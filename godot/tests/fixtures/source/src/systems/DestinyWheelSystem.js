/**
 * DestinyWheelSystem — 命盘轮转系统 (GDD 上瘾引擎 §1)
 *
 * 核心机制：
 *   - 每 N 张卡后触发命盘轮转（N 随境界递减，让后期节奏更紧凑）
 *   - 5 张覆面天机牌，玩家翻开一张获得随机奖励
 *   - VR-5 变量比率强化：传说 5% / 史诗 15% / 稀有 30% / 普通 45% / 空卦 5%
 *   - 保底：至少 1 张 Rare+；空卦数量有限
 */
class DestinyWheelSystem {
  constructor() {
    this.active = false;
    this.deck = [];
    this.flipped = 0;
    this._totalTicks = 0;      // 累计 tick 数
    this.onLog = null;
  }

  init() {
    this.active = false;
    this.deck = [];
    this.flipped = 0;
    this._totalTicks = 0;
    eventBus.on('state:reset', () => this.reset());
  }

  reset() {
    this.active = false;
    this.deck = [];
    this.flipped = 0;
    this._totalTicks = 0;
  }

  /**
   * 每轮 tick — 检测是否触发命盘轮转
   * @param {number} turn 当前轮数
   * @returns {boolean} 是否触发了命盘
   */
  tick(turn) {
    this._totalTicks++;
    const interval = this._realmInterval();
    if (this._totalTicks % interval !== 0) return false;
    // 防止在战斗/心魔等状态中触发
    if (this.active) return false;
    this._generateDeck();
    this.active = true;
    this.flipped = 0;
    if (this.onLog) this.onLog('🔮 天机涌动——命盘轮转显现！选择一张天机牌翻看。');
    return true;
  }

  /**
   * 境界 → 命盘触发间隔
   * 炼气15张 / 筑基12张 / 金丹10张 / 元婴8张 / 化神6张 / 渡劫5张
   */
  _realmInterval() {
    const realm = gameState ? gameState.realm : 'qi';
    const map = { qi: 15, foundation: 12, golden: 10, nascent: 8, deity: 6, tribulation: 5 };
    return map[realm] || 15;
  }

  /**
   * 生成 5 张命盘卡牌
   * VR-5 概率 + 保底 1 张 Rare+
   */
  _generateDeck() {
    const pool = this._rewardPool();
    const deck = [];
    const rarityRolls = [];

    // 先按权重独立抽取 5 张
    for (let i = 0; i < 5; i++) {
      rarityRolls.push(this._rollRarity());
    }

    // 保底：至少 1 张 Rare+
    if (!rarityRolls.some(r => ['legendary','epic','rare'].includes(r))) {
      rarityRolls[Math.floor(Math.random() * 5)] = Math.random() < 0.5 ? 'rare' : 'epic';
    }

    // 空卦保底：最多 1 张空卦
    const emptyCount = rarityRolls.filter(r => r === 'empty').length;
    if (emptyCount > 1) {
      for (let i = 0, fixed = 0; i < 5 && fixed < emptyCount - 1; i++) {
        if (rarityRolls[i] === 'empty') {
          rarityRolls[i] = 'common';
          fixed++;
        }
      }
    }

    for (let i = 0; i < 5; i++) {
      const rarity = rarityRolls[i];
      const candidates = pool[rarity] || pool.common;
      const card = candidates[Math.floor(Math.random() * candidates.length)];
      deck.push({
        name: card.name,
        desc: card.desc,
        rarity: rarity,
        apply: card.apply,
        revealed: false
      });
    }

    this.deck = deck;
  }

  _rollRarity() {
    const roll = Math.random();
    if (roll < 0.05) return 'legendary';
    if (roll < 0.20) return 'epic';
    if (roll < 0.50) return 'rare';
    if (roll < 0.95) return 'common';
    return 'empty';
  }

