#!/usr/bin/env bash
# linux karsiligi: windows/service_remove.cmd
# systemd servisini kaldirir ve proxy/DNS ayarlarini kurulumdan onceki haline dondurur.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
run_service_remove
