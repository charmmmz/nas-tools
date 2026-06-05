# -*- coding: utf-8 -*-

import json
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
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
__POSTER_CACHE = {}
__POSTER_CACHE_MAXSIZE = 2048
__POSTER_CACHE_TYPE = "RecommendationPosterCache"


def hydrate_recommendation_posters(cards, source, media=None):
    """
    为推荐卡片补充更稳定的海报图，保持原有卡片结构不变。
    """
    if not cards:
        return cards

    service = RecommendationService(media_factory=lambda: media or Media(),
                                    poster_cache=ProcessPosterCache(),
                                    max_workers=1)
    hydrated_cards = service.normalize_items(cards, source=source)
    for index, card in enumerate(cards):
        if isinstance(card, dict) and index < len(hydrated_cards):
            card.update(hydrated_cards[index])
    return cards


def clear_recommendation_poster_cache():
    __POSTER_CACHE.clear()


class ProcessPosterCache:
    def get(self, key):
        return globals()["__POSTER_CACHE"].get(key)

    def set(self, key, value):
        if not key or not value:
            return
        poster_cache = globals()["__POSTER_CACHE"]
        if len(poster_cache) >= globals()["__POSTER_CACHE_MAXSIZE"]:
            poster_cache.pop(next(iter(poster_cache)))
        poster_cache[key] = value

    def clear(self):
        globals()["__POSTER_CACHE"].clear()


class RecommendationPosterCache:
    def __init__(self, dict_helper=None):
        if dict_helper:
            self._dict_helper = dict_helper
        else:
            from app.helper import DictHelper
            self._dict_helper = DictHelper()

    def get(self, key):
        if not key:
            return None
        value = self._dict_helper.get(__POSTER_CACHE_TYPE, key)
        if not value:
            return None
        try:
            return json.loads(value)
        except (TypeError, ValueError):
            return None

    def set(self, key, value):
        if not key or not value:
            return
        self._dict_helper.set(__POSTER_CACHE_TYPE,
                              key,
                              json.dumps(value, ensure_ascii=False))

    def clear(self):
        ProcessPosterCache().clear()


