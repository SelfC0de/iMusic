import SwiftUI
import PhotosUI

struct LibraryView: View {
    @EnvironmentObject var library: LibraryStore
    @EnvironmentObject var player: AudioPlayerManager
    @EnvironmentObject var toast: ToastManager
    @State private var selectedSection: LibrarySection = .favorites
    @State private var showCreatePlaylist = false

    enum LibrarySection: String, CaseIterable {
        case favorites  = "Избранное"
        case downloaded = "Загрузки"
        case recent     = "История"
        case playlists  = "Плейлисты"

        var icon: String {
            switch self {
            case .favorites:  return "heart.fill"
            case .downloaded: return "arrow.down.circle.fill"
            case .recent:     return "clock.fill"
            case .playlists:  return "music.note.list"
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
        .sheet(isPresented: $showCreatePlaylist) {
            CreatePlaylistSheet()
                .presentationDetents([.height(280)])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: – Header

    private var header: some View {
        HStack {
            Text("Библиотека")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(Theme.textPrimary)
            Spacer()
            // Action button per section
            switch selectedSection {
            case .recent:
                if !library.recentlyPlayed.isEmpty {
                    Button {
                        library.clearRecent()
                        toast.show("История очищена", style: .info, position: .top)
                        SettingsStore.shared.triggerHaptic(.medium)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 17))
                            .foregroundColor(Theme.danger)
                            .frame(width: 36, height: 36)
                    }
                }
            case .playlists:
                Button { showCreatePlaylist = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Theme.accentBright)
                        .frame(width: 36, height: 36)
                }
            default:
                EmptyView()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 56)
        .padding(.bottom, 12)
    }

    // MARK: – Segment

    private var segmentedControl: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(LibrarySection.allCases, id: \.self) { section in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { selectedSection = section }
                        SettingsStore.shared.triggerHaptic(.light)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: section.icon).font(.system(size: 12))
                            Text(section.rawValue).font(.system(size: 13, weight: .semibold))
                        }
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(selectedSection == section ? Theme.accent : Theme.surface)
                        .foregroundColor(selectedSection == section ? .white : Theme.textSecondary)
                        .cornerRadius(Theme.cornerSm)
                        .overlay(RoundedRectangle(cornerRadius: Theme.cornerSm)
                            .stroke(selectedSection == section ? Theme.accent : Theme.border, lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20).padding(.bottom, 12)
        }
    }

    // MARK: – Content

    @ViewBuilder
    private var content: some View {
        switch selectedSection {
        case .favorites:  SearchableTrackList(tracks: library.favorites, emptyIcon: "heart.fill", emptyText: "Нет избранных треков.\nНажми ♥ на любом треке.")
        case .downloaded: SearchableTrackList(tracks: library.downloaded, emptyIcon: "arrow.down.circle.fill", emptyText: "Нет загруженных треков.\nСкачай музыку для офлайн.")
        case .recent:     SearchableTrackList(tracks: library.recentlyPlayed, emptyIcon: "clock.fill", emptyText: "История пуста.\nПослушай что-нибудь!")
        case .playlists:  PlaylistsTab()
        }
    }
}

// MARK: – Searchable track list (Favorites / Downloads / History)

struct SearchableTrackList: View {
    let tracks: [Track]
    let emptyIcon: String
    let emptyText: String

    @EnvironmentObject var player: AudioPlayerManager
    @State private var query = ""

    var filtered: [Track] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return tracks }
        let q = query.lowercased()
        return tracks.filter { $0.title.lowercased().contains(q) || $0.artist.lowercased().contains(q) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            if !tracks.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.textTertiary)
                    TextField("Поиск...", text: $query)
                        .font(.system(size: 14))
                        .foregroundColor(Theme.textPrimary)
                    if !query.isEmpty {
                        Button { query = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Theme.textTertiary)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Theme.surface)
                .cornerRadius(Theme.cornerMd)
                .overlay(RoundedRectangle(cornerRadius: Theme.cornerMd).stroke(Theme.border, lineWidth: 0.5))
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
            }

            if filtered.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: query.isEmpty ? emptyIcon : "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(Theme.textTertiary)
                    Text(query.isEmpty ? emptyText : "Ничего не найдено")
                        .font(.system(size: 15))
                        .foregroundColor(Theme.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(filtered.enumerated()), id: \.element.id) { idx, track in
                            TrackRow(track: track, isPlaying: player.currentTrack?.id == track.id, queue: filtered, index: idx)
                            Divider().background(Theme.borderSubtle).padding(.leading, 78)
                        }
                    }
                    .padding(.bottom, 140)
                }
            }
        }
    }
}

