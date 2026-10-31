#!/usr/bin/env bash
# linux/tests/lib-test.sh — stub-based unit tests for linux/scripts/_lib.sh.
#
# The library is sourced, never executed. Every command that would mutate the
# real system (ciadpi, resolvectl, gsettings, systemctl, iptables, nft, ip,
# ipset, cp) is shadowed by a stub in a throw-away directory that only records
# its argv. `tee` is stubbed too because the library pipes state files through
# it. `mkdir` and `chmod` stay real, but they only ever see paths inside the
# sandbox. No root, no network, no systemd, no real DNS/proxy/firewall change.
#
# `set -e` is deliberately absent: several assertions expect a command to fail.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_FILE="$SCRIPT_DIR/../scripts/_lib.sh"

if [ ! -r "$LIB_FILE" ]; then
    printf 'err: kutuphane bulunamadi: %s\n' "$LIB_FILE" >&2
    exit 2
fi

TMP="$(mktemp -d "${TMPDIR:-/tmp}/lib-test.XXXXXX")"
cleanup() {
    rm -rf "$TMP"
}
trap cleanup EXIT

RESULTS="$TMP/results.log"
: > "$RESULTS"
export CALLS_LOG="$TMP/calls.log"
: > "$CALLS_LOG"

# --------------------------------------------------------------------------
# Assertion helpers — all of them use shell builtins only, so they also work
# in the sub-shell where PATH points at a single stub directory.
# --------------------------------------------------------------------------

pass() {
    printf 'ok: %s\n' "$1"
    printf 'ok %s\n' "$1" >>"$RESULTS"
}

fail() {
    printf 'fail: %s\n' "$1"
    printf 'fail %s\n' "$1" >>"$RESULTS"
}

check_eq() { # <name> <expected> <actual>
    if [ "$2" = "$3" ]; then
        pass "$1"
    else
        fail "$1 (beklenen: [$2], gelen: [$3])"
    fi
}

check_has() { # <name> <haystack> <needle>
    case "$2" in
        *"$3"*) pass "$1" ;;
        *) fail "$1 (eksik: [$3])" ;;
    esac
}

check_has_not() { # <name> <haystack> <needle>
    case "$2" in
        *"$3"*) fail "$1 (olmamaliydi: [$3])" ;;
        *) pass "$1" ;;
    esac
}

calls() { # recorded stub argv, builtins only
    local line out=''
    if [ ! -f "$CALLS_LOG" ]; then
        return 0
    fi
    while IFS= read -r line; do
        out="$out$line"$'\n'
    done <"$CALLS_LOG"
    printf '%s' "$out"
}

calls_reset() { : >"$CALLS_LOG"; }

# --------------------------------------------------------------------------
# Stubs
# --------------------------------------------------------------------------

STUB_BIN="$TMP/bin"
STUB_BIN_NFT="$TMP/bin-nft"
mkdir -p "$STUB_BIN" "$STUB_BIN_NFT"

write_stub() { # <dir> <name>
    local dir="$1" name="$2"
    cat >"$dir/$name" <<'STUB'
#!/bin/bash
# Test stub: record argv, never touch the real system.
name=${0##*/}
printf '%s %s\n' "$name" "$*" >>"${CALLS_LOG:-/dev/null}"
case "$name" in
    tee)
        # `_write_file` calls `run tee <path>`: the first argv element is the
        # path (not $2), so behave like `tee <path> >/dev/null`.
        if [ -n "${1:-}" ]; then
            cat >"$1"
        fi
        ;;
    iptables|ip6tables)
        # `-C` probes whether a rule exists; report "missing" so the library
        # takes the add path. `-L` probes whether the chain exists -> 0.
        case " $* " in
            *' -C '*) exit 1 ;;
            # `-D` can be made to fail on purpose (teardown tolerance tests).
            *' -D '*) exit "${STUB_IPT_DELETE_RC:-0}" ;;
        esac
        ;;
    ip)
        # detect_default_iface reads `ip route show default`.
        if [ -n "${STUB_IP_ROUTE:-}" ]; then
            printf '%s\n' "$STUB_IP_ROUTE"
        fi
        ;;
    resolvectl)
        if [ "${1:-}" = status ] && [ -n "${STUB_RESOLVECTL_STATUS:-}" ]; then
            printf '%s\n' "$STUB_RESOLVECTL_STATUS"
        fi
        ;;
    systemctl)
        # `is-active --quiet` is the health-check probe; STUB_SYSTEMCTL_ACTIVE
        # lets a test claim the unit never came up.
        case " $* " in
            *' is-active '*) exit "${STUB_SYSTEMCTL_ACTIVE:-0}" ;;
        esac
        ;;
    ss)
        # Nothing binds a socket in the sandbox, so the port is only reported
        # as listening when the test asks for it (STUB_SS_LISTEN=1).
        if [ "${STUB_SS_LISTEN:-0}" = '1' ]; then
            printf 'State Recv-Q Send-Q Local Address:Port Peer Address:Port Process\n'
            printf 'LISTEN 0      4096    127.0.0.1:1080      0.0.0.0:*\n'
        fi
        ;;
    journalctl)
        if [ -n "${STUB_JOURNAL_LINES:-}" ]; then
            printf '%s\n' "$STUB_JOURNAL_LINES"
        fi
        ;;
    gsettings)
        if [ "${1:-}" = list-schemas ] && [ -n "${STUB_GSETTINGS_SCHEMA:-}" ]; then
            printf '%s\n' 'org.gnome.system.proxy'
        fi
        ;;
esac
exit 0
STUB
    chmod +x "$dir/$name"
}

for stub in ciadpi resolvectl gsettings systemctl iptables ip6tables nft ip ipset ss journalctl tee cp; do
    write_stub "$STUB_BIN" "$stub"
done
# A PATH with nft only, so transparent mode falls back to the nft branch.
write_stub "$STUB_BIN_NFT" nft

export PATH="$STUB_BIN:$PATH"
export HOME="$TMP/home"
mkdir -p "$HOME"

# --------------------------------------------------------------------------
# a/b/c — method table, GOODBYEDPI_ARGS override, unknown method
# --------------------------------------------------------------------------

METHOD_LIST="default alt alt2 alt3 alt4 alt5 alt6"

expected_args() {
    case "$1" in
        default) printf '%s' '--fake -1 --md5sig --ttl 8 --split 1+s --disorder 3+s --tlsrec 3+s --mod-http hcsmix,dcsmix' ;;
        alt)     printf '%s' '--fake -1 --ttl 3 --md5sig' ;;
        alt2)    printf '%s' '--split 1+s --disorder 3+s --mod-http hcsmix,dcsmix' ;;
        alt3)    printf '%s' '--fake -1 --ttl 3 --md5sig' ;;
        alt4)    printf '%s' '--split 1+s --disorder 3+s --mod-http hcsmix,dcsmix' ;;
        alt5)    printf '%s' '--split 1+s --tlsrec 1+s --mod-http hcsmix,dcsmix' ;;
        alt6)    printf '%s' '--split 1+s --tlsrec 1+s' ;;
        *)       printf '%s' '<bilinmeyen>' ;;
    esac
}

expected_dns_legacy() {
    case "$1" in
        default | alt3 | alt4 | alt5) printf '%s' 'yandex' ;;
        alt | alt2 | alt6)            printf '%s' 'off' ;;
        *)                            printf '%s' '<bilinmeyen>' ;;
    esac
}

