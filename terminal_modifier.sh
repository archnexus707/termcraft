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
#     - fastfetch + a random Pokemon side-by-side on shell start
#       (a detailed fastfetch config that reveals lots of PC components)
#     - XFCE terminal palette (Tokyo Night by default) + transparency + font
#
#   No wallpapers, no p10k, no extra MOTD. Pokemon can be turned off with
#   --no-pokemon (or ARCHNEXUS_NO_POKEMON=1).
# ------------------------------------------------------------

# ========================= Args =========================
NO_COLOR="${ARCHNEXUS_NO_COLOR:-0}"
NO_SPINNER="${ARCHNEXUS_NO_SPINNER:-0}"
VERBOSE="${ARCHNEXUS_VERBOSE:-0}"
SCHEME="tokyonight"
SET_DEFAULT_SHELL="${ARCHNEXUS_CHSH:-0}"
SHOW_POKEMON="1"; [[ "${ARCHNEXUS_NO_POKEMON:-0}" == "1" ]] && SHOW_POKEMON="0"
DRY_RUN="${ARCHNEXUS_DRY_RUN:-0}"
ASSUME_YES="${ARCHNEXUS_YES:-0}"
ACTION="install"          # install | uninstall | list-schemes | help
BAD_FLAG=""               # set if an unknown flag was seen

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-color)     NO_COLOR=1; shift ;;
    --no-spinner)   NO_SPINNER=1; shift ;;
    --verbose)      VERBOSE=1; shift ;;
    --scheme)       SCHEME="${2:-tokyonight}"; shift 2 2>/dev/null || shift ;;
    --chsh)         SET_DEFAULT_SHELL=1; shift ;;
    --no-pokemon)   SHOW_POKEMON=0; shift ;;
    --dry-run|-n)   DRY_RUN=1; shift ;;
    --yes|-y)       ASSUME_YES=1; shift ;;
    --uninstall)    ACTION="uninstall"; shift ;;
    --list-schemes) ACTION="list-schemes"; shift ;;
    -h|--help)      ACTION="help"; shift ;;
    *)              BAD_FLAG="$1"; ACTION="help"; shift ;;
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

RESULTS=()   # collected "STATUS<TAB>message" lines for the end-of-run summary

section() { echo; echo "${BLUE}${BOLD}==> $*${RESET}"; }
step() { STEP=$((STEP+1)); echo "${CYAN}${BOLD}[$STEP]${RESET} ${BOLD}$*${RESET}"; }
ok()   { RESULTS+=( "OK"$'\t'"$*" );   echo "   ${GREEN}${BOLD}OK $*${RESET}"; }
warn() { RESULTS+=( "SKIP"$'\t'"$*" ); echo "   ${YELLOW}${BOLD}!! $*${RESET}"; }
fail() { RESULTS+=( "FAIL"$'\t'"$*" ); echo "   ${RED}${BOLD}XX $*${RESET}"; }

need_cmd() { command -v "$1" >/dev/null 2>&1; }

# ---- dry-run helpers ----
is_dry() { [[ "$DRY_RUN" == "1" ]]; }
would()  { echo "   ${MAGENTA}${BOLD}~>${RESET} ${DIM}[dry-run] would $*${RESET}"; RESULTS+=( "PLAN"$'\t'"$*" ); }

# ---- color swatches (truecolor) for scheme previews ----
supports_truecolor() {
  [[ "$NO_COLOR" != "1" ]] && [[ -t 1 ]] && [[ "${COLORTERM:-}" == *truecolor* || "${COLORTERM:-}" == *24bit* ]]
}
hex_to_rgb() { local h="${1#\#}"; printf '%d %d %d' "0x${h:0:2}" "0x${h:2:2}" "0x${h:4:2}"; }
swatch() {
  # Render each hex arg as a colored block; degrade to names if no truecolor.
  local h r g b
  if ! supports_truecolor; then printf '%s ' "$@"; return 0; fi
  for h in "$@"; do
    read -r r g b <<<"$(hex_to_rgb "$h")"
    printf '\e[48;2;%d;%d;%dm  \e[0m' "$r" "$g" "$b"
  done
}

