# Advanced server setup and maintenance

Start with the [short setup guide](README.md). This reference covers detailed requirements, private Prowlarr administration, backups, recovery, upgrades, and troubleshooting. The server runs on **64-bit Linux amd64 or ARM64 using Docker Compose**. A Pi 5 needs a 64-bit operating system. Windows and macOS are client platforms; this guide does not provide a native server installer for them.

The files currently supplied are a **private test candidate**. Use the matching files you were given, rather than substituting a guessed public image or a `latest` tag. ARM64 images exist, but Pi runtime and performance checks remain pending. See the [support matrix](../compatibility/support-matrix.md).

## 1. Prepare the host

You need:

- Docker Engine and the Docker Compose plugin, working for the non-root Linux account that will manage Briani.
- Python 3.10 or newer for the supplied operations tool. The tool uses Python's standard library; you do not need .NET or Flutter on the server.
- A Linux amd64/ARM64 kernel supporting `openat2` with `RESOLVE_BENEATH` and `RESOLVE_NO_SYMLINKS`, and Docker memory-limit enforcement. The `doctor` check probes both and stops if either is missing. The path probe opens the existing deployment directory read-only; it creates or changes no host files and does not alter kernel or boot settings.
- Already mounted, local storage for application state and media. SSD/NVMe storage is preferable for databases and downloads. Keep the database off SMB/NFS.
- At least 5 GiB free on the state and media filesystems to pass the initial check, plus space for your actual collection and downloads.
- A stable server address that your client devices can reach. A DHCP reservation on your existing network can keep that address consistent.

