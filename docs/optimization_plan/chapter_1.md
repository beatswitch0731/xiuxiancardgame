# 第一章 · 概述与诊断

> **文档版本**: 1.0  
> **撰写日期**: 2026-07-14  
> **项目路径**: `E:\4e\游1\2026-06-27-05-40-58\xiuxian-card-game`  
> **依据报告**: `游戏全面审查报告_v2.md`（2026-07-14）、`游戏审查报告.md`（2026-07-01，基线）

---

## 1. 项目概述

### 1.1 游戏定位

| 维度 | 描述 |
|------|------|
| **游戏类型** | 纯浏览器端 HTML5 修仙卡牌决策游戏（Roguelike-like 卡牌叙事） |
| **目标平台** | 桌面/移动端浏览器（Chrome/Safari/Edge/Firefox） |
| **核心玩法** | 每回合抽取一张事件卡，选择左/右（有时上/下）选项，获得属性变化，最终目标是突破境界（炼气→筑基→金丹→元婴→化神→渡劫→飞升） |
| **技术架构** | 全局单例（`gameState`/`eventBus`） + EventBus 事件驱动，无构建系统 |
| **代码规模** | 35 个 JS 文件，38 个 JSON 数据文件，约 16,000+ 行 JS 代码 |

**核心玩法一句话描述**：玩家扮演一名修仙者，在有限的寿元内通过不断做出抉择来积累修为、突破境界，最终追求飞升成仙——但每个选择都会种下因果，在未知的未来发芽。

### 1.2 当前完成度评估

#### 内容覆盖率

| 系统 | 设计文档覆盖 | 数据层实现 | 实际可到达 | 覆盖率 |
|------|-----------|-----------|----------|--------|
| 主线境界循环 | 7 个境界（炼气→飞升） | 7 个境界配置 + 6 张突破卡 | 炼气/筑基/金丹部分可达，元婴+ 内容空洞 | ~45% |
| 因果叙事系统 | 36 张因果卡 | 36 张因果卡定义 | 仅约 20 张有种植来源，~25% 不可达 | ~55% |
| 支线系统 | 6 条完整支线（剑/法/体/丹/天枢/白狐） | 6 套 quest JSON + 15+ 张专属卡 | 触发率低，存档重载后锁死 | ~40% |
| 正魔抉择线 | 三幕 35 张剧情卡 | 35 张卡定义 | 第三幕核心 5 张卡完全不可达 | ~60% |
| 世界事件 | 22 条跨境界叙事 | 22 条事件定义 | 因崩溃 bug 几乎无法触发 | ~5% |
| 道侣系统 | 3 名可结交 NPC + 情感弧线 | 弧线数据 + 事件数据 | 双轨并行，冲突风险 | ~70% |
| 战斗系统 | 2 套（旧回合制 + 新 Deck 制） | 2 套系统并存 | 并存导致冲突，Deck 系统奖励缺失 | ~50% |
| 新手引导 | 前 5 回合引导 + 功法选择说明 | 无引导系统 | 0% |

#### 系统完成度

| 系统 | 状态 | 说明 |
|------|------|------|
| 抽卡引擎（CardSystem） | ⚠️ 部分完成 | 20 级优先级抽卡逻辑存在，但 `for...in` 遍历 Map 导致额外卡池失效 |
| 状态管理（GameStateManager） | ⚠️ 部分完成 | 基础属性读写可用，但 cultivation 硬上限、hasFlag 语义错误 |
| 流程导演（FlowDirector） | ⚠️ 部分完成 | 阶段情绪系统存在，但阶段切换过快、`_currentPhase` 为闭包私有变量 |
| 因果系统（KarmaSystem） | ⚠️ 部分完成 | 种子种植/计时/发芽逻辑存在，但 UI 无显示、9 个孤儿种子 |
| 突破系统 | ✅ 基础可用 | 突破判定、成功/失败逻辑存在，但缺乏正反馈 |
| 商店系统（ShopSystem） | ⚠️ 部分完成 | 商品生成可用，但触发硬编码错误、选择后跳过回合结算 |
| 战斗系统（CombatSystem） | ❌ 严重问题 | 新旧系统并存，事件格式不兼容，奖励发放不一致 |
| 存档系统 | ⚠️ 部分完成 | `localStorage` 持久化可用，但 `activeQuests` 未持久化、转世标志残留 |
| 音效/动画 | ⚠️ 部分完成 | 基础 CSS 动画存在，但无境界突破特效、无音效 |
| 新手引导 | ❌ 缺失 | 完全没有引导系统 |

#### Bug 密度

