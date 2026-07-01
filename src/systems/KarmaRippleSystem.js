/**
 * KarmaRippleSystem — 因果涟漪系统 (GDD 上瘾引擎 §5)
 *
 * 核心机制：
 *   - 玩家的选择产生延迟连锁反应
 *   - 每隔 N 回合，检测未发芽的因果种子
 *   - 选中一枚种子，生成"涟漪卡"——展示过去的行动如何影响现在
 *   - 涟漪效果：资源变化 / 事件标志 / 短期Buff
 *
 * 与 KarmaSystem 的关系：
 *   - KarmaSystem 管理种子播种→发芽→合并→抵消的生命周期
 *   - KarmaRippleSystem 是"种子在发芽前就已经开始影响世界"的机制
 *   - 不消费种子（不调用 removeSeed），而是基于存在中的种子生成涟漪
 */
class KarmaRippleSystem {
  constructor() {
    this._history = [];       // 已触发的涟漪记录 [{turn, seedId, text}]
    this._totalTicks = 0;
    this._cooldownTurns = 8;  // 涟漪冷却回合（避免连续触发）
    this._lastRippleTurn = -this._cooldownTurns;
    this.onLog = null;
  }

  init() {
    this._history = [];
    this._totalTicks = 0;
    this._lastRippleTurn = -this._cooldownTurns;
    eventBus.on('state:reset', () => this.reset());
  }

  reset() {
    this._history = [];
    this._totalTicks = 0;
    this._lastRippleTurn = -this._cooldownTurns;
  }

  /**
   * 每回合 tick — 检测是否应该触发涟漪
   * @param {number} turn 当前回合数
   * @returns {Object|null} 涟漪事件卡牌，或 null
   */
  tick(turn) {
    this._totalTicks = turn;

    // 冷却中 → 不触发
    if (turn - this._lastRippleTurn < this._cooldownTurns) return null;

    // 基础触发概率：15%（每境界 +2%）
    const realmBonus = { qi: 0, foundation: 2, golden: 4, nascent: 6, deity: 8, tribulation: 10 };
    const realm = typeof gameState !== 'undefined' ? gameState.realm : 'qi';
    const rate = 0.15 + (realmBonus[realm] || 0) / 100;

    if (Math.random() > rate) return null;

    // 获取当前活跃的因果种子
    const seeds = typeof karmaSystem !== 'undefined' && karmaSystem.getAllSeeds
      ? karmaSystem.getAllSeeds()
      : [];
    const activeSeeds = seeds.filter(s => s.delay > 0);

    // 没有活跃种子 → 不触发涟漪
    if (activeSeeds.length === 0) return null;

    // 随机选一枚种子生成涟漪
    const seed = activeSeeds[Math.floor(Math.random() * activeSeeds.length)];
    this._lastRippleTurn = turn;

    return this._buildRippleCard(seed, turn);
  }

