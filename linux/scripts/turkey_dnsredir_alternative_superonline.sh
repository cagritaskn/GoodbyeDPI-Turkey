#!/usr/bin/env bash
# linux karsiligi: windows/turkey_dnsredir_alternative_superonline.cmd
# Tek seferlik: alt yontem. DNS degistirilmez; Windows karsiligi --set-ttl 3 profiline karsilik gelir.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
run_method_oneshot alt
