import SwiftUI

// MARK: – Palette helper

struct ColorPalette {
    let top: Color
    let bottom: Color
}

let palettes: [ColorPalette] = [
    .init(top: Color(red: 0.35, green: 0.08, blue: 0.55), bottom: Color(red: 0.08, green: 0.04, blue: 0.31)),
    .init(top: Color(red: 0.08, green: 0.20, blue: 0.47), bottom: Color(red: 0.31, green: 0.08, blue: 0.24)),
    .init(top: Color(red: 0.24, green: 0.04, blue: 0.39), bottom: Color(red: 0.04, green: 0.24, blue: 0.31)),
    .init(top: Color(red: 0.39, green: 0.12, blue: 0.24), bottom: Color(red: 0.12, green: 0.31, blue: 0.39)),
]

// MARK: – PlayerSheet

struct PlayerSheet: View {
    @Binding var showPlayer: Bool
    @EnvironmentObject var player: AudioPlayerManager
    @EnvironmentObject var library: LibraryStore
    @EnvironmentObject var toast: ToastManager
    @ObservedObject var downloads = DownloadManager.shared

    @State private var isDragging = false
    @State private var dragProgress: Double = 0
    @State private var dragOffset: CGFloat = 0
    @State private var swipeTriggered = false
    @State private var showQueue = false
    @State private var showEQ = false
    @State private var paletteIndex: Int = 0
    @State private var paletteTimer: Timer? = nil
    @State private var morphProgress: Double = 0

    var currentPalette: ColorPalette { palettes[paletteIndex % palettes.count] }
    var nextPalette: ColorPalette { palettes[(paletteIndex + 1) % palettes.count] }

    var lerpedTop: Color { lerpColor(currentPalette.top, nextPalette.top, morphProgress) }
    var lerpedBottom: Color { lerpColor(currentPalette.bottom, nextPalette.bottom, morphProgress) }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let vinylSize = min(w - 40, h * 0.42)

