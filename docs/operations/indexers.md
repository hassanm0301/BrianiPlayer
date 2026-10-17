# Set up torrent search

Briani's **Discover** screen searches for torrents through [Prowlarr](https://prowlarr.com/), which runs as part of your Briani server. Prowlarr starts with **no indexers** (the sites it searches), so Discover stays empty until you add some. Until then, Discover shows:

> No indexers are enabled. Enable indexers in Prowlarr and in Briani's settings.

This guide takes about ten minutes. You only need it for torrent search. Your existing libraries, and **Add → Magnet link…** / **Torrent file…**, work without it.

```
Briani app ──► Briani server ──► Prowlarr ──► the indexers you add
```

You choose the indexers. Briani doesn't include any, and it doesn't scrape sites itself. Only add sites you're allowed to use, and follow your local laws and each site's rules.

## Before you start

- Briani is already installed and running, and you've created the administrator account ([setup guide](README.md)).
- You can open a terminal on the server, or reach it over SSH.
- You know your **deployment folder**. That's the `--project` folder from setup, for example `~/briani/ops`. It contains `compose.yaml`, `compose.admin.yaml`, and `.env`.

The examples use `192.168.1.50` for the server and `you` for your login on it. Replace both with your own.

## 1. Open Prowlarr's admin page

Prowlarr's web page is private by default and can't be reached, even from your own network. Turn it on temporarily. On the server:

```bash
cd ~/briani/ops
```

```bash
docker compose -f compose.yaml -f compose.admin.yaml up -d
```

If your account needs `sudo` for Docker, put `sudo` in front of each `docker compose` command in this guide.

This publishes Prowlarr at `127.0.0.1:19696` and qBittorrent at `127.0.0.1:18080`, **on the server only**. Nothing new becomes reachable from your network. Docker may restart those two services, which briefly pauses downloads. Your settings and media aren't affected.

## 2. Connect to it from your computer

If you're using a browser on the server itself, open `http://127.0.0.1:19696` and skip to step 3.

Otherwise, open an SSH tunnel from your computer. The same command works in Linux and macOS terminals and in Windows PowerShell:

```bash
ssh -N -L 19696:127.0.0.1:19696 you@192.168.1.50
```

It shows no output while it runs. Leave that terminal open, and open **http://127.0.0.1:19696** in your browser.

## 3. Create your Prowlarr login (first visit only)

The first time, Prowlarr shows an **Authentication Required** dialog. Fill it in like this:

| Field | Choose |
|---|---|
| **Authentication Method** | **Forms (Login Page)** |
| **Authentication Required** | **Enabled** |
| **Username**, **Password**, **Password Confirmation** | A new login for Prowlarr. A password manager is a good place to keep it. |
| **Allowed Hosts** | **Leave empty.** If you do fill it in, include `prowlarr`, or Briani can't reach Prowlarr. |

Choose **Save**. This login only protects Prowlarr's own page. It's separate from your Briani account, and Briani doesn't need it because Briani connects with an API key it saved during setup.

## 4. Add indexers

1. In Prowlarr, open **Indexers** and choose **Add Indexer**.
2. Pick an indexer whose **Protocol** is **torrent**. Briani ignores Usenet indexers.
3. The **Privacy** column tells you what it needs. **Public** indexers need no account. **Private** indexers ask for your details on that site, such as a username, cookie, or API key.
4. Choose **Test**. When the test passes, choose **Save**.
5. Repeat for each indexer you want.

What indexers support affects Briani's three Discover modes:

| Briani mode | The indexer needs |
|---|---|
| **Search** | Search support. Almost all indexers have it. |
| **Latest** | RSS support |
| **Most seeded** | RSS support when the search box is empty, otherwise search support |

If none of your indexers support RSS, choosing **Latest** shows "No enabled provider supports recent releases. Use Search instead."

You don't need to touch Prowlarr's **Apps**, **Download Clients**, or **Sync App Indexers**. Briani reads Prowlarr's indexer list directly and sends downloads to its own qBittorrent.

**Want to check that everything is connected first?** Two lawful public indexers work well for this. **LinuxTracker** (Linux install images) and **PandaCD** (Creative Commons and artist-permitted music) both support search and RSS. Search for `ubuntu` in Discover to see LinuxTracker results.

> **Internet Archive doesn't work at the moment.** As of October 2026 (Prowlarr 2.6.5), archive.org doesn't answer requests that come from Prowlarr, so this indexer fails its test with a timeout. There's nothing to fix on your side.

## 5. Check the connection in Briani

1. In the Briani app, open the account menu (your initial at the bottom of the side bar) and choose **Administration**.
2. Under **Service health and integrations**, find the **prowlarr** row and use its test button (**Test prowlarr**). It should pass.
3. Under **Discovery scope**, check that **Providers scope** and **Categories scope** are both set to **All (no restriction)**. If either one is set to **Selected IDs**, make sure your new indexers and their categories are included, or switch it back to **All**. Then choose **Save discovery scope**.
4. Open **Discover** and choose **Retry sources**, or the refresh button at the top right. Try **Search** with a word you expect to find.

## 6. Close Prowlarr's admin page

When you're done, go back to the normal setup so the admin ports are closed again. On the server:

```bash
cd ~/briani/ops
```

```bash
docker compose up -d
```

You can now stop the SSH tunnel with **Ctrl+C**. Your indexers stay configured. To add or change indexers later, repeat steps 1, 2, 4, and 6.

## If something doesn't work

| What you see | What to do |
|---|---|
| "No indexers are enabled. Enable indexers in Prowlarr and in Briani's settings." | Prowlarr has no enabled torrent indexers, or Briani's **Discovery scope** leaves all of them out. Check steps 4 and 5. |
| "No enabled provider supports recent releases. Use Search instead." | None of your indexers support RSS. Use **Search**, or add an indexer with RSS support. |
| "Indexer '…' does not support browsing latest releases." / "…does not support text search." | That indexer is skipped in this mode. The others still return results. |
| "Indexer '…' did not respond in time." / "…is temporarily disabled by Prowlarr" / "…failed recently in Prowlarr" | The site is slow, down, or blocking Prowlarr. Open Prowlarr and test the indexer there. Prowlarr pauses an indexer for a while after repeated failures. |
| "Indexer '…' is rate limited; try again later." | The site limits how often it can be searched. Wait, or add more indexers. |
| `http://127.0.0.1:19696` won't load | Check that the SSH tunnel is still running and that you ran step 1. `docker compose ps` should list `127.0.0.1:19696->9696/tcp` for Prowlarr. |
| **Test prowlarr** fails after you set up the Prowlarr login | Clear **Allowed Hosts** in Prowlarr (**Settings → General**), or add `prowlarr` to it. |
| You regenerated Prowlarr's API key | Copy the new key from Prowlarr (**Settings → General**). In Briani's **Administration**, use **Configure** on the prowlarr row and paste the key into **New secret**. |
| A member sees no results, but you do | They need **Read** and **Download** access to a library they can download into. Set it under the library's access controls in **Administration**. |
| "This discovery filter is turned off in the server settings." | The provider or category filter they picked is outside the **Discovery scope**. Clear the filter, or widen the scope. |

For other server issues, see [advanced troubleshooting](advanced.md#troubleshooting).
