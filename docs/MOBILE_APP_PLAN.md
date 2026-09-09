# R16a Cloud — Flutter Mobile App Plan

Status: draft for incremental execution
Source of truth for parity: `r16a-cloud_client` (Angular 21 PWA)
Backend: `r16a-cloud` (Spring Boot, stateless OAuth2 resource server / JWT)

---

## 1. Goal

A native mobile client (Android + iOS) that mirrors the web app feature‑for‑feature,
but replaces web idioms with native ones:

| Web idiom | Mobile equivalent |
| --- | --- |
| Hamburger button + slide‑in drawer (`nav-bar`) | Persistent **bottom dock** (nav bar) with 4 destinations |
| Top `app-header` with avatar button | Per‑screen `AppBar`; avatar/title contextual, profile reachable from dock |
| Drag & drop upload | FAB / dock action → system file picker + camera + photo picker |
| `<a download>` / blob download | Native download to device storage + progress notification, "Open with" sheet |
| Hover menus (`file-options`, `file-options` "…") | Long‑press context menu + bottom sheets |
| Image preview modal overlay | Full‑screen hero route with pinch‑zoom + swipe between items |
| Right‑side toolbar buttons | Contextual `AppBar` actions + selection `AppBar` |
| IndexedDB listing cache | Hive/Isar persistent cache |
| `blurhash` canvas placeholder | `flutter_blurhash` |

Requirements fixed for this iteration:

- **Feature‑oriented file structure** (see §4).
- Mobile‑first (phone). Tablet/landscape = best effort, not a goal.
- State management: **Riverpod**.
- Caching: **match the web app** (in‑memory + persistent listing cache, 10s delta‑sync
  polling, thumbnail LRU cache).
- File I/O: **full native** — system/photo/camera pickers for upload; background‑capable
  downloads with progress notifications and share/open sheet.
- Platforms: **Android + iOS**, both built and tested from the start.

---

## 2. Backend contract (already implemented — do not change)

Base URL: `https://cloud.r16a.cloud/api` (prod) / `http://localhost:8080/api` (dev).
All endpoints require `Authorization: Bearer <access_token>` **except** `/api/fs/download/token`.

### Auth
- OIDC / OAuth2 against Authentik: `https://auth.r16a.cloud/application/o/<client>`
- Backend is a pure JWT resource server (`SessionCreationPolicy.STATELESS`), validates via JWKS.
- Scopes used by web: `openid profile email offline_access` (refresh tokens enabled).
- **A dedicated native OIDC client must be created in Authentik** (redirect URI =
  `cloud.r16a.app://oauth/callback` or similar; PKCE public client, no secret).
  → track as a prerequisite task; do not reuse the web client IDs.

### Users — `/api/user`
| Method | Path | Notes |
| --- | --- | --- |
| GET | `/me` | current internal user (id, username, email, displayName, role, preferences, timestamps) |
| PATCH | `/me/preferences` | `{ preferences: { preferredTheme, encryptFilesByDefault, defaultViewMode } }` (partial) |
| GET | `/` | `Page<UserResponse>` — used for the share picker |

### Files — `/api/fs`
| Method | Path | Notes |
| --- | --- | --- |
| GET | `/` | `?ownerId&parentId?&sort=name|updatedAt&dir=asc|desc&limit&cursor?` → `CursorPageResponse<File>`; supports ETag / 304 |
| GET | `/shared-with-me` | Spring `Pageable` (`page,size,sort=isDirectory,desc&sort=<field>,<dir>`) → `Page<File>` |
| GET | `/dashboard` | `?ownerId` → `{ metrics: {uploadedFiles, usedStorageBytes, sharedFiles, uploadedPhotos}, recentFiles: [...] }` |
| GET | `/{id}` | single file |
| POST | `/` | create (folder): `{ name, ownerId, parentId?, isDirectory, visibility?, sharedWithIds? }` |
| POST | `/upload` | multipart: `ownerId, parentId?, file, description?, visibility?, sharedWithIds?` (small files) |
| POST | `/upload/init` → PUT `/upload/{id}/part` (octet-stream) → POST `/upload/{id}/complete` | chunked upload; web threshold = **100 MB** |
| GET | `/upload/{id}/status`, DELETE `/upload/{id}` | resumable-upload support |
| PUT | `/{id}` | update: `{ name?, description?, parentId?, visibility?, sharedWithIds? }` (rename / move) |
| PATCH | `/{id}/sharing` | `{ sharedWithIds: string[] }` |
| DELETE | `/{id}` | delete (204; treat 404 as success) |
| GET | `/{id}/download` | streams bytes, supports `Range` |
| GET | `/{id}/thumbnail` | `?size=small|medium|large`; immutable, 1‑year cache, ETag |
| POST | `/download` | `{ ids: string[] }` → zip stream |
| GET | `/{id}/download-token` → GET `/download/token?token=` | short‑lived (5 min) unauthenticated download URL |
| GET | `/events` | `?ownerId&since=<epochMs>&limit` → `{ events:[{fileId,parentId,fileName,eventType,occurredAt}], nextCursor, hasMore }` — delta sync |

