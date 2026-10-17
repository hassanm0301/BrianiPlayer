# Briani Player user guide

Briani Player is a native app for browsing media libraries and managing downloads on your own Briani server. It is not a browser app or a hosted account service. The server operator installs and maintains the Docker Compose services; start with [server installation and operations](operations/README.md). Install a client using [client installation](client-installation.md).

## Connect to your server

Open **Servers** and choose **Add server**. Enter a **Name** and **Server address**, then choose **Save**. Use the server's LAN IP or DNS name and its configured port, for example `http://192.168.1.50:8088` on a trusted home LAN or `https://media.example.net` behind a correctly configured TLS endpoint. Do not enter `localhost` on a phone or TV: that name refers to the device running the client, not your server. Keep the address free of usernames, passwords, query strings, and fragments.

Use HTTPS when connecting over an untrusted network. For a server on a trusted LAN or VPN, the app can explicitly allow unencrypted HTTP using **Allow unencrypted HTTP for a trusted LAN/VPN server**. With HTTP, credentials and session traffic are not encrypted, so use that option only on a network you trust. After saving the profile, choose **Connect**. **Check connection again** appears after a connection error and can help distinguish an address or server availability problem from a sign-in problem.

The first time anyone connects to a fresh server, the app shows **Create the administrator**. Enter the one-time **Bootstrap code**, **Display name**, **Username**, **Password**, and **Confirm password**, then select **Create administrator**. The [server guide](operations/README.md#4-connect-the-app-and-create-your-administrator) explains how to display the code privately; it expires after 30 minutes and can only claim the first administrator account. Passwords have no length or character rules; the two password fields must match. Error messages come from the server and say what to change. Later users select **Sign in** with an account created by an administrator. A server-reset password must be changed before the client continues.

On Android TV, choose **Link using another signed-in device** on the sign-in screen. Give the TV a device name and choose **Request device code**. On a signed-in phone or desktop connected to the same server, open the account menu (your avatar), choose **Link a device**, enter the TV's code, choose **Check device**, verify the displayed account, server and device name, then choose **Approve device**. The code expires after five minutes. The TV signs in when it receives the approval. You can also use **Use username and password** on the TV.

## Browse libraries and photos

After sign-in, the main navigation contains **Libraries**, **Discover**, and **Downloads**. Your server administrator decides which libraries you can see. Open a library, then a folder or item. Use the folder sort menu to change its order; supported file actions such as **Rename**, **Move**, and **Move to trash** depend on your account's library permissions. Trash is a server-side operation.

The **Libraries** screen may show **Continue watching** when you have saved progress. Its visibility can be changed in **Settings**. Photo folders open a viewer where you can move between adjacent images, zoom and pan, or start a slideshow.

## Discover and download

In **Discover**, choose **Latest**, **Most seeded**, or **Search**. Search looks through torrent result names. **Filters** provides source/provider and category filters, minimum and maximum size, minimum seeders, and sorting by the available result fields; on wide windows you can also sort by selecting a column header. Result seeders, leechers, and peer counts are reported by configured sources; they can be unknown or stale. Results depend on the server administrator's Prowlarr configuration and enabled indexers. Briani does not include indexers or scrape sites directly. If Discover says no indexers are enabled, the administrator can follow [Set up torrent search](operations/indexers.md).

Choose a result's **Add to downloads** action, select a destination library, and add the download. You can also choose **Add → Magnet link…** or **Add → Torrent file…**. For a new torrent, Briani obtains its metadata before payload transfer. Review the file list and use **Save selection and start** to select the files you want. Downloads are sequential: earlier selected video files can hold up later files, so selecting only the video you need can make it available sooner.

In **Downloads**, open a request to see its files and transfer state. Pause, resume, retry, remove a request, or change transfer settings where those actions are available to your account. Removing a request and deleting its payload are different operations; deleting payload has a separate confirmation. When a selected video has enough verified bytes and the player has the metadata it needs, choose **Play**. Missing data buffers while downloading continues. A seek into data that has not arrived may wait; seeking does not change torrent piece priority. Peer availability, file layout, and container metadata affect when playback can start, so no startup time is guaranteed.

After selected files finish, Briani imports supported media into the destination library. Check the download's import status, then return to **Libraries** to browse it. The torrent may continue seeding according to the server's settings; the imported entry is coordinated with its download payload.

## Play media

Videos play in the embedded player by default. Depending on the platform and media, player controls include play/pause, seek, volume, fullscreen, audio and subtitle tracks, subtitle delay, playback speed, and fit/aspect options. Playback is decoded on the client device; the server does not transcode video. Format, codec, graphics, audio and external-player compatibility vary by device.

Use **Play with** to hand playback to an installed compatible app on Android or a configured executable on desktop. The external player must be able to reach the same server. On returning to Briani, resume internally or mark the file watched in the library; external playback does not report progress automatically. **Copy playback URL** creates a temporary URL that grants access to that one file until its session expires or is revoked; treat it like a credential.

On desktop, **Play with → Choose installed player…** lets you select an executable if Briani has not found your player. Device-specific player settings are under **Settings → This device**. When setting custom arguments, enter one argument per line and include exactly one complete `{url}` argument. Briani starts the executable directly; shell commands are not player arguments. On Android, **Play with** lists installed apps that can handle the video URL.

The embedded player may ask whether to resume a saved position. Change this behavior, preferred playback mode and related options under **Settings → Playback and photos**. Client-side decoding means unsupported codecs or device audio/video capabilities can prevent playback even when the server can provide the file.

## Use a TV remote

Use the directional pad to move the highlighted focus, **OK/Select** to open an item or activate a control, and **Back** to return. The TV navigation row gives access to **Libraries**, **Discover**, and **Downloads**; the account control opens settings and account actions. Forms and menus can be used with the remote.

During playback, use the on-screen controls for seeking, tracks, subtitles, and other options. A supported remote's media play/pause button also controls playback. Seeking into an unfinished download may buffer, just as it does on desktop or mobile. Use device-code pairing to avoid entering your password with the remote.

## Account and settings

Open the account menu from your avatar (at the bottom of the sidebar on desktop, at the top right on phones and TV) for **Account and devices**, **Settings**, **Link a device**, **Switch server**, and **Sign out**. On desktop, **Settings** is also the gear above the avatar. Administrators also see **Administration**. In **Account and devices**, change your password or revoke a signed-in device session. Changing your password signs out every device; revoking a session also stops playback tickets from that session.

Settings include appearance and accessibility, library layout and sorting, visible torrent columns, playback preferences, photo slideshow timing, and device-local options such as display scale and external-player configuration. Some preferences sync with your server account; window size and executable paths belong to the device.

The administrator controls accounts, per-library grants, server libraries, Prowlarr connection, and service configuration in **Administration**. **Read** is needed to browse and play a library. Torrent discovery and downloads require the relevant download permission for a destination library. If a library or action is missing, ask the administrator to check your grants.

## Platform support and limits

The current candidate has an installable Linux x64 bundle and an Android debug-signed local-test APK. Windows and macOS source builds have not been verified; there is no public release package or signed app-store build. Android phone and TV behavior was exercised in an emulator, while physical devices remain unverified. See the [support matrix](compatibility/support-matrix.md) for evidence and remaining checks. Briani has no web client or iOS target.

Media compatibility is not universal. High dynamic range formats, Dolby Vision, damaged containers, audio passthrough, and every external player/device combination are not promised. Playback depends on valid available data and adequate peers; missing data buffers instead of being presented as media bytes.
