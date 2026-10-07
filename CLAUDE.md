# FieldFlow (Flutter + Supabase, no custom backend)

## Modules
- Auth, registration/approval, admin-created users, credential messages: done. Logic is in Postgres functions (`supabase/schema.sql`), called via `lib/services/api.dart`.
- Stay signed in: done (token in secure storage, revalidated by `session_info`; splash opens the app directly).
- Face check (`face_verify_screen.dart`, ML Kit face + blink liveness, photo sent to admin as an audit record, first one = reference): at employee sign-in, clock-in, break end. NOT identity matching.
- Technician app: done. Local-first and synced to Supabase (shifts, tasks/visits, GPS points) via `tracking_provider.dart`; tracking starts on clock-in; visit completion requires a photo; chat icon on Home.
- Admin app: done, real data only (the old demo roster was removed). Dashboard = radar/orbit of employees (tap -> `admin_employee_detail_screen.dart`: overview, visits, attendance, routes with km), reports (employee dropdown, charts, PDF export), chat, access, admins, auto pop-ups from `admin_events`.
- Tasks: admin assigns (location search/map pick via `location_picker_screen.dart`, OSM Nominatim), employees can add their own.
- Glass UI: `glass.dart` (GlassBackground, GlassSurface/GlassCard, floating `GlassBottomNav`, `GlassBarSpace`); radar in `radar_orbit.dart` is frosted with employee photos.
- Profile: photo (base64 JPEG in `app_users.avatar`), name, phone, position editable in `edit_profile_screen.dart`; admin sees photos via `admin_avatars`. Needs `005_profile_photo_map.sql`.
- Admin dashboard has a blue Tamil Nadu calendar card (`tn_calendar.dart`; holiday list is per year, moon-based dates marked approx, 2026-2029 filled in; 2027-29 moon dates are approximate and some festivals are not listed). Live field map moved to `admin_live_map_screen.dart` (opened from Team).
- Task locations show as pins (`map_pins.dart`) on employee Tracking, route maps and the admin live map. Route map is full-screen with glass overlays.
- Closing a visit asks for the outcome (`outcome_sheet.dart`: books ordered / samples / follow up / not interested, copies, note); shown to admin in the visit detail and the "closed a task" event. Home has a daily-target ring + streak; weekly leaderboard in `leaderboard_screen.dart` (admin sets the daily target there). Needs `006_outcomes_targets_leaderboard.sql`.
- Not started: Firebase/FCM push, road snapping (OSRM/Mapbox), restart tracking after reboot / OEM battery onboarding, TomTom.

## Setup
1. Run `supabase/schema.sql`, then `supabase/seed_admin.sql` (gitignored) in the Supabase SQL Editor.
2. `flutter run --dart-define-from-file=env.json` (env.json is gitignored).

- Then run `002_admin_management.sql`, `003_profile.sql`, `004_field_sync.sql`, `005_profile_photo_map.sql`, `006_outcomes_targets_leaderboard.sql` (tasks, shifts, GPS, chat, face checks, events). Admin screens show an error until 004 is run.
- Palette: one blue family in `AppColors` (`lib/theme/app_theme.dart`); logo in `assets/` (transparent PNGs).
