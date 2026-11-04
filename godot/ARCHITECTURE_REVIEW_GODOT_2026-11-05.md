# 一念仙途 Godot 工程 · 架构梳理与节点使用审计

| 项 | 内容 |
|---|---|
| 审计日期 | 2026-11-05 |
| 工程根 | `E:/4e/游1/2026-06-27-05-40-58/xiuxian-card-game/godot` |
| 基线版本 | `c268384` / tag `baseline-2026-11-05-pre-noncombat-remedy` |
| 引擎 | Godot 4.7.2 Stable / Forward+ / 1280×800 |
| 审计方式 | 静态扫描（`.tscn` 节点树、`.gd` 依赖图、信号与生命周期特性统计）+ 关键文件人工阅读 |
| 未执行 | 编辑器实机运行、Profiler 采样、F6 单场景逐个校验 |

标注约定：**实测** = 本次扫描直接得出；**推断** = 基于代码语义判断，需实机或行为对照确认。

---

## 一、项目整体架构现状

### 1.1 一句话概括

> **这是一个「3D 用节点、UI 用代码」的双轨工程**：3D 世界真正用起了 Godot 的节点树（单场景 689 节点），而全部 UI 走的是「1 个 Control 挂 2500 行脚本、448 次 `add_child` 现场拼装」的路径。

这不是「没学会 Godot」，而是**迁移策略的必然产物**：浏览器版是 DOM + JS 动态生成，用代码重放 DOM 能最大程度保证逐帧一致。但迁移已过验证期，这套形态正在成为迭代成本的来源。

### 1.2 场景组织（实测）

| 指标 | 数值 |
|---|---|
| 场景总数 | 47 |
| **单节点场景** | **32（68%）** |
| 节点总数（全项目） | 990 |
| 最大场景 | `cangmang_real_3d_world.tscn` **689 节点** |
| 主场景 | `noncombat_opening.tscn`（**1 个 Control 节点 + 2562 行脚本**） |

**节点数分布（实测）**：

| 节点数 | 场景个数 | 代表 |
|---|---|---|
| 1 | **32** | `noncombat_opening`、`duel_stage_*_2d`（多数）、`equipment_demo` |
| 2 | 1 | — |
| 5 | 2 | — |
| 11–12 | 7 | `duel_stage_hd2d`、`duel_stage_real_3d`、`qingyun_pixel_battle_stage` |
| 18–25 | 2 | `cangmang_trial_architecture` |
| 61–73 | 2 | `quick_sword_dummy_real_3d`、`yelingyun_s1_real_3d` |
| 689 | 1 | `cangmang_real_3d_world` |

**节点类型分布（实测，全项目 990 个节点）**：

| 类型 | 数量 | 归属 |
|---|---|---|
| `MeshInstance3D` | **794** | 3D 世界几何 |
| `CylinderMesh` / `ArrayMesh` / `BoxMesh` / `SphereMesh` | 561 / 138 / 70 / 24 | 3D 网格资源 |
| `Node3D` | 60 | 3D 层级 |
| `Script` | 41 | 挂脚本的节点 |
| **`Control`** | **29** | **全部 UI 只剩 29 个 Control** |
| `OmniLight3D` / `Marker3D` | 27 / 16 | 3D 光照与锚点 |
| `Node2D` | 10 | 2D 演出 |
| `SpriteFrames` / `ShaderMaterial` | 8 / 8 | 动画与着色 |

**这张表是全篇最重要的一张**：990 个节点里 794 个是 3D 几何体，**UI 侧只有 29 个 Control 节点**。也就是说，玩家看到的全部菜单、剧情、卡片、图鉴、地图，几乎没有一个是通过节点树表达的。

### 1.3 脚本分层（实测 135 个脚本 / 54,360 行）

| 层 | 代表文件 | 行数 | 职责 | 形态 |
|---|---|---|---|---|
| **数据层** | `noncombat_content_repository.gd` | 1,068 | JSON 模块索引、SHA 校验、路径解析 | `RefCounted` |
| | `runtime_data_registry.gd` | ~140 | 贴图/帧解析、来源清单别名 | `RefCounted` |
| **领域层** | `noncombat_domain.gd` | **6,476** | 状态机 + 全部流程调度 + 结算 | `RefCounted` |
| | `combat_domain.gd` | 1,120 | 战斗权威规则 | `RefCounted` |
| **流程层** | `noncombat_*_flow.gd`（约 60 个） | 200~1,305 | 单一机制：任务/坊市/因果/同伴/世界… | `RefCounted` |
| | `noncombat_normal_choice_policy.gd` | 1,332 | 普通卡抉择策略 | `RefCounted` |
| | `noncombat_realm_gate_flow.gd` | 1,305 | 境界关隘 | `RefCounted` |
| **接口层** | `noncombat_battle_gateway.gd` | 1,918 | 战斗邀约/请求/战果校验 | `RefCounted` |
| | `noncombat_battle_return_flow.gd` | 614 | 战果结算与返回 | `RefCounted` |
| **表现层** | `noncombat_opening_ui.gd` | **2,562** | 全部非战斗界面（6 个屏） | `Control` |
| | `duel_stage_hd2d.gd` | 1,471 | HD-2D 战斗演出 | `Control` |
| | `card_hand_ui.gd` / `reference_battle_hud.gd` | — | 手牌与 HUD | `Control` |
| **入口** | `main.gd` | 928 | 战斗场景总装 | `Control` |

