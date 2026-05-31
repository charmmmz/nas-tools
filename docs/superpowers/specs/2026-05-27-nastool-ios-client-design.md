# NASTOOL iOS Client Design

## Goal

Build a native iOS client for the user's fork of NASTOOL. The app is a receiver and controller: it talks to the NASTOOL service over the user's existing HTTPS DDNS reverse proxy, shows NASTOOL state on the phone, and later receives push notifications and Live Activity updates that are sent by NASTOOL through APNs.

The first deliverable is a useful iPhone client before Apple Developer Program capabilities are fully available. Push notifications and remote Live Activity updates are designed now, but implemented after the developer account is active.

## Current Context

The repository is a Python Flask app with an existing REST API under `/api/v1`. The API already covers the core mobile control surface:

- `POST /api/v1/user/login` returns a bearer token and API key.
- `POST /api/v1/download/now` returns active downloads.
- `POST /api/v1/download/info` returns progress for selected tasks.
- `POST /api/v1/download/start`, `/stop`, and `/remove` control tasks.
- `POST /api/v1/search/result`, `/download/search`, and `/download/item` support search result download flows.
- `POST /api/v1/subscribe/add`, `/delete`, `/movie/list`, `/tv/list`, and `/history` cover subscription workflows.

The user's deployment matches the public-client model: NASTOOL is reachable through an IPv6 DDNS hostname and Nginx Proxy Manager reverse proxy with HTTPS. The iOS app will not expose a server or receive direct inbound traffic. NASTOOL remains the business backend and push sender.

## Phased Scope

### Phase A: Native Control Client

Phase A builds the native app experience that can work before APNs is configured.

Features:

- Add server by HTTPS base URL.
- Login with NASTOOL username and password.
- Store auth token and server settings in Keychain.
- Show active download tasks with progress, speed, remaining status where available, and basic task metadata.
- Start, pause, resume, and remove download tasks.
- Search movies and TV shows using existing NASTOOL search APIs.
- Trigger download from search results.
- View movie and TV subscription lists.
- Add and remove subscriptions.
- Start a Live Activity from inside the app for one or more selected active downloads.
- Update Live Activities locally while the app is active or has short background runtime.

Out of scope for Phase A:

- Remote APNs push.
- Remote start/update/end of Live Activities.
- TestFlight distribution.
- Server-side schema migrations for device tokens.

### Phase B: Push And Remote Live Activities

Phase B starts after the Apple Developer Program account is active and APNs keys/capabilities can be configured.

Features:

- Add an iOS device registration API in NASTOOL.
- Store app device tokens in NASTOOL.
- Add a NASTOOL APNs client that sends normal push notifications.
- Add a notification preference model for daily subscription summaries, download completion, failures, and optional site/status events.
- Add a Live Activity registration API for task-specific ActivityKit push tokens.
- Send ActivityKit updates from NASTOOL to APNs as download progress changes.
- End Live Activities when the task completes, fails, or is removed.
- Send a daily subscription digest from NASTOOL to the app as a normal iOS notification.

## Architecture

### iOS App

The app is a SwiftUI iOS app with these modules:

- `AppShell`: tab navigation, session state, global errors.
- `ServerAuth`: server URL validation, login, token refresh behavior, Keychain storage.
- `NastoolAPI`: typed API client for existing `/api/v1` endpoints.
- `Downloads`: active download list, task controls, progress polling.
- `Search`: search input, result list, download action.
- `Subscriptions`: movie and TV subscription list, add/remove forms.
- `LiveActivitySupport`: ActivityKit models, widget extension UI, local start/update/end in Phase A.
- `PushRegistration`: APNs and ActivityKit token registration in Phase B.

The UI should be quiet and operational: dense lists, clear task states, native controls, and fast navigation. It should feel like a companion control panel rather than a media browsing app.

### NASTOOL Backend

