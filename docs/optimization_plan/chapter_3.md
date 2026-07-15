# 第三章：核心循环与叙事优化

> **本章定位**：针对玩家反馈"玩得莫名其妙，不知道在玩什么"的核心问题，从游戏循环节奏、叙事连贯性、因果系统可视化、支线系统优化四个维度进行重构设计。
>
> **关联审查报告**：P0-4（正魔线不可达）、P0-6（白狐回响断裂）、P1-4（FlowDirector `for...in` 遍历 Map）、P1-14（9个孤儿因果种子）、P1-19（故事线程无引擎）、P1-21（存档重载锁死支线）、P2-7（阶段切换过快）、P2-9（`_narrativeQueue` 死队列）

---

## 1. 核心游戏循环重构

### 1.1 问题诊断

**当前问题**：抽卡→选择→数字+5→抽卡→选择→数字+3，没有节奏感。玩家处于"炼气期"这个长周期内，每一张卡的概率分布基本相同，无法感知"我现在处于什么阶段"。

**代码证据**：

1. **FlowDirector 阶段切换过快**：`FlowDirector.js:43` 中 `CALM` 阶段 `advanceRate = 8`，`PHASE_ORDER` 共5个阶段，每阶段进度100，意味着约 `100/8 = 12.5` 张卡就切换一次阶段。玩家几乎没有时间体验"风平浪静"的积累期，就进入高压的 `TENSION`/`CLIMAX`：

```javascript
// src/systems/FlowDirector.js:38-79
var PHASES = {
  CALM: { advanceRate: 8, ... },      // ~12.5张卡切换
  BUILDUP: { advanceRate: 6, ... }, // ~16.7张卡切换
  TENSION: { advanceRate: 5, ... },  // 20张卡切换
  CLIMAX: { advanceRate: 4, ... },   // 25张卡切换
  RESOLUTION: { advanceRate: 10, ... } // 10张卡切换
};
```

2. **卡池无阶段过滤**：`_drawNormalWithMood`（`FlowDirector.js:414`）和 `CardSystem._drawNormal`（`CardSystem.js:617`）中，仅根据 `card.realm` 和 `card.path` 过滤，没有基于修为进度的阶段过滤。这意味着玩家在修为0时和修为90时，面对的卡池概率分布完全相同：

```javascript
// src/systems/FlowDirector.js:414-513 _drawNormalWithMood
// 过滤条件：境界、功法、一次性、冷却、flags——但没有 cultivation 范围
if (card.realm && card.realm !== gameState.realm) continue;
if (card.path && card.path !== gameState.path) continue;
// ... 缺少 cultivation 阶段过滤
```

3. **额外卡池不可达（P1-4）**：`FlowDirector.js:429-436` 使用 `for...in` 遍历 `cardSystem.cardCache`（ES6 Map），导致 `extraCards` 永远为空：

```javascript
// src/systems/FlowDirector.js:429-436 ❌ 错误代码
for (var id in cardSystem.cardCache) {  // for...in 对 Map 无效！
  var card = cardSystem.cardCache[id];   // 永远为 undefined
  // ...
}
```

这导致 `_loadExtraModule` 加载的所有卡牌（魔道女修、转世回响、跨线交织、正魔线、飞升后）在 FlowDirector 模式下**永远不会被抽到**。

### 1.2 优化方案：章节式三阶段循环

引入"境界内三阶段"概念：每个境界分为**积累期→瓶颈期→突破期**，不同阶段卡池不同，UI上明确标示当前阶段。

| 阶段 | 修为范围 | 卡池特征 | 节奏设计 | UI标识 |
|------|---------|---------|---------|--------|
| **积累期** | 0-70%阈值 | 修炼、采集、日常事件为主；战斗卡概率低 | 舒缓、安全、正向反馈为主 | "修炼积累" |
| **瓶颈期** | 70-100%阈值 | 战斗、抉择、危机事件概率提升；出现"瓶颈预感"卡 | 紧张、风险增加、选择代价变大 | "瓶颈将至" |
| **突破期** | ≥100%阈值 | 触发突破卡牌（`breakthroughCard`），高风险高回报 | 决定性时刻、成败在此一举 | "突破时机" |

**三阶段的心理学设计意图**：
- **积累期**：让玩家建立安全感，逐步积累修为，体验"变强"的正反馈
- **瓶颈期**：制造紧张感，通过增加战斗和危机事件的频率，让玩家感到"修为难以精进"，需要做出关键抉择
- **突破期**：高潮时刻，突破成功带来巨大正反馈（境界提升），失败则承受代价（心魔反噬）

### 1.3 具体实现

#### 1.3.1 修改 FlowDirector.js：增加阶段过滤逻辑

```javascript
// src/systems/FlowDirector.js — 在 _drawPhaseWeighted 中增加 cultivation 阶段判断

function _getCultivationPhase() {
  const realmConfig = gameState.config.realms 
    ? gameState.config.realms.realms[gameState.realm] 
    : null;
  if (!realmConfig) return 'accumulation';
  
  const threshold = realmConfig.cultivationThreshold || 100;
  const cultivation = gameState.attributes.cultivation || 0;
  const ratio = cultivation / threshold;
  
  if (ratio >= 1.0) return 'breakthrough';   // 突破期
  if (ratio >= 0.7) return 'bottleneck';      // 瓶颈期
  return 'accumulation';                      // 积累期
}

function _drawPhaseWeighted() {
  // ... 原有代码 ...
  
  const cultivationPhase = _getCultivationPhase();
  
  // 根据 cultivation 阶段调整阶段权重
  var adjustedWeights = {};
  for (var key in weights) {
    var w = weights[key];
    
    //  cultivation 阶段过滤：瓶颈期增加战斗/挑战权重
    if (cultivationPhase === 'bottleneck') {
      if (key === 'combat' || key === 'combatLight') w *= 2.0;
      if (key === 'challenge') w *= 1.8;
      if (key === 'normal') w *= 0.6;        // 减少平淡日常
      if (key === 'lightStory') w *= 0.5;    // 减少轻松叙事
    }
    // 积累期：增加日常/探索/奖励
    else if (cultivationPhase === 'accumulation') {
      if (key === 'normal') w *= 1.3;
      if (key === 'exploration') w *= 1.5;
      if (key === 'reward') w *= 1.3;
      if (key === 'combat') w *= 0.5;         // 减少战斗
    }
    // 突破期：强制导向突破或瓶颈卡
    else if (cultivationPhase === 'breakthrough') {
      if (key === 'combat') w *= 0.3;         // 大幅减少战斗
      if (key === 'normal') w *= 0.4;
      // 突破卡由 P90 优先级独立处理，此处不重复
    }
    
    // 情绪影响 + 饥饿加成（原有逻辑）
    if (moodWeights[key]) w *= moodWeights[key];
    var starvationBoost = _getStarvationBoost(key);
    if (starvationBoost > 1) w *= starvationBoost;
    
    adjustedWeights[key] = w;
    totalWeight += w;
  }
  
  // ... 后续原有逻辑 ...
}
```

#### 1.3.2 修改 CardSystem.js：根据 cultivation 范围过滤卡池

