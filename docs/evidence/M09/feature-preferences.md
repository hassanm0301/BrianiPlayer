# M09 feature preference consumption

This slice wires existing synced user preferences into the library home, folder browser, discovery results, and photo slideshow. The follow-up also persists discovery filters and sort per feed mode, adds curated admin provider/category scope controls, and explains locale support accurately.

## Behavior delivered

- Library home applies saved grid/list layout, puts pinned libraries first, and honors the continue-watching visibility flag.
- Folder browser applies global default sort/order and per-library/per-folder layout/sort when remember-folder-sort is enabled. Layout and sort changes are written back to the existing folder preference collection. Folder queries start with defaults while preferences load, then reload when the authenticated preference scope becomes available or changes.
- Filename extensions follow the saved visibility preference. Grid tiles retain details and permitted file actions.
- Discovery renders the configured result columns while always keeping the title visible. It applies saved default ordering even when preferences arrive after its initial query.
- Photo slideshow uses the saved interval, clamped to 1–60 seconds.
- Latest and Most seeded discovery feeds use mode-specific defaults (published date descending and seeders descending); filters and sort settings persist per mode without storing search text.
- Administration can set provider/category scope to all or selected IDs, preserving null (unrestricted) versus empty (none), and validates the server contract's count and value bounds. Mutations use the captured admin session/API and discard stale async results.
- Locale settings are described as formatting controls; the application interface remains English.

## Verification

Commands ran from `client/`:

| Command | Exit | Result |
|---|---:|---|
| `dart format lib/features/libraries/libraries_screen.dart lib/features/libraries/folder_screen.dart lib/features/discover/discover_screen.dart lib/features/photos/photo_viewer_screen.dart test/feature_preferences_test.dart` | 0 | Formatted assigned Dart files. |
| `flutter analyze` | 0 | No issues found. |
| `flutter test test/feature_preferences_test.dart test/discover_screen_test.dart test/libraries_screens_test.dart` | 0 | All 14 tests passed, including saved-folder behavior, Most seeded ordering/persistence, admin scope controls, and existing discovery/library regressions. |
| `flutter analyze` | 0 | No issues found. |
| `dart format lib/features/administration/administration_screen.dart lib/features/settings/settings_screen.dart lib/features/discover/discover_screen.dart test/feature_preferences_test.dart` | 0 | Assigned Dart files formatted; a follow-up scoped style cleanup also formatted administration and settings screens. |

Flutter output was returned directly by the command runner; no separate log artifact was created. One earlier regression run exposed that grid mode omitted file actions; the grid tile now provides details and permitted actions, and the final regression run passes. No physical TV or external server was involved in this slice.

## Review notes

The implementation uses the existing generated preference contract and provider; it adds no API fields, dependencies, or generated files. The screen fallback remains usable while preferences are loading or unavailable. Discovery reruns and folder requests preserve existing cancellation/session checks. M09 integration must still run its broader preferences, operations, onboarding, and deployment gates.
