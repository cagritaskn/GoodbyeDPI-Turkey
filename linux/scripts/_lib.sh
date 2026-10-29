#!/usr/bin/env bash
# Shared helpers for the Linux GoodbyeDPI-Turkey scripts.
#
# This file is sourced, not executed. The Linux port runs byedpi (ciadpi) as a
# transparent proxy and steers TCP 80/443 into it with nftables, so every
# program is covered without per-app proxy settings. ciadpi runs as the
# unprivileged "goodbyedpi" user; its own outgoing connections are matched by
# that uid and left alone, which is what keeps the redirect from looping.
#
# Optional, all set in /etc/goodbyedpi-turkey/config.env (env vars override):
#   SPLIT_TUNNEL=1        desync only the domains in split-tunnel-domains.txt
#   REDIRECT_LOCAL=0      leave this machine's own traffic alone
#   FORWARD_SOURCES="..." also redirect traffic routed through this machine
#                         from these IPv4 CIDRs (Docker networks, VMs, LAN)
#   DNS_MODE=off|yandex   override the method's DNS behaviour

set -euo pipefail

# ---- paths -----------------------------------------------------------------

_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINUX_DIR="$(cd "${_LIB_DIR}/.." && pwd)"
BUILT_CIADPI="${LINUX_DIR}/bin/ciadpi"

# ciadpi and these scripts are copied here so the unprivileged user can run the
# binary and the service keeps working if the checkout moves.
LIBEXEC_DIR="/usr/local/libexec/goodbyedpi-turkey"
CIADPI_BIN="${LIBEXEC_DIR}/ciadpi"

CONFIG_DIR="/etc/goodbyedpi-turkey"
CONFIG_FILE="${CONFIG_DIR}/config.env"
DOMAINS_FILE="${CONFIG_DIR}/split-tunnel-domains.txt"

STATE_DIR="/var/lib/goodbyedpi-turkey"
DNS_STATE_FILE="${STATE_DIR}/prev-dns.env"
HOSTS_RUNTIME_FILE="${STATE_DIR}/hosts.txt"

SERVICE_NAME="goodbyedpi-turkey"
SERVICE_UNIT="/etc/systemd/system/${SERVICE_NAME}.service"
SERVICE_TEMPLATE="${LINUX_DIR}/systemd/${SERVICE_NAME}.service.template"

CIADPI_USER="goodbyedpi"
NFT_TABLE="goodbyedpi_turkey"

# KEY=value lines; a variable already set in the environment wins.
if [[ -f "$CONFIG_FILE" ]]; then
    while IFS='=' read -r _key _value; do
        [[ "$_key" =~ ^[A-Z_][A-Z0-9_]*$ ]] || continue
        [[ -n "${!_key+x}" ]] && continue
        _value="${_value%\"}"
        printf -v "$_key" '%s' "${_value#\"}"
    done < "$CONFIG_FILE"
    unset _key _value
fi

CIADPI_PORT="${CIADPI_PORT:-1080}"
SPLIT_TUNNEL="${SPLIT_TUNNEL:-0}"
REDIRECT_LOCAL="${REDIRECT_LOCAL:-1}"
FORWARD_SOURCES="${FORWARD_SOURCES:-}"
DNS_MODE="${DNS_MODE:-}"

# Yandex DNS (matches the Windows scripts' --dns-addr 77.88.8.8 default).
DEFAULT_DNS_V4_PRIMARY="${DEFAULT_DNS_V4_PRIMARY:-77.88.8.8}"
DEFAULT_DNS_V4_SECONDARY="${DEFAULT_DNS_V4_SECONDARY:-77.88.8.1}"

# Never redirected: loopback, private and link-local ranges.
NFT_SKIP_V4="127.0.0.0/8, 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 100.64.0.0/10, 169.254.0.0/16"
NFT_SKIP_V6="::1, fc00::/7, fe80::/10"

# ---- logging ---------------------------------------------------------------

log()  { printf '\033[1;34m[goodbyedpi-turkey]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[goodbyedpi-turkey]\033[0m %s\n' "$*" >&2; }
err()  { printf '\033[1;31m[goodbyedpi-turkey]\033[0m %s\n' "$*" >&2; }
die()  { err "$*"; exit 1; }

# ---- prerequisite checks ---------------------------------------------------

require_linux() {
    if [[ "$(uname -s)" != "Linux" ]]; then
        die "Bu scriptler sadece Linux'ta çalışır. macOS için macos/, Windows için windows/ klasörüne bakın."
    fi
}

require_root() {
    if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
        log "Yönetici (root) yetkisi gerekiyor — sudo ile yeniden başlatılıyor..."
        local script="$1"; shift
        exec sudo \
            --preserve-env=CIADPI_PORT,SPLIT_TUNNEL,REDIRECT_LOCAL,FORWARD_SOURCES,DNS_MODE,DEFAULT_DNS_V4_PRIMARY,DEFAULT_DNS_V4_SECONDARY \
            "$script" "$@"
    fi
}

