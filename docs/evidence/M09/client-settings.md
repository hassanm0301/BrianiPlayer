# M09 client settings and administration slice

Implemented the client settings scope in `client/lib/core/preferences/` and the Settings and Administration screens. Synced preferences use the generated `PreferencesApi`, carry the server's optimistic version on writes, and key the provider lifecycle to profile ID, user ID, session ID, and API identity. Access token refresh retains the same scope. A request started by a replaced session is cancelled, and its response cannot publish into the new scope. Section reset updates only that section's typed defaults; full reset uses the versioned server reset operation. Device preferences remain in SharedPreferences, are validated on read/write, keep player executable/argument data local, and cap the player cache presets at 64 MiB.

The Settings screen exposes synced appearance, accessibility, library, discovery, playback, subtitle, slideshow, pin, and saved-folder preferences, plus local per-device playback controls. The Administration screen gates API loading on administrator role and presents typed settings, user creation, enable/disable and password reset, library creation from mounted-root directory choices, grants, library scans, service status, integrations with secret-redacted display and blank-to-preserve secret entry, bounded maintenance actions, and server-redacted audit summaries. Database snapshot copy explicitly says it is not a full-stack backup. Storage UI displays mounted-root labels and available space, not server filesystem paths.

Verification ran locally with the installed Flutter SDK (escalated command access was needed for Flutter's filesystem operations):

| Command | Exit | Result |
|---|---:|---|
| `cd client && flutter analyze lib/core/preferences lib/features/settings lib/features/administration test/preferences_screens_test.dart` | 0 | No issues found. |
| `cd client && flutter test test/preferences_screens_test.dart` | 0 | 5 tests passed: local device validation/cache cap, section reset/version preservation, token-refresh scope stability and session reload, stale old-profile response isolation, Settings/admin access UI. |

The test runner output was returned directly and was not persisted as a separate log artifact. Tests use fake HTTP and widget/provider state; they do not certify server endpoint deployment or administrator integration behavior against a running server. Parent integration must route to `SettingsScreen` and `AdministrationScreen`, and can consume `userPreferencesProvider` with `ref.watch(userPreferencesProvider)` and `ref.read(userPreferencesProvider.notifier).update((builder) { ... })` or `.reset(PreferenceSection.library)`. `devicePreferencesProvider` is local-only.
