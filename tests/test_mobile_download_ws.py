# -*- coding: utf-8 -*-

from unittest import TestCase
from web.mobile_ws import build_downloads_snapshot, parse_downloads_ws_interval


class FakeWebAction:
    def get_downloading(self):
        return {
            "code": 0,
            "result": [{
                "id": "abc",
                "name": "Movie",
                "speed": "1 MB/s",
                "state": "Downloading",
                "progress": 42
            }]
        }


class MobileDownloadWebSocketTest(TestCase):
    def test_build_downloads_snapshot_wraps_existing_downloading_response(self):
        snapshot = build_downloads_snapshot(action=FakeWebAction())

        self.assertEqual(snapshot["type"], "downloads.snapshot")
        self.assertEqual(snapshot["data"]["code"], 0)
        self.assertEqual(snapshot["data"]["result"][0]["id"], "abc")

    def test_parse_downloads_ws_interval_clamps_values(self):
        self.assertEqual(parse_downloads_ws_interval(None), 3)
        self.assertEqual(parse_downloads_ws_interval("1"), 2)
        self.assertEqual(parse_downloads_ws_interval("8"), 8)
        self.assertEqual(parse_downloads_ws_interval("90"), 30)
        self.assertEqual(parse_downloads_ws_interval("bad"), 3)
