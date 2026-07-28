---
name: git-commit-push
description: 分析当前 git 仓库改动，按逻辑功能拆成多个原子提交（强制中文 feat:/fix:/refactor:/docs:/chore: 等前缀，无 scope），逐个 commit 后自动 git push。专为团队规范提交信息设计，用一次性脚本读取紧凑 diff 概览来极小化 token 消耗。当用户要求提交代码、commit、push、规范提交信息、整理工作区时使用。
---

# git-commit-push

把当前工作区的改动 **按功能拆成多个原子提交**（中文 `feat:/fix:/...` 前缀），逐个提交后 **自动 push**。

设计目标：规范团队提交信息 + 极低 token 消耗。

## 核心原则：省 token

- ✅ **只跑一次** `analyze.sh` 拿到全部信息（统计 + 未跟踪 + unified=0 差异），据此分组写信息。
- ✅ 只有当概览不足以判断某个文件归属时，才对 **单个** 文件再 `git diff HEAD --unified=0 -- <path>`。
- ❌ **绝不** 为了写提交信息去 `cat` / `read` 整个源码文件。
- ❌ 不重复跑 `git status` / `git diff --stat`。
- ❌ 不把完整 diff 复述给用户；执行完只回 **每个 commit 一行** 的摘要。

## 标准工作流

### 0. 定位 skill 目录（兼容 clone 与 pi install 两种安装位置）
脚本位于本 SKILL.md 同目录下的 `scripts/`。先设好 `SD`，**并保持当前项目目录为 CWD**——脚本里的 git 命令会作用于你的项目仓库，而不是 skill 自身的仓库：
```bash
SD="$(for b in "$HOME/.agents/skills" "$HOME/.pi/agent" "$HOME/.pi" ".pi"; do
        [ -d "$b" ] && find "$b" -maxdepth 8 -type f -name SKILL.md -path '*git-commit-push*' 2>/dev/null
      done | head -1)"
SD="$(dirname "$SD")"; [ -n "$SD" ] || { echo "找不到 git-commit-push skill 目录" >&2; exit 1; }
```
> 你刚才 read 本 SKILL.md 时绝对路径已在上下文里，直接 `SD="<SKILL.md 所在目录>"` 跳过查找也可。

### 1. 分析改动（一次脚本调用）
```bash
bash "$SD/scripts/analyze.sh"
```
若输出「工作区干净」则直接结束，告诉用户没有可提交的改动。

### 2. 分组 + 写中文提交信息
依据 analyze 输出，把文件聚成若干组，每组定一个 type + 中文简述。规则见下方【分组规则】与【类型选择】。

### 3. 逐组提交（显式路径，禁止 git add -A）
对每一组：
```bash
bash "$SD/scripts/commit-group.sh" \
  "feat: 运单轨迹增加按司机筛选" \
  admin/apps/web-antdv-next/src/views/freight/waybilltrack/index.vue \
  server/huoyun-module-freight/src/main/java/com/huoyuntong/module/freight/controller/admin/waybilltrack/WaybillTrackController.java
```
可选 body（作为第二个 `-m`）：
```bash
COMMIT_BODY="按企业 + 司机筛选，新增分页参数" \
  bash "$SD/scripts/commit-group.sh" "feat: ..." <paths...>
```
> 等价原生命令：`git add -- <paths> && git commit -m "<type>: <简述>" [-m "body"]`

### 4. 推送
```bash
bash "$SD/scripts/push.sh"
```
无上游自动 `git push -u origin <branch>`；默认拒绝直推 main/master。

### 5. 汇报（一行一个 commit）
```
✓ feat: 运单轨迹增加按司机筛选 (8 files)
✓ fix: 修复阶段表单日期校验缺失 (1 file)
✓ chore: 关闭 application.yaml 调试日志 (1 file)
→ pushed to origin/feature/xxx
```

## 分组规则

- **同一功能的前后端改动合为一个 commit**：如「运单轨迹」的 Controller + Service + Mapper + 前端 `index.vue`/`data.ts` 属于同一功能，**不要**按前后端硬拆。
- **不同功能必须拆开**：运单轨迹 ≠ 审核日志 ≠ 阶段表单，各自独立 commit。
- **纯配置 / 脚本 / SQL / 依赖** 单独成 `chore` / `build`，不混进功能 commit。
- **宁可少拆不要碎拆**：禁止每个文件一个 commit；每个 commit 必须是一个可独立 review / 回滚的完整单元。
- 单文件含多功能且按 hunk 无法干净拆分时，保留在一个 commit，用 body 列要点。

## 类型选择（中文前缀，无 scope）

| type | 用于 | 信号 |
|---|---|---|
| `feat` | 新功能 / 新接口 / 新页面 / 新字段 | 新增 endpoint、VO、Vue 页面、枚举值 |
| `fix` | 修 bug（改正错误行为） | 校验缺失、空指针、序列化错误、配置地址错 |
| `docs` | 仅文档 / 注释 / markdown | 只动 `.md` 或注释 |
| `style` | 仅格式（不改逻辑） | 空格、import 顺序、换行 |
| `refactor` | 重构（无行为变化） | 改名、抽方法、结构调整 |
| `perf` | 性能优化 | 查询优化、缓存、减少 N+1 |
| `test` | 测试 | 新增 / 改测试 |
| `build` | 构建 / 依赖 | `pom.xml`、`package.json`、`Dockerfile` |
| `ci` | CI 配置 | `.github/`、`Jenkinsfile` |
| `chore` | 杂项 | SQL 同步、脚本、yaml 配置、依赖升级、清理 |
| `revert` | 回滚 | 撤销某次提交 |

拿不准时按「这个 commit 主要目的是什么」选一个；多类型混合取最主要的，其余进 body。

## 提交信息格式

```
<type>: <中文简述>
```
- 简述用 **动宾 / 祈使**，简洁（≤30 字为宜），**不加句号**。
- **不加 scope**（对齐本仓库历史：`feat: 运单号自动生成 + ...`）。
- 复杂改动可空一行接 body，用 `- ` 列要点；**不加** `Co-authored-by` 等尾注。

好例子：
```
feat: 运单轨迹增加按司机筛选
fix: 修复阶段表单日期校验缺失
chore: 同步数据库脚本（驾照类型字典完善）
refactor: 抽取审核日志公共记录方法
```

## 安全 / 边界

- **显式路径暂存**：永远 `git add -- <具体路径>`，禁止 `git add -A` / `git add .`。
- **垃圾文件自动跳过**：analyze 会把未跟踪的 `*.log`、`LOG_FILE_*`、`.DS_Store`、`node_modules/`、`dist/`、`target/` 等列入「已跳过」，默认不提交；如确需提交某被跳过的文件，在 commit-group.sh 显式带上它的路径即可。
- **拒绝直推 main / master**：push.sh 默认拦截（git flow 规范）；确需推送主分支设 `COMMIT_PUSH_ALLOW_MAIN=1`。
- **空提交保护**：commit-group.sh 检测到暂存后无差异会跳过。
- **远程名**：默认 `origin`，可用 `COMMIT_PUSH_REMOTE=xxx` 覆盖。
- **不在 git 仓库** / **存在合并冲突** 时停止并提示，不要强行提交。
- 自动 push 是默认行为；如本次只想提交不想推，跑到第 3 步即可，跳过第 4 步。

## 自定义

强制中文是本 skill 的默认。若某仓库想改风格（如改英文、加 scope），直接编辑本 SKILL.md 的【类型选择】与【提交信息格式】两节即可——纯文本，团队成员各自维护或随约定更新。
