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
    @Published var networkServices: [[String: String]] = []

    @Published var activeProfileID: UUID? {
        didSet { UserDefaults.standard.set(activeProfileID?.uuidString, forKey: "activeProfileID") }
    }
    @Published var selectedServiceID: String? {
        didSet { UserDefaults.standard.set(selectedServiceID, forKey: "selectedServiceID") }
    }

    private let daemonService = SMAppService.daemon(plistName: "fr.fotozik.DNSSwitcher.helper.plist")

    init() {
        _activeProfileID = Published(initialValue:
            UserDefaults.standard.string(forKey: "activeProfileID").flatMap(UUID.init))
        _selectedServiceID = Published(initialValue:
            UserDefaults.standard.string(forKey: "selectedServiceID"))
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

    func fetchServices() async {
        do {
            networkServices = try await helperClient.listServices()
        } catch {
            helperError = error.localizedDescription
        }
    }

    func applyProfile(_ profile: DNSProfile) async {
        guard helperStatus == .enabled else {
            helperError = "Helper non installé — ouvre Réglages → Helper"
            return
        }
        if networkServices.isEmpty {
            await fetchServices()
        }
        guard let serviceID = effectiveServiceID() else {
            helperError = "Aucun service réseau disponible"
            return
        }
        do {
            try await helperClient.setDNS(serviceID: serviceID, servers: profile.servers)
            activeProfileID = profile.id
            helperError = nil
        } catch {
            helperError = error.localizedDescription
        }
    }

    private func effectiveServiceID() -> String? {
        if let id = selectedServiceID { return id }
        if let id = networkServices.first(where: { $0["active"] == "1" })?["id"] { return id }
        return networkServices.first?["id"]
    }
}