**分层意图是清楚的**：`UI(Control) → Domain(RefCounted) → Flow(RefCounted) → Repository → Registry`。问题不在意图，在**每层内部的形态**。

### 1.4 依赖关系（实测 436 处 `preload`）

**扇出 Top（一个文件依赖多少个兄弟）**：

| 文件 | 扇出 | 判断 |
|---|---|---|
| `noncombat_domain.gd` | **62** | 上帝对象，唯一热点（其余 ≤37） |
| `main.gd` | 37 | 战斗 scene 启动器 |
| `noncombat_opening_ui.gd` | 32 | UI 直接持有全部 Flow |
| `noncombat_battle_return_flow.gd` | 16 | — |
| `noncombat_battle_gateway.gd` | 13 | — |

**扇入 Top（被多少个文件依赖）**：

| 文件 | 扇入 |
|---|---|
| `noncombat_legacy_fragment_flow.gd` | **33** |
| `noncombat_content_repository.gd` | 28 |
| `noncombat_milestone_flow.gd` | 27 |
| `noncombat_path_skill_flow.gd` | 18 |
| `noncombat_treasure_acquisition.gd` | 17 |
| `runtime_data_registry.gd` | 12 |

**依赖形态**：全部走 `preload("res://scripts/xxx.gd")` + `const X = ...`，**没有一处 `class_name`**（本次新增的 `BattleStub` 是全项目第 1 个）。后果：

- 编辑器无法跨文件补全（只能补 `RefCounted` 的 4 个方法）
- 无法为成员声明具体类型，只能写 `var opening: RefCounted`（实测 192 处）
- 无循环依赖检测

### 1.5 信号使用（实测 42 个 `signal` 声明，162 处 `.connect`）

| 区域 | 信号数 | 形态 |
|---|---|---|
| 战斗 stage（`duel_stage_*`） | 各 4 个 | `battle_finished` / 状态变更等 |
| 非战斗侧 | **3** | `changed(event: Dictionary)`、`voice_subtitle_changed`、`closed` |
| 其余 | — | 多为局部信号 |

**非战斗侧只有一个主信号**：

```gdscript
# noncombat_domain.gd:67
signal changed(event: Dictionary)
```

配套的是 `_on_opening_changed` 里的 `if event.get("type") == "..."` 八个分支 + `_render()` 全量重绘。

**这个模式本身不坏**——它保证 UI 不会与 domain 状态漂移，是刻意的设计选择。代价有两条：
1. 全量重绘的成本压在 2,562 行的 `_render()` 上
2. `event: Dictionary` 让信号失去类型约束力，`type` 拼错即静默失效，编译器无法拦截

### 1.6 Autoload：完全空缺

`project.godot` 全文只有 4 个 section（实测）：

```ini
config_version=5
[application]      name / main_scene / features
[display]          1280×800
[editor_plugins]   godot_mcp_bridge
[rendering]        forward_plus / nearest_mipmap
```

**缺失项**：`[autoload]`、`[input]`、`[gui] theme`、`[audio]` bus layout、`[global_group]`、`[layer_names]`、`config/icon`。

**直接后果（实测）**：`Registry.new()` 与 `Repository.new()` 在每个 UI 里各建一份，JSON 重复解析、缓存不共享。`noncombat_opening_ui.gd` 第 131 行 `registry = Registry.new()` 就是其中一处。

### 1.7 资源组织

```
godot/
├─ content/                   运行时唯一内容根（973MB）
│  ├─ data/                   77 个 JSON（9.1MB）← 唯一权威数据
│  ├─ assets/                 897MB ← 由同步脚本生成，不入 git
│  ├─ media_frames/           58MB 抽帧中间产物
│  └─ source_manifest.json    别名表（18 条 runtimeAliases）
├─ assets/                    1.7GB ← 旧 3D 模型，仍被 6 个场景直接引用
├─ art_source/                1.6GB .blend 源文件（不入包）
├─ art_direction/             383MB 概念图（不入包）
└─ dist/                      2.5GB 导出包
```

**问题**：`content/assets` 与 `assets/` **两套资源根同时参与运行时**。卡面/立绘走 `texture_for()` 收口，3D 模型却直接写 `res://assets/hd2d/...glb`。这导致打包排除规则无法统一、清理 `assets/` 时无法一刀切。

### 1.8 数据流全貌

```
content/data/*.json  (77 个模块)
        ↓  read_json / read_module（含 SHA 校验）
noncombat_content_repository  ←── 28 个文件依赖
        ↓
noncombat_*_flow（约 60 个 RefCounted，单一机制）
        ↓  preload 直连（436 处）
noncombat_domain（6476 行状态机，62 扇出）
        ↓  signal changed(event: Dictionary)（唯一出口）
noncombat_opening_ui（2562 行，132 处 .new()，448 处 add_child）
        ↓
屏幕（32 个单节点场景之一）
```

**战斗侧**是另一条独立链：

```
noncombat_battle_gateway（1918 行：offer → request → validate_result）
        ↓  noncombat_opening_ui:2244  实例化 main.tscn
main.gd（928 行，37 扇出）→ 10 个 duel_stage_* 场景
        ↓  battle_finished(result)
noncombat_battle_return_flow（614 行）→ domain.submit_battle_result
```

