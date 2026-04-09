import Foundation

final class LibraryStore: ObservableObject {
    static let shared = LibraryStore()

    @Published var favorites: [Track] = []
    @Published var downloaded: [Track] = []
    @Published var recentlyPlayed: [Track] = []

    private let favKey = "im_favorites"
    private let dlKey = "im_downloaded"
    private let recentKey = "im_recent"

    private init() {
        load()
    }

    func toggleFavorite(_ track: Track) {
        if isFavorite(track) {
            favorites.removeAll { $0.id == track.id }
        } else {
            favorites.insert(track, at: 0)
        }
        save()
    }

    func isFavorite(_ track: Track) -> Bool {
        favorites.contains { $0.id == track.id }
    }

    func saveDownloaded(track: Track, localURL: URL) {
        if !downloaded.contains(where: { $0.id == track.id }) {
            var t = track
            downloaded.insert(t, at: 0)
            save()
        }
    }

    func addToRecent(_ track: Track) {
        recentlyPlayed.removeAll { $0.id == track.id }
        recentlyPlayed.insert(track, at: 0)
        if recentlyPlayed.count > 50 { recentlyPlayed = Array(recentlyPlayed.prefix(50)) }
        save()
    }

    func removeDownloaded(_ track: Track) {
        if let url = DownloadManager.shared.localFileURL(for: track) {
            try? FileManager.default.removeItem(at: url)
        }
        downloaded.removeAll { $0.id == track.id }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(favorites) { UserDefaults.standard.set(data, forKey: favKey) }
        if let data = try? JSONEncoder().encode(downloaded) { UserDefaults.standard.set(data, forKey: dlKey) }
        if let data = try? JSONEncoder().encode(recentlyPlayed) { UserDefaults.standard.set(data, forKey: recentKey) }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: favKey),
           let decoded = try? JSONDecoder().decode([Track].self, from: data) { favorites = decoded }
        if let data = UserDefaults.standard.data(forKey: dlKey),
           let decoded = try? JSONDecoder().decode([Track].self, from: data) { downloaded = decoded }
        if let data = UserDefaults.standard.data(forKey: recentKey),
           let decoded = try? JSONDecoder().decode([Track].self, from: data) { recentlyPlayed = decoded }
    }
}
