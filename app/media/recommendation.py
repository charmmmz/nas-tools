# -*- coding: utf-8 -*-

from functools import lru_cache
from urllib.parse import quote, urlparse

from lxml import etree

import log
from app.media.media import Media
from app.utils import RequestUtils
from app.utils.types import MediaType
from config import TMDB_IMAGE_W500_URL

__OG_IMAGE_XPATH = (
    "//meta[translate(@property, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', "
    "'abcdefghijklmnopqrstuvwxyz')='og:image']/@content"
)
__DOUBAN_IMAGE_PROXY_PATH = "/douban/image"


def hydrate_recommendation_posters(cards, source, media=None):
    """
    为推荐卡片补充更稳定的海报图，保持原有卡片结构不变。
    """
    if not cards:
        return cards

    media = media or Media()
    source = (source or "").lower()
    for card in cards:
        if not isinstance(card, dict):
            continue
        try:
            if source == "trakt":
                __hydrate_trakt_poster(card, media)
            elif source == "douban":
                __hydrate_douban_poster(card, media)
        except Exception as err:
            log.warn("【Recommend】补充海报失败：%s" % err)
    return cards


def __hydrate_trakt_poster(card, media):
    tmdbid = card.get("tmdbid") or card.get("id")
    if not __is_numeric_id(tmdbid):
        return
    mtype = __card_media_type(card)
    tmdbinfo = media.get_tmdb_info(mtype=mtype, tmdbid=tmdbid)
    poster_path = (tmdbinfo or {}).get("poster_path")
    if poster_path:
        card["image"] = TMDB_IMAGE_W500_URL % poster_path
        return
    poster_url = __get_tmdb_web_poster(mtype=mtype, tmdbid=tmdbid)
    if poster_url:
        card["image"] = poster_url


def __hydrate_douban_poster(card, media):
    if not card.get("site"):
        card["site"] = "豆瓣"
    title = card.get("title")
    year = card.get("year")
    mtype = __card_media_type(card)
    if not title or not year or not mtype:
        __proxy_douban_image(card)
        return
    media_info = media.get_media_info(title="%s %s" % (title, year),
                                      mtype=mtype,
                                      strict=True)
    if not media_info or not __is_numeric_id(getattr(media_info, "tmdb_id", None)):
        __proxy_douban_image(card)
        return
    poster_path = getattr(media_info, "poster_path", "")
    if not poster_path:
        __proxy_douban_image(card)
        return
    card["image"] = poster_path
    card["tmdbid"] = media_info.tmdb_id


def __card_media_type(card):
    card_type = card.get("type")
    if card_type == "MOV" or card.get("media_type") == MediaType.MOVIE.value:
        return MediaType.MOVIE
    if card_type == "TV" or card.get("media_type") == MediaType.TV.value:
        return MediaType.TV
    return None


def __is_numeric_id(value):
    try:
        int(value)
        return True
    except (TypeError, ValueError):
        return False


def __proxy_douban_image(card):
    image_url = card.get("image")
    if not __is_douban_image_url(image_url):
        return
    card["image"] = "%s?url=%s" % (__DOUBAN_IMAGE_PROXY_PATH, quote(image_url, safe=""))


def __is_douban_image_url(image_url):
    parsed = urlparse(image_url or "")
    hostname = parsed.hostname or ""
    return parsed.scheme in ("http", "https") \
        and hostname.endswith(".doubanio.com") \
        and parsed.path.startswith("/view/photo/")


@lru_cache(maxsize=512)
def __get_tmdb_web_poster(mtype, tmdbid):
    if mtype == MediaType.MOVIE:
        media_path = "movie"
    elif mtype == MediaType.TV:
        media_path = "tv"
    else:
        return ""

    res = RequestUtils(timeout=5).get_res(
        url="https://www.themoviedb.org/%s/%s" % (media_path, int(tmdbid))
    )
    if not res or res.status_code != 200 or not res.text:
        return ""
    return __extract_tmdb_og_image(res.text)


def __extract_tmdb_og_image(html_text):
    if not html_text:
        return ""
    html = etree.HTML(html_text)
    if html is None:
        return ""
    images = html.xpath(__OG_IMAGE_XPATH)
    if not images:
        return ""
    return images[0].replace("https://media.themoviedb.org/t/p/",
                             "https://image.tmdb.org/t/p/")
