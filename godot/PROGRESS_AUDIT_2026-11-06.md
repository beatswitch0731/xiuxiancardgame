# 一念仙途 · Godot 工程进度审计

| 项 | 内容 |
|---|---|
| 审计日期 | 2026-11-06 |
| 工程根 | `E:/4e/游1/2026-06-27-05-40-58/xiuxian-card-game/godot` |
| 引擎 | Godot 4.7.2 Stable / Forward+ / 1280×800 |
| 分支 / HEAD | `remedy/noncombat-p0-2026-11-05` / `e6f33d1`（本地 = 远程） |
| 审计方式 | 静态扫描 + 关键文件人工阅读 + 7 项冒烟测试实跑 + 读取既有测试基线报告 |
| 未执行 | 全量 394 项测试重跑（基线报告耗时 271 分钟，本轮只跑冒烟）、编辑器实机逐屏 F6 |

**标注约定**：【实测】= 本次扫描或本轮实跑直接得出；【转述】= 来自既有文档，本次未复验；【冲突】= 文档与代码不一致，已给出代码侧结论。

---

## 零、范围与隔离边界（2026-11-06 制作人明确指令）

> **战斗系统本轮不做，开发任务必须隔离。** 本文档后续所有「待办」均只含非战斗侧；战斗侧内容仅作认知记录，不排期、不动代码。

### 0.1 F 区：冻结，一行不改

| 类别 | 文件 |
|---|---|
| 战斗规则 | `combat_domain.gd`、`battle_plan_resolver.gd`、`battle_stub.gd` |
| 战斗总装 / 路由 | `main.gd`、`combat_stage_router.gd` |
| 战斗舞台 | `duel_stage_*.gd`（11 个 / 4,388 行） |
| 战斗表现 | `combat_action_presenter.gd`、`combat_fx/`（camera_shake / fx_library / fx_template / hitstop_controller）、`card_hand_ui.gd`、`reference_battle_hud.gd`、`battle_intent_slip.gd`、`battlefield_art_registry.gd` |
| 战斗角色 | `real_3d_fighter.gd`、`hd2d_sprite_fighter.gd`、`actor_visual_equipment.gd` |
| 装备演示 | `equipment_demo.gd`、`equipment_demo_actor.gd`、`equipment_demo_domain.gd` |

### 0.2 B 区：边界，只准读契约，不准改实现

| 文件 | 归属说明 |
|---|---|
| `noncombat_battle_gateway.gd` | 非战斗发起的战斗邀约/战果校验，是非战斗流程的出口。**只读不写** |
| `noncombat_battle_return_flow.gd` | 战果结算返回非战斗。**只读不写** |
| `noncombat_battle_victory_flow.gd` | 胜利结算。**只读不写** |
| `noncombat_browser_combat_*.gd`（4 个） | 旧网页战斗存档导入/语义。属存档迁移，改它需同时持有战斗侧契约，**本轮不动** |

### 0.3 N 区：本阶段唯一可动范围

`noncombat_*_flow.gd`（约 60 个）、`noncombat_*_policy.gd`、`noncombat_*_screen.gd`、`noncombat_opening_ui.gd`、`noncombat_domain.gd`、`noncombat_content_repository.gd`、`content/data/**`、`theme/`、`scenes/noncombat/**`、非战斗侧测试。

### 0.4 隔离的可验证判据

任何一次改动后跑：

```bash
git diff --stat HEAD -- scripts/combat_domain.gd scripts/battle_plan_resolver.gd scripts/main.gd \
  'scripts/duel_stage_*.gd' scripts/combat_fx scripts/card_hand_ui.gd scripts/reference_battle_hud.gd \
  scripts/equipment_demo*.gd scripts/real_3d_fighter.gd scripts/hd2d_sprite_fighter.gd
# 期望：0 files changed
```

非空即越界，必须回退。

---

## 一、代码结构（全部【实测】）

