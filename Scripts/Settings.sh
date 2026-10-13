#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

#移除luci-app-attendedsysupgrade
sed -i "/attendedsysupgrade/d" $(find ./feeds/luci/collections/ -type f -name "Makefile")
#修改默认主题
find ./feeds/luci/collections/ -type f -name "Makefile" -exec sed -i "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g" {} +
#修改immortalwrt.lan关联IP
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $(find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js")
#添加编译日期标识。先去掉已写入的后缀，避免同一份源码重复编译时把日期叠加上去
find ./feeds/luci/modules/luci-mod-status/ -type f -name "10_system.js" -exec sed -i \
	-e "s/ + (' \/ [^']*')//g" \
	-e "s/(\(luciversion || ''\))/(\1) + (' \/ $WRT_MARK-$WRT_DATE')/g" {} +

WIFI_UC="./package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc"
if [ -f "$WIFI_UC" ]; then
	#修改WIFI名称
	sed -i "s/ssid='.*'/ssid='$WRT_SSID'/g" $WIFI_UC
	#修改WIFI密码
	sed -i "s/key='.*'/key='$WRT_WORD'/g" $WIFI_UC
fi

CFG_FILE="./package/base-files/files/bin/config_generate"
#修改默认IP地址
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $CFG_FILE
#修改默认主机名
sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" $CFG_FILE

#配置文件修改
echo "CONFIG_PACKAGE_luci=y" >> ./.config
echo "CONFIG_LUCI_LANG_zh_Hans=y" >> ./.config
echo "CONFIG_PACKAGE_luci-theme-$WRT_THEME=y" >> ./.config
echo "CONFIG_PACKAGE_luci-app-$WRT_THEME-config=y" >> ./.config

#引入私有扩展配置
if [ -f "$GITHUB_WORKSPACE/Config/PRIVATE.txt" ]; then
	echo "Applying private configurations from PRIVATE.txt..."
	cat $GITHUB_WORKSPACE/Config/PRIVATE.txt >> ./.config
fi

#手动调整的插件
if [ -n "$WRT_PACKAGE" ]; then
	echo -e "$WRT_PACKAGE" >> ./.config
fi

#高通平台调整
DTS_PATH="./target/linux/qualcommax/dts/"
if [[ "${WRT_TARGET^^}" == *"QUALCOMMAX"* ]]; then
	#无WIFI配置调整Q6大小
	if [[ "$WRT_WIFI" == "WIFI-NO" ]]; then
		find $DTS_PATH -type f ! -iname '*nowifi*' -exec sed -i 's/ipq\(6018\|8074\).dtsi/ipq\1-nowifi.dtsi/g' {} +
		echo "qualcommax set up nowifi successfully!"
	fi
fi

#自定义APK软件源
APK_MIRROR="mirror.nju.edu.cn/immortalwrt"

mkdir -p ./files/etc/uci-defaults/
cat > ./files/etc/uci-defaults/99-custom-apk-repos <<EOF
#!/bin/sh
if [ -d /etc/apk/repositories.d ]; then
    for f in /etc/apk/repositories.d/*.list; do
        [ -f "\$f" ] && sed -i "s|downloads.immortalwrt.org|${APK_MIRROR}|g" "\$f"
    done
    echo "APK mirror set to: ${APK_MIRROR}"
fi
exit 0
EOF
chmod +x ./files/etc/uci-defaults/99-custom-apk-repos

cat > ./files/etc/uci-defaults/98-vim-init <<'EOF'
#!/bin/sh
cat > /root/.vimrc <<'EOVIM'
set encoding=utf-8
set termencoding=utf-8
set fileencodings=utf-8,gbk,gb2312,gb18030,cp936
syntax on
set hlsearch
EOVIM

grep -q "^alias vi='vim'$" /etc/profile || echo "alias vi='vim'" >> /etc/profile
grep -q '^export EDITOR=vim$' /etc/profile || echo "export EDITOR=vim" >> /etc/profile

exit 0
EOF
chmod +x ./files/etc/uci-defaults/98-vim-init

#LAN：租约 24 小时，并关掉这个接口的 IPv6
cat > ./files/etc/uci-defaults/96-lan-network <<'EOF'
#!/bin/sh
uci -q set dhcp.lan.leasetime='24h'
uci -q set dhcp.lan.dhcpv6='disabled'
uci -q set dhcp.lan.ra='disabled'
uci -q set dhcp.lan.ndp='disabled'
uci -q delete dhcp.lan.ra_flags
uci -q delete dhcp.lan.ra_slaac
uci -q commit dhcp

uci -q set network.lan.ipv6='0'
uci -q set network.lan.delegate='0'
uci -q delete network.lan.ip6assign
uci -q delete network.lan.ip6hint
uci -q delete network.lan.ip6class
uci -q delete network.lan.ip6ifaceid
uci -q commit network
exit 0
EOF
chmod +x ./files/etc/uci-defaults/96-lan-network

#DNS 重定向原先只劫持 UDP 53，补上 TCP。LuCI 里的开关仍然控制这两条规则
DNSMASQ_INIT="./package/network/services/dnsmasq/files/dnsmasq.init"
if [ -f "$DNSMASQ_INIT" ] && ! grep -q 'tcp dport 53 counter redirect' "$DNSMASQ_INIT"; then
	awk '
		{
			print
			if ($0 ~ /udp dport 53 counter redirect/ && $0 ~ /DNSMASQ HIJACK/) {
				line = $0
				sub(/udp dport 53/, "tcp dport 53", line)
				print line
			}
		}
	' "$DNSMASQ_INIT" > "$DNSMASQ_INIT.tmp" && mv "$DNSMASQ_INIT.tmp" "$DNSMASQ_INIT"
fi

#Bandix 的 TC 挂载看不到被流量分载绕过的包
if [[ "${WRT_TARGET,,}" == "x86" ]]; then
	cat > ./files/etc/uci-defaults/97-x86-no-flowoffload <<'EOF'
#!/bin/sh
uci -q set firewall.@defaults[0].flow_offloading='0'
uci -q set firewall.@defaults[0].flow_offloading_hw='0'
uci -q commit firewall
exit 0
EOF
	chmod +x ./files/etc/uci-defaults/97-x86-no-flowoffload
fi

#修改jdc ax1800 pro 的内核大小为12M
image_file='./target/linux/qualcommax/image/ipq60xx.mk'
sed -i "/^define Device\/jdcloud_re-ss-01/,/^endef/ { /KERNEL_SIZE := 6144k/s//KERNEL_SIZE := 12288k/ }" $image_file
sed -i "/^define Device\/jdcloud_re-cs-02/,/^endef/ { /KERNEL_SIZE := 6144k/s//KERNEL_SIZE := 12288k/ }" $image_file
sed -i "/^define Device\/jdcloud_re-cs-07/,/^endef/ { /KERNEL_SIZE := 6144k/s//KERNEL_SIZE := 12288k/ }" $image_file
sed -i "/^define Device\/redmi_ax5-jdcloud/,/^endef/ { /KERNEL_SIZE := 6144k/s//KERNEL_SIZE := 12288k/ }" $image_file
sed -i "/^define Device\/linksys_mr/,/^endef/ { /KERNEL_SIZE := 8192k/s//KERNEL_SIZE := 12288k/ }" $image_file
