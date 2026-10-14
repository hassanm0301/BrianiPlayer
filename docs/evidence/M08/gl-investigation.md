# M08 bounded Android EGL investigation

2026-10-12. Read-only source/log investigation; no build, install, AVD change, native-library patch or production edit. Reviewed the locked media_kit_video 2.0.1 Android controller/VideoOutput and upstream mpv commit `78d43740f5`, matching the packaged version string `v0.36.0-549-g78d43740f5-dirty`. A dirty binary may contain additional patches; exact guest EGL source revision was not established.

## Actual observations

Parent logs `/tmp/briani-m08-android-host-gpu.log` and `/tmp/briani-m08-android-skia-parent-verbose.log` retain failed ordinary generated H.264/AAC baseline playback: native `current-vo` empty, `vo-configured=no`, context creation errors, no native decoded screenshot and zero saturated pixels among 1,327,104 interior screen samples. Dimensions and audio-driven position remain insufficient evidence of video rendering. Flutter renderer/host GPU changes did not pass that pixel gate.

Read-only command (exit 0):

```sh
/opt/android-sdk/platform-tools/adb -s emulator-5580 logcat -d -v brief -s libEGL:E EGL_emulation:E emuglEGL:E OpenGLRenderer:E VideoOutput:I
```

Saved filtered output: `/tmp/briani-m08-gl-filtered-readonly.log`. VideoOutput PID 2479 reports a Surface created, followed by the same PID's EGL threads 2552 and 2553 reporting `eglCreateContext` error `0x3004 (EGL_BAD_ATTRIBUTE)`. An unrelated PID 537 `eglQueryContext` error is excluded from the inference. No URI/ticket/credential output is needed.

Read-only `adb -s emulator-5580 shell dumpsys SurfaceFlinger`, filtered to EGL/GLES capability lines, exited 0: Android META-EGL 1.4, EGL_KHR_create_context advertised, GLES 3.1 Android Emulator Translator on the AMD host. Saved selected lines: `/tmp/briani-m08-gl-capabilities-readonly.log`. This is a capability observation, not a native player rendering pass.

## Narrow failure boundary and hypothesis

The locked plugin sets `vo=gpu`, `opengl-es=yes`, `gpu-context=android` (`android_video_controller/real.dart:194–206`); its emulator default sets `hwdec=no` (137–152). Java `VideoOutput.java:55,94–99` obtains a SurfaceProducer surface and passes a JNI global reference as `wid`.

Pinned mpv Android initialization calls its context helper before querying the native visual, setting native-window geometry or creating a window surface. The observed helper error therefore precedes those format/surface operations. A rejected ANativeWindow format is not supported by this failure evidence. [Pinned context_android.c, lines 63–80](https://raw.githubusercontent.com/mpv-player/mpv/78d43740f5/video/out/opengl/context_android.c).

The GLES helper requests client version 2 and `EGL_CONTEXT_FLAGS_KHR` with value zero by default, or the debug bit when gpu-debug is enabled. Google gfxstream's guest EGL parser rejects zero context flags, returning EGL_BAD_ATTRIBUTE unless a recognized debug/forward/robust bit is present. This precisely fits the captured call/error, but remains an inference until tested against the actual guest. [Pinned egl_helpers.c, lines 158–190](https://raw.githubusercontent.com/mpv-player/mpv/78d43740f5/video/out/opengl/egl_helpers.c), [Google guest EGL parser, lines 1606–1612](https://raw.githubusercontent.com/google/gfxstream/main/guest/egl/egl.cpp). Zero is the specified default and the debug bit is supported for GLES; the suspected restriction belongs to the guest parser, not a requirement to disable GPU security. [Khronos EGL_KHR_create_context, context-flags section](https://raw.githubusercontent.com/KhronosGroup/EGL-Registry/main/extensions/KHR/EGL_KHR_create_context.txt).

## One recommended experiment

Run the existing strong Android security/pixel integration test once with **test-only `gpu-debug=yes`**, read back `options/gpu-debug` before the first `vo=gpu` activation. Keep the production relay, GLES/android GPU context, emulator software decoder and every security flag unchanged. The pinned GPU option maps directly to the context debug field, causing the helper to request bit 1 instead of zero. If initial VO activation already occurred, arrange initialization before mounting/opening the Video rather than relying on an ineffective late setting. [Pinned GPU option declaration](https://raw.githubusercontent.com/mpv-player/mpv/78d43740f5/video/out/gpu/context.c).

Success still requires actual colored baseline pixels, configured native VO and zero secondary/unscoped requests; retain filtered EGL errors and native screenshot/ADB evidence. A change in error alone is diagnostic progress, not acceptance. Do not enable this globally from the hypothesis, weaken the pixel gate, replace SurfaceProducer speculatively or invoke D13 from emulator-only failure. D13 requires the physical-target baseline evidence described in `plan/specs/11_DECISIONS_AND_RISKS.md`.

## Parent experiment and production correction
The initial diagnostic placement waited for VideoController initialization before mounting its widget and timed out; the native API's `waitForInitialization:false`, after `player.handle`, corrected that ordering. The actual EGL flags experiment then passed: `/tmp/briani-m08-egl-debug-experiment2.log` exit0, two tests. Baseline `current-vo=gpu`, `vo-configured=yes`, decoded H264/yuv420p, native screenshot 6,764 saturated pixels of9,216 sampled; Flutter screen914,897 saturatedpixels of1,327,104. The seven hostile source cases generated no secondary fetch. ACTION_VIEW rejected10invalidcaps. Decoder fallback errors from forced auto-safe were retained, not hidden.
Parent implemented emulator-only detection through the locked video plugin's existing `Utils.IsEmulator` channel. Only emulator graphics get gpu-debug=yes with readback; physical-device configuration and security flags remain unchanged. The production run without the diagnostic flag `/tmp/briani-m08-egl-production-security.log` exited0, two tests. The temporary test define was removed. Adapter default hardware preference was subsequently corrected to platform automatic so the video plugin retains its emulator software-decoder selection; that final minor change still requires regression. No Media3 replacement occurred. Physical Android/mobile/TV certification remains outstanding.
