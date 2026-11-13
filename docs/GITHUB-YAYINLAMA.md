# Bu dosyaları GitHub'da yeni bir repo olarak yayımlama

Özgün repo: **[`Xelp66/flop-miner-devnet`](https://github.com/Xelp66/flop-miner-devnet)**. Kendi hesabınızda ayrı bir kopya yayımlarken kendi repo adınızı kullanabilirsiniz. Bu rehberde **özel anahtar, gerçek `miner.env` ve `signer` dosyası bulunmaz.** Herkesin kendi bilgisayarında yeniden üreteceği örnek yönergeler içerir.

## Kolay yöntem: GitHub web + Git

1. GitHub'a giriş yapın: https://github.com/new
2. **Repository name:** tercihinize göre bir ad yazın (örnek: `flop-miner-devnet`).
3. Başkalarının da erişmesini istiyorsanız **Public**, yalnız kendiniz içinse **Private** seçin.
4. **Add a README**, **Add .gitignore** ve **Choose a license** seçeneklerini **boş bırakın**; dosyalar paket içinde zaten mevcut.
5. **Create repository** düğmesine basın. Boş repo oluşturulur.
6. Bu rehberin ZIP dosyasını Windows'ta **İndirilenler** klasörüne kaydedip **Tümünü ayıkla** ile açın. Açılan `flop-miner-devnet` klasörünü örneğin kendi Ubuntu ev dizininize kopyalayın. İsterseniz Ubuntu terminalinde Windows'un `Downloads` klasörüne `/mnt/c/Users/WINDOWS_KULLANICI/Downloads` yoluyla erişebilirsiniz. **Sadece paketin dosyalarını** taşıyın; kişisel `/opt/flop-miner` klasörünü GitHub'a **asla** kopyalamayın.
7. Ubuntu terminalinde, ZIP'ten çıkardığınız repo klasörünün içinde aşağıdaki komutları çalıştırın. `KENDI_KULLANICI_ADINIZ` ve `KENDI_REPO_ADINIZ` alanlarını değiştirmeyi unutmayın:

```bash
cd ~/flop-miner-devnet
# NOT: ZIP'i başka yere açtıysanız bu yolu kendi klasörünüze göre değiştirin.
git init -b main
git add README.md LICENSE .gitignore docs scripts
git status --short
git commit -m "Add Windows WSL2 FLOP miner Turkish setup and troubleshooting"
git remote add origin https://github.com/KENDI_KULLANICI_ADINIZ/KENDI_REPO_ADINIZ.git
git push -u origin main
```

**İlk `git commit`** kullanıcı adı/e-posta isterse, kendi GitHub kullanıcı adınızı ve GitHub'daki **no-reply** e-posta adresinizi (Settings > Emails) ayarlayın:

```bash
git config user.name "Xelp66"
git config user.email "GITHUB_NOREPLY_EMAILINIZ"
```

**Push kimlik doğrulaması** için GitHub hesabınızla giriş yapmanız gerekir. Ubuntu'da `gh` kullanabilirsiniz:

```bash
sudo apt-get update && sudo apt-get install -y gh
gh auth login
# GitHub.com > HTTPS > browser ile kimlik doğrula
gh auth setup-git
git push -u origin main
```

> `git push` normal GitHub hesap şifresiyle çalışmayabilir. **Token, parola veya SSH özel anahtarını** README'ye yapıştırmayın. `gh auth login`, kullanıcı hesabınızda etkileşimli doğrulama ister.

## Repo zaten oluşturulmuşsa

`remote origin already exists` hatası alırsanız önce:

```bash
git remote -v
```

Doğru URL görünüyorsa tekrar `git remote add origin` çalıştırmayın. Yanlışsa kendi repoyu seçerek `git remote set-url origin ...` kullanın. Başka projeyi yanlışlıkla overwrite etmeyin, `--force` kullanmayın.

## Yayımlamadan önce güvenlik kontrolü

```bash
git status --short
git ls-files
```

**Şu isimler kesinlikle git'e girmemeli:** `miner.env`, `signer`, `miner.json`, `session-keys/`, `audit-key/`, `models/`, `worker-data/`, `*.seed`, `*.key`. Bu repo dosyaları ile gerçek `/opt/flop-miner` çalışma klasörünü **ayrı tutun**.

Özgün rehber zaten `https://github.com/Xelp66/flop-miner-devnet` adresinde yayımlanmıştır. Yukarıdaki komutlar yalnızca **kendi kopyanızı** oluşturmak istediğinizde gereklidir.
