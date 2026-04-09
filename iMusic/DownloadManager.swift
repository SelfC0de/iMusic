import Foundation
import Combine

final class DownloadManager: ObservableObject {
    static let shared = DownloadManager()

    @Published var downloads: [String: DownloadTask] = [:]

    struct DownloadTask {
        let trackId: String
        var progress: Double
        var isCompleted: Bool
        var localURL: URL?
    }

    private var urlSession: URLSession!
    private var taskMap: [URLSessionTask: String] = [:]

    private init() {
        let config = URLSessionConfiguration.background(withIdentifier: "com.imusic.downloads")
        config.isDiscretionary = false
        urlSession = URLSession(configuration: config, delegate: nil, delegateQueue: nil)
    }

    func download(track: Track) {
        guard downloads[track.id] == nil else { return }
        guard let url = URL(string: track.downloadURL) else { return }

        downloads[track.id] = DownloadTask(trackId: track.id, progress: 0, isCompleted: false)

        let fileName = sanitizeFilename("\(track.artist) - \(track.title).mp3")
        let destURL = localURL(for: fileName)

        if FileManager.default.fileExists(atPath: destURL.path) {
            DispatchQueue.main.async {
                self.downloads[track.id] = DownloadTask(trackId: track.id, progress: 1, isCompleted: true, localURL: destURL)
            }
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")

        let task = urlSession.dataTask(with: request)

        Task {
            do {
                let (tempURL, response) = try await URLSession.shared.download(for: request)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    await MainActor.run { self.downloads[track.id] = nil }
                    return
                }
                try? FileManager.default.createDirectory(at: destURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? FileManager.default.moveItem(at: tempURL, to: destURL)
                await MainActor.run {
                    self.downloads[track.id] = DownloadTask(trackId: track.id, progress: 1, isCompleted: true, localURL: destURL)
                }
                LibraryStore.shared.saveDownloaded(track: track, localURL: destURL)
            } catch {
                await MainActor.run { self.downloads[track.id] = nil }
            }
        }
    }

    func isDownloaded(trackId: String) -> Bool {
        downloads[trackId]?.isCompleted == true
    }

    func progress(for trackId: String) -> Double {
        downloads[trackId]?.progress ?? 0
    }

    private func localURL(for filename: String) -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("Downloads/\(filename)")
    }

    private func sanitizeFilename(_ name: String) -> String {
        let illegal = CharacterSet(charactersIn: "/\\:*?\"<>|")
        return name.components(separatedBy: illegal).joined(separator: "_")
    }

    func localFileURL(for track: Track) -> URL? {
        let fileName = sanitizeFilename("\(track.artist) - \(track.title).mp3")
        let url = localURL(for: fileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}
