# 第五章：修复计划（P0 / P1 / P2 / P3）

> 本计划基于 `游戏全面审查报告_v2.md`（2026-07-14）制定。  
> 所有代码修改均基于对现有文件的实际分析，具体文件路径和代码位置已在各修复项中注明。  
> 建议按照 **"P0 → P1 → P2/P3"** 的顺序执行修复，每完成一级修复后进行全面的回归测试。

---

## 一、P0级修复清单（阻断性Bug，1-2天）

P0级问题导致**游戏流程中断、核心机制失效或数据层断裂**，必须在任何其他工作之前修复。

---

### P0-1. `REALM_ORDER` 引用崩溃

**问题诊断**  
`src/game.js:1017` 中 `_pickWorldEvent()` 方法直接引用 `GameStateManager.REALM_ORDER`：

```javascript
// src/game.js:1015-1023
_pickWorldEvent() {
  const realmName = gameState.getRealmName(gameState.realm);
  const realmIndex = GameStateManager.REALM_ORDER.indexOf(gameState.realm);
  const pool = GameLogic.WORLD_EVENTS.filter(ev => {
    if (!ev.realmGate) return true;
    const gateIndex = GameStateManager.REALM_ORDER.indexOf(
      GameStateManager.REALM_ORDER.find(r => gameState.getRealmName(r) === ev.realmGate)
    );
    return gateIndex >= 0 && realmIndex >= gateIndex;
  });
```

但 `GameStateManager` **从未定义 `REALM_ORDER` 静态属性**。当 `_pickWorldEvent()` 被调用时（每 ~20 回合一次），`GameStateManager.REALM_ORDER` 为 `undefined`，`indexOf` 调用将直接抛出 `TypeError`，导致世界事件系统完全失效，并可能中断当前回合的后续逻辑（因果推进、被动回血等）。

**影响范围**  
- 世界事件系统（`GameLogic.WORLD_EVENTS`）完全不可用。  
- 事件触发时若抛出异常，可能中断 `makeChoice()` 的后续流程（寿元消耗、NPC情绪衰减等）。  
- 玩家永远看不到"天下大事"日志，沉浸感核心机制断裂。

**修复方案**  
使用 `gameState.config.realms.order`（已存在于配置中）替代不存在的 `GameStateManager.REALM_ORDER`：

```javascript
// src/game.js:1015-1027（修改后）
_pickWorldEvent() {
  const realmOrder = gameState.config.realms
    ? (gameState.config.realms.order || ['qi', 'foundation', 'golden', 'nascent', 'deity', 'tribulation'])
    : ['qi', 'foundation', 'golden', 'nascent', 'deity', 'tribulation'];
  const realmIndex = realmOrder.indexOf(gameState.realm);

  const pool = GameLogic.WORLD_EVENTS.filter(ev => {
    if (!ev.realmGate) return true;
    const gateRealmId = realmOrder.find(r => gameState.getRealmName(r) === ev.realmGate);
    const gateIndex = gateRealmId ? realmOrder.indexOf(gateRealmId) : -1;
    return gateIndex >= 0 && realmIndex >= gateIndex;
  });
  // ... 其余逻辑不变
}
```

**验证方法**  
1. 启动游戏，选择任意功法进入对局。  
2. 使用浏览器控制台执行 `gameLogic._tickWorldEvents()` 强制触发。  
3. 确认控制台无 `TypeError`，且日志区出现一条世界事件文本。  
4. 运行 25 回合以上，确认筑基期后事件（如"天剑宗广发英雄帖"）正常触发。

---

### P0-2. 死亡卡被 `makeChoice` 前置拦截绕过

**问题诊断**  
`src/game.js:518` 中 `makeChoice()` 的第一行即拦截死亡状态：

```javascript
// src/game.js:517-518
makeChoice(direction) {
  if (gameState.dead) return false;
```

当玩家死亡时，`game.js:893-898` 会调用 `cardSystem.draw()` 获取死亡卡并设为 `currentCard`：

```javascript
// src/game.js:893-898
if (gameState.checkDeath()) {
  const pn = gameState.playerName || '叶凌云';
  this._log(`${pn}，道消身陨。${gameState.deadReason}`);
  this.currentCard = cardSystem.draw();  // 返回死亡卡
  this._triggerUpdate();
  return true;
}
```

然而由于 `makeChoice` 开头的 `if (gameState.dead) return false`，玩家在死亡卡界面上**无法做出任何选择**。死亡卡本应提供"转世重修"（`reincarnate: true`）和"燃魂一击"（`restart: true`）两个选项，但玩家点击后直接被拒绝，UI 无反馈，游戏陷入死锁状态。

**影响范围**  
- 死亡机制完全不可用，玩家死亡后无法转世，游戏流程断裂。  
- `deathCardMap` 中所有精心编写的死亡叙事卡（道心崩碎、寿元耗尽、身死道消等）永不被展示。

**修复方案**  
移除 `makeChoice` 中对死亡状态的硬拦截，改为在死亡卡处理分支中正常解析选择：

```javascript
// src/game.js:517-526（修改后）
makeChoice(direction) {
  // 死亡状态不再全局拦截——死亡卡本身需要被交互
  // if (gameState.dead) return false;  // 【删除此行】

  const card = this.getCurrentCard();

  // ── 死亡卡选择处理（新增分支）──
  if (gameState.dead && card && card.type === 'DEATH') {
    const choice = card.choices[direction];
    if (!choice) return false;
    this._applyEffects(choice.effects);
    // reincarnate/restart 效果由各自的 handler 处理
    this._triggerUpdate();
    return true;
  }

  // ... 其余逻辑不变
```

同时，确保 `src/ui.js:320-323` 的死亡界面渲染在死亡卡交互完成后才切换：

```javascript
// src/ui.js:320-324（保持原有逻辑即可——死亡卡交互后 gameState.dead 会被 reset 清除）
renderGame() {
  // ...
  if (gameState.dead && !this.currentCard) {  // 增加条件：只有无死亡卡时才显示死亡屏
    this.renderDeathScreen();
    this.showScreen('death');
  }
}
```

**验证方法**  
1. 使用控制台将 `gameState.attributes.health = 0` 强制触发死亡。  
2. 确认 UI 展示死亡卡（而非直接跳转到死亡屏幕）。  
3. 点击死亡卡的"转世重修"选项，确认进入转世流程（`gameLogic._reincarnate()` 被调用，出现"第 X 世·轮回"日志）。  
4. 确认转世后 `gameState.dead === false`，新游戏正常进行。

---

### P0-3. 被动回血硬编码 `maxHealth=100`

**问题诊断**  
`src/game.js:1060-1064` 中 `_applyPassiveRegen()` 将回血上限硬编码为 `100`：

```javascript
// src/game.js:1060-1064（当前代码）
// 应用回血（不超过 maxHealth=100）
if (hpRegen > 0 && gameState.attributes.health < 100) {
  const healAmount = Math.min(hpRegen, 100 - gameState.attributes.health);
  gameState.addAttribute('health', healAmount);
}
```

但 `GameStateManager` 中 `maxHealth` 的实际值由转世加成动态决定（初始为 3，转世后可能更高）：

```javascript
// src/core/GameStateManager.js:48
this.maxHealth = 3 + (savedUnlocks.bonuses.maxHp || 0);
```

硬编码 `100` 导致：
- 炼气期 `maxHealth=3` 时，被动回血永远无法触发（因为 `health < 100` 永远为真，但 `healAmount` 可能大于实际需要）。
- 更关键的是，`100 - gameState.attributes.health` 会计算出远大于实际缺口的治疗量，导致 `addAttribute` 被传入超大值，但 `setAttribute` 内部有 `Math.min(maxVal, value)` 保护，所以实际不会溢出。真正的问题是：**低境界玩家永远回不满血**，因为代码假设上限是 100，而实际是 3。

**影响范围**  
- 法宝/功法被动回血在低境界完全失效或行为异常。  
- 体修路径（依赖高生命值）的数值模型被扭曲。

**修复方案**  
将两处硬编码 `100` 替换为 `gameState.maxHealth`：

```javascript
// src/game.js:1060-1069（修改后）
// 应用回血（不超过实际 maxHealth）
if (hpRegen > 0 && gameState.attributes.health < gameState.maxHealth) {
  const healAmount = Math.min(hpRegen, gameState.maxHealth - gameState.attributes.health);
  gameState.addAttribute('health', healAmount);
}

// 应用福缘恢复（同样修复）
if (fortuneBonus > 0 && gameState.attributes.fortune < gameState.maxHealth) {  // 若福缘上限也应动态化
  gameState.addAttribute('fortune', Math.min(fortuneBonus, gameState.maxHealth - gameState.attributes.fortune));
}
```

