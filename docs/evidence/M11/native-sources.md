# M11 native source/notices collection

## Result

The collector acquired 25 source/build metadata/license files totaling
76,087,297 bytes. The checksummed inventory is
[`dist/sources/manifest.json`](../../../dist/sources/manifest.json); files are
stored below `dist/sources/` and `dist/notices/`. Every collected file passed
the local size and SHA-256 comparison against that manifest. The manifest
identifies immutable source commit URLs where upstream provides Git commits.
Version tags were resolved through the upstream GitHub/GitLab APIs before
those commit URLs were used.

The Android builder is pinned to
`fe8c3ac1a91c09aa6fb1deccbc833f1bafa54768`; its `depinfo.sh` and license are
included. The builder declares default-flavor mpv
`78d43740f52db817d98bcf24fb30a76ab6fa13ff`, FFmpeg 6.0, libass 0.17.1,
HarfBuzz 7.2.0, FriBidi 1.0.12, FreeType 2-13-0, mbedTLS 3.4.0, dav1d 1.2.0,
and libxml2 2.10.3. The dependency source revisions, archive hashes, and
upstream notice text hashes are individually recorded in the manifest. The
builder script places vorbis/vpx/x264 under `ENCODERS_GPL`; these were not
included as dependencies of its default flavor.

The Android FFmpeg 6.0 release archive SHA-256 is
`57be87c22d9b49c112b6d24bc67d42508660e6b718b3db89c44e47e289137082`. FFmpeg's
release host did not expose a `.sha256` or `.sha256sum` sidecar at the checked
URLs; this is the digest of the retrieved versioned archive, not an
independently published checksum or signature verification. Its upstream
`LICENSE.md` and `COPYING.LGPLv2.1` texts are included, without inferring a
license expression for the Android binary.

For the server, the downloaded FFmpeg 9.0.2 archive matches the Dockerfile's
pinned SHA-256 exactly:
`8c3850283eb25fa026482078a04051e0be17347b09ef81a0849bec15a96e002e`. The
Dockerfile describes the signing-key check, LGPL-limited static configuration,
and installation of license files and `config.log`. The collector also
acquired the 9.0.2 upstream license texts. It did not inspect a final installed
server image, rebuild the image, or independently verify the detached
signature in this step.

These source pins and notice files do not prove which exact sources/options
produced the Android APK's observed `libmpv` members. Native build
correspondence and complete applicable Android notices therefore remain
release blockers. The Linux debug app resolves host mpv dynamically; its
clean-room runtime package requirement is a separate gate. Owner public-license
authorization remains absent. This work neither grants a license for Briani
Player nor authorizes publication.

## Collector guarantees

`tools/release/collect_sources.py` downloads only from allowlisted HTTPS hosts
and refuses redirects outside that allowlist. It retains source archives
without extraction; limits each transfer to 512 MiB and the full run to 2 GiB;
checks configured expected digests; hashes every result; writes through a
temporary file and atomic placement; rejects traversal/symlink paths; and
refuses to replace a different existing file. Incomplete collection returns
exit 3 and writes item-level evidence instead of treating missing inputs as a
pass.

## Commands and evidence

| Command | Exit | Result |
|---|---:|---|
| `python -m unittest tests.release.test_collect_sources -v` | 0 | Seven tests cover digest recording, digest mismatch, URL/redirect restrictions, path/symlink safety, per-file and total byte caps, and preservation of existing files. |
| `python -m py_compile tools/release/collect_sources.py tests/release/test_collect_sources.py` | 0 | Both Python modules compile. |
| `python -m pyflakes tools/release/collect_sources.py tests/release/test_collect_sources.py` | 0 | No findings. |
| `python tools/release/collect_sources.py --root .` with scoped network access | 3 | All 25 sources/notices collected; the intentional binary correspondence, image verification, and owner-authorization blockers remain. |
| Local manifest/file digest verification | 0 | All 25 files existed at their manifest paths and matched the recorded lengths and SHA-256 values. |

The tool exits 3 for a successful acquisition because the source inventory is
not a release clearance; the remaining blockers are included in its manifest.
