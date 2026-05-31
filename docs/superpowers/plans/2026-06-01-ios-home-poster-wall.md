# NASTOOL iOS Home Poster Wall Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a backend-proxied TMDB Home tab to the iOS app with a masonry poster wall, Trending/Popular filters, system-region defaults with user override, and poster-to-detail navigation.

**Architecture:** NASTOOL exposes a mobile home feed endpoint that maps Home filters to TMDB helpers, normalizes results into existing card fields, and augments each item with library/subscription state. The iOS app adds typed home models, a `HomeStore`, a SwiftUI `HomeView`, a region picker, and a `MediaDetailView` that can launch precise resource search or add a subscription through existing API methods.

**Tech Stack:** Python Flask-RESTX, NASTOOL `WebAction`/`Media` helpers, Swift 6, SwiftUI, Observation, XCTest, unittest.

---

## File Structure

- Modify `app/media/media.py`: add movie/TV trending helpers that use TMDB `day` and `week` windows.
- Modify `web/action.py`: add `get_mobile_home`, filter validation, feed mapping, interleaving, and NASTOOL state augmentation.
- Modify `web/apiv1.py`: add `mobile` namespace and `/api/v1/mobile/home`.
- Create `tests/test_mobile_home.py`: backend tests for filter mapping, region validation, people exclusion, and state augmentation.
- Modify `ios/NASTOOLMobile/NASTOOLMobileApp/API/NastoolAPIClient.swift`: add `fetchHomeFeed`.
- Modify `ios/NASTOOLMobile/NASTOOLMobileApp/API/NastoolModels.swift`: add home feed enums, region selection, response, and poster item model.
- Create `ios/NASTOOLMobile/NASTOOLMobileApp/Features/Home/HomeStore.swift`: home data loading, filter state, pagination, region persistence, and detail action helpers.
- Create `ios/NASTOOLMobile/NASTOOLMobileApp/Features/Home/HomeView.swift`: segmented controls, region picker, masonry wall, and navigation to detail.
- Create `ios/NASTOOLMobile/NASTOOLMobileApp/Features/Home/MediaDetailView.swift`: detail screen with search and subscription actions.
- Modify `ios/NASTOOLMobile/NASTOOLMobileApp/AppRootView.swift`: add Home as the first tab and wire navigation.
- Modify `ios/NASTOOLMobile/NASTOOLMobileApp/Features/Settings/SettingsView.swift`: expose Home region override.
- Create `ios/NASTOOLMobile/NASTOOLMobileTests/HomeStoreTests.swift`: store, region, pagination, and detail action tests.
- Modify `ios/NASTOOLMobile/NASTOOLMobileTests/NastoolAPIClientTests.swift`: request construction test for `/api/v1/mobile/home`.
- Modify `ios/NASTOOLMobile/NASTOOLMobileTests/NastoolModelDecodingTests.swift`: home response decoding test.
- Modify `ios/NASTOOLMobile/NASTOOLMobileTests/ScaffoldTests.swift`: tab order includes Home first.

## Task 1: Backend Mobile Home Feed

**Files:**
- Test: `tests/test_mobile_home.py`
- Modify: `app/media/media.py`
- Modify: `web/action.py`
- Modify: `web/apiv1.py`

- [ ] **Step 1: Write failing backend tests**

Create `tests/test_mobile_home.py` with unittest tests that patch `web.action.Media` and `web.action.FileTransfer`. Tests must verify:

```python
response = WebAction().get_mobile_home({"group": "trending", "filter": "today", "page": 1})
self.assertEqual(fake_media.calls, [("trending", "movie", "day", 1), ("trending", "tv", "day", 1)])
self.assertEqual([item["type"] for item in response["items"]], ["MOV", "TV"])
```

Also test:

```python
response = WebAction().get_mobile_home({"group": "popular", "filter": "streaming", "region": "cn", "page": 2})
self.assertEqual(fake_media.discover_calls[0][1]["watch_region"], "CN")
self.assertEqual(fake_media.discover_calls[0][1]["with_watch_monetization_types"], "flatrate")
```

And:

```python
response = WebAction().get_mobile_home({"group": "popular", "filter": "theaters", "region": "US", "page": 1})
self.assertEqual(fake_media.discover_calls[0][1]["region"], "US")
self.assertEqual(fake_media.discover_calls[0][1]["with_release_type"], "2|3")
```

And:

```python
response = WebAction().get_mobile_home({"group": "popular", "filter": "streaming", "region": "USA", "page": 1})
self.assertEqual(response["code"], 1)
self.assertIn("地区", response["msg"])
```

- [ ] **Step 2: Run backend tests to verify they fail**

Run: `python -m unittest tests.test_mobile_home -v`

Expected: FAIL because `get_mobile_home` and trending helpers do not exist.

- [ ] **Step 3: Implement backend feed**

Add to `Media`:

```python
def get_tmdb_trending(self, mtype, time_window, page=1):
    if not self.trending:
        return []
    if mtype == MediaType.MOVIE:
        result = self.trending.movie_day(page=page) if time_window == "day" else self.trending.movie_week(page=page)
        return self.__dict_tmdbinfos(result, MediaType.MOVIE)
    if mtype == MediaType.TV:
        result = self.trending.tv_day(page=page) if time_window == "day" else self.trending.tv_week(page=page)
        return self.__dict_tmdbinfos(result, MediaType.TV)
    return []
```

Add to `WebAction._actions`:

```python
"get_mobile_home": self.get_mobile_home,
```

Add `WebAction.get_mobile_home(data)` that validates `group`, `filter`, `page`, and two-letter `region`, maps:

- `trending/today` to movie+TV trending `day`
- `trending/week` to movie+TV trending `week`
- `popular/streaming` to movie+TV discover with `sort_by=popularity.desc`, `watch_region`, `with_watch_monetization_types=flatrate`
- `popular/theaters` to movie discover with `sort_by=popularity.desc`, `region`, `with_release_type=2|3`

Interleave movie and TV lists and augment each item:

```python
fav, rssid = filetransfer.get_media_exists_flag(
    mtype=res.get("type"),
    title=res.get("title"),
    year=res.get("year"),
    mediaid=res.get("id")
)
res.update({"fav": fav, "rssid": rssid})
```

Return:

```python
{"code": 0, "group": group, "filter": filter_key, "region": region, "page": page, "has_more": bool(items), "items": items}
```

Add `mobile = Apiv1.namespace('mobile', description='移动端')` and `POST /api/v1/mobile/home` in `web/apiv1.py` with `group`, `filter`, `region`, and `page` form fields.

- [ ] **Step 4: Run backend tests to verify they pass**

Run: `python -m unittest tests.test_mobile_home -v`

Expected: PASS.

## Task 2: iOS Home Models And API

**Files:**
- Modify: `ios/NASTOOLMobile/NASTOOLMobileApp/API/NastoolModels.swift`
- Modify: `ios/NASTOOLMobile/NASTOOLMobileApp/API/NastoolAPIClient.swift`
- Modify: `ios/NASTOOLMobile/NASTOOLMobileTests/NastoolModelDecodingTests.swift`
- Modify: `ios/NASTOOLMobile/NASTOOLMobileTests/NastoolAPIClientTests.swift`

- [ ] **Step 1: Write failing iOS API/model tests**

Add a decoding test that decodes:

```json
{
  "code": 0,
  "success": true,
  "data": {
    "group": "popular",
    "filter": "streaming",
    "region": "CN",
    "page": 1,
    "has_more": true,
    "items": [
      {
        "id": 101,
        "tmdbid": 101,
        "title": "Arrival",
        "type": "MOV",
        "media_type": "电影",
        "year": "2016",
        "vote": 7.6,
        "image": "https://image.tmdb.org/t/p/w500/poster.jpg",
        "backdrop": "https://image.tmdb.org/t/p/w500/backdrop.jpg",
        "overview": "A movie.",
        "fav": true,
        "rssid": "rss-1"
      }
    ]
  }
}
```

Assert `response.data.items.first?.id == "101"`, `isFavorite == true`, and `voteText == "7.6"`.

Add an API client test that `fetchHomeFeed(group: .popular, filter: .streaming, region: "CN", page: 2)` posts to `/api/v1/mobile/home` with body `filter=streaming&group=popular&page=2&region=CN`.

- [ ] **Step 2: Run iOS tests to verify they fail**

Run: `cd ios/NASTOOLMobile && xcodebuild test -scheme NASTOOLMobile -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -only-testing:NASTOOLMobileTests/NastoolModelDecodingTests -only-testing:NASTOOLMobileTests/NastoolAPIClientTests`

Expected: FAIL because home types and client method do not exist.

- [ ] **Step 3: Implement models and API**

Add:

```swift
enum HomeFeedGroup: String, CaseIterable, Codable, Identifiable {
    case trending
    case popular
    var id: String { rawValue }
}

enum HomeFeedFilter: String, CaseIterable, Codable, Identifiable {
    case today
    case week
    case streaming
    case theaters
    var id: String { rawValue }
}
```

Add `HomeFeedPayload`, `HomeFeedResponse`, and `HomePosterItem` decoders using flexible string helpers for ids and vote. Add `NastoolAPIClient.fetchHomeFeed(group:filter:region:page:)` posting to `/api/v1/mobile/home`.

- [ ] **Step 4: Run iOS tests to verify they pass**

Run the same xcodebuild test command.

Expected: PASS.

## Task 3: iOS Home Store And Region Selection

**Files:**
- Create: `ios/NASTOOLMobile/NASTOOLMobileApp/Features/Home/HomeStore.swift`
- Create: `ios/NASTOOLMobile/NASTOOLMobileTests/HomeStoreTests.swift`

- [ ] **Step 1: Write failing store tests**

Test:

```swift
let store = HomeStore(api: api, localeRegionProvider: { "CN" }, regionStorage: storage)
await store.loadInitial()
XCTAssertEqual(api.requests, [.init(group: .trending, filter: .today, region: nil, page: 1)])
```

