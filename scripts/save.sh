#!/usr/bin/env bash
# 把输入过程中积累的用户词频数据同步回仓库，实现个人词库的 git 版本化
#
# 用法：bash scripts/save.sh
# 之后 git status / git commit 即可提交你的词频积累。
#
# 同步内容：
#   - rime_ice.userdb.txt：用户词典文本快照（记录你输入过的词和使用次数，
#     这是「常用词排序优化」的核心数据，纯文本可 diff）
#   - my_phrase.txt：若你在输入法目录里直接改过个人短语
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RIME_DIR="${RIME_DIR:-$HOME/.config/ibus/rime}"

command -v rime_deployer >/dev/null || { echo "✗ 缺少 rime_deployer"; exit 1; }
[[ -d "$RIME_DIR" ]] || { echo "✗ 输入法目录不存在，先运行 scripts/deploy.sh"; exit 1; }

# 先触发一次部署，让引擎把 LevelDB 里的词频落盘成文本快照
rime_deployer --build "$RIME_DIR" >/dev/null 2>&1 || true

for f in rime_ice.userdb.txt user_dict.txt; do
  if [[ -f "$RIME_DIR/$f" ]]; then
    cp -f "$RIME_DIR/$f" "$REPO_DIR/user/$f"
    echo "✓ 已同步 $f（$(wc -l < "$RIME_DIR/$f") 行）"
  fi
done

if [[ -f "$RIME_DIR/my_phrase.txt" ]]; then
  if ! cmp -s "$RIME_DIR/my_phrase.txt" "$REPO_DIR/user/my_phrase.txt"; then
    cp -f "$RIME_DIR/my_phrase.txt" "$REPO_DIR/user/my_phrase.txt"
    echo "✓ 已同步 my_phrase.txt（检测到改动）"
  fi
fi

echo "完成。运行 git status 查看变更，git commit 提交即可。"