# ---- yes/no confirmation (auto-yes with --yes or on a non-interactive stdin) ----
confirm() {
  local prompt="${1:-Proceed?}" reply
  [[ "$ASSUME_YES" == "1" ]] && return 0
  [[ ! -t 0 ]] && return 0
  printf "%s %s" "${YELLOW}${BOLD}${prompt}${RESET}" "${DIM}[y/N]${RESET} "
  read -r reply
  [[ "$reply" =~ ^[Yy] ]]
}

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

  if is_dry; then
    would "run: $*"
    return 0
  fi

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
  if is_dry; then would "prompt for sudo"; return 0; fi
  sudo -v
  ok "Sudo authorized"
}

# ========================= Paths =========================
FASTFETCH_DIR="${HOME}/.config/fastfetch"
FASTFETCH_CONF="${FASTFETCH_DIR}/config-termcraft.jsonc"
POKE_SRC_DIR="${HOME}/.local/share/pokemon-colorscripts"
TERMRC_DIR="${HOME}/.config/xfce4/terminal"
TERMRC_FILE="${TERMRC_DIR}/terminalrc"
FONT_DIR="${HOME}/.local/share/fonts/JetBrainsMonoNerd"
OMZ_DIR="${HOME}/.oh-my-zsh"
ZSH_CUSTOM_PLUGINS="${OMZ_DIR}/custom/plugins"
ZSH_CUSTOM_THEMES="${OMZ_DIR}/custom/themes"
AGNOSTER_THEME="${ZSH_CUSTOM_THEMES}/agnosterzak.zsh-theme"

ZSHRC="${HOME}/.zshrc"
ZSHRC_BACKUP="${HOME}/.zshrc.termcraft-backup"
BLOCK_START="# >>> termcraft (managed) >>>"
BLOCK_END="# <<< termcraft (managed) <<<"

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
    git curl ca-certificates unzip xz-utils python3
    xfconf xfce4-terminal
    zsh fontconfig lsd
  )
  run_cmd "Installing required packages" \
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${required_pkgs[@]}"

  section "Optional packages"
  for pkg in fastfetch fonts-firacode fonts-font-awesome fonts-noto fonts-noto-color-emoji; do
    step "Installing optional: ${pkg}"
    if is_dry; then
      would "apt-get install ${pkg} (optional)"
      continue
    fi
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
  if is_dry; then would "clone zsh-autosuggestions + zsh-syntax-highlighting"; return 0; fi
  mkdir -p "$ZSH_CUSTOM_PLUGINS"
  git_clone_or_update "https://github.com/zsh-users/zsh-autosuggestions" \
    "${ZSH_CUSTOM_PLUGINS}/zsh-autosuggestions"
  git_clone_or_update "https://github.com/zsh-users/zsh-syntax-highlighting.git" \
    "${ZSH_CUSTOM_PLUGINS}/zsh-syntax-highlighting"
}

