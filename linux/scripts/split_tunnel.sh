#!/usr/bin/env bash
# Switches split-tunnel mode on or off: with it on, only the domains in
# /etc/goodbyedpi-turkey/split-tunnel-domains.txt are desynced and everything
# else passes through ciadpi untouched. Restarts the service if it runs.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

usage() { echo "Kullanım: sudo $0 on|off|status"; exit 1; }

action="${1:-}"
case "$action" in
    on|off) ;;
    status)
        echo "split tunnel : ${SPLIT_TUNNEL}"
        echo "domain listesi: ${DOMAINS_FILE}"
        if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet "$SERVICE_NAME"; then
            echo "hizmet       : çalışıyor"
        else
            echo "hizmet       : çalışmıyor"
        fi
        exit 0
        ;;
    *) usage ;;
esac

require_linux
require_root "$0" "$action"
install_runtime

if [[ "$action" == "on" ]]; then
    config_set SPLIT_TUNNEL 1
    log "Split tunnel açıldı. Domain listesi: $DOMAINS_FILE"
else
    config_set SPLIT_TUNNEL 0
    log "Split tunnel kapatıldı: tüm HTTP/HTTPS trafiği desync'ten geçer."
fi

if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet "$SERVICE_NAME"; then
    log "Hizmet yeniden başlatılıyor..."
    systemctl restart "$SERVICE_NAME"
else
    log "Tek seferlik scripti çalıştırıyorsanız yeniden başlatın."
fi
