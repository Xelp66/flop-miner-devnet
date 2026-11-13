# FLOP Devnet GPU Miner — Windows 11 + WSL2 + Ubuntu | Sıfırdan Türkçe Kurulum

> **Sürüm:** 13 Kasım 2026'da tamamlanan gerçek bir kurulumdan hazırlanmıştır.  
> **Hedef:** Kendi Windows bilgisayarında, NVIDIA GPU ile, WSL Ubuntu üzerinde FLOP Devnet miner çalıştırmak. **Vast.ai / uzak sunucu kullanılmaz.**  
> **Gerçek test:** Windows 11, Ubuntu 22.04.5 / WSL2, RTX 5070 sınıfı 12 GB NVIDIA GPU, Docker Desktop, worker `v0.1.336`, backend `v0.1.239`, CLI `v0.1.342`. **64 doğrulanmış iş / 700 blok / 181 GFLOP/s (Soft)** ile kalibrasyon başarıyla kabul edildi. Bu örnek kapasite diğer kartlar için garanti değildir.

Bu rehber, **Windows'a Ubuntu kurmamış** birinin başlayabileceği biçimde yazılmıştır. Her adımın altında beklenen sonuç, karşılaşılabilecek hatalar ve çözüm bağlantıları vardır. Kendi kurulumumuzdaki **gerçek hataların tamamı** [Hata ve Çözümler](docs/HATALAR-VE-COZUMLER.md) dosyasında ayrıca açıklanmıştır.

