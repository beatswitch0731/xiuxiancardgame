# 道侣如影随形沉浸系统 — 设计文档

> **目标**: 让道侣不再是"面板里的数字"，而是"屏幕里活着的存在"
> **三个关键词**: 如影随形（视觉常驻）· 卡牌傍身（机械绑定）· 身临其境（情感反馈）

---

## 现状诊断

| 维度 | 已有 | 缺失 |
|------|------|------|
| 数据 | 5阶段弧线 + 秘密揭示 + 劫难高潮 + 天命终章 | — 数据质量极高 |
| 引擎 | CompanionArcEngine 好感/羁绊/信任追踪 | 无主动推送机制 |
| UI | 面板弹窗 + 万物志 + 立绘阶段查看器 | **无常驻视觉存在** |
| 卡牌 | 阶段事件通过 _narrativeQueue 注入 | **无道侣专属卡牌** |
| 反馈 | eventBus emit → game.js 监听 | **道侣从不对玩家的选择做出反应** |
| 氛围 | 无 | **无环境对话、无动画、无特效** |

**结论**: 道侣系统有骨架有血肉——但缺少"呼吸"。玩家只有在偶然抽到道侣事件卡时才意识到她的存在，其余时间她是沉默的、不可见的。

---

## 五层沉浸架构

```
┌─────────────────────────────────────────────────┐
│  Layer 5: 羁绊信物 (Keepsake System)             │  ← 最深绑定
│  道侣赠予的实物在角色界面可见，携带即生效         │
├─────────────────────────────────────────────────┤
│  Layer 4: 天命干预 (Intervention)                │  ← 剧情高光
│  濒死/重大抉择时道侣介入，专属演出卡              │
├─────────────────────────────────────────────────┤
│  Layer 3: 卡牌傍身 (Card Infusion)               │  ← 机械绑定
│  道侣专属卡牌混入抽牌池，卡面含道侣元素           │
├─────────────────────────────────────────────────┤
│  Layer 2: 羁绊耳语 (Companion Whisper)           │  ← 情感反馈
│  每次滑动选择后道侣实时评论，好感驱动语气变化      │
├─────────────────────────────────────────────────┤
│  Layer 1: 随身道侣 (Companion HUD)               │  ← 视觉常驻
│  屏幕角落道侣半身像，呼吸动画，情绪变化           │
└─────────────────────────────────────────────────┘
```

---

## Layer 1: 随身道侣 (Companion HUD)

### 概念
屏幕右下角（或左下角，不遮挡主卡牌区）一个**半透明的道侣半身像**。她总是在那里——不是在弹窗里等你点开，而是在你每一次抽卡、每一次选择时都在你身边。

### 视觉设计

```
┌──────────────────────────────────────────┐
│                                          │
│         主卡牌区域                        │
│                                          │
│                              ┌────┐      │
│                              │    │      │
│                              │ 道 │      │  ← 道侣半身像
│                              │ 侣 │      │    120×180px
│                              │ 立 │      │    半透明底
│                              │ 绘 │      │
│                              │    │      │
│                              └────┘      │
│                         "今天参汤..."     │  ← 气泡对话
│                              ♥ 78       │  ← 好感度
└──────────────────────────────────────────┘
```

### 具体实现

