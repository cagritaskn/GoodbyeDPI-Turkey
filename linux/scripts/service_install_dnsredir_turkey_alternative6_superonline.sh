#!/usr/bin/env bash
# linux karsiligi: windows/service_install_dnsredir_turkey_alternative6_superonline.cmd
# Servis kurulumu: alt6 yontemi. DNS degistirilmez.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
run_method_service_install alt6
