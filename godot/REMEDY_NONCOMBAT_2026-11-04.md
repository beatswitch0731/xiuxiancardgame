# 一念仙途 Godot 非战斗模块 · 整改建议

| 项 | 内容 |
|---|---|
| 文档编号 | REMEDY-NONCOMBAT-2026-11-04 |
| 制定日期 | 2026-11-04 |
| 前置前提 | **战斗系统为本阶段刻意规避项，完成度低属正常预期，不计入整改范围** |
| 整改对象 | 非战斗侧的系统设计与实现 + 非战斗↔战斗的接口契约 |
| 取代关系 | 取代 `REMEDY_2026-11-04.md` 中关于「战斗验证洼地」「战斗门禁」的条款；工程与资产逐日台账见 `REMEDY_LEDGER_2026-11.md` |
| 关联文档 | `ACCEPTANCE_STANDARD_v2.md`（验收标准）、`MIGRATION_STATUS_2026-11-04.md`（进度评估） |

---

## 〇、前提修正确认

在确立本前提后，此前三条判断需要撤回或改写：

| 原判断 | 修正后 |
|---|---|
| ~~「战斗 31 个 stage 只有约 20 个测试 = 风险倒挂」~~ | **撤回。** 这是刻意规避的结果，不是风险。战斗不投入即不该要求测试覆盖 |
| ~~「测试 94% 压非战斗 = 资源分配失衡」~~ | **撤回。** 这与「优先完成非战斗」的策略完全一致，是正确分配 |
| 「战斗仅首战切片 = 迁移落后」 | **改写。** 战斗不是落后，是**主动延后**。真正需要保证的是「延后不产生返工」 |

**保留不变的判断**（与非战斗直接相关，且不受前提影响）：

- 通过无法累积：150 次 `退出 0` → 阶段签收 1/12
- 资产缺失静默：立绘缺 230/268（86%），`texture_for()` 静默返回 `null`
- 同步脚本手工枚举，清单外资产从未进工程
- `noncombat_domain.gd` 6,476 行 / 62 个 `preload` 的上帝对象
- 非战斗侧仅 1 个信号 `changed(event: Dictionary)`
- 10 处测试对网页版 `.js` 取整文件 SHA，全部在 `noncombat_*` 测试内
- `godot/` 零版本控制

---

## 一、整改范围界定

### 1.1 在范围内

| 层 | 内容 | 代表文件 |
|---|---|---|
| **数据层** | 内容仓库、来源索引、JSON 模块加载、资产解析 | `noncombat_content_repository.gd`、`runtime_data_registry.gd` |
| **领域层** | 状态机、结算、决策推进 | `noncombat_domain.gd`（6,476 行） |
| **流程层** | 任务/坊市/鬼市/因果/命盘/同伴/NPC/世界/境界/转世/机会 | 236 个 `noncombat_*` 脚本 |
| **表现层** | 开场 UI、剧情页、图鉴、日志、地图、设置 | `noncombat_opening_ui.gd`（2,546 行）等 |
| **存档层** | 槽位、会话、旧档导入、并发锁 | `noncombat_save_slots.gd`、`noncombat_run_session.gd` |
| **接口层** | **非战斗↔战斗的交接契约** | `noncombat_battle_gateway.gd`（1,918 行）等 |
| **工具链** | 同步、审计、覆盖检查 | `tools/*.py` |

### 1.2 不在范围内

| 内容 | 说明 |
|---|---|
| 战斗表现层 | `duel_stage_*`（31 场景 / 23 脚本 / 4,299 行）——延后 |
| 战斗数值与规则 | `combat_domain.gd`（1,120 行）——延后 |
| 战斗演出资源 | VFX 591 帧、敌方动作帧 —— 延后 |
| 战斗 HD-2D/3D 美术 | 建筑 GLB、8 方向角色母体 —— 延后 |

### 1.3 关键分界：接口层算非战斗

这是本次范围划分最重要的一条：

```
noncombat_battle_gateway.gd    1,918 行   ← 算非战斗（必须稳定）
noncombat_battle_return_flow.gd  614 行   ← 算非战斗（必须稳定）
noncombat_battle_victory_flow.gd 249 行   ← 算非战斗（必须稳定）
combat_stage_router.gd            73 行   ← 算接口（只保留路由）
────────────────────────────────────────
duel_stage_*（31 个）                     ← 算战斗（延后）
combat_domain.gd                 1,120 行 ← 算战斗（延后）
```

