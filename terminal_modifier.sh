#!/usr/bin/env bash
set -Eeuo pipefail

# ------------------------------------------------------------
# Script:  terminal_modifier.sh
# Author:  Dickson Massawe (archnexus707)
#
# Goal:
#   Make the local terminal look like JaKooLit's Debian-Hyprland terminal:
#     - JetBrainsMono Nerd Font
#     - zsh + Oh My Zsh + agnosterzak theme
#     - zsh-autosuggestions + zsh-syntax-highlighting
#     - lsd icon aliases
#     - fastfetch (compact config) on shell start
#     - XFCE terminal palette (Tokyo Night by default) + transparency + font
#
#   No wallpapers, no Pokemon, no p10k, no extra MOTD.
# ------------------------------------------------------------

# ========================= Args =========================
NO_COLOR="${ARCHNEXUS_NO_COLOR:-0}"
NO_SPINNER="${ARCHNEXUS_NO_SPINNER:-0}"
VERBOSE="${ARCHNEXUS_VERBOSE:-0}"
SCHEME="tokyonight"
SET_DEFAULT_SHELL="${ARCHNEXUS_CHSH:-0}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-color) NO_COLOR=1; shift ;;
    --no-spinner) NO_SPINNER=1; shift ;;
    --verbose) VERBOSE=1; shift ;;
    --scheme) SCHEME="${2:-tokyonight}"; shift 2 2>/dev/null || shift ;;
    --chsh) SET_DEFAULT_SHELL=1; shift ;;
    *) shift ;;
  esac
done

# ========================= Color =========================
supports_color() {
  [[ -t 1 ]] && command -v tput >/dev/null 2>&1 && [[ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]]
}
if [[ "$NO_COLOR" == "1" ]] || ! supports_color; then
  BOLD=""; DIM=""; RESET=""
  RED=""; GREEN=""; YELLOW=""; BLUE=""; MAGENTA=""; CYAN=""; WHITE=""
else
  BOLD="$(tput bold)"; DIM="$(tput dim)"; RESET="$(tput sgr0)"
  RED="$(tput setaf 1)"; GREEN="$(tput setaf 2)"; YELLOW="$(tput setaf 3)"
  BLUE="$(tput setaf 4)"; MAGENTA="$(tput setaf 5)"; CYAN="$(tput setaf 6)"
  WHITE="$(tput setaf 7)"
fi

# ========================= UI helpers =========================
STEP=0
START_TS="$(date +%s)"
LOG_DIR="${HOME}/.cache/archnexus_terminal_modifier"
mkdir -p "$LOG_DIR"

banner() {
  echo
  echo "${MAGENTA}${BOLD}   █████╗ ██████╗  ██████╗██╗  ██╗███╗   ██╗███████╗██╗  ██╗██╗   ██╗███████╗${RESET}"
  echo "${MAGENTA}${BOLD}  ██╔══██╗██╔══██╗██╔════╝██║  ██║████╗  ██║██╔════╝╚██╗██╔╝██║   ██║██╔════╝${RESET}"
  echo "${MAGENTA}${BOLD}  ███████║██████╔╝██║     ███████║██╔██╗ ██║█████╗   ╚███╔╝ ██║   ██║███████╗${RESET}"
  echo "${MAGENTA}${BOLD}  ██╔══██║██╔══██╗██║     ██╔══██║██║╚██╗██║██╔══╝   ██╔██╗ ██║   ██║╚════██║${RESET}"
  echo "${MAGENTA}${BOLD}  ██║  ██║██║  ██║╚██████╗██║  ██║██║ ╚████║███████╗██╔╝ ██╗╚██████╔╝███████║${RESET}"
  echo "${MAGENTA}${BOLD}  ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝${RESET}"
  echo "${CYAN}${BOLD}      Debian-Hyprland-style terminal: zsh + agnosterzak + JetBrainsMono NF${RESET}"
  echo "${DIM}      Author: Dickson Massawe (archnexus707)${RESET}"
  echo
  echo "${DIM}Scheme:${RESET} ${WHITE}${SCHEME}${RESET}   ${DIM}(--scheme tokyonight|catppuccin|dracula|gruvbox|none)${RESET}"
  echo "${DIM}Flags:${RESET}  ${WHITE}--verbose --no-color --no-spinner --chsh${RESET}"
  echo
}

section() { echo; echo "${BLUE}${BOLD}==> $*${RESET}"; }
step() { STEP=$((STEP+1)); echo "${CYAN}${BOLD}[$STEP]${RESET} ${BOLD}$*${RESET}"; }
ok()   { echo "   ${GREEN}${BOLD}OK $*${RESET}"; }
warn() { echo "   ${YELLOW}${BOLD}!! $*${RESET}"; }
fail() { echo "   ${RED}${BOLD}XX $*${RESET}"; }