### Photos — `/api/photos`
| Method | Path | Notes |
| --- | --- | --- |
| GET | `/years` | `?ownerId` → `[{ year, count }]` |
| GET | `/` | `?ownerId&year&cursor?&limit(=60)` → `CursorPageResponse<File>` |

### Core DTOs (mirror in `core` / feature `domain`)
```
File { id, name, description?, fsPath, isDirectory, visibility: PRIVATE|PUBLIC|SHARED,
       parentId?, ownerId, ownerDisplayName, sharedWithIds: string[],
       createdAt, updatedAt, takenAt?, blurHash? }
CursorPageResponse<T> { content: T[], nextCursor?, hasMore }
UserResponse { id, username, email, displayName, role, preferences, createdAt, updatedAt }
UserPreferences { preferredTheme: light|dark, encryptFilesByDefault: bool, defaultViewMode: grid|list }
DashboardResponse { metrics, recentFiles: [{ id, name, visibility, sizeBytes, updatedAt }] }
```
Helpers to port from `utils/`:
- `isImageFile` → `/\.(avif|bmp|gif|heic|heif|jpe?g|png|svg|webp)$/i`
- `isVideoFile` → `/\.(avi|m4v|mkv|mov|mp4|webm)$/i`
- `iconFromExtension`, `fileSize` (1024 units), `getUserInitials`.

---

## 3. Tech stack

| Concern | Package | Rationale |
| --- | --- | --- |
| State | `flutter_riverpod` + `riverpod_annotation` / `riverpod_generator` | async/stream‑first, matches RxJS+ngrx model |
| Navigation | `go_router` with `StatefulShellRoute.indexedStack` | bottom dock with per‑tab navigation state preserved |
| HTTP | `dio` + `pretty_dio_logger` | interceptors for auth + ETag; progress callbacks |
| OIDC / PKCE | `flutter_appauth` | Authentik authorization‑code + refresh |
| Secure token storage | `flutter_secure_storage` | Keychain / Keystore |
| Persistent cache | `hive_ce` (or `isar`) | listing cache, TTL entries, prefix eviction |
| Blurhash | `flutter_blurhash` | placeholder parity |
| Thumbnails / image cache | `cached_network_image` + custom `BaseCacheManager` that injects the bearer header | LRU disk cache w/ auth |
| File picking | `file_picker`, `image_picker` | uploads |
| Downloads / background | `background_downloader` | resumable, progress notifications, works backgrounded |
| Share / open | `share_plus`, `open_filex` | "Open with" after download |
| Photo zoom | `photo_view` | pinch‑zoom + swipe gallery |
| Video playback | `video_player` + `chewie` (phase 2) | video preview |
| Local notifications | bundled with `background_downloader` | transfer progress |
| Env / flavors | `--dart-define` + `envied` (optional) | dev vs prod config |
| Lint | `flutter_lints` (already present) | |
| Codegen | `build_runner`, `freezed`, `json_serializable` | immutable DTOs / unions |
| Tests | `flutter_test`, `mocktail`, `patrol` (optional e2e) | |

---

## 4. Project structure (feature‑oriented)

