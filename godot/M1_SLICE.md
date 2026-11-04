# Godot 实际内容迁移首批次：Slice Charter 与证据

## 2026-10-16 最新视觉方向更正：HD-2D

用户明确指定 **HD-2D 战斗场景**：有真实空间、建筑细节、前后遮挡与动态光影的场景，配合叶凌云/木人多方向像素角色序列帧。角色动作需有真实逐帧姿态和细腻呼吸，FrameRonin 用于帧整理与打包。此前 ISSUE-09 的程序网格人物和低多边形场景虽可运行，但**视觉验收失败**，不能视为目标方案或完成品；现有入口已改接 HD-2D 混合舞台，但美术仍是候选，未达到参考 P2 的建筑、光影和动作精度。执行任务、素材管线、工具与验收见 `art_direction/HD2D_BATTLE_PRODUCTION_PLAN.md`。下文 ISSUE-09 是当时实施记录，其“真正的 3D 世界与人物”玩家契约已被本节最新用户要求取代。

**2026-10-17 状态：**独立 V4 首战场景已完成 Blender→GLB→Godot 候选接线和 Forward+ 实机复拍，原首战完整 UI 回放通过；视觉评审仍为 FAIL，默认首战没有切到 V4。具体截图、来源清单、缺口与下一艺术关口见上述任务书第 9 节。

### 正在实施：HD2D-01 首战混合舞台

**玩家契约与设计支柱：**保留网页端真实卡牌和结算；保留苍茫宗雨后露天试剑场的地点身份；3D 地面/建筑提供视差、遮挡和受光；像素人物逐帧承担出招与受击；命中关键帧与权威 HP 反馈同步。趣味假设：同一张「试锋一点」牌，在可见的蓄力、探刺、击木短光和木人受击之后，玩家能更明确地读懂这次出牌的重量与后果。最小玩家可见证明是首牌从真实手牌输入到敌人 7→6 HP，再进入下一张牌选择。

**只读调查与基线：**`main.gd:6` 固定加载 `duel_stage_real_3d.tscn`；它实例化世界和两名网格人物，`presentation_integration.gd` 旧断言排斥任何精灵。原 `yelingyun_s1.tres`、`quick_sword_dummy.tres` 已从来源动作表生成，前者「试锋一点」6 帧、526ms、约 235ms 接触，带逐帧脚点；旧 `duel_stage_25d.gd` 会播这些帧，却用平面投影战场。桌面 `play_full_battle_ui.gd` 当前基线 exit 0，输出 `M0_FULL_BATTLE_UI_PASS`。这两处素材/舞台未在同一个运行链中，是本批根因。开工前 `git status --short` 显示已有大量无关改动，全部保留；`godot/` 文件为未跟踪工作树，普通 diff 不代表完整变更。

| Issue | 当前失败行为 | 本批修复位置 | 修复前失败证据 | 修复后与边界门禁 | 状态 |
| --- | --- | --- | --- | --- | --- |
| HD2D-01 | 首战主入口仍显示低多边形人物；源帧只在旧平面舞台 | 新增独立 HD-2D 人物/舞台场景，`main.gd` 仅切舞台绑定，更新视觉集成合同 | `tests/hd2d_stage_contract.gd` 换入口前 exit 1：`main entry has no HD-2D sprite actors`；旧图 `artifacts/godot-migration/real-3d-first-fight/current-opening.png` | 新舞台双来源像素人物+3D 场地、首牌接触 HP、全战 UI、追风连式接触、防御原地、致死溢出均通过；Windows 1280×800 图已复核 | 功能通过；美术候选未通过最终验收 |

**本批边界：**已接通真实 3D 空间与来源像素动作，当前 3D 场地仍是空间基线；建筑 GLB 美术、8 方向角色母体、真呼吸新帧和最终 P2 级画面属于后续 HD2D-02/03。不能把本批通过程序门禁等同于视觉定稿。新的方向帧未进入资源前，镜头只开放已核查视角。输入 → `main.gd` → `combat_domain.gd` 权威结算 → HD-2D 演出联系 `contact_frame` → `main.gd` 延后 HUD 数字 → 下一张卡这一链不得断开。

