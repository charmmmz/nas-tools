# -*- coding: utf-8 -*-

from unittest import TestCase
from unittest.mock import Mock, patch
from urllib.parse import quote

from web.main import App


class DoubanImageProxyTest(TestCase):
    def setUp(self):
        App.config["TESTING"] = True
        self.client = App.test_client()

    def test_douban_image_proxy_adds_douban_referer(self):
        image_url = "https://img3.doubanio.com/view/photo/m_ratio_poster/public/p2932533733.webp"
        upstream = Mock(status_code=200,
                        content=b"image-bytes",
                        headers={"content-type": "image/webp"})

        with patch("web.main.RequestUtils") as request_utils:
            request_utils.return_value.get_res.return_value = upstream

            response = self.client.get("/douban/image?url=%s" % quote(image_url, safe=""))

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data, b"image-bytes")
        self.assertEqual(response.headers.get("content-type"), "image/webp")
        request_utils.assert_called_once()
        self.assertEqual(request_utils.call_args.kwargs["headers"]["Referer"],
                         "https://movie.douban.com/")
        request_utils.return_value.get_res.assert_called_once_with(url=image_url)

    def test_douban_image_proxy_rejects_non_douban_hosts(self):
        image_url = "https://example.com/poster.webp"

        with patch("web.main.RequestUtils") as request_utils:
            response = self.client.get("/douban/image?url=%s" % quote(image_url, safe=""))

        self.assertEqual(response.status_code, 400)
        request_utils.assert_not_called()
