# 第二章 · 玩家体验优化

> **文档版本**: v1.0
> **编写日期**: 基于 2026-07-14 审查报告 v2.0
> **适用范围**: HTML5 修仙卡牌决策游戏《一念仙途》
> **关联文件**: `src/ui.js`、`src/game.js`、`index.html`、`src/core/GameStateManager.js`、`src/systems/FlowDirector.js`、`src/systems/CardSystem.js`、`src/systems/KarmaSystem.js`

---

## 一、目标系统重构

### 1.1 问题诊断

当前游戏存在一个核心体验问题：**玩家不知道"现在该做什么"**。

打开游戏主界面后，玩家看到的是：
- 顶部一排 badge（境界、章节、功法、阶段）
- 6 个属性条 + 灵石 + 寿元 + 回合数
- 一张事件卡和两个选项

这些信息虽然齐全，但缺乏一个**明确的、可执行的当前目标**。玩家只能凭感觉选左或选右，不知道选哪个能让自己"更接近胜利"。

**代码证据**：

```javascript
// src/ui.js:326-375 renderTopBar()
// 当前 top-bar 显示内容：
// - 玩家名 + 境界名
// - 章节进度（如果 chapterSystem 已初始化）
// - FlowDirector 阶段
// - 功法名
// - 灵石、寿元、回合数
// - 支线状态
// 但没有"当前目标"提示
```

`_renderBreakthroughBar`（`ui.js:421`）虽然显示了突破进度条，但它只显示百分比数字，没有告诉玩家"你当前修为 45/100，还需要 55 点修为才能突破"这样的明确目标。

**玩家反馈映射**："玩得莫名其妙，不知道在玩什么" → 首要原因就是**目标感缺失**。

### 1.2 优化方案

#### 1.2.1 顶部 HUD 增加"当前目标"面板

在 `top-bar` 区域增加一个动态目标提示，根据玩家当前状态智能推荐下一步行动：

| 玩家状态 | 目标提示 |
|---------|---------|
| cultivation < threshold × 0.5 | "积累修为，探索修仙之路" |
| cultivation >= threshold × 0.5 | "修为渐满，准备突破境界" |
| cultivation >= threshold × 0.9 | "突破在即！寻找突破契机" |
| health <= 20 | "⚠ 气血危急，优先恢复" |
| daoHeart <= 20 | "⚠ 道心不稳，谨防心魔" |
| lifespan <= 20 | "⚠ 寿元将尽，寻求延寿之法" |
| 有进行中的支线 | "支线进行中：{支线名}" |

#### 1.2.2 突破进度条视觉优化

- **渐变色彩**：低进度（0-30%）用淡蓝色，中进度（30-70%）用青色，高进度（70-90%）用紫色，临界（90-100%）用金色 + 脉冲动画
- **里程碑标记**：在 25%/50%/75% 位置添加小刻度标记
- **百分比显示**：当前 "45%" 改为 "修为 45/100（45%）"
- **下一境界名称**："🔥 筑基突破进度" → "🔥 距筑基期还差 55 修为"

#### 1.2.3 境界突破时全屏反馈

当前突破只是属性变化 + 日志输出，缺乏仪式感。优化方案：

- 全屏暗化 + 金色粒子动画（CSS animation）
- 居中大字："炼气圆满，气旋液化，筑基初成！"
- 播放音效（Web Audio API 生成简单音效作为 fallback）
- 显示突破后的新能力/新解锁内容

### 1.3 具体实现

#### 修改 1：`src/ui.js` — 增加目标提示元素

```javascript
// 在 cacheElements() 中增加目标提示元素（约 ui.js:193 行后）
this.topGoal = document.getElementById('top-goal');

// 在 renderTopBar() 中增加目标提示渲染（约 ui.js:364 行后）
this._renderGoalHint();
```

```javascript
/**
 * 渲染当前目标提示
 * 根据玩家状态动态推荐下一步行动
 */
_renderGoalHint() {
  if (!this.topGoal) return;
  
  const goal = this._computeCurrentGoal();
  this.topGoal.textContent = goal.text;
  this.topGoal.className = `badge goal goal-${goal.priority}`;
  this.topGoal.style.display = 'inline-block';
}

/**
 * 计算当前目标
 * @returns {{text: string, priority: string}}
 */
_computeCurrentGoal() {
  const cultivation = gameState.attributes.cultivation || 0;
  const realmConfig = gameState.config.realms 
    ? (gameState.config.realms.realms || {})[gameState.realm] 
    : null;
  const threshold = realmConfig ? realmConfig.cultivationThreshold : 100;
  const pct = cultivation / threshold;
  
  const health = gameState.attributes.health || 0;
  const daoHeart = gameState.attributes.daoHeart || 0;
  const lifespan = gameState.resources.lifespan || 0;
  
  // 危险状态优先
  if (health <= 20) return { text: '⚠ 气血危急，优先恢复', priority: 'critical' };
  if (daoHeart <= 20) return { text: '⚠ 道心不稳，谨防心魔', priority: 'critical' };
  if (lifespan <= 20) return { text: '⚠ 寿元将尽，寻求延寿之法', priority: 'critical' };
  
  // 支线进行中
  const activeQuest = questSystem.getActiveQuest();
  if (activeQuest) {
    const quest = questSystem.getQuest(activeQuest.questId);
    if (quest) {
      return { text: `📜 支线：${quest.name}`, priority: 'quest' };
    }
  }
  
  // 突破阶段判断
  if (pct >= 0.9) {
    return { text: `🔥 突破在即！还需 ${threshold - cultivation} 修为`, priority: 'breakthrough' };
  }
  if (pct >= 0.5) {
    return { text: `⬆ 积累修为 (${cultivation}/${threshold})`, priority: 'progress' };
  }
  
  // 默认目标
  return { text: '⚔ 探索修仙之路', priority: 'normal' };
}
```

#### 修改 2：`index.html` — 在 top-bar 中增加目标提示 DOM

```html
<!-- 在 top-info div 中增加（约 index.html:67 行后） -->
<span class="badge goal" id="top-goal" style="display:none;">探索修仙之路</span>
```

#### 修改 3：`src/ui.js` — 优化 `_renderBreakthroughBar`

```javascript
/**
 * 突破倒计时进度条 — 增强版
 */
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
  const remaining = Math.max(0, threshold - current);
  
  // 获取下一境界名称
  const realmOrder = gameState.config.realms.order || ['qi', 'foundation', 'golden', 'nascent', 'deity', 'tribulation'];
  const currentIdx = realmOrder.indexOf(gameState.realm);
  const nextRealmName = currentIdx >= 0 && currentIdx < realmOrder.length - 1
    ? gameState.getRealmName(realmOrder[currentIdx + 1])
    : '飞升';

  this.btBar.style.display = 'flex';
  // 优化文字：显示"距XX期还差X修为"
  this.btLabel.textContent = remaining > 0 
    ? `⬆ 距${nextRealmName}还差 ${remaining} 修为`
    : `🔥 ${nextRealmName}突破条件已达成！`;
  this.btFill.style.width = `${pct}%`;
  this.btPct.textContent = `${current}/${threshold} (${pct}%)`;

  // 阶梯色 + 动态类名
  this.btFill.className = 'bt-fill';
  if (pct >= 90) {
    this.btFill.classList.add('crit');
    this.btLabel.style.color = '#fbbf24';
    this.btPct.style.color = '#fbbf24';
    // 临界状态添加脉冲动画
    this.btBar.classList.add('bt-pulse');
  } else if (pct >= 75) {
    this.btFill.classList.add('high');
    this.btLabel.style.color = '#a78bfa';
    this.btPct.style.color = '#a78bfa';
    this.btBar.classList.remove('bt-pulse');
  } else if (pct >= 50) {
    this.btFill.classList.add('mid');
    this.btLabel.style.color = '#5ba0f5';
    this.btPct.style.color = '#5ba0f5';
    this.btBar.classList.remove('bt-pulse');
  } else {
    this.btFill.classList.add('low');
    this.btLabel.style.color = '';
    this.btPct.style.color = '';
    this.btBar.classList.remove('bt-pulse');
  }
}
```

