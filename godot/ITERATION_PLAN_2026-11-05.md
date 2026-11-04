# 架构地基迭代 · 任务书

| 项 | 内容 |
|---|---|
| 文档编号 | ITER-2026-11-05 |
| 制定日期 | 2026-11-05 |
| 依据 | `ARCHITECTURE_REVIEW_GODOT_2026-11-05.md`（架构审计） |
| 基线版本 | `c268384` / tag `baseline-2026-11-05-pre-noncombat-remedy` |
| 起始提交 | `0f58131`（分支 `remedy/noncombat-p0-2026-11-05`） |
| 迭代性质 | 架构地基，不含内容生产与视觉 |
| 阶段数 | 5（4 个改造 + 1 个验收） |

---

## 一、迭代目标

### 1.1 总目标

把审计中「与 Godot 理念不符」的六处里，**风险可控、收益确定的三处**落地，并建立可重复的验证方式。

不做「一次性重构」，做「先让地基能承重」。

### 1.2 可量化目标

| # | 目标 | 当前 | 目标值 | 度量 |
|---|---|---|---|---|
| G1 | 核心类具名类型 | `class_name` = 1（仅 BattleStub） | **≥ 7** | `grep -c "^class_name"` |
| G2 | 场景按需加载 | `main.gd` preload 25 个场景 | **0 个 preload 场景，25 条路由** | `grep -c 'preload("res://scenes' main.gd` |
| G3 | 数据服务单例 | Registry 每 UI 各 new | **生产环境共享 1 份，测试可回退** | 代码审查 + 测试通过 |
| G4 | 事件类型可编译期校验 | 8+ 处裸字符串 | **0 处裸字符串**（全部常量化） | `grep -c 'event.get("type") =='` |
| G5 | 无回归 | 基线测试全绿 | **全绿且断言数不减** | 测试运行记录 |

### 1.3 明确不在本次范围

| 项 | 审计编号 | 为什么不做 |
|---|---|---|
| 抽 5 个静态屏为 `.tscn` | N-1、N-2 | 需逐屏比对视觉，单元大，应与美术协同；本次无视觉回归手段 |
| 立绘区改 `AnimatedSprite2D` | N-1、支柱 3 | **技术前提不成立**（见 §5.1），且呼吸帧资产未就绪 |
| `noncombat_domain` 拆 5 个 Director | N-3 | 6,476 行，风险最高，需独立排期 |
| `Theme` 资源化 | N-8 | 属表现层，与本迭代「地基」主题不同 |
| 战斗 stage 数据驱动 | N-9 | 前置：VFX 评审（163 条 `finalArtApproved` 全 false） |
| 补美术资产 | — | 内容生产，非代码 |

---

## 二、分阶段任务

### 阶段 P1｜类型系统落地（优先级 P0）

**目标**：让核心类在编辑器里可补全、可被声明为具体类型。

**任务**：
1. 给 6 个核心类加 `class_name`：
   - `noncombat_domain.gd` → `NoncombatDomain`
   - `noncombat_content_repository.gd` → `NoncombatContentRepository`
   - `runtime_data_registry.gd` → `RuntimeDataRegistry`
   - `noncombat_opening_ui.gd` → `NoncombatOpeningUI`
   - `combat_domain.gd` → `CombatDomain`
   - `noncombat_run_session.gd` → `NoncombatRunSession`
2. 把**能确定类型**的 `var x: RefCounted` 替换为具体类型（不追求 192 处全清，只改可确定的）

**验收**：
- `grep -c "^class_name"` ≥ 7
- 6 个文件 `--check-only` 全过
- `NONCOMBAT_CONTENT_REPOSITORY_PASS` 数字不变

**风险**：`class_name` 冲突或循环引用 → 逐文件加、每加一个跑一次语法检查。

---

### 阶段 P2｜场景按需加载（优先级 P0）

