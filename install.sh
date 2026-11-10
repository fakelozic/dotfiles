#!/usr/bin/env bash

set -Eeuo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
target_home="${DOTFILES_TARGET_HOME:-$HOME}"
if [[ -n ${DOTFILES_TARGET_HOME:-} ]]; then
  config_root="${target_home}/.config"
  data_root="${target_home}/.local/share"
  state_root="${target_home}/.local/state"
else
  config_root="${XDG_CONFIG_HOME:-${target_home}/.config}"
  data_root="${XDG_DATA_HOME:-${target_home}/.local/share}"
  state_root="${XDG_STATE_HOME:-${target_home}/.local/state}"
fi
# Only for tests: install the system tweaks under this directory instead of /.
system_root="${DOTFILES_SYSTEM_ROOT:-}"
timestamp="$(date +%Y%m%d-%H%M%S)"
backup_root=""
download_temp_dir=""

cleanup() {
  if [[ -n ${download_temp_dir} && -d ${download_temp_dir} ]]; then
    rm -rf -- "$download_temp_dir"
  fi
}
trap cleanup EXIT

files_only=0
skip_nvidia=0
nvidia_installed=0
skip_shell_change=0
skip_reload=0
skip_kde=0
skip_update=0
with_system=0

usage() {
  cat <<'EOF'
Usage: ./install.sh [options]

Options:
  --files-only         Install dotfiles only; skip packages, developer tools,
                       downloads, the login shell and KDE settings.
  --skip-kde           Copy the KDE files but do not change Plasma's settings.
  --skip-update        Do not install pending Fedora updates first.
  --system             Also apply the system tweaks in system/ (uses sudo): zram and
                       swap settings, MGLRU, plocate exclusions, parallel dnf
                       downloads and the login screen wallpaper.
  --skip-nvidia        Do not install NVIDIA drivers.
  --skip-shell-change  Do not make Zsh the login shell.
  --skip-reload        Do not reload a running tmux server.
  -h, --help           Show this help.

For installer testing, DOTFILES_TARGET_HOME may point at a temporary directory.
EOF
}

while (($#)); do
  case "$1" in
    --files-only) files_only=1 ;;
    --skip-kde) skip_kde=1 ;;
    --skip-update) skip_update=1 ;;
    --system) with_system=1 ;;
    --skip-nvidia) skip_nvidia=1 ;;
    --skip-shell-change) skip_shell_change=1 ;;
    --skip-reload) skip_reload=1 ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Unknown option: %s\n\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

if [[ ! -r /etc/fedora-release ]]; then
  printf 'This installer supports Fedora only.\n' >&2
  exit 1
fi

if [[ ${EUID} -eq 0 ]]; then
  printf 'Run this as your normal user; it will use sudo when needed.\n' >&2
  exit 1
fi

required_files=(
  alacritty/alacritty.toml
  fastfetch/config.jsonc
  fastfetch/fedora.txt
  fontconfig/fonts.conf
  ghostty/config.ghostty
  ghostty/shaders/cursor_trail.glsl
  kde/BreezeCharcoal.colors
  kde/build-folder-icons
  kde/panel.js
  kde/plasmoids/org.fak3.desktops/metadata.json
  kde/plasmoids/org.fak3.ramindicator/metadata.json
  kde/shortcuts.py
  mise/config.toml
  scripts/check-editor-deps
  starship.toml
  system/sysctl.d/99-desktop-memory.conf
  system/tmpfiles.d/mglru-min-ttl.conf
  system/zram-generator.conf
  tmux/tmux.conf
  tmux/gruvbox-theme.conf
  vim/vimrc
  walls/cat-wall.jpeg
  zsh/.zshrc
  zsh/.zshrc.local
  zsh/themes/gruvbox.zsh-theme
)

for relative_path in "${required_files[@]}"; do
  if [[ ! -f ${repo_root}/${relative_path} ]]; then
    printf 'Missing repository file: %s\n' "$relative_path" >&2
    exit 1
  fi
done