**理由**：`battle_gateway` 负责「非战斗产出战斗请求」和「校验战斗结果」，它跑在非战斗流程里。战斗不做，这条链也得能跑。

### 1.4 测试覆盖现状（接口层）

| 文件 | 被测试引用 |
|---|---|
| `noncombat_battle_gateway` | **32 个测试文件** |
| `noncombat_battle_return_flow` | 23 个测试文件 |
| `noncombat_battle_victory_flow` | **3 个测试文件** ← 偏少 |

接口层整体覆盖良好，胜利结算流偏薄。

---

## 二、非战斗现状诊断（按层）

### 2.1 数据层

| 问题 | 实测 | 对非战斗的影响 |
|---|---|---|
| 资产缺失静默失败 | `texture_for()` 无告警、无计数、无回退 | 剧情立绘 86% 缺失**长期不可见**，玩家看到空白而非报错 |
| 同步脚本手工枚举 | `sync_runtime_content.py` 以 `ENCOUNTER_ID` 为中心枚举 | 清单外立绘/场景图从未进工程 —— 这是 86% 缺失的**唯一根因** |
| 帧序列全或无 | 单帧缺失即整段返回 `null` | 非战斗的动效也会整段消失 |

### 2.2 领域层

| 问题 | 实测 |
|---|---|
| 上帝对象 | `noncombat_domain.gd` **6,476 行 / 62 个 `preload`**，把 encounter / vendor / dungeon / rebirth / story-thread 全收在一个类 |
| 扇出独占 | 其余文件扇出均 ≤ 27，它一个 62 —— 唯一热点 |
| 类型退化 | 全项目 `class_name` **0 个**；`var x: RefCounted` **192 处**；`Dictionary` 标注 1,971 处 |

### 2.3 流程层

| 问题 | 实测 |
|---|---|
| 流程脚本数量 | 236 个 `noncombat_*`，覆盖网页版 52 个 systems 的绝大部分 |
| 行为对照未完成 | 审计记录「48 个脚本消费者仍标为待完整行为对照」 |
| 验收无法累积 | 150 次通过 → 1/12 签收 |

### 2.4 表现层

| 问题 | 实测 |
|---|---|
| 单节点场景 | 32/47 场景为「1 个根节点 + 挂脚本」 |
| 主界面单体 | `noncombat_opening_ui.gd` **2,546 行 / 131 处 `.new()`**，布局靠字面量 |
| 编辑器失效 | 改「按钮间距 12→16」需改代码重跑截图，不能拖拽 |
| F6 不能单跑 | `_ready()` 依赖 preload 兄弟脚本与 `user://` 存档，独立运行即崩 |
| 无 Theme | `Theme` 资源 0 个，样式每次 `_render()` 重建 `StyleBoxFlat` |
| 音频语义悬空 | `noncombat_opening_audio.gd` 写了 `bus` 字段，但 `default_bus_layout.tres` 不存在 |

### 2.5 信号与架构

| 问题 | 实测 |
|---|---|
| 单信号全量重绘 | 非战斗侧仅 1 个 `changed(event: Dictionary)`，`_on_opening_changed` 里 8 个 `if event.get("type") == "..."` 分支 |
| 字符串比较 | 拼错即**静默失效**，编译器无法拦截 |
| 无 autoload | `Registry`/`Repository` 每个 UI 各 new 一份 → JSON 重复解析 |

### 2.6 关键缺口：非战斗无法独立端到端验证

**这是本次诊断最重要的新发现。**

实测：`tests/` 中 `stub`/`fake` 相关文件数 = **0**。非战斗测试绕过战斗的方式是直接注入结果：

```gdscript
if game == null or not game.submit_battle_result(_result(request, row.outcome)):
```

**测试层能绕过，游玩层绕不过。** `main.tscn` 固定加载 `duel_stage_hd2d.tscn`，所以：

> 想验证「打完雷关之后剧情怎么走」，**必须真的打一场**。

后果：非战斗流程的「战斗中 → 战斗后」这一段，**当前无法在不做战斗的前提下验收**。这正是「刻意规避战斗」策略的最大技术障碍——不是战斗没做，是**非战斗因为战斗没做而验不完**。

