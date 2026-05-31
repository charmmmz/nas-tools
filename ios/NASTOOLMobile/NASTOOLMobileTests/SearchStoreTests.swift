import XCTest
@testable import NASTOOLMobile

@MainActor
final class SearchStoreTests: XCTestCase {
    func testSearchResultsResponseDecodesApiActionWrappedResult() throws {
        let data = Data("""
        {
          "code": 0,
          "success": true,
          "message": "",
          "data": {
            "total": 1,
            "result": {
              "Arrival": {
                "key": "101",
                "title": "Arrival",
                "year": "2016",
                "type": "Movie",
                "poster": "/poster.jpg",
                "overview": "A movie.",
                "exist": false
              }
            }
          }
        }
        """.utf8)

        let response = try JSONDecoder().decode(SearchResultsResponse.self, from: data)

        XCTAssertEqual(response.total, 1)
        XCTAssertEqual(response.result["Arrival"]?.id, "101")
    }

    func testSubmitSearchLoadsMediaCandidatesBeforeResourceSearch() async throws {
        let api = SearchAPISpy()
        api.candidates = [
            MediaCandidate(
                id: "101",
                title: "Arrival",
                year: "2016",
                mediaType: "电影",
                vote: "7.6",
                posterPath: "https://image.tmdb.org/t/p/w500/poster.jpg",
                tmdbID: "101",
                overview: "A movie.",
                link: "https://www.themoviedb.org/movie/101"
            )
        ]
        let store = SearchStore(api: api)

        await store.submitSearch(keyword: "Arrival")

        XCTAssertEqual(api.mediaCandidateKeywords, ["Arrival"])
        XCTAssertEqual(api.searchedRequests.count, 0)
        XCTAssertEqual(store.candidates.map(\.title), ["Arrival"])
        XCTAssertEqual(store.results, [])
        XCTAssertFalse(store.isSearching)
        XCTAssertNil(store.errorMessage)
    }

    func testSelectingMediaCandidateSearchesResourcesWithTMDBIdentity() async throws {
        let api = SearchAPISpy()
        let result = try makeSearchResult(id: "101", title: "Arrival")
        api.results = SearchResultsResponse(code: 0, total: 1, result: ["Arrival": result])
        let store = SearchStore(api: api)
        let candidate = MediaCandidate(
            id: "101",
            title: "Arrival",
            year: "2016",
            mediaType: "电影",
            vote: "7.6",
            posterPath: "/poster.jpg",
            tmdbID: "101",
            overview: "A movie.",
            link: "https://www.themoviedb.org/movie/101"
        )

        await store.searchResources(for: candidate)

        XCTAssertEqual(api.searchedRequests, [
            SearchAPISpy.SearchRequest(keyword: "Arrival", quickMode: false, tmdbID: "101", mediaType: "电影")
        ])
        XCTAssertEqual(store.results.map(\.title), ["Arrival"])
        XCTAssertEqual(store.candidates, [])
        XCTAssertEqual(store.selectedCandidate?.id, "101")
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
    struct SearchRequest: Equatable {
        let keyword: String
        let quickMode: Bool
        let tmdbID: String?
        let mediaType: String?
    }

    var mediaCandidateKeywords: [String] = []
    var searchedRequests: [SearchRequest] = []
    var downloadedIDs: [String] = []
    var candidates: [MediaCandidate] = []
    var results = SearchResultsResponse(code: 0, total: 0, result: [:])
    var error: Error?

    func fetchMediaCandidates(keyword: String, source: String?) async throws -> NastoolResultResponse<[MediaCandidate]> {
        if let error {
            throw error
        }
        mediaCandidateKeywords.append(keyword)
        return NastoolResultResponse(code: 0, success: true, message: nil, msg: nil, total: candidates.count, result: candidates)
    }

    func searchKeyword(_ keyword: String, quickMode: Bool, tmdbID: String?, mediaType: String?) async throws -> NastoolCommandResponse {
        if let error {
            throw error
        }
        searchedRequests.append(SearchRequest(keyword: keyword, quickMode: quickMode, tmdbID: tmdbID, mediaType: mediaType))
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
