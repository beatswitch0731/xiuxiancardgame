# 第四章 数值与战斗系统优化

> **本章定位**：解决游戏核心数值体验问题——玩家"不知道数值有什么用"、"选左选右没区别"、"战斗莫名其妙"、"商店卡住了"。
>
> **基于代码审查**：`GameStateManager.js`（属性上限）、`CombatSystem.js`/`DeckCombatSystem.js`（双战斗系统并存）、`ShopSystem.js`（商店跳过回合）、`path_skills.json`/`paths.json`（功法差异化不足）、`realms.json`（境界阈值全为100）。

---

## 1. 属性数值系统优化（3页）

### 1.1 问题诊断

#### 1.1.1 cultivation 硬上限 100 — 后续境界无法突破

**代码证据**：`src/core/GameStateManager.js:111-117`

```javascript
setAttribute(name, value) {
  const oldValue = this.attributes[name] || 0;
  let maxVal = 100;
  if (name === 'health') maxVal = this.maxHealth;
  if (name === 'daoHeart') maxVal = this.maxDaoHeart;
  
  this.attributes[name] = Math.max(0, Math.min(maxVal, value));
  // ...
}
```

**问题**：`cultivation` 未单独设置上限，被默认的 `maxVal = 100` 截断。而 `realms.json` 中所有境界的 `cultivationThreshold` 都是 100：

```json
{
  "qi": { "cultivationThreshold": 100 },
  "foundation": { "cultivationThreshold": 100 },
  "golden": { "cultivationThreshold": 100 },
  "nascent": { "cultivationThreshold": 100 },
  "deity": { "cultivationThreshold": 100 },
  "tribulation": { "cultivationThreshold": 100 }
}
```

这导致：
- 玩家进入筑基期后，修为依然只需求 100，与炼气期完全相同
- 突破后 `setAttribute('cultivation', 10)` 仅设置到 10，但后续积累到 100 再次突破，没有"需要更多修为"的成长感
- 若未来修改 `cultivationThreshold` 为 200（如筑基期应有更高门槛），`setAttribute` 会将 cultivation 截断在 100，永远无法突破

#### 1.1.2 被动回血硬编码 100 — maxHealth 遗产无效

**代码证据**：`src/game.js:1061-1064`

```javascript
if (hpRegen > 0 && gameState.attributes.health < 100) {
  const healAmount = Math.min(hpRegen, 100 - gameState.attributes.health);
  gameState.addAttribute('health', healAmount);
}
```

**问题**：P0-3 的审查报告指出此问题。体修技能「金刚不坏」+30 maxHp、转世遗产 `maxHp` 加成，均使 `maxHealth > 100`，但 `_applyPassiveRegen` 中的硬编码 `100` 导致超出部分完全无效。这是 **7月1日已报告、至今未修复** 的问题。

#### 1.1.3 属性作用对玩家完全不可见

**代码证据**：`index.html` 中虽有 `data-tooltip` 属性，但游戏运行中没有任何 tooltip 系统实现。

```html
<div class="attr-item" data-attr="cultivation" data-tooltip="修为：修炼进度核心指标...">
```

**问题**：
- 6 个属性条（修为、道心、善因、恶因、福缘、气血）挤在左侧，新玩家无法区分"该关注哪个"
- 道心的作用仅体现在 `daoResist` 减免和 `gameState.attributes.daoHeart / 20` 的伤害加成，但玩家看不到这些数值
- 福缘仅在 `fortune > 70` 时影响权重，但玩家不知道"70"这个阈值
- 善因/恶因差值 `getKarma()` 从未在 UI 中展示

#### 1.1.4 属性条上限显示失真

**代码证据**：`src/ui.js:474`

```javascript
bar.style.width = `${Math.min(value, 100)}%`;
```

**问题**：当 `maxHealth = 130`（体修+30）、`health = 100` 时，UI 显示 100% 满血，但实际只占总上限的 77%。这会给玩家"我满血了"的错觉，进入战斗后发现敌人一击打掉"超出100的部分"会感到困惑。

---

### 1.2 优化方案

#### 1.2.1 境界数值阶梯化重构

**设计原则**：每个境界的修为需求应该明显高于前一境界，形成"越修越难"的修仙体验。

**调整方案**：

| 境界 | 原 threshold | 新 threshold | 增长倍数 |
|------|------------|-------------|---------|
| 炼气期 | 100 | 100 | 1.0x（基准） |
| 筑基期 | 100 | 200 | 2.0x |
| 金丹期 | 100 | 500 | 5.0x |
| 元婴期 | 100 | 1200 | 12.0x |
| 化神期 | 100 | 3000 | 30.0x |
| 渡劫期 | 100 | 8000 | 80.0x |

**理由**：
- 炼气→筑基是"入门到正式修仙"的门槛，2倍增长合理
- 金丹期是"结丹"质变，需要显著积累（5倍）
- 元婴、化神、渡劫是高层境界，指数级增长符合修仙小说的"越往后越难"设定
- 同时，修为获取速度也应随境界提升（通过战斗奖励、高境界卡牌等），形成"需求增长但供给也增长"的平衡

#### 1.2.2 cultivation 动态上限

**方案**：`cultivation` 的上限使用当前境界的 `cultivationThreshold`（或 `cultivationMax`），而非硬编码 100。

#### 1.2.3 属性 tooltip 系统实装

**方案**：鼠标悬停属性条时，显示半透明 tooltip 面板，解释：
- 该属性的作用
- 当前数值的影响（如"道心 5 → 突破成功率 +5%"）
- 与其他属性的关联

#### 1.2.4 道心作用直接可视化

**方案**：在突破进度条附近增加"突破成功率"显示，将道心直接映射为玩家可理解的百分比。

---

### 1.3 具体实现

#### 1.3.1 修改 `realms.json`：阶梯化阈值

**文件**：`E:\4e\游1\2026-06-27-05-40-58\xiuxian-card-game\data\config\realms.json`

```json
{
  "order": ["qi", "foundation", "golden", "nascent", "deity", "tribulation"],
  "realms": {
    "qi": {
      "name": "炼气期",
      "index": 0,
      "cultivationMax": 100,
      "cultivationThreshold": 100,
      "lifespanBonus": 0,
      "breakthroughCard": "break_qi",
      "pillRequired": "foundation",
      "pillName": "筑基丹"
    },
    "foundation": {
      "name": "筑基期",
      "index": 1,
      "cultivationMax": 200,
      "cultivationThreshold": 200,
      "lifespanBonus": 50,
      "breakthroughCard": "break_foundation",
      "pillRequired": "golden",
      "pillName": "结金丹"
    },
    "golden": {
      "name": "金丹期",
      "index": 2,
      "cultivationMax": 500,
      "cultivationThreshold": 500,
      "lifespanBonus": 100,
      "breakthroughCard": "break_golden",
      "pillRequired": "nascent",
      "pillName": "凝婴丹"
    },
    "nascent": {
      "name": "元婴期",
      "index": 3,
      "cultivationMax": 1200,
      "cultivationThreshold": 1200,
      "lifespanBonus": 300,
      "breakthroughCard": "break_nascent",
      "pillRequired": "deity",
      "pillName": "化神丹"
    },
    "deity": {
      "name": "化神期",
      "index": 4,
      "cultivationMax": 3000,
      "cultivationThreshold": 3000,
      "lifespanBonus": 800,
      "breakthroughCard": "break_deity",
      "pillRequired": "tribulation",
      "pillName": "渡劫丹"
    },
    "tribulation": {
      "name": "渡劫期",
      "index": 5,
      "cultivationMax": 8000,
      "cultivationThreshold": 8000,
      "lifespanBonus": 2000,
      "breakthroughCard": "break_tribulation",
      "pillRequired": null,
      "pillName": null
    }
  }
}
```

#### 1.3.2 修改 `GameStateManager.js`： cultivation 动态上限

**文件**：`E:\4e\游1\2026-06-27-05-40-58\xiuxian-card-game\src\core\GameStateManager.js`

**修改位置**：第 111-117 行

```javascript
setAttribute(name, value) {
  const oldValue = this.attributes[name] || 0;
  let maxVal = 100;
  if (name === 'health') maxVal = this.maxHealth;
  if (name === 'daoHeart') maxVal = this.maxDaoHeart;
  // FIX: cultivation 使用当前境界的 cultivationThreshold 作为软上限
  if (name === 'cultivation') {
    const realmConfig = this.config.realms ? this.config.realms.realms[this.realm] : null;
    maxVal = realmConfig ? (realmConfig.cultivationMax || realmConfig.cultivationThreshold || 100) : 100;
  }
  
  this.attributes[name] = Math.max(0, Math.min(maxVal, value));
  if (oldValue !== this.attributes[name]) {
    eventBus.emit('state:attributeChanged', {
      attribute: name,
      oldValue,
      newValue: this.attributes[name]
    });
  }
}
```

