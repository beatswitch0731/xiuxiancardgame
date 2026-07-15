## 审查维度：core_systems_audit（核心系统审查）

> **审查日期**: 基于已有报告对比验证 + 新代码扫描  
> **审查范围**: `src/game.js`, `src/core/GameStateManager.js`, `src/core/Container.js`, `src/core/DataLoader.js`, `src/core/EventBus.js`, `src/services/EffectService.js`, `src/systems/FlowDirector.js`, `src/systems/CardSystem.js`  
> **已有报告**: `游戏审查报告.md` (2026-07-01)

---

## 与已有审查报告的差异总览

| 已有问题 | 状态 | 说明 |
|---|---|---|
| **P0-1** REALM_ORDER 未定义 | ❌ **未修复** | `GameStateManager` 仍无静态属性 `REALM_ORDER` |
| **P0-2** karmaGood/karmaBad 路由错误 | ✅ **已修复** | `EffectService` 已正确注册 handler，路由到 `addAttribute` |
| **P0-3** health 硬上限 100 | ✅ **已修复** | `setAttribute` 已使用 `this.maxHealth` 动态上限 |
| **P0-4** 死亡卡被 UI 绕过 | ❌ **未修复** | `makeChoice` 开头仍拦截 `gameState.dead`，死亡卡无法交互 |
| **P1-1** spiritStoneBonus 永远为 0 | ✅ **已修复** | `EffectService` 已改为 `value * spiritStoneBonus`（不再 `/100`） |
| **P1-3** 商店/集市跳过回合结算 | ❌ **未修复** | `openShop`/`openMarket` 分支仍提前 `return true` |
| **P1-5** 善恶因激增检测失效 | ✅ **已修复** | `_checkAttrSurges` 已从 `attributes` 读取（非 `resources`） |
| **P1-6** realmOrder 硬编码错误 | ❌ **未修复** | `CardSystem.js:379` 仍包含 `formation`/`void`（非 `deity`） |
| **P1-7** 兜底卡 `exp` 无效 | ✅ **已修复** | `EffectService` 已注册 `exp` handler，映射到 `cultivation` |
| **P2-1** 寿元危机种子重复种植 | ❌ **未修复** | `karmaSystem.getActiveSeeds` 仍不存在，保护逻辑失效 |
| **P2-4** `hasFlag` 语义错误 | ❌ **未修复** | `!!this.flags[key]` 仍导致 `false` 被视为不存在 |
| **P2-6** 寿命扣除绕过 `addResource` | ❌ **未修复** | `gameState.resources.lifespan -= 1` 仍直接扣除 |
| **P2-13** `_markSourceUsed` 映射不完整 | ❌ **未修复** | `breakthrough` 仍映射为 `normal`，无独立饥饿追踪 |
| **P3-6** `instance` 变量未使用 | ❌ **未修复** | `var instance = null;` 仍为死代码 |
| **P3-7** `_loadUnlocks` 前向兼容重复 | ❌ **未修复** | 多个 `if (!parsed.xxx)` 仍分散存在 |

---

## P0 级问题（立即修复）

### 1. 世界事件触发 → 游戏崩溃（REALM_ORDER 未定义）
- **位置**: `src/game.js:1017` (`_pickWorldEvent`)  
  `src/core/GameStateManager.js`（缺失静态属性）
- **现象**: `_pickWorldEvent` 调用 `GameStateManager.REALM_ORDER.indexOf(...)`，但 `GameStateManager` 类**从未定义 `REALM_ORDER`** 静态属性，导致 `undefined.indexOf` 抛出 `TypeError`，游戏直接崩溃。
- **根因**: 重构时未在 `GameStateManager` 中添加静态属性，或 `_pickWorldEvent` 未改为使用 `gameState.config.realms.order`。
- **修复建议**:
  ```javascript
  // 方案A：在 GameStateManager 中添加
  static REALM_ORDER = ['qi', 'foundation', 'golden', 'nascent', 'deity', 'tribulation'];
  
  // 方案B（推荐）：改为使用配置
  const realmOrder = gameState.config.realms?.order || ['qi', 'foundation', 'golden', 'nascent', 'deity', 'tribulation'];
  const realmIndex = realmOrder.indexOf(gameState.realm);
  ```

