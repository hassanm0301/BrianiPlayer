# Docker Compose setup follow-up

Date: 2026-10-14. Scope: add direct Compose deployment files and instructions while retaining required paths.

The user withdrew the optional-media-path request. All associated client, server, contract, storage-default, setup-command, and specification changes were reverted to the initial checkout. Task-created optional-path tests and documentation were removed. The ongoing disposable drill was interrupted; its cleanup verified removal of its exact owned containers, networks, volumes, temporary image, and files. A sanitized cleanup excerpt is in `compose-setup/interrupted-drill-cleanup.log`. No production deployment was changed.

The retained change generates `compose.yaml` and `compose.admin.yaml` beside the protected deployment `.env` during init, up, and restore. Ordinary Compose and the operations tool use the same unique deployment identity. Existing custom manifests are preserved only when their explicit project name matches; conflicting/missing names and symlinks are rejected. The original installer still requires `--data` and `--state`, mounted storage, UID/GID, binding, and audited image selection. Compose itself now rejects missing BRIANI_DATA/BRIANI_STATE values and refuses automatic creation of absent bind sources.

The setup guide retains its original required-folder and credential steps, then documents `docker compose up -d` and `docker compose ps` in the generated deployment folder. No new native-client UI or server behavior remains.

Verification artifacts are under `docs/evidence/M09/compose-setup/`:

- Operations tool tests: 30 passed, exit 0 (`operations-tests.log`). New cases cover required path arguments, consistent identity, preserved custom manifests, and conflicting names/symlinks.
- Full operations suite: exit 0, eight server and 30 Python tests passed (`operations-suite.log`).
- Actual Compose config rendering: configured paths exit 0; missing media or state path each rejected with exit 1 (`compose-config.json`). Rendering does not launch containers.
- Documentation validation: exit 0, six documents, 35 links/anchors, 32 shell blocks, 21 parser examples (`docs.log`).
- Plan structural validation and diff whitespace: exit 0 (`plan.log` for the structural check).

A separate read-only reviewer confirmed optional-path behavior was removed and identified a preserved-manifest identity gap. The gap was fixed with explicit name validation and regression coverage. Existing hardware and release certification blockers remain unchanged. Updated operations files have not been repackaged into the original dist archive; no publication occurred. Earlier optional-feature checks are not claimed as final retained-feature install or hardware verification.
