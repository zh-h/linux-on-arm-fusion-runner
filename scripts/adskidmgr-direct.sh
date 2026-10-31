#!/usr/bin/env bash
# Autodesk sign-in callback (adskidmgr://) handler.
# Must use GE-Proton's own wine, sharing WINEPREFIX/wineserver with Fusion.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=env.sh
source "$SCRIPT_DIR/env.sh"
runtime_proxy_env

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <adskidmgr-url>" >&2
  exit 2
fi

IDM="$(find "$WINE_PFX/drive_c" -iname 'AdskIdentityManager.exe' -print 2>/dev/null | sort | head -n1)"
if [[ -z "$IDM" ]]; then
  echo "ERROR: AdskIdentityManager.exe not found under $WINE_PFX" >&2
  exit 1
fi

export WINEPREFIX="$WINE_PFX"
exec "$PROTONPATH/files/bin/wine" "$IDM" "$1"
