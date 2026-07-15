# 审查维度：narrative_flow_audit（叙事流程审查）

> **审查日期**: 2026-07-02  
> **审查范围**: data/quests/、data/cards/（karma/rebirth/demon_path/interweave/post_ascension/death）、data/protagonist.json、data/npcs/、data/companions/、data/world/factions.json、data/echoes/、data/threads/、docs/gdd/剧情相关文档  
> **已有审查报告**: `游戏审查报告.md`（2026-07-01）

---

## 审查方法

本次审查采用**数据驱动+剧情追踪**双轨方法：
1. 对6条支线从头到尾逐卡追踪 `questNext` 链路与 `karmaSeed` 闭环
2. 对正魔线（35张卡）逐卡追踪 `requiresFlags`/`karmaSeed` 依赖关系
3. 对因果系统（karma.json 36张卡）反向追溯种子来源
4. 对跨线交织（interweave.json）验证 flag 来源与前置后置关系
5. 对NPC关系网验证 ID 一致性（core_npcs.json ↔ npc_relations.json ↔ npc_cross_cards.json ↔ protagonist.json）
6. 对转世/飞升/道侣系统检查叙事可达性

---

## P0 级问题（立即修复）

### P0-1 正魔线核心内战卡链完全不可达（`demonInternalConflict`/`orthodoxInternalConflict` 孤儿种子）
- **位置**: `data/cards/demon_path.json:1032,1074` + `karmaCards` 映射
- **现象**: 
  - `dp_demon_schism`（血煞宗的内战）要求 `demonInternalConflict` flag，但**没有任何卡牌种植该种子**
  - `dp_orthodox_schism`（正道的裂痕）要求 `orthodoxInternalConflict` flag，同样**没有任何卡牌种植**
  - 由于 `dp_demon_schism` 不可达，其后继卡 `dp_demon_redemption`（殷血的救赎，要求 `demonCivilWarChosen`）和 `dp_demon_ascend`（魔道飞升之秘，要求 `savedYinxue`）也**全部不可达**
- **根因**: 数据设计时规划了种子→卡片的映射，但忘记了在正魔线卡牌选择中种植这些种子。`demonInternalConflict` 和 `orthodoxInternalConflict` 只在 `karmaCards` 映射中作为**键名**出现，从未作为 `karmaSeed.id` 出现在任何卡牌的 `choices` 中。
- **修复建议**: 
  - 在 `dp_demon_factions`（魔道的内斗）左/右选择中根据玩家立场种植 `demonInternalConflict` 或 `orthodoxInternalConflict` 种子
  - 或修改 `dp_demon_schism`/`dp_orthodox_schism` 的 `requiresFlags` 为实际已种植的种子（如 `demonFactionChosen`）

### P0-2 NPC 关系网 ID 全局不一致，交叉叙事系统核心失效
- **位置**: 
  - `data/npcs/npc_relations.json:29,34,45,61,77,93`
  - `data/npcs/npc_cross_cards.json:104,80`
  - `data/protagonist.json:191-230`
- **现象**: 
  - `npc_relations.json` 使用 `jiuwei`、`xue_sha`、`tian_ji` 作为 NPC ID，但 `core_npcs.json` 中实际 ID 为 `jiuwei_suyue`、`xuesha_laozu`、`tianji_laoren`
  - `protagonist.json` 的 `relationshipDefaults` 使用 `bai_luo`、`jian_ling`、`mu_qing`、`jiu_wei` 等**完全不存在的 ID**（应为 `bai_luoxuan`、`jian_linger`、`mu_qinglan`、`jiuwei_suyue`）
  - `npc_cross_cards.json` 的 `npc_cross_tian_ji_jiuwei_prophecy` 使用 `npcIds: ["tian_ji", "jiuwei"]`，而实际应为 `["tianji_laoren", "jiuwei_suyue"]`；`npc_cross_xue_sha_yin_xue_family` 使用 `xue_sha` 而非 `xuesha_laozu`
- **根因**: 多个数据文件独立维护，没有统一的 NPC ID 校验。`npc_relations.json` 和 `protagonist.json` 的编写者似乎使用了一套简称，而 `core_npcs.json` 使用了完整 ID。
- **修复建议**: 
  - 统一所有文件中的 NPC ID 为 `core_npcs.json` 中的标准 ID
  - 在 `npc_relations.json` 中：`jiuwei` → `jiuwei_suyue`，`xue_sha` → `xuesha_laozu`，`tian_ji` → `tianji_laoren`
  - 在 `protagonist.json` 中：`bai_luo` → `bai_luoxuan`，`jian_ling` → `jian_linger`，`mu_qing` → `mu_qinglan`，`jiu_wei` → `jiuwei_suyue`，`tian_ji` → `tianji_laoren`，`xue_sha` → `xuesha_laozu`
  - 在 `npc_cross_cards.json` 中同步修正

