# 《一念仙途》Godot 版 · 游戏设计文档 GDD v1.0

| 项 | 内容 |
|---|---|
| 文档版本 | v1.0（首版统一稿） |
| 制定日期 | 2026-11-05 |
| 工程根 | `E:/4e/游1/2026-06-27-05-40-58/xiuxian-card-game/godot` |
| 基线提交 | `5522063` / 分支 `remedy/noncombat-p0-2026-11-05` |
| 引擎 | Godot 4.7.2 Stable / Forward+ / 1280×800 / Windows 桌面 |
| 平台范围 | **仅 Windows 桌面 + 桌面浏览器 Web**；不含手机端、触摸适配 |

---

## 第 0 章　文档定位

### 0.1 这份文档解决什么问题

项目已有 **69 份 GDD**（`docs/gdd/`），但存在两个结构性问题：

| 问题 | 表现 |
|---|---|
| **技术状态过期** | `docs/gdd/GDD.md` 第 3.2 节写「战斗系统不存在，需从零设计」，而实际已有 23 个 `duel_stage` 脚本 / 4,299 行；写「卡池 37/200+」，实际 588 张卡已入库 |
| **无 Godot 架构归属** | 69 份文档全是浏览器版设计，**没有一份说明「这个系统在 Godot 里落在哪个脚本、哪个场景、哪个信号」** |

本文档不是第 70 份设计稿，而是**收敛层**：

```
docs/gdd/*.md（69 份，玩法细节与历史决策）
        ↓ 提取不变的设计意图
本文档（玩法支柱 + 系统全景 + Godot 架构归属 + 实测状态）
        ↓ 指导
godot/ 实际代码
```

### 0.2 标注约定

| 标记 | 含义 |
|---|---|
| **【实测】** | 本次扫描或运行直接得出，可复算 |
| **【设计】** | 来自存量 GDD 的设计意图，未必已实现 |
| **【推断】** | 基于代码语义判断，需实机验证 |

**本 GDD 的一条纪律**：凡涉及「完成度」「数量」「状态」的判断，一律标【实测】并给复算口径。**不允许出现没有来源的完成度数字**——存量 GDD 里那些「✅ 100%」正是失去可信度的原因。

### 0.3 与存量文档的关系

| 存量文档 | 处理方式 |
|---|---|
| `docs/gdd/GDD.md` 第 1-2 章（设计支柱、核心循环） | **继承，原文不动** |
| `docs/gdd/GDD.md` 第 3 章（系统架构） | **被本文档第 4-5 章替代**（旧版是浏览器 EventBus 架构） |
| `docs/gdd/GDD.md` 第 3.2 节（实现状态表） | **被本文档第 7 章替代**（旧版数据过期） |
| `GDD_SYSTEM_ALIGNMENT.md`（8 模块 UI 对齐） | **保留**，作为 UI 细化参考 |
| `GDD_COMBAT_V2/V3`、`GDD_ADDICTION_LAYER`、`GDD_TREASURE_DEATH_BALANCE` | **保留**，作为系统细则 |
| 其余 60 余份（切片记录、评审报告、prompt 清单） | **归档**，不再作为设计依据 |

---

## 第 1 章　设计支柱

> 以下四条继承自 `docs/gdd/GDD.md` 第 1 章，**原文不动**。任何设计决策必须对照检验。

### 支柱 1：每一次滑动都是一次抉择

> 玩家不是在"选最优解"——而是在两个都有代价的选项中，选择自己愿意承受的后果。

- 没有纯正面卡。每张卡的两个选项都包含**风险/收益不对称**。
- 拒绝"左边加修为、右边加灵石"的无脑选择。
- 每一张卡应迫使玩家考虑：*我在乎什么？我愿意失去什么？*

**Godot 落地约束**：卡牌选项数据必须携带 `effects` 与 `costs` 双向字段，禁止只写收益。校验在内容仓库层（`unlisted = 0` 门禁之外新增「单向卡」检测）。

### 支柱 2：因果不虚，报应不爽

> 你在炼气期做的一件小事，会在金丹期结出果子——好人未必好报，恶人也未必遭殃，但一切都有迹可循。

- 因果系统是叙事脊梁，不是数值系统。
- 因果种子延迟 5-20 轮发芽，制造"忘了但突然回来"的冲击。
- 因果闭环必须有叙事逻辑，不是随机。

**Godot 落地约束**：因果种子必须随存档持久化，且时钟推进可严格回放（`noncombat_causal_fact_clock.gd` 已实现）。**因果种子属于不可逆数据，验收标准为 bit-exact**。

### 支柱 3：修仙的本质是选择"成为谁"

> 剑修、法修、体修、丹修——不只是数值差异，而是四种不同的修仙哲学和世界观。

- 不同功法走不同剧情线、遇见不同人、面临不同困境。
- NPC 态度因功法而异。
- 同一事件在不同功法视角下可能有完全不同的解读。

**Godot 落地约束**：`path`（修路）必须作为决策的一等公民贯穿数据层。当前 `data/config/paths.json` 已有 paths 定义，战斗舞台按 path 分流（`spell` / `body` / `pill` / `sword` 四套 stage）。

### 支柱 4：死亡不是结束，是另一种推进

> 每一次死亡都应该让玩家获得新的知识或解锁——转世是 meta-progression 的载体，不是惩罚。

- 至少 6 种死亡方式，各有独特 flavor text 与解锁。
- 转世保留部分进度，但解锁新选项。
- 飞升是最难结局，但玩家可选择不飞升。