> **注意**：福缘的上限若也应为 100，则保留原逻辑。若福缘上限也需动态化，建议统一使用配置值。

**验证方法**  
1. 启动新游戏（`maxHealth = 3`）。  
2. 通过控制台给玩家装备一个带 `hpRegen: 1` 的法宝（模拟）。  
3. 将 `health` 降至 1，执行 `gameLogic._applyPassiveRegen()`。  
4. 确认 `health` 恢复至 2（而非试图恢复到 100）。  
5. 转世后增加 `maxHp` 加成，确认回血上限正确提升。

---

### P0-4. 正魔线第三幕种子缺失（`demonInternalConflict` / `orthodoxInternalConflict`）

**问题诊断**  
`data/cards/demon_path.json` 中，第三幕（金丹期）的两张核心剧情卡 `dp_demon_schism`（血煞宗的内战）和 `dp_orthodox_schism`（正道的裂痕）依赖以下 `requiresFlags`：

```json
// data/cards/demon_path.json:1029-1033
{
  "id": "dp_demon_schism",
  "requiresFlags": {
    "demonInternalConflict": null
  }
}

// data/cards/demon_path.json:1071-1075
{
  "id": "dp_orthodox_schism",
  "requiresFlags": {
    "orthodoxInternalConflict": null
  }
}
```

但全局搜索确认：**没有任何卡牌在任何选择的 `karmaSeed` 或 `effects` 中种植 `demonInternalConflict` 或 `orthodoxInternalConflict` 这两个 flag/seed**。这两个种子在 `demon_path.json` 的 `karmaCards` 映射中存在：

```json
// data/cards/demon_path.json:11-12
"demonInternalConflict": "dp_demon_schism",
"orthodoxInternalConflict": "dp_orthodox_schism",
```

但它们只被 **引用**，从未被 **种植**。这意味着正魔线第三幕的两条核心内战剧情线**永久不可达**——无论玩家如何选择，永远不会触发血煞宗内战或正道裂痕事件。

**影响范围**  
- 正魔线第三幕 15 张卡牌中的核心叙事（`dp_demon_schism`、`dp_orthodox_schism`、`dp_demon_redemption`、`dp_demon_ascend`、`dp_final_stand`）全部不可达。  
- 正魔线从第二幕到第三幕的叙事链条断裂，玩家体验在筑基期后突然"无事发生"。

**修复方案**  
在第二幕（筑基期）的关键分岔点 `dp_end_of_foundation`（筑基将尽·分野）的两个选择中，分别种植对应的内战种子：

```json
// data/cards/demon_path.json:654-684（修改后）
{
  "id": "dp_end_of_foundation",
  "choices": {
    "left": {
      "text": "正道——但不再是盲从的正道",
      "effects": { "daoHeart": 20, "karmaGood": 10, "fortune": 5 },
      "karmaSeed": {
        "id": "orthodoxInternalConflict",
        "seedType": "karma",
        "delay": 15,
        "priority": 3
      }
    },
    "right": {
      "text": "魔道——但不做殷血那样的人",
      "effects": { "daoHeart": -10, "cultivation": 15, "karmaBad": 10, "fortune": -5 },
      "karmaSeed": {
        "id": "demonInternalConflict",
        "seedType": "karma",
        "delay": 15,
        "priority": 3
      }
    }
  }
}
```

> `delay: 15` 确保种子在玩家进入金丹期（第三幕）后才发芽，避免叙事节奏过早。

**验证方法**  
1. 加载游戏，通过控制台快速推进到筑基期。  
2. 遇到 `dp_end_of_foundation` 卡，选择正道/魔道。  
3. 检查 `gameState.karmaSeeds` 中是否出现 `orthodoxInternalConflict` 或 `demonInternalConflict`。  
4. 继续推进 15 回合并进入金丹期，确认 `dp_demon_schism` 或 `dp_orthodox_schism` 被抽出。  
5. 完成第三幕全部卡牌链，确认 `dp_final_stand`（最终抉择）正常出现。

---

### P0-5. NPC ID 跨文件不一致

**问题诊断**  
`data/npcs/core_npcs.json` 中定义了 8 个核心 NPC 的标准 ID：

| NPC | `core_npcs.json` 标准 ID |
|-----|------------------------|
| 白刃真人 | `bai_ren` |
| 白落霜 | `bai_luoxuan` |
| 剑灵儿 | `jian_linger` |
| 慕青岚 | `mu_qinglan` |
| 殷血 | `yin_xue` |
| 九尾溯月 | `jiuwei_suyue` |
| 天机老人 | `tianji_laoren` |
| 血煞老祖 | `xuesha_laozu` |

但在以下三个数据文件中，同一 NPC 使用了**不同的缩写 ID**：

**`data/npcs/npc_relations.json`**：
- `xue_sha` → 应为 `xuesha_laozu`
- `tian_ji` → 应为 `tianji_laoren`
- `jiuwei` → 应为 `jiuwei_suyue`

**`data/npcs/npc_cross_cards.json`**：
- 同上，`xue_sha`、`tian_ji`、`jiuwei` 等缩写 ID 被用于 `npcIds`、`npcAffection` 键名。

**`data/echoes/echo_templates.json`**：
- 同上，根键使用 `xue_sha`、`tian_ji`、`jiuwei`。

此外，代码层也存在不一致：`src/game.js:1198` 中 `_buildInnerDemonCard()` 直接引用 `npcSystem.affections.mentor_sword_elder`，但该 ID 在 `core_npcs.json` 中不存在（应为 `bai_ren`）。

**影响范围**  
- `npcSystem.getNpcName('xue_sha')` 返回 `undefined`，导致交叉互动卡、关系矩阵、回响模板全部无法正确关联到 `xuesha_laozu`。  
- 师尊护体心魔机制（`mentor_sword_elder`）永远评估为 `false`，白刃真人的保护剧情不触发。  
- 任何依赖 NPC ID 一致性的系统（好感度计算、势力声望联动、叙事回响）都会产生静默失败。

**修复方案**  
**步骤 1**：统一数据层 ID 为 `core_npcs.json` 标准：

```bash
# data/npcs/npc_relations.json
# 将所有 "xue_sha" 替换为 "xuesha_laozu"
# 将所有 "tian_ji" 替换为 "tianji_laoren"
# 将所有 "jiuwei" 替换为 "jiuwei_suyue"

# data/npcs/npc_cross_cards.json
# 同上替换

# data/echoes/echo_templates.json
# 将根键 "xue_sha" → "xuesha_laozu"
# 将根键 "tian_ji" → "tianji_laoren"
# 将根键 "jiuwei" → "jiuwei_suyue"
```

**步骤 2**：修复代码层引用：

```javascript
// src/game.js:1197-1198（修改后）
const mentorProtection = (typeof npcSystem !== 'undefined' && npcSystem &&
  npcSystem.affections && npcSystem.affections.bai_ren >= 50);
```

**步骤 3**：建立 NPC ID 校验脚本（见第五章测试策略），防止未来回归。

**验证方法**  
1. 运行数据校验脚本，确认 `npc_relations.json` 中所有 `npcA`、`npcB` 均存在于 `core_npcs.json`。  
2. 启动游戏，与血煞老祖（`xuesha_laozu`）建立足够好感度。  
3. 触发交叉互动卡 `npc_cross_xue_sha_yin_xue_family`，确认正常渲染。  
4. 触发心魔反噬，确认好感度 ≥ 50 时 `mentorProtection` 正确生效。

---

### P0-6. 白狐支线回响断裂（`whiteFox` 种子缺失）

**问题诊断**  
`data/cards/karma.json` 中定义了白狐因果链的两张卡：

```json
// data/cards/karma.json:5-6
"karmaCards": {
  "whiteFox": "k_fox_returns",
  "foxGratitude": "k_fox_gratitude",
```

- `k_fox_returns`（狐影再现）：元婴期，`whiteFox` 种子触发。该卡的右选择会种植 `foxGratitude` 种子。
- `k_fox_gratitude`（白狐报恩·终章）：化神期，`foxGratitude` 种子触发。

但 `data/quests/white_fox.json` 中，白狐支线的完成奖励**只种植了 `foxGratitude`，没有种植 `whiteFox`**：

