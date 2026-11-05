# 交接文档 · 致 codex

| 项 | 内容 |
|---|---|
| 交接日期 | 2026-11-05 |
| 交接人 | WorkBuddy（前序执行者） |
| 接手方 | codex |
| 工程根 | `E:/4e/游1/2026-06-27-05-40-58/xiuxian-card-game/godot` |
| 分支 | `remedy/noncombat-p0-2026-11-05` |
| 当前 HEAD | `897e9c4`（本地 = 远程） |
| 基线 tag | `baseline-2026-11-05-pre-noncombat-remedy` / `c268384` |

---

## 一、一句话交代现状

> 非战斗逻辑层已跑到 80~90%，表现层停在 10~25%。架构地基（类型/加载/音频）已补齐，**UI 仍在用代码 `add_child` 拼装（32/47 场景是单节点）**，这是当前最大的结构性债务。

---

## 二、环境与工具（直接可用，不必重装）

### 2.1 Godot 可执行文件

```
E:/4e/游1/2026-06-27-05-40-58/xiuxian-card-game/.godot-toolchain/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe
```

机器：Windows / RTX 3060 Laptop / Vulkan 1.4.303 / Forward+ 可用。

### 2.2 三条命令模板

```bash
GODOT="<上面的路径>"
P="E:/4e/游1/2026-06-27-05-40-58/xiuxian-card-game/godot"

# ① 语法检查（单文件，注意：不解析全局类缓存，见坑 1）
"$GODOT" --headless --path "$P" --check-only --script "res://scripts/xxx.gd"

# ② 完整加载（最可靠的编译验证）
"$GODOT" --headless --path "$P" --quit-after 3     # 期望零 SCRIPT ERROR

# ③ 跑测试（测试脚本都是 extends SceneTree）
"$GODOT" --headless --path "$P" --script "res://tests/xxx.gd"
```

### 2.3 截图工具（**已就绪，这是关键能力**）

```bash
"$GODOT" --path "$P" --script "res://tools/shot_probe.gd"
# 输出：godot/output/_shot_probe.png（1280×800）
# 成功标志：SHOT_PROBE_PASS path=... size=(1280, 800)
```

**必须用非 headless 模式**（不加 `--headless`）。已实测成功，画面完整（水墨背景 + 三槽位 + 六个按钮，无占位块）。

`tools/shot_probe.gd` 现加载 `noncombat_opening.tscn`。改造方式：复制一份，改 `TARGET` 常量指向要截的屏，即可做逐像素回归。

**这是抽屏改造（任务 T1/T2）的验收基础。**

---

## 三、已完成（**不要重做**）

| 提交 | 内容 | 关键点 |
|---|---|---|
| `c268384` | 基线冻结（1,557 文件） | tag `baseline-2026-11-05-pre-noncombat-remedy` |
| `3add826` | 6 个 `class_name` | `NoncombatDomain` / `NoncombatContentRepository` / `RuntimeDataRegistry` / `NoncombatOpeningUI` / `CombatDomain` / `NoncombatRunSession` |
| `9728076` | `main.gd` 25 个 preload → `STAGE_ROUTES` 路由表 | 27 条路由，`_instantiate_stage()` |
| `1356ae7` | `DataService` autoload | 共享 Registry，未加载时回退自建 |
| `0131075` | 13 处 `changed.emit` → `_emit_event()` | 出口记录类型，`event_type_report()` |
| `b875a55` | 5 条音频总线 | Master/BGM/SFX/Voice/UI，子总线 0dB |
| `638bc71` / `897e9c4` | GDD v1.0 → v1.1 | `godot/GDD_GODOT_V1.md` 11 章 |

**已落地的能力，别改回去**：

- `runtime_data_registry.texture_for()` **必须保持「缺失返回 null」** —— 5 处 `duel_stage_*` 用 `== null` 判定资源可用性。占位逻辑只在 `noncombat_opening_ui._art_texture()` wrapper 里
- `BattleStub` 产出的结果**必须过 `noncombat_battle_gateway.validate_result()`** —— 不许自造宽松格式
- `battle_stub_mode` 默认 `false` —— 生产走真实战斗

---

## 四、真正的卡点（就这两个）

### 卡点 A：补资产需要美术，不是代码

| 项 | 缺口 | 位置 |
|---|---|---|
| 卡面 | 133 / 174（缺 76%） | `content/assets/combat/cards/` |
| 场景立绘 | 230 / 268（缺 86%） | `content/assets/narrative/` 附近 |
| 法宝图标 | 23 / 23（缺 100%） | `content/assets/icons/` |
| VFX 帧 | 591 / 651（缺 91%） | 且 163 条 `finalArtApproved` **全为 false** |