            ZStack {
                // ── Gradient Morph background ──────────────────
                LinearGradient(
                    colors: [lerpedTop, lerpedBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 2.0), value: paletteIndex)

                // dark vignette
                RadialGradient(
                    colors: [Color.clear, Color.black.opacity(0.72)],
                    center: .center,
                    startRadius: 60,
                    endRadius: 240
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // drag handle
                    Capsule()
                        .fill(Color.white.opacity(0.25))
                        .frame(width: 40, height: 4)
                        .padding(.top, 14)
                        .padding(.bottom, 4)

                    // header
                    HStack {
                        Button {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) { showPlayer = false }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.08))
                                    .frame(width: 38, height: 38)
                                    .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.85))
                            }
                        }
                        Spacer()
                        VStack(spacing: 1) {
                            Text("СЕЙЧАС ИГРАЕТ")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white.opacity(0.4))
                                .tracking(1.5)
                            Text(player.currentTrack?.artist ?? "")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                                .lineLimit(1)
                        }
                        Spacer()
                        HStack(spacing: 0) {
                            Button { showEQ = true } label: {
                                Image(systemName: "slider.vertical.3")
                                    .font(.system(size: 18))
                                    .foregroundColor(.white.opacity(0.6))
                                    .frame(width: 44, height: 44)
                            }
                            Button { showQueue = true } label: {
                                Image(systemName: "list.bullet")
                                    .font(.system(size: 18))
                                    .foregroundColor(.white.opacity(0.6))
                                    .frame(width: 44, height: 44)
                            }
                        }
                    }
                    .padding(.horizontal, 12)

                    // ── Vinyl disc ─────────────────────────────
                    VinylDisc(
                        coverURL: player.currentTrack?.coverURL ?? "",
                        isPlaying: player.isPlaying,
                        progress: player.progress,
                        accentColor: lerpedTop,
                        size: vinylSize
                    )
                    .offset(x: dragOffset)
                    .gesture(swipeGesture)
                    .padding(.top, 12)

                    // gap below disc — fixed so Track name always shows
                    Spacer().frame(height: 20)

                    // track info
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(player.currentTrack?.title ?? "—")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white.opacity(0.95))
                                .lineLimit(1)
                            Text(player.currentTrack?.artist ?? "")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.55))
                                .lineLimit(1)
                        }
                        Spacer(minLength: 8)
                        CircularDownloadButton(track: player.currentTrack)
                        favouriteButton
                    }
                    .padding(.horizontal, 28)

                    // progress
                    progressBar
                        .padding(.horizontal, 28)
                        .padding(.top, 12)

                    // controls
                    mainControls(accent: lerpedTop)
                        .padding(.horizontal, 28)
                        .padding(.top, 14)

                    // secondary
                    secondaryControls
                        .padding(.horizontal, 28)
                        .padding(.top, 10)

                    // volume
                    volumeBar
                        .padding(.horizontal, 28)
                        .padding(.top, 12)
                        .padding(.bottom, 28)
                }
            }
            .gesture(DragGesture().onEnded { v in
                if v.translation.height > 80 {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) { showPlayer = false }
                }
            })
        }
        .onAppear { startMorphTimer() }
        .onDisappear { paletteTimer?.invalidate() }
        .sheet(isPresented: $showQueue) {
            QueueSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showEQ) {
            EqualizerView()
                .presentationDetents([.height(440)])
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.bg1)
        }
    }

    // MARK: – Gradient morph timer

    private func startMorphTimer() {
        paletteTimer?.invalidate()
        paletteTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            morphProgress += 0.004
            if morphProgress >= 1.0 {
                morphProgress = 0
                paletteIndex = (paletteIndex + 1) % palettes.count
            }
        }
    }

    private func lerpColor(_ a: Color, _ b: Color, _ t: Double) -> Color {
        let t2 = max(0, min(1, t))
        let (ar, ag, ab) = a.rgbComponents
        let (br, bg, bb) = b.rgbComponents
        return Color(
            red:   ar + (br - ar) * t2,
            green: ag + (bg - ag) * t2,
            blue:  ab + (bb - ab) * t2
        )
    }

    // MARK: – Favourite

    private var favouriteButton: some View {
        let fav = player.currentTrack.map { library.isFavorite($0) } ?? false
        return Button {
            guard let track = player.currentTrack else { return }
            library.toggleFavorite(track)
            toast.show(library.isFavorite(track) ? "Добавлено" : "Удалено", style: .success, position: .slideLeft)
            SettingsStore.shared.triggerHaptic(.medium)
        } label: {
            Image(systemName: fav ? "heart.fill" : "heart")
                .font(.system(size: 22))
                .foregroundColor(fav ? .white : .white.opacity(0.45))
                .scaleEffect(fav ? 1.1 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.5), value: fav)
        }
    }

    // MARK: – Progress

    private var progressBar: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.15)).frame(height: 4)
                    Capsule()
                        .fill(Color.white.opacity(0.85))
                        .frame(width: max(0, geo.size.width * CGFloat(isDragging ? dragProgress : player.progress)), height: 4)
                    Circle()
                        .fill(.white)
                        .frame(width: isDragging ? 16 : 11)
                        .shadow(color: .white.opacity(0.4), radius: isDragging ? 6 : 2)
                        .offset(x: max(0, geo.size.width * CGFloat(isDragging ? dragProgress : player.progress) - (isDragging ? 8 : 5.5)))
                        .animation(.spring(response: 0.2, dampingFraction: 0.75), value: isDragging)
                }
                .frame(height: 20)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        isDragging = true
                        dragProgress = min(max(Double(v.location.x / geo.size.width), 0), 1)
                    }
                    .onEnded { v in
                        player.seek(to: min(max(Double(v.location.x / geo.size.width), 0), 1) * player.duration)
                        isDragging = false
                    }
                )
            }
            .frame(height: 20)

            HStack {
                Text(player.formattedTime(isDragging ? dragProgress * player.duration : player.currentTime))
                    .font(.system(size: 11).monospacedDigit()).foregroundColor(.white.opacity(0.4))
                Spacer()
                Text(player.formattedTime(player.duration))
                    .font(.system(size: 11).monospacedDigit()).foregroundColor(.white.opacity(0.4))
            }
        }
    }

    // MARK: – Main controls

    private func mainControls(accent: Color) -> some View {
        HStack(spacing: 0) {
            // Prev — glow circle
            Button {
                player.playPrevious()
                SettingsStore.shared.triggerHaptic(.medium)
            } label: {
                GlowCircleButton(icon: "backward.fill", color: accent.opacity(0.8))
            }
            .buttonStyle(ScaleButtonStyle())
            .frame(maxWidth: .infinity)

            // Play / Pause — large glow circle
            Button {
                player.togglePlayPause()
                SettingsStore.shared.triggerHaptic(.medium)
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [accent.opacity(0.9), accent.opacity(0.5)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 36
                            )
                        )
                        .frame(width: 68, height: 68)
                        .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                        .shadow(color: accent.opacity(0.5), radius: 18, y: 6)

                    if case .loading = player.playerState {
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(1.1)
                    } else if player.isPlaying {
                        // Pause: two precise rectangles
                        HStack(spacing: 5) {
                            RoundedRectangle(cornerRadius: 2)
                                .frame(width: 5, height: 18)
                                .foregroundColor(.white)
                            RoundedRectangle(cornerRadius: 2)
                                .frame(width: 5, height: 18)
                                .foregroundColor(.white)
                        }
                    } else {
                        // Play: triangle with correct optical center offset
                        Image(systemName: "play.fill")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)
                            .offset(x: 2)
                    }
                }
            }
            .buttonStyle(ScaleButtonStyle(scale: 0.94))

            // Next — glow circle
            Button {
                player.playNext()
                SettingsStore.shared.triggerHaptic(.medium)
            } label: {
                GlowCircleButton(icon: "forward.fill", color: accent.opacity(0.8))
            }
            .buttonStyle(ScaleButtonStyle())
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: – Secondary

    private var secondaryControls: some View {
        HStack {
            Button {
                player.isShuffled.toggle()
                SettingsStore.shared.triggerHaptic(.light)
            } label: {
                VStack(spacing: 3) {
                    Image(systemName: "shuffle")
                        .font(.system(size: 17))
                        .foregroundColor(player.isShuffled ? .white : .white.opacity(0.4))
                    Circle().fill(player.isShuffled ? Color.white : Color.clear).frame(width: 4, height: 4)
                }
                .frame(width: 50, height: 32)
            }
            .buttonStyle(ScaleButtonStyle())

            Spacer()
            Image(systemName: "airplayaudio")
                .font(.system(size: 17))
                .foregroundColor(.white.opacity(0.4))
                .frame(width: 44, height: 32)
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
                        .font(.system(size: 17))
                        .foregroundColor(repeatActive ? .white : .white.opacity(0.4))
                    Circle().fill(repeatActive ? Color.white : Color.clear).frame(width: 4, height: 4)
                }
                .frame(width: 50, height: 32)
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    // MARK: – Volume

    private var volumeBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "speaker.fill").font(.system(size: 12)).foregroundColor(.white.opacity(0.4)).frame(width: 16)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.15)).frame(height: 4)
                    Capsule().fill(Color.white.opacity(0.75)).frame(width: geo.size.width * CGFloat(player.volume), height: 4)
                    Circle()
                        .fill(.white)
                        .frame(width: 14, height: 14)
                        .shadow(color: .black.opacity(0.2), radius: 2)
                        .offset(x: max(0, geo.size.width * CGFloat(player.volume) - 7))
                }
                .frame(height: 20)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { v in player.setVolume(Float(min(max(v.location.x / geo.size.width, 0), 1))) }
                )
            }
            .frame(height: 20)
            Image(systemName: "speaker.wave.3.fill").font(.system(size: 12)).foregroundColor(.white.opacity(0.4)).frame(width: 20)
        }
    }

    // MARK: – Swipe

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { v in
                guard abs(v.translation.width) > abs(v.translation.height) else { return }
                dragOffset = v.translation.width * 0.35
            }
            .onEnded { v in
                let threshold: CGFloat = 55
                if v.translation.width < -threshold && !swipeTriggered {
                    swipeTriggered = true
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { dragOffset = -80 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                        player.playNext(); SettingsStore.shared.triggerHaptic(.medium)
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { dragOffset = 0 }
                        swipeTriggered = false
                    }
                } else if v.translation.width > threshold && !swipeTriggered {
                    swipeTriggered = true
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { dragOffset = 80 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                        player.playPrevious(); SettingsStore.shared.triggerHaptic(.medium)
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { dragOffset = 0 }
                        swipeTriggered = false
                    }
                } else {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { dragOffset = 0 }
                }
            }
    }

    private var repeatIcon: String {
        switch player.repeatMode { case .none: return "repeat"; case .one: return "repeat.1"; case .all: return "repeat" }
    }
    private var repeatActive: Bool {
        if case .none = player.repeatMode { return false }; return true
    }
}

