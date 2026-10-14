# M11 independent candidate packaging review

2026-10-13. Read-only script/inventory review; reviewer writes only this report. No tests, builds, archive creation/extraction, Docker, Pi/SSH, production access, hardware execution, or publication occurred. Root owns all corrections and integration. Initial candidate-inputs and final manifest were absent when this pass began. The corrected source and first assembled manifest were subsequently inspected as recorded below.

**Current result: no open P1/P2 implementation finding was identified after the scoped corrections.** The candidate remains blocked for release certification. Final source/archive regeneration after ongoing documentation/test changes, and the parent's final package proof, remain required; this review does not invent their result.

## Findings before assembly

**P1: generated harness credentials/payloads enter the source archive.** `package_audit.py:23–24,44–64` and `build_candidate.py:62–78,327–328` use the shared directory exclusion set. That set does not exclude `prototypes/playback/harness/state/`, which currently contains `credentials.json`, `seeder-credentials.json` (username/password keys), endpoint/runtime reports, torrent payload copies and a `.parts` file. These files will be included as source unless this generated root is excluded by both source-identity hashing and archive enumeration. Only filenames, sizes, and key names were inspected; no credential values were printed. Use a precise generated-path exclusion, not a blanket removal of legitimate source directories called `state`.

**P1: bundle output destinations are not bounded and ancestor symlinks are unchecked.** `build_candidate.py:24–26` defines `OUTPUTS`, but `assemble:339–346` passes arbitrary relative descriptor paths to the writers. A new path such as `server/generated.tar.gz` is created outside `dist`; `_install_generated:174–188` checks for a `dist` ancestor only when replacing a differing existing file. `_temp_sibling:150–155` creates parent directories before checking only the direct parent/final symlink, so an earlier ancestor symlink can redirect writes outside the root. Restrict each generated bundle kind to its exact allowed output and check every ancestor before mkdir/temp creation. Validate Linux source-directory ancestors too. This source schedule was not executed.

**P2: changed reruns leave a stale checksum list.** `assemble:461–464` excludes `dist/SHA256SUMS` from its own checksum records, while `_write_generated:475–479` demands `_previously_owned` for a differing existing file. A changed rerun can replace owned source/archive/manifest files, then fail to replace SHA256SUMS because it has no self-record. The identical-rerun test does not exercise this schedule. Establish prior checksum-list ownership before changing outputs, then allow the checked list to be replaced; do not simply permit arbitrary overwrite.

**P2: source identity omits executable modes.** `package_audit.py:59–63` hashes names/content only, while `_add_tar_file:83–85` maps executable files to 0755 and others to 0644. A chmod that changes executable status changes archive/runtime semantics without changing `sourceTreeSha256`. Use the same normalized mode in source identity and archive metadata. Both hash/archive enumeration must also share exclusion/ordering rules.

**P1: assembler native correspondence blockers can disappear in verification.** `build_candidate.py:424–426` records a blocker when a native component's `sourceCorrespondenceStatus` is not `verified_binary_source`. `package_audit.verify_manifest:281` starts a fresh blocker list and does not preserve the manifest's blockers; its native checks at `472–479` require URL/revision and component evidence, but do not require verified binary/source correspondence. Consequently a signed/runtime-passed native artifact mapped to a wrapper package source archive can pass those checks even though assembly explicitly classified native correspondence as unresolved. Preserve the explicit manifest blockers or independently validate the native correspondence state. The auditor inventories APK native members/direct ELF files; it does not discover native members inside desktop tarballs or OCI archives, so current archive descriptors must explicitly retain their native-provenance limitations rather than treat an empty native list as complete.

All findings were sent to the parent before any fix. These are concrete source-path/schedule observations, not executed reproductions. No release clearance is given by this initial pass.

## Inventory and claim boundaries

Inspected the current 247-component license inventory, 172-package source inventory, relevant media wrapper entries, script source, and packaging test source. Wrapper entries such as `media_kit_libs_android_video` carry their own MIT package-license evidence and explicitly describe official pub archive hashes as package snapshots, not native binary/source correspondence. They do not establish libmpv/FFmpeg licensing. The inventory currently has 24 explicit license blockers and five source blockers; the builder/auditor preserve blocked states, absent owner licensing, signing, and platform evidence. Final artifact mappings still need inspection to ensure native binaries are separately represented and unsupported container/tar member provenance stays blocked.

Existing deterministic archive logic sorts names and fixes gzip/tar timestamps, owners, and normalized modes; unexpected existing differing files require recorded prior checksums. Source identity is observed with no fabricated Git commit. Private code-complete candidate packaging with blocked release certification is the appropriate claim; missing native hardware and public licensing/signing are not passes.

