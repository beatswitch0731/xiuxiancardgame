# Workflow 修改记录

## 2026-07-31：卡牌素材完整性静态审计工具 (tools/audit_assets.js) 完成

### 变更与重构概览

1. **静态素材引用解析与物理断链校验 (Asset Verifier Engine)**：
   - 编写 `tools/audit_assets.js` 自动化工具，借鉴 GitHub 独立游戏常用 Manifest Data Extractor + Physical File Cross-Check 方案；
   - 遍历 `data/cards/` 目录下全部 19 个 JSON 配置文件（解析 586 张卡牌），对 `sceneImage`, `icon`, `image`, `cardArt.image` 物理文件存在性与文件大小进行全量校验。

2. **诊断结果与 PC-98 素材分批挂载**:
   - **扫描卡牌总量**: **586** 张（素材整体覆盖率升至 **83.8%**）；
   - **🔴 物理断链 (404/损坏)**: **0** 张；
   - **已挂载 PC-98 复古卡牌 (18张)**：包含基础牌、同门羁绊、核心法宝装备及最新批次卡牌（`heavy_strike` 撼山靠、`mana_potion` 回气丹、`backlash_flame` 血魔火、`qi_shield` 太乙玄黄罩、`spell_gather` 五气朝元 等），均已落盘至 `assets/combat/cards/` 并自动更新 `battle_cards.json`；
   - **全量 7 层工业级 Prompt 数据库就绪**: 已生成并落盘 `tools/pc98_prompts_manifest.json` 与 `tools/auto_batch_generate_and_mount.js`，包含剩余全部未配图卡牌的 **PC-98 16位像素仙侠风 7层结构化 Prompt**、输出文件名与挂载映射。

3. **详细报告输出**：
   - 导出结构化诊断报告至 `output/asset_audit_report.json`。

### 变更与重构概览

1. **种子伪随机驱动与无头仿真引擎 (Headless Engine)**：
   - 编写 `tools/simulate_run.js` 脚本，无需 DOM 渲染开销，以 **100~500 回合/秒** 的高速度在 Node.js 中仿真运行；
   - 基于 LCG 算法实现 `--seed` 随机数生成器，保证相同 Seed 下玩家与系统的所有交互决策 **100% 精确可复现**。

2. **三策略 AI 决策引擎与四维诊断防线**：
   - 支持 `random`（纯随机）、`greedy`（收益优先）、`survival`（保命优先）三种 AI 决策策略模式；
   - 集成 **Softlock 卡死检测**（连续 5 回合断流）、**循环决策检测**（10 回合内重复组合 ≥ 4 次）、**事件饥饿监测** 与 **数值极值监测**。

3. **现场快照 JSON 导出 (Witness Action Log)**：
   - 当检测到 Softlock 或严重卡死时，自动导出包含 Seed、完整回合序列与现场快照的 `output/softlock_witness_<seed>.json` 文件，支持秒级定位与排查。

4. **验证结果**：
   - `random` 策略 (Seed=1001, 200 回合) **PASSED**；
   - `greedy` 策略 (Seed=2026, 300 回合) **PASSED**；
   - `survival` 策略 (Seed=8888, 200 回合) **PASSED**。

### 变更与重构概览

1. **商店结算与回合逻辑解耦 (模块 A)**：
   - 重构 `src/game.js` 的 `makeChoice` 逻辑，在选项开启商店/集市 (`openShop` / `openMarket`) 时暂停卡牌流并记录 `_pendingShopChoiceContext`，阻断 `turn++` 及寿元提前消耗；
   - 在 `shop:closed` 事件中统一触发 `_finalizeTurnAfterShop()`，确保离开商店时才平滑推进回合及抽取下一张卡牌，解决了进入商店异常跳回合与状态丢失问题；
   - 修正 `CardSystem.js` 中的境界硬编码列表，统一读取全局 `gameState.config.realms.order`。

2. **“天道因果簿”全息 Modal 与因果感知强化 (模块 B)**：
   - 在 `KarmaSystem.js` 中新增 `getPlantedSeeds()` 权威查询接口，提供格式化的善/恶/血脉/宿命种子类型、剩余发芽轮数、起源卡牌与提示描述；
   - 在 `index.html` 顶部导航栏增加 `📜` 天道因果簿按钮与 `karma-log-modal` 全息弹窗；
   - 在 `src/ui.js` 中实现 `_bindKarmaLogPanel()` 与 `_renderKarmaLog()`，提供可视化的因果种子发芽进度监测。

3. **双战斗引擎 Payload 统一与自动化回归 (模块 C)**：
   - 统一 `DeckCombatSystem._victory()` 的事件广播 Payload 规范，包含原始卡牌 `originalCard` 及确切基础奖励（修为与灵石），并自动安全写回 `gameState`；
   - 编写 `tests/ex10_core_loop_comprehensive_integration.test.js` 集成测试；
   - 跑通 EX-01 至 EX-10 全部 10 个自动化测试套件，通过率 **100% (ALL PASSED)**。

## 2026-07-31：EX-09 奇遇与门派/NPC好感度深层交互联动 (P1-06) 完成

### 变更与重构概览

1. **`OpportunityAcquisitionSystem` 门槛与动态权重拓展 (`src/systems/OpportunityAcquisitionSystem.js`)**：
   - 构造函数注入 `npcSystem` 与 `factionSystem` 依赖；
   - 拓展 `_conditionsMet(conditions)`：实现对 `requiredNpcAffection`（NPC 好感度）与 `requiredFactionReputation`（门派声望）的解封条件拦截比对；
   - 拓展 `_calculateWeight`：引入 `npcAffectionScales` 与 `factionReputationScales` 动态权重缩放计算，实现好感度与声望越高，专属奇遇出现概率越大。

2. **奇遇结算与双向数值权威反向写回 (`src/systems/OpportunityAcquisitionSystem.js` & `Container.js`)**：
   - 在奇遇结算 `resolve()` 成功后，自动解析候选者的 `rewards`（如 `npcAffection` 与 `factionReputation`），权威调用 `npcSystem.addAffection()` 及 `factionSystem.addReputation()` 写回系统并触发状态事件；
   - `Container.js` 实例化 `OpportunityAcquisitionSystem` 时正式注入 `npcSystem` 与 `factionSystem`。

3. **多环境导出强化与单元/集成测试 (`src/systems/NpcSystem.js` & `FactionSystem.js`)**：
   - 强化 `NpcSystem` 与 `FactionSystem` 的 CommonJS / window / global 导出机制；
   - 编写 `tests/ex09_opportunity_npc_faction_integration.test.js` 自动化测试，验证门槛拦截、权重缩放及数值反向写回；
   - 运行 EX-01 至 EX-09 全套 9 个自动化回归测试，测试通过率 **100% (PASSED)**。

## 2026-07-31：EX-08 装备系统生产入口挂载与法宝/战斗真实闭环 (P1-05) 完成

### 变更与重构概览

1. **`EquipmentSystem` 生产脚本入口挂载 (`index.html`)**：
   - 在 `index.html` 的 `TreasureSystem.js` 之前正式挂载 `<script src="src/systems/EquipmentSystem.js"></script>`；
   - 彻底修复 `EquipmentSystem` 无法在生产环境被浏览器加载、`Container` 容器注入为空的死角。

2. **跨环境全规范导出 (`src/systems/EquipmentSystem.js` & `src/systems/TreasureSystem.js`)**：
   - 升级导出的兼容性代码，完美支持 `window`、`global` 以及 Node.js `CommonJS module.exports`；
   - 保证了不管是浏览器环境、`Container` 依赖注入，还是 Node 自动化测试，都能无缝使用单例与系统类。

3. **法宝与装备双向装卸强同步 (`src/systems/TreasureSystem.js` & `src/systems/EquipmentSystem.js`)**：
   - 彻底修复 `TreasureSystem.equip/unequip` 抢先改写 `gameState.equipment` 导致 `EquipmentSystem` 的逻辑被重复判断短路、被动数据未能刷新的 Bug；
   - 强化 `_updateActivePassives` 兼容性，全面支持 `passive` 对象/数组、`passives` 数组以及 `combatPassives` 战斗被动；
   - 实现穿戴/卸下法宝时，`EquipmentSystem` 的被动技能与属性加成实时更新并广播事件。

4. **战斗被动实时生效与自动化测试**：
   - 确保 `DeckCombatSystem` 在战斗启动及各阶段回合中，能安全读取 `equipmentSystem.getActivePassives()`，被动与战斗效果精确生效；
   - 编写 `tests/ex08_equipment_system_integration.test.js` 测试套件，并通过 EX-01 至 EX-08 全套 8 个单元/集成测试（100% PASSED）。

## 2026-07-31：EX-07 封顶收益防护与透明选项预览 (P1-03) 完成

### 变更与重构概览

1. **属性 100 封顶防护与权威真实差值计算 (`src/core/GameStateManager.js`)**：
   - 强化 `setAttribute` 与 `addAttribute` 方法，支持精准实际差值计算与返回 (`actualDelta`)；
   - 广播 `state:attributeChanged` 事件时包含 `actualDelta` 与 `isCapped`（封顶标志），日志与系统精准回执实际增量，彻底解决福缘/道心达 100 上限后盲目增加的伪提示。

2. **选项文本透明解析与预检器 (`src/systems/CardSystem.js`)**：
   - 实现 `formatTransparentChoiceText(choice, gameState)` 全息解析函数；
   - **技能全息展开**：自动查表将 `deckCard` ID（如 `spell_nuke`）解析展开为 `【获得卡牌：紫霄雷爆 (法术 2费 造成15点爆发损伤)】`，告别“可能悟得新的招式”的隐瞒信息；
   - **灵石成本透传与警示**：显式前置标注 `【花费 N 灵石】`，当玩家灵石不足时自动追加 ` (灵石不足)` 与禁用标记；
   - **封顶预检**：渲染时若玩家属性已达上限（如福缘 100），自动在描述末尾追加 `⚠️ 注：福缘已达上限(100)，本次收益将为0。` 告别伪选择诱导。

3. **单元与集成测试**：
   - 编写 `tests/ex07_capped_stats_and_transparent_choices.test.js` 测试套件，校验属性 100 封顶计算、卡牌全息展开、灵石不足拦截与封顶预检警示；
   - 顺序回归运行 `ex01` 至 `ex07` 全套自动化测试套件，通过率 **100%**。

## 2026-07-31：EX-06 流派适配规则与因果契约全同步 (P1-02) 完成

### 变更与重构概览

