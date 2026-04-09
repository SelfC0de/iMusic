import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var library: LibraryStore
    @EnvironmentObject var player: AudioPlayerManager
    @EnvironmentObject var toast: ToastManager
    @State private var selectedSection: LibrarySection = .favorites

    enum LibrarySection: String, CaseIterable {
        case favorites = "Избранное"
        case downloaded = "Загрузки"
        case recent = "История"

        var icon: String {
            switch self {
            case .favorites: return "heart.fill"
            case .downloaded: return "arrow.down.circle.fill"
            case .recent: return "clock.fill"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            segmentedControl
            content
        }
        .background(Theme.bg0)
    }

    private var header: some View {
        HStack {
            Text("Библиотека")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(Theme.textPrimary)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 56)
        .padding(.bottom, 12)
    }

    private var segmentedControl: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(LibrarySection.allCases, id: \.self) { section in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            selectedSection = section
                        }
                        SettingsStore.shared.triggerHaptic(.light)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: section.icon)
                                .font(.system(size: 12))
                            Text(section.rawValue)
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(selectedSection == section ? Theme.accent : Theme.surface)
                        .foregroundColor(selectedSection == section ? .white : Theme.textSecondary)
                        .cornerRadius(Theme.cornerSm)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.cornerSm)
                                .stroke(selectedSection == section ? Theme.accent : Theme.border, lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
    }

    @ViewBuilder
    private var content: some View {
        let tracks: [Track] = {
            switch selectedSection {
            case .favorites: return library.favorites
            case .downloaded: return library.downloaded
            case .recent: return library.recentlyPlayed
            }
        }()

        if tracks.isEmpty {
            Spacer()
            VStack(spacing: 16) {
                Image(systemName: selectedSection.icon)
                    .font(.system(size: 40))
                    .foregroundColor(Theme.textTertiary)
                Text(emptyMessage)
                    .font(.system(size: 15))
                    .foregroundColor(Theme.textTertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            Spacer()
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(tracks.enumerated()), id: \.element.id) { idx, track in
                        TrackRow(
                            track: track,
                            isPlaying: player.currentTrack?.id == track.id,
                            queue: tracks,
                            index: idx
                        )
                        Divider()
                            .background(Theme.borderSubtle)
                            .padding(.leading, 78)
                    }
                }
                .padding(.bottom, 140)
            }
        }
    }

    private var emptyMessage: String {
        switch selectedSection {
        case .favorites: return "Нет избранных треков.\nНажми ♥ на любом треке."
        case .downloaded: return "Нет загруженных треков.\nСкачай музыку для офлайн."
        case .recent: return "История пуста.\nПослушай что-нибудь!"
        }
    }
}
