import XCTest
@testable import NASTOOLMobile

@MainActor
final class DownloadsStoreTests: XCTestCase {
    func testLoadDownloadsUpdatesState() async {
        let api = DownloadsAPISpy()
        api.tasks = [
            DownloadTask(id: "abc", name: "Raw Name", title: "Movie", speedText: "↓1MB/s", state: "Downloading", progress: 12)
        ]
        let store = DownloadsStore(api: api)

        await store.load()

        XCTAssertEqual(store.tasks.map(\.id), ["abc"])
        XCTAssertEqual(store.tasks.first?.displayTitle, "Movie")
        XCTAssertFalse(store.isLoading)
        XCTAssertNil(store.errorMessage)
    }

    func testControlActionsCallAPI() async {
        let api = DownloadsAPISpy()
        let store = DownloadsStore(api: api)

        await store.start("start-id")
        await store.pause("pause-id")
        await store.remove("remove-id")

        XCTAssertEqual(api.startedIDs, ["start-id"])
        XCTAssertEqual(api.stoppedIDs, ["pause-id"])
        XCTAssertEqual(api.removedIDs, ["remove-id"])
    }

    func testLoadFailureSurfacesErrorMessage() async {
        let api = DownloadsAPISpy()
        api.error = NastoolAPIError.serverMessage("Downloader offline")
        let store = DownloadsStore(api: api)

        await store.load()

        XCTAssertEqual(store.errorMessage, "Downloader offline")
        XCTAssertFalse(store.isLoading)
    }
}

private final class DownloadsAPISpy: DownloadsAPI, @unchecked Sendable {
    var tasks: [DownloadTask] = []
    var error: Error?
    var startedIDs: [String] = []
    var stoppedIDs: [String] = []
    var removedIDs: [String] = []

    func fetchDownloading() async throws -> NastoolResultResponse<[DownloadTask]> {
        if let error {
            throw error
        }
        return NastoolResultResponse(code: 0, success: true, message: nil, msg: nil, total: tasks.count, result: tasks)
    }

    func startDownload(id: String) async throws -> NastoolCommandResponse {
        startedIDs.append(id)
        return NastoolCommandResponse(code: 0, retcode: nil, success: true, message: nil, msg: nil, retmsg: nil)
    }

    func stopDownload(id: String) async throws -> NastoolCommandResponse {
        stoppedIDs.append(id)
        return NastoolCommandResponse(code: 0, retcode: nil, success: true, message: nil, msg: nil, retmsg: nil)
    }

    func removeDownload(id: String) async throws -> NastoolCommandResponse {
        removedIDs.append(id)
        return NastoolCommandResponse(code: 0, retcode: nil, success: true, message: nil, msg: nil, retmsg: nil)
    }
}
