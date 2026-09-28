#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

: "${APP_IMAGE:?Set APP_IMAGE to the full registry image reference first}"

test -f app.env || {
  echo "Missing app.env"
  exit 1
}

sudo docker pull "$APP_IMAGE"

# Pass APP_IMAGE explicitly because sudo may remove shell variables.
sudo env APP_IMAGE="$APP_IMAGE" \
  docker stack deploy \
    --with-registry-auth \
    --resolve-image always \
    --compose-file stack.yml \
    patchwork

sudo docker stack services patchwork
