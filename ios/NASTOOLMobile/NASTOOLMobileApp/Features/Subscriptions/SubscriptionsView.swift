import SwiftUI

struct SubscriptionsView: View {
    @State private var store: SubscriptionsStore
    @State private var isShowingAddSheet = false

    init(api: SubscriptionsAPI) {
        _store = State(initialValue: SubscriptionsStore(api: api))
    }

    var body: some View {
        List {
            if let errorMessage = store.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            if store.isLoading && store.movies.isEmpty && store.tvShows.isEmpty {
                ProgressView()
            } else if store.movies.isEmpty && store.tvShows.isEmpty {
                ContentUnavailableView("No Subscriptions", systemImage: "bookmark")
            } else {
                if !store.movies.isEmpty {
                    Section("Movies") {
                        ForEach(store.movies) { item in
                            SubscriptionRow(item: item)
                                .swipeActions {
                                    Button("Delete", role: .destructive) {
                                        Task {
                                            await store.remove(item, mediaType: .movie)
                                        }
                                    }
                                }
                        }
                    }
                }

                if !store.tvShows.isEmpty {
                    Section("TV Shows") {
                        ForEach(store.tvShows) { item in
                            SubscriptionRow(item: item)
                                .swipeActions {
                                    Button("Delete", role: .destructive) {
                                        Task {
                                            await store.remove(item, mediaType: .tv)
                                        }
                                    }
                                }
                        }
                    }
                }
            }
        }
        .navigationTitle("Subscriptions")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add Subscription")
            }
        }
        .refreshable {
            await store.load()
        }
        .task {
            await store.load()
        }
        .sheet(isPresented: $isShowingAddSheet) {
            AddSubscriptionSheet { request in
                Task {
                    await store.add(request)
                }
            }
        }
    }
}

private struct SubscriptionRow: View {
    let item: SubscriptionItem

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(item.name)
                .font(.headline)
                .lineLimit(2)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let total = item.totalEpisodes, let current = item.currentEpisode {
                ProgressView(value: Double(current), total: Double(max(total, 1)))
            }
        }
        .padding(.vertical, 5)
    }

    private var subtitle: String {
        var parts: [String] = []
        if let year = item.year {
            parts.append(year)
        }
        if let season = item.season {
            parts.append("S\(season)")
        }
        if let missingEpisodes = item.missingEpisodes {
            parts.append("Missing \(missingEpisodes)")
        } else if let state = item.state {
            parts.append(state)
        }
        return parts.joined(separator: " / ")
    }
}

private struct AddSubscriptionSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var mediaType: AddSubscriptionRequest.MediaType = .movie
    @State private var name = ""
    @State private var year = ""
    @State private var keyword = ""
    @State private var season = 1

    let onSave: (AddSubscriptionRequest) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $mediaType) {
                        Text("Movie").tag(AddSubscriptionRequest.MediaType.movie)
                        Text("TV").tag(AddSubscriptionRequest.MediaType.tv)
                    }
                    .pickerStyle(.segmented)

                    TextField("Name", text: $name)
                    TextField("Year", text: $year)
                        .keyboardType(.numberPad)
                    TextField("Keyword", text: $keyword)

                    if mediaType == .tv {
                        Stepper("Season \(season)", value: $season, in: 1...99)
                    }
                }
            }
            .navigationTitle("Add Subscription")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(
                            AddSubscriptionRequest(
                                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                mediaType: mediaType,
                                year: emptyToNil(year),
                                keyword: emptyToNil(keyword),
                                season: mediaType == .tv ? season : nil,
                                mediaID: nil
                            )
                        )
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func emptyToNil(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

#Preview {
    NavigationStack {
        SubscriptionsView(api: PreviewSubscriptionsAPI())
    }
}

private struct PreviewSubscriptionsAPI: SubscriptionsAPI {
    func fetchMovieSubscriptions() async throws -> NastoolResultResponse<[String: SubscriptionItem]> {
        let item = try previewItem(id: "movie", name: "Example Movie")
        return NastoolResultResponse(code: 0, success: true, message: nil, msg: nil, total: 1, result: [item.id: item])
    }

    func fetchTVSubscriptions() async throws -> NastoolResultResponse<[String: SubscriptionItem]> {
        let item = try previewItem(id: "tv", name: "Example Show", season: "1")
        return NastoolResultResponse(code: 0, success: true, message: nil, msg: nil, total: 1, result: [item.id: item])
    }

    func addSubscription(_ request: AddSubscriptionRequest) async throws -> NastoolCommandResponse {
        NastoolCommandResponse(code: 0, retcode: nil, success: true, message: nil, msg: nil, retmsg: nil)
    }

    func removeSubscription(id: String, mediaType: AddSubscriptionRequest.MediaType) async throws -> NastoolCommandResponse {
        NastoolCommandResponse(code: 0, retcode: nil, success: true, message: nil, msg: nil, retmsg: nil)
    }

    private func previewItem(id: String, name: String, season: String? = nil) throws -> SubscriptionItem {
        let seasonJSON = season.map { "\"season\": \"\($0)\"," } ?? ""
        let data = Data("""
        {
          "id": "\(id)",
          "name": "\(name)",
          "year": "2024",
          \(seasonJSON)
          "state": "R",
          "poster": "/poster.jpg",
          "overview": "Subscribed.",
          "total_ep": 10,
          "current_ep": 3,
          "lack": 7
        }
        """.utf8)
        return try JSONDecoder().decode(SubscriptionItem.self, from: data)
    }
}
