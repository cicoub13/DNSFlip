# AGENTS.md — DNSFlip

Instructions for any agent working on this project.

## Overview

DNSFlip is a macOS menu bar app (SwiftUI `MenuBarExtra`) that switches system DNS servers via a root LaunchDaemon helper over XPC. Distributed outside the Mac App Store (Developer ID + notarization).

---

## Code signing rules

- **Team ID** : `3X7B4F6R56`
- `SMAuthorizedClients` in the helper's embedded Info.plist **must** use `certificate leaf[subject.OU] = "3X7B4F6R56"` (checks the OU field, not the CN)
- `CODE_SIGN_STYLE = Manual` required on macOS 26 (not `Automatic`, which looks for "Mac Development")

## Helper architecture

- Helper = LaunchDaemon (not SMJobBless)
- `com.bootstrap.DNSFlip.helper.plist` is a real file copied to `Contents/Library/LaunchDaemons/`
- Info.plist is **embedded** in the binary via `-sectcreate __TEXT __info_plist`
- `SMAuthorizedClients` lives in the embedded Info.plist of the binary (not in the launchd plist)

## SMAppService

- `SMAppService.daemon(plistName:)` to register the LaunchDaemon
- `unregister()` is **async** on macOS 26 SDK
- Open Login Items: `SMAppService.openSystemSettingsLoginItems()`

## XPC

- `NSXPCConnection(machServiceName:options: .privileged)` for app → root helper connection
- `@objc` protocol + `NSSecureCoding` required for transmitted types
- `DNSHelperProtocol` is compiled into **both targets** (app and helper)
- `invalidationHandler` / `interruptionHandler` on the connection for reconnection handling

---

## Useful commands

```bash
# Build
xcodebuild -scheme DNSFlip -configuration Debug build

# Verify helper signature
codesign -dv DNSFlip.app/Contents/MacOS/DNSFlipHelper

# Verify bundle structure
ls -la DNSFlip.app/Contents/MacOS/
ls -la DNSFlip.app/Contents/Library/LaunchDaemons/

# Verify embedded Info.plist
otool -s __TEXT __info_plist DNSFlip.app/Contents/MacOS/DNSFlipHelper

# launchd status
launchctl print system/com.bootstrap.DNSFlip.helper

# launchd logs
log show --predicate 'process == "DNSFlipHelper" OR subsystem == "com.apple.servicemanagement"' --level error --last 5m
```

---

## Known pitfalls

1. **SourceKit false positives** : "Cannot find type X in scope" after creating a new file → run a build to resolve (do not create duplicates in pbxproj)
2. `SMAppService.unregister()` is async on macOS 26 → `try await`
3. `BundleProgram` must be `Contents/MacOS/DNSFlipHelper` (relative to `DNSFlip.app/`) — omitting `Contents/` causes launchd to look for `DNSFlip.app/MacOS/…` → EX_CONFIG (78)
4. If the build fails with "unsealed contents present in the bundle root", delete any `default.profraw` files left by profiling in the bundle

---

## Commit conventions

- One commit per functional phase
- Message: `Phase N — short description`
- Detailed body: problems encountered and solutions
