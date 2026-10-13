# OpenWRT-CI
云编译 OpenWRT 固件

# 固件简要说明
- 京东云 AX1800 Pro：`IPQ60XX-WIFI-NO`
- 阿里云 AP8220：`IPQ807X-WIFI-NO`
- 飞牛 fnOS 虚拟机：`X86`（官方 ImmortalWrt `openwrt-25.12`）

IPQ 两台共用一套源码。X86 单独一套源码，不和 ARM 混编。

# 目录简要说明

- `.github/workflows/` —— CI 配置。`QCA-ALL` 编两台高通，`X86` 编虚拟机，`OWRT-ALL` / `MTK-ALL` 编其余平台
- `Scripts/` —— 自定义脚本
- `Config/` —— 设备配置。`GENERAL.txt` 对所有机型生效
- `Packages/` —— 本地固化软件包
- `build_ipq60XX.sh` / `build_ipq807X.sh` —— 本地编译两台高通，源码目录 `./wrt`
- `build_X86.sh` —— 本地编译 X86，源码目录 `./wrt-x86`
- `build.sh` —— 旧的单配置入口，默认 `IPQ60XX-WIFI-NO`，主题和 Wi-Fi 处理与上面三个脚本不同

# 本地编译

```bash
./build_ipq60XX.sh
./build_ipq807X.sh
./build_X86.sh
```

二次编译可加 `SKIP_FEEDS=1`，跳过 feeds 更新。IPQ60 和 IPQ807 切换时会清掉上一个目标的 `tmp`、`.config`、`bin` 和 target 编译目录，主机工具链保留。

| | IPQ60 / IPQ807 | X86 |
| --- | --- | --- |
| 源码 | `VIKINGYFY/immortalwrt` `main` | `immortalwrt/immortalwrt` `openwrt-25.12` |
| 目录 | `./wrt` | `./wrt-x86` |
| 主题 | aurora | aurora |
| 主机名 | `OWRT` | `immortalwrt` |
| 地址 | `192.168.0.1` | `192.168.0.10` |

# X86 镜像

面向飞牛 fnOS 虚拟机，只编 Generic x86/64。

- BIOS 的 `combined.img.gz`。飞牛导入解压后的 `img`，不编 qcow2 和 UEFI
- ext4，内核分区 128MB，根分区 1024MB，便于在虚拟机里扩容
- virtio 网卡和磁盘已编进内核；I210、I350 用 `igb`，X520（82599）用 `ixgbe`
- 无显示输出，去掉核显
- 网页升级上传 `combined.img.gz`，不要上传解压后的 1.12G `img`。LuCI 把文件写到内存盘 `/tmp`，裸镜像放不下会导致上传断开
- `qemu-ga` 不编进镜像，进系统后执行 `apk add qemu-ga`。飞牛里要打开 QEMU Guest Agent

# 所有机型的默认网络

首次启动时写入，升级保留配置时不会重写：

- LAN DHCP 租约 24 小时
- 关闭 LAN 的 IPv6，不再下发前缀、RA 和 DHCPv6。WAN 的 IPv6 保持原样
- DNS 重定向同时劫持 UDP 53 和 TCP 53。LuCI 里的开关仍然同时控制这两条规则

# 自定义配置

## 主题
aurora。下拉菜单和圆角由 `Scripts/Handles.sh` 按 VIKINGYFY 的配置改默认模板。

## 应用插件
- luci-app-homeproxy（代理。sing-box 从 `VIKINGYFY/packages` 引入，当前为 1.15 alpha，官方 feeds 的 1.12 不满足依赖）
- adguardhome（广告过滤 / DNS）
- luci-app-adguardhome（`GN01/luci-app-adguardhome`）
- easytier、zerotier（异地组网）

dae、daed 不选。内核仍保留 eBPF/BTF，方便以后自行安装。

## 仅 X86
- luci-app-bandix（流量监控，预编译 eBPF）
- luci-app-oaf（应用过滤，带上 `appfilter` 和 `kmod-oaf`）

这两项和软件流量分载、硬件流量分载冲突。X86 首次启动会关掉防火墙里的流量分载。

## 系统插件
- vlmcsd（KMS 激活）
- cpufreq（CPU 调频）
- autoreboot（定时重启）

## 精简内容
- 移除 USB 相关内核模块和组件
- 移除蓝牙相关内核模块
- 移除磁盘分区工具
- 移除 netspeedtest / diskman / partexp / samba4

# 脚本说明

## Packages.sh

### UPDATE_PACKAGE 函数
```bash
UPDATE_PACKAGE "包名" "仓库地址" "分支" "特殊处理" "额外清理名称"
```
- 自动删除 feeds 中的同名旧版本
- 克隆 GitHub 仓库到 package 目录。目录已在则直接复用，不重复克隆
- 特殊处理：`pkg`=提取子目录，`name`=重命名

### git_sparse_clone 函数
```bash
git_sparse_clone "分支" "仓库URL" "目录1" "目录2" ...
```
- 稀疏克隆，只下载指定目录
- 适合从大杂烩仓库提取多个插件

### UPDATE_VERSION 函数
```bash
UPDATE_VERSION "软件包名" "是否测试版(true/false)"
```
- 自动检测并更新软件包到最新版本
