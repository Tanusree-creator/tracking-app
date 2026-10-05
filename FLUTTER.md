# FieldFlow — Flutter-only Architecture

FieldFlow is a field-service app for technicians (employees) and admins. This document
replaces the FastAPI backend design: **everything lives in the Flutter app**. There is no
custom server. The app talks to Supabase (Auth + Postgres + RLS) directly through
`supabase_flutter`, and uses on-device packages for location, maps and notifications.

> Why no server code: the FastAPI layer only did JWT checks, CRUD, TomTom proxying and PDF
> generation. Supabase RLS now enforces roles, the `latlong2`/`geolocator` packages do
> distance maths on-device, and the `pdf` package builds reports in-app.

---

## 1. Packages

| Concern | Package | Notes |
|---|---|---|
| Backend (auth, DB, realtime) | `supabase_flutter` | Email/password login, RLS-enforced roles |
| **Session storage** | `flutter_secure_storage` | Access/refresh tokens, user id, role |
| Light local prefs | `shared_preferences` | Theme mode, onboarding flag, last-selected filters |
| **Location** | `geolocator` | Permissions, current position, live position stream, distance |
| Address ↔ coordinates | `geocoding` | Geocode a client address, reverse-geocode a GPS point |
| Map display | `flutter_map` + `latlong2` | **TomTom** raster tiles via URL template: `https://api.tomtom.com/map/1/tile/basic/main/{z}/{x}/{y}.png?key=$TOMTOM_API_KEY` |
| TomTom REST (routing, search) | `dio` | Route distance and geocoding from the app; `geocoding` stays as the offline fallback |
| Background tracking | `flutter_background_service` (or `geolocator` foreground service on Android) | Needed while a shift is active |
| **Notifications** | `flutter_local_notifications` + `timezone` + `flutter_timezone` | Scheduled "1 hour before meeting" alerts |
| Push (admin alerts from other devices) | `firebase_messaging` | Optional, see section 6 |
| State management | `flutter_riverpod` | Providers wrap use cases |
| Navigation | `go_router` | Role-based redirect guard |
| Models | `freezed` + `json_serializable` | Immutable entities / DTOs |
| Errors | `fpdart` (or a small `Result` type) | Use cases return `Either<Failure, T>` |
| PDF reports | `pdf` + `printing` | Replaces fpdf2 |
| UI polish | `google_fonts`, `flutter_animate`, `shimmer`, `fl_chart`, `intl` | |

Add each with `flutter pub add <name>` so versions resolve to latest.

---

## 2. Folder structure (Clean Architecture, feature-first)

```
lib/
  main.dart
  app.dart                         # MaterialApp.router, theme, providers
  core/
    config/        env.dart        # Supabase URL / anon key (--dart-define)
    storage/       session_storage.dart   # secure token + role store
    location/      location_service.dart  # geolocator wrapper
    notifications/ notification_service.dart
    theme/         app_theme.dart, colors.dart, text_styles.dart
    router/        app_router.dart
    errors/        failure.dart
    utils/         distance.dart, date_utils.dart
    widgets/       # shared widgets (section 4)
  features/
    auth/
      data/        auth_repository_impl.dart
      domain/      entities/session.dart, repositories/auth_repository.dart,
                   usecases/{login,logout,restore_session}.dart
      presentation/ pages/login_page.dart, providers/auth_provider.dart
    employees/     (same data / domain / presentation split)
    shifts/
    visits/
    tracking/
    reports/
    notifications/
    settings/
```

Each domain module follows the same shape: **entity → repository interface (domain) →
repository impl (data) → use case → Riverpod provider → page/widgets**. Don't invent a
different pattern per module.

---

## 3. Session storage

`core/storage/session_storage.dart` is the only place that touches stored credentials.

| Key | Store | Value |
|---|---|---|
| `access_token` | secure storage | Supabase JWT |
| `refresh_token` | secure storage | Supabase refresh token |
| `user_id` | secure storage | UUID |
| `role` | secure storage | `tech` or `admin` (from `app_metadata.role`) |
| `theme_mode` | shared_preferences | `light` / `dark` / `system` |
| `active_shift_id` | shared_preferences | Restores the tracking screen after app restart |

Flow:

1. App start → `RestoreSession` use case reads secure storage.
2. Token present → refresh it via Supabase, route to the role's home. Missing or refresh
   fails → route to `/login`.
3. `Login` use case signs in, then `SessionStorage.save(...)`.
4. `Logout` use case signs out, then `SessionStorage.clear()` and cancels scheduled
   notifications.
5. `go_router` `redirect` reads the auth provider: unauthenticated → `/login`, `tech` →
   `/home`, `admin` → `/admin`. Admin routes are also protected by RLS, so the guard is UX
   only, not security.

---

## 4. Widgets (reusable, in `core/widgets/`)

