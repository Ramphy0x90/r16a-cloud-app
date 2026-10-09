# r16a-cloud-app

Flutter mobile client (Android + iOS) for **R16a Cloud**, a self-hosted file cloud (iCloud-like).
Goal: feature parity with the Angular web client, using native mobile idioms.

## Sibling repos (read them, don't guess)

| Repo                | Path                   | Role                                                                                           |
| ------------------- | ---------------------- | ---------------------------------------------------------------------------------------------- |
| `r16a-cloud`        | `../r16a-cloud`        | Spring Boot 4 / Java 21 backend. **The API contract. Never change it from here.**              |
| `r16a-cloud_client` | `../r16a-cloud_client` | Angular 21 PWA. **Source of truth for behavior** (caching, TTLs, debounce, copy text, colors). |

Before implementing a feature, read the matching web code (`src/app/pages/<feature>`, `src/app/services`,
`src/app/types`) and the backend controller/DTO (`src/main/java/com/r16a/r16a_cloud/{file,photo,user}`).
Port behavior and values 1:1 unless the plan says to replace a web idiom.

Truth order when sources disagree: **backend code > web client code > this repo's code > `docs/MOBILE_APP_PLAN.md`**.

## Commands

```bash
flutter pub get
flutter analyze            # must be clean
flutter test               # must pass
dart format lib test

# Run against local backend (default: http://localhost:8080/api, Android emulator -> 10.0.2.2)
flutter run
# Run / build against prod (values mirror the web's environment.prod.ts)
flutter run --dart-define-from-file=config/prod.json
flutter build apk --release --dart-define-from-file=config/prod.json
# Release builds without these defines throw at startup (Env.checkReleaseConfig).

# Release build (Android): needs android/key.properties + upload keystore (see
# android/key.properties.example; both git-ignored). Without it the build falls back to the
# debug key and logs a warning — Google Play rejects that.
flutter build appbundle --release --dart-define-from-file=config/prod.json

# Launcher icon + native splash (after changing assets/imgs/domovoy-logo-*.svg)
flutter test tool/branding/render_branding_test.dart   # SVG -> assets/branding/*.png
dart run flutter_launcher_icons                          # config: flutter_launcher_icons.yaml
dart run flutter_native_splash:create                    # config: flutter_native_splash.yaml
cp assets/branding/web/*.png ../r16a-cloud_client/public/icons/   # web PWA icons
flutter test tool/branding/render_store_graphics_test.dart   # Play icon + feature graphic
# flutter_launcher_icons rewrites ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS
# in ios/Runner.xcodeproj/project.pbxproj to "AppIcon" — revert that hunk (must stay YES).
```

Local backend: `cd ../r16a-cloud && docker compose up` (app + MySQL + Redis on :8080).

## The plan

`docs/MOBILE_APP_PLAN.md` holds the full spec: endpoints (§2), screen specs (§5), parity table (§6), phases (§7).
Work **one phase step at a time**. Each step ends compiling, analyzed and tested.

The plan is partly ahead of / different from the code. **Current code wins**; these are known gaps:

- Navigation: `HomeShell` + `IndexedStack` + custom `Dock`, auth gating via `switch` in `app.dart`.
  **No `go_router` yet.** Don't introduce it without asking.
- Models: hand-written `fromJson` / `copyWith`. **No `freezed` / `json_serializable` / codegen yet.** Don't introduce without asking.
- OIDC: reuses the existing `r16a-cloud-local` Authentik provider with an added redirect URI
  (see `core/config/env.dart`), not a dedicated client as plan §2 says.
- 401 handling: `AuthController` refreshes 30s before expiry, single-flight (parallel requests share one
  refresh). `AuthInterceptor` retries a 401 once after `refreshAfterRejection` (not streamed/multipart
  bodies). Only an OAuth rejection of the refresh token (`invalid_grant`…) ends the session, locally
  (no browser end-session); a refresh that can't reach Authentik keeps it and fails the request as a
  connection error. Only the user's Profile logout calls the IdP end-session.
- Persistent cache: Hive (`hive_ce`) only for first pages of folder listings (`HiveListingStore`,
  wired in `main.dart`; tests use `MemoryListingStore`). ETag revalidation lives in `FilesCache` +
  `FilesApi.getFilesRevalidating`, not in a Dio interceptor. Backend folder ETag ignores deletes /
  moves-out, so every such change must go through `FilesCache.invalidateFolder`.

## Status

- Done: theme, dock shell, auth (login/refresh/logout), session (`/user/me`), profile + preferences autosave.
- Dashboard: done, backed by `dashboard_api` + `dashboardProvider`. "View all" switches to Files via
  `homeTabProvider` (core/navigation, drives `HomeShell`); tapping a recent file fetches `GET /fs/{id}`
  and opens it like Files (`openMediaFile`); 404 → "This file no longer exists." + dashboard reload.
