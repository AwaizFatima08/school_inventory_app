#!/usr/bin/env bash
# Publish site/dist to school-supplies.homilabs.org (Hostinger) over SSH/rsync.
#
#   flutter build web --release --base-href /app/ --no-web-resources-cdn --pwa-strategy=none
#   python3 site/build.py
#   site/deploy.sh
#
# Uses this machine's SSH key (hPanel → Advanced → SSH Access). No passwords here.
set -euo pipefail
cd "$(dirname "$0")"

HOSTINGER_SSH="${HOSTINGER_SSH:-u809141334@145.79.26.208}"
HOSTINGER_PORT="${HOSTINGER_PORT:-65002}"
HOSTINGER_DIR="${HOSTINGER_DIR:-domains/homilabs.org/public_html/school-supplies}"

[ -f dist/index.html ] || { echo "dist/ missing: run python3 site/build.py"; exit 1; }
if [ -d dist/app ] && grep -q '127\.0\.0\.1' dist/app/main.dart.js; then
  echo "Refusing to deploy: dist/app is an emulator build"; exit 1
fi

rsync -avz --delete -e "ssh -p ${HOSTINGER_PORT}" dist/ "${HOSTINGER_SSH}:${HOSTINGER_DIR}/"
echo "Deployed. Check https://school-supplies.homilabs.org/"