Test switching popular streaming sends automatic system region:

```swift
store.select(group: .popular)
store.select(filter: .streaming)
await store.loadInitial()
XCTAssertEqual(api.requests.last?.region, "CN")
```

Test explicit override:

```swift
store.regionSelection = .region("US")
await store.loadInitial()
XCTAssertEqual(api.requests.last?.region, "US")
```

Test `loadMore()` appends page 2 items.

- [ ] **Step 2: Run store tests to verify they fail**

Run: `cd ios/NASTOOLMobile && xcodebuild test -scheme NASTOOLMobile -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -only-testing:NASTOOLMobileTests/HomeStoreTests`

Expected: FAIL because `HomeStore` does not exist.

- [ ] **Step 3: Implement HomeStore**

Add `HomeAPI` protocol with `fetchHomeFeed`, a `HomeRegionStorage` protocol, a `UserDefaultsHomeRegionStorage`, and `HomeStore` with:

- `selectedGroup = .trending`
- `selectedFilter = .today`
- `regionSelection`
- `items`
- `selectedDetailItem`
- `isLoading`
- `errorMessage`
- `loadInitial()`
- `loadMore()`
- `select(group:)`
- `select(filter:)`
- `effectiveRegion`

Persist explicit region overrides and treat `automatic` as no stored override.

- [ ] **Step 4: Run store tests to verify they pass**

Run the same HomeStoreTests command.

Expected: PASS.

## Task 4: Home UI, Detail UI, And App Navigation

**Files:**
- Create: `ios/NASTOOLMobile/NASTOOLMobileApp/Features/Home/HomeView.swift`
- Create: `ios/NASTOOLMobile/NASTOOLMobileApp/Features/Home/MediaDetailView.swift`
- Modify: `ios/NASTOOLMobile/NASTOOLMobileApp/AppRootView.swift`
- Modify: `ios/NASTOOLMobile/NASTOOLMobileApp/Features/Settings/SettingsView.swift`
- Modify: `ios/NASTOOLMobile/NASTOOLMobileTests/ScaffoldTests.swift`

- [ ] **Step 1: Write failing scaffold test**

Change `ScaffoldTests` expectation to:

```swift
XCTAssertEqual(AppTab.allCases.map(\.title), ["Home", "Downloads", "Search", "Subscriptions", "Settings"])
```

- [ ] **Step 2: Run scaffold test to verify it fails**

Run: `cd ios/NASTOOLMobile && xcodebuild test -scheme NASTOOLMobile -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -only-testing:NASTOOLMobileTests/ScaffoldTests`

Expected: FAIL because Home is not in `AppTab`.

- [ ] **Step 3: Implement UI and navigation**

Add `.home` as the first `AppTab`, title `Home`, system image `square.grid.2x2`.

Add `HomeView(api:)` containing:

- primary picker for `Trending` and `Popular`
- secondary picker for `Today`/`This Week` or `Streaming`/`Theaters`
- region button and sheet
- two-column masonry poster wall
- `NavigationLink(value:)` or `navigationDestination(item:)` to `MediaDetailView`

Add `MediaDetailView(item:api:)` with poster/backdrop, title, metadata, overview, and buttons:

- `Search Resources`
- `Add Subscription`

Update `SettingsView` to show Home region selection under a `Home` section.

- [ ] **Step 4: Run scaffold test to verify it passes**

Run the same ScaffoldTests command.

Expected: PASS.

## Task 5: Full Verification

**Files:**
- Modify as needed only for build fixes found by verification.

- [ ] **Step 1: Run backend mobile tests**

Run: `python -m unittest tests.test_mobile_home -v`

Expected: PASS.

- [ ] **Step 2: Run full iOS unit/UI suite**

Run: `cd ios/NASTOOLMobile && xcodebuild test -scheme NASTOOLMobile -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5'`

Expected: PASS, or report simulator/environment failures with exact output.

- [ ] **Step 3: Build and launch simulator if tests pass**

Use XcodeBuildMCP when available: call `session_show_defaults`, then `build_run_sim` if defaults are set. If defaults are not set, use `xcodebuild` build output as the verification artifact.

- [ ] **Step 4: Commit implementation**

Stage only files changed for this feature and commit:

```bash
git add app/media/media.py web/action.py web/apiv1.py tests/test_mobile_home.py ios/NASTOOLMobile/NASTOOLMobileApp ios/NASTOOLMobile/NASTOOLMobileTests docs/superpowers/plans/2026-06-01-ios-home-poster-wall.md
git commit -m "feat: add iOS home poster wall"
```

## Self-Review

- Spec coverage: backend proxy, Home tab, poster wall, filters, region default/override, detail navigation, search/subscription actions, and tests are covered.
- Placeholder scan: no TODO/TBD/fill-in steps remain.
- Type consistency: `HomeFeedGroup`, `HomeFeedFilter`, `HomePosterItem`, `HomeFeedResponse`, and `HomeStore` names are consistent across tasks.
