/**
 * CombatCoordinator - 战斗流程协调器
 *
 * 将 GameLogic 中战斗相关的状态管理、预警卡、进入战斗、动作处理、
 * 胜利/失败/逃跑结算等职责全部抽取出来，使 GameLogic 不再直接依赖 deckCombatSystem。
 *
 * 当前仍通过构造函数传入全局依赖，后续在第三阶段引入依赖注入时可进一步替换。
 */
class CombatCoordinator {
  constructor({ gameState, deckCombatSystem, effectService, cardSystem, karmaSystem, callbacks, debug = true }) {
    this.gameState = gameState;
    this.deckCombatSystem = deckCombatSystem;
    this.effectService = effectService;
    this.cardSystem = cardSystem;
    this.karmaSystem = karmaSystem;
    this.callbacks = callbacks || {};
    this.debug = debug;

    this._inCombat = false;
    this._combatWarningShown = false;
    this._pendingCombatCard = null;

    this._dbg('initialized');
  }

  _dbg(...args) {
    if (this.debug) console.log('[CombatCoordinator]', ...args);
  }

  isInCombat() { return this._inCombat; }
  hasWarningShown() { return this._combatWarningShown; }
  getPendingCombatCard() { return this._pendingCombatCard; }

  /**
   * 构建并记录战斗预警卡
   */
  buildCombatWarning(combatCard) {
    this._dbg('buildCombatWarning', combatCard?.id, combatCard?.enemy?.name);
    this._combatWarningShown = true;
    this._pendingCombatCard = combatCard;
    return this._buildCombatWarningCard(combatCard);
  }

  /**
   * 正式进入战斗
   */
  async enterCombat(card) {
    this._dbg('enterCombat', card?.id, card?.enemy?.name);
    if (!card || !card.enemy) {
      this._log('[系统] 战斗卡缺少敌人数据，无法进入战斗。');
      return false;
    }
    this._inCombat = true;
    this._combatWarningShown = false;
    this._pendingCombatCard = null;

    if (!this.deckCombatSystem) {
      this._log('[系统] 战斗系统未加载。');
      this._inCombat = false;
      return false;
    }

    await this.deckCombatSystem._start({ card });
    if (!this.deckCombatSystem.active) {
      this._log('[系统] 战斗初始化失败，已自动恢复。');
      this._inCombat = false;
      return false;
    }

    this._dbg('enterCombat success, inCombat=true');
    this._triggerUpdate();
    return true;
  }

  /**
   * 从预警卡确认进入战斗
   */
  async enterCombatFromWarning() {
    this._dbg('enterCombatFromWarning');
    if (!this._pendingCombatCard) {
      this._log('[系统] 战斗预警卡已过期。');
      return false;
    }
    return this.enterCombat(this._pendingCombatCard);
  }

  /**
   * 获取当前战斗 UI 卡
   */
  getCombatCard() {
    this._dbg('getCombatCard');
    if (!this.deckCombatSystem) return { type: 'COMBAT_UI', combatState: null };
    return { type: 'COMBAT_UI', combatState: this.deckCombatSystem.getState() };
  }

  /**
   * 处理战斗动作（兼容层）
   */
  handleAction(action) {
    this._dbg('handleAction', action, 'inCombat=', this._inCombat);
    if (!this._inCombat) return;
    if (!this.deckCombatSystem || !this.deckCombatSystem.active) return;

    if (action === 'end_turn') {
      this.deckCombatSystem.endTurn();
    } else if (action === 'flee') {
      this.deckCombatSystem.flee();
    } else {
      const idx = parseInt(action, 10);
      if (!isNaN(idx)) {
        this.deckCombatSystem.playCard(idx);
      }
    }
    this._triggerUpdate();
  }

