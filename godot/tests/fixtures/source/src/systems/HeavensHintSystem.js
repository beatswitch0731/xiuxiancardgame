/**
 * HeavensHintSystem — 天机一闪系统 (GDD 上瘾引擎 §6)
 *
 * 核心机制：
 *   - 每隔 N 回合，随机揭示一则天机预言碎片
 *   - 每则预言是 1-2 行诗意的文字，暗示未来事件
 *   - 揭示时推进天机揭示度（Seer Revelation）
 *   - 玩家可选择"相信"或"质疑"预言，获得不同加成
 *
 * 预言体系：
 *   - 40+ 预言碎片，分三类：吉兆(60%) / 凶兆(25%) / 天机(15%)
 *   - 吉兆：正面加成，相信有额外奖励
 *   - 凶兆：负面预警，质疑可避免减益
 *   - 天机：揭示世界观秘密，无直接加成但推进天机度
 */
class HeavensHintSystem {
  constructor() {
    this._hintsRevealed = [];  // 已揭示的预言索引
    this._issuedHints = [];   // 本世真实生成的索引和回合，供延迟展示后恢复核对
    this._totalTicks = 0;
    this._intervalMin = 15;    // 最小触发间隔
    this._intervalMax = 25;    // 最大触发间隔
    this._nextTrigger = this._intervalMin + Math.floor(Math.random() * 11);
    this.onLog = null;
    this._resetHandler = () => this.reset();
  }

  init() {
    this._hintsRevealed = [];
    this._issuedHints = [];
    this._totalTicks = 0;
    this._nextTrigger = this._intervalMin + Math.floor(Math.random() * 11);
    if (typeof gameState !== 'undefined' && gameState?.heavensHintState) {
      this.hydrateState(gameState.heavensHintState);
    }
    if (typeof eventBus?.off === 'function') eventBus.off('state:reset', this._resetHandler);
    eventBus.on('state:reset', this._resetHandler);
  }

  reset() {
    this._hintsRevealed = [];
    this._issuedHints = [];
    this._totalTicks = 0;
    this._nextTrigger = this._intervalMin + Math.floor(Math.random() * 11);
    if (typeof gameState !== 'undefined' && gameState) gameState.heavensHintState = this.exportState();
  }

  exportState() {
    const currentState = typeof gameState !== 'undefined' ? gameState : null;
    return { version: 1, lifeCount: currentState?.getLifeCount?.()
      ?? currentState?.unlocks?.lifeCount ?? 0,
    totalTicks: this._totalTicks, nextTrigger: this._nextTrigger,
    hintsRevealed: [...this._hintsRevealed],
    issuedHints: this._issuedHints.map(entry => ({ turn: entry.turn, index: entry.index })) };
  }

  hydrateState(snapshot) {
    const currentState = typeof gameState !== 'undefined' ? gameState : null;
    const lifeCount = currentState?.getLifeCount?.()
      ?? currentState?.unlocks?.lifeCount ?? 0;
    const poolLength = this._hintPool().length;
    if (!snapshot || snapshot.version !== 1 || snapshot.lifeCount !== lifeCount
      || !Number.isSafeInteger(snapshot.totalTicks) || snapshot.totalTicks < 0
      || !Number.isSafeInteger(snapshot.nextTrigger)
      || snapshot.nextTrigger <= snapshot.totalTicks
      || !Array.isArray(snapshot.hintsRevealed)
      || snapshot.hintsRevealed.length > poolLength
      || new Set(snapshot.hintsRevealed).size !== snapshot.hintsRevealed.length
      || snapshot.hintsRevealed.some(index => !Number.isSafeInteger(index)
        || index < 0 || index >= poolLength)
      || !Array.isArray(snapshot.issuedHints)
      || snapshot.issuedHints.some(entry => !entry || !Number.isSafeInteger(entry.turn)
        || entry.turn < 0 || entry.turn > snapshot.totalTicks
        || !Number.isSafeInteger(entry.index) || entry.index < 0
        || entry.index >= poolLength || !snapshot.hintsRevealed.includes(entry.index))
      || new Set(snapshot.issuedHints.map(entry => `${entry.turn}:${entry.index}`)).size
        !== snapshot.issuedHints.length) return false;
    this._totalTicks = snapshot.totalTicks;
    this._nextTrigger = snapshot.nextTrigger;
    this._hintsRevealed = [...snapshot.hintsRevealed];
    this._issuedHints = snapshot.issuedHints.map(entry =>
      ({ turn: entry.turn, index: entry.index }));
    return true;
  }

