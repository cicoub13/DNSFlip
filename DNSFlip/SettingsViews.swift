import SwiftUI
import ServiceManagement
#if canImport(Sparkle)
import Sparkle
#endif

// MARK: - Settings window

struct SettingsView: View {
    @EnvironmentObject var store: AppStore
    @State private var selectedTab = 0
    #if canImport(Sparkle)
    @StateObject private var sparkle = SparkleUpdaterViewModel()
    #endif

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralTab()
                .environmentObject(store)
                .tabItem { Label("Général", systemImage: "gearshape") }
                .tag(0)
            ProfilesTab()
                .environmentObject(store)
                .environmentObject(store.profileStore)
                .tabItem { Label("Profils", systemImage: "list.bullet") }
                .tag(1)
            NetworkTab(selectedTab: $selectedTab)
                .environmentObject(store)
                .tabItem { Label("Réseau", systemImage: "network") }
                .tag(2)
            HelperTab()
                .environmentObject(store)
                .tabItem { Label("Helper", systemImage: "gearshape.2") }
                .tag(3)
            AboutTab()
                #if canImport(Sparkle)
                .environmentObject(sparkle)
                #endif
                .tabItem { Label("À propos", systemImage: "info.circle") }
                .tag(4)
        }
        .frame(minWidth: 540, idealWidth: 600, minHeight: 420, idealHeight: 480)
    }
}

// MARK: - Sparkle

#if canImport(Sparkle)
final class SparkleUpdaterViewModel: ObservableObject {
    private let controller = SPUStandardUpdaterController(
        startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    @Published var canCheckForUpdates = false

    init() { canCheckForUpdates = controller.updater.canCheckForUpdates }

    func checkForUpdates() { controller.updater.checkForUpdates() }
}
#endif

// MARK: - General tab

struct GeneralTab: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        Form {
            Toggle("Démarrer au login", isOn: Binding(
                get: { store.launchAtLogin },
                set: { val in Task { await store.setLaunchAtLogin(val) } }
            ))
        }
        .formStyle(.grouped)
        .padding(20)
    }
}

// MARK: - Profiles tab

enum ProfileEditorMode: Identifiable {
    case add
    case edit(DNSProfile)

    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let p): return p.id.uuidString
        }
    }
}

struct ProfilesTab: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var profileStore: ProfileStore
    @State private var editorMode: ProfileEditorMode?
    @State private var pendingDelete: DNSProfile?

    var body: some View {
        VStack(spacing: 0) {
            if let err = store.helperError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                    Text(err)
                    Spacer()
                }
                .font(.callout)
                .foregroundStyle(.red)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.08))
            }

            if profileStore.profiles.isEmpty {
                if #available(macOS 14, *) {
                    ContentUnavailableView {
                        Label("Aucun profil", systemImage: "list.bullet.rectangle")
                    } description: {
                        Text("Crée ton premier profil DNS pour commencer.")
                    } actions: {
                        Button("Ajouter un profil") { editorMode = .add }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.system(size: 36))
                            .foregroundStyle(.secondary)
                        Text("Aucun profil").font(.headline)
                        Text("Crée ton premier profil DNS pour commencer.")
                            .foregroundStyle(.secondary)
                        Button("Ajouter un profil") { editorMode = .add }
                            .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                List {
                    ForEach(profileStore.profiles) { profile in
                        HStack {
                            Image(systemName: store.activeProfileID == profile.id
                                  ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(store.activeProfileID == profile.id
                                                 ? Color.green : Color.secondary)
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(profile.name).fontWeight(.medium)
                                if profile.servers.isEmpty {
                                    Text("DHCP")
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                        .italic()
                                } else {
                                    Text(profile.servers.joined(separator: ", "))
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button {
                                editorMode = .edit(profile)
                            } label: {
                                Image(systemName: "pencil")
                            }
                            .buttonStyle(.borderless)
                            .help("Modifier")
                            Button {
                                pendingDelete = profile
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.red)
                        }
                        .padding(.vertical, 2)
                    }
                    .onMove { profileStore.move(fromOffsets: $0, toOffset: $1) }
                }
                Divider()
                HStack {
                    Button {
                        editorMode = .add
                    } label: {
                        Label("Ajouter un profil", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderless)
                    Spacer()
                }
                .padding(8)
            }
        }
        .sheet(item: $editorMode) { mode in
            ProfileEditorView(mode: mode, profileStore: profileStore) { editorMode = nil }
        }
        .confirmationDialog(
            Text("Supprimer \"\(pendingDelete?.name ?? "")\" ?"),
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            presenting: pendingDelete
        ) { profile in
            Button("Supprimer", role: .destructive) {
                profileStore.delete(id: profile.id)
            }
        }
    }
}

// MARK: - Network tab

struct NetworkTab: View {
    @EnvironmentObject var store: AppStore
    @Binding var selectedTab: Int

