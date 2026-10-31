#!/usr/bin/env bash
# Shared environment for the local (project-contained) Fusion 360 on ARM64 setup.
# Source this file from the other scripts; do not execute it.

FUSION_DIR="${FUSION_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export FUSION_DIR

# Proxy policy:
#   * setup/install scripts use FUSION_INSTALL_PROXY (on by default)
#   * running Fusion uses no proxy unless FUSION_PROXY is explicitly set
export FUSION_INSTALL_PROXY="${FUSION_INSTALL_PROXY-http://192.168.10.233:1081}"

install_proxy_env() {
  if [[ -n "${FUSION_INSTALL_PROXY:-}" ]]; then
    export http_proxy="$FUSION_INSTALL_PROXY" https_proxy="$FUSION_INSTALL_PROXY"
    export HTTP_PROXY="$FUSION_INSTALL_PROXY" HTTPS_PROXY="$FUSION_INSTALL_PROXY"
  else
    unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY
  fi
}

runtime_proxy_env() {
  if [[ -n "${FUSION_PROXY:-}" ]]; then
    export http_proxy="$FUSION_PROXY" https_proxy="$FUSION_PROXY"
    export HTTP_PROXY="$FUSION_PROXY" HTTPS_PROXY="$FUSION_PROXY"
  else
    unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY
  fi
}
export -f install_proxy_env runtime_proxy_env

# All runtime state stays inside the project directory.
export WINEPREFIX="${WINEPREFIX:-$FUSION_DIR/prefix}"
# umu treats WINEPREFIX as a Steam compatdata dir; Proton creates the real
# Wine prefix in WINEPREFIX/pfx.
export WINE_PFX="${WINE_PFX:-$WINEPREFIX/pfx}"
export PROTONPATH="${PROTONPATH:-$FUSION_DIR/proton/GE-Proton11-11}"
export UMU_FOLDERS_PATH="${UMU_FOLDERS_PATH:-$FUSION_DIR/umu-data}"
export GAMEID="${GAMEID:-umu-default}"           # no umu-database entry for Fusion
export UMU_LOG="${UMU_LOG:-1}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$FUSION_DIR/cache}"

export UMU_RUN="${UMU_RUN:-$FUSION_DIR/umu/umu-run}"
export PATH="$FUSION_DIR/umu:$PATH"

# --- FEX (standalone local install, used for verification) -----------------
export FEX_HOME="$FUSION_DIR/fex"
export FEX_BIN="$FEX_HOME/root/usr/bin/FEX"

fex_run() {
  # Run an x86_64 Linux ELF under the locally extracted FEX 2610.
  XDG_CONFIG_HOME="$FEX_HOME/config" \
  XDG_DATA_HOME="$FEX_HOME/data" \
  XDG_CACHE_HOME="$FEX_HOME/cache" \
    "$FEX_BIN" "$@"
}
export -f fex_run
