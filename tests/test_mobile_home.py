# -*- coding: utf-8 -*-

from unittest import TestCase
from unittest.mock import patch

from app.utils.types import MediaType
from web.action import WebAction


class FakeTMDB:
    def __init__(self):
        self.language = None


class FakeMedia:
    def __init__(self):
        self.tmdb = FakeTMDB()
        self.trending_calls = []
        self.discover_calls = []

    def get_tmdb_trending(self, mtype, time_window, page=1):
        media_key = "movie" if mtype == MediaType.MOVIE else "tv"
        self.trending_calls.append((media_key, time_window, page))
        return [{
            "id": "%s-%s" % (media_key, page),
            "title": "%s title" % media_key,
            "type": "MOV" if mtype == MediaType.MOVIE else "TV",
            "media_type": mtype.value,
            "year": "2026",
            "vote": 8.1,
            "image": "/%s.jpg" % media_key,
            "overview": "%s overview" % media_key
        }]

    def get_tmdb_discover(self, mtype, params=None, page=1):
        self.discover_calls.append((mtype, dict(params or {}), page))
        return [{
            "id": "%s-%s" % ("movie" if mtype == MediaType.MOVIE else "tv", page),
            "title": "Discover %s" % ("movie" if mtype == MediaType.MOVIE else "tv"),
            "type": "MOV" if mtype == MediaType.MOVIE else "TV",
            "media_type": mtype.value,
            "year": "2026",
            "vote": 7.8,
            "image": "/discover.jpg",
            "overview": "Discover overview"
        }]


class MobileHomeFeedTest(TestCase):
    def setUp(self):
        self.action = object.__new__(WebAction)

    def test_trending_today_uses_movie_and_tv_day_endpoints(self):
        fake_media = FakeMedia()

        with patch("web.action.Media", return_value=fake_media), \
                patch("web.action.FileTransfer") as filetransfer_cls:
            filetransfer_cls.return_value.get_media_exists_flag.return_value = (False, "")

            response = self.action.get_mobile_home({
                "group": "trending",
                "filter": "today",
                "page": 1
            })

        self.assertEqual(response["code"], 0)
        self.assertEqual(fake_media.trending_calls, [
            ("movie", "day", 1),
            ("tv", "day", 1)
        ])
        self.assertEqual([item["type"] for item in response["items"]], ["MOV", "TV"])
        filetransfer_cls.return_value.get_media_exists_flag.assert_any_call(
            mtype="MOV",
            title="movie title",
            year="2026",
            mediaid="movie-1"
        )

    def test_popular_streaming_uses_watch_region_and_flatrate(self):
        fake_media = FakeMedia()

        with patch("web.action.Media", return_value=fake_media), \
                patch("web.action.FileTransfer") as filetransfer_cls:
            filetransfer_cls.return_value.get_media_exists_flag.return_value = (True, "rss-1")

            response = self.action.get_mobile_home({
                "group": "popular",
                "filter": "streaming",
                "region": "cn",
                "page": 2
            })

        self.assertEqual(response["code"], 0)
        self.assertEqual(response["region"], "CN")
        self.assertEqual(fake_media.discover_calls[0][0], MediaType.MOVIE)
        self.assertEqual(fake_media.discover_calls[0][1]["watch_region"], "CN")
        self.assertEqual(fake_media.discover_calls[0][1]["with_watch_monetization_types"], "flatrate")
        self.assertEqual(fake_media.discover_calls[1][0], MediaType.TV)
        self.assertTrue(response["items"][0]["fav"])
        self.assertEqual(response["items"][0]["rssid"], "rss-1")

    def test_popular_theaters_uses_movie_release_region(self):
        fake_media = FakeMedia()

        with patch("web.action.Media", return_value=fake_media), \
                patch("web.action.FileTransfer") as filetransfer_cls:
            filetransfer_cls.return_value.get_media_exists_flag.return_value = (False, "")

            response = self.action.get_mobile_home({
                "group": "popular",
                "filter": "theaters",
                "region": "US",
                "page": 1
            })

        self.assertEqual(response["code"], 0)
        self.assertEqual(len(fake_media.discover_calls), 1)
        self.assertEqual(fake_media.discover_calls[0][0], MediaType.MOVIE)
        self.assertEqual(fake_media.discover_calls[0][1]["region"], "US")
        self.assertEqual(fake_media.discover_calls[0][1]["with_release_type"], "2|3")

    def test_popular_rejects_invalid_region(self):
        response = self.action.get_mobile_home({
            "group": "popular",
            "filter": "streaming",
            "region": "USA",
            "page": 1
        })

        self.assertEqual(response["code"], 1)
        self.assertIn("地区", response["msg"])

    def test_language_is_normalized_and_applied_to_tmdb(self):
        fake_media = FakeMedia()

        with patch("web.action.Media", return_value=fake_media), \
                patch("web.action.FileTransfer") as filetransfer_cls:
            filetransfer_cls.return_value.get_media_exists_flag.return_value = ("0", "")

            response = self.action.get_mobile_home({
                "group": "trending",
                "filter": "today",
                "language": "zh_cn",
                "page": 1
            })

        self.assertEqual(response["code"], 0)
        self.assertEqual(response["language"], "zh-CN")
        self.assertEqual(fake_media.tmdb.language, "zh-CN")
