import XCTest

@MainActor
final class LoginSmokeUITests: XCTestCase {
    func testFreshLaunchShowsLoginControls() {
        let app = XCUIApplication()
        app.launchEnvironment["NASTOOL_UI_TESTING"] = "1"
        app.launch()

        XCTAssertTrue(app.textFields["Server URL"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.textFields["Username"].exists)
        XCTAssertTrue(app.secureTextFields["Password"].exists)
        XCTAssertTrue(app.buttons["Sign In"].exists)
    }
}
