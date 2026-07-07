#!/usr/bin/env bash

set -u

NMCLI_BIN="${NMCLI_BIN:-nmcli}"
PING_BIN="${PING_BIN:-ping}"
IP_BIN="${IP_BIN:-ip}"
PING_TARGET="${PING_TARGET:-1.1.1.1}"
PING_FALLBACK="${PING_FALLBACK:-8.8.8.8}"
PING_COUNT="${PING_COUNT:-5}"
PING_INTERVAL="${PING_INTERVAL:-0.3}"
PING_TIMEOUT="${PING_TIMEOUT:-1}"
GATEWAY_PING_COUNT="${GATEWAY_PING_COUNT:-3}"

ICON_GOOD=""
ICON_REASONABLE=""
ICON_POOR=""
ICON_WARNING=""
ICON_DISCONNECTED="󰌙"

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

# Pinga o destino e imprime "perda:media:jitter" ("blocked::" se ICMP negado)
run_ping() {
  local target="$1" count="$2"
  local output loss avg jitter

  output="$("$PING_BIN" -n -c "$count" -i "$PING_INTERVAL" -W "$PING_TIMEOUT" "$target" 2>&1)"

  if printf '%s\n' "$output" | grep -qi 'Operation not permitted\|socket:'; then
    printf 'blocked::'
    return
  fi

  loss="$(printf '%s\n' "$output" | sed -n 's/.* \([0-9.]\+\)% packet loss.*/\1/p' | head -n 1)"
  avg="$(printf '%s\n' "$output" | sed -n 's#.*= [0-9.]*/\([0-9.]\+\)/[0-9.]*/[0-9.]\+ ms#\1#p' | head -n 1)"
  jitter="$(printf '%s\n' "$output" | sed -n 's#.*= [0-9.]*/[0-9.]*/[0-9.]*/\([0-9.]\+\) ms#\1#p' | head -n 1)"

  printf '%s:%s:%s' "${loss:-100}" "$avg" "$jitter"
}

if ! command -v "$NMCLI_BIN" >/dev/null 2>&1; then
  emit "$ICON_WARNING" "nmcli nao encontrado." "warning"
  exit 0
fi

if ! command -v "$PING_BIN" >/dev/null 2>&1; then
  emit "$ICON_WARNING" "ping nao encontrado." "warning"
  exit 0
fi

device_status="$("$NMCLI_BIN" -t -f DEVICE,TYPE,STATE,CONNECTION dev status 2>&1)"

if printf '%s\n' "$device_status" | grep -qi 'Operation not permitted\|Could not connect'; then
  emit "$ICON_WARNING" "Nao foi possivel consultar a rede nesta sessao." "warning"
  exit 0
fi

# Prioriza wifi/ethernet para nao escolher a interface da VPN (tun/wireguard)
active_line="$(printf '%s\n' "$device_status" | awk -F: '$3=="connected" && ($2=="wifi" || $2=="ethernet"){print; exit}')"

if [ -z "$active_line" ]; then
  active_line="$(printf '%s\n' "$device_status" | awk -F: '$3=="connected"{print; exit}')"
fi

if [ -z "$active_line" ]; then
  emit "$ICON_DISCONNECTED" "Sem conexao ativa." "disconnected"
  exit 0
fi

IFS=':' read -r device_name device_type _ connection_name <<EOF
$active_line
EOF

connection_name="${connection_name//\\:/:}"

# tun generico (ex.: tailscale sempre ativo) nao conta: so VPN que roteia o trafego
vpn_active=""
if "$NMCLI_BIN" -t -f TYPE,NAME connection show --active 2>/dev/null \
  | grep -qiE '^(vpn|wireguard):|^tun:proton'; then
  vpn_active="1"
fi

wifi_signal=""
wifi_ssid=""

if [ "$device_type" = "wifi" ]; then
  # --rescan no: evita disparar scan de redes (deixava o modulo lento e mexe no radio)
  wifi_info="$("$NMCLI_BIN" -t -f IN-USE,SIGNAL,SSID dev wifi list --rescan no 2>&1 | awk -F: '$1=="*"{print; exit}')"
  if [ -n "$wifi_info" ]; then
    IFS=':' read -r _ wifi_signal wifi_ssid <<EOF
$wifi_info
EOF
    wifi_ssid="${wifi_ssid//\\:/:}"
  fi
fi

ping_used_target="$PING_TARGET"
IFS=':' read -r packet_loss avg_latency jitter <<EOF
$(run_ping "$PING_TARGET" "$PING_COUNT")
EOF

