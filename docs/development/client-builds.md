# Building the native client

This guide covers local development and private candidate builds of the Flutter client. Windows/macOS builds and release signing remain unverified; Linux and the Android TV emulator have local build/runtime evidence. Android Studio is optional; Flutter, Gradle, and Android command-line SDK tools are sufficient.

## Prerequisites

Use the repository's locked Flutter/Dart and package versions. Install Flutter stable, Git, CMake and GTK 3 development files for Linux desktop builds. Android builds require a compatible Java 17 toolchain (the app's Gradle compile target is 17), Android SDK command-line tools, platform tools, and the SDK components selected by Flutter. Accept Android SDK licenses with the Android SDK tools. Do not install or accept licenses from an unverified script.

Check what is installed:

```bash
flutter --version
flutter doctor -v
java -version
adb version
```

The Android SDK can be managed with `sdkmanager` and `avdmanager`; Android Studio need not be open or installed. Emulator/AVD creation and device tests are separate from compiling an APK. Do not assume an AVD name or that a desktop emulator proves physical TV playback.

## Dependency and test checks

From the repository root, the task runner resolves the client directory and enforces the checked-in pub lockfile:

```bash
python tools/dev.py client --task analyze
python tools/dev.py client --task test
```

Or run Flutter directly:

```bash
cd client
flutter pub get --enforce-lockfile
flutter analyze --no-pub
flutter test --no-pub
```

Do not run `pub upgrade` as part of a build. If the lockfile must change, treat it as a dependency update and review/test that change separately.

## Linux desktop

Build the same debug configuration used by the repository task runner:

```bash
python tools/dev.py client --task build --platform linux
```

The equivalent direct command, from `client/`, is:

```bash
flutter build linux --debug
```

The bundle is under `client/build/linux/x64/debug/bundle/`; launch the bundled executable from that directory, where its Flutter data and libraries are located. The inspected debug plugin dynamically resolves the host's mpv library. A release package must therefore inventory or bundle its native runtime and notices; the current debug output is not a self-contained release package. Physical display, audio, Wayland, X11, and packaged release behavior need separate verification.

For a local optimized build, run `flutter build linux --release` from `client/`. The final optimized bundle is copied to `dist/client/linux-x64/`. Its packaged startup smoke runs the copied bundle in a temporary directory with a fresh profile and no SDK on its PATH. GTK 3, GLib/GObject, the libraries recorded in `docs/evidence/M11/linux-runtime-ldd.log`, and a compatible host libmpv remain runtime requirements. The plugin dynamically loads mpv; it is not bundled in this candidate. Physical audio/display and Wayland remain separate checks.

## Android mobile and TV

Build a debug APK from the repository root:

```bash
python tools/dev.py client --task build --platform android
```

Or, from `client/`:

```bash
flutter build apk --debug
adb devices
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

The debug application ID has the `.devtest` suffix (`org.brianiplayer.app.devtest`), separate from the provisional base ID `org.brianiplayer.app`. `adb install -r` updates that package without first uninstalling it. Use a connected device or an AVD whose ABI is supported by the locked native video packages. To launch the app from a shell, use the package's installed launcher activity; Android TV should be launched through its TV launcher rather than assuming the phone launcher entry is suitable.

The release build type currently has no authorized signing configuration. `flutter build apk --release` is an unsigned local candidate command, if the Gradle toolchain builds it; it cannot be installed as an update to a differently signed app or uploaded to a store. No signing key, store identity, or public distribution authorization is implied. The Android debug APK scanned for M11 is signed with the Android debug certificate, not a release key.

The final connected API36 TV emulator flow passed real D-pad navigation, generated H.264 video rendered before torrent completion, actual missing-data buffering/recovery, Tracks, Back focus restoration, and browsing the completed import. Evidence is under `docs/evidence/M08/artifacts/1966597629c243fb847df025f1568c0a/`. The earlier emulator EGL issue is corrected with an emulator-only option; physical device graphics configuration is unchanged. D-pad tests and this emulator result do not certify a physical phone or TV.

## Windows and macOS

Use a native platform runner with the required Flutter desktop dependencies. The following commands are the intended local builds; they were **not run** for this checkout:

```powershell
cd client
flutter pub get --enforce-lockfile
flutter analyze --no-pub
flutter test --no-pub
flutter build windows --debug
```

```bash
cd client
flutter pub get --enforce-lockfile
flutter analyze --no-pub
flutter test --no-pub
flutter build macos --debug
```

Windows requires the native Windows desktop toolchain; macOS requires macOS and Xcode. A Linux build cannot establish either platform's native dependencies, player compatibility, signing, or packaging. Those platforms have no build or runtime pass recorded here.

## What is verified

Linux debug and release builds passed. The connected Linux/Xvfb app decoded three generated containers, including early playback and buffering/recovery, and exercised external-player handoff. The Android TV emulator connected workflow passed; a universal release APK also built and is in `dist/client/android/briani-player-unsigned.apk`. Its signature check confirms it is unsigned; the installed integration APK uses the separate debug identity. Windows/macOS, physical devices, audio/display compatibility and user-deferred Pi measurements remain unverified. See the evidence handoffs for exact artifacts and limitations.