### P0-3 白狐因果回响卡「狐影再现」完全不可达（`whiteFox` 种子孤儿）
- **位置**: `data/cards/karma.json:6`（`whiteFox` → `k_fox_returns`）+ `data/quests/white_fox.json`
- **现象**: `karma.json` 中 `whiteFox` 映射到因果卡 `k_fox_returns`（狐影再现，nascent 境界，白衣女子送凝婴丹）。但**没有任何卡牌**在 `choices` 中种植 `whiteFox` 这个种子。白狐支线只种植了 `foxGratitude`（对应 `k_fox_gratitude`）。
- **根因**: 数据设计意图可能是「救白狐」自动种下 `whiteFox` 种子，但实际只种了 `foxGratitude`。`whiteFox` 与 `foxGratitude` 被错误地分离了。
- **修复建议**: 在白狐支线 `q_whiteFox_quest` 的「救狐」选择（right 分支）中添加 `karmaSeed: { "id": "whiteFox", "delay": 8, "realm": "nascent", "priority": 2 }`。

### P0-4 死亡卡叙事系统被UI完全绕过（已有报告P0-4，未修复）
- **位置**: `src/game.js:497` + `src/ui.js:244-247` + `data/cards/death.json`
- **现象**: 死亡卡系统（6张精心撰写的叙事卡：道心崩碎、气血耗尽、厄运缠身、善因过满、恶贯满盈、寿元耗尽）**玩家永远看不到**。`makeChoice` 在死亡时直接 `return false`，UI 直接覆盖为 `death-screen`。
- **根因**: 代码实现与数据设计脱节。死亡卡是数据层的精美叙事内容，但代码层的死亡处理完全不经过它。
- **修复建议**: 移除 `makeChoice` 中的死亡前置拦截，让死亡卡至少展示一次，或干脆删除死亡卡数据以减少维护负担。
- **状态**: ⚠️ **已有报告确认，仍需修复**

---

## P1 级问题（严重缺陷）

### P1-1 正魔线正道导师路径完全不可达（`orthodoxSideChosen` 孤儿）
- **位置**: `data/cards/demon_path.json:909-911`
- **现象**: `dp_orthodox_mentor`（白刃真人的托付）要求 `orthodoxSideChosen` flag，但**没有任何卡牌种植该种子**。进而导致 `dp_sect_heirloom`（镇派之宝）也不可达（它要求 `orthodoxDeepBond`，而 `orthodoxDeepBond` 由 `dp_orthodox_mentor` 种植）。
- **根因**: 与 P0-1 同类问题——种子映射存在但种植缺失。`orthodoxSideChosen` 只出现在 `karmaCards` 映射和 `requiresFlags` 中，从未出现在任何 `karmaSeed` 中。
- **修复建议**: 在 `dp_end_of_foundation` 左选择（选择正道）或 `dp_orthodox_reconnaissance` 左选择（答应正道间谍）中种植 `orthodoxSideChosen` 种子。

### P1-2 大量因果种子「孤儿」——karma.json 中 9 个种子无任何来源
- **位置**: `data/cards/karma.json` karmaCards 映射区
- **现象**: 以下种子在 `karmaCards` 中有映射到精美因果卡，但**没有任何数据文件中的卡牌 choice 种植它们**：

| 种子 ID | 映射卡牌 | 卡牌标题 | 卡牌境界 | 问题 |
|---------|---------|---------|---------|------|
| `whiteFox` | `k_fox_returns` | 狐影再现 | nascent | 无来源（P0-3） |
| `swordBetrayed` | `k_sword_betrayal` | 背叛的剑 | golden | 无来源 |
| `swordHonor` | `k_sword_honor` | 剑的誓言 | nascent | 无来源 |
| `companionSacrifice` | `k_comp_sacrifice` | 道侣的牺牲 | golden | 无来源 |
| `companionTrust` | `k_comp_trust` | 信任何价 | nascent | 无来源 |
| `factionUprising` | `k_faction_uprising` | 势力反目 | golden | 无来源 |
| `factionPeace` | `k_faction_peace` | 势力的感激 | nascent | 无来源 |
| `fortuneWheel` | `k_fortune_wheel` | 命运的轮盘 | golden | 无来源 |
| `betrayedNpc` | `k_betrayed_npc` | 破碎的信任 | nascent | 无来源 |