```
lib/
  main.dart                       # bootstrap: ProviderScope, Hive init, runApp
  app/
    app.dart                      # MaterialApp.router, theme, locale
    router/
      app_router.dart             # GoRouter + StatefulShellRoute (dock)
      routes.dart                 # route name/path constants (mirror web ROUTES)
      auth_redirect.dart          # redirect guard (unauth -> /login)
    shell/
      scaffold_with_dock.dart     # bottom nav dock shell
      dock_destinations.dart      # 4 items: Dashboard, Files, Photos, Profile
    theme/
      app_theme.dart              # light + dark ColorScheme from web CSS tokens
      app_colors.dart             # --colour-* -> Dart constants
      app_typography.dart         # Rubik font

  core/
    config/
      env.dart                    # apiBaseUrl, oidc issuer/clientId/redirect, flavor
    network/
      dio_client.dart             # Dio factory + base options
      auth_interceptor.dart       # attach bearer, refresh on 401, retry
      etag_interceptor.dart       # If-None-Match / 304 handling for listings
      api_exception.dart          # normalized errors
    auth/
      token_store.dart            # secure storage of tokens + expiry
      oidc_service.dart           # flutter_appauth wrapper (login, refresh, logout)
      auth_controller.dart        # Riverpod: AuthState (unknown/authed/unauthed)
    storage/
      hive_boxes.dart             # box names, open/registration
      cache_entry.dart            # { data, storedAt } + TTL helpers
    cache/
      image_auth_cache_manager.dart   # cached_network_image manager w/ bearer
    model/
      cursor_page.dart            # CursorPageResponse<T> (freezed)
      page.dart                   # Spring Page<T>
    util/
      file_type.dart              # isImageFile / isVideoFile / iconFor
      formatters.dart             # fileSize, dateShort, initials
      result.dart                 # typed success/failure (optional)
    widgets/
      app_error_view.dart
      app_empty_state.dart
      app_loading.dart            # spinner parity
      blurhash_image.dart         # blurhash -> thumbnail -> full, with fade
      confirm_sheet.dart          # reusable confirm bottom sheet
      text_input_sheet.dart       # reusable single-field sheet (create folder / rename)

  features/
    auth/
      presentation/
        login_screen.dart         # "Sign in with R16a" -> oidc login
        callback_screen.dart      # (deep-link handler; usually handled by appauth)
    dashboard/
      data/
        dashboard_api.dart
        dashboard_repository.dart
      domain/
        dashboard.dart            # metrics + recent files entities
      presentation/
        dashboard_screen.dart
        dashboard_providers.dart
        widgets/
          metric_card.dart
          recent_file_tile.dart
    files/
      data/
        files_api.dart            # raw dio calls
        files_repository.dart      # orchestrates api + cache + delta sync
        files_cache.dart          # in-memory + Hive, keyed by owner/parent/sort
        upload_service.dart       # multipart + chunked (100MB threshold)
        download_service.dart     # background_downloader integration
        delta_sync_service.dart   # 10s polling of /events, folder-changed stream
      domain/
        file_entity.dart          # File (freezed)
        file_enums.dart           # Visibility, ViewMode, SortField, SortDirection
        files_repository.dart     # abstract interface
      presentation/
        files_screen.dart         # tabs: My files | Shared with me
        file_browser_providers.dart  # folder stack, sort, view mode, selection
        selection_controller.dart
        widgets/
          files_app_bar.dart      # normal + selection modes (toolbar parity)
          breadcrumb_bar.dart     # back-chip parity (shows parent name)
          file_grid.dart
          file_list.dart          # sliver/virtualized
          file_tile.dart          # grid & list tile variants
          file_options_sheet.dart # sort / view / select (file-options parity)
          file_context_sheet.dart # per-file: open, download, rename, share, delete
          upload_sheet.dart       # choose: files / photo / camera
          upload_progress_banner.dart
          create_folder / rename  -> use core text_input_sheet
          share_sheet.dart        # user multi-select
      shared/
        shared_with_me_providers.dart  # flat paged list (reuses file widgets)
    photos/
      data/
        photos_api.dart
        photos_repository.dart     # years + per-year cursor pages + merge shared
      domain/
        year_section.dart
      presentation/
        photos_screen.dart        # year sections, lazy per-section load
        photos_providers.dart
        photo_grid.dart
        photo_viewer_screen.dart  # full-screen pinch-zoom + swipe gallery
    profile/
      data/
        profile_repository.dart    # wraps user api /me + /me/preferences
      presentation/
        profile_screen.dart        # identity card, preferences, logout
        profile_providers.dart
        widgets/
          preference_row.dart
          theme_selector.dart
          toggle_row.dart

  shared/  (optional)  # only if something is truly cross-feature beyond core

test/
  ... mirrors lib/ (unit: repositories, cache, formatters; widget: tiles, screens)
```

