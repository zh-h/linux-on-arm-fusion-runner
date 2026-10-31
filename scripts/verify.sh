#!/usr/bin/env bash
# Smoke checks for the local FEX + Proton + umu + Fusion setup.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=env.sh
source "$SCRIPT_DIR/env.sh"

fail=0
check() {
  local name="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "PASS  $name"
  else
    echo "FAIL  $name"
    fail=1
  fi
}

echo "== host =="
echo "arch:        $(uname -m)"
echo "page size:   $(getconf PAGESIZE)"
echo "glibc:       $(getconf GNU_LIBC_VERSION)"
check "4K page size" test "$(getconf PAGESIZE)" = "4096"
check "/dev/dri/renderD128" test -e /dev/dri/renderD128

echo "== FEX =="
check "FEX binary" test -x "$FEX_BIN"
if [[ -x "$FEX_HOME/test/busybox" ]]; then
  out="$(fex_run "$FEX_HOME/test/busybox" echo ok 2>/dev/null || true)"
  if [[ "$out" == "ok" ]]; then echo "PASS  FEX x86_64 emulation"; else echo "FAIL  FEX x86_64 emulation ($out)"; fail=1; fi
else
  echo "SKIP  FEX smoke test (busybox missing)"
fi

echo "== GE-Proton =="
check "proton script" test -x "$PROTONPATH/proton"
check "toolmanifest.vdf" test -f "$PROTONPATH/toolmanifest.vdf"
check "FEX PE DLLs" test -d "$PROTONPATH/files/lib/wine/aarch64-windows"
check "FEX unixlib" test -d "$PROTONPATH/files/lib/wine/aarch64-unix"

echo "== umu =="
check "umu-run" test -x "$UMU_RUN"
"$UMU_RUN" --version 2>/dev/null || true
check "steamrt4-arm64 installed" test -x "$UMU_FOLDERS_PATH/umu/steamrt4-arm64/_v2-entry-point"

echo "== Fusion =="
check "Wine prefix" test -d "$WINE_PFX"
check "streamer payload" test -f "$FUSION_DIR/installer/client-downloader/streamer.exe"
dep="$(find "$WINE_PFX/drive_c" -type f -name FusionLauncher.exe -printf '%h\n' 2>/dev/null | head -n1)"
if [[ -n "$dep" ]]; then
  echo "PASS  deployment: $dep"
else
  echo "INFO  Fusion not installed yet"
fi

echo "== display =="
"$SCRIPT_DIR/set-wine-dpi.sh" --print 2>/dev/null || echo "scale detection failed"

echo "== proxy =="
echo "install proxy: ${FUSION_INSTALL_PROXY:-<disabled>}"
echo "runtime proxy: ${FUSION_PROXY:-<disabled>}"

exit "$fail"