# Installs pending Fedora updates before anything else. If there were any, offers
# to reboot and stops; running the installer again after the reboot continues.
update_system() {
  local status=0 answer=""
  printf 'Checking for Fedora updates...\n'
  sudo dnf check-upgrade --refresh --quiet >/dev/null 2>&1 || status=$?
  case $status in
    0)
      printf 'Fedora is up to date.\n'
      return
      ;;
    100) ;;
    *)
      printf 'Could not check for updates (dnf exit status %s); continuing.\n' "$status" >&2
      return
      ;;
  esac

  # One upgrade can make more updates available, so repeat until none are left.
  local round
  for round in 1 2 3; do
    printf 'Installing Fedora updates (round %s)...\n' "$round"
    sudo dnf upgrade -y --refresh
    status=0
    sudo dnf check-upgrade --refresh --quiet >/dev/null 2>&1 || status=$?
    ((status == 100)) || break
  done
  printf '\nUpdates are installed. Reboot, then run ./install.sh again to continue.\n'
  if [[ -t 0 ]]; then
    read -r -p 'Reboot now? [y/N] ' answer
    if [[ $answer == [yY]* ]]; then
      sudo systemctl reboot
    fi
  fi
  exit 0
}

install_packages() {
  local packages=(
    alacritty
    bat
    breeze-cursor-theme
    curl
    eza
    fastfetch
    fd-find
    fontconfig
    gcc
    ghostty
    git-core
    make
    papirus-icon-theme
    pciutils
    python3-dbus
    rsms-inter-fonts
    ripgrep
    tar
    tmux
    tree-sitter-cli
    unzip
    vim-enhanced
    wl-clipboard
    xz
    zsh
  )

  # Ghostty is not in Fedora's repositories; scottames/ghostty packages it.
  if ! dnf repolist --enabled 2>/dev/null | grep -q 'scottames:ghostty'; then
    printf 'Enabling the Ghostty COPR repository...\n'
    sudo dnf copr enable -y scottames/ghostty
  fi
  printf 'Installing Fedora packages...\n'
  sudo dnf install -y "${packages[@]}"
}

# Runs a tool's official install script, unless the tool is already installed
# (each of them updates itself afterwards).
run_installer() {
  local name="$1" installed="$2" url="$3"
  shift 3
  if [[ -x $installed ]]; then
    printf '%s is already installed.\n' "$name"
    return
  fi
  printf 'Installing %s...\n' "$name"
  curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 "$url" | "$@"
}

install_dev_tools() {
  local bin="${target_home}/.local/bin"

  # mise installs the global tools in mise/config.toml: Go, Node, pnpm, gh,
  # Neovim, and codex from npm. The file itself is copied with the dotfiles below.
  run_installer mise "${bin}/mise" https://mise.run sh
  printf 'Installing the mise tools...\n'
  export MISE_GLOBAL_CONFIG_FILE="${repo_root}/mise/config.toml"
  (cd -- "$target_home" && "${bin}/mise" install --yes)

  # These use their own installers and update themselves.
  # Bun adds itself to the current shell's startup file; as zsh that is ~/.zshrc,
  # which the dotfiles replace, instead of ~/.bash_profile, which they keep.
  run_installer Bun "${target_home}/.bun/bin/bun" https://bun.sh/install env SHELL=/usr/bin/zsh bash
  run_installer nub "${target_home}/.nub/bin/nub" https://nubjs.com/install.sh env NUB_NO_MODIFY_PATH=1 bash
  run_installer opencode "${target_home}/.opencode/bin/opencode" https://opencode.ai/v2/install bash -s -- --no-modify-path
  run_installer 'Claude Code' "${bin}/claude" https://claude.ai/install.sh bash
  run_installer Rust "${target_home}/.cargo/bin/rustup" https://sh.rustup.rs sh -s -- -y --no-modify-path
  # Starship draws the prompt. Any existing copy counts, wherever it lives.
  if command -v starship >/dev/null 2>&1; then
    printf 'Starship is already installed.\n'
  else
    run_installer Starship "${bin}/starship" https://starship.rs/install.sh sh -s -- --yes --bin-dir "$bin"
  fi

  # The rest of this script (the editor check) needs them on PATH.
  export PATH="${data_root}/mise/shims:${bin}:${target_home}/.cargo/bin:${PATH}"
}

install_nvidia_if_needed() {
  if ((skip_nvidia)); then
    printf 'Skipping NVIDIA setup by request.\n'
    return
  fi

  if ! lspci -n 2>/dev/null | grep -qi '10de:'; then
    printf 'No NVIDIA PCI device detected; skipping NVIDIA setup.\n'
    return
  fi

  local fedora_version
  fedora_version="$(rpm -E %fedora)"
  printf 'NVIDIA hardware detected; enabling RPM Fusion and installing akmods...\n'
  sudo dnf install -y \
    "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-${fedora_version}.noarch.rpm" \
    "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${fedora_version}.noarch.rpm"
  sudo dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda libva-nvidia-driver
  nvidia_installed=1
  sudo akmods --force
}

