# Windows güvenlik denetimi + düzeltme planı — 2026-10-27

**Durum:** Plan v2 — **onay bekliyor** (kod değişikliği henüz başlamadı).
**Kapsam:** `windows/*.cmd`, `windows/README-BEN OKU.txt`, `README.md` (Windows
bölümü), `src/*.c` (savunmacı düzeltmeler), `.github/workflows/build.yml`,
`.gitattributes`.
**Dokunulmayanlar:** `macos/`, `linux/`, `src/` içindeki upstream davranışı
(değişiklik yalnız hata yollarında).

## 1. Doğrulama modeli — üç kapı

Bu iş **CI-öncelikli** yürütülür, çünkü geliştirme makinesinde Windows derleyicisi
yok (mingw yok; `wine` var ama WinDivert kernel sürücüsünü yükleyemez).

| Kapı | Nerede | Ne kanıtlar | Kim |
|---|---|---|---|
| A — yerel statik | Linux dev makinesi | CRLF kontrolü (`file`), `grep` kural kontrolleri, `git diff --name-only` kapsam denetimi, YAML parse, `sha256sum` | worker + Manager |
| B — CI derleme | GitHub Actions `build.yml` (ubuntu + mingw-w64) | `goodbyedpi.exe` x86_64 + i686 derleniyor, artifact üretiliyor | Manager: `gh workflow run build.yml`, `gh run watch`, `gh run download` |
| C — gerçek donanım | Kullanıcının Windows makinesi | `sc create`, `icacls`, WinDivert sürücüsü, gerçek DPI atlatma | **yalnız kullanıcı** |

Kural: B kırmızıysa C'ye gidilmez.

## 2. Bulgular

