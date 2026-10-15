# Landlock-free containment and Pi candidate — 2026-10-15

The Landlock dependency is removed. Local application/security checks and native ARM64 containment checks passed, including the actual nested Hassan/Family bind layout. The updated private image and operations package are staged on `hassan@192.168.100.186`. **Production remains stopped:** Docker reports `MemoryLimit=false`; the operations tool still rejects startup. No kernel, boot settings, account permissions, existing service, indexer account or existing media was changed. No reboot occurred.

## Implementation and accepted boundary

`MutationSandbox.cs` was replaced by `DirectorySafety.cs` and descriptor-based operations in `ContainedStorage.cs`. Path opens use `openat2` with `RESOLVE_BENEATH|RESOLVE_NO_SYMLINKS`. Retained boundaries, library scopes and child handles are revalidated by mount/device/inode identity. Mutation parents and regular-file source identities are checked immediately before mutation; Briani filesystem operations share a process-wide gate. Copies of retained descriptors use atomic `F_DUPFD_CLOEXEC`. Existing authorization and original containment/race tests remain intact. No API contract or migration changed.

The user explicitly accepted dedicated Briani folders on both drives. Host administrators and the managed engine remain trusted writers. Stop Briani before external directory moves, renames or replacements inside its writable folders. Revalidation cannot atomically prevent an arbitrary local process moving an ancestor between the final check and a mutation syscall; this is not a claim of Landlock-equivalent enforcement against hostile local writers. Other apps may read these folders.

The operations preflight now probes `openat2` instead of Landlock. Memory-controller enforcement remains required. Documentation describes the folder ownership rule and the remaining limitation.

## Checks and evidence

| Check | Result / exit code | Artifact |
|---|---|---|
| Final sequential server solution, excluding harness-only EngineIntegration | 421 passed / 0 | `server-regression-final.log` |
| Full identity suite with all three Landlock syscalls forced to ENOSYS | 52 passed / 0; subset of the 421 | `identity-no-landlock-final.log`, `identity-no-landlock.log` |
| Operations Python suite | 32 passed / 0 | `operations-tests.log` |
| Isolated real qBittorrent adapter and metadata/layout harnesses | 1 + 1 passed / 0 each | `engine-adapter.json`, `engine-metadata.json` |
| Exact-run engine cleanup | No test resources remain / 0 | `engine-cleanup.json` |
| API/probe portable publish and ARM64 COPY-only image build | 0 each | `publish-final.log`, `probe-publish-final.log`, `image-arm64-build-final.log` |
| Native Pi create/read/link/rename/unlink, symlink rejection, moved-child rejection | Three cases on each drive / 0 | `pi-final-verification.log` |
| Native Pi scoped libraries, overlap checks and operations across nested Family bind | Both libraries passed / 0 | `pi-final-verification.log` |
| Final Pi doctor | Expected refusal / 2, memory enforcement only | `pi-final-verification.log` |
| Final two-drive Compose rendering and package integrity | Correct binds, nine hashes, protected env/backup, no production containers / 0 | `pi-final-state.json` |
| Plan structural validation; whitespace check | 1062 checks / 0; diff check / 0 | `plan-validation.log` |

The first parallel solution invocation had one timeout in `Revoking_library_read_grant_aborts_an_active_stream` (420 passed, one failed). It passed unchanged in isolation and in both sequential solution runs. The timeout/root cause is not conclusively diagnosed; no assertion or timeout was relaxed. Retained logs: `server-regression.log`, `stream-revocation-recheck.log`, `server-regression-serial.log`. An attempt to reuse the worker's already-cleaned temporary seccomp launcher exited 127 before tests; rebuilding the launcher at the persistent artifact path resolved that invocation issue.

Reproduction from repository root:

```sh
dotnet test server/Briani.sln --no-restore -m:1 --filter 'Category!=EngineIntegration' --logger 'console;verbosity=minimal'
cc -std=c11 -O2 -Wall -Wextra -Werror -o artifacts/landlock-free/deny_landlock prototypes/security/no_landlock/deny_landlock.c
artifacts/landlock-free/deny_landlock dotnet test server/tests/Briani.IdentityTests/IdentityTests.csproj --no-build --no-restore --logger 'console;verbosity=minimal'
python3 -m unittest discover -s tests/operations -v
dotnet publish server/src/Briani.Api/Briani.Api.csproj -c Release --no-restore -p:UseAppHost=false -o artifacts/landlock-free/api
dotnet publish prototypes/security/no_landlock/pi_probe/Briani.PiContainmentProbe.csproj -c Release --no-restore --self-contained false -p:UseAppHost=false -o artifacts/landlock-free/probe
docker --config .tools/docker-config buildx build --platform linux/arm64 --pull=false --load --provenance=false --build-arg BASE_IMAGE=briani-server:m10-arm64 -t briani-server:landlock-free-20261015-arm64 -f artifacts/landlock-free/Dockerfile artifacts/landlock-free
```

Engine commands use the existing `prototypes/downloads/engine/run_pinned_engine.py` and `run_local_peer_transfer.py`, sequentially, each wrapped in `timeout --signal=INT --kill-after=20s 300s`, with `DOCKER_CONFIG=$PWD/.tools/docker-config`, `DOTNET_CLI_HOME=$PWD/.tools/dotnet-home`, and `NUGET_PACKAGES=$PWD/.tools/nuget`. Their exact output and isolated run IDs are in the JSON artifacts. No real indexer or public torrent was used.

`pi-final-verification.py` records the exact native commands and hash assertions, after transferring the image/probe/Compose files. Three one-shot Compose containers ran as UID/GID 1000 with no network, dropped capabilities, read-only root, bounded CPU/PIDs/temporary storage, 256 MiB managed-heap ceiling and 60-second outer timeout. This bounded fixture exercise did not bypass production startup or establish a host-enforced memory cap. Generated fixtures and test containers were removed. The two Compose files are retained here.

## Review and deployment handoff

A separate Sol security reviewer found no blocker under the accepted trusted-host/dedicated-folder boundary. Review fixes cover exception-path descriptor cleanup, required `statx` mount-ID data, serialized disposal, traversal-only ancestry handles and close-on-exec descriptor duplication. Sol handled containment tests; Luna handled operations compatibility and isolated engine verification. Final tests include the review fixes.

Current package: `/home/hassan/briani/package-landlock-free-20261015`; launcher: its `briani` file. Existing project: `/home/hassan/briani/ops`. Prior package and `.env.before-landlock-free-20261015` are preserved. `README.txt` on the Pi records current status and the dedicated-folder rule. The package preserves identical two-drive bindings for Briani and qBittorrent. Its private lock and nine-file manifest are copied here; repository release image locks and archives were not replaced or published.

Final image tag: `briani-server:landlock-free-20261015-arm64`; OCI manifest: `sha256:ffa6cea3d8eecada770f882c79cb6f0403932c5eb496f670f091e41ce5724cb1`; native Docker config identity: `sha256:101712497fce90e254adb3b9576bb50582fd6f81a3535b8be43c1bf840d52c64`. API DLL hash is identical in the published image payload and probe. Native kernel remains `6.18.50+rpt-rpi-2712`, Landlock returns ENOSYS, and `openat2` succeeds (`pi-current-preflight.json`).

No full-stack startup, administrator/library creation, client check, Pi performance/soak or release certification is claimed. Existing milestone/release blockers remain. The next deployment blocker is memory-limit enforcement; no kernel or boot change was authorized or attempted.
