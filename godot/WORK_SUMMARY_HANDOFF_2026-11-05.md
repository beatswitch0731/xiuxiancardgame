# 工作情况总结与交接文档

| 项 | 内容 |
|---|---|
| 文档性质 | **总纲入口**——汇总本分支全部工作并指向各专项文档 |
| 编制日期 | 2026-11-05 12:25 |
| 交接对象 | Codex（接手开发/维护） |
| 工程根 | `E:/4e/游1/2026-06-27-05-40-58/xiuxian-card-game/godot` |
| 分支 | `remedy/noncombat-p0-2026-11-05`（本地 = 远程） |
| 交接时 HEAD | `d57b9c8`（分支共 **22 个提交**，基线 `c268384`） |

> **上手路径**：本文档通读一遍（约 15 分钟）→ 按 §7 索引按需查专项文档 → 按 §3 待办顺序开工。所有文档中的数字遵循「口径 + 来源 + 实测/推断」纪律（详见 `HANDOFF_FINAL_2026-11-05.md` §0）。

---

## 1. 交接摘要

> **项目**：仙侠卡牌抉择游戏（Reigns 式双选），浏览器版迁移 Godot 4.7.2。逻辑层完成 80~90%，表现层持续补齐中。本分支 22 个提交完成了：架构地基 → 资源全量补齐 → 结构规范化 → VFX 代码体系四件大事，并把「凭印象的状态」全部换成了「实测可复现的状态」。

| 维度 | 交接时状态【实测】 |
|---|---|
| 脚本 | 135 个 / 54,360 行（+ `scripts/combat_fx/` 新模块 4 文件） |
| 测试 | 401 个文件（240 个 `SceneTree` 测试），**全量套件首次运行中** |
| 资源 | `content/assets` 4,379 文件 / 1192.5 MB，**JSON 引用口径 100%** |
| 音频 | 33 条引用，32 本地齐全（1 个 HuggingFace URL 数据异常值） |
| 法宝图标 | **唯一确认的真缺口**（源工程无可用图标） |
| 已知失败测试 | **未知**——全量套件结果出来前，历史失败数从未被统计过 |

---

## 2. 已完成的工作及其结果

### 2.1 架构地基（P1~P5，提交 `3add826`~`5522063`）

| 任务 | 结果 | 验证 |
|---|---|---|
| P1 类型系统 | 6 个核心类加 `class_name`（1 → 8） | 完整加载零错 |
| P2 场景按需加载 | `main.gd` 25 个 preload → `STAGE_ROUTES` 27 条路由 | `NONCOMBAT_QI_GATE_ENTRY_PASS` |
| P3 DataService | autoload 共享 Registry（带回退） | 完整加载 + 测试全绿 |
| P4 事件出口 | 13 处 `changed.emit` 统一走 `_emit_event()`，事件类型计数 + 探针 | `EVENT_TYPE_PROBE_PASS types=16` |
| P5 验收 | 迭代报告 4/5 达标（G4 事件常量化未达标，原因见 §5） | 见 `ITERATION_REPORT` |

**副产品发现**：`KARMA_CHOSEN`/`QUEST_CHOSEN` 事件发出但 UI 不处理（待确认设计意图）。

### 2.2 设计与审计文档（`638bc71`、`897e9c4`、`0f58131`）

- `GDD_GODOT_V1.md`（v1.1，11 章）：五层架构 + 12 系统模块分布矩阵 + 迭代路线
- `ARCHITECTURE_REVIEW_GODOT_2026-11-05.md`：节点使用审计 N-1~N-11
- `MIGRATION_SCORECARD.md`：17 子项计分账本（替代二值签收）

### 2.3 资源纠错与全量补齐（`c3cad01`、`d1f0d74`）

| 项 | 此前说法 | 实测结论 |
|---|---|---|
| 卡面 | 「133/174 缺 76%」 | 133 张**全部是同步漏拷**（源工程都有），已同步 → **171/171 = 100%** |
| 场景立绘 | 「230/268 缺 86%」 | 非战斗 269 张**缺 0**；230 是「候选图总数」被误当缺失数 |
| 法宝图标 | 「23/23 缺 100%」 | 法宝只有 **6 个**且无 `icon` 字段；源工程无可用图标 → **真缺口** |
| VFX 帧 | 「591/651 缺 91%」 | JSON 引用口径已 100%（1943 个 `combat/vfx` 帧在漏拷批次里） |
| **全量** | — | 扫描 3,239 个引用文件，补齐 **1,943 个 / 232.9 MB**，现 **100%** |

