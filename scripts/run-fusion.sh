#!/usr/bin/env bash
# Launch Autodesk Fusion 360 through umu + GE-Proton (aarch64/FEX).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=env.sh
source "$SCRIPT_DIR/env.sh"

# Desktop launches have no terminal; keep a log so failures are diagnosable.
mkdir -p "$FUSION_DIR/logs"
if [[ ! -t 1 ]]; then
  exec >>"$FUSION_DIR/logs/run-fusion.log" 2>&1
  echo "=== $(date -Is) run-fusion ==="
fi

# One launch at a time, even for rapid double-clicks.
LOCK_FILE="$FUSION_DIR/cache/run-fusion.lock"
mkdir -p "$(dirname "$LOCK_FILE")"
if command -v flock >/dev/null 2>&1; then
  exec 9>"$LOCK_FILE"
  if ! flock -n 9; then
    echo "Fusion 360 is already starting or running."
    exit 0
  fi
fi

WINUSER="$(find "$WINE_PFX/drive_c/users" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null \
  | grep -vE '^(Public|Default|defaultuser0|All Users)$' | head -n1 || true)"
WINUSER="${WINUSER:-steamuser}"

find_deployment() {
  local roots=(
    "$WINE_PFX/drive_c/users/$WINUSER/AppData/Local/Autodesk/webdeploy/production"
    "$WINE_PFX/drive_c/Program Files/Autodesk/webdeploy/production"
  )
  local r d
  for r in "${roots[@]}"; do
    [[ -d "$r" ]] || continue
    while IFS= read -r d; do
      if [[ -f "$d/FusionLauncher.exe" && -f "$d/Fusion360.exe" ]]; then
        printf '%s\n' "$d"
        return 0
      fi
    done < <(find "$r" -mindepth 1 -maxdepth 1 -type d -printf '%T@ %p\n' 2>/dev/null \
      | sort -nr | cut -d' ' -f2-)
  done
  # Fallback: versioned payload folders can live elsewhere in the prefix.
  while IFS= read -r d; do
    if [[ -f "$d/FusionLauncher.exe" ]]; then
      printf '%s\n' "$d"
      return 0
    fi
  done < <(find "$WINE_PFX/drive_c" -type f -name Fusion360.exe -printf '%T@ %h\n' 2>/dev/null \
    | sort -nr | cut -d' ' -f2-)
  return 1
}

LAUNCHER_DIR="$(find_deployment || true)"
if [[ -z "$LAUNCHER_DIR" || ! -f "$LAUNCHER_DIR/FusionLauncher.exe" ]]; then
  echo "ERROR: FusionLauncher.exe not found in: $WINE_PFX" >&2
  echo "       Run scripts/install-fusion.sh first." >&2
  exit 1
fi
LAUNCHER="$LAUNCHER_DIR/FusionLauncher.exe"

# FusionLauncher.exe looks for FusionLauncher.exe.ini next to itself.
if [[ ! -f "$LAUNCHER_DIR/FusionLauncher.exe.ini" ]]; then
  echo "generating FusionLauncher.exe.ini in $LAUNCHER_DIR"
  python3 - "$LAUNCHER_DIR" "$WINUSER" <<'PY'
import sys
from pathlib import Path

deploy_dir = Path(sys.argv[1])
user = sys.argv[2]
name = deploy_dir.name
target = f'""C:\\users\\{user}\\AppData\\Local\\Autodesk\\webdeploy\\production\\{name}\\Fusion360.exe""'
content = (
    "[Launcher]\r\n"
    "stream = production\r\n"
    "auid = AutodeskInc.Fusion360\r\n"
    f"cmd = {target}\r\n"
    "global = False\r\n\r\n"
)
(deploy_dir / "FusionLauncher.exe.ini").write_bytes(content.encode("utf-16"))
PY
fi

purge_idsdk_locks() {
  find "$WINE_PFX/drive_c/ProgramData/Autodesk/IDSDK" \
    -path '*/interprocess/01000000/*.lock' -delete 2>/dev/null || true
}

purge_idsdk_locks

if pgrep -f 'FusionLauncher\.exe|Fusion360\.exe' >/dev/null 2>&1; then
  echo "Fusion 360 is already running. Not starting a second instance." >&2
  exit 0
fi

# No Fusion window is running. Clear any stale umu/Proton container from an
# earlier session; otherwise it keeps pfx.lock and blocks this launch.
pkill -f "$UMU_RUN" 2>/dev/null || true
if [[ -x "$PROTONPATH/files/bin/wineserver" && -d "$WINE_PFX" ]]; then
  WINEPREFIX="$WINE_PFX" "$PROTONPATH/files/bin/wineserver" -k >/dev/null 2>&1 || true
fi

# Runtime proxy is opt-in only (FUSION_PROXY). By default Fusion goes direct.
runtime_proxy_env
if [[ -n "${FUSION_PROXY:-}" ]]; then
  "$SCRIPT_DIR/set-wine-proxy.sh" "$FUSION_PROXY" >/dev/null 2>&1 || true
