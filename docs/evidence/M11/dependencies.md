# M11 dependency license and source inventory

## Result

The inventory covers all 247 locked third-party identities from 14 lockfiles: 75 NuGet packages and 172 Dart packages. `dist/sbom.json` is CycloneDX 1.6 and contains 247 unique library components. Its purls match the lock-derived identities exactly (247 expected, 247 present, no extras or duplicates).

The result is **blocked**. This is collected evidence, not a license-compliance or release approval. The SBOM records `NOASSERTION` for 24 unresolved SPDX expressions: 15 Dart packages whose copied license text does not unambiguously match one full canonical license, 8 Dart packages without a unique license text, and NuGet `xunit.abstractions` 2.0.3.

## Collected license evidence

The inventory classifies 74 NuGet packages using SPDX expressions from version-specific official NuGet nuspec metadata. Those upstream nuspecs and locally cached nuspecs are copied under `dist/licenses/metadata/nuget/` with hashes. `xunit.abstractions` has no SPDX expression in its nuspec; its mutable license URL is recorded as metadata, not used as proof.

For the 172 Dart lock entries, available canonical license files are copied with source-relative paths and SHA-256 digests. The matcher maps complete canonical SPDX MIT text (26 packages), BSD-3-Clause text (118 packages), and Apache-2.0 text (5 packages) only. It ignores only replaceable copyright declarations, accepts the official matching-text variations, and requires the whole remaining file to match. Extra or concatenated license text remains unmapped. References: [SPDX MIT](https://spdx.org/licenses/MIT.html), [SPDX BSD-3-Clause](https://spdx.org/licenses/BSD-3-Clause.html), and the official full-text [Apache-2.0 reference](../../dist/licenses/reference/Apache-2.0.txt), whose downloaded 11,358-byte file SHA-256 is `cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30`. There are 239 package entries with license evidence and 175 with notice files. Missing evidence is explicit. `briani_api` is workspace code and is not assigned the project's own license.

NuGet `packages.lock.json` hashes are not raw archive SHA-512 values for signed packages. NuGet's [metadata specification](https://github.com/NuGet/Home/wiki/Nupkg-Metadata-File) defines `ContentHash` over package content excluding the signature file; the [NuGet package extractor](https://source.dot.net/NuGet.Packaging/PackageExtractor.cs.html) calls the package reader's `GetContentHash`. The collector runs the installed NuGet runtime via `dotnet nuget verify` and compares that normalized `Content hash` with the lock. All 75 of 75 match. Raw `.nupkg` SHA-512 values are recorded separately and match each cache sidecar.

## Collected source evidence

`dist/sources/packages/manifest.json` contains deterministic archives of all 172 locked Dart package trees, with per-tree and per-archive hashes, original lock archive hashes where available, package paths and explicit exclusions. For all 162 hosted packages, the exact `pub.dev` archive was fetched and its raw SHA-256 matched the lock; each archive was scanned without extraction, and every resolved cache file map matched that official archive. The local tree archives are deterministic resolved-source snapshots, while the retained raw official archives provide exact locked archive bytes. Ten SDK/workspace/path dependencies are archived from their resolved local trees and are not presented as publisher archives. Package resolution uses the exact locked version's cache path rather than a potentially different package-config root. The collector refuses symlinks, excludes build outputs (including Android `.cxx` generated fingerprints) and `.git`, and enforces per-package and aggregate size bounds. It retains one prior JNI archive that contained generated `.cxx` fingerprints and records the versioned current source archive separately.

`dist/sources/packages/nuget-repository-pins.json` records 70 immutable publisher-declared NuGet repository commits across 14 unique GitHub repository/commit pairs, each tied to a hashed version-specific official nuspec. Fourteen exact-commit GitHub codeload archives were fetched with HTTPS host allowlisting and SHA-256/size recorded; archives were scanned but never extracted. The largest was `dotnet/dotnet` at commit `95017c711e6afc1085133d440e42b4bd78155701`: 488,076,398 compressed bytes, 213,493 members, and 2,956,847,932 uncompressed file bytes. It passed 512 MiB compressed, 250,000 member, and 4 GiB uncompressed limits. The other 13 archives are also retained with hashes. The inventory maps 70 NuGet components to these publisher-declared commit archives; this does not prove the repository tree corresponds to the package binary or establish reproducible builds. Five NuGet packages lack an immutable commit in their official nuspec and remain source blockers: the four SQLitePCLRaw packages and `xunit.abstractions`.

## Reproduction and validation

Commands run from the repository root:

| Command | Exit | Result |
|---|---:|---|
| `python3 tools/release/license_inventory.py --root .` | 3 | Rebuilt 247-component CycloneDX SBOM and inventory; 223 expressions identified, 24 `NOASSERTION` entries retained. |
| `python3 tools/release/archive_package_sources.py --root .` | 3 | Archived 172 Dart trees, verified all 162 hosted archives against lock hashes, and archived 14 NuGet repository sources; 5 NuGet packages without immutable repository pins remain. |
| `python3 -m pytest -q tests/release/test_license_inventory.py tests/release/test_archive_package_sources.py` | 0 | 17 focused tests passed: strict MIT/BSD-3/Apache full-text checks, rejection of extra/multi-license text, NuGet lock hashes, deterministic archives, symlink/path/size safety, and exact commit archive validation. |
| `python3 -m py_compile tools/release/license_inventory.py tools/release/archive_package_sources.py tests/release/test_license_inventory.py tests/release/test_archive_package_sources.py` | 0 | Python syntax validation. |
| `python3 -m pyflakes tools/release/license_inventory.py tools/release/archive_package_sources.py tests/release/test_license_inventory.py tests/release/test_archive_package_sources.py` | 0 | Static checks passed. |
| `dotnet nuget verify <each cached .nupkg>` | 0 for all 75 | Runtime normalized content hash matched the lock for all packages; raw SHA-512 remains separately recorded. |

The separate [Android binary string inspection](android-native-strings.log) observes FFmpeg `n6.0`, `--disable-gpl`, `--disable-nonfree`, `--enable-version3`, and `mpv v0.36.0-549-g78d43740f5-dirty` in the release APK. The dirty mpv revision leaves exact binary-to-source correspondence unproved. The [server ffprobe inspection](server-ffprobe-version.log) observes FFmpeg/ffprobe `9.0.2`, static, with `--disable-gpl`, `--disable-version3`, `--disable-nonfree`, and its listed limited codec/demuxer configuration. Observed flags do not substitute for per-binary correspondence and complete notices. Neither evidence item assigns a wrapper package's license to its bundled native payload.

The full package audit/release gate was not run as a pass. The inventory remains blocked on unresolved SPDX evidence and source provenance, and this worker does not own the root manifest or release decision.
