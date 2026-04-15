# Trellis × Superpowers 集成快速接入

这份文档是**快速接入版**，只回答三件事：

1. 这个 adapter 现在的运行契约是什么
2. 怎么安装到一个真实 Trellis 项目里
3. 日常怎么用

如果你想看更完整的架构解释、节点拆解、为什么这样设计，请再看：

- [`SUPERPOWERS_TRELLIS_INTEGRATION_CN.md`](./SUPERPOWERS_TRELLIS_INTEGRATION_CN.md)

---

## 当前运行契约

这套 adapter 现在的核心约束是：

- **不要求安装 Superpowers 插件**
- **不在运行时调用 `superpowers:*` skills**
- **把需要的方法论改写进本地 `/trellis-sp:*` 命令**
- **让 Trellis 继续作为唯一 source of truth**

这样做的原因很直接：在真实项目里，如果本地安装 Superpowers，hook 自动加载可能会和 Trellis 冲突。这个 adapter 的目标，就是保留 Superpowers 擅长的方法，同时避免这类运行时冲突。

一句话理解：

> **Trellis 负责结构与状态，adapter 在本地内嵌受 Superpowers 启发的方法论，增强 Brainstorm / Plan / Execute，同时用 Trellis-native 方式处理 Specify / Clarify。**

---

## 它安装什么

安装后会向目标 Trellis 项目写入：

- `.claude/commands/trellis-sp/brainstorm.md`
- `.claude/commands/trellis-sp/specify.md`
- `.claude/commands/trellis-sp/clarify.md`
- `.claude/commands/trellis-sp/plan.md`
- `.claude/commands/trellis-sp/execute.md`
- `.claude/skills/trellis-sp-local/SKILL.md`

命令含义：

- `/trellis-sp:brainstorm` → 本地 brainstorming discipline，综合 Trellis + Superpowers 的优点
- `/trellis-sp:specify` → Trellis-native task PRD 规格整理
- `/trellis-sp:clarify` → Trellis-native task PRD 歧义澄清
- `/trellis-sp:plan` → 本地 planning discipline + Trellis-native 原子子任务拆分与 task-local execution contract
- `/trellis-sp:execute` → 本地 execution discipline + 通过 Trellis-compatible subagent 渐进执行子任务

---

## 最小接入手册

### 1. 准备一个真实 Trellis 项目

目标项目应当已经通过 `trellis init` 初始化，并且至少包含：

- `.trellis/`
- `.trellis/.version`
- 最好还有 `.trellis/.template-hashes.json`

如果缺少 `.trellis/.version`，adapter 会拒绝安装。

### 2. 从 adapter 目录执行 bootstrap

```bash
./bootstrap.sh /path/to/your/real-project
```

或者：

```bash
./manage.sh bootstrap /path/to/your/real-project
```

行为如下：

- adapter 不存在 → 自动安装并验证
- adapter 已健康安装 → 只执行验证
- adapter 半安装 / 不健康 → 停止并提示你用 doctor / install / list-backups 排查

### 3. 安装后做最小验证

```bash
./manage.sh status /path/to/your/real-project
./manage.sh verify /path/to/your/real-project
./manage.sh release-check /path/to/your/real-project
```

验证通过后，目标项目应存在：

- `.claude/commands/trellis-sp/brainstorm.md`
- `.claude/commands/trellis-sp/specify.md`
- `.claude/commands/trellis-sp/clarify.md`
- `.claude/commands/trellis-sp/plan.md`
- `.claude/commands/trellis-sp/execute.md`
- `.claude/skills/trellis-sp-local/SKILL.md`

---

## 日常使用流程

### 场景 A：复杂任务 / 需求不明确

```text
/trellis:start
/trellis-sp:brainstorm
/trellis-sp:specify
(/trellis-sp:clarify 如有需要)
/trellis-sp:plan
/trellis-sp:execute
/trellis:check
/trellis:finish-work
/trellis:record-session
```

在 `/trellis-sp:brainstorm` 之后，默认下一步是 `/trellis-sp:specify`。只有在仍然存在高价值歧义时才进入 `/trellis-sp:clarify`；否则当 PRD 已经达到 planning-ready 时，直接继续到 `/trellis-sp:plan`。

这条 adapter lane **不会**替代原生 `/trellis:brainstorm`；它是一条从 `/trellis-sp:brainstorm` 显式进入的增强路径。一旦进入 adapter lane，就不要再把用户重定向回原生 brainstorm。

这条 adapter 流程里的 current task 规则需要明确理解：