install_agnosterzak_theme() {
  section "agnosterzak theme (Debian-Hyprland)"
  if is_dry; then would "download agnosterzak.zsh-theme"; return 0; fi
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
  if is_dry; then would "download + install JetBrainsMono Nerd Font"; return 0; fi

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
  section "Fastfetch config (detailed, Pokemon-ready)"
  if is_dry; then would "write detailed fastfetch config -> ${FASTFETCH_CONF}"; return 0; fi
  if ! need_cmd fastfetch; then
    warn "fastfetch is not installed; skipping config"
    return 0
  fi
  mkdir -p "$FASTFETCH_DIR"
  # A detailed config that surfaces a lot of the machine (CPU, GPU, memory,
  # swap, disk, packages, DE/WM, terminal, local IP, battery, locale). The
  # logo is left as the distro default; the shell greeting overrides it with a
  # piped Pokemon (see the ~/.zshrc block), matching the README screenshot.
  cat > "$FASTFETCH_CONF" <<'JSONC'
{
  "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
  "logo": { "type": "auto", "padding": { "top": 1, "left": 2 } },
  "display": { "separator": " -> " },
  "modules": [
    { "type": "title" },
    "separator",
    { "type": "os",        "key": "  OS" },
    { "type": "host",      "key": "  Host" },
    { "type": "kernel",    "key": "  Kernel" },
    { "type": "uptime",    "key": "  Uptime" },
    { "type": "packages",  "key": "  Packages" },
    { "type": "shell",     "key": "  Shell" },
    { "type": "de",        "key": "  DE" },
    { "type": "wm",        "key": "  WM" },
    { "type": "terminal",  "key": "  Terminal" },
    "break",
    { "type": "cpu",       "key": "  CPU" },
    { "type": "gpu",       "key": "  GPU" },
    { "type": "memory",    "key": "  Memory" },
    { "type": "swap",      "key": "  Swap" },
    { "type": "disk",      "key": "  Disk", "folders": "/" },
    { "type": "localip",   "key": "  Local IP" },
    { "type": "battery",   "key": "  Battery" },
    { "type": "locale",    "key": "  Locale" },
    "break",
    { "type": "colors", "paddingLeft": 2, "symbol": "circle" }
  ]
}
JSONC
  ok "Wrote detailed fastfetch config -> $(basename "$FASTFETCH_CONF")"
}

install_pokemon_colorscripts() {
  [[ "$SHOW_POKEMON" != "1" ]] && return 0
  section "Pokemon colorscripts (fastfetch sidekick)"
  if need_cmd pokemon-colorscripts; then
    ok "pokemon-colorscripts already installed"
    return 0
  fi
  if is_dry; then would "clone + install pokemon-colorscripts to /usr/local (needs sudo)"; return 0; fi
  git_clone_or_update "https://gitlab.com/phoneybadger/pokemon-colorscripts.git" "$POKE_SRC_DIR"
  run_cmd "Installing pokemon-colorscripts (sudo)" bash -lc \
    "cd '$POKE_SRC_DIR' && sudo ./install.sh"
}

# The zsh settings termcraft manages, wrapped in markers so we can update or
# remove them without touching the rest of the user's ~/.zshrc.
termcraft_zshrc_block() {
  cat <<'EOF'
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="agnosterzak"
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)
source $ZSH/oh-my-zsh.sh

# fastfetch greeting with a random Pokemon on the left (JaKooLit style)
if command -v fastfetch >/dev/null 2>&1 && [ -f "$HOME/.config/fastfetch/config-termcraft.jsonc" ]; then
    if command -v pokemon-colorscripts >/dev/null 2>&1; then
        pokemon-colorscripts --no-title -s -r \
            | fastfetch -c "$HOME/.config/fastfetch/config-termcraft.jsonc" \
                        --logo-type file-raw --logo - --logo-padding-top 1 2>/dev/null
    else
        fastfetch -c "$HOME/.config/fastfetch/config-termcraft.jsonc"
    fi
fi

# lsd icon aliases
if command -v lsd >/dev/null 2>&1; then
    alias ls='lsd'
    alias l='ls -l'
    alias la='ls -a'
    alias lla='ls -la'
    alias lt='ls --tree'
fi
EOF
}