---

## 三、整改优先级

### P0｜解除非战斗的独立验收阻塞（3 项）

| # | 措施 | 为什么是 P0 |
|---|---|---|
| **P0-1** | 建战斗桩（BattleStub） | 没有它，非战斗永远验不完「战斗后」部分 |
| **P0-2** | 资产缺失可见化 + 同步脚本改全量发现 | 86% 立绘缺失是玩家第一分钟就看到的问题，且目前完全不可见 |
| **P0-3** | 验收改三态 + 子项计分账本 | 不做这个，后续所有工作都无法体现为进度 |

### P1｜结构性债务（3 项）

| # | 措施 | 为什么是 P1 |
|---|---|---|
| **P1-1** | 拆 `noncombat_domain.gd`（6,476 行 / 62 preload） | 每加一个非战斗功能都要动它，是长期成本源头 |
| **P1-2** | 非战斗信号强类型化 | 8 个字符串分支是目前最易静默出错的地方 |
| **P1-3** | 抽 5 个静态屏为 `.tscn` | 解锁 F6 单场景验证与编辑器调布局 |

### P2｜质量提升（3 项）

| # | 措施 | 为什么是 P2 |
|---|---|---|
| **P2-1** | Theme 资源化 | 影响换肤与编辑器预览，但不阻塞功能 |
| **P2-2** | 音频总线 + 非战斗 UI 音效 | 手感问题，非正确性问题 |
| **P2-3** | 字体内嵌（数字等宽 + 标题） | 排版质量，可后补 |

---

## 四、具体措施与验收要点

### P0-1｜战斗桩（BattleStub）

**问题**：非战斗无法在不实现战斗的前提下走完「进入战斗 → 战斗结果 → 返回剧情」。

**措施**：

1. 新建 `scripts/battle_stub.gd`，实现与 `duel_stage_*` 相同的最小接口：

```gdscript
class_name BattleStub
extends Node

## 仅用于非战斗侧端到端验证。生产环境由 combat_stage_router 替换为真实 stage。
## TIER: L1 | 不属于战斗系统，属于非战斗的可测试性基础设施。

signal battle_finished(result: Dictionary)

var _forced_outcome: String = ""   # win / loss / flee；空则由 request 决定

func run(request: Dictionary) -> void:
    var outcome := _forced_outcome if _forced_outcome != "" else "win"
    # 立即产出符合 gateway.validate_result 契约的结果，不播放任何演出
    battle_finished.emit(_build_result(request, outcome))

func _build_result(request: Dictionary, outcome: String) -> Dictionary:
    return {
        "encounterId": request.get("encounterId", ""),
        "sourceCardId": request.get("sourceCardId", ""),
        "outcome": outcome,
        "playerHp": 1 if outcome == "win" else 0,   # 极简：只满足契约必需字段
        "turns": 1,
    }
```

2. 在 `combat_stage_router.gd` 增加开关：`stub_mode = true` 时返回 `BattleStub`，否则返回真实 stage。
3. 非战斗端到端测试统一走 stub，**不再手工 `submit_battle_result` 注入**。

**验收要点**：

| 项 | 判定 |
|---|---|
| 契约一致 | `BattleStub` 产出的 result 能通过 `noncombat_battle_gateway.validate_result()` |
| 端到端可跑 | 至少 3 条自然路线（雷关 / 剑修试炼 / 势力遭遇）从剧情 → 战斗 → 返回 → 下一卡完整走通 |
| 零演出依赖 | stub 不加载任何 `duel_stage_*`、不需要 VFX、不需要敌方动作帧 |
| 可替换 | 关闭 stub 后，原有真实战斗路径不报错 |

**成本**：约 3 小时（含 3 条路线验证）

---

### P0-2｜资产缺失可见化 + 同步脚本改造

**问题**：立绘缺 86%、场景图 531 已覆盖但立绘几乎全空，且 `texture_for()` 静默返回 `null`，问题长期不可见。根因是同步脚本按单遭遇手工枚举。

**措施**：

（a）`runtime_data_registry.gd` 加缺失登记与占位：