```javascript
// src/systems/CardSystem.js — 在 _drawNormal 中增加 cultivationRange 过滤

_drawNormal() {
  this._loadRealmCards(gameState.realm);
  
  const candidates = [];
  const pool = this.getCardPool(gameState.realm);
  const recentPlayed = new Set(gameState.cardsPlayed.slice(-8));
  
  // 计算当前 cultivation 阶段
  const realmConfig = gameState.config.realms 
    ? gameState.config.realms.realms[gameState.realm] 
    : null;
  const threshold = realmConfig ? realmConfig.cultivationThreshold : 100;
  const cultivation = gameState.attributes.cultivation || 0;
  const ratio = cultivation / threshold;
  
  // 合并额外卡池（修复 P1-4：for...in → for...of）
  const poolIds = new Set(pool.map(c => c.id));
  const extraCards = [];
  // ✅ 修复：使用 for...of 遍历 Map
  for (const [id, card] of this.cardCache) {
    if (!poolIds.has(id) && card && card.realm && 
        card.type !== 'DESTINY' && card.type !== 'BOTTLENECK') {
      extraCards.push(card);
    }
  }
  
  const allPool = [...pool, ...extraCards];
  
  for (const card of allPool) {
    // 跳过特殊类型
    if (['DESTINY', 'BOTTLENECK', 'KARMA', 'QUEST'].includes(card.type)) continue;
    
    // 境界过滤
    if (card.realm && card.realm !== gameState.realm) continue;
    
    // ✅ 新增：cultivationRange 阶段过滤
    if (card.cultivationRange) {
      const [min, max] = card.cultivationRange;
      if (cultivation < min || cultivation > max) continue;
    }
    // 如果卡牌没有 cultivationRange，默认在所有阶段都可出现
    
    // 瓶颈期特殊规则：在瓶颈期（ratio >= 0.7），标记为 bottleneckOnly 的卡概率翻倍
    if (ratio >= 0.7 && card.tags && card.tags.includes('bottleneck')) {
      // 权重在后续计算中处理
    }
    // 积累期特殊规则：bottleneckOnly 的卡不出现
    if (ratio < 0.7 && card.tags && card.tags.includes('bottleneckOnly')) {
      continue;
    }
    
    // 功法过滤（原有）
    if (card.path && card.path !== gameState.path) continue;
    
    // 一次性过滤（原有）
    if (card.once && gameState.cardsPlayed.includes(card.id)) continue;
    
    // 冷却（原有）
    if (recentPlayed.has(card.id)) continue;
    
    // Flags 条件（原有）
    if (card.requiresFlags && !gameState.checkFlags(card.requiresFlags)) continue;
    if (card.forbiddenFlags) { /* ... */ }
    
    let weight = card.weight !== undefined ? card.weight : 5;
    
    // 功法亲和（原有）
    if (card.path === gameState.path) weight *= 1.5;
    
    // ✅ 新增：阶段权重调整
    if (ratio >= 0.7 && ratio < 1.0) {
      // 瓶颈期：瓶颈标签卡权重翻倍
      if (card.tags && card.tags.includes('bottleneck')) weight *= 2.0;
      // 危机标签卡权重提升
      if (card.tags && card.tags.includes('crisis')) weight *= 1.8;
      // 安全/日常标签卡权重降低
      if (card.tags && card.tags.includes('daily')) weight *= 0.5;
    } else if (ratio < 0.7) {
      // 积累期：日常标签卡权重提升
      if (card.tags && card.tags.includes('daily')) weight *= 1.3;
      // 瓶颈标签卡不出现
      if (card.tags && card.tags.includes('bottleneckOnly')) weight = 0;
    }
    
    // 福缘、恶因影响（原有）
    if (gameState.attributes.fortune > 70 && card.tags && !card.tags.includes('risk')) {
      weight += 2;
    }
    if (gameState.attributes.karmaBad > 50 && card.tags && card.tags.includes('demon')) {
      weight *= 1.3;
    }
    
    for (let i = 0; i < Math.max(1, Math.round(weight)); i++) {
      candidates.push(card);
    }
  }
  
  // ... 后续原有逻辑 ...
}
```

#### 1.3.3 修改 FlowDirector.js：修复 P1-4（`for...in` → `for...of`）

```javascript
// src/systems/FlowDirector.js:429-436 — 修复遍历 Map 的错误

// ❌ 错误代码：
// for (var id in cardSystem.cardCache) {
//   var card = cardSystem.cardCache[id];
//   ...
// }

// ✅ 正确代码：
if (cardSystem.cardCache) {
  for (const [id, card] of cardSystem.cardCache) {
    if (!poolIds.has(id) && card && card.realm && 
        card.type !== 'DESTINY' && card.type !== 'BOTTLENECK') {
      extraCards.push(card);
    }
  }
}
```

#### 1.3.4 调整阶段切换速率（修复 P2-7）

```javascript
// src/systems/FlowDirector.js:38-79 — 降低阶段切换速度

var PHASES = {
  CALM: {
    name: 'CALM',
    displayName: '风平浪静',
    weights: { normal: 70, lightStory: 15, shop: 10, exploration: 5 },
    advanceRate: 4,        // ← 从 8 降到 4，~25张卡切换
    tensionTarget: 'low',
    desc: '日常修炼、小事件为主，让玩家放松'
  },
  BUILDUP: {
    name: 'BUILDUP',
    displayName: '暗流涌动',
    weights: { normal: 45, story: 20, shop: 10, exploration: 10, combatLight: 15 },
    advanceRate: 3,        // ← 从 6 降到 3，~33张卡切换
    tensionTarget: 'medium',
    desc: '引入支线、轻战斗，节奏逐渐加快'
  },
  TENSION: {
    name: 'TENSION',
    displayName: '危机四伏',
    weights: { normal: 25, story: 15, combat: 35, challenge: 25 },
    advanceRate: 3,        // ← 从 5 降到 3
    tensionTarget: 'high',
    desc: '高强度战斗+抉择，玩家压力达到高峰'
  },
  CLIMAX: {
    name: 'CLIMAX',
    displayName: '决战时刻',
    weights: { combat: 50, story: 20, challenge: 30 },
    advanceRate: 2,        // ← 从 4 降到 2
    tensionTarget: 'critical',
    desc: 'Boss战/重大抉择，不可回头'
  },
  RESOLUTION: {
    name: 'RESOLUTION',
    displayName: '尘埃落定',
    weights: { normal: 35, story: 35, reward: 20, shop: 10 },
    advanceRate: 5,        // ← 从 10 降到 5
    tensionTarget: 'low',
    desc: '战后收尾、奖励发放、故事交代'
  }
};
```

### 1.4 数据层修改示例

为现有卡牌添加 `cultivationRange` 和 `tags` 标记，以炼气期为例：

```json
// data/cards/qi_condensation.json — 示例修改
{
  "cards": [
    {
      "id": "q_meditation",
      "title": "潜心修炼",
      "description": "你盘膝而坐，运转周天，吐纳灵气...",
      "tags": ["daily", "cultivation"],
      "cultivationRange": [0, 70],  // ← 积累期专属
      "choices": { ... }
    },
    {
      "id": "q_bottleneck_omen",
      "title": "瓶颈征兆",
      "description": "你感到修为停滞不前，丹田中的灵气似乎遇到了某种壁垒...",
      "tags": ["bottleneck", "crisis"],
      "cultivationRange": [50, 100],  // ← 瓶颈期出现
      "choices": { ... }
    },
    {
      "id": "q_heart_demon_whisper",
      "title": "心魔低语",
      "description": "突破在即，识海中却传来不安的声音...",
      "tags": ["bottleneckOnly", "inner_demon"],
      "cultivationRange": [85, 100],  // ← 仅瓶颈期后期出现
      "choices": { ... }
    }
  ]
}
```

### 1.5 UI层修改：阶段标识

```javascript
// src/ui.js — 在 renderTopBar 中增加 cultivation 阶段显示

renderTopBar() {
  // ... 原有代码 ...
  
  // ──  cultivation 阶段显示 ──
  if (this.topPhase) {
    const realmConfig = gameState.config.realms 
      ? gameState.config.realms.realms[gameState.realm] 
      : null;
    const threshold = realmConfig ? realmConfig.cultivationThreshold : 100;
    const cultivation = gameState.attributes.cultivation || 0;
    const ratio = cultivation / threshold;
    
    let phaseText = '';
    let phaseClass = '';
    if (ratio >= 1.0) {
      phaseText = '🔥 突破时机';
      phaseClass = 'phase-breakthrough';
    } else if (ratio >= 0.7) {
      phaseText = '⚡ 瓶颈将至';
      phaseClass = 'phase-bottleneck';
    } else {
      phaseText = '🌿 修炼积累';
      phaseClass = 'phase-accumulation';
    }
    
    // 如果 FlowDirector 阶段也存在，合并显示
    if (typeof flowDirector !== 'undefined' && flowDirector) {
      const fdPhase = flowDirector.getPhaseInfo().displayName;
      this.topPhase.textContent = `${phaseText} · ${fdPhase}`;
    } else {
      this.topPhase.textContent = phaseText;
    }
    this.topPhase.className = `badge phase ${phaseClass}`;
    this.topPhase.style.display = 'inline-block';
  }
  
  // ... 后续原有代码 ...
}
```

