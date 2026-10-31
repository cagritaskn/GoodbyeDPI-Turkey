#!/usr/bin/env bash
# linux karsiligi: windows/service_install_dnsredir_turkey_alternative3_superonline.cmd
# Servis kurulumu: alt3 yontemi (Yandex DNS).

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
run_method_service_install alt3