### 2. 死亡卡系统 → 仍被完全绕过（未修复的 P0-4）
- **位置**: `src/game.js:518` (`makeChoice`) + `src/systems/CardSystem.js:130-144` (`draw()`)
- **现象**: `CardSystem.draw()` 在死亡时精心构造死亡叙事卡（`death_dao_collapse` 等），但 `makeChoice` 第 518 行立即 `if (gameState.dead) return false;` 拦截。玩家永远看不到死亡卡，死亡卡叙事系统**仍被完全绕过**。同时 `checkDeath()` 后（第 893 行）设置 `this.currentCard = cardSystem.draw()`，但下一次 `makeChoice` 直接拦截。
- **根因**: 死亡处理逻辑存在两层冲突：`checkDeath` 后试图展示死亡卡，但 `makeChoice` 入口无条件拦截。
- **修复建议**:
  ```javascript
  // 方案A：移除入口拦截，改为在死亡卡选择后处理
  makeChoice(direction) {
    // if (gameState.dead) return false; // ← 删除此行
    const card = this.getCurrentCard();
    // 如果是死亡卡，处理选择后进入死亡屏
    if (card.type === 'DEATH') {
      // ... 处理死亡卡选择，然后进入 death-screen
    }
  }
  
  // 方案B：干脆删除死亡卡系统，直接用 death-screen 减少维护负担
  ```

---

## P1 级问题（严重缺陷）

### 3. 商店/集市选择 → 仍跳过整个回合结算（未修复的 P1-3）
- **位置**: `src/game.js:642-675` (`makeChoice`)
- **现象**: `choice.openShop` 和 `choice.openMarket` 分支仍使用 `return true` 提前退出，**跳过了**以下关键流程：
  - 寿元消耗 (`_shouldConsumeLifespan`)
  - 因果计时推进 (`karmaSystem.tick()`)
  - NPC 情绪衰减 (`npcSystem._tick()`)
  - 法宝被动回血 (`_applyPassiveRegen`)
  - 道侣危机检测 (`_checkCompanionCrisis`)
  - 选择回响 (`_plantChoiceEcho`)
  - 世界事件推进 (`_tickWorldEvents`)
- **根因**: 设计时将商店/集市视为"暂停卡牌流"的外部 UI，但回合生命周期管理未纳入。
- **修复建议**:
  ```javascript
  // 将商店/集市分支改为不提前 return，而是设置标志位
  let pausedForShop = false;
  if (choice.openShop) {
    gameState.cardsPlayed.push(card.id);
    gameState.turn++;
    eventBus.emit('shop:open', { ... });
    pausedForShop = true;
  }
  if (choice.openMarket) {
    gameState.cardsPlayed.push(card.id);
    gameState.turn++;
    eventBus.emit('shop:open', { market: true, ... });
    pausedForShop = true;
  }
  // 继续执行回合结算（寿元、因果、NPC等）
  if (!pausedForShop) {
    // 正常的 nextCard 逻辑
  }
  ```

