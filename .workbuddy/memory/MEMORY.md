# 修仙卡牌游戏 · 项目状态

## 系统清单

### 核心系统 (src/systems/)
- CombatSystem.js — 回合制战斗v2.0 (L1-L6全部完成)
- CardSystem.js — 9级优先级抽卡 (含MARKET集市卡55级)
- StoryNetworkSystem.js — 四引擎叙事中枢
- KarmaSystem.js — 因果系统
- DestinyWheelSystem.js — 命盘轮转 (P0上瘾钩)
- LegacyFragmentSystem.js — 传承残卷 (P0上瘾钩)
- BreakthroughCountdownSystem.js — 突破倒计时 (P0上瘾钩)
- InnerDemonSystem.js — 心魔反噬 (P1上瘾钩)
- KarmaRippleSystem.js — 因果涟漪 (P2上瘾钩)
- HeavensHintSystem.js — 天机一闪 (P2上瘾钩)
- MarketSystem.js — 集市刷新机制 (福源绑定品质/数量/价格)
- TreasureSystem.js — 法宝装备系统 v2.0 (4槽位装备/卸下/复活/trait查询)

### 六钩上瘾引擎完成度: 6/6 ✅
1. 命盘轮转 ✅
2. 心魔反噬 ✅
3. 传承残卷 ✅
4. 突破倒计时 ✅
5. 因果涟漪 ✅
6. 天机一闪 ✅

### 战斗v2.0六层架构完成度: 6/6 ✅ 🎉
- L1 灵力脉冲 ✅
- L2 架势切换 ✅
- L3 格挡时机 ✅
- L4 连击链 ✅
- L5 参数整合 ✅
- L6 法宝机制 ✅ (v2.0三层模型——属性+trait+CombatSystem钩子)

### L6 法宝三层模型 (v2.0)
- 属性层(passive): ATK/DEF/暴击/福源等基础数值
- 特性层(trait): 15个关键字标签(先手/血战/破甲/妖噬/镜返/空蝉/坚盾/灵涌/续命/定心/镇魂/平衡/避厄/探秘/窥因/轮回)
- 机制层(CombatSystem钩子): _calcDamage/_resolveBlock/_enemyTurn/_endTurn 中检测trait并改写战斗规则
- 25件法宝: 武器×4 + 防具×4 + 饰品×9 + 秘宝×8

### 待处理
- 浏览器实际预览测试
- 存档/读档系统
- 数值平衡调优(P3 Monte Carlo)

## 设计文档
- GDD_TREASURE_DEATH_BALANCE.md v2.0 — 法宝三层模型 + 集市刷新 + 死亡6种 + 复活4件 + 道心重定位 + 参数互连矩阵

## 战斗界面：特效四层架构（2026-10-11 实测定案）

**三层完好，仅一层空。这是本轮最容易被误判为"要从零做特效"的事实。**

| 层 | 位置 | 状态 |
|---|---|---|
| **数据层** semanticVfx | `data/combat/action_presentations.json` | ✅ **162 条 / 644 帧 / 帧文件缺失 0** |
| **注册层** vfxAssets | `data/combat/visual_worlds.json` → `vfxAssets` | ✅ **163 条**，26 条缺 `visibleAlphaBounds` |
| **几何层** | `CombatStagePresenter._placementFor()` 等合同 | ✅ 完好 |
| **绑定层** 遭遇→语义→资产 | — | ❌ **162 条中仅 4 条有效，近乎全空 ← 唯一缺口** |

**结论：特效工作 = 补数据 + 补触发，不是设计 + 造资产。**

- placement 分布：`contact` 11 / `target_state` 2 / `travel` 54 / `source` 96
- 通用键 `damage` / `shield` / `weak` **均存在且 placement 正确**
- **零调用契约**：`CombatStagePresenter` 是 presentation-only 演出层，除 `impact()` 外不得新增副作用；触发逻辑一律放 `DeckCombatUI`
- **几何门禁**：`_anchorPointFor` → `_isUnitPoint` 未定义时返回 `null`，宿主在 `feedback:null` 时**静默失败**
- FX 资产实际是 **148 个目录 / 846 张 PNG**（非 148 个文件），35 个 `pipeline-meta.json`

