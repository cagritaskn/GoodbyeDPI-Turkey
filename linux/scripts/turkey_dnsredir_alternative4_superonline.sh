#!/usr/bin/env bash
# linux karsiligi: windows/turkey_dnsredir_alternative4_superonline.cmd
# Tek seferlik: alt4 yontemi (Yandex DNS). Windows karsiligi -5 + Yandex DNS.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
run_method_oneshot alt4