### 4. FlowDirector 中 `for...in` 遍历 Map 导致额外卡池完全失效
- **位置**: `src/systems/FlowDirector.js:429-436` (`_drawNormalWithMood`)
- **现象**: `FlowDirector._drawNormalWithMood` 尝试使用 `for (var id in cardSystem.cardCache)` 遍历 `cardCache`。但 `cardCache` 是 **Map 对象**，`for...in` 不会迭代 Map 的键值对（只会遍历可枚举属性，Map 内部数据不暴露）。因此 `extraCards` 数组**永远为空**，所有通过 `_loadExtraModule` 加载的额外卡牌（魔道女修、转世回响、飞升后、跨线交织等）在 FlowDirector 模式下**永远不会被抽到**。
- **根因**: ES5 风格的 `for...in` 误用于 Map 数据结构。`CardSystem._drawNormal` 中正确使用了 `for...of`。
- **修复建议**:
  ```javascript
  // 错误
  for (var id in cardSystem.cardCache) { ... }
  
  // 正确（与 CardSystem._drawNormal 保持一致）
  for (const [id, card] of cardSystem.cardCache) {
    if (!poolIds.has(id) && card.realm && card.type !== 'DESTINY' && card.type !== 'BOTTLENECK') {
      extraCards.push(card);
    }
  }
  ```

### 5. CardSystem 硬编码 realmOrder 仍包含错误境界名（未修复的 P1-6）
- **位置**: `src/systems/CardSystem.js:379`
- **现象**: `realmOrder = ['qi', 'foundation', 'golden', 'nascent', 'formation', 'void', 'tribulation']`。配置中实际不存在 `formation` 和 `void`，而是 `deity`。当玩家处于 `deity` 境界时，`indexOf('deity')` 返回 `-1`，`realmIdx <= 1` 判断为 `true`（`-1 <= 1`），导致**化神期被误判为炼气/筑基期**（商店触发间隔 8 轮、概率 10%，而非 6 轮、15%）。
- **根因**: 硬编码的 realmOrder 与 `realms.json` 不一致，且未同步更新。
- **修复建议**:
  ```javascript
  const realmOrder = gameState.config.realms?.order || ['qi', 'foundation', 'golden', 'nascent', 'deity', 'tribulation'];
  ```

### 6. 死亡卡兜底选项"拒绝天命"完全无效
- **位置**: `src/systems/CardSystem.js:1144-1147` (`_buildFallbackDeathCard`)
- **现象**: 兜底死亡卡的右侧选项 `effects: { restart: true }`，但 `EffectService` **从未注册 `restart` handler**。玩家选择"拒绝天命，燃魂一击"后没有任何效果，UI 可能卡死或无事发生。
- **根因**: 新增兜底死亡卡时未同步添加 effect handler。
- **修复建议**:
  ```javascript
  // 在 EffectService._registerHandlers 中添加
  this.handlers.set('restart', () => {
    location.reload(); // 或跳转到开始页面
  });
  // 或者将 restart 改为 reincarnate: true，复用转世逻辑
  ```

### 7. 被动回血系统硬编码上限 100，与 maxHealth 不一致
- **位置**: `src/game.js:1061-1064` (`_applyPassiveRegen`)
- **现象**: `_applyPassiveRegen` 中 `gameState.attributes.health < 100` 和 `Math.min(hpRegen, 100 - gameState.attributes.health)` 硬编码了 100。虽然当前默认 `maxHealth = 3`，此代码不会触发错误（因为 3 < 100），但如果玩家通过转世遗产或技能将 `maxHealth` 提升到超过 100，回血将被**错误地截断在 100**。
- **根因**: P0-3 修复时只修改了 `setAttribute`，但漏改了 `_applyPassiveRegen` 中的回血逻辑。
- **修复建议**:
  ```javascript
  const maxHealth = gameState.maxHealth;
  if (hpRegen > 0 && gameState.attributes.health < maxHealth) {
    const healAmount = Math.min(hpRegen, maxHealth - gameState.attributes.health);
    gameState.addAttribute('health', healAmount);
  }
  ```

---

## P2 级问题（体验问题与数据不一致）

### 8. 寿元危机种子仍重复种植（未修复的 P2-1）
- **位置**: `src/game.js:828-830`
- **现象**: `karmaSystem.getActiveSeeds('lifespanWaste')` 方法**仍不存在**（`KarmaSystem.js` 中未定义）。`existing` 为 `undefined`，`!existing` 为 `true`，导致**每回合都会重复种植 `lifespanWaste` 种子**，直到寿元耗尽。
- **修复建议**: 在 `KarmaSystem` 中实现 `getActiveSeeds(id)` 方法，或改用 `gameState.karmaSeeds.filter(...)` 直接检查。

