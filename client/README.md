# Briani Player client

Briani Player is a native Flutter app for Linux, Windows, macOS, Android phones, and Android TV. It connects to a self-hosted Briani server. There is no browser client or iOS target.

For end-user setup, see [install a client](../docs/client-installation.md) and the [user guide](../docs/user-guide.md). For the current platform evidence and limitations, see the [support matrix](../docs/compatibility/support-matrix.md). The current candidate includes a Linux x64 bundle and an Android debug-signed local-test APK; the optimized Android APK is unsigned and cannot be installed.

The generated OpenAPI client lives in `packages/briani_api`; its source contract is maintained under `../contracts/`. Handwritten app code must call the generated client rather than define parallel wire models.

## Development

Follow [client build notes](../docs/development/client-builds.md) for toolchain prerequisites, locked dependency installation, analysis, tests, and platform-specific build commands. In brief, from the repository root:

```sh
python tools/dev.py client --task analyze
python tools/dev.py client --task test
```

Platform builds need their native toolchains. Do not run dependency upgrades as part of an ordinary build; keep `pubspec.lock` enforced.
