# FieldFlow (Flutter + Supabase, no custom backend)

## Modules
- Auth, registration/approval, admin-created users, credential messages: done. Logic is in Postgres functions (`supabase/schema.sql`), called via `lib/services/api.dart`.
- Technician app (home/tasks/tracking/history/profile): done, local-first (shared_preferences per user).
- Admin app (dashboard/employees/reports/access): done. Dashboard, detail and report numbers for the 7 seeded employees come from `demo_data.dart` (deterministic fake data); real Supabase users appear in the registry.
- Not started: syncing shifts/visits/locations to Supabase (so admin sees real field data), Firebase/FCM push, TomTom.

## Setup
1. Run `supabase/schema.sql`, then `supabase/seed_admin.sql` (gitignored) in the Supabase SQL Editor.
2. `flutter run --dart-define-from-file=env.json` (env.json is gitignored).

- Admin management: `supabase/002_admin_management.sql` (run after schema.sql); UI in `lib/screens/admin/admin_admins_screen.dart`.