  /**
   * 构建涟漪卡牌
   */
  _buildRippleCard(seed, turn) {
    const seedType = seed.seedType || 'karma';
    const templates = this._rippleTemplates();
    const typeTemplates = templates[seedType] || templates.karma;
    const tpl = typeTemplates[Math.floor(Math.random() * typeTemplates.length)];

    // 绑定场景立绘
    const sceneMap = {
      karma:    ['scene_karma_k_fox_gratitude.png','scene_karma_k_fox_returns.png','scene_karma_k_pill_cure.png','scene_karma_k_comp_trust.png','scene_karma_k_faction_peace.png','scene_karma_k_echo_karma_chain.png'],
      grudge:   ['scene_karma_k_betrayed_npc.png','scene_karma_k_combat_scar.png','scene_karma_k_pill_poison.png','scene_karma_k_faction_uprising.png','scene_karma_k_lifespan_waste.png'],
      bloodline:['scene_karma_k_body_ascension.png','scene_karma_k_body_echo.png','scene_karma_k_comp_sacrifice.png','scene_karma_k_echo_past_life.png'],
      fate:     ['scene_karma_k_fortune_wheel.png','scene_karma_k_tianshu_echo.png','scene_karma_k_tianshu_revelation.png','scene_karma_k_echo_path_mastery.png']
    };
    const sceneFiles = sceneMap[seedType] || sceneMap.karma;
    const imagePath = `assets/cards/events/${sceneFiles[Math.floor(Math.random() * sceneFiles.length)]}`;

    // 提取关联NPC名称
    const seedToNpc = {
      foxGratitude: '九尾溯月', foxReturns: '九尾溯月',
      compSacrifice: '白落霜', compTrust: '白落霜',
      swordLegacyStarted: '剑无悔', swordHonor: '剑无悔', swordLegacyEcho: '剑无悔',
      spellCodexStarted: '慕青岚', spellCodexRefused: '慕青岚',
      pillMasterStarted: '殷血', pillMasterEcho: '殷血',
      bodyAscension: '血煞老祖', lifespanWaste: '血煞老祖',
      destinyPromise: '天机老人', tianshuEcho: '天机老人',
    };
    const npcName = seedToNpc[seed.id] || null;

    const ripple = {
      type: 'KARMA_RIPPLE',
      title: tpl.title,
      description: tpl.description,
      seedId: seed.id,
      seedType: seedType,
      rippleTurn: turn,
      imagePath: imagePath,
      npcName: npcName,
      choices: {
        left: {
          text: tpl.leftText || '顺势而为',
          effects: tpl.leftEffects || { cultivation: 5, daoHeart: 2 }
        },
        right: {
          text: tpl.rightText || '逆天改命',
          effects: tpl.rightEffects || { daoHeart: 5, cultivation: 3 }
        }
      }
    };

    // 记录涟漪历史
    this._history.push({ turn, seedId: seed.id, seedType, text: tpl.title });
    if (this.onLog) this.onLog(`🌊 因果涟漪：${tpl.title}`);

    return ripple;
  }