class RecommendationService:
    def __init__(self,
                 media_factory=None,
                 douban_factory=None,
                 trakt_factory=None,
                 bangumi_factory=None,
                 filetransfer_factory=None,
                 search_provider=None,
                 downloaded_provider=None,
                 poster_cache=None,
                 max_workers=4):
        self._media_factory = media_factory or Media
        self._douban_factory = douban_factory or self.__default_douban
        self._trakt_factory = trakt_factory or self.__default_trakt
        self._bangumi_factory = bangumi_factory or self.__default_bangumi
        self._filetransfer_factory = filetransfer_factory or self.__default_filetransfer
        self._search_provider = search_provider or self.__default_search_provider
        self._downloaded_provider = downloaded_provider
        self._poster_cache = poster_cache or RecommendationPosterCache()
        self._max_workers = max(1, int(max_workers or 1))

    @staticmethod
    def __default_douban():
        from app.media import DouBan
        return DouBan()

    @staticmethod
    def __default_trakt():
        from app.media import Trakt
        return Trakt()

    @staticmethod
    def __default_bangumi():
        from app.media import Bangumi
        return Bangumi()

    @staticmethod
    def __default_filetransfer():
        from app.filetransfer import FileTransfer
        return FileTransfer()

    @staticmethod
    def __default_search_provider(keyword, source, page):
        from web.backend.web_utils import WebUtils
        return [media.to_dict() for media in WebUtils.search_media_infos(
            keyword=keyword,
            source=source,
            page=page
        )]

    def get_recommend(self, data):
        data = data or {}
        recommend_type = data.get("type")
        subtype = data.get("subtype")
        page = int(data.get("page") or 1)
        items, source = self.__fetch_items(data=data,
                                           recommend_type=recommend_type,
                                           subtype=subtype,
                                           page=page)
        items = self.normalize_items(items, source=source)
        self.__append_library_state(items, fallback_type=recommend_type)
        return {"code": 0, "Items": items}

    def normalize_items(self, items, source=""):
        source = (source or "").lower()
        normalized = [
            self.__normalize_card(item, source=source)
            for item in (items or [])
            if isinstance(item, dict)
        ]
        self.__hydrate_posters(normalized, source=source)
        return normalized

    def __fetch_items(self, data, recommend_type, subtype, page):
        poster_source = ""
        result = []
        media = self._media_factory()
        if recommend_type in ["MOV", "TV"]:
            result, poster_source = self.__fetch_movie_tv_items(media=media,
                                                                subtype=subtype,
                                                                page=page,
                                                                data=data)
        elif recommend_type == "SEARCH":
            result = self._search_provider(data.get("keyword"),
                                           data.get("source"),
                                           page)
        elif recommend_type == "DOWNLOADED":
            if self._downloaded_provider:
                result = self._downloaded_provider(page) or []
        elif recommend_type == "TRENDING":
            result = media.get_tmdb_trending_all_week(page=page)
        elif recommend_type == "DISCOVER":
            mtype = MediaType.MOVIE if subtype in ["MOV", MediaType.MOVIE.value] else MediaType.TV
            result = media.get_tmdb_discover(mtype=mtype,
                                             page=page,
                                             params=data.get("params") or {})
        elif recommend_type == "DOUBANTAG":
            mtype = MediaType.MOVIE if subtype in ["MOV", MediaType.MOVIE.value] else MediaType.TV
            params = data.get("params") or {}
            result = self._douban_factory().get_douban_disover(
                mtype=mtype,
                sort=params.get("sort") or "T",
                tags=params.get("tags") or "",
                page=page
            )
            poster_source = "douban"
        elif recommend_type == "TRAKT":
            params = data.get("params") or {}
            trakt = self._trakt_factory()
            if subtype == "movie":
                result = trakt.get_movie_recommendations(page=page, params=params)
            elif subtype == "show":
                result = trakt.get_show_recommendations(page=page, params=params)
            poster_source = "trakt"
        return result or [], poster_source

    def __fetch_movie_tv_items(self, media, subtype, page, data):
        douban = None
        source = ""
        if subtype == "hm":
            return media.get_tmdb_hot_movies(page), source
        if subtype == "ht":
            return media.get_tmdb_hot_tvs(page), source
        if subtype == "nm":
            return media.get_tmdb_new_movies(page), source
        if subtype == "nt":
            return media.get_tmdb_new_tvs(page), source
        if subtype == "sim":
            tmdbid = data.get("tmdbid")
            if not tmdbid:
                return [], source
            if data.get("type") == "MOV":
                return media.get_movie_similar(tmdbid=tmdbid, page=page), source
            return media.get_tv_similar(tmdbid=tmdbid, page=page), source
        if subtype == "more":
            tmdbid = data.get("tmdbid")
            if not tmdbid:
                return [], source
            if data.get("type") == "MOV":
                return media.get_movie_recommendations(tmdbid=tmdbid, page=page), source
            return media.get_tv_recommendations(tmdbid=tmdbid, page=page), source
        if subtype == "person":
            personid = data.get("personid")
            if not personid:
                return [], source
            mtype = MediaType.MOVIE if data.get("type") == "MOV" else MediaType.TV
            return media.get_person_medias(personid=personid, mtype=mtype, page=page), source
        if subtype == "bangumi":
            return self._bangumi_factory().get_bangumi_calendar(page=page,
                                                                week=data.get("week")), source
        douban_subtypes = {
            "dbom": "get_douban_online_movie",
            "dbhm": "get_douban_hot_movie",
            "dbht": "get_douban_hot_tv",
            "dbdh": "get_douban_hot_anime",
            "dbnm": "get_douban_new_movie",
            "dbtop": "get_douban_top250_movie",
            "dbzy": "get_douban_hot_show",
            "dbct": "get_douban_chinese_weekly_tv",
            "dbgt": "get_douban_weekly_tv_global"
        }
        method_name = douban_subtypes.get(subtype)
        if method_name:
            douban = douban or self._douban_factory()
            return getattr(douban, method_name)(page), "douban"
        return [], source

    def __normalize_card(self, item, source):
        card = dict(item)
        mtype = _card_media_type(card)
        source_id = card.get("source_id") or card.get("id") or ""
        source_image = card.get("source_image") or card.get("image") or ""
        if mtype == MediaType.MOVIE:
            card["type"] = "MOV"
            card["media_type"] = MediaType.MOVIE.value
        elif mtype == MediaType.TV:
            card["type"] = "TV"
            card["media_type"] = MediaType.TV.value
        card["source"] = source
        card["source_id"] = str(source_id)
        card["source_image"] = source_image
        if source and not card.get("site"):
            card["site"] = "Trakt" if source == "trakt" else "豆瓣" if source == "douban" else source
        if source == "trakt" and _is_numeric_id(card.get("id")) and not card.get("tmdbid"):
            card["tmdbid"] = int(card.get("id"))
        if card.get("tmdb_id") and not card.get("tmdbid"):
            card["tmdbid"] = card.get("tmdb_id")
        if not card.get("orgid"):
            card["orgid"] = source_id
        card["year"] = str(card.get("year") or "")
        return card

    def __hydrate_posters(self, cards, source):
        if source not in ("trakt", "douban") or not cards:
            return
        if self._max_workers == 1 or len(cards) == 1:
            for card in cards:
                self.__hydrate_one_poster(card, source=source)
            return
        with ThreadPoolExecutor(max_workers=min(self._max_workers, len(cards))) as executor:
            futures = {
                executor.submit(self.__hydrate_one_poster, card, source): card
                for card in cards
            }
            for future in as_completed(futures):
                try:
                    future.result()
                except Exception as err:
                    log.warn("【Recommend】补充海报失败：%s" % err)

    def __hydrate_one_poster(self, card, source):
        try:
            if source == "trakt":
                self.__hydrate_trakt_poster(card)
            elif source == "douban":
                self.__hydrate_douban_poster(card)
        except Exception as err:
            log.warn("【Recommend】补充海报失败：%s" % err)

    def __hydrate_trakt_poster(self, card):
        tmdbid = card.get("tmdbid") or card.get("id")
        if not _is_numeric_id(tmdbid):
            return
        tmdbid = int(tmdbid)
        mtype = _card_media_type(card)
        cache_key = _poster_cache_key(source="trakt", mtype=mtype, media_id=tmdbid)
        if self.__apply_cached_poster(card, cache_key):
            return
        tmdbinfo = self._media_factory().get_tmdb_info(mtype=mtype, tmdbid=tmdbid)
        poster_url = _tmdb_poster_url((tmdbinfo or {}).get("poster_path"))
        if not poster_url:
            poster_url = _get_tmdb_web_poster(mtype=mtype, tmdbid=tmdbid)
        if poster_url:
            card["image"] = poster_url
            card["tmdbid"] = tmdbid
            self.__set_cached_poster(cache_key, {
                "image": poster_url,
                "tmdbid": tmdbid
            })

    def __hydrate_douban_poster(self, card):
        title = card.get("title")
        year = card.get("year")
        mtype = _card_media_type(card)
        if not title or not year or not mtype:
            _proxy_douban_image(card)
            return
        cache_key = _poster_cache_key(source="douban", mtype=mtype, media_id="%s:%s" % (title, year))
        if self.__apply_cached_poster(card, cache_key):
            return
        media_info = self._media_factory().get_media_info(title="%s %s" % (title, year),
                                                          mtype=mtype,
                                                          strict=True)
        if not media_info or not _is_numeric_id(getattr(media_info, "tmdb_id", None)):
            _proxy_douban_image(card)
            return
        poster_url = _tmdb_poster_url(getattr(media_info, "poster_path", ""))
        if not poster_url:
            _proxy_douban_image(card)
            return
        card["image"] = poster_url
        card["tmdbid"] = getattr(media_info, "tmdb_id")
        self.__set_cached_poster(cache_key, {
            "image": card["image"],
            "tmdbid": card["tmdbid"]
        })

    def __apply_cached_poster(self, card, cache_key):
        cached = self._poster_cache.get(cache_key)
        if not cached:
            return False
        if isinstance(cached, str):
            cached = {"image": cached}
        if cached.get("image"):
            card["image"] = cached.get("image")
        if cached.get("tmdbid"):
            card["tmdbid"] = cached.get("tmdbid")
        return bool(cached.get("image"))

    def __set_cached_poster(self, cache_key, value):
        if isinstance(value, dict):
            value = dict(value)
            value.setdefault("updated_at", int(time.time()))
        self._poster_cache.set(cache_key, value)

    def __append_library_state(self, cards, fallback_type):
        if not cards:
            return
        filetransfer = self._filetransfer_factory()
        for card in cards:
            fav, rssid = filetransfer.get_media_exists_flag(
                mtype=card.get("type") or fallback_type,
                title=card.get("title"),
                year=card.get("year"),
                mediaid=card.get("tmdbid") or card.get("id")
            )
            card.update({
                "fav": fav,
                "rssid": rssid
            })