---

## 二、需要调整的架构

### 2.1 与 Godot 理念不符的六处

#### 问题 A｜UI 层放弃节点树（严重度：高）

**位置**：`scenes/*.tscn`（32 个单节点场景）、`scripts/noncombat_opening_ui.gd`（132 处 `.new()`）

**现象（实测）**：
- 全项目 UI 只有 **29 个 `Control` 节点**
- `add_child()` **448 处**、`.new()` 在 `noncombat_opening_ui.gd` 里 **132 处**
- `_build()` + 6 个 `_build_*_screen()` 合计占该文件大部分篇幅

**为什么不符合 Godot 理念**：Godot 的核心设计是「everything is a node」——布局、锚点、可见性、焦点顺序由节点树和容器（`VBoxContainer`/`MarginContainer`）表达，编辑器可视化调整。当前形态等于把 Godot 当成「一个画布 + 一个 god script」，编辑器退化为脚本启动器。

**具体代价**：
1. 改「按钮间距 12→16」需要改代码、重跑、截图比对，不能在编辑器拖
2. 单节点场景 `_ready()` 直接依赖 `preload` 的兄弟脚本和 `user://` 存档，**F6 单跑即 null 崩溃**，违背「每个场景必须可独立实例化」
3. `.tscn` 与 `.gd` 的 diff 语义错位：节点结构变更全在 `.gd` 的 2,562 行里，code review 看不出「界面变了什么」
4. 6 个屏共享一个脚本，任何一个屏的改动都可能影响其他屏

**目标结构**：

```
scenes/noncombat/
├─ opening_root.tscn            根：仅一个 Control + 屏幕容器
├─ screens/
│  ├─ slot_screen.tscn          存档槽（独立、可 F6）
│  ├─ name_screen.tscn          取名
│  ├─ path_screen.tscn          选路
│  ├─ story_screen.tscn         剧情（含立绘区、选项区、HUD）
│  └─ ending_screen.tscn        结局
└─ shared/
   ├─ choice_row.tscn           选项行（可复用）
   ├─ portrait_panel.tscn       立绘面板
   └─ card_peek.tscn            卡面预览
```

脚本只保留 `bind(state)` 与信号处理，`_build_*` 系列（约 700 行）消失。

---

#### 问题 B｜没有 Autoload，全局服务靠每个 UI 各 new 一份（严重度：高）

**位置**：`project.godot`（无 `[autoload]` 段）、`noncombat_opening_ui.gd:131`

**现象**：`registry = Registry.new()` 在每个需要取图的 UI 里各执行一次。`Repository` 同理。

**代价**：
- JSON 重复解析（`content/data` 77 个模块、9.1MB）
- 缓存不共享（`_texture_aliases` 每个实例各加载一次）
- 无法做跨场景状态（如全局音量、阅读偏好需要靠存档文件传）

**目标结构**：

```gdscript
# autoload/data_service.gd  —— 只做服务定位，不放玩法逻辑
extends Node
## 单一 Registry/Repository 实例，跨场景共享。
## 生命周期：应用启动 → 退出。禁止在此放状态机。
var registry: RuntimeDataRegistry
var repository: NoncombatContentRepository
```

```
[autoload]
DataService="*res://autoload/data_service.gd"
```

**边界纪律**：Autoload 只放「真正的全局服务」（数据访问、音效总线、设置）。**不放玩法逻辑**——`noncombat_domain` 必须保持可实例化，否则测试无法隔离。

---

#### 问题 C｜零 `class_name` 导致类型系统退化（严重度：中高）

**位置**：全部 135 个脚本（`class_name` 计数 = 1，即本次新增的 `BattleStub`）

**现象与代价（实测）**：

| 指标 | 数值 | 后果 |
|---|---|---|
| `var x: RefCounted` | 192 处 | 编辑器只能补 4 个方法 |
| `Dictionary` 标注 | 1,971 处 | 键名拼错得 `0`，不报错 |
| `Variant` 标注 | 829 处 | 完全无约束 |
| `Array`（无元素类型） | 430 处 | 迭代无类型检查 |

**本次改动的实证**：写 `var texture := registry.texture_for(path)` 时报

```
Parse Error: Cannot infer the type of "texture" because the value doesn't have a set type
```

因为 `registry` 声明为 `RefCounted`。这不是偶发——**每写一行链式调用都要显式标类型**，这正是 192 处占位类型的实际成本。

**目标结构**：给核心类加 `class_name`（机械改动，风险极低）：

```gdscript
class_name NoncombatDomain      extends RefCounted   # 6476 行，62 扇出
class_name NoncombatContentRepository extends RefCounted
class_name RuntimeDataRegistry  extends RefCounted
class_name NoncombatOpeningUI   extends Control
class_name CombatDomain         extends RefCounted
```

然后 192 处 `var x: RefCounted` → 具体类型。

**不建议**在本轮动 `Dictionary`/`Variant` 那 3,400 处——那需要自定义 `Resource` 类，是中期工程。

---

#### 问题 D｜`noncombat_domain.gd` 是上帝对象（严重度：中高）

**位置**：`scripts/noncombat_domain.gd`（6,476 行 / 62 扇出）

**现象**：把 encounter / vendor / dungeon / rebirth / story-thread / karma / companion / world 的流程编排全部收在一个类里。其余文件扇出均 ≤37，它一个 62。

