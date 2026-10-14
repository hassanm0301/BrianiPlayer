# M11 packaging and native provenance evidence

Worker scope: `tools/release/`, `tests/release/`, and this report only. No artifact was signed, published, rebuilt, or represented as release-ready here. The repository snapshot has no `.git` metadata, so no source commit is available to record. The inventory tool records an exact source-tree SHA-256 instead; this is a private snapshot identity, not a Git commit or reproducible-build claim.

## Local native artifact scan

Command:

```bash
python tools/release/package_audit.py inventory --root . \
  --output dist/native-inventory.json \
  --artifact client/build/app/outputs/flutter-apk/app-debug.apk \
  --artifact client/build/linux/x64/debug/bundle/lib/libmedia_kit_libs_linux_plugin.so
```

Observed in the final bounded scan: 13 lockfiles and 247 unique resolved package identities; no Git commit; source-tree SHA-256 `deca28ea5ecf46cdc42b58b912483370018e2123b3cf06f0a6ab62178a7c3910`. The source-tree identity excludes generated Flutter `ephemeral` output (including plugin symlinks) along with build/cache output. The APK output changed during the parent’s concurrent client packaging work; the final scan was repeated after its size/hash stabilized. Artifact hashes below refer to that final observed local state, not inferred versions.

| Local artifact | Size | SHA-256 | Finding |
|---|---:|---|---|
| `client/build/app/outputs/flutter-apk/app-debug.apk` | 165,155,952 bytes | `0c5cf445854bb93133a5abf1430bbd8dc4b226a299b6d4b43863d6699cd83c40` | Debug APK, signed with Android Debug certificate SHA-256 `bb9501827dbabca30cb9b52cb6490f83278e4cb06ee1f80cd13d35a9080c9dd8`; not a release signing identity. |
| APK member `lib/arm64-v8a/libmpv.so` | 12,369,680 bytes | `adf83fde58a9f6751ce6e83b9b187f651425d53ec0e20da04deb8dfb4aa775e1` | ELF AArch64, Android API 21, NDK r25c. |
| APK member `lib/armeabi-v7a/libmpv.so` | 11,746,532 bytes | `8aa2b23d16d941a8d685b8eb995b1cb31677ed3e28c55c776954eb1618ab1a2e` | ELF ARMv7, Android API 21, NDK r25c. |
| APK member `lib/x86_64/libmpv.so` | 15,816,336 bytes | `f030e9a1a4d4664e89d7160a3d4528cd5875ee023ff6262e16e95aac28ffaec5` | ELF x86-64, Android API 21, NDK r25c. |
| `client/build/linux/x64/debug/bundle/lib/libmedia_kit_libs_linux_plugin.so` | 20,176 bytes | `1aa9bd045187296a2d7220aa8bc1b60bb6f934e80356f59b8a798406d3d642e2` | Debug Linux x64 plugin; dynamically resolves system `libmpv.so.2`, so this plugin file alone is not a self-contained app bundle. |
| Host runtime `/usr/lib/libmpv.so.2.5.0` | — | `79726a762f436d1fdf0869463df23e2ea11aaeeded9e878e71ed8855fbcb2d36` | Installed Arch package `mpv 1:0.41.0-6`; package database reports `GPL-2.0-or-later AND LGPL-2.1-or-later`. This describes the inspected host runtime, not a bundled Linux release artifact. |

The Android lock pins `media_kit_libs_android_video` 1.3.8 with pub archive SHA-256 `3f6274e5ab2de512c286a25c327288601ee445ed8ac319e0ef0b66148bd8f76c`. Its package LICENSE is MIT (local LICENSE SHA-256 `2e3000f38718f050869d57540c288c661a446f64df1ba4ea4764df552b04a331`). The plugin Gradle script downloads default ABI JARs from `https://github.com/media-kit/libmpv-android-video-build/releases/download/v1.1.7/`; local JAR MD5s match the four values in that script. Their SHA-256 values are:

| JAR | SHA-256 |
|---|---|
| `default-arm64-v8a.jar` | `4363dfa5d3d415b91c1f16f6fb90c3fe59a77dfd3f9b824d2b24b492d6b09df9` |
| `default-armeabi-v7a.jar` | `8ead114fc5a43348d89dc0eb8f41823e549b15115c29f73ee26973f973620995` |
| `default-x86.jar` | `94c13cb6188b774710e5e487afff6e500c4af504df74b2494d7b12cf9be8a66a` |
| `default-x86_64.jar` | `90268cd15f0766e07fb8e427388c621161177c9eb343c544f327bd63232bb236` |

