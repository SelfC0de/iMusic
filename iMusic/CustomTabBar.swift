import SwiftUI

struct CustomTabBar: View {
    @Binding var selected: TabItem
    @Binding var showPlayer: Bool
    @EnvironmentObject var player: AudioPlayerManager

    var body: some View {
        VStack(spacing: 0) {
            if player.currentTrack != nil {
                MiniPlayerBar(showPlayer: $showPlayer)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            HStack(spacing: 0) {
                ForEach(TabItem.allCases, id: \.self) { tab in
                    TabBarButton(tab: tab, isSelected: selected == tab) {
                        guard selected != tab else { return }
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                            selected = tab
                        }
                        SettingsStore.shared.triggerHaptic(.light)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 10)
            .padding(.bottom, 28)
            .background(
                ZStack(alignment: .top) {
                    Theme.bg1
                    Rectangle()
                        .frame(height: 0.5)
                        .foregroundColor(Theme.border)
                }
            )
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: player.currentTrack?.id)
    }
}

struct TabBarButton: View {
    let tab: TabItem
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Theme.accent.opacity(0.15))
                            .frame(width: 46, height: 28)
                    }
                    Image(systemName: tab.icon)
                        .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? Theme.accentBright : Theme.textTertiary)
                        .symbolEffect(.bounce, value: isSelected)
                }
                Text(tab.title)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? Theme.accentBright : Theme.textTertiary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

struct MiniPlayerBar: View {
    @Binding var showPlayer: Bool
    @EnvironmentObject var player: AudioPlayerManager

    var body: some View {
        Button {
            showPlayer = true
            SettingsStore.shared.triggerHaptic(.light)
        } label: {
            VStack(spacing: 0) {
                // Progress line
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Theme.border).frame(height: 2)
                        Rectangle()
                            .fill(Theme.accent)
                            .frame(width: geo.size.width * CGFloat(player.progress), height: 2)
                            .animation(.linear(duration: 0.5), value: player.progress)
                    }
                }
                .frame(height: 2)

                HStack(spacing: 10) {
                    CachedAsyncImage(url: player.currentTrack?.coverURL ?? "")
                        .frame(width: 42, height: 42)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 0.5))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(player.currentTrack?.title ?? "")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.textPrimary)
                            .lineLimit(1)
                        Text(player.currentTrack?.artist ?? "")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.textSecondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 6) {
                        Button {
                            player.playPrevious()
                            SettingsStore.shared.triggerHaptic(.light)
                        } label: {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Theme.textSecondary)
                                .frame(width: 36, height: 36)
                        }
                        .buttonStyle(ScaleButtonStyle(scale: 0.85))

                        Button {
                            player.togglePlayPause()
                            SettingsStore.shared.triggerHaptic(.medium)
                        } label: {
                            ZStack {
                                Circle().fill(Theme.accent).frame(width: 38, height: 38)
                                if case .loading = player.playerState {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.7)
                                } else {
                                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(.white)
                                        .offset(x: player.isPlaying ? 0 : 1)
                                }
                            }
                        }
                        .buttonStyle(ScaleButtonStyle(scale: 0.92))

                        Button {
                            player.playNext()
                            SettingsStore.shared.triggerHaptic(.light)
                        } label: {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Theme.textSecondary)
                                .frame(width: 36, height: 36)
                        }
                        .buttonStyle(ScaleButtonStyle(scale: 0.85))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
        }
        .buttonStyle(.plain)
        .background(Theme.surface)
        .overlay(
            Rectangle().frame(height: 0.5).foregroundColor(Theme.border),
            alignment: .top
        )
    }
}