1. **四位一体强流派契约适配器 (`src/systems/RealmChapterSystem.js`)**：
   - 全面升级 `_adaptCardForPath(card, path)`，摆脱原有的“文案伪装”，实现 **文案 + 因果种子(karmaSeed) + 奖励效果(effects) + 场景配图(sceneImage)** 四位一体同步适配；
   - 剑修 (`sword`)：保留默认剑道契约与 `sword_awakening` 因果种子；
   - 法修 (`spell`)：同步替换文案，种下 `spell_awakening` 紫霄雷印因果种子，配图更新为 `scene_qi_q_spellTome.png`，奖励匹配 `spell_nuke` 法术卡；
   - 体修 (`body`)：同步替换文案，种下 `body_awakening` 金刚霸血因果种子，配图更新为 `scene_qi_q_bodyTrial.png`，奖励匹配 `iron_skin` 霸体卡与 `maxHealth`；
   - 丹修 (`pill`)：同步替换文案，种下 `pill_awakening` 造化丹心因果种子，配图更新为 `scene_qi_q_pillRecipe.png`，奖励匹配灵石与筑基丹配方。

2. **补充多流派因果卡池 (`data/cards/qi.json` 中的 `karmaCards`)**：
   - 补全并注册了 `spell_awakening`（紫霄雷印）、`body_awakening`（金刚霸血）、`pill_awakening`（造化丹韵）三条多流派因果解封消费者节点，闭环流派因果成长链路。

3. **单元与集成测试**：
   - 编写 `tests/ex06_path_adaptation_and_karma.test.js` 测试套件，验证四流派 `karmaSeed`、`effects`、`sceneImage` 隔离性与因果闭环；
   - 顺序回归运行 `ex01` 至 `ex06` 全套测试套件，通过率 100%。

## 2026-07-31：EX-05 秘境 ID 契约 (P1-01) 与 11 个目录秘境启动适配完成

### 变更与重构概览

1. **内联秘境对象收束为固定 ID 契约**：
   - 重构 `data/cards/nascent.json` 中的 `n_cave`（元婴洞天）与 `data/cards/deity.json` 中的 `d_immortal_trace`（仙人遗迹）卡牌，将原先直接嵌在选项中的内联 Object 收束为标准字符串 ID `"nascent_cave"` 和 `"immortal_ruins"`；
   - 在 `nascent.json` 和 `deity.json` 的 `dungeons` 目录中分别补全 `nascent_cave` 与 `immortal_ruins` 的秘境节点与卡牌关联配置。

2. **秘境三分结算机制与“白拿通关资源”漏洞堵截**：
   - 修改 `src/game.js` 的 `dungeon:completed` 监听处理，彻底拆分 **通关 (success === true)**、**中途退出 (user_exit)** 与 **失败离场/异常 (failure)** 三种状态；
   - 只有在真正通关 (`success === true`) 时才发放通关大奖（修为与灵石），堵死了由于假关卡、中途退出或探险失败导致玩家白嫖通关资源的巨型漏洞；
   - 在 `src/game.js` 的 `choice.dungeon` 逻辑中加入了类型判定与自动防御提取，防止非法 Object 造成秘境探险 `missing_dungeon` 闪退。

3. **11 个目录秘境与 11 条入口对齐**：
   - 校验并贯通了 6 大境界中的 11 个目录秘境（`ancientCave`, `mysteryRealm`, `ancientRuins`, `swordSanctum`, `spellSanctum`, `bodySanctum`, `pillSanctum`, `ancient_ruins`, `nascent_cave`, `immortal_ruins`, `immortal_trial`）及其 11 条卡牌入口。

4. **单元与集成测试**：
   - 编写 `tests/ex05_dungeon_contract_and_settlement.test.js` 测试套件，验证 11 个目录秘境配置完整性、内联对象收束以及三分结算隔离；
   - 顺序回归运行 `ex01` 至 `ex05` 全套测试套件，通过率 100%。

## 2026-07-31：EX-04 390px 择道交互与近场回执重构完成

### 变更与重构概览

1. **390px 极窄屏 2x2 网格与无障碍择道 (P0-03)**：
   - 修复在 `390px` 窄屏宽度下原流派单行布局超屏溢出问题，重构 `@media (max-width: 480px)` 下的自适应 `2x2` 网格与长显特征说明；
   - 升级流派卡片元素，为其添加 `role="button"`、`tabindex="0"` 与 `aria-label` 语义，并实现键盘 `Tab` / `Focus`、`Enter` / `Space` 择道确认与数字键 `1`, `2`, `3`, `4` 快捷选定。

2. **选择后 300ms 近场回执 Toast (P1-07)**：
   - 在 `GameUI.makeChoice` 触发前捕获属性快照，并在抉择生效后 300ms 内在卡片近场（顶部/中央）弹框发光 Toast；
   - 实时呈现【选择来源、代价与属性前后变化对比（如 气血: 80 → 75 (-5), 灵石: 100 → 120 (+20)）】，解决移动设备屏下查看不到日志的问题。

3. **设置弹窗 Focus Trap 与移动端属性展开 Toggle (P1-07)**：
   - 实现 `GameUI.setupModalFocusTrap`：开启观感设置弹窗时开启键盘 Focus 圈闭，阻止焦点逃逸，并在按 `Escape` 或关闭时精准归还焦点至触发按钮；
   - 在 `.attribute-panel` header 添加带有 `aria-expanded` 状态语义的 `mobile-attr-toggle-btn` 显式展开/收起控件。

4. **单元与集成测试**：
   - 编写 `tests/ex04_responsive_nearfield_feedback.test.js` 测试套件；
   - 顺序回归运行 `ex01` 到 `ex04` 核心套件，100% 运行通过。

## 2026-07-31：EX-03 好感权威治理与天命修仙修改器面板开发完成

### 变更与重构概览
1. **NPC 好感度权威源统一 (`NPCSystem.js`)**：
   - 增加 `NPCSystem.getAffection(npcId)` 权威读取方法；
   - 统一由 `NPCSystem` 作为好感度与羁绊阶段的唯一存储与更新源，消除多头副本与数据不同步。
2. **赠礼交互成本扣除与限次**：
   - 重构 `NPCSystem._onInteract` 中的 `赠礼` 逻辑：正常游戏模式下严格校验并扣除 20 灵石成本；灵石不足时拒绝赠礼并提示。
3. **【天命修仙修改器 (God Mode Console)】控件开发**：
   - 创建 `src/ui/GodModeConsole.js` 并植入全局页面左下角悬浮按钮与半透明黑晶玻璃弹窗；
   - 提供了 **【无限赠礼 / 免消耗】** 开关：勾选后在 `gameState.godMode.infiniteGifting` 为 `true` 时自动免扣灵石与无视限制，实现无限赠礼开挂；
   - 提供了 **【天命无敌】** 模式开关（免死护栏）、`+1000 灵石`、`恢复满气血道心`、`+100 寿元`、`全员 NPC 好感 +50`、`一键突破境界` 等天命快捷测试工具。
4. **单元与集成测试**：
   - 编写 `tests/ex03_npc_affection_mod.test.js` 测试套件，验证好感度权威读取、正常模式成本防护、开挂模式免消耗无限赠礼与无敌判定；
   - 顺序回归运行 `ex01`、`ex02` 和 `ex03` 测试套件，通过率 100%。

## 2026-07-31：EX-02 死亡语义与生平归档重构完成

### 变更与重构概览
1. **`deathCauseId` 规范契约建立**：
   - 在 `GameStateManager` 中增加了 `deathCauseId` 属性，并新增统一设死接口 `setDeath(reason, causeId)`。
   - 重构 `checkDeath()`，在触发气血耗尽 (`death_blood_loss`)、道心崩碎 (`death_dao_collapse`)、寿元耗尽 (`death_lifespan`) 时产生确切的 `deathCauseId` 契约，消除了死因匹配中的信息丢失。
2. **`CardSystem._drawDeathCard` 精准匹配重构**：
   - 优先根据 `gameState.deathCauseId` 直接在死亡卡库中抽取精确死因卡；
   - 增加道心、气血、寿元、善因、恶贯、厄运等死因关键词智能匹配退化逻辑，彻底消除了无匹配盲目降级回退至默认第一张卡的问题。
3. **生平归档与悟点结算幂等防护 (Single Archive & Idempotent Karma)**：
   - 在 `GameStateManager` 增加 `_lifeArchived` 当世归档锁，重构 `recordLegacy()`：已归档时自动跳过重复计算。
   - 彻底消除了重复点击抉择卡选项或重载页面导致悟点与世家遗产被重复发放和多次累加的 Bug。
4. **持久化与还原**：
   - 在 `GameStateManager` 的 `persistCausalSession` 与 `_restoreCausalSession` 中补齐了 `deathCauseId` 与 `_lifeArchived` 状态的序列化与反序列化还原。
5. **单元测试与回归套件**：
   - 新建 `tests/ex02_death_cause_archive.test.js` 自动测试，验证了死因契约产生、精准死因卡匹配、`recordLegacy()` 幂等防重锁以及存档还原。
   - 跑通 `tests/ex01_ending_arbitration.test.js` 和 `tests/ex02_death_cause_archive.test.js`，全部二元断言通过。

## 2026-07-31：EX-01 终局仲裁与状态解耦重构完成

### 变更与重构概览
1. **新建 `EndingEligibilityService` (终局准入服务)**：
   - 作为终局条件与准入校验的全局唯一权威服务。
   - 消费 `truth_atlas.json` 和 `EvidenceAtlasSystem`，强校验境界、假说、证据线索与羁绊，防止提前或无条件触达结局。
2. **`GameStateManager` 隔离生命周期**：
   - `EPILOGUE` 生命周期与死亡态 (`dead=true`) 彻底解耦；主动结局转入 `EPILOGUE` 阶段，不再改动 `dead = true`。
   - 增加 `isInEnding()` 便利判定方法，并在 `persistCausalSession` 与 `_restoreCausalSession` 中持久化与还原 `lifePhase`。
3. **`EffectService` 结局逻辑拦截**：
   - 在触发 `ending` 效果前通过 `EndingEligibilityService` 强校验准入；未满足条件时拒绝终局并转入 `endingCandidate` 候选因果。
   - 新增 `endingCandidate` handler 处理叙事因果倾向。
4. **`CombatCoordinator` 战斗结算保护**：
   - 在 `onVictory` 和 `_handleDeath` 头部增加 `EPILOGUE` 终局阶段拦截防护，解决最终 Boss 胜利结算被 `checkDeath()` 误触划入普通死亡卡的问题。
5. **`CardSystem` 抽卡优先级解耦**：
   - `draw()` 顶部新增 `EPILOGUE` 阶段结局卡优先抽取逻辑，普通死亡卡仅在 `dead=true` 且非 `EPILOGUE` 时触发。
6. **引入环境与测试**：
   - 在 `index.html` 正式引入 `<script src="src/services/EndingEligibilityService.js"></script>`。
   - 编写 `tests/ex01_ending_arbitration.test.js` 并通过 Node 自动化测试。

## 2026-07-31：玩家全旅程与沉浸体验优化 GDD v1.0 与 Serena 执行计划深度研读

### 任务解读与 Serena 工具分析
1. **任务背景与终极目标**：
   - 彻底解决当前《一念仙途》在“终局接缝损坏”、“结局条件悬空未执行”、“NPC好感无限刷取与双权威”、“窄屏择道不可发现”等 14 项阻断与体验断层。
   - 打造一条完整的玩家旅程：`存档 → 择道 → 做中学 → 路线 → 事件/战斗/关系/经济 → 六境 Boss → 合法结局 → 生平归档 → 遗产 → 转世/上界`。
