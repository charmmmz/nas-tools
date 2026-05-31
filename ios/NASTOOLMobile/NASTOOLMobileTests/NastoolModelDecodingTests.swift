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

    func testDownloadingResponseDecodesApiActionWrappedResult() throws {
        let data = Data("""
        {
          "code": 0,
          "success": true,
          "message": "",
          "data": {
            "result": [
              {
                "id": "torrent-hash",
                "name": "Raw Torrent",
                "title": "Identified Movie",
                "speed": "↓2MB/s ↑10KB/s 5m",
                "state": "Downloading",
                "progress": 64.2,
                "image": ""
              }
            ]
          }
        }
        """.utf8)

        let response = try JSONDecoder().decode(NastoolResultResponse<[DownloadTask]>.self, from: data)

        XCTAssertEqual(response.result.map(\.id), ["torrent-hash"])
        XCTAssertEqual(response.result.first?.displayTitle, "Identified Movie")
    }

    func testDownloadInfoResponseDecodesApiActionWrappedTorrents() throws {
        let data = Data("""
        {
          "code": 0,
          "success": true,
          "message": "",
          "data": {
            "torrents": [
              {
                "id": "torrent-hash",
                "speed": "已暂停",
                "state": "Stoped",
                "progress": 12
              }
            ]
          }
        }
        """.utf8)

        let response = try JSONDecoder().decode(DownloadInfoResponse.self, from: data)

        XCTAssertEqual(response.retcode, 0)
        XCTAssertEqual(response.torrents.first?.id, "torrent-hash")
    }

    func testMediaCandidateResponseDecodesApiActionWrappedTMDBResults() throws {
        let data = Data("""
        {
          "code": 0,
          "success": true,
          "message": "",
          "data": {
            "result": [
              {
                "id": 101,
                "title": "Arrival",
                "year": "2016",
                "type": "电影",
                "media_type": "电影",
                "vote": 7.6,
                "image": "https://image.tmdb.org/t/p/w500/poster.jpg",
                "tmdb_id": 101,
                "overview": "A linguist works with aliens.",
                "link": "https://www.themoviedb.org/movie/101"
              }
            ]
          }
        }
        """.utf8)

        let response = try JSONDecoder().decode(NastoolResultResponse<[MediaCandidate]>.self, from: data)

        XCTAssertEqual(response.result.first?.id, "101")
        XCTAssertEqual(response.result.first?.tmdbID, "101")
        XCTAssertEqual(response.result.first?.posterPath, "https://image.tmdb.org/t/p/w500/poster.jpg")
    }

    func testHomeFeedResponseDecodesApiActionWrappedPosterItems() throws {
        let data = Data("""
        {
          "code": 0,
          "success": true,
          "data": {
            "group": "popular",
            "filter": "streaming",
            "region": "CN",
            "page": 1,
            "has_more": true,
            "items": [
              {
                "id": 101,
                "tmdbid": 101,
                "title": "Arrival",
                "type": "MOV",
                "media_type": "电影",
                "year": "2016",
                "vote": 7.6,
                "image": "https://image.tmdb.org/t/p/w500/poster.jpg",
                "backdrop": "https://image.tmdb.org/t/p/w500/backdrop.jpg",
                "overview": "A movie.",
                "fav": true,
                "rssid": "rss-1"
              }
            ]
          }
        }
        """.utf8)

        let response = try JSONDecoder().decode(HomeFeedResponse.self, from: data)

        XCTAssertEqual(response.data.group, .popular)
        XCTAssertEqual(response.data.filter, .streaming)
        XCTAssertEqual(response.data.region, "CN")
        XCTAssertTrue(response.data.hasMore)
        XCTAssertEqual(response.data.items.first?.id, "101")
        XCTAssertEqual(response.data.items.first?.tmdbID, "101")
        XCTAssertEqual(response.data.items.first?.voteText, "7.6")
        XCTAssertTrue(response.data.items.first?.isFavorite == true)
    }

    func testSearchMediaResultDecodesNestedTorrentGroups() throws {
        let data = Data("""
        {
          "key": "media-key",
          "title": "Arrival",
          "year": "2016",
          "type": "电影",
          "poster": "https://image.tmdb.org/t/p/w500/poster.jpg",
          "overview": "A movie.",
          "exist": false,
          "torrent_dict": [
            [
              "MOV",
              {
                "webdl_1080p": {
                  "group_info": {
                    "respix": "1080p",
                    "restype": "WEB-DL"
                  },
                  "group_total": 1,
                  "group_torrents": {
                    "unique": {
                      "unique_info": {
                        "size": "12 GB"
                      },
                      "torrent_list": [
                        {
                          "id": 301,
                          "site": "PTSite",
                          "torrent_name": "Arrival.2016.1080p.WEB-DL",
                          "description": "WEB-DL / 1080p",
                          "pageurl": "https://pt.example.com/t/301",
                          "size": "12 GB",
                          "respix": "1080p",
                          "restype": "WEB-DL",
                          "seeders": 42,
                          "uploadvalue": 1.0,
                          "downloadvalue": 0.0
                        }
                      ]
                    }
                  }
                }
              }
            ]
          ]
        }
        """.utf8)

        let result = try JSONDecoder().decode(SearchMediaResult.self, from: data)

        XCTAssertEqual(result.posterPath, "https://image.tmdb.org/t/p/w500/poster.jpg")
        XCTAssertEqual(result.torrents.map(\.id), ["301"])
        XCTAssertEqual(result.torrents.first?.torrentName, "Arrival.2016.1080p.WEB-DL")
        XCTAssertEqual(result.torrents.first?.freeText, "FREE")
    }
}