**Godot 落地约束**：死亡 → 转世跨世数据必须完整持久化（`REBIRTH_PATH_REQUIRED` / `REBIRTH_PATH_SELECTED` 事件已存在），且跨世存档兼容是 L3 边界门禁的必检项。

---

## 第 2 章　核心体验与循环

### 2.1 三层循环（继承）

| 层 | 时长 | 内容 | 玩家心理 |
|---|---|---|---|
| **时刻** | 10-30 秒 | 抽卡 → 阅读 → 抉择 → 结算 → 下一张 | "左边风险大但收益高，右边稳妥但有隐藏代价" |
| **会话** | 5-20 分钟 | 开局（0-5 轮）→ 攀升（5-30）→ 危机（30-50）→ 终局（50-80） | "这一世我能走多远" |
| **长期** | 多局 | 死亡 → 转世 → 解锁 → 追求飞升 → 全结局 | "上一世的那件事，这一世回来找我了" |

### 2.2 Godot 侧的循环实现映射【实测】

| 循环层 | Godot 实现 | 文件 |
|---|---|---|
| 时刻 | `NoncombatDomain.choose()` → 结算 → `_emit_event` → `_render()` | `noncombat_domain.gd` 6,476 行 |
| 会话 | 决策时钟 `runClock.decisionIndex` 推进；境界门禁在固定决策点触发 | `noncombat_realm_gate_flow.gd` |
| 长期 | 存档槽 + 转世数据；跨世由 `life` 字段区分 | `noncombat_save_slots.gd`、`noncombat_rebirth_flow.gd` |

**关键设计约束**：时刻循环必须**单帧内完成**结算，不允许异步等待。原因：游戏是纯决策游戏，卡顿会破坏"抉择重量"。当前实现是同步的，符合要求。

---

## 第 3 章　玩法系统全景

### 3.1 系统清单（12 个一级系统）

| # | 系统 | 设计意图【设计】 | 数据模块 | 当前状态【实测】 |
|---|---|---|---|---|
| S1 | **卡牌引擎** | 9 级优先级抽卡，保证叙事节奏 | `data/cards/*` | 588 卡入库，`unlisted=0` |
| S2 | **修路系统** | 四路（剑/法/体/丹）不同剧情与战斗 | `data/config/paths.json` | 4 路齐备，各有专属 stage |
| S3 | **境界系统** | 炼气→筑基→金丹→元婴→化神→渡劫→飞升 | `data/cards/chapter_milestones.json` | 6 关隘 flow 全部实现 |
| S4 | **因果系统** | 种子延迟发芽，叙事脊梁 | `data/echoes/*`、`data/threads/*` | karma/ripple/destiny 三 flow 齐备 |
| S5 | **同伴系统** | 道侣/师徒/同门三条关系线 | `data/companions/*` | 20 事件 + 立绘阶段选图 |
| S6 | **NPC 世界** | 三层灵魂：记忆/好感/秘密 | `data/npcs/core_npcs.json` | **16 个 NPC**，手动交互全实现 |
| S7 | **势力暗流** | 四大势力 + 暗流事件 | `data/world/*` | faction_events + 势力战斗 |
| S8 | **坊市经济** | 四类摊位（公开/鬼市/正规/末课） | `data/shops/*`、`data/markets/*` | 四类 vendor flow 齐备 |
| S9 | **秘境探险** | 节点式地宫，逐层深入 | `data/locations/*` | 5 类 dungeon flow |
| S10 | **死亡转世** | 6 种死法 + 转世解锁 | `data/progression/*` | death/rebirth/lineage 齐备 |
| S11 | **战斗系统** | 卡牌战斗，权威结算 | `data/combat/*` | **本阶段刻意延后**（23 stage 脚本已建，未验收） |
| S12 | **图鉴与日志** | 万物志/因果簿/线程簿/人物志 | `data/**` 汇总 | 4 个 UI 齐备 |

### 3.2 六钩上瘾引擎

| 钩子 | 机制 | Godot 实现【实测】 | 状态 |
|---|---|---|---|
| 命盘轮转 | 延迟触发的命运卡，翻牌揭示 | `noncombat_destiny_wheel.gd` | ✅ 探针观测到 `DESTINY_WHEEL_FLIPPED` |
| 心魔反噬 | 道心归零触发心魔事件 | `noncombat_*` 内嵌 | ✅ |
| 传承残卷 | Boss 战后残卷奖励 | `noncombat_legacy_fragment_flow.gd`（**扇入 33，全项目最高**） | ✅ |
| 突破倒计时 | 境界门禁前的预警卡 | `noncombat_realm_gate_flow.gd` | ✅ |
| 因果涟漪 | 因果种子的连锁反应 | `noncombat_ripple_flow.gd` | ✅ |
| 天机一闪 | 稀有提示卡 | `noncombat_heavens_hint_flow.gd` | ✅ |

**六钩共同的设计约束**：每个钩子都必须**延迟满足**（不是立即反馈），且延迟时长可被玩家感知但不精确预知。这要求决策时钟严格可回放——当前由 `noncombat_causal_fact_clock.gd` 承担。

### 3.3 系统的依赖关系【实测】

扇入 Top（被多少文件 preload）：