    private var activeServiceName: String {
        store.networkServices.first(where: { $0.active })?.name ?? "—"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Interface réseau utilisée pour appliquer les profils DNS.")
                .foregroundStyle(.secondary)
                .font(.callout)

            if store.isFetchingServices {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Chargement des interfaces…")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
            } else if store.networkServices.isEmpty {
                if #available(macOS 14, *) {
                    ContentUnavailableView {
                        Label("Aucun service réseau", systemImage: "network.slash")
                    } description: {
                        Text("Le helper est requis pour lister les interfaces réseau.")
                    } actions: {
                        Button("Configurer le helper") { selectedTab = 2 }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "network.slash")
                            .font(.system(size: 36))
                            .foregroundStyle(.secondary)
                        Text("Aucun service réseau").font(.headline)
                        Text("Le helper est requis pour lister les interfaces réseau.")
                            .foregroundStyle(.secondary)
                        Button("Configurer le helper") { selectedTab = 2 }
                            .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Service réseau")
                        Picker("", selection: Binding(
                            get: { store.selectedServiceID },
                            set: { store.selectedServiceID = $0 }
                        )) {
                            Text("Automatique (service actif)").tag(nil as String?)
                            ForEach(store.networkServices) { svc in
                                Text(svc.name).tag(svc.id as String?)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(maxWidth: 280)
                        Button {
                            Task { await store.fetchServices() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.borderless)
                        .help("Rafraîchir les interfaces")
                    }
                    Text("Service actif détecté : \(activeServiceName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(20)
        .onAppear { Task { await store.fetchServices() } }
    }
}

// MARK: - Helper tab

struct HelperTab: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("DNSFlip utilise un service privilégié pour modifier les DNS système. Ce service (helper) s'exécute en arrière-plan et ne demande votre mot de passe qu'une seule fois lors de l'installation.")
                .foregroundStyle(.secondary)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            HStack(spacing: 14) {
                Image(systemName: statusIcon)
                    .font(.system(size: 28))
                    .foregroundStyle(statusColor)
                    .frame(width: 36)
                VStack(alignment: .leading, spacing: 3) {
                    Text(statusLabel).fontWeight(.medium)
                    Text(statusDescription)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                if store.isWorkingOnHelper {
                    ProgressView().controlSize(.small)
                }
                actionButtons
            }

            if let err = store.helperError {
                Label(err, systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            if let version = store.helperVersion {
                Label {
                    Text("Connexion fonctionnelle : v\(version)")
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                }
                .font(.caption.monospaced())
                .foregroundStyle(.green)
            }

            Spacer()
        }
        .padding(20)
        .onAppear { store.refreshHelperStatus() }
    }

    private var statusIcon: String {
        switch store.helperStatus {
        case .enabled: return "checkmark.shield.fill"
        case .requiresApproval: return "exclamationmark.triangle.fill"
        default: return "xmark.shield.fill"
        }
    }

    private var statusColor: Color {
        switch store.helperStatus {
        case .enabled: return .green
        case .requiresApproval: return .orange
        default: return .red
        }
    }

    private var statusLabel: String {
        switch store.helperStatus {
        case .enabled: return String(localized: "Helper installé")
        case .requiresApproval: return String(localized: "Approbation requise")
        case .notRegistered: return String(localized: "Non installé")
        case .notFound: return String(localized: "Non trouvé")
        @unknown default: return String(localized: "État inconnu")
        }
    }

    private var statusDescription: String {
        switch store.helperStatus {
        case .enabled: return String(localized: "Le service est actif et joignable.")
        case .requiresApproval: return String(localized: "Autorisez-le dans Réglages Système → Général → Ouverture.")
        case .notRegistered: return String(localized: "Cliquez sur Installer pour activer le service.")
        case .notFound: return String(localized: "Fichier helper introuvable dans le bundle.")
        @unknown default: return ""
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        switch store.helperStatus {
        case .enabled:
            Button("Tester la connexion") { Task { await store.pingHelper() } }
                .disabled(store.isWorkingOnHelper)
            Button("Désinstaller", role: .destructive) { Task { await store.uninstallHelper() } }
                .disabled(store.isWorkingOnHelper)
        case .requiresApproval:
            Button("Ouvrir Réglages Système") { SMAppService.openSystemSettingsLoginItems() }
        default:
            Button("Installer le helper") { Task { await store.installHelper() } }
                .disabled(store.isWorkingOnHelper)
        }
    }
}

// MARK: - About tab

struct AboutTab: View {
    #if canImport(Sparkle)
    @EnvironmentObject private var sparkle: SparkleUpdaterViewModel
    #endif

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    var body: some View {
        VStack(spacing: 20) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 80, height: 80)
            VStack(spacing: 4) {
                Text("DNSFlip").font(.title2.weight(.semibold))
                Text("Version \(appVersion)").foregroundStyle(.secondary)
            }
            Text("© 2026 Cyril Beslay").font(.callout).foregroundStyle(.secondary)
            #if canImport(Sparkle)
            Button("Vérifier les mises à jour…") { sparkle.checkForUpdates() }
                .disabled(!sparkle.canCheckForUpdates)
            #endif
            Spacer()
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
