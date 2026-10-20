#!/usr/bin/env bash
# Runs on the server from /opt/groshik after GitHub Actions has copied the
# new backend image, this folder and db/ there. Usage: deploy.sh <image tag>
set -euo pipefail

TAG="${1:?pass the image tag}"
cd "$(dirname "$0")"

if [ ! -s certs/fullchain.pem ] || [ ! -s certs/privkey.pem ]; then
  echo "TLS certificate is missing: put fullchain.pem and privkey.pem into $(pwd)/certs" >&2
  exit 1
fi
IMAGE="groshik-backend:$TAG"

gunzip -c backend-image.tar.gz | docker load
rm -f backend-image.tar.gz

# Remember which image is live, so a plain `docker compose up -d` after a
# server reboot starts the same version.
if grep -q '^BACKEND_IMAGE=' .env; then
  sed -i "s|^BACKEND_IMAGE=.*|BACKEND_IMAGE=$IMAGE|" .env
else
  echo "BACKEND_IMAGE=$IMAGE" >> .env
fi

docker compose up -d db
docker compose --profile tools run --rm migrate
docker compose up -d --remove-orphans backend caddy

for attempt in $(seq 1 30); do
  if docker compose exec -T backend wget -qO- http://127.0.0.1:3000/health \
      | grep -q '"ok":true'; then
    echo "Backend $IMAGE is healthy."
    # Keep the live image and the previous one for a quick rollback.
    docker images groshik-backend --format '{{.Repository}}:{{.Tag}}' \
      | grep -vx "$IMAGE" | tail -n +2 | xargs -r docker rmi >/dev/null || true
    exit 0
  fi
  sleep 2
done

echo "Backend did not become healthy:" >&2
docker compose logs --tail=80 backend >&2
exit 1
