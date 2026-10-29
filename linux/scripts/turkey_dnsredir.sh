#!/usr/bin/env bash
# One-shot: runs the "default" method until Ctrl-C, then restores everything.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
run_method_oneshot default
