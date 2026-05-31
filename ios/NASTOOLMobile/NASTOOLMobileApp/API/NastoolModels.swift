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

    enum CodingKeys: String, CodingKey {
        case code
        case success
        case message
        case msg
        case total
        case result
        case data
    }

    init(code: Int, success: Bool?, message: String?, msg: String?, total: Int?, result: Result) {
        self.code = code
        self.success = success
        self.message = message
        self.msg = msg
        self.total = total
        self.result = result
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let dataContainer = try? container.nestedContainer(keyedBy: CodingKeys.self, forKey: .data)

        code = try container.decode(Int.self, forKey: .code)
        success = try? container.decode(Bool.self, forKey: .success)
        message = try? container.decode(String.self, forKey: .message)
        msg = try? container.decode(String.self, forKey: .msg)
        total = (try? container.decode(Int.self, forKey: .total))
            ?? (try? dataContainer?.decode(Int.self, forKey: .total))

        if let topLevelResult = try? container.decode(Result.self, forKey: .result) {
            result = topLevelResult
        } else if let nestedResult = try? dataContainer?.decode(Result.self, forKey: .result) {
            result = nestedResult
        } else {
            result = try container.decode(Result.self, forKey: .result)
        }
    }
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

    enum CodingKeys: String, CodingKey {
        case retcode
        case code
        case torrents
        case data
    }

    init(retcode: Int, torrents: [DownloadTask]) {
        self.retcode = retcode
        self.torrents = torrents
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let dataContainer = try? container.nestedContainer(keyedBy: CodingKeys.self, forKey: .data)

        retcode = (try? container.decode(Int.self, forKey: .retcode))
            ?? (try? container.decode(Int.self, forKey: .code))
            ?? (try? dataContainer?.decode(Int.self, forKey: .retcode))
            ?? (try? dataContainer?.decode(Int.self, forKey: .code))
            ?? 0

        if let topLevelTorrents = try? container.decode([DownloadTask].self, forKey: .torrents) {
            torrents = topLevelTorrents
        } else if let nestedTorrents = try? dataContainer?.decode([DownloadTask].self, forKey: .torrents) {
            torrents = nestedTorrents
        } else {
            torrents = try container.decode([DownloadTask].self, forKey: .torrents)
        }
    }
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

    enum CodingKeys: String, CodingKey {
        case code
        case total
        case result
        case data
    }

    init(code: Int, total: Int?, result: [String: SearchMediaResult]) {
        self.code = code
        self.total = total
        self.result = result
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let dataContainer = try? container.nestedContainer(keyedBy: CodingKeys.self, forKey: .data)

        code = try container.decode(Int.self, forKey: .code)
        total = (try? container.decode(Int.self, forKey: .total))
            ?? (try? dataContainer?.decode(Int.self, forKey: .total))

        if let topLevelResult = try? container.decode([String: SearchMediaResult].self, forKey: .result) {
            result = topLevelResult
        } else if let nestedResult = try? dataContainer?.decode([String: SearchMediaResult].self, forKey: .result) {
            result = nestedResult
        } else {
            result = try container.decode([String: SearchMediaResult].self, forKey: .result)
        }
    }
}

struct MediaCandidate: Decodable, Equatable, Hashable, Identifiable {
    let id: String
    let title: String
    let year: String?
    let mediaType: String?
    let vote: String?
    let posterPath: String?
    let tmdbID: String?
    let overview: String?
    let link: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case year
        case type
        case mediaType = "media_type"
        case vote
        case posterPath = "image"
        case tmdbID = "tmdb_id"
        case overview
        case link
    }

    init(
        id: String,
        title: String,
        year: String?,
        mediaType: String?,
        vote: String?,
        posterPath: String?,
        tmdbID: String?,
        overview: String?,
        link: String?
    ) {
        self.id = id
        self.title = title
        self.year = year
        self.mediaType = mediaType
        self.vote = vote
        self.posterPath = posterPath
        self.tmdbID = tmdbID
        self.overview = overview
        self.link = link
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        year = try container.decodeFlexibleStringIfPresent(forKey: .year)
        mediaType = (try? container.decode(String.self, forKey: .mediaType))
            ?? (try? container.decode(String.self, forKey: .type))
        vote = try container.decodeFlexibleStringIfPresent(forKey: .vote)
        posterPath = try container.decodeIfPresent(String.self, forKey: .posterPath)
        tmdbID = try container.decodeFlexibleStringIfPresent(forKey: .tmdbID)
        overview = try container.decodeIfPresent(String.self, forKey: .overview)
        link = try container.decodeIfPresent(String.self, forKey: .link)
        id = (try? container.decodeFlexibleString(forKey: .id)) ?? tmdbID ?? title
    }
}

struct SearchMediaResult: Decodable, Equatable, Hashable, Identifiable {
    let id: String
    let title: String
    let year: String?
    let mediaType: String?
    let posterPath: String?
    let overview: String?
    let existsInLibrary: Bool
    let torrents: [SearchTorrent]

    enum CodingKeys: String, CodingKey {
        case id = "key"
        case title
        case year
        case mediaType = "type"
        case posterPath = "poster"
        case imagePath = "image"
        case overview
        case existsInLibrary = "exist"
        case torrentDict = "torrent_dict"
    }

