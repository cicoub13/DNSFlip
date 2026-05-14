import Foundation
import Combine

final class ProfileStore: ObservableObject {
    @Published var profiles: [DNSProfile] = []

    private let storageURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("com.bootstrap.DNSFlip", isDirectory: true)
        storageURL = dir.appendingPathComponent("profiles.json")

        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            print("ProfileStore: impossible de créer le dossier — \(error)")
        }

        load()
    }

    init(storageURL: URL) {
        self.storageURL = storageURL
        load()
    }

    func save() {
        do {
            let data = try JSONEncoder().encode(profiles)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            print("ProfileStore: sauvegarde échouée — \(error)")
        }
    }

    func add(_ profile: DNSProfile) {
        profiles.append(profile)
        save()
    }

    func update(_ profile: DNSProfile) {
        guard let idx = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        profiles[idx] = profile
        save()
    }

    func delete(id: UUID) {
        profiles.removeAll { $0.id == id }
        save()
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        profiles.move(fromOffsets: source, toOffset: destination)
        save()
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            profiles = DNSProfile.defaults
            save()
            return
        }
        do {
            let data = try Data(contentsOf: storageURL)
            profiles = try JSONDecoder().decode([DNSProfile].self, from: data)
        } catch {
            print("ProfileStore: chargement échoué — \(error)")
            profiles = DNSProfile.defaults
        }
    }
}
