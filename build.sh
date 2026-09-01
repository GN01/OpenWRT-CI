#!/usr/bin/env bash
# 本地一键编译，用法：
#   ./build.sh                      # 默认 IPQ60XX-WIFI-NO（京东云 AX1800 Pro）
#   ./build.sh IPQ807X-WIFI-NO      # 阿里云 AP8220
#   SKIP_FEEDS=1 ./build.sh         # 跳过 feeds 更新（二次编译更快）

set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"

chmod +x Scripts/*.sh
sed -i 's/\r$//' Scripts/*.sh Config/*.txt 2>/dev/null || true

export GITHUB_WORKSPACE="$PWD"
export GITHUB_ENV="$PWD/.wrt.env"
: > "$GITHUB_ENV"

export WRT_CONFIG="${1:-IPQ60XX-WIFI-NO}"
export WRT_THEME="${WRT_THEME:-bootstrap}"
export WRT_NAME="${WRT_NAME:-immortalwrt}"
export WRT_SSID="${WRT_SSID:-immortalwrt}"
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
export WRT_WIFI=wifi-yes

CONFIG_FILE="$GITHUB_WORKSPACE/Config/${WRT_CONFIG}.txt"
if [ ! -f "$CONFIG_FILE" ]; then
        echo "找不到配置文件: $CONFIG_FILE"
        echo "可用配置:"
        ls -1 Config/*.txt
        exit 1
fi

export WRT_TARGET
WRT_TARGET="$(grep -m 1 -oP '^CONFIG_TARGET_\K[\w]+(?=\=y)' "$CONFIG_FILE")"

echo "======== 编译配置 ========"
echo "WRT_CONFIG=$WRT_CONFIG"
echo "WRT_TARGET=$WRT_TARGET"
echo "WRT_REPO=$WRT_REPO"
echo "WRT_BRANCH=$WRT_BRANCH"
echo "=========================="

if [ ! -d ./wrt/.git ]; then
        echo "克隆源码..."
        git clone --depth=1 --single-branch --branch "$WRT_BRANCH" "$WRT_REPO" ./wrt
fi
export WRT_HASH
WRT_HASH="$(git -C ./wrt log -1 --pretty=format:'%h')"

cd ./wrt

if [ "${SKIP_FEEDS:-0}" != "1" ]; then
        ./scripts/feeds update -a
        ./scripts/feeds install -a
fi

cd ./package
"$GITHUB_WORKSPACE/Scripts/Packages.sh"
"$GITHUB_WORKSPACE/Scripts/Handles.sh"
cd ..

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
        find ./bin/targets/ -type f \( -iname "*${WRT_TARGET}*" -o -name "*.bin" -o -name "*.itb" -o -name "*.img.gz" \) \
                -exec cp -f {} ./upload/ \; 2>/dev/null || true
fi

echo "======== 编译完成 ========"
echo "固件目录: $GITHUB_WORKSPACE/wrt/bin/targets/"
echo "打包目录: $GITHUB_WORKSPACE/wrt/upload/"
ls -lh ./upload/ || true