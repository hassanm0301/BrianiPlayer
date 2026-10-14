# M10 continuation checkpoint

2026-10-13, ongoing work, not release certification. Parent owns shared source/contracts/locks/Compose/dev.py. Plan M00-M11 remains active; do not stop after an individual milestone. M11 tooling/docs can proceed while hardware runs.

## Executed corrections

- Relay owns detached sockets, frames truthful Content-Length/chunked responses, rejects request bodies/redirects, aborts each upstream on downstream cancellation. Six relay tests passed. Independent framing/truncation/HEAD/304/204/backpressure review passed. `docs/evidence/M10/security-review.md`, `/tmp/briani-m10-relay-tests2.log`, `/tmp/briani-m10-relay-backpressure-review.log`.
- Active download admission reserves `starting` under WriteGate, including tracking the polling row. Two real worker-loop schedules passed, same owner capped / different owner admitted. `/tmp/briani-m10-admission-race3.log`.
- Whole managed configuration application serialized before settings reads. Two real adapter instances / owned HTTP barrier test passed. `ManagedConfigurationConcurrencyTests.cs`, `/tmp/briani-m10-managed-config-concurrency2.log`.
- Pinned qBittorrent reads speeds at whole KiB/s; verification compares effective quantized limits. Fresh m10 operations drill passed complete backup/restore/rollback. `/tmp/briani-m10-operations-drill2.log`.
- Namespace nftables guard baseline actual daemon private fixture, loopback/IPv6-loopback/cloud denial and public HTTPS/Docker DNS pass. `tools/security/egress_probe.py`, `docs/evidence/M10/egress.json`. Each tracker/webseed/peer path still needs isolated individual counters, and controlled DNS-rebinding/redirect fixtures remain separate outstanding gates.
- Guard integrated into Compose, own NET_ADMIN only, no host rules/Docker socket. Exact locked local image. Four-service full operations drill passed all restore/rollback/credentials/grants/settings checks and cleaned. `/tmp/briani-m10-guard-operations-drill3.log`.

## Pi ownership / current work

Pi is production, user authorized key SSH `hassan@192.168.100.186`; every test file/container/image must be removed afterward. No production data/mount configuration/firewall/host packages are changed. Test root ONLY `/mnt/hassan-hdd1/.briani-codex-arm64-20261013-8b9de4`, owner.marker exact `briani-codex-arm64-20261013-8b9de4`; native source/work/fixtures/build data live there. Existing sudo -n docker works; user Docker permissions not changed. Root/bin/docker wrapper only inside test root.

Original production containers must remain running: filestash_wopi `5d2aebf4402e2a7ac9469dc30dadd31d52fd5eb03e6d4e17459b56b0fc648ef5`, filestash `806e28db2382c33f89ad54e39586bc97397b5fe229429d39c85cfaa2a42a691e`. Rechecked running after image load. No global prune.

Native SDK/FFmpeg build exited0 under one CPU; API rebuilt with current fixes. ARM64 image assembled on PC without emulation, exported and loaded on Pi. PC OCI image index ID dd8998ae228587e77d9c427e3afa1710572ae251f56796b41e6b763f882da2bb; Pi Docker load resolves config ID 77b7d05ee8325e6dd4d4b82725030438b8d0720d1e7c0431eaf8554bf6015327. Do not confuse index/config IDs. Native egress helper built legacy Docker with portable COPY, actual ARM64 image ID 5f02bde46266ba46b0bcef4efbb86f6841f5795d5e40aaf37c30dec88ed8be6e. Pinned nftables1.1.6-r1.

**Environment blocker:** Pi Docker cannot enforce memory limits; flags were discarded by kernel/daemon. Never claim configured 1GiB enforcement. Actual RSS collector and MemAvailable workload trip guard exist. User says cooling is tiny CPU heatsink (passive, no fan). HDD mount ext4/dev/sda2 has214GB available; SSD reference throughput cannot be assumed.

`prototypes/benchmarks/setup_pi5.py` parent new fixture setup is running remotely; log `/tmp/briani-m10-pi-setup.log`. It creates five-service owned Compose project briani-pi-8b9de4, source seeder,10000 indexed folder entries and private accounts/workload.json. Native generated source 5.8GiB MKV, completed29MiB MKV. Source transfer completed. Any startup failure requires diagnosis/clean exact owned resources or safe resume; do not reset production. Streaming workload has not run yet.