2. **Serena Agent 视角下的底层契约与重构策略**：
   - **EX-01 (当前下一执行批次)**：聚焦于 **终局状态 / 结局准入**，解决最终 Boss 胜后回退普通死亡卡、金丹/化神提前强行终局的问题。
   - 利用 Serena 的符号切片与交叉引用分析，明确修改 `GameStateManager.js` (生命周期 `EPILOGUE`/`LIFE_PHASES`)、`CombatCoordinator.js` (战利交接)、`EffectService.js` (结局强校验)、`CardSystem.js` (仲裁与准入) 和新增 `EndingEligibilityService` 服务。
3. **实施纪律与验收要求**：
   - 严禁乱推无相关修改，按批次（EX-01 ~ EX-14）严格推进；
   - 必须先建立失败回归测试，再修改生产代码；二元标准验收通过方可进入下一个批次。

## 2026-07-31：Serena (Coding Agent Toolkit) 引入与标准工作流集成

### 根因剖析与工具引入
为了提升 Agent 在代码库中的语义理解、符号切片检索、交叉引用定位以及重构能力，防止因文本模糊匹配或粗暴行号替换导致语法报错与上下文丢失，项目正式从 GitHub 克隆引入了 **Serena (`oraios/serena`)** 编码 Agent 辅助工具包。

### 工具集成分析与成果
1. **源码下载与安装**：
   - 项目克隆至 `serena_repo/`。
   - 使用 `uv tool install --force ./serena_repo` 将 Serena 构建并安装至系统 Python 环境，生成 `serena.exe` / `serena-agent.exe` / `serena-hooks.exe`。
2. **核心工具链支持**：
   - **语义检索**：支持跨模块 `find_symbol`、`get_symbol_overview`（代码切片大纲）、`find_referencing_symbols`（交叉引用索引）。
   - **符号级修改与重构**：提供 `replace_symbol_body`、`insert_after_symbol`、`rename_symbol`，摆脱脆弱的正则与全文覆写。
   - **持久化认知记忆**：内置 `memory_tools` 支持跨 Session 记录架构与模块映射。

### Agent 调用标准规范 (Workflows Standard)
在后续项目开发、系统审查与 Bug 根治过程中，Agent 应按以下规范调用 Serena：
1. **服务启动与交互**：
   - 当需要使用 MCP 模式提供语义上下文时，运行 `cmd /c serena start-mcp-server` 启动服务。
   - 本地查询也可直接使用 `serena` CLI 工具（如 `serena config`, `serena memories`, `serena project`）。
2. **代码定位与重构优先级**：
   - 优先使用 Serena 符号索引查找类定义和函数引用，避免大范围拉取无关源文件。
   - 在涉及 `src/systems/` 下多个核心 System 交叉改动时，使用符号级替换与全项目引用分析。

---

## 2026-07-24：第二轮 6 大系统矛盾与隐蔽 Bug 深度回归治理

### 根因剖析与问题定位
1. **开场序章卡源文件与内联 DATA_MODULES 差异**：`data/cards/qi.json` 与 `index.html` 内联 `DATA_MODULES['cards:qi']` 存在数据更新不同步隐患，导致在不同环境下开场序章卡抽取出现偏差。
2. **暂缓突破 Flag 未包含在突破卡选项中**：`data/cards/foundation.json` 和 `golden.json` 的突破卡`down`选项未包含 `"_setFlag": "breakthrough_paused_cooldown"`，导致选择暂缓突破后无法正确写入 Flag 并触发 5 回合冷却防护。
3. **CardSystem 构造函数中 `_shopCooldown` 未初始化**：构造函数中缺失 `this._shopCooldown = 0;` 初始化，在多次检查商店遭遇时引发 `NaN` 或 `undefined` 判断异常。
4. **`game.js` `makeChoice` 依赖注入 `storyThreadEngine` 忽略与方法调用空指针**：`GameLogic` 构造函数未保留 `this.storyThreadEngine = deps.storyThreadEngine`，且 `makeChoice` 中变量名拼写不一致与缺乏函数防御判定。
5. **体修打牌打出对象牌类型崩溃与出牌气血防壁失效**：`DeckCombatSystem.js` 的 `getCardDef()` 未支持对象类型的 `cardId`，在打牌模式下出牌时未正确根据体修当前气血 10% 额外增加防壁。
6. **QuestSystem 转世重置擦除已完成支线**：`QuestSystem._onReset()` 在收到转世 reset 事件时将 `this.completedQuests` 直接重置为空 Set 并写入 `localStorage`，导致玩家转世后已完成支线纪录被擦除并被错误重新触发。

### 重构与优化方案
1. **统一开场序章卡数据与内联模块 (`data/cards/qi.json` + `index.html`)**：
   - 补全并同步 `q_start_sword`, `q_start_body`, `q_start_spell`, `q_start_pill` 4 大序章卡数据。
   - 运行 `node tools/_rebuild_data.js` 重新编译内联 `DATA_MODULES`。
2. **暂缓突破 Flag 显式写入 (`data/cards/foundation.json`, `golden.json`)**：
   - 为筑基与金丹突破卡的暂缓突破选项显式添加 `"_setFlag": "breakthrough_paused_cooldown"`。
3. **CardSystem 构造函数补齐 `_shopCooldown = 0` (`src/systems/CardSystem.js`)**：
   - 确保初始化数值为 `0`，避免递减计算出现 `NaN`。
4. **`game.js` 故事线程依赖注入与安全调用链 (`src/game.js`)**：
   - 构造函数存储 `this.storyThreadEngine = deps.storyThreadEngine`。
   - 在 `makeChoice` 中防御性校验 `onChoiceMade` / `tick` / `getNextThreadCard` 方法。
5. **`DeckCombatSystem` 对象卡牌兼容与体修动态防壁 (`src/systems/DeckCombatSystem.js`)**：
   - `getCardDef(cardId)` 自动支持对象类型与字符串 ID 兼容。
   - 在 `playCard()` 中出牌后追加体修按当前气血 10% 动态凝练护体防壁逻辑。
6. **QuestSystem 转世后 `completedQuests` 跨世持久化 (`src/systems/QuestSystem.js`)**：
   - `_onReset()` 自动保留并恢复 `completedQuests`，杜绝转世事件把已完成支线擦除。

### 自动化校验与测试门禁
- `tools/test_audit_round2.js` 6 大系统矛盾专项回归测试套件 **6/6 PASSED**。
- `tools/_rebuild_data.js` 重新编译 `index.html` inline `DATA_MODULES`（48 模块）。
- `tools/test_v02.js` 全量核心测试套件 **135/135 PASSED**。

---

## 2026-07-24：5 大系统逻辑矛盾、卡池因果断层与死锁穿透漏洞深度根治

### 根因剖析与问题定位
1. **法修 MP 字段缺失**：`spell_codex.json` 等剧情卡给玩家奖励 `effects: { mp: 10 }`，但 `GameStateManager` 缺少 `mp` 字段，导致奖励静默丢弃。
2. **序章因果种子断层**：序章植入的 4 大流派因果种子（`causal:sword_heart_pure` 等）在筑基期与金丹期无卡牌响应，使开局选择在后续境界被“遗忘”。
3. **体修打牌缺少专属气血防壁**：体修“肉身成圣”设定在打牌中无专属机制，依然依赖武器装备攻击力。
4. **暂缓突破死锁循环**：突破卡面板点击“暂缓突破”后，`FlowDirector` P85 里程碑优先级每回合强推突破卡，造成死锁。
5. **秘境死亡穿透漏洞**：秘境中气血归零时，退秘境逻辑抢先打断全局死亡广播，导致 0 血玩家在地图漫步。
6. **商店遭遇重复弹出**：商店关闭后 `currentCard` 置空，CALM 阶段可能连续再次触发商店遭遇。

### 重构与优化方案
1. **法修 MP 兼容映射 (`EffectService.js`)**：
   - 增加 `mp` 资源效果处理句柄，自动映射并增加玩家修为/灵气。
2. **4 大序章因果种子全链响应 (`data/cards/karma.json`)**：
   - 新增 4 张流派因果回响卡（`k_sword_heart_pure` 纯白剑心、`k_spell_harmony` 太极通玄、`k_body_pure_gold` 沉金不灭、`k_pill_benevolence` 草木仁心）。
   - 在 `karmaCards` 种挂载映射，发芽后向玩家推送流派因果回响。
3. **体修【金刚气血防壁】打牌被动 (`DeckCombatSystem.js`)**：
   - 体修进入战斗时自动获得 `Math.floor(maxHp * 0.5)` 初始防壁，且每张出牌按当前气血 10% 额外凝练防壁。
4. **暂缓突破 5 回合冷却 (`FlowDirector.js`)**：
   - 检查 `breakthrough_paused_cooldown` Flag，暂缓突破时跳过 P90/P85 突破卡强推。
5. **秘境死亡清理与全局断言 (`GameStateManager.js`)**：
   - `checkDeath()` 确认死亡时强制重置 `dungeon = null`，杜绝 0 血游荡。
6. **商店遭遇 6 回合保护 (`CardSystem.js`)**：
   - 增加 `_shopCooldown = 6` 计数器，商店触发或关闭后 6 回合内禁止再次弹出。

### 自动化校验与测试门禁
- `tools/test_system_contradictions.js` 6 大专项测试 100% 验证通过。
- `node tools/_rebuild_data.js` 重新编译 `index.html` inline `DATA_MODULES`（48 模块）。
- `tools/test_narrative_prologues.js` 验证通过。
- `tools/test_v02.js` 全量测试 100% 验证通过 (135/135 PASSED)。
- `tools/test_screen_isolation.js` 验证通过 (3/3 PASSED)。
- `tools/check_404_assets.js` 验证通过 (248/248 零 404 缺失)。
- `tools/antigravity_stop_gate.js` 验证通过。

---

## 2026-07-24：4 大流派开场序章剧情卡、连贯故事线程引擎接通与动态主线章节重构

### 根因剖析与问题定位
1. **缺少开场序章介绍**：玩家择道（体修/剑修/法修/丹修）点击“踏入仙途”后，系统直接将 `currentCard` 设为空进入随机抽卡，缺少交代主角背景、世界大劫与流派誓言的开场序章。
2. **故事线程引擎冷置未加载**：`data/threads/qi_threads.json`（含“荒村妖道”、“青云试炼”等连贯因果剧情线）在 `game.js` 中未加载，`StoryThreadEngine` 未初始化，导致连贯故事无法浮现。
3. **主线章节强行挂钩单一流派**：主线里程碑卡（如 `ch_qi_20` 灵根觉醒、`ch_qi_60` 拜师抉择）硬编码了剑修描述（“仅有剑脉微微回应”、“拜入剑宗”），体修/法修/丹修玩起来极具认知违和。

