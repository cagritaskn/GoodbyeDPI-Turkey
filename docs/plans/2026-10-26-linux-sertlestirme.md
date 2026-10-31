# Linux desteği + güvenlik sertleştirmesi — 2026-10-26 / 27

**Durum:** Tamamlandı ve `origin/master`'a push edildi (son commit `ea3f043`).
**Kapsam:** `linux/` ağacı (byedpi/ciadpi portu), güvenlik denetimi ve düzeltmeleri.
**Dokunulmayanlar:** `macos/`, `windows/`, `src/` — bu iş sırasında hiç değişmedi.

## 1. Amaç

Windows'taki `.cmd` başlatıcılarının Linux karşılığını üretmek ve üretilen kodun
güvenlik açıklarını kapatmak. Linux'ta WinDivert yok; motor olarak
[byedpi](https://github.com/hufrea/byedpi) (`ciadpi`) userspace SOCKS5 proxy'si
kullanılır. Linux, byedpi'nin `--md5sig`, `--fake`, `-E/--transparent`,
`--disorder` gibi yeteneklerini desteklediği için Windows'taki `--set-ttl`
semantiği burada daha yüksek doğrulukla karşılanabiliyor.

## 2. Üretilen yapı

| Dosya | Görev |
|---|---|
| `linux/build.sh` | byedpi'yi klonlar, derler, `linux/bin/ciadpi` üretir; **commit'e pinlidir** (`BYEDPI_COMMIT`, kaçış: `BYEDPI_ALLOW_UNPINNED=1`) |
| `linux/Makefile` | `build` / `clean` / `check` / `test` / `help` |
| `linux/scripts/_lib.sh` | Ortak katman: yöntem tablosu, `run`/`DRY_RUN` önizleme, state snapshot/restore, proxy (gsettings/environment.d), DNS (resolved/resolv.conf), transparent mod (iptables+ip6tables / nft), systemd unit render, sağlık kontrolleri |
| `linux/scripts/turkey_dnsredir*.sh` (7) | Tek seferlik yöntemler (`default`, `alt`, `alt2`…`alt6`) |
| `linux/scripts/service_install*.sh` (7) | systemd servisi kurulumu |
| `linux/scripts/service_remove.sh` | Servisi kaldırır + ağ ayarlarını geri yükler |
| `linux/systemd/goodbyedpi-turkey.service.template` | Sertleştirilmiş unit (aşağıya bkz.) |
| `linux/tests/static-checks.sh` | Tüm `linux/**/*.sh` için `bash -n` kapısı |
| `linux/tests/lib-test.sh` | Stub tabanlı birim testleri (root/ağ gerekmez) |
| `linux/README.md` | Türkçe kullanıcı dokümanı + güvenlik notları + sorun giderme |
| `.github/workflows/linux-static.yml` | CI: `linux/**` için statik kontrol + stub testleri |

## 3. Güvenlik denetimi bulguları ve çözümleri

| # | Önem | Bulgu | Çözüm (commit) |
|---|---|---|---|
| Y1 | Yüksek | `build.sh` pinlenmemiş `main` dalını klonluyordu; binary root olarak çalışıyor | Commit pinleme + doğrulama, uyuşmazlıkta klonu silip çıkma (`6413075`) |
| Y2 | Yüksek | DNS varsayılan olarak Yandex'e zorlanıyordu, düz metin | `GOODBYEDPI_DNS=off\|yandex\|legacy`; **kullanıcı kararıyla varsayılan `yandex`** (`5763309`, `60a0216`) |
| O1 | Orta | `sudo -E` PATH'i koruyordu → root komut çağrılarında PATH hijack | `sudo --preserve-env=<beyaz liste>` + kütüphane içinde sabit PATH (`2b37ad1`) |
| O2 | Orta | Transparent mod yalnız IPv4 kapsıyordu → IPv6 sızıntısı | `ip6tables`/`nft ip6` kuralları (`a01edc0`) |
| O3 | Orta | Teardown kırılgandı: `iptables -D` hatası geri yüklemeyi durduruyordu; backend yeniden tespit ediliyordu | Kaydedilen backend'den, hataya toleranslı teardown (`a01edc0`) |
| D1 | Düşük | Unit'te sandbox anahtarları yoktu | `ProtectSystem=strict`, `RestrictAddressFamilies`, `SystemCallFilter=@system-service`, `NoNewPrivileges` vb. (`a154373`) |
| D2 | Düşük | `umask` yok, state dosyası yazıldıktan sonra `chmod 600` | `umask 077`, dizin 0700, geçici dosya + `mv` (`2b37ad1`) |
| D3 | Düşük | `$args` glob'a açılıyordu | `read -r -a argv` + `"${argv[@]}"` (`2b37ad1`) |

Sonradan, kullanıcı testleri sırasında bulunan iki regresyon daha düzeltildi:

| # | Belirti | Kök neden | Çözüm (commit) |
|---|---|---|---|
| R1 | `gsettings` → `dconf-WARNING … dbus-launch --autolaunch` ve proxy hiç uygulanmıyor | `--preserve-env` beyaz listesi `DBUS_SESSION_BUS_ADDRESS`/`XDG_RUNTIME_DIR` taşımıyordu; dconf root oturumunda yazamıyor | gsettings çağrıları `_as_desktop` ile **`SUDO_USER` olarak** (`runuser -u … -- env XDG_RUNTIME_DIR=… DBUS_SESSION_BUS_ADDRESS=…`); yazma başarısızsa `PROXY_DEGRADED` + non-zero çıkış (`bbb1933`) |
| R2 | Servis `status=203/EXEC`, `start-limit-hit`; tarayıcı "Vekil sunucu bağlantı kabul etmiyor" | Unit'teki `ProtectHome=yes`, `/home` altındaki ExecStart binary'sini görünmez yapıyordu; ayrıca hiçbir sağlık kontrolü yoktu | `ProtectHome=read-only` + kurulum/oneshot sonrası `systemctl is-active` ve port kontrolü, `journalctl` çıktısıyla Türkçe hata (`ea3f043`) |

## 4. Kabul kanıtları

- `cd linux && make check && make test` → `static-checks: 19 scripts, 0 failures`,
  `lib-test: 159 passed, 0 failed` (son hâli `ea3f043` sonrası daha yüksek).
- `./linux/build.sh` → `linux/bin/ciadpi`, `--version` → **17.3**.
- SOCKS smoke: `curl -x socks5h://127.0.0.1:1080 https://example.com` → **HTTP 200**.
- Gerçek kullanıcı testi (Kapı C): `sudo ./scripts/turkey_dnsredir.sh` çalıştı;
  `ciadpi` 1080'de dinliyor, GNOME proxy `manual`, DNS `77.88.8.8`.

## 5. Doğrulanmayanlar (kayıt için)

- Gerçek `systemd` koşumu ve gerçek `iptables/ip6tables` yönlendirmesi: root
  gerektirdiği için yalnız stub kanıtı var (Kapı C'de kullanıcı doğruladı).
- Transparent mod (`GOODBYEDPI_PROXY_MODE=transparent`) gerçek trafikle test edilmedi.
- `linux-static.yml` yerelde yalnız YAML olarak parse edildi; GitHub runner'da koşumu
  kullanıcı gözlemlemedi.

## 6. Yürütme biçimi (bu iş nasıl yapıldı)

- Tek fan-out: Orca orchestration; 4 dalga, 8 görev (S1–S7 + D1/G1/H1 düzeltmeleri),
  3 eşzamanlı worker sınırı.
- Yerel model (`local-ai-qwen/iq3_s`) yalnız mekanik görevlerde kullanıldı
  (build.sh, 15 wrapper, CI YAML); karmaşık mantık ve Türkçe prose buluta gitti.
- Her turda `manager-guard` (nested run/task denetimi) + `worker_done` doğrulaması;
  kapsam denetimi `git diff --name-only` ile yapıldı.
