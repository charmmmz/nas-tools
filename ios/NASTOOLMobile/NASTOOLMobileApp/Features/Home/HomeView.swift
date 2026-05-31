import SwiftUI

typealias HomeViewAPI = HomeAPI & HomeDetailAPI

struct HomeView: View {
    @State private var store: HomeStore
    @State private var isShowingRegionSheet = false

    private let detailAPI: any HomeDetailAPI
    private let imageBaseURL: URL?

    init(api: any HomeViewAPI, imageBaseURL: URL? = nil) {
        _store = State(initialValue: HomeStore(api: api))
        self.detailAPI = api
        self.imageBaseURL = imageBaseURL
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HomeHeader(
                    groupSelection: groupSelection,
                    filterSelection: filterSelection,
                    filters: store.filters,
                    regionTitle: regionTitle,
                    isRegionScoped: store.selectedGroup == .popular,
                    onRegionTap: {
                        isShowingRegionSheet = true
                    }
                )

                if let errorMessage = store.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                }

                if store.items.isEmpty {
                    HomeEmptyState(isLoading: store.isLoading)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 56)
                } else {
                    HomePosterWall(
                        items: store.items,
                        imageBaseURL: imageBaseURL,
                        detailAPI: detailAPI,
                        onLastItemAppear: {
                            Task {
                                await store.loadMore()
                            }
                        }
                    )
                    .padding(.horizontal)

                    if store.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                    }
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Home")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingRegionSheet = true
                } label: {
                    Image(systemName: "globe")
                }
                .accessibilityLabel("Region")
            }
        }
        .refreshable {
            await store.loadInitial()
        }
        .task {
            await store.loadInitial()
        }
        .sheet(isPresented: $isShowingRegionSheet) {
            HomeRegionSelectionSheet(
                selection: store.regionSelection,
                effectiveRegion: store.effectiveRegion,
                onSelect: selectRegion
            )
        }
    }

    private var groupSelection: Binding<HomeFeedGroup> {
        Binding {
            store.selectedGroup
        } set: { group in
            guard group != store.selectedGroup else {
                return
            }
            store.select(group: group)
            Task {
                await store.loadInitial()
            }
        }
    }

    private var filterSelection: Binding<HomeFeedFilter> {
        Binding {
            store.selectedFilter
        } set: { filter in
            guard filter != store.selectedFilter else {
                return
            }
            store.select(filter: filter)
            Task {
                await store.loadInitial()
            }
        }
    }

    private var regionTitle: String {
        switch store.regionSelection {
        case .automatic:
            if let effectiveRegion = store.effectiveRegion {
                return "Auto \(effectiveRegion)"
            }
            return "Auto"
        case .region(let code):
            return HomeRegionSelection.normalizedRegionCode(code) ?? code
        }
    }

    private func selectRegion(_ selection: HomeRegionSelection) {
        store.regionSelection = selection
        if store.selectedGroup == .popular {
            Task {
                await store.loadInitial()
            }
        }
    }
}

private struct HomeHeader: View {
    @Binding var groupSelection: HomeFeedGroup
    @Binding var filterSelection: HomeFeedFilter

    let filters: [HomeFeedFilter]
    let regionTitle: String
    let isRegionScoped: Bool
    let onRegionTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Feed", selection: $groupSelection) {
                ForEach(HomeFeedGroup.allCases) { group in
                    Text(group.title).tag(group)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 10) {
                Picker("Filter", selection: $filterSelection) {
                    ForEach(filters) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)

                Button(action: onRegionTap) {
                    Label(regionTitle, systemImage: "globe")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Region \(regionTitle)")
                .opacity(isRegionScoped ? 1 : 0.55)
            }
        }
        .padding(.horizontal)
    }
}

