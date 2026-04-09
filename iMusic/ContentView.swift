import SwiftUI

struct ContentView: View {
    @State private var selectedTab: TabItem = .search
    @State private var showPlayer = false
    @EnvironmentObject var toast: ToastManager
    @EnvironmentObject var player: AudioPlayerManager

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.bg0.ignoresSafeArea()

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

            VStack(spacing: 0) {
                CustomTabBar(selected: $selectedTab, showPlayer: $showPlayer)
            }

            ToastOverlay()
        }
        .ignoresSafeArea(edges: .bottom)
        .sheet(isPresented: $showPlayer) {
            PlayerSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.bg0)
        }
        .onChange(of: player.currentTrack?.id) {
            if let track = player.currentTrack {
                LibraryStore.shared.addToRecent(track)
            }
        }
    }
}
