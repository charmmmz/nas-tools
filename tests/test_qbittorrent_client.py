from unittest import TestCase

from app.downloader.client.qbittorrent import Qbittorrent


class FakeQbittorrentApiClient:
    def __init__(self, response):
        self.response = response
        self.kwargs = None

    def torrents_add(self, **kwargs):
        self.kwargs = kwargs
        return self.response


class QbittorrentClientTest(TestCase):
    def build_client(self, response):
        client = object.__new__(Qbittorrent)
        client.qbc = FakeQbittorrentApiClient(response)
        client._auto_management = False
        return client

    def test_add_torrent_accepts_legacy_ok_response(self):
        self.assertTrue(self.build_client("Ok.").add_torrent("magnet:?xt=urn:btih:test"))

    def test_add_torrent_accepts_empty_success_response(self):
        self.assertTrue(self.build_client("").add_torrent("magnet:?xt=urn:btih:test"))

    def test_add_torrent_rejects_explicit_failure_response(self):
        self.assertFalse(self.build_client("Fails.").add_torrent("magnet:?xt=urn:btih:test"))