### FX 资产命名 = 敌人 × 动作类型 四元组
```
ascension_heaven_chain_attack_agc_n14
```
- 后缀统计：`_skill`22 / `_hurt`22 / `_defeat`22 / `_attack`22 / `_impact`18 / `_state`17
- 批次代号 `_agc_n5` ~ `_agc_n14`
- `impact()`（L638，61 行）**全项目零调用**

### `.card-art` 是 14 处规则块的四代设计化石层
| 代 | 位置 | 取向 |
|---|---|---|
| 一 | L261 / L1392 / L2426 | 小插画条（`flex:0 0 78~88px`），卡名在图外 |
| 二 | L4139 + L4158 | 插画铺满整卡，卡名压图 → 需 `::after` 遮罩 |
| 三 | L5602 technique-rail | 插画降饱和压背景层 |
| 四 | L6217 → **L7349** | 恢复满不透明，改 flex 流布局（最终生效）|

另加 `breathing-ui.css` 命中 1 条，媒体查询内 4 处（L381/L1594/L2872/L4413）。

**⚠️ `::after{display:none}`（L7366）是配套的刻意决策，不是事故** ——
L7349 把 `.card-name` 设为 `order:0; flex:0 0 30px` 独立行，文字不再压图，遮罩遂无意义。
**不可复活**，否则插画顶部会出现无意义暗带。

**⚠️ `image-rendering: pixelated` 是继承性生效** —— 声明在 L1399/L4152，L7349 未覆盖。
清理 `.card-art` 死代码时若误删，174 张卡面会**突变为平滑插值**，截图里几乎看不出来。

### 手牌真实 DOM（6~7 层，`DeckCombatUI.js` L4154-4163）
`card-cost` / `card-provenance`(L7367 已 display:none) / `card-name` / `card-art` / `card-effect-strip`(`aria-hidden="true"`，可访问性隐患) / `card-desc` / `card-footer`
- **可用钩子**：`data-path` / `data-rarity` / `data-type` / `data-source` / `data-exhaust` / `data-unavailableReason`(locked|reaction|qi)
- 渲染方法是 `buildCardViewModel` + `render`，**没有 `renderHand`**

### 卡面资产的四个硬事实（实测，勿再重新怀疑）
1. **资产齐全**：174 张卡，`cardArt.image` **174/174 存在，缺失率 0%**
2. **100% 是 1:1 正方图**：`{1024×1024: 112, 1254×1254: 4}` —— 插画窗若用 1.74:1 会**裁掉约 42% 画面**
3. **55/171 = 32.2% 的 `.png` 实为 JPEG**（魔数 FF D8）。**JPEG 无 alpha → 卡面不能用 opacity 做淡入淡出/hover 渐显，必须用 filter 或 overlay**
4. **semantic 元数据覆盖率极低**：semantic 12/174、composition 9/174、reviewStatus 3/174 —— **不可作为阻断性门禁**

### 按钮米色块：真凶是 JS，不是 CSS
```js
// DeckCombatUI.js:659 / :671
this.fleeBtn.innerHTML = '再次确认逃离 <kbd>Esc</kbd>';
this.fleeBtn.innerHTML = '逃离战场 <kbd>Esc</kbd>';
```
JS 用纯文本整体覆写按钮，**销毁 `<span>/<strong>`** → L7516 选择器匹配不到，米色底 `background:#d9d0b6` 呈间歇性故障。
修法：改 `querySelector('strong'/'span').textContent`，**不得靠 CSS 给文本节点上色，伪元素也不行**（无法承载 `.armed` 态差异）。

### 战斗界面关键坐标
- 开发服务器端口 **1966**（`node _dev_server.js`），不是 9966
- 战斗屏 DOM：`index.html` L930-1080
- 样式加载顺序：`equipment.css → style.css → deck-combat.css(L10) → breathing-ui.css(L11)`，breathing-ui 是**第三层覆盖**
- **`styles/glassmorphism.css` 是孤儿文件，从未被 link**
- 战斗样式 7622 行，同批控件定义两遍（L758 旧版 vs L2132+ PC98覆盖层）
- 米色块 L7516/L7520（`background:#d9d0b6`）**是次要现象，真凶是 JS**：
  `DeckCombatUI.js:659/671` 用 `innerHTML` 纯文本覆写按钮，**销毁 `<span>/<strong>`** → L7516 匹配不到
