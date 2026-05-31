# -*- coding: utf-8 -*-

import json
import time

from flask import request

try:
    from flask_sock import Sock
except ImportError:
    Sock = None

try:
    from simple_websocket.errors import ConnectionClosed
except ImportError:
    class ConnectionClosed(Exception):
        pass


DOWNLOADS_WS_PATH = "/api/v1/mobile/downloads/ws"
DOWNLOADS_SNAPSHOT_TYPE = "downloads.snapshot"
DEFAULT_DOWNLOADS_WS_INTERVAL = 3
MIN_DOWNLOADS_WS_INTERVAL = 2
MAX_DOWNLOADS_WS_INTERVAL = 30
HEARTBEAT_INTERVAL = 30

sock = Sock() if Sock else None


def parse_downloads_ws_interval(value):
    """
    Parse the client-requested snapshot interval and keep it NAS-friendly.
    """
    if value is None:
        return DEFAULT_DOWNLOADS_WS_INTERVAL
    try:
        interval = float(value)
    except (TypeError, ValueError):
        return DEFAULT_DOWNLOADS_WS_INTERVAL
    return min(max(interval, MIN_DOWNLOADS_WS_INTERVAL), MAX_DOWNLOADS_WS_INTERVAL)


def build_downloads_snapshot(action=None):
    """
    Reuse the existing mobile/web downloading response shape.
    """
    if action is None:
        from web.action import WebAction
        action = WebAction()
    return {
        "type": DOWNLOADS_SNAPSHOT_TYPE,
        "data": action.get_downloading()
    }


def encode_ws_message(message):
    return json.dumps(message, ensure_ascii=False, separators=(",", ":"))


def is_websocket_authorized():
    from app.utils import TokenCache
    from web.security import generate_access_token, identify

    token = request.headers.get("Authorization", default=None) or request.args.get("token", default=None)
    if not token:
        return False
    token = str(token).split()[-1]
    latest_token = TokenCache.get(token)
    if not latest_token:
        return False
    flag, username = identify(latest_token)
    if not username:
        return False
    if not flag:
        TokenCache.set(token, generate_access_token(username))
    return True


def register_mobile_websocket(app):
    if not sock:
        import log
        log.warn("【Mobile】WebSocket 未启用：缺少 Flask-Sock 依赖")
        return None
    sock.init_app(app)
    return sock


if sock:
    @sock.route(DOWNLOADS_WS_PATH)
    def mobile_downloads_ws(ws):
        if not is_websocket_authorized():
            ws.send(encode_ws_message({
                "type": "error",
                "code": 403,
                "message": "安全认证未通过，请检查Token"
            }))
            ws.close()
            return

        interval = parse_downloads_ws_interval(request.args.get("interval"))
        last_snapshot = None
        last_sent_at = 0

        while True:
            try:
                now = time.monotonic()
                snapshot = encode_ws_message(build_downloads_snapshot())
                if snapshot != last_snapshot:
                    ws.send(snapshot)
                    last_snapshot = snapshot
                    last_sent_at = now
                elif now - last_sent_at >= HEARTBEAT_INTERVAL:
                    ws.send(last_snapshot)
                    last_sent_at = now
                time.sleep(interval)
            except (ConnectionClosed, BrokenPipeError, ConnectionResetError):
                return
            except Exception as err:
                import log
                log.error("【Mobile】下载进度 WebSocket 推送失败：%s" % str(err))
                return
