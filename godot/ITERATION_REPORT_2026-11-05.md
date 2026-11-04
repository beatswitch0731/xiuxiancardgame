# 架构地基迭代 · 验收报告

| 项 | 内容 |
|---|---|
| 报告日期 | 2026-11-05 |
| 对应任务书 | `ITERATION_PLAN_2026-11-05.md`（5 阶段） |
| 迭代起点 | `0f58131` |
| 迭代终点 | `0131075` |
| 分支 | `remedy/noncombat-p0-2026-11-05` |
| **总体结论** | **部分完成：5 项目标达成 4 项，G4 未达标** |

---

## 一、结论先说

**4 项达标，1 项未达标。**

未达标的是 G4（消除裸字符串事件比较）。原因是实测发现改动规模远超预估（不是 13 处，而是 79 个调用点分散传参 + 117 个大写字符串混合了 phase/卡 ID/动作名），完整常量化需改 100+ 处且无测试全覆盖。**按任务书纪律，改用一个零风险且能产出真实证据的替代方案**，而不是硬推一个会引入静默失效的改造。

按任务书 §6 完成判据：「任一项不达标，迭代状态为**部分完成**」。本报告如实标注。

---

## 二、目标达成对照

| # | 目标 | 改前 | 改后 | 验证方式 | 状态 |
|---|---|---|---|---|---|
| **G1** | 核心类具名类型 | `class_name` = **1** | **8** | `grep -c "^class_name"` | ✅ 达标（目标 ≥7） |
| **G2** | 场景按需加载 | `main.gd` preload **25** 个场景 | **0** | `grep -c 'preload("res://scenes'` | ✅ 达标 |
| **G3** | 数据服务单例 | Registry 每 UI 各 new | 生产共享 1 份，测试可回退 | 代码审查 + 测试通过 | ✅ 达标（限 Registry） |
| **G4** | 事件类型可编译期校验 | 裸字符串 **7** 处 | **仍 7 处** | `grep -c 'event.get("type") == "'` | ❌ **未达标** |
| **G5** | 无回归 | — | 6 项测试全绿 | 见 §4 | ✅ 达标 |

---

## 三、分阶段交付

### P1｜类型系统落地（提交 `3add826`）

**改动**：6 个核心类加 `class_name`。

| 文件 | 类名 |
|---|---|
| `noncombat_domain.gd` | `NoncombatDomain` |
| `noncombat_content_repository.gd` | `NoncombatContentRepository` |
| `runtime_data_registry.gd` | `RuntimeDataRegistry` |
| `noncombat_opening_ui.gd` | `NoncombatOpeningUI` |
| `combat_domain.gd` | `CombatDomain` |
| `noncombat_run_session.gd` | `NoncombatRunSession` |

**证据**：`class_name` 计数 1 → 8（含原有 `BattleStub` 与 P3 新增 `GameDataService`）。

---

### P2｜场景按需加载（提交 `9728076`）

**改动**：
- 删除 25 个 `const XxxStageScene = preload(...)`
- 新增 `const STAGE_ROUTES`（27 条 key → 路径）
- 25 个 `elif` 分支改为只决定 `stage_key`
- 新增 `_instantiate_stage(key)`：未命中或加载失败 `push_error` + 返回 null

**证据**：
```
preload 场景 25 → 0
残留 StageScene. 引用 → 0
路由条目 27（25 原 preload + hd2d + pixel_dungeon）
NONCOMBAT_QI_GATE_ENTRY_PASS 全项
MIGRATED_RUNTIME_READY stage=source_2d assets_ready=true
```
最后一行证明真实战斗舞台经路由表成功加载，不是只通过语法检查。

---

### P3｜数据服务共享（提交 `1356ae7`）

**改动**：
- 新增 `autoload/data_service.gd`（`GameDataService`）
- `project.godot` 加 `[autoload] DataService`
- `noncombat_opening_ui._ready()` 优先取 `/root/DataService`，未加载时回退自建

