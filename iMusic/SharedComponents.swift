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
                    .animation(.easeInOut(duration: 0.08), value: bars[i])
            }
        }
        .onReceive(timer) { _ in
            guard player.isPlaying else { return }
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
                bars[i] = CGFloat.random(in: 0.1...0.5)
            }
        }
    }
}
