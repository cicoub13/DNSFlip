import Foundation
import Combine
import Network
import ServiceManagement

struct NetworkService: Identifiable, Hashable {
    let id: String
    let name: String
    let active: Bool

    init?(_ dict: [String: String]) {
        guard let id = dict["id"], let name = dict["name"] else { return nil }
        self.id = id
        self.name = name
        self.active = dict["active"] == "1"
    }
}

@MainActor
final class AppStore: ObservableObject {
    let profileStore = ProfileStore()
    let helperClient = HelperClient()

    @Published var helperStatus: SMAppService.Status = .notRegistered
    @Published var helperVersion: String?
    @Published var helperError: String?
    @Published var networkServices: [NetworkService] = []
    @Published var isFetchingServices: Bool = false
    @Published var isWorkingOnHelper: Bool = false
    @Published var launchAtLogin: Bool = false
    @Published var applySuccess: Bool = false

    @Published var activeProfileID: UUID? {
        didSet { UserDefaults.standard.set(activeProfileID?.uuidString, forKey: "activeProfileID") }
    }
    @Published var selectedServiceID: String? {
        didSet { UserDefaults.standard.set(selectedServiceID, forKey: "selectedServiceID") }
    }

    private let daemonService = SMAppService.daemon(plistName: "com.bootstrap.DNSFlip.helper.plist")
    private let loginService = SMAppService.mainApp

    init() {
        _activeProfileID = Published(initialValue:
            UserDefaults.standard.string(forKey: "activeProfileID").flatMap(UUID.init))
        _selectedServiceID = Published(initialValue:
            UserDefaults.standard.string(forKey: "selectedServiceID"))
        _launchAtLogin = Published(initialValue: SMAppService.mainApp.status == .enabled)
        refreshHelperStatus()
    }

    func setLaunchAtLogin(_ enabled: Bool) async {
        do {
            if enabled {
                try loginService.register()
            } else {
                try await loginService.unregister()
            }
        } catch {
            helperError = error.localizedDescription
        }
        launchAtLogin = loginService.status == .enabled
    }

    func refreshHelperStatus() {
        helperStatus = daemonService.status
    }

    func installHelper() async {
        isWorkingOnHelper = true
        defer { isWorkingOnHelper = false }
        do {
            try daemonService.register()
            refreshHelperStatus()
            await pingInternal()
        } catch {
            helperError = error.localizedDescription
        }
    }

    func uninstallHelper() async {
        isWorkingOnHelper = true
        defer { isWorkingOnHelper = false }
        do {
            try await daemonService.unregister()
            refreshHelperStatus()
            helperVersion = nil
        } catch {
            helperError = error.localizedDescription
        }
    }

    func pingHelper() async {
        isWorkingOnHelper = true
        defer { isWorkingOnHelper = false }
        await pingInternal()
    }

    private func pingInternal() async {
        do {
            helperVersion = try await helperClient.helperVersion()
        } catch {
            helperVersion = nil
        }
    }

    func fetchServices() async {
        isFetchingServices = true
        defer { isFetchingServices = false }
        do {
            networkServices = try await helperClient.listServices().compactMap(NetworkService.init)
        } catch {
            helperError = error.localizedDescription
        }
    }

    func applyProfile(_ profile: DNSProfile) async {
        guard helperStatus == .enabled else {
            helperError = String(localized: "Helper non installé — ouvre Réglages → Helper")
            return
        }
        if networkServices.isEmpty { await fetchServices() }
        guard let serviceID = effectiveServiceID() else {
            helperError = String(localized: "Aucun service réseau disponible")
            return
        }
        // Probe servers concurrently with the XPC call (DHCP = no probe)
        let probe: Task<Bool, Never>? = profile.servers.isEmpty
            ? nil
            : Task.detached { await probeAnyDNSServer(profile.servers) }
        do {
            try await helperClient.setDNS(serviceID: serviceID, servers: profile.servers)
            activeProfileID = profile.id
            applySuccess = true
            Task { try? await Task.sleep(for: .seconds(1.5)); applySuccess = false }
            if !(await probe?.value ?? true) {
                let msg = String(localized: "Serveur DNS injoignable — la connexion pourrait être affectée")
                helperError = msg
                Task {
                    try? await Task.sleep(for: .seconds(5))
                    if helperError == msg { helperError = nil }
                }
            } else {
                helperError = nil
            }
        } catch {
            probe?.cancel()
            helperError = error.localizedDescription
        }
    }

    func effectiveServiceID() -> String? {
        if let id = selectedServiceID { return id }
        if let svc = networkServices.first(where: { $0.active }) { return svc.id }
        return networkServices.first?.id
    }
}

// MARK: - DNS Probe (file-scope, actor-free)

private func probeAnyDNSServer(_ servers: [String]) async -> Bool {
    await withTaskGroup(of: Bool.self) { group in
        for server in servers {
            group.addTask { await probeDNSServer(server) }
        }
        for await ok in group {
            if ok { group.cancelAll(); return true }
        }
        return false
    }
}

private func probeDNSServer(_ address: String, timeout: TimeInterval = 2) async -> Bool {
    await withCheckedContinuation { cont in
        let conn = NWConnection(
            to: .hostPort(host: NWEndpoint.Host(address), port: 53),
            using: .udp
        )
        let q = DispatchQueue(label: "dnsflip.probe")
        var done = false
        let finish: (Bool) -> Void = { ok in
            q.async {
                guard !done else { return }
                done = true
                conn.cancel()
                cont.resume(returning: ok)
            }
        }
        conn.stateUpdateHandler = { state in
            switch state {
            case .ready:
                conn.send(content: dnsQueryData(), completion: .contentProcessed { _ in })
                conn.receive(minimumIncompleteLength: 1, maximumLength: 512) { data, _, _, error in
                    finish(data != nil && error == nil)
                }
            case .failed, .cancelled:
                finish(false)
            default: break
            }
        }
        conn.start(queue: .global())
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { finish(false) }
    }
}

private func dnsQueryData() -> Data {
    // Minimal DNS A query for "dns.google."
    var d = Data([0x12, 0x34, 0x01, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
    d += Data([3, 0x64, 0x6e, 0x73, 6, 0x67, 0x6f, 0x6f, 0x67, 0x6c, 0x65, 0x00])
    d += Data([0x00, 0x01, 0x00, 0x01])
    return d
}