**根因**：`tools/sync_runtime_content.py` 手工枚举（见 §3 待办第 1 项）。

### 2.4 结构规范化（`ed27ca0`）

- 新目录：`theme/`、`scenes/noncombat/{screens,shared}/`、`assets/items/`
- `assets/` 从 17 个散落子目录收敛为 8 类（battle/characters/demo/fonts/ui/cards/items/third_party）
- 引用修正 21 文件 / 59 处（scripts+scenes），零残留
- **后续补修**：tools 管线脚本 10 个 / 51 处（`d57b9c8`，见 §6 注意事项）

### 2.5 VFX 代码体系（`b3cf7b1`方案、`64fd665` V1、`dfeb183` V3+接线）

| 交付物 | 位置 | 说明 |
|---|---|---|
| 语义路由器 | `scripts/combat_fx/fx_library.gd` | 166 条 semanticVfx id → 6 类模板；不等权重帧时长（快进慢出） |
| 模板构建器 | `scripts/combat_fx/fx_template.gd` | 代码构建 6 模板节点树；粒子配方表；defeat 挂 Dissolve；`set_direction`；`build_impact_frame` |
| HitFlash | `shaders/fx_hit_flash.gdshader` | 受击闪白 |
| HitStopController | `scripts/combat_fx/hitstop_controller.gd` | `time_scale` **全项目唯一拥有者**；light=3帧/heavy=8/crit=12 |
| V3 shader | `shaders/fx_{dissolve,radial_blur,uv_stretch,impact_frame}.gdshader` | 溶解/径向模糊/方向拉伸/全屏反色 |
| **战斗接线** | `scripts/main.gd`（四处小改） | `_on_combat_event` 记录伤害分级 → `_on_contact_frame` 触发 hit-stop；`_damage_tier()` 分级函数 |
| 验收测试 | `tests/combat_fx_v1.gd`、`tests/combat_fx_v3.gd` | 均 PASS |

**全链路已通**：雷关真实战斗中 contact 帧触发 hit-stop，三回合正常走完（`assets_ready=true`）。

### 2.6 基建补缺（`63cc158`、`d57b9c8`）

- `tools/shot_probe.gd`：非 headless 截图（**视觉回归手段**，1280×800 实测可用）
- `tests/fixtures/visual/slot_screen_baseline.png`：存档屏视觉基线
- `tools/run_test_suite.py`：**全量测试 runner**（此前 240 个测试无一键执行）
- 音频总线 `default_bus_layout.tres`（Master/BGM/SFX/Voice/UI）

---

## 3. 全量测试基线（项目史上第一份）与进行中任务

### 3.1 基线【实测，2026-11-05，耗时 2h04m】

```
SCENE_TREE tests: 240
SUITE_DONE pass=161 fail=48 timeout=31 elapsed=7440s
报告: output/test_suite_report.json
```

### 3.2 初步归因（三 buckets，接手方继续）

| Bucket | 数量 | 判断 | 证据 |
|---|---|---|---|
| **A 渲染类 headless 挂** | timeout 31 个中的约 25 个 | `capture_*`(15) / `record_*`(2) / `preview_*` / motion study 类在 headless 下必然挂起，**非代码损坏** | 名称即语义；需 runner 标记 skip 或非 headless 跑 |
| **B tests 旧路径（本轮迁移遗漏，已修）** | fail 中至少 2 个（Parse error 类） | `tests/*.gd` 是第四类消费方，此前批量替换漏了；**27 处已修**（18 文件），残留只剩 `third_party`（未迁移，无需改） | `actor_rig_pose_diagnostic` 修复后 Parse Error 消失 |
| **C 待逐个归因** | fail 46 个 | `noncombat_warning_flow`（业务断言失败）、`noncombat_browser_*`(6)、`noncombat_first_sword_live_battle` 等 live battle、`hd2d_card_contact_regression`、`presentation_integration` 等——**无历史基线可比对**，需逐个查 | 报告 JSON 的 tail 字段 |

**核心业务测试单独跑全绿**（抽样）：`noncombat_content_repository` / `noncombat_qi_gate_entry` / `noncombat_faction_combat` / `noncombat_whitefox_choices` / `noncombat_bazaar_vendor` / `battle_stub_contract` / `battle_stub_route` / `combat_fx_v1` / `combat_fx_v3` / `audio_bus_layout`。

### 3.3 进行中/后续

