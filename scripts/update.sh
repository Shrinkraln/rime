#!/usr/bin/env bash
# 更新上游雾凇拼音（子模块）到最新版并重新部署
#
# 用法：bash scripts/update.sh
# 更新前建议先 bash scripts/save.sh 备份词频，再 git commit，保持历史干净。
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"

echo "== 拉取雾凇拼音上游最新代码 =="
git submodule update --remote rime-ice

if git diff --quiet -- rime-ice && git diff --cached --quiet -- rime-ice; then
  echo "上游已是最新，无需提交。"
else
  git add rime-ice
  git commit -m "chore: 更新雾凇拼音上游子模块

Co-Authored-By: Claude Code <noreply@anthropic.com>"
fi

exec bash "$REPO_DIR/scripts/deploy.sh"