| 文件 | 扇入 | 含义 |
|---|---|---|
| `noncombat_legacy_fragment_flow.gd` | **33** | 传承残卷被最多系统引用 |
| `noncombat_content_repository.gd` | 28 | 数据访问层 |
| `noncombat_milestone_flow.gd` | 27 | 里程碑判定 |
| `noncombat_path_skill_flow.gd` | 18 | 修路技能 |
| `noncombat_treasure_acquisition.gd` | 17 | 法宝获取 |

**架构含义**：`legacy_fragment_flow` 的 33 扇入是**设计耦合**（每个 Boss 战、每个境界突破都可能触发残卷），不是错误。但它意味着这个文件的接口变更影响面最广，**改动需最高谨慎**。

---

## 第 4 章　Godot 架构规划

> 本章是本文档与 69 份存量 GDD 的根本区别：存量文档描述「玩法是什么」，本章描述「玩法在 Godot 里落在哪、怎么连、谁不能碰谁」。

### 4.1 五层模型与层间纪律

```
┌─ L5 表现层 ────────────────────────────────────────┐
│  职责：把状态画出来，把输入转成意图                  │
│  只读领域层，禁止持有游戏规则                        │
│  典型：NoncombatOpeningUI、DuelStage*、*_UI          │
└─────────────────────────────────────────────────────┘
                        ↓ 只能调用
┌─ L4 接口层 ────────────────────────────────────────┐
│  职责：跨子系统的契约边界（非战斗↔战斗）              │
│  典型：BattleGateway、BattleReturnFlow、BattleStub   │
└─────────────────────────────────────────────────────┘
                        ↓
┌─ L3 领域层 ────────────────────────────────────────┐
│  职责：权威状态机、结算、决策推进                     │
│  唯一真相：NoncombatDomain / CombatDomain            │
│  禁止依赖任何 Control / Node                          │
└─────────────────────────────────────────────────────┘
                        ↓
┌─ L2 流程层 ────────────────────────────────────────┐
│  职责：单一机制的算法（约 60 个 *_flow）              │
│  无状态或仅局部状态，可独立构造与测试                 │
└─────────────────────────────────────────────────────┘
                        ↓
┌─ L1 数据层 ────────────────────────────────────────┐
│  职责：JSON 读取、索引、SHA 校验、资源解析            │
│  典型：ContentRepository、RuntimeDataRegistry        │
└─────────────────────────────────────────────────────┘
```

**四条硬纪律**：

| # | 纪律 | 违反后果 |
|---|---|---|
| 1 | **L1/L2/L3 禁止 preload 任何 `.tscn`** | 数据层被场景依赖污染，无法在 headless 测试中独立运行 |
| 2 | **L3 禁止 `extends Node`** | Domain 若变成节点，测试必须构造场景树，隔离性丧失 |
| 3 | **L5 禁止直接调用 L2** | 绕过 Domain 会导致状态与 UI 漂移（当前已基本遵守：UI 只持有 Domain） |
| 4 | **Autoload 禁止放玩法逻辑** | 单例化后无法实例化，所有测试必须共享全局状态 |

**当前违反情况【实测】**：
- 纪律 1：`noncombat_opening_ui.gd`（L5）preload 了 `main.tscn` 等场景 → 属 L5 行为，**合规**
- 纪律 2：`noncombat_domain.gd` extends RefCounted → **合规**
- 纪律 3：约 15 处 UI 直接 preload Flow（如 `LegacyFragmentFlow`）→ **部分违反**，但多为只读查询，风险可控
- 纪律 4：本轮新增的 `DataService` 只有 registry，**合规**

---

### 4.2 Autoload 规划

| 名称 | 职责 | 生命周期 | 现状 |
|---|---|---|---|
| `DataService` | 共享 `RuntimeDataRegistry` | 启动 → 退出 | ✅ 已实现（P3） |
| `AudioBus` | BGM/SFX/Voice/UI 四总线 + 音量 | 启动 → 退出 | ❌ 未实现（当前无 bus layout） |
| `GameSettings` | 阅读偏好、特效档位、稳定背景 | 启动 → 退出 | ⚠️ 部分（存在 `noncombat_experience_settings.gd`，但是实例而非单例） |

**实现要求**：
- 每个 Autoload 必须有 `##` 注释说明「放什么 / 不放什么」
- 必须提供「未加载时可用」的获取方式（`registry_or_new()` 模式），保证 `--script` 测试可跑
- **禁止**把 `NoncombatDomain` 做成 Autoload

---

### 4.3 场景树规划

#### 4.3.1 当前状态【实测】

| 指标 | 数值 |
|---|---|
| 场景总数 | 47 |
| 单节点场景（1 个根 + 挂脚本） | **32（68%）** |
| 全项目 `Control` 节点数 | **29** |
| `add_child()` 调用 | 448 |
| `noncombat_opening_ui.gd` 的 `.new()` | **132** |

**结论**：UI 层几乎不使用节点树，全部由代码 `add_child` 现场拼装。3D 侧相反（`cangmang_real_3d_world.tscn` 689 节点）。

#### 4.3.2 目标结构

