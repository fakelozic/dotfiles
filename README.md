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

The package list also covers the NetworkManager and Bluetooth tray applets, GNOME Keyring for application secrets and the Papirus icon theme. After installing, the script sets GTK applications to dark mode with Breeze cursors and Papirus icons; the GTK theme itself is left unchanged.

The installer can be run from any desktop or from a console. SwayNC and the clipboard services are always enabled. They are started and checked immediately only inside a running Sway session; otherwise they start at the next Sway login.

Useful installer options:

```bash
./install.sh --files-only
./install.sh --skip-nvidia
./install.sh --skip-shell-change
./install.sh --skip-reload
```

## Machine-specific shell settings

Every install replaces `~/.zshrc`. Keep `PATH` entries, toolchain managers such as mise or SDKMAN, and private aliases in `~/.zshrc.local`. The installed `.zshrc` sources that file last, and the installer never writes to it.

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
- Swaylock: uses `walls/burning-earth.png`. `Super+Escape` locks the screen.
- Notifications: `Super+N` toggles SwayNC.
- Clipboard: `Super+Shift+V` opens text and image history; persistent user services collect new copies.
- Screenshots: `Super+Shift+S` selects an area and copies it to the clipboard. Cancelling selection or failing to capture leaves the clipboard untouched.
- tmux prefix: `Ctrl+Space`, with `Ctrl+A` as a second prefix; press either twice to pass it to the program in the pane. The session chip changes from yellow to purple while the prefix is active.
- Special Sway mode: `Super+Z`, then `c` copies a picked color, `s` copies a selected screenshot, `Shift+s` saves a selected area, and `a` saves an output screenshot. Saved screenshots go to `~/Pictures/Screenshots`.
- Shell tools: `ls`/`ll`/`la`/`lt` use `eza`, `cat` uses `bat`, and `rgf` lists files with `ripgrep`.

The original `sve`, `tux`, `chaos`, and `orbit` wallpapers were removed. `wall.png`, `wallg.png`, and `burning-earth.png` remain.

## Editors

- Neovim: transparent Gruvbox, one shared status line, upright comments, Treesitter highlighting for JavaScript, TypeScript/TSX, Go, Rust, Zig, Lua, C and C++. Language servers include `ts_ls`, `gopls`, `rust_analyzer`, `zls`, `lua_ls` and `clangd`; Mason installs the servers.
- Vim: `vim/vimrc` installs to `~/.vimrc`. Uses Vim's built-in Retrobox theme, transparent gutters, relative line numbers and a small status line, with no additional plugins. Yank and paste share the Wayland clipboard through `wl-clipboard`, as they do in Neovim.

The normal installer supplies and checks the core editor prerequisites. With `--files-only`, install those prerequisites separately and verify them with `./scripts/check-editor-deps`. Install the Go, Rust and Zig toolchains for the languages you use. Keep Zig and ZLS release versions aligned; this setup was checked with both at 0.16.0.

## Verification

Run the regression checks from the repository root:

```bash
python3 -m unittest discover -s tests -v
```

The checks cover screenshot cancellation/capture errors and save locations, editor prerequisite versions, wallpaper/backup preservation across two installs with the same timestamp, and session service setup inside and outside Sway. Screenshot commands are mocked so the tests do not touch your clipboard. The installer checks use a temporary home directory and run only on Fedora as a non-root user. `sudo`, `systemctl`, `gsettings` and downloads are mocked there, so real package installation, service startup and NVIDIA setup are not exercised.
