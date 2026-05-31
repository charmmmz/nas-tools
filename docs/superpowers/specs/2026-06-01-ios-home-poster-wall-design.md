# NASTOOL iOS Home Poster Wall Design

## Goal

Add a native Home tab to the NASTOOL iOS app. The screen should feel like a media discovery surface: a poster wall with masonry-style cards, TMDB-backed sections, region-aware availability filters, and a clean path from discovery to media details, search, and subscription.

The iOS app must not call TMDB directly or store TMDB credentials. NASTOOL remains the backend proxy and source of truth for TMDB configuration, media availability context, library status, and subscription state.

## Decisions

- Add `Home` as the first app tab.
- Use a wall-first masonry layout based on the selected C direction from visual brainstorming.
- Use a two-level filter model:
  - `Trending`: `Today`, `This Week`
  - `Popular`: `Streaming`, `Theaters`
- Default the TMDB region to the phone's system region.
- Allow users to override the region from Home and Settings.
- Open a media detail page when a user taps a poster.
- Keep all TMDB requests behind NASTOOL API endpoints.

## Current Context

The iOS app is a SwiftUI app under `ios/NASTOOLMobile` with existing `Downloads`, `Search`, `Subscriptions`, and `Settings` tabs. It already has:

- A token-authenticated `NastoolAPIClient`.
- Observable feature stores.
- Existing search flow work that can search by TMDB identity.
- NASTOOL result wrappers such as `NastoolResultResponse`.

The backend already exposes `/api/v1/recommend/list`, and the web UI's `TMDB电影` and `TMDB电视剧` pages use the existing `DISCOVER` recommendation path. Backend media helpers already normalize TMDB results to card-like fields: `id`, `title`, `type`, `media_type`, `year`, `vote`, `image`, and `overview`, then add `fav` and `rssid`.

## Official API Notes

TMDB official references confirm the required data model:

- Trending supports a time window of `day` or `week`.
- Discover Movie and Discover TV support filtering and sorting for popularity.
- Discover supports watch provider availability through region-aware watch parameters.
- Movie release filtering can represent theatrical lists through region and release type.

The app design maps these through backend endpoints rather than direct iOS calls.

## Information Architecture

### Tab Order

`Home`, `Downloads`, `Search`, `Subscriptions`, `Settings`

Home is the default authenticated screen. Downloads remains the operational control surface, while Home is the discovery entry point.

### Home Header

The Home header contains:

- Title: `Home`
- Search affordance that opens the existing search surface.
- Region button, for example `Region · CN`.

The region button opens a sheet with:

- `Automatic`: follows the phone system region.
- Common region shortcuts such as `CN`, `US`, `JP`, and `HK`.
- A searchable or expandable full region list can be added later without changing the data model.

### Filters

Home uses two segmented controls.

Primary group:

- `Trending`
- `Popular`

Secondary filter:

- For `Trending`: `Today`, `This Week`
- For `Popular`: `Streaming`, `Theaters`

`Trending` is global and does not depend on region. `Popular` uses the selected region.

## Data Contract

Add a backend endpoint for the mobile home feed:

`POST /api/v1/mobile/home`

Form fields:

- `group`: `trending` or `popular`
- `filter`: `today`, `week`, `streaming`, or `theaters`
- `region`: optional ISO region code, such as `CN` or `US`
- `page`: positive integer

Response:

```json
{
  "code": 0,
  "success": true,
  "message": "",
  "data": {
    "group": "popular",
    "filter": "streaming",
    "region": "CN",
    "page": 1,
    "has_more": true,
    "items": [
      {
        "id": "123",
        "tmdbid": "123",
        "title": "Example",
        "type": "MOV",
        "media_type": "电影",
        "year": "2026",
        "vote": "7.8",
        "image": "https://image.tmdb.org/t/p/w500/poster.jpg",
        "backdrop": "https://image.tmdb.org/t/p/w500/backdrop.jpg",
        "overview": "Short overview.",
        "fav": false,
        "rssid": ""
      }
    ]
  }
}
```

The response intentionally mirrors existing recommendation card fields so the backend can reuse current mapping code. `backdrop` and `has_more` are optional enhancements for native detail and pagination.

## Backend Mapping

### Trending

Use TMDB trending endpoints through backend helpers:

- `Today`: movie day + TV day, merged into one feed.
- `This Week`: movie week + TV week, merged into one feed.

Do not use `trending/all` for Home, because it can include people. The poster wall should contain only movies and TV.

### Popular Streaming

Use TMDB Discover through backend helpers:

- Discover Movie
- Discover TV

Parameters:

- `sort_by=popularity.desc`
- `watch_region=<region>`
- `with_watch_monetization_types=flatrate`

