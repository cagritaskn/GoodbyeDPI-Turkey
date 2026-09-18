#!/usr/bin/env bash
# Shared helpers for the macOS GoodbyeDPI-Turkey scripts.
#
# This file is intended to be sourced, not executed directly. It provides:
#   - require_root            : re-exec under sudo if not running as root.
#   - require_ciadpi          : ensure macos/bin/ciadpi exists and is executable.
#   - detect_network_service  : print the human-readable network service
#                               (e.g. "Wi-Fi", "Ethernet") of the default route.
#   - save_network_state      : snapshot current SOCKS proxy + DNS settings
#                               for the active service into a state file so
#                               they can be restored later.
#   - apply_proxy / clear_proxy
#   - apply_dns   / clear_dns
#   - cleanup_and_restore     : restore state from the snapshot.
#   - start_ciadpi_foreground : launch ciadpi in the foreground with the
#                               supplied arguments, blocking until it exits.
#
# All operations log clearly and refuse to silently override user state.

set -euo pipefail

# ---- paths -----------------------------------------------------------------

# When sourced, BASH_SOURCE[0] is this file. Resolve repo-relative paths.
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MACOS_DIR="$(cd "${_LIB_DIR}/.." && pwd)"
REPO_DIR="$(cd "${MACOS_DIR}/.." && pwd)"
CIADPI_BIN="${MACOS_DIR}/bin/ciadpi"

STATE_DIR="/var/db/goodbyedpi-turkey"
STATE_FILE="${STATE_DIR}/prev-network-state.env"

LAUNCHD_LABEL="com.cagritaskn.goodbyedpi-turkey"
LAUNCHD_PLIST="/Library/LaunchDaemons/${LAUNCHD_LABEL}.plist"
LAUNCHD_TEMPLATE="${MACOS_DIR}/launchd/${LAUNCHD_LABEL}.plist.template"

# Defaults — overridable by callers BEFORE sourcing or with env vars.
CIADPI_HOST="${CIADPI_HOST:-127.0.0.1}"
CIADPI_PORT="${CIADPI_PORT:-1080}"

# Yandex DNS (matches the Windows scripts' --dns-addr 77.88.8.8 default).
DEFAULT_DNS_V4_PRIMARY="${DEFAULT_DNS_V4_PRIMARY:-77.88.8.8}"
DEFAULT_DNS_V4_SECONDARY="${DEFAULT_DNS_V4_SECONDARY:-77.88.8.1}"

# ---- logging ---------------------------------------------------------------

log()  { printf '\033[1;34m[goodbyedpi-turkey]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[goodbyedpi-turkey]\033[0m %s\n' "$*" >&2; }
err()  { printf '\033[1;31m[goodbyedpi-turkey]\033[0m %s\n' "$*" >&2; }
die()  { err "$*"; exit 1; }

# ---- prerequisite checks ---------------------------------------------------

require_macos() {
    if [[ "$(uname -s)" != "Darwin" ]]; then
        die "These scripts only run on macOS. For Windows, use the .cmd files in windows/."
    fi
}

require_root() {
    if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
        log "Yönetici (root) yetkisi gerekiyor — sudo ile yeniden başlatılıyor..."
        # Re-exec the *original* script (passed in as $1) under sudo,
        # preserving its arguments and our tweakable env vars.
        local script="$1"; shift
        exec sudo \
            --preserve-env=CIADPI_HOST,CIADPI_PORT,DEFAULT_DNS_V4_PRIMARY,DEFAULT_DNS_V4_SECONDARY \
            "$script" "$@"
    fi
}

require_ciadpi() {
    if [[ ! -x "$CIADPI_BIN" ]]; then
        err "ciadpi bulunamadı: $CIADPI_BIN"
        err "Önce derleyin:  cd \"$MACOS_DIR\" && ./build.sh"
        exit 1
    fi
}

# ---- network service detection --------------------------------------------

