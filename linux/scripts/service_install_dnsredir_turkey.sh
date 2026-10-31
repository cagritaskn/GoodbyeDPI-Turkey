#!/usr/bin/env bash
# linux karsiligi: windows/service_install_dnsredir_turkey.cmd
# Sistem her acildiginda calisan systemd servisi kurar: varsayilan yontem (Yandex DNS).

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
run_method_service_install default
