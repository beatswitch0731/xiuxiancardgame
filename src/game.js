/**
 * GameLogic - 游戏主逻辑（系统编排器）
 *
 * 负责协调所有子系统，处理核心游戏流程。
 * 不直接操作数据——所有状态变更通过 GameStateManager，
 * 抽卡通过 CardSystem，因果通过 KarmaSystem。
 */
class GameLogic {
  constructor(deps = {}) {
    // 依赖注入（核心状态/事件仍保留全局回退，服务与协调器必须注入）
    this.gameState = deps.gameState || gameState;
    this.eventBus = deps.eventBus || eventBus;
    this.effectService = deps.effectService || null;
    this.combatCoordinator = deps.combatCoordinator || null;
    this.debug = deps.debug !== false;

    this.onLog = null;
    this.onUpdate = null;
    this.currentCard = null;
    // 暂存支线推进后的下一张卡ID（由 QuestSystem 通过 quest:advanced 事件注入）
    this._questNextCardId = null;
    // ── v2.0 上瘾引擎暂存 ──
    this._pendingRipple = null;
    this._pendingHint = null;
    this._pendingMarket = null;
    this._innerDemonActive = false;
    // ── 沉浸 v2.0 心念系统 ──
    this._innerVoiceCooldown = 0;
    this._prevAttrSnap = null; // 上一轮属性快照，用于检测变化
    // ── 沉浸 v2.0 P2：世界事件 ──
    this._lastWorldEventTurn = 0;
    // ── 叙事系统卡牌注入队列（优先级队列，高优先级先出）──
    this._narrativeQueue = [];
    // ── 境界章节主线里程碑 ──
    this._chapterMilestoneCard = null;
    // ── 新手引导教程队列 ──
    this._tutorialCardIds = ['tutorial_1', 'tutorial_2', 'tutorial_3', 'tutorial_4'];

    if (this.debug) console.log('[GameLogic] constructed with deps:', Object.keys(deps));
  }

  /** 世界事件触发间隔（回合） */
  static WORLD_EVENT_INTERVAL = 12;

  /**
   * 世界事件池 —— 让玩家感受到"天下不止我一个人在修仙"
   * 
   * 格式: { text, realmGate, tags }
   *   realmGate: null=任意境界, 境界名=需达到该境界才触发
   *   tags: 用于未来因果种子挂钩（death/treasure/war/secret/monster 等）
   */
  static WORLD_EVENTS = [
    // === 通用事件（任意境界） ===
    { text: '\u4e1c\u6d77\u8fdc\u6d77\u4f20\u6765\u6d88\u606f\uff1a\u9f99\u5bab\u5f00\u542f\u4e07\u5e74\u4e00\u5ea6\u7684\u9f99\u95e8\u5927\u4f1a\uff0c\u5404\u8def\u5929\u624d\u6b63\u5728\u8d76\u5f80\u3002', tags: ['event'] },
    { text: '\u5bd2\u5c71\u5251\u5b97\u7684\u4e00\u4f4d\u957f\u8001\u5750\u5316\uff0c\u4e34\u7ec8\u7559\u4e0b\u4e86\u4e00\u9053\u5251\u610f\u2026\u2026\u4f46\u6ca1\u4eba\u80fd\u53c2\u900f\u3002', tags: ['legacy'] },
    { text: '\u897f\u57df\u6c99\u6d77\u4e2d\u53d1\u73b0\u4e86\u4e00\u5ea7\u4e0a\u53e4\u4fee\u58eb\u7684\u6d1e\u5e9c\u9057\u5740\uff0c\u6563\u4fee\u4eec\u8702\u62e5\u800c\u81f3\u3002', tags: ['treasure'] },
    { text: '\u4e91\u96fe\u5c71\u8109\u6df1\u5904\u4f20\u6765\u5f02\u52a8\uff0c\u636e\u8bf4\u662f\u4e00\u5934\u6c89\u7761\u5343\u5e74\u7684\u5996\u517d\u82cf\u9192\u4e86\u3002', tags: ['monster'] },
    { text: '\u4e39\u5b97\u516c\u5e03\u4e86\u65b0\u7684\u7ec3\u4e39\u6cd5\u95e8\uff0c\u636e\u8bf4\u80fd\u5c06\u6210\u4e39\u7387\u63d0\u5347\u4e09\u6210\u3002\u5382\u5e02\u4e0a\u7075\u8349\u4ef7\u683c\u987f\u65f6\u98d9\u5347\u3002', tags: ['economy'] },
    { text: '\u5317\u57df\u7687\u671d\u5185\u4e71\uff0c\u4e09\u4f4d\u7687\u5b50\u4e89\u4f4d\uff0c\u8fde\u5e26\u7740\u51e0\u4e2a\u4fee\u4ed9\u5b97\u95e8\u4e5f\u5377\u4e86\u8fdb\u53bb\u3002', tags: ['politics'] },
    { text: '\u5929\u666f\u57ce\u4eca\u65e5\u6765\u4e86\u4e00\u4f4d\u795e\u79d8\u5546\u4eba\uff0c\u8bf4\u662f\u624b\u91cc\u6709\u4e00\u5f20\u4e0a\u53e4\u6d1e\u5e9c\u7684\u5730\u56fe\u2026\u2026\u4f46\u8981\u4ef7\u5341\u4e07\u7075\u77f3\u3002', tags: ['secret'] },
    { text: '\u84ec\u83b1\u4ed9\u5c9b\u7684\u4f7f\u8005\u62b5\u8fbe\u5927\u9646\uff0c\u5e26\u6765\u4e86\u6d77\u5916\u4fee\u58eb\u7684\u6cd5\u95e8\u4e0e\u602a\u5f02\u6d77\u517d\u7684\u6d88\u606f\u3002', tags: ['exploration'] },
    { text: '\u5357\u7586\u51fa\u73b0\u5929\u8c61\u5f02\u53d8\uff0c\u4e00\u9897\u6d41\u661f\u753b\u8fc7\u5929\u9645\u2014\u2014\u5929\u673a\u8001\u4eba\u95ed\u5173\u4e0d\u51fa\uff0c\u65e0\u4eba\u80fd\u89e3\u8bfb\u8fd9\u662f\u5409\u662f\u51f6\u3002', tags: ['omen'] },
    { text: '\u6668\u96fe\u5c71\u5e02\u7684\u4fe1\u4f7f\u5e26\u6765\u4e86\u4e00\u5219\u60ca\u4eba\u6d88\u606f\uff1a\u6709\u4eba\u5728\u6df1\u6e0a\u4e2d\u53d1\u73b0\u4e86\u6d3b\u7740\u7684\u9b54\u4fee\u2026\u2026\u800c\u90a3\u4e2a\u9b54\u4fee\u5df2\u7ecf\u6d3b\u4e86\u4e94\u767e\u5e74\u3002', tags: ['ancient'] },
    // === 筑基后解锁 ===
    { text: '\u5929\u5251\u5b97\u5e7f\u53d1\u82f1\u96c4\u5e16\uff0c\u9080\u8bf7\u5404\u5730\u5251\u4fee\u524d\u5f80\u53c2\u52a0\u201c\u5929\u5251\u5927\u6bd4\u201d\uff0c\u5934\u7b79\u636e\u8bf4\u662f\u4e00\u67c4\u4ed9\u5251\u3002', realmGate: '\u7b51\u57fa\u671f', tags: ['tournament'] },
    { text: '\u7ec3\u4e39\u5e08\u8054\u76df\u5ba3\u5e03\u53d1\u73b0\u4e86\u65b0\u7684\u4e39\u65b9\u53e4\u7c4d\uff0c\u5176\u4e2d\u8bb0\u8f7d\u4e86\u201c\u592a\u53e4\u56de\u5929\u4e39\u201d\u7684\u70bc\u5236\u65b9\u6cd5\u2014\u2014\u4f46\u6240\u9700\u6750\u6599\u95fb\u6240\u672a\u95fb\u3002', realmGate: '\u7b51\u57fa\u671f', tags: ['pill'] },
    // === 金丹后解锁 ===
    { text: '\u4e94\u884c\u5b97\u516c\u5e03\u4e86\u4e00\u9879\u53d1\u73b0\uff1a\u4e16\u754c\u7684\u7075\u6c14\u6d53\u5ea6\u6b63\u5728\u7f13\u6162\u4e0b\u964d\u3002\u6709\u4eba\u8bf4\u8fd9\u662f\u5929\u5730\u5927\u52ab\u7684\u524d\u5146\u3002', realmGate: '\u91d1\u4e39\u671f', tags: ['crisis'] },
    { text: '\u4f20\u95fb\u4e2d\u7684\u201c\u665a\u5c9a\u5723\u5730\u201d\u51fa\u73b0\u5728\u4e86\u4e1c\u65b9\u7684\u6d77\u5c7f\u4e0a\u2014\u2014\u636e\u8bf4\u8fdb\u5165\u5176\u4e2d\u7684\u4eba\uff0c\u51fa\u6765\u540e\u4fee\u4e3a\u5927\u6da8\uff0c\u4f46\u4e5f\u4f1a\u5931\u53bb\u67d0\u4e9b\u4e1c\u897f\u3002', realmGate: '\u91d1\u4e39\u671f', tags: ['mystery'] },
    // === 元婴后解锁 ===
    { text: '\u4e2d\u5dde\u7684\u4e03\u5927\u5b97\u95e8\u8054\u5408\u53d1\u5e03\u201c\u8baf\u6740\u4ee4\u201d\uff1a\u6709\u4eba\u5728\u6697\u4e2d\u63a8\u52a8\u6b63\u9b54\u5927\u6218\uff0c\u60ac\u8d4f\u63d0\u4f9b\u7ebf\u7d22\u8005\u3002', realmGate: '\u5143\u5a74\u671f', tags: ['conspiracy'] },
    { text: '\u592a\u53e4\u9057\u6c11\u2014\u2014\u4e00\u4e2a\u81ea\u79f0\u201c\u592a\u53e4\u5996\u65cf\u201d\u7684\u4eba\u51fa\u73b0\u5728\u4e16\u4eba\u9762\u524d\uff0c\u8bf4\u8981\u8ba8\u56de\u7956\u5148\u7684\u5730\u76d8\u3002', realmGate: '\u5143\u5a74\u671f', tags: ['ancient'] },
    // === 化神后解锁 ===
    { text: '\u5317\u51a5\u6d77\u6df1\u5904\u4f20\u6765\u949f\u58f0\u2014\u2014\u636e\u8bf4\u90a3\u662f\u4e00\u4ef6\u5148\u5929\u7075\u5b9d\u201c\u6d6e\u6ca7\u949f\u201d\u7684\u58f0\u97f3\uff0c\u53ea\u6709\u5929\u5730\u5927\u52ab\u524d\u624d\u4f1a\u54cd\u8d77\u3002', realmGate: '\u5316\u795e\u671f', tags: ['artifact'] },
    { text: '\u4e00\u4f4d\u98de\u5347\u5931\u8d25\u7684\u4fee\u58eb\u5728\u4e34\u6b7b\u524d\u590d\u523b\u4e86\u5929\u9053\u7684\u79d8\u5bc6\u2014\u2014\u4f46\u523b\u5230\u4e00\u534a\u5c31\u8eab\u6b7b\u9053\u6d88\u3002\u523b\u6587\u88ab\u5404\u5927\u5b97\u95e8\u62a2\u593a\u3002', realmGate: '\u5316\u795e\u671f', tags: ['secret','fate'] },
    // === 渡劫后解锁 ===
    { text: '\u5929\u5730\u8272\u53d8\u3002\u4e09\u5341\u5e74\u524d\u98de\u5347\u7684\u90a3\u4f4d\u4ed9\u4eba\u2026\u2026\u56de\u6765\u4e86\u3002\u4f46\u4ed6\u770b\u8d77\u6765\u4e0d\u50cf\u4ed9\u4eba\u3002\u50cf\u662f\u2026\u2026\u9003\u56de\u6765\u7684\u3002', realmGate: '\u6e21\u52ab\u671f', tags: ['terrifying','fate'] },
    { text: '\u6709\u4eba\u5728\u5929\u9645\u770b\u5230\u4e86\u4e00\u5ea7\u6d6e\u7a7a\u57ce\u3002\u57ce\u5899\u4e0a\u523b\u7740\u4e00\u53e5\u8bdd\uff1a\u201c\u5929\u9053\u5df2\u6b7b\uff0c\u4ed9\u4eba\u5f53\u7acb\u201d\u3002\u6ca1\u4eba\u77e5\u9053\u662f\u8c01\u523b\u7684\u3002', realmGate: '\u6e21\u52ab\u671f', tags: ['revelation'] },
  ];