#### 1.3.3 修改 `game.js`：修复被动回血硬编码

**文件**：`E:\4e\游1\2026-06-27-05-40-58\xiuxian-card-game\src\game.js`

**修改位置**：第 1061-1064 行

```javascript
// 应用回血（不超过 maxHealth，而非硬编码 100）
if (hpRegen > 0 && gameState.attributes.health < gameState.maxHealth) {
  const healAmount = Math.min(hpRegen, gameState.maxHealth - gameState.attributes.health);
  gameState.addAttribute('health', healAmount);
}

// 应用福缘恢复（不超过100）
if (fortuneBonus > 0 && gameState.attributes.fortune < 100) {
  gameState.addAttribute('fortune', Math.min(fortuneBonus, 100 - gameState.attributes.fortune));
}
```

#### 1.3.4 修改 `ui.js`：属性条按实际上限显示

**文件**：`E:\4e\游1\2026-06-27-05-40-58\xiuxian-card-game\src\ui.js`

**修改位置**：第 465-489 行的 `renderAttributes` 方法

```javascript
renderAttributes() {
  const attrs = gameState.attributes;
  const labels = {
    cultivation: '修为', daoHeart: '道心',
    karmaGood: '善因', karmaBad: '恶因',
    fortune: '福缘', health: '气血'
  };
  
  // 获取各属性的实际上限
  const maxValues = {
    cultivation: (gameState.config.realms && gameState.config.realms.realms[gameState.realm]) 
      ? (gameState.config.realms.realms[gameState.realm].cultivationMax || 100) 
      : 100,
    daoHeart: gameState.maxDaoHeart || 3,
    health: gameState.maxHealth || 3,
    karmaGood: 100, karmaBad: 100, fortune: 100
  };
  
  for (const [key, bar] of Object.entries(this.bars)) {
    const value = attrs[key] || 0;
    const maxValue = maxValues[key] || 100;
    // 按实际上限计算百分比
    bar.style.width = `${Math.min(100, (value / maxValue) * 100)}%`;
    bar.textContent = `${value}`;
    this.labels[key].textContent = `${labels[key]} ${value}/${maxValue}`;

    // 生死红线视觉警报
    if (key === 'health' || key === 'daoHeart') {
      const item = bar.closest('.attr-item');
      if (item) {
        // 当低于上限的20%时触发警报
        if (value <= maxValue * 0.2) {
          item.classList.add('critical');
        } else {
          item.classList.remove('critical');
        }
      }
    }
  }
}
```

#### 1.3.5 新增 `ui.js` tooltip 系统

**文件**：`E:\4e\游1\2026-06-27-05-40-58\xiuxian-card-game\src\ui.js`

**在 `init()` 方法中增加 tooltip 绑定**（约第 28 行后）：

```javascript
init() {
  this.cacheElements();
  this.bindEvents();
  this.bindNpcPanels();
  this._bindShopPanel();
  this._bindThreadPanel();
  this._bindAttributeTooltips(); // 新增
  // ...
}
```

**新增方法**：

```javascript
_bindAttributeTooltips() {
  const tooltipData = {
    cultivation: (val) => {
      const realm = gameState.realm;
      const config = gameState.config.realms?.realms?.[realm];
      const threshold = config?.cultivationThreshold || 100;
      const pct = Math.floor((val / threshold) * 100);
      return `修为：修仙的根本。当前 ${val}/${threshold}（${pct}%）\n达到阈值后可尝试突破境界。`;
    },
    health: (val) => {
      const max = gameState.maxHealth;
      return `气血：当前生命。${val}/${max}\n归零则道消身陨。`;
    },
    daoHeart: (val) => {
      const max = gameState.maxDaoHeart;
      // 道心 → 突破成功率映射：每1点道心 = +1%成功率，基础50%
      const breakRate = Math.min(95, 50 + val);
      return `道心：意志力与心性。${val}/${max}\n突破成功率 +${val}%（当前基础成功率 ${breakRate}%）。`;
    },
    karmaGood: (val) => `善因：${val}。积累善行触发善缘事件，提升福缘。每10点善因增加1%稀有事件概率。`,
    karmaBad: (val) => `恶因：${val}。积累恶行增加敌人强度，但提升魔道事件概率。与善因会互相抵消。`,
    fortune: (val) => `福缘：${val}。影响稀有掉落、奇遇触发、集市品质。高于70时好事件概率增加。`
  };

  for (const [key, bar] of Object.entries(this.bars)) {
    if (!bar) continue;
    const item = bar.closest('.attr-item');
    if (!item) continue;
    
    item.addEventListener('mouseenter', (e) => {
      const val = gameState.attributes[key] || 0;
      const text = tooltipData[key] ? tooltipData[key](val) : `${key}: ${val}`;
      this._showTooltip(e.target, text);
    });
    item.addEventListener('mouseleave', () => {
      this._hideTooltip();
    });
  }
}

_showTooltip(targetEl, text) {
  let tooltip = document.getElementById('game-tooltip');
  if (!tooltip) {
    tooltip = document.createElement('div');
    tooltip.id = 'game-tooltip';
    tooltip.style.cssText = `
      position: fixed; background: rgba(0,0,0,0.9); color: #e0e0e0;
      padding: 12px 16px; border-radius: 8px; font-size: 0.85rem;
      max-width: 280px; line-height: 1.5; pointer-events: none;
      z-index: 1000; border: 1px solid rgba(255,255,255,0.1);
      white-space: pre-line;
    `;
    document.body.appendChild(tooltip);
  }
  tooltip.textContent = text;
  tooltip.style.display = 'block';
  
  const rect = targetEl.getBoundingClientRect();
  tooltip.style.left = `${rect.right + 10}px`;
  tooltip.style.top = `${rect.top}px`;
}

_hideTooltip() {
  const tooltip = document.getElementById('game-tooltip');
  if (tooltip) tooltip.style.display = 'none';
}
```

#### 1.3.6 在 `ui.js` `_renderBreakthroughBar` 中显示突破成功率

**文件**：`E:\4e\游1\2026-06-27-05-40-58\xiuxian-card-game\src\ui.js`

**修改位置**：第 421-463 行

```javascript
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
  const nextRealm = gameState.getRealmName(
    (gameState.config.realms.order || [])[
      (gameState.config.realms.order || []).indexOf(gameState.realm) + 1
    ] || ''
  );
  
  // 计算突破成功率（道心映射）
  const daoHeart = gameState.attributes.daoHeart || 0;
  const baseRate = Math.min(95, 50 + daoHeart); // 基础50% + 每点道心+1%
  const rateText = pct >= 100 ? `突破成功率：${baseRate}%` : `还需 ${threshold - current} 修为 · 成功率：${baseRate}%`;

  this.btBar.style.display = 'flex';
  this.btLabel.textContent = `🔥 ${nextRealm || '突破'}进度`;
  this.btFill.style.width = `${pct}%`;
  this.btPct.textContent = `${pct}%`;
  
  // 在进度条下方添加成功率文本（需要在 index.html 中增加 bt-rate 元素）
  const rateEl = document.getElementById('bt-rate');
  if (rateEl) {
    rateEl.textContent = rateText;
    rateEl.style.display = 'block';
  }
  // ...
}
```

**对应 `index.html` 修改**：在突破进度条 DOM 中增加 `bt-rate` 元素。

---

### 1.4 预期效果

| 指标 | 优化前 | 优化后 |
|------|-------|-------|
| 炼气→筑基修为需求 | 100 → 100（无增长） | 100 → 200（2倍） |
| 体修 maxHealth 被动回血 | 上限100无效 | 按实际 maxHealth 恢复 |
| 属性作用透明度 | 完全不可见 | 悬停显示 tooltip |
| 道心作用感知 | 玩家不知道有什么用 | 直接显示"突破成功率+X%" |
| 属性条显示 | 永远按100上限 | 按实际上限百分比显示 |

**验收标准**：
1. 选择体修后，maxHealth 初始为 33（3+30），被动回血能使 health 恢复到 33
2. 进入筑基期后，突破进度条阈值显示为 200， cultivation 可积累到 200
3. 鼠标悬停修为条，显示"当前 45/200（23%）"
4. 鼠标悬停道心条，显示"突破成功率 +5%（当前基础成功率 55%）"

---

## 2. 功法差异化设计（2页）

### 2.1 问题诊断

**当前设计**：`paths.json` 中 4 个功法仅在开局时提供不同属性加成：

```json
{
  "sword": { "bonuses": { "cultivation": 5, "daoHeart": 3, "health": -5 } },
  "spell": { "bonuses": { "cultivation": 3, "daoHeart": 5, "fortune": 3 } },
  "body": { "bonuses": { "cultivation": 0, "health": 20, "daoHeart": 5 } },
  "pill": { "bonuses": { "cultivation": 3, "spiritStone": 10, "fortune": 5 } }
}
```

