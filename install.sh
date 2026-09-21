#!/usr/bin/env bash

set -Eeuo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
target_home="${DOTFILES_TARGET_HOME:-$HOME}"
if [[ -n ${DOTFILES_TARGET_HOME:-} ]]; then
  config_root="${target_home}/.config"
  state_root="${target_home}/.local/state"
else
  config_root="${XDG_CONFIG_HOME:-${target_home}/.config}"
  state_root="${XDG_STATE_HOME:-${target_home}/.local/state}"
fi
timestamp="$(date +%Y%m%d-%H%M%S)"
backup_root="${state_root}/dotfiles-backups/${timestamp}"
download_temp_dir=""

cleanup() {
  if [[ -n ${download_temp_dir} && -d ${download_temp_dir} ]]; then
    rm -rf -- "$download_temp_dir"
  fi
}
trap cleanup EXIT

files_only=0
skip_nvidia=0
skip_shell_change=0
skip_reload=0

usage() {
  cat <<'EOF'
Usage: ./install.sh [options]

Options:
  --files-only         Install dotfiles only; skip packages, downloads and services.
  --skip-nvidia        Do not install NVIDIA drivers or its Sway environment file.
  --skip-shell-change  Do not make Zsh the login shell.
  --skip-reload        Do not reload a currently running Sway/tmux session.
  -h, --help           Show this help.

For installer testing, DOTFILES_TARGET_HOME may point at a temporary directory.
EOF
}

while (($#)); do
  case "$1" in
    --files-only) files_only=1 ;;
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
  rofi/config.rasi
  sway/config
  sway/config.d/95-gruvbox-rice.conf
  sway/environment
  swaylock/config
  swaync/config.json
  swaync/style.css
  tmux/tmux.conf
  tmux/gruvbox-theme.conf
  walls/burning-earth.png
  walls/wall.png
  walls/wallg.png
  waybar/config.jsonc
  waybar/style.css
  zsh/.zshrc
  zsh/themes/gruvbox.zsh-theme
)

for relative_path in "${required_files[@]}"; do
  if [[ ! -f ${repo_root}/${relative_path} ]]; then
    printf 'Missing repository file: %s\n' "$relative_path" >&2
    exit 1
  fi
done

install_packages() {
  local packages=(
    alacritty
    bat
    breeze-cursor-theme
    cliphist
    curl
    eza
    fontconfig
    git-core
    gnome-calculator
    grim
    grimpicker
    jq
    lxqt-policykit
    neovim
    NetworkManager-tui
    pavucontrol
    pciutils
    ripgrep
    rofi
    slurp
    sway
    swaybg
    sway-config-fedora
    sway-systemd
    swayidle
    swaylock
    SwayNotificationCenter
    tmux
    waybar
    wireplumber
    wl-clipboard
    xdg-desktop-portal-gtk
    xdg-desktop-portal-wlr
    xz
    zsh
  )

  printf 'Installing Fedora packages...\n'
  sudo dnf install -y "${packages[@]}"
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
  sudo akmods --force
}