1. Bucket C 逐个归因（建议：抽 5 个先查，区分「历史遗留」与「本轮引入」——后者优先修）
2. runner 改进：渲染类测试加 skip 标记或 `--rendering-driver` 区分
3. 修复后重跑全量，收敛 FAIL/TIMEOUT 数

其余：无。

---

## 4. 待办事项与优先级（2026-11-05 复核版）

> 优先级原则：**防复发 > 消灭静默失效 > 建立可验证流程 > 增强**。此顺序经过两轮质疑修正，理由见 §5 决策 D10。

| 优先级 | 任务 | 说明 | 前置 |
|---|---|---|---|
| **P0-1** | 处理全量测试结果 | 见 §3.1；任何 FAIL 先归因再修 | 全量套件跑完 |
| **P0-2** | T5 同步脚本三段式改造 | `tools/sync_runtime_content.py` L69-290 手工枚举 → `collect_refs()/resolve()/report()`；1,943 漏拷的根因；验收：`--dry-run` ≈3239 引用、18 条别名不丢、幂等 | 无 |
| **P1-1** | T3 事件清单扩展 | 探针 `noncombat_event_type_probe.gd` 跑 体修/丹修/法修/转世 路线，合并 `event_type_report()` 出全量清单 | 无 |
| **P1-2** | G4 事件常量化 | 基于全量清单把 7 处 `event.get("type")==` 裸字符串改常量；顺带处理 `KARMA_CHOSEN`/`QUEST_CHOSEN` 静默忽略 | P1-1 |
| **P1-3** | T1 抽 `slot_screen.tscn` | 截图基线已备（`tests/fixtures/visual/`）；验证「基线→改造→比对」方法论 | 无 |
| **P2-1** | ContentRepository 共享收尾 | 查清 `build_index()` 调用时序与 `_source_meta` 依赖，补共享或关闭此项 | 无 |
| **P2-2** | T2 抽 `name_screen.tscn` | T1 方法论复用 | T1 |
| **P2-3** | juice 增强 | 屏幕震动系统（通道唯一拥有者）、加载屏 shader 预暖、五修路元素色 | V1/V3 已就位 |
| **P3-1** | 法宝图标 | **阻塞在美术**：4 张按槽位（armor/weapon/artifact/accessory）→ `assets/items/`；出图后一次性做「加 `icon` 字段 + UI 读取」 | 美术 |
| **P3-2** | T4 `noncombat_domain` 拆 5 Director | 6,476 行 / 62 扇出；独占执行，禁止并行改动 | 全量测试基线 |
| **P3-3** | VFX 素材重绘（V4） | 163 条 `finalArtApproved` 全 false，**评审前不动** | 美术评审 |

---

## 5. 重要决策与原因说明

| # | 决策 | 原因 |
|---|---|---|
| D1 | `texture_for()` 缺失返回 **null** 不改 | 5 处 `duel_stage_*` 用 `== null` 判定资源可用性；改返回占位图会让战斗资源缺失被静默掩盖。占位只在 `_art_texture()` wrapper |
| D2 | BattleStub 必须过 `validate_result()` | 桩与真实战斗同契约，否则接真战斗时全崩 |
| D3 | `battle_stub_mode` 默认 `false` | 生产走真实战斗 |
| D4 | 卡面 133 张直接补拷而非等美术 | 逐张核对证明全部在源工程，属同步漏拷 |
| D5 | `main.gd` 场景改路由表不用 preload | 25 个 PackedScene 编译期全加载；新增 stage 改路由表即可（开闭原则） |
| D6 | 事件常量化暂缓、先建探针 | 事件类型由 79 个 `_commit_encounter_transition` 调用点分散传参，117 个大写字符串混 phase/卡 ID，无清单就改 100+ 处 = 高概率静默失效 |
| D7 | hit-stop 用 `time_scale=0.05` 而非 0 | 保 GPUParticles2D 继续走，视觉不断电；`_exit_tree` 强制恢复 |
| D8 | VFX 六模板参数化而非 166 个手搓场景 | 6 类动作 × 配置驱动，语义层（JSON）保留为策划资产 |
| D9 | V4 素材重绘等美术评审 | 163 条 `finalArtApproved=false`，评审前重绘 = 返工 |
| D10 | 待办优先级「防复发>欠账>增强」 | 1943 漏拷事故证明：手工流程的坑比引擎能力缺口杀伤力大；T5 因此排第一（两轮质疑修正后的结论） |
| D11 | 立绘结构（B3）降级为条件触发 | 实测 `animatedMedia` 仅 3 条且全为卡面动效，268 处场景立绘 0 帧序列——资产没做之前做结构 = 建永远走不到的分支 |
| D12 | 战斗接线选 `contact_frame` 信号 | 它已是 contact 帧时刻的权威信号（`main.gd` 已连接），最小侵入；不动 `duel_stage_*` 结构 |

