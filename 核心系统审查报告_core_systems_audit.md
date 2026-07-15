# 核心系统审查报告（core_systems_audit）

> **审查日期**: 2026-07-01  
> **审查维度**: 核心系统（GameLogic、GameStateManager、FlowDirector、CardSystem、EffectService、Container、DataLoader、EventBus）  
> **基准报告**: `游戏审查报告.md`（2026-07-01）

---

## 与已有审查报告的差异总览

| 问题编号 | 问题描述 | 状态 | 说明 |
|---------|---------|------|------|
| P0-1 | `GameStateManager.REALM_ORDER` 未定义 | **仍未修复** | 世界事件触发仍会导致崩溃 |
| P0-2 | `karmaGood`/`karmaBad` 路由错误 | ✅ 已修复 | `EffectService` 已正确映射到 `addAttribute` |
| P0-3 | `health` 硬上限 100 | ✅ 已修复 | `setAttribute` 已使用动态 `maxHealth` |
| P0-4 | 死亡卡系统被绕过 | **仍未修复** | `makeChoice` 仍拦截死亡状态 |
| P1-1 | `spiritStoneBonus` 永远为 0 | ✅ 已修复 | 公式已改为 `Math.floor(value * spiritStoneBonus)` |
| P1-2 | UI 直接访问 `flowDirector._currentPhase` | ❓ 待确认 | 不在本次审查文件范围内 |
| P1-3 | 商店/集市跳过回合结算 | **仍未修复** | `return true` 提前退出仍在 |
| P1-5 | 善恶因激增检测字段错误 | ✅ 已修复 | `_checkAttrSurges` 已正确读取 `attributes` |
| P1-6 | `realmOrder` 硬编码错误境界名 | **仍未修复** | `formation`/`void` 仍未改为 `deity` |
| P1-7 | 兜底卡使用未定义的 `exp` | ✅ 已修复 | `EffectService` 已注册 `exp → cultivation` 映射 |
| P2-3 | `gameState._pendingMarket` 访问错误 | **仍未修复** | 存储位置不一致 |
| P2-4 | `hasFlag` 语义错误 | **仍未修复** | `!!this.flags[key]` 仍在 |
| P2-5 | 丹药资源字段命名不一致 | ⚠️ 需重新评估 | 当前调用约定一致，原报告位置可能已过时 |
| P2-6 | 战斗外寿命扣除绕过 `addResource` | **仍存在** | `gameState.resources.lifespan -= 1` 仍在 |
| P2-9 | `getActiveSeeds` 方法缺失 | **仍未修复** | 可选链保护下静默失效 |
| P3-6 | `instance` 变量未使用 | **仍未修复** | 单例残留仍在 |

---

## P0 级问题（立即修复）

### P0-1: `GameStateManager.REALM_ORDER` 未定义 → 世界事件触发崩溃（仍未修复）
- **位置**：`src/game.js:1017, 1021`（`_pickWorldEvent`）
- **现象**：当 `_tickWorldEvents` 触发时，调用 `GameStateManager.REALM_ORDER.indexOf(...)`，但 `GameStateManager` **从未定义静态属性 `REALM_ORDER`**，导致 `undefined.indexOf` 抛出 `TypeError`，游戏直接卡死。
- **根因**：`GameStateManager` 类中没有定义 `REALM_ORDER` 静态属性，而 `_pickWorldEvent` 直接访问了它。
- **修复建议**：
  ```javascript
  // 方案A：在 GameStateManager 中添加静态属性
  static REALM_ORDER = ['qi', 'foundation', 'golden', 'nascent', 'deity', 'tribulation'];
  
  // 方案B：改为使用实例配置（推荐，避免硬编码）
  const realmOrder = gameState.config.realms ? gameState.config.realms.order : ['qi', 'foundation', 'golden', 'nascent', 'deity', 'tribulation'];
  const realmIndex = realmOrder.indexOf(gameState.realm);
  ```

