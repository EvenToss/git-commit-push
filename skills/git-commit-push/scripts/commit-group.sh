#!/usr/bin/env bash
# git-commit-push / commit-group.sh — 用「显式路径」暂存并提交一个原子改动组
#
# 用法: commit-group.sh "<type>: <中文简述>" <path1> [path2 ...]
# 可选 body:  COMMIT_BODY="简短补充" commit-group.sh "..." <paths...>
#
# 安全特性：
#   - 必须显式给出路径，绝不 git add -A / git add .
#   - 暂存后若无差异则跳过，不产生空 commit
set -euo pipefail

if [ $# -lt 2 ]; then
  echo "用法: commit-group.sh \"<type>: <简述>\" <path1> [path2 ...]" >&2
  exit 64
fi

msg="$1"; shift
paths=("$@")

git rev-parse --is-inside-work-tree >/dev/null

# 显式路径暂存（新增/修改/删除均可，含未跟踪新文件）
git add -- "${paths[@]}"

if git diff --cached --quiet; then
  echo "警告：暂存后无差异，跳过提交（这些文件可能无变化或被 .gitignore 忽略）" >&2
  exit 0
fi

if [ -n "${COMMIT_BODY:-}" ]; then
  git commit -m "$msg" -m "$COMMIT_BODY" >/dev/null
else
  git commit -m "$msg" >/dev/null
fi

# 回显本次提交摘要（一条 oneline + 文件清单）
git show --stat --oneline HEAD
