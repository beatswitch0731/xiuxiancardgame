# 最终交接文档

| 项 | 内容 |
|---|---|
| 文档版本 | v1.0 |
| 交接日期 | 2026-11-05 |
| 交接方 | WorkBuddy（本轮执行者） |
| 接手方 | codex / 后续开发维护者 |
| 工程根 | `E:/4e/游1/2026-06-27-05-40-58/xiuxian-card-game/godot` |
| 分支 | `remedy/noncombat-p0-2026-11-05` |
| 交接时 HEAD | 见文末 §11（本轮提交后） |

---

## 0. 本文档的数据纪律

这份文档里的每个数字都遵循三条规则，接手时请沿用：

| 规则 | 说明 |
|---|---|
| **标注口径** | 凡完成度/覆盖率，必须写明是「JSON 引用口径」「文件计数口径」还是「设计规划口径」 |
| **标注来源** | 数字后给出可复现的统计方式或命令 |
| **区分实测与推断** | 【实测】= 本次扫描/运行直接得出；【推断】= 基于代码语义判断，需实机验证 |

**本轮最重要的教训**：此前多份文档引用了未经复核的历史数字（如「场景立绘缺 86%」），导致后续规划建立在假前提上。凡引用历史数字，先确认它是「候选数」「引用数」「缺失数」还是「设计目标数」。

---

## 1. 交接摘要

### 1.1 本轮完成的三件事

| # | 任务 | 结果 |
|---|---|---|
| 1 | 基础搭建 | 建成 `theme/`、`scenes/noncombat/{screens,shared}/`、`assets/items/` 规范目录；`assets/` 从 17 个散落子目录收敛为 8 类 |
| 2 | 素材迁移 | 82 处 `res://assets/` 引用全部修正（21 文件 / 59 处替换），零残留 |
| 3 | 全量补齐 | 从源工程补齐 **1,943 个**漏拷资源（232.9 MB），JSON 引用口径覆盖率 **1296/3239 → 3239/3239 = 100%** |

### 1.2 当前项目状态【实测】

| 维度 | 数值 | 口径 |
|---|---|---|
| 脚本 | 135 个 / 54,360 行 | `scripts/**/*.gd` |
| 场景 | 47 个 | `scenes/*.tscn` |
| 测试 | 401 个 | `tests/*.gd` |
| 数据 | 75 模块 / 588 卡 / 553 场景引用 | `noncombat_content_repository` 输出 |
| 资源（运行时） | 4,379 文件 / 1192.5 MB | `content/assets/` 文件计数 |
| 资源（原生） | 2,881 文件 / 1695.4 MB | `assets/` 文件计数 |
| 资源覆盖率 | **3239 / 3239 = 100%** | JSON 引用口径，经 18 条别名解析 |
| 卡面 | **171 / 171 = 100%** | `battle_cards[].cardArt.image` 唯一值 |
| 非战斗场景图 | **269 / 269 = 100%** | `sceneImage` 中 `assets/cards/*` 唯一值 |
| 法宝图标 | **0 / 6** | `equipment.json` 6 件法宝，`icon` 字段 0 个 |

---

## 2. 数据勘误（必读）

以下数字曾在历史文档与对话中出现，**均已复核并更正**。接手时请以本表为准。

| 历史表述 | 复核结论 | 更正后 | 依据 |
|---|---|---|---|
| 卡面 `133/174（缺 76%）` | 表述歧义（133 是缺失数，非已有数） | 唯一图 171，核对时存在 38 / 缺 133；**现已 171/171 = 100%** | `ASSET_AUDIT_VERIFIED_2026-11-05.md` |
| 场景立绘 `230/268（缺 86%）` | **完全错误** | 唯一 `sceneImage` 342，缺 4（全在战斗侧）；非战斗 269 张**缺 0** | 同上 |
| 法宝图标 `23/23（缺 100%）` | 数量与性质都错 | 法宝 **6 个**，`icon` 字段 **0 个**；源工程无可用图标 → **真缺口** | 同上 + `ASSET_INDEX_2026-11-05.md` §六 |
| VFX 帧 `591/651（缺 91%）` | 口径不同，不可直接套用 | JSON 引用口径下 VFX 相关文件已 100% 存在；`651` 属设计规划数，非引用数 | 全量扫描结论 |
| 「86% 立绘缺失的唯一根因是同步脚本」 | 因果判断错 | 根因是「同步脚本手工枚举导致漏拷」，但漏拷的是 **1,943 个战斗演出帧 + 133 张卡面**，不是立绘 | 全量扫描 |