Merge movie and TV results by popularity or original TMDB order with stable interleaving.

### Popular Theaters

Use Movie Discover only. TV has no equivalent theater concept.

Parameters:

- `sort_by=popularity.desc`
- `region=<region>`
- `with_release_type=2|3`

If a selected region produces empty results, the backend returns an empty feed rather than silently falling back. The UI can show a friendly empty state and let the user change region.

### Existing State

For every item, the backend should keep adding:

- `fav`
- `rssid`

This preserves NASTOOL's current "already in library or subscribed" awareness.

## iOS Data Model

Add:

- `HomeFeedGroup`: `trending`, `popular`
- `HomeFeedFilter`: `today`, `week`, `streaming`, `theaters`
- `HomeRegionSelection`: `automatic` or `region(code: String)`
- `HomePosterItem`: normalized media card model
- `HomeFeedResponse`: decoded mobile home response

Region behavior:

- `automatic` reads `Locale.autoupdatingCurrent.region?.identifier`.
- If the system region is missing, use a conservative fallback such as `US`.
- Explicit region overrides are persisted locally.
- The selected effective region is sent to the backend only for `Popular`.

## SwiftUI Screens

### HomeView

Responsibilities:

- Own `HomeStore`.
- Show primary and secondary segmented controls.
- Show region button and region picker.
- Render a masonry-style poster wall.
- Load first page on appear.
- Reload when group, filter, or effective region changes.
- Load more when the user scrolls near the end.
- Navigate to `MediaDetailView` on poster tap.

### Poster Wall

Use a SwiftUI-native masonry layout with two columns on iPhone. The first implementation can use balanced columns computed from deterministic poster aspect ratios. Later, it can move to a custom `Layout` if needed.

Cards show:

- Poster image
- Title
- Year
- Type badge
- Vote when available
- Small subscription/library indicator when `fav` or `rssid` is present

### Region Picker

Region picker appears as a sheet. It includes `Automatic` and common regions first. A full ISO list can be added if implementation time allows; otherwise the first version should include common choices and a text field for manual two-letter region codes.

### MediaDetailView

Opened from Home poster cards.

Shows:

- Poster or backdrop
- Title
- Year
- Type
- Vote
- Overview
- Library/subscription state
- `Search Resources`
- `Add Subscription`

Actions:

- `Search Resources` routes into the existing TMDB-identity search flow.
- `Add Subscription` uses the existing subscription API.

## Error Handling

- Network failure: keep existing content visible and show a retry affordance.
- Empty feed: show an empty state that mentions the selected filter and region.
- Invalid region: backend returns a clear validation message; iOS falls back to `Automatic` only after user action.
- Missing poster: use a neutral placeholder with title text.
- TMDB unavailable: backend returns a normal error envelope; iOS displays a nonblocking error.

## Testing

Backend:

- Unit test request mapping for each `group/filter`.
- Test that `trending` excludes people by using movie and TV endpoints rather than `all`.
- Test region validation.
- Test response normalization includes existing `fav` and `rssid` fields.

iOS:

- Decode `HomeFeedResponse`.
- Test `HomeStore` initial load, filter switching, region changes, pagination, and error handling.
- Test automatic region selection with injectable locale provider.
- Test tapping a poster creates the expected detail navigation model.
- Test detail actions call the search or subscription APIs with TMDB identity.

Manual verification:

- Build and run the iOS app in simulator.
- Verify Home appears as the first authenticated tab.
- Verify filter changes reload data.
- Verify region override changes Popular feeds.
- Verify poster tap opens detail.
- Verify Search Resources opens the existing search flow.

## Out Of Scope

- Direct TMDB calls from iOS.
- Downloading directly from Home.
- Push notifications or Live Activities changes.
- A full advanced TMDB filter UI.
- Personalized recommendation algorithms beyond NASTOOL/TMDB state.

## Open Implementation Notes

- The backend can start with `/api/v1/mobile/home` even if future endpoints move under a broader mobile namespace.
- Existing `/api/v1/recommend/list` can remain unchanged for web compatibility.
- The masonry layout should prioritize stable scroll performance over complex animated rearrangement.
- The region picker can start small but the model should support any ISO region code.

## References

- TMDB Trending All: https://developer.themoviedb.org/reference/trending-all
- TMDB Trending TV: https://developer.themoviedb.org/reference/trending-tv
- TMDB Discover Movie: https://developer.themoviedb.org/reference/discover-movie
- TMDB Discover TV: https://developer.themoviedb.org/reference/discover-tv
- Apple Locale autoupdatingCurrent: https://developer.apple.com/documentation/foundation/locale/autoupdatingcurrent
- Apple Locale Region identifier: https://developer.apple.com/documentation/foundation/locale/region-swift.struct/identifier