# Print the BSD device name of the default route's interface (e.g. "en0").
default_interface() {
    route -n get default 2>/dev/null | awk '/interface:/{print $2; exit}'
}

# Print the human-readable network service name (e.g. "Wi-Fi", "Ethernet")
# associated with the default route. networksetup's commands need this name,
# not the BSD device name. Falls back to "Wi-Fi" with a warning.
detect_network_service() {
    local dev service
    dev="$(default_interface || true)"
    if [[ -z "${dev:-}" ]]; then
        warn "Varsayılan ağ arayüzü tespit edilemedi; 'Wi-Fi' varsayılıyor."
        echo "Wi-Fi"
        return 0
    fi

    # networksetup -listallhardwareports prints groups like:
    #   Hardware Port: Wi-Fi
    #   Device: en0
    #   Ethernet Address: ...
    service="$(/usr/sbin/networksetup -listallhardwareports 2>/dev/null \
        | awk -v dev="$dev" '
            /^Hardware Port:/ { hp = substr($0, index($0,$3)) }
            /^Device:/        { if ($2 == dev) { print hp; exit } }
        ')"

    if [[ -z "${service:-}" ]]; then
        warn "BSD arayüzü '$dev' bir networksetup servisine eşlenemedi; 'Wi-Fi' varsayılıyor."
        service="Wi-Fi"
    fi
    echo "$service"
}

# ---- state save / restore --------------------------------------------------

# Write current SOCKS proxy + DNS state for the given service into STATE_FILE
# so a later cleanup_and_restore can put things back exactly as they were.
save_network_state() {
    local service="$1"
    mkdir -p "$STATE_DIR"

    # SOCKS proxy info (printed as "Enabled: Yes/No\nServer: ...\nPort: ...\n...")
    local socks_info
    socks_info="$(/usr/sbin/networksetup -getsocksfirewallproxy "$service" 2>/dev/null || true)"
    local socks_enabled socks_server socks_port
    socks_enabled="$(echo "$socks_info" | awk -F': ' '/^Enabled:/{print $2; exit}')"
    socks_server="$(echo  "$socks_info" | awk -F': ' '/^Server:/{print $2; exit}')"
    socks_port="$(echo    "$socks_info" | awk -F': ' '/^Port:/{print $2; exit}')"

    # DNS servers (one per line, or "There aren't any DNS Servers set ...")
    local dns_list
    dns_list="$(/usr/sbin/networksetup -getdnsservers "$service" 2>/dev/null || true)"
    if [[ "$dns_list" == *"aren't any DNS"* || -z "${dns_list:-}" ]]; then
        dns_list="empty"
    else
        # Compress to space-separated.
        dns_list="$(echo "$dns_list" | tr '\n' ' ' | sed 's/ *$//')"
    fi

    {
        echo "# Saved by GoodbyeDPI-Turkey on $(date '+%Y-%m-%d %H:%M:%S')"
        echo "SERVICE=$(printf '%q' "$service")"
        echo "PREV_SOCKS_ENABLED=$(printf '%q' "${socks_enabled:-No}")"
        echo "PREV_SOCKS_SERVER=$(printf '%q'  "${socks_server:-}")"
        echo "PREV_SOCKS_PORT=$(printf '%q'    "${socks_port:-}")"
        echo "PREV_DNS=$(printf '%q'           "${dns_list}")"
    } > "$STATE_FILE"

    log "Önceki ağ ayarları kaydedildi: $STATE_FILE"
}

# ---- proxy / DNS apply -----------------------------------------------------

apply_proxy() {
    local service="$1"
    log "SOCKS proxy ayarlanıyor: ${service} -> ${CIADPI_HOST}:${CIADPI_PORT}"
    /usr/sbin/networksetup -setsocksfirewallproxy      "$service" "$CIADPI_HOST" "$CIADPI_PORT"
    /usr/sbin/networksetup -setsocksfirewallproxystate "$service" on
}

clear_proxy() {
    local service="$1"
    /usr/sbin/networksetup -setsocksfirewallproxystate "$service" off || true
}

