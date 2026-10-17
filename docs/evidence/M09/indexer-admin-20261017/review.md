# Indexer management: separate review (2026-10-17)

A second pass over commit `0377209` ("feat(admin): manage Prowlarr torrent indexers from Administration"), done separately from the self-review in `report.md`. It covered secret handling, the Prowlarr operation allowlist, authorization, create validation, the mutation lock, the client section and the contract additions, against specs 03, 04, 07 and 08. Line references are to `0377209` unless marked "now".

Each finding below was confirmed by reading the code and, for the four fixed ones, by a test that failed on `0377209` and passes after the fix. Nothing was run against the Pi or a real Prowlarr instance.

## Findings

| # | Severity | Finding | Status |
|---|---|---|---|
| 1 | Medium | A change queued behind another one reached Prowlarr after the administrator was demoted | Fixed |
| 2 | Medium | Prowlarr could apply a change without any audit row | Fixed |
| 3 | Low | Part of a credential could survive the scrubbing of Prowlarr's failure text | Fixed |
| 4 | Low | Parallel indexer tests could take both of SafeHttp's upstream slots, which discovery shares | Fixed |
| 5 | Low | The 18-second limit is per Prowlarr call, not per request | Open |
| 6 | Low | On TV, definitions Briani can't add can't be scrolled to | Fixed later (`tv-unaddable-definitions.md`) |
| 7 | Info | Audit rows for indexers show no resource | Open |
| 8 | Info | Specs 01/08 still describe a narrower scope | Owner decision |
| 9 | Info | Smaller notes | Open |

### 1. Demoted administrator's queued change still reached Prowlarr (Medium, fixed)

`IndexerManagement.cs:18,24,30` checked the live administrator once, and then `IndexerAdministration.cs:121,137,180` waited on the mutation lock with no further check before the write (`:125,148,185`). One holder can keep the lock for several 18-second calls, for example while Prowlarr tests a slow site before enabling it. A change queued in that window was sent even if the administrator had been demoted, disabled or signed out meanwhile. The check after the call answered 403, but Prowlarr had already changed. That is the "demoted admin mid-request" case, made wider by the lock.

**Fix:** create, toggle and delete now take an `authorize` callback, run inside the lock just before the write (now `IndexerAdministration.cs:129,153,199`; `IndexerManagement.cs:48`).
**Test:** `A_change_queued_behind_another_rechecks_the_administrator_before_writing`. On `0377209` it fails because the PUT reaches Prowlarr.

### 2. Prowlarr changes without an audit row (Medium, fixed)

Spec 04 requires administrator changes to be audited, and spec 03's `audit_events` has a `result` column. The audit row was written only after a change returned normally (`IndexerManagement.cs:19,25,31`). Two common paths skipped it:

- **The caller goes away.** The write used `RequestAborted` (`IndexerAdministration.cs:125,148,185`), and so did the status read after it (`:130,155`). If the TV app closed, the network dropped or the client's 20-second timeout fired, SafeHttp abandoned the request. Prowlarr, like any ASP.NET Core app that doesn't watch for disconnects, still applied the change, and the cancellation skipped the audit.
- **Prowlarr answers late.** When adding or enabling tests a slow site for longer than 18 seconds, Briani answered 504 `indexer_timeout` with no audit row, and Prowlarr then finished the change. The report already noted that Prowlarr may still apply it.

**Fix:** once a change is sent, it and the status read after it no longer follow the request's cancellation. The transport's 18-second deadline still bounds them. A late answer raises `UnconfirmedIndexerChange` (now `IndexerAdministration.cs:32,491`). The endpoint records the row with result `unconfirmed` and answers 504 `indexer_timeout` (now `IndexerManagement.cs:49-53`). The Administration audit list already shows any result other than `success` with the error icon.
**Tests:**
- `A_change_sent_to_Prowlarr_is_audited_when_the_caller_goes_away`. On `0377209` no row is written.
- `A_change_Prowlarr_does_not_confirm_in_time_is_audited_as_unconfirmed`, using a pass-through transport that applies the change and then reports a timeout. On `0377209` there are no rows.

### 3. Partial credential left by the failure-text scrubbing (Low, fixed)