### 2.1 「230」的真实来源

不是缺失数，是 N0 阶段的**「非战斗候选图」目录统计数**（含未挂接候选）。原始记录：

> 此前「230 张非战斗候选图」含 `assets/cards/combat/*` 下 55 张战斗卡图。目录工具现同时排除…非战斗候选为 **175 张**。

230 是候选总数，175 是排除战斗后的候选数，两者均非缺失数。

### 2.2 表述规范

缺口一律写作 **`存在/总数（缺 N）`**。禁止写「缺N/总数」——会被误读为「已有 N」。

---

## 3. 项目结构

### 3.1 顶层

```
godot/
├─ project.godot              引擎配置（主场景 / autoload / 渲染）
├─ default_bus_layout.tres    5 条音频总线
├─ export_presets.cfg         导出配置
├─ autoload/                  全局服务（DataService）
├─ scripts/                   135 个 GDScript
├─ scenes/                    47 个场景
│  └─ noncombat/
│     ├─ screens/             （空，待抽 5 屏）
│     └─ shared/              （空，待抽复用组件）
├─ theme/                     （空，待填充）
├─ shaders/                   着色器
├─ content/                   运行时内容（唯一权威）
│  ├─ data/                   ★ 77 个 JSON / 9.1 MB
│  ├─ assets/                 ☆ 运行时贴图 / 1192.5 MB
│  ├─ media_frames/           ☆ 抽帧中间产物
│  ├─ source_media/           ☆ 源媒体
│  ├─ derived/                ★ 派生资源
│  └─ source_manifest.json    ★ 别名表（18 条）
├─ assets/                    ☆ 手工原生资源 / 1695.4 MB
│  ├─ battle/  characters/  demo/  items/
│  └─ fonts/  ui/  cards/  third_party/
├─ tests/                     401 个测试 + fixtures/visual/ 基线截图
├─ tools/                     工具脚本
├─ output/                    ☆ 截图与运行产物
├─ art_source/ art_direction/ dist/   ☆ 不入包
└─ addons/                    编辑器插件
```

**★ 入库 / ☆ 不入库**：`.git` 已 17GB，只有代码、配置、数据、文档入库。

### 3.2 两套资源根（最易混淆处）

| 根 | 用途 | 引用方式 |
|---|---|---|
| `content/assets/` | 来自源 JSON 的图（卡面、场景图、战斗帧、音频） | `texture_for("assets/xxx")` |
| `assets/` | Godot 原生资源（`.glb` / `.ttf` / `.tres`） | `res://assets/xxx` |

**判断规则**：源 JSON 里出现 `assets/xxx` → 第一个根；Godot 原生资源 → 第二个根。放错即 404。

### 3.3 assets/ 分类映射（2026-11-05 迁移）

| 新目录 | 迁入的旧目录 |
|---|---|
| `battle/` | `hd2d`、`25d`、`undercurrent_pixel_v1`、`source_first_fight`、`battle_actor_style_v1` |
| `characters/` | `actor_image3d_mvp`、`actor_motion_lab_v1`、`actor_wearable_v2`、`modular_pixel_actor_v1`、`actor_candidates`、`actors` |
| `demo/` | `equipment_demo`、`equipment_swap_mvp` |
| 原位保留 | `fonts/`、`ui/`、`cards/`、`third_party/`、`items/` |

引用分布（共 82 处）：`battle/` 30、`characters/` 28、`fonts/` 17、`ui/` 6、`demo/` 1。

---

## 4. 模块职责

### 4.1 五层架构与四条纪律

```
L5 表现  NoncombatOpeningUI / DuelStage* / *_ui       只读领域，不持规则
L4 接口  BattleGateway / BattleReturnFlow / BattleStub  跨子系统契约
L3 领域  NoncombatDomain / CombatDomain                权威状态，禁止 extends Node
L2 流程  约 60 个 noncombat_*_flow / *_policy          可独立构造测试
L1 数据  ContentRepository / RuntimeDataRegistry       JSON + SHA + 别名
```

