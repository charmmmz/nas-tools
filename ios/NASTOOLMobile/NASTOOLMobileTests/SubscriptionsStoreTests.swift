import XCTest
@testable import NASTOOLMobile

@MainActor
final class SubscriptionsStoreTests: XCTestCase {
    func testLoadSeparatesMovieAndTVSubscriptions() async throws {
        let api = SubscriptionsAPISpy()
        api.movies = ["1": try makeSubscription(id: "1", name: "Movie One")]
        api.tvShows = ["2": try makeSubscription(id: "2", name: "Show One", season: "1")]
        let store = SubscriptionsStore(api: api)

        await store.load()

        XCTAssertEqual(store.movies.map(\.name), ["Movie One"])
        XCTAssertEqual(store.tvShows.map(\.name), ["Show One"])
    }

    func testAddAndRemoveCallAPI() async throws {
        let api = SubscriptionsAPISpy()
        let store = SubscriptionsStore(api: api)
        let request = AddSubscriptionRequest(name: "Dune", mediaType: .movie, year: "2024", keyword: nil, season: nil, mediaID: nil)
        let item = try makeSubscription(id: "10", name: "Dune")

        await store.add(request)
        await store.remove(item, mediaType: .movie)

        XCTAssertEqual(api.addedRequests, [request])
        XCTAssertEqual(api.removed, ["10:MOV"])
    }
}

private final class SubscriptionsAPISpy: SubscriptionsAPI, @unchecked Sendable {
    var movies: [String: SubscriptionItem] = [:]
    var tvShows: [String: SubscriptionItem] = [:]
    var addedRequests: [AddSubscriptionRequest] = []
    var removed: [String] = []

    func fetchMovieSubscriptions() async throws -> NastoolResultResponse<[String: SubscriptionItem]> {
        NastoolResultResponse(code: 0, success: true, message: nil, msg: nil, total: movies.count, result: movies)
    }

    func fetchTVSubscriptions() async throws -> NastoolResultResponse<[String: SubscriptionItem]> {
        NastoolResultResponse(code: 0, success: true, message: nil, msg: nil, total: tvShows.count, result: tvShows)
    }

    func addSubscription(_ request: AddSubscriptionRequest) async throws -> NastoolCommandResponse {
        addedRequests.append(request)
        return NastoolCommandResponse(code: 0, retcode: nil, success: true, message: nil, msg: nil, retmsg: nil)
    }

    func removeSubscription(id: String, mediaType: AddSubscriptionRequest.MediaType) async throws -> NastoolCommandResponse {
        removed.append("\(id):\(mediaType.rawValue)")
        return NastoolCommandResponse(code: 0, retcode: nil, success: true, message: nil, msg: nil, retmsg: nil)
    }
}

private func makeSubscription(id: String, name: String, season: String? = nil) throws -> SubscriptionItem {
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
      "current_ep": 2,
      "lack": 8
    }
    """.utf8)
    return try JSONDecoder().decode(SubscriptionItem.self, from: data)
}
