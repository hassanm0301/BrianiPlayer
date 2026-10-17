# Briani Player

Browse and play media from your own server on Linux, Android phones/tablets, and Android TV. Briani supports folder libraries, photos, torrent search through Prowlarr, and playback while qBittorrent downloads a video.

## Get started

1. [Set up the Docker server](docs/operations/README.md).
2. [Install the app](docs/client-installation.md).
3. [Set up torrent search](docs/operations/indexers.md) (optional).
4. [Browse, download, and watch](docs/user-guide.md).

The server runs on 64-bit Linux amd64 or ARM64, including a Pi 5 with a compatible host. Video decoding happens on your client device; the server does not transcode. There is no browser or iOS app.

This checkout contains private test packages. Windows/macOS clients are source-only here, and some platform checks remain pending. See [available clients](docs/client-installation.md) and the [support matrix](docs/compatibility/support-matrix.md).

## More information

- [Server maintenance and troubleshooting](docs/operations/advanced.md)
- [Known limitations](docs/release-notes.md)
- [Development setup](docs/development/foundation.md) and [client builds](docs/development/client-builds.md)

Implementation plans are under `plan/`; verification records are under `docs/evidence/`.
