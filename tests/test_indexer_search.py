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
