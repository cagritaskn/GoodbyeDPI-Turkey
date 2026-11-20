#!/usr/bin/env bash
# macOS karşılığı: turkey_dnsredir_alternative5_superonline.cmd
# (Windows: goodbyedpi.exe -9 --dns-addr 9.9.9.9 ...)
#
# Quad9 DNS otomatik atanır.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
run_method_oneshot alt5