need_cmd() { command -v "$1" >/dev/null 2>&1; }

SPIN_FRAMES=( "|" "/" "-" "\\" )
spinner() {
  local pid="$1" msg="$2" i=0
  [[ "$NO_SPINNER" == "1" ]] && return 0
  [[ ! -t 1 ]] && return 0
  while kill -0 "$pid" 2>/dev/null; do
    printf "\r   ${MAGENTA}${BOLD}%s${RESET} %s ${DIM}(working...)${RESET}" "${SPIN_FRAMES[$i]}" "$msg"
    i=$(( (i+1) % ${#SPIN_FRAMES[@]} ))
    sleep 0.1
  done
  printf "\r   %s\r" "                                                                                "
}

run_cmd() {
  local desc="$1"; shift
  local logfile="${LOG_DIR}/$(date +%Y%m%d-%H%M%S)-step${STEP}.log"
  step "$desc"

  if [[ "$VERBOSE" == "1" ]]; then
    if "$@" 2>&1 | tee "$logfile"; then
      ok "$desc"; return 0
    else
      fail "$desc"
      echo "   ${DIM}Log:${RESET} ${WHITE}${logfile}${RESET}"
      tail -n 40 "$logfile" || true
      return 1
    fi
  else
    ( "$@" >"$logfile" 2>&1 ) &
    local pid=$!
    spinner "$pid" "$desc"
    if wait "$pid"; then
      ok "$desc"; return 0
    else
      fail "$desc"
      echo "   ${DIM}Log:${RESET} ${WHITE}${logfile}${RESET}"
      tail -n 40 "$logfile" || true
      return 1
    fi
  fi
}

on_err() {
  local exit_code=$?
  echo
  fail "Script failed (exit ${exit_code}). Logs: ${WHITE}${LOG_DIR}${RESET}"
  exit "$exit_code"
}
trap on_err ERR

require_sudo() {
  step "Requesting sudo permission (needed for installs)"
  sudo -v
  ok "Sudo authorized"
}

# ========================= Paths =========================
FASTFETCH_DIR="${HOME}/.config/fastfetch"
TERMRC_DIR="${HOME}/.config/xfce4/terminal"
TERMRC_FILE="${TERMRC_DIR}/terminalrc"
FONT_DIR="${HOME}/.local/share/fonts/JetBrainsMonoNerd"
OMZ_DIR="${HOME}/.oh-my-zsh"
ZSH_CUSTOM_PLUGINS="${OMZ_DIR}/custom/plugins"
ZSH_CUSTOM_THEMES="${OMZ_DIR}/custom/themes"

# ========================= Terminal schemes =========================
scheme_palette() {
  local name="$1"
  case "$name" in
    tokyonight|tokyo|tokyo-night)
      PALETTE=(
        "#15161e" "#f7768e" "#9ece6a" "#e0af68"
        "#7aa2f7" "#bb9af7" "#7dcfff" "#a9b1d6"
        "#414868" "#f7768e" "#9ece6a" "#e0af68"
        "#7aa2f7" "#bb9af7" "#7dcfff" "#c0caf5"
      )
      FG="#c0caf5"; BG="#1a1b26"; CURSOR="#c0caf5"
      ;;
    dracula)
      PALETTE=(
        "#21222c" "#ff5555" "#50fa7b" "#f1fa8c"
        "#bd93f9" "#ff79c6" "#8be9fd" "#f8f8f2"
        "#6272a4" "#ff6e6e" "#69ff94" "#ffffa5"
        "#d6acff" "#ff92df" "#a4ffff" "#ffffff"
      )
      FG="#f8f8f2"; BG="#282a36"; CURSOR="#f8f8f2"
      ;;
    gruvbox)
      PALETTE=(
        "#282828" "#cc241d" "#98971a" "#d79921"
        "#458588" "#b16286" "#689d6a" "#a89984"
        "#928374" "#fb4934" "#b8bb26" "#fabd2f"
        "#83a598" "#d3869b" "#8ec07c" "#ebdbb2"
      )
      FG="#ebdbb2"; BG="#282828"; CURSOR="#ebdbb2"
      ;;
    catppuccin|catppuccin-mocha|mocha)
      PALETTE=(
        "#45475a" "#f38ba8" "#a6e3a1" "#f9e2af"
        "#89b4fa" "#f5c2e7" "#94e2d5" "#bac2de"
        "#585b70" "#f38ba8" "#a6e3a1" "#f9e2af"
        "#89b4fa" "#f5c2e7" "#94e2d5" "#a6adc8"
      )
      FG="#cdd6f4"; BG="#1e1e2e"; CURSOR="#f5e0dc"
      ;;
    none)
      PALETTE=(); FG=""; BG=""; CURSOR=""
      ;;
    *)
      warn "Unknown scheme '${name}', using tokyonight."
      scheme_palette "tokyonight"
      ;;
  esac
}

