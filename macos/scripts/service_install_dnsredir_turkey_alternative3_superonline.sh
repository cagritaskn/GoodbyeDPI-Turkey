#!/usr/bin/env bash
# macOS karşılığı: service_install_dnsredir_turkey_alternative3_superonline.cmd
# (Windows: goodbyedpi.exe --set-ttl 3 --dns-addr Yandex)

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
run_method_service_install alt3