```gdscript
var missing_textures: Dictionary = {}

func texture_for(source_path: String) -> Texture2D:
    # ... 现有解析逻辑
    var resource = load(full)
    if not resource is Texture2D:
        missing_textures[full] = int(missing_textures.get(full, 0)) + 1
        push_warning("[ASSET_MISSING] " + full)
        return _placeholder_texture()   # 洋红占位，绝不返回透明
    return resource
```

（b）`sync_runtime_content.py` 第 69–290 行改为三段式：`collect_refs()` 遍历 `content/data/**/*.json` 提取全部 `assets/` 引用 → `resolve()` 复制并登记别名 → `report()` 产出 `asset_migration_report.json`。**保留**现有魔数校验与 18 条 runtimeAlias 登记。

**验收要点**：

| 项 | 判定 |
|---|---|
| 缺失可见 | 启动后控制台出现 `[ASSET_MISSING]` 行；缺失处显示洋红占位而非透明 |
| 引用总数 | `--dry-run` 报出的 `total_refs` 与审计值 3,092 同量级 |
| 别名不丢 | `content/source_manifest.json` 原有 18 条别名重跑后一条不少 |
| 立绘覆盖率 | 同步后 `noncombat` 立绘覆盖 ≥ 70%（从当前 14%） |
| 报告可读 | `asset_migration_report.json` 含 `coverage` 与 `missing_from_source` 清单 |

**成本**：约 1 天（脚本改造半天 + 同步与验证半天）

---

### P0-3｜验收改三态 + 子项计分账本

**问题**：150 次 `退出 0` 换不来 1 个阶段签收，签收率 0.7%。

**措施**：

1. 签收改三态：

| 态 | 条件 | 可用性 |
|---|---|---|
| 未开始 | 无证据 | — |
| **功能性通过** | L0 可加载 + L1 冒烟 + L2(Tier A) 全过 | **可继续开发后续模块** |
| 完全签收 | + L3 边界 + L4 视觉 + Tier B/C 达标 | 可进发布候选 |

2. 新建 `MIGRATION_SCORECARD.md`，把 N1–N11 拆为原子子项（≥30 个），每条历史证据归账。
3. 非战斗子项**允许带「未覆盖」备注签收**。

**验收要点**：

| 项 | 判定 |
|---|---|
| 归账完整 | 150 条历史 `退出 0` 全部可检索到归属，未归类 = 0 |
| 可读性 | 不看任务书也能从账本读出「非战斗完成 X%」 |
| 数字会动 | 任一项工作完成后账本数字立即变化 |

**成本**：约 1.5 天

---

### P1-1｜拆 `noncombat_domain.gd`

**问题**：6,476 行 / 62 个 `preload`，非战斗最大的重构债务，每加功能都要动它。

**措施**：按现有 Flow 边界聚为 5 个协作类，域类只保留状态机与调度：

| 新类 | 承接 |
|---|---|
| `EncounterDirector` | 已有，扩展 |
| `VendorDirector` | 坊市 / 鬼市 / 正规坊 |
| `DungeonDirector` | 洞府 / 遗迹 / 地宫 |
| `NarrativeDirector` | 剧情线 / 线程 / 因果展示 |
| `ProgressionDirector` | 境界 / 里程碑 / 转世 |

**验收要点**：

| 项 | 判定 |
|---|---|
| 单文件行数 | `noncombat_domain.gd` < 2,000 行 |
| 行为不变 | 拆分前后全量非战斗测试断言数不减少、全绿 |
| 扇出下降 | 单文件 `preload` 数 ≤ 20 |
| 分步执行 | 一次只拆一个 Director，拆完即跑全量 |

**成本**：3~4 天（**必须分 5 次提交，不可一次重写**）

---

### P1-2｜非战斗信号强类型化

**问题**：非战斗侧只有 1 个 `changed(event: Dictionary)`，8 个 `if event.get("type") == "..."` 分支，字符串拼错静默失效。

**措施**：

```gdscript
signal started(card_id: String)
signal restored(card_id: String)
signal choice_committed(next_card_id: String)
signal battle_requested(encounter_id: String)
```

移除 8 个字符串分支，改独立回调。**保留 `_render()` 全量重绘模式**（该模式保证 UI 不与状态漂移，是优点，成本问题归 P1-3/P2-1）。

**验收要点**：

| 项 | 判定 |
|---|---|
| 无字符串比较 | `grep -rn 'event.get("type")' scripts/` = 0 |
| 主链路 | 剧情推进 / 战斗请求 / 存档恢复 三条链各走一次 |
| 类型可见 | 故意传错参数，编辑器即报错 |