#### 修改 4：`src/ui.js` — 增加突破全屏动画

```javascript
/**
 * 播放境界突破全屏动画
 * @param {string} fromRealm - 原境界名
 * @param {string} toRealm - 新境界名
 */
_playBreakthroughAnimation(fromRealm, toRealm) {
  // 创建全屏覆盖层
  const overlay = document.createElement('div');
  overlay.className = 'breakthrough-overlay';
  overlay.innerHTML = `
    <div class="breakthrough-particles"></div>
    <div class="breakthrough-text">
      <div class="bt-from">${fromRealm} · 圆满</div>
      <div class="bt-arrow">▼</div>
      <div class="bt-to">${toRealm} · 初成</div>
    </div>
  `;
  document.body.appendChild(overlay);
  
  // 3.5秒后自动移除
  setTimeout(() => {
    overlay.classList.add('fade-out');
    setTimeout(() => overlay.remove(), 1000);
  }, 3500);
  
  // 触发心念（如果已修复 _triggerInnerVoice 的调用位置）
  if (this.game && this.game._triggerInnerVoice) {
    this.game._triggerInnerVoice('breakthrough_success', 1.0);
  }
}
```

#### 修改 5：`src/game.js` — 在突破成功后调用动画

```javascript
// 在 _resolveBreakthrough() 方法中（约 game.js:1100+ 行）
// 突破成功后：
// gameState.realm = nextRealm; // 已存在
// 增加：
if (typeof ui !== 'undefined' && ui._playBreakthroughAnimation) {
  const prevRealmName = gameState.getRealmName(prevRealm);
  const nextRealmName = gameState.getRealmName(nextRealm);
  ui._playBreakthroughAnimation(prevRealmName, nextRealmName);
}
```

#### 修改 6：`styles/style.css` — 增加动画样式

```css
/* 目标提示 badge */
.badge.goal { background: rgba(91, 160, 245, 0.15); color: #5ba0f5; border: 1px solid rgba(91, 160, 245, 0.3); }
.badge.goal-critical { background: rgba(231, 76, 60, 0.2); color: #e74c3c; border: 1px solid rgba(231, 76, 60, 0.4); animation: pulse-critical 1.5s infinite; }
.badge.goal-breakthrough { background: rgba(251, 191, 36, 0.2); color: #fbbf24; border: 1px solid rgba(251, 191, 36, 0.4); animation: pulse-gold 2s infinite; }
.badge.goal-quest { background: rgba(163, 113, 247, 0.15); color: #a371f7; border: 1px solid rgba(163, 113, 247, 0.3); }

/* 突破进度条脉冲 */
.breakthrough-bar.bt-pulse { animation: bar-pulse 1.5s ease-in-out infinite; }
@keyframes bar-pulse { 0%,100% { box-shadow: 0 0 0 0 rgba(251,191,36,0.4); } 50% { box-shadow: 0 0 12px 4px rgba(251,191,36,0.2); } }

/* 突破全屏动画 */
.breakthrough-overlay { position: fixed; inset: 0; background: rgba(0,0,0,0.85); z-index: 3000; display: flex; align-items: center; justify-content: center; animation: bt-overlay-in 0.5s ease-out; }
.breakthrough-overlay.fade-out { animation: bt-overlay-out 1s ease-in forwards; }
.breakthrough-text { text-align: center; color: #ffd700; }
.bt-from { font-size: 1.2rem; color: #aaa; }
.bt-arrow { font-size: 2rem; margin: 12px 0; animation: bt-bounce 1s ease-in-out infinite; }
.bt-to { font-size: 2.5rem; font-weight: bold; text-shadow: 0 0 20px rgba(255,215,0,0.5); }
@keyframes bt-overlay-in { from { opacity: 0; } to { opacity: 1; } }
@keyframes bt-overlay-out { from { opacity: 1; } to { opacity: 0; } }
@keyframes bt-bounce { 0%,100% { transform: translateY(0); } 50% { transform: translateY(-10px); } }
```

### 1.4 预期效果

- ✅ 玩家首次进入游戏后，顶部 HUD 明确显示当前目标（如"积累修为（12/100）"）
- ✅ 突破进度条以可视化方式展示成长路径，90% 以上时有脉冲动画提醒
- ✅ 境界突破时获得强烈的正反馈，增强成就感
- ✅ 危险状态（气血/道心/寿元低）时目标提示变为红色警告，引导玩家关注生存

### 1.5 验收标准

1. 打开游戏后，`top-goal` 元素可见，显示内容符合当前玩家状态
2. 修为达到 threshold 的 90% 时，突破进度条开始脉冲动画
3. 成功突破境界后，全屏动画播放，显示"XX期·圆满 → YY期·初成"
4. 气血 <= 20 时，目标提示变为红色警告"⚠ 气血危急"

---

## 二、选择反馈系统

### 2.1 问题诊断

当前选择反馈极为薄弱：

1. **选择前**：玩家只看到选项文字（如"专注修炼"），不知道选了这个会有什么后果
2. **选择后**：只有一行日志（如"灵气入体，修为凝实了几分。+10"），数字变化被淹没在日志中
3. **属性条**：虽然会更新，但没有动画、没有高亮，玩家很难注意到变化

**代码证据**：

```javascript
// src/ui.js:682-696 renderCard() 中选项渲染
// 当前只渲染：方向箭头 + 选项文字 + desc（如果有）
// 以及 _choiceMood() 返回的 mood 类名（blessing/danger/tradeoff/neutral）
// 但 choice.desc 往往是空白的，或只有一句叙事性描述

// _choiceMood()（ui.js:1497）逻辑：
// 根据 effects 中的正负数值判断 mood
// 但只设置 btn.dataset.mood，没有更详细的后果预览
```

```javascript
// src/game.js:517 makeChoice()
// 选择后：_applyEffects() → 日志输出 → _triggerUpdate() → renderGame()
// 没有"选择确认动画"或"属性变化动画"
```

**玩家反馈映射**："选左选右只是数字+5的区别" → 选择缺乏意义感和反馈感。

### 2.2 优化方案

#### 2.2.1 选项按钮增加"后果预览"面板

在每个选项按钮下方增加一个微型后果预览区域：

- 用颜色区分类别：
  - 🟢 绿色 = 收益（修为+、气血+、灵石+）
  - 🔴 红色 = 风险（气血-、道心-、寿元-）
  - 🟡 金色 = 特殊（获得道具、触发支线、种因果）
  - ⚪ 灰色 = 中性（无直接数值变化）

- 标注关键阈值：
  - "气血-15" → 如果当前气血 < 35，显示 "⚠ 危险"
  - "突破进度+25%" → 显示 "🔥 接近突破"
  - "种下因果种子" → 显示 "🌱 因果"

#### 2.2.2 选择后即时反馈动画

- **数字跳动**：属性变化时，在属性条旁边显示浮动数字（如 `+10` 向上飘动后消失）
- **属性条闪烁**：变化的属性条背景闪烁 0.3 秒
- **日志高亮**：该轮日志的第一条（即本次选择的结果）用特殊背景色高亮

