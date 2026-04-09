import SwiftUI

// MARK: – ViewModel

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var tracks: [Track] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var error: String?

    // per-source pagination state
    private var hasMoreS1 = true
    private var hasMoreS2 = true
    var hasMore: Bool { hasMoreS1 || hasMoreS2 }

    private var pageS1 = 0
    private var pageS2 = 0
    private var lastQuery = ""
    private var searchTask: Task<Void, Never>?

    func search() {
        let q = query.trimmed
        guard !q.isEmpty else { return }
        searchTask?.cancel()
        pageS1 = 0; pageS2 = 0
        hasMoreS1 = true; hasMoreS2 = true
        lastQuery = q
        tracks = []
        isLoading = true
        error = nil

        searchTask = Task {
            let results = await SearchService.shared.searchBoth(query: q, page: 0)
            if Task.isCancelled { return }
            if results.isEmpty { error = "Ничего не найдено. Попробуйте другой запрос." }
            tracks = results
            // heuristic: if either source returned fewer than 48, it's exhausted
            let s1c = results.filter { $0.source == .source1 }.count
            let s2c = results.filter { $0.source == .source2 }.count
            hasMoreS1 = s1c >= 48
            hasMoreS2 = s2c >= 40   // zvukofon pages may vary
            isLoading = false
        }
    }

    func loadMore() {
        guard !isLoadingMore, hasMore, !lastQuery.isEmpty else { return }
        isLoadingMore = true

        let q = lastQuery
        let doS1 = hasMoreS1
        let doS2 = hasMoreS2
        let nextS1 = pageS1 + 1
        let nextS2 = pageS2 + 1

        Task {
            async let r1: [Track] = doS1 ? SearchService.shared.searchSource1(query: q, page: nextS1) : []
            async let r2: [Track] = doS2 ? SearchService.shared.searchSource2(query: q, page: nextS2) : []
            let (t1, t2) = await (r1, r2)

            // Deduplicate against existing
            var existingKeys = Set(tracks.map { dedupeKey($0) })
            var merged: [Track] = []
            for t in t1 + t2 {
                let k = dedupeKey(t)
                if !existingKeys.contains(k) { existingKeys.insert(k); merged.append(t) }
            }

            tracks.append(contentsOf: merged)
            if doS1 { pageS1 = nextS1; hasMoreS1 = t1.count >= 48 }
            if doS2 { pageS2 = nextS2; hasMoreS2 = t2.count >= 40 }
            isLoadingMore = false
        }
    }

    func clear() {
        searchTask?.cancel()
        query = ""; tracks = []; error = nil
        isLoading = false; isLoadingMore = false
        hasMoreS1 = true; hasMoreS2 = true
        pageS1 = 0; pageS2 = 0; lastQuery = ""
    }

    private func dedupeKey(_ t: Track) -> String {
        let a = t.artist.lowercased().filter { $0.isLetter || $0.isNumber }
        let ti = t.title.lowercased().filter { $0.isLetter || $0.isNumber }
        return "\(a)_\(ti)"
    }
}

// MARK: – View

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
            // source count badge
            if !vm.tracks.isEmpty {
                sourceStats
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 56)
        .padding(.bottom, 12)
    }

    private var sourceStats: some View {
        HStack(spacing: 6) {
            let s1 = vm.tracks.filter { $0.source == .source1 }.count
            let s2 = vm.tracks.filter { $0.source == .source2 }.count
            if s1 > 0 {
                sourcePill(count: s1, color: Theme.accent)
            }
            if s2 > 0 {
                sourcePill(count: s2, color: Theme.accentBright)
            }
        }
    }

    private func sourcePill(count: Int, color: Color) -> some View {
        Text("\(count)")
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
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
                    Button { vm.clear(); isFocused = false } label: {
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
                Button("Отмена") { vm.clear(); isFocused = false }
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
                ZStack {
                    Circle().stroke(Theme.border, lineWidth: 3).frame(width: 44, height: 44)
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(Theme.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 44, height: 44)
                        .rotationEffect(.degrees(-90))
                        .modifier(SpinModifier())
                }
                Text("Ищем треки...")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.textTertiary)
            }
            Spacer()
        } else if let err = vm.error, vm.tracks.isEmpty {
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
                    .padding(.horizontal, 20).padding(.vertical, 8)
                    .background(Theme.accentGlow).cornerRadius(Theme.cornerSm)
            }
            .padding(.horizontal, 32)
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
                Circle().fill(Theme.accentGlow).frame(width: 100, height: 100)
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 40))
                    .foregroundColor(Theme.accentDim)
            }
            VStack(spacing: 8) {
                Text("Найди свою музыку")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                
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
                    Color.clear
                        .frame(height: 1)
                        .onAppear { vm.loadMore() }

                    if vm.isLoadingMore {
                        HStack(spacing: 8) {
                            ZStack {
                                Circle().stroke(Theme.border, lineWidth: 2.5).frame(width: 20, height: 20)
                                Circle()
                                    .trim(from: 0, to: 0.65)
                                    .stroke(Theme.accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                                    .frame(width: 20, height: 20)
                                    .rotationEffect(.degrees(-90))
                                    .modifier(SpinModifier())
                            }
                            Text("Загрузка...")
                                .font(.system(size: 13))
                                .foregroundColor(Theme.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                }
            }
            .padding(.bottom, 140)
        }
    }
}

// MARK: – Spin animation modifier

struct SpinModifier: ViewModifier {
    @State private var angle: Double = 0
    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(angle))
            .onAppear {
                withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                    angle = 360
                }
            }
    }
}