apply_scheme_xfconf() {
  local name="$1"
  scheme_palette "$name"
  [[ "$name" == "none" ]] && return 0

  xfconf-query -c xfce4-terminal -p /color-use-theme  -t bool   -s false --create >/dev/null 2>&1 || true
  xfconf-query -c xfce4-terminal -p /color-use-system -t bool   -s false --create >/dev/null 2>&1 || true
  xfconf-query -c xfce4-terminal -p /color-background -t string -s "$BG"  --create >/dev/null 2>&1 || true
  xfconf-query -c xfce4-terminal -p /color-foreground -t string -s "$FG"  --create >/dev/null 2>&1 || true
  xfconf-query -c xfce4-terminal -p /color-cursor     -t string -s "$CURSOR" --create >/dev/null 2>&1 || true

  # An xfconf array needs a -t/-s pair per element; a single -t with many -s
  # values is rejected ("N new values, but only 1 types could be determined")
  # and the palette silently never applies.
  local xfconf_palette=()
  local color
  for color in "${PALETTE[@]}"; do
    xfconf_palette+=( -t string -s "$color" )
  done
  xfconf-query -c xfce4-terminal -p /color-palette -a --create \
    "${xfconf_palette[@]}" >/dev/null 2>&1 || true
}

apply_scheme_terminalrc() {
  local name="$1"
  scheme_palette "$name"
  [[ "$name" == "none" ]] && return 0

  mkdir -p "$TERMRC_DIR"
  [[ -f "$TERMRC_FILE" ]] || echo "[Configuration]" > "$TERMRC_FILE"
  local palette_joined; palette_joined="$(IFS=';'; echo "${PALETTE[*]}")"

  grep -q '^ColorPalette=' "$TERMRC_FILE" \
    && sed -i "s|^ColorPalette=.*|ColorPalette=${palette_joined}|" "$TERMRC_FILE" \
    || echo "ColorPalette=${palette_joined}" >> "$TERMRC_FILE"

  grep -q '^ColorForeground=' "$TERMRC_FILE" \
    && sed -i "s|^ColorForeground=.*|ColorForeground=${FG}|" "$TERMRC_FILE" \
    || echo "ColorForeground=${FG}" >> "$TERMRC_FILE"

  grep -q '^ColorBackground=' "$TERMRC_FILE" \
    && sed -i "s|^ColorBackground=.*|ColorBackground=${BG}|" "$TERMRC_FILE" \
    || echo "ColorBackground=${BG}" >> "$TERMRC_FILE"

  grep -q '^ColorCursor=' "$TERMRC_FILE" \
    && sed -i "s|^ColorCursor=.*|ColorCursor=${CURSOR}|" "$TERMRC_FILE" \
    || echo "ColorCursor=${CURSOR}" >> "$TERMRC_FILE"
}

git_clone_or_update() {
  local repo="$1" dest="$2"
  if [[ -d "$dest/.git" ]]; then
    run_cmd "Updating $(basename "$dest")" git -C "$dest" pull --ff-only
  else
    run_cmd "Cloning $(basename "$dest")" git clone --depth 1 "$repo" "$dest"
  fi
}

# ========================= Install steps =========================
apt_install() {
  require_sudo
  section "Packages (apt)"

  run_cmd "Updating apt package lists" sudo apt-get update -y

  local required_pkgs=(
    git curl ca-certificates unzip xz-utils
    xfconf xfce4-terminal
    zsh fontconfig lsd
  )
  run_cmd "Installing required packages" \
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${required_pkgs[@]}"

  section "Optional packages"
  for pkg in fastfetch fonts-firacode fonts-font-awesome fonts-noto fonts-noto-color-emoji; do
    step "Installing optional: ${pkg}"
    if sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg" >/dev/null 2>&1; then
      ok "Installed: ${pkg}"
    else
      warn "Skipped (not available): ${pkg}"
    fi
  done
}

