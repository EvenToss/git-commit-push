# git-commit-push · pi skill

> 把当前工作区的代码改动 **按功能拆成多个原子提交**（强制中文 `feat:/fix:/refactor:` 规范），逐个提交后 **自动 push**。专为 **规范团队提交信息 + 极低 token 消耗** 设计。

适用于 [pi](https://pi.dev)（及任何兼容 [Agent Skills](https://agentskills.io) 标准的 harness，如 Claude Code / Codex）。

---

## 它解决什么问题

- **习惯不统一**：团队里有人一锅炖成一个 commit，有人提交信息随手乱写，review 和回滚都痛苦。
- **手写规范信息累**：每次都要想 type、想分组、写中文简述。
- **让 AI 提交容易烧 token**：直接让模型提交，它倾向于 `cat` 一堆源码去「理解」改动，上下文瞬间膨胀。

`git-commit-push` 把这三件事一次性解决。

## 特性

- 🔪 **按功能自动拆分**：同一功能的前后端改动合一，不同功能拆开，纯配置单独成 `chore`。
- 🇨🇳 **强制中文规范信息**：`feat / fix / docs / style / refactor / perf / test / build / ci / chore / revert` 前缀，无 scope，动宾简述。
- 🚀 **提交后自动 push**（可关）。
- 💸 **极低 token**：一次脚本拿紧凑 diff，**明令禁止**为写信息去 `cat` 整个源码。
- 🛡️ **安全默认**：显式路径暂存（禁 `git add -A`）、垃圾文件（`.log` / `.DS_Store` / `target/` 等）自动跳过、拒绝直推 `main/master`。

## 要求

- 兼容 Agent Skills 的 agent harness（pi / Claude Code / Codex …）
- `bash` ≥ 4 + `git`（macOS / Linux；Windows 用 Git Bash / WSL）

## 安装

> 仓库名 / 包名 / skill 名统一为 **`git-commit-push`**，注册的斜杠命令是 `/skill:git-commit-push`。

### 方式 A · pi package（推荐）

一行装、可更新、可团队自动安装：

```bash
pi install git:github.com/EvenToss/git-commit-push
# 锁版本
pi install git:github.com/EvenToss/git-commit-push@v1.1.0
# 更新
pi update  git:github.com/EvenToss/git-commit-push
# 卸载
pi remove  git:github.com/EvenToss/git-commit-push
```

### 方式 B · 直接 clone 到全局 skills 目录

```bash
git clone git@github.com:EvenToss/git-commit-push.git ~/.agents/skills/git-commit-push
# 或 https：
# git clone https://github.com/EvenToss/git-commit-push.git ~/.agents/skills/git-commit-push
# 更新：
# cd ~/.agents/skills/git-commit-push && git pull
```

pi 对 skills 目录是**递归发现**的，会自动找到 `skills/git-commit-push/SKILL.md`。

### 方式 C · 项目级（团队随仓库共享，最省心）

在项目根执行一次：

```bash
pi install -l git:github.com/EvenToss/git-commit-push
```

它会把安装项写进 `.pi/settings.json` → 提交进仓库 → 队友 `git clone` 该项目后，pi 启动时**自动安装**这个 skill（首次会询问是否信任项目）。

## 用法

**安装后需重启 pi**（pi 只在启动时扫描 skills）。

- 斜杠命令：`/skill:git-commit-push`
- 或自然语言：「提交推送一下」「commit 这些改动」「整理一下工作区」

它会自动：**分析改动 → 按功能分组 → 逐组 commit → push → 一行一个 commit 汇报**，例如：

```
✓ feat: 运单轨迹增加按司机筛选 (8 files)
✓ fix: 修复阶段表单日期校验缺失 (1 file)
✓ chore: 关闭 application.yaml 调试日志 (1 file)
→ pushed to origin/feature/xxx
```

脚本通过一个可移植的定位器自动找到（兼容 clone 与 `pi install` 两种安装位置），无需关心 skill 装在哪。

## 配置（环境变量）

| 变量 | 默认 | 作用 |
|---|---|---|
| `COMMIT_PUSH_ALLOW_MAIN` | `0` | 设 `1` 允许直推 `main`/`master` |
| `COMMIT_PUSH_REMOTE` | `origin` | 推送用的远程名 |
| `COMMIT_BODY` | _(空)_ | 给 `commit-group.sh` 附加 body（第二个 `-m`） |

示例（脚本与 SKILL.md 同目录，在 `scripts/` 下）：

```bash
COMMIT_PUSH_ALLOW_MAIN=1 COMMIT_PUSH_REMOTE=upstream \
  bash ~/.agents/skills/git-commit-push/scripts/push.sh   # clone 安装路径
```

> `pi install` 安装时路径在 `~/.pi/agent/` 下；脚本会自动定位，无需手写绝对路径。

## 自定义

强制中文是默认。想改英文 / 加 scope / 换前缀集：直接编辑 `skills/git-commit-push/SKILL.md` 的【类型选择】与【提交信息格式】两节即可——纯文本，团队成员各自维护或随约定更新。

## 为什么这样设计（省 token 原理）

1. **渐进式披露**：平时只有 `name + description`（约一两百 token）在系统提示里；只有真的要提交时才 `read` 完整 `SKILL.md`。
2. **一次脚本拿全部信息**：`scripts/analyze.sh` 一次输出「统计 + 未跟踪文件 + `unified=0` 差异」，模型据此分组，**无需 `cat` 任何源码**。
3. **硬规则节流**：SKILL.md 明令禁止 `cat`/`read` 整文件、禁止重复跑 `git status`、禁止把完整 diff 复述给用户。

## 安全提示

脚本会执行 `git add` / `git commit` / `git push`。首次使用前请 review `skills/git-commit-push/scripts/` 下的三个脚本。默认行为已尽量保守：

- 永远 `git add -- <显式路径>`，**不** `git add -A`
- 未跟踪的 `*.log` / `.DS_Store` / `node_modules/` / `dist/` / `target/` 等默认跳过
- 默认拒绝直推 `main` / `master`
- 暂存后无差异则跳过，不产生空 commit

## License

[MIT](./LICENSE)
