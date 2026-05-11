import Foundation

struct DNSProfile: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var servers: [String]

    init(id: UUID = UUID(), name: String, servers: [String]) {
        self.id = id
        self.name = name
        self.servers = servers
    }
}

extension DNSProfile {
    static let defaults: [DNSProfile] = [
        DNSProfile(name: "DHCP (défaut)", servers: []),
        DNSProfile(name: "Cloudflare", servers: ["1.1.1.1", "1.0.0.1"]),
        DNSProfile(name: "Google", servers: ["8.8.8.8", "8.8.4.4"]),
        DNSProfile(name: "Quad9", servers: ["9.9.9.9", "149.112.112.112"]),
        DNSProfile(name: "OpenDNS", servers: ["208.67.222.222", "208.67.220.220"]),
    ]
}
