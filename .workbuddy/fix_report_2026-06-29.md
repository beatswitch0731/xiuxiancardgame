# 漏洞修复报告 — 2026-06-29

## P0 叙事断链修复 ✅

### 问题
`StoryNetworkSystem`、`CompanionSystem`、`FactionSystem`、`NpcSystem` 发出的叙事卡事件（`storynetwork:narrativeCard`、`companion:eventCard`、`faction:eventCard`、`npc:encounterCard`）在 `game.js` 中没有任何监听者，导致所有叙事推进卡永远不进主游戏卡牌流。

### 修复（`src/game.js`）
1. `constructor` 新增 `this._narrativeQueue = []`（优先级队列）
2. `init()` 末尾新增4个事件监听，推入 `_narrativeQueue` 并按 `priority` 降序排列
3. `getCurrentCard()` 在 `_pendingMarket` 之后插入队列弹出逻辑

### 效果
白落霜、剑灵儿、殷血、九尾溯月、天机老人、白刃真人、血煞老祖的弧线推进卡、NPC遭遇卡、派系事件卡，现在都能出现在玩家面前了。

---

## P1 重新诊断 — 非 Bug ✅

### 原报告
`death`/`ending_ascension`/`path_select` 三张卡缺 `realm` 字段，永远进不了抽卡池。

### 实际情况
这三张卡的 `type = "DESTINY"`，而 `CardSystem._drawNormal()` 第531行明确排除 DESTINY 类型。它们通过 `cardSystem.getCard('ending_ascension')` 显式调用，**不需要 realm 字段**。无需修复。

`path_select` 是历史遗留的游戏内功法选择卡，UI 层已有功法选择屏幕，该卡设计已被替代。

---

## P2 数据模块补全 ✅

### 原报告
`ChoiceEchoEngine`/`SceneLayerSystem`/`LitPixelRenderer` 未调用 `.init()`

### 实际情况
这三个系统已正确初始化（`loadData()`/`loadTemplates()`/`async init()`），但它们依赖的数据模块未内联进 `DATA_MODULES`，在 `file://` 协议下导致 `dataLoader.loadSync()` 返回 null。

### 修复（`index.html` DATA_MODULES）
| 模块 | 大小 | 功能 |
|------|------|------|
| `locations:locations` | 6.1KB | 场景叙事系统的三层位置数据（17处位置） |
| `echoes:echo_templates` | 6.6KB | 选择延迟回响引擎的模板数据（9个NPC） |
| `npcs:npc_relations` | 2.2KB | NPC交叉互动关系矩阵 |
| `companions:arcs` | 27.9KB | 全角色弧线数据（白落霜/剑灵儿/殷血/九尾/白刃/天机/血煞 完整五阶段+高潮+终局） |

### 最终状态
- DATA_MODULES: 34个条目，index.html: 421KB
- 21/21 关键模块全部验证通过 ✅

---

## 修改文件汇总

| 文件 | 改动类型 | 说明 |
|------|----------|------|
| `src/game.js` | 逻辑修复 | 构造函数+init()+getCurrentCard() 三处修改，接通叙事队列 |
| `index.html` | 数据内联 | 4个数据模块注入 DATA_MODULES |
