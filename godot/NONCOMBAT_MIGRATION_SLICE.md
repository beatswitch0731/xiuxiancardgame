# Godot 非战斗迁移：Slice Charter 与证据

**N1 鬼债与官坊交付生成规则身份（2026-11-04，局部独审无确定 P0/P1）**：从 `src/game.js::_buildGhostDebtDueCard` 的 `ghost_debt_due:<debtId>` 和 `_buildLicensedRustedSwordDeliveryCard` 的 `regulated_rusted_sword_delivery:<orderId>` 追到 Godot `noncombat_ghost_debt_flow.gd`、`noncombat_licensed_delivery.gd` 的实际出卡；两族实例 ID 无界，仓库只登记 `ghost_debt_rule`、`licensed_delivery_rule` 的网页符号、当前 `src/game.js` SHA、ID 前缀、Godot 生产者及到期门槛。内容仓库专项先以 315/预期 317 红例退出 1，修后 `NONCOMBAT_CONTENT_REPOSITORY_PASS` 退出 0。独审核网页函数、Godot ID 形状及源 SHA 一致，见到自然路线测试引用，但本次没有与总门禁并跑长测；动态实例逐个可达性和运行时调用仓库索引均未证明。此批未改变出卡或结算；N1 其他生成家族仍待验收。

**N1 图片引用错指精确诊断（2026-11-04，局部独审无确定 P0/P1）**：独审用 `sceneImage` 从一张已登记图改到另一张已登记图时，旧资源覆盖器仅核文件存在/SHA而放过，完整总门禁虽会因源 JSON SHA 漂移失败却只打印文件名，无卡消费者。诊断专项现新增一对原/改 JSON：同一 `diagnostic_card` 的图从 `scene_qi_q_cave.png` 改为也已登记的 `scene_karma_k_fortune_wheel.png`，修前因不支持来源基线参数而红、修后准确给出改动文件、`$.cards[0].sceneImage`、`consumer=card:diagnostic_card`、旧新路径；现行非战斗源 JSON 与包内副本也逐指针对比图片绑定，完整 Godot 门禁把该覆盖检查移到笼统的源 SHA 断言之前。`NONCOMBAT_ASSET_REFERENCE_DIAGNOSTICS_PASS` 与 `NONCOMBAT_ASSET_COVERAGE_PASS images=531 animated=3 audio=32 copied=1095` 退出 0，独审确认单侧源漂移先报精确指针。若原源和包内副本同时被改、manifest 仍旧，现只能报来源 SHA 文件路径；数组增删/重排也只按位置报告首差异。本批不声称全部误指形状都可精确诊断，N1 其余生成来源和运行消费者索引仍待审，不据此签收。

**N1 境界到达卡有限来源索引（2026-11-04，局部独审无确定 P0/P1）**：独审指出真实金丹自然路线会出现 `realm_arrival_golden`，统一仓库原 311 条生成卡中无任何 `src/game.js` 境界到达规则。现按网页 `_buildRealmArrivalCard` 与 Godot `noncombat_realm_gate_flow.gd::arrival_card` 只登记可生产的金丹、元婴、化神、渡劫四个有限 ID，各自回溯 `data/cards/chapter_milestones.json` 中前一境界第 100 点战斗卡的原 JSON pointer、原场景图、JSON SHA 和 `src/game.js` 规则 SHA。筑基到达使用另一个 `epiphany` 卡，未伪造 `realm_arrival_foundation`。仓库专项先在 311/预期 315 红例退出 1，修后 `NONCOMBAT_CONTENT_REPOSITORY_PASS` 退出 0；独审核四个 ID、原指针、场景图、源/副本与包内图 SHA 一致。独审对金丹自然长测运行约四分钟后因与总门禁争用资源主动中止，**该次没有通过结果**；已有测试断言和先前通过记录不能替代本次独立重跑。运行流目前直接读来源模块，没有用这四条索引作出卡门禁。本批只证明来源登记，元婴以上自然路线尚未逐条证实，N1 未签收。

**N10 首战旧档坏字段公开预览（2026-11-04，局部独审通过）**：独审指出真实浏览器首战撤离结果档若将 `marketState` 或 `heavensHint` 改为 `null`，通用存档预检仍认为结构可读，公开玉简预览调用结果导入器时会报 GDScript 类型/空值脚本错误；战中档 `questState:null` 同理。真实二号槽夹具复制后仅改上述字段的专项修前分别在 `noncombat_browser_combat_result_import.gd:60` 和 `noncombat_browser_combat_pending_import.gd:66` 红于脚本错误、exit 1。结果导入器现先要求坊市、天机、涟漪、同伴进度为 Dictionary、待发因果种子为 Array；战中导入器先要求任务副本为 Dictionary；不符合即返回受控 `UNSUPPORTED_IMPORT_RESULT_STATE` / `UNSUPPORTED_IMPORT_COMBAT_STATE`。正常真实撤离结果与战中导入专项修后均 exit 0，结果档的坏字段替换还核原 Godot 槽字节不变。独审复跑两专项未见本批确定剩余 P0/P1；实际桌面结果档预览按钮未单独点击，只按现有调用链和领域测试声称受控返回。通用 Inspector 对空首局的允许规则未改；本批不代表任意浏览器旧档可导入，N10 未签收。

**N1 生成卡规则来源登记（2026-11-04，局部独审通过）**：独审从真实公开路线指出 `vendor_result:1:bazaar_encounter` 和 `heavens_hint:slot_1:life:0:23:0` 在 Godot 有生产者、却不能由统一内容仓库找到来源规则。此批只补两个相关的来源规则族：`vendor_rule:pending`、`vendor_rule:result` 映射网页 `src/game.js::_buildVendorPendingCard/_buildVendorResultCard` 及 Godot 四类摊位流；`heavens_hint_rule` 映射 `HeavensHintSystem._buildHintCard`、派生天机池 `$.pool` 与 Godot 天机流。三项都是无界实例的有限规则身份，不伪称逐张实例已登记；仓库源 JS/派生池 SHA 固定并由总门禁核当前文件。内容仓库专项先以 308/预期 311 红例退出 1，修后 `NONCOMBAT_CONTENT_REPOSITORY_PASS modules=75 cards=588 quests=6 threads=12 scene_refs=553 unlisted=0` 退出 0，`validate_godot_runtime.py` 语法检查退出 0。独审复跑内容仓库、天机池来源检查、首坊摊位与天机专项均退出 0，确认这批规则符号和来源 SHA；当前摊位/天机运行流尚未调用仓库索引校验生产身份，因此本批仅声称登记，不声称运行时来源门禁。独审还发现 `realm_arrival_<realm>` 等其他规则族及已存在图间错指的诊断缺口，本批未涵盖；N1 全阶段仍未签收。

**N7 炼气凡人道侣危机自然路线复核（2026-11-04，纠正下方历史判断）**：当前来源 `data/npcs/core_npcs.json` 已登记 `mortal`，真实 Chromium 固定 0.45 体修路线在决定 12 选择 `q_love.right` 结缘；到决定 31 时，好感 50、实体在场，`comp_mortal_qi_karma_crisis_good` 的左右选项均可用。左选后好感 54、信任 22，下一卡 `promise_result_648444c4`、决定钟 32、页面错误空；`capture_noncombat_mortal_natural_browser.js --check` 和 Godot `noncombat_n4_quest_source_order.gd` 来源下一卡对照退出 0。下方 N7 ISSUE-01 写的“没有已证自然炼气合格道侣获取路径”已被本证据推翻。此一条路线成立，N7 全阶段的其他同伴、地图、势力与媒体出门条件仍未签收。

**天机旧线索门禁时限（2026-11-04，测试配置）**：`noncombat_heavens_hint_legacy_clue.gd` 在总门禁默认时限下超时；同脚本独立运行约 21 秒、`NONCOMBAT_HEAVENS_HINT_LEGACY_CLUE_PASS clue=true disk=true` 退出 0。只给该脚本单独 90 秒上限，门禁续跑已越过此项；玩法和断言未改。

**坊市桌面交易音效测试时序（2026-11-04，测试边界）**：`noncombat_bazaar_vendor.gd` 原在按键后等待一帧再要求 0.16 秒交易短音仍 `playing`，本次界面重绘耗时后该断言报错；商贩权威关系值已为 1。测试现核查操作后关系值与交易音效流已实际生成并绑定播放器，保留摊位按钮、背景、环境音、离摊、回滚及冷读断言，`NONCOMBAT_BAZAAR_VENDOR_PASS open=true action=true close=true replay=true rollback=true` 退出 0。headless 绑定不等于 Windows 可听实测，N9/N11 仍需可见包体复核。

**命盘延迟自然路线观察窗（2026-11-04，测试边界）**：总门禁旧 200 次循环在决定 201 停下，存盘显示 `pendingDestinyWheel.triggerDecisionIndex=196`、返回卡 `ir_test`、命盘未丢且流程仍在走高优先级内容。将专项观察窗改为 230 次后，实际在决定 202 出命盘并完成翻牌，磁盘快照无未决命盘；`NONCOMBAT_DESTINY_DEFERRED_NATURAL_PASS hidden=true shown=true flip=true disk=true` 退出 0。只改测试上限，未调整生产调度或将静默 pending 视为成功。

**第二世首章节前白狐卡来源闭合（2026-11-04，局部，独审无确定 P0/P1）**：`QuestFlow.resume` 对第二世首张炼气章节前、双 pin 均未存在的合法状态先核当前章节与因果来源 SHA，再在白狐入口卡候选上写双 pin，使随后的 `settle` 仍能严格核来源；已有 pin 仍必须匹配。`noncombat_rebirth_quest.gd` 用合成的第二世第 5 回合/修为 10 状态验证 `resume→settle` 及伪造章节 pin 拒绝，退出 0；完整公开第二世白狐路线的胜/败/撤离、重试和冷读见下方白狐专项退出 0。低修为第 5 回合尚无自然浏览器或 Godot 全路径证明，不计 N6 签收。

**白狐选项来源登记修订号回归（2026-11-04，测试基线更新）**：`data/npcs/core_npcs.json` 当前有 16 个 NPC（新增凡人），白狐首选左/右后的世界登记修订号相应为 17/16；旧断言 16/15 造成门禁误报。仅修正 `noncombat_whitefox_choices.gd` 的预期并保留后续生死、关系、存盘、重放断言，专项 `NONCOMBAT_WHITEFOX_CHOICES_PASS first=2 second=2 npc=true replay=true` 退出 0。未改变玩法实现或阶段签收。

**N2/N4/N6 旧 v2 因果时钟与第二世白狐回归（2026-11-04，局部，待独审）**：总门禁白狐跨世专项原在历史 `pill_decision54_death_probe_v2.json` 的严格恢复失败；逐字段诊断仅 `karmaSeeds`/`pendingKarmaSeeds` 延迟差异，原因是 N4 为当前网页来源补的坊市右选时钟推进被用于重演修复前的旧 Godot 存档。现在旧 `normalFlow.choiceRuleSha` 恢复时冻结历史坊市种子计时，首次新决定写入 `marketSkipSeedTickActivationIndex`，之后严格重演按该持久激活点切换为当前计时；新档与真实体修 0.45 路线仍使用当前规则，`NONCOMBAT_N4_QUEST_SOURCE_ORDER_PASS ... post_crisis=true` 退出 0。第二世开局在首个章节里程碑出现前没有章节来源 pin，QuestFlow 仅对 `rebirth_new_life`、未触发任何炼气章节且双 pin 均缺的状态允许按当前校验来源继续；有 pin 时仍逐项核验。白狐跨世测试的旧预期把任务排在 Qi 60 以后，与当前来源规则冲突，改为在 `ch_qi_20` 后先避开到期遭遇再进白狐任务。完整 `NONCOMBAT_WHITEFOX_REBIRTH_PASS life=1 ... outcomes=3 retry=2 source=true forged=true replay=true` 退出 0，覆盖胜/败/撤离、重试、冷读及伪造回执拒绝。尚无第二世浏览器逐卡夹具；N2/N4/N6 均未签收。

**N4 炼气危机选择后来源卡对照（2026-11-04，局部）**：`noncombat_n4_quest_source_order.gd` 现提交第 33 节点 `comp_mortal_qi_karma_crisis_good.left`，直接比对真实 Chromium 夹具 `after` 的下一张 `promise_result_648444c4` 与决定时钟 32；专项退出 0，输出 `post_crisis=true`。这只将固定 0.45 体修路线再延一跳，不证明其他修路、生产随机流或长期危机后续，N4 未签收。

**N1 ISSUE-12 独审同人物对重发 P1 补正（2026-11-04，本小批独审通过）**：独审实测同人物对旧 `npc_cross_bai_ren_jian_linger_1` 挂起，关系由 `master-disciple` 变 `ally` 后第 37 回合再发 `_37`，单一 `lastCrossTurn` 被覆盖使旧卡在 `take` 被丢弃。专项按来源路径构造双队列，修前 `older dynamic card lost after same-pair reissue` 退出 1。现动态 marker v2 在 `_collect_dynamic` 成功排队时按实际卡 ID 持久写 `issuedCards[id]={turn,pairKey,semanticKey}`；`_valid_dynamic_card` 将卡 ID 来源回合与该发行记录、当前回合/决定钟及来源卡体核对，`lastCrossTurn` 只保留抽卡冷却职责。`take` 丢弃无效卡和 `settle` 完成卡时清理对应发行记录，旧 `_1` 与新 `_37` 可依序投递/结算。旧动态 marker v1 无发行记录的已知形状在 Flow 先核卡体，再于下一次 `collect` 升为 v2；严格 Domain 重放仍产生新发行记录，最终只针对旧 v1 缺字段快照把预期形状归一后逐字比对，v2 缺发行记录直接拒绝。双队列、发行回合错配/未来 ID/缺 ledger、延迟待选磁盘冷读专项通过；真实新 v2 存档的严格重放正例及伪造发行记录负例由 NPC cross 自然专项验证；旧 v1 动态双队列仅 Flow 层升级与取卡通过，真实旧 v2 严格重放尚无来源一致的历史快照，不能宣称兼容验收。N1 未签收。

**N1 ISSUE-12 独审延迟队列 P1 补正（2026-11-04，待复审）**：独审指出 `_valid_dynamic_card` 原用当前 `state.turn` 重建动态卡 ID；第 1 回合排 `npc_cross_bai_ren_jian_linger_1` 后若先结算更高优先级卡，第 2 回合 `take` 会误构造 `_2` 并丢弃合法队列。新增同卡延迟至第 2 回合的 `take/card/settle` 红例，修前 `dynamic cross queue lost its source turn` 退出 1。现在从 `npcIds` 拼出完整 ID 前缀，严格提取规范十进制回合后缀；核对来源回合不早于动态启用、不晚于当前回合和决定钟、且等于该人物对 `lastCrossTurn` 排队记录，重投影使用冻结来源回合。专项同时拒绝未来 ID、队列时间不一致、落后决定钟，并将延迟待选卡写盘、重新读盘后核对卡与结算，并拒绝冷读后伪造的未来 ID。修后 `NONCOMBAT_NPC_CROSS_DYNAMIC_PASS ... delayed=true cold=true`、五张作者预设和内容仓库专项退出 0。冷读仍是 Flow 卡状态 JSON，不宣称 RunSession 严格历史重放或自然长局；N1 未签收。

**N10 浏览器首战撤离结果卡导入排期补正（2026-11-04，局部，待独审）**：当前真实 Chromium 二号玉简 `combat-pending-source-sword.json` 的战中原始快照为坊市 `nextBazaarDecisionIndex=6`、鬼市 19；撤离结果卡快照在第 6 决定结算坊市到期后变成 `lastBazaarDecisionIndex=6,nextBazaarDecisionIndex=16`，并非初始排期 16。导入器此前把 16 直接拿去逆推开局种子，合法结果档报 `UNSUPPORTED_IMPORT_SCHEDULE`（修前退出 1）。现仅对本来源形状使用已写盘 `lastBazaarDecisionIndex` 与下一排期同时逆推，其他未支持排期仍拒；结果卡原始快照、战斗回执、世界脉动、空槽原子导入、严格冷读、确认后来源下一卡 `ch_qi_20` 与伪造 `lastBazaarDecisionIndex` 拒绝在 `NONCOMBAT_BROWSER_COMBAT_RESULT_IMPORT_PASS slot=2 result=true cold=true next=true` 退出 0。待战/回合两份浏览器证据已按当前 UI SHA 重采，两个 `--check` 退出 0，均加入总门禁；结果导入专项也已加入总门禁。只覆盖首世剑修首战撤离这一结果卡，其他战果、战斗中间态、跨世与三槽全类型旧档尚待 N10，N10 未签收。

**N4 固定随机体修全段来源顺序（2026-11-04，局部，待独审）**：重采的真实 Chromium 清洁体修 `0.45` 轨迹共有 34 个可见节点，包含 `ch_qi_60`、命盘、体修因果、导师、凡人道侣与炼气危机。Godot 同 `slot_2`、同固定抽签的逐卡 ID/决定时钟测试 `noncombat_n4_quest_source_order.gd` 已从 0–15 延至 0–33，退出 0。第一处修前红在命盘后：`bazaar_encounter.right` 虽推进决定时钟却未推进因果种子，浏览器应先出现 `k_chapter_body_left`，Godot 却先出导师卡；`noncombat_market_flow.gd::settle_skip` 现在同一次选择减一次种子延迟，市场调度、鬼市与坊市冷读专项通过。第二处修前红在第 32 节点：Godot 道侣随机哈希在浏览器固定 `Math.random=0.45` 的对照中抢先出凡人日常；`CompanionEvents` 新增默认关闭、**不持久化**的测试抽签入口，来源对照设为 0.45 后与浏览器逐卡一致。凡人 `register` 会动态加入网页版道侣表，因此日常卡仍保留生产可达性；曾尝试的禁止凡人日常改动已撤销。`noncombat_mortal_natural.gd` 的结缘→危机→选择→严格冷读通过。此证据只证明一条受控随机路线，生产态 Godot 哈希与网页随机流的全状态同轨、其他修路和旧版误消费章节的网页档未证，N4 未签收；N0–N11 正式仍仅 N0 签收，**1/12**。

**N1 NPC cross 动态三规则身份 ISSUE-12（2026-11-04，局部，待独审）**：网页 `NpcSystem.js::_emitCrossCard` 按 `rival`、`ally|master-disciple`、`neutral|estranged` 三个卡体分支生产 `npc_cross_<npcA>_<npcB>_<turn>`；后者随回合无界，不作为有限卡逐张登记。内容仓库新增三个 `npc_cross_rule:<branch>` **规则身份**（当前 `generated_card` 305→308），记录 JS 函数与 SHA、关系 JSON 与 NPC JSON 的来源 SHA、状态映射及同地实体/12 回合门槛；作者 `npc_cross_cards.json` 五张预设卡不是动态文案来源，不伪造其 JSON 指针。Godot `_dynamic_card` 出卡前核对规则登记，`take` 校验排队卡，`card`/`settle` 从规则重建并逐字段比对待选卡；中性三种随机文案逐一比对，不推进运行 RNG。修前专项先因 `rival` 规则未登记退出 1；登记后又因伪造待选效果被接受退出 1；修后 `NONCOMBAT_NPC_CROSS_DYNAMIC_PASS scheduled=2 templates=3 cooldown=12 effects=true source=true forged=true duplicate=true cold=true` 退出 0，覆盖重复登记拒绝、伪造来源/排队标题/待选效果及缺失动态来源标记拒绝及待选卡磁盘 JSON 冷读重投影。网页来源样本只有两条日程可达候选（师徒、默认中性）和一条 `rival` 构造态模板；磁盘冷读只证明 Flow 投影，不证明 `RunSession` 严格重放或所有关系状态自然可达。来源捕获 `NPC_CROSS_DYNAMIC_SOURCE_PASS scenarios=3`、内容仓库 `NONCOMBAT_CONTENT_REPOSITORY_PASS modules=75 cards=588` 退出 0。N1 未签收。

**N4 决策 14 来源修复（2026-11-03，待独审）**：固定 0.45 清洁体修公开 UI 决定 13 `q_bodyTrial.left`，修前立绘上下文在提交前调用 `getCurrentCard()` 消费待发 `ch_qi_60`，却不保留其可见卡；修后只读 `currentCard`，空卡视为非亲密场景，决定 14 公开卡为 `ch_qi_60`。`tools/test_n4_portrait_flow_precommit.js` 修前精确红在 `decisionIndex=13, pending=ch_qi_60`，修后通过并已登记总门禁；新 `mortal-qi-browser.json` 含 `src/ui.js` SHA 与实际服务器 SHA，决定 31 仍自然出现道侣危机。旧轨迹与 opening/prologue、覆盖账本均留历史，当前 opening/prologue 重采后 `sync_runtime_content.py` 和三方指纹对齐，`companion_whispers.json` 与 Godot 的 UI/catalog pin 已同步。Godot 同策略 0–15 卡/时钟通过，下一分歧为命盘左翻后浏览器 `k_chapter_body_left`、Godot 导师入室卡（同为决定 15），待下一批单独查。N10 战中来源夹具仍待其负责人按新 UI SHA 重采；旧网页已误触发章节的存档保持原状态，未做补偿。N4 未签收。

**N1 因果涟漪四模板来源登记 ISSUE-11（2026-11-03，局部，待独审）**：网页版 `NpcSystem._emitCrossCard` 的实例 ID `npc_cross_<npcA>_<npcB>_<turn>` 与 Godot `_dynamic_card` 同含无界回合，不能伪作有限卡表；该批 N1 只记录此规则族缺口，不逐实例登记。`KarmaRippleSystem._buildRippleCard` 的实例 ID `karma_ripple:<lifeId>:<turn>:<seedId>` 也无界，但来源 `_rippleTemplates` 的四个 seedType `karma/grudge/bloodline/fate` 在 `derived/karma_ripple_templates.json` 各恰有一条有限模板。本批在 `generated_card` 命名空间登记的是 **4 个 `karma_ripple_template:<seedType>` 模板身份，不是 4 个运行卡 ID**；逐模板保留来源 JS SHA、派生目录精确 `$.templates.<seedType>[0]` 指针/SHA、生产函数和种子类型门槛。Godot `noncombat_ripple_flow.gd::_build_card` 在首次生成及 `_restore_card` 冷读重建时核对模板卡体和来源登记。专项修前因首个 karma 模板缺登记退出 1；修后 `NONCOMBAT_RIPPLE_TEMPLATE_REGISTRY_PASS templates=4 duplicate=rejected forged=rejected` 退出 0，重复索引和伪造登记卡体均拒；来源导出 `KARMA_RIPPLE_TEMPLATES_SOURCE_PASS`、内容仓库 `NONCOMBAT_CONTENT_REPOSITORY_PASS modules=75 cards=588`、真实剑修→坊市涟漪 `NONCOMBAT_KARMA_RIPPLE_PASS pending=true replay=true choice=true ui=true` 均退出 0。索引 **301→305**，其中四项只是模板。此批不证明每类 seedType 都在自然长局出卡，也不覆盖 NPC cross 动态规则身份的登记；N1 未签收。

**N1 ISSUE-10 独审实体资格 P1 补正（2026-11-03，待复核）**：独审指出动态临界好感卡虽然有来源索引，Godot `_affection_card` 却没有执行网页 `FlowDirector._isNarrativeValid → canManifest(compId, PHYSICAL)` 的消费者门禁。专项新增 `deadNpcs=[]` 下 `ACTIVE/ECHO_ONLY`、世界登记缺人物行、世界世次错位三类首次 `take` 和已投递 `card/settle` 负例；修前在 ECHO_ONLY 首次出卡处退出 1。现 `_affection_card` 跳过不具本世 `ACTIVE/PHYSICAL` 身份的伴侣，故既不投递也不写 `surface_pushed_<compId>_20` flag；待选恢复与结算复用同一门禁。缺世界登记的旧 Godot 档保留 `deadNpcs` 准入，当前登记的缺席/跨世拒绝。修后 `NONCOMBAT_SURFACING_AFFECTION_REGISTRY_PASS owners=16 duplicate=rejected forged=rejected unavailable=rejected legacy=allowed`、原三支浮现、内容仓库和自然因果卡待选/选后严格冷读均退出 0。此补正仍不证明临界好感卡自然路线或 16 个候选逐卡可达，N1 未签收。

**N1 叙事浮现临界好感生成卡 ISSUE-10（2026-11-03，局部，待独审）**：网页 `NarrativeSurfacing._checkAffectionSurface` 先看现役道侣与已注册伴侣状态，再从共享 NPC 好感挑 18–19 的人物，产生 `surface_<compId>_near_20`。`CompanionSystem.loadData` 初始化作者 `events.json` 的 8 人，`register` 还能从核心 NPC 表补注册其余人物；当前 `core_npcs.json` 共 16 人，故本批登记 **16 个候选 ID**，不把任一候选宣称为自然可达。内容仓库逐 ID 保留网页规则 JS SHA/函数、核心 NPC 行精确指针/SHA、Godot `_affection_card` 与现役/注册/好感/一次性 flag 门槛；规则文案写在 JS 内，故没有伪造作者 JSON 卡体指针。Godot `_affection_card` 在 `take` 首发、`card` 待选恢复及其复用的 `settle` 中核登记。专项修前于 `surface_bai_ren_near_20` 缺登记退出 1；修后 `NONCOMBAT_SURFACING_AFFECTION_REGISTRY_PASS owners=16 duplicate=rejected forged=rejected` 退出 0，逐个来源/投影、重复 core 文档冲突及待选卡篡改后 `card/settle` 拒绝均验证。原 `NONCOMBAT_NARRATIVE_SURFACING_PASS karma=true world=true affection=true cooldown=true`、内容仓库 `NONCOMBAT_CONTENT_REPOSITORY_PASS modules=75 cards=588` 和自然因果卡冷读 `NONCOMBAT_NARRATIVE_SURFACING_NATURAL_PASS pending=true chosen=true replay=true` 退出 0；索引 **285→301**。临界好感卡的真实公开路线与冷读未证，本批不作为其自然可达证据。N1 未签收。

**N1 ISSUE-09 独审可达性更正（2026-11-03）**：`surface_bairen_memory` 虽可由构造态 Godot 测试投影，当前浏览器入口仅监听 `npc:died` 而未找到该事件的运行发射者，且浮现规则读 `bairen_zhenren`、当前核心人物 ID 为 `bai_ren`。因此它是有规则来源的**运行不可达候选**，不计自然可玩卡；下文 ISSUE-09 的“两固定卡”仅指规则登记数量。`surface_karma_burden` 的自然待选/结算/冷读证据仍成立。

**N1 叙事浮现固定生成卡 ISSUE-09（2026-11-03，局部，待独审）**：网页版 `StoryNetworkSystem.js::NarrativeSurfacing` 每 5 回合优先检查世界变化、因果、道侣情感。前两支固定产 `surface_bairen_memory`（白刃死亡后第 3 回合）和 `surface_karma_burden`（至少 4 颗因果种子）；第三支 `surface_<compId>_near_20` 随现役道侣 ID 生成，是另一动态家族，本批未登记。两张固定卡的作者来源就是 JS 函数 `_checkWorldChange/_checkKarmaSurface`，没有独立 JSON 卡体；内容仓库只登记固定 ID、规则 JS 路径/SHA、精确函数符号、Godot `_world_card/_karma_card` 及触发门槛，不虚称有 JSON 指针或已逐字段映射 JS 文案。Godot 两个生产函数在 `take` 初发与 `card` 待选恢复中校验登记，`settle` 复用 `card`。专项先因 `surface_bairen_memory` 未登记退出 1；修后 `NONCOMBAT_SURFACING_GENERATED_REGISTRY_PASS ids=2 duplicate=rejected forged=rejected` 退出 0，重复登记拒绝，伪造待选卡规则身份拒绝。原三支 `NONCOMBAT_NARRATIVE_SURFACING_PASS karma=true world=true affection=true cooldown=true`、内容仓库 `NONCOMBAT_CONTENT_REPOSITORY_PASS modules=75 cards=588` 和公开法修路线因果卡待选/选择后严格冷读 `NONCOMBAT_NARRATIVE_SURFACING_NATURAL_PASS pending=true chosen=true replay=true` 均退出 0；`generated_card` 索引 **283→285**。白刃死亡卡只经构造态入口验证，未有公开自然路线；道侣临界动态卡仍缺 N1 登记。N1 未签收。

**N1 先知弧线实际生成卡登记 ISSUE-08（2026-11-03，局部，待独审）**：网页 `StoryNetworkSystem.js::SeerArcEngine` 以 `ENCOUNTER` 为 index 0 初始态，不产卡；天机老人 `REVELATION/UNVEILING/SACRIFICE/FINAL_PROPHECY` 四阶段按揭示度 20/40/60/80 排队，另有 `revelation/tribulation/destiny` 三张转折卡，作者 `data/companions/arcs.json` 五阶段加三转折中实际产卡 **7 个 ID**。内容仓库逐 ID 记录网页 JS SHA、作者 JSON 精确指针/SHA、网页生产函数与实体在场、阶段和境界门槛；`noncombat_seer_arc_flow.gd::_project` 是首次 `take`、待选 `card`、`settle` 的共用投影入口，现逐卡校验登记。专项修前于 `seer_tianji_laoren_stage_REVELATION` 缺登记退出 1；修后 `NONCOMBAT_SEER_GENERATED_REGISTRY_PASS ids=7 unproduced=1 duplicate=rejected forged=rejected echo_only=rejected legacy=allowed` 退出 0，证明重复 `_index_document` 拒绝、篡改待选登记拒绝、`deadNpcs` 空但世界登记为 `ACTIVE/ECHO_ONLY` 时 `take` 丢弃队列且 `card/settle` 拒绝。现行世界登记还核本世、人物 ID、`ACTIVE/PHYSICAL`；缺世界状态的旧 Godot 档保留原 `deadNpcs` 准入。原 `NONCOMBAT_SEER_ARC_FLOW_PASS`、`NONCOMBAT_CONTENT_REPOSITORY_PASS modules=75 cards=588` 和公开筑基→金丹先知首卡 `NONCOMBAT_SEER_ARC_NATURAL_PASS pending=true chosen=true response=true replay=true` 均退出 0，生成卡索引 **276→283**。自然证据只到首阶段卡，其他六张未逐卡公开长局验收；N1 未签收。

**N1 ISSUE-07 独审 P1 补正（2026-11-03，待复核）**：独审发现原盟友 `take/card/settle` 只查 `deadNpcs`，当 `worldContinuityState` 已把血煞老祖记作 `ACTIVE/ECHO_ONLY` 时仍可出卡。补充专项先在 `deadNpcs` 为空的 ECHO_ONLY 首次 `take` 处退出 1；Godot 现按网页 `WorldContinuityStore.canManifest(..., PHYSICAL)` 检查本世、人物 ID、`ACTIVE/PHYSICAL`，`take` 丢弃不可显现的待发队列，已投递 `card` 及其 `settle` 也拒绝。缺世界登记的旧 Godot 档仍按原 `deadNpcs` 准入，存在世界登记但缺人物行或世次不符则拒绝。修后专项输出 `NONCOMBAT_ALLY_GENERATED_REGISTRY_PASS ids=7 unproduced=1 duplicate=rejected forged=rejected echo_only=rejected legacy=allowed`；原盟友流程、内容仓库专项均退出 0；最终代码状态的自然剑修路线 `NONCOMBAT_ALLY_ARC_NATURAL_PASS card=ally_xuesha_laozu_stage_RECOGNITION pending=true chosen=true response=true replay=true` 退出 0。这只关闭盟友实体卡消费缺口，不声称所有盟友卡自然可达，N1 仍未签收。

**N1 盟友弧线实际生成卡登记 ISSUE-07（2026-11-03，局部，待独审）**：浏览器 `StoryNetworkSystem.js::AllyArcEngine` 注册血煞老祖时 `CONTACT` 是 index 0 初始态，不出卡；`RECOGNITION/TRUST/COMRADE/LEGACY` 四阶段分别在同盟度 20/40/60/80 入队，另有 `revelation/tribulation/destiny` 三张转折卡。作者 `data/companions/arcs.json` 同时有五个阶段字段和三个转折字段，本批仅登记实际产出的 **7 个 ID**，保留网页 JS SHA、作者 JSON 精确指针/SHA、网页生产函数和物理在场/阈值/境界门槛。Godot `noncombat_ally_arc_flow.gd::_project` 是首次 `take`、待选 `card`、`settle` 共用的投影入口，现逐卡核对登记；修前 `noncombat_ally_generated_registry.gd` 在 `ally_xuesha_laozu_stage_RECOGNITION` 缺登记处退出 1，修后输出 `NONCOMBAT_ALLY_GENERATED_REGISTRY_PASS ids=7 unproduced=1 duplicate=rejected forged=rejected`、退出 0。专项经重复 `_index_document` 证实 ID 冲突拒绝，并在真实 `take → card` 待选状态中篡改登记作者卡体，`card` 拒绝；既有 `NONCOMBAT_ALLY_ARC_FLOW_PASS` 与 `NONCOMBAT_CONTENT_REPOSITORY_PASS modules=75 cards=588` 均退出 0，生成卡索引由 269 增至 **276**。这不证明七卡自然长局全可达，也不覆盖先知家族；先知 `ENCOUNTER` 同为初始非卡，尚有四阶段加三转折共 **7 个实际生成 ID** 待 N1 登记。N1 未签收。

**N7 凡尘道侣炼气自然路线 ISSUE-02（2026-11-03，局部，待独审）**：`data/cards/qi.json:q_love.right` 原本授予 `mortal`，但 `core_npcs.json` 没有该 ID，网页只有原始资源字符串而无法注册有好感/实体状态的道侣；新增第 16 名村中女子、炼气/筑基村镇日程及初始好感 50/信任 20，保留原卡文本与选项效果。受控网页生产入口测试先因无登记人物退出 1，修后 `MORTAL_COMPANION_REGISTRATION_PASS`；真实 Chromium 干净体修路线在 decision 12 选择 `q_love.right`，decision 38 出 `comp_mortal_qi_karma_crisis_good` 双选，左选结算好感 54/信任 22，来源和服务 SHA 均校验。Godot 干净体修自然出 `q_love.right` 后，经 `Domain.restore()` 严格冷读，再自然取得善危机双选，选择及后续严格冷读均通过 `NONCOMBAT_MORTAL_NATURAL_PASS bond=true crisis=true cold=true`。新 NPC 使里程碑 75→80、单人遭遇生成卡 60→64/模板变体 720→768；派生目录、来源 pin 与精确测试已同步，当前内容仓库 75 模块/588 卡及动态登记 269 张。旧 v2 死亡旅程样本在新 NPC 来源下先报 `SOURCE_MISMATCH`，仅对原 core SHA、无世界启用标记、v1 世界状态且无 `mortal` 的旧档允许旧来源重演精确投影，并在下一次真实提交时升级世界及来源 pin；同一旧档严格恢复、续局及再次冷读通过 `NONCOMBAT_DEATH_CARD_JOURNEY_PASS`。自然长局暴露的 choice echo `null` 人物 ID 转字串异常已按可选字段修复。网页/Godot 固定抽签不逐步同轨；本批只证明指定旧档形状，不代表所有旧 v2；人物肖像仍待 N9 挂接审图，N7 与全目标未据此签收。

**N1 导师弧线实际生成卡登记 ISSUE-06（2026-11-03，局部，待独审）**：作者 `data/companions/arcs.json` 的白刃真人有 5 个 `arcStages` 加 `secretReveal`、渡劫、命运共 8 个字段组；网页 `StoryNetworkSystem.js::MentorArcEngine` 以 `DISCIPLE` 为 index 0 初始态，只在跨越 index 1–4 时通过 `_buildStageEvent` 产 `INNER_DISCIPLE/TRUSTED/HEIR/LEGACY` 四卡，另产渡劫和命运两卡。网页 `_buildRevelation` 查询 `arc.revelation`，当前作者只有 `secretReveal`，所以揭示卡实际不产；Godot 同样只有这 **6 个实际可产 ID**。本 N1 批只给 6 卡登记网页规则 SHA、作者 JSON 精确指针/SHA、生产函数与物理导师/进度门槛，`noncombat_mentor_flow.gd::_project_card` 作为首次投递、待选恢复及结算共用投影入口核对登记。新专项因首张未登记先退出 1，修后 `NONCOMBAT_MENTOR_GENERATED_REGISTRY_PASS ids=6 unproduced=2 duplicate=rejected forged=rejected`；重复 `_index_document` 和篡改已登记作者卡体均被拒。`NONCOMBAT_MENTOR_ARC_PASS`、`NONCOMBAT_MENTOR_HEIR_LEGACY_PASS`、`NONCOMBAT_CONTENT_REPOSITORY_PASS modules=75 cards=588` 均退出 0。当前生成卡登记总数 **269**。`DISCIPLE` 初始字段和 `secretReveal` 不应被当作已产卡；若目标要求作者揭示节点可玩，需在 N7 玩法源端澄清和修复。N1 及 N7 均未据本批签收。

**N1 五人道侣弧线生成卡来源登记 ISSUE-05（2026-11-03，局部，待独审）**：浏览器 `StoryNetworkSystem.js` 与作者 `data/companions/arcs.json` 共同产生五人各 5 阶段+3 终章的 40 张卡，Godot 来源固定的 `derived/companion_arc_cards.json` 含同 40 ID。内容仓库逐卡保留网页规则 JS SHA、作者 JSON 指针/SHA、派生目录精确 `$.cards.<人物>[i]` 指针/SHA 和原卡体；实际 `noncombat_companion_arc_flow.gd::_project` 为 `take` 首次投递、`card` 待选恢复及 `settle` 的共同入口，现逐卡核对登记。专项先因缺 `arc_bai_luoxuan_stage_ACQUAINTANCE` 来源登记退出 1，修后 `NONCOMBAT_COMPANION_ARC_REGISTRY_PASS owners=5 ids=40 duplicate=rejected forged=rejected`；经 `_index_document` 重复来源产生 ID 冲突，篡改登记卡体被 `_project` 拒绝。`NONCOMBAT_COMPANION_ARC_FLOW_PASS` 和 `NONCOMBAT_CONTENT_REPOSITORY_PASS modules=75 cards=588` 退出 0。当前 `generated_card` 精确总数 263，此批仍不证明 40 张自然长局全部到达，N1 未签收。

**N1 人物来源更新后的旧批复测（2026-11-03）**：N7 把 `core_npcs.json` 从 15 人扩为 16 人后，旧 ISSUE-02 的“75 张里程碑”和 ISSUE-03 的“60 个 NPC 遭遇 ID/720 变体”保留为当批来源快照数字，不再代表当前来源。当前同一登记规则按 16 人得 **80 张里程碑、64 个 NPC 遭遇 ID/768 变体**；`NONCOMBAT_COMPANION_MILESTONE_REGISTRY_PASS count=80`、`NONCOMBAT_NPC_GENERATED_REGISTRY_PASS ids=64 variants=768` 与内容仓库专项均已在新来源/manifest 上退出 0。N7 当前来源版仍需 N1 全生产者审计，N1 未签收。

**N1 通用道侣生成卡来源登记 ISSUE-04（2026-11-03，局部，待独审）**：当前 `core_npcs.json` 16 人中，`events.json` 8 人有作者事件池，剩余 8 人经网页 `CompanionSystem.js::_getGenericEvent/_buildEventCard` 和 Godot `noncombat_companion_events.gd::_generic_events/_build_card` 生成 `generic_daily/emo/help` 三种卡，精确 24 个 `comp_<NPC ID>_<通用事件ID>`。内容仓库按 NPC 来源 SHA、网页函数源码 SHA、通用池槽位、人物/事件 ID 和抽取/冷却门槛登记；Godot `take` 首次出卡与 `card` 待选恢复均核对登记和当前本机通用事件模板。新专项修前于首张 `comp_ds_bloodrose_generic_daily` 查无登记退出 1；修后 `NONCOMBAT_COMPANION_GENERIC_REGISTRY_PASS owners=8 ids=24 duplicate=rejected`，`_index_document` 传重复 NPC 触发生成 ID 冲突，篡改已登记事件 ID 时实际 `card` 消费者拒绝；`NONCOMBAT_COMPANION_EVENTS_PASS` 与 `NONCOMBAT_CONTENT_REPOSITORY_PASS modules=75 cards=588` 均退出 0。此批没有证明 24 张全部在自然长局触发，N1 仍未签收。

**N1 NPC 单次遭遇生成卡来源登记 ISSUE-03（2026-11-03，局部，待独审）**：网页 `NpcSystem.js::_buildEncounterCard` 用 15 名 NPC × 初见/偶遇/重逢/对峙生成 60 个 `npc_encounter_<NPC ID>_<场景>`；四修和三种归一化情绪在 Godot 已固定来源 SHA 的派生目录中形成 720 个模板变体。内容仓库逐 ID 登记网页生产函数与 SHA、NPC 原目录 SHA、派生目录 SHA 和 12 个变体的精确 JSON 位置及卡片；Godot `_general_card` 是首次出卡、待选恢复的同一生产入口，现核对 ID/路径/情绪/模板登记。新增专项先因 `npc_encounter_bai_ren_初见` 未登记而退出 1，修后 `NONCOMBAT_NPC_GENERATED_REGISTRY_PASS ids=60 variants=720 duplicate=rejected`；由 `_index_document` 输入重复 NPC 使生成 ID 冲突报错，篡改已登模板被消费者拒绝。网页真实场景对照 `NONCOMBAT_NPC_GENERAL_PASS cases=4` 与 `NONCOMBAT_CONTENT_REPOSITORY_PASS modules=75 cards=588` 均退出 0。该证据覆盖登记和四个来源实例，未证明 60 个 ID 或 720 个变体在自然长局全可达；N1 仍未签收。

**N1 里程碑补证（2026-11-03）**：通过内容仓库 `_index_document("data/npcs/core_npcs.json", ...)` 输入重复 `ds_demoness`，`Duplicate generated_card ID: comp_ds_demoness_milestone_bond_acquaint` 被拒；`noncombat_companion_milestone_registry.gd` 退出 0。`noncombat_companion_milestones.gd` 把待选里程碑状态写入真实 `RunSession` v2 文件，另建 `RunSession` 从磁盘冷读，再由生产 `Events.card` 重建并核对可见卡，退出 0。这个冷读证明持久化字节和卡片来源投影；该用例的第 12 次决定状态为构造样本，缺真实选择史，因此不能据此声称 `Domain.restore()` 严格历史重放或自然长局通过。

**N1 道侣里程碑生成卡来源登记 ISSUE-02（2026-11-03，局部，待独审）**：网页 `CompanionSystem.js::_checkAffectionMilestones → _buildMilestoneCard` 为可登记的 15 名 `core_npcs.json` 人物各产生 5 种阈值卡，合计 75 个动态 `comp_<人物ID>_milestone_<阈值ID>`。Godot 既有 `companion_milestones.json` 是网页函数 SHA 固定的派生目录，实际 `_milestone_card`/`take`/`card` 之前未在 N1 来源库登记这些 ID。新增只读 `generated_card` 索引逐 ID 留存网页函数符号、源码 SHA、派生目录 JSON 节点/SHA、人物 ID 与阈值/方向/一次性 flag；Godot 出卡及恢复共用 `_milestone_card` 按登记卡 ID 与模板核对。新专项先因缺 75 个登记而退出 1，修后 `NONCOMBAT_COMPANION_MILESTONE_REGISTRY_PASS count=75`，伪造已登记模板被消费者拒绝；`NONCOMBAT_COMPANION_MILESTONES_PASS`、`NONCOMBAT_COMPANION_EVENTS_PASS`、`NONCOMBAT_CONTENT_REPOSITORY_PASS` 均退出 0。此批未证明 75 张在自然长局全部触发，N1 全阶段仍未签收。

**N1 动态同伴事件来源登记 ISSUE-01（2026-11-03，局部，已独审，未见本批确定 P0/P1；实际可达仍由运行时判定）**：玩家契约是可达的 `comp_<道侣ID>_<作者事件ID>` 能回查原事件、来源位置与生产门槛，Godot 出卡与恢复都以该来源登记核对。浏览器 `CompanionSystem._buildEventCard` 和 Godot `NoncombatCompanionEvents._build_card` 都从 `data/companions/events.json` 生成 ID；修前仓库仅按原事件 `blx_1` 建静态卡索引，`comp_bai_luoxuan_blx_1` 查询为空，内容仓库专项先红（exit1）。现 `generated_card` 独立索引登记 8 名同伴 38 条作者事件的生成 ID、原事件 JSON 指针、来源 SHA、两个生产函数及作者门槛、选项效果整数键约束、剑灵儿旧师遭遇依赖和运行时抽取门槛；实际可达性仍由 `_eligible` 判定，Godot `take` 出卡和 `card` 恢复据此核对原事件，通用事件仍按既有路径消费。隔离重复事件验证生成 ID 冲突报错；隔离来源 manifest 的同伴事件 SHA 漂移验证查询拒绝。`NONCOMBAT_CONTENT_REPOSITORY_PASS` 与 `NONCOMBAT_COMPANION_EVENTS_PASS` 均退出 0，真实种子路径出卡并恢复 `comp_bai_luoxuan_blx_1`。此批只覆盖该 38 条事件生产族，通用事件、里程碑与动态善恶危机仍需另行登记，N1 全阶段仍待验收。

**N1 坊市程序音效 ID（2026-11-03，局部，已独审，未见确定 P0/P1）**：`data/audio/path_identity.json` 的 `sfx_market_regulated`、`sfx_market_bazaar`、`sfx_market_ghost` 有作者 `runtime.id` 与 `procedural` 参数，`runtime.path=null`。网页 `AudioManager.js` 按 ID 接收交易音效，Godot `noncombat_market_audio.gd::_make_transaction` 生成 PCM 并由实际交易播放。原 N1 音频索引只收文件路径，`find("audio", "sfx_market_regulated")` 为空；内容仓库专项加入 40 个总音频 ID、真实来源指针/源 SHA 与 `generated_stream` 状态断言，修前退出 1。现在同一只读索引纳入这 3 个 ID，`audio_status` 明确返回程序生成且无包内路径、无文件/SHA/预加载流；37 个文件音频仍保留 `packaged_stream` 与原 SHA 校验。坊市消费者专项在 3 个作者交易 ID 上核对索引的原 runtime、JSON 指针和生成状态，再实播 PCM、核长度和静音；`NONCOMBAT_CONTENT_REPOSITORY_PASS` 与 `NONCOMBAT_MARKET_AUDIO_PASS profiles=3 layered=3 transactions=3 mute=3` 均退出 0。此批没有改播放实现；动态卡生产者登记和 N1 全阶段仍待验收。

**N1 来源音频 ID 与资源定位（2026-11-03，局部，已独审）**：`data/audio/path_identity.json` 的 37 个运行媒体 ID 指向 32 个不同文件；`noncombat_opening_audio.gd` 按 `bgm_sect` 等 ID 消费，原 `ContentRepository.find("audio", "bgm_sect")` 返回空。先在内容仓库专项加入真实 ID/原 JSON 指针/源 SHA/可加载流断言，修前退出 1（`audio ID lost source and runtime path provenance`）。现仓库把每个 `runtime.id` 与原 `runtime.path`、来源指针纳入只读索引，`audio_status(id)` 分别返回 manifest 登记、包内文件存在、SHA 与 `AudioStream` 可加载状态；经 `_index_document` 的隔离重复来源文档验证同 ID 拒绝。资源门禁不再把音频引用只压成路径集合：隔离来源将 `bgm_sect` 路径改为不存在文件时，错误包含源 JSON 指针和 `consumer=audio:bgm_sect`。修后 `NONCOMBAT_CONTENT_REPOSITORY_PASS`、`NONCOMBAT_ASSET_REFERENCE_DIAGNOSTICS_PASS`、`NONCOMBAT_ASSET_COVERAGE_PASS images=531 animated=3 audio=32`、`NONCOMBAT_OPENING_AUDIO_PASS`、`NONCOMBAT_MARKET_AUDIO_PASS` 均退出 0；隔离 manifest 把原流 SHA 改错时仓库仍保留来源定位并拒绝认证。独立只读审查未见本批确定 P0/P1；播放行为未改。当批的文件媒体索引未含 3 个无文件路径的坊市程序音效，现已按上方续批另行登记。动态生成卡的生产者登记及 N1 全阶段仍待验收。

**N1 人物阶段立绘 ID 索引（2026-11-03，局部，已独审）**：来源 `data/companions/portrait_stages.json` 声明 35 个阶段 ID 和原图路径，浏览器 `src/ui.js`/`HeavenlyGallery.js` 与 Godot `noncombat_companion_portraits.gd`/`noncombat_heavenly_gallery.gd` 均按这些阶段展示；此前内容仓库只索卡、任务、线程、NPC，`find("portrait", "bai_luoxuan_trapped")` 返回空。`noncombat_content_repository.gd` 现把每个阶段的 ID、原文、`$.portraitStages.<角色>.stages[i]` 指针及源 SHA 纳入只读索引，重复或缺 ID/asset 给出来源诊断；原图仍经既有 manifest/SHA/Texture 路径验证。内容仓库专项先红于该真实阶段 ID，修后通过，并经 `_index_document` 的隔离重复阶段文档确认同 ID 报错；`NONCOMBAT_CONTENT_REPOSITORY_PASS`、`NONCOMBAT_HEAVENLY_GALLERY_PASS entries=1099 portraits=35` 与 `NONCOMBAT_ASSET_COVERAGE_PASS images=531 animated=3 audio=32` 均退出 0。独立只读审查未见本批确定 P0/P1；此批未改画廊行为，其他媒体 ID 与 N1 全阶段仍需验收。

**N0 当前工作树验收（2026-11-03，已签）**：最终基线 `artifacts/godot-migration/n0-baseline-20261103T021310Z/manifest.json` 收录 3599 文件与完整 Git 工作树状态，`--check` 复跑通过；63 个网页脚本均有登记，175/175 张非战斗候选图逐张用途裁定且 0 待审。74 份来源 JSON 可解析，531 图/3 动画/32 音频的已选资源 SHA 门禁、网页三门禁、开局/序章真实来源轨迹与 Godot 专项通过。独立只读审查未见 N0 出门条件的确定缺口。该签收限当前工作树，相关文件尚未提交；48 个脚本的完整玩法一致性、未挂接素材的正式采用及 N1–N11 仍待后续验收。总计 **1/12**。

**N7 道侣危机 ISSUE-01（2026-11-03，局部，待独审）**：玩家契约是在炼气期单次善恶净变绝对值至少 15、已拥有且实体在场的道侣好感至少 50 时，由该次选择生成可见、左右均可选并产生不同后果的危机卡。修前 `src/game.js::_checkCompanionCrisis` 只发 `type/title/desc`，`CompanionSystem._buildEventCard → _fmtChoices` 因无 `choices` 抛错；`node tools/test_companion_crisis_source.js` 经真实白狐任务右选与公开事件检查复现零卡，退出 1。现唯一作者来源 `data/companions/qi_crisis.json` 提供同一炼气危机的善/恶两个变体及各两项选择；网页真实 `q_whiteFox_quest.right`（善 +18、白璐璇在场）和 `.left`（恶 +18、剑灵儿在场）均出完整危机卡，筑基以上不再投递缺选项的动态危机，保留 `events.json` 高境界作者事件池。Godot 的 `NoncombatDomain._persist_snapshot` 在同一选择候选中调用 `NoncombatCompanionEvents.queue_crisis` 写 `companionProgress.pendingCrises`，`take` 先于普通随机道侣事件取队列；双候选按生命/回合确定抽签，后续触发覆盖单条未消费危机；若抽中已缺席道侣，本次检查丢卡而不改选其他人，`card` 按源 SHA 和变体重建，`settle` 结算数值、好感/信任与一次性回执并清待处理；包内新来源 SHA 为 `e8953640583d339f760f665fa9079a90098a992a2f42c1ba505971b7e5f2c9f7`。专项 `NONCOMBAT_QI_COMPANION_CRISIS_PASS` 从 Godot 真实白狐选择入口注入已拥有/好感 60 的测试前态，覆盖两种符号、选择与危机同次原子存档及写盘失败原字节回滚、双候选抽签与覆盖、优先调度、RunSession 冷读后重建、左右选项可用、不同结算及域可见卡选择；修后与网页专项、白狐严格重演入口、原道侣事件、内容库 75 模块/588 选择节点及两变体原 JSON pointer 均退出 0。炼气来源授予仅 `q_love.right → mortal`，该 ID 不在注册 NPC/道侣目录，故没有已证的自然炼气合格道侣获取路径；该受控前态未证明自然长局，也未证明该受控危机档的严格 `Domain.restore` 重演（受控注入不在历史中）；本切片局部，N7 总阶段未签收。

**N10 本批门禁快照**：`NONCOMBAT_BROWSER_COMBAT_ACTION_COLD_PASS`（红→绿）、`NONCOMBAT_BROWSER_COMBAT_ENEMY_TURN_COLD_PASS`（真实来源 5 值 parity）、`NONCOMBAT_BROWSER_COMBAT_PENDING_IMPORT_PASS`（合法来源旧档）、`NONCOMBAT_BROWSER_OPENING_IMPORT_PASS`（四修旧导入）与 `NONCOMBAT_BATTLE_RETURN_PASS`（旧战斗返回）均退出 0；独立只读审查复跑指定专项，未见本批确定 P0/P1。证据属于当前工作树，浏览器来源检查使用已有采集文件。

**N10 首战后续随机权威补正，ISSUE-01（2026-11-03，局部，已独审）**：玩家契约是已导入的剑修首战从首个敌方反应进入第 2 回合后，关闭再打开仍由同一已核对遭遇状态决定牌序；旧实现的 `noncombat_browser_combat_actions.gd::_reaction_random_values` 把浏览器快照的公开 `authoritySeal` 放入 Godot 未来随机种子。`main.tscn` 的承受操作经 `NoncombatDomain.commit_browser_combat_reaction → RunSession.commit_snapshot` 原子写入回执，`NoncombatDomain.restore → BrowserCombatActions.replay` 逐值重演；但攻击者向 `browserCombatSnapshot` 加无关 nonce、重算公开 seal、重派生 5 值回执，冷读仍接受且可改变牌序。`noncombat_browser_combat_action_cold.gd` 已固化这条完整反例，修前失败于 `resealed unrelated nonce and rederived tape changed cold authority`，退出 1。现从严格冷读逐项绑定到重演世界的修路、境界、世次、决定钟、血量/道心/灵气/血上限/牌组，以及经遭遇合同核对的 Godot owner/来源卡/遭遇 ID 构成固定权威投影，域隔离派生未来 5 值；来源 snapshot 的额外字段及可重算 seal 不参与种子。合法来源旧网页战中档仍按原语义器导入；独立浏览器 5 值 tape 仅校验规则等价，不代表导入后 Godot 与浏览器随机流同序。本修复不提供密码学防伪承诺。目标冷读专项修后退出 0，包含无关 nonce 全重封印/重派生、合法范围内篡改、写盘失败原字节/状态不变、两次冷读及结果一次结算；来源 parity、旧导入与旧战斗回归见本批门禁结果。本批独立只读审查未见确定 P0/P1；第 2 回合继续出牌、其他战斗档和 Windows 可见 GUI 尚未验收，N10 与 N0–N11 仍 **0/12**。本段取代下方历史段落中“从来源战斗封印派生未来随机”的旧实现说明。

**N1 来源图片诊断 ISSUE-01（2026-11-03，局部）**：玩家契约是改错一条来源图片引用或漏打包图片时，门禁直接指出源文件、JSON pointer 与该卡/脚本消费点。入口为 `python tools/validate_noncombat_asset_coverage.py`，读取 `data/**/*.json`、网页加载脚本与样式，再比对 `godot/content/source_manifest.json` 和 Godot 打包文件；原实现把图片路径压成集合，丢失来源位置。修前 `python tools/test_noncombat_asset_reference_diagnostics.py` 用隔离 JSON 中 `card:diagnostic_card` 的 `$.cards[0].sceneImage` 改为不存在图片，门禁仍退出 0，专项退出 1。修后验证器保留来源、pointer/脚本行和消费者，缺 manifest 条目、缺源/包内文件及 SHA 错误均带该定位；同专项还用隔离 manifest 把真实 `data/cards/qi.json` 场景图指向不存在的打包文件，两个负例均被拒，专项退出 0。原 `NONCOMBAT_ASSET_COVERAGE_PASS images=531 animated=3 audio=32 copied=1095` 和 `NONCOMBAT_CONTENT_REPOSITORY_PASS modules=74 cards=586 quests=6 threads=12 scene_refs=553 unlisted=0` 均退出 0。负例专项已接入 `tools/validate_godot_runtime.py` 总门禁，`py_compile` 与专项复跑退出 0；独立只读审查未见此批确定 P0/P1。权威状态为来源 JSON 与 manifest，验证器只读取并诊断，不写玩法状态。N1 的其他 ID/媒体消费者与完整可达性仍按任务书验收，阶段未签收。

**N10 首战敌方行动续档（2026-11-03，局部）**：从前述真实 Chromium 浏览器战中档的 `afterReload` 原始 localStorage 经公开恢复界面续打 `sword_edge`、`sword_followthrough`，点击结束回合后到 `REACTION_OPEN`，再选“承受”进入第 2 回合；各阶段完整原始存档与战斗封印、实际 5 次原生随机值及调用栈见 `artifacts/godot-migration/noncombat-browser-import/combat-turn-source-sword.json`，`node tools/capture_noncombat_combat_turn_browser.js --check` 退出 0。Godot 用该来源 tape 重演两张牌、结束回合和敌方行动，精确核对反应窗口、血量、牌序、敌方计划与 5 次随机消费；修前红测先发现冷载轮次数值生成 `1.0:...` 信号键与浏览器 `1:...` 不同，修正后继续红于故事槽无结束回合写入者。现仅该两张牌序列可原子提交 `END_TURN`；独审另复现完整性 P1：回执中 5 个合法随机值可被任意改写，冷读仍将其当权威；新增合法范围内改写洗牌值红测，修前退出 1。现在从已验来源战斗封印、Godot 遭遇 owner 与固定首反应序号派生域隔离 PRNG，取 5 个可重算值随动作回执原子保存；live 消费同一 tape，冷读先重算逐值比对再重演。写盘失败保持原槽字节、战斗态与演出不变；越界及合法值改写随机回执均拒绝；反应窗口与第 2 回合分别冷读，后者牌序/血量一致，撤离结果只结算一次。来源 tape 只用于验证规则等价，生产导入后的未来随机结果由 Godot 派生流决定，并非浏览器未来随机流；动作回执仍原子保存；第 2 回合继续出牌及其他来源阶段尚未实现，Windows 可见 GUI 尚未验证，N10 与 N0–N11 仍 **0/12**。

**N7 全人物日程旧档回归（2026-11-03）**：全人物遭遇池启用后 `tick_schedule` 曾提前跳过白刃的逐回合日程，导致真实浏览器第 13 决策剑冢→宗门大殿时 `worldContinuity.revision` 浏览器 17、Godot 16，`noncombat_browser_mid_import.gd` 退出 1。移除早退后该真实旧档第 4–14 决策、双套保底、任务、冷读、原子及拒绝负例专项退出 0；NPC 全池、旧档延迟启用、首遇和公开双人自然路线回归也退出 0。独立只读审查确认地点不变时逐回合与抽卡两入口都不重复增加修订号，未发现确定 P0/P1。其余 NPC 自然路线仍未穷尽，N7 与 N0–N11 未签收。

**N10 剑修首战浏览器战斗中档切片（2026-11-03，局部）**：ISSUE-01 来源当前教程是 `tutorial_1–4` 后第 5 决策 `q_start_sword`，旧导入器仍按第 3 决策入道及“避战”导演状态裁定；教学战斗域也只承认 baseDecisionIndex 3。真实 Chromium 公开界面原始 localStorage 快照在 `artifacts/godot-migration/noncombat-browser-import/combat-pending-source-sword.json`，同时含战斗首回合打出 `sword_sheath_guard` 的 pending 与刷新后两份状态。现专用进口分支重演 5 次来源选择、遭遇接战和预警，核对非战斗关键字段与双方 owner 合同，再将来源手牌/抽牌/弃牌、真元、护盾、敌方状态与意图载入 `main.tscn` 实战域；原故事槽严格冷读回到同一待战合同。`noncombat_browser_combat_semantics.gd` 仅认可这一个 TURN_START+CARD_PLAY 形状，校验浏览器封印链、来源开场 HP/牌堆分区守恒、首张守牌效果及遭遇所有权；修前重封印重复手牌会被错放，修后重封印的首态真元、重复/丢失牌在语义与进口层拒绝，伪档替换不改原槽字节。独审另复现并修复了三条 P1：重封印伪造敌方防御/层级、专用分支静默丢未映射库存、冷读战斗权威与严格重演世界属性脱钩。三条在本窄样例的最终快照复审通过；`NONCOMBAT_BROWSER_COMBAT_SEMANTICS_PASS`、`NONCOMBAT_BROWSER_COMBAT_PENDING_IMPORT_PASS`、`NONCOMBAT_BROWSER_COMBAT_SCENE_PASS`、原 `NONCOMBAT_BROWSER_OPENING_IMPORT_PASS` 与 `NONCOMBAT_BATTLE_BOUNDARY_PASS` 专项退出 0。场景专项是 headless 实例化，不是 Windows 可见 GUI。来源样例从中途状态撤离可一次结算，重复回传拒绝，战果冷读通过；**首回合后续出牌的动作持久化见下方续记，其他浏览器战斗阶段/路线仍拒绝，N10 与 N0–N11 均未签收（0/12）**。

**N10 已导入首战续打冷恢复（2026-11-03，仍为局部）**：真实浏览器来源首态保持不可变；Godot 故事槽的 `RunSession.commit_snapshot` 是唯一动作持久写入者。`main.tscn` 在实际出牌前请故事域重放已有动作、验证场景前态，计算合法候选后原子提交动作日志；写盘失败不改手牌、真元、动画或原槽字节。冷读从封印来源首态逐条重放动作，伪造卡 ID/手牌位置拒绝；实测第二张 `sword_edge` 出牌后关闭场景、重启恢复手牌与真元，再出 `sword_followthrough` 并二次冷读，随后撤离只结算一次且结果可冷读。修前红测因场景没有动作持久接口退出 1，修后 `NONCOMBAT_BROWSER_COMBAT_ACTION_COLD_PASS` 退出 0。本段记录当时仅支持首回合出牌；结束回合、首个敌方反应与抽牌冷恢复见上方新切片。其他来源战斗阶段仍未覆盖。此场景测试为 headless，Windows 可见 GUI 尚需重导出后验证；N10 和 N0–N11 均未签收（0/12）。

**N10 剑修首战独审补正（2026-11-03）**：独立只读审查找到三处确定 P1 并以修前红测验证：全重封印伪造第二态 `enemy.defPower=100` 可进战斗；专用导入绕过通用库存所有权检查，注入 `itemInventory` 会静默丢物；严格冷读把战斗权威副本原样拷回，若与重演世界 health 分裂仍可通过。现敌防御/等级按作者敌人模板与首/次态锚定，专用分支拒绝未映射库存/法宝/交互额度/待装备选择并对照来源因果种子与资源，冷读前将战斗 authority 的修路/境界/生命身份/决策钟/血上限/牌组及 health、daoHeart、aura 与重演世界逐项绑定。全重封印伪造、库存注入及战斗/世界分裂负例在进口层拒绝；专项重跑退出 0。该范围仍为首场剑修第一守牌，首回合后续出牌的动作持久化见上方续记；Windows 可见 GUI 未证实，N10 未签收。

**N0 图像范围独审纠偏（2026-11-03）**：原 230 张未入运行包“非战斗候选”混入 55 张 `assets/cards/combat/*` 战斗卡图；当前目录排除这一路径后为 **175 张**。`audit_noncombat_migration.py`、`audit_noncombat_coverage.py --check` 与 `validate_noncombat_asset_coverage.py` 退出 0，来源 59 JSON/615 选择节点/1257 分支，运行已选 531 图/3 动画/32 音频 SHA 覆盖通过。当前逐图账本为 **69 张目视/来源选图排除裁定、62 张 provenance_only、34 张已目视但未挂接的同伴事件候选、10 张其他已审未挂接候选、0 张待裁定，共 175/175 已审**。最后 10 张逐图用途裁定为 6 张身份未证且未挂接的人物概念候选、2 张未挂接旧水墨背景、2 张仓库根多余的战斗房间图输出。背景现行 CSS 选 `bg_inkwash_masterpiece.png` 且 Godot 使用其 JPG 别名；正式青云战斗 profile 选 `qingyun_trial_room_v1.png`，两张根 room 图与同名 Godot 候选 SHA 亦不同。10 张均无当前运行来源的完整路径引用；该结论不证明候选身份、美术质量或可作为正式素材。当前 N0 图像裁定账本已满 175/175，N0 整段仍待当前源码/工作树基线、网页与 Godot 门禁及独立审查复核，不能据逐图数字直接签收。34 张同伴事件候选现逐图有源图 SHA、可能的事件 ID、具体画面/事件对照和人工判词：1 张主体相近，10 张仅主题部分相近，16 张画面与事件动作错位或泛化，4 张 `scene_sn_*` 无对应事件 ID，3 张 `scene_comp_*` 只有角色主题。校验器逐项查事件 ID 真实存在及当前 data/63 网页加载脚本/index/Godot 运行清单无原图完整路径引用；此状态只记录未挂接候选，不表示事件图已实现、自然可达或美术通过。该轮之后待裁定的 10 张为 6 人物、2 旧背景、2 room layer，现已按上文逐图复核。本轮单张追证：旧报告与美术来源清单确认 `card_bailuoshuang_pc98.png` 是 `bai_luoxuan`（白落霜）的身份参考，当前加载的 `PC98CardSystem` 已将该 ID 和旧别名 `bailuoshuang` 都选到 `collected/bai_luoxuan_pc98.png`，其 Godot 副本 SHA 相同，故旧卡图排除。该轮之后仍有 6 张人物、34 张同伴事件、4 张背景/房间图待裁定；同伴事件图的后续逐图审查见本段当前状态。本批再裁定 15 张剑灵儿/九尾溯月变体（其中 3 张与已审旧图 SHA 完全相同）；逐图比对当前阶段作者选图与 Godot 副本。该批之后余 7 张人物图，`yin_xue_intimate_*` 的黑衣女性画面与当前同名男性立绘身份不合，仅凭文件名无法裁定。本批另对剑灵儿 10 张、九尾溯月 5 张旧变体逐张目视，以当前阶段选图、原图/选图 SHA、Godot 同路径副本及当前入口无候选完整路径引用裁定；其余人物图继续待审。本批对剑灵儿与九尾溯月 8 张旧阶段立绘逐张目视；以 `data/companions/portrait_stages.json` 当前选图、Godot 同路径副本及 SHA 对照后记为异图排除，未凭文件名批量签收。62 张溯源原图逐张核同目录 manifest 的 raw/preEdit 路径与 SHA、不同目录 finalPath 与 SHA，并查当前 data/63 网页加载脚本/index/Godot 运行来源清单无原图路径引用；此判断仅说明原图用于溯源，不证明 finalPath 的生产可达或美术通过。`card_character_tianji_laoren.png` 画面内写“九尾溯月”并绘九尾女性，与文件名所称天机老人冲突。两张旧背景图虽与来源现选图构图不同，但 Godot 使用 JPG 派生图；两张 room layer 未找到生产选图路径；34 张同伴事件插画无当前完整路径引用且不与已打包图同 SHA，现已按上文逐图审为未挂接候选。其余路径分类只是候选提示。N0 未签收，N0–N11 **0/12**。

**N0 来源原图精确重复复核（2026-11-03）**：余下 62 张 `provenance/*` 候选逐一计算 SHA，与当前 `data/` 非战斗 JSON 的 `sceneImage`/`image`/`asset`/`portrait` 路径及相应 Godot 副本组成三方比较；无新增 SHA 全等项。故本批没有新增逐图弃用裁定，62 张均保持待审；此前三张全等原图的人工证据仍有效。此比较仅判精确重复，不替代余图的图片内容与来源用途审查。

**N7 手动交互独审补正（2026-11-03）**：原版闲聊把同一次随机值同时用于好感和台词，来源 `NpcSystem._onInteract` 的好感抽签与 `getDialogue` 的台词抽签实际先后独立；原夹具固定 `Math.random=0.4` 掩盖了偏差。来源夹具新增 `[0.0,0.9]` 顺序样例（好感 -1、通用台词），旧实现会选特定台词；Godot 现按动作/序号/阶段分别取确定随机值，冷读可重演。`_physical` 对 `worldContinuityState.npcs` 缺席和世次不一致拒绝，契合浏览器 `WorldContinuityStore.canPhysicallyAppear`；专项含缺席负例。夹具 `--check` 与手动交互专项均退出 0；最终快照的只读独审复跑未发现确定 P0/P1，确认真实界面入口、事务及跨决定冷重演。赠礼/筑基论道的公开玩家路线与真实浏览器入口完整等价仍未证实，N7 仍未签收。

**N7 手动 NPC 人物志与交互切片（2026-11-03，局部）**：ISSUE-01 浏览器 `index.html`→`GameUI.openNpcList/openNpcPanel`→`NpcSystem.getVisibleNpcs/_onGetPanelData` 的境界/物理可见人物、情绪心境、好感羁绊、已知信息、已解锁秘闻与符合条件的闲聊台词，现由 `noncombat_opening_ui.gd` 的人物志按钮→`noncombat_npc_interaction_ui.gd`→`noncombat_domain.gd`→来源 `npcs:core` 呈现；Qi 来源清单仅白刃 1 人，15 人是数据总数，非同时可见。ISSUE-02 `interact_npc` 经候选快照和 RunSession 提交，闲聊/赠礼/请教/论道按来源好感范围、礼物偏好倍率、源形状 `interactionBudget[npcId][turn]`、礼物实际扣数结算；NPC 记忆复用 `npcEncounterScheduling.memories`，好感同步 `npcAffection`、单人和双人标记，行动历史按决策位置严格冷重演。来源 `npc:taught`/`npc:discussedDao` 事件无数值消费者，未增加修为/道心。浏览器 `NpcSystem.loadData` 冷启动重置记忆、情绪、羁绊、秘闻；Godot 为严格存档重演持久化这些本世状态，此为明确差异。`node tools/capture_npc_manual_source.cjs --check` 与 `noncombat_npc_manual_interaction.gd` 退出 0，包含真实界面按钮、公开领域闲聊/请教、跨下一决策冷读、失败磁盘回滚与来源四动作夹具；赠礼/论道仅在直接流程源对照通过，真实获得礼物和筑基公开玩家路线仍未验收。N7 和 N0–N11 仍 **0/12**。

**N7 NPC 独立只读复审（2026-11-03）**：来源入口确未加载成长日程，六时辰日程与默认情绪为当前实际规则；单人 4 张与双人 2 张时辰可达样例的字段、队列、效果、冷却、全局 6 次上限与最多 5 次重抽在流程层 VERIFIED。敌对双人卡仅为模板对照；15 人全部从网页版自然入口到 Godot 冷档仍 UNPROVEN。全局上限/重抽专项在修后补写，缺修前失败运行记录，不能把该专项冒充完整严格门禁。复审未发现当前文件中的确定 P0/P1；地图实体筛选的初报经来源 `WorldMapSystem` 实际入口反证撤回。N7 与 N0–N11 仍 **0/12**。

**N7 动态 NPC 双人卡与 15 人单人遭遇（2026-11-03，局部）**：实查 `index.html` 未调用 `NpcSystem.loadGrowthData()`，故网页版当前运行用六时辰日程/默认地点，`realm_growth.json` 是未启用的作者候选。Godot 按此修正动态双人卡与单人遭遇。动态来源夹具有筑基宗门师徒、金丹月湖中立两条时辰可达样例；敌对白刃/血煞仅是来源模板样例，不宣称自然同地。专项逐字段比对三种模板、检验物理资格、分地点负例、12 回合冷却与效果，退出 0。单人遭遇现支持来源 15 NPC、15%+福缘抽签、记忆间隔和 720 个原场景模板，4 条来源样例逐字段通过（含非常见情绪的来源归一化）；来源全局 6 次遭遇上限与已玩卡最多 5 次重抽专项通过。旧存档、主流程长局和完整门禁需重验；其余 N7/N9/N11 出门条件仍缺，N0–N11 **0/12**。

**N7/N9 NPC 双人预设卡复核（2026-11-03，局部）**：独立只读审查指出交叉好感可能覆盖后续单 NPC 好感、同队列 31/30 优先级倒置、选择遗漏体修回合被动；现已在同一来源流程修复。专项覆盖五张作者卡的资格/once/效果、实际传承道心上限、死者负例；旧档下一次真实提交才启用交叉状态，失败提交不改字节。公开剑修路线经雷关胜利、筑基宗门自然抽到 `npc_cross_bai_ren_jian_linger_lesson`，同时排队时先发交叉卡，选前选后严格冷读及故障回滚通过；`NONCOMBAT_NPC_CROSS_PRESET_PASS`、`NONCOMBAT_NPC_FIRST_LEGACY_PASS`、`NONCOMBAT_NPC_CROSS_NATURAL_PASS ... double_queue=true regen=true portraits=true sizes=2 cold=true atomic=true` 均退出 0。桌面界面显示来源双人物立绘、原文与两项选择；Windows OpenGL 3.3 1280×800/1920×1080 截图在 `output/godot/npc_cross/` 已目视，容器均未越界。动态双人模板/12 回合冷却、另四张预设的公开自然路线、魔域入口及 N7/N9/N11 整段验收仍缺；N0–N11 **0/12**。

**N7 NPC 交叉预设卡原始切片（2026-11-02）**：`noncombat_npc_cross_flow.gd` 从来源 `npc_cross_cards.json`、`npc_relations.json`、`core_npcs.json` 取五张作者卡、关系初值及人物境界，按 `NpcSystem.js` 的同区域双人物理资格、15% 抽签、权重和来源语义 once，作为 `narrative:31` 入队。`noncombat_domain.gd` 接入待选、结算、事务与旧档启用点重放；`bond_*` 与选项 `npcAffection` 各结算一次，`npc_relation:*` 更新关系。原白刃初遇和雷关筑基冷读回归退出 0。后续修复与新证据见上段；N7 与 N0–N11 仍 0/12。

**N7 下一整族切片边界（2026-11-02，只读调查）**：五张预设 NPC 交叉卡有来源数据而无 Godot 双 NPC 消费者。来源要求本世持久抽签/待发身份、区域兼容的物理在场、优先级 31、选择后一次性语义记录和两路好感及关系效果。剑崖师徒预设可作为宗门区域内事件，是否把它记为剑崖地点亲历须明确作为来源差异；魔域预设缺干净首世到达入口，不能以构造状态当自然路线。此段仅界定后续实现与验收，不算完成证据。

**剑崖地点卡干净首世可达性（2026-11-02）**：来源 74 份 JSON 全量枚举的 12 处 `playerLocation` 效果均不指向字面剑崖；初始化、剧情卡驱动、效果/商店、突破、地图点击及 SceneLayerSystem/StoryNetworkSystem 的生产链只读追踪亦没有干净首世转入剑崖的入口。三张地点卡不能用构造状态冒称自然可达；旧档若本来携带剑崖位置仍另审。复核来源注释后，宗门与剑崖的区域兼容允许师徒为预设剧情赴剑崖，触发资格本身不是 P1；地图仍标宗门当前点且剑崖不记亲历，地点卡因此无法自然衔接。当前 Godot 交叉卡消费者与地点卡全链尚未完成，不签收 N7/N11。

**筑基关后金丹首普通卡门禁（2026-11-02）**：旧 `noncombat_foundation_gate_natural.gd` 固定种子路线在金丹抵达后至来源普通抽卡实际有 30 次前置处理，原 24 次循环误报。只修测试观察边界至 48 并保留卡 ID/阶段失败轨迹；重跑 `NONCOMBAT_FOUNDATION_GATE_NATURAL_PASS ... pre_draw=30` 退出 0，严格冷读及原断言未放宽，玩法未改。

## 2026-11-02 N9 环境特效与稳定背景 Slice Charter + Evidence

**玩家合同**：网页版 `ExperienceSettings.js` 把 `effects`、`steadyCamera` 保存在玩法档外，`ThreeBackgroundSystem.js` 用质量档调粒子预算/透明度/速度/帧率，用稳定模式停止背景呼吸。Godot 先前只有静态背景和阅读偏好，无真实特效消费者。

**实现与验证**：新增 `noncombat_ambient_particles.gd`，在槽页/剧情页原背景之上、内容控件之下绘制稳定种子的 2D 灵气层。低/均衡/高分别 80/210/380 点与 30/30/60 FPS 目标，透明度及速度采用来源档位比例；`steadyCamera` 在 Godot 以“稳定背景”显示，实际停止呼吸缩放。战斗交接时隐藏并停止处理，返程恢复。三个质量档都由真实设置弹窗切换并由 `ExperienceSettings.new(path)` 冷读，非法值拒绝；`noncombat_experience_settings.gd` 退出 0 且玩法状态 JSON 比较不变，`noncombat_qi_gate_live_flee.gd` 退出 0 并核战斗停绘/返程。Windows OpenGL 3.3 实采六张图位于 `output/godot/experience_effects/`，1280×800/1920×1080 槽页与 1280×800 剧情页低/高档均无新增遮挡或裁切，独立只读审查未见 P0/P1。普通抽卡阶段从真实 normalFlow.phase 驱动背景色/速度，q_shop 自然路线专项已验证；其它镜头运动、低端设备耗时及整体 N9 尚未验完；N0–N11 保持 0/12。

**雷关撤离复审（2026-11-02）**：独立只读复跑桌面撤离专项退出 0；核对网页版撤离许可、章节卡转移来源 ID 与结果卡前后冷读，未见本切片 P0/P1。新专项只核结果卡 ID，来源全文及资源差值由既有 `noncombat_qi_gate_outcomes.gd` 核验；真实战败、先击破与服丹购买到实战仍未同轨证明。

## 2026-11-02 N2/N7 旧 NPC 行程元数据冷读 Slice Charter + Evidence

**失败与来源**：后段门禁 `noncombat_foundation_sword_trial_contract.gd` 修前退出 1，旧 q3 快照白刃闭关室记录为第 25 回合、revision 17、`reason=schedule`；现行重演的逐选择 NPC 行程使位置又变化，且 `NpcEncounterFlow.tick_schedule` 按当前元数据写 `initial_presence`。旧档无 `worldContinuityActivationIndex`，与新排期规则缺时间边界。失败发生在完整重演后严格 JSON 相等比较，没有放宽该门禁。

**修复与证据**：仅当 `worldContinuityActivationIndex` 已生效时逐选择 tick；缺标记旧档按保存决定序号之后才激活。旧世界状态白刃 `reason=schedule` 且标记晚于旧历史时，`NpcEncounterFlow.collect()` 在标记前按旧 `changedAtTurn` 和 `reason` 回放，标记后和真实续局走现行规则。修后 `NONCOMBAT_FOUNDATION_SWORD_TRIAL_CONTRACT_PASS directions=2 replay=true` 与 `NONCOMBAT_FOUNDATION_SWORD_TRIAL_OUTCOMES_PASS directions=2 outcomes=3 replay=true rollback=true` 均退出 0，后者覆盖旧档更新为新快照后的二次冷读和六种胜败逃。NPC 新档两方向、旧死亡档回归退出 0；独审只读追踪前后规则边界未见 P0/P1。二周目缺标记且带旧元数据的独立样本尚缺；后段总门禁在跑，N2/N7 与 N0–N11 保持 0/12。

## 2026-11-02 N5/N8 炼气雷关来源战场 Slice Charter + Evidence

**玩家合同与原断点**：自然炼气百点决断已存 `BATTLE_PENDING`，原桌面解析器因缺 `ch_qi_100` 来源身份拒绝开战；战场目录同 ID 的通用遭遇是 HP 8/tier 3，章节卡为 HP 5/四态雷律且可撑三回合取胜。原美术目录 `runtimeScene` 空，来源石傀动作图也未打包。由章节卡 `data/cards/chapter_milestones.json` 负责战斗快照，由 `RealmGateFlow` 负责唯一奖励/破境结算。

**实施与证据**：`BattlePlanResolver` 认证章节快照并经 `StageRouter.resolve_choice` 绑定；独立 `duel_stage_qi_gate_2d.tscn` 复用来源 2D 渲染脚本，打包章节卡引用的战场、石傀原图与动作帧。同步脚本从章节卡和 `action_presentations.json` 重建素材清单，`RUNTIME_CONTENT_SYNCED data=74 art=1095 audio=32` 退出 0。`CombatDomain` 加入第三回合敌行动后存活胜利、筑基丹减伤，卡牌信号按作者图转移顺序取首个可用转移，`lastTransition.sourceCardId` 与网页版 `originalCard.id` 均为 `ch_qi_100`。自然路线 `noncombat_qi_gate_entry.gd` 输出 `NONCOMBAT_QI_GATE_ENTRY_PASS ... survival=true counter=true plan_order=true return=true replay=true`、退出 0；含桌面开战、首领音乐、界面三次结束回合/承受反应、敌人仍存活时结算、返回按钮与结果卡确认、严格冷读。`noncombat_qi_gate_live_flee.gd` 又从自然待战档按真实撤离/返回/确认按钮，返回来源撤离卡并两次严格冷读，输出 `NONCOMBAT_QI_GATE_LIVE_FLEE_PASS`、退出 0，已列入总门禁。规则探针在同一来源请求上仅切换服丹 flag 与提高探针 HP，观察未服丹 4 点/服丹 2 点；未把探针修改当作自然购买证据。筑基/金丹关与首剑战回归通过。独立只读复审未见本切片 P0/P1；先击破、真实战败与玩家真服丹路线仍待验证；完整总门禁未结，N5/N8 和 N0–N11 保持 0/12。

## 2026-11-02 N9 阅读设置 Slice Charter + Evidence

**来源与实现**：`src/systems/ExperienceSettings.js` 的高对比、易读字体及字号三档现经 `noncombat_experience_settings.gd` 存到玩法槽外，槽页和剧情页均有键盘可聚焦的“阅读设置”入口。Godot 文本倍率与来源 0.92/1/1.14 一致；高对比增强剧情遮罩、正文板和关键文字；动态生成的界面控件在挂载后按帧统一应用字号/字体，关闭易读字体时恢复作者样式。未修改玩法领域状态。

**实测与限制**：`noncombat_experience_settings.gd` 专项验证槽页、剧情页、持久偏好、字体/倍率、高对比、运行时生成的万物志按钮、重置、玩法状态零修改及双分辨率下当前剧情正文区域、选项行、万物志弹窗的边界，输出 `NONCOMBAT_EXPERIENCE_SETTINGS_PASS`、退出 0；开局 UI、万物志回归退出 0。Windows OpenGL 3.3 的四张实画面保存在 `output/godot/experience_settings/`，已目视检查当前教程卡与弹窗内容在 1280×800、1920×1080 均未裁切。独审首轮发现 `Color` 类型推断解析失败与动态弹窗漏应用，修后独立复跑退出 0，未见剩余 P0/P1。所有来源卡在大字下的完整布局及高对比覆盖全部弹窗仍未证明；背景特效预算及呼吸稳定已见本日新切片；其它镜头与战斗反应模式仍待迁移，N9 和 N0–N11 仍 0/12。

## 2026-11-02 筑基升级宗门讨伐当前规则轨迹

**失败与根因**：旧升级长路线的种子 2 在新增因果展示卡改变决断排期后，没有在 210 次决断内抽中来源营地。旧测试还会在再次遇营地时重复升级同一张 `+` 牌，造成测试自身误报。两处均为测试路线假设，生产调度与升卡代码未改。

**修订与证据**：按当前 `CardSystem` 每 15 回合 30% 的营地抽签与当前普通抽卡轨迹选定种子 764850；真实同门比试供款，30 回合营地命中，31 回合首牌升级，66 回合抽到 `f_mission`。后续严格冷档、战斗请求含升级牌、来源舞台资源加载、桌面启动战斗并撤离回剧情的专项输出 `NONCOMBAT_FOUNDATION_MISSION_UPGRADED_NATURAL_PASS`、退出 0。第二次营地依作者 `camp.json` 的 `up` 离开。独立只读复审核对作者选项、可重放随机和专项日志，未见 P0/P1；复审指出的旧种子文档已标为历史证据。完整总门禁继续，N0–N11 仍 0/12。

## 2026-11-01 N0 作者文本换行 Slice Charter + Evidence

**来源与实现**：`src/core/TextPresentation.js::normalizeNarrativeText` 把作者文本中的字面 `\\r\\n`/`\\n` 与真实回车转为换行，三行以上空行合为两行并去首尾空白。Godot `noncombat_text_presentation.gd` 实现同一字符串规则，剧情正文、天道画廊详情、普通万物志、因果簿与故事线面板在显示边界共用它，玩法槽与作者 JSON 均不改写。

**证据边界**：`noncombat_text_presentation.gd` 专项核对混合转义、真实回车、连续空行、null 和实际剧情卡/画廊，输出 `NONCOMBAT_TEXT_PRESENTATION_PASS source=true story=true gallery=true`、退出 0；画廊、普通万物志、因果簿、故事线各自 UI 回归退出 0，覆盖账本 `--check` 通过。独审独立运行专项退出 0，未见当前来源数据支持的 P0/P1；特殊剧情展示字段的全面文本审查仍缺，N0–N11 保持 0/12。

## 2026-11-01 筑基体修来源上限测试修订

**失败与证据**：门禁在体修“守住底线”结局报气血不符：当前游戏从 11 回血 3 到 14，旧测试仅按基础 `maxHealth=12` 截断。网页版 `GameStateManager.getActualMaxHealth()` 会加聚合功法被动；作者 `config:path_skills` 中体修筑基“金刚不坏”提供 `maxHp+2`，因此实际上限是 14。专项现在从作者模块读取该被动计算期望，原奖励、完成状态、无深层种子断言保留；`NONCOMBAT_FOUNDATION_BODY_QUEST_PASS entry=true variant=true reward=true deep=true` 退出 0。玩法代码未改，总门禁从下一项继续，N0–N11 仍 0/12。

## 2026-11-01 N8 首领残卷旧档重放 Slice Charter + Evidence

**失败与根因**：总门禁的来源筑基剑修试炼旧快照在公开 `Domain.restore()` 最终逐值校验失败。定位到第 30 决定的历史境界首领胜利：快照的 `legacyRunState.pendingBossFragmentReward=null`，但现行 `submit_battle_result()` 重放后生成待领奖励，原存档被拒绝。文件读取、来源指纹和任务流本身均正常。

**修复与证据**：`Domain` 在真实首领奖励首次产出时持久记录 `bossRewardActivationIndex`；恢复缺标记旧档时，已有待领/领取历史按其决定序号重放，无奖励历史则从快照末决定之后才启用。严格重放时未放宽末态 JSON 比较。旧筑基试炼双方向 `NONCOMBAT_FOUNDATION_SWORD_TRIAL_CONTRACT_PASS directions=2 replay=true` 退出 0；`noncombat_boss_fragment_cold.gd` 新增“旧档恰停在首领胜利结果卡、无待领奖励”的冷读反例，同一专项完整通过现行自然首领胜利、待领、领取、写盘失败回滚和续局冷读，退出 0。独审独立重跑残卷冷档长测，未见剩余 P0/P1。总门禁从后续项续跑中，N8 与 N0–N11 仍 0/12。

## 2026-11-01 N9 故事线侧栏 Slice Charter + Evidence

**来源与实现**：网页 `StoryThreadEngine` 的近期日志及 `ui.js` 侧栏同时展示活跃故事线、最近五条终结记录里已完成的结语，以及未兑现因果种子；Godot 现从当前生命的 `storyThreadState` 和 `karmaSeeds` 只读投影，在剧情页“故事线”按钮打开原生面板。标题、阶段、进度、主导抉择与结语取已打包作者定义，不推进线程、不写另一份玩法状态。

**测试与独审**：`noncombat_thread_journal.gd` 对照来源定义验证活跃/完成/种子、作者结语、最近五条截断、空态/有数据 UI、不改当前状态及 1280×800/1920×1080 界限，输出 `NONCOMBAT_THREAD_JOURNAL_PASS source=true active=true completed=true seeds=true ui=true sizes=2`、退出 0，已接总门禁。独审发现境界变化产生的 `realm_expired` 必须占最近五条名额；补状态并加入五条较新境界终止记录遮蔽旧完成记录的回归，独审独立重跑退出 0，无剩余 P0/P1。种子态与完成态 UI 使用内存注入，自然触发→侧栏→冷档/转世长路线尚未通过，N9 与 N0–N11 保持 0/12。

## 2026-11-01 N9 天道因果簿 Slice Charter + Evidence

**来源与实现**：网页版 `KarmaSystem.getPlantedSeeds` 将当前未兑现种子投影为类型、剩余决断、境界、优先级、播种回合和说明；`ui.js::_renderKarmaLog` 在空态显示说明，在有种子时列出来源徽标与时机。Godot 剧情页现可打开“因果簿”，只读 `Domain.state.karmaSeeds`，不推进种子或结算因果。四种类型的 Getter 名称与 UI 短徽标按来源区分：血脉因果/宿命因果在簿内显示“血脉/宿命”。

**证据边界**：`noncombat_karma_journal.gd` 专项核对四种类型、负延迟归零、默认说明、空态与种子态、打开前后状态不变、实际玩家按钮及 1280×800/1920×1080 不裁切，输出 `NONCOMBAT_KARMA_JOURNAL_PASS source=true empty=true seeded=true ui=true sizes=2`、退出 0，已接总门禁。独审首轮未见 P0/P1，指出短徽标显示差异；修订后专项与独审各自重跑通过，本切片无剩余 P0/P1。有种子界面以注入当前内存状态验证显示，**不作为自然播种→因果簿→兑现的长路线证据**；N9 与 N0–N11 仍 0/12。

## 2026-11-01 N9 普通万物志玩家状态 Slice Charter + Evidence

**来源与入口**：网页版 `ui.js::openBestiary` 在非天道模式展示四个与当前存档绑定的标签：道侣、万物、功法、残卷；天道模式改开全览画廊。Godot 剧情页现有“万物志”入口按同一模式分派。普通页面只读当前 `Domain.state` 和校验过的作者模块：8 名人像解锁数/立绘阶段、灵石寿元/已持法宝与丹药、当前流派功法与境界门槛、6 套残卷/本流派绝学预览/本世激活加成。残卷追踪及手选立绘分别沿现有 `Domain.set_legacy_focus` 和 `Domain.select_portrait` 事务提交，页面不另存第二份玩法状态。

**证据与修订**：首次四页专项运行捕获默认 `focusedSetId=null` 时 `String(null)` 的运行错误、退出 1；修复后 `NONCOMBAT_BESTIARY_UI_PASS tabs=4 companions=8 skills=true focus=true replay=true heavenly=true` 退出 0。专项在真实剧情入口打开四页、浏览未结缘人物立绘而不写盘、按来源允许选择其零好感阶段、追踪残卷，随后在全新 Domain 中严格冷读两笔操作；还核对剑修名称、来源绝学预览、构造激活被动显示、天道模式分派及双分辨率界限。独审首轮指出绝学/被动和中文流派名缺失，修后独审复跑通过；随后按审查建议补了未结缘零好感阶段的解锁计数和可选状态，同一独审复跑通过，本切片无剩余 P0/P1。总门禁已登记，完整来源万物志细节与 Windows 可见长局仍待 N9/N11 验收，N0–N11 保持 0/12。

## 2026-11-01 N9 天道万物志只读画廊 Slice Charter + Evidence

**来源与入口**：`src/ui/HeavenlyGallery.js` 从当前 `DATA_MODULES` 建七类目录，天道模式下可看全部作者内容且不结算卡。此前 N0 把它误列为浏览器专用替换；本批改为待迁并新建来源目录消费者、桌面槽页/剧情页入口和独立偏好。Godot 目录读取打包 JSON 与 SHA 校验仓库，保留来源结构地址作为条目身份；打开画廊只读 `RunSession`。

**来源对照**：从当前 `index.html` 的 `DATA_MODULES` 按原 `buildCatalog` 过滤/遍历口径独立计算：人物立绘 35、人物秘闻 15、剧情与命线 762、功法与战斗卡 190、器物丹药 82、传承残卷 6、结局与真相 9，合计 **1099**。Godot 专项逐类精确核对同一数字与唯一结构键；桌面原图、48 项分页、搜索、作者详情、天道模式关闭/再打开、玩法状态不变及 1280×800/1920×1080 界限均已覆盖。初始专项先在“无玩家入口”退出 1，再接 Godot 界面后输出 `NONCOMBAT_HEAVENLY_GALLERY_PASS entries=1099 portraits=35 categories=true ui=true`、退出 0，已加入总门禁。

**独审修订**：首次独审发现目录数量虽对，详情却漏 `choices` 的后续叙事、左右抉择及秘闻等来源字段，判 P1；`ds_blood_moon` 的 `narrativeBlock` 先在 UI 专项退出 1。现按来源 `describe()` 顺序补主要文本、余音、隐秘、情报、传闻、交谈、抉择、结语和来历，并验证血月卡及“白落霜·参汤”原文，专项与独审复跑均退出 0，本切片无剩余 P0/P1。完整 `ExperienceSettings`、画廊外的万物志玩家状态页、Windows 可见导出与 N9 全量仍未验收；N0–N11 保持 0/12。

**N0 账本纠偏**：来源 `HeavenlyGallery.js` 提供七类可玩的只读内容浏览，Godot 无对应屏幕；现已从“浏览器专用原生替换”改为“待迁、无消费者”。现行账本为 63 脚本中的 48 待完整行为审查、12 浏览器替换、3 战斗边界。此前 47/13 是旧登记，不代表新验收。

## 2026-11-01 N9 全局声音开关 Slice Charter + Evidence

**来源与故障**：网页 `ui.js` 的“声音”按钮把 `ImmersionDirector` 与 `AudioManager` 统一静音，并将 `xiuxian_muted` 留在玩法槽之外；Godot 原 `noncombat_opening_audio.gd` 已接开局音乐、场景环境声、选择音效和誓言配音，但无总开关，玩家也无法在槽页或剧情页关闭声音。

**实现链**：槽页 `ToggleAllAudioSlots` 与剧情页 `ToggleAllAudio` → `noncombat_opening_audio.gd.set_muted` → Godot `Master` 总线（BGM、环境声及淡出尾音、SFX、配音与战斗舞台音效都由该总线输出）→ `user://noncombat_audio_settings.cfg`。此设置不写入 `RunSession`，切槽或重启仍生效；静音时保留原音轨和跨场景音量渐变，解除静音从当前音乐继续。

**修前/修后**：新专项修前因 `OpeningAudio.new` 无第三个设置路径参数退出 1；修后 `NONCOMBAT_AUDIO_MUTE_PASS bus=true persisted=true ui=true` 退出 0，覆盖静音后音乐仍在播放、静音时继续路由新音效与配音、重新实例化读取设置、真实战斗舞台两条音效走已静音的总线、玩家按钮两次切换及 1280×800/1920×1080 可见区域。原 `noncombat_opening_audio.gd`、`noncombat_opening_ui.gd`、`noncombat_companion_whisper.gd` 回归退出 0；新专项进入总门禁。来源 `ExperienceSettings` 的视觉与文字选项、其它 BGM 状态切换和市场语义音效仍未迁齐，N9 与总目标仍 0/12。

**独审与修订**：独立只读审查首次判 P1：仅静音新建 `NoncombatMaster` 总线时，三套战斗舞台的播放器仍默认走 `Master`，从剧情入战会重新出声。现总开关直接控制 Godot `Master`，专项新增实际战斗舞台音效节点断言；独审复跑专项退出 0，本切片无剩余 P0/P1。首次通过的非战斗总线专项不能替代此修复。

**门禁耗时实测**：山径战后回剧情 6 个来源分支逐行实测约 145–163 秒，合计约 935 秒，完整 `NONCOMBAT_MOUNTAIN_BATTLE_PASS cases=6` 退出 0。原 900 秒限时被完整工作量触发，现仅该专项调到 1200 秒；不删分支，不据此声称总门禁已通过。此项仍提示严格冷读性能需 N11 量化处理。

## 2026-11-01 N7/N9 道侣手选立绘 Slice Charter + Evidence Manifest

**目标与边界**：网页版来源 `CompanionSystem.js` 的好感解锁、明确选择、选图优先级、失败写盘回滚、每槽及跨世保留；Godot 玩家从已拥有道侣的常驻 HUD 打开阶段列表并换图。来源内容只从 `companions:portrait_stages` 读取。当前批不声明自然获得道侣的完整剧情路线，也不补网页版未定义的 HUD 详情弹窗。

| Issue | 原因、入口与权威 | 修前证据 | 修后证据 | 状态 |
| --- | --- | --- | --- | --- |
| NC-PORTRAIT-01 | 剧情页只自动取阶段图，缺 `CompanionSystem.selectPortrait` 对应操作；现由 HUD 按钮 → `Domain.select_portrait` → RunSession 提交 → `companionCosmetics.selectedPortraitByNpc` → HUD 与无作者场景图的当前 NPC 卡消费；`companionPortraitHistory` 严格重演，转世复制选择映射而不复制本世操作 | `noncombat_companion_portrait_selection.gd` 在 `has_method` 处退出 1：`desktop companion portrait selection is unavailable` | 同专项输出 `gate=true rollback=true replay=true slots=true rebirth=true ui=true`，退出 0；原 `noncombat_companion_whisper.gd` 输出 `source=true choice=true hud=true sizes=2 timeout=true`，退出 0 | 局部实现；独审未发现 P0/P1，跨世端到端与自然道侣 UNPROVEN |
| NC-PORTRAIT-02 | 来源效果可获得 `ds_demoness`，但没有阶段立绘；原 Godot HUD 拼 `concept_ds_demoness.webp` 而资源不存在，也只从专属道侣事件表取名字。独审指出首修误用了素念兜底图：网页版 `_getNpcPortrait` 对绯夜明确指定专属图。现从当前 `ui.js` 导出完整 NPC 肖像映射，以来源 SHA 和导出 SHA 校验，HUD 先取专属图、载入失败才用素念兜底，并从 `npcs:core` 取名字 | 最初专项退出 1：缺 `concept_ds_demoness.webp`；改成仅非空图后独审 REJECTED；补精确来源图断言再次退出 1 | 精确断言 `card_demoness_pc98.png` 与“绯夜”，专项输出 `generic=true`、退出 0；来源导出 `--check` 通过 | 局部 VERIFIED；自然拍卖路线未验 |

**验收边界**：专项 UI 使用真实 Godot 剧情页按钮、来源立绘及 RunSession，但为了直接覆盖好感 80 的菜单和换图，在已严格恢复的档中注入道侣状态，随后不把这份注入档当作冷读证据；冷读、跨槽及写盘回滚由不注入状态的同专项前半段提供。自然取得道侣、网页 3 槽轨迹、从死亡到第二世的实际存档旅程仍待 N7/N9 与 N11 总目标验收。N0–N11 保持 0/12。

**独立反例审查**：只读审查重跑立绘专项、转世恩赐和道侣耳语均退出 0，追查写入、重演、转世投影和玩家按钮未发现可复现 P0/P1；指出 `rebirth=true` 仅为合成死亡态的 `new_life` 投影，`ui=true` 的好感/拥有道侣来自内存注入。Godot 文件当前仍未跟踪，缺可审提交基线；按严格定义此切片只有局部运行证据，提交级与自然跨世端到端均 UNPROVEN。

**NC-PORTRAIT-02 复审**：初次只验证非空图，独审指出绯夜错用素念并判 REJECTED。改从来源 `ui.js` 派生完整 27 项 NPC 肖像映射后，精确纹理测试和导出 `--check` 均退出 0；同一独审按当前代码复审判定这一局部肖像消费者 VERIFIED。27 项映射指向的运行素材全部存在；自然拍卖获得链仍未验。

**总门禁耗时记录**：首轮全套在 `noncombat_battle_victory.gd`（16 来源分支、每分支多次严格冷读）运行 600 秒后因测试时限退出 1，尚无全套 PASS。审查发现新增肖像重演在无操作日志的旧档每步深拷贝状态；现在无待重演操作直接返回。立绘专项复跑退出 0；16 分支战斗胜利专项单独运行最终输出 `NONCOMBAT_BATTLE_VICTORY_PASS cases=16 ...`、退出 0，实测耗时略超过原 600 秒，故总门禁该项限时调至 900 秒并保留完整 16 例。总门禁需继续运行到最终结果，当前不能签收。

**来源立绘别名补齐**：网页 `CompanionSystem._resolvePortraitCompanionId` 将 `tian_ji`、`xue_sha`、`jiuwei` 归一到正式 NPC ID。Godot 原新入口只接受正式 ID；追加 `jiuwei` 的来源阶段选择/规范 ID 写盘/冷读断言先退出 1，再接同一三别名归一入口，专项输出 `alias=true`、退出 0。该操作仍不改变不可达专属道侣的来源获得结论。

**别名与快返独审**：独立只读审查对照网页三个别名，重跑立绘专项 `alias=true` 与无立绘日志的 `noncombat_legacy_focus.gd` 严格冷读，均退出 0；确认重演仍校验数组类型、行动内容并以最终全状态比较防伪，快返不变异原状态。局部 VERIFIED；未替代自然道侣长路线验收。

**专属道侣可达性反例**：只读双入口追踪确认四名耳语 NPC 当前没有 `effects.companion` 获得入口。唯一写入者是 `EffectService.js` 的 companion 效果 → `GameStateManager.addResource`；`f_karma`、`f_foxGratitude` 虽写 `whiteFox`，但 `weight=0` 且当前网页 `src/` 无生产者，实际白狐因果流转到 `k_fox_returns/k_fox_gratitude`，无同伴奖励。`whiteFox` 也不是 NPC/Profile ID，强行投影这两卡时 `CompanionSystem.register` 失败。`ds_demonic_auction` 的 `ds_demoness` ID 真实一致，其 Godot 选择结算已有局部测试，自然元婴抽取到 HUD 冷读尚缺。N11 应记录四名专属 NPC 的当前来源不可达理由；若后续新增自然获得剧情，必须先补来源可达作者分支并同时处理旧档版本，不以改名替代入口。

2026-11-01 续记：N7/N9 道侣耳语扩成剧情页常驻 HUD，按本世拥有、注册和好感选择人物，展示源阶段肖像与好感；来源 `CompanionHUD` 的问候、四人三档空闲语料和 15–35 秒循环已接，选择气泡 3500 毫秒关闭后 HUD 留在页面。切槽中止旧循环。专项验来源文本、选后显示、两个桌面分辨率横纵不裁切、肖像/好感及关闭时序；开局 UI、道侣事件回归通过。网页 HUD 点击的详情方法现行未定义，Godot 未补虚构行为；手选立绘与自然取得道侣路线仍缺，N0–N11 仍 0/12。

2026-11-01 续记：N0 逐脚本账本揭示 `CompanionWhisper.js` 无消费者；N7/N9 已由当前来源 JS 导出四人反应库并在 Godot 成功选择后显示 3500 毫秒耳语。专项验好感分层、无道侣、失败选择不出气泡、两个桌面分辨率选项可见与定时关闭。首次 1280×800 布局专项抓到气泡宽 3 像素导致选项屏外，修后通过；原开局 UI 和道侣事件回归通过。持续肖像 HUD、空闲台词和自然拥有道侣路线仍缺，N0–N11 仍 0/12。

2026-11-01 续记：N0 新增可重生的 `noncombat-coverage-ledger.json`，逐项登记当前 63 个网页加载脚本与 Godot 对应位置、230 张未入包候选图的 SHA 和用途类别。47 项非战斗脚本仍标为待完整行为审查，13 项浏览器实现标为原生替换但可见效果未验，3 项为战斗边界；候选图不计运行素材。目录重生、账本 `--check`、实际 531 图/3 动画/32 音频 SHA 覆盖通过，账本检查已接总门禁。N0 和 N0–N11 仍 0/12。

2026-11-01 续记：来源因果涟漪待选卡原漏掉统一回合被动；体修金丹构造态气血修前 `4>4`、修后 `4>5`。同一旧档启用序号保护历史重演；原涟漪冷读专项通过并登记新专项。N0–N11 仍 0/12。

2026-11-01 续记：师尊事件选择原漏掉网页版统一回合被动。来源师尊待选态投影体修金丹，专项修前气血 `4>4`、修后 `4>5`，旧档回放开关保持 `4>4`；师尊阶段、可信阶段、转世师尊回归通过并登记门禁。剩余特殊阶段和自然长路线仍待复核，N0–N11 仍 0/12。

2026-11-01 续记：体修金丹选择天机卡后漏掉网页版统一回合被动，修前构造态气血 `4>4`；Godot 天机分支现写盘前按当前决定序号结算一次，修后 `4>5`。旧 Godot 档通过 `passiveRegenExtensionIndex` 延迟启用，原历史保持严格可重演，待选天机档下一次选择后冷读通过。天机专项、功法旧档冷读、转世遗产与四修 16 份网页版开局导入通过；其他特殊阶段仍待逐入口审查，N0–N11 仍 0/12。

2026-11-01 续记：故事页气血上限现在按 `PathSkillFlow` 有效被动显示；体修金丹新档 `10/10`、技能未启用旧档 `8/8` 的界面专项退出 0，已加入总门禁。自然跨境界/跨世及完整桌面视觉验收仍缺，N0–N11 仍 0/12。

2026-11-01 续记：N8 功法消费者对照补齐丹修元婴丹药八折的旧档启用点、体修金丹回合回血的有效被动与实际生命上限，以及官坊/师门治疗上限。技能消费者、官坊高境界货单、官坊交易和师门交易专项均退出 0；官坊旧测试的玄铁甲不可购断言改为当前可购货位及非法货号拒绝。来源 `poisonResist` 目前只有被动聚合/存储、没有实际玩法读点，Godot 未赋予新效果。自然跨境界/跨世与 N8 全面签收仍缺，N0–N11 仍 0/12。

2026-11-01 续记：N10 第 12 次实测网页档抽中 `causal:hoarded_manual` 涟漪并显示 `kx_path_sword_legacy`，重演初始种子现在按当次可选因果种子与来源卡文匹配。真实导出预检、空槽导入、严格冷读及伪造种子拒绝专项输出 `decisions=4-12 ripple=true`；第 13 次后的残卷与截断历史锚点等仍缺，N0–N11 仍 0/12。

2026-11-01 续记：N10 第三份真实剑修来源档的第 11 次决定已按师门回应确认后 `ch_qi_80`、残卷失手 2 次、集市待发和涟漪时钟重演，空槽导入严格冷读通过。`noncombat_ripple_flow.gd` 的无事件种子搜索核对到来源时钟；`noncombat_browser_mid_import.gd` 输出 `decisions=4-11`。第 12 次后仍缺，N0–N11 仍 0/12。

2026-11-01 续记：N10 的来源 save10/causal18 剑修轨迹已延至第 10 次决定，包括第 9 次师门导师卡与保底残卷、第 10 次即时回应。第二次隔离抽签采得不同保底套装，两个真实变体的第 9/10 次档均能直接导入空槽并严格冷读；伪造残卷和回应被拒绝。第三份来源轨迹采到第 15 次决定前，第 11 次后续进展见上方最新记录；N10 和 N0–N11 仍 0/12。

2026-11-01 续记：N8 功法技能按来源 `config:path_skills` 的四流派 12 项定义派生，当前选择、最大气血、战斗请求、秘境、服丹突破已经接线；来源 `cultivation` 标签与冥想 ID 的倍率条件一致。地点卡道心损失及因果卡道心/灵石来源效果补入同次被动结算；地点、两条因果回归通过。四项技能专项均退出 0，包括旧档首战零决定预警后严格冷读；其余效果消费者和自然跨境界/跨世仍待逐项核对。N10 的实测 save10/causal18 剑修第 4–8 决定原始导出，领域直接导入、下一可见卡、quest3 活动/已关闭白狐任务、磁盘冷读、伪造任务结局拒绝、桌面空槽预览/点击与战斗中拒绝专项退出 0；第二份隔离本地浏览器 10 决定轨迹在第 4、5 决定保留待发因果，两变体预检通过，第 8 次的市场待发及死亡 NPC 可选字段也已核对。第 9/10 次决定的后续进展见上方最新记录。网页版章节优先时势力节拍不推进，Godot 已将收集移至高优先级之后，四修旧档与体修势力自然路线回归通过，势力卡现第 55 决定出现。战斗与跨世档仍不支持。命盘遮挡自然长局已重新通过，场景层宗门八访长局仍红；N0–N11 仍 0/12。

2026-11-01 续记：剧情页“证据星图”已从 `world:truth_atlas` 投影五线索、四假说、三结局，显示本世与旧 `hintClues`、世界脉搏及终局条件。缺已认证终局胜利或冻结快照时资格仍锁定；弹窗查看不修改领域状态。`noncombat_evidence_atlas.gd` 的桌面控件、来源文字、只读与门禁专项退出 0。真实终局玩家流程及两分辨率外观尚待验，N0–N11 仍 0/12。

2026-11-01 续记：高境界 13 张带战果联动的来源遭遇卡按胜、败、逃共 39 种结果核对了声望、同伴、因果；另有 5 次真实待战请求经 `BattleReturnFlow` 结算势力、直接/联动因果、`combatGlory` 和见闻奖励。`noncombat_higher_outcome_links.gd` 与 `noncombat_higher_link_return.gd` 均退出 0；两项均使用构造的合法来源状态及认证战果，未覆盖玩家逐战输入、35 场逐场和自然长路线。N0–N11 仍 0/12。

2026-11-01 续记：高境界定期遭遇四境界各一张样本已通过 `BattlePlanResolver`、`CombatDomain.load_persisted_request`、来源图 2D 战场实例绑定、HD2D 资产检查和认证胜利回传；`noncombat_higher_catalog.gd` 输出 `combat=4 stages=4 results=4`。35 个高境界非 Boss 战场身份现有运行场景映射。其余目录逐场与桌面玩家输入、自然路线、两项红色自然验收仍未完成。

2026-10-31 续记：金丹至渡劫定期遭遇候选/排期与来源图已接线，四境界候选、待战请求及两个来源避战效果的 `noncombat_higher_catalog.gd` 通过。旧金丹长局存档严格冷读及下一决定启用新排期后冷读通过，并自然呈现金丹配额卡。同步后运行清单 74 数据/1078 图/32 音频，`NONCOMBAT_ASSET_COVERAGE_PASS ... copied=1078`。由于真实路线卡序改变，旧 `noncombat_destiny_deferred_natural.gd` 到 200 步转世前未再出现被遮挡命盘，`noncombat_scene_layer_natural.gd` 先前宗门八访证据同样失效；两项自然验收均未恢复，不得从专项投影推断 N5/N6 或总目标签收。

N7 师徒高潮证据：来源 `StoryNetworkSystem.MentorArcEngine` 在金丹/衣钵阶段排剑劫，在大乘/薪火阶段排天命；`noncombat_mentor_flow.gd` 现在以 v4 队列投影并结算两张原卡，天命选择通过 `noncombat_world_continuity.gd` 写入白刃飞升回响。`noncombat_mentor_climax.gd` 验 v3 回放不获得未来高潮、下一决定启用 v4、金丹剑劫及大乘天命正文/效果/飞升；`noncombat_mentor_trusted.gd` 的公开集市路线验证 v4 选前/选后冷读，并用当前来源 v3 存档验证旧历史严格重放及下一真实选择升级后再冷读；`noncombat_mentor_arc.gd` 回归通过。构造高境界卡的单元证据不能替代公开长局自然触发或桌面画面；网页版 `secretReveal` 与读取 `revelation` 不一致，当前秘闻不可达，N7 和总目标均未签收。

门禁尾段复核：新增 v4 谱系冷档后，从 `noncombat_lineage_v4_cold.gd` 分段续跑至最后的 `stage_router_contract.gd`。因 `noncombat_boss_fragment_cold.gd` 超过 120 秒、`noncombat_rebirth_story_threads.gd` 超过 30 秒、`noncombat_rebirth_ghost_journey.gd` 在 900 秒达第 68/90 步、`noncombat_browser_opening_import.gd` 超过 30 秒，分别按实际长路线设置 600/300/1800/300 秒阈值后续跑；未删断言。`noncombat_rebirth_mentor.gd` 构造态死亡夹具原无当前决定的选择历史和回执，遭当前死亡边界拒绝，补上合法来源回执后该专项退出 0。最后一段 `python tools/validate_godot_runtime.py noncombat_browser_opening_import.gd` 输出 `RUNTIME_MIGRATION_TAIL_PASS data=74 art=999 audio=32 M0_steps=12 reactions=3 presentation=3 stage_routes=4`；从 v4 到尾的各项在分段中通过。未执行从头至尾单次总门禁，N0–N11 **0/12**。

N0 目录重跑：`python tools/audit_noncombat_migration.py` 输出 `artifacts/godot-migration/noncombat-content-catalog.json`，当前 59 源文档、615 节点、1257 分支、531 节点 `sceneImage`、230 张运行清单外非战斗候选图；`python tools/validate_noncombat_asset_coverage.py` 输出 `NONCOMBAT_ASSET_COVERAGE_PASS images=531 animated=3 audio=32 copied=999`。前者的硬编码 `opening_rendered=8` 仅是旧开局静态标签，不能代表现行 Godot 全部呈现范围；后者是字节覆盖而非可达或视觉证明。63 个浏览器脚本的逐消费者状态和 230 图逐张用途仍待建立，N0 未签收；N0–N11 **0/12**。

轮回树图形证据：从同一真实死亡→转世 v5 路线由 `capture_rebirth_tree_v5.gd` 打开桌面弹窗；Windows OpenGL 3.3/NVIDIA RTX 3060 Laptop 输出 `output/godot/rebirth_tree_v5/rebirth_tree_1280x800.png` 和 `rebirth_tree_1920x1080.png`。已检查两张 PNG，弹窗和滚动区域、16 节点中的可见首段、底部返回按钮都位于窗口内，无裁切。未逐屏验购买/退款后的按钮刷新与其它 N8/N9 页面；N0–N11 **0/12**。

真实第二世轮回树入口：`noncombat_lineage_rebirth_cold.gd` 从来源死亡检查点真实转世后，把同一领域状态挂到桌面剧情页并调用 `_render`，验证轮回树入口可见、弹窗恰有 16 节点，再继续购买、退款及严格冷读。修前 `REBIRTH_PENDING` 的 `path=null` 被残卷追踪候选传给 `String` 导致 UI 渲染脚本错误；`noncombat_legacy_fragment_flow.gd` 对未选流派返回空候选后，真实第二世专项与残卷追踪回归均退出 0。headless 控件证据仍不等于正常图形截图、两分辨率或人工视觉验收；N8 与 N0–N11 **0/12**。

N7 白刃师徒后两阶段：`noncombat_mentor_flow.gd` 按 `StoryNetworkSystem.MentorArcEngine` 的 60/80 点来源阈值排队 HEIR/LEGACY，消费 `data/companions/arcs.json` 的“师尊·托剑／道同”正文与效果，HEIR 左选气血受当前上限约束。状态 v3 保存 `heirActivationIndex`；v1/v2 存档在旧决定中仍按旧阶段回放，后续真实决定才写 v3。`noncombat_mentor_heir_legacy.gd` 验证两阈值、来源投影、托剑选择、旧 v2 不提前排队与新决定激活；`noncombat_mentor_trusted.gd` 增验 v1→v2→v3 实际选择后磁盘严格冷读，`noncombat_mentor_arc.gd` 四修首阶段回归通过。新版高阶段的自然长局、桌面可见、师徒秘闻/高潮和加成消费仍未验；N7 与 N0–N11 **0/12**。

N8 谱系归档补链：`LineageSystem.js` 对每笔已完成商店交易计一次购买；Godot 新转世 v5 将普通／鬼市／官坊 `marketPurchaseHistory` 与“最后一课”商店专用 `lastLessonVendorEventHistory` 购买事件合计，按 `TradeRouteSystem.getActiveRoute` 的地点筛选、开通度＋繁荣度－危险度及来源稳定顺序写入归档商路。转世 v4 明确沿用旧投影；`noncombat_lineage_tree.gd` 的金丹归档核对两笔购买与宗门青云剑路，并核对旧版一笔／空商路；`noncombat_rebirth_legacy.gd` 核对显式 v4 和默认 v5；`noncombat_lineage_rebirth_cold.gd` 完整死亡转世与树操作多次冷读均退出 0。`noncombat_lineage_v4_cold.gd` 从真实死亡检查点写入 v4 快照，再由领域磁盘冷重开严格重放一致。所有 N8 上游自然路线与全桌面逐屏验收仍缺；N0–N11 整阶段 **0/12**。

N8 轮回树桌面入口局部：剧情页通过 `rebirth_tree_view` 展示来源四分支 16 节点、悟点、效果和可买/可退状态，按钮调用既有原子树操作。`noncombat_opening_ui.gd` 用构造态来源树实际点击“淬脉”并验证领域状态，弹窗重开没有 Godot 独占窗口报错；真实死亡→第二世买/退与严格冷读沿用 `noncombat_lineage_rebirth_cold.gd` 的既有证据。第二世桌面实际布局、两种分辨率和全模块表现验收仍缺；N0–N11 整阶段 **0/12**。

N8 Boss 残卷与追踪局部：认证 `boss/realm_boss` 胜利由领域战果提交创建待领候选；桌面弹窗可稍后领取或按来源候选选一片。领奖与片数、已领 encounter ID、操作回执同一事务提交，首世和转世严格重放读取回执。“传承追踪”桌面按钮可指定/取消合法未完成套装，原子存档及重放；`noncombat_legacy_focus.gd` 验证失败写盘回滚、普通掉落实际定向和冷读，`noncombat_opening_ui.gd` 按桌面按钮实际选中目标。筑基认证关构造态专项覆盖焦点候选首位、重复拒绝和第八片绝学入组；公开炼气百点关路线覆盖待领冷读、失败写盘回滚、重试、领后冷读及下一决定冷读，均退出 0。普通残卷八片合成与轮回树节奏专项回归通过；新专项已登记总门禁，未执行全量门禁。Boss 弹窗桌面逐屏与跨世自然路线仍需证据；N0–N11 整阶段 **0/12**。

N8 轮回树拾遗节点消费局部：网页版 `LegacyFragmentSystem.getPacingContract/_dropRate/_selectBossCandidateSetIds` 来源规则对应到 `noncombat_legacy_fragment_flow.gd` 的普通卡实际掉落与 Boss 候选选择器。已有树的残响节点将保底从七次合法未掉缩为六次，寻卷丝使焦点权重 0.60→0.70，古契共鸣使炼气掉率 0.08→0.09；三项均在实际 `settle` 路径消费，空合法池和旧档无树仍沿原规则。战利天眼使纯候选选择器从三项增加到四项，其哈希排序与网页版实函数对照；当前 Godot 战果消费者尚未发出待领 Boss 残卷，故该节点仍无可达领取链。`noncombat_lineage_fragments.gd` 验证 16 节点树的四项节奏、来源 Boss 顺序、实际保底／掉率／焦点决策及坏树拒绝，退出 0；原 `noncombat_legacy_fragments.gd` 八片合成、旧档、回滚和严格重放退出 0。`validate_godot_runtime.py` 登记新专项并通过 Python 编译；全量门禁未执行。N8 与 N0–N11 整阶段仍 **0/12**。

N8 轮回树核心运行链局部：浏览器 `LineageSystem.js` 与 `data/progression/rebirth_tree.json` 的 16 节点、首次归档悟点公式、解锁/退款与 `GameStateManager.recordLegacy/getPathMastery` 的系缘/记忆效果已移入 `noncombat_lineage_flow.gd`、`noncombat_rebirth_flow.gd`。树状态和操作历史随转世 v4 存档；领域操作按决定序号、阶段、卡 ID 原子写盘并在严格冷恢复时按顺序重算。`noncombat_lineage_tree.gd` 核对节点数量、金丹示例悟点 9、重复归档不二次领奖、前置、成本、退款、开局加成、异途记忆换算；`noncombat_rebirth_legacy.gd` 核对四级系缘 70% 好感及道痕额外记忆；从真实死亡存档出发的 `noncombat_lineage_rebirth_cold.gd` 依次购买、严格冷读、赐福、退款、严格冷读、继续选择和再次冷读，全部退出 0。`noncombat_rebirth_story_threads.gd`、赐福、任务与 v0–v3 继承专项回归退出 0；总门禁登记 JS SHA 和两个专项，未执行 260 余项全门禁。谱系当前从 Godot 战果、秘境回执、商路历史和集市购买记录归档；非集市购买、源事件完整统计、桌面轮回树界面及旧网页跨世档尚缺；拾遗节点后续状态见上。N8 与 N0–N11 整阶段仍 **0/12**。

N8 跨世好感／境界加成局部：网页版 `GameStateManager.recordLegacy` 将 `npcSystem.affections` 乘轮回树修正后的保留率并保留历世峰值；`NpcSystem.resetForNewLife` 对正遗产取整，否则用 NPC 初值；`CompanionSystem.loadData` 在无恢复值时先抬高道侣 NPC 初值。Godot `noncombat_rebirth_flow.gd` 转世 v3 生成 `legacyNpcAffections` 与 15 位 `npcAffection`，该批使用无轮回树时的 0.5 来源基础率；白刃真人旧排期零值且无互动时用网页版道侣初值 10，实际结算成零时不抬高。`noncombat_npc_encounter_flow.gd` 的新世排期读取继承好感。v3 同时补来源 `_reincarnate` 按旧境界及新世次数增加修为、寿元；v0–v2 的严格投影保留原形。`noncombat_rebirth_legacy.gd` 核对 15 人、峰值、小数取整、负值、旧 v2、新世排期、五种境界与第三世，退出 0；`noncombat_rebirth_boon.gd`、`noncombat_rebirth_body_karma.gd`、`noncombat_rebirth_quest.gd`、`noncombat_npc_first_legacy.gd` 与 `noncombat_death_rebirth_journey.gd` 真实死亡→第二世多次冷读均退出 0。该长路线不含自然好感跨世选择；轮回树 v4 的后续进展见上。N8 与 N0–N11 整阶段仍 **0/12**。

N7 五人道侣弧线运行链局部：`tools/export_companion_arc_cards.js` 调用网页版 `StoryNetworkSystem` 的真实构造函数，从 `data/companions/arcs.json` 导出白落霜、剑灵儿、九尾素月、慕清岚、殷雪各五阶段及秘密／情劫／天命，共 40 张卡。网页版个性化数据中另外四人的秘密与情劫各有一个右选项缺文案和效果；导出时只对这八处缺字段使用同一网页版构造器的通用对应选项，并在 `fallbacks` 逐条记录，原 JSON 未改，个性化关系数值保留。`noncombat_companion_arc_flow.gd` 已接本世阶段账本、人物实体门槛、P53/P51 待发队列、已解决语义去重、作者卡投影、数值／悟性／好感／羁绊／信任／因果种子结算、即时回应和来源指纹；领域含激活、存档、选择与重放入口。`noncombat_companion_arc_flow.gd` 专项验证五人各五阶段及三转折排队、同人阶段先于转折、白落霜初识语义去重、缺席人物拦截、悟性、通用备选右选结算、负生命不额外扣寿元及领域选后新阶段，退出 0；道侣事件、里程碑、语义准入、盟友自然路线和存档会话回归退出 0。定版目录下的第二世迷雾谷→鬼市誓约／债务长测 `NONCOMBAT_REBIRTH_GHOST_JOURNEY_PASS`，其中两次线程卡冷读、付款／拒付、回滚与恢复均通过；该路线没有五人弧线选择。五人没有由现行普通卡直接获得对应资源 ID 的自然轨迹，尚无公开新档弧线自然出卡、选后磁盘严格冷读或全员效果验收；N7 与 N0–N11 整阶段仍 **0/12**。

N7 人物实体准入局部：网页版 `WorldContinuityStore.canPhysicallyAppear` 只认可当前世登记的 ACTIVE/PHYSICAL NPC。Godot 原 `noncombat_companion_events.gd`、`noncombat_normal_choice_policy.gd`、`noncombat_normal_draw_policy.gd` 在世界登记存在却缺当前人物时仍可发事件、给同伴回血或出现实体对话；现三条生产消费者按登记版本、世代、人物 ID、生命周期和显现形态准入，无世界登记的早期旧档保留旧兼容行为。`noncombat_companion_events.gd` 专项增加本世有效/缺失/旧世事件及回血反例并退出 0，`noncombat_story_semantic_admission.gd` 增白狐首见的相同反例并退出 0；道侣里程碑、剑灵儿旧主入口、普通抽卡和自然叙事专项均退出 0。网页版动态道侣危机目前发出无 `choices` 的事件，`CompanionSystem._fmtChoices` 会枚举该缺失字段；此链与五人弧线仍未迁完，N7 与 N0–N11 整阶段仍 **0/12**。

N6 转世线程局部：网页 `StoryThreadEngine` 的线程快照绑定当前世；Godot 原 `noncombat_story_threads_v2_flow.gd` 在第二世直接跳过 `tick/resume`，导致线程卡全部不可达。现新世重置启用序号、首个有效决定生成 `lifeCount=1` 的 12 条线程账本，严格读取只接受同世账本，旧首世无 `lifeCount` 存档仍按首世解释。`noncombat_rebirth_story_threads.gd` 以来源死亡检查点完成真实转世后首决定磁盘写入和严格冷读，并在第二世模拟来源 `q_spiritStone.right` 验证灵矿触发、原卡、选择和跨世隔离。`noncombat_rebirth_ghost_journey.gd` 从真实第二世长链自然发出迷雾谷第 1/2 节点，两次逐节点冷读保持卡与状态一致，选完继续到鬼市及旧档分支，退出 0；旧 v1→v2 线程升级、迷雾谷旧档延迟激活专项退出 0。此证据证明 Godot 第二世生产链与严格冷档，不证明网页和 Godot 第二世完整随机序列逐值相同；N6 与 N0–N11 整阶段仍 **0/12**。

N10 旧网页存档入口局部：`noncombat_browser_save_inspector.gd` 只读接受原始 localStorage JSON、Playwright storageState 和单槽 schema10 对象，逐槽验证 causal18/quest3、槽身份、决定时钟、选择序号、法宝所有权及战斗 owner；三槽来源样本与坏时钟/伪造战斗 owner 负例专项退出 0。`noncombat_browser_save_staging.gd` 将通过预检的原始导出独立暂存，替换前备份原文字节；提升失败和无效导出保持前版，原 Godot 槽不变。网页本地 Playwright 新采集剑、法、体、丹教程／序章各第 0–3 次决定的实际 save10 存档；`noncombat_browser_opening_import.gd` 在空目标槽中按来源选择史重演，匹配基础数值、牌组、决定时钟、下一张卡、势力/同伴/世界/商路、集市与天机及因果涟漪排期、残卷与遗产后，原子提交 Godot v2。来源仅存排期、未存随机种子；导入器选取能再现现有排期、涟漪和残卷态的 Godot 种子，后续随机抽样不是网页原随机流。专项 `noncombat_browser_opening_import.gd` 的四修共 16 个检查点、四修第 2 次决定导入态续至来源战斗邀约/属性/牌组/时钟、错误数值/战中档/占用槽和伪造涟漪效果拒绝、剑修第 2 次决定档实际写盘与两次冷读，以及第 3 次决定待战档的磁盘导入、冷读邀约/涟漪、进入预警与再次冷读均退出 0。桌面 `noncombat_browser_import_ui.gd` 验证文件选择后的逐槽预览、可转换槽导入及战中槽禁用，退出 0。中途任务、战斗待结、跨世、完整旧数据映射、三槽整体提交和战斗 authoritySeal 尚缺，N10 与 N0–N11 整阶段仍 **0/12**。

Windows 包已包含本批旧浏览器教程／序章导入入口并重导出。发现 285 个零字节 `.import` 引发 Godot 打包元数据错误；确认对应源图/模型存在后清除空元数据，编辑器重导后空文件数 0、导入日志 0 条 `ERROR:`。Godot 4.7.2 Windows Desktop release 最终导出日志 0 条 `ERROR:`，从独立工作目录和独立 `APPDATA`/`LOCALAPPDATA` 启动 `.exe --headless --quit-after 60` 退出 0，`.pck` 2,568,224,666 字节。此为启动烟测，N11 的可见交互、包体优化与全路线门禁仍待完成。

法宝背包操作与交易摘要：网页版 `ui.js` 可以在背包中随时装备已拥有的法宝，Godot 此前只有购买后的待装配按钮。桌面剧情现对普通/线程待选卡显示“法宝装备”，点击可装备或卸下；领域把操作和当前决定、阶段、卡 ID 一起原子保存，严格恢复在原位置重放。`noncombat_nascent_revive_acquisition.gd` 经实际桌面按钮装配“涅槃羽”后触发道心归零复活，退出 0。`noncombat_treasure_equipment_cold.gd` 从公开法修新档自然购买“剑心佩”，收入背包，关店后经历集市与战斗，在来源线程卡上装备、卸下，两次冷重放与失败写盘回滚均退出 0。同期修复官坊购买法宝后仍更新旧会话引用导致摘要 0 笔、后续流动集市拒绝关店；`noncombat_regulated_goods.gd` 与 `noncombat_regulated_replay.gd` 通过。其它待选阶段的背包装备、自然取得复活秘宝至致死的完整冷档仍待验，N8/N9 与 N0–N11 整阶段仍 **0/12**。

元婴复活秘宝来源链：`n_trade_city.left` 按来源效果扣 30 灵石并取得“涅槃羽”实例与交易回执；专项 `noncombat_nascent_revive_acquisition.gd` 在构造元婴状态下经桌面背包按钮将该实例装入秘宝槽，再选择来源 `n_awakening.right` 使道心归零，涅槃羽一次性消耗并回复至气血上限，退出 0。尚无自然元婴长局/复活冷档证据；N8 与 N0–N11 整阶段仍 **0/12**。

官坊法宝装配自然链路：`noncombat_regulated_equipment_natural.gd` 从公开法修新档走到筑基第 128 回合普通官坊，购买来源货单的“剑心佩”，在同一会话选择装备并关店，随后从磁盘严格重放，验证实例所有权、装备槽与派生库存一致，退出 0。修复普通法宝装配按钮误写“易手残剑”的文案，`noncombat_regulated_goods.gd` 现核对按钮显示所购法宝名并退出 0。此货单给的是武器，不是复活秘宝，故自然购买→装备→致死→复活冷档链仍缺；N8 与 N0–N11 整阶段仍 **0/12**。

战果来源致死：教学战低上限战败和寿元 1 撤离此前被战果消费者提前拒绝，现来源战果记录与决定回执先落入候选，致死时转为 `death_blood_loss` 或 `death_lifespan`；可复活秘宝在死亡卡前消耗。`noncombat_battle_revive.gd` 构造三分支（替身符战败生还、无秘宝战败、寿尽撤离）均退出 0；四修 8 例原战果严格重放及同门比试胜/败/逃自然回归退出 0。来源任务/线程等其余战斗致死仍需独立自然证据，N8 未签收，N0–N11 仍 **0/12**。

教学战战败致命伤此前在战果消费者中拒绝装备复活秘宝。现先结算来源负伤与燃血，再尝试秘宝复活；`noncombat_battle_revive.gd` 以公开剑修教学待战合同构造低上限替身符分支，验证战败结果卡、战斗回执、1 点气血及秘宝消耗，退出 0。原四修战败/撤离 8 例的来源对照、写盘回滚、严格冷读与桌面战果卡回归再次通过。其它战斗来源的致死/复活分支尚未全部接通，N8 未签收，N0–N11 仍 **0/12**。

秘境致死秘宝拦截：六处已接来源秘境/洞窟失败路径在生成死亡卡前，现共用秘宝复活候选结算；复活仍保留本次秘境失败回执与一次性法宝消耗。`noncombat_cave_failure.gd` 在来源抽到 `q_cave` 后构造低血替身符入口，修复前拒绝，修复后存活并留下失败回执；原无秘宝入口和野兽两支死亡亦通过。其它秘境复活自然长局与冷档仍待补，N8 未签收，N0–N11 仍 **0/12**。

章节卡致死边界：体修来源 `ch_qi_20.right` 在气血 1、双上限 1 时扣 1 气血，旧 `MilestoneFlow` 拒绝结算。现保留来源效果、寿元、被动、章节事实/因果、决定回执后由领域投影 `death_blood_loss`；有效复活秘宝也可先拦截。`noncombat_milestone_fatal.gd` 采用公开体修教程后自然出现的章节卡与构造低血量，修复前失败、修复后退出 0；四修章节连锁、第三章分支及首世死亡卡回归退出 0。构造低血量分支尚需自然致死冷档，N8 未签收，N0–N11 仍 **0/12**。

普通卡致死时，领域层现在按网页版 `GameStateManager.checkDeath` 先尝试当前秘宝槽的复活效果。`TreasureAcquisition.revive_equipped` 从原法宝目录投影 `substitute`、`nirvana`、`samsara`、`chaos` 四种代价，消耗装备实例并更新派生库存；`noncombat_artifact_revive.gd` 从真实第二世 `q_spellTome` 检查点构造已装备替身符分支，验证左选不进入死亡卡，四种来源公式逐一通过。首世与第二世无秘宝死亡冷恢复回归再次退出 0。构造秘宝分支尚无自然购买→装备→致死→冷恢复整档证据，N8 未签收，N0–N11 仍 **0/12**。

Windows 导出预备检查：从 Godot 官方 4.7.2 stable 下载标准模板包，SHA-256 `f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011` 与官方发布资产摘要一致，安装 x86_64 Windows release/debug 模板。现有 `Windows Desktop` 预设导出 `godot/dist/windows/YiNianXianTu.exe`（109,127,680 字节）与 `.pck`（2,565,926,178 字节）退出 0；从独立工作目录和全新 `APPDATA` 启动 `.exe --headless --quit-after 60` 退出 0。仅证明可导出并启动，尚未覆盖可见交互、包体优化、导入旧档和所有非战斗生产路线，N11 未签收，N0–N11 仍 **0/12**。

第二世鬼市自然长链在新增盟友/回响/天机事件后，测试旧的固定到期编号不再对应实际来源决定。现在沿当前节拍寻找可入市鬼市，并以债务条目 `dueDecisionIndex` 对照到期卡。`noncombat_rebirth_ghost_journey.gd` 通过：鬼市入市、誓约剑、到期支付/拒付、旧天机/旧商路、失败写入回滚与严格冷恢复；从 `noncombat_identity.gd` 开始的后段总门禁亦通过。N0–N11 整阶段保持 **0/12**。

普通作者卡 `q_spellTome.left` 在第二世道心 1 时会按网页版结算到道心 0，并应在同次决定进入 `death_dao_collapse`。原 Godot 普通卡策略把这类选择直接拒绝；现由领域层在效果、寿元、被动、决定回执后投影来源死亡叙事卡，第二世恢复器也接受 `DEATH_PENDING`。`noncombat_generic_normal_death.gd` 采用真实第二世第 62 决策检查点，先证明旧行为失败，再验证原子写盘失败回滚、死亡来源与第 63 决策、严格冷恢复，退出 0；普通抽卡策略与首世致死专项也退出 0。装备复活秘宝仍需来源消费者，N8 未签收；N0–N11 整阶段保持 **0/12**。

`jle_8_sword_tomb_old_master` 曾因 Godot 同伴筛选器拒绝一切带 `encounterId` 的作者事件，金丹剑灵儿的并肩战不可达。现仅为该来源事件开放目录遭遇投影，并把左选接入预警、待战、战斗计划、来源图/敌人帧、专属 2D 战场及三种战果回接。来源 `outcomeLinks` 分别在胜/败/逃调整好感与信任，胜利发 `sword_insight+2`；右选保留 −3 好感、−2 信任和 +1 道心。`noncombat_companion_old_master_entry.gd` 从构造金丹剑修状态验证同伴抽取池确能发卡、双选、来源待战请求、计划图装载、桌面战场启动与撤离回执、三战果数值与结果卡，退出 0；测试已纳入运行门禁。自然长局、完整磁盘冷恢复、逐牌胜败及其它同伴事件仍未据此签收，N0–N11 整阶段保持 **0/12**。

普通官坊货架此前显示来源法宝、本脉功法牌、宝匣/古玩却拒绝购买。现复用来源法宝取得回执、牌组取得与鉴宝公式，接入普通官坊购买、穿戴/暂存和事件排序；`TreasureAcquisition` 对 `shop_encounter`、`q_market`、`loc_market_first` 的实源官坊会话核验来源报价、法宝实例和交易号。`noncombat_regulated_goods.gd` 筑基构造货单退出 0；`noncombat_regulated_ordinary_natural.gd` 从公开法修开局经认证首战/阶段关口与来源普通抽签，在第 128 回合官坊买入法宝、功法牌、神秘古玩，闭店后暂存法宝，严格冷档与下一决定均退出 0。自然路线胜战由认证终局夹具提交，真实桌面逐牌胜败及 N8 全部经济/成长尚未签收；N0–N11 整阶段仍 **0/12**。

总门禁在 `noncombat_last_lesson_direct_route.gd` 发现【冰心共鸣】助战牌作者图片虽在源目录，却是 JPEG 字节的 `.png`，Godot PNG 导入记录为 `valid=false`，导致来源场景资产校验失败。`sync_runtime_content.py` 现从最后一课节点的 `combatPresentation.storyAssist.cardId` 追到原战斗牌 `cardArt.image`，在来源清单登记已有的同字节 `.jpg` 运行别名；同步后七节点直达、战斗与来信专项退出 0。门禁继续从下一项交易专项执行。N0–N11 整阶段仍 **0/12**。

`noncombat_foundation_mission_upgraded_natural.gd` 在 2026-10-30 当时的来源种子 2 公开法修新档中连续推进到筑基第 161 回合：同门比试提供灵石，营地升级 `spell_spark+` 后自然再次抽到 `f_mission`。该旧轨迹已被本文件开头 2026-11-02 当前规则的种子 764850、第 66 回合证据取代。首战及阶段关口仍由认证终局夹具完成，不能据此声称逐牌打赢整条自然路线。N0–N11 整阶段仍 **0/12**。

## 2026-10-30：势力暗流写盘与筑基官坊自然路线续跑（N7/N8 局部）

续跑总门禁的下一项 `noncombat_foundation_dungeon_entry.gd` 暴露筑基秘境首领预警已生成当前牌组合同，但 `BattleGateway.build_request` 的完整牌组来源名单漏了 `realm_guardian`，把合同错按教学战简版比较，拒绝进入待战。名单补齐后专项入口、分叉、备战、首领三阶段战斗及放弃结算退出 0；从下一项筑基秘境自然路线继续门禁。此为 N6/N8 相邻战斗交接局部，不代表整阶段验收。

`noncombat_foundation_dungeon_natural.gd` 读档后长老卡左选在新自然前缀下修为与道心双双封顶，来源网页和 Godot 均禁用该无效正收益选项；旧测试硬选左支而失败。现按当局可用方向继续，低属性左支仍由入口专项覆盖。自然路线重跑后，入口、分叉、首领战、胜利两种奖励、败退、撤离、桌面战场、写盘回滚与严格冷恢复全部退出 0；从下一项筑基目录继续门禁。N0–N11 整阶段仍 **0/12**。

总门禁在法修筑基自然路线的 `faction_spell_0` 左选发现，声望与暗流同时变化时，势力事件只把声望登记给商路账本；商路因暗流未登记而拒绝整个存盘事务。现在同一候选快照补记来源 `faction:undercurrentChanged` 对应事件，商路依次处理声望、暗流。自然路线回归在该选择后检查天枢声望 +5、禁书暗流 +1、星墟商路危险 +2/开放度先 +2 再 −1/繁荣 +1；`noncombat_faction_events.gd` 专项退出 0。临时失败档探针已删除。

该路线随后在第 64 回合暴露普通官坊抽货只接受炼气，而网页版筑基仍会按 8 回合、10% 规则触发。普通官坊卡、预抽货与进店抽货现接项目已有的高境界货单；对照 `ShopSystem.getAvailableItems` 补上筑基/金丹/元婴固定突破丹，官坊购买器接来源丹药和礼物/材料效果。`noncombat_regulated_goods.gd` 先因缺结金丹失败，修后从筑基优先级抽卡、开门、买结金丹、闭店通过；炼气礼物/回购原路径仍通过。`noncombat_last_lesson_vendor_transactions.gd` 高境界交易回归退出 0。法修筑基野兽任务 `noncombat_foundation_mission_natural.gd` 在新档自然前缀下胜、败、逃三结果的合同、存盘回滚、严格重开和续卡全部退出 0；`noncombat_faction_natural.gd` 武盟完整自然撤离路线也退出 0。总门禁从下一项筑基秘境入口续跑。普通官坊法宝、本脉功法和鉴宝购买尚未接入该购买器，N8 不签收。N0–N11 整阶段仍 **0/12**。

## 2026-10-29：势力事件来源卡与武盟请关战斗（N7 局部）

新增 `noncombat_faction_events.gd`，从 `world:factions` 读取 17 个作者事件，保存与网页版 `FactionSystem.js` 对齐的 15 次仲裁节拍、境界/路线/声望/旗标/地点/暗流门槛、加权抽取及持久待发卡。宗门物理邀请使用来源 `NarrativeLedger` 的宗门地标兼容范围。普通选择在一个候选快照内结算属性、丹药/本脉牌、声望与商路事件、暗流及爆发因果；来源卡、来源 SHA 和规则 SHA 在冷读与选择时校验。武盟请关左选经现有预警与战斗网关，确认后把地点改为武盟雷峰；战斗计划、规则域和 `main.tscn` 已接来源 2D 战场，补入原仓库中缺包的 12 张敌人动作帧。胜败逃分别按作者遭遇的 `outcomeLinks` 结算 +6/−2/−4 声望，结果卡退回剧情后清掉邀请。右选走普通势力结算。旧 Godot 档读取原字节不写入，新标记在下一有效决定启用；故障写盘保持原字节。`noncombat_faction_events.gd`、`noncombat_faction_combat.gd` 专项退出 0；后者用构造筑基状态启动真实桌面战场并点击撤离，胜败是认证终局夹具。转世旧结构专项曾因新标记误改变 v0 投影失败，修正后通过。

`noncombat_faction_natural.gd` 从公开体修新档自然推进至第 37 次决定出现武盟请关，右选结算、左选预警、待战、真实桌面撤离、−4 声望结果与回剧情均逐检查点严格磁盘冷恢复。发现重放器漏唤醒 `FACTION_PENDING` 与 `faction_` 历史，现已修复。地图地点详情也读取来源势力、子派系声望和等级、暗流阶段文案，桌面地图专项通过。白狐旧来源夹具预期节拍 0 与新运行节拍 2 冲突，已保留实况节拍、继续核对其他来源字段，白狐专项 8/8 通过。武盟战果专项再次通过三结果及桌面撤离；12 张原敌人动作帧已由同步脚本登记到来源清单，内容同步输出 `data=74 art=980 audio=32`，Godot 编辑器导入退出 0。总门禁从白狐续跑时在筑基剑道选择测试的 300 秒时限退出；单跑约三分钟后发现旧断言仍要求已接通的试炼战斗按钮禁用，已改成核对左右战斗与拒绝三方向可用，并单独提高该长局门禁时限。修正后门禁从此项续跑，已通过它，后续仍在运行；尚无单次完整总门禁通过标记。

**验收边界**：地点邀请优先级的全部语义情况、真实逐牌武盟胜败、跨世势力完整冷档及完整总门禁仍缺；N7 与 N0–N11 共 12 阶段仍 **0/12**。

**2026-10-30 旧筑基档回放补证**：续跑门禁发现 `foundation_sword_q3_heart_v2.json` 的炼气破境胜利来自旧规则，事实 `qi_main_trial` 与 `qi_sword_master_stance` 仍活动；当前来源规则会在该胜利回执中消费两事实并创建 `qi_main_outcome`，导致旧档严格重放仅在事实账本上失败。恢复器现在只在旧档保存了炼气破境胜利回执、两事实仍活动且没有新结算记录时，让该次历史战果使用旧语义；新档仍走当前结算。`noncombat_foundation_sword_trial_contract.gd` 从该旧夹具严格读回，左右两个试炼方向和预警再冷读均退出 0。门禁从此项继续，整项目尚无完整通过标记。

同一旧夹具的 `noncombat_foundation_sword_trial_outcomes.gd` 六组合在战果后先遇到来源定期遭遇、筑基里程碑与命盘，旧测试直接要求下一卡为任务终章而失败。专项现沿真实可见卡按确定方向继续，左/右试炼 × 胜/败/逃的任务状态、种子、写盘失败回滚、战果和续卡严格冷恢复均退出 0。该修正保留调度优先级，未把任务终章强行提前。剩余总门禁从下一专项继续。

`noncombat_foundation_sword_trial_low_resource.gd` 的旧三败夹具也因同一筑基 20 层里程碑增加 1 道心而不再抵达原设定边界；现在沿可见插入卡完成四次战败，真实到达气血 1、道心 1 后复核燃血胜利、致死战败、法宝防死与寿元死亡，严格冷恢复通过。专项退出 0；总门禁从桌面试炼继续。

桌面试炼在真实启动时发现 `main.gd` 把合法任务战的空 `encounterId` 送入 `String(null)`，Godot 4.7 报错并中断战场挂载。现在仅当目录遭遇 ID 确实为字符串时才拼接目录卡 ID；`noncombat_foundation_sword_trial_live_battle.gd` 左右两方向均从旧档经桌面战场撤离、返程和严格冷读通过，战场资产就绪。剩余门禁从剑道任务终章继续。

## 2026-10-29：世界脉动持久规则与地图消费（N7 局部）

新增 `noncombat_world_pulse.gd`，逐项承接来源 `WorldPulseSystem.js` 的不安定、匮乏、希望和真相指标、优先级氛围及八种播报。来源选项、线索新增、势力暗流阶段与胜败回执由 `Domain._persist_snapshot` 在候选状态结算，随后与其他系统一次提交；跨世新生命按继承线索重置。地图从已提交状态投影播报，缺旧 marker 的 Godot 档保持原字节冷读，并在下一有效决定启用。`noncombat_world_pulse.gd` 核对来源事件组合、地点氛围、真实开局选择、地图投影、磁盘冷恢复、旧档启用与写盘失败回滚，退出 0；`noncombat_run_session.gd`、`noncombat_rebirth_legacy.gd` 和地图专项回归退出 0。`noncombat_battle_return.gd` 对四修首战败/逃 8 条真实回传补脉动断言，写盘失败回滚与严格重开仍通过。来源 JS SHA 已钉入总门禁。世界互动长局、可达各氛围和 N7 整体验收仍缺，N0–N11 共 12 阶段仍 **0/12**。

## 2026-10-29：山河命卷地图运行消费者（N7 局部）

新增 `noncombat_world_map.gd` 从封包来源 `world:world_map`、`world:trade_routes`、`world:factions` 和 `npcs:core` 只读投影 13 个地点、12 条路线、11 条纪事；当前位置和已访地域取现有快照，任务/线程状态、商路风险与繁荣、势力暗流阶段和当世实体 NPC 也从各自现有状态读取。核心 NPC 的六时辰排期按来源回合映射只读计算，不写第二份地点状态；已知人物在地图显示来源头像与姓名提示。桌面剧情页现有「山河命卷」按钮及 M 键入口，地图点选和定位只改变显示，不改存档或直接传送。`noncombat_world_map.gd` 专项核对炼气迷雾、金丹地点别名、活动任务/线程、商路风险、白刃子时/辰时地点、真实 `noncombat_opening.tscn` 按钮、白刃头像和只读行为，退出 0；1280×800 与 1920×1080 正常图形截图已检查，地点和路线可辨，页内可返回剧情。来源目录缺失时入口显示错误，不展示伪地图。

**验收边界**：这只补地图的状态投影与桌面观察入口。`data/npcs/realm_growth.json` 是当前网页版已打包但未由 `index.html` 调用 `npcSystem.loadGrowthData` 的作者候选，故没有把成长排期强行接进本次地图；其余人物头像的可达展示、世界脉动的完整自然长局、势力暗流详情、各来源地图绑定的长期自然路线和键鼠完整焦点巡检尚待 N7/N9 继续；N0–N11 整阶段仍 **0/12**。

## 2026-10-29：最后一课 N3 剧情战左选（N6 局部）

N3 左选现由 `Domain.choose` 进入预警、确认后持久保存待战请求；四种 N2 交易结局分别冻结来源敌人变体。Godot 战斗计划从 `threads:last_lesson_threads` 及迁移展示资源读取三意计划图，临时战场场景可装载；来源【冰心共鸣】卡图实际为 JPEG 字节但扩展名为 PNG，按项目已有 `runtimeAliases` 保留原始字节并用 `.jpg` 运行时副本导入。首轮保证该牌在五张手牌中，实际出牌获得护盾与剑意并发出剑灵儿援护提示。`main.gd` 现分派 N3 到来源战场；`noncombat_last_lesson_direct_route.gd` 在构造化神借剑状态走过左选→预警→真实桌面 `main.tscn` 装载→桌面撤离按钮与终局结果，并另在战斗域实际打出助战牌→撤离→战果落盘→N4/N5 `right_flee`。专项再次退出 0，输出 `MIGRATED_RUNTIME_READY encounter=<null> cards=5 stage=source_2d assets_ready=true`；胜败采用认证终局夹具，验证 N3 伤势/知识/位置与 N5 `right_victory/right_defeat`。撤离写盘故障时状态及原字节不变，成功后磁盘读取一致，重复战果被拒。原七节点交涉路线与 N2 四结局专项仍通过；浏览器来源 `test_gdd_b11_last_lesson_vertical_slice.js` 6/6 通过。相邻荒村、剑冢真实桌面战斗与战场目录专项通过。

**验收边界**：上述 N3 是构造化神状态，胜败为认证终局夹具；尚无公开新档自然晋化神、逐牌胜败、完整领域冷恢复、第二世最后一课、八种 N5 复合回响的自然冷档及最终美术验收。临时战场沿用来源迁移展示的旧剑演员帧，未批准为最终美术。N0–N11 仍 **0/12**，N6 未签收。下方早期“战斗左选仍缺”的描述保留其当时进度，不代表当前状态。

**N5 八种回响补证与修复**：`noncombat_last_lesson_variants.gd` 从构造的合法化神状态逐条推进 N0–N4，再对接课左/右 × N3 胜/败/逃/交涉共 8 种组合投影真实 N5 卡并提交左右共 16 个选项，输出 `projected=8 choices=16`。初跑发现两条胜利回响的来源 `sword_insight` 未被故事线程效果处理器消费，导致 N5 选择无法提交；已按现有剑道知识账本补处理，并核对左胜 +2、右胜 +1，修后专项退出 0。这仍是构造态投影与结算，缺自然高境界路线和严格磁盘冷恢复，不签收整链。

## 2026-10-29：最后一课坊市交易接线与独审反证（N6 实施中）

**追加验证**：`noncombat_last_lesson_vendor_transactions.gd` 已在构造化神状态接真实 `RunSession`，对普通法宝、功法、宝匣购买、官坊回购和流转号订货分别注入一次写盘失败，确认状态及原存档字节均不变，随后成功交易；混合交易末态及订货后的线索消耗、扣款与订单均由磁盘读取器按 JSON 语义读回一致，专项退出 0。该证据仍未覆盖从公开新档逐决策重建的冷恢复。

N2 左选现经 `Domain.choose` 进入独立三鸣旧剑交易会话；旧剑购买、剑穗交换、灵石不足借剑、空手离开分别在离店时写剧情 `vendorSummary`，由 N3 来源变体消费。Godot 桌面入口可显示交易按钮，官坊背景来自 `markets:vendor_profiles`，结果卡使用同一背景。`noncombat_last_lesson_vendor_transactions.gd` 在手工构造的化神状态下覆盖四结局、领域入口、交易事件顺序重放及购买写盘失败后原状态/原字节重试，退出 0；已加入总门禁清单。`noncombat_last_lesson_direct_route.gd` 改为检查 N2 左选开放、N3 战斗左选仍封锁，退出 0。

这条分支仍 **REJECTED，尚未达到整链来源等价与验收**：网页 `ShopSystem.getAvailableItems` 与作者旧剑一起冻结当前境界普通货单，允许先买丹药、法宝、功法、礼物等商品，并保留官坊回购和因果服务。Godot 现已把高境界普通货单接进 N2 入坊，支持丹药、礼物、普通法宝、本脉功法、天机宝匣和神秘古玩购买，并在旧剑混合回执中累计交易。普通法宝通过实例账本取得，生成来源回执及穿戴/纳戒决定；功法经 `shop_path_slot` 进入牌组与取得账本。宝匣/古玩按来源的气运与道心阈值运行 8 类结果，宝匣反震可给本脉功法，普通鉴宝可给法宝或回收 2 灵石，抽签数和来源回执进入有序重放。暂缓装配后可买非宝物商品、订货和离店，闭店后 `FLOW_PENDING` 仍可处理装配。官坊回购和流转号因果订货已复用合规服务规则，先回购或订货再剑穗换剑的交换记录会累加，旧会话无服务标记时按旧规则重演。N3 战斗左选仍缺。新增货品与服务专项仍是构造态及内存重放，尚无自然晋化神、完整磁盘冷启动及新货品/服务写盘失败回滚证据。完整 12 阶段仍为 **0/12**；本批未完成总门禁。

为修这项反证，`noncombat_regulated_shop_catalog.gd` 新增从来源商品、法宝和牌组目录生成化神/渡劫等高境界普通货单的纯生成函数，沿用来源稀有度权重、礼物与古玩抽签次序，并按 `path+realm` 对已解锁的丹修造化丹鼎应用丹药八折；`noncombat_last_lesson_ambient_catalog.gd` 以固定六次抽签验证化神货单的槽位、顺序及丹修折价，退出 0，已加入总门禁清单。入坊现在把旧剑和该货单一起冻结，并按 `normalFlow.shopEntries` 记录抽签与报价供重放；四结局专项覆盖先买礼物再买剑、买丹不买剑、事件重放与旧剑写盘失败回滚，退出 0。法宝与功法专项先因不可购买退出 1，接消费者后退出 0；审查发现暂缓装配被错误拦截后，新路线先退出 1，接通后退出 0。相邻 `noncombat_battle_deck_rewards.gd` 与 `noncombat_regulated_vendor.gd` 退出 0。第二次独审指出回血实际上限必须包含体修被动与传承，现以来源 `body_hp` 和传承上限计算；构造体修回春丹专项通过。第二世线程/开店冷恢复分支已接入对应回放路径，既有真实转世长局 `NONCOMBAT_DEATH_REBIRTH_JOURNEY_PASS` 退出 0；**第二世最后一课自然冷档仍未验证**。不能以货单生成和局部交易专项替代完整来源路线、冷档与故障回滚验收。

`noncombat_last_lesson_identify.gd` 在构造化神 N2 会话以固定鉴宝抽签覆盖宝匣四分支与古玩四分支，核对反震卡的 `treasure_box_backlash_reward` 来源、废铁回收、实例账本和 `shop_identify` 来源，退出 0；已列入总门禁。`noncombat_last_lesson_vendor_transactions.gd` 又从领域入口购买宝匣，检查抽签数随交易事件重放，退出 0。鉴宝规则钉住网页版 `EffectService.js` SHA `7552c41cbb707c642c1b66d434c084c33241227ada146ff9322ba707a53a72dc`；只读独审对照 8 个分支和网页版同一法宝目录的两次遍历，独立复跑两项专项，未发现本批确定 P1/P2。测试未覆盖真实磁盘冷档和故障写盘，不能宣称整个坊市会话验收。

最后一课会话现冻结 `markets:vendor_profiles` 回购服务并沿用官坊来源因果订货规则；回购、订货、剑穗换剑共用交换摘要和顺序事件。`noncombat_last_lesson_vendor_transactions.gd` 覆盖“买礼物→回购→买剑”、“买礼物→回购→换剑”，以及合成活跃流转号下“买普通法宝待装配→订货→换剑”的摘要与订单，退出 0；相邻 `noncombat_causal_services.gd` 验官方订货价格、过期、原子回滚，退出 0。服务独审曾发现换剑覆盖前置交换记录、待装配时错误禁用订货，两项已修并复审无新确定 P1/P2。新会话写 `lastLessonServiceVersion=1`，旧 Godot 末课会话无此标记时回放旧服务边界；这一兼容分支尚缺真实磁盘旧档专项。合成流转号测试未证明末课订货在 Domain 完整存档恢复，也不能替代自然可达链。

## 2026-10-29：最后一课借剑与交涉路线（N6 局部）

`bairen_last_lesson` 现单独登记到 Godot v2 线程目录，保存 `lastLessonActivationIndex` 和 `threads:last_lesson_threads` SHA。`noncombat_last_lesson_direct_route.gd` 修前首节点不可达退出 1；修后以 `Domain.start` 的核心 NPC 登记为基础构造合法化神第 12 回合，依次走 N0 接课、N1 观课、N2 宗门借剑、N3 交涉、N4 送别、N5 余音、八回合后 N6 上界来信，逐节点核对原 ID、地点、N3 借剑变体、N5 来源 `historyEchoes` 全文及反向不混入、白刃 `ASCENDED/ECHO_ONLY` 和七节点完成回执，退出 0。网页现行 `_applyNpcRelationEffect` 对作者两段键 `npc_relation:jian_linger` 无目标 ID，Godot 按其现行行为接受而不虚构好感；N2 坊市左选正在接线，N3 战斗左选仍未接入。

`noncombat_story_thread_upgrade.gd` 在原 v1 线程待选档升级后核对新 marker；另以旧 v2 无 marker 存档冷读原字节，下一有效决定启用最后一课，重开严格一致。伪造新来源 SHA 的独立槽恢复返回 `SOURCE_MISMATCH`，原槽字节不变；专项退出 0。新优先级 100 线程使原高境界构造态测试的“下一卡应为天枢/天网”假设失效，相关专项明确把白刃设为回响态以隔离该入口，两个旧高境界线程专项以及化神/渡劫关口回归通过。

独审发现首次加载最后一课文件缺失时只检查旧炼气线程路径，误报 `SOURCE_MISMATCH`。`noncombat_last_lesson_source_failure.gd` 以缺文件和有文件但定义漂移两例先红后绿；v2 线程读取目标模块失败时现记录真实缺源标志，分别归 `SOURCE_UNAVAILABLE` 与 `SOURCE_MISMATCH`。这只证明当前来源分类；完整线程待选卡的所有故障形态仍须在真实冷档路线核对。

**证据边界**：上述七节点是构造境界后的线程模块路径，尚未从公开新档自然晋到化神并通过 `Domain.choose`、磁盘冷恢复整条路线。N2 坊市买/换/空手/借剑交易、N3 三鸣旧剑战斗胜败逃、真实战斗助战、跨世线程以及其它 N6/N7/N8 系统仍待完成。完整 291 项 Godot 门禁本批没有跑完，不能记为全量通过。

## 2026-10-29：高优先级故事场景规则与默认像素首战音效（N6/N9 局部）

`StoryThreadEngine` 对 priority≥90 的连续场景只使用作者节点间隔，并在发卡前检查已结节点、变体地点与玩家 `currentLocation`，再把独立的 `historyEchoes` 接到文案。`noncombat_story_high_priority_rules.gd` 修前因规则缺失退出 1；首版实现被独审发现读取错误地点键，改用生产状态的 `currentLocation` 后，零间隔/8 回合来信/普通 2 回合、前置节点、地点及告别选择回声均退出 0。独审又指出来源 priority≥90 的已合资格节点可抢先于低优先级 pending；`noncombat_story_priority_preemption.gd` 用实源天枢与灵矿待发态先红后绿，验证天枢抢先且灵矿待发不丢。`noncombat_foundation_higher_threads.gd`、`noncombat_last_lesson_variants.gd`、`noncombat_story_thread_upgrade.gd` 回归退出 0。此为调度规则，最后一课七节点仍未登记。

首战剑道真实入口默认使用 `QingyunPixelStage`。`noncombat_first_sword_stage_audio.gd` 修前因没有动作与接触音频节点退出 1；现按原 `action_presentations.json` 与 `path_identity.json` 的 cue ID、路径、音量在出招和接触帧播放。独审发现胜利音量继承上一动作，`play_full_battle_ui.gd` 新音量断言先退出 1，改为来源 `sfx_treasure` 播放后退出 0；首战动作音专项与默认像素合同也退出 0。运行总门禁仍待本批稳定后从头完成，不能据此签收 N6/N9 或 12 阶段。

## 2026-10-29：核心 NPC 登记与旧档激活（N7/N6 上游）

浏览器 `NpcSystem.loadData` 在进入游戏时从 `npcs:core` 登记全部人物，跨世重置时重新登记；Godot 原先仅在白狐任务入口建立 `worldContinuityState`。因此跳过白狐的路线缺白刃/剑灵儿实体证明，也影响普通 NPC 遭遇的在场判断。`noncombat_world_registry_bootstrap.gd` 修前退出 1（`core NPCs were not registered at new-run opening`）；现新开局第 0 决定快照和新生命建立时写入来源核心 NPC 登记、激活序号与来源 SHA，白狐入口复用已有登记。旧存档的历史重演按原激活边界不补写过去，下一次有效决定才建登记。新档、旧首世和改 SHA 后原档保留的磁盘专项退出 0；白狐旧入口、NPC 自然遭遇、转世继承专项退出 0。`noncombat_death_rebirth_journey.gd` 现包含无 marker 的第二世待选和已推进存档，以及 NPC 来源 SHA 漂移拒绝/原字节保留，完整自然路线退出 0。

**限制**：独立只读审查确认首世新档和旧档的登记与白狐复用，跨世旧档及来源 SHA 边界静态复审通过，跨世自然专项也退出 0。这只补人物连续性登记，不等于 8 人好感、事件、个人弧线与最后一课自然路线全部可玩。来源 JSON 与 manifest 同时更新但结构非法的旧第二世归档分类尚未单独验证；N7/N6 及 N0–N11 均未整体签收。

## 2026-10-29：白刃最后一课来源入口条件（N6 局部）

网页版 `StoryThreadEngine` 对 `bairen_last_lesson` 使用第 12 回合 `turn_count`、化神/渡劫双境界资格，以及白刃和剑灵儿均为本世实体的合同。Godot v2 线程引擎原先仅支持 `choice_match` / `realm_enter`，只比较单一 `realm`，并忽略 `npcManifestations`，因此不能正确判定这条线程的来源入口。`noncombat_last_lesson_prerequisites.gd` 修前退出 1（`last lesson source prerequisites were not admitted`），修后对回合门槛、两境界、死亡/回响态及缺少连续性登记的反例退出 0；现有 `noncombat_higher_simple_threads.gd`、`noncombat_foundation_higher_threads.gd`、`noncombat_story_thread_upgrade.gd` 退出 0。

同批补齐来源 `StoryThreadEngine._matchesHistoryVariant` 的坊市购买物、交易结局、`anyOf` 组合及战斗模式约束。`noncombat_last_lesson_variants.gd` 使用原 `last_lesson_threads.json` 的四种坊市/借剑分支与八种入课×战果/交涉变体，修前退出 1（`purchased sword did not select source variant`），修后退出 0；旧筑基变体专项回归退出 0。

**范围**：独立只读审查将入口谓词和 12 组复合变体匹配器判为 VERIFIED。`bairen_last_lesson` 尚未登记到 v2 线程目录，七节点的坊市/战斗/回执仍不可玩；N6 与 N0–N11 均未整体签收。总门禁仍在进行。

后续真实接线依赖：单独的线程激活/来源指纹以兼容旧档；坊市 `ENTER_VENDOR` 的真实结算与 `outcomeContext`；旧剑战斗胜败逃回执；白刃飞升的 NPC 生命周期；第 8 回合来书的自然排期与完成回执。节点间隔、前置/地点与 `historyEchoes` 已在通用 v2 规则中接通，但尚未在完整最后一课生产路线中验收。以上每项须经来源输入、磁盘恢复和桌面展示核对。

## 2026-10-28：开局零决定存档恢复（N2 局部）

| Issue | 根因 / 修前 FAIL | 修复 / 修后 PASS | 审查与限制 |
| --- | --- | --- | --- |
| ISSUE-N2-ADMISSION-OPENING | `Domain.start` 的第 0 决定快照含 `normalNarrativeAdmission.activationIndex=1`；`Domain.restore` 原校验只许激活序号 ≤ 当前决定且重建时从 1 开始，故 `noncombat_run_session.gd` 修前报 `second view could not restore the first committed snapshot`。 | `noncombat_domain.gd:restore` 允许精确的下一决定激活边界，并在第 0 决定/教程快照重建同一字段；`noncombat_run_session.gd` 修后退出 0，还从真实首快照派生两份独立 v2 文件，验证旧形状无 marker 可恢复、未来激活序号 2 被拒绝且原字节不变。 | 独立复审对本断点及两条磁盘边界给出 VERIFIED；这是 v2 envelope 的旧形状，真实 LegacyStore v1 整体导入仍属 N10，N2 全阶段未签收。 |

## 2026-10-28：道侣好感里程碑与五类因果回响（N7 局部）

来源链：`CompanionSystem.applyChoice` → 五个好感阈值（100/80/50/20/−20，单次只取最高的已跨阈值）→ P52 待发里程碑卡与动态因果种子 → `KarmaSystem.getReadySeeds` → `CardSystem._drawKarmaCard` 的 `payoffEvent` → `cards:karma_expansion` 五张 `companion_dynamic` 因果卡。Godot 已接当世队列、一次性旗标、非实体角色过滤、成熟种子来源图/文案投影、双选数值与关系变化及单次回执。里程碑卡本身按网页版现行 `game.js` 入口仅结算数值；其 `companionEffects` 虽写在来源卡上，入口未调用 `CompanionSystem.applyChoice`。源 JS SHA `bd6386d3fb6bae095ce312c5bac520129bbee18f692ba25cb6ccc7f13104adcb`，`tools/export_companion_milestones.js` 可复现五张卡，导出到桌面包会包含的 `godot/content/derived/companion_milestones.json`；生成目录 SHA `d2f02a0918fcb381d772a6d1239df312e134ecaa792d4eefb087dc7eb63211a5` 受运行和总门禁校验。

证据：`noncombat_companion_milestones.gd` 覆盖事件选择跨 20、五阈值、队列优先、一次性、死亡跳过、五张成熟回响左右十组选择的全部数值/好感/信任/羁绊、与旧成熟因果双向优先级、领域入口选择，退出 0。`noncombat_companion_events.gd`、`noncombat_companion_response.gd`、`noncombat_first_karma.gd`、`noncombat_second_karma.gd`、`noncombat_causal_services.gd`、`noncombat_body_high_realm_karma.gd` 回归退出 0。独审先发现以下两个反证，修复后的复审认为封顶选择和来源结算 VERIFIED、冷档全路径仍 UNPROVEN：

| Issue | 根因 / 修前 FAIL | 修复 / 修后 PASS | 当前结论 |
| --- | --- | --- | --- |
| ISSUE-N7-COMP-REPLAY | `Domain.restore` 的 `FLOW_PENDING` 历史分派漏 `comp_`；`tools/validate_godot_runtime.py` 新分派 Validator 在修复前以 `Companion choices cannot be resumed during strict save replay` 失败。旧道侣 marker 若没有新里程碑激活界限，重演跨阈值历史还会多出旗标、队列和种子；`noncombat_companion_milestones.gd` 修前以 `pre-milestone companion save gained new facts during replay` 失败。 | `noncombat_domain.gd` 加 `comp_` 分派；`noncombat_companion_events.gd` 用 `milestoneActivationIndex` 约束新事实，旧 marker 回放不启用，新有效选择再激活。专项、来源因果与普通存档相邻回归退出 0。 | 模块和分派修复已核；尚缺自然道侣整段磁盘 `restore()`，故冷档端到端 UNPROVEN。 |
| ISSUE-N7-COMP-CAP | 来源 `EffectService.previewCardChoices` 禁用仅正收益已封顶方向；初见卡道心封顶、福运未满时，Godot 仍收右选。专项修前以 `capped milestone choice ignored the executable other option` 失败。 | `noncombat_companion_events.gd:choice_available` 检查纯正收益封顶，全部封顶时只放行来源首方向；专项修后退出 0。 | 独审复核 VERIFIED。 |

当前 `noncombat_run_session.gd`、`noncombat_choice_echo_natural.gd`、`noncombat_second_karma.gd` 相邻回归退出 0；全量 Godot 总门禁在这次修复后尚未取得退出 0。仍待干净开局获取 `ds_demoness` 后自然跨阈值并写盘冷恢复，以及完整道侣危机、战斗事件与弧线。**N0–N11 共 12 阶段均未整体签收。**

## 2026-10-28：道侣事件 P50（N7 局部）

按网页版 `CompanionSystem.js` 与 `companions:events` 接入 8 人当世羁绊/信任/冷却状态、持久激活标记、已拥有且存活人物的 P50 概率与事件池调度、作者事件选择和一次性回执。事件选择使用由生命 ID、轮次、人物及抽样通道确定的稳定值，以便 Godot 严格重放；势力声望修正与来源 10 轮事件冷却已接。桌面剧情卡在作者未指定场景图时从 `companions:portrait_stages` 按人物好感补立绘。37 个纯剧情事件的双选以及两处大幅降好感的 `companionSacrifice` 因果种子在构造态专项退出 0；带战斗契约的 `jian_linger/jle_8_sword_tomb_old_master` 尚待战斗网关接入。来源规则 SHA `bd6386d3fb6bae095ce312c5bac520129bbee18f692ba25cb6ccc7f13104adcb`。元婴来源卡 `ds_demonic_auction` 取得 `ds_demoness` 后，她能从 NPC 目录注册 8 轮初始冷却及 3 条通用可重复事件；`noncombat_nascent_seductress_choices.gd` 构造态验证购买接入注册。旧 Godot 档以激活序号保持原历史重演，叙事浮现、先知长局、普通抽卡与存盘专项退出 0。其余原始获取 ID `mortal`、`demon`、`whiteFox` 无 NPC 注册资料，不能伪映射为 8 人作者目录；本批尚无公开开局自然获取/事件轨迹，五人个性化弧线、里程碑/危机、高好感回响及完整桌面体验仍待完成。**N0–N11 共 12 阶段均未整体签收。**

人物事件选择还按 `ChoiceOutcomeRouter` 产生持久即时回应；`noncombat_companion_response.gd` 经领域入口验证事件待选、选后回应和确认回执，退出 0。

## 2026-10-28：叙事浮现 P35（N7 局部）

Godot 已按网页版 `StoryNetworkSystem.NarrativeSurfacing` 的每 5 轮检查和 P35 出卡接入白刃死亡后第 3 轮遗产、四颗以上因果种子负重、已注册道侣好感 18–19 临界事件。两选的数值、好感、法宝与决定回执进入同一存档；浮现默认 12 决定冷却。来源规则 SHA `08cd0d1ac24caeae35629210a0f2de0a24a563c7e3c4ea2da3ffe346f8f0a1e4`。`noncombat_narrative_surfacing.gd` 验三类来源事件与白刃遗剑，退出 0；`noncombat_narrative_surfacing_natural.gd` 从公开法修路线自然抽到「肩上的重量」，待选和选后严格磁盘恢复，退出 0。随后先知自然路线亦严格重演两次浮现选择。白刃死亡和道侣临界好感还没有自然生产路径，道侣获取/事件/弧线仍缺；**N0–N11 共 12 阶段均未整体签收**。

## 2026-10-28：人物叙事普通卡准入（N7 局部）

网页版 `CardSystem` 在普通抽卡前调用 `NarrativeLedger.evaluate`。Godot 已修复作者 `cards:story_dialogue` 卡的三个具体漏判：白狐死亡后的实体对话、白落霜初识语义在作者卡与动态弧线卡之间的重复、`sd_nd_luoxuan_trust` 未等初识结算就入池。可重复叙事卡现在按来源默认 12 决定冷却。旧 Godot 档重演旧卡池，下一有效决定经 `normalNarrativeAdmission.activationIndex` 启用新规则；`noncombat_story_semantic_legacy.gd` 验旧形态、升级和严格重演，退出 0。规则来源 `NarrativeLedger.js` SHA `485c6d61b335db1a418900a552d3b001aea66348b8ba02ef8b82111264c9e20a`；`noncombat_story_semantic_admission.gd` 验四项，普通抽卡基线、筑基普通池、元婴普通目录专项退出 0。此处仅是普通卡准入的局部迁移，道侣获取、道侣事件、弧线及完整叙事账本未完成；**N0–N11 共 12 阶段均未整体签收**。

## 2026-10-28：天机先知弧线（N7 局部）

网页版 `SeerArcEngine` 与血煞弧线同属 `StoryNetworkSystem.js`（来源规则 SHA `08cd0d1ac24caeae35629210a0f2de0a24a563c7e3c4ea2da3ffe346f8f0a1e4`）。Godot 已从 `companions:arcs` 投影四阶段、三高潮、来源效果与回应，按道心正增量×0.2 向上取整、秘密类标签 +3、各境界突破奖励推进揭示度；高潮 P44、阶段 P39，在盟友与回响优先级之间出卡。动态卡从 `companions:portrait_stages` 补天机老人肖像，来源和图像均受指纹保护。旧 Godot 档在下一次有效决定激活。

证据：`noncombat_seer_arc_flow.gd` 覆盖道心/标签推进、无时钟属性变化、四阶段与三高潮排队、作者选项和回应，退出 0；`noncombat_seer_arc_natural.gd` 复用公开法修长局。人物叙事冷却启用后，筑基关口揭示度为 10，认证胜利升金丹后达到阈值 20；先结算高优先级线程，再自然抽出天机揭示卡，待选及选后严格磁盘恢复、回应确认一次，退出 0。其余阶段与高潮无自然路线证据，道侣弧线、高好感人物回响及剑崖进入仍待迁，**N0–N11 共 12 阶段均未整体签收**。

## 2026-10-28：血煞盟友弧线（N7 局部）

网页版 `StoryNetworkSystem.AllyArcEngine` 来源规则 SHA 为 `08cd0d1ac24caeae35629210a0f2de0a24a563c7e3c4ea2da3ffe346f8f0a1e4`。Godot 已从作者 `companions:arcs` 投影认可、信任、战友、传承及真相/渡劫/命运卡，数值推进按恶业增量、标签、战果和境界变化进入同一持久事务；高潮与阶段队列按来源顺序延后出卡。动态卡原本没有场景图，桌面版按 `companions:portrait_stages` 补血煞老祖肖像并校验来源与图像。旧 Godot 档在下一次有效决定激活新弧线。

证据：`noncombat_ally_arc_flow.gd` 覆盖来源投影、两选效果、回应 ID、跨四阶段及三高潮排队、同一决定序号内恶业变化，退出 0；`noncombat_ally_arc_natural.gd` 从公开剑修入口经白狐恶业选择、业力回响、剑冢与传承卡，自然达到同盟度 23 并在 P42 抽出认可事件，待选与选后严格磁盘恢复、回应确认一次均通过，退出 0。相邻 `noncombat_mentor_arc.gd`、`noncombat_choice_echo_natural.gd`、`noncombat_bazaar_vendor.gd` 退出 0。其余盟友阶段与高潮尚无自然轨迹，道侣弧线、高好感回响及剑崖进入仍待迁，**N0–N11 共 12 阶段均未整体签收**。

## 2026-10-28：人物选择回响（N7 局部）

网页版 `GameLogic._plantChoiceEcho` 仅对 `COMPANION_ARC`、`COMPANION_EVENT`、`MENTOR_ARC`、`ALLY_ARC`、`SEER_ARC` 种回响；`ChoiceEchoEngine` 先按 NPC 模板首个匹配项定种，再检查轮次、当前好感、存活、地点、境界；`StoryNetworkSystem` 以 P36 出卡。Godot 已在师尊等人物选择的持久提交内种下来源模板或通用种子，在 P36 投影待选卡、结算选项并重演动态卡 ID。14 条模板共 28 个选项的效果消费者逐项通过；旧剑法宝依赖待选回响卡核对来源；通用回响的随机文案与浏览器时间戳 ID 改成存档内确定序号，以支持严格重演。来源规则 SHA 为 `9b98f72a08ee2e02e87a8cd4b8277dc693ed4dcc9afbb6c77469e67c72c87db5`。

证据：`noncombat_choice_echo_flow.gd` 验证旧战线索、旧剑法宝及通用回响，退出 0；`noncombat_choice_echo_templates.gd` 扫过 14 模板的 28 选择，退出 0；`noncombat_mentor_arc.gd` 实际师尊选择写种子、写盘失败回滚与严格读档，退出 0；`noncombat_choice_echo_natural.gd` 公开剑修路线在第 29 轮取得通用回响，待选和选后严格磁盘恢复，退出 0；`noncombat_choice_echo_public_seed.gd` 公开另一条路线在回响到期后因离开原地点不出卡，种子可严格读档，退出 0。相邻 `noncombat_scene_layer_natural.gd`、`noncombat_rebirth_mentor.gd`、`noncombat_rebirth_legacy.gd` 均退出 0。此处已证明通用人物回响自然可达；高好感模板只证明投影/结算，尚无自然种子轨迹，不能据此宣称旧战真相等线索自然可得。剑崖位置进入、其它人物弧线与高好感回响继续待迁，**N0–N11 共 12 阶段均未整体签收**。

## 2026-10-28：证据星图与终局资格（构造态）

天机预言左选 `find_clue` 写入角色 `clues`，与网页版 `GameStateManager.addClue` 的状态源一致，转世会继承该线索。终战快照根据来源 `world:truth_atlas` 计算假说置信度：支持证据数 ÷ `requiredEvidence` × 100，再扣每条反证 25 并限制在 0–100；无来源置信度字段不能伪造资格。`noncombat_heavens_hint.gd` 与 `noncombat_tribulation_gate_entry.gd` 退出 0，后者用线索与羁绊状态产生红尘/混沌结局并检查转世继承。后续地点深层卡已接通宗门丹印线索；人物回响、剑崖入口等线索路径仍待迁移，结局自然可达及完整桌面长局尚无证据。**N0–N11 共 12 阶段均未整体签收。**

上界续卡经 Godot 领域选择时现在也结算网页版每次选择后的法宝/功法被动再生；渡劫终局专项回归退出 0。来源 `SceneLayerSystem` 的深层地点卡在网页由访问计数进入；Godot 现按第 8 次访问发 `loc_sect_deep`，公开筑基路线实测取得 `sect_alchemy_secret` 并严格磁盘恢复。`loc_sword_cliff_deep` 的选择消费者经构造态验证，剑崖地点自然进入尚无证据。`ChoiceEchoEngine` 通用人物回响已有真实入口；模板中的旧战等线索仍不能当作自然可取得。

旧 Godot `hintClues` 存档的历史选择在重演时沿用旧写法；恢复后的新选择使用角色 `clues`。终局与转世兼读旧线索，专项验证旧形态、来源资格及转世继承。编辑中天机脚本曾被写入工具清空，已按本轮读出的实现恢复并通过 `noncombat_heavens_hint.gd`、`noncombat_tribulation_gate_entry.gd`、`noncombat_rebirth_legacy.gd`；`noncombat_heavens_hint_legacy_clue.gd` 还从公开剑修路线生成旧线索、写盘并严格恢复，退出 0。

## 2026-10-28：渡劫百点终局与上界入口（构造态）

`ch_tribulation_100` 现在从渡劫四章和遭遇配额进入；左选迎战天道意志，右选兵解轮回并继承道心 +2。战场原图及动作帧同步入包，来源善恶业抽弃牌规则在首回合与后续回合生效。胜败逃认证回传覆盖重复拒绝、致死伤势与寿尽死亡卡；胜利冻结 token 和结局资格，领取本脉法诀后按来源真相图鉴检查飞升/红尘/混沌条件，旧愿不满足回退飞升。飞升尾声可进入 `pa_ascension_moment` 上界连续卡或轮回。`noncombat_tribulation_gate_entry.gd` 构造态专项含奖励/尾声/上界 JSON 冷档语义，退出 0；化神关、渡劫试炼、高境界抽卡、轮回恩赐专项回归退出 0。来源包现为 74 数据/968 图/32 音频。红尘/混沌的假说资格尚无自然生产者；公开自然长局、真实逐牌通关、严格磁盘冷恢复和上界全目录未验，**N0–N11 共 12 阶段均未整体签收。**

## 2026-10-28：元婴至渡劫普通抽卡运行入口

此前高境界目录/选项专项未经过运行抽卡函数；该函数只放行到金丹，实际会在元婴停住。新增 `noncombat_higher_runtime_draw.gd` 先红于该拦截，修后元婴、化神、渡劫三境都可从运行抽卡函数取得可选来源卡，并记录各自卡模块 SHA。渡劫指纹在保存恢复和状态提交时复核；专项经 JSON 冷档语义退出 0。公开晋境长局、磁盘严格重启和桌面选择仍未验。**N0–N11 共 12 阶段均未整体签收。**

## 2026-10-28：渡劫试炼 `it_combat.left` 战斗闭环（构造态）

从 `t_immortal_test` 的原四节点线性试炼进入 `it_combat`，左选现在接来源预警、免费/10 灵石疗伤备战、认证待战请求、仙人残影三段意图与来源战场。胜利一次结算基础战利品、选项效果及顶层渡劫丹/修为/灵石，领取战果后推进 `it_reward`、`it_blessing` 并完成试炼；战败与撤离分别写失败/放弃回执且不发胜利奖励。`noncombat_tribulation_trial_battle.gd` 胜败逃、重复提交及预警/待战/结果卡 JSON 冷档语义专项退出 0；`noncombat_tribulation_trial.gd`、`noncombat_nascent_battles.gd`、`noncombat_deity_gate_entry.gd` 回归退出 0。同步后的来源包为 74 数据/960 图/32 音频。当前证据为构造态认证战果；公开自然可达长局、磁盘严格冷恢复和真实桌面逐牌胜利仍需验。**N0–N11 共 12 阶段均未整体签收。**

## 2026-10-28：化神百点关到渡劫入境

来源 `ch_deity_100` 的章节与遭遇配额、恶业预警、三种备战、法宝装备实例消耗、业劫战场、计划图、每 10 恶业增加 1 受击及法宝开场护盾 3/敌方攻击 -1 已接入。胜败逃认证结果可一次回传，胜利产生化神主线终局事实、晋升渡劫、选择奖励及入境方向；失败和撤退保留前置事实。`noncombat_deity_gate_entry.gd`、元婴及金丹关、化神普通池专项退出 0。法宝牺牲使用关口实例 ID 的确定性选取以便历史重放；网页版此处用全局 `Math.random`，跨实现同次随机选中哪件法宝尚未做轨迹一致性验收。此项仍是构造态认证战果及 JSON 冷档语义，公开自然长局、真实桌面逐牌胜利和磁盘严格冷恢复未验。**N0–N11 共 12 阶段均未整体签收。**

## 2026-10-28：元婴百点关到化神入境

来源 `data/cards/chapter_milestones.json` 的 `ch_nascent_100` 已由章节配额排期，四种备战分支建立认证请求；化神丹免疫攻击反噬并减少敌方 3 点初始气血。来源计划图、虚空雷罚战场、战斗攻击反噬致死、胜败逃回传、主线事实消费与结果生产、化神晋境奖励及入境选择已通过 `noncombat_nascent_gate_entry.gd` 构造态专项。金丹关和元婴普通池专项回归通过。胜利时事实缺失或终局事实重复会拒绝整个候选结算；失败及撤退保留事实。专项使用认证战果构造和 JSON 冷档语义，尚不代表公开自然长局、真实桌面逐牌通关或磁盘严格冷恢复。**N0–N11 共 12 阶段仍均未整体签收。**

## 2026-10-28 元婴普通池与高境界线性内容（局部通过）

元婴 `n_ancient_ruins` 四节点、秘境成败/主动离场回执、`n_hunt.left` 与 `ar_boss.left` 来源战斗待战/回传已接；同步新增两场来源画面并开放元婴普通抽卡，`normalFlow` 首次元婴抽签钉住 `cards:nascent` SHA。`noncombat_nascent_ruins.gd`、`noncombat_nascent_battles.gd`、`noncombat_nascent_normal_pool.gd`、原元婴洞府和金丹普通池专项退出 0。构造态 `noncombat_deity_ruins.gd` 验证化神仙迹四节点、丹药、死亡、成功及离场，`noncombat_tribulation_trial.gd` 验证渡劫试炼的非战斗四节点，`noncombat_higher_normal_pool.gd` 验证两境来源抽卡选项、拍卖丹药/种子及化神故事结局倾向，均退出 0；化神普通运行池开放，首次抽签钉住 `cards:deity` SHA。`noncombat_nascent_gate_entry.gd` 当前退出 1，准确暴露修为 100 时 `ch_nascent_100` 未排期；该红测未纳入总门禁。元婴自然长局/严格冷档、渡劫试炼左选战斗、元婴以上百点关及最终结局尚未完成；渡劫普通运行池仍关闭。**N0–N11 共 12 阶段均未整体签收。**

## 2026-10-28 六条高境界普通故事线程（构造态通过）

复用 v2 线程调度器接入筑基天书暗门、筑基墨线宗册、金丹天税、元婴梦证、化神天网、渡劫门前证词的原来源节点；完成任务门槛在 Godot 用成功结局的 `questState` 核验。构造态专项验证天书暗门优先级、首选历史变体、完成回执、墨线宗册三幕、拒绝不能开启暗门及来源指纹漂移拒绝，其余四境三幕右支与世界旗标。渡劫首卡已读前五线完成回执，投影对应方向文字；缺失或与源选择不一致时使用来源中性文案。旧 v1 线程升级和灵矿回归通过，天书公开自然路线已验证完成任务后暗门首卡的待选冷恢复与选择提交，法/丹/体自然路线及剑修第四幕专项通过。网页版 `test_f2c_receipt_spoof_counterexample.js` 当前失败：它接受没有原选择记录的伪造完成回执，故跨境回声的“拒绝伪造”暂不能宣称与源端现行行为等价。其它高境界普通线程尚无公开长局和冷档验收；“白刃最后一课”仍缺商店/战斗跨模式消费者。**N6 未签收，N0–N11 共 12 阶段均未整体签收。**

## 2026-10-28 天书筑基任务与自然入口（局部通过）

`noncombat_foundation_tianshu_quest.gd` 验证 `quests:tianshu_codex` 的四幕、两种拒绝、两种完成种子和势力奖励，并验证与 `spell_codex` 同获资格时先出天书、天书关闭后法修任务可续排。`noncombat_foundation_tianshu_natural.gd` 从公开法修开局经认证首战/炼气雷关、真实章节和普通调度到天书首卡，验证严格冷恢复、拒绝、命盘中断后续接、写盘失败零变化及完成。法修与丹修原自然路线回归通过。战斗终态仍用认证夹具，高境界兑现、人物世界与线程总覆盖仍待处理。**N6 未签收，N0–N11 共 12 阶段均未整体签收。**

## 2026-10-28 丹修筑基任务自然入口与冷恢复（局部通过）

`noncombat_foundation_pill_natural.gd` 从公开丹修开局经认证首战、炼气雷关和真实章节/普通调度自然进入 `q_pill_1`，验证入口与完成档严格冷恢复、拒绝不领奖、四幕主链、来源机缘、失败写盘保持原字节，退出 0。战斗终态仍用认证夹具，右支机缘、低资源死亡、桌面操作和高境界因果未验。**N6 未签收，N0–N11 共 12 阶段均未整体签收。**

## 2026-10-28 丹修筑基任务四幕（构造态通过）

`noncombat_foundation_pill_quest.gd` 验证来源 `quests:pill_master` 的入口、拒绝、四幕左链、`pill_insight`、五炉与毁丹旗标、`pillMasterSacrifice`、完成机缘及 `pillMasterEcho`；体/法修任务回归通过。自然入口、冷恢复、右支机缘和高境界兑现尚未验，天书任务尚未接入。**N6 未签收，N0–N11 共 12 阶段均未整体签收。**

## 2026-10-28 元婴魔修相遇两选项（构造态通过）

`noncombat_nascent_seductress_choices.gd` 验证拍卖会左选扣 100 灵石、善恶业各 +5、`ds_demoness` 入同伴资源；丹师交易右选保留来源叙述块并结算修为/恶业。来源卡类型是 `NORMAL`，浏览器只在 `NPC_ENCOUNTER` 类型处理 `npcAffection`，故此处不额外写好感；`ds_demoness` 在 NPC 表有定义、伴侣弧线表无被动。元婴运行池、伴侣事件和桌面呈现仍未验。**N0–N11 共 12 阶段均未整体签收。**

## 2026-10-28 元婴洞府两节点秘境（构造态通过）

`noncombat_nascent_cave.gd` 从原 `cards:nascent` 读取 `n_cave.left` 与 `nascent_cave` 两个节点，验证入口的灵石、炼妖壶、`fortuneWheel` 种子，逐节点原选项、万年玄冰、成功与主动离场一次性回执。修前停在入口拒绝，修后退出 0；金丹秘境与元婴交易专项回归退出 0。元婴普通运行池和自然突破冷档仍未接通。**N0–N11 共 12 阶段均未整体签收。**

## 2026-10-28 元婴来源交易与洞府丹药（构造态通过）

`noncombat_nascent_items.gd` 从来源 `cards:nascent` 验证 `n_cave.right` 收取灵石/丹药和 `n_trade_city.left/right` 的两种付费交易，法宝取得写入原来源交易回执；灵石不足时付费方向不可选，离开仍可选。筑基普通池及金丹来源选择回归退出 0。元婴普通池、洞府左选秘境、古迹与战斗还未接入，未形成自然高境界长局。**N0–N11 共 12 阶段均未整体签收。**

## 2026-10-28 金丹自然普通卡与严格冷恢复（局部通过）

公开法修开局的 `noncombat_foundation_gate_natural.gd` 已走过筑基百点关、金丹入境与金丹章节，真实普通目录自然抽出 `g_shop`；待选、购买后的 JSON 存档均可严格恢复。修复 `noncombat_domain.gd` 历史回放只接受炼气/筑基章节卡而漏掉 `ch_golden_*`，及 `noncombat_treasure_acquisition.gd` 在普通购买中对空 `dungeonRun` 调用 `.get()` 的断点。关口胜利仍使用认证终局夹具；虎娘自然战斗、金丹百点自然全链、高境界池及 N6–N11 仍有缺口。**N0–N11 共 12 阶段均未整体签收。**

## 2026-10-28 金丹普通池试开与虎娘左选（构造态通过；自然冷档待验）

`noncombat_bandit_entry.gd` 验证 `ds_female_bandit.left` 从 Godot 领域选择进入预警、认证请求、来源三意图战斗与战场图，胜败逃三结局可回流；体修胜利按原 `skillAcquire` 取得【虎煞破势】并登记本世一次尝试。`noncombat_golden_normal_pool.gd` 验证金丹目录抽签与基本选择；没有完全无方向可选的卡。官坊 `g_shop.down` 在付费方向仍可用时关闭，符合来源兜底规则。运行抽池现已开放，并在第一次金丹抽签为 `normalFlow` 写入 `cards:golden` SHA。公开开局到金丹后的自然抽卡、虎娘选择严格冷恢复、窗口呈现和高境界长局未验，**N0–N11 共 12 阶段均未整体签收。**

## 2026-10-28 金丹百点关口（构造态通过；自然抽池未开放）

`noncombat_golden_gate_entry.gd` 从来源 `ch_golden_100` 构造金丹 100 点章节与遭遇配额，验证无丹雷阵/空手、有凝婴丹服丹/雷阵/空手共五种认证备战请求，来源阴阳雷兽战场贴图、阳雷/阴雷固定节拍、阴雷穿透与服丹对策。胜败逃三结局经 `BattleReturnFlow` 一次结算；胜败消费本境破境助力，撤离保留；胜利升元婴，继承奖励及入境选择在 JSON 冷档语义下可继续。此证据未覆盖金丹自然抽卡及真实桌面逐牌胜利。虎娘左选内嵌战斗仍缺，运行抽池仍关闭。**N0–N11 共 12 阶段均未整体签收。**

## 2026-10-28 金丹 5 条线性秘境（构造态通过；自然抽池未开放）

`noncombat_golden_dungeons.gd` 由 `cards:golden` 读取太古遗迹和剑/法/体/丹四秘境的 5 个线性节点数组、16 张原卡；验证各入口路径限制、逐节点原数值选择、守卫核心/太古玉/古剑的所有权、元婴丹、成功结算、主动离场一次性回执与错误流派拒绝，退出 0。现行网页的线性数组虽把两个节点标为 `battle`，卡本身仍为 `NORMAL` 选择，`CardSystem` 按序号前进；此切片按来源行为实现，未增加战斗。筑基秘境入口、筑基普通池和金丹选择专项回归退出 0。构造态金丹档尚不能替代自然抽卡、严格冷恢复及桌面呈现验证；金丹普通池仍关闭。**N0–N11 共 12 阶段均未整体签收。**

## 2026-10-28 金丹普通卡来源选项续接（局部通过；运行抽池仍关闭）

来源选择专项现验证 8 个数值选择、10 个因果种子选择（含筑基旧境界卡与一条双种子）、法宝/丹药/商店、6 个 NPC 数值/好感或费用选择、魔修再邀左选续到原 `dp_demon_truth` 卡，以及虎娘右选的原公式 50% 夹具、体修成功/失败本世尝试及其他流派不抽机缘，退出 0。灵脉左选现按来源扣修为、加道心并写入金丹破境助力，单次 +20%、累计封顶 50%；破境时消费该标记的金丹 Gate 尚未迁入，故此选择仍未闭环。金丹 5 条线性秘境的 16 张原节点卡已有构造态消费者，见上节。`noncombat_foundation_normal_pool.gd`、筑基目录遭遇和筑基里程碑回归退出 0；战斗装载器对空遭遇 ID 的筑基宗门任务误转换也已修复。金丹目录当前无完全无方向可选的卡；失败专项已推进到“运行抽池关闭”。丰富资源夹具列出的 `g_shop.down` 是付费选项可用时的来源限制，月湖右选需筑基丹，实质未支持方向仍为虎娘左选战斗。金丹普通池及自然/冷档路线仍未开放。**N0–N11 共 12 阶段均未整体签收。**

## 2026-10-28 N4 高境界章节阈值预备（构造态通过；自然循环未开放）

金丹来源卡现可在不开放抽池的情况下按原 JSON 回读；`noncombat_golden_choices.gd` 验 8 个数值选择与 7 个因果种子选择在领域层结算，包括一项双种子选择，退出 0。运行抽池仍保持关闭，原失败专项继续指出剩余人物/战斗/特殊效果断点。

网页 `RealmChapterSystem` 的金丹、元婴、化神、渡劫阈值及旧卡 ID 别名现接入 `noncombat_milestone_flow.gd`，四境界各四张、共 16 张非战斗章节卡的排期、来源图、Boss 旅程提示、选择效果与章节回执专项 `noncombat_higher_milestones.gd` 退出 0；炼气及筑基旧专项回归退出 0。金丹普通池尚未开放：试开后 `noncombat_golden_normal_pool.gd` 指出 `g_veinFight`、`g_oldFriend`、`ds_spirit_vein`、`ds_female_bandit`、`iw_sect_family_clash`、`iw_comp_sect_forbid` 在当前消费者下可被抽中却无可选方向，涉及因果、人物关系和新战斗。试开已回退，该失败专项保留作为后续修复入口；不能将 16 张构造态章节卡视为金丹长局可达。**N0–N11 共 12 阶段均未整体签收。**

## 2026-10-28 N4/N5 筑基遭遇配额与百点破境（局部通过；总目标未签收）

`noncombat_foundation_catalog.gd` 从筑基来源普通遭遇目录实际排期一张卡，验证预警、来源认证待战请求、行动图装载、来源战场素材和胜利后导演配额记录，退出 0。此前构造态 `noncombat_foundation_gate_entry.gd` 验四章前置、配额门槛、无丹/有丹备战、心魔开局规则、胜败逃与金丹奖励/入境，退出 0。`noncombat_foundation_gate_natural.gd` 从公开法修开局经正常抽卡、来源章节及定期遭遇累计可见配额，自然走到筑基百点预警，确认待战、提交认证胜利结果、选择奖励及金丹入境；预警、待战、奖励和入境各阶段严格冷恢复，退出 0。旧冷档在金丹入境卡选项的整数/浮点差异导致误拒，改为 JSON 语义比较后，原失败档已可继续；完整自然专项重跑退出 0。三个专项已登记运行验证器。

自然路线使用认证战斗终态夹具，并没有实测玩家逐牌击败百点心魔；失败/撤离在构造态结算，尚缺自然冷档分支。金丹普通循环仍被运行域明确拦截，所以上述入境不是跨境界长局完成证据。**N0–N11 共 12 阶段均未整体签收。**

## 2026-10-28 N4 筑基章节 20/40/60/80（局部通过；总目标未签收）

网页版 `RealmChapterSystem` 的筑基章节阈值为 20/40/60/80/100；Godot 之前仅给炼气章节排期。`noncombat_milestone_flow.gd` 现从原 `chapter_milestones.json` 投影筑基四张非战斗卡，消费首卡流派变体、终局 Boss 旅程的阶段提示、章节事实与 80 点心镜前事回响。历史回放按 `ch_foundation_*` 重新调度来源卡。修前 `noncombat_foundation_milestones.gd` 在 20 点未排期退出 1；修后四卡连续结算、来源图、事实链与回响退出 0。`noncombat_foundation_milestones_natural.gd` 自公开法修开局触发 20 点章节，选择前后严格冷恢复并验来源事实，退出 0。100 点筑基心魔劫及金丹普通循环仍缺；先前自然专项的固定决定序号会因此变化，正重跑受影响路线。**N4 和 N0–N11 均未整体签收。**

## 2026-10-28 N4/N6 筑基秘境图与守卫战斗交接（局部通过；总目标未签收）

`data/cards/foundation.json:f_trial.right` 已接入秘境入口、长老、分岔、整备、守卫与宝藏图。秘境运行记录拥有稳定 session ID，进入、逐节点前进、离场、失败和成功写入同一存档；秘境节点优先于普通轮次事件显示。守卫使用原三阶段 5/7/9 血规则，第二阶段开场护盾和作者阶段画面，胜利先显示 `combat_reward`，确认后才出现两种宝藏选择。

`noncombat_foundation_dungeon_natural.gd` 从公开法修路线固定抽卡到 `f_trial`，验证各节点严格冷恢复、两种宝藏收益、胜败逃三结局、外来及重复回执拒绝、故障写盘回滚，输出 `NONCOMBAT_FOUNDATION_DUNGEON_NATURAL_PASS ... outcomes=3 rewards=2 replay=true rollback=true`，退出 0。`noncombat_foundation_dungeon_entry.gd` 验证另一条分叉、主动离场、来源舞台、三阶段真实规则域战斗及阶段图片，退出 0。两专项已加入运行验证器。`noncombat_foundation_mission_fatal.gd`、`noncombat_battle_return.gd`、`noncombat_cave_rewards.gd` 修改后回归均退出 0。

自然入口的先前首战与炼气雷关由认证终局夹具推进；守卫胜败逃由认证终局结果构造，三阶段逐牌实战仅在构造态测试。新增章节后的秘境自然全链及桌面开战→撤离→回剧情复跑退出 0，`noncombat_foundation_mission_natural.gd` 三战果复跑退出 0；低资源死亡冷档及后续金丹自然突破还未验收。**N0–N11 共 12 阶段均未整体签收。**

## 2026-10-28 N4/N5 筑基宗门任务与升级牌战斗（局部通过；总目标未签收）

`data/cards/foundation.json:f_mission.right` 已接普通抽卡→预警→烈焰虎来源战场→胜败逃结果卡。`noncombat_foundation_mission_natural.gd` 从公开法修路线抽到原卡，以认证终局结果检验三结局奖励/惩罚、外来和重复回执拒绝、故障写盘回滚、来源舞台绑定、各阶段严格冷恢复；退出 0。胜利含基础战利品与来源任务奖励，本路线修为 +42、灵石 +18、恶业 +5、筑基丹 1 枚。此专项不证明真实逐牌胜败。

独审补出战斗快照漏传 `modifiers` 和升级牌 `+` 跨战斗计划、卡牌定义、手牌、来源舞台的断链。`runtime_data_registry.gd` 现按 `data/combat/deck_progression.json` 的优先效果规则生成升级卡；`noncombat_upgraded_battle_card.gd` 对定义、当前牌组计划、战力加成、真实 `CombatDomain.play_card`、手牌显示/按钮及来源动作专项退出 0。`noncombat_foundation_mission_upgraded_natural.gd` 从公开法修开局经同门比试胜利拿到足额灵石，在营地真实付 30+8 升级，再自然抽到宗门任务，严格冷恢复升级牌待战档，桌面 `LaunchBattle` 进入来源战场、真实撤离按钮返回剧情并拒绝重复回执；退出 0。该自然路线的首战、同门比试和炼气雷关仍使用认证终局夹具，升级牌在自然战场中已装载，实际出牌专项为构造牌组。

`noncombat_foundation_mission_fatal.gd` 构造态验证战败道心归零、撤离寿元归零和伤势致死均能与同次回执进入死亡卡，重复回执拒绝；退出 0，低资源自然档和死亡后冷恢复尚待验。独立只读复审复跑升级与致死专项，未见新的确定 P1/P2。白狐战斗、荒村入口、山径战斗旧回归退出 0；来源舞台修改后的真实入口回归另在运行。前一全量门禁 `full-gate-foundation-pool-2026-10-28.log` 因实施中途改码手动停止，不能作为通过证据。**N0–N11 共 12 阶段均未整体签收。**

## 2026-10-28 N4/N6 法修筑基任务与筑基普通池（局部通过；总目标未签收）

| Issue | 来源合同与断点 | 可复核证据 | 结论 |
| --- | --- | --- | --- |
| ISSUE-N6-SPELL-QUEST | `data/quests/spell_codex.json` 四幕的拒绝、研读/询问变体、接受/拒绝契约、终章成功/失败和数组因果种子必须按来源结算。 | `noncombat_foundation_spell_quest.gd` 构造态核选择效果；`noncombat_foundation_spell_natural.gd` 自公开法修开局经认证首战/雷关战果、筑基普通循环达到修为 25，验证失败与成功支、回滚、严格冷恢复及真实桌面按钮/领取回执，均退出 0。正常 Windows OpenGL [1280×800 选择](../artifacts/godot-migration/foundation-spell-completion/choice_1280x800.png)、[1920×1080 选择](../artifacts/godot-migration/foundation-spell-completion/choice_1920x1080.png)、[1280×800 回执](../artifacts/godot-migration/foundation-spell-completion/receipt_1280x800.png) 已目视。 | 四幕局部 VERIFIED；高境界种子消费者、真实逐牌过雷关和两端同种子全程轨迹尚待验。 |
| ISSUE-N4-FOUNDATION-POOL | `data/cards/foundation.json` 的正权重卡会进入筑基普通池。来源复杂效果包括买物、删牌、种子、牌组、未注册的 `demon` 库存道侣。旧 Godot 仅按炼气筛卡且会在抽中全无可选方向时停止续卡。 | `noncombat_foundation_normal_pool.gd` 验来源池、拍卖行 25+6 双费用、黑市剑牌、法宝台账、遗迹体修牌、三类因果种子、低灵石市场选项、付费关系和满属性 `f_love` 后续结算；旧 `noncombat_normal_draw_policy.gd` 已改为只拦金丹及以上，两个专项退出 0。独立只读复审发现并复跑满属性死锁与转世删牌误禁的修复，未见本切片新的确定 P1/P2。 | 当期普通池仍未签收；`f_mission.right` 在上方后续切片补入，`f_trial.right` 来源秘境和更高境界消费者仍缺。`f_ruins_explore` 的两张奖励牌都只带体修标签，网页版跨流派可见选择过滤与来源卡权重有冲突，完整跨引擎可达性需另行裁定。 |
| ISSUE-N4-FOUNDATION-SHOP | `f_shop.up` 必须先扣 25 灵石进入选牌，选中目标另扣牌组规则的 6 灵石，取消不退首费；来源 ID 必须随目标记录和严格回放保存。 | 人物叙事冷却接入后，`noncombat_foundation_shop_natural.gd` 改以固定抽签 0.55 在公开法修第 59 轮、灵石 48 时自然抽到 `f_shop`；验证桌面图/费用、真实 `Choice_up` 点击、故障写盘零变化、目标选中、取消及四处严格冷恢复，退出 0。先前规则的第 30 次循环、灵石 66 记录仅属旧路线。 | 此来源删牌链已获自然入口与冷档证据；目标牌/取消按钮本身尚未由 UI 点击实测，两个操作由 Domain API 执行。途中战斗使用认证终态夹具，不代表真实逐牌胜利。 |

本轮总门禁初跑在 `noncombat_whitefox_entry.gd` 因旧拒绝用例把现在合法的筑基任务入口视为非法而触发脚本错误；用例已改为只测仍非法的状态，独立专项退出 0。后续门禁因实施期间继续改码而手动停止，`artifacts/godot-migration/full-gate-foundation-pool-2026-10-28.log` 不作为通过证据。`godot/` 当前未跟踪，不能用 Git diff 冒充精确变更基线。**N0–N11 共 12 阶段均未整体签收。**

## 2026-10-28 N6 体修筑基任务与高境界因果（局部通过；N6 未签收）

| Issue | 来源合同与断点 | 可复核证据 | 结论 |
| --- | --- | --- | --- |
| ISSUE-N6-BODY-QUEST | `data/quests/body_tribulation.json` 四幕要求体修筑基后触发；第一幕拒绝须关闭任务，第三幕撤退改变第四幕文案，坚持写入 `bodyTrialStarted`，第四幕选择特殊优先/加权机缘、完成奖励和势力声望，只有坚持后硬扛才写入 `bodyTrialDeep`。`data/progression/acquisition_opportunities.json` 对赤身特殊传承要求道心≥2、恶业≤5、体修见闻≥2。 | `noncombat_quest_flow.gd` 按 path 选择来源任务，`noncombat_domain.gd` 接通恢复/选择；`noncombat_foundation_body_quest.gd` 用低恶业构造态验特殊传承、奖励和种子；`noncombat_foundation_body_natural.gd` 从公开体修开局经首战/炼气雷关到任务，验拒绝、坚持/撤退变体、自然恶业 22 导致加权奖池、随机实际奖品所有权、故障回滚、严格冷恢复。两专项退出 0；独立复审原四幕和奖励专项亦退出 0。 | 四幕结算局部 VERIFIED；首战与雷关战果在自然专项中由测试构造的认证结果提交，非真实逐牌桌面胜利，也非浏览器自然同种子全程数值对照。 |
| ISSUE-N6-BODY-UI | 第四幕选择前应看到来源机缘，领取后要显示实际奖品。 | 自然专项在 `q_body_4` 实例化真实 `noncombat_opening.tscn`，检查按钮预览并发出真实 `Choice_left.pressed`，经领域信号自动续卡后核实领取回执。正常 Windows OpenGL [1280×800 选择](../artifacts/godot-migration/foundation-body-completion/choice_1280x800.png)、[1920×1080 选择](../artifacts/godot-migration/foundation-body-completion/choice_1920x1080.png)、[1280×800 回执](../artifacts/godot-migration/foundation-body-completion/receipt_1280x800.png) 已目视；原劫台图、候选比例和实际奖品可见，无遮挡/裁切。 | 所查按钮链通过；1920×1080 固定宽按钮文字偏小，留待 N9 表现验收。 |
| ISSUE-N6-BODY-KARMA | 独立复审发现任务写入的 `bodyTrialStarted`、`bodyTrialDeep` 在 Godot 原无消费者；来源 `data/cards/karma.json` 映射为金丹 `k_body_echo` 和元婴 `k_body_ascension`，来源浏览器 `KarmaSystem.getReadySeeds` 按境界成熟并加跨境界优先级。 | `noncombat_body_high_realm_karma.gd` 修前在金丹回响入口退出 1，修后对两境界来源卡图、左右效果、优先级与一次消费退出 0；`noncombat_karma_flow.gd` 读取原卡及 SHA，`noncombat_domain.gd` 允许这两卡严格历史回放。 | **低层消费者已接线，尚未签收自然高境界兑现**：Godot 境界突破和普通循环目前只到筑基，尚无从玩家首局自然到金丹/元婴的入口与冷档验收。 |

体修自然专项使用持久剧情选择，但首战和炼气雷关通过认证战果夹具越过真实战斗，环境与普通抽卡随机值由测试固定；机缘本身使用原生随机种子，故专项按抽中的候选及所有权验收，不硬断言固定奖品。网页 `test_project_body_tribulation_quest_browser.js` 的入口也人为设置筑基/第 10 回合，仅证明其后来源按钮流程；不能将它称为自然整局浏览器轨迹。体修路径遇到剑修因果牌赠剑选项时，原 UI 曾报可选却在领取层拒绝；`noncombat_karma_flow.gd::choice_available` 现按实际牌组领取结果禁用该按钮，自然体修路径可继续。`godot/` 未跟踪，不以 Git diff 声称精确变更基线。**N6 与 N0–N11 共 12 阶段均未整体签收。**

独审补出选择末态缺口：来源在选择效果、被动恢复及同回合事件后才判燃血/死亡。`noncombat_domain.gd` 现于提交钩子之后、写盘之前对剑/体筑基任务和两张体修高境界因果做末态仲裁；`noncombat_death_flow.gd` 用本次选择历史和收据核来源。`noncombat_foundation_body_natural.gd` 的 q1 气血 1 燃血、上限已尽血亡、道心 1 拒绝死亡、q4 完成奖励后存活，修前燃血例退出 1、修后均通过；这些分支人工改了恢复后的内存属性，只证明热态边界，不作严格冷恢复证据。剑修第三幕既有合法前序低资源燃血/死亡严格冷恢复专项另退出 0。灵泉葫芦的每回合回血此前漏于筑基任务/因果，`noncombat_foundation_body_quest.gd` 和 `noncombat_body_high_realm_karma.gd` 各有修前失败、修后通过的来源效果例；共用恢复器现按境界读取已解锁体修技能，金丹/元婴 `body_regen` 每轮 +1，不再把 hp=1 的回响误判燃血。可复活法宝参与这类新选择的终态仍无实现，候选会拒绝写盘并保留原选择，不能称全分支完成。

最终局部独立只读复审核对来源境界顺序、恢复调用次数、选择来源收据、提交时机和高境界效果，独立重跑高境界专项退出 0，未发现新的确定 P1/P2。新增后本机体修四幕、自然路线、剑修终章、剑修低资源与首张炼气因果回归退出 0。总门禁尾段从 `noncombat_foundation_body_quest.gd` 继续运行，结果以 `artifacts/godot-migration/full-gate-tail-body-2026-10-28.log` 为准；当前不能把未结束门禁写成通过。

## 2026-10-27 N6 筑基剑道传承第三幕至终章（专项通过；N6 未签收）

| Issue | 来源与断点 | 现有证据 | 结论 |
| --- | --- | --- | --- |
| ISSUE-N6-FOUNDATION-03 | `data/quests/sword_legacy.json` 的第三幕左右选须先进入来源剑冢预警与待战合同；胜、败、逃按原分支结算，胜利后方可到第四幕，失败保留重试，`down` 可放弃。低资源失败和燃血胜利还必须与死亡/转世边界一致。 | `noncombat_foundation_sword_trial_contract.gd`、`_outcomes.gd`、`_seed_delay.gd`、`_low_resource.gd`、`_live_battle.gd` 均退出 0；真实桌面可冷恢复第三幕待战合同、进入剑冢战场并撤离返回。胜败逃规则由认证战果专项覆盖；第三幕真实桌面胜利终态仍未单独完成。独立只读复审重跑结算与低资源专项通过。 | 局部 VERIFIED；不据此宣称整场真实按钮胜利已验。 |
| ISSUE-N6-FOUNDATION-04 | 第四幕左右选须从 `progression:acquisition_opportunities` 先判特殊传承再按加权奖池抽取技能或法宝，同次结算来源选择效果、`rewardOnComplete`、`factionRewards`、延迟因果和完成回执；玩家选择前应看到实时奖池，选后应看到实际所得。 | `noncombat_foundation_sword_completion.gd` 从自然第三幕胜利到第四幕，验证特殊条件、自然加权、私取法宝、道心/修为/气运、两向选择因果与完成回响、声望、故障写盘回滚、一次性限制、带测试条件的严格冷恢复和真实桌面按钮→信号→自动续卡。正常 Windows OpenGL [1280×800 选择](../artifacts/godot-migration/foundation-sword-completion/choice_1280x800.png)、[1920×1080 选择](../artifacts/godot-migration/foundation-sword-completion/choice_1920x1080.png)、[1280×800 领取回执](../artifacts/godot-migration/foundation-sword-completion/receipt_1280x800.png) 已目视；来源卡图、奖池百分比和所得可见。独立只读复跑 exit 0，未见确定产品 P1/P2。 | 当前所查终章分支专项通过；正常槽位无测试随机覆盖的完整长局仍待验。 |

机缘 RNG 初始种子及进位随决策保存，来源 SHA 固定；专项的左/右固定 roll 仅用于可复现地覆盖候选，另有未覆写的机缘原生随机种子冷回放。更早的剧情夹具使用未持久化的测试随机覆盖，因此直接交给正式槽位冷启动会被严格历史校验拒绝；此结果不能当作普通玩家存档故障，也不能证明正常槽位恢复。第四幕真实 UI 已从恢复后的领域状态点击；完整从新档一路逐击胜利、其他四条筑基任务、十二线程、全量媒体和 Windows 导出包仍待完成。完整 Godot 尾段门禁见 `artifacts/godot-migration/full-gate-tail-resume7-2026-10-27.log`，输出 `RUNTIME_MIGRATION_TAIL_PASS data=74 art=837 audio=32`。`godot/` 当前未跟踪，以上以来源指针、运行测试和截图复核，不以 Git diff 冒充精确变更证据。**N0–N11 共 12 阶段、N6 均未整体签收。**

## 2026-10-27 N6 荒村第三幕真实战场（专项通过；N6 未签收）

`thread_ab_village_3` 左右选择均由真实剧情第三幕产生空 `encounterId` 的待战请求，敌人是顶层 `resentment_shadow_qi`、无计划图、依次施加虚弱、攻击、护盾。此前剧情层只能持久保存预警和接收测试代入的胜败逃；`BattlePlanResolver` 拒绝此来源，`CombatDomain` 未装载其顺序意图，两个战场目录的 `runtimeScene` 为空。现仅对认证的荒村第三幕左右请求装载来源敌人、当前牌组与两套作者展示，`main.gd` 进入同一来源帧舞台，胜败逃由玩家按钮的实际战斗终态回原剧情。

`node tools/capture_noncombat_abandoned_village_source.js` 从浏览器生产 VM 的干净 seed36 路线保存左支胜败逃逐操作状态、右支热态与冷态开战/前两轮；14 个源码/数据 SHA 写入 `abandoned_village_source.json`。Godot `noncombat_abandoned_village_live_loadout.gd` 左右来源计划、敌人、牌组、虚弱和第二轮攻击专项修前退出 1、修后退出 0。`noncombat_abandoned_village_live_battle.gd` 从持久种子和公开选择建档，由桌面自行冷恢复；左败、右逃经真实回合/反应/撤离/返回剧情按钮，各自冷档一次性结算，退出 0。`noncombat_abandoned_village_live_victory.gd` 在不同洗牌下用真实卡牌和闪避/格挡完成胜利，首次故障写盘不改变待战字节，重试后冷档确认第三幕胜利回执、重复提交拒绝；正常 Windows Vulkan 1280×800、1920×1080 运行与两图目视均通过。网页来源 `combat:vfx` 显示首轮虚弱四帧；桌面初版只装载未播放，真实 UI 回归修前退出 1。现虚弱/伤害/护盾来源特效随演员接触点播放，短时 `noncombat_village_stage_vfx_contact.gd` 与左右真实桌面重跑核对虚弱首帧和敌人施法帧重叠，退出 0。当前最新全量 Godot 门禁从 `noncombat_first_karma.gd` 续跑，结果以持久日志 `artifacts/godot-migration/full-gate-tail-2026-10-27.log` 为准。

**仍待解决**：网页自身的 `migrated_presentations.json` 把井下石室与黑雾怨念的第三幕画成室外村道/古树与蒙面人，并用不同提示声称左右有不同战术，而两支浏览器真实敌人和前两轮规则相同。Godot 现忠实消费网页展示，战场目录 `approvedForFinalArt=false`；场景叙事与战斗美术/提示仍需来源修订和重新取证，不能作为终审画面。网页第三幕卡冷恢复还会丢临时迁移展示：右支热态发作者专属虚弱特效，冷态退回通用特效；Godot 持久右支仍使用专属展示，此差异已在 fixture 留证，待来源恢复规则统一。当前未完成其它故事/遭遇、全量媒体、跨引擎整场逐牌数值对照与 Windows 最终导出包。`godot/` 未跟踪，独立审查可核当前生产者/消费者但无法以 Git diff 证明精确改动行。**N6 与 N0–N11 共 12 阶段均未整体签收。**

## 2026-10-27 N6 同门比试真实战场（专项与独立复审通过；N6 未签收）

`q_fellow.right` 是普通牌内嵌战斗：敌人来自卡片顶层 `enemy`，`encounterId=null`，`sect_sparring_qi` 敌人模板只有按顺序轮换的 `buff sword_intent+1 → attack 1`，没有 `planGraph`。原剧情层早已持久保存右选、预警和胜败逃合同，但 `BattlePlanResolver` 先前拒绝空目录 ID，`CombatDomain` 强制计划图，桌面目录 `battlefield_q_fellow_native_v1` 未建。`noncombat_q_fellow_live_loadout.gd` 从自然抽牌后的待战冷档要求来源计划和当前牌组，修前退出 1；现在解析认证的顶层敌人快照、按来源意图推进并结算敌方剑意增伤，来源论剑台/同门师兄帧与剑修动作装入 `duel_stage_fellow_2d`，专项退出 0。`tools/capture_noncombat_q_fellow_source.js` 重新记录来源三结果与败退分支逐步状态，9 个来源 SHA 与当前网页源码一致；Godot 对照首意图、第一轮增益、第二轮剑意消耗及 2 点攻击。不同自然路线的玩家开场气血并未宣称跨引擎一致。

`noncombat_q_fellow_live_battle.gd` 用持久种子和仅会写入 `normalFlow` 的普通抽卡固定值，经公开剧情选择建立待战档；故事界面凭 `save_path` 自行冷恢复，再按真实回合/反应、撤离、返回剧情按钮分别完成败与逃。验证原图、敌方攻击作者帧、无演出缺帧、冷恢复和重复战果拒绝，独立复跑退出 0。首次用未持久化的集市/命盘/涟漪/天机随机数覆盖建档，桌面自动读档会隔离该测试档；此证据已弃用，最终专项不再设置那些覆盖。`noncombat_q_fellow_live_victory.gd` 同样从桌面自动冷恢复，用真实卡牌/回合/反应按钮获胜，写盘失败保持原待战字节、重试后一次性回执冷恢复；独立复跑退出 0。既有 `noncombat_q_fellow_outcomes.gd` 提供网页胜败逃的剧情奖惩比对，不把桌面专项解释为两端整场逐牌同轨。正常 Windows Vulkan 的 [1280×800](../artifacts/godot-migration/q-fellow-live-battle/q_fellow_1280_idle.png) 与 [1920×1080](../artifacts/godot-migration/q-fellow-live-battle/q_fellow_1920_idle.png) 开场已目视，论剑台、双方角色、意图、手牌与撤离操作完整；1920 手牌偏小待 N9。战场仍是来源帧候选，`approvedForFinalArt=false`。新版全量门禁尾段仍在运行，N6 六任务/十二线程和最终 Windows 包远未完成。

## 2026-10-27 N6 白狐第三幕猎狗战桌面生产者（专项通过，独立复审通过、全量门禁中；N6 未签收）

| Issue | 玩家合同与来源 | 已确认断点与下一证据 | 状态 |
| --- | --- | --- | --- |
| N6-WHITEFOX-LIVE-01 | 自然到达 `q_whiteFox_3` 后选迎战、确认预警，应从已持久的任务待战请求以当前牌组对抗猎狗群；胜利才结束任务并种下来源因果，败北或撤离保留后续重试，终态由同一桌面战斗返回剧情。来源 `data/quests/white_fox.json` 在左选内定义 `hound_pack_qi`、`combatPresentation` 战场/犬群帧与三条按顺序行动的意图；网页版 `DeckCombatSystem._createEnemy/_generateEnemyIntent` 对无计划图敌人按原模板意图轮转。 | 修前 `BattlePlanResolver` 拒绝 null catalog ID，`CombatDomain` 强制计划图，桌面入口未选猎狗来源舞台。现从已持久任务选择解析来源计划，按猎狗模板顺序意图作战；场景消费来源战场、犬群帧和虚弱特效。独审又发现战斗域曾硬限第一世；二世真实冷档启动红例退出 1 后修正。旧跨世回归还漏确认定期遭遇的回应卡，测试路线按当前公开选择修复。 | 首世四修来源意图与初态、剑修撤离/战败、丹修胜利的真实按钮链、冷档一次性结算及二世认证计划装载专项 exit 0；正常 Vulkan 三图已目视。独立复审通过、全量门禁中。 |

**本批最新证据（以下调查段落为修前基线）**：`node tools/capture_noncombat_whitefox_hound_intents_source.js` 从浏览器生产入口采得四修 16 个状态；`noncombat_whitefox_live_loadouts.gd` 对照四修当前牌组、开战初态和各三轮无牌敌方行动，exit 0。`noncombat_whitefox_live_battle.gd` 用自然剑修冷档经 `OpeningScene → LaunchBattle` 开战，核对来源犬群狂吠姿态和虚弱 VFX，再撤离、返回剧情、冷档重放及假敌人/未认证计划拒绝，exit 0。`noncombat_whitefox_live_outcomes.gd` 从丹修真实按钮胜利、剑修真实按钮战败分别回剧情，验证胜利才结任务、失败写盘回滚重试及重复战果拒绝，exit 0。`noncombat_whitefox_rebirth.gd` 的第二世真实待战计划与 `CombatDomain` 装载修前失败、修后完整胜败逃旧回归 exit 0；第二世三结果仍由测试构造，不称二世桌面终态已验。`capture_whitefox_battle.gd` 正常 Windows Vulkan 输出 1280×800、1920×1080 开场和 1280×800 狂吠/弱化三图于 `artifacts/godot-migration/whitefox-live-battle/`，画面可见来源战场、犬群、手牌和操作，1920 手牌偏小待 N9；`approvedForFinalArt=false`。资源同步后 74 数据/837 图/32 音频，`validate_noncombat_asset_coverage.py` exit 0；网页内容、135 项基本规则与 3880 个静态资源检查 exit 0。工作树 `godot/` 未跟踪，精确 Git 变更 diff 不可得，本批审计按文件入口/消费者及运行证据核对。四修全部桌面胜败逃组合、二世桌面战斗终态、战斗伤害/防御 VFX 完整消费、Windows 导出包及 N6 六任务十二线程总验收仍待后续批次。

来源预查：调用 `capture_noncombat_whitefox_battle_source.js::openWhiteFox('sword')` 从原生产 VM 自然到达猎狗战后，不出牌、连续三次公开 `endTurn/chooseReaction(TAKE_HIT)`：开场意图 `debuff weak+1`、敌意图游标 1；第一回合后玩家弱 1 且第二意图 attack 1、游标 2；第二回合后弱 0、气血 3→2，第三意图 attack 2、游标 3；第三回合后气血 2→1，下一意图回到 debuff、游标 4。此为规则回归的来源边界，不等于桌面已实现。当前运行包的猎狗素材仅有战场背景，任务卡列出的犬群动作帧和 VFX 尚未入包。

同一生产入口四修初态复查：剑修 HP 3/4、防壁 1、当前牌组 6；法修 HP 4/4、防壁 0、牌组 6；体修 HP 4/4、防壁 1、牌组 6；丹修 HP 4/4、防壁 1、牌组 6。四修开局都显示同一来源 `debuff weak+1` 意图并把顺序游标置 1。`noncombat_whitefox_live_battle.gd` 已从剑修自然剧情待战冷档建立修前回归，当前在 `BattlePlanResolver.inspect_request` 的空 catalog ID 处退出 1；这份红例不作为桌面已能开战的证据。任务卡展示数据引用的 20 个图片路径中，仅战场与游侠人物原图已有 Godot 副本，其余 18 个源图在网页仓库存在、尚未同步。

补充 `noncombat_whitefox_live_loadouts.gd`，从现成的八条网页生产战果 fixture 中选四修各一条真实胜利的战前 `battle` 状态，经 Godot 自然剧情与冷档入口核对计划牌组、玩家战斗初态和猎狗模板/首意图，并按新来源轨迹对照每修三次无牌敌方行动、虚弱保留/衰减、气血与下一意图；道心抵抗使用来源 VM 实际掷值，原文件 SHA 不符会拒绝作为预言机。修前仍在同一空 catalog ID 断点退出 1，尚未将浏览器战果冒称桌面战果。

桌面红例进一步要求犬群狂吠时实际显示任务卡的 debuff 姿态帧和弱化 VFX 四帧中的画面，再核对战斗域弱 1 及撤离回执；资源存在、纹理可加载或仅展示背景都不足以通过这一断言。

新增可复跑网页生产轨迹 `tools/capture_noncombat_whitefox_hound_intents_source.js` → `godot/tests/fixtures/whitefox_hound_intents_source.json`：四修自然到战斗后只调用公开 `endTurn/chooseReaction(TAKE_HIT)`，每修开场加三次敌方行动，共 16 个状态快照，脚本运行输出 `WHITEFOX_HOUND_INTENTS_SOURCE_PASS paths=4 steps=16`。三次行动后剑/法/体/丹 HP 分别为 1/2/2/1，弱状态均已从第一行动后的 1 自然衰减为 0，第四次待行动意图均回到 `debuff`、游标 4。源 VM 的随机函数只在公开反应调用期间被动记录，未注入状态；每次攻击的道心抵抗掷值与后续洗牌掷值都在输入记录，桌面回归使用对应抵抗掷值。六份来源 SHA 随轨迹记录。

实施边界已缩到实际断点：`BattlePlanResolver.inspect_request` 目前把 null `encounterId` 强转字符串，随后仅认教学/山径并查 catalog；应从已认证的 `pendingResolution` 和 `StageRouter.resolve_choice` 构建白狐来源计划，保留请求里的 null ID。`CombatDomain` 装载、出牌记忆、结束回合、反应、开新回合都直接取 `planRuntime`；猎狗模板没有 `planGraph`，需按来源 `intents` 顺序推进并保留敌方刚施加的虚弱到下一玩家回合。`main.gd`、来源舞台、战场目录与资源同步目前只会选 catalog 遭遇；需让原任务展示画面、犬群姿态和弱化 VFX 在实际桌面事件中消费。既有 `NoncombatBattleGateway` 已保存并验证任务原选择、当前牌组、来源哈希和一次性战果，原则上复用该权威入口。

## 2026-10-27 N5 山径第二战真实桌面生产者（独立专项 VERIFIED，总门禁运行中；N5 未签收）

| Issue | 玩家合同与权威链 | 修前反证与实施边界 | 验收状态 |
| --- | --- | --- | --- |
| N5-MOUNTAIN-LIVE-01 | 首战胜利后，四修从原 `q_mountain_shadow_approach` 左选、确认预警进入第二战；玩家应以当前七张牌及按修途平衡的巡山石影开战，胜败逃由战斗终态回原剧情，一次写盘且冷恢复。入口 `noncombat_opening_ui.gd` → `BattlePlanResolver.resolve_persisted` → `CombatDomain.load_persisted_request` / `main.gd` → `NoncombatDomain.submit_battle_result`。`RunSession` 的 `BATTLE_PENDING/pendingResolution/playerSnapshot` 为权威待战状态。 | `noncombat_mountain_battle.gd` 的来源结算六例与冷存档属于剧情合同，不能证明战斗生产者。新 `noncombat_mountain_live_battle.gd` 用自然剧情状态冷恢复，修前在剑修 `launchAuthorized` / 敌人 / 牌组检查处退出 1。解析器、战斗域及桌面入口已接山径来源请求与当前牌组，来源场景/帧入包。最终专项四修出真实按钮链、胜败逃、一写盘、冷档、重复回执、伪造敌人拒绝、初始意图和失败写盘字节回滚，独立复跑 exit 0；`noncombat_mountain_integrity.gd` 的素材漂移/跨战伪造/奖励一次性亦独立 exit 0。 | 独立 VERIFIED（当前树四修所查终态）；全量门禁运行中。 |
| N5-MOUNTAIN-CARD-ACTION-02 | 山径剑修通过 `main.gd` 的牌按钮进入 `duel_stage_source_2d.gd::present_action`，网页版 `_resolveSemanticActionContract` 对匹配卡 ID/动作族优先选 `action_presentations.json::cardActions`；舞台须播放对应作者帧和 cue，战斗权威状态仍归 `CombatDomain`。 | 独立反证发现舞台只取通用族与 variant。新增 `noncombat_mountain_card_actions.gd` 修前因 `sword_edge` 缺作者帧/cue 退出 1；`_source_paths` 检查四张牌的来源帧，`bind_stage_context` 对四张剑修卡以 `cardActions` 覆盖同族 key。修后专项退出 0，核对四张牌首帧、时长、起手/接触 cue，并实跑 `sword_followthrough` 动作起手/接触。 | 独立 VERIFIED，专项 exit 0；18 动作帧与 4 目录项 SHA 一致。 |
| N5-MOUNTAIN-SPELL-DAMAGE-03 | 法修从真实存盘山径请求带入奖励 `spell_nuke`；来源 `DeckCombatSystem.prepareCardDamage` 对 5 基础伤害先乘封印 3，再加五行轮转 1，敌防护另算。`CombatDomain.play_card` 消费 `pathCombatState.cardSequence` 与 `playerStatus.spell_seal`，把伤害写入 `enemy.hp`。 | 独立反证发现 Godot 先把轮转 1 加进基础再乘 3。扩展 `noncombat_mountain_spell_rewards.gd` 在持久来源请求后设公开出牌边界与前两张不同牌，敌人 100 HP/0 防；修前剩 82（18 伤）退出 1。`_damage_enemy` 现先算条件倍率再加流派加成；修后剩 84（16 伤）退出 0，原抽牌、反噬与致死优先级同项通过。 | 独立 VERIFIED，专项 exit 0（16 伤、抽牌、反噬、致死）。 |
| N5-TWO-BATTLE-UI-04 | 丹修从真实写盘的首战待战点，经同一个 `OpeningScene` 的战斗/剧情按钮连续打完首战、选择奖励和山径预警、打完第二战；`battle_finished` 两次交给同一 `RunSession`，冷档中有两个不同来源的胜利回执。 | 既有山径专项用合法合成首战回执建立前置，因此不能证明连续 UI 链；这是证据缺口而非已确认的运行缺陷。新 `noncombat_two_battle_pill_ui.gd` 不注入战斗状态或首战结果，首战与第二战均由卡牌/回合/反应/返回按钮推进，中间由奖励和山径 Choice 按钮推进；独立复跑 exit 0，冷档 `battleResultHistory` 恰好两条胜利，重复提交均拒绝。 | 独立 VERIFIED（丹修两胜，首战前教学路线由领域 API 布置）。 |

来源是 `data/combat/encounters.json`、`encounter_presentations.json`、`action_presentations.json` 和 `NoncombatBattleGateway._mountain_resolution`。不用静态遭遇表中的 7 HP 敌人替代来源按四修平衡的敌人；不借首战木人背景。资源同步和覆盖专项为 74 数据、819 图、32 音频；山径来源图与当前牌图的别名经 `RuntimeDataRegistry.texture_for` 解析，32 个所查战场路径及 22 个卡动作/目录项的源、运行包、manifest SHA 独立核对一致。正常 Windows Vulkan `capture_mountain_battle.gd` 已输出四修各 1280×800 与 1920×1080 开场、剑修 1280×800 接触帧，专项 exit 0；九张位于 `artifacts/godot-migration/mountain-live-battle/`，独立审查逐张核尺寸和修途身份，主角、石影、当前手牌及操作区可见，未见明显裁切；剑修出招图仅证明作者动作帧与扣血事件同场，剑尖在像素上尚未触及敌人。1920 下手牌相对场景偏小，留给 N9 屏幕表现阶段评估。战场仍为非最终美术候选，`approvedForFinalArt=false` 保留。四路线×三结果完整组合、主观听感和 Windows 导出包仍未由本批证明。丹修两战连续 UI 的 `pressed.emit()` 验证按钮回调，不证明实体鼠标命中与画面布局。

## 2026-10-27 N5 丹修首战逐牌按钮与败北回剧情（局部 VERIFIED，N5 未签收）

| Issue | 玩家合同与入口 | 可复核证据及边界 | 独立审查 |
| --- | --- | --- | --- |
| N5-PILL-UI-01 | 先前丹修毒伤胜利专项由测试直接调用 `CombatDomain.play_card`，只能证明规则与舞台回调，不能证明玩家当前手牌按钮能逐张出牌。 | `noncombat_first_pill_victory_ui.gd` 现从 `hand_row` 当前可用 Button 的 `source_card_id` 找牌并 `pressed.emit()`；通过 `HandUI.card_selected` 和 `main._play_card` 进入战斗域。自然冷档 `LaunchBattle`、真实卡/回合/反应/返回按钮、毒伤胜利、原 treasure 音、冷读档及重复回执拒绝 headless 退出 0；独立复审重跑并核对入口，未见确定 P1/P2。这里验证按钮回调，不称真实鼠标命中或画面像素。 | VERIFIED（按钮/毒伤终态） |
| N5-PILL-UI-02 | 丹修首战败北此前仅由规则域构造，缺桌面玩家动作→敌方致死→剧情回执。 | `noncombat_first_pill_defeat_ui.gd` 从自然冷档入来源战场，按当前手牌 Button 出 `pill_ember` 引发敌方攻击，经回合/TAKE_HIT 按钮真实战败，终态音核对 `heart_beat.mp3`，再按 ReturnToStory，冷读档成功且拒绝重复提交。headless 与正常 OpenGL 均退出 0，独立复审核对作者 cue、音频路径和真实终态并退出 0。起始牌 3 张 ember/6 张总牌，初手 5 张保证可出；不声称视觉终帧、故障写盘回滚或导出包已验。 | VERIFIED（按钮/败北/心跳音/冷档） |

这两项补齐丹修首世教学战桌面胜败入口，与既有撤离/失败写盘重试专项一起覆盖三种结果；范围仍限第一生命原教学战。音频的主观听感与 Windows 导出、其它生命和其余遭遇仍须独立完成。

## 2026-10-27 N5 法/体首世桌面胜败回剧情（局部 VERIFIED，N5 未签收）

| Issue | 玩家合同与修前证据 | 当前实现链和证据 | 独立审查 |
| --- | --- | --- | --- |
| N5-SPELL-BODY-TERMINAL-UI-01 | 先前法/体首战只有桌面出牌与撤离回传，胜败各自回剧情依赖 `CombatDomain` 规则驱动专项，缺真实场景中的完整按钮链。新增专项首版只打攻击牌，法修因低血在敌血仍为 4 时战败并退出 1；战败路径若零出牌，敌方真实计划进入防守，8 回合无败北，同样退出 1。 | `noncombat_first_spell_body_terminal_ui.gd` 从法/体自然首世冷档经 `LaunchBattle`，用卡牌按钮按来源封印/沉桩连携出牌，回合与反应按钮推到 `VICTORY/DEFEAT`，读取 `ReturnToStory` 后提交结果并冷读档，重复回执拒绝。战败分支出一张护盾牌以触发真实敌方攻击；修后两路径×胜败 4 案例 headless 与正常 OpenGL 各退出 0，独立复审两次不同洗牌 headless 均退出 0。此专项验证桌面回路，不宣称跨引擎逐牌数值同轨、终态画帧/听感或 Windows 导出包。 | VERIFIED（所查按钮/终态/冷档链） |

入口—状态链为 `noncombat_opening_ui.gd::LaunchBattle` → `main.gd` 的卡按钮/回合/反应 UI → `CombatDomain` 真实终态 → `main.terminal_result` → `RunSession` 一次性写盘与冷恢复。结果没有从测试手工注入。法/体来源规则逐牌来源对照及撤离/写盘失败恢复沿用已验收专项；本批增加桌面胜败互动证据，不冒称整场视觉、声音、源端 RNG 或导出包都已验收。

## 2026-10-27 N5 四修首战音频事件相位（局部 VERIFIED，N5 未签收）

| Issue | 玩家合同、根因与权威链 | 修前失败及当前证据 | 独立审查 |
| --- | --- | --- | --- |
| N5-SWORD-AUDIO-01 | 网页 `DeckCombatSystem._resolveSemanticActionContract` 对剑修起始牌优先取 `cardActions`，缺专属动作的 `sword_guard` 取 `paths.sword.guard`；`AudioManager` 把实际语义相位映到 `sfxCues` 和 `path_identity.json` 的运行音频。Godot `duel_stage_hd2d.gd` 已有角色动作与 `contact_frame`，但无战斗音频消费。 | 新专项由剑修真实付费预警冷档 `LaunchBattle` 入 HD2D 场，修前因缺 `SourceActionSfx/SourceContactSfx` 退出 1。舞台现从作者卡牌/路径/敌方动作读 cue 和音频目录，演员接触键触发攻击/玩家防守/敌攻音。追斩、防守、敌攻及第二回合真实 `RECOVER` 敌防守专项在 headless/正常 OpenGL 退出 0；旧剑修 live battle、舞台集成、战场目录与完整 M0 回放退出 0。 | VERIFIED（所查来源 cue） |
| N5-SWORD-AUDIO-02 | 初版把 JSON 中有 `impact/reactionResolved/actorDefeated` 字段误当该视觉步骤必发声；网页伤害后的 `hurt` 是 presentation-only，玩家 reaction 与敌方 defend 只发 `actionStarted`，敌方 collapse 视觉步骤不播 heartbeat，胜利 `combat:victory` 才播 treasure。 | 独立初审指出多余命中、格挡和败亡音；专项改查并行受击静音后先退出 1，修后剑修舞台仅在真实相位有 cue 时播放，并从胜利终态播 `sfx_treasure`。专项经真实第二回合 `RECOVER` 核对敌防守只起手；`play_full_battle_ui.gd` 来源 12 步最后由 `sword_probe` 直接击杀后，headless/正常 OpenGL 均断言 treasure 原流，独立复跑退出 0。 | VERIFIED（所查运行链；播放次数仅静态防重） |
| N5-SOURCE-AUDIO-05 | 同一相位错误也影响法/体/丹 2D 来源舞台：受击 sidecar 额外播 `sfx_hit`，丹修 `pill_recycle` 只有 `gain_qi` 却多播状态音，毒伤胜利不是 `CARD_PLAY` 而漏胜利音。 | 三修音频专项增加“攻击演完后未重播受击音”，修前法修退出 1；丹修回气自然冷档专项修前在额外 `sfx_pl_03_state` 退出 1，现根据已结算 effects 的伤害或正量防壁/治疗/状态决定是否播接触音；随机缺牌后真实回合补抽分支也退出 0。丹修毒伤胜利的真实桌面专项检查 `get_treasure.mp3`；四项音频/终态专项 headless 与正常 OpenGL 均退出 0，独立复审命中回气缺牌补抽且未见确定 P1/P2。 | VERIFIED（所查首战相位） |

权威链为真实冷档 `LaunchBattle` → `main.gd::_on_combat_changed` → 对应舞台从 `action_presentations.json` 与 `path_identity.json` 读取来源 cue/音频；终态胜利由 `main.gd` 通知舞台，等当前展示队列结束后播 treasure。声音不改战斗伤害/真元和持久战果；网页无对应语义事件的视觉受击不制造第二道声音。代码以 queued/played 标记防重；现有运行专项未计数播放调用，所以只声明防重代码已复核，不声称严格一次播放已实测。主观听感、整场混音与 Windows 导出包仍须另验。相关 Godot 文件未纳入 Git，本批不能以 `git diff` 作相对基线证据。

## 2026-10-27 N5 法/体/丹来源帧战场音效（触发链候选，N5 未签收）

| Issue | 玩家合同与根因 | 修复前反证、当前证据和边界 | 独立审查 |
| --- | --- | --- | --- |
| N5-SOURCE-AUDIO-01 | 网页 `DeckCombatSystem` 按 `action_presentations.json` 的 `sfxCueId` 发起手、命中和状态事件，`AudioManager` 等视觉动作时钟再播放 `path_identity.json` 的运行音频。Godot 法/体/丹首战已播放来源帧，但 `duel_stage_source_2d.gd` 仅有图像/接触信号，没有音频播放器，进入战场后对应动作静音。 | `noncombat_first_source_stage_audio.gd` 从三条自然首世冷档进入战场，修前在法修的“播放器缺失”处退出 1；舞台现从两份作者数据关联 cue/runtime，预装音频并按动作帧时钟播放。初版专项期望和时钟约束有漏洞，已按下三项反例补正。 | VERIFIED（所查三修起手/接触/状态触发） |
| N5-SOURCE-AUDIO-02 | 网页 `_deriveCardSemanticPresentation` 先判伤害、再治疗、再护盾；`spell_ward`、`body_stance`、`pill_catalyst` 属 guard。初版 Godot 仅按 `type=skill` 选 skill 帧和音，法修护符误播法修 skill 音。 | 纠正专项期望后，法修在“guard 起手音未播放”处退出 1。舞台现在按原牌效果优先级映射 attack/skill/guard，专项核对三修护盾牌的来源首帧、起手与状态音；丹修催化若不在初手，专项经真实回合按钮补抽，缺牌分支本机及独立复审均命中并退出 0。 | VERIFIED |
| N5-SOURCE-AUDIO-03 | 网页 `DeckCombatUI` 的近战 `visualContact` 在接触帧**开始**触发；初版 Godot 等到含接触的整帧结束才发音。独立审查估算体修玩家/敌人分别晚约 90/125 ms；修前专项实测体修敌方在 389 ms 才接触并退出 1。 | 舞台对近战按来源 `impactFrameIndex`（缺省中帧）进入该帧即发接触音，投射物按原 `impactAtMs` 在帧中分段计时。复审指出只在接触时检查当前贴图会使旧延迟假绿；现专项从 `action_started` 单调时钟量到接触事件，体修玩家/敌人按作者前帧 250/265 ms 给 315/330 ms 上限，并同查接触帧贴图。缺动作起始信号时先退出 1，修后 headless 与正常 OpenGL 退出 0；独立复审确认旧 340/390 ms 会失败。 | VERIFIED |
| N5-SOURCE-AUDIO-04 | 网页 `_resolveSemanticActionContract` 将 `variantsBySourceId` 的牌专属动作合并进通用 family；首世法修 `spell_ward` 与体修 `body_stance` 各有 5 张专属帧，初版 Godot 仅加载通用 4 帧 guard，资源同步也遗漏这 10 张。 | 专项改以作者变体首帧为期望后先在法修退出 1；同步脚本现按起始牌加入 10 张原帧，舞台按卡 ID 选合并后的动作，接触检查使用变体显式 `impactFrameIndex=3`。修后 headless/正常 OpenGL 退出 0，素材覆盖为 74 数据、791 图、32 音频；独立复审核对 10 张原件、运行副本和清单 SHA/字节一致。 | VERIFIED |

权威链为真实 `LaunchBattle` → `main.gd` 选择来源舞台 → `CombatDomain.changed` → `duel_stage_source_2d.gd` 按原动作 `sfxCueId` 和原音频 runtime ID/路径播放 → Godot 音频播放器。独立复审核对 32 个来源音频及新 10 张专属帧的源文件、运行副本与清单 SHA 全匹配；修后法/体/丹桌面撤离专项及丹修毒伤胜利回剧情专项均退出 0。只给来源帧舞台接线，旧剑修 HD2D 舞台及其它遭遇仍须另验；本批检查播放状态、源路径与接触时钟，不把它当作主观听感、整场混音或 Windows 导出包音频验收。未新增第二份手工音频映射，也没有以一段通用命中音替代三修作者 cue。`data/audio/path_identity.json` 对体/丹扩展的来源状态仍标 `pending_independent_audit`，本批接线不冒称其原声音资产已完成最终审听。

## 2026-10-27 N5 丹修首世来源战场接入（可玩候选，N5 未签收）

| Issue | 断点与实现 | 可复核证据和边界 | 独立审查 |
| --- | --- | --- | --- |
| N5-PILL-STAGE-01 | 首世丹修已能持久保存 `enc_trial_pill_poison` 待战请求，但来源战场目录为 `unbuilt`、`runtimeScene` 空，`BattlePlanResolver` 因 `sceneAvailable=false` 拒绝开战。现用 `duel_stage_source_2d.gd` 按丹修来源回廊、主角/炉灵身份、6 张起始牌和 S1 动作帧绘制；仅首世丹修教学战通过来源请求及场景资源检查后放行。 | `noncombat_first_pill_live_battle.gd` 修前退出 1（战场未授权）；修后真实冷档 `LaunchBattle`、回气出牌动作、撤离、结果写盘失败重试、冷恢复与重复结果拒绝均退出 0。`noncombat_first_pill_outcomes.gd` 从来源请求分别由真实规则生产毒伤胜利和战败，再各向剧情层提交一次，退出 0；这不是桌面鼠标逐步完成胜败。 | VERIFIED（所查桌面撤离及规则胜败链） |
| 来源素材与画面 | `sync_runtime_content.py` 新增丹修首战所需的 46 张来源图片；连同先前已入包的场地，共 47 个唯一必需路径，同步后为 74 数据、781 图、32 音频，原路径和 SHA 写入同一来源清单。主角 `actorCard` 用于资源就绪校验，舞台待机实际显示攻击动作第一帧，不称该身份图已被绘制。 | 素材覆盖 `NONCOMBAT_ASSET_COVERAGE_PASS images=531 animated=3 audio=32 copied=781`。Windows 正常 OpenGL 图形渲染 [1280×800 开场](../artifacts/godot-migration/first-pill-battle/pill_1280_idle.png)、[1920×1080 开场](../artifacts/godot-migration/first-pill-battle/pill_1920_idle.png)、[1280×800 出招](../artifacts/godot-migration/first-pill-battle/pill_1280_contact.png) 均已目视检查，主角、炉灵、回廊、卡牌可见且无明显裁切；截图不证明整场动画质量。 | VERIFIED（47 路径 SHA 与所查三帧） |

权威链为 `noncombat_opening_ui.gd::LaunchBattle` → `BattlePlanResolver.resolve_persisted` → `main.gd` 来源舞台 → `CombatDomain` 终态 → `RunSession` 原子战果。备选的旧剑修舞台回退会错误呈现对手和场地，已弃用。丹修、体修、法修首战桌面专项、丹修规则/胜败专项及剑修完整回放最终均退出 0；新增三项专项已登记 `validate_godot_runtime.py`，全量脚本本批未取得完整通过结果。其他生命、其它遭遇、整场跨引擎逐回合同轨、战中中断恢复、音频和 Windows 导出包仍须继续完成。

独立只读复审复跑丹修桌面撤离/原子回传、规则胜败专项，逐一核对 47 个来源图片的源文件/运行副本/清单 SHA 及两份网页 fixture 的四源哈希，目视核查三张截图，未发现确定 P1/P2。桌面逐步点击胜败、整场动画、战中中断和导出包仍为 UNPROVEN；本批未以 Git 差异作验收，因为相关 Godot 文件尚未纳入 Git。

后续补充 `noncombat_first_pill_victory_ui.gd`：真实桌面场景的丹修卡牌经战斗域逐张出手，回合/反应按钮由界面触发，毒伤击杀后读取界面的 `ReturnToStory` 可见且可用，返回后冷档的胜利回执拒绝重复提交。由于开局洗牌随机，测试按当前手牌选择安全丹牌并在敌人剩余气血不超过 2 时保留毒伤终结；连续四次实跑均输出 `NONCOMBAT_FIRST_PILL_VICTORY_UI_PASS terminal=true poison=true return=true receipt=true`，已登记总门禁。独立只读复审再跑退出 0，查看最新 v2 档确认为 `BATTLE_RESULT_PENDING`、唯一胜利历史、待战槽清除及对应 `battle:<owner>` 胜利回执，判定本次场景/按钮/写盘链 VERIFIED。此测试仍通过战斗域调用出牌，不冒称实体鼠标逐牌操作或全场图形表现。

## 2026-10-27 N5 丹修首世教学战规则预备（历史记录：场景接入前）

玩家合同：自然首世丹修到 `enc_trial_pill_poison` 后，回气、催化、丹火、敌行动前毒伤及丹牌疗伤应按网页版规则结算；毒伤杀敌须向桌面界面公布已完成的胜利状态。权威链为 `noncombat_domain.gd` 持久待战请求 → `BattlePlanResolver.resolve_persisted` 认证 → `CombatDomain.load_first_teaching_request/play_card/choose_reaction` 唯一战斗状态 → `main.gd::_on_combat_changed` 读取相位并重绘。网页生产轨迹由 `tools/capture_noncombat_first_pill_rules_source.js` 和 `tools/capture_noncombat_first_pill_poison_terminal_source.js` 从自然丹修路线实跑采集；两份 fixture 均固定 `DeckCombatSystem.js`、`PathArchetypeSystem.js`、战斗卡与流派规则的 SHA，`validate_godot_runtime.py` 核对 SHA。没有用脚本制造固定终态，也没有在桌面入口放行未建场景。

| Issue | 修前反证与根因 | 修复、回归及边界 | 独立审查 |
| --- | --- | --- | --- |
| N5-PILL-01 | 首次 `pill_recycle` 后网页版 `qiGained=1`，Godot 仍为 0；`CombatDomain.play_card` 未按来源 `maxQi + qiGained - qiSpent = qiRemaining` 更新敌方回合记忆。规则专项新增逐牌 `qiGained` 对照后退出 1。 | `play_card` 在所有牌效果完成后更新 `turnMemory.qiRemaining/qiGained`。来源四牌、毒伤敌行动及疗伤的逐步状态对照通过；法、体规则与剑修完整战斗回放退出 0。 | VERIFIED（仅规则行为） |
| N5-PILL-02 | 来源第二回合 `pill_ember → pill_catalyst` 后毒伤击杀敌人。修前 `choose_reaction` 在相位仍为 `REACTION_OPEN` 时先发 `POISON_TICK`，随后才写 `VICTORY`；`main.gd::_on_combat_changed` 只在信号到达时重绘，可能留下反应按钮。新增来源终态专项修前退出 1。 | `choose_reaction` 先写 `active=false/VICTORY/outcome`，再发一次 `POISON_TICK`；新专项断言最后通知到达时相位已是 `VICTORY`，修后退出 0。非致命毒伤仍按原敌行动链继续。 | VERIFIED（仅信号/状态链） |

规则批次当时只对真实待战请求在探针中代入 `launchAuthorized`，来源战场目录尚未建；上节随后接入了场景。此处规则证据本身不证明玩家已能操作丹修战斗、胜败逃回剧情或整场逐回合同轨。被否决的捷径是单独在 UI 猜测毒伤胜利，或仅修改 fixture 的期望值：两者均不能修正战斗状态生产者。

独立只读复审从网页两捕获脚本重新实跑并比对 fixture 字节、校验四源 SHA，复跑丹修规则、法修规则与旧剑修完整回放，并追踪 `main.gd` 信号消费者和胜利按钮读相位；两项规则/信号行为判定 VERIFIED，未见新增确定性 P1/P2。丹修真实桌面 UI 闭环仍为 UNPROVEN。此次作者另跑丹修、法修、体修规则、剑修完整回放与剑/法/体桌面首战专项均退出 0；法修规则专项退出 0 但报告了现存资源退出告警，不把它写成无告警。全量 `validate_godot_runtime.py` 未取得完整结果，故本节不以总门禁证明广域完成。当前 Godot 文件尚未纳入 Git，`git diff` 为空；复审结论基于当前文件、来源与实跑，而不是相对 Git 基线的补丁审计。

## 2026-10-26 N5 体修首世来源战场接入（可玩候选，N5 未签收）

| Issue | 断点与实现 | 证据及边界 |
| --- | --- | --- |
| N5-BODY-STAGE-01 | 体修来源待战请求已有效，但目录 `unbuilt`、来源帧未打包、桌面不放行。现在 `duel_stage_source_2d.gd` 按遭遇 ID 选择体/法各自原回廊、主角、敌人、牌图及帧序列；目录只放行首世体修教学战，缺来源素材时继续留在待战。 | `noncombat_first_body_live_battle.gd` 修前在场景未授权处退出 1；修后真实冷档 `LaunchBattle`、`body_stance` 出牌、撤离按钮回剧情、失败写盘重试、冷恢复/重复拒绝均退出 0。 |
| 胜败终态 | 同一来源请求装载 `CombatDomain`，真实出牌/敌袭产生 `VICTORY/DEFEAT`，战斗层只报终态，剧情层结算。 | `noncombat_first_body_outcomes.gd` 输出 `NONCOMBAT_FIRST_BODY_OUTCOMES_PASS victory=true defeat=true source_owner=true`；这是规则域驱动测试，不是桌面鼠标逐步完成胜败。 |
| 来源视觉 | 同步脚本仅增加体修首战被消费的 S1 动作帧、身份图和牌图；同步后 74 数据/735 图/32 音频。 | Windows 正常图形渲染 `artifacts/godot-migration/first-body-battle/body_1280_idle.png`、`body_1920_idle.png`、`body_1280_contact.png` 已目视核对铁骨机关兽、体修主角、动作、卡牌和无裁切；截帧不等于整段动作质量验收。素材覆盖门禁 `NONCOMBAT_ASSET_COVERAGE_PASS images=531 animated=3 audio=32 copied=735`。 |

体修、法修与旧剑修相关规则/桌面专项及 `replay_full_battle.gd` 全部退出 0；来源 JSON 内容验证通过。独立只读审查核对体/法各 46 个必需媒体路径的源文件、运行副本和清单 SHA，以及 1280×800、1920×1080、出招截帧，未见战场功能链确定 P1/P2。审查还发现一次体修首战测试启动时的旧像素舞台 PNG 静态预载编译错误；Godot 编辑器导入补齐该 PNG 的 `.png.import`/`.ctex` 后，体/法/剑相关四项完整日志复跑均不再报 `SCRIPT ERROR`。体修首战测试还曾在 PASS 后偶发退出资源告警；测试释放场景后等待引擎清理，再串行三次均退出 0 且日志无 `ERROR/WARNING`。这关闭了本次可复现的测试收尾问题，不推断 Windows 导出包已无资源问题。体修只限首世教学战，整场跨引擎逐回合同轨、其它生命/后续遭遇、声音和 Windows 导出包图形交互仍待做。

## 2026-10-26 N5 体修首世教学战规则预备（历史记录：场景接入前）

`tools/capture_noncombat_first_body_rules_source.js` 在网页版生产运行图从首世体修走到 `enc_trial_body_iron`，真实打出 `body_stance → body_stance → body_fist`，记录开场与逐牌气血、防壁、敌血、真元、手牌、坚固层数，并固定 `DeckCombatSystem.js`、`PathArchetypeSystem.js`、战斗卡及流派规则四份 SHA。来源开场防壁为 1；第一次沉桩后为 2，第二次借 `repeat_type` 加成达到 4；有盾出拳按 `block_min` 将敌血 6→4。`noncombat_first_body_rules.gd` 先在来源体修请求无法装载处退出 1，补开局被动与两条流派规则后退出 0，输出 `NONCOMBAT_FIRST_BODY_RULES_PASS source_effects=true isolated_stage=true`。剑修、法修来源规则及真实桌面首战、完整剑修回放的受影响专项均退出 0。

规则接入当时，测试仅对已认证待战请求代入隔离的 `launchAuthorized` 标志，体修目录仍为 `unbuilt`。随后上节接入来源桌面战场；本段保留此前规则证据，不把规则探针冒称桌面战斗。此前独立只读审查核对四源 SHA 并复跑体修、法修规则专项，均退出 0，未见确定 P1/P2。

## 2026-10-26 N5 法修首世来源战场接入（可玩候选，N5 未签收）

| Issue | 真实入口与断点 | 根因与修复边界 | 出门条件 |
| --- | --- | --- | --- |
| N5-SPELL-STAGE-01 | 首世 `spell` 已可自然形成并冷恢复 `enc_trial_spell_seal` 待战合同；`BattlePlanResolver` 返回 `sceneAvailable=false`，桌面无“进入战场” | 战场目录将法修标为 `unbuilt`，Godot 包仅同步剑修动作帧，`main.gd` 固定实例化剑修 HD-2D 场景且标题取剑修首场 | 从真实待战档进原法修战场、原身份与动作帧，实际出牌/敌袭形成终态，胜败逃各一次回剧情；来源图/动作无缺失，失败写盘仍可重试，冷恢复与剑修回归通过；1280×800/1920×1080 画面核对。 |

来源资产链：`encounter_presentations.json` 的法修 `sceneImage` 与 `actorCards.enemy`、`path_presentations.json` 的法修主角身份、`action_presentations.json` 中 `paths.spell` 与 `encounters.enc_trial_spell_seal` 的动作帧/时长，以及首始牌图。同步后内容清单为 74 数据/690 图片/32 音频；原图与帧不存在时仍停在待战，不以剑修木人代替法灵。修前 `noncombat_first_spell_live_battle.gd` 因来源战场未授权退出 1。

| 声明 | 生产入口与状态链 | 证据及限制 |
| --- | --- | --- |
| 首世法修桌面可玩 | 原剧情 `start("spell")` → 序章右选 → 邀约左选 → 预警左选 → 冷恢复 `BATTLE_PENDING` → `LaunchBattle` → `main.tscn` 来源法修 2D 舞台 | `noncombat_first_spell_live_battle.gd` 退出 0，`NONCOMBAT_FIRST_SPELL_LIVE_BATTLE_PASS desktop=true action=true flee=true atomic=true replay=true`；实际 `spell_ward` 出牌及撤离按钮回传，一次性结算、失败写盘重试和冷恢复。仅首世教学遭遇放行。 |
| 法修胜败终态能回剧情 | 同一来源请求装载 `CombatDomain`，真实出牌/敌袭产生 `VICTORY/DEFEAT`，`main.terminal_result()` 生成事实，剧情域结算 | `noncombat_first_spell_outcomes.gd` 退出 0，`NONCOMBAT_FIRST_SPELL_OUTCOMES_PASS victory=true defeat=true source_owner=true`；胜败操作目前为 Domain 驱动测试，不等同桌面鼠标逐步走完整战。 |
| 来源素材与表现 | 战场目录选 `duel_stage_spell_2d.tscn`；来源回廊背景、主角/法灵身份、卡图及两方动作帧从 SHA 清单加载，命中信号来自来源动作时长 | `validate_noncombat_asset_coverage.py` 输出 `NONCOMBAT_ASSET_COVERAGE_PASS images=531 animated=3 audio=32 copied=690`；正常 Windows 图形渲染的 `artifacts/godot-migration/first-spell-battle/spell_1280_idle.png`、`spell_1920_idle.png`、`spell_1280_contact.png` 已目视核对来源身份、卡牌和无裁切，截帧不证明完整动作质量。 |
| 旧线不倒退 | 剑修仍走原 HD-2D 舞台，法修只在已认证请求和全部来源素材存在时开放 | `noncombat_first_sword_live_battle.gd`、`battle_plan_resolver_contract.gd`、`replay_full_battle.gd` 退出 0。 |

范围界线：法修三张起始牌的逐步数值已与网页生产轨迹对照；整场战斗逐回合跨引擎同轨、法修其它生命/后续遭遇、体修/丹修首场、战中中断恢复、声音及 Windows 导出包图形交互仍待做。以上是一条可玩候选链，不是 N5 或 N0–N11 的完成声明。

独立只读审查复跑法修桌面链、法修胜败规则链与剑修旧链，均 exit 0；46 个法修素材路径的源文件、运行副本和清单 SHA 一致，未发现确定 P1/P2。审查将 `spell_1280_contact.png` 限定为命中后扣血与界面截帧，不作为完整动作质量证明。`godot/` 在当前工作树整体未跟踪，无法给出相对 Git 基线的差异证明；以来源 SHA、入口链和实跑结果审查本批。

## 2026-10-26 N5 法修教学战规则预备（历史记录：场景接入前）

`tools/capture_noncombat_first_spell_rules_source.js` 从网页生产运行图自然走到首世法修教学战，按 `spell_ward → spell_spark → spell_cycle` 真实出牌，保存开场和每步的气血、敌血、真元、手牌数、法印及四份来源 SHA。Godot 的请求装载现能从真实持久法修合同建立来源敌人、牌组和 `spell_cycle` 流派；法印达到两层后的条件伤害与消耗、抽牌、三张不同牌成环的伤害和回气逐步对齐来源 fixture。原剑修出牌与完整来源战斗回归通过。

场景接入前，`battlefield_enc_trial_spell_seal_native_v1` 为 `unbuilt`，`runtimeScene` 为空，因此桌面不显示进入战场。当时 `noncombat_first_spell_rules.gd` 只以隔离规则探针验证数值；现已改成真实桌面授权检查。此段只保留此前的规则工作与审查史。

此前独立只读审查复查了来源指纹、网页出牌消费者、Godot 请求装载/卡效/UI 门禁与受影响剑修回归，结论为三张法修牌的限定规则声明 `VERIFIED`、当时未建场景的桌面门禁 `VERIFIED`、剑修回归 `VERIFIED`；当时法修整场可玩战斗 `UNPROVEN`。审查者独立复跑 `noncombat_first_sword_live_battle.gd`、`replay_full_battle.gd` 与 `battle_plan_resolver_contract.gd`，均退出 0，未见当批确定 P1/P2。当前相关文件在原工作树中为未跟踪文件，不能以 `git diff` 给出相对基线；此处证据依当前文件、来源 SHA 和实跑测试。

## 2026-10-26 N5 剑修教学战真实回传（单线 VERIFIED，N5 总段未签收）

首世剑修桌面剧情从已保存的 `BATTLE_PENDING` 请求重新校验来源 owner、预警回执、牌组和战场素材后，可进入剑修教学战。战斗运行态从该请求的角色属性、气血上限、道心、流派开场护盾、牌组，以及来源遭遇和敌人模板建立；不再把固定 `m0_desktop_opening.json` 中途快照当作玩家存档。玩家操作造成真实 `VICTORY/DEFEAT/FLEE` 后，战场只上报终态事实，剧情域仍负责一次性写入来源奖励或伤势与结果卡。预警右选和序章右选的旧档重放同时修正：`encounterActionHistory` 首项记录的是来源方向，接受遭遇实际命令为左；战斗回执历史也保留来源方向。严格回放现在校验两者并执行真实接受命令，避免把右侧序章误读为避战。

`noncombat_first_sword_live_battle.gd` 在真实桌面剧情入口打开战斗，使用出牌、结束回合及承受敌袭得到战败，验证失败写盘原态/重试、结算、冷恢复和拒绝重复返回；另从同一来源请求与完整源码战斗夹具的抽签/出牌序列得到真实胜利，桌面撤离按钮也能生成 `FLEE` 终态；两者均由战场终态构造 v2 结果，剧情只接收一次。`noncombat_warning_flow.gd` 五种预警读档与 `noncombat_battle_return.gd` 四修合同结算回归通过。当前只接剑修首场：其它生命的剑修教学战、法/体/丹教学战和后续遭遇的战斗规则、对应撤离及战中中断恢复仍需实现；这些分支继续保留待战存档，N5 和 N0–N11 均未签收。

## 2026-10-26 N5f 精英配额与炼气雷关（局部 VERIFIED，总目标继续）

`tools/capture_noncombat_third_cadence_source.js` 从干净剑修 seed123 的公开输入自然走到第三次定期精英卡，四分支均经真实网页战斗。新增 `tools/capture_noncombat_npc_first_source.js` 记录该路线上白刃真人初见左右两选、两次 NPC 判定随机值、师徒进度及后续 TRUSTED 卡；`npc_first_source.json` 的 63 份来源指纹均匹配。Godot 的 NPC 调度保存判定队列、随机游标、好感及记忆，在来源随机值回放下通过同一公开选择前缀进入 NPC 初见、TRUSTED 师徒卡及原精英卡。`noncombat_npc_first_entry.gd` 验证来源卡、桌面立绘和冷恢复，`noncombat_npc_first_choices.gd` 验证左右结算及后续师徒卡，`noncombat_npc_first_legacy.gd` 验证旧 Godot 档原字节读入、下一决定延迟激活和写盘失败回滚；`noncombat_cadence_third_entry.gd` 原路线入口已退出 0。Godot 战斗结算曾把同一场胜利的基础修为与作者修为合并为单次师徒进度事件，两场累计比网页版少 2 点；现按真实奖励分段推进，来源路线在白狐入口前的进度对齐为 31。网页全局 RNG 与 Godot 独立 RNG 尚未自然同种子逐抽样一致，故原路线测试明确标为来源随机值回放。

网页第三次精英绕行后自然出现 `_warning_ch_qi_100`。`tools/capture_noncombat_qi_gate_source.js` 以公开选择和真实战斗录制免费/付费备战胜利、免费备战撤离与战败，另录三种心魔、三种突破领奖和三种筑基感悟选择；`qi_gate_source.json` 固定 64 份来源 SHA。Godot 替代公开路线修正师徒进度后会多经过 TRUSTED、其回应及一次天象卡，再进入雷关；`noncombat_qi_gate_entry.gd`、两种胜利备战、撤离、战败心魔三支及 `noncombat_qi_gate_arrival.gd` 已重新通过；完整战败专项输出 `NONCOMBAT_QI_GATE_DEFEAT_PASS cases=3 source=true replay=true`。胜利进入筑基、修为重置 10、气血/道心回满并增加寿元；撤离仍在炼气且延后一抽；战败触发心魔，接受/抵抗在此来源状态进入道心崩碎，封印进入败退结果卡。筑基感悟选择若功法已拥有，网页版允许继续且不重复加牌，Godot 现同样处理。来源低寿元/保命变体、真实战场终态生产、网页版旧档和 N0–N11 总验收仍缺。

## 2026-10-26 N5f 第二次定期遭遇（局部 VERIFIED，总目标继续）

`tools/capture_noncombat_second_cadence_source.js` 从干净剑修 seed123 经两场真实战斗、首次 catalog 绕行和八次公开选择自然触发 `enc_quota_qi_missing_disciple`，记录绕行、胜利、战败、撤离四支，包含来源卡、战前警告、真实网页战斗输入/终态、决定账本、导演配额与下一张卡。`godot/tests/fixtures/second_cadence_source.json` 固定 63 份来源文件 SHA。Godot 经同一公开路线自然触发该卡；命盘抽奖使用固定的可重放种子 8898，使第一张为网页 seed123 的稀有道心丹，其奖励在当前封顶道心上无数值变化。命盘动作在 Godot 选择史单列以供严格重放，跨引擎比较时排除这个网页不记录的内部动作。

`noncombat_cadence_second_entry.gd` 验证自然卡/冷恢复。`noncombat_cadence_second_outcomes.gd` 分别验证四分支来源状态、警告/待战/战果、三次累计战斗回执、回应卡及确认后续、每阶段严格读档。第二张 catalog 的右选有作者 `narrativeBlock`：修复前 Godot 绕过“失踪弟子”承诺回应直接显示师门卡；现在同一决定写入可恢复回应卡与承诺回执，确认后再继续调度。第一张 catalog 无 `narrativeBlock`，保持原绕行行为。Godot 师门卡自带原立绘路径，网页版师门卡由展示层另行解析，下一卡比较只投影掉该展示字段。四支分别退出 0，完整四支单进程输出 `NONCOMBAT_CADENCE_SECOND_OUTCOMES_PASS`；首次 catalog 四支回归输出 `NONCOMBAT_CADENCE_BATTLE_PASS`。战果在 Godot 专项由合同输入，真实战斗场景终态生产仍未验收；本段不构成 N6 或 N0–N11 签收。

网页版 seed123 自然路线在第二次遭遇绕行、作者回应、白刃师门/天象后，于决定 24 先签发 `npc_encounter_bai_ren_初见`，决定 27 再签发精英配额 `enc_quota_qi_outer_guard`。Godot 现在可在固定来源随机值回放下按相同公开决定顺序签发两卡，`noncombat_cadence_third_entry.gd` 已通过；`noncombat_cadence_third_outcomes.gd` 沿此原路线的绕行、胜利、战败、撤离四结局及分段冷恢复均退出 0，输出 `NONCOMBAT_CADENCE_THIRD_OUTCOMES_PASS contracts=4 source_route=true replay=true`。另一条 Godot 替代路线多一张 TRUSTED 与回应卡，排期决定数不同，其专项只比较来源卡、精英配额和终局相对效果，不再要求整份 Director 的绝对决定号相等。

## 2026-10-26 N6 古洞窟与迷雾谷（局部 VERIFIED，整段未签收）

`tools/capture_noncombat_cave_source.js` 从干净剑修 seed14 的生产浏览器 VM 自然抽到 `q_cave`，记录进入古洞的前态、三节点 8 组选项、主动离场、成功/失败回执，以及迷雾谷首节点两选、第二节点变体和四个完成结局。`godot/tests/fixtures/cave_mist_source.json` 含本次公开输入、卡文/图 ID、状态与来源文件 SHA；验证器逐个核对来源指纹。浏览器入洞决定 27 时气血 2→1、气血上限 4→3、道心 3→2；先吞噬再过兽关的两种选项会写失败回执并进入 `death_blood_loss`。另从同一待选快照设置来源允许的极低气血，验证入洞当决定就死亡并写失败回执。主动离场不增加决定序号，也不触发迷雾谷。

Godot 从普通池自然抽到 `q_cave` 后由 `noncombat_cave_flow.gd` 接管三张原节点，`dungeonRun`、进度及同生命/同来源决定的唯一结算回执随 `RunSession` 保存。成功回执才激活 `mist_valley`；两张原故事卡、第一选造成的第二节点文案变体、四个完成回执、`yuanming_legacy_found` 世界事实和 `yuanming_karma_mark` 延后因果均由来源数据生成。桌面“离开秘境”按钮走独立操作账本，保持决定时钟不变，严格读档会在相同节点重演该操作。古洞死亡修复了死亡消费者只接受 `q_love` 与同轮命盘盖住死亡卡的问题；兽关右选的 `beastCore` 使用来源受限的法宝实例回执。

已通过 `noncombat_cave_entry.gd`、`noncombat_cave_abandon.gd`、`noncombat_cave_failure.gd`、`noncombat_cave_rewards.gd`、`noncombat_mist_valley_entry.gd`、`noncombat_mist_valley_outcomes.gd` 和 `noncombat_mist_valley_legacy_upgrade.gd`：自然入洞、主动离场的桌面按钮/冷恢复、来源气血基线的入洞当即死亡及两条兽关死亡路径、四条古洞成功奖励组合及 `beastCore` 实例来源、迷雾谷四结局与旧四线程 v2 档延迟激活。`q_cave.left` 在这条 Godot 自然路线道心已封顶，只用非满道心的来源数值策略验证。`noncombat_death_card_journey.gd` 回归和素材覆盖检查也退出 0；当前素材覆盖为 645 图、32 音频。Godot 自然路线进入古洞前的气血比浏览器此样本高 1，因此死亡专项从真实入洞状态改用浏览器气血作合成基线；它验证死亡消费者，但不证明该固定 Godot 路线自然死亡。N6 其余剧情/任务/线程、实际 Godot 战场终态生产、第二世全部路径和 N0–N11 总验收仍未完成。

## 2026-10-26 N5f 定期遭遇与累计排期（VERIFIED）

N5e已独立VERIFIED，继续下一依赖，不改并行战场。来源P88 `FlowDirector`/`EncounterDirector`位于章节、任务之前，持久化展示/接受/解决/绕行及独立冷却。已迁STORY山径没有source.encounterId，不能替代定期catalog山径。

| Issue | 来源与真实断点 | 实施/验收要求 |
| --- | --- | --- |
| N5f-01 | 原剑修两场真实胜利、两次领奖和章节后，turn11展示 `encounter_card_enc_patrol_qi_mountain_shadow`，scheduledDecision12，当前8张牌。Godot自然同前缀`noncombat_cadence_entry.gd`退出1：此处误进`q_whiteFox_quest`；Domain缺P88，gateway仅认教学catalog。 | 从原候选资格、角色配额、seen/resolved/presented排序选卡；不能写死下一张山影。实现原优先级、pending展示检查点/原图与当前loadout，保留旧档前缀，明确新规则激活边界。主门禁暂不登记尚红的入口测试，修完后必须加入。 |
| N5f-02 | 教学Return/Avoid当前会重建首轮排期，不能累加一般遭遇。源四类oracle已捕获实际绕行/胜/败/逃，三场战斗不会丢前两场或已获第7/8张。 | 绕行只追加avoided、不增resolved counts；胜败逃都追加resolved与角色count，保留教学记录。nextDue取展示scheduledDecision+interval，cooldown取结算时当前决定+冷却；一般绕行不是教学promise回应。完整卡/奖励/伤势/寿元/Director逐值比对、写盘失败/重复/旧owner拒绝、offer/warning/pending/result/ack冷恢复。 |

来源证据：`tools/capture_noncombat_cadence_source.js` 使用生产runtime和公开输入，fixture `tests/fixtures/cadence_battle_source.json` 保存公共教程路线、教学6牌→STORY7牌→catalog8牌、4分支和真实战斗输入。源绕行77→75寿元是作者-1再叠普通COMBAT决定成本-1；直接接白狐，没有额外确认卡。catalog撤离77→76；胜败逃terminal turn12、ack turn13，排期nextDue20/cooldown14。实际败退须等待第二轮抽到`draw_sword`出牌后承受PROBE，不得用始终空过或注入HP伪称真实败退；原plan的intent4与enemy atkPower2按各自字段保留，不在迁移里修改平衡。

### 2026-10-25 接续调查与修前证据

当前工作树的 `noncombat_cadence_entry.gd` 已从真实开局通过，`noncombat_cadence_catalog.gd` 和 `noncombat_cadence_director.gd` 也通过；旧版“入口仍红”的记录已过期。四分支 `noncombat_cadence_battle.gd` 仍在第一条绕行路径的发卡前状态失败：`daoHeart actual=4.0 expected=3.0`，因此 N5f 尚不能验收。相关 Godot 文件在本工作树中为既有未跟踪文件，接续时保留其内容。

| 维度 | N5f-02 当前首个断点 |
| --- | --- |
| 真实入口 | 剑修自然开局，经教学胜利、山径胜利、两次择法及 `ch_qi_80.left`，再到定期遭遇。 |
| 生产者 | `src/game.js` 的选择结算调用 `GameStateManager.checkDeath()`；Godot 对应 `MilestoneFlow.settle()` 结算章节效果。 |
| 消费者 | `CadenceFlow.resume()`、`EncounterDirector.schedule()` 和 `noncombat_cadence_battle.gd` 读取结算后的角色与导演状态。 |
| 初始化与存储 | `Domain.start()` 初始化权威快照；属性上限、当前属性、决定时钟和 `noncombatFlow.encounterDirectorState` 经 `RunSession` 原子保存。 |
| 最小复现 | `Godot --headless --path godot --script res://tests/noncombat_cadence_battle.gd`；首例 `sword_avoid` 在 `beforeOffer/attributes/daoHeart` 失败。 |
| 覆盖情况 | 目录、导演和发卡入口专项已通过；四分支长链专项已红，尚未纳入总门禁。 |
| 根因结论 | 已证实：`ch_qi_80.left` 把气血 1 扣至 0，网页随后燃血，气血上限 5→4、道心上限 4→3、道心 4→3；Godot 章节结算漏做选后被动回复与死亡检查，保留道心 4。来源 fixture 与网页实跑一致。 |
| 本批边界 | 修正章节结算中这条已证实的续命路径，再对照四分支和旧档激活点；不修改并行战斗场景或来源 fixture。 |

### 2026-10-26 N5f 修复与验收证据

`MilestoneFlow.settle` 补上来源选择后的被动回复及 `checkDeath` 燃血续命，`ch_qi_80.left` 的气血/道心上限与来源对齐。首次教学战胜利领奖后，新局 Domain 先排已到阈值的 `ch_qi_20`，保留署名山径续卡，章节结算后再兑现；来源的章节→山径→第二次奖励顺序、奖励时间戳和历史逐值一致。旧 Godot 存档没有 N5f 初始激活标记，保留原山径→章节前缀供严格重放，`noncombat_cadence_legacy.gd` 已断言这一顺序并通过冷恢复。测试中的网页 `flags` 映射到 Godot 因果承诺/选择历史/任务账本，空 `modifiers` 与空任务账本按同义状态比较，没有改来源 fixture。严格重放沿用测试已设置的旁支随机值，保证同一公开输入重建同一存档。

`noncombat_cadence_battle.gd` 自自然剑修开局，对来源四行 fixture 的绕行、胜利、败退、撤离逐值验证；四例均输出 `CADENCE_BATTLE_CASE_PASS`，总输出 `NONCOMBAT_CADENCE_BATTLE_PASS`，退出0。覆盖8→9牌、前两场战果保留、Director累计计数/排期、原卡与结果卡、offer/warning/pending/result/ack 冷恢复、写盘失败原字节、外来 owner/重复回执拒绝。`noncombat_cadence_entry/catalog/director` 退出0。独立只读审计对新档四分支给 VERIFIED，指出旧档无标记激活缺实测；新增 `noncombat_cadence_legacy.gd` 从公开决定形成无标记 turn11 旧前缀，严格重开不改字节/牌组/前两场，旧白狐展示不提前排期，下一成功决定原子安装 activationIndex12，失败写盘回滚和升级后冷恢复均通过，退出0。

受影响专项 `noncombat_first_session_route.gd`、`noncombat_victory_continuation.gd`、`noncombat_milestone_flow.gd`、`noncombat_battle_return.gd`、`noncombat_combat_scheduling.gd` 退出0。后者修前暴露新世重置后有 cadence 标记却缺本世 Director 初始状态；现按来源 `EncounterDirector.reset()` 在恩赐结算时初始化本世状态，旧第二世无标记且无 Director 的前缀严格重放到下一决定，原子初始化本世 Director+标记，旧第二世排期专项通过。五项 N5f 专项已登记 `validate_godot_runtime.py`。该接口专项提交来源约定的战果合同，不代表 Godot 战场场景已能自产终态；下一次定期遭遇的完整来源四分支仍待后续验证。

总门禁 108 项按失败断点分段执行完毕，最后一段 `python tools/validate_godot_runtime.py noncombat_rebirth_ghost_journey.gd` 退出0并输出 `RUNTIME_MIGRATION_TAIL_PASS data=74 art=606 audio=32`；没有单次从头到尾的 PASS。分段原因：旧测试的 20/60/120/180/240/900 秒限时在本机实际耗时下不足，单项复跑均退出0后校准对应限时；旧 v1 第二世白狐、死亡轮回和鬼市长测的固定卡序遗漏 N5f 已到期的定期试炼与决定15的命盘插入。它们现从真实存档冷重开，公开右选绕行并保存决定，再续原任务/因果/交易路线；`noncombat_whitefox_rebirth.gd` 胜败逃及非胜重战退出0，`noncombat_death_rebirth_journey.gd` 的体修因果与独吞功法因果在命盘同决定翻牌后通过，`noncombat_rebirth_ghost_journey.gd` 的旧商路标记分叉沿实际 `q_spellTome.left → market_encounter` 严格回放，主档字节不变。独立只读复核对旧档新增绕行路径给静态 VERIFIED，未见确定掩盖问题。N5f 结论基于五项专项、受影响旧专项和分段总门禁；第二次定期遭遇只在旧第二世长局验证了公开绕行，未作四结局网页 oracle 对照。

下一依赖顺序已核对：定期catalog → 普通inline `q_fellow.right` 的剧情消费者（已局部验证，战场与装备仍缺）→ 荒村线程（战斗结局推进第四幕而非非胜重战）→ 剑冢（入口宝物/seed及declined、古剑receipt）→ 其余线程/境界。只复制任务/线程JSON不算接通；sourceOutcomeContext、延迟和条件完成种子须逐链落地。

## 2026-10-24 N5e 白狐第三幕任务战（VERIFIED）

本批沿已迁白狐前两幕接通第三幕左选；原 QUEST inline 敌人与完整 choice 为权威，不能伪造 catalog 遭遇或套山径微平衡。调查已在四修网页自然开局抵达turn11，公开战斗输入验证四胜/剑败/体逃和非胜后的再次迎战。只接剧情输入/结果消费，战场运行生产者不在本批。

| Issue | 入口/权威/根因 | 实施与验收合同 |
| --- | --- | --- |
| N5e-01 | `q_whiteFox_3.left` → GameLogic/CardSystem inline choice → CombatCoordinator；当前Godot禁用，gateway仅识别两类catalog来源。 | 绑定任务源SHA、active step2、QUEST原卡/choice/无catalogID的combatCard；warning及付费备战不结任务、不推进决定；当前deck和能力进入请求。自然入口、原图/按钮、pending冷恢复、缺源/改源拒绝。 |
| N5e-02 | game._resolveCombatOutcome → QuestSystem.advanceQuest → KarmaSystem，再由战果提交一次决定。当前return拒额外效果/种子，QuestFlow只支持付款/放弃。 | 胜利合并基础、选项和任务奖励、实际裁剪的数值摘要、六势力和商路事件、两种子按来源顺序/来源结局；败退伤势+道心代价，撤离寿元，不关任务。down回通用Flow，章节优先后可回第三幕；新owner重战、旧owner拒绝、写盘失败、重复/严格重演与旧付款/放弃回归。 |

完整WorldPulse/StoryNetwork/lineage仍为独立缺口；禁止从本次战果重置此前全局状态。来源副作用和当前已迁范围分别验收，未通过测试/独立复核前不计完成。

### 当前实施与真实来源

- `capture_noncombat_whitefox_battle_source.js` 在原生产网页运行图中用公开选牌/endTurn/reaction输入生成8条轨迹，保存为 `tests/fixtures/whitefox_battle_source.json`；四修胜、剑败、体逃及两种非胜后冷恢复再获胜。两次生成字节一致，53份JS/JSON来源指纹已登记正式门禁。
- QUEST第三幕左选已开放，网关冻结完整原卡/choice/combatCard。`encounterId` 必须保留null，`questId=white_fox_line`，内联犬群为hp6/atk1/def0，四修一致；不得虚造catalog ID或套教学/山径微平衡。免费及付费预警不提交剧情决定，paid仅扣10灵石/恢复至多1气血；请求保留当前deck、knowledge、modifiers。
- 胜利先结算基础战利品与choice，再结算任务完结奖励、六势力与商路事件；最终摘要用实际裁剪后的增量。任务关闭/完成一次；`foxGratitude`在`whiteFox`之前，分别保留originQuest与originOutcome、null context。因果种子随决定只tick一次。败退应用伤势及道心-1，撤离寿元-1，任务仍在step2；确认结果后按原章节优先级返回第三幕，新的owner不能被旧战果兑现。
- 原故事场景图用于战果，预警用原荒野图；战果完整卡字典/原文/技能候选对照来源。胜利择法实际加入当前deck，director不因无catalog inline任务战被错误累加。

### 发现的问题、修复与证据

1. 新 `noncombat_whitefox_battle.gd` 修前失败“inline quest battle has no consumer”；8矩阵先再次暴露decision15被命盘覆盖奖励。核对网页暖运行：turn11/wheel11→非胜turn12/wheel11→结果确认13/12→章节14/13→再战胜利15/13→领奖16/14。源combat terminal不调用普通残卷、wheel/ripple/hint。Domain现按本次combat receipt分流，仍保留因果、线程、ghost/到货/market；terminal到货不按普通选择规则抑制market。最终8例 `NONCOMBAT_WHITEFOX_BATTLE_PASS`，退出0。
2. 新 `combatScheduling{version:1,activationIndex}` 保留旧局既有随机序列/奖励。新局从0生效；无标记旧档按旧规则严格重演，通过后下一成功决定原子升级，读档不改字节、不回算历史计数。`noncombat_combat_scheduling.gd` 通过新/旧教学、STORY山径、结果确认恢复普通tick、旧前缀、旧第二世前缀、失败写盘和严格重启。网页冷启动会清零wheel；Godot继续保留已有持久命盘合同，不把此源端重置行为伪称两端一致。
3. `noncombat_whitefox_integrity.gd` 退出0：实际桌面节点左按钮进入warning、两阶段原图/原标题、付费失败同token重试、当前牌组快照；warning/pending×任务JSON/故事图/预警图×缺失/变化，共12类live与cold来源故障正确区分并保留字节、禁止误归档；提前完成任务、seed结局、重复历史三类伪造拒绝。
4. 独立只读审计实际拒收两项：P1旧第二世白狐左战保存后无法重开；P2气血1、道心4/4战败后额外扣1道心。已修复并回归：第一/第二世共用来源检查、唯一战果匹配及预警动作重演；第二世支持warning/pending/result/ack/非胜重战。新增 `noncombat_whitefox_rebirth.gd` 退出0，合法旧inheritanceVersion1→自然第二世白狐→三个结局、两次非胜重战、来源缺失/变化与伪造history检查。`noncombat_whitefox_burn.gd` 修前复现道心多扣，改为伤势→defeatEffects→checkDeath燃血，修后道心3/3与真实网页一致，失败写盘、严格重启与原ch80续卡均通过；真正心魔/寿尽/法宝复活仍不是本批已迁功能。
5. 原 `noncombat_whitefox_third.gd` 回归通过，旧放弃/足额付款及资金门槛不变，新增左选可用；原warning五例在共享恢复提取后通过。内容/来源前置 `CONTENT_AND_SOURCE_GATES_PASS`。五个新专项已登记正式门禁；本批没有重跑全部运行套件，最近完整通过仍为N9x-03j-p。独立审计最终VERIFIED：原失败脚本warning/pending恢复变绿；修前保留的旧pending文件在不改字节的前提下成功恢复、结算、领取功法与继续，外来owner和重复history仍拒绝。独立燃血回归退出0，未见新确定P1/P2。最终共享恢复/燃血改动后，原四修非胜8例回归再次退出0。

本批未修改战斗场景、角色、美术、战斗domain或实际终态生产者。Godot测试输入战斗合同结果，证明非战斗消费者与持久化，不能冒充实际战斗动画已驱动剧情。其余任务/线程、原网页旧档导入、完整世界与高境界、声音素材消费者及最终Windows构建仍需继续实施。

## 2026-10-24 N5d 山径第二战与连续战果

本批合同：首战奖励取得的新功法进入山径 STORY 左选的第二战，复用 v2 待战槽；结算按原来源回剧情，保留首战记录并可严格重启。桌面原图/原文及剧情规则沿用网页版，战场美术与实战终态生产仍由独立战斗任务接入。

| Issue | 真实入口、原因与实施 | 验收状态 |
| --- | --- | --- |
| N5d-01 | `q_mountain_shadow_approach` 左选 → Domain → EncounterFlow → BattleGateway。原入口禁用、网关只认教学 COMBAT/starter。扩为来源 STORY 的完整冻结 choice/combatCard，按源 roleMicroBalance 计算四修敌人，携带当前牌组与能力快照；warning 是备战检查点，不增加决定。 | 新 `noncombat_mountain_battle.gd` 修前退出1：山径没有第二战消费者。修后六例通过，完整来源 choice、当前7张牌、knowledge/modifiers、原warning文案及每阶段严格恢复一致。原敌人四修 hp/atk 为5/2、4/2、2/1、1/1；体/丹 planGraph 攻击意图同步应用来源delta。 |
| N5d-02 | 第二战结果 → BattleReturnFlow/VictoryFlow → Domain 原子保存及 replay。原历史只有一条；山径结算不能复用教学排期递增，也没有返回山径的奖励续卡。改为追加记录、按决定索引唯一匹配、保留 STORY 标签/ID、原 outcome 文案与择法候选。 | 六例完整结果卡/数值增量/导演状态/两条战果/重启均通过。第二次胜利四修修为+9、气运+1，灵石3/3/1/1。奖励跳过后回通用Flow，不重复山径；专项另验证取得第8张牌、写盘失败回滚、相同token重试、旧owner/伪造多战历史拒绝。 |

来源与验证：

1. `tools/capture_noncombat_mountain_source.js` 通过原生产runtime和公开战斗输入记录 `tests/fixtures/mountain_battle_source.json` 六例：四修真实胜利、剑真实战败、体实际撤离；14份JS/JSON指纹。独立审计再实跑剑修，sourceCard/warning/pendingResolution/resultCard 与fixture一致。
2. `noncombat_mountain_battle.gd` → `NONCOMBAT_MOUNTAIN_BATTLE_PASS cases=6 source=true current_deck=true multiple_results=true atomic=true replay=true`，退出0。该矩阵同时覆盖第一战获法、第二战持久结算与确认后续流程。warning只比较对玩家展示的字段；浏览器内部 `_targetCombatCard/encounterContext` 由Godot的独立冻结resolution和owner合同承担，不复制成第二份UI状态。
3. `noncombat_mountain_integrity.gd` 先在真实桌面按钮进入warning后发现源战场图未打包，后又复现 live 缺图分类丢失、缺JSON误标为变化。已补原PNG（SHA `2a76d4452f811fb651ce8236f8b288819d6db77be74c318020eed6693dd4ff16`）和同步脚本动态来源；gateway传递 `SOURCE_UNAVAILABLE/SOURCE_MISMATCH` 到 Domain/return/restore。最终专项退出0，覆盖桌面点击/原图/双按钮、付费备战一次性、warning与pending缺图/变图/缺模块/变模块、保留原字节并恢复重试、五种战果历史篡改、第二次择法失败写盘与重复拒绝。UI证据是headless真实场景节点，不冒称截图美术验收。
4. 来源 `_encounterActionId` 先取 STORY ID `q_mountain_shadow_approach`，没有对应composition；故五项世界样式为null。VictoryFlow现检查来源action key与战场配置，未把 canonical encounter ID 强套成已兼容。此处是本批来源结算投影，非完整战场渲染兼容器。
5. 独立只读 `mountain_battle_audit` 核对真实源链并复跑旧教学warning五例；本代理复跑旧四修非胜八例，全部退出0。内容/来源前置门禁 `CONTENT_AND_SOURCE_GATES_PASS`；新两专项及14源指纹已注册总门禁，当前包74份数据/604图/32音频。受影响文件空白检查通过；整个工作树另有无关 `.workbuddy/memory/MEMORY.md` 尾空行，未修改、不声明全树diff通过。最近完整运行门禁仍为N9x-03j-p，本批没有重复完整套件。

明确边界与下一批：Godot 测试提交合同终态，不冒充实战动画/终态生产已接；完整 WorldPulse、StoryNetwork、lineage 胜场历史及其余任务/境界仍有缺口。下一依赖入口为原白狐第三幕 `q_whiteFox_3` 的 inline QUEST 战斗：无catalog encounterId、仅胜利结束任务，非胜保留任务并能重战，不能套山径的catalog数值规则。

## 2026-10-24 N5c 首战胜利 → 择法 → 山径 → 首访坊市

本批两项实施：① 来源胜利奖励、候选功法及单次取得。② 原署名续卡、路线镜头与首访坊市两选回接。以源 JS/JSON 为权威；`submit_battle_result` 仍是独立战斗适配器的终态槽位，Godot 专项输入认证字段合同，不能据此称实战场景已回传。未修改战场、角色、动画或战斗数值。

### 代码与来源规则

- `noncombat_battle_victory_flow.gd`：基础修为 `5+floor(战前修为/20)`，灵石 `floor(教学敌人 atk*1.5)`；再应用原 `victoryEffects`，剑悟写 knowledge.sword、法/体/丹写对应 modifier。数值取来源并计算实际差额，忽略输入结果中的任意奖励数据，不再额外重复 combatRewards。沿用原战场图、世界/UI 材质元数据、奖励标题/正文/选项。
- `noncombat_deck_acquisition.gd`：累计境界 rewardPool、稳定去重、canonical 已拥有检查（含 `+` 牌及取得历史）、确定性前三；选择只取得功法，不执行其战斗效果。记录 sourceType=battle_reward、mode=path_reward、原 turn，同步当前 battleLoadout.deck。down 保持牌组。
- `noncombat_first_session_route.gd`：山径从 `cards:qi` 叠加 `first_session_cohesion` 的流派 route lens；坊市从 `locations:locations` 读取。保留原图、文案、剧情结果、LOCATION/STORY 类型与标签；更新位置及 visitedLocations，不伪加 visits。右选走原 `first_session_serial`，延迟环境抽卡；坊市右选建立来源 PromiseSchema 回应，domain 可确认后恢复。
- `noncombat_domain.gd`：新 `firstSessionContinuation` 模拟源 `_questNextCardId`。领奖时**新产生**的 ripple/hint/market 等事件可使续卡暂存；仅有到期章节并不抢显式 nextCard。插入卡结算后优先恢复旧续卡，章节消费者不会抢先消耗下一阈值。源 seed123 的剑/法先显示章节来自15%随机 ripple，并非流派或“跨过修为50”；Godot沿用既有可重放随机流，不硬编码这个偶然结果，不声称与浏览器共享 Math.random 消耗序列全局一致。
- `noncombat_regulated_vendor_flow.gd`：首访 `loc_market_first` 左选打开既有 regulated_market，会话关闭后才应用来源 vendorCloseEffects.fortune +3、被动恢复、一次决定/种子时钟与访问记录。开店不提前结算。源卡与指纹保存于会话，恢复时重演货单/会话；不为该入口套 q_market 的专用版本标志。

### 证据与问题闭合

1. `node tools/capture_noncombat_battle_victory_source.js` → `BATTLE_VICTORY_SOURCE_PASS paths=4 choices=4 real_combat=true route_lens=true market=true rows=16`。真实生产运行图与 `settleCombat`，不注入战斗终态；记录 `battle_victory_source.json` 及6份源码 SHA。剑/法/体/丹实际修为增量10/10/10/11，灵石4/4/1/1。
2. 新 `noncombat_battle_victory.gd` 先失败“胜利后的择法与山影剧情尚待接通”，后16例 PASS：数值、完整奖励卡、取得牌组/历史逐值对照；提交/选择失败回滚、重复提交/点击、奖励/续卡各断点严格重放。
3. `noncombat_battle_deck_rewards.gd` PASS：16组候选、12组取得对照；已拥有/升级/移除后已取得、累计境界、异流派、非法来源拒绝，编辑后牌组保留。旧 starter/camp/legacy 模块回归通过。
4. `noncombat_first_session_route.gd` 与 `noncombat_first_market_vendor.gd` 专项先红后绿。`noncombat_first_market_journey.gd` 曾暴露首访结果没有分派给官坊 dismiss，补齐 `_regulated_vendor_active` 后 PASS：桌面场景实例加载原图与双按钮，开店/关闭 +3 延后结算、写盘失败回滚、重复关闭拒绝、严格重启；右选回应/确认及回原流程也通过。这里是 headless 场景节点验证，没有交互截图验收。
5. 独立只读审计发现三个 P2：新 `pendingMarketCard` 不抢显式续卡；visual_worlds 缺源被覆盖成变化；路线缺图没有分类、可能被 UI 当坏档归档。全部已修复。`noncombat_victory_continuation.gd` PASS：自然 seven-left 路线对准源 turn7集市，暂存续卡→ch20→山径，仅消耗首章15且待发集市保留；继续串联首市。山径/坊市缺图及变图均分类、保留字节，图片恢复后原档可重放。审计另以真实网页 seed3 战斗证实集市插入规则；修后独立缺图复现 `restore=false/store_error=SOURCE_UNAVAILABLE/bytes_exist=true`，最终 VERIFIED，无新确定 P1/P2。
6. 原八例败退/撤离 `noncombat_battle_return.gd`、原结果完整性 `noncombat_battle_return_integrity.gd`、原官坊自然长局 `noncombat_q_market_replay.gd` 回归 PASS；来源/内容门禁前置 `CONTENT_AND_SOURCE_GATES_PASS`。全部新专项和胜利6源码 SHA 已注册完整门禁；本批没有重跑全部运行套件，最近全量通过仍为 N9x-03j-p。

### 明确剩余范围 / 下一批

- 山径左选真实第二战未接，当前可见但禁用；不得把第七张新功法抛弃后重新初始化 starter。下一批扩 story 类型战斗来源、敌人 roleMicroBalance、连续战果历史与已有战斗接口。
- Godot 实战场景终态生产、非教学战装备/被动消费、完整 worldPulse/StoryNetwork、死亡/法宝复活、其余线程/任务/境界、网页旧档和完整媒体迁移仍未完成。
- 本批环境中断使用已迁移的持久 RNG。全局原 Math.random 一致性、一般多次战斗/跨生命回放、绝对优先中断的全部交错不能由当前16例首战覆盖，需要随对应入口继续验证。

## 2026-10-24 N5b 首轮教学战败退/撤离 → 原剧情回接

本批合同：独立战斗适配器向既有 v2 待战槽提交身份相符的终态结果后，由 NoncombatDomain 单次原子提交剧情副作用；不在本批修改 combat_domain、战场场景、动画、美术或战斗数值。结果卡继续用来源 NORMAL 类型、无 combat tags、唯一 down 选择及原图，确认后进入原章节/任务优先级。`submit_battle_result(result) -> bool` 是适配器槽位，返回 false 必须保留待战并允许重试；它不是战斗动作真实性证明。

| Issue | 用户要求 / 根因 | 实现、反证与最终状态 |
| --- | --- | --- |
| N5b-01 | 已有首战待战生产者和 v2 校验器，没有持久战果消费者；剧情停在 BATTLE_PENDING。 | `noncombat_battle_return_flow.gd` + Domain submit/replay + 桌面结果事件。主专项最初退出 1：`persisted teaching battle has no result settlement consumer`，实现后四修 × 两非胜结果八例通过。真实自然开局、待战/结果/down/后续章节严格重启、重复与外来结果拒绝、写盘失败回滚；丹修败退另覆盖付费备战。`NONCOMBAT_BATTLE_RETURN_PASS paths=4 outcomes=2 atomic=true replay=true blood=true ui=true cases=8`。范围内已实现。 |
| N5b-02 | 独立审计发现新 first_session_combat scope 仅获章节入口接受，白狐等入口被静默跳过，错误状态也能重放。 | Quest/Karma/Mentor/Emergent 和 Milestone 五入口统一接收新 scope。审计实际复现 defeat→集市、flee→涟漪而应为白狐；新增 scope 专项使用原 seven-left 路线，非胜→down→两章节→白狐→救狐到第二幕，严格重启通过。`NONCOMBAT_BATTLE_RETURN_SCOPE_PASS defeat=true flee=true white_fox=true replay=true`。审计从 REJECTED 转为 VERIFIED。 |

来源与规则：

- `src/game.js::_resolveCombatOutcome`：非胜不调用普通 COMBAT 选卡的额外寿元消耗；败退按来源伤势，撤离默认寿元 -1。结果提交才增加一次决定；结果卡 down 再增加一次。两次分别 tick 因果，已有线程与市场等继续经候选快照统一调度。
- `GameStateManager.checkDeath`：真实气血为 0 且两项永久上限均大于 1 时，先把 maxHealth/maxDaoHeart 各减 1，health 设 1，daoHeart 限至新上限。保存伤势实际值，不能用燃血后的最终气血差替代。无额外 burnBlood flag。
- `EncounterDirector` 在 base turn 记录 accepted/resolved，再把决定提交到 base+1；已解决数量用于间隔哈希。严格比对完整来源 director 状态，而非只看当前卡。
- `CombatCoordinator::_buildCombatOutcomeCard`：沿用原标题、正文、NORMAL 类型、唯一 down、原战场图和 presentationId；down 不复制 combat tags，不重复伤势/寿元。新入口没有新增自定义结果文案。

可复跑证据：

1. `node tools/capture_noncombat_battle_return_source.js` → `BATTLE_RETURN_SOURCE_PASS real_combat=true defeat=true flee=true blood=true rows=2`。使用生产脚本图与真实 DeckCombatSystem；剑修实际出攻击牌/endTurn/TAKE_HIT，体修实际 flee，无注入终态或改血量。产物 `godot/tests/fixtures/battle_return_source.json` 保存 before/after/down、整张结果卡和完整 director，带四份规则源码 SHA。Godot 主专项逐字段/整字典比较两条来源轨迹。
2. Godot `noncombat_battle_return.gd` / `noncombat_battle_return_scope.gd` / `noncombat_battle_return_integrity.gd` 全部退出 0。integrity 补测先红：缺图恢复被拒绝但未给来源分类；修复后 `SOURCE_UNAVAILABLE` / `SOURCE_MISMATCH` 区分、原字节保留、伪造 outcome/injury/warning 拒绝、非终态拒绝、down 写盘失败及同 token 重试通过。
3. 原 `noncombat_battle_boundary.gd`（8 offer/8 pending）、`noncombat_warning_flow.gd`（5 cases）退出 0；`validate_godot_runtime.py` 的内容/来源前置部分输出 `CONTENT_AND_SOURCE_GATES_PASS`。三个新专项及 oracle 源码 SHA 已注册完整门禁。**本批未重跑整个运行套件，最近全量通过仍是 N9x-03j-p**。
4. 新鲜上下文独立只读审计 `battle_return_readonly_audit`：重跑 scope 和 integrity 通过，确认上述 P1 闭合；最终未发现新确定 P1/P2。因果、师门、涌现 scope 接受静态核实，未各自重复整条长局。Godot 桌面场景真实实例加载原图和 down 按钮检查通过（headless 场景检查，不冒称交互截图验收）。

明确余项与下一批：

- 本批 Godot 测试由合同夹具提交结果；真实 Godot 战斗运行→终态→submit 槽位仍待独立适配器接入。既有 M0 剑修演示不能冒充四修实战。
- victory 仍在写盘前明确拒绝：需接基础奖励 + 来源 victoryEffects、三选一技能/跳过及 `q_mountain_shadow_approach`，不得跳过择法或重复 `combatRewards`。基础胜利奖励无随机数：修为 `5+floor(战前修为/20)`、灵石 `floor((enemy.atkPower || tier || 1)*1.5)`，然后另加来源胜利效果。
- 真正死亡、法宝复活、撤离寿尽不属于当前自然首战可达返回范围，命中时保留待战，待死亡/复活通用消费者后接；没有引入“永远至少一血”的规则。
- 全局 WorldPulse/StoryNetwork 尚未完整迁入，非胜世界变化仍有差异：原败退净 hope-2/instability+3，撤离净 instability+1，以及 card_choice 事件。该部分不计本批完成，后续须与全局历史重演一起迁入，不能从战斗回传开始凭空重置世界状态。
- 荒村/剑冢线程战斗请求、完整战后任务/因果、其他境界、网页旧档、全媒体等按原任务书继续；2/12 线程炼气节点的既有完成数没有因本批虚增。

## 2026-10-21 N9t 集市回归确定性与官坊二次冷却 Slice Charter（验证中）

| Issue | 玩家合同 / 失败机理 | 修复与证据 |
| --- | --- | --- |
| N9t-01 | 集市在第 18 次决定应按已固定的源端测试轨迹排期；此前 `noncombat_market_arrival.gd` 只固定商队和命盘随机数，因果涟漪可在 18 触发并正确占用中断位，令集市顺延 19，造成随机测试失败。 | 修复前全量门禁两次断言 `lastBazaarDecisionIndex=19`，独立重跑亦复现且显示 `lastRippleTurn=18`。测试现同时固定涟漪与天机，保留第 21 次决定、集市 18/24 和严格重放原断言；单项退出 0，随后全量序列已越过该项。生产调度未改。 |
| N9t-02 | 来源 `FlowDirector._drawBySource('shop')` 在 P25 未中后若普通来源选中 `shop`，会再次调用 `CardSystem._checkShopEncounter`；正数冷却需再次减 1，归零才有资格掷骰。旧 Godot P10 只在 8 的倍数直接掷骰，既漏扣冷却又可能多抽货。 | `noncombat_shop_cooldown.gd` 先因 `_secondary_shop_check` 缺失退出 1；修后直接覆盖双检查、非 8 轮减冷却、资格命中设保护 6、旧掷骰回执分支；又从真实第 27 次决定执行 `resume_flow()` 选 `shop` 来源，保存/严格重启，并用真实回执去掉新字段构造旧形状后严格重启。专项退出 0（约 27 秒）；已纳入 `validate_godot_runtime.py`。历史 `normalFlow.draws` 无新字段时仍按修复前规则重放，后续新决定写冷却前后字段。 |

**独立复核与边界**：只读审计未见 P0/P1，并核对来源调用次数与集市固定随机路径。真实 `resume_flow()` 当前覆盖的是第 27 次决定的非 8 轮 P10；第 32 轮同轮 P25→P10、有旧 `phaseShopRoll` 回执的 `restore()` 尚无真实入口证据，仅有内部结算测试。P25 命中仍因真实 `regulated_market` 货单与交易消费者未迁而拒发，本批没有将官坊宣称可玩。完整 `python tools/validate_godot_runtime.py` 已依次通过全部非战斗用例（含新增官坊冷却、优先级、洞府、存档与 UI），随后在并行战斗 `presentation_integration.gd` 失败：木人胸口接触标记距离约 `0.837579`；`stage_router_contract.gd` 因验证器遇错停止未运行。本批不改战斗表现，整体质量门禁未通过。

## 2026-10-20 N9s 洞府原卡与牌组目标 Slice Charter（进行中）

| Issue | 玩家合同 | 来源、权威与反例 |
| --- | --- | --- |
| N9s-01 | 第 30 次决定的 P24 洞府命中应优先于已待发集市；显示 `cards:camp` 原卡及原场景图。左选扣 15 灵石并恢复 2 气血；上选离去。 | `FlowDirector.getNextCard → CardSystem._checkCampEncounter` 发 `camp_meditation`；`game.js` 先按 `costCheck` 扣费，`EffectService` 后应用数值效果。修复前真实 Godot 路线 `noncombat_camp_runtime.gd` 于 P24 发卡断言退出 1。验收为发卡、原文、原图、扣费、可选状态、待选及已选重启、坏盘与失败写盘原态。 |
| N9s-02 | 右选斩牌、下选强化应继续进入可关闭的牌组目标选择，目标实际修改本世牌组并接入战斗读牌；选错、钱不足和重启不能复制或丢牌。 | 浏览器洞府先扣 20/30，再由 `SkillCardAcquisitionSystem.removeCardAt/upgradeCardAt` 分别额外扣来源 `combat:deck_progression` 的 6/8 灵石；至多留 4 张、已升级卡不可再升级。按两个事务保留取消目标的源行为与费用，目标操作使用原卡定义和当前牌组序号。验收包括同名重复卡、存档严格重放、来源漂移与失败写盘。 |

**执行边界**：本批只迁洞府发卡与四选及其牌组目标消费者；P25 官坊、其他境界和并行战斗表现不在本批改动内。原版移牌/强化的双重收费可能让玩家意外，先保持源端规则并在桌面目标界面明确显示二段费用；未来经济改版须另立可比对设计决定。

**当前实施证据**：新增来源读取的 `CampFlow`，P24 命中在同一候选提交中先于待发集市发 `camp_meditation`；原图 `scene_camp.png` 已复制且与网页版 SHA 相同。`Domain` 的 `CAMP_PENDING → CAMP_TARGET_PENDING/FLOW_PENDING` 保留原卡 15/20/30/0 入门费用、满血疗伤禁用、二段目标费用 6/8、取消不返费、原牌位移除及 `+` ID 强化。`campTargetHistory` 在恢复时与完整决定日志一起重放；目标点击带令牌和预期牌 ID，写盘失败不发布变化。桌面明确显示两段费用和目标列表。红测 `noncombat_camp_runtime.gd` 在原 P24 拒发处退出 1，修后专项退出 0：自然第 30 次决定发卡、原卡/原图、待选与离开后严格重启；高余额合成状态检验四选、重复牌位、刚好只有入门费、最低四张、已强化、取消与目标写盘失败回滚。`noncombat_priority_order.gd` 的旧拒发断言已换成真实发卡抢占测试并通过。独立只读复核未见 P1；指出目标 `deckOperations` 少流派/境界字段，现已按网页版补入并在专项断言。

**未证实边界**：高余额移牌/强化还缺从浏览器和 Godot 双方真实开局抵达的同轮轨迹及目标完成后的严格重启；当前测试的高余额状态为测试内合成，不能充作自然可达证明。并行战斗网关目前仅承认首次起始牌组，也尚未解析 `+` 卡的强化效果，故不能称作改牌后战斗可用。P25 官坊仍拒发；完整迁移目标继续保持开放。

## 2026-10-20 N9r 发卡优先级与可回放抽签 Slice Charter（调度与存档日志已实施；消费者待接）

| Issue | 玩家合同 | 源端与当前根因 | 修复前证据 / 验收 |
| --- | --- | --- | --- |
| N9r-01 | 达到商店／营地检查轮次且没有更高优先级卡时，先按原版概率检查 P25 官坊、P24 洞府，再发 P20 集市或 P15 天机／涟漪；同一轮的未触发掷骰仍影响后续抽卡且读档重放一致。 | `src/systems/FlowDirector.js::getNextCard` 在 P55-28 后检查 P25/P24，再处理待发标志；`src/systems/CardSystem.js::_checkShopEncounter/_checkCampEncounter` 以回合号和概率决定是否触发。Godot `noncombat_domain.gd::resume_flow` 先消费 `_market_flow/_ripple_flow/_hint_flow`，只在它们全空时进入 `_draw_normal_after_priorities` 抽 P25/P24；因此待发卡会跳过掷骰。 | 用真实 `Domain.resume_flow()` 构造到期与待发冲突的修复前红测；验证抢占、未抢占时随机值已消耗、同轮幂等、失败写盘原态、待选／已选严格恢复和来源内容引脚。抽到合法 P25/P24 时须有原卡消费者，不能只更改排序后永久阻断可达游戏。 |
| N9r-02 | 超过 30 次选择后仍能从开局严格回放，界面的最近 30 条不应成为唯一决定日志。 | `choiceHistory` 在 Domain 与多个消费者里截断为 30 条，而 `restore()` 原来只从这一数组开局重放；到第 30 次决定的 P24 未命中路线首次显现教程前 3 条丢失。 | 独立 `replayHistory` 保存完整选择，统一事务从所有消费者的 `choiceHistory` 增量同步；保留原最近 30 条语义，严格重启、坏盘和篡改回执拒绝。短历史旧档重放后首次提交升级。 |

**实施边界**：本批只处理 P55-28 之下的 P25/P24 与 P20/P15/P10 仲裁及必要的官坊／洞府原卡消费；不触碰战斗场景。原 `data/cards/camp.json` 四个选项中移牌／强化依赖现有牌组权威，官坊 `ENTER_VENDOR` 依赖商店会话；这些消费者必须按同一状态事务接入或明确作为后续批次的可证伪缺口，不能用假卡替换。N9q 及更早存档需按旧规则严格重放再迁移，不得因为新增抽签字段改写原字节。

**本轮已落实**：`resume_flow` 在高优先级叙事之后、集市/涟漪/天机之前检查 P25/P24；未触发时将掷骰、冷却前后和来源 `cards:camp` 指纹写入 `normalFlow.priorityChecks`，普通抽卡不重复掷骰。旧档在重放时沿原调度，校验通过后下一次提交才升级。专项 `noncombat_priority_order.gd` 先在决断 30 的洞府与合成待发集市冲突上红测，修后验证命中先于集市、P25/P24 未命中消耗随机数、真实 `resume_flow()` 未命中后出集市、实际决断 30 未命中回执保存/重启、伪造回执拒绝与失败原态。冲突所用待发集市由同一真实流程捕获的原 `bazaar_encounter` 合成注入；不能称作浏览器已实跑到决断 30 的同轮证据，也不能把合成集市存档当作自然生成可重放路径。为使该测试可以跨 30 条历史严格恢复，新增全量 `replayHistory`；`choiceHistory` 仍限最近 30 条。已触发的官坊和洞府因消费者未迁移仍在提交前拒绝，**这两个遭遇尚不能游玩**。

**下一批明确消费者**：洞府需从 `cards:camp` 读取原卡与原图，左选在 15 灵石成本和气血上限下结算；右选移牌、下选强化应走牌组权威与可恢复的目标选择，离开选项直接结算。官坊需从 `CardSystem._buildShopCard` 的原文案和 `ShopSystem` 货单构建 `shop_encounter`，右选进入 `regulated_market` 会话；现有 `public_bazaar` 会话不能冒充。上述消费者接入后再把命中路径从 fail-closed 升为可玩，并新增重启/坏盘证据。旧档中在引入完整日志前已超过 30 条且丢失前缀的历史，无法凭现存数据恢复，仍是兼容缺口。

**验证与独立复核**：`noncombat_priority_order.gd` 独立退出 0，含真实 `resume_flow()` 的未命中集市分支、长日志重启、短旧档升级和伪造回执反例；`noncombat_normal_runtime.gd` 与其他非战斗专项在项目验证器中通过。完整 `python tools/validate_godot_runtime.py` 仍在并行战斗的 `presentation_integration.gd` 失败，木人胸口接触标记距离约 `0.83673`，本批未改战斗文件。只读审计未发现本批已实现路径的 P1；提醒下一批官坊消费者必须让 P10 阶段来源的第二次商店检查遵守 `shopCooldown`，否则未来会多消耗随机数。洞府/官坊触发消费者和源浏览器同轮轨迹仍未完成。

## 2026-10-20 N9q 普通卡运行时闭环 Slice Charter（首条真实路线已接通，系统仍未闭合）

| Issue | 玩家合同与单一权威 | 本批验证 |
| --- | --- | --- |
| N9q-01 | 首张天机左选后应由 `FlowDirector.getNextCard → _drawPhaseWeighted → CardSystem.drawNormalCard` 发出原版普通卡；当前 Godot `Domain.resume_flow` 在 P15 后返回 false，画面停在空卡。 | 接通可重放的抽卡游标、来源抽样、完整炼气候选池及原 JSON 卡文；固定浏览器零随机轨迹在决断 27 得 `q_gathering`，决断 28 得 `q_meditation`。待选、已选重启不得更换卡，失败写盘不得改变运行态。 |
| N9q-02 | `GameLogic.handleChoice → EffectService/GameStateManager` 分别负责封顶准入、寿元成本和燃血续命；纯策略已有但没有运行时消费者。 | 采药右选封顶禁用，左选各数值与原版相同；不支持的特殊奖励、死亡/复活路径显式拒绝，不假装已经完整迁移。 |

**权威链**：网页 `src/systems/FlowDirector.js`、`src/systems/CardSystem.js`、`src/game.js`、`src/core/GameStateManager.js` 及 `data/cards/*.json` → Godot 只读 `ContentRepository`/`NormalDrawPolicy`/`NormalChoicePolicy` → `Domain.resume_flow/choose` → 原子 `RunSession` → 桌面 `noncombat_opening_ui`。`noncombat_normal_runtime.gd` 先在决断 27 无续卡处失败，接线后以来源零随机轨迹验证 `q_gathering`→`q_meditation`、封顶按钮、原图、待选/已选恢复、伪造抽签回执拒绝和写盘失败原态回滚。纯策略专项另覆盖完整炼气 26 张候选、独立 COMBAT 寿元、`q_market` 第三选、实际生命上限参与情绪，以及选择后被动回血在燃血前生效；`shops:treasures` 与 `config:path_skills` 已纳入来源引脚。

**当前明确缺口**：P25/P24 调度与全量决定日志已在 N9r 补入；命中官坊/洞府后仍需原卡消费者，不能算可玩的遭遇。早期 N9q 存档缺少两份被动引脚时，目前仅验证首张普通卡待选且无被动的旧形状可严格重放并在下一次提交升级；已结算且有回血被动、或跨越营地/商店掷骰的早期 N9q 存档仍需要专属旧规则回放，不能宣称通用兼容。其他境界、同伴被动、死亡/复活、复杂奖励与后续分支仍需逐项接入。当前通过的是上述首条路线，绝非非战斗完整迁移。

**本轮验证**：`noncombat_normal_draw_policy.gd` 与 `noncombat_normal_runtime.gd` 均独立退出 0；后者约 69 秒，因此总门禁只给该专项的上限改为 120 秒，没有改变断言。`python tools/validate_godot_runtime.py` 重跑已通过所有排在 `presentation_integration.gd` 之前的测试（含本轮普通卡、存档与桌面 UI），最终在并行战斗表现的胸口命中点断言退出 1：距离 `0.83668184280396`、偏移 `(0.550552, -0.425575, 0.464558)`。此失败不由非战斗卡流修改触发，项目总门禁不能写为通过；后续战斗用例因该处提前退出尚未验证。

## 2026-10-20 N9p 普通抽卡与采药续卡：来源核对及候选策略底座（运行时待接）

新增只读实跑 `artifacts/godot-migration/noncombat_normal_draw_browser_trace.jsonl`，从剑修真实开局经过师尊回应、第二次坊市和首张天机，固定 `Math.random=0` 到达决断 27 的 `q_gathering`。此时 `FlowDirector.exportState` 为 `phase=BUILDUP, phaseProgress=30, cardCount=18, lastDrawSource=normal:BUILDUP`；采药左选后决断 28 是 `q_meditation`，游标进到 `phaseProgress=36, cardCount=19`。不能以 `cardsPlayed` 长度代替 `cardCount`，因为高优先级插入与摊位内部动作不等于每次抽卡。`CardSystem.getNormalDrawBuckets` 在决断 27 的当前境界桶有 **26** 张可抽卡，来源不仅是 `cards:qi`，还包含魔道、叙事对话、世界氛围等已缓存模块；筑基前 `previous` 与 `evergreen` 桶为空。比如 `q_gathering` 基础权重 10、`q_meditation` 14、剑修专属 `q_swordTomb` 9.5。只读取炼气期 14 张普通卡会悄悄改变概率，不能作为迁移实现。

| 待实施单元 | 源权威与验收 |
| --- | --- |
| N9p-01 调度游标与普通池 | 从 `FlowDirector.getNextCard/_drawPhaseWeighted` 恢复五阶段、进度、卡数、饥饿、情绪、来源抽样和高优先级让位；从 `CardSystem.init/getNormalDrawBuckets/isCardEligibleForNormalDraw/drawNormalCard` 取得完整缓存候选、资格、最近 8 张冷却、72/18/10 境界桶与卡内权重。抽样记录进 RunSession 以便严格重放，不能只写选中 ID 或固定 `q_gathering`。先对齐此实跑的 26 张候选与两个游标，再扩四修和不同随机值。 |
| N9p-02 普通卡选择与生死 | `q_gathering` 正文、双选、原图从 `data/cards/qi.json` 读取，封顶右选禁用。左选源实跑：气血 1→0 后 `GameStateManager.checkDeath` 燃血续命，气血/道心上限 5/4→4/3，最终气血 1、道心 4→3；`_shouldConsumeLifespan` 另外让寿元 76→75，决断 28 出 `q_meditation`。上限不足时应走来源死亡/复活判定，不以单个固定轨迹替代。验证待选、已选、续卡及失败写盘重载。 |

`noncombat_normal_draw_policy.gd` 已从可校验的来源模块构造候选目录，实现当前/上一/常青境界桶、资格、最近 8 张冷却、基础权重、情绪标签加权与给定随机值的卡内抽样；还原五阶段游标的纯计算及固定零随机的来源选择，但尚未把游标写入 RunSession，也不发布卡或结算选择。新跨运行时专项 `noncombat_normal_draw_policy.gd` 以实跑精简 fixture 对比 26 张候选的 **有序 ID 与逐张基础权重**，固定零随机先得 `q_gathering`、将其列入最近 8 张后再得 `q_meditation`，并以来源游标验证第 13 次抽卡转入 BUILDUP、第 18/19 次进度为 30/36；已纳入验证器。当前 Godot 仍停在首张天机左选后的 `FLOW_PENDING`；游标的实际提交/旧档升级、P10 来源抽样与完整叙事准入、普通卡实际选择及燃血/死亡消费者都未接通，不能把候选策略专项通过写作 N9p 已完成。其余非战斗缺口见任务书总表。

`noncombat_normal_choice_policy.gd` 另以来源 `cards:qi` 为权威，对无特殊奖励字段的普通卡预演数字效果、封顶按钮与气血归零后的燃血续命；同一实跑 fixture 验证采药左选的全部八项属性、资源、上限及吐纳卡按钮。上限不足需进入尚未迁移的死亡/复活消费者时、遇到同伴等奖励字段时会显式拒绝，不伪造奖励，也不写盘。候选策略专项当前只证明炼气期；其它境界显式拒绝，待对应候选池与剧情账本准入逐境界对照后再开放。

## 2026-10-20 N9o 天机一闪首张可达卡 Slice Charter（已实施；专项通过）

| Issue | 来源与玩家可见缺口 | 验收合同 |
| --- | --- | --- |
| N9o-01 | 浏览器 `noncombat_bazaar_second_right_browser_trace.jsonl`：师尊回应后第二次坊市右选，第 26 次决定发出 `heavens_hint:*:16:0`。`HeavensHintSystem` 在第 16 次决定生成序号 0 的吉兆，却因更高优先级事件延到第 26 次才可见。旧 Godot 在坊市右选后 `resume_flow()` 没有此待发卡。 | 由原 JS 机械导出 40 条预言，保留本次生成与待发编号、来源文本、时钟、P15 优先级；第 26 次决定发原卡。卡两侧可选状态、效果、原子写盘/回滚、待选与已选严格重放，以及旧档不改原字节均需验证。 |

**来源与实施**：`tools/export_heavens_hint_pool.js` 从原 `src/systems/HeavensHintSystem.js` 导出 40 条原诗文与解释，验证器检查 JS SHA `67f2f543bbbc04f340cee18afb00d7f43cbae28dd9e65d3eb2a15cac31ef12c2` 和派生 JSON SHA `16946a5d930631f36a610ceb42cbb063ea7b68d56c15a7b814f688427f4df209`。`noncombat_heavens_hint_flow.gd` 在命盘、涟漪之后与坊市之前记录时钟、生成历史和待发卡；恢复时由来源编号重建，不信任存档内文案和效果。当前固定随机 0 路线与网页一致：生成决断 16、下一次触发 31、到决断 26 仍为同一吉兆，天机揭示度记录 +3。源卡未配置 `sceneImage`，桌面采用正文卡布局而不虚构一张剧情图。

**选择与边界**：`noncombat_bazaar_hint_left_browser_trace.jsonl` 记录决断 26 左项可选、右项 `all_positive_rewards_capped` 禁用；左选后决断 27 灵石 13→16，网页下一张是普通卡 `q_gathering`。Godot 专项 `noncombat_heavens_hint.gd` 先红后绿：同路线原文/时钟/发卡、封顶禁用、合成未封顶右选、桌面按钮、写盘失败回滚、待选及已选读档、畸形随机种子拒绝且不改字节均通过。当前只把凶兆长期减伤、特殊预言线索写入可持久的非战斗桥接字段；战斗减伤消费者、天机老人关系引擎及普通卡 `q_gathering` 的完整消费者尚未接通，不能把 40 条来源池等同于 40 条完整剧情闭环。旧 N9n 档缺少天机 RNG/历史，恢复后从下一次玩家决定激活新时钟，无法反推其过去未存下的随机提示。

**同决断仲裁补验**：浏览器 `game.js` 在新天机占据后置中断槽时跳过当次普通坊市 tick；独立只读审查据此发现 Godot 可能同时排天机与坊市并提前重置后者时钟。现 `noncombat_market_flow.gd` 检查本决断新签发的天机事件，保持到期坊市未消费；`noncombat_heavens_hint.gd` 用两个时钟同决断到期的合成状态固定该边界。N9p 应从网页版 `q_gathering` 继续，但必须先移植 `FlowDirector._drawPhaseWeighted → CardSystem.drawNormalCard` 的情绪、境界准入、最近 8 张冷却和权重来源；不可为这条轨迹硬编码 `q_gathering`。选择结算还需验证低血扣血、死亡转移、原图、读档和下一次抽卡。该段尚未实施。

**N9p 新的源端事实**：`noncombat_bazaar_gathering_left_browser_trace.jsonl` 显示当前气血 1 的 `q_gathering` 右项因修为/道心封顶被禁用；左项仍可选。左选后决断 28 气血保持 1、寿元 76→75，下一张普通卡为 `q_meditation`。源码 `src/game.js::_shouldConsumeLifespan` 对负气血选项扣 1 寿元，`src/core/GameStateManager.js::checkDeath` 在气血归零时先执行“燃血续命”：气血与道心上限各减 1，再把气血设回 1；只有上限不足且复活手段未拦截时才确认死亡。旧说明“负气血改付寿元”错误，已纠正。普通卡结算必须同时核对这两个独立机制与实际死亡阈值，不能把 `health:-2` 直接解释成死亡或单一代价替换。

**2026-10-20 门禁复核**：真实旧 N9m fixture 的 `battleCardSourceSha=00338d…`，当前并行战斗任务更新后的 `cards:battle_cards` 来源 SHA 为 `2d8e08…`；原文件应由来源钉校验以 `SOURCE_MISMATCH` 原字节拒绝，不能为让测试变绿而改写旧档。`noncombat_mentor_trusted.gd` 同时用当前来源封装的 v1 师尊阶段样本验证同决断升级和重启，并用原字节 fixture 验证漂移拒绝。`python tools/validate_godot_runtime.py` 已跑过全部非战斗专项，最终仍在并行战斗的 `presentation_integration.gd` 木人胸口接触标记距离 `0.83675664663315` 处退出 1；项目总门禁未通过。

## 2026-10-20 N9n 白刃师尊第二阶段与涟漪后续 Slice Charter（已实施；专项通过）

| Issue | 来源与玩家可见缺口 | 验收合同 |
| --- | --- | --- |
| N9n-01 | 固定浏览器轨迹 `artifacts/godot-migration/noncombat_bazaar_ripple_right_browser_trace.jsonl` 在决断 22 选择因果涟漪右项后，决断 23 当前卡为 `mentor_bai_ren_stage_TRUSTED`，标题“师尊·真相”。原 `StoryNetworkSystem.MentorArcEngine` 在传承值 40 从 `INNER_DISCIPLE` 进入 `TRUSTED`，卡文及两选效果来自 `data/companions/arcs.json`。Godot 现 `MentorFlow` 把阶段、卡 ID 与回应卡来源均写死为首阶段，涟漪后 `resume_flow()` 无法发出真实续卡。 | 从真实剑修→集市→涟漪路径先红测；以来源阈值/队列保留首阶段，同时让二阶段在相同决断与相同优先级发出。正文、效果、立绘仍读原 JSON 与素材清单；两选各自数值、回应回执、桌面入口及存档重放通过。旧首阶段专项不得退化。 |

**实施边界**：阶段推进、卡投影、选择结算和回应归属必须在同一批改完，不能只改阈值后留下无法选择或无法恢复的当前卡。此批只处理当前实跑到达的第二阶段；`HEIR`/`LEGACY`、秘闻及渡劫高潮依各自原版触发条件另批验证。

**N9n 实施与证据**：红测 `noncombat_mentor_trusted.gd` 沿 N9m 真实剑修→集市→因果涟漪右选路径复现决断 23 无师尊卡，状态虽有传承度 40 仍停 `INNER_DISCIPLE`。`noncombat_mentor_flow.gd` 现依来源 20/40 门槛顺序排入两阶段，不丢跨阈值的前阶段卡；当前队列决定来源 `arcs.json` 卡文、效果、稳定卡 ID 与原 `portrait_stages.json` 立绘。`noncombat_domain.gd` 的令牌及回应归属识别两阶段，`RunSession` 在选择后保存 `mentorPromise`。浏览器 `noncombat_bazaar_trusted_left_browser_trace.jsonl` 实跑为决断 23 `mentor_bai_ren_stage_TRUSTED`、传承 40、入阶段时刻 22；左选后决断 24 业报善 +15（36→51）、回应卡 `promise_result_c500a306`。Godot 专项逐项核对卡、阶段、数值、回应 ID、坏盘回滚、待选与已选重启严格重放及桌面原立绘。

**右选来源限制**：`noncombat_bazaar_trusted_right_browser_trace.jsonl` 显示同一路线右选 `daoHeart +5` 与 `cultivation +10` 均已封顶，网页版预览给 `all_positive_rewards_capped` 并禁用按钮；Godot 同样在状态层拒绝并在桌面禁用，失败不改存档。合成未封顶修为时右选保留原版两项效果，可选且结算。已有 `noncombat_mentor_arc.gd` 两个首阶段分支及 `noncombat_karma_ripple.gd` 回归复绿。该合成右选验证不等同于原版可达的另一条未封顶路线。

**旧档兼容补丁**：独立复核以真实 N9m `FLOW_PENDING` 决断 23 存档发现，若直接按二阶段规则重放，会把原来 `mentorArcState.version=1` 的 `INNER_DISCIPLE` 状态改为 `TRUSTED`，导致整档严格校验失败。已保存原始字节至 `tests/fixtures/legacy_n9m_ripple_decision23_v2.json`（SHA-256 `041769ee204eac5e145f50118991cd2af8ec5384a52bb67812d6190ca9947b99`）。新增阶段规则版本 2：版本 1 只在重放期间沿历史单阶段规则重建；校验通过后不改原文件，在玩家 `resume_flow()` 的首次事务中于原决断号补排 `TRUSTED`，写成版本 2。专项先红后绿，并核对原字节、同决断升级及升级后再次严格读档。旧档更早节点及其它中断形态仍需随消费者持续覆盖。

**续线与坏档反例**：浏览器新轨迹 `noncombat_bazaar_trusted_ack_browser_trace.jsonl` 证明第二阶段左选回应确认后，决断 25 显示另一张原 `bazaar_encounter`；该卡在决断 24 已排期，`lastBazaarDecisionIndex=24`、`nextBazaarDecisionIndex=30`。Godot 同路由在确认、读档及恢复后与三项时钟一致。将真实旧档的阶段版本改为对象曾触发 `SCRIPT ERROR`，现先校验数值类型、整数性及版本范围，坏档干净拒绝且文件字节不变。独立只读复核未再发现此批可复现 P1/P2。`python tools/validate_godot_runtime.py` 的非战斗专项全部通过；完整项目门禁仍在并行战斗 `presentation_integration.gd` 的胸口接触标记距离 `0.83675664663315` 失败，不能报告整体通过。

## 2026-10-20 N9m 因果涟漪待发槽与离摊后续卡 Slice Charter（已实施；专项通过）

| Issue | 原版实跑与来源机制 | 出门条件 |
| --- | --- | --- |
| N9m-01 | `KarmaRippleSystem.tick → FlowDirector.setPending('ripple')`。固定随机 0 的 `artifacts/godot-migration/noncombat_bazaar_ask_luo_dismiss_browser_trace.jsonl` 显示决断 5 生出 `karma_ripple:...:5:causal:sword_legacy_start`，冷却 8 次决定后决断 13 由 `...:13:causal:qi_sword_attune` 覆盖同一个 P15 待发槽；决断 21 仍因更高优先级坊市未出，离摊关闭决断 22 后才被提取为当前卡。`karmaRippleState.lastRippleTurn=13/totalTicks=21`，离摊本身不再 tick。 | 复用来源种子，不消费种子；按 8 次冷却、当前活跃种子和真实顶层决断 tick，保存历史与单槽覆盖。恢复时从已钉住的模板来源重建，不能把存档里的效果字段当作者规则。P15 必须排在里程碑、任务、业报、坊市后。离摊结果卡收起后在决断 22 显示同一 `KARMA_RIPPLE`，中途重开不重抽/重发。 |
| N9m-02 | 源 `KarmaRippleSystem._rippleTemplates` 为四种种子类型提供文案、两选效果、来源场景图；`game.js` 结算顶层选择。当前 Godot 离摊结果卡收起后 `resume_flow()` 返回 false，停在 `FLOW_PENDING`，故缺失真实后续决定。 | 从源 JS 自动导出并校验模板/脚本 SHA；迁入两选的通用数值效果、决定回执和下一卡调度，桌面原图消费、保存后重启、过期令牌与失败写盘专项通过。不能将固定轨迹的 `q_gathering` 当作未结算涟漪的替代卡。 |

**先后关系**：先写从真实开局→坊市→离摊→结果收起的红测，再移植早期 tick/槽位重建；最后接展示、选择与重载。第 49 次访摊/30 条选择历史的长局重放为另一个存档架构缺口，不能用本切片的短链结果声称已解决。

**N9m 实施与可复现证据**：`tools/export_karma_ripple_templates.js` 从原 `src/systems/KarmaRippleSystem.js` 导出四类模板至 `godot/content/derived/karma_ripple_templates.json`，源脚本 SHA `b4bb05e930b97e607059b7802b6f0feb0d3723a3ae87ae95310aa8072c065e4c`、派生模板 SHA `3679b95d6e3df93435f4f9caec44fbd0709c0439166f37a086d8cebec9bcc2e5` 进入验证器和存档来源钉。`noncombat_ripple_flow.gd` 按来源节拍生成待发槽、冷却及历史，发卡时从模板与已记录的种子重新构造文案、效果和图片，图片须同时通过来源清单 SHA 与可加载纹理校验；`RunSession` 只在一次事务成功后保存。`noncombat_karma_ripple.gd` 在真实剑修→坊市→罗师傅询问→离摊→结果收起路径上先因缺 P15 失败，修后检验第 5/13 次决断的覆盖、第 22 次决断出卡、右选数值、失败写盘与重启重放、桌面原图及按钮。补充合成边界覆盖旧种子 1→0 与 0→0、新涟漪与市场同回合到期时市场让位、血脉左选 `maxHealth` 同步补当前气血；缺图/坏图待发及已选择存档重放拒绝并保留原文件。师尊立绘无效时的高优先级错误不能被涟漪卡掩盖，旧专项已复绿。独立只读复核：当前 N9m 可复现范围无剩余 P1/P2。

**范围边界**：上述源端固定轨迹与血脉/市场合成边界不能代表四修全路、完整长期种子生命期、所有中断对涟漪 tick 的抑制、30 条选择历史以后的整档恢复；旧 Godot 档如已停在 N9m 之前的 `FLOW_PENDING`，仍需专门升级策略。下一批应沿来源卡真实消费者继续推进，不能把 N9m 发卡误作完整非战斗迁移。

**N9m 总门禁**：`python tools/validate_godot_runtime.py` 已纳入来源模板导出校验及 `noncombat_karma_ripple.gd`，完整运行后所有非战斗专项通过；项目总门禁最终仍在并行战斗 `presentation_integration.gd` 失败，胸口接触标记距离约 `0.83675664663315`。N9m 没有更改战斗舞台、角色动作或接触标记代码；不可将此结果写作项目整体通过。

## 2026-10-20 N9l 询问锈剑流转号 Slice Charter（已实施；非战斗门禁通过）

| Issue | 浏览器来源实跑与权威 | 本批验收 |
| --- | --- | --- |
| N9l-01 | `ShopSystem.executeVendorAction('ask_luo') → _applyCostSpec → NarrativeLedger.recordFact → marketState.activeSession`。`artifacts/godot-migration/noncombat_bazaar_ask_luo_browser_trace.jsonl`：开摊决断 21 灵石 14；询问后同一决断灵石 13、罗摊关系 1、交谈额度 2→1、`ask_luo` 回执含 `fact:0:rumor_rusted_sword_origin`，该事实 `createdDecisionIndex=22`；离摊决断 22，结果卡交易数仍 0、交谈数 1、花费栏仍 0。 | 只从原动作 `costSpec/causalFact` 读取费用、事实类型/生产者/载荷，余额与同世唯一性前置；扣款、关系、额度、回执、来源事实同一次提交。失败写盘不产生半条事实；重启严格重放；下一次来访已经记账则不可再问。桌面按钮及余额显示真实规则。官坊订购消费者另批。 |

**执行边界**：`marketActionHistory` 只记录输入，用来源动作重建当前会话；来源事实与 1 灵石支付同时保存在 RunSession。因果图已在本世剧情钉版本，任何热态漂移不得提交新状态。覆盖实际首次集市入口和合成再次来访；真正第二轮市场节拍仍未完成端到端验证。

**N9l 实施与证据**：首个 Godot 专项因 `ask_luo` 未在 UI/动作表开放而退出 1；修后从原 `vendor_profiles.json` 的 `costSpec/causalFact` 扣 1 灵石、关系 +1、交谈额度 -1，并写 `fact:0:rumor_rusted_sword_origin`、有事实 ID 的动作回执与摘要，决断 21 保持不变，离摊才进 22。`noncombat_bazaar_ask_luo.gd` 验证无钱拒绝、坏盘原字节不变、重复询问拒绝、恢复后会话严格重建、离摊/结果收起、下次入摊同世唯一性和桌面按钮。`artifacts/godot-migration/noncombat_bazaar_ask_luo_then_sword_browser_trace.jsonl` 的组合实跑显示询问后灵石 13、凭关系购剑后 7、两类事实同时存在；Godot 专项同链组合投影一致。官坊订购及三次决断后的旧主事件尚未接入，不能称流转号已经被剧情消费。

**独立复核**：N9l 当前可达交易无可复现 P1/P2；代价不计入购买摘要符合网页版。第 49 次访摊会裁掉旧付费交谈输入，且更早的 30 条 `choiceHistory` 截断已经阻断长程整档重放；本批只证明首访与合成下一访，**不证明** 48+ 次访摊或长局恢复。流转号事实的时间窗关闭和官坊消费仍待独立迁移。

**N9k/N9l 总门禁**：`python tools/validate_godot_runtime.py` 已纳入两条专项并完整运行，所有非战斗测试及先前战斗基础专项通过，最后仍由并行战斗 `presentation_integration.gd` 的木人胸口接触点偏移 `0.68133342266083` 退出 1。项目总门禁未通过；本批没有修改战斗舞台或接触点代码。

## 2026-10-20 N9k 易手残剑、人情交易与穿戴待决 Slice Charter（已实施；灵茶模式另批）

| Issue | 网页实跑事实与单一权威 | 本批验收 |
| --- | --- | --- |
| N9k-01 | `ShopSystem._resolveCostMode → _purchaseTreasure → TreasureSystem.acquire → NarrativeLedger.recordFact`。`artifacts/godot-migration/noncombat_bazaar_vendor_buy_rusted_sword_browser_trace.jsonl` 实跑：先 `assist_luo` 使许摊关系 1，在同一决断 21 选择 `favor` 购买，灵石 14→8、报价 4→3、取得 `tr:traded_rusted_sword:1`、来源 `public_bazaar_trade`，生成 `fact:0:sword_origin_traded` 和 `pendingLoadoutDecision`；离摊到决断 22 后待穿戴仍在。 | 不能只放一把 ID 到资源数组。此批只按原 `favor` costMode 验人情和 6 灵石，再以法宝实例写入器、来源事实和会话摘要同次提交；失败不扣款、不发事实、不掉库存，重试/重载不重复。`gift` 须有真实灵茶所有权和源端轨迹后另批验收。 |
| N9k-02 | `_buildPendingLoadoutDecision/resolveLoadoutDecision` 使新得法宝可穿戴或收入纳戒，待决结构包含实例、交易回执、槽位与允许动作；来源浏览器买剑时打开穿戴弹层，关闭弹层只是暂缓决定，离摊不清除待决。 | Godot 桌面显示可恢复的穿戴/收纳决策，来源 `TreasureSystem` 的装备槽与库存派生状态一致；无法走“关闭 UI 即默认穿戴”，也不能因未迁界面而丢掉待决。 |

**依赖与裁定**：当前 `noncombat_treasure_acquisition.gd` 只写命盘来源回执，必须先扩为可传入来源/交易 ID 的统一实例写入，保持旧命盘用例通过。当前 `noncombat_milestone_flow.gd` 的 `spineFacts` 可作为同世因果事实宿主，但必须核对 `NarrativeLedger` 事实唯一性、消费者时间窗与旧档重放。残剑源码还带 `narrativeProvenance` 和两个 `costModes`；N9j 的 `itemInventory` 只为 `gift` 模式提供真实灵茶库存检查，不表示玩家当前已持有灵茶。先补失败专项和两模式浏览器证据，再开放入口。

## 2026-10-20 N9j 集市商路札记与物品所有权 Slice Charter（实施中）

| Issue | 浏览器实跑与源状态所有者 | 本批验收 |
| --- | --- | --- |
| N9j-01 | `ShopSystem.purchase → _purchaseWithCostSpec → GameStateManager.addItem`。固定剑修路径 `artifacts/godot-migration/noncombat_bazaar_vendor_buy_route_note_browser_trace.jsonl`：入摊灵石 14、`itemInventory={}`；购 `bazaar_luo_route_note` 后灵石 9、`itemInventory.商路线索=1`、四件库存变三件；离摊决断 22。 | 只迁来源 `story_item` 现金报价“旧商路札记”及物品数量，扣款/加物/移库存/回执原子提交；恢复后仍为 1，重复购买和坏盘不得重复发物；桌面真实按钮显示、购买后从库存消失并展示随身物品。苏鉴师灵茶换物、残剑双代价、官坊线索消费者另批。 |

**实施边界**：物品 ID、数量、价格只读复制的 `vendor_profiles.json`；`itemInventory` 与网页版 `GameStateManager` 一样是 `{itemId:count}`，不把商品名当拥有物，也不因获得线索就提前触发尚未迁移的世界/官坊分支。

**N9j 实施与证据**：`noncombat_bazaar_story_item.gd` 在真实剑修→集市路径先因来源报价不可购退出 1；`noncombat_vendor_flow.gd` 将现金报价的 `story_item` 纳入原购买事务，按作者 `effect.itemId/quantity` 写 `itemInventory`，保留 N9i 的余额/库存/来源校验和购买输入重放。浏览器实跑入摊灵石 14、空物品栏，购买后灵石 9、`商路线索×1`、报价 3 件；Godot 专项匹配决断 21/22、结果卡“花费 5 灵石”、失败写盘原字节不变、重复购买拒绝、开摊及离摊严格恢复。桌面按钮点击后物品所有权可见，商品立即从库存消失；残剑与苏鉴师换物仍因缺少对应代价/来源事实链而不可购。

| N9j 声明 | 入口→写入→消费 | 当前验证 |
| --- | --- | --- |
| 商路札记真实购买 | `VendorBuy_bazaar_luo_route_note → Domain.purchase_vendor_offer → VendorFlow.purchase_offer → RunSession`；`itemInventory.商路线索` 由状态与 UI 读取 | 浏览器同一会话来源轨迹与 Godot 专项匹配灵石 14→9、物品 0→1、库存 4→3；坏盘、重复输入和恢复通过。 |
| 来源范围 | 原 JSON `story_item` 现金报价，原 JS `ShopSystem._applyItemEffect`/`GameStateManager.addItem` | 没有把商品名误作物品 ID，也没有用 `sceneImage` 或文本冒充拥有权。独立只读复核 VERIFIED、无可复现 P1/P2；混合购买/交谈顺序与 30 条选择历史以外的整档重放尚无端到端实证。 |

**N9i/N9j 总门禁**：`python tools/validate_godot_runtime.py` 在修复第 49 次记录及纳入 `noncombat_bazaar_purchase.gd`、`noncombat_bazaar_story_item.gd` 后完整运行；所有非战斗专项及紧接的战斗基础专项通过，最终在并行战斗 `presentation_integration.gd` 的木人胸口接触标记距离 `0.68311780691147` 退出 1。故不能宣称项目总门禁通过，此失败不由本批非战斗文件改写。

## 2026-10-20 N9i 集市疗伤散购买 Slice Charter（实施中）

| Issue | 网页权威链与红线 | 本批验收 |
| --- | --- | --- |
| N9i-01 | `ShopSystem.purchase → _purchaseWithCostSpec → _applyItemEffect(pill.healHp) → _syncPendingVendorSession`。实跑 `artifacts/godot-migration/noncombat_bazaar_vendor_buy_healing_browser_trace.jsonl`：决断 21 入摊时灵石 14、气血 1、四件库存；购 `bazaar_han_healing` 后同决断灵石 10、气血 3、剩三件库存、`purchaseCount=1/spiritStoneSpent=4`；离摊决断 22 产生“集市 · 摊主记名”，到访 `refused=false/outcome=traded`、剩三件。 | 只接来源药散两类 `pill.healHp`（普通与关系专供）；报价冻结、价格/气血上限校验、扣款/疗伤/库存/购买回执同一次 RunSession 提交；坏盘回滚、重复购买拒绝、重载重放、无钱拒绝、桌面购买入口与浏览器数值一致。故事道具、残剑/装配、换物和因果事实继续禁用。 |

**实施依赖**：N9h 已把会话与离摊事务接通；本切片须扩会话来源重建以识别已购买报价，保留购买输入历史供严格重放，关闭结果从剩余库存和真实购买数生成。任何价格/效用从已复制 `vendor_profiles.json` 读取，禁止重新编一份货表。

**N9i 实施与证据**：`noncombat_bazaar_purchase.gd` 先在真实剑修→集市路径对“无购买命令”退出 1；浏览器 `noncombat_bazaar_vendor_buy_healing_browser_trace.jsonl` 给出同一 `sessionKey` 的购买前后状态。`VendorFlow.purchase_healing` 只识别作者 `pill.healHp` 报价，从冻结的来源会话取价并在一份候选快照中扣灵石、加气血、移除报价、追加购买摘要与重放输入；`Domain.purchase_vendor_offer` 通过已提交快照校验、选择令牌和 RunSession 单次提交。桌面 `VendorBuy_*` 按真实剩余库存生成，余额不足禁用，购买后摊位文本立即去掉售出的药散。直接测试验证灵石不足/气血上限，真实路径测试验证失败写盘原字节不变、重复购买拒绝、打开及关闭后的严格重放、结果卡和到访 `outcome=traded`；桌面控件点击确实到达权威状态。来源货表、`game.js` 与 `ShopSystem.js` 散列仍由总门禁固定；其余故事物品、残剑、换物、因果事实以及鬼市仍禁用。

| N9i 声明 | 入口→写入→读取 | 当前验证 |
| --- | --- | --- |
| 药散来源价与原子购买 | `VendorBuy_bazaar_han_healing → Domain.purchase_vendor_offer → VendorFlow.purchase_healing → RunSession`；重开通过 `_replay_vendor_actions` 消费 `marketPurchaseHistory` 并全状态比较 | 浏览器固定轨迹：灵石 14→10、气血 1→3、报价 4→3 件；Godot 专项通过购买、余额不足、气血上限、坏盘回滚、重复输入、打开会话重放。 |
| 关闭、结果和桌面库存 | `VendorClose → VendorFlow.close → marketState.visitHistory/pendingVendorResultCard`；UI 从剩余 `immutableOffers` 展示 | 浏览器与 Godot 均为决断 22、交易 1 笔、花费 4 灵石、剩 3 件；专项验证关闭重放、真实按钮及售后库存。独立审查发现第 49 次来访原逻辑会丢弃早期购买输入；新增失败回归后改为保留，并验证被裁剪会话的来源、生命和决定序号，复核 VERIFIED、无余下可复现 P1/P2。 |

**仍缺**：熟客下一次入摊的折扣与专供药包尚无浏览器多次来访轨迹；现有实现按来源关系字段计算，但不能声称该长线已完成实跑对照。第 49 次来访测试是来源会话投影的合成回归，完整 `Domain.restore` 长程重放仍受原有 30 条 `choiceHistory` 截断架构限制。N9j 需优先处理故事物品所有权及重复获取规则，N9k 再处理带两种代价模式和因果来源的残剑；`ask_luo` 的事实生产与官坊消费另设切片。

## 2026-10-20 N9h 坊市左选会话与关闭回执 Slice Charter（首批接通，交易待续）

| Issue | 网页实际链路 | 本批验收 |
| --- | --- | --- |
| N9h-01 | `GameLogic.makeChoice(ENTER_VENDOR) → MarketSystem.createVendorSession → ShopSystem.open` 先写 `marketState.activeSession.status=open`，`decisionIndex` 保持 21；快照里固定三摊、四件当前报价、两次深度来往额度、`sessionKey=vendor:slot_1:life:0:22:bazaar_encounter:public_bazaar`，当前卡变 `VENDOR_PENDING`。真实空手访问 `artifacts/godot-migration/noncombat_bazaar_vendor_empty_browser_trace.jsonl`。 | Godot 左选从来源 `vendor_profiles.json` 冻结摊位、报价、服务及背景，打开会话不提前计时/领赏，失败写盘无泄漏；重启恢复同一会话和报价。 |
| N9h-02 | `shop:closed → _handleVendorClosed → _finalizeTurnAfterVendor` 在认证 `sessionKey/vendorId/entryCardId` 后一次性结算原 `bazaar_encounter` 左选、到访记录与 `VENDOR_RESULT`。空手离开在决断 22，结果卡 `vendor_result:1:bazaar_encounter`；右键收起结果卡只是内部过渡，来源选择历史记 23、决定时钟仍 22。互动 `assist_han` 在关摊前把额度 2→1、关系 0→1、回执写入会话，离开结果变“集市 · 摊主记名”。来源 `noncombat_bazaar_vendor_assist_han_browser_trace.jsonl` 与 `noncombat_bazaar_vendor_dismiss_browser_trace.jsonl`。 | 会话互动、关闭、结果卡、回执、旧档重放和失败写盘同源同事务；只在关闭时推进一次决定。购买/换物/因果事实要在随后交易切片完成，若未实现须在界面明确禁用，不能把空手关闭当完整商店。 |

**实现顺序**：先为未完成的左选写真实路径红测；从来源档构建不可变快照，保留卡与令牌直至关闭；实现 sessionKey 和对应 close；再接来源互动回执、恢复与结果卡，最后才开购买、换物、因果线索。Godot 存档只由 RunSession 写，页面可见会话不是第二份经济状态。

**本批实施与证据（2026-10-20）**：`noncombat_vendor_flow.gd` 从 `vendor_profiles.json` 的公开集市档冻结三摊、四件报价、交谈额度与来源背景；`noncombat_domain.gd` 让左选写入 `VENDOR_OPEN` 而决定时钟停在 21，交谈 `assist_han`、`assist_luo`、`barter_su` 以来源 action 回执修改关系并递减额度，关闭时核验 sessionKey/entryCardId 后一次性生成到访记录、决定 22 和 `VENDOR_RESULT_PENDING`，结果卡右选内部收起不再推进时钟。`marketActionHistory` 是 Godot 重放所需的有序动作输入，只保存 action ID/sessionKey；来访记录按来源上限裁到 48 时，同步裁掉旧动作并把已积累的关系写入 `vendorRelationBaseline`，避免正常多次来访被误拒。入摊、交谈、离摊先核对当前状态等于已提交快照；会话里的摊位、报价、额度、交谈摘要均按来源重新投影核对。桌面故事界面显示来源背景、摊主与库存名称、交谈和离摊按钮；缺少事实账本的 `ask_luo` 与四件货品的购买/换物暂不开放，文字明确标记交易待接入。此批不能算完整商店。

| N9h 声明 | 真实入口/写入/读取 | 测试与状态 |
| --- | --- | --- |
| N9h-01 入摊不计时、冻结来源摊位并可恢复 | `SourceChoices/Choice_left → NoncombatDomain.choose → VendorFlow.open → RunSession.commit_snapshot`；`get_current_card` 和 UI 读取 `marketState.activeSession` | `noncombat_bazaar_vendor.gd` 修复前因左选不可进退出 1，修复后入摊、坏盘回滚、来源图片和 UI 按钮点击、打开后重载通过；伪前史注入先红后绿。网页版参考 `noncombat_bazaar_vendor_empty_browser_trace.jsonl`。独立审查 VERIFIED。 |
| N9h-02 交谈、关闭、结果卡与收起 | `VendorAction_assist_han → perform_vendor_action → marketState.vendorRelations/actionReceipts/marketActionHistory`；`VendorClose → close_vendor → visitHistory/choiceHistory/runClock/pendingVendorResultCard`；结果右选清 session | `noncombat_bazaar_vendor.gd` 验一次与重复动作、三个坏盘回滚点、互动和空手结果文案、关闭/收起严格重放；热态动作/货品篡改及第 49 次记录裁剪先红后绿。网页版参考 `noncombat_bazaar_vendor_assist_han_browser_trace.jsonl` 与 `noncombat_bazaar_vendor_dismiss_browser_trace.jsonl`。独立审查 VERIFIED；真实完整多次入摊及其长线重放未证明。 |

**下一依赖切片 N9i**：补全 `ShopSystem` 四件货品的价格/代价检查、一次性购买回执与物品/疗伤/法宝获取；接 `ask_luo` 的因果事实生产和下游官坊消费者；同会话重载、坏盘、重复购买与跨次关系折扣必须与网页实跑核对。鬼市和普通官坊另立来源入口切片。

## 2026-10-20 N9g 坊市待发队列与右选 Slice Charter（待实施）

| Issue | 网页实跑事实和源状态所有者 | 实施与验收门禁 |
| --- | --- | --- |
| N9g-01 | `GameLogic._queueMarketForProjectedDecision → MarketSystem.tick → FlowDirector.pendingFlags.market` 是**单个可覆盖槽位**。完整逐决定实跑 `artifacts/godot-migration/noncombat_bazaar_timeline_browser_trace.jsonl` 表明固定随机 0 时：开局排坊市 6 / 鬼市 14；决断 6 坊市入列并重排 12，决断 12 再入列并重排 18，决断 14 鬼市覆盖坊市并重排 30，决断 18 坊市覆盖鬼市并重排 24，决断 21 才取出坊市。第 18–20 次决定卡由 P60 因果、P45 涌现等更高优先级占用。Godot 尚无持久 `marketState` 或待发集市队列。 | 在首局初始化来源 `vendor_profiles.json` 的 6–10 决断节拍与夜窗 14–20 鬼市节拍，保存可重放抽样和覆盖槽位；旧档下一次有效决定原子升级，严格旧档重放不改原字节。仅满足来源位置/优先级时入列，排队与弹出均在单一 RunSession 快照；源 `MarketSystem.js`、`vendor_profiles.json` 及来源背景校验。固定随机轨迹须在 6/12/14/18 覆盖、21 出列，重启/写盘失败不丢也不重发。 |
| N9g-02 | `bazaar_encounter` 是 `MarketSystem._buildBazaarCard()` 的动态文案，左选 `ENTER_VENDOR` 且 `AFTER_CLOSE_EXACTLY_ONCE`；右选直接结算并继续。`noncombat_bazaar_skip_browser_trace.jsonl` 显示右选决断 22 后为 `karma_ripple:slot_1:life:0:13:causal:qi_sword_attune`，且集市到访表和活跃摊位均未增加。 | 本切片须至少把来源动态卡和右选做成可恢复、一次性提交；左选必须保留完整摊位交易合同，待 N9h 落地前不得假装结算或无提示地丢选择。N9h 随后接两次深度往来、购买/换物、关系/线索事实、关闭后单次结算，才可称坊市入口可玩。 |

**实现顺序**：① 先以网页逐决定轨迹锁定初始节拍、决断 18 队列及 21 出队，建立失败 Godot 专项；② 把市场时钟、独立 RNG 与 pending card 写进候选快照，来源配置与当前地点决定资格，旧档 replay 设置迁移激活点；③ 调整 `resume_flow` 只在 P60/P45 无卡后消费 pending market；④ 右选通过统一令牌、决定回执和原子写盘；⑤ 接 N9h 的 vendor session/交易后才开放左选。不要把第 21 决断硬编码成市场触发点，也不要在重新启动后重算并覆盖已经排队的市场卡。

**N9g 坊市到访/右选落地（2026-10-20）**：`noncombat_market_flow.gd` 从 `vendor_profiles.json` 读取 6–10 决断公开坊市与夜窗 14–20 鬼市节拍，保存独立 RNG、两套时钟和唯一可覆盖的待发槽位；Godot `noncombat_domain.gd` 在已提交决定推进时调度，来源卡优先级低于章节、任务、因果、师徒和涌现。新局第 6/12/14/18 次覆盖、第 21 次展现的固定零轨迹与 `noncombat_bazaar_timeline_browser_trace.jsonl` 相符；坊市卡文字按网页 `MarketSystem._buildBazaarCard` 及当前地点构造，桌面 UI 从来源 `presentationProfile.backgroundPath` 取原背景，右选在单次 RunSession 提交中写决定回执且不增加摊位到访。已排队/已选择存档严格重放、写盘失败原字节不变、旧档在下一次真实决定升级（旧 `FLOW_PENDING` 单纯取卡不提前升级）。来源 JS 指纹进入总门禁，配置与背景由原件 SHA/可加载性复核。`noncombat_market_arrival.gd` 从无调度器的红测到通过；独立只读审查发现热态缺失配置时应为 `SOURCE_UNAVAILABLE`，新增模拟缺源负例先红后修复，复核无 P1/P2。左选会话另见 N9h；鬼市商品/交易及完整货品购买仍未迁移。

| N9g 声明 | 可复核证据 | 结果 |
| --- | --- | --- |
| 节拍、覆盖与来源地点 | `src/systems/MarketSystem.js`、`src/game.js`、`artifacts/godot-migration/noncombat_bazaar_timeline_browser_trace.jsonl`；`noncombat_market_arrival.gd` | 第 6/12/14/18 次待发覆盖及第 21 次坊市已验证 |
| 来源素材与右选原子性 | `data/markets/vendor_profiles.json`、`godot/content/source_manifest.json`、同一专项的坏源/读档/失败写盘/旧档负例 | 已验证；左选交易与鬼市商品仍缺 |
| 总门禁 | `python tools/validate_godot_runtime.py` 本轮完整运行 | 所有非战斗专项通过；并行战斗 `presentation_integration.gd` 木人胸口标记偏差约 0.683，项目总门禁未通过 |

## 2026-10-20 N9f 剑宗誓册因果兑现 Slice Charter

| Issue | 网页来源链与当前断点 | 本批验收 |
| --- | --- | --- |
| N9f-01 | `em_heaven_gaze` 结算时 `causal:sword_sect_path` 延迟归零，网页版 `KarmaSystem.getReadySeeds → CardSystem._drawKarmaCard` 由 `data/cards/karma_expansion.json` 发 `kx_ch_sword_sect_path`。Godot 因果白名单缺此种子，在可恢复 `FLOW_PENDING` 停住。 | 从真实剑修路线发来源题名/文案/原图和两选；左选修为/道心/`draw_sword`/誓约标志，右选善业/福缘/道心/修订标志。只消耗该种子，一次性回执、旧档重载、失败写盘与坏图/坏源拒绝。下张交给独立 Flow 仲裁，不提前仿造坊市。 |

**边界**：浏览器两选真实轨迹先核对牌组取得与下一张卡；本批不改 Godot 战斗表现。源中 `draw_sword` 在当前剑修起始牌组以外，须按牌组权威新增并在同一存档事务持久化，不把“卡文提到赐剑”当成奖励证据。

**N9f 落地与证据**：浏览器 `artifacts/godot-migration/noncombat_sword_sect_{left,right}_browser_trace.jsonl` 实跑到决断 21；左选修为 95→99、取得 `draw_sword` 并记 `sourceId=kx_ch_sword_sect_path`，右选善业 36→38、牌组不变，均消费剑宗种子，下一卡皆 `bazaar_encounter`。`noncombat_karma_flow.gd` 由作者种子映射排卡并沿现有来源 SHA/原图门禁结算；`noncombat_sword_sect_karma.gd` 先红后绿，验证原图、两选、左选牌组来源、坏图拒绝、待选与已选重载、失败写盘与重复输入。相邻四项因果/涌现专项再次全部退出 0。独立只读复核在本卡范围未见可复现 P1/P2；**坊市动态卡、入场、购买、关闭和后继 Flow 尚未迁移**，所以不声称决断 21 之后的路线连通。

**N9f 总门禁复核**：新专项完整双分支约需 27 秒，已纳入运行门禁的 60 秒长路线组。一次总门禁在 `noncombat_mentor_arc.gd` 的法修随机残卷路径偶发失败，单独重跑通过；该测试现固定本进程随机种子，避免随机完成天书时提前改变章节阈值。最新 `python tools/validate_godot_runtime.py` 通过所有非战斗专项，仍在并行战斗 `presentation_integration.gd` 的木人接触标记距离 `0.68293702602386` 失败，不宣称项目总门禁通过。

## 2026-10-20 N9e 天道注视涌现事件 Slice Charter

| Issue | 网页来源链与当前断点 | 本批验收 |
| --- | --- | --- |
| N9e-01 | `StoryNetworkSystem.EmergentNarrativeEngine.THRESHOLDS` 在修为、福缘都超过 80 时生成 `em_heaven_gaze`；`FlowDirector` 的叙事 P45 排在到期因果 P60 后。当前浏览器路径在 `kx_ch_shared_opportunity` 结算后出现该卡，Godot 仍为 `FLOW_PENDING`。事件模板写在 JS 中，没有作者 `sceneImage`。 | 只在实际阈值和前序更高优先级满足后呈现来源文案/选择；左右效果、回执、叙事优先级、无图 UI、旧档/重启/失败写盘可验证。JS 指纹漂移拒绝，不能复制到第二份不受控剧情数据。 |

**边界**：先核对网页两选真实轨迹和下一卡；不能因为当前样本在高福缘/修为下必出，就把 `em_heaven_gaze` 做成无条件固定续卡。其它 5 类涌现阈值、反复触发语义、完整叙事队列需要单独门禁。

**N9e 落地与证据**：`tools/export_story_emergent_cards.js` 从网页 `StoryNetworkSystem.js` 提取当前六张涌现模板，生成只读派生文件并以源 JS SHA 与派生文件 SHA 双重固定；Godot `noncombat_emergent_flow.gd` 在首次排卡和选择结算前核对真实文件指纹、阈值与更高优先级，按源文案呈现无 `sceneImage` 的文字卡。浏览器 `artifacts/godot-migration/noncombat_heaven_gaze_{left,right}_browser_trace.jsonl` 证明决断 20 左选修为 95/福缘 100/恶业 6，右选修为 100/福缘 70/恶业 16，下一张均为 `kx_ch_sword_sect_path`。`noncombat_heaven_gaze.gd` 先红后绿，验证两选、无图桌面 UI、阈值抑制、待选和已选重载、失败写盘及无状态泄漏；独立审查找出的首次读取可篡改派生 JSON 问题以隔离副本负例先红后修复，复核确认无剩余 P1/P2。`python tools/validate_godot_runtime.py` 本次非战斗专项均通过，完整门禁仍在并行战斗 `presentation_integration.gd` 的木人胸口接触点距离 `0.68317967653275` 退出 1。下张剑宗誓册仍待迁，不把本事件当完整 FlowDirector。

**N9e 后续回归**：沿 N9f 路线发现 Godot 在结算后可能立即再次生成 `em_heaven_gaze`，而网页 `NarrativeLedger.getRepeatPolicy` 对 `EMERGENT` 设 12 次决定冷却。新增“立即拒绝、第 12 次决定后可重发”的失败回归后，在 `_heaven_due` 读取已结算选择历史的决断号；运行门禁同时固定 `NarrativeLedger.js` 的 SHA。修后专项退出 0。此处只实现当前事件的冷却，完整叙事账本与其余涌现卡仍未迁。

## 2026-10-20 N9d 第三张因果卡 Slice Charter

| Issue | 网页生产链与当前断点 | 本批验收 |
| --- | --- | --- |
| N9d-01 | `k_chapter_sword_left/right` 后，浏览器 `KarmaSystem.getReadySeeds → CardSystem._drawKarmaCard` 从同优先级后续种子 `causal:shared_opportunity` 映射 `data/cards/karma_expansion.json` 的 `kx_ch_shared_opportunity`；Godot 目前只允许旧剑种与剑痕种子。 | 在真实决策 18 后排出作者卡和原图；左右选分别处理福缘/灵石/善业/标志或道心/善业/标志，移除本因果种子，存档重载、失败写盘、旧因果回放和源散列均正确。 |

**边界**：本批只处理这条网页实达支线，其他命盘/普通卡及战斗另行仲裁。来源布尔旗与现有 `flags` 权威同次写入，不额外制造剧情文本。

**N9d 落地与证据**：`noncombat_shared_karma.gd` 从真实首局走到决断 18，先红测未发卡，再验收源 `kx_ch_shared_opportunity` 的原图和两选。固定 0 浏览器 `noncombat_shared_karma_{left,right}_browser_trace.jsonl` 给出决断 19：左选福缘 87→90、灵石 10→14、善业 35→36 与 `karma_result_shared_ally`；右选善业 35→37 与 `karma_result_shared_advice`；均仅消费 `causal:shared_opportunity`，下一张网页版为 `em_heaven_gaze`。Godot 两选同值、原子回滚及严格重放退出 0。独立审查指出同一 `karma_expansion.json` 的旧 SHA 在热态续卡被覆盖；新增热态漂移测试先红后绿，现在旧 pin 不匹配即拒绝、不改存档。坏原图也拒绝排卡。`em_heaven_gaze` 是 StoryNetworkSystem 涌现事件，另列后续批次，不能用因果映射代替。

## 2026-10-20 N9c 第二张因果卡 Slice Charter

| Issue | 网页生产链与当前断点 | 本批验收 |
| --- | --- | --- |
| N9c-01 | `KarmaSystem.getReadySeeds → CardSystem._drawKarmaCard/_materializeKarmaCard` 在 `ch_qi_80` 后取先种下的 `causal:qi_sword_attune`，从 `data/cards/karma.json` 映射 `k_chapter_sword_left`，以种子 `context` 将标题/选项回声展开。Godot `KarmaFlow` 只接受 `causal:sword_legacy_start`，此时 `FLOW_PENDING` 无卡。 | 同一真实路线展示来源原图和已展开文案；两选分别结算修为/道心或修为/福缘，移除且仅移除本次种子，决定时钟、回执、严格待选/已选读档及写盘失败回滚通过。旧首张 `kx_path_sword_legacy` 的存档形状保持不变。 |

**边界**：本批只扩充已实跑的第二张因果卡，不擅自批量激活其它因果、普通抽卡或战斗。先红测真实入口，再扩充 Godot 因果消费者；源 `karma.json` 与原图分别校验并保存散列。网页固定随机值 0 的路径证据为 `artifacts/godot-migration/noncombat_qi_trial_{left,right}_browser_trace.jsonl`。

**N9c 落地与证据**：`noncombat_second_karma.gd` 先红测 `FLOW_PENDING` 断点，后从 `karma.json` 映射并用原种子 context 展开“剑脉初鸣·剑痕回响”，原场景图可加载。浏览器 `noncombat_second_karma_right_browser_trace.jsonl` 实证本路径修为 100/道心 4 时左选两项正收益均封顶而禁用、右选福缘 85→87；Godot UI 与领域入口同时禁左、允右。测试覆盖两种前置章节选择、待选/已选原文重载、失败写盘、种子一次性消费、坏图、源 `cards:karma` SHA 漂移与缺失分类；旧 `noncombat_first_karma.gd` 保持通过。独立只读审查未发现可复现 P1/P2。其它未实跑的因果映射仍未自动发牌。

## 2026-10-20 N9b 第四张炼气章节卡 Slice Charter

| Issue | 当前差距与来源链 | 本批验收 |
| --- | --- | --- |
| N9b-01 | 浏览器白狐第三幕放弃→第三章→因果→师尊→命盘翻牌→回应确认后，`RealmChapterSystem.getMilestoneCard(qi,70)` 在 P85 返回作者 `ch_qi_80`，附 `ch_qi_100.bossJourney.stages.80` 整备提示和 `qi_main_commitment` 因果事实消费者。Godot `noncombat_milestone_flow.gd` 只认识阈值 15/30/50，玩家确认回应后停在 `FLOW_PENDING`。 | Godot 同一路线以来源图文和阈值 70 排出 `ch_qi_80`；左右选一次提交来源属性/寿元、事实消费与 `qi_main_trial` 生产、选择回执、严格读档与失败写盘回滚；下一张仍交 Flow 仲裁，不伪造战斗。 |

**边界**：这张作者卡的左右选均为非战斗选择，左文案虽写迎战但原数据无 `triggerCombat`。沿用 N4/N8 的来源 JSON 和事实账本，不为它重画素材，不改并行战斗文件。浏览器固定随机值 0 的完整截图工具轨迹在 `artifacts/godot-migration/noncombat_qi_trial_{left,right}_browser_trace.jsonl`。先建立失败专项，再修改同一 MilestoneFlow 生产/结算。

**N9b 落地与证据**：`noncombat_milestone_flow.gd` 使阈值 70 发作者 `ch_qi_80`，投影 `ch_qi_100.bossJourney.stages.80` 整备提示与原图；左/右选择按网页分别在决断 17 得到气血 1/2、福缘 85/86、寿元 76/77，消费 `qi_main_commitment` 并产生 `qi_main_trial`。`noncombat_qi_trial_milestone.gd` 先红后绿，验证两选、坏原图、待选/已选严格重放与写盘失败原子性。独立审查发现运行中章节来源缺失被误报 `SOURCE_MISMATCH`；新增热态缺源回归并改为 `SOURCE_UNAVAILABLE`，存档原文不变。旧第三章节与首命盘专项仍退出 0。下一张实际是 `k_chapter_sword_left`，已在 N9c 接入。

## 2026-10-20 N9a 命盘首次中断 Slice Charter

| Issue | 当前可复现差距与来源链 | 本批验收 |
| --- | --- | --- |
| N9a-01 | 真实桌面路径的浏览器 `GameLogic._makeChoiceInternal → DestinyWheelSystem.tick` 在第 15 次决定后先于下一张剧情卡显示 `DESTINY_WHEEL`；Godot 师尊选择只留下 `NARRATIVE_RESULT_PENDING`，没有命盘叠加与恢复。证据 `artifacts/godot-migration/noncombat_post_mentor_browser_trace.jsonl` 的白狐第三幕放弃→第三章→因果→师尊左选。 | 同一合法决定生成可持久的五张覆面命盘；四个网页版键位可翻；先显示命盘，翻完恢复被覆盖的来源回应卡；重启、重复操作、写盘失败保持一次性。 |
| N9a-02 | 浏览器命盘奖励写在 `src/systems/DestinyWheelSystem.js` 闭包中，含修为、道心、福缘、灵石、寿元、标志及法宝；Godot 无来源投影与奖励权威。 | 通过钉住当前 JS SHA 的明确奖励表结算首次命盘，命盘抽取概率与 Rare+ / 空卦限制遵循源代码；奖励在同一 RunSession 提交并可回放，旧档从下一有效决定升级。未迁法宝必须有保守失败行为，不得虚发。 |

**边界**：只迁首轮炼气 15 决定后的命盘，不代替后续普通抽卡、第二轮命盘、市场/心魔等优先级。网页 `Math.random=0` 命盘五张皆龙脉印记，页面仅提供前四张选择；本批 Godot 用保存的独立 RNG 状态保证跨进程回放，固定掷值只做对照。网页当前内部命盘翻牌在截图工具中仍未观察到关闭，需用直接运行入口单独核对；不能把“显示命盘”当作奖励已完成。并行战斗目录不得改动。

**N9a 落地与证据**：`noncombat_destiny_wheel.gd` 与 `noncombat_treasure_acquisition.gd` 在第 15 次决定后保存来源五张覆面卡与可复现抽样，四个可点方向翻牌，奖励和法宝发放同一事务提交，并恢复先前师尊回应卡。来源 JS/法宝 JSON 的 SHA 均有运行门禁；空卦只保留网页最后一张、首次命盘时钟按 15 决定触发。`noncombat_destiny_wheel.gd` 测试先红后绿，覆盖固定 0 浏览器的修为 100/道心 4/福缘 85、不同稀有度抽样、法宝 token/实例、读档、坏源、重复翻牌与失败写盘。独立只读复核的空卦位置、触发时钟、法宝权威、缺源分类和取得决断号问题均已修复；后续第 30 次命盘及全部奖励支线尚无浏览器实跑门禁。

## 2026-10-20 N8d 传承残卷普通选择与合成 Slice Charter

| Issue | 来源链与根因 | 本批验收 |
| --- | --- | --- |
| N8d-01 | `index.html → GameLogic.makeChoice → LegacyFragmentSystem.tryDrop` 在成功的非 COMBAT 选择后以境界概率/七次空落保底给来源兼容的残卷；Godot 没有该生产者，现有 `RunSession` 无随机状态。 | 只在有效选择且同一次快照内推进可回放随机状态；空池不计保底、失败提交无泄漏、旧档原字节严格回放并在下一决定升级。概率与套装资格以网页版契约及 `battle_cards.json` 为依据。 |
| N8d-02 | `LegacyFragmentSystem.checkCompletions → SkillCardAcquisitionSystem.acquireLegacyCard` 集齐 8 片后一次性发流派变体卡并记录来源，Godot 目前只有因果左选的单卡取得。 | 真实剑修路线固定 0 掉落轨迹第 8 片发 `legacy_sword_heart_art`、来源 `legacy_fragment_set/sword_heart`、存档重载不重发；其它流派从卡定义查询变体；不修改并行战斗呈现。 |

**权限与边界**：网页版 JSON/JS 是机制依据，Godot `RunSession` 是本世唯一写权威；已有浏览器档不直接改写。随机序列由本世快照保存，测试固定掷值只用于确定性核验。Boss 奖励、追踪目标 UI、轮回跨世继承归后续切片。验收用 Godot 公共选择入口、浏览器固定随机轨迹、定向测试、完整运行门禁和独立只读审查。

**N8d 实施与证据（2026-10-20）**：`noncombat_legacy_fragment_flow.gd` 按网页六套/8 片、各境界概率、连续 7 次空落后的第 8 次保底以及 `legacy`+流派双标签资格，在非 COMBAT 成功选择的候选快照内推进有初始种子的随机状态。第 8 片通过牌组权威取得对应流派绝学，写 `legacy_fragment_set` 来源；六套被动及天书福缘、仙志寿元/气血、魔血道心上限即时效果同次提交。普通剧情的修为增益、道心伤害、气血/道心上限消费者已接聚合被动；`battle_request.playerSnapshot.legacyPassives` 只预留跨战斗合同，**并行 Godot 战斗端尚无消费代码，不能宣称暴击、开战护盾、低血伤害和丹药疗效已生效**。`legacyRuleSourceSha` 钉住浏览器 `LegacyFragmentSystem.js` 当前 SHA；运行门禁核对真实 JS，来源规则变化须重新审校并升级；旧 Godot 档原字节回放，下次决定同一提交升级，规则漂移报 `SOURCE_MISMATCH` 不改存档。`noncombat_legacy_fragments.gd` 先红后绿：真实剑修路线第 6 次 COMBAT 决定不计残卷，第 9 次决定取得第 8 片，取得记录 turn=8 与浏览器 `Math.random=0` 轨迹一致；四流派来源变体、七空落保底、缺 `legacy` 标签拒绝、六套被动、完成时写盘失败回滚、旧档升级、重载、SHA 漂移均退出 0。独立只读审查首轮指出即时效果/被动及双标签缺口，二次复核确认已修并指出 JS 漂移门禁，现已加指纹；审查也确认战斗消费仍未实现。完整运行门禁所有非战斗专项已通过，停在并行战斗 `presentation_integration.gd` 木人胸口接触点距离 `0.683167`；`_fit_story_screen` 增加离树后守卫，消除多项 UI 专项退出后的延迟帧异常。待 N5 战斗真实接线与传承 UI/轮回档补齐。

| N8d 声明 | 可复核证据 | 结论 |
| --- | --- | --- |
| 只在成功的普通选择后掉落，七空落保底 | `src/game.js:2778`、`LegacyFragmentSystem.js:375`；`noncombat_legacy_fragments.gd` 的真实路线与 0.99 掷值 | 已实现并验证 |
| 第八片发当前流派绝学及六套奖励 | `battle_cards.json` 的 `legacySetId/legacyPath/tags`、`LegacyFragmentSystem.js:750-812`；四流派和六套专项 | 非战斗属性已实现并验证；战斗被动消费未实现 |
| 旧档、失败写盘、源规则漂移不误改原档 | `noncombat_legacy_fragments.gd` 的重放/故障注入/坏 SHA/坏 RNG 负例；总门禁 JS 指纹 | 已实现并验证 |
| 完整运行门禁 | `python tools/validate_godot_runtime.py` 于 2026-10-20 通过所有非战斗专项；`presentation_integration.gd` 在 `distance=0.68313974142075` 退出 1 | 并行战斗呈现仍阻断总门禁 |

**N8d 实施与证据（2026-10-20）**：`noncombat_legacy_fragment_flow.gd` 按网页六套/8 片、炼气 8% 起的各境界概率、连续 7 次空落后的第 8 次保底以及 `legacy`+流派双标签资格，在非 COMBAT 已提交选择的候选快照内推进有初始种子的随机状态。第 8 片通过牌组权威取得对应流派绝学，写 `legacy_fragment_set` 来源；六套被动及天书福缘、仙志寿元/气血、魔血道心上限即时效果同次提交。普通剧情的修为增益、道心伤害、气血/道心上限消费者已接聚合被动；`battle_request.playerSnapshot.legacyPassives` 只预留跨战斗合同，**并行 Godot 战斗端尚无消费代码，不能宣称暴击、开战护盾、低血伤害和丹药疗效已生效**。`legacyRuleSourceSha` 钉住浏览器 `LegacyFragmentSystem.js` 当前 SHA；`validate_godot_runtime.py` 核对真实 JS，来源规则变化须重新审校并升级；旧 Godot 档原字节回放，下次决定同一提交升级，规则漂移报 `SOURCE_MISMATCH` 不改存档。`noncombat_legacy_fragments.gd` 先红后绿：真实剑修路线第 6 次 COMBAT 决定不计残卷，第 9 次决定取得第 8 片，取得记录 turn=8 与浏览器 `Math.random=0` 轨迹一致；四流派来源变体、七空落保底、缺 `legacy` 标签拒绝、六套被动、完成时写盘失败回滚、旧档升级、重载、SHA 漂移均退出 0。独立只读审查首轮指出即时效果/被动及双标签缺口，二次复核确认已修并指出 JS 漂移门禁，现已加指纹；审查也确认战斗消费仍未实现。完整运行门禁所有非战斗专项已通过，停在并行战斗 `presentation_integration.gd` 木人胸口接触点距离 `0.683167`；`_fit_story_screen` 增加离树后守卫，消除多项 UI 专项退出后的延迟帧异常。待后续 N5 战斗真实接线与传承 UI/轮回档补齐。

## 2026-10-20 N8c 选流派即有起始牌组 Slice Charter

| Issue | 玩家契约与旧档风险 | 验收 |
| --- | --- | --- |
| N8c-01 | 网页 `SkillCardAcquisitionSystem.grantStarterDeck` 在流派确定后即给对应六张本世起始牌；Godot 只在确认迎战或 N8b 因果领奖时才建牌组，普通剧情中的牌组视图/未来遭遇装载缺权威。来源 `deck_progression.json`、`battle_cards.json`。 | 四流派新档起始即有源六张、来源散列、持久重载；首战装载仍校验来源牌组；不凭空增加随机传承掉落。 |
| N8c-02 | 已存的旧 Godot 开局缺牌组字段，直接改 `start()` 会让严格选择回放与存档原文不符。 | 旧档使用旧形状原文回放，下一次已授权决定才在同一提交升级牌组；升级后新档可再次严格重放，失败写盘不改可见状态。 |

**N8c 落地与复核（2026-10-20）**：`noncombat_deck_acquisition.gd:ensure_starter()` 从来源契约验证四流派各六张卡，`noncombat_domain.gd` 在新档第一次提交即写牌组、取得操作和双源 SHA。读旧档时只在回放域启用旧结构；恢复到可玩的域后，下一次有效决定与牌组升级同次提交。`noncombat_starter_deck.gd` 的四流派起始牌、原文重载、旧档升级、写盘失败和来源漂移先红后绿；`noncombat_first_karma.gd` 另冻结了 N8b 左选后但尚无 N8c 版本字段的档，验证其牌组仍可严格回放。独立只读复核发现初版只在建牌组时校验来源，运行中来源变更后仍可写出无法恢复的新档；新增来源 SHA 变动时的选择拒绝回归先红后绿，现每次提交前复核两份牌组源。非战斗相关专项通过；完整 `python tools/validate_godot_runtime.py` 通过至并行战斗 `presentation_integration.gd`，仍因木人胸口接触点距离 `0.683052` 退出 1。旧 `BATTLE_PENDING` 的专用冻结档样本、随机传承残卷掉落和更远剧情/遭遇牌组消费者仍待补。


## 2026-10-20 N8b 因果左选牌组取得 Slice Charter

| Issue | 来源契约和缺口 | 验收 |
| --- | --- | --- |
| N8b-01 | `kx_path_sword_legacy` 左选含 `deckCard:sword_intent`，网页版 `EffectService → SkillCardAcquisitionSystem.acquireLegacyCard` 会按 `battle_cards.json` 卡定义/流派标签验证、记录 `skillAcquisitions` 并把牌加入本世 `deck`；Godot 只给本次迎战临时起始牌，避战路线没有牌组权威。 | 从当前真实路线及持久待选卡先红测：来源六张起始牌 + 剑意、取得来源记录、血量/修为/寿元/结果旗、严格重载/重复拒绝、后继师徒；把所用战斗卡/牌组源 SHA 固定。随机传承碎片 `legacy_sword_heart_art` 属另一生产链，不伪造掉落。 |
| N8b-02 | 同一因果卡右选不得改变牌组，且坏源或写盘失败不得只给数值不给卡。桌面按钮应反映原子提交能力。 | 左选从 UI 可操作；新增坏来源/失败写盘测试；右选现有专项维持通过，旧 N6b 师徒存档原文不变。 |

**N8b 落地与证据（2026-10-20）**：`noncombat_deck_acquisition.gd` 使用原 `deck_progression.json` 六张剑修起始牌与 `battle_cards.json` 的 `sword_intent` 卡定义/流派标签，拒绝重复或跨流派卡，记录与网页一致的 `skillAcquisitions.sword_intent`（`sourceId=kx_path_sword_legacy`、`sourceType=legacy_deck_effect`、`mode=legacy`、取得时 turn 13）和牌组操作；两份来源 SHA 钉在同一存档。`noncombat_karma_flow.gd` 左选的气血 -1、修为 +3、寿元 -1、结果旗、种子结算与牌组新增共用一次候选快照提交；桌面按钮开放。`noncombat_first_karma.gd` 从真实避战/白狐/第三章路线先红后绿，验证原起始牌 + `sword_intent`、写盘失败原文不变、重载、重复拒绝与后继师徒；右选专项同时通过。独立只读审查未发现本切片 P1/P2。网页版 `Math.random=0` 轨迹额外出现 `LegacyFragmentSystem` 在第 8 回合给的随机传承牌 `legacy_sword_heart_art`，当前 Godot 尚无该掉落生产者，所以不能将这条路线的 Godot 7 张牌宣称与浏览器 8 张完整等值；N8c 须单独接其随机状态/存档与因果顺序。


## 2026-10-20 N8a 来源因果卡优先级与右选结算 Slice Charter / Evidence Manifest

| Issue | 玩家契约、来源链、根因 | 本批验收 |
| --- | --- | --- |
| N8a-01 | 玩家从已保存的白狐第三幕「离开」继续，经 `ch_qi_60` 左选后，网页版 P60 因果先于 P48 师徒出 `kx_path_sword_legacy`；Godot 的 `resume_flow()` 只检查里程碑→任务→师徒，遗漏 `CardSystem._drawKarmaCard`。来源 `data/cards/karma_expansion.json` 的 `karmaCards` 映射、`KarmaSystem.getReadySeeds`、`FlowDirector.getNextCard`、原图及源 SHA 决定准入。 | 先记录真实浏览器顺序；从 Godot 公共入口红测「第三章后优先显示原因果卡」，核对原图、待选存档重放和来源漂移，不把未选择的种子提前消费。 |
| N8a-02 | 此卡右选不用牌组奖励：网页版第 14 决定福缘 70→71、设置 `karma_result_sword_legacy_tempered`、移除已兑现种子、下张师徒卡；Godot 目前无法结算。左选包含 `deckCard:sword_intent`，须由牌组权威处理，不能丢奖励。 | 右选来源效果、种子计时、单次回执、原图、写盘失败、重载与后继师徒可执行；左选暂禁用并提示牌组接口待接，N8b 单独完成完整牌组取得。 |

真实网页版取证：`artifacts/godot-migration/noncombat_whitefox_post_terminal_karma_{browser,right_browser}_trace.jsonl`，`Math.random=0`。`q_whiteFox_3/down` 第 12 决定后是 `ch_qi_60`；第 13 决定选左后是 `kx_path_sword_legacy`；因果第 14 决定右选后是 `mentor_bai_ren_stage_INNER_DISCIPLE`。左选浏览器轨迹也保留，其牌组新增 `sword_intent`，并显示更早已取得 `legacy_sword_heart_art`；不能把首战六张 starterDeck 冒充这条路线的完整牌组。

**N8a 落地与复核（2026-10-20）**：`noncombat_karma_flow.gd` 从源因果映射、种子优先级、卡原图及 SHA 产生待选卡；`noncombat_domain.gd` 把它排在任务与师徒之间，并对右选的福缘 +1、`karma_result_sword_legacy_tempered`、种子移除/其余种子计时、回执及写盘失败做一次性提交。`noncombat_opening_ui.gd` 把暂不能兑现 `deckCard:sword_intent` 的左选置为不可用。`noncombat_first_karma.gd` 在真实决策路线先红后绿，覆盖待选读档、坏源、原图、左选拒绝、右选结算、重载接回师徒。独立审查发现旧 N6b 存档在新因果优先级下会把原本的师徒卡回放为因果卡；新增旧式师徒待选及师徒已选的存档回归先红后绿，`karmaArbitrationVersion=1` 只标记新顺序，旧存档按旧顺序回放，恢复后的新决定采用当前优先级。

**历史来源漂移与总门禁**：冻结 N3b 原档引用的八文件 `sourceContentHash` 与当前不同（原 `859a4f…`，现 `5c0a77…`；当前 `battle_cards.json` 的修改时间晚于冻结档），不能宣称这些原档可按当前来源直接恢复。`restore()` 现在明确报 `SOURCE_MISMATCH`、保留原字节并禁止 `archive_unrestorable()` 误归档；若网关独有源文件缺失，则报 `SOURCE_UNAVAILABLE`。冻结测试同时覆盖来源一致时的重放和来源漂移时的安全保护。`noncombat_first_karma.gd` 与 `noncombat_milestone_flow.gd` 专项退出 0；完整 `python tools/validate_godot_runtime.py` 跑过全部非战斗专项，仍在并行战斗 `presentation_integration.gd` 的木人胸口接触点距离 `0.683161` 退出 1。左选牌组权威、战斗胜败回传与完整因果仲裁仍未完成。

**N8a 落地与复核（2026-10-20）**：`noncombat_karma_flow.gd` 从源因果映射、种子优先级、卡原图及 SHA 产生待选卡；`noncombat_domain.gd` 把它排在任务与师徒之间，并对右选的福缘 +1、`karma_result_sword_legacy_tempered`、种子移除/其余种子计时、回执及写盘失败做一次性提交。`noncombat_opening_ui.gd` 把暂不能兑现 `deckCard:sword_intent` 的左选置为不可用。`noncombat_first_karma.gd` 在真实决策路线先红后绿，覆盖待选读档、坏源、原图、左选拒绝、右选结算、重载接回师徒。独立审查发现旧 N6b 存档在新因果优先级下会把原本的师徒卡回放为因果卡；新增旧式师徒待选及师徒已选的存档回归先红后绿，`karmaArbitrationVersion=1` 只标记新顺序，旧存档按旧顺序回放，恢复后的新决定采用当前优先级。

**历史来源漂移与总门禁**：冻结 N3b 原档引用的八文件 `sourceContentHash` 与当前不同（原 `859a4f…`，现 `5c0a77…`；当前 `battle_cards.json` 的修改时间晚于冻结档），不能宣称这些原档可按当前来源直接恢复。`restore()` 现在明确报 `SOURCE_MISMATCH`、保留原字节并禁止 `archive_unrestorable()` 误归档；冻结测试同时覆盖来源一致时的重放和来源漂移时的安全保护。`noncombat_first_karma.gd` 与 `noncombat_milestone_flow.gd` 专项退出 0；完整 `python tools/validate_godot_runtime.py` 跑过全部非战斗专项，仍在并行战斗 `presentation_integration.gd` 的木人胸口接触点距离 `0.683161` 退出 1。左选牌组权威、战斗胜败回传与完整因果仲裁仍未完成。

## 2026-10-20 N6b 白狐第三幕终局选择 Slice Charter / Evidence Manifest

| Issue | 玩家契约、来源与现有缺口 | 本批门禁 |
| --- | --- | --- |
| N6b-01 | 玩家救狐并走完第二张任务卡后，第三张 `q_whiteFox_3` 有「击退猎狗」「付灵石交涉」「离开」三选。当前 Godot 已展示原卡但 `issue_choice_token()==0`，后两种无需战斗的终局也无法执行。来源 `data/quests/white_fox.json`、网页版 `GameLogic._makeChoiceInternal → EffectService → QuestSystem.advanceQuest/_completeQuest/_failQuest → KarmaSystem/FactionSystem` 决定资源、任务结果、奖励、势力、种子与后续调度；迎战是延迟战斗决定，不可提前发胜利奖励。 | 先用真实网页入口记录右/下选择与不足 20 灵石的拒绝；新增从 Godot 真实开局抵达第三卡的先红专项，覆盖费用、原任务奖励/势力/两类因果种子、放弃、旧档重放、重复点击与写盘失败。只在来源战斗合同可验证后开放左选；第三张来源图与存档原文保持完整。 |

初始裁定：N6b 先完成第三张卡的非战斗终局，左选继续锁在现有可信战斗边界，避免把尚未发生的猎狗胜利当作任务完成。若来源实跑证实费用或奖励顺序不同于静态 JSON，以真实入口为准并记录差异。本批不更改并行战斗场景。

**N6b 落地与证据（2026-10-20）**：真实浏览器路径记录在 `artifacts/godot-migration/noncombat_whitefox_third_{down,right,right_insufficient}_browser_trace.jsonl`。剑修自然走到第三幕时只有 10 灵石，右选因 20 灵石费用不可用；下选第 12 决定保持资源/属性不变，任务 `abandoned`、无完成奖励，下一张为 `ch_qi_60`。右选的浏览器轨迹通过测试注入补足 10 灵石（不是游戏内获得）核对结算：支出 20、任务返 20、善业 25→52、福缘 70→80、两颗因果种子 `whiteFox`/`foxGratitude` 都从 15 递减到 14，五个正道势力各 +5、血煞宗 -5。Godot `noncombat_quest_flow.gd` 按原任务/势力 JSON 在一次候选快照内处理右/下、来源 SHA、声望与种子；`noncombat_domain.gd` 允许第三卡专属 down 并在读档验证势力来源。桌面 UI 禁用尚无战斗合同的左选与不足费用的右选，写盘失败后重绘准入状态。`noncombat_whitefox_third.gd` 由真实开局验证下选、费用拒绝、旧档回放、写盘失败、坏势力 SHA、桌面按钮与右选资金充足的纯结算投影，专项通过；`noncombat_whitefox_choices.gd` 回归通过。独立只读 QA 找到并复测修复了写盘失败后错误重新启用禁用按钮的问题。完整 `python tools/validate_godot_runtime.py` 跑过所有非战斗专项，仍在并行战斗 `presentation_integration.gd` 木人胸口接触点偏差 `0.682652` 退出 1，不记为全项目通过。右选尚无在当前限定路线自然取得额外 10 灵石的入口，所以其真实运行存档/重放尚未验收；左选猎狗战及胜败逃回传仍待独立 N5 战斗接口接通。

## 2026-10-19 N7a 白刃传承首个阶段 Slice Charter / Evidence Manifest

| Issue | 玩家契约与根因 | 修改前证据 | 本批验收 |
| --- | --- | --- | --- |
| N7a-01 | 第三章左选后，网页版通过 `state:attributeChanged` 按正修为增量的 `ceil(0.3×delta)` 累积白刃传承值；`StoryNetworkSystem.MentorArcEngine` 在 20 点跨阶段并把 `mentor_bai_ren_stage_INNER_DISCIPLE` 排入 P48。Godot 只有章节/白狐流，没有传承值生产者与动态师徒卡消费者，停在 `FLOW_PENDING`。需从所有已迁决定的同一次持久提交累积，而非在第三章硬编码。 | `artifacts/godot-migration/noncombat_mentor_full_progression_browser_trace.jsonl` 的剑修真实链为 12→14→15→19→21，白狐失败后 19 时无事件、第三章 +6 产生 +2 后入队；现有 `noncombat_third_milestone.gd` 结算后仍 `FLOW_PENDING`。 | 新档及旧 N3b/N4/N6 档重放，传承状态不重复增加；来源 `companions:arcs` 动态卡和 `companions:portrait_stages` 白刃当前肖像按 SHA 加载，条件不足不发卡，坏源/坏图保留存档；第三章后桌面 UI 可看见师尊卡。 |
| N7a-02 | 玩家在「师尊·断剑」左右选择后，来源效果、师徒事件确认和 `ChoiceOutcomeRouter` 的即时回应须同次提交；网页版左选第 12 决定修为 64/善业 12/传承 22，右选修为 61/福缘 57/传承 21。原 Godot 没有该输入及回应。 | `artifacts/godot-migration/noncombat_mentor_{left,right}_browser_trace.jsonl` 均从真实桌面入口到两侧选择，回应 ID 分别是 `promise_result_3b3a1690`、`promise_result_dc8715d0`。 | 两侧选择、来源数值、事件一次性确认、回应卡 ID/文案、重复点击、写盘失败回滚、待选/结算/回应读档。回应确认后继续保留真实 Flow 边界，不伪造普通抽卡。 |

来源链：`index.html` → `GameLogic.makeChoice` → `EffectService` / `GameStateManager` 属性变化 → `StoryNetworkSystem` 修为监听与 `MentorArcEngine` 阶段队列 → `FlowDirector` P48 → `ChoiceOutcomeRouter` 回应。师徒动态卡原作者数据没有 `sceneImage`，本批从作者 `data/companions/portrait_stages.json` 取白刃初始肖像作为桌面呈现资产；它是既有角色图而非新画剧情场景。完整师徒弧线与其余角色弧线仍按后续批次独立迁移。已知完整 Godot 总门禁在并行战斗 `presentation_integration.gd` 的木人接触点偏差约 0.683 失败，本批不修改战斗资产。

**N7a 实施与证据（2026-10-19）**：`noncombat_mentor_flow.gd` 在所有已迁选择的候选快照提交时复现网页版的修为正增量 `ceil(0.3×delta)` 和相关卡标签 +3；跨 20 点时把作者 `INNER_DISCIPLE` 入队。`noncombat_domain.gd` 在章节和白狐任务后调度该阶段，从 `companions:arcs` 读取原文/左右效果，从 `companions:portrait_stages` 取白刃初始立绘，原子提交选项、事件确认、回应承诺及决策回执；回应确认前再次核验作者数据和立绘。`noncombat_opening_ui.gd` 将作者正文中的字面 `\n` 段落符呈现为实际换行，不改来源 JSON。旧 Godot 存档通过严格重放重建传承值，下次有效调度才增加新字段。师尊卡及回应所附 `sceneImage` 是桌面呈现补充，浏览器动态卡本身没有该字段。

**跨流派反例修复**：独立只读复核查出首次实现错加了 `path == sword` 门槛；网页版 `StoryNetworkSystem` 对所有流派注册白刃。`noncombat_mentor_spell_browser_trace.jsonl` 与 `noncombat_mentor_pill_browser_trace.jsonl` 实跑确认法修/丹修第三章后传承 20 并抽出同一师尊事件。该门槛已移除；Godot 四流派专项验证剑修 21、法修/丹修 20，体修在当前样本修为 49、尚未触发第三章或师尊事件。审查还发现回应确认时未复查师尊来源；已补弧线 JSON、立绘定义与图像 SHA/Texture 守卫。`noncombat_mentor_arc.gd` 覆盖左右效果、回应 ID、待选与已选严格读档、旧档升级、来源/图像漂移、写盘失败和重复输入，最终退出 0；第三章、白狐选择、开局 UI 专项也退出 0。独立复核在本有界事件内未见剩余可复现 P1/P2。完整 `validate_godot_runtime.py` 仍因并行战斗 `presentation_integration.gd` 接触点偏差 `0.68300414085388` 退出 1，不能称全项目通过。

## 2026-10-19 N4c 第三张炼气章节卡 Slice Charter / Evidence Manifest

| Issue | 玩家契约与来源链 | 修改前反例 | 本批门禁 |
| --- | --- | --- | --- |
| N4c-01 | 白狐入口左选导致任务失败、修为升至 55 后，网页 `FlowDirector` 的 P85 章节检查先于其他续卡调度阈值 50，对应作者卡 `ch_qi_60`。左/右选择须保存原效果、第三拍主线事实、因果种子、来源立绘及第 11 决定；战斗仍走独立接口。来源是 `RealmChapterSystem` 的 50→60 别名、`chapter_milestones.json`、`EffectService` 与 `causal_graph.json`。 | 新 `godot/tests/noncombat_third_milestone.gd` 从真实剑修开局、前两章及白狐失败走到 `FLOW_PENDING`，首次运行在“第三卡未调度”退出 1；网页版 `artifacts/godot-migration/noncombat_whitefox_left_browser_trace.jsonl` 已实跑到第 10 决定并给出 `ch_qi_60`、55 修为及原图。 | 原卡与来源阶段提示、左右效果/因果事实、存档严格重放、重复选择拒绝、写盘失败回滚；新专项及受影响旧专项通过。完整门禁若因并行战斗失败如实报告。不替白狐第三卡战斗造结果，不扩手机端。 |

实施边界：`ch_qi_60` 右选的来源效果是数值 `pill: 1`，网页版 `EffectService` 会将它当作丹药资源键 `"1"` 加一；这不是有效的筑基丹 ID。迁移本批保持来源语义并在剧情/经济缺口表中登记作者数据待审，不擅自改为 `foundation`。当前首两张章节卡已有旧档快照，第三卡演出层的升级不能破坏它们的严格重放。

**N4c 实施与证据**：`noncombat_milestone_flow.gd` 依网页版阈值别名调度 50→`ch_qi_60`，从作者 `ch_qi_100.bossJourney.stages.60` 投影【对策】提示，并接入第三拍默认【来历回声】；按来源结算两选、主线压力事实消费与承诺/师承立场产生，数值 `pill:1` 保持来源资源键 `"1"`。第三卡图片按清单 SHA 和 Texture 加载校验；独立审查发现原实现可带坏图排卡，又发现已结算存档的坏图重放可能误归档，两种负例分别先红后修。现在坏图会阻止排卡，待选与已结算档重放均标 `SOURCE_MISMATCH` 并保留原字节。新专项 `godot/tests/noncombat_third_milestone.gd` 两选、原图、阶段文案、事实、因果种子、重复选择、写盘失败及三处坏图边界退出 0；旧里程碑、白狐入口和前两张任务卡专项均退出 0。独立只读复核在限定的第三章投影/结算中未见剩余 P1/P2。

**网页版实跑对照**：`artifacts/godot-migration/noncombat_third_milestone_{left,right}_browser_trace.jsonl` 自真实桌面开局经白狐失败走到第三章并点击左右选。第 11 决定后左选修为 61/恶业 24，右选修为 59/善业 3/丹药 `{"1":1}`；两边种子 ID 与延迟及 Godot v2 存档相同。网页紧接着抽出 `mentor_bai_ren_stage_INNER_DISCIPLE`，Godot 在第三章结算后仍为 `FLOW_PENDING`；下一批须迁 `StoryNetworkSystem` 的师徒阶段生产者/条件/原素材/选择和存档，不能把本批称为路线闭环。网页刷新后的卡恢复值为空，本批仅把当次真实选择及 Godot 严格读档作为对应证据。完整 `validate_godot_runtime.py` 本轮在非战斗专项后仍因并行战斗 `presentation_integration.gd` 木人胸口接触点偏差约 `0.683` 退出 1；本批不改战斗文件。

## 2026-10-19 N4b 白狐任务入口 Slice Charter / Evidence Manifest

| Issue | 玩家契约与根因 | 修改前反例 | 本批验收 |
| --- | --- | --- | --- |
| N4b-01 | 四修避开首战并完成两张炼气里程碑后，网页由 FlowDirector 的 P70 任务检查选出合格的 `white_fox_line`，呈现源卡 `q_whiteFox_quest` 和原场景图；任务激活、禁旗与任务存档须同次提交，重启严格重放只激活一次。原 Godot 仅有两张里程碑，随后停在 `FLOW_PENDING`。 | `godot/tests/noncombat_whitefox_entry.gd` 先红：sword 路线第二里程碑后 `resume_flow()` 返回 false，白狐未排期；网页左右分支浏览器轨迹保存在 `artifacts/godot-migration/noncombat_whitefox_{left,right}_browser_trace.jsonl`。 | 四修来源资格、原文原图、入口激活与 v2 存档重放；禁旗/已访问/境界/回合负例、来源 SHA 漂移、写盘失败不改可见状态。入口选择保持禁用直到任务结算和 NPC 生命周期、续卡形成同一事务；不把入口展示称作白狐支线可玩。 |

来源链：`src/systems/FlowDirector.js` P85→P80→P70，`src/systems/QuestSystem.js` `_onCheckTrigger/_canTrigger/_activateQuest`，`data/quests/white_fox.json`。本批只在 Godot 首轮避战窗口接一个符合网页条件的白狐入口，其他 P90 中断和完整任务仲裁仍是明确缺口。`q_whiteFox` 普通卡与 `q_whiteFox_quest` 任务卡不同，不能互代。两张后续白狐卡原图已通过源资源清单核验；第三张狗群战斗仍留给战斗接口。来源第三卡“仍被困”与第二卡“救它脱困”有文案连续性冲突，迁移期间保持源文并列入剧情审校。五份开局数据的 v2 指纹保持不变，任务 JSON 使用独立 SHA 字段，旧档需可恢复。

**N4b 实施与证据（2026-10-19）**：`noncombat_quest_flow.gd` 在两张炼气章节阈值和章节/因果 SHA 都已确认后，读取 `quests:white_fox` 的原任务定义、资格条件、入口卡与原场景图，写入 `questState` v3、任务 flags、待展示卡及独立 `questSourceSha`；`noncombat_domain.gd` 用原有一次性 v2 提交落盘，严格重放时先校验章节、因果、任务三项已使用的来源 SHA。旧 N3b/N4a 档不被改写，合法来源更新/缺源/原图损坏时保留档并给出来源错误，不误归档。UI 呈现原卡并明确“选择结算待接入”，不提供可点击的假左右选择。`godot/tests/noncombat_whitefox_entry.gd` 从四修真实开局走到第 9 决定，核验源卡、原图、任务激活、重启不重复、未支持的选择拒绝、禁旗/已访卡/境界/回合、坏 SHA、写盘失败及合法来源更新的存档保护；初次测试在“白狐未调度”处退出 1，实现后退出 0。原 `noncombat_milestone_flow.gd`、`noncombat_opening_ui.gd`、`noncombat_run_session.gd` 均回归通过，旧 N3b 冻结档仍在里程碑测试内通过。`node tools/test_white_fox_causal_entry_contract.js` 8/8 通过，浏览器左右选择轨迹已留存，用于下一批的效果/NPC/续卡核对。独立只读审查先发现来源更新及图损坏会误归档，现已修复并复核无剩余 P1/P2。

**剩余具体链路**：N6a 下一批应把 `q_whiteFox_quest` 左选的 NPC `DEAD`、任务 `failed`、来源效果/寿元，以及右选的相遇 flag、step1、`q_whiteFox_2` 续卡作为一个可回滚的提交；再接第二张左右选择与第三张展示。第三张左选必须交给战斗合同与胜败/逃结果，右选需校验 20 灵石与完成奖励，下选需记录放弃；在这组状态机与战斗回调可验证前，入口只可展示不可操作。当前完整 Godot 总门禁已跑至并行战斗 `presentation_integration.gd` 才退出 1，失败为木人胸口接触点偏差 `0.68315225839615`；N4b 非战斗项目依赖此前均通过，不把总门禁标为通过。开局 UI 专项这次退出 0，但退出时报告 6 个 ObjectDB/2 个资源警告，需单独处理。未触碰战斗场景、战斗角色或其并行测试。

## 2026-10-19 N6a 白狐前两张任务卡结算 Slice Charter

| Issue | 玩家契约与状态权威 | 先失败验证与验收 |
| --- | --- | --- |
| N6a-01 | 从已保存的 `q_whiteFox_quest` 做左/右选择，来源数值、寿元、NPC 生命周期、任务结果或 step1、下一张卡必须在同一 v2 修订提交；救狐后 `q_whiteFox_2` 再做左/右选择，进入来源 `q_whiteFox_3`，第三卡战斗/支付/放弃仍须守住独立接口。权威为 `data/quests/white_fox.json`、`data/npcs/core_npcs.json`、网页版 `QuestSystem`/`WorldContinuityStore`/`EffectService`，对照两份真实浏览器轨迹。 | 先增加 `godot/tests/noncombat_whitefox_choices.gd` 红测：当前 `QUEST_PENDING` token 为 0、拒绝选择。后续核对两个首卡分支、二卡两选、NPC `DEAD`、任务 v3、失血寿元、种子节拍、重启/重复/写盘失败及来源 SHA；第三卡仅呈现，不允许未迁战斗合同的选择。独审与完整门禁另记。 |

**N6a 实施与证据（2026-10-19）**：先红测“白狐选项未接通”，再把来源白狐前两张卡的四个选择接到 `noncombat_quest_flow.gd`。首卡左选按网页 +12 修为、-1 气血、+18 恶因并扣 1 寿元，15 名来源 NPC 的初始 `WorldContinuityStore` 形状在同次存档建立，`bai_luoxuan` 转 `DEAD/ECHO_ONLY`、任务 `failed`；右选 -3 修为、+18 善因、+8 福缘，设相遇 flag，任务推进 step1 并显示 `q_whiteFox_2`。第二张左选 +18 修为/+10 福缘/+5 善因，右选 +8 道心/+8 善因/+15 福缘，均推进 step2 并显示来源 `q_whiteFox_3` 与其原图；第三卡三种选择没有 token，等战斗与任务结束结算合同。`noncombat_world_continuity.gd` 的 15 名 NPC 初始顺序/修订和左选死亡修订与网页版状态结构对照。两份原浏览器轨迹加新采的 `noncombat_whitefox_right_right_browser_trace.jsonl` 提供首卡左右、第二张左右数值；`noncombat_whitefox_choices.gd` 剑修两种首卡、两种二卡、桌面 UI 卡图/按钮、写盘失败、重复 token、q2/q3 重载均通过。

独审两次指出重放反例后修复：旧 N4b 白狐入口档没有 `npcSourceSha/worldContinuityState`，现在严格重放维持旧形状，下一次成功选择在候选快照中一次性补齐；q2 续卡图损坏时，重放向存档层传播来源错误，保留原 v2 字节。新增回归分别冻结旧形状与模拟坏图，独审复核 N6a 有界范围无剩余 P1/P2。N6a 选项专项覆盖剑修，入口专项覆盖四修；四修选择效果尚未逐一路径浏览器对照。尚未接 `ch_qi_60`、第三卡狗群战斗/付费/放弃、后续任务奖励和完整 Flow 仲裁。原网页第三卡“仍被困”与前文救出矛盾，保持源文待统一剧情审校。

最终专项 `noncombat_whitefox_entry.gd`、`noncombat_whitefox_choices.gd`、`noncombat_milestone_flow.gd`、`noncombat_opening_ui.gd`、`noncombat_run_session.gd` 均退出 0；`node tools/test_white_fox_causal_entry_contract.js` 8/8 通过。最终完整 `python tools/validate_godot_runtime.py` 已跑过新增两项白狐专项，仍在并行战斗 `presentation_integration.gd` 退出 1：木人胸口接触点距离 `0.68260216712952`；不记作全项目通过。未修改该并行战斗文件。

## 2026-10-19 N4a 首轮避开后的炼气章节续卡

| Issue | 来源与玩家契约 | 本批结果及剩余边界 |
| --- | --- | --- |
| N4a-01 | 网页四修首轮避开后，回应卡确认会按章节阈值优先出 `ch_qi_20`（实际触发阈值 15、旧卡 ID 20）；选后因初始修为已超过 30，再出 `ch_qi_40`。两张卡的文案、场景图、效果、因果种子与主线事实必须由来源数据和 `RealmChapterSystem` 投影，不能仅把卡 ID 写死。 | `noncombat_milestone_flow.gd` 读取源 `chapter_milestones.json` 与 `causal_graph.json` 的校验副本，按 15/30 阈值、路径变体与已触发记录投影；四修真实开局可选第一张，随后进入第二张，两个决定和主线事实均保存并可恢复。第二张之后的任务/普通卡仲裁尚未迁移，停在 `FLOW_PENDING`。 |

**先失败再实现**：`godot/tests/noncombat_milestone_flow.gd` 初次运行在“来源章节卡未调度”处退出 1。实现后四修从真实开局到避开回应、首张与第二张里程碑，校验路径场景图可由 Godot 真实加载、阈值 15→30、来源效果、因果种子按决定时钟递减、主线 `qi_main_call` 的产生与第二拍消费、坏章节 SHA 拒绝写盘、失败写盘回滚和严格重载，专项退出 0。首张左选/第二张右选及首张右选/第二张左选都按四修实测；后一组直接与 `noncombat_milestone_cross_browser_trace.jsonl` 的角色属性、种子及章节进度逐项比较，期待值冻结于 `godot/tests/fixtures/n4a_cross_browser_expected.json`。追加体修寿元源轨迹后发现首轮“避开”少扣 1 寿元：网页版将遭遇卡视为 `COMBAT` 决定，避开也扣寿元；`noncombat_avoid_flow.gd` 已修正，体修首张右选寿元从来源 78→77 并与 Godot 对齐。默认桌面 UI 在回应后自动恢复可调度的章节卡；独审发现早期 N3b 旧档缺 `promise` 且回应卡字段更少，现以两份从真实旧存档冻结的原始字节回归，分别从回应待确认与 `FLOW_PENDING` 原样重放，在下一次动作补齐旧版缺少的因果时钟节拍与首轮避开寿元费用，原决定不重写，再次重载通过。`tools/validate_godot_runtime.py` 纳入该专项。

**浏览器对照与边界**：`tools/capture_noncombat_avoid_browser.js --ack --milestone-choice` 的四修固定随机带实跑均为回应→`ch_qi_20`→`ch_qi_40`；原卡 ID 20/40 对应当前触发阈值 15/30。源四修路径变体的左右效果、图片和因果种子均来自 `data/cards/chapter_milestones.json`，不是 Godot 新写剧情。剑修继续选择第二张右选，网页第 9 决定到 `q_whiteFox_quest`；Godot 此处仍停在 `FLOW_PENDING`，下一批需迁任务触发与 Flow 仲裁。当前首轮专用 `noncombatFlow.spineFacts` 按来源 `NarrativeLedger` 记录主线事实，但尚未代替完整叙事账本。网页版刷新会重置 EncounterDirector 的既有差异仍未被误报为等价。

**本轮门禁与源数据现状**：`noncombat_milestone_flow.gd`、`noncombat_avoid_flow.gd`、`noncombat_opening_ui.gd` 三项 Godot 专项均退出 0；UI 专项有一次退出时报告 6 个 ObjectDB/2 个资源释放警告，随后复跑未重现，仍不能据此声称已系统排除。完整 `python tools/validate_godot_runtime.py` 退出 1，停在并行战斗 `presentation_integration.gd`，木人胸口接触点偏差 `0.68306314945221`，因此未宣称全项目通过。`node tools/validate_chapter_path_variants.js` 为 24/24 通过；另一个来源遗留数值测试 `node tools/test_p3_12_milestone_values.js` 为 31/40，9 项失败集中在后期战斗章敌人数值/旧预期和 `combatChance`，本批没有修改来源 JSON，也不把该测试当作 N4a 通过证据。

## 2026-10-19 N3b 四修教学遭遇的避开决定与续卡

| Issue | 玩家契约、现状与根因 | 本批验收 |
| --- | --- | --- |
| N3b-01 | 玩家在来源教学遭遇选择“避开”时，应按 `encounters.json` 的**各自**效果结算，记一次决定并让 EncounterDirector 进入 avoided/cooldown；来源遭遇不能进入 `cardsPlayed` 或 resolved。现有 Godot 邀约只开放迎战，右选直接拒绝。网页版四修代价不同，不能用统一 `knowledge.world+1` 实现。 | 真实网页版入口采集四修右选的资源、导演、下一卡和重载轨迹；Godot 从四修真实开局右选后与来源对照。写盘失败、重复点击、跨重载、来源 SHA 变化都不造成第二次结算；未迁完整 Flow 的部分明确停在可恢复调度边界，不伪造固定山径续卡。 |

来源链：`GameUI.makeChoice → GameLogic._makeChoiceInternal → EffectService → GameStateManager → EncounterDirector._onCardChosen/_settleCadence → FlowDirector.getNextCard → GameUI`。Godot 目标链为 `noncombat_opening_ui → noncombat_domain.choose → 候选快照（来源效果、director/flow 状态、决定回执）→ RunSession.commit_snapshot → 卡投影`。本批不改并行战斗场景或源 Web 作者数据；先运行来源入口、旧 Godot 专项和失败回归，再落代码。

**N3b 本轮落地与证据**：`tools/capture_noncombat_avoid_browser.js` 从真实网页开局逐一采集剑/法/体/丹右选：来源决策 5→6，效果分别为 `knowledge.world+1`、`knowledge.world+1`、`health+1`、`fortune+1`，结果卡 ID 分别为 `promise_result_8f87a81d`、`promise_result_0105e2c0`、`promise_result_2aae4ec5`、`promise_result_799e44eb`；导演均标记 `avoided`、冷却到决定 8，下一次到期为 15/14/15/15；遭遇来源 ID 不进入 `cardsPlayed`。`noncombat_avoid_flow.gd` 从经八文件 SHA 校验的作者数据生成一次候选状态；`noncombat_domain.gd` 只有提交成功才发布回应卡，确认回应时再把承诺标为 resolved 并停在 `FLOW_PENDING`。`noncombat_opening_ui.gd` 显示来源避开文案、回应与可恢复的续篇边界。没有通用 Flow 仲裁与冷却后的实际遭遇再排期，N3b 完整门禁仍未通过。

**失败回归及差异**：新增 `noncombat_avoid_flow.gd` 测试在实现前因右选无生产者退出 1；实现后四修、结果 ID、来源选择/导演、回应确认、双重点击、写盘失败、存档恢复、来源 SHA 漂移以及游戏运行中回应确认前的规则漂移均退出 0。来源网页版四修在避开后按刷新键会从 `promise_result_*` 跳到 `q_whiteFox_quest` 并丢失导演冷却；复核等待后仍如此。Godot 保留回应与导演状态是明确的持久性修复，**不是**当前网页重载语义的逐字等价。网页回应卡本身无场景图，Godot 复用遭遇卡的作者场景图作展示，这是媒体投影调整。回应卡已带来源承诺 ID、语义键、叙事标识与确认 resolution，首轮专用 `noncombatFlow.promise` 保存 pending→resolved；尚未把它并入通用 `NarrativeLedger/FlowDirector`，后续长局承诺迁移不能以本字段代替。

**审查与门禁**：独立只读复核确认四条即时避开结算与 Godot 重载；指出网页版重载差异和运行中来源漂移风险，后者已添加拒绝写盘守卫及负例。`godot/tests/noncombat_avoid_flow.gd`、`noncombat_opening_ui.gd` 和非战斗专项目标均通过；`python tools/validate_godot_runtime.py` 仍在并行战斗 `presentation_integration.gd` 退出 1，木人胸口接触点偏差约 `0.683`，因此不能宣称全项目回归通过。

## 2026-10-19 N3a 首轮迎战预警与待战生产者

| Issue | 玩家契约、根因与批次边界 | 验收 |
| --- | --- | --- |
| N3a-01 | 网页遭遇左选仅冻结来源选择并展示 `COMBAT_WARNING`；预警左选直接迎战，右选花 10 灵石并恢复至多 1 点气血。二者都不能提前结算来源 `choiceHistory`、`cardsPlayed`、回合或奖励。Godot 原先只显示 `COMBAT_HANDOFF` 邀约，`BATTLE_PENDING` 全靠测试手造。此批让真实开局经持久候选快照生产预警和 v2 待战请求；避开依赖尚未迁入的 `EncounterDirector/FlowDirector` 调度，暂不开放；战斗场景、结果结算和战斗美术不在此批。 | 四修来源邀约可点击迎战，来源警告可左右备战；每次写盘成功后才换屏。重启预警和待战均恢复同一 owner/来源/费用，错误旧令牌、费用不足、改错八文件 SHA、写盘失败和重复确认拒绝。真实 `Domain` 产生的状态须通过 `BattleGateway.build_request`，不以合成 Dictionary 代替。 |

修复前新增 `noncombat_warning_flow.gd`，真实剑修开局在邀约选择处失败：`offer changed on an unsupported avoid action`（原 `issue_choice_token()` 为 0，未接迎战）。实现后 `noncombat_encounter_flow.gd` 只生成候选状态，`noncombat_domain.gd` 调用既有 `RunSession.commit_snapshot` 成功才发布。`BattleGateway.source_resolution_for_offer` 从经 SHA 验证的原遭遇/表现规则冻结来源选择，并在待战请求重验；Godot JSON 读档将整数解析成浮点，网关对完整来源选择做 JSON 值规范化比较、对开场护盾值做严格数值比较，防止正确存档被误拒。网页原流派第一战不触发特殊 Boss 预警规则，使用 `CombatCoordinator` 的普通左右预警文案与费用。

**当前完成边界**：默认桌面入口现在能点击“迎战”、看战前预警并选择左右备战；确认后显示“待战合同已保存”，不自动进入尚未接协议的战斗场景。右侧“避开”暂不显示，避免把来源遭遇永久注销或错误跳到固定剧情。`BATTLE_PENDING` 已有真实生产者和恢复测试，战斗适配器/真实胜败逃回传与战果卡仍未完成。旧 Godot v1/v2 `COMBAT_HANDOFF` 不改旧字节，重开后仍是可选择的邀约；新行动记录仅在首次迎战时进入 v2 快照。来源导演文件漂移时不归档原待战存档，保留原文并锁住入口。

**N3a 可复核证据（2026-10-19）**：`godot/tests/noncombat_warning_flow.gd` 从 `Domain.start()` 经教程、四修序章进入真实邀约，覆盖剑修序章左右与剑/法/体/丹四流派的五个代表组合。验证迎战只冻结来源、警告左右备战的 10 灵石/至多 1 气血差别、待战 v2 请求、重启后相同 owner、旧令牌/重复确认拒绝、费用不足、写盘/重命名失败回滚、来源 SHA 漂移保档；专项退出 0，输出 `NONCOMBAT_WARNING_FLOW_PASS cases=5`。额外注入 `pendingWarning:null` 的 v2 坏档，修复前 Godot 报 `Trying to assign value of type 'Nil' to a variable of type 'Dictionary'`，修复后 `restore()` 正常拒绝且专项无脚本错误。`validate_godot_runtime.py` 现在也把 Godot 的 `SCRIPT ERROR:` 当成失败，避免脚本报错后测试仍打印 PASS 的假阳性。`noncombat_run_session.gd` 专项退出 0；它确保清单或源文件缺失归 `SOURCE_UNAVAILABLE`、实际规则字节 SHA 不符归 `SOURCE_MISMATCH`，两类都不归档原档。来源 `node tools/test_agc_first_session_contract.js` 退出 0。独立只读复核重跑 RunSession、预警、开局 UI、战斗边界和三槽 UI 专项，均退出 0；复核将正常待战链路评为 VERIFIED，仍明确不覆盖真实战斗消费者/战果。

**总门禁**：`python tools/validate_godot_runtime.py` 中当批 14 个非战斗专项及其后的首战基础回归走完，随后在并行战斗 `presentation_integration.gd` 退出 1：木人胸口接触点距离约 `0.683`。因此本批只能报告非战斗链路专项通过，不能报告全项目门禁通过。来源 `node tools/test_gdd_b7_encounter_director_cadence.js` 为 16/16 通过，证明网页版避开、冷却与再排期语义可作为 N3b 对照。N3b 已落资源、导演冷却与首轮承诺检查点；通用 `FlowDirector` 续卡及再排期仍归 N4，不可因专用 `noncombatFlow` 字段而宣称完成。N5 薄适配器需从已持久的 `battle_request()` 启动战斗，并在终局一次写入战果回执、来源效果及战果卡。四修全 4×2×2 组合与实际桌面视觉/声音仍需补验。

以下 N1d、N1c、NC-05a 等节保留当批形成时的证据和状态措辞；判断**当前**进度应以上述 N3a 记录与任务书第 6 节为准。

## 2026-10-19 N1d 来源规则单一校验入口

| Issue | 玩家契约、当前错误与根因 | 本批入口与验收 |
| --- | --- | --- |
| N1d-01 | 玩家看到的四修教学遭遇、未来待战请求和来源版本指纹必须来自同一份经 SHA 校验的原数据。当前开局域经 `ContentRepository.read_module` 校验，`BattleGateway` 却从 `RuntimeDataRegistry.read_json` 的可变缓存直接读遭遇、表现、起始牌组与清单；这允许被改写的缓存改变邀约内容或签出伪造的来源指纹，导致状态与显示的规则版本分裂。 | 默认 Godot 开局真实 `q_start_* → encounter_card_*` 仍显示四修原邀约；网关所有业务 JSON 改由 `ContentRepository` 只读读取，八份参与首轮交接的规则源均验证当前文件 SHA 后才给出邀约/指纹。专项测试先在篡改 registry 缓存时失败，再通过；任一参与来源 SHA 错误拒绝邀约与待战请求，不修改存档、不触碰并行战斗场景。 |

源码链路结论：网页版 `GameUI.makeChoice → GameLogic.makeChoice/_makeChoiceInternal → EffectService/ChoiceOutcomeRouter → EncounterDirector + FlowDirector → GameStateManager checkpoint → GameUI.renderCard`。`CardSystem._buildCombatEncounterCard` 由 `encounters.json` 生成邀约；左选只是冻结战斗来源并转预警，预警确认后才进入战斗，战果认证后才写来源选择和结果卡。右选的 `knowledge` 经 `EffectService → GameState.addKnowledge('world')`，记一次选择，但 `EncounterDirector` 只记 `avoided`、冷却后可再次排期，不能把它标为永久完成或直接跳到山径。网页版 `GameLogic`、`FlowDirector`、`EncounterDirector` 的分散可变状态和 UI 重入风险不逐行搬迁：Godot 在**同一候选快照**保存当前决策、调度队列/游标、导演待决/冷却、知识、一次性回执和来源指纹；写盘成功后才发布画面。此批先封闭来源校验断点，后续 N2/N3/N4 依该快照合同实现可玩的邀约选择。

**N1d-01 验证结果**：真实四修左右八条 `Domain.choose()` 路线仍显示原邀约，重载后同图同 ID。伪造 `RuntimeDataRegistry` 遭遇缓存的测试先失败，改用校验仓库后通过；错误 `paths.json` SHA 的“残缺邀约”测试先失败，网关改为完整来源校验后通过。独立只读复核发现网页 `_withEncounterPlanGraph()` 还读取 `encounter_director.json`，已将其加入指纹；并让 `cards:qi` 原始卡不存在时拒绝邀约。专项测试故意改错遭遇、路径、原卡和导演规则的 manifest SHA，邀约与指纹均为空。这里验证的是**目前首轮网关交接依赖的八份源**及纯函数合同；`BATTLE_PENDING` 尚无生产态创建和战斗消费者，完整战斗规则的 N5 版本锁定仍未完成。总门禁的并行战斗失败单独记录，不因此宣称全项目通过。

N1d 复核：`node tools/test_agc_first_session_contract.js` 和 `node tools/test_gdd_b7_encounter_director_cadence.js` 分别通过；Godot `noncombat_battle_boundary.gd` 通过（8 份邀约、8 份合成待战合同），全项目 `python tools/validate_godot_runtime.py` 仍退出 1，停在并行战斗 `presentation_integration.gd` 的木人胸口接触点距离 `0.68316173553467`。脚本顺序在该战斗测试前已运行全部 13 个非战斗专项；独立只读审查判定 N1d 邀约来源校验 VERIFIED、真实战斗交接 UNPROVEN。

## 2026-10-19 N1c 首轮遭遇邀约原场景媒体

| Issue | 玩家契约、当前错误与根因 | 本批入口与验收 |
| --- | --- | --- |
| N1c-01 | 四修序章进入教学遭遇时，玩家应看到来源 `encounter_presentations.json` 为该遭遇指定的场景图。当前 `noncombat_opening_ui.gd::_render` 固定显示上一张序章卡的 `originSceneImage`；`noncombat_battle_gateway.gd::_resolve_offer` 未投影遭遇图；内容同步只装了剑修第一战图，其余三张未入包。结果是原网页的地点与 Godot 玩家看到的地点不一致。 | `first_session_cohesion.json` 四条路线 → 来源 encounter/presentation → `BattleOffer.sceneImage` → Godot 资源加载 → 当前邀约屏。八个序章方向均应投影自己路线的原场景图，四张图片按原字节 SHA 入包；缺来源图时拒绝错误回退。测试先失败再修复，重开显示同图；不改并行战斗场景和角色素材。 |
| N1c-02 | 非战斗剧情 JSON 中已有 553 处 `sceneImage` 引用，其中 20 处/13 种跨 `assets/combat/` 的故事/任务/章节图片未进入 Godot 内容清单；这会使将来的原卡与条件变体无法显示原图。根因是同步器按目录排除所有 `assets/combat/`，没有按字段区分非战斗剧情图。 | 仅从非战斗源 JSON 的 `sceneImage` 字段派生跨目录图片，按原字节 SHA 入包；553 处来源指针应保持不变，清单缺项降为 0，13 种图片可导入 Godot Texture。测试先失败再修复；本批不声称尚未迁入的任务/线程消费者已经可玩。 |

本批只修复遭遇邀约媒体的来源/消费链。迎战/避开与预警状态要遵守网页的决定延迟结算；在其可恢复状态和下一卡调度实现前，不把静态的邀约文案伪装成已可点的战斗选择。原场景图本身的战斗美术升级仍由并行战斗任务处理。

**N1c 验证结果（2026-10-19）**：先在 `noncombat_battle_boundary.gd` 与 `noncombat_opening_ui.gd` 加来源场景图断言，两项均在修复前失败；补齐 `BattleOffer.sceneImage`、四修遭遇表现图入包及 UI 消费后通过。`noncombat_battle_boundary.gd` 检查四修序章左右共 8 个方向的来源 ID 与场景图；`noncombat_opening_ui.gd` 实跑四修到邀约、剑修重开以及缺图注入负例，缺图时清旧图并提示错误；`noncombat_save_slot_ui.gd` 实跑默认三槽的剑修邀约与重载，并要求图片非空。源 `sceneImage` 仍有 553 处，原来缺清单的 20 处/13 种现为 0；跨 `assets/combat/` 的 13 种非战斗场景图逐张经过来源 SHA、清单 SHA 和 Godot Texture 加载验证。同步后清单为 74 份 JSON、603 张图片，其中 531 张按非战斗运行引用选入、32 个音频。独立只读 QA 复跑专项并核对四修图的来源/清单 SHA，N1c-01/02 的**媒体链**通过；13 张图对应的任务/章节运行消费者尚未迁入，不能计入剧情可玩覆盖。

本批 `python tools/validate_godot_runtime.py` 在全部非战斗专项通过后停于并行战斗 `presentation_integration.gd`：木人胸口命中标记距离 `0.6830148100853`，总门禁退出 1。该失败与本批改动文件无交集；战斗侧须修复后重跑总门禁，当前不能写“项目总门禁通过”。无头 Godot 的 `frame_post_draw` 截图未产生有效图片，桌面实际画面仍需人工视觉验收。

**N1c 验证结果（2026-10-19）**：先在 `noncombat_battle_boundary.gd` 与 `noncombat_opening_ui.gd` 加来源场景图断言，两项均在修复前失败；补齐 `BattleOffer.sceneImage`、四修遭遇表现图入包及 UI 消费后通过。`noncombat_battle_boundary.gd` 检查四修序章左右共 8 个方向的来源 ID 与场景图；`noncombat_opening_ui.gd` 实跑四修到邀约、剑修重开以及缺图注入负例，缺图时清旧图并提示错误；`noncombat_save_slot_ui.gd` 实跑默认三槽的剑修邀约与重载，并要求图片非空。源 `sceneImage` 仍有 553 处，原来缺清单的 20 处/13 种现为 0；跨 `assets/combat/` 的 13 种非战斗场景图逐张经过来源 SHA、清单 SHA 和 Godot Texture 加载验证。同步后清单为 74 份 JSON、603 张图片，其中 531 张按非战斗运行引用选入、32 个音频。独立只读 QA 复跑专项并核对四修图的来源/清单 SHA，N1c-01/02 的**媒体链**通过；13 张图对应的任务/章节运行消费者尚未迁入，不能计入剧情可玩覆盖。

本批 `python tools/validate_godot_runtime.py` 在全部非战斗专项通过后停于并行战斗 `presentation_integration.gd`：木人胸口命中标记距离 `0.6830148100853`，总门禁退出 1。该失败与本批改动文件无交集；战斗侧须修复后重跑总门禁，当前不能写“项目总门禁通过”。无头 Godot 的 `frame_post_draw` 截图未产生有效图片，桌面实际画面仍需人工视觉验收。

## NC-02A 开局声音重整（2026-10-19，进行中）

用户原话："游戏声音的部分完全是乱的……全部重做或者……找对应剧情的素材，合适的音调台词放进去"。这轮先让 Godot 桌面版**实际可达**的开局成为可听验收段；全游戏 615 个选择节点需随 NC-04 剧情消费者迁移逐段扩展，不能把音频文件已复制当作剧情配音完成。

声音设计支柱：①地点先于曲目（山风、雷雨、水瀑、丹火各自有空间来源）；②台词必须和眼前的文字、说话者一致；③阅读时音乐让位给叙事，誓言进入时自动压低音乐；④选择只在存档成功后响，避免假的因果反馈。体验假设：玩家从功法选择走到自己的序章时，听到与画面一致的环境和**此时才说出口**的誓言，会更清楚地感到进入哪条修行路。下一秒应分辨地点；本次开局应分辨四道；长期应能从声音预感剧情危险但不替玩家做选择。最小证明：剑修到 `q_start_sword` 才触发已录的剑道誓言和剑冢山风，重开同一未决卡不会重播誓言。

入口—结算—反馈：`noncombat_opening.tscn` → 选槽/选道 → `noncombat_domain.start` 保存 → `STARTED` → 教程；选择 → `choose` 持久化 → `CHOICE_COMMITTED` → 下一卡声景；恢复只做声景同步。Web `data/cards/qi.json` 和 `data/audio/path_identity.json` 仍为 ID/台词权威。现有四段 oath 的原文与 `q_start_{path}` 路线一致，但当前 Godot 在 `tutorial_1` 就播放，导致台词时间/地点错位；四曲 CC-BY 替换文件与 catalog 中 ACE-Step 制作描述不一致，详情见 `assets/audio/AUDIO_ATTRIBUTION.md`。新外部环境素材须逐件登记来源、作者、许可证、文件 SHA；试听未核准时不能宣称美术总监级混音。

| Issue | 错误链与本轮目标 | 修复前证据 | 边界与验收 |
| --- | --- | --- | --- |
| AUD-01 | `STARTED` 在教程播路线誓言；`CHOICE_COMMITTED` 仅 snap；无场景环境层。把誓言放在首次进入对应 `q_start_*`，四处环境独立，在恢复时只恢复环境，不重说誓言。 | 旧 `noncombat_opening_audio.gd` 只有 BGM、SFX、voice 三播放器；`noncombat_opening_ui.gd::_on_opening_changed` 的 `STARTED` 同时播 oath。新回归测试须先失败。 | 来源卡 ID → 声景 profile → 资源；四路、跳过教程、恢复、重复选择、换槽、语音自动 duck/restore。 |
| AUD-02 | 现有全局 sect BGM 被用于所有可达开局地点，替换音乐的 catalog 文案仍称定制国风。建立媒体真实来源账本和适度背景音量；未试听通过的音乐不按虚假风格命名。 | `path_identity.json` BGM 制作元数据与 `AUDIO_ATTRIBUTION.md` 的 2026-10-11 替换声明冲突。 | 不把旁白盖住；不将候选环境声误标为原创；音频包哈希、Godot 资源加载。 |

本批来源媒体矩阵：四段原文件及其来源、作者、授权、SHA 见 `assets/audio/AUDIO_ATTRIBUTION.md`；稳定 ID 与卡 ID 在 `data/audio/path_identity.json::openingSoundscapes`；Godot 消费者为 `scripts/noncombat_opening_audio.gd::set_story_scene`；触发为 `STARTED`、`CHOICE_COMMITTED` 或 `RESTORED`；`tests/noncombat_opening_audio.gd` 与 `tests/noncombat_opening_ui.gd` 验证。其他 500 余剧情图、NPC 台词、任务/同伴/商店/战斗声音属于后续整线重制，不以这一段代替。

### 声音工作包与人物声音规范

现有来源 `data/` 仅两份剧情 JSON 有 `audioCue`（`tianshu_codex.json`、`last_lesson_threads.json`），另有 3 段 `assets/audio/voice/*intro.mp3` 未见运行引用和逐句字幕合同。因此全局声音重做不能靠给 615 个静态选择节点自动配音：先随 NC-04 建立实际可达卡与状态变体图，再按**场景、剧情转折、角色说话行为**配声。每次扩容继续沿用同一 `openingSoundscapes` 式的来源 ID → 稳定场景 ID → 音频消费者结构，但改名为通用声景路由并与完整 `PresentationResolver` 合并，避免第二套进度状态。

| 顺序 | 可听范围 | 音乐/环境/SFX | 台词交付和通过条件 |
| --- | --- | --- | --- |
| A（本批） | 教程 + 四修序章 | 山风、远雷、野外瀑布、炉火；旧 BGM 压低当临时底层，过场环境淡入淡出 | 四句原 oath 各在对应序章首次进入时播，逐字字幕；读档不重播，选择失败不出声 |
| B（NC-04 首段） | 教学遭遇预警与战后第一张剧情卡 | 预警用短促低频提示，不用持续心跳；战果从战斗场景的已提交结果决定声态 | 仅对有明确说话者和来源文字的节点配台词；战斗断点恢复不重复台词 |
| C（任务/同伴） | 白狐、最后一课、天书等可达分支 | 林间/室内/秘境的底噪各守物理空间；因果反转用短 cue，不能把普通点击伪装成重要回响 | 建角色声音档案：年龄气质、节奏、口音边界、情绪禁区、声线连续性；每句锁 speaker ID、来源卡/变体、文字、进出条件、字幕和素材 SHA；不拿通用 TTS 朗读整张卡 |
| D（坊市/地图/战斗） | 各商贩、地点、技能相位 | 环境声随地点变，价格/交易只有成功回执才响；战斗 attack/impact/status 与画面接触帧同步，避免 generic hit 叠声 | 人物台词及战斗喊声须明确角色身份，按角色统一录制/生成并人工挑选；旧 NPC intro 三文件先核文、核授权后方可接入 |
| E（终盘/发布） | 六境、死亡/转世、结局 | 四首 2026-10-11 替换曲目按实声重新试听，逐首判保留/重配；作同世界观的旋律动机和响度母带 | 代表性每分支通路、存档恢复和 Windows 导出试听；资源路径、授权署名、字幕与语言设置一致 |

音色约束：主角同一人可有四修不同呼吸与意图，但不可突然换声线；NPC 要和其文本身份、关系、年龄感区分，不使用通用播报腔、名人模仿或凭文件名猜台词。关键情绪留白，受击和选择音不要盖住对白。音频事件只消费已提交的决定、已呈现的卡或动画接触点；过时、重复、读档重建事件默认静音。

后续配乐委托的统一母题先定为两音问句和一个未落地的回答，四修改变的是触感、空间和呼吸，不是换成四首互不相干的歌：断剑池用干燥拨弦/稀疏金属尾音、观天台用远雷下的低箫与符纹脉冲、雷音瀑布用水声间的短鼓与低弦、丹房用陶器轻碰与近场炉火。教程允许长留白；台词入场时任何有节拍的层退后。每首新曲交付主混、无打击乐层、环境层和可无缝循环版本，并拿真实字幕与连续选择实听，拒收响度过高的预告片式鼓点、通用仙侠音色包和随意拼接的古风段落。当前四首 CC-BY 曲只作占位声音，不能把旧 `prompt` 当它们的音色实测结果。

### 2026-10-19 可重复证据与遗留

| Issue | 根因与修复文件 | 修复前 → 修复后 | 边界 / 独立校验 / 状态 |
| --- | --- | --- | --- |
| AUD-01 | `noncombat_opening_ui.gd::_on_opening_changed` 在 `STARTED` 提前播 oath；`noncombat_opening_audio.gd` 无地点层。改为按来源卡 ID 在已提交后切 5 类声景，四句誓言只于四个序章首次进入说出，字幕来自 `path_identity.json`，音乐和环境在说话时 duck。 | 修改后的 UI 回归测试在旧代码上退出 1：`tutorial should have reading music but no out-of-scene path oath`；最终 `noncombat_opening_audio.gd` 输出 `soundscapes=5 oath=4 duck=4`，`noncombat_opening_ui.gd` 输出 `prologue_oath=true resume_ambience=true`，均退出 0。 | 四修、同卡重复调用、恢复序章、未知战斗交接、循环与音量恢复通过；原有 `validate_godot_runtime.py` 非本批编写，已通过。代码接线与来源校验通过；真实耳机听感 `UNPROVEN`。 |
| AUD-02 | 旧四曲仍为 2026-10-11 的 CC-BY 替换文件，ACE-Step 制作文字已过时。`path_identity.json::generation.music` 标明原曲是历史候选，运行来源指向 `AUDIO_ATTRIBUTION.md`；场景设 `musicGain`，四处自然声选有授权的原文件。 | `sync_runtime_content.py` 输出 `audio=32`；`noncombat_asset_import.gd` 输出 `audio=32`；`validate_noncombat_asset_coverage.py` 输出 `audio=32`；完整 `validate_godot_runtime.py` 输出 `RUNTIME_MIGRATION_PASS ... audio=32`，均退出 0。 | 4 个外部文件的 SHA/作者/授权在署名表；Godot MCP `godot_get_project_info` 报 32 音频。旧 BGM 的音乐风格尚未重新作曲或人工听审；此项只完成源信息纠偏与开局混音缓解，全曲重制为遗留。 |

未通过的听感/剧情范围不可报“全部声音已重做”：Web 的 `AudioManager` 仍在 `path:selected` 时播 oath，且三段未接线的 NPC intro 尚未核对内容；Godot 目前仅 8 个来源开局节点可玩。以上差异须在对应剧情消费者接入时处理，不能把静态 615 节点数写成已配音节点数。

完整实施顺序与模块部署见 `NONCOMBAT_FULL_MIGRATION_TASKBOOK.md`；本文件只维护各批次真实完成证据和剩余缺口。

日期：2026-10-18。此记录只描述当前工作树中的可运行迁移证据；网页 `data/` 和 `assets/` 仍是内容权威源。桌面版优先，不增加手机端入口。Godot 默认入口已改为 `scenes/noncombat_opening.tscn`；原战斗切片保留在 `scenes/main.tscn`，可单独运行。

## 2026-10-19 NC-05a 战斗接口预备 Slice Charter

玩家要求按当前进度更新 `NONCOMBAT_FULL_MIGRATION_TASKBOOK.md` 后执行，让非战斗迁移与另一边战斗场景复用并行。此批只处理一条「序章已提交 → 来源教学遭遇邀约 → 可校验的战斗请求/结果槽位」链，不修改战斗场景/战斗域，也不声称已经进入战斗或返回剧情。源 Web `CardSystem._buildCombatEncounterCard` 为 `encounter_card_<id>` 生成迎战/避开两选；`CombatCoordinator._createEncounterContext/_claimCombatOutcome` 给战局确定性身份并拒绝外来结果；`GameLogic._resolveCombatOutcome` 在来源决定事务中结算胜败逃。当前 Godot 的 `COMBAT_HANDOFF` 已到遭遇邀约，尚未迎战或预警确认，必须明确分清这几层。

| Issue | 用户声明的问题与现状 | 根因 / 本批修复位置 | 修复前失败证据 | 边界与验收 | 修复后证据 / 独审 / 状态 |
| --- | --- | --- | --- | --- | --- |
| NC-05a-01 | “需要进入战斗系统的每个接口代码也衔接好留给槽位”；现有 UI 只显示教学遭遇 ID，玩家看不到来源遭遇内容 | `noncombat_opening_ui.gd::_render` 将 `COMBAT_HANDOFF` 当空卡；新增只读 `noncombat_battle_gateway.gd::offer_from_state` 并由 UI 展示来源题名、敌手、战前情报 | 新 `noncombat_battle_boundary.gd` 在网关文件不存在时退出 1；旧 UI 的 `current.is_empty()` 分支只显示“教学遭遇待接入”及 ID | 四修八选、重载、非法 ID/路径/境界；不擅自选迎战、不使用不存在的战斗图、不改剧情状态 | 新测试 `offers=8`，原生 UI 实点显示“剑修证明·一线快剑/快剑木人”且重新打开保留；完整 Godot 门禁通过。独立只读审查 `VERIFIED`（实入口、来源身份、读档和非法来源均核对）；本批完成 |
| NC-05a-02 | 另一边战斗复用任务需要稳定输入/输出合同；当前固定首战只读 `enc_trial_sword_swift`，无完整 request/result 校验 | `main.gd::_ready` 固定 `load_m0_opening()`；独立网关按**将来应持久的** `BATTLE_PENDING` 合同投影 request，并校验 result，不触碰战斗代码；N3–N5 再接实际生产者与结算消费者 | 新 `noncombat_battle_boundary.gd` 在网关文件不存在时退出 1；既有 `main.gd` 没有接收请求的入口 | 未确认邀约不得启动；四修身份稳定；错 owner、错来源、重复/未知结果拒绝；`validated` 不等于已持久结算 | v1 合成测试曾错误要求战前已有来源迎战历史/完成回执，现由 NC-05a-03 废弃并替换；真实生产态 `BATTLE_PENDING`、战果消费及读档仍缺，独审 `UNPROVEN` |

本批 Evidence Manifest：来源 `data/progression/first_session_cohesion.json`、`data/combat/encounters.json`、`data/combat/encounter_presentations.json`、`data/cards/qi.json`；入口 `godot/project.godot` → `noncombat_opening.tscn` → `noncombat_opening_ui.gd` → `noncombat_domain.gd`；状态仍是三槽 Godot v1 首局快照，无并行剧情真相；测试为 `godot/tests/noncombat_battle_boundary.gd`、既有序章八选、开局 UI 与完整门禁。另一边独占的战斗文件不在本批改动集。

五维声明：`offer_from_state` 由默认桌面场景 `noncombat_opening_ui.gd::_render` 在已提交 `COMBAT_HANDOFF` 消费，权威状态为 `noncombat_domain.gd` 写盘的当前遭遇 ID 与选择历史，原数据从四个来源 JSON 只读投影；四修八选及读档的 `noncombat_battle_boundary.gd` 和实场景 `noncombat_opening_ui.gd` 均退出 0，独立只读审查为 `VERIFIED`。`build_request/validate_result` 的入口目前只有专项合同测试的合成 `BATTLE_PENDING`，仍没有生产者或实战消费者，独审为 `UNPROVEN`，不能宣称“战斗已接通”。网页 `node tools/test_v02.js` 135/135、`python tools/validate_noncombat_asset_coverage.py` 518 图/32 音、`python tools/validate_godot_runtime.py` 通过；审美和真实战斗回传仍需后续独审。独审另记 P2：实际 `combat_domain.gd` 终局字段与协议的 `encounterInstanceId/terminal/combatPhase` 不同，战斗复用侧须显式映射并做真实回传测试。

## 2026-10-19 NC-05a-03 延迟战斗语义纠偏与剧情架构审计

本批先只读核对 `src/game.js:2072-2080,2187-2244,2334-2345,3802-4042`、`src/coordinators/CombatCoordinator.js:703-719,1208-1232`，并由三条独立只读审计分别核剧情、运行架构和内容媒体。发现 v1 网关/测试把来源迎战历史和 `decision:...:choice:...` 回执写在战前，而网页在迎战和确认预警时都只写检查点；战果时才提交来源选择、任务/因果/线程、`choiceHistory` 与 `decision:<lifeId>:combat:<owner>` 回执。Godot v1 槽位若按原样扩成生产态，会造成一次战斗两次决定、提前推进任务和重复奖励。

| Issue | 权威链与根因 | 修复前失败证据 | 本批修复与门禁 | 结论 |
| --- | --- | --- | --- | --- |
| NC-05a-03 | `noncombat_battle_gateway.gd` 以已增加的 `decisionIndex`、战前来源 `choiceHistory` 和普通 choice 回执构建请求，漏预警左右备战身份、牌组等装载数据；对应专项测试自己合成了错误状态 | 先改 `noncombat_battle_boundary.gd` 为“来源仍未提交、时钟未前进、检查点/备战回执/装载资料存在”的 v2 fixture，旧网关退出 1：`committed challenge did not make a stable source request`；独审再指出右备战不扣费、敌人意图只比五字段、四流派共用假牌组 | v2 网关用已提交 `baseDecisionIndex` 冻结 owner，以 `base+1` 作未来决定序号；来源 `choiceHistory`/回执不得提前出现。右备战回执须与灵石 -10/气血至多 +1 的待战状态全等，左备战零变化；四修牌组须与本局 deck 和原 `deck_progression.json` 的各自起始牌全等；作者敌人/意图、表现与收益按完整原始投影比对。专项测试先分别为未扣费、假牌组、伪造奖励额外失败，修复后 `offers=8 pending_contract=8` 退出 0；`python tools/validate_godot_runtime.py` 输出 `RUNTIME_MIGRATION_PASS data=74 art=587 audio=32`，`node tools/test_v02.js` 135/135，素材覆盖 518/3/32/587 | **纯接口契约已纠偏；生产态和真实战斗仍 UNPROVEN**。v1 旧合同不兼容，版本提升至 2。独审 P1 已在合成合同中加负例；准备费用的真实持久生产者、行动图重建和其他装载系统权威投影仍待 N2–N5 |

来源覆盖与缺口：当前 59 份非战斗 JSON 静态目录有 615 作者选择节点、1257 分支、531 处节点 `sceneImage`，其中 586 带 ID、29 是无 ID 嵌套变体；按所有 JSON 指针遍历则有 553 处 `sceneImage`。Godot 真入口仅 4 教程+4 四修序章、4 种只读教学邀约；6 任务/24 节点及 8 个状态变体、12 线程/40 节点及 29 个条件变体、8 同伴/38 事件、地图 13 点/12 路/11 纪事均缺通用生产者与消费者。34 条二级媒体映射和 3 动画 WebP/68 帧已入包但无剧情运行消费者。N1c 已把 13 张跨 `assets/combat/` 的非战斗 `sceneImage` 补入清单；228 张其他候选图未裁定。网页旧档 schema10/Quest3 仍未导入 Godot 三槽。上述静态数字都不是可达率。

剧情查缺补漏和代码责任已经写入 `NONCOMBAT_FULL_MIGRATION_TASKBOOK.md` §10：四修首轮、白狐、荒村和最后一课按生产者、门槛、选项、状态写入、战果分流、延迟兑现、媒体、续卡和 Godot 缺口逐线登记。四个来源 Node 组件测试本轮退出 0，但白狐等高回合样本有入口注入，未拿到清洁新档自然长局轨迹；最后一课非剑修身份与荒村早期选择回响列作**设计待审**，不能擅改源门槛或宣传剧情已闭环。

## 2026-10-19 N1a 来源内容仓库 Slice Charter

| Issue | 根因与限定目标 | 修复前证据 | 验收与排除 |
| --- | --- | --- | --- |
| N1a-01 | `runtime_data_registry.gd` 只按文件路径缓存 Dictionary，根数组 JSON 无法读，缺 `DataLoader` 模块 ID/别名、源 SHA 与 card/quest/thread/NPC 稳定 ID 索引；开局域仍直接硬编码文件路径。新增只读 `noncombat_content_repository.gd`，让开局消费者按来源模块 ID 读，索引带源文件/JSON 位置/SHA，并报告缺场景图 | 新 `noncombat_content_repository.gd` 测试应在文件不存在时失败；现有 `runtime_data_registry.gd` 无 `read_module`/通用 ID 查找；`q_sword_3` 等顶层场景图位于未同步 `assets/combat/` | 入口开局回归不变；`npcs:core` 别名、根数组卡、白狐任务、荒村/最后一课线程、NPC、二级媒体可查；返回值不可变更缓存；源副本 SHA 出错拒绝；报告 6 个已知缺图及来源卡，不把索引当作剧情可玩；不修改战斗场景。完成状态待本批验证 |

**N1a 验证与独审修正**：首次实现只索引约 455/586 个有 ID 的选择节点；独审指出地点、同伴事件、线程、势力、章节等 131 个缺口。随后对 74 份已复制 JSON 的每个 `{id, choices}` 对象递归建立原 JSON pointer，现索引恰好 586 个、无重复；专项测试覆盖 `loc_market_first`、`thread_heaven_net_1`、`blx_1` 等原漏项。真实开局原先在序章仍绕过校验仓库读取首轮路线和遭遇；现在 `noncombat_domain.gd` 从同一仓库读 `config:paths`、`cards:qi`、`config:realms`、`progression:first_session_cohesion`、`combat:encounters`。持久化测试故意篡改首轮路线 manifest SHA，序章选择被拒绝，运行状态与原存档字节不变。`card_scene_image_status` 分别给出 `listedInManifest/fileExists/shaVerified/textureLoadable`，不再以“清单中有记录”冒充图已可显示；故意改错图片 SHA 的负例会报未验证。此状态仅覆盖卡顶层 `sceneImage`，任务 `stateVariants`、线程 `variants` 和遭遇 `combatPresentation` 仍属 N1 后续；`data/protagonist.json` 是源目录顶层文件，不符合双段模块 ID，须以显式路径/别名处理。战斗网关和 UI 仍有旧 registry 读取，N1 整体不标完成。

独审复核补充：对独立静态目录的 `(id,sourcePath,jsonPointer)` 集合逐项比对为 586/586，缺项 0、多项 0；74 份已复制数据与 Web 原件的 SHA 漂移 0。仓库只从非 `data/combat/` 文档建立剧情选择索引，避免未来战斗规则加入同型对象污染剧情卡索引。专项仓库、持久化、开局 UI、四修序章与默认场景无界面启动均退出 0；仍不等于条件变体和剧情消费者完成。

**N1b 当前接线**：仓库以显式 `protagonist:core` 地址读取顶层 `data/protagonist.json`；`scene_image_references(sourcePath)` 遍历非战斗 JSON 的所有 `sceneImage` 字段，返回原 JSON pointer、图片路径以及清单/文件/SHA/Texture 四项状态，覆盖线程 `variants`、任务 `stateVariants` 和选择中的 `combatPresentation` 引用。专项测试核对 `q_sword_3` 战斗表现缺图及荒村败退变体原图。开局音频目录改为仓库读取，错误的 `path_identity.json` SHA 会拒绝播放；开局 UI 的流派名/题签读取也改为仓库模块。这里只建立**引用与来源状态**，尚未按任务/线程条件把变体卡投影到剧情界面；战斗网关仍有旧 registry 路径，N1 总门禁继续未过。

独立 QA 对 59 份非战斗 JSON 全扫：`sceneImage` 共 553 处，其中 20 处引用未列资源清单的 13 个不同文件。新增 Godot 专项门禁逐份累计同样的 553/20/13，并保留原文件与 JSON pointer。先前“6 张缺图”只指六张非战斗选择卡**顶层** `sceneImage`，不是所有变体和遭遇表现的缺图总数。`_originalSceneImage`、阶段立绘 `asset`、`portrait`、一般 `image`、二级媒体与音频依旧需要单独的引用/消费者检查；不能把当前 `sceneImage` 索引称为完整媒体迁移。

批量引用门禁首次对 553 张图逐张执行 Texture 加载，超过现有单脚本 15 秒限时；改为批量仅核对源指针与清单归属（约 2.8 秒），代表性的顶层、变体和战斗表现图仍逐张核对文件、SHA 与 Texture 加载。修正后 `python tools/validate_godot_runtime.py` 再次通过：`RUNTIME_MIGRATION_PASS data=74 art=587 audio=32 M0_steps=12 reactions=3 presentation=3 stage_routes=4`。这个优化不替代所有图片的导入检查；原有 `noncombat_asset_import.gd` 仍负责已入包资源的加载门禁。

## 2026-10-19 N2a 单一持久提交入口 Slice Charter

| Issue | 玩家契约与根因 | 修改前证据 | 本批边界和门禁 |
| --- | --- | --- | --- |
| N2a-01 | 旧 Godot v1 开局档必须保持可读且原文不被升级覆盖；任何已提交选择只能在写盘成功后被玩家看到。现有 `noncombat_domain.gd` 已有候选态提交，但 `noncombat_opening_store.gd` 只认 version 1、无修订号，两个打开同一槽的域实例可用旧状态覆盖较新的决定；直接修改 v1 快照又会触发严格重放失败，UI 可能误归档旧档 | 基线 `noncombat_persistence.gd`、`noncombat_save_slots.gd`、`noncombat_opening_ui.gd` 均退出 0；另加专项测试先证明并行旧实例的第二次提交能覆盖较新状态，且新 `RunSession` 接口尚不存在 | 新的 slot 专属 v2 独立文件，包含 `version/revision/sourceFingerprint/state`；v1 经现有域重放验证后才允许写 v2，v1 原字节保留。提交必须带期望 revision、检查同槽/同 lifeId/决定时钟不回退、原子写入，再换内存与发事件。旧 token、双实例竞态、写盘失败、坏档/未来版本、掉电 `.pending`、三槽隔离和 UI 重启均需负例；不声称网页 schema10 已导入，不修改战斗场景 |

本批仅把现有开局选择接到一个可并发拒绝的持久提交者，不迁通用剧情调度或战斗生产态。后续 N2 仍需完整 `RunSession` 的任务/线程/RNG/因果/战斗快照模型；本批通过不能宣称 N2 总门禁已过。

**N2a-01 已接入和验证（2026-10-19）**：默认开局和三槽位入口均调用 `noncombat_run_session.gd`；旧 Godot v1 只读恢复，下一次成功决定写独立 v2，旧文件原字节保留。v2 带槽位、修订号，以及开局实际依赖的五份规则 JSON 指纹；只改美术/音频清单不锁剧情档，改开局规则版本则锁档并保留原文。域按 `expected_revision` 提交候选状态，持久化成功后才更新内存和发布事件。损坏且有 v1 祖档的 v2、来源不符档及未来版本均保留原文件并锁住 UI，避免静默回退。`.pending` 写毕但重命名失败时不算提交；重载隔离未提交原文，保留稳定档，并允许原决定重试。即使 `.pending` 截断，旁边的稳定 v2、旧 v1 或空白新局也能继续；截断字节另存可回读。损坏的稳定档和 `.pending` 并存时先隔离 pending，再归档坏档，避免“界面可新开局但写盘必败”。新 `noncombat_run_session.gd` 专项先因入口不存在失败，修复后通过；开局 UI 的来源版本负例先失败、修复后通过；损坏 v2 与 v1 并存的回退负例先失败、修复后通过。独立 QA 追加了媒体清单变动、规则 SHA 变动、重命名失败重载、截断 pending 的三种恢复组合和坏档/未提交档并存负例，专项通过。`python tools/validate_godot_runtime.py` 是本批总门禁，包含新专项和既有三槽、开局 UI、首战门禁。本门禁只证明单进程内两个旧实例的修订冲突拒绝；**不承诺跨进程文件锁或网页版 schema 10 导入**，也未迁移任务/线程/RNG/因果的完整长局状态。`RULESET_VERSION` 在开局结算语义变化时必须显式递增；下一批应先把完整运行快照字段、决定调度与网页轨迹加入同一提交入口，再接剧情消费者。

## 玩家契约与范围

目标是把网页版**实际运行**的非战斗内容与规则接入 Godot，而非只复制 JSON 或另写相似剧情。当前可见路径为：选玉简 → 玉册题名 → 选择四种功法之一 → 来源 `tutorial_1` → 原左右选择及效果 → 来源教程续卡 → 来源流派序章左右选择与因果结算 → 来源教学遭遇邀约（来源题名、敌人、机制与迎战/避开文案）；显示原序章场景图。每次输入只结算一次、成功写盘后才更新画面，重开 Godot 回到同一未决卡或遭遇邀约。教学遭遇卡真正的迎战/避开选择、预警确认、战斗及其后续仍是明确边界；不能用固定首战样本伪装完整流程。

完整迁移账本按依赖顺序继续：

| ID | 系统与权威源 | 本批状态 | 必要验收 |
| --- | --- | --- | --- |
| NC-01 | 开局/教程/流派序章：`src/ui.js`, `src/game.js`, `GameStateManager.js`, `KarmaSystem.js`, `data/cards/qi.json`, `data/progression/first_session_cohesion.json` | 来源玉册题名、四路径首次开局、教程、序章左右选择与教学遭遇交接 ID 已运行；战斗预警未接 | 名字、四路径开局、序章八选、数值/因果、一次选择、原卡续接与重载 |
| NC-02 | 原图/音频映射：`sceneImage`, `assets/`, `data/audio/path_identity.json` | 74 JSON、603 张已入包图片、2 个 JPEG 别名、3 个动画 WebP 原文件与 68 个导出帧、32 个来源音频；531 张按非战斗引用选入，四修邀约显示来源场景图；开局 5 类声景、四流派序章誓言与选择音接入 | 源字节 SHA、逐帧像素与时长、Godot 加载；其余剧情消费者、音乐重制与人工试听另验 |
| NC-03 | 因果存档与三槽：`GameStateManager` schema 10 / causal 18 | Godot 首局专用三槽与带修订号 v2 提交已实现；旧 Godot v1 原文保留；网页版旧档导入、重命名/删除仍未实施 | 三槽隔离、旧档 JSON 导入、断点恢复、失败回退；不能用简化存档声称兼容 |
| NC-04 | `EffectService` + `FlowDirector` + 剧情/任务/因果/同伴/商店/地图 | 待实施 | 每个可达卡 ID、生产者、状态写入、下一决策、刷新恢复与网页轨迹对照 |
| NC-05 | 战斗边界与战果回传 | N5a 四修邀约与纯接口槽位已接；真实预警/运行/战果持久结算待实施，不改另一边战斗场景 | 剧情预警确认后传完整上下文，胜败/逃后只提交一次奖励并回到来源续卡 |

## 已证实的入口与差距

- 网页 `index.html` 按序加载 `DataLoader`、`GameStateManager`、各系统、`GameLogic`、`GameUI`；`src/ui.js::startGame` 调 `src/game.js::start`。后者设置路径加成、教程或序章。`makeChoice` 经事务、`EffectService`、`FlowDirector` 结算与续卡。
- 开工前 Godot `project.godot` → `scenes/main.tscn` → `scripts/main.gd::_ready` 固定调用 `combat.load_m0_opening()`。现在默认入口加载 `scenes/noncombat_opening.tscn`，其 `Control` 消费原 `qi.json`、`paths.json`、`realms.json` 与首批场景图；原战斗场景保留。
- N1b 时 `tools/sync_runtime_content.py` 从原有 74 份 JSON 和 74 张首战图扩展到非战斗 JSON、网页入口 HTML、已加载 CSS/JS、`NarrativeCardExhibit` 二级媒体清单和 `LitPixelRenderer` 的角色底色/法线/材质路径；当时独立校验得 518 个非战斗图片引用路径、资源清单 587 张可直接导入的原图。N1c 后最新数量见本文件顶部与 NC-02 表。两份 PNG 名称下的 JPEG 字节别名、三份原动画 WebP 字节归档与其 68 张解码 PNG 帧仍按来源处理；Godot 的 `SpriteFrames` 依来源 WebP 的 ANMF 帧时长组序列。轨迹采集时核对了页面加载的脚本、HTML 与关键数据共 67 份本地/HTTP 响应 SHA；序章另有四路径八选的实时浏览器状态轨迹与源码 SHA。资源可加载不表示剧情/UI/声音消费者已迁移。
- Godot 首局专用存档一号位于原 `user://noncombat_opening_v1.json`，二、三号各有独立文件；来源的三槽 ID 与默认玉简名称用于 Godot 入口，各槽 `runClock.lifeId` 与回执含实际槽 ID。网页版 `index.html`/`src/ui.js::_confirmName` 的玉册题名先于功法选择；Godot 现在同顺序，保留四字输入上限、空名默认 `叶凌云`，名字随首局快照及选择保存。旧 Godot v1 无名字字段的开局可恢复，并在下一次选择时补默认名。切换选中槽后才载入，选择时写盘并以待提交文件同目录替换；重载时从来源 JSON 重演 `choiceHistory` 并核验完整快照。损坏或过期快照在 UI 中归档原文并显示提示，归档失败则禁用该槽新开局；损坏活动槽索引也在选择新槽时归档原文后重建。它们是局部 Godot 新档，**不是**网页版 `saveVersion=10` / causal 18 的三槽兼容导入；源端重命名、删除和旧 Quest sidecar 处理也未实施。
- 基线：`tests/replay_full_battle.gd` 通过 M0 步骤 5–16；网页 `node tools/test_v02.js` 135/135。开工前 `presentation_integration.gd` 曾在 15 秒门禁超时；当前完整 `python tools/validate_godot_runtime.py` 已通过，仍需留意该测试的运行时间波动。

## NC-01 八维调查

| 维度 | 证据 |
| --- | --- |
| 真实入口 | 网页 `index.html` → `src/ui.js::startGame/makeChoice`；Godot `project.godot` → `scenes/noncombat_opening.tscn` |
| 生产者 | 网页 `GameLogic.start`、`GameLogic.makeChoice`、`EffectService`、`FlowDirector` |
| 消费者 | 网页 `GameUI.renderGame`；目标 Godot 原生 `Control` |
| 初始化 | 网页 `GameStateManager.reset`，初始气血、道心、修为、福缘、灵石、寿元；`GameLogic.start` 加功法加成 |
| 状态存储 | 网页 `GameStateManager` 与 causal checkpoint；Godot 首次教程局部状态、`runClock` 回执、`choiceHistory`、`recentCardTags`、未决卡检查点持久化；跨系统因果与旧档未迁 |
| 最小复现 | 新局剑修：`tutorial_1` 右选 → `tutorial_4` 左选 → `q_start_sword`；另一条左选 → `tutorial_2` |
| 当前测试 | 网页 `tools/test_narrative_prologues.js`、实时 `tools/capture_noncombat_opening_source.js`；Godot 四项 `noncombat_*` 测试 |
| 根因状态 | 开工前缺少非战斗状态机与入口；首批已补。审查指出选择历史和持久回执缺口，现已补并通过实时轨迹对照；后续 Flow/存档体系仍未实现 |

## 门禁与证据

1. 来源数据与原图的哈希验证；不得手改 Godot 内容副本。
2. 新增 Godot 专项测试在实现前失败、实现后通过，覆盖首次选择、重复输入、非法方向与路线分支。
3. Godot 原生界面从独立剧情入口实际启动，点击选择后看到来源卡片及真实状态变化；日志无脚本错误与缺图。
4. 现有首战重放仍通过；不把该测试算作非战斗迁移的证明。
5. 独立只读审查从用户要求、真实入口、数据源、状态和测试尝试推翻完成声明。未过者标 `UNPROVEN`。

## Claim-to-Evidence

| 声明 | 实现 | 入口 | 权威状态 | 测试 | 独审 |
| --- | --- | --- | --- | --- | --- |
| NC-01 玉册题名、四流派首局教程、序章至教学遭遇交接 | `scripts/noncombat_domain.gd`, `scripts/noncombat_opening_ui.gd` | `project.godot` → `scenes/noncombat_opening.tscn` | 来源 JSON + Godot 首局专用状态，确认名字后选流派时首次写盘；选择成功写盘后发信号；来源遭遇 ID 为止 | `tests/noncombat_identity.gd`, `tests/noncombat_opening_parity.gd`, `tests/noncombat_browser_trace_parity.gd`, `tests/noncombat_prologue_parity.gd`, `tests/noncombat_opening_ui.gd`；浏览器八选实时轨迹；`name-creation.png`, `path-selection.png`, `sword-prologue-source.png` 与 `teaching-encounter-handoff.png` 桌面截图 | 序章独审复核通过，范围截止 `COMBAT_HANDOFF`；题名只读独审与浏览器实测通过：确认题名后、选流派前刷新会回默认，选流派后刷新保留名字；本批完整门禁通过 |
| NC-02 来源媒体包与开局实际画面 | `tools/sync_runtime_content.py`, `content/source_manifest.json` | `scripts/runtime_data_registry.gd::texture_for/sprite_frames_for`；开局与四修教学邀约实际取图 | 不改变规则状态；两份 JPEG 字节别名与三份动画 WebP 原字节归档、等值解码帧 | 74 JSON + 603 图片 + 2 别名 + 3 动画/68 帧 + 32 音频 SHA；`tools/validate_noncombat_asset_coverage.py` 验证 531 张非战斗引用图；跨目录 13 张逐张加载 Texture | 音频人工听感未审；其余剧情图片运行消费待接 |
| NC-02 开局来源声音事件 | `scripts/noncombat_opening_audio.gd`, `scripts/noncombat_opening_ui.gd` | Godot 桌面选择功法进入教程时响山风；进入对应 `q_start_*` 时切地点声并播对应 oath；恢复只恢复环境；成功选卡响 snap，序章入口让位给台词 | `data/audio/path_identity.json` 的卡 ID/场景/声音路径，四句原文字幕；Godot 首局存档只决定当前位置，音频不写进存档 | 修复前 `noncombat_opening_ui.gd` 回归测试在“教程不应提前说誓言”失败；修复后 `tests/noncombat_opening_audio.gd` 验 5 类声景、4 oath、循环与压低/恢复，`tests/noncombat_opening_ui.gd` 验实点、序章字幕和读档不重播；完整 `tools/validate_godot_runtime.py` 通过 | 代码/导入门禁通过；人耳审美验收仍 UNPROVEN，网页静音/其余系统事件未迁 |
| NC-03 首局局部重载 | `scripts/noncombat_opening_store.gd`, `scripts/noncombat_domain.gd::restore` | Godot 默认场景启动恢复 | `user://noncombat_opening_v1.json`，完整重演匹配后恢复；不可恢复文件原文归档；旧浏览器三槽不适用 | `tests/noncombat_persistence.gd`, `tests/noncombat_opening_ui.gd` 覆盖成功、失败写盘、损坏与重载 | Batch B 独审确认局部重载通过；浏览器旧档兼容仍 `UNPROVEN` |
| NC-03 Godot 原生三槽入口 | `scripts/noncombat_save_slots.gd`, `scripts/noncombat_opening_ui.gd` | 桌面默认场景 `SlotSelection`，各槽各自 Godot v1 文件 | 一号沿用旧 Godot 文件；二/三号独立；槽 ID 进入 `runClock.lifeId`/回执；`noncombat_active_slot_v1.json` 仅记录当前选择 | `tests/noncombat_save_slots.gd` 隔离/重开/跨槽回执/损坏文件与索引、`tests/noncombat_save_slot_ui.gd` 实际点击切换与损坏数据归档；`save-slots.png` 桌面截图 | 独审复核通过；网页 schema 10 导入、源端重命名/删除仍 `UNPROVEN` |

## 已观察到的限制

- 四流派序章效果与本次因果种子已按浏览器轨迹结算。教学遭遇邀约已有来源身份和场景图消费者；后续 `FlowDirector` 抽卡、迎战/避开、战斗预警、战斗执行与回传还没有可玩的 Godot 消费者。
- 网页开局还调用起始牌组授予、剧情线程、市场节律等系统。当前首局轨迹的可比字段通过，但**不等于**全量 `GameStateManager` 快照或完整游戏迁移。
- 网页 schema 10 旧档、任务侧存档、转世和战斗中的恢复均未导入。Godot 原生三槽目前只隔离首次开局专用状态；战斗场景保留，不在本批接线。
- 531 张按非战斗来源引用选入的图片与 32 个音频路径进入资源包（其中 28 个旧素材、4 个新环境源；该目录也含战斗音效）；Godot 能加载图片、三组 `SpriteFrames` 与音频。开局现消费 1 首临时 BGM、4 段环境原文件组成 5 类声景、4 句路线誓言和 1 个选择音效；网页动态压缩器、其他音频事件、程序化市场音效仍未移。多数图片尚无 Godot UI、地图、剧情消费者，复制与导入不等于可玩迁移。`RuiCCardRenderer` 动态加载的 `assets/card-material-textures/*.js` 是原图的网页专用封装，其镭射材质和水面实时效果尚未在 Godot 接入。
- 声音触发时点有明确差异：网页版 `card:chosen` 立即播放 snap，Godot 在选择成功写盘后播放，避免失败提交出声。网页音频全局静音、压缩器、SFX 并发/节流和独立 bus 尚未迁移；Godot 当前单播放器连续 snap 可能截断前一个音效，不能声称完整音频系统等价。
- 原生选择界面已实际使用网页版 `bg_inkwash_masterpiece.png`、Logo、四枚原 `*_ink.png` 图标和对应题签；截图为 `name-creation.png`、`path-selection.png`。布局是 Godot 桌面重建，尚未逐像素复刻网页版 CSS；动态 `Path3DArtifactSystem`、悬浮细节和其余非战斗页面仍未移。剧情屏继续使用 `bg_start.png` 与来源场景图，尚未视觉照搬网页版布局。
- N1b 历史基线曾有 `RUNTIME_MIGRATION_PASS data=74 art=587 audio=32`、`NONCOMBAT_ASSET_COVERAGE_PASS images=518 animated=3 audio=32 copied=587`。N1c 最新媒体门禁是 `NONCOMBAT_ASSET_COVERAGE_PASS images=531 animated=3 audio=32 copied=603`；当前项目总门禁失败于并行战斗接触点测试，见本文件顶部 N1c 记录。

## 非战斗源码迁移顺序（源码审计）

网页版 `index.html` 实际按序加载 63 个脚本（含渲染库与战斗模块），不是一组独立卡牌 JSON。Godot 桌面运行时不能把 DOM、`localStorage` 和 JS 全局对象直接当作 GDScript 执行。迁移必须逐批替换实际消费者；每批用可重放的浏览器轨迹校验输入、状态、副作用、下一决策与重载。

| 顺序 | 网页权威代码 | Godot 所需消费者及验收 | 当前证据 |
| --- | --- | --- | --- |
| 1 状态与存档 | `GameStateManager.js`（save schema 10、causal schema 18、三槽）、`DataLoader.js`、`EventBus.js` | 三槽文件、旧网页存档导入、同世/跨世状态重建、事务回滚；先验证未决卡与因果再显示 | 当前仅首局专用 v1 重演存档；网页旧档不兼容 |
| 2 通用选择规则 | `GameLogic.makeChoice`、`EffectService.js`、`FlowDirector.js`、`CardSystem.js`、`KarmaSystem.js`、`ChoiceOutcomeRouter.js` | 按类型实施选择/效果/因果/延迟承诺/抽卡/检查点，逐卡验证四条流派路径；不能在非战斗卡用固定续卡代替 Flow | 教程和序章专用规则已移；通用规则未移 |
| 3 世界与剧情 | `StoryThreadEngine.js`、`NarrativeDirector.js`、`RealmChapterSystem.js`、`QuestSystem.js`、`NpcSystem.js`、`CompanionSystem.js`、`FactionSystem.js`、`EncounterDirector.js`、`WorldContinuityStore.js` 等 | 每个可达事件的卡生产者、状态写入者、续卡优先级、跨周目恢复与界面消费者都需落地 | 74 份来源 JSON 已入包；运行消费者未移 |
| 4 非战斗交互 | `ShopSystem.js`、`MarketSystem.js`、`WorldMapSystem.js`、`SceneLayerSystem.js`、`EquipmentSystem.js`、`TreasureSystem.js`、`PathSkillSystem.js` 等 | Godot 原生商店/坊市/地图/装备/卡牌展示，原库存、价格、事件账本和状态守卫；源 UI 流程逐步核对 | 原图与音频包可读；原交互未移 |
| 5 表现 | `src/ui.js`、`NarrativeCardExhibit.js`、`RuiCCardRenderer.js`、`LitPixelRenderer.js`、`AudioManager.js`、`VisualStoryDirector.js` | 先复现来源卡内容和交互，再接原图、动画帧、音频事件、材质/水面效果；桌面尺度截图与网页对照 | 只有开局场景使用来源图；媒体包加载通过，不等于表现完成 |

战斗 `DeckCombatSystem.js`、`DeckCombatUI.js`、`CombatCoordinator.js` 在本轮排除，但非战斗到战斗的交接必须保留完整来源上下文；目前交接只保留来源遭遇卡 ID，不能产生战斗结果。后续应先迁通用非战斗结算与卡牌调度及其状态所有者，再用真实浏览器导出档核对 schema 10/causal 18 导入；否则虽能读入 JSON，也无法安全恢复未决卡和世界状态。教学战斗后的剧情续接还依赖战斗边界的独立实施。

## 2026-10-19 剧情路线、策划架构与美术素材逐项盘点

本节把「复制到 Godot」与「Godot 已能在真实流程中消费」分开。机器可读的来源索引由 `tools/audit_noncombat_migration.py` 从当前 `data/` 和 `godot/content/source_manifest.json` 生成至 `artifacts/godot-migration/noncombat-content-catalog.json`；每条内容记录源 JSON、SHA-256、JSON 路径、ID、选择的实际效果/控制字段、场景图、任务/线程触发及变体图。它是**静态作者内容目录**，不声称全部节点可从开局触达，也不声称视觉质量验收通过。

### 数量和现状

| 来源范围 | 当前目录中实际内容 | Godot 状态 |
| --- | --- | --- |
| `data/` 非 `data/combat/` | 59 份 JSON；扫描到 615 个带选择的内容节点、1257 个选择分支、531 处节点 `sceneImage`；其中 586 个节点有不同的字符串 ID，另有 29 个无顶层 ID 的嵌套变体 | 59 份 JSON 已按原字节入包；默认流程实际呈现的来源节点仅 `tutorial_1..4` 和 `q_start_{sword,spell,body,pill}` 共 8 个；其余没有通用剧情消费者 |
| 主线/普通/因果/境界卡 | `data/cards/` 的选择节点 480 个，分布在炼气至飞升后、死亡/转世、章节点、因果、世界氛围等数据；`battle_cards.json` 虽在同目录但不算非战斗选择节点 | 只有教程和四流派序章专用状态机；权重抽卡、境界/死亡/转世、普通事件和因果兑现未迁 |
| 支线 | 6 个任务包，共 23 张任务卡，另有 1 个可选择的嵌套状态变体；入口条件、`questNext`、`questEnd`、`questOutcome`、胜败回传与完成奖励分别存在 | 来源 JSON/对应原图已入包；`QuestSystem` 的触发、步骤、失败封闭、奖励和状态变体未迁 |
| 故事线 | 7 个文件中的 12 条线程、40 个作者化节点；可按先前选择、商店购买/交涉、战斗结果投影变体 | 线程触发、延迟、冷却、完成回执、跨境界回响及变体投影未迁 |
| 角色/同伴 | `data/companions/events.json` 的 8 名同伴、38 个事件；另有 NPC/关系/势力/角色资料和立绘映射 | 文件已入包；关系阈值、NPC 生命周期、同伴事件与正确立绘消费者未迁 |
| 世界与因果 | 地图 13 个节点、12 条路线、11 条纪事；8 个角色、6 个任务、5 个线程绑定；因果图 33 个事实类型 | 仅文件已入包；世界观测/追踪、运行时绑定、事实生产/延迟消费未迁。地图原设计明确不作瞬移入口 |
| 媒体 | 现有非战斗图片文件 746 张；原有 518 张按已知运行引用选入，另补 13 张位于 `assets/combat/` 的非战斗 `sceneImage`，合计 531 张。原目录仍有 228 张未裁定候选图 | 资源文件在 `godot/content/`；当前剧情界面消费开局 8 个节点及四修遭遇邀约的来源图，其它图/立绘、动态卡面材质、场景层及多数声音没有剧情事件消费者。228 张须逐张辨别候选/废稿/动态引用，不擅自挂到剧情 |
| 战斗依赖 | 非战斗 JSON 中有跨 `assets/combat/` 的图片引用；其中 13 张由非战斗 `sceneImage` 消费责任驱动，现已按原字节入包 | 其余战斗专属帧和场景依实际遭遇的表现清单补齐；目录名本身不决定剧情图片的责任归属 |

原始 `docs/gdd/GDD.md` 规定「选择承担代价、因果延迟兑现、四修不同视角、死亡/转世继续推进」四个策划支柱，但其早期“战斗系统不存在”等实现状态已经过时。实施状态以 `index.html` 的当前脚本图、`architecture_overview.md` 的权威链和实跑轨迹为准，GDD 用于检验体验意图，不代替运行证据。

### 不能简化成静态连线的三条典型路线

| 路线 | 触发 → 选择/写入 → 变体/素材 | Godot 缺口与验收轨迹 |
| --- | --- | --- |
| 首轮四修 | `first_session_cohesion.json` 将每个 `q_start_*` 绑定对应教学遭遇，再以 `routeLensRef` 指向 `q_mountain_shadow_approach` 的四种视角；右选可续接 `loc_market_first`，并允许受更高优先级事件打断后恢复 | 目前停在 `COMBAT_HANDOFF`。须先有来源预警、完整战斗上下文和胜败回执，再显示四修各自的路途文案/场景图、坊市卡；四条路径逐选对照浏览器轨迹 |
| 白狐报恩 | `white_fox_line` 的入口限定炼气、最早第 5 轮及未完成/未访问条件；`q_whiteFox_quest` 左选失败并写白狐死亡，右选救助续 `q_whiteFox_2`；第三张 `q_whiteFox_3` 可战斗、付费或离开，战果决定任务终局；完成时兑现奖励和延后因果种子 | 三张卡分别有独立原 `sceneImage`。需复刻任务触发、`questNext`、失败不发完成奖励、战果只结算一次、旧档恢复。测试救助/拒绝/战胜/败退/离开并核对剧情图、NPC 状态及奖励 |
| 荒村妖道/最后一课 | `abandoned_village` 由 `q_beggar` 右选在延迟 3 个决策后触发，4 个节点；终局 `combatOutcomes` 为 defeat/flee 时改用不同原场景图。`bairen_last_lesson` 的后续节点还按旧选择、购买结果和战果复合投影 | 需线程队列、完整 `threadDirection`/战斗/商店回执、条件投影、跨节点叙述与重载；同一个卡 ID 下要验证状态变体的文案和图，不可只按 ID 固定配图 |

**权威续卡链**：输入卡 ID/方向及令牌 → 校验成本/条件 → `EffectService` 与因果、NPC、同伴、任务、线程等各写入者结算一次 → 保留 `questNext`/`nextCard` 与战斗/商店合同 → `FlowDirector` 依死亡/中断、战斗预警、作者化续篇、破境与遭遇、任务、因果、叙事队列、市场/营地、普通卡优先级挑下一卡 → 按任务 `stateVariants`、线程 `variants` 和当前世界状态生成最终展示卡 → `sceneImage`/立绘/音频消费者显示 → 原子保存决定及恢复点。不能先从静态 `nextCard` 跳转再补效果；那会跳过任务失败、延迟因果和战果条件。

### 可执行迁移批次与完成判据

| 批次 | 实施内容 | 本批完成证据 |
| --- | --- | --- |
| A 来源内容契约与媒体索引 | 保持 `data/` 为唯一内容权威；把当前静态目录当作逐节点资产/分支清单，检查 228 张未选图片的网页引用、来源、用途和视觉归属，分类为使用/备用/废稿；对线程和任务变体保留不同图片路径 | 目录可从源码重生；59 份 JSON 哈希、所有已知非战斗图片引用、直接/变体图路径校验；任何新增资源都记录原路径和剧情消费者 |
| B 通用状态/结算/调度 | 把 Godot 开局专用状态扩成能承载浏览器当前档的权威状态；实现效果、成本、因果时钟、一次性回执、保留续卡与 `FlowDirector` 优先级；在真实未决卡上按一次输入只结算一次 | 固定种子浏览器↔Godot 对照卡 ID、方向、数值、旗标、队列、下张卡、刷新恢复；优先覆盖首轮四修与普通/因果交替；旧 schema 10、causal 18、quest 3 导入单独证明，不能把 Godot v1 三槽称为旧档兼容 |
| C 任务、故事、角色世界 | 依次接 6 任务、12 线程、NPC 生命周期/同伴阈值、33 类因果事实、地图纪事/势力/商店；每类保留原触发、延迟、互斥、步骤及终局回执 | 用白狐、荒村和最后一课三种含不同分支机制的路线做浏览器↔Godot全程对照；地图只观测/追踪且读取同一权威剧情状态 |
| D 战斗边界与剧情返回 | 不改本轮战斗规则；新增预警和带来源卡、选择、任务/线程上下文、奖惩分支的交接；战果经唯一回执写回非战斗状态，再由来源调度器续卡 | 四流派教学战各胜败/逃可恢复，白狐和线程战斗不重复领奖、不丢变体，交接期间重开可回到同一未结合同 |
| E 表现对齐 | 各剧情节点从来源 `sceneImage`、`artDirection`、NPC 立绘和媒体事件渲染；原网页其他非战斗页面/材质行为按真实入口逐页重建，桌面优先 | 每条验收轨迹同时检查卡文、背景图/角色图、音频事件与截图；缺图/错图为失败，不能用已有文件数代替呈现证据 |

本节是迁移路线清单，**A 的静态盘点已执行，B–E 尚未完成**。A 中 228 张候选图的逐张用途裁定仍待做；任何路线只有在 Godot 原生入口可玩、状态可恢复、来源浏览器轨迹可对照时才能标记“已迁移”。

这段静态盘点最初只新增目录工具与规划文档；其后已实现 Godot 首局和 NC-05a 接口，应以上方后续记录为准。盘点复核：`python tools/audit_noncombat_migration.py` → `documents=59 choice_nodes=615 branches=1257 scene_images=531 opening_rendered=8 missing_copied_images=0`；目录自身再验源 JSON SHA、分支总数及 6 任务/12 线程/8 同伴等组别通过。N1c 媒体覆盖 → `images=531 animated=3 audio=32 copied=603`；早期 `node tools/validate_content.js` → 74 JSON、586 张可引用卡、78 类 Effect、21 敌人模板、37 加载模块且内容闭环校验通过；早期 `node tools/test_v02.js` → 135/135。上述检查只证实来源与目录可用，**不证明 N1–N11 的 Godot 行为已完成**。
# 2026-10-21 N9u 官坊遭遇与独立会话 Slice Charter（执行中）

| Issue | 玩家合同 | 来源链与验收 |
| --- | --- | --- |
| N9u-01 | P25 或 P10 命中时发出原 `shop_encounter`；不入楼的选择仍结算一次，入楼显示本次冻结的真实报价。 | `FlowDirector → CardSystem._checkShopEncounter/_buildShopCard → ShopSystem.getAvailableItems`；先红测命中仍 fail-closed，再验证两次选货调用及冷却、随机回执、原卡文、待选/跳过严格恢复。 |
| N9u-02 | 官坊使用 `regulated_market` 独立会话：至少突破丹可真实购买、离摊出结算卡；其余未接商品明确不可购买。 | `GameLogic.ENTER_VENDOR → MarketSystem.createVendorSession → ShopSystem.purchase/close`；不得借用公开集市的摊主、人情、两次交谈、背景。验证货单不可重抽、购买状态/存档恢复、重复购买与不足额拒绝、写盘失败回滚、来源指纹及伪造回执拒绝。 |

**边界**：本批仅炼气境界且只开放已验证的商品结算；鉴宝、法宝、功法、礼物和回购服务仍属后续消费者，必须在 UI 列出但禁止操作，不能虚称官坊全功能迁移。若来源定价或牌组条件不能完整复现，该入口继续 fail-closed，不展示假报价。并行战斗目录不改。上一批完整门禁所有非战斗专项通过，随后在并行战斗 `presentation_integration.gd` 胸口接触标记距离约 0.838 处失败；总门禁尚未通过。

### N9u 本轮完成证据与独立审计（2026-10-21）

- 来源运行器 `node tools/export_regulated_shop_fixture.js` 直接调用网页 `ShopSystem.getAvailableItems`，保存两次官坊遭遇各自的预取及正式货单，四次调用各耗六个随机数。`noncombat_regulated_catalog.gd` 对照其有序 ID/价格与初始商路倍率 0.852；官坊卡文字、选择和来源 JSON/SHA 仍由内容仓提供。
- 红测先证实 P25 原卡未发出、独立会话未接、正规购买及严格重放缺失；新增 `noncombat_regulated_vendor.gd` 验真实命中、两类丹药中已开放的一类购买、库存冻结、重复及未接商品拒绝、官坊关闭一回合、被动回血、因果种子推进、48 条访问记忆上限、旧购买归档后再入集市。`noncombat_regulated_replay.gd` 从新局经公开集市买药自然走到官坊，验待选/入楼/购买/结果四次严格读档、原图与报价 UI、失败写盘原态/原字节、报价伪造拒绝。两项及 `noncombat_regulated_catalog.gd` 最新专项均退出码 0。
- 只读审计找到并已修复：官坊关店漏被动恢复/因果时钟，48 条后官坊购买使集市校验失败，公开集市购买被误判为商路事件，跨官坊丹药价格内存状态丢失，访问上限导致结果卡 ID 重复。后者以会话键组成 Godot 稳定结果身份，是为严格存档作出的有意选择；网页版会话 ID 是易失计数，并不宣称字面同值。
- 浏览器 `ShopSystem.items` 的丹药价格在同一进程内连续变价，但网页刷新会按 JSON 重建其未持久化内存；Godot 把价格轨迹写进 `normalFlow.shopPillPrices`，以便继续游玩与严格恢复保持同一规则。此处是源端行为的可恢复化处理，不能称刷新时与网页版逐字段相同。
- `python tools/validate_godot_runtime.py` 的本轮完整门禁运行至并行战斗 `presentation_integration.gd` 失败：接触标记距木人胸口 `0.83749383687973`，该战斗表现问题不在本批改动。官坊之外仍缺流转号动态服务、回购、法宝/功法/礼物/鉴宝结算，变动势力/暗流的商路消费者及其它境界；这些路线不得被标成已迁移。

## N9v 官坊随身物品与回购 Slice Charter（已完成，非战斗专项）

| Issue | 可玩合同 | 来源证据与验收 |
| --- | --- | --- |
| N9v-01 | 来源货单里的炼气礼物可付灵石入 `itemInventory`，同次会话已购货消失；买不起、重复买及写盘失败不扣款。 | `ShopSystem.purchase/_applyItemEffect` 的 `gift` 分支及 `shop_items.json`，只接受来源 `giftItemId` 和正数量；严格读档须重演购买史和完整库存。来源 `material` 目前在 `_applyItemEffect` 回 `unknown`，本批不把材料销售伪装成成功。 |
| N9v-02 | 官坊回购台只对持有的来源礼物/材料显示操作，每种物品一次，每次扣 1 份、返 2 灵石，重复与不存在物品拒绝；离店摘要记录换物。 | `vendor_profiles.json` 的 `regulated_buyback`、`ShopSystem.getVendorActions/executeVendorAction` 与 `GameStateManager.consumeItem`；保留独立 action 回执、严格重演和旧集市来往验证，不混入摊主交谈预算。 |

**实施边界**：动态流转号服务需要因果事实消费端另批处理；不以可见按钮代替事实生命周期或剧情兑现。网页目前对“只回购、不购买”的会话仍按 `purchaseCount=0` 写 `declined` 并显示“最终没有出手”；Godot 本批保留这项源行为，审计后再决定是否同时修网页、Godot 与依赖 visit outcome 的剧情消费者，不把它描述成已完善的产品文案。

**本轮证据**：新增 `noncombat_regulated_goods.gd` 先在礼物商品不可买处红测退出码 1，再通过炼气灵茶来源报价、入库存、重复拒绝、回购扣件/返 2 灵石、先回购后购买的逆序事件、同次回执与访问记忆裁剪后的集市准入。`noncombat_regulated_replay.gd` 走自然集市买药→官坊礼物→回购→疗伤丹，检查每笔交易后的严格存档重放、写盘失败回滚、伪造回购动作/报价拒绝，以及桌面回购按钮明示 +2 灵石；另把旧 N9u 购买档剥除新事件字段，证实仍可严格读档，并在下一笔新交易后升级有序日志再严格读档。两个专项退出码均为 0。`mcp__yinian_godot.godot_validate_script` 确认官坊、领域和集市三个脚本可解析；旧 `noncombat_bazaar_vendor.gd`、`noncombat_normal_runtime.gd` 回归通过。独立只读审计指出回购返款原 UI 未明示，已修，并指出上述网页本身的单独回购结果文案缺口。完整项目门禁仍受并行战斗接触点测试失败约束。

## N9w 原著 `q_market` 官坊入口与流转号兑现合同（执行中）

源端除 P25 动态 `shop_encounter` 外，`data/cards/qi.json` 还把 `q_market` 放在炼气普通池，权重 8、原图 `scene_qi_q_market.png`，左选入 `regulated_market`，右选记商队旗号，下选离开。现行 Godot 的普通选择策略把 `action` 和 `narrativeBlock` 视为未接消费者，若抽到 `q_market` 会以“选中未迁移选择消费者”停止；因此只实现 P25 官坊不能证明此路线已迁。须保持两张卡不同的抽样次数、原卡文、方向和回放回执。

流转号的权威链为 `ask_luo` 生成 `fact:0:rumor_rusted_sword_origin` → 按 `causal_graph.json` 在事实决断 +1 至 +4 的官坊会话显示订货服务，逾期给关闭文案 → 收 12 灵石并消费事实，登记 `licensed_rusted_sword` 订单 → 三次**核心决断**后插入交付卡 → 同一原子提交中产生一件有来历的法宝、`sword_origin_licensed` 事实与装备/纳戒选择 → 战斗网关读取实际装备实例。现有 Godot 只有事实生产者、法宝实例账本与战斗请求的装备投影；尚无订单、延期交付卡和回执全链。不能在这条链完成前开放会扣钱的订货按钮。

| 检查点 | 验收口径 |
| --- | --- |
| N9w-01 普通池入口 | 真正抽到 `q_market` 时三向均可按原义完成；左向冻结一次官坊货单并可离店，右/下正常推进。结果卡、来源原图、48 条访问上限和新旧存档回放通过。 |
| N9w-02 事实窗口 | `ask_luo` 同世唯一事实在官坊的决断窗口内显示可用服务，窗口外只显示来源终结文案。页面和存档不可伪造事实、价格、服务或窗口。 |
| N9w-03 订货及延期 | 同一次提交扣 12 石、消费事实、登记有唯一 ID 的订单；重复、余额不足或写盘失败不漏扣。三次核心决断后仅排一次交付，其他插卡不提前推进。 |
| N9w-04 交付及战斗边界 | 交付选择、法宝实例、来源事实、装备/纳戒选择一起可重放；失败提交回滚且交付卡可重试。战斗请求使用该实例和装备效果，回传只结算一次。 |

来源验收参照：`src/systems/NarrativeLedger.js`、`MarketSystem.js`、`ShopSystem.js`、`src/game.js` 及 `tools/browser/b5_licensed_rusted_sword_player_journey.js`。网页证据脚本为 UI 操作示例，但直接暂存原卡与余额；迁移验收还须补自然可达的 Godot 抽卡链，不把该脚本当作自然到达证明。

**N9w-01 已验证**：`noncombat_q_market.gd` 先因原卡与三向选择不可到达红测退出码 1，接线后验明它在原炼气普通池、原 `scene_qi_q_market.png` 校验并可加载。左向只抽一次正式官坊货单、可购买与出楼；右向按网页 `ChoiceOutcomeRouter` 的 `narrativeBlock` 生成即时「坊市三门·回应」卡并写世界旗号，回应卡再确认；下向离开并写对应旗号。网页版入店/离店分支没有经过通用 `ChoiceOutcomeRouter.commitChoice`，左向不凭空写选择旗号。同世再次右选时来源 `NarrativeLedger` 会拒绝相同 promise ID，Godot 因此不重复生成回应。`noncombat_q_market_replay.gd` 从完整开局走到瘸脚许事实，再用可重放抽签自然抽中 `q_market`（固定 roll 0.20）；待选卡、右向待回应/已回应、下向离开、左向入楼/购买/离楼均严格读档，桌面原图与三按钮可见；模拟改版前右选存档，确认旧状态原样恢复。新版选择存入生效决断点，严格回放旧选择时不补写不存在的回应或旗号。两个专项退出码 0，原官坊礼物/回购专项和普通抽卡回归通过。

**N9w-02 只读事实窗口已验证**：官坊打开时按原 `causal_graph.json` 与 `spineFacts` 生成同世流转号服务；事实决断 +1 至 +4 的会话保留来源标签、说明、12 灵石成本和交付定义，逾期会话显示来源 `terminalClosure`。独立 `noncombat_causal_fact_clock.gd` 在权威 `runClock.decisionIndex` 实际推进的同一候选快照中关闭逾期事实，记录真实关闭决断；关店结果确认不推进该时钟。桌面禁用订货按钮及正文显示来源价款“需 12 灵石”，避免误认为已能交易。来源 SHA、服务会话版本和事实时钟生效点入存档；旧版会话在严格回放时保留原服务列表，下一次新会话才升级，旧事实时钟从恢复后的下一次决定开始。`noncombat_causal_services.gd`、`noncombat_q_market_replay.gd`、`noncombat_regulated_replay.gd` 退出码均为 0，独立只读复核未见新 P1/P2。订货后台事务的后续进度见下一段；交付尚未接通，可见条目仍不可付费。

**N9w-03 当前实施与路线证据**：已按网页版 `ShopSystem.executeVendorAction → NarrativeLedger.consumeFact → MarketSystem.registerLicensedRustedSwordOrder` 做内部单快照事务：复核被冻结服务与现行来源事实/价款，扣 12 灵石、消费指定事实、登记唯一订单（登记决断 +3 到期）、写会话回执和有序事件；无钱、伪造报价、重复以及写盘失败均不得改状态。`noncombat_causal_services.gd` 用来源形状的有效会话验证事务与失败回滚；公开 `Domain.perform_vendor_action` 在交付消费者未接时硬拒绝，桌面按钮也禁用，正式 `Domain.restore` 不接受未发布订单历史。固定零随机的首访许摊路线在决断 22 生成流转号、决断 27 关闭，随后官坊到决断 33 才开，`noncombat_causal_order_access_gap.gd` 固定这种确实错过期限的路线。另一条**真实可达路线**先跳过首访，在第二次集市决断 25 询问、事实记在 26，再由可重放的合法普通池抽签在决断 28 抽到 `q_market`；`noncombat_causal_reachability.gd` 证实有效服务与 12 灵石报价，并在待选卡、入楼会话两个断点严格读档，退出码 0。两条路线说明时间限制具有真实分支意义；网页 B4/B5 的 `stageAuthoredCard('q_market')` 演示仍不能替代这份自然证据。独立只读复核未见内部事务新 P1；交付、装备、战斗读取与公开支付的严格回放未接，**N9w-03 不能签收**。

### N9w-03b 到期生产者 Slice Charter + Evidence Manifest

| 字段 | 内容 |
| --- | --- |
| Issue ID / 玩家合同 | N9w-03b：订单登记后第 3 次核心决断产生唯一到货回执；同决断的交谈、关结果卡和读档不催熟订单；正常集市节律让位于已入队的官坊交付。公开付款继续关闭，直到领取、装配及严格回放都可用。 |
| 权威链 | `src/systems/MarketSystem.js::collectDueLicensedSwordDeliveries/markLicensedSwordDeliveryQueued` → `src/game.js::_queueDueLicensedSwordDelivery/_queueMarketForProjectedDecision`；Godot `noncombat_regulated_vendor_flow.gd::_register_causal_order` → `noncombat_domain.gd::_persist_snapshot` → `noncombat_market_flow.gd::settle`。订单与待交付 ID 都保存在同一候选快照。 |
| 根因 / 排除 | 当前 Godot 仅登记 REGISTERED 和 `dueCoreDecisionIndex`，没有随核心决断到期的生产者。不能用关店、UI 刷新或墙钟计时；网页版用权威 projected decision index。也不能提前开放支付，否则玩家会得到不可领取订单。 |
| 红测与门禁 | `godot/tests/noncombat_licensed_delivery_due.gd` 在生产者脚本不存在时退出 1；基线 `noncombat_causal_reachability.gd` 退出 0。新测试锁定 +1/+2 不到、+3 唯一到货、非核心同 index 不重复、后续核心不重排及伪造提前到期拒绝。待实施后跑本项、可达路线、官坊回放、普通流程及完整门禁，并由独立只读审计复核。 |
| 暂不宣称 | 本批的 READY/待交付 ID 只是内部持久事件，不能称为玩家可领取卡；领取法宝、来历事实、装配和公开订货属于 N9w-04 后续闭环。 |

**N9w-03b 实施证据与审计限定**：新 `noncombat_licensed_delivery.gd::settle` 仅在 `runClock.decisionIndex` 实际前进时校验订单并把到期 `REGISTERED` 改为 `READY`，同一候选快照写唯一 `deliveryReceiptId` 与 `pendingLicensedDeliveryOrderId`；`Domain._persist_snapshot` 在市场节律前调用，新增到货时抑制当次普通市场抽样。公开支付和领取仍未打开。修复前 `noncombat_licensed_delivery_due.gd` 因生产者不存在退出 1；修复后退出 0，覆盖登记索引 23、24/25 未到、26 到货、同索引与后续索引不重复、篡改到期索引拒绝。独立只读审计最初发现网页版在战斗中与突破继承待处理时不排到货；已加入 `Domain._delivery_eligible_for_tick` 和对应负例，复核认为这两个抑制条件与 `src/game.js` 对齐，未发现当前新增可达 P1/P2。审计仍将**玩家端到端订货→到货→完整读档标为 UNPROVEN**：当前专项构造来源形状的内部订单并驱动时钟，真实入口仍被支付门禁关闭。审计另指出未来境界继承接入时，普通集市节律也需按网页同一条件抑制；当前没有该状态的自然生产者，记入后续境界迁移核对。相关测试已加入 `tools/validate_godot_runtime.py` 项目门禁；完整门禁结果另记。

### N9w-04a 真正领取链 Slice Charter + Evidence Manifest（专项与总门禁通过）

| 字段 | 内容 |
| --- | --- |
| Issue ID / 玩家合同 | N9w-04a：从干净新局跳过首次许摊，在第二次集市问流转号，合法抽中 `q_market` 后付 12 灵石订货；第 3 次核心决断前交付卡不可出现，到期后验印领取唯一法宝和来历事实，再选择穿戴或收入纳戒；每个断点可严格读档，重复与失败提交无额外奖励。 |
| 权威链 | `data/narrative/causal_graph.json` + `src/systems/MarketSystem.js` + `src/systems/ShopSystem.js::preview/fulfillLicensedRustedSwordOrder` + `src/game.js::_buildLicensedRustedSwordDeliveryCard/_resolveLicensedRustedSwordDeliveryAction` + `src/systems/TreasureSystem.js::acquire`。Godot 走 `Domain.perform_vendor_action` → 订单候选事务 → `LicensedDelivery.settle/resume/claim/resolve_loadout` → `TreasureAcquisition` → `RunSession` 严格回放。 |
| 错误根因 / 排除 | 目前公开 `perform_vendor_action` 硬拒订单、`available_actions` 禁用，READY 没有玩家交付卡和领取消费者；仅把按钮解锁会扣款却无法兑现。不得用 staged card、直接注入订单或只验函数存在代替自然路线。 |
| 修复前失败 | `godot/tests/noncombat_licensed_delivery_journey.gd` 从真实新局/第二次集市/普通池抽中 `q_market`，在公开订单动作处退出 1：`public source order remains gated`。来源 `node tools/test_gdd_b5_licensed_rusted_sword_path.js` 7/7 通过。 |
| 完成门禁 | 同一测试须覆盖付款/到期/领取/装配及对应读档，另补写盘失败、重复、伪造与收纳分支；N9w-03b 与官坊、普通池、旧档及项目总门禁通过，再独立反证审计。战斗非教学遭遇读取此剑的被动和新卡另列 N9w-04b，不用教学战网关替代。 |

**N9w-04a 玩家路线证据（2026-10-21）**：`noncombat_licensed_delivery_journey.gd` 固定合法普通池抽签值 0.21，从干净新局跳过首次许摊，在第二次集市问得流转号、自然抽到 `q_market`，通过公开 API 支付 12 灵石；订单三次核心决断后才生成交付卡，领取唯一实例与来源事实，再对自然到达的同一装配待决态分别选择穿戴和收入纳戒。付款后、到货卡、领取后、两种装配后严格重放均通过。付款、领取、装配三次写盘失败注入均检查内存状态及存档字节不变，然后重试成功；重复订货与领取拒绝。`noncombat_licensed_delivery_claim.gd` 另覆盖内部候选态重复领取、收纳及来源字段，`noncombat_licensed_delivery_due.gd` 覆盖核心时钟与提前到期伪造。三个专项退出码均为 0；`noncombat_causal_services.gd` 改用公开入口验证订单失败回滚，`noncombat_causal_reachability.gd` 的旧“付款须拒绝”断言更新为活报价可用与严格读档，两项退出码均为 0。独立只读审计未找到已确认的玩家可达 P1/P2，并指出自然收纳读档缺口；补上分支后该专项通过。**完整项目门禁仍在复跑，N9w-04b 战斗效果仍未实现，不将领取闭环等同于战斗闭环。**

前述 N9w-02/03/03b 的“公开支付仍禁用”“交付尚不可领取”描述保留为各阶段历史断点，以上述 N9w-04a 玩家路线与最终门禁记录为当前状态。`Domain._persist_snapshot` 现在对突破继承待处理也抑制普通集市节律，与交付抑制共用来源条件。完整 `python tools/validate_godot_runtime.py` 在 2026-10-21 退出码 0，输出 `RUNTIME_MIGRATION_PASS data=74 art=603 audio=32 M0_steps=12 reactions=3 presentation=3 stage_routes=4`。第一次总门禁曾停在已过期的“公开支付应拒绝”断言，更新为有效报价/严格读档后通过；第二次曾在 `noncombat_save_slot_ui.gd` 偶发读到旧测试目录，该测试把进程启动后的微秒数单独当目录名，现改用系统秒数＋进程 ID＋微秒数，专项及完整门禁通过。另有源端 `test_gdd_batch1_authoritative_choice_preview.js` 的独立旧范围断言期望 38 而实际 40，未修改来源内容；它不属于本次 Godot 门禁。

### N9x-01 普通战斗选择交接 Slice Charter（局部消费者已验证，整段未签收）

`q_fellow` 是原炼气普通池权重 9 的「同门比试」。左选仅结算修为/道心，右选 `triggerCombat`；敌人定义位于**卡牌顶层** `enemy`，右选带胜/败/逃效果，卡牌另有 `combatRewards`。网页版 `CardSystem.resolveChoiceCombatContract` 将该选择识别为直接战斗，`CombatCoordinator.buildChoiceCombatWarning` 从 `choice.enemy || sourceCard.enemy` 建预警，`GameLogic` 在进入战斗前不发胜利奖励，读档由 `DeckCombatSystem._combatCardFromAuthoredChoice` 重建同一敌人。Godot 当前 `noncombat_normal_choice_policy` 仅接纯数值选项；修为和道心达到上限时，不能假称右选不可用而把左选当保底，所以固定抽签 0.20 的自然长局会在 `q_fellow` 安全停止。这是内容迁移缺口，不能靠跳卡、改权重或预扣奖励解决。

| 检查点 | 实施与验收 |
| --- | --- |
| 源码锁定与红测 | 用原 `data/cards/qi.json::q_fellow`、`CardSystem`、`CombatCoordinator`、`GameLogic`、`DeckCombatSystem` 建一条自然抽中卡的失败测试：未接消费者时保持 `FLOW_PENDING` 与存档字节不变。锁定原卡图 `scene_qi_q_fellow.png`、卡顶层敌人、右选三种战果和 `combatRewards` 的合并顺序。 |
| 非战斗所有权 | 新的普通战斗警告/待战请求保留原卡 ID、所选方向、源卡敌人、稳定 encounter owner、原始选择及尚未结算的战果投影；警告准备另记回执，不推进核心决断。普通池与首场教学战使用带显式类型的同一 `BattleRequest/Result` 边界，旧 v2 教学存档不得变形。 |
| 装备接口 | 请求由已保存的 `equipment`、`treasureInstances` 和牌组权威生成，穿戴 `licensed_rusted_sword` 才可把其来源被动与 `licensed_rusted_sword_guard` 战术卡交给战斗消费者；收纳分支不得生效。战斗域只消费并回传认证终局，不能自行写剧情奖励。 |
| 结果与回放 | 胜/败/逃只在对应 owner 的一次原子提交中结算来源效果、卡牌战斗奖励、受伤与决定时钟，再生成结果卡/下一剧情；写盘失败保留待战状态，重复/外来/不完整结果不获奖。自然 `q_fellow` 待选、预警、待战、战果与重启各断点严格回放。 |
| 并行边界 | 本批先改非战斗普通卡、请求网关和返回结算槽位；已有战斗场景/角色/光影由另一任务维护。只有真实桌面战斗能消费新合同并返回有效终局后，才称玩家端到端完成。 |

战斗前置口径来自 `godot/NONCOMBAT_FULL_MIGRATION_TASKBOOK.md` 的 N5 接口约定；以上为待执行验收条件，不计作已迁功能。

**2026-10-26 实施与证据。** `noncombat_q_fellow_entry.gd` 曾在合法普通抽卡值 0.18 后因没有消费者退出1，并验证失败前状态与存档字节不变；补齐普通右选预警和网关后，从 Godot 剑修自然决定27抽到原 `q_fellow`，顶层 `sect_sparring_qi` 敌人和右向选择进入预警，确认时不推进核心决定，待战请求保持无 catalog ID、右向、原选择和当前牌组。原 `migrated_presentations` 引用的 17 张战场/敌人/特效图片已复制并录入 `source_manifest.json`，Godot 导入及资源覆盖门禁通过。

`tools/capture_noncombat_q_fellow_source.js` 在未改牌、属性、生命、回合或战果的浏览器生产 VM 中，以 seed1 的公开输入于决定20自然抽到 `q_fellow`；右选、预警、真实出牌/结束回合/反应/逃跑构成胜败逃三条源轨迹，保存于 `tests/fixtures/q_fellow_combat_source.json`。网页实收：胜修为95→100、灵石60→66、恶业25→30、青云声望10→7，`combatGlory` 存档 delay8；败实收伤势1并燃血，气血最终1、上限3→2/道心上限2→1、青云声望10→8；逃只扣道心1，不扣寿元或声望。三张结果卡及确认后的档均在浏览器冷启动逐字段相等。

Godot `noncombat_q_fellow_entry.gd` 对照浏览器预警的完整显示与 `choices` 合同，验证预警冷恢复；`noncombat_q_fellow_outcomes.gd` 对照三个结果卡的稳定字段及败/逃完整卡，验证各来源效果、燃血、声望、seed、待战/结果冷恢复、失败写盘回滚、外来与重复 owner 拒绝，三结局确认后能继续原 Flow。两专项和既有 `noncombat_normal_runtime.gd` 均退出0，独立只读审计复跑两专项退出0，未见本局部链路确定 P1/P2。浏览器夹具 SHA 与两专项已登记 `validate_godot_runtime.py`；资源覆盖门禁输出 `NONCOMBAT_ASSET_COVERAGE_PASS images=531 animated=3 audio=32 copied=623`。

**未签收条件。** 浏览器来源是跳过教程的决定20路径，Godot 新局包含教程并在决定27自然抽卡，修为/灵石/上限不同；因此现有证据只证同卡分支及其来源规则，未证整条开局和后继卡逐值同轨。Godot 战果仍由合成 v2 终态合同驱动，实际战场生产者未回传认证终局；穿戴 `licensed_rusted_sword` 后的守后反击被动与战术卡尚未由真实战场验收。N9x-01 整段和 N0–N11 总目标维持未完成。

### N9x-02 原炼气普通卡「山间坊市」 Slice Charter（专项与总门禁通过）

`data/cards/qi.json::q_shop` 是权重 10 的普通池 `SHOP` 卡，与 P25 `shop_encounter`、`q_market` 官坊和公开集市是三个不同入口。原卡有四个选择：20 石得中文键「筑基丹」、10 石得中文键「回春丹」、15 石打开删牌界面、离开获得 1 点道心；上三项含原 `costCheck`。网页 `EffectService` 直接把中文丹药键写入 `resources.pills`，`removeCard` 调用删牌 UI，费用在选目标前结算。Godot 目前普通池能把此卡作为 `NORMAL_PENDING` 呈现，但 `_simple_choice` 只认纯数值，买丹/删牌都不可用，界面统一提示“正向收益已达上限”，与真实原因不符。不能把它并入官坊价目或重抽为别的卡。

| 检查点 | 实施与验收 |
| --- | --- |
| 红测与来源 | 从原 `qi.json` 冻结卡 ID、四选、原图、三笔成本、中文丹药键、删牌目标规则；自然普通池抽中 `q_shop` 后先证明当前买丹和删牌不可执行或错误提示。保留原网页 `EffectService/GameStateManager` 的键语义，不擅自把中文丹药写成官坊 `foundation` ID。 |
| 付款与持有 | 左/右在同一候选快照中校验 `costCheck`、扣来源价款、增加对应丹药 1 件、写一次决断与回执；余额不足、重复、写盘失败零变化，待选及结算后严格回放。下选只按原文加道心并推进一次。 |
| 精简牌组 | 上选先付原卡 15 石并进入可恢复的删牌目标待决态；与现有洞府目标选择共用牌组权威和 UI 能力。网页删牌 UI 在选定目标时**另扣** `deck_progression.json` 的 `removeCost=6` 灵石；共 21 石。取消不退首笔 15 石；退出、重启和重复操作由来源规则与已提交价款决定。 |
| 桌面与兼容 | 四按钮、费用/不可用原因、原 `scene_qi_q_shop.png`、目标列表实际可见；旧 `q_shop` 待选存档仍可恢复。网页来源中的中文丹药键与后续 `foundation` 消费键不一致，先保持来源所有权并单列后续道具别名审计，不能通过本批测试伪称可用于突破。 |

本批仅触及非战斗 `q_shop` 的选择和目标消费者；N9x-01 普通战斗卡交接继续保留为战斗合同依赖项。

**N9x-02 实施与证据（2026-10-21）**：`noncombat_q_shop_source.gd` 起初在左选不可执行处红测退出 1；接线后核验原卡四向、场景图、中文丹药键，以及满道心且仍买得起商品时「离开」不可得道心、零石且其他选项不可执行时允许回退。`noncombat_q_shop_journey.gd` 从干净剑修新局走到第 27 次决定，用普通池合法固定抽签 0.55 自然抽到 `q_shop`，16 灵石时左选不可买、右选与上选可用；桌面加载原 `scene_qi_q_shop.png`、正确按钮状态及 15+6 费用提示。右选支付 10 石得到中文键「回春丹」一份，写盘失败保持内存与存档字节，重试后严格读档。上选进入同卡来源的删牌目标待决态，先扣 15 石，余 1 石不够目标另付 6 石，因此全部目标禁用；待决、取消不退费及取消后均严格读档。高余额分支另验 20 石「筑基丹」和 15+6 实删一张牌，但该分支是来源形状的合成余额，**不算自然实删后的严格读档证据**。原 `camp_meditation` 删牌和普通卡专项回归均通过；新用例纳入 `tools/validate_godot_runtime.py`。独立只读审计先发现满道心门禁差异，修复并补测试后未见新增明确 P1/P2。最终完整 `python tools/validate_godot_runtime.py` 退出码 0，输出 `RUNTIME_MIGRATION_PASS data=74 art=603 audio=32 M0_steps=12 reactions=3 presentation=3 stage_routes=4`。

**N9x-02 后续限制**：需另找原玩法自然累计至少 21 灵石、在 `q_shop` 真正选牌并严格重放的路线；旧洞府目标完成存档的显式专项回归也待补。探索丹修自然路线时，决断 14 已持有 40 石，但决断 17 或 19 的鬼市商品入口因交易消费者尚未迁移而安全停止；这不是 `q_shop` 的实删证明，也提示鬼市为高余额路线的前置缺口。网页 `q_shop` 发出的中文「筑基丹」与突破消费者使用的 `foundation` 标识不一致，先保留来源键，下一批审计同名道具的显示、使用和迁移语义，不在没有来源证据时自动换键。

### N9x-03 鬼市待发卡与交易闭环 Slice Charter（实施中）

丹修自然路线在第 14 次决定已持有 40 灵石，随后 `MarketFlow` 会按鬼市优先级排入 `market_encounter`；目前 `noncombat_market_flow.gd::resume` 明确拒绝展示，因为商品与交易消费者未迁。原 `MarketSystem.tick` 在夜间、人口地点和福缘/恶业/线索信号满足时先排鬼市，再排公开集市；`_generateGhostItems` 抽货、`_buildMarketCard` 抽风味文案，进入会话时还会重新构造商品。仅换一张静态卡或允许“绕道”会改变随机消耗和可重放事实，不算完成。

| 检查点 | 来源与验收 |
| --- | --- |
| N9x-03a 到场与原卡 | `src/systems/MarketSystem.js::tick/_generateGhostItems/_buildMarketCard` 与 `data/markets/vendor_profiles.json::ghost_market`：按来源夜间与信号条件到场，固定原随机消耗顺序、风味/福缘/货源描述及左右选；旧安全停盘仍能在新消费者接通后严格读档。 |
| N9x-03b 入摊与报价 | `MarketSystem.createVendorSession`、`ShopSystem.getAvailableItems`：独立 `ghost_market` 会话、契台场景、冻结报价与隐特质、验封服务、交谈预算及寿元/灵石复合成本；不借用官坊或公开集市档。 |
| N9x-03c 夜契及追债 | 原 `ghost_oath_rusted_sword` 先付 4 灵石与 3 寿元，唯一剑实例和 `sword_origin_ghost_oath` 事实绑定到债务；第 3 次核心决断起催收另 2 灵石，清偿/违约只收束一次，违约按来源撤销鬼市准入。负余额、死亡边界、伪造债务与写盘失败不能漏扣或重奖。 |
| N9x-03d 普通货交易 | 从冻结货单购买炼气可装备普通法宝，扣灵石与寿元，生成实例、装配决定和普通债；混购、同时到期与严格读档均需覆盖。 |
| N9x-03e 丹修自然链（本段已验收） | 丹修自然路线在鬼市到场、入摊、交易、到期、结果后接原 `q_pillRecipe` 两分支，并以自然余额在 `q_shop` 实删及严格读档；本段证据见下方 2026-10-22 验收记录。其它后续剧情和战斗仍各按合同验收。 |

实施时先建立来源失败用例，再逐批完成；各阶段状态以本账本后文和任务书文首为准，不通过改抽签权重或抹去鬼市事件来换取表面畅通。

**N9x-03a/b 来源准备（2026-10-21）**：新增 `noncombat_ghost_market_catalog.gd`，把原 `MarketSystem._generateItems → _generateGhostItems → _buildMarketCard` 的抽货、商路修正、五件截取、封签、加价和风味文案移为纯生成器；另按 `createVendorSession` 把固定夜契残剑放在随机货物前，并冻结每件的灵石＋寿元双成本、验封服务、场景、债务规则和交谈额度。`noncombat_ghost_catalog_source.gd` 先因无 `build_session` 红测，再用网页版固定随机值 0、0.37 与高福缘 41 次货单抽签＋1 次文案抽签的来源投影校对：高福缘八候选槽只展示五件，商品 ID、价格及两处封签均一致。此测试纳入 Godot 运行门禁。**当前仍是纯来源模块**：尚未接到 `MarketFlow` 的到场存档和桌面入口，也未接购买、验封、夜契追债与自然丹修读档；因此 `market_encounter` 仍维持安全停止，N9x-03a/b 不能签收玩家可玩完成。

**独立只读复核后的修正与集成门禁**：高繁荣路线下，原网页在高稀有度无货而降级选货时不累计金质件数；纯模块最初误累计，现用 `deity`、福缘 90、已拥有全部五星、仍可抽六星「破魂锥」的固定序列逐抽签对照，包含 36 次货单抽签及额外 1 次文案抽签，商品/价格/封签一致。退化随机源若对五件货物始终命中同一封签位，网页版会无限循环；Godot 在 64 次以上仍不足两个不同货位时安全拒绝生成，正常来源序列不变。`_active_route` 目前对自然变化的势力声望/暗流拒绝推算，而网页版商路会随这些事件改变：**在运行态接入前必须迁移或可重放商路事件及状态**，否则任务后的真实鬼市路线仍会停盘；不能把纯模块测试当作自然链通过。

**N9x-03 来源门禁记录**：新增专项单跑退出码 0；纳入完整 `python tools/validate_godot_runtime.py` 后再次退出码 0，汇总 `RUNTIME_MIGRATION_PASS data=74 art=603 audio=32 M0_steps=12 reactions=3 presentation=3 stage_routes=4`。独立只读复核未发现修正后的纯模块仍有明确 P1/P2；审计范围不含尚未接入的玩家入口和债务链。下一批先补动态商路事件与可重放快照，再在一次原子提交里冻结鬼市货单、卡文和随机数状态；其后接右选离开、左选会话及夜契/验封/追债消费者。

**N9x-03 商路状态增量（2026-10-21，专项与总门禁通过）**：`noncombat_trade_route_flow.gd` 从原 `TradeRouteSystem` 与 `world:trade_routes` 建立四条初始路线，并在同一 `Domain._persist_snapshot` 事务消费上游事件，写入路线数值、最多八条历史、来源指纹与激活索引。白狐第三幕 `factionRewards` 的六次真实声望变动按来源顺序投递，针对网页源端固定投影核对四条路线：青云剑路通畅 72/繁荣 56、神农药河 64/61、西域血砂道 36/41、遗迹星路 28/32；事件缺失或声望/暗流总值不符时拒绝提交。鬼市目录与官坊价格只接受经过来源校验的商路快照；新局首个决定后严格读档一致。旧档恢复边界经只读复核修正：首生决断 0–5、势力状态为来源初值且无市场购买的前缀，可在下一次决断激活可信初始路线；更晚或有变化的旧档保留 `tradeRouteLegacyUnverified`，不提供依赖商路的目录/报价。`noncombat_trade_route_state.gd`、`noncombat_whitefox_third.gd`、持久化和两类目录专项退出码 0。首次总门禁发现鬼市目录旧测试以残缺商路快照模拟高繁荣，现改用完整来源指纹快照；原六星降级抽取专项及总门禁重新通过，汇总 `RUNTIME_MIGRATION_PASS data=74 art=603 audio=32 M0_steps=12 reactions=3 presentation=3 stage_routes=4`。独立只读复核未发现当前新增明确 P1/P2。当前非战斗网关尚无认证战果回传，秘境成功及鬼市购买也未形成可玩结算；对应原 `combat:victorySettled`、`dungeon:settled`、`shop:purchasePrepared` 三种商路事件须在各自生产者接通时补齐，并逐个验证严格读档。鬼市卡到场与会话仍在安全停盘，不把纯目录通过等同于玩家链通过。

**N9x-03a 到场冻结增量（2026-10-21，专项通过、扩展总门禁待复验）**：`MarketFlow.settle` 在夜门到期且信号满足时，先按原 `MarketSystem.tick` 顺序抽下一次夜门，再调用鬼市来源目录，写入同一候选快照的 `pendingGhostPlan` 与 `pendingMarketCard`；普通商队随后覆盖单一待发槽时清除旧鬼市计划。生产状态使用同一个持久化 `marketRngState`，固定零值节律测试因无法抽出多个不同封签货位，货单部分仍取保存的 seeded RNG。新 `noncombat_ghost_arrival_frozen.gd` 从来源形状的第 14 次决断检验夜门、货单、卡文、来源指纹与相同随机状态重算，拒绝不可信商路。`noncombat_market_arrival.gd` 又从真实游玩路线截取第 14 次决断的到场快照，经新的 `RunSession` 严格读档与字段对比，原第 21 次决断覆盖节律、公开集市右选回滚及旧档专项仍通过。此阶段 `MarketFlow.resume` 对鬼市待发卡仍明确停盘，因为入摊、交易和债务消费者尚缺；到场数据可重放不能等同于玩家可选择的鬼市卡。


### 2026-10-21 N9x-03a2 鬼市原卡展示与绕行（已实施，入摊仍待接）

**ISSUE-N9x-03a2**：此前鬼市虽能按来源夜门冻结货单，但 `MarketFlow.resume` 停盘，玩家无法看到原卡；桌面也没有将 `market_encounter` 绑定到鬼市原背景。法修自然路线现从教程、避战、白狐分支、公开集市到 `q_gathering`，在决断 14 由正式 `Domain.resume_flow` 呈现鬼市卡。`MarketFlow` 校验 `pendingGhostPlan` 的来源指纹与待发卡一致后投影原文；右选「绕道而行」按一次决定结算并清除货单。左选「进去逛逛」保持禁用，避免落入尚未实现的鬼市购买、验封、夜契及追债流程。桌面从 `ghost_market.presentationProfile.backgroundPath` 读取原 `bg_market_ghost_pc98.webp`。

**验收证据**：`godot/tests/noncombat_ghost_choice.gd` 修复前因鬼市卡停盘失败；修复后自然法修路线、待选与已选严格读档、写盘失败原字节回滚、同令牌重复选择拒绝、旧占位及伪造货源指纹拒绝、桌面原图与左禁右显均退出 0。`python tools/validate_godot_runtime.py` 全量门禁本次重跑通过：`RUNTIME_MIGRATION_PASS data=74 art=603 audio=32 M0_steps=12 reactions=3 presentation=3 stage_routes=4`。独立只读复核 VERIFIED，未发现此范围 P1/P2；未做像素视觉对比。下一批 N9x-03b 才接左选入摊、冻结报价与离场；N9x-03c 才接交易、验封、夜契及追债，不能把右选可玩写成鬼市闭环。
### 2026-10-21 N9x-03b 鬼市入摊与空手离场 Slice Charter（实施中）

| Issue | 来源链 | 玩家验收与证据 |
| --- | --- | --- |
| ISSUE-N9x-03b | `src/game.js::makeChoice(ENTER_VENDOR) → MarketSystem.canEnterVendor/createVendorSession → close/vendor result`；原 `data/markets/vendor_profiles.json::ghost_market`，已冻结的 `pendingGhostPlan`。 | 法修第 14 次决断原鬼市卡左选在夜窗、来源指纹与访问权都有效时进入独立 `ghost_market` 会话；固定契约在随机货单之前，报价包含灵石和寿元，原背景及退出标签可见。当前只允许查看与空手离开，交易/验封/夜契保持禁用。打开、关闭、结果卡、结果确认各断点都需严格读档；失败写盘不改内存和字节，伪造来源与非夜窗拒绝。 |

**边界**：`GhostCatalog.build_session` 已是纯来源投影，不能重新抽货；`RunSession` 只在候选快照完整后提交。左选先打开会话，来源决定在关闭时才计一次；空手离场结果文案按 `GameLogic._buildVendorResultCard(ghost)`。本切片不产生交易/债务事实；N9x-03c 必须另建来源交易与债务回放测试后开放报价按钮。
### 2026-10-21 N9x-03c1 夜契残剑购买 Slice Charter（下一批）

| Issue | 来源与状态边界 | 玩家验收 |
| --- | --- | --- |
| ISSUE-N9x-03c1 | `ShopSystem._purchaseTreasure/_createGhostDebt`、`TreasureSystem.acquire`、`NarrativeLedger.recordFact`、`MarketSystem.createVendorSession`；原 `ghost_oath_rusted_sword` 固定契约在 `vendor_profiles.json`。 | 从自然鬼市入摊购买「夜契残剑」一次；同一候选快照扣 4 灵石与 3 寿元、发唯一实例、记 `sword_origin_ghost_oath` 事实、建立三次核心决断后的债务，并出现穿戴/收纳待决态。失败写盘、余额不足、重复购买、伪造来源均不改状态与字节；购买后、装配后严格读档；桌面按钮只在消费者完备时启用。 |

**拒绝捷径**：`TreasureAcquisition.acquire` 目前只认证公开集市与官坊来源，必须扩展有来源指纹的鬼市交易合同；不能只往 `resources.treasures` 追加 ID。`GhostVendorFlow.source_valid` 目前只接受零交易会话，必须根据已提交购买历史重建期望会话并验证债务/事实/实例；不能为了开按钮跳过严格回放。债到期、清偿/违约和战斗胜利催债属后续 N9x-03c2/03c3，不把获得剑等同于债务闭环。测试先红后绿，专项、整套门禁及独立只读复核均为签收条件。
### 2026-10-21 N9x-03b 鬼市入摊与空手离场验收（本批完成）

**来源与实现**：`Domain.choose` 在 `market_encounter` 左选后通过 `GhostVendorFlow.open` 将已冻结的 `pendingGhostPlan` 投影为独立 `ghost_market` 会话；固定「夜契残剑」排在随机货单前，原 `bg_market_ghost_pc98.webp`、契台背景、灵石和寿元双成本、封签及退出标签进入桌面显示。会话报价、浮价区间与货物沿用到场计划；运势等级和商路提示由**入摊时**状态计算。`close` 只允许零交易会话，写一次来源选择、访问记录和原风格空离摊结果；第 15 次决断到期命盘可覆盖结果，确认后再续行。购买、验封和交谈按钮仍禁用。

**先红后绿**：`godot/tests/noncombat_ghost_entry.gd` 在左选未开放时退出 1；实现后从法修真实路线自然出鬼市卡，验证左选、会话货单、原背景、按钮禁用、入摊/关闭/结果/确认断点严格读档及两次写盘失败回滚。`godot/tests/noncombat_ghost_choice.gd` 验夜门、鬼市路引物理持有、伪造货源指纹拒绝、旧占位拒绝和绕行一次性结算；延迟入摊的合成状态用例先因旧到场运势/商路提示退出 1，改为入摊时读当前状态后退出 0，同时断言价格倍数仍冻结。该合成用例并非跨多次决断的自然路线证据。

**门禁与审计**：`noncombat_ghost_choice.gd`、`noncombat_ghost_entry.gd` 单跑均退出 0；`python tools/validate_godot_runtime.py` 退出 0，输出 `RUNTIME_MIGRATION_PASS data=74 art=603 audio=32 M0_steps=12 reactions=3 presentation=3 stage_routes=4`。独立只读审计复核网页 `src/game.js:2545-2556` 的入摊时运势/商路读取与冻结货单时点，未发现本批剩余可确认 P1/P2。`NONCOMBAT_FULL_MIGRATION_TASKBOOK.md` 顶部已同步当前状态。历史 N9x-03a2 的「左禁右显」仅描述当时断点，当前以本节为准。

**未完成**：夜契购买、唯一法宝来历与三次决断后的债务/清偿/违约、验封、随机货物交易、战斗催债、丹修自然长局，以及网页战果回传等仍缺。下一批按上面的 N9x-03c1 契约购买合同实施；不把可查看与空离摊称为鬼市交易闭环。
### 2026-10-21 N9x-03c1/c2 夜契残剑签约、装配与到期债务（本批完成）

**来源链与玩家路径**：法修真实开局依次走教程、首战避开、白狐任务、公开集市及 q_gathering，于第 14 次决断见来源鬼市卡，左选进入冻结的 ghost_market 会话。固定夜契残剑按来源排在随机货物之前，桌面按钮显示 4 灵石加 3 寿元并可签约；其他随机货品仍禁用。同一候选快照扣两项成本，发一个带鬼市来源和债务 ID 的残剑实例，记录 sword_origin_ghost_oath 事实、三次核心决断后的债务和穿戴/收纳待决态。购买不能重复；穿戴或收纳均可严格读档。离摊计一次来源左选，结果卡与命盘覆盖可恢复。

**债务时序与处理**：第 17 次核心决断排唯一到期债，优先于命盘、涟漪、天机和集市。索债卡左选扣 2 灵石并消耗来历事实，右选不扣灵石且永久撤销鬼市准入；两种结局分别在认证到期快照上严格重放。战斗待结算与突破继承期间沿用官坊交付的来源门禁推迟排债，下一合格核心决断补排；这两个负例和补排目前以合成候选态验证，尚非自然战斗/突破游玩证据。Godot 尚无胜利催债与夜契开场被动的认证战斗消费者，因此索债卡不宣称该战斗效果。

**测试与回滚**：godot/tests/noncombat_ghost_oath_purchase.gd 先因交易消费者缺失红测，后从自然鬼市入口验证可见按钮、一次性费用/实例/事实/债务、购买写盘失败保持内存及文件原字节、穿戴和收纳分支、结果卡、到期优先级、清偿写盘失败回滚、违约、余额不足门禁、伪造债务与剑实例关系拒绝及各断点严格读档。专项退出 0；网页版来源测试 tools/test_gdd_b5_ghost_oath_rusted_sword_path.js 退出 0（20 通过，0 失败）。完整 python tools/validate_godot_runtime.py 退出 0：RUNTIME_MIGRATION_PASS data=74 art=603 audio=32 M0_steps=12 reactions=3 presentation=3 stage_routes=4。首轮门禁与测试同时编辑时曾因未完成的第三参数红测挂起；稳定版专项实际约 25 秒，已列入 60 秒长路线测试档，最终整套门禁通过。独立只读反证审计指出的未接战斗效果文案和战斗/继承提前排债两处 P2 已修复；最终复核未发现当前批次可确认的 P1/P2。

**剩余缺口与下一批**：鬼市随机货品购买、封签验看、交谈、战斗胜利催债与夜契被动、市场购买驱动商路、丹修自然长局仍缺。验封会消耗真实 itemInventory 中一份商路线索，还会修改会话冻结货单并产生操作回执；下一批须按网页操作顺序保存购买与验封的统一事件序列，严格读档后才开放按钮。旧 N9x-03c1 charter 的“下一批”与 N9x-03b 验收结尾的“购买未完成”是其各自当时的历史断点，本节是当前状态。
### 2026-10-21 N9x-03c3 鬼市验封 Slice Charter（实施中）

| Issue | 玩家合同与权威链 | 当前根因与本批验收 |
| --- | --- | --- |
| ISSUE-N9x-03c3 | 网页 ShopSystem.getVendorActions / performVendorAction → ghost_inspect_seal 服务；来源 vendor_profiles.json 定义一份商路线索的 item 成本；MarketSystem 到场冻结封签与揭示文本。Godot 桌面点击验看后，真实 itemInventory 扣一，冻结货单的指定封签变为 revealed，操作回执和会话摘要可恢复。 | Godot GhostVendorFlow.available_actions 目前恒空，Domain.perform_vendor_action 拒绝鬼市，_replay_vendor_actions 拒绝鬼市行动历史，close 拒绝 actionReceipts。先用自然路线或认证入口红测，再实现一次性验封、余额不足/重复/伪造来源拒绝、写盘失败原字节回滚、购买与验封先后顺序的严格回放、桌面入口和安全离摊。 |

**边界与门禁**：本批只接封签服务；随机鬼市货物购买含多类型法宝、债务和战斗消费者，另批处理。保持网页 data 定义为价款与文案来源，不增第二套手工货表。先跑 Godot 专项，再跑受影响的鬼市/集市专项、完整运行门禁及只读独立审计。无需修改战斗场景或移动端。

### 2026-10-21 N9x-03c3 鬼市验封验收

**来源与事务**：网页 `ShopSystem.getVendorActions / performVendorAction` 对 `ghost_inspect_seal:<offerId>` 收取一份 `商路线索`，将本次冻结货单对应 `hiddenTrait.status` 从 `sealed` 改为 `revealed`，写 `actionReceipts`、`summary.exchangeCount`、`summary.exchangedItems` 与共享 `marketActionHistory`。Godot 使用公开集市自然购买的商路线索和冻结鬼市货单执行同一候选快照事务；桌面按钮显示成本，验封前隐藏真相，提交后显示原 `revealedText`。夜契购买和验封按 `ghostVendorEventHistory` 保存实际执行顺序，以便严格读档重放。网页允许夜契购买后装配决定未决时先验封，Godot 同样支持 `purchase → inspect → loadout`，不会强迫玩家先收纳或穿戴。

**集市边界修复**：先红测复现“验封后离鬼市，再次进入公开集市被拒”。公开集市关系投影现在只消费公开集市动作；遇鬼市动作时须同时验证鬼市格式的 sessionKey、配对的 `ghostVendorEventHistory` 行、合法鬼市访问记录，或 48 条访问窗口已逐出的旧记录。访问窗口清理只把公开摊位动作折入摊主关系，保留鬼市验封动作供物品扣除的重放。不能只因未知动作 ID 就跳过验证。

**验收证据**：`godot/tests/noncombat_ghost_seal.gd` 从法修真实路线先在公开集市买商路线索，再入鬼市验封，验证原子扣物、回执、摘要、显示、无物和重复拒绝；两次失败写盘均保持内存与存档原字节。专项覆盖 `inspect → purchase → loadout` 与 `purchase → inspect → loadout` 的严格读档，验封后安全离摊、下一次公开集市左选入摊及严格读档；三个独立落盘篡改快照（重复鬼市事件、删除共享动作、回改封签状态）均被 `restore` 拒绝。修复前自然后续集市测试退出 1，修复后专项退出 0，标记 `NONCOMBAT_GHOST_SEAL_PASS natural=true rollback=true inventory=true replay=true order=true ui=true`。独立只读审计复跑本专项、夜契购买和鬼市入摊专项，结论 VERIFIED，未发现本批确定 P1/P2。48 次自然访问后的完整长局恢复仍未专项验证；本批不据此宣称全量市场或非战斗迁移完成。

**完整门禁**：`python tools/validate_godot_runtime.py` 退出 0，输出 `RUNTIME_MIGRATION_PASS data=74 art=603 audio=32 M0_steps=12 reactions=3 presentation=3 stage_routes=4`。这覆盖现有迁移测试，不等同未迁移内容已完成。

**后续**：随机鬼市货物的法宝、货币与债务种类尚需逐个接入来源事务；夜契战斗被动/胜利催债、丹修自然长局与战斗回传仍是独立缺口。当前网页版鬼市档 `stalls` 为空，`ShopSystem.getVendorActions` 只生成验封服务，不存在可迁移的鬼市交谈动作。

### 2026-10-21 N9x-03d 鬼市随机法宝交易 Slice Charter（已验收，非完整鬼市）

| Issue | 玩家合同与权威链 | 根因、范围和验收 |
| --- | --- | --- |
| ISSUE-N9x-03d | 网页 `MarketSystem._generateGhostItems/createVendorSession → ShopSystem.purchase/_purchaseTreasure/_createGhostDebt → GameLogic._buildGhostDebtDueCard/_resolveGhostDebtAction`；Godot 以到场冻结的 `pendingGhostPlan.stock` 和 `treasures.json` 为商品来源。 | 当前 `GhostVendorFlow.available_offers` 仅启用固定夜契，`purchase_oath`、`resolve_loadout` 和 `_project_oath_purchase` 只接受夜契残剑，`GhostDebtFlow` 只认 `ghost_oath_sword`。使炼气自然货单中有能力支付的普通法宝可购买：原子扣报价中的灵石与寿元、唯一实例、穿戴/收纳、普通鬼债三次决断后索取半价灵石、清偿/违约、多个交易依真实顺序严格读档。失败写盘不改状态或原字节，余额不足/重复购买/伪造来源/畸形债务拒绝。 |

**边界**：随机货单不手写；只为来源定义且拥有装备槽 `weapon/armor/accessory/artifact` 的法宝打开交易。网页版 `_buildPendingLoadoutDecision` 对其它类型返回失败，因此 Godot 不把高境界非装备物品误标为可买。普通鬼债没有夜契的来历事实和胜利压力；不得伪造 `sword_origin_ghost_oath` 或修改既有夜契债务语义。若自然初始余额不足，用由真实鬼市到场快照派生、仅提高余额的认证测试分支验证交易，不把它称作自然赚得的货币。整套 Godot 门禁、浏览器来源测试和独立只读反证审计后方可验收。

**根因与先红证据**：`godot/tests/noncombat_ghost_generic_goods.gd` 从法修真实路线在第 14 次决断到达来源鬼市，观察到 25 灵石、78 寿元和四件普通炼气法宝；修复前 `vendor_offers` 对它们一律 `supported=false`，专项以 `ordinary source ghost treasure has no purchase consumer` 退出 1。实现后第二个失败证据是两份普通债同日到期：第一份清偿后，第二份处于 `DUE` 却未再排可见索债卡；专项以 `second due ghost contract was lost after first settlement` 退出 1。混购检查又证明夜契 `purchase_oath` 会把已发生的普通交易汇总覆盖成单笔；已改为增量累计。

**实施与验收证据**：`GhostVendorFlow` 消费冻结的来源报价，只对来源法宝定义中可装配的普通货物执行灵石与寿元双成本事务，写唯一实例、普通鬼债、穿戴/收纳决定、会话汇总和有序事件账本；`TreasureAcquisition` 认证该普通鬼市交易来源；`GhostDebtFlow` 在到期时以来源冻结的半价清偿额生成无夜契因果事实的索债卡，连续排出同时到期的多份债。专项从自然余额完成两笔普通货物交易、装备/收纳、清偿第一笔、违约第二笔，逐断点严格读档，验证失败写盘原字节回滚、余额不足、重复交易、免费债务伪造拒绝，以及普通法宝与夜契两种先后混购。`noncombat_ghost_seal.gd` 额外覆盖普通商品→收纳→验封的事件顺序与严格读档。`noncombat_ghost_generic_goods.gd` 输出 `NONCOMBAT_GHOST_GENERIC_GOODS_PASS source=true atomic=true loadout=true replay=true multi=true debt=true`；网页版 `test_gdd_b2_market_domain.js` 与 `test_gdd_b5_ghost_oath_rusted_sword_path.js` 退出 0，Godot 夜契、验封专项退出 0。完整 `python tools/validate_godot_runtime.py` 退出 0，汇总 `RUNTIME_MIGRATION_PASS data=74 art=603 audio=32 M0_steps=12 reactions=3 presentation=3 stage_routes=4`。前两次完整运行仅因 `ghost_choice` 的 20 秒旧进程限时和新增验封混购专项的 60 秒限时中止；分别单跑量得 23.54 秒与 58.52 秒且断言通过，验收器只对这些实测慢例提高限时后全量通过。独立只读复核及最终小改动复核均 VERIFIED，未发现本批玩家可达 P1/P2。

**N9x-03e 接续缺口**：本批法修自然鬼市足额交易不等于丹修高余额长局；须从丹修真实开局逐断点完成鬼市到场、交易、债务、后续卡调度，并在自然余额下实际到达 `q_shop` 后执行目标删牌及严格读档。其它境界/非装备商品、夜契战斗被动和胜利催债仍在本批范围外；无来源交易消费者的货物继续不可买。

### 2026-10-22 N9x-03e 丹修鬼市至山间坊市自然长局 Slice Charter（本段已验收）

| Issue | 玩家合同与权威链 | 根因、实现和边界 |
| --- | --- | --- |
| ISSUE-N9x-03e | 网页 `data/cards/qi.json::q_pillRecipe → EffectService`：左选扣 10 灵石、加 15 修为、获 ID 为 `foundation` 的丹药；右选加 5 福缘并种下 `pillPoison`（原 delay 8、金丹期）的因果。Godot `noncombat_opening_ui → Domain.resume_flow/choose → NormalDrawPolicy/NormalChoicePolicy → RunSession` 必须让丹修高余额自然路线穿过该卡，随后从真实抽签到 `q_shop` 完成两段共 21 灵石删牌。 | 原 `NormalChoicePolicy._simple_choice` 拒绝非数值 `pill` 和选择级 `karmaSeed`；`Domain._pending_normal` 因两边都不可选而安全停止。仅对原卡开放这两种来源选择；左选把丹药写入 `resources.pills.foundation`，右选以现有 `MilestoneFlow` 种子账本入账并随决定 tick。后续金丹期因果兑现、`foundation` 丹药突破消费和完整丹修长局仍由各自消费者验收，本批不提前宣称。 |

**先红证据与排除项**：`godot/tests/noncombat_pill_ghost_q_shop_journey.gd` 从丹修开局按真实路线在第 14 次决断以 40 灵石进鬼市，购买普通法宝并在第 17 次决断清偿普通鬼债；第 20 次决断的 `q_inherit` 后，`resume_flow()` 退出 1，报 `selected ordinary card needs an unmigrated choice consumer: q_pillRecipe`。不是资金、鬼市报价或卡池抽签问题；同一自然状态已有足够灵石，来源卡及其两项非数值效果可从原 `qi.json` 和 `EffectService` 核对。

**实施与验收证据**：`NormalChoicePolicy` 从原卡读取左选费用和丹药 ID，右选允许带有因果种子的原选择；`Domain._choose_normal` 在一次持久提交里种下右选因果。新增专项从真实丹修路线检查丹方原图、桌面双选、左选失败写盘原字节回滚及购买后严格读档、右选 `pillPoison` 金丹期延时 11 的本次剩余值及严格读档；之后第 23 次决断以自然余额至少 21 灵石抽到 `q_shop`，桌面显示可删目标，实付 15＋6 灵石、删一张牌并严格读档。专项退出 0，输出 `NONCOMBAT_PILL_GHOST_Q_SHOP_JOURNEY_PASS ghost=true recipe=true debt=true shop=true replay=true`。独立初审 REJECTED 指出两处可达 P2：重抽丹方时同 ID 因果种子被拒，福缘封顶且左选买得起时右选错误开放。专项新增重复种子不重置计时/不复制、封顶可购买禁右与无钱保底放右断言，修复前分别退出 1；`MilestoneFlow._plant_seed` 现与网页 `KarmaSystem.plantSeed` 一样接受重复 ID 并在新原始延迟更短时合并，`NormalChoicePolicy.choice_available` 对纯封顶福缘奖励遵守网页保底规则。修正后专项含桌面原图与两项边界退出 0，独立只读复审 VERIFIED，未见本批新增 P1/P2。首次丹方左右分支和自然 `q_shop` 实删的严格读档已证实；**重复种子仅用状态注入验证公开选择行为，自然重抽后的严格读档仍 UNPROVEN**。完整 `python tools/validate_godot_runtime.py` 最终退出 0，汇总 `RUNTIME_MIGRATION_PASS data=74 art=603 audio=32 M0_steps=12 reactions=3 presentation=3 stage_routes=4`。首轮总门禁只在 `noncombat_regulated_replay.gd` 的旧 120 秒进程限时截断，该脚本已打印全通过标记；独立单跑实测 124.85 秒且退出 0，因此仅将此脚本限时调为 180 秒后重跑整套门禁通过，断言未改。后续金丹期因果兑现、丹药突破消费、完整丹修长局及战斗效果仍按各自消费者验收。

### 2026-10-22 N9x-03f 丹修删牌后的来源续卡 Slice Charter（非致死路线已验收）

| Issue | 玩家合同与权威链 | 当前证据及验收 |
| --- | --- | --- |
| ISSUE-N9x-03f | 从 N9x-03e 自然 `q_shop` 实删后的持久状态继续，按网页 `GameLogic → MarketSystem.tick → FlowDirector/CardSystem` 顺序消费已排定的行商和后续卡，不跳事件或改抽签。Godot 的 `Domain.resume_flow → MarketFlow.resume → NormalDrawPolicy` 仍须保持一次决断、原卡内容、正确续卡和严格重放。 | 最近一次真实运行档在决断 24、8 灵石、`FLOW_PENDING`，含原 `bazaar_encounter` 待发卡；来源与 Godot 均在到期时先排市场卡。自然专项已证明离开行商后的 `q_spiritStone → karma_spell_awakening → q_love` 原卡顺序及每个已实现节点的严格读档。下一张 `karma_body_awakening` 仍安全停在未迁选择消费者；不把整条后续链算作完成。 |

**排除路径与门禁**：不跳过行商，不通过提高余额或改 0.55 抽签回避下一张卡；不把战斗画面任务纳入非战斗实现。若下一张是战斗选择，只接带来源 ID 和一次性战果槽位的合同，真实战斗效果由并行战斗任务验收。新增专项须检查原图/桌面入口、写盘失败不改存档字节、待选/已选严格读档，并纳入 Godot 总门禁；完成后由独立只读 Reviewer 反证。下一处阻断点的根因、测试和实现位置待真实入口复现后补入本节。

**首个实际阻断点与来源边界**：延长后的 `noncombat_pill_ghost_q_shop_journey.gd` 已从删牌后的原 `bazaar_encounter` 离开，严格读档后依次结算 `q_spiritStone` 右选和 `karma_spell_awakening` 右选；决断 27 的下一次 `resume_flow()` 修复前退出 1：`selected ordinary card needs an unmigrated choice consumer: q_love`。原 `data/cards/qi.json::q_love` 左选只加道心与修为，右选扣道心/修为并给 `companion: "mortal"`；在本次自然状态左选数值已封顶，右选是唯一可执行方向。网页 `EffectService` 调 `GameStateManager.addResource('companions', 'mortal')` 去重，再调用 `CompanionSystem.register`；现行 NPC/道侣来源表没有 `mortal` 定义，注册返回 false，不生成该角色的好感状态、被动或事件。Godot 的 `_simple_choice` 原本拒绝右选，且 `_apply_passive_regen` 对任何非空同伴列表安全停止。本批仅按该来源事实给 `mortal` 唯一持有记录；不伪造 NPC、好感、画像或战斗加成。其它已定义道侣的被动/事件保持未迁边界。

**实施与验收证据**：`NormalChoicePolicy` 仅识别来源 `q_love` 右选的三项效果，在同一候选快照里去重写入 `resources.companions=["mortal"]`，结算道心/修为负数和一轮寿元；无来源定义的 `mortal` 不产生被动，其他同伴仍被现有被动门禁拦住。专项单跑 `noncombat_normal_draw_policy.gd` 退出 0，覆盖左选、右选、重复持有和后续数值卡；自然 `noncombat_pill_ghost_q_shop_journey.gd` 检查原图和按钮、待选读档、失败写盘原字节不变、右选效果及严格读档，退出 0，输出 `... love=true replay=true`，实测 128.06 秒，因此门禁仅为该增长的长路线改为 180 秒。独立只读审查发现道心不高于 2 或寿元只剩 1 时右选曾显示可点而结算因未迁死亡/复活被拒；新增短专项先红退出 1，`choice_available` 改用与结算相同的生效后道心损失及寿元边界判断后退出 0，审查复核 VERIFIED、未见本批新 P1/P2。**致死状态的网页右选及死亡/复活仍未迁；若两侧都不可执行，Godot 安全停止，不宣称 `q_love` 全状态完成。**自然路线再继续会在决断 28 的 `karma_body_awakening` 因未迁消费者安全停止；此为下一独立缺口。总门禁结果见下。

**N9x-03f 总门禁与 Claim-to-Evidence**：完整 `python tools/validate_godot_runtime.py` 退出 0，输出 `RUNTIME_MIGRATION_PASS data=74 art=603 audio=32 M0_steps=12 reactions=3 presentation=3 stage_routes=4`。实现位置 `NormalChoicePolicy.choice_available/settle/_apply_passive_regen`；真实入口 `noncombat_opening_ui → Domain.resume_flow/choose → RunSession`；权威状态 `resources.companions`、道心/修为/寿元、`choiceHistory` 和 `runClock.receipts`；专项 `noncombat_normal_draw_policy.gd` 与 `noncombat_pill_ghost_q_shop_journey.gd` 均退出 0，独立只读复审 VERIFIED。该证据仅覆盖自然非致死路线及短专项边界，后续 `karma_body_awakening`、致死状态和战斗侧同伴数值消费仍为开放缺口。
### 2026-10-22 N9x-03g 丹修自然抽到「因果·金刚霸血」 Slice Charter（本段已验收）

| Issue | 玩家合同与权威链 | 红测、实现边界和门禁 |
| --- | --- | --- |
| ISSUE-N9x-03g | N9x-03f 的自然丹修持久状态在决断 28 由 `Domain.resume_flow → NormalDrawPolicy` 抽到 `data/cards/qi.json::karma_body_awakening`；网页 `CardSystem._drawNormal → GameLogic.makeChoice → EffectService` 允许两侧原选项。左选加 20 修为、气血上限 2 且上限增加时等额回血，再加 2 气血；右选加 15 修为、尝试按唯一 `SkillCardAcquisitionSystem.acquireLegacyCard` 取得 `iron_skin`。 | 修复前 `NormalChoicePolicy._simple_choice` 同时拒绝 `maxHealth` 和 `deckCard`，整卡未能发给玩家。先扩单元与自然专项建立红测，再只对来源卡的已核效果接消费者；体修且未持有时通过现有 `DeckAcquisition.acquire_legacy` 写入牌组和来源记录，丹修流派不匹配或已持有时保留数值结果而不虚构授牌。必须验证原图、两侧可选、左/右数值、牌组路径、失败写盘回滚、待选/已选严格读档，以及下一张真实卡。完整 Godot 门禁和独立只读审查通过后才验收。 |

**来源边界**：`EffectService.previewCardChoices` 把 `maxHealth` 和 `deckCard` 视为有意义效果，故修为已达上限时两侧仍可选；`EffectService` 按来源对象顺序执行 `maxHealth`，其处理器同时给气血加 2，再执行显式 `health +2`，总回血最多 4 且不超过新上限。`iron_skin` 来源 `battle_cards.json` 仅含 `body` 流派标签；网页 `acquireLegacyCard` 在丹修下返回 `path_mismatch`，选择本身仍提交。现有 Godot `DeckAcquisition.acquire_legacy` 已是牌组权威，不能在普通选择政策里直接追加牌组 ID。战斗侧如何消费所得牌仍由战斗边界独立验收。
**实施证据**：修复前短专项 `noncombat_normal_draw_policy.gd` 因原图存在但两侧不可执行而退出 1；网页版实际 `EffectService.apply` 对来源左选输出上限 5→7、受伤气血 1→5、修为 50→70，右选对丹修尝试 `iron_skin` 被流派拒绝但修为续至 85。Godot 改为只接受这张来源卡的两项原效果：左选按来源顺序更新上限及回血，右选统一调用 `DeckAcquisition.acquire_legacy`，仅对流派不符和已持有视为不授牌但保留本次选择数值。短专项修后退出 0，覆盖体修实际取得来源记录、丹修不授牌、重复不复制、两侧可选和受伤回血。自然 `noncombat_pill_ghost_q_shop_journey.gd` 从新局到决断 29 检查原图/按钮、两侧结算、失败写盘原字节不变和严格读档，退出 0，输出 `body=true replay=true`，实测约 150 秒；总门禁对此长专项的超时限单独设为 240 秒，不更改断言。保存状态短程恢复后下一张为来源 `q_fortune`，其选择结算属于既有迁移范围；还未证明它之后的整条路线。完整门禁结果和独立审查结论见下方 N9x-03h 验收记录。

**范围校正**：网页 `CardSystem._cacheKarmaMappings` 会把 `qi.json::karmaCards` 中这张内联 `NORMAL` 卡同时放入普通候选；`drawNormalCard` 排除的是 `KARMA` 类型。因此丹修决断 28 的 `NORMAL_PENDING` 与网页普通池一致，**不是**体修种子兑现。独立只读复核确认此点，N9x-03g 的体修授牌仅短专项在选择政策层验证；从体修序章左选 `causal:body_trial_start` 到期的 P60 因果优先链路另由 N9x-03h 验收。

### 2026-10-22 N9x-03h 体修开局种子到期因果兑现（本段已验收）

| Issue | 来源与自然路径 | 本批验收 |
| --- | --- | --- |
| ISSUE-N9x-03h | `q_start_body` 左选种下 `causal:body_trial_start`；网页 `KarmaSystem.getReadySeeds → CardSystem._drawKarmaCard` 以 P60 读取 `karma_expansion.json` 的映射，再解析 `qi.json` 内联 `karma_body_awakening`，先于普通卡和坊市。Godot 原 `KarmaFlow` 只识别剑修因果，因此体修成熟种子被跳过。 | 自然体修开局、避开首战、章节和白狐任务后，成熟种子在决断 12 先发原图与两侧按钮；右选通过已有牌组权威取得一张 `iron_skin` 并严格读档；左选上限增加与叠加回血；失败写盘保留原字节，待选和两种结果严格读档，种子恰好消耗一次。保留普通池对同 ID 卡的合法准入，不伪造战斗效果。 |

**先红后绿与范围**：新 `noncombat_body_karma_due.gd` 起初从真实体修开局走到决断 12 后因 `KarmaFlow` 未识别成熟种子，退出 1，报 `mature body seed was not given its source priority`。Godot 现按来源 `karma_expansion` 映射核对 `cards:qi` 内联卡及其原图，待选态同时固定映射与 qi 卡源指纹；因果结算重用 N9x-03g 已验证的普通卡效果消费者，再由因果流记录历史、消耗种子并推进钟表。`Domain.restore` 重演该到期路径并核验两份来源；专项注入映射漂移，确认拒绝读档且原字节不变。专项退出 0：`NONCOMBAT_BODY_KARMA_DUE_PASS natural=true deck=true heal=true rollback=true replay=true ui=true`；既有首次/第二次剑修因果和普通卡政策专项均退出 0。独立审查发现网页选择历史保留来源卡 `type=NORMAL`，而首版 Godot 写死 `KARMA`；两分支新增断言先红，改用源卡 `type` 后专项及独立复跑均退出 0，未见本批余留确定 P1/P2。普通抽卡与到期因果都可给出同 ID 的并存关系已由来源和 Godot 代码核对，**尚无同一生命两次出这张卡的混合路径实跑**。最终完整 `python tools/validate_godot_runtime.py` 退出 0，输出 `RUNTIME_MIGRATION_PASS data=74 art=603 audio=32 M0_steps=12 reactions=3 presentation=3 stage_routes=4`；此结果覆盖现有测试，不代表非战斗全量迁移完成。

### 2026-10-22 N9x-03i 第二次天机签发与持久化（本段已验收）

| Issue | 真实来源链路 | 实施和证据 |
| --- | --- | --- |
| ISSUE-N9x-03i | 网页 `HeavensHintSystem._selectRandomHint` 从尚未揭示的 40 个来源索引取下一个，JavaScript 数字 `0` 经 JSON 往返仍等于 `0`。Godot `RunSession` 读回数组中的 `0.0`，旧 `HeavensHintFlow.settle` 用 `Array.has(0)` 检索，重复选中已揭示索引 0。 | 只在索引候选生成处按整数数值比较；保留原随机流、40 条来源诗文、已揭示历史和严格 `_valid` 去重。`noncombat_heavens_hint.gd` 用序列化往返后的首条索引建立红测，修前退出 1，修后第二条选索引 1 且结构校验通过。真实丹修长局延伸到决断 32，第二次签发 `heavens_hint:slot_3:life:0:32:1`，待选/已选严格读档与失败写盘原字节回滚退出 0。 |

**阻断现场与范围**：从 N9x-03g 的自然丹修存档续行，决断 29 `q_fortune`、30 `market_encounter`、31 命盘与 `q_pillRecipe` 左选后，决断 32 的下一张普通卡已可抽到 `q_shop`，但 `_persist_snapshot → HeavensHintFlow.settle → _valid` 因重复索引拒绝写盘，`flow_failure_reason()` 为空；这不是卡池或境界里程碑失败。修复后同一分支先发优先级更高的第二次天机，再由来源队列继续到集市。临时探查副本在下一次未迁致死 `q_love` 消费者前走到决断 54；探查采用自动选项，不代表其间各卡内容全部验收。临时探查脚本已移除。此段没有修改战斗场景或素材。独立只读复核对照 `HeavensHintSystem.js` 的 `includes` 语义和 Godot 整数去重，单跑短专项退出 0，未见确定 P1/P2；40 条全部揭示后的循环尚未实测。首次完整门禁在涟漪缺图注入断言处退出 1，单跑该专项退出 0；排除遗留探针 Godot 进程干扰后，第二次完整 `python tools/validate_godot_runtime.py` 退出 0，输出 `RUNTIME_MIGRATION_PASS data=74 art=603 audio=32 M0_steps=12 reactions=3 presentation=3 stage_routes=4`。没有因首次失败放宽断言。

**下一阻断点 N9x-03j 来源复核（未实施）**：临时探查存档到决断 54 时气血 1、道心 1、道心上限 1、寿元 69、无装备法宝。新增可重复的网页版来源测试 `tools/capture_noncombat_q_love_death_browser.js`，在同样数值和决断时钟下退出 0，输出 `BROWSER_Q_LOVE_DEATH_PASS`：`q_love` 左项两项正收益封顶不可选；右项可选并在决断 55 把道心 1→0、修为 100→95、寿元 69→68，同时持有 `mortal`，签发原图 `death_dao_collapse`，`lifePhase=DYING_NARRATIVE`；选择死因卡左项后进入第 1 世后的 `rebirth_boon`，`LEGACY_CHOICE`、待选新流派，累计道心开局加成 1、长寿回合跨世灵石加成 7。Godot 当前为缺失死亡/复活消费者而禁用右项，避免只扣数值却跳过死亡卡。下一批须实现来源结算、一次性决定与 P100 死因卡的原子持久化、原图和双选、失败写盘回滚，再验收死因卡选择、跨世遗产、全生命状态复位与新世 `rebirth_boon`。`MilestoneFlow`、QuestFlow、KarmaFlow、MentorFlow 等尚写死 `:life:0`/首世 scope，不能仅开放本卡选择就声称转世可玩。该浏览器测试用了来源形状的数值/时钟注入来固定边界，未冒充完整从开局到决断 55 的网页版自然随机轨迹。

**复现材料**：保留 Godot 丹修长局的自动探查快照 `godot/tests/fixtures/pill_decision54_death_probe_v2.json`（原 RunSession v2、slot_3、revision 51、`FLOW_PENDING`、decisionIndex 54、51,540 字节、SHA-256 `2F22FD11BA9ECF2FCDC0540A42FE8DEE469F6945DF552AE49D007B5A82FC3FA2`）。探查使用固定普通抽签 0.55、集市/命盘抽签 0.0、涟漪抽签 0.999 和天机抽签 0.0；严格重演须使用同一环境控制。它由临时探查按自动选项走到边界，**不是默认随机参数下的自然路线**，也不代表网页版自然轨迹或其间所有选择已逐项验收；正式测试复制到独立 `user://tests/` 槽位，不能覆盖玩家存档。

### 2026-10-22 N9x-03j-a 跨世存档提交合同 Slice Charter（存储层已验收，死亡/转世尚未可玩）

| Issue | 玩家合同与权威链 | 根因、范围和验收 |
| --- | --- | --- |
| ISSUE-N9x-03j-a | 来源 `GameLogic._reincarnate → GameStateManager.reset(true)/prepareReincarnationHandoff` 将一世死亡叙事结算为下一世 `rebirth_boon`，`lifeId` 加一、决断时钟归零；Godot 唯一写盘权威 `Domain → RunSession.commit_snapshot` 必须允许这一合法边界，并仍拒绝普通命令跨世。 | 当前 `RunSession.commit_snapshot` 无条件要求 `lifeId` 不变且 `decisionIndex` 不下降，任何真正转世都会报 `RUN_IDENTITY_CHANGED`。本批只建立显式 `commit_life_transition`：从已提交的死亡待选卡，验证下一世 ID、零时钟、源/目标卡、一次性边界账本和原子写盘；普通提交仍拒绝跨世。先建立修前失败专项，再验成功、伪造/重复/跨槽/写盘失败原字节保留与重启读回，并纳入总门禁。此合同本身不开放 `q_love` 致死选项、不声明已迁死亡叙事、转世遗产或多世严格重放；后续 Domain/各首世 flow 接入时必须另立红测与审计。 |

**Evidence Manifest（存储层 VERIFIED）**：来源事实为本节上方浏览器 `BROWSER_Q_LOVE_DEATH_PASS` 及 `src/game.js::_reincarnate`、`src/core/GameStateManager.js::reset`；修前阻断为 `godot/scripts/noncombat_run_session.gd::commit_snapshot` 的 `RUN_IDENTITY_CHANGED`。基线 `noncombat_run_session.gd` 退出 0；新增 `noncombat_life_transition_store.gd` 修前因无跨世入口退出 1，修后退出 0，覆盖成功、重启读回、普通提交拒绝换世、前世快照/世代跳跃/跨槽/错误选向结构拒绝、重复拒绝、失败写盘保留原字节与新世内普通提交；既有 `noncombat_run_session.gd` 和 `noncombat_save_slots.gd` 退出 0。完整 `python tools/validate_godot_runtime.py` 退出 0，输出 `RUNTIME_MIGRATION_PASS data=74 art=603 audio=32 M0_steps=12 reactions=3 presentation=3 stage_routes=4`。独立只读审查及跨槽补测后的复核均 VERIFIED，未见本批玩家可达 P1/P2。RunSession 只能校验结构与归档一致性，无法自行证明旧死亡待选态由来源选择真实产生；该真实性和旧 v1 档的跨世恢复、新世完整 reset 仍属于 Domain 后续验收，不能声称已经落地。

### 2026-10-22 N9x-03j-b 丹修致死「情劫」到新世抉择 Slice Charter（阶段二专项通过；总门禁与独审进行中）

| Issue | 来源与玩家合同 | 根因、边界和验收 |
| --- | --- | --- |
| ISSUE-N9x-03j-b | 自真实 Godot 丹修决断 54 存档，下一张 `q_love` 右选按网页 `GameLogic.makeChoice → EffectService → GameStateManager.checkDeath → FlowDirector P100` 扣道心/修为/寿元、只登记 `mortal`，发原图 `death_dao_collapse`；其两项只写跨世奖励。`_reincarnate` 以单次持久事务将新世 `lifeId` 加一、重置决断时钟与当世状态、保存前世因果和奖励，展示来源 `rebirth_boon` 并要求重新择道；选道后仍保持该卡待决。 | Godot `NormalChoicePolicy` 拒绝致死右选；`Domain` 没有死亡卡、转世或多世严格重放消费者，且多处 flow 使用首世 scope。红测应从保留 v2 探查存档复制到独立测试槽，检查 `q_love` 原卡、致死决定与死因卡/原图、两次严格重启、错误令牌与写盘失败回滚、前世归档和新世奖励、重新择道后的原 `rebirth_boon`。不得只开放按钮就跳过死亡卡；也不得把上一世任务、道侣、鬼债、商店货单、战斗请求带进新世。战斗系统保持隔离。 |

**本批证据状态**：阶段一致死决定与死亡卡已验收；阶段二已打通死亡卡选择、轮回、择道和新世待选卡，专项与独立反证通过；最终完整门禁正在重跑。来源浏览器样本在 N9x-03j 来源复核；此次从 Godot 探查存档复现，不能把网页数值注入冒充自然全流程。

**阶段一：致死决定与死亡卡**：`noncombat_death_rebirth_journey.gd` 修前在决断 54 的来源 `q_love` 抽卡处红测失败，原因是两项选择被旧安全策略同时禁用；解除致死右项并接上死亡消费者后，测试推进到「死亡卡左选尚不能轮回」，说明致死决定已被实际消费。`noncombat_death_card_journey.gd` 从相同原 RunSession v2 快照严格恢复并发卡，验证死亡右选把道心 1→0、修为 100→95、寿元 69→68、同伴仍只一份 `mortal`，决定索引 54→55；死亡原因、原 `death.json` 卡文和原图来自 `ContentRepository`，可严格重启。写盘失败不改内存与活动存档原字节，旧令牌不能再次消费。该测试覆盖**固定抽签控制下的 Godot 探查路线**，不证明默认随机参数下从首局自然到达。独立只读审查复跑专项退出 0，结论 VERIFIED，未见本阶段可达路径确定的 P1/P2；同时指出有装备法宝时网页只对带 `revive` 属性的法宝拦截死亡，而本阶段一律拒绝致死选择，待装备/高境界来源消费者实现时要补此边界。完整门禁结果见本节后续记录。

**下一关仍未完成**：`DEATH_PENDING` 当前能展示原卡，但 `issue_choice_token()` 不开放死亡卡按钮；`RunSession.commit_life_transition` 的跨世事务虽已验证，`Domain` 尚未调用。后续须实现死亡卡左/右来源奖励、全生命周期复位、前世归档校验、新世 `rebirth_boon`、重新择道和多世严格读档；当前这条玩家路线在死亡卡处停住，不能作为可玩轮回验收。

**阶段一门禁与 Claim-to-Evidence**：网页来源测试 `node tools/capture_noncombat_q_love_death_browser.js` 在本地测试服务器上退出 0，输出 `BROWSER_Q_LOVE_DEATH_PASS`；Godot 短专项 `noncombat_normal_draw_policy.gd` 退出 0，死亡长专项 `noncombat_death_card_journey.gd` 退出 0，输出 `fatal=true art=true replay=true rollback=true stale=true`。首次完整 `python tools/validate_godot_runtime.py` 的所有前置检查通过，仅在新增死亡专项被旧 20 秒进程限时截断；按单跑实测把该专项归入 60 秒长路线后，单独执行验证器清单中从它到末项的所有 14 项，逐项退出 0、标记齐全，输出 `TAIL_GATE_ALL_PASS`。这组证据**合起来覆盖完整清单，但并非同一次验证器进程打印 `RUNTIME_MIGRATION_PASS`**；没有把超时写成断言通过。独立只读审查单跑死亡专项并检查来源规则、原图、事务与严格读档，结论 VERIFIED、未见本阶段可达路径确定的 P1/P2。完整轮回红测仍停在死亡卡选择处，保留作下一阶段实施基线。

**阶段二实施边界与修前红测**：同一 `noncombat_death_rebirth_journey.gd` 从原决断 54 快照重放到 `DEATH_PENDING`，修前退出 1，报 `authored death-card legacy choice did not reincarnate`。本阶段只接 `death_dao_collapse` 的来源两选、新世未择道与已择道的 `rebirth_boon` 待决态；其它死因、复活法宝及恩赐卡后续消费不能借此冒充完成。前世终态由 `lifeJournal` 归档，恢复时须重演前世选择并与归档相等，再按死亡卡方向和来源初始值重建新世快照，不接受只凭存档字段自称「已转世」。死亡卡到新世必须调用专门的跨世提交；择道沿同世提交且不能增加决定索引。新世各来源队列必须用新 `lifeId` 重新初始化，不许继承前世的市场、债务、任务、道侣、天机和牌组运行态。验收覆盖两选奖励、失败写盘原字节回滚、严格重启、伪造前世终态拒绝和桌面择道入口。

**阶段二实施与当前证据**：`Domain._choose_death` 读取来源死亡卡，调用 `RebirthFlow.new_life` 构建候选并经 `RunSession.commit_life_transition` 原子提交；`Domain._restore_rebirth` 从 `lifeJournal` 取前世终态，以来源内容严格重演后重新推导新世，逐字段比较才接受。未择道时 `lifePhase=LEGACY_CHOICE`；桌面路径按钮沿同世 `commit_snapshot` 赋予来源起始牌组和路径加成，依据网页 `beginFreshSession` 切为 `ALIVE`，仍显示来源 `rebirth_boon` 原图。残卷档案与其来源/RNG 游标、已有知识和线索身份跨世保留，线索重置为来源 `legacy`/第 0 回合/新世 ID；本世残卷运行态归零；旧市场、债务、任务、NPC 世界态、道侣和牌组运行态不继承。新增回归先在死亡卡左选失败，再在残卷游标/生命阶段与知识/线索继承断言失败，修复后 `NONCOMBAT_DEATH_REBIRTH_JOURNEY_PASS` 退出 0；覆盖两选来源奖励的各自写盘与严格重启、死亡与轮回写盘失败原字节回滚、未择道/已择道严格重启、伪造前世终态拒绝和真实桌面路径按钮。独立只读反证复跑更新专项退出 0，结论 **VERIFIED**，未见本阶段确定 P1/P2。知识/线索用严格恢复的终态加上来源形状的已获进度投影测试；未走完剑/法避战→`q_love` 的自然长路线。该探查夹具必须注入固定环境抽签后才能严格重演，桌面按钮是在已严格恢复的 Domain 上测试；**不代表原夹具可作为默认随机参数的玩家槽位直接打开**。`rebirth_boon` 三选、跨世后的正常抽卡/来源队列完整初始化、旧 v1 档跨世恢复及其它死亡原因仍未验收；不能宣称完整轮回可玩。

**阶段二来源与总门禁进度**：扩展后的 `node tools/capture_noncombat_q_love_death_browser.js` 在本地静态服务器上退出 0，输出 `BROWSER_Q_LOVE_DEATH_PASS`；它以来源状态注入核对死亡→未择道→调用 `ui.startGame('body')` 后的知识/线索、`ALIVE` 和恩赐卡，不把该调用当作浏览器 DOM 路径按钮实点。独立只读审查复核脚本快照时点正确。首次完整 `python tools/validate_godot_runtime.py` 执行到本专项时，正值新增知识/线索红测，按预期退出 1：`earned knowledge and clue identity were lost across life reset`。修复后本专项及独立复跑退出 0；最终代码的完整验证器正在重跑，未取得汇总标记前不计作总门禁通过。下一批需单独核验网页版 `recordLegacy` 的势力声望衰减、完成支线标记及 NPC 好感继承：本阶段的丹修夹具没有可结算的 `factionProgress`，不得把知识/线索的通过扩大成全部跨世遗产通过。

**右选专项断言纠偏**：新增右支独立写盘/重启检查初次假阴性：奖励字典允许省略值为零的 `daoHeart`，测试误用默认 `-1`；重启后的 JSON 数字类型也不能直接与内存字典逐项按类型比较。现仍断言来源修为 +10、遗产灵石 +7、独立活动槽位、重启成功及规范化后的全状态等值，没有取消右支或放宽来源数值；独立复跑通过。

**进程限时纠偏**：最终代码的第二轮完整门禁已完成此前所有用例，却在新增轮回长专项的 120 秒进程上限截断，没有业务断言输出。未改动测试内容的独立复跑退出 0、标记齐全，实测 167.38 秒；因此仅将该项上限调为 240 秒，第三轮完整门禁正在执行。不能把先前超时记作通过。

### N9x-03j-c｜跨世阵营声望与已完成支线（实现已过专项；总门禁进行中）

| Issue | 来源与玩家合同 | 根因与验收 |
| --- | --- | --- |
| ISSUE-N9x-03j-c | 网页 `GameStateManager.recordLegacy` 在死亡归档时把每个势力的当世声望按 60% 四舍五入，正值与旧遗产取峰值、负值取谷值；真值且以 `Completed` 结尾的任务标记永久加入遗产。`FactionSystem._resetForNewLife` 先以非零遗产声望或来源初值初始化；`GameLogic._reincarnate` 随后还额外加上遗产声望的 30% 四舍五入值。`GameStateManager.reset` 从跨世 unlocks 还原 flags，并由 `QuestSystem._onReset` 把孤立 `quest_*_active=true` 标记置为 false；当前任务运行态归零。 | Godot `RebirthFlow.new_life` 此前丢失阵营、已完成任务及应留 flags。现以来源终态重建两类遗产与新世阵营初值，恢复应保留的 flags，清掉跨世临时标记并重置孤立任务激活标记；仍使用跨世原子提交和严格重演。专项覆盖正负声望、多世峰谷、白狐完成标记、假值不误记、写盘失败回滚和旧轮回快照兼容。完整玩家链及失败/放弃任务的关闭记录留待第二世任务流接通。 |

**入口→状态→消费者**：死亡卡选择 `Domain._choose_death → RebirthFlow.new_life → RunSession.commit_life_transition`；旧世权威由 `lifeJournal` 的来源严格重演保证；新世阵营消费者为 `QuestFlow._settle_third_reward`、鬼市/官坊目录和商路状态。此批只承接 Godot 已有可生产的阵营声望及任务完成标记；NPC 好感虽在网页 `recordLegacy` 中跨世保留，但 Godot 尚无对等可结算的好感生产者，另列后批。前世当世 `factionProgress` 不直接拷贝为新世进度，跨世可见 flags 按来源重置。网页版 `QuestSystem._onReset` 保留 `closedQuests`/`questOutcomes` 却清活动任务；Godot 当前丢弃 `questState`，故前世失败/放弃任务在第二世可能错误重触发，接通第二世任务前必须迁移并验收。继承声望的新世首次打开鬼市/官坊前，也须验证商路初始快照已生成且目录不会将继承声望误判为未回放。当世正常任务消费和商店消费尚不可达，不将专项数值投影算作完整玩家链。

**证据与边界（2026-10-23）**：`noncombat_rebirth_legacy.gd` 在修复前先因跨世声望/完成标记失败，再因孤立任务激活标记失败；修复后输出 `NONCOMBAT_REBIRTH_LEGACY_PASS faction=true quest=true peak=true rollback=true restart=true`。`capture_noncombat_q_love_death_browser.js` 注入同源终态并输出 `BROWSER_Q_LOVE_DEATH_PASS`，确认声望 12/-11 遗产、16/-14 新世声望、完成真值与 `quest_*_active=false`。独立只读审查复跑专项退出 0，未见本批计算/投影的确定 P1/P2。测试从真实 Godot 白狐第三卡路由取得任务候选，但通过私有 `QuestFlow.settle` 注入支付余额、再手工构建死亡终态；重启核验使用 `RunSession.load_snapshot`，未在该专项走 `Domain.restore`。因此本批只证明来源数值与状态投影、原子提交；**没有证明白狐自然完成→自然死亡→第二世可玩**。完整 Godot 门禁现重跑，须有汇总标记后才能记通过。

### N9x-03j-d｜轮回恩赐三选与第二世恢复（专项与独立审查通过；总门禁待完成）

**网页样本已取**：`node tools/capture_noncombat_rebirth_boon_browser.js` 输出 `BROWSER_REBIRTH_BOON_PASS samples=4`。经死亡卡左选、重新择道、资助费用后的第一张卡 `rebirth_boon`：剑修左选扣 10 善缘并取得 `sword_intent`；体修左选也扣 10 善缘，但 `SkillCardAcquisitionSystem.validateCardForPath` 拒绝剑修牌，实际无牌；右选扣 20 灵石并取得一件 `避尘珠`；下选按气血上限回血并弹出通用删牌 UI。每个有效决断的 `decisionIndex` 0→1，下一卡由来源导演抽取。来源卡“免费遗忘两张基础防御牌”的描述与实际 UI 的“可付费删除任意一张”不一致，不能把两者混称为已实现。

**实现与验收顺序**：先把 `REBIRTH_PENDING` 已择道卡纳入令牌/选择入口，按来源 `costCheck` 处理消耗，复用 Godot 唯一牌组权威和法宝实例权威，并让下选后牌组目标入口明确展示实际消耗。体修等非剑流派左选应在提交前拒绝并保留原存档字节，避免照搬网页“扣费无奖励”的缺陷；这是显式的产品纠错，原卡内容与原素材仍保留。三选均须记录一次性来源决断、来源卡图和候选效果，失败提交不得泄漏余额/法宝/技能牌。随后从经严格恢复的死亡卡跨世、择道、恩赐卡选择及再重启验证；仅落入 `FLOW_PENDING` 而无法推进第二世卡流仍不算玩家链完成。先红测再实现，每轮用源浏览器样本、专项、受影响集成和最终总门禁核对。

**当前落地证据（2026-10-23）**：新 `noncombat_rebirth_boon.gd` 先报 `rebirth boon settlement missing`，后输出 `NONCOMBAT_REBIRTH_BOON_PASS`；核验剑修付 10 善缘取 `sword_intent`、非剑修左选提交前拒绝、付 20 灵石取带来源回执的 `避尘珠`、下选回血并打开按原版实际规则收费的一张牌目标、两种余额不足拒绝。`Domain.choose` 使用现有候选写盘与一次性令牌。长路线 `noncombat_death_rebirth_journey.gd` 从严读首世决断 54 到死亡卡、跨世、桌面重择道，再执行恩赐下选写盘失败原字节回滚、成功写入、目标取消、两次严格重启，以及第二世首张原普通卡签发与选择后严格重启，输出 `NONCOMBAT_DEATH_REBIRTH_JOURNEY_PASS`。严格恢复使用前世来源归档、恩赐来源及完整 `replayHistory` 重演；首世旧版 pending 快照保持版本 0 回放。第二世 `noncombatFlow` 独立建新世范围，鬼市/商路游标在首个新世决定初始化。当前只对已可重放的第二世普通卡继续提交；新世市场、洞府目标及再次死亡在接通前拒绝写盘。独立只读审查指出：普通池的 `q_shop` 等牌虽非 `NORMAL` 类型，仍以 `NORMAL_PENDING` 流程选择；严格重演原错误类型限制已改为核对阶段与卡 ID，复核后无新的确定性 P1/P2。恩赐左/右的自然存档重启及 `q_shop` 等来源类型的第二世重启仍缺直接回归。任务/因果/导师等来源消费者尚只接受首世 scope，**不能称第二世完整可玩**。原总门禁在新批次修改代码前主动停止，未得汇总标记，不计通过。

### N9x-03j-e｜跨世保留已关闭任务结局（来源样本与专项长测通过；总门禁待完成）

**来源与缺口**：`src/systems/QuestSystem.js` 的 `_onReset` 清除活动任务、待发入口及孤立激活旗标，`_saveActiveQuests` 仍保存 `completedQuests`、`closedQuests`、`questOutcomes`；`GameStateManager._normalizeQuestState` 使用第 3 版任务存档。`node tools/capture_noncombat_rebirth_quest_reset_browser.js` 输出 `BROWSER_REBIRTH_QUEST_RESET_PASS closed=3 active=0`，实跑证明完成、失败、放弃三种关闭结局均跨 reset 保留。此前 Godot `new_life` 丢弃整个 `questState`，使失败/放弃任务在将来接入第二世调度时可能重触发。

**实现与证据**：新轮回继承版本 2 清空 `activeQuests`，保留三份关闭记录；无前世任务记录时建立空的来源第 3 版记录。继承版本 0/1 继续按原快照重演，避免让新字段破坏已写 Godot 档。`noncombat_rebirth_legacy.gd` 先因缺关闭记录退出 1，修复后输出 `NONCOMBAT_REBIRTH_LEGACY_PASS`；它覆盖完成/失败/放弃、声望与旧 v0/v1 投影。`noncombat_death_rebirth_journey.gd` 从前世真实失败白狐存档走到第二世，严格重启并核验失败关闭记录，同时另写一份旧 v1 新生命快照确认仍可严格读回，输出 `NONCOMBAT_DEATH_REBIRTH_JOURNEY_PASS`。`noncombat_rebirth_boon.gd` 再跑退出 0。第二世任务入口/续卡尚未开放，不能把持久化记录等同于整条任务在第二世可玩。完整 `validate_godot_runtime.py` 已跑过此前各项，进入 `noncombat_death_rebirth_journey.gd` 后因其原 240 秒工具时限退出 1；同一长测单独运行退出 0，未报告功能断言。工具时限已按该事实调至 420 秒；本批及下一批合并重新跑完整门禁前，不记总门禁通过。

### N9x-03j-f｜第二世炼气首张章节卡与跨世因果身份（专项与真实长测通过；总门禁待完成）

**来源轨迹**：`tools/capture_noncombat_q_love_death_browser.js` 实跑确认前世死亡选择后章节记录暂留，而重新择道后 `chapterSystem.triggeredMilestones.qi` 清零；来源 `shouldTriggerMilestone('qi', 15)` 给出阈值 15 与 `ch_qi_20`。网页 `NarrativeLedger._factInstanceId` 以当世生命序号形成 `fact:<lifeCount>:<factTypeId>`，`KarmaSystem.plantSeed` 记 `originLife`。Godot 固定长测中，第二世第一张普通卡 `q_fortune` 左选给修为 +15，形成真实可达入口。原版体修章节变体图为 `assets/cards/events/scene_qi_q_bodyTrial.png`。

**实现与证据**：`MilestoneFlow.resume` 现接纳新世 `rebirth_new_life` 流程；章节选择的生命 ID 校验、种子 `originLife`、事实 ID 与 `lifeCount` 均取当前世，不再写死首世 0。首世无显式 `lifeCount` 的旧投影按 0 保持兼容。第二世 `Domain.resume_flow` 放行章节待选，严格恢复入口承认 `MILESTONE_PENDING`，跨世完整决断日志可交替重演普通卡与章节卡；记录的普通抽签仍由来源种子和保存的回执逐张核验。`noncombat_rebirth_boon.gd` 先因新世阈值 15 无章节卡退出 1，修复后通过；`noncombat_milestone_flow.gd` 与 `noncombat_third_milestone.gd` 首世回归通过。扩展的 `noncombat_death_rebirth_journey.gd` 从前世真实死亡、恩赐下选、新世 `q_fortune` 左选到 `ch_qi_20`，验证体修原图可加载、待选严格重启、章节写盘失败原字节回滚、已选事实 `fact:1:qi_main_call` 和种子 `originLife=1`、已选严格重启，输出 `NONCOMBAT_DEATH_REBIRTH_JOURNEY_PASS ... chapter=true`。轮回恩赐、旧版轮回档及桌面 UI 专项复跑通过。**下一缺口**：新世成熟因果、未关闭白狐任务与导师等优先级仍未消费；当前章节卡链只证明首个阈值及其存档，不能外推为第二世全链可玩。完整总门禁待本轮后续批次合并运行。

### N9x-03j-g｜第二世体修因果兑现与集市打断（专项、真实长测及总门禁通过）

**来源与实现**：`cards:karma` 的 `causal:qi_body_stance/burden` 分别映射 `k_chapter_body_left/right`；`cards:karma_expansion` 的 `causal:hoarded_manual` 映射 `kx_ch_hoarded_manual`。三卡保留原文、动态章节占位符、原 `sceneImage`、左右效果与来源 SHA；结算按当世 `lifeId` 写一次性决定、递减因果时钟并移除已兑现种子。第二世恢复入口及完整决断重演已承认 `KARMA_PENDING`。同一条自然路线在体修因果成熟前先到公开集市，因此只接通已可重演的 `MARKET_PENDING` 及“继续赶路”分支，严格恢复同时纳入集市待选/跳过；第二世入摊交易左选在界面与提交入口均禁止，避免未验证交易日志进入跨世档。

**证据与下一缺口**：`noncombat_rebirth_body_karma.gd` 覆盖体修章节左右种子、两张因果卡、独吞功法来源图和善恶旗标；`noncombat_death_rebirth_journey.gd` 从真实首世死亡沿第二世普通卡、四张炼气章节卡、集市跳过、体修因果及独吞功法自然推进，逐段检查待选/结算严格重启和因果写盘失败原字节回滚，输出 `NONCOMBAT_DEATH_REBIRTH_JOURNEY_PASS ... karma=true manual=true`。`noncombat_rebirth_boon.gd`、首世 `noncombat_second_karma.gd`、`noncombat_bazaar_vendor.gd` 回归均退出 0。完整 `python tools/validate_godot_runtime.py` 合并门禁输出 `RUNTIME_MIGRATION_PASS data=74 art=603 audio=32 M0_steps=12 reactions=3 presentation=3 stage_routes=4`。首次门禁在首世回响缺图负例失败，该专项单独复跑通过；测试临时存档改为进程号加计时并补诊断后，完整门禁重跑通过。第二世集市入摊、仍活跃的任务与导师、后续不同流派/境界因果、再次死亡和旧网页版存档导入仍未完成；不能把这条体修路线推广为全剧情可玩。

### N9x-03j-h｜第二世公开集市入摊与交易重放（真实分叉长测及总门禁通过）

**实现**：`Domain._restore_rebirth` 在第二世承认 `VENDOR_OPEN`/`VENDOR_RESULT_PENDING`，对 `replayHistory` 中的公开集市左选按来源开摊、重演同一会话的行动与购买事件、关摊，再重演结果卡右选；待结算摊位在主决断日志之外重演交易事件，并以完整状态相等拒绝伪造存档。新世公开集市左选已开放；鬼市仍只允许右选，避免未迁的鬼市货单/交易链进入无法恢复的状态。

**证据与边界**：扩展的 `noncombat_death_rebirth_journey.gd` 从真实第二世决定 8 的公开集市待选态复制独立测试槽，一支问摊主、购买 `bazaar_han_healing`、关摊、确认结果卡；入摊、问讯、购买、结果和结束后逐段严格重启，购买写盘失败时核对内存与存档原字节后再重试。原槽继续走集市跳过→体修因果→独吞功法，最终输出 `NONCOMBAT_DEATH_REBIRTH_JOURNEY_PASS ... vendor=true`。原有来源商品目录、价格与效果未复制或改写。首世 `noncombat_bazaar_vendor.gd`、鬼市 `noncombat_ghost_entry.gd`、轮回遗产与体修因果专项退出 0；合并 `python tools/validate_godot_runtime.py` 输出 `RUNTIME_MIGRATION_PASS data=74 art=603 audio=32 M0_steps=12 reactions=3 presentation=3 stage_routes=4`。该证据只覆盖公开集市的一次行动与一笔购买；鬼市入场、其他商品/换物顺序、第二世任务和导师及后续剧情仍待迁。

### N9x-03j-i｜第二世未关闭白狐任务与当世人物身份（专项、旧版轮回自然长测及总门禁通过）

**实现**：`QuestFlow.resume` 允许 `rebirth_new_life`，但仍按原章节阈值、任务触发、已关闭记录和场景图资格仲裁。任务入口保留前世已完成/关闭结局，并创建当前生命编号的白狐人物登记；拒绝时人物死亡转换检查相同生命编号。三张原任务卡的决定回执、任务失败/完成/放弃和完成因果种子均写当前 `lifeId/originLife`，不再固定为首世 0。`Domain.restore` 对第二世 `QUEST_PENDING` 使用完整来源重演，并核对待选与结算后的全状态。

**证据与限制**：`noncombat_rebirth_quest.gd` 用新版轮回继承的未关闭任务状态检查入口、人物 `lifeId=1`、原卡拒绝/救助/完成/放弃、保留另一条已关闭任务及完成种子 `originLife=1`。扩展的 `noncombat_death_rebirth_journey.gd` 从真实首世死亡归档建立兼容版 v1 新生命存档，体修按原普通卡和章节卡自然走到 `q_whiteFox_quest`，分槽验证待选、写盘失败回滚、拒绝后白狐死亡/任务失败，以及救助后放弃，两份结局均严格重开，输出 `... quest=true`；同测的新版 v2 存档保留前世白狐失败结局，不会错误重触发。首世白狐入口、前两选、第三选及轮回遗产专项均退出 0。自然入口证据来自旧 v1 无前世关闭记录的存档；新版 v2 的“首世尚未触发白狐便死亡→第二世自然触发”玩家路线、第二世付费完成后的长局严格重开、战斗胜利完成分支仍待补，不能写成白狐全分支跨世已验收。本批完整 `python tools/validate_godot_runtime.py` 已重跑通过，输出 `RUNTIME_MIGRATION_PASS data=74 art=603 audio=32 M0_steps=12 reactions=3 presentation=3 stage_routes=4`。

### N9x-03j-j｜第二世白刃导师阶段、回应与跨世重置（专项、真实长测及总门禁通过）

**来源与修复**：网页版 `StoryNetworkSystem.resetForNewLife` 清空并重新登记当世师徒状态；导师事件来源为 `data/companions/arcs.json`，原有立绘来自 `data/companions/portrait_stages.json`。Godot 原先仅允许首世 `first_session_avoid` 排出导师卡，结算写死 `life:0`，跨世时同进程 `_mentor_state` 也未归零。现新生命原子提交成功后重置导师运行态；`MentorFlow.resume` 接纳 `rebirth_new_life`，阶段决定回执与承诺 ID 使用当前 `lifeCount/lifeId`。第二世 `MENTOR_PENDING` 和导师回应 `NARRATIVE_RESULT_PENDING` 已纳入严格重演；阶段仍限已迁入的 `INNER_DISCIPLE`、`TRUSTED`，不冒充来源 `HEIR`/`LEGACY` 全部完成。

**验收**：新增 `noncombat_rebirth_mentor.gd` 先因前世导师阶段被保留而失败，修复后输出 `NONCOMBAT_REBIRTH_MENTOR_PASS reset=true stage=true identity=true`，核验重置、原导师卡/立绘、当世回执及跨世承诺不碰撞。真实 `noncombat_death_rebirth_journey.gd` 让第二世体修按来源卡序自然触发 `INNER_DISCIPLE`，对导师待选、选择写盘失败回滚、回应卡待确认及已确认逐段严格重启，之后仍走公开集市、体修与独吞功法因果，输出 `... mentor=true`。接入后来源优先级使体修因果后的下一张变为公开集市，长测据实际调度验证集市跳过后继续兑现因果。首世 `noncombat_mentor_arc.gd`、`noncombat_mentor_trusted.gd` 回归退出 0。当前第二世 `TRUSTED` 的自然长路线、后两阶段和师徒被动仍需独立迁移；本批完整 `python tools/validate_godot_runtime.py` 已重跑通过，输出 `RUNTIME_MIGRATION_PASS data=74 art=603 audio=32 M0_steps=12 reactions=3 presentation=3 stage_routes=4`。

### N9x-03j-k｜第二世白狐付费完成自然分支（真实长测及总门禁通过）

**可达性**：从真实首世死亡档产生的兼容版 v1 第二世槽，原 `q_fortune`、`q_inherit` 和炼气章节按调度自然走到 `q_whiteFox_quest`；`q_inherit` 左选按原卡取得 20 灵石，使白狐第三幕的 20 灵石支付有真实余额，不注入钱。该槽复制为第三个独立分支，依次救狐、收灵草、支付完成。`noncombat_death_rebirth_journey.gd` 检查第三幕支付前的余额、写盘失败时内存与存档原字节不变、同令牌重试成功、完成记录及 `whiteFoxCompleted`、青云剑宗声望 +5、支付与任务奖励相抵后的灵石、`foxGratitude` 因果 `originLife=1` 和完成后严格重启；输出 `... quest_paid=true`。失败、放弃的既有分支仍独立保存并通过。本批填补 N9x-03j-i 所列旧 v1 第二世付费长局缺口；新版 v2 的首世未关闭自然死亡路线与迎战胜利结算仍未验证，不能称全任务跨世完成。完整 `python tools/validate_godot_runtime.py` 已重跑通过，输出 `RUNTIME_MIGRATION_PASS data=74 art=603 audio=32`。

### N9x-03j-l｜旧档转世同进程运行态归零（专项、真实长测及总门禁通过）

**根因**：网页版 `StoryNetworkSystem.resetForNewLife` 与导演重置会替换本世运行态；Godot 冷启动的第二世严格重演创建新 `Domain`，但首世存档在同一进程点死亡卡后，首世的普通抽卡游标、饥饿计数、旧规则回放标记及命盘/市场/涟漪/天机等激活点还留在对象中。此前仅重置了导师状态和两个市场游标，旧档玩家不中断转世可能与重启后的抽卡及阶段规则不同。

**实现与验收**：`Domain._choose_death` 只在跨世原子提交成功后调用 `_reset_new_life_runtime`，清空前世普通抽卡回执缓存、卡数/饥饿、兼容回放模式及旧 RNG 激活点，把当世导师、任务/避战兼容标记、因果事实、官坊、鬼市与商路游标设为冷启动新生命的初始值；来源档案、遗产和新生命状态仍由 `RebirthFlow.new_life` 保留。`noncombat_rebirth_mentor.gd` 先因旧优先级回放标记未清而红，修复后覆盖各类旧标记/游标和新生命来源卡身份，输出 `NONCOMBAT_REBIRTH_MENTOR_PASS`。`noncombat_death_rebirth_journey.gd` 在真实死亡选择后对照同进程与严格重启的普通卡数和饥饿态，再走完第二世白狐三结局、导师、公开集市和两段因果，输出 `... quest_paid=true mentor=true`。两个专项均退出 0；完整 Godot 运行门禁输出 RUNTIME_MIGRATION_PASS data=74 art=603 audio=32 M0_steps=12 reactions=3 presentation=3 stage_routes=4。旧网页版存档导入仍未完成；本批验证的是 Godot 旧格式首世转世边界。

### N9x-03j-m｜第二世天机与鬼市夜契（专项及总门禁通过）

**源端边界**：`HeavensHintSystem.exportState/importState` 以当前 `lifeCount` 标记天机状态，`MarketSystem.tick` 到夜窗发鬼市原货单，`TradeRouteSystem` 在新生命初次核心决定从原始商路开始；前批 Godot 把第二世天机标为第 0 世，并把新生命从决定 1 开始的商路快照当成无法验真的旧档，故鬼市第 18 次决定抽货失败。已把新世天机头写当世 ID、读档与阶段白名单接通；真正由死亡卡进入的新世商路在决定 1 初始化为可信来源快照。此前已写入的第二世 `heavensHintState.lifeCount=0` 用严格重演兼容读取，不能让旧编号污染新存档。首世天机、商路及鬼市规则未改。

**可达性与验收**：`noncombat_rebirth_ghost_journey.gd` 从既有可严读的首世决定 54 存档自然走 `q_love` 致死右选、死亡卡轮回、第二世法修与轮回恩赐，经原普通卡、四张章节卡、导师、公开集市、命盘，到第二世决定 16 的 `heavens_hint:slot_3:life:1:16:0` 和决定 18 的 `market_encounter`；固定的仅是可重放的环境抽签，不增卡或改源权重。待选天机、鬼市待选、鬼市开摊、无购买离摊、结果与确认每步严格重开；开摊写盘失败检查内存与原字节不变。独立夜契分支以真实余额买 `ghost_oath_rusted_sword`，验证 4 灵石与 3 寿元扣除、当世 `fact:1:sword_origin_ghost_oath`、唯一剑实例、债务 ID 带 `life:1`、失败写盘回滚与重试、收入纳戒、带未偿债离摊和逐段严格重启；原槽字节未被分支修改。另在真实第二世待发天机点构造此前 Godot 可能写出的 `lifeCount=0` 兼容快照，验证严格重演、接卡、选择和重开。专项输出 `NONCOMBAT_REBIRTH_GHOST_JOURNEY_PASS hint=true ghost=true oath=true replay=true rollback=true`，已纳入总门禁，完整运行输出 RUNTIME_MIGRATION_PASS data=74 art=603 audio=32 M0_steps=12 reactions=3 presentation=3 stage_routes=4。

**仍缺**：本批没有证明第二世夜契到期催债在后续核心决定中完成、鬼市其它商品/验封的第二世长局、先前商路被标为 `tradeRouteLegacyUnverified=true` 的旧第二世存档能进入新鬼市、再次死亡和旧网页版存档导入；这些不计作完成。

### N9x-03j-n｜旧第二世未验商路快照的鬼市续接（专项、负例及总门禁通过）

**兼容边界**：前批修复之后的新生命会在决定 1 从来源初始化可验证商路；此前 Godot 已写出的第二世档使用相同原始商路和事件回放，却把它标为 `tradeRouteLegacyUnverified=true`，因此能严格读档但鬼市目录拒绝抽货。网页版 `TradeRouteSystem` 在 `state:reset` 时重新加载商路初值。现不改旧档字段或伪造商路变化：只有真实跨世提交，或读档时前世死亡归档与第二世全部选择日志严格重演成功，`Domain` 才给鬼市目录和会话一个仅在当前运行时有效的归档来源信任；目录仍检查商路版本、原配置指纹、路线结构与势力事实。单独调用目录没有该信任，首世未验快照仍拒绝。

**证据**：`noncombat_rebirth_ghost_journey.gd` 在第二世决定 17、鬼市产生前，把真实存档复制为旧字段格式并重新提交校验封套；旧档严格重演后自然选择 `q_shop`、得到决定 18 的鬼市来源货单、开摊并严格重开，原槽字节不变。`noncombat_ghost_arrival_frozen.gd` 的未验首世商路负例仍输出 `... untrusted=true`。更新专项输出 `NONCOMBAT_REBIRTH_GHOST_JOURNEY_PASS ... old_trade=true ...`；包含该分支的全量门禁输出 RUNTIME_MIGRATION_PASS data=74 art=603 audio=32。夜契后续第二世催债、更多鬼市商品与旧网页版存档导入仍待验收。

### N9x-03j-o｜第二世夜契索债两结局（专项及总门禁通过）

**自然链路**：承接 N9x-03j-m 的第二世真实购买夜契残剑且收入纳戒的独立槽，离摊结果确认后，原调度先在决定 19 给公开集市、决定 20 给 `q_inherit`，决定 21 按 `GhostDebtFlow` 到期时钟发 `ghost_debt_due:ghost_debt:vendor:slot_3:life:1:19:market_encounter:ghost_market:ghost_oath_rusted_sword:r1`。此前生产者与首世结算已有，但第二世 `resume_flow` 和严格恢复的阶段列表不含 `GHOST_DEBT_PENDING`，自然续卡安全停止。现只接通该来源阶段和选择日志重演，不改到期时钟、成本或卡文。

**验收**：`noncombat_rebirth_ghost_journey.gd` 从原待发卡严格重开，确认当世债务 ID 和两方向可选；付款支先模拟写盘失败，检查原字节和内存不变，再用原令牌支付 2 灵石，账单变 `SETTLED`、鬼市准入保持开放，`fact:1:sword_origin_ghost_oath` 和唯一消费回执被消费，完成后严格重开。由同一待选档复制的违约支不扣钱，将账单变 `DEFAULTED`、鬼市准入撤销、同一事实消费，完成后严格重开；主槽与分支互不改写。专项输出 `... debt=true ...` 并退出 0；完整 `python tools/validate_godot_runtime.py` 退出 0，输出 `RUNTIME_MIGRATION_PASS data=74 art=603 audio=32 M0_steps=12 reactions=3 presentation=3 stage_routes=4`。此批尚未覆盖第二世其它鬼市商品的普通债、更多生命轮回及旧网页版存档导入。

### N9x-03j-p｜首条炼气故事线程：灵矿争议（专项及总门禁通过）

**网页来源与接线**：`data/threads/qi_threads.json` 的 `spirit_mine` 在 `q_spiritStone` 右选延迟后启动，依次发 `sm_arrival` 和 `sm_consequence`，两节点间保留来源的至少 2 回合间隔。Godot 新增 `noncombat_story_thread_flow.gd`，从原线程 JSON 及已核验的场景图构卡，保存当前世激活点、来源 SHA、已选节点、待选节点与终结回执；`noncombat_domain.gd` 让 `THREAD_PENDING` 进入卡牌读取、令牌选择、严格恢复和决断回放。线程选择继续使用现有原子提交，奖励、丹药、因果种子与 `mine_dispute_resolved` 事实按来源结算；未接的其它线程不以空卡假装完成。旧 Godot 快照从其原有决断点之后启用该线程，不追溯补发先前的触发。

**可玩证据**：`tests/fixtures/spirit_mine_pending_v1.json` 固定在已有自然炼气路线的原 `q_spiritStone` 待选槽。`noncombat_spirit_mine_thread.gd` 自该槽右选后推进两节点，检查原图、首选引起的次节点文案变化、每个待选和结算的严格重开、两节点写盘失败时的原字节与内存回滚、左结局丹药及右结局灵石支出和因果种子；专项输出 `NONCOMBAT_STORY_SPIRIT_MINE_PASS nodes=2 branches=2 replay=true rollback=true`，退出 0。原首世丹修、鬼市、商店长局以显式旧激活点复跑通过，证明既有路线不被新增待选卡悄然改写。

**总门禁与后续**：全量运行门禁首跑在旧鬼市通用货品专项的 60 秒工具时限处退出 1；该专项独跑约 70 秒、输出通过并正常退出，验证器已仅将这一项调至 120 秒。第二跑在因果涟漪的缺图错误分类断言失败；该专项不改生产逻辑连续独跑两次通过，第三次完整门禁也通过，故尚不能把该次偶发失败归因于某一确定根因。第三跑退出 0，输出 `RUNTIME_MIGRATION_PASS data=74 art=603 audio=32 M0_steps=12 reactions=3 presentation=3 stage_routes=4`，包括新增线程、原首世长局、第二世死亡与鬼市长局和既有战斗接口。当前只覆盖首世灵矿线程；其余 11 条线程、跨世线程调度和网页旧档导入仍是缺口。

### N9x-03j-q｜灵矿线程素材失效的恢复与提示（红绿专项及正常两结局回归通过）

**发现与修复**：灵矿线程原图缺失或 SHA 不符时 `_node_card` 已拒绝构卡，但 `THREAD_PENDING` 的严格恢复失败没有把原因传回 `RunSession`，`flow_failure_reason` 也未读取新线程错误。`noncombat_spirit_mine_source.gd` 从原 `q_spiritStone` 待选夹具自然推进到首节点，先以缺图内容仓库复现空错误分类，退出 1。现由线程流记录来源缺失状态，Domain 在待选恢复、历史选择重演、继续出卡、已有令牌的选择及写盘前线程推进失败时传回 `SOURCE_UNAVAILABLE` 或 `SOURCE_MISMATCH`；界面可读取线程错误。失败保持原内存、原存档字节与待选节点，不补发新卡。

**证据与范围**：修复后新专项输出 `NONCOMBAT_STORY_SPIRIT_MINE_SOURCE_PASS missing=true drift=true atomic=true`，退出 0；原两节点、两结局、严格重启与写盘回滚专项复跑输出 `NONCOMBAT_STORY_SPIRIT_MINE_PASS nodes=2 branches=2 replay=true rollback=true`，退出 0。新专项已加入运行验证器，时限 120 秒。本补修之后只重跑上述直接受影响专项；N9x-03j-p 的整套通过发生在该补修之前，不把它表述为补修后的全量复跑。

### N9x-03j-r｜多线程 v2、药谷叛徒与旧档升级（来源核对、自然分支、UI 及兼容专项通过）

**来源规则**：`StoryThreadEngine.js` 的最多 2 条活跃线程、4 回合触发冷却、普通节点至少 2 回合间隔、25 回合超时和待选节点保护进入 v2 调度；当前只开放 `spirit_mine`、`herb_refugee` 两个已实现定义，不能据此宣称全部线程已可玩。`EffectService` 把 `knowledge` 加入 `knowledge.world`；`_mergeThreadCard` 的选项覆盖须合并原效果，不能用变体文字抹掉奖励。`KarmaSystem.plantSeed` 为药谷完成种子保留 `originThread`，不虚构 `originCard` 或 `context`。源端 `node tools/test_f2c_herb_refugee_causality.js` 输出 5/5；补充生产运行时规则采样确认知识 +8、完成种子 `forbidden_pill_secret` 在当前决定结算后 `delay=7`、`originCard=null`、`context=null`。该源端样本手动推进时钟，只作为规则依据；自然可达性由下述 Godot 长局证明。

**实现和存档结构**：`noncombat_story_threads_v2_flow.gd` 使用原线程 JSON 构卡，支持按开始时间/优先级选择节点、同时活跃的独立进度、原条件变体、完成事实与种子。`storyThreadState.version=2` 保存 `threads`、`upgradeIndex`、原 JSON 指纹及线程/因果源码指纹；版本 1 的原 `noncombat_story_thread_flow.gd` 保留为旧档重演路径。Domain 读档不改原字节或待选卡，只在下一次有效决定将旧状态原子升级。升级后按原近期选择历史评估新线程；不丢弃旧档中仍有效的丹方购买条件。初次接入的版本号数组判断曾误拒 JSON 的 `2.0`，现改为数值比较；升级边界、状态和选择仍由完整重演核验。

**自然路线与界面证据**：`herb_refugee_recipe_pending_v1.json` 来自既有首世丹修长局的决定 22、原 `q_pillRecipe` 待选点，未注入灵石或剧情标记。`noncombat_herb_refugee_thread.gd` 先因没有 v2 调度退出 1；接入后从购买丹方推进到逃亡者与追兵，分别验证接受/拒收真方和两种追兵应对，共 4 结局；拒购原丹方分支不会启动药谷线。检查两节点原图、知识 +8、拒收真方后的原描述及右选文字、原效果保留、节点与结局逐次严格重启、完成写盘失败回滚、一次性完成回执、`herb_valley_encounter` 和原延后种子。同一自然路线观察并断言两条线程同时活跃；Godot 桌面场景的图片控件、正文及可选按钮实际消费拒收变体。最终输出 `NONCOMBAT_HERB_REFUGEE_THREAD_PASS branches=4 refusal=true replay=true rollback=true overlap=true ui=true`。

**旧档与回归证据**：`spirit_mine_v1_node_pending.json` 在升级前由真实灵矿路线捕获。`noncombat_story_thread_upgrade.gd` 验证 v1 原字节/原待选卡不变、失败升级回滚、有效选择后 v2 进度及严格重启、伪造未来升级点被拒；另沿原丹方购买产生真实 v1 前缀，先复现升级丢失近期触发条件，修复后验证下一次原商店决定启动药谷线且可严格重开，输出 `... prior_choice=true`。灵矿两结局、素材失效及普通卡运行专项分别输出 `NONCOMBAT_STORY_SPIRIT_MINE_PASS`、`NONCOMBAT_STORY_SPIRIT_MINE_SOURCE_PASS`、`NONCOMBAT_NORMAL_RUNTIME_PASS`。验证器的内容与源码部分单独执行，输出 `CONTENT_AND_SOURCE_GATES_PASS`；新增两专项已注册。本批没有重跑全量长局，最近一次完整 `RUNTIME_MIGRATION_PASS` 仍是 N9x-03j-p，不能外推为本批全量复跑。

**剩余范围与下一接口**：当前只接通两条线程的炼气节点，药谷种子的筑基期 `kx_thread_forbidden_pill` 回响仍未接入 Godot；线程日志、跨世调度和其余 10 条线程也未全部迁移。炼气剩余的荒村/剑冢线程含真实 `triggerCombat`，雾谷要求古洞成功回执；下一批应接通这些非战斗生产者与战斗等待/一次性结果回传合同，再接节点后续，保持战场场景、美术和战斗数值模块的独立边界。
## 2026-10-26 N6 荒村妖道：乞丐赠书 → 四幕战果（单线局部 VERIFIED）

- **来源生产链**：`tools/capture_noncombat_abandoned_village_source.js` 从干净 `sword seed36` 生产 VM 用公开选择在 turn17 遇 `q_beggar.right`；线程延迟 3 决定激活，第 23/27/31/35 回合显示四幕。第三幕同一合法待战档冷恢复后，19 次公开牌局输入获胜、两轮受击败退、一次撤离均推进第四幕；败/逃各有原文及原图，仅胜利完成后种 `exiled_disciple_echo`。`godot/tests/fixtures/abandoned_village_source.json` 保留公开输入、状态、卡片、战场行动及冷恢复差异。浏览器冷恢复时 `startedAtTurn` 会重基、待选卡迁入的战场表现可缺失，来源脚本分别记录可比较的玩法投影与原对象，未把两者混同。
- **Godot 生产者/消费者**：`noncombat_story_threads_v2_flow.gd` 在普通 `q_beggar.right` 的已提交选择后激活第三条炼气线程；前两幕结算知识、道心等作者效果，第三幕按左右方向从 `migrated_presentations.json` 投影战场表现并持有原线程卡。`noncombat_battle_gateway.gd`、`noncombat_encounter_flow.gd` 生成警告及 v2 待战请求；`noncombat_battle_return_flow.gd` 将来源胜败逃效果和 `outcomeContext` 原子写回线程，第四幕按战果选同 ID 的来源变体，完成回执保留四节点且仅胜利种因果。线程来源与战场表现文件均有 SHA 固定；旧两线程 v2 档读时不写，下一决定才添加荒村状态。同步脚本纳入荒村左右战场图、敌人意图和特效 18 张独有素材，现 74 数据/641 图/32 音频。
- **Godot 证据**：`noncombat_abandoned_village_entry.gd` 从自然普通池抽到乞丐卡，验证扣费、延迟、前两幕、第三幕原卡/左预警/待战与右方向独立合同，含中断冷恢复和桌面卡片呈现；`noncombat_abandoned_village_outcomes.gd` 从同一 Godot 待战档分叉胜败逃，验证失败写盘回滚、三种结果卡、第四幕原文原图、完成回执、单次因果；`noncombat_abandoned_village_legacy_upgrade.gd` 验证旧两线程 v2 读取不变及新决定延迟升级。最终三个专项均退出 0；独立进程复核战果专项输出 `NONCOMBAT_ABANDONED_VILLAGE_OUTCOMES_PASS natural=true outcomes=3 fourth_variants=3 replay=true rollback=true`，核对胜利修为封顶时仍显示来源配置的 +10 摘要、三战果文案和媒体、22 张资产 SHA 与 14 处来源 pin，未发现新确定性 P1/P2。同期原 `noncombat_mountain_battle.gd` 六例、白狐战斗八例、`noncombat_story_thread_upgrade.gd` 和 `noncombat_herb_refugee_thread.gd` 已通过；资源覆盖输出 `NONCOMBAT_ASSET_COVERAGE_PASS images=531 animated=3 audio=32 copied=641`。
- **边界**：浏览器自然路径跳过教程，Godot 自然专项含教程与中途普通战，因此两端决定号及战前状态不同；目前证据是来源卡、分支规则和稳定玩家可见结果的对照，非完整逐决定数值同轨。Godot 战场仍未产生真实 terminal 结果；第三幕进入致死心魔或寿尽时，待战档可恢复但死亡结算尚未接入。旧两线程 v2 专项只覆盖第 1 决定的空线程档，未单独覆盖活跃旧线程的冷升级。N6 其他五项任务与其余九条线程、跨世/高境界、Windows 全量出口仍按任务书待完成。

## 2026-10-26 N6 剑冢试炼：残剑入口 → 三幕战斗与传承（合同侧局部 VERIFIED）

- **来源**：`tools/capture_noncombat_sword_tomb_source.js` 从干净剑修 seed26 生产 VM 用公开输入于 turn26 抽到 `q_swordTomb.left`，第 33/37/41 次决定出现三幕。捕获首幕婉拒与接受、第二幕左右×胜败逃、第三幕十二结局及冷恢复；`godot/tests/fixtures/sword_tomb_source.json` 的来源 SHA 固定并通过两次确定性重生。网页 `q_swordTomb.left` 在修为封顶时实际只加业障 5，取得 `brokenSword` 实例与来源回执，种 `swordHonor`（同决定结算后 delay14）。仅第二幕胜利且第三幕左选取得 `剑心古剑`，种 `sword_spirit_memory`（delay7）。
- **已通过的 Godot 专项**：`noncombat_sword_tomb_entry.gd` 从自然普通池抽到原卡，核对残剑唯一实例、来源回执、数值/因果字段、第一幕原卡及接受/婉拒回执、第二幕左右预警/待战与多段严格恢复，退出 0；`noncombat_sword_tomb_outcomes.gd` 从同一合法待战态分叉左右问心×胜败逃六支，逐支检查结果卡媒体与来源文案规则、第三幕胜败逃原文原图、左右十二种完成回执、仅胜利并收剑得古剑/因果、结果失败写盘回滚、重复战果拒绝及冷恢复，输出 `NONCOMBAT_SWORD_TOMB_OUTCOMES_PASS natural=true branches=6 endings=12 replay=true rollback=true` 且退出 0。`noncombat_sword_tomb_legacy_upgrade.gd` 使用旧三线程 v2 档及旧残剑选择，证实读档原字节不变、下一次已提交决定才加入新线程且不追溯触发，退出 0。新增字段后的旧荒村入口、三战果和旧两线程 v2 升级专项、药谷四结局/同时活跃、v1→v2 升级专项均已回归通过。
- **实现与边界**：普通卡左选复用法宝实例账本、作者效果与因果种子；多线程 v2 新增剑冢激活点、婉拒出口和问心战 `outcomeContext`，左右战场媒体已同步到 74 数据/645 图/32 音频。预警保留原选择写入的文字，战场使用迁移表现；战后结果卡还原作者 `combatPresentation`，避免把战场 overlay 的非空媒体 ID 串入网页本为 null 的六张结果卡。独立只读复核发现并确认修复此一 P2，未发现其它确定性 P1/P2；fixture 的 15 个来源 pin 与剑冢 20 个战场资产 SHA 均吻合。目前战果仍由测试合同提交，真实 Godot 战斗场景生产者和致死分支未完成。网页版与 Godot 开局决策号和战前牌组不同，结果卡可选功法及实际伤势数值可能不同，比较依据限定为来源同卡规则与稳定视觉/分支字段。炼气 5 条来源线程中现已接 4 条；雾谷必须先有古洞成功回执，不能仅挂接卡文。

## 2026-10-27 N6 筑基剑道传承入口与非战斗选择（局部 VERIFIED，目标仍在推进）

| Issue | 玩家合同与来源 | 修复前证据 | 生产链与验证 | 状态 |
| --- | --- | --- | --- | --- |
| ISSUE-N6-FOUNDATION-01 | 剑修通过 `ch_qi_100`、领取突破奖励及本命神通后，网页 `FlowDirector` 通过 `QuestSystem` 发 `q_sword_1`；其接受、婉拒、铸心剑、铸铁剑和试炼前离开都必须写入同一任务快照。`data/quests/sword_legacy.json` 为作者卡与效果权威。 | `noncombat_foundation_quest_entry.gd` 从公开筑基路线得到 `bazaar_encounter`，预期来源夹具 `q_sword_1`，退出 1。 | `QuestFlow.resume/_settle_foundation` 按原任务包触发、结算前两幕及放弃；`Domain` 续卡优先级、来源 SHA、选择令牌与严格历史回放接通；`RunSession` 原子提交。入口专项与分支专项均退出 0。分支专项从同一真实待选档分出婉拒、心剑、铁剑，检查修为/道心上限、知识、旗标、任务步数、原图/铁剑描述、冷重开、重复/无战果选择零变化、失败写盘原字节和内存不变。 | 局部 VERIFIED；`q_sword_3` 迎战及 `q_sword_4` 完成奖励未接。 |
| ISSUE-N6-FOUNDATION-02 | `q_sword_3.down` 是原作者可用放弃选择；不能让尚未接入的战斗方向看似可选。 | 独立审计在 `Domain.choose` 找到仅白狐允许 `down` 的白名单，并在桌面 `noncombat_opening_ui.gd` 找到任务阶段未消费 `can_choose_direction`。 | `Domain` 放行剑冢原 `down`，UI 对无有效任务合同的方向禁用并标注；分支专项加载真实 Godot 场景，检查原图/状态文案、左右禁用和下方放弃可用，再结算放弃并严格重开。 | 独立只读审计无剩余确定 P1/P2；局部 VERIFIED。 |

**证据边界**：独立审计复跑 `NONCOMBAT_FOUNDATION_QUEST_ENTRY_PASS` 与 `NONCOMBAT_FOUNDATION_QUEST_CHOICES_PASS`，确认上述局部玩家路径；全量 N6 的六任务/十二线程、筑基其他三流派、白狐跨境界进行态、剑冢战斗胜败逃及终章机缘仍未证明。`godot/` 当前为既有未跟踪工作树，`git diff` 不能给这些文件的提交基线差异来源；行为证据和源码 pin 有效，提交级 provenance 仍为 UNPROVEN。N0–N11 总目标不得因本切片标记完成。



## 2026-11-02 N9 集市声音 Slice Charter + Evidence

**来源与入口**：`AudioManager.js` 在 `shop:open` 读取商会话的 `presentationProfile`，为 `regulated_market`、`public_bazaar`、`ghost_market` 启动三组低通程序环境声；`shop:purchased` 与 `market:vendorAction` 成功后依据 `data/audio/path_identity.json` 播短提示音，`shop:closed` 只停环境声。Godot 的 `Domain` 成功持久提交后发 `VENDOR_PURCHASED`/`VENDOR_ACTION`，剧情页只读 `marketState.activeSession.presentationProfile`，`OpeningAudio` 由独立 `MarketAudio` 播放来源参数生成的循环 PCM 与短音，沿既有 Master 静音偏好，不写玩法存档。商铺界面切出会停环境声，已触发提示音自然播完。

**证据**：`noncombat_market_audio.gd` 从当前作者商家配置与音频目录逐项读取三类 ID，断言循环 PCM 非零、宗门音乐未被替换、未购买不开提示音、交易提示音参数、静音与恢复、关店只停环境声，输出 `NONCOMBAT_MARKET_AUDIO_PASS profiles=3 layered=3 transactions=3 mute=3` 退出 0。`noncombat_bazaar_purchase.gd` 经真实来源决断进入坊市，在剧情页实际购买按钮提交后验证环境声与交易音，再点“返回玉简”验证环境声退出，输出 `NONCOMBAT_BAZAAR_PURCHASE_PASS ... ui=true` 退出 0。`noncombat_bazaar_vendor.gd` 经商贩动作与关店按钮验证交易音和环境声退出。`noncombat_audio_mute.gd`、`noncombat_opening_audio.gd` 均退出 0；专项已纳入总门禁。首轮 UI 测试抓到生成循环未设置 `loop_end` 后会提前停播，现明确设置采样末尾。其余 BGM 场景、全部语义音效和可见 Windows 长局未完成，N9 与 N0–N11 仍 0/12。

**独审修复与补证**：只读审查发现商会话中点击“返回玉简”只停剧情环境声，集市环境声仍会响在槽菜单。把坊市购买专项改走真实槽页并加返回断言，修前退出 1（`returning to the slot menu left bazaar ambience playing`）；`_show_slot_screen` 现在清除商呈现，修后该专项与独审独立重跑退出 0。本切片独审未发现剩余 P0/P1；当前 Godot 文件仍为未跟踪工作树，提交级差异证据 UNPROVEN。N9 整体仍未签收。

## 2026-11-02 高境界体修因果卡门禁纠偏

总门禁通过 `noncombat_foundation_body_natural.gd` 后停在 `noncombat_body_high_realm_karma.gd`：原测试把 `maxHealth=8` 当作网页结算的实际气血上限，期望“接受金刚体”后仍为 8；现行作者 `config:path_skills` 的体修筑基被动给 `maxHp+2`，网页 `GameStateManager.getActualMaxHealth` 合并该值，卡的 `health+2` 从 8 到 10。专项从作者技能模块读取上限加成后核对结算，`NONCOMBAT_BODY_HIGH_REALM_KARMA_PASS golden=true nascent=true once=true effects=true` 退出 0。未改玩法结算；总门禁从后续项继续，N0–N11 仍 0/12。

## 2026-11-02 元婴法修洞天灵石测试纠偏

总门禁在 `noncombat_nascent_items.gd` 的 `n_cave.right` 卡停下：旧测试固定余额 110，当前法修新档元婴阶段已启用作者 `config:path_skills` 的筑基被动“道法自然” `spiritStoneBonus=0.2`。来源 `EffectService` 对正向 10 灵石增量额外加 `floor(10×0.2)=2`，因此余额为 112；Godot `PathSkillFlow.effect_delta` 采用同式。专项按源配置读取比率并保持丹药、城市交易、余额不足断言，`NONCOMBAT_NASCENT_ITEMS_PASS cave=true treasure=true pill=true poor=true` 退出 0；独审独立复跑并核对来源、激活点与消费链，未见 P0/P1。玩法代码未改，门禁从后续项续跑；此合成元婴态不替代自然跨境界路线，N0–N11 仍 0/12。

同一根因的下一专项 `noncombat_nascent_cave.gd` 在进洞左选也把来源 `spiritStone+30` 当作实收 +30；法修功法应加 `floor(30×0.2)=6`。该专项现读取同一作者被动和卡的原始奖励，核对实收 +36，并保留首节点、法宝、因果种子、洞窟成功与放弃断言；`NONCOMBAT_NASCENT_CAVE_PASS nodes=2 rewards=true abandon=true` 退出 0。无玩法代码修改，门禁续跑中。

## 2026-11-02 筑基宗门讨伐战利品断言纠偏

总门禁在自然法修 `f_mission.right` 战胜后报“奖励不同”。加状态诊断后见战前灵石 13、战后 34，实收 +21；旧测试写死 +18。网页版 `DeckCombatSystem` 对敌人攻击 2 给基础 `floor(2×1.5)=3` 灵石，`data/cards/foundation.json` 另给作者 `combatRewards.spiritStone=15`，`EffectService` 受法修筑基 `spiritStoneBonus=0.2` 使这笔作者奖励实收 18。专项现从来源敌人、卡奖励与功法配置计算 3+15+3，仍核对筑基丹、恶缘、修为上限、重复拒绝、写盘失败回滚及三种战果。`FOUNDATION_MISSION_NATURAL_OUTCOME_PASS victory/defeat/flee` 与 `NONCOMBAT_FOUNDATION_MISSION_NATURAL_PASS ... outcomes=3 replay=true rollback=true` 均输出、退出 0。独立只读审查逐来源与 Godot 两段奖励调用确认 +21 期望，无 P0/P1；审查未另跑耗时三分支路线。玩法未改；此处自然路线覆盖宗门讨伐，不代表整个 N6/N8 验收。N0–N11 仍 0/12。

## 2026-11-02 N10 网页中途档第 13–14 决定

**来源与边界**：`artifacts/godot-migration/noncombat-browser-import/mid-source-save-sword-extended.json` 为真实网页版 save10/causal18 剑修序列。第 13 决定 `kx_path_sword_legacy.left` 后可见 `k_chapter_sword_left`，第 14 决定后可见 `kx_ch_hoarded_manual`；第 15 快照无可见卡，仍拒绝导入。来源 `LegacyFragmentSystem.js` 在第 9 决定给 `heaven_book` 保底碎片，第 13 决定另给 `pill_way` 普通掉落；NPC 白刃在第 12 轮行程更新，世界修订号 16→17。

**实现与验证**：导入器在受限、逐卡验证的首世剑修历史上扩至 14 决定，按来源随机数消耗重演两次碎片、因果涟漪和剑修因果卡致死燃血；领域每次选择提交时更新白刃行程和原轮次。第 13/14 档经原始来源字段对照、空槽原子导入、严格冷读，所见卡、时钟、碎片、世界状态与来源吻合。独审先发现来源 `flowState.pendingFlags.market` 未与 Godot 待发集市卡比对，已补全对象对照，并以第 13/14 快照分别篡改集市文案作为拒绝反例。`noncombat_browser_mid_import.gd` 输出 `NONCOMBAT_BROWSER_MID_IMPORT_PASS ... decisions=4-14 ... pity=two-sets ... cold=true atomic=true reject=true`，退出 0、stderr 空；旧四修开局导入专项独立复跑通过。只读独审结论 VERIFIED，无剩余 P0/P1。N10 整项仍缺战中、跨世和更长历史的浏览器档，N0–N11 仍 0/12。

**桌面入口补证**：`noncombat_browser_import_ui.gd` 在原教程档、白狐活跃任务档和战中拒绝之外，另把第 14 决定的真实来源文件交给槽页文件选择回调，核对预览可导入、空槽提交、点选槽进入剧情后显示 `kx_ch_hoarded_manual`、第二套 `pill_way` 碎片及独立暂存的原导出字节。专项输出 `NONCOMBAT_BROWSER_IMPORT_UI_PASS ... chapter_karma=true ... battle_blocked=true`，退出 0、stderr 空。此为 Godot 界面实例与玩家入口事件验证；可见 Windows 桌面手动操作仍待 N9/N11 整体验收。
## 2026-11-02 天机回应与白狐势力来源漂移

**门禁反例**：`noncombat_seer_arc_natural.gd` 公开长局中，回应选择实际 `choose=true` 且事件只记录一次，状态为 `DESTINY_WHEEL_PENDING`。来源 `DestinyWheelSystem.js` 的金丹每 10 次决定命盘会先于下张普通卡展示；Godot 的命盘持久中断与该顺序一致。旧测试仅允许 `FLOW_PENDING`，现同时验合法命盘卡与触发节奏；专项 `NONCOMBAT_SEER_ARC_NATURAL_PASS`、退出 0、stderr 空，独审确认无 P0/P1。

**来源错误归因**：`noncombat_whitefox_third.gd` 注入势力来源 SHA 漂移后，恢复器拒绝了旧档，但先由势力结构验证返回，未设置 `RunSession.last_error`。两条恢复路径现先对有效的势力来源钉子运行共享 `_pinned_source_matches`，再验证结构。专项 `NONCOMBAT_WHITEFOX_THIRD_PASS`、退出 0；独审独立复跑通过，无 P0/P1。完整门禁从第一张因果卡继续，N0–N11 仍 0/12。
## 2026-11-02 宗门深处场景卡自然路线

旧剑修避战固定路线在来源 `q_love.right` 道心归零后进入第二世，后续 200 次选择停留洞府，宗门仅 1 次访问；教学战后 `q_mountain_shadow_approach.right` 也被现行 `first_session_cohesion` 变体串行导向坊市，不能用原卡的“暂返宗门”效果做自然路线证据。这两条失败轨迹均未计完成。

现以既有公开 `_open_third_alt`/`_reach_gate` 入口走炼气百点关胜利、筑基觉醒，来源与 Godot 均回宗门。筑基后选择 `q_sword_1.right` 放弃快进的剑修任务，`ch_foundation_20.right` 放缓修为；其余由同一固定抽签和公开选项驱动。第 61 决定在筑基宗门第 8 次访问自然发出 `loc_sect_deep`，左选得到原 `sect_alchemy_secret`，待选与已选两次磁盘严格冷读全状态一致。`noncombat_scene_layer_natural.gd` 输出 `NONCOMBAT_SCENE_LAYER_NATURAL_PASS visit=8 clue=true disk=true`、退出 0、stderr 空；独审确认无构造地点/访问次数及 P0/P1。仅此场景一条自然链得到证明，N7 整项仍未签收。

## 2026-11-02 N10 已占用玉简安全替换

入口是槽页选择用户导出的网页 JSON，预览成功的已占用可读槽显示“备份并替换”，确认前不写原档。确认后导入器再次重演来源快照；`RunSession.commit_browser_import` 核对修订号和源指纹，逐字节备份现存 v2 或旧 v1，再以 `.pending` 原子提交 v2，提交后复核快照；失败写盘保留原档。`noncombat_browser_replace.gd` 对 v2、仅有 v1、失败写盘、写后校验失败回退原始字节、严格冷读和过期确认返回可复核结果，输出 `NONCOMBAT_BROWSER_REPLACE_PASS ... legacy=true`。槽页专项独立输出 `NONCOMBAT_BROWSER_IMPORT_UI_PASS ... replace_backup=true`，stderr 空；独审抓到双独占弹窗冲突，修复后未见剩余 P0/P1。跨进程同时写同槽尚未解决；浏览器战中、跨世及长历史存档仍不支持，N10 未签收。

重复启动后保留旧备份：浏览器原文暂存与目标槽替换都将备份名从单纯进程内微秒改为墙钟秒+PID+进程内微秒，并拒绝复制到已存在路径。暂存专项验证连续备份名不同且两份均保留原始字节，替换和槽页专项重跑通过。跨进程同槽提交互斥仍待 N2。

## 2026-11-02 N9 阅读设置弹窗对比度

高对比开关原先只改变剧情正文和底纹，阅读设置弹窗仍以灰字显示。现对该弹窗静态控件及内部“返回”按钮的文字主色应用 `#FFF6DF`，关闭时恢复原主题颜色。`noncombat_experience_settings.gd` 通过真实槽页信号验证开关、重置与存档状态隔离，输出 `... contrast=true dialog=true ...`；`capture_experience_settings.gd` 重新抓取 1280×800 和 1920×1080 实画面，独审确认标签与重置按钮包含目标字形像素，内部按钮开关色测试通过，未发现 P0/P1。其它弹窗对比度与全部来源卡的大字完整布局未验，N9 未签收。

## 2026-11-02 N11 Windows release 首轮冷启动

本机导出模板 `version.txt` 为 `4.7.2.stable`，使用现有 Windows Desktop preset 导出到 `output/godot/windows_release/`；Godot 返回 0，日志 `godot/.godot/windows_export.log` 以 `[ DONE ] savepack` 结束。exe 为 109,127,680 字节、PCK 为 2,616,307,847 字节。复制到独立 `output/godot/windows_smoke_clean/` 后逐文件 SHA256 相等；以隔离 `%APPDATA%` 运行复制品，`--headless --quit-after 120` 返回 `EXPORT_SMOKE_EXIT=0`，日志无资源加载错误。`output/godot/windows_smoke_clean/smoke-evidence.json` 保存实际命令参数、隔离路径、两个哈希和退出码。导出物又以 Windows OpenGL 3.3、`--write-movie` 录下 30 帧；`output/godot/windows_smoke_clean/opening.png` 的 1280×800 首屏显示三槽界面且未裁切。此证据只说明导出物能从独立安装目录冷启动并绘出初始界面；键鼠长局、三槽操作、导入、战斗打断与全部内容可达性仍未通过，N11 未签收。

首轮导出帧还揭示全新空目录一号玉简误显“上次使用”：槽默认选择 `slot_1` 不代表确有活动索引。已在 `inspect_slot` 让摘要仅凭存在且有效的活动索引显示该标记；`noncombat_save_slot_ui.gd` 从空目录和真实切槽两侧验证，独审通过。该修复发生在首轮导出之后，交付包须重导；此处的 AVI/PNG 仅作问题与首屏载入证据。

尝试向隐藏的导出物窗口发送一次 Windows 槽按钮鼠标消息并录制 600 帧，`ui_click_mid.png` 仍为原三槽界面，隔离用户目录无活动槽索引；隐藏窗口未证实接收输入。该尝试不计入键鼠交互或 N11 路线覆盖。

## 2026-11-02 商店结果卡后的装备冷恢复

总门禁在 `noncombat_treasure_equipment_cold.gd` 发现真实缺陷：商店关闭生成 `VENDOR_RESULT_PENDING`，确认结果卡后进入下一普通卡时仍使用同一 `runClock.decisionIndex`。在该普通卡执行的装备记录因此与此前结果卡同序号；恢复器原先在结果卡尚未确认时就核对装备事件的卡 ID，误拒合法存档。`_replay_equipment_actions` 现在只在 `VENDOR_RESULT_PENDING` 暂缓该事件，待结果卡被历史记录确认后仍按操作、道具、阶段、卡 ID、完整事件、事件总数和最终状态严格核对。现有自然购买专项在修前退出 1；修后输出 `NONCOMBAT_TREASURE_EQUIPMENT_COLD_PASS purchase=true equip=true unequip=true rollback=true replay=true`、退出 0；同一失败存档的独立冷恢复也返回成功。独立只读审查未见 P0/P1。总门禁从该失败点继续；N0–N11 仍未整体签收。

## 2026-11-02 N2 同槽跨进程写入保护（局部，未签收）

`RunSession` 的读取、普通/跨世提交、网页档替换和损坏档归档现先取得同槽目录锁；读到 `.pending` 的归档也在锁内，避免一个进程把另一个进程尚在写入的候选档搬走。独立双进程专项让两个 Godot 实例从同一修订号同时选择，结果只允许一个提交，最终修订号为 1 且严格冷读成功：`NONCOMBAT_SLOT_LOCK_PARALLEL_PASS one_commit=true revision=1 cold=true orphan_preserved=true`。`noncombat_run_session.gd`、`noncombat_browser_replace.gd`、`noncombat_browser_import_ui.gd` 回归退出 0。

独审指出锁忙时旧 UI 会把现存档误归档，以及按过期时间自动回收锁会在双回收者竞态中移走新活锁。现将 `SLOT_BUSY`/`SLOT_LOCK_FAILED` 列为不可归档状态，归档须重新取得槽锁并核对本次失败时读取的路径及原始 SHA；`noncombat_slot_lock_archive.gd` 验证忙锁和旧失败结论均保留有效档，退出 0。危险的按时间自动回收已撤下。

**强退恢复续记**：锁的候选目录先写 owner、再由 Windows 原子改名为正式锁；写 owner 前强退只留不阻塞的候选目录。持锁强退后，正式锁必须有合法 PID 标记，且 `tasklist` 确认原进程不存在才被移入固定旧 token 墓碑目录；同一墓碑阻止另一恢复者误搬新活锁。`test_godot_slot_lock_parallel.py` 先验同修订号双提交仅一笔生效，再验无效 owner、活 PID 锁均不回收，死 PID 孤锁恢复、候选目录不阻塞，以及两独立 Godot 进程同步回收时恰一者持锁 4 秒、另一者报忙、原存档字节不变且最终严格冷读成功，输出 `... recovery_race=true`、退出 0。`noncombat_run_session.gd`、`noncombat_slot_lock_archive.gd`、`noncombat_browser_replace.gd`、`noncombat_browser_import_ui.gd` 回归退出 0；独审独立复跑双进程反例，未见本批 P0/P1。进程查询不可用或 owner 无效时仍保留锁，需人工排障；N2 整阶段仍未签收。

## 2026-11-02 旧二周目阵营时序严格回放（局部）

完整门禁在 `noncombat_generic_normal_death.gd` 发现真实第二世 `mentorArcState.version=2`、带旧 `factionEventState` 的档无法严格恢复：新版阵营收集在优先事件后运行，旧档在优先事件前运行，导致 `factionProgress.ticksSinceEvent` 不一致。恢复器只对确有旧阵营状态的旧档在历史决定中沿旧顺序回放，并在下一次真实决定写入 `factionCollectionNewActivationIndex` 切换新顺序；无阵营状态的首世旧档不写此标记。专项验证原始档恢复、致死选择失败回滚、切换决定号 63、死亡档严格冷读及非法标记拒绝，输出 `NONCOMBAT_GENERIC_NORMAL_DEATH_PASS`、退出 0。`noncombat_death_rebirth_journey.gd` 也已完整通过首世无阵营旧档的死亡、冷读、转世与后续路线，门禁继续后段。独立只读审查未见 P0/P1，但历史只证明回放结果一致，不证明标记的唯一原始时点。N0–N11 仍 0/12。

## 2026-11-02 N9 阅读高对比扩至现有弹窗（局部）

阅读设置的高对比现在应用于剧情页现有的万物志、证据星图、浏览器档选择/预览/替换、因果簿、线程簿、装备、残卷、传承追踪、轮回树等弹窗文字控件；按钮按普通、悬停、按下、聚焦、禁用状态分别保存原色、应用浅米黄并可恢复。动态控件的 `node_added` 更新也接受“正常字号＋默认字体＋仅高对比”的组合，补测新生成的万物志人物行。`noncombat_experience_settings.gd` 输出 `NONCOMBAT_EXPERIENCE_SETTINGS_PASS ... dialog=true`、退出 0，且在重置后校验按钮各状态原色和玩法档不变。OpenGL 实抓 `output/godot/experience_settings/` 的 1280×800、1920×1080 剧情、设置及万物志图；独审逐像素复核底部按钮字形为米黄色抗锯齿色，未见本批 P0/P1。禁用立绘阶段按钮、系统文件选择器的原生窗口外观和全部来源卡大字排版尚未完整实拍，N9 未签收。

**N10 战中网页旧档来源切片（2026-11-03，来源证据）**：`node tools/capture_noncombat_combat_pending_browser.js` 经 `index.html` 真实 Chromium 公开槽页/剑修选择/前五次决定、试炼预警确认、战斗键盘出牌，采得二号玉简原始 localStorage（save10/causal18/quest3，`combatSession.active=true`、`PLAYER_TURN`、来源卡 `encounter_card_enc_trial_sword_swift`，决定 5，authority seal `dc2-9dea3a159035c70d`），再刷新续战并经页面撤阵得到 `combat_fled_encounter_card_enc_trial_sword_swift`，结果卡确认后下一可见决定 `ch_qi_20`。原字节、刷新后重签 seal、完整选路及来源/实际服务文件 SHA 在 `artifacts/godot-migration/noncombat-browser-import/combat-pending-source-sword.json`；`node tools/capture_noncombat_combat_pending_browser.js --check` 校验来源漂移与证据结构通过。此处仅是 N10 来源取证，未签收 Godot 战中导入；N0–N11 仍 **0/12**。





