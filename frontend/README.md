# Todo App â€” Flutter Web client

Frontend for the task management platform (see `../docs` for the system
architecture and API contract).

> **Phase 16 scope:** **enterprise UX polish** â€” a consistency audit of the
> Phase 10â€“15 design system with ten targeted fixes, no new features or
> dependencies. Duplicated UI consolidated into shared widgets (`AppInlineAlert`
> banner, `AppChoiceChip`/`AppFilterChip` status chips), the tasks search box
> rebuilt on `AppTextField`, `AppTextField` gained a `suffix` slot and hides
> character counters app-wide, the task-detail action gap and list-divider
> asymmetry fixed, auth/home battery pages migrated off legacy `AppColors`
> aliases to `context.appColors`, and two genuine **600 px** responsive
> overflows fixed (page-header action reflow, dashboard section-header wrap).
> A Flutter element-reuse animation bug (button text-style interpolation) found
> through the regression run was fixed with stable action keys. Responsive
> no-overflow is now verified at **390/600/768/1024/1280/1440**. Verified:
> analyze clean, 302/302 tests, web build OK. No backend changes.
>
> **Phase 15 scope:** **frontend â†” backend integration hardening** â€” an audit of
> every network surface against the documented API contract, with four genuine
> fixes: per-request `X-Correlation-Id` generation + echo capture (joinable
> server traces), error exceptions now carry the **outer-envelope** `path`/
> `timestamp` and the correlated trace id (previously dropped because the
> backend places those fields top-level, never inside `error`), `/api/v1/health`
> routes stay public in the authenticated transport (no bearer header, no
> 401-refresh retry), and the task search field caps input at the backend's 200
> char limit. The test mock's error envelope was corrected to the real wire
> shape so these defects can no longer be masked. Verified against the real
> backend: `mvn verify` green (135 ITs), analyze clean, 293/293 tests, web
> build OK. No backend changes.
>
> **Phase 14 scope:** **search, filters and sorting** on `/tasks` â€” the list
> stays fully server-backed with no local re-filtering. A debounced `search`
> field, status chips, an overdue-only toggle, an inclusive due-date range
> (bottom-sheet date pickers), a sort-field dropdown + direction toggle, and
> clear-search / clear-filters actions. Every control writes a single immutable
> query (`TaskListQuery`) that serialises to the `GET /api/v1/tasks` query
> parameters (`search`, `status`, `overdue`, `dueDateFrom`/`dueDateTo`, `sort`,
> `direction`, `page`, `size`) with stale-response discarding and duplicate
> request suppression.
>
> **Phase 13 scope:** the **real task-management UI** for `/tasks` â€” full CRUD
> replacing the placeholder route. One bounded, filterable task list (status +
> overdue-only chips, pagination, refresh/loading/error/empty states), a task
> detail deep link (`/tasks/{id}`) with lifecycle actions (start / complete /
> cancel), create + edit forms, and delete with confirmation. All writes go
> through the existing `/api/v1/tasks` endpoints with the correct wire contracts
> (full-PUT, minimal three-state PATCH, explicit-null clears); ownership and
> `completedAt` stay server-side.
>
> **Phase 12 scope:** the **real dashboard UI** for `/dashboard` â€” six metric
> cards, a native status distribution, overdue / recent / upcoming task
> previews, status + overdue-only filter chips, and refresh / loading / error /
> empty states. All data is owner-scoped and comes from the existing
> `GET /api/v1/dashboard` and `GET /api/v1/tasks` endpoints through the
> authenticated `ApiClient` (no new endpoints, no task CRUD).
>
> **Phase 11 scope:** the **login / register / profile UI** wired to the real
> backend APIs with an in-memory session. Auth-aware routing (protected /
> publicOnly guards), logout, form validation, error / loading / success states,
> responsive accessible pages, and a new test suite covering the auth + profile
> data / state / HTTP layers plus the page widgets.
>
> **Phase 10 scope:** the **completed design system**. Semantic design tokens
> (colors, spacing 4â€“64, radius, typography roles, elevation) exposed through a
> `ThemeExtension`, an expanded widget library (buttons w/ variants, cards,
> inputs, loading/empty/error states), an application **shell with responsive
> sidebar/drawer navigation** and page header, generic feedback components
> (snackbar, dialog, confirmation, badge, divider), and a live
> **`/design-system` showcase** route with gallery tests.

