import Foundation
import Observation

protocol DownloadsAPI: Sendable {
    func fetchDownloading() async throws -> NastoolResultResponse<[DownloadTask]>
    func startDownload(id: String) async throws -> NastoolCommandResponse
    func stopDownload(id: String) async throws -> NastoolCommandResponse
    func removeDownload(id: String) async throws -> NastoolCommandResponse
}

extension NastoolAPIClient: DownloadsAPI {}

@MainActor
@Observable
final class DownloadsStore {
    private let api: DownloadsAPI

    private(set) var tasks: [DownloadTask] = []
    private(set) var isLoading = false
    var errorMessage: String?

    init(api: DownloadsAPI) {
        self.api = api
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await api.fetchDownloading()
            tasks = response.result.sorted { lhs, rhs in
                lhs.displayTitle.localizedStandardCompare(rhs.displayTitle) == .orderedAscending
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func start(_ id: String) async {
        await performCommand {
            try await api.startDownload(id: id)
        }
    }

    func pause(_ id: String) async {
        await performCommand {
            try await api.stopDownload(id: id)
        }
    }

    func remove(_ id: String) async {
        await performCommand {
            try await api.removeDownload(id: id)
        }
    }

    private func performCommand(_ command: () async throws -> NastoolCommandResponse) async {
        do {
            let response = try await command()
            guard response.isSuccess else {
                errorMessage = response.message ?? response.msg ?? response.retmsg ?? "Command failed."
                return
            }
            errorMessage = nil
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