else
  "$SCRIPT_DIR/set-wine-proxy.sh" --disable >/dev/null 2>&1 || true
fi

# Match Wine's DPI to the desktop scale (KDE/kwinoutput, kscreen, Xft.dpi).
"$SCRIPT_DIR/set-wine-dpi.sh" >/dev/null 2>&1 || \
  echo "WARNING: could not set Wine DPI" >&2

# Disable Autodesk's analytics service to shorten shutdown.
"$SCRIPT_DIR/set-wine-overrides.sh" >/dev/null 2>&1 || \
  echo "WARNING: could not apply Wine overrides" >&2

export WINEPREFIX PROTONPATH UMU_FOLDERS_PATH GAMEID
export QT_D3D_NO_FLIP=1
export WINEDLLOVERRIDES="bcp47langs=,icuuc=n"
export PROTON_USE_XALIA=0
export DXVK_LOG_LEVEL="${DXVK_LOG_LEVEL:-none}"
export WINEDEBUG="${WINEDEBUG:--all}"
unset EGL_PLATFORM GDK_BACKEND QT_WAYLAND_RECONNECT 2>/dev/null || true

fusion_window_present() {
  local w n c
  for w in $(xprop -root _NET_CLIENT_LIST 2>/dev/null | grep -oE '0x[0-9a-f]+'); do
    n=$(xprop -id "$w" _NET_WM_NAME 2>/dev/null)
    case "$n" in *Autodesk\ Fusion*|*Fusion360*) return 0 ;; esac
    c=$(xprop -id "$w" WM_CLASS 2>/dev/null)
    case "$c" in *steam_app_default*) return 0 ;; esac
  done
  return 1
}

HAVE_XPROP=0
if [[ -n "${DISPLAY:-}" ]] && command -v xprop >/dev/null 2>&1; then
  HAVE_XPROP=1
fi

# Fast teardown: stop umu, pressure-vessel, Proton/wineserver, and Wine services.
stop_container() {
  if [[ -n "${UMU_PID:-}" ]]; then
    kill -TERM "$UMU_PID" 2>/dev/null || true
    local i
    for i in 1 2 3 4 5; do
      kill -0 "$UMU_PID" 2>/dev/null || break
      sleep 0.2
    done
    kill -KILL "$UMU_PID" 2>/dev/null || true
  fi
  pkill -TERM -f "$PROTONPATH" 2>/dev/null || true
  pkill -TERM -f "$UMU_FOLDERS_PATH/umu/umu-shim" 2>/dev/null || true
  if [[ -x "$PROTONPATH/files/bin/wineserver" && -d "$WINE_PFX" ]]; then
    timeout 5 env WINEPREFIX="$WINE_PFX" "$PROTONPATH/files/bin/wineserver" -k \
      >/dev/null 2>&1 || true
  fi
  sleep 0.5
  pkill -KILL -f "$PROTONPATH" 2>/dev/null || true
  pkill -KILL -f "$UMU_FOLDERS_PATH/umu/umu-shim" 2>/dev/null || true
  purge_idsdk_locks
}

cleanup() { stop_container; }
trap cleanup EXIT
trap 'cleanup; exit 143' TERM
trap 'cleanup; exit 130' INT

echo "launching: $LAUNCHER"
"$UMU_RUN" "$LAUNCHER" "$@" 9>&- &
UMU_PID=$!

# Keep the container only while Fusion is alive. Fusion360.exe normally exits
# on close; if the Wine process/services linger under FEX, a window-gone timer
# forces a fast teardown so pfx.lock is released for the next launch.
SEEN_FUSION=0
WINDOW_GONE_SECONDS=0
START_SECONDS=$SECONDS
CLOSE_GRACE="${FUSION_CLOSE_GRACE:-5}"
[[ "$CLOSE_GRACE" =~ ^[0-9]+$ ]] || CLOSE_GRACE=5
while kill -0 "$UMU_PID" 2>/dev/null; do
  if pgrep -f 'Fusion360\.exe' >/dev/null 2>&1; then
    SEEN_FUSION=1
  elif [[ "$SEEN_FUSION" -eq 1 ]]; then
    echo "$(date -Is) Fusion process exited; cleaning up."
    break
  fi

  if [[ "$SEEN_FUSION" -eq 1 && "$HAVE_XPROP" -eq 1 && \
        $((SECONDS - START_SECONDS)) -gt 120 ]]; then
    if fusion_window_present; then
      WINDOW_GONE_SECONDS=0
    else
      WINDOW_GONE_SECONDS=$((WINDOW_GONE_SECONDS + 1))
      if [[ "$WINDOW_GONE_SECONDS" -ge "$CLOSE_GRACE" ]]; then
        echo "$(date -Is) Fusion window closed; cleaning up now."
        break
      fi
    fi
  fi

  if [[ "$SEEN_FUSION" -eq 0 && $((SECONDS - START_SECONDS)) -gt 600 ]]; then
    echo "Timed out waiting for Fusion to start." >&2
    break
  fi
  sleep 1
done

stop_container
wait "$UMU_PID" 2>/dev/null || true