#### 2.2.3 细化 `_choiceMood` 规则

当前 `_choiceMood` 只返回 4 种 mood，增加更多细分：

| 条件 | mood | 按钮样式 |
|------|------|---------|
| 有 `karmaSeed` | `karmic` | 紫色边框 + 因果图标 |
| 有 `openShop` / `openMarket` | `commerce` | 金色边框 + 灵石图标 |
| 有 `breakSuccess` | `breakthrough` | 金色渐变 + 突破图标 |
| 有 `dungeon` | `exploration` | 蓝色边框 + 秘境图标 |
| 有 `nextCard`（支线推进）| `quest` | 紫色边框 + 卷轴图标 |
| health 变化 < -15 | `lethal` | 红色闪烁边框 |

### 2.3 具体实现

#### 修改 1：`src/ui.js` — 增强 `renderCard` 中选项的后果预览

```javascript
// 在 renderCard() 的选项渲染循环中（约 ui.js:682-697 行）
// 替换为增强版：

dirs.forEach(dir => {
  const btn = this.getChoiceButton(dir);
  const choice = card.choices[dir];
  if (btn && choice) {
    btn.classList.add('visible');
    btn.querySelector('.choice-text').textContent = `${dirLabels[dir]} ${choice.text}`;
    
    // 后果描述（保留原有叙事描述）
    const descEl = btn.querySelector('.choice-desc');
    if (descEl) {
      descEl.textContent = choice.desc || '';
    }
    
    // === 新增：后果预览 ===
    const previewEl = btn.querySelector('.choice-preview');
    if (previewEl) {
      const preview = this._buildChoicePreview(choice);
      previewEl.innerHTML = preview;
      previewEl.style.display = preview ? 'block' : 'none';
    }
    
    // 选择预兆（增强版 mood）
    const mood = this._choiceMoodEnhanced(choice);
    btn.dataset.mood = mood;
  }
});
```

#### 修改 2：`src/ui.js` — 新增 `_buildChoicePreview` 方法

```javascript
/**
 * 构建选项后果预览 HTML
 * @param {Object} choice
 * @returns {string} HTML 字符串
 */
_buildChoicePreview(choice) {
  if (!choice) return '';
  const parts = [];
  
  // 数值效果预览
  if (choice.effects) {
    const effectLabels = {
      cultivation: '修为', health: '气血', daoHeart: '道心',
      karmaGood: '善因', karmaBad: '恶因', fortune: '福缘',
      spiritStone: '灵石', lifespan: '寿元'
    };
    
    for (const [key, val] of Object.entries(choice.effects)) {
      if (effectLabels[key] && typeof val === 'number') {
        const color = val > 0 ? '#4ade80' : val < 0 ? '#f87171' : '#9ca3af';
        const sign = val > 0 ? '+' : '';
        parts.push(`<span class="preview-tag" style="color:${color}">${effectLabels[key]} ${sign}${val}</span>`);
      }
    }
  }
  
  // 特殊效果预览
  if (choice.karmaSeed) {
    const seedId = Array.isArray(choice.karmaSeed) ? choice.karmaSeed[0].id || choice.karmaSeed[0] : choice.karmaSeed.id || choice.karmaSeed;
    parts.push(`<span class="preview-tag preview-karma">🌱 因果</span>`);
  }
  if (choice.openShop || choice.openMarket) {
    parts.push(`<span class="preview-tag preview-shop">💰 商店</span>`);
  }
  if (choice.breakSuccess !== undefined) {
    parts.push(`<span class="preview-tag preview-breakthrough">🔥 突破</span>`);
  }
  if (choice.dungeon) {
    parts.push(`<span class="preview-tag preview-dungeon">🏔 秘境</span>`);
  }
  if (choice.nextCard || choice.questNext) {
    parts.push(`<span class="preview-tag preview-quest">📜 支线</span>`);
  }
  
  // 危险预警：如果 effects 会导致当前属性进入危险区
  const dangerWarnings = this._checkDangerThresholds(choice.effects);
  for (const warning of dangerWarnings) {
    parts.push(`<span class="preview-tag preview-warning">⚠ ${warning}</span>`);
  }
  
  return parts.join(' ');
}

/**
 * 检查选择是否会导致属性进入危险阈值
 */
_checkDangerThresholds(effects) {
  if (!effects) return [];
  const warnings = [];
  
  if (effects.health !== undefined) {
    const projected = (gameState.attributes.health || 0) + effects.health;
    if (projected <= 20 && projected > 0) warnings.push('气血危险');
    if (projected <= 0) warnings.push('可能死亡');
  }
  if (effects.daoHeart !== undefined) {
    const projected = (gameState.attributes.daoHeart || 0) + effects.daoHeart;
    if (projected <= 20) warnings.push('道心危险');
  }
  if (effects.lifespan !== undefined) {
    const projected = (gameState.resources.lifespan || 0) + effects.lifespan;
    if (projected <= 10) warnings.push('寿元殆尽');
  }
  
  return warnings;
}
```

#### 修改 3：`src/ui.js` — 增强 `_choiceMood` 为 `_choiceMoodEnhanced`

```javascript
/**
 * 增强版选择预兆判断
 * 在原 _choiceMood 基础上增加对特殊 choice 的识别
 */
_choiceMoodEnhanced(choice) {
  if (!choice) return 'neutral';
  
  // 特殊 choice 类型优先
  if (choice.karmaSeed) return 'karmic';
  if (choice.openShop || choice.openMarket) return 'commerce';
  if (choice.breakSuccess !== undefined) return 'breakthrough';
  if (choice.dungeon) return 'exploration';
  if (choice.nextCard || choice.questNext) return 'quest';
  if (choice._treasureOption) return 'treasure';
  
  // 危险检查
  const dangerWarnings = this._checkDangerThresholds(choice.effects);
  if (dangerWarnings.some(w => w.includes('死亡'))) return 'lethal';
  if (dangerWarnings.length > 0) return 'danger';
  
  // 回退到原 _choiceMood 逻辑
  return this._choiceMood(choice.effects);
}
```

#### 修改 4：`index.html` — 在 choice-btn 中增加 preview 元素

```html
<!-- 在每个 choice-btn 中增加 preview 容器（约 index.html:223-244 行） -->
<!-- 例如 choice-left： -->
<button class="choice-btn left" id="choice-left" data-dir="left">
  <span class="choice-arrow">←</span>
  <span class="choice-text">选择</span>
  <span class="choice-desc"></span>
  <span class="choice-preview"></span>  <!-- 新增 -->
</button>
```

#### 修改 5：`src/ui.js` — 增加选择后属性动画

```javascript
/**
 * 播放属性变化动画
 * @param {string} attr - 属性名
 * @param {number} delta - 变化量
 */
_animateAttributeChange(attr, delta) {
  const bar = this.bars[attr];
  const label = this.labels[attr];
  if (!bar || !label) return;
  
  // 属性条闪烁
  bar.classList.add('attr-flash');
  setTimeout(() => bar.classList.remove('attr-flash'), 300);
  
  // 浮动数字
  const floatEl = document.createElement('div');
  floatEl.className = 'attr-float';
  floatEl.textContent = delta > 0 ? `+${delta}` : `${delta}`;
  floatEl.style.color = delta > 0 ? '#4ade80' : '#f87171';
  
  const rect = bar.getBoundingClientRect();
  floatEl.style.left = `${rect.right + 8}px`;
  floatEl.style.top = `${rect.top}px`;
  document.body.appendChild(floatEl);
  
  // 动画：向上飘动 + 淡出
  requestAnimationFrame(() => {
    floatEl.style.transition = 'all 1s ease-out';
    floatEl.style.transform = 'translateY(-30px)';
    floatEl.style.opacity = '0';
  });
  
  setTimeout(() => floatEl.remove(), 1000);
}
```