### 9. 寿命扣除仍绕过 `addResource`（未修复的 P2-6）
- **位置**: `src/game.js:822`
- **现象**: `gameState.resources.lifespan -= 1` 仍直接对 `lifespan` 做 `-=` 操作，不经过 `addResource` 的 `Math.max(0, ...)` 保护。
- **修复建议**: `gameState.addResource('lifespan', null, -1);`

### 10. `hasFlag` 语义错误（未修复的 P2-4）
- **位置**: `src/core/GameStateManager.js:203-205`
- **现象**: `hasFlag` 返回 `!!this.flags[key]`，当 flag 被显式设为 `false` 时会被视为「不存在」。`checkFlags` 中 `value === null` 的「仅检查存在」语义因此被破坏。
- **修复建议**: `return this.flags.hasOwnProperty(key);`

### 11. cultivation 等属性硬上限 100，后续境界存在潜在风险
- **位置**: `src/core/GameStateManager.js:111-117` (`setAttribute`)
- **现象**: `setAttribute` 对所有非 health/daoHeart 属性使用 `maxVal = 100`。`cultivation` 作为修为值，如果后续境界的 `cultivationThreshold` 超过 100（如元婴期需要 150），玩家**永远无法积累足够的修为**进行突破。
- **根因**: 未为 `cultivation` 设置动态上限（或根据当前境界阈值设置）。
- **修复建议**: 在 `setAttribute` 中为 `cultivation` 添加动态上限，或使用 `addAttribute` 时解除上限限制。

### 12. 缺少 delay 字段的因果种子永不发芽
- **位置**: `src/systems/CardSystem.js:694` (`_drawKarmaCard`)
- **现象**: `ready = seeds.filter(s => s.delay <= 0 && ...)`。如果某个 seed 没有 `delay` 字段（如通过某些代码路径直接 `push` 到 `karmaSeeds`），`undefined <= 0` 为 `false`，该种子**永远卡死在种子池中**，无法被移除或触发。
- **修复建议**: 使用 `(s.delay || 0) <= 0` 或种植时强制校验 delay 字段。

### 13. `_narrativeQueue` 在 FlowDirector 缺失时成为死队列
- **位置**: `src/game.js:865-873` (`makeChoice`)
- **现象**: 当 `flowDirector` 不存在时，`threadEngine.getNextThreadCard()` 返回的叙事卡被放入 `this._narrativeQueue`，但 `getCurrentCard()` 在 `!flowDirector` 时直接调用 `cardSystem.draw()`，**从不读取 `this._narrativeQueue`**。这些叙事卡被永久丢弃。
- **修复建议**: 在 `getCurrentCard` 的 `!flowDirector` 分支中检查 `this._narrativeQueue`。

### 14. `CardSystem._checkShopEncounter` 中 `itemCount` 死代码
- **位置**: `src/systems/CardSystem.js:406-407`
- **现象**: `itemCount = Math.min(items.length, 5)` 计算后从未使用，商店卡中未限制展示商品数量。
- **修复建议**: 在构建 `choices` 时使用 `itemCount`，或删除该变量。

---

## P3 级问题（设计债务）

### 15. `FlowDirector` 中 `instance` 变量未使用（未修复的 P3-6）
- **位置**: `src/systems/FlowDirector.js:125`
- **现象**: `var instance = null;` 声明后从未赋值或使用，疑似废弃的单例模式残留。
- **修复建议**: 删除该变量，或实现真正的单例模式。

### 16. `_loadUnlocks` 前向兼容逻辑分散（未修复的 P3-7）
- **位置**: `src/core/GameStateManager.js:453-458`
- **现象**: 多个 `if (!parsed.xxx) parsed.xxx = default` 的兼容逻辑，新字段不断增加时维护成本高。
- **修复建议**: 使用结构化合并函数或 JSON Schema 验证。

