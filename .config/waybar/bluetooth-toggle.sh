#!/usr/bin/env bash

set -u

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/waybar"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}"
PREFERRED_FILE="$CONFIG_DIR/bluetooth-preferred-devices"
CACHE_FILE="$CACHE_DIR/waybar-bluetooth-last-device"

notify() {
  if command -v notify-send >/dev/null 2>&1; then
    notify-send -a "waybar-bluetooth" "$1" "${2:-}"
  fi
}

btctl() {
  bluetoothctl --timeout 5 "$@" 2>/dev/null
}

device_name() {
  btctl info "$1" | sed -n 's/^[[:space:]]*Name: //p' | head -n 1
}

is_connected() {
  btctl info "$1" | grep -q "Connected: yes"
}

is_trusted() {
  btctl info "$1" | grep -q "Trusted: yes"
}

ensure_adapter_on() {
  local powered

  powered="$(btctl show | sed -n 's/^[[:space:]]*Powered: //p' | head -n 1)"
  if [ "$powered" = "yes" ]; then
    return 0
  fi

  if btctl power on >/dev/null; then
    return 0
  fi

  notify "Bluetooth" "Nao foi possivel ligar o adaptador."
  exit 1
}

disconnect_first_connected() {
  local mac name

  while read -r mac; do
    [ -n "$mac" ] || continue
    name="$(device_name "$mac")"
    if btctl disconnect "$mac" >/dev/null && ! is_connected "$mac"; then
      mkdir -p "$CACHE_DIR"
      printf '%s\n' "$mac" > "$CACHE_FILE"
      notify "Bluetooth" "Desconectado de ${name:-$mac}."
      exit 0
    fi
  done < <(btctl devices Connected | awk '{print $2}')
}

emit_candidate() {
  local mac="$1"

  [ -n "$mac" ] || return 0
  case "$mac" in
    \#*) return 0 ;;
  esac
  printf '%s\n' "$mac"
}

candidate_devices() {
  local mac

  if [ -f "$PREFERRED_FILE" ]; then
    while read -r mac; do
      emit_candidate "$mac"
    done < "$PREFERRED_FILE"
  fi

  if [ -f "$CACHE_FILE" ]; then
    while read -r mac; do
      emit_candidate "$mac"
    done < "$CACHE_FILE"
  fi

  while read -r mac; do
    [ -n "$mac" ] || continue
    if is_trusted "$mac"; then
      emit_candidate "$mac"
    fi
  done < <(btctl devices Paired | awk '{print $2}')

  btctl devices Paired | awk '{print $2}'
}

connect_device() {
  local mac="$1"
  local name output

  name="$(device_name "$mac")"
  output="$(btctl connect "$mac")"

  if is_connected "$mac"; then
    mkdir -p "$CACHE_DIR"
    printf '%s\n' "$mac" > "$CACHE_FILE"
    notify "Bluetooth" "Conectado a ${name:-$mac}."
    return 0
  fi

  if printf '%s\n' "$output" | grep -qi "successful"; then
    mkdir -p "$CACHE_DIR"
    printf '%s\n' "$mac" > "$CACHE_FILE"
    notify "Bluetooth" "Conectado a ${name:-$mac}."
    return 0
  fi

  return 1
}

main() {
  local mac
  local any_candidate=0

  ensure_adapter_on
  disconnect_first_connected

  while read -r mac; do
    [ -n "$mac" ] || continue
    any_candidate=1
    if connect_device "$mac"; then
      exit 0
    fi
  done < <(candidate_devices | awk '!seen[$0]++')

  if [ "$any_candidate" -eq 0 ]; then
    notify "Bluetooth" "Nenhum dispositivo pareado encontrado."
  else
    notify "Bluetooth" "Falha ao conectar aos dispositivos conhecidos."
  fi

  exit 1
}

main "$@"