### 1.6 预期效果

1. **节奏感知**：玩家能明确感知"我现在处于修炼的哪个阶段"——积累期安心修炼，瓶颈期紧张抉择，突破期放手一搏
2. **卡池丰富度**：通过 cultivationRange 过滤，同一境界内的不同修为阶段呈现不同卡池，避免"炼气期100张卡千篇一律"
3. **P1-4修复**：额外卡池（魔道女修、转世回响、正魔线等）在 FlowDirector 模式下恢复正常可达
4. **P2-7修复**：阶段切换速率降低约50%，每个阶段能体验20-30张卡，建立稳定的节奏预期

### 1.7 验收标准

- [ ] 在积累期（修为<70%阈值），`bottleneckOnly` 标签卡牌不出现
- [ ] 在瓶颈期（修为≥70%阈值），`bottleneck` 标签卡牌权重翻倍，`daily` 标签卡牌权重减半
- [ ] FlowDirector 模式下，`_loadExtraModule` 加载的卡牌（如正魔线）可被正常抽到
- [ ] 一个完整境界（从0修为到突破）经历至少 80-100 张卡，其中 CALM 阶段 ≥ 25张

---

## 2. 叙事连贯性优化

### 2.1 问题诊断

**当前问题**：上一张救了白狐，下一张变成长老讲道，卡牌之间没有联系。玩家感到"每一张卡都是独立的，我的选择没有在世界中留下痕迹"。

**代码证据**：

1. **过渡文字触发率低**：`NarrativeCoherenceLayer.js:280-375` 中 `buildTransition` 有50%概率跳过（`Math.random() > this._transitionProbability`），且过渡文字模板较为平淡，多为"你深吸一口气，继续前行"：

```javascript
// src/systems/NarrativeCoherenceLayer.js:280-375
buildTransition(nextCard, gameState, threadEngine, questSystem, npcSystem) {
  // 冷却检查
  if (gameState.turn - this._lastTransitionTurn < this._transitionCooldown) {
    return null;
  }
  // ...
  // 非强触发时检查概率
  if (!isStrongTrigger && Math.random() > this._transitionProbability) {
    return null;  // ← 50% 概率直接跳过过渡
  }
  // ...
}
```

2. **选择回响触发面过窄**：`ChoiceEchoEngine.js:48-101` 的 `plantEcho` 仅在 `COMPANION_ARC`、`COMPANION_EVENT`、`MENTOR_ARC`、`ALLY_ARC`、`SEER_ARC` 五种卡牌类型上触发。大量普通选择（如救白狐、杀妖兽、买丹药）完全没有被记录：

```javascript
// src/game.js:1492-1512 _plantChoiceEcho
_plantChoiceEcho(card, direction, choice) {
  if (!card || !choice) return;
  if (typeof choiceEchoEngine === 'undefined' || !choiceEchoEngine) return;
  // 仅在特定卡牌类型上触发
  const echoTypes = ['COMPANION_ARC', 'COMPANION_EVENT', 'MENTOR_ARC', 'ALLY_ARC', 'SEER_ARC'];
  if (echoTypes.includes(card.type)) {
    choiceEchoEngine.plantEcho({...});
  }
  // 普通选择（如救白狐、战斗）完全不被记录
}
```

3. **位置切换过于隐性**：`game.js:463-469` 中，卡牌驱动的位置切换仅在 `this.currentCard.location` 与当前位置不同时触发，但切换时没有过渡叙事，玩家可能完全没注意到自己"移动了"：

```javascript
// src/game.js:463-469
if (this.currentCard && this.currentCard.location &&
    typeof sceneLayerSystem !== 'undefined' && sceneLayerSystem) {
  const currentLoc = gameState.currentLocation;
  if (currentLoc !== this.currentCard.location) {
    sceneLayerSystem.transition(this.currentCard.location, 'card_driven');
    // ← 没有过渡叙事，玩家感知不到位置变化
  }
}
```

4. **故事线程引擎未实例化（P1-19）**：`game.js:859-873` 中 `threadEngine` 仅在 `typeof threadEngine !== 'undefined'` 时执行，但 `threadEngine` 从未被实例化，导致 `qi_threads.json` 中定义的5条完整故事线程完全不可达：

```javascript
// src/game.js:859-873
if (typeof threadEngine !== 'undefined' && threadEngine) {
  threadEngine.onChoiceMade(card, direction, choice, gameState);
  threadEngine.tick(gameState);
  const threadCard = threadEngine.getNextThreadCard(gameState);
  // ... 但 threadEngine 从未被实例化，此代码块永不执行
}
```

### 2.2 优化方案

#### 2.2.1 位置锚定：每个位置有独立卡池与过渡叙事

将"位置"从隐性的 `card.location` 提升为核心游戏机制：

| 位置 | 卡池特征 | 过渡叙事示例 |
|------|---------|------------|
| **宗门** | 修炼、讲道、同门互动、支线触发 | "你御剑返回青云宗，山门前的石狮子依旧沉默。" |
| **坊市** | 交易、拍卖、消息、偶遇 | "坊市的喧嚣扑面而来，丹药和灵草的气味混在一起。" |
| **秘境** | 探索、战斗、奇遇、陷阱 | "你踏入了迷雾山谷，连灵气都变得陌生。" |
| **洞府** | 闭关、炼丹、炼器、心魔 | "洞府的石门在你身后缓缓关闭，世界被隔绝在外。" |
| **魔域** | 正魔线、危险事件、特殊交易 | "这里的灵气带着铁锈的味道——不，是血。" |

**位置切换时的过渡叙事规则**：
1. 每次切换位置时，**强制**显示一段过渡文字（100%触发，不随机跳过）
2. 过渡文字从位置专属的模板库中抽取，结合当前修为阶段和最近事件
3. 过渡文字中引用最近的重要选择（如"你带着白狐的谢礼，御剑返回宗门"）

#### 2.2.2 事件链：选择触发后续事件

引入"事件链"机制：某些关键选择会在特定回合后触发后续事件。

**示例事件链**：

```
救白狐（q_whiteFox_quest）→ 3回合后触发"白狐谢礼"（q_whiteFox_2）→ 完成支线后种植 whiteFox 种子 
  → 15回合后（化神期）触发"狐影再现"（k_fox_returns）→ 选择后种植 foxGratitude 种子
    → 12回合后触发"白狐报恩·终章"（k_fox_gratitude）
```

#### 2.2.3 选择回响：扩大记录范围

将 `choiceEchoEngine.plantEcho` 的触发范围从5种特殊卡牌类型扩展到**所有含 `karmaSeed` 的选择**：

```javascript
// 扩展选择回响的触发条件
const shouldPlantEcho = 
  echoTypes.includes(card.type) ||           // 原有：弧线/道侣/师尊/盟友/先知卡
  choice.karmaSeed ||                        // 新增：种下了因果种子的选择
  (choice.effects && (
    (choice.effects.karmaGood >= 10) ||     // 新增：大善因选择
    (choice.effects.karmaBad >= 10) ||      // 新增：大恶因选择
    (choice.effects.daoHeart >= 15) ||      // 新增：道心重大突破
    (choice.effects.daoHeart <= -15)        // 新增：道心重大崩溃
  )) ||
  card.tags && card.tags.includes('story'); // 新增：故事标签卡
```

### 2.3 具体实现

#### 2.3.1 修改 NarrativeCoherenceLayer.js：增强过渡文字