(
    # shellcheck source=/dev/null
    . "$LIB_FILE"

    for method in $METHOD_LIST; do
        check_eq "method_args:$method" "$(expected_args "$method")" "$(method_args "$method")"
    done

    # DNS policy: forcing Yandex DNS is the default (Y3); `off` is the opt-out.
    unset GOODBYEDPI_DNS
    for method in $METHOD_LIST; do
        check_eq "method_dns_mode:default-yandex:$method" 'yandex' "$(method_dns_mode "$method")"
    done

    GOODBYEDPI_DNS=''
    check_eq "method_dns_mode:empty-is-yandex" 'yandex' "$(method_dns_mode default)"
    unset GOODBYEDPI_DNS

    GOODBYEDPI_DNS='off'
    for method in $METHOD_LIST; do
        check_eq "method_dns_mode:off-opt-out:$method" 'off' "$(method_dns_mode "$method")"
    done
    unset GOODBYEDPI_DNS

    GOODBYEDPI_DNS='yandex'
    for method in $METHOD_LIST; do
        check_eq "method_dns_mode:yandex-forces:$method" 'yandex' "$(method_dns_mode "$method")"
    done
    unset GOODBYEDPI_DNS

    GOODBYEDPI_DNS='legacy'
    for method in $METHOD_LIST; do
        check_eq "method_dns_mode:legacy:$method" "$(expected_dns_legacy "$method")" "$(method_dns_mode "$method")"
    done
    unset GOODBYEDPI_DNS

    if (GOODBYEDPI_DNS='bogus' method_dns_mode default >/dev/null 2>&1); then
        fail "method_dns_mode:invalid-policy-dies"
    else
        pass "method_dns_mode:invalid-policy-dies"
    fi
    invalid_err="$(GOODBYEDPI_DNS='bogus' method_dns_mode default 2>&1 >/dev/null)"
    check_has "method_dns_mode:invalid-policy-names-off" "$invalid_err" 'off | yandex | legacy'
    check_has "method_dns_mode:invalid-policy-names-yandex-default" "$invalid_err" 'varsayilan: yandex'

    check_eq "method_args:default-when-omitted" "$(expected_args default)" "$(method_args)"

    GOODBYEDPI_ARGS='--fake -1 --ttl 4 --split 5+s'
    check_eq "method_args:GOODBYEDPI_ARGS-override" '--fake -1 --ttl 4 --split 5+s' "$(method_args alt6)"
    unset GOODBYEDPI_ARGS

    if (method_args yok-boyle-bir-yontem >/dev/null 2>&1); then
        fail "method_args:unknown-method-dies"
    else
        pass "method_args:unknown-method-dies"
    fi

    if (method_dns_mode yok-boyle-bir-yontem >/dev/null 2>&1); then
        fail "method_dns_mode:unknown-method-dies"
    else
        pass "method_dns_mode:unknown-method-dies"
    fi

    # log_dns_policy must make the effective policy visible, and must warn
    # before DNS is handed to a third party.
    check_has "log_dns_policy:off-line" "$(log_dns_policy off 2>&1)" 'DNS politikasi: off'
    check_has "log_dns_policy:off-mentions-opt-in" "$(log_dns_policy off 2>&1)" 'GOODBYEDPI_DNS=yandex'
    check_has "log_dns_policy:yandex-warning" "$(log_dns_policy yandex 2>&1)" 'DNS ucuncu tarafa (Yandex) yonlendirilecek'
    check_has "log_dns_policy:yandex-warning-mentions-off" "$(log_dns_policy yandex 2>&1)" 'GOODBYEDPI_DNS=off'
    check_has "log_dns_policy:yandex-warning-mentions-plaintext" "$(log_dns_policy yandex 2>&1)" 'duz metin DNS'
    check_eq "log_dns_policy:yandex-no-log-line" '' "$(log_dns_policy yandex 2>/dev/null)"
)

# --------------------------------------------------------------------------
# d — render_unit
# --------------------------------------------------------------------------

(
    # shellcheck source=/dev/null
    . "$LIB_FILE"
    CIADPI_BIN="$STUB_BIN/ciadpi"

    unit="$(render_unit "$UNIT_NAME" "$CIADPI_BIN" --split 1+s --disorder 3+s)"

    check_has "render_unit:execstart-ciadpi" "$unit" "ExecStart=$CIADPI_BIN "
    check_has "render_unit:ip" "$unit" '--ip "127.0.0.1"'
    check_has "render_unit:port" "$unit" '--port "1080"'
    # render_unit quotes every whitespace-separated token, which systemd parses
    # back into the same argv, so `--split 1+s` lands as two quoted tokens.
    check_has "render_unit:arg-split" "$unit" '"--split" "1+s"'
    check_has "render_unit:arg-disorder" "$unit" '"--disorder" "3+s"'
    check_has "render_unit:caps-socks" "$unit" 'AmbientCapabilities=CAP_NET_RAW'
    check_has_not "render_unit:caps-socks-no-net-admin" "$unit" 'CAP_NET_ADMIN'
    check_has_not "render_unit:no-args-placeholder" "$unit" '@ARGS@'
    check_has_not "render_unit:no-ciadpi-placeholder" "$unit" '@CIADPI@'

    # The unit sandbox must keep the ExecStart binary readable. The repository
    # lives under /home, and `ProtectHome=yes` hides /home from the unit, which
    # killed the service with 203/EXEC + start-limit-hit.
    check_has "unit:protecthome-read-only" "$unit" 'ProtectHome=read-only'
    # line-exact: the explanatory comment above the key names the wrong value
    if printf '%s\n' "$unit" | grep -qx 'ProtectHome=yes'; then
        fail "unit:protecthome-not-yes (aktif anahtar hala ProtectHome=yes)"
    else
        pass "unit:protecthome-not-yes"
    fi
    check_has "unit:protecthome-comment" "$unit" 'ProtectHome=yes makes /home invisible'
    check_has "unit:protectsystem-still-strict" "$unit" 'ProtectSystem=strict'
    check_has "unit:no-new-privileges-kept" "$unit" 'NoNewPrivileges=yes'
    check_has "unit:execstart-home-path-rendered" "$unit" "ExecStart=$CIADPI_BIN "
)

(
    PROXY_MODE=transparent
    # shellcheck source=/dev/null
    . "$LIB_FILE"
    CIADPI_BIN="$STUB_BIN/ciadpi"

    unit="$(render_unit "$UNIT_NAME" "$CIADPI_BIN" --fake -1 --ttl 3 --md5sig)"

    check_has "render_unit:transparent-caps" "$unit" 'AmbientCapabilities=CAP_NET_RAW CAP_NET_ADMIN'
    check_has "render_unit:transparent-bound" "$unit" 'CapabilityBoundingSet=CAP_NET_RAW CAP_NET_ADMIN'
    check_has "render_unit:transparent-args" "$unit" '"--fake"'
)

# --------------------------------------------------------------------------
# e — DRY_RUN=1 is a side-effect free preview
# --------------------------------------------------------------------------

(
    DRY_RUN=1
    # shellcheck source=/dev/null
    . "$LIB_FILE"
    STATE_DIR="$TMP/dry-state"
    STATE_FILE="$STATE_DIR/prev-state.env"

    preview="$(save_state lo 2>/dev/null)"
    rc=$?
    check_eq "dry-run:rc" 0 "$rc"
    check_has "dry-run:prints-would-run" "$preview" 'would-run:'

    stray=0
    while IFS= read -r line; do
        case "$line" in
            '') : ;;
            would-run:*) : ;;
            *) stray=1 ;;
        esac
    done <<<"$preview"
    check_eq "dry-run:only-preview-lines" 0 "$stray"

    if [ -e "$STATE_DIR" ]; then
        fail "dry-run:no-state-dir"
    else
        pass "dry-run:no-state-dir"
    fi
    if [ -e "$STATE_FILE" ]; then
        fail "dry-run:no-state-file"
    else
        pass "dry-run:no-state-file"
    fi
)

# --------------------------------------------------------------------------
# f — save_state / restore_state round-trip (real sandbox files, stub commands)
# --------------------------------------------------------------------------

