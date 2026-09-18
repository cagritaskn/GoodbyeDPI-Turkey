#!/usr/bin/env bash
# macOS karşılığı: turkey_dnsredir_alternative_superonline.cmd
# (Windows: goodbyedpi.exe --set-ttl 3   — DNS değiştirilmez)
#
# Tek seferlik çalıştırır, sistem DNS'ine dokunmaz. SOCKS proxy'sini
# 127.0.0.1:1080 olarak ayarlar; çıkıldığında ayar otomatik kaldırılır.
# Bu yöntemi kullandıktan SONRA macOS'ta DNS'i elle Yandex/Cloudflare'e
# çevirmeyi unutmayın (System Settings -> Network -> aktif servis -> DNS).

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
run_method_oneshot alt
