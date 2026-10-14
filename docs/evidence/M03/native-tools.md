# M03 media utilities: FFmpeg 9.0.2 build evidence

Date: 2026-10-12. Scope: standalone, minimal FFmpeg/FFprobe build stage for bounded metadata probing and one-frame JPEG thumbnails. This does not enable a server-side video conversion pipeline.

## Source and authenticity

The official [FFmpeg download page](https://ffmpeg.org/download.html) lists source release 9.0.2 as the current 9.0 point release (released 2026-09-18), and provides the xz source archive and PGP signature. Its release verification section publishes fingerprint `FCF986EA15E6E293A5644F10B4322F04D67658D8` for the FFmpeg release signing key. The source archive URL is `https://ffmpeg.org/releases/ffmpeg-9.0.2.tar.xz`; its verified SHA-256 is:

```text
8c3850283eb25fa026482078a04051e0be17347b09ef81a0849bec15a96e002e
```

The key was downloaded from [ffmpeg.org/ffmpeg-devel.asc](https://ffmpeg.org/ffmpeg-devel.asc), and the detached signature from [ffmpeg.org/releases/ffmpeg-9.0.2.tar.xz.asc](https://ffmpeg.org/releases/ffmpeg-9.0.2.tar.xz.asc). The fingerprint matched the value published on the download page, and `gpg --verify` reported a good RSA signature using that key. GnuPG marked the UID untrusted in the local keyring; the signer fingerprint was checked independently against the official FFmpeg page. The Docker build repeats source SHA checking and signature verification with `gpgv` before extraction.

## Build artifact and license

Reusable build stage: [`infra/media/ffmpeg.Dockerfile`](/home/hassan/projects/BrianiPlayer/infra/media/ffmpeg.Dockerfile). It uses the repository’s pinned .NET SDK image as the build environment and copies the resulting `/opt/briani-media` tree into the pinned ASP.NET runtime image for an execution check. The successful build command was:

```text
docker --config .tools/docker-config buildx build --load --progress=plain -t briani-media:9.0.2 -f infra/media/ffmpeg.Dockerfile --build-arg JOBS=2 .
```

Exit status: 0. The final local image was Linux/amd64, image ID `sha256:96ae656c90a9c4a1afd600bae658b51647f5e483e7cedb9cabbdb3513b4f6ec0`. It is a local verification image, not a production image. SDK and runtime base references were the exact digests already recorded in `toolchain.lock.json` (`e70cdb7f…` and `222759b3…`). The resolved build-tool package versions were recorded inside the image and pinned in the Dockerfile:

| Package | Version |
|---|---|
| build-essential | 12.10ubuntu1 |
| ca-certificates | 20260601~24.04.1 |
| curl | 8.5.0-2ubuntu10.15 |
| gpg | 2.4.4-2ubuntu17.6 |
| nasm | 2.16.01-1build1 |
| pkg-config | 1.8.1-2build1 |
| xz-utils | 5.6.1+really5.4.5-1ubuntu0.3 |
| zlib1g-dev | 1:1.3.dfsg-3.1ubuntu2.2 |

The exact build command, version output, source SHA file, and package list are in the image under `/opt/briani-media/share/ffmpeg/`. Configure reported `License: LGPL version 2.1 or later`; GPL, version-3, and nonfree components are disabled. The staged files include FFmpeg’s `LICENSE.md` and `COPYING.LGPLv2.1`. This is the license reported by this configuration, not a blanket license conclusion for other FFmpeg configurations.

## Selected functionality

The configure profile disables network protocols, autodetection, shared libraries, AVDevice, docs, debugging, GPL, version-3, and nonfree code. It enables the `file` and `pipe` protocols; MOV/MP4, Matroska/WebM, AVI, MPEG program/transport/elementary streams, Ogg and JPEG/PNG/WebP/GIF image demuxers; H.264, HEVC, MPEG-4 Part 2, MJPEG, PNG, WebP, and GIF decoders; the MJPEG encoder and image2 muxer; and `scale`, `transpose`, and `format` filters. PNG support requires zlib, which is explicitly enabled. FFprobe can report stream/container metadata without requiring an enabled decoder for every reported codec; unsupported codec decoding must remain an ordinary probe result and not be treated as a reason to invent codec details.

Integration recipe: copy the `ffmpeg-build` stage into the shared server Dockerfile and add `COPY --from=ffmpeg-build /out/opt/briani-media /opt/briani-media` to the final runtime stage. Keep application code responsible for configured process timeouts, output-size bounds, thread limits, and input authorization. FFmpeg use should remain bounded FFprobe metadata work or a one-frame thumbnail operation; the profile contains no network protocol, HLS muxer, server streaming, or full-video conversion path. A plain FFmpeg process must not be used to serve incomplete torrent bytes.

## Smoke checks

Synthetic input creation used the host FFmpeg only to generate temporary fixtures under `/tmp/briani-media-fixtures/`; no repository fixture was changed. Video: a 3-second 320x180 H.264/AAC MP4, SHA-256 `37e57db13fcd6a1b55777f7eaf2e43861b89bbdbf6d9964e8f3b5892424a7e55`. Photos were locally generated JPEG, PNG, WebP, and GIF inputs; their hashes are preserved in the generation command’s environment at `/tmp/briani-media-fixtures/`.

The built image was mounted read-only for inputs and wrote only to `/tmp/briani-media-output/`. The smoke command ran FFprobe on the MP4 and all four photo formats, wrote one scaled/rotated JPEG frame from the MP4, and wrote a scaled JPEG thumbnail from each photo. It exited 0 and printed `ALL_IMAGE_AND_VIDEO_SMOKES_PASSED`:

```text
docker --config .tools/docker-config run --rm -v /tmp/briani-media-fixtures:/fixtures:ro -v /tmp/briani-media-output:/out briani-media:9.0.2 /bin/sh -ec 'set -eu; tools=/opt/briani-media/bin; "$tools/ffprobe" -v error -show_entries format=format_name,duration:stream=codec_type,codec_name -of json /fixtures/synthetic.mp4 > /out/video-metadata.json; "$tools/ffmpeg" -v error -threads 1 -i /fixtures/synthetic.mp4 -map 0:v:0 -frames:v 1 -vf scale=64:-2,transpose=clock -c:v mjpeg -f image2 -update 1 /out/video-thumb.jpg; for ext in jpg png webp gif; do "$tools/ffprobe" -v error -show_entries format=format_name:stream=codec_type,codec_name -of json "/fixtures/photo.$ext" > "/out/$ext-metadata.json"; "$tools/ffmpeg" -v error -threads 1 -i "/fixtures/photo.$ext" -frames:v 1 -vf scale=32:-2 -c:v mjpeg -f image2 -update 1 "/out/from-$ext.jpg"; test -s "/out/from-$ext.jpg"; done; test -s /out/video-thumb.jpg; cat /out/video-metadata.json; echo ALL_IMAGE_AND_VIDEO_SMOKES_PASSED'
```

FFprobe reported `h264` video and `aac` audio for the MP4. Compiled versions were `ffmpeg version 9.0.2` and `ffprobe version 9.0.2`. Outputs were non-empty: video thumbnail 1,576 bytes; photo thumbnails 707–1,188 bytes. The recorded thumbnail and metadata files are under `/tmp/briani-media-output/`. Photo fixture SHA-256 values: JPEG `58e4dfdb9b980ae2607629f292206f1d4cb605b322e7d4c29030e7a89039ebb2`; PNG `9f170e6034742ea1bfbdc9dac2ced515011c0ccfffea128d9363fb0b517c1660`; WebP `1bdf2017e40a81e9954c0e98502fe81d56691a2a405670ab3a99f283cb12efaa`; GIF `6e7a69f96608b1090759895f25e32e2299c6dd9ab09fd10b983fe6b6870f3c50`.

## Platform and verification limits

Only an amd64 image build was executed. The Dockerfile is parameterized for the existing SDK/runtime references, but no ARM64 build or Raspberry Pi 5 test was performed. No throughput or memory benchmark was run. The smoke checks establish expected demux/probe/decode/thumbnail paths for generated fixtures only; they do not certify every codec, malformed-media safety, concurrency, process sandboxing, or production timeout policy. The parent’s M03 implementation must apply those controls and must not claim full transcoding support.