- `.card-art` 被定义 **10 次**，最终生效 L7349；L7366 `::after{display:none}` 关掉装饰层
- **删 4 条死规则**：L2872 / L3962 / L3967 / L3969；保留 L5602 technique-rail 与 L7349
- 真实渲染方法是 `DeckCombatUI.buildCardViewModel` + `render`，**没有 `renderHand`**

### 三条硬约束（重构时不可违反）
1. **`_pathSynergyRestGeometry` 依赖 17 个 DOM 引用**（`deck-combat.css:537-538`）—— 不得增删重排，否则卡牌飞行避障错位穿模
2. **`#combat-notes { display: contents }`**（:7507）必须保持 —— 它是真实 DOM，抹平会让机制条+日志脱离布局流
3. **`breathing-ui.css:755-765 / 796-802`** 用 `#deck-combat-screen` 提高特异性越权重覆盖 combat-hud 之前的层 —— 是叠层污染源

### 新增样式落点
`styles/combat-hud.css`（34KB）置于 `index.html:14` 之后，为最高优先级层。**源头清理比叠层更重要**，否则很快变第五层。

### 截图工具（复用）
`tools/shoot_combat.js`（注假 DOM，看布局骨架可信）
`tools/shoot_combat_entry.js`（走 `deckCombatSystem.init()` 真实入口）
`tools/verify_cardart.js` / `tools/shoot_real_combat.js`
- 运行前**必须** `taskkill //F //IM chrome.exe`，否则 CHROME_FAIL
- Chromium：`%USERPROFILE%/AppData/Local/ms-playwright/chromium-1243/chrome-win64/chrome.exe`
- Node 22 自带 WebSocket，用 `addEventListener` 而非 `ws.on`

## 视觉方向（2026-10-11 美术总监定案，已否决 PC-98 HUD）
- **采纳**：素胎命书 + 朱砂危险信号
- **否决**：PC-98 像素硬边框 + 真元发光宝珠。理由：① 项目母题明令 UI 不做"覆盖在世界外的玻璃面板"；② 文档中 PC98 指像素颗粒质感，非像素图标库；③ 通用青铜边框无法区分五条修路径
- **否决范围涵盖整个 PC-98 HUD 语汇**，不限于硬边框控件
- **`steps()` 阶梯缓动可保留**，但论证应为「模拟 hard-clustered 像素帧间跳变，呼应 `mediaDensity: hard_clustered_retro_pixel`」，**不可称"PC98 原生语言"**（项目规范中 PC98 指渲染密度，非动画传统）
- **朱砂 `#c0392b` 仅三处**：敌人意图预警 / 暴击斩痕 / 玩家受击。普通命中零朱砂（走亮度对比），回合横贯线与屏边 vignette 降级旧白或暗金

### ⚠️ 配色基线尚未确认
`docs/COMBAT_UI_VISUAL_BASELINE_v1.md` 中的色值是**制作人转述，非美术总监原文**，美术总监至今未确认。
**实现时一律引用 token，禁写字面值。**

### ⚠️ token 双定义陷阱
```css
L1782  --combat-cinnabar: #9e3f32;                          /* 旧层叠 */
L4835  --combat-cinnabar: var(--world-cinnabar, #a65345);   /* pc98 world 块内，生效 */
```
**旧层叠写的朱砂值在 pc98 战斗里会被替换成 `#a65345`。** 同类陷阱需警惕。

### z-index 层级（以 L4837-4844 为准，非旧层叠）
```
background 1 / grade 5 / exchange 11 / actors 12 / labels 15 / ui 24 / action 30 / overlay 34
```
**`actors`(12) > `exchange`(11) → FX 会被 actor 卡片遮挡。** `.combat-bottom` 在 pc98 块内实为 `z-index: var(--combat-layer-ui)`=**24**，非旧层叠的 10。

## 汇编纪律（2026-10-11 教训）
汇编他人方案时，**必须逐节标注三态**：`原文主张` / `汇编者转述` / `待确认`。
**不得笼统标「来源：原文」。** 否则下游会把转述当权威，产生返工。