write_zshrc() {
  section "Managed ~/.zshrc block (agnosterzak + plugins + fastfetch + lsd)"
  if is_dry; then
    would "inject the termcraft block into ${ZSHRC} (one-time backup -> $(basename "$ZSHRC_BACKUP"))"
    return 0
  fi

  local block; block="$(printf '%s\n%s\n%s\n' "$BLOCK_START" "$(termcraft_zshrc_block)" "$BLOCK_END")"

  if [[ ! -f "$ZSHRC" ]]; then
    { echo "# ~/.zshrc"; echo; printf '%s\n' "$block"; } > "$ZSHRC"
    ok "Created ~/.zshrc with the termcraft block"
    return 0
  fi

  # Back up the original exactly once so re-runs don't stack .bak files.
  if [[ ! -f "$ZSHRC_BACKUP" ]]; then
    cp -a "$ZSHRC" "$ZSHRC_BACKUP"
    ok "Backed up existing ~/.zshrc -> $(basename "$ZSHRC_BACKUP")"
  fi

  if grep -qF "$BLOCK_START" "$ZSHRC"; then
    # Strip the old managed block, then re-append a fresh one (idempotent).
    local tmp; tmp="$(mktemp)"
    awk -v s="$BLOCK_START" -v e="$BLOCK_END" '
      $0==s {skip=1} skip==0 {print} $0==e {skip=0}
    ' "$ZSHRC" > "$tmp"
    { cat "$tmp"; printf '%s\n' "$block"; } > "$ZSHRC"
    rm -f "$tmp"
    ok "Refreshed the termcraft block in ~/.zshrc"
  else
    printf '\n%s\n' "$block" >> "$ZSHRC"
    ok "Appended the termcraft block to ~/.zshrc (existing config preserved)"
  fi
}

tweak_xfce_terminal() {
  section "XFCE terminal look (scheme + transparency + JetBrainsMono NF)"
  if ! need_cmd xfce4-terminal; then
    warn "xfce4-terminal not found; skipping"
    return 0
  fi
  if is_dry; then would "apply ${SCHEME} palette + transparency + JetBrainsMono NF to xfce4-terminal"; return 0; fi

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
  if is_dry; then would "chsh -s $(command -v zsh)"; return 0; fi
  step "Changing default shell to zsh"
  if chsh -s "$(command -v zsh)"; then
    ok "Default shell changed to zsh (re-login to take effect)"
  else
    warn "chsh failed; run 'chsh -s \"\$(command -v zsh)\"' manually"
  fi
}

# ========================= Help / schemes / plan / summary =========================
show_help() {
  cat <<EOF
${BOLD}termcraft${RESET} - forge a Debian-Hyprland-style terminal
(zsh + agnosterzak + JetBrainsMono NF + fastfetch with a Pokemon sidekick)

${BOLD}Usage:${RESET} ./terminal_modifier.sh [OPTIONS]

${BOLD}Options:${RESET}
  --scheme NAME     Color scheme: tokyonight (default), catppuccin, dracula, gruvbox, none
  --chsh            Also set zsh as your default shell
  --no-pokemon      Skip the Pokemon greeting (fastfetch only)
  --dry-run, -n     Show what would happen without changing anything
  --yes, -y         Don't ask for confirmation
  --list-schemes    Preview the available color schemes and exit
  --uninstall       Undo termcraft (restore ~/.zshrc, reset xfce4-terminal)
  --verbose         Stream command output instead of a spinner
  --no-spinner      Disable the spinner animation
  --no-color        Disable colored output
  -h, --help        Show this help and exit

${BOLD}Environment equivalents:${RESET}
  ARCHNEXUS_CHSH=1  ARCHNEXUS_NO_POKEMON=1  ARCHNEXUS_DRY_RUN=1  ARCHNEXUS_YES=1
  ARCHNEXUS_VERBOSE=1  ARCHNEXUS_NO_SPINNER=1  ARCHNEXUS_NO_COLOR=1
EOF
}

do_list_schemes() {
  echo "${BOLD}Available color schemes${RESET}"
  echo
  local s
  for s in tokyonight catppuccin dracula gruvbox; do
    scheme_palette "$s"
    printf "  ${BOLD}%-12s${RESET} " "$s"
    swatch "${PALETTE[@]}"
    echo
  done
  printf "  ${BOLD}%-12s${RESET} ${DIM}(leave terminal colors untouched)${RESET}\n" "none"
  echo
  echo "${DIM}Apply one with:${RESET} --scheme <name>"
}