| 等级 | 数量 | 定义 | 占比 |
|------|------|------|------|
| 🔴 P0（阻断性） | 6 | 导致崩溃或核心机制完全失效 | 9% |
| 🟠 P1（严重） | 26 | 功能严重异常、数值崩坏、流程断链 | 38% |
| 🟡 P2（中等） | 18 | 体验下降、数据不一致 | 26% |
| 🔵 P3（轻微） | 12 | 设计债务、代码异味 | 17% |
| **合计** | **62** | — | — |

> **关键结论**：本项目存在 **6 个 P0 级崩溃/核心机制失效**、**26 个 P1 级严重缺陷**，总计 62 个分级问题。大量精心设计的叙事内容（约 15-20 张卡牌）因数据层 bug 或代码层拦截而**"存在但不可达"**。

---

## 2. 核心问题诊断：为什么玩家觉得"莫名其妙"

玩家核心反馈是："玩得莫名其妙，不知道在玩什么"。这句话背后不是一个问题，而是**7 个相互交织的系统性缺陷**共同导致的结果。以下从 7 个维度逐一诊断，每个维度均引用具体的代码/数据证据。

---

### 2.1 目标感缺失：没有明确的"当前该做什么"

#### 问题诊断

玩家开局后，屏幕上显示的是：

> 叶凌云 · 炼气期 | 剑修 | 灵石: 10 | 寿元: 80 | 回合: 1

以及一个进度条显示 "🔥 突破进度 0%"。但没有告诉玩家：
- 当前修为 0 / 目标 100（需要多少？）
- 寿元 80 意味着什么（每年消耗 1 点？）
- 应该选择什么策略来最大化生存概率

顶部 HUD 中，`renderTopBar()` 的代码如下：

```javascript
// src/ui.js:326-375
renderTopBar() {
  const playerName = gameState.playerName || '叶凌云';
  this.topRealm.textContent = `${playerName} · ${gameState.getRealmName()}`;
  // ... 省略章节/阶段/位置/时辰等显示 ...
  this.topPath.textContent = gameState.getPathName(gameState.path);
  this.topSpiritStone.textContent = gameState.resources.spiritStone;
  this.topLifespan.textContent = gameState.resources.lifespan;
  this.topTurn.textContent = gameState.turn;
  // ... 突破进度条 ...
  this._renderBreakthroughBar();
  // ... 支线状态 ...
}
```

`_renderBreakthroughBar()` 只渲染了一个进度百分比，没有任何"目标"文字：

```javascript
// src/ui.js:421-463
_renderBreakthroughBar() {
  if (!this.btBar) return;
  const realmConfig = gameState.config.realms
    ? (gameState.config.realms.realms || {})[gameState.realm]
    : null;
  if (!realmConfig || !realmConfig.cultivationThreshold) {
    this.btBar.style.display = 'none';
    return;
  }
  const threshold = realmConfig.cultivationThreshold;
  const current = gameState.attributes.cultivation;
  const pct = Math.min(100, Math.floor((current / threshold) * 100));
  // ... 只显示百分比和颜色变化 ...
  this.btLabel.textContent = `🔥 ${nextRealm || '突破'}进度`;
  this.btFill.style.width = `${pct}%`;
  this.btPct.textContent = `${pct}%`;
}
```

更深层的问题：`realms.json` 中所有境界的 `cultivationThreshold` 都是 **100**。这意味着炼气期到渡劫期，每次突破都需要积累 100 点修为。玩家感受不到"越往后越难"的 progression 曲线。

```json
// data/config/realms.json
{
  "order": ["qi", "foundation", "golden", "nascent", "deity", "tribulation"],
  "realms": {
    "qi": { "cultivationThreshold": 100, ... },
    "foundation": { "cultivationThreshold": 100, ... },
    "golden": { "cultivationThreshold": 100, ... },
    "nascent": { "cultivationThreshold": 100, ... },
    "deity": { "cultivationThreshold": 100, ... },
    "tribulation": { "cultivationThreshold": 100, ... }
  }
}
```

#### 影响范围

- **新手玩家**：开局不知道要做什么，随机点选项，寿元耗尽后死亡，没有学到任何游戏机制
- **进阶玩家**：感受不到 progress 的成就感，每次突破的"仪式感"完全相同

#### 代码证据

| 位置 | 问题 |
|------|------|
| `src/ui.js:326-375` | `renderTopBar()` 无目标提示 |
| `src/ui.js:421-463` | `_renderBreakthroughBar()` 只显示百分比，无目标文字 |
| `data/config/realms.json` | 所有境界 `cultivationThreshold` 均为 100，无差异化 |

---

### 2.2 选择无意义感：选左选右只是数字 +5 的区别

#### 问题诊断

玩家选择一个选项后，游戏只显示一行日志：

> 修为 +5，气血 -3

