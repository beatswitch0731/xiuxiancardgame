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