#### 修改 6：`src/game.js` — 在选择后 emit 属性变化事件

```javascript
// 在 makeChoice() 的 _applyEffects() 调用后（约 game.js:617 行后）
// 监听属性变化事件并触发动画

// 记录应用效果前的属性快照
const preAttrs = { ...gameState.attributes };
const preResources = { ...gameState.resources };

// 应用效果（原有代码）
this._applyEffects(choice.effects);

// === 新增：检测变化并触发 UI 动画 ===
if (typeof ui !== 'undefined' && ui._animateAttributeChange) {
  for (const [key, val] of Object.entries(choice.effects || {})) {
    if (typeof val === 'number' && ['cultivation','health','daoHeart','karmaGood','karmaBad','fortune'].includes(key)) {
      const pre = preAttrs[key] || 0;
      const post = gameState.attributes[key] || 0;
      const actualDelta = post - pre;
      if (actualDelta !== 0) {
        ui._animateAttributeChange(key, actualDelta);
      }
    }
  }
}
```

#### 修改 7：`styles/style.css` — 增加后果预览和动画样式

```css
/* 后果预览 */
.choice-preview { display: block; margin-top: 4px; font-size: 0.7rem; line-height: 1.4; }
.preview-tag { display: inline-block; padding: 1px 6px; border-radius: 3px; background: rgba(0,0,0,0.3); margin-right: 4px; margin-bottom: 2px; }
.preview-karma { background: rgba(163,113,247,0.2); color: #c084fc; }
.preview-shop { background: rgba(251,191,36,0.2); color: #fbbf24; }
.preview-breakthrough { background: rgba(255,215,0,0.2); color: #ffd700; }
.preview-dungeon { background: rgba(91,160,245,0.2); color: #5ba0f5; }
.preview-quest { background: rgba(163,113,247,0.2); color: #a371f7; }
.preview-warning { background: rgba(231,76,60,0.2); color: #f87171; font-weight: bold; }

/* 按钮 mood 样式扩展 */
.choice-btn[data-mood="karmic"] { border-color: #c084fc; box-shadow: 0 0 8px rgba(192,132,252,0.3); }
.choice-btn[data-mood="commerce"] { border-color: #fbbf24; }
.choice-btn[data-mood="exploration"] { border-color: #5ba0f5; }
.choice-btn[data-mood="quest"] { border-color: #a371f7; }
.choice-btn[data-mood="lethal"] { border-color: #e74c3c; animation: lethal-pulse 0.8s infinite; }
@keyframes lethal-pulse { 0%,100% { box-shadow: 0 0 0 0 rgba(231,76,60,0.5); } 50% { box-shadow: 0 0 10px 2px rgba(231,76,60,0.3); } }

/* 属性条闪烁动画 */
.attr-fill.attr-flash { animation: attr-flash 0.3s ease-out; }
@keyframes attr-flash { 0% { filter: brightness(2); } 100% { filter: brightness(1); } }

/* 浮动数字 */
.attr-float { position: fixed; font-size: 1rem; font-weight: bold; pointer-events: none; z-index: 2000; }
```

### 2.4 预期效果

- ✅ 选择前，玩家可以直观地看到每个选项的数值后果和特殊效果
- ✅ 危险选择（如"气血-15 导致死亡风险"）有红色警告
- ✅ 选择后，变化的属性条闪烁，浮动数字飘动，反馈明确
- ✅ 特殊 choice（因果/突破/商店/秘境）有独特的按钮样式

### 2.5 验收标准

1. 鼠标悬停/显示选项时，每个 choice-btn 下方显示后果预览标签
2. 选择"气血-20"的选项时，如果当前气血 < 40，预览显示"⚠ 气血危险"
3. 选择后，属性条闪烁，浮动数字动画播放
4. 带有 `karmaSeed` 的选项按钮边框变为紫色

---

## 三、属性面板简化

### 3.1 问题诊断

当前属性面板（`index.html:109-199`）包含：

- **6 个属性条**：修为、道心、善因、恶因、福缘、气血
- **天机条**：`tianji`（index.html:158-164）
- **5 个被动加成**：回血/轮、福缘/轮、攻击、防御、暴击

总计 **12 个数据项** 同时显示在左侧 sidebar。其中善因、恶因、福缘在 `index.html` 中已设置 `style="display:none;"`（`line 130, 137, 144`），但 `renderAttributes()`（`ui.js:465`）会强制显示它们。

**代码证据**：

```html
<!-- index.html:130-164 -->
<!-- 善因、恶因、福缘 已设为 display:none -->
<div class="attr-item" data-attr="karmaGood" style="display:none;">...</div>
<div class="attr-item" data-attr="karmaBad" style="display:none;">...</div>
<div class="attr-item" data-attr="fortune" style="display:none;">...</div>
```

```javascript
// ui.js:465-490 renderAttributes()
// 循环遍历 this.bars（ cultivation, daoHeart, karmaGood, karmaBad, fortune, health ）
// 无条件渲染所有 6 个属性条，覆盖 HTML 中的 display:none
```

这导致：
1. 信息过载：新玩家面对 6 个属性条 + 被动加成，不知该关注哪个
2. 关键信息被淹没：修为（核心进度）和气血（生死线）没有视觉突出
3. 灵石显示在顶部 resources 区域，但排版松散

**玩家反馈映射**："信息过载" → 6 个属性 + 灵石 + 寿元 + 回合数 + 阶段 + 位置 = 认知超载。

### 3.2 优化方案

#### 3.2.1 属性分级显示

| 级别 | 属性 | 显示方式 | 变化提醒 |
|------|------|---------|---------|
| **主显**（始终可见） | 修为、气血、寿元 | 大属性条 + 数字 | 修为变化时闪烁金色，气血<=20时红色脉冲 |
| **次显**（折叠面板） | 道心、善因、恶因、福缘 | 折叠在"展开"按钮下 | 关键变化时（如善因+10）闪烁提醒 |
| **紧凑显示** | 灵石 | 图标+数字，放在 top-bar | 获得/消耗时数字跳动 |
| **隐藏/按需** | 天机 | 仅在 >50 时显示 | 超过 80 时红色警告 |

#### 3.2.2 主显属性视觉增强

- **修为条**：使用渐变蓝色，宽度大于其他条，标记 threshold 位置
- **气血条**：使用红色渐变，<=50 时变黄，<=20 时变红并脉冲
- **寿元**：从属性面板移到 top-bar 的灵石旁边，用 🕐 图标

#### 3.2.3 次显面板交互

- 点击"展开灵根详情"按钮后，下方滑出道心/善因/恶因/福缘
- 当这些属性发生显著变化（>=10）时，展开按钮闪烁提醒
- 天机条默认隐藏，仅当 `tianji > 50` 时自动展开显示

### 3.3 具体实现

#### 修改 1：`index.html` — 重构属性面板 DOM 结构

