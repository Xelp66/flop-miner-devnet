#!/usr/bin/env bash
# Read-only health checks. Does not dump keys, .env contents, or passwords.
set -u
DIR=/opt/flop-miner
ENV="$DIR/miner.env"
COMPOSE="$DIR/docker-compose.yml"

printf '\n=== FLOP WSL Doctor (salt okunur) ===\n'
if [ -f /proc/sys/kernel/osrelease ] && grep -qi microsoft /proc/sys/kernel/osrelease; then
  echo '[OK] WSL kernel tespit edildi'
else
  echo '[INFO] WSL tespit edilemedi (normal Linux olabilir)'
fi
printf 'PID 1: '
ps -p 1 -o comm= 2>/dev/null || true

if command -v nvidia-smi >/dev/null 2>&1; then
  nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader 2>&1 || true
elif [ -x /usr/lib/wsl/lib/nvidia-smi ]; then
  /usr/lib/wsl/lib/nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader 2>&1 || true
else
  echo '[UYARI] nvidia-smi yok; Windows NVIDIA sürücüsünü kontrol edin'
fi

if ! command -v docker >/dev/null 2>&1; then
  echo '[HATA] Docker CLI yok. Windows Docker Desktop / WSL Integration kontrol edin.'
  exit 1
fi
if ! docker info >/dev/null 2>&1; then
  echo '[HATA] Docker daemon erişilemiyor. Docker Desktop Running olmalı.'
  exit 1
fi
echo '[OK] Docker daemon erişilebilir'

if [ ! -f "$ENV" ] || [ ! -f "$COMPOSE" ]; then
  echo '[HATA] /opt/flop-miner/miner.env veya docker-compose.yml yok'
  exit 1
fi
C=(docker compose --env-file "$ENV" -f "$COMPOSE")
printf '\n=== Docker Compose ===\n'
"${C[@]}" ps

printf '\n=== systemd servis/timer durumları ===\n'
for unit in flop-tunnel.service flop-fence-guard.timer flop-tunnel-watch.timer; do
  printf '%-30s ' "$unit"
  systemctl is-active "$unit" 2>/dev/null || true
done

H=$(sed -n 's/^SESSION_PUBLIC_HOST=//p' "$ENV" | head -1)
if [[ "$H" =~ ^[a-z0-9.-]+$ ]] && [ -n "$H" ]; then
  printf '\nDuyurulan public host: %s\n' "$H"
  printf 'HTTPS /session/info (401 beklenir): '
  curl -sS --max-time 12 -o /dev/null -w '%{http_code}\n' "https://$H/session/info" || true
else
  echo '[UYARI] SESSION_PUBLIC_HOST boş/geçersiz'
fi

printf '\n=== Son 5 dakika (özel anahtar/log içeriği basılmadan olay özeti) ===\n'
"${C[@]}" logs --since=5m worker 2>/dev/null \
  | grep -Ei 'model-gate OK|Session host listening|Endpoint ad|capacity rate|cap accepted|Fatal:|fenced|settle cooperative' \
  | tail -20 || true

printf '\n=== Fence durum kontrolü ===\n'
if [ -f "$DIR/fence-guard/status.mjs" ] && command -v jq >/dev/null 2>&1; then
  "${C[@]}" exec -T worker node --input-type=module < "$DIR/fence-guard/status.mjs" \
    | jq '{fenced,ready}' 2>/dev/null || echo '[UYARI] Fence status okunamıyor'
else
  echo '[INFO] Fence guard dosyası/jq henüz kurulu değil'
fi

printf '\n[SIRLAR] Bu script signer, seed, token veya env içeriği yazdırmaz.\n'
