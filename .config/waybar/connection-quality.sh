#!/usr/bin/env bash

set -u

NMCLI_BIN="${NMCLI_BIN:-nmcli}"
PING_BIN="${PING_BIN:-ping}"
PING_TARGET="${PING_TARGET:-1.1.1.1}"
PING_COUNT="${PING_COUNT:-3}"
PING_TIMEOUT="${PING_TIMEOUT:-1}"

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

human_type() {
  case "$1" in
    wifi) printf 'Wi-Fi' ;;
    ethernet) printf 'Ethernet' ;;
    *) printf '%s' "$1" ;;
  esac
}

if ! command -v "$NMCLI_BIN" >/dev/null 2>&1; then
  emit "" "nmcli nao encontrado." "warning"
  exit 0
fi

if ! command -v "$PING_BIN" >/dev/null 2>&1; then
  emit "" "ping nao encontrado." "warning"
  exit 0
fi

device_status="$("$NMCLI_BIN" -t -f DEVICE,TYPE,STATE,CONNECTION dev status 2>&1)"

if printf '%s\n' "$device_status" | grep -qi 'Operation not permitted\|Could not connect'; then
  emit "" "Nao foi possivel consultar a rede nesta sessao." "warning"
  exit 0
fi

active_line="$(printf '%s\n' "$device_status" | awk -F: '$3=="connected"{print; exit}')"

if [ -z "$active_line" ]; then
  emit "" "Sem conexao ativa." "disconnected"
  exit 0
fi

IFS=':' read -r device_name device_type _ connection_name <<EOF
$active_line
EOF

wifi_signal=""
wifi_ssid=""

if [ "$device_type" = "wifi" ]; then
  wifi_info="$("$NMCLI_BIN" -t -f IN-USE,SIGNAL,SSID dev wifi 2>&1 | awk -F: '$1=="*"{print; exit}')"
  if [ -n "$wifi_info" ]; then
    IFS=':' read -r _ wifi_signal wifi_ssid <<EOF
$wifi_info
EOF
  fi
fi

ping_output="$("$PING_BIN" -n -c "$PING_COUNT" -W "$PING_TIMEOUT" "$PING_TARGET" 2>&1)"

if printf '%s\n' "$ping_output" | grep -qi 'Operation not permitted\|socket:'; then
  tooltip="Conexao ativa: $(human_type "$device_type")"
  if [ -n "$connection_name" ]; then
    tooltip+=$'\n'"Rede: ${connection_name}"
  fi
  if [ -n "$wifi_signal" ]; then
    tooltip+=$'\n'"Sinal: ${wifi_signal}%"
  fi
  tooltip+=$'\n'"Latencia indisponivel nesta sessao."
  emit "" "$tooltip" "warning"
  exit 0
fi

packet_loss="$(printf '%s\n' "$ping_output" | sed -n 's/.* \([0-9.]\+\)% packet loss.*/\1/p' | head -n 1)"
avg_latency="$(printf '%s\n' "$ping_output" | sed -n 's#.*= [0-9.]*/\([0-9.]\+\)/[0-9.]*/[0-9.]\+ ms#\1#p' | head -n 1)"

if [ -z "$packet_loss" ]; then
  packet_loss="100"
fi

quality_class="$(
  awk -v avg="${avg_latency:-999}" -v loss="$packet_loss" -v signal="${wifi_signal:-}" '
    BEGIN {
      if (loss >= 34 || avg >= 180 || (signal != "" && signal < 35)) {
        print "poor"
      } else if (loss > 0 || avg >= 80 || (signal != "" && signal < 60)) {
        print "reasonable"
      } else {
        print "good"
      }
    }
  '
)"

case "$quality_class" in
  good) label="Conexao boa" ;;
  reasonable) label="Conexao razoavel" ;;
  *) label="Conexao ruim" ;;
esac

tooltip="${label}"
tooltip+=$'\n'"Tipo: $(human_type "$device_type")"
if [ -n "$connection_name" ]; then
  tooltip+=$'\n'"Rede: ${connection_name}"
fi
if [ -n "$wifi_ssid" ]; then
  tooltip+=$'\n'"SSID: ${wifi_ssid}"
fi
if [ -n "$wifi_signal" ]; then
  tooltip+=$'\n'"Sinal: ${wifi_signal}%"
fi
if [ -n "$avg_latency" ]; then
  tooltip+=$'\n'"Latencia media: ${avg_latency} ms"
fi
tooltip+=$'\n'"Perda: ${packet_loss}%"

emit "" "$tooltip" "$quality_class"
