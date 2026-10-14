# Reusable media-tools stage. Integrate by copying this stage into the server
# Dockerfile, then COPY --from=ffmpeg-build /out/opt/briani-media /opt/briani-media.
ARG SDK_IMAGE=mcr.microsoft.com/dotnet/sdk@sha256:e70cdb7f80b0348f5cb85f19a8f670fca061f033d57eed12fa003d58b0e06317
ARG RUNTIME_IMAGE=mcr.microsoft.com/dotnet/aspnet@sha256:222759b391a1aaf241166672c8f99b2d4ada452e7b5319f3c6e8f265a37b5ad4

FROM ${SDK_IMAGE} AS ffmpeg-build
ARG FFMPEG_VERSION=9.0.2
ARG FFMPEG_SHA256=8c3850283eb25fa026482078a04051e0be17347b09ef81a0849bec15a96e002e
ARG JOBS=2
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential=12.10ubuntu1 ca-certificates=20260601~24.04.1 \
    curl=8.5.0-2ubuntu10.15 gpg=2.4.4-2ubuntu17.6 nasm=2.16.01-1build1 \
    pkg-config=1.8.1-2build1 xz-utils=5.6.1+really5.4.5-1ubuntu0.3 \
    zlib1g-dev=1:1.3.dfsg-3.1ubuntu2.2 \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /tmp/ffmpeg-build
RUN set -eux; \
    curl --fail --location --retry 3 --output ffmpeg.tar.xz "https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.xz"; \
    curl --fail --location --retry 3 --output ffmpeg.tar.xz.asc "https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.xz.asc"; \
    curl --fail --location --retry 3 --output ffmpeg-devel.asc https://ffmpeg.org/ffmpeg-devel.asc; \
    actual="$(sha256sum ffmpeg.tar.xz | cut -d' ' -f1)"; \
    test -n "${FFMPEG_SHA256}" && test "$actual" = "${FFMPEG_SHA256}"; \
    fingerprint="$(gpg --show-keys --with-colons ffmpeg-devel.asc | awk -F: '$1 == "fpr" {print $10; exit}')"; \
    test "$fingerprint" = "FCF986EA15E6E293A5644F10B4322F04D67658D8"; \
    gpg --batch --dearmor --output ffmpeg-keyring.gpg ffmpeg-devel.asc; \
    gpgv --keyring ./ffmpeg-keyring.gpg ffmpeg.tar.xz.asc ffmpeg.tar.xz; \
    mkdir source && tar -xJf ffmpeg.tar.xz --strip-components=1 -C source
WORKDIR /tmp/ffmpeg-build/source
RUN set -eux; \
    ./configure \
      --prefix=/opt/briani-media --bindir=/opt/briani-media/bin --libdir=/opt/briani-media/lib \
      --disable-gpl --disable-version3 --disable-nonfree --disable-autodetect \
      --disable-doc --disable-debug --disable-network --disable-avdevice \
      --disable-shared --enable-static --enable-small --enable-zlib \
      --disable-everything --enable-ffmpeg --enable-ffprobe \
      --enable-avcodec --enable-avformat --enable-avfilter --enable-swscale --enable-avutil \
      --enable-protocol=file,pipe \
      --enable-demuxer=mov,matroska,avi,mpegps,mpegts,mpegvideo,ogg,image2,image2pipe,image_jpeg_pipe,image_png_pipe,image_webp_pipe,image_gif_pipe,gif \
      --enable-muxer=image2,image2pipe \
      --enable-decoder=h264,hevc,mpeg4,mjpeg,png,webp,gif \
      --enable-encoder=mjpeg \
      --enable-parser=h264,hevc,mpeg4video,mjpeg,png,webp,gif,aac,ac3,flac,opus,vorbis \
      --enable-filter=scale,transpose,format,hflip,vflip \
      --extra-cflags=-fstack-protector-strong --extra-ldflags=-Wl,-z,relro,-z,now; \
    make -j"${JOBS}"; \
    make DESTDIR=/out install; \
    install -D LICENSE.md /out/opt/briani-media/share/ffmpeg/LICENSE.md; \
    install -D COPYING.LGPLv2.1 /out/opt/briani-media/share/ffmpeg/COPYING.LGPLv2.1; \
    cp ffbuild/config.log /out/opt/briani-media/share/ffmpeg/config.log; \
    dpkg-query -W -f='${binary:Package}=${Version}\n' build-essential ca-certificates curl gpg nasm pkg-config xz-utils zlib1g-dev > /out/opt/briani-media/share/ffmpeg/build-packages.txt; \
    printf '%s  ffmpeg-%s.tar.xz\n' "${FFMPEG_SHA256}" "${FFMPEG_VERSION}" > /out/opt/briani-media/share/ffmpeg/source.sha256

FROM ${RUNTIME_IMAGE} AS ffmpeg-runtime-check
COPY --from=ffmpeg-build /out/opt/briani-media /opt/briani-media
RUN /opt/briani-media/bin/ffmpeg -version && /opt/briani-media/bin/ffprobe -version
