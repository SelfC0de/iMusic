import SwiftUI

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var tracks: [Track] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var error: String?
    @Published var hasMore = true

    private var currentPage = 0
    private var lastQuery = ""
    private var searchTask: Task<Void, Never>?

    func search() {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        searchTask?.cancel()
        currentPage = 0
        lastQuery = q
        tracks = []
        hasMore = true
        isLoading = true
        error = nil

        searchTask = Task {
            do {
                let results = try await SearchService.shared.search(query: q, page: 0)
                if Task.isCancelled { return }
                tracks = results
                hasMore = results.count >= 48
            } catch {
                if !Task.isCancelled {
                    self.error = "Ошибка загрузки. Проверьте соединение."
                }
            }
            isLoading = false
        }
    }

    func loadMore() {
        guard !isLoadingMore, hasMore, !lastQuery.isEmpty else { return }
        isLoadingMore = true
        currentPage += 1
        let page = currentPage
        let q = lastQuery

        Task {
            do {
                let results = try await SearchService.shared.search(query: q, page: page)
                await MainActor.run {
                    tracks.append(contentsOf: results)
                    hasMore = results.count >= 48
                    isLoadingMore = false
                }
            } catch {
                await MainActor.run {
                    isLoadingMore = false
                }
            }
        }
    }

    func clear() {
        searchTask?.cancel()
        query = ""
        tracks = []
        error = nil
        isLoading = false
        hasMore = true
        currentPage = 0
        lastQuery = ""
    }
}

struct SearchView: View {
    @StateObject private var vm = SearchViewModel()
    @EnvironmentObject var player: AudioPlayerManager
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            headerView
            searchBar
            contentArea
        }
        .background(Theme.bg0)
    }

    private var headerView: some View {
        HStack {
            Text("Поиск")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(Theme.textPrimary)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 56)
        .padding(.bottom, 12)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15))
                    .foregroundColor(isFocused ? Theme.accent : Theme.textTertiary)

                TextField("Исполнитель, трек...", text: $vm.query)
                    .font(.system(size: 15))
                    .foregroundColor(Theme.textPrimary)
                    .autocorrectionDisabled()
                    .autocapitalization(.none)
                    .focused($isFocused)
                    .submitLabel(.search)
                    .onSubmit { vm.search() }
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Готово") { isFocused = false }
                                .foregroundColor(Theme.accent)
                                .fontWeight(.semibold)
                        }
                    }

                if !vm.query.isEmpty {
                    Button {
                        vm.clear()
                        isFocused = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundColor(Theme.textTertiary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Theme.surface)
            .cornerRadius(Theme.cornerMd)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerMd)
                    .stroke(isFocused ? Theme.accent.opacity(0.5) : Theme.border, lineWidth: 1)
            )
            .animation(.easeInOut(duration: 0.2), value: isFocused)

            if isFocused {
                Button("Отмена") {
                    vm.clear()
                    isFocused = false
                }
                .font(.system(size: 15))
                .foregroundColor(Theme.accent)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isFocused)
    }

    @ViewBuilder
    private var contentArea: some View {
        if vm.isLoading {
            Spacer()
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Theme.accent))
                    .scaleEffect(1.2)
                Text("Ищем треки...")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.textTertiary)
            }
            Spacer()
        } else if let err = vm.error {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 36))
                    .foregroundColor(Theme.textTertiary)
                Text(err)
                    .font(.system(size: 14))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                Button("Повторить") { vm.search() }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.accent)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Theme.accentGlow)
                    .cornerRadius(Theme.cornerSm)
            }
            .padding(.horizontal, 32)
            Spacer()
        } else if vm.tracks.isEmpty && !vm.query.isEmpty {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 36))
                    .foregroundColor(Theme.textTertiary)
                Text("Ничего не найдено")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer()
        } else if vm.tracks.isEmpty {
            emptyState
        } else {
            tracksList
        }
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Theme.accentGlow)
                    .frame(width: 100, height: 100)
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 40))
                    .foregroundColor(Theme.accentDim)
            }
            VStack(spacing: 8) {
                Text("Найди свою музыку")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                Text("Введи название трека или исполнителя")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.textTertiary)
            }
            Spacer()
        }
    }

    private var tracksList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(vm.tracks.enumerated()), id: \.element.id) { idx, track in
                    TrackRow(
                        track: track,
                        isPlaying: player.currentTrack?.id == track.id,
                        queue: vm.tracks,
                        index: idx
                    )
                    Divider()
                        .background(Theme.borderSubtle)
                        .padding(.leading, 78)
                }

                if vm.hasMore {
                    Button {
                        vm.loadMore()
                    } label: {
                        HStack(spacing: 8) {
                            if vm.isLoadingMore {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Theme.accent))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.down.circle")
                                    .font(.system(size: 16))
                                    .foregroundColor(Theme.accent)
                            }
                            Text(vm.isLoadingMore ? "Загрузка..." : "Загрузить ещё")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Theme.accent)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    }
                    .buttonStyle(.plain)
                    .disabled(vm.isLoadingMore)
                }
            }
            .padding(.bottom, 140)
        }
    }
}
