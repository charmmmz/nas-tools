import time

from app.utils import RequestUtils
from app.utils.types import MediaType
from config import Config


class Trakt:
    _base_url = "https://api.trakt.tv"
    _api_version = "2"
    _page_num = 20
    _max_limit = 100
    _default_redirect_uri = "urn:ietf:wg:oauth:2.0:oob"

    def __init__(self, config=None, config_saver=None, request=None):
        self._request = request
        if config is None:
            self._root_config = Config().get_config()
            if not self._root_config.get("trakt"):
                self._root_config["trakt"] = {}
            self._config = self._root_config["trakt"]
            self._config_saver = None
        else:
            self._root_config = None
            self._config = config
            self._config_saver = config_saver

    @staticmethod
    def normalize_movie(item):
        return Trakt.__normalize_item(item=item,
                                      media_code="MOV",
                                      media_type=MediaType.MOVIE.value,
                                      date_key="released")

    @staticmethod
    def normalize_show(item):
        return Trakt.__normalize_item(item=item,
                                      media_code="TV",
                                      media_type=MediaType.TV.value,
                                      date_key="first_aired")

    @staticmethod
    def __normalize_item(item, media_code, media_type, date_key):
        if not item:
            return None
        ids = item.get("ids") or {}
        tmdb_id = ids.get("tmdb")
        if not tmdb_id:
            return None
        date_value = item.get(date_key) or ""
        return {
            "id": tmdb_id,
            "orgid": ids.get("trakt"),
            "title": item.get("title") or "",
            "year": item.get("year") or "",
            "type": media_code,
            "media_type": media_type,
            "vote": Trakt.__round_vote(item.get("rating")),
            "image": Trakt.__first_image(item.get("images")),
            "overview": item.get("overview") or "",
            "date": date_value[:10] if date_value else "",
            "site": "Trakt"
        }

    @staticmethod
    def __round_vote(value):
        if value is None or value == "":
            return ""
        try:
            return round(float(value), 1)
        except (TypeError, ValueError):
            return ""

    @staticmethod
    def __first_image(images):
        if not images:
            return ""
        posters = images.get("poster") or []
        return posters[0] if posters else ""

    def is_configured(self):
        return bool(self._config.get("client_id") and self._config.get("client_secret"))

    def is_authorized(self):
        return bool(self._config.get("access_token") and self._config.get("refresh_token"))

    def get_device_code(self):
        if not self._config.get("client_id"):
            return None
        resp = self.__post("/oauth/device/code", {
            "client_id": self._config.get("client_id")
        })
        if not resp or resp.status_code != 200:
            return None
        return resp.json()

    def poll_device_token(self, device_code):
        if not device_code or not self.is_configured():
            return False, None
        resp = self.__post("/oauth/device/token", {
            "code": device_code,
            "client_id": self._config.get("client_id"),
            "client_secret": self._config.get("client_secret")
        })
        if not resp or resp.status_code != 200:
            return False, resp.status_code if resp else None
        token_info = resp.json()
        self.__save_token_info(token_info)
        return True, token_info

    def refresh_access_token(self):
        if not self.is_configured() or not self._config.get("refresh_token"):
            return False
        resp = self.__post("/oauth/token", {
            "refresh_token": self._config.get("refresh_token"),
            "client_id": self._config.get("client_id"),
            "client_secret": self._config.get("client_secret"),
            "redirect_uri": self._config.get("redirect_uri") or self._default_redirect_uri,
            "grant_type": "refresh_token"
        })
        if not resp or resp.status_code != 200:
            return False
        self.__save_token_info(resp.json())
        return True

    def clear_authorization(self):
        self._config["access_token"] = ""
        self._config["refresh_token"] = ""
        self._config["expires_at"] = ""
        self.__save_config()

    def get_movie_recommendations(self, page=1, params=None):
        return self.__get_recommendations(kind="movies",
                                          page=page,
                                          params=params,
                                          normalizer=self.normalize_movie)

    def get_show_recommendations(self, page=1, params=None):
        return self.__get_recommendations(kind="shows",
                                          page=page,
                                          params=params,
                                          normalizer=self.normalize_show)

    def __get_recommendations(self, kind, page, params, normalizer):
        if not self.__ensure_authorized():
            return []
        page = int(page or 1)
        request_limit = min(max(page, 1) * self._page_num, self._max_limit)
        query = self.__recommendation_query(params=params, limit=request_limit)
        resp = self.__get("/recommendations/%s" % kind, query)
        if not resp or resp.status_code != 200:
            return []
        start_pos = (page - 1) * self._page_num
        end_pos = start_pos + self._page_num
        result = []
        for item in (resp.json() or [])[start_pos:end_pos]:
            card = normalizer(item)
            if card:
                result.append(card)
        return result

    def __recommendation_query(self, params, limit):
        query = {
            "extended": "full,images",
            "limit": limit
        }
        params = params or {}
        for key in ["ignore_watched", "ignore_collected", "ignore_watchlisted"]:
            if key in params and params.get(key) != "":
                query[key] = self.__as_bool(params.get(key))
        watch_window = params.get("watch_window")
        if watch_window:
            try:
                query["watch_window"] = int(watch_window)
            except (TypeError, ValueError):
                pass
        return query

    @staticmethod
    def __as_bool(value):
        if isinstance(value, bool):
            return value
        return str(value).lower() in ["1", "true", "yes", "on"]

    def __ensure_authorized(self):
        if not self.is_authorized():
            return False
        expires_at = self._config.get("expires_at")
        try:
            expires_at = int(expires_at)
        except (TypeError, ValueError):
            expires_at = 0
        if expires_at and expires_at <= int(time.time()) + 300:
            return self.refresh_access_token()
        return True

    def __save_token_info(self, token_info):
        created_at = token_info.get("created_at") or int(time.time())
        expires_in = token_info.get("expires_in") or 0
        self._config["access_token"] = token_info.get("access_token") or ""
        self._config["refresh_token"] = token_info.get("refresh_token") or ""
        self._config["expires_at"] = int(created_at) + int(expires_in)
        self.__save_config()

    def __save_config(self):
        if self._config_saver:
            self._config_saver(self._config)
        elif self._root_config is not None:
            Config().save_config(self._root_config)

    def __headers(self, auth=False):
        headers = {
            "Content-Type": "application/json",
            "trakt-api-version": self._api_version,
            "trakt-api-key": self._config.get("client_id") or ""
        }
        if auth and self._config.get("access_token"):
            headers["Authorization"] = "Bearer %s" % self._config.get("access_token")
        return headers

    def __request(self, auth=False):
        if self._request:
            return self._request
        return RequestUtils(headers=self.__headers(auth=auth),
                            proxies=Config().get_proxies())

    def __post(self, path, data):
        req = self.__request(auth=path.startswith("/recommendations"))
        return req.post_res(url=self.__url(path), json=data)

    def __get(self, path, params):
        req = self.__request(auth=True)
        return req.get_res(url=self.__url(path), params=params)

    def __url(self, path):
        if path.startswith("/oauth"):
            return "%s%s" % (self._base_url, path)
        return "%s%s" % (self._base_url, path)
