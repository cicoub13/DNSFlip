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
        let settingsView = SettingsView()
            .environmentObject(store)
        let hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "DNSSwitcher — Réglages"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 480, height: 280))
        window.isReleasedWhenClosed = false
        window.center()

        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Placeholder views (remplacés en Phase 6)

private struct MenuBarContentView: View {
    @ObservedObject var store: AppStore
    let showSettings: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("DNSSwitcher")
                .font(.headline)
            Text("\(store.profileStore.profiles.count) profil(s) chargé(s)")
                .foregroundStyle(.secondary)
            Divider()
            Button("Réglages…") { showSettings() }
                .buttonStyle(.borderless)
            Button("Quitter") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding()
        .frame(width: 280)
    }
}

private struct SettingsView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        TabView {
            HelperSettingsTab()
                .environmentObject(store)
                .tabItem { Label("Helper", systemImage: "gearshape") }
        }
        .frame(width: 420, height: 260)
    }
}

private struct HelperSettingsTab: View {
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
            if let v = store.helperVersion {
                Text("(v\(v))").foregroundStyle(.secondary).font(.caption)
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