#!/usr/bin/env bash
# linux karsiligi: windows/turkey_dnsredir_alternative6_superonline.cmd
# Tek seferlik: alt6 yontemi. DNS degistirilmez; Windows karsiligi -9 profiline karsilik gelir.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
run_method_oneshot alt6
