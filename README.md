# linux-on-arm-fusion-runner

在 Ubuntu 26.04 ARM64（鲲鹏 920）上运行 Autodesk Fusion 360，采用本地 FEX + Proton
方案。所有组件（FEX、GE-Proton、umu、Steam Runtime、Wine prefix）都放在本目录内，
不使用 PPA/apt/Steam 安装。

## 准备工作

> **安装脚本会自动在线下载 Autodesk 官方的 Windows 安装器，无需手动准备。**

默认下载地址（可用 `FUSION_INSTALLER_URL` 覆盖）：

```text
https://dl.appstreaming.autodesk.com/production/installers/Fusion%20Client%20Downloader.exe
```

脚本将文件保存为 `imports/Fusion Client Downloader.exe` 并直接使用。若自动
下载失败，也可从 Autodesk 官网自行下载同一文件，放到该路径后重新运行。
下载得到的安装器保持原样，不做修改。

## 目录结构

| 路径 | 用途 |
|---|---|
| `fex/` | 从 Ubuntu 26.04 PPA 的 .deb 中提取的 FEX-Emu 2610 armv8.2 |
| `proton/GE-Proton11-11/` | GE-Proton aarch64（内置 FEX 的 ARM64X Wine） |
| `umu/umu-run` | umu-launcher 1.4.4 zipapp |
| `umu-data/` | Steam Linux Runtime 4（arm64）与 umu 状态 |
| `prefix/` | 安装 Fusion 的 WINEPREFIX |
| `installer/client-downloader/` | 7z 解包出的 Autodesk 流程序（不可信载荷） |
| `cache/`、`logs/` | 缓存与日志 |
| `imports/` | Autodesk 官方安装器缓存（脚本自动下载） |
| `scripts/` | 安装 / 部署 / 启动 / 校验 / 卸载脚本 |

不执行安装器的 32 位 SFX 外壳：先用 `7z` 解包，再直接运行其中的 64 位
`streamer.exe`，从而避免 32 位 x86 模拟。

## 快速开始

```bash
./scripts/setup-fex.sh            # 本地 FEX + x86-64 冒烟测试
./scripts/setup-proton-umu.sh     # GE-Proton 11-11 aarch64 + umu 1.4.4
./scripts/install-fusion.sh       # Autodesk 图形界面：下载并安装 Fusion
./scripts/install-desktop-handler.sh   # adskidmgr:// 登录回调
./scripts/run-fusion.sh           # 启动 Fusion
./scripts/verify.sh               # 校验
```

Autodesk 登录回调由 `scripts/adskidmgr-direct.sh` 处理：它在同一个 prefix 中，
用 GE-Proton 自带的 `wine` 运行 `AdskIdentityManager.exe`（已知 umu 路径会破坏
该回调）。

## 备注

### 网络与代理

- 安装脚本（包括自动下载安装器）使用 `FUSION_INSTALL_PROXY`（默认
  `http://192.168.10.233:1081`；将其置空即可禁用）。
- `run-fusion.sh` 和登录回调默认**不使用代理**；导出
  `FUSION_PROXY=http://host:port` 可选择启用（同时会更新 Wine 注册表）。
- 若安装期间 Autodesk 下载器无法联网，先运行 `./scripts/set-wine-proxy.sh`
  （使用 `FUSION_INSTALL_PROXY` 启用 WinINet 代理）。

### 安装与启动

- `install-fusion.sh` 启动前会自动注册 `adsk://` / `adskidmgr://` 登录回调处理器；
  也可单独运行 `./scripts/install-desktop-handler.sh` 重新注册。
- 安装期间流程序窗口（`Autodesk 应用程序流`）会保持打开，并自动启动 Fusion。
  两者运行在同一个 umu 容器中，因此关闭流程序窗口可能同时关闭 Fusion；可用
  `scripts/run-fusion.sh` 重新启动。
- 不要直接启动 `Fusion360.exe`；请通过 `scripts/run-fusion.sh` 调用
  `FusionLauncher.exe`（必须设置 `QT_D3D_NO_FLIP=1`）。

### 高分屏与 DPI

- 安装和启动脚本会从 KDE（`kwinoutputconfig.json`）、`kscreen-doctor` 或
  `Xft.dpi` 检测桌面缩放比例，并据此设置 Wine 的 `LogPixels` / `Win8DpiScaling`
  （2 倍缩放 → 192 DPI）。可用 `FUSION_SCALE_PERCENT=200` 或
  `FUSION_WINE_DPI=192` 覆盖；`--print` 显示检测到的值。

### 应用启动器

- `install-fusion.sh` 会在 Fusion 载荷出现后立即创建
  `~/.local/share/applications/autodesk-fusion360.desktop`。可用
  `./scripts/install-launcher.sh` 重新创建；`--remove` 用于删除该条目。
  `uninstall.sh` 在两种模式下都会移除该条目，`--purge` 还会删除项目的 `icons/`
  目录。

### 关闭与退出

- **关闭：** Fusion 窗口消失后，`run-fusion.sh` 会等待 `FUSION_CLOSE_GRACE` 秒
  （默认 5），然后强制停止 umu/Proton/Wine，以便尽快释放 `pfx.lock`。如需为保存
  对话框留出更多时间，可调大该值（`FUSION_CLOSE_GRACE=10`）。
- **关闭速度：** 通过 Wine DLL 覆盖禁用 `adpclientservice.exe`（Autodesk
  分析/遥测），从而减少关机路径上的后台服务。登录/授权不受影响。删除
  `HKCU\Software\Wine\DllOverrides` 下的对应值即可恢复。

### 兼容性

- 不要应用旧的 `Qt6WebEngineCore.dll` 补丁：它们与当前 Fusion 版本的 ABI 不兼容，
  会在启动时崩溃。

### 卸载

- 全局写入仅限于 `adsk://` / `adskidmgr://` 桌面处理器。`scripts/uninstall.sh`
  会移除它，并默认删除所有本地安装（`fex/`、`proton/`、`umu/`、`umu-data/`、
  `prefix/`、`cache/`、`installer/`、`icons/`、`logs/`）。使用
  `scripts/uninstall.sh --keep` 可保留本地安装。

## 许可证

本项目（脚本与文档）采用 [MIT 许可证](LICENSE)，可自由使用、修改和再分发，
但需保留版权声明与许可证文本。

- 本仓库不分发 Autodesk Fusion 360 及其安装程序。它们是 Autodesk 的专有软件，
  使用前请阅读并遵守 Autodesk 的许可协议与服务条款；本许可证不涵盖这些内容。
- FEX-Emu、GE-Proton、umu-launcher、Wine/Proton、Steam Linux Runtime 等第三方
  组件遵循各自的许可证，下载和使用时请遵守相应条款。
- 本项目与 Autodesk 无隶属或背书关系。
