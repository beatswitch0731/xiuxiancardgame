# NPC 立绘全链路审计报告

**日期**: 2026-06-29  
**审计范围**: 全部8个核心NPC + 7个demonic_seductress NPC + NPC_CROSS交叉事件的立绘加载全链路  

---

## 一、立绘加载架构（三层降级）

```
card.npcId / card.npcIds[0]
  │
  ├─(1) LitPixel 路径    →  _toLitPixelCharId()  →  WebGL渲染（normals/materials）
  │   └─ 失败
  ├─(2) 静态贴图路径     →  _fallbackCardPortrait()  →  _getNpcPortrait()  →  <img>
  │   └─ 失败  
  └─(3) 像素占位符       →  "⚔" + npcId文字
```

三个映射表：
- `_npcPortraitMap` — 静态贴图URL
- `_toLitPixelCharId` — LitPixel角色ID
- `portrait_stages.json` + `_getUnlockedPortraitStages` — 好感度阶段立绘

---

## 二、已发现漏洞

### 🔴 P0 — `jiuwei` 短ID在所有三个映射表中缺失

**触发场景**: NPC_CROSS 预设卡「千年的债」(tian_ji + jiuwei)  
**npc_cross_cards.json** 使用 `"jiuwei"` (短ID)，但核心数据使用 `"jiuwei_suyue"` (长ID)

| 映射表 | 修复前 | 修复后 |
|--------|--------|--------|
| `_npcPortraitMap` | 只有 `jiuwei_suyue` → `jiuwei` fallback到 `concept_bai_luoxuan.webp` ❌ | 新增 `jiuwei: concept_jiuwei_suyue.webp` ✅ |
| `_toLitPixelCharId` | 只有 `jiuwei_suyue` → `jiuwei` fallback到原始值 | 新增 `jiuwei: 'jiuwei_suyue'` ✅ |
| `portrait_stages alias` | 只有 `{tian_ji, xue_sha}` → `jiuwei` 找不到 stage | 新增 `jiuwei: 'jiuwei_suyue'` ✅ |

**后果**: 「千年的债」交叉卡触发时，九尾溯月的立绘显示为**白落霜**——完全错误的角色。LitPixel也会因找不到 `concept_jiuwei.webp` 而失败。

**✅ 已修复**：三处映射表均添加 `jiuwei → jiuwei_suyue` 别名。

---

### 🟡 P1 — 狐狸粒子特效 jiuwei 短ID未覆盖

**位置**: ui.js 三处 `isFox` 判断  
**触发**: NPC_CROSS 卡的 `_renderCardPortraitForStage` 渲染时  
**后果**: 九尾溯月的交叉卡不显示狐狸粒子特效（狐火、九尾环绕等）

**✅ 已修复**：
- Line 1530: `_renderCardPortrait` 狐狸粒子 + `jiuwei`
- Line 1597: `isFox` 判断 + `jiuwei`  
- Line 2518: `_renderCardPortraitForStage` 狐狸粒子 + `jiuwei`

---

### 🟡 P2 — `wandering_mortal` 无任何立绘文件

**触发场景**: demonic_seductress.json 的7个 ds_* NPC (血玫、月烟等)  
**链路**:
1. `_toLitPixelCharId(ds_bloodrose)` → `wandering_mortal`
2. LitPixel 尝试加载 `concept_wandering_mortal.webp` → **404**
3. Fallback 到 `_getNpcPortrait(ds_bloodrose)` → `card_dieyi_xianzi_pc98.png` ✅

**后果**: 第2步浪费一次网络请求并产生控制台报错，但第3步降级成功。玩家看不到白屏，但开发者控制台会刷404。

**✅ 已修复**：`_npcPortraitMap` 新增 `wandering_mortal: card_sunian_mortal_pc98.png` 兜底。

**⚠️ 残留问题**：LitPixel 路径对 ds_* 仍然会尝试加载不存在的 `wandering_mortal` 纹理。不影响渲染结果，但浪费一次加载。建议后续将 `_toLitPixelCharId` 中 ds_* 映射改为返回 `null` 并让调用方跳过 LitPixel。