但玩家不知道：
- 这个 +5 对我的总进度意味着什么（100 点中的 5%？）
- 这个 -3 是否危险（当前 10/10 气血？还是 100/100？）
- 选择左边和右边在叙事上有什么不同（除了数字）

选择系统缺乏**后果预览**。在 `renderCard()` 中，选项按钮只渲染了文字：

```javascript
// src/ui.js:renderCard() 中 choice 按钮的渲染逻辑
// 每个选项按钮只显示 text，没有后果提示
btn.textContent = choice.text;
```

没有颜色区分（收益/风险/特殊），没有阈值标注（"气血-15 → 危险"），没有"这个选择会影响未来什么"的提示。

#### 影响范围

- 玩家选择变成纯随机或纯功利计算（哪个数字大点哪个）
- 叙事选择失去意义——玩家不会为了"故事"而选，因为不知道故事会怎么发展

#### 代码证据

| 位置 | 问题 |
|------|------|
| `src/ui.js:renderCard()` | 选项按钮仅渲染 `choice.text`，无后果预览 |
| `src/game.js:_applyEffects()` | 效果应用后立即进入下一回合，无即时反馈动画 |
| 全局 | 缺少 `_choiceMood` 细化规则（只有 left/right/up/down 的方向） |

---

### 2.3 叙事断裂：每张卡是独立事件，无因果联系

#### 问题诊断

当前抽卡系统（`CardSystem.draw()`）的核心逻辑是：从当前境界的卡池中**按权重随机抽取一张**。这意味着：

- 上一张卡是"救了白狐"，下一张可能是"长老讲道"
- 两张卡之间没有任何因果联系
- 玩家感受不到"我的选择创造了未来"

虽然项目设计了 `NarrativeCoherenceLayer`（叙事连贯层）来生成过渡文字，但其实现效果有限：

```javascript
// src/systems/NarrativeCoherenceLayer.js（当前实现）
// 过渡文字示例："你刚刚经历了 [上一张卡标题]，现在 [当前卡标题]"
// 这是一种简单的拼接，不是真正的因果叙事
```

真正应该运作的因果系统（`KarmaSystem`、`ChoiceEchoEngine`）因为以下原因大部分未生效：

1. **因果种子种了但玩家不知道**：`karmaSeeds` 数组存在于 `gameState` 中，但 UI 层没有任何显示
2. **9 个孤儿因果种子**：有精美的因果卡定义，但没有任何卡牌/选择在种植它们
3. **正魔线第三幕断链**：`demonInternalConflict`/`orthodoxInternalConflict` 种子没有任何来源

```json
// data/cards/demon_path.json — 第三幕核心卡牌
// 这些卡牌要求 requiresFlags: { "demonInternalConflict": null }
// 但没有任何 choice 种植了 "demonInternalConflict" 这个 karmaSeed
// 导致以下 5 张核心叙事卡永远不可达：
// - dp_demon_schism（血煞宗内战）
// - dp_orthodox_schism（正道裂痕）
// - dp_demon_redemption（殷血救赎）
// - dp_demon_ascend（魔道飞升之秘）
// - dp_demon_supreme（魔道至尊/正道领袖）
```

#### 影响范围

- 游戏玩起来像"随机事件生成器"，而不是"我在创造自己的修仙故事"
- 大量精心撰写的叙事文本（约 15-20 张卡）永远不会被玩家看到

#### 代码证据

| 位置 | 问题 |
|------|------|
| `src/systems/CardSystem.js:draw()` | 按权重随机抽卡，无叙事链逻辑 |
| `src/systems/NarrativeCoherenceLayer.js` | 过渡文字简单拼接，无真正因果 |
| `data/cards/demon_path.json` | 第三幕 5 张卡无触发来源 |
| `data/cards/karma.json` | 9 个孤儿因果种子无种植来源 |

---

### 2.4 信息过载：6 个属性 + 灵石 + 寿元 + 回合数 + 阶段 + 位置

#### 问题诊断

`renderAttributes()` 一次性渲染了 6 个属性条：

```javascript
// src/ui.js:465-500+
renderAttributes() {
  const attrs = gameState.attributes;
  const labels = {
    cultivation: '修为', daoHeart: '道心',
    karmaGood: '善因', karmaBad: '恶因',
    fortune: '福缘', health: '气血'
  };
  // 为每个属性渲染一个进度条...
}
```

加上 `renderTopBar()` 中的：
- 灵石（`spiritStone`）
- 寿元（`lifespan`）
- 回合数（`turn`）
- 阶段（`phase`）
- 位置（`location`）
- 时辰（`timeOfDay`）
- 支线状态（`quest`）

