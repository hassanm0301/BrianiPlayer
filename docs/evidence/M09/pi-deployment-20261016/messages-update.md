# Server-authored messages, unrestricted passwords, confirm password — 16 October 2026

Status: **deployed to the Pi; administrator not yet claimed.** The `hassan` account lost passwordless sudo at 02:47. The owner then authorized using the dedicated `claude` account (key `~/.ssh/claude_pi`, passwordless sudo) for the Docker steps.

## Owner decisions implemented

1. **The server writes every message; clients display it.** `Infrastructure/Security/ErrorMessages.cs` holds a message for every error code. `ApiException`, `Problems.WriteAsync` and framework problem details default `title`/`detail` to that message. Validation sites add specific details, such as username rules, named text fields, settings ranges derived from the embedded schema, library/access rules and search text. Operation and job `error` objects are now full problems with messages. Download `errorDetail` comes from the catalog. Page `warnings` keep codes in storage and render as sentences at the API boundary, e.g. `Indexer 'a' is temporarily disabled by Prowlarr.`
2. **No password restrictions.** The 12–128 length rule is gone from server, contract, client and docs. Login no longer rejects long passwords. Only presence is required; empty, 1-character and 5000-character passwords are covered by a test.
3. **Confirm password.** `confirmPassword` is required on bootstrap and admin create-user. `confirmNewPassword` is required on change-password and admin reset-password. The server compares them; a mismatch returns 400 `password_mismatch`, "The passwords do not match." The client adds the fields to the bootstrap screen, the create-member dialog and the reset dialog. Change-password already had one; its client-side mismatch check now goes through the server.

Client behavior: `clientError` returns the problem `detail` (falling back to `title`), including problem bodies from byte/text endpoints. Client-written text remains only where no server reply exists (unreachable server, certificate failure, missing problem body), for device-local failures (fullscreen, external player), and for parsing non-numeric text in number fields. Client validators that duplicated server rules were removed: password length, required fields, settings ranges, URL shape, list sizes. Thirteen `catch (_)` handlers around server calls that replaced the server's reason with fixed text now show the server message. So do the folder-operation and download status-code overrides and the connection test.

Contract: `contracts/openapi.yaml` updates the four password schemas and documents `Problem` and `warnings`/`errorDetail` as display text. `plan/specs/12_API_CONTRACT.md` and `07_SECURITY.md` record the rule. The Dart client was regenerated with the pinned generator. No database migration.

## Verification

| Check | Result / exit | Log (in `messages/`) |
|---|---|---|
| `dotnet test server/Briani.sln --no-restore -m:1 --filter 'Category!=EngineIntegration'` | 424 passed, 0 failed / 0 | `server-tests.log` |
| New identity tests: no password rules, mismatch message, readable problems, every thrown code has a catalog message | Included above (Identity 55/55) | `identity-tests.log` (earlier run, before the final message was added) |
| `flutter test` (client) | 116 passed / 0 | `client-tests.log` |
| `flutter analyze` | No issues / 0 | — |
| `python3 tools/contracts/generate.py --check` | No drift / 0 | `contract-check.log` |
| `python3 -m unittest discover -s tests/operations` | 32 passed / 0 | `operations-tests.log` |
| `python3 plan/tools/validate_plan.py` | Pass / 0 | `plan-validation.log` |
| `git diff --check` | 0 | — |
| ARM64 COPY-only overlay build on `briani-server:landlock-free-20261015-arm64` | 0; image `sha256:143fb5f0…bb16`, config `sha256:963a2ad4…8bb4` | `image-arm64-build.log` |
| Archive transfer to Pi | SHA-256 matched (`a49dcdce…04f9`) | `image-archive.sha256` |

The first full-suite run found two issues, both fixed and rerun: an xUnit analyzer error in the new test, and a missing catalog message (`permission_changed`) caught by the coverage test.

Harness scripts that call these endpoints (`tools/operations/drill.py`, `tools/media_container_probe.py`, and the M05–M08 prototype runners) now send confirmation fields. Their full-stack runs were not repeated. The desktop/Android end-to-end suites were not run.

## Pi rollout (pending owner)

Staged without root:

- `/home/hassan/briani/package-me## Pi rollout

Done as `claude@192.168.100.186`, using sudo only for Docker and for reading or copying root-readable state. File edits ran as `hassan`.

| Step | Result |
|---|---|
| Archive SHA-256 on Pi | `a49dcdce…04f9`, matches the local build |
| `docker image load` | ID `sha256:963a2ad4…8bb4` (arm64), equal to the `runtimeConfigDigest` in the package's image lock |
| Stop `briani`; `cp -a` state and `.env` | `/mnt/hassan_drive/briani/backups/before-messages-20261016-034943` (15 MB) plus `.env` copy |
| `.env` | Copied to `ops/.env.before-messages-20261016`; `BRIANI_IMAGE=briani-server:messages-20261016-arm64` |
| `docker compose --project-directory ops up -d` | Only `briani` was recreated; qBittorrent, Prowlarr and the guard kept running |
| `/healthz`, `/readyz` from LAN | 200 / 200 |
| Live bootstrap with mismatched confirmation | 400 `password_mismatch`, "The passwords do not match." |
| Live bootstrap with 1-character username | 400 with the specific username rule |
| Live bootstrap with 4-character password and matching confirmation (wrong code) | Passes validation; 403 `bootstrap_unavailable` with a readable message (proves no length rule) |
| `--regenerate-bootstrap` one-shot (stop, run, `up -d briani`) | New 30-minute code issued and given to the owner; `/readyz` 200 |

The operations tool's `doctor`/`up` and its image-lock check were not run in this rollout, because they invoke Docker through `hassan`'s now password-protected sudo. The image ID was checked against the lock by hand. The host checks `doctor` covers (memory cgroup, openat2, mounts) passed earlier today on the same boot.

Rollback: `cp /home/hassan/briani/ops/.env.before-messages-20261016 /home/hassan/briani/ops/.env`, then `docker compose --project-directory /home/hassan/briani/ops up -d briani`. The state backup above is from before the switch; there was no schema migration.

## Cleanup

At the owner's explicit request, all six backups were permanently deleted on 2026-10-16: the state backup and its `.env` copy, both `ops/.env.before-*` files, `README.before-20261016.txt`, and `/boot/firmware/cmdline.txt.before-briani-20261016`. The rollback steps above no longer apply. Rolling back now means setting `BRIANI_IMAGE=briani-server:landlock-free-20261015-arm64` (still loaded) and running `up -d briani`. Undoing the boot change means removing ` cgroup_enable=memory` from `cmdline.txt` and rebooting. `/readyz` returned 200 after cleanup.