- `/trellis:start` 仍然是推荐入口，但 adapter 命令即使被直接调用，也必须自己把 Trellis task 状态处理正确。
- `/trellis-sp:brainstorm` 应保证存在 parent task，并在进入 `/trellis-sp:specify` 前把 `.trellis/.current-task` 设为 parent task。
- `/trellis-sp:brainstorm` 在创建 parent task 或发现 adapter 标记缺失/过期时，应立即执行 `python3 .claude/scripts/trellis-sp-task-meta.py <task-dir> --role parent --phase brainstorm`。
- `/trellis-sp:specify` 在结束前，应立即执行 `python3 .claude/scripts/trellis-sp-task-meta.py <task-dir> --role parent --phase specify`，保证 active parent task 仍能被识别为 adapter-managed task。
- `/trellis-sp:plan` 在创建或更新 child tasks 时，`.trellis/.current-task` 仍应保持指向 parent task。
- `/trellis-sp:plan` 在 planning 进行时，应立即执行 `python3 .claude/scripts/trellis-sp-task-meta.py <parent-task-dir> --role parent --phase plan`；当 parent 准备好进入 execution handoff 时，再执行 `python3 .claude/scripts/trellis-sp-task-meta.py <parent-task-dir> --role parent --phase execute`。
- `/trellis-sp:plan` 还应在 parent 缺失 `implement.jsonl` / `check.jsonl` / `debug.jsonl` 时，先执行 `python3 ./.trellis/scripts/task.py init-context <parent-task-dir> <dev_type>` 初始化父任务上下文，再用 `python3 ./.trellis/scripts/task.py add-context ...` 仅补齐 Trellis-native preload context，例如相关 spec、共享 guides/docs，以及确有必要时极少量可复用 code-pattern reference。likely touched 的业务代码文件应写入 `info.md`，不应通过 jsonl 预载。
- `/trellis-sp:plan` 对每个新建或更新的 child task，都应在缺失 jsonl 时先执行 `python3 ./.trellis/scripts/task.py init-context <child-task-dir> <dev_type>`，再立即执行 `python3 .claude/scripts/trellis-sp-task-meta.py <child-task-dir> --role child --phase execute`；child `info.md` 还应显式记录 `Read First`、likely touched files、实现顺序与验证目标，供运行时按需读取代码。
- `/trellis-sp:execute` 在执行每个 child task 前，应先把 `.trellis/.current-task` 切到该 child；所有 child 完成后，再切回 parent task 做最终 parent-level `check`。
- `/trellis:finish-work` 仍然是 Trellis 原生的 finish / handoff 节点；在 adapter lane 里，只能在 `/trellis-sp:execute` 恢复 parent task 并完成 parent-level final `check` 之后进入。
- child task 只是 staged execution unit，不能单独视为 ready-for-finish-work。
- 在 handoff 到 `/trellis:finish-work` 之前，应明确判断这次流程是否暴露了值得通过 `/trellis:update-spec` 沉淀的通用规则、约束或调试经验。
- 在 `/trellis:finish-work` 之后，如果 staged execution 形成了值得跨 session 保留的决策或 review 结论，应继续走 `/trellis:record-session`。

### 场景 B：需求已经比较清楚

```text
/trellis:start
/trellis-sp:specify
/trellis-sp:plan
/trellis-sp:execute
/trellis:check
/trellis:finish-work
```

### 场景 C：特别小的修复

对于真正 trivial 的改动，也可以完全不走这些增强命令，直接用 Trellis 原生流程。

---

## 关键运行约束

- task-level feature spec 的唯一事实来源是 active task `prd.md`
- `/trellis-sp:brainstorm` 在本地应用受 Superpowers 启发的 brainstorming discipline，但所有需求仍落回 Trellis task PRD；如果原本没有 active task，它还应先创建并激活 parent task，避免后续 `/trellis-sp:specify` 看见 `CURRENT TASK = (none)`
- `/trellis-sp:brainstorm`、`/trellis-sp:specify`、`/trellis-sp:plan` 还负责通过 `.claude/scripts/trellis-sp-task-meta.py` 持续刷新 `task.json.meta.trellis_sp`，让 parent/child task 在跨 session 时仍能被识别。
- `/trellis-sp:plan` 必须在需要 staged delivery 时把大任务拆成原子子任务，并把 implementation contract 收敛到 parent/child task-local `info.md` 与 jsonl context files，而不是写入外部 plan artifact；planning 期间 current task 应保持为 parent task。jsonl 只承载 Trellis-native preload context，运行时代码读取指引应写入 `info.md`
- `/trellis-sp:execute` 必须按子任务顺序渐进推进，并通过 Trellis-compatible `research` / `implement` / `check` / `debug` subagent 路由真实工作；执行每个 child task 前应切到该 child，并先审阅 child/parent 的 `prd.md` 与 `info.md`，按 `Read First` 和 likely touched files 在运行时读取真实代码，全部 child 完成后再切回 parent 做最终 `check`
- `/trellis:start` 在 current-task resume 和 manual-selection 两种入口下，都应读取 `task.json.meta.trellis_sp` 再决定走 adapter flow 还是原生 Trellis flow：parent task 恢复时先读 parent `prd.md` 与 `info.md`；child task 恢复时先读 child `prd.md`，再读 parent `prd.md` 与 parent `info.md`，并先完成当前 child loop，再回到 parent final `check`。
- 当前 adapter **不会**把执行阶段直接交给 Trellis `dispatch` agent。这样做是有意为之：adapter 现在只做轻量执行桥接，不想过早耦合到完整的 Trellis phase orchestration（例如 `task.json.next_action`、finish/create-pr 语义以及更深的 dispatch 假设）。目前这套设计已经能继承 Trellis 的 hook/context 注入优势，同时保持 adapter 边界清晰。
- `research` 不是每次强制执行：context 足够时可跳过，context 缺失时必须补齐
- Ralph Loop 只有在执行路径真正落到 Trellis `check` subagent 时才会重新生效，因此最终验证必须显式回到 Trellis `check`