| 维度 | 数值 | 口径 |
|---|---|---|
| 核心脚本 | **144 个 / 55,397 行** | `scripts/**/*.gd` |
| 测试脚本 | **409 个 / 48,525 行** | `tests/**/*.gd` |
| 工具脚本 | 50 个 / 5,440 行 | `tools/**/*.gd` |
| 场景 | 47 个 `.tscn`，其中 **32 个是单节点** | `scenes/*.tscn` |
| 着色器 | 29 个 `.gdshader` | `shaders/**` |
| 数据 | 77 个 JSON | `content/data/**` |
| Autoload | 1 个（`DataService`） | `project.godot` |
| 编辑器插件 | 1 个（`godot_mcp_bridge`，15 脚本 / 2,299 行，非玩法） | `addons/` |
| 技能示例脚本 | 29 个 / 985 行（`.agents/`，不计入项目代码） | — |

### 1.1 五层分层

```
L5 表现  noncombat_opening_ui(2,475) / duel_stage_*(11 个/4,388行) / card_hand_ui
L4 接口  noncombat_battle_gateway(1,918) / noncombat_battle_return_flow
L3 领域  noncombat_domain(6,504) / combat_domain(1,120)
L2 流程  约 60 个 noncombat_*_flow / *_policy
L1 数据  noncombat_content_repository(1,068) / runtime_data_registry
```

四条纪律（来自 `HANDOFF_FINAL_2026-11-05.md` §4.1，本轮未逐条复验）：L1/L2/L3 禁止 preload `.tscn`；L3 禁止 `extends Node`；L5 禁止直接调 L2 状态变更；Autoload 禁止放玩法逻辑。

### 1.2 最大的三个文件

| 文件 | 行数 | 扇出 | 判断 |
|---|---|---|---|
| `noncombat_domain.gd` | 6,504 | 62 | 上帝对象，未拆 |
| `noncombat_opening_ui.gd` | 2,475 | 32 | 6 屏共用一个脚本，已抽出 3 屏 |
| `noncombat_battle_gateway.gd` | 1,918 | 13 | 跨子系统契约 |

---

## 二、已完成模块（有代码 + 有测试证据）

### 2.1 测试基础设施（本轮完成，【实测】）

| 项 | 状态 | 证据 |
|---|---|---|
| 测试收集判定 | 已修 | `run_test_suite.py` 递归解析 `extends "res://..."` 基类链，收集 240 → 391 |
| 超时日志 | 已修 | `Popen.communicate` + 写 `output/test_timeout/<name>.log` |
| 三车道分类 | 已修 | `test_suite_policy.json`：headless 343 / headless-long 8 / windowed 43 |
| 事件类型常量表 | 已建 | `noncombat_event_types.gd` 141 行，62 个常量 + `is_event_type()` |
| 事件调用点常量化 | 已做 | 93 处替换，`constant_sites=94`，零残留字面量 |
| UI 事件覆盖不变式 | 已建 | `HANDLED_ALL=19` + `AUDIO_ONLY_EVENTS=43` = 62，交集为空 |

### 2.2 非战斗 UI 抽屏（本轮完成，【实测】）

| 屏 | 脚本 | 行数 | 状态 |
|---|---|---|---|
| 存档槽屏 | `noncombat_slot_screen.gd` | 83 | 已抽，节点路径零变更，截图差异 0.0435% |
| 取名屏 | `noncombat_name_screen.gd` | 133 | 已抽（构建函数 74→13 行） |
| 择道屏 | `noncombat_path_screen.gd` | 162 | 已抽（构建函数 88→10 行） |
| 剧情屏 | — | — | **未抽** |

### 2.3 战斗 juice（本轮完成，【实测】）

| 项 | 证据 |
|---|---|
| 屏幕震动 `CameraShake` | `COMBAT_CAMERA_SHAKE_PASS tiers=4 decay=1.4` |
| 受击闪白三段式 | `DUEL_HIT_TINT_PASS flash=0.050 fade=0.070 total=0.160` |

### 2.4 六钩设计在 Godot 侧的落地（【实测】脚本数 / 测试数）

| 钩子 | 脚本 | 测试 | 判定 |
|---|---|---|---|
| 因果系统 karma | 44 | 85 | 覆盖充分 |
| 命盘轮转 destiny_wheel | 3 | 39 | 覆盖充分 |
| 因果涟漪 ripple | 6 | 32 | 覆盖充分 |
| 突破倒计时 breakthrough | 8 | 13 | 覆盖充分 |
| 传承残卷 legacy_fragment | 35 | 8 | 扇入 33，覆盖偏少 |
| **心魔反噬 inner_demon** | 3 | **0** | **零测试，风险点** |

