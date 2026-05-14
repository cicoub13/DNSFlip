import XCTest
@testable import DNSFlip

final class DNSFlipTests: XCTestCase {

    // MARK: - IP validation

    func testIPv4Valid() {
        XCTAssertTrue(isValidIP("1.1.1.1"))
        XCTAssertTrue(isValidIP("8.8.8.8"))
        XCTAssertTrue(isValidIP("127.0.0.1"))
        XCTAssertTrue(isValidIP("255.255.255.255"))
    }

    func testIPv6Valid() {
        XCTAssertTrue(isValidIP("2606:4700:4700::1111"))
        XCTAssertTrue(isValidIP("::1"))
        XCTAssertTrue(isValidIP("2001:4860:4860::8888"))
    }

    func testIPInvalid() {
        XCTAssertFalse(isValidIP(""))
        XCTAssertFalse(isValidIP("cloudflare.com"))
        XCTAssertFalse(isValidIP("1.1.1.1/32"))
        XCTAssertFalse(isValidIP("256.0.0.1"))
        XCTAssertFalse(isValidIP("not-an-ip"))
    }

    // MARK: - DNSProfile Codable

    func testDNSProfileRoundTrip() throws {
        let original = DNSProfile(name: "Custom", servers: ["1.1.1.1", "1.0.0.1"])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DNSProfile.self, from: data)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.servers, original.servers)
    }

    func testDNSProfileEmptyServers() throws {
        let profile = DNSProfile(name: "DHCP", servers: [])
        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(DNSProfile.self, from: data)
        XCTAssertTrue(decoded.servers.isEmpty)
    }

    // MARK: - ProfileStore

    private func makeTempStore() -> (ProfileStore, URL) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("DNSFlipTest-\(UUID().uuidString).json")
        return (ProfileStore(storageURL: url), url)
    }

    func testProfileStoreLoadsDefaults() {
        let (store, url) = makeTempStore()
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertEqual(store.profiles.count, DNSProfile.defaults.count)
        XCTAssertEqual(store.profiles.first?.name, DNSProfile.defaults.first?.name)
    }

    func testProfileStoreRoundTrip() throws {
        let (store, url) = makeTempStore()
        defer { try? FileManager.default.removeItem(at: url) }

        store.profiles.append(DNSProfile(name: "Custom", servers: ["9.9.9.9"]))
        store.save()

        let store2 = ProfileStore(storageURL: url)
        XCTAssertEqual(store2.profiles.count, DNSProfile.defaults.count + 1)
        XCTAssertEqual(store2.profiles.last?.name, "Custom")
        XCTAssertEqual(store2.profiles.last?.servers, ["9.9.9.9"])
    }

    func testProfileStorePreservesOrder() throws {
        let (store, url) = makeTempStore()
        defer { try? FileManager.default.removeItem(at: url) }

        store.profiles = [
            DNSProfile(name: "B", servers: []),
            DNSProfile(name: "A", servers: ["1.1.1.1"]),
        ]
        store.save()

        let store2 = ProfileStore(storageURL: url)
        XCTAssertEqual(store2.profiles.map(\.name), ["B", "A"])
    }

    // MARK: - AppStore.effectiveServiceID

    private func svc(_ id: String, active: Bool) -> NetworkService {
        NetworkService(["id": id, "name": id, "active": active ? "1" : "0"])!
    }

    @MainActor
    func testEffectiveServiceIDPrefersSelected() {
        let store = AppStore()
        store.selectedServiceID = "svc-1"
        store.networkServices = [svc("svc-1", active: false), svc("svc-2", active: true)]
        XCTAssertEqual(store.effectiveServiceID(), "svc-1")
    }

    @MainActor
    func testEffectiveServiceIDFallsBackToActive() {
        let store = AppStore()
        store.selectedServiceID = nil
        store.networkServices = [svc("svc-1", active: false), svc("svc-2", active: true)]
        XCTAssertEqual(store.effectiveServiceID(), "svc-2")
    }

    @MainActor
    func testEffectiveServiceIDFallsBackToFirst() {
        let store = AppStore()
        store.selectedServiceID = nil
        store.networkServices = [svc("svc-1", active: false), svc("svc-2", active: false)]
        XCTAssertEqual(store.effectiveServiceID(), "svc-1")
    }

    @MainActor
    func testEffectiveServiceIDNilWhenEmpty() {
        let store = AppStore()
        store.selectedServiceID = nil
        store.networkServices = []
        XCTAssertNil(store.effectiveServiceID())
    }

    // MARK: - HelperError

    func testHelperErrorDescription() {
        let desc = HelperError.connectionFailed.errorDescription
        XCTAssertNotNil(desc)
        XCTAssertFalse(desc!.isEmpty)
    }
}
