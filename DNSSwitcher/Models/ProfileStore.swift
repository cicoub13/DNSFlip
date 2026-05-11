import Foundation
import Combine

final class ProfileStore: ObservableObject {
    @Published var profiles: [DNSProfile] = []
    @Published var activeProfileID: UUID?

    private let storageURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("fr.fotozik.DNSSwitcher", isDirectory: true)
        storageURL = dir.appendingPathComponent("profiles.json")

        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            print("ProfileStore: impossible de créer le dossier — \(error)")
        }

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
