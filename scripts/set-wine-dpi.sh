#!/usr/bin/env bash
# Detect the desktop scale and configure Wine's DPI to match.
#
# Detection order:
#   1. FUSION_WINE_DPI          explicit DPI (e.g. 192)
#   2. FUSION_SCALE_PERCENT     explicit percent (e.g. 200, 150)
#   3. KDE kwinoutputconfig.json  (Scale from the display configuration)
#   4. kscreen-doctor -o          (Scale: N)
#   5. Xft.dpi from the X server  (dpi / 96 * 100)
#   6. 100%
#
# Usage:
#   set-wine-dpi.sh           detect and write the registry
#   set-wine-dpi.sh --print   only print "scale=...% dpi=..."
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=env.sh
source "$SCRIPT_DIR/env.sh"

detect_percent() {
  if [[ -n "${FUSION_SCALE_PERCENT:-}" ]]; then
    printf '%s\n' "$FUSION_SCALE_PERCENT"
    return 0
  fi

  local scale
  scale="$(python3 - <<'PY' 2>/dev/null || true
import json, os, pathlib
cfg = pathlib.Path(os.environ.get("XDG_CONFIG_HOME", pathlib.Path.home() / ".config")) / "kwinoutputconfig.json"
try:
    data = json.loads(cfg.read_text())
except Exception:
    raise SystemExit(1)
scales = []
for section in data:
    if section.get("name") == "outputs":
        for out in section.get("data", []):
            value = out.get("scale")
            if isinstance(value, (int, float)) and value > 0:
                scales.append(float(value))
if not scales:
    raise SystemExit(1)
print(max(scales))
PY
)"
  if [[ -n "$scale" ]]; then
    python3 -c 'import sys; print(round(float(sys.argv[1]) * 100))' "$scale"
    return 0
  fi

  if command -v kscreen-doctor >/dev/null 2>&1; then
    scale="$(kscreen-doctor -o 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | awk '/Scale:/ {print $2; exit}')"
    if [[ -n "$scale" ]]; then
      python3 -c 'import sys; print(round(float(sys.argv[1]) * 100))' "$scale"
      return 0
    fi
  fi

  if command -v xrdb >/dev/null 2>&1; then
    local dpi
    dpi="$(xrdb -query 2>/dev/null | awk '/Xft\.dpi/ {print $2; exit}')"
    if [[ -n "$dpi" ]]; then
      python3 -c 'import sys; print(round(float(sys.argv[1]) / 96 * 100))' "$dpi"
      return 0
    fi
  fi

  echo 100
}

if [[ -n "${FUSION_WINE_DPI:-}" ]]; then
  DPI="$(python3 -c 'import sys; print(max(96, min(480, int(float(sys.argv[1])))))' "$FUSION_WINE_DPI")"
  PERCENT="$(python3 -c 'import sys; print(round(int(sys.argv[1]) / 96 * 100))' "$DPI")"
else
  PERCENT="$(detect_percent)"
  DPI="$(python3 -c 'import sys; print(max(96, min(480, round(96 * float(sys.argv[1]) / 100))))' "$PERCENT")"
fi

if [[ "${1:-}" == "--print" ]]; then
  echo "scale=${PERCENT}% dpi=${DPI}"
  exit 0
fi

KEY_DESKTOP='HKCU\Control Panel\Desktop'
KEY_FONTS='HKCU\Software\Wine\Fonts'

run_reg() {
  # Use GE-Proton's wine directly (same prefix/wineserver, no second container).
  # Only fall back to umu when the prefix or wine binary is not available yet.
  if [[ -x "$PROTONPATH/files/bin/wine" && -d "$WINE_PFX" ]]; then
    WINEPREFIX="$WINE_PFX" "$PROTONPATH/files/bin/wine" reg "$@"
  else
    "$UMU_RUN" reg.exe "$@"
  fi
}

run_reg add "$KEY_FONTS" /v LogPixels /t REG_DWORD /d "$DPI" /f
run_reg add "$KEY_DESKTOP" /v LogPixels /t REG_DWORD /d "$DPI" /f
run_reg add "$KEY_DESKTOP" /v Win8DpiScaling /t REG_DWORD /d 1 /f

echo "Wine DPI set to ${DPI} (desktop scale ${PERCENT}%)"