- **根因**: 因果系统数据层设计完整，但种子种植点未覆盖。这些种子可能计划在代码中由特定系统事件（如战斗、NPC交互、道侣事件）自动种植，但代码中未实现。
- **修复建议**: 为每个种子找到合理的种植点，或在对应卡牌中直接添加 `karmaSeed`。例如：
  - `companionSacrifice`：在 `events.json` 中「生死相依」事件（blx_9）选择「舍命相救」时种植
  - `factionUprising`/`factionPeace`：在势力事件的选择结果中种植
  - `swordBetrayed`：在剑修支线或战斗结果中种植

### P1-3 跨线交织「天劫·无情道/有情道」不可达（`cutMortalTies`/`keepMortalTies` 孤儿）
- **位置**: `data/cards/interweave.json:278-350`
- **现象**: `iw_cut_ties_tribulation` 要求 `cutMortalTies` flag，`iw_keep_ties_tribulation` 要求 `keepMortalTies` flag。但**没有任何数据文件设置这两个 flag**。
- **根因**: 这两个 flag 可能原计划由某个「红尘抉择」卡设置，但该卡缺失或未实现。
- **修复建议**: 在 `data/cards/` 的某个境界卡（如 golden 或 nascent）中添加「断红尘/守红尘」的抉择卡，其选择分别设置 `cutMortalTies` 和 `keepMortalTies` flag。

### P1-4 飞升后结局卡可能先于抉择卡出现（叙事顺序崩坏）
- **位置**: `data/cards/post_ascension.json:412-474`
- **现象**: `pa_dilemma`（选择——三种结局抉择）和 `pa_ending_reform`（新生——完结）都是 `type: NORMAL`，`realm: tribulation`，无 `requiresFlags` 互斥。`pa_ending_reform` 的 `weight: 2`，`pa_dilemma` 的 `weight: 3`。在抽卡系统中，玩家**可能先看到「完结」卡，再看到「抉择」卡**，造成严重的叙事逻辑矛盾。
- **根因**: 飞升后卡池缺少阶段锁或 `requiresFlags` 依赖关系。
- **修复建议**: 为 `pa_ending_reform` 添加 `requiresFlags: { "dilemmaResolved": null }`，并在 `pa_dilemma` 的 choices 中设置 `dilemmaResolved` flag（根据选择设置不同 flag 如 `reformPathChosen`/`destroyPathChosen` 等）。

### P1-5 道侣冲突与和解卡可能顺序颠倒
- **位置**: `data/cards/interweave.json:353-437`
- **现象**: `iw_comp_demon_clash`（道不同——道侣质问魔功）和 `iw_comp_demon_reconcile`（重修旧好——道侣解释）都是独立的 `SPECIAL` 卡，无 `requiresFlags` 依赖。玩家**可能先看到和解卡，再看到冲突卡**。同理，`iw_comp_sect_forbid`（师门阻挠）和 `iw_comp_sect_approve`（师父认可）虽然有 flag 依赖，但 `iw_comp_sect_approve` 要求 `compSectDisapprove`，而 `compSectDisapprove` 由 `iw_comp_sect_forbid` 种植。这部分是正确的。但冲突/和解没有正确依赖。
- **根因**: 缺少 `requiresFlags` 或 `forbiddenFlags` 来强制顺序。
- **修复建议**: 为 `iw_comp_demon_reconcile` 添加 `requiresFlags: { "compDemonClashResolved": null }`，并在 `iw_comp_demon_clash` 的 choices 中设置该 flag。