`Reason()` cut each Prowlarr `errorMessage` to 300 characters (`IndexerAdministration.cs:442`). Only after that did it remove addresses and known setting values (`:450-452`). A value that crossed the cut was no longer matched whole, so its first characters stayed in the problem detail. Addresses were still caught, because a cut address still matches the address rule. The exposure is limited to administrators, but the scrubbing exists to stop exactly this.

**Fix:** control characters are stripped, then the whole message is scrubbed, then it is shortened (now `IndexerAdministration.cs:459,470`).
**Test:** `Long_rejection_reasons_are_scrubbed_before_they_are_shortened`. On `0377209` the first nine characters of the typed key come back.

### 4. Parallel tests starve discovery's upstream slots (Low, fixed)

`SafeHttp` allows two upstream requests at once for all of Briani (`SafeHttp.cs:24,43`), and discovery searches use the same instance. `TestAsync` (`IndexerAdministration.cs:160`) didn't take the mutation lock, and each indexer row tests on its own. Testing two slow indexers therefore held both slots for up to 18 seconds, and every user's search and source resolution waited or timed out.

**Fix:** tests take the same lock as changes, so this page holds at most one slot for its slow calls (now `IndexerAdministration.cs:169`).
**Test:** `Indexer_tests_run_one_at_a_time`. On `0377209` both tests reach Prowlarr together.

### 5. Per-call deadline, per-request client timeout (Low, open)

`ProwlarrTransport.cs:7` caps each Prowlarr call at 18 seconds "to answer before the client's 20-second receive timeout" (`client_session.dart:161`). A change makes several calls in a row, plus any wait for the lock:

- **Create:** schema (when cold), sync profiles, POST, then status.
- **Toggle:** GET, PUT, then status.

With finding 4, tests also wait for the lock. A slow Prowlarr test near the cap, or a change queued behind another, can outlast the client. The admin then sees a generic timeout while the change goes through. After finding 2 it is still audited, and a refresh shows it.

A per-request budget, or a bounded lock wait with its own "busy" answer, would close this gap. Either one needs a new error code and contract text, so I've left it for a decision.

### 6. TV: unaddable definitions out of reach (Low, open)

`indexer_management.dart:425-428` lists addable definitions first. `:468` disables every other tile, and a disabled `ListTile` can't take focus. With a remote, focus stops at the last addable entry, so the list never scrolls to the 100-odd definitions that need Prowlarr's page, or to their setup notes. Searching narrows the list, and their notes are readable once visible.

Making those tiles focusable but not tappable would fix this. It's a UX gap only: those definitions can't be added from Briani anyway.

**Later:** fixed in a follow-up; see `tv-unaddable-definitions.md`. On TV, Flutter's directional mode already let the disabled tiles take focus. The gap was real in traditional mode (keyboard, or a remote on a device not detected as a TV).

### 7. Audit rows for indexers show no resource (Info, open)

The audit list sets `resourceId` only when the target ID parses as a GUID (`AdministratorConfiguration.cs:85`, contract `AuditEntry.resourceId: uuid`). Indexer rows store Prowlarr's numeric ID, so "Indexer deleted" doesn't say which indexer. `configuration.updated` rows behave the same way. The ID is in the database. Showing it needs a contract change.

### 8. Scope against specs 01 and 08 (Info, owner decision)

Spec 08 (`plan/specs/08_DOCKER_AND_PI.md:67`) says Briani's native administration offers status, enabled sources and connection tests, and "should not reproduce every indexer's configuration schema". Add relays the plain settings of 533 of 637 torrent definitions, and Remove deletes indexers in Prowlarr. The report reads this as within the spec's intent. That's a reasonable reading, but it's a scope decision for the owner. Either the spec text gets updated, or Add/Remove are recorded as an accepted extension. I didn't edit the specs.

### 9. Smaller notes (Info)