private struct HomePosterWall: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let items: [HomePosterItem]
    let imageBaseURL: URL?
    let detailAPI: any HomeDetailAPI
    let onLastItemAppear: () -> Void

    var body: some View {
        let columns = Self.makeColumns(items: items, count: columnCount)

        HStack(alignment: .top, spacing: 12) {
            ForEach(columns.indices, id: \.self) { columnIndex in
                LazyVStack(spacing: 12) {
                    ForEach(columns[columnIndex]) { item in
                        NavigationLink {
                            HomeMediaDetailView(
                                item: item,
                                api: detailAPI,
                                imageBaseURL: imageBaseURL
                            )
                        } label: {
                            HomePosterCard(
                                item: item,
                                imageBaseURL: imageBaseURL,
                                posterHeight: posterHeight(for: item, columnCount: columnCount)
                            )
                        }
                        .buttonStyle(.plain)
                        .onAppear {
                            if item.id == items.last?.id {
                                onLastItemAppear()
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var columnCount: Int {
        horizontalSizeClass == .regular ? 3 : 2
    }

    private func posterHeight(for item: HomePosterItem, columnCount: Int) -> CGFloat {
        let seed = item.id.unicodeScalars.reduce(0) { partial, scalar in
            partial + Int(scalar.value)
        }
        let compactHeights: [CGFloat] = [214, 246, 282]
        let regularHeights: [CGFloat] = [244, 284, 326]
        let heights = columnCount == 2 ? compactHeights : regularHeights
        return heights[seed % heights.count]
    }

    private static func makeColumns(items: [HomePosterItem], count: Int) -> [[HomePosterItem]] {
        guard count > 1 else {
            return [items]
        }

        var columns = Array(repeating: [HomePosterItem](), count: count)
        var heights = Array(repeating: 0, count: count)

        for item in items {
            let shortestColumn = heights.enumerated().min { lhs, rhs in
                lhs.element < rhs.element
            }?.offset ?? 0
            columns[shortestColumn].append(item)
            heights[shortestColumn] += item.id.unicodeScalars.reduce(210) { partial, scalar in
                partial + Int(scalar.value % 41)
            }
        }

        return columns
    }
}

private struct HomePosterCard: View {
    let item: HomePosterItem
    let imageBaseURL: URL?
    let posterHeight: CGFloat

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            HomeRemoteImage(path: item.posterPath, baseURL: imageBaseURL)
                .frame(height: posterHeight)
                .clipped()

            LinearGradient(
                colors: [.clear, .black.opacity(0.82)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    if let year = item.year, !year.isEmpty {
                        Text(year)
                    }
                    if let voteText = item.voteText, !voteText.isEmpty, voteText != "0" {
                        Label(voteText, systemImage: "star.fill")
                            .labelStyle(.titleAndIcon)
                    }
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.82))

                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 5) {
                    if item.isFavorite {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                    Text(item.type == "TV" ? "TV" : "Movie")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.82))
                }
            }
            .padding(10)
        }
        .background(Color.secondary.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 9, y: 5)
        .accessibilityElement(children: .combine)
    }
}

private struct HomeMediaDetailView: View {
    let item: HomePosterItem
    let api: any HomeDetailAPI
    let imageBaseURL: URL?

    @State private var isSearching = false
    @State private var isSubscribing = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var isShowingAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ZStack(alignment: .bottomLeading) {
                    HomeRemoteImage(path: item.backdropPath ?? item.posterPath, baseURL: imageBaseURL)
                        .frame(maxWidth: .infinity)
                        .frame(height: 340)
                        .clipped()

                    LinearGradient(
                        colors: [.black.opacity(0.05), .black.opacity(0.86)],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.title)
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(.white)
                            .lineLimit(3)
                            .minimumScaleFactor(0.72)

                        Text(detailSubtitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.82))
                            .lineLimit(2)
                    }
                    .padding()
                }
                .frame(maxWidth: .infinity)

                actionButtons

                if let overview = item.overview, !overview.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Overview")
                            .font(.headline)
                        Text(overview)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(item.title)
        .navigationBarTitleDisplayMode(.inline)
        .alert(alertTitle, isPresented: $isShowingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    private var actionButtons: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                searchButton
                subscriptionButton
            }

            VStack(spacing: 12) {
                searchButton
                subscriptionButton
            }
        }
        .controlSize(.large)
        .padding(.horizontal)
    }

    private var searchButton: some View {
        Button {
            Task {
                await searchResources()
            }
        } label: {
            if isSearching {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else {
                Label("Search Resources", systemImage: "magnifyingglass")
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(isSearching)
    }

    private var subscriptionButton: some View {
        Button {
            Task {
                await addSubscription()
            }
        } label: {
            if isSubscribing {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else {
                Label(subscriptionButtonTitle, systemImage: "bookmark")
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.bordered)
        .disabled(isSubscribing || item.rssID != nil)
    }

    private var detailSubtitle: String {
        var parts: [String] = [item.type == "TV" ? "TV" : "Movie"]
        if let year = item.year, !year.isEmpty {
            parts.append(year)
        }
        if let voteText = item.voteText, !voteText.isEmpty, voteText != "0" {
            parts.append("Rating \(voteText)")
        }
        return parts.joined(separator: " / ")
    }

    private var subscriptionButtonTitle: String {
        item.rssID == nil ? "Add Subscription" : "Subscribed"
    }

    private func searchResources() async {
        isSearching = true
        defer { isSearching = false }

        do {
            let response = try await api.searchKeyword(
                item.title,
                quickMode: false,
                tmdbID: item.tmdbID,
                mediaType: item.type
            )
            showCommandResult(response, successMessage: "Search started.")
        } catch {
            showAlert(title: "Search Failed", message: error.localizedDescription)
        }
    }

    private func addSubscription() async {
        guard let mediaType = AddSubscriptionRequest.MediaType(homeType: item.type) else {
            showAlert(title: "Subscription Failed", message: "Unsupported media type.")
            return
        }

        isSubscribing = true
        defer { isSubscribing = false }

        do {
            let response = try await api.addSubscription(
                AddSubscriptionRequest(
                    name: item.title,
                    mediaType: mediaType,
                    year: item.year,
                    keyword: nil,
                    season: mediaType == .tv ? 1 : nil,
                    mediaID: item.tmdbID
                )
            )
            showCommandResult(response, successMessage: "Subscription added.")
        } catch {
            showAlert(title: "Subscription Failed", message: error.localizedDescription)
        }
    }

    private func showCommandResult(_ response: NastoolCommandResponse, successMessage: String) {
        if response.isSuccess {
            showAlert(title: "Done", message: successMessage)
        } else {
            showAlert(
                title: "Request Failed",
                message: response.message ?? response.msg ?? response.retmsg ?? "The server did not accept the request."
            )
        }
    }

    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        isShowingAlert = true
    }
}

private struct HomeRegionSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    let selection: HomeRegionSelection
    let effectiveRegion: String?
    let onSelect: (HomeRegionSelection) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        onSelect(.automatic)
                        dismiss()
                    } label: {
                        HomeRegionRow(
                            title: "Automatic",
                            subtitle: effectiveRegion.map { "System \($0)" },
                            isSelected: selection == .automatic
                        )
                    }
                    .buttonStyle(.plain)
                }

                Section("Regions") {
                    ForEach(filteredRegions) { region in
                        Button {
                            onSelect(.region(region.code))
                            dismiss()
                        } label: {
                            HomeRegionRow(
                                title: region.name,
                                subtitle: region.code,
                                isSelected: selection.storedRegionCode == region.code
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .searchable(text: $query, prompt: "Region")
            .navigationTitle("Region")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var filteredRegions: [HomeRegionOption] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return HomeRegionOption.all
        }

        return HomeRegionOption.all.filter { region in
            region.code.localizedCaseInsensitiveContains(trimmedQuery)
                || region.name.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }
}

private struct HomeRegionRow: View {
    let title: String
    let subtitle: String?
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .foregroundStyle(.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.headline)
                    .foregroundStyle(.tint)
            }
        }
        .contentShape(Rectangle())
    }
}

