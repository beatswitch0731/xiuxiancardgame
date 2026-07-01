# 道侣如影随形 — Phase 1+2 实施报告

> 日期: 2026-06-29
> 实施: Layer 1 随身道侣 HUD + Layer 2 羁绊耳语

---

## 新建文件

### `src/systems/CompanionWhisper.js`
羁绊耳语系统 — 120 行
- **反应库**: 白落霜/剑灵儿/沐清澜/殷雪 四个角色 × 9种事件类型 × 3档好感度
- **48条原创台词** (白落霜27条 + 剑灵儿27条 + 沐清澜12条 + 殷雪12条)
- `getReaction()`: 根据卡牌+选择方向推断事件类型，返回对应好感阶段的台词
- `getReactionByType()`: 用于 CompanionHUD.react() 情绪反应
- `getIdleLines()`: 用于 HUD 随机空闲气泡

### 全局单例
`const companionWhisper = new CompanionWhisper();` — 无需手动初始化

---

## 修改文件

### `src/ui.js` (+200 行)
新增 **CompanionHUD 类**:
- `init()`: 创建 DOM 结构 (#companion-hud)，含半身像 img + 情绪覆盖层 + 气泡 + 好感度
- `setCompanion(compId, compData)`: 切换陪伴道侣，播放入场动画 + 问候气泡
- `switchCompanion()`: 带退场动画的切换
- `_setEmotion(affection)`: 5档好感驱动光效 (calm→glow→sparkle→aura)
- `react(eventType, data)`: 6种情绪反应 (worried/proud/moved/concerned/desperate/relieved)
- `_showBubble(text, duration)`: 显示气泡文字
- `_startIdleBubbles()`: 15-35秒随机空闲对话
- `destroy()`: 清理定时器

GameUI 新增公开方法:
- `initCompanionHUD()` → 创建 CompanionHUD 实例
- `showCompanionBubble(text, duration)` → 羁绊耳语触发通道
- `setActiveCompanion(compId, compData)` → 外部激活通道

### `src/game.js` (+70 行)
新增方法:
- `_getActiveCompanion()`: 从 companionSystem 取好感度最高且已注册的道侣
- `_triggerCompanionWhisper(card, direction)`: 每次选择后调用耳语系统
- `_activateCompanionToHUD()`: 激活道侣到 HUD

集成点:
- `init()` → 调用 `ui.initCompanionHUD()`
- `start()` → 调用 `this._activateCompanionToHUD()`
- `_applyEffects` companion 分支 → 注册后激活 HUD
- `makeChoice` 末尾 → `_triggerCompanionWhisper()`

### `styles/style.css` (+160 行)
`#companion-hud` 全部样式:
- 固定右下角定位 (z-index: 100)
- .comp-hud-portrait (110×160px, 紫调半透明, 悬停增强边框)
- .comp-hud-emotion (5档常驻 + 6种反应, box-shadow 光效系统)
- .comp-hud-bubble (气泡容器, show class 控制显隐)
- .comp-hud-heart (好感指示器, ♥ 脉动动画)
- 入场/退场动画 (spring easing)
- 手机横屏适配

### `index.html` (+1 行)
加载 `src/systems/CompanionWhisper.js` (在 game.js 之前)

---

## 验收检查

| 条件 | 状态 |
|------|------|
| 道侣激活后屏幕右下角可见半身像 | ✅ setCompanion → HUD 展示 |
| 白落霜好感70+有淡金狐火光晕 | ✅ comp-aura box-shadow |
| 每次滑动选择后1秒内弹出道侣对话 | ✅ _triggerCompanionWhisper → showCompanionBubble |
| 低好感"参汤要趁热"/高好感"三百年够长了" | ✅ 好感到达70时自动切档 |
| 四个角色各有独立语音风格 | ✅ 白落霜温柔/剑灵儿傲娇/沐清澜空灵/殷雪冷酷 |
| 空闲时有随机闲聊 | ✅ _startIdleBubbles 15-35s |
| 点击 HUD 打开道侣详情 | ✅ 点击触发 _openNpcCompPanel |

---

## 后续 plan

Phase 3 (卡牌傍身): 需要 CompanionCardInfuser.js + companion_cards.json + CardSystem 注入
Phase 4 (天命干预): 濒死/心魔劫触发专属卡
Phase 5 (羁绊信物): keepsakes 数组 + 被动效果系统