install_nerd_font() {
  local font_dir="${data_root}/fonts"
  download_temp_dir="$(mktemp -d)"

  printf 'Installing JetBrainsMono Nerd Font...\n'
  curl --fail --location --retry 3 \
    --output "${download_temp_dir}/JetBrainsMono.tar.xz" \
    'https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/JetBrainsMono.tar.xz'
  printf '%s  %s\n' \
    '04d5e8f903693f9dd13e16f867e994834e681eb3c72c0d337a770dcda09010cf' \
    "${download_temp_dir}/JetBrainsMono.tar.xz" | sha256sum --check --status
  mkdir -p -- "$font_dir"
  tar -xJf "${download_temp_dir}/JetBrainsMono.tar.xz" -C "$download_temp_dir"
  find "$download_temp_dir" -maxdepth 1 -type f -name '*.ttf' -exec install -m 0644 -t "$font_dir" {} +
  fc-cache -f "$font_dir"
  cleanup
  download_temp_dir=""
}

install_oh_my_zsh() {
  local omz_dir="${target_home}/.oh-my-zsh"
  if [[ -d ${omz_dir}/.git ]]; then
    printf 'Oh My Zsh already exists; leaving it at its current revision.\n'
  else
    printf 'Installing Oh My Zsh...\n'
    git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$omz_dir"
  fi
}

backup_path() {
  local source_path="$1"
  local relative_path

  if [[ ! -e $source_path && ! -L $source_path ]]; then
    return
  fi

  relative_path="${source_path#"${target_home}/"}"
  mkdir -p -- "${backup_root}/$(dirname -- "$relative_path")"
  cp -a -- "$source_path" "${backup_root}/${relative_path}"
}

install_file() {
  local source_path="$1"
  local destination_path="$2"
  install -Dm0644 -- "$source_path" "$destination_path"
}

# KDE keeps these in single files that the settings below change in place.
kde_config_files=(
  kdeglobals
  kwinrc
  breezerc
  kcminputrc
  ksplashrc
  kscreenlockerrc
  kglobalshortcutsrc
  plasma-org.kde.plasma.desktop-appletsrc
)

install_dotfiles() {
  local name
  local backup_targets=(
    "${config_root}/alacritty"
    "${config_root}/fastfetch"
    "${config_root}/fontconfig/fonts.conf"
    "${config_root}/mise/config.toml"
    "${config_root}/ghostty/config.ghostty"
    "${config_root}/ghostty/shaders/cursor_trail.glsl"
    "${config_root}/nvim"
    "${config_root}/starship.toml"
    "${config_root}/tmux"
    "${data_root}/color-schemes/BreezeCharcoal.colors"
    "${data_root}/plasma/plasmoids/org.fak3.desktops"
    "${data_root}/plasma/plasmoids/org.fak3.ramindicator"
    "${target_home}/.vimrc"
    "${target_home}/.zshrc"
    "${target_home}/.zshrc.local"
    "${target_home}/.oh-my-zsh/custom/themes/gruvbox.zsh-theme"
    "${target_home}/walls/cat-wall.jpeg"
  )
  for name in "${kde_config_files[@]}"; do
    backup_targets+=("${config_root}/${name}")
  done

  mkdir -p -- "${state_root}/dotfiles-backups"
  backup_root="$(mktemp -d "${state_root}/dotfiles-backups/${timestamp}-XXXXXX")"

  printf 'Backing up existing configuration to %s\n' "$backup_root"
  for target in "${backup_targets[@]}"; do
    backup_path "$target"
  done

  install_file "${repo_root}/alacritty/alacritty.toml" "${config_root}/alacritty/alacritty.toml"
  install_file "${repo_root}/fastfetch/config.jsonc" "${config_root}/fastfetch/config.jsonc"
  install_file "${repo_root}/fastfetch/fedora.txt" "${config_root}/fastfetch/fedora.txt"
  install_file "${repo_root}/fontconfig/fonts.conf" "${config_root}/fontconfig/fonts.conf"
  install_file "${repo_root}/ghostty/config.ghostty" "${config_root}/ghostty/config.ghostty"
  install_file "${repo_root}/ghostty/shaders/cursor_trail.glsl" "${config_root}/ghostty/shaders/cursor_trail.glsl"
  # Ghostty needs the shader as a full path.
  sed -i "s|^custom-shader = ~/|custom-shader = ${target_home}/|" "${config_root}/ghostty/config.ghostty"
  install_file "${repo_root}/starship.toml" "${config_root}/starship.toml"
  install_file "${repo_root}/tmux/tmux.conf" "${config_root}/tmux/tmux.conf"
  install_file "${repo_root}/tmux/gruvbox-theme.conf" "${config_root}/tmux/gruvbox-theme.conf"
  install_file "${repo_root}/vim/vimrc" "${target_home}/.vimrc"
  install_file "${repo_root}/zsh/.zshrc" "${target_home}/.zshrc"
  install_file "${repo_root}/zsh/.zshrc.local" "${target_home}/.zshrc.local"
  install_file "${repo_root}/mise/config.toml" "${config_root}/mise/config.toml"
  install_file "${repo_root}/zsh/themes/gruvbox.zsh-theme" "${target_home}/.oh-my-zsh/custom/themes/gruvbox.zsh-theme"
  install_file "${repo_root}/kde/BreezeCharcoal.colors" "${data_root}/color-schemes/BreezeCharcoal.colors"

  mkdir -p -- "${config_root}/nvim"
  cp -a -- "${repo_root}/nvim/." "${config_root}/nvim/"

  # Replaced whole, so files a newer version no longer has do not linger.
  for name in org.fak3.desktops org.fak3.ramindicator; do
    rm -rf -- "${data_root}/plasma/plasmoids/${name}"
    mkdir -p -- "${data_root}/plasma/plasmoids"
    cp -a -- "${repo_root}/kde/plasmoids/${name}" "${data_root}/plasma/plasmoids/"
  done

  if [[ -f /usr/share/icons/Papirus-Dark/index.theme ]]; then
    "${repo_root}/kde/build-folder-icons" bluegrey "${data_root}/icons"
  else
    printf 'Papirus is not installed; skipping the bluegrey folder icons.\n'
  fi

  mkdir -p -- "${target_home}/walls"
  install -m0644 -- "${repo_root}/walls/cat-wall.jpeg" "${target_home}/walls/cat-wall.jpeg"
}

