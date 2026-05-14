# Plan — DNSFlip v1

## État

- **Phase 1–2** : projet Xcode, targets, SMAppService ✅
- **Phase 3** : helper LaunchDaemon + XPC hello-world ✅ (v1 confirmé via UI)
- **Phase 4** : DNSConfigurator.swift — SCPreferences ← **en cours**
- **Phase 5** : NetworkInspector.swift — SCDynamicStore + NWPathMonitor
- **Phase 6** : UI finale (MenuBarContentView + SettingsView + ProfileEditorView)
- **Phase 7** : Script build-and-notarize.sh

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

## Compilation

```bash
xcodebuild -scheme DNSFlip -configuration Debug build
# → BUILD SUCCEEDED
```

Debug DerivedData : `~/Library/Developer/Xcode/DerivedData/DNSFlip-aggpdragwtjkzxfwcbyrwurckmvq/Build/Products/Debug/DNSFlip.app`
