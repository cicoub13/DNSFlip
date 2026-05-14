#!/usr/bin/env bash
# Build, sign, notarize, and staple DNSFlip.
# Usage:
#   Local:  ./scripts/build-and-notarize.sh
#   CI:     Called automatically by .github/workflows/release.yml
#
# Prerequisites (local):
#   brew install create-dmg
#   xcrun notarytool store-credentials "DNSFlip-AC-API" \
#     --key ~/.appstoreconnect/AuthKey_XXXXXXXXXX.p8 \
#     --key-id XXXXXXXXXX --issuer XXXXXXXX-...
#   bin/sign_update  (from Sparkle release tarball — see README)
#
# CI environment variables required:
#   APPLE_API_KEY_PATH    path to the .p8 key file
#   APPLE_API_KEY_ID      10-char key ID
#   APPLE_API_ISSUER_ID   UUID issuer

set -euo pipefail

SCHEME="DNSFlip"
CONFIG="Release"
TEAM_ID="3X7B4F6R56"
CERT_HASH="CE3A55BF33414E397601B24F5A8245DC43EACCB5"
KEYCHAIN_PROFILE="DNSFlip-AC-API"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$ROOT_DIR"

# ── Read version ──────────────────────────────────────────────────────────────
VERSION=$(grep -m1 'MARKETING_VERSION' DNSFlip.xcodeproj/project.pbxproj \
  | sed 's/.*MARKETING_VERSION = //;s/;//;s/[[:space:]]//g')
echo "→ Building DNSFlip v${VERSION}"

mkdir -p build

# ── Clean ─────────────────────────────────────────────────────────────────────
xcodebuild clean \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -quiet

# ── Archive ───────────────────────────────────────────────────────────────────
xcodebuild archive \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -archivePath "build/DNSFlip.xcarchive" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="Developer ID Application" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  -quiet

# ── Export ────────────────────────────────────────────────────────────────────
echo "→ Exporting archive"
rm -rf "build/export"
mkdir -p "build/export"
cp -R "build/DNSFlip.xcarchive/Products/Applications/DNSFlip.app" "build/export/"

APP="build/export/DNSFlip.app"

# ── Re-sign Sparkle components (SPM builds leave Versions/B with dev cert) ────
echo "→ Re-signing Sparkle nested components"
SPARKLE="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
for item in \
    "$SPARKLE/XPCServices/Downloader.xpc" \
    "$SPARKLE/XPCServices/Installer.xpc" \
    "$SPARKLE/Updater.app" \
    "$SPARKLE/Autoupdate" \
    "$SPARKLE"; do
  [ -e "$item" ] && codesign --force --sign "$CERT_HASH" --timestamp --options runtime "$item"
done
codesign --force --sign "$CERT_HASH" --timestamp --options runtime "$APP"

# ── Verify signature ──────────────────────────────────────────────────────────
echo "→ Verifying signature"
codesign --verify --deep --strict --verbose=2 "$APP"
spctl --assess --type execute --verbose "$APP" || {
  echo "⚠  spctl assess failed — likely not notarized yet (expected at this stage)"
}

# ── Create DMG ────────────────────────────────────────────────────────────────
echo "→ Creating DMG"
DMG="build/DNSFlip-${VERSION}.dmg"
rm -f "$DMG"

DMG_ARGS=(
  --volname "DNSFlip ${VERSION}"
  --window-size 540 380
  --icon-size 96
  --icon "DNSFlip.app" 140 180
  --app-drop-link 400 180
  --no-internet-enable
)

if [ -f "scripts/dmg-background.png" ]; then
  DMG_ARGS+=(--background "scripts/dmg-background.png")
fi

create-dmg "${DMG_ARGS[@]}" "$DMG" "$APP"

# ── Sign DMG ──────────────────────────────────────────────────────────────────
echo "→ Signing DMG"
codesign --sign "$CERT_HASH" --timestamp "$DMG"

# ── Notarize ──────────────────────────────────────────────────────────────────
echo "→ Notarizing (this takes 1–5 min)"
if [ -n "${CI:-}" ]; then
  xcrun notarytool submit "$DMG" \
    --key "${APPLE_API_KEY_PATH}" \
    --key-id "${APPLE_API_KEY_ID}" \
    --issuer "${APPLE_API_ISSUER_ID}" \
    --wait
else
  xcrun notarytool submit "$DMG" \
    --keychain-profile "$KEYCHAIN_PROFILE" \
    --wait
fi

# ── Staple ────────────────────────────────────────────────────────────────────
echo "→ Stapling"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

# ── Checksum ──────────────────────────────────────────────────────────────────
echo "→ Computing checksum"
shasum -a 256 "$DMG" | tee "${DMG}.sha256"

# ── Sparkle signature ─────────────────────────────────────────────────────────
SIGN_UPDATE=""
for candidate in \
    "bin/sign_update" \
    "$(find ~/Library/Developer/Xcode/DerivedData -name "sign_update" -maxdepth 12 2>/dev/null | head -1)" \
    "$(command -v sign_update 2>/dev/null || true)"; do
  if [ -x "${candidate:-}" ]; then
    SIGN_UPDATE="$candidate"
    break
  fi
done

if [ -n "$SIGN_UPDATE" ]; then
  echo "→ Signing for Sparkle (EdDSA)"
  SPARKLE_SIG=$("$SIGN_UPDATE" "$DMG")
  DMG_SIZE=$(stat -f%z "$DMG")
  {
    echo "SPARKLE_SIG=${SPARKLE_SIG}"
    echo "DMG_SIZE=${DMG_SIZE}"
    echo "DMG_URL=https://github.com/cicoub13/DNSFlip/releases/download/v${VERSION}/DNSFlip-${VERSION}.dmg"
  } > "build/sparkle.env"
  echo "Sparkle EdDSA: $SPARKLE_SIG"
else
  echo "⚠  bin/sign_update not found — skipping Sparkle signature"
  echo "   Download Sparkle tools: https://github.com/sparkle-project/Sparkle/releases"
  echo "   Extract sign_update and place it at bin/sign_update"
fi

echo ""
echo "✓ Done."
echo "  Artifact : $DMG"
echo "  Checksum : ${DMG}.sha256"
[ -f "build/sparkle.env" ] && echo "  Sparkle  : build/sparkle.env"
