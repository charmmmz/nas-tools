# -*- coding: utf-8 -*-

DEFAULT_REMOTE_SEARCH_THREADS = 5
DEFAULT_TORZNAB_SEARCH_TIMEOUT = 10
REMOTE_INDEXER_TYPES = {"jackett", "prowlarr"}


def _type_value(client_type):
    return str(getattr(client_type, "value", client_type) or "").lower()


def _positive_int(value, default):
    try:
        value = int(value)
    except (TypeError, ValueError):
        return default
    return value if value > 0 else default


def resolve_search_workers(indexer_count, client_type, client_config=None):
    if indexer_count <= 0:
        return 0
    if _type_value(client_type) not in REMOTE_INDEXER_TYPES:
        return indexer_count

    client_config = client_config or {}
    configured_workers = _positive_int(
        client_config.get("search_threads"),
        DEFAULT_REMOTE_SEARCH_THREADS
    )
    return max(1, min(indexer_count, configured_workers))


def resolve_torznab_timeout(client_config=None):
    client_config = client_config or {}
    return _positive_int(
        client_config.get("search_timeout"),
        DEFAULT_TORZNAB_SEARCH_TIMEOUT
    )
