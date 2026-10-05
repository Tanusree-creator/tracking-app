# FieldFlow (trackingapp)

Flutter-only field-service app. No custom backend: Supabase is called directly from the
app. Full architecture, packages, use cases and notification design are in `FLUTTER.md`.

## Conventions

- Clean architecture, feature-first: `features/<name>/{data,domain,presentation}`.
- Each module follows the same pattern: entity, repository, use case, Riverpod provider,
  page. Follow sibling modules, don't invent new patterns.
- Session data goes through `core/storage/session_storage.dart` only.
- Never put the Supabase service-role key in the app.

## Modules

| Module | Status |
|---|---|
| Architecture doc (`FLUTTER.md`) | Done |
| core (theme, router, storage, location, notifications) | Not started |
| auth | Not started |
| employees | Not started |
| shifts | Not started |
| visits | Not started |
| tracking | Not started |
| reports | Not started |
| notifications | Not started |

Update this table as work happens.
