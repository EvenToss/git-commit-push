#!/usr/bin/env bash
# git-commit-push / push.sh — 推送当前分支；无上游则 -u
#
# 安全:
#   - 默认拒绝直推 main / master
#   - 远程名可用 COMMIT_PUSH_REMOTE 覆盖（默认 origin）
#   - 默认优先走 SSH：标准 HTTP(S) 远程会临时转成 git@host:owner/repo.git
#   - 需强制推送主分支：COMMIT_PUSH_ALLOW_MAIN=1
#   - 失败时分类提示，避免模型乱试命令
set -euo pipefail

to_ssh_url() {
  case "$1" in
    git@*:*|ssh://*)
      printf '%s\n' "$1"
      ;;
    https://*/*|http://*/*)
      local raw="${1#http://}"
      raw="${raw#https://}"
      local host="${raw%%/*}"
      local repo="${raw#*/}"
      repo="${repo%.git}"
      printf 'git@%s:%s.git\n' "$host" "$repo"
      ;;
    *)
      printf '%s\n' "$1"
      ;;
  esac
}

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
remote_url="$(git remote get-url "$remote" 2>/dev/null || true)"

if [ -z "$remote_url" ]; then
  echo "错误：找不到远程 ${remote}。请检查 git remote -v。" >&2
  exit 1
fi

push_target="$(to_ssh_url "$remote_url")"
using_ssh=0
if [ "$push_target" != "$remote_url" ]; then
  using_ssh=1
fi

push_desc="$remote"
if [ "$using_ssh" -eq 1 ]; then
  push_desc="${remote} (SSH)"
fi

if git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
  echo "→ git push ${push_desc} ${branch}"
  set +e
  out="$(git push "$push_target" "HEAD:${branch}" 2>&1)"
  ec=$?
  set -e
else
  echo "→ git push -u ${push_desc} ${branch}"
  set +e
  out="$(git push "$push_target" "HEAD:${branch}" 2>&1)"
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
if ! git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
  git fetch "$remote" "$branch" >/dev/null 2>&1 || true
  git branch --set-upstream-to="${remote}/${branch}" "$branch" >/dev/null 2>&1 || true
fi
echo "✓ 已推送 ${branch}"
