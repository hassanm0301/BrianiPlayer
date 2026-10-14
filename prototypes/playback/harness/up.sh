#!/bin/sh
set -eu
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
project=briani-m00-harness
state="$here/state"
credentials="$state/credentials.json"
swarm=0
if [ "${1-}" = "--swarm" ] && [ "$#" -eq 1 ]; then
  swarm=1
elif [ "$#" -ne 0 ]; then
  echo "Usage: $0 [--swarm]" >&2
  exit 2
fi
require_digest() {
  name=$1
  eval "ref=\${$name-}"
  case "$ref" in
    *@sha256:*) ;;
    *) echo "$name must be an immutable image reference ending @sha256:<64 hex digits>" >&2; exit 2 ;;
  esac
  digest=${ref##*@sha256:}
  [ "${#digest}" -eq 64 ] || { echo "$name digest must contain 64 hexadecimal digits" >&2; exit 2; }
  case "$digest" in *[!0-9a-fA-F]*) echo "$name digest must be hexadecimal" >&2; exit 2;; esac
}
require_digest QB_IMAGE
mkdir -p "$state/data"
files="-f $here/compose.yaml"
if [ "$swarm" -eq 1 ]; then
  files="$files -f $here/compose.swarm.yaml"
fi
# The positional file arguments are fixed paths assembled above; image refs are
# only interpolated by Compose after digest validation.
# shellcheck disable=SC2086
docker compose --project-name "$project" --project-directory "$here" $files up -d
set -- "$project-qbittorrent-1" "$credentials"
if [ "$swarm" -eq 1 ]; then
  set -- "$@" "$project-seeder-1" "$state/seeder-credentials.json"
fi
python3 - "$@" <<'PY'
import json, os, re, subprocess, sys, time
args = iter(sys.argv[1:])
services = list(zip(args, args))
pattern = re.compile(r"temporary password is provided for this session:\s*(\S+)", re.I)
for container, path in services:
    for _ in range(40):
        result = subprocess.run(["docker", "logs", container], text=True, capture_output=True, check=False)
        logs = result.stdout + result.stderr
        matches = list(pattern.finditer(logs))
        if matches:
            data = json.dumps({"username": "admin", "password": matches[-1].group(1)}, indent=2) + "\n"
            tmp = path + ".tmp"
            fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
            with os.fdopen(fd, "w", encoding="utf-8") as f:
                f.write(data)
            os.replace(tmp, path)
            os.chmod(path, 0o600)
            break
        if "Connection to localhost (::1) 8080 port [tcp/http-alt] succeeded!" in logs and os.path.isfile(path):
            break
        time.sleep(1)
    else:
        raise SystemExit(f"{container} did not emit a temporary API credential within 40 seconds")
PY
python3 - "$project-qbittorrent-1" "$state/endpoints.json" "$swarm" <<'PY'
import json, os, subprocess, sys
downloader, path, with_seeder = sys.argv[1:]
services = [("qbittorrent", downloader, 18081)]
if with_seeder == "1":
    services.append(("seeder", downloader.replace("-qbittorrent-1", "-seeder-1"), None))
endpoints = {}
for name, container, published in services:
    info = json.loads(subprocess.check_output(["docker", "inspect", container], text=True))[0]
    networks = info["NetworkSettings"]["Networks"]
    ip = next((network["IPAddress"] for network in networks.values() if network.get("IPAddress")), None)
    if not ip:
        raise SystemExit(f"{container} has no harness network address")
    endpoints[name] = {"service": name, "bridgeIp": ip, "apiPort": 8080,
                       "apiBase": f"http://{ip}:8080"}
    if published is not None:
        endpoints[name]["loopbackPublishedBase"] = f"http://127.0.0.1:{published}"
tmp = path + ".tmp"
with open(tmp, "w", encoding="utf-8") as stream:
    json.dump(endpoints, stream, indent=2, sort_keys=True)
    stream.write("\n")
os.replace(tmp, path)
PY
if [ "$swarm" -eq 1 ]; then
  for service in "$project-qbittorrent-1" "$project-seeder-1"; do
    ip=$(docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$service")
    cred="$credentials"
    [ "$service" = "$project-seeder-1" ] && cred="$state/seeder-credentials.json"
    python3 "$here/private_network.py" --url "http://$ip:8080" --credentials "$cred"
  done
else
  ip=$(docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$project-qbittorrent-1")
  python3 "$here/private_network.py" --url "http://$ip:8080" --credentials "$credentials"
fi
