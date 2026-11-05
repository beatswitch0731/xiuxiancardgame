# 素材索引

| 项 | 内容 |
|---|---|
| 版本 | v1.0 |
| 编制日期 | 2026-11-05 |
| 工程根 | `<repo>/godot` |
| 源工程 | `<repo>`（浏览器版，素材来源） |
| 索引口径 | `content/data/**/*.json` + `content/source_manifest.json` 全量 `assets/` 引用，经 18 条 runtimeAliases 解析后核对实际文件 |
| 覆盖率 | **3239 / 3239 = 100%**（2026-11-05 全量补齐后） |

---

## 一、两套资源根

| 根 | 体积 | 文件数 | 用途 | 引用方式 |
|---|---|---|---|---|
| `godot/content/assets/` | **1192.5 MB** | **4,379** | 运行时内容（卡面、场景图、战斗帧、音频） | `texture_for("assets/xxx")` |
| `godot/assets/` | **1695.4 MB** | **2,881** | 手工 Godot 原生资源（3D、字体、UI 材质） | `res://assets/xxx` |

**判断规则**：源 JSON 里出现的 `assets/xxx` → 第一个根；Godot 原生资源（`.glb`/`.ttf`/`.tres`）→ 第二个根。

---

## 二、`content/assets/` 目录索引

按体积排序，列出主要目录。`路径` 相对 `content/`，即 JSON 里写的样子。

| 路径 | 文件数 | 体积 | 内容 | 主要引用字段 |
|---|---|---|---|---|
| `assets/cards/events/` | 454 | 306.7 MB | 剧情事件场景图 | `cards[].sceneImage` |
| `assets/combat/battlefields/` | 107 | 115.0 MB | 战斗场景图 | `sceneImage`（战斗卡/遭遇） |
| `assets/combat/provenance/` | 32 | 76.9 MB | 素材溯源图 | `provenancePath` |
| `assets/characters/stages/` | 90 | 64.6 MB | 同伴立绘阶段图 | `portraitStages` / `cardAssets` |
| `assets/combat/enemy_actions/` | 1,003 | 64.3 MB | 敌人动作序列帧 | `animatedMedia[].frames[].path` |
| `assets/combat/cards/` | 202 | 63.6 MB | 战斗卡面（含 `pc98_*` 子目录） | `battle_cards[].cardArt.image` |
| `assets/cards/keyframes/` | 126 | 46.2 MB | 关键帧插画 | `sceneImage` |
| `assets/combat/protagonist/` | 762 | 33.2 MB | 主角动作序列帧 | 帧序列 `path` |
| `assets/card-illustrations/hd/` | 24 | 29.9 MB | 高清卡面插画 | `cardArt.image` |
| `assets/combat/vfx/` | 697 | 26.9 MB | 打击特效帧 | `animatedMedia` / VFX 引用 |
| `assets/audio/bgm/` | 8 | 24.9 MB | 背景音乐 | `audioCatalog` |
| `assets/cards/characters/` | 54 | 24.3 MB | 角色卡图 | `cardArt.image` |
| `assets/ui/endings/` | 16 | 19.7 MB | 结局插画 | 结局配置 |
| `assets/combat/migrated_encounters_v1/` | 72 | 15.4 MB | 迁移遭遇图 | `sceneImage` |
| 其余目录 | 732 | 约 321 MB | 背景、UI、音频、图标、NPC 等 | 多字段 |
| **合计** | **4,379** | **1192.5 MB** | — | — |

---

## 三、`assets/` 目录索引（2026-11-05 分类后）