private struct HomeEmptyState: View {
    let isLoading: Bool

    var body: some View {
        if isLoading {
            ProgressView("Loading")
        } else {
            ContentUnavailableView("No Posters", systemImage: "film.stack")
        }
    }
}

private struct HomeRemoteImage: View {
    let path: String?
    let baseURL: URL?

    var body: some View {
        Group {
            if let url = resolvedURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        placeholder
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.secondary.opacity(0.14))
    }

    private var placeholder: some View {
        Image(systemName: "film")
            .font(.largeTitle)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var resolvedURL: URL? {
        guard let path, !path.isEmpty else {
            return nil
        }
        if let absoluteURL = URL(string: path), absoluteURL.scheme != nil {
            return absoluteURL
        }
        guard let baseURL else {
            return nil
        }
        if path.hasPrefix("/") {
            guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
                return nil
            }
            components.path = path
            return components.url
        }
        return URL(string: path, relativeTo: baseURL)?.absoluteURL
    }
}

private struct HomeRegionOption: Identifiable, Hashable {
    let code: String
    let name: String

    var id: String { code }

    static let all: [HomeRegionOption] = Locale.Region.isoRegions
        .map(\.identifier)
        .filter { code in
            code.count == 2 && code.allSatisfy(\.isLetter)
        }
        .map { code in
            HomeRegionOption(
                code: code,
                name: Locale.autoupdatingCurrent.localizedString(forRegionCode: code) ?? code
            )
        }
        .sorted { lhs, rhs in
            lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
}

private extension AddSubscriptionRequest.MediaType {
    init?(homeType: String) {
        switch homeType.uppercased() {
        case "MOV", "MOVIE":
            self = .movie
        case "TV", "SHOW":
            self = .tv
        default:
            return nil
        }
    }
}

#Preview {
    NavigationStack {
        HomeView(api: PreviewHomeAPI(), imageBaseURL: URL(string: "https://nas.example.com"))
    }
}

