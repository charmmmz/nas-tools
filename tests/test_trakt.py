# -*- coding: utf-8 -*-

import time
from unittest import TestCase
from unittest.mock import patch

from app.media.trakt import Trakt
from web.action import WebAction


class FakeResponse:
    def __init__(self, status_code=200, payload=None):
        self.status_code = status_code
        self._payload = payload or {}

    def json(self):
        return self._payload


class FakeRequest:
    def __init__(self, post_response=None, get_response=None):
        self.post_response = post_response
        self.get_response = get_response
        self.posts = []
        self.gets = []

    def post_res(self, url, json=None, **kwargs):
        self.posts.append({"url": url, "json": json, "kwargs": kwargs})
        return self.post_response

    def get_res(self, url, params=None, **kwargs):
        self.gets.append({"url": url, "params": params, "kwargs": kwargs})
        return self.get_response


class TraktClientTest(TestCase):
    def test_normalize_movie_with_tmdb_id(self):
        movie = Trakt.normalize_movie({
            "title": "Dune: Part Two",
            "year": 2024,
            "ids": {"trakt": 123, "tmdb": 693134},
            "rating": 8.14,
            "overview": "Paul Atreides unites with Chani.",
            "released": "2024-03-01",
            "images": {"poster": ["https://image.example/poster.jpg"]},
        })

        self.assertEqual(movie["id"], 693134)
        self.assertEqual(movie["orgid"], 123)
        self.assertEqual(movie["type"], "MOV")
        self.assertEqual(movie["media_type"], "电影")
        self.assertEqual(movie["title"], "Dune: Part Two")
        self.assertEqual(movie["vote"], 8.1)
        self.assertEqual(movie["image"], "https://image.example/poster.jpg")
        self.assertEqual(movie["date"], "2024-03-01")
        self.assertEqual(movie["site"], "Trakt")

    def test_normalize_show_with_tmdb_id(self):
        show = Trakt.normalize_show({
            "title": "Shogun",
            "year": 2024,
            "ids": {"trakt": 456, "tmdb": 126308},
            "rating": 8.91,
            "overview": "A collision of worlds.",
            "first_aired": "2024-02-27T00:00:00.000Z",
            "images": {"poster": ["https://image.example/show.jpg"]},
        })

        self.assertEqual(show["id"], 126308)
        self.assertEqual(show["orgid"], 456)
        self.assertEqual(show["type"], "TV")
        self.assertEqual(show["media_type"], "电视剧")
        self.assertEqual(show["title"], "Shogun")
        self.assertEqual(show["vote"], 8.9)
        self.assertEqual(show["image"], "https://image.example/show.jpg")
        self.assertEqual(show["date"], "2024-02-27")
        self.assertEqual(show["site"], "Trakt")

    def test_skip_items_without_tmdb_id(self):
        trakt = Trakt(config={
            "client_id": "client",
            "client_secret": "secret",
            "access_token": "access",
            "refresh_token": "refresh",
            "expires_at": int(time.time()) + 3600,
        }, request=FakeRequest(get_response=FakeResponse(payload=[
            {"title": "No TMDB", "ids": {"trakt": 1}},
            {"title": "With TMDB", "ids": {"trakt": 2, "tmdb": 999}, "year": 2026},
        ])))

        movies = trakt.get_movie_recommendations()

        self.assertEqual(len(movies), 1)
        self.assertEqual(movies[0]["id"], 999)

    def test_refresh_expiring_token_persists_new_token_fields(self):
        saved = []
        created_at = int(time.time())
        config = {
            "client_id": "client",
            "client_secret": "secret",
            "redirect_uri": "urn:ietf:wg:oauth:2.0:oob",
            "access_token": "old-access",
            "refresh_token": "old-refresh",
            "expires_at": created_at - 10,
        }
        request = FakeRequest(post_response=FakeResponse(payload={
            "access_token": "new-access",
            "refresh_token": "new-refresh",
            "expires_in": 604800,
            "created_at": created_at,
            "token_type": "bearer",
            "scope": "public",
        }))
        trakt = Trakt(config=config, config_saver=lambda cfg: saved.append(dict(cfg)), request=request)

        self.assertTrue(trakt.refresh_access_token())

        self.assertEqual(config["access_token"], "new-access")
        self.assertEqual(config["refresh_token"], "new-refresh")
        self.assertEqual(config["expires_at"], created_at + 604800)
        self.assertEqual(saved[-1]["access_token"], "new-access")
        self.assertEqual(request.posts[0]["json"]["grant_type"], "refresh_token")


class TraktWebActionTest(TestCase):
    def test_get_recommend_dispatches_trakt_movies(self):
        expected = [{"id": 11, "title": "Movie", "type": "MOV"}]
        action = object.__new__(WebAction)
        with patch("web.action.Trakt", create=True) as trakt_cls, \
                patch("web.action.FileTransfer") as filetransfer_cls:
            trakt_cls.return_value.get_movie_recommendations.return_value = expected
            filetransfer_cls.return_value.get_media_exists_flag.return_value = (False, "")

            result = action.get_recommend({
                "type": "TRAKT",
                "subtype": "movie",
                "page": 2,
                "params": {"ignore_watched": "true"}
            })

        trakt_cls.return_value.get_movie_recommendations.assert_called_once_with(
            page=2,
            params={"ignore_watched": "true"}
        )
        self.assertEqual(result["Items"], [{
            "id": 11,
            "title": "Movie",
            "type": "MOV",
            "fav": False,
            "rssid": ""
        }])

    def test_get_recommend_dispatches_trakt_shows(self):
        expected = [{"id": 22, "title": "Show", "type": "TV"}]
        action = object.__new__(WebAction)
        with patch("web.action.Trakt", create=True) as trakt_cls, \
                patch("web.action.FileTransfer") as filetransfer_cls:
            trakt_cls.return_value.get_show_recommendations.return_value = expected
            filetransfer_cls.return_value.get_media_exists_flag.return_value = (True, 7)

            result = action.get_recommend({
                "type": "TRAKT",
                "subtype": "show",
                "page": 1,
                "params": {}
            })

        trakt_cls.return_value.get_show_recommendations.assert_called_once_with(
            page=1,
            params={}
        )
        self.assertEqual(result["Items"], [{
            "id": 22,
            "title": "Show",
            "type": "TV",
            "fav": True,
            "rssid": 7
        }])
