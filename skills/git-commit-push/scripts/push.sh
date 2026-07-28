#!/usr/bin/env bash
# git-commit-push / push.sh — 推送当前分支；无上游则 -u
#
# 安全:
#   - 默认拒绝直推 main / master
#   - 远程名可用 COMMIT_PUSH_REMOTE 覆盖（默认 origin）
#   - 需强制推送主分支：COMMIT_PUSH_ALLOW_MAIN=1
#   - 失败时分类提示，避免模型乱试命令
set -euo pipefail

git rev-parse --is-inside-work-tree >/dev/null
branch="$(git rev-parse --abbrev-ref HEAD)"

case "$branch" in
  main|master)
    if [ "${COMMIT_PUSH_ALLOW_MAIN:-0}" != "1" ]; then
      echo "错误：当前分支为 ${branch}，默认不直推主分支（git flow）。" >&2
      echo "      请切到特性分支；确需推主分支设 COMMIT_PUSH_ALLOW_MAIN=1。" >&2
      exit 1
    fi
    ;;
esac

remote="${COMMIT_PUSH_REMOTE:-origin}"

if git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
  echo "→ git push ${remote} ${branch}"
  set +e
  out="$(git push "$remote" "$branch" 2>&1)"
  ec=$?
  set -e
else
  echo "→ git push -u ${remote} ${branch}"
  set +e
  out="$(git push -u "$remote" "$branch" 2>&1)"
  ec=$?
  set -e
fi

if [ "$ec" -ne 0 ]; then
  printf '%s\n' "$out" >&2
  echo "----" >&2
  case "$out" in
    *non-fast-forward*|*rejected*|*fetch\ first*)
      echo "提示：推送被拒（non-fast-forward）。先 git pull --rebase，再重试。" >&2
      ;;
    *Authentication*|*Permission*|*could\ not\ read\ Username*|*403*|*401*)
      echo "提示：认证失败。检查 SSH key / gh auth / 远程权限。" >&2
      ;;
    *does\ not\ appear\ to\ be\ a\ git\ repository*|*Repository\ not\ found*)
      echo "提示：远程仓库不存在或无权限。检查 git remote -v。" >&2
      ;;
    *)
      echo "提示：push 失败（exit $ec）。勿强推 main/master；勿用 --force 除非用户明确要求。" >&2
      ;;
  esac
  exit "$ec"
fi

printf '%s\n' "$out"
echo "✓ 已推送 ${branch}"