### 2.5 基础设施

| 项 | 证据 |
|---|---|
| `DataService` 单例 + 回退 | 交接文档记录，本轮未复验 |
| `texture_for()` 缺失返回 null 契约 | 5 处 `duel_stage_*` 依赖，未改动 |
| `BattleStub` 战斗桩 | `BATTLE_STUB_CONTRACT_PASS`、`BATTLE_STUB_ROUTE_PASS` |
| 五条音频总线 | `AUDIO_BUS_LAYOUT_PASS buses=5` |
| 资源覆盖率 100% | 交接文档【转述】：3239/3239，卡面 171/171 |

### 2.6 本轮冒烟实跑结果（【实测】，7/7 全绿）

```
noncombat_content_repository   PASS modules=75 cards=588 quests=6 threads=12 scene_refs=553 unlisted=0
noncombat_event_catalog        PASS types=62 constant_sites=94
battle_stub_contract           PASS
battle_stub_route              PASS phase=BATTLE_RESULT_PENDING
audio_bus_layout               PASS buses=5
combat_camera_shake            PASS tiers=4 decay=1.4
duel_hit_tint                  PASS flash=0.050 fade=0.070 total=0.160
```

---

## 三、未完成与存在问题

### 3.1 真实缺陷（不是车道误报）

#### 3.1a 战斗侧 · 冻结，仅记录不修

| # | 问题 | 证据 |
|---|---|---|
| F-1 | 舞台契约方法不存在 | `Nonexistent function 'get_actor_model' / 'get_world_model' in base SubViewportContainer (duel_stage_qingyun_pixel.gd)`；影响 `battle_visual_hierarchy`、`hd2d_stage_contract`、`hd2d_timeline_regression` 三个契约测试 |
| F-2 | VFX 段方法缺失 | `Nonexistent function 'burst_segment' in base Node2D (mapfit_v5_probe_fx.gd)`，调用点 `duel_stage_qingyun_pixel.gd:365`；影响 `mapfit_v5_motion_study`、`mapfit_v6_spacing_study` |

#### 3.1b 非战斗侧 · 可修，属本阶段范围

| # | 问题 | 证据 | 影响 |
|---|---|---|---|
| 1 | 法宝复活检查点不严格 | `noncombat_artifact_revive`：`second-life spell source checkpoint did not strictly restore` | 第二世恢复有偏差，属存档正确性 |
| 2 | 导出边界泄漏 | `desktop_art_export_boundary`：`DESKTOP_ART_EXPORT_LEAK res://art_source/actor_v5_pixel_qa/...png` | `art_source/` 未入包却被导出引用 |
| 3 | 浏览器存档导入失败 | `noncombat_browser_import_ui`、`noncombat_browser_mid_import`（`browser source changed: src/game.js`） | 旧网页存档迁移链断 |
| 4 | 势力注册表元数据丢失 | `noncombat_faction_generated_registry`：`lost exact source or reachability metadata` | 生成势力不可追溯 |
| 5 | 槽位锁 worker | `noncombat_slot_lock_worker` 失败 | 槽位锁并发行为 |
| 6 | 复活/死亡旅程 | `noncombat_death_rebirth_journey`、`noncombat_rebirth_ghost_journey`、`noncombat_rebirth_legacy`、`noncombat_generic_normal_death` | 转世链路 |
| 7 | 奖励布局 | `noncombat_reward_layout` | 结算呈现 |
| 8 | 天画廊 / 白狐入口 | `noncombat_heavenly_gallery`、`noncombat_whitefox_entry` | 入口流程 |
| 9 | 筑基剑试炼 4 项 | `noncombat_foundation_sword_trial_{contract,live_battle,low_resource,outcomes}` + `noncombat_foundation_sword_completion` | **跨边界**：需驱动真实战斗，修它可能触碰 F 区，本轮只做归因不做修复 |

### 3.2 设计承诺与实现不符（**冻结区认知记录，本轮不修**）

