#!/bin/bash

PKG_PATH="$GITHUB_WORKSPACE/wrt/package/"

#预置HomeProxy数据
if [ -d *"homeproxy"* ]; then
	echo " "

	HP_RULE="surge"
	HP_PATH="homeproxy/root/etc/homeproxy"

	rm -rf ./$HP_PATH/resources/*

	git clone -q --depth=1 --single-branch --branch "release" "https://github.com/Loyalsoldier/surge-rules.git" ./$HP_RULE/
	cd ./$HP_RULE/ && RES_VER=$(git log -1 --pretty=format:'%s' | grep -o "[0-9]*")

	echo $RES_VER | tee china_ip4.ver china_ip6.ver china_list.ver gfw_list.ver
	awk -F, '/^IP-CIDR,/{print $2 > "china_ip4.txt"} /^IP-CIDR6,/{print $2 > "china_ip6.txt"}' cncidr.txt
	sed 's/^\.//g' direct.txt > china_list.txt ; sed 's/^\.//g' gfw.txt > gfw_list.txt
	mv -f ./{china_*,gfw_list}.{ver,txt} ../$HP_PATH/resources/

	cd .. && rm -rf ./$HP_RULE/

	cd $PKG_PATH && echo "homeproxy date has been updated!"
fi

#修改homeproxy init.d脚本，解决停止服务时不清理防火墙残留规则的问题
HP_INIT="./homeproxy/root/etc/init.d/homeproxy"
if [ -f "$HP_INIT" ]; then
	echo " "
	echo "Patching homeproxy init.d script..."
	
	# 在start_service函数的fw4 reload前添加动态创建防火墙包含项
	sed -i '/start_service()/,/^}$/{
		/fw4 reload.*>.*\/dev\/null/i\
\	# 动态添加防火墙包含项（如果不存在）\
\	if ! uci -q get firewall.homeproxy_forward >/dev/null; then\
\		uci set firewall.homeproxy_forward=include\
\		uci set firewall.homeproxy_forward.type=nftables\
\		uci set firewall.homeproxy_forward.path=/var/run/homeproxy/fw4_forward.nft\
\		uci set firewall.homeproxy_forward.position=chain-pre\
\		uci set firewall.homeproxy_forward.chain=forward\
\	fi\
\	if ! uci -q get firewall.homeproxy_input >/dev/null; then\
\		uci set firewall.homeproxy_input=include\
\		uci set firewall.homeproxy_input.type=nftables\
\		uci set firewall.homeproxy_input.path=/var/run/homeproxy/fw4_input.nft\
\		uci set firewall.homeproxy_input.position=chain-pre\
\		uci set firewall.homeproxy_input.chain=input\
\	fi\
\	if ! uci -q get firewall.homeproxy_post >/dev/null; then\
\		uci set firewall.homeproxy_post=include\
\		uci set firewall.homeproxy_post.type=nftables\
\		uci set firewall.homeproxy_post.path=/var/run/homeproxy/fw4_post.nft\
\		uci set firewall.homeproxy_post.position=table-post\
\	fi\
\	uci commit firewall
	}' $HP_INIT
	
	# 在stop_service函数的fw4 reload前添加清理防火墙包含项
	sed -i '/stop_service()/,/^}$/{
		/fw4 reload.*>.*\/dev\/null/i\
\	# 清理防火墙包含项\
\	uci -q delete firewall.homeproxy_forward\
\	uci -q delete firewall.homeproxy_input\
\	uci -q delete firewall.homeproxy_post\
\	uci commit firewall
	}' $HP_INIT
	
	cd $PKG_PATH && echo "homeproxy init.d has been patched!"
fi


#修改qca-nss-drv启动顺序
NSS_DRV="../feeds/nss_packages/qca-nss-drv/files/qca-nss-drv.init"
if [ -f "$NSS_DRV" ]; then
	echo " "

	sed -i 's/START=.*/START=85/g' $NSS_DRV

	cd $PKG_PATH && echo "qca-nss-drv has been fixed!"
fi

#修改qca-nss-pbuf启动顺序
NSS_PBUF="./kernel/mac80211/files/qca-nss-pbuf.init"
if [ -f "$NSS_PBUF" ]; then
	echo " "

	sed -i 's/START=.*/START=86/g' $NSS_PBUF

	cd $PKG_PATH && echo "qca-nss-pbuf has been fixed!"
fi
