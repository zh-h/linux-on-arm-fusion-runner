#!/usr/bin/env bash
# Register the adsk:// and adskidmgr:// URI handlers for the current user.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=env.sh
source "$SCRIPT_DIR/env.sh"

APPS_DIR="$HOME/.local/share/applications"
DESKTOP_FILE="$APPS_DIR/fusion360-adskidmgr.desktop"
mkdir -p "$APPS_DIR"

cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=Fusion 360 Autodesk Callback
Comment=Route Autodesk sign-in callbacks into the local Fusion Proton prefix
Exec=$FUSION_DIR/scripts/adskidmgr-direct.sh %u
Icon=autodesk-fusion360
Terminal=false
NoDisplay=true
MimeType=x-scheme-handler/adsk;x-scheme-handler/adskidmgr;
EOF

update-desktop-database "$APPS_DIR" >/dev/null 2>&1 || true
xdg-mime default fusion360-adskidmgr.desktop x-scheme-handler/adskidmgr 2>/dev/null || true
xdg-mime default fusion360-adskidmgr.desktop x-scheme-handler/adsk 2>/dev/null || true
if command -v kbuildsycoca6 >/dev/null 2>&1; then
  kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
fi

echo "registered: $DESKTOP_FILE"
gio mime x-scheme-handler/adskidmgr 2>/dev/null || true
gio mime x-scheme-handler/adsk 2>/dev/null || true
