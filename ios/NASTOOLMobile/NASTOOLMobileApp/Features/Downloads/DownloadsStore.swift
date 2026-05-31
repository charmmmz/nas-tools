import Foundation
import Observation

protocol DownloadsAPI: Sendable {
    func fetchDownloading() async throws -> NastoolResultResponse<[DownloadTask]>
    func startDownload(id: String) async throws -> NastoolCommandResponse
    func stopDownload(id: String) async throws -> NastoolCommandResponse
    func removeDownload(id: String) async throws -> NastoolCommandResponse
}

protocol DownloadEventsAPI: Sendable {
    func downloadSnapshots() -> AsyncThrowingStream<[DownloadTask], Error>
}

extension NastoolAPIClient: DownloadsAPI {}
extension NastoolAPIClient: DownloadEventsAPI {}

@MainActor
@Observable
final class DownloadsStore {
    private let api: DownloadsAPI
    private let events: DownloadEventsAPI?
    private var eventsTask: Task<Void, Never>?

    private(set) var tasks: [DownloadTask] = []
    private(set) var isLoading = false
    var errorMessage: String?

    init(api: DownloadsAPI, events: DownloadEventsAPI? = nil) {
        self.api = api
        self.events = events ?? api as? DownloadEventsAPI
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await api.fetchDownloading()
            apply(response.result)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func connectEvents() {
        guard eventsTask == nil, let events else {
            return
        }

        eventsTask = Task { @MainActor [weak self] in
            do {
                for try await snapshot in events.downloadSnapshots() {
                    self?.apply(snapshot)
                }
            } catch {
                self?.errorMessage = error.localizedDescription
            }
        }
    }

    func disconnectEvents() {
        eventsTask?.cancel()
        eventsTask = nil
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

    private func apply(_ snapshot: [DownloadTask]) {
        tasks = sorted(snapshot)
        errorMessage = nil
    }

    private func sorted(_ snapshot: [DownloadTask]) -> [DownloadTask] {
        snapshot.sorted { lhs, rhs in
            lhs.displayTitle.localizedStandardCompare(rhs.displayTitle) == .orderedAscending
        }
    }
}
