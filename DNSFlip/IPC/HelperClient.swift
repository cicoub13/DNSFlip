import Foundation

final class HelperClient {
    private var connection: NSXPCConnection?

    private func makeConnection() -> NSXPCConnection {
        let c = NSXPCConnection(machServiceName: "com.bootstrap.DNSFlip.helper", options: .privileged)
        try? c.setCodeSigningRequirement("anchor apple generic and identifier \"com.bootstrap.DNSFlip.helper\" and certificate leaf[subject.OU] = \"3X7B4F6R56\"")
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
        return try await withTimeout {
            try await withCheckedThrowingContinuation { cont in
                proxy.helperVersion { version in cont.resume(returning: version) }
            }
        }
    }

    func setDNS(serviceID: String, servers: [String]) async throws {
        guard let proxy = proxy() else { throw HelperError.connectionFailed }
        try await withTimeout {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                proxy.setDNS(serviceID: serviceID, servers: servers) { error in
                    if let error { cont.resume(throwing: error) }
                    else { cont.resume() }
                }
            }
        }
    }

    func listServices() async throws -> [[String: String]] {
        guard let proxy = proxy() else { throw HelperError.connectionFailed }
        return try await withTimeout {
            try await withCheckedThrowingContinuation { cont in
                proxy.listServices { services in cont.resume(returning: services) }
            }
        }
    }
}

private func withTimeout<T: Sendable>(seconds: Double = 5, _ work: @escaping @Sendable () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await work() }
        group.addTask {
            try await Task.sleep(for: .seconds(seconds))
            throw HelperError.timeout
        }
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}

enum HelperError: LocalizedError {
    case connectionFailed
    case timeout
    var errorDescription: String? {
        switch self {
        case .connectionFailed: return String(localized: "Impossible de se connecter au helper.")
        case .timeout: return String(localized: "Le helper ne répond pas.")
        }
    }
}
