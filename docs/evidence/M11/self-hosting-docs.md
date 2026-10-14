# M11 documentation follow-up — 14 October 2026

## Scope and ownership

The user requested documentation for an end user self-hosting Briani, including Docker setup and client installation/use. This follow-up updates working repository documentation, rather than implementing a new milestone or certifying a release.

- Parent owned `README.md`, `docs/operations/README.md`, final integration, and evidence/status.
- `client_docs` worker (GPT-6 Luna / medium, narrow context) owned `docs/client-installation.md`, `docs/user-guide.md`, and `client/README.md`. Parent integrated corrections and additional installation details after the worker finished.
- Separate read-only `docs_review` reviewer (GPT-6 Luna / medium) checked commands, artifacts, UI labels, and platform claims, then reviewed the expanded Android/Linux/TV details. No recursive agents or overlapping editing occurred.

The work contributes documentation for R01/R02/R03/R09/R13/R20/R26 and the operational instructions associated with T25/T27/T30. It does not change those acceptance results or satisfy their outstanding runtime/distribution gates.

## Delivered documentation

The root README now directs users through server setup, app installation, and everyday use. The Docker guide covers prerequisites, mounted state/media storage, non-root identity, architecture-specific image loading, checksum verification, LAN binding and allowed hosts, host preflight, qBittorrent bootstrap ordering, Prowlarr credentials, first administrator, libraries and grants, private upstream administration via SSH, status/stop/start, backups, retained-media recovery, upgrade requirements, remote access, and troubleshooting.

The client guide provides Linux bundle extraction/runtime dependencies, Android phone/tablet installation, TV sideload and device-code pairing, Android minimum version/ABIs and debug package identity, unsigned APK restrictions, and Windows/macOS availability. The user guide covers actual screen labels, connection, sign-in, browsing/photos, discovery, file selection, downloading/import, buffering/seeking, external playback, remote controls, settings, and sessions.

Commands and behavior were checked against `infra/compose/`, `tools/operations/briani.py`, server bootstrap/storage/integration code, client screen/input/player code, `images.lock.json`, current archive contents, and M11 package evidence. Official Docker installation and Android adb references were checked on 14 October 2026; no upstream version or package name was inferred from memory.

## Verification commands and results

Run from the repository root. Full logs are in [self-hosting-docs/](self-hosting-docs/).

| Command | Exit | Result/artifact |
|---|---:|---|
| `python3 tools/operations/briani.py --help` | 0 | Checked available operations and options against examples |
| `python3 docs/evidence/M11/self-hosting-docs/validate_docs.py` | 0 | Five documents, 24 local links/anchors, 24 shell blocks checked with `bash -n`, 15 examples accepted by the actual operations parser, four Compose identity comparisons; `docs-check.log` |
| `python3 -m unittest discover -s tests/operations` | 0 | 26 tests; `operations-tests.log` |
| `python3 -m unittest discover -s tests/release` | 0 | 57 tests; `release-tools-tests.log` |
| `sha256sum -c --quiet dist/SHA256SUMS` | 0 | All 843 original packaged files verified; `checksums.log` is empty because the command is quiet on success |
| `python3 tools/dev.py release --task verify` | 2 | `source tree SHA-256 mismatch`; `release-verify.log`, detailed runner logs at `artifacts/dev/20261013T211351.751658Z/` |

The checks validate documentation syntax, references, current CLI option parsing, project identity, tooling regressions, and preserved package bytes. They do not execute the installation examples against a real server. The Compose helper was compared with the actual tool for ordinary, spaced, fallback-slug, and long project paths. No test weakened security or mounted production data.

## Review findings and integration corrections

Independent review returned no priority findings. It specifically verified startup ordering, the matching hashed Compose project name, loopback administration, LAN/allowed-host configuration, credential defaults, bootstrap regeneration, Linux runtime libraries, Android APK identity/ABIs, remote bindings, and truthful platform availability.

Parent integration corrected the initial client draft's server-port example from 8080 to 8088, matched the exact connection-error and first-administrator labels, and removed an incorrect implication that returning from external playback automatically resumes the embedded player. Added concrete TV/phone installation steps and Linux libsecret/runtime-storage guidance. The final documentation check passed after integration.

## Limitations and handoff

No application, contract, image, client binary, or deployment configuration changed. No service was started/stopped on behalf of the user, indexer account configured, router port forwarded, artifact published, signing performed, or production data modified. Full server/client and clean-install/restore/hardware suites were not rerun for a documentation-only change; their original evidence and blockers remain intact.

`dist/` remains the original candidate snapshot, including its embedded READMEs and source archive. Its 843 checksum entries still pass. The source documentation now differs from the original manifest's source-tree identity, so release verification correctly exits 2; rebuilding the candidate with matching provenance is separate packaging work. Do not report the previous release-verifier exit 3 as the result of this updated tree.

`plan/evidence/status.json` records this documentation follow-up without promoting any milestone or release gate. Native Pi/physical Android, Windows/macOS, signing, license/native-source, optimized playback, engine reconnect, and coverage limitations remain unchanged. There is no subsequent implementation milestone assigned by this request. Users should begin at `README.md`; any future release packaging must include the rewritten guides and regenerate the matching source/provenance/checksum records.