```json
// data/quests/white_fox.json:25-32
"rewardOnComplete": {
  "attributes": { "karmaGood": 15, "fortune": 10 },
  "resources": { "spiritStone": 20 },
  "flags": ["whiteFoxCompleted"],
  "karmaSeeds": [
    { "id": "foxGratitude", "delay": 10, "realm": "foundation", "priority": 2 }
  ]
}
```

这导致：
1. 玩家完成白狐支线后，直接进入 `k_fox_gratitude`（终章），**跳过了 `k_fox_returns`（狐影再现）**。  
2. `k_fox_returns` 中白狐化身为白衣女子赠送凝婴丹的关键叙事**永久不可见**。  
3. 叙事顺序完全颠倒：玩家先看到"终章"，再（如果通过其他途径触发）看到"初章"。

**影响范围**  
- 白狐支线因果链的叙事结构崩坏。  
- `k_fox_returns` 的场景图 `scene_karma_k_fox_returns.png` 永不被展示。

**修复方案**  
在 `q_whiteFox_3`（白狐支线第三步）的右选择中种植 `whiteFox` 种子，并将 `foxGratitude` 种子的触发境界调整为 `nascent`（与 `k_fox_returns` 的右选择一致）：

```json
// data/quests/white_fox.json:90-101（修改后）
{
  "id": "q_whiteFox_3",
  "choices": {
    "left": {
      "text": "击退猎狗，护送白狐",
      "effects": { "health": -15, "karmaGood": 20, "fortune": 10 },
      "questEnd": true,
      "karmaSeed": {
        "id": "whiteFox",
        "seedType": "karma",
        "delay": 12,
        "realm": "nascent",
        "priority": 3
      }
    },
    "right": {
      "text": "用灵石打发猎户",
      "effects": { "spiritStone": -20, "karmaGood": 12, "daoHeart": 5 },
      "questEnd": true,
      "karmaSeed": {
        "id": "whiteFox",
        "seedType": "karma",
        "delay": 15,
        "realm": "nascent",
        "priority": 3
      }
    }
  }
}
```

同时，移除 `rewardOnComplete` 中多余的 `foxGratitude` 种子（避免重复种植），改为由 `k_fox_returns` 的右选择自然触发：

```json
// data/quests/white_fox.json:25-32（修改后）
"rewardOnComplete": {
  "attributes": { "karmaGood": 15, "fortune": 10 },
  "resources": { "spiritStone": 20 },
  "flags": ["whiteFoxCompleted"]
  // foxGratitude 种子移除——由 k_fox_returns 的右选择种植
}
```

**验证方法**  
1. 完成白狐支线 `white_fox_line`（救助白狐 → 接受谢礼 → 击退猎狗）。  
2. 检查 `gameState.karmaSeeds`，确认存在 `whiteFox` 种子，`realm: "nascent"`。  
3. 推进至元婴期并等待 12-15 回合，确认 `k_fox_returns`（狐影再现）被抽出。  
4. 选择 `k_fox_returns` 的右选项"询问她的身份"，确认种植 `foxGratitude` 种子。  
5. 推进至化神期，确认 `k_fox_gratitude`（白狐报恩·终章）被抽出。

---

## 二、P1级修复清单（功能缺陷，1-2周）

P1级问题导致**功能不完整、数值异常或叙事不连贯**。不影响游戏基本运行，但严重损害体验。

---

### 代码层问题（11个）

#### P1-1. 商店卡回合推进不同步

**问题诊断**  
`src/game.js:643-652` 中，当玩家选择 `openShop: true` 时，`turn` 和 `cardsPlayed` 被立即推进：

```javascript
gameState.cardsPlayed.push(card.id);
gameState.turn++;
eventBus.emit('shop:open', { ... });
```

但商店关闭时（`shop:closed` 事件，`game.js:304-307`）仅设置 `currentCard = null`，不推进回合。这意味着：
- 玩家进入商店消耗了 1 回合。
- 关闭商店后，下一张卡被抽出，但玩家**没有做出任何选择**就进入了下一个回合。
- 从玩家视角："我只是逛了一下商店，怎么时间突然过了一回合？"

**修复方案**  
将商店回合推进延迟到关闭时：

```javascript
// src/game.js:643-652（修改后）
if (choice.openShop) {
  // 不在这里推进回合，仅标记商店状态
  eventBus.emit('shop:open', {
    items: shopSystem ? shopSystem.getAvailableItems(gameState.realm) : []
  });
  this._triggerUpdate();
  return true;
}

// src/game.js:304-307（修改后）
this.eventBus.on('shop:closed', () => {
  this.currentCard = null;
  gameState.cardsPlayed.push('shop_visit');  // 记录商店访问
  gameState.turn++;                          // 关闭时才推进回合
  this._triggerUpdate();
});
```

**验证方法**：进入商店 → 购买/浏览 → 关闭商店 → 检查 `gameState.turn` 仅增加 1。

---

#### P1-2. `CardSystem._checkShopEncounter` 硬编码错误 realmOrder

**问题诊断**  
`src/systems/CardSystem.js:379` 硬编码了不存在的境界名：

```javascript
const realmOrder = ['qi', 'foundation', 'golden', 'nascent', 'formation', 'void', 'tribulation'];
```

实际游戏境界为 `qi`, `foundation`, `golden`, `nascent`, `deity`, `tribulation`。`formation` 和 `void` 是错误名称。

**修复方案**  
```javascript
const realmOrder = gameState.config.realms
  ? (gameState.config.realms.order || ['qi', 'foundation', 'golden', 'nascent', 'deity', 'tribulation'])
  : ['qi', 'foundation', 'golden', 'nascent', 'deity', 'tribulation'];
```

**验证方法**：进入 `deity` 境界，确认商店触发间隔使用正确的 `minInterval = 6`（而非错误回退到 `minInterval = 8`）。

---

#### P1-3. 兜底事件卡使用 `exp` 字段与其他卡不一致

**问题诊断**  
`CardSystem._buildFallbackEventCard()` 和 `_buildFallbackDeathCard()` 均使用 `exp` 作为效果键：

```javascript
// src/systems/CardSystem.js:1167
choices: { left: { effects: { exp: 10 } } }
```

虽然 `EffectService` 注册了 `exp` handler（作为 `cultivation` 的别名），但**所有正式卡牌**均使用 `cultivation`。这种不一致会导致数据校验脚本误判 `exp` 为无效键，也增加维护成本。

**修复方案**  
```javascript
// src/systems/CardSystem.js:1167
effects: { cultivation: 10 }  // 替代 exp: 10
```

---

#### P1-4. `FlowDirector` 中 `for...in` 遍历 Map

**问题诊断**  
`src/systems/FlowDirector.js` 中存在 `for (const key in someMap)` 遍历 `Map` 实例的代码模式。`for...in` 遍历的是对象的枚举属性，而非 Map 的 entries，导致迭代结果包含非预期的原型链属性或完全为空。

**修复方案**  
将所有 `for...in` 遍历 Map 的代码替换为 `for...of map.entries()` 或 `map.forEach()`：

```javascript
// 修改前（错误）
for (const key in this.factionPriorities) { ... }

// 修改后（正确）
for (const [key, value] of this.factionPriorities.entries()) { ... }
```

**验证方法**：在 FlowDirector 活跃时运行 50 回合，确认无空迭代导致的阶段卡死。

---

#### P1-5. `EffectService` 未注册 `restart` handler

**问题诊断**  
`CardSystem._buildFallbackDeathCard()` 的右选择使用 `restart: true`：

```javascript
choices: {
  right: {
    text: '拒绝天命，燃魂一击',
    effects: { restart: true }
  }
}
```

但 `EffectService._registerHandlers()` 中仅有 `reincarnate` handler（空函数），**没有 `restart` handler**。选择"燃魂一击"后无任何效果，玩家困惑。

**修复方案**  
在 `EffectService` 中添加 `restart` handler（行为与 `reincarnate` 相同——重启当前世）：

```javascript
// src/services/EffectService.js:71-72（修改后）
this.handlers.set('reincarnate', () => {});
this.handlers.set('restart', () => {});  // 新增
```

并在 `game.js` 的 `makeChoice` 中统一处理：

```javascript
// src/game.js:751-753（修改后）
if (gameState.dead || (choice.effects && (choice.effects.reincarnate || choice.effects.restart))) {
  this._reincarnate();
  return true;
}
```

**验证方法**：死亡后选择"燃魂一击"，确认触发转世流程。

---