apply_dns() {
    local service="$1"
    log "DNS sunucuları ayarlanıyor: ${service} -> ${DEFAULT_DNS_V4_PRIMARY} ${DEFAULT_DNS_V4_SECONDARY}"
    /usr/sbin/networksetup -setdnsservers "$service" \
        "$DEFAULT_DNS_V4_PRIMARY" "$DEFAULT_DNS_V4_SECONDARY"
}

# Restore DNS to "use DHCP-supplied servers".
clear_dns() {
    local service="$1"
    /usr/sbin/networksetup -setdnsservers "$service" "Empty" || true
}

# ---- cleanup trap ----------------------------------------------------------

# Restore state recorded by save_network_state(). Safe to call multiple times.
cleanup_and_restore() {
    if [[ ! -f "$STATE_FILE" ]]; then
        return 0
    fi

    # shellcheck disable=SC1090
    source "$STATE_FILE"
    local svc="${SERVICE:-}"
    if [[ -z "$svc" ]]; then
        rm -f "$STATE_FILE"
        return 0
    fi

    log "Ağ ayarları eski haline döndürülüyor (${svc})..."

    if [[ "${PREV_SOCKS_ENABLED:-No}" == "Yes" ]] \
       && [[ -n "${PREV_SOCKS_SERVER:-}" ]] \
       && [[ -n "${PREV_SOCKS_PORT:-}" ]]; then
        /usr/sbin/networksetup -setsocksfirewallproxy \
            "$svc" "$PREV_SOCKS_SERVER" "$PREV_SOCKS_PORT" || true
        /usr/sbin/networksetup -setsocksfirewallproxystate "$svc" on || true
    else
        /usr/sbin/networksetup -setsocksfirewallproxystate "$svc" off || true
    fi

    if [[ -z "${PREV_DNS:-}" || "${PREV_DNS}" == "empty" ]]; then
        /usr/sbin/networksetup -setdnsservers "$svc" "Empty" || true
    else
        # shellcheck disable=SC2086
        /usr/sbin/networksetup -setdnsservers "$svc" ${PREV_DNS} || true
    fi

    rm -f "$STATE_FILE"
    log "Geri yükleme tamamlandı."
}

install_cleanup_trap() {
    # EXIT fires for any exit (normal, Ctrl-C, kill, error). Using only EXIT
    # avoids running the restore logic twice when a signal arrives.
    trap cleanup_and_restore EXIT
}

# ---- method definitions ----------------------------------------------------
#
# These are functional macOS equivalents of the Windows GoodbyeDPI-Turkey
# methods. They are NOT bit-for-bit copies — the most powerful Windows trick
# (a fake packet with a low TTL, used by goodbyedpi.exe's -5/-9 presets) is
# not implementable in userspace on macOS, because byedpi's `--fake`/`--ttl`
# options are Windows/Linux only. We compensate with `--split`, `--disorder`,
# `--tlsrec`, `--oob` and HTTP header mixing, which the byedpi maintainers
# explicitly recommend on BSD/macOS.
#
# The mapping below was chosen to mimic each Windows method's behaviour as
# closely as possible: methods that use `--set-ttl 5` (an aggressive fake
# packet) map to `--split 1+s --disorder 3+s` (aggressive ClientHello
# fragmentation + reordering); methods built around `--set-ttl 3` (lighter)
# map to `--disorder 3+s`; the `-9` preset (no fake packet, fragment + record
# split) maps cleanly to `--split 1+s --tlsrec 1+s`.
#
# DNS_MODE = "yandex"  -> force the system DNS to Yandex (matches the
#                         Windows scripts that pass --dns-addr 77.88.8.8).
# DNS_MODE = "off"     -> leave DNS untouched (mirrors the Windows scripts
#                         that do NOT pass --dns-addr).
#
# Edit the arrays below if you find a combination that works better for
# your ISP and want to make it the default.