```javascript
// src/ui.js — CompanionHUD 类

class CompanionHUD {
  constructor() {
    this.container = null;     // DOM 容器
    this.portraitEl = null;    // 立绘元素
    this.bubbleEl = null;      // 气泡文字
    this.heartEl = null;       // 好感指示器
    this.activeCompId = null;  // 当前陪伴的道侣
    this._idleTimer = null;    // 空闲气泡计时器
    this._emotion = 'calm';    // 当前情绪
  }

  /** 初始化 DOM — 在 game.init() 时调用 */
  init() {
    this.container = document.createElement('div');
    this.container.id = 'companion-hud';
    this.container.innerHTML = `
      <div class="comp-hud-portrait">
        <canvas id="comp-hud-canvas" width="120" height="180"></canvas>
        <div class="comp-hud-emotion" id="comp-hud-emotion"></div>
      </div>
      <div class="comp-hud-bubble" id="comp-hud-bubble"></div>
      <div class="comp-hud-heart" id="comp-hud-heart">
        <span class="comp-hud-heart-icon">♥</span>
        <span class="comp-hud-heart-val" id="comp-hud-heart-val">0</span>
      </div>
    `;
    document.body.appendChild(this.container);
    this.container.style.display = 'none'; // 初始隐藏
  }

  /** 设置当前陪伴的道侣 */
  setCompanion(compId, compData) {
    this.activeCompId = compId;
    this.container.style.display = 'flex';

    // 加载道侣立绘到 canvas
    this._loadPortrait(compId);

    // 根据好感度设置情绪
    const affection = compData.affection || 0;
    this._setEmotion(affection);

    // 更新好感指示器
    document.getElementById('comp-hud-heart-val').textContent = affection;

    // 播放入场动画
    this.container.classList.add('comp-hud-enter');
    setTimeout(() => this.container.classList.remove('comp-hud-enter'), 600);

    // 启动空闲气泡
    this._startIdleBubbles(compId, compData);
  }

  /** 更换陪伴的道侣 — 带过渡动画 */
  switchCompanion(newCompId, newCompData) {
    this.container.classList.add('comp-hud-exit');
    setTimeout(() => {
      this.setCompanion(newCompId, newCompData);
    }, 400);
  }

  /** 情绪系统 — 根据好感度 + 事件驱动 */
  _setEmotion(affection) {
    let emotion, animClass;
    if (affection < 20)  { emotion = 'distant'; animClass = 'comp-calm'; }
    else if (affection < 40) { emotion = 'curious'; animClass = 'comp-calm'; }
    else if (affection < 60) { emotion = 'warm'; animClass = 'comp-glow'; }
    else if (affection < 80) { emotion = 'devoted'; animClass = 'comp-sparkle'; }
    else { emotion = 'soulbound'; animClass = 'comp-aura'; }

    this._emotion = emotion;
    document.getElementById('comp-hud-emotion').className = `comp-hud-emotion ${animClass}`;
  }

  /** 触发情绪反应 — 由外部事件调用 */
  react(eventType, data) {
    const reactions = {
      'player_hurt': { emotion: 'worried',  duration: 3000 },
      'breakthrough': { emotion: 'proud',   duration: 5000 },
      'dao_heart_gain': { emotion: 'moved',  duration: 4000 },
      'karma_bad': { emotion: 'concerned', duration: 4000 },
      'death_near': { emotion: 'desperate',duration: 0 }, // 直到玩家脱离危险
      'combat_victory':{ emotion: 'relieved',duration: 3000 },
    };

    const reaction = reactions[eventType];
    if (!reaction) return;

    // 更新情绪动画
    document.getElementById('comp-hud-emotion').className =
      `comp-hud-emotion comp-${reaction.emotion}`;

    // 显示反应气泡
    const lines = this._getReactionLine(eventType, data);
    if (lines) this._showBubble(lines);

    // 定时恢复
    if (reaction.duration > 0) {
      clearTimeout(this._reactTimer);
      this._reactTimer = setTimeout(() => {
        this._setEmotion(data?.affection || this._lastAffection || 50);
      }, reaction.duration);
    }
  }

  /** 空闲时随机冒泡 */
  _startIdleBubbles(compId, compData) {
    const idleLines = this._getIdleLines(compId, compData);
    const cycle = () => {
      const line = idleLines[Math.floor(Math.random() * idleLines.length)];
      this._showBubble(line);
      this._idleTimer = setTimeout(cycle, 15000 + Math.random() * 20000);
    };
    cycle();
  }

  /** 获取空闲对话 — 按好感阶段不同 */
  _getIdleLines(compId, compData) {
    const aff = compData.affection || 0;
    const lines = {
      bai_luoxuan: {
        low:  ['参汤要趁热……', '今天的药采好了。', '洞府的风有点凉。'],
        mid:  ['你修炼时我就在旁边。', '今天的参汤多放了枸杞。', '你的灵气比昨天更稳了。'],
        high: ['道侣——月亮出来了。', '我的尾巴有点痒。', '三百年——够长了。'],
      },
      jian_linger: {
        low:  ['剑冢的风还是那么冷。', '…………', '出剑再快一点。'],
        mid:  ['今天的剑路——还行。', '我不是在等你。', '你出剑慢了半拍。'],
        high: ['冰心剑意——原来是暖的。', '别走太远。', '我在剑冢等你。'],
      },
    };

    const charLines = lines[compId] || { low: ['……'], mid: ['……'], high: ['……'] };
    if (aff < 40) return charLines.low;
    if (aff < 70) return charLines.mid;
    return charLines.high;
  }
}
```