  /**
   * 战斗胜利结算
   */
  onVictory(data) {
    this._dbg('onVictory', data?.originalCard?.id);
    // 【诊断日志】战斗胜利入口：记录战前状态
    const hpBefore = this.gameState.attributes.health;
    const cardId = data?.originalCard?.id || data?.cardId || 'unknown';
    this._log(`[战斗结算·胜] card=${cardId} hpBefore=${hpBefore} inCombat=${this._inCombat}`);
    this._inCombat = false;
    this._combatWarningShown = false;

    if (this.callbacks.onInnerVoice) {
      this.callbacks.onInnerVoice('combat_victory', 0.5);
    }

    // 记录已玩卡牌
    const currentCard = this._getCurrentCard();
    if (currentCard) {
      this.gameState.cardsPlayed.push(currentCard.id);
      this.gameState.turn++;
    }

    // 生成战利品卡牌
    const rewardCard = this._buildCombatRewardCard(data);
    if (this.callbacks.setCurrentCard) {
      this.callbacks.setCurrentCard(rewardCard);
    }

    if (this.karmaSystem) this.karmaSystem.tick();

    // 势力声望联动
    const factionResult = this._applyFactionReputation(true);
    if (factionResult) this._log(factionResult);

    // 【诊断日志】战斗胜利出口：记录战后状态 + 死亡检查
    const hpAfter = this.gameState.attributes.health;
    this._log(`[战斗结算·胜] 出口 hpAfter=${hpAfter} dead=${this.gameState.dead} willCheckDeath=${!this.gameState.dead}`);
    if (this.gameState.checkDeath()) {
      this._log(`[战斗结算·胜] checkDeath=true，触发 _handleDeath`);
      this._handleDeath();
      return;
    }
    this._triggerUpdate();
  }

  /**
   * 战斗失败结算
   */
  onDefeat(data) {
    this._dbg('onDefeat', data?.originalCard?.id || data?.cardId);
    // 【诊断日志】战败入口：记录战前状态
    const hpBefore = this.gameState.attributes.health;
    const cardId = data?.originalCard?.id || data?.cardId || 'unknown';
    const isBreakthrough = !!(data?.originalCard?.combatRewards?.breakSuccess);
    this._log(`[战斗结算·败] card=${cardId} hpBefore=${hpBefore} inCombat=${this._inCombat} isBreakthrough=${isBreakthrough}`);
    this._inCombat = false;
    this._combatWarningShown = false;

    // 兼容旧格式：旧系统 emit { cardId, hpLoss, log }，新系统 emit { originalCard, cardId, hpLoss, log }
    const originalCard = data?.originalCard || (data?.cardId ? { id: data.cardId } : null);

    if (originalCard && originalCard.combatRewards && originalCard.combatRewards.breakSuccess) {
      this._log(`[战斗结算·败] breakSuccess=true，走突破失败结算分支`);
      if (this.callbacks.onResolveBreakthrough) {
        this.callbacks.onResolveBreakthrough(0, originalCard);
      }
    } else {
      // 【P0 修复 #3】微数值对齐：战败扣 1 点气血（而非 20），避免 maxHealth=3 时必死
      this.gameState.addAttribute('health', -1);
      this._log(`[战斗结算·败] 扣血 -1，hpNow=${this.gameState.attributes.health}（maxHealth=${this.gameState.maxHealth}）`);
      this._triggerUpdate();
    }

    // 【P0 修复 #3】near_death 阈值从 < 20 调整为 <= 1（微数值对齐）
    if (this.gameState.attributes.health <= 1) {
      this._log(`[战斗结算·败] hp<=1，触发 near_death 内心独白`);
      if (this.callbacks.onInnerVoice) {
        this.callbacks.onInnerVoice('near_death', 0.9);
      }
    }

    const currentCard = this._getCurrentCard();
    if (currentCard) {
      this.gameState.cardsPlayed.push(currentCard.id);
      this.gameState.turn++;
    }
    if (this.callbacks.setCurrentCard) this.callbacks.setCurrentCard(null);

    if (this.karmaSystem) this.karmaSystem.tick();

    // 势力声望联动
    const factionResult = this._applyFactionReputation(false);
    if (factionResult) this._log(factionResult);

    // 【诊断日志】战败出口：记录战后状态 + 死亡检查
    const hpAfter = this.gameState.attributes.health;
    this._log(`[战斗结算·败] 出口 hpAfter=${hpAfter} dead=${this.gameState.dead} willCheckDeath=${!this.gameState.dead}`);
    if (this.gameState.checkDeath()) {
      this._log(`[战斗结算·败] checkDeath=true，触发 _handleDeath`);
      this._handleDeath();
      return;
    }
    this._triggerUpdate();
  }