method_args() {
    case "$1" in
        default)
            # Mirrors: goodbyedpi.exe -5 --set-ttl 5 --dns-addr Yandex
            echo "--split 1+s --disorder 3+s --tlsrec 3+s --mod-http hcsmix,dcsmix"
            ;;
        alt)
            # Mirrors: goodbyedpi.exe --set-ttl 3
            echo "--disorder 3+s --tlsrec 3+s"
            ;;
        alt2)
            # Mirrors: goodbyedpi.exe -5
            echo "--split 1+s --disorder 3+s --mod-http hcsmix,dcsmix"
            ;;
        alt3)
            # Mirrors: goodbyedpi.exe --set-ttl 3 --dns-addr Yandex
            echo "--disorder 1+s --tlsrec 1+s"
            ;;
        alt4)
            # Mirrors: goodbyedpi.exe -5 --dns-addr Yandex
            echo "--split 1+s --disorder 3+s --mod-http hcsmix,dcsmix"
            ;;
        alt5)
            # Mirrors: goodbyedpi.exe -9 --dns-addr Yandex
            echo "--split 1+s --tlsrec 1+s --mod-http hcsmix,dcsmix"
            ;;
        alt6)
            # Mirrors: goodbyedpi.exe -9
            echo "--split 1+s --tlsrec 1+s"
            ;;
        *)
            die "Bilinmeyen yöntem: $1"
            ;;
    esac
}

method_dns_mode() {
    case "$1" in
        default|alt3|alt4|alt5) echo "yandex" ;;
        alt|alt2|alt6)          echo "off"    ;;
        *) die "Bilinmeyen yöntem: $1" ;;
    esac
}

# Convenience: run the full one-shot workflow for the given method name.
# Args: $1 = method name (default | alt | alt2 | alt3 | alt4 | alt5 | alt6)
run_method_oneshot() {
    local method="$1"
    require_macos
    require_root "$0"
    require_ciadpi

    local service
    service="$(detect_network_service)"
    log "Aktif ağ servisi: ${service}"

    save_network_state "$service"
    install_cleanup_trap

    apply_proxy "$service"
    if [[ "$(method_dns_mode "$method")" == "yandex" ]]; then
        apply_dns "$service"
    fi

    # shellcheck disable=SC2046
    start_ciadpi_foreground $(method_args "$method")
}

# ---- launchd service helpers ----------------------------------------------

# Render the plist template, replacing @LABEL@, @CIADPI@ and the
# <!-- ARGS_PLACEHOLDER --> marker line with one <string>…</string> per
# trailing argument.
# Args:
#   $1     = LaunchDaemon label
#   $2     = absolute path to ciadpi
#   $3..$n = ciadpi CLI arguments (each becomes its own <string> element)
render_plist() {
    local label="$1"; shift
    local bin="$1";   shift

    if [[ ! -f "$LAUNCHD_TEMPLATE" ]]; then
        die "launchd şablonu bulunamadı: $LAUNCHD_TEMPLATE"
    fi

    local args=("$@")

    # Read the template line by line; when we hit the marker, emit a
    # <string> element for each arg in its place. Doing it in pure bash
    # avoids awk's "newline in -v" limitation and keeps escaping under
    # our control.
    local line
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" == *"<!-- ARGS_PLACEHOLDER -->"* ]]; then
            for a in "${args[@]}"; do
                local escaped="${a//&/&amp;}"
                escaped="${escaped//</&lt;}"
                escaped="${escaped//>/&gt;}"
                printf '        <string>%s</string>\n' "$escaped"
            done
            continue
        fi
        # Substitute the two simple placeholders, line at a time.
        line="${line//@LABEL@/$label}"
        line="${line//@CIADPI@/$bin}"
        printf '%s\n' "$line"
    done < "$LAUNCHD_TEMPLATE"
}

