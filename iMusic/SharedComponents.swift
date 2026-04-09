import SwiftUI

struct ScaleButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.88
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct WaveformVisualizer: View {
    @EnvironmentObject var player: AudioPlayerManager
    @State private var bars: [CGFloat] = Array(repeating: 0.3, count: 28)
    @State private var phase: Double = 0

    let timer = Timer.publish(every: 0.08, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 2.5) {
            ForEach(0..<28, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [Theme.accentDim, Theme.accentBright],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 3, height: 28 * bars[i])
                    .animation(player.isPlaying ? .easeInOut(duration: 0.08) : .none, value: bars[i])
            }
        }
        .onReceive(timer) { _ in
            guard player.isPlaying else {
                // freeze bars at low flat state when paused
                if bars.first != 0.08 {
                    withAnimation(.easeOut(duration: 0.4)) {
                        for i in 0..<28 { bars[i] = 0.08 }
                    }
                }
                return
            }
            phase += 0.25
            for i in 0..<28 {
                let wave1 = sin(phase + Double(i) * 0.45) * 0.25
                let wave2 = sin(phase * 1.7 + Double(i) * 0.3) * 0.2
                let rand = Double.random(in: -0.08...0.08)
                bars[i] = CGFloat(min(1.0, max(0.12, 0.45 + wave1 + wave2 + rand)))
            }
        }
        .onAppear {
            for i in 0..<28 {
                bars[i] = player.isPlaying ? CGFloat.random(in: 0.1...0.5) : 0.08
            }
        }
        .onChange(of: player.isPlaying) {
            if !player.isPlaying {
                withAnimation(.easeOut(duration: 0.4)) {
                    for i in 0..<28 { bars[i] = 0.08 }
                }
            }
        }
    }
}

// MARK: – Glow Circle Button (фото 1 style)

struct GlowCircleButton: View {
    let icon: String
    let color: Color
    @State private var pressed = false

    var body: some View {
        ZStack {
            // Outer glow ring
            Circle()
                .stroke(color.opacity(0.35), lineWidth: 1.5)
                .frame(width: 62, height: 62)
                .blur(radius: 1)

            // Glow blob behind
            Circle()
                .fill(
                    RadialGradient(
                        colors: [color.opacity(0.45), color.opacity(0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 34
                    )
                )
                .frame(width: 68, height: 68)
                .blur(radius: 4)

            // Dark circle body
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "#1e1a24"),
                            Color(hex: "#0f0d14")
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 58, height: 58)
                .overlay(
                    Circle()
                        .stroke(color.opacity(0.5), lineWidth: 1)
                )

            // Icon
            Image(systemName: icon)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(width: 68, height: 68)
    }
}

// MARK: – Inline Player Card (фото 2 style — embedded in track list)

struct InlinePlayerCard: View {
    @EnvironmentObject var player: AudioPlayerManager

    var body: some View {
        HStack(spacing: 12) {
            // Cover
            CachedAsyncImage(url: player.currentTrack?.coverURL ?? "")
                .frame(width: 46, height: 46)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 0.5))

            // Title + artist
            VStack(alignment: .leading, spacing: 2) {
                Text(player.currentTrack?.title ?? "")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
                Text(player.currentTrack?.artist ?? "")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Play/pause
            Button {
                player.togglePlayPause()
                SettingsStore.shared.triggerHaptic(.medium)
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(ScaleButtonStyle(scale: 0.85))

            // Next
            Button {
                player.playNext()
                SettingsStore.shared.triggerHaptic(.light)
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Theme.textSecondary)
                    .frame(width: 32, height: 36)
            }
            .buttonStyle(ScaleButtonStyle(scale: 0.85))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.surfaceElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Theme.accent.opacity(0.25), lineWidth: 1)
                )
                .shadow(color: Theme.accent.opacity(0.1), radius: 8)
        )
        // progress line at bottom
        .overlay(
            GeometryReader { geo in
                VStack {
                    Spacer()
                    HStack(spacing: 0) {
                        Theme.accent
                            .frame(width: (geo.size.width - 28) * CGFloat(player.progress))
                            .animation(.linear(duration: 0.5), value: player.progress)
                        Color.clear
                    }
                    .frame(height: 2)
                    .clipShape(Capsule())
                    .padding(.horizontal, 14)
                    .padding(.bottom, 4)
                }
            }
        )
        .transition(.asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .move(edge: .top).combined(with: .opacity)
        ))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: player.currentTrack?.id)
    }
}

// MARK: – Search Loading Animation

struct SearchLoadingView: View {
    @State private var phase: Double = 0
    @State private var textOpacity: Double = 0
    @State private var dotCount: Int = 0
    @State private var barHeights: [CGFloat] = Array(repeating: 4, count: 5)

    let texts = ["Ищу треки", "Поиск актуального", "Готовлю список", "Почти готово"]
    @State private var textIndex = 0

    let barTimer = Timer.publish(every: 0.12, on: .main, in: .common).autoconnect()
    let textTimer = Timer.publish(every: 1.8, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 28) {
            // Animated waveform bars
            HStack(spacing: 5) {
                ForEach(0..<5, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [Theme.accentDim, Theme.accentBright],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(width: 6, height: barHeights[i])
                        .animation(
                            .spring(response: 0.25, dampingFraction: 0.55)
                                .delay(Double(i) * 0.04),
                            value: barHeights[i]
                        )
                }
            }
            .frame(height: 44)
            .onReceive(barTimer) { _ in
                phase += 0.35
                for i in 0..<5 {
                    let wave = sin(phase + Double(i) * 0.9) * 0.5 + 0.5
                    barHeights[i] = 6 + CGFloat(wave) * 38
                }
            }

            // Animated text with dots
            VStack(spacing: 6) {
                HStack(spacing: 2) {
                    Text(texts[textIndex])
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                        .id(textIndex)

                    HStack(spacing: 2) {
                        ForEach(0..<3, id: \.self) { d in
                            Circle()
                                .fill(Theme.accent)
                                .frame(width: 4, height: 4)
                                .opacity(dotCount > d ? 1 : 0.2)
                                .animation(
                                    .easeInOut(duration: 0.25).delay(Double(d) * 0.12),
                                    value: dotCount
                                )
                        }
                    }
                    .padding(.leading, 2)
                }

            }
        }
        .onAppear {
            withAnimation(.easeIn(duration: 0.3)) { textOpacity = 1 }
        }
        .onReceive(textTimer) { _ in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                textIndex = (textIndex + 1) % texts.count
                dotCount = (dotCount % 3) + 1
            }
        }
    }
}
