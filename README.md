# ImmortalWrt Hiveton H5000M GitHub Actions 自动化编译工程

本项目是专为 **海微腾 Hiveton H5000M**（联发科 MT7987A / Filogic 880，双 2.5G 网口 + MT5700M 5G 模块）定制的 ImmortalWrt 固件云端自动化编译仓库。

借助 GitHub Actions，每次推送更新或手动点击即可在 GitHub 云端全自动拉取最新源码、应用补丁并构建最新固件，自动上传构建产物与 GitHub Releases。

---

## ✨ 固件集成特性与插件

- **底包**: [ImmortalWrt](https://github.com/immortalwrt/immortalwrt) (官方分支 `openwrt-25.12`，Linux 6.12 内核)
- **风扇智能温控**: 集成 `luci-app-h5000m-fancontrol` + 自动应用 H5000M DTS 设备树补丁（解除内核 thermal governor 竞争，实现平滑温控调速）
- **5G 模块支持**: 集成 `luci-app-mt5700m` + `QModem` (包含 `ubus-at-daemon` 与 `sms-tool_q`) + CDC-NCM / RNDIS / Option 全套驱动
- **网络路由加速**: 集成 `luci-app-passwall` + `sing-box` (全协议版本) + `xray-core` + `chinadns-ng` + `haproxy` + `v2ray-geodata`
- **智能防污染 DNS**: 集成 `luci-app-mosdns` + `mosdns` (包含 `adblock_set` 插件补丁版本) + `v2dat` + 规则集
- **UPnP 端口映射**: 集成 `luci-app-upnp` + `miniupnpd-nftables` (适配 Firewall4 / Nftables)
- **多存储文件管理**: 集成 `luci-app-openlist` + `openlist` 核心 (官方 OpenList 4.2.6，支持挂载各类网盘、WebDAV、本地存储与 FUSE 挂载)
- **完整中文语言包**: 已集成所有插件的简体中文语言包

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
├── .gitignore                       # Git 忽略配置
└── README.md                        # 项目说明文档
```

---

## 🚀 如何使用 GitHub Actions 自动编译？

### 第一步：在 GitHub 上新建仓库
1. 登录您的 GitHub 账号，点击右上角的 **「+」 -> 「New repository」**。
2. 填写仓库名称（例如 `immortalwrt-h5000m`），选择 **Public** 或 **Private**（公开或私有均可）。
3. **不要**勾选 "Initialize this repository with a README"（保持空仓库）。
4. 点击 **「Create repository」**。

### 第二步：将本地项目推送到您的 GitHub 仓库
在本地终端（或 WSL）中进入当前项目目录，执行以下命令：
```bash
# 替换为您的 GitHub 仓库地址
git remote add origin https://github.com/<您的用户名>/<您的仓库名>.git

# 推送代码到 GitHub 的 main 分支
git push -u origin main
```

### 第三步：开启 GitHub Actions 写入权限（用于自动发布 Release）
1. 打开您的 GitHub 仓库页面，进入 **Settings -> Actions -> General**。
2. 滚动到底部的 **Workflow permissions**。
3. 选择 **「Read and write permissions」**，并勾选 **「Allow GitHub Actions to create and approve pull requests」**。
4. 点击 **Save**。

### 第四步：触发自动编译
- **手动触发**：进入仓库页面顶部 **Actions** 标签页，点击左侧的 **「Build ImmortalWrt H5000M Firmware」**，然后点击右侧的 **「Run workflow」** 按钮即可。
- **自动触发**：当您对 `config/`、`patches/` 或 `scripts/` 进行任何修改并 push 到 GitHub 时，GitHub Actions 将会自动触发构建。
- **定时触发**：默认配置为每周定期检测构建，保持固件核心与规则最新。

### 第五步：下载固件
构建完成后（耗时约 1.5 ~ 2.5 小时）：
- 固件会自动上传到当前 Actions 运行记录的 **Artifacts** 区域。
- 如果勾选了 Release，固件会自动发布在仓库右侧的 **Releases** 页面中，直接点击即可下载 `.bin` 固件。
