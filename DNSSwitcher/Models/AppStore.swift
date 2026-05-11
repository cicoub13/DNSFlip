import Foundation
import Combine
import ServiceManagement

@MainActor
final class AppStore: ObservableObject {
    let profileStore = ProfileStore()
    let helperClient = HelperClient()

    @Published var helperStatus: SMAppService.Status = .notRegistered
    @Published var helperVersion: String?
    @Published var helperError: String?

    private let daemonService = SMAppService.daemon(plistName: "fr.fotozik.DNSSwitcher.helper.plist")

    init() {
        refreshHelperStatus()
    }

    func refreshHelperStatus() {
        helperStatus = daemonService.status
    }

    func installHelper() async {
        do {
            try daemonService.register()
            refreshHelperStatus()
            await pingHelper()
        } catch {
            helperError = error.localizedDescription
        }
    }

    func uninstallHelper() async {
        do {
            try await daemonService.unregister()
            refreshHelperStatus()
            helperVersion = nil
        } catch {
            helperError = error.localizedDescription
        }
    }

    func pingHelper() async {
        do {
            helperVersion = try await helperClient.helperVersion()
        } catch {
            helperVersion = nil
        }
    }
}
