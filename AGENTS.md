# AGENTS.md — DNSFlip

Instructions pour tout agent qui travaille sur ce projet.

## Projet概述

DNSFlip est une app macOS menu bar (SwiftUI `MenuBarExtra`) qui permute les serveurs DNS système via un helper root LaunchDaemon + XPC. Distribué hors Mac App Store (Developer ID + notarisation).

**Phase actuelle** : Phase 3 terminée (build OK) mais test XPC end-to-end échoue (launchd spawn fail `EX_CONFIG`). Voir `PLAN.md` pour le diagnostic en cours.

---

## Règles fondamentales

### Signature de code
- **Team ID** : `3X7B4F6R56` (pas le CN du cert qui montre `5R6326P5M7`)
- **Certificat valide** : hash `043E45DB8A108B80CDF02FDB35242D0EBA2BA99A`
- `SMAuthorizedClients` dans le helper Info.plist **doit** utiliser `certificate leaf[subject.OU] = "3X7B4F6R56"` (vérifie le champ OU, pas le CN)
- `CODE_SIGN_STYLE = Manual` requis sur macOS 26 (pas `Automatic` qui cherche "Mac Development")
- L'autre cert Apple Development (`D5044FB2D37A75E57708ADDA1D5C93F081CFADC3`) est expiré — à supprimer du Keychain

### Architecture helper
- Helper = LaunchDaemon (pas SMJobBless)
- Le plist `com.bootstrap.DNSFlip.helper.plist` est un **vrai fichier** copié dans `Contents/Library/LaunchDaemons/`
- L'Info.plist est **embarqué** dans le binaire via `-sectcreate __TEXT __info_plist`
- `SMAuthorizedClients` dans l'Info.plist embarqué du binaire (pas dans le launchd plist)

### SMAppService
- `SMAppService.daemon(plistName:)` pour enregistrer le LaunchDaemon
- `unregister()` est **async** sur macOS 26 SDK
- Ouvrir Login Items : `SMAppService.openSystemSettingsLoginItems()`

### XPC
- `NSXPCConnection(machServiceName:options: .privileged)` pour connexion depuis app → helper root
- Protocole `@objc` + `NSSecureCoding` requis pour les types transmis
- `DNSHelperProtocol` est compilé dans **les deux targets** (app et helper)
- `invalidationHandler` / `interruptionHandler` sur la connexion pour gérer les reconnexions

---

## Commandes utiles

```bash
# Build
xcodebuild -scheme DNSFlip -configuration Debug build

# Vérifier signature helper
codesign -dv DNSFlip.app/Contents/MacOS/DNSFlipHelper

# Vérifier structure bundle
ls -la DNSFlip.app/Contents/MacOS/
ls -la DNSFlip.app/Contents/Library/LaunchDaemons/

# Vérifier Info.plist embarqué
otool -s __TEXT __info_plist DNSFlip.app/Contents/MacOS/DNSFlipHelper

# État launchd
launchctl print system/com.bootstrap.DNSFlip.helper

# Logs launchd
log show --predicate 'process == "DNSFlipHelper" OR subsystem == "com.apple.servicemanagement"' --level error --last 5m

# Ouvrir app
open ~/Library/Developer/Xcode/DerivedData/DNSFlip-aggpdragwtjkzxfwcbyrwurckmvq/Build/Products/Debug/DNSFlip.app
```

---

## Prochaines tâches (PLAN.md)

1. **Diagnostic XPC** : launchd spawn fail avec `EX_CONFIG` — le helper tourne manuellement mais pas via SMAppService
2. **Phase 4** : DNSConfigurator.swift avec SCPreferences, SystemConfiguration.framework dans pbxproj
3. **Phase 5** : NetworkInspector.swift (SCDynamicStore + NWPathMonitor)
4. **Phase 6** : UI MenuBarContentView (liste profils + DNS actif) + SettingsView (tabs Profils/Helper/À propos) + ProfileEditorView
5. **Phase 7** : Script build-and-notarize.sh

---

## Fichiers modifiés récemment

- `DNSFlip/DNSFlipApp.swift` — MenuBarExtra avec `.menuBarExtraStyle(.menu)` + fenêtre Settings manuelle (SettingsLink ne marche pas depuis MenuBarExtra)
- `DNSFlip/IPC/HelperClient.swift` — client XPC async
- `DNSFlipHelper/main.swift` — XPC listener hello-world (setDNS/listServices stubs)
- `DNSFlipHelper/Info.plist` — embarqué dans le binaire, `SMAuthorizedClients` avec Team ID 3X7B4F6R56
- `DNSFlipHelper/com.bootstrap.DNSFlip.helper.plist` — copied to LaunchDaemons/ dans le bundle

---

## Erreurs connues

1. **SourceKit false positives** : "Cannot find type X in scope" après chaque création de fichier → faire un build pour résoudre (ne pas créer de doublons dans pbxproj)
2. `.keyboardShortcut(.comma)` n'existe pas → utiliser `.buttonStyle(.borderless)`
3. `SMAppService.unregister()` est async sur macOS 26 → `try await`
4. `BundleProgram` doit être `Contents/MacOS/DNSFlipHelper` (relatif à `DNSFlip.app/`) — sans `Contents/` launchd cherche `DNSFlip.app/MacOS/…` → EX_CONFIG (78)
5. Si le build échoue avec "unsealed contents present in the bundle root", supprimer les `default.profraw` laissés par le profiling dans le bundle

---

## Conventions de commit

- Un commit par phase fonctionnelle
- Message : "Phase N — description courte"
- Corps détaillé : problèmes rencontrés et solutions