#!/usr/bin/env bash
# linux karsiligi: windows/turkey_dnsredir_alternative3_superonline.cmd
# Tek seferlik: alt3 yontemi (Yandex DNS). Windows karsiligi --set-ttl 3 + Yandex DNS.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
run_method_oneshot alt3
