# 资源完成度核对报告

| 项 | 内容 |
|---|---|
| 核对日期 | 2026-11-05 |
| 核对对象 | 卡面 / 场景立绘 / 法宝图标 三项完成度数据 |
| 核对方式 | 遍历 `content/data/**/*.json` 全量引用 + 逐文件检查 `content/assets/` 存在性（含 `source_manifest.json` 的 18 条 runtimeAliases 别名解析） |
| 结论 | **1 项基本正确、1 项完全错误、1 项数量与性质都错** |
| 是否改动代码 | **否**，纯核对 |

---

## 一、结论速览

| 项 | 此前表述 | 实测（核对时） | 判定 | 处理结果 |
|---|---|---|---|---|
| 卡面 | 「133/174（缺 76%）」 | 唯一图 **171**，存在 **38**，缺 **133**（缺 77.8%） | ⚠️ **数字对，表述歧义** | ✅ **已修复：133 张全部从源工程同步，现 171/171 = 100%** |
| 场景立绘 | 「230/268（缺 86%）」 | 唯一 `sceneImage` **342**，缺 **4**（全在战斗侧）；**非战斗 269 张缺 0** | ❌ **完全错误** | 待修文档表述 |
| 法宝图标 | 「23/23（缺 100%）」 | 法宝 **6 个**，icon 字段 **0 个** | ❌ **数量与性质都错** | 确认为**真缺口**（源工程无可用图标），保留在清单 |

**表述歧义的根源**：我把「缺 133」写成了「133/174」，按「已完成/总数」的行业惯例会被读成「已有 133 张」。以后所有缺口的表述统一为 **`存在/总数（缺 N）`**。

---

## 一之二、卡面缺口的重大发现（2026-11-05 补记）

**133 张缺口全部是同步漏拷，不是美术缺口。**

| 目录 | 源工程有 | Godot 侧有 |
|---|---|---|
| `assets/combat/cards/pc98_legacy_v2` | **27 张** | **0 张** |
| `assets/combat/cards` | **128 张** | **14 张** |

逐张核对 133 个缺失路径：

```
卡面缺失总数: 133
  源工程存在: 133  → 属同步漏拷
  源工程也没有: 0   → 属美术真缺口
```

**已执行同步**：133 个文件 / 69.3 MB，全部复制到 `content/assets/`，跳过 0。

**同步后复核**：`唯一 171 / 存在 171 / 缺 0（覆盖率 100.0%）`

**回归验证**：
- 完整项目加载零 SCRIPT ERROR（133 张新图导入正常）
- `NONCOMBAT_CONTENT_REPOSITORY_PASS modules=75 cards=588 quests=6 threads=12 scene_refs=553 unlisted=0`（与同步前一致）

**结论**：这一项不是「需要画 133 张图」，是「需要拷贝 133 个文件」。根因仍是 `sync_runtime_content.py` 的手工枚举——它只同步白名单内的遭遇资产。

---

## 二、卡面（唯一真缺口）

### 2.1 数据源

| 项 | 值 |
|---|---|
| JSON 文件 | `content/data/cards/battle_cards.json` |
| 字段路径 | `battle_cards[].cardArt.image` |
| 卡牌数 | **174** 张 |
| 唯一图 | **171** 张（3 张卡复用同图） |

### 2.2 覆盖情况

| 目录 | 共 | 缺 |
|---|---|---|
| `assets/combat/cards` | 121 | **97** |
| `assets/combat/cards/pc98_legacy_v2` | 25 | **25**（整目录全缺） |
| `assets/combat/body_tribulation_opportunity_v1` | 4 | 4 |
| `assets/combat/pill_master_opportunity_v1` | 4 | 4 |
| `assets/combat/spell_codex_opportunity_v1` | 3 | 3 |
| `assets/combat/cards/pc98_starter_v2` | 7 | 0 |
| `assets/cards/characters` | 6 | 0 |
| `assets/combat/cards/pc98_starter_v3` | 1 | 0 |
| **合计** | **171** | **133** |

**覆盖率 22.2%（38/171）**。

### 2.3 还缺什么（具体）

**第一优先：`pc98_legacy_v2` 整目录 25 张全缺**

这个目录名暗示它是「PC-98 风格旧版卡面」的迁移目标，但文件一个都没有。样例：
```
assets/combat/cards/pc98_legacy_v2/legacy_demon_blood_sword_pc98.png
assets/combat/cards/pc98_legacy_v2/legacy_pill_way_body_pc98.png
```

**第二优先：`assets/combat/cards` 97 张**

散落在主卡面目录。样例：
```
assets/combat/cards/card_pill_nascent_return_pc98.png
assets/combat/cards/card_pill_golden_poison_pc98.png
assets/combat/cards/card_sword_shop_foundation_line_pc98.png
```

**第三优先：三个 opportunity 目录共 11 张**

按修路分组的机遇卡面：`body_tribulation`(4) / `pill_master`(4) / `spell_codex`(3)。

### 2.4 建议下一步