**成本**：1 天

---

### P1-3｜抽 5 个静态屏为 `.tscn`

**问题**：`noncombat_opening_ui.gd` 2,546 行 / 131 处 `.new()`，布局靠字面量，改间距要改代码重跑截图。

**措施**：把存档槽 / 取名 / 选路 / 剧情 / 结局 5 屏的 `_build_xxx_screen()` 各抽为独立 `.tscn`，脚本只留 `bind(state)` 与信号处理。**一次只抽 1 屏**，从存档槽开始。

**验收要点**：

| 项 | 判定 |
|---|---|
| F6 可单跑 | 抽出的场景独立运行不崩 |
| 编辑器可调 | 间距/锚点可在编辑器拖拽，不碰代码 |
| 视觉不变 | 抽出前后 `capture_*` 截图逐像素比对 |
| 代码减少 | `_build` 系列减少约 700 行 |

**成本**：每屏 0.5 天，本期先做 2 屏

---

### P2 三项（简述）

| 措施 | 验收要点 | 成本 |
|---|---|---|
| Theme 资源化 | 改 `theme/main.tres` 一处语义色，全局 UI 同步变化 | 1 天 |
| 音频总线 + UI 音效 | 五总线（Master/BGM/SFX/Voice/UI）可独立调；补 5 个 UI 音效（click/page/error/confirm/hover），接上已悬空的 `bus` 字段 | 1 天 |
| 字体内嵌 | 数字等宽不抖；字体子集化 42MB → 8MB 以内 | 0.5 天 |

---

## 五、战斗系统：预留接口与后续接入说明

### 5.1 接口契约（本次冻结，不实现）

非战斗与战斗之间只走**三元组**，这三者的数据形状在本次整改中冻结：

| 接口 | 生产者 | 消费者 | 契约 |
|---|---|---|---|
| `offer_from_state(state)` | `noncombat_battle_gateway` | 非战斗 UI（显示备战） | 返回可用的战斗邀约 |
| `build_request(state)` | `noncombat_battle_gateway` | 战斗系统 | 战斗所需全部输入 |
| `validate_result(state, result)` | `noncombat_battle_gateway` | 非战斗流程（接回） | 校验并消费战斗结果 |

**冻结要求**：三条方法的**入参键名、返回键名、必需字段**在本次整改期内不得变更。任何变更需走显式评审。

### 5.2 战斗桩与真实战斗的替换点

```
combat_stage_router.gd
    ├── stub_mode = true   → BattleStub（本次实现）
    └── stub_mode = false  → duel_stage_*（后续接入）
```

**替换成本评估**：接入真实战斗时，只需把 `stub_mode` 关掉，非战斗侧**一行不用改**。这是本次预留要达到的效果。

### 5.3 后续接入清单（不在本次范围，仅登记）

| 待接入项 | 前置条件 | 预估 |
|---|---|---|
| 真实战斗 stage 接入 router | `BattleStub` 契约验证通过 | — |
| 战斗结果结算（伤害/护盾/暴击） | `combat_domain` 数值定稿 | — |
| 敌方动作帧 | 资产补全（42/54 遭遇零帧） | — |
| VFX 特效 | 163 条资产验收（当前 `finalArtApproved` 全 false） | — |
| HD-2D / 3D 美术 | 建筑 GLB、8 方向角色母体 | — |
| `noncombat_battle_victory_flow` 补测试 | 当前仅 3 个测试，偏薄 | 0.5 天 |

### 5.4 唯一需要现在做的战斗相关事

**只有当它是「非战斗的验收前置」时才做**：

| 事项 | 属于非战斗吗 | 本次做吗 |
|---|---|---|
| `BattleStub` | ✅ 是非战斗的可测试性基础设施 | **做（P0-1）** |
| `battle_gateway` / `return_flow` / `victory_flow` | ✅ 是非战斗流程的一部分 | **做（保持稳定）** |
| `combat_stage_router` 的 stub 开关 | ✅ 是接缝 | **做（加开关）** |
| `duel_stage_*` 表现 | ❌ 是战斗 | 不做 |
| `combat_domain` 数值 | ❌ 是战斗 | 不做 |
| 战斗测试补齐 | ❌ 属战斗 | 不做 |