### P0-NEW: `_applyPassiveRegen` 硬编码 health 上限 100 → 气血上限加成再次失效
- **位置**：`src/game.js:1061-1064`
- **现象**：`setAttribute` 已修复为使用动态 `maxHealth`（P0-3 已修复），但**法宝/功法被动回血逻辑仍硬编码 100 作为上限**：
  ```javascript
  if (hpRegen > 0 && gameState.attributes.health < 100) {
    const healAmount = Math.min(hpRegen, 100 - gameState.attributes.health);
  ```
  当 `maxHealth > 100` 时（如体修遗产加成到 130），被动回血上限被错误限制为 100，超出部分无效。
- **根因**：P0-3 的修复只覆盖了 `setAttribute`，遗漏了 `_applyPassiveRegen` 中的上限计算逻辑。
- **修复建议**：
  ```javascript
  const maxHp = gameState.maxHealth || 100;
  if (hpRegen > 0 && gameState.attributes.health < maxHp) {
    const healAmount = Math.min(hpRegen, maxHp - gameState.attributes.health);
    gameState.addAttribute('health', healAmount);
  }
  ```

### P0-4: 死亡卡系统被完全绕过 → 玩家永远看不到死亡叙事（仍未修复）
- **位置**：`src/game.js:518` + `src/ui.js:244-247`
- **现象**：`makeChoice` 第一行 `if (gameState.dead) return false;` 拦截了所有死亡状态下的选择。虽然 `checkDeath()` 检测到死亡后会设置 `currentCard = cardSystem.draw()`（返回精心构造的死亡叙事卡），但玩家点击任何选择时都会被第一行拦截。同时 `UI.renderGame()` 检测到死亡后直接覆盖为 `death-screen`。
- **根因**：死亡处理在 `draw()`（构造死亡卡）和 `makeChoice`（拦截选择）之间不一致。
- **修复建议**：
  ```javascript
  // 方案A：移除 makeChoice 中的前置拦截，改为在死亡卡选择后进入 death-screen
  makeChoice(direction) {
    // if (gameState.dead) return false;  // 移除此行
    
    const card = this.getCurrentCard();
    
    // ... 处理选择 ...
    
    // 死亡后只接受转世/重开选择
    if (gameState.dead && !choice.effects?.reincarnate && !choice.effects?.restart) {
      return false;
    }
    
    // ... 其余逻辑 ...
  }
  ```

---

## P1 级问题（严重缺陷）

### P1-3: 商店/集市选择跳过整个回合结算（仍未修复）
- **位置**：`src/game.js:643-674`
- **现象**：`choice.openShop` 和 `choice.openMarket` 分支使用 `return true` 提前退出，**跳过了**：
  - 寿元消耗（`_shouldConsumeLifespan`）
  - 因果计时推进（`karmaSystem.tick()`）
  - NPC 情绪衰减（`npcSystem._tick()`）
  - 法宝被动回血（`_applyPassiveRegen`）
  - 道侣危机检测（`_checkCompanionCrisis`）
  - 选择回响（`_plantChoiceEcho`）
  - 世界事件推进（`_tickWorldEvents`）
  - 故事线程推进（`threadEngine.tick`）
- **根因**：商店/集市分支设计为"暂停卡牌流"，但实现方式过于粗暴，直接 return 跳过了所有回合结算逻辑。
- **修复建议**：
  ```javascript
  // 将商店/集市分支改为设置标志位，不提前 return
  if (choice.openShop) {
    gameState.cardsPlayed.push(card.id);
    gameState.turn++;
    this._shopActive = true;  // 设置标志
    eventBus.emit('shop:open', { ... });
    // 继续执行到函数末尾，让回合结算正常进行
  }
  // 在 shop:closed 事件处理中清除标志并推进卡牌
  ```

