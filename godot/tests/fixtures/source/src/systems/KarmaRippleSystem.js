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
    this._resetHandler = () => this.reset();
  }

  init() {
    this._history = [];
    this._totalTicks = 0;
    this._lastRippleTurn = -this._cooldownTurns;
    if (typeof gameState !== 'undefined' && gameState?.karmaRippleState) {
      this.hydrateState(gameState.karmaRippleState);
    }
    if (typeof eventBus?.off === 'function') eventBus.off('state:reset', this._resetHandler);
    eventBus.on('state:reset', this._resetHandler);
  }

  reset() {
    this._history = [];
    this._totalTicks = 0;
    this._lastRippleTurn = -this._cooldownTurns;
    if (typeof gameState !== 'undefined' && gameState) {
      gameState.karmaRippleState = this.exportState();
    }
  }

  exportState() {
    const lifeCount = typeof gameState?.getLifeCount === 'function'
      ? gameState.getLifeCount()
      : Number(gameState?.unlocks?.lifeCount) || 0;
    return {
      version: 1,
      lifeCount: Math.max(0, Math.floor(Number(lifeCount) || 0)),
      lastRippleTurn: Math.floor(Number(this._lastRippleTurn) || -this._cooldownTurns),
      totalTicks: Math.max(0, Math.floor(Number(this._totalTicks) || 0)),
      history: this._history.slice(-50).map(entry => ({
        turn: Math.max(0, Math.floor(Number(entry.turn) || 0)),
        seedId: String(entry.seedId || ''),
        seedType: String(entry.seedType || 'karma'),
        text: String(entry.text || '')
      }))
    };
  }

  hydrateState(snapshot) {
    if (!snapshot || typeof snapshot !== 'object' || Array.isArray(snapshot)) return false;
    const lifeCount = typeof gameState?.getLifeCount === 'function'
      ? gameState.getLifeCount()
      : Number(gameState?.unlocks?.lifeCount) || 0;
    const lastRippleTurn = Number(snapshot.lastRippleTurn);
    const totalTicks = Number(snapshot.totalTicks);
    if (Number(snapshot.version) !== 1 || Number(snapshot.lifeCount) !== Number(lifeCount)) return false;
    if (!Number.isFinite(lastRippleTurn) || !Number.isFinite(totalTicks)) return false;
    if (lastRippleTurn > Math.max(0, Number(gameState?.turn) || 0)) return false;
    if (!Array.isArray(snapshot.history) || snapshot.history.length > 50) return false;
    const history = [];
    for (const raw of snapshot.history) {
      if (!raw || typeof raw !== 'object' || typeof raw.seedId !== 'string' || !raw.seedId) return false;
      const turn = Number(raw.turn);
      if (!Number.isFinite(turn) || turn < 0 || turn > totalTicks) return false;
      history.push({
        turn: Math.floor(turn),
        seedId: raw.seedId,
        seedType: typeof raw.seedType === 'string' && raw.seedType ? raw.seedType : 'karma',
        text: typeof raw.text === 'string' ? raw.text : ''
      });
    }
    this._lastRippleTurn = Math.floor(lastRippleTurn);
    this._totalTicks = Math.max(0, Math.floor(totalTicks));
    this._history = history;
    return true;
  }

  _persistState() {
    if (typeof gameState === 'undefined' || !gameState) return false;
    gameState.karmaRippleState = this.exportState();
    if (typeof gameState.persistCausalSession === 'function') gameState.persistCausalSession();
    return true;
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

    const card = this._buildRippleCard(seed, turn);
    this._persistState();
    return card;
  }

  /**
   * 构建涟漪卡牌
   */
  _buildRippleCard(seed, turn) {
    const seedType = seed.seedType || 'karma';
    const currentState = typeof gameState !== 'undefined' ? gameState : null;
    const lifeId = typeof currentState?.getRunClock === 'function'
      ? (currentState.getRunClock()?.lifeId || `legacy:${currentState.getLifeCount?.() ?? 0}`)
      : `legacy:${currentState?.getLifeCount?.() ?? currentState?.unlocks?.lifeCount ?? 0}`;
    const templates = this._rippleTemplates();
    const typeTemplates = templates[seedType] || templates.karma;
    const tpl = typeTemplates[Math.floor(Math.random() * typeTemplates.length)];

    // 绑定场景立绘
    const sceneMap = {
      karma: ['scene_karma_k_echo_karma_chain.png'],
      grudge: ['scene_karma_k_echo_karma_chain.png'],
      bloodline: ['scene_karma_k_echo_karma_chain.png'],
      fate: ['scene_karma_k_fortune_wheel.png']
    };
    const sceneFiles = sceneMap[seedType] || sceneMap.karma;
    const imagePath = `assets/cards/events/${sceneFiles[Math.floor(Math.random() * sceneFiles.length)]}`;

    // Generic ripples carry no unverified NPC appearance or reward claim.
    const npcName = null;

    const ripple = {
      // A pending Flow card is a real player decision. Its source identity must
      // survive the pending snapshot and the later committed decision receipt.
      id: `karma_ripple:${lifeId}:${turn}:${seed.id}`,
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

  /** Rebuild a shown Flow card from authored content, never from saved effects. */
  restorePendingCard(snapshot) {
    if (!snapshot || snapshot.type !== 'KARMA_RIPPLE'
      || typeof snapshot.seedId !== 'string' || !snapshot.seedId
      || !Number.isSafeInteger(snapshot.rippleTurn) || snapshot.rippleTurn < 0) return null;
    const currentState = typeof gameState !== 'undefined' ? gameState : null;
    const lifeId = typeof currentState?.getRunClock === 'function'
      ? (currentState.getRunClock()?.lifeId || `legacy:${currentState.getLifeCount?.() ?? 0}`)
      : `legacy:${currentState?.getLifeCount?.() ?? currentState?.unlocks?.lifeCount ?? 0}`;
    const id = `karma_ripple:${lifeId}:${snapshot.rippleTurn}:${snapshot.seedId}`;
    const history = this._history.find(entry => entry.turn === snapshot.rippleTurn
      && entry.seedId === snapshot.seedId && entry.seedType === snapshot.seedType
      && entry.text === snapshot.title);
    if (snapshot.id !== id || !history) return null;
    const templates = this._rippleTemplates();
    const template = (templates[snapshot.seedType] || templates.karma)
      .find(entry => entry.title === snapshot.title && entry.description === snapshot.description);
    if (!template) return null;
    const choices = {
      left: { text: template.leftText || '顺势而为',
        effects: template.leftEffects || { cultivation: 5, daoHeart: 2 } },
      right: { text: template.rightText || '逆天改命',
        effects: template.rightEffects || { daoHeart: 5, cultivation: 3 } }
    };
    const sceneFiles = {
      karma: ['scene_karma_k_echo_karma_chain.png'],
      grudge: ['scene_karma_k_echo_karma_chain.png'],
      bloodline: ['scene_karma_k_echo_karma_chain.png'],
      fate: ['scene_karma_k_fortune_wheel.png']
    }[snapshot.seedType] || ['scene_karma_k_echo_karma_chain.png'];
    const imagePath = sceneFiles.map(file => `assets/cards/events/${file}`)
      .includes(snapshot.imagePath) ? snapshot.imagePath : null;
    if (!imagePath) return null;
    return { id, type: 'KARMA_RIPPLE', title: template.title,
      description: template.description, seedId: snapshot.seedId,
      seedType: snapshot.seedType, rippleTurn: snapshot.rippleTurn,
      imagePath, npcName: null,
      choices, _flowSource: 'pending:ripple' };
  }

  /**
   * 涟漪叙事模板库
   */
  _rippleTemplates() {
    // A seed type is not proof that a particular person acted or a particular
    // event occurred. Only source-authenticated story cards may state those
    // facts. These ambient ripples describe the player's present sensation.
    return {
      karma: [{
        title: '因果微澜',
        description: '一枚尚未兑现的因果轻轻牵动气机。你记得先前的取舍，但此刻没有新的结果可供确认。先调息，还是把这份感应留待日后核证？',
        leftText: '顺着气机调息',
        rightText: '暂且敛息，守住本心',
        leftEffects: { cultivation: 8, fortune: 3 },
        rightEffects: { daoHeart: 8, cultivation: 4 }
      }],
      grudge: [{
        title: '心绪回潮',
        description: '一桩未了之因让心绪短暂翻涌。眼前没有仇家，也没有已经发生的报复；你只能先决定如何应对自己的动摇。',
        leftText: '强行压住杂念',
        rightText: '放慢修行，留心缘由',
        leftEffects: { cultivation: 8, daoHeart: -3, karmaBad: 3 },
        rightEffects: { daoHeart: 3, cultivation: -2, fortune: -1 }
      }],
      bloodline: [{
        title: '脉息一动',
        description: '血脉中的灵息忽然偏了一瞬，随即归于平稳。它还不足以证明远方有人召唤或遭劫，只提醒你留心自己的身体。',
        leftText: '循着脉息运功',
        rightText: '稳住气血再观察',
        leftEffects: { cultivation: 15, maxHealth: 1, daoHeart: -1 },
        rightEffects: { daoHeart: 1, cultivation: 3 }
      }],
      fate: [{
        title: '命途轻颤',
        description: '命数的感应微微偏转，尚看不出确定的吉凶，更不能据此认定天道或他人已经采取行动。你可以体察这丝变化，也可以先守住当下。',
        leftText: '体察变化，顺势行功',
        rightText: '记下异动，继续修行',
        leftEffects: { cultivation: 20, fortune: 10, daoHeart: -1 },
        rightEffects: { daoHeart: 2, fortune: -3, cultivation: 5 }
      }]
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