```html
<!-- 替换原有 attribute-panel（约 index.html:109-199 行） -->
<aside class="attribute-panel">
  <div class="panel-decoration top"></div>
  <div class="panel-header">
    <span class="panel-icon">☯</span>
    <span class="panel-title">修仙状态</span>
  </div>
  
  <!-- 主显属性：修为 + 气血 -->
  <div class="panel-body panel-primary">
    <div class="attr-item attr-primary" data-attr="cultivation">
      <div class="attr-icon c-icon-xiu">⚔</div>
      <div class="attr-info">
        <div class="attr-label" id="label-cultivation">修为 0</div>
        <div class="attr-bar attr-bar-large"><div class="attr-fill cultivation" id="bar-cultivation">0</div></div>
      </div>
    </div>
    <div class="attr-item attr-primary" data-attr="health">
      <div class="attr-icon c-icon-qi">❤</div>
      <div class="attr-info">
        <div class="attr-label" id="label-health">气血 0</div>
        <div class="attr-bar attr-bar-large"><div class="attr-fill health" id="bar-health">0</div></div>
      </div>
    </div>
  </div>
  
  <!-- 次显属性：折叠面板 -->
  <div class="panel-divider toggle-secondary" id="toggle-secondary">
    <span class="divider-dot">◆</span>
    <span class="divider-label">灵根详情</span>
    <span class="divider-arrow">▼</span>
    <span class="divider-dot">◆</span>
  </div>
  
  <div class="panel-body panel-secondary" id="panel-secondary" style="display:none;">
    <div class="attr-item" data-attr="daoHeart" data-tooltip="道心：抵抗心魔与诱惑的意志力">
      <div class="attr-icon c-icon-xin">◈</div>
      <div class="attr-info">
        <div class="attr-label" id="label-daoHeart">道心 0</div>
        <div class="attr-bar"><div class="attr-fill daoHeart" id="bar-daoHeart">0</div></div>
      </div>
    </div>
    <div class="attr-item" data-attr="karmaGood">
      <div class="attr-icon c-icon-shan">◎</div>
      <div class="attr-info">
        <div class="attr-label" id="label-karmaGood">善因 0</div>
        <div class="attr-bar"><div class="attr-fill karmaGood" id="bar-karmaGood">0</div></div>
      </div>
    </div>
    <div class="attr-item" data-attr="karmaBad">
      <div class="attr-icon c-icon-e">◆</div>
      <div class="attr-info">
        <div class="attr-label" id="label-karmaBad">恶因 0</div>
        <div class="attr-bar"><div class="attr-fill karmaBad" id="bar-karmaBad">0</div></div>
      </div>
    </div>
    <div class="attr-item" data-attr="fortune">
      <div class="attr-icon c-icon-fu">✤</div>
      <div class="attr-info">
        <div class="attr-label" id="label-fortune">福缘 0</div>
        <div class="attr-bar"><div class="attr-fill fortune" id="bar-fortune">0</div></div>
      </div>
    </div>
    <!-- 天机条：默认隐藏，仅高值时显示 -->
    <div class="attr-item" data-attr="tianji" id="attr-tianji" style="display:none;">
      <div class="attr-icon" style="color:#e74c3c; font-weight:bold;">⚡</div>
      <div class="attr-info">
        <div class="attr-label" id="label-tianji">天机 0</div>
        <div class="attr-bar"><div class="attr-fill tianji" id="bar-tianji" style="background:#e74c3c;">0</div></div>
      </div>
    </div>
  </div>
  
  <div class="panel-divider">
    <span class="divider-dot">◆</span>
    <span class="divider-label">法宝·功法</span>
    <span class="divider-dot">◆</span>
  </div>
  <div class="panel-passives" id="panel-passives">
    <!-- 被动加成保持原样 -->
    <div class="passive-row" id="passive-hpRegen">...</div>
    <div class="passive-row" id="passive-fortune">...</div>
    <div class="passive-row" id="passive-atk">...</div>
    <div class="passive-row" id="passive-def">...</div>
    <div class="passive-row" id="passive-crit">...</div>
  </div>
  <div class="panel-decoration bottom"></div>
</aside>
```

#### 修改 2：`index.html` — 优化 top-bar 资源显示

```html
<!-- 替换原有 top-resources（约 index.html:73-80 行） -->
<div class="top-resources">
  <span class="resource compact" title="灵石">
    <img class="res-icon-img" src="assets/icons/icon_spirit_stone.png" alt="灵石">
    <span id="top-spiritStone">0</span>
  </span>
  <span class="resource compact" title="寿元">
    <span class="res-icon-text">🕐</span>
    <span id="top-lifespan">0</span>
  </span>
  <span class="resource compact" title="轮数">
    <span class="res-icon-text">🔄</span>
    <span id="top-turn">0</span>
  </span>
  <button class="npc-list-btn" id="npc-list-btn" title="江湖人物">👤</button>
  <button class="npc-list-btn" id="bestiary-btn" title="万物志">📖</button>
  <button class="npc-list-btn" id="thread-panel-btn" title="故事线">🔗</button>
</div>
```

#### 修改 3：`src/ui.js` — 重构 `renderAttributes`

```javascript
renderAttributes() {
  const attrs = gameState.attributes;
  const labels = {
    cultivation: '修为', daoHeart: '道心',
    karmaGood: '善因', karmaBad: '恶因',
    fortune: '福缘', health: '气血'
  };
  
  // 主显属性：始终渲染
  const primaryAttrs = ['cultivation', 'health'];
  for (const key of primaryAttrs) {
    const bar = this.bars[key];
    const label = this.labels[key];
    if (!bar || !label) continue;
    
    const value = attrs[key] || 0;
    const maxVal = key === 'health' ? gameState.maxHealth : 100;
    const pct = Math.min(100, (value / maxVal) * 100);
    
    bar.style.width = `${pct}%`;
    bar.textContent = `${value}`;
    
    const labelSuffix = key === 'health' ? ` / ${gameState.maxHealth}` : '';
    this.labels[key].textContent = `${labels[key]} ${value}${labelSuffix}`;
    
    // 气血生死线
    if (key === 'health') {
      const item = bar.closest('.attr-item');
      if (item) {
        if (value <= 20) {
          item.classList.add('critical');
          bar.classList.add('pulse-red');
        } else {
          item.classList.remove('critical');
          bar.classList.remove('pulse-red');
        }
      }
    }
  }
  
  // 次显属性：仅当面板展开时渲染（或始终渲染但面板可折叠）
  const secondaryAttrs = ['daoHeart', 'karmaGood', 'karmaBad', 'fortune'];
  for (const key of secondaryAttrs) {
    const bar = this.bars[key];
    const label = this.labels[key];
    if (!bar || !label) continue;
    
    const value = attrs[key] || 0;
    bar.style.width = `${Math.min(value, 100)}%`;
    bar.textContent = `${value}`;
    this.labels[key].textContent = `${labels[key]} ${value}`;
  }
  
  // 天机条：动态显示/隐藏
  const tianjiBar = document.getElementById('bar-tianji');
  const tianjiItem = document.getElementById('attr-tianji');
  if (tianjiBar && tianjiItem) {
    const tianjiVal = attrs.tianji || 0;
    if (tianjiVal > 50) {
      tianjiItem.style.display = 'flex';
      tianjiBar.style.width = `${Math.min(tianjiVal, 100)}%`;
      tianjiBar.textContent = `${tianjiVal}`;
      if (tianjiVal > 80) {
        tianjiItem.classList.add('critical');
      }
    } else {
      tianjiItem.style.display = 'none';
    }
  }
  
  // 检查次显属性是否有显著变化，提醒展开
  this._checkSecondaryAlert(secondaryAttrs);
}

/**
 * 检查次显属性是否有显著变化，闪烁展开按钮
 */
_checkSecondaryAlert(secondaryKeys) {
  const toggleBtn = document.getElementById('toggle-secondary');
  if (!toggleBtn) return;
  
  // 简化逻辑：如果面板未展开且任一属性 >= 20，闪烁提醒
  const panel = document.getElementById('panel-secondary');
  if (!panel || panel.style.display !== 'none') return;
  
  const hasAlert = secondaryKeys.some(key => (gameState.attributes[key] || 0) >= 20);
  if (hasAlert) {
    toggleBtn.classList.add('has-alert');
  } else {
    toggleBtn.classList.remove('has-alert');
  }
}
```

