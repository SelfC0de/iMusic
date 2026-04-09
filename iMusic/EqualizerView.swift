import SwiftUI

struct EqualizerView: View {
    @ObservedObject var eq = EqualizerManager.shared
    @State private var draggingBand: Int? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Эквалайзер")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Toggle("", isOn: $eq.isEnabled)
                    .tint(Theme.accent)
                    .labelsHidden()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            // EQ Bands
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(0..<5, id: \.self) { i in
                    bandColumn(index: i)
                }
            }
            .frame(height: 200)
            .padding(.horizontal, 16)
            .opacity(eq.isEnabled ? 1 : 0.4)

            // Presets
            VStack(alignment: .leading, spacing: 8) {
                Text("Пресеты")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.textTertiary)
                    .padding(.horizontal, 20)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(eq.presets) { preset in
                            presetChip(preset)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 20)
            .opacity(eq.isEnabled ? 1 : 0.4)
        }
        .background(Theme.bg1)
    }

    // MARK: – Band column

    private func bandColumn(index i: Int) -> some View {
        VStack(spacing: 6) {
            // dB value
            Text(gainLabel(bands[i]))
                .font(.system(size: 10, weight: .medium).monospacedDigit())
                .foregroundColor(Theme.accent)
                .frame(height: 14)

            // Slider track
            GeometryReader { geo in
                let trackH = geo.size.height
                let knobH: CGFloat = 22
                let usable = trackH - knobH
                let normalized = CGFloat((bands[i] + 12) / 24)  // -12..+12 → 0..1
                let knobY = usable * (1 - normalized) + knobH / 2

                ZStack(alignment: .top) {
                    // track bg
                    Capsule()
                        .fill(Theme.bg3)
                        .frame(width: 4)
                        .padding(.vertical, knobH / 2)

                    // filled portion (from center to knob)
                    let centerNorm: CGFloat = 0.5
                    let fillTop = min(centerNorm, normalized)
                    let fillBot = max(centerNorm, normalized)
                    let fillY = usable * (1 - fillBot) + knobH / 2
                    let fillH = (fillBot - fillTop) * usable

                    Capsule()
                        .fill(bands[i] >= 0 ? Theme.accent : Theme.warning)
                        .frame(width: 4, height: max(1, fillH))
                        .offset(y: fillY)

                    // center line
                    Rectangle()
                        .fill(Theme.border)
                        .frame(width: 10, height: 1)
                        .offset(y: usable * 0.5 + knobH / 2)

                    // knob
                    Circle()
                        .fill(draggingBand == i ? Theme.accentBright : Theme.accent)
                        .frame(width: knobH, height: knobH)
                        .shadow(color: Theme.accent.opacity(0.5), radius: draggingBand == i ? 8 : 3)
                        .offset(y: knobY - knobH / 2)
                }
                .frame(width: geo.size.width)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in
                            guard eq.isEnabled else { return }
                            draggingBand = i
                            let raw = 1 - (v.location.y - knobH / 2) / usable
                            let clamped = min(1, max(0, raw))
                            let gain = Float(clamped) * 24 - 12
                            eq.bands[i] = gain.rounded()
                            eq.currentPreset = "Custom"
                            SettingsStore.shared.triggerHaptic(.light)
                        }
                        .onEnded { _ in draggingBand = nil }
                )
            }

            // Frequency label
            Text(eq.bandFrequencies[i])
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(Theme.textTertiary)
                .frame(height: 12)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: – Preset chip

    private func presetChip(_ preset: EQPreset) -> some View {
        let isActive = eq.currentPreset == preset.name
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                eq.applyPreset(preset)
            }
            SettingsStore.shared.triggerHaptic(.light)
        } label: {
            Text(preset.name)
                .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                .foregroundColor(isActive ? Theme.accentBright : Theme.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isActive ? Theme.accent.opacity(0.2) : Theme.bg3)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(isActive ? Theme.accent : Theme.border, lineWidth: isActive ? 1 : 0.5)
                        )
                )
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.92))
    }

    private var bands: [Float] { eq.bands }

    private func gainLabel(_ gain: Float) -> String {
        let g = Int(gain.rounded())
        return g == 0 ? "0" : (g > 0 ? "+\(g)" : "\(g)")
    }
}