| 路径 | 文件数 | 体积 | 内容 |
|---|---|---|---|
| `assets/battle/hd2d/` | 659 | 1525.1 MB | HD-2D 角色与场景模型 |
| `assets/battle/undercurrent_pixel_v1/` | 1,840 | 25.2 MB | 像素参考素材 |
| `assets/battle/25d/` | 10 | 9.7 MB | 2.5D 舞台资源 |
| `assets/battle/battle_actor_style_v1/` | 4 | 0.9 MB | 角色风格参考 |
| `assets/battle/source_first_fight/` | — | 0.7 MB | 首战原画 |
| `assets/fonts/` | 2 | 41.6 MB | `LXGWWenKai-Regular.ttf` / `NotoSansSC-VF.ttf` |
| `assets/characters/actor_image3d_mvp/` | 10 | 47.5 MB | 3D 角色实验 |
| `assets/characters/actor_wearable_v2/` | 15 | 17.1 MB | 换装资源 |
| `assets/characters/actor_motion_lab_v1/` | 24 | 8.1 MB | 动作实验 |
| `assets/characters/modular_pixel_actor_v1/` | 18 | 6.4 MB | 模块化像素角色 |
| `assets/characters/actor_candidates/` | 12 | 0.8 MB | 角色候选 |
| `assets/characters/actors/` | — | 0.3 MB | 角色杂项 |
| `assets/demo/equipment_demo/` | 225 | 3.3 MB | 换装演示 |
| `assets/demo/equipment_swap_mvp/` | — | 4 KB | 换装 MVP |
| `assets/ui/` | — | 2.0 MB | UI 材质（plaque / intent slip / desk） |
| `assets/third_party/` | 3 | 6.4 MB | Quaternius 授权资源 |
| `assets/cards/` | — | 0.3 MB | 卡牌杂项 |
| `assets/items/` | 0 | 0 | **空**（见 §六） |
| **合计** | **2,881** | **1695.4 MB** | — |

---

## 四、2026-11-05 补齐明细

### 4.1 全量扫描结论

```
引用唯一文件数: 3239
  Godot 侧已有: 1296
  缺失:         1943
    源工程存在(可补): 1943
    源工程也没有(真缺口): 0
```

### 4.2 补齐的 1943 个文件按目录分布

| 目录 | 个数 |
|---|---|
| `assets/combat/enemy_actions/` | 731 |
| `assets/combat/vfx/` | 609 |
| `assets/combat/protagonist/` | 494 |
| `assets/combat/provenance/` | 32 |
| `assets/combat/spell_codex_opportunity_v1/` | 11 |
| `assets/combat/enemies/` | 10 |
| `assets/combat/ui/` | 10 |
| `assets/combat/enemy_identities/` | 9 |
| `assets/combat/native_card_v2/` | 7 |
| `assets/combat/fx/` | 4 |
| `assets/combat/player_paths/` | 4 |
| `assets/combat/cards/` | 4 |
| 其余约 12 个目录 | 18 |
| **合计** | **1,943** |

**体积**：232.9 MB（1,940 个 `.png` + 3 个 `.webp`）。

### 4.3 补齐前已单独完成的部分

同日早些时候已补 133 张战斗卡面（69.3 MB），本轮 1,943 个不含这 133 个。

### 4.4 补齐后复核

```
引用唯一文件: 3239 / 存在: 3239 / 缺: 0 / 覆盖率: 100.00%
content/assets 体积: 967 MB → 1192.5 MB
```

---

## 五、runtimeAliases（18 条）

`content/source_manifest.json` 的 `runtimeAliases`：源路径声明为 `.png`，实际磁盘是 `.jpg`。**任何资源核对脚本都必须解析这 18 条**，否则会把已有文件误判为缺失。

| # | 源路径（JSON 中） | 实际磁盘 |
|---|---|---|
| 1 | `assets/backgrounds/bg_inkwash_masterpiece.png` | 同名 `.jpg` |
| 2 | `assets/backgrounds/bg_start.png` | 同名 `.jpg` |
| 3 | `assets/combat/cards/card_body_guard_pc98.png` | 同名 `.jpg` |
| 4 | `assets/combat/cards/card_body_qi_breath_pc98.png` | 同名 `.jpg` |
| 5 | `assets/combat/cards/card_draw_sword_pc98.png` | 同名 `.jpg` |
| 6 | `assets/combat/cards/card_heavy_strike_pc98.png` | 同名 `.jpg` |
| 7 | `assets/combat/cards/card_ice_resonance_pc98.png` | 同名 `.jpg` |
| 8 | `assets/combat/cards/card_mana_potion_pc98.png` | 同名 `.jpg` |
| 9 | `assets/combat/cards/card_pill_mending_pc98.png` | 同名 `.jpg` |
| 10 | `assets/combat/cards/card_pill_poison_pc98.png` | 同名 `.jpg` |
| 11 | `assets/combat/cards/card_qi_shield_pc98.png` | 同名 `.jpg` |
| 12 | `assets/combat/cards/card_spell_gather_pc98.png` | 同名 `.jpg` |
| 13 | `assets/combat/cards/card_spell_nuke_pc98.png` | 同名 `.jpg` |
| 14 | `assets/combat/cards/card_spell_qi_retrace_pc98.png` | 同名 `.jpg` |
| 15 | `assets/combat/cards/card_spell_tide_pc98.png` | 同名 `.jpg` |
| 16 | `assets/combat/cards/card_sword_array_pc98.png` | 同名 `.jpg` |
| 17 | `assets/combat/cards/card_sword_intent_pc98.png` | 同名 `.jpg` |
| 18 | `assets/combat/cards/card_sword_qi_riposte_pc98.png` | 同名 `.jpg` |