  /**
   * 每回合 tick
   * @param {number} turn
   * @returns {Object|null} 天机卡牌，或 null
   */
  tick(turn) {
    this._totalTicks = turn;
    if (turn < this._nextTrigger) return null;

    // 境界越高触发越频繁（降低间隔）
    const realm = typeof gameState !== 'undefined' ? gameState.realm : 'qi';
    const intervalMod = { qi: 1.0, foundation: 0.9, golden: 0.8, nascent: 0.7, deity: 0.6, tribulation: 0.5 };
    const mod = intervalMod[realm] || 1.0;

    const baseInterval = this._intervalMin + Math.floor(Math.random() * (this._intervalMax - this._intervalMin));
    this._nextTrigger = turn + Math.max(5, Math.round(baseInterval * mod));

    const card = this._buildHintCard();
    if (typeof gameState !== 'undefined' && gameState) gameState.heavensHintState = this.exportState();
    return card;
  }

  /**
   * 构建天机一闪卡牌
   */
  _buildHintCard() {
    const pool = this._hintPool();
    const available = [];

    for (let i = 0; i < pool.length; i++) {
      if (!this._hintsRevealed.includes(i)) available.push(i);
    }

    // 全部揭示过 → 循环使用
    const idx = available.length > 0
      ? available[Math.floor(Math.random() * available.length)]
      : Math.floor(Math.random() * pool.length);

    if (available.length > 0) this._hintsRevealed.push(idx);
    this._issuedHints.push({ turn: this._totalTicks, index: idx });
    const hint = pool[idx];
    const currentState = typeof gameState !== 'undefined' ? gameState : null;
    const lifeId = typeof currentState?.getRunClock === 'function'
      ? (currentState.getRunClock()?.lifeId || `legacy:${currentState.getLifeCount?.() ?? 0}`)
      : `legacy:${currentState?.getLifeCount?.() ?? currentState?.unlocks?.lifeCount ?? 0}`;

    // 根据类型构建不同的选择效果
    const effects = this._buildEffects(hint);

    if (this.onLog) this.onLog(`✨ 天机一闪：${hint.text}`);

    // 推进天机揭示度
    if (typeof storyNetworkSystem !== 'undefined' && storyNetworkSystem.seerArcs) {
      storyNetworkSystem.seerArcs.addRevelation('tianji_laoren', 3);
    }

    return {
      id: `heavens_hint:${lifeId}:${this._totalTicks}:${idx}`,
      type: 'HEAVENS_HINT',
      title: hint.category === '吉兆' ? '✨ 天机一闪 · 吉兆' :
             hint.category === '凶兆' ? '⚠ 天机一闪 · 凶兆' : '🌀 天机一闪 · 天机',
      description: `识海微微震动，一道灵光闪过——\n\n"${hint.text}"\n\n${hint.interpretation}`,
      hintCategory: hint.category,
      hintIndex: idx,
      hintTurn: this._totalTicks,
      choices: {
        left: {
          text: effects.leftText,
          effects: effects.leftEffects
        },
        right: {
          text: effects.rightText,
          effects: effects.rightEffects
        }
      }
    };
  }

  /** Rebuild the forecast and effects from the authored pool on cold resume. */
  restorePendingCard(snapshot) {
    if (!snapshot || snapshot.type !== 'HEAVENS_HINT'
      || !Number.isSafeInteger(snapshot.hintIndex)
      || !Number.isSafeInteger(snapshot.hintTurn) || snapshot.hintTurn < 0) return null;
    const currentState = typeof gameState !== 'undefined' ? gameState : null;
    const lifeId = typeof currentState?.getRunClock === 'function'
      ? (currentState.getRunClock()?.lifeId || `legacy:${currentState.getLifeCount?.() ?? 0}`)
      : `legacy:${currentState?.getLifeCount?.() ?? currentState?.unlocks?.lifeCount ?? 0}`;
    const id = `heavens_hint:${lifeId}:${snapshot.hintTurn}:${snapshot.hintIndex}`;
    const hint = this._hintPool()[snapshot.hintIndex];
    if (snapshot.id !== id || !hint || snapshot.hintTurn > this._totalTicks
      || !this._issuedHints.some(entry => entry.turn === snapshot.hintTurn
        && entry.index === snapshot.hintIndex)) return null;
    const effects = this._buildEffects(hint);
    return { id, type: 'HEAVENS_HINT',
      title: hint.category === '吉兆' ? '✨ 天机一闪 · 吉兆' :
        hint.category === '凶兆' ? '⚠ 天机一闪 · 凶兆' : '🌀 天机一闪 · 天机',
      description: `识海微微震动，一道灵光闪过——\n\n"${hint.text}"\n\n${hint.interpretation}`,
      hintCategory: hint.category, hintIndex: snapshot.hintIndex,
      hintTurn: snapshot.hintTurn,
      choices: { left: { text: effects.leftText, effects: effects.leftEffects },
        right: { text: effects.rightText, effects: effects.rightEffects } },
      _flowSource: 'pending:hint' };
  }

