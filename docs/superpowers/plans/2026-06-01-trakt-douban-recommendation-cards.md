# Trakt And Douban Recommendation Cards Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Trakt and Douban recommendation pages use reliable posters and a Trakt-inspired wide media card layout.

**Architecture:** Add a small backend poster hydration helper that works on existing recommendation card dictionaries before local subscription enrichment. Add a dedicated Lit card component and switch only Trakt/Douban full recommendation pages to the new responsive grid.

**Tech Stack:** Python unittest, existing NASTOOL `Media`/`MetaInfo` helpers, Flask/Jinja template, Lit custom elements, Tabler-style CSS, Node syntax checks.

---

## File Map

- Create `app/media/recommendation.py`: poster hydration helper for source-agnostic recommendation card dictionaries.
- Modify `web/action.py`: call poster hydration in `get_recommend` for Trakt and Douban sources before `FileTransfer` enrichment.
- Create `tests/test_recommendation_posters.py`: backend unit tests for Trakt and Douban poster fallback.
- Create `web/static/components/card/recommendation/index.js`: new wide card component with existing search/detail/subscribe actions.
- Create `web/static/components/card/recommendation/placeholder.js`: loading placeholder matching the wide card layout.
- Modify `web/templates/discovery/recommend.html`: select `recommendation-card` only for `Type == "TRAKT"` or Douban list pages.
- Modify `web/templates/navigation.html` or the component import registry if needed after inspecting existing script registration.
- Modify `web/static/css/style.css`: add the responsive wide-card grid and card styles.
- Modify `tests/test_trakt.py`: adjust existing `get_recommend` dispatch expectations if hydration changes the code path.

## Task 1: Backend Poster Hydration Tests

**Files:**
- Create: `tests/test_recommendation_posters.py`
- Modify only if needed: `tests/test_trakt.py`

- [ ] **Step 1: Write failing tests**

Create tests for these behaviors:

```python
# -*- coding: utf-8 -*-

from unittest import TestCase
from unittest.mock import Mock

from app.media.recommendation import hydrate_recommendation_posters


class RecommendationPosterHydrationTest(TestCase):
    def test_trakt_card_uses_tmdb_poster_when_source_image_missing(self):
        media = Mock()
        media.get_tmdb_info.return_value = {"poster_path": "/poster.jpg"}
        cards = [{
            "id": 123,
            "type": "MOV",
            "media_type": "电影",
            "title": "Movie",
            "year": "2026",
            "image": "",
            "site": "Trakt",
        }]

        hydrate_recommendation_posters(cards, source="trakt", media=media)

        self.assertEqual(cards[0]["image"], "https://image.tmdb.org/t/p/w500/poster.jpg")
        media.get_tmdb_info.assert_called_once()

    def test_trakt_card_keeps_existing_source_image(self):
        media = Mock()
        cards = [{
            "id": 123,
            "type": "MOV",
            "media_type": "电影",
            "title": "Movie",
            "year": "2026",
            "image": "https://trakt.example/poster.jpg",
            "site": "Trakt",
        }]

        hydrate_recommendation_posters(cards, source="trakt", media=media)

        self.assertEqual(cards[0]["image"], "https://trakt.example/poster.jpg")
        media.get_tmdb_info.assert_not_called()

    def test_douban_card_uses_strict_tmdb_match_when_available(self):
        media = Mock()
        media.get_media_info.return_value = Mock(
            tmdb_id=456,
            poster_path="https://image.tmdb.org/t/p/w500/douban.jpg",
        )
        cards = [{
            "id": "DB:1",
            "type": "MOV",
            "media_type": "电影",
            "title": "Douban Movie",
            "year": "2026",
            "image": "https://douban.example/poster.jpg",
        }]

        hydrate_recommendation_posters(cards, source="douban", media=media)

        self.assertEqual(cards[0]["image"], "https://image.tmdb.org/t/p/w500/douban.jpg")
        self.assertEqual(cards[0]["tmdbid"], 456)
        media.get_media_info.assert_called_once()

    def test_douban_card_keeps_source_image_when_strict_match_missing(self):
        media = Mock()
        media.get_media_info.return_value = None
        cards = [{
            "id": "DB:1",
            "type": "MOV",
            "media_type": "电影",
            "title": "Douban Movie",
            "year": "2026",
            "image": "https://douban.example/poster.jpg",
        }]

        hydrate_recommendation_posters(cards, source="douban", media=media)

        self.assertEqual(cards[0]["image"], "https://douban.example/poster.jpg")
        self.assertNotIn("tmdbid", cards[0])
```

- [ ] **Step 2: Run tests to verify RED**

Run:

```bash
NASTOOL_CONFIG=/Users/charm/Documents/NASTOOL/config/config.yaml .venv/bin/python -m unittest tests.test_recommendation_posters -v
```

Expected: fail because `app.media.recommendation` does not exist.

## Task 2: Backend Poster Hydration Implementation

**Files:**
- Create: `app/media/recommendation.py`
- Modify: `web/action.py`
- Test: `tests/test_recommendation_posters.py`, `tests/test_trakt.py`

- [ ] **Step 1: Implement helper**

Create `hydrate_recommendation_posters(cards, source, media=None)`:

- Return the same list object after mutating card dictionaries in place.
- For `source == "trakt"`, keep existing `image`; otherwise use numeric `id` with `Media().get_tmdb_info(...)` and `TMDB_IMAGE_W500_URL`.
- For `source == "douban"`, require `title`, `year`, and `type`; call `Media().get_media_info(title=f"{title} {year}", mtype=MediaType.MOVIE/TV, strict=True)`.
- If Douban lookup returns a normal numeric `tmdb_id` and `poster_path`, set `image` to `poster_path` and set `tmdbid` for UI detail navigation.
- Catch exceptions and keep original cards.

