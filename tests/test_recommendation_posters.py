# -*- coding: utf-8 -*-

from unittest import TestCase
from unittest.mock import Mock, patch
from urllib.parse import quote

from app.media.recommendation import hydrate_recommendation_posters


class RecommendationPosterHydrationTest(TestCase):
    def test_trakt_card_uses_tmdb_poster_when_source_image_missing(self):
        media = Mock()
        media.get_tmdb_info.return_value = {"poster_path": "/poster.jpg"}
        cards = [{
            "id": 123,
            "type": "MOV",
            "media_type": "电影",
            "title": "Movie",
            "year": "2026",
            "image": "",
            "site": "Trakt",
        }]

        hydrate_recommendation_posters(cards, source="trakt", media=media)

        self.assertEqual(cards[0]["image"], "https://image.tmdb.org/t/p/w500/poster.jpg")
        media.get_tmdb_info.assert_called_once()

    def test_trakt_card_keeps_existing_source_image(self):
        media = Mock()
        cards = [{
            "id": 123,
            "type": "MOV",
            "media_type": "电影",
            "title": "Movie",
            "year": "2026",
            "image": "https://trakt.example/poster.jpg",
            "site": "Trakt",
        }]

        hydrate_recommendation_posters(cards, source="trakt", media=media)

        self.assertEqual(cards[0]["image"], "https://trakt.example/poster.jpg")
        media.get_tmdb_info.assert_not_called()

    def test_trakt_card_uses_tmdb_web_poster_when_api_lookup_missing(self):
        media = Mock()
        media.get_tmdb_info.return_value = None
        response = Mock(status_code=200)
        response.text = (
            '<html><head>'
            '<meta property="og:image" '
            'content="https://media.themoviedb.org/t/p/w500/fallback.jpg">'
            '</head></html>'
        )
        cards = [{
            "id": 987654321,
            "type": "MOV",
            "media_type": "电影",
            "title": "Movie",
            "year": "2026",
            "image": "",
            "site": "Trakt",
        }]

        with patch("app.media.recommendation.RequestUtils") as request_utils:
            request_utils.return_value.get_res.return_value = response

            hydrate_recommendation_posters(cards, source="trakt", media=media)

        self.assertEqual(cards[0]["image"], "https://media.themoviedb.org/t/p/w500/fallback.jpg")
        media.get_tmdb_info.assert_called_once()

    def test_douban_card_uses_strict_tmdb_match_when_available(self):
        media = Mock()
        media.get_media_info.return_value = Mock(
            tmdb_id=456,
            poster_path="https://image.tmdb.org/t/p/w500/douban.jpg",
        )
        cards = [{
            "id": "DB:1",
            "type": "MOV",
            "media_type": "电影",
            "title": "Douban Movie",
            "year": "2026",
            "image": "https://douban.example/poster.jpg",
        }]

        hydrate_recommendation_posters(cards, source="douban", media=media)

        self.assertEqual(cards[0]["image"], "https://image.tmdb.org/t/p/w500/douban.jpg")
        self.assertEqual(cards[0]["tmdbid"], 456)
        media.get_media_info.assert_called_once()

    def test_douban_card_keeps_source_image_when_strict_match_missing(self):
        media = Mock()
        media.get_media_info.return_value = None
        cards = [{
            "id": "DB:1",
            "type": "MOV",
            "media_type": "电影",
            "title": "Douban Movie",
            "year": "2026",
            "image": "https://douban.example/poster.jpg",
        }]

        hydrate_recommendation_posters(cards, source="douban", media=media)

        self.assertEqual(cards[0]["image"], "https://douban.example/poster.jpg")
        self.assertNotIn("tmdbid", cards[0])

    def test_douban_card_proxies_douban_image_when_strict_match_missing(self):
        media = Mock()
        media.get_media_info.return_value = None
        image_url = "https://img3.doubanio.com/view/photo/m_ratio_poster/public/p2932533733.webp"
        cards = [{
            "id": "DB:1",
            "type": "MOV",
            "media_type": "电影",
            "title": "Douban Movie",
            "year": "2026",
            "image": image_url,
        }]

        hydrate_recommendation_posters(cards, source="douban", media=media)

        self.assertEqual(cards[0]["image"], "/douban/image?url=%s" % quote(image_url, safe=""))
        self.assertNotIn("tmdbid", cards[0])