| # | 纪律 |
|---|---|
| 1 | L1/L2/L3 禁止 preload `.tscn` |
| 2 | L3 禁止 `extends Node` |
| 3 | L5 禁止直接调 L2 的状态变更方法 |
| 4 | Autoload 禁止放玩法逻辑 |

### 4.2 核心文件

| 文件 | 行数 | 职责 | 风险 |
|---|---|---|---|
| `noncombat_domain.gd` | 6,476 | 非战斗权威状态机 | 极高（62 扇出） |
| `noncombat_opening_ui.gd` | 2,562 | 全部非战斗界面（6 屏） | 高（132 处 `.new()`） |
| `noncombat_battle_gateway.gd` | 1,918 | 战斗邀约/请求/战果校验 | 高 |
| `main.gd` | 928 | 战斗场景总装 + `STAGE_ROUTES` 路由 | 中 |
| `noncombat_content_repository.gd` | 1,068 | JSON 索引 + SHA | 低（只读） |

### 4.3 12 个一级系统

S1 卡牌引擎 / S2 修路 / S3 境界 / S4 因果 / S5 同伴 / S6 NPC / S7 势力 / S8 坊市 / S9 秘境 / S10 死亡转世 / S11 战斗（刻意延后） / S12 图鉴。

完整「系统 → 脚本 → 场景 → 数据 → 测试」矩阵见 `GDD_GODOT_V1.md` §5.1。

### 4.4 Autoload

| 名称 | 职责 | 状态 |
|---|---|---|
| `DataService` | 共享 `RuntimeDataRegistry` | ✅ 已实现，带回退 |
| `AudioBus` | 五总线音量 | ⚠️ 总线已建，控制未接 |
| `GameSettings` | 阅读偏好 | ⚠️ 存在但是实例非单例 |

取用必须带回退（`--script` 测试模式不加载 autoload）：

```gdscript
var data_service := get_node_or_null("/root/DataService") as GameDataService
if data_service != null:
    registry = data_service.registry_or_new()
else:
    registry = RuntimeDataRegistry.new()
```

---

## 5. 资源状态

### 5.1 覆盖率【实测】

```
引用唯一文件: 3239 / 存在: 3239 / 缺: 0 / 覆盖率: 100.00%
```

口径：遍历 `content/data/**/*.json` + `source_manifest.json`，收集所有 `assets/` 开头且带图片/音频扩展名的字符串，经 18 条 `runtimeAliases` 解析后核对 `content/` 下实际文件。

**本轮补齐**：1,943 个 / 232.9 MB，分布：

| 目录 | 个数 |
|---|---|
| `combat/enemy_actions/` | 731 |
| `combat/vfx/` | 609 |
| `combat/protagonist/` | 494 |
| `combat/provenance/` | 32 |
| 其余约 18 个目录 | 77 |

全部来自源工程，**0 个是美术真缺口**。

### 5.2 唯一确认的真缺口：法宝图标

| 项 | 内容 |
|---|---|
| 缺口项 | 法宝图标 |
| 现有覆盖范围 | 源工程 `assets/icons/` 25 个 PNG，五类：灵根 9 / 修路 4 / 修路水墨 4 / 路标 4 / 其他 4 |
| 确认结论 | **该清单不含任何法宝类图标**。`path_sword_artifact.png` 属路标类（`path_` 前缀）非装备图标。`assets/items/` 为空，`equipment.json` 的 6 件法宝均无 `icon` 字段。**属真实资源缺口（真缺口），非漏拷。** |

逐项清单见 `ASSET_INDEX_2026-11-05.md` §六。

### 5.3 别名表

`source_manifest.json` 的 18 条 `runtimeAliases` 全部是 `.png` → `.jpg`（2 个背景 + 16 张卡面）。**任何核对脚本必须解析**，否则误判缺失。

---

## 6. 使用方式

### 6.1 环境

Godot 4.7.2 Stable：`<repo>/.godot-toolchain/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe`。

### 6.2 首次上手（4 步）