---

## 三、验证通过的映射（无漏洞）

| NPC ID | _npcPortraitMap | _toLitPixelCharId | concept_*.webp | pc98 card |
|--------|:-:|:-:|:-:|:-:|
| bai_ren | ✅ | bai_ren_zhenren | ✅ | ✅ |
| bai_luoxuan | ✅ | bai_luoxuan | ✅ | ✅ |
| jian_linger | ✅ | jian_linger | ✅ | ✅ |
| mu_qinglan | ✅ | mu_qinglan | ✅ | ✅ |
| yin_xue | ✅ | yin_xue | ✅ | ✅ |
| jiuwei_suyue | ✅ | jiuwei_suyue | ✅ | ✅ |
| **jiuwei** (短) | ✅ **已修复** | ✅ **已修复** | — | — |
| tianji_laoren | ✅ | tianji_laoren | ✅ | ✅ |
| tian_ji (短) | ✅ → tianji_laoren | ✅ → tianji_laoren | ✅ | — |
| xuesha_laozu | ✅ | xuesha_laozu | ✅ | ✅ |
| xue_sha (短) | ✅ → xuesha_laozu | ✅ → xuesha_laozu | ✅ | — |
| ds_bloodrose | ✅ → dieyi_xianzi | ⚠️ → wandering_mortal | ❌ | ✅ |
| ds_moonmist | ✅ → liu_ruyan | ⚠️ → wandering_mortal | ❌ | ✅ |
| ds_spiritvine | ✅ → hua_xiangrong | ⚠️ → wandering_mortal | ❌ | ✅ |
| ds_demoness | ✅ → youming_shusheng | ⚠️ → wandering_mortal | ❌ | ✅ |
| ds_traveler | ✅ → mortal | ⚠️ → wandering_mortal | ❌ | ✅ |
| ds_alchemist | ✅ → liu_qingluan | ⚠️ → wandering_mortal | ❌ | ✅ |
| ds_bandit_queen | ✅ → swordsman_wanderer | ⚠️ → wandering_mortal | ❌ | ✅ |
| wandering_mortal | ✅ **已修复** → mortal | ⚠️ → 自身 | ❌ | — |
| mortal | ✅ | — | — | ✅ |
| wandering_swordsman | ✅ | — | — | ✅ |
| liu_qingluan | ✅ | — | — | ✅ |
| shi_potian | ✅ | — | — | ✅ |
| dieyi_xianzi | ✅ | — | — | ✅ |
| youming_shusheng | ✅ | — | — | ✅ |
| liu_ruyan | ✅ | — | — | ✅ |
| hua_xiangrong | ✅ | — | — | ✅ |

---

## 四、修复汇总

| # | 文件 | 行数 | 变更 |
|---|------|------|------|
| 1 | src/ui.js `_npcPortraitMap` | 1416 | + `jiuwei: concept_jiuwei_suyue.webp` |
| 2 | src/ui.js `_toLitPixelCharId` | 1637 | + `jiuwei: 'jiuwei_suyue'` |
| 3 | src/ui.js `_getUnlockedPortraitStages` | 2413 | alias新增 `jiuwei: 'jiuwei_suyue'` |
| 4 | src/ui.js `_renderCardPortrait` | 1530 | isFox + `\|\| npcId === 'jiuwei'` |
| 5 | src/ui.js `_renderCardPortrait` | 1597 | isFox + `\|\| npcId === 'jiuwei'` |
| 6 | src/ui.js `_renderCardPortraitForStage` | 2518 | + `\|\| npcId === 'jiuwei'` |
| 7 | src/ui.js `_npcPortraitMap` | 1422 | + `wandering_mortal: card_sunian_mortal_pc98.png` |

---

## 五、结论

**现在所有24个已使用NPC ID（8核心 + 7 ds_* + 辅助角色）的立绘加载链路均已打通**，不存在「完全没有贴图」的路径。最严厉的三个漏洞（jiuwei错显白落霜、wandering_mortal无兜底）已全部修复。
