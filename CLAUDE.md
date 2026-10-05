# FieldFlow (trackingapp)

Flutter-only field-service app. No custom backend: Supabase is called directly from the
app. Full architecture, packages, use cases and notification design are in `FLUTTER.md`.

## Conventions

- Clean architecture, feature-first: `features/<name>/{data,domain,presentation}`.
- Each module follows the same pattern: entity, repository, use case, Riverpod provider,
  page. Follow sibling modules, don't invent new patterns.
- Session data goes through `core/storage/session_storage.dart` only.
- Never put the Supabase service-role key in the app.
- UI: use `Space`, `Radii`, `FontSizes`, `Motion` tokens and the `core/widgets` components. No raw spacing, radius or font-size numbers in screens.

## Modules

| Module | Status |
|---|---|
| Architecture doc (`FLUTTER.md`) | Done |
| core (theme, router, session storage, location, notifications) | Built, analyzer clean, not run on a device |
| auth (login, restore session, role redirect) | Built, untested against live Supabase |
| employees (admin list + create login via Edge Function) | Built; Edge Function not deployed yet |
| shifts + tracking (clock in/out, background GPS, TomTom map) | Built, untested on device; column names assumed |
| notifications (1-hour visit reminders, tech + admin wording) | Built, untested on device |
| visits (create/edit UI) | Not started (reminders read the existing `visits` table) |
| reports (PDF) | Not started |

Run: `flutter run --dart-define-from-file=env.json`. Needs JDK 17 for Android builds
(Gradle 8.14 does not run on JDK 25).

Update this table as work happens.