#### 修改 4：`src/ui.js` — 绑定折叠面板事件

```javascript
// 在 cacheElements() 中增加（约 ui.js:210 行后）
this.toggleSecondary = document.getElementById('toggle-secondary');
this.panelSecondary = document.getElementById('panel-secondary');

// 在 bindEvents() 中增加（约 ui.js:270 行后）
if (this.toggleSecondary) {
  this.toggleSecondary.addEventListener('click', () => {
    const isHidden = this.panelSecondary.style.display === 'none';
    this.panelSecondary.style.display = isHidden ? 'block' : 'none';
    this.toggleSecondary.querySelector('.divider-arrow').textContent = isHidden ? '▲' : '▼';
    this.toggleSecondary.classList.remove('has-alert');
  });
}
```

#### 修改 5：`src/ui.js` — 在 `renderTopBar` 中更新寿元显示

```javascript
// renderTopBar() 中（约 ui.js:354 行）
// 原有：this.topLifespan.textContent = gameState.resources.lifespan;
// 增加颜色提醒：
const lifespan = gameState.resources.lifespan || 0;
this.topLifespan.textContent = lifespan;
this.topLifespan.style.color = lifespan <= 20 ? '#e74c3c' : lifespan <= 40 ? '#fbbf24' : '';
```

#### 修改 6：`styles/style.css` — 增加折叠面板样式

```css
/* 主显属性条更大 */
.attr-bar-large { height: 12px; }
.attr-bar-large .attr-fill { font-size: 0.75rem; line-height: 12px; }

/* 折叠面板 */
.toggle-secondary { cursor: pointer; user-select: none; transition: background 0.2s; }
.toggle-secondary:hover { background: rgba(255,255,255,0.05); }
.toggle-secondary .divider-arrow { transition: transform 0.2s; }
.toggle-secondary.has-alert { animation: alert-pulse 1.5s infinite; }
.toggle-secondary.has-alert .divider-label { color: #fbbf24; }

/* 气血脉冲 */
.attr-fill.pulse-red { animation: pulse-red 1s infinite; }
@keyframes pulse-red { 0%,100% { opacity: 1; } 50% { opacity: 0.6; } }
@keyframes alert-pulse { 0%,100% { box-shadow: inset 0 0 0 0 rgba(251,191,36,0.3); } 50% { box-shadow: inset 0 0 8px 2px rgba(251,191,36,0.2); } }

/* 紧凑资源显示 */
.resource.compact { font-size: 0.85rem; gap: 3px; }
.res-icon-text { font-size: 0.9rem; }
```

### 3.4 预期效果

- ✅ 新玩家进入游戏后，左侧只显示修为和气血两个大属性条，认知负担大幅降低
- ✅ 修为条始终可见，玩家清晰感知自己的成长进度
- ✅ 气血条在危险时红色脉冲，引导玩家关注生存
- ✅ 灵石、寿元、回合数紧凑排列在顶部，不占用主面板空间
- ✅ 高级玩家可以点击"灵根详情"展开查看道心/善恶因/福缘

### 3.5 验收标准

1. 左侧属性面板默认只显示"修为"和"气血"两个属性条
2. 点击"灵根详情"后展开显示道心/善因/恶因/福缘
3. 气血 <= 20 时，属性条红色脉冲闪烁
4. 天机值 > 50 时，天机条自动出现；> 80 时红色警告
5. 寿元 <= 20 时，top-bar 的寿元数字变红色

---

## 四、新手引导系统

### 4.1 问题诊断

当前游戏**完全没有新手引导**。玩家开局后的流程是：

1. 输入名字 → 选择功法（4 个按钮，只有一句话描述）
2. 直接进入游戏，第一张卡可能是"采集灵草"或"老乞赠书"
3. 玩家不知道：修为是什么？道心是干嘛的？善因/恶因有什么用？寿元耗尽了会怎样？

**代码证据**：

```javascript
// game.js:353-388 start(path) 方法
// 只输出两行日志：
// "{playerName}，仙途之路，自此开始。"
// "你选择了 {功法名} 之道。"
// 然后直接 _triggerUpdate() 开始抽卡

// index.html:31-55 功法选择
// 每个功法只有一个图标、名字、一句话描述：
// "剑修 · 一剑破万法，高攻高风险"
// 没有属性差异、没有专属机制说明
```

**玩家反馈映射**："玩得莫名其妙" → 开局缺乏引导，玩家不知道任何规则的因果关系。

### 4.2 优化方案

#### 4.2.1 前 5 回合"引导卡"系统

前 5 张卡改为**引导卡**，每张卡带有解释性文字，逐步介绍核心机制：

| 回合 | 引导卡主题 | 说明内容 |
|------|-----------|---------|
| 1 | 修为与境界 | "修为是修仙的根本，积累到 100 可突破境界" |
| 2 | 气血与寿元 | "气血归零则道消，寿元耗尽则坐化" |
| 3 | 道心与选择 | "道心影响突破成功率，也决定面对诱惑时的定力" |
| 4 | 因果系统 | "善恶之举会种下因果，未来可能开花结果" |
| 5 | 功法特色 | 根据所选功法，介绍专属机制和技能 |

引导卡的选项后果经过**精心设计**，确保玩家能安全地体验数值变化。

#### 4.2.2 功法选择增强

在功法选择界面增加详细对比：

- **属性差异可视化**：用迷你条形图展示 4 个功法的初始属性差异
- **玩法风格标签**：如"高风险高回报""稳健发育""资源运营""控制策略"
- **专属机制说明**：
  - 剑修："暴击率+15%，解锁剑意系统"
  - 法修："灵石获取+20%，部分卡牌有额外选项"
  - 体修："气血上限+30，被动回血"
  - 丹修："丹药效果+50%，可炼制特殊丹药"

#### 4.2.3 "首次遇到"提示系统

当玩家首次遇到以下系统时，弹出非侵入式提示框：

- 首次种因果种子 → "🌱 你种下了一颗因果种子。若干回合后，它会发芽为特殊事件。"
- 首次触发支线 → "📜 支线任务已激活！在顶部 HUD 可查看进度。"
- 首次进入商店 → "💰 坊市中可以购买法宝、丹药和功法秘籍。"
- 首次进入战斗 → "⚔ 战斗会消耗寿元，胜利可获得修为和战利品。"
- 首次遇到瓶颈 → "🔥 修为已满！选择突破可进入下一境界，但突破可能失败。"

### 4.3 具体实现

#### 修改 1：新建 `src/systems/TutorialSystem.js`

