#!/usr/bin/env bash
# Mede ping/download/upload contra os endpoints públicos do Cloudflare
# speed test (speed.cloudflare.com) — os mesmos que o site oficial usa.
# Sem servidor próprio: sai de verdade pela sua rede até a internet, em vez
# de medir loopback. Chamado por SpeedTestService.qml a cada clique em
# "Testar agora", imprime o resultado em JSON numa linha só.
#
# Sem "set -e": cada curl tem --max-time próprio (rede móvel/instável pode
# travar uma requisição por tempo indefinido sem isso) e falha é tratada
# explicitamente com `fail`, que sempre imprime um JSON válido — sem isso,
# um curl travado ou abortado no meio deixava o script morrer sem
# imprimir nada, e o widget mostrava os números zerados em vez de erro.
set -uo pipefail

BASE="https://speed.cloudflare.com"

fail() {
    printf '{"error": true}\n'
    exit 1
}

# ping: 3 amostras contra o endpoint de trace (payload mínimo, só pra medir RTT)
total=0
for _ in 1 2 3; do
    t=$(curl -s --max-time 5 -o /dev/null -w "%{time_total}" "$BASE/cdn-cgi/trace") || fail
    total=$(awk "BEGIN {print $total + $t}")
done
ping_ms=$(awk "BEGIN {print ($total/3)*1000}")

# download: 8MB (pequeno o bastante pra não estourar o timeout numa rede lenta)
down_stats=$(curl -s --max-time 30 -o /dev/null -w "%{time_total} %{size_download}" "$BASE/__down?bytes=8000000") || fail
down_time=$(cut -d' ' -f1 <<< "$down_stats")
down_bytes=$(cut -d' ' -f2 <<< "$down_stats")
down_mbps=$(awk "BEGIN {print ($down_bytes*8)/($down_time*1000000)}")

# upload: 3MB aleatórios
tmpfile=$(mktemp)
head -c 3000000 /dev/urandom > "$tmpfile"
up_stats=$(curl -s --max-time 30 -o /dev/null -w "%{time_total} %{size_upload}" -X POST --data-binary "@$tmpfile" "$BASE/__up")
up_status=$?
rm -f "$tmpfile"
[ "$up_status" -eq 0 ] || fail
up_time=$(cut -d' ' -f1 <<< "$up_stats")
up_bytes=$(cut -d' ' -f2 <<< "$up_stats")
up_mbps=$(awk "BEGIN {print ($up_bytes*8)/($up_time*1000000)}")

printf '{"pingMs": %s, "downloadMbps": %s, "uploadMbps": %s}\n' "$ping_ms" "$down_mbps" "$up_mbps"