## Prerequisites

- Flutter stable (this project was created/verified with Flutter 3.47.4,
  Dart 3.13.3).
- The backend REST API running locally at `http://localhost:8080`
  (see `../docs/development-workflow.md`).
- **Docker + Docker Compose** (for the containerised stack; see below).

## Commands

```bash
cd frontend

# Resolve dependencies
flutter pub get

# Static analysis
flutter analyze

# Tests (unit + widget)
flutter test

# Run in a browser against the local backend
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080

# Production web build
flutter build web --dart-define=API_BASE_URL=https://api.example.com
```

## Docker

The frontend is containerised via a multi-stage Dockerfile:

- **Build stage:** Debian Bookworm downloads Flutter 3.47.4 from the official
  release tarball, resolves dependencies, and builds the Flutter Web release
  SPA. The backend URL is baked in at build time via `--dart-define`.
- **Runtime stage:** nginx 1.27 Alpine serves the static SPA with a fallback
  to `/index.html` so deep links (`/login`, `/tasks/{id}`) never return 404.

Build the image manually:

```bash
cd frontend
docker build -t todo-app-frontend:local .
```

Or let Docker Compose manage it (recommended):

```bash
cd infrastructure
docker compose up -d         # builds both backend + frontend images, starts the stack
docker compose ps            # all three containers should be "healthy"
```

The containerised frontend runs at `http://localhost:3000`. The backend
lives at `http://localhost:8080`. The SPA is configured to talk to
`http://localhost:8080` at build time — never to `http://backend:8080`.

## CI / CD

The GitHub Actions workflow (`.github/workflows/ci.yml`) enforces the exact
same gates locally and in CI. To reproduce the CI frontend checks locally:

```bash
cd frontend
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze --fatal-infos
flutter test --concurrency 8
flutter build web --dart-define=API_BASE_URL=http://localhost:8080
```

CI uses the pinned Flutter 3.47.4 stable SDK (`subosito/flutter-action@v2`),
never a floating latest release. See [`../docs/phase-19-report.md`](../docs/phase-19-report.md).

---

## Folder structure

```
frontend/
â”œâ”€â”€ web/                      # Web platform shell (HTML, manifest, icons)
â”œâ”€â”€ lib/
â”‚   â”œâ”€â”€ main.dart             # Entry point â†’ runApp(TodoApp)
â”‚   â”œâ”€â”€ app.dart              # Root MaterialApp (theme + router wiring)
â”‚   â”œâ”€â”€ core/                 # Cross-cutting, framework-agnostic logic
â”‚   â”‚   â”œâ”€â”€ config/           # AppConfig (dart-define based)
â”‚   â”‚   â”œâ”€â”€ constants/        # AppConstants (name, tagline)
â”‚   â”‚   â””â”€â”€ utils/            # responsive.dart (breakpoints, size classes)
â”‚   â”œâ”€â”€ data/                 # Global data/API plumbing (implemented)
â”‚   â”‚   â””â”€â”€ api/              # ApiClient, envelope/error/response models,
â”‚   â”‚                         # interceptors, ApiPaths
â”‚   â”œâ”€â”€ domain/               # Global domain contracts (reserved, later phases)
â”‚   â”œâ”€â”€ application/          # App-level state (reserved, later phases)
â”‚   â”œâ”€â”€ presentation/         # App shell
â”‚   â”‚   â”œâ”€â”€ router/           # AppRouter â€” the central route table
â”‚   â”‚   â””â”€â”€ screens/          # DesignSystemPage + route placeholder screens
â”‚   â”œâ”€â”€ shared/               # Reusable presentation primitives
â”‚   â”‚   â”œâ”€â”€ theme/            # design_tokens, colors, typography, theme, and
â”‚   â”‚   â”‚                     # theme_extensions (AppThemeTokens + appColors)
â”‚   â”‚   â””â”€â”€ widgets/          # AppButton, AppTextField, AppCard, AppLoading,
â”‚   â”‚                         # AppErrorState, AppEmptyState, AppScaffold,
â”‚   â”‚                         # AppShell, AppSidebar, AppPageHeader,
â”‚   â”‚                         # ResponsiveContainer, AppBadge, AppDivider,
â”‚   â”‚                         # AppSnackbar, AppDialog, AppConfirmationDialog,
â”‚   â”‚                         # AppInlineAlert, AppChoiceChip, AppFilterChip
â”‚   â””â”€â”€ features/             # Feature modules
â”‚       â”œâ”€â”€ auth/             #   data/  domain/  presentation/
â”‚       â”‚                     #   AuthState, AuthenticatedHttpClient, login,
â”‚       â”‚                     #   register, auth validators, profile API,
â”‚       â”‚                     #   profile models, profile page
â”‚       â”œâ”€â”€ profile/          #   presentation/ domain/ data/
â”‚       â”œâ”€â”€ dashboard/        #   data/ domain/ presentation/
â”‚       â”‚                     #   DashboardApi, dashboard models, DashboardPage
â”‚       â””â”€â”€ tasks/            #   data/ domain/ presentation/
â”‚                             #   TaskApi, task models + validators, TasksPage,
â”‚                             #   TaskDetailPage, TaskFormPage
â””â”€â”€ test/                     # Widget + unit tests
```

