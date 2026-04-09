import SwiftUI

struct TrackRow: View {
    let track: Track
    let isPlaying: Bool
    var queue: [Track] = []
    var index: Int = 0
    var onPlay: (() -> Void)? = nil

    @EnvironmentObject var player: AudioPlayerManager
    @EnvironmentObject var library: LibraryStore
    @EnvironmentObject var toast: ToastManager
    @ObservedObject var downloads = DownloadManager.shared
    @State private var showMenu = false

    var body: some View {
        HStack(spacing: 12) {
            coverView
            infoView
            Spacer()
            trailingView
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(isPlaying ? Theme.accentGlow : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            if let custom = onPlay {
                custom()
            } else {
                player.play(track: track, queue: queue, index: index)
            }
            SettingsStore.shared.triggerHaptic(.medium)
        }
        .onLongPressGesture {
            showMenu = true
            SettingsStore.shared.triggerHaptic(.heavy)
        }
        .confirmationDialog(track.title, isPresented: $showMenu, titleVisibility: .visible) {
            Button("Добавить в избранное") {
                library.toggleFavorite(track)
                toast.show(library.isFavorite(track) ? "Добавлено в избранное" : "Удалено из избранного", style: .success)
            }
            Button("Скачать") {
                DownloadManager.shared.download(track: track)
                toast.show("Скачивание началось", style: .info)
            }
            if let local = DownloadManager.shared.localFileURL(for: track) {
                Button("Удалить загрузку", role: .destructive) {
                    library.removeDownloaded(track)
                    toast.show("Удалено", style: .warning)
                }
            }
            Button("Отмена", role: .cancel) {}
        }
    }

    private var coverView: some View {
        ZStack {
            CachedAsyncImage(url: track.coverURL)
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Theme.border, lineWidth: 0.5)
                )

            if isPlaying {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(0.45))
                    .frame(width: 50, height: 50)
                EqualizerBars()
                    .frame(width: 22, height: 18)
            }
        }
    }

    private var infoView: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(track.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isPlaying ? Theme.accentBright : Theme.textPrimary)
                .lineLimit(1)
            Text(track.artist)
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)
                .lineLimit(1)
        }
    }

    private var trailingView: some View {
        HStack(spacing: 14) {
            if let task = downloads.downloads[track.id], !task.isCompleted {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Theme.accent))
                    .scaleEffect(0.75)
            } else if downloads.isDownloaded(trackId: track.id) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.accent.opacity(0.7))
            }

            if library.isFavorite(track) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.accent)
            }

            Text(track.duration)
                .font(.system(size: 12, weight: .regular).monospacedDigit())
                .foregroundColor(Theme.textTertiary)
        }
    }
}

struct EqualizerBars: View {
    @State private var heights: [CGFloat] = [0.3, 0.7, 0.5, 0.9]

    let timer = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Theme.accentBright)
                    .frame(width: 3, height: 18 * heights[i])
                    .animation(.easeInOut(duration: 0.2), value: heights[i])
            }
        }
        .onReceive(timer) { _ in
            heights = heights.map { _ in CGFloat.random(in: 0.2...1.0) }
        }
    }
}
