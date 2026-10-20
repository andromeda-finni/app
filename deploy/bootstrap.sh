#!/usr/bin/env bash
# One-time server preparation for groshiktheapp.ru. Run as root:
#
#   ssh root@groshiktheapp.ru 'bash -s -- "<deploy public key>"' < deploy/bootstrap.sh
#
# Installs Docker from Ubuntu's own packages (docker.com may be unreachable),
# creates the "deploy" user that GitHub Actions logs in as, prepares
# /opt/groshik with a .env of random database passwords, and opens only
# SSH, HTTP and HTTPS in the firewall. Safe to run again.
set -euo pipefail

DEPLOY_KEY="${1:?pass the deploy public key as the first argument}"
APP_DIR=/opt/groshik
DOMAIN=groshiktheapp.ru

export DEBIAN_FRONTEND=noninteractive
apt-get update -q
apt-get install -y -q ufw openssl curl
# Keep an existing Docker (e.g. docker-ce from Docker's own repository, whose
# containerd.io conflicts with Ubuntu's docker.io); install one only if absent.
if ! command -v docker >/dev/null 2>&1; then
  apt-get install -y -q docker.io
  apt-get install -y -q docker-compose-v2 || true
fi
systemctl enable --now docker
docker --version

# Ubuntu 20.04 may lack the docker-compose-v2 package: fall back to the
# official plugin binary from GitHub Releases.
if ! docker compose version >/dev/null 2>&1; then
  install -d /usr/local/lib/docker/cli-plugins
  curl -fsSL -o /usr/local/lib/docker/cli-plugins/docker-compose \
    "https://github.com/docker/compose/releases/download/v2.29.7/docker-compose-linux-$(uname -m)"
  chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
fi
docker compose version

if ! id deploy >/dev/null 2>&1; then
  useradd --create-home --shell /bin/bash deploy
fi
usermod -aG docker deploy
install -d -m 700 -o deploy -g deploy /home/deploy/.ssh
touch /home/deploy/.ssh/authorized_keys
grep -qxF "$DEPLOY_KEY" /home/deploy/.ssh/authorized_keys ||
  echo "$DEPLOY_KEY" >> /home/deploy/.ssh/authorized_keys
chown deploy:deploy /home/deploy/.ssh/authorized_keys
chmod 600 /home/deploy/.ssh/authorized_keys

install -d -m 750 -o deploy -g deploy "$APP_DIR"
# The TLS certificate (fullchain.pem, privkey.pem) is copied here by hand.
install -d -m 750 -o deploy -g deploy "$APP_DIR/certs"
if [ ! -f "$APP_DIR/.env" ]; then
  umask 077
  cat > "$APP_DIR/.env" <<ENV
API_DOMAIN=$DOMAIN
POSTGRES_ADMIN_PASSWORD=$(openssl rand -hex 24)
GROSHIK_APP_PASSWORD=$(openssl rand -hex 24)
CORS_ORIGINS=
ENV
  chown deploy:deploy "$APP_DIR/.env"
fi

ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 443/udp
ufw --force enable

echo "Server is ready. The first GitHub deploy will start the stack in $APP_DIR."
