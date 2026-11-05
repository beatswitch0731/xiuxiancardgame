# 《一念仙途》Godot 工程 · 交接手册

| 项 | 内容 |
|---|---|
| 文档版本 | v1.0 |
| 编制日期 | 2026-11-05 |
| 工程根 | `E:/4e/游1/2026-06-27-05-40-58/xiuxian-card-game/godot` |
| 引擎 | Godot 4.7.2 Stable / Forward+ / 1280×800 |
| 当前分支 | `remedy/noncombat-p0-2026-11-05` |
| 适用读者 | 接手本工程开发/维护的人，或 AI 编码助手 |

---

## 目录

1. [项目概览](#1-项目概览)
2. [目录结构](#2-目录结构)
3. [模块职责](#3-模块职责)
4. [使用方式](#4-使用方式)
5. [资源规范](#5-资源规范)
6. [维护方式](#6-维护方式)
7. [关键约束](#7-关键约束)
8. [排错手册](#8-排错手册)
9. [本次结构迁移记录](#9-本次结构迁移记录)

---

## 1. 项目概览

### 1.1 一句话

> 一个仙侠题材的卡牌抉择游戏（Reigns 式双选），从浏览器版迁移到 Godot，逻辑层已完成 80~90%，表现层在进行中。

### 1.2 技术栈

| 项 | 值 |
|---|---|
| 引擎 | Godot 4.7.2 Stable |
| 语言 | GDScript 2.0（全项目零 C#） |
| 渲染 | Forward+ / Vulkan 1.4 |
| 分辨率 | 1280×800 固定 |
| 平台 | **仅 Windows 桌面**（不含手机/触摸） |
| 数据 | JSON（588 卡 / 75 模块 / 16 NPC） |
| 测试 | 自定义 `extends SceneTree` 脚本，401 个 |

### 1.3 规模【实测】

| 指标 | 数值 |
|---|---|
| 脚本 | 135 个 / 54,360 行 |
| 场景 | 47 个 |
| 测试 | 401 个 |
| 数据模块 | 75 个 / 9.1MB |
| 资源 | `content/assets` 967MB + `assets` 1.7GB |

### 1.4 设计文档索引

| 文档 | 用途 |
|---|---|
| `GDD_GODOT_V1.md` | **设计 + 架构主文档**，11 章 |
| `ASSET_AUDIT_VERIFIED_2026-11-05.md` | 资源缺口核对（含三项纠错） |
| `ARCHITECTURE_REVIEW_GODOT_2026-11-05.md` | 架构审计（N-1~N-11 问题） |
| `HANDOFF_TO_CODEX_2026-11-05.md` | 待办任务交接（T1~T6） |
| `MIGRATION_SCORECARD.md` | 子项进度账本 |

---

## 2. 目录结构

### 2.1 顶层

```
godot/
├─ project.godot              ← 引擎配置（主场景、autoload、渲染）
├─ default_bus_layout.tres    ← 音频总线（Master/BGM/SFX/Voice/UI）
├─ export_presets.cfg         ← 导出配置
│
├─ autoload/                  ← 全局单例（只放服务，不放玩法）
├─ scripts/                   ← 全部 GDScript（135 个）
├─ scenes/                    ← 场景文件（47 个）
├─ theme/                     ← 主题资源（待填充）
├─ shaders/                   ← 着色器
│
├─ content/                   ← 运行时内容（唯一权威）
│  ├─ data/                   ← JSON（77 个，9.1MB）★入库
│  ├─ assets/                 ← 运行时贴图（967MB）☆不入库
│  ├─ media_frames/           ← 抽帧中间产物 ☆不入库
│  ├─ source_media/           ← 源媒体 ☆不入库
│  ├─ derived/                ← 派生资源 ★入库
│  └─ source_manifest.json    ← 别名表（18 条 runtimeAliases）★入库
│
├─ assets/                    ← 手工资源（3D/字体/UI）☆不入库
│  ├─ fonts/                  ← 字体（42MB）
│  ├─ ui/                     ← UI 材质（2MB）
│  ├─ battle/                 ← 战斗资源（1.5GB+）
│  ├─ characters/             ← 角色资源（80MB）
│  ├─ demo/                   ← 演示资源（4MB）
│  ├─ items/                  ← 道具图标（**新，待美术产出**）
│  ├─ cards/                  ← 卡牌相关（320KB）
│  └─ third_party/            ← 第三方（6.4MB）
│
├─ tests/                     ← 401 个测试
│  └─ fixtures/               ← 测试夹具
│     └─ visual/              ← 视觉基线截图
│
├─ tools/                     ← 工具脚本（Python + GDScript）
├─ output/                    ← 截图与运行产物 ☆不入库
├─ art_source/                ← .blend 源文件（1.6GB）☆不入库
├─ art_direction/             ← 概念图（383MB）☆不入库
├─ dist/                      ← 导出包（2.5GB）☆不入库
└─ addons/                    ← 编辑器插件（godot_mcp_bridge）
```

**★入库 / ☆不入库**：`.git` 已 17GB，只有代码、配置、数据、文档入库。资源靠同步脚本或手工分发。

### 2.2 scripts/ 的命名约定

| 前缀 | 含义 | 数量 |
|---|---|---|
| `noncombat_*` | 非战斗逻辑（主线） | 约 100 |
| `combat_*` / `duel_*` | 战斗 | 约 25 |
| `actor_*` | 角色演示/换装 | 8 |
| `battle_*` | 战斗辅助（plan/intent） | 2 |

**新加非战斗脚本必须带 `noncombat_` 前缀**，否则会被审计脚本漏掉。

---

## 3. 模块职责

### 3.1 五层架构（硬纪律）

```
L5 表现层   NoncombatOpeningUI / DuelStage* / *_ui
              ↓ 只读领域，禁止持规则
L4 接口层   BattleGateway / BattleReturnFlow / BattleStub
              ↓
L3 领域层   NoncombatDomain(6476行) / CombatDomain
              ↓ 禁止 extends Node
L2 流程层   约 60 个 noncombat_*_flow / *_policy
              ↓
L1 数据层   ContentRepository / RuntimeDataRegistry
```

**四条纪律**：

| # | 纪律 | 违反后果 |
|---|---|---|
| 1 | L1/L2/L3 禁止 preload `.tscn` | 数据层被场景污染，headless 测试跑不了 |
| 2 | L3 禁止 `extends Node` | Domain 变节点后测试必须建场景树 |
| 3 | L5 禁止直接调 L2 的状态变更方法 | 绕过 Domain 导致 UI 与状态漂移 |
| 4 | Autoload 禁止放玩法逻辑 | 单例化后无法隔离测试 |

### 3.2 核心文件职责

| 文件 | 行数 | 职责 | 改动风险 |
|---|---|---|---|
| `noncombat_domain.gd` | **6,476** | 非战斗权威状态机 + 全部流程编排 | **极高**（62 扇出） |
| `noncombat_opening_ui.gd` | **2,562** | 全部非战斗界面（6 屏） | **高**（132 处 `.new()`） |
| `noncombat_battle_gateway.gd` | 1,918 | 战斗邀约/请求/战果校验 | 高（32 测试引用） |
| `duel_stage_hd2d.gd` | 1,471 | HD-2D 战斗演出 | 中（战斗延后） |
| `noncombat_normal_choice_policy.gd` | 1,332 | 普通卡抉择策略 | 中 |
| `noncombat_realm_gate_flow.gd` | 1,305 | 境界关隘 | 中 |
| `combat_domain.gd` | 1,120 | 战斗权威规则 | 中（战斗延后） |
| `noncombat_content_repository.gd` | 1,068 | JSON 索引 + SHA 校验 | **低**（28 扇入，只读） |
| `main.gd` | 928 | 战斗场景总装 + 舞台路由 | 中 |

### 3.3 12 个一级系统

| 系统 | 领域入口 | 主要流程 | 数据 |
|---|---|---|---|
| S1 卡牌引擎 | `NoncombatDomain` | `noncombat_normal_draw_policy`<br>`noncombat_normal_choice_policy` | `data/cards/*` |
| S2 修路 | 同上 | `noncombat_path_skill_flow`<br>`noncombat_first_session_route` | `data/config/paths.json` |
| S3 境界 | 同上 | `noncombat_realm_gate_flow`<br>`noncombat_foundation_dungeon_flow` | `data/cards/chapter_milestones.json` |
| S4 因果 | 同上 | `noncombat_karma_flow`<br>`noncombat_ripple_flow`<br>`noncombat_destiny_wheel`<br>`noncombat_causal_fact_clock` | `data/echoes/*`<br>`data/threads/*` |
| S5 同伴 | 同上 | `noncombat_companion_events`<br>`noncombat_companion_arc_flow` | `data/companions/*` |
| S6 NPC | 同上 | `noncombat_npc_encounter_flow`<br>`noncombat_npc_interaction_flow` | `data/npcs/core_npcs.json` |
| S7 势力 | 同上 | `noncombat_faction_events`<br>`noncombat_story_thread_flow` | `data/world/*` |
| S8 坊市 | 同上 | `noncombat_vendor_flow`<br>`noncombat_ghost_vendor_flow`<br>`noncombat_regulated_vendor_flow` | `data/shops/*`<br>`data/markets/*` |
| S9 秘境 | 同上 | `noncombat_cave_flow`<br>`noncombat_nascent_ruins_flow` | `data/locations/*` |
| S10 死亡转世 | 同上 | `noncombat_death_flow`<br>`noncombat_rebirth_flow`<br>`noncombat_lineage_flow` | `data/progression/*` |
| S11 战斗 | `CombatDomain` | `duel_stage_*`（23 个） | `data/combat/*` |
| S12 图鉴 | — | `noncombat_evidence_atlas`<br>`noncombat_karma_journal`<br>`noncombat_thread_journal`<br>`noncombat_bestiary_ui` | 汇总 |

### 3.4 Autoload（3 个，只放服务）

| 名称 | 职责 | 实现 |
|---|---|---|
| `DataService` | 共享 `RuntimeDataRegistry` | ✅ `autoload/data_service.gd` |
| `AudioBus` | 五总线音量控制 | ⚠️ 总线已建，控制未接 |
| `GameSettings` | 阅读偏好/特效档位 | ⚠️ 存在但是实例非单例 |

**取用方式**（必须带回退）：

```gdscript
var data_service := get_node_or_null("/root/DataService") as GameDataService
if data_service != null:
    registry = data_service.registry_or_new()
else:
    registry = RuntimeDataRegistry.new()   # 测试与独立场景走这条
```

---

## 4. 使用方式

### 4.1 环境要求

| 项 | 要求 |
|---|---|
| Godot | 4.7.2 Stable（路径见下） |
| 显卡 | 支持 Vulkan（实测 RTX 3060 可用） |
| 磁盘 | ≥ 5GB（资源 + 导入缓存） |

**Godot 可执行文件**：
```
<repo>/.godot-toolchain/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe
```

### 4.2 首次上手（四条命令）

```bash
GODOT="<上面的路径>"
P="<repo>/godot"

# ① 重建全局类缓存（首次必须，否则 class_name 全部失效）
"$GODOT" --headless --path "$P" --editor --quit

# ② 完整加载（验证无解析错误）
"$GODOT" --headless --path "$P" --quit-after 5

# ③ 跑核心测试
"$GODOT" --headless --path "$P" --script "res://tests/noncombat_content_repository.gd"

# ④ 截图看界面
"$GODOT" --path "$P" --script "res://tools/shot_probe.gd"
# → godot/output/_shot_probe.png
```

**① 不可跳过**：`--check-only` 单文件模式**不解析全局类缓存**，会误判通过。

### 4.3 运行项目

```bash
# 直接跑主场景
"$GODOT" --path "$P"

# 跑导出包
./dist/windows/YiNianXianTu.exe
```

### 4.4 测试

```bash
# 单个测试
"$GODOT" --headless --path "$P" --script "res://tests/<name>.gd"

# 耗时型测试需要更长超时（见 §8.3）
```

**测试写法**：`extends SceneTree` + `_initialize()`，不是 `Node` + `_ready()`。

### 4.5 截图（视觉回归）

```bash
"$GODOT" --path "$P" --script "res://tools/shot_probe.gd"
```

- **必须非 headless**（不加 `--headless`），否则无渲染上下文
- 改 `shot_probe.gd` 的 `TARGET` 常量可截任意场景
- 基线截图在 `tests/fixtures/visual/`

### 4.6 导出

```bash
"$GODOT" --headless --path "$P" --export-release "Windows Desktop" dist/windows/YiNianXianTu.exe
```

导出前确认 `export_presets.cfg` 的 `exclude_filter` 排除了 `art_source/`、`art_direction/`、`output/`、`tests/`。

---

## 5. 资源规范

### 5.1 两套资源根（重要，别混）

| 根 | 用途 | 引用方式 | 入库 |
|---|---|---|---|
| `content/assets/` | **运行时内容**（卡面/场景图/音频） | `texture_for("assets/xxx.png")` | ❌ 967MB |
| `assets/` | **手工资源**（3D/字体/UI 材质） | `res://assets/fonts/xxx.ttf` | ❌ 1.7GB |

**为什么两套**：
- `content/assets` 由同步脚本从浏览器版复制，路径格式与源 JSON 一致（`assets/xxx`），经 `RuntimeDataRegistry` 收口，带 18 条 `.png`→`.jpg` 别名
- `assets` 是 Godot 原生资源（`.glb`/`.ttf`/`.tres`），直接 `res://` 引用

**新加资源时的判断**：
- 来自源 JSON 的图（卡面/sceneImage）→ `content/assets/`
- Godot 原生资源（模型/字体/主题）→ `assets/`

### 5.2 assets/ 分类规则（2026-11-05 重构后）

| 目录 | 放什么 | 来源 |
|---|---|---|
| `fonts/` | 字体文件 | 原位保留 |
| `ui/` | UI 材质图（plaque/slip 等） | 原位保留 |
| `battle/` | 战斗相关（hd2d/25d/战场/参考素材） | 由 `hd2d`、`25d`、`undercurrent_pixel_v1`、`source_first_fight`、`battle_actor_style_v1` 迁入 |
| `characters/` | 角色资源（模型/换装/候选） | 由 `actor_*`、`modular_pixel_actor_v1`、`actors`、`actor_candidates` 迁入 |
| `demo/` | 演示/实验资源（不参与发布） | 由 `equipment_demo`、`equipment_swap_mvp` 迁入 |
| `items/` | 道具图标（**待产**） | 新增 |
| `cards/` | 卡牌相关杂项 | 原位保留 |
| `third_party/` | 第三方资源 | 原位保留 |

### 5.3 命名规范

| 类型 | 规范 | 示例 |
|---|---|---|
| 卡面 | `card_<效果>_<风格>.png` | `card_strike_pc98.png` |
| 场景图 | `scene_<地点/事件>.png` | `scene_camp.png` |
| 战场 | `battlefield_<遭遇id>.png` | `battlefield_enc_trial_sword_swift.png` |
| 法宝图标 | `{slot}_icon.png` | `weapon_icon.png` |
| 字体 | 原名保留 | `NotoSansSC-VF.ttf` |
| 场景文件 | `<系统>_<用途>.tscn` | `slot_screen.tscn` |

### 5.4 帧序列（animatedMedia）

`content/source_manifest.json` 的 `animatedMedia` 数组：

```json
{
  "sourcePath": "assets/card-illustrations/motion/jian-idle.webp",
  "frames": [{"path": "assets/...", "durationMs": 120}, ...]
}
```

**当前只有 3 条**（`jian-idle` 4 帧、`jiuwei-idle` 4 帧、`jiuwei-water` 60 帧）。
场景立绘**零帧序列**。

`sprite_frames_for()` 已做逐帧容错：缺帧跳过，全缺才返回 null。

---

## 6. 维护方式

### 6.1 加一张新卡

1. 编辑 `content/data/cards/<realm>.json`，在 `cards[]` 加一项
2. 必填字段：`id`（全局唯一，**永不改名**）、`title`、`description`、`type`、`choices`、`sceneImage`
3. `sceneImage` 指向 `assets/cards/events/xxx.png`，确保文件存在于 `content/assets/`
4. 跑 `noncombat_content_repository` 测试 —— `unlisted` 必须为 0
5. 跑 `noncombat_qi_gate_entry` 之类的路线测试确认无回归

**注意**：加卡后决策时钟会变，parity 测试可能失败。这是预期行为，需重新对照。

### 6.2 加一张战斗卡

1. 编辑 `content/data/cards/battle_cards.json` 的 `battle_cards[]`
2. 必填：`id`、`name`、`type`、`cost`、`description`、`effects`、`cardArt.image`
3. `cardArt.image` 指向 `assets/combat/cards/xxx.png`
4. 跑 `battle_stub_contract` + `noncombat_qi_gate_entry`

### 6.3 加一个法宝图标（待做）

三步，**必须一次做完**，避免字段存在但无人读取：

1. 美术产出 4 张：`armor_icon.png` / `weapon_icon.png` / `artifact_icon.png` / `accessory_icon.png`
   放到 `assets/items/`
2. `content/data/items/equipment.json` 每个 item 加 `"icon": "res://assets/items/{slot}_icon.png"`
3. 改 UI 读取：`noncombat_treasure_acquisition.gd` 与装备界面（当前只渲染文字）

**为什么 4 张不是 6 张**：6 个法宝按 slot 分布是 armor 1 / accessory 2 / weapon 1 / artifact 2，4 张覆盖全部，且新增法宝不用再画。

### 6.4 加一个场景（战斗舞台）

1. 在 `scenes/` 建 `.tscn`（**推荐用编辑器**，不手写）
2. `main.gd` 的 `STAGE_ROUTES` 加一条：`"key": "res://scenes/xxx.tscn"`
3. `_build()` 的分支里加 `stage_key = "key"`
4. 跑 `noncombat_qi_gate_entry` 确认路由有效

**不要**在 `main.gd` 加 `const XxxScene = preload(...)` —— 那会把场景在编译期全部加载。

### 6.5 改 `noncombat_domain.gd`（高风险）

6,476 行 / 62 扇出。改动纪律：

1. 先跑全量非战斗测试记录基线
2. 一次只改一类功能
3. 改完立即跑全量，断言数不得减少
4. 独立提交，便于单独回退
5. **期间禁止其他并行改动**

拆分规划见 `GDD_GODOT_V1.md` §4.6（5 个 Director）。

### 6.6 改 UI（`noncombat_opening_ui.gd`）

2,562 行 / 6 个屏共用一个脚本。改动纪律：

1. 先 `grep -n` 定位要改的函数（`_build_slot_screen` L405 / `_build_name_screen` L688 / …）
2. 改完**必须截图比对**（`tools/shot_probe.gd`）
3. 因为 6 屏共用，改一处要确认其余 5 屏无变化

### 6.7 同步资源（从浏览器版）

当前脚本 **`tools/sync_runtime_content.py` 第 69–290 行是手工枚举**（`ENCOUNTER_ID = "enc_trial_sword_swift"`），**只同步白名单内的资产**。

这就是 133 张卡面缺失的根因（2026-11-05 已手工补齐）。

**临时方案**（手工同步单个目录）：

```python
# 见 ASSET_AUDIT_VERIFIED_2026-11-05.md §七 的可复现脚本
```

**长期方案**：改成三段式 `collect_refs()` / `resolve()` / `report()`，全量发现 JSON 里的 `assets/` 引用。

---

## 7. 关键约束

### 7.1 三条不可违反的契约

| # | 约束 | 原因 | 违反后果 |
|---|---|---|---|
| 1 | `texture_for()` 缺失必须返回 **null** | 5 处 `duel_stage_*` 用 `== null` 判定资源可用性 | 战斗资源缺失被静默掩盖 |
| 2 | `BattleStub` 结果必须过 `validate_result()` | 桩要与真实战斗同契约 | 接口失真，接真战斗时全崩 |
| 3 | 卡牌/遭遇 ID **永不改名** | 存档、因果种子、事件回执全引用 | 旧档全废 |

### 7.2 禁止事项

| # | 禁止 | 原因 |
|---|---|---|
| 1 | `battle_stub_mode` 默认改 `true` | 生产会走桩、无真实战斗 |
| 2 | 删测试或改断言 | 326 个非战斗测试是唯一安全网 |
| 3 | 动 `duel_stage_*` 结构 | 战斗本阶段刻意延后 |
| 4 | 手写 `.tscn` 的 `uid` | 让引擎生成 |
| 5 | 在 `.tscn`/`.tres` 写注释 | Godot 解析器不支持 |
| 6 | 把 `content/assets` 或 `assets` 加进 git | 2.7GB，会让仓库爆炸 |
| 7 | 用 `--check-only` 判定跨文件类型正确 | 它不解析全局类缓存 |
| 8 | 全局替换时命中自己刚写的 wrapper | 会造成无限递归（已踩过） |

---

## 8. 排错手册

### 8.1 `Could not find type "XxxYyy"`

**原因**：全局类缓存未更新。加了 `class_name` 或新 autoload 后必现。

**解法**：
```bash
"$GODOT" --headless --path "$P" --editor --quit
"$GODOT" --headless --path "$P" --quit-after 5
```

### 8.2 `Failed to instantiate an autoload`

**原因**：同 8.1，autoload 脚本解析失败导致"不继承 Node"。

**解法**：重建缓存后重试。若仍失败，检查 autoload 脚本第一行是否 `class_name Xxx` + `extends Node`。

### 8.3 测试超时（默认 30 秒）

| 测试 | 实际耗时 |
|---|---|
| `noncombat_choice_echo_public_seed` | 约 116 秒 |
| `noncombat_faction_combat` | 180 秒 |
| `noncombat_faction_natural` | 约 600 秒 |
| `noncombat_q_fellow_outcomes` | > 180 秒 |

**解法**：单独跑时给足超时。**不要**通过改测试内部逻辑来"加速"。

### 8.4 `Cannot infer the type of "x"`

**原因**：右侧表达式类型未知，常见于 `var x := registry.xxx()`，因为 `registry` 声明为 `RefCounted`。

**解法**：显式标注 `var x: Texture2D = registry.xxx()`。

### 8.5 资源 404 / 贴图空白

**排查顺序**：
1. 看控制台有没有 `[ASSET_MISSING]` 告警（`texture_for` 已加日志）
2. 检查 `content/source_manifest.json` 的 `runtimeAliases` 是否有 `.png`→`.jpg` 别名
3. 确认文件在 `content/assets/` 下（不是 `assets/`）
4. 如果是法宝图标缺失 → 预期行为（尚未产出）

### 8.6 测试报 `FOREIGN_RESULT` / `INVALID_OUTCOME`

**原因**：桩或战斗产出的 result 与 gateway 契约不符。

**排查**：对照 `noncombat_battle_gateway.validate_result()` 的字段要求（8 个必填 + receipt 格式 + postBattleState 三字段自洽）。

### 8.7 音频没声音 / bus 报错

**排查**：
1. `default_bus_layout.tres` 是否在项目根
2. 跑 `tests/audio_bus_layout.gd` 确认 5 条总线在
3. 检查播放器的 `bus` 是否指向存在的总线名

---

## 9. 本次结构迁移记录

### 9.1 迁移映射（旧 → 新）

如果有人按旧路径找文件，对照此表：

| 旧路径 | 新路径 | 体积 |
|---|---|---|
| `assets/hd2d` | `assets/battle/hd2d` | 1.5G |
| `assets/25d` | `assets/battle/25d` | 9.8M |
| `assets/undercurrent_pixel_v1` | `assets/battle/undercurrent_pixel_v1` | 30M |
| `assets/source_first_fight` | `assets/battle/source_first_fight` | 664K |
| `assets/battle_actor_style_v1` | `assets/battle/battle_actor_style_v1` | 940K |
| `assets/actor_image3d_mvp` | `assets/characters/actor_image3d_mvp` | 48M |
| `assets/actor_motion_lab_v1` | `assets/characters/actor_motion_lab_v1` | 8.2M |
| `assets/actor_wearable_v2` | `assets/characters/actor_wearable_v2` | 18M |
| `assets/modular_pixel_actor_v1` | `assets/characters/modular_pixel_actor_v1` | 6.5M |
| `assets/actor_candidates` | `assets/characters/actor_candidates` | 820K |
| `assets/actors` | `assets/characters/actors` | 344K |
| `assets/equipment_demo` | `assets/demo/equipment_demo` | 4.0M |
| `assets/equipment_swap_mvp` | `assets/demo/equipment_swap_mvp` | 4K |

**未迁移**（保持原位）：`fonts` / `ui` / `cards` / `third_party`

### 9.2 迁移影响

| 项 | 结果 |
|---|---|
| 引用替换 | 21 个文件 / 59 处，无残留 |
| 引用总数 | 82 处不变（`battle` 30 + `characters` 28 + `fonts` 17 + `ui` 6 + `demo` 1） |
| 完整加载 | 零 SCRIPT ERROR |
| 雷关跑通 | `NONCOMBAT_QI_GATE_ENTRY_PASS`，`assets_ready=true`（证明 3D 战场资源加载正常） |
| 截图 | `SHOT_PROBE_PASS size=(1280,800)` |

### 9.3 新增目录

| 目录 | 用途 | 状态 |
|---|---|---|
| `theme/` | 主题资源 | 空（待填充） |
| `scenes/noncombat/screens/` | 5 个屏的 `.tscn` | 空（待抽） |
| `scenes/noncombat/shared/` | 复用组件 | 空（待抽） |
| `assets/items/` | 法宝图标 | 空（待美术） |

---

## 附录：快速命令速查

```bash
GODOT="<repo>/.godot-toolchain/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe"
P="<repo>/godot"

# 重建缓存（改 class_name / autoload 后必做）
"$GODOT" --headless --path "$P" --editor --quit

# 编译验证
"$GODOT" --headless --path "$P" --quit-after 5

# 核心测试
"$GODOT" --headless --path "$P" --script "res://tests/noncombat_content_repository.gd"
"$GODOT" --headless --path "$P" --script "res://tests/noncombat_qi_gate_entry.gd"
"$GODOT" --headless --path "$P" --script "res://tests/battle_stub_contract.gd"
"$GODOT" --headless --path "$P" --script "res://tests/battle_stub_route.gd"
"$GODOT" --headless --path "$P" --script "res://tests/audio_bus_layout.gd"

# 截图
"$GODOT" --path "$P" --script "res://tools/shot_probe.gd"

# 运行
"$GODOT" --path "$P"
```

---

**文档版本**：v1.0  
**编制日期**：2026-11-05  
**对应提交**：结构迁移后（见 `git log` 最新提交）  
**下次修订**：抽屏（T1/T2）完成后
