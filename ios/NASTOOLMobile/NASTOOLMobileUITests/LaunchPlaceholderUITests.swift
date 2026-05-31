import XCTest

@MainActor
final class LaunchPlaceholderUITests: XCTestCase {
    func testLaunches() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.exists)
    }
}