Install Docker using [Docker's instructions for your Linux distribution](https://docs.docker.com/engine/install/) and its [Compose plugin instructions](https://docs.docker.com/compose/install/linux/). For **64-bit Raspberry Pi OS**, Docker directs you to its [Debian instructions](https://docs.docker.com/engine/install/debian/); its separate [Raspberry Pi OS page](https://docs.docker.com/engine/install/raspberry-pi-os/) covers 32-bit installations, which Briani does not target.

Check the tools in a terminal on your server:

```bash
uname -m
python3 --version
docker version
docker compose version
id
```

The architecture should be `x86_64` (amd64) or `aarch64` (ARM64). `docker version` must show a working server connection. Complete your distribution's Docker access setup before continuing. Run Briani's operations commands as your chosen non-root account, with that account's UID/GID; prefixing them with `sudo` changes the identity and fails the checks.

For a Pi, also use reliable power, active cooling, and preferably wired Ethernet. These measures do not establish a performance guarantee.

## 2. Choose where to store everything

Keep these three directories separate:

| Directory | Contents | Example |
|---|---|---|
| Deployment/project | Protected `.env` identifying your deployment | `/home/you/briani/ops` |
| State | Briani database, accounts, keys, thumbnails, qBittorrent/Prowlarr configuration | `/mnt/briani-ssd/state` |
| Media/data | Your library folders and managed downloads | `/mnt/briani-ssd/media` |

State and media may be sibling directories on the same mounted disk, but cannot contain each other or overlap the deployment directory. Give Briani dedicated writable directories for state and media; do not point it at a broad shared host directory. The operations tool requires them to be under an **already mounted non-root filesystem**. An ordinary folder on `/` is refused, even if it has plenty of space, to avoid writing to the OS disk when a media disk is missing. The backup target must also be on a mounted non-root filesystem.

Mount and prepare your disk using your operating system's storage tools first. The selected account must be able to create and write the directories. Briani will not change the ownership of your media disk for you. Paths must be absolute, must not be symlinks, and must not contain `:`, `#`, or newlines. Keep state private to the selected account; `init` creates its service directories with owner-only access. Briani resolves authorized paths through descriptor-based `openat2` containment. This protects requests from escaping those directories through symlinks or `..` traversal; it does not provide an atomic guarantee against an arbitrary local process moving or replacing directories concurrently. Treat the host and its local administrators as trusted.

Stop the Briani Compose stack before reorganizing, renaming, or moving the selected state or media directories on the host. After the change, update the deployment configuration through a reviewed migration procedure; do not move active paths while services are running.

Existing media belongs **inside the selected media directory**, for example `media/Videos/` and `media/Photos/`. In the containers, that directory appears as `/data` for both Briani and qBittorrent. Choosing `/mnt/briani-ssd/media` does not also expose other folders elsewhere on the host.

## 3. Load the supplied server images

Copy the candidate to your server, including `dist/`, `infra/`, `tools/operations/`, `images.lock.json`, and `toolchain.lock.json`. Keep those files from the same candidate together. You do not need to compile the server.

From the candidate's top-level directory, verify the supplied files:

```bash
sha256sum -c dist/SHA256SUMS
```

If a listed file is missing or a checksum fails, obtain the matching complete candidate before continuing. The checksum index describes the original packaged snapshot; local source edits are separate from it.

**On an Intel/AMD Linux host**, load:

```bash
docker image load -i dist/images/briani-server-and-egress-linux-amd64.tar
```

Use `briani-server:v1.0.0` as the server image in the next step.

**On an ARM64 host**, load both:

```bash
docker image load -i dist/images/briani-server-linux-arm64.tar
docker image load -i dist/images/briani-egress-linux-arm64.tar
```

Use `briani-server:v1.0.0-arm64` in the next step. Loading these archives does not verify native Pi execution.

The operations tool selects the matching network guard image automatically and verifies both images against `images.lock.json`. qBittorrent and Prowlarr are pulled using the pinned references in Compose, so initial setup also needs access to their image registry. The private local tags above are supported only with `--local-image` and the exact supplied image identities.

### Using the smaller operations archive

If you do not want the source tree on the server, extract the supplied operations archive into an existing folder you control:

```bash
tar -xzf dist/briani-operations.tar.gz -C /path/to/package-folder
```

Its tool root is `/path/to/package-folder/briani-operations/dist/operations/`. In the next section, set `BRIANI_PACKAGE` to that directory instead of the source tree. Load the separate image archives before switching directories. The archive contains its own locked Compose files and tools; use them together. This guide describes the current source documentation; the archive's embedded README reflects the original packaged snapshot.

## 4. Create your deployment

The examples below use a server at **192.168.1.50**, accessible on your trusted home LAN. Replace it with your server's actual IPv4 address, and adjust all paths to your mounted storage. Keep these variables in the same Bash terminal for the remaining steps:

```bash
# Absolute path to the candidate root, or the extracted operations tool root.
BRIANI_PACKAGE="/home/you/BrianiPlayer"
BRIANI_PROJECT="/home/you/briani/ops"
BRIANI_STATE_DIR="/mnt/briani-ssd/state"
BRIANI_MEDIA_DIR="/mnt/briani-ssd/media"
BRIANI_SERVER_IP="192.168.1.50"
BRIANI_SERVER_IMAGE="briani-server:v1.0.0"

# On ARM64, change BRIANI_SERVER_IMAGE to briani-server:v1.0.0-arm64.
python3 "$BRIANI_PACKAGE/tools/operations/briani.py" init \
  --project "$BRIANI_PROJECT" \
  --data "$BRIANI_MEDIA_DIR" \
  --state "$BRIANI_STATE_DIR" \
  --bind "$BRIANI_SERVER_IP" \
  --hosts "localhost;127.0.0.1;briani;$BRIANI_SERVER_IP" \
  --uid "$(id -u)" --gid "$(id -g)" \
  --image "$BRIANI_SERVER_IMAGE" --local-image
```

`init` creates the protected deployment `.env` and service state directories. If the deployment already exists, inspect it instead of replacing it. Do not source `.env` as a shell script.

`--bind` controls which **host interface** accepts connections on port **8088**. `--hosts` controls which hostnames/IPs the application accepts, without ports or URL schemes. Include the actual IP or hostname your clients will enter. If you use a hostname such as `briani.home`, add it to the semicolon-separated list too.

For access only from the server itself, use `--bind 127.0.0.1` instead. Phones and TVs cannot reach that loopback binding. Use the LAN example only on a trusted network; the stock Compose stack serves HTTP. The client requires you to explicitly allow unencrypted LAN/VPN connections.

Run the preflight:

```bash
python3 "$BRIANI_PACKAGE/tools/operations/briani.py" doctor \
  --project "$BRIANI_PROJECT"
```

Before startup, an empty service table is normal. Resolve any architecture, disk, permissions, memory-controller, or `openat2` error before continuing. The tool does not alter your kernel or weaken these requirements.

## 5. Start the services and capture their credentials

For a **new deployment**, run these in order:

```bash
python3 "$BRIANI_PACKAGE/tools/operations/briani.py" qbit-bootstrap \
  --project "$BRIANI_PROJECT"

python3 "$BRIANI_PACKAGE/tools/operations/briani.py" up \
  --project "$BRIANI_PROJECT"

python3 "$BRIANI_PACKAGE/tools/operations/briani.py" capture-prowlarr-key \
  --project "$BRIANI_PROJECT"
```

`qbit-bootstrap` starts qBittorrent and its network guard first, replaces the actual temporary Web UI password with a unique one, verifies it, and saves it privately. Run it **before** full-stack `up`; it refuses to replace an already running session. Use `qbit-bootstrap --interactive --project "$BRIANI_PROJECT"` instead if you want to choose the replacement password.

`up` starts the complete stack:

| Service | Purpose |
|---|---|
| `briani` | Accounts, libraries, media delivery, and the client API |
| `qbittorrent` | Sequential torrent downloads and seeding |
| `prowlarr` | Searches the indexers you configure |
| `torrent-egress-guard` | Restricts qBittorrent's network access inside its container network |

Give Prowlarr time to create `config.xml` before capturing its key. If the capture command reports that the file is absent, wait for Prowlarr startup and rerun that command. If the protected secret file already exists, leave it in place.

The saved credentials are `state/secrets/qbittorrent-webui-password` and `state/secrets/prowlarr-api-key`. Briani reads them automatically; you do not need to copy them into the app for the default stack. Protect these files and Docker access. qBittorrent's initial temporary password can appear in Docker's own logs.

Check readiness from a machine that can reach the selected interface:

```bash
curl --fail "http://$BRIANI_SERVER_IP:8088/healthz"
curl --fail "http://$BRIANI_SERVER_IP:8088/readyz"
```

You can also visit those addresses in a browser to check the API's health response. Port 8088 does not serve a Briani browser interface. Readiness does not mean you have configured working indexers yet.

## 6. Install a client and claim the first administrator

Install an app using [Client installation](../client-installation.md). A desktop or phone is convenient for initial administration; you can pair the TV afterwards.

Display the one-time setup code in an interactive terminal on the server:

```bash
python3 "$BRIANI_PACKAGE/tools/operations/briani.py" show-bootstrap-token \
  --project "$BRIANI_PROJECT"
```

Do not redirect or log that output. The code expires **30 minutes after its creation** and is removed once setup is claimed.

In the client:

1. Open **Servers → Add server**.
2. Give it a name and enter `http://192.168.1.50:8088`, using your actual server IP.
3. For this trusted-LAN HTTP setup, enable **Allow unencrypted HTTP for a trusted LAN/VPN server**, then **Save** and **Connect**.
4. The fresh server opens **Create the administrator**. Enter the **Bootstrap code**, **Display name**, **Username**, and a **Password** of 12–128 characters, then choose **Create administrator**.

Keep the code private. Your Briani administrator password is separate from the qBittorrent password. After setup, other users sign in with accounts you create, or use the TV device-code flow.

## 7. Add libraries and give users access

Create media subfolders on your mounted data directory before adding libraries, for example:

```bash
mkdir -p "$BRIANI_MEDIA_DIR/Videos" "$BRIANI_MEDIA_DIR/Photos"
```

Copy your existing media into those folders using your normal file tools. These paths appear as `/data/Videos` and `/data/Photos` inside the server. Do not select the private `.briani` download/staging directories as libraries.

In **Administration**, choose **Add library**, select **Mounted storage** and the offered **Directory**, then enter a library name. You select directories under the configured mount; you do not type arbitrary host paths into the app. Use a writable library for torrent destinations. A **Read-only library** allows browsing/playback and disables changes/downloads into it.

Use the library's **Scan** action after adding media. Return to **Libraries** and open a known video or photo to check the setup.

For other viewers, choose **Create user**, then use **Manage [library name] access** and **Save access**:

| Grant | Allows |
|---|---|
| Read | Browse, view photos, and play media |
| Download | Discover/add torrents and download into that library; also requires Read |
| Manage | Supported file and download management actions; also requires Read |

Grant each person only the access they need. A member with no library grants sees no libraries. Download actions also depend on task ownership and shared-job rules. The [user guide](../user-guide.md) explains everyday use.

## 8. Set up torrent discovery in Prowlarr

Skip indexer setup if you only want to browse your existing files. For torrent search, add your chosen indexers in Prowlarr's own administration UI, then test the connections in Briani. Briani does not supply indexer accounts or configure Prowlarr as a download client; Briani controls qBittorrent itself.

### Keep Compose commands attached to this deployment

The operations tool gives each deployment a name based on its **absolute project directory**. A plain `docker compose up` uses a different name and can create a second stack. Define this helper in the same Bash terminal to use the tool's exact project name for status, maintenance, and the private admin overlay:

```bash
BRIANI_COMPOSE_PROJECT="$(python3 - "$BRIANI_PROJECT" <<'PY'
import hashlib, pathlib, re, sys
p = pathlib.Path(sys.argv[1]).resolve()
slug = re.sub(r'[^a-z0-9_-]+', '-', p.name.lower()).strip('-') or 'deployment'
print(f'briani-{slug[:24]}-{hashlib.sha256(str(p).encode()).hexdigest()[:10]}')
PY
)"

briani_compose() {
  docker compose --project-name "$BRIANI_COMPOSE_PROJECT" \
    -f "$BRIANI_PACKAGE/infra/compose/compose.yaml" \
    --project-directory "$BRIANI_PROJECT" \
    --env-file "$BRIANI_PROJECT/.env" "$@"
}
```

Enable the private administration ports:

```bash
briani_compose -f "$BRIANI_PACKAGE/infra/compose/compose.admin.yaml" up -d
```

This may recreate containers and briefly interrupt downloads/playback. It preserves mounted state and media. The overlay binds the admin interfaces only on the server's loopback address:

| Interface | Address on the server |
|---|---|
| Prowlarr | `http://127.0.0.1:19696` |
| qBittorrent | `http://127.0.0.1:18080` |

If your server has no desktop, open an SSH tunnel from your own computer. Replace the login and IP with your server details:

```bash
ssh -N -L 19696:127.0.0.1:19696 -L 18080:127.0.0.1:18080 you@192.168.1.50
```

Keep that terminal open, then visit `http://127.0.0.1:19696` on your computer. Complete Prowlarr's setup/authentication prompts, add the torrent indexers you have access to, and test each one there. Its administrator login is separate from your Briani account. Configure indexers and categories for the content you want; no Stremio/Torrentio, movie catalog, per-site scraper, or Usenet setup is provided.

Back in Briani **Administration**, use **Test prowlarr** and **Test qbittorrent**. The default integration values are:

| Integration | Service URL used by Briani | Credential |
|---|---|---|
| Prowlarr | `http://prowlarr:9696/` | Automatically captured API key |
| qBittorrent | `http://qbittorrent:8080/` | Username `admin`, automatically saved Web UI password |

These are **container-to-container** addresses. Do not replace them with your computer's `localhost`, the tunnel ports, or the LAN client address. If you deliberately change an upstream credential, update its Briani integration using **Configure** and **New secret**; do not paste secrets into support messages.

Use the discovery provider/category controls and **Save discovery scope** if you want to restrict which configured providers/categories users can search. In **Discover**, try **Latest**, **Most seeded**, or **Search**. Results depend on the configured indexers; seeders/peers are their reported values and may be unknown or stale.

When done, remove the admin overlay's published ports by returning to the normal stack:

```bash
python3 "$BRIANI_PACKAGE/tools/operations/briani.py" up --project "$BRIANI_PROJECT"
```

No router forwarding is needed for LAN client access. The stock stack does not publish the torrent peer port to the host. Port 6881 is a peer transport setting, not a client or administration URL. Keep administration ports private.

## Everyday server operations

In a fresh terminal, restore the variables from step 4 and the Compose helper from step 8 before using these examples.

```bash
# Show services and repeat the host/storage checks.
python3 "$BRIANI_PACKAGE/tools/operations/briani.py" doctor --project "$BRIANI_PROJECT"
briani_compose ps --all

# Inspect recent Briani server logs.
briani_compose logs --tail 100 briani

# Stop cleanly without removing state or media.
briani_compose stop

# Start again with the host checks.
python3 "$BRIANI_PACKAGE/tools/operations/briani.py" up --project "$BRIANI_PROJECT"
```

Redact private information before sharing logs. Avoid sharing qBittorrent startup logs because they can contain temporary credentials. Do not rename/move the deployment directory casually: its path determines the Compose project name.

### Back up configuration and media

Choose a **new** destination on a mounted backup disk, outside your live state/media directories:

```bash
python3 "$BRIANI_PACKAGE/tools/operations/briani.py" backup \
  --project "$BRIANI_PROJECT" \
  --output /mnt/backup/briani-2026-10-14
```

Use your own date or unique name each time. The tool stops the state-writing services, copies their configuration, deployment/image records, and keys with a checksum manifest, then restarts the services that were previously running. Expect a brief interruption. The destination must not already exist.

**Media is excluded.** Back up your media disk separately if you want to protect the collection. The configuration backup contains passwords and encryption keys; keep it private and encrypt off-host copies. The app's **Database snapshot** action is only an application snapshot, not this full-stack backup.

### Restore or roll back

Use the operations bundle matching the backup's image locks, and run as the original UID/GID. Restore into **new, empty, separate** project/state directories:

```bash
python3 "$BRIANI_PACKAGE/tools/operations/briani.py" restore \
  --backup /mnt/backup/briani-2026-10-14 \
  --project /home/you/briani/restore-ops \
  --state /mnt/briani-ssd/restore-state \
  --data /mnt/briani-ssd/restore-media
```

This restores configuration, not media, and does not start the restored stack. For a configuration-only restore drill, keep it stopped while checking the copied files. The restore inherits the original binding/port: do not start it alongside the original server unless you have isolated its access, including the admin ports. This candidate records media filesystem identities; an empty or copied media directory will not silently become a replacement for the original disk.

For recovery of existing libraries/downloads, **stop the original stack first**, keep its original media mount and files in place, and use the explicit retained-media option:

```bash
python3 "$BRIANI_PACKAGE/tools/operations/briani.py" restore \
  --backup /mnt/backup/briani-2026-10-14 \
  --project /home/you/briani/recovery-ops \
  --state /mnt/briani-ssd/recovery-state \
  --data "$BRIANI_MEDIA_DIR" --allow-existing-data

python3 "$BRIANI_PACKAGE/tools/operations/briani.py" doctor \
  --project /home/you/briani/recovery-ops
```

Never run two stacks against the same media mount. Once the original stack is stopped and the restore checks pass, start the restored project with `up --project /home/you/briani/recovery-ops`. Check accounts, library access, playback, and existing download/recheck status before resuming normal use. Use the recovery project path for later operations. Copying media to another disk changes its recorded identity and requires a separately verified migration; this candidate does not automatically rebind it.

`rollback` takes the same arguments as `restore` and restores the backed-up image/state into a new project. Do not start an older server image against a database already migrated by a newer one.

### Upgrade only with a matching release package

There is no published upgrade target for this candidate. When an audited release is provided, keep the prior bundle, create a fresh backup, and follow that release's compatibility instructions. The CLI requires an exact pinned image present in the bundle's image lock and a reviewed compatibility file approving that precise transition:

```bash
python3 "$BRIANI_PACKAGE/tools/operations/briani.py" upgrade \
  --project "$BRIANI_PROJECT" \
  --backup /mnt/backup/briani-before-upgrade \
  --image 'registry.example/briani@sha256:<release-supplied-digest>' \
  --compatibility-file /path/to/release-supplied-compatibility.json
```

That image is a placeholder, not an available download. Do not invent a digest or approve compatibility yourself just to pass the check. Verify readiness, sign-in, browsing, playback, and downloads afterwards. Retain the backup until those checks succeed; use it for rollback if needed. Avoid unattended `latest` image replacements.

## Access away from home

Use your existing VPN or a separately configured HTTPS reverse proxy. The supplied stack does not install a VPN or TLS proxy for you, and plain HTTP exposes credentials to anyone who can observe the connection. For HTTPS, clients need a reachable URL and a certificate they trust; include that hostname in `BRIANI_HOSTS` in the deployment `.env`, then rerun `up`.

Do not forward qBittorrent/Prowlarr administration ports to the internet. Public exposure requires a reviewed TLS/proxy/firewall configuration and authentication/rate-limit controls; this guide's LAN example is not that configuration. External players must also be able to reach the server and trust its certificate.

## Troubleshooting

| Symptom | What to check |
|---|---|
| `doctor` reports a missing mount | Confirm the actual disk is mounted. Do not create a substitute folder on the OS disk. |
| Permission or UID/GID error | Use the account recorded during `init`; ensure it owns or can write the selected directories. Avoid `sudo` and world-writable permissions. |
| `openat2` or memory-limit failure | Use a host/kernel providing the reported capability. Do not bypass the check. |
| Local image identity mismatch | Load the correct architecture's archives and use their matching locks/tools. Do not retag an unrelated image. |
| Phone/TV cannot connect | Check server IP, port 8088, LAN binding, allowed host list, firewall access, and the HTTP opt-in. `localhost` on the phone/TV refers to that device. |
| HTTP 400 when connecting | Check that the address's hostname/IP is in `BRIANI_HOSTS`; entries have no scheme or port. |
| Bootstrap code expired | A restart does not renew it. Before any administrator exists, use the regeneration steps below. |
| No libraries or media | Add a directory under the mounted data root, scan it, and check the user's Read grant. |
| Discovery empty/unavailable | Test both integrations; check Prowlarr indexers, categories, credentials, and the user's Read + Download grant on a writable library. |
| Playback keeps buffering | Check peers/download speed and available data. Seeking ahead waits for sequential transfer; it does not prioritize missing pieces. |
| Video works on one device only | The client must decode the codec/container. Try a compatible external player; the server does not transcode. |
| qBittorrent stays disconnected | Check service health first. Automatic reconnect remains a candidate limitation; controlled qBittorrent restart recovery has recorded evidence. |

To renew an **unclaimed** setup code, stop Briani so it releases its database lock, run the one-shot regeneration in an interactive terminal, and start it again:

```bash
briani_compose stop briani
briani_compose run --rm --no-deps briani --regenerate-bootstrap
python3 "$BRIANI_PACKAGE/tools/operations/briani.py" up --project "$BRIANI_PROJECT"
```

The one-shot command prints the new code; keep it private and use it within 30 minutes. It refuses once setup is claimed and is not an administrator-password reset.

For a confirmed engine connection problem, the controlled recovery command is `briani_compose restart qbittorrent`. It interrupts active downloads. Recheck readiness and the integration test afterwards; do not repeatedly restart a stack with failing storage.

After power loss or a storage error, check disk health, free space, mounted paths, and server logs before restarting. Preserve state if SQLite reports corruption and restore a clean backup into a separate project. Keep the original disk and state until recovery is verified.
