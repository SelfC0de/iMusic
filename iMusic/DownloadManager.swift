import Foundation
import Combine

final class DownloadManager: NSObject, ObservableObject {
    static let shared = DownloadManager()

    @Published var downloads: [String: DownloadTask] = [:]

    struct DownloadTask {
        let trackId: String
        var progress: Double
        var isCompleted: Bool
        var localURL: URL?
    }

    private var session: URLSession!
    private var taskToTrackId: [Int: String] = [:]
    private var trackToDestURL: [String: URL] = [:]

    private override init() {
        super.init()
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    func download(track: Track) {
        guard downloads[track.id] == nil else { return }

        let destURL = localURL(for: track)

        if FileManager.default.fileExists(atPath: destURL.path) {
            DispatchQueue.main.async {
                self.downloads[track.id] = DownloadTask(trackId: track.id, progress: 1, isCompleted: true, localURL: destURL)
            }
            LibraryStore.shared.saveDownloaded(track: track, localURL: destURL)
            return
        }

        guard let url = URL(string: track.downloadURL) else { return }

        DispatchQueue.main.async {
            self.downloads[track.id] = DownloadTask(trackId: track.id, progress: 0, isCompleted: false)
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")

        let task = session.downloadTask(with: request)
        trackToDestURL[track.id] = destURL
        taskToTrackId[task.taskIdentifier] = track.id
        task.resume()
    }

    func isDownloaded(trackId: String) -> Bool {
        downloads[trackId]?.isCompleted == true
    }

    func localFileURL(for track: Track) -> URL? {
        let url = localURL(for: track)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private func localURL(for track: Track) -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let name = sanitize("\(track.artist) - \(track.title).mp3")
        return docs.appendingPathComponent("Downloads/\(name)")
    }

    private func sanitize(_ name: String) -> String {
        name.components(separatedBy: CharacterSet(charactersIn: "/\\:*?\"<>|")).joined(separator: "_")
    }
}

extension DownloadManager: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let trackId = taskToTrackId[downloadTask.taskIdentifier] else { return }
        let progress: Double
        if totalBytesExpectedToWrite > 0 {
            progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        } else {
            progress = 0
        }
        DispatchQueue.main.async {
            self.downloads[trackId]?.progress = progress
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let trackId = taskToTrackId[downloadTask.taskIdentifier],
              let destURL = trackToDestURL[trackId] else { return }

        do {
            try FileManager.default.createDirectory(at: destURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.moveItem(at: location, to: destURL)

            DispatchQueue.main.async {
                self.downloads[trackId] = DownloadTask(trackId: trackId, progress: 1, isCompleted: true, localURL: destURL)
                self.taskToTrackId.removeValue(forKey: downloadTask.taskIdentifier)
                self.trackToDestURL.removeValue(forKey: trackId)
            }

            // Find track in library to save
            let allTracks = LibraryStore.shared.favorites + LibraryStore.shared.downloaded + LibraryStore.shared.recentlyPlayed
            if let track = allTracks.first(where: { $0.id == trackId }) {
                LibraryStore.shared.saveDownloaded(track: track, localURL: destURL)
            }
        } catch {
            DispatchQueue.main.async {
                self.downloads.removeValue(forKey: trackId)
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard error != nil,
              let trackId = taskToTrackId[task.taskIdentifier] else { return }
        DispatchQueue.main.async {
            self.downloads.removeValue(forKey: trackId)
            self.taskToTrackId.removeValue(forKey: task.taskIdentifier)
            self.trackToDestURL.removeValue(forKey: trackId)
        }
    }
}
