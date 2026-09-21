# Fedora Sway Gruvbox dotfiles

This repository recreates the current Fedora Sway setup: a restrained Gruvbox palette, a 30 px Waybar on the BenQ display, Alacritty, tmux, native Oh My Zsh prompt, SwayNC, Breeze cursors and the matching lock screen.

Firefox is deliberately not configured or themed.

## Install on Fedora

From a fresh Fedora installation:

```bash
sudo dnf install -y git
git clone https://github.com/fakelozic/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

The script is safe to run again. Before writing configuration, it copies existing targets to:

```text
~/.local/state/dotfiles-backups/YYYYMMDD-HHMMSS/
```

It installs the Fedora packages used by the configuration, including `ripgrep`, `eza`, `bat`, Sway, Waybar, Alacritty, tmux, Neovim, SwayNC, Breeze cursors and screenshot/clipboard utilities. It also installs JetBrainsMono Nerd Font and Oh My Zsh. Starship is not installed or activated because the Gruvbox Oh My Zsh theme provides the prompt directly; `starship.toml` remains in the repository as an optional configuration.

Useful installer options:

```bash
./install.sh --files-only
./install.sh --skip-nvidia
./install.sh --skip-shell-change
./install.sh --skip-reload
```

## NVIDIA and Secure Boot

The normal install detects NVIDIA hardware. When present, it enables RPM Fusion, installs the open-compatible Fedora NVIDIA akmod packages, builds the module and installs `sway/environment`. On other hardware, the NVIDIA environment file is skipped.

With Secure Boot enabled, the akmods certificate may need to be enrolled once before the driver can load:

```bash
sudo kmodgenca -a
sudo mokutil --import /etc/pki/akmods/certs/public_key.der
```

Choose a one-time password, reboot, select **Enroll MOK**, and enter that password. Then allow the akmod build to finish before rebooting again:

```bash
sudo akmods --force
modinfo -F version nvidia
```

## Machine-specific display layout

This setup mirrors the current two-monitor machine:

- `HDMI-A-1` is the main BenQ display and is the only display with Waybar.
- `HDMI-A-2` is placed to its left.
- Workspaces 1–8 open on the BenQ; 9–10 open on the second display.

If connector names differ, inspect them with `swaymsg -t get_outputs` and update `sway/config`, `waybar/config.jsonc`, and `swaync/config.json`.

## Key details

- Sway: 1 px subtle active border, 8 px inner and 2 px outer gaps.
- Calculator: opens floating.
- Waybar: bottom, 30 px, seconds visible, square workspace indicators.
- Swaylock: uses `walls/burning-earth.png`.
- tmux prefix: `Ctrl+Space`; the session chip changes from yellow to purple while the prefix is active.
- Special Sway mode: `Super+Z`, then `c` copies a picked color, `s` copies a selected screenshot, and `a` saves an output screenshot.
- Shell tools: `ls`/`ll`/`la`/`lt` use `eza`, `cat` uses `bat`, and `rgf` lists files with `ripgrep`.

The original `sve`, `tux`, `chaos`, and `orbit` wallpapers were removed. `wall.png`, `wallg.png`, and `burning-earth.png` remain.