  // ============ 沉浸 v2.0：心念系统（内心独白） ============

  /** @type {Object<string, string[]>} */
  static INNER_VOICES = {
    breakthrough_success: [
      "\u4e39\u7530\u5185\u7075\u6c14\u5982\u6f6e\u6c50\u3002\u6211\u611f\u5230\u81ea\u5df1\u2026\u2026\u53d8\u4e86\u3002",
      "\u8f70\u2014\u2014\u50cf\u662f\u4e00\u6247\u95e8\u88ab\u649e\u5f00\u3002\u95e8\u540e\uff0c\u662f\u5168\u65b0\u7684\u5929\u5730\u3002",
      "\u539f\u6765\u7a81\u7834\u7684\u611f\u89c9\u662f\u8fd9\u6837\u7684\u3002\u4e0d\u662f\u53d8\u5f3a\uff0c\u662f\u53d8\u5f97\u2026\u2026\u5b8c\u6574\u4e86\u3002"
    ],
    breakthrough_fail: [
      "\u4e39\u7530\u50cf\u788e\u88c2\u7684\u74f7\u5668\u3002\u4f46\u88c2\u75d5\u91cc\uff0c\u6709\u91d1\u8272\u7684\u5149\u900f\u51fa\u6765\u3002",
      "\u53c8\u5931\u8d25\u4e86\u3002\u7b2c\u4e09\u6b21\u4e86\u3002\u6211\u54ac\u7740\u7259\u5bf9\u81ea\u5df1\u8bf4\uff1a\u7b2c\u56db\u6b21\uff0c\u4e00\u5b9a\u6210\u3002",
      "\u75bc\u3002\u4f46\u75bc\u8bf4\u660e\u6211\u8fd8\u6d3b\u7740\u3002\u6d3b\u7740\u7684\u4fee\u58eb\uff0c\u6ca1\u6709\u653e\u5f03\u7684\u8d44\u683c\u3002"
    ],
    near_death: [
      "\u8840\u4ece\u5634\u89d2\u6d41\u4e0b\u6765\u3002\u539f\u6765\u4fee\u58eb\u7684\u8840\uff0c\u4e5f\u662f\u54b8\u7684\u3002",
      "\u773c\u524d\u53d1\u9ed1\u3002\u4f46\u6211\u8fd8\u80fd\u770b\u89c1\u90a3\u6761\u8def\u2014\u2014\u90a3\u6761\u5411\u4e0a\u7684\u8def\u3002",
      "\u547d\u60ac\u4e00\u7ebf\u3002\u5947\u602a\u7684\u662f\uff0c\u6211\u53cd\u800c\u4e0d\u6015\u4e86\u3002"
    ],
    meet_companion: [
      "\u5979\u770b\u6211\u7684\u773c\u795e\u91cc\u6709\u4e00\u79cd\u8bf4\u4e0d\u6e05\u7684\u4e1c\u897f\u3002\u50cf\u662f\u2026\u2026\u597d\u5947\u3002",
      "\u539f\u6765\u4fee\u4ed9\u8def\u4e0a\uff0c\u4e5f\u4f1a\u9047\u89c1\u8fd9\u6837\u7684\u4eba\u3002\u4f1a\u5728\u4f60\u8f6c\u8eab\u7684\u65f6\u5019\uff0c\u8ddf\u7740\u4f60\u8d70\u3002"
    ],
    karma_good_surge: [
      "\u6211\u505a\u4e86\u4e00\u4ef6\u597d\u4e8b\u3002\u4e0d\u77e5\u9053\u4e3a\u4ec0\u4e48\uff0c\u5fc3\u91cc\u6696\u6696\u7684\u3002\u8fd9\u5c31\u662f\u2026\u2026\u5584\u56e0\u5417\uff1f",
      "\u638c\u5fc3\u53d1\u71c3\u3002\u4ed9\u9014\u4e0d\u53ea\u662f\u4e89\u3002\u6709\u65f6\u5019\uff0c\u4e5f\u662f\u5b88\u62a4\u3002"
    ],
    karma_bad_surge: [
      "\u6211\u7684\u624b\u5728\u6296\u3002\u4e0d\u662f\u6015\u2014\u2014\u662f\u5174\u594b\u3002\u539f\u6765\u8d70\u8fd9\u6761\u8def\uff0c\u4f1a\u8ba9\u4eba\u2026\u2026\u6d3b\u8fc7\u6765\u3002",
      "\u6709\u4eba\u8bf4\u4fee\u4ed9\u8981\u65ad\u60c5\u7edd\u6b32\u3002\u6211\u89c9\u5f97\u4e0d\u5bf9\u3002\u60c5\u611f\u672c\u8eab\uff0c\u5c31\u662f\u529b\u91cf\u3002",
      "\u6076\u56e0\u50cf\u4e00\u6761\u86c7\uff0c\u7f20\u4e0a\u4e86\u6211\u7684\u810a\u690e\u3002\u4f46\u5b83\u662f\u6e29\u70ed\u7684\u3002"
    ],
    combat_victory: [
      "\u4ed6\u5012\u4e0b\u4e86\u3002\u6211\u7684\u5251\u8fd8\u5728\u9e23\u53eb\u3002\u8fd9\u5c31\u662f\u2026\u2026\u751f\u5b58\u7684\u6ecb\u5473\u3002",
      "\u80dc\u5229\u4e86\u3002\u4f46\u6211\u77e5\u9053\uff0c\u4e0b\u4e00\u4e2a\u654c\u4eba\u4f1a\u66f4\u5f3a\u3002\u8fd9\u5c31\u662f\u4fee\u4ed9\u3002"
    ],
    dao_heart_crack: [
      "\u9053\u5fc3\u52a8\u6447\u4e86\u3002\u6211\u7591\u60d1\u4e86\u4e00\u77ac\u2014\u2014\u6211\u5230\u5e95\u5728\u8d70\u4ec0\u4e48\u8def\uff1f",
      "\u4fe1\u5ff5\u50cf\u6c99\u5821\u4e00\u6837\u5d29\u584c\u4e86\u4e00\u89d2\u3002\u4f46\u6211\u8fd8\u7ad9\u7740\u3002\u53ea\u8981\u8fd8\u7ad9\u7740\uff0c\u5c31\u80fd\u91cd\u5efa\u3002"
    ]
  };

  /**
   * 触发内心独白
   * @param {string} category - 心念类别
   * @param {number} [forceChance] - 强制概率 (0-1)
   */
  _triggerInnerVoice(category, forceChance) {
    if (this._innerVoiceCooldown > 0) return;
    const voices = GameLogic.INNER_VOICES[category];
    if (!voices || voices.length === 0) return;
    const chance = forceChance !== undefined ? forceChance : 0.7;
    if (Math.random() > chance) return;
    const voice = voices[Math.floor(Math.random() * voices.length)];
    this._log(`\u300c${voice}\u300d`, 'inner-voice');
    this._innerVoiceCooldown = 3;
  }

  /**
   * 拍摄属性快照（用于检测大幅变化）
   */
  _snapshotAttrs() {
    this._prevAttrSnap = {
      cultivation: gameState.attributes.cultivation,
      daoHeart: gameState.attributes.daoHeart,
      karmaGood: gameState.attributes.karmaGood,
      karmaBad: gameState.attributes.karmaBad,
      health: gameState.attributes.health
    };
  }

