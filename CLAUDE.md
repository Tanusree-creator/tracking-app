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
- Language: English / Hindi / Tamil (`lib/l10n/l10n.dart`, `strings_hi.dart`, `strings_ta.dart`). Code text stays English and is looked up with `'Home'.tr`; `trf('Hi, {}', [name])` fills blanks; keys containing `{}` in the string maps are patterns (also used for server messages like "Message from {}"). Missing text falls back to English. Picker in `widgets/language_picker.dart` (login page, admin bar, Profile). Switching rebuilds every element. PDF reports stay English. Any new UI text needs a `.tr` plus entries in both maps.
- Transitions: `slideRoute` (parallax, opaque page background so screens never show through each other), `fadeRoute` (splash/login/logout), `AnimatedTabStack` for bottom-nav tabs (lazy, keeps state).
- Staff types: `app_users.staff_type` = `field` (marketing, GPS, `TechShell`) or `office` (in-house, no tracking, `office_shell.dart`). Chosen when the admin creates the user (long-press a person in Team to change it). `home_router.dart` picks the app. Office app: `office_home_screen.dart`, `office_tasks_screen.dart`, `follow_ups_screen.dart` (people/schools to call or visit, with date+time; admin gets an event and sees them on the admin calendar), calendar tab.
- Leave (`leave_screen.dart`, admin `admin_leaves_screen.dart`): both staff types request, admin approves/rejects; approved days show as absent (attendance calendars + `calendar_screen.dart`). Announcements (`announcements_screen.dart`): admin writes (optional picture, audience all/marketing/office), employees see them and get an in-app alert. Employee data for all of this lives in `services/staff_provider.dart`.
- Calendar: `calendar_screen.dart` (month grid + big picture banner per day, `widgets/event_picture.dart` draws illustrated pictures for holidays/leave/calls/visits/tasks; no real photos). Admin sees everyone, employees their own (`services/calendar_loaders.dart`).
- Chat: photos and voice notes (base64 in `chat_messages.media`, fetched per message; `record` + `audioplayers`). Admin credentials dialog has Share (WhatsApp/SMS/email).
- Not started: Firebase/FCM push, road snapping (OSRM/Mapbox), restart tracking after reboot / OEM battery onboarding, TomTom.

## Setup
1. Run `supabase/schema.sql`, then `supabase/seed_admin.sql` (gitignored) in the Supabase SQL Editor.
2. `flutter run --dart-define-from-file=env.json` (env.json is gitignored).

- Run `007_office_leaves_announcements.sql` last (staff types, office tasks, follow-ups, leave, announcements, chat media); the new screens show an error until it is run.
- Then run `002_admin_management.sql`, `003_profile.sql`, `004_field_sync.sql`, `005_profile_photo_map.sql`, `006_outcomes_targets_leaderboard.sql` (tasks, shifts, GPS, chat, face checks, events). Admin screens show an error until 004 is run.
- Palette: one blue family in `AppColors` (`lib/theme/app_theme.dart`); logo in `assets/` (transparent PNGs).
