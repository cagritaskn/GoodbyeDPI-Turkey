#!/usr/bin/env bash
# Build helper for the macOS port of GoodbyeDPI-Turkey.
#
# This script fetches the upstream byedpi (https://github.com/hufrea/byedpi)
# source — which is the cross-platform DPI bypass tool we use under the hood
# on macOS — into macos/third_party/byedpi if it is not already there, then
# compiles it and copies the resulting `ciadpi` binary into macos/bin/.
#
# Why byedpi: WinDivert (used by GoodbyeDPI on Windows) is a Windows-only
# kernel driver. On macOS there is no equivalent, so we use byedpi which
# implements the same DPI evasion techniques (TLS ClientHello splitting,
# TCP disorder, OOB byte, TLS record splitting, HTTP header mixing)
# as a pure userspace SOCKS5 proxy. Some Windows-only tricks
# (`--fake` / `--ttl`) are not available on macOS — see macos/README.md.

set -euo pipefail

BYEDPI_REPO="${BYEDPI_REPO:-https://github.com/hufrea/byedpi.git}"
BYEDPI_REF="${BYEDPI_REF:-main}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THIRD_PARTY_DIR="${SCRIPT_DIR}/third_party"
BYEDPI_DIR="${THIRD_PARTY_DIR}/byedpi"
BIN_DIR="${SCRIPT_DIR}/bin"

log() { printf '\033[1;34m[build]\033[0m %s\n' "$*"; }
err() { printf '\033[1;31m[build]\033[0m %s\n' "$*" >&2; }

if [[ "$(uname -s)" != "Darwin" ]]; then
    err "This build script targets macOS (Darwin) only."
    err "On Windows, use the Makefile in src/ — see the project README."
    exit 1
fi

for tool in git make cc; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        err "Required tool '$tool' is missing."
        err "Install Xcode Command Line Tools:  xcode-select --install"
        exit 1
    fi
done

mkdir -p "$THIRD_PARTY_DIR" "$BIN_DIR"

if [[ ! -d "$BYEDPI_DIR/.git" ]]; then
    log "Fetching byedpi from ${BYEDPI_REPO} (ref: ${BYEDPI_REF})"
    git clone --depth 1 --branch "$BYEDPI_REF" "$BYEDPI_REPO" "$BYEDPI_DIR"
else
    log "byedpi already cloned at ${BYEDPI_DIR} — skipping clone"
    log "(use 'git -C ${BYEDPI_DIR} pull' to update, or delete the dir to re-clone)"
fi

log "Building ciadpi for $(uname -m)"
make -C "$BYEDPI_DIR" -j"$(sysctl -n hw.ncpu)" clean
make -C "$BYEDPI_DIR" -j"$(sysctl -n hw.ncpu)"

if [[ ! -x "$BYEDPI_DIR/ciadpi" ]]; then
    err "Build appears to have failed: $BYEDPI_DIR/ciadpi is missing or not executable."
    exit 1
fi

cp -f "$BYEDPI_DIR/ciadpi" "$BIN_DIR/ciadpi"
chmod +x "$BIN_DIR/ciadpi"

# IMPORTANT (Apple Silicon especially): clang writes an "adhoc,linker-signed"
# code signature on the freshly compiled binary. That signature is brittle:
# `cp` produces a byte-identical copy but AMFI (Apple Mobile File Integrity)
# treats the copy's signature as invalid and SIGKILLs the process the moment
# it tries to execute (you see "Killed: 9" in the shell, and launchd reports
# "last exit reason = OS_REASON_CODESIGNING" for the LaunchDaemon).
#
# Re-signing the copy with a regular ad-hoc signature (no "linker-signed"
# flag) avoids this. No Apple Developer account is needed — `-s -` means
# "ad-hoc, no identity", which is what unsigned local builds use everywhere.
if command -v codesign >/dev/null 2>&1; then
    log "Re-signing the copy with an ad-hoc signature (Apple Silicon AMFI fix)"
    codesign --force --sign - \
        --identifier com.cagritaskn.goodbyedpi-turkey.ciadpi \
        "$BIN_DIR/ciadpi"
else
    err "WARNING: 'codesign' not found. On Apple Silicon the binary may be"
    err "         killed at startup with 'Killed: 9' due to invalid signature."
fi

log "Built binary: ${BIN_DIR}/ciadpi"
"$BIN_DIR/ciadpi" --help 2>&1 | head -1 || true

log "Done. Next steps:"
log "  - One-shot:  sudo ./macos/scripts/turkey_dnsredir.sh"
log "  - Service :  sudo ./macos/scripts/service_install_dnsredir_turkey.sh"
log "  - Remove  :  sudo ./macos/scripts/service_remove.sh"