```bash
GODOT="<上述路径>"; P="<repo>/godot"

"$GODOT" --headless --path "$P" --editor --quit    # ① 重建全局类缓存（必做）
"$GODOT" --headless --path "$P" --quit-after 5     # ② 完整加载验证
"$GODOT" --headless --path "$P" --script "res://tests/noncombat_content_repository.gd"
"$GODOT" --path "$P" --script "res://tools/shot_probe.gd"   # ③ 截图（非 headless）
```

**① 不可跳过**：`--check-only` 不解析全局类缓存，会误判通过。

### 6.3 关键命令

| 目的 | 命令 |
|---|---|
| 跑主场景 | `"$GODOT" --path "$P"` |
| 跑测试 | `"$GODOT" --headless --path "$P" --script "res://tests/<name>.gd"` |
| 截图 | `"$GODOT" --path "$P" --script "res://tools/shot_probe.gd"` |
| 导出 | `"$GODOT" --headless --path "$P" --export-release "Windows Desktop" dist/windows/...exe` |

### 6.4 耗时测试（默认 30 秒不够）

`noncombat_choice_echo_public_seed` ≈116s / `noncombat_faction_combat` 180s / `noncombat_faction_natural` ≈600s / `noncombat_q_fellow_outcomes` >180s。

---

## 7. 维护方式

| 场景 | 要点 |
|---|---|
| 加非战斗卡 | 编辑 `content/data/cards/<realm>.json` 的 `cards[]`；必填 `id`（永不改名）、`title`、`description`、`type`、`choices`、`sceneImage`；跑 `noncombat_content_repository` 确认 `unlisted=0` |
| 加战斗卡 | 编辑 `battle_cards.json` 的 `battle_cards[]`；必填 `cardArt.image` |
| 加战斗舞台 | `STAGE_ROUTES` 加一条 + `_build()` 分支设 `stage_key`；**不要**用 `const X = preload(...)` |
| 改 `noncombat_domain.gd` | 先跑全量记录基线，一次只改一类，独立提交，期间禁止并行改动 |
| 改 `noncombat_opening_ui.gd` | 6 屏共用一脚本，改完必须截图比对 |
| 同步素材 | `tools/sync_runtime_content.py` 仍是手工枚举（根因）；核对脚本见 §8 |

详见 `PROJECT_HANDBOOK_2026-11-05.md` §6。

---

## 8. 可复现的资源核对脚本

```python
import json, glob, os, re
man = json.load(open('content/source_manifest.json', encoding='utf-8'))
alias = {e['sourcePath']: e['runtimePath'] for e in man.get('runtimeAliases', [])}
EXT = re.compile(r'\.(png|jpg|jpeg|webp|gif|wav|mp3|ogg)$', re.I)

refs = set()
def walk(o):
    if isinstance(o, dict):
        for v in o.values(): walk(v)
    elif isinstance(o, list):
        for i in o: walk(i)
    elif isinstance(o, str) and o.startswith('assets/') and EXT.search(o):
        refs.add(o)

for f in glob.glob('content/data/**/*.json', recursive=True) + ['content/source_manifest.json']:
    walk(json.load(open(f, encoding='utf-8')))

missing = [p for p in refs if not os.path.isfile(os.path.join('content', alias.get(p, p)))]
# 期望：len(missing) == 0
```

补齐逻辑（源工程根 `SRC`）：

```python
import shutil
for p in missing:
    rp = alias.get(p, p)
    s, d = os.path.join(SRC, rp), os.path.join('content', rp)
    if os.path.isfile(s) and not os.path.isfile(d):
        os.makedirs(os.path.dirname(d), exist_ok=True)
        shutil.copy2(s, d)
```

---

## 9. 验证记录（本轮实跑）

| # | 检查 | 结果 |
|---|---|---|
| 1 | 完整项目加载（导入 1,943 张新图） | 零 `SCRIPT ERROR` / `Parse Error` |
| 2 | `noncombat_content_repository` | `PASS modules=75 cards=588 quests=6 threads=12 scene_refs=553 unlisted=0`（与补齐前一致） |
| 3 | `noncombat_qi_gate_entry` | `PASS public=true quota=true warning=true pending=true survival=true counter=true plan_order=true return=true replay=true`，`assets_ready=true` |
| 4 | `battle_stub_contract` | `PASS` |
| 5 | `audio_bus_layout` | `PASS buses=5 names=Master,BGM,SFX,Voice,UI` |
| 6 | `shot_probe`（非 headless） | `PASS size=(1280,800)` |
| 7 | 资源覆盖率复核 | `3239 / 3239 = 100.00%` |

