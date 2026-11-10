#!/usr/bin/env bash
# 从 GitHub 源码编译 librime 引擎（含 lua / octagram / charcode 插件）
#
# 为什么自编译：Ubuntu 22.04 自带的 librime 1.7.3（2022 年）太旧，
# 雾凇拼音需要 librime ≥ 1.11（enable_word_completion 等特性）。
#
# 用法：
#   bash scripts/build-librime.sh [版本号]      # 默认 1.17.0
#   PREFIX=/usr/local bash scripts/build-librime.sh   # 可指定安装前缀
#
# 构建完成后需要 root 权限安装：
#   sudo cmake --install engine/librime/build && sudo ldconfig
set -euo pipefail

VERSION="${1:-1.17.0}"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENGINE_DIR="$REPO_DIR/engine/librime"
PREFIX="${PREFIX:-/usr/local}"

# 0) 依赖检查
for cmd in git cmake ninja g++ pkg-config; do
  command -v "$cmd" >/dev/null || { echo "✗ 缺少 $cmd（见 README 的 apt 安装命令）"; exit 1; }
done

# 1) 克隆源码（已存在则跳过）
if [[ ! -d "$ENGINE_DIR" ]]; then
  echo "== 克隆 librime $VERSION =="
  git clone --depth 1 --branch "$VERSION" https://github.com/rime/librime.git "$ENGINE_DIR"
fi

# 2) 安装插件（lua 必需——雾凇拼音的日期/计算器/置顶等全靠 lua；octagram 智能组句）
if [[ ! -d "$ENGINE_DIR/plugins/lua" || ! -d "$ENGINE_DIR/plugins/octagram" || ! -d "$ENGINE_DIR/plugins/charcode" ]]; then
  echo "== 安装插件（lua / octagram / charcode）=="
  (cd "$ENGINE_DIR" && bash install-plugins.sh \
    hchunhui/librime-lua lotem/librime-octagram rime/librime-charcode)
fi

# 3) 配置 + 构建
echo "== 构建 librime $VERSION（前缀 $PREFIX）=="
# 三个 Ubuntu 22.04 兼容性标志：
#   LINUX=ON —— 上游用 if(LINUX) 判断平台，该变量在本机 cmake 求值为假，
#      导致 find_package(Boost) 不请求 regex 组件、链接时缺 libboost_regex
#   Boost_NO_BOOST_CMAKE=ON —— 系统 boost 的 cmake 配置目标有缺陷（locale 拒绝
#      debug-runtime 变体），改用经典头文件+库文件查找模式
#   ENABLE_LOGGING=OFF —— 系统 glog 0.5 缺少 librime 1.17 需要的 API，禁用引擎日志
cmake -S "$ENGINE_DIR" -B "$ENGINE_DIR/build" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DBUILD_TEST=OFF \
  -DBUILD_MERGED_PLUGINS=ON \
  -DLINUX=ON \
  -DBoost_NO_BOOST_CMAKE=ON \
  -DENABLE_LOGGING=OFF

cmake --build "$ENGINE_DIR/build" -j"$(nproc)"

echo
echo "✓ 构建完成。安装需要 root 权限："
echo "    sudo cmake --install $ENGINE_DIR/build"
echo "    sudo ldconfig"
echo "安装后验证：$(which rime_deployer 2>/dev/null || echo rime_deployer) 应来自 $PREFIX/bin"