### P1-6 因果种子 realm 设置与因果卡 realm 要求不匹配（`foxGratitude`）
- **位置**: `data/quests/white_fox.json:30` + `data/cards/karma.json:66-68`
- **现象**: 白狐支线完成时种植 `foxGratitude` 种子，参数为 `delay: 10, realm: "foundation"`。但对应的因果卡 `k_fox_gratitude`（白狐报恩·终章）的 `realm: "deity"`。这意味着种子在筑基期就种下，但因果卡要到化神境界才能抽出。虽然 `delay` 机制可能先存着种子，但 `realm: foundation` 与 `realm: deity` 的跨度（5个境界）导致这张卡的叙事时间线严重脱节。
- **根因**: 种子种植时的 `realm` 参数应该是「触发境界」，但因果卡本身的 `realm` 是「可抽取境界」。如果两者不一致，可能导致种子在错误的时机尝试触发但被卡池过滤掉，或者延迟过久导致玩家遗忘叙事关联。
- **修复建议**: 将 `k_fox_gratitude` 的 `realm` 改为 `nascent` 或 `golden`，使其与种子延迟（10回合+ foundation 到 nascent 的突破时间）更接近。或者将种子 `realm` 改为 `deity`，但这样种子要到化神期才种下，与支线完成时间（炼气期）脱节更远。
- **更好的方案**: 将 `foxGratitude` 分为两个阶段：
  - 阶段1（foundation/golden）：`k_fox_returns`（狐影再现）——种子改为 `whiteFox` 在救狐时种下，延迟 10 回合
  - 阶段2（deity）：`k_fox_gratitude`（终章）——由 `k_fox_returns` 的 right 选择种植 `foxGratitude` 种子

### P1-7 故事线程系统（StoryThread）数据完整但引擎未集成
- **位置**: `data/threads/qi_threads.json` + `docs/gdd/STORY_THREAD_SYSTEM.md`
- **现象**: `qi_threads.json` 定义了 5 条完整的故事线程（荒村妖道、灵石风波、剑冢试炼、药谷叛逃、雾隐秘府），每条线程有触发条件、2-4 个节点、方向分支、结局后果。但 `STORY_THREAD_SYSTEM.md` 明确说明 Phase 1（引擎核心）和 Phase 2（数据）是「实施中」，Phase 3-5 是「待实施/后续」。审查 `game.js`（已有报告）未发现 `threadEngine` 相关的代码集成。
- **根因**: 设计文档与实现进度脱节。数据已经准备好了，但引擎代码尚未接入主循环。
- **修复建议**: 完成 `StoryThreadEngine` 的 `game.js` 集成，或暂时在 `CardSystem.draw` 中手动实现线程卡注入逻辑，避免数据浪费。
- **影响**: 这意味着**炼气期没有任何故事线程会被触发**，玩家体验是纯粹的原子事件卡，与 GDD 描述的「因果连贯感」严重不符。

### P1-8 转世宿命卡效果字段未定义（`deckCard`、`removeCard`）
- **位置**: `data/cards/rebirth.json:38-54`
- **现象**: `rebirth_boon` 左选择有 `effects: { "deckCard": "sword_intent" }`，下选择有 `effects: { "removeCard": true }`。但已有审查报告确认 `game.js` 的 `_applyEffects` 中**没有任何分支处理 `deckCard` 或 `removeCard`**。这两张转世效果完全无效。
- **根因**: 数据层设计超前端代码实现。
- **修复建议**: 在 `src/game.js` 的 `_applyEffects` 或 `EffectService.js` 中添加 `deckCard` 和 `removeCard` 的处理逻辑，或从数据层删除这些效果改用已有支持的效果（如 `cultivation`、`treasure` 等）。
- **状态**: ⚠️ **新增问题**

---

## P2 级问题（体验问题）

### P2-1 道侣系统双轨并行导致维护负担与体验混乱
- **位置**: `data/companions/arcs.json` + `data/companions/events.json`
- **现象**: 两个文件同时定义了同一道侣的剧情内容：
  - `arcs.json`：定义了 5 位道侣的完整弧线（ACQUAINTANCE→KNOWING→DEEP_BOND→SOUL_BOND→DESTINY）+ secretReveal + tribulationClimax + destinyClimax
  - `events.json`：定义了同一道侣的日常/情感/危机事件（如白落霜的「参汤」「采药同行」「人妖殊途」「狐牙」「生死相依」「天命道侣」）
  - 两个系统中有**大量标题和剧情重合**：例如 `arcs.json` 中白落霜的「人妖殊途」与 `events.json` 中 `blx_6` 的「人妖殊途」是同一个剧情场景，但效果数值不同。
- **根因**: 两套道侣系统可能是不同版本的设计方案，未被合并。
- **修复建议**: 明确主次关系——以 `arcs.json` 为主弧线，`events.json` 为日常补充。合并重复内容，或移除其中一个系统。

