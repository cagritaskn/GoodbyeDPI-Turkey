#!/usr/bin/env bash
# macOS karşılığı: service_install_dnsredir_turkey_alternative2_superonline.cmd
# (Windows: goodbyedpi.exe -5   — DNS sistemce değiştirilmez)

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
run_method_service_install alt2