### CSS

```css
/* companion-hud — 随身道侣 */
#companion-hud {
  position: fixed;
  bottom: 20px;
  right: 20px;
  z-index: 100;
  display: flex;
  flex-direction: column;
  align-items: center;
  pointer-events: none;
  opacity: 0.85;
  transition: opacity 0.5s;
}

.comp-hud-portrait {
  position: relative;
  width: 120px;
  height: 180px;
  border-radius: 8px;
  overflow: hidden;
  background: linear-gradient(135deg, rgba(30,10,40,0.6), rgba(10,5,20,0.8));
  border: 1px solid rgba(180,140,220,0.3);
  box-shadow: 0 0 20px rgba(150,100,200,0.15);
}

.comp-hud-portrait canvas {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

/* 情绪光效层 */
.comp-hud-emotion {
  position: absolute;
  inset: 0;
  pointer-events: none;
  transition: all 0.8s ease;
}

.comp-hud-emotion.comp-calm    { box-shadow: inset 0 0 0 transparent; }
.comp-hud-emotion.comp-glow    { box-shadow: inset 0 0 20px rgba(255,200,220,0.2); }
.comp-hud-emotion.comp-sparkle { box-shadow: inset 0 0 30px rgba(255,180,200,0.3); }
.comp-hud-emotion.comp-aura    {
  box-shadow: 0 0 25px rgba(200,150,255,0.3), inset 0 0 20px rgba(255,200,240,0.2);
}

/* 情绪反应动画 */
.comp-hud-emotion.comp-worried   { box-shadow: inset 0 0 25px rgba(255,100,100,0.3); }
.comp-hud-emotion.comp-proud     { box-shadow: 0 0 30px rgba(255,215,0,0.4); }
.comp-hud-emotion.comp-moved     { box-shadow: inset 0 0 25px rgba(255,180,200,0.3); }
.comp-hud-emotion.comp-concerned { box-shadow: inset 0 0 20px rgba(100,100,255,0.25); }
.comp-hud-emotion.comp-desperate { box-shadow: inset 0 0 40px rgba(255,50,50,0.5); }
.comp-hud-emotion.comp-relieved  { box-shadow: inset 0 0 25px rgba(100,255,150,0.2); }

/* 气泡 */
.comp-hud-bubble {
  max-width: 180px;
  padding: 6px 12px;
  margin-top: 8px;
  background: rgba(20,10,30,0.85);
  border: 1px solid rgba(180,140,220,0.3);
  border-radius: 12px;
  color: #e0d0f0;
  font-size: 12px;
  text-align: center;
  opacity: 0;
  transform: translateY(5px);
  transition: all 0.4s ease;
}

.comp-hud-bubble.show {
  opacity: 1;
  transform: translateY(0);
}

/* 好感度 */
.comp-hud-heart {
  display: flex;
  align-items: center;
  gap: 4px;
  margin-top: 4px;
  font-size: 11px;
  color: rgba(255,150,180,0.8);
}

.comp-hud-heart-icon {
  font-size: 14px;
  animation: heartPulse 2s ease-in-out infinite;
}

@keyframes heartPulse {
  0%, 100% { transform: scale(1); }
  50% { transform: scale(1.2); }
}

/* 入场/退场 */
.comp-hud-enter { animation: compHudIn 0.6s ease-out; }
.comp-hud-exit  { animation: compHudOut 0.4s ease-in; }
@keyframes compHudIn  { from { opacity: 0; transform: translateX(30px); } }
@keyframes compHudOut { to   { opacity: 0; transform: translateX(30px); } }
```

---

