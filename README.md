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

固件每天早上4点自动编译。

固件信息里的时间为编译开始的时间，方便核对上游源码提交时间。

MEDIATEK系列、QUALCOMMAX系列、ROCKCHIP系列、X86系列。

# 目录简要说明

workflows——自定义CI配置

Scripts——自定义脚本

Config——自定义配置

# 自定义配置

## 主题
- 使用 OpenWRT 默认主题 Bootstrap

## 科学插件
- homeproxy（基于 sing-box）
- passwall
- daed（eBPF 透明代理）

## 系统插件
- adguardhome（广告过滤/DNS）
- diskman（磁盘管理）
- netspeedtest（网速测试）
- partexp（分区扩容）
- easytier（P2P 组网）
- zerotier（异地组网）
- upnp
- autoreboot（定时重启）

## 内核依赖
- kmod-sched-bpf（daed 依赖）
- kmod-xdp-sockets-diag（daed 依赖）

#
[![Stargazers over time](https://starchart.cc/VIKINGYFY/OpenWRT-CI.svg?variant=adaptive)](https://starchart.cc/VIKINGYFY/OpenWRT-CI)