**你能做的**：改同步脚本让资产进来（`tools/sync_runtime_content.py` 第 69–290 行仍是手工枚举单遭遇 `ENCOUNTER_ID = "enc_trial_sword_swift"`）。**这是唯一根因**——清单外的美术从未进入工程。

**你不能做的**：画图。

**注意**：VFX 591 帧**先别补**，资产未过美术评审，补了必返工。

### 卡点 B：事件类型常量化，缺「全量清单」

`noncombat_opening_ui.gd` 有 7 处 `event.get("type") == "XXX"` 裸字符串，拼错即静默失效。

**为什么上次没做**：事件类型不是集中在 13 处 emit，而是由 **79 个** `_commit_encounter_transition(state, "EVENT_TYPE")` 调用点传参；`noncombat_domain.gd` 内 117 个大写字符串混着 `state.phase`（`NORMAL_PENDING`）、动作名（`END_TURN`）、卡 ID，无法可靠自动区分。改 100+ 处且无测试兜底 = 高概率引入更多静默失效。

**解锁方式**：先跑全量清单。

```bash
# 已有一条探针，走剑修路线，输出 16 种事件
"$GODOT" --headless --path "$P" --script "res://tests/noncombat_event_type_probe.gd"
```

**要做的是**：复制这个探针，换成体修/丹修/法修/转世路线各跑一次，合并 `event_type_report()`，得到全量清单后再常量化。

---

## 五、交接任务（按优先级，每项可直接执行）

### T1｜抽 `slot_screen.tscn`（P0，最高价值）

**目标**：把 `noncombat_opening_ui.gd` 的 `_build_slot_screen()`（L405 起）抽成独立 `.tscn`，脚本只留 `bind(state)` 与信号。

**为什么先做这个**：它是最简单的屏（3 个槽位按钮 + 4 个功能按钮），且**已有截图基线**。

**步骤**：

1. 先截图存档当前状态作为基线
```bash
"$GODOT" --path "$P" --script "res://tools/shot_probe.gd"
cp "$P/output/_shot_probe.png" "$P/output/baseline_slot_screen.png"
```

2. 在编辑器里建 `scenes/noncombat/screens/slot_screen.tscn`（**推荐用编辑器**，不要手写 `.tscn`；若必须手写，遵守：`[gd_scene load_steps=N format=3]` 开头、**不能有注释**、不手写 `uid`）

3. 把 `_build_slot_screen()` 里的节点创建改为 `preload("res://scenes/noncombat/screens/slot_screen.tscn").instantiate()`，脚本暴露 `bind(state: Dictionary) -> void`

4. 截图比对
```bash
"$GODOT" --path "$P" --script "res://tools/shot_probe.gd"
# 与 baseline_slot_screen.png 逐像素比对（允许 ±1 抗锯齿差异）
```

**验收**：
- 截图与基线一致（人眼可辨无差异）
- 场景可 F6 独立运行不崩
- 全量测试仍绿（见 §7 基线）

**风险**：布局错位、焦点顺序变化。缓解：截图比对 + 保留旧代码注释一个版本，出问题 `git revert`。

---

### T2｜抽 `name_screen.tscn`（P0）

同 T1，目标改为 `_build_name_screen()`（L688 起）。**T1 验证方法论可行后再做这个。**

---

### T3｜跑全量事件清单（P0，为 G4 铺路）

**目标**：产出 `EVENT_TYPES` 全量清单，让事件常量化有据可依。

**步骤**：

1. 读 `tests/noncombat_event_type_probe.gd`（已存在，走剑修路线）
2. 复制为 `noncombat_event_type_probe_body.gd` 等，改路线构造（可继承 `noncombat_qi_gate_entry.gd` 复用 `_open_third_alt`）
3. 每条路线跑一次，收集 `EVENT_TYPES` 输出
4. 合并去重，写入 `godot/EVENT_TYPES_INVENTORY.md`
5. 与 `noncombat_opening_ui.gd` 的 19 个分支对照，标出：
   - UI 处理但从未触发（死分支）
   - 发出但 UI 未处理（静默忽略）

**已知发现**：剑修路线下 `KARMA_CHOSEN`（×4）与 `QUEST_CHOSEN`（×3）不在 UI 的 19 个分支内，被静默忽略。**先确认这是否是设计意图**，再决定补分支还是删分支。

**验收**：清单覆盖 ≥ 5 条路线；每条事件有来源（哪个 flow 发出）。

---

### T4｜拆 `VendorDirector`（P1，风险最高，独占执行）

**目标**：从 `noncombat_domain.gd`（6,476 行 / 62 扇出）拆出坊市相关流程。