```
scenes/
├─ noncombat/
│  ├─ opening_root.tscn          ← 根：1 Control + 屏幕容器 + 音频挂点
│  ├─ screens/
│  │  ├─ slot_screen.tscn        ← 存档槽（3 槽位展示 + 新建/读取/删除）
│  │  ├─ name_screen.tscn        ← 取名（输入 + 校验）
│  │  ├─ path_screen.tscn        ← 选路（4 路卡片）
│  │  ├─ story_screen.tscn       ← 剧情主屏（立绘区 + 卡面 + 选项行 + HUD）
│  │  └─ ending_screen.tscn      ← 结局（飞升/死亡/转世）
│  └─ shared/
│     ├─ choice_row.tscn         ← 选项行（被 6 处复用）
│     ├─ portrait_panel.tscn     ← 立绘面板（Container + Sprite 双模式）
│     ├─ hud_bar.tscn            ← 顶部状态条（修为/灵石/道心/境界）
│     └─ dialog_frame.tscn       ← 弹窗框（图鉴/日志/设置共用）
├─ combat/
│  ├─ duel_stage.tscn            ← 1 个舞台骨架（替代 23 个 *_2d.tscn）
│  └─ duel_hud.tscn              ← 手牌 + 意图 + 血条
└─ demo/                         ← 演示场景隔离，不参与发布
   ├─ actor_motion_lab.tscn
   ├─ equipment_demo.tscn
   └─ pixel_dungeon_demo.tscn
```

**拆分的三个纪律**：

1. **一个 `.tscn` 必须能 F6 独立运行**，不依赖父场景或 `user://` 存档
2. **布局属性必须在 `.tscn` 里**（锚点、间距、尺寸），脚本只负责 `bind(state)`
3. **节点引用用 `@export var x: NodePath`**（当前 0 处，目标：所有跨节点引用）

#### 4.3.3 立绘区的正确结构（修正旧建议）

**旧建议「立绘改 `AnimatedSprite2D`」不成立**：`art_rect` 是 `TextureRect`，用法含 `custom_minimum_size` / `size_flags_*`，属 Control 布局体系；`AnimatedSprite2D` 是 `Node2D`，无这些属性。

**正确结构**：

```
portrait_panel.tscn (Control)
├─ Frame (PanelContainer)          ← 边框与遮罩，Control 布局
├─ Still (TextureRect)             ← 静态立绘，单图卡用这个
└─ Frames (AnimatedSprite2D)       ← 帧序列（待机呼吸/受击），
                                     通过 anchors + scale 适配 Control 区域
```

**切换规则**：
- `sprite_frames_for(path) != null` → 显示 `Frames`，隐藏 `Still`
- 否则 → 显示 `Still`（走 `texture_for` 或占位）

这样既保留布局能力，又为将来的呼吸帧留好位置。**这必须在大规模补立绘资源之前完成**，否则补完还要再改一次结构。

---

### 4.4 信号契约

#### 4.4.1 当前状态【实测】

| 区域 | signal 数 | 形态 |
|---|---|---|
| 非战斗 | **3** | `changed(Dictionary)` / `voice_subtitle_changed` / `closed` |
| 战斗 stage | 各 4 | `battle_finished` / `presentation_finished` / `presentation_missing` / `contact_frame` |
| 全项目 | 42 | — |

非战斗的 `changed(event: Dictionary)` + `if event.get("type") == "..."` 是**刻意的全量重绘模式**，保证 UI 不与状态漂移，**保留**。

#### 4.4.2 事件清单（探针实测）

一条剑修真实路线触发的 16 种事件：

```
STARTED ×1              CHOICE_COMMITTED ×3
FLOW_CARD_READY ×14     ENCOUNTER_WARNING ×2
BATTLE_REQUEST_READY ×2 BATTLE_RESULT_COMMITTED ×2
BATTLE_RESULT_ACKNOWLEDGED ×2  RESULT_ACKNOWLEDGED ×3
MILESTONE_CHOSEN ×4     MENTOR_CHOSEN ×2
DESTINY_WHEEL_FLIPPED ×1 ENCOUNTER_AVOIDED ×2
MARKET_SKIPPED ×2       HINT_CHOSEN ×1
KARMA_CHOSEN ×4         QUEST_CHOSEN ×3
```

**已知缺口**：`KARMA_CHOSEN`（×4）与 `QUEST_CHOSEN`（×3）**不在 UI 的 19 个处理分支内**，被静默忽略。是否设计如此待确认。

#### 4.4.3 信号化目标（分两步，不可跳）

**第一步（已完成）**：13 处 `changed.emit` 统一走 `_emit_event()`，出口记录类型与次数，提供 `event_type_report()`。

**第二步（待做，有前置）**：拆成强类型信号。

```gdscript
# 拆分前提：先用探针跑 3~5 条不同路线（剑修/体修/丹修/法修/转世），
# 合并 event_type_report() 得到全量清单。没有清单就拆信号 = 凭猜测定 API。
signal card_started(card_id: String)
signal choice_committed(next_card_id: String, decision_index: int)
signal battle_requested(encounter_id: String)
signal battle_settled(outcome: String)
signal state_restored(slot_id: String)
```

**为什么不能直接拆**：事件类型由 **79 个** `_commit_encounter_transition(state, "EVENT_TYPE")` 调用点分散传参，domain 内 117 个大写字符串混着 `state.phase`（`NORMAL_PENDING`）、动作名（`END_TURN`）、卡 ID，无法可靠自动区分。

---

### 4.5 依赖规则

#### 4.5.1 允许的依赖方向

```
L5 表现 → L4 接口 → L3 领域 → L2 流程 → L1 数据
   ↓                                    ↑
   └────────── 只读查询可跨层 ───────────┘
```

**允许**：L5 直接读 L2 的**纯查询方法**（如 `flow.current_state()`）
**禁止**：L5 调用 L2 的**状态变更方法**（必须经 L3）