---

## 六、法宝图标：缺口确认

### 缺口项

法宝图标。

### 现有覆盖范围

源工程 `assets/icons/` 共 **25 个 PNG**，全部列出如下，按五类枚举：

| 类别 | 文件 |
|---|---|
| 灵根（9） | `icon_linggen_bing.png`、`icon_linggen_feng.png`、`icon_linggen_hundun.png`、`icon_linggen_huo.png`、`icon_linggen_jin.png`、`icon_linggen_lei.png`、`icon_linggen_mu.png`、`icon_linggen_shui.png`、`icon_linggen_tu.png` |
| 修路（4） | `icon_body.png`、`icon_pill.png`、`icon_spell.png`、`icon_sword.png` |
| 修路水墨（4） | `body_ink.png`、`pill_ink.png`、`spell_ink.png`、`sword_ink.png` |
| 路标（4） | `path_body_statue.png`、`path_pill_elixir.png`、`path_spell_seal.png`、`path_sword_artifact.png` |
| 其他（4） | `game_logo.png`、`xianxia_minimal_logo.png`、`icon_lifespan.png`、`icon_spirit_stone.png` |

合计 9 + 4 + 4 + 4 + 4 = **25**，与源工程记录一致。

### 确认结论

**上述 25 个清单不含任何法宝类图标。**

其中 `path_sword_artifact.png` 文件名含 `artifact`，但属「路标」类（`path_` 前缀，剑修路标），不是装备/法宝图标。

`godot/assets/items/` 当前为空。`content/data/items/equipment.json` 的 6 件法宝记录（`玄铁甲`、`灵泉葫芦`、`避尘珠`、`太乙精金剑`、`青云剑匣`、`神农鼎`）均无 `icon` 字段。

**该项为真实资源缺口（真缺口），不属于源工程素材漏拷。**

---

## 七、检索方式

### 7.1 按卡牌 ID 找卡面

```python
import json
bc = json.load(open('content/data/cards/battle_cards.json', encoding='utf-8'))['battle_cards']
img = next(c['cardArt']['image'] for c in bc if c['id'] == '<card_id>')
# 实际文件：content/<img>（若 img 在 runtimeAliases 中，用映射后的 .jpg）
```

### 7.2 按卡牌 ID 找场景图

```python
import glob, json
for f in glob.glob('content/data/cards/*.json'):
    d = json.load(open(f, encoding='utf-8'))
    for c in d.get('cards', []):
        if c.get('id') == '<card_id>':
            print(c.get('sceneImage'))
```

### 7.3 按遭遇 ID 找战场图

`sceneImage` 中形如 `battlefield_<encounter_id>_*.png` 的文件位于
`content/assets/combat/battlefields/`。

### 7.4 按事件类型找帧序列

`content/source_manifest.json` 的 `animatedMedia` 数组，当前 3 条：

| sourcePath | 帧数 |
|---|---|
| `assets/card-illustrations/motion/jian-idle.webp` | 4 |
| `assets/card-illustrations/motion/jiuwei-idle.webp` | 4 |
| `assets/card-illustrations/motion/jiuwei-water-environment.webp` | 60 |

---

## 八、索引维护

本索引的数字由以下口径得出，可随时重跑复核：

1. 遍历 `content/data/**/*.json` 与 `content/source_manifest.json`，收集所有以 `assets/` 开头且带图片/音频扩展名的字符串
2. 用 `runtimeAliases` 做 `.png`→`.jpg` 映射
3. 检查 `content/<mapped_path>` 是否存在
4. 目录体积与文件数用 `os.walk` 统计

**新加素材后**：重跑上述口径，更新 §二 表格与 §四 的补齐记录。

---

**文档版本**：v1.0  
**编制日期**：2026-11-05  
**数据状态**：2026-11-05 全量补齐后（3239/3239 = 100%）