**`assets_ready=true` 是关键证据**：它来自 `duel_stage.has_hd2d_assets()`，会实际检查角色序列帧与战场资源加载，不是语法层面的通过。

---

## 10. 关键约束

### 10.1 三条不可违反的契约

| # | 约束 | 原因 |
|---|---|---|
| 1 | `texture_for()` 缺失必须返回 **null** | 5 处 `duel_stage_*` 用 `== null` 判定资源可用性；改返回占位图会让校验永远通过 |
| 2 | `BattleStub` 结果必须过 `validate_result()` | 桩要与真实战斗同契约 |
| 3 | 卡牌/遭遇 ID **永不改名** | 存档、因果种子、事件回执全引用 |

### 10.2 禁止事项

`battle_stub_mode` 默认改 true / 删测试或改断言 / 动 `duel_stage_*` 结构 / 手写 `.tscn` 的 `uid` / 在 `.tscn` `.tres` 写注释 / 把 `content/assets` 或 `assets` 加进 git / 用 `--check-only` 判定跨文件类型 / 全局替换命中自己刚写的 wrapper。

### 10.3 剩余工作

| 项 | 状态 |
|---|---|
| 法宝图标 | **真缺口**（§5.2），用户已确认需要 |
| VFX 美术评审 | 163 条 `finalArtApproved` 全 false（设计口径，非引用口径） |
| `sync_runtime_content.py` 手工枚举 | 待改三段式（`collect_refs` / `resolve` / `report`），否则下次仍会漏拷 |
| 抽 5 屏为 `.tscn` | 待做，截图基线已备 |
| `noncombat_domain` 拆 5 Director | 待做（高风险） |
| 事件类型常量化 | 需先跑全量事件清单 |

---

## 11. Git 与回退

| 项 | 值 |
|---|---|
| 分支 | `remedy/noncombat-p0-2026-11-05` |
| 基线 tag | `baseline-2026-11-05-pre-noncombat-remedy` / `c268384` |
| 本分支提交数 | 17（交接前） |

```bash
git log --oneline main..HEAD              # 查看全部提交
git revert <hash>                          # 退单个任务
git reset --hard c268384                   # 整体回到基线
```

**注意**：
- 资源文件在 `content/assets/` 与 `assets/` 下，**均不入库**，所以 `git` 操作不会回滚素材补齐
- 回退后若报类找不到，重跑 `--editor --quit` 重建缓存
- 不要 `push --force`

---

## 12. 文档索引

| 文档 | 用途 |
|---|---|
| **`ASSET_INDEX_2026-11-05.md`** | 素材索引（目录/数量/体积/别名/缺口确认/检索方式） |
| **`PROJECT_HANDBOOK_2026-11-05.md`** | 维护手册（9 章，含排错与命令速查） |
| `GDD_GODOT_V1.md` | 设计 + 架构主文档（11 章） |
| `ASSET_AUDIT_VERIFIED_2026-11-05.md` | 资源缺口核对与三项纠错 |
| `ARCHITECTURE_REVIEW_GODOT_2026-11-05.md` | 架构审计（N-1~N-11） |
| `HANDOFF_TO_CODEX_2026-11-05.md` | 待办任务交接（T1~T6） |
| `MIGRATION_SCORECARD.md` | 子项进度账本 |
| `ITERATION_REPORT_2026-11-05.md` | 架构地基迭代验收（4/5 达标） |

**接手时先读**：`ASSET_INDEX` + `PROJECT_HANDBOOK` + 本文档 §2 勘误表。

---

**文档版本**：v1.0  
**交接日期**：2026-11-05  
**数据状态**：全量补齐后（3239/3239 = 100%）  
**下一修订触发**：法宝图标产出 / 抽屏完成 / 同步脚本改造完成