---

## 一个原子子任务拆分示例

一个好的 `/trellis-sp:plan` 结果，不应该把明显需要 staged delivery 的大任务，继续保留成一次性、不可审查的 implementation pass。

例如，假设当前 active Trellis task 是：

- parent task: `为 adapter 增加 atomic workflow`

那么更合理的 planning 结果应该保留这个 parent task 作为总任务，并拆成几个可审查的 child tasks，例如：

1. `update plan command contract`
   - 目标：让 `/trellis-sp:plan` 明确负责把大任务拆成 atomic child tasks
   - 可能涉及文件：`overlay/.claude/commands/trellis-sp/plan.md`、`overlay/.claude/skills/trellis-sp-local/SKILL.md`
   - 验证点：文档显式出现 parent/child decomposition 与 task-local execution contract

2. `update execute command contract`
   - 目标：让 `/trellis-sp:execute` 明确按 child task 渐进执行并设置 checkpoint
   - 可能涉及文件：`overlay/.claude/commands/trellis-sp/execute.md`、`lib/trellis-target.sh`
   - 验证点：文档显式要求 sequential child execution、`check`/`debug` 循环、parent-level final `check`

3. `update adapter verification and docs`
   - 目标：让 `verify.sh` 与 README / 集成说明跟新契约一致
   - 可能涉及文件：`verify.sh`、`README.md`、`README_INTEGRATION_CN.md`、`SUPERPOWERS_TRELLIS_INTEGRATION_CN.md`
   - 验证点：verify 通过，说明文档与命令契约一致

在这种模型里：

- parent task 保留总体 PRD，以及写在 `info.md` 里的执行顺序
- 每个 child task 都有自己收窄后的 `prd.md`、`info.md` 和 jsonl context files；其中业务代码的运行时目标应写在 `info.md`，而不是放进 jsonl 预载
- `/trellis-sp:execute` 应该按 child task 逐个推进，而不是把 parent task 当作一个不可分的大实现步骤
- 每个 child 到达干净的 `check` 结果后，都应停在 review checkpoint 再继续
- 所有 child 完成后，再做一次 parent-level final `check`

一个最小可照抄模板可以是：

### Parent `info.md`
- 目标
- 有序 child task 列表
- child 到文件的映射
- shared runtime reading targets
- verification strategy
- review checkpoints

### Child `prd.md`
- 一个原子目标
- 一组简短 requirements
- 1-2 条可验证 acceptance criteria
- likely touched files

### Child `info.md`
- `Read First`
- likely touched files
- suggested implementation sequence
- verification targets
- blockers / assumptions

### Child 执行 checklist
- `implement` 只完成当前 child scope
- 当前 child 的 `check` 通过
- 必要时先 `debug` 再继续
- 进入下一个 child 前先做 checkpoint summary

这就是这里所说的“Superpowers 风格拆解，Trellis-native 执行”。

## 运维与维护

### 查看状态

```bash
./manage.sh status /path/to/your/trellis-project
```

### 诊断问题

```bash
./manage.sh doctor /path/to/your/trellis-project
```

### 运行只读自检

```bash
./manage.sh self-test /path/to/your/trellis-project
```

### 查看备份

```bash
./manage.sh list-backups /path/to/your/trellis-project
./manage.sh list-backups /path/to/your/trellis-project <snapshot-name>
```

### 恢复快照

```bash
./manage.sh restore /path/to/your/trellis-project <snapshot-name>
```

### task 元数据

adapter 运行时用于识别任务类型的标记放在 `task.json.meta.trellis_sp` 中。

建议字段：

- `managed`：是否为 adapter 管理任务
- `role`：`parent` 或 `child`
- `workflow_version`：当前 metadata 版本
- `last_phase`：最近一次 adapter 阶段，如 `brainstorm`、`specify`、`plan`、`execute`

adapter 会安装 `.claude/scripts/trellis-sp-task-meta.py`，用于在不修改 Trellis core script 的前提下写入并刷新这些字段。

### 清理旧快照

```bash
./manage.sh prune-backups /path/to/your/trellis-project keep-latest 3
```

### 导出状态清单

```bash
./manage.sh export-manifest /path/to/your/trellis-project ./manifest.json
```

### 发布前检查

```bash
./manage.sh release-check /path/to/your/trellis-project
```

---

## 进一步阅读

如果你想看更完整的解释，请继续看：

- [`SUPERPOWERS_TRELLIS_INTEGRATION_CN.md`](./SUPERPOWERS_TRELLIS_INTEGRATION_CN.md)