**2026-10-16 实施证据：**`main.gd` 现加载 `duel_stage_hd2d.tscn`；两名角色为引用原 `SpriteFrames` 的 `AnimatedSprite3D`，脚点和时长读取原元数据，场地为独立 3D 网格及灯光。新远山松林使用先写提示词再调用 ImageGen 生成的远景候选，仅置于最深处；旧廊棚、白灯、过亮地砖高光在本舞台隐藏。首牌突刺命中 75ms 停顿和短火花，追风连式有独立命中帧；卡牌内容和图仍来自 `battle_cards.json`。独立只读审查发现追风连式漏接触、防御冲刺及致死溢出假血量；新增 `tests/hd2d_card_contact_regression.gd` 先 exit 1，修复后 exit 0。程序门禁：`hd2d_stage_contract.gd`、`hd2d_card_contact_regression.gd`、`presentation_integration.gd`、`play_full_battle_ui.gd`、`card_hand_ui.gd`、`replay_full_battle.gd` 全部 exit 0；`python tools/validate_godot_runtime.py` 输出 `data=74 art=74 M0_steps=12 reactions=3 presentation=3 stage_routes=4`。Windows OpenGL 图形渲染记录 `artifacts/godot-migration/hd2d-first-fight/opening.png`、`contact.png`、`followthrough-contact.png`；桌面调试包 `YiNianXianTu-HD2D-M1.exe/.pck` 导出 exit 0，exe `--headless --quit-after 5` exit 0。当前实机图仍有规则石砖、简陋山门与木人、静态待机帧，且远景只是一层；**尚未通过最终视觉验收，未声称多方向和呼吸帧已制作**。导出包的图形窗口交互仍待单独验证。

**角色方向资产进度与审查结论：**ImageGen 根据原叶凌云图生成八向转面 V1、V2，提示词、原图、哈希和逐格拒收理由见 `art_direction/HD2D_ASSET_PROMPTS.md`。本地 FrameRonin V3 实际完成 V2 的 4×2 切帧、逐格脚点平移与重组合；八格 alpha 脚底均为 y=475。独立复审确认上述三处演出代码缺陷已闭环；生成转面轮廓仍有红绿边缘污染，且像素密度与当前攻击帧不同，故候选继续隔离，不接入玩家战斗。这一批没有完成多方向呼吸或攻击序列。

## 玩家契约

先把当前浏览器游戏的真实内容与结算搬进 Godot，维持稳定 ID 和数值；仅做 Windows 与桌面浏览器，不做手机端。首批次从 M0 实际运行的剑修首战进入，读取当前 `data/`、首战卡图和浏览器权威状态。在这条真实首战链上升级立体战场；它仍是首战切片，不等于整款游戏已搬迁。

## 2026-10-16 ISSUE-09：首战改为真正的 3D 世界与人物

用户在看到前一轮实机图后明确否定原画投影地板、木桩和 `AnimatedSprite3D` 角色：它们仍显得像平面背景；要求在 Godot 中用有体积、可转动视角观察的建筑、场地和人物模型完成真实 3D 战斗。目标仍是苍茫宗冷雨试剑场与叶凌云对快剑木人，桌面显示，来源首战卡牌、数值、输入与剧情 ID 保持权威。像素感由造型与克制材质调色形成，不能再把一张原画贴到战场几何体上冒充 3D。实机对比后，当前场景使用原生分辨率渲染以保留建筑和角色轮廓；半分辨率候选留档在 `candidate-half-resolution.png`。

本批实施边界：新增 `scenes/cangmang_real_3d_world.tscn`、`scenes/yelingyun_s1_real_3d.tscn`、`scenes/quick_sword_dummy_real_3d.tscn` 和 `scenes/duel_stage_real_3d.tscn`；主入口只改演出场景接线。战场建筑、石阶、试剑场、训练物件与两名角色必须使用 `MeshInstance3D` 等有体积几何；角色攻击、守势、受击、待机必须有 Godot 引擎动作；出牌到接触帧的 HP 显示、锁输入、回待机与原规则一致。暂不把一招首战模型演出宣称为整款游戏或 P2 视觉完成。

