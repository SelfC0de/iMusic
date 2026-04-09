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
    @State private var showAddToPlaylist = false

    var body: some View {
        HStack(spacing: 12) {
            coverView
            infoView
            Spacer(minLength: 8)
            trailingControls
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(isPlaying ? Theme.accentGlow : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            onPlay?() ?? player.play(track: track, queue: queue, index: index)
            SettingsStore.shared.triggerHaptic(.medium)
        }
        .onLongPressGesture {
            showMenu = true
            SettingsStore.shared.triggerHaptic(.heavy)
        }
        .confirmationDialog(track.title, isPresented: $showMenu, titleVisibility: .visible) {
            Button(library.isFavorite(track) ? "Убрать из избранного" : "Добавить в избранное") {
                library.toggleFavorite(track)
                toast.show(library.isFavorite(track) ? "Добавлено в избранное" : "Удалено из избранного", style: .success)
            }
            if !library.playlists.isEmpty {
                Button("Добавить в плейлист") {
                    showAddToPlaylist = true
                }
            }
            if downloads.localFileURL(for: track) != nil {
                Button("Удалить загрузку", role: .destructive) {
                    library.removeDownloaded(track)
                    toast.show("Удалено", style: .warning)
                }
            }
            Button("Отмена", role: .cancel) {}
        }
        .sheet(isPresented: $showAddToPlaylist) {
            AddToPlaylistSheet(track: track)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: Cover

    private var coverView: some View {
        ZStack {
            CachedAsyncImage(url: track.coverURL)
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 0.5))

            if isPlaying {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(0.45))
                    .frame(width: 50, height: 50)
                EqualizerBars()
                    .frame(width: 22, height: 18)
            }
        }
    }

    // MARK: Info

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

    // MARK: Trailing Controls

    private var trailingControls: some View {
        HStack(spacing: 10) {
            // Favourite mini
            if library.isFavorite(track) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.accentDim)
            }

            // Duration + source dot
            HStack(spacing: 4) {
                Circle()
                    .fill(track.source == .source1 ? Theme.accent : Theme.accentBright)
                    .frame(width: 5, height: 5)
                    .opacity(0.7)
                Text(track.duration)
                    .font(.system(size: 11, weight: .regular).monospacedDigit())
                    .foregroundColor(Theme.textTertiary)
            }
            .frame(minWidth: 36, alignment: .trailing)

            // Download button with circular indicator
            CircularDownloadButton(track: track)
        }
    }
}

// MARK: – Circular Download Button

struct CircularDownloadButton: View {
    let track: Track?
    @ObservedObject var downloads = DownloadManager.shared
    @EnvironmentObject var toast: ToastManager

    private var trackId: String { track?.id ?? "" }

    private var task: DownloadManager.DownloadTask? {
        downloads.downloads[trackId]
    }
    private var isCompleted: Bool { task?.isCompleted ?? false }
    private var inProgress: Bool { task != nil && !isCompleted }
    private var progress: Double { task?.progress ?? 0 }

    var body: some View {
        Button {
            guard let t = track else { return }
            if isCompleted { return }
            DownloadManager.shared.download(track: t)
            toast.show("Скачивание...", style: .info, position: .top)
            SettingsStore.shared.triggerHaptic(.light)
        } label: {
            ZStack {
                Circle()
                    .fill(isCompleted ? Theme.accent.opacity(0.15) : Theme.surface)
                    .frame(width: 36, height: 36)
                    .overlay(Circle().stroke(Theme.border, lineWidth: 0.5))

                if inProgress {
                    // Track ring
                    Circle()
                        .stroke(Theme.bg3, lineWidth: 3)
                        .frame(width: 26, height: 26)
                    // Progress ring
                    Circle()
                        .trim(from: 0, to: CGFloat(progress))
                        .stroke(
                            Theme.accentBright,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 26, height: 26)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.25), value: progress)

                    // Pause icon while downloading
                    Image(systemName: "pause.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Theme.accentBright)
                } else if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Theme.accentBright)
                } else {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.textTertiary)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isCompleted || inProgress)
        .frame(width: 36, height: 36)
    }
}

// MARK: – Equalizer Bars

struct EqualizerBars: View {
    @State private var heights: [CGFloat] = [0.4, 0.8, 0.5, 1.0]
    let timer = Timer.publish(every: 0.18, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Theme.accentBright)
                    .frame(width: 3, height: 18 * heights[i])
                    .animation(.easeInOut(duration: 0.18), value: heights[i])
            }
        }
        .onReceive(timer) { _ in
            heights = (0..<4).map { _ in CGFloat.random(in: 0.2...1.0) }
        }
    }
}

// MARK: – Add To Playlist Sheet

struct AddToPlaylistSheet: View {
    let track: Track
    @EnvironmentObject var library: LibraryStore
    @EnvironmentObject var toast: ToastManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(library.playlists) { pl in
                        let already = library.isInPlaylist(track, playlist: pl)
                        Button {
                            if already {
                                library.removeFromPlaylist(track, playlist: pl)
                                toast.show("Удалено из «\(pl.name)»", style: .info, position: .top)
                            } else {
                                library.addToPlaylist(track, playlist: pl)
                                toast.show("Добавлено в «\(pl.name)»", style: .success, position: .top)
                            }
                            SettingsStore.shared.triggerHaptic(.light)
                        } label: {
                            HStack(spacing: 14) {
                                // Cover
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Theme.accentGlow)
                                        .frame(width: 44, height: 44)
                                    if let img = pl.coverImage {
                                        Image(uiImage: img)
                                            .resizable().scaledToFill()
                                            .frame(width: 44, height: 44)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    } else {
                                        Image(systemName: "music.note.list")
                                            .font(.system(size: 16))
                                            .foregroundColor(Theme.accentBright)
                                    }
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(pl.name)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(Theme.textPrimary)
                                        .lineLimit(1)
                                    Text("\(pl.tracks.count) треков")
                                        .font(.system(size: 12))
                                        .foregroundColor(Theme.textSecondary)
                                }

                                Spacer()

                                Image(systemName: already ? "checkmark.circle.fill" : "plus.circle")
                                    .font(.system(size: 22))
                                    .foregroundColor(already ? Theme.accentBright : Theme.textTertiary)
                                    .animation(.spring(response: 0.25, dampingFraction: 0.6), value: already)
                            }
                            .padding(12)
                            .background(Theme.surface)
                            .cornerRadius(Theme.cornerMd)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.cornerMd)
                                    .stroke(already ? Theme.accent : Theme.border, lineWidth: already ? 1 : 0.5)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(Theme.bg1)
            .navigationTitle("Добавить в плейлист")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") { dismiss() }
                        .foregroundColor(Theme.accent)
                        .font(.system(size: 15, weight: .semibold))
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
