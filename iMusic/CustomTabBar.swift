import SwiftUI

struct CustomTabBar: View {
    @Binding var selected: TabItem
    @EnvironmentObject var player: AudioPlayerManager

    var body: some View {
        VStack(spacing: 0) {
            if player.currentTrack != nil {
                MiniPlayerBar()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            HStack(spacing: 0) {
                ForEach(TabItem.allCases, id: \.self) { tab in
                    TabBarButton(tab: tab, isSelected: selected == tab) {
                        if selected != tab {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                selected = tab
                            }
                            SettingsStore.shared.triggerHaptic(.light)
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 10)
            .padding(.bottom, 24)
            .background(
                ZStack {
                    Theme.bg1
                    Rectangle()
                        .frame(height: 0.5)
                        .foregroundColor(Theme.border)
                        .frame(maxHeight: .infinity, alignment: .top)
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
                            .frame(width: 44, height: 28)
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
    @EnvironmentObject var player: AudioPlayerManager
    @EnvironmentObject var toast: ToastManager

    var body: some View {
        HStack(spacing: 12) {
            CachedAsyncImage(url: player.currentTrack?.coverURL ?? "")
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Theme.border, lineWidth: 0.5)
                )

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

            Spacer()

            Button {
                player.playPrevious()
                SettingsStore.shared.triggerHaptic(.light)
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Theme.textSecondary)
            }

            Button {
                player.togglePlayPause()
                SettingsStore.shared.triggerHaptic(.medium)
            } label: {
                ZStack {
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: 36, height: 36)
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
            }

            Button {
                player.playNext()
                SettingsStore.shared.triggerHaptic(.light)
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.surface)
        .overlay(
            GeometryReader { geo in
                VStack {
                    Rectangle()
                        .fill(Theme.border)
                        .frame(height: 0.5)
                    Spacer()
                }
            }
        )
        .overlay(
            GeometryReader { geo in
                HStack(spacing: 0) {
                    Theme.accent
                        .frame(width: geo.size.width * player.progress)
                    Spacer(minLength: 0)
                }
                .frame(height: 2)
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
        )
    }
}