失败基线：`artifacts/godot-migration/source-first-fight/current-opening.png`、`current-hit.png`，上一版虽能运行，但 `duel_stage_25d.tscn` 仍引用原画投影 shader 和两个 `AnimatedSprite3D` 人物。验收证据：新场景没有原画 backdrop/角色 sprite；引擎场景树中的网格及动作片段可核查；实机正面与旋转镜头截图证明体积和视差；真实来源卡牌点击、命中反馈与完整首战规则回放继续通过。美术质量需以实机 1280×800 尺度再审，不能用节点数替代审美验收。

**ISSUE-09 实施与证据账本（本批首战）：**

| 字段 | 实际结果 |
| --- | --- |
| 根因与修复 | 旧 `duel_stage_25d.tscn` 的原画投影地面、角色 `AnimatedSprite3D` 只给出了表面受光，旋转镜头不能看到可信角色体积。`main.gd` 现绑定 `duel_stage_real_3d.tscn`；战场、叶凌云和木人分别是独立可编辑的实体网格场景，`real_3d_fighter.gd` 的 `AnimationPlayer` 驱动姿态与接触关键帧。卡牌 UI 和 `combat_domain.gd` 的权威规则保持原运行链。 |
| 修复前失败证据 | 上一版 1280×800 图 `source-first-fight/current-opening.png` 仍显得像平面背景；旧场景文件可复核两个 `AnimatedSprite3D` 和投影 shader。新的实体网格/无角色精灵验收断言对旧运行链不成立。 |
| 修复后行为门禁 | `tests/presentation_integration.gd` 从真实 `main.tscn` 点击来源 `sword_probe`，验证 3D 网格场地与两名模型、无精灵、F9 旋转镜头视差、动画轨接触、剑尖与胸部标记距离 ≤0.35 世界单位、HP 接触同步、输入锁、守势、木人反击、胜利和护盾受击。命中轨道取代独立计时器；早期反证曾显示计时器触发时动画已前进到 0.62 秒，剑尖离胸口 0.91 单位。 |
| 实际测试 | `presentation_integration.gd` exit 0；`replay_full_battle.gd` 对源 M0 步骤 5–16 通过；新增 `play_full_battle_ui.gd` 从真实主场景连续点击 8 张来源卡、结束回合及 2 次敌方反应，第三回合胜利，exit 0；`card_hand_ui.gd` 通过；`tools/validate_godot_runtime.py` 输出 `data=74 art=74 M0_steps=12 reactions=3 presentation=3 stage_routes=4`。 |
| 桌面玩家证据 | `artifacts/godot-migration/real-3d-first-fight/current-opening.png`、`current-orbit.png`、`current-hit.png`、`current-action.webm` 为同一新版 Web 导出在 1280×800 桌面 Chrome 的实机记录；`current-probe.json` 中 pageErrors 与 httpFailures 均为零。F9 斜视能看见山门、石阶、树与角色侧面变化。Windows `YiNianXianTu-Real3D-M1.exe/.pck` 导出 exit 0，exe `--headless --quit-after 5` exit 0；图形化 Windows 交互仍未独立验收。 |
| 边界与剩余 | 只覆盖来源首战，奖励、剧情入口、存档与其它遭遇仍按原账本未迁移。新版世界和角色是有体积的低多边形首版，冷雨、湿石和暖灯保留源世界观，但建筑与人物精度仍低于参考 P2；不宣称最终美术完成。Windows 图形化交互尚未验证。 |

独立只读审计对当前工作树的 3D 场景、实体人物、接触帧与 M0 规则判为 VERIFIED；它当时指出完整首战尚未从 UI 走通、卡牌文本截断。随后补充了 `tests/play_full_battle_ui.gd` 并实际通过第三回合胜利；卡面说明改为两行加省略提示，悬停完整原文使用定宽换行框，新增边界与内容高度断言并通过。多次出牌还暴露旧提示动画捕获已释放对象的问题，改用弱引用后完整 UI 回放不再有这条运行时错误。上述后续修复经过本地回归，尚未做第二次独立只读审计。全部本批 `godot/` 和实机证据目前仍是工作树未跟踪文件，普通 `git diff` 不能代表本批完整改动。

下文 ISSUE-01～08 与旧“当前已验证”段落保留为迁移历史；其中关于运行主入口仍使用 `duel_stage_25d.tscn`、原画投影地面和 `AnimatedSprite3D` 的叙述，均已由本节 ISSUE-09 的实际运行链取代。