// MARK: – Playlists tab

struct PlaylistsTab: View {
    @EnvironmentObject var library: LibraryStore
    @EnvironmentObject var player: AudioPlayerManager
    @EnvironmentObject var toast: ToastManager
    @State private var editingPlaylist: Playlist? = nil
    @State private var openPlaylist: Playlist? = nil

    var body: some View {
        if library.playlists.isEmpty {
            Spacer()
            VStack(spacing: 16) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 40))
                    .foregroundColor(Theme.textTertiary)
                Text("Нет плейлистов.\nНажми + чтобы создать.")
                    .font(.system(size: 15))
                    .foregroundColor(Theme.textTertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            Spacer()
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(library.playlists) { pl in
                        PlaylistRow(playlist: pl)
                            .contentShape(Rectangle())
                            .onTapGesture { openPlaylist = pl }
                            .contextMenu {
                                Button { editingPlaylist = pl } label: {
                                    Label("Переименовать", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    library.deletePlaylist(pl)
                                    toast.show("Плейлист удалён", style: .info, position: .top)
                                } label: {
                                    Label("Удалить", systemImage: "trash")
                                }
                            }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 140)
            }
            .sheet(item: $openPlaylist) { pl in
                PlaylistDetailSheet(playlist: pl)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $editingPlaylist) { pl in
                EditPlaylistSheet(playlist: pl)
                    .presentationDetents([.height(340)])
                    .presentationDragIndicator(.visible)
            }
        }
    }
}

// MARK: – Playlist row card

struct PlaylistRow: View {
    let playlist: Playlist

    var body: some View {
        HStack(spacing: 14) {
            // Cover
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Theme.accentGlow)
                    .frame(width: 52, height: 52)
                if let img = playlist.coverImage {
                    Image(uiImage: img)
                        .resizable().scaledToFill()
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 20))
                        .foregroundColor(Theme.accentBright)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(playlist.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
                Text("\(playlist.tracks.count) треков")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(Theme.textTertiary)
        }
        .padding(14)
        .background(Theme.surface)
        .cornerRadius(Theme.cornerMd)
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerMd).stroke(Theme.border, lineWidth: 0.5))
    }
}

// MARK: – Playlist detail

struct PlaylistDetailSheet: View {
    @State var playlist: Playlist
    @EnvironmentObject var library: LibraryStore
    @EnvironmentObject var player: AudioPlayerManager
    @Environment(\.dismiss) var dismiss

    var current: Playlist { library.playlists.first { $0.id == playlist.id } ?? playlist }

