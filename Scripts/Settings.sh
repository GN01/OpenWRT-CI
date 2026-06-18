#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

#移除luci-app-attendedsysupgrade
sed -i "/attendedsysupgrade/d" $(find ./feeds/luci/collections/ -type f -name "Makefile")
#保留bootstrap作为默认主题，额外主题通过配置安装后在LuCI中切换
#修改immortalwrt.lan关联IP
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $(find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js")
#添加编译日期标识
sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ $WRT_MARK-$WRT_DATE')/g" $(find ./feeds/luci/modules/luci-mod-status/ -type f -name "10_system.js")

WIFI_SH=$(find ./target/linux/{mediatek/filogic,qualcommax}/base-files/etc/uci-defaults/ -type f -name "*set-wireless.sh" 2>/dev/null)
WIFI_UC="./package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc"
if [ -f "$WIFI_SH" ]; then
	#修改WIFI名称
	sed -i "s/BASE_SSID='.*'/BASE_SSID='$WRT_SSID'/g" $WIFI_SH
	#修改WIFI密码
	sed -i "s/BASE_WORD='.*'/BASE_WORD='$WRT_WORD'/g" $WIFI_SH
elif [ -f "$WIFI_UC" ]; then
	#修改WIFI名称
	sed -i "s/ssid='.*'/ssid='$WRT_SSID'/g" $WIFI_UC
	#修改WIFI密码
	sed -i "s/key='.*'/key='$WRT_WORD'/g" $WIFI_UC
	#修改WIFI地区
	sed -i "s/country='.*'/country='CN'/g" $WIFI_UC
	#修改WIFI加密
	sed -i "s/encryption='.*'/encryption='psk2+ccmp'/g" $WIFI_UC
fi

CFG_FILE="./package/base-files/files/bin/config_generate"
#修改默认IP地址
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $CFG_FILE
#修改默认主机名
sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" $CFG_FILE

#配置文件修改
echo "CONFIG_PACKAGE_luci=y" >> ./.config
echo "CONFIG_LUCI_LANG_zh_Hans=y" >> ./.config
echo "CONFIG_PACKAGE_luci-theme-bootstrap=y" >> ./.config
echo "CONFIG_PACKAGE_luci-theme-argon=y" >> ./.config
echo "CONFIG_PACKAGE_luci-app-argon-config=y" >> ./.config
#WRT_THEME作为额外主题安装，bootstrap保持默认主题
if [[ -n "$WRT_THEME" && "$WRT_THEME" != "bootstrap" && "$WRT_THEME" != "argon" ]]; then
	echo "CONFIG_PACKAGE_luci-theme-$WRT_THEME=y" >> ./.config
	echo "CONFIG_PACKAGE_luci-app-$WRT_THEME-config=y" >> ./.config
fi

#引入私有扩展配置
if [ -f "$GITHUB_WORKSPACE/Config/PRIVATE.txt" ]; then
	echo "Applying private configurations from PRIVATE.txt..."
	cat $GITHUB_WORKSPACE/Config/PRIVATE.txt >> ./.config
fi

#手动调整的插件
if [ -n "$WRT_PACKAGE" ]; then
	echo -e "$WRT_PACKAGE" >> ./.config
fi

#无WIFI配置标志
if [[ "${WRT_CONFIG,,}" == *"wifi"* && "${WRT_CONFIG,,}" == *"no"* ]]; then
	echo "WRT_WIFI=wifi-no" >> $GITHUB_ENV
fi

#Linux 6.18新增选项：OpenWRT元数据未收录，CONFIG_KERNEL_前缀无效，需直接写入内核目标配置
#ARM64 BRBE（Branch Record Buffer Extension），路由器不需要
for kconfig in $(find ./target/linux/ -maxdepth 2 -name "config-*"); do
	grep -q "CONFIG_ARM64_BRBE" "$kconfig" 2>/dev/null || echo "# CONFIG_ARM64_BRBE is not set" >> "$kconfig"
done

#高通平台调整
DTS_PATH="./target/linux/qualcommax/dts/"
if [[ "${WRT_TARGET^^}" == *"QUALCOMMAX"* ]]; then
	#取消nss相关feed
	echo "CONFIG_FEED_nss_packages=n" >> ./.config
	echo "CONFIG_FEED_sqm_scripts_nss=n" >> ./.config
	#echo "CONFIG_ATH11K_NSS_SUPPORT=n" >> ./.config
	#echo "CONFIG_ATH11K_NSS_MESH_SUPPORT=n" >> ./.config
	#设置NSS版本
	echo "CONFIG_NSS_FIRMWARE_VERSION_12_5=y" >> ./.config
	#其他调整
	echo "CONFIG_PACKAGE_kmod-usb-serial-qualcomm=y" >> ./.config

	#无WIFI配置调整Q6大小
	if [[ "${WRT_CONFIG,,}" == *"wifi"* && "${WRT_CONFIG,,}" == *"no"* ]]; then
		find $DTS_PATH -type f ! -iname '*nowifi*' -exec sed -i 's/ipq\(6018\|8074\).dtsi/ipq\1-nowifi.dtsi/g' {} +
		echo "qualcommax set up nowifi successfully!"
	fi

	#开启sqm-nss插件
	#echo "CONFIG_PACKAGE_luci-app-sqm=y" >> ./.config
	#echo "CONFIG_PACKAGE_sqm-scripts-nss=y" >> ./.config
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

#修改jdc ax1800 pro 的内核大小为12M
image_file='./target/linux/qualcommax/image/ipq60xx.mk'
sed -i "/^define Device\/jdcloud_re-ss-01/,/^endef/ { /KERNEL_SIZE := 6144k/s//KERNEL_SIZE := 12288k/ }" $image_file
sed -i "/^define Device\/jdcloud_re-cs-02/,/^endef/ { /KERNEL_SIZE := 6144k/s//KERNEL_SIZE := 12288k/ }" $image_file
sed -i "/^define Device\/jdcloud_re-cs-07/,/^endef/ { /KERNEL_SIZE := 6144k/s//KERNEL_SIZE := 12288k/ }" $image_file
sed -i "/^define Device\/redmi_ax5-jdcloud/,/^endef/ { /KERNEL_SIZE := 6144k/s//KERNEL_SIZE := 12288k/ }" $image_file
sed -i "/^define Device\/linksys_mr/,/^endef/ { /KERNEL_SIZE := 8192k/s//KERNEL_SIZE := 12288k/ }" $image_file