require_tools() {
    local tool
    for tool in nft runuser; do
        command -v "$tool" >/dev/null 2>&1 || die "Gerekli araç bulunamadı: $tool (nftables / util-linux paketini kurun)"
    done
}

require_built_ciadpi() {
    if [[ ! -x "$BUILT_CIADPI" ]]; then
        err "ciadpi bulunamadı: $BUILT_CIADPI"
        err "Önce derleyin:  cd \"$LINUX_DIR\" && ./build.sh"
        exit 1
    fi
}

# ---- installation ----------------------------------------------------------

ensure_user() {
    if ! id -u "$CIADPI_USER" >/dev/null 2>&1; then
        log "Sistem kullanıcısı oluşturuluyor: $CIADPI_USER"
        useradd --system --no-create-home --home-dir /nonexistent \
            --shell /usr/sbin/nologin "$CIADPI_USER"
    fi
}

# Copy ciadpi, these scripts and the default domain list into system paths.
install_runtime() {
    require_built_ciadpi
    ensure_user

    install -d -m 0755 "$LIBEXEC_DIR" "$CONFIG_DIR" "$STATE_DIR"
    install -m 0755 "$BUILT_CIADPI" "$CIADPI_BIN"
    install -m 0644 "${_LIB_DIR}/_lib.sh" "${LIBEXEC_DIR}/_lib.sh"
    install -m 0755 "${_LIB_DIR}/_run.sh" "${LIBEXEC_DIR}/_run.sh"

    if [[ ! -f "$DOMAINS_FILE" ]]; then
        install -m 0644 "${LINUX_DIR}/split-tunnel-domains.txt" "$DOMAINS_FILE"
        log "Domain listesi kopyalandı: $DOMAINS_FILE"
    fi
    if [[ ! -f "$CONFIG_FILE" ]]; then
        cat > "$CONFIG_FILE" <<'EOF'
# GoodbyeDPI-Turkey (Linux). Environment variables override these.
SPLIT_TUNNEL=0
REDIRECT_LOCAL=1
# Space-separated IPv4 CIDRs whose routed traffic is also redirected,
# e.g. a Docker network: FORWARD_SOURCES="172.18.0.0/16"
FORWARD_SOURCES=""
EOF
        log "Ayar dosyası oluşturuldu: $CONFIG_FILE"
    fi
}

# Set a KEY=value line in CONFIG_FILE, adding it if missing.
config_set() {
    local key="$1" value="$2"
    install -d -m 0755 "$CONFIG_DIR"
    touch "$CONFIG_FILE"
    if grep -q "^${key}=" "$CONFIG_FILE"; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$CONFIG_FILE"
    else
        printf '%s=%s\n' "$key" "$value" >> "$CONFIG_FILE"
    fi
}

# ---- nftables --------------------------------------------------------------

apply_nft() {
    local sources="" cidr
    for cidr in $FORWARD_SOURCES; do
        sources+="${sources:+, }${cidr}"
    done

    local output_rules="" prerouting_rules="" input_rules
    if [[ "$REDIRECT_LOCAL" == "1" ]]; then
        output_rules="
        meta skuid \"${CIADPI_USER}\" return
        ip daddr { ${NFT_SKIP_V4} } return
        ip6 daddr { ${NFT_SKIP_V6} } return
        tcp dport { 80, 443 } redirect to :${CIADPI_PORT}"
    fi
    input_rules="
        tcp dport ${CIADPI_PORT} iif \"lo\" accept"
    if [[ -n "$sources" ]]; then
        prerouting_rules="
        ip saddr { ${sources} } ip daddr != { ${NFT_SKIP_V4} } tcp dport { 80, 443 } redirect to :${CIADPI_PORT}"
        input_rules+="
        tcp dport ${CIADPI_PORT} ip saddr { ${sources} } accept"
    fi
    # ciadpi listens on every interface so forwarded traffic can reach it;
    # nothing but loopback and FORWARD_SOURCES may connect.
    input_rules+="
        tcp dport ${CIADPI_PORT} drop"

    clear_nft
    log "nftables kuralları uygulanıyor (tablo: inet ${NFT_TABLE})"
    nft -f - <<EOF
table inet ${NFT_TABLE} {
    chain output {
        type nat hook output priority dstnat; policy accept;${output_rules}
    }
    chain prerouting {
        type nat hook prerouting priority dstnat; policy accept;${prerouting_rules}
    }
    chain input {
        type filter hook input priority filter; policy accept;${input_rules}
    }
}
EOF
}

clear_nft() {
    nft delete table inet "$NFT_TABLE" 2>/dev/null || true
}

# ---- DNS -------------------------------------------------------------------

