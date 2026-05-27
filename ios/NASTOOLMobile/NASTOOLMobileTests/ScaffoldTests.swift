import XCTest
@testable import NASTOOLMobile

final class ScaffoldTests: XCTestCase {
    func testAppTabContainsExpectedPrimaryTabs() {
        XCTAssertEqual(AppTab.allCases.map(\.title), ["Downloads", "Search", "Subscriptions", "Settings"])
    }
}
