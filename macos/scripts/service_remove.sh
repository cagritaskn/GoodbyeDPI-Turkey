#!/usr/bin/env bash
# macOS karşılığı: service_remove.cmd
#
# GoodbyeDPI-Turkey launchd hizmetini kaldırır ve SOCKS proxy + DNS ayarlarını
# kurulumdan önceki haline döndürür.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
run_service_remove