---

## 6. 已知问题与注意事项

### 6.1 数据勘误（历史错误数字，引用前先查此表）

| 历史表述 | 更正后 |
|---|---|
| 卡面 `133/174 缺 76%` | 已同步，**171/171 = 100%** |
| 场景立绘 `230/268 缺 86%` | 非战斗 **269/269 = 100%**（230 是候选数不是缺失数） |
| 法宝图标 `23/23 缺 100%` | 法宝 6 个、无 `icon` 字段、源工程无图标 → **真缺口** |
| VFX `591/651 缺 91%` | 引用口径已 100%；651 是设计规划数 |
| 「86% 缺失根因是同步脚本」 | 根因判断对，但漏拷的是 **1,943 个战斗演出帧 + 133 卡面**，不是立绘 |

### 6.2 工程坑（全部实际踩过）

| # | 坑 | 正确做法 |
|---|---|---|
| 1 | **大资源变更后 `--quit-after` 中断导入**：`.import` 在但 `.ctex` 缺 → `load()` 静默 null | 必须跑 `"$GODOT" --headless --path . --import`（实测 2m16s） |
| 2 | `--check-only` 不解析全局类缓存 | 加 `class_name`/autoload 后必跑 `--editor --quit` 再 `--quit-after 5` |
| 3 | `replace_all` 误伤刚写的 wrapper → 无限递归 | 替换前确认新模式不命中新代码 |
| 4 | `var x: RefCounted` 下 `var y := registry.f()` 推断失败 | 显式标 `var y: Texture2D = ...` |
| 5 | `art_rect`（TextureRect）不能换 `AnimatedSprite2D` | 会丢 `custom_minimum_size` 等 Control 属性；用 Control 容器 + 内部 Sprite |
| 6 | `.tscn`/`.tres` 不能写注释；不手写 `uid` | 解析器不支持；让引擎生成 |
| 7 | GPUParticles2D 的 `visibility_rect` 默认太小 | 模板已放大 1536²；新模板照做 |
| 8 | 按名查找的节点（`get_node("SeqLayer")`）测试构造时必须命名 | 否则读回 nil → `float(nil)` 报奇怪错误 |
| 9 | 迁移影响面 = ①scripts+scenes ②tools 管线 ③导出配置 | 本轮漏了②（10 脚本 51 处），后补 |
| 10 | 音频引用**不带 `assets/` 前缀**（`AUDIO_ROOT` 拼接） | 资源扫描口径必须含两类，否则音频全漏 |
| 11 | printf/heredoc 里 `%` 会被吞 | 转义 `%%` 或用引号包裹 |
| 12 | 测试是 `extends SceneTree` + `_initialize()` | 不是 Node + `_ready()` |

### 6.3 运行时注意事项

- `Engine.time_scale` **只允许 `HitStopController` 写**（通道所有权）；新增系统不得触碰
- 同屏特效 ≤ 3 组、每组粒子 ≤ 64；首次 shader 编译卡帧 → 上线前加加载屏预暖（未实现，见 §4 P2-3）
- `content/assets`（1.2GB）与 `assets`（1.7GB）**不入 git**；新环境需从源工程同步或取发布包
- 回退后若报 `Could not find type`，重跑 `--editor --quit` 重建缓存

---

## 7. 文件与代码位置索引

### 7.1 新增模块（本分支产出）

| 路径 | 职责 | 关键入口 |
|---|---|---|
| `scripts/combat_fx/fx_library.gd` | 语义路由器 | `route_key(id)` / `frame_paths(id)` / `frame_durations(id)` |
| `scripts/combat_fx/fx_template.gd` | 模板构建器 | `build(kind, frames, durations)` / `set_direction(node, rad)` / `build_impact_frame()` |
| `scripts/combat_fx/hitstop_controller.gd` | hit-stop 唯一拥有者 | `trigger(tier)` / `tier_frames(tier)` / `cancel()` |
| `shaders/fx_hit_flash.gdshader` | 受击闪白 | `flash_strength` |
| `shaders/fx_dissolve.gdshader` | 消散 | `dissolve_progress` + `noise_tex` |
| `shaders/fx_radial_blur.gdshader` | 径向模糊 | `strength` / `blur_center` |
| `shaders/fx_uv_stretch.gdshader` | 方向拉伸 | `direction` / `stretch` |
| `shaders/fx_impact_frame.gdshader` | 全屏反色 | `intensity` / `invert` |
| `autoload/data_service.gd` | Registry 共享 | `registry_or_new()` |
| `tools/run_test_suite.py` | 全量测试 runner | `python tools/run_test_suite.py` |
| `tools/shot_probe.gd` | 截图探针 | 改 `TARGET` 常量截任意屏 |
| `tests/combat_fx_v1.gd` / `v3.gd` | VFX 验收 | headless 直跑 |
| `tests/battle_stub_route.gd` / `contract.gd` | 桩端到端/契约 | 同上 |
| `tests/noncombat_event_type_probe.gd` | 事件类型探针 | 同上 |
| `tests/fixtures/visual/slot_screen_baseline.png` | 视觉基线 | T1 比对用 |

