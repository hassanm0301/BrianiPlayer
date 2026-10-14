# Install a Briani Player client

Install the app on each device you want to use for viewing. You do not need Docker, .NET, or Flutter on those devices when using a supplied client package. Your [Docker server](operations/README.md) must already be running and reachable.

The files described here are private candidate artifacts under `dist/`, not public downloads. Obtain the matching candidate from its operator. There is currently no published client release page, store package, Windows installer, or macOS app bundle. See the [support matrix](compatibility/support-matrix.md) for what has and has not been verified. Paths in the commands below start at the candidate's top-level directory.

| Device | Package supplied |
|---|---|
| Linux x64 desktop | `dist/client/briani-player-linux-x64.tar.gz` |
| Android phone/tablet or Android TV | `dist/client/android/briani-player-local-test.apk` for local testing |
| Windows/macOS | No verified ready-made package; source build instructions only |

The Android file named `briani-player-unsigned.apk` needs signing before installation. Use the local-test APK for the sideload steps below.

## Linux x64 bundle

The archive targets Linux x86-64 (amd64). It needs a graphical desktop plus the host GTK 3, GLib/GObject, and libsecret libraries, a compatible system `libmpv` (`libmpv.so.2` in the inspected candidate), and the audio/video libraries used by that mpv build. Install these runtime dependencies through your distribution's package manager; their package names vary. The archive does not bundle mpv or every system library. The [client build notes](development/client-builds.md) link to the inspected runtime dependency list.

Extract it into a folder you control, then launch the bundled executable:

```sh
mkdir -p "$HOME/Applications"
tar -xzf dist/client/briani-player-linux-x64.tar.gz -C "$HOME/Applications"
cd "$HOME/Applications/briani-player-linux-x64"
./briani_player
```

Keep the executable, `data/`, and `lib/` together. To start it again, open that folder and run `./briani_player`, or create a desktop shortcut whose working directory is the bundle folder. If startup reports a missing shared library, install its runtime package and retry. For remembered sign-in, Linux also needs an available desktop secret service; if secure storage is unavailable, Briani offers a session-only login.

This is an unsigned candidate bundle. Its packaged startup was checked on Linux x64 with a fresh profile, but physical display, audio, Wayland compatibility, and playback from the optimized bundle have not been verified. A Linux x64 bundle cannot run on a Raspberry Pi ARM64 desktop.

## Android phone or tablet

Use `dist/client/android/briani-player-local-test.apk`. The app's minimum Android version is **Android 8.0 / API 26**. Its supplied native libraries target ARMv7, ARM64, and x86-64; device/decoder compatibility still needs testing. This APK is signed with the Android Debug certificate for local testing, rather than a release key.

To install without development tools:

1. Copy the APK from the candidate to your phone/tablet, for example by USB file transfer.
2. Open it in your device's file manager.
3. If Android asks, allow that file manager to **install unknown apps**. The exact settings label varies by device.
4. Review the installation prompt and install **Briani Player**.
5. Open the app from your launcher and [connect to your server](#connect-after-installation).

You can turn off that install permission afterwards. You do not need to allow access to your phone's entire media collection just to browse server libraries.

Alternatively, install from your computer with [Android SDK Platform Tools and adb](https://developer.android.com/tools/adb). Enable USB debugging in the device's Developer options, connect it, and approve your computer's debugging prompt:

```sh
adb devices
adb install -r dist/client/android/briani-player-local-test.apk
```

The device should appear as `device`, not `unauthorized`. If more than one device is connected, use `adb -s DEVICE_SERIAL install -r ...`, replacing the serial and APK path. Android Studio is not required. `-r` updates an existing app with a compatible signature while keeping its data; it cannot override a signing mismatch. The test app's identity is `org.brianiplayer.app.devtest`, separate from the provisional release identity `org.brianiplayer.app`.

The optimized candidate at `dist/client/android/briani-player-unsigned.apk` is **unsigned**. Android does not accept it for installation in this state. It is not a usable upgrade for the debug-signed test APK. There is no release signing key or store-ready APK in this checkout. Physical phone/TV behavior and optimized APK playback remain unverified.

## Android TV

The same local-test APK supports a TV launcher and remote controls; you do not need a separate TV APK. Your device must run Android TV, not a different smart-TV operating system.

1. Transfer `briani-player-local-test.apk` to the TV with a method supported by that device, such as a USB drive and file manager. Enable installation for that file manager when the TV asks, then install the APK. If your TV does not support this route, use its documented debugging connection with adb and the installation command above.
2. Launch **Briani Player** from the TV's app launcher.
3. Use the remote to add the same server address you used on your desktop or phone. For the LAN example, enter `http://192.168.1.50:8088` and enable the trusted-network HTTP option.
4. At sign-in, select **Link using another signed-in device**, name the TV, and choose **Request device code**.
5. On a phone or desktop already signed in to that same server, open **Account → Link a device**. Enter the code, choose **Check device**, verify the account/server/device shown, then choose **Approve device**.
6. Leave the TV on its waiting screen until it signs in. A code expires after five minutes; request a new one if needed.

Pairing signs the TV into the account that approves it. Use a member account with the intended library access if the TV is shared. Pairing does not create the first administrator; complete that server setup first. **Use username and password** is available if you prefer direct sign-in.

The Android TV emulator passed remote navigation and connected playback checks. That result does not certify every physical TV's video, audio, or graphics support.

## Windows and macOS

There are no provided or verified Windows or macOS client bundles in this candidate. The Flutter source and build instructions are available in [client build notes](development/client-builds.md), but native builds, runtime behavior, packaging, playback, and signing have not been verified on those platforms. No browser client or iOS app is provided.

## Connect after installation

Open **Servers → Add server**, enter a **Name** and **Server address**, then **Save → Connect**. For the server guide's LAN example, the address is `http://192.168.1.50:8088`; replace the IP with your server's address and enable **Allow unencrypted HTTP for a trusted LAN/VPN server**. On another device, `localhost` or `127.0.0.1` refers to that device, not the server.

Use HTTPS for untrusted remote access. Login credentials and session traffic are unencrypted over HTTP. The operator obtains the first-administrator bootstrap code on the server; other viewers use the accounts created for them. Continue with the [user guide](user-guide.md) for signing in, adding libraries, downloading, and watching.