#### P1-6. `cultivation` 属性上限硬编码为 100

**问题诊断**  
`GameStateManager.setAttribute()` 中 `maxVal` 对 cultivation 使用默认值 `100`：

```javascript
// src/core/GameStateManager.js:111-117
setAttribute(name, value) {
  let maxVal = 100;
  if (name === 'health') maxVal = this.maxHealth;
  if (name === 'daoHeart') maxVal = this.maxDaoHeart;
  this.attributes[name] = Math.max(0, Math.min(maxVal, value));
}
```

但不同境界的 `cultivationThreshold` 可能超过 100（如金丹期 150、元婴期 200）。当 `cultivation` 达到 100 时会被硬截断，玩家无法突破到更高境界。

**修复方案**  
根据当前境界动态获取 cultivation 上限：

```javascript
// src/core/GameStateManager.js:111-122（修改后）
setAttribute(name, value) {
  let maxVal = 100;
  if (name === 'health') maxVal = this.maxHealth;
  if (name === 'daoHeart') maxVal = this.maxDaoHeart;
  if (name === 'cultivation') {
    const realmConfig = this.config.realms ? this.config.realms.realms[this.realm] : null;
    maxVal = realmConfig ? (realmConfig.cultivationThreshold || 100) : 100;
  }
  this.attributes[name] = Math.max(0, Math.min(maxVal, value));
}
```

**验证方法**：在筑基期将 cultivation 提升至 101，确认 `setAttribute` 允许该值（筑基 threshold 为 100，但此处应允许达到 threshold 而非截断在 threshold 以下——实际上 `checkBreakthrough` 在 `>= threshold` 时触发，所以 cultivation 可以等于 threshold。若 threshold=100，则 cultivation 应能到达 100。若某境界 threshold > 100，则应允许超过 100。）。

> **修正理解**：`cultivation` 的上限应是当前境界的 `cultivationThreshold`，而非固定 100。上述修复方案正确。

---

#### P1-7. 部分因果种子缺少 `delay` / `realm` 约束

**问题诊断**  
`data/quests/white_fox.json` 中 `rewardOnComplete.karmaSeeds` 的 `foxGratitude` 种子设置了 `realm: "foundation"`，但 `k_fox_gratitude` 卡牌本身要求 `realm: "deity"`。这意味着种子可能在 foundation 境界提前发芽，但抽到的卡牌要求 deity 境界，导致卡被跳过或逻辑冲突。

类似地，部分支线奖励的 `karmaSeeds` 缺少 `realm` 字段，导致种子在任何境界都可能发芽，与卡牌设计的境界叙事不匹配。

**修复方案**  
统一审查所有 `karmaSeeds` 的 `realm` 字段，确保与目标卡牌的 `realm` 一致：

```json
// data/quests/white_fox.json:29-31（修改后）
"karmaSeeds": [
  { "id": "foxGratitude", "delay": 10, "realm": "deity", "priority": 2 }
]
```

**验证方法**：运行数据校验脚本（见第五章），检查所有 `karmaSeed` 的 `realm` 是否与对应卡牌的 `realm` 匹配。

---

#### P1-8. `DeckCombatSystem` 中 `maxHealth` 引用风险

**问题诊断**  
`src/systems/DeckCombatSystem.js:86`：

```javascript
this.player = {
  hp: gameState.attributes.health,
  maxHp: gameState.maxHealth,
```

若 `gameState.maxHealth` 因初始化顺序问题为 `undefined`（如 `deckCombatSystem._start` 在 `gameState.reset()` 之前被调用），`maxHp` 将为 `undefined`，导致后续所有 `Math.min(this.player.maxHp, ...)` 返回 `NaN`。

**修复方案**  
添加防御性默认值：

```javascript
// src/systems/DeckCombatSystem.js:84-89（修改后）
this.player = {
  hp: gameState.attributes.health || 1,
  maxHp: gameState.maxHealth || 3,
  daoHeart: gameState.attributes.daoHeart || 3,
  block: 0
};
```

**验证方法**：在 `gameState.reset()` 之前手动触发战斗，确认不抛出异常。

---

#### P1-9. `DeckCombatSystem` 忽略卡牌原始 `enemy` 数据

**问题诊断**  
`DeckCombatSystem._start()` 接收 `data.card`，但构建敌人时**仅使用 `enemy.tier`** 来生成极简属性，完全忽略了卡牌中定义的 `enemy.hp`、`enemy.atk`、`enemy.def`、`enemy.special` 等字段：

```javascript
// src/systems/DeckCombatSystem.js:92-121
const enemyData = card.enemy;
const tier = enemyData.tier || 1;
let enemyHp = 3;
if (tier === 2) enemyHp = 8;
if (tier === 3) enemyHp = 15;
```

这意味着所有战斗敌人只有 3/8/15 点血、无防御、无特殊技能，战斗数值设计完全失效。

**修复方案**  
优先使用卡牌定义的敌人数据，tier 仅作为后备：

```javascript
// src/systems/DeckCombatSystem.js:92-121（修改后）
const enemyData = card.enemy;
const tier = enemyData.tier || 1;

// 优先使用卡牌定义的敌人属性
defaultEnemyHp = { 1: 3, 2: 8, 3: 15 };
let enemyHp = enemyData.hp || defaultEnemyHp[tier] || 3;
let enemyAtk = enemyData.atk || (tier * 3);  // 简单默认攻击
let enemyDef = enemyData.def || 0;

this.enemy = {
  name: (enemyDef && enemyDef.name) || enemyData.name || '修仙者',
  hp: enemyHp,
  maxHp: enemyHp,
  block: 0,
  tier: tier,
  def: enemyDef,  // 保留 AI 模板
  atk: enemyAtk,  // 新增：攻击力
  intentIndex: 0,
  factionId: enemyData.factionId || null
};
```

**验证方法**：创建一张带 `enemy: { name: "测试妖兽", tier: 2, hp: 25, atk: 5 }` 的战斗卡，确认进入战斗后敌人拥有 25 HP 和 5 攻击力。

---

#### P1-10. 新旧 `CombatSystem` 事件 payload 格式不兼容

**问题诊断**  
旧版 `CombatSystem` 和新版 `DeckCombatSystem` 发射的 `combat:victory` / `combat:defeat` 事件 payload 结构完全不同：

```javascript
// CombatSystem.js（旧版）发射格式
eventBus.emit('combat:victory', {
  cardId: this.cardId,
  rewards: this.rewards,
  log: this.log
});

eventBus.emit('combat:defeat', {
  cardId: this.cardId,
  hpLoss: hpLoss,
  log: this.log
});

// DeckCombatSystem.js（新版）发射格式
eventBus.emit('combat:victory', { originalCard: this.originalCard });
eventBus.emit('combat:defeat', { originalCard: this.originalCard });
```

而 `CombatCoordinator.onVictory(data)` 和 `onDefeat(data)` 期望的是新版格式（`data.originalCard`）：

```javascript
// src/coordinators/CombatCoordinator.js:120-153
onVictory(data) {
  // 使用 data.originalCard.combatRewards
}

onDefeat(data) {
  if (data && data.originalCard && data.originalCard.combatRewards) {
    // ...
  }
}
```

如果旧版 `CombatSystem` 触发事件（某些代码路径可能仍调用旧系统），`CombatCoordinator` 找不到 `originalCard`，导致战斗奖励丢失或错误扣除血量。

**修复方案**  
在 `CombatCoordinator` 中增加对两种格式的兼容：

```javascript
// src/coordinators/CombatCoordinator.js:120-153（修改后）
onVictory(data) {
  const originalCard = data && (data.originalCard || data.cardId);
  // ... 使用 originalCard
}

onDefeat(data) {
  const originalCard = data && (data.originalCard || data.cardId);
  if (originalCard && typeof originalCard === 'object' && originalCard.combatRewards) {
    // ...
  } else {
    // 兼容旧版格式：直接扣血
    gameState.addAttribute('health', -20);
  }
}
```

**验证方法**：分别通过旧版和新版战斗系统触发一场战斗，确认胜利/失败后奖励/惩罚均正确应用。

---

#### P1-11. 战斗奖励日志不一致

**问题诊断**  
- `CombatSystem._victory()` 将奖励文本写入内部 `this.log`，但 `CombatCoordinator` 接管 UI 后不再读取旧系统的日志。  
- `DeckCombatSystem._victory()` 完全不处理 `originalCard.combatRewards`，仅发射 `combat:victory` 事件。  
- `CombatCoordinator._buildCombatRewardCard()` 构建的奖励卡描述文字与 `CombatSystem._victory()` 的日志格式不同。

