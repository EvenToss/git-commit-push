#!/usr/bin/env bash
# commit-push / analyze.sh — 一次性输出紧凑改动概览，供分组写提交信息
#
# 设计目标：用「一次脚本调用」拿到分组所需的全部信息，
# 避免模型多次 cat / git diff 烧 token。模型据此分组即可，无需再读整个源码文件。
#
# 用法: analyze.sh [diff行数上限，默认500]
set -euo pipefail

CAP="${1:-500}"
# 未跟踪文件中疑似「产物/垃圾」的模式：默认跳过，不进 commit
JUNK_RE='(^|/)(node_modules|dist|build|target|\.idea|\.vscode|\.gradle|out|coverage)(/|$)|(^|/)\.DS_Store$|\.log$|^LOG_FILE|\.tmp$|\.swp$|\.bak$|\.iml$|\.class$|\.pyc$|(^|/)\.env[^/]*$'

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')"

upstream=""
ahead_behind=""
if u="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"; then
  [ -n "$u" ] && upstream="$u"
  if [ -n "$upstream" ]; then
    ab="$(git rev-list --left-right --count '@{u}...HEAD' 2>/dev/null || printf '0\t0')"
    behind="${ab%%$'\t'*}"; ahead="${ab##*$'\t'}"
    ahead_behind="(ahead ${ahead} / behind ${behind})"
  fi
fi

echo "══════════════════════════════════════════════════════════════"
echo " commit-push · 改动分析"
echo "══════════════════════════════════════════════════════════════"
echo "分支:   $branch"
if [ -n "$upstream" ]; then
  echo "上游:   $upstream $ahead_behind"
else
  echo "上游:   （未设置，push 时会自动 git push -u origin <branch>）"
fi
echo "根目录: $repo_root"
echo

tracked_clean=0; git diff --quiet HEAD 2>/dev/null || tracked_clean=1
untracked="$(git ls-files --others --exclude-standard 2>/dev/null || true)"

if [ "$tracked_clean" -eq 0 ] && [ -z "$untracked" ]; then
  echo "（工作区干净，没有可提交的改动）"
  echo "══════════════════════════════════════════════════════════════"
  exit 0
fi

echo "── 统计 (vs HEAD，含 staged+unstaged) ─────────────────────────"
git diff HEAD --stat 2>/dev/null || true
echo

echo "── 未跟踪文件 ──────────────────────────────────────────────────"
junk=(); legit=()
while IFS= read -r f; do
  [ -z "$f" ] && continue
  if [[ "$f" =~ $JUNK_RE ]]; then junk+=("$f"); else legit+=("$f"); fi
done <<< "$untracked"

if [ ${#legit[@]} -gt 0 ]; then
  for f in "${legit[@]}"; do
    lc="$(wc -l < "$f" 2>/dev/null | tr -d ' ' || echo '?')"
    echo " (new) $f  (${lc} lines)"
  done
else
  echo "（无）"
fi
echo

if [ ${#junk[@]} -gt 0 ]; then
  echo "── 已跳过（疑似产物/垃圾，默认不提交）──────────────────────────"
  for f in "${junk[@]}"; do echo " $f"; done
  echo "  ↑ 如确需提交其中某文件，在 commit-group.sh 里显式带上其路径即可。"
  echo
fi

echo "── 差异 (unified=0，仅变更行 + 函数上下文头) ───────────────────"
diff_out="$(git diff HEAD --unified=0 2>/dev/null || true)"
diff_lines="$(printf '%s\n' "$diff_out" | grep -c . || true)"
if [ "$diff_lines" -gt "$CAP" ]; then
  echo "⚠ 差异较大（约 ${diff_lines} 行 > 上限 ${CAP}），仅打印前 ${CAP} 行。"
  echo "  对归属不明的单文件可再跑: git diff HEAD --unified=0 -- <path>"
  echo "--------------------------------------------------------------"
  printf '%s\n' "$diff_out" | grep . | head -n "$CAP"
  echo "... (已截断，完整约 ${diff_lines} 行) ..."
elif [ "$diff_lines" -eq 0 ]; then
  echo "（已跟踪文件无差异；改动都在上面的「未跟踪文件」里）"
else
  printf '%s\n' "$diff_out"
fi
echo "══════════════════════════════════════════════════════════════"
