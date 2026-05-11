import Foundation

final class HelperDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.exportedInterface = NSXPCInterface(with: DNSHelperProtocol.self)
        connection.exportedObject = HelperImpl()
        connection.resume()
        return true
    }
}

final class HelperImpl: NSObject, DNSHelperProtocol {
    func helperVersion(reply: @escaping (String) -> Void) {
        reply("1")
    }

    func setDNS(serviceID: String, servers: [String], reply: @escaping (Error?) -> Void) {
        reply(NSError(domain: "fr.fotozik.DNSSwitcher.helper", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "Not implemented yet"]))
    }

    func listServices(reply: @escaping ([[String: String]]) -> Void) {
        reply([])
    }
}

let listener = NSXPCListener(machServiceName: "fr.fotozik.DNSSwitcher.helper")
let helperDelegate = HelperDelegate()
listener.delegate = helperDelegate
listener.resume()
RunLoop.main.run()