# systemd-resolved is in charge when resolv.conf points at its stub.
uses_resolved() {
    command -v resolvectl >/dev/null 2>&1 \
        && grep -qE '^nameserver 127\.0\.0\.53' /etc/resolv.conf 2>/dev/null
}

default_interface() {
    ip -4 route show default 2>/dev/null | awk '{for (i = 1; i < NF; i++) if ($i == "dev") {print $(i + 1); exit}}'
}

apply_dns() {
    install -d -m 0755 "$STATE_DIR"
    if uses_resolved; then
        local iface
        iface="$(default_interface)"
        [[ -n "$iface" ]] || die "Varsayılan ağ arayüzü bulunamadı."
        printf 'DNS_BACKEND=resolved\nDNS_IFACE=%q\n' "$iface" > "$DNS_STATE_FILE"
        log "DNS ayarlanıyor (systemd-resolved, ${iface}): ${DEFAULT_DNS_V4_PRIMARY} ${DEFAULT_DNS_V4_SECONDARY}"
        resolvectl dns "$iface" "$DEFAULT_DNS_V4_PRIMARY" "$DEFAULT_DNS_V4_SECONDARY"
        resolvectl domain "$iface" '~.'
    else
        local backup="${STATE_DIR}/resolv.conf.bak" link=""
        if [[ -L /etc/resolv.conf ]]; then
            link="$(readlink /etc/resolv.conf)"
        else
            cp -p /etc/resolv.conf "$backup"
        fi
        printf 'DNS_BACKEND=file\nDNS_LINK=%q\n' "$link" > "$DNS_STATE_FILE"
        log "DNS ayarlanıyor (/etc/resolv.conf): ${DEFAULT_DNS_V4_PRIMARY} ${DEFAULT_DNS_V4_SECONDARY}"
        rm -f /etc/resolv.conf
        printf 'nameserver %s\nnameserver %s\n' "$DEFAULT_DNS_V4_PRIMARY" "$DEFAULT_DNS_V4_SECONDARY" > /etc/resolv.conf
    fi
}

restore_dns() {
    [[ -f "$DNS_STATE_FILE" ]] || return 0
    local DNS_BACKEND="" DNS_IFACE="" DNS_LINK=""
    # shellcheck disable=SC1090
    source "$DNS_STATE_FILE"
    if [[ "$DNS_BACKEND" == "resolved" ]]; then
        resolvectl revert "$DNS_IFACE" || true
    elif [[ "$DNS_BACKEND" == "file" ]]; then
        rm -f /etc/resolv.conf
        if [[ -n "$DNS_LINK" ]]; then
            ln -s "$DNS_LINK" /etc/resolv.conf
        elif [[ -f "${STATE_DIR}/resolv.conf.bak" ]]; then
            mv "${STATE_DIR}/resolv.conf.bak" /etc/resolv.conf
        fi
    fi
    rm -f "$DNS_STATE_FILE"
    log "DNS ayarı eski haline döndürüldü."
}

# ---- cleanup ---------------------------------------------------------------

# Safe to call multiple times.
cleanup_and_restore() {
    clear_nft
    restore_dns
}

install_cleanup_trap() {
    trap cleanup_and_restore EXIT
}

# ---- method definitions ----------------------------------------------------
#
# Same mapping as macos/scripts/_lib.sh (see the table in macos/README.md), so a
# method that works for an ISP on macOS works the same way here. byedpi also
# supports `--fake`/`--ttl` on Linux; edit these if a TTL-based variant works
# better for your ISP.

method_args() {
    case "$1" in
        default) echo "--split 1+s --disorder 3+s --tlsrec 3+s --mod-http hcsmix,dcsmix" ;;
        alt)     echo "--disorder 3+s --tlsrec 3+s" ;;
        alt2)    echo "--split 1+s --disorder 3+s --mod-http hcsmix,dcsmix" ;;
        alt3)    echo "--disorder 1+s --tlsrec 1+s" ;;
        alt4)    echo "--split 1+s --disorder 3+s --mod-http hcsmix,dcsmix" ;;
        alt5)    echo "--split 1+s --tlsrec 1+s --mod-http hcsmix,dcsmix" ;;
        alt6)    echo "--split 1+s --tlsrec 1+s" ;;
        *)       die "Bilinmeyen yöntem: $1" ;;
    esac
}

method_dns_mode() {
    if [[ -n "$DNS_MODE" ]]; then
        echo "$DNS_MODE"
        return
    fi
    case "$1" in
        default|alt3|alt4|alt5) echo "yandex" ;;
        alt|alt2|alt6)          echo "off"    ;;
        *) die "Bilinmeyen yöntem: $1" ;;
    esac
}