- [ ] **Step 2: Run backend poster tests to verify GREEN**

Run:

```bash
NASTOOL_CONFIG=/Users/charm/Documents/NASTOOL/config/config.yaml .venv/bin/python -m unittest tests.test_recommendation_posters -v
```

Expected: all tests pass.

- [ ] **Step 3: Wire helper into `get_recommend`**

In `web/action.py`, after source-specific `res_list` is created and before `FileTransfer()` enrichment:

- Track `poster_source = "trakt"` for `Type == "TRAKT"`.
- Track `poster_source = "douban"` for Douban subtypes and `Type == "DOUBANTAG"`.
- Call `hydrate_recommendation_posters(res_list, source=poster_source)` when set.

- [ ] **Step 4: Update and run dispatch tests**

Run:

```bash
NASTOOL_CONFIG=/Users/charm/Documents/NASTOOL/config/config.yaml .venv/bin/python -m unittest tests.test_trakt tests.test_recommendation_posters -v
```

Expected: all tests pass.

## Task 3: Wide Recommendation Card Component

**Files:**
- Create: `web/static/components/card/recommendation/index.js`
- Create: `web/static/components/card/recommendation/placeholder.js`
- Modify: `web/templates/navigation.html` or existing component import registry if needed.
- Modify: `web/static/css/style.css`

- [ ] **Step 1: Create component and placeholder**

Implement `recommendation-card` with properties matching `normal-card` plus optional `card-realid`/`card-tmdbid`. It should:

- Show poster on the left, metadata on the right.
- Use `Golbal.noImage` when image is missing or fails.
- Navigate to `media_detail` only when the selected detail ID is not `DB:*`.
- Keep search and subscription actions through `media_search(...)` and `Golbal.lit_love_click(...)`.
- Dispatch `fav_change` after subscription state changes.

- [ ] **Step 2: Add CSS**

Add stable responsive classes:

- `.grid-recommendation-card`
- `.lit-recommendation-card`
- `.recommendation-card-poster`
- `.recommendation-card-body`
- `.recommendation-card-actions`

Desktop cards should be landscape; mobile cards can stack vertically.

- [ ] **Step 3: Run JavaScript syntax checks**

Run:

```bash
/Users/charm/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node --check web/static/components/card/recommendation/index.js
/Users/charm/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node --check web/static/components/card/recommendation/placeholder.js
```

Expected: both commands succeed.

## Task 4: Recommendation Template Switch

**Files:**
- Modify: `web/templates/discovery/recommend.html`

- [ ] **Step 1: Compute enhanced-card mode**

In the page script, derive:

```javascript
const UseRecommendationCard = Type === "TRAKT"
  || Type === "DOUBANTAG"
  || ["dbom", "dbhm", "dbht", "dbdh", "dbnm", "dbtop", "dbzy", "dbct", "dbgt"].includes(SubType);
```

- [ ] **Step 2: Switch grid and placeholders**

Use `grid-recommendation-card` and `recommendation-card-placeholder` only when `UseRecommendationCard` is true. Keep existing `normal-card` behavior otherwise.

- [ ] **Step 3: Render the new card**

For enhanced mode, append:

```html
<recommendation-card
  card-tmdbId="${item.tmdbid || item.id}"
  card-sourceid="${item.id}"
  card-mediatype="${item.type}"
  card-showSub="1"
  card-image="${item.image}"
  card-weekday="${item.weekday}"
  card-fav="${item.fav}"
  card-vote="${item.vote}"
  card-year="${item.year}"
  card-title="${item.title}"
  card-overview="${item.overview}"
  card-restype="${item.media_type}"
  card-date="${item.date}"
  card-site="${item.site}"
></recommendation-card>
```

- [ ] **Step 4: Check template and component syntax**

Run:

```bash
/Users/charm/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node --check web/static/components/card/recommendation/index.js
.venv/bin/python -m compileall web app tests
```

Expected: both commands succeed.

## Task 5: Verification And Visual QA

**Files:**
- No new files unless a small fixture is needed.

- [ ] **Step 1: Run focused tests**

Run:

```bash
NASTOOL_CONFIG=/Users/charm/Documents/NASTOOL/config/config.yaml .venv/bin/python -m unittest tests.test_trakt tests.test_recommendation_posters -v
```

Expected: all tests pass.

- [ ] **Step 2: Run compile and syntax checks**

Run:

```bash
NASTOOL_CONFIG=/Users/charm/Documents/NASTOOL/config/config.yaml .venv/bin/python -m compileall app web tests
/Users/charm/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node --check web/static/components/card/recommendation/index.js
/Users/charm/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node --check web/static/components/card/recommendation/placeholder.js
git diff --check
```

Expected: all commands succeed.

- [ ] **Step 3: Manual browser check if a local app server is available**

Open a Trakt or Douban recommendation page and confirm:

- Wide cards render only on Trakt/Douban list pages.
- Poster fallback does not produce broken-image icons.
- Text and actions do not overlap on desktop or mobile widths.

## Self-Review

- Spec coverage: poster fallback, Trakt/Douban scope, new wide card, normal cards preserved elsewhere, and tests are covered.
- Placeholder scan: no TBD/TODO placeholders.
- Type consistency: card fields stay compatible with current `normal-card`; `tmdbid` is additive and does not replace `id`.
