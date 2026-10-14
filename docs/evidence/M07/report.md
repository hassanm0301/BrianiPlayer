# M07 desktop application handoff

The Linux desktop feature slice is implemented and its actual application/real-engine playback flow passes. Windows/macOS native builds and physical display/audio/Wayland verification are unavailable or outstanding; this is a blocked-verification milestone for the complete desktop platform gate, not a release certification.

The Flutter app supplies server profiles and strict transport, session/vault refresh and cancellation, sign-in/bootstrap, authorized libraries/folders/photos, Prowlarr discovery, magnet/torrent upload and consent/file selection, transfer controls, embedded media_kit playback and scoped external-player handoff. The native player disables config/scripts/secondary media loads with readback and uses a bounded capability relay. Progress/track/fullscreen/lifecycle behavior is integrated; M09 adds settings/account routes and preference consumption.

## Actual verification

Canonical connected run `33adf9920ffc436b804bd01a3bea27c2` under `docs/evidence/M07/artifacts/`: `prototypes/client/run_desktop_e2e.py`, exit0, three generated media cases. The app decoded H264 video before completion at torrent progress0.82833, native cache paused/resumed on the same stream when the engine paused/resumed, launched one owned mpv process and reaped it, completed and imported the download, then browsed its imported media through Libraries. A640x480 Xvfb screenshot visibly shows synthetic video and17,236 viewport colors. The API follow-on cases verify MKV early open/ranges/buffering and honest tail-metadata MP4 waiting. See desktop-e2e.md for exact artifact names/commands. Owned Docker containers/networks were removed.

Linux native security suite:3passed, `/tmp/briani-m07-native-review-OujZ03/result.log`; MP4/MKV actual decoding before held final bytes, scripts/playlist/HLS/redirect/folder capability denial, bounded configured cache. Relay suite4passed `/tmp/briani-m07-relay-tests3.log` at original scope. Review M10 subsequently identified per-range cancellation while upstream is idle as an outstanding finding; relay-wide close tests do not certify that behavior.

Whole client tests76passed `/tmp/briani-m09-final-client-tests.log` exit0 after account/settings/native graphics integration; analyzer0 `/tmp/briani-m09-client-final-analyze.log` before the final playback-mode change, whose analyze/regressions must be retained at M09 integration. Linux debug build0 `/tmp/briani-m07-linux-debug-build.log`; actual E2E subsequently builds current native code. Separate reviews: review-native.md, review-initial.md, dialog-lifetime.md. The server eligibility defect discovered by UI testing was fixed using verified contiguous prefix;3tests0 `/tmp/briani-m07-eligibility-tests.log`.

## Limits and next work

No Windows/macOS builds, physical audio/display, Wayland or full discovery-outage E2E pass is claimed. These missing gates remain explicit. Finish connected Android/TV flow, M09 real-image onboarding and preference gates, then M10 cancellation/admission/daemon-egress corrections and native Pi acceptance. Keep generated fixtures private/test-only. No registry or app publication occurred.
