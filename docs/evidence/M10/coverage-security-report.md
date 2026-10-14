# Scoped security branch tests — 13 October 2026

Worker scope: new test files only; no production source, contracts, migrations, package locks, Pi access, Docker execution, or external network calls. Parent owns integrated acceptance/status accounting.

## Changes

- `server/tests/Briani.IdentityTests/PermissionBoundaryTests.cs`: explicit owner/non-owner, manager, shared and destructive download-control cases; discovery eligibility after library/session/password state changes.
- `server/tests/Briani.IdentityTests/SecretPersistenceBoundaryTests.cs`: reject retained keys of invalid length without replacing them; retain/reopen the key; restore owner-only permissions; reject truncated and nonce/tag/ciphertext-tampered AES-GCM envelopes; bootstrap replacement/removal.
- `server/tests/Briani.DiscoveryTests/MetainfoBoundaryTests.cs`: malformed v2 root/leaf trees, missing/short roots and negative lengths; hybrid padding/alignment/file-list disagreement; valid hybrid padding and shared v2 Merkle-layer verification with distinct paths and an empty file.
- `server/tests/Briani.DownloadTests/ProgressiveWatchdogBoundaryTests.cs`: fourteen open-stream changes covering ticket/session/auth/grant, job/file generation, replaced paths, grown descriptors and actual availability invalidation using the existing fake engine. A healthy tick first persists activity in the revocation case.
- `server/tests/Briani.MediaTests/CompletedWatchdogBoundaryTests.cs`: eleven open-stream changes covering missing/revoked/expired session, disabled/password-change/auth state, disabled library, media generation and file identity/length/mtime. One healthy tick precedes revocation.

Watchdog tests invoke the real playback service with a response stream whose first write remains blocked. They verify that the attempted bytes match generated fixture bytes, the response is aborted, its write is cancelled, there is no second write, and the active reader lease is released. They do not simulate a hardware player or claim real-engine acceptance. The fixtures use manual timestamps and the watchdog's real one-second timer; every wait is bounded.

## Commands and results

Each command below used `DOTNET_CLI_HOME="$PWD/.tools/dotnet-home" DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1`; outputs were redirected to the listed log. Collection is the installed `Code Coverage` collector, format `cobertura`. The runner requires localhost sockets; precise local test execution was allowed through automatic approval after the sandbox's initial socket denial.

| Command after `.tools/dotnet/dotnet test` | Exit | Tests | Log |
| --- | ---: | ---: | --- |
| `server/tests/Briani.IdentityTests/IdentityTests.csproj --no-restore --nologo --collect 'Code Coverage;Format=cobertura' --results-directory artifacts/coverage-security/identity-final` | 0 | 44 passed, 0 failed, 0 skipped | `coverage-security-identity-final.log` |
| `server/tests/Briani.DiscoveryTests/DiscoveryTests.csproj --no-restore --nologo --filter 'FullyQualifiedName~SourceMetainfoTests\|FullyQualifiedName~MetainfoBoundaryTests' --collect 'Code Coverage;Format=cobertura' --results-directory artifacts/coverage-security/metainfo-final` | 0 | 31 passed, 0 failed, 0 skipped | `coverage-security-metainfo-final.log` |
| `server/tests/Briani.DownloadTests/DownloadTests.csproj --no-restore --nologo --filter 'FullyQualifiedName~ProgressiveWatchdogBoundaryTests' --collect 'Code Coverage;Format=cobertura' --results-directory artifacts/coverage-security/progressive-final` | 0 | 14 passed, 0 failed, 0 skipped | `coverage-security-progressive-final.log` |
| `server/tests/Briani.MediaTests/MediaTests.csproj --no-restore --nologo --filter 'FullyQualifiedName~CompletedWatchdogBoundaryTests' --collect 'Code Coverage;Format=cobertura' --results-directory artifacts/coverage-security/completed` | 0 | 11 passed, 0 failed, 0 skipped | `coverage-security-completed.log` |

Earlier focused runs passed Identity 12, new Discovery 13 and progressive 14; their artifacts/logs remain under `artifacts/coverage-security/{identity,discovery,progressive}` and `coverage-security-{identity,discovery,progressive}.log`. The final progressive run supersedes the earlier run because the healthy persistence assertion was added afterward. Initial failures were runner localhost-socket denial (exit 1) and Discovery build analyzer xUnit2031, corrected by using `Assert.Single(collection, predicate)` (exit 1); neither was a test pass.

## Literal collected branch results

Counts below are taken from the matching Cobertura class's source-line `condition-coverage` totals and agree with its reported `branch-rate`. They are scoped measurements, not an overall application coverage claim.

| Source class/method | Covered/valid | Branch rate | Report set |
| --- | ---: | ---: | --- |
| `PermissionService.CanDiscoverAsync` | 2/2 | 100% | identity-final |
| `PermissionService.RequireDownloadControlAsync` | 10/10 | 100% | identity-final |
| `PermissionService.CapabilitiesAsync` | 25/26 | 96.15% | identity-final |
| `SecretStore` | 6/8 | 75% | identity-final |
| `Metainfo` | 202/240 | 84.17% | metainfo-final |
| `BencodeReader` | 34/54 | 62.96% | metainfo-final |
| `ProgressivePlayback.WatchAsync` | 28/28 | 100% | progressive-final |
| `CompletedPlayback.WatchAsync` | 22/22 | 100% | completed |

Raw reports:

- `artifacts/coverage-security/identity-final/4395f71f-4866-4d91-b615-257d3ea0820d/hassan_archlinux_2026-10-13.12_16_41.cobertura.xml`
- `artifacts/coverage-security/metainfo-final/27fa5476-0001-4f3d-a517-3581d670eae5/hassan_archlinux_2026-10-13.12_16_09.cobertura.xml`
- `artifacts/coverage-security/progressive-final/52ee6dc4-d2b9-418c-99b4-be75e0643d8f/hassan_archlinux_2026-10-13.12_15_42.cobertura.xml`
- `artifacts/coverage-security/completed/d7c5a211-3b59-4bc2-9d93-004162cfddd9/hassan_archlinux_2026-10-13.12_14_42.cobertura.xml`

## Remaining limits and review findings

The ≥90% critical-module target is not established for all modules by this scoped run. The parser selection omits `ParserPropertyTests` and other source API/resolver tests; parent must include those in its integrated collection. Its `Metainfo` denominator is 240 whereas the earlier broad report denominator was 146. Do not average percentages or naively add counters across these reports; a current integrated collection must resolve the measurement.

`SecretStore` retains two uncovered outcomes: the unsupported non-Linux platform branch at line 11 and native permission-reset failure at line 13. Normal owned files on this Linux test host cannot induce the latter. No mounts, host permission changes or production modifications were introduced merely to cover it. This remains an explicit measurement limitation.

No compiler-generated classes were excluded. In particular, async `<…>d__` classes contain the handwritten authorization and watchdog predicates and remain included. Watchdog reported coverage does not replace the named real-engine, hardware or complete-system acceptance scenarios. No production defect was reproduced by the new tests.