**代价**：
- 每加一个非战斗功能都要动它，是长期成本源头
- 无法单独测试任一流程（必须构造完整 domain）
- 6,476 行超出单文件可维护上限

**目标结构**（按现有 Flow 边界聚 5 个协作类，域类只留状态机与调度）：

| 新类 | 承接 | 预估行数 |
|---|---|---|
| `EncounterDirector` | 已有，扩展 | — |
| `VendorDirector` | 坊市 / 鬼市 / 正规坊 | ~900 |
| `DungeonDirector` | 洞府 / 遗迹 / 地宫 | ~800 |
| `NarrativeDirector` | 剧情线 / 线程 / 因果展示 | ~1,200 |
| `ProgressionDirector` | 境界 / 里程碑 / 转世 | ~1,000 |

**执行纪律**：一次只拆一个 Director，拆完即跑全量，独立提交。

---

#### 问题 E｜非战斗信号面过窄（严重度：中）

**位置**：`noncombat_domain.gd:67`

**现象**：非战斗侧只有 1 个 `changed(event: Dictionary)`，配 8 个 `if event.get("type") == "..."` 分支。

**代价**：字符串拼错**静默失效**。这是全项目最容易被忽略的缺陷类型——没有崩溃、没有日志，只是某个功能"偶尔不生效"。

**目标结构**：

```gdscript
signal card_started(card_id: String)
signal choice_committed(next_card_id: String, decision_index: int)
signal battle_requested(encounter_id: String)
signal battle_settled(outcome: String)
signal state_restored(slot_id: String)
```

**保留** `_render()` 全量重绘模式——该模式保证 UI 不漂移，是优点。只解决「信号失去类型约束力」这一条。

---

#### 问题 F｜零 `@export NodePath`，节点引用靠硬编码（严重度：中）

**位置**：全部脚本（`@export var ... NodePath` **0 处**）

**现象**：`get_node()` **63 处**（集中在战斗侧：`duel_stage_hd2d` 20、`card_hand_ui` 17、`real_3d_fighter` 10、`reference_battle_hud` 7）；`@onready` 仅 35 处。

> **需要修正一处旧结论**：此前的审计报告写「`get_node("路径")` 运行期查找 0 处（全走 `@onready`/构造期持有）」。**实测为 63 处 `get_node`、35 处 `@onready`，该结论有误**，应以此处为准。

**代价**：路径是字符串字面量，节点改名即运行期崩溃；且无法在编辑器里拖拽指定引用。

**目标结构**：

```gdscript
@export var hand_container: NodePath
@onready var _hand: Control = get_node(hand_container)
```

配合拆出来的 `.tscn`，节点引用由编辑器配置，脚本不再知道具体路径。

---

### 2.2 目标架构全景

```
┌─ Autoload（3 个，只放服务）──────────────────────────┐
│  DataService    Registry + Repository 单例           │
│  AudioBus       BGM/SFX/Voice/UI 四总线              │
│  GameSettings   阅读偏好、音量、特效档位              │
└──────────────────────────────────────────────────────┘
                          ↓
┌─ 场景层（每个可 F6 独立运行）────────────────────────┐
│  noncombat/opening_root.tscn                         │
│    └─ screens/{slot,name,path,story,ending}.tscn     │
│    └─ shared/{choice_row,portrait_panel}.tscn        │
│  combat/duel_stage.tscn（1 个骨架 + 30 份数据）       │
└──────────────────────────────────────────────────────┘
                          ↓
┌─ 领域层（class_name + 强类型信号）───────────────────┐
│  NoncombatDomain（状态机，< 2000 行）                 │
│    ├─ VendorDirector / DungeonDirector               │
│    ├─ NarrativeDirector / ProgressionDirector        │
│    └─ EncounterDirector                              │
│  CombatDomain（战斗权威规则）                         │
└──────────────────────────────────────────────────────┘
                          ↓
┌─ 接口层（冻结契约）──────────────────────────────────┐
│  BattleGateway: offer → request → validate_result    │
│  BattleStub（非战斗验证） / duel_stage_*（真实战斗）  │
└──────────────────────────────────────────────────────┘
                          ↓
┌─ 数据层（单一资源根）────────────────────────────────┐
│  content/data/*.json  ← 唯一权威                     │
│  content/assets/*     ← 由同步脚本生成                │
│  Theme/main.tres      ← 样式资源化                    │
└──────────────────────────────────────────────────────┘
```

---

## 三、游戏目标达成度分析

### 3.1 目标锚点：来自任务书，不是我的判断

游戏要达成什么，`docs/GODOT_MIGRATION_EXECUTION_TASKBOOK_2026-10-15.md` 已经写明，我直接引用而不再重新定义：

| # | 设计支柱（原文） |
|---|---|
| 1 | **看得懂**：卡牌费用、效果、目标、敌方意图和战斗结果一眼可辨 |
| 2 | **出手有因果**：蓄势、身体动作、命中、伤害数字、声音和受击回应在同一节拍 |
| 3 | **角色有生命**：待机有细小呼吸、重心变化；不同功法的动作轮廓可辨 |
| 4 | **规则可信**：一次输入只结算一次，视觉停顿不改伤害、反应期限或奖励 |
| 5 | **旧进度可带走**：存档可导入、可回退、可核查 |

