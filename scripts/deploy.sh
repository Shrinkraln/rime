#!/usr/bin/env bash
# 部署雾凇拼音 + 个人配置到 ibus-rime 用户目录，并重新构建词库
#
# 用法：bash scripts/deploy.sh
#   可用环境变量 RIME_DIR 指定 Rime 用户目录（默认 ~/.config/ibus/rime）
#
# 安全设计：
#   - 用户词频数据（rime_ice.userdb.txt / rime_ice.userdb/）永不覆盖
#   - 首次部署时旧输入法目录整体备份为 rime.bak-时间戳
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RIME_DIR="${RIME_DIR:-$HOME/.config/ibus/rime}"
SOURCE_DIR="$REPO_DIR/rime-ice"
USER_DIR="$REPO_DIR/user"

for cmd in rsync rime_deployer; do
  command -v "$cmd" >/dev/null || { echo "✗ 缺少命令 $cmd（先安装 ibus-rime 并编译 librime，见 README）"; exit 1; }
done
case "$(command -v rime_deployer)" in
  /usr/bin/*)
    echo "⚠  rime_deployer 来自系统包（librime 1.7.x），雾凇拼音需要 ≥1.11，请先运行 scripts/build-librime.sh";;
esac

# 首次部署：已有输入法目录但不是雾凇拼音时，整体备份
if [[ -d "$RIME_DIR" && ! -f "$RIME_DIR/rime_ice.schema.yaml" ]]; then
  bak="$RIME_DIR.bak-$(date +%Y%m%d-%H%M%S)"
  mv "$RIME_DIR" "$bak"
  echo "✓ 原输入法目录已备份到 $bak"
fi
mkdir -p "$RIME_DIR"

# 1) 同步雾凇拼音（上游子模块），排除运行时数据防止误删
echo "== 同步雾凇拼音上游 =="
rsync -a --delete \
  --exclude='.git' \
  --exclude='build' \
  --exclude='runLog.txt' \
  --exclude='rime_ice.userdb' \
  --exclude='*.userdb.txt' \
  --exclude='user_dict.txt' \
  --exclude='installation.yaml' \
  --exclude='log' \
  "$SOURCE_DIR/" "$RIME_DIR/"

# 2) 覆盖个人配置与词库（同样排除用户词频，绝不覆盖运行时数据）
echo "== 同步个人配置（user/）=="
rsync -a --exclude='*.userdb.txt' --exclude='user_dict.txt' "$USER_DIR/" "$RIME_DIR/"

# 3) 仓库里有用户词频快照而运行时没有时，恢复之（重装场景）
if [[ -f "$REPO_DIR/user/rime_ice.userdb.txt" && ! -f "$RIME_DIR/rime_ice.userdb.txt" ]]; then
  cp "$REPO_DIR/user/rime_ice.userdb.txt" "$RIME_DIR/"
  echo "✓ 已从仓库恢复用户词频快照"
fi

# 4) 重新构建（编译 prism/bin、把用户词典快照写入 LevelDB）
# 若上游词库源文件比已编译产物新（例如刚更新子模块），先清掉产物强制全量重建。
# 必须显式检查：主词库被 patch 成 my_words 后，rime_deployer 不会自动重建其
# import 的 rime_ice 等词库的旧产物。
if [[ -f "$RIME_DIR/build/rime_ice.table.bin" ]] &&
   find "$SOURCE_DIR/cn_dicts" "$SOURCE_DIR/en_dicts" -name '*.dict.yaml' \
     -newer "$RIME_DIR/build/rime_ice.table.bin" 2>/dev/null | grep -q .; then
  rm -f "$RIME_DIR"/build/*.bin
  echo "== 词库源有更新，强制全量重建 =="
fi
echo "== rime_deployer --build =="
rime_deployer --build "$RIME_DIR"

echo
echo "✓ 部署完成。"
echo "  - 输入法未生效时：注销并重新登录（GNOME Wayland 需要重启会话）"
echo "  - 之后用 scripts/save.sh 把积累的词频数据同步回仓库（git 版本化）"
