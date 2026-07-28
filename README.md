# git-commit-push · pi skill

> 把当前工作区的代码改动 **按功能拆成多个原子提交**（强制中文 `feat:/fix:/refactor:` 规范），逐个提交后 **自动 push**。专为 **规范团队提交信息 + 极低 token 消耗** 设计。

适用于 [pi](https://pi.dev)（及任何兼容 [Agent Skills](https://agentskills.io) 标准的 harness，如 Claude Code / Codex）。

---

## 它解决什么问题

- **习惯不统一**：一锅炖 commit 或信息乱写，review / 回滚痛苦。
- **手写规范信息累**：每次要想 type、分组、写中文简述。
- **AI 提交烧 token**：模型爱 `cat` 源码，上下文膨胀。

`git-commit-push` 用 **一次紧凑 analyze + 建议分组** 解决这三件事。

## 特性

- 🔪 **按功能拆分**：同功能前后端合一；配置单独 `chore`/`build`；脚本给出 `suggest-groups`。
- 🇨🇳 **强制中文规范信息**：`feat/fix/docs/style/refactor/perf/test/build/ci/chore/revert`，无 scope。
- 🚀 **提交后自动 push**（可关）。
- 默认优先使用 **SSH 远程推送**（标准 HTTP(S) remote 会自动转 SSH，适用于 GitHub / GitLab / Gitee）。
- 可选集成 git-ship：创建 PR 并 `squash merge`（带确认门禁）。
- 💸 **极低 token**：结构化概览（name-status / 信号样例 / 新文件预览），禁止读整文件。
- 🛡️ **安全默认**：显式路径、垃圾跳过、密钥 WARN、拒推 main/master、冲突即停、消息格式校验。

## 要求

- 兼容 Agent Skills 的 agent harness（pi / Claude Code / Codex …）
- `bash` 3.2+ + `git`（macOS 系统 bash 可用；Linux / Git Bash / WSL）

## 安装

> 仓库名 / 包名 / skill 名统一为 **`git-commit-push`**，斜杠命令 `/skill:git-commit-push`。

### 方式 A · pi package（推荐）

```bash
pi install git:github.com/EvenToss/git-commit-push
pi install git:github.com/EvenToss/git-commit-push@v1.3.0
pi update  git:github.com/EvenToss/git-commit-push
pi remove  git:github.com/EvenToss/git-commit-push
```

### 方式 B · clone 到全局 skills

```bash
git clone git@github.com:EvenToss/git-commit-push.git ~/.agents/skills/git-commit-push
```

### 方式 C · 项目级

```bash
pi install -l git:github.com/EvenToss/git-commit-push
```

写入 `.pi/settings.json` 后队友可自动安装。

## 用法

**安装后需重启 pi**。

- `/skill:git-commit-push`
- 或：「提交推送一下」「commit 这些改动」

流程：**analyze → 确认分组 → 逐组 commit → push →（可选 ship PR）→ 一行汇报**。

## 配置（环境变量）

| 变量 | 默认 | 作用 |
|---|---|---|
| `COMMIT_PUSH_ALLOW_MAIN` | `0` | `1` 允许直推 main/master |
| `COMMIT_PUSH_REMOTE` | `origin` | 远程名（默认优先用其 SSH URL 推送） |
| `COMMIT_BODY` | _(空)_ | commit 第二个 `-m` |
| `COMMIT_DRY_RUN` | `0` | `1` 或 `--dry-run` 只演练不提交 |
| `ANALYZE_PREVIEW_LINES` | `20` | 新文件预览行数 |
| `ANALYZE_PER_FILE_SIGNAL` | `8` | 每文件信号行上限 |

Ship（可选）额外环境变量：
- `COMMIT_SHIP_CONFIRM=1`：开启 PR 创建与 squash merge（必填，防止误触发）
- `COMMIT_SHIP_BASE`：主分支名（默认自动探测 main/master）
- `COMMIT_SHIP_REMOTE`：远程名（默认取 `COMMIT_PUSH_REMOTE` 或 `origin`）
- `COMMIT_SHIP_VALIDATE_CMD`：可选验证命令（失败会停止，不 merge）
- `COMMIT_SHIP_ADMIN=1`：可选；给 `gh pr merge` 增加 `--admin`

## 自定义

强制中文为默认。改英文 / scope / 前缀：编辑 `skills/git-commit-push/reference.md` 与 `SKILL.md`，并同步 `commit-group.sh` 内 `TYPES`。

## 为什么省 token

1. **渐进披露**：平时只有 name + description；触发后读瘦身版 `SKILL.md`；细则在 `reference.md`。
2. **一次 analyze**：冲突 / log / name-status / 预览 / 密钥 / 截断信号 / 建议分组，无需 `cat` 源码。
3. **硬规则**：禁止读整文件、禁止 `git add -A`、禁止复述 diff。

## 安全提示

请先 review `skills/git-commit-push/scripts/`。默认保守：

- 永远 `git add -- <显式路径>`
- 产物与疑似密钥默认跳过
- 拒绝直推 main/master；默认优先走 SSH；push 被拒（如 non-fast-forward）则建议先 `git pull --rebase`
- 提交信息格式校验；钩子失败打印完整输出

## License

[MIT](./LICENSE)
