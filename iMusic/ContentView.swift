import SwiftUI

struct ContentView: View {
    @State private var selectedTab: TabItem = .search
    @EnvironmentObject var toast: ToastManager
    @EnvironmentObject var player: AudioPlayerManager

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.bg0.ignoresSafeArea()

            ZStack {
                SearchView()
                    .opacity(selectedTab == .search ? 1 : 0)
                    .allowsHitTesting(selectedTab == .search)

                PlayerView()
                    .opacity(selectedTab == .player ? 1 : 0)
                    .allowsHitTesting(selectedTab == .player)

                LibraryView()
                    .opacity(selectedTab == .library ? 1 : 0)
                    .allowsHitTesting(selectedTab == .library)

                SettingsView()
                    .opacity(selectedTab == .settings ? 1 : 0)
                    .allowsHitTesting(selectedTab == .settings)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 0) {
                CustomTabBar(selected: $selectedTab)
            }

            ToastOverlay()
        }
        .ignoresSafeArea(edges: .bottom)
        .onChange(of: player.currentTrack?.id) { _ in
            if let track = player.currentTrack {
                LibraryStore.shared.addToRecent(track)
            }
        }
    }
}
