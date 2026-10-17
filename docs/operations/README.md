# Set up your Briani server

Run Briani on a 64-bit Linux computer or Raspberry Pi 5 with Docker Compose. Then install the app on the devices you want to watch from.

## Before you start

- Install [Docker Engine](https://docs.docker.com/engine/install/) and the [Compose plugin](https://docs.docker.com/compose/install/linux/), plus Python 3.10 or newer.
- Use a non-root account that can run Docker and write to your media disk.
- Have a local disk already mounted, such as `/mnt/briani`. State and media must be separate, dedicated folders on mounted storage, with at least 5 GiB free for the initial check. Allow more space for your collection. The host and its local administrators must be trusted; stop the stack before moving or reorganizing either folder.
- Have the supplied Briani candidate files on the server. First startup also needs internet access to pull the pinned qBittorrent and Prowlarr images. These are private Briani test packages; there is no public Briani image to pull yet. [Platform status](../compatibility/support-matrix.md) lists remaining verification.

The examples use `192.168.1.50` for your server. Replace it with your actual LAN IP.

## 1. Load the images

Open a terminal in the Briani candidate folder:

```bash
cd /path/to/BrianiPlayer
```

On an **Intel/AMD Linux computer**:

```bash
docker image load -i dist/images/briani-server-and-egress-linux-amd64.tar
```

On a **64-bit Raspberry Pi or other ARM64 host**, use these instead:

```bash
docker image load -i dist/images/briani-server-linux-arm64.tar
docker image load -i dist/images/briani-egress-linux-arm64.tar
```

## 2. Choose your folders and address

Run this in the same terminal. Change the disk paths and IP to yours. On ARM64, set the image to `briani-server:v1.2.0-arm64`.

```bash
BRIANI_PACKAGE="$PWD"
BRIANI_PROJECT="$HOME/briani/ops"
BRIANI_STATE_DIR="/mnt/briani/state"
BRIANI_MEDIA_DIR="/mnt/briani/media"
BRIANI_SERVER_IP="192.168.1.50"
BRIANI_SERVER_IMAGE="briani-server:v1.2.0"

python3 "$BRIANI_PACKAGE/tools/operations/briani.py" init \
  --project "$BRIANI_PROJECT" \
  --state "$BRIANI_STATE_DIR" --data "$BRIANI_MEDIA_DIR" \
  --bind "$BRIANI_SERVER_IP" \
  --hosts "localhost;127.0.0.1;briani;$BRIANI_SERVER_IP" \
  --uid "$(id -u)" --gid "$(id -g)" \
  --image "$BRIANI_SERVER_IMAGE" --local-image

python3 "$BRIANI_PACKAGE/tools/operations/briani.py" doctor \
  --project "$BRIANI_PROJECT"
```

Your configuration and accounts go in the state folder; your files go in the media folder. The tool checks storage, permissions, Docker memory-limit enforcement, and Linux `openat2` path-containment support. Briani uses descriptor-based containment to keep authorized paths beneath their configured directories; it cannot guarantee safety against an arbitrary local process moving directories concurrently. If the tool reports a problem, use [troubleshooting](advanced.md#troubleshooting) before continuing.

## 3. Start the server

Run these in order for a new installation:

```bash
python3 "$BRIANI_PACKAGE/tools/operations/briani.py" qbit-bootstrap \
  --project "$BRIANI_PROJECT"
python3 "$BRIANI_PACKAGE/tools/operations/briani.py" up \
  --project "$BRIANI_PROJECT"
python3 "$BRIANI_PACKAGE/tools/operations/briani.py" capture-prowlarr-key \
  --project "$BRIANI_PROJECT"
```

`qbit-bootstrap` sets and saves qBittorrent's password; `up` starts the full stack; `capture-prowlarr-key` saves Prowlarr's API key. If Prowlarr has not finished starting, wait briefly and rerun only `capture-prowlarr-key`.

### Use Docker Compose directly

`init` creates **compose.yaml**, **compose.admin.yaml**, and a protected **.env** in your deployment folder. The state and media paths above are required; Compose also rejects missing paths. After completing the first-start credential steps, you can manage the server with standard Compose commands:

```bash
cd "$BRIANI_PROJECT"
docker compose up -d
docker compose ps
```

The generated Compose files use the same deployment name as the operations tool. Keep your mounted disk available; Compose refuses to silently create replacement directories for missing storage. For backups and recovery, continue using the operations tool as described in [advanced maintenance](advanced.md).

## 4. Connect the app and create your administrator

[Install a client](../client-installation.md), then display the setup code in your server terminal:

```bash
python3 "$BRIANI_PACKAGE/tools/operations/briani.py" show-bootstrap-token \
  --project "$BRIANI_PROJECT"
```

In the app:

1. Choose **Servers → Add server** and enter a name.
2. Enter `http://192.168.1.50:8088`, using your actual server IP.
3. Enable **Allow unencrypted HTTP for a trusted LAN/VPN server**, then **Save → Connect**.
4. Enter the **Bootstrap code**, **Display name**, **Username**, **Password**, and **Confirm password**. Choose **Create administrator**. If anything is wrong, the server explains what to fix.

The code is private and expires 30 minutes after the server first creates it. [Renew an expired code](advanced.md#troubleshooting) if needed. Use this HTTP setup only on a trusted network; [remote access](advanced.md#access-away-from-home) needs additional setup. There is no Briani browser app.

## 5. Add your media

Create a library folder and copy your files into it:

```bash
mkdir -p "$BRIANI_MEDIA_DIR/Videos"
```

In the app, open **Administration → Add library**, select **Mounted storage** and the **Videos** directory, give the library a name, then choose **Add**. Use its **Scan** action. Open **Libraries** to browse and play your files.

For other people, use **Create user** and the library's access controls. **Read** allows browsing/playback; **Download** adds torrent downloads; **Manage** adds file-management actions. Download and Manage also require Read. Choose **Save access** after editing grants.

## 6. Set up torrent search (optional)

Discover stays empty until you add indexers in Prowlarr. Follow [Set up torrent search](indexers.md). It takes about ten minutes. Existing files can be used without configuring indexers.

For daily app use, see the [user guide](../user-guide.md). Backups, upgrades, service controls, and recovery are in [advanced server setup and maintenance](advanced.md).

To let people download the apps straight from your server, set up the optional [client download page](downloads.md).
