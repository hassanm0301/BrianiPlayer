# Existing-feature polish and bug fixes — 2026-10-14

Implemented the requested audit findings without adding major product features. Existing media delivery, authorization, engine and deployment boundaries are unchanged. No production data, indexer accounts, Pi or physical Android device was contacted. Unrelated Compose/operations work already present in the checkout was preserved.

## Changes

- Folder sorting now uses the supported `name/date/size` wire values. Folder and Discover requests are cancelled and checked against query/session identity, preventing late responses from overwriting searches or mixing pages. Refresh failures preserve useful content and offer explicit retry; a failed load is no longer labelled an empty folder.
- Download refreshes reconcile the entire loaded window, remove disappeared requests and preserve pagination. Polling stops for hidden routes/background lifecycle states. Details render files lazily, fetch live data every five seconds while visible, and refresh settings/capabilities less often. User file selections survive polling. Partial transfer limits validate independently and invalid input stays in the dialog.
- Main tabs retain their navigation/search/scroll state, with one feature header. Library grids use responsive lazy slivers; grid thumbnails use the available tile area. Continue Watching refreshes on return, including when previously empty. System accessibility text scaling is composed with the app preference.
- Seek dragging previews locally and commits once; settings sliders likewise save at gesture end. The player reuses its video widget and moves secondary controls to accessible panels. Photo state follows updated routes/adjacent lists, resets zoom and cancels slideshow/request work appropriately.
- Administration loads independent sections separately; create-member validation stays inline. Storage/rate settings use labelled MiB/GiB units, broad numeric ranges use bounded input, account device times are localized, and saved-server failures show safe retry messages.
- Server catalog count/version aggregation uses one query. Thumbnail eviction sorts only when the physical cache needs eviction; physical inspection and orphan accounting remain intact. No shared thumbnail cache was introduced: authorized per-session requests remain authoritative.

## Verification

| Check | Result | Evidence |
|---|---|---|
| Flutter complete widget/unit suite | 112 passed, exit 0 | `flutter-full-final.log` |
| Flutter analysis | No issues, exit 0 | `flutter-analyze-final.log` |
| Linux debug build | Passed, exit 0 | `linux-build.log` |
| Server application tests | 415 passed across 10 projects | `server-regressions.log`, `server/*.trx` |
| Download application suite using prescribed `Category!=EngineIntegration` filter | 108 passed, exit 0 (included in 415) | `server-downloads-application.log` |
| Dedicated engine integration harnesses | 2 passed, exit 0 each, isolated resources cleaned | `server-engine/report.md` |
| Native Linux connected UI and media matrix | Passed, exit 0: 2 native tests and 3 media cases; owned resources cleaned | `desktop/`, `desktop-run-final.log` |
| Secret scan | Passed, exit 0 | `secret-scan.log` |
| Plan structure / whitespace | 1,062 checks passed / no diff whitespace errors | `plan-validation.log` |
| Local optimization measurements | Exact aggregate equality, including empty catalog; unnecessary sort eliminated | `performance/local-measurement.md` |
| Single isolated reconnect experiment | Passed; payload hashes match; cleanup clean | `performance/reconnect-unassisted.json` |

New regression coverage checks stale-query cancellation, both sort wire values, permission/session transitions, failed-vs-empty content, refresh and pagination, OS scaling, retained tabs/Back, quiet polling, 1,000-file lazy rendering, metadata request counts, retained unchecked files, slider commits, partial transfer limits, admin partial failures, inline validation, photo/slideshow changes, and late settings writes across download IDs. Existing TV focus/navigation tests pass in the full suite. These are widget checks, not physical TV certification.