(
    DRY_RUN=0
    STUB_RESOLVECTL_STATUS='Global'
    export STUB_RESOLVECTL_STATUS
    # shellcheck source=/dev/null
    . "$LIB_FILE"
    STATE_DIR="$TMP/state"
    STATE_FILE="$STATE_DIR/prev-state.env"
    UNIT_PATH="$TMP/etc/$UNIT_NAME.service"
    CIADPI_BIN="$STUB_BIN/ciadpi"

    calls_reset
    save_state lo >/dev/null 2>&1
    rc=$?
    check_eq "save_state:rc" 0 "$rc"

    if [ -f "$STATE_FILE" ]; then
        pass "save_state:state-file-created"
    else
        fail "save_state:state-file-created"
    fi

    check_eq "save_state:mode-600" 600 "$(stat -c '%a' "$STATE_FILE" 2>/dev/null)"
    # The state dir carries the saved proxy/DNS snapshot too, so it is private
    # as well; the .tmp sibling must never survive the atomic rename.
    check_eq "save_state:dir-mode-700" 700 "$(stat -c '%a' "$STATE_DIR" 2>/dev/null)"
    if [ -e "$STATE_FILE.tmp" ]; then
        fail "save_state:no-tmp-leftover"
    else
        pass "save_state:no-tmp-leftover"
    fi

    for key in SAVED_IFACE SAVED_PROXY_MODE SAVED_DNS_BACKEND SAVED_DNS_PREV \
        SAVED_RESOLV_BACKUP SAVED_PROXY_BACKEND SAVED_GS_MODE SAVED_GS_HOST \
        SAVED_GS_PORT SAVED_GS_IGNORE SAVED_ENV_FILE SAVED_ENV_FILE_PRESENT; do
        if grep -q "^$key=" "$STATE_FILE" 2>/dev/null; then
            pass "save_state:key-$key"
        else
            fail "save_state:key-$key"
        fi
    done

    check_eq "save_state:iface-value" 'SAVED_IFACE=lo' "$(grep '^SAVED_IFACE=' "$STATE_FILE" 2>/dev/null)"
    check_eq "save_state:dns-backend-value" 'SAVED_DNS_BACKEND=resolved' "$(grep '^SAVED_DNS_BACKEND=' "$STATE_FILE" 2>/dev/null)"

    calls_reset
    restore_state >/dev/null 2>&1
    rc=$?
    check_eq "restore_state:rc" 0 "$rc"

    if [ -f "$STATE_FILE" ]; then
        fail "restore_state:state-file-removed"
    else
        pass "restore_state:state-file-removed"
    fi

    trace="$(calls)"
    check_has "restore_state:dns-command" "$trace" 'resolvectl revert lo'
    check_has "restore_state:flush-caches" "$trace" 'resolvectl flush-caches'
    check_has "restore_state:transparent-down-first" "$trace" 'iptables -t nat -D OUTPUT -j GOODBYEDPI_TURKEY'

    restore_state >/dev/null 2>&1
    rc=$?
    check_eq "restore_state:second-call-safe" 0 "$rc"

    # Y2: DNS is opt-in, so a run that did not change DNS must not write DNS at
    # teardown either (the saved flag records that decision).
    calls_reset
    save_state lo 0 >/dev/null 2>&1
    check_eq "save_state:dns-applied-flag-off" 'SAVED_DNS_APPLIED=0' \
        "$(grep '^SAVED_DNS_APPLIED=' "$STATE_FILE" 2>/dev/null)"
    out="$(restore_state 2>&1)"
    rc=$?
    trace="$(calls)"
    check_eq "restore_state:dns-not-applied-rc" 0 "$rc"
    check_has_not "restore_state:dns-not-applied-no-revert" "$trace" 'resolvectl revert'
    check_has_not "restore_state:dns-not-applied-no-flush" "$trace" 'flush-caches'
    check_has "restore_state:dns-not-applied-log" "$out" 'DNS geri yuklemesi atlandi'

    # Service install reuses an existing state file, so a run that does change
    # DNS must flip the saved flag — otherwise its teardown would skip DNS.
    calls_reset
    save_state lo 0 >/dev/null 2>&1
    _gdt_mark_dns_applied >/dev/null 2>&1
    check_eq "mark_dns_applied:flag-flipped" 'SAVED_DNS_APPLIED=1' \
        "$(grep '^SAVED_DNS_APPLIED=' "$STATE_FILE" 2>/dev/null)"
    calls_reset
    restore_state >/dev/null 2>&1
    check_has "mark_dns_applied:teardown-reverts-dns" "$(calls)" 'resolvectl flush-caches'
)

# --------------------------------------------------------------------------
# g — transparent_up / transparent_down (iptables and nft branches)
# --------------------------------------------------------------------------

(
    DRY_RUN=0
    PROXY_MODE=transparent
    # shellcheck source=/dev/null
    . "$LIB_FILE"

    calls_reset
    transparent_up >/dev/null 2>&1
    rc=$?
    check_eq "transparent_up:rc" 0 "$rc"

    trace="$(calls)"
    check_has "transparent_up:chain-flush" "$trace" 'iptables -t nat -F GOODBYEDPI_TURKEY'
    check_has_not "transparent_up:chain-not-recreated" "$trace" 'iptables -t nat -N GOODBYEDPI_TURKEY'
    check_has "transparent_up:private-range-return" "$trace" 'iptables -t nat -A GOODBYEDPI_TURKEY -d 10.0.0.0/8 -j RETURN'
    check_has "transparent_up:port-return" "$trace" 'iptables -t nat -A GOODBYEDPI_TURKEY -p tcp -m tcp --dport 1080 -j RETURN'
    check_has "transparent_up:redirect" "$trace" 'iptables -t nat -A GOODBYEDPI_TURKEY -p tcp -j REDIRECT --to-ports 1080'
    check_has "transparent_up:output-hook" "$trace" 'iptables -t nat -A OUTPUT -j GOODBYEDPI_TURKEY'
    # O2: IPv6 must be redirected too, otherwise IPv6 traffic bypasses ciadpi.
    check_has "transparent_up:v6-redirect" "$trace" 'ip6tables -t nat -A GOODBYEDPI_TURKEY6 -p tcp -j REDIRECT --to-ports 1080'
    check_has "transparent_up:v6-output-hook" "$trace" 'ip6tables -t nat -A OUTPUT -j GOODBYEDPI_TURKEY6'

    calls_reset
    transparent_down >/dev/null 2>&1
    rc=$?
    check_eq "transparent_down:rc" 0 "$rc"

    trace="$(calls)"
    check_has "transparent_down:unhook" "$trace" 'iptables -t nat -D OUTPUT -j GOODBYEDPI_TURKEY'
    check_has "transparent_down:flush-chain" "$trace" 'iptables -t nat -F GOODBYEDPI_TURKEY'
    check_has "transparent_down:delete-chain" "$trace" 'iptables -t nat -X GOODBYEDPI_TURKEY'
    # O2/O3: the IPv6 mirror is torn down as well, and teardown never aborts.
    check_has "transparent_down:v6-unhook" "$trace" 'ip6tables -t nat -D OUTPUT -j GOODBYEDPI_TURKEY6'
    check_has "transparent_down:v6-delete-chain" "$trace" 'ip6tables -t nat -X GOODBYEDPI_TURKEY6'
)

(
    DRY_RUN=0
    PROXY_MODE=transparent
    # shellcheck source=/dev/null
    . "$LIB_FILE"
    # nft-only PATH: iptables is not reachable, so the fallback branch is used.
    PATH="$STUB_BIN_NFT"
    export PATH

    calls_reset
    transparent_up >/dev/null 2>&1
    rc=$?
    check_eq "transparent_up-nft:rc" 0 "$rc"

    trace="$(calls)"
    check_has "transparent_up-nft:table" "$trace" 'nft add table ip goodbyedpi_turkey'
    check_has "transparent_up-nft:chain" "$trace" 'nft add chain ip goodbyedpi_turkey output'
    check_has "transparent_up-nft:redirect" "$trace" 'nft add rule ip goodbyedpi_turkey output tcp redirect to :1080'
    # O2: the nft branch mirrors the redirect for IPv6 as well.
    check_has "transparent_up-nft:v6-table" "$trace" 'nft add table ip6 goodbyedpi_turkey6'
    check_has "transparent_up-nft:v6-redirect" "$trace" 'nft add rule ip6 goodbyedpi_turkey6 output ip6 nexthdr tcp redirect to :1080'
    check_has_not "transparent_up-nft:no-iptables" "$trace" 'iptables'

    calls_reset
    transparent_down >/dev/null 2>&1
    rc=$?
    check_eq "transparent_down-nft:rc" 0 "$rc"
    down_trace="$(calls)"
    check_has "transparent_down-nft:delete-table" "$down_trace" 'nft delete table ip goodbyedpi_turkey'
    check_has "transparent_down-nft:v6-delete-table" "$down_trace" 'nft delete table ip6 goodbyedpi_turkey6'
)

# --------------------------------------------------------------------------
# h — backend detection returns documented values
# --------------------------------------------------------------------------

(
    # shellcheck source=/dev/null
    . "$LIB_FILE"

    dns_backend="$(detect_dns_backend)"
    case "$dns_backend" in
        resolved | resolvconf) pass "detect_dns_backend:documented-value ($dns_backend)" ;;
        *) fail "detect_dns_backend:documented-value (gelen: [$dns_backend])" ;;
    esac

    proxy_backend="$(detect_proxy_backend)"
    case "$proxy_backend" in
        none | environmentd | gsettings) pass "detect_proxy_backend:documented-value ($proxy_backend)" ;;
        *) fail "detect_proxy_backend:documented-value (gelen: [$proxy_backend])" ;;
    esac
)

(
    STUB_RESOLVECTL_STATUS='Global'
    STUB_GSETTINGS_SCHEMA=1
    export STUB_RESOLVECTL_STATUS STUB_GSETTINGS_SCHEMA
    # shellcheck source=/dev/null
    . "$LIB_FILE"

    check_eq "detect_dns_backend:resolved" 'resolved' "$(detect_dns_backend)"
    check_eq "detect_proxy_backend:gsettings" 'gsettings' "$(detect_proxy_backend)"
)

# --------------------------------------------------------------------------
# i — require_root and the sudo password-prompt problem
#
# The real sudo binary is NEVER reached: both cases put a stub `sudo` first in
# PATH and that stub only records its argv. This matters — invoking the real
# sudo here could ask for a password and charge the attempt to pam_faillock,
# which is exactly the failure the library is meant to avoid.
# `sudo -n true` is the cache probe; `sudo --preserve-env=<list> -- <script>`
# is the re-exec (an explicit allow-list, never `-E`).
# --------------------------------------------------------------------------

SUDO_CACHED="$TMP/sudo-cached"
SUDO_NOCACHE="$TMP/sudo-nocache"
mkdir -p "$SUDO_CACHED" "$SUDO_NOCACHE"