// MARK: – Vinyl Disc View

struct VinylDisc: View {
    let coverURL: String
    let isPlaying: Bool
    let progress: Double
    let accentColor: Color
    let size: CGFloat

    @State private var isAnimating = false

    var body: some View {
        TimelineView(.animation(paused: !isPlaying)) { tl in
            let angle = tl.date.timeIntervalSinceReferenceDate * 27.0
            ZStack {
                // outer glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [accentColor.opacity(0.35), Color.clear],
                            center: .center, startRadius: size*0.35, endRadius: size*0.55
                        )
                    )
                    .frame(width: size + 40, height: size + 40)
                    .blur(radius: 8)

                // vinyl body
                Circle()
                    .fill(Color(red: 0.06, green: 0.05, blue: 0.09))
                    .frame(width: size, height: size)
                    .overlay(
                        ZStack {
                            // grooves
                            ForEach([0.28, 0.38, 0.48, 0.58, 0.68, 0.78, 0.88], id: \.self) { f in
                                Circle()
                                    .stroke(accentColor.opacity(0.07 + f * 0.04), lineWidth: 0.8)
                                    .frame(width: size * f, height: size * f)
                            }
                            // spectrum inside disc — clipped to circle
                            SpectrumBars(isPlaying: isPlaying, accentColor: accentColor, time: tl.date.timeIntervalSinceReferenceDate)
                                .frame(width: size, height: size)
                                .clipShape(Circle())
                                .opacity(0.75)
                            // sheen
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.05), Color.clear, Color.white.opacity(0.03)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: size, height: size)
                            // center label (counter-rotates to stay upright)
                            ZStack {
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            colors: [accentColor.opacity(0.9), accentColor.opacity(0.5)],
                                            center: .center, startRadius: 0, endRadius: size * 0.23
                                        )
                                    )
                                    .frame(width: size * 0.46, height: size * 0.46)
                                    .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
                                CachedAsyncImage(url: coverURL)
                                    .frame(width: size * 0.38, height: size * 0.38)
                                    .clipShape(Circle())
                                    .opacity(0.88)
                                Circle()
                                    .fill(Color(red: 0.04, green: 0.03, blue: 0.07))
                                    .frame(width: size * 0.055, height: size * 0.055)
                            }
                            .rotationEffect(.degrees(-angle))
                        }
                        .frame(width: size, height: size)
                    )
                    .rotationEffect(.degrees(angle))

                // progress arc
                Circle()
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(accentColor.opacity(0.9), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: size + 20, height: size + 20)
                    .rotationEffect(.degrees(-90))
                Circle()
                    .trim(from: CGFloat(progress), to: 1)
                    .stroke(Color.white.opacity(0.08), style: StrokeStyle(lineWidth: 3))
                    .frame(width: size + 20, height: size + 20)
                    .rotationEffect(.degrees(-90))

                // progress dot
                let dotAngle = (progress - 0.25) * 2 * Double.pi
                Circle()
                    .fill(.white)
                    .frame(width: 10, height: 10)
                    .offset(
                        x: CGFloat(cos(dotAngle)) * (size / 2 + 10),
                        y: CGFloat(sin(dotAngle)) * (size / 2 + 10)
                    )

                // needle
                NeedleView(size: size, accentColor: accentColor, isPlaying: isPlaying, time: tl.date.timeIntervalSinceReferenceDate)
            }
        }
        .frame(width: size + 60, height: size + 20)
    }
}

