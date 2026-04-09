import SwiftUI

struct PlayerView: View {
    @EnvironmentObject var player: AudioPlayerManager
    @EnvironmentObject var library: LibraryStore
    @EnvironmentObject var toast: ToastManager

    @State private var isDragging = false
    @State private var dragProgress: Double = 0
    @State private var showQueue = false

    var body: some View {
        VStack(spacing: 0) {
            headerRow
            Spacer()
            if player.currentTrack == nil {
                emptyPlayer
            } else {
                albumArt
                Spacer()
                trackInfo
                Spacer().frame(height: 24)
                progressSection
                Spacer().frame(height: 28)
                controls
                Spacer().frame(height: 28)
                extraControls
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .background(Theme.bg0)
        .sheet(isPresented: $showQueue) {
            QueueSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var headerRow: some View {
        HStack {
            Text("Плеер")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(Theme.textPrimary)
            Spacer()
            if player.currentTrack != nil {
                Button {
                    showQueue = true
                } label: {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 18))
                        .foregroundColor(Theme.textSecondary)
                }
            }
        }
        .padding(.top, 56)
        .padding(.bottom, 8)
    }

    private var emptyPlayer: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().fill(Theme.accentGlow).frame(width: 120, height: 120)
                Image(systemName: "waveform")
                    .font(.system(size: 52))
                    .foregroundColor(Theme.accentDim)
            }
            VStack(spacing: 8) {
                Text("Ничего не играет")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                Text("Найди трек во вкладке Поиск")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.textTertiary)
            }
        }
    }

    private var albumArt: some View {
        ZStack {
            CachedAsyncImage(url: player.currentTrack?.coverURL ?? "")
                .frame(width: UIScreen.main.bounds.width - 80, height: UIScreen.main.bounds.width - 80)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: Theme.shadowAccent, radius: player.isPlaying ? 30 : 10)
                .scaleEffect(player.isPlaying ? 1.0 : 0.9)
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: player.isPlaying)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Theme.border, lineWidth: 0.5)
                )
        }
    }

    private var trackInfo: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(player.currentTrack?.title ?? "")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
                Text(player.currentTrack?.artist ?? "")
                    .font(.system(size: 15))
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            Button {
                if let track = player.currentTrack {
                    library.toggleFavorite(track)
                    toast.show(
                        library.isFavorite(track) ? "Добавлено в избранное" : "Удалено из избранного",
                        style: .success, position: .slideLeft
                    )
                    SettingsStore.shared.triggerHaptic(.medium)
                }
            } label: {
                Image(systemName: player.currentTrack.map { library.isFavorite($0) } ?? false ? "heart.fill" : "heart")
                    .font(.system(size: 22))
                    .foregroundColor(player.currentTrack.map { library.isFavorite($0) } ?? false ? Theme.accentBright : Theme.textTertiary)
                    .scaleEffect(player.currentTrack.map { library.isFavorite($0) } ?? false ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.5), value: player.currentTrack.map { library.isFavorite($0) } ?? false)
            }
        }
    }

    private var progressSection: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.bg3)
                        .frame(height: 4)
                    Capsule()
                        .fill(
                            LinearGradient(colors: [Theme.accentDim, Theme.accentBright], startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: geo.size.width * (isDragging ? dragProgress : player.progress), height: 4)
                    Circle()
                        .fill(Theme.accentBright)
                        .frame(width: isDragging ? 16 : 12, height: isDragging ? 16 : 12)
                        .offset(x: geo.size.width * (isDragging ? dragProgress : player.progress) - (isDragging ? 8 : 6))
                        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isDragging)
                }
                .frame(height: 20)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { val in
                            isDragging = true
                            dragProgress = min(max(val.location.x / geo.size.width, 0), 1)
                        }
                        .onEnded { val in
                            let p = min(max(val.location.x / geo.size.width, 0), 1)
                            player.seek(to: p * player.duration)
                            isDragging = false
                        }
                )
            }
            .frame(height: 20)

            HStack {
                Text(player.formattedTime(isDragging ? dragProgress * player.duration : player.currentTime))
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundColor(Theme.textTertiary)
                Spacer()
                Text(player.formattedTime(player.duration))
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundColor(Theme.textTertiary)
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 0) {
            Button {
                player.playPrevious()
                SettingsStore.shared.triggerHaptic(.medium)
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 26))
                    .foregroundColor(Theme.textPrimary)
                    .frame(maxWidth: .infinity)
            }

            Button {
                player.togglePlayPause()
                SettingsStore.shared.triggerHaptic(.medium)
            } label: {
                ZStack {
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: 70, height: 70)
                        .shadow(color: Theme.shadowAccent, radius: 16)
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .offset(x: player.isPlaying ? 0 : 2)
                }
            }

            Button {
                player.playNext()
                SettingsStore.shared.triggerHaptic(.medium)
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 26))
                    .foregroundColor(Theme.textPrimary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var extraControls: some View {
        HStack {
            Button {
                player.isShuffled.toggle()
                SettingsStore.shared.triggerHaptic(.light)
                toast.show(player.isShuffled ? "Перемешать: вкл" : "Перемешать: выкл", style: .info, position: .top)
            } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: 18))
                    .foregroundColor(player.isShuffled ? Theme.accentBright : Theme.textTertiary)
            }

            Spacer()

            Button {
                if let track = player.currentTrack {
                    DownloadManager.shared.download(track: track)
                    toast.show("Скачивание...", style: .info, position: .top)
                    SettingsStore.shared.triggerHaptic(.light)
                }
            } label: {
                Image(systemName: DownloadManager.shared.isDownloaded(trackId: player.currentTrack?.id ?? "") ? "arrow.down.circle.fill" : "arrow.down.circle")
                    .font(.system(size: 22))
                    .foregroundColor(DownloadManager.shared.isDownloaded(trackId: player.currentTrack?.id ?? "") ? Theme.accent : Theme.textTertiary)
            }

            Spacer()

            Button {
                let modes: [AudioPlayerManager.RepeatMode] = [.none, .one, .all]
                let current = player.repeatMode
                let idx = modes.firstIndex(where: {
                    switch ($0, current) {
                    case (.none, .none), (.one, .one), (.all, .all): return true
                    default: return false
                    }
                }) ?? 0
                player.repeatMode = modes[(idx + 1) % modes.count]
                SettingsStore.shared.triggerHaptic(.light)
            } label: {
                Image(systemName: repeatIcon)
                    .font(.system(size: 18))
                    .foregroundColor(repeatActive ? Theme.accentBright : Theme.textTertiary)
            }
        }
        .padding(.horizontal, 8)
    }

    private var repeatIcon: String {
        switch player.repeatMode {
        case .none: return "repeat"
        case .one: return "repeat.1"
        case .all: return "repeat"
        }
    }

    private var repeatActive: Bool {
        switch player.repeatMode {
        case .none: return false
        default: return true
        }
    }
}

struct QueueSheet: View {
    @EnvironmentObject var player: AudioPlayerManager

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(player.queue.enumerated()), id: \.element.id) { idx, track in
                        TrackRow(
                            track: track,
                            isPlaying: player.currentTrack?.id == track.id,
                            queue: player.queue,
                            index: idx
                        )
                        Divider().background(Theme.borderSubtle).padding(.leading, 78)
                    }
                }
                .padding(.bottom, 32)
            }
            .background(Theme.bg1)
            .navigationTitle("Очередь")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }
}