# write_sudo_stub <dir> — argv-logging sudo stub; the exit code of the `-n true`
# cache probe is controlled by SUDO_STUB_PROBE_RC so one stub serves both cases.
write_sudo_stub() {
    cat >"$1/sudo" <<'STUB'
#!/bin/bash
# Test stub for sudo: records argv, never touches PAM.
printf 'sudo %s\n' "$*" >>"${CALLS_LOG:-/dev/null}"
case " $* " in
    *' -n true '*) exit "${SUDO_STUB_PROBE_RC:-0}" ;;
esac
exit 0
STUB
    chmod +x "$1/sudo"
}
write_sudo_stub "$SUDO_CACHED"
write_sudo_stub "$SUDO_NOCACHE"

# The re-exec keeps an explicit allow-list instead of the whole environment;
# read the list from the library so the assertion cannot drift from the code.
SUDO_KEEP="$(
    # shellcheck source=/dev/null
    . "$LIB_FILE"
    printf '%s' "$_GDT_SUDO_KEEP"
)"

# A stand-in for the wrapper the user ran; never executed (sudo is stubbed).
FAKE_WRAPPER="$TMP/turkey_dnsredir.sh"
printf '#!/usr/bin/env bash\nexit 0\n' >"$FAKE_WRAPPER"

( # (a) cached credential: re-exec happens, no hint, no failure
    DRY_RUN=0
    SUDO_STUB_PROBE_RC=0
    PATH="$SUDO_CACHED:$PATH"
    export PATH SUDO_STUB_PROBE_RC
    # shellcheck source=/dev/null
    . "$LIB_FILE"

    calls_reset
    out="$(require_root "$FAKE_WRAPPER" 2>&1)"
    rc=$?
    trace="$(calls)"

    check_eq "require_root:cached-credential-rc" 0 "$rc"
    check_has "require_root:cached-credential-reexec" "$trace" "sudo --preserve-env=$SUDO_KEEP -- $FAKE_WRAPPER"
    check_has "require_root:preserve-env-flag" "$trace" '--preserve-env='
    check_has "require_root:preserve-env-carries-dns-policy" "$SUDO_KEEP" 'GOODBYEDPI_DNS'
    # an explicit allow-list, never the caller's whole environment
    check_has_not "require_root:allowlist-no-wildcard" "$SUDO_KEEP" '*'
    check_has_not "require_root:cached-credential-no-sudo-E" "$trace" 'sudo -E'
    check_has_not "require_root:cached-credential-no-hint" "$out" 'faillock'
)

( # (b) no TTY and no cached credential: stop with instructions, never re-exec
    DRY_RUN=0
    SUDO_STUB_PROBE_RC=1
    PATH="$SUDO_NOCACHE:$PATH"
    export PATH SUDO_STUB_PROBE_RC

    child="$TMP/no-tty-child.sh"
    cat >"$child" <<'CHILD'
#!/usr/bin/env bash
# Sources the library and calls require_root with no controlling terminal.
set -u
# shellcheck source=/dev/null
. "$1"
require_root "$2"
CHILD
    chmod +x "$child"

    out_file="$TMP/no-tty.out"
    calls_reset
    if setsid -w true 2>/dev/null; then
        # </dev/null kills stdin, setsid drops the controlling terminal, so
        # sudo would have nowhere to print a prompt.
        setsid -w bash "$child" "$LIB_FILE" "$FAKE_WRAPPER" </dev/null >"$out_file" 2>&1
        rc=$?
    else
        fail "require_root:no-tty-case-needs-setsid"
        : >"$out_file"
        rc=0
    fi
    out="$(cat "$out_file")"
    trace="$(calls)"

    if [ "$rc" -eq 0 ]; then
        fail "require_root:no-tty-nonzero-rc (rc=0)"
    else
        pass "require_root:no-tty-nonzero-rc"
    fi
    check_has "require_root:no-tty-hint-sudo-v" "$out" 'sudo -v'
    check_has "require_root:no-tty-hint-faillock" "$out" 'faillock --user'
    check_has "require_root:no-tty-hint-retry-command" "$out" "sudo --preserve-env=$SUDO_KEEP -- $FAKE_WRAPPER"
    check_has_not "require_root:no-tty-no-raw-password-error" "$out" 'a password is required'
    check_has_not "require_root:no-tty-no-raw-tty-error" "$out" 'a terminal is required'
    check_has "require_root:no-tty-cache-probe-only" "$trace" 'sudo -n true'
    check_has_not "require_root:no-tty-no-sudo-E" "$trace" 'sudo -E'
)

# --------------------------------------------------------------------------
# j — PATH hardening
#
# The library rewrites PATH only for uid 0, because only root's lookups can be
# turned into root code execution. A stub `id` that claims uid 0 makes that
# branch reachable without root: after sourcing, an attacker-controlled
# directory must be gone from PATH and the fixed order must be in place.
# --------------------------------------------------------------------------

ATTACK_BIN="$TMP/attacker-bin"
mkdir -p "$ATTACK_BIN"
cat >"$ATTACK_BIN/id" <<'STUB'
#!/bin/bash
# Test stub for id: claim to be root so the library's root-only hardening runs.
printf '0\n'
STUB
chmod +x "$ATTACK_BIN/id"

(
    PATH="$ATTACK_BIN:$PATH"
    export PATH
    # shellcheck source=/dev/null
    . "$LIB_FILE"

    check_eq "safe-path:root-uses-fixed-order" \
        '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin' "${PATH:-}"
    check_eq "safe-path:matches-documented-constant" "${_GDT_SAFE_PATH:-}" "${PATH:-}"
    check_has_not "safe-path:attacker-prefix-dropped" "${PATH:-}" "$ATTACK_BIN"
    # exported, so every child process (sudo, systemctl, ciadpi) inherits it
    child_path="$(env | sed -n 's/^PATH=//p' | head -n 1)"
    check_eq "safe-path:exported-to-children" "${PATH:-}" "$child_path"
)

(
    # An unprivileged run keeps the caller PATH (dry-run wrappers and this
    # stub suite rely on it); the fixed order is still the documented value.
    # shellcheck source=/dev/null
    . "$LIB_FILE"
    case ":$PATH:" in
        *":$STUB_BIN:"*) pass "safe-path:nonroot-keeps-caller-path" ;;
        *) fail "safe-path:nonroot-keeps-caller-path (PATH=$PATH)" ;;
    esac
    check_eq "safe-path:documented-value" \
        '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin' "${_GDT_SAFE_PATH:-}"
)

# --------------------------------------------------------------------------
# k — desync arguments are never glob-expanded
#
# A caller-supplied `GOODBYEDPI_ARGS='*'` used to reach ciadpi through an
# unquoted expansion, so a `*` in the cwd (aaa.conf, bbb.conf) would have
# turned into extra argv entries. Both paths are checked: the dry-run preview
# of the one-shot runner and the real argv handed to ciadpi.
# --------------------------------------------------------------------------

DECOY_DIR="$TMP/decoys"
mkdir -p "$DECOY_DIR"
: >"$DECOY_DIR/aaa.conf"
: >"$DECOY_DIR/bbb.conf"

(
    DRY_RUN=1
    PROXY_MODE=socks
    GOODBYEDPI_ARGS='*'
    STUB_IP_ROUTE='default via 192.168.1.1 dev eth9'
    export GOODBYEDPI_ARGS STUB_IP_ROUTE
    # shellcheck source=/dev/null
    . "$LIB_FILE"
    # after sourcing: the library pins CIADPI_BIN to the real build output
    CIADPI_BIN="$STUB_BIN/ciadpi"
    STATE_DIR="$TMP/glob-state"
    STATE_FILE="$STATE_DIR/prev-state.env"
    cd "$DECOY_DIR" || exit 1

    out="$(run_method_oneshot default 2>&1)"
    check_has "no-glob:oneshot-literal-star" "$out" '--port 1080 *'
    check_has_not "no-glob:oneshot-no-decoy-aaa" "$out" 'aaa.conf'
    check_has_not "no-glob:oneshot-no-decoy-bbb" "$out" 'bbb.conf'
)

(
    DRY_RUN=0
    # shellcheck source=/dev/null
    . "$LIB_FILE"
    # after sourcing: the library pins CIADPI_BIN to the real build output, so
    # overriding it earlier would run the compiled proxy instead of the stub.
    CIADPI_BIN="$STUB_BIN/ciadpi"
    cd "$DECOY_DIR" || exit 1

    calls_reset
    STUB_SS_LISTEN=1 start_ciadpi_foreground '*' >/dev/null 2>&1
    rc=$?
    trace="$(calls)"

    check_eq "no-glob:ciadpi-rc" 0 "$rc"
    check_has "no-glob:argv-literal-star" "$trace" 'ciadpi --ip 127.0.0.1 --port 1080 *'
    check_has_not "no-glob:argv-no-decoy-aaa" "$trace" 'aaa.conf'
    check_has_not "no-glob:argv-no-decoy-bbb" "$trace" 'bbb.conf'
)

# --------------------------------------------------------------------------
# l — teardown tolerance and the recorded transparent backend
# --------------------------------------------------------------------------

