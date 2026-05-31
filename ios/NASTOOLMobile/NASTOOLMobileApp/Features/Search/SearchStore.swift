import Foundation
import Observation

protocol SearchAPI: Sendable {
    func fetchMediaCandidates(keyword: String, source: String?) async throws -> NastoolResultResponse<[MediaCandidate]>
    func searchKeyword(_ keyword: String, quickMode: Bool, tmdbID: String?, mediaType: String?) async throws -> NastoolCommandResponse
    func fetchSearchResults() async throws -> SearchResultsResponse
    func downloadSearchResult(id: String, directory: String?, setting: String?) async throws -> NastoolCommandResponse
}

extension NastoolAPIClient: SearchAPI {}

@MainActor
@Observable
final class SearchStore {
    private let api: SearchAPI

    var query = ""
    private(set) var candidates: [MediaCandidate] = []
    private(set) var selectedCandidate: MediaCandidate?
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
            let response = try await api.fetchMediaCandidates(keyword: trimmedKeyword, source: "tmdb")
            candidates = response.result
            selectedCandidate = nil
            results = []
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func searchResources(for candidate: MediaCandidate) async {
        isSearching = true
        defer { isSearching = false }

        do {
            let command = try await api.searchKeyword(
                candidate.title,
                quickMode: false,
                tmdbID: candidate.tmdbID,
                mediaType: candidate.mediaType
            )
            guard command.isSuccess else {
                errorMessage = command.message ?? command.msg ?? command.retmsg ?? "Search failed."
                return
            }

            let response = try await api.fetchSearchResults()
            results = response.result.values.sorted { lhs, rhs in
                lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
            candidates = []
            selectedCandidate = candidate
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func download(_ result: SearchMediaResult) async {
        await download(id: result.id)
    }

    func download(_ torrent: SearchTorrent) async {
        await download(id: torrent.id)
    }

    private func download(id: String) async {
        downloadingIDs.insert(id)
        defer { downloadingIDs.remove(id) }

        do {
            let response = try await api.downloadSearchResult(id: id, directory: nil, setting: nil)
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