### P2-2 支线早期终止不设置完成标志，可能导致重复触发
- **位置**: `data/quests/white_fox.json:47-49`
- **现象**: 白狐支线第一张卡 `q_whiteFox_quest` 的左选择「妖兽当诛，取丹炼药」有 `questEnd: true`，但**没有设置任何完成 flag**。该选择获得 `karmaBad: 18` 并结束支线。但 `whiteFoxCompleted` flag 只在 `rewardOnComplete` 中定义，而早期终止是否触发 `rewardOnComplete` 取决于代码逻辑。如果代码不触发，玩家之后可能再次触发白狐支线（因为 `forbiddenFlags` 中的 `whiteFoxCompleted` 不存在）。
- **根因**: 早期终止的 questEnd 路径未显式标记完成 flag。
- **修复建议**: 为所有 `questEnd: true` 的选择添加 `flags: ["whiteFoxCompleted"]`（或对应支线完成 flag），确保与 `forbiddenFlags` 保持一致。

### P2-3 多个 NPC 交叉卡引用错误 ID（同 P0-2 的局部表现）
- **位置**: `data/npcs/npc_cross_cards.json`
- **现象**: 
  - `npc_cross_tian_ji_jiuwei_prophecy` 使用 `npcIds: ["tian_ji", "jiuwei"]`，应为 `["tianji_laoren", "jiuwei_suyue"]`
  - `npc_cross_xue_sha_yin_xue_family` 使用 `npcIds: ["xue_sha", "yin_xue"]`，应为 `["xuesha_laozu", "yin_xue"]`（`yin_xue` 正确）
- **根因**: 同 P0-2。
- **修复建议**: 同步修正。

### P2-4 正魔线 `karmaCards` 映射与 `requiresFlags` 不一致
- **位置**: `data/cards/demon_path.json:5-16`
- **现象**: `karmaCards` 映射中 `demonInternalConflict` → `dp_demon_schism`，但 `dp_demon_schism` 的 `requiresFlags` 是 `demonInternalConflict`（自指）。`orthodoxInternalConflict` → `dp_orthodox_schism` 也是自指。`betrayalChoice` → `dp_final_stand`，但 `dp_final_stand` 的 `requiresFlags` 是 `demonSideChosen`（不是 `betrayalChoice`）。
- **根因**: `karmaCards` 映射与卡牌实际依赖关系不同步。`karmaCards` 的设计意图可能是「种子发芽时抽这张卡」，但卡牌的 `requiresFlags` 却要求另一个条件。
- **修复建议**: 统一逻辑——要么让 `karmaCards` 映射成为种子→卡片的唯一触发条件（移除 `requiresFlags`），要么让 `requiresFlags` 与 `karmaCards` 映射一致。

### P2-5 剧情文档与数据实现存在偏差
- **位置**: `docs/gdd/STORY_THREAD_SYSTEM.md` vs `data/threads/qi_threads.json`
- **现象**: 
  - GDD 文档中线程示例使用 `cardId: "q_help_injury"` 作为触发条件，但 `qi_threads.json` 实际使用 `cardId: "q_beggar"`、`"q_spiritStone"`、`"q_swordTomb"` 等。触发卡 ID 不一致。
  - GDD 文档描述线程节点有 `maxActive` 和 `unlockThread` 字段，但 `qi_threads.json` 中缺失这些字段。
- **根因**: 文档先行，数据后行，但未同步更新。
- **修复建议**: 更新 GDD 或数据，保持一致。

### P2-6 转世卡 `minLifeCount` 要求过高，部分卡几乎不可见
- **位置**: `data/cards/rebirth.json`
- **现象**: `rb_heaven_final`（天道印记·终章）要求 `minLifeCount: 5`，`rb_heaven_4` 要求 4。这意味着玩家需要转世 5 次才能看到最终的天道印记剧情。在现有版本中，转世系统受死亡卡绕过（P0-4）和存档 bug（P1-4）影响，实际很难达到这么高的转世次数。
- **根因**: 设计面向长期游玩，但核心机制（死亡/转世）存在缺陷导致难以触达。
- **修复建议**: 先修复 P0-4 和 P1-4，再评估转世频率。或暂时降低 `minLifeCount` 要求以测试内容。