```javascript
// src/systems/NarrativeCoherenceLayer.js — 修改 buildTransition

buildTransition(nextCard, gameState, threadEngine, questSystem, npcSystem) {
  // 冷却检查（保留，但降低冷却时间）
  if (gameState.turn - this._lastTransitionTurn < this._transitionCooldown) {
    return null;
  }
  
  const candidates = [];
  let isStrongTrigger = false;
  
  // 1. 位置切换过渡 — 最高优先级，强制触发
  if (nextCard.location && nextCard.location !== gameState.currentLocation) {
    const locTransition = this._buildLocationTransition(
      gameState.currentLocation, 
      nextCard.location,
      gameState
    );
    if (locTransition) {
      candidates.push({ text: locTransition, weight: 10 });
      isStrongTrigger = true;
    }
  }
  
  // 2. 线程续接
  if (threadEngine && nextCard._threadId) {
    const threadInfo = this._getThreadInfo(threadEngine, nextCard._threadId);
    if (threadInfo && threadInfo.currentNodeIndex > 0) {
      candidates.push({
        text: this._pickTemplate('thread_continuation', { threadTitle: threadInfo.title }),
        weight: 4,
      });
      isStrongTrigger = true;
    }
  }
  
  // 3. 因果种子提醒（增强：显示具体种子名称）
  const activeSeeds = gameState.karmaSeeds ? gameState.karmaSeeds.filter(s => s.delay <= 3) : [];
  if (activeSeeds.length > 0) {
    const seedNames = activeSeeds.map(s => this._getSeedDisplayName(s.id)).filter(Boolean);
    if (seedNames.length > 0) {
      candidates.push({
        text: `你感觉到某种因果正在暗中编织——${seedNames.join('、')}的宿命，似乎快要到了了结的时刻。`,
        weight: activeSeeds.some(s => s.delay <= 0) ? 5 : 3,
      });
    } else {
      candidates.push({
        text: this._pickTemplate('karma_reminder'),
        weight: activeSeeds.some(s => s.delay <= 0) ? 5 : 3,
      });
    }
  }
  
  // 4. 活跃支线提醒
  // ...（原有逻辑）...
  
  // 5. 最近选择回响（新增）
  if (gameState.choiceHistory && gameState.choiceHistory.length > 0) {
    const recentChoice = gameState.choiceHistory[gameState.choiceHistory.length - 1];
    if (recentChoice && recentChoice.cardId) {
      const echoText = this._buildRecentChoiceEcho(recentChoice);
      if (echoText) {
        candidates.push({ text: echoText, weight: 2 });
      }
    }
  }
  
  // 6. 位置氛围（新增）
  if (gameState.currentLocation) {
    const locationMood = this._buildLocationMood(gameState.currentLocation, gameState);
    if (locationMood) {
      candidates.push({ text: locationMood, weight: 1 });
    }
  }
  
  // ... 后续原有逻辑 ...
  
  // 过渡概率：位置切换时100%触发，其他情况70%触发
  if (!isStrongTrigger && Math.random() > 0.70) {  // ← 从 0.50 提升到 0.70
    return null;
  }
  
  // ... 后续原有逻辑 ...
}

// 新增：位置切换过渡文字
_buildLocationTransition(from, to, gameState) {
  const templates = {
    '宗门→坊市': [
      '你御剑离开宗门，坊市的喧嚣在前方等你。山门在身后越来越远，而红尘越来越近。',
      '青云宗的石狮子目送你远去。你知道，回来时你可能是另一个人。'
    ],
    '坊市→宗门': [
      '带着坊市买来的丹药和消息，你返回宗门。喧嚣散尽，山门依旧沉默。',
      '你踏过宗门门槛时，守门弟子多看了你一眼——坊市的气息还沾在你的衣角。'
    ],
    '宗门→秘境': [
      '你向长老报备后，独自前往秘境。越靠近，灵气越狂暴——这是机缘的味道，也是死亡的味道。',
      '秘境入口的雾气像一张嘴。你走进去时，身后的世界安静得不像真的。'
    ],
    '秘境→宗门': [
      '你活着从秘境出来了。这一点本身，就足够让同门多看一眼。',
      '身上的伤还在，但储物袋里的东西让一切值得。你御剑返回宗门，准备消化这次冒险。'
    ],
    'default': [
      '你从${from}前往${to}，路途中的风景和心事一样多。',
      '离开${from}时，你没有回头。前往${to}的路上，你想起很多事。'
    ]
  };
  
  const key = `${from}→${to}`;
  const pool = templates[key] || templates['default'];
  let text = pool[Math.floor(Math.random() * pool.length)];
  text = text.replace('${from}', from).replace('${to}', to);
  
  // 如果最近有重要选择，嵌入到过渡文字中
  if (gameState.choiceHistory && gameState.choiceHistory.length > 0) {
    const recent = gameState.choiceHistory[gameState.choiceHistory.length - 1];
    if (recent.cardId === 'q_whiteFox_quest' && recent.direction === 'right') {
      text = '白狐在林中最后看了你一眼。你转身离开，踏上前往' + to + '的路。' + text;
    }
  }
  
  return text;
}

// 新增：最近选择回响
_buildRecentChoiceEcho(recentChoice) {
  // 根据最近的选择卡ID和方向，生成回响文字
  const echoes = {
    'q_whiteFox_quest': {
      right: '那只白狐的影子还在你心里——你选择了救它，这个决定在日后会以某种方式回响。',
      left: '你选择了取丹。现在回想起来，那双眼睛里的温度让你有些不安。'
    },
    'dp_demon_offer': {
      right: '你拒绝了那枚令牌。但你知道，声音的主人不会就此罢休。',
      left: '那枚黑色令牌还在你的储物袋里。每次修炼时，它似乎都在微微发热。'
    }
  };
  
  const cardEchoes = echoes[recentChoice.cardId];
  if (cardEchoes && cardEchoes[recentChoice.direction]) {
    return cardEchoes[recentChoice.direction];
  }
  return null;
}
```

#### 2.3.2 修改 game.js：扩大选择回响范围

```javascript
// src/game.js:855-856 — 修改 _plantChoiceEcho 的触发条件

_plantChoiceEcho(card, direction, choice) {
  if (!card || !choice) return;
  if (typeof choiceEchoEngine === 'undefined' || !choiceEchoEngine) return;
  
  // 原有：特定卡牌类型
  const echoTypes = ['COMPANION_ARC', 'COMPANION_EVENT', 'MENTOR_ARC', 'ALLY_ARC', 'SEER_ARC'];
  
  // ✅ 新增：扩展触发条件
  const shouldPlantEcho = 
    echoTypes.includes(card.type) ||
    choice.karmaSeed ||
    (choice.effects && (
      (choice.effects.karmaGood >= 10) ||
      (choice.effects.karmaBad >= 10) ||
      (choice.effects.daoHeart >= 15) ||
      (choice.effects.daoHeart <= -15)
    )) ||
    (card.tags && card.tags.includes('story')) ||
    (card.tags && card.tags.includes('karma')) ||
    (card.type === 'QUEST');  // 支线选择也记录
  
  if (shouldPlantEcho) {
    choiceEchoEngine.plantEcho({
      turn: gameState.turn,
      realm: gameState.realm,
      cardId: card.id,
      choice: direction,
      choiceLabel: choice.text || '',
      npcId: card.npcId || null,
      affection: card.npcId && typeof npcSystem !== 'undefined'
        ? (npcSystem.affections[card.npcId] || 0)
        : 0,
      location: gameState.currentLocation || '未知',
      cardType: card.type
    });
  }
}
```

#### 2.3.3 实例化 StoryThreadEngine（修复 P1-19）

```javascript
// src/game.js:181-200 — 在 init() 中实例化 threadEngine

init() {
  // ... 原有初始化代码 ...
  
  // ✅ 修复 P1-19：实例化 StoryThreadEngine
  if (typeof StoryThreadEngine !== 'undefined') {
    window.threadEngine = new StoryThreadEngine();
    const threadData = dataLoader.loadSync('threads:qi');
    if (threadData) {
      threadEngine.init(threadData);
      console.log('[GameLogic] StoryThreadEngine initialized with qi_threads');
    }
  }
  
  // ... 后续原有代码 ...
}
```

#### 2.3.4 修改位置切换：增加强制过渡叙事

```javascript
// src/game.js:462-469 — 位置切换时增加过渡叙事

// FIX-1: 卡牌驱动位置切换
if (this.currentCard && this.currentCard.location &&
    typeof sceneLayerSystem !== 'undefined' && sceneLayerSystem) {
  const currentLoc = gameState.currentLocation;
  if (currentLoc !== this.currentCard.location) {
    // ✅ 新增：位置切换前生成过渡叙事
    if (typeof coherenceLayer !== 'undefined' && coherenceLayer) {
      const locTransition = coherenceLayer._buildLocationTransition(
        currentLoc, 
        this.currentCard.location, 
        gameState
      );
      if (locTransition) {
        this._log(`【${currentLoc} → ${this.currentCard.location}】${locTransition}`);
      }
    }
    sceneLayerSystem.transition(this.currentCard.location, 'card_driven');
  }
}
```

