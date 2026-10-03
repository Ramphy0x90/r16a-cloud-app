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
- 401 handling: `AuthInterceptor` logs out on 401, no refresh-and-retry yet.
- No Hive cache, no ETag interceptor yet.

## Status

- Done: theme, dock shell, auth (login/refresh/logout), session (`/user/me`), profile + preferences autosave.
- Dashboard: done, backed by `dashboard_api` + `dashboardProvider`.
- Files: browse done (plan Phase 4 steps 9–10): `files_api`, 60s memory `files_cache`, `FilesController`
  (tabs, folder stack, sort, cursor paging), grid/list UI, options sheet. Shared tab is a flat list
  (folders there don't open). Thumbnails (`ThumbnailCache`: 400 LRU, 5 min, 4 concurrent) + blurhash
  via custom `ImageProvider`s in `file_images.dart`; tapping an image opens `FileViewerScreen`
  (photo_view, swipe between the folder's images). Mutations: create folder, rename, share
  (`shareCandidatesProvider`, `SessionApi.listUsers`), delete + bulk delete, selection mode
  (options "Select" or long-press menu); prompts/snackbars in `file_actions.dart`, cache invalidated
  on every mutation. Upload: `FileUploader` (multipart ≤ 100 MB, else chunked init/parts/complete,
  streamed via `UploadSource.openRead`), `UploadController` (2 concurrent, inline progress + errors
  banners), pickers in `upload_picker.dart` (file_picker / image_picker, behind `uploadPickerProvider`).
  Download: `FileDownloads` (background_downloader): token link for one file, zip `POST /fs/download`
  otherwise; tap non-image → temp copy + system "open with"; save → Android Downloads (+ notification),
  iOS share sheet. Download in long-press menu and selection (also on Shared tab).
  Pending: delta sync, Hive + ETag.
- Photos: placeholder screen.

Update this section when a phase step lands.

## Architecture

```
lib/
  app/        app.dart (MaterialApp, auth gate, theme mode), shell/ (dock), theme/
  core/       auth/, config/env.dart, network/ (dio, interceptor, ApiException),
              session/ (CurrentUser, currentUserProvider), util/, widgets/
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
- OAuth redirect scheme `cloud.r16a.r16acloudapp` is defined in **three** places: `env.dart`,
  `android/app/build.gradle.kts` (`appAuthRedirectScheme`), `ios/Runner/Info.plist`. Change all or none.

## Rules

- **Ask before**: adding a dependency not listed in plan §3, adding codegen, adding go_router,
  changing auth flow, touching `android/`/`ios/` config beyond what a plugin's install docs require.
- Never edit the sibling repos. If the backend seems to need a change, stop and say so.
- Never commit tokens, real user data, or prod-only secrets (the OIDC client id is public/PKCE and fine).
- Don't mark work done until `flutter analyze` is clean and `flutter test` passes. Report what you ran.
- Large features: propose a plan first (which plan step, files to add/change, web files you ported from).
