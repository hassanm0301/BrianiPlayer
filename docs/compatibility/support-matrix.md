# Candidate verification matrix

| Target | Build/package | Local verification | Remaining verification |
|---|---|---|---|
| Linux amd64 server | Docker archive available | Four-service install, persistence, backup/restore/rollback, byte oracle, real-engine playback and fault checks passed | Native OS/base package provenance completeness; spontaneous engine reconnect reliability |
| Linux ARM64 server | Docker archive available; final API portable IL overlay over native runtime/FFmpeg | Package assembly and ARM ELF/package identities checked locally | Native execution, kernel capability, memory and workload measurements reserved to owner |
| Linux x64 client | Optimized bundle and archive | Fresh packaged startup without SDK; connected test-variant video and external mpv passed under Xvfb | Optimized playback, physical audio/display, Wayland and distro dependency compatibility |
| Android mobile/TV | Unsigned optimized APK; ordinary debug-signed local-test APK | Ordinary APK installation/startup; API36 x64 TV emulator D-pad, grant-limited pairing, early rendered playback and buffering passed in integration variant | Optimized native APK and physical phone/TV tests reserved to owner; release signing |
| Windows client | Source and build workflow available | No native runner | Native build/package, playback, external handlers and signing |
| macOS client | Source and build workflow available | No native runner | Native build/package, playback, external handlers, signing/notarization |

The server targets Linux distributions on amd64 and ARM64 through Docker Compose, with no native installer. Distribution independence does not bypass the required kernel Landlock ABI/syscalls or Docker memory-limit enforcement. The operations preflight checks these capabilities and fails on an unsupported host without changing the kernel, host firewall or permissions. Owner Pi setup previously lacked the required kernel/memory enforcement; that environment was cleaned and all further testing was prohibited by the owner.

Playback uses client mpv/native decoders and available torrent bytes. The server does no video transcoding or remuxing. Generated H.264 MP4/MKV evidence is not a promise of arbitrary codec, HDR, Dolby Vision, audio passthrough, damaged-container or external-player compatibility. Sparse/missing bytes cause honest buffering; seeking does not reprioritize pieces. Missing or stalled peers cannot be treated as successful playback.

The candidate is private and unsigned except for the clearly labeled Android Debug certificate. No public licensing grant, store identity or distribution approval has been assigned. The complete evidence and known limitations are in `../evidence/M11/report.md` and `../../plan/evidence/status.json`.