> 这三条是本次审计最重要的认知纠正，但它们全部落在战斗冻结区。**只记录，不排期**，等战斗阶段解冻时再作为设计债处理。

| # | 项 | 设计/记忆声称 | 代码实测 |
|---|---|---|---|
| 1 | 法宝三层模型 | `treasures.json._design` 写「属性(passive) + 特性(trait) + 机制(CombatSystem 钩子)」 | 数据层齐全：55 件中 `trait` 44、`passive` 53、`combatPassives` 3、`combatPresentation` 11。**但 `combat_domain.gd` 内 `trait`/`treasure`/`artifact` 词边界命中 0**；`battle_plan_resolver.gd` 只读 `treasureInstances` 快照，无钩子实现 |
| 2 | 战斗 v2.0 六层 | 记忆记「6/6 完成」 | Godot 侧 `qi_pulse`/`parry`/`combo`/`chain`/`stance` 词边界命中**均为 0**。实际战斗是：出牌 + 意图 + `reaction_options()`（`GUARD`/`DEFLECT`/`TAKE_HIT`）+ `block` 数值 + `status`。这套六层只存在于已退役的网页版 `src/systems/CombatSystem.js`（35 KB，2026-08-21） |
| 3 | `items/equipment.json` | 交接文档称为「法宝 6 个」并围绕它规划图标 | 6 件装备，字段 `stats`/`passives`，**无 `icon`、无 `trait`**；全项目搜索 `items/equipment` **零引用**，是孤儿数据。真正的法宝在 `shops/treasures.json`（55 件） |

### 3.3 P1：架构债（本轮实测，与 11-05 审计相比基本未动）

| # | 债 | 当前实测 | 11-05 审计值 |
|---|---|---|---|
| N-1 | 单节点场景 | **32 / 47** | 32 / 47（未变） |
| N-2 | 单脚本多屏 | `opening_ui` 2,475 行 | 2,562 行（降 87） |
| N-3 | 上帝对象 | `noncombat_domain` **6,504 行 / 扇出 62** | 6,476 / 62（略增） |
| N-5 | 节点引用硬编码 | `@export NodePath` **0 个**，`get_node(` **63 处** | 0 / 63（未变） |
| N-6 | 非战斗信号面窄 | 全项目 `signal` 53 个 | 42 个 |
| N-8 | 无 Theme 资源 | `theme/` 只有 `.gitkeep`，Theme `.tres` **0 个** | 14 处 `StyleBoxFlat.new()` |
| N-9 | 舞台脚本重复 | `duel_stage_*` **11 个 / 4,388 行** | 23 个 / 4,299 行 |
| N-11 | `_process(delta)` | **15 个** | 15 个（未变） |

### 3.4 P1：进度账本本身失真

`MIGRATION_SCORECARD.md`（11-05）记「非战斗 10/17 = 59%，N1-b ~ N1-h 全部未开始，N2~N11 未开始」。但代码侧：

| 账本条目 | 账本状态 | 代码实测 |
|---|---|---|
| N1-b 四类摊位规则 | 未开始 | 四个 flow 均已存在：`noncombat_vendor_flow`(45 KB)、`noncombat_regulated_vendor_flow`(42 KB)、`noncombat_ghost_vendor_flow`(38 KB)、`noncombat_last_lesson_vendor_flow`(29 KB) |
| N1-e 鬼债与官坊交付 | 未开始 | `noncombat_licensed_delivery.gd`(13 KB) 存在 |
| N2 存档/恢复/槽位锁 | 未开始 | 槽屏已抽、`noncombat_run_session.gd`(19 KB)、`noncombat_browser_opening_import.gd`(19 KB)、`noncombat_browser_save_staging` 测试通过 |
| N1-f 动态 NPC 交叉卡 | 未开始 | `noncombat_npc_cross_flow.gd`(30 KB)、`noncombat_npc_encounter_flow.gd`(28 KB) |
| N1-g 同伴事件卡 | 未开始 | `noncombat_companion_events.gd`(36 KB)、`noncombat_companion_arc_flow.gd`(16 KB) |