print_plan() {
  local poke chsh
  poke="$([[ "$SHOW_POKEMON" == "1" ]] && echo on || echo off)"
  chsh="$([[ "$SET_DEFAULT_SHELL" == "1" ]] && echo yes || echo no)"
  echo "${BOLD}Plan${RESET} ${DIM}(scheme: ${SCHEME} | pokemon: ${poke} | set default shell: ${chsh})${RESET}"
  if [[ "$SCHEME" != "none" ]]; then
    scheme_palette "$SCHEME"
    printf "  ${DIM}palette:${RESET} "; swatch "${PALETTE[@]}"; echo
  fi
  echo "  ${CYAN}1.${RESET} apt: zsh, xfce4-terminal, lsd, fontconfig, xz-utils, python3, fonts, ..."
  echo "  ${CYAN}2.${RESET} Oh My Zsh + zsh-autosuggestions + zsh-syntax-highlighting"
  echo "  ${CYAN}3.${RESET} agnosterzak theme + JetBrainsMono Nerd Font"
  echo "  ${CYAN}4.${RESET} detailed fastfetch config$([[ "$SHOW_POKEMON" == "1" ]] && echo " + pokemon-colorscripts")"
  echo "  ${CYAN}5.${RESET} managed ~/.zshrc block (existing config preserved)"
  echo "  ${CYAN}6.${RESET} xfce4-terminal: ${SCHEME} palette + transparency + JetBrainsMono NF"
  [[ "$SET_DEFAULT_SHELL" == "1" ]] && echo "  ${CYAN}7.${RESET} set zsh as the default shell (chsh)"
}

notify_running_terminal() {
  if pgrep -x xfce4-terminal >/dev/null 2>&1; then
    warn "xfce4-terminal is running - close all its windows (or log out/in) for the new colors/font to apply."
  fi
}

print_summary() {
  local okc=0 skipc=0 failc=0 planc=0 line status msg
  for line in "${RESULTS[@]}"; do
    status="${line%%$'\t'*}"
    case "$status" in OK) okc=$((okc+1));; SKIP) skipc=$((skipc+1));; FAIL) failc=$((failc+1));; PLAN) planc=$((planc+1));; esac
  done
  echo
  echo "${BOLD}Summary:${RESET} ${GREEN}${okc} ok${RESET}, ${YELLOW}${skipc} skipped${RESET}, ${RED}${failc} failed${RESET}$([[ $planc -gt 0 ]] && printf ', %s%s planned%s' "$MAGENTA" "$planc" "$RESET")"
  for line in "${RESULTS[@]}"; do
    status="${line%%$'\t'*}"; msg="${line#*$'\t'}"
    case "$status" in
      SKIP) printf "  ${YELLOW}. skipped:${RESET} %s\n" "$msg" ;;
      FAIL) printf "  ${RED}x failed:${RESET} %s\n" "$msg" ;;
    esac
  done
}