Conventions:
- Each feature owns `data / domain / presentation`. No feature imports another feature's
  `data` or `presentation` — cross‑feature reuse goes through `core` or a feature's `domain`.
- Providers live next to the screen that owns them; repositories are `core`‑style singletons
  exposed via provider.
- DTOs: `freezed` + `json_serializable`, one file per entity.

---

## 5. Screen‑by‑screen spec

### 5.0 App shell / dock
- `StatefulShellRoute.indexedStack` with 4 branches. Bottom `NavigationBar` (Material 3)
  styled to the R16a palette; labels + `bootstrap`‑equivalent icons
  (house, cloud, images, person). Center‑of‑gravity: Files.
- Dock hidden on full‑screen routes (photo viewer, login).
- Selection mode in Files does **not** hide the dock; instead the Files `AppBar` swaps to a
  selection app bar (parity with `toolbar--selecting`).
- Theme reacts to `UserPreferences.preferredTheme`; also honor system theme as fallback
  before `/me` resolves.

### 5.1 Login  (`/login`) — **new, no web equivalent**
Web relies on route‑guard redirect; mobile needs an explicit entry screen.
- Branding (identity logo — reuse `bg-0.svg` / `Sixtyfour` font wordmark).
- Single primary button → `OidcService.login()` (flutter_appauth, PKCE).
- On success: persist tokens, route to `/dashboard`.
- Handles: cancel, network error, IdP error. Loading overlay parity with web
  `auth-redirect-overlay`.
- Auto‑skip if a valid/refreshable token already exists (`auth_redirect.dart`).

### 5.2 Dashboard  (`/dashboard`)
Parity with `pages/dashboard`.
- **Metrics grid**: 4 `MetricCard`s (2×2 on phone):
  Used storage (`fileSize(usedStorageBytes)`), Files uploaded, Photos & videos, Shared files.
  Accent colours from web (`#e23636`, `#f59e0b`, `#10b981`, `#8b5cf6`).
- **Recent files**: list of up to N rows — icon, name, visibility chip, size, relative date.
  Tap → open in Files at that file's folder (or preview if image). "View all" → Files tab.
- States: loading (spinner), error ("Could not load dashboard data right now."), empty
  ("No files uploaded yet.").
- Pull‑to‑refresh.

### 5.3 Files  (`/files`)
Parity with `pages/files` + `files-toolbar` + `grid-view` + `list-view`.

**Layout**
- `AppBar`:
  - Normal mode: title = current folder name or "My files"; actions = `file_options_sheet`
    trigger (⋮), new‑folder, upload.
  - At root: segmented control / tabs **My files | Shared with me** (parity with
    `filter-tabs`). In a subfolder: back‑chip breadcrumb showing parent name (parity with
    `breadcrumb.html`), tapping it pops one level; long‑press → jump to root.
  - Selection mode: leading ✕ (cancel), title = "N selected", actions =
    download / (share, rename when N==1) / delete. Shared tab is read‑only → only download.
- Body: `grid` or `list` view (persisted via `defaultViewMode` preference, toggle in options
  sheet). List view virtualized (`SliverList`/`ListView.builder`). Grid = responsive
  `SliverGridDelegateWithMaxCrossAxisExtent`.
- Infinite scroll: load next cursor page when near bottom (parity with `inViewport`
  sentinel). Shared‑with‑me is a flat non‑cursor `Page` (uses `page/size`).
- Drag & drop overlay is dropped (desktop‑only); replaced by upload sheet.

**Interactions**
- Tap folder → push into folder (folder stack in provider; `AppBar` + breadcrumb update).
- Tap image/video → photo viewer route (hero). Tap other file → context sheet (with Open/
  Download).
- Long‑press any file → `file_context_sheet`: Open, Download, Rename, Share, Delete
  (Rename/Share/Delete hidden on shared tab).
- Multi‑select: enter via options sheet "Select" or long‑press → tap toggles; batch
  download / delete; single‑selection share/rename.