Targeted successful reads exited 0. Some initial guessed filenames were absent; no test exit code is claimed. Awaiting parent corrections and final candidate manifest for a focused follow-up.

## Correction review, before final manifest

Reinspected the parent's/worker's corrections. The reported source schedules are closed in the current source: exact harness-state exclusion is shared, executable mode participates in identity, source archive enumeration follows the same sorted walk order, generated Linux/operations destinations are allowlisted, and all source/output ancestors are checked before creation. Prior checksum-list ownership is evaluated before output changes; changed owned reruns may then refresh the list. The auditor preserves explicit manifest blockers and independently requires verified native binary/source correspondence. Source-level negative tests now cover these boundaries; their execution remains the parent's evidence.

Candidate inputs now exist and distinguish unsigned release APK, debug-signed emulator test APK, native-runtime-deferred ARM images, and separate unverified native APK members. `libmpv.so` maps to ecosystem `native`, with its observed dirty version/commit and `unverified_binary_source`, rather than a MIT Flutter wrapper. OCI/native archive inventory scope still needs explicit blockers.

One additional integrity gap was reported: the project's source archive lives in `provenance.sourceArchive`, but the inspected auditor does not yet validate that reference/hash or its content agreement with the source identity. SHA256SUMS is not read by that verifier either. If the source tar is absent from artifact descriptors, source-tar tampering alone is not detected. The parent was asked to validate the provenance source archive and safe canonical content identity. No final-artifact conclusion is issued while this remains pending.

## Source archive correction and assembled-draft inspection

The source-archive gap is closed in the corrected `package_audit.py:92–136,461–464`. The auditor validates the provenance archive hash, then compares the exact regular-file member set/content and normalized 0755/0644 modes against current source without extracting files. It rejects unsafe/nonregular/unexpected/duplicate members and imposes compressed-size, expanded-size, and member-count bounds. Both source identity and archive construction use the shared exact exclusions for generated harness state and generated playback fixtures. Archive ordering remains the same deterministic sorted walk used by identity hashing; gzip/tar metadata stays normalized. No checker execution was performed by this reviewer.

Inspected actual `dist/candidate-inputs.json`, `dist/manifest.json`, `dist/provenance.json` and the saved `docs/evidence/M11/package-audit-final.json` after first assembly. Manifest/provenance source commit is null, their source-tree hashes agree, and provenance subjects exactly cover the seven artifact paths/hashes. The draft has 247 component records and 162 assembly blockers; the saved audit reports `blocked`, 472 blockers, and seven inventory entries. The parent reports the audit command exited 3 as designed. No full artifact hash rescan was run by this reviewer, per the assigned scope.

The seven artifacts cover amd64 API/guard archive, ARM API archive, ARM guard archive, unsigned optimized APK, debug-signed test APK, Linux bundle, and operations bundle. Android native entries are explicitly unverified; actual ABI/member hashes are recorded and the libmpv dirty version maps to native provenance rather than the wrapper's MIT license. Optimized Android playback, Linux release playback, full native OS/base-image/Android transitive inventory, owner license grant, signing, Windows/macOS, physical Android, ARM runtime/performance, and unassisted reconnect reliability retain explicit limitations. The package/native inventory and source archives do not prove whole-binary corresponding-source compliance. No coverage target, hardware check, or platform certification is asserted by this review.

The reviewed source regressions now include wrong destination, symlink ancestors, generated-state exclusion, executable-mode identity, changed owned rerun checksums, retained manifest blockers, unverified wrapper/native mapping, and unsafe/mismatched project archive members. The saved `source-identity-regression.log` inspected here shows 19 passes from the preceding audit revision; the parent reports 20 audit tests after the archive check and 11 assembler tests. Those latter results are parent-reported until their final logs are recorded; they were not rerun by the reviewer.

At this draft inspection, SHA256 values were:

```text
tools/release/build_candidate.py 82d2fc74ce2cd06058afbb547397adb17c2c20c044529715ca53242231a00d0a
tools/release/package_audit.py   7bb50546c9f47837bb2d534f19f43feec726b4a4160c23dbec06f861b1abf0e2
dist/candidate-inputs.json       0a3f340d2bf67c1a6a02b8674c80d90aa8d95ae5245bceb4ff83372b4ca3b074
dist/manifest.json               5619022c03b494aae2229e2f0280374e545dde6d5b3558af62b5ffe7e3813897
dist/provenance.json             f55c6167d996f3c4553900c20d439643491586dbd8de88b2e02dad5deeefeb6b
```

