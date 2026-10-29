#!/usr/bin/env bash
# Stops and removes the systemd service and restores nftables and DNS.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
run_service_remove
