# linux-on-arm-fusion-runner

Everything (FEX, GE-Proton, umu, Steam Runtime, Wine prefix) lives inside this
directory. No PPA/apt/Steam installation is used.

## Layout

| Path | Purpose |
|---|---|
| `fex/` | FEX-Emu 2610 armv8.2, extracted from the Ubuntu 26.04 PPA .deb |
| `proton/GE-Proton11-11/` | GE-Proton aarch64 (ARM64X Wine with bundled FEX) |
| `umu/umu-run` | umu-launcher 1.4.4 zipapp |
| `umu-data/` | Steam Linux Runtime 4 (arm64) and umu state |
| `prefix/` | WINEPREFIX where Fusion is installed |
| `installer/client-downloader/` | 7z-extracted Autodesk streamer (untrusted payload) |
| `cache/`, `logs/` | caches and logs |
| `imports/` | Autodesk installer input (gitignored) |
| `scripts/` | setup / install / launch / verify / uninstall helpers |

Put Autodesk's Windows installer at
`imports/Fusion 360 Client Downloader.exe`. It is ignored by git and kept
untouched. Its 32-bit SFX shell is not executed: the payload is extracted with
`7z`, and the 64-bit `streamer.exe` inside is run directly, avoiding 32-bit x86
emulation.

## Quick start

```bash
./scripts/setup-fex.sh            # local FEX + x86-64 smoke test
./scripts/setup-proton-umu.sh     # GE-Proton 11-11 aarch64 + umu 1.4.4
./scripts/install-fusion.sh       # Autodesk GUI: download/install Fusion
./scripts/install-desktop-handler.sh   # adskidmgr:// sign-in callback
./scripts/run-fusion.sh           # launch Fusion
./scripts/verify.sh               # checks
```

The Autodesk sign-in callback is handled by
`scripts/adskidmgr-direct.sh`, which runs `AdskIdentityManager.exe` with
GE-Proton's own `wine` in the same prefix (the umu path is known to break the
callback).

## Notes

- Installation scripts use `FUSION_INSTALL_PROXY` (default
  `http://192.168.10.233:1081`; set it empty to disable).
- `run-fusion.sh` and the sign-in callback use **no proxy** by default; export
  `FUSION_PROXY=http://host:port` to opt in (this also updates the Wine registry).
- If the Autodesk downloader cannot reach the network during installation, run
  `./scripts/set-wine-proxy.sh` first (enables the WinINet proxy using
  `FUSION_INSTALL_PROXY`).
- During installation the streamer window (`Autodesk 应用程序流`) stays open and
  auto-launches Fusion. Both run in the same umu container, so closing the
  streamer window may also close Fusion; relaunch with `scripts/run-fusion.sh`.
- DPI: the install and launch scripts detect the desktop scale from KDE
  (`kwinoutputconfig.json`), `kscreen-doctor`, or `Xft.dpi`, and set Wine's
  `LogPixels` / `Win8DpiScaling` accordingly (2x scale → 192 DPI). Override with
  `FUSION_SCALE_PERCENT=200` or `FUSION_WINE_DPI=192`; `--print` shows the
  detected values.
- Application launcher: `install-fusion.sh` creates
  `~/.local/share/applications/autodesk-fusion360.desktop` as soon as the Fusion
  payload appears. Recreate it with `./scripts/install-launcher.sh`; remove it
  with `--remove`. `uninstall.sh` always removes this entry (both modes), and
  `--purge` also deletes the project `icons/` directory.
- Closing: after the Fusion window disappears, `run-fusion.sh` waits
  `FUSION_CLOSE_GRACE` seconds (default 5) and then force-stops umu/Proton/Wine,
  so `pfx.lock` is released quickly. Raise it if you need more time for a save
  dialog (`FUSION_CLOSE_GRACE=10`).
- Shutdown speed: `adpclientservice.exe` (Autodesk analytics/telemetry) is
  disabled through a Wine DLL override, which removes a background service from
  the shutdown path. Sign-in/licensing is unaffected. Restore it by deleting the
  value under `HKCU\Software\Wine\DllOverrides`.
- Do not launch `Fusion360.exe` directly; use `FusionLauncher.exe` via
  `scripts/run-fusion.sh` (`QT_D3D_NO_FLIP=1` is required).
- Do not apply old `Qt6WebEngineCore.dll` patches: they are ABI-incompatible
  with current Fusion builds and crash at startup.
- Global writes are limited to the `adsk://` / `adskidmgr://` desktop handler.
  `scripts/uninstall.sh` removes it and, by default, deletes all local installs
  (`fex/ proton/ umu/ umu-data/ prefix/ cache/ installer/ icons/ logs/`). Use
  `scripts/uninstall.sh --keep` to keep the local installs.
- Git: only `README.md`, `scripts/`, `imports/README.md` and `.gitignore` are
  tracked. The installer (`imports/*.exe`), downloaded runtimes, generated
  payload, icons, logs and the Wine prefix are ignored.
