# GoodbyeDPI-Turkey — Linux

Linux tarafı, Windows sürümüyle aynı amacı taşır: ISS'nin Derin Paket İnceleme (DPI) sistemini atlatmak. Ama motor farklı: burada
[byedpi](https://github.com/hufrea/byedpi) (`ciadpi`) kullanılıyor. Bu bir VPN değildir, trafiğini başka ülkeye taşımaz; bu yüzden
oyunlarda ve genel kullanımda hız kaybı yaratmaz. Paketleri yerel bir SOCKS5 proxy üzerinden yeniden düzenler.

## Ne farklı?

Windows sürümü WinDivert çekirdek sürücüsüyle çalışır; Linux'ta bu sürücünün karşılığı yok. Bu port, kullanıcı alanında çalışan bir
SOCKS5 proxy (`ciadpi`) ile Linux'a özgü paket tekniklerini (`--md5sig`, `--fake`, `--split`, `--disorder`, `--tlsrec`) birleştirir.
Yani macOS portunun birebir kopyası değil: Linux'un kendi primitiflerini kullanan ayrı bir uygulama.

## Gereksinimler

- Linux + `systemd` (servis modu için).
- Derleme için `git`, `make` ve bir C derleyicisi (`cc` / `gcc`).
- `sudo` yetkisi.
- Yalnızca şeffaf (transparent) mod için `iptables` **veya** `nft`.
- DNS için `systemd-resolved` (`resolvectl`) önerilir; yoksa `/etc/resolv.conf` yolu kullanılır.

## Derleme

```bash
cd linux
./build.sh        # ya da: make build
```

Betik byedpi'yi `linux/third_party/byedpi` altına klonlar ve `ciadpi` derleyip `linux/bin/ciadpi` olarak bırakır.
Temizlemek için `make clean` (hem `bin/` hem de gömülü byedpi derleme çıktıları silinir).

## Tek seferlik kullanım

Yedi hazır yöntem var. Hepsini tek tek dene, hangisi ISS'nde çalışıyorsa onu kullan:

| Komut | Yöntem | Açıklama | DNS |
| --- | --- | --- | --- |
| `sudo ./scripts/turkey_dnsredir.sh` | default | En geniş ayar: fake + md5sig + split + disorder + tlsrec | Yandex |
| `sudo ./scripts/turkey_dnsredir_alternative_superonline.sh` | alt | Sadece fake + düşük TTL + md5sig | Yandex |
| `sudo ./scripts/turkey_dnsredir_alternative2_superonline.sh` | alt2 | Sadece split + disorder | Yandex |
| `sudo ./scripts/turkey_dnsredir_alternative3_superonline.sh` | alt3 | alt ile aynı argümanlar | Yandex |
| `sudo ./scripts/turkey_dnsredir_alternative4_superonline.sh` | alt4 | alt2 ile aynı argümanlar | Yandex |
| `sudo ./scripts/turkey_dnsredir_alternative5_superonline.sh` | alt5 | split + tlsrec | Yandex |
| `sudo ./scripts/turkey_dnsredir_alternative6_superonline.sh` | alt6 | Sadece split + tlsrec | Yandex |

Yedi yöntemin hepsi varsayılan olarak Yandex DNS'i (77.88.8.8 / 77.88.8.1) zorlar; sistem DNS'ine dokunulmasını
istemiyorsan `GOODBYEDPI_DNS=off` ile çalıştır.

Betikleri `linux/` dizininin içinden çalıştır. Terminal açık kalır; `Ctrl-C` ile durduğunda proxy ve DNS ayarları geri alınır.
Ortak katman `linux/scripts/_lib.sh` dosyasında; yöntem tablosunu orada görebilirsin.

## Servis olarak kurma (otomatik başlangıç)

Tek seferlik sürümü beğendiysen aynı yedi yöntemin servis karşılığı var:

```bash
sudo ./scripts/service_install_dnsredir_turkey.sh
# varyantlar: service_install_dnsredir_turkey_alternative_superonline.sh,
#             ..._alternative2_superonline.sh ... ..._alternative6_superonline.sh
```

Kurulum sonrası systemd unit adı `goodbyedpi-turkey` olur:

```bash
systemctl status goodbyedpi-turkey
journalctl -u goodbyedpi-turkey -f
```

## Kaldırma

```bash
sudo ./scripts/service_remove.sh
```

Servisi durdurup unit dosyasını siler, ardından kaydedilmiş duruma göre proxy'yi ve DNS'i eski haline döndürür
(`/var/lib/goodbyedpi-turkey/prev-state.env` içindeki yedekten).

## İki mod: socks ve transparent

Varsayılan mod `socks`. Uygulamalar `127.0.0.1:1080` adresine yönlendirilir; GNOME'da proxy ayarı otomatik yapılır, GNOME yoksa
`environment.d` dosyası yazılır (yeni oturum açınca etkin olur).

Şeffaf mod, proxy ayarı olmayan uygulamalar için trafiği `iptables`/`nft` ile `REDIRECT` eder:

```bash
sudo GOODBYEDPI_PROXY_MODE=transparent ./scripts/turkey_dnsredir.sh
```

Bu mod `CAP_NET_ADMIN` ister ve varsayılan olarak kapalıdır. Dikkat: şeffaf modda elle kural bırakma; kalıcı kural yazarsan
internetin kesilmesi bu yüzdendir. Servis modunda gerekli yetenekler unit dosyasına otomatik eklenir.

## Güvenlik notları

- **DNS:** Varsayılan olarak DNS Yandex'e (77.88.8.8 / 77.88.8.1) zorlanır; bu, Windows betiklerindeki davranışla aynıdır.
  Yandex üçüncü taraf bir çözümleyicidir ve şifresiz DNS kullanır; bu yüzden MITM'e açıktır. DNS'e hiç dokunulmasını
  istemiyorsan `GOODBYEDPI_DNS=off` ile çalıştır, eski yöntem tablosu davranışı için `GOODBYEDPI_DNS=legacy` kullan.
  Hangi çözümleyicinin kullanıldığını `resolvectl dns <arayüz>` ile doğrula.
- **Yetkiler:** Süreç root olarak çalışır ve `--fake`, `--md5sig` için `CAP_NET_RAW` ile ham soket kullanır. Servis modunda
  unit, `NoNewPrivileges`, `ProtectSystem=strict`, `ProtectHome`, `RestrictAddressFamilies`, `SystemCallFilter` gibi
  sandbox anahtarlarıyla sınırlanır. Bir seferlik modda bu sınırlar yoktur, süreç tam root yetkisiyle açık kalır.
- **Dinleme adresi:** `CIADPI_HOST=0.0.0.0` **yapılmamalı**; proxy'yi tüm ağa açar (açık proxy). Varsayılan
  `127.0.0.1:1080` adresidir, yerel makine dışından erişilemez.
- **IPv6:** Şeffaf modda IPv4 ve IPv6 kuralları birlikte kurulur. Sistemde `ip6tables` / `nft ip6` yoksa betik uyarı verip
  yalnız IPv4 kurallarıyla devam eder; bu durumda IPv6 trafiği proxy'yi atlar ve IPv6 sızıntısı olabilir.
- **Kesinti sonrası temizlik:** `sudo ./scripts/service_remove.sh`, `systemctl is-active goodbyedpi-turkey`,
  `pgrep -a ciadpi`, `gsettings get org.gnome.system.proxy mode`, `resolvectl dns <arayüz>` çıktılarına bak; şeffaf modda
  elle kural kaldıysa `sudo iptables -t nat -F GOODBYEDPI_TURKEY`.
- **Derleme:** byedpi belirli bir commit'e sabitlenmiştir (`BYEDPI_COMMIT`). Güncellemek için önce
  `BYEDPI_ALLOW_UNPINNED=1 ./build.sh` ile derle, farkı incele, sonra yeni SHA'yı `BYEDPI_COMMIT` olarak yaz.

## Doğrulama / test

```bash
cd linux
make check    # bash -n ile tüm betiklerin sözdizimi
make test     # stub testleri, root gerekmez
```

Hiçbir şeyi değiştirmeden önizleme almak istersen `DRY_RUN=1` kullan; sistem komutları çalıştırılmaz, sadece yazılır:

```bash
DRY_RUN=1 ./scripts/turkey_dnsredir.sh
```

## Sorun giderme

- **Servis `status=203/EXEC` / `start-limit-hit` ile ölüyor:** ExecStart'taki `ciadpi` ikilisi unit'in sandbox'ı içinden
  erişilemez demektir. `ProtectHome=yes` `/home` dizinini servis için tamamen görünmez yapar; depo `linux/bin/ciadpi`
  genelde `/home` altında olduğu için süreç hiç başlamaz (`Unable to locate executable`, `203/EXEC`, ardından
  `start-limit-hit`). Şablonda artık `ProtectHome=read-only` yazıyor: ikili okunur, yazma izni yok. Eski unit ile
  karşılaşırsan `sudo ./scripts/service_remove.sh` çalıştırıp kurulumu tekrarla; `systemctl cat goodbyedpi-turkey`
  çıktısında `ProtectHome=read-only` görmelisin.
- **Tarayıcı "Vekil sunucu bağlantıyı kabul etmiyor" diyor (Firefox/Chrome):** proxy (GNOME) uygulanmış ama `ciadpi`
  dinlemiyor demektir; bu yüzden tarayıcı ölü bir porta gider. Kurulum artık bunu fark eder: servis aktif olmazsa ya da
  `1080` portu dinlenmezse son 20 journal satırını basar ve sıfırdan farklı çıkış koduyla durur (başarı taklidi yok).
  Kontrol: `systemctl status goodbyedpi-turkey`, `journalctl -u goodbyedpi-turkey -n 30`, `ss -ltn | grep 1080`,
  `pgrep -a ciadpi`. Temizlik: `sudo ./scripts/service_remove.sh`.

- **`--md5sig` desteklenmiyor / bağlantı hiç açılmıyor:** çekirdek bu tekniği kabul etmiyor olabilir. Argümanları
  `GOODBYEDPI_ARGS` ile ez: `sudo GOODBYEDPI_ARGS='--split 1+s --disorder 3+s' ./scripts/turkey_dnsredir.sh`.
- **`ciadpi bulunamadı`:** henüz derlememişsin. `cd linux && ./build.sh` çalıştır.
- **DNS geri gelmedi / internete çıkmıyor:** `sudo ./scripts/service_remove.sh` çalıştır; DNS ve proxy kayıtlı duruma döner.
- **Şeffaf modda internet tamamen kesildi:** önce kuralları boşalt, sonra servisi kaldır:
  `sudo iptables -t nat -F GOODBYEDPI_TURKEY` ve `sudo ./scripts/service_remove.sh`. `nft` kullanıyorsan
  `sudo nft delete table ip goodbyedpi_turkey` aynı işi görür.
- **Hâlâ engel var:** yöntemi değiştir (tablodaki alt varyantlar), sonra servis kurulumunu tekrarla.
- **`dconf-WARNING: failed to commit changes to dconf: "dbus-launch --autolaunch=..."`:** proxy ayarı masaüstü
  kullanıcısına yazılamamış demektir (tarayıcı SOCKS proxy'yi görmez, atlatma sessizce çalışmaz). GNOME proxy'si kullanıcı
  oturumunun D-Bus hattından yazıldığı için ortak katman `gsettings` çağrılarını artık `runuser -u $SUDO_USER -- env
  DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/<uid>/bus` ile masaüstü kullanıcısı olarak çalıştırır (`runuser` yoksa
  `sudo -u` yoluna düşer). İkisi de yoksa ya da yazma yine başarısız olursa betik başarı taklidi yapmaz: uyarı verir,
  "SOCKS proxy uygulanamadı" hatasıyla sıfırdan farklı çıkış koduyla durur ve kaydettiği durumu geri yükler.
- **GNOME dışı masaüstü (KDE, XFCE...):** `org.gnome.system.proxy` şeması ya da oturum D-Bus hattı yoksa proxy
  `~/.config/environment.d/90-goodbyedpi-turkey.conf` (root'ta `/etc/environment.d/...`) üzerinden yazılır, yeni oturum
  açılışında etkin olur; seçilen arka uç ve nedeni her çalışmada `[i] Proxy arka ucu: ...` satırıyla loglanır.

## Neyin doğrulanmadığı

Bu depoda Linux tarafı yalnızca sözdizimi kontrolü (`make check`) ve stub testleri (`make test`) ile doğrulandı. Gerçek DPI atlatma
davranışı ISS'ye, şehre ve tarihe göre değişir; burada "kesin çalışır" iddiası yok. Bir yöntem sende çalışmıyorsa diğerini dene.
