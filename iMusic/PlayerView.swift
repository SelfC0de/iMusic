import SwiftUI

struct PlayerSheet: View {
    @EnvironmentObject var player: AudioPlayerManager
    @EnvironmentObject var library: LibraryStore
    @EnvironmentObject var toast: ToastManager
    @ObservedObject var downloads = DownloadManager.shared
    @Environment(\.dismiss) var dismiss

    @State private var isDragging = false
    @State private var dragProgress: Double = 0
    @State private var showQueue = false
    @State private var dragOffset: CGFloat = 0
    @State private var swipeTriggered = false

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Theme.textSecondary)
                            .frame(width: 36, height: 36)
                    }
                    Spacer()
                    VStack(spacing: 2) {
                        Text("СЕЙЧАС ИГРАЕТ")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Theme.textTertiary)
                            .tracking(1.5)
                        Text(player.currentTrack?.artist ?? "")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Theme.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Button { showQueue = true } label: {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 18))
                            .foregroundColor(Theme.textSecondary)
                            .frame(width: 36, height: 36)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)

                if player.currentTrack == nil {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "waveform")
                            .font(.system(size: 50))
                            .foregroundColor(Theme.accentDim)
                        Text("Ничего не играет")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Theme.textPrimary)
                    }
                    Spacer()
                } else {
                    // Fixed budget: topbar≈60, trackInfo≈48, viz≈28, progress≈42, controls≈70, secondary≈36, volume≈18, gaps≈60
                    let fixedH: CGFloat = 60 + 48 + 28 + 42 + 70 + 36 + 18 + 60
                    let artSize = min(geo.size.height - fixedH, geo.size.width - 48)

                    // Album art
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Theme.accentDim.opacity(0.15))
                            .frame(width: artSize, height: artSize)
                            .blur(radius: 22)
                            .offset(y: 8)
                            .scaleEffect(player.isPlaying ? 1.04 : 0.9)
                            .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: player.isPlaying)

                        CachedAsyncImage(url: player.currentTrack?.coverURL ?? "")
                            .frame(width: artSize, height: artSize)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.border, lineWidth: 0.5))
                            .scaleEffect(player.isPlaying ? 1.0 : 0.93)
                            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: player.isPlaying)
                            .shadow(color: .black.opacity(0.4), radius: 20, y: 10)

                        if case .loading = player.playerState {
                            RoundedRectangle(cornerRadius: 18)
                                .fill(Color.black.opacity(0.5))
                                .frame(width: artSize, height: artSize)
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Theme.accentBright))
                                .scaleEffect(1.4)
                        }
                    }
                    .frame(width: artSize, height: artSize)
                    .offset(x: dragOffset)
                    .gesture(
                        DragGesture(minimumDistance: 20)
                            .onChanged { v in
                                guard abs(v.translation.width) > abs(v.translation.height) else { return }
                                dragOffset = v.translation.width * 0.4
                            }
                            .onEnded { v in
                                let threshold: CGFloat = 60
                                if v.translation.width < -threshold && !swipeTriggered {
                                    swipeTriggered = true
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { dragOffset = -80 }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                        player.playNext()
                                        SettingsStore.shared.triggerHaptic(.medium)
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { dragOffset = 0 }
                                        swipeTriggered = false
                                    }
                                } else if v.translation.width > threshold && !swipeTriggered {
                                    swipeTriggered = true
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { dragOffset = 80 }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                        player.playPrevious()
                                        SettingsStore.shared.triggerHaptic(.medium)
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { dragOffset = 0 }
                                        swipeTriggered = false
                                    }
                                } else {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { dragOffset = 0 }
                                }
                            }
                    )

                    // Visualizer
                    WaveformVisualizer()
                        .frame(height: 24)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        .opacity(player.isPlaying ? 1 : 0.25)
                        .animation(.easeInOut(duration: 0.3), value: player.isPlaying)

                    // Track info
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(player.currentTrack?.title ?? "")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(Theme.textPrimary)
                                .lineLimit(1)
                            Text(player.currentTrack?.artist ?? "")
                                .font(.system(size: 13))
                                .foregroundColor(Theme.textSecondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        CircularDownloadButton(track: player.currentTrack)
                        let fav = player.currentTrack.map { library.isFavorite($0) } ?? false
                        Button {
                            guard let track = player.currentTrack else { return }
                            library.toggleFavorite(track)
                            toast.show(library.isFavorite(track) ? "Добавлено" : "Удалено", style: .success, position: .slideLeft)
                            SettingsStore.shared.triggerHaptic(.medium)
                        } label: {
                            Image(systemName: fav ? "heart.fill" : "heart")
                                .font(.system(size: 22))
                                .foregroundColor(fav ? Theme.accentBright : Theme.textTertiary)
                                .scaleEffect(fav ? 1.1 : 1.0)
                                .animation(.spring(response: 0.25, dampingFraction: 0.5), value: fav)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                    // Progress
                    progressSection
                        .padding(.horizontal, 24)
                        .padding(.top, 10)

                    // Main controls
                    mainControls
                        .padding(.horizontal, 24)
                        .padding(.top, 14)

                    // Secondary controls
                    secondaryControls
                        .padding(.horizontal, 24)
                        .padding(.top, 8)

                    // Volume
                    volumeSection
                        .padding(.horizontal, 24)
                        .padding(.top, 10)
                        .padding(.bottom, 20)
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

    private var progressSection: some View {
        VStack(spacing: 5) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.bg3).frame(height: 5)
                    Capsule()
                        .fill(LinearGradient(colors: [Theme.accentDim, Theme.accentBright], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(0, geo.size.width * CGFloat(isDragging ? dragProgress : player.progress)), height: 5)
                    Circle()
                        .fill(Theme.accentBright)
                        .frame(width: isDragging ? 17 : 12, height: isDragging ? 17 : 12)
                        .shadow(color: Theme.accent.opacity(0.6), radius: isDragging ? 7 : 3)
                        .offset(x: max(0, geo.size.width * CGFloat(isDragging ? dragProgress : player.progress) - (isDragging ? 8.5 : 6)))
                        .animation(.spring(response: 0.2, dampingFraction: 0.75), value: isDragging)
                }
                .frame(height: 22)
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
            .frame(height: 22)

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
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: 54)
            }
            .buttonStyle(ScaleButtonStyle())

            Button {
                player.togglePlayPause()
                SettingsStore.shared.triggerHaptic(.medium)
            } label: {
                ZStack {
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: 68, height: 68)
                        .shadow(color: Theme.shadowAccent, radius: 18, y: 6)
                    if case .loading = player.playerState {
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(1.1)
                    } else {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 26, weight: .bold))
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
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: 54)
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    private var secondaryControls: some View {
        HStack {
            Button {
                player.isShuffled.toggle()
                SettingsStore.shared.triggerHaptic(.light)
                toast.show(player.isShuffled ? "Перемешать: вкл" : "Выкл", style: .info)
            } label: {
                VStack(spacing: 3) {
                    Image(systemName: "shuffle")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(player.isShuffled ? Theme.accentBright : Theme.textTertiary)
                    Circle().fill(player.isShuffled ? Theme.accentBright : Color.clear).frame(width: 4, height: 4)
                }
                .frame(width: 48, height: 34)
            }
            .buttonStyle(ScaleButtonStyle())

            Spacer()
            Image(systemName: "airplayaudio")
                .font(.system(size: 18))
                .foregroundColor(Theme.textTertiary)
                .frame(width: 40, height: 34)
            Spacer()

            Button {
                switch player.repeatMode {
                case .none: player.repeatMode = .all
                case .all:  player.repeatMode = .one
                case .one:  player.repeatMode = .none
                }
                SettingsStore.shared.triggerHaptic(.light)
            } label: {
                VStack(spacing: 3) {
                    Image(systemName: repeatIcon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(repeatActive ? Theme.accentBright : Theme.textTertiary)
                    Circle().fill(repeatActive ? Theme.accentBright : Color.clear).frame(width: 4, height: 4)
                }
                .frame(width: 48, height: 34)
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    private var volumeSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "speaker.fill").font(.system(size: 12)).foregroundColor(Theme.textTertiary).frame(width: 16)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.bg3).frame(height: 4)
                    Capsule().fill(Theme.accent).frame(width: geo.size.width * CGFloat(player.volume), height: 4)
                    Circle()
                        .fill(.white)
                        .frame(width: 14, height: 14)
                        .shadow(color: .black.opacity(0.3), radius: 3)
                        .offset(x: max(0, geo.size.width * CGFloat(player.volume) - 7))
                }
                .frame(height: 18)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { v in player.setVolume(Float(min(max(v.location.x / geo.size.width, 0), 1))) }
                )
            }
            .frame(height: 18)
            Image(systemName: "speaker.wave.3.fill").font(.system(size: 12)).foregroundColor(Theme.textTertiary).frame(width: 20)
        }
    }

    private var repeatIcon: String {
        switch player.repeatMode { case .none: return "repeat"; case .one: return "repeat.1"; case .all: return "repeat" }
    }
    private var repeatActive: Bool {
        if case .none = player.repeatMode { return false }; return true
    }
}

struct QueueSheet: View {
    @EnvironmentObject var player: AudioPlayerManager
    var body: some View {
        NavigationView {
            Group {
                if player.queue.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "list.bullet").font(.system(size: 36)).foregroundColor(Theme.textTertiary)
                        Text("Очередь пуста").font(.system(size: 16)).foregroundColor(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity).background(Theme.bg1)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(player.queue.enumerated()), id: \.element.id) { idx, track in
                                TrackRow(track: track, isPlaying: player.currentTrack?.id == track.id, queue: player.queue, index: idx)
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
