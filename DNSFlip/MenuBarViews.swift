import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var store: AppStore
    @ObservedObject var profileStore: ProfileStore
    let showSettings: () -> Void

    private var activeName: String {
        guard let id = store.activeProfileID,
              let p = store.profileStore.profiles.first(where: { $0.id == id }) else {
            return String(localized: "Aucun profil actif")
        }
        return p.name
    }

    var body: some View {
        let helperActive = store.helperStatus == .enabled
        if helperActive {
            Button("DNS actif : \(activeName)") {}
                .disabled(true)
        } else {
            Button("DNS inactif") {}
                .disabled(true)
        }
        Divider()
        ForEach(profileStore.profiles) { profile in
            ProfileMenuItem(
                profile: profile,
                isActive: store.activeProfileID == profile.id
            ) {
                Task { await store.applyProfile(profile) }
            }
            .disabled(!helperActive)
        }
        Divider()
        if store.helperError != nil {
            Button("⚠︎ Erreur — ouvrir Réglages") { showSettings() }
        }
        Button("Réglages…") { showSettings() }
            .keyboardShortcut(",", modifiers: .command)
        Divider()
        Button("Quitter DNSFlip") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q", modifiers: .command)
    }
}

struct ProfileMenuItem: View {
    let profile: DNSProfile
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if isActive {
                Label(profile.name, systemImage: "checkmark")
            } else {
                Text(profile.name)
            }
        }
    }
}