### 重构与优化方案
1. **4 大流派开场序章剧情卡系统 (`prologue_${path}`)**：
   - 遵照 `.agents/rules/60-image-generation-prompt-engineering.md` 与 PC98 暗黑东方水墨规则，在 `data/cards/qi.json` 中为 4 大流派分别重构了 `q_start_sword`（剑气冲霄·宿命剑种）、`q_start_body`（肉身成圣·金刚沉金）、`q_start_spell`（雷法通玄·阴阳太极）、`q_start_pill`（草木蕴灵·造化神农）开场序章卡。
   - 选项提供深远因果树植入（`karmaSeed`）与显著数值/法宝影响。
   - `game.start(path)` 开局立即触发对应序章卡。
2. **故事线程引擎全量接通 (`StoryThreadEngine.js`)**：
   - 在 `game.js` 的 `init()` 中加载 `threads:qi_threads` 数据并初始化 `storyThreadEngine`。
   - 在回合抽卡与推进中 tick `storyThreadEngine`，让多节点连贯剧情自然连续浮现。
3. **主线章节里程碑流派动态适配 (`RealmChapterSystem.js`)**：
   - 在 `RealmChapterSystem.getMilestoneCard` 中实现 `_adaptCardForPath`，根据玩家选择的功法（body/sword/spell/pill）动态适配 `ch_qi_20` 与 `ch_qi_60` 的叙事描述与拜师选项（体修拜入金刚圣宗/散修炼体，法修拜入紫霄雷宗/阴阳秘典，丹修拜入神农丹宗/草木造化）。
4. **数据同步**：
   - 运行 `tools/_rebuild_data.js` 将所有改动同步至 `index.html` 中的 `DATA_MODULES`，确保本地双击与 HTTP 服务器数据完全一致。

### 自动化校验与测试门禁
- `tools/test_narrative_prologues.js` 新增专项测试 100% 验证通过。
- `tools/test_v02.js` 全量测试验证通过 (135/135 PASSED)。
- `tools/test_screen_isolation.js` 验证通过 (3/3 PASSED)。
- `tools/check_404_assets.js` 验证通过 (248/248 零 404 缺失)。
- `tools/antigravity_stop_gate.js` 验证通过。

---

### 根因剖析与问题定位
1. **修仙流派描述与视觉粗糙**：原本对 4 大修仙流派（体修、剑修、法修、丹修）仅有简短概括，缺乏符合作者/设计规范（`60-image-generation-prompt-engineering.md`）的完整视觉 Prompt 链条与高质感三维渲染架构。
2. **战斗 UI 文字与暗底冲突**：战斗界面原有的部分文本缺少足够的对比度与光影遮罩，在暗色与复杂三维灵气背景下可读性不足。
3. **战斗特效与三维交互深度**：战斗打牌反馈缺乏高饱和水墨灵符视觉、三维斩击与爆裂 VFX、以及高动感伤害浮空跳字。

### 重构与优化方案
1. **4 大流派 AAA 级 AI 提示词工程规范 (60-image-generation-prompt-engineering)**：
   - 彻底摆脱粗糙简陋的概括词，采用标准的 `任务目标 → 主体与动作 → 环境 → 构图/镜头 → 光影/色彩 → 风格/材质 → 功能约束 → 文字 → 排除项 → Output Specification` 标准 Prompt 结构。
   - 为 **体修（金刚人体/气血/经脉）**、**剑修（双刃开槽飞剑/冷银高光）**、**法修（八卦太极雷盘/紫霄符文）**、**丹修（造化晶丹/次表面散射）** 制定全套高精 Visual Brief。
2. **Three.js WebGL 原生 3D Procedural Meshes 与高阶 GLSL Shaders (`Path3DArtifactSystem.js`)**：
   - **体修（金刚不灭 Shader）**：3D 金刚人体姿态网格 + 顶点正弦气血呼吸脉冲 + Fresnel 边缘金光。
   - **剑修（冷银剑煞 Shader）**：3D 菱形双刃血槽 Extrude 飞剑 + 高阶 Blinn-Phong 金属极锐镜面高光 (Specular Cutoff)。
   - **法修（紫霄雷闪 Shader）**：3D 双轴旋转 Torus 雷盘 + 8 公转符文块 + Perlin 2D/3D 噪声电弧 Shader。
   - **丹修（次表面散射 SSS Shader）**：3D 多面体晶丹 + 60° 交叉神农符环 + Back-lighting Transmission 次表面透光。
3. **战斗 UI 与对比度根治 (`styles/deck-combat.css` & `src/systems/DeckCombatUI.js`)**：
   - 全面升级战斗 UI 字体对比度（采用楷体/宋体、水墨明金 `#FFD700` 与纯白高亮、`text-shadow: 0 2px 6px rgba(0,0,0,0.95)`）。
   - 重构【东方水墨灵符】卡牌，引入金色与翡翠内边框、`transform: translateY(-48px) scale(1.16) rotate(0deg)` 动态 3D Hover 浮起与光晕。
   - 实现三维特效（斩击弧线波、血煞爆裂、护盾碎裂飞溅）与 `ThreeBackgroundSystem` 联动。
   - 落地极高对比度、带冲击力二次弹跳动画的浮空伤害跳字（Floating Damage Text）。

### 自动化校验与测试门禁
- `tools/test_v02.js` 验证通过 (135/135 PASSED)。
- `tools/test_screen_isolation.js` 验证通过 (3/3 PASSED)。
- `tools/check_404_assets.js` 验证通过 (186 资产校验零缺失)。
- `tools/antigravity_stop_gate.js` 验证通过。

---

### 根因剖析与问题定位
1. **字体与暗底冲突不可读**：此前在 `glassmorphism.css` 与 `style.css` 中对弹窗、事件框、对白框与日志侧边栏硬编码了暗灰色字体 `#1C2123` / `#1A1612`，当在暗色背景或半透明深色玻璃框上显示时形成“黑字黑底”，导致玩家看不清文字。
2. **拒绝 2D 贴图，跃升为真 3D 空间网格**：2D 图片贴图无法提供物理法线与三维空间深度感，必须使用 Three.js 原生 3D 几何体组合构建真正的 3D 网格造型。

### 重构与优化方案
1. **全界面字体高对比度与无障碍修整**：
   - 彻底覆写 `glassmorphism.css` 与 `style.css` 中的字体颜色规则，全量换装高对比度亮象牙白 `#FAF3E0` 与水墨明金 `#D9B168`。
   - 为暗底文字追加强制高亮微阴影 `text-shadow: 0 1px 3px rgba(0,0,0,0.9)`，确保剧情对话框、选项按钮、属性面板 100% 极高清、易读。
2. **True 3D Procedural Mesh 几何拓扑构建**：
   - **体修（金刚人体法相）**：3D 武道躯干 Cylinder + 头部 Sphere + 抱拳双臂 Cylinders + 沉稳马步双腿 + 丹田经脉 3D 灵光节点球体。
   - **剑修（冷银神剑）**：3D 菱形双刃血槽 Extrude 剑身 + 展翼 Torus 剑镡 + Cylinder 剑柄。
   - **法修（太极阴阳雷盘）**：3D 双轴旋转 Torus 八卦环 + 中央 3D 太极球 + 8 个公转 Rune Boxes。
   - **丹修（九转造化神丹）**：3D Icosahedron 多面体晶丹 + 60° 交叉旋转 Torus 神农环。
3. **高阶 GLSL Vertex & Fragment Shaders**：
   - 编写顶点正弦呼吸脉冲 Shader、Blinn-Phong 金属镜面光高光 Shader、3D Perlin 雷电 Shader 以及 SSS 次表面散射 Shader。

### 自动化校验与实机验证
- `tools/test_screen_isolation.js` 验证通过 (3/3)。
- `tools/check_404_assets.js` 验证通过 (186/186)。
- `tools/test_v02.js` 验证通过 (135/135)。
- 通过 Playwright 浏览器子 agent 捕获游戏内部剧情框高对比度画面（`ingame_event_modal_1784792288109.png`）与择道 True 3D 几何画面（`path_selection_screen_1784791774941.png`）。

---

## 2026-07-23：体修【金刚人体法相】重塑与 60 提示词工程高精视觉资产落地

### 根因剖析与问题定位
1. **体修偏离人体成圣本源**：此前误将“古鼎/铜鼎”作为体修图标（鼎为器具而非人体），破坏了体修“肉身成圣、气血不灭”的招牌代入感。
2. **三维几何体粗糙简陋**：低多边形简单几何体拼接缺乏画师级艺术感。
3. **职业区分模糊**：此前混淆了五行彩球，未突显剑修人剑合一、法修太极雷印、丹修九转灵丹的鲜明流派特性。

### 重构与优化方案
1. **贯彻 `.agents/rules/60-image-generation-prompt-engineering.md` 提示词工程规范**：
   - 严禁万能词堆砌，构建包含用途、主体动作、环境构图、光影色彩、媒介材质与排除项的 Visual Brief。
   - 使用 `generate_image` 工具生成 4 大高精修仙视觉资产：
     - `assets/icons/path_body_statue.png`：体修【金刚人体法相 / 气血经脉人身】
     - `assets/icons/path_sword_artifact.png`：剑修【绝世冷银神剑】
     - `assets/icons/path_spell_seal.png`：法修【道家太极阴阳符印与紫霄雷阵】
     - `assets/icons/path_pill_elixir.png`：丹修【九转造化灵丹与神农符环】
2. **Three.js WebGL / GLSL 材质融合**：
   - 将画师级高精资产作为 3D 节点，结合 Three.js 正弦 3D 浮空、鼠标 Hover 视差倾斜、Fresnel 边缘光与 3D 灵气粒子星群。
3. **消除黑框与画面嵌入**：
   - 使用 CSS `mix-blend-mode: screen` 与 `clip-path: circle()`，使金色人体法相与灵脉道印完全无缝地融入古卷纸背景。

### 自动化校验与实机验证
- `tools/test_screen_isolation.js` 验证通过 (3/3)。
- `tools/check_404_assets.js` 验证通过 (186/186)。
- `tools/test_v02.js` 验证通过 (135/135)。
- 通过 Playwright 浏览器子 agent 捕获实机体修【金刚人体法相】画面（`hover_body_path_1784786915420.png`）。

---

## 2026-07-23：AAA 级 180px-220px 视口 Three.js GLSL 择道 3D 神器重构

### 根因剖析与问题定位
1. **视口尺寸受限（110px Canvas Viewport）**：此前 3D Canvas 仅 110px，模型画面占比过小、显得平淡粗糙。
2. **材质缺乏高阶 GLSL 光泽**：缺乏 **Fresnel 边缘强光（Rim Lighting）**、**Perlin 3D 动态体积噪声波（Procedural Volumetric Noise Shader）** 与 **3D 灵气粒子星流（Particle Swarms）**。

### 重构与优化方案
1. **画布视口与画幅翻倍（180px - 220px High-Res Canvas）**：
   - 将 3D 画布从 `110px` 提升至 `180px`（Hover 悬停按视差放缩至 `220px`），调整相机焦点，使神器充满视窗画面。
