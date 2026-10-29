#!/usr/bin/env bash
# Installs the "alt5" method as a systemd service that starts at boot.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
run_method_service_install alt5