玩家在不同战斗系统中看到的奖励反馈完全不同，造成困惑。

**修复方案**  
统一战斗奖励的日志输出：在 `CombatCoordinator.onVictory()` 中生成标准化奖励日志：

```javascript
// src/coordinators/CombatCoordinator.js:120-153（修改后）
onVictory(data) {
  // ... 原有逻辑 ...
  
  // 统一奖励日志
  const rewardCard = this._buildCombatRewardCard(data);
  const rw = data && (data.originalCard || {}).combatRewards;
  if (rw) {
    const lines = [];
    if (rw.cultivation) lines.push(`修为 +${rw.cultivation}`);
    if (rw.spiritStone) lines.push(`灵石 +${rw.spiritStone}`);
    if (rw.pill) lines.push(`获得丹药：${rw.pill}`);
    if (rw.treasure) lines.push(`获得法宝：${rw.treasure}`);
    if (lines.length) this._log(`战斗奖励：${lines.join('，')}`);
  }
  
  if (this.callbacks.setCurrentCard) {
    this.callbacks.setCurrentCard(rewardCard);
  }
  // ...
}
```

**验证方法**：通过 DeckCombatSystem 赢得战斗，确认日志区显示"战斗奖励：修为 +X，灵石 +Y"。

---

#### P1-12. `DeckCombatSystem._victory` 不发放战斗奖励

**问题诊断**  
`DeckCombatSystem._victory()` 仅同步 HP 并发射事件，**完全不处理原卡牌的 `combatRewards`**：

```javascript
// src/systems/DeckCombatSystem.js:538-548
_victory() {
  this.active = false;
  this._addLog(`战斗胜利！`);
  gameState.attributes.health = this.player.hp;
  eventBus.emit('combat:victory', { originalCard: this.originalCard });
  eventBus.emit('ui:hideCombatScreen');
}
```

而 `CombatCoordinator._buildCombatRewardCard()` 虽然有奖励处理逻辑，但仅处理 `originalCard.combatRewards` 中的灵石、修为、丹药、法宝，**不处理 deckCard（战斗卡牌奖励）**。

**修复方案**  
在 `CombatCoordinator._buildCombatRewardCard()` 中增加 `deckCard` 奖励处理：

```javascript
// src/coordinators/CombatCoordinator.js:261-326（在 rewardCard 构建中增加）
if (originalCard && originalCard.combatRewards) {
  // ... 现有 cultivation/spiritStone/pill/treasure 处理 ...
  
  // 新增：deckCard 奖励
  if (originalCard.combatRewards.deckCard && this.deckCombatSystem) {
    this.deckCombatSystem.masterDeck.push(originalCard.combatRewards.deckCard);
    this._log(`获得战斗卡牌：【${originalCard.combatRewards.deckCard}】`);
  }
}
```

**验证方法**：创建一张带 `combatRewards: { deckCard: "sword_intent" }` 的战斗卡，胜利后确认 `deckCombatSystem.masterDeck` 包含新卡牌。

---

### 数据层问题（10个）

#### P1-13. `requiresFlags` 引用 karmaSeed ID 而非 flag

**问题诊断**  
部分卡牌的 `requiresFlags` 引用的是 karmaSeed 的 ID（如 `demonInternalConflict`），但 `requiresFlags` 系统检查的是 `gameState.flags`，而 karmaSeed 种植的是 `gameState.karmaSeeds`。两者存储位置不同，导致 `checkFlags()` 永远返回 `false`。

**修复方案**  
对需要 karmaSeed 触发的卡牌，改用正确的触发机制（由 `KarmaSystem` 在种子发芽时自动设置对应 flag）：

```javascript
// 在 KarmaSystem 种子发芽时同步设置 flag
plantSeed(seed) {
  // ...
  gameState.setFlag('karma_' + seed.id, true);  // 新增：同步设置 flag
}
```

或将卡牌的 `requiresFlags` 改为检查 `karma_` 前缀的 flag。

**验证方法**：运行数据校验脚本，检查所有 `requiresFlags` 引用的 ID 是否存在于 flag 种植来源中。

---

#### P1-14. 因果种子"孤儿"问题（9个无种植来源）

**问题诊断**  
`data/cards/karma.json` 的 `karmaCards` 映射中，存在多个种子 ID 有对应卡牌但**没有任何卡牌/支线/代码种植它们**：

| 孤儿种子 ID | 对应卡牌 | 状态 |
|------------|---------|------|
| `tianshuStarted` | `k_tianshu_echo` | 无种植来源 |
| `tianshuDeep` | `k_tianshu_revelation` | 无种植来源 |
| `bodyTrialStarted` | `k_body_echo` | 无种植来源 |
| `bodyTrialDeep` | `k_body_ascension` | 无种植来源 |
| `swordBetrayed` | `k_sword_betrayal` | 无种植来源 |
| `swordHonor` | `k_sword_honor` | 无种植来源 |
| `companionSacrifice` | `k_comp_sacrifice` | 无种植来源 |
| `companionTrust` | `k_comp_trust` | 无种植来源 |
| `fortuneWheel` | `k_fortune_wheel` | 无种植来源 |

**修复方案**  
对每个孤儿种子，在适当的支线/事件/战斗代码中补种：

- `tianshuStarted`/`tianshuDeep`：在"天书"支线完成时种植。
- `bodyTrialStarted`/`bodyTrialDeep`：在"肉身试炼"支线完成时种植。
- `swordBetrayed`/`swordHonor`：在剑修相关剧情选择中种植（如背叛同门或接受白刃传承）。
- `companionSacrifice`/`companionTrust`：在道侣危机事件后种植。
- `fortuneWheel`：在获得特殊命运物品时种植。

**验证方法**：运行数据校验脚本 `checkKarmaSeedMapping()`，确认所有 `karmaCards` 键均有种植来源。

---

#### P1-15. 天劫相关 flag 无种植来源

**问题诊断**  
`data/cards/interweave.json` 中 `iw_cut_ties_tribulation` 和 `iw_keep_ties_tribulation` 分别需要 `cutMortalTies` 和 `keepMortalTies` flag，但没有任何卡牌种植这两个 flag。

**修复方案**  
在渡劫期前的关键剧情卡中增加选择，种植对应 flag：

```json
// 在合适的"斩尘缘"/"守红尘"剧情卡中增加：
"choices": {
  "left": {
    "text": "斩断凡尘羁绊",
    "effects": { "daoHeart": 20 },
    "karmaSeed": { "id": "cutMortalTies", "delay": 1, "priority": 10 }
  },
  "right": {
    "text": "守护凡间亲人",
    "effects": { "karmaGood": 15 },
    "karmaSeed": { "id": "keepMortalTies", "delay": 1, "priority": 10 }
  }
}
```

**验证方法**：确认 `iw_cut_ties_tribulation` 和 `iw_keep_ties_tribulation` 在渡劫期可被抽出。

---

#### P1-16. `post_ascension.json` 叙事顺序崩坏

**问题诊断**  
`pa_engine_sighting`（天道引擎·远观）的左选择种植 `heavenEngineProximity` 种子，而 `pa_point_system`（积分体系）需要该 flag。但 `pa_harvest_season`（收割季）和 `pa_point_system` 均无线性依赖——玩家可能先看到"收割季"再看到"天道引擎远观"，叙事逻辑颠倒（先看到收割，再看到引擎）。

**修复方案**  
为 `pa_harvest_season` 增加 `requiresFlags: { heavenEngineProximity: null }`，确保玩家先看到引擎，再看到收割。同时 `pa_point_system` 保持对 `heavenEngineProximity` 的依赖。

---

#### P1-17. 跨线交织卡"冲突/和解"顺序颠倒

**问题诊断**  
`data/cards/interweave.json` 中 `iw_comp_demon_reconcile`（重修旧好）**没有 `requiresFlags`**，而 `iw_comp_demon_clash`（道不同）需要 `demonAccepted`。这意味着"和解"卡可能**先于"冲突"卡**出现，叙事上不可能：玩家先看到道侣原谅自己，再看到道侣质问自己。

同理，`iw_comp_sect_approve`（师父的认可）需要 `compSectDisapprove`，但 `iw_comp_sect_forbid`（师门的阻挠）没有 `once: true`，可能重复出现。

