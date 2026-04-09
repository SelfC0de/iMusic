import SwiftUI
import AVFoundation

struct PlayerView: View {
    @EnvironmentObject var player: AudioPlayerManager
    @EnvironmentObject var library: LibraryStore
    @EnvironmentObject var toast: ToastManager
    @ObservedObject var downloads = DownloadManager.shared

    @State private var isDragging = false
    @State private var dragProgress: Double = 0
    @State private var showQueue = false

    var body: some View {
        VStack(spacing: 0) {
            headerRow
                .padding(.horizontal, 24)

            if player.currentTrack == nil {
                emptyPlayer
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        albumArt
                            .padding(.top, 12)
                            .padding(.horizontal, 24)

                        trackInfoRow
                            .padding(.horizontal, 24)
                            .padding(.top, 24)

                        progressSection
                            .padding(.horizontal, 24)
                            .padding(.top, 20)

                        mainControls
                            .padding(.horizontal, 24)
                            .padding(.top, 28)

                        secondaryControls
                            .padding(.horizontal, 24)
                            .padding(.top, 24)

                        volumeSection
                            .padding(.horizontal, 24)
                            .padding(.top, 24)

                        Spacer().frame(height: 140)
                    }
                }
            }
        }
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
                Button { showQueue = true } label: {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(Theme.surface)
                        .clipShape(Circle())
                }
            }
        }
        .padding(.top, 56)
        .padding(.bottom, 8)
    }

    private var emptyPlayer: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle().fill(Theme.accentGlow).frame(width: 130, height: 130)
                Image(systemName: "waveform")
                    .font(.system(size: 54))
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
            Spacer()
        }
    }

    private var albumArt: some View {
        let size = UIScreen.main.bounds.width - 80
        return ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(Theme.accentDim.opacity(0.22))
                .frame(width: size, height: size)
                .blur(radius: 30)
                .offset(y: 10)
                .scaleEffect(player.isPlaying ? 1.06 : 0.9)
                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: player.isPlaying)

            CachedAsyncImage(url: player.currentTrack?.coverURL ?? "")
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.border, lineWidth: 0.5))
                .scaleEffect(player.isPlaying ? 1.0 : 0.92)
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: player.isPlaying)
                .shadow(color: .black.opacity(0.5), radius: 24, y: 12)

            if case .loading = player.playerState {
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color.black.opacity(0.55))
                    .frame(width: size, height: size)
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Theme.accentBright))
                    .scaleEffect(1.5)
            }
        }
        .frame(width: size, height: size)
    }

    private var trackInfoRow: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
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

            CircularDownloadButton(track: player.currentTrack)

            let fav = player.currentTrack.map { library.isFavorite($0) } ?? false
            Button {
                guard let track = player.currentTrack else { return }
                library.toggleFavorite(track)
                toast.show(library.isFavorite(track) ? "Добавлено в избранное" : "Удалено", style: .success, position: .slideLeft)
                SettingsStore.shared.triggerHaptic(.medium)
            } label: {
                Image(systemName: fav ? "heart.fill" : "heart")
                    .font(.system(size: 22))
                    .foregroundColor(fav ? Theme.accentBright : Theme.textTertiary)
                    .scaleEffect(fav ? 1.1 : 1.0)
                    .animation(.spring(response: 0.25, dampingFraction: 0.5), value: fav)
            }
        }
    }

    private var progressSection: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.bg3).frame(height: 5)
                    Capsule()
                        .fill(LinearGradient(colors: [Theme.accentDim, Theme.accentBright], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(0, geo.size.width * CGFloat(isDragging ? dragProgress : player.progress)), height: 5)
                    Circle()
                        .fill(Theme.accentBright)
                        .frame(width: isDragging ? 18 : 13, height: isDragging ? 18 : 13)
                        .shadow(color: Theme.accent.opacity(0.6), radius: isDragging ? 8 : 3)
                        .offset(x: max(0, geo.size.width * CGFloat(isDragging ? dragProgress : player.progress) - (isDragging ? 9 : 6.5)))
                        .animation(.spring(response: 0.2, dampingFraction: 0.75), value: isDragging)
                }
                .frame(height: 24)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        isDragging = true
                        dragProgress = min(max(Double(v.location.x / geo.size.width), 0), 1)
                    }
                    .onEnded { v in
                        let p = min(max(Double(v.location.x / geo.size.width), 0), 1)
                        player.seek(to: p * player.duration)
                        isDragging = false
                    }
                )
            }
            .frame(height: 24)

            HStack {
                Text(player.formattedTime(isDragging ? dragProgress * player.duration : player.currentTime))
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundColor(Theme.textTertiary)
                Spacer()
                Text(player.formattedTime(player.duration))
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundColor(Theme.textTertiary)
            }
        }
    }

    private var mainControls: some View {
        HStack(spacing: 0) {
            Button {
                player.playPrevious()
                SettingsStore.shared.triggerHaptic(.medium)
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: 60)
            }
            .buttonStyle(ScaleButtonStyle())

            Button {
                player.togglePlayPause()
                SettingsStore.shared.triggerHaptic(.medium)
            } label: {
                ZStack {
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: 76, height: 76)
                        .shadow(color: Theme.shadowAccent, radius: 22, y: 8)
                    if case .loading = player.playerState {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.2)
                    } else {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(.white)
                            .offset(x: player.isPlaying ? 0 : 2)
                    }
                }
            }
            .buttonStyle(ScaleButtonStyle(scale: 0.94))

            Button {
                player.playNext()
                SettingsStore.shared.triggerHaptic(.medium)
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: 60)
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    private var secondaryControls: some View {
        HStack {
            Button {
                player.isShuffled.toggle()
                SettingsStore.shared.triggerHaptic(.light)
                toast.show(player.isShuffled ? "Перемешать: вкл" : "Перемешать: выкл", style: .info)
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "shuffle")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(player.isShuffled ? Theme.accentBright : Theme.textTertiary)
                    Circle()
                        .fill(player.isShuffled ? Theme.accentBright : Color.clear)
                        .frame(width: 5, height: 5)
                }
                .frame(width: 52, height: 46)
            }
            .buttonStyle(ScaleButtonStyle())

            Spacer()

            Image(systemName: "airplayaudio")
                .font(.system(size: 20))
                .foregroundColor(Theme.textTertiary)
                .frame(width: 44, height: 44)

            Spacer()

            Button {
                switch player.repeatMode {
                case .none: player.repeatMode = .all
                case .all: player.repeatMode = .one
                case .one: player.repeatMode = .none
                }
                SettingsStore.shared.triggerHaptic(.light)
                let label: String
                switch player.repeatMode {
                case .none: label = "Повтор: выкл"
                case .one: label = "Повтор: один"
                case .all: label = "Повтор: все"
                }
                toast.show(label, style: .info)
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: repeatIcon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(repeatActive ? Theme.accentBright : Theme.textTertiary)
                    Circle()
                        .fill(repeatActive ? Theme.accentBright : Color.clear)
                        .frame(width: 5, height: 5)
                }
                .frame(width: 52, height: 46)
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    private var volumeSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "speaker.fill")
                .font(.system(size: 13))
                .foregroundColor(Theme.textTertiary)
                .frame(width: 18)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.bg3).frame(height: 4)
                    Capsule()
                        .fill(Theme.accent)
                        .frame(width: geo.size.width * CGFloat(player.volume), height: 4)
                    Circle()
                        .fill(.white)
                        .frame(width: 14, height: 14)
                        .shadow(color: .black.opacity(0.3), radius: 3)
                        .offset(x: max(0, geo.size.width * CGFloat(player.volume) - 7))
                }
                .frame(height: 20)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        player.setVolume(Float(min(max(v.location.x / geo.size.width, 0), 1)))
                    }
                )
            }
            .frame(height: 20)

            Image(systemName: "speaker.wave.3.fill")
                .font(.system(size: 13))
                .foregroundColor(Theme.textTertiary)
                .frame(width: 22)
        }
    }

    private var repeatIcon: String {
        switch player.repeatMode {
        case .none: return "repeat"
        case .one: return "repeat.1"
        case .all: return "repeat"
        }
    }
    private var repeatActive: Bool {
        if case .none = player.repeatMode { return false }
        return true
    }
}

// MARK: – Scale Button Style

struct ScaleButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.88
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: – Queue Sheet

struct QueueSheet: View {
    @EnvironmentObject var player: AudioPlayerManager

    var body: some View {
        NavigationView {
            Group {
                if player.queue.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 36))
                            .foregroundColor(Theme.textTertiary)
                        Text("Очередь пуста")
                            .font(.system(size: 16))
                            .foregroundColor(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.bg1)
                } else {
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
                }
            }
            .navigationTitle("Очередь")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }
}