- Upload: dock/AppBar action → `upload_sheet` → Files picker / Photo library / Camera →
  `upload_service`:
  - < 100 MB: multipart `POST /upload` with progress.
  - ≥ 100 MB: chunked init/part/complete.
  - Concurrency 2 (web parity). `upload_progress_banner` shows `i/n — name` + overall bar.
    Per‑file errors surfaced in a dismissible banner.
  - Post‑upload: invalidate folder cache + refresh.
- Create folder / Rename: `text_input_sheet`. Delete / bulk delete: `confirm_sheet`
  (404 treated as success).
- Share: `share_sheet` — load users via `GET /api/user`, exclude self + owner, checkbox
  list, `PATCH /{id}/sharing`.

**Caching & sync (match web)**
- `files_cache`: key = `owner::parent::sort::dir::limit`; in‑memory entry (60s TTL) +
  Hive persistent entry (5 min TTL). First page served from Hive instantly, then network.
- ETag: send `If-None-Match`; on 304 keep cached page.
- `delta_sync_service`: start on Files mount with `ownerId`; poll `GET /events` every 10s
  from `now`; on events touching the current `parentId`, invalidate + silent refresh.
  Stop on unmount.
- Folder‑cache invalidation on every mutation (create/rename/delete/share/upload).

**States**: loading spinner; empty ("No files yet" / "Nothing shared with you yet");
per‑action error toasts/snackbars.

### 5.4 Photos  (`/photos`)
Parity with `pages/photos`.
- Vertical list of **year sections** (newest first). Each: header (`year` + count), then a
  tight 3–6 column grid (columns by width: <480→3, <768→4, <1200→5, else 6 — same
  breakpoints).
- Lazy loading: a section loads its first page when it scrolls near the viewport
  (parity `year-load-trigger`); "load more" per year on cursor. Pre‑reserve height from
  count to keep scroll stable (`gridHeight` computation port).
- Thumbnails: bounded parallelism (6), blurhash placeholder → small thumbnail; cancel
  fetch when scrolled away.
- Shared photos merged in by year (`/fs/shared-with-me` filtered to media,
  year from `takenAt ?? createdAt`), with a "people" badge; video badge for videos.
- Tap → `photo_viewer_screen`: full‑screen, pinch‑zoom (`photo_view`), swipe between
  photos in that section, download / share actions, caption = file name.
- States: loading, empty ("No photos yet").
- Pull‑to‑refresh re‑fetches years.

### 5.5 Profile  (`/profile`)
Parity with `pages/profile`.
- **Identity card**: avatar (initials), display name, `@username`; read‑only display name
  & username fields.
- **Preferences** (auto‑save, 300 ms debounce, `PATCH /me/preferences`, optimistic with
  error revert — parity):
  - Default theme: light / dark (applies app‑wide immediately).
  - Default file view: grid / list.
  - Encrypt files by default: toggle (`toggle_row`).
  - Error line: "Could not save preferences. Please try again."
- **Authentication**: Logout button → `OidcService.logout()` (end session + wipe token
  store + clear caches) → `/login`.
- Optional additions (native): app version, clear cache, open system notification settings.

---

## 6. Cross‑cutting behavior parity

| Area | Web | Mobile |
| --- | --- | --- |
| Auth bootstrap | `checkAuth()` in app initializer; guard calls `authorize()` | `auth_redirect` resolves token on launch; refresh if expired; else `/login` |
| 401 handling | oidc silent renew + `unauthorizedRoute` | `auth_interceptor`: refresh once & retry; on failure → logout → `/login` |
| Theme | body class from `preferredTheme` | `ThemeMode` from preference (fallback: system) |
| Preferences store | ngrx `app` feature | `authController` + `profileProviders`; cached in Hive for instant launch |
| Thumbnails | blob URLs, in‑mem LRU (400), 5 min TTL | `image_auth_cache_manager` disk LRU + memory; blurhash first |
| Listing cache | memory + IndexedDB | memory + Hive (same keys/TTLs) |
| Delta sync | 10s `/events` poll | same; pause when app backgrounded, catch‑up on resume |
| Downloads | `<a>` blob / signed token | `background_downloader` to app docs / MediaStore; notification; "Open with" |
| Large upload | chunked > 100 MB | same thresholds & endpoints; pause/resume optional phase 2 |
| Errors | `console.error` + inline states | snackbars + inline error views + Sentry‑style logger (optional) |

