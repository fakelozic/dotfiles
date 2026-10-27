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
  cinnamon/applets/gpaste-reloaded@feuerfuchs.eu/metadata.json
  cinnamon/applets/ram@dotfiles/applet.js
  cinnamon/applets/ram@dotfiles/metadata.json
  cinnamon/appearance.dconf
  cinnamon/keybindings.dconf
  cinnamon/themes/Matcha-dark-gruvbox/index.theme
  cinnamon/themes/Matcha-dark-gruvbox/cinnamon/cinnamon.css
  cinnamon/themes/Matcha-dark-gruvbox/gtk-3.0/gtk.css
  firefox/user.js
  firefox/userChrome.css
  gnome-terminal/profile.dconf
  rofi/config.rasi
  scripts/cliphist-rofi
  scripts/lock-screen
  scripts/nightlight
  scripts/pick-color
  scripts/screenshot
  scripts/check-editor-deps
  quickshell/shell.qml
  sway/config
  sway/config.d/90-bar.conf
  sway/config.d/90-swayidle.conf
  sway/config.d/95-autostart-policykit-agent.conf
  sway/config.d/95-gruvbox-rice.conf
  sway/environment
  swaylock/config
  systemd/user/cliphist-image.service
  systemd/user/cliphist-text.service
  tmux/tmux.conf
  tmux/gruvbox-theme.conf
  walls/burning-earth.png
  walls/wall.png
  walls/wall-gruvbox.png
  walls/wallg.png
  vim/vimrc
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
    blueman
    breeze-cursor-theme
    cliphist
    gpaste
    curl
    eza
    fd-find
    fontconfig
    gcc
    git-core
    gnome-calculator
    gnome-keyring
    gnome-keyring-pam
    grim
    ImageMagick
    jq
    lxqt-policykit
    make
    neovim
    nodejs
    npm
    network-manager-applet
    NetworkManager-tui
    papirus-icon-theme
    pavucontrol
    pciutils
    quickshell
    rsms-inter-fonts
    ripgrep
    rofi
    slurp
    sway
    swaybg
    sway-config-fedora
    sway-systemd
    swayidle
    swaylock
    tar
    tmux
    tree-sitter-cli
    unzip
    vim-enhanced
    wireplumber
    wl-clipboard
    wlsunset
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

