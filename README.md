# Hyprland Liquid Glass Dotfiles

Setup pessoal do Hyprland com estética Liquid Glass, Waybar customizada, temas automáticos via wallust e módulos próprios (apolo, ProtonVPN, qualidade de conexão).

> Baseado em [JaKooLit/Hyprland-Dots](https://github.com/JaKooLit/Hyprland-Dots) com customizações visuais e de workflow.

---

## Preview

| Waybar + Workspaces | Lock Screen |
|---|---|
| *(screenshot)* | *(screenshot)* |

---

## Qual é o seu caso?

Escolha o caminho de instalação:

- **[Já uso o JaKooLit Hyprland-Dots](#caso-a--já-uso-o-jakoolit-hyprland-dots)** — o mais rápido, sobrescreve só os arquivos customizados
- **[Hyprland limpo / outra base](#caso-b--hyprland-limpo-ou-outra-base)** — instala tudo do zero com o `install.sh`

---

## Caso A — Já uso o JaKooLit Hyprland-Dots

Se você já tem o setup do JaKooLit rodando, você só precisa sobrescrever os arquivos que foram customizados aqui. Sem instalar dependências extras.

```bash
git clone git@github.com:dedez1nn/hyprland.git ~/repos/hyprland
cd ~/repos/hyprland
```

> O caminho `~/repos/hyprland` não é só convenção: o serviço systemd do
> `quickshell-dashboard` (`.config/systemd/user/quickshell-dashboard.service`)
> aponta pra `%h/repos/hyprland/quickshell-dashboard` de forma fixa. Clonando
> em outro lugar, ajuste o `ExecStart` desse arquivo.

### 1. Waybar — layout e estilo

```bash
# Layout ativo
cp ".config/waybar/configs/[TOP] Andre Liquid Glass" \
   ~/.config/waybar/configs/

# Estilo Liquid Glass
cp ".config/waybar/style/[Extra] Liquid Glass.css" \
   ~/.config/waybar/style/

# Módulos customizados (apolo, ProtonVPN, keybinds, connection quality)
cp .config/waybar/UserModules ~/.config/waybar/UserModules

# Scripts da Waybar
cp .config/waybar/apolo-review.sh \
   .config/waybar/protonvpn-status.sh \
   .config/waybar/protonvpn-toggle.sh \
   .config/waybar/connection-quality.sh \
   .config/waybar/bluetooth-toggle.sh \
   ~/.config/waybar/
chmod +x ~/.config/waybar/*.sh

# Imagem do módulo apolo
cp .config/waybar/apolo.png ~/.config/waybar/

# Apontar o symlink de estilo para o Liquid Glass
ln -sfn ~/.config/waybar/style/[Extra]\ Liquid\ Glass.css ~/.config/waybar/style.css
ln -sfn ~/.config/waybar/configs/[TOP]\ Andre\ Liquid\ Glass ~/.config/waybar/config
```

### 2. Hypr — configs de usuário

```bash
cp -r .config/hypr/UserConfigs/. ~/.config/hypr/UserConfigs/
cp -r .config/hypr/UserScripts/. ~/.config/hypr/UserScripts/
cp .config/hypr/hyprlock.conf ~/.config/hypr/hyprlock.conf
cp .config/hypr/hypridle.conf ~/.config/hypr/hypridle.conf
```

### 3. Corrigir paths (substitui HOME_PLACEHOLDER pelo seu $HOME)

```bash
sed -i "s|HOME_PLACEHOLDER|$HOME|g" ~/.config/hypr/hyprlock.conf
sed -i "s|HOME_PLACEHOLDER|$HOME|g" ~/.config/waybar/style/[Extra]\ Liquid\ Glass.css
```

### 4. Wallpapers

```bash
mkdir -p ~/Imagens/wallpapers
cp wallpapers/*.jpg ~/Imagens/wallpapers/
```

Depois defina o wallpaper padrão editando `~/.config/hypr/hyprpaper.conf`.

### 5. Terminal, notificações, logout

Copie só o que quiser substituir:

```bash
# Kitty
cp -r .config/kitty/. ~/.config/kitty/

# Ghostty
cp .config/ghostty/config ~/.config/ghostty/config

# Swaync (notificações)
cp -r .config/swaync/. ~/.config/swaync/

# Wlogout (menu de saída)
cp -r .config/wlogout/. ~/.config/wlogout/

# btop
cp .config/btop/btop.conf ~/.config/btop/btop.conf

# Theming Qt (qt5ct/qt6ct)
cp -r .config/qt5ct/. ~/.config/qt5ct/
cp -r .config/qt6ct/. ~/.config/qt6ct/

# Thunar (atalhos e ações customizadas)
cp -r .config/Thunar/. ~/.config/Thunar/

# Wezterm (terminal alternativo)
cp .config/wezterm/wezterm.lua ~/.config/wezterm/wezterm.lua

# Apps de autostart (keyring, Proton Mail Bridge, boas-vindas do CachyOS)
cp -r .config/autostart/. ~/.config/autostart/

# Aplicativos padrão do sistema
cp .config/mimeapps.list ~/.config/mimeapps.list

# Módulo overview do Quickshell + tema Material
cp -r .config/quickshell/. ~/.config/quickshell/

# Serviços de usuário do systemd (autostart do quickshell-dashboard)
cp -r .config/systemd/. ~/.config/systemd/
systemctl --user daemon-reload
```

Reinicie a Waybar: `pkill waybar && waybar &`

---

## Caso B — Hyprland limpo ou outra base

### 1. Dependências

```bash
# Core Hyprland
sudo pacman -S hyprland hyprlock hypridle hyprpaper

# Waybar e notificações
sudo pacman -S waybar swaync

# Terminal, launcher, gerenciador de arquivos
sudo pacman -S kitty ghostty rofi-wayland thunar

# Menu de saída e barra de sessão
sudo pacman -S wlogout nwg-bar

# Quickshell (overview de janelas + quickshell-dashboard)
yay -S quickshell-git

# Theming Qt, agente polkit, applets de bandeja
sudo pacman -S qt5ct qt6ct hyprpolkitagent network-manager-applet blueman

# playerctl (mini player MPRIS do quickshell-dashboard)
sudo pacman -S playerctl

# Wallpaper daemon
# Opção A — pacman:
sudo pacman -S swww
# Opção B — AUR (awww, substituto do swww):
yay -S awww
sudo ln -sf /usr/bin/awww /usr/local/bin/swww
sudo ln -sf /usr/bin/awww-daemon /usr/local/bin/swww-daemon

# Theming automático
yay -S wallust

# Screenshots
sudo pacman -S grim slurp swappy

# Python (widget de clima)
sudo pacman -S python python-requests

# Fontes — obrigatório para os ícones
sudo pacman -S ttf-jetbrains-mono-nerd ttf-fantasque-nerd

# Extras opcionais
sudo pacman -S fastfetch cava bat lsd fzf
```

### 2. Instalar

```bash
git clone https://github.com/YOUR_USERNAME/dotfiles.git ~/dotfiles
cd ~/dotfiles
bash install.sh
```

O script faz backup dos configs existentes, copia tudo, corrige os paths e cria os symlinks necessários.

### 3. Shell (opcional)

O `.zshrc` usa **oh-my-zsh** com o tema `agnosterzak`. Para instalar:

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Plugins
git clone https://github.com/zsh-users/zsh-autosuggestions \
  ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting \
  ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting

# Tema agnosterzak
curl -o ~/.oh-my-zsh/custom/themes/agnosterzak.zsh-theme \
  https://raw.githubusercontent.com/zakaziko99/agnosterzak-ohmyzsh-theme/master/agnosterzak.zsh-theme
```

---

## Configuração pós-instalação

### Widget de clima

O widget está configurado para **Passos, MG**. Para mudar:

```python
# ~/.config/hypr/UserScripts/Weather.py
MANUAL_PLACE: Optional[str] = "Sua Cidade, Seu Estado"
MANUAL_LAT: Optional[float] = -00.0000
MANUAL_LON: Optional[float] = -00.0000
```

Coordenadas: `curl ipinfo.io` ou [latlong.net](https://www.latlong.net/).

### Wallpaper padrão

Os wallpapers ficam em `~/Imagens/wallpapers/`. Para mudar o padrão edite `~/.config/hypr/hyprpaper.conf` e `~/.config/hypr/hyprlock.conf` (o caminho do fundo da tela de lock).

Pela Waybar você pode trocar com `SUPER + W` (menu) ou clique direito no botão de wallpaper para um aleatório.

### Módulo apolo

O ícone  na Waybar abre a TUI de revisão de emails do projeto [proton-api](../proton-api). Ele espera que o projeto esteja em `~/proton-api` com um venv em `.venv/`. Se não usar, remova `"custom/apolo"` do arquivo `~/.config/waybar/configs/[TOP] Andre Liquid Glass`.

### ProtonVPN

O widget detecta o estado da VPN via `protonvpn status`. Requer o [ProtonVPN CLI](https://protonvpn.com/support/linux-vpn-tool/) instalado e autenticado (`protonvpn signin`).

### Quickshell Dashboard

Widgets extras (boas-vindas, calendário, clima, mini player, notas do Notion)
que aparecem quando o workspace focado está vazio. Roda como serviço systemd
apontando direto pro caminho do repo — **precisa que o repo esteja em
`~/repos/hyprland`** (ver nota na seção de clone acima). Configuração de
segredos (token Notion, link `.ics` do Proton Calendar) e detalhes completos
estão no [README próprio](quickshell-dashboard/README.md).

```bash
cp quickshell-dashboard/config/secrets.example.json quickshell-dashboard/config/secrets.json
# edite secrets.json com seus valores
systemctl --user daemon-reload
systemctl --user restart quickshell-dashboard.service
```

### SDDM (tela de login)

`etc/sddm.conf` configura autologin e o tema `simple_sddm_2`. Não é copiado
pelo `install.sh` (exige `sudo` e mexe fora de `$HOME`) — copie manualmente
se usar SDDM:

```bash
sudo cp etc/sddm.conf /etc/sddm.conf
```

Ajuste `[Autologin] User=` para o seu usuário antes de copiar.

### Problemas conhecidos

A pasta [`troubleshooting/`](troubleshooting/) tem notas de incidentes já
resolvidos neste setup (Proton Bridge não abre, migração de keyring,
loop no `protonvpn signin`) — vale conferir antes de investigar do zero.

---

## Atalhos principais

| Tecla | Ação |
|-------|------|
| `SUPER + Enter` | Terminal (Kitty) |
| `SUPER + D` | Launcher (Rofi) |
| `SUPER + Q` | Fechar janela |
| `SUPER + W` | Menu de wallpaper |
| `SUPER + C` | VS Code |
| `SUPER + H` | Dicas rápidas |
| `SUPER + SHIFT + K` | Buscar todos os atalhos |
| `SUPER + CTRL + B` | Mudar estilo da Waybar |
| `SUPER + ALT + B` | Mudar layout da Waybar |
| `CTRL + ALT + L` | Bloquear tela |
| `CTRL + ALT + P` | Menu de energia |
| `SUPER + 1–0` | Mudar workspace |

---

## O que é customizado aqui vs JaKooLit original

| Arquivo | O que foi alterado |
|---------|-------------------|
| `waybar/configs/[TOP] Andre Liquid Glass` | Layout próprio com módulos apolo, ProtonVPN, connection quality |
| `waybar/style/[Extra] Liquid Glass.css` | Estilo Liquid Glass (inspirado no iOS 26 / macOS Tahoe) |
| `waybar/UserModules` | Módulos apolo, protonvpn, connection_quality, keybinds |
| `waybar/*.sh` | Scripts próprios para ProtonVPN, bluetooth, qualidade de conexão |
| `hypr/UserConfigs/UserDecorations.conf` | Blur, sombras, bordas com cores do wallust |
| `hypr/UserConfigs/UserAnimations.conf` | Animações de janela e workspace |
| `hypr/UserConfigs/UserKeybinds.conf` | Atalho SUPER+C para VS Code |
| `hypr/UserScripts/Weather.py` | Widget de clima via Open-Meteo (sem API key) |
| `hypr/UserScripts/CheckUpdates.sh` | Conta updates do pacman + AUR |
| `hypr/hyprlock.conf` | Tela de lock com hora grande, clima e bateria |
| `kitty/kitty.conf` | Cores mapeadas para o tema agnosterzak |
| `ghostty/config` | Terminal alternativo com blur e FantasqueSansM |

---

## Estrutura

```
hyprland/                       ← clonar em ~/repos/hyprland (ver nota acima)
├── install.sh                  ← instalador principal
├── wallpapers/                 ← fundos de tela
├── .zshrc                      ← config do zsh
├── etc/
│   └── sddm.conf                ← tela de login (copiar manualmente, precisa sudo)
├── troubleshooting/             ← notas de incidentes já resolvidos (Proton Bridge, keyring, VPN)
├── quickshell-dashboard/        ← widgets de área de trabalho vazia (README próprio)
└── .config/
    ├── hypr/
    │   ├── hyprland.conf
    │   ├── hyprlock.conf
    │   ├── hypridle.conf
    │   ├── hyprpaper.conf
    │   ├── UserConfigs/        ← edite aqui para personalizar
    │   └── UserScripts/        ← scripts customizados
    ├── waybar/
    │   ├── configs/            ← layouts disponíveis
    │   ├── style/              ← temas CSS
    │   ├── UserModules         ← módulos próprios
    │   └── *.sh                ← scripts dos módulos
    ├── quickshell/              ← overview de janelas (qs -c overview)
    ├── kitty/
    ├── ghostty/
    ├── wezterm/
    ├── rofi/
    ├── swaync/
    ├── wlogout/
    ├── nwg-bar/
    ├── btop/
    ├── fastfetch/
    ├── cava/
    ├── fish/
    ├── qt5ct/ qt6ct/           ← theming de apps Qt
    ├── Thunar/
    ├── autostart/               ← keyring, Proton Mail Bridge etc
    ├── systemd/user/            ← serviço do quickshell-dashboard, rclone (pessoal)
    ├── git/                     ← gitignore global
    ├── swappy/
    ├── mimeapps.list
    └── wallust/
```

---

## Créditos

- [JaKooLit](https://github.com/JaKooLit) — base dos dotfiles Hyprland
- [Hyprland](https://hyprland.org/) — compositor Wayland
- [wallust](https://codeberg.org/explosion-mental/wallust) — geração automática de cores a partir do wallpaper
