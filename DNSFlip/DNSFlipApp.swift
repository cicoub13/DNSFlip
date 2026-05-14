import SwiftUI
import Network

// MARK: - App entry point

@main
struct DNSFlipApp: App {
    @StateObject private var store = AppStore()
    @State private var settingsWindow: NSWindow?

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(store: store, showSettings: { presentSettings() })
        } label: {
            Image(systemName: menuBarSymbol)
                .accessibilityLabel("DNSFlip")
        }
        .menuBarExtraStyle(.menu)
    }

    private var menuBarSymbol: String {
        if store.applySuccess { return "checkmark.circle.fill" }
        return store.helperStatus == .enabled
            ? "arrow.left.arrow.right.circle.fill"
            : "arrow.left.arrow.right.circle"
    }

    private func presentSettings() {
        if let existing = settingsWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let hostingController = NSHostingController(rootView: SettingsView().environmentObject(store))
        let window = NSWindow(contentViewController: hostingController)
        window.title = String(localized: "DNSFlip — Réglages")
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 580, height: 460))
        window.isReleasedWhenClosed = false
        window.center()
        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - IP validation helper

func isValidIP(_ s: String) -> Bool {
    IPv4Address(s) != nil || IPv6Address(s) != nil
}
