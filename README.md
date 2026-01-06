# OpenWRT-CI
云编译OpenWRT固件

官方版：
https://github.com/immortalwrt/immortalwrt.git

高通版：
https://github.com/VIKINGYFY/immortalwrt.git

# U-BOOT

高通版：

https://github.com/chenxin527/uboot-ipq60xx-emmc-build

https://github.com/chenxin527/uboot-ipq60xx-nor-build

联发科版：

https://drive.wrt.moe/uboot/mediatek

# 固件简要说明

固件信息里的时间为编译开始的时间，方便核对上游源码提交时间。

MEDIATEK系列、QUALCOMMAX系列、ROCKCHIP系列、X86系列。

这里只编译 jdc AX1800pro、aliyun ap8220的NO-WI-FI固件，有其他需求请自行更改。

# 目录简要说明

- `workflows/` —— 自定义 CI 配置
- `Scripts/` —— 自定义脚本
- `Config/` —— 自定义配置

# 脚本说明

## Packages.sh

### UPDATE_PACKAGE 函数
```bash
UPDATE_PACKAGE "包名" "仓库地址" "分支" "特殊处理" "额外清理名称"
```
- 自动删除 feeds 中的同名旧版本
- 克隆 GitHub 仓库到 package 目录
- 特殊处理：`pkg`=提取子目录，`name`=重命名

### git_sparse_clone 函数
```bash
git_sparse_clone "分支" "仓库URL" "目录1" "目录2" ...
```
- 稀疏克隆，只下载指定目录（节省时间和空间）
- 适合从大杂烩仓库提取多个插件

### UPDATE_VERSION 函数
```bash
UPDATE_VERSION "软件包名" "是否测试版(true/false)"
```
- 自动检测并更新软件包到最新版本

# 自定义配置

## 主题
- argon（sbwml/luci-theme-argon）
- aurora（eamonxg/luci-theme-aurora）
- kucat（sirpdboy/luci-theme-kucat）

## 应用插件
- homeproxy（已修复防火墙残留 + 预置 surge 规则数据）
- adguardhome（广告过滤/DNS，来自 kenzok8/small-package）
- easytier（组网）
- zerotier（组网）
- upnp（自动端口映射）

> 注：homeproxy 已在 Handles.sh 中修复防火墙残留问题，并预置 Loyalsoldier/surge-rules 数据
> 注：passwall 已移除（停止时不清理防火墙规则）

## 系统插件
- vlmcsd（KMS 激活）
- cpufreq（CPU 调频）
- autoreboot（定时重启）

## eBPF 内核依赖（可后装 dae、daed）
已预置 eBPF/BTF 内核支持，可通过 opkg 安装 dae：
- kmod-sched-bpf / kmod-xdp-sockets-diag
- CONFIG_KERNEL_DEBUG_INFO_BTF=y
- CONFIG_KERNEL_BPF_EVENTS=y
- CONFIG_KERNEL_CGROUP_BPF=y
- CONFIG_BPF_TOOLCHAIN_HOST=y

## 精简内容
- 移除 USB 相关内核模块和组件
- 移除蓝牙相关内核模块
- 移除磁盘分区工具
- 移除 netspeedtest/diskman/partexp/samba4

#
[![Stargazers over time](https://starchart.cc/VIKINGYFY/OpenWRT-CI.svg?variant=adaptive)](https://starchart.cc/VIKINGYFY/OpenWRT-CI)