**目标**：`main.gd` 不再在编译期加载全部 25 个战斗场景。

**任务**：
1. 删除 25 个 `const XxxStageScene = preload("res://scenes/...")`
2. 建路由表 `STAGE_ROUTES: Dictionary`（key → 路径）
3. 把 `elif` 分支里的 `duel_stage = XxxStageScene.instantiate()` 改为赋值 `stage_key`
4. 统一在分支末尾用 `_instantiate_stage(stage_key)` 加载
5. 保留所有原有分支的**判断条件不变**

**验收**：
- `grep -c 'preload("res://scenes' main.gd` = 0
- 路由表条目数 = 原 preload 场景数（±0）
- `--check-only` 通过
- 雷关路线端到端测试仍通过（`BATTLE_STUB_ROUTE_PASS` 走真实域，会触达 stage 解析）

**风险**：漏改一个分支导致该 stage 加载为空 → 用「路由 key 必须命中」的断言兜底（未命中 push_error）。

---

### 阶段 P3｜数据服务共享（优先级 P1）

**目标**：生产环境 Registry/Repository 只有 1 份；测试与独立场景仍可自建。

**任务**：
1. 新增 `autoload/data_service.gd`
2. `project.godot` 加 `[autoload] DataService`
3. `noncombat_opening_ui.gd` 的 `registry = Registry.new()` 改为「有 DataService 则复用，否则自建」
4. **不改变**既有显式注入的 API（`story.opening = game` 仍有效）

**验收**：
- 生产启动时 `DataService.registry` 非空且被 UI 复用
- 测试环境（无 autoload）仍能自建，测试全绿
- `--check-only` 通过

**风险**：autoload 在 `--script` 测试模式下可能不加载 → 必须保留回退分支，且回退是**正常路径**而非异常处理。

---

### 阶段 P4｜事件类型常量化（优先级 P1）

**目标**：消除 `event.get("type") == "STARTED"` 这类裸字符串的拼错风险。

**任务**：
1. 在 `noncombat_domain.gd` 顶部定义事件常量：
   ```gdscript
   const EVT_STARTED := "STARTED"
   const EVT_RESTORED := "RESTORED"
   const EVT_CHOICE_COMMITTED := "CHOICE_COMMITTED"
   const EVT_BATTLE_REQUEST_READY := "BATTLE_REQUEST_READY"
   # …按实际 emit 点补全
   ```
2. 8+ 处 `changed.emit({"type": "X"...})` 改为 `{EVT_X, ...}`
3. `noncombat_opening_ui.gd` 的 `if event.get("type") == "X"` 改为 `== NoncombatDomain.EVT_X`

**为什么不做完整强类型信号**：8+ 个事件的 payload 字段各不相同（`path`/`cardId`/`nodeId`/`npcId`/`setId`…），拆成独立信号需同时改 domain 的 8 处 emit 与 UI 的 7 处分支，**且当前无覆盖全部事件类型的测试**。常量化能达到「拼错即编译报错」的核心目的，风险低一个量级。

**验收**：
- `grep -c 'event.get("type") == "'` = 0（无裸字符串比较）
- `grep -c 'changed.emit({"type": "'` = 0
- 8 个事件类型的 emit 点全部改为常量
- 主链路测试通过

**风险**：漏改一处 → 逐个 emit 点核对（先导出清单再改）。

---

### 阶段 P5｜全量回归与验收（优先级 P0）

**任务**：
1. 跑语法检查：全部改动文件 `--check-only`
2. 跑契约测试：`battle_stub_contract`、`battle_stub_route`
3. 跑内容仓库测试：`noncombat_content_repository`
4. 跑 2~3 个非战斗主链路测试（选择耗时可控的）
5. 记录 G1~G5 实际值
6. 输出验收报告 `ITERATION_REPORT_2026-11-05.md`

**验收**：G1~G5 全部达标，任一不达标即迭代未完成。

---

## 三、执行纪律

