#!/bin/sh
set -eu

project='briani-m00-harness'
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

if [ "${1-}" != "--confirm-project=$project" ]; then
  echo "Refusing cleanup. Run: $0 --confirm-project=$project" >&2
  exit 2
fi
if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required" >&2
  exit 2
fi
# Explicit project and file prevent Compose from resolving a caller's project.
docker compose --project-name "$project" --project-directory "$here" \
  -f "$here/compose.yaml" -f "$here/compose.swarm.yaml" down --volumes --remove-orphans
rm -f "$here/state/credentials.json" "$here/state/seeder-credentials.json" \
  "$here/state/runtime-report.json" "$here/state/endpoints.json" \
  "$here/state/credentials.json.tmp" "$here/state/seeder-credentials.json.tmp" \
  "$here/state/endpoints.json.tmp"
if [ -d "$here/state/data" ]; then
  find "$here/state/data" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
fi
