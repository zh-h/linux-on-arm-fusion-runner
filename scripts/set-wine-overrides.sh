#!/usr/bin/env bash
# Apply Wine DLL overrides used by this setup.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=env.sh
source "$SCRIPT_DIR/env.sh"

KEY='HKCU\Software\Wine\DllOverrides'

run_reg() {
  # Use GE-Proton's wine directly (same prefix/wineserver, no second container).
  if [[ -x "$PROTONPATH/files/bin/wine" && -d "$WINE_PFX" ]]; then
    WINEPREFIX="$WINE_PFX" "$PROTONPATH/files/bin/wine" reg "$@"
  else
    "$UMU_RUN" reg.exe "$@"
  fi
}

# Autodesk's analytics/telemetry service. Disabling it skips a background
# service and shortens Fusion's shutdown path. Licensing/sign-in are handled by
# AdskIdentityManager and are not affected.
run_reg add "$KEY" /v adpclientservice.exe /t REG_SZ /d "" /f

echo "Wine overrides: adpclientservice.exe=disabled"
