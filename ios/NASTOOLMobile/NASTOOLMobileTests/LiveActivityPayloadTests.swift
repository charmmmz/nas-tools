import XCTest
@testable import NASTOOLMobile

final class LiveActivityPayloadTests: XCTestCase {
    func testDownloadTaskMapsToClampedActivityContentState() {
        let lowProgressTask = DownloadTask(id: "low", title: "Low", progress: -10)
        let highProgressTask = DownloadTask(id: "high", title: "High", speedText: "done", state: "Downloading", progress: 145)

        let lowState = DownloadActivityAttributes.ContentState(task: lowProgressTask)
        let highState = DownloadActivityAttributes.ContentState(task: highProgressTask)

        XCTAssertEqual(lowState.progress, 0)
        XCTAssertEqual(highState.progress, 100)
        XCTAssertEqual(highState.title, "High")
        XCTAssertEqual(highState.speedText, "done")
    }
}
