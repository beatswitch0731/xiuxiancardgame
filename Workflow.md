# Workflow 修改记录

## 2026-06-28：白狐线（white_fox_line）断链修复

### 问题
白狐线第1步选择"掰开铁夹，救它脱困"之后，游戏直接断链，无法正常推进到第2步和第3步。

### 根本原因
1. **数据层与引擎逻辑冲突**：第1步右选项同时种了 `karmaSeed`（`delay=8, realm=foundation`），但支线引擎已通过 `step++` 直接衔接第2步卡，因果种子反而成了干扰项（双重触发风险）。

2. **第2步缺少显式跳转**：`q_whiteFox_2` 的两个选项均无 `questEnd`、无 `questNext`，虽然引擎默认 `step++` 能推进，但路径不明确且依赖隐式行为。

3. **`advanceQuest` 污染数据层**：原代码将 `nextCard.id` 赋值到 `choice.nextCard`（原始 JSON 数据对象），属于副作用污染。

### 修改文件

#### `data/quests/white_fox.json`
- 删除第1步右选项的 `karmaSeed`（其作用已由 `rewardOnComplete.karmaSeeds.foxGratitude` 统一承接）
- 第2步两个选项均加入 `"questNext": "q_whiteFox_3"` 显式跳转

#### `src/systems/QuestSystem.js`
- `advanceQuest()` 中将下一张卡ID存入 `active._pendingNextCardId`（Active quest状态对象），不再污染原始 `choice` 数据
- `quest:advanced` 事件新增 `nextCardId` 字段

#### `src/game.js`
- 新增 `this._questNextCardId` 字段
- `init()` 中监听 `quest:advanced` 事件，将 `nextCardId` 暂存
- `makeChoice()` 中优先使用 `_questNextCardId` 来设置 `currentCard`，保留旧的 `choice.nextCard` 兜底

### 修复后白狐线流程
```
第1步（炼气期5轮+）→ 右选 → step推进到cards[1]，currentCard设为q_whiteFox_2
第2步（q_whiteFox_2）→ 任选 → questNext="q_whiteFox_3"，currentCard设为q_whiteFox_3
第3步（q_whiteFox_3）→ 任选 → questEnd=true → 支线结算，种下foxGratitude（筑基期触发白落霜登场）
```

---

## 2026-06-28：全支线系统性断链与触发条件修复

### 扫描范围
6条支线（白狐报恩/天枢秘典/肉身渡劫/剑道传承/禁术之书/失传丹方）+ karma.json

### 发现的问题

| 类别 | 数量 | 描述 |
|------|------|------|
| 🔴 P0 触发Fatal | 1 | 天枢秘典 `requiredFlags:["tianshuSpellEvent"]` 无任何地方设置，支线永远不触发 |
| 🔴 P0 karmaSeed无映射 | 9 | 剑道传承3个、禁术之书3个、失传丹方3个，种子发芽找不到卡牌 |
| 🔴 P0 断链步骤 | 5 | 天枢Step3、体修Step3、剑道Step2、禁术Step2、丹方Step2，均靠隐式step++无显式questNext |
| 🟡 P1 Priority冲突 | 1 | 天枢秘典与禁术之书均为spell功法priority=7，法修玩家其中一条可能永远不触发 |

### 修复内容

#### `data/quests/tianshu_codex.json`
- 删除 `requiredFlags:["tianshuSpellEvent"]`（无来源）
- priority改为6（避免与禁术之书冲突）
- 新增 `requiredAttributes:{daoHeart:30}` 区分触发时机
- Step1-3全加 `questNext` 显式串联；右选（放弃路径）加 `questEnd`
- karmaSeed移到最终Step4的选项（决定态度后才种下）

#### `data/quests/body_tribulation.json`
- Step1-3全加 `questNext` 显式串联；右选（放弃）加 `questEnd`
- karmaSeed移到Step3左（坚持完整试炼）和Step4左（硬抗天劫）

#### `data/quests/sword_legacy.json`
- Step1-3全加 `questNext` 显式串联；右选（退开）加 `questEnd`
- karmaSeed移到Step3左（以心剑迎战）和Step4左（彻悟剑道）

#### `data/quests/spell_codex.json`
- Step1-3全加 `questNext` 显式串联；右选（放弃）加 `questEnd`
- karmaSeed移到Step2左（学禁术时）和Step3左（拒绝契约时）

#### `data/quests/pill_master.json`
- Step1-3全加 `questNext` 显式串联；右选（婉拒）加 `questEnd`
- karmaSeed移到Step2左（大量炼制时）和Step3左（毁丹时）

#### `data/cards/karma.json`
- karmaCards新增9个映射（swordLegacyStarted/Trial/Echo、spellCodexStarted/Refused/Echo、pillMasterStarted/Sacrifice/Echo）
- 新增9张因果叙事卡牌（完整剧情内容）

### 修复后验证
- 全部26个questNext引用：✅ 26/26
- 全部14个karmaSeed映射：✅ 14/14
- requiredFlags来源：✅ 无悬空flag

## 2026-07-01 FlowDirector与UI阶段反馈集成
- **架构升级**：将 game.js 的独立判定队列全面重构，委托给 FlowDirector.js 进行相位控制和调度。
- **UI增强**：在 index.html 与 ui.js 中新增了基于阶段的动态徽章以及卡牌来源提示标签。
- **缺漏补齐**：补全并实现了原设计文档遗漏的秘境分叉选项过渡逻辑 (DUNGEON_FORK)。