### 2.4 预期效果

1. **卡牌间连贯性**：每次位置切换都有过渡叙事，玩家感知到"我在移动"
2. **选择有回响**：关键选择（种因果、大善恶、支线）会在后续卡牌中通过过渡文字被提及
3. **P1-19修复**：StoryThreadEngine 被实例化，5条故事线程（灵脉探索、妖兽异动、散修秘闻、古修洞府、宗门暗流）恢复正常可达
4. **P2-9修复**：`threadEngine` 被实例化后，`_narrativeQueue` 不再成为死队列

### 2.5 验收标准

- [ ] 位置切换时，日志中显示专属过渡叙事（非通用模板）
- [ ] 救白狐后3回合内，至少有一次过渡文字提及白狐
- [ ] 选择回响覆盖范围包括：支线卡、因果种子卡、善恶因≥10的选择、道心变化≥15的选择
- [ ] `threadEngine` 实例化后，`qi_threads.json` 中的线程可被正常推进

---

## 3. 因果系统可视化

### 3.1 问题诊断

**当前问题**：种了因果种子但玩家完全不知道，发芽时也没有感觉。玩家反馈"善恶因是什么？完全没感觉到它的存在"。

**代码证据**：

1. **种因果时无UI反馈**：`KarmaSystem.js:48-86` 的 `plantSeed` 中，虽然发射了 `karma:seedPlanted` 事件，但 `game.js:1482-1484` 的监听器仅将种子信息写入日志（一行文字），没有视觉提示：

```javascript
// src/game.js:1482-1484
_onKarmaSeedPlanted(data) {
  this._log(`因果种下：${data.seed.id}（${data.seed.delay}轮后发芽）`);
  // ← 仅一行日志，没有卡牌动画、没有UI面板、没有持续提醒
}
```

2. **因果发芽无特殊提示**：`CardSystem.js:690-715` 的 `_drawKarmaCard` 在种子发芽时仅发射 `karma:seedGerminated` 事件，UI层没有针对因果卡的特殊渲染：

```javascript
// src/systems/CardSystem.js:690-715
_drawKarmaCard() {
  const ready = seeds.filter(s => s.delay <= 0 && (!s.realm || s.realm === gameState.realm));
  if (ready.length === 0) return null;
  ready.sort((a, b) => b.priority - a.priority);
  const seed = ready[0];
  gameState.karmaSeeds = seeds.filter(s => s !== seed);
  const cardId = this.karmaCardMap.get(seed.id);
  if (cardId) {
    eventBus.emit('karma:seedGerminated', { seedId: seed.id, cardId });
    return this.getCard(cardId);  // ← 返回的卡牌与普通卡无异
  }
  return null;
}
```

3. **无因果种子列表UI**：整个UI系统中没有任何面板显示当前已种下的种子和预计发芽时间。玩家无法知道"我种了什么因果""它们什么时候发芽"。

4. **P0-6：白狐因果回响断裂**：`karma.json` 中 `k_fox_returns` 对应的 `whiteFox` 种子没有任何种植来源。`white_fox.json` 的 `rewardOnComplete` 中种植的是 `foxGratitude`（对应 `k_fox_gratitude`），而不是 `whiteFox`：

```json
// data/quests/white_fox.json:25-31
"rewardOnComplete": {
  "karmaSeeds": [
    { "id": "foxGratitude", "delay": 10, "realm": "foundation", "priority": 2 }
  ]
}

// data/cards/karma.json:5-7
"karmaCards": {
  "whiteFox": "k_fox_returns",     // ← 这个种子 ID 是 whiteFox
  "foxGratitude": "k_fox_gratitude" // ← 支线种的是 foxGratitude
}
```

这意味着 `whiteFox → k_fox_returns` 的映射**永远无法触发**。

5. **P1-7：无 delay 的因果种子永不发芽**：`CardSystem.js:694` 中 `s.delay <= 0` 对 `undefined` 为 `false`，无 delay 的 karmaSeed 将永远卡在数组中：

```javascript
// src/systems/CardSystem.js:694
const ready = seeds.filter(s =>
  s.delay <= 0 && (!s.realm || s.realm === gameState.realm)
);
// 如果 s.delay === undefined，undefined <= 0 为 false，种子永不发芽
```

### 3.2 优化方案

#### 3.2.1 种因果时的视觉反馈

当玩家做出一个选择并种下因果种子时：
1. 在卡牌上叠加一个"因果种子"动画（如一颗种子落入土壤的图标）
2. 在选项按钮下方显示文字提示："种下因果种子：白狐报恩（预计8回合后发芽）"
3. 在日志中以特殊样式（带 🌱 图标）记录

#### 3.2.2 因果簿面板

在UI中新增一个"因果簿"按钮和面板：
- **按钮位置**：属性面板下方或顶部栏右侧
- **面板内容**：
  - 已种下的种子列表：种子名称、类型（善因/恶因/血脉/命运）、预计发芽回合、限定境界
  - 已发芽的种子列表：历史记录，可点击回顾
  - 因果影响说明：当前善恶因值 → 对福缘/魔道事件的影响

#### 3.2.3 因果发芽时的特殊入场

当因果种子发芽时：
1. 卡牌入场前播放"因果绽放"动画（金色/暗红色光芒，取决于种子类型）
2. 卡牌顶部显示特殊标识："🌱 因果绽放 · 白狐报恩"
3. 文字描述前增加引言："多年前你救下的白狐，今日化作人形前来报恩。因果循环，报应不爽。"

### 3.3 具体实现

#### 3.3.1 修改 KarmaSystem.js：种植时发射增强事件

```javascript
// src/systems/KarmaSystem.js:48-86 — 增加种植时的详细事件信息

plantSeed(seed) {
  if (!seed || !seed.id) return;
  
  const existing = gameState.karmaSeeds.find(s => s.id === seed.id);
  if (existing) {
    if (seed.delay < existing.delay) {
      existing.delay = seed.delay;
      existing.priority = Math.max(existing.priority, seed.priority || 0);
    }
    return;
  }
  
  let adjustedDelay = seed.delay != null ? seed.delay : 5;
  adjustedDelay = this._adjustDelayByRealm(adjustedDelay);
  
  const karmaSeed = {
    id: seed.id,
    seedType: seed.seedType || 'karma',
    delay: adjustedDelay,
    realm: seed.realm || null,
    priority: seed.priority || 0,
    originTurn: gameState.turn,
    originCard: seed.originCard || null,
    originChoice: seed.originChoice || null,
    mergeGroup: seed.mergeGroup || null,
    cancelGroup: seed.cancelGroup || null,
    // ✅ 新增：人类可读的种子名称和描述
    displayName: this._getSeedDisplayName(seed.id) || seed.id,
    description: this._getSeedDescription(seed.id) || ''
  };
  
  this._checkCancel(karmaSeed);
  gameState.karmaSeeds.push(karmaSeed);
  
  // ✅ 增强事件：包含更多UI可用的信息
  eventBus.emit('karma:seedPlanted', { 
    seed: karmaSeed,
    displayName: karmaSeed.displayName,
    delay: karmaSeed.delay,
    seedType: karmaSeed.seedType,
    realm: karmaSeed.realm
  });
  
  this._checkMerge(karmaSeed.seedType, karmaSeed.mergeGroup);
}

// 新增：种子名称映射
_getSeedDisplayName(seedId) {
  const names = {
    'whiteFox': '白狐报恩',
    'foxGratitude': '白狐感恩',
    'demonInternalConflict': '魔道内乱',
    'orthodoxInternalConflict': '正道裂痕',
    'demonAccepted': '魔道之因',
    'demonRefused': '拒绝魔道',
    'swordBetrayed': '剑道背叛',
    'swordHonor': '剑的誓言',
    'companionSacrifice': '道侣牺牲',
    'companionTrust': '信任考验',
    'factionUprising': '势力反目',
    'factionPeace': '势力和解',
    'fortuneWheel': '命运轮盘',
    'betrayedNpc': '破碎的信任',
    'lifespanWaste': '寿元危机',
    'combatScar': '战斗伤疤',
    'combatGlory': '战斗威名'
  };
  return names[seedId] || seedId;
}

_getSeedDescription(seedId) {
  const descriptions = {
    'whiteFox': '多年前救下的白狐，将在未来某日回报你的恩情',
    'demonInternalConflict': '你种下的魔道之因，将在血煞宗内部引发一场风暴',
    'swordBetrayed': '剑道上的背叛，终将回到你自己身上'
  };
  return descriptions[seedId] || '';
}
```

