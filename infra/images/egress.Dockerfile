FROM alpine@sha256:294b683cb724975bec92580e1e685676bd4b50bda910ddb8c51d4cabeaec77e6
RUN apk add --no-cache nftables=1.1.6-r1
COPY infra/network/egress.nft /etc/briani/egress.nft
COPY infra/network/guard.sh /guard.sh
HEALTHCHECK --interval=5s --timeout=3s --start-period=5s --retries=3 CMD ["/guard.sh", "verify"]
ENTRYPOINT ["/guard.sh"]