  /**
   * 战斗逃跑结算
   */
  onFled(data) {
    this._dbg('onFled', data?.originalCard?.id);
    // 【诊断日志】逃跑入口
    const cardId = data?.originalCard?.id || 'unknown';
    this._log(`[战斗结算·逃] card=${cardId} hpBefore=${this.gameState.attributes.health} inCombat=${this._inCombat}`);
    this._inCombat = false;
    this._combatWarningShown = false;

    const currentCard = this._getCurrentCard();
    if (currentCard) {
      this.gameState.cardsPlayed.push(currentCard.id);
      this.gameState.turn++;
    }
    if (this.callbacks.setCurrentCard) this.callbacks.setCurrentCard(null);

    if (this.karmaSystem) this.karmaSystem.tick();

    // 【诊断日志】逃跑出口：记录死亡检查
    this._log(`[战斗结算·逃] 出口 hp=${this.gameState.attributes.health} dead=${this.gameState.dead} willCheckDeath=${!this.gameState.dead}`);
    if (this.gameState.checkDeath()) {
      this._log(`[战斗结算·逃] checkDeath=true，触发 _handleDeath`);
      this._handleDeath();
      return;
    }
    this._triggerUpdate();
  }

  // ============ 内部工具 ============

  _buildCombatWarningCard(combatCard) {
    const enemy = combatCard.enemy || {};
    const enemyName = enemy.name || '未知敌人';
    const battlefield = combatCard.battlefield || combatCard.location || 'default';

    const warningTexts = {
      cave: '洞壁上的青苔被踩碎的声音从前方传来。你闻到了血腥气——' + enemyName + '正在前方等候。',
      sect: '一道剑气划破空气，对方已发现你的气息。' + enemyName + '挡在了去路上。',
      wilderness: '荒野中突然安静下来。你感到一股强烈的杀意从四面涌来——是' + enemyName + '。',
      default: '前方出现了强大的气息。' + enemyName + '挡住了你的去路，似乎已准备好战斗。'
    };
    const desc = warningTexts[battlefield] || warningTexts.default;

    return {
      id: '_warning_' + combatCard.id,
      title: '危险预感',
      description: desc,
      type: 'COMBAT_WARNING',
      _targetCombatCard: combatCard,
      choices: {
        left: {
          text: '直接迎战',
          desc: '正面应对。',
          effects: {},
          _confirmCombat: true
        },
        right: {
          text: '调整气息',
          desc: '消耗 10 灵石，恢复 1 点气血。',
          effects: { health: 1 },
          _confirmCombat: true,
          costCheck: { spiritStone: 10 }
        }
      }
    };
  }

  _buildCombatRewardCard(data) {
    const originalCard = data && data.originalCard;
    let rewardText = '';

    // 应用原卡的 combatRewards
    if (originalCard && originalCard.combatRewards) {
      this.effectService.apply(originalCard.combatRewards, this._effectContext());
      const rw = originalCard.combatRewards;
      const rwStrs = [];
      if (rw.spiritStone) rwStrs.push(`灵石 +${rw.spiritStone}`);
      if (rw.cultivation) rwStrs.push(`修为 +${rw.cultivation}`);
      if (rw.karmaGood) rwStrs.push(`善缘 +${rw.karmaGood}`);
      if (rw.karmaBad) rwStrs.push(`恶业 +${rw.karmaBad}`);
      if (rwStrs.length > 0) {
        rewardText = `\n\n除了战利品，你还获得了：${rwStrs.join('，')}。`;
      }
      if (rw.breakSuccess) {
        rewardText += '\n\n【境界突破】：劫数已过，你感觉体内的力量正在蜕变！';
        if (this.callbacks.onResolveBreakthrough) {
          this.callbacks.onResolveBreakthrough(1, originalCard);
        }
      }
    }

    // 动态生成战利品卡牌（从实际战斗卡牌库中抽取）
    let availableCards = [];
    if (this.deckCombatSystem && this.deckCombatSystem.cardDB) {
      availableCards = Object.keys(this.deckCombatSystem.cardDB).filter(id => id !== 'strike' && id !== 'defend');
    }
    if (availableCards.length === 0) {
      availableCards = ['strike', 'defend', 'sword_intent', 'qi_gather'];
    }

    const shuffle = arr => arr.sort(() => 0.5 - Math.random());
    const choices = shuffle([...availableCards]).slice(0, 3);

    const getName = (id) => {
      if (this.deckCombatSystem && this.deckCombatSystem.cardDB && this.deckCombatSystem.cardDB[id]) {
        return this.deckCombatSystem.cardDB[id].name;
      }
      const nameMap = { 'strike': '剑击', 'defend': '灵气盾', 'sword_intent': '凝结剑意', 'qi_gather': '吐纳' };
      return nameMap[id] || id;
    };

    return {
      id: 'combat_reward',
      type: 'NORMAL',
      sceneImage: 'assets/cards/events/scene_pool_market.png',
      title: '大胜',
      description: '战斗结束。你在战场上发现了一些修炼感悟，请选择一项吸纳，或者直接离去。' + rewardText,
      choices: {
        left: {
          text: `吸纳【${getName(choices[0])}】`,
          effects: { deckCard: choices[0] }
        },
        right: {
          text: `吸纳【${getName(choices[1])}】`,
          effects: { deckCard: choices[1] }
        },
        down: {
          text: '飘然离去',
          effects: {}
        }
      }
    };
  }