(
    DRY_RUN=0
    PROXY_MODE=transparent
    STUB_RESOLVECTL_STATUS='Global'
    STUB_GSETTINGS_SCHEMA=1
    STUB_IPT_DELETE_RC=1
    export STUB_RESOLVECTL_STATUS STUB_GSETTINGS_SCHEMA STUB_IPT_DELETE_RC
    # shellcheck source=/dev/null
    . "$LIB_FILE"
    STATE_DIR="$TMP/teardown-state"
    STATE_FILE="$STATE_DIR/prev-state.env"

    save_state lo >/dev/null 2>&1
    rc=$?
    check_eq "teardown-tolerance:save-rc" 0 "$rc"
    check_eq "transparent-state:backend-recorded" 'SAVED_TRANSPARENT_BACKEND=iptables' \
        "$(grep '^SAVED_TRANSPARENT_BACKEND=' "$STATE_FILE" 2>/dev/null)"
    check_eq "transparent-state:v6-recorded" 'SAVED_TRANSPARENT_V6=1' \
        "$(grep '^SAVED_TRANSPARENT_V6=' "$STATE_FILE" 2>/dev/null)"

    calls_reset
    rc=0
    # `set -e` on purpose: a failing `iptables -D` must not abort the teardown,
    # because the proxy/DNS restore runs after the firewall cleanup.
    ( set -e; restore_state >/dev/null 2>&1 ) || rc=$?
    check_eq "teardown-tolerance:set-e-rc" 0 "$rc"

    trace="$(calls)"
    check_has "teardown-tolerance:failing-delete-attempted" "$trace" \
        'iptables -t nat -D OUTPUT -j GOODBYEDPI_TURKEY'
    check_has "teardown-tolerance:proxy-still-restored" "$trace" \
        'gsettings set org.gnome.system.proxy mode'
    check_has "teardown-tolerance:dns-still-restored" "$trace" 'resolvectl revert lo'
)

(
    DRY_RUN=0
    # shellcheck source=/dev/null
    . "$LIB_FILE"
    STATE_DIR="$TMP/nft-recorded-state"
    STATE_FILE="$STATE_DIR/prev-state.env"
    mkdir -p "$STATE_DIR"
    # A hand-written state file as an nft install leaves it. Both tools are in
    # PATH now, so re-detecting would pick iptables — the recorded backend wins.
    cat >"$STATE_FILE" <<EOF
SAVED_IFACE=lo
SAVED_PROXY_BACKEND=none
SAVED_DNS_BACKEND=none
SAVED_DNS_APPLIED=0
SAVED_TRANSPARENT_BACKEND=nft
SAVED_TRANSPARENT_V6=1
EOF

    calls_reset
    restore_state >/dev/null 2>&1
    rc=$?
    trace="$(calls)"

    check_eq "transparent-backend:recorded-rc" 0 "$rc"
    # Both tools are reachable, so only the order proves which one the state
    # file chose: the recorded nft teardown runs before the iptables leftovers.
    nft_del_line="$(grep -n 'nft delete table ip goodbyedpi_turkey' "$CALLS_LOG" 2>/dev/null | head -n 1 | cut -d: -f1)"
    ipt_del_line="$(grep -n 'iptables -t nat -D OUTPUT -j GOODBYEDPI_TURKEY' "$CALLS_LOG" 2>/dev/null | head -n 1 | cut -d: -f1)"
    order='missing'
    if [ -n "$nft_del_line" ] && [ -n "$ipt_del_line" ] && [ "$nft_del_line" -lt "$ipt_del_line" ]; then
        order='ok'
    fi
    check_eq "transparent-backend:recorded-nft-torn-down-first" 'ok' "$order"
    check_has "transparent-backend:recorded-nft6-torn-down" "$trace" \
        'nft delete table ip6 goodbyedpi_turkey6'
    check_has "transparent-backend:iptables-leftovers-cleaned" "$trace" \
        'iptables -t nat -D OUTPUT -j GOODBYEDPI_TURKEY'
)

# --------------------------------------------------------------------------
# m — end-to-end order: snapshot, then apply, then restore
#
# Protects the trap/teardown ordering (O3): a run must snapshot the previous
# state before it changes anything, and the restore must come afterwards.
# --------------------------------------------------------------------------

(
    DRY_RUN=0
    STUB_RESOLVECTL_STATUS='Global'
    export STUB_RESOLVECTL_STATUS
    # shellcheck source=/dev/null
    . "$LIB_FILE"
    STATE_DIR="$TMP/e2e-state"
    STATE_FILE="$STATE_DIR/prev-state.env"

    calls_reset
    save_state lo >/dev/null 2>&1
    apply_dns lo >/dev/null 2>&1
    restore_state >/dev/null 2>&1
    rc=$?
    check_eq "e2e:dns-apply-restore-rc" 0 "$rc"

    save_line="$(grep -n "tee ${STATE_FILE}.tmp" "$CALLS_LOG" 2>/dev/null | head -n 1 | cut -d: -f1)"
    apply_line="$(grep -n 'resolvectl dns lo 77.88.8.8 77.88.8.1' "$CALLS_LOG" 2>/dev/null | head -n 1 | cut -d: -f1)"
    restore_line="$(grep -n 'resolvectl revert lo' "$CALLS_LOG" 2>/dev/null | head -n 1 | cut -d: -f1)"

    order='missing'
    if [ -n "$save_line" ] && [ -n "$apply_line" ] && [ -n "$restore_line" ] &&
        [ "$save_line" -lt "$apply_line" ] && [ "$apply_line" -lt "$restore_line" ]; then
        order='ok'
    fi
    check_eq "e2e:snapshot-then-apply-then-restore" 'ok' "$order"
    if [ -e "$STATE_FILE" ]; then
        fail "e2e:state-file-removed"
    else
        pass "e2e:state-file-removed"
    fi
)

# --------------------------------------------------------------------------
# n — desktop user resolution
#
# The GNOME proxy belongs to the desktop user, not to root. `id` is read
# through the command (never $EUID), so a stub can answer for both cases.
# --------------------------------------------------------------------------

NONROOT_BIN="$TMP/nonroot-bin"
mkdir -p "$NONROOT_BIN"
cat >"$NONROOT_BIN/id" <<'STUB'
#!/bin/bash
# Test stub for id: an ordinary desktop user. The uid is deliberately not the
# test runner's own, so only a library that really asks `id` gets it right.
case " $* " in
    *' -u desktopusr '*) printf '4242\n' ;;
    ' -un '*) printf 'desktopusr\n' ;;
    *) printf '4242\n' ;;
esac
STUB
chmod +x "$NONROOT_BIN/id"

ROOT_BIN="$TMP/root-bin"
mkdir -p "$ROOT_BIN"
cat >"$ROOT_BIN/id" <<'STUB'
#!/bin/bash
# Test stub for id: root for `-u`, uid 1000 for the desktop user `baris`.
printf 'id %s\n' "$*" >>"${CALLS_LOG:-/dev/null}"
case " $* " in
    *' -u baris '*) printf '1000\n' ;;
    *' -u ghost '*) exit 1 ;;
    ' -un '*) printf 'baris\n' ;;
    *) printf '0\n' ;;
esac
STUB
chmod +x "$ROOT_BIN/id"

cat >"$ROOT_BIN/runuser" <<'STUB'
#!/bin/bash
# Test stub for runuser: record the exact prefix, then execute what it wraps
# so the gsettings stub still sees the injected session environment.
printf 'runuser %s\n' "$*" >>"${CALLS_LOG:-/dev/null}"
shift 2
[ "${1:-}" = '--' ] && shift
exec "$@"
STUB
chmod +x "$ROOT_BIN/runuser"

cat >"$ROOT_BIN/gsettings" <<'STUB'
#!/bin/bash
# Test stub for gsettings: records argv *and* the session bus it inherited, so
# a test can prove DBUS_SESSION_BUS_ADDRESS really reached the tool.
printf 'gsettings %s [dbus=%s]\n' "$*" "${DBUS_SESSION_BUS_ADDRESS:-<none>}" >>"${CALLS_LOG:-/dev/null}"
case " ${1:-} " in
    ' list-schemas ')
        # the schema probe always works; only the writes are made to fail
        [ -n "${STUB_GSETTINGS_SCHEMA:-}" ] && printf 'org.gnome.system.proxy\n'
        exit 0
        ;;
esac
exit "${STUB_GSETTINGS_RC:-0}"
STUB
chmod +x "$ROOT_BIN/gsettings"

( # (a) unprivileged run: the desktop user is the caller
    PATH="$NONROOT_BIN:$PATH"
    export PATH
    # shellcheck source=/dev/null
    . "$LIB_FILE"

    check_eq "desktop-user:nonroot-name" 'desktopusr' "$(_gdt_desktop_user)"
    check_eq "desktop-user:nonroot-uid" '4242' "$(_gdt_desktop_uid)"
)

