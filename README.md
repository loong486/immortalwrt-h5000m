# ImmortalWrt Hiveton H5000M GitHub Actions 自动化编译工程

本项目是专为 **海微腾 Hiveton H5000M**（联发科 MT7987A / Filogic 880，双 2.5G 网口 + MT5700M 5G 模块）定制的 ImmortalWrt 固件云端自动化编译仓库。

借助 GitHub Actions，每次推送更新或手动点击即可在 GitHub 云端全自动拉取最新源码、应用补丁并构建最新固件，自动上传构建产物与 GitHub Releases。

---

## 📖 关于本项目 (About)

> **专为海微腾 Hiveton H5000M 5G 路由器量身定制的高性能、开箱即用 ImmortalWrt 固件自动化编译工程。**

- **🎯 研发背景**：海微腾 Hiveton H5000M 搭载联发科 Filogic 880 (MT7987A 4核 A53 @ 2.0GHz)，拥有双 2.5G 网口并集成移远 MT5700M 5G NR 模组，性能出众。然而官方系统扩展性受限，原生开源固件又存在设备树温控锁频竞争、5G 模组驱动缺失、缺少自动化追番与多网盘挂载等痛点。
- **💡 核心设计**：本项目通过 GitHub Actions 实现了完全自动化、每周追踪官方分支（`openwrt-25.12`，Linux 6.12 内核）的云端构建流程。深度融合了 **DTS 温控补丁**、**全套 5G 驱动与 AT 守护**、**网络防污染加速** 与 **OpenList 网盘聚合**，为极客玩家与家庭网络中枢提供极致体验。
- **⚡ 特色优势**：
  - **免搭建本地编译环境**：无需耗费数十 GB 本地硬盘与数小时配置交叉编译工具链，直接利用 GitHub 云端 Runner 构建。
  - **安全与纯净**：源码与脚本 100% 透明开源，不含任何后门与冗余预装，配置精简高效。
  - **一键云端自动发版**：构建完成自动上传完整固件与升级包到 GitHub Releases，支持在线直接下载与网页后台无缝升级。

---

## ✨ 固件集成特性与插件