1. **先查 `pc98_legacy_v2` 的 25 张是否存在于源工程**（`<repo>/assets/combat/cards/pc98_legacy_v2/`）。如果源工程有、Godot 没有 → 是**同步脚本漏拷**，改脚本即可
2. 如果源工程也没有 → 是**美术真缺口**，进创作队列
3. 这一项是三项里**唯一影响玩家可玩性**的缺口（战斗手牌无图）

---

## 三、场景立绘（此前数据完全错误）

### 3.1 数据源

| 项 | 值 |
|---|---|
| JSON 文件 | 分散在 `content/data/cards/*.json` 共 16 个文件 |
| 字段路径 | `cards[].sceneImage` |
| 引用总数 | **673 处** |
| 唯一资源 | **342** 张 |

### 3.2 覆盖情况（按目录）

| 目录 | 共 | 缺 | 性质 |
|---|---|---|---|
| `assets/cards/events` | **201** | **0** | 剧情事件图 |
| `assets/cards/keyframes` | **63** | **0** | 关键帧 |
| `assets/cards/companions` | 5 | 0 | 同伴 |
| `assets/combat/battlefields` | 55 | **3** | **战斗场景** |
| `assets/combat/encounter_catalog_v1` | 1 | **1** | **战斗场景** |
| `assets/combat/migrated_encounters_v1` | 8 | 0 | 战斗 |
| `assets/combat/realm_boss_r9bc` | 3 | 0 | 战斗 |
| 其余 6 个单文件目录 | 6 | 0 | 战斗 |
| **合计** | **342** | **4** | — |

### 3.3 关键结论

**非战斗剧情图 269 张（events 201 + keyframes 63 + companions 5），缺 0 张，覆盖率 100%。**

缺的 4 张**全部在战斗侧**：
```
assets/combat/battlefields/battlefield_enc_boss_deity_karma_dragon_agc_n14.png
assets/combat/battlefields/battlefield_enc_boss_nascent_void_agc_n13.png
assets/combat/battlefields/battlefield_enc_boss_tribulation_heaven_door_agc_n14.png
assets/combat/encounter_catalog_v1/battlefields/battlefield_enc_trial_sword_swift_native_v1.png
```

### 3.4 「230/268」这个数从哪来的

**在工程中无法复现。** 最可能的来源是混淆了两个不同口径：

| 数 | 真实含义 | 出处 |
|---|---|---|
| **269** | 非战斗 sceneImage 唯一资源总数（201+63+5） | 本次实测 |
| **230** | 「非战斗候选图」的目录统计数（**含未挂接的候选**，非缺失数） | `NONCOMBAT_FULL_MIGRATION_TASKBOOK.md` 的 N0 阶段记录 |

原始记录写的是：

> 此前"230 张非战斗候选图"含 `assets/cards/combat/*` 下 55 张战斗卡图。目录工具现同时排除 `assets/combat/*` 与 `assets/cards/combat/*`，非战斗候选为 **175 张**

也就是说：**230 是「候选图总数」，175 是「排除战斗后的候选数」，两者都不是「缺失数」。** 我把候选数误当成了缺失数，并把「缺 86%」这个比例算了上去。

### 3.5 建议下一步

**这一项基本不需要动。** 只需要补 4 张战斗场景图，且都在战斗侧（本阶段延后），优先级最低。

**但需要修正文档**：`GDD_GODOT_V1.md` 与 `HANDOFF_TO_CODEX_2026-11-05.md` 里若引用了「立绘缺 86%」，应改为「非战斗场景图 269 张全齐，缺 0」。

---

## 四、法宝图标（数量与性质都错）

### 4.1 数据源

| 项 | 值 |
|---|---|
| JSON 文件 | `content/data/items/equipment.json` |
| 结构 | `{"items": {<中文名>: {...}}}`（**字典，非数组**） |
| 法宝数 | **6** |
| 有 `icon` 字段的 | **0** |

### 4.2 实际清单

| 法宝 | slot | tier |
|---|---|---|
| 玄铁甲 | armor | qi |
| 灵泉葫芦 | accessory | qi |
| 避尘珠 | accessory | foundation |
| 太乙精金剑 | weapon | golden |
| 青云剑匣 | artifact | nascent |
| 神农鼎 | artifact | nascent |

**6 个法宝，没有一个有 `icon` 字段。**

单条记录的完整键：
```
['id', 'name', 'slot', 'tier', 'tierName', 'desc', 'stats', 'passives']
```

### 4.3 「23/23」从哪来的

**数据里不存在 23 这个数。** 网页版源工程 `data/items/equipment.json` 同样只有 **6 个**法宝。

可能的来源：
- 设计目标里的法宝数量（如「25 件法宝」的设计规划）
- 或网页版 `TreasureSystem.js` 的硬编码定义（但该文件里可提取的 item 定义为 0，说明它从 JSON 读）

**没有证据支持 23 或 25。**

### 4.4 性质判定（这点比数量更重要）

不是「图标文件缺了 23 个」，而是：

> **法宝数据模型里根本没有 `icon` 字段。**

这意味着当前 UI **不会**去读法宝图标——`noncombat_treasure_acquisition.gd` 和装备界面只用文字描述。所以这一项不是「资源缺失」，是「功能未设计」。

