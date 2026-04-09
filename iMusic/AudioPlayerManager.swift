import Foundation
import AVFoundation
import MediaPlayer
import Combine

final class AudioPlayerManager: NSObject, ObservableObject {
    static let shared = AudioPlayerManager()

    @Published var currentTrack: Track?
    @Published var playerState: PlayerState = .idle
    @Published var currentTime: Double = 0
    @Published var duration: Double = 1
    @Published var volume: Float = 1.0
    @Published var isShuffled = false
    @Published var repeatMode: RepeatMode = .none

    enum RepeatMode { case none, one, all }

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var statusObserver: NSKeyValueObservation?
    private var cancellables = Set<AnyCancellable>()
    var queue: [Track] = []
    private var queueIndex: Int = -1

    private override init() {
        super.init()
        setupRemoteCommands()
    }

    func play(track: Track, queue: [Track] = [], index: Int = 0) {
        self.queue = queue.isEmpty ? [track] : queue
        self.queueIndex = queue.isEmpty ? 0 : index
        loadAndPlay(track)
    }

    private func loadAndPlay(_ track: Track) {
        currentTrack = track
        playerState = .loading

        stopObservers()
        player?.pause()

        guard let url = URL(string: track.streamURL) else {
            playerState = .error("Неверный URL")
            return
        }

        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        player?.volume = volume

        statusObserver = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                switch item.status {
                case .readyToPlay:
                    self?.player?.play()
                    self?.playerState = .playing
                    self?.duration = item.duration.seconds.isNaN ? 1 : item.duration.seconds
                    self?.updateNowPlaying()
                case .failed:
                    self?.playerState = .error(item.error?.localizedDescription ?? "Ошибка")
                default: break
                }
            }
        }

        timeObserver = player?.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            self?.currentTime = time.seconds
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinish),
            name: .AVPlayerItemDidPlayToEndTime,
            object: item
        )
    }

    @objc private func playerDidFinish() {
        switch repeatMode {
        case .one:
            player?.seek(to: .zero)
            player?.play()
        case .all:
            playNext()
        case .none:
            if queueIndex < queue.count - 1 {
                playNext()
            } else {
                playerState = .idle
                currentTime = 0
            }
        }
    }

    func togglePlayPause() {
        guard player != nil else { return }
        if case .playing = playerState {
            player?.pause()
            playerState = .paused
        } else {
            player?.play()
            playerState = .playing
        }
        updateNowPlaying()
    }

    func seek(to time: Double) {
        player?.seek(to: CMTime(seconds: time, preferredTimescale: 600))
        currentTime = time
    }

    func playNext() {
        let nextIndex = isShuffled
            ? Int.random(in: 0..<max(1, queue.count))
            : min(queueIndex + 1, queue.count - 1)
        guard nextIndex < queue.count, nextIndex != queueIndex || queue.count == 1 else { return }
        queueIndex = nextIndex
        loadAndPlay(queue[nextIndex])
    }

    func playPrevious() {
        if currentTime > 3 {
            seek(to: 0)
            return
        }
        let prevIndex = isShuffled
            ? Int.random(in: 0..<max(1, queue.count))
            : max(queueIndex - 1, 0)
        queueIndex = prevIndex
        loadAndPlay(queue[prevIndex])
    }

    func setVolume(_ v: Float) {
        volume = v
        player?.volume = v
    }

    private func stopObservers() {
        if let obs = timeObserver { player?.removeTimeObserver(obs) }
        timeObserver = nil
        statusObserver?.invalidate()
        statusObserver = nil
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
    }

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            self?.player?.play(); self?.playerState = .playing; return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            self?.player?.pause(); self?.playerState = .paused; return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            self?.playNext(); return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            self?.playPrevious(); return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let e = event as? MPChangePlaybackPositionCommandEvent {
                self?.seek(to: e.positionTime)
            }
            return .success
        }
    }

    private func updateNowPlaying() {
        guard let track = currentTrack else { return }
        let info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    var isPlaying: Bool {
        if case .playing = playerState { return true }
        return false
    }

    var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }

    func formattedTime(_ seconds: Double) -> String {
        guard !seconds.isNaN, !seconds.isInfinite else { return "0:00" }
        let s = Int(seconds)
        return "\(s / 60):\(String(format: "%02d", s % 60))"
    }
}
