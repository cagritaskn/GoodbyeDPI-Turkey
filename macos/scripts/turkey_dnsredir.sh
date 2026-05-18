#!/usr/bin/env bash
# macOS karşılığı: turkey_dnsredir.cmd  (varsayılan yöntem, TTL=5 + Yandex DNS)
#
# GoodbyeDPI-Turkey'i tek seferlik olarak çalıştırır. Bu komut dosyası bir
# terminal penceresinde ciadpi'yi başlatır, sistem genelinde SOCKS proxy'sini
# 127.0.0.1:1080 olarak ayarlar ve DNS sunucularını Yandex DNS olarak değiştirir.
# Ctrl-C ile veya terminali kapatarak durdurabilirsiniz; çıkıldığında tüm
# ağ ayarları otomatik olarak eski haline döner.
#
# NOT: Windows'taki "fake packet + low TTL" tekniği macOS'ta mevcut değil;
# bu yüzden burada split + disorder + tlsrec + HTTP header karıştırma
# karması kullanılıyor. Ayrıntılar için macos/README.md.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
run_method_oneshot default
