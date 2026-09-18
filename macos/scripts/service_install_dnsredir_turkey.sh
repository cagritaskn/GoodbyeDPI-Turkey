#!/usr/bin/env bash
# macOS karşılığı: service_install_dnsredir_turkey.cmd
# (Varsayılan yöntem — Yandex DNS + TTL=5 stili karma)
#
# Bilgisayar her açıldığında otomatik olarak çalışan bir launchd LaunchDaemon
# kurar. SOCKS proxy'sini ve DNS'i sistem genelinde ayarlar. Kaldırmak için
# service_remove.sh kullanın.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
run_method_service_install default
