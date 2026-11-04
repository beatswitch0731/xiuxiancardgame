# 美术资产生成与处理进度跟踪

> 范围更正：下方“34/34”只代表 2026-07-15 的旧章节图清单，不代表《素材—玩法融合严格整改 GDD V1》完成。整改素材必须经过真实生成、运行时装配、桌面/窄屏浏览器在位审校和独立审计后，才允许勾为完成。

## 《素材—玩法融合严格整改 GDD V1》实时进度（2026-09-02）

当前阶段：**技术／运行时候选全局验收已完成；N11、N12、N13、N14 与 Global-01—11 均关闭，54/54 正式遭遇进入同世界运行时候选；所有素材仍不升格为最终美术**

- [x] 同世界视觉合同：`visualWorldId`、像素密度、光向、地面带、纸木/青铜 UI 材质和唯一 VFX 权威已进入运行时；当前 54/54 正式遭遇拥有 composition。该项只代表运行时候选覆盖，`finalArtApproved=false`。
- [/] 试剑场背景：旧软绘版已拒绝；硬簇像素新候选已真实生成并保存 provenance/hash，待桌面与 390px 敌我在位复核。
- [/] S1 剑修：基础七族已挂载；两组完整剑身接触候选 v17 已生成，试探刺待在位装配，斜上点刺仍需检查连续帧方向跳变。
- [/] S1 体修：v16 七族、28 帧已真实生成；attack/skill/guard/reaction/hurt/defeat 六个运行时语义已挂载，reaction 过大已在固定脚点上归一到稳定身高，胜利候选仍需终局视觉签收。
- [/] S1 术修：v18 七族、28 帧已真实生成；六个核心运行时语义已挂载，符册透视和胜利终局仍需独立视觉签收。
- [/] S1 丹修：七族已真实生成，六个核心运行时语义已挂载；首局药圃战场、百毒炉灵、左向毒烟 travel VFX 与新档开场已完成在位技术审校，最终审美批准仍为 false。
- [/] S3 剑修：attack / skill / guard / reaction / hurt / defeat / victory 七族 28 帧已按 `displayedVisualStageId` 挂载；正式金丹入口不再借用 S1 动作返老还童。成长用 `1.04H` 精瘦成年比例、稳定脚根和控剑姿态表达，不用破布、盔甲或统一放大。
- [/] 代表敌人矩阵：封符灵体 L1 为悬浮窄核 `1.14H × 0.82W`，惊雷石傀 H1 为四足巨碑 `1.52H × 1.12W`，铁骨机关兽 J2 为低伏宽体 `0.82H × 1.0529W`，百毒炉灵 J2 为矮厚构装 `0.74H × 0.6831W`，七星剑阵 G2 为悬浮横阵 `1.18H × 1.26W`，雾盟镇关者 K2 为矮重宽肩 `1.14H × 0.52W`，筑基镜魔 K2 为悬浮碎镜法体 `1.60H × 0.94W`。各对象分别登记身高、体宽、重心、接地/悬浮、投影与景深；Boss 的威慑可以来自高度，也可以来自横向占场、负空间、前景压迫或阶段变形，禁止统一缩放。
- [/] 坊市/UI：真实坊市背景与连续纸面账册已通过法修桌面/390px新档链；代表战斗的招式谱、状态札、意图签已消费同世界纸木/青铜 atlas，禁止纯黑网页面板；其余界面仍待矩阵复核。
- [/] 全会话验证：法修新档已在桌面/390px走完教学战 attack/hurt/defeat→奖励→路线→坊市→刷新；炼气雷关已走完正式 `ch_qi_100` 的 hurt→敌策→attack/VFX→defeat→结算。四流派与其余境界尚未全齐。
- [x] L1/H1 运行时独立对抗审计：`VERIFIED / P0=0 / P1=0 / P2=3`。第一轮拦出的旧 G1 混装、法修入口错走剑修、吊绳虚增身高、动作证据不全、窄屏身份条压住敌人与最终批准状态无法升格均已根修；390px/1280px 为 4/4 PASS，姓名与身份条对真实 alpha 轮廓遮挡均为 0。P2 为正式美术未终验、真正晋级时需补 promoted 浏览器 fixture、未跟踪文件需纳入最终提交。全部仍为 `finalArtApproved=false` 候选，未计入最终美术完成率。
- [x] J2 体修/丹修运行时独立对抗审计：`VERIFIED / P0=0 / P1=0 / P2=1`。最终树 390px/1280px 为 4/4 PASS；铁兽低宽、炉灵矮厚、脚点、动作尺度、新档开场和左向毒烟均闭环。唯一 P2 是未跟踪文件的最终打包遗漏风险；媒体仍为 `finalArtApproved=false`。
- [/] G2 S3 剑修/七星剑阵：最终 formal 单链证据为 `output/playwright/agc_golden_sword_array_formal/fresh-N0RdWm/evidence.json`，从教程可见卡经正式 `ch_golden_40 → 深入秘境 → warning → enc_trial_sword_array`，以原始 `5/6` 战斗气血自然完成 13 次攻击/4 次结束回合→enemy defeat→S3 victory→`combat_reward`→结算刷新→领取奖励→合法下一节点 `ch_golden_60`。刷新前后消费节点均为 `[20,45]`，首局里程碑 45 日志恰好 1 次，刷新后不重放。390px/1280px 比例/方向/VFX 为 `fresh-FeawiI`，战斗中真实背景/比例/投影刷新恢复为 `fresh-R9pIdQ`。结算页、奖励选项与领取回执均消费纸札/青铜 atlas，无旧黑卡或内部字段；方向、分层、作者化比例和悬空投影在位。独立复审 `P0=0/P1=0/P2=1`，唯一 P2 为未跟踪打包风险；所有新素材仍为 `finalArtApproved=false`。
- [x] K2 S2 剑修/雾盟镇关者/筑基镜魔运行时候选：雾盟正式邀请→战斗中冷刷新证据为 `output/playwright/agc_narrative_wumeng/fresh-hvjEJ3/wumeng_gate_evidence.json`，不夸大为自然终局；筑基 100 必经镜魔→真实出牌→敌方计划变化→自然胜利→突破结算→冷刷新→同世界残卷弹窗→金丹抵达→抵达态冷刷新证据为 `output/playwright/agc_k2_foundation_mirror_formal/fresh-digBtZ/evidence.json`。S2 玩家、两敌、两战场和两套 VFX 同属 `cangmang_sect_pc98_v1 + sect_field_ledger_v1`；镇关者约为玩家 `1.15×` 高、`1.81×` 宽，镜魔约为玩家 `1.60×` 高、`3.23×` 宽。两者威慑分别来自双足横压和悬浮碎镜占场，不共用比例/落地/投影 profile。镜魔左向攻击实机未二次镜像；结算、残卷弹窗和境界抵达均在冷刷新后保留世界收据。独立复审 `P0/P1/P2=0`。全局侧栏仍是跨切片 UI 待办；全部新媒体有 prompt→raw SHA→运行帧 SHA、帧指标和 lifecycle，仍为 `finalArtApproved=false`。
- [x] K3 战后世界壳层运行时候选：新鲜正式证据为 `output/playwright/agc_k2_foundation_mirror_formal/fresh-yAYG5Z/evidence.json`。结算、首领残卷和境界抵达首次/冷刷新均消费同一战场、纸札和旧铜材质；离开后 fail closed 清理。残卷已改为连续账册、中文数据印记和玩家可见安全名称；境界抵达桌面为完整人物＋侧置回执、390px 为人物在上回执在下，顶栏两个信息组横向 overflow=0。强制门全通过，独立产品视觉复签 `PASS / 0 阻断`，严格审计 `P0=0/P1=0/P2=2`（三种印记缺本次自然像素覆盖、未跟踪打包风险）；只登记 `VISUAL_CANDIDATE`，普通剧情卡持久 shell 仍未关闭。
- [x] K4 S2 法/体/丹 attack 运行时候选：三路线分别使用 `1.00H × 0.28W / 0.32W / 0.30W` 与独立 COM、动作帧、原生右向 VFX；筑基镜魔保持自己的 `1.60H × 0.94W / hovering / depth -0.04` 合同，威慑不是共享 Boss 倍率。最终统一证据 `output/playwright/agc_k4_s2_path_attacks/fresh-4vTNem/evidence.json` 覆盖 spell/body/pill desktop 与 body 390px，4/4 PASS。产品视觉审校 `PASS P0=0/P1=0/P2=3`，严格审计 `ACCEPTED P0=0/P1=0/P2=5`；K4 只关闭 attack，全部仍 `finalArtApproved=false`。
- [x] K5 S2 法/体/丹 skill 运行时候选：三路线各有独立 4 帧方法动作与 source-local VFX。法印已由纯红坏块改为前臂尺度的暗朱砂/旧纸旋结，丹丸核心已压到指间约 6–10px，体修足压在 390px 内收；`actorAnchorOffsetU` 由 System→UI→Presenter 双重验证并按 actor height 应用。最终证据 `output/playwright/agc_k5_s2_path_skills/fresh-N2RVGe/evidence.json` 覆盖三路线 desktop+narrow，6/6 PASS。产品视觉 `PASS P0=0/P1=0/P2=3`，严格审计 `ACCEPTED P0=0/P1=0/P2=6`；全部仍 `finalArtApproved=false`。
- [x] N1 金丹雷兽／离炉真火运行时候选：两个独立战场、两敌四语义、S3 法／体／丹七语义、三套 VFX 与四张签名卡图已真实生成、装配并进入同一世界。最终稳定证据 `output/playwright/agc_n1_golden_thunder_furnace_formal/evidence.json`（SHA-256 `0ac6a5b4cc93338c63ea2a556d621a210772c56a32f06f0cb9c633848efbbb6b`）为四场同次 PASS，81 个当前入口依赖精确绑定，真实阳／阴／炉火动作窗口均 `authoredCount=1 / genericLeak=0`，5/5 authored VFX 有自然运行采样和同源注册表素材，两场终局完整关闭，28 个篡改反例全部失败关闭。最终独立反证 `VERIFIED P0=0/P1=0/P2=1`；唯一 P2 为未跟踪交付风险，全部仍 `finalArtApproved=false`。
- [x] N2 战场底缘融界运行时候选：移除兼容世界最后一层满宽深绿底和横向榫接条，保留招式托盘、真元槽、回合/离场、牌堆和战报各自的真实纸木旧铜素材。`output/playwright/agc_n2_battlefield_edge_hud/fresh-F33CC2/evidence.json` 覆盖桌面雷兽与 390px 丹火，底缘透明且不拦输入、局部控件可交互、横向溢出 0、真实行动/VFX 与错误统计均通过。独立视觉与反证均 `APPROVED P0=0/P1=0`；不新增 composition，不升格最终美术。
- [x] N3 逐实体体型覆盖门：strict profile 已从 `12/20` 提升为 `15/20`，已完成 composition 的 strict 覆盖从 `4/11` 提升为 `6/11`。`authoredScaleBasis + bodyProfileContractSha256 + compoundActor` 已进入 producer、provenance、System、UI、Presenter 与浏览器证据；tier=999/稀有度/HP 反例不改变铁兽或剑阵尺寸。四例主证据 `fresh-RyBO87` 通过；首轮视觉审计拦下的剑阵窄屏右缘断层已由同战场 root fallback 根修并以 `fresh-PprRNA` 复签，最终视觉 `P0/P1/P2=0`、严格架构 `P0/P1=0`。
- [x] N4 因果行进特效与丹火终局：阳雷、阴雷、丹火热流和丹火熄灭四套四帧真实素材已完成 raw→pipeline→运行帧→registry→真实 actionId 装配。最终同构建证据为雷兽 `output/playwright/agc_n4_final_gate_boss/fresh-aqmDBB/evidence.json` 与丹火完整终局 `output/playwright/agc_n4_final_gate_terminal/fresh-JLTLmE/evidence.json`；自然方向、逐招式可见尺寸、单一 authored carrier、1HP→灰烬→victory→hide 均闭合。System/UI 双端拒绝缺帧、坏 hash、非法状态、坏 scale 与缺朝向素材，禁止 generic fallback 偷换。视觉 `PASS P0=0/P1=0/P2=1`，严格反证 `ACCEPTED P0=0/P1=0/P2=2`；仍为 `finalArtApproved=false`。
- [x] N5 快剑木偶／巡山石影逐实体比例：两敌已分别登记身高、体宽、重心、双足根、景深、投影、动作 alpha 包络与威胁来源；tier/rarity/HP/bossFlag 不参与尺寸。最终比例证据 `output/playwright/agc_n5_spatial_world_reaudit/fresh-F1TOmq/evidence.json`，两场终局证据分别为 `agc_n5_quick_terminal_reaudit` 与 `agc_n5_mountain_terminal_reaudit`。快剑木屑与山影石脉 VFX 分流，石拳窄屏可见侵入约 `7.732px ≤ 8px`；视觉 `PASS P0=0/P1=0/P2=1`，严格反证 `ACCEPTED P0=0/P1=0/P2=2`。strict profile `17/20`、strict composition `8/11`，全部仍 `finalArtApproved=false`。
- [x] N6A 符阵灵／百毒炉灵逐实体比例：符灵按高窄悬浮纸翼法体、丹炉按矮厚双足压力构装挂载；两场远程身体零侵入，桌面／390px 四场比例证据 `fresh-0Oda0s` 4/4 PASS。浏览器拦出的三帧旧符弹已用 built-in ImageGen 真实补成四帧纸符并完成 runtime decode/dedupe；法／丹完整教学战 attack/hurt/defeat→奖励→路线→坊市→刷新 4/4 PASS。视觉 `PASS P0=0/P1=0/P2=2`，严格反证复签 `ACCEPTED/VERIFIED P0=0/P1=0/P2=2`；全部仍 `finalArtApproved=false`。
- [x] N7 炼气雷关巨碑：最后一个现有 legacy profile/composition 已挂载 strict 数据；`1.52H × 1.12W` 建筑式四墩足巨碑在 390px 与玩家共同缩放约 `.90455`，桌面为 `1`。最终 2/2 浏览器证据 `output/playwright/agc_n7_qi_thunder_spatial_reaudit3/fresh-abHRJM/evidence.json` 已关闭比例、接地、方向和 HUD safe rect；仍为 `finalArtApproved=false`。
- [x] N8 外门巡律使／噬灵藤心：两场新增 identity、四族动作、战场、因果 VFX、逐实体 profile 与 composition；巡律使 `1.03H × .34W` 靠精瘦前压，藤心 `.72H × .82W` 靠低伏横展，均不读取 boss/tier/rarity/HP。五场主证据为 `output/playwright/agc_n8_qi_encounter_cohesion_final/fresh-NoMeLx/evidence.json`；首轮视觉 P1 已用专用四帧贴地格挡根修，限定证据 `output/playwright/agc_n8_ground_deflect_contact_fix/fresh-yIA7Ja/evidence.json`（SHA-256 `b7072def2ce40dfb08388e9d3bab5caf593c7bb1f26b79c52b292eef5d980161`）。独立严格与视觉均 PASS、阻断 0；状态仅为 `BROWSER_VERIFIED`，最终批准仍 false。
- [x] N9 错乱阵灵／镜雾游魂：两场已拥有独立身份、动作、战场、VFX、逐实体比例和原生计划。阵灵以真实 `block 3→2→1→0` 破阵并进入 `EXPOSED`；镜雾分别记忆玩家路线与 `attack/guard/skill`，真实完成 ECHO 后可折序进入 `REFRACTURE`，存档恢复保持。代表浏览器证据 `output/playwright/agc_n9_final/fresh-LTgm7y/evidence.json`，SHA-256 `5a2dab1470423ca05fc9dd32b16fbf6d8c54ceba780db006b25c8c9594db3e29`；桌面阵灵与 390 镜雾均证明敌右→玩家左的施法—行进—接触。完整内部视觉审校 `PASS P0=0/P1=0/P2=2`，独立严格复签 `VERIFIED P0=0/P1=0/P2=1`；`finalArtApproved=false`。