### P1-6: CardSystem 商店触发硬编码错误境界名（仍未修复）
- **位置**：`src/systems/CardSystem.js:379`
- **现象**：`realmOrder = ['qi', 'foundation', 'golden', 'nascent', 'formation', 'void', 'tribulation']`。配置中实际不存在 `formation` 和 `void`，正确应为 `deity`。当玩家处于 `deity` 境界时，`indexOf('deity')` 返回 `-1`，虽然代码通过 `else` 分支勉强能跑，但属于**数据与硬编码不一致**。
- **根因**：硬编码数组与 `realms.json` 配置不同步。
- **修复建议**：
  ```javascript
  // 从配置动态读取
  const realmOrder = gameState.config.realms ? gameState.config.realms.order : ['qi', 'foundation', 'golden', 'nascent', 'deity', 'tribulation'];
  ```

### P1-NEW: `_checkEffectCost` 中 lifespan 检查逻辑错误 → 最后 1 年寿命无法使用
- **位置**：`src/game.js:984-988`
- **现象**：
  ```javascript
  if (effects.lifespan !== undefined && effects.lifespan < 0) {
    if (gameState.resources.lifespan + effects.lifespan <= 0) {
      return false;
    }
  }
  ```
  使用 `<= 0` 而非 `< 0`。当寿命仅剩 1 年时（`lifespan = 1`），任何消耗 1 年寿命的效果（`effects.lifespan = -1`）会被错误阻止，因为 `1 + (-1) = 0`，`0 <= 0` 为 `true` → `return false`。
- **根因**：边界条件错误。应允许寿命降到 0（刚好耗尽），但不应允许负值。
- **修复建议**：将 `<= 0` 改为 `< 0`。

### P1-NEW: EffectService 缺少 `restart` handler → "燃魂一击"无效
- **位置**：`src/services/EffectService.js`（全局）+ `src/systems/CardSystem.js:1145`
- **现象**：`_buildFallbackDeathCard` 中提供 `"拒绝天命，燃魂一击"` 选项，其效果为 `effects: { restart: true }`，但 `EffectService` 中**从未注册 `restart` 的 handler**。玩家选择后无任何效果。
- **根因**：EffectService 的 handler 注册不完整。
- **修复建议**：
  ```javascript
  this.handlers.set('restart', () => {
    // 重开逻辑：重置游戏状态
    gameState.reset(false);
    gameState.dead = false;
    gameState.deadReason = '';
    // 触发重新开始事件
    eventBus.emit('game:restart', {});
  });
  ```

### P1-NEW: `makeChoice` 死亡处理流程断裂 → 死亡卡"可看不可选"
- **位置**：`src/game.js:518, 893-899`
- **现象**：`checkDeath()` 在 makeChoice 末尾检测到死亡时，设置 `this.currentCard = cardSystem.draw()`（返回死亡卡），然后 `return true`。但**下一次**玩家调用 `makeChoice` 时，第一行 `if (gameState.dead) return false` 会拦截所有选择。玩家能看到死亡卡 UI，但永远无法点击选择。
- **根因**：单次死亡处理被拆分到两次 `makeChoice` 调用中，第二次被全局拦截。
- **修复建议**：同 P0-4，移除 `makeChoice` 开头的全局死亡拦截，改为在死亡卡选择时只拦截非转世选项。

---

## P2 级问题（体验问题）

### P2-3: `gameState._pendingMarket` 访问错误对象（仍未修复）
- **位置**：`src/systems/CardSystem.js:345`
- **现象**：CardSystem 检查 `gameState._pendingMarket`，但实际市场卡存储在：
  - `flowDirector._pendingFlags.market`（当 flowDirector 存在时，通过 `flowDirector.setPending('market', mkt)` 设置，见 `src/game.js:809`）
  - `gameLogic._pendingMarket`（当 flowDirector 不存在时的 fallback，见 `src/game.js:810`）
  `gameState` 上从未定义 `_pendingMarket` 字段，此代码分支**永远不可达**。
