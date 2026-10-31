# imports/

Place Autodesk's Windows installer here:

```
imports/Fusion 360 Client Downloader.exe
```

The executable is proprietary and is intentionally ignored by git
(`imports/*.exe`). The setup scripts never execute its 32-bit SFX shell: they
extract it with `7z` and run the 64-bit `streamer.exe` inside.
