# ImmortalWrt-ImageBuilder (Fork) — AI Agent 项目指导说明

## 📋 项目概述

本仓库 fork 自 [wukongdaily/ImmortalWrt-ImageBuilder](https://github.com/wukongdaily/ImmortalWrt-ImageBuilder)，使用 GitHub Actions 基于 ImmortalWrt ImageBuilder 构建 x86-64 路由器固件。

**主要差异：** 在原作基础上，针对 x86-64-24.10 版本定制了更多默认集成插件、自定义插件下载源、以及 WebUI 菜单项位置调整。

---

## 🏗️ 项目结构

```
├── .github/workflows/
│   ├── lhy-build-x86-64-24.10.x.yml   ← 自定义工作流（启动构建的主入口）
│   ├── build-x86-64-24.10.x.yml       ← 原作工作流（保留但不用）
│   └── build-*.yml                     ← 原作的其他架构工作流
│
├── files/                              ← 嵌入固件的自定义文件
│   └── etc/
│       ├── rc.local                    ← ⭐ 自定义：开机调整个别插件 WebUI 菜单位置
│       └── uci-defaults/
│           ├── 99-custom.sh            ← 固件首次启动配置脚本（与原作同步）
│           └── 60-appfilter-feature-cfg ← appfilter 功能配置
│
├── shell/
│   ├── lhy-custom-packages.sh          ← ⭐ 自定义：启用的第三方/仓库外插件列表
│   ├── custom-packages.sh              ← 原文的第三方插件列表（与上游同步，仅作参考）
│   ├── switch_repository.sh            ← 软件源切换
│   └── prepare-packages.sh             ← IPK 解压准备
│
├── x86-64/
│   ├── lhy-build24.sh                  ← ⭐ 自定义：构建脚本（Docker ImageBuilder 内执行）
│   ├── build24.sh                      ← 原文构建脚本（与上游同步，保留参考）
│   └── imm.config                      ← ImmortalWrt 内核配置
│
└── info.md                             ← 固件发布信息模板
```

---

## ⭐ 核心自定义文件详细说明

### 1️⃣ `lhy-build-x86-64-24.10.x.yml` — 工作流入口

GitHub Actions 工作流，触发方式：`workflow_dispatch`（手动触发）。

**用户可在 UI 上配置的参数：**

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `luci_version` | choice | 24.10.6 | LUCI 版本号 |
| `release_version` | string | 空 | 发布版本标签 |
| `custom_router_ip` | string | 192.168.100.1 | 多网口路由器管理 IP |
| `profile` | string | 1024 | 固件大小(MB) |
| `enable_store` | boolean | true | 是否集成 iStore 商店 |
| `enable_docker` | boolean | true | 是否集成 Docker |
| `enable_others` | boolean | true | 是否集成拓展插件 |
| `enable_pppoe` | yes/no | no | 是否配置 PPPoE 拨号 |
| `pppoe_account/password` | string | — | 宽带账号密码 |

**构建流程：**
1. Checkout 代码
2. 写入自定义 IP 配置到 `custom/` 目录
3. 校验 PPPoE 参数
4. Docker 运行 `immortalwrt/imagebuilder:x86-64-openwrt-${luci_version}` 镜像
5. 挂载 `files/`、`custom/`、`x86-64/lhy-build24.sh`、`shell/`、`packages/` 等目录到容器内
6. 容器内执行 `lhy-build24.sh`（挂载为 `/home/build/immortalwrt/build.sh`）

---

### 2️⃣ `lhy-build24.sh` — 构建核心脚本

在 Docker ImageBuilder 容器内执行，负责组装固件。

**执行顺序：**
1. 打印镜像信息（版本、IP、大小等）
2. `source shell/lhy-custom-packages.sh`（仅当 enable_others=true）
3. `source shell/switch_repository.sh`（切换软件源仓库）
4. 创建 PPPoE 配置文件
5. 下载第三方插件：
   - **自定义仓库：** `liuweilhy/OpenwrtPackages` 最新 Release 中的 IPK
   - **原作 store 仓库：** `wukongdaily/store` 中的 run/ipk 文件
6. 组装 `PACKAGES` 变量（详见下方）
7. 检测各插件并下载对应的内核二进制：
   - openclash → 下载 clash_meta 内核、GeoIP/GeoSite
   - ssr-plus → 下载 mihomo core
   - adguardhome → 下载 AdGuardHome 内核
8. `make image` 调用 ImageBuilder 构建固件

**默认集成的核心包（PACKAGES 变量）：**
```
curl, diskman, firewall, theme-argon, argon-config,
package-manager, ttyd, xray-core, hysteria, passwall-zh-cn,
openclash, homeproxy-zh-cn, openssh-sftp-server, filemanager
vlmcsd, zerotier, smartdns, ddns-go, frps, frpc, wol,
wechatpush, upnp, cloudflared
```

**环境变量传递链：**
```
工作流 UI(用户输入) → YML 中的 -e 参数 → lhy-build24.sh 读取 → 构建固件
```

---

### 3️⃣ `lhy-custom-packages.sh` — 自定义插件清单

这个文件定义用户在 **拓展插件** 模式下额外集成的插件。通过取消注释行来启用/禁用。

**当前已启用的插件（通过 `CUSTOM_PACKAGES+=`）：**

| 插件 | 说明 | 来源 |
|------|------|------|
| adguardhome | 去广告 | 第三方 |
| geoview xray-core sing-box hysteria passwall-zh-cn | passwall 代理 | 第三方 |
| nikki-zh-cn | 代理客户端 | Imm 仓库 |
| watchdog | 看门狗 | 第三方 |
| mosdns | DNS 分流 | 第三方 |
| appfilter | 应用过滤 | 第三方 |
| taskplan | 任务计划 | Imm 仓库 |
| easytier | 组网工具 | 第三方 |
| bandix | 流量监控 | 第三方 |
| rtp2httpd | IPTV 转发 | 第三方 |
| advanced-reboot (x2) | 高级重启 | Imm 仓库 |

**注释中可选的插件（取消注释即可启用）：**
run, quickstart, quickfile, uninstall, aurora, openvpn, dae/daed, ssr-plus, passwall2, nekobox, momo, clashoo, openclash, homeproxy, wireguard, tailscale, partexp, kucat, advancedplus, turboacc, lucky, gecoosac, unishare, ipsec-vpnd, dufs 等。

**⚠️ 冲突警告：**
- `clashoo` 与 `nikki` 不能同时集成
- `luci-app-run` 与 `quickfile` 不能同时集成（nginx 配置冲突）
- 启用 `advancedplus` 需排除 `argon-config`

---

### 4️⃣ `files/etc/rc.local` — WebUI 菜单位置调整

固件首次启动后执行的用户自定义脚本。主要功能：

| 目标插件 | 原菜单位置 | 调整至 |
|----------|-----------|--------|
| appfilter | services → | **control** |
| nft-qos | services → | **network** |
| wol | services → | **control** |
| nlbwmon | services → | **network** |
| banip | services → | **network** |

这些调整通过 `sed` 修改 Lua 控制器或 JSON 菜单文件实现，使管理类插件从杂乱的"服务"菜单移到更合理的分类下。

---

### 5️⃣ `files/etc/uci-defaults/99-custom.sh` — 首次开机配置

与上游同步的脚本，在固件首次启动时自动运行，完成：

1. **防火墙设置** — WAN 口入站默认为 ACCEPT（便于新手访问）
2. **主机名映射** — `time.android.com` 安卓 TV 时间同步修复
3. **PPPoE 配置** — 从动态生成的文件读取拨号信息
4. **网口探测与配置：**
   - 单网口 → DHCP 模式
   - 多网口 → 首个为 WAN（DHCP/PPPoE），其余为 LAN（静态 IP）
5. **SSH/TTYD 开放** — 所有网口均可访问
6. **quickfile** — nginx 配置修复（如已安装）
7. **Docker 防火墙** — 配置 docker zone 规则

---

## 🔄 与原作的同步策略

本仓库定期通过 `git merge upstream/master` 同步上游更新。

**同步时需要关注的冲突/变更点：**

| 文件 | 同步策略 |
|------|----------|
| `shell/lhy-custom-packages.sh` | 手动合并 `shell/custom-packages.sh` 中新增/更新的插件选项到本文件对应位置 |
| `x86-64/lhy-build24.sh` | 检查 `x86-64/build24.sh` 的结构性更新，选择性合并 |
| `*.yml` 工作流 | 自定义工作流独立维护，不与上游同步 |
| `files/etc/uci-defaults/99-custom.sh` | git merge 自动处理（直接使用上游版本） |

---

## 🔧 AI Agent 操作指南

### 修改固件默认集成插件

**位置：** `x86-64/lhy-build24.sh` 第 77-107 行

```bash
PACKAGES="$PACKAGES curl"
PACKAGES="$PACKAGES luci-i18n-diskman-zh-cn"
# ... 直接增删行即可
```

### 新增/移除第三方插件

**位置：** `shell/lhy-custom-packages.sh`

取消注释或添加新行：
```bash
CUSTOM_PACKAGES="$CUSTOM_PACKAGES <包名>"
```

### 调整 WebUI 菜单位置

**位置：** `files/etc/rc.local`

参照已有模式添加新的 `sed` 替换段。

### 修改首次开机行为

**位置：** `files/etc/uci-defaults/99-custom.sh`

注意此文件与上游同步，若做了个性化修改应在 git 中保留。

### 添加新 Release 下载地址

**位置：** `.github/workflows/lhy-build-x86-64-24.10.x.yml` 第 147 行

```yaml
files: |
  ${{ github.workspace }}/bin/targets/x86/64/*squashfs-combined-efi.img.gz
```

### 同步上游更新

```bash
git fetch upstream
git merge upstream/master
# 检查冲突，更新 lhy-custom-packages.sh 中的插件选项
git add -u && git commit -m "Merge upstream: <summary>"
```

### 数据流总结

```
用户 GitHub UI 输入参数
  ↓
lhy-build-x86-64-24.10.x.yml
  ↓ (docker run -e ...)
lhy-build24.sh (容器内)
  ├── source lhy-custom-packages.sh   → 第三方插件列表
  ├── source switch_repository.sh     → 软件源
  ├── 下载 liuweilhy/OpenwrtPackages  → 我的自定义 IPK
  ├── 下载 wukongdaily/store          → 第三方 run/ipk
  ├── 检测/下载插件内核 (openclash/ssr-plus/adguardhome)
  └── make image → 生成 .img.gz
  ↓
GitHub Release → 用户下载
```

---

## 🧪 测试验证要点

1. **工作流可运行** — 在 GitHub Actions 手动触发应能成功构建
2. **固件可启动** — 生成的 .img.gz 能在虚拟机/x86 设备上启动
3. **Web 界面可达** — 多网口 `192.168.100.1`，单网口 DHCP 模式
4. **PPPoE 拨号** — 如配置则应正常拨号
5. **插件功能** — 被启用的插件在 WebUI 中可见且可用
6. **菜单位置** — rc.local 调整的插件出现在正确菜单分类下
