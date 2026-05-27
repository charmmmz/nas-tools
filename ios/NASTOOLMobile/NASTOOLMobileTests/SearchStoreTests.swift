import XCTest
@testable import NASTOOLMobile

@MainActor
final class SearchStoreTests: XCTestCase {
    func testSubmitSearchTriggersSearchAndLoadsResults() async throws {
        let api = SearchAPISpy()
        let result = try makeSearchResult(id: "101", title: "Arrival")
        api.results = SearchResultsResponse(code: 0, total: 1, result: ["Arrival": result])
        let store = SearchStore(api: api)

        await store.submitSearch(keyword: "Arrival")

        XCTAssertEqual(api.searchedKeywords, ["Arrival"])
        XCTAssertEqual(store.results.map(\.title), ["Arrival"])
        XCTAssertFalse(store.isSearching)
        XCTAssertNil(store.errorMessage)
    }

    func testDownloadSelectedResultCallsAPI() async throws {
        let api = SearchAPISpy()
        let result = try makeSearchResult(id: "202", title: "Dune")
        let store = SearchStore(api: api)

        await store.download(result)

        XCTAssertEqual(api.downloadedIDs, ["202"])
    }
}

private final class SearchAPISpy: SearchAPI, @unchecked Sendable {
    var searchedKeywords: [String] = []
    var downloadedIDs: [String] = []
    var results = SearchResultsResponse(code: 0, total: 0, result: [:])
    var error: Error?

    func searchKeyword(_ keyword: String, quickMode: Bool) async throws -> NastoolCommandResponse {
        if let error {
            throw error
        }
        searchedKeywords.append(keyword)
        return NastoolCommandResponse(code: 0, retcode: nil, success: true, message: nil, msg: nil, retmsg: nil)
    }

    func fetchSearchResults() async throws -> SearchResultsResponse {
        if let error {
            throw error
        }
        return results
    }

    func downloadSearchResult(id: String, directory: String?, setting: String?) async throws -> NastoolCommandResponse {
        downloadedIDs.append(id)
        return NastoolCommandResponse(code: 0, retcode: nil, success: true, message: nil, msg: nil, retmsg: nil)
    }
}

private func makeSearchResult(id: String, title: String) throws -> SearchMediaResult {
    let data = Data("""
    {
      "key": "\(id)",
      "title": "\(title)",
      "year": "2024",
      "type": "Movie",
      "poster": "/poster.jpg",
      "overview": "A movie.",
      "exist": false
    }
    """.utf8)
    return try JSONDecoder().decode(SearchMediaResult.self, from: data)
}