### P2-7 因果卡 `k_echo_past_life`/`k_echo_path_mastery`/`k_echo_karma_chain` 的 `requirements` 字段可能不被代码支持
- **位置**: `data/cards/karma.json:730-819`
- **现象**: 这三张转世回响卡有 `requirements: { "minLifeCount": N, "differentPaths": true }` 字段。但已有审查报告未提及 `EffectService` 或 `CardSystem` 是否解析 `requirements` 字段。如果代码不支持，这些卡会在不满足条件时被错误地抽出。
- **根因**: 数据层使用了高级条件，但代码层可能未实现。
- **修复建议**: 验证 `CardSystem.draw` 是否过滤 `requirements`。如果未实现，添加过滤逻辑或在数据层移除这些字段（用 `forbiddenFlags` 替代）。

---

## P3 级问题（设计债务）

### P3-1 高境界内容空缺（元婴+）导致叙事空洞
- **位置**: `data/cards/` 目录
- **现象**: 已有审查报告确认「当前只做了炼气期、筑基期、金丹初期的卡牌内容」。从金丹中期到渡劫，**大量支线、因果卡、道侣事件、势力事件、世界事件的内容缺失**。玩家在后期会大量抽到兜底卡（「潜心修炼」），叙事体验严重下降。
- **根因**: 内容制作进度滞后于系统开发。
- **修复建议**: 优先填充 nascent（元婴）、deity（化神）、tribulation（渡劫）三个境界的核心叙事卡池。至少需要：
  - 每个境界 20-30 张 NORMAL 事件卡
  - 每个境界 2-3 条故事线程（ Story Thread ）
  - 元婴+ 的道侣高潮事件
  - 化神+ 的势力冲突高潮

### P3-2 章节里程碑场景图缺失（已有报告P3-5）
- **位置**: `data/cards/chapter_milestones.json`
- **现象**: 30 张 `scene_ch_{realm}_{threshold}.png` 作为 `_originalSceneImage` 占位，但文件系统中不存在。虽然当前代码未引用此字段，但后续章节 UI 一旦启用，将批量 404。
- **状态**: ⚠️ **已有报告确认，仍需修复**

### P3-3 角色概念美术资源缺失（已有报告P3-4）
- **位置**: `index.html` 中引用的 `assets/characters/*.webp`
- **现象**: 18 张角色概念图缺失，导致道侣/NPC 的亲密/信任阶段 UI 面板显示空白。
- **状态**: ⚠️ **已有报告确认，仍需修复**

### P3-4 正魔线部分种子被 `cancelGroup` 错误取消
- **位置**: `data/cards/demon_path.json:135-139, 165-169`
- **现象**: `dp_demon_face` 右选择的 `demonRefused` 种子和 `dp_demon_offer` 左选择的 `demonAccepted` 种子都带有 `cancelGroup: "demon_path_choice"`。这意味着如果玩家先拒绝、后接受，或先接受后拒绝，后面的选择会取消前面的种子。但**如果玩家直接拒绝（dp_demon_face 右），种子被种下，然后玩家继续正道路径，这个种子会在后续某个正道选择中被取消吗？** 没有证据表明有正道选择会触发 `cancelGroup: "demon_path_choice"`。所以这个 `cancelGroup` 实际上只防止 demon_path 内部的冲突，不影响外部。
- **根因**: `cancelGroup` 设计意图是防止正魔路径互斥，但实现不完整。
- **修复建议**: 在关键正道选择（如 `dp_orthodox_mentor` 左选择）中也添加 `cancelGroup: "demon_path_choice"`，确保正魔路径互斥。

### P3-5 势力事件 `minReputation` 可能过于严格
- **位置**: `data/world/factions.json`
- **现象**: 多个势力事件要求 `minReputation: 10` 或 `30`。如果玩家没有主动参与势力互动，声望可能长期为 0。这意味着大量势力叙事内容被锁死。
- **根因**: 势力系统与主卡牌的联动不足，玩家缺乏自然积累声望的途径。
- **修复建议**: 在主线/支线卡牌的选择中增加势力声望奖励（如完成白狐支线增加青云剑宗声望），或降低势力事件的初始声望门槛。

---

## 与已有审查报告的差异

### 已修复/未在数据层发现的问题

