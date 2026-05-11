import Foundation

final class HelperClient {
    private var connection: NSXPCConnection?

    private func makeConnection() -> NSXPCConnection {
        let c = NSXPCConnection(machServiceName: "fr.fotozik.DNSSwitcher.helper", options: .privileged)
        c.remoteObjectInterface = NSXPCInterface(with: DNSHelperProtocol.self)
        c.invalidationHandler = { [weak self] in self?.connection = nil }
        c.interruptionHandler = { [weak self] in self?.connection = nil }
        c.resume()
        return c
    }

    private func proxy() -> DNSHelperProtocol? {
        if connection == nil { connection = makeConnection() }
        return connection?.remoteObjectProxy as? DNSHelperProtocol
    }

    func helperVersion() async throws -> String {
        guard let proxy = proxy() else { throw HelperError.connectionFailed }
        return try await withCheckedThrowingContinuation { cont in
            proxy.helperVersion { version in cont.resume(returning: version) }
        }
    }

    func setDNS(serviceID: String, servers: [String]) async throws {
        guard let proxy = proxy() else { throw HelperError.connectionFailed }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            proxy.setDNS(serviceID: serviceID, servers: servers) { error in
                if let error { cont.resume(throwing: error) }
                else { cont.resume() }
            }
        }
    }

    func listServices() async throws -> [[String: String]] {
        guard let proxy = proxy() else { throw HelperError.connectionFailed }
        return try await withCheckedThrowingContinuation { cont in
            proxy.listServices { services in cont.resume(returning: services) }
        }
    }
}

enum HelperError: LocalizedError {
    case connectionFailed
    var errorDescription: String? { "Impossible de se connecter au helper." }
}
