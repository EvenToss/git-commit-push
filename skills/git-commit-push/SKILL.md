---
name: git-commit-push
description: "分析当前 git 仓库改动，按逻辑功能拆成多个原子提交（强制中文 feat:/fix:/refactor:/docs:/chore: 等前缀，无 scope），逐个 commit 后自动 git push。可选集成 git-ship：创建 PR 并 squash merge（带安全门禁）。一次性脚本输出紧凑结构化概览 + 建议分组，极小化 token。当用户要求提交代码、commit、push、规范提交信息、整理工作区时使用。"
---

# git-commit-push

按功能拆成原子提交（中文 `<type>: …`）并自动 push。目标：规范 + 极低 token。

## 硬规则（省 token）

1. **只跑一次** `analyze.sh`；用其 `## suggest-groups` 确认/微调后写信息。
2. 仅当某文件归属仍不明时，才对 **单个** 文件：`git diff HEAD --unified=0 -- <path>`。
3. **禁止** `cat`/`read` 整份源码；**禁止**重复 `git status`/`git diff --stat`。
4. **禁止** `git add -A` / `git add .`；只用 `commit-group.sh` 显式路径。
5. 对用户只回 **每个 commit 一行**；勿复述完整 diff。

细则与类型表见同目录 `reference.md`（拿不准时再读）。

## 工作流

### 0. 定位 SD
脚本在本 SKILL.md 同级 `scripts/`。读到本文件后直接：

```bash
SD="<本 SKILL.md 所在目录>"
```

仅当路径未知时再 fallback 查找（保持 CWD 为**项目仓库**）：

```bash
SD="$(for b in "$HOME/.agents/skills" "$HOME/.pi/agent" "$HOME/.pi" ".pi"; do
        [ -d "$b" ] && find "$b" -maxdepth 8 -type f -name SKILL.md -path '*git-commit-push*' 2>/dev/null
      done | head -1)"
SD="$(dirname "$SD")"; [ -n "$SD" ] || { echo "找不到 git-commit-push" >&2; exit 1; }
```

### 1. 分析（一次）
```bash
bash "$SD/scripts/analyze.sh"
```
- 输出含 `conflict` / `log` / `files` / `untracked` 预览 / `secrets` / `signals` / `suggest-groups`。
- `conflict: YES` 或 `status: clean` → 停止并告知用户。
- `## secrets` 有 `WARN` → 默认跳过这些路径（除非用户明确要求提交）。

### 2. 分组 + 中文信息
以 `suggest-groups` 为起点：同功能前后端合并；配置/依赖单独 `chore`/`build`；宁可少拆勿碎拆。  
格式：`<type>: <中文简述>`（≤30 字、无 scope、无句号）。类型取值见 `reference.md`。

### 3. 逐组提交
```bash
bash "$SD/scripts/commit-group.sh" "feat: 增加按司机筛选轨迹" path1 path2
# 可选 body / 演练：
COMMIT_BODY="- 补充说明" bash "$SD/scripts/commit-group.sh" "feat: ..." path1
bash "$SD/scripts/commit-group.sh" --dry-run "feat: ..." path1
```

### 4. 推送
```bash
bash "$SD/scripts/push.sh"
```
默认拒推 `main`/`master`；若推送被拒（如 non-fast-forward），建议先 `git pull --rebase` 再重试。

### 4.5（可选）Ship：创建 PR 并 squash merge（借鉴 git-ship）
仅当用户明确表达“发布/提 PR 并合并/ship”意图，且你确认仓库允许 squash merge 时才启用。

1) 显示推送后的 ship 计划并要求用户确认：

```text
📦 Ready to ship:
  分支: <当前分支>
  目标: <main 或 master>（squash merge）
  行为: 创建 PR → squash merge → 删除远程分支 → 回到最新 main

继续？(y/n)
```

2) 用户确认后再运行：
```bash
COMMIT_SHIP_CONFIRM=1 \
COMMIT_SHIP_VALIDATE_CMD="（可选：填你希望执行的最小验证命令，如 npm test）" \
bash "$SD/scripts/ship-pr.sh"
```

`ship-pr.sh` 内置安全门禁：默认不会执行 merge，必须显式设置 `COMMIT_SHIP_CONFIRM=1`。

### 5. 汇报
```
✓ feat: 增加按司机筛选轨迹 (8 files)
✓ chore: 关闭调试日志 (1 file)
→ pushed to origin/feature/xxx
```

## 安全速查

| 项 | 行为 |
|---|---|
| 暂存 | 仅显式路径 |
| 垃圾文件 | analyze `## skipped` 默认不提交 |
| 密钥 | `## secrets` WARN，默认不提交 |
| 主分支 | 拒推；`COMMIT_PUSH_ALLOW_MAIN=1` 例外 |
| 推送被拒 | 如 non-fast-forward，先 `git pull --rebase` 再重试 |
| 空提交 | 跳过 |
| 只 commit 不 push | 做完第 3 步即可 |

环境变量：`COMMIT_PUSH_REMOTE`、`COMMIT_BODY`、`COMMIT_DRY_RUN=1`。

Ship 额外环境变量：
- `COMMIT_SHIP_CONFIRM=1`：确认门禁（必须）
- `COMMIT_SHIP_BASE`：主分支名（默认自动探测 main/master）
- `COMMIT_SHIP_REMOTE`：远程名（默认取 `COMMIT_PUSH_REMOTE` 或 `origin`）
- `COMMIT_SHIP_VALIDATE_CMD`：可选验证命令（失败会停止，不 merge）
- `COMMIT_SHIP_ADMIN=1`：可选；给 `gh pr merge` 增加 `--admin`（跳过部分要求）
