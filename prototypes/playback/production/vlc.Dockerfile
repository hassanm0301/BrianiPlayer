FROM mcr.microsoft.com/dotnet/aspnet@sha256:222759b391a1aaf241166672c8f99b2d4ada452e7b5319f3c6e8f265a37b5ad4

ENV DEBIAN_FRONTEND=noninteractive \
    HOME=/tmp

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        python3 \
        python3-vlc \
        vlc-bin \
        vlc-plugin-base \
        vlc-plugin-video-output \
    && dpkg-query -W -f='${binary:Package}=${Version}\n' \
        python3 python3-vlc vlc-bin vlc-plugin-base vlc-plugin-video-output libvlc5 \
        > /usr/share/vlc-proof-packages.txt \
    && rm -rf /var/lib/apt/lists/*

COPY vlc_probe.py /opt/vlc_probe.py
RUN chmod 0555 /opt/vlc_probe.py

USER 1000:1000
ENTRYPOINT ["python3", "/opt/vlc_probe.py", "--container-probe"]
