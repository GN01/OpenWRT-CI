#!/usr/bin/env bash
# 本地编译 X86（飞牛 fnOS 虚拟机）
#   ./build_X86.sh
#   SKIP_FEEDS=1 ./build_X86.sh
# 源码：immortalwrt/immortalwrt 的 openwrt-25.12。源码目录：./wrt-x86

set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"

chmod +x Scripts/*.sh
sed -i 's/\r$//' Scripts/*.sh Config/*.txt 2>/dev/null || true

export GITHUB_WORKSPACE="$PWD"
WRT_DIR="$PWD/wrt-x86"
export GITHUB_ENV="$WRT_DIR/.wrt.env"

export WRT_CONFIG="X86"
export WRT_THEME="${WRT_THEME:-aurora}"
export WRT_NAME="${WRT_NAME:-OWRT}"
export WRT_SSID="${WRT_SSID:-OWRT}"
export WRT_WORD="${WRT_WORD:-12345678}"
export WRT_IP="${WRT_IP:-192.168.0.1}"
export WRT_PW="${WRT_PW:-无}"
export WRT_REPO="${WRT_REPO:-https://github.com/immortalwrt/immortalwrt.git}"
export WRT_BRANCH="${WRT_BRANCH:-openwrt-25.12}"
export WRT_SOURCE="${WRT_SOURCE:-immortalwrt/immortalwrt}"
export WRT_PACKAGE="${WRT_PACKAGE:-}"
export WRT_TEST="${WRT_TEST:-false}"
export WRT_DATE
WRT_DATE="$(TZ=UTC-8 date +"%y.%m.%d-%H.%M.%S")"
export WRT_MARK="${WRT_MARK:-GN01}"
export WRT_INFO="${WRT_SOURCE%%/*}"
export WRT_WIFI="none"

CONFIG_FILE="$GITHUB_WORKSPACE/Config/${WRT_CONFIG}.txt"
export WRT_TARGET
WRT_TARGET="$(grep -m 1 -oP '^CONFIG_TARGET_\K[^=_]+(?=\=y)' "$CONFIG_FILE")"

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

if [ "${SKIP_FEEDS:-0}" != "1" ]; then
	./scripts/feeds update -a
	./scripts/feeds install -a
fi

"$GITHUB_WORKSPACE/Scripts/Packages.sh"
"$GITHUB_WORKSPACE/Scripts/Handles.sh"

rm -f .config
cat "$CONFIG_FILE" "$GITHUB_WORKSPACE/Config/GENERAL.txt" >> .config
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
	find ./bin/targets/ -type f \( \
		-iname "*${WRT_TARGET}*" -o \
		-name "*.bin" -o -name "*.itb" -o \
		-name "*.img" -o -name "*.img.gz" \
	\) -exec cp -f {} ./upload/ \; 2>/dev/null || true
fi

echo "======== 编译完成 ========"
echo "固件目录: $WRT_DIR/bin/targets/"
echo "打包目录: $WRT_DIR/upload/"
ls -lh ./upload/ || true