### 当前完成边界与下一纵切

- 当前 54 个正式遭遇均拥有同世界 composition；N11—N14 整族运行时候选、跨系统生命周期、全局回归与真实入口反证均已关闭。技术／运行时候选 GDD 验收完成；最终视觉批准仍由用户另行决定。
- 当前 `pc98-card-art-replacement-v3` 明确范围为 61 张卡：61/61 唯一 prompt、canonical mount、1024×1024 PNG 与 C2PA-bearing Codex ImageGen provenance 全部通过；这不把范围外卡牌或任何候选自动升格为最终美术。
- 首局体修＋丹修 J2 已达到运行时技术候选：真实开场→教学战 attack/hurt/defeat→奖励→路线→坊市→刷新两条链已通过，独立审计 VERIFIED；不升格为最终美术。
- [x] K2 运行时候选：S2 剑修六动作已进入 `enc_faction_wumeng_elite` 与 `enc_boss_foundation_mirror`；方向、作者化比例、同世界战斗/结算/残卷弹窗/抵达、刷新与素材来源账本均已通过浏览器和静态门。雾盟终局未覆盖的边界已明确，最终独立复审结论待写回；最终视觉批准仍为 false。
- [x] N2 战场底缘融界：运行时与两份独立候选审计已关闭。保留 `finalArtApproved=false`，不把代理视觉通过冒充用户终审。
- [x] N10 玩家成长与动作语义总线：高阶段四路线 7 语义候选与兼容门已关闭；最终美术批准仍为 false。
- [x] N11：地脉兽／构装／药灵族 7 场完成素材、数据、比例、机制、装配与候选审计。统一压缩证据 `output/playwright/agc_x_visual_world_composite/fresh-nsxFPX/evidence.json`（SHA-256 `c69d71a76adccbcdfbaf17943f92245074d7f94b37dd9071c445398393145c09`）覆盖桌面金身影与 390px 药灵，两场 active-combat reload 后均恢复精确战场／比例／机制并绘制本敌动作与 authored impact VFX；独立用户候选验收 `VERIFIED P0=0/P1=0/P2=1`，最终美术批准仍为 false。
- [x] N12：宗门人形／戒律／追缉族 10 场已完成 10 identity／40 action sheets 的确定性抠图、170 张透明人物帧、10 个逐实体 profile、10 个静态与 40 个动作载体度量、10 张无角色战场、10 个 composition、10 张互异原生 planGraph、20 组专属 VFX／80 帧及其运行时 cue/lifecycle。扩展后的天枢桌面／390px 稳定证据 SHA-256 为 `303b5bcb12aa20cdf11e650cb60057f564a84b72431ea6a0f700165fa2840856`，精确绑定 76 个当前运行时输入；N12-07／08 独立复审 `VERIFIED P0=0/P1=0/P2=3`。当前 `runtimeMounted/profileMounted=true`，逐项 browser 状态仅代表天枢为真，`finalArtApproved=false`。
- [x] N13：异象／魂体／阵法／异火族 11 场完成 11 identity、44 action／176 帧、11 actor-free battlefields、44 VFX／176 帧、11 profile/composition/planGraph、七份权威数据同构、桌面＋390px 公共入口和独立反证；证据 SHA-256 `f626f3fdaa429845aedabdbe600566b52f7bac079ca341cc9252151069f630e6`，审计 `VERIFIED P0=0/P1=0/P2=2`，最终批准仍 false。
- [x] N14：天劫／法则 Boss／隐藏终局族 11 场完成 11 identity、44 action／176 帧、11 actor-free battlefields、44 VFX／176 帧、11 profile/composition/planGraph、374 个唯一运行输出、桌面＋390px 公共入口与独立反证。浏览器证据 SHA-256 `0a0b5e46e1293bfeccfb56c8c0bead04118eb5845dffb0b92360eded09a4e671`；审计 `VERIFIED P0=0/P1=0/P2=1`，最终批准仍 false。
- [x] N11—N14 压缩验收合同：每批全量静态／来源／运行时门禁；浏览器一个桌面与一个 390 代表样例；一次族级独立反证与视觉审校。红项按实际反例增加样例，没有恢复逐敌循环。
- [x] GDD 最终全局验收：内容／404／视觉世界／计划图／生命周期／72 模块内联 parity、37/37 GDD 门、61/61 卡图目标与真实浏览器矩阵全部通过；N1 最终独立反证 `VERIFIED P0=0/P1=0/P2=1`，Global-11 证据 SHA-256 `826360d0cc679db823be6486f74e1e7744e7021329ecb440d1c82212aec74b46`。结论仅为技术／运行时候选完成，不等于最终审美批准。
- [x] AUDIO-B5A 剑修／法修声音身份：4 套状态 BGM、两路各 3 个语义 SFX 与 1 条同男主誓词共 12 项真实 WAV 已由免费远端模型生成并接入；HTTP 正式入口、`file://` 离线入口、刷新不重播、静音、解码、来源交叉绑定和反伪造门均通过。当前证据 runId `cfbc6b28-4e5c-4f16-9541-978fb3740135`，SHA-256 `ce42fcc4d05c118c0c887704882b4219785aa5946d3d094354557e08d0d1757e`；独立只读审计 `VERIFIED P0=0/P1=0/P2=5`。仅关闭技术／运行时候选，人工听觉审美仍待用户签收，体修／丹修留给 B5B。