The first native run passed actual libmpv playback, starvation/recovery and external-player handoff, then failed an old assertion expecting tab selection to discard the open folder. The test now verifies the retained folder and refreshes it to observe the completed import. A second run compiled an intermediate helper assertion looking for a file-only Details control on that folder; its timeout is retained in the evidence. The completed assertion scopes the Downloads folder inside FolderScreen, avoiding both navigation labels and file-only controls. Final run `87e48899e5f64e55bd22fee11244f09b` passed the entire harness, including all three media cases; `desktop-cleanup.json` independently confirms all three runs left no owned containers, networks, temporary fixture/state directories or credential handoff files. The test's native window is also sized to match its existing 1280×800 Flutter surface.

## Commands and environment

From `client/`, Flutter commands used the installed snapshot with a temporary writable cache overlay (the installed `/opt/flutter` SDK was not modified):

```sh
FLUTTER_ROOT=/tmp/briani-quality-audit-20261014/flutter-sdk \
  /opt/flutter/bin/cache/dart-sdk/bin/dart /opt/flutter/bin/cache/flutter_tools.snapshot \
  --no-version-check test --no-pub --reporter expanded
# Same prefix: analyze --no-pub
# Same prefix: build linux --debug --no-pub
```

Actual environment: Flutter 3.47.7, Dart 3.13.5, .NET SDK 10.0.112 on Linux x86-64. No dependency/package upgrade was made. Native build subprocesses use a temporary wrapper pointing to the same installed Flutter snapshot. Test-runner sockets and isolated Docker/Xvfb execution required scoped sandbox escalation; initial read-only-cache/socket failures are environmental, not passing checks.

From the repository root, with `DOTNET_CLI_HOME=$PWD/.tools/dotnet-home` and `NUGET_PACKAGES=$PWD/.tools/nuget`:

```sh
dotnet test server/Briani.sln --no-restore --nologo --logger trx \
  --results-directory docs/evidence/M10/polish/server
dotnet test server/tests/Briani.DownloadTests/DownloadTests.csproj --no-restore --nologo \
  --filter 'Category!=EngineIntegration'
python3 plan/tools/validate_plan.py
git diff --check
```

The unfiltered solution command exited 1: its 415 application tests passed, but two engine tests emitted the existing dynamic-skip exception because their fixture environment was absent. Both then passed through their dedicated isolated harnesses; see `server-engine/report.md` for exact commands and cleanup. Counts are not doubled.

Native connected command (temporary Flutter wrapper first on PATH, repository test-only Docker configuration):

```sh
PATH=/tmp/briani-quality-audit-20261014/flutter-sdk/bin:$PATH \
DOCKER_CONFIG=$PWD/.tools/docker-config \
python3 prototypes/client/run_desktop_e2e.py --artifacts docs/evidence/M10/polish/desktop
```

## Independent review and remaining limits

Separate Sol review found two additional state races: a late settings response for download A could overwrite B, and polling during the mounted frame after disconnect could throw. Both are fixed and regression-tested. Delete-payload confirmation also checks request/API identity before proceeding. The final narrow review reported no remaining actionable finding. Server authorization continues to guard every mutation even when UI capability metadata is cached.

Synthetic local measurements show one aggregate statement instead of two (10,000 rows: median 0.543 → 0.413 ms), and no sort when 1,000 cache entries fit (0.810 → 0.787 ms; timing difference may be noise). These use Python/SQLite/filesystem equivalents, not API/Pi benchmarks. Current server EF/endpoint tests pass, including empty catalogs for all sorts.

The reconnect run resumed in 5.065 seconds after a 3.762-second outage and completed with matching hashes. Its harness explicitly reconnects the network, re-adds the private peer, starts the torrent and removes fixture limits; it proves one recovery without daemon restart. Earlier unexplained intermittent stalls remain an open reliability blocker. No automatic daemon-restart behavior was added.

Pi, physical Android/TV, Windows/macOS and signing/release verification remain blocked or user-deferred. Native desktop exercises the current client against the existing locked local server image; host-side server tests exercise the current server changes. Distribution archives and image locks were not rebuilt or published. Existing milestone/release blockers remain unchanged.
