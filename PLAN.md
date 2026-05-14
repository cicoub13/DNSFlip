# Plan — DNSFlip v1

## État

- **Phase 1–2** : projet Xcode, targets, SMAppService ✅
- **Phase 3** : helper LaunchDaemon + XPC hello-world ✅ (v1 confirmé via UI)
- **Phase 4** : DNSConfigurator.swift — SCPreferences ✅ (commit f314d3e)
- **Phase 5** : NetworkInspector.swift — SCDynamicStore + NWPathMonitor
- **Phase 6** : UI finale (MenuBarContentView + SettingsView + ProfileEditorView)
- **Phase 7** : Pipeline de distribution ✅ (voir ci-dessous)

---

## Fix Phase 3 (post-mortem)

`BundleProgram` était `MacOS/DNSFlipHelper` mais launchd résout ce chemin depuis la racine du bundle (`DNSFlip.app/`). Le binaire est à `Contents/MacOS/DNSFlipHelper` → corrigé.

---

## Phase 4 — DNSConfigurator.swift

Implémenter la vraie logique DNS dans le helper via `SCPreferences` / `SystemConfiguration.framework`.

### Objectif

`setDNS(serviceID:servers:reply:)` dans `HelperImpl` doit :
1. Ouvrir `SCPreferences` avec authorization (le helper tourne en root → pas besoin d'AuthorizationRef côté helper)
2. Localiser le service réseau par `serviceID` (UUID du service SCPreferences)
3. Écrire les serveurs DNS dans `State:/Network/Service/<id>/DNS` et `Setup:/Network/Service/<id>/DNS`
4. Appeler `SCPreferencesApplyChanges` + `SCPreferencesCommitChanges`

### Fichiers à créer / modifier

| Fichier | Action |
|---|---|
| `DNSFlipHelper/DNSConfigurator.swift` | Nouveau — logique SCPreferences |
| `DNSFlipHelper/main.swift` | Modifier `setDNS` → déléguer à `DNSConfigurator` |
| `DNSFlip.xcodeproj` | Ajouter `SystemConfiguration.framework` au target helper |

### API SCPreferences (rappel)

```swift
// Ouvrir les préférences système (root → pas d'auth requise)
let prefs = SCPreferencesCreate(nil, "DNSFlipHelper" as CFString, nil)

// Chemin du service DNS
let path = "NetworkServices/\(serviceID)/DNS" as CFString
let dnsDict: CFDictionary = ["ServerAddresses": servers] as CFDictionary

SCPreferencesPathSetValue(prefs, path, dnsDict)
SCPreferencesCommitChanges(prefs)
SCPreferencesApplyChanges(prefs)
```

### Aussi : listServices

`listServices(reply:)` doit retourner les services réseau actifs :
- Utiliser `SCNetworkServiceCopyAll` ou lire `NetworkServices` dans SCPreferences
- Retourner `[["id": uuid, "name": name, "active": "1/0"]]`

---

## Phase 5 — NetworkInspector.swift

- `SCDynamicStoreCreate` pour observer les changements DNS en temps réel
- `NWPathMonitor` pour détecter l'interface active
- Notifier l'app via XPC (ou `DistributedNotificationCenter`)

---

## Architecture actuelle (Phase 3 terminée)

```
DNSFlip.app
├── Contents/MacOS/
│   ├── DNSFlip         (SwiftUI MenuBarExtra)
│   └── DNSFlipHelper  (XPC daemon root)
└── Contents/Library/LaunchDaemons/
    └── com.bootstrap.DNSFlip.helper.plist

App GUI ──NSXPCConnection──▶ Helper (root, Mach "com.bootstrap.DNSFlip.helper")
```

**Protocole XPC** (`DNSHelperProtocol`) :
- `helperVersion(reply:)` → String ✅
- `setDNS(serviceID:servers:reply:)` → Error? (stub → Phase 4)
- `listServices(reply:)` → [[String:String]] (stub → Phase 4)

---

## Phase 7 — Pipeline de distribution ✅

Fichiers créés :
- `scripts/build-and-notarize.sh` — build Release, export, DMG, notarisation, staple, EdDSA Sparkle
- `scripts/ExportOptions.plist` — Developer ID, Manual signing, Team 3X7B4F6R56
- `scripts/update-appcast.py` — MAJ appcast.xml à chaque release
- `.github/workflows/release.yml` — CI déclenché sur tag `v*.*.*`
- `appcast.xml` — feed Sparkle (rempli automatiquement par le CI)
- `CHANGELOG.md`, `LICENSE`, `README.md`

### Étapes one-shot à faire avant la première release

1. **Apple API Key** : https://appstoreconnect.apple.com → Keys → "Developer" → télécharger `.p8`
   ```bash
   xcrun notarytool store-credentials "DNSFlip-AC-API" \
     --key ~/.appstoreconnect/AuthKey_XXX.p8 \
     --key-id XXXXXXXXXX \
     --issuer XXXXXXXX-XXXX-...
   ```
2. **Sparkle** : ajouter via Xcode → File → Add Package → `https://github.com/sparkle-project/Sparkle`  
   Puis générer les clés EdDSA :
   ```bash
   # Trouver generate_keys dans DerivedData après le premier build avec Sparkle
   find ~/Library/Developer/Xcode/DerivedData -name generate_keys | head -1
   ./generate_keys   # → affiche la clé publique à ajouter dans pbxproj:
                     #   INFOPLIST_KEY_SUPublicEDKey = "clé ici"
   ```
3. **Télécharger sign_update** :
   ```bash
   # Depuis la release Sparkle (même version que SPM) :
   # Extraire sign_update → bin/sign_update
   chmod +x bin/sign_update
   ```
4. **AppIcon** : fournir les images PNG dans `DNSFlip/Assets.xcassets/AppIcon.appiconset/`  
   (16, 32, 128, 256, 512 @ 1x/2x — 10 tailles)
5. **Secrets GitHub** (Settings → Secrets → Actions) :
   - `AC_API_KEY_P8` — `base64 -i AuthKey_XXX.p8 | pbcopy`
   - `AC_API_KEY_ID`, `AC_API_ISSUER_ID`
   - `BUILD_CERT_P12` — exporter le cert Developer ID depuis le Trousseau en .p12 + base64
   - `BUILD_CERT_PASSWORD`, `KEYCHAIN_PASSWORD`
   - `HOMEBREW_TAP_TOKEN` (optionnel) — PAT GitHub sur le repo `cicoub13/homebrew-tap`
6. **Repo homebrew-tap** : créer `cicoub13/homebrew-tap` sur GitHub  
   (le workflow y pousse le Cask automatiquement)

### Release publique

```bash
./scripts/build-and-notarize.sh          # test local
git tag v1.0.0 && git push origin v1.0.0 # déclenche le CI
```

---

## Compilation

```bash
xcodebuild -scheme DNSFlip -configuration Debug build
# → BUILD SUCCEEDED
```

Debug DerivedData : `~/Library/Developer/Xcode/DerivedData/DNSFlip-aggpdragwtjkzxfwcbyrwurckmvq/Build/Products/Debug/DNSFlip.app`