  /**
   * 检测属性大幅变化并触发心念
   */
  _checkAttrSurges() {
    if (!this._prevAttrSnap) return;
    const curr = {
      cultivation: gameState.attributes.cultivation,
      daoHeart: gameState.attributes.daoHeart,
      karmaGood: gameState.attributes.karmaGood,
      karmaBad: gameState.attributes.karmaBad,
      health: gameState.attributes.health
    };

    // 修为暴涨
    if (curr.cultivation - this._prevAttrSnap.cultivation >= 15) {
      this._triggerInnerVoice('breakthrough_success', 0.7);
    }
    // 道心重创
    if (this._prevAttrSnap.daoHeart - curr.daoHeart >= 10) {
      this._triggerInnerVoice('dao_heart_crack', 0.8);
    }
    // 善因激增
    if (curr.karmaGood - this._prevAttrSnap.karmaGood >= 10) {
      this._triggerInnerVoice('karma_good_surge', 0.6);
    }
    // 恶因激增
    if (curr.karmaBad - this._prevAttrSnap.karmaBad >= 10) {
      this._triggerInnerVoice('karma_bad_surge', 0.6);
    }
  }

  init() {
    // 初始化卡牌系统（预加载炼气+筑基）
    cardSystem.init();

    // 初始化因果系统
    karmaSystem.init();

    // 初始化法宝系统
    treasureSystem.init();

    // 初始化功法技能系统
    pathSkillSystem.init();

    // 初始化战斗系统
    if (typeof deckCombatSystem !== 'undefined') {
        deckCombatSystem.init();
    }

    // 初始化商店系统
    if (typeof shopSystem !== 'undefined' && shopSystem) {
      shopSystem.init();
    }

    // 初始化支线系统并加载支线数据
    questSystem.init();

    // 尝试加载支线数据
    const whiteFoxData = dataLoader.loadSync('quests:white_fox');
    if (whiteFoxData) {
      questSystem.loadQuest(whiteFoxData);
    }
    const tianshuData = dataLoader.loadSync('quests:tianshu_codex');
    if (tianshuData) {
      questSystem.loadQuest(tianshuData);
    }
    const bodyTrialData = dataLoader.loadSync('quests:body_tribulation');
    if (bodyTrialData) {
      questSystem.loadQuest(bodyTrialData);
    }
    const swordLegacyData = dataLoader.loadSync('quests:sword_legacy');
    if (swordLegacyData) {
      questSystem.loadQuest(swordLegacyData);
    }
    const spellCodexData = dataLoader.loadSync('quests:spell_codex');
    if (spellCodexData) {
      questSystem.loadQuest(spellCodexData);
    }
    const pillMasterData2 = dataLoader.loadSync('quests:pill_master');
    if (pillMasterData2) {
      questSystem.loadQuest(pillMasterData2);
    }

    // 初始化剧情网系统（叙事元系统）
    if (typeof storyNetworkSystem !== 'undefined' && storyNetworkSystem) {
      storyNetworkSystem.init();
    }

    // ── v2.0 上瘾引擎初始化 ──
    if (typeof destinyWheelSystem !== 'undefined' && destinyWheelSystem) {
      destinyWheelSystem.init();
      destinyWheelSystem.onLog = (msg) => this._log(msg);
    }
    if (typeof legacyFragmentSystem !== 'undefined' && legacyFragmentSystem) {
      legacyFragmentSystem.init();
      legacyFragmentSystem.onLog = (msg) => this._log(msg);
    }
    if (typeof karmaRippleSystem !== 'undefined' && karmaRippleSystem) {
      karmaRippleSystem.init();
      karmaRippleSystem.onLog = (msg) => this._log(msg);
    }
    if (typeof heavensHintSystem !== 'undefined' && heavensHintSystem) {
      heavensHintSystem.init();
      heavensHintSystem.onLog = (msg) => this._log(msg);
    }
    if (typeof marketSystem !== 'undefined' && marketSystem) {
      marketSystem.init();
      marketSystem.onLog = (msg) => this._log(msg);
    }

    // 初始化配置
    const realmsConfig = dataLoader.loadSync('config:realms');
    const pathsConfig = dataLoader.loadSync('config:paths');
    gameState.init({
      realms: realmsConfig,
      paths: pathsConfig
    });

    // 初始化 FlowDirector 核心调度
    if (typeof flowDirector !== 'undefined' && flowDirector) {
      flowDirector.init();
    }

    // FIX-1: 接通位置/场景系统 — 加载位置数据并设置初始位置
    if (typeof sceneLayerSystem !== 'undefined' && sceneLayerSystem) {
      const locData = dataLoader.loadSync('locations:locations');
      if (locData) {
        sceneLayerSystem.loadData(locData);
      }
      // 游戏开局默认位置：宗门
      sceneLayerSystem.transition('宗门', 'game_start');
    }

    // ── 道侣沉浸 v2.5：初始化随身 HUD ──
    if (typeof ui !== 'undefined' && ui && typeof ui.initCompanionHUD === 'function') {
      ui.initCompanionHUD();
    }

    // 监听事件
    this.eventBus.on('state:death', (data) => this._onDeath(data));
    this.eventBus.on('game:restart', () => {
      this.start(gameState.path || 'sword');
    });
    // 终极结局事件：EffectService 触发后，切换到对应结局卡
    this.eventBus.on('game:ending', (data) => {
      const endingCardId = 'ending_' + (data.endingType || 'ascension');
      const endingCard = cardSystem.getCard(endingCardId);
      if (endingCard) {
        this.currentCard = endingCard;
        this._log(`【仙途终局】进入结局：${endingCard.title}`);
      } else {
        // 安全兜底：找不到卡直接用飞升结局
        this.currentCard = cardSystem.getCard('ending_ascension');
        this._log('【仙途终局】结局卡未找到，回退至飞升结局');
      }
      this._triggerUpdate();
    });
    this.eventBus.on('quest:triggered', (data) => this._onQuestTriggered(data));
    this.eventBus.on('quest:completed', (data) => this._onQuestCompleted(data));
    // 支线推进事件：暂存下一张卡ID，避免依赖 choice.nextCard 的数据污染
    this.eventBus.on('quest:advanced', (data) => {
      this._questNextCardId = data.nextCardId || null;
    });
    this.eventBus.on('karma:seedPlanted', (data) => this._onKarmaSeedPlanted(data));
    this.eventBus.on('combat:victory', (data) => this.combatCoordinator.onVictory(data));
    this.eventBus.on('combat:defeat', (data) => this.combatCoordinator.onDefeat(data));
    this.eventBus.on('combat:fled', (data) => this.combatCoordinator.onFled(data));
    // 【故事线程】引擎日志 → 游戏日志区
    this.eventBus.on('game:log', (msg) => this._log(msg));

    // 【商店系统】商店关闭后继续卡牌流
    this.eventBus.on('shop:closed', () => {
      this.currentCard = null;
      this._triggerUpdate();
    });

    // ── 叙事连贯性层（效果叙事 + 卡牌过渡 + 交叉引用）──
    if (typeof coherenceLayer !== 'undefined' && coherenceLayer) {
      coherenceLayer.init();
    }

    // ── 境界章节系统：加载里程碑数据并初始化 ──
    if (typeof chapterSystem !== 'undefined' && chapterSystem) {
      try {
        const milestoneData = dataLoader.loadSync('cards:chapter_milestones');
        if (milestoneData) {
          chapterSystem.init(milestoneData);
          this._log('【章节】六章主线已就绪。');
        } else {
          this._log('[系统] 里程碑卡牌数据加载失败，章节系统降级。');
        }
      } catch (e) {
        this._log('[系统] 章节系统初始化异常：' + e.message);
      }
    }

    // ── 叙事系统事件监听 ──
    // storyNetworkSystem、companionSystem、factionSystem、npcSystem 发出的叙事卡注入主卡牌流
    // 使用优先级队列：高优先级叙事卡（arc高潮）优先于低优先级（NPC遭遇）
    const _pushNarrative = (data) => {
      if (!data || !data.card) return; // null card = "本次无叙事事件"
      if (!this._narrativeQueue) this._narrativeQueue = [];
      // data 格式兼容两种：
      //   旧: { card: cardObj, priority: 53 }
      //   新: cardObj (带 _narrativePriority)
      const wrapper = data.card ? data : { card: data, priority: 50 };
      this._narrativeQueue.push(wrapper);
      // 按 priority 降序排序（priority越高越优先）
      this._narrativeQueue.sort((a, b) => (b.priority || b._narrativePriority || 0) - (a.priority || a._narrativePriority || 0));
    };
    eventBus.on('storynetwork:narrativeCard', (data) => _pushNarrative(data));
    eventBus.on('companion:eventCard',        (data) => _pushNarrative(data));
    eventBus.on('faction:eventCard',          (data) => _pushNarrative(data));
    eventBus.on('npc:encounterCard',          (data) => _pushNarrative(data));
  }

  /**
   * 开始游戏
   * @param {string} path - 功法路径
   */
  start(path) {
    gameState.reset(true);
    gameState.path = path;
    this._innerVoiceCooldown = 0;
    this._chapterMilestoneCard = null;

    // ── 新手引导：首次游玩注入教程卡 ──
    if (this.isFirstPlay()) {
      const tutorialCard = cardSystem.getCard('tutorial_1');
      if (tutorialCard) {
        this.currentCard = tutorialCard;
        this._log('【引导】初入仙途，请跟随指引了解修仙法则。');
      } else {
        this.currentCard = null;
      }
    } else {
      this.currentCard = null;
    }

    // ── 重置章节系统 ──
    if (typeof chapterSystem !== 'undefined' && chapterSystem) {
      chapterSystem.reset();
    }

    const playerName = gameState.playerName || '\u53f6\u51cc\u4e91';
    this._log(`${playerName}\uff0c\u4ed9\u9014\u4e4b\u8def\uff0c\u81ea\u6b64\u5f00\u59cb\u3002`);
    this._log(`\u4f60\u9009\u62e9\u4e86 ${gameState.getPathName(path)} \u4e4b\u9053\u3002`);
    this._snapshotAttrs();

    // ── 道侣沉浸 v2.5：激活已有道侣到 HUD ──
    this._activateCompanionToHUD();

    // 应用功法加成
    if (gameState.config.paths && gameState.config.paths.paths[path]) {
      const bonuses = gameState.config.paths.paths[path].bonuses;
      if (bonuses) {
        for (const [key, value] of Object.entries(bonuses)) {
          if (key === 'spiritStone') {
            gameState.addResource('spiritStone', null, value);
          } else if (key === 'health') {
            // 微数值模型：如果功法增减血量，同时对应调整上限 maxHealth，防止溢出或降为0
            gameState.maxHealth = Math.max(1, gameState.maxHealth + value);
            gameState.setAttribute('health', gameState.attributes.health + value);
          } else if (key === 'daoHeart') {
            // 微数值模型：如果功法增减道心，同时对应调整上限 maxDaoHeart
            gameState.maxDaoHeart = Math.max(1, gameState.maxDaoHeart + value);
            gameState.setAttribute('daoHeart', gameState.attributes.daoHeart + value);
          } else if (['cultivation', 'fortune'].includes(key)) {
            gameState.addAttribute(key, value);
          }
        }
      }
    }

    this._triggerUpdate();
  }