#### 3.3.2 修改 game.js：增强种因果的日志反馈

```javascript
// src/game.js:1482-1484 — 增强种因果的UI反馈

_onKarmaSeedPlanted(data) {
  const seed = data.seed;
  const typeIcons = { karma: '🌱', grudge: '💀', bloodline: '🩸', fate: '🌀' };
  const icon = typeIcons[seed.seedType] || '🌱';
  const realmText = seed.realm ? `（${gameState.getRealmName(seed.realm)}期）` : '';
  
  this._log(`${icon} 因果种下：【${seed.displayName || seed.id}】${realmText} — 预计 ${seed.delay} 回合后发芽`);
  
  // ✅ 新增：触发UI提示（toast 样式）
  if (typeof ui !== 'undefined' && ui && ui.showToast) {
    ui.showToast({
      icon: icon,
      title: `因果种下：${seed.displayName || seed.id}`,
      text: `预计 ${seed.delay} 回合后发芽${realmText}`,
      type: seed.seedType === 'grudge' ? 'warning' : 'info',
      duration: 3000
    });
  }
}
```

#### 3.3.3 修改 ui.js：增加因果簿面板

```javascript
// src/ui.js — 在 cacheElements 中增加因果簿元素

cacheElements() {
  // ... 原有代码 ...
  
  // ✅ 新增：因果簿面板
  this.karmaBookBtn = document.getElementById('karma-book-btn');
  this.karmaBookPanel = document.getElementById('karma-book-panel');
  this.karmaBookClose = document.getElementById('karma-book-close');
  this.karmaActiveList = document.getElementById('karma-active-list');
  this.karmaHistoryList = document.getElementById('karma-history-list');
  this.karmaInfluence = document.getElementById('karma-influence');
  
  // ... 后续原有代码 ...
}

// 新增：渲染因果簿
renderKarmaBook() {
  if (!this.karmaActiveList) return;
  
  const seeds = gameState.karmaSeeds || [];
  const typeIcons = { karma: '🌱', grudge: '💀', bloodline: '🩸', fate: '🌀' };
  const typeNames = { karma: '善因', grudge: '恶因', bloodline: '血脉', fate: '命运' };
  
  // 活跃种子列表
  let activeHtml = '';
  const activeSeeds = seeds.filter(s => s.delay > 0).sort((a, b) => a.delay - b.delay);
  
  if (activeSeeds.length === 0) {
    activeHtml = '<div class="karma-empty">暂无种下的因果种子</div>';
  } else {
    for (const seed of activeSeeds) {
      const icon = typeIcons[seed.seedType] || '🌱';
      const typeName = typeNames[seed.seedType] || seed.seedType;
      const realmText = seed.realm ? ` · ${gameState.getRealmName(seed.realm)}` : '';
      const progress = Math.max(0, 100 - (seed.delay / (seed.originTurn + seed.delay || 1)) * 100);
      
      activeHtml += `
        <div class="karma-seed-item ${seed.seedType}">
          <div class="karma-seed-icon">${icon}</div>
          <div class="karma-seed-info">
            <div class="karma-seed-name">${seed.displayName || seed.id}</div>
            <div class="karma-seed-meta">${typeName}${realmText} · 预计 ${seed.delay} 回合后发芽</div>
            <div class="karma-seed-bar"><div class="karma-seed-fill" style="width:${progress}%"></div></div>
          </div>
        </div>
      `;
    }
  }
  
  this.karmaActiveList.innerHTML = activeHtml;
  
  // 因果影响说明
  if (this.karmaInfluence) {
    const karmaGood = gameState.attributes.karmaGood || 0;
    const karmaBad = gameState.attributes.karmaBad || 0;
    let influenceText = '';
    
    if (karmaGood > 30 && karmaGood > karmaBad) {
      influenceText = `善因高（${karmaGood}）→ 福缘增加，善缘事件概率提升`;
    } else if (karmaBad > 30 && karmaBad > karmaGood) {
      influenceText = `恶因高（${karmaBad}）→ 魔道事件概率增加，正道声望下降`;
    } else if (karmaGood > 20 && karmaBad > 20) {
      influenceText = `善恶交织 → 因果冲突事件概率增加，选择代价变大`;
    } else {
      influenceText = `因果平衡 → 事件按正常概率触发`;
    }
    
    this.karmaInfluence.textContent = influenceText;
  }
}

// 在 renderGame 中调用
renderGame() {
  this.renderTopBar();
  this.renderAttributes();
  this.renderPassives();
  this.renderCard();
  this.renderLog();
  this.renderKarmaBook();  // ← 新增
  
  if (gameState.dead) {
    this.renderDeathScreen();
    this.showScreen('death');
  }
}
```

#### 3.3.4 修改 ui.js：因果发芽时的特殊渲染

```javascript
// src/ui.js — 在 renderCard 中增加因果卡的特殊标识

renderCard() {
  const card = this.game.getCurrentCard();
  if (!card) return;
  this.currentCard = card;
  
  // ... 原有代码 ...
  
  // ✅ 新增：因果发芽时的特殊渲染
  if (card.type === 'KARMA' || (card.tags && card.tags.includes('karma'))) {
    this.cardEl.classList.add('card-karma-germinated');
    
    // 查找对应的种子信息
    const seedInfo = this._getGerminatedSeedInfo(card.id);
    if (seedInfo) {
      const typeIcons = { karma: '🌱', grudge: '💀', bloodline: '🩸', fate: '🌀' };
      const icon = typeIcons[seedInfo.seedType] || '🌱';
      
      // 在标题前增加因果标识
      this.cardTitle.innerHTML = `<span class="karma-germinate-badge">${icon} 因果绽放</span> ${card.title}`;
      
      // 在描述前增加引言
      let introText = '';
      if (seedInfo.delayElapsed) {
        introText = `<div class="karma-intro">${seedInfo.delayElapsed} 回合前种下的因，今日结成硕果。</div>`;
      }
      this.cardDesc.innerHTML = introText + (card.description || '');
      
      // 播放因果绽放动画（CSS 动画）
      this.cardEl.style.animation = 'karmaBloom 0.8s ease-out';
      setTimeout(() => { this.cardEl.style.animation = ''; }, 800);
    }
  }
  
  // ... 后续原有代码 ...
}

_getGerminatedSeedInfo(cardId) {
  // 从 karmaCardMap 反向查找种子ID
  if (typeof cardSystem !== 'undefined' && cardSystem.karmaCardMap) {
    for (const [seedId, mappedCardId] of cardSystem.karmaCardMap) {
      if (mappedCardId === cardId) {
        // 查找已发芽的种子记录
        const seed = (gameState.karmaSeeds || []).find(s => s.id === seedId);
        if (seed) {
          return {
            seedId: seed.id,
            seedType: seed.seedType,
            displayName: seed.displayName,
            delayElapsed: gameState.turn - (seed.originTurn || 0)
          };
        }
      }
    }
  }
  return null;
}
```

#### 3.3.5 修复 P0-6：白狐因果回响补种

```json
// data/quests/white_fox.json — 修改 rewardOnComplete

"rewardOnComplete": {
  "attributes": { "karmaGood": 15, "fortune": 10 },
  "resources": { "spiritStone": 20 },
  "flags": ["whiteFoxCompleted"],
  "karmaSeeds": [
    { "id": "foxGratitude", "delay": 10, "realm": "foundation", "priority": 2 },
    // ✅ 新增：种植 whiteFox 种子，使 k_fox_returns 可触发
    { "id": "whiteFox", "delay": 15, "realm": "deity", "priority": 3 }
  ]
}
```

#### 3.3.6 修复 P1-7：无 delay 的种子提供默认值