**修复方案**  
```json
// iw_comp_demon_reconcile 增加 requiresFlags
"requiresFlags": {
  "companionDemonClash": null  // 新增 flag，由 iw_comp_demon_clash 的任意选择种植
}

// iw_comp_demon_clash 的选择中增加 flag 种植
"choices": {
  "left": {
    "effects": { "daoHeart": 10 },
    "karmaSeed": { "id": "companionDemonClash", "delay": 1, "priority": 10 }
  }
}
```

---

#### P1-18. `whiteFox` 种子在 karma.json 中被重复定义

**问题诊断**  
`karma.json` 将 `whiteFox` 映射到 `k_fox_returns`，但 `white_fox.json` 的支线奖励种植的是 `foxGratitude`。更深层的问题是：`k_fox_returns` 本身在 `karma.json` 中作为普通因果卡存在，但**没有任何代码路径通过 `karmaSystem` 触发它**（因为 `whiteFox` 种子从未被种植）。

这导致 `whiteFox` 在 `karmaCards` 映射中是一个"死映射"——有定义但无触发路径。

**修复方案**  
同 P0-6：在 `q_whiteFox_3` 的选择中种植 `whiteFox` 种子。同时，从 `white_fox.json` 的 `rewardOnComplete` 中移除 `foxGratitude` 种子，改为由 `k_fox_returns` 的右选择种植。

---

#### P1-19. `interweave` 卡的 `companionEffects` 永不执行

**问题诊断**  
`data/cards/interweave.json` 中多张卡牌（如 `iw_comp_demon_clash`、`iw_comp_demon_reconcile`）包含 `companionEffects` 字段，但 `game.js:724-726` 仅在 `card.type === 'COMPANION_EVENT' || card.type === 'COMPANION_ARC'` 时处理 `companionEffects`：

```javascript
if ((card.type === 'COMPANION_EVENT' || card.type === 'COMPANION_ARC') && choice.comanionEffects) {
  companionSystem.applyChoice(choice);
}
```

而 `interweave.json` 中所有卡的 `type` 均为 `SPECIAL`，因此 `companionEffects`**永远不被执行**。道侣好感度变化在这些卡上完全无效。

**修复方案**  
扩展 `game.js` 中 `companionEffects` 的处理条件，包含交叉互动卡：

```javascript
// src/game.js:724-726（修改后）
const companionCardTypes = ['COMPANION_EVENT', 'COMPANION_ARC', 'SPECIAL'];
if (companionCardTypes.includes(card.type) && choice.companionEffects) {
  companionSystem.applyChoice(choice);
}
```

或更精确地，检查 `choice.companionEffects` 存在即处理：

```javascript
if (choice.companionEffects && companionSystem) {
  companionSystem.applyChoice(choice);
}
```

**验证方法**：触发 `iw_comp_demon_clash`，选择左选项，确认道侣好感度按 `companionEffects.affectionDelta` 正确变化。

---

#### P1-20. `rebirth.json` 中 `deckCard` / `removeCard` 格式与 `EffectService` 不兼容

**问题诊断**  
`data/cards/rebirth.json` 中 `rebirth_boon` 卡使用：

```json
"effects": { "deckCard": "sword_intent" }
"effects": { "removeCard": true, "health": 5 }
```

`EffectService` 的 `deckCard` handler 将值直接推入 `masterDeck`：

```javascript
this.handlers.set('deckCard', (value, context) => {
  if (typeof deckCombatSystem !== 'undefined' && deckCombatSystem) {
    deckCombatSystem.masterDeck.push(value);
  }
});
```

但 `rebirth_boon` 被触发时（`_reincarnate()` 后），`deckCombatSystem` 可能尚未初始化 `masterDeck`（`reset()` 会清空卡组）。此外，`removeCard: true` 在 `EffectService` 中调用 `ui.showRemoveCardScreen()`，但转世时 UI 可能尚未完成渲染。

**修复方案**  
1. 在 `_reincarnate()` 中延迟 `rebirth_boon` 的展示，直到 `deckCombatSystem` 初始化完成。  
2. 为 `deckCard` handler 增加空卡组保护：

```javascript
this.handlers.set('deckCard', (value, context) => {
  if (typeof deckCombatSystem !== 'undefined' && deckCombatSystem) {
    if (!deckCombatSystem.masterDeck) deckCombatSystem.masterDeck = [];
    deckCombatSystem.masterDeck.push(value);
    this._log(`获得战斗卡牌：【${value}】`, context);
  }
});
```

**验证方法**：转世后选择"前世的功法"（`deckCard: "sword_intent"`），确认 `deckCombatSystem.masterDeck` 包含该卡。

---

#### P1-21. 存档重载后支线锁死

**问题诊断**  
`QuestSystem._onReset()` 在 `state:reset` 事件时清空 `activeQuests` 和 `completedQuests`。但当玩家通过浏览器刷新重新加载页面时，`localStorage` 中保存的 `quest_*_active` flag 和 `quest_*_step` 仍然保留。`QuestSystem.init()` 加载后，**不会根据这些 flag 恢复进行中的支线状态**，导致：
- 已标记为 `quest_white_fox_line_active = true` 的支线不再被 `CardSystem.draw()` 识别。  
- 玩家卡在"有 active flag 但无 active quest"的状态，支线系统永久锁死。

**修复方案**  
在 `QuestSystem.init()` 中增加存档恢复逻辑：

```javascript
// src/systems/QuestSystem.js:24-33（修改后）
init() {
  eventBus.on('quest:checkTrigger', () => this._onCheckTrigger());
  eventBus.on('quest:requestCurrentCard', () => this._onRequestCurrentCard());
  eventBus.on('quest:requestEntryCard', () => this._onRequestEntryCard());
  eventBus.on('state:reset', () => this._onReset());
  
  // 新增：从 gameState.flags 恢复进行中的支线
  this._restoreActiveQuestsFromFlags();
}

_restoreActiveQuestsFromFlags() {
  for (const [key, value] of Object.entries(gameState.flags || {})) {
    if (key.startsWith('quest_') && key.endsWith('_active') && value) {
      const questId = key.replace('quest_', '').replace('_active', '');
      const step = gameState.getFlag('quest_' + questId + '_step', 0);
      if (this.quests.has(questId) && !this.activeQuests.find(q => q.questId === questId)) {
        this.activeQuests.push({ questId, step, startedAt: gameState.turn });
      }
    }
  }
}
```

**验证方法**：
1. 开始白狐支线（第一步后 `quest_white_fox_line_active = true`）。  
2. 刷新浏览器重新加载游戏。  
3. 确认 `QuestSystem.activeQuests` 自动恢复包含 `white_fox_line`。  
4. 确认下一张抽出的卡为 `q_whiteFox_2`（第二步）。

---


---

## 三、P2/P3级修复清单（2-4周）

P2/P3级问题导致**体验下降、数据不一致、维护困难或设计债务**。可在核心修复完成后逐步处理。

---

### P2级问题

#### P2-1. 寿元危机种子重复种植

**问题描述**: `game.js:828-830` 调用 `karmaSystem.getActiveSeeds('lifespanWaste')` 方法不存在，导致每回合重复种植。

**修复方案**: 实现 `getActiveSeeds` 方法，或改用 `gameState.karmaSeeds.filter`：

```javascript
// src/game.js:826-838（修改）
if (gameState.resources.lifespan <= 20 && gameState.resources.lifespan > 0) {
  const existing = gameState.karmaSeeds.filter(s => s.id === 'lifespanWaste');
  if (existing.length === 0) {
    karmaSystem.plantSeed({
      id: 'lifespanWaste',
      description: `寿元仅剩 ${gameState.resources.lifespan} 年，身体开始衰竭。`,
      originCard: card.id,
      magnitude: Math.max(1, 30 - gameState.resources.lifespan)
    });
  }
}
```

---

#### P2-2. `hasFlag` 语义错误

**问题描述**: `GameStateManager.js:203-205` 中 `hasFlag` 返回 `!!this.flags[key]`，flag 显式设为 `false` 时被视为不存在。

**修复方案**: 

```javascript
// src/core/GameStateManager.js:203-205
hasFlag(key) {
  return this.flags.hasOwnProperty(key) && this.flags[key] !== false;
}
```

---

#### P2-3. 寿命扣除绕过 `addResource`

**问题描述**: 多处直接 `gameState.resources.lifespan -= 1`，不经过 `Math.max(0, ...)` 保护。

**修复方案**: 统一使用 `addResource`：