新手玩家开局看到的是 **10+ 个数字/进度条**，但没有任何说明这些属性是做什么的。例如：
- `daoHeart`（道心）到底有什么作用？代码中它影响突破成功率，但 UI 上没有任何提示
- `karmaGood`/`karmaBad`（善因/恶因）种了种子会发生什么？玩家看不到任何效果
- `fortune`（福缘）影响抽卡权重，但玩家不知道

```javascript
// src/core/GameStateManager.js:111-117
setAttribute(name, value) {
  const oldValue = this.attributes[name] || 0;
  let maxVal = 100;
  if (name === 'health') maxVal = this.maxHealth;
  if (name === 'daoHeart') maxVal = this.maxDaoHeart;
  // cultivation 等属性的上限也是 100！
  this.attributes[name] = Math.max(0, Math.min(maxVal, value));
}
```

#### 影响范围

- 认知负荷过高：玩家需要同时关注 10+ 个指标
- 无法判断优先级：不知道哪个属性当前最危险/最重要

#### 代码证据

| 位置 | 问题 |
|------|------|
| `src/ui.js:465-500+` | `renderAttributes()` 渲染 6 个属性条，无优先级区分 |
| `src/ui.js:326-375` | `renderTopBar()` 同时显示 7+ 个指标 |
| `src/core/GameStateManager.js:111-117` | 所有属性上限 100，无差异化说明 |

---

### 2.5 缺乏爽点/里程碑：突破境界没有正反馈

#### 问题诊断

境界突破在 `_advanceRealm()` 中的实现极为简陋：

```javascript
// src/game.js:1281-1291
_advanceRealm() {
  const realmOrder = gameState.config.realms
    ? gameState.config.realms.order
    : ['qi', 'foundation', 'golden', 'nascent', 'deity', 'tribulation'];
  const idx = realmOrder.indexOf(gameState.realm);
  const oldRealm = gameState.realm;
  if (idx < realmOrder.length - 1) {
    gameState.realm = realmOrder[idx + 1];
    gameState.setAttribute('cultivation', 10);
    eventBus.emit('state:realmChanged', { from: oldRealm, to: gameState.realm });
    // 仅此而已！没有动画、没有音效、没有叙事文字
  }
}
```

突破后只发射了一个 `state:realmChanged` 事件，UI 层只更新了顶部文字。没有：
- 全屏突破动画
- 境界名称大字展示
- 突破叙事情境文字（"炼气圆满，气旋液化，筑基初成！"）
- 属性提升提示（寿元 +50、新卡池解锁）

这导致玩家感受不到"我突破了！我变强了！"的成就感。

#### 影响范围

- 核心游戏循环缺乏"高峰体验"（peak experience），玩家流失率高
- 境界系统沦为"数字从 100 重置为 10"的机械操作

#### 代码证据

| 位置 | 问题 |
|------|------|
| `src/game.js:1281-1291` | `_advanceRealm()` 仅发射事件，无动画/音效/叙事 |
| `src/ui.js:326-375` | 仅更新顶部文字，无突破特效 |
| 全局 | 无 `breakthrough_animation.css` 或音效文件 |

---

### 2.6 善恶因果系统隐形：种了种子但玩家看不到、感觉不到

#### 问题诊断

`KarmaSystem` 的核心机制是：当玩家做出某个选择时，种下 `karmaSeed`（因果种子），经过 `delay` 回合后在特定 `realm` 发芽，触发对应的因果卡。

但玩家体验是：
1. 选择"救白狐" → 没有任何提示说"种下了一颗因果种子"
2. 8 回合后 → 突然抽到一张"白狐报恩"卡，玩家已经忘了自己救过白狐
3. 没有"因果簿"可以查看当前已种下的种子

UI 层完全没有任何因果相关的显示：

```javascript
// src/ui.js — 全局搜索 "karmaSeed" 或 "因果"
// 结果：没有任何相关渲染逻辑
// 没有因果簿按钮、没有种子列表、没有发芽倒计时
```

更深层的问题：`KarmaSystem.plantSeed()` 被调用时，没有发射任何 UI 事件供显示：

```javascript
// src/systems/KarmaSystem.js（推断结构）
// plantSeed 被调用后，种子只存在于 gameState.karmaSeeds 数组中
// 没有事件被发射到 UI 层
```

此外，**9 个孤儿因果种子**使得这个问题雪上加霜——即使玩家看到了某种子，也有 25% 的概率那个种子永远不会发芽。

#### 影响范围

- 游戏核心叙事机制（"因果报应"）对玩家完全隐形
- 玩家无法理解"为什么突然抽到这张卡"，产生随机感

#### 代码证据

| 位置 | 问题 |
|------|------|
| `src/ui.js` | 无因果簿 UI、无种子显示 |
| `src/systems/KarmaSystem.js` | `plantSeed` 无 UI 事件发射 |
| `data/cards/karma.json` | 36 张因果卡中 9 张无种植来源（孤儿种子） |

