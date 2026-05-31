# Trakt And Douban Recommendation Cards Design

## Goal

Improve the Trakt and Douban recommendation pages so posters load reliably and the main recommendation list feels closer to Trakt's official media browsing experience, without replacing the rest of NASTOOL's visual shell.

## Decisions

- Use the approved A direction from visual brainstorming: keep the current NASTOOL page frame, but render Trakt and Douban recommendation lists with a wider dark media card inspired by official Trakt.
- Apply the new card layout to the full recommendation list pages for Trakt and Douban.
- Keep existing homepage/ranking horizontal slides on the current compact poster card for now, but improve their poster fallback through the same backend data normalization.
- Use the most reliable poster source per provider and keep the existing no-image placeholder only as the final fallback.

## Current Context

Recommendation list pages are rendered by `web/templates/discovery/recommend.html`. That template calls `get_recommend` and currently appends `normal-card` elements into `#recommend_content`.

`normal-card` is poster-first and works well when `card-image` is reliable. When the image is empty or blocked, it falls back to the local no-image asset and the overlay becomes dense and hard to scan.

Trakt recommendations already include TMDB IDs after the initial integration, so TMDB poster fallback can be precise. Douban recommendation entries currently carry Douban IDs such as `DB:<id>` and often use Douban image URLs directly. Those URLs can fail due to missing fields, stale links, or hotlink restrictions.

## Scope

In scope:

- Add a reusable backend poster hydration helper for recommendation card dictionaries.
- Hydrate Trakt cards by TMDB ID when the Trakt poster is missing.
- Hydrate Douban cards through a strict title/year TMDB lookup so browser-side Douban hotlink failures can be avoided.
- Preserve existing card fields expected by search, detail, and subscription actions.
- Add a new Lit card component for Trakt/Douban recommendation list pages.
- Add a dedicated grid class for the new wide card layout.
- Use the new card only on full list pages where `Type == "TRAKT"` or Douban recommendation sources are active.
- Keep normal cards for TMDB, Bangumi, search, downloaded, person, and media-detail recommendation pages.
- Add tests for poster fallback behavior and Trakt normalization.

Out of scope:

- Full dark-mode page chrome matching app.trakt.tv.
- Replacing NASTOOL navigation or global theme.
- Reworking every discovery card in the product.
- Broad fuzzy matching for Douban cards when title/year matching is ambiguous.
- Proxying or caching image binaries locally.

## Poster Fallback

The backend should make the `image` field more reliable before it reaches the frontend.

Fallback order for Trakt:

1. Keep an existing non-empty Trakt source image.
2. If the card has a numeric TMDB ID and media type, request TMDB detail and use `poster_path` with `TMDB_IMAGE_W500_URL`.
3. If no TMDB poster can be found, keep `image` empty and let the frontend show the existing no-image asset.

Fallback order for Douban:

1. If the card has title, year, and media type, run an existing strict TMDB metadata lookup with those fields.
2. Use the TMDB poster when the lookup returns a normal numeric TMDB ID and a poster path.
3. If the lookup fails or is ambiguous, keep the original Douban image URL.
4. If both are unavailable or fail in the browser, let the frontend show the existing no-image asset.

Douban matching must stay conservative. The first version should not use broad fuzzy replacement, because a wrong poster is worse than a visible placeholder. The existing metadata cache should be reused so repeated page loads do not repeatedly search TMDB for the same title/year.

## UI Design

The new card is a landscape media card:

- Left side: fixed-ratio poster.
- Right side: dark information panel with title, source badge, vote, year, media type, date, and overview.
- Bottom actions: search and subscribe, matching current `normal-card` behavior.
- Click opens the existing media detail page when the card has a normal TMDB ID.
- Cards have stable dimensions so missing text, long titles, and fallback images do not resize the grid.

Desktop layout:

- Use a responsive grid with cards around 22 to 28 rem wide.
- Cards keep a two-column poster/detail composition.

Mobile layout:

- Stack poster and details vertically inside the same dark card.
- Keep actions reachable without depending on hover.

## Data Flow

`get_recommend` remains the single backend entry point.

1. Source helper returns normalized card dictionaries.
2. Poster hydration runs before local media/subscription enrichment.
3. Existing `FileTransfer().get_media_exists_flag(...)` adds `fav` and `rssid`.
4. The recommendation template picks the card component based on page type.
5. The card component calls existing global actions for detail, search, and subscription.

## Error Handling

- Missing poster data should never break the recommendation list.
- TMDB failures or ambiguous Douban matches should be logged only at the helper level and should not hide a valid recommendation.
- Cards without normal TMDB IDs should not navigate to a broken TMDB detail URL.
- Douban cards that remain `DB:<id>` should still support media search with the existing title/year flow where current behavior allows it.

## Testing

Automated tests:

- Trakt card without a Trakt image uses TMDB `poster_path` when a TMDB ID exists.
- Trakt card keeps a source image when present.
- Douban card uses a strict title/year TMDB poster when a safe match exists.
- Douban card keeps the original Douban image when strict TMDB lookup fails.
- The recommendation web action keeps adding `fav` and `rssid` after hydration.
- JavaScript syntax checks pass for the new card component.

Manual verification:

- Open Trakt movie and TV recommendation pages and confirm posters appear from TMDB when Trakt images are missing.
- Open Douban full recommendation pages and confirm existing working posters still show.
- Confirm missing posters render a clean fallback rather than squeezed text over a broken image.
- Confirm desktop and mobile layouts do not overlap text or actions.