## 2026-10-16 首战战场升级状态

### 当前视觉返工批次：ISSUE-07 / ISSUE-08

- **ISSUE-07 卡牌过宽且缺少层次。** 用户提供的实际运行截图中，五张约 216×214 的牌几乎为方形，牌图被裁成横幅，费用、牌名、规则字挤在同一块深色底上；与参考 P1 的小幅竖牌和项目 2:3 竖版素材规范不符。修复目标为桌面 1280×800 下居中的竖向卡牌、源图主视觉、层次分明的窄边框/阴影与放大可读的卡面信息，同时保留源卡 ID、图片、费用、状态和键鼠出牌。
- **ISSUE-08 场景的 3D 添加物破坏了原战场构图。** 当前方块檐棚和中景山门遮挡了来源远景的山门与石台，平铺石板盖掉原有试剑环，导致世界观信息和远近层次反而下降。修复目标为保留来源苍茫宗山门、训练木桩、环形试剑场的空间关系，3D 只在能明确改善近景材质、受光、天气、接触反馈的部位使用；冷雨青灰为常态，暖光限于场景物件与攻击焦点。以用户截图作失败基线，Godot 实机新截图和交互验证作为验收证据。

- **ISSUE-03：先前 2.5D 样机脱离项目世界观。** 西式石厅、贵族剑士、披甲木偶与首战的苍茫宗露天试剑场不符。现运行场景改为旧版首战的山门战场远景、叶凌云和快剑木人原身份图、原卡图与原动作帧；角色使用 Godot `AnimatedSprite3D` + `SpriteFrames`，卡牌事件触发帧序、木屑接触特效、45ms 命中停顿和镜头回弹。旧样机资源仍在工作树供追溯，但运行绑定和导出预设不再引用。
- **ISSUE-04：战斗场景缺少引擎特有的空间与光影。** 第一版 155 节点方块棚、假山门和平铺石板曾盖掉旧版山门与试剑环，用户实际截图否定了该结果。当前 `scenes/duel_stage_25d.tscn` 用可受动态光的原画投影 3D 地面、相机、方向光、局部光、雨线、动画角色和接触剑光；`scenes/cangmang_trial_architecture.tscn` 仅保留两根对齐原画木桩位置、以同一原画投影着色的可编辑近景 3D 木桩，避免重复造景。旧石板图 `art_direction/candidates/MAT-01_slate_first_pass.png` 仍是留档候选，不再进入运行场景。`SubViewportContainer.stretch_shrink=2` 让 3D 受光与源角色共用像素密度。这个修复恢复了苍茫宗试剑场构图；完整 P2 级 3D 建筑质量仍未通过视觉验收。
- **FrameRonin 定位与实测：**其原仓库是 Web 序列帧/视频/抠图/图集/像素处理工具，不是 Godot 的 3D 建筑编辑器插件。已在本地将「试锋一点」原六帧导入、预览和无损重组；输出图集当前通过 AtlasTexture 接入 Godot `SpriteFrames`，逐帧时长/脚点仍由旧版数据决定。它未新增姿态；二三十帧的细腻新动作尚需逐帧制作和验收。记录见 `art_direction/FRAME_RONIN_EVALUATION.md` 与 `frameronin_sword_probe_provenance.json`。
- **补帧首轮反证：**按先写提示词后生图的流程制作第 2→3 帧过渡候选 ACT-02A/02B；两张都输出 1254×1254，人物和剑占比远超原 320×320 序列，第二张脚点甚至碰到底边。两张均列为 `REJECTED`，保存于 `art_direction/candidates/` 供核查，不导入 FrameRonin 图集或运行 `SpriteFrames`。这是实际制作瓶颈，不能把六帧图集包装成细腻的新动作。
- **玩家可见证据：**`artifacts/godot-migration/source-first-fight/current-opening.png`、`current-card-hover.png` 和 `current-action.webm` 为 1280×800 桌面 Web 实机画面/录像；从录像抽出的命中帧 `qa-final-hit-019.png` 显示收尖的冷玉刺击线、暖色接触碎光和木人受击，右上 HP 7/7→6/7。五张卡已变为居中的 146×222 竖牌，保留 1024×1024 来源原画完整构图，悬停显示来源效果。旧版对照为 `artifacts/godot-migration/m0-2026-10-15/battle-opening-desktop.png`。网页运行无脚本错误或资源 404。与参考 P2 相比，当前仍缺高精度 3D 建筑、更多角色帧和重型攻击的镜头/光效；不称视觉完成。

