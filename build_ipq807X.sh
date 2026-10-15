#!/usr/bin/env bash
# 本地编译 IPQ807X-WIFI-NO（阿里云 AP8220）
#   ./build_ipq807X.sh
#   SKIP_FEEDS=1 ./build_ipq807X.sh
# 源码：VIKINGYFY/immortalwrt 的 main。与 IPQ60XX 共用 ./wrt

set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"

chmod +x Scripts/*.sh
sed -i 's/\r$//' Scripts/*.sh Config/*.txt 2>/dev/null || true

export GITHUB_WORKSPACE="$PWD"
WRT_DIR="$PWD/wrt"
export GITHUB_ENV="$WRT_DIR/.wrt.env"

export WRT_CONFIG="IPQ807X-WIFI-NO"
export WRT_THEME="${WRT_THEME:-aurora}"
export WRT_NAME="${WRT_NAME:-OWRT}"
export WRT_SSID="${WRT_SSID:-OWRT}"
export WRT_WORD="${WRT_WORD:-12345678}"
export WRT_IP="${WRT_IP:-192.168.0.1}"
export WRT_PW="${WRT_PW:-无}"
export WRT_REPO="${WRT_REPO:-https://github.com/VIKINGYFY/immortalwrt.git}"
export WRT_BRANCH="${WRT_BRANCH:-main}"
export WRT_SOURCE="${WRT_SOURCE:-VIKINGYFY/immortalwrt}"
export WRT_PACKAGE="${WRT_PACKAGE:-}"
export WRT_TEST="${WRT_TEST:-false}"
export WRT_DATE
WRT_DATE="$(TZ=UTC-8 date +"%y.%m.%d-%H.%M.%S")"
export WRT_MARK="${WRT_MARK:-GN01}"
export WRT_INFO="${WRT_SOURCE%%/*}"
export WRT_WIFI="WIFI-NO"

CONFIG_FILE="$GITHUB_WORKSPACE/Config/${WRT_CONFIG}.txt"
export WRT_TARGET WRT_SUBTARGET
WRT_TARGET="$(grep -m 1 -oP '^CONFIG_TARGET_\K[^=_]+(?=\=y)' "$CONFIG_FILE")"
WRT_SUBTARGET="$(grep -m 1 -oP "^CONFIG_TARGET_${WRT_TARGET}_\K[^=_]+(?=\=y)" "$CONFIG_FILE")"

echo "======== 编译配置 ========"
echo "WRT_CONFIG=$WRT_CONFIG"
echo "WRT_TARGET=$WRT_TARGET"
echo "WRT_WIFI=$WRT_WIFI"
echo "WRT_REPO=$WRT_REPO"
echo "WRT_BRANCH=$WRT_BRANCH"
echo "WRT_DIR=$WRT_DIR"
echo "=========================="

if [ ! -d "$WRT_DIR/.git" ]; then
	echo "克隆源码..."
	git clone --depth=1 --single-branch --branch "$WRT_BRANCH" "$WRT_REPO" "$WRT_DIR"
fi
: > "$GITHUB_ENV"
export WRT_HASH
WRT_HASH="$(git -C "$WRT_DIR" log -1 --pretty=format:'%h')"

cd "$WRT_DIR"

stamp="$WRT_DIR/.wrt-target"
target_id="$WRT_TARGET/$WRT_SUBTARGET"
if [ -f "$stamp" ] && [ "$(cat "$stamp")" != "$target_id" ]; then
	echo "从 $(cat "$stamp") 切换到 $target_id，清理上一个目标的编译产物"
	rm -rf tmp .config bin build_dir/target-* staging_dir/target-* staging_dir/packages
fi
echo "$target_id" > "$stamp"

if [ "${SKIP_FEEDS:-0}" != "1" ]; then
	./scripts/feeds update -a
	./scripts/feeds install -a
fi

"$GITHUB_WORKSPACE/Scripts/Packages.sh"
"$GITHUB_WORKSPACE/Scripts/Handles.sh"

rm -f .config
cat "$CONFIG_FILE" "$GITHUB_WORKSPACE/Config/GENERAL.txt" >> .config
# 同一份源码重复编译时先还原状态页，Settings.sh 只追加一次日期
git -C feeds/luci checkout -- modules/luci-mod-status/htdocs/luci-static/resources/view/status/include/10_system.js
"$GITHUB_WORKSPACE/Scripts/Settings.sh"
set -a
# shellcheck disable=SC1091
source "$GITHUB_ENV"
set +a

make defconfig -j"$(nproc)"
make download -j"$(nproc)"
make -j"$(nproc)" || make -j1 V=s

mkdir -p ./upload
cp -f ./.config "./upload/Config-${WRT_CONFIG}-${WRT_INFO}-${WRT_BRANCH}-${WRT_DATE}.txt"
if [ "${WRT_TEST}" != "true" ]; then
	find ./bin/targets/ -type f \( -iname "*${WRT_TARGET}*" -o -name "*.bin" -o -name "*.itb" -o -name "*.img.gz" \) \
		-exec cp -f {} ./upload/ \; 2>/dev/null || true
fi

echo "======== 编译完成 ========"
echo "固件目录: $WRT_DIR/bin/targets/"
echo "打包目录: $WRT_DIR/upload/"
ls -lh ./upload/ || true