  /**
   * 涟漪叙事模板库
   */
  _rippleTemplates() {
    return {
      karma: [
        {
          title: '善因回响',
          description: '昔日援手之人，今日登门报恩。你感受到一股暖流在经脉中回荡——那是因果之力，迟来的回响。',
          leftText: '接受回报，积累福缘',
          rightText: '婉拒好意，修心养性',
          leftEffects: { cultivation: 8, fortune: 3, spiritStone: 50 },
          rightEffects: { daoHeart: 8, cultivation: 4 }
        },
        {
          title: '前人栽树',
          description: '你曾在荒山种下的一株灵草，如今已成一片灵田。路过的散修代为照料，如今前来拜谢。',
          leftText: '收下灵田产出',
          rightText: '将灵田赠予散修',
          leftEffects: { cultivation: 10, spiritStone: 80 },
          rightEffects: { daoHeart: 6, fortune: 5, karmaGood: 3 }
        },
        {
          title: '旧恩新果',
          description: '当年救下的白狐，如今修得人形，携灵药来访。因果循环，报应不爽——善缘终有善果。',
          leftText: '接受灵药',
          rightText: '祝福她仙途坦荡',
          leftEffects: { cultivation: 12, pill: '聚灵丹' },
          rightEffects: { daoHeart: 5, fortune: 8 }
        },
        {
          title: '九尾报恩',
          description: '九尾溯月托一只小狐送来口信："你当年在雷雨夜救的那条白狐，现在已经修得九尾。她说她欠你一条命——不是命债，是因果。"一截白尾毫落在你手心——那是狐狸最珍贵的信物。',
          leftText: '收下尾毫——这是她的心意',
          rightText: '托小狐送回——"我不需要回报"',
          leftEffects: { fortune: 12, spiritStone: 100, daoHeart: 5 },
          rightEffects: { daoHeart: 15, karmaGood: 5 }
        },
        {
          title: '雪落无声',
          description: '白落霜在你闭关的石室外，放了一副暖玉手套。没有留字，没有声响——但你出关时，手套还是温热的。她知道你要渡寒关，却从不说破。',
          leftText: '戴上手套入寒关',
          rightText: '将手套收好，靠自己渡关',
          leftEffects: { cultivation: 15, daoHeart: 10, health: 8 },
          rightEffects: { cultivation: 20, daoHeart: 5 }
        },
        {
          title: '以命换命丹',
          description: '殷血派人送来一颗血色丹药——那是他以自身精血为引炼制的续命丹。传话的人说："师父说，你活着比这丹值钱。"',
          leftText: '服下续命丹',
          rightText: '将丹药送回——"让他自己留着"',
          leftEffects: { cultivation: 20, maxHp: 10, health: 20 },
          rightEffects: { daoHeart: 15, fortune: 10 }
        },
        {
          title: '剑痕作铭',
          description: '剑无悔在你练剑的地方留下一道剑痕——那是他的独门剑式。没有言语教导，只有这一剑让你自行领悟。剑痕旁刻了一行小字：剑非杀人之器，乃证道之心。',
          leftText: '参悟剑痕，精研剑式',
          rightText: '不学他人剑，走自己的道',
          leftEffects: { cultivation: 15, daoHeart: 8, combatBoost: 3 },
          rightEffects: { daoHeart: 15, cultivation: 8 }
        },
        {
          title: '星辉入梦',
          description: '慕青岚在你识海中留下一缕星辉——她说：若你迷途，星辉会指路。不是她指路，是星辉自己认得你。',
          leftText: '收下星辉，留作护身',
          rightText: '化入识海——转化成自悟之光',
          leftEffects: { daoHeart: 15, fortune: 10, cultivation: 5 },
          rightEffects: { cultivation: 12, daoHeart: 12 }
        }
      ],
      grudge: [
        {
          title: '恶因反噬',
          description: '昔日结下的仇怨，如今化作暗流涌来。有人在你突破的关键时刻布下陷阱——因果从不遗忘。',
          leftText: '硬闯陷阱',
          rightText: '绕道而行',
          leftEffects: { cultivation: 8, daoHeart: -3, karmaBad: 3 },
          rightEffects: { daoHeart: 3, cultivation: -2, fortune: -1 }
        },
        {
          title: '仇人登门',
          description: '旧日仇敌纠集同门前来寻仇。血煞之气弥漫，周围草木枯萎——恶业终须面对。',
          leftText: '以力破敌',
          rightText: '以理服人',
          leftEffects: { cultivation: 10, karmaBad: 5, spiritStone: 100 },
          rightEffects: { daoHeart: 5, fortune: 2, karmaGood: 3 }
        },
        {
          title: '血煞觊觎',
          description: '血煞老祖的目光从深渊中投来——你体内的经脉共振了。他闻到了恶因的味道，像鲨鱼闻到了血。他说："加入我——你天生适合魔道。"',
          leftText: '断然拒绝——修魔非我本意',
          rightText: '试探——"你说说条件"',
          leftEffects: { daoHeart: 20, karmaGood: 5, cultivation: 8 },
          rightEffects: { cultivation: 12, daoHeart: -5, karmaBad: 8 }
        },
        {
          title: '因果黑洞',
          description: '有一件你没做完的事，正在吞噬周围的因果——就像星空中突然出现了一个黑洞。其他的因果种子都在绕着它旋转、被拉扯。无常在低声警告：有些债，拖不得。',
          leftText: '立刻去寻找欠债之人',
          rightText: '等待——让因果自会清算',
          leftEffects: { daoHeart: 10, fortune: 5, cultivation: -3 },
          rightEffects: { cultivation: 8, karmaBad: 10, daoHeart: -8 }
        }
      ],
      bloodline: [
        {
          title: '血脉感应',
          description: '血脉深处传来悸动——与你血脉相连的某位存在，正在召唤你。命运的丝线在虚空中震动。',
          leftText: '回应召唤',
          rightText: '压制感应',
          leftEffects: { cultivation: 15, maxHp: 5, daoHeart: -2 },
          rightEffects: { daoHeart: 8, cultivation: 3 }
        },
        {
          title: '羁绊之音',
          description: '与你有深厚羁绊的人正在经历劫难。你的心口莫名刺痛——羁绊是一把双刃剑。',
          leftText: '远程传送援助',
          rightText: '相信对方能渡过',
          leftEffects: { cultivation: -5, daoHeart: 10, fortune: 5 },
          rightEffects: { daoHeart: -3, cultivation: 5, karmaBad: 2 }
        },
        {
          title: '混沌共鸣',
          description: '你体内的混沌漏洞体质突然躁动——这不是病，是共鸣。另一个混沌体质者正在附近经历天劫。混沌体质在仙道上稀有到万里无一，但现在两个混沌体同在一个时辰内——这不可能是巧合。',
          leftText: '前往天劫方向——看看是谁',
          rightText: '守好自己的关——各人自渡',
          leftEffects: { cultivation: 10, daoHeart: -3, fortune: 8 },
          rightEffects: { daoHeart: 15, cultivation: 5 }
        },
        {
          title: '三脉残根觉醒',
          description: '三脉残根——剑脉残、丹脉残、阵脉残——这本是天生的残缺。但今天，三道残根同时在你的丹田中震动，像三根琴弦被同一只手拨动。有人在远方弹奏了这首"残根歌"。',
          leftText: '追寻琴音的来源',
          rightText: '以修行淬炼残根——化为己用',
          leftEffects: { fortune: 15, cultivation: 5, daoHeart: -3 },
          rightEffects: { cultivation: 20, daoHeart: 10 }
        }
      ],
      fate: [
        {
          title: '命运涟漪',
          description: '天机盘上，你的命星微微闪烁。天道注意到了一枚因果种子的异常——你的选择将改变命运纹理。',
          leftText: '拥抱命运的馈赠',
          rightText: '斩断命运的枷锁',
          leftEffects: { cultivation: 20, fortune: 10, daoHeart: -5 },
          rightEffects: { daoHeart: 15, fortune: -3, cultivation: 5 }
        },
        {
          title: '天机老人口谕',
          description: '天机老人破例给你传了一道口谕——不是预言，是警告："你命中有一次必死的劫——不是寿元尽了，是天劫要你死。唯一破法：在劫降临前，找到三个真心为你流泪的人。"他咳了一声："我只是传话——你信不信，你自己定。"',
          leftText: '记下——"三个人，我会找到"',
          rightText: '冷笑——"天道若要杀我，三个人拦不住"',
          leftEffects: { daoHeart: 25, fortune: 15, cultivation: 10 },
          rightEffects: { cultivation: 20, daoHeart: 15, fortune: -5 }
        },
        {
          title: '星辰重排',
          description: '今夜没有月亮——但所有的星辰都亮了。而且它们不在原来的位置上。天机盘疯狂旋转，吐出一个荒谬的结论：你不是"命定之人"，你是一个"漏洞"——天道没想到你会存在。你的一切因果，天道都没有预案。',
          leftText: '欣喜——无宿命即是最大的自由',
          rightText: '警惕——天道不会容忍漏洞太久',
          leftEffects: { daoHeart: 30, fortune: 20, cultivation: 10 },
          rightEffects: { cultivation: 25, daoHeart: 10, fortune: 5 }
        }
      ]
    };
  }

  /**
   * 获取涟漪历史（用于UI日志）
   */
  getHistory() {
    return [...this._history];
  }

  /**
   * 获取状态（供外部查询）
   */
  getState() {
    return {
      cooldownTurns: this._cooldownTurns,
      lastRippleTurn: this._lastRippleTurn,
      totalRipples: this._history.length
    };
  }
}

// 全局单例
const karmaRippleSystem = new KarmaRippleSystem();