install_oh_my_zsh() {
  section "Oh My Zsh"
  if [[ -d "$OMZ_DIR" ]]; then
    ok "Oh My Zsh already present"
    return 0
  fi
  run_cmd "Installing Oh My Zsh (unattended, no chsh)" bash -lc \
    'RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"'
}

install_zsh_plugins() {
  section "Zsh plugins"
  mkdir -p "$ZSH_CUSTOM_PLUGINS"
  git_clone_or_update "https://github.com/zsh-users/zsh-autosuggestions" \
    "${ZSH_CUSTOM_PLUGINS}/zsh-autosuggestions"
  git_clone_or_update "https://github.com/zsh-users/zsh-syntax-highlighting.git" \
    "${ZSH_CUSTOM_PLUGINS}/zsh-syntax-highlighting"
}

install_agnosterzak_theme() {
  section "agnosterzak theme (Debian-Hyprland)"
  mkdir -p "$ZSH_CUSTOM_THEMES"
  run_cmd "Downloading agnosterzak.zsh-theme" curl -fsSL \
    "https://raw.githubusercontent.com/JaKooLit/Debian-Hyprland/main/assets/add_zsh_theme/agnosterzak.zsh-theme" \
    -o "${ZSH_CUSTOM_THEMES}/agnosterzak.zsh-theme"
}

install_jetbrains_nerd_font() {
  section "Nerd Font (JetBrainsMono)"
  if fc-list | grep -qi 'JetBrainsMono Nerd Font'; then
    ok "JetBrainsMono Nerd Font already installed"
    return 0
  fi

  mkdir -p "$FONT_DIR"
  local tmp; tmp="$(mktemp -d)"
  run_cmd "Downloading JetBrainsMono Nerd Font" curl -fsSL \
    "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz" \
    -o "${tmp}/JetBrainsMono.tar.xz"
  run_cmd "Extracting JetBrainsMono Nerd Font" tar -xJf "${tmp}/JetBrainsMono.tar.xz" -C "$FONT_DIR"
  rm -rf "$tmp" || true
  run_cmd "Refreshing font cache (fc-cache)" fc-cache -f "$HOME/.local/share/fonts" || true
}

install_fastfetch_config() {
  section "Fastfetch compact config"
  if ! need_cmd fastfetch; then
    warn "fastfetch is not installed; skipping config download"
    return 0
  fi
  mkdir -p "$FASTFETCH_DIR"
  run_cmd "Downloading config-compact.jsonc" curl -fsSL \
    "https://raw.githubusercontent.com/JaKooLit/Hyprland-Dots/main/config/fastfetch/config-compact.jsonc" \
    -o "${FASTFETCH_DIR}/config-compact.jsonc"
}

