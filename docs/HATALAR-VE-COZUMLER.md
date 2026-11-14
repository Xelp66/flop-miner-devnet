# FLOP WSL Miner — Hatalar ve Çözümler

**Bu bölüm genel bir hata listesi değil, gerçek Windows/WSL Devnet kurulumunda karşılaştığımız sorunlardan hazırlanmıştır.** Her örnekte hata mesajı, neden ve çözüm ayrı gösterilir. Ayrıca yeni kullanıcıların karşılaşabileceği WSL/Docker ön koşul hataları bulunur. [Ana kurulum rehberi](../README.md).

> **Güvenlik:** `signer`, `session-keys/enclave.seed`, `audit-key/evidence.key`, `miner.env` içindeki gizli tokenlar veya 24 kelimelik mnemonic'in içeriğini hiçbir yerde paylaşmayın. Tanılama için **dosya izinlerini** gösterin, **içeriğini değil**. İzinleri `777` yapmayın. `docker compose down -v` çalıştırmayın.

## Ubuntu / WSL / Docker temelleri

### Ubuntu APT `404` ve `jq` bulunamıyor

**Karşılaşılan durum:** Ubuntu içinde paket kurulumu sırasında bazı eski URL'ler `404 Not Found` döndü; `jq` eksikti.

**Olası neden:** APT önbelleği eski ya da etkin paket deposunun adresi değişmiş. Önce varsayılan depoları değiştirmeden yeniden güncelleyin:

```bash
sudo apt-get clean
sudo apt-get update
sudo apt-get install -y jq curl git ca-certificates
jq --version
```

Hâlâ `404` ise hata veren **depo URL'sini** inceleyin:

```bash
grep -RniE '^deb |^URIs:' /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null | head -50
```

Ubuntu dağıtımınızla uyumsuz/terkedilmiş üçüncü taraf depoları güvenle düzeltmeden `apt` çalışmayabilir. Rastgele eski sürüm paketleri yüklemeyin; hata veren depo listesini paylaşabilirsiniz (**token/anahtar paylaşmadan**).

### `wsl --install` çalışmıyor / WSL 1 / systemd yok

- **Yönetici PowerShell** kullanın, `wsl --update`, Windows yeniden başlatma.
- `wsl --list --verbose` çıktısında kurulan Ubuntu sürümü **2** olmalı.
- Gerekirse `wsl --set-version Ubuntu-22.04 2` (dağıtım adı gerçekten böyleyse).
- `ps -p 1 -o comm=` → `systemd` beklenir. Değilse `/etc/wsl.conf` dosyasına `[boot]` altında `systemd=true`, ardından **Windows PowerShell'de** `wsl --shutdown` ve Ubuntu yeniden başlatma.
- Sanallaştırma/`0x80370102`: BIOS/UEFI VT-x/AMD-V/SVM, Windows sanal makine platformu ve WSL gereksinimlerini kontrol edin. İşlemci/donanım desteği yoksa farklı kuruluma geçmek gerekebilir.