```javascript
// src/game.js:822
// 原：gameState.resources.lifespan -= 1;
// 改为：
gameState.addResource('lifespan', null, -1);

// src/systems/CombatSystem.js:783,825
// 同样改为使用 addResource
```

---

#### P2-4. 战斗格挡系统状态残留

**问题描述**: `CombatSystem.js:52-71` 中 `reset()` 未清理 `_pendingBlockDamage` 和 `_pendingBlockSpecial`。

**修复方案**:

```javascript
// src/systems/CombatSystem.js:52-71
reset() {
  // ... 现有字段 ...
  this._pendingBlockDamage = undefined;
  this._pendingBlockSpecial = undefined;
}
```

---

#### P2-5. 日志上限过短

**问题描述**: `src/ui.js:15` 中 `maxLogMessages = 6`，战斗上下文几乎不可见。

**修复方案**:

```javascript
// src/ui.js:15
this.maxLogMessages = 20; // 从6提升到20
```

---

#### P2-6. `_markSourceUsed` 映射不完整

**问题描述**: `FlowDirector.js:537-558` 中 `breakthrough` 映射为 `normal`，无独立饥饿追踪。

**修复方案**:

```javascript
// src/systems/FlowDirector.js:537-558
var sourceMap = {
  'interrupt': 'interrupt',
  'combat_warning': 'combat',
  'breakthrough': 'breakthrough', // 改为独立追踪
  'milestone': 'milestone',
  // ...
};
```

---

#### P2-7. 阶段切换过快

**问题描述**: `FlowDirector.js:38-79` 中 `CALM` 阶段 `advanceRate = 8`，约13张卡就进入 `BUILDUP`。

**修复方案**:

```javascript
// src/systems/FlowDirector.js:38-46
CALM: {
  name: 'CALM',
  displayName: '风平浪静',
  weights: { normal: 70, lightStory: 15, shop: 10, exploration: 5 },
  advanceRate: 5, // 从8降低到5，延长平静期
  tensionTarget: 'low',
  desc: '日常修炼、小事件为主，让玩家放松'
}
```

---

#### P2-8. 支线推进隐式 `step++` 风险

**问题描述**: `QuestSystem.js:173-199` 中 `questNext` 找不到时回退为 `step++`，可能错位。

**修复方案**: 找不到 `questNext` 时记录警告，不自动推进：

```javascript
// src/systems/QuestSystem.js:181-190
if (choice.questNext) {
  const nextIndex = cards.findIndex(c => c.id === choice.questNext);
  if (nextIndex >= 0) {
    active.step = nextIndex;
    gameState.setFlag('quest_' + active.questId + '_step', nextIndex);
  } else {
    console.warn(`[QuestSystem] questNext "${choice.questNext}" not found in quest "${active.questId}"`);
    // 不推进，保持在当前步骤，等待修正
  }
}
```

---

#### P2-9. `_narrativeQueue` 在 FlowDirector 缺失时成为死队列

**问题描述**: `game.js:865-873` 中 `!flowDirector` 时叙事卡放入 `_narrativeQueue`，但 `getCurrentCard` 从不读取。

**修复方案**: 在 `getCurrentCard` 中检查并消费 `_narrativeQueue`：

```javascript
// src/game.js:396-510（在 getCurrentCard 中添加）
getCurrentCard() {
  // ... 原有逻辑 ...
  
  // 消费叙事队列（当 FlowDirector 不可用时）
  if (!this.currentCard && (!typeof flowDirector !== 'undefined' || !flowDirector) && this._narrativeQueue && this._narrativeQueue.length > 0) {
    const wrapper = this._narrativeQueue.shift();
    this.currentCard = wrapper.card || wrapper;
    return this.currentCard;
  }
  
  // ... 其余逻辑 ...
}
```

---

#### P2-10. FlowDirector 与 CardSystem 抽卡逻辑严重重复

**问题描述**: `FlowDirector.js:414-513` 和 `CardSystem.js:617-688` 有几乎完全相同的过滤、权重、冷却逻辑。

**修复方案**: 将公共逻辑提取为 `CardPoolFilter` 工具类，供两者共用。

---

#### P2-11. `_checkEffectCost` lifespan 边界错误

**问题描述**: `game.js:975-990` 中 `<= 0` 导致最后1年寿命无法使用。

**修复方案**:

```javascript
// src/game.js:984-988
if (effects.lifespan !== undefined && effects.lifespan < 0) {
  if (gameState.resources.lifespan + effects.lifespan < 0) {
    return false;
  }
}
```

---

#### P2-12. 转世后 `quest_active` 标志残留

**问题描述**: `GameStateManager.js:37-114` 中 `reset(true)` 保留 `savedUnlocks.flags`，转世后已完成的支线标志仍保留。

**修复方案**: 在 `reset` 中清理 `quest_*_active` 标志：

```javascript
// src/core/GameStateManager.js:96-100
this.flags = savedUnlocks.flags || {};
// 清理残留的 quest_active 标志
for (const key of Object.keys(this.flags)) {
  if (key.startsWith('quest_') && key.endsWith('_active')) {
    delete this.flags[key];
  }
}
```

---

#### P2-13. 秘境图模式无限递归风险

**问题描述**: `CardSystem.js:857-924` 中节点缺失 `card` 且 `next` 指向另一个缺失节点时，无最大深度限制。

**修复方案**:

```javascript
// src/systems/CardSystem.js:883-950（添加最大深度限制）
_drawDungeonGraphCard(dungeon, depth = 0) {
  const MAX_DEPTH = 50;
  if (depth > MAX_DEPTH) {
    console.error('[DungeonGraph] Max depth exceeded, exiting dungeon');
    gameState.dungeon = null;
    gameState.dungeonNodeId = null;
    gameState.dungeonPath = [];
    eventBus.emit('dungeon:completed', {});
    return this.draw();
  }
  // ... 原有逻辑，递归调用时传递 depth + 1
  if (node.next) {
    gameState.dungeonNodeId = node.next;
    return this._drawDungeonGraphCard(dungeon, depth + 1);
  }
}
```

---

#### P2-14. `pill` 效果字段类型不一致

**问题描述**: 部分卡牌使用 `pill` 作为字符串值，但 `addResource` 预期数值型。

**修复方案**: 在 `EffectService` 中统一处理：

```javascript
// src/services/EffectService.js:80-83
this.handlers.set('pill', (value, context) => {
  if (typeof value === 'string') {
    this.gameState.addResource('pills', value, 1);
    this._log(`获得丹药：${value}`, context);
  } else {
    // 数值型：向后兼容
    this.gameState.addResource('pills', 'generic', value);
  }
});
```

---

### P3级问题

| # | 问题 | 位置 | 修复建议 |
|---|------|------|---------|
| P3-1 | 数据双重维护 | `index.html` + `data/` | 将 `DATA_MODULES` 剥离，使用 `DataLoader` 统一加载 |
| P3-2 | 缺少构建系统 | 项目根目录 | 引入 Vite 或 Rollup 做模块打包 |
| P3-3 | 混合编码风格 | 所有 JS 文件 | 统一为 ES6 class + const/let 风格 |
| P3-4 | 缺失角色概念图 | `assets/characters/*.webp` | 生成/采购 18 张概念图 |
| P3-5 | 缺失章节里程碑场景图 | `data/cards/chapter_milestones.json` | 生成/采购 30 张场景图 |
| P3-6 | 未使用的 `instance` 变量 | `FlowDirector.js:125` | 删除 `var instance = null;` |
| P3-7 | `_loadUnlocks` 前向兼容逻辑 | `GameStateManager.js:453-458` | 使用 JSON Schema 做结构化验证 |
| P3-8 | 没有自动化测试 | 项目根目录 | 添加 Jest/Vitest 单元测试框架 |
| P3-9 | combat 与 UI 日志同步脆弱 | `CombatSystem.js` + `ui.js` | 使用事件驱动替代直接清空日志 |
| P3-10 | 高境界内容空缺 | `README.md` + 数据层 | 填充元婴、化神、渡劫三个境界的卡牌池 |
| P3-11 | `protagonist.json` 关系键缩写 | `data/protagonist.json` | 统一为完整NPC ID |
| P3-12 | 配置分散无交叉验证 | `data/config/` | 建立 JSON Schema 校验 |

---

## 四、实施路线图

### 第1周：P0修复 + 目标HUD + 选择反馈

