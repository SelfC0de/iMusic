import Foundation
import UIKit

struct Playlist: Identifiable, Codable {
    var id: String = UUID().uuidString
    var name: String
    var tracks: [Track] = []
    var coverImageData: Data? = nil

    var coverImage: UIImage? {
        guard let data = coverImageData else { return nil }
        return UIImage(data: data)
    }
}

final class LibraryStore: ObservableObject {
    static let shared = LibraryStore()

    @Published var favorites: [Track] = []
    @Published var downloaded: [Track] = []
    @Published var recentlyPlayed: [Track] = []
    @Published var playlists: [Playlist] = []

    private let favKey    = "im_favorites"
    private let dlKey     = "im_downloaded"
    private let recentKey = "im_recent"
    private let plKey     = "im_playlists"

    private init() { load() }

    // MARK: – Favorites
    func toggleFavorite(_ track: Track) {
        if isFavorite(track) { favorites.removeAll { $0.id == track.id } }
        else { favorites.insert(track, at: 0) }
        save()
    }
    func isFavorite(_ track: Track) -> Bool { favorites.contains { $0.id == track.id } }

    // MARK: – Downloads
    func saveDownloaded(track: Track, localURL: URL) {
        if !downloaded.contains(where: { $0.id == track.id }) {
            downloaded.insert(track, at: 0)
            save()
        }
    }
    func removeDownloaded(_ track: Track) {
        if let url = DownloadManager.shared.localFileURL(for: track) {
            try? FileManager.default.removeItem(at: url)
        }
        downloaded.removeAll { $0.id == track.id }
        save()
    }

    // MARK: – Recent
    func addToRecent(_ track: Track) {
        recentlyPlayed.removeAll { $0.id == track.id }
        recentlyPlayed.insert(track, at: 0)
        if recentlyPlayed.count > 50 { recentlyPlayed = Array(recentlyPlayed.prefix(50)) }
        save()
    }
    func clearRecent() {
        recentlyPlayed.removeAll()
        save()
    }

    // MARK: – Playlists
    func createPlaylist(name: String) {
        let pl = Playlist(name: name.trimmed.isEmpty ? "Плейлист" : name.trimmed)
        playlists.insert(pl, at: 0)
        save()
    }

    func deletePlaylist(_ playlist: Playlist) {
        playlists.removeAll { $0.id == playlist.id }
        save()
    }

    func renamePlaylist(_ playlist: Playlist, name: String) {
        guard let idx = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        playlists[idx].name = name.trimmed.isEmpty ? playlists[idx].name : name.trimmed
        save()
    }

    func setPlaylistCover(_ playlist: Playlist, image: UIImage) {
        guard let idx = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        playlists[idx].coverImageData = image.jpegData(compressionQuality: 0.7)
        save()
    }

    func addToPlaylist(_ track: Track, playlist: Playlist) {
        guard let idx = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        guard !playlists[idx].tracks.contains(where: { $0.id == track.id }) else { return }
        playlists[idx].tracks.append(track)
        save()
    }

    func removeFromPlaylist(_ track: Track, playlist: Playlist) {
        guard let idx = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        playlists[idx].tracks.removeAll { $0.id == track.id }
        save()
    }

    func isInPlaylist(_ track: Track, playlist: Playlist) -> Bool {
        playlist.tracks.contains { $0.id == track.id }
    }

    func savePlaylists() { save() }

    // MARK: – Persistence
    private func save() {
        if let d = try? JSONEncoder().encode(favorites)      { UserDefaults.standard.set(d, forKey: favKey) }
        if let d = try? JSONEncoder().encode(downloaded)     { UserDefaults.standard.set(d, forKey: dlKey) }
        if let d = try? JSONEncoder().encode(recentlyPlayed) { UserDefaults.standard.set(d, forKey: recentKey) }
        if let d = try? JSONEncoder().encode(playlists)      { UserDefaults.standard.set(d, forKey: plKey) }
    }

    private func load() {
        if let d = UserDefaults.standard.data(forKey: favKey),
           let v = try? JSONDecoder().decode([Track].self, from: d) { favorites = v }
        if let d = UserDefaults.standard.data(forKey: dlKey),
           let v = try? JSONDecoder().decode([Track].self, from: d) { downloaded = v }
        if let d = UserDefaults.standard.data(forKey: recentKey),
           let v = try? JSONDecoder().decode([Track].self, from: d) { recentlyPlayed = v }
        if let d = UserDefaults.standard.data(forKey: plKey),
           let v = try? JSONDecoder().decode([Playlist].self, from: d) { playlists = v }
    }
}