**Önce okuyun:** Bu bir **devnet/testnet** kurulumudur; test FLOP gerçek para/kazanç garantisi değildir. Sponsor, RPC, model ve image sürümleri her an değişebilir. Komutları çalıştırmadan önce açıklamalarını okuyun. Bu repo FLOP'un veya UfukNode'un resmî yayını değildir; özgün kurulum betiklerini [UfukNode/flop-miner-setup](https://github.com/UfukNode/flop-miner-setup) üzerinden indirir.

## İçindekiler

1. [Gereksinimler ve kurulum mimarisi](#0-gereksinimler-ve-kurulum-mimarisi)
2. [Windows: WSL2 ve Ubuntu](#1-windows-wsl2-ve-ubuntu)
3. [Windows: NVIDIA sürücüsü ve Docker Desktop](#2-windows-nvidia-sürücüsü-ve-docker-desktop)
4. [Ubuntu: sistem hazırlığı](#3-ubuntu-sistem-hazırlığı)
5. [FLOP dosyaları ve ayarlar](#4-flop-dosyaları-ve-ayarlar)
6. [Miner cüzdanı, güvenli anahtarlar, sponsor](#5-miner-cüzdanı-ve-güvenli-anahtarlar)
7. [Model indirme ve backend](#7-modeli-indirme-ve-zincirde-doğrulama)
8. [Cloudflare HTTPS tüneli ve worker](#9-cloudflare-https-tüneli)
9. [Kalibrasyon ve koruma sistemleri](#12-kalibrasyon)
10. [Performans yaması ve son kontrol](#15-worker-performans-yaması)
11. [Yeniden başlatma, günlük kullanım ve güvenlik](#yeniden-başlatma-ve-günlük-kullanım)

## 0. Gereksinimler ve kurulum mimarisi

- Windows 11, WSL2 çalıştırabilen BIOS/UEFI sanallaştırma ve güncel Windows Update.
- NVIDIA GPU, **Windows NVIDIA sürücüsü** (testimizde 591.97 / CUDA 13.1); üretici belgelerinde GPU/driver şartlarını güncel kontrol edin.
- WSL2 üzerinde **Ubuntu 22.04 LTS** (24.04 da çalışabilir ama bu belgede 22.04 test edildi).
- **Docker Desktop for Windows**, WSL2 engine ve Ubuntu WSL Integration açık. Aynı Ubuntu içine ayrıca Docker Engine kurmayın; iki kurulum çakışabilir.
- İnternete sürekli erişim; model/container indirmeleri büyüktür. En az ~60 GB boş alan planlayın; daha fazlası rahat ettirir. RAM ve disk ihtiyacı sisteme göre değişir.
- GPU belleği: kaynak rehberde 16 GB+ önerilir; biz **12 GB ile bu 0.5B modeli başlatabildik**. Diğer kartlarda/konfigürasyonlarda garanti değildir.
- Windows **uyku/hibernation** moduna girerse WSL miner çalışmaz. Kesintisiz çalışma için uygun güç ayarları gerekir.

```text
Windows 11
  ├─ NVIDIA Windows Driver (GPU-PV)
  ├─ Docker Desktop (WSL2 engine / Linux containers)
  └─ WSL2 / Ubuntu 22.04 + systemd
       ├─ FLOP backend (GPU, model inference)
       ├─ FLOP worker (signer, Ghost, sessions, settlement)
       ├─ Cloudflare Quick Tunnel → HTTPS → localhost:8645
       ├─ fence-guard.timer (güvenli kilit kontrolü)
       └─ tunnel-watch.timer (değişen tünel adresi)
```

> **Terminal ayrımı:** `powershell` komutları **Windows'ta Yönetici PowerShell**, `bash` komutları **Ubuntu / WSL terminali** içindir. `PS C:\>` ile `kullanici@bilgisayar:~$` istemlerini karıştırmayın.

## 1. Windows: WSL2 ve Ubuntu

**Windows PowerShell'i yönetici olarak açın:** Başlat > PowerShell > Sağ tık > Yönetici olarak çalıştır.

```powershell
wsl --install -d Ubuntu-22.04
wsl --update
```

Windows isterse **yeniden başlatın**. Başlat menüsünden **Ubuntu 22.04** uygulamasını açın. İlk açılışta bir Linux kullanıcı adı ve şifresi oluşturun (bu Windows şifrenizden ayrı olabilir).

**PowerShell'de** doğrulayın:

```powershell
wsl --list --verbose
```

Ubuntu satırında `VERSION 2` beklenir. `VERSION 1` ise (yüklü dağıtım adını `wsl -l -v` çıktısından alarak):

```powershell
wsl --set-version Ubuntu-22.04 2
```

`wsl --install` takılırsa [Microsoft'un WSL kurulum rehberini](https://learn.microsoft.com/tr-tr/windows/wsl/install) inceleyin. Yalnızca gerçekten gerekirse `wsl --install --web-download -d Ubuntu-22.04` yöntemini deneyin. Sanallaştırma hatalarında BIOS/UEFI'de VT-x/AMD-V veya SVM etkin olmalıdır.

## 2. Windows: NVIDIA sürücüsü ve Docker Desktop

**Windows üzerinde:**

1. [NVIDIA Drivers](https://www.nvidia.com/drivers/) üzerinden GPU'nuza uygun güncel **Windows** sürücüsünü kurun ve gerekirse yeniden başlatın. **WSL Ubuntu içine Linux NVIDIA sürücüsü (`nvidia-driver`, `cuda-drivers`) kurmayın.**
2. [Docker Desktop for Windows](https://docs.docker.com/desktop/setup/install/windows-install/) kurun, açın ve ilk kurulumu tamamlayın.
3. Docker Desktop > **Settings > General > Use WSL 2 based engine** açık olsun. Ayar bazı sürümlerde WSL2 zaten seçili olduğu için görünmeyebilir.
4. Docker Desktop > **Settings > Resources > WSL Integration** > **Ubuntu-22.04** seçeneğini açın > **Apply & Restart**.
5. Docker Desktop **Linux containers** modunda ve **Running** durumda olsun.

Şimdi **Ubuntu terminalini** açın:

```bash
cat /etc/os-release | grep PRETTY_NAME
nvidia-smi || /usr/lib/wsl/lib/nvidia-smi
docker --version
docker compose version
docker info --format '{{.ServerVersion}}'
```

**GPU'yu konteyner içinden doğrulama:**

```bash
docker run --rm --gpus all nvidia/cuda:13.0.1-base-ubuntu22.04 \
  nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv
```

GPU adı ve belleği görünmeden FLOP backend'e geçmeyin. `Cannot connect to the Docker daemon` veya `could not select device driver ... gpu` alırsanız [Docker/GPU sorunları](docs/HATALAR-VE-COZUMLER.md#docker-ve-gpu) bölümüne bakın.

> **Önemli:** **Docker Desktop yolunda** Ubuntu içinde ayrıca `apt install docker.io`, Docker Engine veya `nvidia-container-toolkit` kurulumuna ihtiyaç yoktur. Bu paketler **yalnızca Docker Engine'i WSL içine ayrı kurmayı tercih eden ileri seviye kullanıcılar** için farklı bir yöntemdir. Bu rehber Docker Desktop kullanır.

## 3. Ubuntu: sistem hazırlığı

Ubuntu terminalinde:

```bash
sudo apt-get update
sudo apt-get install -y git curl jq openssl ca-certificates wget gnupg coreutils util-linux
```

`jq` yoksa sponsor/model çıktısını ve sağlık kontrolünü okumak zorlaşır. `apt update` sırasında `404` alırsanız [APT 404 çözümüne](docs/HATALAR-VE-COZUMLER.md#ubuntu-apt-404-ve-jq-bulunamıyor) bakın.

**Systemd kontrolü:**

```bash
ps -p 1 -o comm=
```

`systemd` görünüyorsa devam edin. Aksi hâlde Ubuntu'da `/etc/wsl.conf` dosyasını düzenleyin (var olan bölümleri silmeyin):

```bash
sudo nano /etc/wsl.conf
```

Dosyaya `[boot]` bölümü yoksa şunu ekleyin; varsa mevcut bölümün altına sadece `systemd=true` ekleyin:

```ini
[boot]
systemd=true
```

Kaydedin (`Ctrl+O`, Enter, `Ctrl+X`). **Windows PowerShell'de:**

```powershell
wsl --shutdown
```

Ubuntu'yu yeniden açıp `ps -p 1 -o comm=` ile kontrol edin.

## 4. FLOP dosyaları ve ayarlar

Kaynak rehberin **compose, env ve sponsor** dosyalarını indiriyoruz; sistem betiklerini kendimiz uydurmuyoruz.

```bash
cd ~
git clone https://github.com/UfukNode/flop-miner-setup.git
sudo mkdir -p /opt/flop-miner/models
sudo chown -R "$USER:$USER" /opt/flop-miner
cp ~/flop-miner-setup/docker-compose.yml ~/flop-miner-setup/miner.env.example \
   ~/flop-miner-setup/sponsor.mjs /opt/flop-miner/
cd /opt/flop-miner
install -m 600 miner.env.example miner.env
```

### 4.1. Test edilmiş sürümler

Kaynak env'deki CLI `v0.1.321`, 13 Kasım 2026'da Devnet runtime `1014020` için **eski kalıyordu**. Biz `v0.1.342` ile model doğrulamasını ve miner durumunu başarıyla yaptık. Bu rehberde sadece CLI satırını değiştiriyoruz; worker ve backend kaynağın sabit image digest'lerini kullanıyor:

```bash
sed -i 's#^FLOP_CLI=.*#FLOP_CLI=ghcr.io/flop-labs/flop-core/cli:v0.1.342#' /opt/flop-miner/miner.env
```

> **Sürüm notu:** CLI tag/digest ve Devnet runtime gelecekte değişebilir. `v0.1.342`, yalnızca **bu tarihte test edilmiş** sürümdür; yeni runtime geldiğinde FLOP'un resmî image'ini tekrar kontrol edin. Worker `v0.1.336` için 15. adımdaki yama özel olarak yazılmıştır; yeni worker'a aynı yamayı uygulamayın.

### 4.2. Kişisel değişkenler ve sırlar

```bash
cd /opt/flop-miner
sed -i "s/^INFERENCE_API_KEY=.*/INFERENCE_API_KEY=$(openssl rand -hex 32)/" miner.env
sed -i "s/^SESSION_AUTH_TOKEN=.*/SESSION_AUTH_TOKEN=$(openssl rand -hex 32)/" miner.env
read -r -p 'Miner adı (küçük harf/rakam/tire): ' MINER_NAME
while ! [[ "$MINER_NAME" =~ ^[a-z0-9][a-z0-9-]*$ ]]; do
  echo 'Geçersiz miner adı; tekrar deneyin.'
  read -r -p 'Miner adı (küçük harf/rakam/tire): ' MINER_NAME
done
sed -i "s/^WORKER_NAME=.*/WORKER_NAME=$MINER_NAME/" miner.env
unset MINER_NAME
chmod 600 miner.env
```

`miner.env` **asla GitHub'a yüklenmemelidir**. Tokenları sohbete/Discord'a/loglara göndermeyin.

### 4.3. Terminal kısayolları

Aşağıdaki kısayolları **bir kez** ekleyin:

```bash
cat >> ~/.bashrc <<'EOF'
# FLOP miner helpers (WSL)
export FLOP_CLI="$(grep '^FLOP_CLI=' /opt/flop-miner/miner.env 2>/dev/null | cut -d= -f2-)"
compose() { docker compose --env-file /opt/flop-miner/miner.env -f /opt/flop-miner/docker-compose.yml "$@"; }
flop() { docker run --rm --network host -e FLOP_KEY_PASSWORD -v /opt/flop-miner:/work "$FLOP_CLI" "$@"; }
EOF
source ~/.bashrc
```

Doğrulama:

```bash
printf 'CLI: %s\n' "$FLOP_CLI"
compose config --quiet
```

> Bütün komutları her seferinde `/opt/flop-miner` içinden çalıştırmak zorunda değilsiniz; `compose` kısayolu mutlak yol kullanır. **Ama** `docker compose --env-file miner.env -f docker-compose.yml ...` yazacaksanız **önce `cd /opt/flop-miner`** deyin.

### 4.4. Container image'lerini indirin

```bash
docker pull "$FLOP_CLI"
compose pull
```

Backend image'i büyüktür; disk ve internet kotasını kontrol edin.

## 5. Miner cüzdanı ve güvenli anahtarlar

**Sıfırdan başlayan kullanıcı** yeni, sadece miner için ayrılmış bir hesap oluşturur. **Zaten FLOP miner hesabınız varsa yeni hesap üretmeyin; mevcut `signer` dosyasını güvenli biçimde taşıyın.** Asıl cüzdan seed'inizi bu kurulumda kullanmayın.

```bash
cd /opt/flop-miner
umask 077
# ÖNCE: /opt/flop-miner/signer veya $HOME/flop-miner-key.json
# zaten varsa yeni hesap oluşturmayın; mevcut anahtarı koruyun.
if [ -e signer ] || [ -e "$HOME/flop-miner-key.json" ]; then
  echo 'Mevcut anahtar bulundu: yeni cüzdan üretmeyin, önce mevcut hesabınızı kullanın.'
else
  flop keys generate --type sr25519 --show-secret --json > "$HOME/flop-miner-key.json"
  jq -er .mnemonic "$HOME/flop-miner-key.json" > signer
  jq -r .address "$HOME/flop-miner-key.json"
fi
```

Son komuttaki **halka açık miner adresini** not edin. 24 kelimelik mnemonic'inizi **sadece kendi terminalinizde** görüntüleyip çevrimdışı, güvenli bir yere yazın:

```bash
cat /opt/flop-miner/signer
```

> Bu çıktı **asla kimseyle paylaşılmaz**. Yedeği güvenle aldığınızdan emin olmadan aşağıdaki geçici dosyayı silmeyin.

```bash
rm -f "$HOME/flop-miner-key.json"
```

Worker `v0.1.336` dosyaların sahibi konusunda katıdır. **Bizim yaşadığımız üç yeniden başlatma hatasını önlemek için sahipliği en baştan ayarlayın:**

```bash
sudo chown root:root /opt/flop-miner/signer
sudo chmod 600 /opt/flop-miner/signer

sudo install -d -o root -g root -m 700 /opt/flop-miner/session-keys
sudo sh -c '[ -e /opt/flop-miner/session-keys/enclave.seed ] || { umask 077; openssl rand -hex 32 > /opt/flop-miner/session-keys/enclave.seed; }'
sudo chown root:root /opt/flop-miner/session-keys/enclave.seed
sudo chmod 600 /opt/flop-miner/session-keys/enclave.seed

sudo install -d -o root -g root -m 700 /opt/flop-miner/audit-key
sudo sh -c '[ -e /opt/flop-miner/audit-key/evidence.key ] || { umask 077; openssl rand -hex 32 > /opt/flop-miner/audit-key/evidence.key; }'
sudo chown root:root /opt/flop-miner/audit-key/evidence.key
sudo chmod 600 /opt/flop-miner/audit-key/evidence.key
```

**Doğrulama (dosya içeriklerini göstermeden):**

```bash
sudo stat -c '%n | Owner: %U | Mod: %a' \
  /opt/flop-miner/signer \
  /opt/flop-miner/session-keys \
  /opt/flop-miner/session-keys/enclave.seed \
  /opt/flop-miner/audit-key \
  /opt/flop-miner/audit-key/evidence.key
```

Anahtar dosyaları `root/600`, klasörler `root/700` olmalı. Normal kullanıcıyla `stat .../evidence.key` komutu `Permission denied` derse bu **beklenen güvenlik davranışıdır**; `sudo stat` kullanın. İzinleri `777` yapmayın. `signer`/`enclave.seed`/`evidence.key` silinmemeli ve yeniden kurulumda **üzerine yazılmamalıdır**.

## 6. Sponsor kaydı ve stake

Kaynağın sponsor betiği, imzalı kayıt isteğini [FLOP testnet sponsor servisine](https://faucet.flop.network/) gönderir. Betik için Docker görüntüsündeki Node kullanılır:

```bash
cd /opt/flop-miner
docker run --rm -v /opt/flop-miner:/work --entrypoint node "$FLOP_CLI" /work/sponsor.mjs
```

`HTTP 200` ve `success: true` görünmesi başarılı kayıt anlamına gelir. Sponsor bakiyesi/stake miktarı ağ koşullarına göre değişebilir; belirli bir tutarı garanti etmeyin.

**Önemli:** Sponsor kayıt başarılıysa tekrar cüzdan oluşturmayın; `flop miner register` ile ikinci bir işlem göndermeyin. `429`/`503` sorunları için [sponsor bölümü](docs/HATALAR-VE-COZUMLER.md#sponsor-429-503-ve-403)ne bakın.

Miner adresinizle zincir kaydını doğrulayın:

```bash
read -r -p 'Miner adresiniz (5...): ' MINER_ADDRESS
flop --network devnet --rpc wss://rpc.devnet.flop.network \
  miner status "$MINER_ADDRESS" --json | jq '{registered,stake,calibration}'
```

Beklenen `registered: true`, `stake.active: true`. `calibration: null` henüz normaldir. `RPC_UNREACHABLE` çıkarsa sponsorun çalışmadığı anlamına **gelmez**.

## 7. Modeli indirme ve zincirde doğrulama

**Bizim yaşadığımız kritik fark:** modelin güncel Hugging Face `main` revizyonu ile zincire kayıtlı modelin beklediği dosyalar aynı olmayabilir. Modeli, test ederek doğruladığımız **sabit revision** ile indirin:

```bash
cd /opt/flop-miner
flop --network devnet --rpc wss://rpc.devnet.flop.network \
  model fetch 0x1a52c1abe781db051e70ae357f72bb70161ca0c092df0b618f22a9292ba63306 \
  --precision BF16 \
  --revision 7ae557604adf67be50417f59c2c2f167def9a775 \
  --output-dir /work/models/qwen2.5-0.5b-instruct \
  --json
```

Başarılı sonuçta `ok: true`, `verified_root` değeri kayıtlı `0x1a52...63306` model hash'ine eşit olmalıdır. Zincirin kullandığı şema `verity-v1`'dir; Hugging Face'in verdiği `content_root` ile `verified_root` **farklı olabilir**. Önemli olan **kayıtlı model hash'inin doğrulanmasıdır**. Dosya indirme hatasında tekrar deneyin; `Unsupported runtime spec version` için CLI sürümünü gözden geçirin.

## 8. GPU backend'ini başlatma

```bash
cd /opt/flop-miner
compose up -d backend
compose logs --tail=80 backend
```

`MODEL_DIR reproduces MODEL_HASH` ve `Uvicorn running on ...:8000` beklenir. GPU ilk çalıştırmada model yükler. Sağlık kontrolü gizli anahtarınızı ekrana basmaz:

```bash
compose exec -T backend python3 -c 'import os,json,urllib.request as u; r=json.loads(u.urlopen(u.Request("http://127.0.0.1:8000/health",headers={"Authorization":"Bearer "+os.environ["INFERENCE_API_KEY"]})).read());print(json.dumps({k:r.get(k) for k in ("model_identity","model_hash","precision","decode_policy_hash","image")},indent=2))'
```

`model_identity: "measured"`, `precision: "bf16"`, doğru `model_hash` beklenir.

## 9. Cloudflare HTTPS tüneli

Miner'ın kendi bilgisayarınızdan dış dünyaya HTTPS ile ulaşılabilir olması gerekir. Router'da port açmadan, ücretsiz Cloudflare Quick Tunnel kullanıyoruz. Bu hizmetin **kalıcı sabit alan adı garantisi yoktur**.

```bash
cd ~
curl -fsSL -o cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared.deb
cloudflared --version
```

**Systemd servisi:**

```bash
sudo tee /etc/systemd/system/flop-tunnel.service > /dev/null <<'EOF'
[Unit]
Description=FLOP miner HTTPS tunnel
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=/usr/bin/cloudflared tunnel --no-autoupdate --url http://127.0.0.1:8645
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now flop-tunnel.service
```

Tünel adresini okuyup env'e yazın:

```bash
H=$(sudo journalctl -u flop-tunnel --no-pager -o cat \
  | grep -oE '[a-z0-9-]+\.trycloudflare\.com' | tail -1)
[ -n "$H" ] || { echo 'Tünel adresi henüz yok; journalctl ile kontrol et'; exit 1; }
sed -i "s/^SESSION_PUBLIC_HOST=.*/SESSION_PUBLIC_HOST=$H/" /opt/flop-miner/miner.env
grep '^SESSION_PUBLIC_HOST=' /opt/flop-miner/miner.env
```

Değer **`https://` olmadan**, sadece küçük harfli DNS adı olmalıdır. Sonra kuracağımız Tunnel Watch bu adresi değiştiğinde günceller.

## 10. Worker'ı başlatma

```bash
cd /opt/flop-miner
compose up -d worker
compose logs --tail=100 worker
```

**Başarılı başlatmada:**

- `Signer: 5...` (kendi miner adresiniz)
- `[ghost] published ghost key`
- `model-gate OK ... BF16`
- `Session chain settle enabled`
- `Session host listening on :8645`
- `Endpoint ad (https://...trycloudflare.com): published to the mailbox`

`Fatal: Signer file ... must be owned ...`, `Enclave key file ...`, `audit key directory ...` hataları **bizim gerçek kurulumumuzda görüldü**; kök sebep root sahipliği/izinleriydi. [Ayrıntılı komutlar](docs/HATALAR-VE-COZUMLER.md#worker-anahtar-ve-izin-hataları).

## 11. HTTPS ve worker sağlık kontrolü

**Dışarıdan bağlantı testi:**

```bash
H=$(grep '^SESSION_PUBLIC_HOST=' /opt/flop-miner/miner.env | cut -d= -f2-)
curl -sS --max-time 15 -o /dev/null -w '%{http_code}\n' "https://$H/session/info"
```

**`401` burada başarılıdır:** endpoint erişiliyor ama yetkisiz istek reddediliyor. `502`/`503` sorun olabilir; [tünel bölümüne](docs/HATALAR-VE-COZUMLER.md#cloudflare-tüneli-401-502-ve-değişen-adres) bakın.

**Yerel, yetkili sağlık kontrolü:**

```bash
T=$(grep '^SESSION_AUTH_TOKEN=' /opt/flop-miner/miner.env | cut -d= -f2-)
curl -sS --max-time 15 -H "Authorization: Bearer $T" \
  http://127.0.0.1:8645/session/info \
  | jq '{is_ready,audit_handoff_enabled}'
unset T
```

`audit_handoff_enabled: true` beklenir. Kalibrasyondan önce `is_ready: false` **normal** olabilir.

## 12. Kalibrasyon

Worker ağın gönderdiği Ghost test işlerini cevaplar. Bizim kalibrasyonumuzda 72 görev cevaplanmıştı; daha sonra **64 doğrulanmış görev**, **700 blok** ve **181 GFLOP/s** ilk kapasite kabulü zincirde göründü. Bu yalnızca **test edilmiş örnektir**.

```bash
compose logs -f worker | grep --line-buffered -Ei 'answered task|calibrat|capacity rate|error'
```

Canlı log ekranından `Ctrl+C` ile çıkınca worker çalışmaya devam eder. Mesajları şöyle yorumlayın:

| Mesaj | Anlamı |
|---|---|
| `capacity rate: waiting for an accepted cap (no finalized calibration record)` | Henüz kabul edilmiş kapasite kaydı yok; başlangıçta normal |
| `[ghost] answered task` | Görev **cevaplandı**; henüz zincirce doğrulanmış demek değildir |
| `[calibration] calibration check failed: ... InsufficientBurstWork` | İstenen sürdürülebilir kapasite o kontrol anında doğrulanamadı; sonraki kalibrasyon başarılı olabilir |
| `[calibration] initial cap accepted: 181 GFLOP/s from 64 verified jobs` | **Gerçek ilk kalibrasyon onayı** (181 sadece örneğimiz) |
| `capacity rate: 45 fits 4 sessions on cap 181` | Worker, onaylanmış kapasiteyi oturumlar arasında paylaştırıyor |

Rehberde ölçüm koşulu **en az 64 doğrulanmış iş ve yaklaşık 600 blokluk bir pencere**; süre ağ durumuna göre değişebilir. Tek başına 64 adet `answered task` sayısı **yeterli değildir**. Aynı GPU'nun bilgisayarınızda açık kalması gerekir.

Zincir doğrulaması:

```bash
flop --network devnet --rpc wss://rpc.devnet.flop.network \
  miner status "$MINER_ADDRESS" --json \
  | jq '.calibration'
```

`null` yerine `capGflopsPerSec`, `verifiedJobs`, `burstElapsedBlocks` görünürse onay zincirde işlenmiştir. RPC geçici olarak erişilemezse işlemleri hemen tekrar tekrar göndermeyin; worker'ın aktif olup olmadığını ayrıca kontrol edin.

## 13. Fence Guard — güvenli kilit koruması

Worker, zincire gönderdiği bir işlemin durumunu doğrulayamadığında **`miner signer is fenced`** uyarısı ile güvenlik kilidine girebilir. Kilidi elle silmek tehlikelidir. Kaynak rehberin, zincirden doğrulama yaparak güvenli olduğunda kilidi kaldırabilen aracını kuruyoruz:

```bash
U=https://raw.githubusercontent.com/UfukNode/flop-miner-setup/main/fence-guard
install -d -m 700 /opt/flop-miner/fence-guard
cd /opt/flop-miner/fence-guard
curl -fsSL --remote-name-all "$U"/{fence-guard.sh,status.mjs,recover.mjs,reconcile.mjs,worker-reconcile.mjs}
chmod +x fence-guard.sh
sudo curl -fsSL -o /etc/systemd/system/flop-fence-guard.service "$U/flop-fence-guard.service"
sudo curl -fsSL -o /etc/systemd/system/flop-fence-guard.timer "$U/flop-fence-guard.timer"
sudo systemctl daemon-reload
sudo systemctl enable --now flop-fence-guard.timer
systemctl list-timers flop-fence-guard.timer --no-pager
```

Kontrol:

```bash
docker compose --env-file /opt/flop-miner/miner.env -f /opt/flop-miner/docker-compose.yml \
  exec -T worker node --input-type=module < /opt/flop-miner/fence-guard/status.mjs \
  | jq '{fenced,ready}'
```

`fenced: false`, `ready: true` beklenir (kalibrasyon geçtikten sonra).

## 14. Tunnel Watch — tünel adresi değişirse otomatik düzeltme

Quick Tunnel, WSL/Windows yeniden başladığında farklı bir host adı alabilir. Bu araç tüneli **her dakika** kontrol edip gerekirse env'i ve worker'ı günceller.

```bash
U=https://raw.githubusercontent.com/UfukNode/flop-miner-setup/main/tunnel-watch
sudo install -d -m 755 /opt/flop-miner/tunnel-watch
sudo curl -fsSL -o /opt/flop-miner/tunnel-watch/tunnel-watch.sh "$U/tunnel-watch.sh"
sudo chmod +x /opt/flop-miner/tunnel-watch/tunnel-watch.sh
sudo curl -fsSL -o /etc/systemd/system/flop-tunnel-watch.service "$U/flop-tunnel-watch.service"
sudo curl -fsSL -o /etc/systemd/system/flop-tunnel-watch.timer "$U/flop-tunnel-watch.timer"
sudo systemctl daemon-reload
sudo systemctl enable --now flop-tunnel-watch.timer
systemctl list-timers flop-tunnel-watch.timer --no-pager
sudo journalctl -u flop-tunnel-watch -o cat --no-pager | tail -20
```

`Deactivated successfully` / `Finished ...` mesajları **normal**: servis bir kontrol yapıp kapanır, timer yeniden başlatır.

## 15. Worker performans yaması

**Sadece worker `v0.1.336` için.** Kaynak rehberdeki yama, sık yinelenen RPC okumalarını azaltır. Başarılı kalibrasyon ve Fence Guard kurulumu sonrasında uyguluyoruz. **Yama üçüncü taraf kodu değiştirdiğinden betiği çalıştırmadan önce inceleyin.**

```bash
cd /opt/flop-miner
curl -fsSL -o patch-worker.sh \
  https://raw.githubusercontent.com/UfukNode/flop-miner-setup/main/worker-patch/patch-worker.sh
less patch-worker.sh
sudo bash patch-worker.sh
```

**Bizim aldığımız hata:** `flock: cannot open lock file /run/flop-fence-guard.lock: Permission denied`. Sebep `bash patch-worker.sh` komutunu normal kullanıcıyla çalıştırmaktı. **Çözüm: `sudo bash patch-worker.sh`**. Başarılı çıktı `worker recreated with the patched file` ve `patched file: <hash>` olmalıdır.

Birebir SHA doğrulaması:

```bash
sha256sum /opt/flop-miner/patches/miner-worker.mjs
compose exec -T worker sha256sum /repo/sdk/miner-worker/miner-worker.mjs
```

İki hash aynı olmalı. Bizim kurulumda yamalı hash `92e67c4a73c7e41aef5834b0b7eb0e44e0ad655c2c4fe1cb50087dc2bc37a1bf` oldu (image ve yama değişirse doğal olarak başka hash olabilir). Orijinal `33255f3fd456f6f1a3e0c1c22221654d54e0117a3108c2012f240cb9c644bc0d` görünüyorsa yama çalışan worker'a geçmemiştir.

> **Sürüm güncellemeden önce:** yama geri alınmalı. Kaynak betiğe göre `sudo bash /opt/flop-miner/patch-worker.sh --undo` komutunu yalnızca planlı bakımda ve kaynak talimatlarını kontrol ettikten sonra kullanın.

## 16. Son doğrulama

```bash
cd /opt/flop-miner
compose ps
compose logs --tail=45 worker
cd /opt/flop-miner/fence-guard
compose exec -T worker node --input-type=module < status.mjs | jq '{fenced,ready}'
```

Başarılı son durumumuz: **backend Up**, **worker Up**, `model-gate OK`, `Session host listening on :8645`, `Endpoint ad (...) published`, `fenced: false`, `ready: true` ve `capacity rate: 45 fits 4 sessions on cap 181`.

`attested_gpu_inventory: []` kalibrasyon yapılmadığı anlamına **gelmez**. GPU envanterinin zincire yazılması **isteğe bağlı ayrı bir adımdır**; orijinal rehberin [16. GPU bildirimi](https://github.com/UfukNode/flop-miner-setup/blob/main/Turkce-Kurulum.md) kısmında keystore/şifre ile yapılır. Yedek almadan veya kişisel seed'i yanlışlıkla paylaşma riski varken uygulamayın.

## Yeniden başlatma ve günlük kullanım

Windows yeniden başladıktan sonra **Docker Desktop'ı açın** (Running olmalı), ardından **Ubuntu'yu açın**. Docker Desktop kullanırken Ubuntu içinde `sudo systemctl start docker` **gerekmez**.

```bash
# Ubuntu'da
cd /opt/flop-miner
sudo systemctl start flop-tunnel
sudo systemctl start flop-fence-guard.timer
sudo systemctl start flop-tunnel-watch.timer
compose up -d
compose ps
compose logs -f worker
```

İsterseniz bu repodan sağlanan [kontrol scripti](scripts/doctor.sh) ile terminal durumu görebilirsiniz (dosyayı kendi Ubuntu'nuzda indirin, çalıştırmadan önce okuyun). `Ctrl+C` ile logdan çıkmak **worker'ı durdurmaz**.

**Oturum/ödeme izle:**

```bash
compose logs --since=1h worker | grep -Ei '\[session\]|settle cooperative|payment|error' | tail -40
```

`Session chain settle enabled` oturum **ödendi** demek değildir; başarılı ücretli oturum için `[session] settle cooperative` gibi kapanış kaydı arayın. [Explorer](https://explorer.devnet.flop.network/mining) ile zincir durumunu karşılaştırın.

### Güvenlik ve yedek

- **Özel sırlar:** `/opt/flop-miner/signer`, `session-keys/enclave.seed`, `audit-key/evidence.key`, `miner.env`, varsa `miner.json` ve keystore parolası. Bunları GitHub'a, Discord'a veya hata raporuna koymayın.
- 24 kelimelik mnemonic'i **çevrimdışı güvenli yedekte** saklayın. `enclave.seed` ve `evidence.key` için de güvenli yedek gerekir; içeriklerini genel sohbete yazmayın.
- **`docker compose down -v` ÇALIŞTIRMAYIN**: volume'lardaki kalıcı verileri silebilir. `worker-data` silmeyin. Sadece `Ctrl+C` ile logdan çıkın, worker çalışır.
- Docker Desktop / WSL kapalıyken miner çalışmaz; zamanlayıcıların aktif olması bilgisayar uyku modunda miner'ı çalıştırmaz.
- `sudo chmod -R 777 /opt/flop-miner` gibi güvenliksiz komutlar kullanmayın.

## Ek belgeler

- [Gerçek kurulumda aldığımız bütün hatalar ve adım adım çözümler](docs/HATALAR-VE-COZUMLER.md)
- [Günlük komutlar / hızlı referans](docs/GUNLUK-KOMUTLAR.md)
- [Üretici ve upstream belgeleri](docs/KAYNAKLAR.md)
- [Salt-okuma tanılama betiği](scripts/doctor.sh)
- [Windows yeniden açıldıktan sonraki Ubuntu başlangıç betiği](scripts/start-miner.sh)

**Teşekkür / kaynak:** [UfukNode/flop-miner-setup](https://github.com/UfukNode/flop-miner-setup); [FLOP Network](https://flop.network/); Microsoft WSL, Docker ve NVIDIA belgeleri. Bu repodaki anlatım, yerel WSL kurulumundaki karşılaşılan sorunlara göre yeniden düzenlenmiştir; upstream kod/betik dosyaları bu repoda kopyalanmaz, indirildiği kaynak adresi açıkça belirtilir.

## GitHub'a yayımlama

Bu rehberi kendi hesabınıza aktarmak veya katkıda bulunmak için **[GitHub'da çatallama/yayımlama adımları](docs/GITHUB-YAYINLAMA.md)** dosyasını takip edin. Bu yayının GitHub adresi [`Xelp66/flop-miner-devnet`](https://github.com/Xelp66/flop-miner-devnet); **asla gerçek `/opt/flop-miner` çalışma klasörünüzü veya özel anahtarlarınızı yüklemeyin.**