## Layer 2: 羁绊耳语 (Companion Whisper)

### 概念
**每次玩家滑动选择后**，道侣对选择做出评论。不是系统提示——是她作为一个人对你的选择产生了反应。

### 触发时机
```
玩家滑动选择 → game._applyChoice() → CompanionWhisper.reactToChoice()
```

### 实现设计

```javascript
// src/systems/CompanionWhisper.js

class CompanionWhisper {
  constructor() {
    /** 反应库 — 按道侣 × 事件类型 × 好感阶段 */
    this._reactionDB = {
      bai_luoxuan: {
        // 类型: [低好感(0-40), 中好感(40-70), 高好感(70+)]
        heal: [
          '你受伤了？我回去熬药。',
          '参汤一直在灶上温着。',
          '以后受伤——先告诉我。',
        ],
        cultivate: [
          '修炼时注意经脉。',
          '你的灵气越来越稳了。',
          '道侣修炼的样子——很好看。',
        ],
        kill: [
          '……那个人必须死吗？',
          '你是对的。但下次让我帮忙。',
          '杀便杀了。天道不记这一笔——我替你记。',
        ],
        save: [
          '你救了人。',
          '你是好人——我一直知道。',
          '三百年后——世人会记得你做过什么。',
        ],
        breakthrough: [
          '恭喜。',
          '你的修为又进一步了。',
          '道侣——我为你高兴。真的。',
        ],
        dao_heart_gain: [
          '道心坚定是好事。',
          '你的道——越来越清晰了。',
          '你选的每条路——我都跟随。',
        ],
        karma_bad: [
          '你……做了什么？',
          '天道在看着。',
          '不管怎样——我站在你这边。',
        ],
        death_near: [
          '不行！',
          '你不能死——参汤还没喝完。',
          '你答应过我的——三百年不够！',
        ],
      },
      jian_linger: {
        heal: [
          '这点伤就喊疼？',
          '下次躲快点。',
          '……疼的话就说。',
        ],
        cultivate: [
          '今天的剑路还行。',
          '修炼认真点——别偷懒。',
          '你进步了——别得意。',
        ],
        kill: [
          '干净利落——不错。',
          '这种人不值得你脏剑。',
          '杀就杀了。剑不会犹豫——你也不许。',
        ],
        save: [
          '……多管闲事。',
          '救人值得。但别逞强。',
          '你心软的样子——也不算难看。',
        ],
        breakthrough: [
          '哼——还行。',
          '突破就好。别骄傲。',
          '（嘴角压不住地上扬）恭喜。',
        ],
        dao_heart_gain: [
          '道心这种东西——自己悟。',
          '你的道——比我的锋利。',
          '剑道同归。我不会走——你也不许。',
        ],
        karma_bad: [
          '你想清楚了？',
          '天道在算账——你算得过它？',
          '做都做了——别后悔。后悔没用。',
        ],
        death_near: [
          '你敢！',
          '我还没赢够——你不准死。',
          '（拔剑）天道——你敢动他试试。',
        ],
      },
    };
  }

  /** 根据选择标签推断事件类型 */
  _inferEventType(card, choiceDir) {
    const effects = choiceDir === 'left' ? card.leftEffects : card.rightEffects;
    if (!effects) return 'neutral';

    if (effects.hp || effects.health > 0) return 'heal';
    if (effects.cultivation > 0) return 'cultivate';
    if (effects.karmaBad > 0) return 'karma_bad';
    if (effects.karmaGood > 0) return 'save';
    if (effects.daoHeart > 10) return 'dao_heart_gain';
    if (card.type === 'BREAKTHROUGH' || card.tags?.includes('breakthrough')) return 'breakthrough';

    return 'neutral';
  }

  /** 获取反应文本 */
  getReaction(compId, card, choiceDir, affection) {
    const eventType = this._inferEventType(card, choiceDir);
    const charDB = this._reactionDB[compId];
    if (!charDB) return null;

    const typeLines = charDB[eventType];
    if (!typeLines) return null;

    const tier = affection < 40 ? 0 : affection < 70 ? 1 : 2;
    return typeLines[tier] || null;
  }
}
```

### 集成方式