# Install (or replace) the launchd service for the given method, then start
# it. Also applies the system-wide SOCKS proxy + (optionally) Yandex DNS so
# that the service is actually used by applications.
# Args: $1 = method name
run_method_service_install() {
    local method="$1"
    require_macos
    require_root "$0"
    require_ciadpi

    local service
    service="$(detect_network_service)"
    log "Aktif ağ servisi: ${service}"

    # First time install: snapshot existing state once so service_remove can
    # restore it. Do not overwrite an existing snapshot — that would lose the
    # *original* state if the install script is run multiple times.
    if [[ ! -f "$STATE_FILE" ]]; then
        save_network_state "$service"
    else
        log "Önceki ağ ayarı kaydı mevcut, korunuyor: $STATE_FILE"
    fi

    # Stop and unload any prior instance so we can safely replace the plist.
    if launchctl print "system/${LAUNCHD_LABEL}" >/dev/null 2>&1; then
        log "Eski hizmet durduruluyor..."
        launchctl bootout "system/${LAUNCHD_LABEL}" 2>/dev/null || true
    fi
    rm -f "$LAUNCHD_PLIST"

    log "Yeni launchd plist yazılıyor: $LAUNCHD_PLIST"
    # shellcheck disable=SC2046
    render_plist "$LAUNCHD_LABEL" "$CIADPI_BIN" \
        -i "$CIADPI_HOST" -p "$CIADPI_PORT" $(method_args "$method") \
        > "$LAUNCHD_PLIST"
    chown root:wheel "$LAUNCHD_PLIST"
    chmod 0644 "$LAUNCHD_PLIST"

    log "Hizmet yükleniyor ve başlatılıyor..."
    launchctl bootstrap system "$LAUNCHD_PLIST"
    launchctl enable "system/${LAUNCHD_LABEL}" 2>/dev/null || true
    launchctl kickstart -k "system/${LAUNCHD_LABEL}" 2>/dev/null || true

    apply_proxy "$service"
    if [[ "$(method_dns_mode "$method")" == "yandex" ]]; then
        apply_dns "$service"
    fi

    log "Hizmet kuruldu: ${LAUNCHD_LABEL}"
    log "Durum görmek için:  sudo launchctl print system/${LAUNCHD_LABEL}"
    log "Kaldırmak için   :  sudo $(dirname "$0")/service_remove.sh"
}

run_service_remove() {
    require_macos
    require_root "$0"

    if launchctl print "system/${LAUNCHD_LABEL}" >/dev/null 2>&1; then
        log "Hizmet durduruluyor: ${LAUNCHD_LABEL}"
        launchctl bootout "system/${LAUNCHD_LABEL}" 2>/dev/null || true
    else
        log "Hizmet zaten yüklü değil: ${LAUNCHD_LABEL}"
    fi

    if [[ -f "$LAUNCHD_PLIST" ]]; then
        log "Plist siliniyor: $LAUNCHD_PLIST"
        rm -f "$LAUNCHD_PLIST"
    fi

    # Restore proxy + DNS to whatever was active before installation.
    cleanup_and_restore

    log "GoodbyeDPI-Turkey kaldırıldı."
}

# ---- ciadpi runner ---------------------------------------------------------

# Run ciadpi in the foreground with the supplied args.
# The caller is expected to have arranged proxy / DNS / cleanup beforehand.
# We deliberately do NOT exec — we run ciadpi as a child and `wait`, so that
# the EXIT/INT/TERM trap (cleanup_and_restore) still fires when ciadpi exits
# or the user hits Ctrl-C.
start_ciadpi_foreground() {
    log "ciadpi başlatılıyor: $CIADPI_BIN -i $CIADPI_HOST -p $CIADPI_PORT $*"
    log "Ctrl-C veya pencereyi kapatmak GoodbyeDPI-Turkey'i durdurur."
    "$CIADPI_BIN" -i "$CIADPI_HOST" -p "$CIADPI_PORT" "$@" &
    local pid=$!
    # Forward SIGINT/SIGTERM to the child so it shuts down gracefully.
    trap 'kill -TERM '"$pid"' 2>/dev/null || true' INT TERM
    wait "$pid"
}
