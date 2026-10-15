#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

#安装和更新软件包
UPDATE_PACKAGE() {
	local PKG_NAME=$1
	local PKG_REPO=$2
	local PKG_BRANCH=$3
	local PKG_SPECIAL=$4
	local PKG_LIST=("$PKG_NAME" $5)  # 第5个参数为自定义名称列表
	local REPO_NAME=${PKG_REPO#*/}
	local REPO_PATH="./package/$REPO_NAME"

	echo " "

	# 删除本地可能存在的不同名称的软件包
	for NAME in "${PKG_LIST[@]}"; do
		# 查找匹配的目录
		echo "Search directory: $NAME"
		local FOUND_DIRS=$(find ./feeds/luci/ ./feeds/packages/ -maxdepth 3 -type d -iname "*$NAME*" 2>/dev/null)

		# 删除找到的目录
		if [ -n "$FOUND_DIRS" ]; then
			while read -r DIR; do
				rm -rf "$DIR"
				echo "Delete directory: $DIR"
			done <<< "$FOUND_DIRS"
		else
			echo "Not fonud directory: $NAME"
		fi
	done

	# 克隆 GitHub 仓库。同一源码树再次编译时目录已在，直接复用
	if [ -d "$REPO_PATH/.git" ]; then
		echo "Use existing repository: $REPO_PATH"
	else
		git clone --depth=1 --single-branch --branch $PKG_BRANCH "https://github.com/$PKG_REPO.git" $REPO_PATH

		# 处理克隆的仓库
		if [[ "$PKG_SPECIAL" == "pkg" ]]; then
			find $REPO_PATH/*/ -maxdepth 3 -type d -iname "*$PKG_NAME*" -prune -exec cp -rf {} ./package \;
			rm -rf $REPO_PATH
		fi
	fi
}

# 调用示例
# UPDATE_PACKAGE "OpenAppFilter" "destan19/OpenAppFilter" "master" "" "custom_name1 custom_name2"
# UPDATE_PACKAGE "open-app-filter" "destan19/OpenAppFilter" "master" "" "luci-app-appfilter oaf" 这样会把原有的open-app-filter，luci-app-appfilter，oaf相关组件删除，不会出现coremark错误。

# UPDATE_PACKAGE "包名" "项目地址" "项目分支" "pkg/name，可选，pkg为从大杂烩中单独提取包名插件；name为重命名为包名"
UPDATE_PACKAGE "aurora" "eamonxg/luci-theme-aurora" "master"
UPDATE_PACKAGE "aurora-config" "eamonxg/luci-app-aurora-config" "master"
UPDATE_PACKAGE "easytier" "EasyTier/luci-app-easytier" "main"
UPDATE_PACKAGE "luci-app-adguardhome" "GN01/luci-app-adguardhome" "main"
rm -rf ./package/packages
# HomeProxy 和 sing-box 用源码树自带的官方包。
# UPDATE_PACKAGE "homeproxy" "VIKINGYFY/packages" "main" "" "sing-box luci-app-homeproxy"

# HomeProxy 自带的中国 IP 和域名列表跟着 LuCI 源码走，常常落后几个月。
# 编译时取最新版写进镜像，来源和版本号与 HomeProxy 自己的更新脚本一致。
# 写在 ./files 里，不改 feeds，下次 feeds update 不会被本地改动卡住。下载失败就保留官方自带的版本。
HP_RES_DIR="./files/etc/homeproxy/resources"
UPDATE_HP_RES() {
	local res_name=$1
	local res_repo=$2
	local res_ref=$3
	local res_file=$4
	local auth=()
	[ -n "${GITHUB_TOKEN:-}" ] && auth=(-H "Authorization: Bearer $GITHUB_TOKEN")

	local res_info=$(curl -fsSL --max-time 30 "${auth[@]}" \
		"https://api.github.com/repos/$res_repo/commits?sha=$res_ref&path=$res_file&per_page=1" | python3 -c '
import json, re, sys
try:
	c = json.load(sys.stdin)[0]
	print(c["sha"], "".join(re.findall(r"[0-9-]+", c["commit"]["message"])).replace("-", ""))
except Exception:
	pass
')
	local res_sha=${res_info% *}
	local res_ver=${res_info#* }
	if [ -z "$res_info" ] || [ -z "$res_ver" ]; then
		echo "HomeProxy $res_name: failed to get the latest version, keep the bundled one"
		return
	fi

	local tmp_file=$(mktemp)
	if curl -fsSL --max-time 120 -o "$tmp_file" "https://raw.githubusercontent.com/$res_repo/$res_sha/$res_file" && [ -s "$tmp_file" ]; then
		[ "$res_name" = "china_list" ] && sed -i -e "s/full://g" -e "/:/d" "$tmp_file"
		mkdir -p "$HP_RES_DIR"
		chmod 644 "$tmp_file"
		mv -f "$tmp_file" "$HP_RES_DIR/$res_name.txt"
		echo "$res_ver" > "$HP_RES_DIR/$res_name.ver"
		echo "HomeProxy $res_name: $res_ver"
	else
		rm -f "$tmp_file"
		echo "HomeProxy $res_name: download failed, keep the bundled one"
	fi
}
if [ -d ./feeds/luci/applications/luci-app-homeproxy ]; then
	UPDATE_HP_RES "china_ip4" "1715173329/IPCIDR-CHINA" "master" "ipv4.txt"
	UPDATE_HP_RES "china_ip6" "1715173329/IPCIDR-CHINA" "master" "ipv6.txt"
	UPDATE_HP_RES "gfw_list" "Loyalsoldier/v2ray-rules-dat" "release" "gfw.txt"
	UPDATE_HP_RES "china_list" "Loyalsoldier/v2ray-rules-dat" "release" "direct-list.txt"
fi
# Bandix、OpenAppFilter 都依赖内核特性，并且和流量分载冲突，只编进 X86
if [[ "${WRT_TARGET,,}" == "x86" ]]; then
	UPDATE_PACKAGE "bandix" "timsaya/openwrt-bandix" "main"
	UPDATE_PACKAGE "luci-app-bandix" "timsaya/luci-app-bandix" "main"
	# https://github.com/destan19/OpenAppFilter 。先删掉 feeds 里的旧副本，避免编到过期的 oaf
	UPDATE_PACKAGE "OpenAppFilter" "destan19/OpenAppFilter" "master" "" "luci-app-oaf open-app-filter appfilter oaf"
fi

# 内核 6.12 会把空参数列表当成错误，上游 KCFLAGS 还没盖住 strict-prototypes
OAF_MAKE="./package/OpenAppFilter/oaf/Makefile"
if [ -f "$OAF_MAKE" ] && ! grep -q 'Wno-error=strict-prototypes' "$OAF_MAKE"; then
	awk '
		index($0, "-Wno-error=missing-prototypes") && !seen {
			sub(/-Wno-error=missing-prototypes/, "-Wno-error=strict-prototypes -Wno-error=missing-prototypes")
			seen = 1
		}
		{ print }
	' "$OAF_MAKE" > "$OAF_MAKE.tmp" && mv "$OAF_MAKE.tmp" "$OAF_MAKE"
fi

# Git稀疏克隆，只克隆指定目录到本地
function git_sparse_clone() {
	branch="$1" repourl="$2" && shift 2
	echo " "
	echo "========== Git Sparse Clone =========="
	echo "Repository: $repourl"
	echo "Branch: $branch"
	echo "Directories: $@"
	echo "======================================="
	git clone --depth=1 -b $branch --single-branch --filter=blob:none --sparse $repourl
	repodir=$(echo $repourl | awk -F '/' '{print $(NF)}')
	cd $repodir && git sparse-checkout set $@
	echo "Checking out: $@"
	mkdir -p ../package
	mv -f $@ ../package/
	echo "Moved to package/: $@"
	cd .. && rm -rf $repodir
	echo "Sparse clone completed!"
}

#删除官方的默认插件（保留dae/daed和adguardhome核心，luci-app-adguardhome使用GN01仓库版本）
rm -rf ./feeds/luci/applications/luci-app-{passwall*,mosdns,dockerman,bypass*,adguardhome}

#复制本地固化软件包（目录为空或不存在时跳过）
if [ -d "$GITHUB_WORKSPACE/Packages" ] && [ -n "$(ls -A "$GITHUB_WORKSPACE/Packages" 2>/dev/null)" ]; then
	cp -rf "$GITHUB_WORKSPACE/Packages/"* ./package/
fi

#更新软件包版本
UPDATE_VERSION() {
	local PKG_NAME=$1
	local PKG_MARK=${2:-false}
	local PKG_FILES=$(find ./package/ ./feeds/packages/ -maxdepth 3 -type f -wholename "*/$PKG_NAME/Makefile")

	if [ -z "$PKG_FILES" ]; then
		echo "$PKG_NAME not found!"
		return
	fi

	echo -e "\n$PKG_NAME version update has started!"

	for PKG_FILE in $PKG_FILES; do
		local PKG_REPO=$(grep -Po "PKG_SOURCE_URL:=https://.*github.com/\K[^/]+/[^/]+(?=.*)" $PKG_FILE)
		local PKG_TAG=$(curl -sL "https://api.github.com/repos/$PKG_REPO/releases" | jq -r "map(select(.prerelease == $PKG_MARK)) | first | .tag_name")

		local OLD_VER=$(grep -Po "PKG_VERSION:=\K.*" "$PKG_FILE")
		local OLD_URL=$(grep -Po "PKG_SOURCE_URL:=\K.*" "$PKG_FILE")
		local OLD_FILE=$(grep -Po "PKG_SOURCE:=\K.*" "$PKG_FILE")
		local OLD_HASH=$(grep -Po "PKG_HASH:=\K.*" "$PKG_FILE")

		local PKG_URL=$([[ "$OLD_URL" == *"releases"* ]] && echo "${OLD_URL%/}/$OLD_FILE" || echo "${OLD_URL%/}")

		local NEW_VER=$(echo $PKG_TAG | sed -E 's/[^0-9]+/\./g; s/^\.|\.$//g')
		local NEW_URL=$(echo $PKG_URL | sed "s/\$(PKG_VERSION)/$NEW_VER/g; s/\$(PKG_NAME)/$PKG_NAME/g")
		local NEW_HASH=$(curl -sL "$NEW_URL" | sha256sum | cut -d ' ' -f 1)

		echo "old version: $OLD_VER $OLD_HASH"
		echo "new version: $NEW_VER $NEW_HASH"

		if [[ "$NEW_VER" =~ ^[0-9].* ]] && dpkg --compare-versions "$OLD_VER" lt "$NEW_VER"; then
			sed -i "s/PKG_VERSION:=.*/PKG_VERSION:=$NEW_VER/g" "$PKG_FILE"
			sed -i "s/PKG_HASH:=.*/PKG_HASH:=$NEW_HASH/g" "$PKG_FILE"
			echo "$PKG_FILE version has been updated!"
		else
			echo "$PKG_FILE version is already the latest!"
		fi
	done
}

#引入私有扩展脚本
if [ -f "$GITHUB_WORKSPACE/Scripts/PRIVATE.sh" ]; then
	source "$GITHUB_WORKSPACE/Scripts/PRIVATE.sh"
fi
