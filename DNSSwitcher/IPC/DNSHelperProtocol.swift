import Foundation

@objc public protocol DNSHelperProtocol {
    func helperVersion(reply: @escaping (String) -> Void)
    func setDNS(serviceID: String, servers: [String], reply: @escaping (Error?) -> Void)
    func listServices(reply: @escaping ([[String: String]]) -> Void)
}
