#!/bin/sh
set -eu
if [ "${1:-}" = verify ]; then
  nft list chain inet briani_egress output | grep -q 'hook output priority mangle; policy drop;'
  exit
fi
# Replacing our table in one nft transaction leaves no unfiltered window. Other
# tables and the host namespace are never flushed or altered.
if nft list table inet briani_egress >/dev/null 2>&1; then
  { echo 'delete table inet briani_egress'; cat /etc/briani/egress.nft; } | nft -f -
else
  nft -f /etc/briani/egress.nft
fi
/guard.sh verify
exec sleep infinity