| # | Önem | Bulgu | Kanıt |
|---|---|---|---|
| W1 | **Yüksek** | Servis **LocalSystem** çalışıyor ve binary kullanıcı-yazılabilir dizinden geliyor: `sc create "GoodbyeDPI" binPath= "\"%CD%\%_arch%\goodbyedpi.exe\" …"` (16 `.cmd`'nin hiçbirinde `obj=` yok). `%CD%` = ZIP'in çıkarıldığı yer (İndirilenler/Masaüstü) → o dosyayı sonradan değiştiren herkes SYSTEM alır | `windows/service_install_dnsredir_turkey.cmd:15` ve 6 kardeşi |
| W2 | Yüksek | Aynı dizinden `WinDivert.dll` yükleniyor (app-dir arama sırası) + LocalSystem → W1 ile birleşince SYSTEM kod çalıştırma | `goodbyedpi.exe` çalışma dizini |
| W3 | Orta | Hiçbir `.cmd`'de admin ön kontrolü yok; adminsiz çalıştırma yarım durum bırakır | `grep -l 'net session' windows/*.cmd` → boş |
| W4 | Orta | `service_remove.cmd` başka ürünlerin `WinDivert` / `WinDivert14` servislerini de siliyor | `windows/service_remove.cmd:8-12` |
| W5 | Orta | 7 `.cmd` koşulsuz `--dns-addr 77.88.8.8 --dns-port 1253` (+IPv6 Yandex) → tüm DNS tek üçüncü tarafta, düz metin | `grep dns-addr windows/*.cmd` |
| W6 | Orta | WinDivert indirmesi SHA256 ile doğrulanıyor (iyi) ancak üretilen artifact'lar için checksum yok | `build.yml:20,49-50` |
| W11 | Orta | `.gitattributes` yok, `core.autocrlf` ayarsız → `.cmd` dosyaları LF'e dönerse Windows'ta bozulur (bugün CRLF) | `file windows/*.cmd` → "CRLF line terminators" |
| W12 | Orta-Yüksek | CI: `permissions:` yok, `actions/checkout` `persist-credentials: false` değil, workflow `pull_request`'te repo içinden gelen `src/Makefile`'ı çalıştırıyor → aynı repodan PR, yazma yetkili token'lı job'da kod çalıştırabilir | `build.yml:1-26` |
| W13 | Orta | `build.yml` tetikleyicilerinde `windows/**` yok → yalnız `.cmd`/doküman değişince hiç CI sinyali yok | `grep -c 'windows/' build.yml` → 0 |
| W7 | Düşük | `malloc/calloc/strdup` sonuçları kontrol edilmiyor (OOM → NULL deref); `add_filter_str` payı `+16` yalnızca port ≤ 65535 varsayımıyla yeterli; `fake_clienthello` `packet_size`'ı `MAX_PACKET_SIZE` ile karşılaştırmıyor | `goodbyedpi.c:212-230`, `fakepackets.c:412-447`, `service.c:28-31` |
| W8 | Bilgi (iyi) | Ağdan gelen veri yolları doğru sınırlı: `extract_sni`, HTTP `Host`, `blackwhitelist_check_hostname`; derleyici bayrakları da sertleştirilmiş (`-D_FORTIFY_SOURCE=2`, `-fstack-protector`, `-pie -fPIE`, `-Wformat-security`) | `goodbyedpi.c:445-475`, `src/Makefile:22-27` |
| W9 | Düşük | Doküman antivirüsü "tamamen kaldırın" diyor; ayrıca kurulum dizini için ACL adımı yok | `README.md`, `windows/README-BEN OKU.txt` |

## 3. Dalgalar ve görevler

### Dalga 1 — paralel, 3 worker (dosyalar disjoint)

**WA — cmd sertleştirme Kapı A**
- **Target:** `windows/_require_admin.cmd` (yeni), 7 `service_install*.cmd`, `service_remove.cmd`, `.gitattributes` (yeni).
- **Change:** admin ön kontrolü (`net session >nul 2>&1 || (echo … & pause & exit /b 1)`); kurulum öncesi "kullanıcı-yazılabilir dizin" uyarısı + `%ProgramFiles%` önerisi; `WinDivert14`/eski WinDivert sürümlerini silmeyi bırak, yalnız `GoodbyeDPI` + `WinDivert`; her `sc` çağrısını hata toleranslı yap; `.gitattributes` ile `*.cmd text eol=crlf`, `*.sh text eol=lf`, `*.c text eol=lf`.
- **Constraints:** yöntem argümanları **değişmez**; dosyalar ASCII + CRLF kalır (renormalize yok); `@ECHO OFF`/`PUSHD`/`POPD` düzeni korunur; Türkçe kullanıcı metni.
- **Ownership:** `.gitattributes`, `windows/_require_admin.cmd`, `windows/service_install_dnsredir_turkey*.cmd` (7), `windows/service_remove.cmd`.
- **Acceptance:** `file windows/*.cmd` → hepsi CRLF; `grep -c '_require_admin'` = 7; `grep -c WinDivert14` = 0; `git diff --cached --name-only` = 9 yol.
- **Reporting:** filesModified, commit SHA, dört komut çıktısı.
- **Stop:** satır sonu dönüşümü riski doğrulanamıyorsa (diff'te tüm satırlar değişmiş görünüyorsa) sor.

**WB — güvenlik dokümanı Kapı A**
- **Target:** `windows/README-BEN OKU.txt`, kök `README.md` (Windows bölümü).
- **Change:** "Güvenlik notları (Windows)": DNS varsayılanı (Yandex, düz metin, `--dns-addr` kaldırma yolu); servis LocalSystem → ZIP'i `%ProgramFiles%\GoodbyeDPI` gibi yönetici-yazılabilir dizine çıkar + `icacls "…" /inheritance:r /grant:r "Administrators:(OI)(CI)F" "SYSTEM:(OI)(CI)F" "Users:(OI)(CI)RX"`; `WinDivert.dll/.sys` aynı dizinden yüklendiği için dizin yazılabilirse SYSTEM riski; sürüm SHA256 doğrulama; antivirüs için "kaldır" yerine "istisna + hash" tonu.
- **Constraints:** mevcut talimatlar silinmez (additive, 0 silme), CRLF korunur.
- **Ownership:** `windows/README-BEN OKU.txt`, `README.md`.
- **Acceptance:** `git show --numstat` 0 silme; `grep -c 'Güvenlik'` ≥ 1 her dosyada; verilen komutlar gerçek (`icacls`, `certutil -hashfile`).
- **Stop:** mevcut bir talimatla çelişki varsa sor.

**WC — CI sertleştirme Kapı A**
- **Target:** `.github/workflows/build.yml`.
- **Change:** workflow düzeyinde `permissions: contents: read`; `actions/checkout@v4` + `persist-credentials: false` (iki job); tetikleyicilere `windows/**` ekle; her artifact'a `sha256sum` ile `SHA256SUMS` üret ve artifact'a koy; `retention-days` sabitle.
- **Constraints:** derleme komutları/adımları bozulmaz; yeni job eklenmez.
- **Ownership:** `.github/workflows/build.yml`.
- **Acceptance:** `python3 -c "import yaml; …"` job/step sayısı artmış; `grep -nE 'permissions:|persist-credentials|windows/\*\*|SHA256SUMS'` dört eşleşme; yerel `sha256sum` denemesi.
- **Stop:** workflow'u bozma riski varsa sor.

### Dalga 2 — tek worker (Kapı B'ye bağlı)

**WD — C savunmacı düzeltmeler**
- **Target:** `src/goodbyedpi.c`, `src/fakepackets.c`, `src/service.c`.
- **Change:** `malloc/calloc/strdup` NULL kontrolleri; `add_filter_str`/`add_ip_id_str`/`add_maxpayloadsize_str` için `snprintf` + dönüş uzunluğuna göre yeniden tahsis; `fake_clienthello`'da `packet_size > MAX_PACKET_SIZE` erken dönüş; `SetDefaultDllDirectories(LOAD_LIBRARY_SEARCH_SYSTEM32|LOAD_LIBRARY_SEARCH_APPLICATION_DIR)` ile DLL arama sırasını sabitle (W2 savunması).
- **Constraints:** davranış değişikliği yok (yalnız hata yolları); CLI argümanları/çıktı metinleri değişmez; `src/` derleyici bayrakları değişmez.
- **Ownership:** `src/goodbyedpi.c`, `src/fakepackets.c`, `src/service.c`.
- **Acceptance:** yerel derleme **yok** → Kapı A: `git diff --stat` + kod incelemesi; **Kapı B zorunlu** (`gh workflow run build.yml` → `gh run watch` yeşil).
- **Stop:** derleme hatası CI'da çıkarsa tahminle düzeltmeye çalışma, CI logunu raporla.

### Dalga 3 — publish + kullanıcı testi

1. Push (kullanıcı onayı) → `gh workflow run build.yml` → `gh run watch` (Kapı B).
2. Artifact: `goodbyedpi_x86_64_<sha>` (+ `goodbyedpi_x86_<sha>`) → indirilip Windows'ta test edilir (Kapı C).
3. Kapı C geri bildirimi: hangi yöntem çalıştı, hata mesajı var mı → gerekirse yeni plan turu.

### Dalga 4 — ayrı sürüm kararı

**WE — Program Files kurulumu:** `service_install_hardened.cmd` (binary'yi `%ProgramFiles%\GoodbyeDPI`e kopyalar, ACL'i sıkılaştırır, servisi oradan kurar). W1 + W2'yi kökten kapatır; kullanıcı davranışı değiştiği için sürüm notu ve duyuru ister.

## 4. Risk ve geri dönüş

| Risk | Önlem | Geri dönüş |
|---|---|---|
| `.cmd` dosyalarının satır sonları bozulur (Windows'ta çalışmaz) | `.gitattributes` + `file` kontrolü + CRLF diff denetimi | tek commit revert |
| `SetDefaultDllDirectories` yanlış modla DLL'i bulamaz | `LOAD_LIBRARY_SEARCH_APPLICATION_DIR` dahil; Kapı B + Kapı C | çağrıyı kaldır |
| CI sabitlemesi derlemeyi kırar | `permissions`/`persist-credentials` derlemeyi etkilemez; `windows/**` yalnız tetikleyici | workflow diff revert |
| `snprintf` dönüşüyle yeniden tahsis hatalı olur | yalnız hata yolu; davranış aynı; Kapı B | commit revert |
| Kapı C'de test edilemez | kullanıcı kendi makinesinde dener; sonuç bu dosyaya işlenir | — |

## 5. Açık kararlar

1. `service_remove.cmd` eski `WinDivert14`'ü silmeyi bıraksın mı? *(öneri: evet)*
2. `SetDefaultDllDirectories` WD kapsamına girsin mi? *(öneri: evet)*
3. `.gitattributes` eklensin mi? *(öneri: evet, dosya içerikleri değişmez)*
4. Kapı B'yi Manager mı koşsun (`gh workflow run`), yoksa kullanıcı mı tetiklesin? *(öneri: Manager koşsun, artifact adını raporlasın)*

## 6. Yürütme notları

- Eşzamanlılık: 3 worker; aynı dosyaya iki worker dokunmaz (WD tek başına, `src/` sahibi).
- Her spec yedi alanı ve üç `pi` kısıtını taşır (bkz. `README.md`).
- `worker_done` payload'ında `taskId` zorunlu; eksikse Orca reddeder ve dispatch açık kalır.
- Kapsam denetimi: her dalga sonunda `git diff --name-only` yalnız izinli yolları göstermeli.