外加两条迁移硬约束：**保住规则/内容/进度**、**视觉升级到 HD-2D 级**。

### 3.2 逐条达成度

| 支柱 | 逻辑层（数据/规则） | 表现层（视听/演出） | 达成判断 | 架构瓶颈 |
|---|---|---|---|---|
| **1 看得懂** | ✅ 588 卡 / 75 模块 / 553 场景引用全部入库，`unlisted=0` | ⚠️ **卡面 41/174（24%）** —— 76% 的牌只能靠文字辨认 | **逻辑完备，表现阻塞** | 卡面缺失 + `card_hand_ui.gd:267` 无回退占位 |
| **2 出手有因果** | ✅ 战斗规则 `combat_domain` 1,120 行，首战完整链已过 | ⚠️ **VFX 60/651 帧（9%）**；敌方动作帧 42/54 遭遇零帧 | **规则到位，反馈层几乎空白** | VFX 资产未验收（163 条 `finalArtApproved` 全 false） |
| **3 角色有生命** | — | ⚠️ 仅 3 组待机动画（`jian-idle` 4 帧、`jiuwei-idle` 4 帧、`jiuwei-water` 60 帧）；剧情立绘**静态无呼吸** | **基本未达成** | 立绘系统是 `TextureRect` 单图，无 `AnimatedSprite2D`/`AnimationPlayer` 承担 |
| **4 规则可信** | ✅ 确定性轨迹对照已做到雷关决定 0–33；一次性结算有专项 | ✅ 权威结算在 `combat_domain`，演出层只消费 | **这条达成度最高** | 无——分层是对的 |
| **5 旧进度可带走** | ✅ 三槽位 + 战斗快照导入 + 并发锁 + 坏字段受控拒绝 | — | **逻辑完备，覆盖面不足** | 仅二号槽首世剑修有夹具；跨世/长历史旧档未验 |
| **视觉升级 HD-2D** | — | ❌ `M1_SLICE` 明写「视觉评审仍为 FAIL」；3D 场地是空间基线，建筑 GLB 未做 | **未达成** | 建筑资产 + 8 方向角色母体缺位 |

### 3.3 一句话结论

> **这个项目的逻辑层已经跑到 80~90%，表现层停在 10~25%，而架构正在让表现层的补齐变得昂贵。**

具体表现：
- 要补一张立绘，得改 2,562 行的 `_render()`（因为在代码里 `add_child`），而不是换一张资源
- 要做一次立绘的呼吸动画，当前 `TextureRect` 结构不支持（没有 `AnimatedSprite2D` 位）
- 要统一换肤，得改 `game_ui_skin.gd` 的 14 处 `StyleBoxFlat.new()`，而不是换一个 `Theme`

### 3.4 可迭代点与优先级

按「对玩家感知的贡献 ÷ 改动成本」排序：

| 优先级 | 迭代点 | 支撑支柱 | 成本 | 为什么这个优先级 |
|---|---|---|---|---|
| **P0** | 补齐卡面（133 张）+ 立绘（230 张） | 1、3 | 迁移为主 | 玩家第一分钟就看到；且多数是「漏拷」而非「没画」 |
| **P0** | `sprite_frames_for` 逐帧容错（已完成） | 2 | 已做 | 让 42 个零帧遭遇里已有的帧能用起来 |
| **P1** | 立绘区从 `TextureRect` 换成 `AnimatedSprite2D` + `SpriteFrames` | 3 | 中 | 这是「角色有生命」的**唯一**技术路径；节点结构必须先改，否则补了呼吸帧也放不进去 |
| **P1** | 抽 5 个静态屏为 `.tscn` | 1、3 | 中 | 解锁 F6 与编辑器调布局，让美术能独立改界面 |
| **P1** | `Theme` 资源化 | 1 | 低 | 换肤不改代码，一次投入长期受益 |
| **P2** | UI 音效补 5 个 | 2 | 低 | 「点击没生效」的误判来源；比补 VFX 便宜得多 |
| **P2** | 战斗 stage 数据驱动（1 骨架 + 30 数据） | 2 | 高 | 现在 23 个 stage 脚本 4,299 行重复 |
| **P3** | VFX 591 帧 | 2 | 很高 | **先过美术评审**，否则补完必返工 |
| **P3** | 3D 建筑 GLB / 8 方向角色母体 | 视觉 | 很高 | 需外部产出，非代码问题 |

**注意顺序**：P1 的「立绘换 AnimatedSprite2D」必须**先于**大规模补立绘资源。否则补完之后还要再改一次结构。

---

## 四、节点使用问题排查

### 问题清单总览