```javascript
/**
 * TutorialSystem - 新手引导系统
 *
 * 负责：
 * 1. 前 N 回合的引导卡注入
 * 2. "首次遇到"提示管理
 * 3. 引导完成状态持久化
 */
class TutorialSystem {
  constructor() {
    this._completedTips = new Set();
    this._guideCardIndex = 0;
    this._isActive = true;
    this._maxGuideTurns = 5;
  }

  init() {
    // 从存档读取已完成提示
    try {
      const saved = localStorage.getItem('xiuxian_tutorial');
      if (saved) {
        const data = JSON.parse(saved);
        this._completedTips = new Set(data.tips || []);
        this._guideCardIndex = data.guideIndex || 0;
        this._isActive = data.isActive !== false;
      }
    } catch (e) {
      // 首次游戏，使用默认值
    }

    // 监听关键事件
    eventBus.on('card:chosen', (data) => this._onCardChosen(data));
    eventBus.on('karma:seedPlanted', (data) => this._tryShowTip('karma_seed'));
    eventBus.on('quest:triggered', (data) => this._tryShowTip('quest'));
    eventBus.on('shop:open', (data) => this._tryShowTip('shop'));
    eventBus.on('combat:start', (data) => this._tryShowTip('combat'));
    eventBus.on('state:breakthroughReady', (data) => this._tryShowTip('breakthrough'));
  }

  /**
   * 检查当前是否需要插入引导卡
   * @returns {Object|null} 引导卡或 null
   */
  getGuideCard() {
    if (!this._isActive) return null;
    if (gameState.turn >= this._maxGuideTurns) {
      this._completeTutorial();
      return null;
    }
    if (this._guideCardIndex >= this._maxGuideTurns) return null;

    const cards = this._buildGuideCards();
    const card = cards[this._guideCardIndex];
    if (card) {
      this._guideCardIndex++;
      this._saveState();
      return card;
    }
    return null;
  }

  /**
   * 构建 5 张引导卡
   */
  _buildGuideCards() {
    const path = gameState.path || 'sword';
    const pathNames = { sword: '剑修', spell: '法修', body: '体修', pill: '丹修' };
    const pathName = pathNames[path] || '剑修';

    return [
      {
        id: '_tutorial_1',
        title: '📖 修仙初识 · 修为',
        description: '修为是修仙的根本。每做出一次选择，你可能获得或失去修为。当修为达到当前境界的上限时，就可以尝试突破到下一境界。当前境界：炼气期，上限：100修为。',
        type: 'TUTORIAL',
        choices: {
          left: {
            text: '运转周天（安全）',
            effects: { cultivation: 8, daoHeart: 2 },
            desc: '稳扎稳打，修为+8，道心+2。'
          },
          right: {
            text: '冒险采药（风险）',
            effects: { cultivation: 15, health: -5 },
            desc: '修为+15，但气血-5。注意：气血归零会死亡！'
          }
        }
      },
      {
        id: '_tutorial_2',
        title: '📖 修仙初识 · 气血与寿元',
        description: '气血代表你的生命力，归零则道消身陨。寿元是你的剩余寿命，每经历一次战斗会消耗 1 年。寿元耗尽则会坐化而终。',
        type: 'TUTORIAL',
        choices: {
          left: {
            text: '调息恢复',
            effects: { health: 10, cultivation: 5 },
            desc: '恢复气血+10，修为+5。'
          },
          right: {
            text: '继续修炼',
            effects: { cultivation: 10, health: -3 },
            desc: '修为+10，气血-3。关注你的气血！'
          }
        }
      },
      {
        id: '_tutorial_3',
        title: '📖 修仙初识 · 道心',
        description: '道心代表你的意志力。道心高时，突破境界更容易成功；道心低时，容易走火入魔。某些选择会考验你的道心。',
        type: 'TUTORIAL',
        choices: {
          left: {
            text: '坚守本心',
            effects: { daoHeart: 8, cultivation: 5 },
            desc: '道心+8，修为+5。'
          },
          right: {
            text: '捷径诱惑',
            effects: { cultivation: 18, daoHeart: -5, karmaBad: 5 },
            desc: '修为+18，但道心-5，恶因+5。捷径总有代价。'
          }
        }
      },
      {
        id: '_tutorial_4',
        title: '📖 修仙初识 · 因果',
        description: '你的善恶之举会种下因果种子。善行积累善因，可能在未来触发善缘事件；恶行积累恶因，可能招来灾厄。善恶因可以在"灵根详情"中查看。',
        type: 'TUTORIAL',
        choices: {
          left: {
            text: '施舍凡人',
            effects: { karmaGood: 10, spiritStone: -5, fortune: 5 },
            desc: '善因+10，福缘+5。消耗 5 灵石。',
            karmaSeed: { id: 'tutorial_good', delay: 3, seedType: 'karma' }
          },
          right: {
            text: '漠然离去',
            effects: { cultivation: 8 },
            desc: '修为+8。没有因果。'
          }
        }
      },
      {
        id: '_tutorial_5',
        title: `📖 修仙初识 · ${pathName}之道`,
        description: this._getPathTutorialDesc(path),
        type: 'TUTORIAL',
        choices: {
          left: {
            text: '发挥功法特长',
            effects: this._getPathTutorialEffects(path),
            desc: '体验你的功法专属机制。'
          },
          right: {
            text: '保守修炼',
            effects: { cultivation: 10, daoHeart: 5 },
            desc: '稳健提升修为和道心。'
          }
        }
      }
    ];
  }

  _getPathTutorialDesc(path) {
    const descs = {
      sword: '剑修之道，以剑证道。你拥有更高的暴击率，在战斗中能造成更大伤害。但气血成长较低，需要谨慎应对强敌。',
      spell: '法修之道，万法归一。你拥有更多的选择机会（部分卡牌有额外选项），且灵石获取+20%。善于策略和资源运营。',
      body: '体修之道，肉身成圣。你的气血上限+30，且每轮回血。修炼速度稍慢，但生存能力极强。',
      pill: '丹修之道，以丹入道。丹药效果+50%，且可以通过灵石炼制特殊丹药。善于资源转换和长线运营。'
    };
    return descs[path] || '修仙之道，各有特色。探索你的功法专属机制。';
  }

  _getPathTutorialEffects(path) {
    const effects = {
      sword: { cultivation: 12, critRate: 5 },
      spell: { cultivation: 10, fortune: 5, spiritStone: 10 },
      body: { cultivation: 8, health: 15 },
      pill: { cultivation: 10, spiritStone: 5, fortune: 5 }
    };
    return effects[path] || { cultivation: 10 };
  }

  /**
   * 尝试显示"首次遇到"提示
   */
  _tryShowTip(tipId) {
    if (this._completedTips.has(tipId)) return;
    this._completedTips.add(tipId);
    this._saveState();

    const tips = {
      karma_seed: {
        title: '🌱 因果系统',
        text: '你种下了一颗因果种子。若干回合后，它会发芽为特殊事件。善恶之举都会影响你的因果。'
      },
      quest: {
        title: '📜 支线任务',
        text: '支线任务已激活！完成支线可获得独特奖励。进度可在顶部 HUD 查看。'
      },
      shop: {
        title: '💰 坊市',
        text: '坊市中可以购买法宝、丹药和功法秘籍。商品会随境界提升而更新。'
      },
      combat: {
        title: '⚔ 战斗',
        text: '战斗会消耗寿元。胜利可获得修为和战利品，失败则损失气血。注意敌人的蓄力攻击！'
      },
      breakthrough: {
        title: '🔥 境界突破',
        text: '修为已满！选择突破可进入下一境界。突破成功率受道心和福缘影响，失败会损失气血。'
      }
    };

    const tip = tips[tipId];
    if (tip && typeof ui !== 'undefined') {
      ui._showToast(tip.title, tip.text);
    }
  }

  /**
   * 监听选择事件，推进引导卡
   */
  _onCardChosen(data) {
    if (!this._isActive) return;
    if (data.card && data.card.type === 'TUTORIAL') {
      // 引导卡被选择后，推进到下一阶段
      this._saveState();
    }
  }

  _completeTutorial() {
    this._isActive = false;
    this._saveState();
    if (typeof ui !== 'undefined') {
      ui._showToast('✅ 引导完成', '你已了解修仙的基本规则。仙途漫漫，祝你好运！');
    }
  }

  _saveState() {
    try {
      localStorage.setItem('xiuxian_tutorial', JSON.stringify({
        tips: Array.from(this._completedTips),
        guideIndex: this._guideCardIndex,
        isActive: this._isActive
      }));
    } catch (e) {
      // 静默失败
    }
  }

  reset() {
    this._completedTips.clear();
    this._guideCardIndex = 0;
    this._isActive = true;
    this._saveState();
  }
}

// 全局单例
const tutorialSystem = new TutorialSystem();
```

