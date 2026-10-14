# M07 Linux desktop connected E2E

## Runner and safety

`prototypes/client/run_desktop_e2e.py` provisions a per-run, M07-labeled internal Docker network, the locked qBittorrent image, the Briani API image, generated synthetic media, and ephemeral accounts. Containers have no published ports. The host Flutter app uses a specific unused address from the private network, with an exact allowed-host entry. Credentials are passed only in a mode-0600 handoff file, never argv or logs, and removed in `finally`; owned containers, the network, protected handoff, temporary server/downloader data, and generated private fixture payloads are cleaned up. The runner also tracks and terminates only mpv processes spawned during the UI test.

`client/integration_test/desktop_e2e_test.dart` uses the actual Linux Flutter app, generated API client, HTTP server, and production `MediaKitPlaybackAdapter`. Only native audio output is disabled for this headless Xvfb run. The real UI creates/connects a server profile, signs in, opens Libraries/Discover/Downloads, submits selection consent for the generated MP4, and starts embedded playback. A file-marker handshake pauses/resumes the actual torrent through authenticated API operations while the same native player is running. ImageMagick captures the real Xvfb desktop; the runner checks a video viewport crop for substantial color detail.

## Canonical connected desktop run

Command: `python3 prototypes/client/run_desktop_e2e.py --artifacts docs/evidence/M07/artifacts` (Docker/Flutter executed with authorized escalation). The runner's Linux case was `xvfb-run -a flutter test integration_test/desktop_e2e_test.dart -d linux`, exit 0.

Full pass: [run 33adf9920ffc436b804bd01a3bea27c2](artifacts/33adf9920ffc436b804bd01a3bea27c2/result.json), 3 media cases. The UI selected and started the 21,065,227-byte synthetic faststart MP4 through the real consent flow. Native libmpv decoded its first frame while incomplete at torrent progress `0.82833`. The actual UI player was starved by pausing the torrent through authenticated API operations: it reported a stable cache pause, then resumed advancing on the same stream when the torrent resumed. The UI handed the stream to mpv, then navigated back through Libraries → Downloads → the imported job folder → nested torrent root and found the completed imported media item.

The actual Xvfb desktop capture is [ui-native-render.png](artifacts/33adf9920ffc436b804bd01a3bea27c2/ui-native-render.png), 640×480. The runner measured 17,236 unique colors in its video viewport crop, consistent with the visible synthetic color-bar video. It observed and reaped one mpv process spawned by the UI handoff. The other cases verified early incomplete MKV decode, native cache pause/resume, missing-piece range wait/recovery, unchanged piece priorities and the HTTP range matrix; tail-metadata MP4 waited until completion before first frame.

The record reports API image `sha256:4f5bf75b0e778852fc92ede2326c79adb8c4a01bd32244b635f2d271991346bb`, qBittorrent 5.2.4, an internal network, no external tracker/peer, and no published ports. Flutter analyzer reported no issues for the integration test, and `python3 -m py_compile prototypes/client/run_desktop_e2e.py` passed. A post-run Docker label check found no remaining M07 containers or networks.

## Limits

The test opens the library's empty root before starting the download. Discovery outage/back-responsiveness has not been demonstrated. Physical display and audio-device behavior are not certified; this run used Xvfb and disabled native audio output. No real indexer, public swarm, external tracker/peer, or production data was used. Older failed attempts remain in the artifact directory and are not represented as passing evidence.