- **底包**: [ImmortalWrt](https://github.com/immortalwrt/immortalwrt) (官方分支 `openwrt-25.12`，Linux 6.12 内核)
- **风扇智能温控**: 集成 `luci-app-h5000m-fancontrol` + 自动应用 H5000M DTS 设备树补丁（解除内核 thermal governor 竞争，实现平滑温控调速）
- **5G 模块支持**: 集成 `luci-app-mt5700m` + `QModem` (包含 `ubus-at-daemon` 与 `sms-tool_q`) + CDC-NCM / RNDIS / Option 全套驱动
- **网络路由加速**: 集成 `luci-app-passwall` + `sing-box` (全协议版本) + `xray-core` + `chinadns-ng` + `haproxy` + `v2ray-geodata`
- **智能防污染 DNS**: 集成 `luci-app-mosdns` + `mosdns` (包含 `adblock_set` 插件补丁版本) + `v2dat` + 规则集
- **UPnP 端口映射**: 集成 `luci-app-upnp` + `miniupnpd-nftables` (适配 Firewall4 / Nftables)
- **多存储文件管理**: 集成 `luci-app-openlist` + `openlist` 核心 (官方 OpenList 4.2.6，支持挂载各类网盘、WebDAV、本地存储与 FUSE 挂载)
- **FRP 内网穿透**: 集成 `luci-app-frpc` + `frpc` (支持与云端 VPS 建立安全加密反向通道，将 OpenList 等内网服务安全穿透至外部 Docker/VPS 节点)
- **完整中文语言包**: 已集成所有插件的简体中文语言包

---

## 📦 插件与核心组件来源声明 (Credits & Upstream Sources)

本项目秉持开源共建理念，特此向所有被集成的优秀开源项目及其维护者致以崇高敬意。各插件与核心组件的源码来源及上游仓库声明如下：

| 组件 / 插件名称 | 上游维护者 / 团队 | 上游项目仓库 | 核心功能与作用说明 |
| :--- | :--- | :--- | :--- |
| **ImmortalWrt 底包** | [ImmortalWrt Team](https://github.com/immortalwrt) | [immortalwrt/immortalwrt](https://github.com/immortalwrt/immortalwrt) | 固件底包核心，基于 `openwrt-25.12` 分支与 Linux 6.12 内核 |
| **H5000M 风扇控制** | [FAN789](https://github.com/FAN789) | [FAN789/luci-app-h5000m-fancontrol](https://github.com/FAN789/luci-app-h5000m-fancontrol) | H5000M 专用风扇调速与多传感器综合温控插件 |
| **MT5700M 5G 模块** | [FAN789](https://github.com/FAN789) | [FAN789/luci-app-mt5700m](https://github.com/FAN789/luci-app-mt5700m) | MT5700M 5G 模组状态监控、锁频、网络配置 Web 插件 |
| **5G 模组后台服务** | [FUjr](https://github.com/FUjr) | [FUjr/QModem](https://github.com/FUjr/QModem) | 包含 `ubus-at-daemon` AT 指令守护与 `sms-tool_q` 短信工具 |
| **OpenList 核心与插件** | [OpenListTeam](https://github.com/OpenListTeam) | [OpenListTeam/OpenList-OpenWRT](https://github.com/OpenListTeam/OpenList-OpenWRT)<br>[OpenListTeam/OpenList](https://github.com/OpenListTeam/OpenList) | 支持挂载各类网盘、WebDAV、本地存储与 FUSE 的聚合文件管理系统 |
| **MosDNS 防污染 DNS** | [sbwml](https://github.com/sbwml)<br>[IrineSistiana](https://github.com/IrineSistiana) | [sbwml/luci-app-mosdns](https://github.com/sbwml/luci-app-mosdns)<br>[IrineSistiana/mosdns](https://github.com/IrineSistiana/mosdns) | MosDNS v5 高性能 DNS 分流转发器、adblock_set 补丁与 Web 界面 |
| **PassWall 网络加速** | [xiaorouji](https://github.com/xiaorouji) | [xiaorouji/openwrt-passwall](https://github.com/xiaorouji/openwrt-passwall) | OpenWrt 强大的多协议分流与代理管理工具 |
| **sing-box 协议核心** | [SagerNet](https://github.com/SagerNet) | [SagerNet/sing-box](https://github.com/SagerNet/sing-box) | 新一代通用全协议通用网络代理核心 |
| **Xray 代理核心** | [XTLS Team](https://github.com/XTLS) | [XTLS/Xray-core](https://github.com/XTLS/Xray-core) | 高性能 Xray 协议核心组件 |
| **ChinaDNS-NG** | [zfl9](https://github.com/zfl9) | [zfl9/chinadns-ng](https://github.com/zfl9/chinadns-ng) | 高性能双栈防污染 DNS 智能分流工具 |
| **MiniUPnPd** | [Thomas Bernard](https://github.com/miniupnp) | [miniupnp/miniupnp](https://github.com/miniupnp/miniupnp) | UPnP IGD 协议服务，支持现代 Linux Firewall4 (nftables) 映射 |
| **FRP 内网穿透** | [fatedier](https://github.com/fatedier) | [fatedier/frp](https://github.com/fatedier/frp) | 高性能反向代理应用，支持 TCP/UDP/HTTP 穿透与云端反向通道 |

---

## 📁 目录结构

```
├── .github/
│   └── workflows/
│       └── build-immortalwrt.yml    # GitHub Actions 自动化构建核心工作流
├── config/
│   └── h5000m.config                # H5000M 纯净种子配置 (基于本地编译验证)
├── patches/
│   └── h5000m-userspace-fan-control.patch # 设备树 DTS 温控补丁
├── scripts/
│   ├── diy-part1.sh                 # 自定义 Feeds 添加脚本 (QModem, MosDNS 等)
│   └── diy-part2.sh                 # 源码克隆、补丁注入、源优先级修复脚本
├── push_to_github.bat               # Windows 一键自动推送脚本 (智能识别远程)
├── push_to_github.sh                # Linux / WSL 一键推送脚本
├── .gitignore                       # Git 忽略配置
└── README.md                        # 项目说明文档与开源致谢
```

---

## 🚀 如何使用 GitHub Actions 自动编译？

### 第一步：在 GitHub 上新建仓库
1. 登录您的 GitHub 账号，点击右上角的 **「+」 -> 「New repository」**。
2. 填写仓库名称（例如 `immortalwrt-h5000m`），选择 **Public** 或 **Private**（公开或私有均可）。
3. **不要**勾选 "Initialize this repository with a README"（保持空仓库）。
4. 点击 **「Create repository」**。

### 第二步：将本地项目推送到您的 GitHub 仓库
在 Windows 上，直接双击项目根目录下的 **`push_to_github.bat`** 脚本即可；或者在本地终端中执行：
```bash
# 替换为您的 GitHub 仓库地址
git remote set-url origin https://github.com/<您的用户名>/<您的仓库名>.git

# 推送代码到 GitHub 的 main 分支
git push -u origin main
```

### 第三步：开启 GitHub Actions 写入权限（用于自动发布 Release）
1. 打开您的 GitHub 仓库页面，进入 **Settings -> Actions -> General**。
2. 滚动到底部的 **Workflow permissions**。
3. 选择 **「Read and write permissions」**，并勾选 **「Allow GitHub Actions to create and approve pull requests」**。
4. 点击 **Save**。

### 第四步：触发自动编译
- **自动触发**：当您通过 `push_to_github.bat` 推送更新到 GitHub 时，GitHub Actions 将会自动触发构建。
- **手动触发**：进入仓库页面顶部 **Actions** 标签页，点击左侧的 **「Build ImmortalWrt H5000M Firmware」**，然后点击右侧的 **「Run workflow」** 按钮即可。
- **定时触发**：默认配置为每周定期检测构建，保持固件核心与规则最新。

### 第五步：下载固件
构建完成后（耗时约 1.5 ~ 2.5 小时）：
- 固件会自动上传到当前 Actions 运行记录的 **Artifacts** 区域。
- 如果勾选了 Release，固件会自动发布在仓库右侧的 **Releases** 页面中，直接点击即可下载 `.bin` 固件。
