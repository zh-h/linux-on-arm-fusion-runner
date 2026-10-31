#!/usr/bin/env bash
# Remove the desktop integrations and, by default, all local installs.
#
# usage: uninstall.sh [--keep]
#   (default) delete fex/ proton/ umu/ umu-data/ prefix/ cache/ installer/ icons/ logs/
#   --keep    keep local installs
# Both modes remove the adsk:// / adskidmgr:// handler and the Fusion application
# launcher entry.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=env.sh
source "$SCRIPT_DIR/env.sh"

MODE="purge"
case "${1:-}" in
  ""|--purge) MODE="purge" ;;
  --keep) MODE="keep" ;;
  -h|--help)
    echo "usage: $0 [--keep]"
    echo "  default: delete local downloads + Wine prefix"
    echo "  --keep : remove the desktop handler only"
    exit 0 ;;
  *) echo "unknown option: $1" >&2; exit 2 ;;
esac

APPS_DIR="$HOME/.local/share/applications"
DESKTOP_FILE="$APPS_DIR/fusion360-adskidmgr.desktop"
FUSION_DESKTOP="$APPS_DIR/autodesk-fusion360.desktop"
MIMEAPPS="$HOME/.config/mimeapps.list"

# --- remove the sign-in URI handler ----------------------------------------
rm -f "$DESKTOP_FILE"
if [[ -f "$MIMEAPPS" ]]; then
  sed -i '/fusion360-adskidmgr\.desktop/d' "$MIMEAPPS"
fi

# --- remove the Fusion application launcher entry (required on uninstall) ---
if [[ -x "$SCRIPT_DIR/install-launcher.sh" ]]; then
  "$SCRIPT_DIR/install-launcher.sh" --remove >/dev/null 2>&1 || rm -f "$FUSION_DESKTOP"
else
  rm -f "$FUSION_DESKTOP"
fi

update-desktop-database "$APPS_DIR" >/dev/null 2>&1 || true
if command -v kbuildsycoca6 >/dev/null 2>&1; then
  kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
fi
echo "removed desktop handler: $DESKTOP_FILE"
echo "removed application launcher: $FUSION_DESKTOP"

if [[ "$MODE" != "purge" ]]; then
  echo "local installs kept (run without --keep to delete them)"
  exit 0
fi

# --- stop Fusion, the installer, and Wine ----------------------------------
echo "stopping Fusion / installer / Wine processes..."
pkill -f 'FusionLauncher\.exe' 2>/dev/null || true
pkill -f 'Fusion360\.exe' 2>/dev/null || true
pkill -f 'AdskIdentityManager\.exe' 2>/dev/null || true
pkill -f 'msedgewebview2\.exe' 2>/dev/null || true
pkill -f "$FUSION_DIR/installer/client-downloader/streamer.exe" 2>/dev/null || true
pkill -f "$FUSION_DIR/umu/umu-run" 2>/dev/null || true
pkill -f "$FUSION_DIR/proton/GE-Proton11-11" 2>/dev/null || true
pkill -f "${UMU_FOLDERS_PATH:-$FUSION_DIR/umu-data}/umu" 2>/dev/null || true

if [[ -x "$PROTONPATH/files/bin/wineserver" && -d "$WINE_PFX" ]]; then
  WINEPREFIX="$WINE_PFX" "$PROTONPATH/files/bin/wineserver" -k >/dev/null 2>&1 || true
fi

# --- delete local installs -------------------------------------------------
rm -rf \
  "$FUSION_DIR/fex" \
  "$FUSION_DIR/proton" \
  "$FUSION_DIR/umu" \
  "$FUSION_DIR/umu-data" \
  "$FUSION_DIR/prefix" \
  "$FUSION_DIR/cache" \
  "$FUSION_DIR/installer" \
  "$FUSION_DIR/icons" \
  "$FUSION_DIR/logs"

echo "deleted: fex/ proton/ umu/ umu-data/ prefix/ cache/ installer/ icons/ logs/"
echo "kept: imports/Fusion Client Downloader.exe, scripts/, README.md, .gitignore"
