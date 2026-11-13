# Kaynaklar, sürümler ve sınırlar

## Kullanılan birincil kaynaklar

- [UfukNode — FLOP GPU Miner Kurulum Rehberi (Türkçe)](https://github.com/UfukNode/flop-miner-setup/blob/main/Turkce-Kurulum.md): compose, env.example, sponsor kaydı, Ghost, kalibrasyon, fence-guard, tunnel-watch ve worker performans yaması. **Bu projedeki upstream betikler kaynak repodan indirilir; bu paketin içine kopyalanmaz.**
- [UfukNode — kaynak depo](https://github.com/UfukNode/flop-miner-setup)
- [FLOP Network](https://flop.network/)
- [FLOP sürüm manifestosu](https://flop.network/releases.json) — img ve CLI sürümleri değişebilir.
- [FLOP Devnet Explorer / Mining](https://explorer.devnet.flop.network/mining)
- [Microsoft — Windows için WSL kurulumu](https://learn.microsoft.com/tr-tr/windows/wsl/install)
- [Microsoft — WSL temel komutları](https://learn.microsoft.com/tr-tr/windows/wsl/basic-commands)
- [Docker — Docker Desktop WSL 2 backend](https://docs.docker.com/desktop/features/wsl/)
- [Docker — Docker Desktop GPU support](https://docs.docker.com/desktop/features/gpu)
- [NVIDIA — CUDA on WSL User Guide](https://docs.nvidia.com/cuda/wsl-user-guide/)
- [Cloudflare — Cloudflared](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/)

## 13 Kasım 2026'da yerel WSL kurulumunda doğrulananlar

| Bileşen | Test edilen |
|---|---|
| Windows / WSL | Windows 11; Ubuntu 22.04.5 / WSL2 |
| GPU | NVIDIA RTX 5070 sınıfı Laptop GPU, yaklaşık 12 GB VRAM (konsol logları ile doğrulandı) |
| NVIDIA Windows sürücüsü | 591.97, CUDA 13.1 |
| Docker | Docker Desktop / WSL GPU entegrasyonu |
| FLOP CLI | `ghcr.io/flop-labs/flop-core/cli:v0.1.342` |
| Worker | `ghcr.io/flop-labs/flop-core/miner-worker:v0.1.336@sha256:b238975bb6ca282358e8f52f178152f26b4675ae6bbc5e1e305eacf92b27e39d` |
| Backend | `ghcr.io/flop-labs/flop-core/miner-vllm-toploc:v0.1.239@sha256:9b6c6dfc4d77ac37583d28dbfdcb4fa96207ae95956c1e859b7d5e9eef6f7b9e` |
| Model | `Qwen/Qwen2.5-0.5B-Instruct` BF16 |
| Kayıtlı model hash'i | `0x1a52c1abe781db051e70ae357f72bb70161ca0c092df0b618f22a9292ba63306` |
| Model revision | `7ae557604adf67be50417f59c2c2f167def9a775` |
| Kalibrasyon | 181 GFLOP/s, 64 verified jobs, 700 blocks, `Soft` |
| Worker durumu | `ready: true`, `fenced: false`, endpoint yayınlandı |
| Yamalı worker SHA256 | `92e67c4a73c7e41aef5834b0b7eb0e44e0ad655c2c4fe1cb50087dc2bc37a1bf` |

**Bu değerler evrensel performans/spec değildir.** Özellikle ağ sürümü, sponsor bakiyesi, stake, image sürümleri ve kalibrasyon koşulları güncellenebilir. Rehberi yeni kullanıcılar üzerinde otomatik test ettiğimizi iddia etmiyoruz; gerçek kullanıcı kurulumundan türetildiği ve resmî belgelerle karşılaştırıldığı doğrudur.

## Kaynak lisans / güvenlik yaklaşımı

Bu depo UfukNode'un **metinlerini veya betiklerini birebir yeniden yayımlamaz**; FLOP'un upstream compose/sponsor/timer betiklerine kaynak URL'leriyle yönlendirme yapar. Dış scriptleri indirirken kendiniz inceleyin ve değiştirilmiş kodu doğrudan çalıştırmayın. Özel anahtarlar veya cüzdan mnemonic'i hiçbir zaman bu repoya yüklenmemelidir.

**Public testnet address / test FLOP / model hash, mnemonic değildir**; ancak kendi yerel kimliklerinizi bir rehberde sabitlemeyin. Özel veri ve hizmet tokenlarının sızması risktir.
