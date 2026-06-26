#!/usr/bin/env bash
# Lançador da TUI de revisão do apolo — chamado pelo botão da Waybar (kitty -e).
cd "$HOME/proton-api" || { echo "pasta ~/proton-api não encontrada"; read -rn1; exit 1; }
# A UI usa Textual, que vive no venv do projeto; o python do sistema não o tem.
PY="$HOME/proton-api/.venv/bin/python"
[ -x "$PY" ] || PY="python"   # fallback se o venv ainda não existir
"$PY" -m apolo.cli review
rc=$?
if [ "$rc" -ne 0 ]; then
    echo
    read -rn1 -p "apolo saiu com erro ($rc). Pressione qualquer tecla para fechar..."
fi