**承接范围**：坊市 / 鬼市 / 正规坊 / 末课 四类 vendor。

**步骤**：
1. 先跑全量非战斗测试记录基线（见 §7）
2. 新建 `scripts/noncombat_vendor_director.gd`（`class_name VendorDirector`）
3. 把 domain 里 vendor 相关的私有方法与状态迁过去，domain 保留调度
4. **一次只迁一类**（先公开坊市），迁完立即跑全量
5. 独立提交

**验收**：
- `noncombat_domain.gd` 行数下降
- 全量测试断言数不减、全绿
- `NONCOMBAT_BAZAAR_VENDOR_PASS` / `NONCOMBAT_GHOST_*` 仍通过

**风险**：6,476 行文件大范围改动，行为漂移。**期间禁止其他并行改动**。

---

### T5｜同步脚本改全量发现（P1）

**目标**：`tools/sync_runtime_content.py` 第 69–290 行从手工枚举改为三段式（`collect_refs` / `resolve` / `report`）。

**必须保留的既有能力**（别在重写中丢失）：
1. PNG/JPEG 魔数校验与 `.png`→`.jpg` 别名登记（现有 **18 条** `runtimeAliases`）
2. `content/source_manifest.json` 的写入格式
3. 幂等性：重复执行不新增重复别名

**验收**：
- `--dry-run` 报出的 `total_refs` 与审计值 3,092 同量级
- 18 条别名重跑后一条不少
- 产出 `content/asset_migration_report.json`

---

### T6｜补资产（P2，阻塞在美术）

**顺序**（按玩家可见度）：
1. 场景立绘 230 张（开局 60 秒必见）
2. 卡面 133 张（战斗可读性）
3. 法宝图标 23 张
4. VFX 591 帧（**等美术评审**）

**你的部分**：跑 T5 之后，把 `missing_from_source` 清单整理成美术需求单。

---

## 六、已知的坑（12 条，全是实际踩过的）

| # | 坑 | 症状 | 正确做法 |
|---|---|---|---|
| 1 | **`--check-only` 不解析全局类缓存** | 加了 `class_name` 后单文件检查全过，完整加载却报 `Could not find type` | 必须 `--editor --quit` 重建 `.godot/global_script_class_cache.cfg`，再 `--quit-after 3` 复验 |
| 2 | **编辑器未扫描时 autoload 会失败** | `Failed to instantiate an autoload, script does not inherit from Node` | 同上，先重建缓存 |
| 3 | **`registry: RefCounted` 导致类型推断失败** | `var x := registry.texture_for(p)` 报 `Cannot infer the type` | 写 `var x: Texture2D = ...` |
| 4 | **全局替换误伤自己写的 wrapper** | `replace_all` 把 wrapper 内部调用也换了 → **无限递归** | 替换前先确认新模式不会命中新写入的代码 |
| 5 | **`noncombat_opening_ui.gd` 是 2,562 行巨兽** | 改一处影响 6 个屏 | 改前先 `grep -n` 定位，改后跑全部相关屏 |
| 6 | **`art_rect` 不能换成 `AnimatedSprite2D`** | 会失去 `custom_minimum_size` / `size_flags_*`（属 Control 布局） | 正确做法：Control 容器 + 内部 `AnimatedSprite2D`，或 `TextureRect` + `AnimationPlayer` 驱动 texture |
| 7 | **`sprite_frames_for` 已改逐帧容错** | 缺帧会跳过而非整段 null | 别改回去——历史拷贝是逐目录截断的，「全或无」会把局部缺失放大成敌人完全不动 |
| 8 | **`content/assets` 不入 git（897MB）** | 检出后贴图缺失 | 资产需单独同步；`content/data`（9.1MB）才入库 |
| 9 | **`.git` 已 17GB** | 不要往里塞大文件 | 只提交代码与配置 |
| 10 | **测试脚本是 `extends SceneTree`** | 不是 Node，不能用 `_ready` | 用 `_initialize()` |
| 11 | **部分测试超时 600 秒** | 默认 30 秒门禁会误报 | 见 §7，已知超时清单 |
| 12 | **写 shell 命令时 `%` 会被 printf 吞** | 记忆写入被截断 | 用 heredoc 或转义 `%%` |

---

## 七、验收基线（改动前后必须一致）

### 7.1 必跑测试

