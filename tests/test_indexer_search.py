# -*- coding: utf-8 -*-

from unittest import TestCase

from app import indexer_search_config


class IndexerSearchTest(TestCase):
    def test_remote_indexer_default_workers_are_capped(self):
        workers = indexer_search_config.resolve_search_workers(
            indexer_count=20,
            client_type="JACKETT",
            client_config={}
        )

        self.assertEqual(5, workers)

    def test_remote_indexer_workers_use_config_without_exceeding_indexer_count(self):
        workers = indexer_search_config.resolve_search_workers(
            indexer_count=3,
            client_type="PROWLARR",
            client_config={"search_threads": "8"}
        )

        self.assertEqual(3, workers)

    def test_builtin_indexer_keeps_full_parallelism(self):
        workers = indexer_search_config.resolve_search_workers(
            indexer_count=12,
            client_type="BUILTIN",
            client_config={}
        )

        self.assertEqual(12, workers)

    def test_torznab_timeout_uses_config_with_default(self):
        self.assertEqual(10, indexer_search_config.resolve_torznab_timeout({}))
        self.assertEqual(25, indexer_search_config.resolve_torznab_timeout({"search_timeout": "25"}))

    def test_torznab_limit_uses_pt_site_search_result_num(self):
        self.assertEqual(100, indexer_search_config.resolve_torznab_limit({}))
        self.assertEqual(50, indexer_search_config.resolve_torznab_limit({"site_search_result_num": "50"}))

    def test_media_name_match_rejects_obvious_different_titles(self):
        self.assertFalse(
            indexer_search_config.is_probable_same_media_name("Pretty Obsession", ["Obsession"])
        )

    def test_media_name_match_accepts_punctuation_variants(self):
        self.assertTrue(
            indexer_search_config.is_probable_same_media_name(
                "Puss in Boots The Last Wish",
                ["Puss in Boots: The Last Wish"]
            )
        )

    def test_media_name_match_allows_different_scripts_for_tmdb_lookup(self):
        self.assertTrue(
            indexer_search_config.is_probable_same_media_name("Obsession", ["迷恋"])
        )