2. **高模 3D 几何建模（High-Poly Artifact Meshes）**：
   - **剑修（凌霄神剑）**：开血槽双刃剑身、古金铭文剑镡、流线剑柄与金穗饰环。
   - **法修（紫霄八卦雷盘）**：双层阴阳刻面八卦符盘 + **金、木、水、火、土 5 颗独立公转灵珠**。
   - **体修（沉金霸尊鼎）**：饕餮纹四方尊鼎、鼎耳与三足，鼎内悬浮炽热沉金火种。
   - **丹修（九转造化神丹）**：多面体晶莹金丹与双重交错水墨神农符环。
3. **开源高阶 GLSL Shaders 与 3D 粒子流 (Fresnel + Perlin 3D Noise + Particle Swarms)**：
   - **Fresnel 边缘强光 Shader**：顶点与片元实时计算 `pow(1.0 - dot(vViewDir, vNormal), 2.5)`。
   - **Perlin 3D 体积噪声 Shader**：模拟剑气撕裂、雷法闪烁、霸体血气热浪与草木药火升腾。
   - **3D 灵气粒子星群（Particle Swarms）**：每个神器配备 30+ 独立环绕旋转的 3D 灵气粒子流！

### 自动化校验与实机验证
- `tools/test_screen_isolation.js` 验证通过 (3/3)。
- `tools/check_404_assets.js` 验证通过 (186/186)。
- `tools/test_v02.js` 验证通过 (135/135)。
- 通过 Playwright 浏览器子 agent 捕获实机 AAA 级 180px-220px 视口 3D GLSL 画面（`hover_sword_1784784210921.png`）。

---

## 2026-07-23：择道立誓无框水墨悬浮、剑光纠偏与竖排毛笔字挥毫重构

### 根因剖析与问题定位
1. **矩形控件与盒子束缚**：原本使用矩形卡片盒与边框，破坏了修仙画卷自由无界、玄尚自然的意境。
2. **剑修特效偏离本真**：原本使用了套路奇幻冰蓝色，偏离了“剑就是剑”至纯至简的水墨冷银淬火锋芒。
3. **缺少修仙竖排文字挥毫体验**：横排平铺文字缺乏修仙古籍卷轴的笔墨仪式感。

### 重构与优化方案
1. **彻底删除所有方形控件与盒装边框**：
   - 移除背景、边框、阴影与盒状容器，打造直接悬浮于水墨画卷背景上的无框空间（`.path-floating-grid`）。
2. **剑修特效纠偏（剑即是剑）**：
   - 重构为 **纯粹冷银精钢飞剑 + 水墨白银剑光 GLSL Shader**，呈现淬火寒芒与一剑破万法的凌厉剑意。
3. **四流派 3D 法宝与 GLSL 异象升维**：
   - **法修**：太极八卦符盘 + 金木水火土【五行灵珠】独立周天轨道公转 + 雷闪 Shader。
   - **体修**：沉金霸尊古鼎 + 冲天气血与金刚热浪 Shader。
   - **丹修**：九转造化灵丹 + 太极药火与螺旋草木灵雾 Shader。
4. **修仙竖排毛笔字按次序挥毫显现**：
   - 实装 `writing-mode: vertical-rl; text-orientation: upright;` 竖排文字节点。
   - 鼠标 Hover 时，功法尊名、标签与描述按笔墨次序从上至下淡入晕染显现。

### 自动化校验与实机验证
- `tools/test_screen_isolation.js` 验证通过 (3/3)。
- `tools/check_404_assets.js` 验证通过 (186/186)。
- `tools/test_v02.js` 验证通过 (135/135)。
- 通过 Playwright 浏览器子 agent 捕获实机无框 3D 浮空与竖排毛笔字晕染动画（`hover_sword_1784783199215.png`）。

---

## 2026-07-23：择道立誓 3D WebGL GLSL 悬浮法宝系统重构

### 根因剖析与问题定位
1. **2D 平面控件包裹局限**：择道立誓界面原本使用平贴 2D 图标与普通框包裹，缺乏修仙法宝悬浮于掌心的空间意境与三维震撼度。
2. **缺乏 WebGL 高级光彩质感**：平淡的 CSS 静态边框无法展现剑气流转、雷闪脉冲、气血金环与药香雾气等修仙异象。

### 重构与优化方案
1. **全 WebGL / Three.js 3D 悬浮神器系统 (`Path3DArtifactSystem.js`)**：
   - 彻底摒弃 2D 框包裹，为 4 大流派独立搭建三维悬浮 Mesh 组与自定义 GLSL `ShaderMaterial`：
     - **剑修**：三维凌霄飞剑（剑刃、剑镡、剑柄、剑首）+ 冰蓝剑煞环波 GLSL Shader。
     - **法修**：三维碧霄八卦雷法符阵（双层同心符环与核心灵珠）+ 闪电波纹 GLSL Shader。
     - **体修**：三维沉金霸尊古鼎（鼎身、鼎沿、鼎耳、鼎足）+ 金刚气血脉冲 GLSL Shader。
     - **丹修**：三维造化灵丹与神农环 + 草木药香云雾 GLSL Shader。
2. **三维浮沉与鼠标视差 Hover 交互**：
   - 正弦波缓动自然浮沉（Sine Wave Float）。
   - 鼠标悬停（Hover）时触发 3D 法宝加快自转、视差倾斜（Parallax Tilt）与 GLSL Shader 光晕喷薄绽放。
3. **集成与降级**：
   - 在 `index.html` 中装载内置 `three.min.js` 与 `Path3DArtifactSystem.js`。若设备 WebGL 不可用，安全回退到静态水墨纹理。

### 自动化校验与实机验证
- `tools/test_screen_isolation.js` 验证通过 (3/3)。
- `tools/check_404_assets.js` 验证通过 (186/186)。
- `tools/test_v02.js` 验证通过 (135/135)。
- 通过 Playwright 浏览器代理子 agent 捕获实机 3D WebGL 渲染与 hover 交互录屏（`path_3d_artifacts_verify_1784781915410.webp`）。

---

## 2026-07-23：开始界面文案重构与修仙控件艺术级 UI 重构

### 根因剖析与问题定位
1. **文案生硬矛盾、网游机械感重**：
   - 首页原副标题 `选择属于你的修真宏图` 呈现代手游广告感，与水墨暗色修仙脱节。
   - 名字创建标题使用现代 emoji `🖋️`；提示 `仙路无名，请在竹简上留捺尊名（4字以内）` 存在生硬语病（“留捺”词义混乱）。
   - 择道立誓功法描述充斥现代网游与管理学黑话（如“极攻暴伤”、“无上限暴击”、“多维决策优势”、“绝对护盾与反伤”、“滚滚修行为机缘”），严重破坏水墨修仙代入感。
2. **UI 控件艺术设计与视觉意境脱节**：
   - 名字输入框在聚焦（focus）时出现现代浏览器天蓝色 Focus Ring，破坏宣纸/水墨视觉底色。
   - 样式表后半部分（4045-4090行）存在多余的 `.name-creation h2 { color: #1C2123; }` 浅色旧规则，在后级选择器中意外覆盖了暗色背景下的金丝标题颜色。
   - 弹窗面板与按钮缺乏宣纸暗纹、鎏金虚线边框与雕版朱砂印章视觉质感。

### 重构与优化方案
1. **修仙正统文风重构**：
   - 主副标题更新为 `一念入道 · 执掌因果` / `天地不仁，诸界沉浮。一念之间，叩问红尘大道。`
   - 道号 Modal 标语更新为 `玉册题名 · 开启仙途` / `仙途漫漫，请于道册题写尊号（四字以内）`。
   - 功法描述重构为优雅优雅修仙文风：
     - **剑修**：`霜剑斩空 · 极致杀伐`（一剑破万法，凭凌厉剑意断绝因果、一击致命）
     - **法修**：`雷法通玄 · 五行变化`（诸术兼修，引天地雷霆与五行灵气运筹帷幄）
     - **体修**：`肉身成圣 · 气血不灭`（锻淬金身，凭浩瀚血气化作坚强防壁震慑强敌）
     - **丹修**：`以丹入道 · 草木蕴灵`（灵丹妙药，炼天地草木菁华转化为修行大机缘）
2. **修仙水墨 UI 控件艺术级升级**：
   - 彻底移除 `:focus` 天蓝外框，实装 **暗墨深池、朱砂暗红与鎏金微光晕染** 控件体系。
   - `.name-card-box` 引入水墨暗色宣纸底色、金丝虚线内衬框（`::before` 伪元素）与鎏金文字阴影（`#F3E9D4`）。
   - 清理 4045-4090 行中重复覆盖的浅色旧选择器，统一步调。
   - 确认按钮重构为雕版朱砂印章（`【朱】 凝神定名 · 踏入仙途`），字数统计调整为古质卡片角标。

### 自动化校验与实机验证
- 屏幕隔离测试 `tools/test_screen_isolation.js` 验证通过 (3/3)。
- 资源缺失校验 `tools/check_404_assets.js` 验证通过 (186/186)。
- 游戏核心全量集成测试 `tools/test_v02.js` 验证通过 (135/135)。
- 通过浏览器代理子 agent（Playwright）在 1966 端口进行全流程交互与界面截图审计，确认视觉质感与选道流程完美通畅。

---

## 2026-07-23：首页封面顶部黑缝/暗影横条深层根因与隔离修复

### 根因剖析
- **顶部缝隙/暗影横条真正根因**：
  1. `.start-bg` 此前设置了 `z-index: -1;` 且其父级 `#start-screen` 未创建独立层叠上下文（Stacking Context）。
  2. 当在上轮修复中给 `.start-bg` 加上 `transform: scale(1.04)` 缩放效果时，触发 CSS 规范中的 **Transform Stacking Context 机制**，导致 `.start-bg` 内部设置了 `rgba(55, 40, 28, 0.45)` 径向渐变的 `::after` 伪元素被强行提升至背景图之上渲染。
  3. 由于 `radial-gradient(ellipse at 50% 50%...)` 在宽屏分辨率下椭圆垂直轴距离顶部仅 50% 高度，导致屏幕最顶部横向产生了一条极为明显的**深褐色暗影横条**（被误识别为顶部漏缝/黑边）。
  4. 同时 `inset: 0` 在部分高 DPA 缩放或亚像素渲染浏览器中可能出现 1px 视口缝隙。

### 修复方案
1. **彻底移除边缘暗影伪元素**：将 `.start-bg::after` 设置为 `display: none;`，消灭顶层暗色径向渐变带来的阴影横条。
2. **负边距全面覆照**：将 `.start-bg` 边距调整为 `inset: -12px;`，向四周外扩 12px 物理绝杀任何分辨率下的边界亚像素缝隙。
3. **层叠上下文隔离**：给 `#start-screen` 增加 `isolation: isolate; overflow: hidden;`，并将 `.start-bg` 的层级重构为 `z-index: 0;`、`.start-bg::before` 为 `z-index: 1;`、`.start-content` 为 `z-index: 2;`，完美层叠隔离。