```javascript
// src/systems/CardSystem.js:690-715 — 修复 delay 未定义问题

_drawKarmaCard() {
  const seeds = gameState.karmaSeeds;
  if (seeds.length === 0) return null;
  
  // ✅ 修复：处理 undefined delay
  const ready = seeds.filter(s => {
    const delay = s.delay !== undefined ? s.delay : 5;  // ← 默认 delay 5
    return delay <= 0 && (!s.realm || s.realm === gameState.realm);
  });
  
  if (ready.length === 0) return null;
  
  ready.sort((a, b) => b.priority - a.priority);
  const seed = ready[0];
  
  gameState.karmaSeeds = seeds.filter(s => s !== seed);
  
  const cardId = this.karmaCardMap.get(seed.id);
  if (cardId) {
    eventBus.emit('karma:seedGerminated', { seedId: seed.id, cardId });
    return this.getCard(cardId);
  }
  
  return null;
}
```

### 3.4 预期效果

1. **种因果可见**：每次种因果都有视觉反馈和日志记录，玩家明确知道"我种下了什么"
2. **因果簿可查**：随时打开因果簿查看已种下的种子和预计发芽时间
3. **发芽有仪式感**：因果卡发芽时有特殊动画和引言，增强叙事重量
4. **P0-6修复**：白狐线因果回响闭环恢复，`k_fox_returns` 可正常触发
5. **P1-7修复**：无 delay 的种子默认5回合后发芽，不再永远卡住

### 3.5 验收标准

- [ ] 种因果时，屏幕显示 toast 提示（含种子名称、类型、预计发芽时间）
- [ ] 因果簿面板显示所有活跃种子，含进度条和预计发芽时间
- [ ] 因果卡发芽时，卡牌有"因果绽放"特殊标识和CSS动画
- [ ] 白狐支线完成后，因果簿中显示 `whiteFox` 种子，预计15回合后、化神期发芽
- [ ] 无 delay 字段的因果种子在5回合后正常发芽

---

## 4. 支线系统优化

### 4.1 问题诊断

**当前问题**：6条支线存在但触发率低，存档重载后锁死，玩家不知道支线何时触发、进度如何。

**代码证据**：

1. **支线触发无提示**：`QuestSystem.js:56-72` 的 `_onCheckTrigger` 仅在条件满足时触发，但没有任何前置提示让玩家知道"某个支线即将触发"或"我已满足触发条件"：

```javascript
// src/systems/QuestSystem.js:56-72
_onCheckTrigger() {
  if (this.activeQuests.length > 0) return;
  if (this._pendingEntryCard) return;
  
  for (const [questId, quest] of this.quests) {
    if (this.completedQuests.has(questId)) continue;
    if (!this._canTrigger(quest)) continue;
    
    this._activateQuest(quest);  // ← 直接触发，没有任何前置提示
    return;
  }
}
```

2. **存档重载锁死支线（P1-21）**：`QuestSystem.js:109-122` 的 `activeQuests` 仅存于内存，`GameStateManager.js:99` 的 `flags` 会持久化到 `localStorage`。刷新页面后，`activeQuests` 为空，但 `forbiddenFlags` 检测到 `quest_whiteFox_line_active = true`，认为支线仍在进行中，从而**永远不再触发**：

```javascript
// src/systems/QuestSystem.js:109-122
_activateQuest(quest) {
  this.activeQuests.push({
    questId: quest.id,
    step: 0,
    startedAt: gameState.turn
  });
  // ...
  gameState.setFlag('quest_' + quest.id + '_active', true);  // ← 持久化到 localStorage
  // 但 activeQuests 不持久化！
}

// 存档重载后：
// activeQuests = []（内存清空）
// flags.quest_white_fox_line_active = true（从 localStorage 恢复）
// _canTrigger 中 forbiddenFlags 检查 → 发现 flag 为 true → 认为支线进行中 → 永不触发
```

3. **支线进度不可见**：`QuestSystem.js` 没有任何方法返回支线的当前进度（如"白狐报恩 1/3"），UI层无法显示。

4. **正魔线第三幕不可达（P0-4）**：`demon_path.json` 中 `dp_demon_second_choice` 和 `dp_orthodox_second_choice` 没有种植 `demonInternalConflict`/`orthodoxInternalConflict` 种子，导致第三幕5张核心卡（`dp_demon_schism`、`dp_orthodox_schism`、`dp_demon_redemption`、`dp_demon_ascend`、`dp_demon_supreme`）永远不可达：

```json
// data/cards/demon_path.json — dp_demon_second_choice 的 choices 中
// 缺少 karmaSeed: { id: "demonInternalConflict" }
```

### 4.2 优化方案

#### 4.2.1 支线触发条件可视化

当玩家满足某条支线的触发条件（但尚未触发）时，在顶部HUD显示提示：
- `[支线触发条件已满足：天枢秘典（法修专属）]`
- `[支线触发条件已满足：白狐报恩（炼气期·5回合后）]`

当支线实际触发时，弹出更明显的提示：
- `📜 支线触发：【白狐报恩】山路旁，一只白狐被猎户的铁夹困住...`

#### 4.2.2 支线进度条

激活支线后，在顶部HUD或支线面板显示进度：
- `白狐报恩 1/3 — 白狐受困`
- `天枢秘典 2/4 — 天道书的真相`

#### 4.2.3 存档修复

持久化 `activeQuests` 状态到 `localStorage`，或在 `_loadUnlocks` 中清理孤立的 `quest_*_active` flag。

### 4.3 具体实现

#### 4.3.1 修改 QuestSystem.js：增加触发条件检查与提示

```javascript
// src/systems/QuestSystem.js — 新增触发条件检查方法

/**
 * 检查哪些支线已满足触发条件但尚未触发（用于UI提示）
 * @returns {Array} 已满足条件的支线列表
 */
getReadyQuests() {
  const ready = [];
  for (const [questId, quest] of this.quests) {
    if (this.completedQuests.has(questId)) continue;
    if (this.activeQuests.some(a => a.questId === questId)) continue;
    if (this._pendingEntryCard && this._pendingEntryCard.questId === questId) continue;
    if (!this._canTrigger(quest)) continue;
    
    ready.push({
      questId: quest.id,
      questName: quest.name,
      startRealm: quest.startRealm || quest.trigger?.startRealm,
      pathRestriction: quest.pathRestriction || quest.trigger?.pathRestriction
    });
  }
  return ready;
}

/**
 * 获取活跃支线的进度信息
 * @returns {Object|null} { questId, questName, step, totalSteps, currentCardTitle }
 */
getActiveQuestProgress() {
  if (this.activeQuests.length === 0) return null;
  
  const active = this.activeQuests[0];
  const quest = this.quests.get(active.questId);
  const cards = this.questCards.get(active.questId);
  const currentCard = cards && cards[active.step] ? cards[active.step] : null;
  
  return {
    questId: active.questId,
    questName: quest ? quest.name : active.questId,
    step: active.step + 1,  // 1-based for display
    totalSteps: cards ? cards.length : 0,
    currentCardTitle: currentCard ? currentCard.title : ''
  };
}

// 修改 _activateQuest：增加触发事件信息
_activateQuest(quest) {
  this.activeQuests.push({
    questId: quest.id,
    step: 0,
    startedAt: gameState.turn
  });
  
  const entryCard = cardSystem.getCard(quest.entryCardId);
  this._pendingEntryCard = entryCard;
  
  gameState.setFlag('quest_' + quest.id + '_active', true);
  gameState.setFlag('quest_' + quest.id + '_step', 0);
  
  // ✅ 增强事件：包含更多信息供UI使用
  eventBus.emit('quest:triggered', {
    questId: quest.id,
    questName: quest.name,
    entryCardId: quest.entryCardId,
    totalSteps: this.questCards.get(quest.id)?.length || 0,
    startRealm: quest.startRealm || quest.trigger?.startRealm
  });
}
```

#### 4.3.2 修改 GameStateManager.js：持久化 activeQuests