  _handleDeath() {
    const pn = this.gameState.playerName || '叶凌云';
    // 【诊断日志】_handleDeath 入口：完整记录死亡状态
    const deathState = {
      hp: this.gameState.attributes.health,
      daoHeart: this.gameState.attributes.daoHeart,
      lifespan: this.gameState.resources.lifespan,
      dead: this.gameState.dead,
      deadReason: this.gameState.deadReason,
      hasEndingFlag: this.gameState.hasFlag('game_ended'),
      inCombatBefore: this._inCombat
    };
    this._log(`[死亡处理] 玩家=${pn} 状态=${JSON.stringify(deathState)}`);

    this._log(`${pn}，道消身陨。${this.gameState.deadReason}`);

    // 【P0 修复 #1】强制解开主流程锁，否则 isInCombat() 持续 true 导致主循环僵死
    const wasInCombat = this._inCombat;
    this._inCombat = false;
    this._combatWarningShown = false;
    this._pendingCombatCard = null;
    this._log(`[死亡处理] 战斗锁解开 wasInCombat=${wasInCombat} → inCombat=false`);

    if (this.callbacks.setCurrentCard) {
      // 【诊断日志】抽下一张卡（应为死亡卡或转世卡）
      const nextCard = this.cardSystem.draw();
      const nextCardId = nextCard ? nextCard.id : 'null';
      this._log(`[死亡处理] 抽下一张卡 id=${nextCardId}（应为 death_* 或 rebirth_*）`);
      this.callbacks.setCurrentCard(nextCard);
    } else {
      this._log(`[死亡处理] ⚠️ callbacks.setCurrentCard 未注册，下一张卡无法设置！`);
    }
    this._triggerUpdate();
  }

  /**
   * 战斗结果影响势力声望（Combat→Faction 环）
   * 从旧 CombatSystem 迁移而来，保持原有逻辑。
   * @param {boolean} victory true=胜利, false=失败
   * @returns {string|null} 日志消息
   */
  _applyFactionReputation(victory) {
    if (typeof factionSystem === 'undefined' || !factionSystem) return null;
    if (!this.deckCombatSystem || !this.deckCombatSystem.enemy) return null;

    const factionId = this.deckCombatSystem.enemy.factionId;
    if (!factionId) return null;

    const faction = factionSystem.getFaction(factionId);
    // 敌对势力列表（邪道/魔道）
    const hostileFactions = ['xuesha_sect'];

    if (victory) {
      if (hostileFactions.includes(factionId)) {
        // 击败邪道：全正道势力声望+5，血煞宗声望-10
        factionSystem.addReputation(factionId, -10);
        for (const [fid] of factionSystem.factions) {
          if (!hostileFactions.includes(fid)) {
            factionSystem.addReputation(fid, 5);
          }
        }
        return `你的战绩传遍修真界，正道各派声望+5！`;
      } else {
        // 击败正道弟子：该势力声望-3
        factionSystem.addReputation(factionId, -3);
        return `${faction ? faction.name : factionId} 对你的行为感到不满，声望-3。`;
      }
    } else {
      // 战败：各势力声望微降（流言蜚语）
      if (hostileFactions.includes(factionId)) {
        factionSystem.addReputation(factionId, -2);
      }
      for (const [fid] of factionSystem.factions) {
        if (!hostileFactions.includes(fid)) {
          factionSystem.addReputation(fid, -2);
        }
      }
      return `战败的消息传开，你的声望受损。`;
    }
  }

  _getCurrentCard() {
    if (this.callbacks.getCurrentCard) {
      return this.callbacks.getCurrentCard();
    }
    return null;
  }

  _effectContext() {
    return { log: this._log.bind(this) };
  }

  _log(msg) {
    if (this.callbacks.log) this.callbacks.log(msg);
  }

  _triggerUpdate() {
    if (this.callbacks.onUpdate) this.callbacks.onUpdate();
  }
}
