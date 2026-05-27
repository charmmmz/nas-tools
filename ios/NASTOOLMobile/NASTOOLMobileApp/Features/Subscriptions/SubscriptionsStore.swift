import Foundation
import Observation

protocol SubscriptionsAPI: Sendable {
    func fetchMovieSubscriptions() async throws -> NastoolResultResponse<[String: SubscriptionItem]>
    func fetchTVSubscriptions() async throws -> NastoolResultResponse<[String: SubscriptionItem]>
    func addSubscription(_ request: AddSubscriptionRequest) async throws -> NastoolCommandResponse
    func removeSubscription(id: String, mediaType: AddSubscriptionRequest.MediaType) async throws -> NastoolCommandResponse
}

extension NastoolAPIClient: SubscriptionsAPI {}

@MainActor
@Observable
final class SubscriptionsStore {
    private let api: SubscriptionsAPI

    private(set) var movies: [SubscriptionItem] = []
    private(set) var tvShows: [SubscriptionItem] = []
    private(set) var isLoading = false
    var errorMessage: String?

    init(api: SubscriptionsAPI) {
        self.api = api
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let movieResponse = try await api.fetchMovieSubscriptions()
            let tvResponse = try await api.fetchTVSubscriptions()
            movies = sortedItems(movieResponse.result.values)
            tvShows = sortedItems(tvResponse.result.values)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func add(_ request: AddSubscriptionRequest) async {
        await performCommand {
            try await api.addSubscription(request)
        }
    }

    func remove(_ item: SubscriptionItem, mediaType: AddSubscriptionRequest.MediaType) async {
        await performCommand {
            try await api.removeSubscription(id: item.id, mediaType: mediaType)
        }
    }

    private func performCommand(_ command: () async throws -> NastoolCommandResponse) async {
        do {
            let response = try await command()
            guard response.isSuccess else {
                errorMessage = response.message ?? response.msg ?? response.retmsg ?? "Subscription command failed."
                return
            }
            errorMessage = nil
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func sortedItems(_ items: Dictionary<String, SubscriptionItem>.Values) -> [SubscriptionItem] {
        items.sorted { lhs, rhs in
            lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }
}
