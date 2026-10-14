# M01 — Repository and build foundation

## Summary

Milestone: M01. Evidence date: 2026-10-12. Code status: foundation implementation in progress/integrated locally. Verification status: local Linux/amd64 checks are evidenced; platform and hardware gates remain blocked or pending. Commit: unavailable. M01 is not represented as fully complete by this report.

## Environment and versions

Observed local toolchain details and pinned image digests are recorded in `toolchain.lock.json`; development notes are in `docs/development/foundation.md`. The environment is Linux/amd64. Windows and macOS runners were unavailable. Raspberry Pi access is pending, and final Android TV device-stage verification remains pending. Local Android APK debug build evidence was reported by the implementation run; its raw log is not present in this handoff directory.

## Implemented behavior

The repository contains the .NET solution, SQLite-backed server foundation, Flutter shell, frozen OpenAPI contract and generated Dart client, Compose manifests, CI workflow, task runner, and lock artifacts. The OpenAPI generator check reports deterministic API and serializer regeneration. Dependency versions are enumerated in `docs/development/dependency-inventory.md`, sourced from six committed NuGet/Flutter locks. A portable local credential scanner and focused tests are included in this handoff.

## Commands and results

| Command | Environment | Exit status | Evidence |
|---|---|---:|---|
| `python tools/dev.py doctor` | Linux/amd64 | 0 | `artifacts/dev/20261012T082028.833029Z/run.json`; detailed output `/tmp/briani-doctor.log` |
| `dotnet build server/Briani.sln --nologo` | .NET SDK 10.0.112 | 0 | `/tmp/briani-foundation-build.log`; runner record `artifacts/dev/20261012T082031.837351Z/run.json` |
| Server unit, contract, integration projects | .NET 10 | 0; 6 tests total (3 unit, 1 contract, 2 integration) | `/tmp/briani-server-tests.log` |
| `python tools/contracts/generate.py --check` | OpenAPI Generator 7.26.0 | 0 | `/tmp/briani-generation-check.log` |
| `python tools/dev.py compose --task smoke` | Docker Compose 5.6.0, isolated test project | 0 | `artifacts/dev/20261012T080405.985744Z/run.json` |
| `python -m unittest discover -s tests/tools -p test_scan_secrets.py` | Python 3.14 | 0; 5 tests | Current local command; scanner tests added in this handoff |
| `python tools/security/scan_secrets.py` | Repository tree | 0 | Current local command; no supported patterns found |
| `python tools/dependencies/inventory.py` | Six committed lock artifacts | 0 | Current local command; output `docs/development/dependency-inventory.md` |
| Flutter analyze/test, Linux debug and Android APK debug | Flutter 3.47.6 | exit0; analyze and6 client tests captured | /tmp/briani-m01-client-analyze.log and /tmp/briani-m01-client-tests-final.log; Linux/APK builds reported separately by worker |
| Multi-architecture image build | Current host/buildx | amd64 image build passed; ARM64 not verified | `/tmp/briani-image-build.log`; actual image digest in local Docker/build evidence |

The clean .NET build and image build logs show no errors. Existing earlier exploratory task-runner attempts failed before the successful final doctor/build/Compose evidence; those are retained in `artifacts/dev/` and are not presented as successful final runs.

## Independent review

Review finding P1: the remote HTTP insecure-transport option required a client-side guard before credentials were read from the vault or sent over an unapproved HTTP origin. The parent reports the `allowInsecureHttp` guard is fixed before reading stored credentials. Parent owns the review fix and its regression evidence. A separate review agent was not used for this report; no review-agent activity is claimed.

## Blockers and remaining checks

Windows/macOS builds are blocked by unavailable runners. Native ARM64/Raspberry Pi 5 validation is blocked pending device access. Android TV final-stage checks remain pending. The report does not claim successful benchmark profile or release verification. Contract generation, client, and Compose claims are bounded to the recorded commands above; raw logs for some client checks were not preserved in this evidence set.

## Handoff

Proceed to M02 only under the parent’s integration decision and current milestone status. Keep the API contract and lockfiles stable. Re-run the recorded Flutter commands from a clean checkout if the missing raw logs are needed as durable evidence. M00 remains a synthetic local engine proof, not Pi certification.
