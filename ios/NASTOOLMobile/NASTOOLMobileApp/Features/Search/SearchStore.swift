import Foundation
import Observation

protocol SearchAPI: Sendable {
    func searchKeyword(_ keyword: String, quickMode: Bool) async throws -> NastoolCommandResponse
    func fetchSearchResults() async throws -> SearchResultsResponse
    func downloadSearchResult(id: String, directory: String?, setting: String?) async throws -> NastoolCommandResponse
}

extension NastoolAPIClient: SearchAPI {}

@MainActor
@Observable
final class SearchStore {
    private let api: SearchAPI

    var query = ""
    private(set) var results: [SearchMediaResult] = []
    private(set) var isSearching = false
    private(set) var downloadingIDs: Set<String> = []
    var errorMessage: String?

    init(api: SearchAPI) {
        self.api = api
    }

    func submitSearch() async {
        await submitSearch(keyword: query)
    }

    func submitSearch(keyword: String) async {
        let trimmedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKeyword.isEmpty else {
            return
        }

        query = trimmedKeyword
        isSearching = true
        defer { isSearching = false }

        do {
            let command = try await api.searchKeyword(trimmedKeyword, quickMode: true)
            guard command.isSuccess else {
                errorMessage = command.message ?? command.msg ?? command.retmsg ?? "Search failed."
                return
            }

            let response = try await api.fetchSearchResults()
            results = response.result.values.sorted { lhs, rhs in
                lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func download(_ result: SearchMediaResult) async {
        downloadingIDs.insert(result.id)
        defer { downloadingIDs.remove(result.id) }

        do {
            let response = try await api.downloadSearchResult(id: result.id, directory: nil, setting: nil)
            guard response.isSuccess else {
                errorMessage = response.message ?? response.msg ?? response.retmsg ?? "Download failed."
                return
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
