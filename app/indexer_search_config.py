# -*- coding: utf-8 -*-

import difflib
import re

DEFAULT_REMOTE_SEARCH_THREADS = 5
DEFAULT_TORZNAB_SEARCH_TIMEOUT = 10
DEFAULT_TORZNAB_SEARCH_LIMIT = 100
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


def resolve_torznab_limit(pt_config=None):
    pt_config = pt_config or {}
    return _positive_int(
        pt_config.get("site_search_result_num"),
        DEFAULT_TORZNAB_SEARCH_LIMIT
    )


def _normalize_media_name(name):
    if not name:
        return ""
    name = str(name).lower()
    name = re.sub(r"[\u200B-\u200D\uFEFF]", "", name)
    name = re.sub(r"['’\"“”]", "", name)
    name = re.sub(r"[^0-9a-z\u4e00-\u9fff]+", " ", name)
    name = re.sub(r"\b(the|a|an)\b", " ", name)
    return re.sub(r"\s+", " ", name).strip()


def is_probable_same_media_name(candidate_name, target_names):
    candidate = _normalize_media_name(candidate_name)
    targets = [_normalize_media_name(name) for name in target_names or []]
    targets = [name for name in targets if name]
    if not candidate or not targets:
        return True

    candidate_has_word = bool(re.search(r"[0-9a-z]", candidate))
    candidate_has_cjk = bool(re.search(r"[\u4e00-\u9fff]", candidate))
    comparable_targets = [
        target for target in targets
        if (candidate_has_word and re.search(r"[0-9a-z]", target))
        or (candidate_has_cjk and re.search(r"[\u4e00-\u9fff]", target))
    ]
    if not comparable_targets:
        return True

    compact_candidate = candidate.replace(" ", "")
    for target in comparable_targets:
        compact_target = target.replace(" ", "")
        if compact_candidate == compact_target:
            return True
        if difflib.SequenceMatcher(None, candidate, target).ratio() >= 0.9:
            return True
    return False
