# 一念仙途 · 沉浸感交互设计 v2.0

> 核心命题：玩家现在「读卡→按键→看结果」——这是一个"旁观修仙"的体验。
> 我们要把它变成「**我在修仙**」的体验。

---

## §0 当前交互诊断

### 当前交互流（每一步都是问题）

```
[抽卡] → 卡牌出现（纯文本+立绘贴图）
       → 玩家读描述
       → 按方向键/滑动 → 卡牌飞走 → 新卡出现
       → 底部日志追加一行
       → 属性条数字变化
```

### 六大沉浸断点

| # | 断点 | 表现 | 根因 |
|---|------|------|------|
| 1 | **肉身缺席** | 玩家是"操作UI的无名者" | 主角没有任何视觉/文字存在感 |
| 2 | **世界沉默** | 位置变化只发生在数据层 | 有SceneLayerSystem但从未让玩家「感知」身处何方 |
| 3 | **选择太轻** | 四个方向按钮长得一模一样 | 选择的代价在点下去之前不可感知 |
| 4 | **反馈滞后** | 后果沉在日志底部 | 玩家做完选择，要滚动才能看到发生了什么 |
| 5 | **时间静止** | 回合推进只是数字+1 | 没有昼夜、没有季节、没有世界在"流动"的感觉 |
| 6 | **情感缺席** | 日志是纯事实陈述 | 主角没有内心独白，NPC反应只是数据变化 |

---

## §1 五层沉浸框架

```
┌──────────────────────────────────────────────────┐
│ ⑤ 世界律动 — 昼夜/天气/节日让世界"活着"         │
│ ④ 选择重力 — 预感/犹豫/后悔让每次选择有重量     │
│ ③ 肉身在场 — 主角的呼吸/想法/身体变化可感知     │
│ ② 空间存在 — 玩家时刻知道自己"在哪儿"           │
│ ① 即时回响 — 选择的后果在眼前炸开，不沉入日志   │
└──────────────────────────────────────────────────┘
```

---

## §2 层①：即时回响 —— 让后果在眼前炸开

### 问题
目前所有事件后果（修为+5、道心-3）都沉在底部日志，玩家做完选择后需要转移注意力到屏幕最下方。

### 方案：卡面涟漪反馈

**在选择生效的瞬间，直接在卡牌上展示发生了什么：**

```
玩家选择「接受心魔」→ 卡牌短暂暗化
→ 卡面上炸出浮动文字：
   "修为 +5"（金色，上飘）
   "道心 -5"（红色，下坠）
   "恶业 +10"（暗紫色，扩散）
→ 0.8秒后文字消散，卡牌飞离
→ 新卡滑入
```

#### 技术实现

新增 `_showChoiceEcho(effects)` 方法，在 `makeChoice` 中、`_applyEffects` 之后立即调用：

```js
// ui.js 新增
_showChoiceEcho(effects) {
  if (!effects) return;
  const colors = {
    cultivation: { color: '#f0b232', dir: 'up', icon: '⚔' },
    daoHeart:    { color: '#a371f7', dir: 'up', icon: '◈' },
    karmaGood:   { color: '#3fb950', dir: 'up', icon: '◎' },
    karmaBad:    { color: '#f85149', dir: 'down', icon: '◆' },
    fortune:     { color: '#39d0d8', dir: 'up', icon: '✤' },
    health:      { color: '#f85149', dir: 'down', icon: '❤' },
    spiritStone: { color: '#f0b232', dir: 'up', icon: '💎' },
    lifespan:    { color: '#fb8500', dir: 'down', icon: '⏳' },
  };

  const container = this.cardEl;
  for (const [key, value] of Object.entries(effects)) {
    const cfg = colors[key];
    if (!cfg || value === 0 || typeof value !== 'number') continue;
    if (['path','reincarnate','pill','treasure','companion','reincarnation_bonus'].includes(key)) continue;

    const sign = value > 0 ? '+' : '';
    const el = document.createElement('div');
    el.className = 'choice-echo';
    el.textContent = `${cfg.icon || ''} ${sign}${value}`;
    el.style.cssText = `
      position: absolute;
      left: ${40 + Math.random() * 20}%;
      top: ${30 + Math.random() * 20}%;
      color: ${cfg.color};
      font-size: 1.2rem;
      font-weight: 700;
      text-shadow: 0 0 12px ${cfg.color};
      pointer-events: none;
      z-index: 100;
      animation: echo-${cfg.dir} 1.2s ease-out forwards;
    `;
    container.appendChild(el);
    setTimeout(() => el.remove(), 1300);
  }
}
```