( # (b) root run: SUDO_USER owns the session
    SUDO_USER='baris'
    export SUDO_USER
    PATH="$ROOT_BIN:$PATH"
    export PATH
    # shellcheck source=/dev/null
    . "$LIB_FILE" 2>/dev/null
    PATH="$ROOT_BIN:$STUB_BIN:/usr/bin:/bin"
    export PATH

    check_eq "desktop-user:root-sudo-user" 'baris' "$(_gdt_desktop_user)"
    check_eq "desktop-user:root-sudo-user-uid" '1000' "$(_gdt_desktop_uid)"
)

( # (c) root run without a usable SUDO_USER falls back to root
    SUDO_USER='root'
    export SUDO_USER
    PATH="$ROOT_BIN:$PATH"
    export PATH
    # shellcheck source=/dev/null
    . "$LIB_FILE" 2>/dev/null
    PATH="$ROOT_BIN:$STUB_BIN:/usr/bin:/bin"
    export PATH
    check_eq "desktop-user:sudo-user-root" 'root' "$(_gdt_desktop_user)"
)

( # (d) unknown SUDO_USER (id fails) must not be trusted
    SUDO_USER='ghost'
    export SUDO_USER
    PATH="$ROOT_BIN:$PATH"
    export PATH
    # shellcheck source=/dev/null
    . "$LIB_FILE" 2>/dev/null
    PATH="$ROOT_BIN:$STUB_BIN:/usr/bin:/bin"
    export PATH
    check_eq "desktop-user:unknown-sudo-user-falls-back" 'root' "$(_gdt_desktop_user)"
)

( # (e) root run without SUDO_USER at all
    unset SUDO_USER
    PATH="$ROOT_BIN:$PATH"
    export PATH
    # shellcheck source=/dev/null
    . "$LIB_FILE" 2>/dev/null
    PATH="$ROOT_BIN:$STUB_BIN:/usr/bin:/bin"
    export PATH
    check_eq "desktop-user:no-sudo-user" 'root' "$(_gdt_desktop_user)"
)

# --------------------------------------------------------------------------
# o — _as_desktop routes gsettings into the desktop session
#
# Root has no session bus, so every gsettings call must be prefixed with
# `runuser -u <user> -- env XDG_RUNTIME_DIR=... DBUS_SESSION_BUS_ADDRESS=...`.
# --------------------------------------------------------------------------

ROOT_RUN_DIR="$TMP/run-user"
mkdir -p "$ROOT_RUN_DIR/1000"
: >"$ROOT_RUN_DIR/1000/bus"

(
    DRY_RUN=0
    PROXY_MODE=socks
    SUDO_USER='baris'
    STUB_GSETTINGS_SCHEMA=1
    export SUDO_USER STUB_GSETTINGS_SCHEMA
    # shellcheck source=/dev/null
    . "$LIB_FILE" 2>/dev/null
    PATH="$ROOT_BIN:$STUB_BIN:/usr/bin:/bin"
    export PATH
    _GDT_RUN_USER_DIR="$ROOT_RUN_DIR"
    export _GDT_RUN_USER_DIR

    prefix="runuser -u baris -- env XDG_RUNTIME_DIR=$ROOT_RUN_DIR/1000 DBUS_SESSION_BUS_ADDRESS=unix:path=$ROOT_RUN_DIR/1000/bus"

    check_eq "as-desktop:session-bus-path" "$ROOT_RUN_DIR/1000/bus" "$(_gdt_session_bus_path)"
    if _gdt_session_bus_ready; then
        pass "as-desktop:bus-ready"
    else
        fail "as-desktop:bus-ready"
    fi

    calls_reset
    out="$(apply_proxy 2>&1)"
    rc=$?
    trace="$(calls)"

    check_eq "as-desktop:apply-rc" 0 "$rc"
    check_eq "as-desktop:not-degraded" 0 "${PROXY_DEGRADED:-0}"
    check_has "as-desktop:runuser-prefix" "$trace" "$prefix gsettings set org.gnome.system.proxy mode manual"
    check_has "as-desktop:runuser-prefix-socks" "$trace" "$prefix gsettings set org.gnome.system.proxy.socks host 127.0.0.1"
    check_has "as-desktop:runuser-prefix-port" "$trace" "$prefix gsettings set org.gnome.system.proxy.socks port 1080"
    # the injected session bus must survive env(1) and reach gsettings itself
    check_has "as-desktop:dbus-reaches-gsettings" "$trace" \
        "gsettings set org.gnome.system.proxy mode manual [dbus=unix:path=$ROOT_RUN_DIR/1000/bus]"
    check_has "as-desktop:apply-log" "$out" 'GNOME proxy ayarlandi'

    # Every gsettings invocation is routed: no bare call, all carry the bus.
    gs_total=$(grep -c '^gsettings ' "$CALLS_LOG" 2>/dev/null || true)
    gs_with_bus=$(grep -c "^gsettings .*\[dbus=unix:path=$ROOT_RUN_DIR/1000/bus\]" "$CALLS_LOG" 2>/dev/null || true)
    check_eq "as-desktop:all-gsettings-carry-bus" "${gs_total:-0}" "${gs_with_bus:-0}"
    if [ "${gs_total:-0}" -ge 5 ]; then
        pass "as-desktop:probe-and-writes-routed"
    else
        fail "as-desktop:probe-and-writes-routed (sadece ${gs_total:-0} cagri)"
    fi

    # save_state reads the previous values through the same route
    calls_reset
    STATE_DIR="$TMP/desktop-state"
    STATE_FILE="$STATE_DIR/prev-state.env"
    save_state lo >/dev/null 2>&1
    trace="$(calls)"
    check_has "as-desktop:save-state-read" "$trace" "$prefix gsettings get org.gnome.system.proxy mode"
)

( # unprivileged run: no prefix, the command runs as-is
    DRY_RUN=0
    PROXY_MODE=socks
    STUB_GSETTINGS_SCHEMA=1
    export STUB_GSETTINGS_SCHEMA
    PATH="$NONROOT_BIN:$PATH"
    export PATH
    # shellcheck source=/dev/null
    . "$LIB_FILE"

    calls_reset
    _as_desktop gsettings set org.gnome.system.proxy mode manual >/dev/null 2>&1
    rc=$?
    trace="$(calls)"
    check_eq "as-desktop:nonroot-rc" 0 "$rc"
    check_has "as-desktop:nonroot-plain" "$trace" 'gsettings set org.gnome.system.proxy mode manual'
    check_has_not "as-desktop:nonroot-no-runuser" "$trace" 'runuser'
)

( # (c) no runuser and no sudo: warn once, never pretend it worked
    PROXY_MODE=socks
    EMPTY_BIN="$TMP/empty-bin"
    mkdir -p "$EMPTY_BIN"
    # shellcheck source=/dev/null
    . "$LIB_FILE" 2>/dev/null
    id() { case " $* " in *' -u baris '*) printf '1000\n' ;; *) printf '0\n' ;; esac; }
    PATH="$EMPTY_BIN"
    export PATH
    SUDO_USER='baris'
    export SUDO_USER
    _GDT_RUN_USER_DIR="$ROOT_RUN_DIR"

    out="$(_as_desktop gsettings set org.gnome.system.proxy mode manual 2>&1)"
    rc=$?
    check_eq "as-desktop:no-wrapper-rc" 1 "$rc"
    check_has "as-desktop:no-wrapper-warn" "$out" 'runuser/sudo bulunamadi'
    check_has "as-desktop:no-wrapper-command" "$out" "'gsettings' masaustu kullanicisinin oturumunda calistirilamadi"
    check_eq "as-desktop:no-wrapper-prefix-empty" '' "${_GDT_AS_DESKTOP_ARGV[*]}"
)

( # (d) runuser missing but sudo present: fall back to `sudo -u <user> -E env`
    SUDO_ONLY_BIN="$TMP/sudo-only-bin"
    mkdir -p "$SUDO_ONLY_BIN"
    cat >"$SUDO_ONLY_BIN/sudo" <<'STUB'
#!/bin/bash
printf 'sudo %s\n' "$*" >>"${CALLS_LOG:-/dev/null}"
exit 0
STUB
    chmod +x "$SUDO_ONLY_BIN/sudo"
    # shellcheck source=/dev/null
    . "$LIB_FILE" 2>/dev/null
    id() { case " $* " in *' -u baris '*) printf '1000\n' ;; *) printf '0\n' ;; esac; }
    PATH="$SUDO_ONLY_BIN"
    export PATH
    SUDO_USER='baris'
    export SUDO_USER
    _GDT_RUN_USER_DIR="$ROOT_RUN_DIR"

    rc=0
    _gdt_session_prefix || rc=$?
    check_eq "as-desktop:sudo-fallback-rc" 0 "$rc"
    check_eq "as-desktop:sudo-fallback-argv" \
        "sudo -u baris -E env XDG_RUNTIME_DIR=$ROOT_RUN_DIR/1000 DBUS_SESSION_BUS_ADDRESS=unix:path=$ROOT_RUN_DIR/1000/bus" \
        "${_GDT_AS_DESKTOP_ARGV[*]}"
    # the require_root re-exec must never grow a -E; only the session hop does
    check_has_not "as-desktop:reexec-stays-on-allowlist" "$_GDT_SUDO_KEEP" 'DBUS_SESSION_BUS_ADDRESS'
)