---

## 7. Delivery phases (incremental — "little by little")

Each phase should end compiling, runnable on both platforms, and with its slice tested.

**Phase 0 — Foundation**
1. `pubspec` deps; analysis options; folder skeleton (§4); `--dart-define` env; app flavors.
2. `core/network` (Dio + interceptors stubbed), `core/model`, `core/util` (formatters,
   file_type), `core/widgets` (loading/empty/error).
3. `app/theme` — port `--colour-*` tokens to light/dark `ColorScheme`; Rubik + Sixtyfour fonts.
4. `app/router` + `scaffold_with_dock` with 4 placeholder screens + bottom dock.

**Phase 1 — Auth**
5. Authentik native client (prereq, external). `core/auth`: `oidc_service`, `token_store`,
   `auth_controller`, `auth_interceptor` (bearer + refresh + retry), `auth_redirect`.
6. `features/auth` login screen; end‑to‑end sign‑in → `/dashboard`; logout.

**Phase 2 — Dashboard**
7. `dashboard` data/domain/presentation; metric cards + recent list; states; pull‑to‑refresh.
   (First real end‑to‑end API screen — proves networking + auth.)

**Phase 3 — Profile**
8. `profile` screen; `/me` load; preferences auto‑save with debounce + revert;
   theme switching live; logout wired.

**Phase 4 — Files: browse (read‑only)**
9. `files_api`, `files_repository`, `files_cache` (memory + Hive), ETag interceptor.
10. `files_screen` grid/list, folder navigation, breadcrumb back‑chip, infinite scroll,
    view/sort options sheet, My files / Shared‑with‑me tabs.
11. Image/video tap → basic `photo_viewer_screen`.

**Phase 5 — Files: mutate**
12. Create folder, rename, delete, bulk delete (selection mode + selection AppBar).
13. Share sheet (user list + `PATCH sharing`).
14. Cache invalidation on mutations.

**Phase 6 — Files: transfer**
15. `upload_service` (multipart + chunked, concurrency 2, progress banner, error banner);
    upload sheet (files / photo / camera).
16. `download_service` via `background_downloader` (single + zip batch), notifications,
    "Open with" sheet.

**Phase 7 — Delta sync**
17. `delta_sync_service` 10s polling; lifecycle‑aware pause/resume; silent refresh on
    folder‑changed.

**Phase 8 — Photos**
18. `photos_repository` (years + per‑year cursor + shared merge); year sections with lazy
    load + height reservation; bounded thumbnail fetch.
19. Full‑screen photo viewer: pinch‑zoom, swipe gallery, download/share.

**Phase 9 — Polish**
20. Empty/error states pass, haptics, transitions, app icons & splash, offline banner,
    "clear cache", crash/error logging, store metadata.
21. Test pass: repository unit tests, cache tests, key widget tests; manual QA matrix
    (Android + iOS, light/dark, slow network, large file, expired token).

---

## 8. Open prerequisites / decisions to confirm as we go

- [ ] **Authentik**: create a native/public OIDC client (PKCE, custom‑scheme redirect).
      Need client ID + redirect URI + whether `offline_access` is allowed for public clients.
- [ ] Deep‑link scheme / Universal Links vs custom scheme for the OAuth redirect.
- [ ] Hive vs Isar for the persistent cache (default: Hive CE — lighter).
- [ ] Android download destination: app‑scoped storage vs MediaStore/Downloads (default:
      MediaStore Downloads via `background_downloader`).
- [ ] Video preview in‑app now or phase 2 (default: phase 2; until then "Open with").
- [ ] Whether to add biometric app‑lock (not in web; possible native add‑on).
- [ ] Package id / bundle id (`cloud.r16a.app`?) and display name.

---

## 9. Non‑goals (this iteration)
- Tablet‑optimized master/detail layout.
- Desktop (macOS/Windows/Linux) targets.
- Offline **mutations** / write queue (reads are cached; writes require connectivity).
- Resumable upload pause/resume UI (endpoints exist; wire later).
- Public share links UI beyond user‑to‑user sharing.