The upstream builder tag is [`v1.1.7`](https://github.com/media-kit/libmpv-android-video-build/tree/v1.1.7). The release page exposes short commit `fe8c3ac`, not a full object ID in the retrieved evidence. Its [`depinfo.sh`](https://github.com/media-kit/libmpv-android-video-build/blob/v1.1.7/buildscripts/include/depinfo.sh) declares mpv commit `78d43740f52db817d98bcf24fb30a76ab6fa13ff`, FFmpeg 6.0, NDK 25.2.9519653 and other source dependency versions. The upstream [`LICENSE`](https://github.com/media-kit/libmpv-android-video-build/blob/v1.1.7/LICENSE) describes MIT for default/full builder flavor and GPLv3-or-later for `encoders-gpl`. Those facts do not by themselves establish the complete license set, build configuration, notices, or corresponding sources for every library inside the shipped `libmpv.so` files. No matching source archive SHA-256 was available from the local files, and the APK's generated `NOTICES.Z` contains no mpv or FFmpeg notice. These native provenance and corresponding-source items remain release blockers.

The Linux pub lock pins `media_kit_libs_linux` 1.2.1 with pub archive SHA-256 `2b473399a49ec94452c4d4ae51cfc0f6585074398d74216092bf3d54aac37ecf`; its package license is MIT. It is a plugin dependency, while this inspected debug app uses the host mpv package at runtime. A release bundle needs an explicit external runtime requirement or a separately inventoried bundled native runtime with its own license/source/notice records.

## Verifier contract and checks

`tools/release/package_audit.py inventory` writes a checksummed inventory draft and resolved identities from the repository's `packages.lock.json` and `pubspec.lock` files. It deliberately leaves licensing, signing, source matching, platform verification, and build provenance unasserted. Its source-tree SHA hashes sorted relative file paths and SHA-256 digests while excluding generated `build`, `dist`, `artifacts`, `ephemeral`, evidence outputs, tool caches, and Git metadata. Remaining symlinks in hashed source are rejected.

`verify --root ROOT --manifest dist/manifest.json` verifies recorded artifact and lock hashes, exact lockfile coverage, dependency coverage and license-expression consistency between the manifest and SBOM package URLs, SPDX license evidence/notice/corresponding-source file presence and digests, CycloneDX/SPDX JSON shape, per-artifact build/platform/signing evidence, source identity, provenance subjects, and APK native-member hashes/ELF ABIs. Provenance source identity must match the manifest when stated; native source origins must use HTTPS and source revisions cannot be placeholders. All manifest paths are root-relative; traversal and symlink paths fail closed. Exit 0 means the declared gates are evidenced; exit 3 means the candidate is blocked by missing evidence or unsigned state; exit 2 means malformed, unsafe, or tampered inputs. The tool checks evidence presence and consistency; it does not make a legal determination or independently prove that a license expression was selected correctly.

| Command | Exit | Result |
|---|---:|---|
| `python -m py_compile tools/release/package_audit.py tests/release/test_package_audit.py` | 0 | Both modules compile. |
| `python -m unittest discover -s tests/release -v` | 0 | Sixteen tests cover successful signed fixture verification, unsigned/missing-notice blocked state, source-tree identity without inventing a commit, lock/SBOM omissions, SBOM license mismatch, APK ABI mismatch, checksum tampering, path traversal, symlink files and directories, provenance source-tree mismatch, missing manifest, inventory, platform/source/license omissions, evidence-output exclusion, and blocked exit 3. |
| `python -m pyflakes tools/release/package_audit.py tests/release/test_package_audit.py` | 0 | No static lint findings. |
| `python tools/release/package_audit.py inventory --root . --output /tmp/briani-m11-native-inventory-final6.json --artifact client/build/app/outputs/flutter-apk/app-debug.apk --artifact client/build/linux/x64/debug/bundle/lib/libmedia_kit_libs_linux_plugin.so` | 0 | Inventory-only draft recorded 2 artifact hashes, 13 lockfiles and 247 package identities; source commit absent, source-tree SHA recorded; no licensing/signing/release claims. |
| `python tools/release/package_audit.py verify --root . --manifest dist/manifest.json` | 3 | No candidate manifest exists; correctly returned explicit `blocked` (`manifest file missing`). |

Release packaging remains blocked: no owner public-license grant, no Git metadata/source commit, no release-signed APK, no complete native source/notices package, no source archive hash, no complete SBOM/provenance manifest, and no final platform evidence. Windows/macOS builds and real-device/platform tests were not attempted in this worker scope. No reproducible rebuild or public release is claimed.
