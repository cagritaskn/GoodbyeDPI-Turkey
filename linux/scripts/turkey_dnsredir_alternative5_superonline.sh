#!/usr/bin/env bash
# linux karsiligi: windows/turkey_dnsredir_alternative5_superonline.cmd
# Tek seferlik: alt5 yontemi (Yandex DNS). Windows karsiligi -9 + Yandex DNS.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
run_method_oneshot alt5
