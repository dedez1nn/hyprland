#!/usr/bin/env bash
# Conta atualizações disponíveis (pacman + AUR) para a waybar

pacman_updates=$(checkupdates 2>/dev/null | wc -l)
aur_updates=$(yay -Qua 2>/dev/null | wc -l)
total=$((pacman_updates + aur_updates))

if [ "$total" -eq 0 ]; then
    echo '{"text":"󰸞","tooltip":"Sistema atualizado","class":"updated"}'
else
    echo "{\"text\":\"󰚰 $total\",\"tooltip\":\"$pacman_updates pacman  |  $aur_updates AUR\",\"class\":\"pending\"}"
fi
