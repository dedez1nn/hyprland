#!/usr/bin/env bash

set -u

PROTONVPN_BIN="${PROTONVPN_BIN:-protonvpn}"
COUNTRY_NAME="Brazil"

json_escape() {
  local value="${1//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  printf '%s' "$value"
}

emit() {
  local text="$1"
  local tooltip="$2"
  local class="$3"

  printf '{"text":"%s","tooltip":"%s","class":"%s"}\n' \
    "$(json_escape "$text")" \
    "$(json_escape "$tooltip")" \
    "$(json_escape "$class")"
}

if ! command -v "$PROTONVPN_BIN" >/dev/null 2>&1; then
  emit "" "ProtonVPN CLI nao encontrado." "error"
  exit 0
fi

status_output="$("$PROTONVPN_BIN" status 2>&1)"

if printf '%s\n' "$status_output" | grep -q '^Status: Connected'; then
  server_line="$(printf '%s\n' "$status_output" | sed -n 's/^Server: //p' | head -n 1)"
  protocol_line="$(printf '%s\n' "$status_output" | sed -n 's/^Protocol: //p' | head -n 1)"
  tooltip="ProtonVPN conectado"
  [ -n "$server_line" ] && tooltip+=$'\n'"${server_line}"
  [ -n "$protocol_line" ] && tooltip+=$'\n'"Protocolo: ${protocol_line}"
  tooltip+=$'\n'"Clique: desconectar"
  tooltip+=$'\n'"Clique direito: reconectar em ${COUNTRY_NAME}"
  emit "" "$tooltip" "connected"
  exit 0
fi

if printf '%s\n' "$status_output" | grep -q '^Status: Disconnected'; then
  emit "" "$(printf 'ProtonVPN desconectado\nClique para conectar em %s' "$COUNTRY_NAME")" "disconnected"
  exit 0
fi

if printf '%s\n' "$status_output" | grep -qi 'Authentication required'; then
  emit "" "$(printf 'ProtonVPN precisa de login.\nExecute: protonvpn signin')" "warning"
  exit 0
fi

if printf '%s\n' "$status_output" | grep -qi 'Operation not permitted\|PermissionError\|unexpected error occurred'; then
  emit "" "$(printf 'ProtonVPN indisponivel nesta sessao.\nAbra a Waybar na sua sessao grafica.')" "warning"
  exit 0
fi

emit "" "$(printf 'Falha ao consultar o ProtonVPN.\n%s' "$status_output")" "error"
