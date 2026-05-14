import Foundation

private let clientRequirement = "anchor apple generic and identifier \"com.bootstrap.DNSFlip\" and certificate leaf[subject.OU] = \"3X7B4F6R56\""

final class HelperDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        do {
            try connection.setCodeSigningRequirement(clientRequirement)
        } catch {
            return false
        }
        connection.exportedInterface = NSXPCInterface(with: DNSHelperProtocol.self)
        connection.exportedObject = HelperImpl()
        connection.resume()
        return true
    }
}

private func isValidIPAddress(_ address: String) -> Bool {
    var buf = [UInt8](repeating: 0, count: 16)
    return inet_pton(AF_INET, address, &buf) == 1 || inet_pton(AF_INET6, address, &buf) == 1
}

final class HelperImpl: NSObject, DNSHelperProtocol {
    func helperVersion(reply: @escaping (String) -> Void) {
        reply("1")
    }

    func setDNS(serviceID: String, servers: [String], reply: @escaping (Error?) -> Void) {
        guard !serviceID.isEmpty, serviceID.count <= 256 else {
            reply(DNSError.invalidInput)
            return
        }
        guard servers.count <= 8, servers.allSatisfy({ isValidIPAddress($0) }) else {
            reply(DNSError.invalidInput)
            return
        }
        do {
            try DNSConfigurator.setDNS(serviceID: serviceID, servers: servers)
            reply(nil)
        } catch {
            reply(error)
        }
    }

    func listServices(reply: @escaping ([[String: String]]) -> Void) {
        reply(DNSConfigurator.listServices())
    }
}

let listener = NSXPCListener(machServiceName: "com.bootstrap.DNSFlip.helper")
let helperDelegate = HelperDelegate()
listener.delegate = helperDelegate
listener.resume()
RunLoop.main.run()
