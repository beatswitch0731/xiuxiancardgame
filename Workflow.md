# Workflow 修改记录

## 2026-06-28：白狐线（white_fox_line）断链修复

### 问题
白狐线第1步选择"掰开铁夹，救它脱困"之后，游戏直接断链，无法正常推进到第2步和第3步。

### 根本原因
1. **数据层与引擎逻辑冲突**：第1步右选项同时种了 `karmaSeed`（`delay=8, realm=foundation`），但支线引擎已通过 `step++` 直接衔接第2步卡，因果种子反而成了干扰项（双重触发风险）。
2. **第2步缺少显式跳转**：`q_whiteFox_2` 的两个选项均无 `questEnd`、无 `questNext`，虽然引擎默认 `step++` 能推进，但路径不明确且依赖隐式行为。
3. **`advanceQuest` 污染数据层**：原代码将 `nextCard.id` 赋值到 `choice.nextCard`（原始 JSON 数据对象），属于副作用污染。

### 修改文件
- `data/quests/white_fox.json`
- `src/systems/QuestSystem.js`
- `src/game.js`

---

## 2026-06-28：全支线系统性断链与触发条件修复

### 问题
6条支线（白狐报恩/天枢秘典/肉身渡劫/剑道传承/禁术之书/失传丹方）+ karma.json 中存在大量断链、无法触发或触发条件冲突（如天枢秘典无法触发，种子发芽找不到卡牌，隐式 step++ 错位）。

### 修复内容
- **`data/quests/tianshu_codex.json`** 等支线数据文件，全加 `questNext` 显式串联；右选（放弃）加 `questEnd`，修复断链。
- **`data/cards/karma.json`**：新增 9 个映射及对应的因果叙事卡牌。

---

## 2026-07-01：FlowDirector与UI阶段反馈集成

- **架构升级**：将 `game.js` 的独立判定队列全面重构，委托给 `FlowDirector.js` 进行相位控制和调度。
- **UI增强**：在 `index.html` 与 `ui.js` 中新增了基于阶段的动态徽章以及卡牌来源提示标签。
- **缺漏补齐**：补全并实现了原设计文档遗漏的秘境分叉选项过渡逻辑 (`DUNGEON_FORK`)。

---

## 2026-07-15：开局暴毙与 DataLoader 404 加载失败修复

### 问题
1. 控制台报错 `DataLoader.js:126 Failed to load resource: the server responded with a status of 404 (Not Found)`
2. 玩家反馈：开局选择剑修，气血直接显示为 0，过一关就会暴毙死亡。

### 根本原因
1. **数据文件名与加载模块名不匹配**：代码中初始化炼气期卡池是 `dataLoader.loadSync('cards:qi')`。而实际数据 file 命名为 `data/cards/qi_condensation.json`，对应的外部请求路径为 `data/cards/qi.json`，导致返回 404 并加载不到任何炼气期卡牌，系统无限陷入兜底卡抽卡逻辑。
2. **功法加成数值与微数值模型冲突**：在重构为“微数值模型”后，玩家基础 `maxHealth` 为 3。而 `paths.json` 配置中，剑修初始气血加成为 `-5`。在 `game.js:start(path)` 中，直接把 `-5` 加到属性上变成了 `-2`，随后被 `setAttribute` 截断为 0，一开局便进入濒死逻辑。同时，体修 `"health": 20` 也会因超出 `maxHealth` 被强行截断到 3，体修高气血加成形同虚设。

### 修复内容

#### 1. 文件重命名
- 将 `data/cards/qi_condensation.json` 重命名为 `data/cards/qi.json`（已通过 ren 成功转换）。

#### 2. 代码逻辑优化（`src/game.js`）
- 在 `game.js` 功法加成应用阶段，当功法带来 `health` 或 `daoHeart` 的增减加成时，先对 `maxHealth` 或 `maxDaoHeart` 的上限值做出相应加减，然后再赋值具体属性，防止属性被初始的低上限截断。

#### 3. 数值合理化（`data/config/paths.json`）
- 调整四大流派的初始 bonuses，使其完美契合微数值模型：
  - **剑修**：`health: -1`（配合初始 3 点血变成 2 点血，高攻击低血量特性）
  - **体修**：`health: 2`（配合初始 3 点血增加上限至 5 点，发挥高气血优势）
  - **法修**：`daoHeart: 2`（偏向防守和道心积累）
  - **丹修**：`spiritStone: 5, fortune: 15`

---