#### 4.5.2 依赖热点的特殊约定

| 文件 | 扇入 | 约定 |
|---|---|---|
| `noncombat_legacy_fragment_flow.gd` | **33** | 接口冻结，新增方法只能追加，不可改签名 |
| `noncombat_content_repository.gd` | 28 | 只读，任何写操作都是设计错误 |
| `noncombat_milestone_flow.gd` | 27 | 判定逻辑变更需同步跑全部里程碑测试 |
| `noncombat_domain.gd` | 扇出 **62** | 见 §4.6 |

#### 4.5.3 类型安全要求

| 要求 | 当前【实测】 | 目标 |
|---|---|---|
| 核心类有 `class_name` | **8** | 全部 L1~L3 类 |
| `var x: RefCounted` 占位 | 192 处 | 逐步替换为具体类型 |
| `@export NodePath` | **0** | 所有跨节点引用 |
| `get_node()` 运行期查找 | **63** | 0（改 `@onready` + 导出路径） |

**注**：`--check-only` 单文件模式**不解析全局类缓存**，加了 `class_name` 后必须跑
`godot --headless --path . --editor --quit` 重建 `.godot/global_script_class_cache.cfg`，再用 `--quit-after 3` 完整加载复验。否则会误判通过。

---

### 4.6 `noncombat_domain.gd` 的拆分规划

**当前**：6,476 行 / 62 扇出 / 承担全部非战斗流程编排。

**目标**：域类只保留状态机与调度，按 Flow 边界聚 5 个协作类。

| 新类 | 承接 | 目标行数 | 目标扇出 |
|---|---|---|---|
| `EncounterDirector` | 遭遇与战斗交接（已有雏形） | ≤ 1,500 | ≤ 15 |
| `VendorDirector` | 坊市 / 鬼市 / 正规坊 / 末课 | ≤ 900 | ≤ 15 |
| `DungeonDirector` | 洞府 / 遗迹 / 地宫 / 高阶线性 | ≤ 800 | ≤ 15 |
| `NarrativeDirector` | 剧情线 / 线程 / 因果展示 / 涟漪 | ≤ 1,200 | ≤ 15 |
| `ProgressionDirector` | 境界 / 里程碑 / 转世 / 血脉 | ≤ 1,000 | ≤ 15 |

**执行纪律**：
1. 一次只拆一个 Director
2. 拆完即跑全量非战斗测试，断言数不得减少
3. 独立提交，可单独回退
4. **拆分期间禁止其他并行改动**

**为什么现在不拆**：6,476 行是当前唯一的高风险改动点，需要完整的测试覆盖作为安全网。当前 326 个非战斗测试是够的，但一旦拆分期间引入其他改动（如信号改造），失败原因将无法定位。

---

## 第 5 章　模块分布矩阵

> 每个系统必须能回答：**落在哪个脚本、哪个场景、哪份数据、哪条测试**。答不出的系统即为「无归属代码」。

### 5.1 一级系统分布表

| 系统 | 领域入口 | 主要流程脚本 | 场景 | 数据模块 | 测试 |
|---|---|---|---|---|---|
| **S1 卡牌引擎** | `NoncombatDomain` | `noncombat_normal_draw_policy`<br>`noncombat_normal_choice_policy` | `story_screen.tscn`（待拆） | `data/cards/*` | `noncombat_cadence_*` |
| **S2 修路** | `NoncombatDomain` | `noncombat_path_skill_flow`<br>`noncombat_first_session_route` | `path_screen.tscn`（待拆） | `data/config/paths.json` | `noncombat_path_*` |
| **S3 境界** | `NoncombatDomain` | `noncombat_realm_gate_flow`（1,305 行）<br>`noncombat_foundation_dungeon_flow`<br>`noncombat_golden_dungeon_flow` | `duel_stage_*_gate_2d` | `data/cards/chapter_milestones.json` | `noncombat_qi_gate_*`<br>`noncombat_foundation_*` |
| **S4 因果** | `NoncombatDomain` | `noncombat_karma_flow`<br>`noncombat_ripple_flow`<br>`noncombat_destiny_wheel`<br>`noncombat_causal_fact_clock` | `karma_journal_ui` | `data/echoes/*`<br>`data/threads/*` | `noncombat_karma_*`<br>`noncombat_ripple_*` |
| **S5 同伴** | `NoncombatDomain` | `noncombat_companion_events`<br>`noncombat_companion_arc_flow`<br>`noncombat_companion_whisper` | `story_screen` 立绘区 | `data/companions/*` | `noncombat_companion_*` |
| **S6 NPC** | `NoncombatDomain` | `noncombat_npc_encounter_flow`<br>`noncombat_npc_interaction_flow`<br>`noncombat_npc_cross_flow` | `npc_interaction_ui` | `data/npcs/core_npcs.json`（16 人） | `noncombat_npc_*` |
| **S7 势力** | `NoncombatDomain` | `noncombat_faction_events`<br>`noncombat_story_thread_flow` | `duel_stage_faction_wumeng_2d` | `data/world/*` | `noncombat_faction_*` |
| **S8 坊市** | `NoncombatDomain` | `noncombat_vendor_flow`<br>`noncombat_ghost_vendor_flow`<br>`noncombat_regulated_vendor_flow`<br>`noncombat_market_flow` | `story_screen` 选项行 | `data/shops/*`<br>`data/markets/*` | `noncombat_bazaar_*`<br>`noncombat_ghost_*` |
| **S9 秘境** | `NoncombatDomain` | `noncombat_cave_flow`<br>`noncombat_nascent_ruins_flow`<br>`noncombat_higher_linear_dungeon_flow` | `duel_stage_pixel_dungeon` | `data/locations/*` | `noncombat_dungeon_*` |
| **S10 死亡转世** | `NoncombatDomain` | `noncombat_death_flow`<br>`noncombat_rebirth_flow`<br>`noncombat_lineage_flow` | `ending_screen.tscn`（待拆） | `data/progression/*` | `noncombat_death_*`<br>`noncombat_rebirth_*` |
| **S11 战斗**（延后） | `CombatDomain` | `duel_stage_*`（23 个） | `duel_stage.tscn`（目标） | `data/combat/*` | `battle_*`（约 20） |
| **S12 图鉴** | — | `noncombat_evidence_atlas`<br>`noncombat_karma_journal`<br>`noncombat_thread_journal`<br>`noncombat_bestiary_ui` | 4 个 `*_ui` | 汇总 | 分散 |