`path_skills.json` 中虽有 3 层被动技能，但：
- 剑修的「血剑共鸣」`lowHpAtkBonus: 2.0` 只在旧 CombatSystem 中生效，DeckCombatSystem 完全忽略
- 法修的「道法自然」`spiritStoneBonus: 0.2` 在 EffectService 中已修复，但 `0.2` 作为百分比使用时需要 `value * 0.2`（当前已正确）
- 体修的「金刚不坏」`maxHp: 30` 因被动回血硬编码 100 而部分无效
- 丹修的「丹道真意」`pillBonus: 0.5` 只在 `_resolveBreakthrough` 中生效，日常体验无感

**核心问题**：玩家在游戏中感受不到"我是剑修"和"我是法修"的区别。除了开局 +5/-5 的属性差异，后续几百回合中，两者抽到的卡、遇到的战斗、获得的收益几乎相同。

---

### 2.2 优化方案

引入**功法专属机制**，让每种功法有独特的 gameplay loop：

#### 2.2.1 剑修 — 剑意系统

**核心机制**：战斗中积累"剑意"层数，剑意可叠加到普通攻击中造成额外伤害，或通过特殊卡牌"剑意释放"一次性消耗。

**专属机制字段**（新增到 `path_skills.json`）：

```json
{
  "id": "sword_intent",
  "name": "剑意凝聚",
  "desc": "每次战斗开始时获得2层剑意。攻击牌消耗剑意造成额外伤害。",
  "unlockRealm": "qi",
  "passive": { "startSwordIntent": 2 },
  "exclusiveMechanic": {
    "type": "sword_intent",
    "maxStack": 10,
    "damagePerStack": 2
  }
}
```

#### 2.2.2 法修 — 多选项与禁术

**核心机制**：
- 某些卡牌对法修额外开放第 3/4 个选项（上/下方向）
- 突破成功率 +10%（已在 `paths.json` 的 `bonuses` 中体现，但需要代码支持）
- 专属"禁术"支线：法修可在某些事件中选择"使用禁术"，获得强力短期收益但积累恶因

**专属机制字段**：

```json
{
  "id": "spell_options",
  "name": "万法通明",
  "desc": "部分事件卡有额外选项。突破成功率+10%。",
  "unlockRealm": "qi",
  "passive": { "breakthroughRateBonus": 10, "extraOptions": true }
}
```

#### 2.2.3 体修 — 肉身成圣

**核心机制**：
- 气血上限 +30（已有）
- 修炼速度 -20%（cultivation 获取 ×0.8）
- 突破失败时承受的伤害减半（道心扣减从 -15 变为 -8）
- 战斗中自带"减伤"状态：受到的伤害 -1（最小为1）

**专属机制字段**：

```json
{
  "id": "body_toughness",
  "name": "肉身成圣",
  "desc": "气血上限+30，修炼速度-20%，但突破失败时损伤减半。",
  "unlockRealm": "qi",
  "passive": { "maxHp": 30, "cultivationGainMult": 0.8, "breakthroughFailureReduction": 0.5 }
}
```

#### 2.2.4 丹修 — 炼丹系统

**核心机制**：
- 专属"炼丹"动作：将 2 个材料 + 灵石转化为丹药（修为丹、气血丹、道心丹）
- 商店优先出现丹方和材料
- 专属"失传丹方"支线（已有）

**专属机制字段**：

```json
{
  "id": "pill_alchemy",
  "name": "丹道真意",
  "desc": "可在洞府中将材料炼制为丹药。丹药效果+50%。",
  "unlockRealm": "qi",
  "passive": { "pillBonus": 0.5, "canAlchemy": true }
}
```

---

### 2.3 具体实现

#### 2.3.1 修改 `paths.json`：增加专属机制描述

**文件**：`E:\4e\游1\2026-06-27-05-40-58\xiuxian-card-game\data\config\paths.json`

```json
{
  "paths": {
    "sword": {
      "name": "剑修",
      "icon": "⚔️",
      "desc": "一剑破万法，高攻高风险",
      "startCard": "q_start_sword",
      "playStyle": "高爆发 · 剑意积累 · 低气血",
      "exclusiveMechanic": "剑意系统：战斗中积累剑意层数，可叠加到攻击中造成额外伤害",
      "bonuses": { "cultivation": 5, "daoHeart": 3, "health": -5 }
    },
    "spell": {
      "name": "法修",
      "icon": "🔮",
      "desc": "诸术并修，多选项策略",
      "startCard": "q_start_spell",
      "playStyle": "多选择 · 突破加成 · 禁术风险",
      "exclusiveMechanic": "万法通明：部分事件有额外选项，突破成功率+10%，可接触禁术",
      "bonuses": { "cultivation": 3, "daoHeart": 5, "fortune": 3 }
    },
    "body": {
      "name": "体修",
      "icon": "🛡️",
      "desc": "肉身成圣，气血雄厚",
      "startCard": "q_start_body",
      "playStyle": "高生存 · 慢修炼 · 抗失败",
      "exclusiveMechanic": "肉身成圣：气血上限+30，修炼速度-20%，突破失败损伤减半",
      "bonuses": { "cultivation": 0, "health": 20, "daoHeart": 5 }
    },
    "pill": {
      "name": "丹修",
      "icon": "🧪",
      "desc": "以丹入道，资源转换",
      "startCard": "q_start_pill",
      "playStyle": "资源循环 · 炼丹转化 · 丹方支线",
      "exclusiveMechanic": "炼丹系统：将材料炼制为丹药，丹药效果+50%，专属丹方支线",
      "bonuses": { "cultivation": 3, "spiritStone": 10, "fortune": 5 }
    }
  }
}
```

#### 2.3.2 修改 `path_skills.json`：增加专属机制技能

**文件**：`E:\4e\游1\2026-06-27-05-40-58\xiuxian-card-game\data\config\path_skills.json`

在每种功法下新增第一层专属技能（unlockRealm 改为 qi，开局即生效）：

```json
{
  "skills": {
    "sword": {
      "name": "剑修",
      "skills": [
        {
          "id": "sword_intent_mechanic",
          "name": "剑意凝聚",
          "desc": "战斗开始时获得2层剑意，每层剑意使攻击+2伤害",
          "unlockRealm": "qi",
          "passive": { "startSwordIntent": 2, "swordIntentDamage": 2 },
          "flavor": "剑修的核心不在于剑，而在于意。"
        },
        {
          "id": "sword_crit",
          "name": "剑气纵横",
          "desc": "战斗时暴击率+15%",
          "unlockRealm": "foundation",
          "passive": { "critRate": 15 },
          "flavor": "一剑破万法——要么中了，要么死了。"
        }
      ]
    },
    "spell": {
      "name": "法修",
      "skills": [
        {
          "id": "spell_options_mechanic",
          "name": "万法通明",
          "desc": "部分事件卡有额外选项，突破成功率+10%",
          "unlockRealm": "qi",
          "passive": { "breakthroughRateBonus": 10, "extraOptions": true },
          "flavor": "知道的越多，选择就越多。"
        },
        {
          "id": "spell_fortune",
          "name": "道法自然",
          "desc": "灵石获取+20%",
          "unlockRealm": "foundation",
          "passive": { "spiritStoneBonus": 0.2 },
          "flavor": "天地灵气，尽归我身。"
        }
      ]
    },
    "body": {
      "name": "体修",
      "skills": [
        {
          "id": "body_toughness_mechanic",
          "name": "肉身成圣",
          "desc": "气血上限+30，修炼速度-20%，突破失败损伤减半",
          "unlockRealm": "qi",
          "passive": { "maxHp": 30, "cultivationGainMult": 0.8, "breakthroughFailureReduction": 0.5 },
          "flavor": "万法不侵，只是皮厚。"
        },
        {
          "id": "body_regen",
          "name": "气血再生",
          "desc": "每轮回血3",
          "unlockRealm": "golden",
          "passive": { "hpRegen": 3 },
          "flavor": "伤口？什么伤口？"
        }
      ]
    },
    "pill": {
      "name": "丹修",
      "skills": [
        {
          "id": "pill_alchemy_mechanic",
          "name": "丹道真意",
          "desc": "可在洞府炼丹。丹药效果+50%",
          "unlockRealm": "qi",
          "passive": { "pillBonus": 0.5, "canAlchemy": true },
          "flavor": "万物皆丹——包括你自己。"
        },
        {
          "id": "pill_poison",
          "name": "万毒不侵",
          "desc": "毒属性伤害减半",
          "unlockRealm": "golden",
          "passive": { "poisonResist": 0.5 },
          "flavor": "炼丹的人，早就被毒习惯了。"
        }
      ]
    }
  }
}
```