| # | 问题 | 位置 | 类型 | 严重度 |
|---|---|---|---|---|
| N-1 | 32 个单节点场景，UI 完全不走节点树 | `scenes/*.tscn` | 该用节点没拆 | 高 |
| N-2 | 单脚本承担 6 个屏，132 处 `.new()` 手搓 UI | `noncombat_opening_ui.gd` | 节点职责错位 | 高 |
| N-3 | 6,476 行 / 62 扇出的上帝对象 | `noncombat_domain.gd` | 职责过重 | 高 |
| N-4 | `main.gd` preload 25 个场景 | `main.gd:11-35` | 场景实例化不当 | 中高 |
| N-5 | 零 `@export NodePath`，63 处 `get_node` 硬编码 | `duel_stage_hd2d.gd`(20)、`card_hand_ui.gd`(17) 等 | 节点引用错位 | 中 |
| N-6 | 非战斗只有 1 个 `changed(Dictionary)` 信号 | `noncombat_domain.gd:67` | 信号使用不当 | 中 |
| N-7 | 无 Autoload，Registry/Repository 各 UI 各 new | `noncombat_opening_ui.gd:131` | 单例缺失 | 高 |
| N-8 | 无 Theme，14 处 `StyleBoxFlat.new()` 运行时重建 | `game_ui_skin.gd` 等 4 文件 | 资源特性未用 | 中 |
| N-9 | 23 个 `duel_stage_*` 脚本重复 4,299 行 | `duel_stage_*_2d.gd` | 该用数据驱动 | 中高 |
| N-10 | 162 处 `.connect` 但仅 1 处 `_exit_tree`、0 处 `disconnect` | 全局 | 信号生命周期 | 低 |
| N-11 | 15 个 `_process(delta)` 回调 | 分散各文件 | 轮询替代信号 | 低（多数合理） |

---

### N-1｜32 个单节点场景，UI 完全不走节点树

**位置**：`scenes/*.tscn`，32 个只有 1 个根节点的场景；主场景 `noncombat_opening.tscn` 就是其中之一。

**现象（实测）**：全项目 990 个节点中，`Control` 只有 **29 个**；`add_child()` 448 处。

**原因**：迁移期用代码重放浏览器 DOM 结构，能保证逐帧一致（326 个契约测试正依赖这种确定性）。**这在迁移期是正确选择。**

**影响**：
1. 编辑器失去价值——布局/间距全是 `Vector2(...)` 字面量，调整要改代码
2. **不能 F6 单场景校验**：`_ready()` 依赖 `preload` 兄弟脚本和 `user://` 存档，独立运行即 null 崩
3. `.tscn` 与 `.gd` 的 diff 语义错位，code review 看不出界面变化
4. 美术无法独立调整界面，必须经过程序

**建议**：按屏拆分，一次一个。

```
scenes/noncombat/screens/
  slot_screen.tscn     ← 先从这个开始（结构最简单）
  name_screen.tscn
  path_screen.tscn
  story_screen.tscn
  ending_screen.tscn
```

抽出后脚本只留 `bind(state)` 与信号处理，`_build_*` 系列约 700 行消失。

---

### N-2｜单脚本承担 6 个屏，132 处 `.new()` 手搓 UI

**位置**：`scripts/noncombat_opening_ui.gd`（2,562 行）
- `_build()` L202
- `_build_slot_screen()` L405
- `_build_name_screen()` L688
- `_build_path_screen()` L773
- `_build_story_screen()` L861
- `_build_experience_dialog()` L1108
- 另有 `_render()`

**原因**：所有屏共用一个脚本，靠 `visible = true/false` 切换。

**影响**：
1. **改动耦合**：改存档槽的按钮样式，要通读 2,562 行确认不影响其他 5 屏
2. 132 处 `.new()` 意味着 132 个对象在运行期创建，无编辑器预览
3. 无法继承/复用：两个屏都需要「选项行」时，只能各写一遍

**建议**：按 N-1 拆屏后，把跨屏复用的 UI 片段也做成 `.tscn`：

```
scenes/noncombat/shared/
  choice_row.tscn       ← 选项行（剧情/坊市/遭遇都复用）
  portrait_panel.tscn   ← 立绘面板
  hud_bar.tscn          ← 顶部状态条
```

---

### N-3｜6,476 行 / 62 扇出的上帝对象

**位置**：`scripts/noncombat_domain.gd`

**现象（实测）**：62 处 `preload`，其余文件扇出均 ≤37。把 encounter / vendor / dungeon / rebirth / story-thread / karma / companion / world 全部流程编排收在一个类。

**原因**：迁移时以「单一权威状态」为目标，把所有流程调度集中，保证状态转换可严格回放。**这个目标达成了**，代价是类膨胀。

**影响**：
1. 每加一个非战斗功能都要动它——长期成本源头
2. 无法单独测试任一流程（必须构造完整 domain）
3. 6,476 行超出单文件可维护上限
4. 它与 28 个 Flow 的关系是「全知」，任何 Flow 的接口变更都可能波及

**建议**：按现有 Flow 边界聚 5 个协作类，域类只留状态机与调度。

| 新类 | 承接 | 扇出目标 |
|---|---|---|
| `EncounterDirector` | 已有，扩展 | ≤15 |
| `VendorDirector` | 坊市/鬼市/正规坊 | ≤15 |
| `DungeonDirector` | 洞府/遗迹/地宫 | ≤15 |
| `NarrativeDirector` | 剧情线/线程/因果展示 | ≤15 |
| `ProgressionDirector` | 境界/里程碑/转世 | ≤15 |

**执行纪律**：一次只拆一个，拆完即跑全量，独立提交。目标 `noncombat_domain.gd` < 2,000 行。

---

### N-4｜`main.gd` preload 25 个场景

**位置**：`scripts/main.gd:11-35`

```gdscript
const DUEL_STAGE_HD2D_PATH := "res://scenes/duel_stage_hd2d.tscn"
const SpellStageScene = preload("res://scenes/duel_stage_spell_2d.tscn")
const BodyStageScene = preload("res://scenes/duel_stage_body_2d.tscn")
# … 共 25 个
```

