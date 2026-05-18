#!/usr/bin/env bash
# macOS karşılığı: turkey_dnsredir_alternative2_superonline.cmd
# (Windows: goodbyedpi.exe -5   — DNS değiştirilmez)
#
# Bu yöntemi kullandıktan SONRA DNS'inizi elle Yandex/Cloudflare'e çevirin.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
run_method_oneshot alt2
