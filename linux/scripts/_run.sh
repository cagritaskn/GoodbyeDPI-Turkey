#!/usr/bin/env bash
# Entry point of the systemd service: runs one method until the unit stops.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
run_ciadpi "${1:?yöntem adı gerekli}"
