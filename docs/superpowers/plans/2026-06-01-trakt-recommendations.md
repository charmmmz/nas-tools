# Trakt Recommendations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Trakt OAuth device authorization and personalized movie/TV recommendation lists to NASTOOL.

**Architecture:** Add a focused Trakt client under `app/media` and keep Trakt-specific HTTP, token refresh, and response normalization out of `web/action.py`. Extend existing recommendation dispatch, settings pages, discovery navigation, and filter config without changing the current card or subscription components.

**Tech Stack:** Python, Flask/Jinja templates, existing `Config` YAML storage, existing `RequestUtils`, unittest/pytest-compatible tests, Lit-based existing frontend components.

---

## File Structure

- Create `app/media/trakt.py`: Trakt API client, OAuth token handling, recommendation normalization.
- Modify `app/media/__init__.py`: export `Trakt`.
- Create `tests/test_trakt.py`: unit tests for normalization and token refresh.
- Modify `web/action.py`: add Trakt web actions and recommendation dispatch.
- Modify `config/config.yaml`: add default `trakt` config node.
- Modify `web/main.py`: add `/trakt` settings route.
- Create `web/templates/setting/trakt.html`: Trakt configuration and authorization UI.
- Modify `web/static/components/layout/navbar/index.js`: add Trakt discovery and settings navigation entries.
- Modify `app/conf/moduleconf.py`: add Trakt recommendation filter config.

## Task 1: Trakt Client Tests And Implementation

**Files:**
- Create: `tests/test_trakt.py`
- Create: `app/media/trakt.py`
- Modify: `app/media/__init__.py`

- [ ] **Step 1: Write failing tests**

Add tests that instantiate `Trakt(config=..., request=...)`, normalize movie/show payloads, skip missing TMDB IDs, and refresh an expiring token.

- [ ] **Step 2: Run tests to verify they fail**

Run: `python -m unittest tests.test_trakt -v`

Expected: FAIL because `app.media.trakt` does not exist.

- [ ] **Step 3: Implement minimal Trakt client**

Create `Trakt` with `normalize_movie`, `normalize_show`, `get_movie_recommendations`, `get_show_recommendations`, `get_device_code`, `poll_device_token`, `refresh_access_token`, and `clear_authorization`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `python -m unittest tests.test_trakt -v`

Expected: PASS for all Trakt client tests.

## Task 2: Web Action Dispatch

**Files:**
- Modify: `web/action.py`

- [ ] **Step 1: Write failing dispatch tests**

Extend `tests/test_trakt.py` to patch `web.action.Trakt` and verify `get_recommend({"type": "TRAKT", "subtype": "movie"})` calls movie recommendations, while `subtype=show` calls show recommendations.

- [ ] **Step 2: Run tests to verify they fail**

Run: `python -m unittest tests.test_trakt -v`

Expected: FAIL because `get_recommend` does not handle `Type == "TRAKT"`.

- [ ] **Step 3: Add web actions and dispatch**

Import `Trakt`, add `trakt_device_code`, `trakt_device_token`, and `trakt_clear_auth` to the command map, and add a `TRAKT` branch in `get_recommend`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `python -m unittest tests.test_trakt -v`

Expected: PASS for client and dispatch tests.

## Task 3: Settings And Navigation UI

**Files:**
- Modify: `config/config.yaml`
- Modify: `web/main.py`
- Create: `web/templates/setting/trakt.html`
- Modify: `web/static/components/layout/navbar/index.js`
- Modify: `app/conf/moduleconf.py`

- [ ] **Step 1: Add config defaults**

Add a `trakt` YAML node with `client_id`, `client_secret`, `redirect_uri`, `access_token`, `refresh_token`, and `expires_at`.

- [ ] **Step 2: Add settings route and template**

Add `/trakt` in `web/main.py` and create a template that saves config, starts device authorization, finishes authorization, and clears authorization through `ajax_post`.

- [ ] **Step 3: Add navigation and filters**

Add Trakt movie/TV entries to the discovery menu, add a Trakt settings entry, and define `DISCOVER_FILTER_CONF["trakt"]`.

- [ ] **Step 4: Run syntax checks**

Run: `python -m compileall app web tests`

Expected: exits with code 0.

## Task 4: Verification

**Files:**
- All files above.

- [ ] **Step 1: Run focused unit tests**

Run: `python -m unittest tests.test_trakt -v`

Expected: PASS.

- [ ] **Step 2: Run existing core tests**

Run: `python -m unittest tests.test_metainfo -v`

Expected: PASS.

- [ ] **Step 3: Inspect changed files**

Run: `git diff -- app/media/trakt.py app/media/__init__.py tests/test_trakt.py web/action.py config/config.yaml web/main.py web/templates/setting/trakt.html web/static/components/layout/navbar/index.js app/conf/moduleconf.py docs/superpowers/specs/2026-06-01-trakt-recommendations-design.md docs/superpowers/plans/2026-06-01-trakt-recommendations.md`

Expected: only Trakt recommendation changes and docs.
