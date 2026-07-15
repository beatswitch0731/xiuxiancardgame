# L6 法宝体系重设计 — 完成报告

> 版本: v2.0 | 日期: 2026-06-29

## 核心变更

**去除「战斗动词」按钮，改为三层模型**：属性 + 特性(trait) + 机制(CombatSystem钩子)

法宝不增加操作复杂度。你仍然在攻击、格挡、切换架势——但装备不同法宝后，每次攻击的后果变了。

## 三层模型

| 层 | 存储位置 | 示例 |
|----|---------|------|
| **属性** | treasures.json `passive` | ATK+8, DEF+12, critRate+5% |
| **特性** | treasures.json `trait` | 先手, 破甲, 妖噬, 镜返, 空蝉... |
| **机制** | CombatSystem.js 钩子 | `_calcDamage`, `_resolveBlock`, `_endTurn`... |

## 15个Trait × 战斗5层联动

### 武器 trait → `_calcDamage()`
| trait | 法宝 | 机制 |
|-------|------|------|
| 先手 | 剑心佩 | 每场战斗首次攻击 ×1.5 |
| 血战 | 血玉扳指 | HP<50% 时攻击 ×1.5 |
| 破甲 | 破魂锥 | 无视50%敌方防御 |
| 妖噬 | 炼妖壶 | 30%伤害吸血 |

### 防具 trait → `_resolveBlock()` / `_enemyTurn()` / `_endTurn()`
| trait | 法宝 | 机制 |
|-------|------|------|
| 镜返 | 冰魄镜甲 | 完美格挡时反射50%伤害 |
| 空蝉 | 虚空袈裟 | HP<20%时自动闪避下一次攻击 |
| 坚盾 | 玄铁甲 | 格挡窗口完美/良好区扩大30% |
| 灵涌 | 灵纹法袍 | 每回合额外+1灵力回复 |

### 饰品 trait → `_endTurn()` / 事件系统
| trait | 法宝 | 机制 |
|-------|------|------|
| 续命 | 续命珠/灵泉葫芦 | 每10战斗回合自动回血 |
| 镇魂 | 定魂玉 | mindResist (passive) |
| 定心 | 万年玄冰 | daoResist (passive) |

## 修改文件

| 文件 | 变更量 | 内容 |
|------|--------|------|
| `data/shops/treasures.json` | 重写 | 25件法宝→"trait"替换战斗"active"，新增灵泉葫芦为饰品 |
| `src/systems/TreasureSystem.js` | +30行 | getEquippedTraits(), hasTrait() |
| `src/systems/CombatSystem.js` | +60行 | _traits追踪, _calcDamage(破甲/血战/先手), _applyLifesteal(妖噬), _resolveBlock(镜返), _enemyTurn(空蝉), _endTurn(灵涌/续命) |
| `src/ui.js` | +10行 | 坚盾扩大格挡窗口, 格挡标签显示🛡坚盾 |
| `docs/GDD_TREASURE_DEATH_BALANCE.md` | 2.4节重写 | 三层模型设计文档 v2.0 |

## 验证

- 语法验证: 4 JS + 1 JSON ✓
- 功能测试: 先手✓ 灵涌✓ 空蝉✓ 妖噬✓ 破甲✓ 血战✓

## 战斗系统六层状态

| 层 | 名称 | 状态 |
|----|------|------|
| L1 | 灵力脉冲 | ✅ 完成 |
| L2 | 架势切换 | ✅ 完成 |
| L3 | 格挡时机 | ✅ 完成 |
| L4 | 连击链 | ✅ 完成 |
| L5 | 参数整合 | ✅ 完成 |
| L6 | 法宝机制 | ✅ v2.0 三层模型完成 |
