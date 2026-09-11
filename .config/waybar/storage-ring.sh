#!/usr/bin/env bash
# Gera um icone de armazenamento com um anel de progresso ao redor,
# preenchido conforme o espaco em disco usado. Pensado para o modulo
# "image" da Waybar (chave "exec"), que espera o caminho do PNG no stdout.

set -u

DISK_PATH="${STORAGE_RING_PATH:-/home}"
ICON="$HOME/.config/waybar/storage-icon.png"
CACHE_DIR="$HOME/.cache/waybar"
OUT="$CACHE_DIR/storage-ring.png"

SIZE=22
CENTER=11
RADIUS=9
STROKE=2
ICON_SIZE=12

mkdir -p "$CACHE_DIR"

pct="$(df --output=pcent "$DISK_PATH" 2>/dev/null | tail -n 1 | tr -dc '0-9')"
[ -z "$pct" ] && pct=0
[ "$pct" -gt 100 ] && pct=100

# Verde -> amarelo -> vermelho conforme o disco enche
if [ "$pct" -ge 90 ]; then
    color="#ff8080"
elif [ "$pct" -ge 70 ]; then
    color="#ffd479"
else
    color="#7fffa0"
fi

icon_small="$CACHE_DIR/storage-icon-small-${ICON_SIZE}.png"
[ -f "$icon_small" ] || magick "$ICON" -resize "${ICON_SIZE}x${ICON_SIZE}" "$icon_small"

ring="$CACHE_DIR/storage-ring-arc.png"

if [ "$pct" -ge 100 ]; then
    # arco de 360 graus nao desenha nada no ImageMagick; usa circulo cheio
    magick -size "${SIZE}x${SIZE}" xc:none \
        -strokewidth "$STROKE" -fill none -stroke "$color" \
        -draw "circle $CENTER,$CENTER $CENTER,$((CENTER - RADIUS))" \
        "$ring"
else
    end_angle="$(awk -v p="$pct" 'BEGIN { printf "%.2f", -90 + 3.6 * p }')"
    magick -size "${SIZE}x${SIZE}" xc:none \
        -strokewidth "$STROKE" -fill none -stroke "#ffffff40" \
        -draw "circle $CENTER,$CENTER $CENTER,$((CENTER - RADIUS))" \
        -stroke "$color" \
        -draw "arc 1.5,1.5 $((SIZE - 2)).5,$((SIZE - 2)).5 -90,$end_angle" \
        "$ring"
fi

magick "$ring" "$icon_small" -gravity center -compose over -composite "$OUT"

echo "$OUT"