#### 2.3.3 修改 `game.js`：应用功法专属机制

**文件**：`E:\4e\游1\2026-06-27-05-40-58\xiuxian-card-game\src\game.js`

**修改位置**：`start()` 方法中功法加成应用后（约第 374-385 行）

```javascript
start(path) {
  gameState.reset(true);
  gameState.path = path;
  this.currentCard = null;
  // ...
  
  // 应用功法加成（已有代码）
  if (gameState.config.paths && gameState.config.paths.paths[path]) {
    const pathData = gameState.config.paths.paths[path];
    const bonuses = pathData.bonuses;
    if (bonuses) {
      for (const [key, value] of Object.entries(bonuses)) {
        if (key === 'spiritStone') {
          gameState.addResource('spiritStone', null, value);
        } else if (['cultivation', 'daoHeart', 'health', 'fortune'].includes(key)) {
          gameState.addAttribute(key, value);
        }
      }
    }
    
    // FIX: 应用功法专属被动（从 pathSkillSystem 读取 qi 境界技能）
    if (typeof pathSkillSystem !== 'undefined' && pathSkillSystem) {
      const passiveBonuses = pathSkillSystem.getPassiveBonuses(path);
      
      // 体修：修炼速度调整（在 cultivation 获取时生效，此处设置 flag）
      if (passiveBonuses.cultivationGainMult) {
        gameState.setFlag('cultivationGainMult', passiveBonuses.cultivationGainMult);
      }
      
      // 法修：突破成功率加成（在 _resolveBreakthrough 中读取）
      if (passiveBonuses.breakthroughRateBonus) {
        gameState.setFlag('breakthroughRateBonus', passiveBonuses.breakthroughRateBonus);
      }
      
      // 丹修：炼丹能力标记
      if (passiveBonuses.canAlchemy) {
        gameState.setFlag('canAlchemy', true);
      }
    }
  }
  
  this._triggerUpdate();
}
```

#### 2.3.4 修改 `game.js`：体修修炼速度调整

**文件**：`E:\4e\游1\2026-06-27-05-40-58\xiuxian-card-game\src\game.js`

**修改位置**：`_applyEffects` 或 `EffectService` 中 cultivation 处理

在 `EffectService.js` 中修改 `cultivation` handler：

```javascript
// 基础属性：修为（带功法修炼速度调整）
this.handlers.set('cultivation', (value) => {
  let modifiedValue = value;
  // 体修：修炼速度降低
  const gainMult = gameState.getFlag('cultivationGainMult');
  if (gainMult && value > 0) {
    modifiedValue = Math.floor(value * gainMult);
  }
  this.gameState.addAttribute('cultivation', modifiedValue);
});
```

#### 2.3.5 修改 `game.js`：法修突破成功率加成

**文件**：`E:\4e\游1\2026-06-27-05-40-58\xiuxian-card-game\src\game.js`

**修改位置**：`_resolveBreakthrough` 方法（第 1141 行）

```javascript
_resolveBreakthrough(successRate, card) {
  // ...
  const roll = Math.random();
  
  // 法修突破成功率加成
  let adjustedRate = successRate;
  const btBonus = gameState.getFlag('breakthroughRateBonus') || 0;
  if (btBonus > 0) {
    adjustedRate = Math.min(0.95, successRate + btBonus / 100);
  }
  
  if (roll < adjustedRate) {
    this._log('突破成功！境界提升！');
    // ...
  } else {
    // 体修：突破失败损伤减半
    const failureReduction = gameState.getFlag('breakthroughFailureReduction') || 0;
    let daoHeartLoss = -15;
    let cultivationLoss = -30;
    if (failureReduction > 0) {
      daoHeartLoss = Math.floor(daoHeartLoss * (1 - failureReduction));
      cultivationLoss = Math.floor(cultivationLoss * (1 - failureReduction));
      this._log('肉身强韧，减轻了突破失败的反噬！');
    }
    this._log('突破失败，道心受挫。');
    gameState.addAttribute('daoHeart', daoHeartLoss);
    gameState.addAttribute('cultivation', cultivationLoss);
    // ...
  }
}
```

#### 2.3.6 修改 `DeckCombatSystem.js`：剑意系统支持

**文件**：`E:\4e\游1\2026-06-27-05-40-58\xiuxian-card-game\src\systems\DeckCombatSystem.js`

**修改位置**：`_start` 方法中玩家初始化后（第 167 行后）

```javascript
// 剑修：开局获得剑意层数
if (gameState.path === 'sword' && typeof pathSkillSystem !== 'undefined') {
  const bonuses = pathSkillSystem.getPassiveBonuses('sword');
  if (bonuses.startSwordIntent) {
    this._setStatus('player', 'sword_intent', bonuses.startSwordIntent);
    this._addLog(`剑意凝聚：获得 ${bonuses.startSwordIntent} 层剑意！`);
  }
}
```

**修改位置**：`_resolveEffect` 中 damage 处理（第 310 行）

```javascript
if (effect.type === 'damage') {
  let dmg = effect.value;
  // 剑意加成（支持 pathSkillSystem 配置的每层伤害）
  let swordIntent = this._getStatus('player', 'sword_intent');
  if (swordIntent > 0) {
    let intentDamage = swordIntent; // 默认 1层=1伤害
    if (typeof pathSkillSystem !== 'undefined') {
      const bonuses = pathSkillSystem.getPassiveBonuses(gameState.path);
      if (bonuses.swordIntentDamage) {
        intentDamage = swordIntent * bonuses.swordIntentDamage;
      }
    }
    dmg += intentDamage;
    this._setStatus('player', 'sword_intent', 0); // 清空
    this._addLog(`剑意爆发，附加 ${intentDamage} 伤害！`);
  }
  
  this._dealDamage(this.enemy, dmg);
}
```

#### 2.3.7 修改 `ui.js`：开局功法选择界面增加专属机制展示

**文件**：`E:\4e\游1\2026-06-27-05-40-58\xiuxian-card-game\src\ui.js`

在 `renderStartScreen` 或功法选择渲染时，为每个功法按钮添加 `.path-exclusive` 元素显示专属机制。这需要在 CSS 和 HTML 中配合，此处略。

---

### 2.4 预期效果

| 功法 | 优化前体验 | 优化后体验 |
|------|----------|----------|
| 剑修 | 开局 health-5，之后无区别 | 战斗有剑意系统，高爆发但低生存 |
| 法修 | 开局 fortune+3，之后无区别 | 更多选择、更高突破率、可接触禁术 |
| 体修 | 开局 health+20，之后无区别 | 超高气血、抗失败、但修炼慢 |
| 丹修 | 开局 spiritStone+10，之后无区别 | 可炼丹转化资源、丹药效果强 |

**验收标准**：
1. 选择剑修开局，进入第一场 DeckCombatSystem 战斗，初始手牌外有 2 层 sword_intent 状态
2. 选择法修，突破炼气→筑基时，成功率显示为 60%（基础50% + 10%）
3. 选择体修， cultivation 获取 ×0.8，突破失败只扣 8 道心和 15 修为
4. 选择丹修，在洞府冥想卡中出现"炼丹"额外选项

---

## 3. 战斗系统统一方案（3页）

### 3.1 问题诊断

#### 3.1.1 双系统并存，同时监听 `combat:start`

**代码证据**：

`src/systems/CombatSystem.js:46`（旧系统）：
```javascript
eventBus.on('combat:start', (data) => this._start(data));
```

`src/systems/DeckCombatSystem.js:36`（新系统）：
```javascript
eventBus.on('combat:start', (data) => this._start(data));
```

**问题**：如果 `game.js` 或 `CombatCoordinator` 直接 emit `combat:start`，两个系统会**同时初始化**，各自创建独立的 player/enemy 状态，导致：
- 旧系统显示一个战斗界面，新系统显示另一个
- 日志混乱，两个系统都向 `this.log` 写数据
- 胜利/失败时两个系统都 emit 事件，UI 收到两次通知

#### 3.1.2 DeckCombatSystem 不发放任何战斗奖励

**代码证据**：`src/systems/DeckCombatSystem.js:538-548`

```javascript
_victory() {
  this.active = false;
  this._addLog(`战斗胜利！`);
  
  // 同步剩余HP
  gameState.attributes.health = this.player.hp;
  eventBus.emit('combat:victory', { originalCard: this.originalCard });
  
  // 关闭 UI
  eventBus.emit('ui:hideCombatScreen');
}
```

**问题**：旧 `CombatSystem._victory()` 会发放 cultivation、spiritStone、treasure 等奖励（`src/systems/CombatSystem.js:744-815`），但 `DeckCombatSystem._victory()` **完全不发放任何奖励**。玩家通过 DeckCombatSystem 赢得战斗后，只获得 `CombatCoordinator._buildCombatRewardCard()` 生成的战利品选择卡，而没有任何基础修为/灵石奖励。