private struct PreviewHomeAPI: HomeViewAPI {
    func fetchHomeFeed(
        group: HomeFeedGroup,
        filter: HomeFeedFilter,
        region: String?,
        language: String?,
        page: Int
    ) async throws -> HomeFeedResponse {
        HomeFeedResponse(
            code: 0,
            success: true,
            message: nil,
            data: HomeFeedPayload(
                group: group,
                filter: filter,
                region: region,
                page: page,
                hasMore: false,
                items: [
                    HomePosterItem(
                        id: "movie-1",
                        title: "The Electric State",
                        type: "MOV",
                        mediaType: "Movie",
                        year: "2025",
                        voteText: "7.2",
                        posterPath: nil,
                        overview: "A drifter searches for a missing sibling across a strange machine-haunted landscape."
                    ),
                    HomePosterItem(
                        id: "tv-1",
                        title: "The Last of Us",
                        type: "TV",
                        mediaType: "TV",
                        year: "2025",
                        voteText: "8.6",
                        posterPath: nil,
                        overview: "Survivors cross a changed world."
                    )
                ]
            )
        )
    }

    func searchKeyword(
        _ keyword: String,
        quickMode: Bool,
        tmdbID: String?,
        mediaType: String?
    ) async throws -> NastoolCommandResponse {
        NastoolCommandResponse(code: 0, retcode: nil, success: true, message: nil, msg: nil, retmsg: nil)
    }

    func addSubscription(_ request: AddSubscriptionRequest) async throws -> NastoolCommandResponse {
        NastoolCommandResponse(code: 0, retcode: nil, success: true, message: nil, msg: nil, retmsg: nil)
    }
}