### 旧章节素材清单（历史范围）

总任务量：34张图片（3张角色图 + 31张场景图）
旧清单完成：34/34
旧清单阶段：**已完成，仅作历史记录**

## 进度状态说明
- [x]：已生成并裁剪转存完成
- [/]：生成中或待裁剪
- [ ]：尚未开始
- [!]：异常或被中断

## 一、角色概念与诱惑立绘 (3/3)
- [x] 白落霜概念图 (`concept_bai_luoxuan.webp`)
- [x] 白落霜诱惑立绘 (`bai_luoxuan_seductive_v8_greeksculpt.png`)
- [x] 九尾溯月诱惑立绘 (`jiuwei_suyue_seductive.webp`)

## 二、特殊场景 (1/1)
- [x] 营地场景 (`scene_camp.png`)

## 三、章节里程碑 (30/30)

### 1. 凡尘初醒（炼气期）(5/5)
- [x] scene_ch_qi_20.png (灵根觉醒)
- [x] scene_ch_qi_40.png (初遇机缘)
- [x] scene_ch_qi_60.png (师承抉择)
- [x] scene_ch_qi_80.png (入道试炼)
- [x] scene_ch_qi_100.png (突破筑基)

### 2. 宗门风云（筑基期）(5/5)
- [x] scene_ch_foundation_20.png (拜入宗门)
- [x] scene_ch_foundation_40.png (师门历练)
- [x] scene_ch_foundation_60.png (门派纷争)
- [x] scene_ch_foundation_80.png (红尘试炼)
- [x] scene_ch_foundation_100.png (突破金丹)