- **Native masked secrets.** For toggle and test failures, Briani sees only `********` for native masked secrets. Only the address rule covers them. That rule (`IndexerAdministration.cs:44`) ends a URL at `)`, so a literal `)` before a query passkey would leave the rest of the URL visible. Prowlarr percent-encodes parentheses in query values, so I couldn't reach this path.
- **Back keeps typed values.** In the add dialog, Back (`indexer_management.dart:379-384`) keeps typed values in the form's controllers until the dialog closes or another definition is chosen. They stay in memory only: never persisted or logged, and there is no Dio logging interceptor.
- **Null setting values.** `IndexerCreate.settings` declares non-null string values (`contracts/openapi.yaml`, `IndexerCreate`). The server also accepts `null` and treats it as blank.

## Checked without findings

- **No values or keys in responses.** Configured-indexer responses (list, create, toggle) carry no field values. Definition detail never returns secret defaults. Audit rows hold only action, numeric ID, trace and result. The new code has no logger. The exception middleware writes problems without logging bodies or upstream text. The Prowlarr API key is sent only as a header to the configured origin.
- **Allowlist.**
  - Construction: `ProwlarrCall` has a private constructor and integer IDs.
  - Paths: patterns are anchored with `\A…\z`, use ASCII `[0-9]` and allow at most 64 characters.
  - Transport: it re-checks every call and the same-origin rule. Non-GET requests go only to the configured service. A 3xx answer is never followed and maps to `provider_unavailable`.
  - Request content: no client input reaches a path. Settings keys come only from the definition's own non-hidden, non-base fields. `implementation`, `configContract`, `appProfileId`, `tags` and `id` are set by the server.
- **Authorization.**
  - Every route needs the `administrator` policy plus the live database check (enabled, password not pending, administrator, valid access token and session), before and after the call.
  - Members and anonymous callers are refused with no upstream call.
  - Malformed and encoded-traversal IDs get 404.
- **Create validation.**
  - Refused settings: unknown, info, hidden, `baseSettings.*`, and a `baseUrl` outside the definition's links.
  - Typed values: select, checkbox, integer and decimal values are parsed. Control characters are refused.
  - Size limits: 48 settings of 4,096 characters each, and a 64 KiB request body.
  - Unknown members are refused.
- **Toggle round trip.** Prowlarr restores native masks. Cardigann values go back unchanged. A no-op toggle writes nothing.
- **Catalog cache.** It's keyed by the connection version, which increases on every integration change, and lasts 10 minutes. Entries are looked up by validated key and never used in a path.
- **Client.**
  - Secret fields are obscured, with suggestions and autocorrect off. Values live only in controllers that are disposed with the dialog.
  - Errors show the server's scrubbed text.
  - The search field doesn't autofocus on TV.
- **Contract.** The OpenAPI additions match the server's shapes and limits (patterns, `maxProperties: 48`, `maxLength`, `additionalProperties: false`, `writeOnly` settings).

## Verification

| Command | Exit | Result |
|---|---|---|
| `dotnet test server/tests/Briani.DiscoveryTests/DiscoveryTests.csproj --no-restore -m:1 --filter IndexerAdministrationTests`, new tests against the `0377209` sources | 1 | 5 new tests failed, 69 existing passed. This confirms findings 1–4 (`review-confirm-on-0377209.log`). |
| Same, after the fixes | 0 | 74 passed (`review-indexer-tests.log`) |
| `dotnet test server/Briani.sln --no-restore -m:1 --filter 'Category!=EngineIntegration'` | 0 | 533 passed, 0 failed: 528 before plus 5 new (`review-server-tests.log`) |
| `flutter analyze` (client) | 0 | No issues (`review-client-analyze.log`) |
| `flutter test` (client) | 0 | 150 passed (`review-client-tests.log`) |
| `python3 plan/tools/validate_plan.py` | 0 | PASS, after the `status.json` entry was added |
| `python3 tools/security/scan_secrets.py` | 0 | No supported credential patterns found |
| `python3 docs/evidence/M11/self-hosting-docs/validate_docs.py` | 0 | PASS: 6 documents, 39 local links/anchors |

This review didn't change any client code. Flutter ran as a regression check. The contract is also unchanged.

### Test changes

- `FakeProwlarr` can now pause only matching requests (`PauseOn`) and replace its failure text (`FailureMessage`).
- `TestHost` takes extra service registrations.
- `LateProwlarr` wraps the real transport so a change can be applied and then reported late.
