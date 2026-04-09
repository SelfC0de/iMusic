import SwiftUI

struct MiniPlayerBar: View {
    @Binding var showPlayer: Bool
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
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
                Text(player.currentTrack?.artist ?? "")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Play/Pause
            Button {
                player.togglePlayPause()
                SettingsStore.shared.triggerHaptic(.medium)
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(ScaleButtonStyle(scale: 0.85))

            // Next
            Button {
                player.playNext()
                SettingsStore.shared.triggerHaptic(.light)
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                    .frame(width: 36, height: 40)
            }
            .buttonStyle(ScaleButtonStyle(scale: 0.85))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Theme.surfaceElevated)
                .shadow(color: .black.opacity(0.35), radius: 12, y: 4)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                showPlayer = true
            }
            SettingsStore.shared.triggerHaptic(.light)
        }
        // progress line at bottom of pill
        .overlay(
            GeometryReader { geo in
                VStack {
                    Spacer()
                    HStack(spacing: 0) {
                        Theme.accent
                            .frame(width: geo.size.width * CGFloat(player.progress))
                        Color.clear
                    }
                    .frame(height: 2)
                    .clipShape(RoundedRectangle(cornerRadius: 1))
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 2)
            }
        )
    }
}
