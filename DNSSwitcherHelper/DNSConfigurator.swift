import Foundation
import SystemConfiguration

enum DNSError: LocalizedError {
    case preferencesOpen
    case lock
    case serviceNotFound(String)
    case protocolNotFound
    case setFailed
    case commit
    case apply

    var errorDescription: String? {
        switch self {
        case .preferencesOpen:        return "Cannot open system preferences"
        case .lock:                   return "Cannot lock preferences"
        case .serviceNotFound(let id): return "Service not found: \(id)"
        case .protocolNotFound:       return "DNS protocol not found for service"
        case .setFailed:              return "Cannot set DNS configuration"
        case .commit:                 return "Cannot commit preferences"
        case .apply:                  return "Cannot apply preferences"
        }
    }
}

enum DNSConfigurator {
    static func setDNS(serviceID: String, servers: [String]) throws {
        guard let prefs = SCPreferencesCreate(nil, "fr.fotozik.DNSSwitcher.helper" as CFString, nil) else {
            throw DNSError.preferencesOpen
        }
        guard SCPreferencesLock(prefs, true) else {
            throw DNSError.lock
        }
        defer { SCPreferencesUnlock(prefs) }

        guard let service = SCNetworkServiceCopy(prefs, serviceID as CFString) else {
            throw DNSError.serviceNotFound(serviceID)
        }
        guard let proto = SCNetworkServiceCopyProtocol(service, kSCNetworkProtocolTypeDNS) else {
            throw DNSError.protocolNotFound
        }

        // nil resets to DHCP-assigned DNS; non-empty replaces the entire DNS config for this service
        let config: CFDictionary? = servers.isEmpty ? nil : [kSCPropNetDNSServerAddresses: servers] as CFDictionary
        guard SCNetworkProtocolSetConfiguration(proto, config) else {
            throw DNSError.setFailed
        }
        guard SCPreferencesCommitChanges(prefs) else {
            throw DNSError.commit
        }
        guard SCPreferencesApplyChanges(prefs) else {
            throw DNSError.apply
        }
    }

    static func listServices() -> [[String: String]] {
        guard let prefs = SCPreferencesCreate(nil, "fr.fotozik.DNSSwitcher.helper" as CFString, nil),
              let services = SCNetworkServiceCopyAll(prefs) as? [SCNetworkService] else {
            return []
        }
        return services.compactMap { service in
            guard let id = SCNetworkServiceGetServiceID(service) as String?,
                  let name = SCNetworkServiceGetName(service) as String? else { return nil }
            return [
                "id": id,
                "name": name,
                "active": SCNetworkServiceGetEnabled(service) ? "1" : "0"
            ]
        }
    }
}