### 4.5 建议下一步

1. **先决策**：法宝是否需要图标？（6 个法宝全是文字描述也能玩）
2. 若需要 → 先加 `icon` 字段到 `equipment.json`（6 条），再补 6 张图，**不是 23 张**
3. 若不需要 → 从缺口清单里移除这一项

---

## 五、修正后的资源缺口总表

| 资源 | JSON 配置 | 唯一资源 | 存在 | 缺 | 覆盖率 | 性质 |
|---|---|---|---|---|---|---|
| **战斗卡面** | `cards/battle_cards.json` → `cardArt.image` | 171 | **171** | **0** | **100%** | ✅ 已同步（原 133 缺全部来自源工程） |
| **非战斗场景图** | 16 个 `cards/*.json` → `sceneImage` | 269 | 269 | **0** | **100%** | 无缺口 |
| 战斗场景图 | 同上 | 73 | 69 | 4 | 94.5% | 战斗侧，延后 |
| **法宝图标** | `items/equipment.json` → `icon` | 字段不存在 | — | **6**（需新增） | 0% | **真缺口：源工程无可用图标** |

---

## 六、法宝图标：确认真缺口与规格建议

### 6.1 为什么是真缺口

`assets/icons/` 现有 25 个 PNG，全部是：

| 类别 | 文件 |
|---|---|
| 灵根 | `icon_linggen_{bing,feng,hundun,huo,jin,lei,mu,shui,tu}.png` |
| 修路 | `icon_{body,pill,spell,sword}.png` |
| 修路水墨 | `{body,pill,spell,sword}_ink.png` |
| 路标 | `path_{body_statue,pill_elixir,spell_seal,sword_artifact}.png` |
| 其他 | `game_logo` / `xianxia_minimal_logo` / `icon_lifespan` / `icon_spirit_stone` |

**没有一件装备/法宝专用图标。** 源工程 `assets/` 下也搜不到 `artifact` / `treasure` / `equip` 命名的图标资源。

### 6.2 两种规格方案

| 方案 | 数量 | 说明 |
|---|---|---|
| **A 定制** | 6 张 | 每个法宝一张：玄铁甲 / 灵泉葫芦 / 避尘珠 / 太乙精金剑 / 青云剑匣 / 神农鼎 |
| **B 按槽位** | 4 张 | armor / weapon / artifact / accessory 各一张，6 个法宝按 slot 复用 |

**建议 B**：法宝只有 6 个，按槽位画 4 张即可覆盖，且将来新增法宝无需再画。

### 6.3 落地需要三件事（当前都没做）

1. **美术产出** 4 张（或 6 张）图标
2. **数据加字段**：`equipment.json` 每个 item 加 `icon`，指向 `assets/icons/items/{slot}_icon.png`
3. **UI 读取**：`noncombat_treasure_acquisition.gd` / 装备界面需新增图标显示（当前只渲染文字）

**顺序建议**：先定规格 → 美术出图 → 加字段 + 改 UI（一次性完成，避免字段存在但无人读取的中间态）。

---

## 七、建议的处理顺序

| 序 | 动作 | 状态 |
|---|---|---|
| 1 | ~~查 `pc98_legacy_v2` 25 张是否在源工程~~ | ✅ **已完成：在，已同步** |
| 2 | ~~查 `assets/combat/cards` 97 张同上~~ | ✅ **已完成：在，已同步** |
| 3 | 修正 GDD / 交接文档里「立绘缺 86%」的表述 | 待做 |
| 4 | 法宝图标：定规格（建议 4 张按槽位）→ 美术产出 → 加 `icon` 字段 + 改 UI | **用户已确认要做**，待启动 |
| 5 | 4 张战斗场景图 | 随战斗延后 |
| 6 | 修 `sync_runtime_content.py` 手工枚举根因 | 待做（否则下次仍会漏） |

---

## 七、核对脚本（可复现）

本次数据全部由以下逻辑得出，可随时重跑复核：

```python
# 伪代码，实际已在核对过程中执行
alias = {e['sourcePath']: e['runtimePath'] for e in manifest['runtimeAliases']}
def ok(p):
    return os.path.isfile(os.path.join('content', alias.get(p, p)))

# 卡面
battle_cards = json.load('content/data/cards/battle_cards.json')['battle_cards']
faces = set(c['cardArt']['image'] for c in battle_cards if c.get('cardArt',{}).get('image'))

# 场景图
scene = 所有 JSON 中键名为 'sceneImage' 的字符串值

# 法宝
items = json.load('content/data/items/equipment.json')['items']
icons = [v['icon'] for v in items.values() if v.get('icon')]
```

**关键**：必须解析 `source_manifest.json` 的 `runtimeAliases`（18 条 `.png`→`.jpg` 别名），否则会把已有文件误判为缺失。

---

**报告版本**：v1.0  
**核对日期**：2026-11-05  
**数据口径**：`content/data` 全量 JSON + `content/assets` 实际文件 + 18 条 runtimeAliases  
**未改动任何代码或配置**
