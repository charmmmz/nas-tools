# Trakt Recommendations Design

## Goal

Add Trakt-powered personalized movie and TV recommendations to NASTOOL. The first version lets an admin configure Trakt OAuth, authorize the app with Trakt device codes, view Trakt recommendations in the existing discovery UI, and use the existing media detail and subscription actions from each recommendation card.

## Current Context

NASTOOL already has a recommendation pipeline:

- `web/action.py` exposes `get_recommend`, normalizes different recommendation sources, and enriches cards with local media or subscription state.
- `web/templates/discovery/recommend.html` renders paged recommendation cards from `get_recommend`.
- `web/static/components/page/discovery/index.js` renders discovery rows for ranking and Bangumi.
- `web/static/components/card/normal/index.js` and `web/static/components/utility/utility.js` already support opening TMDB detail pages and toggling subscriptions from cards.
- Existing recommendation sources include TMDB, Douban, Bangumi, recent downloads, search results, and TMDB similar/recommendation endpoints.

Trakt's official API supports OAuth device authorization and personalized recommendations through:

- `POST /oauth/device/code`
- `POST /oauth/device/token`
- `POST /oauth/token` with `grant_type=refresh_token`
- `GET /recommendations/movies`
- `GET /recommendations/shows`

The recommendation endpoints require OAuth and return media IDs including TMDB IDs when available. This makes them compatible with the current NASTOOL card and subscription flow.

## Scope

In scope for the first version:

- Add a Trakt client module for OAuth device flow, token refresh, recommendation requests, and response normalization.
- Add Trakt configuration fields to `config/config.yaml`.
- Add web actions for starting authorization, polling/finishing authorization, and clearing authorization.
- Add a Trakt settings page where the admin can save Client ID/Secret and authorize the local NASTOOL instance.
- Add "Trakt Movie Recommendations" and "Trakt TV Recommendations" entries under discovery.
- Add `Type=TRAKT` handling in `get_recommend`.
- Support basic recommendation filters: ignore watched, ignore collected, ignore watchlisted, and watch window.
- Reuse existing card actions for media details and subscription.
- Add tests for response normalization, token refresh behavior, and `get_recommend` dispatch.

Out of scope for the first version:

- Automatic scheduled subscription or downloading from Trakt recommendations.
- Writing NASTOOL watch history back to Trakt.
- Syncing Trakt watchlists, collections, ratings, or playback progress.
- Multi-user Trakt accounts inside one NASTOOL instance.
- Trakt scrobbling.

## Architecture

### Trakt Client

Create `app/media/trakt.py` with a `Trakt` class. It owns Trakt-specific HTTP requests and exposes a small interface:

- `is_configured()`
- `is_authorized()`
- `get_device_code()`
- `poll_device_token(device_code)`
- `clear_authorization()`
- `get_movie_recommendations(page, params)`
- `get_show_recommendations(page, params)`

The client reads and writes the `trakt` config node through `Config`. Access tokens are treated as sensitive values and are never logged.

### Token Handling

The config stores:

- `client_id`
- `client_secret`
- `redirect_uri`
- `access_token`
- `refresh_token`
- `expires_at`

`expires_at` is stored as a Unix timestamp. Before requesting recommendations, the client checks whether the access token expires soon. If needed, it refreshes the token through `POST /oauth/token`. Refresh failures return a clear error to the UI and do not expose token values.

### Recommendation Normalization

Trakt movie and show responses are converted into the card shape already used by NASTOOL:

```python
{
    "id": tmdb_id,
    "orgid": trakt_id,
    "title": title,
    "year": year,
    "type": "MOV" or "TV",
    "media_type": "电影" or "电视剧",
    "vote": rating,
    "image": poster_url,
    "overview": overview,
    "date": released_or_first_aired,
    "site": "Trakt"
}
```

Items without a TMDB ID are skipped in version one, because the existing detail and subscription flow expects TMDB IDs for normal movie/TV cards.

### Web Actions And API

Extend `WebAction` with:

- `trakt_device_code`
- `trakt_device_token`
- `trakt_clear_auth`

Extend `get_recommend` with `Type == "TRAKT"` and `SubType == "movie"` or `"show"`.

The existing `/api/v1/recommend/list` endpoint remains compatible. New OAuth actions are exposed through the existing `ajax_post` command dispatcher used by the settings pages.

### UI

Add `web/templates/setting/trakt.html`:

- Shows Client ID, Client Secret, Redirect URI, authorization state, and token expiry.
- Saves config through the existing `update_config` action.
- Starts device authorization and displays the Trakt activation URL and user code.
- Polls once when the user clicks a "finish authorization" button, instead of background polling forever.
- Clears authorization without deleting Client ID/Secret.

Add a "Trakt" settings entry in the settings section of the navbar.

Add two discovery entries under "探索":

- `Trakt电影推荐`: `recommend?type=TRAKT&subtype=movie&title=Trakt电影推荐&filter=trakt`
- `Trakt电视剧推荐`: `recommend?type=TRAKT&subtype=show&title=Trakt电视剧推荐&filter=trakt`

Add `trakt` filter config with dropdowns for ignore watched, ignore collected, ignore watchlisted, and watch window.

## Error Handling

- Missing Client ID/Secret returns "请先配置 Trakt Client ID 和 Client Secret".
- Missing authorization returns "请先完成 Trakt 授权".
- Expired or invalid authorization returns "Trakt 授权已失效，请重新授权".
- Rate limits return "Trakt 请求过于频繁，请稍后再试".
- Network failures return the Trakt HTTP status or a generic connection failure message.
- Empty recommendation results render the existing empty state.

## Security

- Trakt passwords are never requested or stored.
- Access and refresh tokens are stored only in the existing config file, matching current project configuration patterns.
- Token values are not displayed after authorization and are not written to logs.
- OAuth uses device code flow, so no public callback URL is required for NAS deployments.

## Testing

Add unit tests that do not call the Trakt network:

- Normalize a Trakt movie with a TMDB ID into a NASTOOL movie card.
- Normalize a Trakt show with a TMDB ID into a NASTOOL TV card.
- Skip Trakt items that have no TMDB ID.
- Refresh an expiring token and persist the new token fields.
- Dispatch `get_recommend` for Trakt movie and show subtypes.

Manual verification:

- Save Trakt Client ID/Secret from the settings page.
- Start device authorization and confirm the activation code is shown.
- Complete authorization in Trakt and finish authorization in NASTOOL.
- Open the Trakt movie and TV recommendation pages.
- Confirm cards open media details and the subscription heart uses the existing RSS subscription flow.