  /**
   * 根据预言类型构建选择效果
   */
  _buildEffects(hint) {
    switch (hint.category) {
      case '吉兆':
        return {
          leftText: '顺应天机，接受馈赠',
          rightText: '保持谦逊，不贪天功',
          leftEffects: { cultivation: 2, fortune: 1, spiritStone: 3 },
          rightEffects: { daoHeart: 1, cultivation: 1, fortune: 1 }
        };
      case '凶兆':
        return {
          leftText: '相信预警，提前准备',
          rightText: '无视凶兆，勇往直前',
          leftEffects: { daoHeart: 1, damageReduction: 1, fortune: -1 },
          rightEffects: { cultivation: 2, daoHeart: -1, karmaBad: 1 }
        };
      case '天机':
        // Only a prophecy can grant prophecy-class evidence. A remembered life
        // cannot mint the physical sword mark found at the authored location.
        let clue = null;
        if (hint.text.includes('飞升非终') || hint.text.includes('天道在筛选')) clue = 'ancient_prophecy_warning';
        return {
          leftText: '铭记于心',
          rightText: '顺其自然',
          leftEffects: { daoHeart: 1, fortune: 1, cultivation: 1, ...(clue ? { find_clue: clue } : {}) },
          rightEffects: { cultivation: 2, fortune: 1 }
        };
      default:
        return {
          leftText: '相信预言',
          rightText: '质疑预言',
          leftEffects: { cultivation: 1 },
          rightEffects: { daoHeart: 1 }
        };
    }
  }