The layout is feature-first and clean-architecture inspired: `data`
implements contracts, `domain` holds platform-independent rules, `presentation`
owns screens, `shared` holds reusable primitives, `core` holds cross-cutting
concerns. Documentation for the layout philosophy lives in
`../docs/architecture.md` (Â§4).

## Configuration approach

All environment values are injected at **build/run time via dart-defines** â€”
never hardcoded and never committed as secrets:

| Define            | Default                | Purpose                        |
| ----------------- | ---------------------- | ------------------------------ |
| `API_BASE_URL`    | `http://localhost:8080`| Backend REST origin             |
| `APP_ENVIRONMENT` | `development`          | `development`/`staging`/`production` |
| `DEBUG_MODE`      | `true`                 | Debug affordances              |

Read them through `AppConfig` (`lib/core/config/app_config.dart`); the API
client resolves `AppConfig.apiBaseUrl` automatically.

**Security:** anything shipped to Flutter Web is publicly inspectable. JWT
secrets, database passwords, private keys and backend credentials must never be
placed in the client â€” they stay server-side. This is called out on
`AppConfig` itself.

## API foundation & error model

`lib/data/api` is ready for feature integration without containing any feature
endpoint:

- `ApiClient` â€” JSON requests (`get`/`post`/`put`/`patch`/`delete`), optional
  interceptors (auth-token injection, logging), timeout, and automatic parsing
  of the backend envelopes into typed `ApiResponse<T>` or a thrown
  `ApiException`. Every request sends a generated `X-Correlation-Id` (Phase 15)
  that the backend echoes back; the echo (and the top-level envelope
  `path`/`timestamp`) is carried on server-error exceptions so a failure can be
  joined to the backend's log line.
- `ApiError`/`ApiErrorDetail` mirror the documented backend error envelope
  (`success`, `error.code`, `error.message`, `error.details`, `timestamp`,
  `path`) â€” the frontend **parses** errors instead of hard-coding future codes.
- `ApiPaths.v1` centralizes the `/api/v1` prefix.

See `lib/data/README.md` for the inventory.

## Routing

Routes are centralized in `AppRouter` (`lib/presentation/router/app_router.dart`):

| Route        | Screen                     |
| ------------ | -------------------------- |
| `/`          | `HomePage` â€” session-aware landing |
| `/login`     | `LoginPage` â€” username/email sign-in |
| `/register`  | `RegisterPage` â€” new-account form |
| `/profile`   | `ProfilePage` â€” create / edit profile |
| `/dashboard` | `DashboardPage` â€” real dashboard (metrics, status, overdue, recent/upcoming tasks) |
| `/tasks`     | `TasksPage` â€” filterable, paginated task list with create entry-point |
| `/tasks/{id}`| `TaskDetailPage` â€” task detail with lifecycle + edit/delete (deep link) |
| `/design-system` | `DesignSystemPage` (pure showcase of tokens + components) |