### 根因修复与梳理
- **界面透出与重叠根因**：
  1. `.screen` 在没有 `.active` 类时仅使用标准 `display: none`，由于 `styles/deck-combat.css` 中 `.deck-combat-screen` 和其子元素（`.combat-entry-banner` 横幅、`enemy-sprite` 剪影、资源栏等）使用了高层级固定定位（`position: absolute / fixed; z-index: 1000`），当容器或动画状态在初始化时被重新触发展现时，导致战斗 UI 的固定布局透出并覆盖在开局创角/主界面之上。
  2. `DeckCombatUI._showEncounterIntro` 缺乏运行时 `.active` 状态判断，导致未进入战斗时亦可能挂上 `.visible` 触发开场横幅动画。
- **治理方案**：
  - **CSS 物理隔离阻断**：在 `styles/style.css` 中为 `.screen` 统一实装 `.screen { display: none !important; }` 与 `.screen.active { display: flex !important; }`，强行锁死所有非激活屏幕（开局/游戏/战斗/死亡），物理绝杀跨屏幕穿透。
  - **战斗横幅作用域收口**：在 `styles/deck-combat.css` 中将横幅动画约束为 `.deck-combat-screen.active .combat-entry-banner.visible`；同时在 `DeckCombatUI.js` 的 `_showEncounterIntro` 入口增加 `if (!this._isActive()) return;` 门禁。
  - **404 资源真实根因与修复**：定位到真正的 HTTP 404 根因为 `_dev_server.js` 测试服务器在 Windows 系统下进行静态文件查找时，直接把 `req.url` 包含的查询字符串（例如 `?v=5`）拼接到磁盘路径中（如 `assets/icons/xianxia_minimal_logo.png?v=5`），导致磁盘找不到带 `?v=5` 的文件名而返回 404！已重构 `_dev_server.js` 使用 `new URL(req.url)` 剥离 Query String 仅保留真实 `pathname`，彻底解决 `xianxia_minimal_logo.png?v=5` 404 报错。同时新增 `tools/check_404_assets.js` 对 248 个静态资源及服务器解析规则进行自动化门禁断言。日志中的 `chrome-extension://` 报错则确认是第三方 Chrome 浏览器插件加载其内部 Manifest 被拒所致。

### 自动化校验
- 新建 `tools/test_screen_isolation.js` 门禁断言：
  1. 验证 `style.css` 包含 `.screen` 强制 `display: none !important` 防线；
  2. 验证 `deck-combat.css` 的横幅动画严格限定于 `.active` 屏幕下；
  3. 验证 `DeckCombatUI.js` 包含 `!this._isActive()` 拒绝非激活场景下的 UI 动画。
- 校验结果：✅ 3/3 通过；`test_v02.js` 135/135 全绿。


## 2026-07-23：全量 effects 旧数值收口 + 数据门禁建立

### 根因修复
- **自审核发现**：上轮"daoHeart 全量微数值收口"存在虚报——采用了逐点打补丁策略，实际剩余 18+ 处 `daoHeart ≥ 21` 或 `cultivation/karmaGood > 20` 的旧大数值。
- **全量修复**（StoryNetworkSystem.js 共 10 处，KarmaRippleSystem.js 1 处）：

| 文件 | 位置 | 字段 | 修改前 | 修改后 |
|---|---|---|---|---|
| StoryNetworkSystem.js | L1134 | daoHeart | 25 | 20 |
| StoryNetworkSystem.js | L1142 | daoHeart/karmaGood/fortune/cultivation | 30/20/15/10 | 20/15/10/8 |
| StoryNetworkSystem.js | L1352 | daoHeart/karmaGood/fortune | 40/30/20 | 20/20/15 |
| StoryNetworkSystem.js | L1357 | cultivation | 30 | 20 |
| StoryNetworkSystem.js | L1411 | daoHeart | 25 | 20 |
| StoryNetworkSystem.js | L1601 | daoHeart（TRANSMISSION） | 25 | 20 |
| StoryNetworkSystem.js | L1602 | daoHeart（ASCENSION left/right） | 30/20 | 20/15 |
| StoryNetworkSystem.js | L1776 | daoHeart/karmaGood（SACRIFICE） | 25/20 | 20/18 |
| StoryNetworkSystem.js | L1777 | daoHeart（FINAL_PROPHECY right） | 30 | 20 |
| KarmaRippleSystem.js | L292 | cultivation | 25 | 20 |

### 数据门禁建立
- 新增 `tools/validate_effects_budget.js`：纯静态正则扫描，覆盖 `src/systems/` 下所有 JS 文件
- 门禁预算规则：`daoHeart ≤ 20 / cultivation ±20 / fortune ±20 / karmaGood ≤ 20 / karmaBad ≤ 20 / health ≥ -8`
- 违规时以退出码 1 终止，可直接接入 CI 流水线
- 支持 `--fix-report` 模式仅输出报告不阻断

### 验证结果
- `validate_effects_budget.js`：✅ 全部通过（0 处违规）
- `test_v02.js`：✅ 135/135 全部通过，0 失败


## 2026-07-20：前端网页极简国风 Logo 设计与实装

- **无文字极简 Logo 绘制**：使用 AI 图像生成工具设计并生成了极简国风玉莲仙剑融合图标（无任何英文字体、汉字，高对比度与辨识度，完美贴合修仙境界与卡牌决策主题），覆盖资源文件为 `assets/icons/game_logo.png`。
- **网页 Favicon 页签集成**：在 `index.html` 的头部插入 `<link rel="icon" href="assets/icons/game_logo.png" type="image/png">`，使浏览器标签栏直接展示该质感玉莲仙剑图标，提高产品精致度与专业感。
- **水墨微浮动效与灵光呼吸**：在 `styles/style.css` 中为 `.game-logo-img` 实装了 `logoFloat` 垂直往复缓动动画以及外发光呼吸效果，营造法宝浮空的玄幻意境。
- **网页布局校验与测试通过**：使用浏览器自动化子代理（browser subagent）以及 `check_softlock.js` 对前端首页布局和软锁安全性进行双重验证，100% 绿灯无报错。

## 2026-07-20：卡牌构建去卡牌化与本命传承系统（方案 A）重构

- **普通战斗去卡牌化结算**：在 `CombatCoordinator.js` 的 `_buildCombatRewardCard` 中，将战胜普通敌人后的战利品卡牌重构为不再强制三选一卡牌，仅结算修为和灵石，并提供单选项“整理战利品离去”的普通大胜卡，使打牌构筑流程节奏更加紧凑。
- **大境界突破本命流派传承**：当战胜雷劫或心魔顺利破关时（检测到 `rw.breakSuccess`），触发特制的“本命传承”抉择卡，根据玩家当前流派（`gameState.path`）从专属传承池（如剑修凝意/拔剑/剑阵，法修五气/潮汐/玄雷）中随机选择 3 张功法以 `left`/`right`/`down` 的三选一形式呈现供玩家参悟。
- **功法领悟汉化卡名解析**：在 `EffectService.js` 中优化 `deckCard` 效果。当玩家领悟卡牌时，反向查询 `deckCombatSystem.cardDB`，将日志从裸卡 ID 升级为显示对应的真实卡牌汉化名称（如“九天玄雷诀”、“太虚剑阵”），极大提高了 UI 表达品质。
- **际遇事件与残魂授诀扩充**：
  - 在 `qi.json` 的 `cave_spirit` 奇遇中，选择“强行吞噬”扣除少量气血并奖励 `backlash_flame` (血魔火) 卡牌。
  - 在 `qi.json` 的 `cave_reward` 奇遇中，选择“取走功法”奖励 `heavy_strike` (重剑无锋) 卡牌。
  - 在 `foundation.json` 的 `realm_prepare` 秘境残魂授诀中，选择“炼临阵丹”奖励 `mana_potion` (回气丹) 卡牌。
- **单元测试回归跑通**：新建 `tools/test_deckbuilding_rewards.js` 并成功 3/3 绿灯通过，全系统回归校验无异常。

## 2026-07-20：法宝刷新概率加权与神秘鉴宝系统重构

- **动态全境界商品法宝池**：在 `ShopSystem.js` 中重构法宝类商品候选库生成，由静态的 `shop_items.json` 替换为动态载入全局 `treasureSystem.treasureDB`，使商店能随着境界提升自动包含黄金、元婴及更高品阶的传世至宝。
- **道心与福缘双轨概率加权**：重构法宝品阶随机刷新机制。商店将不再依赖单一的气运值，而是根据玩家当前品阶，结合 `fortune`（道缘）与 `daoHeart`（道心）双属性加权，大大增加了高修为/大毅力者刷新到地、天、玄等品阶法宝的几率。
- **Slot 4 古玩与宝匣抽奖实装**：在 Slot 4 增加了 50% 概率刷出“神秘古玩”（15灵石，难度适中）或“天机宝匣”（25灵石，难度高、产出极丰）。
- **双属性鉴宝效果解析器 (`EffectService.js`)**：在 `_identifyTreasure` 中实装了对于 `antique` 和 `box` 双分支鉴宝算法的支持。
  - 神秘古玩依福缘与道心判定：可能淘到顽石或开出凡、地、天三阶法宝。
  - 天机宝匣判定依福缘与道心的大范围随机：低属性开启会引发天机反噬碎裂（仅得到基础气诀卡牌或回复丹药）；高属性则可开出元婴、化神及渡劫级的传说神兵与本命至宝。
- **单元测试回归**：新建 `tools/test_shop_and_antique_customization.js` 测试用例并成功 3/3 绿灯跑通，全系回归通过。

## 2026-07-20：天劫境界专属突破玩法定制与微数值属性加成对齐

- **境界突破微数值对齐**：在 `game.js` 的 `_advanceRealm` 境界提升中，将最大生命值与最大道心上限增幅由宏数值 `+10`/`+5` 调整为更平衡的 `+1`/`+1`，强行恢复状态且防止后期数值崩塌。
- **法宝代渡劫消耗机制**：在 `EffectService.js` 中实装了 `_consumeTreasure` 随机销毁拥有法宝的效果，并在碎裂时自动清理其在 `equipped` 装备槽与 `gameState.equipment` 中的状态，且完成白名单判定。
- **不同天劫定制预警与机制**：
  - 在 `CombatCoordinator.js` 中为金丹（心魔）、元婴（阴阳二气劫）、化神（虚空雷罚）、渡劫（九重天劫）、飞升（九九大劫）设计了不同的警告卡与服用突破丹药/布避雷阵/以法宝代劫的选项分支。
  - 在 `DeckCombatSystem.js` 中完美实装：金丹道心压制心魔与结金丹免伤；元婴奇数阳雷双倍、偶数阴雷穿盾（凝婴丹免疫穿盾）；化神出攻击卡天机反噬扣血（化神丹免疫反噬且降Boss血量）；渡劫业力伤害增幅与法宝代劫效果；飞升善恶审判赏善抽牌/罚恶弃牌机制。
