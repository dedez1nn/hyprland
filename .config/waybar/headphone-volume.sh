#!/usr/bin/env bash
# Waybar custom module: mostra o volume só quando o sink padrão é um fone (headset/bluetooth)
# --check : só retorna exit code (usado em "exec-if")

get_default_sink() { timeout 2 pactl get-default-sink 2>/dev/null; }

sink_is_headphone() {
	local sink="$1"
	[[ -z "$sink" ]] && return 1
	timeout 2 pactl -f json list sinks 2>/dev/null | jq -e --arg name "$sink" '
		.[] | select(.name == $name) |
		((.properties["device.form_factor"] // "") | test("headset|headphone")) or
		(.properties["device.bus"] == "bluetooth")
	' >/dev/null 2>&1
}

# Nivel real do audio (dBFS) capturado no monitor do sink, nao e o dB de volume/ganho.
# dBFS = 0 e o teto digital (clipping); silencio digital puro nao produz "RMS level dB" (sem amostras acima do ruido)
get_dbfs() {
	local sink="$1"
	local out db
	out=$(timeout 1 ffmpeg -nostats -hide_banner -f pulse -i "${sink}.monitor" -t 0.3 -af astats=metadata=0 -f null - 2>&1)
	db=$(printf '%s\n' "$out" | grep "RMS level dB" | tail -n1 | grep -oE '\-?[0-9]+\.[0-9]+')
	[[ -z "$db" ]] && { printf -- '-inf'; return; }
	LC_NUMERIC=C printf '%.2f' "$db"
}

# Suaviza o dBFS com media movel das ultimas leituras validas: a janela de
# 0.3s do ffmpeg capta pontos bem diferentes da dinamica da musica (testado:
# ~7dB de oscilacao entre leituras de 0.3s da mesma faixa), entao mostrar o
# valor cru faz o dB estimado "piscar" sem o volume real ter mudado.
DBFS_HISTORY_FILE="${XDG_RUNTIME_DIR:-/tmp}/waybar-headphone-dbfs-history"
DBFS_HISTORY_WINDOW=3
DBFS_HISTORY_MAX_AGE=8

smooth_dbfs() {
	local dbfs="$1" now
	now="$(date +%s)"
	printf '%s %s\n' "$now" "$dbfs" >> "$DBFS_HISTORY_FILE"

	# So considera leituras dentro da janela de idade (maxage). Isso já isola
	# qualquer leitura de antes de uma suspensao/boot/reconexao do bluetooth
	# (o "now" da leitura atual fica bem distante do timestamp salvo antes do
	# gap, entao a linha antiga e descartada em vez de entrar na media).
	#
	# Usa mediana em vez de media: um pico isolado (pop/estatica do fone/BT
	# reconectando) nao arrasta o valor exibido, so um valor consistente em
	# pelo menos 2 leituras consecutivas conta.
	awk -v now="$now" -v maxage="$DBFS_HISTORY_MAX_AGE" -v window="$DBFS_HISTORY_WINDOW" \
		-v tmp="${DBFS_HISTORY_FILE}.tmp" '
		{ if (now - $1 <= maxage) { n++; ts[n] = $1; val[n] = $2 } }
		END {
			start = (n > window) ? n - window + 1 : 1
			count = 0
			for (i = start; i <= n; i++) {
				count++; arr[count] = val[i]
				print ts[i], val[i] > tmp
			}
			if (count < 2) exit 1
			for (i = 2; i <= count; i++) {
				key = arr[i]; j = i - 1
				while (j >= 1 && arr[j] > key) { arr[j + 1] = arr[j]; j-- }
				arr[j + 1] = key
			}
			if (count % 2 == 1) { median = arr[(count + 1) / 2] }
			else { median = (arr[count / 2] + arr[count / 2 + 1]) / 2 }
			printf "%.2f", median
		}
	' "$DBFS_HISTORY_FILE"
	mv -f "${DBFS_HISTORY_FILE}.tmp" "$DBFS_HISTORY_FILE" 2>/dev/null
}

# Estimativa (nao medicao) de dB SPL real no ouvido, calibrada com dados publicos do QCY T1C:
# - PipeWire/Pulse usa curva cubica de volume -> ganho(dB) = 60*log10(volume/100), confirmado batendo
#   com o "-8,97 dB" que o pactl reporta pra 71% de volume.
# - REF_SPL_MAX_0DBFS e o teto teorico do driver a 100% de volume tocando um sinal de 0 dBFS.
#   Fontes: fones desse tipo "passam de 100 dB SPL" no volume maximo tocando musica normal
#   (nao 0 dBFS), e musica bem masterizada fica em torno de -15 a -20 dBFS de RMS -> teto em
#   0 dBFS fica perto de 118-120 dB SPL. E aproximacao heuristica, nao calibracao de laboratorio.
REF_SPL_MAX_0DBFS=118

estimate_spl() {
	local volume="$1" dbfs="$2"
	awk -v vol="$volume" -v dbfs="$dbfs" -v ref="$REF_SPL_MAX_0DBFS" 'BEGIN {
		if (vol <= 0) { print "-inf"; exit }
		gain = 60 * log(vol / 100) / log(10)
		printf "%.0f", ref + gain + dbfs
	}'
}

sink="$(get_default_sink)"

if [[ "$1" == "--check" ]]; then
	sink_is_headphone "$sink"
	exit $?
fi

if ! sink_is_headphone "$sink"; then
	exit 1
fi

muted="$(timeout 2 pamixer --get-mute 2>/dev/null)"
volume="$(timeout 2 pamixer --get-volume 2>/dev/null)"
desc="$(timeout 2 pactl -f json list sinks 2>/dev/null | jq -r --arg name "$sink" '.[] | select(.name==$name) | .description')"

# Se pamixer travou/falhou (ex: pipewire-pulse ainda subindo apos resume),
# nao segue com $volume vazio - a comparacao numerica abaixo quebraria o modulo.
[[ -z "$volume" ]] && exit 1

if [[ "$muted" == "true" ]]; then
	text="󰖁 Mudo"
	tooltip="${desc} · mudo"
	class="muted"
else
	dbfs_raw="$(get_dbfs "$sink")"
	if (( volume <= 30 )); then
		icon="󰕿"
	elif (( volume <= 70 )); then
		icon="󰖀"
	else
		icon="󰕾"
	fi
	if [[ "$dbfs_raw" == "-inf" ]]; then
		text=" ${icon} ${volume}%"
		tooltip="${desc} · volume ${volume}% · sem audio tocando"
		class="active"
	else
		dbfs="$(smooth_dbfs "$dbfs_raw")"
		if [[ -z "$dbfs" ]]; then
			# ainda nao ha 2 leituras validas dentro da janela (acabou de sair de
			# suspensao, boot, ou o bluetooth acabou de reconectar) - evita exibir
			# um pico isolado e espurio como se fosse o dB real
			text=" ${icon} ${volume}%"
			tooltip="${desc} · volume ${volume}% · calibrando leitura de dB..."
			class="active"
		else
			spl="$(estimate_spl "$volume" "$dbfs")"
			dbfs_display="$(LC_NUMERIC=C printf '%.0f' "$dbfs")"
			text=" ${icon} ${volume}% · ~${spl} dB"
			tooltip="${desc} · volume ${volume}% · sinal: ${dbfs_display} dBFS (mediana) · SPL estimado: ~${spl} dB (aproximacao heuristica, nao e medicao real)"
			if (( spl >= 85 )); then
				class="loud"
			else
				class="active"
			fi
		fi
	fi
fi

jq -nc --arg text "$text" --arg tooltip "$tooltip" --arg class "$class" \
	'{text: $text, tooltip: $tooltip, class: $class}'
