# Client download page

An optional one-page site that offers the newest Briani Player apps for direct download: the Android TV APK, the Android phone/tablet APK and the Linux x64 bundle. Each button downloads the file from your server; nobody is sent to GitHub.

It runs as its own small Compose project, separate from the Briani server stack, so starting or removing it never touches Briani, qBittorrent or Prowlarr.

## How it works

- Every 15 minutes, and at most every 2 minutes while people are visiting, it asks the GitHub API for the project's releases. It picks the newest non-draft release that ships each package. Pre-releases count, since every Briani release so far is one.
- It then mirrors those packages into a Docker volume. A copy is kept only when its size and SHA-256 match the digest GitHub publishes for the release. Older copies are deleted once a newer release is mirrored.
- Until a new package is mirrored, its download is relayed from GitHub through the server, so the link still downloads in place. Relayed bytes are not checked by this service; the mirrored copy that replaces them is.
- Downloads support byte ranges, so interrupted downloads can resume.

| Address | Downloads |
|---|---|
| `/` | The page |
| `/tv` | `briani-player-local-test.apk`, saved as `briani-player-<version>-android-tv.apk` |
| `/android` | The same APK, saved as `briani-player-<version>-android.apk` |
| `/linux` | `briani-player-linux-x64.tar.gz`, saved as `briani-player-<version>-linux-x64.tar.gz` |
| `/healthz` | JSON status: last check, last error, and whether each package is mirrored |

The TV and phone links serve the same universal APK, the debug-signed local-test build. The release's `briani-player-unsigned.apk` cannot be installed, so it is not offered. The short `/tv` address is meant to be typed on a TV, in its browser or a downloader app.

## Run it

You need Docker with the Compose plugin and internet access for the first build. Copy `infra/downloads/` to the server, then create a `.env` file next to its `compose.yaml`:

```sh
DOWNLOADS_BIND=192.168.1.50
DOWNLOADS_SERVER_URL=http://192.168.1.50:8088
```

Start it from that folder:

```bash
docker compose up -d --build
```

Then open `http://192.168.1.50:8089` on any device on your network.

| Setting | Default | Meaning |
|---|---|---|
| `DOWNLOADS_BIND` | `127.0.0.1` | Host address to listen on. Use your LAN IP to reach it from other devices. |
| `DOWNLOADS_PORT` | `8089` | Host port. |
| `DOWNLOADS_SERVER_URL` | empty | Briani server address shown on the page for people to enter in the app. Hidden when empty. |
| `DOWNLOADS_REPO` | `hassanm0301/BrianiPlayer` | GitHub repository whose releases are offered. |
| `DOWNLOADS_INTERVAL` | `900` | Seconds between release checks (at least 60). |
| `DOWNLOADS_PRERELEASES` | `1` | Set to `0` to offer only full releases. |
| `DOWNLOADS_TV_ASSET`, `DOWNLOADS_ANDROID_ASSET`, `DOWNLOADS_LINUX_ASSET` | see the table above | Release file name to offer for each button. |

The last group is read inside the container; add it under `environment:` in `compose.yaml` if a future release renames its files.

The cache needs about 250 MB for one release. The container runs as an unprivileged user on a read-only filesystem with no Linux capabilities. GitHub allows 60 unauthenticated API requests per hour per address; unchanged release lists are fetched with an ETag, and the checks above stay well under that limit.

## Update or remove it

After pulling a newer copy of `infra/downloads/`, run `docker compose up -d --build` again. To remove it with its cache, run `docker compose down --volumes` in the same folder.