# Full ciadpi argument list for a method, honouring SPLIT_TUNNEL.
ciadpi_args() {
    local method="$1"
    local args=(-i :: -p "$CIADPI_PORT" --transparent)
    # shellcheck disable=SC2207
    local desync=($(method_args "$method"))

    if [[ "$SPLIT_TUNNEL" == "1" ]]; then
        [[ -f "$DOMAINS_FILE" ]] || die "Domain listesi bulunamadı: $DOMAINS_FILE"
        # byedpi has no comment syntax: strip comments and blank lines.
        sed -e 's/#.*//' -e 's/[[:space:]]*$//' -e '/^$/d' "$DOMAINS_FILE" > "$HOSTS_RUNTIME_FILE"
        chmod 0644 "$HOSTS_RUNTIME_FILE"
        # Desync the listed hosts; the empty group after --auto=none passes
        # everything else through untouched.
        args+=(--hosts "$HOSTS_RUNTIME_FILE" "${desync[@]}" --auto=none)
    else
        args+=("${desync[@]}")
    fi
    printf '%s\n' "${args[@]}"
}

# ---- runner ----------------------------------------------------------------

# Apply nftables (+ DNS), run ciadpi as the unprivileged user in the
# foreground, and undo everything when it exits. Used by the one-shot scripts
# and by the systemd service.
run_ciadpi() {
    local method="$1"
    require_tools
    [[ -x "$CIADPI_BIN" ]] || die "ciadpi kurulu değil: $CIADPI_BIN"

    if [[ "$REDIRECT_LOCAL" != "1" && -z "$FORWARD_SOURCES" ]]; then
        die "REDIRECT_LOCAL=0 ve FORWARD_SOURCES boş: yönlendirilecek trafik yok."
    fi

    local args
    mapfile -t args < <(ciadpi_args "$method")

    install -d -m 0755 "$STATE_DIR"
    install_cleanup_trap
    apply_nft
    if [[ "$(method_dns_mode "$method")" == "yandex" ]]; then
        apply_dns
    fi

    log "Yöntem: ${method} · split tunnel: ${SPLIT_TUNNEL} · yerel trafik: ${REDIRECT_LOCAL} · yönlendirilen ağlar: ${FORWARD_SOURCES:-yok}"
    log "ciadpi başlatılıyor: $CIADPI_BIN ${args[*]}"
    runuser -u "$CIADPI_USER" -- "$CIADPI_BIN" "${args[@]}" &
    local pid=$!
    trap 'kill -TERM '"$pid"' 2>/dev/null || true' INT TERM
    wait "$pid"
}

run_method_oneshot() {
    local method="$1"
    require_linux
    require_root "$0"
    require_tools
    install_runtime
    log "Ctrl-C GoodbyeDPI-Turkey'i durdurur ve ayarları geri alır."
    run_ciadpi "$method"
}

# ---- systemd service -------------------------------------------------------

require_systemd() {
    [[ -d /run/systemd/system ]] || die "systemd çalışmıyor; tek seferlik scriptleri (turkey_dnsredir*.sh) kullanın."
}

run_method_service_install() {
    local method="$1"
    require_linux
    require_root "$0"
    require_tools
    require_systemd
    install_runtime

    [[ -f "$SERVICE_TEMPLATE" ]] || die "systemd şablonu bulunamadı: $SERVICE_TEMPLATE"
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        log "Eski hizmet durduruluyor..."
        systemctl stop "$SERVICE_NAME"
    fi

    log "systemd birimi yazılıyor: $SERVICE_UNIT"
    sed -e "s|@RUNNER@|${LIBEXEC_DIR}/_run.sh|" -e "s|@METHOD@|${method}|g" \
        "$SERVICE_TEMPLATE" > "$SERVICE_UNIT"
    chmod 0644 "$SERVICE_UNIT"

    systemctl daemon-reload
    systemctl enable --now "$SERVICE_NAME"

    log "Hizmet kuruldu: ${SERVICE_NAME} (${method})"
    log "Durum görmek için:  systemctl status ${SERVICE_NAME}   ·   journalctl -u ${SERVICE_NAME} -f"
    log "Kaldırmak için   :  sudo $(dirname "$0")/service_remove.sh"
}

run_service_remove() {
    require_linux
    require_root "$0"

    if [[ -f "$SERVICE_UNIT" ]]; then
        log "Hizmet durduruluyor: ${SERVICE_NAME}"
        systemctl disable --now "$SERVICE_NAME" 2>/dev/null || true
        rm -f "$SERVICE_UNIT"
        systemctl daemon-reload
    else
        log "Hizmet zaten yüklü değil: ${SERVICE_NAME}"
    fi

    # Leftovers of a run that did not exit cleanly.
    cleanup_and_restore
    rm -rf "$LIBEXEC_DIR"
    log "GoodbyeDPI-Turkey kaldırıldı. Ayarlar korundu: $CONFIG_DIR"
}