Unknown routes fall back to `/`. The `AuthGuard` wrapper on every route
enforces access policy automatically:
- **publicOnly** (home, login, register, design-system): authenticated visitors
  are redirected to the landing page.
- **protected** (profile, dashboard, tasks): unauthenticated visitors are
  bounced to `/login` with the original destination preserved.

## Dashboard (Phase 12)

`/dashboard` is a polished, responsive productivity dashboard backed entirely
by the existing authenticated APIs â€” no new endpoints and no task CRUD:

- **Data** (`features/dashboard/data/dashboard_api.dart`) â€” `GET
  /api/v1/dashboard` for the six owner-scoped counters and `GET /api/v1/tasks`
  for bounded preview pages (recent `createdAt DESC`, overdue `overdue=true`,
  upcoming `dueDateFrom=today`). Requests run in parallel (`Future.wait`) and
  never download an unbounded list.
- **Models** (`features/dashboard/domain/dashboard_models.dart`) â€” mirror the
  exact `DashboardResponse` / `TaskResponse` / `TaskPageResponse` wire
  contracts. `OVERDUE` is a derived flag, not a status.
- **State** (`features/dashboard/presentation/dashboard_page.dart`) â€” plain
  `setState` (the Phase 11 lightweight approach); a refresh keeps content on
  screen, disables itself while in flight, and reports failures via snackbar.
- **Metric cards** â€” responsive 1/2/3-column grid of total / to do /
  in progress / completed / cancelled / overdue with screen-reader labels.
- **Status distribution** â€” four native, proportionally-filled status bars
  (no charting dependency).
- **Overdue / tasks** â€” danger-tinted overdue list (or "You're all caught up"),
  bounded recent + upcoming previews with status / overdue-only filter chips,
  and a "View all tasks" affordance that navigates to `/tasks`.
- **States** â€” `AppLoading`, `AppErrorState` with retry (safe, status-aware
  copy that never leaks backend detail), and `AppEmptyState` for every
  no-data section.
- **Responsive & accessible** â€” constraints-driven (390 â†’ 1440+), capped
  content width, semantic metric labels, keyboard-operable chips/buttons,
  48 px touch targets, and no color-only signalling.

See `features/dashboard/README.md` for the full module documentation.

## Tasks (Phase 13)

`/tasks` is full task management backed by the existing authenticated
`/api/v1/tasks` endpoints â€” no backend changes and no new packages:

- **Data** (`features/tasks/data/task_api.dart`) â€” `TaskApi` over the
  authenticated `ApiClient`: bounded list (page/size with optional
  `status`/`overdue` query params), get-by-id, create (full body,
  explicit-`null` description), update (full-replacement PUT), patch (partial,
  only-changed-fields with explicit-`null` clears), the dedicated
  status/complete/cancel endpoints, and delete.
- **Models** (`features/tasks/domain/task_models.dart`) â€” mirror the exact
  `TaskResponse` / `TaskPageResponse` contracts, including the server-owned
  `version` (optimistic-lock) and the derived `overdue` flag. `OVERDUE` is never
  a status. Validators (`task_validators.dart`) mirror the backend's 200/2000
  field limits.
- **List** (`tasks_page.dart`) â€” one 15-row page per fetch; filter chips
  (`All` / status / `Overdue only`) replace the whole selection and re-query;
  previous/next pagination with a total count; refresh that keeps content on
  screen and refuses overlaps; loading / error-with-retry / empty (incl.
  filter-empty with "Clear filters") states.
- **Detail** (`task_detail_page.dart`, deep link `/tasks/{id}`) â€” header card,
  lifecycle actions that disappear on terminal tasks, metadata timestamps, and
  safe copy for load/save failures. Recoverable errors (`INVALID_TRANSITION`,
  `OPTIMISTIC_LOCK_CONFLICT`) get a **Refresh** action instead of destructive
  auto-retry.
- **Form** (`task_form_page.dart`) â€” create and edit in one screen. Create
  normalizes blank description â†’ `null`; edit builds a minimal PATCH
  (strings set, explicit-`null` clears, untouched fields omitted) and stops with
  "No changes to save" when nothing changed. Due date is a timezone-free
  calendar day via `showDatePicker` with a clear affordance.