#### 3.1.3 DeckCombatSystem 忽略 `card.enemy` 的 HP/ATK/DEF

**代码证据**：`src/systems/DeckCombatSystem.js:92-122`

```javascript
const enemyData = card.enemy;
const tier = enemyData.tier || 1;
let enemyHp = 3;
if (tier === 2) enemyHp = 8;
if (tier === 3) enemyHp = 15;
```

**问题**：卡牌数据中精心设计的 `enemy.hp`、`enemy.atk`、`enemy.def` 被完全忽略。所有 T1 敌人统一 3 血，T2 统一 8 血，T3 统一 15 血。这导致：
- 炼气期同门比试（设计中 HP=25）变成 3 血秒杀
- 元婴期大能（设计中 HP=50）变成 15 血，与普通妖兽无区别

#### 3.1.4 新旧系统事件格式不兼容

**代码证据**：

旧 `CombatSystem._defeat()`（`src/systems/CombatSystem.js:817-839`）：
```javascript
eventBus.emit('combat:defeat', {
  cardId: this.cardId,
  hpLoss: hpLoss,
  log: this.log
});
```

新 `DeckCombatSystem._checkPlayerDeath()`（`src/systems/DeckCombatSystem.js:525-536`）：
```javascript
eventBus.emit('combat:defeat', { originalCard: this.originalCard });
```

`CombatCoordinator.onDefeat()`（`src/coordinators/CombatCoordinator.js:158-170`）：
```javascript
onDefeat(data) {
  if (data && data.originalCard && data.originalCard.combatRewards && data.originalCard.combatRewards.breakSuccess) {
    // 突破失败处理
  } else {
    gameState.addAttribute('health', -20); // 额外扣血！
  }
}
```

**问题**：当旧 `CombatSystem` 触发 defeat 时，`data.originalCard` 为 `undefined`，进入 else 分支额外扣除 20 点 health，造成**重复扣血**（旧系统已经扣了 `hpLoss`）。

#### 3.1.5 旧 CombatSystem 奖励日志与实物不一致

**代码证据**：`src/systems/CombatSystem.js:769-780`

```javascript
if (this.rewards) {
  if (this.rewards.cultivation) {
    gameState.addAttribute('cultivation', this.rewards.cultivation);
    rewardText.push(`修为 +${this.rewards.cultivation}`);
  }
  // ... 只发放自定义奖励
}

// 默认奖励（始终添加到日志，但未必发放）
const defaultCult = 5 + Math.floor(gameState.attributes.cultivation / 20);
if (!this.rewards || !this.rewards.cultivation) {
  gameState.addAttribute('cultivation', defaultCult);
}
rewardText.push(`修为 +${defaultCult}`); // 日志总是显示默认奖励
```

**问题**：当 `this.rewards.cultivation` 存在时，实际只发放自定义奖励，但 `rewardText` 仍然追加了默认奖励的文本，数据与显示不一致。

---

### 3.2 优化方案

**推荐方案 A：统一使用 DeckCombatSystem，废弃旧 CombatSystem。**

理由：
1. DeckCombatSystem 是杀戮尖塔式微数值打牌系统，节奏快（3-5 回合结束），更适合卡牌决策游戏的核心体验
2. 旧 CombatSystem 是回合制 RPG 战斗（玩家 HP 300+，敌人 25-30），与卡牌游戏的"每回合快速决策"节奏不匹配
3. 旧系统的格挡时机、架势切换、灵力管理虽然深度高，但学习曲线陡峭，与游戏目标受众（休闲卡牌玩家）不匹配
4. DeckCombatSystem 已有 UI 界面（`deck-combat-screen`），旧系统无独立 UI

**方案 A 实施步骤**：
1. 移除旧 `CombatSystem` 的事件监听（不再响应 `combat:start`）
2. 在 `DeckCombatSystem._victory()` 中补充战斗奖励发放
3. 统一事件格式为 `{ originalCard, cardId }`
4. 让 `DeckCombatSystem` 读取 `card.enemy` 的 HP/ATK/DEF 数据（以 enemy 数据为准，tier 仅作为 fallback）
5. 在 `CombatCoordinator` 中统一处理 victory/defeat/fled

---

### 3.3 具体实现

#### 3.3.1 修改 `CombatSystem.js`：注释掉事件监听

**文件**：`E:\4e\游1\2026-06-27-05-40-58\xiuxian-card-game\src\systems\CombatSystem.js`

**修改位置**：第 42-48 行的 `init()` 方法

```javascript
init() {
  this.active = false;
  this.log = [];
  this.turn = 0;
  // FIX: 旧战斗系统已废弃，不再监听 combat:start
  // 保留其他事件监听以兼容格挡时机等 UI 功能（如需）
  // eventBus.on('combat:start', (data) => this._start(data));
  // eventBus.on('combat:action', (data) => this._executeAction(data));
  // eventBus.on('combat:blockAction', (data) => this._resolveBlock(data));
  eventBus.on('state:reset', () => this.reset());
}
```

> **注意**：保留文件本身，不删除。如果未来需要恢复旧系统（如高级玩家要求），只需取消注释即可。

#### 3.3.2 修改 `DeckCombatSystem.js`：读取 enemy 数据 + 奖励发放

**文件**：`E:\4e\游1\2026-06-27-05-40-58\xiuxian-card-game\src\systems\DeckCombatSystem.js`

**修改位置 1**：第 92-122 行，敌人初始化

```javascript
// 初始化敌人微数值 (优先使用 card.enemy 数据，tier 仅作为 fallback)
const enemyData = card.enemy;
const tier = enemyData.tier || 1;

// FIX: 优先使用卡牌中定义的 enemy.hp/atk/def，而非硬编码 tier 映射
let enemyHp = enemyData.hp || (tier === 2 ? 8 : tier === 3 ? 15 : 3);
let enemyAtk = enemyData.atk || (tier === 2 ? 2 : tier === 3 ? 3 : 1);
let enemyDef = enemyData.def || 0;
```

**修改位置 2**：第 113-122 行，敌人对象构造

```javascript
this.enemy = {
  name: (enemyDef && enemyDef.name) || enemyData.name || '修仙者',
  hp: enemyHp,
  maxHp: enemyHp,
  block: 0,
  tier: tier,
  def: enemyDef,
  intentIndex: 0,
  factionId: enemyData.factionId || null,
  // 新增：保存原始攻击力，用于意图伤害计算
  baseAtk: enemyAtk
};
```

**修改位置 3**：第 198-220 行，意图生成时读取 enemy 攻击力

```javascript
_generateEnemyIntent() {
  if (this.enemy.def && this.enemy.def.intents) {
    const intents = this.enemy.def.intents;
    this.enemyIntent = intents[this.enemy.intentIndex % intents.length];
    this.enemy.intentIndex++;
  } else {
    // Fallback 极简意图逻辑，使用 enemy.baseAtk
    const intents = [];
    const baseAtk = this.enemy.baseAtk || 1;
    if (this.enemy.tier === 1) {
      intents.push({ type: 'attack', value: baseAtk, desc: `意图：攻击 (${baseAtk}点伤害)` });
    } else if (this.enemy.tier === 2) {
      if (this.turn % 3 === 0) {
        intents.push({ type: 'debuff', value: 1, desc: '意图：施加负面状态' });
      } else {
        intents.push({ type: 'attack', value: baseAtk, desc: `意图：攻击 (${baseAtk}点伤害)` });
      }
    } else {
      intents.push({ type: 'attack', value: baseAtk, desc: `意图：攻击 (${baseAtk}点伤害)` });
    }
    this.enemyIntent = intents[0];
  }
}
```

**修改位置 4**：第 538-548 行，`_victory` 方法补充奖励

