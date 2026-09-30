# Fedora Sway Gruvbox dotfiles

This repository recreates the current Fedora Sway setup: a restrained Gruvbox palette, a 26 px Waybar on the BenQ display, Alacritty, Neovim, minimal Vim, tmux, native Oh My Zsh prompt, SwayNC, Breeze cursors and the matching lock screen.

![Sway Gruvbox desktop with minimal Vim and the Rofi power menu](assets/desktop.png)

Current desktop preview using a public Lua example in Vim and the power menu in preview mode.

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
~/.local/state/dotfiles-backups/YYYYMMDD-HHMMSS-XXXXXX/
```

Each run gets a unique backup directory. Existing wallpaper files are backed up alongside the configuration.

It installs the Fedora packages used by the configuration, including `ripgrep`, `eza`, `bat`, Sway, Waybar, Alacritty, tmux, Neovim, Vim, SwayNC, Breeze cursors and screenshot/clipboard utilities. It also installs JetBrainsMono Nerd Font and Oh My Zsh. The installer also installs the C compiler, `make`, `unzip`, `tree-sitter-cli`, Node.js and npm needed by the editor setup. It checks for Neovim 0.12.0 or later and `tree-sitter-cli` 0.26.1 or later before replacing configuration. Starship is not installed or activated because the Gruvbox Oh My Zsh theme provides the prompt directly; `starship.toml` remains in the repository as an optional configuration.

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

- Sway: 1 px subtle active border, 4 px inner and 1 px outer gaps, 20 px tab titles.
- Calculator: opens floating.
- Waybar: bottom, 26 px, seconds visible, square workspace indicators; RAM turns Gruvbox red above 80%.
- Rofi: eight launcher rows with the original width and font; a centered power menu opens from Waybar.
- Swaylock: uses `walls/burning-earth.png`.
- Notifications: `Super+N` toggles SwayNC.
- Clipboard: `Super+Shift+V` opens text and image history; persistent user services collect new copies.
- Screenshots: `Super+Shift+S` selects an area and copies it to the clipboard. Cancelling selection or failing to capture leaves the clipboard untouched.
- tmux prefix: `Ctrl+Space`; the session chip changes from yellow to purple while the prefix is active.
- Special Sway mode: `Super+Z`, then `c` copies a picked color, `s` copies a selected screenshot, and `a` saves an output screenshot.
- Shell tools: `ls`/`ll`/`la`/`lt` use `eza`, `cat` uses `bat`, and `rgf` lists files with `ripgrep`.

The original `sve`, `tux`, `chaos`, and `orbit` wallpapers were removed. `wall.png`, `wallg.png`, and `burning-earth.png` remain.

## Editors

- Neovim: transparent Gruvbox, one shared status line, upright comments, Treesitter highlighting for JavaScript, TypeScript/TSX, Go, Rust, Zig, Lua, C and C++. Language servers include `ts_ls`, `gopls`, `rust_analyzer`, `zls`, `lua_ls` and `clangd`; Mason installs the servers.
- Vim: `vim/vimrc` installs to `~/.vimrc`. Uses Vim's built-in Retrobox theme, transparent gutters, relative line numbers and a small status line, with no additional plugins.

The normal installer supplies and checks the core editor prerequisites. With `--files-only`, install those prerequisites separately and verify them with `./scripts/check-editor-deps`. Install the Go, Rust and Zig toolchains for the languages you use. Keep Zig and ZLS release versions aligned; this setup was checked with both at 0.16.0.

## Verification

Run the regression checks from the repository root:

```bash
python3 -m unittest discover -s tests -v
```

The checks cover screenshot cancellation/capture errors, editor prerequisite versions, and wallpaper/backup preservation across two installs with the same timestamp. Screenshot commands are mocked so the tests do not touch your clipboard. The installer check uses a temporary home directory and runs only on Fedora as a non-root user; package installation, service startup and NVIDIA setup are not exercised.