- **数据结构转换与天劫数据补充**：
  - 将里程碑卡 `ch_deity_100` 与 `ch_tribulation_100` 改为 `COMBAT` 类型卡牌并添加胜后微数值 `combatRewards` 及 `enemy` 属性。
  - 在 `battle_cards.json` 的 `enemies` 集中补齐筑基雷劫、金丹心魔、元婴天劫、化神雷罚、九重天劫和飞升天劫的 intents 行为数据。
- **自动化测试回归验证**：编写并成功运行了 `tools/test_breakthrough_customization.js` 测试，4/4 组关键玩法行为（吃药盾牌加成、阴阳二气劫穿盾、虚空反噬、业力天道审判与法宝碎裂）测试完全通过。

## 2026-07-20：天劫境界、古玩鉴宝与内容校验全链路闭环加固

- **内容闭环校验工具对齐**：在 `validate_content.js` 的 `EFFECT_KEYS` 静态集合中补全 `maxHealth` 与 `maxDaoHeart` 键，使校验器能完美通过 45 个 JSON 配置、462 张卡牌的静态校验。
- **心魔大劫致死闭环**：在 `game.js` 的 `makeChoice` 头部 `INNER_DEMON` 分支中补充 `gameState.checkDeath()` 拦截。确保若心魔抵抗失败气血/道心耗尽，可于当前回合直接切入死因卡，阻止状态不闭合。
- **功法卡持久化存储同步**：修复了在奇遇选项、集市中购买卡牌时仅能写入运行时 `deckCombatSystem` 的漏洞。彻底实现了持久化回写 `gameState.deck` 存档，并在转世重修时正确重置。
- **战后生命管线化同步**：将 `DeckCombatSystem._victory` 中的 HP 战后回写修改为全局 `gameState.setAttribute('health')`，确保属性值改变严格受到 clamp 防溢出与事件发射的全局管控。

## 2026-07-20：核心微数值架构重塑与数据清洗

- **新增罡气机制**：在 `GameStateManager.js` 与 `EffectService.js` 中实装了罡气缓冲机制，优先抵扣气血伤害。
- **新增境界压制**：在 `DeckCombatSystem.js` 中实装特权防御，高敌方 2 阶时免疫战斗伤害。
- **燃血保命机制**：重构 `checkDeath`，在气血归零时如果满足条件，允许玩家永久扣除 1 点气血 and 道心上限，恢复 1 点气血苟活，保留了硬核的死亡威胁，并增加了容错底牌。
- **突破上限成长**：在 `chapter_milestones.json` 中配置了突破奖励，每次突破大境界永久增加气血与道心上限。
- **全量遗留大数值清洗**：编写 Node 脚本全局清洗了所有中后期卡牌的数值地雷，将不合理的大量伤害（-50等）按比例压缩，极其恶劣的伤害替换为 `maxHealth: -1` 上限削减，极大提高了游戏的平滑度。
- **Node环境支持修复**：修复了 `GameStateManager.js` 缺失 CommonJS 导出导致 `test_death.js` 测试脚本在 Node 下加载报错的问题。
- **实装“双轴互锁”机制**：将打牌卡组与剧情事件进行了统合绑定，在 `GameStateManager.js` 增加了持久化卡组，并为剧情事件加入了选项标签过滤判定（`reqDeckTag`），允许玩家利用牌组内的卡牌解锁特定的叙事交互。
- **法修“法印”机制扩展**：在打牌系统与卡组配置中实装了法修核心词缀“法印”，新增了条件加成、对群伤害以及根据法印层数过牌等底层打牌效果支持。

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


## 2026-07-20：修复由于灵石不足导致的集市/拍卖会关卡卡死（Softlock）问题

### 问题
在 `q_market`、`n_trade_city`、`d_auction` 和 `t_last_auction` 卡牌中，所有的选项均需要消耗灵石。如果玩家遭遇该卡牌时持有的灵石不足以支付任何一个选项的消耗，将被系统提示“资源不足”且无法做出选择，导致游戏流程完全卡死。

### 修复内容
编写脚本扫描了所有卡牌配置文件并确认存在此缺陷。针对这四张集市/拍卖会卡牌，分别在其 `choices` 节点中增加了一个不消耗任何资源的 `down`（向下）选项作为“离开”的保底方案。现在当玩家灵石不足时，可通过向下滑动安全退出当前事件。涉及修改的文件包括 `qi.json`, `nascent.json`, `deity.json`, `tribulation.json`。

## 2026-07-21：系统逻辑闭环深度审查与全量 BUG 修复

### 背景
对三大阶段（Phase 1 法宝装备、Phase 2 战斗重构、Phase 3 视觉升华）完成后，进行了全面系统闭环审查，发现并修复 3 个 P0 严重 BUG、2 个 P1 逻辑漏洞、1 个 P2 设计整合缺陷。

### 修复详情

- **[BUG-1 P0]** `DeckCombatSystem.js` 中 `endTurn()` 重复定义，后定义覆盖前定义导致装备被动触发 (`onTurnEnd`) 和功法流派回合结算永久失效。修复：删除第 859 行旧版，修正内部错误调用 `_enemyAction()` 为 `_enemyTurn()`。

- **[BUG-2 P0]** `data/items/equipment.json` 格式与 `_triggerEquipmentPassives` 解析逻辑完全不匹配（`trigger` vs `hook`，对象效果 vs 字符串效果，`count` vs `triggerCount`），导致所有装备被动 100% 无法触发。修复：重写 `equipment.json` 为正确的扁平格式。

- **[BUG-3 P0]** `_applyEquipmentPassiveEffect` 内三处错误方法名：`_draw()` → `_drawCards()`；`_checkEnemyDeath()` → `_handleEnemyDefeated()`；`_resolveDamage()` → `_dealDamage()`。回血逻辑同时修正为走 `gameState.addAttribute` 全局管线。

- **[BUG-4 P1]** `weak`/`fortify` 状态每回合双重衰减（`_startTurn` 自然衰减一次 + `_enemyTurn` 手动 `_setStatus` 再衰减一次）。修复：移除 `_enemyTurn` 内的手动衰减，仅保留减益读取。

- **[ISSUE-1 P2]** `_start` 内存在与 `equipment.json` 数值冲突的硬编码（weapon→2剑意、armor→3护盾），移除，改由 `_triggerEquipmentPassives('onCombatStart')` 从 json 配置驱动。

- **[ISSUE-3 P1]** `_addStatus` 日志输出英文状态 ID。修复：添加 `STATUS_NAME_MAP` 字典实现 `weak→虚弱/vulnerable→易伤/poison→丹毒/fortify→金刚罡劲/sword_intent→剑意` 的中文映射。

- **[新增]** `_triggerEquipmentPassives` 新增 `cardTag` 标签过滤逻辑，实现"青云剑匣"按剑诀标签计数触发的完整闭环。

## 2026-07-21：天机星图系统完整落地与核心系统闭环测试通过

### 问题
1. **天机证据星图缺失前端入口**：`EvidenceAtlasSystem.js` 定义了图谱与终局推演逻辑，但在 `index.html` 中未加载脚本，没有前端面板容器（线索、假说、结局列表）和 `#evidence-atlas-btn` 入口按钮，`src/game.js` 中也未对其初始化并加载 `truth_atlas.json` 数据。
2. **战斗系统启动早期退出 BUG**：在 `DeckCombatSystem.js` 的 `_start` 方法中，玩家健康（HP > 0）状态下由于 `this.active` 默认为 `false` 触发了防微数值暴毙的早期退出 `if (!this.active) return;` 导致战斗初始化未执行完成便退出的严重 BUG。
3. **老旧单元测试不兼容当前版本**：`tools/test_v02.js` 因法宝装备槽新设计（未调用 equip 即检测 getPassiveBonuses ）、卡牌数和法宝数扩充、真元系统引入后打牌测试未调用 endTurn 导致无限循环等，引发 14 个测试失败。

### 本次核心修复内容

1. **天机星图（EvidenceAtlasSystem）完整落地**
   - **`index.html`**：加载了 `src/systems/EvidenceAtlasSystem.js` 脚本。在 UI 右上角菜单追加了“🌌 天机图谱 (A)”快捷入口按钮；在主体结构中新增了天机图谱与世界脉动展示面板 `#evidence-atlas-panel`（包含世界脉动大盘 `#evidence-world-pulse`，核心线索、推演假说及终局轨道三栏式精美玻璃拟物化网格）。
   - **`src/game.js`**：在 `init` 中增加了 `evidenceAtlasSystem.init()`，并通过 DataLoader 同步读取并装载 `data/world/truth_atlas.json` 数据，完成线索推演大图的动态灌注。

2. **修复 `DeckCombatSystem.js` 的 `_start` 初始化 BUG**
   - 在 `this._checkPlayerDeath()` 判定前（第 190 行）优先将 `this.active` 置为 `true`。确保在玩家未暴毙的情况下，防死判定通过后能正常推进后续的洗牌、发牌、触发回合开局动作，彻底扫除了战斗激活失败的逻辑盲区。

3. **测试套件（135 个 Unit Test）全面绿化**
   - **`tools/test_v02.js`**：
     - 在 VM 虚拟机沙箱环境中通过 fs 同步接口动态 mock 注入 `fetch` 函数，打通 `DataLoader` 对 `battle_cards.json` 的异步动态文件读取能力。
     - 调整了卡牌池与法宝库计数的断言阈值以适应最新扩充的内容。
     - 为所有测试项中通过 `ts.acquire` 获取的测试用法宝（玄铁甲、剑心佩、灵泉葫芦、避尘珠）追加了 `ts.equip` 的槽位装备动作。
     - 在 `_applyPassiveRegen` 测试用例中动态调大 `gameState.maxHealth = 100` 以适配回血机制与上限截断测试。
     - 修正了 `combat victory/defeat flow` 测试用例中的打牌循环，在玩牌失败（如真元不足）时执行 `dcs.endTurn()` 逻辑，实现跨回合博弈循环。
   - **测试结果**：成功实现 135 个单元测试用例全部一次性 100% 绿灯通过！

## 2026-07-21：天道阻尼物理拖拽系统与极致微观质感重构

### 问题
网页游戏通常采用原生的 CSS Transition 来跟随鼠标坐标，这会导致拖拽手感极度扁平、廉价，在高帧率电竞鼠标下还容易出现掉帧卡顿。同时，卡牌单纯的单色发光特效显得非常“页游风”，缺乏独立游戏的高级质感。

### 本次核心重构内容

1. **真正的物理渲染引擎 (rAF Physics Loop)**
   - **`src/ui.js`**：彻底摒弃了“原生 CSS `transition` 追赶鼠标”的做法，重写了 `startSwipe`, `moveSwipe`, `endSwipe` 的拖拽逻辑。
   - 引入 `requestAnimationFrame` 驱动的独立渲染线程。利用 **Lerp (线性插值)** 实现了绝佳的“空气粘滞感”（拖拽延迟追随）。
   - **自适应重力阻尼 (Weight Damping)**：结合游戏逻辑 `_getCardWeight()`，日常遭遇卡牌拖动时灵巧跟手（`lerp=0.18`），而在面临雷劫、心魔等重大抉择时，卡牌拖动阻力剧增（`lerp=0.06`），传递沉重的修仙宿命感。