#### CSS动画

```css
@keyframes echo-up {
  0%   { opacity: 1; transform: translateY(0) scale(1); }
  100% { opacity: 0; transform: translateY(-60px) scale(1.3); }
}
@keyframes echo-down {
  0%   { opacity: 1; transform: translateY(0) scale(1); }
  100% { opacity: 0; transform: translateY(40px) scale(0.8); }
}
```

**成本**：~40行JS + ~15行CSS。立即见效。

---

## §3 层②：空间存在 —— 让玩家知道「我在哪里」

### 问题
SceneLayerSystem 已经维护了位置数据（宗门/坊市/秘境/洞府/魔域），但玩家完全不知道。位置变化只在后台发生。

### 方案A：位置栏（轻量，立即实施）

在顶栏和卡牌之间，增加一条**位置状态条**：

```html
<div class="location-bar" id="location-bar">
  <span class="loc-icon">🏯</span>
  <span class="loc-name" id="loc-name">青云宗 · 藏经阁</span>
  <span class="loc-mood" id="loc-mood">晨雾未散，青石阶上露水沾衣。</span>
</div>
```

风格极简——半透明底色，融入顶部设计。

**成本**：~30行HTML + ~30行CSS + 10行JS监听位置变化。

### 方案B：卡牌场景背景动态切换（已有基础）

目前 `card.sceneImage` 字段存在但很少使用。应该在每次位置变化时，拉取对应场景图作为卡牌背景。

**成本**：需要补充场景图资源（每个主位置1张图，~5-6张）。

---

## §4 层③：肉身在场 —— 让主角「活着」

### 问题
主角叶凌云是完全隐形的。他的属性变化、他的身体感受、他的内心活动——全都不向玩家展示。结果是：玩家操作一个UI，不是扮演一个人。

### 方案：「心念」系统 —— 主角内心独白

在关键转折点（属性剧烈变化、濒死、突破、遇到重要NPC、善恶大幅变化），在卡牌上短暂展示一段主角的第一人称内心独白。

```
突破失败 →
「丹田里像是有千万根针在扎。我的手在抖——不是怕，是不甘。」

遇到白落霜 →
「她站在月光下，狐耳微动。我突然觉得，修仙这件事，好像也不该是一个人。」

气血<20% →
「血从嘴角渗出来，咸的。我还能往前走吗？能。必须能。」
```

#### 触发规则

| 触发条件 | 心念池 | 概率 |
|----------|--------|------|
| 修为+15以上 | 修行心念 | 70% |
| 道心-10以上 | 挣扎心念 | 80% |
| 善恶变化≥10 | 抉择心念 | 60% |
| 气血<20 | 濒死心念 | 90% |
| 遇到新道侣 | 情感心念 | 100% |
| 突破成功 | 突破心念 | 100% |
| 突破失败 | 挫折心念 | 100% |
| 击杀敌人 | 战斗心念 | 50% |

#### 技术实现