在 `game.js` 的 `_applyChoice()` 末尾加入：

```javascript
// 道侣耳语 — 每次选择后触发
const activeComp = companionSystem?.getActiveCompanion();
if (activeComp && window.companionWhisper) {
  const reaction = companionWhisper.getReaction(
    activeComp.id, this.currentCard, dir,
    activeComp.affection || 0
  );
  if (reaction) {
    // 气泡显示3秒
    ui.showCompanionBubble(reaction, 3000);
    // 同步到 HUD
    if (ui.companionHUD) {
      ui.companionHUD.react(this._inferReactionType(this.currentCard, dir), {
        affection: activeComp.affection
      });
    }
  }
}
```

---

## Layer 3: 卡牌傍身 (Companion Card Infusion)

### 概念
当道侣关系达到一定阶段，**道侣专属卡牌**会混入抽卡池。这些卡不是"弹出道侣面板"——而是实实在在的卡牌，带着道侣的印记和加成。

### 专属卡牌设计

#### 白落霜 — 系列: "狐影随行"

```json
{
  "id": "comp_bai_heal",
  "type": "COMPANION",
  "title": "白落霜 · 参汤",
  "description": "白落霜不知何时又熬好了一碗参汤。碗边贴着一张纸条——\\n\\n'趁热。凉了伤胃。'",
  "realm": "QI_REFINING",
  "tags": ["companion", "heal", "bai_luoxuan"],
  "minAffection": 40,
  "leftText": "喝下参汤",
  "leftEffects": { "health": 15, "daoHeart": 3 },
  "rightText": "留给她喝",
  "rightEffects": { "health": 5, "daoHeart": 8, "companionAffection": 10 },
  "companionIcon": "🦊",
  "companionId": "bai_luoxuan"
}
```

```json
{
  "id": "comp_bai_foxfire",
  "type": "COMPANION",
  "title": "白落霜 · 狐火引路",
  "description": "南疆深处的迷阵困住了你的神识。忽然——一团淡蓝的狐火在你前方三丈亮起。\\n\\n是她的气息。她找不到你——但她的狐火找到了。",
  "realm": "FOUNDATION",
  "tags": ["companion", "explore", "bai_luoxuan"],
  "minAffection": 60,
  "leftText": "跟随狐火",
  "leftEffects": { "cultivation": 10, "fortune": 15, "daoHeart": 5 },
  "rightText": "以自己的神识硬闯",
  "rightEffects": { "cultivation": 15, "daoHeart": 10, "health": -5 },
  "companionIcon": "🦊",
  "companionId": "bai_luoxuan"
}
```

```json
{
  "id": "comp_bai_tail",
  "type": "COMPANION",
  "title": "白落霜 · 九尾暖意",
  "description": "闭关第七天——寒气侵体。你的经脉开始冻结。\\n\\n忽然——一条半透明的白色尾巴从虚空中探出，轻轻搭在你的手腕上。温暖的妖力沿着你的灵脉流淌——不是外来的力量，是她的。\\n\\n她在三千里外的洞府，把本命妖力送过来了。",
  "realm": "GOLDEN_CORE",
  "tags": ["companion", "rescue", "bai_luoxuan"],
  "minAffection": 80,
  "leftText": "接受她的妖力",
  "leftEffects": { "health": 30, "cultivation": 10, "daoHeart": 15, "companionAffection": 5 },
  "rightText": "拒绝——不想让她消耗",
  "rightEffects": { "health": -10, "daoHeart": 20, "companionAffection": 15 },
  "companionIcon": "🦊",
  "companionId": "bai_luoxuan"
}
```

#### 剑灵儿 — 系列: "剑心相随"

```json
{
  "id": "comp_jian_spar",
  "type": "COMPANION",
  "title": "剑灵儿 · 晨练",
  "description": "鸡鸣时分——剑冢已经传来剑鸣。\\n\\n剑灵儿在练剑。但她今天的剑路很慢——慢到你能看清每一式的变化。\\n\\n'别多想。'她头也不回地说，'我只是状态不好。'\\n\\n但她的耳朵红了。",
  "realm": "QI_REFINING",
  "tags": ["companion", "cultivate", "jian_linger"],
  "minAffection": 40,
  "leftText": "拔剑陪练",
  "leftEffects": { "cultivation": 12, "daoHeart": 5 },
  "rightText": "安静观看",
  "rightEffects": { "cultivation": 5, "daoHeart": 8, "companionAffection": 8 },
  "companionIcon": "❄️",
  "companionId": "jian_linger"
}
```