def _card_media_type(card):
    card_type = card.get("type")
    if card_type == "MOV" or card.get("media_type") == MediaType.MOVIE.value:
        return MediaType.MOVIE
    if card_type == "TV" or card.get("media_type") == MediaType.TV.value:
        return MediaType.TV
    return None


def _is_numeric_id(value):
    try:
        int(value)
        return True
    except (TypeError, ValueError):
        return False


def _poster_cache_key(source, mtype, media_id):
    return "poster:%s:%s:%s" % (source or "", getattr(mtype, "value", mtype) or "", media_id or "")


def _tmdb_poster_url(poster_path):
    if not poster_path:
        return ""
    if str(poster_path).startswith("http"):
        return poster_path
    return TMDB_IMAGE_W500_URL % poster_path


def __get_cached_poster(cache_key):
    return __POSTER_CACHE.get(cache_key)


def __set_cached_poster(cache_key, value):
    if not cache_key or not value:
        return
    if len(__POSTER_CACHE) >= __POSTER_CACHE_MAXSIZE:
        __POSTER_CACHE.pop(next(iter(__POSTER_CACHE)))
    __POSTER_CACHE[cache_key] = value


def _proxy_douban_image(card):
    image_url = card.get("image")
    if not _is_douban_image_url(image_url):
        return
    card["image"] = "%s?url=%s" % (__DOUBAN_IMAGE_PROXY_PATH, quote(image_url, safe=""))


def _is_douban_image_url(image_url):
    parsed = urlparse(image_url or "")
    hostname = parsed.hostname or ""
    return parsed.scheme in ("http", "https") \
        and hostname.endswith(".doubanio.com") \
        and parsed.path.startswith("/view/photo/")


@lru_cache(maxsize=512)
def _get_tmdb_web_poster(mtype, tmdbid):
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
    return _extract_tmdb_og_image(res.text)


def _extract_tmdb_og_image(html_text):
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


__card_media_type = _card_media_type
__is_numeric_id = _is_numeric_id
__poster_cache_key = _poster_cache_key
__proxy_douban_image = _proxy_douban_image
__is_douban_image_url = _is_douban_image_url
__get_tmdb_web_poster = _get_tmdb_web_poster
__extract_tmdb_og_image = _extract_tmdb_og_image
