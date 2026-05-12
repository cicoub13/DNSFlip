import SwiftUI
import ServiceManagement

@main
struct DNSSwitcherApp: App {
    @StateObject private var store = AppStore()
    @State private var settingsWindow: NSWindow?

    var body: some Scene {
        MenuBarExtra("DNSSwitcher", systemImage: "network") {
            MenuBarContentView(store: store, showSettings: { presentSettings() })
        }
        .menuBarExtraStyle(.menu)
    }

    private func presentSettings() {
        if let existing = settingsWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let hostingController = NSHostingController(rootView: SettingsView().environmentObject(store))
        let window = NSWindow(contentViewController: hostingController)
        window.title = "DNSSwitcher — Réglages"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 500, height: 360))
        window.isReleasedWhenClosed = false
        window.center()
        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Menu bar

private struct MenuBarContentView: View {
    @ObservedObject var store: AppStore
    let showSettings: () -> Void

    var body: some View {
        ForEach(store.profileStore.profiles) { profile in
            Button(action: { Task { await store.applyProfile(profile) } }) {
                Text((store.activeProfileID == profile.id ? "✓ " : "   ") + profile.name)
            }
        }
        Divider()
        Button("Réglages…") { showSettings() }
        Divider()
        Button("Quitter") { NSApplication.shared.terminate(nil) }
    }
}

// MARK: - Settings window

private struct SettingsView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        TabView {
            ProfilesTab()
                .environmentObject(store)
                .environmentObject(store.profileStore)
                .tabItem { Label("Profils", systemImage: "list.bullet") }
            NetworkTab()
                .environmentObject(store)
                .tabItem { Label("Réseau", systemImage: "network") }
            HelperTab()
                .environmentObject(store)
                .tabItem { Label("Helper", systemImage: "gearshape") }
        }
        .frame(width: 500, height: 360)
    }
}

// MARK: - Profiles tab

private enum ProfileEditorMode: Identifiable {
    case add
    case edit(DNSProfile)

    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let p): return p.id.uuidString
        }
    }
}

private struct ProfilesTab: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var profileStore: ProfileStore
    @State private var editorMode: ProfileEditorMode?

    var body: some View {
        VStack(spacing: 0) {
            List {
                ForEach(profileStore.profiles) { profile in
                    HStack {
                        Image(systemName: store.activeProfileID == profile.id
                              ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(store.activeProfileID == profile.id ? Color.green : Color.secondary)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(profile.name)
                            Text(profile.servers.isEmpty ? "DHCP" : profile.servers.joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Modifier") { editorMode = .edit(profile) }
                            .buttonStyle(.borderless)
                        Button(role: .destructive) {
                            profileStore.profiles.removeAll { $0.id == profile.id }
                            profileStore.save()
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.red)
                    }
                }
                .onMove { source, destination in
                    profileStore.profiles.move(fromOffsets: source, toOffset: destination)
                    profileStore.save()
                }
            }
            Divider()
            HStack {
                Button("Ajouter un profil") { editorMode = .add }
                Spacer()
                if let err = store.helperError {
                    Text(err).foregroundStyle(.red).font(.caption)
                }
            }
            .padding(8)
        }
        .sheet(item: $editorMode) { mode in
            ProfileEditorView(mode: mode, profileStore: profileStore) {
                editorMode = nil
            }
        }
    }
}

// MARK: - Network tab

private struct NetworkTab: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Interface réseau utilisée pour appliquer les profils DNS.")
                .foregroundStyle(.secondary)
                .font(.callout)
            if store.networkServices.isEmpty {
                Text("Aucun service chargé — helper requis.")
                    .foregroundStyle(.secondary)
            } else {
                HStack {
                    Text("Service réseau")
                    Picker("", selection: Binding(
                        get: { store.selectedServiceID },
                        set: { store.selectedServiceID = $0 }
                    )) {
                        Text("Automatique (service actif)").tag(nil as String?)
                        ForEach(store.networkServices, id: \.self) { svc in
                            if let id = svc["id"], let name = svc["name"] {
                                Text(name).tag(id as String?)
                            }
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: 280)
                }
            }
            Spacer()
        }
        .padding()
        .onAppear { Task { await store.fetchServices() } }
    }
}

// MARK: - Helper tab

private struct HelperTab: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            statusRow
            Divider()
            actionButtons
            if let err = store.helperError {
                Text(err).foregroundStyle(.red).font(.caption)
            }
            Spacer()
        }
        .padding()
        .onAppear { store.refreshHelperStatus() }
    }

    private var statusRow: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
            Text(statusLabel)
            if store.helperVersion != nil {
                Text("fonctionnel ✅").foregroundStyle(.secondary).font(.caption)
            }
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
        case .enabled: return "Helper installé"
        case .requiresApproval: return "Approbation requise"
        case .notRegistered: return "Non installé"
        case .notFound: return "Non trouvé"
        @unknown default: return "Inconnu"
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        switch store.helperStatus {
        case .enabled:
            HStack {
                Button("Tester la connexion") {
                    Task { await store.pingHelper() }
                }
                Button("Désinstaller", role: .destructive) {
                    Task { await store.uninstallHelper() }
                }
            }
        case .requiresApproval:
            Button("Ouvrir Réglages Système") {
                SMAppService.openSystemSettingsLoginItems()
            }
        default:
            Button("Installer le helper") {
                Task { await store.installHelper() }
            }
        }
    }
}

// MARK: - Profile editor

private struct ProfileEditorView: View {
    let mode: ProfileEditorMode
    let profileStore: ProfileStore
    let onDismiss: () -> Void

    @State private var name: String
    @State private var serversText: String

    init(mode: ProfileEditorMode, profileStore: ProfileStore, onDismiss: @escaping () -> Void) {
        self.mode = mode
        self.profileStore = profileStore
        self.onDismiss = onDismiss
        switch mode {
        case .add:
            _name = State(initialValue: "")
            _serversText = State(initialValue: "")
        case .edit(let profile):
            _name = State(initialValue: profile.name)
            _serversText = State(initialValue: profile.servers.joined(separator: ", "))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                TextField("Nom", text: $name)
                TextField("Serveurs DNS (séparés par des virgules)", text: $serversText)
                    .help("Laisser vide pour utiliser le DNS DHCP")
            }
            .padding()
            Divider()
            HStack {
                Spacer()
                Button("Annuler") { onDismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Enregistrer") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(EdgeInsets(top: 8, leading: 16, bottom: 12, trailing: 16))
        }
        .frame(width: 360)
    }

    private func save() {
        let servers = serversText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        switch mode {
        case .add:
            profileStore.profiles.append(DNSProfile(name: trimmedName, servers: servers))
        case .edit(let original):
            if let idx = profileStore.profiles.firstIndex(where: { $0.id == original.id }) {
                profileStore.profiles[idx].name = trimmedName
                profileStore.profiles[idx].servers = servers
            }
        }
        profileStore.save()
        onDismiss()
    }
}