    init(
        id: String,
        title: String,
        year: String? = nil,
        mediaType: String? = nil,
        posterPath: String? = nil,
        overview: String? = nil,
        existsInLibrary: Bool = false,
        torrents: [SearchTorrent] = []
    ) {
        self.id = id
        self.title = title
        self.year = year
        self.mediaType = mediaType
        self.posterPath = posterPath
        self.overview = overview
        self.existsInLibrary = existsInLibrary
        self.torrents = torrents
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeFlexibleString(forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? id
        year = try container.decodeFlexibleStringIfPresent(forKey: .year)
        mediaType = try container.decodeIfPresent(String.self, forKey: .mediaType)
        posterPath = (try? container.decode(String.self, forKey: .posterPath))
            ?? (try? container.decode(String.self, forKey: .imagePath))
        overview = try container.decodeIfPresent(String.self, forKey: .overview)
        existsInLibrary = try container.decodeIfPresent(Bool.self, forKey: .existsInLibrary) ?? false
        torrents = Self.decodeTorrents(from: container)
    }

    private static func decodeTorrents(from container: KeyedDecodingContainer<CodingKeys>) -> [SearchTorrent] {
        if let seasonEntries = try? container.decode([SearchSeasonTorrentEntry].self, forKey: .torrentDict) {
            return seasonEntries.flatMap(\.torrents)
        }
        if let seasonDictionary = try? container.decode([String: [String: SearchTorrentGroup]].self, forKey: .torrentDict) {
            return seasonDictionary.values.flatMap { groupDictionary in
                groupDictionary.values.flatMap(\.torrents)
            }
        }
        return []
    }
}

struct SearchTorrent: Decodable, Equatable, Hashable, Identifiable {
    let id: String
    let site: String?
    let torrentName: String
    let description: String?
    let pageURL: String?
    let size: String?
    let respix: String?
    let restype: String?
    let reseffect: String?
    let releasegroup: String?
    let videoEncode: String?
    let seeders: Int?
    let uploadValue: Double?
    let downloadValue: Double?

    var qualityText: String {
        [restype, respix, videoEncode, reseffect].compactMap { value in
            guard let value, !value.isEmpty else {
                return nil
            }
            return value
        }.joined(separator: " / ")
    }

    var freeText: String? {
        if downloadValue == 0 {
            return "FREE"
        }
        if let downloadValue, downloadValue != 1 {
            return "\(Int((downloadValue * 100).rounded()))%DL"
        }
        if let uploadValue, uploadValue != 1 {
            return "\(Int((uploadValue * 100).rounded()))%UL"
        }
        return nil
    }

    enum CodingKeys: String, CodingKey {
        case id
        case site
        case torrentName = "torrent_name"
        case description
        case pageURL = "pageurl"
        case size
        case respix
        case restype
        case reseffect
        case releasegroup
        case videoEncode = "video_encode"
        case seeders
        case uploadValue = "uploadvalue"
        case downloadValue = "downloadvalue"
    }

    init(
        id: String,
        site: String? = nil,
        torrentName: String,
        description: String? = nil,
        pageURL: String? = nil,
        size: String? = nil,
        respix: String? = nil,
        restype: String? = nil,
        reseffect: String? = nil,
        releasegroup: String? = nil,
        videoEncode: String? = nil,
        seeders: Int? = nil,
        uploadValue: Double? = nil,
        downloadValue: Double? = nil
    ) {
        self.id = id
        self.site = site
        self.torrentName = torrentName
        self.description = description
        self.pageURL = pageURL
        self.size = size
        self.respix = respix
        self.restype = restype
        self.reseffect = reseffect
        self.releasegroup = releasegroup
        self.videoEncode = videoEncode
        self.seeders = seeders
        self.uploadValue = uploadValue
        self.downloadValue = downloadValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeFlexibleString(forKey: .id)
        site = try container.decodeIfPresent(String.self, forKey: .site)
        torrentName = try container.decodeIfPresent(String.self, forKey: .torrentName) ?? id
        description = try container.decodeIfPresent(String.self, forKey: .description)
        pageURL = try container.decodeIfPresent(String.self, forKey: .pageURL)
        size = try container.decodeIfPresent(String.self, forKey: .size)
        respix = try container.decodeIfPresent(String.self, forKey: .respix)
        restype = try container.decodeIfPresent(String.self, forKey: .restype)
        reseffect = try container.decodeIfPresent(String.self, forKey: .reseffect)
        releasegroup = try container.decodeIfPresent(String.self, forKey: .releasegroup)
        videoEncode = try container.decodeIfPresent(String.self, forKey: .videoEncode)
        seeders = try container.decodeFlexibleIntIfPresent(forKey: .seeders)
        uploadValue = try container.decodeFlexibleDoubleIfPresent(forKey: .uploadValue)
        downloadValue = try container.decodeFlexibleDoubleIfPresent(forKey: .downloadValue)
    }
}

private struct SearchSeasonTorrentEntry: Decodable {
    let seasonKey: String
    let groups: [String: SearchTorrentGroup]

    var torrents: [SearchTorrent] {
        groups.values.flatMap(\.torrents)
    }

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        seasonKey = try container.decode(String.self)
        groups = try container.decode([String: SearchTorrentGroup].self)
    }
}

private struct SearchTorrentGroup: Decodable {
    let groupTotal: Int?
    let groupTorrents: [String: SearchTorrentUnique]

    var torrents: [SearchTorrent] {
        groupTorrents.values.flatMap(\.torrentList)
    }

    enum CodingKeys: String, CodingKey {
        case groupTotal = "group_total"
        case groupTorrents = "group_torrents"
    }
}

private struct SearchTorrentUnique: Decodable {
    let torrentList: [SearchTorrent]

    enum CodingKeys: String, CodingKey {
        case torrentList = "torrent_list"
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