## 入口与权威链

### 下一批 ISSUE-05：首战重洗牌后的完整回放

玩家契约：同一首战开场、同一出牌和反应选择、同一随机抽样输入下，Godot 应复现网页版直到第三回合胜利的权威战斗状态。不得为测试改变卡牌数值、卡牌顺序或旧版源文件。当前第一回合测试在第二回合忽略手牌，因为 `combat_domain.gd::_start_turn()` 使用 Godot 内置 `Array.shuffle()`，与网页版 `DeckCombatSystem._shuffle()` 的逐步 Fisher–Yates 随机抽样不同。

来源入口：`index.html` → 剧情教学选择 → `encounter_card_enc_trial_sword_swift` 预警确认 → `DeckCombatSystem.playCard/endTurn/chooseReaction` → 战斗奖励卡；原始 M0 `battle-trace-desktop.json` 记录步骤 5–17。新版诊断工具 `capture_full_battle_rng.py` 在当前浏览器入口独立重放同样选择，逐次记录战斗期的 `Math.random` 返回值、调用者和牌堆状态；必须与冻结的 M0 权威投影逐步一致，才允许用作 Godot 测试输入。

ISSUE-05 的实施范围是在 Godot 战斗领域层加入可注入的随机抽样流，重洗牌使用与源一致的 Fisher–Yates；正式运行保留 Godot 自身随机源。回归门禁是修复前 `replay_full_battle.gd` 失败、修复后按来源步骤 5–16 对齐阶段/血量/护盾/真元/手牌/牌堆/敌策且最后变为胜利；再跑已有首回合、反应、视觉集成、桌面入口及独立只读复核。未覆盖奖励事务、存档及其它遭遇。

**调查后更正：本批存在第二个同一首战闭环内的差异（ISSUE-06）。** 随机输入接通后，步骤 13 的「青锋点雪」在 Godot 只造成 1 点伤害，网页版造成 2 点。源 `PathArchetypeSystem.beforeCard()` 在同回合「技能 → 攻击」且玩家保有至少 1 护盾时，按 `data/config/path_archetypes.json` 的 `sword_flow.flow_alternate` 给一次 +1 伤害；Godot `combat_domain.gd` 尚无这条来源流派运行状态。实施时从同一来源数据读取首战所选流派和规则，只补此战可达的 `previous_type` 条件、回合重置和一次触发语义；不把 +1 硬写进卡牌或泛化为其它流派已迁移。修复前反证为 `replay_full_battle.gd` 在步骤 13 明确报 `enemyHp=2`，源为 `1`。

**本批实施结果：**`capture_full_battle_rng.py` 从当前浏览器重新录得 M0 首战的 9 次战斗随机抽样，逐步投影与冻结旧版 M0 证据一致；`sync_runtime_content.py` 从该来源生成 `content/fixtures/m0_full_battle_expected.json` 并记录哈希。Godot `combat_domain.gd` 现以可注入 RNG 流重放来源 Fisher–Yates 洗牌，并按来源流派数据触发首战可达的剑流「技能→攻击」一次加伤。`replay_full_battle.gd` 对步骤 5–16 的阶段、回合、真元、双方 HP/盾、手牌/抽弃牌堆、敌策和流派状态逐项通过，第三回合达到 `VICTORY`；独立只读审计结论为该 M0 规则轨迹 VERIFIED。网页版第 17 步的奖励选择/持久化尚未迁移或验证。

`index.html` → `src/systems/DeckCombatSystem.js` 和 `data/` 是旧版权威；`artifacts/godot-migration/m0-2026-10-15/` 是浏览器行为证据。

