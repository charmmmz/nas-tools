import SwiftUI

struct SearchView: View {
    @State private var store: SearchStore

    init(api: SearchAPI) {
        _store = State(initialValue: SearchStore(api: api))
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
                ProgressView()
            } else if store.results.isEmpty {
                ContentUnavailableView("No Results", systemImage: "magnifyingglass")
            } else {
                ForEach(store.results) { result in
                    SearchResultRow(
                        result: result,
                        isDownloading: store.downloadingIDs.contains(result.id),
                        onDownload: {
                            Task {
                                await store.download(result)
                            }
                        }
                    )
                }
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
}

private struct SearchResultRow: View {
    let result: SearchMediaResult
    let isDownloading: Bool
    let onDownload: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(result.title)
                    .font(.headline)
                    .lineLimit(2)

                Text([result.year, result.mediaType].compactMap { $0 }.joined(separator: " / "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let overview = result.overview, !overview.isEmpty {
                    Text(overview)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
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
            .accessibilityLabel("Download Result")
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    NavigationStack {
        SearchView(api: PreviewSearchAPI())
    }
}

private struct PreviewSearchAPI: SearchAPI {
    func searchKeyword(_ keyword: String, quickMode: Bool) async throws -> NastoolCommandResponse {
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
              "type": "Movie",
              "poster": "/poster.jpg",
              "overview": "A search result from NASTOOL.",
              "exist": false
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