  /**
   * 检测是否为首次游玩（新手引导判断）
   * 兼容旧存档：已转世或有解锁记录的玩家视为已完成引导
   */
  isFirstPlay() {
    if (gameState.unlocks.tutorialCompleted === true) return false;
    if (gameState.unlocks.tutorialCompleted === false) return true;
    // 旧存档兼容：有转世记录或已解锁卡牌 → 已完成引导
    if ((gameState.unlocks.lifeCount || 0) > 0 || (gameState.unlocks.cards || []).length > 0) {
      gameState.unlocks.tutorialCompleted = true;
      gameState._saveUnlocks();
      return false;
    }
    return true;
  }

  // ============ 抽卡与选择 ============

  /**
   * 获取当前卡牌
   * @returns {Object}
   */
  getCurrentCard() {
    if (this.combatCoordinator && this.combatCoordinator.isInCombat()) {
      return this.combatCoordinator.getCombatCard();
    }

    // ── v2.0 心魔反噬卡 ──
    if (this._innerDemonActive) {
      return this._buildInnerDemonCard();
    }

    // ── v2.0 命盘轮转卡 ──
    if (typeof destinyWheelSystem !== 'undefined' && destinyWheelSystem && destinyWheelSystem.active) {
      return { type: 'DESTINY_WHEEL', wheelState: destinyWheelSystem.getState() };
    }

    // ── FIX-4 秘境图模式下委托 ──
    if (gameState.dungeon) {
      return cardSystem._drawDungeonCard();
    }

    if (!this.currentCard) {
      // ── 天机追踪 (Tianji Pursuit) ──
      if (gameState.getAttribute('tianji') >= 100) {
          gameState.setAttribute('tianji', 0); // 重置
          this._log('【警告】天机泄露，跨界大能锁定了你的气息！');
          this.currentCard = {
              id: 'heaven_pursuit',
              title: '跨界追杀',
              description: '你使用逆天遗物的气息被上界大能察觉。一只遮天蔽日的巨手撕裂虚空，向你抓来！',
              type: 'COMBAT',
              tags: ['combat'],
              enemy: {
                  name: '跨界神念化身',
                  tier: 3,
                  id: 'enemy_sword' // 可以复用高难度 AI
              },
              choices: {
                  left: { text: '迎战', effects: {} },
                  right: { text: '逃遁(无效)', effects: {} }
              }
          };
          return this.currentCard;
      }
      
      // ===== FlowDirector 核心调度 =====
      if (typeof flowDirector !== 'undefined' && flowDirector) {
        this.currentCard = flowDirector.getNextCard();
      } else {
        this.currentCard = cardSystem.draw();
      }
      // ── 安全兜底：极少情况下 draw() 可能返回 null（deathCardMap 空 + 兜底卡也未生成）
      if (!this.currentCard) {
        this._log('[系统] 抽卡池为空，已生成默认事件。');
        this.currentCard = {
          id: 'game_fallback',
          title: '潜心修炼',
          description: '你盘膝而坐，运转周天，吐纳灵气。修行之道，贵在坚持。',
          type: 'NORMAL',
          realm: gameState.realm,
          choices: {
            left: { text: '专注修炼', effects: { exp: 5 }, desc: '稳扎稳打提升修为。' },
            right: { text: '游历散心', effects: { fortune: 1 }, desc: '放松心情，或许会有意外收获。' }
          }
        };
      }

      // FIX-1: 卡牌驱动位置切换 — 如果卡牌指定了 location，切换场景
      if (this.currentCard && this.currentCard.location &&
          typeof sceneLayerSystem !== 'undefined' && sceneLayerSystem) {
        const currentLoc = gameState.currentLocation;
        if (currentLoc !== this.currentCard.location) {
          sceneLayerSystem.transition(this.currentCard.location, 'card_driven');
        }
      }

      // 战斗卡检测：抽到 combat 标签的卡 → 先展示预警卡，再进入战斗
      if (this.currentCard && (this.currentCard.type === 'COMBAT' || (this.currentCard.tags && this.currentCard.tags.includes('combat')))) {
        // FIX-3: 战斗预警机制 — 先展示预警卡，给玩家准备时间
        if (!this.combatCoordinator.hasWarningShown()) {
          const warningCard = this.combatCoordinator.buildCombatWarning(this.currentCard);
          this.currentCard = warningCard;
          return warningCard;
        }
        // 预警卡已展示过，正式进入战斗
        if (!this.currentCard.enemy) {
          this._log('[系统] 战斗状态异常，已自动恢复。');
          return this.currentCard;
        }
        this.combatCoordinator.enterCombat(this.currentCard);
        return this.combatCoordinator.getCombatCard();
      }
    }

    // 【环环相扣：法宝主动效果】为当前卡牌附加法宝主动选项
    if (this.currentCard && typeof treasureSystem !== 'undefined' && treasureSystem) {
      const activeOptions = treasureSystem.getActiveOptions(this.currentCard);
      if (activeOptions.length > 0) {
        // 浅拷贝卡牌对象，附加法宝选项
        const enhancedCard = Object.assign({}, this.currentCard);
        enhancedCard.choices = Object.assign({}, this.currentCard.choices);
        for (const opt of activeOptions) {
          enhancedCard.choices[opt.direction] = {
            text: opt.text,
            effects: opt.effects,
            treasureId: opt.treasureId,
            _treasureOption: true
          };
        }
        enhancedCard._hasTreasureOptions = true;
        return enhancedCard;
      }
    }

    return this.currentCard;
  }

