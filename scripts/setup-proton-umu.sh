#!/usr/bin/env bash
# Install GE-Proton 11-11 (aarch64) and umu-launcher 1.4.4 (zipapp) into the project.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=env.sh
source "$SCRIPT_DIR/env.sh"
install_proxy_env

PROTON_DIR="$FUSION_DIR/proton"
PROTON_TAG="GE-Proton11-11"
PROTON_ASSET="${PROTON_TAG}-aarch64.tar.gz"
PROTON_SUM="${PROTON_TAG}-aarch64.sha512sum"
PROTON_REL="https://github.com/GloriousEggroll/proton-ge-custom/releases/download/${PROTON_TAG}"

UMU_TAG="1.4.4"
UMU_ASSET="umu-launcher-${UMU_TAG}-zipapp.tar"
UMU_URL="https://github.com/Open-Wine-Components/umu-launcher/releases/download/${UMU_TAG}/${UMU_ASSET}"

mkdir -p "$PROTON_DIR" "$FUSION_DIR/umu" "$FUSION_DIR/umu-data" "$FUSION_DIR/logs"

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

# --- GE-Proton --------------------------------------------------------------
download "$PROTON_REL/$PROTON_SUM" "$PROTON_DIR/$PROTON_SUM"
if [[ ! -s "$PROTON_DIR/$PROTON_ASSET" ]]; then
  download "$PROTON_REL/$PROTON_ASSET" "$PROTON_DIR/$PROTON_ASSET"
fi

echo "--- verifying GE-Proton archive ---"
if ! (cd "$PROTON_DIR" && sha512sum -c "$PROTON_SUM"); then
  echo "checksum mismatch, removing archive and retrying" >&2
  rm -f "$PROTON_DIR/$PROTON_ASSET"
  download "$PROTON_REL/$PROTON_ASSET" "$PROTON_DIR/$PROTON_ASSET"
  (cd "$PROTON_DIR" && sha512sum -c "$PROTON_SUM")
fi

if [[ ! -d "$PROTON_DIR/$PROTON_TAG" ]]; then
  # aarch64 release tarballs unpack as GE-ProtonXX-YY-aarch64/.
  if [[ -d "$PROTON_DIR/${PROTON_TAG}-aarch64" ]]; then
    mv "$PROTON_DIR/${PROTON_TAG}-aarch64" "$PROTON_DIR/$PROTON_TAG"
  else
    echo "extracting $PROTON_ASSET"
    tar -xzf "$PROTON_DIR/$PROTON_ASSET" -C "$PROTON_DIR"
    if [[ -d "$PROTON_DIR/${PROTON_TAG}-aarch64" ]]; then
      mv "$PROTON_DIR/${PROTON_TAG}-aarch64" "$PROTON_DIR/$PROTON_TAG"
    fi
  fi
fi
chmod +x "$PROTON_DIR/$PROTON_TAG/proton"

# --- umu-launcher zipapp ----------------------------------------------------
UMU_TAR="$FUSION_DIR/umu/$UMU_ASSET"
if [[ ! -s "$UMU_TAR" ]]; then
  download "$UMU_URL" "$UMU_TAR"
fi
if [[ ! -s "$FUSION_DIR/umu/umu-run" ]]; then
  rm -rf "$FUSION_DIR/umu/.extract"
  mkdir -p "$FUSION_DIR/umu/.extract"
  tar -xf "$UMU_TAR" -C "$FUSION_DIR/umu/.extract" --strip-components=1
  install -m755 "$FUSION_DIR/umu/.extract/umu-run" "$FUSION_DIR/umu/umu-run"
  ln -sf umu-run "$FUSION_DIR/umu/umu_run.py"
  rm -rf "$FUSION_DIR/umu/.extract"
fi
test -s "$FUSION_DIR/umu/umu-run"

echo "--- layout checks ---"
test -f "$PROTON_DIR/$PROTON_TAG/toolmanifest.vdf"
test -e "$PROTON_DIR/$PROTON_TAG/files/bin"
test -d "$PROTON_DIR/$PROTON_TAG/files/lib/wine/aarch64-windows"
test -d "$PROTON_DIR/$PROTON_TAG/files/lib/wine/aarch64-unix"
"$PROTON_DIR/$PROTON_TAG/proton" --version 2>/dev/null | head -n 2 || true

echo "--- umu version ---"
"$FUSION_DIR/umu/umu-run" --version

echo "GE-Proton: $PROTON_DIR/$PROTON_TAG"
echo "umu-run:   $FUSION_DIR/umu/umu-run"