### 5.2 存档与设置（横切）

| 能力 | 脚本 | 存档位置 | 验收要点 |
|---|---|---|---|
| 三槽位 | `noncombat_save_slots.gd` | `user://saves/slot_{1,2,3}.json` | 并发锁、孤锁恢复 |
| 会话写入 | `noncombat_run_session.gd` | 同上 | 原子提交、失败回滚 |
| 浏览器旧档导入 | `noncombat_browser_save_import`<br>`_staging` / `_inspector` | 同上 | 坏字段受控拒绝（`UNSUPPORTED_IMPORT_RESULT_STATE`） |
| 体验设置 | `noncombat_experience_settings.gd` | `user://experience_settings.json` | 重启保持、非法值回退 |
| 音频 | `noncombat_opening_audio.gd`<br>`noncombat_market_audio.gd` | 无 | **bus 语义当前悬空**（无 bus layout） |

### 5.3 无归属与待归属清单【实测】

| 项 | 现状 | 处理 |
|---|---|---|
| `actor_*` 系列（8 个脚本） | 换装/骨骼 Demo，无系统归属 | 归入 `demo/`，不参与发布 |
| `paperdoll_actor_study.gd` | 研究性代码 | 同上 |
| `modular_actor_hd2d` / `modular_pixel_actor` | 角色模块化 Demo | 同上 |
| `equipment_demo*`（3 个） | 换装演示 | 同上 |
| `undercurrent_hit_fx` / `pixel_dungeon_hit_fx` | 打击特效 | 归 S11 战斗 |
| `reference_battle_hud` | 战斗 HUD 参考实现 | 归 S11 |

---

## 第 6 章　数据模型

### 6.1 数据分层

```
content/data/            运行时唯一权威（77 个 JSON，9.1MB）【实测】
├─ cards/                卡牌与章节里程碑
├─ config/               路径、境界、常量
├─ combat/               遭遇、演出、视觉世界、动作帧
├─ companions/           同伴定义、事件、立绘阶段
├─ echoes/               因果回响
├─ items/                法宝、消耗品
├─ locations/            地点与秘境
├─ markets/ shops/       坊市与商店
├─ narrative/            叙事模块
├─ npcs/                 NPC 定义（16 人）
├─ progression/          转世与血脉
├─ quests/ threads/      任务与线程
└─ world/                势力、真相图鉴
```

**纪律**：`content/data` 是唯一权威。**禁止在脚本里硬编码卡牌数值**。所有数值必须来自 JSON，脚本只做规则运算。

### 6.2 ID 规范

| 类型 | 前缀 | 示例 | 约束 |
|---|---|---|---|
| 卡牌 | `ch_` / `q_` / `k_` / `n_` | `ch_qi_100` | 全局唯一，不可改名（存档引用） |
| 遭遇 | `enc_` | `enc_trial_sword_swift` | 同上 |
| 遭遇实例 | `enc:` | `enc:slot_2:life:0:30:ch_qi_100:1` | 运行期生成，含槽位/世次/决策序号 |
| 卡牌来源 | 与卡 ID 同 | `sourceCardId` | 用于战果归属校验 |
| 同伴 | `comp_` | `comp_mortal_qi_karma_crisis_good` | — |
| NPC | 小写名 | `mortal`、`bai_ren` | — |
| 线程 | `thread_` | `thread_sword_tomb_2` | — |

**不可逆约束**：卡牌 ID 与遭遇 ID 一旦发布**永不改名**——存档、因果种子、事件回执全部引用它们。

### 6.3 存档格式

| 项 | 规格 |
|---|---|
| 位置 | `user://saves/slot_{1,2,3}.json` |
| 权威字段 | 版本、活动槽位、解锁、转世档案、任务/因果 sidecar、当前决策、战斗快照 |
| 战斗快照 | `contractVersion = 2`，含权威校验字段 |
| 并发 | 同槽目录锁；孤锁按 PID 存活判断后才回收 |
| 旧档兼容 | `normalFlow.choiceRuleSha` 为历史值时按旧规则回放，首次新决定写入激活点 |

**验收等级：bit-exact（E1）**。存档属于不可逆数据，任何字段差异都算失败。

---

## 第 7 章　实现现状

### 7.1 总体【实测】