Later regeneration will change the manifest/archive snapshot as expected. The parent must retain final assembly/checksum/audit results for that snapshot. Private candidate delivery with blocked certification remains truthful; public release clearance is not issued.

## Final immutable artifact consistency pass

2026-10-13. The parent froze the final artifacts/evidence after the manager and quota corrections. This pass performed only file reads, SHA256 calculations, archive member reads without extraction, and source-identity hashing. It ran no test, build, Docker, Pi/SSH, physical hardware, deployment, or publication operation. Only this review was appended.

**Result: no concrete final artifact/evidence mismatch or open P1/P2 packaging finding was identified.** All seven actual artifact hashes and sizes match the final manifest, and provenance subjects cover exactly those seven paths/hashes. Every referenced artifact build/verification/signing evidence file hashes correctly, as do SBOM, provenance, candidate inputs, retained source archive, and lockfile references. The final source-tree identity recomputed from the current source is `90db9a029ed04265efe382fab2215d2158250a6ca37b154cde4852b270b5e94c`, matching manifest and provenance. The three reviewed manager-control production hashes still match `manager-control-review.md`.

The retained project source archive has 759 members and excludes generated harness state and generated playback fixtures. Its image/toolchain locks equal the current root files. The staged operations image/toolchain locks, operations scripts, and Compose files equal the root copies; the operations tar preserves the `briani-operations/dist/operations/` staging prefix and its locks also match. An initial inspection-only script assumed locks directly under `briani-operations/` and returned a missing-member error; the actual prefix was then inspected successfully. This was a review-path assumption, not a candidate defect. No extracted files were created.

Final manifest contains 247 package components and **164 explicit assembly blockers**. The completed saved package audit has **`status:blocked`, 474 certification blockers, and seven inventory entries**; release verification records task exit **3**, preserving blocked milestone/release states. The checksum file contains 843 records, and the parent's frozen checksum run records every entry `OK` with exit 0. This reviewer independently hashed the seven main artifacts and their manifest references; the complete 843-file rescan is the parent's run. No exit-2 malformed/tampered result is relabeled as a blocked candidate.

The frozen packaged-operations log ends in `DRILL_RESULT=PASS` and cleanup. The final `download-restore-manager-final-pass.json` says passed, preserves the request/idempotency/grant/key, and explicitly uses **configuration restore over retained media**, not copied-media recovery. It records a genuine partial 786,432-byte transfer, observed checking/completion after recheck, and resumed exact 8,388,608-byte output matching its independent source hash. Post-cleanup evidence lists empty exact Compose resources, the removed fixture container/network IDs, removed marked scratch root, and `verified:true`. The cold/build evidence files are retained with matching hashes. Earlier resource fault JSONs reference the preceding `95ab…` image and remain historical proofs; this pass does not recertify the final image from those older records.

Actual connected desktop result `4115614232624b71ab58a9ac1f082448` and TV result `020dfef6666f4771a7af36618fe7acc9` both say passed against final amd64 API image `sha256:1df27e12987bc5e3881d56e964d64a57de9837a13aef7eed8182921ba44f2ac8`; the TV result records Flutter exit 0. The final server log's ten suites total 412 passed, zero failed/skipped. Saved Python evidence reports 134 passed plus 21 subtests; release tooling reports 55 passed; client analyzer reports no issues. Parent reports 86 Flutter tests. These are inspections/attributions of the owner's runs, not new reviewer executions.

Optimized Android playback remains unverified; debug/emulator evidence is identified as such. Linux release startup is distinguished from connected test-variant playback. Native libmpv/FFmpeg/OS and Android transitive source correspondence, below-target handler branch coverage, physical Android/TV, Windows/macOS, ARM runtime/performance, signing/public licensing, and unassisted reconnect limitations remain explicit. ARM packaging retains COPY-only portable IL/native-base assembly claims and does not claim new ARM execution. Private code-complete candidate delivery with blocked release certification remains the supported conclusion.

Final snapshot hashes:

```text
dist/manifest.json          2feff37e64b44e9d9141c58979dce794f5b62448c718f1c50cc60020d3110045
dist/provenance.json        ce1be2387fa5c57d49747d93b1f02e8a4c27db0d72362feae08b973c069bd22c
dist/candidate-inputs.json  ff52324ef37628a1563e41ee3832a221dbc057b7ca520a27988d6ba6cc4ddb79
package-audit-final.json    a86202541a0baa93925ae0253e593871480b2bb235839ee48e9a6a983995b15e
```

No cosmetic changes are requested and no further implementation review is implied. A later artifact/source edit would require regenerating the affected identities and rerunning the relevant owner's checks.