```javascript
_victory() {
  this.active = false;
  this._addLog(`战斗胜利！`);
  
  // 同步剩余HP
  gameState.attributes.health = this.player.hp;
  
  // FIX: 发放战斗基础奖励（修为 + 灵石）
  const originalCard = this.originalCard || {};
  const rewards = originalCard.combatRewards || {};
  
  // 1. 修为奖励（自定义优先，否则按敌人强度计算）
  if (rewards.cultivation) {
    gameState.addAttribute('cultivation', rewards.cultivation);
    this._addLog(`修为 +${rewards.cultivation}`);
  } else {
    // 默认奖励：按敌人 tier 计算
    const defaultCult = (this.enemy.tier || 1) * 3 + Math.floor(gameState.attributes.cultivation / 50);
    gameState.addAttribute('cultivation', defaultCult);
    this._addLog(`修为 +${defaultCult}`);
  }
  
  // 2. 灵石奖励
  if (rewards.spiritStone) {
    gameState.addResource('spiritStone', null, rewards.spiritStone);
    this._addLog(`灵石 +${rewards.spiritStone}`);
  } else {
    const defaultStone = (this.enemy.tier || 1) * 5 + Math.floor(Math.random() * 5);
    gameState.addResource('spiritStone', null, defaultStone);
    this._addLog(`灵石 +${defaultStone}`);
  }
  
  // 3. 丹药/法宝奖励（如果有）
  if (rewards.pill) {
    gameState.addResource('pills', rewards.pill, 1);
    this._addLog(`获得丹药：${rewards.pill}`);
  }
  if (rewards.treasure) {
    gameState.addResource('treasures', rewards.treasure, 1);
    if (typeof treasureSystem !== 'undefined') treasureSystem.acquire(rewards.treasure);
    this._addLog(`获得法宝：${rewards.treasure}`);
  }
  
  // 4. 善恶因奖励
  if (rewards.karmaGood) {
    gameState.addAttribute('karmaGood', rewards.karmaGood);
    this._addLog(`善缘 +${rewards.karmaGood}`);
  }
  if (rewards.karmaBad) {
    gameState.addAttribute('karmaBad', rewards.karmaBad);
    this._addLog(`恶业 +${rewards.karmaBad}`);
  }
  
  // 5. 因果种子：战斗伤疤与威名（从旧 CombatSystem 迁移）
  if (typeof karmaSystem !== 'undefined' && karmaSystem) {
    if (this.player.hp < this.player.maxHp * 0.3) {
      karmaSystem.plantSeed({
        id: 'combatScar',
        description: `与${this.enemy.name}大战后气血亏空，落下病根。`,
        originCard: originalCard.id,
        magnitude: Math.floor((this.player.maxHp * 0.3 - this.player.hp) / 5)
      });
    }
    if (this.enemy.factionId) {
      karmaSystem.plantSeed({
        id: 'combatGlory',
        description: `你击败了${this.enemy.name}，战名开始在修真界流传。`,
        originCard: originalCard.id,
        magnitude: 10
      });
    }
  }
  
  // FIX: 统一事件格式，包含 originalCard 和 cardId
  eventBus.emit('combat:victory', { 
    originalCard: this.originalCard,
    cardId: originalCard.id || null
  });
  
  // 关闭 UI
  eventBus.emit('ui:hideCombatScreen');
}
```

**修改位置 5**：第 525-536 行，`_checkPlayerDeath` 统一事件格式

```javascript
_checkPlayerDeath() {
  if (this.player.hp <= 0) {
    this.player.hp = 0;
    this.active = false;
    
    // 同步回 gameState
    gameState.attributes.health = 0;
    this._addLog(`你被击败了...`);
    eventBus.emit('ui:hideCombatScreen');
    
    // FIX: 统一事件格式，包含 originalCard 和 cardId
    eventBus.emit('combat:defeat', { 
      originalCard: this.originalCard,
      cardId: this.originalCard ? this.originalCard.id : null
    });
  }
}
```

#### 3.3.3 修改 `CombatCoordinator.js`：统一事件处理

**文件**：`E:\4e\游1\2026-06-27-05-40-58\xiuxian-card-game\src\coordinators\CombatCoordinator.js`

**修改位置**：第 120-196 行

```javascript
/**
 * 战斗胜利结算
 */
onVictory(data) {
  this._dbg('onVictory', data?.originalCard?.id);
  this._inCombat = false;
  this._combatWarningShown = false;

  if (this.callbacks.onInnerVoice) {
    this.callbacks.onInnerVoice('combat_victory', 0.5);
  }

  // 记录已玩卡牌
  const currentCard = this._getCurrentCard();
  if (currentCard) {
    this.gameState.cardsPlayed.push(currentCard.id);
    this.gameState.turn++;
  }

  // 生成战利品卡牌（DeckCombatSystem 已发放基础奖励，此处只生成额外战利品）
  const rewardCard = this._buildCombatRewardCard(data);
  if (this.callbacks.setCurrentCard) {
    this.callbacks.setCurrentCard(rewardCard);
  }

  if (this.karmaSystem) this.karmaSystem.tick();

  // 势力声望联动
  const factionResult = this._applyFactionReputation(true);
  if (factionResult) this._log(factionResult);

  if (this.gameState.checkDeath()) {
    this._handleDeath();
    return;
  }
  this._triggerUpdate();
}

/**
 * 战斗失败结算
 */
onDefeat(data) {
  this._dbg('onDefeat', data?.originalCard?.id);
  this._inCombat = false;
  this._combatWarningShown = false;

  // FIX: 统一处理 defeat 逻辑
  const originalCard = data && data.originalCard;
  
  if (originalCard && originalCard.combatRewards && originalCard.combatRewards.breakSuccess) {
    // 突破战斗失败：不额外扣血，只扣突破相关
    if (this.callbacks.onResolveBreakthrough) {
      this.callbacks.onResolveBreakthrough(0, originalCard);
    }
  } else {
    // 普通战斗失败：DeckCombatSystem 已将 health 设为 0，此处只需处理失败后果
    // 如果 health > 0（逃跑或其他情况），则扣除 20
    if (this.gameState.attributes.health > 0) {
      this.gameState.addAttribute('health', -20);
    }
  }

  if (this.gameState.attributes.health < 20) {
    if (this.callbacks.onInnerVoice) {
      this.callbacks.onInnerVoice('near_death', 0.9);
    }
  }

  const currentCard = this._getCurrentCard();
  if (currentCard) {
    this.gameState.cardsPlayed.push(currentCard.id);
    this.gameState.turn++;
  }
  if (this.callbacks.setCurrentCard) this.callbacks.setCurrentCard(null);

  if (this.karmaSystem) this.karmaSystem.tick();

  // 势力声望联动
  const factionResult = this._applyFactionReputation(false);
  if (factionResult) this._log(factionResult);

  if (this.gameState.checkDeath()) {
    this._handleDeath();
    return;
  }
  this._triggerUpdate();
}
```

#### 3.3.4 修改 `CombatSystem.js`：统一 defeat 事件格式

**文件**：`E:\4e\游1\2026-06-27-05-40-58\xiuxian-card-game\src\systems\CombatSystem.js`

**修改位置**：第 817-839 行

```javascript
_defeat() {
  this.active = false;

  // 扣除血量
  const hpLoss = Math.floor(this.player.maxHp * 0.3);
  gameState.addAttribute('health', -hpLoss);

  // 消耗额外寿元
  gameState.resources.lifespan -= 3;

  // 势力声望联动
  const factionResult = this._applyFactionReputation(false);

  this._addLog(`你战败了——损失了 ${hpLoss} 点气血和 3 年寿元。`);
  this._addLog(`你拖着伤残之躯逃离了战场...`);
  if (factionResult) this._addLog(factionResult);

  // FIX: 统一事件格式
  eventBus.emit('combat:defeat', {
    originalCard: { id: this.cardId },
    cardId: this.cardId,
    hpLoss: hpLoss,
    log: this.log
  });
}
```

#### 3.3.5 修改 `CombatSystem.js`：修复奖励日志与实物不一致

**文件**：`E:\4e\游1\2026-06-27-05-40-58\xiuxian-card-game\src\systems\CombatSystem.js`

**修改位置**：第 744-780 行

```javascript
_victory() {
  this.active = false;

  const rewardText = [];
  
  // 自定义奖励（如果存在）
  if (this.rewards) {
    if (this.rewards.cultivation) {
      gameState.addAttribute('cultivation', this.rewards.cultivation);
      rewardText.push(`修为 +${this.rewards.cultivation}`);
    }
    if (this.rewards.spiritStone) {
      gameState.addResource('spiritStone', null, this.rewards.spiritStone);
      rewardText.push(`灵石 +${this.rewards.spiritStone}`);
    }
    if (this.rewards.pill) {
      gameState.addResource('pills', this.rewards.pill, 1);
      rewardText.push(`获得丹药：${this.rewards.pill}`);
    }
    if (this.rewards.treasure) {
      gameState.addResource('treasures', this.rewards.treasure, 1);
      if (treasureSystem) treasureSystem.acquire(this.rewards.treasure);
      rewardText.push(`获得法宝：${this.rewards.treasure}`);
    }
  }

  // 默认奖励（仅在没有自定义奖励时发放）
  const defaultCult = 5 + Math.floor(gameState.attributes.cultivation / 20);
  if (!this.rewards || !this.rewards.cultivation) {
    gameState.addAttribute('cultivation', defaultCult);
    rewardText.push(`修为 +${defaultCult}`);
  }

  const defaultStone = Math.floor(this.enemy.atk * 1.5);
  if (!this.rewards || !this.rewards.spiritStone) {
    gameState.addResource('spiritStone', null, defaultStone);
    rewardText.push(`灵石 +${defaultStone}`);
  }

  // ... 其余不变
}
```

---

### 3.4 预期效果