```js
// 新增 src/data/inner_voice.js 或内联到 game.js
const INNER_VOICES = {
  breakthrough_fail: [
    "丹田像碎裂的瓷器。但裂痕里，有金色的光透出来。",
    "又失败了。第三次了。我咬着牙对自己说：第四次，一定成。",
    "疼。但疼说明我还活着。活着的修士，没有放弃的资格。"
  ],
  near_death: [
    "血从嘴角流下来。原来修士的血，也是咸的。",
    "眼前发黑。但我还能看见那条路——那条向上的路。",
    "命悬一线。奇怪的是，我反而不怕了。"
  ],
  meet_companion: [
    "她看我的眼神里有一种说不清的东西。像是……好奇。",
    "原来修仙路上，也会遇见这样的人。会在你转身的时候，跟着你走。"
  ],
  // ...更多心念池
};

// game.js 中在关键变化后调用
_triggerInnerVoice(category) {
  if (this._innerVoiceCooldown > 0) return;
  const voices = INNER_VOICES[category];
  if (!voices || Math.random() > 0.7) return;
  const voice = voices[Math.floor(Math.random() * voices.length)];
  this._log(`「${voice}」`);  // 斜体显示在日志顶部
  this._innerVoiceCooldown = 3; // 冷却3轮
}

// 突破时触发
_resolveBreakthrough(successRate, card) {
  // ...原有逻辑
  if (success) {
    this._triggerInnerVoice('breakthrough_success');
  } else {
    this._triggerInnerVoice('breakthrough_fail');
  }
}
```

**成本**：~200行心念文本 + ~30行触发逻辑。沉浸感提升幅度极大——这是"从0到1"的改变。

---

## §5 层④：选择重力 —— 让每一次滑动都有分量

### 问题
四个方向按钮长得一模一样。不管选什么，UI反馈一样。玩家在两个截然不同的选择之间感受不到区别。

### 方案A：选择预兆闪动

在选择按钮上，给不同后果类型的按钮加上微妙的颜色/动效区分：

| 后果类型 | 按钮光效 | 直觉 |
|----------|----------|------|
| 正面为主（修为+、福缘+） | 金色微光呼吸 | "这个方向有好事" |
| 有代价（道心-、恶业+） | 暗紫/暗红渐隐 | "这个方向有代价" |
| 中性/探索 | 青色微闪 | "这个方向通往未知" |
| 危险/战斗 | 红色边框脉冲 | "这个方向很危险" |

**注意**：不要直接显示具体数值（那样就成攻略了），只传递**情绪色彩**。

#### 实现

在 `renderCard()` 中，根据 `card.choices[dir].effects` 的主导倾向，给按钮添加 `data-mood` 属性：

```js
_choiceMood(effects) {
  if (!effects) return 'neutral';
  let positive = 0, negative = 0;
  for (const [k, v] of Object.entries(effects)) {
    if (['cultivation','fortune','health','daoHeart','karmaGood','spiritStone','lifespan'].includes(k)) {
      if (v > 0) positive += Math.abs(v);
      if (v < 0) negative += Math.abs(v);
    }
    if (k === 'karmaBad' && v > 0) negative += v;
  }
  if (negative > positive * 1.5) return 'danger';
  if (positive > negative * 1.5) return 'blessing';
  if (negative > 0 && positive > 0) return 'tradeoff';
  return 'neutral';
}
```

CSS:
```css
.choice-btn[data-mood="blessing"] .choice-arrow { color: var(--accent-gold); animation: glow-pulse 2s ease-in-out infinite; }
.choice-btn[data-mood="danger"] .choice-arrow { color: var(--accent-red); animation: danger-flicker 3s ease-in-out infinite; }
.choice-btn[data-mood="tradeoff"] .choice-arrow { color: var(--accent-purple); }
```

### 方案B：滑动阻力微调

当前滑动阈值统一80px。不同"重量"的选择可以有不同的视觉阻力：
- 重大选择（突破卡、死亡卡）：滑动时卡牌移动速度×0.7，旋转角度更大 → 感觉"沉重"
- 轻量选择（探索卡）：正常速度 → 感觉"轻快"

**成本**：~20行JS。

---

## §6 层⑤：世界律动 —— 让世界「活着」

### 问题
回合只是数字+1。没有时间流逝的感觉。

### 方案A：时辰系统（轻量）

基于回合数模拟时辰循环。每6轮切换一次时辰，影响CSS全局色调：