1. **一次只改一个阶段**，每阶段结束立即验证，验证通过才进下一阶段
2. **每阶段独立提交**，commit message 标注阶段号（P1~P5）
3. **验证失败且 30 分钟内无法定位 → 回退该阶段**，在报告中记为未完成，不假装通过
4. **改动前记数，改动后复核**：每个 G 指标都要有「改前值 → 改后值」
5. **不删既有测试、不改既有断言**

---

## 四、验收标准总表

| 阶段 | 验收命令/方式 | 通过条件 |
|---|---|---|
| P1 | `grep -c "^class_name" scripts/*.gd` | ≥ 7 |
| P1 | `--check-only` × 6 文件 | 全过 |
| P1 | `noncombat_content_repository` | `modules=75 cards=588 ... unlisted=0` |
| P2 | `grep -c 'preload("res://scenes' scripts/main.gd` | = 0 |
| P2 | 路由条目 vs 原场景数 | 相等 |
| P2 | `--check-only` main.gd | 通过 |
| P3 | autoload 段存在 | `[autoload]` 有 DataService |
| P3 | 回退路径可用 | 无 autoload 时测试仍绿 |
| P4 | 裸字符串比较计数 | = 0 |
| P4 | emit 点常量化 | 全部 |
| P5 | 全部测试 | 全绿 |

---

## 五、风险与前置判断

### 5.1 需要修正架构文档的一处建议

架构文档 §3.4 写「立绘区从 `TextureRect` 换成 `AnimatedSprite2D`」。**这个建议在技术上不成立**：

实测 `noncombat_opening_ui.gd:103` `var art_rect: TextureRect`，其用法包含 `custom_minimum_size`、`size_flags_horizontal`、`size_flags_stretch_ratio`（L261-262、L924-927）——全部是 **Control 布局属性**。`AnimatedSprite2D` 是 `Node2D`，没有这些属性。

**正确做法**（供后续排期参考）：保持 `Control` 布局容器，内部放 `AnimatedSprite2D`；或用 `TextureRect` + `AnimationPlayer` 驱动 `texture` 轨道。两者都需要重构布局，不是换节点类型那么简单。

因此本迭代**不包含**立绘节点化。

### 5.2 风险表

| 阶段 | 风险 | 概率 | 影响 | 缓解 |
|---|---|---|---|---|
| P1 | `class_name` 冲突/循环引用 | 低 | 编译失败 | 逐文件加 + 每次语法检查 |
| P1 | 替换 `RefCounted` 引发连锁类型错误 | 中 | 编译失败 | 只改可确定类型，不碰 `Dictionary`/`Variant` |
| P2 | 漏改分支致 stage 加载为空 | 中 | 该遭遇战斗白屏 | 路由未命中时 `push_error` 并返回 null |
| P3 | autoload 在测试模式不加载 | 高 | 测试崩溃 | 回退分支作为正常路径 |
| P3 | 共享实例引发跨测试污染 | 中 | 测试互相干扰 | 测试环境仍自建，不复用 |
| P4 | 漏改一处致事件静默失效 | 中 | 某功能不响应 | 先导出 emit 清单再逐个改 |
| P4 | 常量名与字符串不一致 | 低 | 同上 | 常量值必须与原字符串完全一致 |

### 5.3 不可逆点

无。全部改动可通过 `git revert` 单个阶段提交回退；美术与内容不受影响。

---

## 六、完成判据

> 本迭代「完成」= G1~G5 五项全部达标，且 `ITERATION_REPORT_2026-11-05.md` 中每项都有「改前值 → 改后值 → 验证命令」三列实测记录。

任一项不达标，迭代状态为「部分完成」，并须在报告中列出未达标项与原因。

---

**文档版本**：v1.0  
**制定日期**：2026-11-05  
**执行起点**：`0f58131`  
**预计阶段**：P1 → P2 → P3 → P4 → P5