| 指标 | 优化前 | 优化后 |
|------|-------|-------|
| 双系统冲突 | 同时响应 combat:start | 仅 DeckCombatSystem 响应 |
| 战斗奖励 | DeckCombatSystem 无奖励 | 发放 cultivation + spiritStone + 自定义奖励 |
| 敌人数据 | 统一 3/8/15 HP | 按 card.enemy.hp/atk/def 个性化 |
| defeat 事件 | 格式不一致导致重复扣血 | 统一 `{originalCard, cardId}` 格式 |
| 奖励日志 | 总是显示默认奖励，与实际不符 | 仅显示实际发放的奖励 |

**验收标准**：
1. 触发一场战斗后，旧 CombatSystem 的 `_start` 不再被调用（在控制台确认无旧系统日志）
2. 通过 DeckCombatSystem 赢得战斗后， cultivation 和 spiritStone 均有增加
3. 一张 enemy.hp=25 的战斗卡，进入 DeckCombatSystem 后敌人 HP 显示为 25（而非 3/8/15）
4. 旧 CombatSystem 的 defeat 事件不再导致额外扣 20 血

---

## 4. 商店与资源系统优化（2页）

### 4.1 问题诊断

#### 4.1.1 商店选择后跳过整个回合结算

**代码证据**：`src/game.js:642-675`

```javascript
// 【商店卡】打开商店 UI，暂停卡牌流
if (choice.openShop) {
  gameState.cardsPlayed.push(card.id);
  gameState.turn++;
  eventBus.emit('shop:open', {
    items: shopSystem ? shopSystem.getAvailableItems(gameState.realm) : []
  });
  this._triggerUpdate();
  return true;  // ← 提前 return，跳过后续所有结算
}

// 【v2.0 集市】
if (choice.openMarket) {
  // ...
  this._triggerUpdate();
  return true;  // ← 同样提前 return
}
```

**跳过的结算包括**：
- 寿元消耗 (`_shouldConsumeLifespan`)
- 因果计时推进 (`karmaSystem.tick()`)
- NPC 情绪衰减 (`npcSystem._tick()`)
- 法宝被动回血 (`_applyPassiveRegen()`)
- 道侣危机检测 (`_checkCompanionCrisis`)
- 选择回响 (`_plantChoiceEcho`)
- 世界事件推进 (`_tickWorldEvents`)
- 属性剧变检测 (`_checkAttrSurges`)

**影响**：每次进入商店，玩家"免费"获得一回合——不消耗寿元、不推进因果、不检测死亡。这破坏了游戏的核心循环节奏。

#### 4.1.2 商店出现时机不可预期

**代码证据**：`src/systems/CardSystem.js:374-398`

```javascript
_checkShopEncounter() {
  // ...
  const realmOrder = ['qi', 'foundation', 'golden', 'nascent', 'formation', 'void', 'tribulation'];
  // formation 和 void 是错误境界名！
  if (realmIdx <= 1) { minInterval = 8; probability = 0.10; }
  else { minInterval = 6; probability = 0.15; }
  if (turn % minInterval !== 0) return null;
  if (Math.random() >= probability) return null;
  return this._buildShopCard();
}
```

**问题**：
- 商店出现是纯随机，玩家不知道"什么时候能买东西"
- 化神期（deity）玩家 `realmIdx = -1`（因为 `formation`/`void` 错误），被错误地按炼气期频率处理
- 随机性导致某些局玩家 30 回合都遇不到商店，另一些局连续遇到

#### 4.1.3 商店商品与功法无关

**代码证据**：`src/systems/ShopSystem.js:28-59`

```javascript
getAvailableItems(realm) {
  const realmOrder = ['qi', 'foundation', 'golden', 'nascent', 'formation', 'void', 'tribulation'];
  // ...
  let available = this.items.filter(item => {
    const itemIdx = realmOrder.indexOf(item.realm);
    return itemIdx <= maxIdx;
  });
  // 随机注入2张功法卡牌
  // ...
}
```

**问题**：商品列表只按境界过滤，与玩家当前功法完全无关。剑修商店可能卖法术书，法修商店可能卖剑类法宝，没有"功法专属商品"的体验。

---

### 4.2 优化方案

#### 4.2.1 修复商店跳过回合结算

**方案**：将 `openShop`/`openMarket` 分支的 `return true` 改为继续执行后续流程，仅设置一个标志位 `this._shopOpened = true` 来防止重复触发。

#### 4.2.2 商店改为"定期出现"

**方案**：
- 每 10 回合（或固定间隔）必定出现一次商店卡，取代随机概率
- 在顶部 HUD 增加"下回合商店"提示（当距离商店还有 1-2 回合时）
- 修复 `realmOrder` 硬编码，使用 `gameState.config.realms.order`

#### 4.2.3 商品与功法挂钩

**方案**：
- 剑修商店：优先出现攻击类法宝、剑意卡牌、暴击丹药
- 法修商店：优先出现法术书、突破辅助丹药、灵石加成道具
- 体修商店：优先出现气血丹药、防御法宝、减伤符文
- 丹修商店：优先出现材料包、丹方、炼丹工具

#### 4.2.4 丹修专属"炼丹"系统

**方案**：在洞府冥想卡中，丹修玩家额外出现"炼丹"选项，将材料转化为修为丹/气血丹/道心丹。

---

### 4.3 具体实现

#### 4.3.1 修改 `game.js`：修复商店跳过回合结算

**文件**：`E:\4e\游1\2026-06-27-05-40-58\xiuxian-card-game\src\game.js`

**修改位置**：第 642-675 行

```javascript
// 【商店卡】打开商店 UI，暂停卡牌流
if (choice.openShop) {
  gameState.cardsPlayed.push(card.id);
  gameState.turn++;
  eventBus.emit('shop:open', {
    items: shopSystem ? shopSystem.getAvailableItems(gameState.realm) : []
  });
  // FIX: 不再 return true，设置标志位后继续执行后续流程
  this._shopOpened = true;
  // 注意：不要 return，继续执行下方的回合结算
}

// 【v2.0 集市】
if (choice.openMarket) {
  gameState.cardsPlayed.push(card.id);
  gameState.turn++;
  if (typeof marketSystem !== 'undefined' && marketSystem) {
    marketSystem._totalVisits++;
    const marketItems = marketSystem.getCurrentMarketItems();
    const fortuneTier = marketSystem.getFortuneTierText();
    const priceMult = marketSystem.getPriceMultiplier();
    eventBus.emit('shop:open', {
      items: marketItems,
      market: true,
      fortuneTier,
      priceMult,
      fortune: gameState.attributes.fortune
    });
  } else {
    eventBus.emit('shop:open', { items: [] });
  }
  // FIX: 同样不 return true
  this._shopOpened = true;
}

// 确保只有未进入商店时，才执行后续流程（但即使进了商店，也执行回合结算）
// 原代码在 642-675 之间提前 return，现在移除 return
```

**同时，将商店相关的回合结算代码独立为一个方法**：

在 `makeChoice` 方法末尾（第 920 行后）添加：

```javascript
// 商店/集市已处理，执行回合结算（之前被跳过的部分）
if (this._shopOpened) {
  this._shopOpened = false;
  // 继续执行：因果、回血、道侣检测、世界事件等
  this._executeRoundEndSettlement(card, choice, direction);
  return true;
}
```

**新增 `_executeRoundEndSettlement` 方法**：

```javascript
/**
 * 回合结束结算（被商店/集市共用）
 */
_executeRoundEndSettlement(card, choice, direction) {
  // 寿元消耗
  if (this._shouldConsumeLifespan(card, choice)) {
    gameState.resources.lifespan -= 1;
  }

  // 因果种子：lifespanWaste
  if (gameState.resources.lifespan <= 20 && gameState.resources.lifespan > 0) {
    if (typeof karmaSystem !== 'undefined' && karmaSystem) {
      const existing = karmaSystem.getActiveSeeds && karmaSystem.getActiveSeeds('lifespanWaste');
      if (!existing || existing.length === 0) {
        karmaSystem.plantSeed({
          id: 'lifespanWaste',
          description: `寿元仅剩 ${gameState.resources.lifespan} 年，身体开始衰竭。`,
          originCard: card.id,
          magnitude: Math.max(1, 30 - gameState.resources.lifespan)
        });
      }
    }
  }

  // 因果计时推进
  karmaSystem.tick();

  // NPC情绪衰减
  if (typeof npcSystem !== 'undefined' && npcSystem) {
    npcSystem._tick();
  }

  // 法宝/功法被动回血
  this._applyPassiveRegen();

  // 道侣危机检测
  this._checkCompanionCrisis(card, direction, choice);

  // 选择回响
  this._plantChoiceEcho(card, direction, choice);

  // 故事线程
  this._recordChoiceHistory(card, direction, choice);
  if (typeof threadEngine !== 'undefined' && threadEngine) {
    threadEngine.onChoiceMade(card, direction, choice, gameState);
    threadEngine.tick(gameState);
  }

  // 叙事连贯性
  if (typeof coherenceLayer !== 'undefined' && coherenceLayer) {
    const narration = coherenceLayer.narrateChoice(card, direction, choice, gameState);
    if (narration) this._log(narration);
  }

  // 事件：卡牌被选择
  eventBus.emit('card:chosen', { card, direction, choice });

  // 道侣耳语
  this._triggerCompanionWhisper(card, direction);

  // 属性剧变检测
  this._checkAttrSurges();
  if (this._innerVoiceCooldown > 0) this._innerVoiceCooldown--;

  // 世界事件
  if (!this.combatCoordinator.isInCombat()) {
    this._tickWorldEvents();
  }

  // 检查死亡
  if (gameState.checkDeath()) {
    const pn = gameState.playerName || '叶凌云';
    this._log(`${pn}，道消身陨。${gameState.deadReason}`);
    this.currentCard = cardSystem.draw();
    this._triggerUpdate();
    return;
  }

  this._triggerUpdate();
}
```