Local owned old probe helper `briani-egress-probe-8b9de4` and network `briani-egress-probe-net-8b9de4` still need cleanup after final guard tests (org.brianiplayer.fixture label, exact previously created IDs). Native stopped build containers `briani-codex-arm64-8b9de4`, `briani-codex-arm64-publish-8b9de4` remain; remove exact labels only at final cleanup. Native helper legacy intermediate layers/new pulled images need exact unused-image cleanup, never prune.

## Client / release work

M08 native emulator actual pixel/security passed earlier (EGL gpu-debug emulator only). Parent has fixed TV text field Up/Down actions and server page layout: no TV rail/FAB, header Add server, direct Card controls, first Connect autofocus. Actual-screen TV focus unit now passes. Worker desktop_e2e connected run a4465ad233064a4ca03c49bb0d1f2bab progressed real login/library/back and is still running; get terminal result. Emulator owned AVD Briani_Test_TV_API36, port5580, ANDROID_AVD_HOME project .tools/android-avd. Default sandbox ADB falsely cannot use socket; escalate scoped checks. Test predicate uses exact primary context ancestry/canonical action roots, not shared ancestor hasFocus. No physical TV until maximum local tests pass; user has TV at end. Windows/macOS absent.

Benchmark worker tools/benchmarks workload+collector and25 tests pass. Workload compares EVERY range to prehashed readonly independent oracle, refreshes eight separate owner tokens every8min, GET checks session/generation every30sec (no nonexistent renewal endpoint), allows exact ticket paths and restricted folder queries. Copy fresh scripts to Pi/PC before running. Config sources contain secrets, remain0600 and must not be printed. Client visible locale formatting still needs actual consumption; device reset now serialized but latest regression pending.

M11 worker package_audit.py+16 tests, user-guide.md/client-builds.md completed. No dist manifest yet. Android release debug signing removed; actual unsigned Release artifacts pending. Source has no Git metadata; record exact source-tree SHA, commitnull. Native builder v1.1.7 full source ref fe8c3ac1a91c09aa6fb1deccbc833f1bafa54768 from gitlsremote; corresponding-source/notices collection pending. All real artifacts/SBOM/provenance/checksums still required; no publication.

Remaining: Pi full30min load/throughput/native player, complete engine crash/resource matrix and parser/security gates, final client regressions/Android connected/physicaldevice, meaningful release verification/artifacts/docs, truthful reports/status. No partial final answer; continue independent work.

## Latest resumption / user steering (13 October 2026)

The user forbids further Pi tests and will run them themselves. All Pi work is stopped; ONLY prior cleanup was executed, reviewed and exited0. Eight owned containers, two networks, images and entire HDD test root were removed; protected production services remained running. No further SSH or Pi actions are needed or authorized. ARM64 image is retained locally in dist/images. Native runtime was blocked by kernel Landlock ENOSYS and absent memory enforcement; no performance pass is claimed.

Parent corrected ARM64 open flags and startup orphaned-work leases. Actual SIGKILL matrix passed three exact boundaries and strengthened durable removal state/SQL assertions: docs/evidence/M10/crash-matrix.json. 6000 deterministic parser/availability cases passed (3 tests). Extended egress7/7 passed and cleaned: egress-extended2.json. Root images.lock now current AMD95ab... and ARMf381... index digests, runtime config digests separate. Fresh production build log preserved server-image-build-final.log. Old /tmp logs vanished across interruption; preserve evidence in repository now.

Local Linux Release bundle built0; log presently client/docs/evidence/M11-linux-build.log pendingmove. Locale is wired, nullableAPIlogout guard+TvShellPage parentScope traversal landed. 85clienttests passed before newTVscope test; thatscopeunit passed separately. Androidworker diagnostic now nativeBack+Downloadstabfocusgreen; fullflow foundtestmatcher falsely accepts trailingPopup focus forrowtitle; fixingharnesssemanticnestedcontrol predicate. M11sourcecollector acquired25 exactversion/commit archives/notices76MB, allSHAverified; binarycorrespondence/licensing/publicgrant remain explicitlyblocked. LicenseSBOM worker active. Continue local implementation/tests/packaging; no partialfinalcheckpoint.