**结论：账本反映的是「签收状态」，不是「代码状态」。** 大量条目是「代码写了但没跑验收测试、没记账」，所以 59% 这个数字会显著低估实际完成量，但它同时也不能当完成度用——缺的是验收证据。

### 3.5 P2：测试基线未清零（已按隔离边界分类）

`output/test_suite_report_s0.json`（2026-11-06 02:59）【实测读取】：

```
pass=326  fail=27  timeout=41  error=0   收集 394   耗时 16,279 秒（271 分钟）
lanes: headless=343  headless-long=8  windowed=43
```

按 §零 的隔离边界重新归类【实测】：

| 桶 | fail | timeout | 归属 |
|---|---|---|---|
| 战斗侧 | **5** | 0 | F 区冻结，不修 |
| 非战斗侧 | **22** | **41** | N 区，本阶段范围 |
| 其中渲染车道误报 | 若干 | 若干 | 已在 S4 分车道，非代码缺陷 |

- 非战斗侧 41 个 timeout 全部是「自然长局」类（`noncombat_*_natural`、`*_outcomes`、`*_journey`、`qi_gate_*`），不是卡死
- 4 个长测试仍超默认门禁：`noncombat_choice_echo_public_seed`(116s)、`noncombat_faction_combat`(180s)、`noncombat_faction_natural`(600s)、`noncombat_q_fellow_outcomes`(>180s)
- **结论：战斗冻结后，非战斗侧仍有 22 fail + 41 timeout 的真实债**，不能因为「战斗不做」就认为基线已经干净

---

## 四、文档与代码不一致清单（本次核实的核心产出）

| # | 文档说法 | 出处 | 代码实测 | 处置建议 |
|---|---|---|---|---|
| 1 | 「法宝 6 个，`icon` 0 个 → 真缺口」 | `HANDOFF_FINAL` §5.2、`HANDOFF_TO_CODEX` 卡点 A | `equipment.json` 6 件**且零引用**；`treasures.json` 55 件法宝才有 `trait` | 图标需求单要按 55 件/4 槽位重写；先决定 `equipment.json` 是删还是接 |
| 2 | 「`sync_runtime_content.py` 手工枚举，待改三段式」 | `HANDOFF_FINAL` §10.3 | **已完成**：`discover_referenced_assets()` + `collect_*` 三段式，提交 `3a84297` | 从待办移除 |
| 3 | 「抽 5 屏为 `.tscn`」 | `HANDOFF_FINAL` §10.3、`HANDOFF_TO_CODEX` T1/T2 | 走的是 `.gd` 路线，已抽 3 屏；`scenes/noncombat/screens/` 仍只有 `.gitkeep` | 明确路线：`.gd` 已验收就改文档，不要再按 `.tscn` 规划 |
| 4 | 脚本 135 个 / 54,360 行 | `HANDOFF_FINAL` §1.2 | **144 个 / 55,397 行** | 更新基线 |
| 5 | 测试 401 个 | `HANDOFF_FINAL` §1.2 | **409 个** | 更新基线 |
| 6 | 「事件类型常量化 待做」 | `HANDOFF_FINAL` §10.3 | **已完成**：62 类型 + 93 处替换 + 覆盖不变式 | 从待办移除 |
| 7 | 战斗 v2.0 六层 6/6 | `MEMORY.md` | Godot 侧仅 block 数值 + 三选一反应，无架势/连击/法宝钩子 | 记忆需改写：网页版成果未随迁移继承 |
| 8 | 六钩 6/6 完成 | `MEMORY.md` | 5 钩有测试，`inner_demon` **0 测试** | 补测试或降级标注 |
| 9 | 法宝 25 件（武器4/防具4/饰品9/秘宝8） | `MEMORY.md` | 55 件（秘宝24/武器14/饰品12/防具5） | 记忆需更新 |
| 10 | 非战斗 59% | `MIGRATION_SCORECARD` | 代码量远超，但缺验收证据 | 账本改为「签收口径」，另设「代码存在口径」 |

---

## 五、风险与阻塞点

