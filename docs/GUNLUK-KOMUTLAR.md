# Günlük komutlar — FLOP Miner / Windows 11 / WSL

> Bütün komutlar **Ubuntu terminalinde** çalışır; yalnızca Windows PowerShell olarak belirtilenler farklıdır. Docker Desktop **Windows'ta Running** olmalıdır.

## Windows yeniden açıldığında (en kısa yol)

1. Windows'ta **Docker Desktop** uygulamasını açın ve `Running` olduğundan emin olun.
2. **Ubuntu 22.04** terminalini açın.
3. Şunları sırayla çalıştırın:

```bash
cd /opt/flop-miner
sudo systemctl start flop-tunnel
sudo systemctl start flop-fence-guard.timer
sudo systemctl start flop-tunnel-watch.timer
docker compose --env-file miner.env -f docker-compose.yml up -d
docker compose --env-file miner.env -f docker-compose.yml ps
```

Cloudflare Quick Tunnel yeniden açılırken **URL değişmiş olabilir**. Tunnel Watch'ın değişikliği algılaması için zamanlayıcının aktif olması yeterli; worker adresi otomatik güncellenebilir. Kendi env'inizdeki adresi kontrol edin:

```bash
grep '^SESSION_PUBLIC_HOST=' /opt/flop-miner/miner.env
systemctl list-timers flop-tunnel-watch.timer --no-pager
```

## Miner çalışıyor mu?

```bash
cd /opt/flop-miner
docker compose --env-file miner.env -f docker-compose.yml ps
docker compose --env-file miner.env -f docker-compose.yml logs --since=5m --tail=60 worker
```

Beklenen: backend + worker `Up`, `Session host listening on :8645`, `model-gate OK`, `Endpoint ad (...) published`.

## Worker kilitli mi?

```bash
cd /opt/flop-miner/fence-guard
docker compose --env-file ../miner.env -f ../docker-compose.yml \
  exec -T worker node --input-type=module < status.mjs | jq '{fenced,ready}'
```

Beklenen `false/true`. Gerçek bir `fenced: true` durumunda **kilit dosyasını elle silmeyin**.

## Bilgisayar açıldı, miner çalışıyor ama ödeme yok (14.11.2026)

**Gerçek vakamız:** Docker ve Cloudflare ayaktaydı, fakat worker'ın kanıt yüklemesi `da.register failed` ile takıldı ve `/session/info-proof` üzerinden `ready: false` döndü. Süresi dolmuş kanal zincirde `computeChannel.TimedOutRefunded` ile kapatıldıktan ve worker yeniden başlatıldıktan sonra `ready: true` doğrulandı. **Bu, tek başına yeni ödeme geldiğini kanıtlamaz.**

**İlk kontrol:** `docker compose ... ps`, `fence-guard/status.mjs` ve **POST** `/session/info-proof` ile durumu doğrulayın. `ready: null` belirsizdir; dışarıdan `401` yalnızca erişimin çalıştığını gösterir. `fenced: true` iken güvenlik kilidini elle silmeyin veya imzalı işlem başlatmayın.

**Adım adım güvenli düzeltme, hazır komutlar ve dikkat edilmesi gerekenler:**
[14 Kasım 2026 — restart sonrası `ready: false` / takılı kanal](HATALAR-VE-COZUMLER.md) başlığını açın. **Süresi dolmamış kanala `--send` göndermeyin**; kapatma ücretlidir ve escrow alıcıya iade edilir. `ready: true` sonrasında gerçek ödemeyi ayrıca Explorer'da `computeChannel.settle` ile kontrol edin.

## Kalibrasyon / Ghost işlerini izle

```bash
cd /opt/flop-miner
docker compose --env-file miner.env -f docker-compose.yml \
  logs -f worker | grep --line-buffered -Ei 'answered task|calibrat|capacity rate|error'
```

Logdan `Ctrl+C` ile çıkmak worker'ı durdurmaz.

## Oturum ve ödemeler

```bash
cd /opt/flop-miner
docker compose --env-file miner.env -f docker-compose.yml \
  logs --since=1h worker \
  | grep -Ei '\[session\]|settle cooperative|payment|error' | tail -40
```

`Session chain settle enabled` sadece mekanizmanın açık olduğu anlamına gelir; **ödeme yapıldığı** anlamına gelmez. Ücretli oturumlarda `[session] settle cooperative` ve Explorer kaydını doğrulayın.

## GPU'yu izle

```bash
nvidia-smi || /usr/lib/wsl/lib/nvidia-smi
```

## HTTPS tünel testi

```bash
H=$(grep '^SESSION_PUBLIC_HOST=' /opt/flop-miner/miner.env | cut -d= -f2-)
curl -sS --max-time 15 -o /dev/null -w '%{http_code}\n' "https://$H/session/info"
```

Beklenen `401` (**olumlu**, yetkisiz istek reddedildi). `502` / timeout ise worker ve tüneli kontrol edin.

## Servis zamanlayıcılarını incele

```bash
systemctl list-timers flop-fence-guard.timer flop-tunnel-watch.timer --no-pager
sudo journalctl -u flop-tunnel-watch -o cat --no-pager | tail -20
sudo journalctl -u flop-tunnel --no-pager | tail -20
```

## Miner zincir kalibrasyonu

`MINER_ADDRESS` değişkenini kendi **halka açık** adresinizle doldurun:

```bash
read -r -p 'Miner adresi (5...): ' MINER_ADDRESS
FLOP_CLI=$(grep '^FLOP_CLI=' /opt/flop-miner/miner.env | cut -d= -f2-)
docker run --rm --network host "$FLOP_CLI" \
  --network devnet --rpc wss://rpc.devnet.flop.network \
  miner status "$MINER_ADDRESS" --json \
  | jq '{registered,stake,calibration,attested_gpu_inventory}'
```

`RPC_UNREACHABLE` kısa süreli ağ kesintisi olabilir; miner cüzdanını yeniden oluşturmayın.

## Performans yaması hâlâ aktif mi?

```bash
cd /opt/flop-miner
sha256sum patches/miner-worker.mjs
docker compose --env-file miner.env -f docker-compose.yml \
  exec -T worker sha256sum /repo/sdk/miner-worker/miner-worker.mjs
```

İki hash **aynı** olmalı.

## Logları nasıl durdururum?

`Ctrl+C` yalnızca **log izleme komutunu** durdurur. Miner çalışmayı sürdürür. **Kullanmayın:** `docker compose down -v` (kalıcı verileri siler).

## Kaynaklar

- [Tam kurulum](../README.md)
- [Hatalar ve çözümler](HATALAR-VE-COZUMLER.md)
- [FLOP Explorer](https://explorer.devnet.flop.network/mining)