| Widget | Purpose |
|---|---|
| `AppScaffold` | Gradient header, safe area, consistent padding |
| `PrimaryButton` / `SecondaryButton` | Loading state, full width, rounded 14 px |
| `AppTextField` | Label, validation, password toggle |
| `StatCard` | Icon + value + label (hours today, distance, visits) |
| `ShiftStatusCard` | Clocked in/out, timer, break state, clock-in/out action |
| `VisitTile` | Client, address, time window, status chip |
| `StatusChip` | Scheduled / In progress / Done / Cancelled colours |
| `RouteMapView` | `flutter_map` with polyline for the GPS trail and a marker for each visit |
| `NotificationTile` | Title, body, time, unread dot, swipe to dismiss |
| `EmptyState` / `ErrorState` | Illustration, message, retry button |
| `ShimmerList` | Loading placeholder |
| `PermissionBanner` | Location or notification permission denied, with an "Open settings" action |

UI direction: Material 3, rounded cards (16 px), soft shadows, one seed colour
(`ColorScheme.fromSeed`), light and dark themes, `google_fonts` (Inter), subtle
`flutter_animate` fade/slide on list items, bottom `NavigationBar` for employees and a
`NavigationRail` or drawer for admins on wide screens.

---

## 5. Use cases (domain layer)

Each use case is a single-method class: `Future<Either<Failure, T>> call(Params)`.

**Auth**
- `Login(email, password)`, `Logout()`, `RestoreSession()`, `GetCurrentUser()`

**Employees** (admin unless noted)
- `GetMyProfile()` (tech), `UpdateMyProfile()` (tech)
- `ListEmployees()`, `CreateEmployee()`, `UpdateEmployee()`, `DeleteEmployee()`

**Shifts** (tech)
- `ClockIn()`: gets location, creates the shift, saves `active_shift_id`, starts tracking
- `ClockOut()`: stops tracking, computes hours and distance, clears `active_shift_id`
- `StartBreak()`, `EndBreak()`, `GetActiveShift()`, `GetShiftHistory(page)`
- `ListAllShifts(employeeId?)` (admin)

**Visits**
- `CreateVisit()`: saves the visit, then calls `ScheduleVisitReminder`
- `ListVisits(shiftId?, status?)`, `GetVisit()`, `UpdateVisit()` (reschedules the reminder),
  `DeleteVisit()` (cancels the reminder)
- `ListAllVisits(employeeId?, shiftId?)` (admin)

**Tracking**
- `StartLocationTracking()`, `StopLocationTracking()`
- `UploadTrackingPoints(batch)`: batches up to 500 points to Supabase
- `GetShiftRoute(shiftId)`: points plus total distance
- `CalculateRouteDistance(points)`: Haversine / `Geolocator.distanceBetween`, chunked
- `GeocodeAddress(address)`, `ReverseGeocode(lat, lon)`

**Reports**
- `BuildMyReport(from, to)`, `BuildEmployeeReport(id, from, to)`: PDF bytes
- `GetEmployeeSummary(id, from, to)`: chart data (admin)

**Notifications**
- `ScheduleVisitReminder(visit)`, `CancelVisitReminder(visitId)`
- `RescheduleAllReminders()`: run after login and after app update
- `GetNotificationInbox()`, `MarkNotificationRead(id)`

---

## 6. Notifications (new feature)

Both employees and admins are reminded **1 hour before a client meeting**, with different
content.

| Audience | Message | Tap action |
|---|---|---|
| Employee | "Meeting with {client} at {time}. Head out soon." | Opens the visit detail |
| Admin | "{employee} meets {client} at {time}. Check their status." | Opens the employee's live shift and route |

How it works:

1. `ScheduleVisitReminder` computes `visit.start − 1 hour` (using `timezone`), skips it if
   the time has already passed, and calls
   `flutter_local_notifications.zonedSchedule(id: visit.id.hashCode, ...)`.
2. The employee device schedules the employee message.
3. The admin device schedules the admin message for every visit it can see. It syncs the
   visit list on login and on Supabase Realtime changes, then reschedules.
4. A `notifications` table (`id`, `user_id`, `visit_id`, `title`, `body`, `read`,
   `created_at`) backs the in-app inbox.
5. Android 13+ needs the `POST_NOTIFICATIONS` runtime permission. Android 12+ needs
   `SCHEDULE_EXACT_ALARM` or inexact scheduling. iOS needs a permission prompt.
   `PermissionBanner` handles denial.

Limitation to decide on: local scheduling only fires on devices that have synced the visit
and are not force-killed. If an admin must be alerted reliably while the app is closed, or
about visits created while their app was off, add `firebase_messaging` and a Supabase
scheduled job (or Edge Function) that sends push. That is a small server-side piece, but it
runs inside Supabase, not as a separate backend.

---

## 7. Location

- `LocationService` (core) wraps `geolocator`: checks service enabled, requests
  `whenInUse` then `always` (for background tracking), exposes
  `Stream<Position>` with `distanceFilter: 10` and `accuracy: high`.