## 2026-07-15：核心系统崩溃与主剧情线断链修复（P0/P1重构交付）

### 问题
1. **世界事件触发崩溃**：开启小波动后，游戏在特定轮次会因为 `GameStateManager.REALM_ORDER` 未定义导致 indexOf 报错，致使整个游戏卡死崩溃。
2. **正魔抉择线第三幕断链**：正魔抉择线虽然配置了庞大的第三幕内战与救赎剧情，但由于筑基期终点决战卡 `dp_end_of_foundation` 的选择项中完全遗漏了 `orthodoxSideChosen` 和 `demonSideChosen` 因果种子的种植，导致主角进入金丹期后无法解锁对应的第三幕剧情，造成长线剧情完全断流。
3. **死亡叙事卡被绕过 & "拒绝天命"重启无效**：
   - 气血或道心耗尽时，UI 层 `renderGame` 粗暴拦截了非 `death_` 开头卡的展示，直接以黑色 `death-screen` 覆盖，使得极具代入感的 6 张死因叙事卡无法展现在玩家面前。
   - 通用死亡卡中配置的“拒绝天命”（`restart: true`）选项触发后，虽然 EffectService 对其进行了重置，但没有触发底层的重新加载，导致游戏直接处于死锁状态。

### 根本原因
1. **类未暴露与实例引用错误**：在 `GameStateManager.js` 末尾只导出了单例实例 `gameState`，并没有将 `GameStateManager` 类暴露到全局。而 `game.js` 直接读取了类上的静态属性 `GameStateManager.REALM_ORDER`，因而抛出 `TypeError` 崩溃。
2. **数据层数据链漏配**：剧情大纲只在特殊的被动卡上配置了选择倾向，但在主动的大分野分歧卡上漏了对应的因果种子配置。
3. **UI 提前拦截与事件总线监听缺失**：UI 没有给死亡卡留出足够的渲染时间，同时底层并没有对 `game:restart` 事件做出重置开局的处理。

### 修复内容

#### 1. 修复世界事件崩溃（`src/game.js`）
- 在 `_pickWorldEvent` 内部获取境界排序时，安全回退读取 `gameState.config.realms?.order` 或预设常量，不再从类上直接硬编码获取，彻底消除 TypeError 崩溃隐患。

#### 2. 打通正魔抉择线第三幕（`data/cards/demon_path.json`）
- 在筑基期终点抉择卡 `dp_end_of_foundation` 的左选（正道）和右选（魔道）上分别补种了 `orthodoxSideChosen` 和 `demonSideChosen` 的因果种子（`delay` 设为 2），使金丹期第三幕的派系支线能够如期解锁触发。

#### 3. 修复死亡叙事卡与重启机制（`src/game.js`）
- 在 `game:restart` 事件触发时，在 `GameLogic` 中自动监听并重新调用 `start()` 重新启动新开局。与已有的死亡卡 `makeChoice` 头部放行逻辑相呼应，打通“死亡 - 叙事 - 选择 - 重启”的全链路。

#### 4. 统一 NPC 标识符规范
- 审查并规范了所有数据配置，确认其完全使用了统一规范的标准全局 NPC ID（如 `xuesha_laozu` 等），无缝衔接好感度与回响系统。

## 2026-07-15：结局系统完整性修复

### 问题
结局卡牌 (`ending_red_dust`, `ending_chaos`) 未定义导致游戏在选择非飞升结局时出现黑屏卡死，并且 UI 和 GameLogic 没有放行结局卡在死亡状态下的展示。

### 本次核心修复内容

1. **补全结局数据定义**
   我们在 `data/cards/qi.json` 中加入了原本只存在于文案设计中的 `ending_red_dust`（红尘兵解） 和 `ending_chaos`（混沌真解） 这两张重要的结局卡，并设定 `"reincarnate": true`，这让玩家在选择相应的毁灭性选项后可以顺利进入转世重修流程，而不再是报错崩溃。

2. **修复数据加载依赖**
   在 `tools/_rebuild_data.js` 的配置中，我们将原本错误的 `'cards:qi': 'data/cards/qi_condensation.json'` 修正为了 `'cards:qi': 'data/cards/qi.json'`，确保最新添加的这些卡牌能够被打包到 `core.json` 中并正确加载。控制台里关于 `core.json` 404 的报错只是因为开发模式下未打包旧的零散文件，这并不影响程序的实际运行。