  /**
   * 玩家做出选择
   * @param {string} direction - 'left' | 'right' | 'up' | 'down'
   * @returns {boolean} 选择是否有效
   */
  makeChoice(direction) {
    if (gameState.dead && this.currentCard && !this.currentCard.id.startsWith('death_') && !this.currentCard.id.startsWith('ending_')) return false;

    const card = this.getCurrentCard();

    // ── v2.0 心魔反噬选择处理 ──
    if (card.type === 'INNER_DEMON') {
      this._resolveInnerDemon(direction);
      return true;
    }

    // ── v2.0 命盘轮转选择处理 ──
    if (card.type === 'DESTINY_WHEEL') {
      const idx = { left: 0, right: 1, up: 2, down: 3 }[direction];
      if (idx !== undefined && typeof destinyWheelSystem !== 'undefined') {
        destinyWheelSystem.flipCard(idx);
      }
      this._triggerUpdate();
      return true;
    }




    // ── FIX-3: 战斗预警卡选择处理 ──
    if (card.type === 'COMBAT_WARNING') {
      const warningChoice = card.choices[direction];
      if (!warningChoice) return false;
      // 检查资源（服丹备战需要丹药）
      if (warningChoice.costCheck && !this._checkCost(warningChoice.costCheck)) {
        this._log('丹药不足，无法备战。');
        this._triggerUpdate();
        return false;
      }
      // 应用准备效果（道心加成/丹药回血等）
      if (warningChoice.effects) this._applyEffects(warningChoice.effects);
      if (warningChoice.costCheck && warningChoice.costCheck.spiritStone) {
        gameState.addResource('spiritStone', null, -warningChoice.costCheck.spiritStone);
      }
      // 恢复待战斗的卡牌并进入战斗
      const pendingCombatCard = this.combatCoordinator.getPendingCombatCard();
      if (pendingCombatCard) {
        this.currentCard = pendingCombatCard;
        // 正式进入战斗（fire-and-forget，战斗系统会通过事件通知 UI）
        this.combatCoordinator.enterCombatFromWarning();
        this._triggerUpdate();
        return true;
      }
      this._triggerUpdate();
      return true;
    }

    // ── FIX-4: 秘境分叉选择处理 ──
    if (card.type === 'DUNGEON_FORK') {
      const forkChoice = card.choices[direction];
      if (!forkChoice) return false;
      // 应用路径上的效果 (如有)
      if (forkChoice.effects) this._applyEffects(forkChoice.effects);
      // 推进秘境到玩家选择的目标节点
      if (forkChoice._dungeonForkNext && typeof cardSystem !== 'undefined' && cardSystem) {
        cardSystem.advanceDungeonToFork(card._dungeonNodeId, forkChoice._dungeonForkNext);
        this._log('你选择了：' + forkChoice.text);
      }
      this._triggerUpdate();
      return true;
    }

    const choice = card.choices[direction];
    if (!choice) return false;
    let pauseCardFlow = false;

    // 【沉浸 v2.0】拍快照（在应用效果前）
    this._snapshotAttrs();

    // 商店/营地卡 costCheck: 检查是否付得起
    if (choice.costCheck) {
      if (!this._checkCost(choice.costCheck)) {
        this._log('资源不足，无法进行此操作。');
        this._triggerUpdate();
        return false;
      }
      // 自动扣除 costCheck 中的资源
      if (choice.costCheck.spiritStone) {
        gameState.addResource('spiritStone', null, -choice.costCheck.spiritStone);
      }
      if (choice.costCheck.health) {
        gameState.addAttribute('health', -choice.costCheck.health);
      }
      if (choice.costCheck.karmaGood) {
        gameState.addAttribute('karmaGood', -choice.costCheck.karmaGood);
      }
    }

    // 资源消耗校验：防止灵石/寿元被扣到负数
    if (!this._checkEffectCost(choice.effects)) {
      this._log('资源不足，此选择无法执行。');
      this._triggerUpdate();
      return false;
    }

    // 应用效果
    this._applyEffects(choice.effects);

    // ── 去全局化：选项驱动战斗触发 ──
    if (choice.triggerCombat || (choice.effects && choice.effects.triggerCombat)) {
      const warningCard = this.combatCoordinator.buildCombatWarning(card);
      this.currentCard = warningCard;
      this._triggerUpdate();
      return true;
    }

    // ════════════════════════════════════════
    //  境界章节里程碑检测
    //  修为达到阈值(20/40/60/80/100)时注入对应里程碑卡
    // ════════════════════════════════════════
    if (typeof chapterSystem !== 'undefined' && chapterSystem && chapterSystem._initialized) {
      const cultivation = gameState.getAttribute('cultivation');
      const threshold = chapterSystem.shouldTriggerMilestone(gameState.realm, cultivation);
      if (threshold !== null) {
        const milestoneCard = chapterSystem.getMilestoneCard(gameState.realm, threshold);
        if (milestoneCard) {
          if (typeof flowDirector !== 'undefined' && flowDirector) {
            flowDirector.setMilestone(milestoneCard);
          } else {
            this._chapterMilestoneCard = milestoneCard;
          }
          this._log(
            '【' + chapterSystem.getChapterTitle(gameState.realm) + '】里程碑 ' +
            threshold + ' —— ' + milestoneCard.title
          );
        }
      }
    }

    // 【商店卡】打开商店 UI，暂停卡牌流
    if (choice.openShop) {
      eventBus.emit('shop:open', {
        items: shopSystem ? shopSystem.getAvailableItems(gameState.realm) : []
      });
      // 暂停卡牌流，不推进到下一卡
      pauseCardFlow = true;
    }

    // 【v2.0 集市】打开集市 UI（使用 MarketSystem 预刷商品）
    if (choice.openMarket) {
      if (typeof marketSystem !== 'undefined' && marketSystem) {
        marketSystem._totalVisits++;
        const marketItems = marketSystem.getCurrentMarketItems();
        const fortuneTier = marketSystem.getFortuneTierText();
        const priceMult = marketSystem.getPriceMultiplier();
        eventBus.emit('shop:open', {
          items: marketItems,
          market: true,
          fortuneTier,
          priceMult,
          fortune: gameState.attributes.fortune
        });
      } else {
        eventBus.emit('shop:open', { items: [] });
      }
      pauseCardFlow = true;
    }

    // 种因果种子（支持单个对象、数组、或字符串快捷格式）
    if (choice.karmaSeed) {
      const seeds = Array.isArray(choice.karmaSeed) ? choice.karmaSeed : [choice.karmaSeed];
      for (let seed of seeds) {
        // 兼容字符串快捷格式 "causal:xxx" → 展开为标准对象
        if (typeof seed === 'string') {
          seed = {
            id: seed,
            seedType: 'karma',
            delay: 5,
            priority: 1
          };
        }
        karmaSystem.plantSeed({
          ...seed,
          originCard: card.id,
          originChoice: direction
        });
      }
    }

    // 支线推进
    if (card.type === 'QUEST') {
      questSystem.advanceQuest(direction, card);
    }

    // NPC 遭遇卡：记录好感变化
    if (card.type === 'NPC_ENCOUNTER' && choice.npcAffection !== undefined && card.npcId) {
      npcSystem.addAffection(card.npcId, choice.npcAffection);
      npcSystem.recordInteraction(card.npcId, '\u906d\u9047', choice.text, choice.npcAffection);
      // 【沉浸 v2.0】初次遇到道侣 → 心念
      if (choice.npcAffection > 0 && !gameState.resources.companions.includes(card.npcId)) {
        this._triggerInnerVoice('meet_companion', 0.8);
      }
    }

    // NPC交叉互动卡：处理好感变化（可能影响多个NPC）+ NPC间关系变化
    if (card.type === 'NPC_CROSS' && choice.npcAffection) {
      if (typeof choice.npcAffection === 'object') {
        for (const [npcId, delta] of Object.entries(choice.npcAffection)) {
          npcSystem.addAffection(npcId, delta);
        }
      }
      // npc_relation 效果由 _applyEffects 中的 _applyNpcRelationEffect 处理
    }

    // 弧线卡 & 道侣事件卡：应用伴侣效果（好感/信任/羁绊变化）
    if ((card.type === 'COMPANION_EVENT' || card.type === 'COMPANION_ARC') && choice.companionEffects) {
      companionSystem.applyChoice(choice);
    }

    // 师尊弧线卡 & 先知弧线卡 & 盟友弧线卡：关系推进已在引擎侧通过事件体系处理
    // （mentor:progressionChange / seer:revelationChange / ally:alignmentChange 由修炼/道心/恶业变化自动触发）

    // 势力事件卡：应用势力效果
    if (card.type === 'FACTION_EVENT' && choice.factionEffects) {
      factionSystem.applyChoice(choice);
    }

    // 秘境进入
    if (choice.dungeon) {
      gameState.dungeon = choice.dungeon;
      gameState.dungeonNodeIndex = 0;
      gameState.dungeonNodeId = null;  // FIX-4: 图结构模式由 _drawDungeonGraphCard 初始化
      gameState.dungeonPath = [];
      this._log(`进入秘境探险...`);
    }

    // 境界突破
    if (choice.breakSuccess !== undefined) {
      this._resolveBreakthrough(choice.breakSuccess, card);
    }

    // 转世重修（死亡卡选择 或 手动转世效果）
    if (gameState.dead || (choice.effects && choice.effects.reincarnate)) {
      this._reincarnate();
      return true;
    }

    // 秘境推进
    if (gameState.dungeon && !choice.dungeon) {
      cardSystem.advanceDungeon();
    }

    // 记录已玩卡牌
    gameState.cardsPlayed.push(card.id);
    gameState.turn++;

    // ── v2.0 上瘾引擎钩子 ──
    // 传承残卷掉落检测
    if (typeof legacyFragmentSystem !== 'undefined' && legacyFragmentSystem && card.type !== 'COMBAT') {
      const frag = legacyFragmentSystem.tryDrop(gameState.realm);
      if (frag) {
        // 检查是否集齐
        const completions = legacyFragmentSystem.checkCompletions();
        for (const set of completions) {
          this._log(`🎉 传承合成：${set.name}！${set.effect}`);
        }
      }
    }
    // 命盘轮转触发检测
    if (typeof destinyWheelSystem !== 'undefined' && destinyWheelSystem && !this.combatCoordinator.isInCombat()) {
      if (destinyWheelSystem.tick(gameState.turn)) {
        eventBus.emit('destiny:triggered', destinyWheelSystem.getState());
        this._triggerUpdate();
        return true;
      }
    }
    // 因果涟漪触发检测
    if (typeof karmaRippleSystem !== 'undefined' && karmaRippleSystem && !this.combatCoordinator.isInCombat()) {
      const ripple = karmaRippleSystem.tick(gameState.turn);
      if (ripple) {
        if (typeof flowDirector !== 'undefined' && flowDirector) flowDirector.setPending('ripple', ripple);
        else this._pendingRipple = ripple;
        this._triggerUpdate();
        return true;
      }
    }
    // 天机一闪触发检测
    if (typeof heavensHintSystem !== 'undefined' && heavensHintSystem && !this.combatCoordinator.isInCombat()) {
      const hint = heavensHintSystem.tick(gameState.turn);
      if (hint) {
        if (typeof flowDirector !== 'undefined' && flowDirector) flowDirector.setPending('hint', hint);
        else this._pendingHint = hint;
        this._triggerUpdate();
        return true;
      }
    }
    // 集市偶遇触发检测
    if (typeof marketSystem !== 'undefined' && marketSystem && !this.combatCoordinator.isInCombat()) {
      const mkt = marketSystem.tick(gameState.turn);
      if (mkt) {
        if (typeof flowDirector !== 'undefined' && flowDirector) flowDirector.setPending('market', mkt);
        else this._pendingMarket = mkt;
        this._triggerUpdate();
        return true;
      }
    }
    // 世界事件公告（沉浸 v2.0 P2）
    if (!this.combatCoordinator.isInCombat()) {
      this._tickWorldEvents();
    }

    // 寿元消耗
    if (this._shouldConsumeLifespan(card, choice)) {
      gameState.addResource('lifespan', null, -1);
    }

    // 【因果种子】lifespanWaste：寿元 <= 20 时种下危机种子
    if (gameState.resources.lifespan <= 20 && gameState.resources.lifespan > 0) {
      if (typeof karmaSystem !== 'undefined' && karmaSystem) {
        // 避免重复种下
        const existing = karmaSystem.getActiveSeeds && karmaSystem.getActiveSeeds('lifespanWaste');
        if (!existing || existing.length === 0) {
          karmaSystem.plantSeed({
            id: 'lifespanWaste',
            description: `寿元仅剩 ${gameState.resources.lifespan} 年，身体开始衰竭。`,
            originCard: card.id,
            magnitude: Math.max(1, 30 - gameState.resources.lifespan)
          });
        }
      }
    }

    // 因果计时推进
    karmaSystem.tick();

    // NPC情绪衰减 + 同位置交叉互动检测（修复：此前从未被调用）
    if (typeof npcSystem !== 'undefined' && npcSystem) {
      npcSystem._tick();
    }

    // 【环环相扣：法宝/功法被动】每轮回血/福缘加成
    this._applyPassiveRegen();

    // 【环环相扣：道侣危机】善恶剧烈变化时触发情劫/危机
    this._checkCompanionCrisis(card, direction, choice);

    // === 选择回响：在弧线/道侣/师尊/盟友卡上种回响种子 ===
    this._plantChoiceEcho(card, direction, choice);

    // === 故事线程：记录选择历史 + 线程推进 ===
    this._recordChoiceHistory(card, direction, choice);
    if (typeof threadEngine !== 'undefined' && threadEngine) {
      threadEngine.onChoiceMade(card, direction, choice, gameState);
      threadEngine.tick(gameState);
      const threadCard = threadEngine.getNextThreadCard(gameState);
      if (threadCard) {
        if (typeof flowDirector !== 'undefined' && flowDirector) {
          flowDirector.enqueueNarrative(threadCard, threadEngine.config.injectionPriority);
        } else {
          if (!this._narrativeQueue) this._narrativeQueue = [];
          this._narrativeQueue.push({ card: threadCard, priority: threadEngine.config.injectionPriority });
          this._narrativeQueue.sort((a, b) => (b.priority || 0) - (a.priority || 0));
        }
      }
    }

    // === 叙事连贯性层：效果叙事日志（方案A） ===
    if (typeof coherenceLayer !== 'undefined' && coherenceLayer) {
      const narration = coherenceLayer.narrateChoice(card, direction, choice, gameState);
      if (narration) this._log(narration);
    }

    // Event: 卡牌被选择
    eventBus.emit('card:chosen', { card, direction, choice });

    // 【沉浸 v2.5】道侣耳语 — 每次选择后触发
    this._triggerCompanionWhisper(card, direction);

    // 【沉浸 v2.0】检测属性剧变 → 触发心念
    this._checkAttrSurges();
    // 心念冷却递减
    if (this._innerVoiceCooldown > 0) this._innerVoiceCooldown--;

    // 检查死亡
    if (gameState.checkDeath()) {
      const pn = gameState.playerName || '\u59da\u51cc\u4e91';
      this._log(`${pn}\uff0c\u9053\u6d88\u8eab\u9699\u3002${gameState.deadReason}`);
      this.currentCard = cardSystem.draw();
      this._triggerUpdate();
      return true;
    }

    // 下一张卡：优先使用支线推进事件注入的 nextCardId
    if (this._questNextCardId) {
      this.currentCard = cardSystem.getCard(this._questNextCardId);
      this._questNextCardId = null;
    } else if (choice.nextCard) {
      // 兜底：兼容旧数据中直接在 choice 上设置的 nextCard
      this.currentCard = cardSystem.getCard(choice.nextCard);
    } else {
      this.currentCard = null;
    }

    // ── 新手引导：教程完成处理 ──
    if (card.id && card.id.startsWith('tutorial_') && !choice.nextCard && !this._questNextCardId) {
      gameState.unlocks.tutorialCompleted = true;
      gameState._saveUnlocks();
      const pathStarterMap = {
        sword: 'q_start_sword',
        spell: 'q_start_spell',
        body: 'q_start_body',
        pill: 'q_start_pill'
      };
      const starterId = pathStarterMap[gameState.path] || 'q_meditation';
      this.currentCard = cardSystem.getCard(starterId);
      this._log('【引导】教程完成，仙途正式开启。');
    }

    // ── 叙事连贯性层：构建卡牌间过渡文字（方案B）──
    const nextCard = this.currentCard;
    if (typeof coherenceLayer !== 'undefined' && coherenceLayer && nextCard) {
      const transition = coherenceLayer.buildTransition(
        nextCard, gameState,
        typeof threadEngine !== 'undefined' ? threadEngine : null,
        typeof questSystem !== 'undefined' ? questSystem : null,
        typeof npcSystem !== 'undefined' ? npcSystem : null
      );
      coherenceLayer.setPendingTransition(transition);
    }

    if (pauseCardFlow) {
      this._triggerUpdate();
      return true;
    }

    this._triggerUpdate();
    return true;
  }