// MARK: – Needle

struct NeedleView: View {
    let size: CGFloat
    let accentColor: Color
    let isPlaying: Bool
    let time: Double

    var body: some View {
        GeometryReader { geo in
            let cx = geo.size.width / 2
            let cy = geo.size.height / 2
            let pivotX = cx + size * 0.48
            let pivotY = cy - size * 0.38
            let tipAngle: Double = -0.42
            let tipX = cx + (size / 2 + 2) * CGFloat(cos(tipAngle))
            let tipY = cy + (size / 2 + 2) * CGFloat(sin(tipAngle))
            let pulse = isPlaying ? (sin(time * 4) * 0.5 + 0.5) : 0.0

            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: pivotX, y: pivotY))
                    p.addLine(to: CGPoint(x: tipX, y: tipY))
                }
                .stroke(Color.white.opacity(0.65), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

                Circle()
                    .fill(Color(red: 0.55, green: 0.55, blue: 0.6))
                    .frame(width: 12, height: 12)
                    .position(x: pivotX, y: pivotY)
                Circle()
                    .fill(Color(red: 0.2, green: 0.2, blue: 0.25))
                    .frame(width: 6, height: 6)
                    .position(x: pivotX, y: pivotY)

                Circle()
                    .fill(accentColor.opacity(isPlaying ? 0.5 + 0.5 * pulse : 0.3))
                    .frame(width: CGFloat(6 + 2 * pulse), height: CGFloat(6 + 2 * pulse))
                    .position(x: tipX, y: tipY)
            }
        }
    }
}