3. **修复坊市资源不足死锁**
   我们在各个境界的商店卡牌（`q_shop`, `f_shop`, `g_shop`）中统一增加了下划（`down`）的“离开”选项。之前当玩家灵石不足且所有选项都带有 `costCheck` 时，会被弹出“资源不足”提示却无法退出卡牌，导致死锁。现在可以通过向下滑动安全退出商店。

4. **重构国风水墨 UI**
   彻底重构了游戏的开始页面样式。引入了宣纸质感的 SVG 噪点和多层径向渐变底纹；将原有的发光特效重置为深墨色的笔触边缘；修复了输入框与字数统计的错位问题，并改成了留白下划线的风格；最后将“踏入仙途”按钮重制为朱砂红色的仿印章样式。

5. **修复死亡卡牌卡死无法滑动**
   修复了 `src/ui.js` 中因 `gameState.dead` 拦截导致“气血耗尽”等死亡卡（`death_blood_loss`）无法进行任何滑动选择的 Bug。现在处于死亡或结局结算卡牌时，UI 会允许操作从而完成转世重修流程。

## 2026-07-15：全局数值系统与战斗触发去全局化重构

### 问题
在 3 点气血/道心的微数值底盘下，游戏暴露出宏观事件数值超标（秒杀）、强行冲关失败直接死亡（无法触发心魔反噬玩法）、卡牌战斗触发过于粗暴一刀切（全局拦截 `COMBAT` 类型卡牌，直接吞掉原生剧情分支）等重大的机制与数值失衡。

### 修改与重构内容

1. **奇遇事件数值微小化 (`data/cards/*.json`)**
   - 修正了 `qi.json`，`foundation.json`，`nascent.json` 等中残留的宏观事件数值，将 `-10`、`-15` 甚至 `-20` 的秒杀级气血扣减平滑降级为 `-1` 或 `-2`。
   - 移除了 `break_qi`，`break_foundation`，`break_golden` 等选项中会导致玩家出选项即暴毙的无条件扣血。

2. **突破惩罚数值平滑与心魔机制打通 (`src/game.js`)**
   - 将突破失败时的道心直接扣减从 `-15` 减小为 `-1`。在失败后确保玩家道心不会瞬间归零，从而使 `_innerDemonActive` 能安全激活，成功触发后续心魔反噬的一系列博弈与抵抗。

3. **战斗触发去全局化与剧情抉择恢复**
   - **`src/game.js`**：取消了对 `type === 'COMBAT'` 或 `combat` 标签卡牌的粗暴全局拦截。改为只拦截“没有 choices 选项的纯战斗雷劫卡”；对于配有选项的剧情战斗卡（如 `q_fellow` 同门比试），放行其原生渲染。
   - **选项驱动触发**：在 `makeChoice` 中，当玩家选择了配有 `triggerCombat: true` 效果的选项时，才在结算其效果后动态唤起战斗预警。
   - **`qi.json` / `foundation.json` / `nascent.json`**：在同门切磋、宗门任务、元婴猎杀的选择中添加了 `triggerCombat: true`，完美实现“和谈”与“全力一战”的原生支线并存。

4. **打牌战斗平衡性微调 (`data/cards/battle_cards.json`)**
   - 优化战斗手牌：将 `heavy_strike`（重剑无锋）由性价比极低的 2 费 2 伤提升至 2 费 `3` 伤。
   - 平滑怪物的极高伤害：将蓄力凶兽、狂暴妖兽、跨界神念化身、老者的单回合输出限制降到玩家 3 点生命底盘所能抗衡的合理限度。

5. **各境界坊市删卡机制实装**
   - 在炼气期 `q_shop` (15灵石)、筑基期 `f_shop` (25灵石) 以及金丹期 `g_shop` (40灵石) 中新增了 `up` 选项（精简感悟），完美联动 `EffectService.js` 中的 `removeCard` 处理，让玩家可以在商店中精减并剔除卡组里的杂牌，增强构建乐趣。

---

## 2026-07-16：本地代码暂存、分支更名与远程仓库推送

### 操作内容
- 本地积累的全部修补与重构代码（包括 Three.js 画面整合、游戏数据模型微数值平衡调整、结局流程卡死修复、战斗全局拦截重构等）进行暂存并执行本地提交。
- 本地分支由 `feature/threejs-integration` 重命名为 `main` 分支。
- 关联远程 Git 仓库 `https://github.com/beatswitch0731/xiuxiancardgame.git`。
- 首次推送到远程仓库的主分支 `main`（执行 `git push -u origin main`）。
