#!/usr/bin/env bash
# linux karsiligi: windows/turkey_dnsredir.cmd
# Tek seferlik calisma: varsayilan yontem (Yandex DNS + split/disorder/tlsrec karmasi). Ctrl-C ile cikince ayarlar geri yuklenir.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
run_method_oneshot default