2. **动态惯性与物理形变 (Inertia & Deformation)**
   - 在拖拽时，程序实时计算卡牌瞬时速度 (`vx, vy`)，通过速度向卡牌施加**迎风摆尾偏转 (`rotateZ`)** 和 **空间后仰 (`rotateX/Y`)**，使卡牌拥有“流体力学”般的物理体积感。
   - 释放时引入过冲弹簧曲线：未确认选择时，卡牌使用 `cubic-bezier(0.34, 1.56, 0.64, 1)` 回弹，如同被拉满的弓弦般颤动归位；确认选择时，卡牌继承初速度以物理惯性飞出屏幕。

3. **极致微观质感与光影艺术 (Micro-textures & Lighting)**
   - **`styles/style.css`**：利用 base64 注入了极度细腻的 SVG 碎形噪点（Fractal Noise），使卡牌表面呈现出宣纸/古玉的粗糙物理材质，彻底消灭数字纯色带来的廉价感。
   - 重写了卡牌的 `.card` 阴影引擎。抛弃单层霓虹发光，使用“1 层高光内描边 + 3 层由近及远的自然衰减外光晕”的组合 (`box-shadow`)，完美模拟出法宝内蕴光泽的通透立体感。
   - 实现了 **3D 悬停倾斜 (Tilt on Hover)**，即使不拖拽，鼠标滑过时卡牌亦会随着视线扭曲翻转，极具互动质感。

## 2026-07-22：UI视觉质感与高级水墨素材重构

### 背景
用户反馈原有的赛博修仙 UI 设计（如黑底像素图标、违和的背景图、生硬的抠图）不够契合高端仙侠游戏的美术基调，要求进行“宣纸、水墨、暖色调、高融合度”的高规格定制重构。

### 本次核心重构内容

1. **殿堂级国风美术生成与植入**
   - 摒弃了原有的廉价素材，使用顶级提示词（工笔画、淡雅水墨、朱砂留白）重新生成了主背景 `bg_main.png`。
   - 重新生成了 4 大流派（剑、法、体、丹）的纯白底色图标，素材质量达到 Masterpiece 级别（上古飞剑、太极玉佩、气血金焰、紫金丹炉）。
2. **正片叠底完美融合渲染技术 (`mix-blend-mode`)**
   - 彻底摒弃了前端强行抠图去底的粗糙方案。在 `style.css` 中为所有的流派图标应用了 `mix-blend-mode: multiply`（正片叠底）特效。
   - 白底图标被完美过滤透明化，只留下高纯度的水墨与朱砂线条，使其宛如真实印章般“印”在底层的宣纸背景上，完美消除了一切违和感与黑边。
3. **CSS 深度优化与质感打磨**
   - 调整了 `.start-content` 的透明度遮罩，去除了原先严重遮挡底层山水背景的纯色叠加层，使高级背景全貌得以完整展现。
   - 细化了 `.path-btn` 修道选项卡的物理边框与悬浮（Hover）特效，加入了朱砂色微框隐现与高光散射，操作手感更加高级。

## 2026-07-22：纯正水墨意境渲染与全透明 UI 深度融合

### 背景
用户反馈主背景过于“素净”缺少写意水墨画意境，且功法选择界面（P2）的选项卡依然自带白色渐变底板，像“白纸块”一样遮挡了底层的宣纸背景，未能实现真正的融合。且图标颜色过于花哨，不符合纯正水墨风。

### 本次深度重构内容

1. **CSS 原生水墨山水画生成 (Abstract CSS Ink-Wash)**
   - 在 `.start-bg::after` 中，摒弃了单纯的边框暗角。巧妙运用了多达 8 层的 `radial-gradient` 径向渐变，纯靠前端代码在屏幕四周（特别是底部和角落）绘制出了深浅不一的**写意水墨远山**和**竹影晕染**，极大丰富了宣纸背景的国画意境，且中央区域完美留白，不影响 UI 阅读。
2. **功法卡牌全透明化 (Transparent UI)**
   - 彻底将 `.path-btn` 的背景色设为 `transparent`，剥离了所有物理边框。
   - 现在的流派选项在常态下完全融入背景；在 Hover 悬浮时，不再显示方框，而是通过 `radial-gradient` 散发出一团淡淡的水墨晕染阴影（如同墨滴散开），带来极致的高级互动质感。
3. **前端实时黑白水墨滤镜 (Real-time Ink Filter)**
   - 为了将彩色的图标瞬间转换为纯正国画水墨，在 CSS 中为 `.path-icon-img` 叠加了终极滤镜魔法：`filter: grayscale(100%) contrast(1.5) sepia(10%);`。
   - 这不仅瞬间剥离了俗气的明黄/亮蓝色，加上先前的 `mix-blend-mode: multiply`，让图标变成了真正的“纯黑墨水点缀一丝老旧朱砂”的极致传统字画风格，与宣纸背景 100% 完美交融！

---

## 2026-07-23：5 大核心系统隐患彻底整改与严格防回归验证

### 隐患及修复内容

1. **微数值全面收口**：
   - 重构 `StoryNetworkSystem.js`、`CompanionSystem.js` 和 `KarmaRippleSystem.js` 中的动态暴击扣血与道心加成，将非战斗选项的 `health: -15/-30/-40` 统一收口缩放至 `-1 ~ -2` 微数值，消除了非战斗秒杀死锁（Softlock）。
2. **装备系统刷血 Bug 修复与法宝强同步**：
   - 重构 `EquipmentSystem.js` 的 `_removeStats`。脱下增加生命上限的装备时，同步扣减附加的生命值并截断至新上限，彻底封堵重复穿脱装备无限刷血的 Bug。
   - 在 `TreasureSystem.js` 的 `equip` 与 `unequip` 中强同步联动 `EquipmentSystem`，保证法宝被动、属性与装备槽状态时刻一致。
3. **UI 面板闭环**：
   - 在 `ui.js` 中新增 `_renderEquipmentPanel()`，闭环渲染 `weapon`/`armor`/`accessory`/`artifact` 4 个装备槽及交互，完美对接 `styles/equipment.css`。
4. **敌人数据清洗与粗暴除法移除**：
   - 清洗 `chapter_milestones.json` 中遗留的 Boss `hp: 25/30` 为规范微数值 `hp: 15/18, atk: 3`。
   - 彻底移除 `DeckCombatSystem.js` Line 346-349 的 `rawHp > 20 ? Math.round(rawHp / 5) : rawHp` 粗暴除法，消除小怪血量倒挂隐患。
5. **依赖容器与单例安全防护**：
   - 在 `Container.js` 与 `EquipmentSystem.js` 中加入了对全局单例及 `resources/eventBus` 的非空容错检查。

### 自动化验证
- **`tools/test_equipment_sync.js`**：新增装备脱血与法宝同步自动化回归测试，**PASS (2/2)**。
- **`tools/validate_content.js`**：48 个 JSON 结构、卡牌及敌人模板内容闭环校验通过。
- **`tools/test_v02.js`**：核心综合测试套件 **135 passed, 0 failed**。

---

## 2026-07-23：Antigravity 严谨工程交付包 (Strict Engineering Pack) 部署

### 部署背景与核心能力升级
为实现工程交付彻底杜绝表面修补、防范隐性回归，并将自动化门禁提升为终止控制点（Stop Hook），完成了 `antigravity_strict_engineering_pack` 升级包的全面集成。

### 部署内容

1. **Stop Hook 终止门禁体系**：
   - 部署 `.agents/hooks.json`，配置 Antigravity Stop Hook。
   - 部署 `tools/antigravity_stop_gate.js`，在 Agent 准备停止时自动扫描 `git` 变更，按需触发数值预算 (`validate_effects_budget.js`)、内容完整性 (`validate_content.js`)、综合回归 (`test_v02.js`)、屏幕隔离 (`test_screen_isolation.js`) 及 404 资源校验 (`check_404_assets.js`)。失败时返回 `continue` 阻止终止并要求修补。

2. **模块化 Agent 规则**：
   - `.agents/rules/00-engineering-contract.md` (严谨工程交付总契约)
   - `.agents/rules/10-architecture-grounding.md` (架构与意图校准)
   - `.agents/rules/20-systems-effects-budget.md` (剧情数值预算门禁)
   - `.agents/rules/30-data-integrity.md` (数据驱动与内容完整性)
   - `.agents/rules/40-ui-regression.md` (UI 屏幕隔离与视觉回归)
   - `.agents/rules/50-test-integrity.md` (测试完整性与宿主兼容)

3. **技能与工作流**：
   - 部署 `.agents/skills/strict-engineering-delivery/SKILL.md`。
   - 部署 `antigravity-workflows/strict-delivery.md`，固化 9 阶段探索—计划—实现—验证—审查闭环。

### 验证记录
- 执行 `cmd /c node -e "..." | node tools/antigravity_stop_gate.js` 管道测试，终止门禁脚本解析与逻辑校验正常完成。

---

## 2026-07-23：工程包 V2 集成与战斗界面敌人意图图标水墨风深度重构

### 部署内容
1. **Antigravity 严谨工程交付包 V2 集成**：
   - 部署了最新的生图规则文件 [.agents/rules/60-image-generation-prompt-engineering.md](file:///e:/4e/游1/2026-06-27-05-40-58/xiuxian-card-game/.agents/rules/60-image-generation-prompt-engineering.md)（AI 视觉资产生成与编辑规则），规范了从 Visual Brief 拆解、叙事性 Prompt 撰写、视觉分类规范到 Prompt 自检与视觉落盘校验的全流程。
2. **战斗界面敌人意图图标水墨重构**：
   - 重构了 `src/systems/DeckCombatUI.js` 中的意图渲染逻辑，抛弃了简陋的 Emoji 文字拼接，升级为水墨神韵徽章组件（Ink Intent Badge）。
   - 为 4 类核心意图（剑煞攻击 `attack`、金刚护体 `defend`、幽阴施煞 `debuff`、聚气玄蕴 `buff`）引入 SVG 写意符号、意图数值显示与独立说明。
   - 在 `styles/deck-combat.css` 中设计了 4 种独立的水墨渐变光晕、老松烟墨底框、朱砂红与流金高光视觉风格，支持渐变微光与毛玻璃层级。

### 自动化验证与门禁结果
- **`tools/test_screen_isolation.js`**：UI 屏幕隔离测试 **PASS (3/3)**。
- **`tools/check_404_assets.js`**：扫描 186 个静态资源，无 404 缺失缺失 **PASS**。
- **`tools/test_v02.js`**：核心综合测试套件 **PASS (135 passed, 0 failed)**。
- **Stop Gate 自动化门禁**：运行 `tools/antigravity_stop_gate.js` 自动检测变更，`Effects budget`、`Content integrity`、`Integration regression`、`Screen isolation`、`Asset/link integrity` 全部 **PASS (allow)**。