> **注意**：这实际上需要重构 `makeChoice` 的后期流程，将"核心效果应用"与"回合结算"分离。如果重构风险较高，可以采用更保守的方案：保留 `return true`，但在 `return` 之前手动调用所有被跳过的结算方法。

**保守方案**（推荐，风险更低）：

```javascript
if (choice.openShop) {
  gameState.cardsPlayed.push(card.id);
  gameState.turn++;
  eventBus.emit('shop:open', { items: shopSystem ? shopSystem.getAvailableItems(gameState.realm) : [] });
  
  // FIX-保守：手动执行所有被跳过的回合结算
  this._executeRoundEndSettlement(card, choice, direction);
  
  this._triggerUpdate();
  return true;
}
```

#### 4.3.2 修改 `CardSystem.js`：商店定期出现 + 修复 realmOrder

**文件**：`E:\4e\游1\2026-06-27-05-40-58\xiuxian-card-game\src\systems\CardSystem.js`

**修改位置**：第 374-398 行

```javascript
_checkShopEncounter() {
  if (typeof shopSystem === 'undefined' || !shopSystem) return null;

  const turn = gameState.turn;
  const realm = gameState.realm;
  
  // FIX: 使用配置中的境界顺序，而非硬编码
  const realmOrder = gameState.config.realms && gameState.config.realms.order 
    ? gameState.config.realms.order 
    : ['qi', 'foundation', 'golden', 'nascent', 'deity', 'tribulation'];
  const realmIdx = realmOrder.indexOf(realm);

  // 定期出现：每 SHOP_INTERVAL 回合必定出现
  const SHOP_INTERVAL = 10;
  if (turn > 0 && turn % SHOP_INTERVAL === 0) {
    return this._buildShopCard();
  }
  
  return null;
}
```

#### 4.3.3 修改 `ShopSystem.js`：商品与功法挂钩

**文件**：`E:\4e\游1\2026-06-27-05-40-58\xiuxian-card-game\src\systems\ShopSystem.js`

**修改位置**：第 28-59 行

```javascript
getAvailableItems(realm) {
  const realmOrder = gameState.config.realms && gameState.config.realms.order
    ? gameState.config.realms.order
    : ['qi', 'foundation', 'golden', 'nascent', 'deity', 'tribulation'];
  const maxIdx = realmOrder.indexOf(realm);
  if (maxIdx < 0) return [];

  let available = this.items.filter(item => {
    const itemIdx = realmOrder.indexOf(item.realm);
    return itemIdx <= maxIdx;
  });
  
  // FIX: 根据功法过滤和排序商品
  const path = gameState.path;
  if (path) {
    // 功法偏好权重
    const pathPrefs = {
      sword: ['attack', 'crit', 'sword_card'],
      spell: ['spell', 'mana', 'breakthrough'],
      body: ['defense', 'hp', 'regen'],
      pill: ['pill', 'material', 'alchemy']
    };
    const prefs = pathPrefs[path] || [];
    
    // 将匹配功法的商品置顶（排序）
    available.sort((a, b) => {
      const aMatch = prefs.includes(a.category) ? 1 : 0;
      const bMatch = prefs.includes(b.category) ? 1 : 0;
      return bMatch - aMatch;
    });
  }

  // 动态注入随机的功法卡牌
  // ...（保留原有逻辑）

  return available;
}
```

> **注意**：这需要在 `shop_items.json` 中为商品增加 `category` 字段。如果数据层未准备，可以先注释掉排序逻辑，仅保留框架。

#### 4.3.4 新增丹修专属炼丹系统

**文件**：`E:\4e\游1\2026-06-27-05-40-58\xiuxian-card-game\src\game.js`

在 `makeChoice` 中洞府冥想分支后，增加炼丹处理：

```javascript
// 洞府进入（已有代码）
if (choice.dungeon) {
  // ...
}

// FIX: 丹修专属——洞府炼丹
if (choice.alchemy && gameState.getFlag('canAlchemy')) {
  const materialCost = choice.alchemy.materials || 2;
  const spiritStoneCost = choice.alchemy.spiritStone || 10;
  
  // 检查材料（简化：假设材料以某种方式存在）
  if (gameState.resources.spiritStone >= spiritStoneCost) {
    gameState.addResource('spiritStone', null, -spiritStoneCost);
    
    const pillType = choice.alchemy.pillType || 'health_pill';
    const pillAmount = 1 + (pathSkillSystem ? (pathSkillSystem.getPassiveBonuses('pill').pillBonus || 0) : 0);
    
    gameState.addResource('pills', pillType, Math.floor(pillAmount));
    this._log(`炼丹成功！获得 ${pillType} x${Math.floor(pillAmount)}。`);
  } else {
    this._log('灵石不足，无法炼丹。');
  }
}
```

---

### 4.4 预期效果

| 指标 | 优化前 | 优化后 |
|------|-------|-------|
| 商店回合结算 | 跳过全部 | 正常执行 |
| 商店出现频率 | 随机 8-12 回合 10% | 固定每 10 回合 |
| 商品相关性 | 与功法无关 | 功法偏好排序 |
| 丹修体验 | 无专属机制 | 可炼丹转化资源 |

**验收标准**：
1. 进入商店并购买物品后，寿元 -1、因果推进、回血、道侣检测等均正常执行
2. 第 10、20、30 回合必定出现商店卡
3. 剑修商店的前 3 个商品中出现攻击/暴击相关物品的概率 > 50%
4. 丹修玩家在洞府冥想卡中看到"炼丹"选项

---

## 本章总结

| 优化项 | 关键修改文件 | 影响等级 | 预计工作量 |
|--------|------------|---------|----------|
| 境界阶梯化阈值 | `realms.json` | P1 | 1小时 |
| cultivation 动态上限 | `GameStateManager.js` | P1 | 30分钟 |
| 被动回血硬编码修复 | `game.js` | P0 | 15分钟 |
| 属性 tooltip 系统 | `ui.js` + `index.html` | P2 | 2小时 |
| 道心→突破成功率可视化 | `ui.js` | P2 | 1小时 |
| 功法专属机制 | `path_skills.json` + `paths.json` + `game.js` + `DeckCombatSystem.js` | P1 | 4小时 |
| 战斗系统统一（方案A） | `CombatSystem.js` + `DeckCombatSystem.js` + `CombatCoordinator.js` | P0 | 3小时 |
| 商店回合结算修复 | `game.js` | P1 | 2小时 |
| 商店定期出现 | `CardSystem.js` | P2 | 1小时 |
| 商品与功法挂钩 | `ShopSystem.js` | P2 | 1.5小时 |
| 丹修炼丹系统 | `game.js`（新增选项处理） | P2 | 2小时 |

**总计**：约 18 小时编码 + 4 小时测试验证

**与审查报告问题映射**：
- P0-3 被动回血硬编码 100 → 1.3.3 修复
- P1-1 商店跳过回合结算 → 4.3.1 修复
- P1-2 realmOrder 硬编码错误 → 4.3.2 修复
- P1-6 cultivation 硬上限 100 → 1.3.2 修复
- P1-8 DeckCombatSystem maxHealth undefined → 3.3.2 增加回退
- P1-9 DeckCombatSystem 忽略 enemy 数据 → 3.3.2 修复
- P1-10 新旧 CombatSystem 事件格式不兼容 → 3.3.3/3.3.4 统一
- P1-11 战斗奖励日志与实物不一致 → 3.3.5 修复
- P1-12 DeckCombatSystem._victory 不发放奖励 → 3.3.2 补充

---

> **下一章预告**：第五章将覆盖 P0/P1/P2 修复清单的完整实施路线图、测试策略和长期架构建议。
