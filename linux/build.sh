#!/usr/bin/env bash
# Build helper for the Linux port of GoodbyeDPI-Turkey.
#
# This script fetches the upstream byedpi (https://github.com/hufrea/byedpi)
# source into linux/third_party/byedpi when it is not already there, compiles
# it and copies the resulting `ciadpi` binary into linux/bin/.
#
# Why byedpi: WinDivert (used by GoodbyeDPI on Windows) is a Windows-only
# kernel driver and Linux has no equivalent of it in this project, so the
# Linux port drives byedpi instead — a userspace DPI evasion tool that
# implements the same tricks (TLS ClientHello splitting, TCP disorder, OOB
# byte, TLS record splitting, HTTP header mixing) behind a SOCKS5 proxy.

set -euo pipefail

BYEDPI_REPO="${BYEDPI_REPO:-https://github.com/hufrea/byedpi.git}"
BYEDPI_REF="${BYEDPI_REF:-main}"

# Supply-chain pin: the ciadpi binary built here is later executed as root by
# the systemd unit and by the sudo-based runner scripts. Cloning a mutable
# branch alone would mean that a force-push, a branch move or a compromised
# upstream turns straight into root code execution, so the exact upstream
# commit this port was built and reviewed against is pinned below. Never build
# an unpinned tree unless you have reviewed the upstream diff yourself.
# Update this SHA only after that review (verify_commit_pin prints both SHAs).
BYEDPI_COMMIT="${BYEDPI_COMMIT:-ba532298de7b28cfe854aea83d061369d13ca290}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THIRD_PARTY_DIR="${SCRIPT_DIR}/third_party"
BYEDPI_DIR="${THIRD_PARTY_DIR}/byedpi"
BIN_DIR="${SCRIPT_DIR}/bin"

log() { printf '\033[1;34m[build]\033[0m %s\n' "$*"; }
err() { printf '\033[1;31m[build]\033[0m %s\n' "$*" >&2; }

if [[ "$(uname -s)" != "Linux" ]]; then
    err "This build helper targets Linux only."
    err "On macOS use macos/build.sh; on Windows build src/ with MinGW."
    exit 1
fi

for tool in git make cc; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        err "Required tool '$tool' is missing."
        err "Install it with your package manager, e.g. 'apt install git make gcc'."
        exit 1
    fi
done

mkdir -p "$THIRD_PARTY_DIR" "$BIN_DIR"

if [[ ! -d "$BYEDPI_DIR/.git" ]]; then
    log "Fetching byedpi from ${BYEDPI_REPO} (ref: ${BYEDPI_REF})"
    git clone --depth 1 --branch "$BYEDPI_REF" "$BYEDPI_REPO" "$BYEDPI_DIR"
else
    log "byedpi already cloned at ${BYEDPI_DIR} — skipping clone"
    log "(delete the dir to re-clone at ${BYEDPI_REF}, then update BYEDPI_COMMIT below)"
fi

# Refuse to compile anything that is not the pinned commit.
actual_commit="$(git -C "$BYEDPI_DIR" rev-parse HEAD)"
if [[ "$actual_commit" != "$BYEDPI_COMMIT" ]]; then
    if [[ "${BYEDPI_ALLOW_UNPINNED:-}" == "1" ]]; then
        err "WARNING: commit pin BYPASSED (BYEDPI_ALLOW_UNPINNED=1)."
        err "  expected: ${BYEDPI_COMMIT}"
        err "  actual:   ${actual_commit}"
        err "The resulting binary will run as root. Only continue if you reviewed the upstream diff."
    else
        err "byedpi commit does not match the pin — refusing to build."
        err "  expected (BYEDPI_COMMIT in this script): ${BYEDPI_COMMIT}"
        err "  actual   (HEAD of ${BYEDPI_DIR}):       ${actual_commit}"
        err "The clone is deleted so an unreviewed tree can never be compiled by accident."
        err "To move the pin after reviewing the upstream changes: edit BYEDPI_COMMIT in"
        err "  ${SCRIPT_DIR}/build.sh   (or run: BYEDPI_COMMIT=${actual_commit} ./build.sh)"
        err "To build this unpinned tree anyway: BYEDPI_ALLOW_UNPINNED=1 ./build.sh"
        rm -rf "$BYEDPI_DIR"
        exit 1
    fi
else
    log "pinned commit verified: ${actual_commit}"
fi

JOBS="$(nproc 2>/dev/null || echo 1)"

log "Building ciadpi for $(uname -m) with ${JOBS} job(s)"
make -C "$BYEDPI_DIR" -j"$JOBS"

if [[ ! -x "$BYEDPI_DIR/ciadpi" ]]; then
    err "Build appears to have failed: $BYEDPI_DIR/ciadpi is missing or not executable."
    exit 1
fi

cp -f "$BYEDPI_DIR/ciadpi" "$BIN_DIR/ciadpi"
chmod +x "$BIN_DIR/ciadpi"

log "Built binary: ${BIN_DIR}/ciadpi"
log "Done. Run 'make help' in ${SCRIPT_DIR} to list the available targets."
