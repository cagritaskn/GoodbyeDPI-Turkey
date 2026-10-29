# GoodbyeDPI-Turkey — Linux

macOS sürümü gibi [byedpi](https://github.com/hufrea/byedpi) kullanır. Fark:
proxy ayarı gerekmez, tüm programlar otomatik kapsanır. Yöntemler macOS ile
aynıdır.

## Kurulum

```bash
sudo apt install git build-essential   # Fedora: dnf install git make gcc
./linux/build.sh
```

## Kullanım

```bash
sudo ./linux/scripts/turkey_dnsredir.sh                    # tek seferlik, Ctrl-C ile durur
sudo ./linux/scripts/service_install_dnsredir_turkey.sh    # açılışta otomatik başlar
sudo ./linux/scripts/service_remove.sh                     # kaldırır, ayarları geri alır
```

Diğer yöntemler (`alternative*`) macOS'takiyle aynı isimlerle duruyor.

## Split tunnel

Sadece listedeki siteleri etkiler, diğerleri normal açılır.
Liste: `/etc/goodbyedpi-turkey/split-tunnel-domains.txt`

```bash
sudo ./linux/scripts/split_tunnel.sh on    # veya off, status
```

## Docker ve WSL

Windows'taki GoodbyeDPI, WSL'in trafiğini görmez; bu sürümü WSL içinde
çalıştırın. Container'lar için ağlarını `FORWARD_SOURCES` ile ekleyin:

```bash
# Sadece bir Docker ağı, sadece listedeki siteler
sudo SPLIT_TUNNEL=1 REDIRECT_LOCAL=0 FORWARD_SOURCES="172.18.0.0/16" DNS_MODE=off \
    ./linux/scripts/turkey_dnsredir.sh
```

Ayarlar `/etc/goodbyedpi-turkey/config.env` dosyasında da tutulabilir.

## Sorun giderme

- Çalışıyor mu: `sudo nft list table inet goodbyedpi_turkey`
- Site açılmıyor: split tunnel'ı açın veya başka bir yöntem deneyin.
- Çökme sonrası kurallar kaldı: `sudo ./linux/scripts/service_remove.sh`
