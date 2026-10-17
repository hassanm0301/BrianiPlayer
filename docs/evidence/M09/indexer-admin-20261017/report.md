# Indexer management in Administration (2026-10-17)

Adds an administrator-only **Indexers** section to the client's Administration screen. It lists, adds, enables/disables, tests and removes Prowlarr torrent indexers without opening Prowlarr's web page over an SSH tunnel. The Pi and its Prowlarr indexers were not touched. Upstream behaviour was checked against Prowlarr 2.6.5.5623, the digest pinned in `infra/compose/compose.yaml`, both in its source at tag `v2.6.5.5623` and in a local isolated Compose stack.

## Fit with the plan

- **Prowlarr stays the only discovery source.** Briani only relays Prowlarr's own definitions. It ships no site list, and Usenet indexers are left out of every list and can't be changed.
- **Every action is authorized on the server.** All seven routes need the administrator policy, plus a live administrator check before and after each Prowlarr call. Prowlarr is reached only through nine fixed operations (`ProwlarrCall`), and the transport re-checks each method/path pair. Clients never send a Prowlarr path, URL or API key.
- **Advanced features stay in settings.** The section lives in Administration, which only administrators can see.
- **TV.** Every control is reachable with Down/Left/Right/Select. A widget test drives the whole flow, from the top of the page through add, toggle, test and remove, with key events only.
- **Specs 01 and 08** describe Briani's native indexer administration as status, enabled-source choices and connection tests, and say complex source configuration stays in Prowlarr's UI and Briani "should not reproduce every indexer's configuration schema". List, enable/disable and test map onto that directly. Add and remove go a little further. Add doesn't reproduce any per-indexer schema: it relays the plain settings Prowlarr describes for one definition. Anything complex stays in Prowlarr's page and the list says why: free-form site addresses, CAPTCHA, dynamic option lists, FlareSolverr, duplicate generic implementations, or more than 48 settings. Editing an existing indexer's settings is not offered. I read this as within the spec's intent, not a conflict. The spec text itself is unchanged.

## Prowlarr 2.6.5 behaviour relied on

Taken from `ProviderControllerBase.cs`, `IndexerController.cs`, `IndexerResource.cs` and `SchemaBuilder.cs` at tag `v2.6.5.5623`, and confirmed against the local probe:

| Call | Observed |
|---|---|
| `GET /api/v1/indexer/schema` | 200, 6.1 MB, 657 definitions (636 torrent, 21 usenet) before the fixture was added |
| `POST /api/v1/indexer` | 201 with the resource. When `enable` is true, Prowlarr tests first. On failure it returns 400 with `[{isWarning, propertyName, errorMessage, severity, attemptedValue?…}]` and saves nothing. Needs an existing `appProfileId` and a `priority` of 1–50. |
| `PUT /api/v1/indexer/{id}` | 202 with the resource. Enabling tests first (400, stays disabled). |
| `POST /api/v1/indexer/test` | 200 `text/plain` `{}`, or 400 with failures |
| `DELETE /api/v1/indexer/{id}` | 200 `{}`, **also for an unknown ID** |
| `GET /api/v1/indexer/{id}` unknown | 404 with an internal stack trace in `description` |
| Wrong `X-Api-Key` | 401 |
| Secret masking | Only native fields with privacy `password`/`apiKey` come back as `********`, and are restored from the mask on write. **Cardigann extra fields (passwords, cookies, passkeys, API keys) come back in plain text**, and most are flagged privacy `normal`. In 2.6.5: 212 `password`-type fields flagged `normal`, plus 142 `cookie`, 139 `apikey` and 39 `passkey` text fields. |
| Failure text | Can quote request URLs (passkeys in query strings) and site responses; `attemptedValue` can be a credential |

Because of the last two rows, Briani never returns field values for configured indexers. It returns secret-looking settings as write-only `secret` fields with no value, and builds its error details only from `errorMessage`, with addresses and every known setting value replaced.

## Changes

