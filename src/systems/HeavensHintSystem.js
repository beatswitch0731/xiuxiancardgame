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
    this._totalTicks = 0;
    this._intervalMin = 15;    // 最小触发间隔
    this._intervalMax = 25;    // 最大触发间隔
    this._nextTrigger = this._intervalMin + Math.floor(Math.random() * 11);
    this.onLog = null;
  }

  init() {
    this._hintsRevealed = [];
    this._totalTicks = 0;
    this._nextTrigger = this._intervalMin + Math.floor(Math.random() * 11);
    eventBus.on('state:reset', () => this.reset());
  }

  reset() {
    this._hintsRevealed = [];
    this._totalTicks = 0;
    this._nextTrigger = this._intervalMin + Math.floor(Math.random() * 11);
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

    return this._buildHintCard();
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
    const hint = pool[idx];

    // 根据类型构建不同的选择效果
    const effects = this._buildEffects(hint);

    if (this.onLog) this.onLog(`✨ 天机一闪：${hint.text}`);

    // 推进天机揭示度
    if (typeof storyNetworkSystem !== 'undefined' && storyNetworkSystem.seerArcs) {
      storyNetworkSystem.seerArcs.addRevelation('tianji_laoren', 3);
    }

    return {
      type: 'HEAVENS_HINT',
      title: hint.category === '吉兆' ? '✨ 天机一闪 · 吉兆' :
             hint.category === '凶兆' ? '⚠ 天机一闪 · 凶兆' : '🌀 天机一闪 · 天机',
      description: `天机盘微微震动，一道灵光闪过你的识海——\n\n"${hint.text}"\n\n${hint.interpretation}`,
      hintCategory: hint.category,
      hintIndex: idx,
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

  /**
   * 根据预言类型构建选择效果
   */
  _buildEffects(hint) {
    switch (hint.category) {
      case '吉兆':
        return {
          leftText: '顺应天机，接受馈赠',
          rightText: '保持谦逊，不贪天功',
          leftEffects: { cultivation: 12, fortune: 5, spiritStone: 60 },
          rightEffects: { daoHeart: 8, cultivation: 5, fortune: 2 }
        };
      case '凶兆':
        return {
          leftText: '相信预警，提前准备',
          rightText: '无视凶兆，勇往直前',
          leftEffects: { daoHeart: 5, def: 3, fortune: -1 },
          rightEffects: { cultivation: 8, daoHeart: -3, karmaBad: 2 }
        };
      case '天机':
        return {
          leftText: '铭记于心',
          rightText: '顺其自然',
          leftEffects: { daoHeart: 5, fortune: 3, cultivation: 5 },
          rightEffects: { cultivation: 8, fortune: 2 }
        };
      default:
        return {
          leftText: '相信预言',
          rightText: '质疑预言',
          leftEffects: { cultivation: 5 },
          rightEffects: { daoHeart: 5 }
        };
    }
  }

  /**
   * 预言碎片池 — 40条
   */
  _hintPool() {
    return [
      // ===== 吉兆 (60% = 24条) =====
      { category: '吉兆', text: '青鸾衔书至，云外有仙音。', interpretation: '近期将有贵人相助，或获失传功法残卷。' },
      { category: '吉兆', text: '剑鸣三尺水，月照万年冰。', interpretation: '剑道感悟即将突破，攻击力将大幅提升。' },
      { category: '吉兆', text: '古潭深千尺，龙吟动九霄。', interpretation: '隐秘洞府即将现世，藏有上古丹药。' },
      { category: '吉兆', text: '桃花落满肩，春风度玉门。', interpretation: '道侣好感将在近期大幅提升。' },
      { category: '吉兆', text: '丹炉生紫烟，九转可通玄。', interpretation: '炼丹成功率达到顶峰，适合炼制突破丹药。' },
      { category: '吉兆', text: '三尺青锋冷，一朝破长空。', interpretation: '下次战斗将获得剑心共鸣，伤害翻倍。' },
      { category: '吉兆', text: '石中藏美玉，沙里有黄金。', interpretation: '下一次探索将获得稀有资源。' },
      { category: '吉兆', text: '星垂平野阔，月涌大江流。', interpretation: '修为增长速度将在近期翻倍。' },
      { category: '吉兆', text: '灵根初醒时，正是飞升日。', interpretation: '经脉瓶颈即将松动，突破概率大增。' },
      { category: '吉兆', text: '虎啸生风雷，龙腾起云烟。', interpretation: '战斗中将触发致命一击，伤害 +50%。' },
      { category: '吉兆', text: '金鳞跃池中，一朝化龙去。', interpretation: '平凡之中蕴含大机缘，勿错过日常卡牌。' },
      { category: '吉兆', text: '白鹤衔芝至，紫气自东来。', interpretation: '寿元将获得额外延长。' },
      { category: '吉兆', text: '剑冢鸣金铁，古意入心怀。', interpretation: '获得上古剑修传承，暴击伤害 +15%。' },
      { category: '吉兆', text: '玉笛飞声远，清风满楼台。', interpretation: '坊市将有珍品上架，价格公道。' },
      { category: '吉兆', text: '莲开九品台，佛光自西来。', interpretation: '道心将在近期大幅稳固，心魔抗性 +20%。' },
      { category: '吉兆', text: '枯木逢春雨，铁树绽银花。', interpretation: '绝境之中转机将至——哪怕是死局。' },
      { category: '吉兆', text: '银河落九天，疑是地上仙。', interpretation: '遇见一位隐藏的高人，可获得指点。' },
      { category: '吉兆', text: '凤栖梧桐树，百鸟自朝拜。', interpretation: '势力声望将大幅提升，可号令一方。' },
      { category: '吉兆', text: '珠藏深渊底，龙护万年安。', interpretation: '获得一件上古法宝，附带独特主动技能。' },
      { category: '吉兆', text: '扶摇九万里，绝云气负青天。', interpretation: '修为即将飞跃式增长。' },
      { category: '吉兆', text: '丹心映日月，浩气贯长虹。', interpretation: '善行将获天道嘉奖，因果福报降临。' },
      { category: '吉兆', text: '海底生明月，天涯共此时。', interpretation: '与道侣的羁绊将进入全新阶段。' },
      { category: '吉兆', text: '神兵藏匣久，今朝试锋芒。', interpretation: '隐藏的本命法宝即将觉醒。' },
      { category: '吉兆', text: '松风吹解带，山月照弹琴。', interpretation: '一段平静的修炼时光，修为稳步增长。' },

      // ===== 凶兆 (25% = 10条) =====
      { category: '凶兆', text: '黑云压城城欲摧。', interpretation: '强敌将至，若不准备，将遭受重创。' },
      { category: '凶兆', text: '血月照孤舟，江心鬼火流。', interpretation: '道心即将受到严峻考验，心魔蠢蠢欲动。' },
      { category: '凶兆', text: '霜刃未曾试，今日把示君。', interpretation: '身边之人可能背叛——审视你的羁绊。' },
      { category: '凶兆', text: '螳螂捕蝉雀，黄雀伺其后。', interpretation: '你正成为更大棋局中的棋子，警惕暗算。' },
      { category: '凶兆', text: '风起青萍末，浪成微澜间。', interpretation: '小疏忽将酿成大祸，检查你的资源和状态。' },
      { category: '凶兆', text: '镜花水月终成空。', interpretation: '不要被虚假的突破幻象迷惑，实力需沉淀。' },
      { category: '凶兆', text: '螣蛇乘雾，终为土灰。', interpretation: '冒险行为将导致重大损失，谨慎行事。' },
      { category: '凶兆', text: '山雨欲来风满楼。', interpretation: '势力暗流即将爆发，做好准备。' },
      { category: '凶兆', text: '孤舟蓑笠翁，独钓寒江雪。', interpretation: '孤独将至——道侣可能离你而去。' },
      { category: '凶兆', text: '天生一个仙人洞，无限风光在险峰。', interpretation: '突破在即，但劫数也随之而来——渡劫成功率 -15%。' },

      // ===== 天机 (15% = 6条) =====
      { category: '天机', text: '天道有缺，混沌为证。', interpretation: '这个世界并不完整。天道本身存在漏洞——而你正是这漏洞的化身。' },
      { category: '天机', text: '飞升非终，而是始。', interpretation: '飞升不是终点。那些飞升的先贤——没有人回来，也没有人真正离开。' },
      { category: '天机', text: '第七块碎片不在天外，在心中。', interpretation: '天机盘的最后一块碎片，不在任何秘境，而在你的道心深处。' },
      { category: '天机', text: '天道在筛选，而非滋养。', interpretation: '每一次天劫，不是考验——是收割。天道在筛选值得\u300c保留\u300d的灵魂。' },
      { category: '天机', text: '你曾来过，也将再来。', interpretation: '转世并非偶然。你是天道循环中的锚点——每一世都在接近真相。' },
      { category: '天机', text: '混沌非敌，乃剑。', interpretation: '你的混沌漏洞体质不是缺陷——是对抗天道的唯一武器。' }
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