install_nerd_font() {
  local font_dir="${target_home}/.local/share/fonts"
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

install_dotfiles() {
  local backup_targets=(
    "${config_root}/alacritty"
    "${config_root}/nvim"
    "${config_root}/rofi"
    "${config_root}/sway"
    "${config_root}/swaylock"
    "${config_root}/swaync"
    "${config_root}/tmux"
    "${config_root}/waybar"
    "${target_home}/.zshrc"
    "${target_home}/.oh-my-zsh/custom/themes/gruvbox.zsh-theme"
  )

  printf 'Backing up existing configuration to %s\n' "$backup_root"
  for target in "${backup_targets[@]}"; do
    backup_path "$target"
  done

  install_file "${repo_root}/alacritty/alacritty.toml" "${config_root}/alacritty/alacritty.toml"
  install_file "${repo_root}/rofi/config.rasi" "${config_root}/rofi/config.rasi"
  install_file "${repo_root}/sway/config" "${config_root}/sway/config"
  install_file "${repo_root}/sway/config.d/95-gruvbox-rice.conf" "${config_root}/sway/config.d/95-gruvbox-rice.conf"
  install_file "${repo_root}/swaylock/config" "${config_root}/swaylock/config"
  sed -i "s|^image=.*|image=${target_home}/walls/burning-earth.png|" "${config_root}/swaylock/config"
  install_file "${repo_root}/swaync/config.json" "${config_root}/swaync/config.json"
  install_file "${repo_root}/swaync/style.css" "${config_root}/swaync/style.css"
  install_file "${repo_root}/tmux/tmux.conf" "${config_root}/tmux/tmux.conf"
  install_file "${repo_root}/tmux/gruvbox-theme.conf" "${config_root}/tmux/gruvbox-theme.conf"
  install_file "${repo_root}/waybar/config.jsonc" "${config_root}/waybar/config.jsonc"
  install_file "${repo_root}/waybar/style.css" "${config_root}/waybar/style.css"
  install_file "${repo_root}/zsh/.zshrc" "${target_home}/.zshrc"
  install_file "${repo_root}/zsh/themes/gruvbox.zsh-theme" "${target_home}/.oh-my-zsh/custom/themes/gruvbox.zsh-theme"

  mkdir -p -- "${config_root}/nvim"
  cp -a -- "${repo_root}/nvim/." "${config_root}/nvim/"

  mkdir -p -- "${target_home}/walls" "${target_home}/Pictures/Screenshots"
  install -m0644 -- "${repo_root}/walls/burning-earth.png" "${target_home}/walls/burning-earth.png"
  install -m0644 -- "${repo_root}/walls/wall.png" "${target_home}/walls/wall.png"
  install -m0644 -- "${repo_root}/walls/wallg.png" "${target_home}/walls/wallg.png"

  if ((skip_nvidia)); then
    printf 'Not installing the NVIDIA-specific Sway environment file.\n'
  elif command -v lspci >/dev/null 2>&1 && lspci -n 2>/dev/null | grep -qi '10de:'; then
    install_file "${repo_root}/sway/environment" "${config_root}/sway/environment"
  else
    printf 'No NVIDIA device detected; not installing the NVIDIA-specific Sway environment file.\n'
  fi
}

configure_session() {
  local current_user
  current_user="$(id -un)"

  if ((!skip_shell_change)); then
    printf 'Setting Zsh as the login shell for %s...\n' "$current_user"
    sudo usermod --shell /usr/bin/zsh "$current_user"
  fi

  # Waybar is launched by Fedora's Sway config. A user service would duplicate it.
  systemctl --user disable --now waybar.service >/dev/null 2>&1 || true
  systemctl --user enable --now swaync.service >/dev/null 2>&1 || true
}

reload_session() {
  if ((skip_reload)); then
    return
  fi

  if [[ -n ${SWAYSOCK:-} ]] && command -v swaymsg >/dev/null 2>&1; then
    swaymsg reload >/dev/null
  fi
  if command -v swaync-client >/dev/null 2>&1; then
    swaync-client --reload-config >/dev/null 2>&1 || true
    swaync-client --reload-css >/dev/null 2>&1 || true
  fi
  if command -v tmux >/dev/null 2>&1 && tmux list-sessions >/dev/null 2>&1; then
    tmux source-file "${config_root}/tmux/tmux.conf"
  fi
}

if ((!files_only)); then
  install_packages
  install_nvidia_if_needed
  install_nerd_font
  install_oh_my_zsh
fi

install_dotfiles

if ((!files_only)); then
  configure_session
fi

reload_session

printf '\nDone. Your previous configuration is in:\n  %s\n' "$backup_root"
printf 'Log out and select Sway from the login screen.\n'

if ((!files_only && !skip_nvidia)) && command -v mokutil >/dev/null 2>&1 \
  && mokutil --sb-state 2>/dev/null | grep -qi enabled; then
  printf '\nSecure Boot is enabled. If the NVIDIA module does not load after reboot,\n'
  printf 'enroll the akmods signing certificate as described in README.md.\n'
fi