**原因**：用 `const X = preload(...)` 做场景路由表，写法直观。

**影响（推断，需实机 Profiler 确认数值）**：
1. `preload` 是**编译期**加载——25 个 `PackedScene` 在脚本加载时全部解析，连带其 `ext_resource`（脚本、贴图、模型）
2. 玩家只打一场战斗，却承担全部 25 个 stage 的加载开销
3. 无法按需卸载
4. 新增一个 stage 就要改 `main.gd`（违反开闭原则）

**说明**：`.tscn` 本身很小（0~2KB，因为都是单节点），所以**不能夸大**为「几十 MB 内存」。真实代价是「25 个场景的依赖图全部提前加载」，具体数值需 Profiler 采样后才能定论。

**建议**：

```gdscript
# 改为按需加载 + 路由表用 String
const STAGE_ROUTES := {
    "qi_gate":   "res://scenes/duel_stage_qi_gate_2d.tscn",
    "spell":     "res://scenes/duel_stage_spell_2d.tscn",
    # …
}

func _load_stage(route_key: String) -> Control:
    var path: String = STAGE_ROUTES.get(route_key, "")
    if path.is_empty():
        push_error("[main] unknown stage route: " + route_key)
        return null
    return (load(path) as PackedScene).instantiate() as Control
```

若首战有明显卡顿，再用 `ResourceLoader.load_threaded_request()` 预热。

---

### N-5｜零 `@export NodePath`，63 处 `get_node` 硬编码

**位置（实测分布）**：

| 文件 | `get_node` 次数 |
|---|---|
| `duel_stage_hd2d.gd` | **20** |
| `card_hand_ui.gd` | **17** |
| `real_3d_fighter.gd` | 10 |
| `reference_battle_hud.gd` | 7 |
| `equipment_demo.gd` / `duel_stage_qingyun_pixel.gd` / `actor_wearable_demo.gd` | 3 / 2 / 2 |
| `noncombat_opening_ui.gd` | 1 |

全项目 `@export var ... NodePath` = **0 处**，`@onready` = 35 处。

> **修正旧结论**：此前审计报告写「`get_node("路径")` 运行期查找 0 处（全走 `@onready`/构造期持有）」，**与实测不符**。实际 63 处 `get_node`、35 处 `@onready`。以此处为准。

**原因**：UI 由代码创建，节点在运行期才存在，无法在编辑器里指定。

**影响**：
1. 路径是字符串字面量，节点改名 → 运行期 `get_node` 返回 null → 空指针
2. 无法在编辑器里拖拽指定引用，节点结构变化对脚本不可见
3. `get_node` 在 `_process` 里调用会有每帧字符串查找开销（**需逐个确认调用位置**，本次未验证是否有此情况）

**建议**：配合 N-1 拆屏后改用导出引用：

```gdscript
@export var hand_container: NodePath
@onready var _hand: Control = get_node(hand_container)
```

---

### N-6｜非战斗只有 1 个 `changed(Dictionary)` 信号

**位置**：`scripts/noncombat_domain.gd:67`

```gdscript
signal changed(event: Dictionary)
```

配套 `_on_opening_changed` 里 8 个 `if event.get("type") == "..."` 分支。

**原因**：刻意选择「单一信号 + 全量重绘」，保证 UI 不与 domain 状态漂移。**这个模式本身不坏**，是可靠的架构选择。

**影响**：
1. `type` 是字符串，拼错即**静默失效**——没有崩溃、没有日志，只是某个功能偶尔不生效
2. 8 个分支集中在一处，新增事件类型要改这个函数
3. 全量重绘的成本压在 2,562 行的 `_render()` 上

**建议**：只解决类型约束力，不动全量重绘模式。

```gdscript
signal card_started(card_id: String)
signal choice_committed(next_card_id: String, decision_index: int)
signal battle_requested(encounter_id: String)
signal battle_settled(outcome: String)
signal state_restored(slot_id: String)
```

---

### N-7｜无 Autoload，Registry/Repository 各 UI 各 new

**位置**：`project.godot`（无 `[autoload]` 段）；`noncombat_opening_ui.gd:131` 的 `registry = Registry.new()`

**原因**：迁移时刻意避免全局状态，全部显式注入（便于测试）。**这个初衷是对的。**

**影响**：
1. `content/data` 77 个模块、9.1MB JSON 被重复解析
2. `_texture_aliases` 每个实例各加载一次
3. 无法做应用级共享状态（音量、阅读偏好靠存档文件传）

**建议**：加 3 个**纯服务** Autoload，不放玩法逻辑：

```gdscript
# autoload/data_service.gd
extends Node
## 单一 Registry/Repository 实例。生命周期：启动→退出。
## 禁止在此放状态机或玩法规则。
var registry: RuntimeDataRegistry
var repository: NoncombatContentRepository
```

```
[autoload]
DataService="*res://autoload/data_service.gd"
AudioBus="*res://autoload/audio_bus.gd"
GameSettings="*res://autoload/game_settings.gd"
```

**边界**：`noncombat_domain` 必须保持可实例化，不能因为加了 Autoload 就变成单例——否则测试无法隔离。

---

### N-8｜无 Theme，14 处 `StyleBoxFlat.new()` 运行时重建