**范围收缩（须说明）**：只共享 `RuntimeDataRegistry`。`ContentRepository` 有 `_indexed` 状态且 `read_module` 依赖 `build_index` 填充的 `_source_meta`，初始化时序未完全确认，**不纳入本轮**以免改变启动顺序。

**证据**：
```
8 个 class_name 全部进入全局类缓存
完整项目加载零 SCRIPT ERROR
NONCOMBAT_CONTENT_REPOSITORY_PASS（数字与基线一致）
```

---

### P4｜事件出口统一化 + 探针（提交 `0131075`）

**原计划调整**（这是本次唯一未达标项，过程必须完整交代）：

任务书写的是「19 个事件类型全部常量化，消除裸字符串比较」。实测后发现三件事推翻了预估：

1. 事件类型不只来自 13 处 `changed.emit`，而是由 **79 个** `_commit_encounter_transition(state, "EVENT_TYPE")` 调用点传参
2. domain 内大写字符串共 **117 个**，混着 `state.phase`（`NORMAL_PENDING`）、战斗动作（`END_TURN`）、卡 ID，无法可靠自动区分
3. 无任何测试覆盖全部 19 个接收分支

完整常量化 = 改 100+ 处 + 无测试兜底 = 高概率引入静默失效。

**实际交付**：
- 13 处 `changed.emit(...)` 统一走 `_emit_event(event)`，出口记录「类型 → 次数」，type 为空时 `push_error`
- 新增 `event_type_report()`
- 新增 `tests/noncombat_event_type_probe.gd`

**探针实测（一条真实剑修路线的 16 种事件）**：
```
BATTLE_REQUEST_READY x2, BATTLE_RESULT_ACKNOWLEDGED x2,
BATTLE_RESULT_COMMITTED x2, CHOICE_COMMITTED x3,
DESTINY_WHEEL_FLIPPED x1, ENCOUNTER_AVOIDED x2, ENCOUNTER_WARNING x2,
FLOW_CARD_READY x14, HINT_CHOSEN x1, KARMA_CHOSEN x4, MARKET_SKIPPED x2,
MENTOR_CHOSEN x2, MILESTONE_CHOSEN x4, QUEST_CHOSEN x3,
RESULT_ACKNOWLEDGED x3, STARTED x1
```

**探针直接发现**：`KARMA_CHOSEN`（4 次）与 `QUEST_CHOSEN`（3 次）不在 UI 的 19 个 `event.get("type")` 分支内，被 `_on_opening_changed` 静默忽略。是否为设计如此需行为确认，但**在此之前没有任何手段能发现这件事**。

---

### P5｜全量回归（本报告）

见 §4。

---

## 四、回归证据汇总

全部在本机 Godot 4.7.2 headless 实跑：

| # | 测试/检查 | 结果 |
|---|---|---|
| 1 | 完整项目加载（`--quit-after 3`） | **零 SCRIPT ERROR** |
| 2 | `noncombat_content_repository` | `PASS modules=75 cards=588 quests=6 threads=12 scene_refs=553 unlisted=0` |
| 3 | `noncombat_qi_gate_entry` | `PASS public=true quota=true warning=true pending=true survival=true counter=true plan_order=true return=true replay=true` |
| 4 | `noncombat_bazaar_vendor` | `PASS open=true action=true close=true replay=true rollback=true` |
| 5 | `noncombat_whitefox_choices` | `PASS first=2 second=2 npc=true replay=true` |
| 6 | `battle_stub_contract` | `PASS` |
| 7 | `battle_stub_route` | `PASS pending= after=breakthrough_reward phase=BATTLE_RESULT_PENDING` |
| 8 | `noncombat_event_type_probe` | `PASS types=16` |

**数字与基线一致性**：`content_repository` 的 `modules=75 cards=588 quests=6 threads=12 scene_refs=553 unlisted=0` 与迭代前完全一致，说明数据层未受影响。