# --------------------------------------------------------------------------
# p — detect_proxy_backend: gsettings only when it can actually work
# --------------------------------------------------------------------------

(
    STUB_GSETTINGS_SCHEMA=1
    export STUB_GSETTINGS_SCHEMA
    # shellcheck source=/dev/null
    . "$LIB_FILE" 2>/dev/null
    PATH="$ROOT_BIN:$STUB_BIN:/usr/bin:/bin"
    export PATH
    SUDO_USER='baris'
    export SUDO_USER
    # bus socket missing for uid 1000 -> the GNOME backend cannot work
    _GDT_RUN_USER_DIR="$TMP/run-user-no-bus"
    export _GDT_RUN_USER_DIR
    mkdir -p "$TMP/run-user-no-bus/1000" "$HOME/.config/environment.d"

    if _gdt_session_bus_ready; then
        fail "detect-proxy:bus-missing-detected"
    else
        pass "detect-proxy:bus-missing-detected"
    fi
    check_eq "detect-proxy:schema-visible-but-no-bus" 'environmentd' "$(detect_proxy_backend 2>/dev/null)"
    out="$(detect_proxy_backend 2>&1 >/dev/null)"
    check_has "detect-proxy:fallback-reason" "$out" 'masaustu oturum veriyolu yok'
    check_has "detect-proxy:fallback-names-backend" "$out" 'Proxy arka ucu: environmentd'

    # same run with the socket present: GNOME backend wins again
    _GDT_RUN_USER_DIR="$ROOT_RUN_DIR"
    check_eq "detect-proxy:schema-and-bus" 'gsettings' "$(detect_proxy_backend 2>/dev/null)"
    out="$(detect_proxy_backend 2>&1 >/dev/null)"
    check_has "detect-proxy:gsettings-log" "$out" 'Proxy arka ucu: gsettings'
)

( # schema not visible through the desktop session -> environmentd
    mkdir -p "$HOME/.config/environment.d"
    # shellcheck source=/dev/null
    . "$LIB_FILE" 2>/dev/null
    PATH="$ROOT_BIN:$STUB_BIN:/usr/bin:/bin"
    export PATH
    SUDO_USER='baris'
    export SUDO_USER
    _GDT_RUN_USER_DIR="$ROOT_RUN_DIR"
    export _GDT_RUN_USER_DIR

    check_eq "detect-proxy:schema-hidden" 'environmentd' "$(detect_proxy_backend 2>/dev/null)"
    out="$(detect_proxy_backend 2>&1 >/dev/null)"
    check_has "detect-proxy:schema-hidden-reason" "$out" 'semasi masaustu oturumunda gorunmuyor'
)

# --------------------------------------------------------------------------
# q — a failed GNOME write is never swallowed
#
# STUB_GSETTINGS_RC=1 makes every write fail while the schema stays visible.
# The run must warn, mark itself degraded and exit non-zero — the EXIT trap
# still restores the state it saved before touching anything.
# --------------------------------------------------------------------------

(
    DRY_RUN=0
    PROXY_MODE=socks
    SUDO_USER='baris'
    STUB_GSETTINGS_SCHEMA=1
    STUB_GSETTINGS_RC=1
    export SUDO_USER STUB_GSETTINGS_SCHEMA STUB_GSETTINGS_RC
    # shellcheck source=/dev/null
    . "$LIB_FILE" 2>/dev/null
    PATH="$ROOT_BIN:$STUB_BIN:/usr/bin:/bin"
    export PATH
    _GDT_RUN_USER_DIR="$ROOT_RUN_DIR"
    export _GDT_RUN_USER_DIR

    # apply_proxy must run in *this* shell: a command substitution would hide
    # the PROXY_DEGRADED flag it sets from the caller that has to fail.
    calls_reset
    apply_out="$TMP/degraded-apply.out"
    apply_proxy >"$apply_out" 2>&1
    rc=$?
    out="$(cat "$apply_out")"
    check_eq "degraded:apply-rc" 0 "$rc"
    check_eq "degraded:flag-set" 1 "${PROXY_DEGRADED:-0}"
    check_has "degraded:warn-write" "$out" 'GNOME proxy yazilamadi: gsettings set org.gnome.system.proxy mode'
    check_has "degraded:warn-proxy" "$out" 'SOCKS proxy uygulanmis sayilmaz'
    check_has_not "degraded:no-success-log" "$out" 'GNOME proxy ayarlandi'

    out="$(_gdt_fail_if_degraded 2>&1)"
    rc=$?
    check_eq "degraded:fail-if-degraded-rc" 1 "$rc"
    check_has "degraded:error-headline" "$out" 'SOCKS proxy uygulanamadi'
    check_has "degraded:error-hint-runuser" "$out" 'runuser -u <kullanici>'
    check_has "degraded:error-hint-desktop" "$out" 'masaustu oturumundan calistirin'
)

( # end to end: run_method_oneshot must exit non-zero and still restore
    child="$TMP/degraded-child.sh"
    cat >"$child" <<'CHILD'
#!/bin/bash
# Stands in for a wrapper: the library decides the exit code.
set -euo pipefail
. "$1"
PATH="$2"
export PATH
CIADPI_BIN="$3/ciadpi"
STATE_DIR="$4"
STATE_FILE="$STATE_DIR/prev-state.env"
run_method_oneshot default
CHILD
    chmod +x "$child"

    degraded_state="$TMP/degraded-state"
    out_file="$TMP/degraded.out"
    calls_reset
    SUDO_USER='baris' \
    STUB_GSETTINGS_SCHEMA=1 \
    STUB_GSETTINGS_RC=1 \
    STUB_IP_ROUTE='default via 192.168.1.1 dev eth9' \
    STUB_RESOLVECTL_STATUS='Global' \
    _GDT_RUN_USER_DIR="$ROOT_RUN_DIR" \
        bash "$child" "$LIB_FILE" "$ROOT_BIN:$STUB_BIN:/usr/bin:/bin" "$STUB_BIN" "$degraded_state" \
        >"$out_file" 2>&1
    rc=$?
    out="$(cat "$out_file")"

    if [ "$rc" -eq 0 ]; then
        fail "degraded:oneshot-nonzero-rc (rc=0)"
    else
        pass "degraded:oneshot-nonzero-rc"
    fi
    check_has "degraded:oneshot-warn" "$out" 'GNOME proxy yazilamadi: gsettings set org.gnome.system.proxy'
    check_has "degraded:oneshot-error" "$out" 'SOCKS proxy uygulanamadi'
    check_has_not "degraded:oneshot-no-false-success" "$out" 'GNOME proxy ayarlandi'
    if [ -e "$degraded_state/prev-state.env" ]; then
        fail "degraded:oneshot-trap-restored-state"
    else
        pass "degraded:oneshot-trap-restored-state"
    fi
)

( # service_remove: a degraded restore must warn and exit non-zero
    child="$TMP/remove-child.sh"
    cat >"$child" <<'CHILD'
#!/bin/bash
# Stands in for service_remove.sh.
set -euo pipefail
. "$1"
PATH="$2"
export PATH
STATE_DIR="$3"
STATE_FILE="$STATE_DIR/prev-state.env"
# The unit path must stay inside the sandbox: the default one is a real system
# path and a live install there would make the teardown fail (or touch it).
UNIT_PATH="$STATE_DIR/$UNIT_NAME.service"
run_service_remove
CHILD
    chmod +x "$child"

    remove_state="$TMP/remove-state"
    mkdir -p "$remove_state"
    cat >"$remove_state/prev-state.env" <<'STATE'
SAVED_IFACE=lo
SAVED_PROXY_MODE=socks
SAVED_PROXY_BACKEND=gsettings
SAVED_GS_MODE='manual'
SAVED_GS_HOST='127.0.0.1'
SAVED_GS_PORT=1080
SAVED_GS_IGNORE='[]'
SAVED_DNS_BACKEND=none
SAVED_DNS_APPLIED=0
STATE

    out_file="$TMP/remove.out"
    calls_reset
    SUDO_USER='baris' \
    STUB_GSETTINGS_SCHEMA=1 \
    STUB_GSETTINGS_RC=1 \
    _GDT_RUN_USER_DIR="$ROOT_RUN_DIR" \
        bash "$child" "$LIB_FILE" "$ROOT_BIN:$STUB_BIN:/usr/bin:/bin" "$remove_state" \
        >"$out_file" 2>&1
    rc=$?
    out="$(cat "$out_file")"

    if [ "$rc" -eq 0 ]; then
        fail "degraded:service-remove-nonzero-rc (rc=0)"
    else
        pass "degraded:service-remove-nonzero-rc"
    fi
    check_has "degraded:service-remove-warn" "$out" 'GNOME proxy ayarlari geri yuklenemedi'
    check_has "degraded:service-remove-write-warn" "$out" 'GNOME proxy yazilamadi: gsettings set org.gnome.system.proxy'
)

