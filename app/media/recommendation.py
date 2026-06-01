# -*- coding: utf-8 -*-

import log
from app.media.media import Media
from app.utils.types import MediaType
from config import TMDB_IMAGE_W500_URL


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
    if card.get("image"):
        return
    tmdbid = card.get("tmdbid") or card.get("id")
    if not __is_numeric_id(tmdbid):
        return
    tmdbinfo = media.get_tmdb_info(mtype=__card_media_type(card), tmdbid=tmdbid)
    poster_path = (tmdbinfo or {}).get("poster_path")
    if poster_path:
        card["image"] = TMDB_IMAGE_W500_URL % poster_path


def __hydrate_douban_poster(card, media):
    if not card.get("site"):
        card["site"] = "豆瓣"
    title = card.get("title")
    year = card.get("year")
    mtype = __card_media_type(card)
    if not title or not year or not mtype:
        return
    media_info = media.get_media_info(title="%s %s" % (title, year),
                                      mtype=mtype,
                                      strict=True)
    if not media_info or not __is_numeric_id(getattr(media_info, "tmdb_id", None)):
        return
    poster_path = getattr(media_info, "poster_path", "")
    if not poster_path:
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
