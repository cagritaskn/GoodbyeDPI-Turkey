#!/usr/bin/env bash
# Build helper for the Linux port of GoodbyeDPI-Turkey.
#
# Fetches byedpi (https://github.com/hufrea/byedpi) into
# linux/third_party/byedpi, compiles ciadpi and copies it into linux/bin/.
# Same approach as macos/build.sh: WinDivert is Windows-only, and byedpi
# implements the same DPI evasion techniques in userspace. On Linux it also
# runs as a transparent proxy, which the scripts in linux/scripts/ rely on.
#
# Set LDFLAGS=-static for a binary that runs on any distribution.

set -euo pipefail

BYEDPI_REPO="${BYEDPI_REPO:-https://github.com/hufrea/byedpi.git}"
# Pinned: the scripts use --transparent and --hosts as documented in this tag.
BYEDPI_REF="${BYEDPI_REF:-v0.17.3}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THIRD_PARTY_DIR="${SCRIPT_DIR}/third_party"
BYEDPI_DIR="${THIRD_PARTY_DIR}/byedpi"
BIN_DIR="${SCRIPT_DIR}/bin"

log() { printf '\033[1;34m[build]\033[0m %s\n' "$*"; }
err() { printf '\033[1;31m[build]\033[0m %s\n' "$*" >&2; }

if [[ "$(uname -s)" != "Linux" ]]; then
    err "This build script targets Linux only."
    err "On macOS use macos/build.sh; on Windows use the Makefile in src/."
    exit 1
fi

for tool in git make cc; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        err "Required tool '$tool' is missing."
        err "Debian/Ubuntu: sudo apt install git build-essential"
        err "Fedora       : sudo dnf install git make gcc"
        err "Arch         : sudo pacman -S git base-devel"
        err "Alpine       : apk add bash git make gcc musl-dev linux-headers"
        exit 1
    fi
done

mkdir -p "$THIRD_PARTY_DIR" "$BIN_DIR"

if [[ ! -d "$BYEDPI_DIR/.git" ]]; then
    log "Fetching byedpi from ${BYEDPI_REPO} (ref: ${BYEDPI_REF})"
    git clone --depth 1 --branch "$BYEDPI_REF" "$BYEDPI_REPO" "$BYEDPI_DIR"
else
    log "byedpi already cloned at ${BYEDPI_DIR} — skipping clone"
    log "(delete the dir to re-clone, or set BYEDPI_REF to build another ref)"
fi

jobs="$(nproc 2>/dev/null || echo 2)"
log "Building ciadpi for $(uname -m)"
make -C "$BYEDPI_DIR" -j"$jobs" clean
make -C "$BYEDPI_DIR" -j"$jobs"

if [[ ! -x "$BYEDPI_DIR/ciadpi" ]]; then
    err "Build appears to have failed: $BYEDPI_DIR/ciadpi is missing or not executable."
    exit 1
fi

cp -f "$BYEDPI_DIR/ciadpi" "$BIN_DIR/ciadpi"
chmod +x "$BIN_DIR/ciadpi"

log "Built binary: ${BIN_DIR}/ciadpi"
"$BIN_DIR/ciadpi" --version 2>&1 | head -1 || true

log "Done. Next steps:"
log "  - One-shot:  sudo ./linux/scripts/turkey_dnsredir.sh"
log "  - Service :  sudo ./linux/scripts/service_install_dnsredir_turkey.sh"
log "  - Remove  :  sudo ./linux/scripts/service_remove.sh"
