import Foundation

final class NastoolAPIClient: @unchecked Sendable {
    let baseURL: URL

    private let session: URLSession
    private let token: String?
    private let decoder: JSONDecoder

    init(
        baseURL: URL,
        session: URLSession = .shared,
        token: String? = nil,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.baseURL = baseURL
        self.session = session
        self.token = token
        self.decoder = decoder
    }

    func withToken(_ token: String) -> NastoolAPIClient {
        NastoolAPIClient(baseURL: baseURL, session: session, token: token, decoder: decoder)
    }

    func makeFormRequest(path: String, fields: [String: String?] = [:], includeAuth: Bool = true) throws -> URLRequest {
        var request = URLRequest(url: try endpointURL(path: path))
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if includeAuth, let token, !token.isEmpty {
            request.setValue(token, forHTTPHeaderField: "Authorization")
        }
        request.httpBody = formEncoded(fields: fields)
        return request
    }

    func postForm<Response: Decodable>(
        path: String,
        fields: [String: String?] = [:],
        includeAuth: Bool = true
    ) async throws -> Response {
        let request = try makeFormRequest(path: path, fields: fields, includeAuth: includeAuth)
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NastoolAPIError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw NastoolAPIError.httpStatus(httpResponse.statusCode)
        }
        return try decoder.decode(Response.self, from: data)
    }

    func login(username: String, password: String) async throws -> LoginResponse {
        try await postForm(
            path: "/api/v1/user/login",
            fields: [
                "username": username,
                "password": password
            ],
            includeAuth: false
        )
    }

    func fetchDownloading() async throws -> NastoolResultResponse<[DownloadTask]> {
        try await postForm(path: "/api/v1/download/now")
    }

    func fetchDownloadInfo(ids: [String]) async throws -> DownloadInfoResponse {
        try await postForm(path: "/api/v1/download/info", fields: ["ids": ids.joined(separator: ",")])
    }

    func startDownload(id: String) async throws -> NastoolCommandResponse {
        try await postForm(path: "/api/v1/download/start", fields: ["id": id])
    }

    func stopDownload(id: String) async throws -> NastoolCommandResponse {
        try await postForm(path: "/api/v1/download/stop", fields: ["id": id])
    }

    func removeDownload(id: String) async throws -> NastoolCommandResponse {
        try await postForm(path: "/api/v1/download/remove", fields: ["id": id])
    }

    func searchKeyword(_ keyword: String, quickMode: Bool = true) async throws -> NastoolCommandResponse {
        try await postForm(
            path: "/api/v1/search/keyword",
            fields: [
                "search_word": keyword,
                "unident": quickMode ? "1" : "0"
            ]
        )
    }

    func fetchSearchResults() async throws -> SearchResultsResponse {
        try await postForm(path: "/api/v1/search/result")
    }

    func downloadSearchResult(id: String, directory: String? = nil, setting: String? = nil) async throws -> NastoolCommandResponse {
        try await postForm(
            path: "/api/v1/download/search",
            fields: [
                "id": id,
                "dir": directory,
                "setting": setting
            ]
        )
    }

    func fetchMovieSubscriptions() async throws -> NastoolResultResponse<[String: SubscriptionItem]> {
        try await postForm(path: "/api/v1/subscribe/movie/list")
    }

    func fetchTVSubscriptions() async throws -> NastoolResultResponse<[String: SubscriptionItem]> {
        try await postForm(path: "/api/v1/subscribe/tv/list")
    }

    func addSubscription(_ request: AddSubscriptionRequest) async throws -> NastoolCommandResponse {
        try await postForm(path: "/api/v1/subscribe/add", fields: request.formFields)
    }

    func removeSubscription(id: String, mediaType: AddSubscriptionRequest.MediaType) async throws -> NastoolCommandResponse {
        try await postForm(
            path: "/api/v1/subscribe/delete",
            fields: [
                "rssid": id,
                "type": mediaType.rawValue
            ]
        )
    }

    private func endpointURL(path: String) throws -> URL {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw NastoolAPIError.invalidBaseURL
        }

        let basePath = components.path.trimmingSlashes
        let endpointPath = path.trimmingSlashes
        if basePath.isEmpty {
            components.path = "/" + endpointPath
        } else {
            components.path = "/" + [basePath, endpointPath].joined(separator: "/")
        }

        guard let url = components.url else {
            throw NastoolAPIError.invalidBaseURL
        }
        return url
    }

    private func formEncoded(fields: [String: String?]) -> Data {
        let body = fields
            .compactMap { key, value -> (String, String)? in
                guard let value else {
                    return nil
                }
                return (key, value)
            }
            .sorted { lhs, rhs in lhs.0 < rhs.0 }
            .map { key, value in
                "\(percentEncode(key))=\(percentEncode(value))"
            }
            .joined(separator: "&")

        return Data(body.utf8)
    }

    private func percentEncode(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: ":#[]@!$&'()*+,;=")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}

private extension String {
    var trimmingSlashes: String {
        trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}
