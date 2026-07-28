#!/usr/bin/env bash
# git-commit-push / ship-pr.sh — 创建 PR 并 squash merge
#
# 目标：借鉴 git-ship 的安全门禁与发布流程，但保持与本项目现有“先 commit 再 push”模型兼容。
#
# 触发门禁（强制）：默认不执行 merge；只有显式设置 COMMIT_SHIP_CONFIRM=1 才会继续。
#
# 环境变量：
#   COMMIT_SHIP_CONFIRM      默认 0；设为 1 才会继续创建 PR/合并
#   COMMIT_SHIP_BASE         默认自动探测（main 优先，否则 master）
#   COMMIT_SHIP_REMOTE       默认取 COMMIT_PUSH_REMOTE 或 origin
#   COMMIT_SHIP_VALIDATE_CMD 可选：自定义验证命令（例如 'npm test'）
#   COMMIT_SHIP_ADMIN        默认 0；设为 1 时给 gh pr merge 增加 --admin（跳过部分要求/要求校验）

set -euo pipefail

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "ERROR: not a git repo" >&2
  exit 2
}

if [ "${COMMIT_SHIP_CONFIRM:-0}" != "1" ]; then
  echo "已拒绝执行：需要显式设置 COMMIT_SHIP_CONFIRM=1 才能创建 PR/合并。" >&2
  exit 64
fi

branch="$(git rev-parse --abbrev-ref HEAD)"

case "$branch" in
  main|master)
    if [ "${COMMIT_SHIP_ALLOW_MAIN:-0}" = "1" ]; then
      # 用户确实想在主分支上走后续：允许但仍会做额外校验
      :
    else
      echo "ERROR: 当前在 ${branch}。ship-pr.sh 只建议用于特性分支；请切到工作分支再重试。" >&2
      exit 1
    fi
    ;;
esac

# 只在工作区干净时发布（避免在合并期间产生额外提交/冲突）
if [ -n "$(git diff --name-only 2>/dev/null || true)" ]; then
  echo "ERROR: 工作区存在未提交改动，请先 commit 或 stash。" >&2
  exit 1
fi
untracked="$(git ls-files --others --exclude-standard 2>/dev/null || true)"
if [ -n "$untracked" ]; then
  echo "ERROR: 工作区存在未跟踪文件，请先 commit 或 stash。未跟踪示例：" >&2
  printf '%s\n' "$untracked" | sed -n '1,5p' >&2
  exit 1
fi

remote="${COMMIT_SHIP_REMOTE:-${COMMIT_PUSH_REMOTE:-origin}}"

base="${COMMIT_SHIP_BASE:-}"
if [ -z "$base" ]; then
  if git show-ref --quiet "refs/remotes/origin/main" || git show-ref --quiet "refs/heads/main"; then
    base="main"
  elif git show-ref --quiet "refs/remotes/origin/master" || git show-ref --quiet "refs/heads/master"; then
    base="master"
  else
    echo "ERROR: 无法自动探测主分支（main/master）。请设置 COMMIT_SHIP_BASE。" >&2
    exit 1
  fi
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "ERROR: 找不到 gh（GitHub CLI）。请先安装并登录：gh auth login" >&2
  exit 1
fi

# 确保 gh 已登录（不硬依赖 host，可按默认 GitHub 域检查）
set +e
gh auth status >/dev/null 2>&1
gh_ec=$?
set -e
if [ "$gh_ec" -ne 0 ]; then
  echo "ERROR: gh 未登录或认证失败。请先：gh auth login" >&2
  exit 1
fi

echo "## ship plan"
echo "  Branch: ${branch}"
echo "  Base:   ${base}"
echo "  Remote: ${remote}"

echo "## sync base (fetch only)"
git fetch "$remote" "$base" >/dev/null 2>&1 || {
  echo "ERROR: git fetch ${remote} ${base} 失败。" >&2
  exit 1
}

# 先检查是否已存在 PR（避免重复创建）
pr_number="$(gh pr list --head "$branch" --base "$base" --state open --limit 1 --json number --template '{{range .}}{{.number}}{{end}}' 2>/dev/null || true)"

title="$(git log -1 --pretty=%s 2>/dev/null || true)"
if [ -z "$title" ]; then
  title="ship: ${branch}"
fi

file_list="$(git diff --name-only "${remote}/${base}...HEAD" 2>/dev/null || true)"
file_list="${file_list#"${file_list%%[![:space:]]*}"}"
files_preview="$(printf '%s\n' "$file_list" | sed -n '1,30p' | tr '\n' ' ' | sed 's/[[:space:]]*$//')"

summ="$(git log -3 --pretty=%s 2>/dev/null || true)"
if [ -z "$summ" ]; then
  summ="$title"
fi
summ_bullets="$(printf '%s\n' "$summ" | sed 's/^/ - /' | sed '1,3p')"

pr_body="$(cat <<EOF
## Summary
$summ_bullets

## Files
$files_preview

🤖 Shipped via git-commit-push
EOF
)"

if [ -z "${pr_number:-}" ]; then
  echo "## create PR"
  pr_url="$(gh pr create --base "$base" --head "$branch" --title "$title" --body "$pr_body" 2>&1 | tail -n 1 || true)"
  if [ -z "$pr_url" ]; then
    # 有些情况下 gh pr create 输出不止最后一行；重新读一下 PR URL 更稳妥
    pr_number="$(gh pr list --head "$branch" --base "$base" --state open --limit 1 --json number --template '{{range .}}{{.number}}{{end}}' 2>/dev/null || true)"
  fi
else
  echo "## found existing PR"
fi

if [ -z "${pr_number:-}" ]; then
  echo "ERROR: 创建/定位 PR 失败（未获取到 PR number）。" >&2
  exit 1
fi

pr_url="${pr_url:-$(gh pr view "$pr_number" --json url --template '{{.url}}' 2>/dev/null || true)}"
echo "PR: ${pr_url:-#${pr_number}}"

if [ -n "${COMMIT_SHIP_VALIDATE_CMD:-}" ]; then
  echo "## validate"
  echo "Command: ${COMMIT_SHIP_VALIDATE_CMD}"
  set +e
  bash -lc "${COMMIT_SHIP_VALIDATE_CMD}" 2>&1
  v_ec=$?
  set -e
  if [ "$v_ec" -ne 0 ]; then
    echo "ERROR: validate 失败（exit ${v_ec}）。停止，不进行 merge。" >&2
    exit "$v_ec"
  fi
else
  echo "## validate"
  echo "（未设置 COMMIT_SHIP_VALIDATE_CMD，跳过验证）"
fi

echo "## merge (squash + delete-branch)"
merge_admin_flags=()
if [ "${COMMIT_SHIP_ADMIN:-0}" = "1" ]; then
  merge_admin_flags=(--admin)
fi

# 注意：gh pr merge 默认可能会有交互提示；本脚本假设你在能接受交互/或已提前确认的环境里使用。
gh pr merge "$pr_number" --squash --delete-branch "${merge_admin_flags[@]}"

echo "## return to ${base}"
git checkout "$base" >/dev/null 2>&1 || true
git pull --rebase "$remote" "$base" >/dev/null 2>&1 || true

# 合并后删除本地分支（如果仍存在且不在当前分支）
if [ "$branch" != "$base" ]; then
  git branch -D "$branch" >/dev/null 2>&1 || true
fi

echo "🚀 Ship 完成！"
echo "  ✓ ${pr_url:-PR #$pr_number} 已 squash merge 到 ${base}"
echo "  ✓ 当前在 ${base}（已尝试同步最新）"

