import XCTest
@testable import NASTOOLMobile

@MainActor
final class HomeStoreTests: XCTestCase {
    func testInitialLoadUsesTrendingTodayWithoutRegion() async {
        let api = HomeAPISpy()
        api.pages = [[makeItem(id: "1", title: "Trending Movie")]]
        let store = HomeStore(
            api: api,
            localeRegionProvider: { "CN" },
            localeLanguageProvider: { "zh-CN" },
            regionStorage: InMemoryHomeRegionStorage()
        )

        await store.loadInitial()

        XCTAssertEqual(api.requests, [
            HomeAPISpy.Request(group: .trending, filter: .today, region: nil, language: "zh-CN", page: 1)
        ])
        XCTAssertEqual(store.items.map(\.id), ["1"])
        XCTAssertNil(store.errorMessage)
    }

    func testPopularStreamingUsesAutomaticSystemRegion() async {
        let api = HomeAPISpy()
        let store = HomeStore(
            api: api,
            localeRegionProvider: { "CN" },
            localeLanguageProvider: { "zh-CN" },
            regionStorage: InMemoryHomeRegionStorage()
        )

        store.select(group: .popular)
        store.select(filter: .streaming)
        await store.loadInitial()

        XCTAssertEqual(api.requests.last, HomeAPISpy.Request(group: .popular, filter: .streaming, region: "CN", language: "zh-CN", page: 1))
    }

    func testHomeFeedLanguageUsesSystemLanguageNotSelectedRegion() async {
        let api = HomeAPISpy()
        let store = HomeStore(
            api: api,
            localeRegionProvider: { "US" },
            localeLanguageProvider: { "zh-CN" },
            regionStorage: InMemoryHomeRegionStorage()
        )

        store.regionSelection = .region("JP")
        store.select(group: .popular)
        store.select(filter: .theaters)
        await store.loadInitial()

        XCTAssertEqual(api.requests.last, HomeAPISpy.Request(group: .popular, filter: .theaters, region: "JP", language: "zh-CN", page: 1))
    }

    func testExplicitRegionPersistsAndOverridesAutomaticRegion() async {
        let api = HomeAPISpy()
        let storage = InMemoryHomeRegionStorage()
        let store = HomeStore(
            api: api,
            localeRegionProvider: { "CN" },
            localeLanguageProvider: { "zh-CN" },
            regionStorage: storage
        )

        store.regionSelection = .region("US")
        store.select(group: .popular)
        await store.loadInitial()

        XCTAssertEqual(storage.storedRegionCode, "US")
        XCTAssertEqual(api.requests.last?.region, "US")
    }

    func testLoadMoreAppendsNextPage() async {
        let api = HomeAPISpy()
        api.pages = [
            [makeItem(id: "1", title: "First")],
            [makeItem(id: "2", title: "Second")]
        ]
        let store = HomeStore(
            api: api,
            localeRegionProvider: { "CN" },
            localeLanguageProvider: { "zh-CN" },
            regionStorage: InMemoryHomeRegionStorage()
        )

        await store.loadInitial()
        await store.loadMore()

        XCTAssertEqual(api.requests.map(\.page), [1, 2])
        XCTAssertEqual(store.items.map(\.id), ["1", "2"])
    }
}

private final class HomeAPISpy: HomeAPI, @unchecked Sendable {
    struct Request: Equatable {
        let group: HomeFeedGroup
        let filter: HomeFeedFilter
        let region: String?
        let language: String?
        let page: Int
    }

    var requests: [Request] = []
    var pages: [[HomePosterItem]] = [[]]
    var error: Error?

    func fetchHomeFeed(
        group: HomeFeedGroup,
        filter: HomeFeedFilter,
        region: String?,
        language: String?,
        page: Int
    ) async throws -> HomeFeedResponse {
        if let error {
            throw error
        }
        requests.append(Request(group: group, filter: filter, region: region, language: language, page: page))
        let index = max(0, min(page - 1, pages.count - 1))
        return HomeFeedResponse(
            code: 0,
            success: true,
            message: nil,
            data: HomeFeedPayload(
                group: group,
                filter: filter,
                region: region,
                page: page,
                hasMore: page < pages.count,
                items: pages[index]
            )
        )
    }
}

private final class InMemoryHomeRegionStorage: HomeRegionStorage {
    var storedRegionCode: String?

    func loadRegionCode() -> String? {
        storedRegionCode
    }

    func saveRegionCode(_ regionCode: String?) {
        storedRegionCode = regionCode
    }
}

private func makeItem(id: String, title: String) -> HomePosterItem {
    HomePosterItem(
        id: id,
        title: title,
        type: "MOV",
        mediaType: "电影",
        year: "2026",
        voteText: "8.1",
        posterPath: "/poster.jpg",
        overview: "Overview"
    )
}