- **States & accessibility** â€” `AuthenticatedScaffold` shell, semantic task
  tiles (single merged label), keyboard-operable chips/buttons, 48 px targets,
  and verified no-overflow across 390 â†’ 1440+ px.

See `features/tasks/README.md` for the full module documentation.

## Tasks â€” search, filters & sorting (Phase 14)

Phase 14 extends the Phase 13 list without touching the backend or adding
packages: every filter, sort and search is a `GET /api/v1/tasks` query param.

- **Query model** (`features/tasks/domain/task_list_query.dart` â€”
  `TaskSortField`, `TaskListQuery`) â€” one immutable object owns the whole
  listing state: `page`/`size`, `sort` (allowlisted field) + `direction`, and the
  optional `status` / `dueDateFrom` / `dueDateTo` / `overdue` / `search`.
  `toQueryParams` sends only non-default values (`overdue=false` and blank
  search are omitted), `resetPage`/`clearFilters` keep pagination and sorting
  sane, and equality compares dates by calendar day.
- **Search** â€” debounced (300 ms) `TextField` with a clear button. Rapid
  keystrokes coalesce; every fetch is tagged with a request id and stale
  responses are discarded. Search + filters combine in one request, and a no-hit
  search shows a dedicated empty state with a one-tap clear.
- **Filters** â€” status `ChoiceChip`s, an `Overdue only` `FilterChip`, and a due
  date range action chip opening a bottom sheet with two `showDatePicker`s
  (inclusive `dueDateFrom`/`dueDateTo`, `Clear dates`, Apply). An invalid
  `from > to` range shows an inline error and skips the fetch.
- **Sort** â€” a `DropdownButton` over the backend allowlist plus a direction
  toggle (ASC/DESC), defaulting to `createdAt DESC`.
- **Responsive** â€” the controls use `Wrap`s so chips/buttons reflow at compact
  widths instead of overflowing; verified no-overflow from 390 â†’ 1440+ px.
- **Data** â€” `TaskApi.listTasksFromQuery(TaskListQuery)` unpacks the query into
  the endpoint's query parameters (the Phase 13 `listTasks` overload stays for
  back-compat). The test mock implements the same contract so widget tests
  exercise real server-backed filtering/sorting/search.

## Design system

`lib/shared/theme/` holds every visual token â€” colors (`AppColors`),
typography (`AppTypography`), spacing/radius/sizes/shadows
(`design_tokens.dart`) â€” and the assembled `AppTheme.light()` `ThemeData`:

- soft neutral/pastel surfaces on a warm paper background (`#F6F5F2`),
- a semantic color set (primary/secondary/text/feedback/border roles) exposed
  both on `AppColors` and as `AppThemeTokens`, a `ThemeExtension` readable via
  `context.appColors`,
- strong type hierarchy (`displayLarge â€¦ labelSmall` role ladder),
- rounded inputs and cards, generous spacing, subtle shadows,
- dark-ink primary CTA with focused/hover/disabled states,
- component themes for buttons, inputs, cards, dialogs, snackbars, chips,
  tooltips and the app bar.

Dark mode is intentionally deferred; the polished light theme ships now.

Components live in `lib/shared/widgets/`:

- `AppButton` â€” `primary`/`secondary`/`destructive` variants, icon support,
  loading spinner, `expanded`, optional `tooltip`,
- `AppTextField` â€” labels, hints, error/helper text, icons, `enabled`, an
  overrideable screen-reader label, an arbitrary trailing `suffix` widget, and
  hidden character counters,
- `AppCard` â€” `standard`/`elevated` variants with an optional interactive
  (pressable) mode,
- `AppLoading` / `AppEmptyState` / `AppErrorState` â€” the three feedback states,
- `AppInlineAlert` â€” the single inline banner (danger/info tones, live region,
  announced exactly once),
- `AppChoiceChip` / `AppFilterChip` â€” the shared status/filter chips behind the
  tasks and dashboard filter bars,
- `AppShell` â€” responsive application shell: a pinned `AppSidebar` on
  tablet/desktop and an app-bar menu + drawer on compact widths, plus an
  `AppPageHeader` for consistent page titles,