```bash
"$GODOT" --headless --path "$P" --script "res://tests/noncombat_content_repository.gd"
# NONCOMBAT_CONTENT_REPOSITORY_PASS modules=75 cards=588 quests=6 threads=12 scene_refs=553 unlisted=0

"$GODOT" --headless --path "$P" --script "res://tests/noncombat_qi_gate_entry.gd"
# NONCOMBAT_QI_GATE_ENTRY_PASS public=true quota=true warning=true pending=true survival=true counter=true plan_order=true return=true replay=true

"$GODOT" --headless --path "$P" --script "res://tests/battle_stub_contract.gd"
# BATTLE_STUB_CONTRACT_PASS

"$GODOT" --headless --path "$P" --script "res://tests/battle_stub_route.gd"
# BATTLE_STUB_ROUTE_PASS ... phase=BATTLE_RESULT_PENDING

"$GODOT" --headless --path "$P" --script "res://tests/audio_bus_layout.gd"
# AUDIO_BUS_LAYOUT_PASS buses=5

"$GODOT" --headless --path "$P" --script "res://tests/noncombat_bazaar_vendor.gd"
# NONCOMBAT_BAZAAR_VENDOR_PASS open=true action=true close=true replay=true rollback=true

"$GODOT" --headless --path "$P" --script "res://tests/noncombat_whitefox_choices.gd"
# NONCOMBAT_WHITEFOX_CHOICES_PASS first=2 second=2 npc=true replay=true
```

### 7.2 已知超时测试（默认 30 秒不够，需单独给上限）

| 测试 | 实际耗时 |
|---|---|
| `noncombat_choice_echo_public_seed` | 约 116 秒 |
| `noncombat_faction_combat` | 需 180 秒 |
| `noncombat_faction_natural` | 约 600 秒 |
| `noncombat_q_fellow_outcomes` | > 180 秒 |

**建议**：这批测试应该拆开（GDD §8.3 规定单测 ≤ 120 秒），但拆分本身是独立任务。

---

## 八、禁止事项（会破坏既有基线）

| # | 禁止 | 原因 |
|---|---|---|
| 1 | 改 `texture_for()` 的返回契约 | 5 处战斗场景依赖 `== null` 判定 |
| 2 | 放宽 `validate_result()` | 桩必须过真实校验 |
| 3 | 把 `BattleStub` 的 `battle_stub_mode` 默认值改成 `true` | 生产会走桩、无真实战斗 |
| 4 | 删 `tests/` 下任何测试或改其断言 | 326 个非战斗测试是唯一安全网 |
| 5 | 动 `duel_stage_*`（战斗侧） | 本阶段刻意延后，未验收 |
| 6 | 手写 `.tscn` 的 `uid` 字段 | 让引擎生成 |
| 7 | 在 `.tscn`/`.tres` 里写注释 | Godot 解析器不支持 |
| 8 | `git push --force` | 当前分支已推送，有协作风险 |
| 9 | 把 `content/assets` 加进 git | 897MB，会让仓库爆炸 |

---

## 九、回退方式

```bash
cd E:/4e/游1/2026-06-27-05-40-58/xiuxian-card-game

git log --oneline 0f58131..HEAD    # 看本分支 10 个提交
git revert <hash>                   # 退单个任务
git reset --hard c268384            # 整体回到基线（会丢全部改动）
```

**注意**：回退后若 Godot 报类找不到，需重跑 `--editor --quit` 重建缓存。

---

## 十、参考文档（按重要性）

| 文档 | 用途 |
|---|---|
| `godot/GDD_GODOT_V1.md` | **必读**。11 章，含五层架构、模块分布矩阵、迭代路线 |
| `godot/ITERATION_REPORT_2026-11-05.md` | 上一轮迭代的验收报告（4/5 达标，含 G4 未完成原因） |
| `godot/ARCHITECTURE_REVIEW_GODOT_2026-11-05.md` | 架构审计（N-1~N-11 节点问题，每条含位置与建议） |
| `godot/MIGRATION_SCORECARD.md` | 子项进度账本（17 子项，10 已完成） |
| `godot/NONCOMBAT_FULL_MIGRATION_TASKBOOK.md` | 215KB，N0–N11 阶段定义与全部验收证据 |
| `docs/GODOT_MIGRATION_EXECUTION_TASKBOOK_2026-10-15.md` | 原始 M0–M7 任务书（玩家契约、设计支柱原文） |

---

## 十一、给 codex 的一句话建议

**先做 T1，别先做 T4。**

T1（抽一个屏）能让你在 2 小时内验证「截图基线 → 改造 → 截图比对」这条路走不走得通。走通了，后面 4 个屏是重复劳动。

T4（拆 6,476 行）如果先做，一旦行为漂移，你会在 326 个测试里找不到是哪一处崩的。

---

**文档版本**：v1.0  
**交接时间**：2026-11-05 09:10  
**当前 HEAD**：`897e9c4`