  /**
   * 奖励池定义
   */
  _rewardPool() {
    return {
      legendary: [
        {
          name: '龙脉印记',
          desc: '修为+30 道心+10 福缘+15',
          apply: () => {
            gameState.addAttribute('cultivation', 30);
            gameState.addAttribute('daoHeart', 10);
            gameState.addAttribute('fortune', 15);
            gameState.unlock('achievement', 'dragon_mark');
            return '🐉 龙脉印记入体——修为+30 道心+10 福缘+15！';
          }
        },
        {
          name: '天劫免疫',
          desc: '下次突破失败时免疫心魔',
          apply: () => {
            gameState.setFlag('tribulationImmune', true);
            return '⚡ 天劫免疫·一次——下次突破失败不再受心魔反噬。';
          }
        },
        {
          name: '混元神石',
          desc: '获得传说级法宝：混元神石',
          apply: (reward = {}) => {
            const rewardToken = reward.transactionId || this._rewardToken(reward.index, '混元神石');
            const acquired = typeof treasureSystem !== 'undefined' && treasureSystem
              && typeof treasureSystem.acquire === 'function'
              ? treasureSystem.acquire('混元神石', {
                source: 'destiny_wheel',
                sourceId: rewardToken,
                channel: 'destiny',
                transactionId: rewardToken
              })
              : false;
            return acquired
              ? '💎 混元神石入袋——传说级法宝！'
              : '💎 命盘显出混元神石，但法宝契约未能写入，请稍后重试。';
          }
        }
      ],
      epic: [
        {
          name: '剑心佩碎片',
          desc: '攻击力永久+5',
          apply: () => {
            gameState.setFlag('atkBonus', (gameState.getFlag('atkBonus', 0)) + 5);
            return '🗡 剑心佩碎片——攻击力永久+5！';
          }
        },
        {
          name: '秘境密钥',
          desc: '灵石+50 秘境探索次数+1',
          apply: () => {
            gameState.addResource('spiritStone', null, 50);
            gameState.setFlag('dungeonKeys', (gameState.getFlag('dungeonKeys', 0)) + 1);
            return '🔑 秘境密钥——灵石+50 秘境次数+1！';
          }
        },
        {
          name: '天书残页',
          desc: '修为+20 解锁隐藏支线线索',
          apply: () => {
            gameState.addAttribute('cultivation', 20);
            gameState.setFlag('heavenBookPage', (gameState.getFlag('heavenBookPage', 0)) + 1);
            return '📜 天书残页——修为+20 隐藏支线线索+1！';
          }
        }
      ],
      rare: [
        {
          name: '灵泉玉露',
          desc: '气血回复30%',
          apply: () => {
            const heal = Math.floor(100 * 0.3);
            gameState.addAttribute('health', heal);
            return `💧 灵泉玉露——气血+${heal}！`;
          }
        },
        {
          name: '灵石袋',
          desc: '灵石+30',
          apply: () => {
            gameState.addResource('spiritStone', null, 30);
            return '💰 灵石袋——灵石+30！';
          }
        },
        {
          name: '道心丹',
          desc: '道心+5',
          apply: () => {
            gameState.addAttribute('daoHeart', 5);
            return '☯ 道心丹——道心+5！';
          }
        }
      ],
      common: [
        {
          name: '灵石袋',
          desc: '灵石+15',
          apply: () => {
            gameState.addResource('spiritStone', null, 15);
            return '💰 小灵石袋——灵石+15！';
          }
        },
        {
          name: '聚灵丹',
          desc: '修为+5',
          apply: () => {
            gameState.addAttribute('cultivation', 5);
            return '💊 聚灵丹——修为+5！';
          }
        },
        {
          name: '寿元桃',
          desc: '寿元+3',
          apply: () => {
            gameState.addResource('lifespan', null, 3);
            return '🍑 寿元桃——寿元+3！';
          }
        }
      ],
      empty: [
        {
          name: '空卦',
          desc: '天机未显，一无所获',
          apply: () => {
            return '🌫 空卦——天机不显，命盘落空。也许下一次...？';
          }
        }
      ]
    };
  }

  /**
   * 翻开指定位置的天机牌
   * @param {number} index 0-4
   * @returns {string|null} 结果消息
   */
  flipCard(index) {
    if (!this.active || index < 0 || index >= this.deck.length) return null;
    const card = this.deck[index];
    if (card.revealed) return null;

    card.revealed = true;
    this.flipped++;

    let msg = '';
    if (card.apply) {
      try { msg = card.apply({ index, transactionId: this._rewardToken(index, card.name) }); } catch (e) { msg = '天机紊乱...'; }
    }

    // 翻牌后关闭命盘
    if (this.flipped >= 1) {
      this.active = false;
      if (this.onLog) this.onLog(msg || `天机揭示：${card.name}`);
    }

    return msg;
  }

  _rewardToken(index, rewardName = 'reward') {
    const runClock = gameState?.getRunClock?.() || null;
    const life = runClock?.lifeId
      || `legacy:${Number(gameState?.getLifeCount?.() ?? gameState?.unlocks?.lifeCount ?? 0) || 0}`;
    // A wheel reward is opened within a persisted decision. Do not derive its
    // receipt from `_totalTicks`: that counter resets on boot and cannot make
    // a replay idempotent.
    const decision = Math.max(0, Number(
      gameState?.getNextDecisionIndex?.()
      ?? gameState?.getDecisionIndex?.()
      ?? gameState?.turn
    ) || 0);
    return `treasure:destiny:life:${life}:decision:${decision}:slot:${Math.max(0, Number(index) || 0)}:item:${rewardName}`;
  }

  /**
   * 获取当前状态（供 UI 渲染）
   */
  getState() {
    return {
      active: this.active,
      deck: this.deck,
      flipped: this.flipped
    };
  }
}

// 全局单例
const destinyWheelSystem = new DestinyWheelSystem();
