#!/usr/bin/env bash
# Download/install Fusion 360 via Autodesk's 64-bit streamer inside GE-Proton.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=env.sh
source "$SCRIPT_DIR/env.sh"
install_proxy_env

PAYLOAD_DIR="$FUSION_DIR/installer/client-downloader"
SOURCE_EXE="$FUSION_DIR/imports/Fusion 360 Client Downloader.exe"
LEGACY_EXE="$FUSION_DIR/Fusion 360 Client Downloader.exe"
if [[ ! -f "$SOURCE_EXE" && -f "$LEGACY_EXE" ]]; then
  SOURCE_EXE="$LEGACY_EXE"
fi
STREAMER_ARGS=(
  -a 73e72ada57b7480280f7a6f4a289729f
  -s production
  -c https://dl.appstreaming.autodesk.com/production/
)

if [[ ! -f "$SOURCE_EXE" ]]; then
  echo "ERROR: installer not found: $FUSION_DIR/imports/Fusion 360 Client Downloader.exe" >&2
  echo "       Put the Autodesk Windows installer there and retry." >&2
  exit 1
fi

mkdir -p "$PAYLOAD_DIR"
if [[ ! -f "$PAYLOAD_DIR/streamer.exe" ]]; then
  echo "extracting installer payload into $PAYLOAD_DIR"
  7z x -y -o"$PAYLOAD_DIR" "$SOURCE_EXE" >/dev/null
fi

echo "--- streamer architecture (expect PE32+ x86-64) ---"
file "$PAYLOAD_DIR/streamer.exe"

echo "--- configuring Wine DPI (desktop scale detection) ---"
if [[ ! -d "$WINE_PFX" ]]; then
  # Create the prefix first so the installer GUI starts with the right DPI.
  "$UMU_RUN" reg.exe query 'HKCU\Software\Wine' >/dev/null 2>&1 || true
fi
"$SCRIPT_DIR/set-wine-dpi.sh" || echo "WARNING: could not set Wine DPI (see above)" >&2
"$SCRIPT_DIR/set-wine-overrides.sh" || echo "WARNING: could not apply Wine overrides (see above)" >&2

launcher_installed() {
  local roots=("$WINE_PFX/drive_c/Program Files/Autodesk/webdeploy/production")
  local u
  for u in "$WINE_PFX"/drive_c/users/*; do
    [[ -d "$u" ]] || continue
    roots+=("$u/AppData/Local/Autodesk/webdeploy/production")
  done
  local r
  for r in "${roots[@]}"; do
    [[ -d "$r" ]] || continue
    if find "$r" -maxdepth 2 -type f -name FusionLauncher.exe -print -quit 2>/dev/null | grep -q .; then
      return 0
    fi
  done
  return 1
}

install_launcher_when_ready() {
  local i
  for i in $(seq 1 720); do
    if launcher_installed; then
      "$SCRIPT_DIR/install-launcher.sh" || true
      return 0
    fi
    sleep 5
  done
  return 1
}

echo "--- waiting to register the application launcher entry ---"
install_launcher_when_ready &
LAUNCHER_WATCH_PID=$!

echo "--- starting umu + GE-Proton + Autodesk streamer ---"
echo "    (first run downloads the arm64 Steam Runtime; then the Autodesk GUI appears)"
cd "$PAYLOAD_DIR"
set +e
"$UMU_RUN" "$PAYLOAD_DIR/streamer.exe" "${STREAMER_ARGS[@]}" 2>&1 | tee "$FUSION_DIR/logs/install-fusion.log"
rc=${PIPESTATUS[0]}
set -e

if [[ -n "${LAUNCHER_WATCH_PID:-}" ]]; then
  kill "$LAUNCHER_WATCH_PID" 2>/dev/null || true
  wait "$LAUNCHER_WATCH_PID" 2>/dev/null || true
fi
if launcher_installed; then
  "$SCRIPT_DIR/install-launcher.sh" || true
fi

echo "--- configuring Wine proxy for runtime (best effort) ---"
if [[ -n "${FUSION_PROXY:-}" ]]; then
  "$SCRIPT_DIR/set-wine-proxy.sh" "$FUSION_PROXY" || echo "WARNING: could not set Wine proxy (see above)" >&2
else
  "$SCRIPT_DIR/set-wine-proxy.sh" --disable || echo "WARNING: could not disable Wine proxy (see above)" >&2
fi

if [[ $rc -ne 0 ]]; then
  echo "streamer exited with status $rc; see logs/install-fusion.log" >&2
  exit "$rc"
fi

echo "--- installed deployments ---"
DEPLOY_ROOT="$WINE_PFX/drive_c/users/steamuser/AppData/Local/Autodesk/webdeploy/production"
if [[ -d "$DEPLOY_ROOT" ]]; then
  for d in "$DEPLOY_ROOT"/*/; do
    printf '%s  Fusion360=%s FusionLauncher=%s\n' \
      "$(basename "$d")" \
      "$([[ -f "$d/Fusion360.exe" ]] && echo y || echo n)" \
      "$([[ -f "$d/FusionLauncher.exe" ]] && echo y || echo n)"
  done
else
  echo "no deployment directory yet: $DEPLOY_ROOT" >&2
fi

echo "Next: scripts/run-fusion.sh"
