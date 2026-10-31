#!/usr/bin/env bash
# linux/tests/static-checks.sh — syntax gate for the Linux port's shell files.
#
# Usage: static-checks.sh [dir ...]
#
# With no arguments the whole linux/ tree is checked (resolved from this
# script's own location), recursively. Vendored third_party/ clones and
# generated bin/ directories are skipped. Every other *.sh is parsed with
# `bash -n`; nothing is executed.
#
# Exit codes: 0 every file parses, 1 at least one file failed, 2 a directory
# argument does not exist. Self-contained: it does not read or run anything
# outside the directories it is given.
set -euo pipefail

TMP_ERR=""

cleanup() {
    if [ -n "$TMP_ERR" ] && [ -f "$TMP_ERR" ]; then
        rm -f "$TMP_ERR"
    fi
}

if [ "${1:-}" = '-h' ] || [ "${1:-}" = '--help' ]; then
    printf 'usage: %s [dir ...]\n' "${0##*/}" >&2
    exit 0
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
default_dir="$(cd "$script_dir/.." && pwd)"

if [ "$#" -eq 0 ]; then
    set -- "$default_dir"
fi

for dir in "$@"; do
    if [ ! -d "$dir" ]; then
        printf 'err: dizin bulunamadi: %s\n' "$dir" >&2
        exit 2
    fi
done

TMP_ERR="$(mktemp "${TMPDIR:-/tmp}/static-checks.XXXXXX")"
trap cleanup EXIT

total=0
failed=0

while IFS= read -r -d '' file; do
    total=$((total + 1))
    if bash -n "$file" 2>"$TMP_ERR"; then
        continue
    fi
    failed=$((failed + 1))
    printf 'FAIL %s\n' "$file"
    sed 's/^/    /' "$TMP_ERR" >&2
done < <(
    for dir in "$@"; do
        find "$dir" \
            \( -type d \( -name third_party -o -name bin \) -prune \) -o \
            -type f -name '*.sh' -print0
    done | sort -z
)

printf 'static-checks: %d scripts, %d failures\n' "$total" "$failed"

if [ "$failed" -eq 0 ]; then
    exit 0
fi
exit 1