---

## 五、两个必须记录的意外发现

### 5.1 `--check-only` 会误报通过

P1 加完 6 个 `class_name` 后，`--check-only --script` 六次全过。但在 P3 加 autoload 时，完整项目加载报：

```
Parse Error: Could not find type "RuntimeDataRegistry"
ERROR: Failed to instantiate an autoload
```

原因：**`--check-only` 单文件模式不解析全局类缓存**。真正生效需要：

```bash
godot --headless --path . --editor --quit      # 重建 global_script_class_cache.cfg
godot --headless --path . --quit-after 3       # 完整加载复验
```

本次缓存 1986 → 3427 字节，8 个 `class_name` 才真正注册。

**这条要写进后续所有验证流程**：`--check-only` 只能验证单文件语法，不能验证跨文件类型引用。

### 5.2 架构文档中「立绘改 AnimatedSprite2D」的建议不成立

实测 `noncombat_opening_ui.gd:103` 的 `art_rect` 是 `TextureRect`，用法包含 `custom_minimum_size`、`size_flags_horizontal`、`size_flags_stretch_ratio` —— 全是 **Control 布局属性**。`AnimatedSprite2D` 是 `Node2D`，没有这些属性。

正确做法是「Control 容器 + 内部 `AnimatedSprite2D`」或「`TextureRect` + `AnimationPlayer` 驱动 texture 轨道」，两者都要重构布局，不是换节点类型。该建议已在任务书 §5.1 记录修正。

---

## 六、回退方式

每个阶段独立提交，可单独回退：

```bash
cd E:/4e/游1/2026-06-27-05-40-58/xiuxian-card-game
git log --oneline 0f58131..HEAD        # 查看 4 个提交
git revert 0131075                     # 退 P4
git revert 1356ae7                     # 退 P3
git revert 9728076                     # 退 P2
git revert 3add826                     # 退 P1
```

整体回到迭代前：

```bash
git reset --hard 0f58131
```

**注意**：P3 新增了 `[autoload]` 和 `.godot/global_script_class_cache.cfg`。回退后若 Godot 报类找不到，需重新跑一次 `--editor --quit` 重建缓存。

---

## 七、遗留与建议

### 7.1 本迭代遗留

| 项 | 原因 | 建议 |
|---|---|---|
| G4 事件常量化 | 规模超预估（79 调用点 + 117 字符串） | 先用探针跑更多路线，导出完整事件清单，再一次性常量化 |
| `ContentRepository` 共享 | 初始化时序未确认 | 先查清 `build_index` 由谁在何时调用 |
| 抽 5 个静态屏为 `.tscn` | 无视觉回归手段 | 需与截图比对工具配套 |

### 7.2 探针的后续用法

`noncombat_event_type_probe` 可以直接扩展成「跑 N 条路线，汇总所有事件类型」，产出完整清单后再做常量化——**那时改的是有据可依的清单，而不是凭猜测定 API**。

建议下一步：

```gdscript
# 用 3~5 条不同路线（剑修/体修/丹修/法修/转世）各跑一次，
# 合并 event_type_report()，得到全量事件清单
```

---

## 八、完成情况判定

| 判据（任务书 §6） | 实际 |
|---|---|
| G1~G5 五项全部达标 | ❌ 4/5（G4 未达标） |
| 每项有「改前值 → 改后值 → 验证命令」三列实测记录 | ✅ 见 §2 |
| 任一项不达标须列出未达标项与原因 | ✅ 见 §3 P4 |

**迭代状态：部分完成（4/5）**

不把 G4 标为完成，是因为裸字符串确实还在。用出口诊断替代它是有价值的，但**不等于完成了常量化**。这条必须留着。

---

**报告版本**：v1.0  
**编制日期**：2026-11-05  
**提交范围**：`3add826` → `0131075`（4 个阶段提交 + 本报告）