```javascript
// src/core/GameStateManager.js — 在 _saveUnlocks 和 _loadUnlocks 中处理 activeQuests

// 由于 QuestSystem 是全局单例，我们需要在 GameStateManager 中保存/恢复 activeQuests
// 方案：在 QuestSystem 中增加 save/restore 方法，由 GameStateManager 调用

// 修改 reset 方法：保留 activeQuests（如果存在）
reset(keepUnlocks = true) {
  // ... 原有代码 ...
  
  // 保存当前 activeQuests 用于恢复
  const savedActiveQuests = (typeof questSystem !== 'undefined' && questSystem) 
    ? questSystem.activeQuests : [];
  
  // ... 原有 reset 代码 ...
  
  // 恢复 activeQuests（如果存在）
  if (savedActiveQuests.length > 0 && typeof questSystem !== 'undefined' && questSystem) {
    questSystem.activeQuests = savedActiveQuests;
  }
}

// 更好的方案：在 _saveUnlocks 中保存 activeQuests
_saveUnlocks() {
  try {
    const dataToSave = {
      ...this.unlocks,
      // ✅ 新增：保存进行中的支线状态
      activeQuests: (typeof questSystem !== 'undefined' && questSystem) 
        ? questSystem.activeQuests : [],
      // 保存当前游戏状态（用于断点续玩）
      savedGameState: {
        realm: this.realm,
        turn: this.turn,
        attributes: this.attributes,
        resources: this.resources,
        flags: this.flags,
        karmaSeeds: this.karmaSeeds
      }
    };
    localStorage.setItem('xiuxian_unlocks', JSON.stringify(dataToSave));
  } catch (e) {
    // localStorage 不可用时静默失败
  }
}

_loadUnlocks() {
  try {
    const saved = localStorage.getItem('xiuxian_unlocks');
    if (saved) {
      const parsed = JSON.parse(saved);
      
      // 确保新字段存在
      if (!parsed.flags) parsed.flags = {};
      // ... 原有兼容逻辑 ...
      
      // ✅ 新增：恢复支线状态
      if (parsed.activeQuests && typeof questSystem !== 'undefined' && questSystem) {
        questSystem.activeQuests = parsed.activeQuests;
      }
      
      // ✅ 新增：清理孤立的 quest_*_active flags（修复 P1-21）
      if (!parsed.activeQuests || parsed.activeQuests.length === 0) {
        for (const key of Object.keys(parsed.flags)) {
          if (key.startsWith('quest_') && key.endsWith('_active')) {
            parsed.flags[key] = false;  // 清理孤立的 active flag
          }
        }
      }
      
      return parsed;
    }
  } catch (e) {
    // 解析失败时使用默认值
  }
  return { /* ... 默认返回值 ... */ };
}
```

#### 4.3.3 修改 ui.js：显示支线状态和进度

```javascript
// src/ui.js — 在 renderTopBar 中增强支线显示

renderTopBar() {
  // ... 原有代码 ...
  
  // ── 支线状态 ──
  const activeQuest = questSystem.getActiveQuest();
  if (activeQuest && this.topQuest) {
    const quest = questSystem.getQuest(activeQuest.questId);
    const progress = questSystem.getActiveQuestProgress();
    if (progress) {
      this.topQuest.textContent = `📜 ${progress.questName} ${progress.step}/${progress.totalSteps}`;
    } else {
      this.topQuest.textContent = quest ? `支线: ${quest.name}` : '';
    }
    this.topQuest.style.display = 'inline-block';
  } else {
    // ✅ 新增：显示已满足条件但未触发的支线
    const readyQuests = questSystem.getReadyQuests ? questSystem.getReadyQuests() : [];
    if (readyQuests.length > 0 && this.topQuest) {
      const ready = readyQuests[0];
      this.topQuest.textContent = `🔔 支线可触发: ${ready.questName}`;
      this.topQuest.style.display = 'inline-block';
      this.topQuest.classList.add('quest-ready');
    } else if (this.topQuest) {
      this.topQuest.style.display = 'none';
      this.topQuest.classList.remove('quest-ready');
    }
  }
  
  // ... 后续原有代码 ...
}
```

#### 4.3.4 修复 P0-4：正魔线补种内战种子

```json
// data/cards/demon_path.json — 在 dp_demon_second_choice 和 dp_orthodox_second_choice 中补种

// 注：需要根据实际数据文件中的 card ID 和 choice 结构添加
// 以下为需要添加/修改的位置示意：

{
  "id": "dp_demon_second_choice",
  "choices": {
    "left": {
      "text": "选择魔道",
      "effects": { ... },
      "karmaSeed": {
        "id": "demonSideChosen",
        "seedType": "bloodline",
        "delay": 6,
        "priority": 5
      }
      // ✅ 新增：种下内战种子
      ,"flags": ["demonSideChosen"]
    },
    "right": {
      "text": "拒绝并逃离",
      "effects": { ... }
    }
  }
}

// 在正魔线第三幕的触发链中，需要确保以下种子被正确种植：
// 1. demonInternalConflict → dp_demon_schism, dp_demon_redemption, dp_demon_ascend
// 2. orthodoxInternalConflict → dp_orthodox_schism
// 3. demonDeepBond → dp_blood_oath
// 4. orthodoxDeepBond → dp_sect_heirloom
// 5. betrayalChoice → dp_final_stand

// 具体修改方案：在 dp_demon_master_visit 的选择中（血煞宗师父出现）
{
  "id": "dp_demon_master_visit",
  "choices": {
    "left": {
      "text": "接过——'教我'",
      "effects": { ... },
      "karmaSeed": {
        "id": "demonDeepBond",
        "seedType": "bloodline",
        "delay": 5,
        "priority": 7
      },
      // ✅ 新增：种下内战种子
      "karmaSeed": [
        { "id": "demonDeepBond", "seedType": "bloodline", "delay": 5, "priority": 7 },
        { "id": "demonInternalConflict", "seedType": "grudge", "delay": 8, "priority": 6 }
      ]
    }
  }
}
```

### 4.4 预期效果

1. **支线触发可预期**：玩家能看到"某支线已满足条件，即将触发"的提示
2. **支线进度可见**：激活支线后，HUD显示"白狐报恩 1/3"，玩家明确知道还剩几步
3. **P1-21修复**：存档重载后支线状态正确恢复，不再锁死
4. **P0-4修复**：正魔线第三幕核心内战卡链恢复可达，5张核心叙事卡可被玩家体验

### 4.5 验收标准

- [ ] 满足支线触发条件时，顶部HUD显示"🔔 支线可触发：XXX"
- [ ] 支线激活后，顶部HUD显示"📜 白狐报恩 1/3"
- [ ] 刷新页面后，进行中的支线状态正确恢复，不会锁死
- [ ] 正魔线第三幕的 `dp_demon_schism`、`dp_orthodox_schism` 等卡牌可被正常触发
- [ ] 存档重载后，已完成的支线不会错误显示为"进行中"

---

## 本章总结

| 优化项 | 关联P级问题 | 核心改动文件 | 预期效果 |
|--------|-----------|------------|---------|
| 章节式三阶段循环 | P1-4, P2-7 | `FlowDirector.js`, `CardSystem.js` | 玩家感知"我现在处于什么阶段" |
| 修复 `for...in` 遍历 Map | P1-4 | `FlowDirector.js:429` | 额外卡池（正魔线/转世等）恢复可达 |
| 叙事连贯性增强 | P1-19, P2-9 | `NarrativeCoherenceLayer.js`, `game.js` | 卡牌间有过渡，选择有回响 |
| 实例化 StoryThreadEngine | P1-19 | `game.js:181` | 5条故事线程恢复正常 |
| 因果系统可视化 | P0-6, P1-7 | `KarmaSystem.js`, `ui.js` | 种因果可见，发芽有仪式感 |
| 修复白狐回响断裂 | P0-6 | `data/quests/white_fox.json` | `k_fox_returns` 可触发 |
| 修复无 delay 种子 | P1-7 | `CardSystem.js:694` | 无 delay 种子默认5回合后发芽 |
| 支线系统优化 | P0-4, P1-21 | `QuestSystem.js`, `GameStateManager.js`, `ui.js` | 支线触发可预期、进度可见、存档不锁死 |
| 修复正魔线第三幕 | P0-4 | `data/cards/demon_path.json` | 5张核心叙事卡恢复可达 |

---

> **下一章关联**：第四章「数值与战斗系统」将基于本章的 cultivation 阶段概念，为不同修为阶段设计差异化的战斗难度和数值曲线。
