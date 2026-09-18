# GoodbyeDPI-Turkey — macOS Sürümü

Bu klasör, [GoodbyeDPI-Turkey](../README.md) projesinin macOS karşılığını içerir.
Windows tarafındaki `src/` ve `windows/` klasörleri olduğu gibi durmaktadır;
bu macOS port'u onları hiçbir şekilde değiştirmez.

## Önemli farklar (önce bunları okuyun)

GoodbyeDPI, Windows'a özel olan **WinDivert** sürücüsünü kullanır. macOS'ta
böyle bir sürücü yoktur, bu yüzden tam aynı kod buraya taşınamaz. Onun
yerine bu port, aynı DPI atlatma tekniklerini saf userspace SOCKS5 proxy
olarak uygulayan **[byedpi (`ciadpi`)](https://github.com/hufrea/byedpi)**
aracını kullanır.

Sonuçlar olarak:

- TLS ClientHello bölme (`--split`), ters sıralı segment gönderme
  (`--disorder`), TLS kayıt bölme (`--tlsrec`), OOB byte (`--oob`) ve
  HTTP başlık karıştırma (`--mod-http`) **çalışır**.
- Windows'ta GoodbyeDPI'ın kullandığı **"sahte paket + düşük TTL"**
  hilesi (`--set-ttl`, `--auto-ttl`, `--fake-from-hex`) byedpi'da BSD/macOS
  için desteklenmez. Onun yerine yukarıdaki tekniklerin daha agresif
  kombinasyonu kullanılır.
- Tüm scripts'ler ve hizmet yapısı, Windows tarafındaki .cmd dosyalarını
  bire bir mantıkla yansıtır (tek seferlik çalıştırma + `launchd`
  LaunchDaemon ile otomatik başlatma).

Eğer kullandığınız ISS bu macOS sürümünde belirli sitelerle çalışmıyorsa,
Windows'ta da işe yarayan TTL-tabanlı yöntemler tek başına çalışıyor olabilir.
O durumda alternatif olarak şu projelere de göz atabilirsiniz: **SpoofDPI**,
**Throne** (TUN tabanlı, Roblox/Discord için byedpi'yi sarmalar), **zapret**.

## Gereksinimler

- macOS 12 (Monterey) veya üstü, Intel veya Apple Silicon.
- Xcode Command Line Tools: `xcode-select --install`
- Yönetici (sudo) şifresi.

## Kurulum (kaynaktan)

```bash
git clone https://github.com/cagritaskn/GoodbyeDPI-Turkey.git
cd GoodbyeDPI-Turkey
./macos/build.sh
```

`build.sh`:

1. byedpi kaynak kodunu `macos/third_party/byedpi` altına klonlar (ilk seferde),
2. `ciadpi` ikilisini derler,
3. Derlenen ikiliyi `macos/bin/ciadpi`'ye kopyalar.

## Kullanım — Tek Seferlik (Windows'taki `turkey_dnsredir.cmd` karşılığı)

Aşağıdakilerden birini terminalde çalıştırın. Script root yetkisi ister, gerekirse
otomatik olarak `sudo` ile yeniden başlar. Ctrl-C ile çıktığınızda SOCKS proxy
ve DNS ayarları **otomatik olarak eski haline döner**.

```bash
sudo ./macos/scripts/turkey_dnsredir.sh                                  # varsayılan yöntem (Yandex DNS)
sudo ./macos/scripts/turkey_dnsredir_alternative_superonline.sh          # DNS değiştirmez
sudo ./macos/scripts/turkey_dnsredir_alternative2_superonline.sh         # DNS değiştirmez
sudo ./macos/scripts/turkey_dnsredir_alternative3_superonline.sh         # Yandex DNS
sudo ./macos/scripts/turkey_dnsredir_alternative4_superonline.sh         # Yandex DNS
sudo ./macos/scripts/turkey_dnsredir_alternative5_superonline.sh         # Yandex DNS
sudo ./macos/scripts/turkey_dnsredir_alternative6_superonline.sh         # DNS değiştirmez
```

## Kullanım — Hizmet Olarak (Windows'taki `service_install_*.cmd` karşılığı)

Bilgisayar açıldığında otomatik başlayan bir LaunchDaemon kurar:

```bash
sudo ./macos/scripts/service_install_dnsredir_turkey.sh                  # varsayılan
sudo ./macos/scripts/service_install_dnsredir_turkey_alternative_superonline.sh
sudo ./macos/scripts/service_install_dnsredir_turkey_alternative2_superonline.sh
sudo ./macos/scripts/service_install_dnsredir_turkey_alternative3_superonline.sh
sudo ./macos/scripts/service_install_dnsredir_turkey_alternative4_superonline.sh
sudo ./macos/scripts/service_install_dnsredir_turkey_alternative5_superonline.sh
sudo ./macos/scripts/service_install_dnsredir_turkey_alternative6_superonline.sh
```

Kaldırmak için (proxy ve DNS ayarlarını da eski haline döndürür):

```bash
sudo ./macos/scripts/service_remove.sh
```

Hizmetin durumunu kontrol etmek için:

```bash
sudo launchctl print system/com.cagritaskn.goodbyedpi-turkey
tail -f /var/log/goodbyedpi-turkey.log
```

## Split tunnel — sadece belirli siteleri ciadpi'den geçirme

Yukarıdaki scripts'ler sistem geneli SOCKS proxy'si kurar, yani **tüm** TLS
trafiği desync'ten geçer. Bu, engelli olmayan siteleri de bozabilir: bölünmüş
ClientHello'yu reddeden sunucular olur (`sahibinden.com` → `sslv3 alert
illegal parameter`, `vercel.com` → timeout).

`split_tunnel.sh`, sistem geneli SOCKS ayarını bir PAC dosyasıyla değiştirir;
sadece `macos/split-tunnel-domains.txt` içindeki domainler ciadpi'ye gider,
kalan her şey doğrudan bağlanır. Bir `service_install_*` scripti kurduktan
sonra çalıştırın:

```bash
sudo ./macos/scripts/split_tunnel.sh on      # PAC'a geç
sudo ./macos/scripts/split_tunnel.sh status  # servis servis mevcut durum
sudo ./macos/scripts/split_tunnel.sh off     # sistem geneli SOCKS'a dön
```

Domain listesi ilk çalıştırmada `/usr/local/etc/goodbyedpi-turkey/` altına
kopyalanır; listeyi orada düzenleyip tekrar `on` çalıştırın. Bir sitenin
gerçekten engelli olup olmadığını `curl -s -o /dev/null -w "%{http_code}"
--noproxy '*' https://site` ile kontrol edin — `000` dönüyorsa listeye ekleyin.

DNS ayarı değişmez: ISS resolver'ı `discord.com`'u engel IP'sine çözdüğü için
Yandex DNS split tunnel modunda da gereklidir.

## Yöntem ↔ Argüman Eşlemesi

| Yöntem (Windows)                          | Windows args                       | macOS byedpi args                                          | DNS         |
|-------------------------------------------|------------------------------------|------------------------------------------------------------|-------------|
| `turkey_dnsredir`                         | `-5 --set-ttl 5 --dns-addr Y`      | `--split 1+s --disorder 3+s --tlsrec 3+s --mod-http h,d`   | Yandex      |
| `turkey_dnsredir_alternative_superonline` | `--set-ttl 3`                      | `--disorder 3+s --tlsrec 3+s`                              | değiştirmez |
| `turkey_dnsredir_alternative2_*`          | `-5`                               | `--split 1+s --disorder 3+s --mod-http h,d`                | değiştirmez |
| `turkey_dnsredir_alternative3_*`          | `--set-ttl 3 --dns-addr Y`         | `--disorder 1+s --tlsrec 1+s`                              | Yandex      |
| `turkey_dnsredir_alternative4_*`          | `-5 --dns-addr Y`                  | `--split 1+s --disorder 3+s --mod-http h,d`                | Yandex      |
| `turkey_dnsredir_alternative5_*`          | `-9 --dns-addr Y`                  | `--split 1+s --tlsrec 1+s --mod-http h,d`                  | Yandex      |
| `turkey_dnsredir_alternative6_*`          | `-9`                               | `--split 1+s --tlsrec 1+s`                                 | değiştirmez |

> `h,d` = `hcsmix,dcsmix` (HTTP Host başlığını karıştırır)
> Y = Yandex DNS (`77.88.8.8` / `77.88.8.1`)
>
> Bu eşlemeleri kendi ISS'niz için iyileştirmek isterseniz
> `macos/scripts/_lib.sh` içindeki `method_args` fonksiyonunu düzenleyin —
> tüm scripts'ler bu fonksiyonu paylaşır.

## Ayarları manuel inceleme

```bash
# Aktif servisin adını bulun (Wi-Fi, Ethernet, ...)
networksetup -listallnetworkservices

# Mevcut SOCKS proxy + DNS durumunu görün
networksetup -getsocksfirewallproxy "Wi-Fi"
networksetup -getdnsservers          "Wi-Fi"

# Geri al (eğer scripts ile değil de elle ayarladıysanız)
sudo networksetup -setsocksfirewallproxystate "Wi-Fi" off
sudo networksetup -setdnsservers              "Wi-Fi" Empty
```

## Sorun giderme

- **"Operation not permitted" hatası**: Script'i mutlaka `sudo` ile çalıştırın.
  Script kendiliğinden sudo'ya geçer ama yine de yönetici şifresi sorulur.
- **"ciadpi bulunamadı"**: Önce `./macos/build.sh` çalıştırın.
- **Uygulamalar proxy'i kullanmıyor**: macOS'taki sistem genelinde SOCKS proxy
  ayarı çoğu uygulama tarafından otomatik kullanılır. Bazı uygulamalar
  (örn. Chrome belirli sürümler, bazı oyunlar) sistem proxy'sini yok sayar.
  Bu durumda söz konusu uygulamanın ayarlarından proxy'yi elle
  `127.0.0.1:1080` olarak ayarlamanız gerekebilir.
- **DNS sızıntısı**: SOCKS5 default olarak DNS sorgularını uzaktan çözer ama
  bazı uygulamalar DNS'i kendi başına yapar. Bu yüzden script default yöntemde
  sistem DNS'ini Yandex'e ayarlar.
