# 10 — CLI-first development, Codex and platform builds

## Development host

The reference development workflow targets Linux, including Arch Linux and KDE/Wayland. Use the operator's actual CPU/GPU and available virtualization when validating emulator and native playback behavior. Do not select the backend because the user previously used Go. Server code can be built/tested locally for development or in SDK containers; the shipped server still has Docker-only deployment.

Required tools: Git, current .NET 10 SDK, Docker Engine/Compose/buildx, Flutter stable SDK with bundled Dart, compatible Android JDK/toolchain, Android SDK command-line tools/platform-tools/emulator, and platform native build prerequisites. Codex runs commands in the checked-out repository. Pin exact versions after compatibility validation; do not scatter unpinned installer scripts or daily upgrades through milestones.

Android Studio is optional. It can simplify SDK/AVD setup, Logcat, profiler and visual debugging, but the build and emulator do not require the IDE to remain open. Use the Gradle wrapper, not a globally installed arbitrary Gradle version. The selected Android Gradle plugin determines the JDK requirement; capture it in the lock report rather than guessing an incompatible combination.

See S18–S21 for Android/Flutter primary documentation. Existing SDK licenses or account credentials are not implied by this plan; the operator must accept required licenses and provide access appropriately.

## First environment check

M00/M01 implement a non-destructive doctor command that records versions, compatible SDK components, architecture, `/dev/kvm` availability for the local Android emulator, storage, Docker permissions and output directories. Report missing prerequisites with commands/instructions; do not silently add the user to privileged groups or change BIOS settings.

After one-time installation, use these command families (repository scripts will wrap exact project names):

```bash
# SDK/toolchain diagnostics
flutter doctor -v
dotnet --info
docker compose version
adb version

# Android virtual devices managed outside Android Studio
"$ANDROID_HOME/emulator/emulator" -list-avds
"$ANDROID_HOME/emulator/emulator" -accel-check
"$ANDROID_HOME/emulator/emulator" -avd "$BRIANI_TV_AVD"

# Client builds/tests
cd client
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

SDK image/AVD names are discovered from `sdkmanager --list` and pinned in development instructions. Do not invent an Android TV image identifier. Use x86_64 for an x86-64 hardware-accelerated emulator, with matching native player libraries. ARM-only release libraries may not run in that emulator. Set SVM/KVM/permissions appropriately through administrator-approved host setup.

Launch Android/TV via an explicit known activity or TV launcher intent, not a phone-only launcher shortcut that fails to find a Leanback activity. Wrapper scripts resolve the installed package/activity.

```bash
adb devices
adb shell input keyevent KEYCODE_DPAD_DOWN
adb shell input keyevent KEYCODE_DPAD_CENTER
adb shell input keyevent KEYCODE_BACK
adb exec-out screencap -p > /tmp/briani-tv-screen.png
adb logcat
```

Screenshots help UI review, but automated D-pad assertions are still required. Do not install an emulator on the Pi server as part of production deployment.

## Local versus cloud agents

A local Codex execution environment can access the locally running emulator and containers when permissions permit. A remote/cloud execution environment does not automatically reach the user's PC emulator or Pi. Arrange a separately authorized runner or record the hardware gate as blocked; never claim a remote agent used a local TV because ADB exists in its container.

Do not give agents personal indexer/passkey credentials for routine tests. The fixtures require no paid account or arbitrary download-site access.

## Platform release matrix

| Target | Build runner | Initial artifact |
|---|---|---|
| Linux x64 | Linux | Packaged app bundle plus tested AppImage where feasible; document/bundle libmpv dependencies appropriately. |
| Windows x64 | Windows with required C++ tools | ZIP application bundle; installer is optional after the working bundle, not a release blocker for initial distribution. |
| macOS arm64/x64 | macOS/Xcode | App bundle/DMG for validated architectures; sign/notarize only with authorized credentials. |
| Android mobile | Linux/Windows/macOS Android toolchain | Signed APK per supported ABI; AAB only when a store publication is separately authorized. |
| Android TV | Same Android toolchain | TV-capable APK with required launcher configuration and D-pad tests. |
| Server arm64/amd64 | buildx CI + native smoke runners | Multi-architecture OCI images and pinned Compose manifest. |

Do not promise all desktop binaries can be built correctly on an Arch host alone. macOS signing/notarization and Windows toolchain dependencies are real infrastructure requirements. Store review/account fees, application ID ownership and signing keys are not created by the model. Use provisional package ID `org.brianiplayer.app` during development and verify it is controlled/usable before public release; never claim registration.

A single Android codebase may provide mobile/TV entry points or flavors with shared logic. Pin the chosen manifest/flavor design in M01; default is one APK declaring both appropriate launchers with runtime TV detection, unless the locked tooling requires separate thin flavors. This is a packaging adjustment, not two separate app implementations.

## Dependency policy

Lock .NET SDK/package versions, Flutter SDK revision, Dart packages, Gradle wrapper/plugin/JDK, native player binaries, OpenAPI generator, all container images and fixture tools. M00 tests upstream compatibility; M01 writes `toolchain.lock.json` and lockfiles. Use supported stable releases, never master/nightly merely because an online code example includes an appealing endpoint.

Native libmpv behavior comes from the actual packaged binaries, not the newest system mpv on the developer's workstation. Record native versions per target and test release builds; debug performance alone is not representative. Prevent native dependency downloads from silently changing without a checksum/version lock.