---

## 六、验收要点汇总

### 6.1 本期（P0）结项条件

| # | 条件 | 判定方式 |
|---|---|---|
| 1 | 战斗桩可用 | 3 条自然路线经 stub 完成「剧情→战斗→返回→下一卡」 |
| 2 | 桩契约合规 | stub 结果通过 `validate_result()` |
| 3 | 缺失可见 | 启动出现 `[ASSET_MISSING]`；缺失处显示占位 |
| 4 | 同步全量 | `asset_migration_report.json` 产出，立绘覆盖 ≥ 70% |
| 5 | 证据归账 | 账本未归类 = 0 |
| 6 | 三态生效 | 至少 1 个子项标为「功能性通过」（建议首战或 N1-a） |

### 6.2 非战斗专项验收门槛（长期）

| 层 | 门槛 |
|---|---|
| L0 可加载 | 非战斗场景 100% F6 无错 |
| L1 冒烟 | 每条主流程（任务/坊市/因果/同伴/世界/境界/转世）各 1 条端到端 |
| L2 行为等价 | Tier A（决定 0–50）逐卡 100%；Tier B 每族 ≥1 条；Tier C 只求不崩 |
| L3 边界 | 5 类存档（新档/旧档/坏字段/跨世/长历史）× 2 槽 |
| L4 视觉 | 人工清单，**不阻塞 L0–L3** |
| 单测耗时 | ≤ 120 秒 |
| 资产 | 可加载 100%，缺失告警 ≤ 5 |

### 6.3 非战斗「完成」的定义（本阶段）

> **非战斗模块完成 = 全部 Tier A 行为等价 + 全部 Tier B 有代表路线 + 战斗桩可替换 + 账本数字可读。**

不要求：战斗实现、战斗美术、VFX、敌方帧。

---

## 七、时间安排（12 天，2026-11-04 ~ 11-15）

| 日期 | 事项 | 产出 |
|---|---|---|
| **11-04** | 战斗桩 + router 开关 | `battle_stub.gd`；1 条路线跑通 |
| 11-05 | 战斗桩验证 3 条路线 | 3/3 端到端 |
| 11-06 | 资产缺失可见化 | `[ASSET_MISSING]` 生效 |
| 11-07 | 同步脚本改全量发现 | `asset_migration_report.json` |
| 11-08 | 首次全量同步 | 立绘覆盖 ≥ 70% |
| 11-09 | 计分账本骨架 + 前 80 条归账 | 账本可查 |
| 11-10 | 剩余 70 条归账 + N1 拆子项 | 未归类 = 0 |
| 11-11 | 非战斗信号强类型化 | 8 个字符串分支移除 |
| 11-12 | 抽第 1 屏为 `.tscn`（存档槽） | F6 可单跑 |
| 11-13 | 抽第 2 屏（取名） | F6 可单跑 |
| 11-14 | `noncombat_domain` 拆第 1 个 Director | `VendorDirector` 独立 |
| **11-15** | 全量回归 + 复盘 | 全绿 + 门槛调整结论 |

> `noncombat_domain` 的 5 次拆分跨期，本期只完成 1 个。

---

## 八、风险与不做的事

### 风险

| 风险 | 预案 |
|---|---|
| 战斗桩过于简化导致真实接入时返工 | 桩必须走 `validate_result()` 真实校验，不许自己造一套宽松格式 |
| 同步全量后发现源工程也没图 | `missing_from_source` 清单即美术创作清单，转交 ART |
| 拆 domain 引入回归 | 一次只拆一个 Director，拆完即跑全量 |

### 明确不做

| 不做 | 原因 |
|---|---|
| 补战斗表现、战斗数值、战斗测试 | 前提已明确：战斗刻意延后 |
| 补 VFX 591 帧 | 资产未验收，补了必返工 |
| 物理删除网页版 | 依赖未解除（见 `MIGRATION_STATUS_2026-11-04.md`） |
| 一次拆完 `noncombat_domain` | 6,476 行一次重写风险不可控 |

---

**文档版本**：v1.0（非战斗聚焦版）  
**制定日期**：2026-11-04  
**前提声明**：战斗系统为本阶段刻意规避项，本文档不对战斗完成度作任何要求  
**复审节点**：2026-11-15
