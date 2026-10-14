# Native ARM64 evidence and user-deferred verification

On 13 October 2026 the user explicitly instructed: “Forget about testing on the raspberry pi. DO not do it. I will do it myself”. No further Pi tests, builds or benchmark attempts are authorized. Only cleanup of the previously isolated fixture remains, as previously requested.

The API and restricted FFmpeg 9.0.2 tools were compiled on the real ARM64 Pi with the locked SDK/runtime sources. The API was rebuilt after fixing ARM64 `O_DIRECTORY`/`O_NOFOLLOW` flags and startup orphaned-work leases. The corrected image config digest loaded on Pi was `sha256:b63a0824ec0ec611d98da1d809c3eeb4620d7f7354874a253359728c140f95e9`; the PC OCI index digest is recorded separately in images.lock.json. Native egress helper image was `sha256:5f02bde46266ba46b0bcef4efbb86f6841f5795d5e40aaf37c30dec88ed8be6e`.

Runtime and performance gates did not pass. Before the user deferred testing, native startup reached the filesystem mutation boundary and failed closed: `mutation_containment_unavailable`. Read-only native `landlock_create_ruleset(NULL,0,VERSION)` and ERRATA queries each returned -1/errno38 (ENOSYS). `/sys/kernel/security/lsm` reported only capability. Docker also reported no memory-limit enforcement. No kernel, boot, security or production-service configuration was changed. Kernel: 6.18.50+rpt-rpi-2712; passive tiny CPU heatsink supplied by user; fixtures used HDD/ext4 /mnt/hassan-hdd1, not an SSD benchmark reference.

No 30-minute workload or Pi throughput numbers are claimed. Temperature and memory observations during setup are not a performance certification. Existing filestash and filestash_wopi containers were confirmed running before cleanup. Cleanup completed with exit 0: eight owned containers, two fixture networks, test image references and the entire owned HDD directory were removed. No image removal was forced; both protected production containers remained running. See pi-cleanup.stdout.log and pi-cleanup.stderr.log.

The isolated path was /mnt/hassan-hdd1/.briani-codex-arm64-20261013-8b9de4 with its exact owner marker. The local ARM64 image artifact is retained under dist/images for the user’s later checks.