- Files: browse done (plan Phase 4 steps 9–10): `files_api`, 60s memory `files_cache`, `FilesController`
  (tabs, folder stack, sort, cursor paging), grid/list UI, options sheet. Shared tab is a flat list
  (folders there don't open). Thumbnails (`ThumbnailCache`: 400 LRU, 5 min, 4 concurrent) + blurhash
  via custom `ImageProvider`s in `file_images.dart`; tapping an image opens `FileViewerScreen`
  (photo_view, swipe between the folder's images). Mutations: create folder, rename, share
  (`shareCandidatesProvider`, `SessionApi.listUsers`), delete + bulk delete, selection mode
  (options "Select" or long-press menu); prompts/snackbars in `file_actions.dart`, cache invalidated
  on every mutation. Move (mobile-only; long-press menu + selection bar): `showMoveDestinationSheet`
  browses folders (`folderChildrenProvider`, stops paging at the first file), `FilesApi.move` =
  `PUT /fs/{id}` `{name, parentId}`; invalidates source + target folders. **Can't move to root**: backend
  treats `parentId: null` as "unchanged" (needs a backend change); its move event also only names the
  target folder, so other devices don't see the source folder change until its cache expires. Upload: `FileUploader` (multipart ≤ 100 MB, else chunked init/parts/complete,
  streamed via `UploadSource.openRead`), `UploadController` (2 concurrent, inline progress + errors
  banners), pickers in `upload_picker.dart` (file_picker / image_picker, behind `uploadPickerProvider`).
  Download: `FileDownloads` (background_downloader): token link for one file, zip `POST /fs/download`
  otherwise; tap non-image → temp copy + system "open with"; save → Android Downloads (+ notification),
  iOS share sheet. Download in long-press menu and selection (also on Shared tab).
  Delta sync: `FileDeltaSync` polls `/fs/events` every 10s while the Files tab is visible (shell wraps
  tabs in `TickerMode`) and the app is foreground; catches up on resume; changed folders go through
  `FilesController.folderChanged`.
  Listing cache: memory 60s → Hive 5 min → network revalidated with the stored ETag (304 reuses it);
  cleared on sign-out from `app.dart`.
- Photos: done (plan Phase 8 step 18): `PhotosApi` (`/photos/years`, `/photos`, shared media via
  `/fs/shared-with-me`), `PhotosController` (year sections, lazy pages), grid with placeholder tiles that
  request the next page when laid out (keyed by loaded count so on-screen ones re-ask). Viewer has
  Download + "Share via…" (step 19). Refreshes itself (debounced) on `mediaRevisionProvider` bumps.
- Phase 9 (partial): user-visible name **Domovoi** (internal name stays R16a Cloud); `AppLogger`
  (core/logging) catches all errors, `AppLogger.reporter` is the hook for a crash service; offline
  detection from real traffic (`NetworkStatusInterceptor`) + banner above the dock, Files serves stored
  listings of any age while offline; Profile "Clear cache" (`clearCachesProvider`, extended in
  `main.dart`, also run on sign-out); shared `StatusMessage` for empty/error states; haptics on
  selection/delete; hero thumbnail → viewer (`filesHeroPrefix` / `photosHeroPrefix`).
  Launcher icon + native splash generated from the logo SVGs (see Commands).
- Video playback (mobile-only; web shows thumbnails): `FileViewerScreen` pages through images *and*
  videos; videos are a `VideoPage` (video_player + chewie) streamed from `videoSourceProvider` (5-min
  download-token URL, Range-capable, no bearer). Playback errors fetch a fresh link and resume (max 2);
  unplayable formats (MKV/AVI, WebM on iOS) fall back to "Open with another app" (`openWithOtherApp`).
  iOS dev against plain-http localhost would need ATS `NSAllowsLocalNetworking` (not added).
- Account deletion: Profile → "Delete account" (typed confirmation) → `DELETE /api/user/me` (backend
  `AccountDeletionService` erases files, storage, thumbnails, events, shares, uploads, user) → logout.
  The web client has the same flow (Profile → Delete account).
  Sign-up is invite-only via Authentik; the Authentik identity is removed manually by an admin.
- "Encrypt files by default" was removed everywhere (it never encrypted anything). Don't reintroduce
  encryption claims without real encryption.
- Privacy policy: web client page `/privacy` (public, marked draft until legally reviewed). App links to
  `Env.privacyPolicyUrl` (https://domovoi.cloud/privacy) from login + Profile via `url_launcher`.
  Keep it true: domovoi.cloud is behind Cloudflare; cloud.r16a.cloud (the app's API) and auth.r16a.cloud
  are not. Backend purges file events after 90 days (`FileEventRetentionTask`).
  Deferred by user: crash-reporting service.
- Play Store prep: `docs/PLAY_STORE.md` (blockers, listing text, App content + Data safety answers,
  permissions) and `docs/QA_CHECKLIST.md` (manual release QA). Changing what the app collects, sends or
  asks permission for means updating both that file and the web privacy policy. Profile shows
  "Version x.y.z (build)" (`appVersionProvider`, core/config, `package_info_plus` — approved).
  Store graphics: `assets/branding/store/` (rendered, see Commands).

Update this section when a phase step lands.

## Architecture

```
lib/
  app/        app.dart (MaterialApp, auth gate, theme mode), shell/ (dock), theme/
  core/       auth/, config/env.dart, network/ (dio, interceptor, ApiException),
              session/ (CurrentUser, currentUserProvider, users list), util/, widgets/,
              logging/ (AppLogger), cache/ (clearCachesProvider),
              model/ (FileItem — shared DTO),
              media/ (MediaApi: thumbnails/bytes/download links, ThumbnailCache, image
                      providers, FileViewerScreen, FileDownloads, FileThumbnail,
                      media_actions.dart: openMediaFile / saveMediaFiles / shareMediaFile)
  features/<name>/{data,domain,presentation}
```

- Features never import another feature's `data` or `presentation`. Share via `core` or a feature's `domain`.
- State: **Riverpod 3** (`Notifier` / `AsyncNotifier`, manual providers, no generator). Providers live next to their owner.
- HTTP: always via `dioProvider`. One API class per backend area; each method catches `DioException`
  and rethrows `ApiException.fromDioException(e)`. Widgets never see Dio.
- Owner id for listing/upload calls (`ownerId` query param) comes from `currentUserProvider`.
- Auth decisions go through `AuthController.getValidAccessToken()` only. Nothing else reads `TokenStore`.

## Conventions

- Doc-comment every class with what it mirrors on web/backend, e.g. ``/// Mirrors `DashboardResponse` (`types/file.ts`).``
  Keep this habit; it's how parity is traced.
- Reuse web copy text exactly (error/empty strings).
- Colors only from `AppColors` / `ColorScheme`. No hex literals in widgets.
- Bottom padding on tab screens must clear the floating dock (currently 120).
- Small, focused files. Widgets for a screen go in `presentation/widgets/`.

## Testing

- Unit-test API classes, controllers and any logic port (caching, TTLs, upload chunking, formatters).
- Use fakes, not platform channels: override `tokenStoreProvider` / `oidcServiceProvider`;
  stub HTTP with a custom `HttpClientAdapter` (see `test/core/network/auth_interceptor_test.dart`).
- **Every widget test that pumps `R16aCloudApp` must override `tokenStoreProvider`**, or secure storage hangs forever.
- Tests mirror `lib/` paths.

## API gotchas

- Base URL already ends in `/api`; paths are `/user/me`, `/fs/...`, `/photos/...`.
- `FileResponse.isDirectory` is serialized as `isDirectory`. Timestamps are ISO-8601 instants; ids are UUID strings.
- `/fs` listing is cursor-paged (`CursorPageResponse`, supports ETag/304); `/fs/shared-with-me` is Spring `Page` (`page,size,sort`).
- `DELETE /fs/{id}`: treat 404 as success.
- Uploads ≥ 100 MB use chunked `upload/init` → `PUT part` (octet-stream) → `complete`; below that, multipart `POST /upload`.
- `GET /fs/download/token` is the only unauthenticated endpoint.
- App id is **`cloud.domovoi.app`** on both platforms (Android `applicationId`/`namespace`, iOS
  `PRODUCT_BUNDLE_IDENTIFIER`). Permanent once published — never change it.
- OAuth redirect scheme `cloud.r16a.r16acloudapp` is defined in **three** places: `env.dart`,
  `android/app/build.gradle.kts` (`appAuthRedirectScheme`), `ios/Runner/Info.plist`. Change all or none.

## Rules

- **Ask before**: adding a dependency not listed in plan §3, adding codegen, adding go_router,
  changing auth flow, touching `android/`/`ios/` config beyond what a plugin's install docs require.
- Never edit the sibling repos. If the backend seems to need a change, stop and say so.
- Never commit tokens, real user data, or prod-only secrets (the OIDC client id is public/PKCE and fine).
- Don't mark work done until `flutter analyze` is clean and `flutter test` passes. Report what you ran.
- Large features: propose a plan first (which plan step, files to add/change, web files you ported from).
