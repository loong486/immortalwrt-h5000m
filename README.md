<div align="center">

# 🚀 ImmortalWrt for Hiveton H5000M

**专为海微腾 Hiveton H5000M (MT7987A / Filogic 880 + MT5700M 5G) 深度定制的高性能、现代化 ImmortalWrt 固件自动化构建工程**

[![Build Firmware](https://github.com/loong486/immortalwrt-h5000m/actions/workflows/build-immortalwrt.yml/badge.svg)](https://github.com/loong486/immortalwrt-h5000m/actions/workflows/build-immortalwrt.yml)
[![Latest Release](https://img.shields.io/github/v/release/loong486/immortalwrt-h5000m?color=blue&logo=github&label=Release)](https://github.com/loong486/immortalwrt-h5000m/releases)
[![Target](https://img.shields.io/badge/Target-MediaTek%20Filogic%20880-orange?logo=openwrt)](https://openwrt.org)
[![Kernel](https://img.shields.io/badge/Kernel-Linux%206.12-informational?logo=linux)](https://kernel.org)
[![Modem](https://img.shields.io/badge/5G%20Modem-MT5700M%20NR-success)](#-5g-模块与现代化-qmodem-生态)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

[固件特性](#-核心特性亮点) • [硬件规格](#-硬件与固件规格) • [快速刷机](#-快速刷机与升级指南) • [使用指引](#-核心功能配置指南) • [云端编译](#-云端自定义构建) • [开源致谢](#-开源致谢与上游项目)

</div>

---

## 📖 项目简介 (About)

本项目基于 **[ImmortalWrt 25.12](https://github.com/immortalwrt/immortalwrt)** 官方源码仓库，针对 **海微腾 Hiveton H5000M** 5G CPE / 路由器量身定制。依托 GitHub Actions 实现每周自动追踪最新上游源码与自动化云端构建。

### 为什么选择本项目？
* **解决原生系统痛点**：官方原生固件普遍存在设备树温控锁频竞争导致风扇啸叫或降频、缺少 MT5700M 5G 模组管理看板、缺乏短信自动转发等问题。
* **现代化组件全套重构**：
  - 模组控制彻底拥抱 **QModem 现代总线架构**，解决传统私有脚本抢占串口导致的掉线问题。
  - 核心代理与 DNS 分流采用成熟稳定的 **PassWall + MosDNS v5**（双核集成 `Xray` 与 `sing-box 1.14+`），Real-IP 无污染解析与 `nftables` 高速透明分流无缝配合。
* **编译速度极致精简**：剥离重型交叉编译工具链（如 `llvm-bpf` 与巨型 Go 模块），将 GitHub Actions 云端编译时间由原本的 50+ 分钟大幅压缩至 **15~20 分钟**。
* **平滑升级与配置继承**：内建迁移清理脚本，支持无缝“保留配置升级”，升级固件后原有 Wi-Fi、代理订阅与基础网络设置不丢失。

---

## 📋 硬件与固件规格

| 属性 | 详细规格 |
| :--- | :--- |
| **设备型号** | 海微腾 Hiveton H5000M (5G CPE 高性能路由器) |
| **主控芯片 (SoC)** | 联发科 MediaTek Filogic 880 (MT7987A)，4 核心 ARM Cortex-A53 @ 2.0 GHz |
| **网络接口** | 2 × 2.5 Gbps (2.5G 网口) + 高性能 Wi-Fi 原生无线支持 |
| **5G 模组** | 鼎桥 TD Tech MT5700M 5G NR 工业级模组 (M.2 Key-B 接口) |
| **系统架构** | ARM64 (aarch64_cortex-a53) |
| **固件底包** | ImmortalWrt 25.12 分支（Linux 6.12 内核，全量 Firewall4 / nftables 架构） |
| **时区与语言** | 默认中国时区 (`Asia/Shanghai` / UTC+8)，全量集成简体中文语言包与亚洲时区库 |

---

## 🌟 核心特性亮点

### 1. 🌡️ 硬件级智能风扇温控 (DTS Patched)
* 自动注入专门针对 H5000M 定制的设备树 DTS 补丁，解除内核原生 Thermal Governor 的固定温控竞争。
* 深度整合 `luci-app-h5000m-fancontrol`，根据 CPU/5G 模组实时温度实现平滑阶梯调速，兼顾高负荷散热与日常静音。

### 2. 📶 5G 模块与现代化 QModem 生态
* **无冲突串口总线**：基于 `ubus-at-daemon` 统一调度，并在编译期注入 `tom_modem` 自动探测 `ubus` 总线补丁，彻底避免 QModem、ModemWebUI 与 SmsForward 争抢物理串口导致模组掉线。
* **开机自动 SIM 卡初始化**：集成 `qmodem-mt5700-fix` 服务，开机自动执行 `AT^SCICHG=0,1` 唤醒 SIM 卡槽，彻底根除基带返回 `+CME ERROR: 10`（SIM 未识别）的问题。
* **现代化模组控制后台 (`luci-app-qmodem-next`)**：
  - 官方现代响应式管理后台，提供模组拨号管理、实时射频监控与会话式短信收发。
  - 默认禁用 SIM 卡短信自动删除（`sms_auto_delete_from_sim=0`），确保 QModem、ModemWebUI 与 SmsForward 三方均可完整读取短信而互不干扰。
* **MT5700 独立现代 WebUI 看板 ([lonelysix-editor/luci-app-modemwebui](https://github.com/lonelysix-editor/luci-app-modemwebui))**：
  - 集成 `luci-app-modemwebui` 与原生 ARM64 后端 `webuiserver`（全面取代旧版 Python `at-webserver`），在 LuCI 点击 **调制解调器 → ModemWebUI** 直接在新标签页全屏打开 `http://<路由器地址>:8001/`（告别主题错位内嵌框），也可直接访问 `http://192.168.88.1:8001/`。
  - 运行于 `PORT=qmodem` + `MODE=tom_modem` 模式并直接对接 QModem `ubus-at-daemon` 总线，结合 QModem `post_init` 钩子自动追踪冷启动 USB 重枚举后的动态 AT 端口并重载服务（同时将前端 AT 指令超时提升至 `5s`），提供专属可视化信号仪表盘、载波聚合 (CA) 状态监控、短信开关管理、频段/小区锁定及交互式 AT 终端。

### 3. 📩 全自动多通道短信转发 (`luci-app-smsforward`)
* 集成独立开源插件 **[snowflakexuehui/luci-app-smsforward](https://github.com/snowflakexuehui/luci-app-smsforward)**（`luci-app-smsforward` + C 语言守护进程 `smsforward`），收到运营商流量提醒、验证码或欠费短信时即时推送到随身设备。
* 后端通过 `tom_modem -u` 复用 QModem `ubus-at-daemon` 总线读取短信，并与 QModem / ModemWebUI 共享未删除的 SIM 卡短信（同时默认关闭 QModem 自带旧版转发开关以防重复推送）。
* **原生支持 10 大主流推送渠道**：
  - **PushPlus（推送加）**、**WxPusher（微信推送）**、**PushDeer**
  - **企业微信 Webhook**、**Bark（iOS 推送）**、**钉钉（DingTalk）**、**飞书（Feishu）**
  - **IYUU**、**Telegram 机器人**、**Server酱**
* 支持 LuCI 界面（**调制解调器 → 短信转发**）一站式配置、历史转发记录查看/清理与一键测试推送。

### 4. ⚡ PassWall + MosDNS v5 高性能透明分流与防污染 DNS
* **PassWall (`luci-app-passwall`)**：基于 Firewall4 `nftables` / `nftset` 的成熟透明代理方案，同时内置 **Xray** 与 **sing-box 1.14+** 双核心（支持 VLESS Reality、Hysteria2 端口跳跃、Trojan、Shadowsocks 等全协议）。
* **MosDNS v5 ([sbwml/luci-app-mosdns](https://github.com/sbwml/luci-app-mosdns))**：集成带 `adblock_set` 与缓存预取增强补丁的 `mosdns 5.3.4` + `geo2txt`，实现国内外 Real-IP 精准分流解析、防 DNS 污染/泄漏及 IPv6 `AAAA` 按需过滤，开关代理无需清理 FakeIP 缓存。
* 预置 `zoneinfo-asia` 时区数据库，确保 Go 核心程序日志时间与 `Asia/Shanghai` 完全一致。

### 5. 🛡️ AdGuard Home 全网过滤与端口映射
* **AdGuard Home (`luci-app-adguardhome` + `adguardhome`)**：集成 ImmortalWrt 官方最新 AdGuard Home v0.107+，提供全网 DNS 广告拦截、追踪器屏蔽与可视化查询日志。默认处于关闭状态以避免与 `dnsmasq` / `MosDNS` 抢占 `53` 端口；需要启用时可在 **服务 → AdGuard Home** 中配置并打开初始化向导（`:3000`）按需对接 DNS 端口。
* **MiniUPnPd (nftables)**：完美适配 Firewall4，游戏主机与下载工具端口自动映射。

---

## 📦 插件矩阵与上游致谢 (Credits)

| 功能分类 | 插件 / 组件名称 | 上游维护者 | 上游项目仓库 | 核心功能说明 |
| :--- | :--- | :--- | :--- | :--- |
| **系统核心** | ImmortalWrt 源码 | ImmortalWrt Team | [immortalwrt/immortalwrt](https://github.com/immortalwrt/immortalwrt) | 固件核心底包 (25.12, Linux 6.12) |
| **硬件温控** | `luci-app-h5000m-fancontrol` | FAN789 | [FAN789/luci-app-h5000m-fancontrol](https://github.com/FAN789/luci-app-h5000m-fancontrol) | H5000M 硬件风扇温控与调速 |
| **MT5700 独立看板** | `luci-app-modemwebui` / `webuiserver` | lonelysix-editor | [lonelysix-editor/luci-app-modemwebui](https://github.com/lonelysix-editor/luci-app-modemwebui) | MT5700 独立现代 WebUI 看板 (`:8001`)，基于 `tom_modem` / `ubus` 总线 |
| **5G 协议栈** | `qmodem` / `luci-app-qmodem-next` | FUjr | [FUjr/QModem](https://github.com/FUjr/QModem) | QModem 核心、`ubus-at-daemon` 无冲突总线与现代 Web 界面 |
| **短信自动转发** | `luci-app-smsforward` / `smsforward` | snowflakexuehui | [snowflakexuehui/luci-app-smsforward](https://github.com/snowflakexuehui/luci-app-smsforward) | 独立 C 语言多通道短信监听与自动推送转发插件 |
| **网络代理** | `luci-app-passwall` | Openwrt-Passwall | [Openwrt-Passwall/openwrt-passwall](https://github.com/Openwrt-Passwall/openwrt-passwall) | 基于 nftables 的全功能透明分流代理 |
| **DNS 分流** | `luci-app-mosdns` / `mosdns` | sbwml / IrineSistiana | [sbwml/luci-app-mosdns](https://github.com/sbwml/luci-app-mosdns) | MosDNS v5 无污染国内外 DNS 分流与广告过滤 |
| **代理内核** | `xray-core` / `sing-box` (v1.14.4) | XTLS / SagerNet | [XTLS/Xray-core](https://github.com/XTLS/Xray-core) • [SagerNet/sing-box](https://github.com/SagerNet/sing-box) | 双核心现代全协议代理引擎 |
| **DNS 广告拦截** | `luci-app-adguardhome` / `adguardhome` | AdguardTeam / ImmortalWrt | [AdguardTeam/AdGuardHome](https://github.com/AdguardTeam/AdGuardHome) | 全网 DNS 广告与追踪器过滤拦截服务 |
| **端口映射** | `miniupnpd-nftables` | Thomas Bernard | [miniupnp/miniupnp](https://github.com/miniupnp/miniupnp) | Firewall4 原生 UPnP IGD 映射服务 |

---

## 🛠️ 快速刷机与升级指南

### 1. 默认登录信息
* **管理后台 IP**：`192.168.88.1`
* **默认用户 / 密码**：`root` / `root`
* **默认 Wi-Fi 密码**：`198198ko`

### 2. 升级固件 (保留现有配置)
如果您目前正在运行本固件或兼容系统：
1. 从 GitHub 仓库的 **[Releases](https://github.com/loong486/immortalwrt-h5000m/releases)** 页面下载最新的 `sysupgrade.bin` 固件包。
2. 进入路由器后台：**系统 → 备份/升级 → 刷写固件**。
3. 上传固件包，**勾选“保留配置”**，确认刷写。
4. > **提示**：固件内置了自动化迁移清理脚本（`99-cleanup-legacy`），首次启动会自动清理旧版 `at-webserver`（`/www/5700`）、`momo`、`openlist`、`frpc` 等残留文件与过期 feed 源、应用默认接入参数（`192.168.88.1` / `root` / Wi-Fi 密码 `198198ko`）及禁用硬件加速流控（防止 MT5700M USB CDC NAT 断流），同时保留您的 PassWall / MosDNS / AdGuard Home 等核心业务配置。

### 3. 全新安装 (不保留配置)
首次从官方原厂固件或其他第三方固件切换时，建议取消勾选“保留配置”进行全新刷写，以获得最纯净稳定的运行环境。

---

## ⚙️ 核心功能配置指南

### 📶 5G 模组与联网调试
* 固件启动后会自动配置 QModem USB 槽位（`2-1`）并识别 MT5700M 完成 SIM 初始化，借助 `ubus-at-daemon` 提供统一无冲突总线。
* 可在 **调制解调器 (Modem)** 中查看模组状态与收发短信，或通过 **调制解调器 → ModemWebUI**（`http://192.168.88.1:8001/`）进行详细射频参数、载波聚合 (CA) 监控与锁频配置。
* 固件默认禁用 SIM 卡短信自动删除（`sms_auto_delete_from_sim=0`），并关闭了防火墙软件/硬件流控（Flow Offloading），保证 USB CDC 网卡 NAT 稳定以及 QModem、ModemWebUI 与 SmsForward 三端同时读取短信不冲突。

### 🎛️ MT5700 独立看板 (ModemWebUI)
* **访问方式**：在 LuCI 后台点击 **调制解调器 → ModemWebUI** 即可直接在新窗口打开专属 MT5700 管理控制台（或浏览器直接访问 `http://192.168.88.1:8001/`）。
* **零冲突动态端口架构**：后台由原生 ARM64 守护进程 `/usr/bin/webuiserver` 驱动，开机自动探测 MT5700M 并按当前路由器 LAN IP（默认 `192.168.88.1`）生成前端配置；默认启用 `PORT=qmodem` + `MODE=tom_modem` 模式直接对接 QModem `ubus-at-daemon` 总线，并在 USB 重枚举触发 QModem `post_init` 时自动同步最新 AT 端口并平滑重载服务，开箱即用，无需手工配置串口或 Python 代理。

### 📩 配置短信自动转发 (SmsForward)
1. 进入后台：**调制解调器 → 短信转发**（系统已默认关闭 QModem 自带旧版 `sms_forwarder` 开关，避免重复推送）。
2. 勾选启用服务，AT 端口保持默认 `qmodem`（底层调用 `tom_modem -u` 复用 `ubus-at-daemon` 无冲突总线）。
3. 选择并配置所需推送通道：**PushPlus、WxPusher、PushDeer、企业微信、Bark、钉钉、飞书、IYUU、Telegram、Server酱**，填入对应 Token / Key / Webhook。
4. 保存并应用后，可在页面直接点击 **测试推送** 验证连通性，或查看与清除历史转发记录（也可通过 SSH 执行 `/usr/bin/smsforward -t` 手动测试）。

### 🚀 PassWall + MosDNS 配置
1. **MosDNS**：进入 **服务 → MosDNS**，勾选启用并保持“DNS 转发”开启（远程 DNS 指向本地代理端口或加密上游，按需开启非国内 IPv6 `AAAA` 过滤）。
2. **PassWall**：进入 **服务 → PassWall**，在“节点订阅”中填入订阅链接并更新节点；DNS 分流模式选择通过 `MosDNS`（自定义上游 `127.0.0.1#5335`）或内置 `ChinaDNS-NG`，勾选主开关“保存并应用”即可。

---

## 💻 云端自定义构建

本项目完全基于 GitHub Actions 自动化运维：

### 1. 快速 Fork 编译属于自己的固件
1. 点击本仓库右上角 **Fork** 到您的个人 GitHub 账号。
2. 进入您 Fork 后的仓库页面：**Settings → Actions → General → Workflow permissions**，勾选 **Read and write permissions** 并保存。
3. 进入 **Actions** 标签页，在左侧选择 **Build ImmortalWrt H5000M Firmware**，点击右侧 **Run workflow** 即可开始全自动云端构建。
4. 构建完成后，前往 **Releases** 即可下载生成的固件。

### 2. 升级与调整 sing-box 核心版本
如需体验未来最新发布的 sing-box，仅需修改 [`scripts/diy-part2.sh`](scripts/diy-part2.sh) 第 9 行：
```bash
SING_BOX_VERSION="1.14.4"  # 直接修改为您需要的版本号
```
提交代码后，GitHub Actions 将会自动以指定版本完成拉取与编译。

---

## 📂 仓库文件组织

```text
immortalwrt-h5000m/
├── .github/
│   └── workflows/
│       └── build-immortalwrt.yml     # GitHub Actions 自动化云端编译流水线
├── config/
│   └── h5000m.config                 # H5000M 固件编译种子配置文件
├── patches/
│   └── h5000m-userspace-fan-control.patch # 设备树 DTS 用户态智能温控补丁
├── scripts/
│   ├── diy-part1.sh                  # 编译前阶段：自定义 Feed 软件源注册
│   └── diy-part2.sh                  # 编译中阶段：插件拉取、版本覆盖与迁移注入
├── .gitignore                        # Git 版本控制忽略配置
├── LICENSE                           # MIT 开源授权协议
└── README.md                         # 项目使用说明文档
```

---

## 📜 开源许可

本项目源码及相关脚本基于 [MIT License](LICENSE) 协议开源。集成的第三方软件包与插件均遵循其各自的原生开源协议。
