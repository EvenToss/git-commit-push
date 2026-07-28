#!/usr/bin/env bash
# git-commit-push / analyze.sh — 一次输出紧凑结构化概览（低 token）
# 兼容 bash 3.2+（macOS 系统 bash）
#
# 用法: analyze.sh [信号行上限，默认150]
# 环境: ANALYZE_PREVIEW_LINES=20  ANALYZE_PER_FILE_SIGNAL=8
set -euo pipefail

CAP="${1:-150}"
PREVIEW_LINES="${ANALYZE_PREVIEW_LINES:-20}"
PER_FILE_SIGNAL="${ANALYZE_PER_FILE_SIGNAL:-8}"

JUNK_RE='(^|/)(node_modules|dist|build|target|\.idea|\.vscode|\.gradle|out|coverage)(/|$)|(^|/)\.DS_Store$|\.log$|^LOG_FILE|\.tmp$|\.swp$|\.bak$|\.iml$|\.class$|\.pyc$'
SECRET_NAME_RE='(^|/)\.env$|(^|/)\.env\.(local|production|prod|development|dev|staging|test)$|(^|/)id_(rsa|ed25519|ecdsa|dsa)$|\.(pem|p12|pfx|keystore|jks)$|(^|/)credentials\.json$|(^|/)service-account.*\.json$|(^|/)secrets?\.(ya?ml|json|toml)$'
SECRET_ALLOW_RE='\.env\.(example|sample|template|dist)$'
NOISE_DIRS='src|main|java|kotlin|resources|static|public|app|apps|web|views|components|pages|controller|controllers|service|services|mapper|mappers|dto|vo|entity|entities|model|models|domain|api|server|client|admin|shared|common|util|utils|lib|libs|test|tests|__tests__|spec|hooks|store|stores|types|type|com|org|net|io|internal|pkg|cmd|scripts|script|config|configs|assets|i18n|locales'

is_junk() { [[ "$1" =~ $JUNK_RE ]]; }
is_secret_name() {
  local f="$1"
  [[ "$f" =~ $SECRET_ALLOW_RE ]] && return 1
  [[ "$f" =~ $SECRET_NAME_RE ]]
}

is_textish() {
  local f="$1" mime
  mime="$(file -b --mime-type "$f" 2>/dev/null || echo unknown)"
  case "$mime" in
    text/*|application/json|application/xml|application/javascript|application/x-*script*|application/toml|application/yaml|application/x-yaml|inode/x-empty) return 0 ;;
  esac
  # 无 file 时：按扩展名兜底
  case "$f" in
    *.md|*.txt|*.json|*.yml|*.yaml|*.toml|*.xml|*.html|*.css|*.scss|*.js|*.jsx|*.ts|*.tsx|*.vue|*.java|*.kt|*.go|*.rs|*.py|*.rb|*.sh|*.sql|*.css|*.svg) return 0 ;;
  esac
  return 1
}

feature_key() {
  local path="$1" base dir stem key="" part
  base="${path##*/}"
  dir="${path%/*}"
  [ "$dir" = "$path" ] && dir="."

  stem="${base%.*}"
  stem="$(printf '%s' "$stem" | sed -E 's/(Controller|Service|Mapper|Repository|Impl|DTO|VO|Entity|Component|View|Page|Test|Spec|Hook)$//; s/[-_]+$//')"
  stem="$(printf '%s' "$stem" | tr '[:upper:]' '[:lower:]')"

  if [ "$dir" != "." ]; then
    # 从路径末段向前找非噪声目录
    local rest="$dir"
    while [ -n "$rest" ] && [ "$rest" != "." ]; do
      part="${rest##*/}"
      part="$(printf '%s' "$part" | tr '[:upper:]' '[:lower:]')"
      if [[ ! "$part" =~ ^($NOISE_DIRS)$ ]] && [[ ! "$part" =~ ^[a-z]$ ]] && [ "${#part}" -ge 2 ]; then
        key="$part"
        break
      fi
      if [ "$rest" = "${rest##*/}" ]; then
        rest=""
      else
        rest="${rest%/*}"
      fi
    done
  fi

  if [ -n "$key" ]; then
    printf '%s' "$key"
  elif [ -n "$stem" ]; then
    printf '%s' "$stem"
  else
    printf '%s' "_misc"
  fi
}