- **Server:** `ProwlarrCall`/`IProwlarrAdminTransport` (allowlist), `ProwlarrTransport.SendAsync`, `SafeHttp.SendAsync` (non-GET only to the configured service origin, 18-second deadline, bounded bodies), `IndexerAdministration` (catalog cache per connection version for 10 minutes, field classification, validation, scrubbing), `IndexerManagement` endpoints with audit rows `indexer.created/enabled/disabled/deleted`, six error messages, and a 64 KiB request cap.
- **Contract:** seven operations and eight schemas in `contracts/openapi.yaml`. `client/packages/briani_api` was regenerated with `tools/contracts/generate.py`.
- **Client:** `indexer_management.dart` (part of the Administration screen), a new **Indexers** jump-list topic, and the snapshot now keeps the server's message for a failed read.
- **Docs:** `docs/operations/indexers.md` (in-app option, when Prowlarr's page is still needed, new troubleshooting rows), `docs/operations/README.md`, `docs/operations/advanced.md`. The branch was fast-forwarded onto `9945dec` (the guide commit on `ui-redesign`) to edit the guide.

## Verification

| Command | Exit | Result |
|---|---|---|
| `dotnet test server/Briani.sln --no-restore -m:1 --filter 'Category!=EngineIntegration'` | 0 | 528 passed, 0 failed (`server-tests.log`) |
| `dotnet test Briani.sln` (unfiltered) | 1 | 528 passed; the only 2 non-passes are the environment-gated `EngineClientTests` live-harness tests, whose dynamic skip is reported as failed (same as `docs/evidence/M10/server-integrated-final.log`) |
| `dotnet test … --filter IndexerAdministrationTests` | 0 | 69 passed |
| `flutter analyze` (client) | 0 | No issues (`client-analyze.log`) |
| `flutter test` (client) | 0 | 150 passed, including the 4 in `test/indexer_management_test.dart` (`client-tests.log`) |
| `python3 tools/contracts/generate.py --check` | 0 | PASS: deterministic API and serializer regeneration |
| `python3 plan/tools/validate_plan.py` | 0 | PASS |
| `python3 docs/evidence/M11/self-hosting-docs/validate_docs.py` | 0 | PASS: 6 documents, 39 local links/anchors |
| `python3 tools/security/scan_secrets.py` | 0 | no supported credential patterns found |

Server tests (`server/tests/Briani.DiscoveryTests/IndexerAdministrationTests.cs`) run the real `ProwlarrTransport` and `SafeHttp` against `FakeProwlarr`, a loopback stand-in built from the shapes above. They cover:

- A member gets 403 and an anonymous caller 401 on all seven routes, with no call reaching Prowlarr.
- The allowlist accepts the nine fixed operations and rejects 18 others (`system/status`, `config/host`, `testall`, `action/*`, `bulk`, `newznab`, `download`, traversal, query strings, wrong case or method).
- Malformed IDs, including encoded traversal, get 404 with no upstream call.
- The list contains no field values, credentials, mask strings or the Prowlarr key.
- Definition detail never returns secret defaults and shows definition HTML as plain text.
- Typed create values, the first sync profile, and validation before any write (unknown, info, hidden, base-settings, off-list base URL, bad select/checkbox/number, control characters, setup-in-Prowlarr, unknown definition).
- Rejection reasons with addresses and typed values removed.
- The toggle round trip keeps masked and Cardigann secrets, and a no-op toggle writes nothing.
- Enabling a failing indexer leaves it disabled.
- Test health with stored secrets scrubbed.
- Delete checks existence and protocol before removing.
- The live administrator re-check after the upstream call.
- A rejected Prowlarr key maps to a safe problem.

A mutation check confirmed the tests catch problems. Removing address scrubbing failed 2 tests, and removing the authorization policy and pre-check failed all 7 route cases.

### End to end against a local Prowlarr

`probe/compose.yaml` runs the pinned Prowlarr image with an nginx fixture site, under project name `briani-prowlarr-probe`, with a scratch config and only `127.0.0.1:29696` published. `probe/brianifixture.yml` is a generated private Cardigann definition, loaded from `Definitions/Custom`, whose search needs a fixture key. Briani ran from this branch with scratch state on `127.0.0.1:28088`, and `probe/e2e.py` drove it. Sanitized output is in `e2e-local-prowlarr.json`. Results:

- 637 torrent definitions listed (533 addable). The 104 others: 58 need FlareSolverr, 40 need unsupported settings such as a CAPTCHA, 5 are duplicate generic implementations (Generic Torznab and similar, Torrent RSS Feed), and 1 takes a typed site address. LinuxTracker and PandaCD are addable.
- A wrong key gave 400: "Prowlarr did not add this indexer: Unable to connect to indexer. Unexpected response status Unauthorized code from indexer request". The right key gave 201.
- Test passed. Disable, disable again (no write, no audit) and enable all worked, and a test after toggling still passed, so the Cardigann key survived the round trip.
- Unknown setting and off-list select gave 400, a setup-in-Prowlarr definition 409, and the traversal path 404.
- A member got 403 on all six routes tried.
- Delete gave 204, then 404.
- Audit recorded `indexer.created`, `indexer.disabled`, `indexer.enabled` and `indexer.deleted` once each.
- No response contained the fixture key or the Prowlarr API key.

## Limitations

- No Android phone, Android TV or physical remote was used. TV usability is covered by the D-pad widget test only.
- No real private tracker was added, and no real public indexer was contacted from the probe. Each Prowlarr test made by Briani is capped at 18 seconds so it answers before the client's 20-second timeout. For a slow site, the admin sees "Prowlarr did not answer in time…", and Prowlarr may still finish the change.
- Editing an existing indexer's settings, categories, priority, tags or sync profile is not offered. Remove and re-add, or use Prowlarr's page.
- Text settings a definition uses inside URLs are passed to Prowlarr as typed, the same as in Prowlarr's own UI. Only administrators can set them, and the base address is restricted to the definition's own links.
- No separate review pass was run. The findings below come from my own review.

## Review findings (fixed before handoff)

1. Prowlarr's privacy flag misses most Cardigann credentials. Secrets are now classified by type, privacy and name, and configured indexers never return values.
2. Native definition names with spaces ("M-Team - TP", "Secret Cinema", "Torrent Bytes") were silently dropped. Keys are now slugged, and a fixture covers it.
3. A no-op toggle wrote an audit row. Now only real changes are audited.
4. The definition list overflowed short dialogs (found by the widget test). It now takes at most 380 px of the available height.
5. Ordering addable definitions first relied on an unstable sort. It now uses two stable passes.
6. The global write gate would have been held across Prowlarr tests. The endpoints now take it only for the audit row.