  // ============ 效果应用 ============

  _applyEffects(effects) {
    if (!effects) return;
    if (!this.effectService) {
      console.error('[GameLogic] EffectService 未注入');
      return;
    }
    this.effectService.apply(effects, this._effectContext());
  }

  _effectContext() {
    return {
      log: this._log.bind(this),
      onNpcRelation: this._applyNpcRelationEffect.bind(this),
      onCompanionActivated: this._activateCompanionToHUD.bind(this)
    };
  }

  _shouldConsumeLifespan(card, choice) {
    // FIX-2: 改为 tag/type 检测，自动覆盖所有战斗卡，无需维护硬编码ID列表
    if (card && card.type === 'COMBAT') return true;
    if (card && Array.isArray(card.tags) && card.tags.includes('combat')) return true;
    if (choice && choice.effects && (choice.effects.health < 0 || choice.effects.daoHeart < 0)) return true;
    return false;
  }

  _checkCost(costCheck) {
    if (!costCheck) return true;
    if (costCheck.spiritStone && gameState.resources.spiritStone < costCheck.spiritStone) {
      return false;
    }
    if (costCheck.health && gameState.attributes.health <= costCheck.health) { // 不能自杀
      return false;
    }
    if (costCheck.karmaGood && (gameState.attributes.karmaGood || 0) < costCheck.karmaGood) {
      return false;
    }
    return true;
  }

  /**
   * 检查 effects 中的资源消耗是否可支付。
   * 防止灵石/寿元/丹药被扣到负数。
   * @param {Object} effects
   * @returns {boolean}
   */
  _checkEffectCost(effects) {
    if (!effects) return true;
    // 灵石
    if (effects.spiritStone !== undefined && effects.spiritStone < 0) {
      if (gameState.resources.spiritStone + effects.spiritStone < 0) {
        return false;
      }
    }
    // 寿元
    if (effects.lifespan !== undefined && effects.lifespan < 0) {
      if (gameState.resources.lifespan + effects.lifespan <= 0) {
        return false;
      }
    }
    return true;
  }

  // ============ 沉浸 v2.0 P2：世界事件 ============

  /**
   * 每隔 WORLD_EVENT_INTERVAL 回合，在日志中插入一条"天下大事"。
   * 让玩家感受到世界在独立运转——不依赖玩家的行动。
   */
  _tickWorldEvents() {
    // 上次事件后还需等待足够回合
    if (gameState.turn - this._lastWorldEventTurn < GameLogic.WORLD_EVENT_INTERVAL) return;
    // 随机小波动，避免完全是固定节奏
    if (Math.random() < 0.6) return; // 60%概率触发，平均每 ~20 回合一次事件

    const candidate = this._pickWorldEvent();
    if (!candidate) return;

    this._lastWorldEventTurn = gameState.turn;
    this._log(candidate.text, 'world-event');
  }

  /**
   * 随机选取一条符合当前境界要求的世界事件
   * @returns {{ text: string }|null}
   */
  _pickWorldEvent() {
    const realmOrder = gameState.config.realms?.order || ['qi', 'foundation', 'golden', 'nascent', 'deity', 'tribulation'];
    const realmIndex = realmOrder.indexOf(gameState.realm);
    // 只筛选境界门禁 ≤ 当前境界的事件
    const pool = GameLogic.WORLD_EVENTS.filter(ev => {
      if (!ev.realmGate) return true;
      const gateIndex = realmOrder.indexOf(
        realmOrder.find(r => gameState.getRealmName(r) === ev.realmGate)
      );
      return gateIndex >= 0 && realmIndex >= gateIndex;
    });
    if (pool.length === 0) return null;
    // 从池中随机选
    return pool[Math.floor(Math.random() * pool.length)];
  }

  // ============ 法宝/功法被动再生 ============

  /**
   * 每轮结束时应用法宝和功法技能的被动再生效果。
   * 包括 hpRegen（回血）、fortuneBonus（福缘恢复）。
   */
  _applyPassiveRegen() {
    // 聚合所有被动加成
    let hpRegen = 0;
    let fortuneBonus = 0;

    // 法宝被动
    if (typeof treasureSystem !== 'undefined' && treasureSystem) {
      const treasBonuses = treasureSystem.getPassiveBonuses();
      hpRegen += treasBonuses.hpRegen || 0;
      fortuneBonus += treasBonuses.fortuneBonus || 0;
    }

    // 功法技能被动
    if (typeof pathSkillSystem !== 'undefined' && pathSkillSystem && gameState.path) {
      const skillBonuses = pathSkillSystem.getPassiveBonuses(gameState.path);
      hpRegen += skillBonuses.hpRegen || 0;
      fortuneBonus += skillBonuses.fortuneBonus || 0;
    }

    // 应用回血（不超过 maxHealth）
    if (hpRegen > 0 && gameState.attributes.health < gameState.maxHealth) {
      const healAmount = Math.min(hpRegen, gameState.maxHealth - gameState.attributes.health);
      gameState.addAttribute('health', healAmount);
    }

    // 应用福缘恢复（不超过100）
    if (fortuneBonus > 0 && gameState.attributes.fortune < 100) {
      gameState.addAttribute('fortune', Math.min(fortuneBonus, 100 - gameState.attributes.fortune));
    }
  }

  /**
   * 获取聚合被动加成（供外部查询，如UI面板）
   * @returns {Object}
   */
  _getAggregatedPassives() {
    const passives = { hpRegen: 0, atk: 0, def: 0, critRate: 0, fortuneBonus: 0, daoResist: 0, pillBonus: 0 };

    if (typeof treasureSystem !== 'undefined' && treasureSystem) {
      const tb = treasureSystem.getPassiveBonuses();
      for (const k of Object.keys(passives)) {
        passives[k] += tb[k] || 0;
      }
    }

    if (typeof pathSkillSystem !== 'undefined' && pathSkillSystem && gameState.path) {
      const sb = pathSkillSystem.getPassiveBonuses(gameState.path);
      for (const k of Object.keys(passives)) {
        passives[k] += sb[k] || 0;
      }
    }

    return passives;
  }

  // ============ 道侣危机检测 ============

  /**
   * 检测善恶值剧烈变化，触发道侣情劫/危机事件。
   * 触发条件：本回合 karmaGood 或 karmaBad 变化 ≥ 15 且存在好感度 ≥ 50 的道侣。
   */
  _checkCompanionCrisis(card, direction, choice) {
    if (typeof companionSystem === 'undefined' || !companionSystem) return;

    // 计算本回合善恶变化
    let karmaDelta = 0;
    if (choice.effects && choice.effects.karmaGood !== undefined) karmaDelta += choice.effects.karmaGood;
    if (choice.effects && choice.effects.karmaBad !== undefined) karmaDelta -= choice.effects.karmaBad;

    if (Math.abs(karmaDelta) < 15) return;

    // 查找好感度 ≥ 50 的已激活道侣
    const companionIds = gameState.resources.companions || [];
    const candidates = [];
    for (const compId of companionIds) {
      const state = companionSystem.getState(compId);
      if (state && state.affection >= 50) {
        candidates.push({ id: compId, name: companionSystem._getName(compId), state });
      }
    }

    if (candidates.length === 0) return;

    // 随机选一位道侣触发危机
    const comp = candidates[Math.floor(Math.random() * candidates.length)];
    const crisisType = karmaDelta > 0 ? '善因危机' : '恶因危机';
    const crisisEvent = karmaDelta > 0
      ? { type: 'crisis', title: `${comp.name}的担忧`, desc: `${comp.name}看到你做了一件大善事，但代价太大了。她/他担心你把自己搭进去——\"你为什么总是这样？能不能……也为自己想一想？\"` }
      : { type: 'crisis', title: `${comp.name}的质问`, desc: `${comp.name}亲眼目睹了你的恶行。她/他的眼神里有失望——还有一种你从未见过的陌生。\"我不认识这个你了。\"` };

    eventBus.emit('companion:heartEvent', {
      compId: comp.id,
      event: crisisEvent
    });

    this._log(`【道侣危机】${comp.name}对你的行为产生了强烈反应。`);
  }