# Writes one KDE setting and tells running applications about it.
kde_set() {
  local file="$1" group="$2" key="$3" value="$4"
  local group_args=() parts=() part
  IFS='/' read -r -a parts <<< "$group"
  for part in "${parts[@]}"; do
    group_args+=(--group "$part")
  done
  kwriteconfig6 --notify --file "$file" "${group_args[@]}" --key "$key" "$value"
}

configure_kde() {
  local wallpaper="${target_home}/walls/cat-wall.jpeg"
  local font_inter='Inter,10.5,-1,5,400,0,0,0,0,0,0,0,0,0,0,1'
  local count

  if ((skip_kde)) || [[ -n ${DOTFILES_TARGET_HOME:-} ]]; then
    return
  fi
  if [[ ${XDG_CURRENT_DESKTOP:-} != *KDE* ]]; then
    printf 'Not running inside Plasma; run this again from a Plasma session to apply the KDE settings.\n'
    return
  fi

  printf 'Applying KDE settings...\n'
  # Look: Breeze Dark panels, the Breeze Charcoal colour scheme with a steel-blue
  # accent taken from the wallpaper, Breeze cursors and bluegrey Papirus folders.
  plasma-apply-desktoptheme breeze-dark >/dev/null || true
  if [[ $(kreadconfig6 --group General --key ColorScheme) != BreezeCharcoal ]]; then
    plasma-apply-colorscheme BreezeCharcoal >/dev/null || true
  fi
  if [[ $(kreadconfig6 --group General --key AccentColor) != '71,119,145' ]]; then
    plasma-apply-colorscheme --accent-color '#477791' >/dev/null || true
    # Saved as the accent too, so applying a colour scheme later keeps it.
    kde_set kdeglobals General AccentColor 71,119,145
    kde_set kdeglobals General LastUsedCustomAccentColor 71,119,145
  fi
  plasma-apply-cursortheme breeze_cursors >/dev/null || true
  if [[ -d ${data_root}/icons/Papirus-Dark-Bluegrey ]]; then
    /usr/libexec/plasma-changeicons Papirus-Dark-Bluegrey >/dev/null 2>&1 || true
  fi

  # Fonts: Inter for the interface, JetBrains Mono for fixed width.
  kde_set kdeglobals General font "$font_inter"
  kde_set kdeglobals General menuFont "$font_inter"
  kde_set kdeglobals General toolBarFont "$font_inter"
  kde_set kdeglobals General smallestReadableFont 'Inter,9,-1,5,400,0,0,0,0,0,0,0,0,0,0,1'
  kde_set kdeglobals General fixed 'JetBrainsMono Nerd Font,11,-1,5,400,0,0,0,0,0,0,0,0,0,0,1'
  kde_set kdeglobals WM activeFont "$font_inter"

  # Ghostty is the terminal Dolphin and other apps open.
  kde_set kdeglobals General TerminalApplication 'ghostty --gtk-single-instance=true'
  kde_set kdeglobals General TerminalService com.mitchellh.ghostty.desktop

  # Windows: focus follows the mouse, no window borders, instant desktop switching.
  kde_set kwinrc Windows FocusPolicy FocusFollowsMouse
  kde_set kwinrc org.kde.kdecoration2 BorderSize None
  kde_set kwinrc org.kde.kdecoration2 BorderSizeAuto false
  kde_set kwinrc Plugins blurEnabled true
  kde_set kwinrc Plugins fadedesktopEnabled true
  kde_set kwinrc Plugins slideEnabled false
  kde_set kwinrc Effect-fadedesktop AnimationDuration 0
  kde_set kwinrc Effect-blur BlurStrength 11
  kde_set kwinrc Effect-blur NoiseStrength 6
  kde_set kwinrc Effect-translucency MoveResize 91
  kde_set kwinrc TabBox HighlightWindows false
  kde_set breezerc Common OutlineEnabled false
  kde_set breezerc Common ShadowSize ShadowSmall
  kde_set breezerc Style MenuOpacity 85
  kde_set breezerc Windeco TitleAlignment AlignLeft
  kde_set ksplashrc KSplash Engine none
  kde_set ksplashrc KSplash Theme None

  # Input: fast key repeat; flat pointer acceleration for the Razer Viper Mini.
  kde_set kcminputrc Keyboard RepeatDelay 250
  kde_set kcminputrc Keyboard RepeatRate 35
  kde_set kcminputrc 'Libinput/5426/138/Razer Razer Viper Mini' PointerAccelerationProfile 1

  # Six virtual desktops in one row.
  kde_set kwinrc Desktops Rows 1
  count="$(busctl --user get-property org.kde.KWin /VirtualDesktopManager \
    org.kde.KWin.VirtualDesktopManager count 2>/dev/null | awk '{print $2}')"
  while [[ -n $count ]] && ((count < 6)); do
    busctl --user call org.kde.KWin /VirtualDesktopManager \
      org.kde.KWin.VirtualDesktopManager createDesktop us "$count" "Desktop $((count + 1))" || break
    count=$((count + 1))
  done
  busctl --user call org.kde.KWin /KWin org.kde.KWin reconfigure >/dev/null 2>&1 || true

  # Wallpaper on the desktop and the lock screen.
  plasma-apply-wallpaperimage "$wallpaper" >/dev/null || true
  kde_set kscreenlockerrc 'Greeter/Wallpaper/org.kde.image/General' Image "file://${wallpaper}"
  kde_set kscreenlockerrc 'Greeter/Wallpaper/org.kde.image/General' PreviewImage "file://${wallpaper}"

  # Sway-style keys: Meta+1-6, Meta+Shift+1-6, Meta+Shift+Q, Meta+F, Meta+Return.
  python3 "${repo_root}/kde/shortcuts.py" || printf 'Could not apply the shortcuts; continuing.\n' >&2

  # The panel: clock, launcher, pinned apps, Desktops, RAM indicator, tray.
  # kde/panel.js builds it only once and leaves an existing setup alone.
  busctl --user call org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell evaluateScript s \
    "$(<"${repo_root}/kde/panel.js")" | sed -n 's/^s "\(.*\)"$/\1/p' \
    || printf 'Could not build the panel; continuing.\n' >&2

  # KDE's GTK bridge writes GTK's colours only when it starts, so restart it to
  # give GTK apps the new accent.
  busctl --user call org.kde.kded6 /kded org.kde.kded6 unloadModule s gtkconfig >/dev/null 2>&1 || true
  busctl --user call org.kde.kded6 /kded org.kde.kded6 loadModule s gtkconfig >/dev/null 2>&1 || true
}

