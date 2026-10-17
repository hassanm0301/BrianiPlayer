# Client download page — 17 October 2026

Status: **deployed to the Pi** at `http://192.168.100.186:8089` (LAN only). It serves the v1.2.0 packages from its own mirror. The setup is described in [operations/downloads.md](../operations/downloads.md).

## Checks before deployment

| Check | Result / exit |
|---|---|
| `python3 -W error::ResourceWarning -m unittest discover -s tests/downloads` | 12 passed / 0 |
| `python3 -m unittest discover -s tests/operations` | 32 passed / 0 |
| QR codes for versions 1–6 decoded with `zbarimg` after rendering with `rsvg-convert` | All matched |
| Local amd64 container against real GitHub | Mirrored both packages; served SHA-256 matched GitHub's digests; non-root (uid 10001), read-only root; `healthy`; stop took 0.2 s, exit 0 |
| Relay before mirroring (local) | `Range: bytes=0-99` gave 206 with the APK's first 100 bytes; the full Linux bundle matched its digest |
| Page in a browser at desktop width, 375 px (light scheme) and dark scheme | No horizontal scroll and no console or CSP errors; copy button works; device badge correct |

The first Pi build showed that `COPY` keeps the host's file modes. The Pi's umask produced 0640 files that the unprivileged user could not read. Fixed in `dd1ce68` by a `chmod` in the image; rebuilt locally from 0640 sources and confirmed readable as uid 10001.

## Pi deployment

The `hassan` account copied `infra/downloads/` to `/home/hassan/briani/downloads` and wrote `.env` (0600) with `DOWNLOADS_BIND=192.168.100.186` and `DOWNLOADS_SERVER_URL=http://192.168.100.186:8088`. File hashes matched the commit. The `claude` account ran the Docker steps with sudo:

```sh
sudo docker compose --project-directory /home/hassan/briani/downloads up -d --build
```

| Step | Result |
|---|---|
| Build on the Pi (arm64) and start | Project `briani-downloads`, volume `briani-downloads_cache`, port `192.168.100.186:8089` |
| Mirror | APK (238,810,925 bytes) in 26 s, Linux bundle (11,694,591 bytes) in 1 s, both checked against GitHub's SHA-256 |
| `/tv`, `/android`, `/linux` downloaded from this workstation over the LAN | 200; names `briani-player-1.2.0-android-tv.apk`, `-android.apk`, `-linux-x64.tar.gz`; SHA-256 `541c86f8…08db9` (APK), `691d3db8…54b9156` (bundle), equal to the release digests; about 85 MB/s |
| `Range: bytes=0-99` on `/android` | 206 |
| Live page QR code | Decodes to `http://192.168.100.186:8089/android` |
| Container | `healthy`, restart policy `unless-stopped` |
| Briani stack | Untouched: `briani`, `qbittorrent`, `prowlarr` and the guard kept running; `/readyz` 200 |

## Logo update (same day, 14:44 +04)

After `025dfb1`, only `page.html` differed from the Pi's copy; the Pi's old copy matched `20d01ad`. As `hassan`, the new `page.html` was copied over (SHA-256 `1affe02e…2895624`, equal to the commit). As `claude`:

```sh
sudo docker compose --project-directory /home/hassan/briani/downloads up -d --build
```

| Check | Result |
|---|---|
| Container | Recreated, `healthy`, 0 restarts, uid 10001, read-only root; `/app/page.html` hash equals the commit |
| Live page | 200; header mark and favicon are the new logo; no console or CSP errors |
| Mirror | Cache volume kept; `/healthz` reports all three packages mirrored at v1.2.0, no error; `/android` still 200 with 238,810,925 bytes |
| Briani stack | Untouched; `/readyz` 200 |

## Limitations

- Android TV and phone get the same debug-signed local-test APK, the only installable APK in the releases. Installing on a physical phone or TV from this page was not tested.
- Whether a TV browser or downloader app accepts the plain-HTTP LAN download was not tested.
- Until a new release is mirrored, its downloads are relayed from GitHub and are not checked by this service.

Rollback or removal: `sudo docker compose --project-directory /home/hassan/briani/downloads down --volumes`.