- **根因**：变量存储位置不一致。幸运的是 FlowDirector 的 P20 优先级已处理市场卡，此后备逻辑不影响功能，但属于脆弱的代码。
- **修复建议**：统一存储位置，或在 CardSystem 中从正确的来源读取。

### P2-4: `hasFlag` 语义错误（仍未修复）
- **位置**：`src/core/GameStateManager.js:203-205`
- **现象**：
  ```javascript
  hasFlag(key) {
    return !!this.flags[key];
  }
  ```
  当 flag 被显式设为 `false` 时（如 `setFlag('someQuestActive', false)`），`!!false` 为 `false`，flag 被视为"不存在"。但 `checkFlags` 中 `value === null` 的语义是"只检查存在性，不关心值"。
- **根因**：使用真值检查代替存在性检查。
- **修复建议**：
  ```javascript
  hasFlag(key) {
    return this.flags.hasOwnProperty(key);
  }
  ```

### P2-6: 战斗外寿命扣除绕过 `addResource`（仍存在）
- **位置**：`src/game.js:822`
- **现象**：`gameState.resources.lifespan -= 1;` 直接修改 lifespan，不经过 `addResource` 的 `Math.max(0, ...)` 保护。虽然当前逻辑不会触发负值，但违反了数据主权约定。
- **根因**：便捷性写法，未遵循数据操作规范。
- **修复建议**：改为 `gameState.addResource('lifespan', null, -1);`

### P2-9: `getActiveSeeds` 方法缺失（仍未修复）
- **位置**：`src/game.js:829`
- **现象**：`karmaSystem.getActiveSeeds && karmaSystem.getActiveSeeds('lifespanWaste')` 被调用，但 `KarmaSystem` 中未定义此方法。由于可选链保护（`&&`），不会崩溃，但导致"避免重复种植 lifespanWaste 种子"的保护逻辑完全失效。
- **根因**：功能设计在 game.js 中引用，但未在 KarmaSystem 中实现。
- **修复建议**：在 KarmaSystem 中实现 `getActiveSeeds(seedId)` 方法，或改用 `gameState.karmaSeeds.filter(s => s.id === seedId)`。

### P2-NEW: `GameStateManager.reset()` 未清理动态属性
- **位置**：`src/core/GameStateManager.js:37-103`
- **现象**：`reset()` 方法清理了 `attributes`、`resources`、`flags` 等核心字段，但未清理动态添加的属性如 `_pendingReincBonus`。虽然 `_reincarnate()` 在使用后会将其设为 `null`，但如果玩家通过其他方式触发 reset（如"燃魂一击"重开），这些动态属性可能残留。
- **根因**：动态属性缺乏统一的生命周期管理。
- **修复建议**：在 `reset()` 中显式清理 `_pendingReincBonus = null` 等动态属性。

### P2-NEW: `EventBus.collect` 中有未使用的变量
- **位置**：`src/core/EventBus.js:88-106`
- **现象**：`requests`、`originalEmit`、`collector` 三个变量被声明但从未使用。
- **根因**：代码重构后未清理残留变量。
- **修复建议**：删除未使用的变量声明。

---

## P3 级问题（设计债务）

### P3-6: FlowDirector 中 `instance` 变量未使用（仍未修复）
- **位置**：`src/systems/FlowDirector.js:125`
- **现象**：`var instance = null;` 从未赋值或使用，疑似废弃的单例模式残留。
- **根因**：代码重构遗留。
- **修复建议**：删除该行。

### P3-NEW: FlowDirector 饥饿算法 `_markSourceUsed` 映射不完整
- **位置**：`src/systems/FlowDirector.js:530-558`
- **现象**：`sourceMap` 将 `breakthrough` 映射为 `normal`，导致每次突破卡牌后，「普通卡」饥饿计数器被重置，但 `breakthrough` 本身没有独立的饥饿追踪。这意味着突破卡出得越少，普通卡的饥饿补偿越强，但突破卡本身的饥饿状态从未被记录。
- **根因**：sourceMap 设计不完整，遗漏了 `breakthrough` 的独立追踪。
- **修复建议**：为 `breakthrough` 添加独立的饥饿追踪条目。