# Copies one file into the system, keeping a dated copy of a different original.
system_install() {
  local source_path="$1" destination="${system_root}$2"
  if [[ -f $destination ]] && cmp -s "$source_path" "$destination"; then
    return
  fi
  if [[ -f $destination ]]; then
    sudo cp -a -- "$destination" "${destination}.bak-${timestamp}"
  fi
  sudo install -Dm0644 -- "$source_path" "$destination"
  printf '  installed %s\n' "$2"
}

configure_system() {
  local updatedb="${system_root}/etc/updatedb.conf"
  local dnf_conf="${system_root}/etc/dnf/dnf.conf"
  local login_conf="${system_root}/etc/plasmalogin.conf"
  local login_wallpaper=/var/lib/plasmalogin/wallpapers/cat-wall.jpeg

  printf 'Applying system tweaks (sudo)...\n'
  # Memory: zram as the main swap, tuned for it, plus MGLRU thrashing protection.
  system_install "${repo_root}/system/zram-generator.conf" /etc/systemd/zram-generator.conf
  system_install "${repo_root}/system/sysctl.d/99-desktop-memory.conf" /etc/sysctl.d/99-desktop-memory.conf
  system_install "${repo_root}/system/tmpfiles.d/mglru-min-ttl.conf" /etc/tmpfiles.d/mglru-min-ttl.conf

  # plocate's nightly index skips build output and version control folders.
  if [[ -f $updatedb ]] && ! grep -q '^PRUNENAMES' "$updatedb"; then
    printf 'PRUNENAMES = ".git .hg .svn node_modules target .venv __pycache__"\n' | sudo tee -a "$updatedb" >/dev/null
    printf '  added PRUNENAMES to /etc/updatedb.conf\n'
  fi

  # Faster dnf downloads.
  if [[ -f $dnf_conf ]] && ! grep -q '^max_parallel_downloads' "$dnf_conf"; then
    printf 'max_parallel_downloads=10\n' | sudo tee -a "$dnf_conf" >/dev/null
    printf '  added max_parallel_downloads=10 to /etc/dnf/dnf.conf\n'
  fi

  # Login screen wallpaper (Plasma Login Manager).
  if [[ -f $login_conf ]]; then
    system_install "${repo_root}/walls/cat-wall.jpeg" "$login_wallpaper"
    if [[ -z $system_root ]]; then
      sudo restorecon "$login_wallpaper" 2>/dev/null || true
    fi
    if ! grep -qx "Image=file://${login_wallpaper}" "$login_conf"; then
      sudo cp -a -- "$login_conf" "${login_conf}.bak-${timestamp}"
      if grep -q '^Image=' "$login_conf"; then
        sudo sed -i "s|^Image=.*|Image=file://${login_wallpaper}|" "$login_conf"
      else
        printf '[Greeter][Wallpaper][org.kde.image][General]\nImage=file://%s\n' "$login_wallpaper" \
          | sudo tee -a "$login_conf" >/dev/null
      fi
      printf '  set the login screen wallpaper\n'
    fi
  fi

  if [[ -z $system_root ]]; then
    sudo sysctl --quiet --system
    sudo systemd-tmpfiles --create /etc/tmpfiles.d/mglru-min-ttl.conf
    printf 'The zram size change, if any, takes effect after a reboot.\n'
  fi
}

