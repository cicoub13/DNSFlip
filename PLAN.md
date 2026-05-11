# Plan — DNSSwitcher v1 (suite)

## Contexte

Phase 3 (helper SMAppService + XPC hello-world) est **construite** mais le test end-to-end **échoue** au niveau de launchd : le helper spawn mais crash immédiatement avec `last exit code = 78: EX_CONFIG`.

L'helper binary fonctionne quand lancé manuellement (depuis `Contents/MacOS/`), l'XPC Mach port est bien enregistré (`0x18fdcf`), mais launchd ne peut pas le démarrer correctement — problème de configuration plist ou de sandbox.

**Symptômes** :
- `launchctl print system/fr.fotozik.DNSSwitcher.helper` → `state = spawn failed`, `exit code = 78`
- `ps aux | grep DNSSwitcherHelper` → le processus apparaît brièvement puis disparaît
- Le helper tourne correctement si lancé manuellement (`./DNSSwitcherHelper` depuis `Contents/MacOS/`)

---

## Diagnostic à faire

1. **Vérifier les logs launchd** :
   ```bash
   log show --predicate 'process == "DNSSwitcherHelper" OR processImagePath contains "DNSSwitcherHelper"' --level error --last 5m
   ```

2. **Tester sans sandbox** (launchd peut être plus strict sur les paths) :
   - Le `BundleProgram` dans le plist est `MacOS/DNSSwitcherHelper` (relatif au bundle)
   - Vérifier que c'est le bon path pour launchd (qui voit le bundle depuis `/`)
   - launchd peut avoir un problème avec les paths relatifs pour les LaunchDaemons via SMAppService

3. **Ajouter un exit handler** dans le helper pour comprendre exactement où il crash

---

## Prochaines étapes

### Diagnostic (par agent dedicated)
- [ ] `log show` pour capturer l'erreur exacte du crash
- [ ] Vérifier le sandbox profile de launchd
- [ ] Tester `BundleProgram` avec un chemin absolu vs relatif

### Si le helper marche (XPC hello-world validé)
- [ ] Phase 4 : SCPreferences DNS writing (DNSConfigurator.swift)
- [ ] Phase 5 : SCDynamicStore NetworkInspector
- [ ] Phase 6 : UI finale (MenuBarContentView + SettingsView)
- [ ] Phase 7 : Signature + notarisation

### Si le plist launchd est le problème
- [ ] Corriger le launchd plist (chemin absolu pour BundleProgram ?)
- [ ] Vérifier les permissions du bundle
- [ ] Vérifier `AssociatedBundleIdentifiers`

---

## Fichiers actuels critiques

| Fichier | Rôle |
|---|---|
| `DNSSwitcherHelper/main.swift` | XPC hello-world stub (helperVersion = "1", setDNS = error) |
| `DNSSwitcher/IPC/HelperClient.swift` | Client XPC async (utilise `DNSHelperProtocol`) |
| `DNSSwitcher/IPC/DNSHelperProtocol.swift` | @objc protocole partagé |
| `DNSSwitcher/Models/AppStore.swift` | SMAppService install/uninstall + ping |
| `DNSSwitcher/DNSSwitcherApp.swift` | MenuBarExtra + Settings window opener |
| `DNSSwitcherHelper/fr.fotozik.DNSSwitcher.helper.plist` | LaunchDaemon plist dans le bundle |
| `DNSSwitcherHelper/Info.plist` | Embarqué via `-sectcreate __TEXT __info_plist` (SMAuthorizedClients) |

---

## Architecture actuelle (Phase 3)

```
DNSSwitcher.app
├── Contents/MacOS/
│   ├── DNSSwitcher         (SwiftUI MenuBarExtra)
│   └── DNSSwitcherHelper  (XPC daemon root, -sectcreate __TEXT __info_plist)
└── Contents/Library/LaunchDaemons/
    └── fr.fotozik.DNSSwitcher.helper.plist  (Label + BundleProgram + MachServices)

App GUI ──NSXPCConnection──▶ Helper (root, Mach "fr.fotozik.DNSSwitcher.helper")
```

**Protocole XPC** (`DNSHelperProtocol`) :
- `helperVersion(reply:)` → String
- `setDNS(serviceID:servers:reply:)` → Error?
- `listServices(reply:)` → [[String:String]]

---

## Compilation

```bash
xcodebuild -scheme DNSSwitcher -configuration Debug build
# → BUILD SUCCEEDED
```

Debug DerivedData : `~/Library/Developer/Xcode/DerivedData/DNSSwitcher-aggpdragwtjkzxfwcbyrwurckmvq/Build/Products/Debug/DNSSwitcher.app`