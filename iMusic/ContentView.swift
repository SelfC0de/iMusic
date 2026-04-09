import SwiftUI

struct ContentView: View {
    @State private var selectedTab: TabItem = .search
    @State private var showPlayer = false
    @EnvironmentObject var toast: ToastManager
    @EnvironmentObject var player: AudioPlayerManager

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.bg0.ignoresSafeArea()

            // Tab content
            ZStack {
                SearchView()
                    .opacity(selectedTab == .search ? 1 : 0)
                    .allowsHitTesting(selectedTab == .search)
                LibraryView()
                    .opacity(selectedTab == .library ? 1 : 0)
                    .allowsHitTesting(selectedTab == .library)
                SettingsView()
                    .opacity(selectedTab == .settings ? 1 : 0)
                    .allowsHitTesting(selectedTab == .settings)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // bottom padding so content clears mini-bar + tab
            .padding(.bottom, player.currentTrack != nil ? 148 : 80)

            // Tab bar + mini player
            VStack(spacing: 0) {
                // Mini player bar (фото 2)
                if player.currentTrack != nil {
                    MiniPlayerBar(showPlayer: $showPlayer)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Tab bar
                HStack(spacing: 0) {
                    ForEach(TabItem.allCases, id: \.self) { tab in
                        Button {
                            guard selectedTab != tab else { return }
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                                selectedTab = tab
                            }
                            SettingsStore.shared.triggerHaptic(.light)
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: selectedTab == tab
                                      ? tab.icon.replacingOccurrences(of: ".fill", with: "") + ".fill"
                                      : tab.icon)
                                    .font(.system(size: 22, weight: selectedTab == tab ? .semibold : .regular))
                                    .foregroundColor(selectedTab == tab ? Theme.accentBright : Theme.textTertiary)
                                Text(tab.title)
                                    .font(.system(size: 10, weight: selectedTab == tab ? .semibold : .regular))
                                    .foregroundColor(selectedTab == tab ? Theme.accentBright : Theme.textTertiary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 10)
                .padding(.bottom, 28)
                .background(
                    ZStack(alignment: .top) {
                        Theme.bg1
                        Rectangle().frame(height: 0.5).foregroundColor(Theme.border)
                    }
                )
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: player.currentTrack?.id)

            ToastOverlay()

            // Full screen player (фото 1)
            if showPlayer {
                PlayerSheet(showPlayer: $showPlayer)
                    .transition(.move(edge: .bottom))
                    .zIndex(10)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .onChange(of: player.currentTrack?.id) {
            if let track = player.currentTrack {
                LibraryStore.shared.addToRecent(track)
            }
        }
    }
}