### 17. FlowDirector 与 CardSystem 抽卡逻辑严重重复
- **位置**: `src/systems/FlowDirector.js:414-513` + `src/systems/CardSystem.js:617-688`
- **现象**: `_drawNormalWithMood` 与 `CardSystem._drawNormal` 有几乎完全相同的过滤、权重、冷却逻辑。任何修改（如新增过滤条件）需要同时改两处，极易遗漏。
- **修复建议**: 将公共抽卡逻辑提取到 `CardSystem` 的一个新方法（如 `drawFromPool(options)`），由 `FlowDirector` 调用。

### 18. `FlowDirector._markSourceUsed` 中 `breakthrough` 映射为 `normal`（未修复的 P2-13）
- **位置**: `src/systems/FlowDirector.js:537-558`
- **现象**: `breakthrough` 被映射为 `normal`，导致每次突破后普通卡饥饿计数器被重置，但 `breakthrough` 本身没有独立的饥饿追踪。统计报告中的 "breakthrough 饥饿" 永远不会出现。
- **修复建议**: 添加 `'breakthrough': 'breakthrough'` 映射。

### 19. `EventBus.collect` 方法中 `this.emit` 劫持存在 `this` 绑定风险
- **位置**: `src/core/EventBus.js:94-103`
- **现象**: `collect` 方法中临时替换 `this.emit = function(...) { ... }`，但替换后的函数是普通函数，如果 listener 内部通过 `this.emit(...)` 调用且依赖 `this` 上下文，绑定会丢失。当前代码中未使用该方法，属于死代码。
- **修复建议**: 标记 `collect` 方法为废弃，或改用符号/代理实现安全的劫持。

### 20. `CardSystem._handleQuestCardRequest` 设置的 `_pendingQuestCard` 无任何消费者
- **位置**: `src/systems/CardSystem.js:1113-1120`
- **现象**: `_handleQuestCardRequest` 将卡存入 `this._pendingQuestCard`，但 `draw()` 中优先级 80/70 使用的是 `_getQuestCurrentCard()` 和 `_getQuestEntryCard()`（通过 eventBus 请求），**从不读取 `_pendingQuestCard`**。
- **修复建议**: 删除 `_pendingQuestCard` 相关代码，或改用 `_pendingQuestCard` 作为 quest 卡的内部缓存。

---

## 总结

本次审查在验证已有报告的基础上，发现 **2 个 P0 级问题仍未修复**（REALM_ORDER 崩溃、死亡卡绕过），**5 个 P1 级问题未修复**（商店跳过结算、realmOrder 硬编码、Map 遍历错误、死亡卡 restart 无效、被动回血上限错误），以及 **多个新发现的 P2/P3 问题**。

**最危险的三个问题**：
1. **REALM_ORDER 未定义** → 世界事件触发必崩溃（P0-1）。
2. **FlowDirector 中 `for...in` 遍历 Map** → 额外卡池全部失效，魔道/转世/交织等高级内容玩家永远看不到（新 P1）。
3. **CardSystem 硬编码 realmOrder 包含 `formation`/`void`** → 化神期被误判为低境界，商店/触发逻辑全部错乱（P1-6）。

**修复优先级建议**：
- **第一阶段（本周）**：修复 P0-1（REALM_ORDER）、P0-4（死亡卡）、P1-4（Map 遍历）、P1-6（realmOrder 硬编码）。
- **第二阶段（2 周）**：修复 P1-3（商店跳过结算）、P1-5（死亡卡 restart）、P1-7（被动回血上限）、P2-1（getActiveSeeds）、P2-6（寿命扣除）。
- **第三阶段（1 月）**：消除 FlowDirector/CardSystem 代码重复（P3）、重构 `_loadUnlocks` 兼容逻辑（P3）。
