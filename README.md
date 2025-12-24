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

# 目录简要说明

workflows——自定义CI配置

Scripts——自定义脚本

Config——自定义配置

# 自定义配置

## 主题
- Bootstrap（OpenWRT 默认）

## 科学/代理插件
- homeproxy（基于 sing-box）
- passwall
- daed（eBPF 透明代理）

## 网络插件
- adguardhome（广告过滤/DNS）
- oaf（应用过滤/OpenAppFilter）
- easytier（P2P 组网）
- zerotier（异地组网）
- upnp（端口映射）

## 系统插件
- vlmcsd（KMS 激活）
- cpufreq（CPU 调频）
- autoreboot（定时重启）

## daed 内核依赖
- kmod-sched-bpf
- kmod-xdp-sockets-diag
- CONFIG_KERNEL_DEBUG_INFO_BTF
- CONFIG_KERNEL_BPF_EVENTS
- CONFIG_KERNEL_XDP_SOCKETS
- CONFIG_BPF_TOOLCHAIN_HOST

## 精简内容
- 移除 USB 相关内核模块和组件
- 移除磁盘分区工具
- 移除 netspeedtest/diskman/partexp/samba4

#
[![Stargazers over time](https://starchart.cc/VIKINGYFY/OpenWRT-CI.svg?variant=adaptive)](https://starchart.cc/VIKINGYFY/OpenWRT-CI)


