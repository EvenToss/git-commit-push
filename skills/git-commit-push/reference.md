# git-commit-push · reference

按需阅读。日常流程以 `SKILL.md` 为准。

## 分组规则

- **同一功能的前后端合为一个 commit**：Controller + Service + Mapper + 对应前端页/API 同属一功能，不要按前后端硬拆。
- **不同功能必须拆开**：各自独立 commit。
- **纯配置 / 脚本 / SQL / 依赖** 单独 `chore` / `build`，不混进功能 commit。
- **宁可少拆不要碎拆**：禁止每个文件一个 commit；每个 commit 须可独立 review / 回滚。
- 单文件含多功能且无法按 hunk 干净拆分时，保留一个 commit，用 body 列要点。
- `analyze.sh` 的 `## suggest-groups` 是启发式起点：可合并过细组、拆开误绑组。

## 类型选择（中文前缀，无 scope）

| type | 用于 | 信号 |
|---|---|---|
| `feat` | 新功能 / 新接口 / 新页面 / 新字段 | 新 endpoint、VO、页面、枚举 |
| `fix` | 修 bug | 校验缺失、空指针、错误配置 |
| `docs` | 仅文档 / 注释 / markdown | 只动 `.md` 或注释 |
| `style` | 仅格式（不改逻辑） | 空格、import 顺序、换行 |
| `refactor` | 重构（无行为变化） | 改名、抽方法、结构调整 |
| `perf` | 性能优化 | 查询优化、缓存、减 N+1 |
| `test` | 测试 | 新增 / 改测试 |
| `build` | 构建 / 依赖 | `pom.xml`、`package.json`、`Dockerfile` |
| `ci` | CI 配置 | `.github/`、`Jenkinsfile` |
| `chore` | 杂项 | SQL、脚本、yaml、清理 |
| `revert` | 回滚 | 撤销某次提交 |

拿不准时按「主要目的」选一个；其余进 body。

## 提交信息格式

```
<type>: <中文简述>
```

- 动宾 / 祈使，≤30 字，不加句号，不加 scope。
- 复杂改动可加 body（`COMMIT_BODY`），用 `- ` 列要点；不加 `Co-authored-by`。

好例子：

```
feat: 增加按司机筛选轨迹
fix: 修复阶段表单日期校验缺失
chore: 同步驾照类型字典脚本
refactor: 抽取审核日志公共方法
```

坏例子：`feat(track): add filter`（有 scope / 英文）、`feat: 优化。`（句号）、`update code`（无 type）。

## analyze 输出字段

| 段 | 含义 |
|---|---|
| `conflict` | `YES` 则停止 |
| `log` | 近 5 条，对齐语气 |
| `files` | `status path +N -M` |
| `untracked` | 新文件 + 前 N 行预览（勿再 read） |
| `skipped` | 产物/垃圾，默认不提交 |
| `secrets` | 疑似密钥路径 WARN |
| `signals` | 截断后的 FILE/@@/± 样例，非全文 diff |
| `suggest-groups` | `G1 type paths…` 供确认 |

信号行默认上限 150；不足时再对 **一个** 文件补 `git diff HEAD --unified=0 -- <path>`。

## commit-group / push

```bash
bash commit-group.sh "feat: 简述" p1 p2
bash commit-group.sh --dry-run "feat: 简述" p1
COMMIT_BODY="- 点1" bash commit-group.sh "feat: 简述" p1

bash push.sh
COMMIT_PUSH_ALLOW_MAIN=1 bash push.sh          # 允许主分支
COMMIT_PUSH_REMOTE=upstream bash push.sh
```

消息须匹配：`^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert): .+`  
钩子失败时脚本打印完整输出，修复后 **新开** commit，勿 amend 除非用户明确要求。

## 自定义

改风格（英文 / 加 scope）：编辑本文件与 `SKILL.md` 相关节；`commit-group.sh` 内 `TYPES` 正则需同步。