#### 修改 2：`src/game.js` — 在 `init()` 中初始化 TutorialSystem

```javascript
// 在 init() 方法中（约 game.js:181-347 行）
// 在 questSystem 初始化之后，添加：

// 初始化新手引导系统
if (typeof tutorialSystem !== 'undefined' && tutorialSystem) {
  tutorialSystem.init();
}
```

#### 修改 3：`src/game.js` — 在 `getCurrentCard()` 中优先返回引导卡

```javascript
// 在 getCurrentCard() 方法中（约 game.js:416 行开始）
// 在 FlowDirector / cardSystem.draw() 之前，插入：

// ── 新手引导：前5回合优先显示引导卡 ──
if (typeof tutorialSystem !== 'undefined' && tutorialSystem && !this.combatCoordinator.isInCombat()) {
  const guideCard = tutorialSystem.getGuideCard();
  if (guideCard) {
    this.currentCard = guideCard;
    return this.currentCard;
  }
}
```

#### 修改 4：`src/ui.js` — 增加 `_showToast` 方法

```javascript
/**
 * 显示非侵入式提示 toast
 * @param {string} title
 * @param {string} text
 */
_showToast(title, text) {
  const toast = document.createElement('div');
  toast.className = 'game-toast';
  toast.innerHTML = `
    <div class="toast-title">${title}</div>
    <div class="toast-text">${text}</div>
  `;
  document.body.appendChild(toast);

  // 动画进入
  requestAnimationFrame(() => {
    toast.classList.add('toast-in');
  });

  // 4秒后自动移除
  setTimeout(() => {
    toast.classList.add('toast-out');
    setTimeout(() => toast.remove(), 500);
  }, 4000);
}
```

#### 修改 5：`src/ui.js` — 增加引导卡渲染

```javascript
// 在 renderCard() 中（约 ui.js:541 行）
// 在特殊卡牌分支判断中增加 TUTORIAL 类型：

if (card.type === 'TUTORIAL') {
  this._renderTutorialCard(card);
  return;
}
```

```javascript
/**
 * 引导卡渲染
 */
_renderTutorialCard(card) {
  this.cardTitle.textContent = card.title;
  this.cardDesc.textContent = card.description;
  this.cardType.textContent = '引导';
  this.cardEl.className = 'card card-tutorial';
  this.cardEl.style.backgroundImage = '';
  this.cardPortrait.style.display = 'none';

  // 引导卡使用特殊背景色
  this.cardEl.style.background = 'linear-gradient(135deg, #1a2a3a 0%, #2a3a4a 100%)';
  this.cardEl.style.border = '1px solid rgba(91, 160, 245, 0.4)';

  this.choiceButtons.forEach(btn => btn.classList.remove('visible'));
  const dirs = ['left', 'right'];
  const dirLabels = { left: '←', right: '→' };

  dirs.forEach(dir => {
    const btn = this.getChoiceButton(dir);
    const choice = card.choices[dir];
    if (btn && choice) {
      btn.classList.add('visible');
      btn.querySelector('.choice-text').textContent = `${dirLabels[dir]} ${choice.text}`;
      const descEl = btn.querySelector('.choice-desc');
      if (descEl) descEl.textContent = choice.desc || '';
      // 引导卡选项使用更明显预览
      const previewEl = btn.querySelector('.choice-preview');
      if (previewEl) {
        previewEl.innerHTML = this._buildChoicePreview(choice);
        previewEl.style.display = 'block';
      }
      btn.dataset.mood = this._choiceMoodEnhanced(choice);
    }
  });
}
```

#### 修改 6：`index.html` — 引入 TutorialSystem

```html
<!-- 在 game.js 之后，ui.js 之前引入（约 index.html 的核心基础设施 script 区域） -->
<script src="src/systems/TutorialSystem.js"></script>
```

#### 修改 7：`styles/style.css` — 增加引导卡和 toast 样式

```css
/* 引导卡 */
.card-tutorial { border-color: rgba(91, 160, 245, 0.5); }
.card-tutorial .card-title { color: #5ba0f5; }
.card-tutorial .card-description { color: #b8d4f0; line-height: 1.8; }

/* Toast 提示 */
.game-toast { position: fixed; top: 80px; right: 20px; max-width: 320px; background: rgba(30,40,50,0.95); border: 1px solid rgba(91,160,245,0.4); border-radius: 8px; padding: 14px 18px; z-index: 2500; box-shadow: 0 4px 20px rgba(0,0,0,0.4); transform: translateX(120%); transition: transform 0.4s ease-out; }
.game-toast.toast-in { transform: translateX(0); }
.game-toast.toast-out { transform: translateX(120%); }
.game-toast .toast-title { font-size: 1rem; font-weight: bold; color: #5ba0f5; margin-bottom: 6px; }
.game-toast .toast-text { font-size: 0.85rem; color: #ccc; line-height: 1.5; }
```

### 4.4 预期效果

- ✅ 新玩家进入游戏后，前 5 张卡为引导卡，逐步学习核心机制
- ✅ 引导卡的选项后果清晰标注（如"注意：气血归零会死亡！"）
- ✅ 首次遇到因果/支线/商店/战斗时，弹出友好提示而非让玩家困惑
- ✅ 功法选择时有更详细的差异说明，帮助玩家做出有信息的选择
- ✅ 引导完成后，toast 提示"引导完成"，自然过渡到正常游戏

### 4.5 验收标准

1. 新存档开局后，第一张卡是引导卡"📖 修仙初识 · 修为"
2. 引导卡的选项后果有明确的数值预览和颜色区分
3. 第 5 张引导卡根据所选功法动态生成内容（剑修/法修/体修/丹修不同）
4. 首次种因果时，右上角弹出 toast"🌱 因果系统"说明
5. 引导完成后弹出"✅ 引导完成"toast
6. `localStorage` 中保存 `xiuxian_tutorial` 记录已完成提示

---

## 本章修改汇总

| 修改文件 | 修改类型 | 修改内容 |
|---------|---------|---------|
| `src/ui.js` | 新增方法 | `_renderGoalHint()`、`_computeCurrentGoal()`、`_playBreakthroughAnimation()`、`_buildChoicePreview()`、`_checkDangerThresholds()`、`_choiceMoodEnhanced()`、`_animateAttributeChange()`、`_checkSecondaryAlert()`、`_showToast()`、`_renderTutorialCard()` |
| `src/ui.js` | 修改方法 | `cacheElements()`、`renderTopBar()`、`_renderBreakthroughBar()`、`renderAttributes()`、`renderCard()`、`bindEvents()` |
| `src/game.js` | 修改方法 | `init()`、`getCurrentCard()`、`makeChoice()` |
| `index.html` | 新增 DOM | `top-goal` badge、`choice-preview` 元素、折叠面板结构 |
| `index.html` | 修改 DOM | `attribute-panel` 重构、`top-resources` 紧凑化 |
| `index.html` | 新增 script | `src/systems/TutorialSystem.js` |
| `src/systems/TutorialSystem.js` | 新建文件 | 完整的引导系统类 |
| `styles/style.css` | 新增样式 | 目标提示、突破动画、后果预览、属性动画、引导卡、toast 等 |

---

> **下一章**: [第三章 · 核心循环与叙事](chapter_3.md)