# --------------------------------------------------------------------------
# r — PATH: silent rewrite for sudo's secure_path, warn only on real drift
# --------------------------------------------------------------------------

SAFE_PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'

(
    # shellcheck source=/dev/null
    . "$LIB_FILE"

    if _gdt_path_has_foreign_entry "$SAFE_PATH"; then
        fail "path-check:exact-safe-list-is-not-foreign"
    else
        pass "path-check:exact-safe-list-is-not-foreign"
    fi
    if _gdt_path_has_foreign_entry '/usr/local/sbin:/usr/local/bin:/usr/bin'; then
        fail "path-check:subset-is-not-foreign"
    else
        pass "path-check:subset-is-not-foreign"
    fi
    if _gdt_path_has_foreign_entry '/home/baris/tmpbin:/usr/bin'; then
        pass "path-check:extra-entry-is-foreign"
    else
        fail "path-check:extra-entry-is-foreign"
    fi
    if _gdt_path_has_foreign_entry '/usr/bin:/home/baris/tmpbin'; then
        pass "path-check:trailing-extra-entry-is-foreign"
    else
        fail "path-check:trailing-extra-entry-is-foreign"
    fi
)

# source_path_case <path> — source the library with a stubbed root `id` and
# print everything it logged. A shell function shadows `id` without putting a
# directory on PATH, so the PATH under test stays exactly as given.
path_case_out=''
source_path_case() {
    PATH="$1" TEST_LIB="$LIB_FILE" bash -c '
        id() { printf "0\n"; }
        . "$TEST_LIB"
        printf "final-path=%s\n" "$PATH"
    ' 2>&1
}

path_case_out="$(source_path_case '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin')"
check_has_not "path:secure-path-no-warn" "$path_case_out" '[!]'
check_has "path:secure-path-log-line" "$path_case_out" '[i] PATH sabitlendi (root)'
check_has "path:secure-path-silent-rewrite" "$path_case_out" 'sudo secure_path'
check_has "path:secure-path-final" "$path_case_out" "final-path=$SAFE_PATH"

path_case_out="$(source_path_case '/home/baris/tmpbin:/usr/local/bin:/usr/bin')"
check_has "path:extra-entry-warns" "$path_case_out" '[!] PATH sabitlendi (root)'
check_has "path:extra-entry-named" "$path_case_out" "/home/baris/tmpbin"
check_has "path:extra-entry-rewritten" "$path_case_out" "final-path=$SAFE_PATH"
check_has_not "path:extra-entry-no-secure-path-note" "$path_case_out" 'sudo secure_path'

# --------------------------------------------------------------------------
# t — a service that never comes up must fail the run, loudly
#
# `systemctl enable --now` returns 0 for a unit that dies immediately, e.g.
# 203/EXEC when the unit sandbox (ProtectHome) hides the ExecStart binary. The
# health check has to notice, print the journal and name the recovery command —
# before the SOCKS proxy is applied on top of a dead port.
# --------------------------------------------------------------------------

HEALTH_BIN="$TMP/health-bin"
mkdir -p "$HEALTH_BIN"
# ciadpi that never listens: prints one bind error and exits, like a real
# argument/bind failure (the one-shot health check consumes this stub).
cat >"$HEALTH_BIN/ciadpi" <<'STUB'
#!/bin/bash
printf 'ciadpi %s\n' "$*" >>"${CALLS_LOG:-/dev/null}"
printf 'error: cannot bind 127.0.0.1:1080: Address already in use\n' >&2
exit 1
STUB
chmod +x "$HEALTH_BIN/ciadpi"

( # healthy unit: active and listening, so the install may continue
    # shellcheck source=/dev/null
    . "$LIB_FILE" 2>/dev/null
    PATH="$ROOT_BIN:$STUB_BIN:/usr/bin:/bin"
    export PATH
    STUB_SYSTEMCTL_ACTIVE=0
    STUB_SS_LISTEN=1
    export STUB_SYSTEMCTL_ACTIVE STUB_SS_LISTEN

    out="$(_gdt_service_health_check "$UNIT_NAME" 2>&1)"
    rc=$?
    check_eq "service-health:healthy-rc" 0 "$rc"
    check_has "service-health:healthy-log" "$out" "Servis aktif ve dinliyor: $UNIT_NAME"
)

( # unit inactive/failed: run_method_service_install must exit non-zero
    child="$TMP/service-install-child.sh"
    cat >"$child" <<'CHILD'
#!/bin/bash
# Stands in for service_install_dnsredir_turkey.sh. systemctl/ciadpi are stubs,
# so nothing is installed, started or applied to the live session.
set -euo pipefail
. "$1"
PATH="$2"
export PATH
UNIT_PATH="$3"
STATE_DIR="$4"
STATE_FILE="$STATE_DIR/prev-state.env"
run_method_service_install alt6
CHILD
    chmod +x "$child"

    svc_dir="$TMP/service-install"
    mkdir -p "$svc_dir/etc"
    out_file="$TMP/service-install.out"
    calls_reset
    SUDO_USER='baris' \
    STUB_IP_ROUTE='default via 192.168.1.1 dev eth9' \
    STUB_SYSTEMCTL_ACTIVE=1 \
    STUB_JOURNAL_LINES='goodbyedpi-turkey.service: Failed to locate executable /home/u/repo/linux/bin/ciadpi: No such file or directory' \
    GOODBYEDPI_DNS=off \
        bash "$child" "$LIB_FILE" "$ROOT_BIN:$STUB_BIN:/usr/bin:/bin" \
        "$svc_dir/etc/goodbyedpi-turkey.service" "$svc_dir/state" >"$out_file" 2>&1
    rc=$?
    out="$(cat "$out_file")"
    trace="$(calls)"

    if [ "$rc" -eq 0 ]; then
        fail "service-health:nonzero-rc (rc=0)"
    else
        pass "service-health:nonzero-rc"
    fi
    check_has "service-health:error-headline" "$out" 'Servis saglik kontrolu basarisiz'
    check_has "service-health:names-protecthome" "$out" 'ProtectHome'
    check_has "service-health:names-203-exec" "$out" '203/EXEC'
    check_has "service-health:names-cap-net-raw" "$out" 'CAP_NET_RAW'
    check_has "service-health:names-port-in-use" "$out" 'portu baska bir surec tarafindan kullaniliyor'
    check_has "service-health:recovery-command" "$out" 'sudo ./scripts/service_remove.sh'
    check_has "service-health:journal-printed" "$out" 'Failed to locate executable'
    check_has "service-health:journal-consulted" "$trace" "journalctl -u $UNIT_NAME -n 20 --no-pager"
    check_has_not "service-health:no-success-log" "$out" 'Servis kuruldu:'
    # the proxy must not be applied on top of a dead unit
    check_has_not "service-health:no-proxy-write" "$trace" 'gsettings set'
)

# --------------------------------------------------------------------------
# u — the one-shot path never claims success when ciadpi is not listening
# --------------------------------------------------------------------------

( # ciadpi dies at once: the port never opens, so the run must stop non-zero
    DRY_RUN=0
    # shellcheck source=/dev/null
    . "$LIB_FILE"
    CIADPI_BIN="$HEALTH_BIN/ciadpi"

    out="$(start_ciadpi_foreground --bogus 2>&1)"
    rc=$?

    if [ "$rc" -eq 0 ]; then
        fail "oneshot-health:nonzero-rc (rc=0)"
    else
        pass "oneshot-health:nonzero-rc"
    fi
    check_has "oneshot-health:error-headline" "$out" 'ciadpi baslatilamadi'
    check_has "oneshot-health:shows-child-stderr" "$out" 'cannot bind 127.0.0.1:1080'
    check_has "oneshot-health:names-port-in-use" "$out" 'portu baska bir surec tarafindan kullaniliyor'
    check_has "oneshot-health:mentions-recovery" "$out" 'sudo ./scripts/service_remove.sh'
    check_has_not "oneshot-health:no-listening-log" "$out" 'ciadpi dinliyor'
)


passed=$(grep -c '^ok ' "$RESULTS" 2>/dev/null || true)
failed=$(grep -c '^fail ' "$RESULTS" 2>/dev/null || true)
passed=${passed:-0}
failed=${failed:-0}

printf 'lib-test: %s passed, %s failed\n' "$passed" "$failed"

if [ "$failed" -eq 0 ]; then
    exit 0
fi
exit 1