guess_type() {
  local path="$1" base="${1##*/}"
  case "$path" in
    .github/*|*/.github/*|Jenkinsfile|*/Jenkinsfile|.gitlab-ci.yml|*/.gitlab-ci.yml) echo ci; return ;;
  esac
  case "$base" in
    package.json|package-lock.json|pnpm-lock.yaml|yarn.lock|pom.xml|go.mod|go.sum|Cargo.toml|Cargo.lock|Gemfile|Gemfile.lock|composer.json|composer.lock|Dockerfile|Dockerfile.*|docker-compose.yml|docker-compose.yaml|*.gradle|settings.gradle|settings.gradle.kts) echo build; return ;;
    *.md|*.mdx|LICENSE|LICENSE.*|CHANGELOG|CHANGELOG.*|AUTHORS|AUTHORS.*) echo docs; return ;;
    *.sql) echo chore; return ;;
    *.sh|*.bash|*.zsh) echo chore; return ;;
    *Test.*|*Spec.*|*_test.*|*.test.*|*.spec.*) echo test; return ;;
    *.yml|*.yaml|*.toml|*.ini|*.cfg|*.conf|.editorconfig|.gitignore|.npmrc|tsconfig.json|tsconfig.*.json) echo chore; return ;;
  esac
  case "$path" in
    */test/*|*/tests/*|*/__tests__/*|*/spec/*) echo test; return ;;
    docs/*|*/docs/*) echo docs; return ;;
    *migrate*|*migration*) echo chore; return ;;
  esac
  echo "?"
}

# ── 仓库检查 ──────────────────────────────────────────────
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "ERROR: not a git repo"
  exit 2
fi

repo_root="$(git rev-parse --show-toplevel)"
echo "root: $repo_root"
echo

# ── 冲突 ─────────────────────────────────────────────────
echo "## conflict"
conflicted="$(git diff --name-only --diff-filter=U 2>/dev/null || true)"
unmerged="$(git ls-files -u 2>/dev/null || true)"
if [ -n "$conflicted" ] || [ -n "$unmerged" ]; then
  echo "YES"
  if [ -n "$conflicted" ]; then
    printf '%s\n' "$conflicted" | sed 's/^/  /'
  else
    printf '%s\n' "$unmerged" | awk '{print $4}' | sort -u | sed 's/^/  /'
  fi
  echo
  echo "STOP: resolve merge conflicts before committing."
  exit 2
fi
echo "NO"
echo

# ── 近史 ─────────────────────────────────────────────────
echo "## log"
git log -5 --oneline --no-decorate 2>/dev/null || echo "(no commits yet)"
echo

tracked_dirty=0
git diff --quiet HEAD 2>/dev/null || tracked_dirty=1
untracked="$(git ls-files --others --exclude-standard 2>/dev/null || true)"

if [ "$tracked_dirty" -eq 0 ] && [ -z "$untracked" ]; then
  echo "## status"
  echo "clean"
  exit 0
fi

# ── 文件清单：name-status + numstat（awk 合并，无关联数组）──
echo "## files"
tmp_ns="$(mktemp)"
tmp_num="$(mktemp)"
tmp_all="$(mktemp)"
tmp_grp="$(mktemp)"
trap 'rm -f "$tmp_ns" "$tmp_num" "$tmp_all" "$tmp_grp"' EXIT

git diff HEAD --name-status 2>/dev/null >"$tmp_ns" || true
git diff HEAD --numstat 2>/dev/null >"$tmp_num" || true

if [ ! -s "$tmp_ns" ]; then
  echo "(no tracked changes)"
else
  awk -F '\t' '
    FNR==NR {
      if (NF >= 3 && $1 != "-" && $2 != "-") {
        # rename: plus minus old new
        if (NF == 4) { plus[$4]=$1; minus[$4]=$2 }
        else { plus[$3]=$1; minus[$3]=$2 }
      } else if (NF >= 3) {
        if (NF == 4) { plus[$4]="bin"; minus[$4]="bin" }
        else { plus[$3]="bin"; minus[$3]="bin" }
      }
      next
    }
    {
      status=$1
      if (NF == 3) {
        disp=$2 " -> " $3; path=$3
      } else {
        disp=$2; path=$2
      }
      p=(path in plus)?plus[path]:"0"
      m=(path in minus)?minus[path]:"0"
      printf "%s\t%s\t+%s\t-%s\n", status, disp, p, m
    }
  ' "$tmp_num" "$tmp_ns"
fi
echo

# ── 未跟踪 / 跳过 / 密钥 ─────────────────────────────────
echo "## untracked"
junk_list=""
legit_list=""
secret_list=""

while IFS= read -r f; do
  [ -z "$f" ] && continue
  if is_secret_name "$f"; then
    secret_list="${secret_list}${f}"$'\n'
  fi
  if is_junk "$f"; then
    junk_list="${junk_list}${f}"$'\n'
  else
    legit_list="${legit_list}${f}"$'\n'
    printf '%s\n' "$f" >>"$tmp_all"
  fi
done <<< "$untracked"

# tracked 路径也进 all + 密钥扫描
while IFS=$'\t' read -r status path path2; do
  [ -z "${path:-}" ] && continue
  if [ -n "${path2:-}" ]; then
    printf '%s\n' "$path2" >>"$tmp_all"
    is_secret_name "$path2" && secret_list="${secret_list}${path2}"$'\n'
    is_secret_name "$path" && secret_list="${secret_list}${path}"$'\n'
  else
    printf '%s\n' "$path" >>"$tmp_all"
    is_secret_name "$path" && secret_list="${secret_list}${path}"$'\n'
  fi
done <"$tmp_ns"

if [ -z "$legit_list" ]; then
  echo "(none)"
else
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    if [ -f "$f" ]; then
      if is_textish "$f"; then
        lc="$(wc -l < "$f" 2>/dev/null | tr -d ' ' || echo '?')"
        echo "NEW $f ($lc lines)"
        echo "---"
        head -n "$PREVIEW_LINES" "$f" 2>/dev/null || true
        echo "---"
      else
        sz="$(wc -c < "$f" 2>/dev/null | tr -d ' ' || echo '?')"
        echo "NEW $f (binary/non-text, ${sz} bytes)"
      fi
    else
      echo "NEW $f (dir or missing)"
    fi
  done <<< "$legit_list"
fi
echo

echo "## skipped"
if [ -z "$junk_list" ]; then
  echo "(none)"
else
  printf '%s' "$junk_list"
fi
echo

echo "## secrets"
if [ -z "$secret_list" ]; then
  echo "(none)"
else
  printf '%s' "$secret_list" | sort -u | while IFS= read -r s; do
    [ -z "$s" ] && continue
    echo "WARN $s"
  done
  echo "NOTE: do not commit secrets unless user explicitly insists; prefer skip."
fi
echo

# ── hunk 信号（文件头 + @@ + 短 ± 样例，非全文）──────────
echo "## signals"
signal_lines=0
file_lines=0
truncated=0

emit_sig() {
  if [ "$signal_lines" -ge "$CAP" ]; then
    truncated=1
    return 1
  fi
  printf '%s\n' "$1"
  signal_lines=$((signal_lines + 1))
  return 0
}

while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in
    diff\ --git\ *)
      current_file="${line##* b/}"
      file_lines=0
      emit_sig "FILE $current_file" || break
      ;;
    @@*)
      [ "$file_lines" -ge "$PER_FILE_SIGNAL" ] && continue
      emit_sig "$line" || break
      file_lines=$((file_lines + 1))
      ;;
    +++\ *|---\ *)
      continue
      ;;
    +*|-*)
      # hunk body (+/- lines); ---/+++ already skipped above
      [ "$file_lines" -ge "$PER_FILE_SIGNAL" ] && continue
      if [ "${#line}" -gt 120 ]; then
        line="$(printf '%s' "$line" | cut -c1-117)..."
      fi
      emit_sig "$line" || break
      file_lines=$((file_lines + 1))
      ;;
  esac
done < <(git diff HEAD --unified=0 2>/dev/null || true)

if [ "$signal_lines" -eq 0 ]; then
  echo "(no tracked hunks; changes are untracked-only)"
elif [ "$truncated" -eq 1 ]; then
  echo "... TRUNCATED at $CAP signal lines. For one unclear file only:"
  echo "    git diff HEAD --unified=0 -- <path>"
fi
echo

# ── 建议分组（临时文件：type\tkey\tpath）──────────────────
echo "## suggest-groups"
: >"$tmp_grp"
if [ ! -s "$tmp_all" ]; then
  echo "(none)"
else
  sort -u "$tmp_all" | while IFS= read -r p; do
    [ -z "$p" ] && continue
    gt="$(guess_type "$p")"
    fk="$(feature_key "$p")"
    case "$gt" in
      build|docs|ci) key="$gt" ;;
      chore) key="chore:$fk" ;;
      test) key="test:$fk" ;;
      *) key="feat:$fk" ;;
    esac
    printf '%s\t%s\t%s\n' "$gt" "$key" "$p"
  done >"$tmp_grp"

  # 按 key 聚合输出（兼容 BSD awk / bash 3.2）
  cut -f2 "$tmp_grp" | sort -u | {
    idx=1
    while IFS= read -r key; do
      [ -z "$key" ] && continue
      lines="$(awk -F '\t' -v k="$key" '$2==k{print $3}' "$tmp_grp")"
      types="$(awk -F '\t' -v k="$key" '$2==k{print $1}' "$tmp_grp" | sort -u)"
      n="$(printf '%s\n' "$lines" | grep -c . || true)"
      tcount="$(printf '%s\n' "$types" | grep -c . || true)"
      if [ "$tcount" -eq 1 ]; then
        t="$types"
        [ "$t" = "?" ] && t="?"
      else
        # 混合时：若含 ? 与确定类型，取确定；多个确定则 ?
        t="$(printf '%s\n' "$types" | grep -v '^[?]$' | head -1 || true)"
        [ -z "$t" ] && t="?"
        if [ "$(printf '%s\n' "$types" | grep -v '^[?]$' | sort -u | grep -c . || true)" -gt 1 ]; then
          t="?"
        fi
      fi
      # 显示
      if [ "$n" -ge 4 ]; then
        first="$(printf '%s\n' "$lines" | head -1)"
        common="${first%/*}"
        same=1
        while IFS= read -r x; do
          [ -z "$x" ] && continue
          case "$x" in
            "$common"/*|"$common") ;;
            *) same=0; break ;;
          esac
        done <<< "$lines"
        echo "G${idx} ${t}  ${n} files"
        if [ "$same" -eq 1 ] && [ -n "$common" ] && [ "$common" != "$first" ]; then
          echo "     # ${common}/**"
        fi
        printf '%s\n' "$lines" | sed 's/^/     /'
      else
        flat="$(printf '%s\n' "$lines" | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
        echo "G${idx} ${t}  $flat"
      fi
      idx=$((idx + 1))
    done
  }
fi

echo
echo "HINT: confirm/adjust groups; write '<type>: <中文简述>'; commit-group.sh per group; then push.sh"
echo "RULE: same feature FE+BE = one commit; never git add -A; never read full source files"
