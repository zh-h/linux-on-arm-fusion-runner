#!/usr/bin/env bash
# Create (or remove) the KDE application launcher entry for Fusion 360.
#
#   install-launcher.sh           create/refresh the entry
#   install-launcher.sh --remove  remove the entry
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=env.sh
source "$SCRIPT_DIR/env.sh"

APPS_DIR="$HOME/.local/share/applications"
DESKTOP_FILE="$APPS_DIR/autodesk-fusion360.desktop"
ICON_DIR="$FUSION_DIR/icons"
ICON_PNG="$ICON_DIR/autodesk-fusion360.png"
ICON_ICO_SRC="$FUSION_DIR/installer/client-downloader/resources/autodesk.ico"

refresh_menu() {
  update-desktop-database "$APPS_DIR" >/dev/null 2>&1 || true
  if command -v kbuildsycoca6 >/dev/null 2>&1; then
    kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
  fi
}

if [[ "${1:-}" == "--remove" ]]; then
  rm -f "$DESKTOP_FILE"
  refresh_menu
  echo "removed application launcher: $DESKTOP_FILE"
  exit 0
fi
if [[ $# -gt 0 ]]; then
  echo "usage: $0 [--remove]" >&2
  exit 2
fi

mkdir -p "$APPS_DIR" "$ICON_DIR"

# Prefer a PNG (KDE renders it reliably). The Autodesk ICO contains a
# 96x96 32bpp image; convert the largest frame with Pillow when available.
ICON_VALUE="applications-engineering"
if [[ ! -s "$ICON_PNG" && -f "$ICON_ICO_SRC" ]]; then
  if python3 - "$ICON_ICO_SRC" "$ICON_PNG" >/dev/null 2>&1 <<'PY'
import sys
from PIL import Image

src, dst = sys.argv[1], sys.argv[2]
im = Image.open(src)
sizes = getattr(im, "sizes", None)
if callable(sizes):
    try:
        candidates = list(sizes())
    except Exception:
        candidates = []
    if candidates:
        best = max(candidates, key=lambda s: s[0] * s[1])
        if hasattr(im, "getimage"):
            im = im.getimage(best)
im = im.convert("RGBA")
im.save(dst, "PNG")
PY
  then
    :
  fi
fi

if [[ -s "$ICON_PNG" ]]; then
  ICON_VALUE="$ICON_PNG"
elif [[ -f "$ICON_ICO_SRC" ]]; then
  cp -f "$ICON_ICO_SRC" "$ICON_DIR/autodesk-fusion360.ico"
  ICON_VALUE="$ICON_DIR/autodesk-fusion360.ico"
fi

cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=Autodesk Fusion 360
GenericName=3D CAD
Comment=Autodesk Fusion 360 via local GE-Proton/FEX
Exec="$FUSION_DIR/scripts/run-fusion.sh"
Icon=$ICON_VALUE
Terminal=false
Categories=Graphics;Engineering;3DGraphics;
Keywords=Autodesk;Fusion;CAD;3D;
StartupNotify=true
StartupWMClass=steam_app_default
EOF
chmod 644 "$DESKTOP_FILE"

if command -v desktop-file-validate >/dev/null 2>&1; then
  desktop-file-validate "$DESKTOP_FILE" || true
fi
refresh_menu

echo "created application launcher: $DESKTOP_FILE"
echo "icon: $ICON_VALUE"
echo "Search for 'Fusion' in the KDE application launcher."
