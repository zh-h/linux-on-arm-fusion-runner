#!/usr/bin/env bash
# Configure Wine's WinINet proxy.
#   set-wine-proxy.sh [URL]       enable with URL (default: FUSION_INSTALL_PROXY)
#   set-wine-proxy.sh --disable   disable proxy for Wine/Proton apps
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=env.sh
source "$SCRIPT_DIR/env.sh"

ENABLE=1
URL="${FUSION_INSTALL_PROXY:-}"
case "${1:-}" in
  --disable) ENABLE=0 ;;
  --enable) ;;
  "") ;;
  *) URL="$1" ;;
esac

HOSTPORT="${URL#*://}"
HOSTPORT="${HOSTPORT%/}"
[[ -n "$HOSTPORT" ]] || ENABLE=0

KEY='HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings'

run_reg() {
  # Use GE-Proton's wine directly (same prefix/wineserver, no second container).
  # Only fall back to umu when the prefix or wine binary is not available yet.
  if [[ -x "$PROTONPATH/files/bin/wine" && -d "$WINE_PFX" ]]; then
    WINEPREFIX="$WINE_PFX" "$PROTONPATH/files/bin/wine" reg "$@"
  else
    "$UMU_RUN" reg.exe "$@"
  fi
}

run_reg add "$KEY" /v ProxyEnable /t REG_DWORD /d "$ENABLE" /f
if [[ "$ENABLE" -eq 1 ]]; then
  run_reg add "$KEY" /v ProxyServer /t REG_SZ /d "$HOSTPORT" /f
  run_reg add "$KEY" /v ProxyOverride /t REG_SZ /d '<local>' /f
fi

echo "Wine proxy: enable=$ENABLE server=${HOSTPORT:-none}"
