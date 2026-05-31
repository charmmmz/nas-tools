import SwiftUI

struct SearchView: View {
    @State private var store: SearchStore
    private let imageBaseURL: URL?

    init(api: SearchAPI, imageBaseURL: URL? = nil) {
        _store = State(initialValue: SearchStore(api: api))
        self.imageBaseURL = imageBaseURL
    }

    var body: some View {
        @Bindable var store = store

        List {
            if let errorMessage = store.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            if store.isSearching {
                Section {
                    ProgressView("Searching")
                }
            }

            if !store.candidates.isEmpty {
                Section("Media Matches") {
                    ForEach(store.candidates) { candidate in
                        Button {
                            Task {
                                await store.searchResources(for: candidate)
                            }
                        } label: {
                            MediaCandidateRow(candidate: candidate, imageBaseURL: imageBaseURL)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if !store.results.isEmpty {
                Section(resourceSectionTitle) {
                    ForEach(store.results) { result in
                        SearchResourceResultRow(
                            result: result,
                            imageBaseURL: imageBaseURL,
                            downloadingIDs: store.downloadingIDs,
                            onDownloadResult: {
                                Task {
                                    await store.download(result)
                                }
                            },
                            onDownloadTorrent: { torrent in
                                Task {
                                    await store.download(torrent)
                                }
                            }
                        )
                    }
                }
            }

            if !store.isSearching && store.candidates.isEmpty && store.results.isEmpty {
                ContentUnavailableView(emptyTitle, systemImage: emptySystemImage)
            }
        }
        .navigationTitle("Search")
        .searchable(text: $store.query, prompt: "Movie or TV title")
        .onSubmit(of: .search) {
            Task {
                await store.submitSearch()
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await store.submitSearch()
                    }
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .accessibilityLabel("Search")
            }
        }
    }

    private var resourceSectionTitle: String {
        if let title = store.selectedCandidate?.title {
            return "Resources for \(title)"
        }
        return "Resources"
    }

    private var emptyTitle: String {
        if store.selectedCandidate != nil {
            return "No Resources"
        }
        if !store.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "No Media Matches"
        }
        return "Search Movies or TV"
    }

    private var emptySystemImage: String {
        store.selectedCandidate == nil ? "magnifyingglass" : "tray"
    }
}

private struct MediaCandidateRow: View {
    let candidate: MediaCandidate
    let imageBaseURL: URL?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            PosterThumbnail(path: candidate.posterPath, baseURL: imageBaseURL, width: 64, height: 96)

            VStack(alignment: .leading, spacing: 6) {
                Text(candidate.title)
                    .font(.headline)
                    .lineLimit(2)

                Text(candidateSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let overview = candidate.overview, !overview.isEmpty {
                    Text(overview)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .padding(.top, 4)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    private var candidateSubtitle: String {
        var parts: [String] = []
        if let year = candidate.year, !year.isEmpty {
            parts.append(year)
        }
        if let mediaType = candidate.mediaType, !mediaType.isEmpty {
            parts.append(mediaType)
        }
        if let vote = candidate.vote, !vote.isEmpty, vote != "0" {
            parts.append("Rating \(vote)")
        }
        return parts.joined(separator: " / ")
    }
}

private struct SearchResourceResultRow: View {
    let result: SearchMediaResult
    let imageBaseURL: URL?
    let downloadingIDs: Set<String>
    let onDownloadResult: () -> Void
    let onDownloadTorrent: (SearchTorrent) -> Void

    var body: some View {
        DisclosureGroup {
            if result.torrents.isEmpty {
                Button(action: onDownloadResult) {
                    Label("Download", systemImage: "arrow.down.circle")
                }
                .disabled(downloadingIDs.contains(result.id))
            } else {
                ForEach(result.torrents) { torrent in
                    SearchTorrentRow(
                        torrent: torrent,
                        isDownloading: downloadingIDs.contains(torrent.id),
                        onDownload: {
                            onDownloadTorrent(torrent)
                        }
                    )
                }
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                PosterThumbnail(path: result.posterPath, baseURL: imageBaseURL, width: 68, height: 102)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(result.title)
                            .font(.headline)
                            .lineLimit(2)

                        if result.existsInLibrary {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .accessibilityLabel("Exists in Library")
                        }
                    }

                    Text(resultSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if let overview = result.overview, !overview.isEmpty {
                        Text(overview)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var resultSubtitle: String {
        var parts: [String] = []
        if let year = result.year, !year.isEmpty {
            parts.append(year)
        }
        if let mediaType = result.mediaType, !mediaType.isEmpty {
            parts.append(mediaType)
        }
        if !result.torrents.isEmpty {
            parts.append("\(result.torrents.count) torrents")
        }
        return parts.joined(separator: " / ")
    }
}

private struct SearchTorrentRow: View {
    let torrent: SearchTorrent
    let isDownloading: Bool
    let onDownload: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                Text(torrent.torrentName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(3)

                if let description = torrent.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Text(torrentSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Button(action: onDownload) {
                if isDownloading {
                    ProgressView()
                } else {
                    Image(systemName: "arrow.down.circle")
                }
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Download Torrent")
        }
        .padding(.vertical, 6)
    }

    private var torrentSubtitle: String {
        var parts: [String] = []
        if let site = torrent.site, !site.isEmpty {
            parts.append(site)
        }
        if let size = torrent.size, !size.isEmpty {
            parts.append(size)
        }
        if !torrent.qualityText.isEmpty {
            parts.append(torrent.qualityText)
        }
        if let freeText = torrent.freeText {
            parts.append(freeText)
        }
        if let seeders = torrent.seeders {
            parts.append("\(seeders) seeders")
        }
        return parts.joined(separator: " / ")
    }
}

private struct PosterThumbnail: View {
    let path: String?
    let baseURL: URL?
    let width: CGFloat
    let height: CGFloat

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
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: width, height: height)
        .background(Color.secondary.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var placeholder: some View {
        Image(systemName: "film")
            .font(.title2)
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

#Preview {
    NavigationStack {
        SearchView(api: PreviewSearchAPI(), imageBaseURL: URL(string: "https://nas.example.com"))
    }
}

private struct PreviewSearchAPI: SearchAPI {
    func fetchMediaCandidates(keyword: String, source: String?) async throws -> NastoolResultResponse<[MediaCandidate]> {
        NastoolResultResponse(
            code: 0,
            success: true,
            message: nil,
            msg: nil,
            total: 1,
            result: [
                MediaCandidate(
                    id: "preview",
                    title: "Example Movie",
                    year: "2024",
                    mediaType: "电影",
                    vote: "7.6",
                    posterPath: "/poster.jpg",
                    tmdbID: "preview",
                    overview: "A TMDB match from NASTOOL.",
                    link: "https://www.themoviedb.org/movie/preview"
                )
            ]
        )
    }

    func searchKeyword(_ keyword: String, quickMode: Bool, tmdbID: String?, mediaType: String?) async throws -> NastoolCommandResponse {
        NastoolCommandResponse(code: 0, retcode: nil, success: true, message: nil, msg: nil, retmsg: nil)
    }

    func fetchSearchResults() async throws -> SearchResultsResponse {
        let data = Data("""
        {
          "code": 0,
          "total": 1,
          "result": {
            "Example Movie": {
              "key": "preview",
              "title": "Example Movie",
              "year": "2024",
              "type": "电影",
              "poster": "/poster.jpg",
              "overview": "A search result from NASTOOL.",
              "exist": false,
              "torrent_dict": [
                [
                  "MOV",
                  {
                    "webdl_1080p": {
                      "group_total": 1,
                      "group_torrents": {
                        "unique": {
                          "torrent_list": [
                            {
                              "id": "torrent-preview",
                              "site": "PTSite",
                              "torrent_name": "Example.Movie.2024.1080p.WEB-DL",
                              "description": "WEB-DL / 1080p",
                              "size": "8 GB",
                              "respix": "1080p",
                              "restype": "WEB-DL",
                              "seeders": 24,
                              "uploadvalue": 1.0,
                              "downloadvalue": 0.0
                            }
                          ]
                        }
                      }
                    }
                  }
                ]
              ]
            }
          }
        }
        """.utf8)
        return try JSONDecoder().decode(SearchResultsResponse.self, from: data)
    }

    func downloadSearchResult(id: String, directory: String?, setting: String?) async throws -> NastoolCommandResponse {
        NastoolCommandResponse(code: 0, retcode: nil, success: true, message: nil, msg: nil, retmsg: nil)
    }
}