| 维度 | 数值 | 口径 |
|---|---|---|
| 脚本 | 135 个 / 54,360 行 | `scripts/**/*.gd` |
| 场景 | 47 个（32 个单节点） | `scenes/*.tscn` |
| 测试 | 401 个 `.gd` | `tests/*.gd` |
| 数据模块 | 75 个 / 588 卡 / 553 场景引用 | `noncombat_content_repository` 输出 |
| 资产覆盖 | 卡面 24% / 立绘 14% / VFX 帧 9% | 见验收报告 |
| 导出包 | 2.4GB PCK（2026-10-30 构建） | `dist/windows/` |

### 7.2 系统完成度矩阵

**判定标准**：
- `功能性通过` = L0 可加载 + L1 冒烟 + L2(Tier A) 全过
- `完全签收` = 上述 + L3 边界 + L4 视觉 + Tier B/C 达标

| 系统 | 逻辑 | 表现 | 数据 | 状态 |
|---|---|---|---|---|
| S1 卡牌引擎 | ✅ | ⚠️ 卡面 24% | ✅ 588 卡 | **功能性通过** |
| S2 修路 | ✅ | ✅ 4 路 stage 齐 | ✅ | **功能性通过** |
| S3 境界 | ✅ | ⚠️ | ✅ | **功能性通过** |
| S4 因果 | ✅ | ⚠️ 无专门演出 | ✅ | **功能性通过** |
| S5 同伴 | ✅ | ⚠️ 立绘 14% | ✅ | **功能性通过** |
| S6 NPC | ✅ | ⚠️ | ✅ 16 人 | **功能性通过** |
| S7 势力 | ✅ | ⚠️ | ✅ | **功能性通过** |
| S8 坊市 | ✅ | ⚠️ 无 UI 音效 | ✅ | **功能性通过** |
| S9 秘境 | ✅ | ⚠️ | ✅ | **功能性通过** |
| S10 死亡转世 | ✅ | ⚠️ | ✅ | **功能性通过** |
| S11 战斗 | ✅ 规则 | ❌ 视觉 FAIL | ⚠️ 帧 9% | **刻意延后** |
| S12 图鉴 | ✅ | ⚠️ | ✅ | **功能性通过** |

**没有一项达到「完全签收」**。阻塞点全部在表现层（资产 + 视觉验收），不在逻辑层。

### 7.3 技术债清单（按优先级）

| # | 债务 | 量化 | 影响 |
|---|---|---|---|
| 1 | UI 不使用节点树 | 32/47 单节点场景，`Control` 仅 29 个 | 不能 F6、不能拖拽、diff 无意义 |
| 2 | `noncombat_domain` 上帝对象 | 6,476 行 / 62 扇出 | 每加功能都要动它 |
| 3 | 无 Theme | 14 处 `StyleBoxFlat.new()` | 换肤要改代码 |
| 4 | 无音频总线 | `bus` 字段悬空 | BGM/SFX 无法独立调节 |
| 5 | 资产缺失静默 | 已修（P0-2 已完成） | 现已可见 |
| 6 | 事件类型裸字符串 | 7 处 | 拼错静默失效 |
| 7 | `get_node` 硬编码 | 63 处 | 节点改名即崩 |
| 8 | 战斗 stage 重复 | 23 脚本 / 4,299 行 | 一处演出修复要改多份 |

---

## 第 8 章　质量门禁

### 8.1 五层门禁

| 层 | 检查 | 门槛 | 阻塞 |
|---|---|---|---|
| **L0** 可加载 | 场景 F6 无错、脚本解析通过、资源零缺失告警 | 100% | 一切 |
| **L1** 冒烟 | 进入 → 出牌/选择 → 结算 → 退出 | 100% 场景 | L2+ |
| **L2** 行为等价 | 同输入同输出（Tier A 逐卡） | Tier A 100% | 签收 |
| **L3** 边界 | 5 类存档（新/旧/坏字段/跨世/长历史）× 2 槽 | 全过 | 签收 |
| **L4** 视觉 | 截图目视清单 | 人工勾 | **不阻塞 L0–L3** |

### 8.2 当前可执行的门禁命令

```bash
cd godot
GODOT=<godot 可执行路径>

# L0-a：全局类缓存 + 完整加载（--check-only 不可替代）
"$GODOT" --headless --path . --editor --quit
"$GODOT" --headless --path . --quit-after 3    # 期望零 SCRIPT ERROR

# L0-b：内容仓库
"$GODOT" --headless --path . --script res://tests/noncombat_content_repository.gd
# 期望 NONCOMBAT_CONTENT_REPOSITORY_PASS modules=75 cards=588 ... unlisted=0

# L1：主链路
"$GODOT" --headless --path . --script res://tests/noncombat_qi_gate_entry.gd
"$GODOT" --headless --path . --script res://tests/noncombat_bazaar_vendor.gd
"$GODOT" --headless --path . --script res://tests/noncombat_whitefox_choices.gd

# 接口层
"$GODOT" --headless --path . --script res://tests/battle_stub_contract.gd
"$GODOT" --headless --path . --script res://tests/battle_stub_route.gd

# 诊断
"$GODOT" --headless --path . --script res://tests/noncombat_event_type_probe.gd
```

### 8.3 单测耗时上限

**≤ 120 秒**。超过即拆，**不许调高时限**。当前有 5~8 个测试超过（最长约 600 秒），需拆分。

---

## 第 9 章　迭代路线

### 9.1 四个批次