### P3-NEW: `_applyPassiveRegen` 与 `_getAggregatedPassives` 代码重复
- **位置**：`src/game.js:1041-1094`
- **现象**：两个函数都遍历 `treasureSystem.getPassiveBonuses()` 和 `pathSkillSystem.getPassiveBonuses()`，提取相同的属性集合。`_getAggregatedPassives` 本质上是 `_applyPassiveRegen` 的计算部分被抽取出来，但没有被 `_applyPassiveRegen` 复用。
- **根因**：功能演进中重复实现。
- **修复建议**：让 `_applyPassiveRegen` 调用 `_getAggregatedPassives` 获取加成值，然后统一应用。

### P3-NEW: `makeChoice` 中多个提前 return 导致流程碎片化
- **位置**：`src/game.js:517-926`
- **现象**：商店（643）、集市（655）、心魔（523）、命盘轮转（529）、战斗预警（542）、秘境分叉（570）等都有独立的 `return true`，每个分支都需要单独维护 `gameState.cardsPlayed.push()` 和 `gameState.turn++`。这使得统一的回合结算逻辑被严重分散，极易在新增分支时遗漏关键步骤。
- **根因**：架构设计缺陷，缺乏统一的"回合结算钩子"机制。
- **修复建议**：引入回合结算钩子模式——所有特殊分支只设置标志/状态，在函数末尾统一执行回合结算。

---

## 已确认修复的问题

| 问题 | 修复位置 | 验证方式 |
|-----|---------|---------|
| **P0-2: karmaGood/karmaBad 路由** | `src/services/EffectService.js:131-133` | `handlers.set('karmaGood', ...)` 和 `handlers.set('karmaBad', ...)` 均路由到 `addAttribute` |
| **P0-3: health 硬上限** | `src/core/GameStateManager.js:113-115` | `if (name === 'health') maxVal = this.maxHealth;` |
| **P1-1: spiritStoneBonus 永远为 0** | `src/services/EffectService.js:165-166` | 公式已改为 `Math.floor(value * spiritStoneBonus)` |
| **P1-5: 善恶因激增检测字段错误** | `src/game.js:154-179` | `_checkAttrSurges` 已正确从 `gameState.attributes` 读取 |
| **P1-7: 兜底卡 exp 无效** | `src/services/EffectService.js:176` | 已注册 `exp → cultivation` 映射 |

---

## 新发现问题汇总

本次审查共发现 **4 个新 P0/P1 级问题**、**3 个新 P2 级问题**、**3 个新 P3 级问题**：

**新增 P0**：
- P0-NEW: `_applyPassiveRegen` 硬编码 health 上限 100（P0-3 修复的遗漏）

**新增 P1**：
- P1-NEW: `_checkEffectCost` 中 lifespan 检查 `<= 0` 应为 `< 0`
- P1-NEW: EffectService 缺少 `restart` handler
- P1-NEW: makeChoice 死亡处理流程断裂（与 P0-4 相关）

**新增 P2**：
- P2-NEW: `GameStateManager.reset()` 未清理动态属性
- P2-NEW: `EventBus.collect` 未使用变量

**新增 P3**：
- P3-NEW: FlowDirector `_markSourceUsed` 映射不完整
- P3-NEW: 被动回血代码重复
- P3-NEW: makeChoice 流程碎片化

---

> **审查结论**：已有报告中的 4 个 P0 级问题中，2 个已修复（karma路由、health上限），**2 个仍未修复**（REALM_ORDER未定义、死亡卡被绕过）。本次审查新增 1 个 P0 级问题（_applyPassiveRegen 硬编码上限遗漏）和 3 个 P1 级问题。建议**立即修复** P0-1、P0-4、P0-NEW、P1-3、P1-6 以解除核心机制崩溃风险。