### 注入机制

在 `CardSystem.draw()` 的优先级链中加入：

```javascript
// 优先级 25: 道侣卡牌注入（低于战斗/突破/死亡，高于普通抽卡）
const compCard = this._checkCompanionInfusion();
if (compCard) {
  this._lastDrawnPriority = 25;
  return compCard;
}
```

`_checkCompanionInfusion()` 逻辑：
1. 取当前激活道侣的 affection
2. 扫描 COMPANION 类型卡牌，筛选 `minAffection <= currentAffection`
3. 按 15% 概率注入（保证不是每次都出，保持惊喜感）
4. 每种道侣卡内置冷却（抽过后 8 轮内不再重复）

---

## Layer 4: 天命干预 (Companion Intervention)

### 概念
最高羁绊阶段（SOUL_BOND + DESTINY）时，在特定极端情况下——濒死、堕入魔道、飞升天劫——道侣可以**主动介入**，从抽卡优先队列中插入一张专属的"天命干预卡"。

### 触发条件

| 触发场景 | 条件 | 冷却 |
|----------|------|------|
| 生命值 < 15% | affection ≥ 80, bond ≥ 3 | 30轮 |
| karmaBad 突破 50 | affection ≥ 70 | 一次 |
| 心魔劫失败 | affection ≥ 85 | 每次飞升 |
| 飞升之门前最后一卡 | 所有道侣中 affection 最高者 | 一次 |

### 白落霜 — 天命干预卡

```json
{
  "id": "comp_intervene_bai_death",
  "type": "COMPANION_INTERVENE",
  "priority": 95,
  "title": "白落霜 · 以命相护",
  "description": "你倒下的瞬间——一道白影掠过。\\n\\n白落霜挡在你身前。她的九条尾巴全部展开——不是平时的半透明，是燃烧的白色火焰。\\n\\n'天道——我白狐部欠他九世因果。你想动他——先从我身上踏过去。'\\n\\n她的本命妖丹从胸口浮出——这是在燃烧长生。",
  "leftText": "伸手抱住她——'够了'",
  "leftEffects": { "health": 40, "daoHeart": 25, "karmaGood": 20 },
  "rightText": "强行把她推到身后——直面天道",
  "rightEffects": { "health": -20, "daoHeart": 35, "karmaGood": 25, "cultivation": 20 },
  "companionEffects": { "bai_luoxuan": { "affectionDelta": 30, "longevityCost": "百年" } }
}
```

---

## Layer 5: 羁绊信物 (Keepsake System)

### 概念
道侣在关键阶段会赠予**信物**——不是消耗品，是角色界面上永远可见的物品。每件信物有独立的故事和被动效果。

### 信物设计

| 道侣 | 阶段 | 信物 | 效果 | 描述 |
|------|------|------|------|------|
| 白落霜 | SOUL_BOND | 狐牙项链 | HP回复+3/轮, 毒抗+30% | "白狐一辈子只有一颗本命狐牙。" |
| 白落霜 | DESTINY | 九世婚契 | 道心+20, 幸运+15 | "画了这个——你就是我九辈子的夫君。" |
| 剑灵儿 | SOUL_BOND | 冰心剑穗 | 冰系伤害+20%, 闪避+10% | "她悄悄系在你剑上的——假装不是她。" |
| 剑灵儿 | DESTINY | 同归剑誓 | 道心+25, 修炼+15 | "剑道同归——我不会走。" |

### 实现