# Prints the profile directory Firefox opens by default, or nothing when
# Firefox has not been started yet.
find_firefox_profile() {
  local root relative

  # Firefox keeps using ~/.mozilla when it exists; newer installs use XDG.
  for root in "${target_home}/.mozilla/firefox" "${config_root}/mozilla/firefox"; do
    [[ -r ${root}/profiles.ini ]] || continue
    # Each [Install...] section names the profile that installation opens.
    relative="$(awk '/^\[/ { install = /^\[Install/ }
      install && /^Default=/ { sub(/\r$/, ""); print substr($0, 9); exit }' "${root}/profiles.ini")"
    [[ -n $relative ]] || continue
    [[ $relative == /* ]] || relative="${root}/${relative}"
    if [[ -d $relative ]]; then
      printf '%s\n' "$relative"
      return 0
    fi
  done
  return 0
}

install_dotfiles() {
  local firefox_profile
  local backup_targets=(
    "${config_root}/alacritty"
    "${target_home}/.local/share/cinnamon/applets/gpaste-reloaded@feuerfuchs.eu"
    "${target_home}/.local/share/cinnamon/applets/ram@dotfiles"
    "${target_home}/.themes/Matcha-dark-gruvbox"
    "${config_root}/nvim"
    "${config_root}/quickshell"
    "${config_root}/rofi"
    "${config_root}/sway"
    "${config_root}/swaylock"
    "${config_root}/systemd/user/cliphist-image.service"
    "${config_root}/systemd/user/cliphist-text.service"
    "${config_root}/tmux"
    "${target_home}/.local/bin/cliphist-rofi"
    "${target_home}/.local/bin/lock-screen"
    "${target_home}/.local/bin/nightlight"
    "${target_home}/.local/bin/pick-color"
    "${target_home}/.local/bin/screenshot"
    "${target_home}/.vimrc"
    "${target_home}/.zshrc"
    "${target_home}/.oh-my-zsh/custom/themes/gruvbox.zsh-theme"
    "${target_home}/walls/burning-earth.png"
    "${target_home}/walls/wall.png"
    "${target_home}/walls/wall-gruvbox.png"
    "${target_home}/walls/wallg.png"
  )

  firefox_profile="$(find_firefox_profile)"
  if [[ -n $firefox_profile ]]; then
    backup_targets+=(
      "${firefox_profile}/chrome/userChrome.css"
      "${firefox_profile}/user.js"
    )
  fi

  mkdir -p -- "${state_root}/dotfiles-backups"
  backup_root="$(mktemp -d "${state_root}/dotfiles-backups/${timestamp}-XXXXXX")"

  printf 'Backing up existing configuration to %s\n' "$backup_root"
  for target in "${backup_targets[@]}"; do
    backup_path "$target"
  done

  install_file "${repo_root}/alacritty/alacritty.toml" "${config_root}/alacritty/alacritty.toml"
  install_file "${repo_root}/rofi/config.rasi" "${config_root}/rofi/config.rasi"
  install -Dm0755 -- "${repo_root}/scripts/cliphist-rofi" "${target_home}/.local/bin/cliphist-rofi"
  install -Dm0755 -- "${repo_root}/scripts/lock-screen" "${target_home}/.local/bin/lock-screen"
  install -Dm0755 -- "${repo_root}/scripts/nightlight" "${target_home}/.local/bin/nightlight"
  install -Dm0755 -- "${repo_root}/scripts/pick-color" "${target_home}/.local/bin/pick-color"
  install -Dm0755 -- "${repo_root}/scripts/screenshot" "${target_home}/.local/bin/screenshot"
  install_file "${repo_root}/vim/vimrc" "${target_home}/.vimrc"
  install_file "${repo_root}/sway/config" "${config_root}/sway/config"
  install_file "${repo_root}/sway/config.d/90-bar.conf" "${config_root}/sway/config.d/90-bar.conf"
  install_file "${repo_root}/sway/config.d/90-swayidle.conf" "${config_root}/sway/config.d/90-swayidle.conf"
  install_file "${repo_root}/sway/config.d/95-autostart-policykit-agent.conf" "${config_root}/sway/config.d/95-autostart-policykit-agent.conf"
  install_file "${repo_root}/sway/config.d/95-gruvbox-rice.conf" "${config_root}/sway/config.d/95-gruvbox-rice.conf"
  install_file "${repo_root}/swaylock/config" "${config_root}/swaylock/config"
  sed -i "s|^image=.*|image=${target_home}/walls/burning-earth.png|" "${config_root}/swaylock/config"
  install_file "${repo_root}/systemd/user/cliphist-image.service" "${config_root}/systemd/user/cliphist-image.service"
  install_file "${repo_root}/systemd/user/cliphist-text.service" "${config_root}/systemd/user/cliphist-text.service"
  install_file "${repo_root}/tmux/tmux.conf" "${config_root}/tmux/tmux.conf"
  install_file "${repo_root}/tmux/gruvbox-theme.conf" "${config_root}/tmux/gruvbox-theme.conf"
  install_file "${repo_root}/zsh/.zshrc" "${target_home}/.zshrc"
  install_file "${repo_root}/zsh/themes/gruvbox.zsh-theme" "${target_home}/.oh-my-zsh/custom/themes/gruvbox.zsh-theme"

  if [[ -n $firefox_profile ]]; then
    install_file "${repo_root}/firefox/userChrome.css" "${firefox_profile}/chrome/userChrome.css"
    install_file "${repo_root}/firefox/user.js" "${firefox_profile}/user.js"
    printf 'Installed the Firefox theme; restart Firefox to see changes.\n'
  else
    printf 'No Firefox profile found; skipping the Firefox theme. Start Firefox once, then run this again.\n'
  fi

  mkdir -p -- "${config_root}/nvim"
  cp -a -- "${repo_root}/nvim/." "${config_root}/nvim/"

  mkdir -p -- "${target_home}/.local/share/cinnamon/applets"
  cp -a -- "${repo_root}/cinnamon/applets/." "${target_home}/.local/share/cinnamon/applets/"

  # Replaced whole, so files a rebuilt theme no longer has do not linger.
  rm -rf -- "${target_home}/.themes/Matcha-dark-gruvbox"
  mkdir -p -- "${target_home}/.themes"
  cp -a -- "${repo_root}/cinnamon/themes/Matcha-dark-gruvbox" "${target_home}/.themes/"

  mkdir -p -- "${config_root}/quickshell"
  cp -a -- "${repo_root}/quickshell/." "${config_root}/quickshell/"

  mkdir -p -- "${target_home}/walls" "${target_home}/Pictures/Screenshots"
  install -m0644 -- "${repo_root}/walls/burning-earth.png" "${target_home}/walls/burning-earth.png"
  install -m0644 -- "${repo_root}/walls/wall.png" "${target_home}/walls/wall.png"
  install -m0644 -- "${repo_root}/walls/wall-gruvbox.png" "${target_home}/walls/wall-gruvbox.png"
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
  local current_user service
  local session_services=(
    cliphist-text.service
    cliphist-image.service
  )
  current_user="$(id -un)"

  if ((!skip_shell_change)); then
    printf 'Setting Zsh as the login shell for %s...\n' "$current_user"
    sudo usermod --shell /usr/bin/zsh "$current_user"
  fi

  # Quickshell draws the bar and shows notifications, started by
  # sway/config.d/90-bar.conf. A Waybar user service would add a second bar.
  # SwayNC is masked as well as disabled, because D-Bus would otherwise start
  # it again for the first notification and keep Quickshell from receiving any.
  systemctl --user daemon-reload
  systemctl --user disable --now waybar.service >/dev/null 2>&1 || true
  systemctl --user disable --now swaync.service >/dev/null 2>&1 || true
  systemctl --user mask swaync.service >/dev/null 2>&1 || true
  systemctl --user enable "${session_services[@]}"

  # These services need a running Sway session. From another desktop or a
  # console they cannot start yet, so enabling them is all that can be done.
  if [[ -z ${SWAYSOCK:-} ]]; then
    printf 'Not running inside Sway; the session services start at the next Sway login.\n'
    return
  fi

  # Quickshell's notification server needs the bus name these daemons take.
  systemctl --user stop dunst.service mako.service >/dev/null 2>&1 || true
  systemctl --user start "${session_services[@]}"
  for service in "${session_services[@]}"; do
    if ! systemctl --user is-active --quiet "$service"; then
      printf 'Service failed to start: %s\n' "$service" >&2
      systemctl --user --no-pager status "$service" >&2 || true
      return 1
    fi
  done
}

configure_appearance() {
  local schema=org.gnome.desktop.interface
  local setting key value
  local settings=(
    'color-scheme prefer-dark'
    'cursor-theme breeze_cursors'
    'cursor-size 24'
    'icon-theme Papirus-Dark'
  )

  if ! command -v gsettings >/dev/null 2>&1; then
    printf 'gsettings not found; skipping GTK appearance settings.\n' >&2
    return
  fi

  # GTK applications read these instead of Sway's cursor theme. The GTK theme
  # itself is left as it is.
  printf 'Applying dark GTK appearance, Breeze cursors and Papirus icons...\n'
  for setting in "${settings[@]}"; do
    read -r key value <<< "$setting"
    if ! gsettings set "$schema" "$key" "$value"; then
      printf 'Could not set %s %s; continuing.\n' "$schema" "$key" >&2
    fi
  done
}

set_applet_setting() {
  local uuid="$1" key="$2" value="$3"
  local settings_dir="${config_root}/cinnamon/spices/${uuid}"

  if [[ $(gsettings get org.cinnamon enabled-applets) != *"$uuid"* ]]; then
    return
  fi
  # Cinnamon writes an applet's settings file when it first loads the applet,
  # and does not notice later changes to it, so the applet is reloaded.
  for _ in {1..10}; do
    compgen -G "${settings_dir}/*.json" >/dev/null && break
    sleep 0.5
  done
  if python3 -I -c '
import json, sys
key, value = sys.argv[1], json.loads(sys.argv[2])
changed = False
for path in sys.argv[3:]:
    try:
        with open(path) as file:
            settings = json.load(file)
    except FileNotFoundError:
        continue
    if key in settings and settings[key].get("value") != value:
        settings[key]["value"] = value
        with open(path, "w") as file:
            json.dump(settings, file, indent=4)
        changed = True
sys.exit(0 if changed else 1)
' "$key" "$value" "$settings_dir"/*.json; then
    gdbus call --session --dest org.Cinnamon --object-path /org/Cinnamon \
      --method org.Cinnamon.ReloadXlet "$uuid" APPLET >/dev/null || true
  fi
}

configure_cinnamon() {
  local applets cinnamon_pid settings_backup uuid

  # dconf is per user, so a test install into DOTFILES_TARGET_HOME would still
  # change the real desktop.
  if [[ -n ${DOTFILES_TARGET_HOME:-} ]] || ! command -v cinnamon >/dev/null 2>&1 \
    || ! command -v dconf >/dev/null 2>&1; then
    return
  fi

  settings_backup="${backup_root}/cinnamon.dconf"
  dconf dump /org/cinnamon/ > "$settings_backup"
  printf 'Applying Sway-style Cinnamon keybindings and key repeat (previous Cinnamon settings saved to %s)...\n' \
    "$settings_backup"
  dconf load /org/cinnamon/ < "${repo_root}/cinnamon/keybindings.dconf"

  # The GNOME keys are what GTK apps outside Cinnamon (and on Sway) read.
  dconf dump /org/gnome/desktop/interface/ > "${backup_root}/gnome-interface.dconf"
  dconf dump /org/nemo/desktop/ > "${backup_root}/nemo-desktop.dconf"
  printf 'Applying the Gruvbox Matcha theme and Inter fonts...\n'
  dconf load /org/ < "${repo_root}/cinnamon/appearance.dconf"

  # Put each applet just left of the network icon, once, so they end up in
  # this order. Applets in a panel zone are ordered by their position number,
  # so the ones after it move up.
  for uuid in ram@dotfiles gpaste-reloaded@feuerfuchs.eu; do
    applets="$(gsettings get org.cinnamon enabled-applets)"
    if [[ $applets == *"$uuid"* ]]; then
      continue
    fi
    # Cinnamon reads the GSettings schemas once, when it starts, and aborts
    # when an applet asks for one it has not seen. GPaste's comes with the
    # gpaste package, so a Cinnamon started before that has to restart first.
    if [[ $uuid == gpaste-reloaded@feuerfuchs.eu ]]; then
      cinnamon_pid="$(pgrep -xo cinnamon || true)"
      if ! gsettings list-schemas | grep -qx org.gnome.GPaste; then
        printf 'GPaste is not installed; not adding its applet to the panel.\n'
        continue
      elif [[ -n $cinnamon_pid ]] && (( $(stat -c %Y /usr/share/glib-2.0/schemas/gschemas.compiled) \
        > $(printf '%(%s)T' -1) - $(ps -o etimes= -p "$cinnamon_pid") )); then
        printf 'Cinnamon started before GPaste was installed; log out and back in, then run this again to add its applet.\n'
        continue
      fi
    fi
    printf 'Adding %s to the panel...\n' "$uuid"
    gsettings set org.cinnamon enabled-applets "$(python3 -I -c '
import ast, sys
applets = ast.literal_eval(sys.argv[1].removeprefix("@as "))
ids = [int(a.rsplit(":", 1)[1]) for a in applets]
right = sorted((int(a.split(":")[2]), a) for a in applets if a.split(":")[:2] == ["panel1", "right"])
at = next((pos for pos, a in right if ":network@" in a), max((pos for pos, _ in right), default=-1) + 1)
moved = {a: f"panel1:right:{pos + 1}:" + a.split(":", 3)[3] for pos, a in right if pos >= at}
result = [moved.get(a, a) for a in applets]
result.append(f"panel1:right:{at}:{sys.argv[2]}:{max(ids, default=0) + 1}")
print(result)
' "$applets" "$uuid")"
  done

  # GPaste Reloaded opens its history with Super+H, which snaps windows left
  # here. The window list takes Super+1-9 and Super+Shift+1-9 for its apps and
  # the sound applet Super+Shift+S, which the workspace and screenshot keys use.
  set_applet_setting gpaste-reloaded@feuerfuchs.eu kb-show-history '"<Super><Shift>v"'
  set_applet_setting grouped-window-list@cinnamon.org super-num-hotkeys false
  set_applet_setting sound@cinnamon.org keyOpen '""'
}

configure_gnome_terminal() {
  if [[ -n ${DOTFILES_TARGET_HOME:-} ]] || ! command -v gnome-terminal >/dev/null 2>&1 \
    || ! command -v dconf >/dev/null 2>&1; then
    return
  fi

  dconf dump /org/gnome/terminal/ > "${backup_root}/gnome-terminal.dconf"
  printf 'Applying the GNOME Terminal profile...\n'
  dconf load /org/gnome/terminal/ < "${repo_root}/gnome-terminal/profile.dconf"
}

reload_session() {
  if ((skip_reload)); then
    return
  fi

  if [[ -n ${SWAYSOCK:-} ]] && command -v swaymsg >/dev/null 2>&1; then
    swaymsg reload >/dev/null
    # Sway runs exec lines only at login. A running Quickshell reloads its
    # files by itself, but it can reload while they are half copied, so it is
    # restarted instead.
    if command -v quickshell >/dev/null 2>&1; then
      quickshell kill >/dev/null 2>&1 || true
      swaymsg exec quickshell >/dev/null
    fi
  fi
  if command -v tmux >/dev/null 2>&1 && tmux list-sessions >/dev/null 2>&1; then
    tmux source-file "${config_root}/tmux/tmux.conf"
  fi
}

if ((!files_only)); then
  install_packages
  "${repo_root}/scripts/check-editor-deps"
  install_nvidia_if_needed
  install_nerd_font
  install_oh_my_zsh
fi

install_dotfiles
configure_cinnamon
configure_gnome_terminal

if ((!files_only)); then
  configure_session
  configure_appearance
fi

reload_session

printf '\nDone. Your previous configuration is in:\n  %s\n' "$backup_root"
printf 'Log out and select Sway from the login screen.\n'

if ((!files_only && !skip_nvidia)) && command -v mokutil >/dev/null 2>&1 \
  && mokutil --sb-state 2>/dev/null | grep -qi enabled; then
  printf '\nSecure Boot is enabled. If the NVIDIA module does not load after reboot,\n'
  printf 'enroll the akmods signing certificate as described in README.md.\n'
fi
