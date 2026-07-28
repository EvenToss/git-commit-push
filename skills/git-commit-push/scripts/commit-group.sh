#!/usr/bin/env bash
# git-commit-push / commit-group.sh — 显式路径暂存并提交一个原子组
#
# 用法:
#   commit-group.sh "<type>: <中文简述>" <path1> [path2 ...]
#   commit-group.sh --dry-run "<type>: <简述>" <path1> ...
#
# 环境:
#   COMMIT_BODY="补充说明"   作为第二个 -m
#   COMMIT_DRY_RUN=1         只打印将执行的操作，不 add/commit
#
# 安全:
#   - 必须显式路径，绝不 git add -A / git add .
#   - 校验 conventional 中文前缀格式
#   - 暂存后无差异则跳过
#   - 钩子失败时打印完整 stderr（不吞掉）
set -euo pipefail

TYPES='feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert'

dry_run=0
if [ "${1:-}" = "--dry-run" ]; then
  dry_run=1
  shift
fi
if [ "${COMMIT_DRY_RUN:-0}" = "1" ]; then
  dry_run=1
fi

if [ $# -lt 2 ]; then
  echo "用法: commit-group.sh [--dry-run] \"<type>: <简述>\" <path1> [path2 ...]" >&2
  exit 64
fi

msg="$1"; shift
paths=("$@")

if [[ ! "$msg" =~ ^($TYPES):\ .+$ ]]; then
  echo "错误：提交信息须匹配 '<type>: <简述>'" >&2
  echo "      type ∈ {feat,fix, docs, style, refactor, perf, test, build, ci, chore, revert}" >&2
  echo "      收到: $msg" >&2
  exit 64
fi

# 简述不应为空（正则已保证有内容）；警告英文-only / 过长
body_part="${msg#*: }"
if [ "${#body_part}" -gt 50 ]; then
  echo "警告：简述偏长（${#body_part} 字），建议 ≤30 字" >&2
fi

git rev-parse --is-inside-work-tree >/dev/null

if [ "$dry_run" -eq 1 ]; then
  echo "DRY-RUN commit: $msg"
  if [ -n "${COMMIT_BODY:-}" ]; then
    echo "DRY-RUN body: $COMMIT_BODY"
  fi
  echo "DRY-RUN paths:"
  for p in "${paths[@]}"; do echo "  $p"; done
  exit 0
fi

# 显式路径暂存
git add -- "${paths[@]}"

if git diff --cached --quiet; then
  echo "警告：暂存后无差异，跳过提交（文件无变化或被 .gitignore 忽略）" >&2
  exit 0
fi

set +e
if [ -n "${COMMIT_BODY:-}" ]; then
  out="$(git commit -m "$msg" -m "$COMMIT_BODY" 2>&1)"
  ec=$?
else
  out="$(git commit -m "$msg" 2>&1)"
  ec=$?
fi
set -e

if [ "$ec" -ne 0 ]; then
  echo "错误：git commit 失败（exit $ec）。钩子或 pre-commit 输出如下：" >&2
  printf '%s\n' "$out" >&2
  exit "$ec"
fi

# 成功：一行摘要 + 文件统计
git show --stat --oneline HEAD