- While a shift is active, positions are buffered locally and flushed in batches through
  `UploadTrackingPoints` (max 500 per call). `active_shift_id` lets tracking resume after a
  restart.
- Required platform setup:
  - Android: `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `ACCESS_BACKGROUND_LOCATION`,
    `FOREGROUND_SERVICE_LOCATION`, `POST_NOTIFICATIONS`
  - iOS `Info.plist`: `NSLocationWhenInUseUsageDescription`,
    `NSLocationAlwaysAndWhenInUseUsageDescription`, and the `location` background mode
- Distance is computed on-device with `Geolocator.distanceBetween` (Haversine), as a
  fallback. TomTom provides the map tiles and, through `dio`, road-route distance and address
  search, with the key read from `env.json`.

---

## 8. Screens

**Employee:** Login, Home (shift card, today's visits, stats), Visits (list, create, edit),
Active shift map, History, Notifications inbox, Profile and settings.

**Admin:** Login, Dashboard (stats, charts), Employees (list, create, edit), All shifts, All
visits, Employee detail (live route map, report download), Notifications.

---

## 9. Backend (Supabase, no custom server)

Reuse `migrations/001_initial_schema.sql` from the old API project (tables, RLS policies),
and add the `notifications` table above. Roles stay in `app_metadata.role`. Admin-only
operations that need the service role, such as creating an Auth user for a new employee,
must not ship the service-role key in the app. Do that in a Supabase Edge Function, or have
the admin invite users from the dashboard.

Config lives in a git-ignored `env.json` (`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `TOMTOM_API_KEY`) and
is passed with `flutter run --dart-define-from-file=env.json`. Read it in `core/config/env.dart`
with `String.fromEnvironment`. Never embed the service-role key, DB password, JWT secret or
Firebase service-account JSON in the Flutter app.

### Tables (already exist in Supabase)

The tables below are inferred from the FieldFlow API README (employees, shifts, visits,
GPS tracking points; `shifts.route_distance_m` is the only column that README names). Column
names are unverified. **Your Supabase project already has these tables, so the live schema
is authoritative.** Before writing any data layer, compare this list against the real
schema and adapt column names in the Flutter models. Do not create duplicate tables, and
add only what is missing (for example `notifications` and `employees.fcm_token`).

| Table | Key columns | RLS |
|---|---|---|
| `employees` | `id` (= auth uid), name, email, phone, role, fcm_token | Self read/update; admin all |
| `shifts` | `id`, `employee_id`, clock_in, clock_out, break_minutes, route_distance_m | Owner; admin read all |
| `visits` | `id`, `shift_id`, `employee_id`, client_name, address, lat, lon, start_at, end_at, status, notes | Owner; admin read all |
| `tracking_points` | `id`, `shift_id`, `employee_id`, lat, lon, accuracy, recorded_at | Owner insert/read; admin read |
| `notifications` | `id`, `user_id`, `visit_id`, title, body, read, created_at | Recipient only |

Flutter accesses them with `Supabase.instance.client.from('visits')...`. Live admin views use
`.stream()` / Realtime on `shifts` and `tracking_points`. Run the migration from the Supabase
SQL editor; the admin role is set via `app_metadata.role`.

---

## 10. Build order

1. Add packages, theme, router, `SessionStorage`
2. Auth module (login, restore session, role redirect)
3. Location service and permissions
4. Shifts and tracking
5. Visits
6. Notifications (local scheduling, then inbox)
7. Reports and the admin dashboard
8. Polish: animations, empty/error states, dark mode

---

## 11. Design system (implemented in `lib/core/theme` and `lib/core/widgets`)

Premium feel comes from consistency, not effects. Never use raw numbers in screens; use the
tokens in `core/theme/tokens.dart`.

| Rule | Values |
|---|---|
| Spacing (`Space`) | 4, 8, 12, 16, 20, 24, 32 |
| Type scale (`FontSizes`, via `Theme.textTheme`) | headline 28, title 22, subtitle 18, body 16, caption 13 |
| Radius (`Radii`) | small 8, medium 16, large 24 |
| Shadow (`AppShadows.soft`) | black 5% opacity, blur 20, offset (0, 8); none in dark mode |
| Colour | One primary (blue), one accent (teal, `colorScheme.tertiary`), neutral surfaces; status colours come from these |
| Motion (`Motion`) | 180 ms / 280 ms, `easeOutCubic`; only for feedback: button loading, error reveal (`AnimatedSize`), list/state switches (`AnimatedSwitcher`), shift status (`AnimatedContainer`) |
| Dark mode | Separate background / surface / muted-text colours, tested against the same components |
| Performance | `const` constructors, `select` on providers, `RepaintBoundary` around the live map, small widgets so GPS updates rebuild only the map |

Reusable components: `AppCard`, `AppButton` (animated loading), `AppTextField`,
`StatusPill`, `EmptyState`. Add new screens from these, not from raw Material widgets.
Heavy UI packages are avoided; `google_fonts` (Inter) is the only styling dependency.