// MARK: – Spectrum Bars

struct SpectrumBars: View {
    let isPlaying: Bool
    let accentColor: Color
    let time: Double

    private let n = 28
    private let bw: CGFloat = 3.5
    private let gap: CGFloat = 2.5

    private func barHeight(index i: Int, totalH h: CGFloat) -> CGFloat {
        let rawH: Double
        if isPlaying {
            let wave1 = sin(time * 2.8 + Double(i) * 0.55)
            let wave2 = sin(time * 1.7 + Double(i) * 0.3)
            rawH = 0.15 + 0.72 * abs(wave1 * 0.6 + wave2 * 0.4)
        } else {
            rawH = 0.06
        }
        return CGFloat(rawH) * h * 0.44
    }

    private func barAlpha(index i: Int) -> Double {
        let centerDist = abs(Double(i) - Double(n) / 2) / (Double(n) / 2)
        return 1.0 - centerDist * 0.55
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let totalW = CGFloat(n) * (bw + gap) - gap
            let startX = (w - totalW) / 2
            let baseY = h / 2

            ZStack {
                ForEach(0..<n, id: \.self) { i in
                    SpectrumBarGroup(
                        index: i,
                        bw: bw,
                        bh: barHeight(index: i, totalH: h),
                        alpha: barAlpha(index: i),
                        x: startX + CGFloat(i) * (bw + gap),
                        baseY: baseY,
                        accentColor: accentColor
                    )
                }
            }
        }
    }
}

private struct SpectrumBarGroup: View {
    let index: Int
    let bw: CGFloat
    let bh: CGFloat
    let alpha: Double
    let x: CGFloat
    let baseY: CGFloat
    let accentColor: Color

    var body: some View {
        ZStack {
            Rectangle()
                .fill(accentColor.opacity(0.55 * alpha))
                .frame(width: bw, height: max(2, bh))
                .cornerRadius(2)
                .position(x: x + bw / 2, y: baseY - bh / 2)

            Rectangle()
                .fill(accentColor.opacity(0.22 * alpha))
                .frame(width: bw, height: max(2, bh * 0.45))
                .cornerRadius(2)
                .position(x: x + bw / 2, y: baseY + bh * 0.225)

            Rectangle()
                .fill(Color.white.opacity(0.3 * alpha))
                .frame(width: bw, height: max(1, min(4, bh * 0.08)))
                .cornerRadius(2)
                .position(x: x + bw / 2, y: baseY - bh + 2)
        }
    }
}

// MARK: – Color extension

extension Color {
    var rgbComponents: (Double, Double, Double) {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: nil)
        return (Double(r), Double(g), Double(b))
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
                        Image(systemName: "list.bullet").font(.system(size: 36)).foregroundColor(Theme.textTertiary)
                        Text("Очередь пуста").font(.system(size: 16)).foregroundColor(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity).background(Theme.bg1)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(player.queue.enumerated()), id: \.element.id) { idx, track in
                                TrackRow(track: track, isPlaying: player.currentTrack?.id == track.id,
                                         queue: player.queue, index: idx)
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