do_uninstall() {
  banner
  section "Uninstall termcraft"
  if ! confirm "Remove termcraft's changes (restore ~/.zshrc, reset xfce4-terminal colors)?"; then
    warn "Uninstall cancelled"; return 0
  fi

  # 1) ~/.zshrc: restore the backup if we made one, else strip the managed block.
  if [[ -f "$ZSHRC_BACKUP" ]]; then
    if is_dry; then would "restore ${ZSHRC} from $(basename "$ZSHRC_BACKUP")"
    else cp -a "$ZSHRC_BACKUP" "$ZSHRC" && ok "Restored ~/.zshrc from backup"; fi
  elif [[ -f "$ZSHRC" ]] && grep -qF "$BLOCK_START" "$ZSHRC"; then
    if is_dry; then would "strip termcraft block from ${ZSHRC}"
    else
      local tmp; tmp="$(mktemp)"
      awk -v s="$BLOCK_START" -v e="$BLOCK_END" '$0==s{skip=1} skip==0{print} $0==e{skip=0}' "$ZSHRC" > "$tmp"
      mv "$tmp" "$ZSHRC"; ok "Removed termcraft block from ~/.zshrc"
    fi
  else
    warn "No termcraft ~/.zshrc changes found"
  fi

  # 2) files termcraft created
  local f
  for f in "$FASTFETCH_CONF" "$AGNOSTER_THEME"; do
    [[ -f "$f" ]] || continue
    if is_dry; then would "remove $f"; else rm -f "$f" && ok "Removed $(basename "$f")"; fi
  done

  # 3) reset the xfce4-terminal properties termcraft set
  if need_cmd xfconf-query; then
    local props=(/color-use-theme /color-use-system /color-background /color-foreground
                 /color-cursor /color-palette /background-mode /background-darkness
                 /font-use-system /font-name)
    if is_dry; then would "reset xfconf props: ${props[*]}"
    else
      local p
      for p in "${props[@]}"; do xfconf-query -c xfce4-terminal -p "$p" -r >/dev/null 2>&1 || true; done
      ok "Reset xfce4-terminal colors/font (xfconf)"
    fi
  fi

  echo
  echo "${DIM}Left in place (remove manually if you want):${RESET} Oh My Zsh, zsh plugins,"
  echo "${DIM}JetBrainsMono NF, pokemon-colorscripts, and installed apt packages.${RESET}"
  notify_running_terminal
}

# ========================= Entry point =========================
main() {
  case "$ACTION" in
    help)
      banner
      [[ -n "$BAD_FLAG" ]] && fail "Unknown option: ${BAD_FLAG}"
      show_help
      [[ -n "$BAD_FLAG" ]] && exit 2
      exit 0
      ;;
    list-schemes) banner; do_list_schemes; exit 0 ;;
    uninstall)    do_uninstall; exit 0 ;;
  esac

  banner

  [[ "${EUID}" -eq 0 ]] && { fail "Run this as your normal user (not root)."; exit 1; }
  need_cmd apt-get || { fail "This script targets Debian/Ubuntu (apt-get not found)."; exit 1; }

  print_plan
  echo
  if is_dry; then
    echo "${MAGENTA}${BOLD}Dry run - no changes will be made.${RESET}"
  else
    confirm "Proceed with these changes?" || { warn "Cancelled by user."; exit 0; }
  fi

  section "System checks"
  ok "User: ${BOLD}${USER}${RESET}"
  ok "Logs: ${BOLD}${LOG_DIR}${RESET}"

  apt_install
  install_oh_my_zsh
  install_zsh_plugins
  install_agnosterzak_theme
  install_jetbrains_nerd_font
  install_fastfetch_config
  install_pokemon_colorscripts
  write_zshrc
  tweak_xfce_terminal
  set_default_shell_zsh

  section "Finished"
  local end_ts elapsed
  end_ts="$(date +%s)"
  elapsed="$((end_ts - START_TS))"

  print_summary
  echo
  if is_dry; then
    echo "${MAGENTA}${BOLD}Dry run complete.${RESET} Re-run without --dry-run to apply."
  else
    echo "${GREEN}${BOLD}Done. Open a NEW terminal window to see the new look.${RESET}"
    echo "${CYAN}${BOLD}Notes:${RESET}"
    echo "  * If the prompt glyphs render as boxes, set the terminal font to"
    echo "    ${BOLD}JetBrainsMono Nerd Font${RESET} explicitly."
    echo "  * Run with ${BOLD}--chsh${RESET} to also make zsh your default shell."
    echo "  * Undo everything with ${BOLD}--uninstall${RESET}."
    notify_running_terminal
  fi
  echo
  echo "${DIM}Elapsed:${RESET} ${BOLD}${elapsed}s${RESET}"
  echo
}

main "$@"