```
子时(0-6轮)  → 背景偏蓝黑，月光色 #1a1a3a
卯时(6-12轮) → 背景偏青灰，晨光色 #1a2a2a
午时(12-18轮)→ 背景偏金黄，正午色 #2a2a1a
酉时(18-24轮)→ 背景偏暖橙，黄昏色 #2a1a1a
```

实现：
```css
:root[data-time="子时"] { --bg-dark: #0a0c14; --bg-panel: #111420; --bg-card: #181c2a; }
:root[data-time="卯时"] { --bg-dark: #0c1414; --bg-panel: #141c1c; --bg-card: #1a2424; }
:root[data-time="午时"] { --bg-dark: #14140c; --bg-panel: #1c1c14; --bg-card: #24241a; }
:root[data-time="酉时"] { --bg-dark: #140c0c; --bg-panel: #1c1414; --bg-card: #241a1a; }
```

**成本**：~30行CSS + 10行JS更新 `document.documentElement.dataset.time`。

### 方案B：节气/月相（进阶，后续迭代）

基于总轮数循环更长的周期（如30轮一个月相），影响某些卡牌的出现概率、集市价格等。

### 方案C：世界事件公告

每隔若干轮，在日志中插入一条"天下大事"——和玩家当前行动无关，但让世界感觉更大：

```
第24轮 → 「东海传来消息：龙宫开启万年一度的龙门大会。」
第48轮 → 「西荒传出异动：魔尊第七子破封而出。」
```

这些消息成为后续因果种子的铺垫。配合 `KarmaSeedSystem` 的延时触发。

---

## §7 优先级与实施路线

| 优先级 | 特性 | 代码量 | 沉浸提升 | 推荐先做 |
|--------|------|--------|----------|----------|
| **P0** | 卡面涟漪反馈 | ~40JS+15CSS | ⭐⭐⭐⭐⭐ | ✅ 立即 |
| **P0** | 心念系统 | ~200文本+30JS | ⭐⭐⭐⭐⭐ | ✅ 立即 |
| **P1** | 选择预兆闪动 | ~30JS+30CSS | ⭐⭐⭐⭐ | |
| **P1** | 位置栏 | ~30HTML+30CSS+10JS | ⭐⭐⭐ | |
| **P1** | 时辰系统 | ~30CSS+10JS | ⭐⭐⭐ | |
| **P2** | 滑动阻力 | ~20JS | ⭐⭐ | |
| **P2** | 世界事件 | ~100文本+20JS | ⭐⭐⭐ | |

---

## §8 关键原则

### 1. 减法优先于加法
> 沉浸 ≠ 更多UI元素。沉浸 = 让现有元素"消失"进世界里。
> 好的沉浸设计是：玩家忘了自己在操作UI。

### 2. 文字是修仙游戏的第一感官
> 没有3D场景、没有立体声——文字就是一切。
> 每一行日志、每一段描述、每一个选择文案，都必须是"修仙世界里的文字"，
> 而不是"游戏说明书里的文字"。

### 3. 后果必须可见、可感
> "修为+5" → 玩家看到的是数字。
> "一缕灵气从丹田升起，经脉微微发热。修为+5" → 玩家感受到的是体验。
> 数值变化永远是配菜，感官描述才是主菜。

### 4. 主角必须先"活过来"
> 所有沉浸设计的前提：玩家必须感觉自己扮演的是一个**有血有肉的人**，
> 而不是一个操作属性面板的会计。
> 心念系统的优先级高于一切视觉特效——因为文字才是情感的载体。

---

## §9 不要做的事

1. ❌ 不要加复杂的动画系统——CSS animation 足以覆盖 90% 需求
2. ❌ 不要为沉浸而加"教程式引导"——沉浸的前提是自由
3. ❌ 不要用AI生成所有心念文本——3-5条手写 > 50条AI
4. ❌ 不要让时辰/天气影响核心数值——它是氛围层，不是策略层
5. ❌ 不要在手机上做触觉反馈——web haptic API 兼容性太差

---

*v2.0 — 2026-06-29*