```javascript
// game.js — GameStateManager 中的 keepsakes 数组
this.state.resources.keepsakes = [
  {
    id: 'fox_tooth_necklace',
    name: '狐牙项链',
    from: 'bai_luoxuan',
    stage: 'SOUL_BOND',
    acquiredAt: null,      // 获得时的游戏轮数
    effects: { hpRegen: 3, poisonResist: 30 },
    description: '白狐一辈子只有一颗本命狐牙。',
    icon: '🦊💎',
  },
  // ...
];

// 信物被动效果在 _triggerUpdate() 中计算：
_applyKeepsakeEffects() {
  for (const ks of (this.state.resources.keepsakes || [])) {
    if (!ks.acquiredAt) continue;
    for (const [key, val] of Object.entries(ks.effects)) {
      this.state[key] = (this.state[key] || 0) + val;
    }
  }
}
```

信物在万物志和角色界面中展示，获得时有专属演出卡。

---

## 完整集成方案

### 事件流

```
玩家滑动选择
    │
    ├─► game._applyChoice() 应用效果
    │       │
    │       ├─► CompanionWhisper.reactToChoice()  → 道侣耳语气泡
    │       ├─► CompanionHUD.react()              → 道侣情绪动画
    │       └─► CompanionArcEngine.onAffectionChanged() → 好感变化
    │
    ├─► game.getCurrentCard() 抽下一张
    │       │
    │       ├─► 优先100: 死亡卡
    │       ├─► 优先95:  天命干预卡 ← NEW
    │       ├─► 优先90:  突破卡
    │       ├─► 优先50:  上瘾引擎
    │       ├─► 优先31:  NPC交叉事件
    │       ├─► 优先25:  道侣注入卡 ← NEW
    │       ├─► 优先20:  叙事队列
    │       └─► 优先0:   普通抽卡
    │
    └─► ui.renderCard()
            │
            ├─► COMPANION 类型 → 特殊渲染（道侣立绘 + 专属光效）
            ├─► COMPANION_INTERVENE 类型 → 全屏演出渲染
            └─► 普通卡 → 标准渲染（但 HUD 仍然显示道侣存在）
```

### 需要新建的文件

```
src/systems/CompanionWhisper.js    — 道侣耳语反应库
src/systems/CompanionCardInfuser.js — 道侣卡牌注入器
data/cards/companion_cards.json    — 道侣专属卡牌数据（10-12张）
```

### 需要修改的文件

```
src/ui.js        — 添加 CompanionHUD 类 + whisper bubble 方法
src/game.js      — draw() 注入优先级 + _applyChoice() 耳语触发
src/systems/CardSystem.js — _checkCompanionInfusion() + COMPANION 类型处理
styles/style.css  — #companion-hud 全部样式 + .comp-hud-* 动画
index.html        — DATA_MODULES 注册 companion_cards 模块
```

---

## 实施优先级

| 阶段 | 内容 | 工作量 | 沉浸提升 |
|------|------|--------|----------|
| **Phase 1** | Layer 1 随身道侣 HUD | ~200行 JS + ~100行 CSS | ★★★★ |
| **Phase 2** | Layer 2 羁绊耳语 | ~150行 JS (反应库) | ★★★★★ |
| **Phase 3** | Layer 3 卡牌傍身 | ~100行 JS + 10张卡数据 | ★★★★ |
| **Phase 4** | Layer 4 天命干预 | ~80行 JS + 2-4张卡数据 | ★★★ |
| **Phase 5** | Layer 5 羁绊信物 | ~100行 JS + 信物数据 | ★★★ |

**建议**: Phase 1+2 同时做——视觉常驻和情感反馈是"如影随形"的核心。做完这两层，道侣就不再是面板里的数字了。

---

## 验收标准

- [ ] 所有道侣在激活后，屏幕右下角能看到她们的半身像
- [ ] 白落霜好感70+时，立绘周围有淡金色狐火光晕
- [ ] 玩家每次滑动选择后，对应的道侣会在1秒内弹出对话气泡
- [ ] 低好感时白落霜说"参汤要趁热"，高好感时说"三百年——够长了"——同一事件不同好感有不同语气
- [ ] 好感40+时抽卡池中出现道侣专属卡，卡面有道侣立绘和专属标签
- [ ] 濒死时道侣不沉默——有专属的焦虑/愤怒/劝阻反应
- [ ] SOUL_BOND 阶段获得信物后，角色界面能看到该信物并享受被动加成