| 已有报告问题 | 状态 | 说明 |
|-------------|------|------|
| P0-1 `REALM_ORDER` 未定义 | **代码层，本次不审查** | 属于 `core_systems_audit`，不在 narrative_flow 范围内 |
| P0-2 `karmaGood/karmaBad` 路由错误 | **代码层，数据层设计正确** | 数据文件中大量卡牌正确使用 `karmaGood`/`karmaBad` 作为 effect key，但代码路由错误导致效果无效。数据设计本身无问题。 |
| P0-3 health 硬上限 | **代码层** | 不在本次审查范围 |
| P1-1 `spiritStoneBonus` 永远为 0 | **代码层** | 不在本次审查范围 |
| P1-3 商店跳过回合 | **代码层** | 不在本次审查范围 |
| P1-4 存档重载锁死支线 | **代码层** | 不在本次审查范围，但叙事层面影响支线可达性 |
| P1-6 realmOrder 硬编码 | **代码层** | 不在本次审查范围 |
| P1-7 兜底卡 `exp` 无效 | **代码层** | 不在本次审查范围 |
| P2-1 寿元危机种子重复种植 | **代码层** | `getActiveSeeds` 方法缺失是代码问题 |
| P2-8 支线 `step++` 风险 | **代码层** | `QuestSystem.advanceQuest` 逻辑问题 |
| P2-12 转世 quest_active 残留 | **代码层** | `reset()` 逻辑问题 |
| P3-1 数据双重维护 | **架构层** | 不在本次审查范围 |
| P3-4 角色概念图缺失 | **确认** | 同 P3-3 |
| P3-5 章节里程碑图缺失 | **确认** | 同 P3-2 |
| 7.1 6条支线完整 | **数据验证通过** | 所有 `questNext` 引用有效，26 个链接无悬空（与已有报告一致） |
| 7.2 因果系统深度 | **数据丰富但触发率极低** | 由于 P0-2（karma路由错误）+ P1-2（大量孤儿种子），实际触发率远低于设计预期。数据层有 36 张因果卡，但约 9 张完全不可达。 |

### 本次审查新增的关键问题

1. **P0-1 正魔线核心内战卡链完全不可达** — 4张关键卡（dp_demon_schism, dp_orthodox_schism, dp_demon_redemption, dp_demon_ascend）因种子孤儿而无法触发。这是正魔线第三幕（金丹期）的核心叙事，几乎完全失效。
2. **P0-2 NPC ID 全局不一致** — 这是跨系统的数据级崩溃，影响 NPC 关系网、交叉卡、主角关系默认值的全部功能。
3. **P0-3 白狐因果回响「狐影再现」不可达** — 一个重要的因果闭环断裂。
4. **P1-1 正道导师路径不可达** — 白刃真人的核心托付剧情（dp_orthodox_mentor + dp_sect_heirloom）完全不可见。
5. **P1-2 9个因果种子孤儿** — 大量精心设计的因果卡永远不会被玩家看到。
6. **P1-3 天劫无情道/有情道不可达** — 两个跨线交织的巅峰剧情不可见。
7. **P1-4 飞升后叙事顺序崩坏** — 玩家可能先看到结局再看到抉择。
8. **P1-7 故事线程系统数据完整但引擎未集成** — 炼气期的5条故事线程完全无法触发，GDD 设计的「因果连贯感」在主循环中不存在。

---

## 总结

《一念仙途》在**叙事数据层**展现了极高的设计完成度：
- 6条支线剧情完整、因果闭环设计精巧
- 正魔线三幕结构（35张卡）的叙事张力出色
- 道侣弧线、NPC交叉卡、转世系统、飞升后内容都有充分的数据支撑

但**数据层与代码层之间存在大量断裂**：
- **约 25% 的因果卡**（9/36）因种子孤儿而完全不可达
- **正魔线第三幕核心**（内战→救赎→飞升之秘）因 `demonInternalConflict` 孤儿而整体失效
- **正道导师路径**（白刃托付→镇派之宝）因 `orthodoxSideChosen` 孤儿而整体失效
- **NPC 关系系统**因 ID 不一致而无法正确匹配交叉卡
- **故事线程系统**（5条炼气期线程）有数据无引擎，等于不存在
- **死亡卡系统**有数据无展示路径，等于不存在

这些问题大多是**数据配置错误**（种子种植缺失、ID 不一致、flag 来源缺失），而非设计层面的结构性问题。建议**优先修复 P0 级数据配置错误**（预计 1-2 天工作量），然后验证 P1 级因果卡触发率，再逐步补充高境界内容。

> **最危险的断裂点**: 正魔线第三幕（P0-1）+ 白刃真人托付（P1-1）+ 9个孤儿因果种子（P1-2）。这三处问题导致约 15-20 张精心撰写的叙事卡永远不会被任何玩家看到。