  /**
   * 预言碎片池 — 40条
   */
  _hintPool() {
    return [
      // ===== 吉兆 (60% = 24条) =====
      { category: '吉兆', text: '青鸾衔书至，云外有仙音。', interpretation: '青鸾之象指向外界机缘；此刻只能辨出灵气回暖，未见具体来人或残卷。' },
      { category: '吉兆', text: '剑鸣三尺水，月照万年冰。', interpretation: '剑鸣像是心境回应；此兆没有预定的攻击加成。' },
      { category: '吉兆', text: '古潭深千尺，龙吟动九霄。', interpretation: '潭底有旧时回声；洞府与丹药仍待亲自查证。' },
      { category: '吉兆', text: '桃花落满肩，春风度玉门。', interpretation: '春意掠过旧缘；关系如何变化，仍取决于之后的相处。' },
      { category: '吉兆', text: '丹炉生紫烟，九转可通玄。', interpretation: '炉火映出一线紫光；炼丹成败仍由实际材料与选择决定。' },
      { category: '吉兆', text: '三尺青锋冷，一朝破长空。', interpretation: '剑意一瞬清明；下一场战斗的伤害仍由出牌与敌势决定。' },
      { category: '吉兆', text: '石中藏美玉，沙里有黄金。', interpretation: '土石之间似有灵光；下一次探索的收获尚无定数。' },
      { category: '吉兆', text: '星垂平野阔，月涌大江流。', interpretation: '星月相接，吐纳稍顺；此兆不改变后续修为增长倍率。' },
      { category: '吉兆', text: '灵根初醒时，正是飞升日。', interpretation: '经脉有片刻温热；真正的突破仍须满足境界条件。' },
      { category: '吉兆', text: '虎啸生风雷，龙腾起云烟。', interpretation: '雷声振耳，战意微动；此兆不会预置下一击的暴击。' },
      { category: '吉兆', text: '金鳞跃池中，一朝化龙去。', interpretation: '寻常之处也可留心；是否有机缘，仍看实际遭遇。' },
      { category: '吉兆', text: '白鹤衔芝至，紫气自东来。', interpretation: '白鹤掠过识海，气息略安；此兆不直接延长寿元。' },
      { category: '吉兆', text: '剑冢鸣金铁，古意入心怀。', interpretation: '剑冢影子一闪而逝；传承归属与暴击伤害尚无定论。' },
      { category: '吉兆', text: '玉笛飞声远，清风满楼台。', interpretation: '坊市灯火掠过识海；实际货品与价格仍以入市时为准。' },
      { category: '吉兆', text: '莲开九品台，佛光自西来。', interpretation: '莲影令心神暂定；此兆不附加持续的心魔抗性。' },
      { category: '吉兆', text: '枯木逢春雨，铁树绽银花。', interpretation: '枯木上有新芽之象；困境的解法仍需在当下寻找。' },
      { category: '吉兆', text: '银河落九天，疑是地上仙。', interpretation: '远处似有人声；此兆不能证明高人已经现身。' },
      { category: '吉兆', text: '凤栖梧桐树，百鸟自朝拜。', interpretation: '梧桐影动，众声杂然；势力声望仍以实际行动积累。' },
      { category: '吉兆', text: '珠藏深渊底，龙护万年安。', interpretation: '深渊有珠光一闪；尚无法确认法宝或主动技能。' },
      { category: '吉兆', text: '扶摇九万里，绝云气负青天。', interpretation: '风势高举，吐纳一畅；修为变化以此刻选择结算为准。' },
      { category: '吉兆', text: '丹心映日月，浩气贯长虹。', interpretation: '一缕念头引来温和回响；未来因果仍须由具体行动兑现。' },
      { category: '吉兆', text: '海底生明月，天涯共此时。', interpretation: '月色牵起一段旧念；羁绊是否推进仍看双方选择。' },
      { category: '吉兆', text: '神兵藏匣久，今朝试锋芒。', interpretation: '匣中似有金铁轻鸣；本命法宝尚无觉醒凭据。' },
      { category: '吉兆', text: '松风吹解带，山月照弹琴。', interpretation: '松风令心绪稍定；此刻可以静心修炼，后续收益仍看行动。' },

      // ===== 凶兆 (25% = 10条) =====
      { category: '凶兆', text: '黑云压城城欲摧。', interpretation: '乌云压近，宜审视当前准备；并无已锁定的强敌或伤害。' },
      { category: '凶兆', text: '血月照孤舟，江心鬼火流。', interpretation: '血月之影使心神微乱；是否遭遇心魔仍取决于后续事件。' },
      { category: '凶兆', text: '霜刃未曾试，今日把示君。', interpretation: '霜刃映出疑影；此兆不足以指认任何同伴背叛。' },
      { category: '凶兆', text: '螳螂捕蝉雀，黄雀伺其后。', interpretation: '局中似有旁观之眼；幕后之人和暗算尚无实证。' },
      { category: '凶兆', text: '风起青萍末，浪成微澜间。', interpretation: '微风拂动灵台，提醒留意资源与状态；灾祸尚未发生。' },
      { category: '凶兆', text: '镜花水月终成空。', interpretation: '镜中景象易失真；检视突破条件，比追逐幻象可靠。' },
      { category: '凶兆', text: '螣蛇乘雾，终为土灰。', interpretation: '雾中道路难辨；先衡量风险，再决定是否冒进。' },
      { category: '凶兆', text: '山雨欲来风满楼。', interpretation: '山雨未至，远处隐有杂音；势力冲突尚待证据。' },
      { category: '凶兆', text: '孤舟蓑笠翁，独钓寒江雪。', interpretation: '寒江之象令人想起旧缘；此兆不能预告道侣离去。' },
      { category: '凶兆', text: '天生一个仙人洞，无限风光在险峰。', interpretation: '险峰与劫云同时映现；实际渡劫条件和成功率并未改变。' },

      // ===== 天机 (15% = 6条) =====
      { category: '天机', text: '天道有缺，混沌为证。', interpretation: '天道有缺的说法浮现脑海；它是待查的线索，尚不足以判定你的本质。' },
      { category: '天机', text: '飞升非终，而是始。', interpretation: '飞升后的去向仍是疑案；记下这则警讯，留待其他证据印证。' },
      { category: '天机', text: '第七块碎片不在天外，在心中。', interpretation: '这句旧谶把碎片与道心并置；它自身不提供新的物证。' },
      { category: '天机', text: '天道在筛选，而非滋养。', interpretation: '天劫或许藏着另一种筛选机制；记下警讯，等待实证。' },
      { category: '天机', text: '你曾来过，也将再来。', interpretation: '旧生的回声与今世相叠；这则线索仍需别的证据串联。' },
      { category: '天机', text: '混沌非敌，乃剑。', interpretation: '混沌之力可以成为一种选择；它并非已证实的唯一答案。' }
    ];
  }

  /**
   * 获取已揭示的预言列表
   */
  getRevealed() {
    const pool = this._hintPool();
    return this._hintsRevealed.map(idx => pool[idx]);
  }

  /**
   * 获取状态
   */
  getState() {
    return {
      hintsRevealed: this._hintsRevealed.length,
      totalHints: this._hintPool().length,
      nextTrigger: this._nextTrigger
    };
  }
}

// 全局单例
const heavensHintSystem = new HeavensHintSystem();
