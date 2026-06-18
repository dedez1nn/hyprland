# Hyprland Dotfiles

A clean, minimal Hyprland setup with a Liquid Glass-inspired Waybar, dark terminal, and automatic theming via wallust.

> Based on [JaKooLit's Hyprland-Dots](https://github.com/JaKooLit/Hyprland-Dots) — customized with personal aesthetic tweaks.

---

## Preview

> Replace with your own screenshots

| Waybar + Workspaces | Lock Screen | Keybind Cheatsheet |
|---|---|---|
| *(screenshot)* | *(screenshot)* | *(screenshot)* |

---

## Requirements

Install these packages before copying the configs. On Arch Linux:

```bash
# Core
sudo pacman -S hyprland hyprlock hypridle hyprpaper

# Waybar & notifications
sudo pacman -S waybar swaync

# Terminal & launcher
sudo pacman -S kitty rofi-wayland

# File manager & utilities
sudo pacman -S thunar wlogout

# Wallpaper daemon
# Option A — if swww is available in your repos:
sudo pacman -S swww
# Option B — AUR (awww):
yay -S awww
# If using awww, create the symlinks:
sudo ln -sf /usr/bin/awww /usr/local/bin/swww
sudo ln -sf /usr/bin/awww-daemon /usr/local/bin/swww-daemon

# Theming
yay -S wallust

# Screenshots
sudo pacman -S grim slurp swappy

# Python (for weather widget)
sudo pacman -S python python-requests

# Font — REQUIRED for icons to render
sudo pacman -S ttf-jetbrains-mono-nerd

# Optional extras
sudo pacman -S fastfetch cava bat
```

---

## Installation

> **Warning:** This will overwrite files in `~/.config`. Back up your existing configs first.

```bash
# 1. Clone
git clone https://github.com/YOUR_USERNAME/dotfiles.git ~/dotfiles

# 2. Copy configs
cp -r ~/dotfiles/.config/* ~/.config/

# 3. Copy shell config (optional)
cp ~/dotfiles/.zshrc ~/   # only if you also use oh-my-zsh + agnosterzak
```

After copying, log out and log back into Hyprland.

---

## Post-install Setup

### Wallpaper

Place your wallpaper at:

```
~/Pictures/wallpapers/wallpaper.jpg
```

The wallpaper button on Waybar (right side) lets you browse and apply wallpapers from that folder. A random one can also be applied with `CTRL + ALT + W`.

After applying a wallpaper, **wallust** automatically regenerates the color scheme for Kitty, Waybar, and other components.

### Weather Widget

The weather widget on Waybar's center bar is pre-configured for **Passos, MG, Brazil**.

To change it to your location, edit `~/.config/hypr/UserScripts/Weather.py`:

```python
MANUAL_PLACE: Optional[str] = "Your City, Your State"
MANUAL_LAT: Optional[float] = -00.0000   # your latitude
MANUAL_LON: Optional[float] = -00.0000   # your longitude
```

Find your coordinates at [latlong.net](https://www.latlong.net/) or via `curl ipinfo.io`.

---

## Keybinds

Press `SUPER + H` or click the `󰌌` button on Waybar to open the full interactive cheatsheet.

**Most important shortcuts:**

| Key | Action |
|-----|--------|
| `SUPER + Enter` | Terminal (Kitty) |
| `SUPER + D` | App launcher (Rofi) |
| `SUPER + Q` | Close window |
| `SUPER + W` | Wallpaper menu |
| `SUPER + T` | Change theme (wallust) |
| `SUPER + H` | Keybind cheatsheet |
| `SUPER + SHIFT + K` | Search all keybinds |
| `CTRL + ALT + L` | Lock screen |
| `CTRL + ALT + P` | Power menu |
| `SUPER + 1–0` | Switch workspace |

---

## Customization

| File | What it controls |
|------|-----------------|
| `~/.config/hypr/UserConfigs/01-UserDefaults.conf` | Default terminal, file manager, editor |
| `~/.config/hypr/UserConfigs/UserKeybinds.conf` | Your personal keybindings |
| `~/.config/hypr/UserConfigs/UserSettings.conf` | Gaps, borders, animations toggle |
| `~/.config/hypr/UserConfigs/UserDecorations.conf` | Window rounding, shadows, blur |
| `~/.config/hypr/UserScripts/Weather.py` | Weather location |
| `~/.config/kitty/kitty.conf` | Terminal colors and font |
| `~/.config/waybar/UserModules` | Add your own Waybar modules |
| `~/.config/waybar/style/[Extra] Liquid Glass.css` | Waybar visual style |

### Changing the Waybar layout

Press `SUPER + CTRL + B` to pick a Waybar style from a menu, or `SUPER + ALT + B` to switch the module layout.

### Adjusting terminal colors

The color scheme is generated from your wallpaper by **wallust** (stored in `~/.config/kitty/kitty-themes/01-Wallust.conf`). You can override any color in `~/.config/kitty/kitty.conf` — see the comments there for which ANSI slot maps to which prompt segment.

---

## Structure

```
.config/
├── hypr/
│   ├── hyprland.conf          # Main Hyprland config
│   ├── hyprlock.conf          # Lock screen
│   ├── hypridle.conf          # Idle/sleep behavior
│   ├── configs/               # Keybinds, window rules, startup apps
│   ├── UserConfigs/           # ← Edit these to personalize
│   ├── UserScripts/           # Custom scripts (weather, wallpaper, etc.)
│   └── scripts/               # Core scripts (do not edit)
├── waybar/
│   ├── configs/               # Bar layouts
│   ├── style/                 # CSS themes
│   └── UserModules            # ← Add your own modules here
├── kitty/                     # Terminal config
├── rofi/                      # Launcher themes
├── swaync/                    # Notification center
└── wallust/                   # Color scheme templates
```

---

## Credits

- [JaKooLit](https://github.com/JaKooLit) — base Hyprland-Dots config
- [Hyprland](https://hyprland.org/) — the compositor
- [wallust](https://codeberg.org/explosion-mental/wallust) — automatic color theming
