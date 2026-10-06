#!/usr/bin/env bash
# Runs the plugin tests in Yaegi against the sources shipped in $IMAGE_REF.
set -euo pipefail

# Keep in step with the yaegi version in the go.mod of the Traefik release in use
# renovate: depName=github.com/traefik/yaegi datasource=go
YAEGI_VERSION="v0.16.1"

: "${IMAGE_REF:?IMAGE_REF must name the image to test}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work="$(mktemp -d)"
container=""
cleanup() {
  if [[ -n "$container" ]]; then
    docker rm "$container" >/dev/null
  fi
  rm -rf "$work"
}
trap cleanup EXIT

# The image is FROM scratch with no command, so create needs a placeholder one.
container="$(docker create "$IMAGE_REF" none)"
mkdir "$work/image"
docker cp "$container:/" - | tar -x -C "$work/image"

for f in .traefik.yml go.mod plugin.go LICENSE; do
  if [[ ! -f "$work/image/$f" ]]; then
    echo "::error::$f is missing from $IMAGE_REF"
    exit 1
  fi
done

cp "$REPO_ROOT"/*_test.go "$work/image/"
cd "$work/image"
go run "github.com/traefik/yaegi/cmd/yaegi@${YAEGI_VERSION}" test -v .