Resmî kaynak: [Microsoft WSL](https://learn.microsoft.com/tr-tr/windows/wsl/install).

## Docker ve GPU

### `Cannot connect to the Docker daemon` veya `docker: command not found`

Bu rehber **Docker Desktop + Ubuntu WSL Integration** kullanır. **Windows'ta** Docker Desktop'ı açın, `Running` yazdığını doğrulayın. Settings > General > WSL 2 engine, Settings > Resources > WSL Integration > Ubuntu-22.04 etkin olsun.

Ubuntu terminalinde:

```bash
docker version
docker compose version
docker info --format '{{.ServerVersion}}'
```

**Docker Desktop kurulumunda** Ubuntu içine ikinci `docker.io`/`dockerd` yüklemek sorunu büyütebilir. Docker Desktop'ın WSL integration'ını düzeltin. `permission denied while trying to connect to the Docker daemon socket` durumunda da önce aynı ayarları ve etkin Docker context'ini kontrol edin:

```bash
docker context ls
```

### GPU görünmüyor: `could not select device driver "" with capabilities: [[gpu]]`

**Karşılaşılan durum:** NVIDIA GPU'nun Docker konteynerine geçirilmesi eksik olabiliyor. Bizim kurulumda GPU Docker içinden çalışır hâle getirildi.

**Docker Desktop + WSL2 çözümü:** Windows NVIDIA sürücüsünü güncelleyin; `wsl --update`; Docker Desktop WSL2 engine ve Linux containers modunu kontrol edin. Ubuntu'da:

```bash
nvidia-smi || /usr/lib/wsl/lib/nvidia-smi
docker run --rm --gpus all nvidia/cuda:13.0.1-base-ubuntu22.04 nvidia-smi
```

**Önemli ayrım:** Yalnızca ayrı bir *native Docker Engine* kullanan Ubuntu sunucusunda NVIDIA Container Toolkit / `nvidia-ctk runtime configure --runtime=docker` gerekir. **Bu repoda seçilen Docker Desktop yolunda o adımları uygulamayın.** WSL içine NVIDIA Linux display driver kurmayın.

Kaynaklar: [Docker WSL](https://docs.docker.com/desktop/features/wsl/), [Docker Desktop GPU](https://docs.docker.com/desktop/features/gpu), [NVIDIA CUDA on WSL](https://docs.nvidia.com/cuda/wsl-user-guide/).

### 12 GB VRAM ile backend açılır mı?

Kaynak rehber 16 GB+ VRAM önerse de gerçek kurulumda **12 GB NVIDIA GPU + Qwen 0.5B BF16** ile backend açıldı. Loglarda model yüklendi ve `/health` `model_identity: measured` döndü. Bu **tüm 12 GB GPU'lar için garanti değildir**; başka GPU kullanımı, model varyantı ve sürücü etkileyebilir. Başka büyük modelleri aynı GPU'da çalıştırmayın.

## Sponsor: 429, 503 ve 403

**Bizim kurulumda sponsor servisinden `429` ve `503` yanıtları alınmıştı.** Bunlar her durumda yeni cüzdan oluşturmak gerektiğini göstermez.

- **`429`**: sponsor servisinin kapasite/günlük sınırı veya istek limiti dolmuş olabilir. Mesaj içeriğine bakın; sürekli spam yapmayın, uygun zamanda tekrar deneyin.
- **`503`**: sponsor servisi geçici olarak kullanılamıyor. Ağa dönmesini bekleyin; anahtarları değiştirmeyin.
- **`403`**: işlem engellenmiş veya hesap kabul edilmemiş olabilir; servis yanıtındaki nedeni inceleyin.
- **`HTTP 200` ve `success: true`**: sponsor kayıt başarılı. Aynı hesabı gereksiz yere yeniden kaydetmeyin.

Çözüm için mevcut **halka açık** miner adresinizle zincir durumunu kontrol edin:

```bash
read -r -p 'Miner adresi (5...): ' MINER_ADDRESS
FLOP_CLI=$(grep '^FLOP_CLI=' /opt/flop-miner/miner.env | cut -d= -f2-)
docker run --rm --network host "$FLOP_CLI" \
  --network devnet --rpc wss://rpc.devnet.flop.network \
  miner status "$MINER_ADDRESS" --json | jq '{registered,stake}'
```

Bizim son başarılı kaydımızda `registered: true`, `stake.active: true` ve sponsor delege stake'i vardı. Sponsor miktarı zamanla değişebilir; sabit bir rakama güvenmeyin. **RPC erişilemiyorsa sponsor sonucunu salt-okuma sorguyla doğrulamış sayılmazsınız; önce RPC'yi kontrol edin.**

## CLI / RPC / model

### `Unsupported runtime spec version 1014020` (CLI v0.1.321 veya eski)

**Karşılaşılan durum:** FLOP Devnet zinciri runtime `1014020` sürümündeyken kullandığımız CLI `v0.1.321` yalnızca eski spec'leri destekliyordu. Metadata/model komutları başarısız oldu.

**Bizim çalışan çözüm (13.11.2026):** Sadece CLI görüntüsünü `v0.1.342` olarak değiştirdik:

```bash
cd /opt/flop-miner
sed -i 's#^FLOP_CLI=.*#FLOP_CLI=ghcr.io/flop-labs/flop-core/cli:v0.1.342#' miner.env
docker pull ghcr.io/flop-labs/flop-core/cli:v0.1.342
source ~/.bashrc
```

Yeni runtime değişirse bu sürüm de eski kalabilir. [FLOP sürüm listesini](https://flop.network/releases.json) ve resmî image'leri kontrol edin. CLI'yi yükseltmek, worker'ı otomatik yükseltmek değildir; **worker patch'i başka sürüme taşımayın.**

### `RPC_UNREACHABLE ... timed out after 10 seconds`

**Bizim gerçek log:**

```text
"ok": false,
"code": "RPC_UNREACHABLE",
"message": "RPC unreachable: could not connect to wss://rpc.devnet.flop.network ... timed out after 10 seconds"
```

**Ne demek?** RPC WebSocket o anda yanıt vermedi. **Bu hata tek başına miner kaydının silindiği veya GPU'nun bozulduğu anlamına gelmez.**

```bash
# Worker yaşıyor mu?
cd /opt/flop-miner
docker compose --env-file miner.env -f docker-compose.yml ps

# Worker loglarında yeni RPC bağlantı hatası var mı?
docker compose --env-file miner.env -f docker-compose.yml \
  logs --since=10m worker | grep -Ei 'rpc|fatal|fenced|error' | tail -30
```

RPC tarafında geçici kesinti yaşanabilir. Birkaç dakika sonra salt-okuma `miner status` sorgusunu tekrar deneyin; **sponsor kaydı / stake / imzalı işlemleri gereksiz tekrarlamayın**. `miner signer is fenced` olursa aşağıdaki Fence Guard bölümünü uygulayın.

### `model fetch` sırasında `MODEL_VERIFICATION_FAILED` / `fetch failed`

**Bizim durum:** Model ilk denemelerde yanlış/güncel revision veya indirme sorunu nedeniyle doğrulanmadı. CLI sürümünü `v0.1.342` yaptık, ardından kayıttaki model için **sabit Hugging Face revision** kullandık:

```bash
cd /opt/flop-miner
flop --network devnet --rpc wss://rpc.devnet.flop.network \
  model fetch 0x1a52c1abe781db051e70ae357f72bb70161ca0c092df0b618f22a9292ba63306 \
  --precision BF16 \
  --revision 7ae557604adf67be50417f59c2c2f167def9a775 \
  --output-dir /work/models/qwen2.5-0.5b-instruct --json
```

**Hedef sonuç:** `verified_root` kayıtlı `0x1a52c1...63306` hash'ine eşit; `scheme: verity-v1`, `ok: true`. Tek seferlik ağ indirme hatası varsa tekrar deneyin. Doğrulama başarısızsa yanlış dosyayı çalışan backend'e yüklemeyin.

### `content_root` farklı ama `verified_root` aynı

**Gerçekte görüldü.** Hugging Face içerik hash'i ile zincirin **`verity-v1` model root'u** farklı ölçümler olabilir. Model kayıtlı root'a **başarıyla** doğrulanıyorsa bu kendi başına hata değildir. Yanlış olan `verified_root` değerinin kayıtlı `MODEL_HASH` ile eşleşmemesidir.

### Backend `MODEL_DIR reproduces MODEL_HASH` / sağlık kontrolü

Doğru çalışma örneği:

```text
MODEL_DIR reproduces MODEL_HASH ... (verity-v1)
Uvicorn running on http://0.0.0.0:8000
```

Backend sağlık kontrolünde `"model_identity": "measured"`, doğru hash ve `"precision": "bf16"` beklenir. Başarısızsa modeli 7. adımdaki kayıtlı revision ile yeniden doğrulayın; Docker GPU desteğini de kontrol edin.

## Worker anahtar ve izin hataları

Bunlar **en çok zaman harcadığımız gerçek hatalardı**. Üçünün de ortak nedeni, konteynerde `root` olarak çalışan worker'ın bind-mount edilen dosyaların host tarafında yanlış sahiplik/izinlere sahip olmasıydı.

**ÖNEMLİ:** Önce worker'ı durdurun. **Anahtarları yeniden üretmeyin, dosya içeriklerini yazdırmayın.**

```bash
cd /opt/flop-miner
docker compose --env-file miner.env -f docker-compose.yml stop worker
```

### Hata 1: `Signer file /run/flop/signer must be owned by the worker user`

```text
Fatal: Error: Signer file /run/flop/signer must be owned by the worker user
```

**Düzeltme:**

```bash
sudo chown root:root /opt/flop-miner/signer
sudo chmod 600 /opt/flop-miner/signer
```

### Hata 2: `Enclave key file must be owned by the worker user`

Signer düzeldikten sonra ikinci hata çıktı. **Düzeltme:**

```bash
sudo chown root:root /opt/flop-miner/session-keys/enclave.seed
sudo chmod 600 /opt/flop-miner/session-keys/enclave.seed
```

### Hata 3: `audit key directory must be worker-owned and not writable by group/other`

Signer ve enclave düzeldikten sonra bu kez worker, audit anahtarının **dizinini** reddetti. `evidence.key` dosyasını tek başına düzeltmek yeterli değil:

```bash
sudo chown root:root /opt/flop-miner/audit-key
sudo chmod 700 /opt/flop-miner/audit-key
sudo chown root:root /opt/flop-miner/audit-key/evidence.key
sudo chmod 600 /opt/flop-miner/audit-key/evidence.key
```

**Kontrolü yalnızca `sudo stat` ile yapın:**

```bash
sudo stat -c '%n | Owner: %U | Permission: %a' \
  /opt/flop-miner/signer \
  /opt/flop-miner/session-keys/enclave.seed \
  /opt/flop-miner/audit-key \
  /opt/flop-miner/audit-key/evidence.key
```

Beklenen: anahtar dosyaları `root/600`, audit-key klasörü `root/700`.

**Worker'ı başlatın:**

```bash
docker compose --env-file miner.env -f docker-compose.yml up -d worker
docker compose --env-file miner.env -f docker-compose.yml logs --since=1m --tail=80 worker
```

`model-gate OK`, `[ghost] published ghost key`, `Session host listening on :8645` ve `Endpoint ad ... published` kontrol edin.

### `stat: cannot statx '.../audit-key/evidence.key': Permission denied`

**Bu hatayı da bizzat aldık.** `audit-key` klasörü `root/700` olduğunda normal WSL kullanıcısı içerideki dosyayı listeleyemez. **Bu istenen güvenlik düzenidir.** Dizin izinlerini açmak yerine:

```bash
sudo stat -c '%n | Owner: %U | Permission: %a' \
  /opt/flop-miner/audit-key \
  /opt/flop-miner/audit-key/evidence.key
```

### Loglarda eski `Fatal` hatalarının tekrar görünmesi

`docker compose logs worker` bütün önceki container denemelerini gösterebilir; bizim 30/60 dakikalık grep çıktımızda eski `Signer` / `Enclave` / `audit` hataları tekrar görülüyordu. **Bu, şu an da hata olduğu anlamına gelmez.**

```bash
docker compose --env-file /opt/flop-miner/miner.env \
  -f /opt/flop-miner/docker-compose.yml ps

docker compose --env-file /opt/flop-miner/miner.env \
  -f /opt/flop-miner/docker-compose.yml logs --since=2m --tail=80 worker
```

Worker `Up` ve son loglarda başarılı mesajlar varsa eski `Fatal` kayıtlarına bakıp anahtarları yeniden değiştirmeyin.

## Cloudflare tüneli: `401`, `502` ve değişen adres

### `/session/info` dışarıdan `401` veriyor — bu hata mı?

**Hayır.** Bizim testimizde:

```bash
H=$(grep '^SESSION_PUBLIC_HOST=' /opt/flop-miner/miner.env | cut -d= -f2-)
curl -sS --max-time 15 -o /dev/null -w '%{http_code}\n' "https://$H/session/info"
```

**401 beklenen yanıt**: worker erişiliyor ama yetkisiz istek reddediliyor. **502/503** ise worker hazır değil, tunnel yönlendirme bozuk veya servis erişilemiyor olabilir:

```bash
sudo systemctl status flop-tunnel --no-pager
sudo journalctl -u flop-tunnel -n 40 --no-pager
docker compose --env-file /opt/flop-miner/miner.env -f /opt/flop-miner/docker-compose.yml ps
```

Quick Tunnel her yeniden başlatmada **farklı `trycloudflare.com` adresi** verebilir. Rehberdeki **Tunnel Watch** bunu takip eder. `SESSION_PUBLIC_HOST` başında `https://` **olmamalı**.

### `SESSION_PUBLIC_HOST must be a lowercase DNS name`

`miner.env` içindeki satır sadece şu biçimde olmalı:

```text
SESSION_PUBLIC_HOST=ornek-isim.trycloudflare.com
```

`https://` veya sonda `/session/info` yazmayın.

### Tunnel Watch: `Deactivated successfully` / `Finished ...`

**Bizim çıktımız:**

```text
Starting FLOP miner tunnel watch (keeps the public address working)...
flop-tunnel-watch.service: Deactivated successfully.
Finished FLOP miner tunnel watch (keeps the public address working).
```

Bu normaldir; servis **timer tarafından kısa süreli başlatılıp kapanır**. Sonraki çalışma zamanını kontrol edin:

```bash
systemctl list-timers flop-tunnel-watch.timer --no-pager
```

## Kalibrasyon, Ghost ve oturumlar

### `capacity rate: waiting for an accepted cap (no finalized calibration record)`

**Bizim çıktı:** Kalibrasyon başlamadan önce ve iş cevaplanırken görülüyordu; tek başına hata değil. Test işleri geliyor mu?

```bash
cd /opt/flop-miner
docker compose --env-file miner.env -f docker-compose.yml \
  logs --since=30m worker | grep -E '\[ghost\] answered task|\[calibration\]' | tail -30
```

### `72 answered task` varken `.calibration` neden `null`?

**Bizde tam bu yaşandı.** `answered task` görev **cevaplandı** demektir, **doğrulandı** demek değildir. Kaynak rehber en az **64 doğrulanmış iş + 600 blok ölçüm aralığı** gerektiğini söylüyor. İlk 72 işimiz yaklaşık dört dakikalık log aralığında gerçekleşti; gereken blok aralığı henüz onaylanmamıştı.

```bash
# Logda kabul mesajına bakın
docker compose --env-file /opt/flop-miner/miner.env \
  -f /opt/flop-miner/docker-compose.yml logs worker \
  | grep -Ei 'cap accepted|calibration' | tail -20
```

Kalibrasyon ancak `initial cap accepted` veya zincirde dolu `.calibration` kaydıyla kesinleşir. Worker ve ağ bağlantısını açık tutun.

### `hwCalibration.InsufficientBurstWork: Verified work does not demonstrate the requested sustained cap`

**Bizim logda bu kontrol önce başarısız oldu**, ancak daha sonra şu mesaj geldi:

```text
[calibration] initial cap accepted: 181 GFLOP/s from 64 verified jobs (window from #3667698)
```

Ağ, o anda yeterli sürdürülebilir kapasite kanıtı görmemiş olabilir. **Hemen anahtar değiştirmeyin, GPU'yu yeniden kaydetmeyin, worker'ı gereksiz başlatmayın.** Yeni kalibrasyon kontrollerini ve **zincir kaydını** izleyin. Sürekli başarısızsa GPU yükü, sıcaklık, ağ, backend ve gerçek doğrulama sayısını kontrol edin.

Bizim son zincir durumumuz (13.11.2026):

```json
{
  "capGflopsPerSec": 181,
  "empiricalCapGflopsPerSec": 181,
  "assuranceTier": "Soft",
  "verifiedJobs": 64,
  "burstElapsedBlocks": 700
}
```

Bu **örnektir**; başka bir kullanıcıda rakamlar farklı olacaktır.

### `attested_gpu_inventory: []` / `hardware_fingerprint: null`

Bizim miner **181 GFLOP/s ile kalibre edildiği hâlde** `attested_gpu_inventory` boştu. Çünkü GPU envanterini zincire **isteğe bağlı ayrı işlem olarak** yazmadık. Bu değerler kalibrasyonun başarısız olduğunu göstermez. [Upstream GPU bildirimi](https://github.com/UfukNode/flop-miner-setup/blob/main/Turkce-Kurulum.md) ayrı adımda açıklanır.

### `Session chain settle enabled` var ama ödeme yok

Bu satır **oturum/settlement özelliği açık** demektir, ödeme alındı demek değildir. Biz ilk çalıştırmada henüz ücretli oturum tamamlanmadığı için şu filtre sadece başlangıç mesajlarını gösteriyordu:

```bash
docker compose --env-file /opt/flop-miner/miner.env \
  -f /opt/flop-miner/docker-compose.yml logs --since=1h worker \
  | grep -Ei '\[session\]|settle cooperative|payment|error' | tail -40
```

Ücretli oturum için `[session] settle cooperative` ve Explorer kaydını kontrol edin. Devnet'te istek gelmesi, ücret ya da gelir garantisi yoktur.

### `capacity rate: 45 fits 4 sessions on cap 181`

Bu **olumlu** mesajdır: onaylanan 181 GFLOP/s kapasiteden worker'ın **aynı anda 4 session** ayırabildiğini gösterir. GPU'da aynı anda dört ücretli iş olduğu anlamına gelmez.

### `Session-serving mode (Mode A, chain-settle). Not polling mempool tasks.`

Bu hata değildir. Worker **oturum sunma modundadır**; mempool görevi taramak yerine zincir/HTTPS üzerinden gelen oturumlara hizmet verir.

### `miner signer is fenced`

Bu **güvenlik kilididir**, dosyayı silerek çözülmemelidir. Fence Guard zamanlayıcısını çalıştırın ve durumunu görün:

```bash
systemctl list-timers flop-fence-guard.timer --no-pager
sudo tail -30 /opt/flop-miner/fence-guard/guard.log
cd /opt/flop-miner/fence-guard
docker compose --env-file ../miner.env -f ../docker-compose.yml \
  exec -T worker node --input-type=module < status.mjs | jq .
```

`fenced: true` ise sistemin zincirce güvenli olduğunu doğrulamasını bekleyin. Rehberde `BLOCKED, needs a person` durumunda **elle dosya silmeyin**; [upstream hata yönergelerine](https://github.com/UfukNode/flop-miner-setup/blob/main/Turkce-Kurulum.md) bakın.


### 14 Kasım 2026: Bilgisayar yeniden açıldıktan sonra ödeme yok, `da.register failed`, worker `ready: false`

**Gerçek olay (Windows 11 + WSL2 + Docker Desktop, worker v0.1.336):** Bilgisayar kapatılıp açıldıktan sonra konteynerler çalışıyor, GPU/model doğrulanıyor, Cloudflare tüneline erişiliyor; ancak miner yeni ücretli oturumları tamamlamıyordu. Bu olayda **takılı kalmış, süresi dolmuş bir kanalı zincirde kapattıktan ve worker'ı başlattıktan sonra** `/session/info-proof` tekrar **`ready: true`** döndü. Bu işlem görev kabul edebilme durumunu düzeltti; sonraki kazançların/ödemenin gerçekleştiği ayrıca `settle` ile doğrulanmalıdır.

**Gördüğümüz işaretler:**

- Worker logunda `[session] turn 0 g_n=132 unacked=132 toploc=yes` vardı: GPU gerçekten işlem yapmıştı.
- Aynı kanalın kanıt gönderimi `"phase":"da.register","status":"failed"` ile yaklaşık **55 saniye** sonra başarısız oldu.
- Ardından `miner signer is fenced`, `ready: false` ve zaman zaman `/session/info` isteğinde 20 saniyelik timeout görüldü.
- Fence Guard logunda `no fence file found; leaving it` vardı. Daha sonra kilit sorgusu `fenced: false` döndü; **kilidin kalkması tek başına worker'ın hazır olduğu anlamına gelmedi.**
- `fence-guard/status.mjs` çıktısındaki `ready: null`, gerçek `false` demek değildir: Bu betik `/session/info` hatasını yakalayıp `null` yazabilir.
- `/session/info` adresine **yetkisiz** HTTP isteği `401` döndü: Port erişilebilir; fakat bu **hazır/ödeme alabilir** anlamına gelmez.
- Tek bir RPC `chain_getFinalizedHead` denemesi başarılıydı (yaklaşık 1,8 sn); bu aralıklı RPC hatalarını dışlamaz. Önceki saatlerde `1006 Abnormal Closure` kopmaları da görülmüştü.
- Cloudflare Quick Tunnel adresi yeniden başlatmada değişebilir. Bizde duyurulan adres dışarıdan `401` döndü; bu olayın kesin nedeninin Cloudflare olduğu **gösterilmedi**.

#### 1. Önce konteyner, kilit ve gerçek hazır olma durumuna bakın

Komutların tamamı **Ubuntu / WSL terminalinde** çalışır:

```bash
cd /opt/flop-miner
docker compose --env-file miner.env -f docker-compose.yml ps
docker ps --format 'table {{.Names}}\t{{.Status}}' | grep -E 'NAMES|flop-miner'

# İmzalama kilidi: false beklenir; ready:null kesin hazır-değil kararı değildir
docker compose --env-file miner.env -f docker-compose.yml \
  exec -T worker node --input-type=module < fence-guard/status.mjs \
  | jq '{fenced,ready}'
```

**Kesin hazır olma testi:** `/session/info-proof` için **GET değil POST** kullanın; GET `404` döner ve bu bir arıza değildir. Token'ı ekrana basmadan worker içinden test:

```bash
cd /opt/flop-miner
docker compose --env-file miner.env -f docker-compose.yml exec -T worker node -e '
const start=Date.now();
fetch("http://127.0.0.1:8645/session/info-proof",{
  method:"POST",
  headers:{Authorization:"Bearer "+process.env.SESSION_AUTH_TOKEN,
           "Content-Type":"application/json"},
  body:JSON.stringify({challenge:require("node:crypto").randomBytes(32).toString("hex")}),
  signal:AbortSignal.timeout(20000)
}).then(async r=>{
  const d=await r.json();
  console.log(JSON.stringify({http:r.status,ready:d.ready,error:d.error||null,ms:Date.now()-start},null,2))
}).catch(e=>console.log("HATA:",e.message))
'
```

`http: 200` ile birlikte `ready: true` beklenir. `ready: false` ise önce gerçek nedenini bulmadan tekrar tekrar worker restart yapmayın.

**Eğer `fenced: true` ise:** Önce `sudo systemctl start flop-fence-guard.service` ve `sudo tail -20 /opt/flop-miner/fence-guard/guard.log` ile güvenli uzlaşmayı kontrol edin. Gerekli imzalı işlem akıbeti kesinleşmeden **fence dosyasını silmeyin, zorla kilidi açmayın, yeniden signer oluşturmayın**. Kilit devam ediyorsa aşağıdaki imzalı kanal kapatma adımına geçmeyin.

#### 2. Başarısız kanıt yüklemesine bağlı *takılı kanalı* tespit edin

```bash
cd /opt/flop-miner
docker compose --env-file miner.env -f docker-compose.yml logs --since=24h worker \
  | grep -E '"phase":"da\.(register|reconstruct)","status":"failed"|miner signer is fenced' \
  | tail -20
```

Hata satırındaki `channelId` değerini alın. **Başka miner'a ait veya farklı durumdaki bir kanalı kapatmayın.** Bizim olayda kanal kimliği `0x5aeab42765b8dce43901ad59efe3fbf285f3a477c7aa9be7d24dd05fc9d19bd8` idi; bu **geçmişe ait örnektir, yeni olayda aynısını kullanmayın**.

Upstream'in `close-expired.mjs` aracı, kanalı zincirde okuyup sahipliği, durumu ve bitiş bloğunu doğrular. İlk çalışma **sadece kontrol (dry-run)** yapar:

```bash
cd /opt/flop-miner
install -d -m 755 tools
curl -fsSL -o tools/close-expired.mjs \
  https://raw.githubusercontent.com/UfukNode/flop-miner-setup/main/tools/close-expired.mjs
# Güvenlik için indirdiğiniz betiğin içeriğini inceleyin:
less tools/close-expired.mjs

# AŞAĞIDAKİ DEĞERİ YENİ HATALI OTURUMUN channelId'Sİ İLE DEĞİŞTİRİN:
ID=0xBURAYA_64_HEX_KARAKTERLIK_KANAL_KIMLIGI
CLI=$(grep '^FLOP_CLI=' miner.env | cut -d= -f2-)
docker run --rm --network host -v /opt/flop-miner:/work:ro \
  --entrypoint node "$CLI" /work/tools/close-expired.mjs "$ID"
```

Yalnızca `open and expired ... can be closed` mesajı alındığında ve **`fenced: false` doğrulandığında** bir sonraki adıma geçin. `open until block ...` ise henüz süresi dolmamıştır, imzalı kapatma yapmayın. Ücret, ağ koşullarına göre değişir; bizim olayda tahmini **0,0085 test FLOP** idi.

#### 3. Worker'ı durdurun, süre aşımı işlemini gönderin, yeniden başlatın

`--send` **gerçek zincir işlemi imzalar**, kapanan kanalın escrow tutarını alıcıya iade eder ve miner hesabından işlem ücreti tahsil eder. İşlem, ücretli bir oturumun miner'a ödeme yapmasını sağlamaz; süresi dolan ve zaten bloke olmuş kanalı kapatmaya yarar.

```bash
cd /opt/flop-miner
# EŞ ZAMANLI imzalamayı engellemek için worker'ı durdurun
sudo flock -w 15 /run/flop-fence-guard.lock \
  docker compose --env-file /opt/flop-miner/miner.env \
  -f /opt/flop-miner/docker-compose.yml stop worker

# $ID ve $CLI değişkenleri 2. adımdan gelmiş olmalı.
# Yalnızca doğruladığınız süresi dolmuş kanalı kapatın:
sudo flock -w 15 /run/flop-fence-guard.lock \
  docker run --rm --network host -v /opt/flop-miner:/work:ro \
  --entrypoint node "$CLI" /work/tools/close-expired.mjs --send "$ID"

# Başarı: closed (computeChannel.TimedOutRefunded)
docker compose --env-file miner.env -f docker-compose.yml up -d worker
```

Bizde görülen **başarılı** on-chain çıktı: `closed (computeChannel.TimedOutRefunded)`. Bu çıktı gelmezse işlemin gerçekleştiğini varsaymayın, tekrar `--send` çalıştırmadan önce zincir durumuna bakın.

#### 4. Düzeldiğini doğrulayın

- Worker yeniden açılırken geçici `fetch failed` olabilir; `docker compose ... ps worker` ve son açılış logunda `Session host listening on :8645` bekleyin. Tekrar tekrar restart yapmayın.
- Yukarıdaki **POST /session/info-proof** testi `http: 200, ready: true` dönmeli. **Bizde kapatma ve worker başlatma sonrasında bu durum doğrulandı.**
- Cloudflare adresini kontrol edin; ücretsiz Quick Tunnel adresinin değişmesi **tek başına sorun değildir**. Tunnel Watch güncel `SESSION_PUBLIC_HOST` adresini worker'a duyurmalıdır:

```bash
cd /opt/flop-miner
HOST=$(grep '^SESSION_PUBLIC_HOST=' miner.env | cut -d= -f2-)
echo "Tünel: https://$HOST"
curl -sS --max-time 15 -o /dev/null -w 'Cloudflare HTTP: %{http_code}\n' \
  "https://$HOST/session/info"
```

`401` dış erişimin çalıştığını gösterir; **ödeme yapıldığını kanıtlamaz**. Nihai ödeme doğrulaması için worker logunda `[session] settle cooperative` veya Explorer'da `computeChannel.settle` başarılı işlemi bulunmalıdır.

**Yapmayın:** `docker compose down -v`, `docker system prune`, worker veri/kanıt deposu veya signer/fence dosyalarını elle silme, aynı kanala belirsiz şekilde tekrar tekrar `--send` gönderme. Bunun her PC açılışında mutlaka yaşanacağı doğrulanmadı; bu vaka yeniden başlatma **sonrasında gözlendi**, kesin kök nedenin WSL/Cloudflare olduğu gösterilmedi.

**Kaynak:** [UfukNode — RPC kesintisi sonrasında worker hazır değil / süresi dolan kanalı kapatma](https://github.com/UfukNode/flop-miner-setup/blob/main/Turkce-Kurulum.md) (rehberin sorun giderme bölümü).

### `V2 leaf cannot bind a TOPLOC activation commitment (fail closed)`

Kaynak rehberde bu hata `SESSION_COMMIT_IDS` eksikliğine bağlanıyor. Güncel `docker-compose.yml` dosyamızda `SESSION_COMMIT_IDS: "1"` var. Kontrol:

```bash
docker compose --env-file /opt/flop-miner/miner.env \
  -f /opt/flop-miner/docker-compose.yml \
  exec -T worker printenv SESSION_COMMIT_IDS
```

`1` olmalı. Kullanıcı kendi compose dosyasını yazdıysa bu alanı kaynak compose ile karşılaştırmalı.

### `503 session evidence publication unavailable`

Worker `v0.1.336` ücretli oturumlar için kanıt deposu ister. `SESSION_AUDIT_EVIDENCE_DIR`, `SESSION_AUDIT_EVIDENCE_KEY_FILE`, `./audit-key` mount ve `evidence.key` izinlerini kontrol edin. Yetkili `/session/info` yanıtında `audit_handoff_enabled: true` beklenir.

## Performans yaması ve komut dizini

### `flock: cannot open lock file /run/flop-fence-guard.lock: Permission denied`

**Bizim son kurulum hatamız.** `bash patch-worker.sh` orijinal worker'ı doğruladı, dört yamayı hazırladı, `syntax check: ok` ve `docker-compose.yml: mount added` dedi; ancak **kilit dosyası root'a ait** olduğu için worker'ı yeniden oluşturamadı.

**Bizim başarılı çözüm:**

```bash
cd /opt/flop-miner
sudo bash patch-worker.sh
```

Çıktıda `worker recreated with the patched file` ve `patched file: <hash>` beklenir. **Sadece normal `bash` komutu ile ikinci defa denemeyin.** Orijinal kaynak betik zaten root olarak çalıştırılmak üzere yazılmıştır.

### `sha256sum` hâlâ orijinal `33255f3f...` gösteriyor

Yama dosyası üretilmiş ama `flock` hatası yüzünden worker **yeniden oluşturulmamıştı**. Başarılı `sudo bash patch-worker.sh` sonrasında dosyanın ve container içindeki dosyanın SHA'sı eşitlendi:

```bash
sha256sum /opt/flop-miner/patches/miner-worker.mjs
docker compose --env-file /opt/flop-miner/miner.env \
  -f /opt/flop-miner/docker-compose.yml \
  exec -T worker sha256sum /repo/sdk/miner-worker/miner-worker.mjs
```

Her iki hash aynı olmalı. Test örneğimizde **`92e67c4a73c7e41aef5834b0b7eb0e44e0ad655c2c4fe1cb50087dc2bc37a1bf`**.

### `couldn't find env file: /opt/flop-miner/fence-guard/miner.env`

**Bizzat aldık.** Şu dizindeyken `docker compose --env-file miner.env ...` yazmıştık:

```text
/opt/flop-miner/fence-guard
```

`miner.env` ise bir üst dizinde. **En kolay çözüm:**

```bash
cd /opt/flop-miner
docker compose --env-file miner.env -f docker-compose.yml ps
docker compose --env-file miner.env -f docker-compose.yml logs -f worker
```

Veya **her dizinden** mutlak yol kullanın:

```bash
docker compose --env-file /opt/flop-miner/miner.env \
  -f /opt/flop-miner/docker-compose.yml ps
```

Bu hata **miner'ın durduğunu göstermez**, sadece terminalin yanlış klasörde olduğunu gösterir.

### Yama sonrası `Up` ve `ready: true`

Son kontrolümüzde `backend Up`, `worker Up`, `fenced: false`, `ready: true` ve `Session host listening on :8645` vardı. Bunlar başarılı kurulum göstergeleridir.

```bash
cd /opt/flop-miner
docker compose --env-file miner.env -f docker-compose.yml ps
cd /opt/flop-miner/fence-guard
docker compose --env-file ../miner.env -f ../docker-compose.yml \
  exec -T worker node --input-type=module < status.mjs | jq '{fenced,ready}'
```

---

**Sorunlar devam ediyorsa:** Son 2 dakikalık logları ve hata mesajını paylaşın; **secrets, token, seed, `.env` içeriği paylaşmayın**. **Canlı log ekranından `Ctrl+C` ile çıkmak miner'ı durdurmaz.**
