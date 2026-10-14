# SecretStore read-only state fault

**Result: passed** in actual local containers on 2026-10-13. Run `472c22e64eb540cdbf6c27d463a0f8c5` used the pinned `briani-server:m10` image (`sha256:95ab935e5834f4dab1390fbea017dbfd4a99a0d5b998b01e7acf808a89fc9b3b`). It generated a key through production `SecretStore` on an owned writable config root, then mounted that same owned root read-only for the fault case. The probe did not preload fixture or LINQ helpers before constructing `SecretStore`.

The writable baseline generated a 32-byte key and passed constructor, encryption/decryption, and reopen/decryption checks. Its SHA-256 was `9E552512D91C804290334C878DA85F33C582004C25FB86C1C5BD5D68CC69A0F2`. In the read-only mount case, the production constructor returned HTTP 503 `secret_store_unavailable`; the exact key bytes and hash remained unchanged. The probe made no write-permission changes, used no syscall mock, and changed no production setting. The full structured result is [resource-fault-secret-store.json](resource-fault-secret-store.json).

The original probe attempt is preserved in [resource-fault-secret-store-startup-failure.json](resource-fault-secret-store-startup-failure.json) as a non-acceptance diagnostic. It reached the contained-file path before the fixture had loaded `System.Linq`, and the mutation sandbox's restricted worker could not load it. The production fix replaced the LINQ call with CoreLib iteration. This fresh run exercised the constructor cold, without a probe warmup, and reached the intended read-only failure. All storage scenarios in the run passed; six exact owner-labelled containers were removed without cleanup errors.

## Reproduction and exit codes

The restore used the project lock file and kept NuGet auditing enabled. The normal sandboxed restore could not reach `api.nuget.org`; the following scoped elevated restore completed successfully and emitted no audit warning:

```sh
DOTNET_CLI_HOME="$PWD/.tools/dotnet-home" NUGET_PACKAGES="$PWD/.tools/nuget" \
  dotnet restore prototypes/security/resource_faults/ResourceProbe.csproj \
  --locked-mode --nologo
# exit 0; locked packages restored with NuGet audit enabled

DOTNET_CLI_HOME="$PWD/.tools/dotnet-home" NUGET_PACKAGES="$PWD/.tools/nuget" \
  dotnet publish prototypes/security/resource_faults/ResourceProbe.csproj \
  --configuration Release --no-restore \
  --output /tmp/briani-resource-probe-secret-readonly-audited --nologo
# exit 0

DOCKER_CONFIG="$PWD/.tools/docker-config" \
  python3 prototypes/security/resource_faults/run.py \
  --probe-publish /tmp/briani-resource-probe-secret-readonly-audited \
  --skip-network --output docs/evidence/M10/resource-fault-secret-store.json
# exit 0; run ID 472c22e64eb540cdbf6c27d463a0f8c5; cold constructor and unchanged key hash

python3 -m unittest prototypes/security/resource_faults/test_run.py
# exit 0: 4 ownership, torrent-metainfo, and reconnect-bound checks passed
```

The run removed six exact owner-labelled containers with no cleanup errors. The matching run-label container query returned no resources, and the exact marker-owned scratch directory was absent. The unrelated network scenario was skipped in this focused run.