  // ============ 境界突破 ============

  _resolveBreakthrough(successRate, card) {
    const realmConfig = gameState.config.realms
      ? gameState.config.realms.realms[gameState.realm]
      : null;
    const requiredPill = realmConfig ? realmConfig.pillRequired : null;

    if (requiredPill && gameState.hasResource('pill', requiredPill)) {
      gameState.consumeResource('pill', requiredPill);
      const pillName = realmConfig ? realmConfig.pillName : '\u4e39\u836f';
      this._log(`\u670d\u7528${pillName}\uff0c\u7a81\u7834\u6210\u529f\uff01`);
      this._triggerInnerVoice('breakthrough_success', 1.0);

      // 【功法被动】pillBonus：丹药效果加成
      let pillBonus = 0;
      if (typeof pathSkillSystem !== 'undefined' && pathSkillSystem && gameState.path) {
        const skillBonuses = pathSkillSystem.getPassiveBonuses(gameState.path);
        pillBonus = skillBonuses.pillBonus || 0;
      }
      if (pillBonus > 0) {
        // pillBonus 百分比：额外获得修为（下个境界的修为上限的百分比）
        const nextRealm = gameState.config.realms
          ? gameState.config.realms.order[gameState.config.realms.order.indexOf(gameState.realm) + 1]
          : null;
        const nextThreshold = nextRealm && gameState.config.realms.realms[nextRealm]
          ? gameState.config.realms.realms[nextRealm].cultivationThreshold : 100;
        const bonusCult = Math.floor(nextThreshold * pillBonus / 100);
        if (bonusCult > 0) {
          gameState.addAttribute('cultivation', bonusCult);
          this._log(`丹道真意，额外获得 ${bonusCult} 修为！`);
        }
      }

      this._advanceRealm();
      return;
    }

    const roll = Math.random();
    if (roll < successRate) {
      this._log('\u7a81\u7834\u6210\u529f\uff01\u5883\u754c\u63d0\u5347\uff01');
      this._triggerInnerVoice('breakthrough_success', 1.0);
      this._advanceRealm();
    } else {
      this._log('\u7a81\u7834\u5931\u8d25\uff0c\u9053\u5fc3\u53d7\u632b\u3002');
      this._triggerInnerVoice('breakthrough_fail', 1.0);
      gameState.addAttribute('daoHeart', -1);
      gameState.addAttribute('cultivation', -30);

      // ── v2.0 心魔反噬 (GDD §3) ──
      this._innerDemonActive = true;
    }
  }

  // ============ v2.0 心魔反噬 ============

  _buildInnerDemonCard() {
    // 检查师尊护体 (GDD §3.4)
    const mentorProtection = (typeof npcSystem !== 'undefined' && npcSystem &&
      npcSystem.affections && npcSystem.affections.mentor_sword_elder >= 50);
    const demonPill = gameState.hasResource('pill', '心魔丹');

    const card = {
      type: 'INNER_DEMON',
      title: '心魔反噬',
      description: '突破失败，心魔趁虚而入——黑暗的念头在你识海中翻涌。你感到另一个自己在低语：\n\n"何必苦苦坚持正道？接受我，你将更强。"',
      realm: gameState.realm,
      tags: ['inner_demon', 'breakthrough_failure'],
      choices: {}
    };

    if (mentorProtection) {
      card.description += '\n\n✨ 师尊的传承之力护住了你的心脉——你感到一股暖流驱散了些许寒意。';
      card.choices = {
        left: { text: '接受心魔', effects: { cultivation: 8, daoHeart: -5, karmaBad: 5 } },
        right: { text: '师尊训诫', effects: { daoHeart: 2, cultivation: 2 } },
        up: { text: '暂时封印', effects: {} }
      };
      card._mentorProtected = true;
    } else {
      card.choices = {
        left: { text: '接受心魔', effects: { cultivation: 5, daoHeart: -5, karmaBad: 10, _innerDemon: 'accept' } },
        right: { text: '抵抗心魔', effects: { daoHeart: -3, cultivation: 2, _innerDemon: 'resist' } },
        up: { text: '暂时封印', effects: { _innerDemon: 'seal' } }
      };
    }

    if (demonPill) {
      card.choices.down = { text: '服用心魔丹', effects: { daoHeart: 5, cultivation: 3, _innerDemon: 'pill' } };
      card._demonPill = true;
    }

    return card;
  }

  _resolveInnerDemon(direction) {
    const card = this._buildInnerDemonCard();
    const choice = card.choices[direction];
    if (!choice) return;

    this._applyEffects(choice.effects);

    const innerAction = choice.effects._innerDemon;
    if (innerAction === 'accept') {
      this._log('你接受了心魔——它融入了你的修为，但从此它与你共存。恶业+10。');
      // 下次突破概率+10%（设置flag）
      gameState.setFlag('innerDemonBoost', true);
    } else if (innerAction === 'resist') {
      this._log('你以道心强行压制了心魔。道心-3, 修为+2。');
      const resisted = (gameState.getFlag('innerDemonResisted', 0)) + 1;
      gameState.setFlag('innerDemonResisted', resisted);
      if (resisted >= 3) {
        this._log('🏆 成就解锁: 心如铁石！连续三次抵抗心魔，道心+5！');
        gameState.addAttribute('daoHeart', 5);
      }
    } else if (innerAction === 'seal') {
      const sealed = (gameState.getFlag('innerDemonSealed', 0)) + 1;
      gameState.setFlag('innerDemonSealed', sealed);
      this._log(`你将心魔暂时封印。封印层数: ${sealed}/5`);
      if (sealed >= 5) {
        this._log('⚠️ 五重心魔封印集体爆发——魔劫降临！');
        gameState.addAttribute('daoHeart', -20);
        gameState.addAttribute('karmaBad', 20);
        gameState.setFlag('innerDemonSealed', 0);
      }
    } else if (innerAction === 'pill') {
      gameState.consumeResource('pill', '心魔丹');
      this._log('心魔丹入喉——心魔被强行震散，道心反而更加凝实。');
    } else if (card._mentorProtected && direction === 'right') {
      // 师尊训诫: 扣传承值
      if (typeof npcSystem !== 'undefined' && npcSystem) {
        npcSystem.affections.mentor_sword_elder = Math.max(0, (npcSystem.affections.mentor_sword_elder || 0) - 10);
        this._log('师尊训诫了你一番——传承值 -10，但道心更加稳固。');
      }
    }

    this._innerDemonActive = false;
    gameState.cardsPlayed.push('inner_demon');
    gameState.turn++;
    this._triggerUpdate();
  }

  _advanceRealm() {
    const realmOrder = gameState.config.realms
      ? gameState.config.realms.order
      : ['qi', 'foundation', 'golden', 'nascent', 'deity', 'tribulation'];

    const idx = realmOrder.indexOf(gameState.realm);
    const oldRealm = gameState.realm;
    if (idx < realmOrder.length - 1) {
      gameState.realm = realmOrder[idx + 1];
      gameState.setAttribute('cultivation', 10);
      eventBus.emit('state:realmChanged', { from: oldRealm, to: gameState.realm });

      // 位置切换：境界突破 → 返回宗门（最安全的默认位置）
      if (typeof sceneLayerSystem !== 'undefined' && sceneLayerSystem) {
        sceneLayerSystem.transition('宗门', 'realm_breakthrough');
      }

      // 加载下一境界卡牌
      cardSystem._loadRealmCards(gameState.realm);

      // 解锁功法技能
      if (gameState.path) {
        const newSkills = pathSkillSystem.unlockForRealm(gameState.path, gameState.realm);
        for (const skill of newSkills) {
          this._log(`功法技能解锁：【${skill.name}】—— ${skill.desc}`);
        }
      }

      gameState.unlock('realm', gameState.realm);

      // ── 境界章节：完成上一章，进入下一章 ──
      if (typeof chapterSystem !== 'undefined' && chapterSystem && chapterSystem._initialized) {
        const oldChapter = chapterSystem.getChapterTitle(oldRealm);
        const newChapter = chapterSystem.getChapterTitle(gameState.realm);
        const oldProgress = chapterSystem.getProgress(oldRealm);
        this._log(
          '【' + oldChapter + '】完成！里程碑 ' + oldProgress.triggered + '/' + oldProgress.total +
          '\n  → ' + newChapter
        );
        // 重置新章里程碑（防转世残留）
        chapterSystem.reset(gameState.realm);
      }

      this._log(`进入${gameState.getRealmName(gameState.realm)}！`);

      if (gameState.realm === 'foundation') {
        this.currentCard = cardSystem.getCard('q_foundation');
      }
    } else {
      // 飞升结局
      gameState.dead = true;
      gameState.deadReason = '渡劫成功，飞升成仙';
      gameState.unlock('ending', 'ascension');
      this.currentCard = cardSystem.getCard('ending_ascension');
    }
  }

  // ============ 转世 ============

