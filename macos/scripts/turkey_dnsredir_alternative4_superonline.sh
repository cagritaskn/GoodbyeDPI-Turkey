#!/usr/bin/env bash
# macOS karşılığı: turkey_dnsredir_alternative4_superonline.cmd
# (Windows: goodbyedpi.exe -5 --dns-addr 77.88.8.8 ...)
#
# Yandex DNS otomatik atanır.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
run_method_oneshot alt4