| 优先级 | 风险 | 为什么阻塞 | 缓解 |
|---|---|---|---|
| **R1** | `noncombat_domain.gd` 6,504 行 / 扇出 62 | 任何改动都可能行为漂移，394 个测试里定位成本极高 | 若要动，必须先有全量绿基线 + 一次只迁一类 + 独立提交 |
| **R2** | 非战斗侧 22 fail + 41 timeout 未分类归因 | 无法判断新改动是真回归还是踩到既有失败 | 先出「真缺陷 / 跨边界 / 历史遗留」三张清单 |
| **R3** | UI 32/47 单节点场景 | 美术无法在编辑器里独立调界面，改样式必须改代码 | 抽屏继续，并把 Theme 资源化提前 |
| **R4** | `inner_demon` 零测试 | 六钩之一完全无回归保护，且属非战斗侧 | 补一个最小契约测试 |
| **R5** | 4 个长测试 116~600 秒 | 阻塞门禁，任何全量验证要 4.5 小时 | 拆分测试（GDD §8.3 要求单测 ≤120s） |
| **R6** | 账本与代码脱节 | 排期会基于错的完成度 | 账本加「代码存在 / 已验收」双列 |
| **R7** | 隔离边界靠自觉，无机器门禁 | 一次「顺手改」就可能把战斗侧拖进来 | 落地 §0.4 的 `git diff --stat` 判据，越界即回退 |

### 冻结区风险（不在本轮，仅登记）

| 项 | 说明 |
|---|---|
| 法宝机制层未接战斗 | 55 件法宝有 `trait` 数据，`combat_domain` 无钩子。设计最大兑现缺口，属战斗阶段任务 |
| 战斗六层未迁移 | 架势/连击/灵力脉冲/格挡时机在 Godot 侧不存在，只在退役网页版 |
| F-1 / F-2 舞台契约与 VFX 段方法缺失 | 见 §3.1a |

---

## 六、建议的下一步（仅非战斗侧，二选一）

战斗侧已冻结，原先的「补法宝战斗接线」选项**作废**。剩下的两条都在 N 区，且互不依赖，可以任选其一先做：

| 选项 | 内容 | 收益 | 成本 | 越界风险 |
|---|---|---|---|---|
| **A′** | 收口非战斗测试基线：把 22 fail + 41 timeout 分成「真缺陷 / 跨边界（需驱动战斗）/ 历史遗留」三张清单，先修 §3.1b 的 1~8 项 | 恢复「测试可信」，后续所有改动才有安全网 | 中，多轮跑测 | 低（第 9 项筑基剑试炼标为只归因不修） |
| **C′** | 继续 UI 结构改造：抽 story 屏 + Theme 资源化 + 剩余单节点场景 | 解锁美术独立迭代，降低后续 UI 成本 | 中低，方法论已验证 | 零（纯表现层，不碰战斗） |

> **建议先 A′ 后 C′**：A′ 只产出归因清单 + 修 8 项非战斗缺陷，能把「基线脏」这个长期噪音清掉；C′ 的方法论已在本轮验证（截图差异 0.0435%），随时可插入，不依赖 A′。

**不建议**在同一轮里混做 A′ 与 C′：抽屏会改 `noncombat_opening_ui.gd`，而 A′ 的部分失败测试恰好依赖该文件的布局断言，混做会让归因重新变模糊。

---

## 七、本次审计未覆盖

- 全量 394 项测试重跑（只跑 7 项冒烟）
- 编辑器实机逐屏 F6 校验
- 导出包体实际运行（`export_presets.cfg` 未验证）
- 美术资源 163 条 `finalArtApproved` 的人工评审
- 移动端（TapTap 目标平台）触控与性能

**审计结论**：工程「逻辑层厚、表现层薄、验收证据缺」的格局本轮未改变。本轮真实推进集中在**测试基础设施、事件类型安全、三屏抽取、战斗 juice** 四块。

两处认知偏差已登记但**按隔离要求不修**：① 法宝机制层与战斗六层没有随迁移继承（§3.2）；② `items/equipment.json` 是孤儿数据，交接文档误把它当法宝清单。这两条等战斗阶段解冻时再处理。

**当前可执行范围只有 N 区**（§0.3）：非战斗 flow / UI / 数据 / 非战斗测试。F 区与 B 区在本阶段一律不动，用 §0.4 的 `git diff --stat` 判据做机器校验。
