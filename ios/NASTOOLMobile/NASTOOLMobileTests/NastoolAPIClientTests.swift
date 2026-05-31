import XCTest
@testable import NASTOOLMobile

final class NastoolAPIClientTests: XCTestCase {
    func testMakeFormRequestUsesNastoolTokenHeaderAndEncodedBody() throws {
        let client = NastoolAPIClient(
            baseURL: try XCTUnwrap(URL(string: "https://nas.example.com/nastool/")),
            token: "jwt-token"
        )

        let request = try client.makeFormRequest(
            path: "/api/v1/download/info",
            fields: ["ids": "abc 123", "empty": nil]
        )

        XCTAssertEqual(request.url?.absoluteString, "https://nas.example.com/nastool/api/v1/download/info")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "jwt-token")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded; charset=utf-8")
        XCTAssertEqual(String(data: try XCTUnwrap(request.httpBody), encoding: .utf8), "ids=abc%20123")
    }

    func testMakeWebSocketRequestUsesWebSocketSchemeBasePathAndToken() throws {
        let client = NastoolAPIClient(
            baseURL: try XCTUnwrap(URL(string: "https://nas.example.com/nastool/")),
            token: "jwt-token"
        )

        let request = try client.makeWebSocketRequest(path: "/api/v1/mobile/downloads/ws")

        XCTAssertEqual(request.url?.absoluteString, "wss://nas.example.com/nastool/api/v1/mobile/downloads/ws")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "jwt-token")
    }

    func testMakeWebSocketRequestMapsHttpToWs() throws {
        let client = NastoolAPIClient(
            baseURL: try XCTUnwrap(URL(string: "http://nas.example.com")),
            token: "jwt-token"
        )

        let request = try client.makeWebSocketRequest(path: "/api/v1/mobile/downloads/ws")

        XCTAssertEqual(request.url?.scheme, "ws")
    }

    func testLoginPostsCredentialsAndDecodesResponse() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let client = NastoolAPIClient(
            baseURL: try XCTUnwrap(URL(string: "https://nas.example.com")),
            session: session
        )

        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/api/v1/user/login")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(String(data: try requestBodyData(from: request), encoding: .utf8), "password=p%40ss&username=admin")

            let data = Data("""
            {
              "code": 0,
              "success": true,
              "data": {
                "token": "jwt-token",
                "apikey": "api-key",
                "userinfo": {
                  "userid": "8",
                  "username": "admin",
                  "userpris": ["admin"]
                }
              }
            }
            """.utf8)
            return (HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }
        defer { MockURLProtocol.requestHandler = nil }

        let login = try await client.login(username: "admin", password: "p@ss")

        XCTAssertEqual(login.data.token, "jwt-token")
        XCTAssertEqual(login.data.apiKey, "api-key")
        XCTAssertEqual(login.data.user.id, "8")
    }

    func testFetchMediaCandidatesPostsKeywordAndTMDBSource() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let client = NastoolAPIClient(
            baseURL: try XCTUnwrap(URL(string: "https://nas.example.com")),
            session: session,
            token: "jwt-token"
        )

        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/api/v1/media/search")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "jwt-token")
            XCTAssertEqual(String(data: try requestBodyData(from: request), encoding: .utf8), "keyword=Arrival&searchtype=tmdb")

            let data = Data("""
            {
              "code": 0,
              "success": true,
              "data": {
                "result": [
                  {
                    "id": 101,
                    "title": "Arrival",
                    "type": "电影",
                    "tmdb_id": 101
                  }
                ]
              }
            }
            """.utf8)
            return (HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }
        defer { MockURLProtocol.requestHandler = nil }

        let response = try await client.fetchMediaCandidates(keyword: "Arrival", source: "tmdb")

        XCTAssertEqual(response.result.map(\.title), ["Arrival"])
    }

    func testSearchKeywordWithCandidateOmitsQuickModeAndPostsTMDBIdentity() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let client = NastoolAPIClient(
            baseURL: try XCTUnwrap(URL(string: "https://nas.example.com")),
            session: session,
            token: "jwt-token"
        )

        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/api/v1/search/keyword")
            XCTAssertEqual(
                String(data: try requestBodyData(from: request), encoding: .utf8),
                "media_type=%E7%94%B5%E5%BD%B1&search_word=Arrival&tmdbid=101"
            )

            let data = Data("""
            {
              "code": 0,
              "success": true,
              "message": "",
              "data": {}
            }
            """.utf8)
            return (HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }
        defer { MockURLProtocol.requestHandler = nil }

        let response = try await client.searchKeyword("Arrival", quickMode: false, tmdbID: "101", mediaType: "电影")

        XCTAssertTrue(response.isSuccess)
    }

    func testFetchHomeFeedPostsFilterRegionAndPage() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let client = NastoolAPIClient(
            baseURL: try XCTUnwrap(URL(string: "https://nas.example.com")),
            session: session,
            token: "jwt-token"
        )

        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/api/v1/mobile/home")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "jwt-token")
            XCTAssertEqual(
                String(data: try requestBodyData(from: request), encoding: .utf8),
                "filter=streaming&group=popular&page=2&region=CN"
            )

            let data = Data("""
            {
              "code": 0,
              "success": true,
              "message": "",
              "data": {
                "group": "popular",
                "filter": "streaming",
                "region": "CN",
                "page": 2,
                "has_more": false,
                "items": []
              }
            }
            """.utf8)
            return (HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }
        defer { MockURLProtocol.requestHandler = nil }

        let response = try await client.fetchHomeFeed(group: .popular, filter: .streaming, region: "CN", page: 2)

        XCTAssertEqual(response.data.group, .popular)
        XCTAssertEqual(response.data.filter, .streaming)
        XCTAssertEqual(response.data.page, 2)
    }
}

private final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let requestHandler = Self.requestHandler else {
            XCTFail("Missing request handler")
            return
        }

        do {
            let (response, data) = try requestHandler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private func requestBodyData(from request: URLRequest) throws -> Data {
    if let body = request.httpBody {
        return body
    }
    guard let stream = request.httpBodyStream else {
        return Data()
    }

    stream.open()
    defer { stream.close() }

    var data = Data()
    let bufferSize = 1024
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    defer { buffer.deallocate() }

    while stream.hasBytesAvailable {
        let count = stream.read(buffer, maxLength: bufferSize)
        if count < 0 {
            throw stream.streamError ?? NastoolAPIError.invalidResponse
        }
        if count == 0 {
            break
        }
        data.append(buffer, count: count)
    }
    return data
}