  _reincarnate() {
    const lastTurn = gameState.turn;
    const lastRealm = gameState.realm;
    const lastPath = gameState.path;

    // 【环环相扣：转世连锁】记录跨世遗产
    gameState.recordLegacy();

    // 转世次数+1
    gameState.incrementLife();
    const lifeCount = gameState.getLifeCount();
    this._log(`—————— 第 ${lifeCount} 世 · 轮回 ——————`);

    // 基础跨世加成（境界越高、寿命越长，转世加成越多）
    if (lastRealm !== 'qi') {
      gameState.unlocks.bonuses.startCultivation += 3 + (lifeCount > 1 ? 2 : 0);
    }
    if (lastTurn > 30) {
      gameState.unlocks.bonuses.startSpiritStone += 5 + Math.min(lifeCount, 5) * 2;
    }
    if (lastRealm === 'foundation' || lastRealm === 'golden') {
      gameState.unlocks.bonuses.maxLifespan += 5 + lifeCount;
    }
    if (lastRealm === 'nascent' || lastRealm === 'deity') {
      gameState.unlocks.bonuses.maxLifespan += 10 + lifeCount * 2;
    }

    // 应用死亡卡选择的转世加成
    const bonus = gameState._pendingReincBonus;
    if (bonus) {
      const parts = bonus.split(',');
      for (const part of parts) {
        const trimmed = part.trim();
        const match = trimmed.match(/^([a-zA-Z]+)\s*([+-]\d+)$/);
        if (!match) continue;
        const [, stat, valueStr] = match;
        const value = parseInt(valueStr, 10);
        switch (stat) {
          case 'cultivation': gameState.unlocks.bonuses.startCultivation += value; break;
          case 'spiritStone': gameState.unlocks.bonuses.startSpiritStone += value; break;
          case 'maxLifespan': gameState.unlocks.bonuses.maxLifespan += value; break;
          case 'daoHeart': gameState.unlocks.bonuses.daoHeart = (gameState.unlocks.bonuses.daoHeart || 0) + value; break;
          case 'fortune': gameState.unlocks.bonuses.fortune = (gameState.unlocks.bonuses.fortune || 0) + value; break;
          case 'maxHp': gameState.unlocks.bonuses.maxHp = (gameState.unlocks.bonuses.maxHp || 0) + value; break;
          case 'karmaGood': gameState.unlocks.bonuses.karmaGood = (gameState.unlocks.bonuses.karmaGood || 0) + value; break;
          case 'karmaBad': gameState.unlocks.bonuses.karmaBad = (gameState.unlocks.bonuses.karmaBad || 0) + value; break;
        }
      }
      this._log(`前世抉择余响：${bonus}`);
      gameState._pendingReincBonus = null;
    }

    gameState._saveUnlocks();
    gameState.reset(true);

    this._log(`转世重修——前世的道路如雾中残梦。`);
    this._log(`你感觉到体内有 ${gameState.getLegacyAffection ? '一股熟悉的气息' : '新的力量'}在涌动。`);
    this._log(`难度：${this._getDifficultyText()}`);

    // 【天道恩赐】：抽第一张牌为轮回之选
    this.currentCard = cardSystem.getCard('rebirth_boon');

    // 【环环相扣：转世→NPC】前世老友残留印象
    if (typeof npcSystem !== 'undefined' && npcSystem && gameState.unlocks.legacy) {
      const legacyAffections = gameState.unlocks.legacy.npcAffections || {};
      for (const [npcId, affection] of Object.entries(legacyAffections)) {
        if (affection > 0 && npcSystem.affections) {
          npcSystem.affections[npcId] = Math.round(affection);
        }
      }
    }

    // 【环环相扣：转世→Faction】前世势力的暗流依旧
    if (typeof factionSystem !== 'undefined' && factionSystem && gameState.unlocks.legacy) {
      const legacyReps = gameState.unlocks.legacy.factionReputations || {};
      for (const [factionId, rep] of Object.entries(legacyReps)) {
        if (rep !== 0) {
          const currentRep = factionSystem.reputations?.[factionId] || 0;
          factionSystem.reputations[factionId] = currentRep + Math.round(rep * 0.3);
        }
      }
    }

    this._triggerUpdate();
  }

  // ============ 战斗协调器代理 ============

  /**
   * 战斗中选择动作（由 UI 调用）
   * 注：新版 DeckCombatUI 已直接绑定点击事件，此方法保留兼容层
   */
  combatAction(action) {
    if (this.combatCoordinator) {
      this.combatCoordinator.handleAction(action);
    }
  }

  // ============ 难度曲线系统 ============

  /**
   * 根据转世次数获得当前难度等级 (0-10)
   */
  getDifficultyLevel() {
    const lifeCount = gameState.getLifeCount();
    return Math.min(lifeCount, 10);
  }

  /**
   * 获取难度乘数（敌方属性缩放）
   */
  _getDifficultyMultiplier() {
    const level = this.getDifficultyLevel();
    return 1 + level * 0.15; // 每世 +15% 难度
  }

  /**
   * 获取难度文本描述
   */
  _getDifficultyText() {
    const level = this.getDifficultyLevel();
    if (level === 0) return '初世·凡尘';
    if (level <= 2) return '轮回·磨砺';
    if (level <= 4) return '三世·因果';
    if (level <= 7) return '五世·逆命';
    return '九世·天道';
  }

  // ============ 事件处理 ============

  _onDeath(data) {
    this._log(`道消身陨：${data.reason}`);
  }

  _onQuestTriggered(data) {
    this._log(`支线触发：【${data.questName}】`);
  }

  _onQuestCompleted(data) {
    this._log(`支线完成：【${data.questName}】`);
  }

  _onKarmaSeedPlanted(data) {
    this._log(`因果种下：${data.seed.id}（${data.seed.delay}轮后发芽）`);
  }

  // ============ 工具方法 ============

  /**
   * 种选择回响种子（在弧线卡/道侣卡/师尊卡/盟友卡做选择后调用）
   * @private
   */
  _plantChoiceEcho(card, direction, choice) {
    if (!card || !choice) return;
    if (typeof choiceEchoEngine === 'undefined' || !choiceEchoEngine) return;

    const echoTypes = ['COMPANION_ARC', 'COMPANION_EVENT', 'MENTOR_ARC', 'ALLY_ARC', 'SEER_ARC'];
    if (echoTypes.includes(card.type)) {
      choiceEchoEngine.plantEcho({
        turn: gameState.turn,
        realm: gameState.realm,
        cardId: card.id,
        choice: direction,
        choiceLabel: choice.text || '',
        npcId: card.npcId || null,
        affection: card.npcId && typeof npcSystem !== 'undefined'
          ? (npcSystem.affections[card.npcId] || 0)
          : 0,
        location: gameState.currentLocation || '未知',
        cardType: card.type
      });
    }
  }

  /**
   * 应用NPC间关系效果
   * 处理 effects 中的 'npc_relation:fromId:toId': delta 格式
   * @private
   */
  _applyNpcRelationEffect(key, value) {
    const parts = key.split(':');
    if (parts.length < 3) return;
    const fromNpc = parts[1];
    const toNpc = parts[2];

    if (typeof npcSystem !== 'undefined' && npcSystem && npcSystem.adjustNpcRelation) {
      npcSystem.adjustNpcRelation(fromNpc, toNpc, value);
      this._log(`${npcSystem.getNpcName(fromNpc)} 与 ${npcSystem.getNpcName(toNpc)} 的关系 ${value > 0 ? '改善' : '恶化'}了。`);
    }
  }

  _log(message, cssClass) {
    if (this.onLog) this.onLog(message, cssClass);
  }

  // ============ 道侣沉浸 v2.5 ============

  /**
   * 获取当前激活的道侣（好感最高且 registered）
   * @returns {{ id: string, affection: number, bond: number, trust: number, stage: string, name: string }|null}
   */
  _getActiveCompanion() {
    if (typeof companionSystem === 'undefined' || !companionSystem) return null;
    const comps = gameState.resources.companions || [];
    if (comps.length === 0) return null;

    let best = null;
    let bestAff = -1;
    for (const compId of comps) {
      const state = companionSystem.getState(compId);
      if (!state) continue;
      if (state.affection > bestAff) {
        bestAff = state.affection;
        best = { id: compId, ...state };
      }
    }
    return best;
  }

  /**
   * 触发道侣耳语 — 每次滑动选择后调用
   * @param {Object} card
   * @param {string} direction
   */
  _triggerCompanionWhisper(card, direction) {
    if (typeof companionWhisper === 'undefined' || !companionWhisper) return;
    if (typeof ui === 'undefined' || !ui || !ui.companionHUD) return;

    const activeComp = this._getActiveCompanion();
    if (!activeComp) return;

    const affection = activeComp.affection || 0;
    const reaction = companionWhisper.getReaction(activeComp.id, card, direction, affection);
    if (reaction) {
      ui.showCompanionBubble(reaction, 3500);
    }

    // 同步更新 HUD 好感度
    if (this.onUpdate) {
      ui.companionHUD.heartValEl.textContent = affection;
    }
    // 更新情绪光效
    ui.companionHUD._setEmotion(affection);
    ui.companionHUD._lastAffection = affection;
  }

  /**
   * 激活道侣到 HUD（获得道侣或游戏开始时调用）
   */
  _activateCompanionToHUD() {
    if (typeof ui === 'undefined' || !ui || !ui.companionHUD) return;
    const activeComp = this._getActiveCompanion();
    if (activeComp) {
      ui.setActiveCompanion(activeComp.id, activeComp);
    }
  }

  _triggerUpdate() {
    // ── 叙事连贯性层：在渲染新卡之前显示过渡文字 ──
    if (typeof coherenceLayer !== 'undefined' && coherenceLayer) {
      const transition = coherenceLayer.consumePendingTransition();
      if (transition && this.onShowTransition) {
        this.onShowTransition(transition);
      }
    }
    if (this.onUpdate) this.onUpdate();
  }

  getAvailableDirections(card) {
    if (!card || !card.choices) return [];
    return Object.keys(card.choices);
  }

  /**
   * 记录选择历史（供 StoryThreadEngine 触发检测使用）
   */
  _recordChoiceHistory(card, direction, choice) {
    if (!gameState.choiceHistory) gameState.choiceHistory = [];
    gameState.choiceHistory.push({
      cardId: card.id,
      cardType: card.type,
      direction: direction,
      turn: gameState.turn,
      tags: card.tags || []
    });

    // 记录最近卡牌标签（供 tag_chain 触发）
    if (!gameState.recentCardTags) gameState.recentCardTags = [];
    if (card.tags) {
      for (const tag of card.tags) {
        gameState.recentCardTags.push(tag);
      }
    }
    // 只保留最近 20 个标签
    if (gameState.recentCardTags.length > 20) {
      gameState.recentCardTags = gameState.recentCardTags.slice(-20);
    }

    // 只保留最近 30 条选择历史
    if (gameState.choiceHistory.length > 30) {
      gameState.choiceHistory = gameState.choiceHistory.slice(-30);
    }
  }
}