`godot/project.godot` → `scenes/main.tscn` → `scripts/main.gd` → `scripts/combat_domain.gd` 是新运行链。`godot/tools/sync_runtime_content.py` 原字节复制全部 74 份 JSON、首战 8 张静态图和 62 张动作/特效帧，`godot/content/source_manifest.json` 记录哈希。运行时读取 `godot/content/data/`，卡牌名称、费用、效果与卡图不在 UI 中重写。M0 的桌面开场和第三槽活动战斗快照只作为迁移/对照样本；目前没有旧存档导入器。

`scripts/combat_stage_router.gd` 现从原 `encounter_presentations.json` 解析当前首战背景、`presentationId` 与 `battlefieldId`，主场景已消费该结果；它也按网页版 `CardSystem.hydrateCombatCardPresentation()` 的 `${sourceCardId}:${direction}` 优先级解析剧情选项视觉字段，不改来源卡和待结算上下文。`tests/stage_router_contract.gd` 核对旧村左/右分场、剑冢左/右共场异呈现四个分支。**这只是来源映射与当前首战接线；剧情选择、预警确认、其余 3D 场景及胜后结算尚未进入 Godot 运行链。**

## 本轮问题账本：旧版素材与演出对接

| ID | 用户可见问题 | 根因与修复 | 修复前证据 | 修复后门禁 | 独立审计 |
| --- | --- | --- | --- | --- | --- |
| ISSUE-01 | 出牌、受击只有静态角色和白色闪屏，旧版动作素材没有进入 Godot | 旧同步脚本只复制 8 张静态图；`main.gd` 用固定 0.32 秒计时。现从 `action_presentations.json` 的首战卡专属、剑修回退、敌方动作和 `semanticVfx` 复制原 PNG；`build_source_first_fight_frames.gd` 将原时长/脚点装入 `SpriteFrames`，现用 `duel_stage_25d.gd` 在 Godot `AnimatedSprite3D` 播放并串行回待机，演出完成再解锁。`combat_action_presenter.gd` 只保留旧 2D 演出测试，不是当前主入口。 | `validate_godot_runtime.py` 曾以缺失动作帧失败；旧版 `desktop-opening.png`/出牌截图仅有静态像。 | `presentation_integration.gd`、桌面 Web 实机录像；数值仍由 `combat_domain.gd` 决定。 | 独立审计曾指出旧截图和剑轨接线问题；已修复并重抓 |
| ISSUE-02 | 手牌是简化按钮，缺原卡面信息和选择反馈 | `main.gd` 只放 110px 卡图+文本。现用 `card_hand_ui.gd` 从原 `battle_cards.json` 显示费用、原图、效果、描述、不可用状态与 1–5 快捷键；`CARD_PLAY` 后暂显原卡图/卡名。 | 旧 Godot/原浏览器开场图可直接对比；`presentation_integration.gd` 曾因主场景仍渲染简化按钮失败。 | `card_hand_ui.gd` 与主场景集成测试、桌面 Web 实机截图。 | 独立复核未发现现存 P0/P1；卡面信息和出牌状态接线通过 |

实际资源链：`data/combat/action_presentations.json` → 稳定卡牌/敌方动作 ID → Godot 原字节帧文件及哈希 → `CARD_PLAY`/`ENEMY_ACTION` → 按帧玩家/敌人动作、原木屑与 `sword_trace` 四帧细剑轨。`combat_domain.gd` 在出牌时仍即时更新权威 HP；`main.gd` 将双方受击 HUD 数字及胜败提示延后至相应接触帧，保证玩家看见的伤害与命中同步；有盾命中按效果结果保留护盾数字直到接触，使用冷玉剑轨而不触发木屑。当前动作资产的源数据 `motionApproved:true`，美术字段仍是候选复核状态，不宣称最终美术定稿。没有添加手机端入口。新生成的只有独立 3D 地面材质候选和未接入的补帧试图，角色、卡面、背景、接触特效仍用旧版源图。

## 当前已验证