write_zshrc() {
  section "Writing Debian-Hyprland-style ~/.zshrc"
  local zshrc="${HOME}/.zshrc"
  if [[ -f "$zshrc" ]]; then
    run_cmd "Backing up existing ~/.zshrc" bash -lc \
      "cp -a '$zshrc' '${zshrc}.bak.$(date +%s)'"
  fi

  cat > "$zshrc" <<'EOF'
# Managed by terminal_modifier.sh — Debian-Hyprland style
# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="agnosterzak"

plugins=(
    git
    zsh-autosuggestions
    zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh

# fastfetch greeting (compact)
if command -v fastfetch >/dev/null 2>&1 && [ -f "$HOME/.config/fastfetch/config-compact.jsonc" ]; then
    fastfetch -c "$HOME/.config/fastfetch/config-compact.jsonc"
fi

# Set-up icons for files/directories in terminal using lsd
if command -v lsd >/dev/null 2>&1; then
    alias ls='lsd'
    alias l='ls -l'
    alias la='ls -a'
    alias lla='ls -la'
    alias lt='ls --tree'
fi
EOF
  ok "Wrote ~/.zshrc (agnosterzak + plugins + fastfetch + lsd)"
}

tweak_xfce_terminal() {
  section "XFCE terminal look (scheme + transparency + JetBrainsMono NF)"
  if ! need_cmd xfce4-terminal; then
    warn "xfce4-terminal not found; skipping"
    return 0
  fi

  if [[ "$SCHEME" != "none" ]]; then
    if need_cmd xfconf-query && xfconf-query -c xfce4-terminal -l >/dev/null 2>&1; then
      run_cmd "Applying terminal scheme '${SCHEME}' via xfconf" bash -lc \
        "$(declare -f scheme_palette apply_scheme_xfconf); apply_scheme_xfconf '$SCHEME'"
    else
      run_cmd "Applying terminal scheme '${SCHEME}' via terminalrc" bash -lc \
        "$(declare -f scheme_palette apply_scheme_terminalrc); apply_scheme_terminalrc '$SCHEME'"
    fi
  else
    ok "Skipping scheme (scheme=none)"
  fi

  if need_cmd xfconf-query && xfconf-query -c xfce4-terminal -l >/dev/null 2>&1; then
    run_cmd "Setting transparency + JetBrainsMono NF (xfconf)" bash -lc \
      'xfconf-query -c xfce4-terminal -p /background-mode -t string -s TERMINAL_BACKGROUND_TRANSPARENT --create >/dev/null 2>&1 || true;
       xfconf-query -c xfce4-terminal -p /background-darkness -t double -s 0.85 --create >/dev/null 2>&1 || true;
       xfconf-query -c xfce4-terminal -p /font-use-system -t bool -s false --create >/dev/null 2>&1 || true;
       xfconf-query -c xfce4-terminal -p /font-name -t string -s "JetBrainsMono Nerd Font 11" --create >/dev/null 2>&1 || true'
  else
    mkdir -p "$TERMRC_DIR"
    [[ -f "$TERMRC_FILE" ]] || echo "[Configuration]" > "$TERMRC_FILE"
    run_cmd "Setting transparency + JetBrainsMono NF (terminalrc)" bash -lc \
      "grep -q '^BackgroundMode=' '$TERMRC_FILE' && sed -i 's/^BackgroundMode=.*/BackgroundMode=TERMINAL_BACKGROUND_TRANSPARENT/' '$TERMRC_FILE' || echo 'BackgroundMode=TERMINAL_BACKGROUND_TRANSPARENT' >> '$TERMRC_FILE';
       grep -q '^BackgroundDarkness=' '$TERMRC_FILE' && sed -i 's/^BackgroundDarkness=.*/BackgroundDarkness=0.850000/' '$TERMRC_FILE' || echo 'BackgroundDarkness=0.850000' >> '$TERMRC_FILE';
       grep -q '^FontName=' '$TERMRC_FILE' && sed -i 's/^FontName=.*/FontName=JetBrainsMono Nerd Font 11/' '$TERMRC_FILE' || echo 'FontName=JetBrainsMono Nerd Font 11' >> '$TERMRC_FILE'"
  fi

  echo "   ${DIM}Tip:${RESET} For real transparency: XFCE Settings -> Window Manager Tweaks -> Compositor."
}

set_default_shell_zsh() {
  [[ "$SET_DEFAULT_SHELL" != "1" ]] && return 0
  section "Default shell"
  local current_shell; current_shell="$(basename "${SHELL:-}")"
  if [[ "$current_shell" == "zsh" ]]; then
    ok "zsh is already the default shell"
    return 0
  fi
  if ! need_cmd zsh; then
    warn "zsh not found; cannot chsh"
    return 0
  fi
  step "Changing default shell to zsh"
  if chsh -s "$(command -v zsh)"; then
    ok "Default shell changed to zsh (re-login to take effect)"
  else
    warn "chsh failed; run 'chsh -s \"\$(command -v zsh)\"' manually"
  fi
}

main() {
  banner

  [[ "${EUID}" -eq 0 ]] && { fail "Run this as your normal user (not root)."; exit 1; }
  need_cmd apt-get || { fail "This script targets Debian/Ubuntu (apt-get not found)."; exit 1; }

  section "System checks"
  ok "User: ${BOLD}${USER}${RESET}"
  ok "Logs: ${BOLD}${LOG_DIR}${RESET}"

  apt_install
  install_oh_my_zsh
  install_zsh_plugins
  install_agnosterzak_theme
  install_jetbrains_nerd_font
  install_fastfetch_config
  write_zshrc
  tweak_xfce_terminal
  set_default_shell_zsh

  section "Finished"
  local end_ts elapsed
  end_ts="$(date +%s)"
  elapsed="$((end_ts - START_TS))"

  echo "${GREEN}${BOLD}Done. Open a NEW terminal window to see the new look.${RESET}"
  echo
  echo "${CYAN}${BOLD}Notes:${RESET}"
  echo "  * If colors look wrong in xfce4-terminal, log out/in once (xfconf cache)."
  echo "  * If the prompt glyphs render as boxes, set the terminal font to"
  echo "    ${BOLD}JetBrainsMono Nerd Font${RESET} explicitly."
  echo "  * Run with ${BOLD}--chsh${RESET} (or ARCHNEXUS_CHSH=1) to also make zsh your default shell."
  echo
  echo "${DIM}Elapsed:${RESET} ${BOLD}${elapsed}s${RESET}"
  echo
}

main "$@"