| 天数 | 任务 | 交付物 | 验收标准 |
|------|------|--------|---------|
| Day 1-2 | P0-1 REALM_ORDER、P0-3 被动回血、P0-5 NPC ID | 修复后的JS文件 | 游戏运行12回合不崩溃，世界事件正常触发 |
| Day 2-3 | P0-2 死亡卡、P0-4 正魔线种子、P0-6 白狐回响 | 修复后的JS+JSON | 死亡卡正常展示，正魔线第三幕可达 |
| Day 4 | 顶部HUD"当前目标"面板 | 修改后的 `ui.js` | 玩家始终看到"积累修为至X，突破Y境界" |
| Day 5 | 选择反馈系统（后果预览+颜色区分） | 修改后的 `ui.js` | 选项按钮下方显示后果预览 |
| 周末 | 集成测试 | 测试报告 | P0全部通过，HUD和选择反馈正常工作 |

### 第2周：P1修复 + 属性简化 + 因果可视化

| 天数 | 任务 | 交付物 | 验收标准 |
|------|------|--------|---------|
| Day 1-2 | P1-1 商店跳过回合、P1-2 realmOrder、P1-4 for...in Map | 修复后的JS | 商店选择后回合结算正常，FlowDirector能抽到额外模块卡 |
| Day 3 | P1-6 cultivation上限、P1-7 delay缺失、P1-8 maxHealth | 修改后的 `GameStateManager.js` + `CardSystem.js` | cultivation可按境界阈值增长 |
| Day 4 | 属性面板简化（主显/次显分离） | 修改后的 `index.html` + `ui.js` | 修为/气血/寿元始终可见，其余折叠 |
| Day 5 | 因果簿UI面板 | 新增 `ui.js` 方法 | 玩家可查看所有已种下的种子和预计发芽时间 |
| 周末 | P1级集成测试 | 测试报告 | P1修复全部通过 |

### 第3周：叙事连贯性 + 功法差异化 + 战斗系统统一

| 天数 | 任务 | 交付物 | 验收标准 |
|------|------|--------|---------|
| Day 1-2 | P1-9 DeckCombat enemy数据、P1-10 事件格式、P1-12 战斗奖励 | 修改后的 `DeckCombatSystem.js` | DeckCombatSystem读取enemy数据，胜利发放奖励 |
| Day 3 | 废弃旧 CombatSystem（移除事件监听） | 修改后的 `CombatSystem.js` | 旧系统不再监听 `combat:start` |
| Day 4 | 功法差异化（专属机制实现） | 修改后的 `path_skills.json` + `game.js` | 4个功法有明显不同的战斗/修炼体验 |
| Day 5 | 叙事连贯性优化（位置锚定+事件链） | 修改后的 `coherenceLayer` | 卡牌间有过渡叙事，事件链正常触发 |
| 周末 | 战斗系统端到端测试 | 测试报告 | 所有战斗路径奖励正确 |

### 第4周：测试 + 高境界内容填充 + 资源补充

| 天数 | 任务 | 交付物 | 验收标准 |
|------|------|--------|---------|
| Day 1-2 | P2级修复（批量处理） | 修改后的多个JS文件 | P2问题全部修复 |
| Day 3 | 元婴期卡牌池填充 | 新增 `data/cards/nascent.json` | 元婴期不再大量抽到兜底卡 |
| Day 4 | 化神期+渡劫期卡牌池填充 | 新增 `data/cards/deity.json` + `tribulation.json` | 高境界有专属事件 |
| Day 5 | 性能测试 + 资源补充 | 测试报告 | UI渲染流畅，无内存泄漏 |
| 周末 | 最终验收测试 | 完整测试报告 | 从开局到飞升的完整流程可运行 |

---

## 五、测试策略

### 5.1 单元测试

覆盖以下核心模块：

```javascript
// 示例：GameStateManager 单元测试
describe('GameStateManager', () => {
  test('setAttribute should respect realm-specific cultivation threshold', () => {
    const gsm = new GameStateManager();
    gsm.config.realms = {
      order: ['qi', 'foundation'],
      realms: {
        qi: { cultivationThreshold: 100 },
        foundation: { cultivationThreshold: 200 }
      }
    };
    gsm.realm = 'foundation';
    gsm.setAttribute('cultivation', 250);
    expect(gsm.attributes.cultivation).toBe(200);
  });
  
  test('hasFlag should treat explicit false as not having flag', () => {
    const gsm = new GameStateManager();
    gsm.setFlag('testFlag', false);
    expect(gsm.hasFlag('testFlag')).toBe(false);
  });
});
```

### 5.2 端到端测试

从开局到第一次死亡/转世的完整流程：

```javascript
// e2e/test_full_flow.js
async function testFullFlow() {
  gameLogic.start('sword');
  
  for (let i = 0; i < 100; i++) {
    const card = gameLogic.getCurrentCard();
    const dirs = gameLogic.getAvailableDirections(card);
    if (dirs.length > 0) {
      gameLogic.makeChoice(dirs[0]);
    }
  }
  
  assert(logContains('东海远海'));
  if (gameState.dead) {
    assert(gameLogic.currentCard.id.startsWith('death_'));
  }
}
```

**覆盖目标**：所有6条支线、正魔线、转世系统、所有境界突破。

### 5.3 数据验证脚本

```javascript
// scripts/validate_data.js
function checkFlagReferences() {
  const allCards = loadAllCards();
  const allFlags = new Set();
  const requiredFlags = new Set();
  
  for (const card of allCards) {
    if (card.choices) {
      for (const choice of Object.values(card.choices)) {
        if (choice.flags) choice.flags.forEach(f => allFlags.add(f));
      }
    }
    if (card.requiresFlags) {
      Object.keys(card.requiresFlags).forEach(f => requiredFlags.add(f));
    }
  }
  
  for (const flag of requiredFlags) {
    if (!allFlags.has(flag) && !isAutoFlag(flag)) {
      console.error(`Flag "${flag}" 被 requiresFlags 引用，但无种植来源`);
    }
  }
}

function checkKarmaSeedMapping() {
  const karmaData = JSON.parse(fs.readFileSync('data/cards/karma.json'));
  const allSeeds = new Set(Object.keys(karmaData.karmaCards));
  const plantedSeeds = new Set();
  // 遍历所有卡牌收集种植的 seed
  for (const seed of allSeeds) {
    if (!plantedSeeds.has(seed)) {
      console.error(`KarmaSeed "${seed}" 有对应因果卡，但无种植来源`);
    }
  }
}
```

### 5.4 性能测试

| 测试项 | 指标 | 方法 |
|--------|------|------|
| UI渲染 | 单帧 < 16ms | Chrome DevTools Performance |
| 日志上限 | 内存稳定 | 运行500回合监控内存 |
| 卡牌加载 | 首屏 < 3s | Lighthouse |
| 秘境递归 | 无栈溢出 | 构造循环节点图测试 |

---

## 六、长期建议

### 6.1 引入构建系统（Vite/Rollup）

**现状**: 无 npm/rollup/webpack/vite，所有 JS 通过 `<script>` 标签按顺序加载，全局命名空间污染严重。

**建议**: 
1. 使用 Vite 作为构建工具。
2. 将全局单例改为 ES Module 导出。

```javascript
// 目标架构
import { GameStateManager } from './core/GameStateManager.js';
import { CardSystem } from './systems/CardSystem.js';

const gameState = new GameStateManager();
const cardSystem = new CardSystem();
```

### 6.2 引入 TypeScript

**现状**: 无类型检查，大量低级错误。

**建议**:
1. 逐步迁移：新文件用 `.ts`，旧文件保留 `.js`。
2. 为核心接口定义类型。

### 6.3 建立数据规范文档

| 规范项 | 说明 | 示例 |
|--------|------|------|
| NPC ID | 使用下划线连接的完整名称 | `tianji_laoren` |
| flag 命名 | 小写驼峰 | `demonAccepted` |
| karmaSeed ID | 小写驼峰 | `whiteFox` |
| realm 名称 | 配置中定义的键 | `qi`、`deity` |

### 6.4 建立自动化 CI/CD

```yaml
# .github/workflows/ci.yml
name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: '18'
      - run: npm ci
      - run: npm run test
      - run: npm run validate-data
      - run: npm run build
```

---

> **文档结束**
> 
> 本修复计划基于 `游戏全面审查报告_v2.md`（2026-07-14）和 `游戏审查报告.md`（2026-07-01）制定。
> 所有代码修改均基于对现有文件的实际分析，具体文件路径和代码位置已在各修复项中注明。
> 建议按照"P0 → P1 → P2/P3"的顺序执行修复，每完成一级修复后进行全面的回归测试。