- Godot 4.7.2 主场景无界面运行并输出 `MIGRATED_RUNTIME_READY encounter=enc_trial_sword_swift cards=5`。
- `tests/replay_first_turn.gd` 从旧版开场状态重放 `sword_probe → sword_followthrough → sword_sheath_guard → 结束回合 → 承受攻击`。M0 第 5–10 步的阶段、回合、真元、玩家血量/护盾、敌人血量/护盾、敌策状态一致；第 5–9 步手牌顺序一致。第 10 步的洗牌顺序单独列为待验证。
- `tests/reaction_first_fight.gd` 使用旧版实际剑修首战开场与真实护盾卡，验证格挡、偏斩、闪避的可用条件、伤害、敌策转换和下一回合抽牌惩罚。`tools/validate_godot_runtime.py` 同时核对派生样本与原始 M0 trace/存档，防止修改期望文件掩盖差异。
- 桌面 Web 1280×800 真实浏览器启动，旧版背景、角色、敌人、五张实际手牌可见；点击第一张卡后敌人 HP 7→6、真元 3→2、手牌少一张。实际点开反应窗口，选择格挡后进入第二回合。浏览器脚本错误和资源 404 均为零。画面证据在 `artifacts/godot-migration/runtime-first-slice/`。
- 最新首战已重新导出 Windows Desktop：`artifacts/godot-migration/source-first-fight/YiNianXianTu-Godot-M1.exe` 连同同名 `.pck`/`.console.exe`；控制台版本 `--headless --quit-after 5` 退出码 0，输出 `MIGRATED_RUNTIME_READY encounter=enc_trial_sword_swift cards=5 stage=25d frames_ready=true`。这证明导出包可启动，尚不等于 Windows 图形交互已验收。
- 首战视觉组件测试使用复制的真实 PNG 验证五张卡的动作帧、剑光和接触特效；主场景点击第一张牌后，原动作帧替换静态像，战斗输入按演出生命周期锁住，结束回待机，敌人 HP 7→6。桌面 Web 截图可见源卡面和受击帧。

## 未通过的迁移门禁

- **VERIFIED（有限范围）：M0 首战同输入轨迹规则。** 已以来源随机序列对齐步骤 5–16，包括第 10 步重洗牌和第三回合胜利；格挡、偏斩、闪避另有分支测试。**UNPROVEN：**胜/败奖励事务、其他战斗轨迹、装备与功法全部效果。
- **UNPROVEN：剧情入口与存档。** 现在从 M0 首战开场样本进入，不是从创建角色与剧情选择到达；没有三槽旧档导入或持久化。
- **UNPROVEN：完整游戏与 P2 视觉。** 当前已有可运行的首战 2.5D 场地与原动态角色，但建筑细节、前后层次、光影、角色动作流畅度与 UI 尚未达到用户给的 P2 截图；完整游戏内容远未迁移。
- **UNPROVEN：完整多媒体迁移。** 本轮接上首战原有动作帧、原木屑特效和源表 `sword_trace` 细剑轨；旧版 SFX、环境亮度呼吸、完整动作状态机及其他遭遇尚未移植。静态待机像配合 1 源像素的引擎位置呼吸，尚不是完整呼吸序列。卡牌/动作美术仍处候选复核状态。
- **UNPROVEN：MCP 实时编辑器闭环。** MCP 离线编辑场景和 Windows/Web 导出可用；本项目编辑器桥接在多个旧连接占用时运行/截图请求超时。不能声称实时 MCP 闭环通过。
- **UNPROVEN：Windows 图形交互。** Windows 桌面导出文件已生成，但目前只有桌面 Web 的可视点击证据；Windows exe 尚未完成图形化交互验收。
- **残留资产：** 先前样机的 `godot/assets/25d/`、`godot/assets/actors/` 和 `godot/assets/cards/` 仍在工作树；当前运行场景不使用，导出预设排除了旧 `25d` 样机。不要把残留文件计入当前视觉成果。

## 下一批实施顺序

1. 从旧版实机录制完整首战的确定性命令与 RNG 输入；扩大 Godot 对照覆盖到敌方行动、回合、胜败与奖励。
2. 接入实际剧情 `tutorial_1 → ... → encounter_card_enc_trial_sword_swift` 的状态迁移，拒绝硬编码剧情路线。
3. 完成桌面旧档 JSON 导入、三槽回退和权威校验，再推进其他可达内容。
4. 沿真实结算事件继续打磨 2.5D 战斗：先锁定叶凌云 `sword_probe` 一招，录制实机帧时序、做 FrameRonin 候选对照并验收脚点与身份，再扩大动作；同时对照 P2 补足 Godot 3D 地形层、建筑细节和受光，逐项替换候选而不覆盖原素材。