**位置（实测）**：`game_ui_skin.gd`（4）、`card_hand_ui.gd`（4）、`noncombat_opening_ui.gd`（3）、`main.gd`（3）

**影响**：
1. 每次 `_render()` 都新建 `StyleBoxFlat` 对象
2. 编辑器无样式预览
3. 换肤要改代码，不能换资源
4. 四个文件各自定义一套样式，容易出现「同一个按钮在战斗和非战斗里长得不一样」

**建议**：把 `game_ui_skin.gd` 的样式组合一次性烘成 `theme/main.tres`，代码只保留语义色常量引用。项目设置 `[gui] theme` 指向它。

**注意**：`Theme` 里的颜色应引用单一来源的 token。Web 侧曾出现 `--combat-cinnabar` 双定义（`#9e3f32` vs `#a65345`），Godot 侧新建 token 时不要再犯。

---

### N-9｜23 个 `duel_stage_*` 脚本重复 4,299 行

**位置**：`scripts/duel_stage_*_2d.gd` 等，合计 23 个脚本 / 4,299 行

**现象（实测）**：

| 脚本 | 行数 |
|---|---|
| `duel_stage_hd2d.gd` | 1,471 |
| `duel_stage_source_2d.gd` | 476 |
| `duel_stage_25d.gd` | 465 |
| `duel_stage_real_3d.gd` | 436 |
| `duel_stage_qingyun_pixel.gd` | 420 |
| 其余 18 个 | 14~326 |

**原因**：每个遭遇一个 stage，各自继承/复制演出逻辑。

**影响**：同一个演出修复（如接触帧时序）要在多个文件重复改；新增遭遇成本高。

**建议**：**场景骨架 + 数据驱动**——固定节点（战场层 / 玩家槽 / 敌人槽 / HUD / FX 层）写进 `.tscn`，帧序列与配色由 `visual_worlds.json` 注入，收敛为 **1 个 `DuelStage` + 30 份数据**。

**前置条件**：`visual_worlds.json` 里 163 条资产的 `finalArtApproved` 全为 `false`。**先过评审再数据化**，否则会把未验收资产固化进运行时。

---

### N-10｜162 处 `.connect` 但仅 1 处 `_exit_tree`、0 处 `disconnect`

**位置**：全局（实测 `_exit_tree` 1 处、`disconnect(` 0 处、`CONNECT_ONE_SHOT` 1 处、`.bind(` 48 处）

**准确表述**：Godot 4 在对象释放时会自动清理连接，**所以这不是内存泄漏风险**。真正的问题是**语义风险**——节点被 `remove_child()` 移出树但仍存活时，信号仍会送达，可能触发不该执行的逻辑。

**影响**：低。当前 `remove_child` 的使用很少（`real_3d_fighter.gd:53` 一处，且随后立即 `free()`，处理是正确的）。

**建议**：不必批量补 `_exit_tree`。只在「节点会被移出树但保留」的场景补显式断开。优先级低。

---

### N-11｜15 个 `_process(delta)` 回调

**位置**：分散在 15 个文件（`noncombat_ambient_particles`、`hd2d_sprite_fighter`、`pixel_dungeon_*`、`main.gd` 等），每个文件 1 个。

**判断**：**多数合理**。粒子、特效、逐帧演出本来就需要每帧更新。

**需要甄别的一处**：`noncombat_run_session.gd` 曾被认为「若是存档节流应改 `Timer`」。实际核查发现该文件里没有 `func _process(delta)`，匹配到的是 `_process_confirmed_gone()`（一个用 `tasklist` 查进程是否存活的函数），**属于误报**。

**建议**：本轮不需处理。若后续 Profiler 显示粒子层占用过高，再用 `GPUParticles2D` 替代 CPU 逐帧计算。

---

## 五、优先级汇总

| 顺序 | 事项 | 对应问题 | 理由 |
|---|---|---|---|
| 1 | 补卡面/立绘资源（同步脚本改全量发现） | 支柱 1、3 | 玩家第一分钟可见；多数是漏拷不是没画 |
| 2 | 立绘区换 `AnimatedSprite2D` + `SpriteFrames` | N-1、支柱 3 | **必须先于**大规模补立绘，否则二次返工 |
| 3 | 加 3 个 Autoload + 6 个 `class_name` | N-7、C | 机械改动，收益立竿见影 |
| 4 | 抽 5 个静态屏为 `.tscn` + `@export NodePath` | N-1、N-2、N-5 | 解锁 F6 与美术独立改界面 |
| 5 | 非战斗信号强类型化 | N-6 | 消除静默失效 |
| 6 | `Theme` 资源化 | N-8 | 换肤不改代码 |
| 7 | `noncombat_domain` 拆 5 个 Director | N-3 | 长期成本源头，但风险最高，需排期 |
| 8 | `main.gd` 场景按需加载 | N-4 | 需 Profiler 先确认实际开销 |
| 9 | 战斗 stage 数据驱动 | N-9 | 前置：VFX 评审 |

---

**文档版本**：v1.0  
**审计日期**：2026-11-05  
**基线版本**：`c268384` / `baseline-2026-11-05-pre-noncombat-remedy`  
**需要修正的旧结论**：审计报告中「`get_node` 0 处」不成立（实测 63 处）；「`noncombat_run_session._process` 应改 Timer」属误报（无 `_process(delta)`）。
