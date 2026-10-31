#!/usr/bin/env bash
# Install FEX-Emu 2610 (armv8.2, ubuntu resolute arm64) into ./fex without apt.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=env.sh
source "$SCRIPT_DIR/env.sh"
install_proxy_env

FEX_DIR="$FUSION_DIR/fex"
DEB_HOST="https://launchpad.net/~fex-emu/+archive/ubuntu/fex/+files"
DEB_MAIN="fex-emu-armv8.2_2610-1~r_arm64.deb"
DEB_WINE="fex-emu-wine_2610-1~r_arm64.deb"

mkdir -p "$FEX_DIR"/{debs,root,wine,config/fex-emu,data,cache,test}

download() {
  local url="$1" out="$2"
  if [[ -s "$out" ]]; then
    echo "exists: $out"
    return 0
  fi
  echo "download: $url"
  curl -L --fail --retry 5 --connect-timeout 20 -o "$out.part" "$url"
  mv "$out.part" "$out"
}

download "$DEB_HOST/$DEB_MAIN" "$FEX_DIR/debs/$DEB_MAIN"
download "$DEB_HOST/$DEB_WINE" "$FEX_DIR/debs/$DEB_WINE"
(cd "$FEX_DIR/debs" && sha256sum ./*.deb > SHA256SUMS && cat SHA256SUMS)

if [[ ! -x "$FEX_DIR/root/usr/bin/FEX" ]]; then
  echo "extracting $DEB_MAIN"
  dpkg-deb -x "$FEX_DIR/debs/$DEB_MAIN" "$FEX_DIR/root"
fi
if [[ ! -e "$FEX_DIR/wine/usr/lib/wine/aarch64-unix/libwow64fex.so" ]]; then
  echo "extracting $DEB_WINE"
  dpkg-deb -x "$FEX_DIR/debs/$DEB_WINE" "$FEX_DIR/wine"
fi

cat > "$FEX_DIR/config/fex-emu/Config.json" <<'JSON'
{
  "Config": {
    "ProfileStats": "1",
    "X87ReducedPrecision": "1",
    "TSOEnabled": "1",
    "VectorTSOEnabled": "0",
    "MemcpySetTSOEnabled": "0",
    "HalfBarrierTSOEnabled": "1",
    "MaxInst": "500",
    "Multiblock": "1"
  }
}
JSON

if [[ ! -x "$FEX_DIR/test/busybox" ]]; then
  echo "download: x86_64 static busybox (FEX smoke test)"
  curl -L --fail --retry 5 --connect-timeout 20 \
    -o "$FEX_DIR/test/busybox" \
    "https://busybox.net/downloads/binaries/1.35.0-x86_64-linux-musl/busybox"
  chmod +x "$FEX_DIR/test/busybox"
fi

echo "--- FEX smoke test (expect: ok) ---"
fex_run "$FEX_DIR/test/busybox" echo ok
echo "FEX installed under $FEX_DIR"
