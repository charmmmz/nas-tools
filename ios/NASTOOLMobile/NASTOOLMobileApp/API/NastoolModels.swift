import Foundation

struct LoginResponse: Decodable, Equatable {
    let code: Int
    let success: Bool
    let message: String?
    let data: LoginSession
}

struct LoginSession: Decodable, Equatable {
    let token: String
    let apiKey: String
    let user: NastoolUser

    enum CodingKeys: String, CodingKey {
        case token
        case apiKey = "apikey"
        case user = "userinfo"
    }
}

struct NastoolUser: Decodable, Equatable {
    let id: String
    let username: String
    let permissions: [String]

    enum CodingKeys: String, CodingKey {
        case id = "userid"
        case username
        case permissions = "userpris"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeFlexibleString(forKey: .id)
        username = try container.decode(String.self, forKey: .username)
        permissions = try container.decodeIfPresent([String].self, forKey: .permissions) ?? []
    }
}

struct NastoolResultResponse<Result: Decodable>: Decodable {
    let code: Int
    let success: Bool?
    let message: String?
    let msg: String?
    let total: Int?
    let result: Result
}

struct NastoolCommandResponse: Decodable, Equatable {
    let code: Int?
    let retcode: Int?
    let success: Bool?
    let message: String?
    let msg: String?
    let retmsg: String?

    var isSuccess: Bool {
        if let success {
            return success
        }
        if let code {
            return code == 0
        }
        if let retcode {
            return retcode == 0
        }
        return false
    }
}

struct DownloadInfoResponse: Decodable, Equatable {
    let retcode: Int
    let torrents: [DownloadTask]
}

struct DownloadTask: Decodable, Equatable, Hashable, Identifiable {
    let id: String
    let name: String?
    let title: String?
    let speedText: String
    let state: String
    let progress: Double
    let imagePath: String?

    var displayTitle: String {
        if let title, !title.isEmpty {
            return title
        }
        return name ?? id
    }

    var isDownloading: Bool {
        !["stopped", "stoped", "paused"].contains(state.lowercased())
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case title
        case speedText = "speed"
        case state
        case progress
        case imagePath = "image"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeFlexibleString(forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        speedText = try container.decodeIfPresent(String.self, forKey: .speedText) ?? ""
        state = try container.decodeIfPresent(String.self, forKey: .state) ?? ""
        progress = try container.decodeFlexibleDoubleIfPresent(forKey: .progress) ?? 0
        imagePath = try container.decodeIfPresent(String.self, forKey: .imagePath)
    }

    init(
        id: String,
        name: String? = nil,
        title: String? = nil,
        speedText: String = "",
        state: String = "",
        progress: Double = 0,
        imagePath: String? = nil
    ) {
        self.id = id
        self.name = name
        self.title = title
        self.speedText = speedText
        self.state = state
        self.progress = progress
        self.imagePath = imagePath
    }
}

struct SearchResultsResponse: Decodable {
    let code: Int
    let total: Int?
    let result: [String: SearchMediaResult]
}

struct SearchMediaResult: Decodable, Equatable, Hashable, Identifiable {
    let id: String
    let title: String
    let year: String?
    let mediaType: String?
    let posterPath: String?
    let overview: String?
    let existsInLibrary: Bool

    enum CodingKeys: String, CodingKey {
        case id = "key"
        case title
        case year
        case mediaType = "type"
        case posterPath = "poster"
        case overview
        case existsInLibrary = "exist"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeFlexibleString(forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? id
        year = try container.decodeFlexibleStringIfPresent(forKey: .year)
        mediaType = try container.decodeIfPresent(String.self, forKey: .mediaType)
        posterPath = try container.decodeIfPresent(String.self, forKey: .posterPath)
        overview = try container.decodeIfPresent(String.self, forKey: .overview)
        existsInLibrary = try container.decodeIfPresent(Bool.self, forKey: .existsInLibrary) ?? false
    }
}

struct SubscriptionItem: Decodable, Equatable, Hashable, Identifiable {
    let id: String
    let name: String
    let year: String?
    let season: String?
    let state: String?
    let posterPath: String?
    let overview: String?
    let totalEpisodes: Int?
    let currentEpisode: Int?
    let missingEpisodes: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case year
        case season
        case state
        case posterPath = "poster"
        case overview
        case totalEpisodes = "total_ep"
        case currentEpisode = "current_ep"
        case missingEpisodes = "lack"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeFlexibleString(forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? id
        year = try container.decodeFlexibleStringIfPresent(forKey: .year)
        season = try container.decodeFlexibleStringIfPresent(forKey: .season)
        state = try container.decodeIfPresent(String.self, forKey: .state)
        posterPath = try container.decodeIfPresent(String.self, forKey: .posterPath)
        overview = try container.decodeIfPresent(String.self, forKey: .overview)
        totalEpisodes = try container.decodeFlexibleIntIfPresent(forKey: .totalEpisodes)
        currentEpisode = try container.decodeFlexibleIntIfPresent(forKey: .currentEpisode)
        missingEpisodes = try container.decodeFlexibleIntIfPresent(forKey: .missingEpisodes)
    }
}

struct AddSubscriptionRequest: Equatable {
    enum MediaType: String {
        case movie = "MOV"
        case tv = "TV"
    }

    var name: String
    var mediaType: MediaType
    var year: String?
    var keyword: String?
    var season: Int?
    var mediaID: String?

    var formFields: [String: String?] {
        [
            "name": name,
            "type": mediaType.rawValue,
            "year": year,
            "keyword": keyword,
            "season": season.map(String.init),
            "mediaid": mediaID
        ]
    }
}

enum NastoolAPIError: LocalizedError, Equatable {
    case invalidBaseURL
    case invalidResponse
    case httpStatus(Int)
    case serverMessage(String)

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            "Invalid server URL."
        case .invalidResponse:
            "Invalid server response."
        case .httpStatus(let status):
            "Server returned HTTP \(status)."
        case .serverMessage(let message):
            message
        }
    }
}

extension KeyedDecodingContainer {
    func decodeFlexibleString(forKey key: Key) throws -> String {
        if let value = try? decode(String.self, forKey: key) {
            return value
        }
        if let value = try? decode(Int.self, forKey: key) {
            return String(value)
        }
        if let value = try? decode(Double.self, forKey: key) {
            return String(value)
        }
        throw DecodingError.valueNotFound(
            String.self,
            DecodingError.Context(codingPath: codingPath + [key], debugDescription: "Missing string-compatible value")
        )
    }

    func decodeFlexibleStringIfPresent(forKey key: Key) throws -> String? {
        if !contains(key) {
            return nil
        }
        if try decodeNil(forKey: key) {
            return nil
        }
        return try decodeFlexibleString(forKey: key)
    }

    func decodeFlexibleDoubleIfPresent(forKey key: Key) throws -> Double? {
        if !contains(key) {
            return nil
        }
        if try decodeNil(forKey: key) {
            return nil
        }
        if let value = try? decode(Double.self, forKey: key) {
            return value
        }
        if let value = try? decode(Int.self, forKey: key) {
            return Double(value)
        }
        if let value = try? decode(String.self, forKey: key) {
            return Double(value.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }

    func decodeFlexibleIntIfPresent(forKey key: Key) throws -> Int? {
        if let intValue = try? decode(Int.self, forKey: key) {
            return intValue
        }
        if let stringValue = try? decode(String.self, forKey: key) {
            return Int(stringValue.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        if let doubleValue = try? decode(Double.self, forKey: key) {
            return Int(doubleValue)
        }
        return nil
    }
}
