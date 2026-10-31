#!/usr/bin/env bash
# Syntax gate for every shell script in this repo.
#
# Usage: macos/tests/static-checks.sh [dir ...]
#   Runs `bash -n` on every *.sh found recursively under each dir.
#   Default dir: macos/ (resolved relative to the repo root).
#   Paths containing /third_party/ or /bin/ are skipped (vendored code and
#   build output are not ours to lint).
#
# Output is deliberately compact: only failures are printed, one FAIL line
# plus the captured stderr, then a single summary line.
#
# Exit codes:
#   0  every script parses
#   1  at least one script failed `bash -n`
#   2  usage error (a given dir does not exist)
#
# shellcheck is not available here, so `bash -n` is the only syntax gate.
# Kept Bash 3.2 compatible (macOS ships /bin/bash 3.2): no mapfile,
# no readarray, no ${var,,}, no associative arrays.

set -u

# Resolve repo-relative paths the same way macos/scripts/_lib.sh does.
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
MACOS_DIR="$(cd "${TESTS_DIR}/.." && pwd)"
REPO_DIR="$(cd "${MACOS_DIR}/.." && pwd)"

usage() {
    printf 'usage: %s [dir ...]\n' "${0##*/}"
    printf '  Runs bash -n on every *.sh under each dir (default: %s)\n' "${REPO_DIR}/macos"
    printf '  Skips paths containing /third_party/ or /bin/\n'
}

if [[ $# -gt 0 ]]; then
    dirs=("$@")
else
    dirs=("${REPO_DIR}/macos")
fi

i=0
while [[ $i -lt ${#dirs[@]} ]]; do
    d="${dirs[$i]}"
    if [[ "$d" == "-h" || "$d" == "--help" ]]; then
        usage
        exit 0
    fi
    if [[ ! -d "$d" ]]; then
        printf 'static-checks: not a directory: %s\n' "$d" >&2
        usage >&2
        exit 2
    fi
    i=$((i + 1))
done

total=0
failures=0

i=0
while [[ $i -lt ${#dirs[@]} ]]; do
    dir="${dirs[$i]}"
    # find | sort keeps the output order stable; the while-read loop avoids
    # mapfile/readarray, which Bash 3.2 does not have.
    while IFS= read -r f; do
        case "$f" in
            */third_party/*|*/bin/*) continue ;;
        esac
        total=$((total + 1))
        stderr_out="$(bash -n "$f" 2>&1)"
        rc=$?
        if [[ $rc -ne 0 ]]; then
            failures=$((failures + 1))
            printf 'FAIL %s\n' "$f"
            if [[ -n "$stderr_out" ]]; then
                printf '%s\n' "$stderr_out"
            fi
        fi
    done < <(find "$dir" -type f -name '*.sh' | sort)
    i=$((i + 1))
done

printf 'static-checks: %d scripts, %d failures\n' "$total" "$failures"

if [[ $failures -gt 0 ]]; then
    exit 1
fi
exit 0
