# -*- coding: utf-8 -*-

import threading
from unittest import TestCase

from app.media.recommendation import RecommendationService
from app.utils.types import MediaType


class MemoryPosterCache:
    def __init__(self, initial=None):
        self.values = dict(initial or {})
        self.sets = []

    def get(self, key):
        return self.values.get(key)

    def set(self, key, value):
        self.values[key] = value
        self.sets.append((key, value))

    def clear(self):
        self.values.clear()
        self.sets.clear()


class FakeMedia:
    def __init__(self):
        self.tmdb_info_calls = []
        self.media_info_calls = []

    def get_tmdb_info(self, mtype, tmdbid):
        self.tmdb_info_calls.append((mtype, tmdbid))
        return {"poster_path": "/poster-%s.jpg" % tmdbid}

    def get_media_info(self, title, mtype, strict=True):
        self.media_info_calls.append((title, mtype, strict))
        return type("MediaInfo", (), {
            "tmdb_id": 456,
            "poster_path": "https://image.tmdb.org/t/p/w500/douban.jpg"
        })()


class BlockingMedia:
    def __init__(self, entered_event, release_event):
        self.entered_event = entered_event
        self.release_event = release_event
        self.calls = []
        self._lock = threading.Lock()

    def get_tmdb_info(self, mtype, tmdbid):
        with self._lock:
            self.calls.append(tmdbid)
            if len(self.calls) == 2:
                self.entered_event.set()
        self.release_event.wait(1)
        return {"poster_path": "/poster-%s.jpg" % tmdbid}


class FakeFileTransfer:
    def __init__(self):
        self.calls = []

    def get_media_exists_flag(self, mtype, title, year, mediaid):
        self.calls.append((mtype, title, year, mediaid))
        return ("exists-%s" % mediaid, "rss-%s" % mediaid)


class FakeTrakt:
    def get_movie_recommendations(self, page=1, params=None):
        return [{
            "id": 11,
            "title": "Movie",
            "year": "2026",
            "type": "MOV",
            "media_type": "电影",
            "image": "",
            "overview": "Overview",
            "site": "Trakt"
        }]


class RecommendationServiceTest(TestCase):
    def test_trakt_items_are_standardized_and_poster_result_is_persisted(self):
        media = FakeMedia()
        cache = MemoryPosterCache()
        service = RecommendationService(media_factory=lambda: media,
                                        poster_cache=cache,
                                        max_workers=1)

        cards = service.normalize_items([{
            "id": 123,
            "title": "Movie",
            "year": "2026",
            "type": "MOV",
            "media_type": "电影",
            "image": "https://trakt.example/poster.jpg",
            "overview": "Overview",
            "site": "Trakt"
        }], source="trakt")

        self.assertEqual(cards[0]["source"], "trakt")
        self.assertEqual(cards[0]["source_id"], "123")
        self.assertEqual(cards[0]["source_image"], "https://trakt.example/poster.jpg")
        self.assertEqual(cards[0]["tmdbid"], 123)
        self.assertEqual(cards[0]["image"], "https://image.tmdb.org/t/p/w500/poster-123.jpg")
        self.assertEqual(media.tmdb_info_calls, [(MediaType.MOVIE, 123)])
        self.assertEqual(cache.values["poster:trakt:电影:123"]["image"], cards[0]["image"])

    def test_persisted_poster_cache_is_used_without_calling_tmdb(self):
        media = FakeMedia()
        cache = MemoryPosterCache({
            "poster:trakt:电影:123": {
                "image": "https://image.tmdb.org/t/p/w500/cached.jpg",
                "tmdbid": 123
            }
        })
        service = RecommendationService(media_factory=lambda: media,
                                        poster_cache=cache,
                                        max_workers=1)

        cards = service.normalize_items([{
            "id": 123,
            "title": "Movie",
            "year": "2026",
            "type": "MOV",
            "media_type": "电影",
            "image": "",
            "overview": "",
            "site": "Trakt"
        }], source="trakt")

        self.assertEqual(cards[0]["image"], "https://image.tmdb.org/t/p/w500/cached.jpg")
        self.assertEqual(media.tmdb_info_calls, [])

    def test_douban_items_fall_back_to_proxy_when_tmdb_match_missing(self):
        media = FakeMedia()
        media.get_media_info = lambda *args, **kwargs: None
        service = RecommendationService(media_factory=lambda: media,
                                        poster_cache=MemoryPosterCache(),
                                        max_workers=1)

        cards = service.normalize_items([{
            "id": "DB:1",
            "title": "Douban Movie",
            "year": "2026",
            "type": "MOV",
            "media_type": "电影",
            "image": "https://img3.doubanio.com/view/photo/m_ratio_poster/public/p2932533733.webp",
            "overview": ""
        }], source="douban")

        self.assertTrue(cards[0]["image"].startswith("/douban/image?url="))
        self.assertEqual(cards[0]["source"], "douban")
        self.assertEqual(cards[0]["source_id"], "DB:1")

    def test_uncached_poster_hydration_runs_concurrently(self):
        entered_event = threading.Event()
        release_event = threading.Event()
        media = BlockingMedia(entered_event=entered_event,
                              release_event=release_event)
        service = RecommendationService(media_factory=lambda: media,
                                        poster_cache=MemoryPosterCache(),
                                        max_workers=2)

        result = []
        worker = threading.Thread(target=lambda: result.extend(service.normalize_items([
            {"id": 101, "title": "A", "year": "2026", "type": "MOV", "media_type": "电影", "image": ""},
            {"id": 102, "title": "B", "year": "2026", "type": "MOV", "media_type": "电影", "image": ""},
        ], source="trakt")))
        worker.start()

        self.assertTrue(entered_event.wait(0.5))
        release_event.set()
        worker.join(1)
        self.assertFalse(worker.is_alive())
        self.assertEqual([item["tmdbid"] for item in result], [101, 102])

    def test_get_recommend_fetches_standardizes_and_appends_library_state(self):
        filetransfer = FakeFileTransfer()
        service = RecommendationService(
            trakt_factory=FakeTrakt,
            media_factory=FakeMedia,
            filetransfer_factory=lambda: filetransfer,
            poster_cache=MemoryPosterCache(),
            max_workers=1
        )

        result = service.get_recommend({
            "type": "TRAKT",
            "subtype": "movie",
            "page": 1,
            "params": {}
        })

        self.assertEqual(result["code"], 0)
        self.assertEqual(result["Items"][0]["fav"], "exists-11")
        self.assertEqual(result["Items"][0]["rssid"], "rss-11")
        self.assertEqual(filetransfer.calls, [("MOV", "Movie", "2026", 11)])