---

### 2.7 系统存在但不可达：大量内容被 Bug 封印

#### 问题诊断

这是项目最严重的问题类别。大量设计精良、文本精美的内容因为代码/数据 bug 而**永远无法被玩家看到**。

#### 7.1 世界事件系统（22 条事件）

```javascript
// src/game.js:1015-1025
_pickWorldEvent() {
  const realmName = gameState.getRealmName(gameState.realm);
  const realmIndex = GameStateManager.REALM_ORDER.indexOf(gameState.realm);
  // 问题：GameStateManager.REALM_ORDER 从未定义！
  // 结果：undefined.indexOf(...) 抛出 TypeError，游戏直接崩溃
}
```

`GameStateManager` 中**没有任何地方定义 `REALM_ORDER`**：

```javascript
// src/core/GameStateManager.js — 全局搜索 REALM_ORDER
// 结果：无定义。只有局部变量 realmOrder 在多处出现
```

#### 7.2 死亡卡叙事系统（6 张卡）

`CardSystem.draw()` 在死亡时精心构造死亡叙事卡（`death_dao_collapse` 等 6 张），但：

```javascript
// src/game.js:517-518
makeChoice(direction) {
  if (gameState.dead) return false;  // 死亡时直接拦截，不展示死亡卡
  // ...
}

// src/ui.js:313-324
renderGame() {
  this.renderTopBar();
  // ... 如果死亡，直接覆盖为 death-screen
  if (gameState.dead) {
    this.renderDeathScreen();
    this.showScreen('death');
  }
}
```

#### 7.3 额外卡池全部失效

```javascript
// src/systems/FlowDirector.js:429-436
if (cardSystem.cardCache) {
  for (var id in cardSystem.cardCache) {  // ❌ for...in 对 Map 无效！
    var card = cardSystem.cardCache[id];   // 永远遍历不到任何元素
    // ...
  }
}
```

`cardCache` 是 ES6 `Map`，但 `for...in` 只能遍历对象的 enumerable 属性。这导致通过 `_loadExtraModule` 加载的所有卡牌（魔道女修、转世回响、跨线交织、正魔线、飞升后）**永远不会被抽到**。

#### 7.4 被动回血硬编码上限

```javascript
// src/game.js:1060-1064
_applyPassiveRegen() {
  // ... 计算 hpRegen ...
  if (hpRegen > 0 && gameState.attributes.health < 100) {  // ❌ 硬编码 100
    const healAmount = Math.min(hpRegen, 100 - gameState.attributes.health);  // ❌ 硬编码 100
    gameState.addAttribute('health', healAmount);
  }
}
```

如果玩家通过转世遗产获得 `maxHealth > 100`（如体修技能「金刚不坏」+30），被动回血将被错误截断在 100。

#### 7.5 白狐因果回响完全不可达

```json
// data/cards/karma.json
{
  "karmaCards": {
    "whiteFox": "k_fox_returns"  // 狐影再现——需要 whiteFox 种子
  }
}

// data/quests/white_fox.json — rewardOnComplete
"karmaSeeds": [
  { "id": "foxGratitude", "delay": 10, "realm": "foundation", "priority": 2 }
  // ❌ 没有种植 "whiteFox" 种子！只有 foxGratitude
]
```

`whiteFox` 因果种子在 `qi_condensation.json` 的 `q_whiteFox` 卡中有种植，但该卡的 `karmaSeed.delay` 为 8、`realm` 为 `foundation`。然而白狐支线在 7 月 1 日修复后，`q_whiteFox` 的种植可能被移除或转移。无论如何，`whiteFox` 种子的当前种植来源**无法可靠触发**到 `k_fox_returns`（要求 `realm: nascent`）。

#### 7.6 白狐支线存档锁死

```javascript
// src/systems/QuestSystem.js:109-122
// QuestSystem.activeQuests 仅存于内存，不写入 localStorage
// 但 gameState.flags 会持久化（包含 quest_white_fox_line_active = true）
// 刷新页面后：activeQuests 为空，但 forbiddenFlags 认为支线仍在进行中
// 结果：该支线永远不再触发
```

#### 影响范围

- **~25% 的因果卡**（9/36）永远不会触发
- **正魔线第三幕**（5 张核心卡）完全不可达
- **22 条世界事件**几乎无法触发
- **6 张死亡叙事卡**永远不可见
- **所有额外卡池**（魔道女修、转世回响、跨线交织等）全部失效

#### 代码证据汇总