### 7.2 关键修改文件

| 路径 | 本分支改动 |
|---|---|
| `scripts/main.gd` | `STAGE_ROUTES` 路由表 + `_instantiate_stage()` + hit-stop 接线（`hitstop`/`_pending_damage_tier`/`_damage_tier()`/`_on_contact_frame`） |
| `scripts/noncombat_opening_ui.gd` | `_art_texture()` 占位 wrapper（11 处）+ `battle_stub_mode` + DataService 取用 |
| `scripts/runtime_data_registry.gd` | `class_name` + 缺失登记告警 + `placeholder_texture()` + `sprite_frames_for` 逐帧容错 |
| `scripts/noncombat_domain.gd` | `class_name` + `_emit_event()` 出口统一 + `event_type_report()` |
| `project.godot` | `[autoload] DataService` |
| `default_bus_layout.tres` | 5 条音频总线 |
| `scenes/`、`tools/*.py` | 引用路径修正（59 + 51 处） |

### 7.3 文档索引

| 文档 | 用途 |
|---|---|
| **本文档** | 总纲入口 |
| `PROJECT_HANDBOOK_2026-11-05.md` | 维护手册（目录结构/使用/维护/排错 9 章） |
| `GDD_GODOT_V1.md` | 设计 + 架构主文档（11 章） |
| `ASSET_INDEX_2026-11-05.md` | 素材索引（目录/别名/缺口/检索） |
| `HANDOFF_FINAL_2026-11-05.md` | 详细交接（12 章，含数据纪律） |
| `HANDOFF_TO_CODEX_2026-11-05.md` | 任务交接（T1~T6 细节步骤） |
| `VFX_MIGRATION_PLAN_2026-11-05.md` | VFX 方案（§3 四层体系/§4 路线） |
| `ASSET_AUDIT_VERIFIED_2026-11-05.md` | 资源核对与纠错 |
| `ARCHITECTURE_REVIEW_GODOT_2026-11-05.md` | 架构审计（N-1~N-11） |
| `MIGRATION_SCORECARD.md` | 子项进度账本 |
| `ITERATION_REPORT_2026-11-05.md` | 架构地基迭代验收 |
| `TASK_PLAN_NONCOMBAT_2026-11-05.md` | 12 任务/4 包原始方案 |

---

## 8. 快速上手（接手 30 分钟）

```bash
GODOT="<repo>/.godot-toolchain/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe"
P="<repo>/godot"

# 1. 重建缓存（必做）
"$GODOT" --headless --path "$P" --editor --quit
# 2. 完整加载
"$GODOT" --headless --path "$P" --quit-after 5
# 3. 核心测试四连
"$GODOT" --headless --path "$P" --script "res://tests/noncombat_content_repository.gd"
"$GODOT" --headless --path "$P" --script "res://tests/combat_fx_v1.gd"
"$GODOT" --headless --path "$P" --script "res://tests/combat_fx_v3.gd"
"$GODOT" --headless --path "$P" --script "res://tests/noncombat_qi_gate_entry.gd"
# 4. 截图看界面
"$GODOT" --path "$P" --script "res://tools/shot_probe.gd"
# 5. 全量套件（如需复跑）
python "$P/tools/run_test_suite.py" --timeout 120
```

**第一个开发决策点**：§3.1 的全量结果处理。之后按 §4 顺序推进。

---

**文档版本**：v1.0  
**编制日期**：2026-11-05 12:25  
**对应 HEAD**：`d57b9c8`（22 commits on `remedy/noncombat-p0-2026-11-05`）  
**修订触发**：全量测试结果出来 / T5 完成 / 抽屏完成
