# imports/

`scripts/install-fusion.sh` 会自动把 Autodesk 的 Windows 安装器下载到这里：

```
imports/Fusion Client Downloader.exe
```

如自动下载失败，可手动放入同名文件。

安装脚本不会执行它的 32 位 SFX 外壳：用 `7z` 解包后直接运行其中的 64 位
`streamer.exe`。
