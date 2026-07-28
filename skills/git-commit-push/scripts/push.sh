#!/usr/bin/env bash
# git-commit-push / push.sh — 推送当前分支；无上游则 git push -u origin <branch>
#
# 安全特性：
#   - 默认拒绝直推 main / master（防误操作）
#   - 远程名可用 COMMIT_PUSH_REMOTE 覆盖（默认 origin）
#   - 需强制推送主分支：COMMIT_PUSH_ALLOW_MAIN=1
set -euo pipefail

git rev-parse --is-inside-work-tree >/dev/null
branch="$(git rev-parse --abbrev-ref HEAD)"

case "$branch" in
  main|master)
    if [ "${COMMIT_PUSH_ALLOW_MAIN:-0}" != "1" ]; then
      echo "错误：当前分支为 ${branch}，git-commit-push 默认不直推主分支（git flow 规范）。" >&2
      echo "      请切到特性分支后再推；确需推主分支设 COMMIT_PUSH_ALLOW_MAIN=1。" >&2
      exit 1
    fi
    ;;
esac

remote="${COMMIT_PUSH_REMOTE:-origin}"

if git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
  echo "→ git push"
  git push
else
  echo "→ git push -u ${remote} ${branch}"
  git push -u "$remote" "$branch"
fi

echo "✓ 已推送 ${branch}"