if [ "$packet_loss" = "blocked" ]; then
  tooltip="Conexao ativa: $(human_type "$device_type")"
  if [ -n "$connection_name" ]; then
    tooltip+=$'\n'"Rede: ${connection_name}"
  fi
  if [ -n "$wifi_signal" ]; then
    tooltip+=$'\n'"Sinal: ${wifi_signal}%"
  fi
  tooltip+=$'\n'"Latencia indisponivel nesta sessao."
  emit "$ICON_WARNING" "$tooltip" "warning"
  exit 0
fi

# Alvo primario pode bloquear ICMP: tenta o fallback antes de declarar perda total
if [ "${packet_loss%%.*}" -ge 100 ] 2>/dev/null; then
  IFS=':' read -r fb_loss fb_avg fb_jitter <<EOF
$(run_ping "$PING_FALLBACK" "$PING_COUNT")
EOF
  if [ "$fb_loss" != "blocked" ] && [ "${fb_loss%%.*}" -lt 100 ] 2>/dev/null; then
    packet_loss="$fb_loss"
    avg_latency="$fb_avg"
    jitter="$fb_jitter"
    ping_used_target="$PING_FALLBACK"
  fi
fi

# Ping ao gateway para separar problema local (Wi-Fi/roteador) de problema no provedor
gateway_ip=""
gateway_loss=""
gateway_avg=""

if command -v "$IP_BIN" >/dev/null 2>&1; then
  gateway_ip="$("$IP_BIN" route show default 2>/dev/null | awk '/^default via/{print $3; exit}')"
fi

if [ -n "$gateway_ip" ]; then
  IFS=':' read -r gateway_loss gateway_avg _ <<EOF
$(run_ping "$gateway_ip" "$GATEWAY_PING_COUNT")
EOF
  if [ "$gateway_loss" = "blocked" ]; then
    gateway_loss=""
  fi
fi

quality_class="$(
  awk -v avg="${avg_latency:-999}" -v loss="$packet_loss" -v signal="${wifi_signal:-}" -v vpn="${vpn_active:-}" '
    BEGIN {
      lat_poor = 180
      lat_warn = 80
      if (vpn != "") {
        # Tunel adiciona latencia: nao penalizar a conexao pela VPN
        lat_poor = 270
        lat_warn = 120
      }
      # Com 5 pings, 1 perdido = 20%: tolera 1 perda antes de rebaixar
      if (loss >= 40 || avg >= lat_poor || (signal != "" && signal < 30)) {
        print "poor"
      } else if (loss > 20 || avg >= lat_warn || (signal != "" && signal < 45)) {
        print "reasonable"
      } else {
        print "good"
      }
    }
  '
)"

case "$quality_class" in
  good) label="Conexao boa"; icon="$ICON_GOOD" ;;
  reasonable) label="Conexao razoavel"; icon="$ICON_REASONABLE" ;;
  *) label="Conexao ruim"; icon="$ICON_POOR" ;;
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
if [ -n "$vpn_active" ]; then
  tooltip+=$'\n'"VPN ativa (medicao via tunel)"
fi
if [ -n "$avg_latency" ]; then
  tooltip+=$'\n'"Latencia media: ${avg_latency} ms"
fi
if [ -n "$jitter" ]; then
  tooltip+=$'\n'"Jitter: ${jitter} ms"
fi
tooltip+=$'\n'"Perda: ${packet_loss}%"

if [ -n "$gateway_loss" ]; then
  if [ -n "$gateway_avg" ]; then
    tooltip+=$'\n'"Gateway: ${gateway_avg} ms"
  else
    tooltip+=$'\n'"Gateway: sem resposta"
  fi
fi

if [ "$ping_used_target" != "$PING_TARGET" ]; then
  tooltip+=$'\n'"Alvo ${PING_TARGET} sem resposta; medido via ${ping_used_target}"
fi

# Diagnostico: aponta onde esta o problema quando a conexao nao esta boa
if [ "$quality_class" != "good" ] && [ -n "$gateway_loss" ]; then
  gateway_ok="$(
    awk -v loss="$gateway_loss" -v avg="${gateway_avg:-999}" \
      'BEGIN { print (loss < 34 && avg < 50) ? "1" : "" }'
  )"
  if [ -n "$gateway_ok" ]; then
    tooltip+=$'\n'"Diagnostico: rede local ok, problema alem do roteador (provedor)"
  else
    tooltip+=$'\n'"Diagnostico: problema na rede local (Wi-Fi/roteador)"
  fi
fi

emit "$icon" "$tooltip" "$quality_class"
