# -*- coding: utf-8 -*-

from unittest import TestCase
from unittest.mock import Mock, patch

from app.media.media import Media
from app.utils.types import MediaType


class TmdbLanguageTest(TestCase):
    def test_tmdb_info_uses_configured_language_when_language_missing(self):
        media = Media.__new__(Media)
        media.tmdb = Mock()
        media._Media__get_tmdb_movie_detail = Mock(return_value={
            "id": 1,
            "title": "Movie",
            "genres": [],
        })
        media._Media__get_genre_ids_from_detail = Mock(return_value=[])

        with patch("app.media.media.Config") as config_cls:
            config_cls.return_value.get_config.return_value = {"tmdb_language": "en-US"}

            media.get_tmdb_info(mtype=MediaType.MOVIE,
                                tmdbid=1,
                                chinese=False)

        self.assertEqual(media.tmdb.language, "en-US")

    def test_tmdb_info_keeps_explicit_language_over_config(self):
        media = Media.__new__(Media)
        media.tmdb = Mock()
        media._Media__get_tmdb_movie_detail = Mock(return_value={
            "id": 1,
            "title": "Movie",
            "genres": [],
        })
        media._Media__get_genre_ids_from_detail = Mock(return_value=[])

        with patch("app.media.media.Config") as config_cls:
            config_cls.return_value.get_config.return_value = {"tmdb_language": "en-US"}

            media.get_tmdb_info(mtype=MediaType.MOVIE,
                                tmdbid=1,
                                language="ja-JP",
                                chinese=False)

        self.assertEqual(media.tmdb.language, "ja-JP")
