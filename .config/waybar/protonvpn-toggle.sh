#!/usr/bin/env bash

set -u

PROTONVPN_BIN="${PROTONVPN_BIN:-protonvpn}"
COUNTRY_NAME="Brazil"
WAYBAR_SIGNAL=8
MODE="${1:-toggle}"

notify() {
  if command -v notify-send >/dev/null 2>&1; then
    notify-send -a "waybar-protonvpn" "$1" "${2:-}"
  fi
}

refresh_waybar() {
  pkill -RTMIN+"$WAYBAR_SIGNAL" waybar >/dev/null 2>&1 || true
}

is_connected() {
  "$PROTONVPN_BIN" status 2>&1 | grep -q '^Status: Connected'
}

connect_brazil() {
  local output rc

  output="$("$PROTONVPN_BIN" connect --country "$COUNTRY_NAME" 2>&1)"
  rc=$?
  refresh_waybar

  if [ "$rc" -eq 0 ]; then
    notify "ProtonVPN" "Conectado em ${COUNTRY_NAME}."
    return 0
  fi

  notify "ProtonVPN" "Falha ao conectar em ${COUNTRY_NAME}."
  printf '%s\n' "$output" >&2
  return "$rc"
}

disconnect_vpn() {
  local output rc

  output="$("$PROTONVPN_BIN" disconnect 2>&1)"
  rc=$?
  refresh_waybar

  if [ "$rc" -eq 0 ]; then
    notify "ProtonVPN" "Desconectado."
    return 0
  fi

  notify "ProtonVPN" "Falha ao desconectar."
  printf '%s\n' "$output" >&2
  return "$rc"
}

if ! command -v "$PROTONVPN_BIN" >/dev/null 2>&1; then
  notify "ProtonVPN" "CLI nao encontrado."
  exit 1
fi

case "$MODE" in
  toggle)
    if is_connected; then
      disconnect_vpn
    else
      connect_brazil
    fi
    ;;
  connect)
    connect_brazil
    ;;
  disconnect)
    disconnect_vpn
    ;;
  *)
    notify "ProtonVPN" "Acao invalida: ${MODE}"
    exit 1
    ;;
esac