| 批次 | 主题 | 内容 | 前置 |
|---|---|---|---|
| **A 地基**（已完成） | 类型系统 / 场景加载 / 数据服务 / 事件出口 | `class_name`×8、`STAGE_ROUTES`、`DataService`、`_emit_event` | — |
| **B 表现层地基** | Theme / 音频总线 / 立绘结构 / 抽 5 屏 | 让美术能独立改界面 | A |
| **C 结构治理** | domain 拆 5 Director / 信号强类型 | 长期可维护 | B + 完整测试网 |
| **D 内容补全** | 卡面 / 立绘 / VFX / 战斗 stage 数据化 | 玩家可见质量 | B |

### 9.2 批次 B 的任务分解

| # | 任务 | 验收 | 风险 |
|---|---|---|---|
| B1 | `Theme/main.tres` 资源化 | 改一处语义色，全局同步变化 | 低 |
| B2 | `AudioBus` autoload + 5 总线 | BGM/SFX 可独立调节 | 中（bus 语义要接上） |
| B3 | `portrait_panel.tscn`（Still + Frames 双模式） | 有帧用帧，无帧用图 | 中 |
| B4 | 抽 `slot_screen.tscn` | F6 可单跑 | 中（视觉比对） |
| B5 | 抽 `name_screen.tscn` | F6 可单跑 | 中 |
| B6 | `@export NodePath` 替换 63 处 `get_node` | 节点改名不再崩 | 中 |

### 9.3 批次 D 的顺序（关键）

**必须 B3 完成后再批量补立绘**。否则补完 230 张立绘还要再改一次结构。

```
B3（立绘双模式结构）
    ↓
补立绘 230 张 → 补卡面 133 张 → 补法宝图标 23 张
    ↓
VFX 591 帧（需先过美术评审，当前 163 条 finalArtApproved 全 false）
```

---

## 第 10 章　风险与不做的事

### 10.1 三条硬约束（违反会引发系统性故障）

| # | 约束 | 原因 |
|---|---|---|
| 1 | **`texture_for()` 必须保持「缺失返回 null」** | 5 处 `duel_stage_*` 用 `== null` 判定资源可用性；改返回占位图会让校验永远通过，掩盖战斗资源缺失 |
| 2 | **`_pathSynergyRestGeometry` 的 17 个 DOM 引用不得增删重排** | 卡牌飞行动画的避障依赖其固定结构（Web 侧约束，Godot 侧对应卡牌放置逻辑） |
| 3 | **卡牌 ID / 遭遇 ID 永不改名** | 存档、因果种子、事件回执全引用 |

### 10.2 明确不做

| 项 | 原因 |
|---|---|
| 手机端 / 触摸适配 | 平台范围已定：仅桌面 |
| 物理删除浏览器版 | 它是 parity 的权威基准，且被 10 处测试 SHA 依赖 |
| 一次性重写 `noncombat_domain` | 6,476 行，需分 5 次 |
| 用高风险改造去修「静默失效」 | 会制造更多静默失效（G4 的教训） |
| 在 VFX 评审前补 591 帧 | 资产未验收，补完必返工 |

### 10.3 版本规划

| 版本 | 完成条件 |
|---|---|
| **v1.0（本文档）** | 架构规划落地，玩法系统有明确归属 |
| v1.1 | 批次 B 完成：表现层地基可用 |
| v1.2 | 批次 C 完成：结构治理达标 |
| v2.0 | 批次 D 完成 + 全部系统「完全签收」+ Windows 包实机验收 |

---

## 附录 A　与存量 69 份 GDD 的映射

| 存量文档 | 本文档对应 | 关系 |
|---|---|---|
| `docs/gdd/GDD.md` §1-2 | 第 1、2 章 | 继承原文 |
| `docs/gdd/GDD.md` §3 | 第 4、5 章 | **替代**（旧为浏览器 EventBus 架构） |
| `docs/gdd/GDD.md` §3.2 | 第 7 章 | **替代**（旧数据过期） |
| `docs/gdd/GDD_COMBAT_V2/V3.md` | 第 5 章 S11 | 保留为战斗细则 |
| `docs/gdd/GDD_ADDICTION_LAYER.md` | 第 3.2 节六钩 | 保留为细则 |
| `docs/gdd/GDD_TREASURE_DEATH_BALANCE.md` | 第 5 章 S8/S10 | 保留为细则 |
| `GDD_SYSTEM_ALIGNMENT.md` | 第 4.3 节场景规划 | 保留为 UI 参考 |
| 其余约 60 份 | — | 归档，不再作为设计依据 |

## 附录 B　本文档的数据来源

| 数据 | 来源 |
|---|---|
| 脚本数/行数 | `find scripts -name "*.gd" \| xargs wc -l` = 54,360 |
| 场景节点数 | `grep -c "^\[node " scenes/*.tscn` |
| 节点类型分布 | `grep -rho 'type="[A-Za-z]*"' scenes/*.tscn` |
| 依赖扇入扇出 | `grep -c "preload(" scripts/*.gd` / 被 preload 计数 |
| 事件清单 | `noncombat_event_type_probe.gd` 实跑 |
| 内容规模 | `NONCOMBAT_CONTENT_REPOSITORY_PASS` 输出 |
| 资产覆盖 | 审计报告 §5.1 |

---

**文档版本**：v1.0  
**制定日期**：2026-11-05  
**基线提交**：`5522063`  
**下次修订**：批次 B 完成后（预计 v1.1）

