#!/usr/bin/env bash
# Cheatsheet de atalhos do Hyprland — abre em janela Kitty flutuante

if [[ "$1" == "--display" ]]; then
  B=$'\033[1m'  R=$'\033[0m'
  C=$'\033[38;5;75m'    # azul-ciano (título/box)
  Y=$'\033[38;5;221m'   # amarelo-ouro (categorias)
  W=$'\033[97m'         # branco (teclas)
  G=$'\033[38;5;244m'   # cinza médio (descrições)
  D=$'\033[38;5;238m'   # cinza escuro (linhas)

  _h() { printf "\n  ${B}${Y}%s${R}\n  ${D}══════════════════════════════════════════════════${R}\n" "$1"; }
  _l() { printf "    ${W}%-34s${R}${G}%s${R}\n" "$1" "$2"; }

  {
    printf "\n"
    printf "  ${B}${C}╔══════════════════════════════════════════════════╗${R}\n"
    printf "  ${B}${C}║           HYPRLAND  ·  GUIA DE ATALHOS           ║${R}\n"
    printf "  ${B}${C}╚══════════════════════════════════════════════════╝${R}\n"

    _h " Aplicativos"
    _l "SUPER + Enter" "Terminal (Kitty)"
    _l "SUPER + SHIFT + Enter" "Terminal dropdown"
    _l "SUPER + D" "Launcher de aplicativos (Rofi)"
    _l "SUPER + E" "Gerenciador de arquivos"
    _l "SUPER + B" "Navegador padrão"
    _l "SUPER + S" "Pesquisa na web"
    _l "SUPER + ALT + C" "Calculadora"

    _h " Janelas"
    _l "SUPER + Q" "Fechar janela"
    _l "SUPER + SHIFT + Q" "Matar processo"
    _l "SUPER + F" "Tela cheia"
    _l "SUPER + CTRL + F" "Maximizar"
    _l "SUPER + Space" "Flutuar / ancorar"
    _l "SUPER + ← ↑ ↓ →" "Mover foco"
    _l "SUPER + SHIFT + ←↑↓→" "Redimensionar"
    _l "SUPER + CTRL + ←↑↓→" "Mover janela"

    _h " Workspaces"
    _l "SUPER + 1 – 0" "Ir para workspace 1–10"
    _l "SUPER + SHIFT + 1 – 0" "Mover janela para workspace"
    _l "SUPER + Scroll  /  , ." "Navegar entre workspaces"
    _l "SUPER + Tab / SHIFT+Tab" "Próximo / anterior"
    _l "SUPER + U" "Workspace especial (scratchpad)"

    _h " Grupos de Janelas"
    _l "SUPER + G" "Criar / desfazer grupo"
    _l "SUPER + Tab" "Próxima janela no grupo"
    _l "SUPER + SHIFT + Tab" "Janela anterior no grupo"

    _h " Sistema"
    _l "CTRL + ALT + L" "Bloquear tela (hyprlock)"
    _l "CTRL + ALT + P" "Menu de energia (wlogout)"
    _l "CTRL + ALT + Delete" "Sair do Hyprland"
    _l "SUPER + SHIFT + N" "Central de notificações"
    _l "SUPER + SHIFT + E" "Menu de configurações"
    _l "SUPER + N" "Luz noturna"

    _h " Screenshots"
    _l "SUPER + PrtSc" "Captura de tela imediata"
    _l "SUPER + SHIFT + PrtSc" "Captura de área"
    _l "SUPER + SHIFT + S" "Captura com edição (Swappy)"
    _l "ALT + PrtSc" "Captura da janela ativa"
    _l "SUPER + CTRL + PrtSc" "Captura em 5 segundos"

    _h "󱄄 Wallpaper & Tema"
    _l "SUPER + W" "Menu de wallpapers"
    _l "CTRL + ALT + W" "Wallpaper aleatório"
    _l "SUPER + SHIFT + W" "Efeitos de wallpaper"
    _l "SUPER + T" "Mudar tema global (Wallust)"
    _l "SUPER + ALT + O" "Alternar blur"

    _h " Waybar & Interface"
    _l "SUPER + CTRL + ALT + B" "Ocultar / mostrar a barra"
    _l "SUPER + CTRL + B" "Escolher estilo da barra"
    _l "SUPER + ALT + B" "Escolher layout da barra"
    _l "SUPER + ALT + R" "Recarregar barra e menus"
    _l "SUPER + H" "Esta cheatsheet"
    _l "SUPER + SHIFT + K" "Buscar todos os atalhos (Rofi)"

    printf "\n"
    printf "  ${D}══════════════════════════════════════════════════${R}\n"
    printf "  ${G}  ${W}q${G} para fechar   ${W}↑ ↓ / PgUp PgDn${G} para rolar${R}\n\n"
  } | less -R --no-init --prompt="    ↑↓ rolar  ·  q fechar"
  exit 0
fi

kitty \
  --class keybind-sheet \
  --title "Atalhos — Hyprland" \
  bash "${BASH_SOURCE[0]}" --display