configure_shell() {
  local current_user
  current_user="$(id -un)"
  if ((!skip_shell_change)) && [[ $(getent passwd "$current_user" | cut -d: -f7) != */zsh ]]; then
    printf 'Setting Zsh as the login shell for %s...\n' "$current_user"
    sudo usermod --shell /usr/bin/zsh "$current_user"
  fi
}

reload_session() {
  if ((skip_reload)); then
    return
  fi
  if command -v tmux >/dev/null 2>&1 && tmux list-sessions >/dev/null 2>&1; then
    tmux source-file "${config_root}/tmux/tmux.conf"
  fi
}

if ((!files_only)); then
  if ((!skip_update)); then
    update_system
  fi
  install_packages
  install_dev_tools
  "${repo_root}/scripts/check-editor-deps"
  install_nvidia_if_needed
  install_nerd_font
  install_oh_my_zsh
fi

install_dotfiles

if ((!files_only)); then
  configure_shell
  configure_kde
fi

if ((with_system)); then
  configure_system
fi

reload_session

printf '\nDone. Your previous configuration is in:\n  %s\n' "$backup_root"
printf 'Open new Ghostty windows to see terminal changes. Some KDE changes need a new login.\n'

if ((nvidia_installed)) && command -v mokutil >/dev/null 2>&1 \
  && mokutil --sb-state 2>/dev/null | grep -qi enabled; then
  printf '\nSecure Boot is enabled. If the NVIDIA module does not load after reboot,\n'
  printf 'enroll the akmods signing certificate as described in README.md.\n'
fi