Phase A does not require backend changes unless an existing API response is unsuitable for mobile. When a small compatibility endpoint is needed, it should be added under `/api/v1/mobile/...` and wrap existing business actions instead of duplicating downloader or subscription logic.

Phase B adds:

- `IOS_DEVICES` table for device token, user, app build, environment, notification settings, and timestamps.
- `IOS_LIVE_ACTIVITIES` table for task id, device id, ActivityKit push token, task display metadata, state, and timestamps.
- `/api/v1/mobile/device/register` for APNs token registration.
- `/api/v1/mobile/device/preferences` for notification preferences.
- `/api/v1/mobile/live-activity/register` for mapping a NASTOOL task to an ActivityKit token.
- `/api/v1/mobile/live-activity/end` for explicit cleanup from the app.
- An APNs sender service used by scheduler and download progress code.

### Data Flow

Login:

```text
iPhone app -> NASTOOL /api/v1/user/login -> token stored in Keychain
```

Downloads:

```text
iPhone app -> /api/v1/download/now -> render active tasks
iPhone app -> /api/v1/download/info -> refresh selected task progress
iPhone app -> /api/v1/download/start|stop|remove -> control task
```

Phase A Live Activity:

```text
User starts Live Activity in app
App polls NASTOOL while active
App updates ActivityKit locally
App ends activity when task completes or user stops tracking
```

Phase B Live Activity:

```text
App starts Live Activity and receives ActivityKit push token
App registers task id + push token with NASTOOL
NASTOOL polls/observes downloader progress
NASTOOL sends ActivityKit push updates through APNs
APNs updates iPhone Live Activity
NASTOOL sends end event on completion/failure/removal
```

Daily subscription push:

```text
NASTOOL scheduler builds subscription digest
NASTOOL sends normal APNs notification to registered devices
iOS displays notification and opens related subscription screen when tapped
```

## Security

- Require HTTPS server URLs in the app for saved servers.
- Store tokens only in Keychain.
- Do not store the NASTOOL password after login.
- Use bearer token auth for API calls.
- Support logout by clearing local credentials.
- Recommend a strong NASTOOL password and a long API key because the service is internet reachable.
- Phase B APNs endpoints require the same authenticated user session as other client APIs.
- Device tokens are treated as secrets and never shown in logs unless debug mode is explicitly enabled.

## Error Handling

- Network failures show a retry action and keep the last successful state visible.
- Auth failures return the user to login with an explanation.
- Unsupported or missing server features are shown as disabled controls with short labels.
- Download control failures show the backend message when available.
- Live Activity failures fall back to in-app progress only.
- Push registration failures do not block normal app use.

## Testing

Phase A:

- Unit tests for request construction and response decoding.
- Unit tests for Keychain/session state transitions using test doubles.
- API integration smoke tests against local NASTOOL where practical.
- Manual simulator and device tests for login, downloads, search, and subscriptions.
- Widget/Live Activity local tests on a physical device, because Live Activities are device-sensitive.

Phase B:

- Backend unit tests for device registration and token replacement.
- Backend tests for APNs payload construction.
- Manual APNs sandbox tests for normal push.
- Manual ActivityKit push tests on a physical device.
- Regression test that Phase A app functions still work without push configured.

## Implementation Order

1. Create iOS app and widget extension skeleton.
2. Implement server login and Keychain-backed session.
3. Implement typed NASTOOL API client for existing endpoints.
4. Build Downloads tab and task controls.
5. Build Search tab and download action.
6. Build Subscriptions tab.
7. Add local Live Activity tracking from the app.
8. Add NASTOOL mobile API extensions for Phase B.
9. Add APNs device push and daily subscription digest.
10. Add remote ActivityKit push registration and updates.

## Decisions

- The primary connection model is public HTTPS access to the user's NASTOOL reverse proxy.
- The iOS app is not a server and does not need inbound network access.
- NASTOOL is the push sender for both regular notifications and Live Activity updates.
- Phase A ships value before APNs is available.
- Phase B depends on an active Apple Developer Program account and APNs credentials.