| 系统 | 位置 | 问题 | 影响 |
|------|------|------|------|
| 世界事件 | `src/game.js:1017` | `GameStateManager.REALM_ORDER` 未定义 | 22 条事件触发崩溃 |
| 死亡卡 | `src/game.js:518` + `src/ui.js:321-323` | 死亡拦截 + 覆盖 death-screen | 6 张卡不可见 |
| 额外卡池 | `src/systems/FlowDirector.js:430` | `for...in` 遍历 Map | 所有额外模块卡不可达 |
| 被动回血 | `src/game.js:1061-1062` | 硬编码上限 100 | maxHealth > 100 时失效 |
| 白狐回响 | `data/quests/white_fox.json:29-31` | 未种植 `whiteFox` 种子 | `k_fox_returns` 不可达 |
| 正魔线第三幕 | `data/cards/demon_path.json` | 无 `demonInternalConflict` 种植 | 5 张核心卡不可达 |
| 支线存档 | `src/systems/QuestSystem.js:109-122` | `activeQuests` 未持久化 | 存档重载后支线锁死 |

---

### 2.8 用户体验地图：从开局到第一次死亡/转世的完整流程

```
┌─────────────────────────────────────────────────────────────────────┐
│  回合 0: 开局                                                         │
│  ├─ 问题: 没有新手引导，玩家不知道4个功法有什么区别                    │
│  ├─ 问题: 没有"目标"提示，只有"突破进度 0%"                          │
│  └─ 情绪: 好奇但困惑                                                  │
├─────────────────────────────────────────────────────────────────────┤
│  回合 1-5: 前5张卡                                                    │
│  ├─ 问题: 属性条6个同时闪烁，不知道哪个重要                            │
│  ├─ 问题: 选择后只有数字变化，不知道"为什么选这个"                    │
│  ├─ 问题: 卡片之间没有叙事联系（救了白狐 → 长老讲道）                │
│  └─ 情绪: 逐渐麻木，变成"看数字选大的"                                │
├─────────────────────────────────────────────────────────────────────┤
│  回合 5-10: 可能触发支线                                              │
│  ├─ 问题: 支线出现时没有任何提示（"支线: 白狐报恩" 在顶部一闪而过）   │
│  ├─ 问题: 玩家不知道"支线"是什么，也不知道它有多少步                 │
│  ├─ 问题: 如果刷新页面，支线可能永远锁死（P1-21）                     │
│  └─ 情绪: 如果注意到支线，略感惊喜；如果没注意到，完全错过              │
├─────────────────────────────────────────────────────────────────────┤
│  回合 10-20: 日常修炼                                                 │
│  ├─ 问题: 没有节奏变化，每张卡都是"修为+5/气血-3"                    │
│  ├─ 问题: 突破进度缓慢上升到 30-50%，没有里程碑感                    │
│  ├─ 问题: 商店可能出现（但玩家不知道何时会出现）                      │
│  ├─ 问题: 选择商店后整个回合结算被跳过（P1-3）                        │
│  └─ 情绪: 单调，开始觉得"无聊"                                        │
├─────────────────────────────────────────────────────────────────────┤
│  回合 20+: 接近突破或死亡                                             │
│  ├─ 问题: 如果 cultivation 接近 100，可能触发瓶颈卡                   │
│  ├─ 问题: 突破成功/失败没有明显区别（只是一行日志）                   │
│  ├─ 问题: 如果寿元耗尽，直接跳转到 death-screen，看不到死亡叙事卡    │
│  ├─ 问题: 死亡后"转世"按钮没有说明转世会保留什么                      │
│  └─ 情绪: 挫败——"我死了，但我不知道为什么会死"                        │
├─────────────────────────────────────────────────────────────────────┤
│  转世后: 新的开始                                                     │
│  ├─ 问题: 转世遗产（maxHealth+ 等）没有显示在开局界面                 │
│  ├─ 问题: 但 passive regen 仍硬编码 100，遗产 maxHealth 无效（P0-3）   │
│  └─ 情绪: 困惑——"我转世了，但感觉和第一次没区别"                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 3. 问题优先级矩阵

### 3.1 分级定义

| 等级 | 定义 | 修复时间 | 不修复的后果 |
|------|------|---------|-------------|
| 🔴 **阻断性** | 游戏无法进行、崩溃或核心机制完全失效 | 1-3 天 | 玩家无法完成基础游戏流程 |
| 🟠 **严重** | 核心玩法失效、大量内容不可达、数值系统崩坏 | 1-2 周 | 玩家体验严重受损，大量设计内容浪费 |
| 🟡 **中等** | 体验下降、数据不一致、维护困难 | 2-4 周 | 玩家流失率高，开发维护成本增加 |
| 🔵 **轻微** | 设计债务、代码异味、优化项 | 按需 | 长期技术债务积累 |

### 3.2 阻断性（P0）问题清单

| # | 问题 | 影响范围 | 修复难度 | 修复文件 | 验证方法 |
|---|------|---------|---------|---------|---------|
| P0-1 | `REALM_ORDER` 未定义 → 世界事件崩溃 | 22 条世界事件不可达 | 低 | `src/core/GameStateManager.js` | 触发世界事件不崩溃 |
| P0-2 | 死亡卡被完全绕过 | 6 张死亡叙事卡不可见 | 中 | `src/game.js` + `src/ui.js` | 死亡时展示死亡卡后再进入 death-screen |
| P0-3 | 被动回血硬编码上限 100 | maxHealth 遗产无效 | 低 | `src/game.js:1061-1062` | 体修遗产 +30 后，被动回血可到 130 |
| P0-4 | 正魔线核心内战卡链不可达 | 第三幕 5 张核心卡不可达 | 低 | `data/cards/demon_path.json` | 正魔线完整通关流程可触发第三幕 |
| P0-5 | NPC ID 全局不一致 | 关系网/交叉卡/回响全部失效 | 中 | `data/npcs/` 多个文件 | NPC 匹配系统正常运作 |
| P0-6 | 白狐因果回响完全不可达 | `k_fox_returns` 永不触发 | 低 | `data/quests/white_fox.json` | 完成白狐支线后 15 回合触发 `k_fox_returns` |

### 3.3 严重（P1）问题清单（精选）

| # | 问题 | 影响范围 | 修复难度 | 修复文件 | 验证方法 |
|---|------|---------|---------|---------|---------|
| P1-3 | 商店选择跳过整个回合结算 | 因果/回血/危机检测全部跳过 | 中 | `src/game.js:642-675` | 选择商店后寿元正常消耗、因果推进 |
| P1-4 | `for...in` 遍历 Map 导致额外卡池失效 | 所有 `_loadExtraModule` 卡不可达 | 低 | `src/systems/FlowDirector.js:430` | 魔道女修/转世回响/跨线交织卡可被抽到 |
| P1-6 | `realmOrder` 硬编码含 `formation`/`void` | 化神期商店触发频率错误 | 低 | `src/systems/CardSystem.js:379` | 化神期按正确间隔触发商店 |
| P1-7 | 兜底卡 `exp` 无效 | 兜底卡无效果 | 低 | `src/systems/CardSystem.js:1168` | 兜底卡正确增加 cultivation |
| P1-8 | 死亡卡"拒绝天命"无效 | 死亡后无法转世，陷入死循环 | 低 | `src/services/EffectService.js` | 选择"拒绝天命"后正常重启 |
| P1-9 | cultivation 硬上限 100 | 后续境界阈值 >100 时无法突破 | 低 | `src/core/GameStateManager.js:111-117` | cultivation 使用动态上限 |
| P1-10 | 因果种子无 delay 永不发芽 | 无 delay 的种子卡在数组中 | 低 | `src/systems/CardSystem.js:694` | 无 delay 种子按默认 delay 发芽 |
| P1-11 | DeckCombatSystem maxHealth undefined | 防御动作导致 NaN | 低 | `src/systems/DeckCombatSystem.js:86` | 战斗中防御动作正常计算 |
| P1-12 | DeckCombatSystem 忽略 enemy 数据 | 卡牌设计的敌人 HP/ATK 无效 | 中 | `src/systems/DeckCombatSystem.js:92-122` | 敌人使用 card.enemy 中定义的数据 |
| P1-13 | 新旧 CombatSystem 事件格式不兼容 | 旧系统 defeat 时重复扣血 | 中 | `src/systems/CombatSystem.js` + `CombatCoordinator.js` | 统一 defeat 事件格式 |
| P1-14 | 战斗奖励日志与实物不一致 | 数据显示不符 | 低 | `src/systems/CombatSystem.js:770-780` | 奖励文本与实际发放一致 |
| P1-15 | DeckCombatSystem._victory 不发放奖励 | 战斗后无 cultivation/灵石 | 中 | `src/systems/DeckCombatSystem.js:538-548` | 战斗胜利后发放基础奖励 |
| P1-16 | requiresFlags 引用 karmaSeed ID | 正魔线/跨线交织卡不可达 | 中 | `data/cards/demon_path.json` + `interweave.json` | 正魔线后续卡牌正常触发 |
| P1-17 | 9 个孤儿因果种子 | ~25% 因果卡不可达 | 中 | 多个数据文件 | 所有因果种子有种植来源 |
| P1-18 | 跨线交织天劫不可达 | 2 张巅峰剧情卡不可达 | 低 | `data/cards/interweave.json` | 无情道/有情道天劫可触发 |
| P1-19 | 飞升后叙事顺序崩坏 | 可能先看到结局再看到抉择 | 低 | `data/cards/post_ascension.json` | 叙事顺序正确 |
| P1-20 | 道侣冲突与和解卡顺序颠倒 | 先和解后冲突 | 低 | `data/cards/interweave.json` | 冲突卡必须先于和解卡 |
| P1-21 | 因果种子 realm 不匹配 | 种子在筑基期种，化神期才触发 | 低 | `data/cards/karma.json` + `data/quests/white_fox.json` | 种子 realm 与触发 realm 匹配 |
| P1-22 | 故事线程系统无引擎 | 5 条线程数据存在但不可用 | 中 | `src/game.js` | 线程系统正常运作 |
| P1-23 | 转世宿命卡效果未定义 | deckCard/removeCard 无效 | 中 | `src/services/EffectService.js` + `data/cards/rebirth.json` | 转世奖励正确生效 |
| P1-24 | 存档重载锁死支线 | 刷新页面后支线永远不可触发 | 中 | `src/systems/QuestSystem.js` + `src/core/GameStateManager.js` | 刷新后支线状态正确恢复 |

### 3.4 中等（P2）问题清单（精选）

| # | 问题 | 影响范围 | 修复难度 | 修复文件 |
|---|------|---------|---------|---------|
| P2-1 | 寿元危机种子重复种植 | 每回合重复种植 `lifespanWaste` | 低 | `src/game.js:828-830` |
| P2-2 | `hasFlag` 语义错误 | flag 设为 `false` 时视为不存在 | 低 | `src/core/GameStateManager.js:203-205` |
| P2-3 | 寿命扣除绕过 `addResource` | 直接 `lifespan -= 1`，无边界保护 | 低 | `src/game.js:822` + `src/systems/CombatSystem.js:783,825` |
| P2-4 | 格挡系统状态残留 | `reset()` 未清理 `_pendingBlockDamage` | 低 | `src/systems/CombatSystem.js:52-71` |
| P2-5 | 日志上限过短 | `maxLogMessages = 6`，战斗上下文不可见 | 低 | `src/ui.js:15` |
| P2-6 | 阶段切换过快 | `CALM` 阶段约 13 张卡就进入 `BUILDUP` | 中 | `src/systems/FlowDirector.js:38-79` |
| P2-7 | 支线推进隐式 `step++` 风险 | `questNext` 找不到时回退错位 | 中 | `src/systems/QuestSystem.js:173-199` |
| P2-8 | 数据双重维护 | `index.html` 内联 JSON + `data/` 目录 | 高 | 全局重构 |
| P2-9 | 缺少构建系统 | 无 npm/rollup/vite，全局命名空间污染 | 高 | 项目根目录 |
| P2-10 | 混合编码风格 | `class`/`var` IIFE/`const` 箭头函数并存 | 中 | 所有 JS 文件 |

### 3.5 轻微（P3）问题清单

| # | 问题 | 影响范围 | 修复难度 | 修复文件 |
|---|------|---------|---------|---------|
| P3-1 | 缺失角色概念美术 | 18 张概念图缺失 | 高 | `assets/characters/*.webp` |
| P3-2 | 缺失章节里程碑场景图 | 30 张场景图缺失 | 高 | `data/cards/chapter_milestones.json` |
| P3-3 | 高境界内容空缺 | 元婴/化神/渡劫卡牌池空洞 | 高 | `data/cards/` 多个目录 |
| P3-4 | 没有自动化测试 | 无 `.test.js` 或测试框架 | 中 | 项目根目录 |
| P3-5 | `protagonist.json` 关系键缩写 | 与 `core_npcs.json` 完整 ID 不一致 | 低 | `data/protagonist.json` |
| P3-6 | 配置分散无 Schema | 新增境界时容易遗漏 | 中 | `data/config/` 目录 |

---

## 4. 验收标准

本章作为优化方案的总纲，其验收标准如下：

| 验收项 | 标准 | 验证方法 |
|--------|------|---------|
| 问题诊断准确性 | 所有引用的代码/数据位置可通过文件读取确认 | 逐条核对文件路径和行号 |
| 优先级矩阵完整性 | P0/P1/P2/P3 分级与审查报告一致，无遗漏 | 对照 `游戏全面审查报告_v2.md` |
| 用户体验地图 | 覆盖从开局到转世的完整流程，每个节点有明确问题标注 | 逐回合模拟玩家体验 |
| 证据可追踪性 | 所有代码示例和数据引用可直接在项目中找到 | 使用 `grep` 验证每个引用 |

---

> **下一章预告**：第二章「玩家体验优化」将针对 2.1-2.4 的诊断结论，提出**目标系统重构**、**选择反馈系统**、**属性面板简化**、**新手引导系统**四个可执行的优化方案，并给出具体的代码修改位置和技术实现要点。