### 3. 丹心问道（金丹期）(5/5)
- [x] scene_ch_golden_20.png (金丹初成)
- [x] scene_ch_golden_40.png (秘境探索)
- [x] scene_ch_golden_60.png (正魔抉择)
- [x] scene_ch_golden_80.png (道侣机缘)
- [x] scene_ch_golden_100.png (突破元婴)

### 4. 碎丹成婴（元婴期）(5/5)
- [x] scene_ch_nascent_20.png
- [x] scene_ch_nascent_40.png
- [x] scene_ch_nascent_60.png
- [x] scene_ch_nascent_80.png
- [x] scene_ch_nascent_100.png

### 5. 神游太虚（化神期）(5/5)
- [x] scene_ch_deity_20.png
- [x] scene_ch_deity_40.png
- [x] scene_ch_deity_60.png
- [x] scene_ch_deity_80.png
- [x] scene_ch_deity_100.png

### 6. 天劫飞升（渡劫期）(5/5)
- [x] scene_ch_tribulation_20.png
- [x] scene_ch_tribulation_40.png
- [x] scene_ch_tribulation_60.png
- [x] scene_ch_tribulation_80.png
- [x] scene_ch_tribulation_100.png

---
**备注/中断记录：**
- **2026-07-15**: 初始化跟踪文档，完成了炼气期（5/5）和筑基期（5/5）的里程碑图片生成。
- **2026-07-15**: 生成金丹期前3张时遇到额度问题。稍作等待后系统恢复了额度分配。
- **2026-07-15**: 一次性从金丹期 80% (`scene_ch_golden_80.png`) 继续，成功完成了旧版章节清单，并通过自动裁剪脚本嵌入项目。该记录只关闭当时 34 张图的范围，不代表后续《素材—玩法融合严格整改 GDD V1》完成。
