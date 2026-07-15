# P0 内容补全报告

## 概述

本次补全解决了 GDD 审查中发现的 4 个阻断级问题，让游戏能够完整跑通 **筑基→金丹** 并修复了所有核心系统的闭环。

---

## 1. 金丹期卡池 (15 张)

| ID | 标题 | 类型 | 功法 |
|----|------|------|------|
| g_coreFormed | 金丹初成 | 起始 (once) | 通用 |
| g_swordIntent | 剑意化形 | 专属 | 剑修 |
| g_spellGreat | 术法大成 | 专属 | 法修 |
| g_bodyGold | 金身初显 | 专属 | 体修 |
| g_pillSecret | 古丹方重现 | 专属 | 丹修 |
| g_ruins | 上古遗迹 | 秘境入口 | 通用 |
| g_veinFight | 灵脉之争 | 冲突 | 通用 |
| g_tribulationOmen | 天劫预兆 | 精神 | 通用 |
| g_demonSeed | 魔种暗生 | 诱惑 | 通用 |
| g_elderMystery | 长老的秘密 | 社交 | 通用 |
| g_daoConference | 论道大会 | 社交 | 通用 |
| g_oldFriend | 故人来访 | 神秘 | 通用 |
| g_forbiddenTome | 禁术诱惑 | 诱惑 (条件触发) | 通用 |
| g_fateChoice | 命运歧路 | 宿命 (once) | 通用 |
| break_golden | 金丹圆满 | 瓶颈 | 通用 |

**秘境**: 太古遗迹 (ancientRuins) — 4 节点秘境，含遗迹回声/守护兽/岔路/核心。

---

## 2. foxGratitude 因果闭环

**问题**: 白狐支线完成后种下 `foxGratitude` 种子，但 `karmaCardMap` 中没有对应映射 → 种子发芽但找不到卡牌。

**修复**:
- 新增因果卡 `f_foxGratitude`：「白狐报恩」— 筑基期触发，白落霜化形报恩
- 新增映射 `foundation.json` → `karmaCards.foxGratitude: "f_foxGratitude"`
- 数据流: 白狐支线完成(炼气) → 种子延迟10轮 → 筑基期发芽 → 白落霜报恩/收为道侣

---

## 3. 势力扩大

### 药王谷 (shennong_dangu)
- 新增 `pill_0` 筑基期事件「丹道入门试」— pill 专属
- 总事件数: 1 → **2** (foundation, nascent)

### 武盟 (wumeng_alliance) — **新建**
- 3 子派系: 钢骨流(横炼) / 气血流(内壮) / 雷体流(淬雷)
- 3 事件: 入门试(foundation) / 金身试炼(golden) / 雷体之争(nascent)
- 1 暗流: 武盟雷体之争 (4 阶段)
- body 功法在筑基期即可触发专属势力事件

**势力总数**: 5 → **6**

---

## 4. NPC 秘密/深层信息

| NPC | secrets | knownInfo | gossip | 状态 |
|-----|---------|-----------|--------|------|
| 白刃真人 | 3 | 4 | 3 | ✅ 已有 |
| **白落霜** | **3** | **4** | **3** | 🆕 全部新增 |
| **剑灵儿** | **3** | **4** | **3** | 🆕 全部新增 |
| 慕青岚 | 3 (曾2) | 4 | 3 | 🔧 补 lvl3 |
| **殷血** | **3** | **4** | **3** | 🆕 全部新增 |
| 九尾溯月 | 3 | - | - | 已有 |
| 天机老人 | 3 | - | - | 已有 |
| 血煞老祖 | 3 | - | - | 已有 |

---

## 测试结果

**端到端测试**: 25/25 通过 ✅

```
✅ foxGratitude 因果种子发芽 → f_foxGratitude 白狐报恩
✅ 金丹卡池 15 张全部可用
✅ 4 功法专属卡各 1 张
✅ 突破卡 break_golden 存在
✅ 秘境卡 ruines_ancient 存在
✅ 药王谷 foundation 级事件触发成功
✅ 武盟 foundation 级事件触发成功
✅ 8 NPC 全部拥有 3 层秘密
✅ 4 目标 NPC 拥有完整 knownInfo
```

---

## 文件变更

| 文件 | 操作 |
|------|------|
| `data/cards/golden.json` | 🆕 新建 |
| `data/cards/foundation.json` | 🔧 新增 1 卡 + karmaCards |
| `data/world/factions.json` | 🔧 新增 武盟 + 药王谷事件 |
| `data/npcs/core_npcs.json` | 🔧 4 NPC 秘密/信息 |
| `index.html` | 🔧 DATA_MODULES 重建 (50KB) |
| `tools/test_p0.js` | 🆕 端到端验证脚本 |
