import XCTest
@testable import NASTOOLMobile

final class NastoolModelDecodingTests: XCTestCase {
    func testLoginResponseDecodesTokenApiKeyAndUser() throws {
        let data = Data("""
        {
          "code": 0,
          "success": true,
          "data": {
            "token": "jwt-token",
            "apikey": "api-key",
            "userinfo": {
              "userid": 7,
              "username": "admin",
              "userpris": ["admin", "search"]
            }
          }
        }
        """.utf8)

        let response = try JSONDecoder().decode(LoginResponse.self, from: data)

        XCTAssertEqual(response.code, 0)
        XCTAssertTrue(response.success)
        XCTAssertEqual(response.data.token, "jwt-token")
        XCTAssertEqual(response.data.apiKey, "api-key")
        XCTAssertEqual(response.data.user.username, "admin")
        XCTAssertEqual(response.data.user.permissions, ["admin", "search"])
    }

    func testDownloadTaskDecodesFlexibleStringAndNumericFields() throws {
        let data = Data("""
        {
          "id": 42,
          "name": "Raw Torrent Name",
          "title": "Identified Movie",
          "speed": "↓1.2MB/s ↑30KB/s 10m",
          "state": "Downloading",
          "progress": "41.5",
          "image": "/poster.jpg"
        }
        """.utf8)

        let task = try JSONDecoder().decode(DownloadTask.self, from: data)

        XCTAssertEqual(task.id, "42")
        XCTAssertEqual(task.displayTitle, "Identified Movie")
        XCTAssertEqual(task.speedText, "↓1.2MB/s ↑30KB/s 10m")
        XCTAssertEqual(task.progress, 41.5)
        XCTAssertTrue(task.isDownloading)
    }
}