- `AppSnackbar` / `AppDialog` / `AppConfirmationDialog` / `AppBadge` /
  `AppDivider` â€” generic feedback and structure primitives.

The live **`/design-system`** route renders every token gallery and component,
so the library can be reviewed and demoed (including snackbar, dialog and
confirmation flows) without touching feature code.

## Responsive strategy

Web targets desktop, laptop and tablet browser widths; mobile (compact) sizes
are recognized but not optimized until a mobile phase.

- Breakpoints live in `core/utils/responsive.dart`: `compact < 600`,
  `tablet 600â€“1023`, `desktop â‰¥ 1024` (inclusive at 600/1024).
- Layout flow derives from **actual constraints** (`LayoutBuilder`) via
  `ResponsiveContainer`: content width is capped at `1200` and centered on
  desktop, and the horizontal gutter grows from `24` to `32` on desktop.
- LayoutBuilder, ConstrainedBox, Flexible/Expanded and MediaQuery are used as
  appropriate; no hardcoded screen dimensions gate behavior.
- `AppShell` adapts navigation itself: compact widths get an app-bar menu that
  opens a drawer; tablet/desktop widths get a pinned sidebar (264 px) beside
  the content, so feature pages never have to manage shell chrome. The page
  header's action row reflows onto new lines when the content slot is narrow,
  and every routed page is verified overflow-free at
  390/600/768/1024/1280/1440.

## Accessibility foundation

- Semantic text roles via `TextTheme`; labels on every form control
  (`AppTextField` screen-reader labels are overrideable).
- Buttons/inputs never drop below 48 logical px touch targets; loading
  spinners are announced as live regions.
- Cards and interactive containers expose button semantics; `AppShell`
  navigation is keyboard operable with visible focus styling and a clamped
  text-scale factor for readability. Full WCAG certification is out of scope
  for the foundation.

## Testing

```bash
flutter test
```

329 tests covering every layer of the app:

- **Task data** â€” `TaskApi` (request paths, bounded pagination/filter params,
  full-PUT / minimal-PATCH serialization, explicit-null clears, dedicated
  status/complete/cancel/delete endpoints, optimistic-lock/transition error
  surfacing).
- **Task models & validators** â€” wire parsing (calendar dates, status
  fallbacks), lifecycle/cancellation helpers, pagination, date formatters.
- **Task pages** â€” list states (loading/error/empty/refresh/filter/pagination),
  create/edit/delete flows incl. confirm + decline, patch diffing, lifecycle
  transitions, safe error copy, responsive no-overflow across 390â€“1440,
  accessibility semantics.
- **Dashboard data & page** â€” `DashboardApi` (request paths, bounded
  pagination/filter params, error mapping), `DashboardModels` (wire parsing,
  status mapping), `DashboardPage` (loading/error/empty/retry/refresh,
  metric semantics, filter chips, duplicate-refresh prevention, navigation,
  responsive no-overflow across 390â€“1440).
- **Auth data & state** â€” `AuthApi`, `AuthTokenResponse` / `CurrentUser` models,
  `AuthState` lifecycle (login / logout / register / refresh / concurrent
  refresh serialisation), `AuthenticatedHttpClient` (bearer injection, 401 â†’
  refresh â†’ retry, loop guard).
- **Profile data** â€” `ProfileApi` (GET full profile, PUT upsert with full body,
  PATCH partial update), `ProfilePatchRequest` diffing, `ProfileModels` parse /
  serialise.
- **Validators & timezone** â€” username / email / password / confirm / profile
  field validators, timezone IANA lookup and catalogue.
- **App routing & guards** â€” named-route table, unknown-route fallback,
  protected / publicOnly redirects, authenticated-user redirect, self-redirect
  prevention.
- **Page widgets** â€” login, register, profile, design-system, responsive
  breakpoints, app shell and theme assembly.
- **API foundation** â€” `ApiClient` (typed decode, interceptors, error /
  envelope parsing, network / timeout, correlation-id generation + echo capture
  and top-level envelope path/timestamp forwarding into exceptions), config
  defaults, design-system widget library.