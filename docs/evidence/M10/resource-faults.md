# M10 local resource fault probes

**Result:** the bounded local storage-fault cases and private TCP disconnect/recovery case passed on 2026-10-13. The probe calls Briani's production `ContainedStorage` and `DownloadAdmission` code in the locked server runtime image, with a fresh SQLite database and generated 32 KiB fixture. Raw structured measurements are in [resource-faults.json](resource-faults.json).

The runtime image ID observed locally and recorded in `images.lock.json` was `sha256:95ab935e5834f4dab1390fbea017dbfd4a99a0d5b998b01e7acf808a89fc9b3b` (amd64, .NET runtime 10.0.12). This is the repository's locked image ID; an assignment message contained a transposed digest and was not used as the source of truth.

The actual disk-full case used an 8 MiB tmpfs mounted at `/data/library`. The probe wrote 8,355,840 bytes before the filesystem returned `IOException` with `errno 28` and zero free bytes. Production admission then returned HTTP 507 `disk_full`; SQLite still contained zero download jobs and zero requests. The retained fixture and a post-cleanup recovery write both matched SHA-256 `09FED9CBFB98B6AB0F3E8FF63B7B1F9B0E07D58B225295C78FDC023CC4985A72`.

For the mount cases, the runner persisted a library identity and fixture, then mounted that fixture read-only. The production volume check reported unwritable, file creation failed, and admission returned 409 `disk_unavailable`; the fixture hash stayed unchanged. With the same database but an empty replacement data root, admission returned 409 `path_unavailable` and did not create or adopt a library directory.

The raw TCP case used two containers on a Docker `--internal` network and recovered the same 32 KiB fixture after disconnecting only its owned client. For qBittorrent, one spontaneous recovery completed, while two other unassisted runs stalled at 30- and 210-second deadlines without an intervening control change. A corrected controlled receiver restart retained the partial bytes and completed after re-adding the exact private fixture peer. The explicit restart recovery path passed; spontaneous engine-reconnect reliability remains limited/open. See [qbittorrent-network-loss.md](qbittorrent-network-loss.md). The production `SecretStore` read-only state case, including its cold constructor proof, is documented in [resource-fault-secret-store.md](resource-fault-secret-store.md). T14's quota race and complete engine egress policy remain separate acceptance work.

## Reproduction and exit codes

All commands ran from the repository root. The probe build used cached, already-resolved dependencies because NuGet's advisory endpoint was unreachable from the restricted network; `NuGetAudit=false` was scoped to this temporary prototype restore and did not change a repository lock file or production build setting.

```sh
python -m unittest prototypes.security.resource_faults.test_run
# exit 0: 2 ownership/cleanup tests passed

python -m py_compile prototypes/security/resource_faults/run.py
# exit 0

DOTNET_CLI_HOME="$PWD/.tools/dotnet-home" NUGET_PACKAGES="$PWD/.tools/nuget" \
  dotnet restore prototypes/security/resource_faults/ResourceProbe.csproj \
  --ignore-failed-sources --nologo -p:NuGetAudit=false
# exit 0; cached package graph, audit service unavailable

DOTNET_CLI_HOME="$PWD/.tools/dotnet-home" NUGET_PACKAGES="$PWD/.tools/nuget" \
  dotnet publish prototypes/security/resource_faults/ResourceProbe.csproj \
  --configuration Release --no-restore --output /tmp/briani-resource-probe-security-publish --nologo
# exit 0

DOCKER_CONFIG="$PWD/.tools/docker-config" \
  python prototypes/security/resource_faults/run.py \
  --probe-publish /tmp/briani-resource-probe-security-publish \
  --output docs/evidence/M10/resource-faults.json
# exit 0; final run ID 7a85c18f8bb24b3baf667f62dc5db997
```

The final run removed six exact run-labelled container IDs and its network ID. The ownership-filtered `docker ps -a` and `docker network ls` checks returned no resources, and the marked scratch directory was absent. No global prune, host firewall, production service, Pi, or host data path was touched. The test fixture was generated in the owned scratch directory and removed after its SHA-256 was recorded.
