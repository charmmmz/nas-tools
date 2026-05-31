import XCTest
@testable import NASTOOLMobile

final class ScaffoldTests: XCTestCase {
    func testAppTabContainsExpectedPrimaryTabs() {
        XCTAssertEqual(AppTab.allCases.map(\.title), ["Home", "Downloads", "Search", "Subscriptions", "Settings"])
    }
}
