#!/usr/bin/env bash
# After Windows login, start Docker Desktop GUI first, then open WSL Ubuntu and run this script.
set -euo pipefail
DIR=/opt/flop-miner

if [ ! -f "$DIR/miner.env" ] || [ ! -f "$DIR/docker-compose.yml" ]; then
  echo 'FLOP kurulumu /opt/flop-miner altında bulunamadı.' >&2
  exit 1
fi
if ! docker info >/dev/null 2>&1; then
  echo 'Docker Desktop Windows üzerinde Running olmalı; WSL integration açık mı?' >&2
  exit 1
fi

sudo systemctl start flop-tunnel.service
sudo systemctl start flop-fence-guard.timer
sudo systemctl start flop-tunnel-watch.timer

docker compose --env-file "$DIR/miner.env" -f "$DIR/docker-compose.yml" up -d
docker compose --env-file "$DIR/miner.env" -f "$DIR/docker-compose.yml" ps
printf '\nNot: Quick Tunnel URL değişmişse Tunnel Watch güncelleyecektir.\n'