    var body: some View {
        NavigationView {
            Group {
                if current.tracks.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "music.note")
                            .font(.system(size: 40))
                            .foregroundColor(Theme.textTertiary)
                        Text("Плейлист пуст.\nДобавь треки из поиска.")
                            .font(.system(size: 15))
                            .foregroundColor(Theme.textTertiary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.bg1)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(current.tracks.enumerated()), id: \.element.id) { idx, track in
                                TrackRow(track: track, isPlaying: player.currentTrack?.id == track.id,
                                         queue: current.tracks, index: idx)
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            library.removeFromPlaylist(track, playlist: current)
                                        } label: { Label("Удалить", systemImage: "trash") }
                                    }
                                Divider().background(Theme.borderSubtle).padding(.leading, 78)
                            }
                        }
                        .padding(.bottom, 80)
                    }
                    .background(Theme.bg1)
                }
            }
            .navigationTitle(current.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Закрыть") { dismiss() }
                        .foregroundColor(Theme.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: – Create playlist sheet

struct CreatePlaylistSheet: View {
    @EnvironmentObject var library: LibraryStore
    @EnvironmentObject var toast: ToastManager
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var photosItem: PhotosPickerItem? = nil
    @State private var coverImage: UIImage? = nil
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 20) {
            Text("Новый плейлист")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(Theme.textPrimary)
                .padding(.top, 20)

            // Cover picker
            PhotosPicker(selection: $photosItem, matching: .images) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Theme.accentGlow)
                        .frame(width: 72, height: 72)
                    if let img = coverImage {
                        Image(uiImage: img)
                            .resizable().scaledToFill()
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    } else {
                        VStack(spacing: 4) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 22))
                                .foregroundColor(Theme.accentBright)
                            Text("Обложка")
                                .font(.system(size: 10))
                                .foregroundColor(Theme.textTertiary)
                        }
                    }
                }
            }
            .onChange(of: photosItem, perform: { newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let img = UIImage(data: data) {
                        await MainActor.run { coverImage = img }
                    }
                }
            })

            TextField("Название...", text: $name)
                .font(.system(size: 16))
                .foregroundColor(Theme.textPrimary)
                .padding(14)
                .background(Theme.surface)
                .cornerRadius(Theme.cornerMd)
                .overlay(RoundedRectangle(cornerRadius: Theme.cornerMd).stroke(Theme.border, lineWidth: 0.5))
                .focused($focused)
                .onSubmit { create() }
                .padding(.horizontal, 20)

            HStack(spacing: 12) {
                Button("Отмена") { dismiss() }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.surface)
                    .cornerRadius(Theme.cornerMd)

                Button("Создать") { create() }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(name.trimmed.isEmpty ? Theme.accentDim : Theme.accent)
                    .cornerRadius(Theme.cornerMd)
                    .disabled(name.trimmed.isEmpty)
            }
            .padding(.horizontal, 20)
            Spacer()
        }
        .background(Theme.bg1.ignoresSafeArea())
        .onAppear { focused = true }
    }

    private func create() {
        guard !name.trimmed.isEmpty else { return }
        var pl = Playlist(name: name)
        if let img = coverImage { pl.coverImageData = img.jpegData(compressionQuality: 0.7) }
        library.playlists.insert(pl, at: 0)
        library.savePlaylists()
        toast.show("Плейлист создан", style: .success, position: .top)
        SettingsStore.shared.triggerHaptic(.medium)
        dismiss()
    }
}

// MARK: – Edit playlist sheet (rename + cover)

struct EditPlaylistSheet: View {
    let playlist: Playlist
    @EnvironmentObject var library: LibraryStore
    @EnvironmentObject var toast: ToastManager
    @Environment(\.dismiss) var dismiss
    @State private var name: String
    @State private var photosItem: PhotosPickerItem? = nil
    @State private var coverImage: UIImage? = nil
    @FocusState private var focused: Bool

    init(playlist: Playlist) {
        self.playlist = playlist
        _name = State(initialValue: playlist.name)
        _coverImage = State(initialValue: playlist.coverImage)
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Редактировать")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(Theme.textPrimary)
                .padding(.top, 20)

            // Cover picker
            PhotosPicker(selection: $photosItem, matching: .images) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Theme.accentGlow)
                        .frame(width: 72, height: 72)
                    if let img = coverImage {
                        Image(uiImage: img)
                            .resizable().scaledToFill()
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    } else {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 24))
                            .foregroundColor(Theme.accentBright)
                    }
                    // Edit badge
                    VStack { Spacer(); HStack { Spacer()
                        Circle().fill(Theme.accent).frame(width: 22, height: 22)
                            .overlay(Image(systemName: "pencil").font(.system(size: 10)).foregroundColor(.white))
                            .offset(x: 4, y: 4)
                    }}
                }
            }
            .onChange(of: photosItem, perform: { newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let img = UIImage(data: data) {
                        await MainActor.run { coverImage = img }
                    }
                }
            })

            // Name field
            TextField("Название...", text: $name)
                .font(.system(size: 16))
                .foregroundColor(Theme.textPrimary)
                .padding(14)
                .background(Theme.surface)
                .cornerRadius(Theme.cornerMd)
                .overlay(RoundedRectangle(cornerRadius: Theme.cornerMd).stroke(Theme.border, lineWidth: 0.5))
                .focused($focused)
                .padding(.horizontal, 20)

            HStack(spacing: 12) {
                Button("Отмена") { dismiss() }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Theme.surface).cornerRadius(Theme.cornerMd)

                Button("Сохранить") { save() }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Theme.accent).cornerRadius(Theme.cornerMd)
            }
            .padding(.horizontal, 20)
            Spacer()
        }
        .background(Theme.bg1.ignoresSafeArea())
    }

    private func save() {
        library.renamePlaylist(playlist, name: name)
        if let img = coverImage { library.setPlaylistCover(playlist, image: img) }
        toast.show("Сохранено", style: .success, position: .top)
        SettingsStore.shared.triggerHaptic(.medium)
        dismiss()
    }
}
