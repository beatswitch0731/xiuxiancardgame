/**
 * CombatCoordinator - 战斗流程协调器
 *
 * 将 GameLogic 中战斗相关的状态管理、预警卡、进入战斗、动作处理、
 * 胜利/失败/逃跑结算等职责全部抽取出来，使 GameLogic 不再直接依赖 deckCombatSystem。
 *
 * 当前仍通过构造函数传入全局依赖，后续在第三阶段引入依赖注入时可进一步替换。
 */
class CombatCoordinator {
  constructor({
    gameState,
    deckCombatSystem,
    effectService,
    choiceOutcomeRouter = null,
    endingEligibilityService = null,
    skillCardAcquisitionSystem = null,
    cardSystem,
    chapterSystem = null,
    karmaSystem,
    callbacks,
    debug = true
  }) {
    this.gameState = gameState;
    this.deckCombatSystem = deckCombatSystem;
    this.effectService = effectService;
    this.choiceOutcomeRouter = choiceOutcomeRouter;
    this.endingEligibilityService = endingEligibilityService;
    this.skillCardAcquisitionSystem = skillCardAcquisitionSystem;
    this.cardSystem = cardSystem;
    this.chapterSystem = chapterSystem;
    this.karmaSystem = karmaSystem;
    this.callbacks = callbacks || {};
    this.debug = debug;

    this._inCombat = false;
    this._combatWarningShown = false;
    this._pendingCombatCard = null;
    this._pendingResolution = null;
    this._activeEncounterContext = null;

    this._dbg('initialized');
  }

  _dbg(...args) {
    if (this.debug) console.log('[CombatCoordinator]', ...args);
  }

  isInCombat() { return this._inCombat; }
  hasWarningShown() { return this._combatWarningShown; }
  getPendingCombatCard() { return this._pendingCombatCard; }
  getPendingResolution() { return this._pendingResolution; }

  capturePendingWarningState() {
    const clone = value => value == null ? null : JSON.parse(JSON.stringify(value));
    return {
      warningShown: this._combatWarningShown,
      pendingCombatCard: clone(this._pendingCombatCard),
      pendingResolution: clone(this._pendingResolution)
    };
  }

  restorePendingWarningState(snapshot) {
    if (!snapshot || typeof snapshot !== 'object') return false;
    const clone = value => value == null ? null : JSON.parse(JSON.stringify(value));
    this._combatWarningShown = snapshot.warningShown === true;
    this._pendingCombatCard = clone(snapshot.pendingCombatCard);
    this._pendingResolution = clone(snapshot.pendingResolution);
    return true;
  }

  /**
   * 构建并记录战斗预警卡
   */
  buildCombatWarning(combatCard, resolutionContext = null) {
    this._dbg('buildCombatWarning', combatCard?.id, combatCard?.enemy?.name);
    const contextualCombatCard = Object.assign({}, combatCard, {
      encounterContext: this._createEncounterContext(combatCard)
    });
    this._combatWarningShown = true;
    this._pendingCombatCard = contextualCombatCard;
    this._pendingResolution = resolutionContext || null;
    const warningCard = this._buildCombatWarningCard(contextualCombatCard);
    warningCard.encounterContext = contextualCombatCard.encounterContext;
    if (!warningCard.sceneImage && contextualCombatCard.combatPresentation?.sceneImage) {
      warningCard.sceneImage = contextualCombatCard.combatPresentation.sceneImage;
    }
    const injury = this._getDefeatHealthLoss(contextualCombatCard, resolutionContext);
    const configuredFloor = Number(resolutionContext?.choice?.defeatHealthFloor
      ?? contextualCombatCard.defeatHealthFloor
      ?? contextualCombatCard.combatRules?.defeatHealthFloor);
    // Describe the rule, not a forecast frozen before a preparation choice.
    // Only source-choice settlement owns floor protection; legacy direct
    // combat must not acquire it merely because a card has a similarly named field.
    const hasChoiceResolution = resolutionContext?.choice
      && typeof resolutionContext.choice === 'object' && !Array.isArray(resolutionContext.choice);
    const floorRule = hasChoiceResolution && Number.isFinite(configuredFloor) && configuredFloor >= 1
      ? `最低保留 ${Math.floor(configuredFloor)} 点真实气血（不足时不再扣除，不额外回血）；`
      : '';
    warningCard.description = `${warningCard.description || ''}\n\n【结算规则】战斗中的护体值是独立局内资源；胜利不会把局内受击写回真实气血。战败伤势上限 ${injury} 点；${floorRule}实际损失按结算时气血计算，备战疗伤可改变实际损失。`;
    return warningCard;
  }

  /**
   * 由叙事选项创建战斗。原选项只在战斗结果确定后结算，避免开战前扣血或发奖励。
   */
  buildChoiceCombatWarning(sourceCard, direction, choice) {
    const enemy = choice?.enemy || sourceCard?.enemy;
    const combatCard = Object.assign({}, sourceCard, {
      encounterId: choice?.encounterId || sourceCard?.encounterId || null,
      encounterKind: choice?.encounterKind || sourceCard?.encounterKind || null,
      enemy,
      battlefield: choice?.battlefield || enemy?.battlefield || sourceCard?.battlefield,
      combatPresentation: Object.assign({}, sourceCard?.combatPresentation || {}, choice?.combatPresentation || {}),
      defeatHealthLoss: choice?.defeatHealthLoss ?? sourceCard?.defeatHealthLoss,
      defeatHealthFloor: choice?.defeatHealthFloor ?? sourceCard?.defeatHealthFloor,
      combatRules: Object.assign({}, sourceCard?.combatRules || {}, choice?.combatRules || {})
    });
    return this.buildCombatWarning(combatCard, {
      sourceCard,
      direction,
      choice,
      combatCard
    });
  }

  cancelPendingCombat({ keepResolution = false } = {}) {
    this._combatWarningShown = false;
    this._pendingCombatCard = null;
    if (!keepResolution) this._pendingResolution = null;
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

    const contextualCombatCard = Object.assign({}, card, {
      encounterContext: this._createEncounterContext(card)
    });
    this._activeEncounterContext = JSON.parse(JSON.stringify(contextualCombatCard.encounterContext));
    await this.deckCombatSystem._start({
      card: contextualCombatCard,
      encounterContext: contextualCombatCard.encounterContext,
      resolutionContext: this._pendingResolution
    });
    if (!this.deckCombatSystem.active) {
      this._log('[系统] 战斗初始化失败，已自动恢复。');
      this._inCombat = false;
      this._pendingResolution = null;
      this._activeEncounterContext = null;
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

  restoreActiveCombat(snapshot) {
    if (!snapshot || snapshot.active !== true || !snapshot.originalCard?.id
      || !this.deckCombatSystem?.active) return false;
    const authoritativeSnapshot = typeof this.deckCombatSystem.exportState === 'function'
      ? this.deckCombatSystem.exportState()
      : null;
    if (!authoritativeSnapshot
      || authoritativeSnapshot.authoritySeal !== snapshot.authoritySeal
      || authoritativeSnapshot.originalCard?.id !== snapshot.originalCard.id) return false;
    this._inCombat = true;
    this._combatWarningShown = false;
    this._pendingCombatCard = null;
    this._activeEncounterContext = authoritativeSnapshot.encounterContext
      ? JSON.parse(JSON.stringify(authoritativeSnapshot.encounterContext))
      : null;
    this._pendingResolution = authoritativeSnapshot.resolutionContext
      ? JSON.parse(JSON.stringify(authoritativeSnapshot.resolutionContext))
      : null;
    return true;
  }

  /**
   * 处理战斗动作（兼容层）
   */
  handleAction(action) {
    this._dbg('handleAction', action, 'inCombat=', this._inCombat);
    if (!this._inCombat) return;
    if (!this.deckCombatSystem || !this.deckCombatSystem.active) return;

    if (action && typeof action === 'object' && action.type === 'reaction') {
      this.deckCombatSystem.chooseReaction(action.reactionId, action.windowId);
    } else if (action === 'end_turn') {
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
    if (!this._claimCombatOutcome('victory', data)) return false;
    const pendingResolution = this._pendingResolution;
    const directGate = this._beginDirectRealmGateDecision(pendingResolution, data);
    if (directGate === false) return false;
    // 【诊断日志】战斗胜利入口：记录战前状态
    const hpBefore = this.gameState.attributes.health;
    const cardId = data?.originalCard?.id || data?.cardId || 'unknown';
    this._dbg('victory_enter', { cardId, hpBefore, inCombat: this._inCombat });

    // 记录已玩卡牌
    const currentCard = this._getCurrentCard();

    // 先恢复来源选项：胜利效果、任务推进和因果种子只在此刻结算。
    // 基础战利品已由 DeckCombatSystem 写入，因此只快照来源结算的增量，再与显式 baseRewards 合并。
    const settlementBefore = this._captureSettlementState();
    if (!this._settlePendingCombatOutcome('victory', pendingResolution, data)) {
      return false;
    }
    // A direct realm gate has no source-choice wrapper.  Its narrative
    // settlement must accept before cardsPlayed, rewards, flow, or a new
    // checkpoint can leak out.  A failed receipt restores the last active
    // combat snapshot so the player can retry rather than lose the anchor.
    const realmOutcome = this._notifyRealmGateOutcome('victory', data?.originalCard);
    if (realmOutcome !== true) {
      if (directGate) return this._rejectDirectRealmGateDecision(directGate, data);
      // GameStateManager rollback returns the whole pre-battle snapshot,
      // including DeckCombatSystem's base rewards.  Only lightweight/non-state
      // runtimes need the explicit delta compensation below.
      if (realmOutcome?.stateRolledBack !== true) this._rollbackBaseCombatRewards(data?.baseRewards);
      this._restoreRejectedCombatOutcome(pendingResolution);
      return false;
    }
    // 选择驱动战斗的来源卡、turn 与 choiceHistory 由
    // GameLogic._resolveCombatOutcome 统一提交；这里只记录无来源的强制战。
    if (currentCard && !pendingResolution) {
      this.gameState.cardsPlayed.push(currentCard.id);
      if (!directGate) this.gameState.turn++;
    }
    this._combatWarningShown = false;
    this._pendingCombatCard = null;
    this._pendingResolution = null;
    const terminalFinale = this._isTerminalFinale(data?.originalCard);
    if (terminalFinale && !this._beginTerminalVictory(data)) {
      this._log('[终局交接] 最终 Boss 胜利凭证已存在或上下文无效，本次结算被拒绝。');
      if (directGate) return this._rejectDirectRealmGateDecision(directGate, data);
      this._triggerUpdate();
      return false;
    }

    // Boss fragments own durable state. They must be created only after the
    // source decision has committed; otherwise their persistence can replace
    // the active-combat snapshot that a rejected source settlement needs.
    if (typeof legacyFragmentSystem !== 'undefined' && legacyFragmentSystem) {
      const reward = legacyFragmentSystem.beginBossReward(this._buildBossRewardEncounterContext(data));
      if (reward.created) {
        this._log(`⚔ Boss 战利待选：${reward.pending.candidateSetIds.length} 套传承可择。`);
      }
    }

    if (this.callbacks.onInnerVoice) {
      this.callbacks.onInnerVoice('combat_victory', 0.5);
    }
    const settlementAfter = this._captureSettlementState();
    const settlementSummary = this._mergeSettlementSummary(
      data?.baseRewards,
      this._diffSettlementState(settlementBefore, settlementAfter)
    );

    // 生成战利品卡牌
    const rewardCard = this._buildCombatRewardCard(data, settlementSummary, pendingResolution);
    // 突破回调在上一行的奖励构建中执行；待其读取战前服丹标记后再清理。
    this._clearRealmGatePillCounter(data?.originalCard);
    if (this.callbacks.setCurrentCard) {
      this.callbacks.setCurrentCard(rewardCard);
    }


    // 势力声望联动
    const factionResult = this._hasExplicitFactionOutcomeLink(pendingResolution, 'victory')
      ? null
      : this._applyFactionReputation(true);
    if (factionResult) this._log(factionResult);
    // The raw combat:victory signal is emitted before this coordinator has
    // authenticated and settled the encounter. Persistent listeners must see
    // only this accepted signal, before the outcome checkpoint is saved.
    if (!pendingResolution && typeof eventBus !== 'undefined' && eventBus) {
      eventBus.emit('combat:victorySettled', data);
    }
    // 【诊断日志】战斗胜利出口：记录战后状态 + 死亡检查
    const hpAfter = this.gameState.attributes.health;
    this._dbg('victory_exit', { hpAfter, dead: this.gameState.dead, willCheckDeath: !this.gameState.dead });
    if (this.gameState.lifePhase === 'EPILOGUE' || (typeof this.gameState.isInEnding === 'function' && this.gameState.isInEnding())) {
      this._dbg('victory_epilogue_skip_death_check');
      this._inCombat = false;
      this._triggerUpdate();
      return true;
    }
    if (this.gameState.checkDeath()) {
      this._dbg('victory_check_death', { triggered: true });
      this._handleDeath();
      if (directGate) return this._finishDirectRealmGateDecision(directGate, data);
      // The source decision was committed before checkDeath. Persist the
      // resulting death card and cause under that same decision checkpoint.
      return this._commitOutcomeCheckpoint(pendingResolution, currentCard);
    }
    if (directGate) return this._finishDirectRealmGateDecision(directGate, data);
    this._commitOutcomeCheckpoint(pendingResolution, currentCard);
    this._triggerUpdate();
    return true;
  }

  /**
   * 战斗失败结算
   */
  onDefeat(data) {
    this._dbg('onDefeat', data?.originalCard?.id || data?.cardId);
    if (!this._claimCombatOutcome('defeat', data)) return false;
    const pendingResolution = this._pendingResolution;
    const directGate = this._beginDirectRealmGateDecision(pendingResolution, data);
    if (directGate === false) return false;
    // 【诊断日志】战败入口：记录战前状态
    const hpBefore = this.gameState.attributes.health;
    const cardId = data?.originalCard?.id || data?.cardId || 'unknown';
    const isBreakthrough = !!(data?.originalCard?.combatRewards?.breakSuccess);
    this._dbg('defeat_enter', { cardId, hpBefore, inCombat: this._inCombat, isBreakthrough });

    // 兼容旧格式：旧系统 emit { cardId, hpLoss, log }，新系统 emit { originalCard, cardId, hpLoss, log }
    const originalCard = data?.originalCard || (data?.cardId ? { id: data.cardId } : null);
    if (!this._settlePendingCombatOutcome('defeat', pendingResolution, data)) return false;
    let appliedDefeatHealthLoss = pendingResolution && data?.sourceSettlement?.accepted === true
      ? data.sourceSettlement.defeatHealthLoss
      : undefined;
    if (this._notifyRealmGateOutcome('defeat', originalCard) !== true) {
      if (directGate) return this._rejectDirectRealmGateDecision(directGate, data);
      this._restoreRejectedCombatOutcome(pendingResolution);
      return false;
    }
    this._combatWarningShown = false;
    this._pendingCombatCard = null;
    this._pendingResolution = null;
    if (this.cardSystem?.getActiveDungeonRun?.()) {
      this.cardSystem.completeDungeon('failure', 'combat_loss', {
        cardId: data?.originalCard?.id || data?.cardId || null
      });
    }
    this._clearRealmGatePillCounter(originalCard);

    if (!pendingResolution) {
      const injury = Number(data?.defeatHealthLoss) || this._getDefeatHealthLoss(originalCard);
      if (this.gameState?.applyInjury) {
        appliedDefeatHealthLoss = this.gameState.applyInjury(injury, { source: cardId, reason: 'combat_defeat' });
      } else if (this.gameState?.setAttribute) {
        const healthBeforeInjury = this.gameState.attributes.health;
        this.gameState.setAttribute('health', Math.max(0, healthBeforeInjury - injury));
        appliedDefeatHealthLoss = healthBeforeInjury - this.gameState.attributes.health;
      }
      this._log(typeof appliedDefeatHealthLoss === 'number' && Number.isFinite(appliedDefeatHealthLoss)
        ? `斗法败退，护体本源受损，气血 -${appliedDefeatHealthLoss}。`
        : '斗法败退，本次伤势数值未记录，请以当前气血为准。');
    }

    if (originalCard && originalCard.combatRewards && originalCard.combatRewards.breakSuccess) {
      this._dbg('defeat_breakthrough_branch');
      if (this.callbacks.onResolveBreakthrough) {
        this.callbacks.onResolveBreakthrough(0, originalCard, true);
      }
    } else {
      this._dbg('defeat_injury_settled', {
        hpNow: this.gameState.attributes.health,
        maxHealth: this.gameState.maxHealth
      });
      this._triggerUpdate();
    }

    // 【P0 修复 #3】near_death 阈值从 < 20 调整为 <= 1（微数值对齐）
    if (this.gameState.attributes.health <= 1) {
      this._dbg('defeat_near_death_inner_voice', { hp: this.gameState.attributes.health });
      if (this.callbacks.onInnerVoice) {
        this.callbacks.onInnerVoice('near_death', 0.9);
      }
    }

    const currentCard = this._getCurrentCard();
    if (currentCard && !pendingResolution) {
      this.gameState.cardsPlayed.push(currentCard.id);
      if (!directGate) this.gameState.turn++;
    }
    const outcomeCard = this._buildCombatOutcomeCard('defeat', { ...data, appliedDefeatHealthLoss }, pendingResolution);
    if (this.callbacks.setCurrentCard) this.callbacks.setCurrentCard(outcomeCard);


    // 势力声望联动
    const factionResult = this._hasExplicitFactionOutcomeLink(pendingResolution, 'defeat')
      ? null
      : this._applyFactionReputation(false);
    if (factionResult) this._log(factionResult);
    if (!pendingResolution && typeof eventBus !== 'undefined' && eventBus) {
      eventBus.emit('combat:defeatSettled', data);
    }

    // 【诊断日志】战败出口：记录战后状态 + 死亡检查
    const hpAfter = this.gameState.attributes.health;
    this._dbg('defeat_exit', { hpAfter, dead: this.gameState.dead, willCheckDeath: !this.gameState.dead });
    if (this.gameState.checkDeath()) {
      this._dbg('defeat_check_death', { triggered: true });
      this._handleDeath();
      if (directGate) return this._finishDirectRealmGateDecision(directGate, data);
      return this._commitOutcomeCheckpoint(pendingResolution, currentCard);
    }
    if (directGate) return this._finishDirectRealmGateDecision(directGate, data);
    this._commitOutcomeCheckpoint(pendingResolution, currentCard);
    this._triggerUpdate();
  }

  /**
   * 战斗逃跑结算
   */
  onFled(data) {
    this._dbg('onFled', data?.originalCard?.id);
    if (!this._claimCombatOutcome('flee', data)) return false;
    const pendingResolution = this._pendingResolution;
    const directGate = this._beginDirectRealmGateDecision(pendingResolution, data);
    if (directGate === false) return false;
    // 【诊断日志】逃跑入口
    const cardId = data?.originalCard?.id || 'unknown';
    this._dbg('flee_enter', { cardId, hpBefore: this.gameState.attributes.health, inCombat: this._inCombat });
    if (!this._settlePendingCombatOutcome('flee', pendingResolution, data)) return false;
    if (this._notifyRealmGateOutcome('flee', data?.originalCard) !== true) {
      if (directGate) return this._rejectDirectRealmGateDecision(directGate, data);
      this._restoreRejectedCombatOutcome(pendingResolution);
      return false;
    }
    this._combatWarningShown = false;
    this._pendingCombatCard = null;
    this._pendingResolution = null;
    if (this.cardSystem?.getActiveDungeonRun?.()) {
      this.cardSystem.abandonDungeon('combat_fled', {
        cardId: data?.originalCard?.id || data?.cardId || null
      });
    }
    this._clearRealmGatePillCounter(data?.originalCard);

    if (!pendingResolution) {
      // 无来源上下文的旧战斗沿用默认逃跑代价。
      this.gameState.addResource('lifespan', null, -1);
      this._log('你为脱离战场燃去一年寿元。');
    }

    const currentCard = this._getCurrentCard();
    if (currentCard && !pendingResolution) {
      this.gameState.cardsPlayed.push(currentCard.id);
      if (!directGate) this.gameState.turn++;
    }
    const outcomeCard = this._buildCombatOutcomeCard('flee', data, pendingResolution);
    if (this.callbacks.setCurrentCard) this.callbacks.setCurrentCard(outcomeCard);


    // 【诊断日志】逃跑出口：记录死亡检查
    this._dbg('flee_exit', {
      hp: this.gameState.attributes.health,
      dead: this.gameState.dead,
      willCheckDeath: !this.gameState.dead
    });
    if (this.gameState.checkDeath()) {
      this._dbg('flee_check_death', { triggered: true });
      this._handleDeath();
      if (directGate) return this._finishDirectRealmGateDecision(directGate, data);
      return this._commitOutcomeCheckpoint(pendingResolution, currentCard);
    }
    if (directGate) return this._finishDirectRealmGateDecision(directGate, data);
    this._commitOutcomeCheckpoint(pendingResolution, currentCard);
    this._triggerUpdate();
  }

  _buildBossRewardEncounterContext(data = {}) {
    const rawContext = data?.encounterContext;
    if (!rawContext || typeof rawContext !== 'object' || Array.isArray(rawContext)) return rawContext;
    const context = { ...rawContext };
    const presentation = data?.presentation;
    const uiMaterialId = presentation?.visualWorld?.uiMaterial?.id || null;
    if (presentation?.visualWorldCompatible === true
      && presentation?.visualWorldId === 'cangmang_sect_pc98_v1'
      && uiMaterialId === 'sect_field_ledger_v1') {
      context.rewardPresentation = {
        visualWorldId: 'cangmang_sect_pc98_v1',
        uiMaterialId: 'sect_field_ledger_v1',
        visualSurface: 'boss_fragment_choice'
      };
    }
    return context;
  }

  // ============ 内部工具 ============

  /**
   * 抢占一次战斗结算权。DeckCombatSystem 的结果事件可能因重复监听或
   * 调试桥接到达多次；只有仍处于 active 的首次结果可以产生永久结算。
   */
  _claimCombatOutcome(outcome, data) {
    if (!this._inCombat) {
      const cardId = data?.originalCard?.id || data?.cardId || 'unknown';
      this._dbg('outcome_duplicate_ignored', { outcome, cardId });
      return false;
    }
    const expected = this._activeEncounterContext;
    if (expected) {
      const incoming = data?.encounterContext || data?.originalCard?.encounterContext || null;
      if (!incoming
        || incoming.encounterInstanceId !== expected.encounterInstanceId
        || incoming.cardId !== expected.cardId
        || (data?.originalCard?.id && data.originalCard.id !== expected.cardId)
        || (data?.cardId && data.cardId !== expected.cardId)) {
        this._dbg('outcome_foreign_ignored', { outcome, expected: expected.encounterInstanceId });
        return false;
      }
    }
    this._inCombat = false;
    this._activeEncounterContext = null;
    return true;
  }

  /**
   * A source-owned battle has not actually concluded until GameLogic has
   * committed the source decision.  A rejected write must never leak a
   * reward/outcome card or discard the persisted active combat snapshot.
   */
  _settlePendingCombatOutcome(outcome, pendingResolution, data) {
    if (!pendingResolution || typeof this.callbacks.onCombatOutcome !== 'function') return true;
    const accepted = this.callbacks.onCombatOutcome(outcome, pendingResolution, data);
    if (accepted !== false && data?.sourceSettlement?.accepted !== false) return true;
    // A full GameStateManager rollback restores the authenticated pre-battle
    // snapshot, including Deck's already-applied base rewards. Lightweight
    // runtimes have no such snapshot and need explicit delta compensation.
    if (outcome === 'victory' && data?.sourceSettlement?.stateRolledBack !== true) {
      this._rollbackBaseCombatRewards(data?.baseRewards);
    }
    this._restoreRejectedCombatOutcome(pendingResolution);
    return false;
  }

  _restoreRejectedCombatOutcome(pendingResolution) {
    const snapshot = this.gameState?.combatSession;
    let restored = false;
    if (snapshot?.active === true && this.deckCombatSystem
      && typeof this.deckCombatSystem.hydrateState === 'function') {
      try {
        restored = this.deckCombatSystem.hydrateState(snapshot) === true;
      } catch (error) {
        restored = false;
      }
    }
    if (restored) {
      this._inCombat = true;
      this._combatWarningShown = false;
      this._pendingCombatCard = null;
      this._activeEncounterContext = snapshot.encounterContext
        ? JSON.parse(JSON.stringify(snapshot.encounterContext))
        : null;
      this._pendingResolution = snapshot.resolutionContext
        ? JSON.parse(JSON.stringify(snapshot.resolutionContext))
        : pendingResolution;
      this._log('【存档】战局结算未能写盘，已恢复到可重试的战斗现场。');
    } else {
      // The authenticated state still carries combatSession, so refresh can
      // resume it. Do not invent a reward card while that recovery is pending.
      this._pendingResolution = pendingResolution;
      this._log('【存档】战局结算未能写盘；战斗快照已保留，请重试或刷新恢复。');
    }
    this._triggerUpdate();
    return restored;
  }

  /**
   * The encounter lifecycle settles synchronously in GameLogic's
   * onCombatOutcome callback, while the durable next card is installed here.
   * Persist only after both operations have completed so a refresh cannot
   * resurrect the just-resolved encounter or lose its outcome card.
   */
  _beginDirectRealmGateDecision(pendingResolution, data) {
    const card = data?.originalCard;
    // Source-choice combat owns its own transaction. The direct terminal gate
    // needs this same combat decision boundary so victory credentials, rewards,
    // world deeds and the visible reward card commit together.
    if (pendingResolution) return null;
    const terminalFinale = this._isTerminalFinale(card);
    const realmGate = this._isRealmGateCard(card) && card?.narrativeSpine?.combatSettlement;
    const dungeonBoss = !realmGate && this._isDirectDungeonBossCard(card);
    if (!card?.id) return null;
    // Reuse the existing atomic direct-outcome boundary for every source-less
    // battle; realm gates and dungeon bosses retain their dedicated receipts.
    const callback = terminalFinale || realmGate ? this.callbacks.onDirectRealmGateDecision
      : dungeonBoss ? this.callbacks.onDirectDungeonBossDecision
        : this.callbacks.onDirectCombatDecision;
    if (typeof callback !== 'function') return null;
    const gate = {
      sourceCardId: card.id,
      encounterInstanceId: data?.encounterContext?.encounterInstanceId,
      cardBefore: this._getCurrentCard(),
      authority: terminalFinale || realmGate ? 'direct_realm_gate'
        : dungeonBoss ? 'direct_dungeon_boss' : 'direct_combat',
      callback
    };
    data.sourceSettlement = { accepted: false, authority: gate.authority };
    if (!gate.encounterInstanceId || this.gameState.beginCausalTransaction?.({ decisionPending: true }) !== true) {
      this._restoreRejectedCombatOutcome(null);
      return false;
    }
    return gate;
  }

  _isDirectDungeonBossCard(card) {
    const state = this.gameState, run = state?.dungeonRun;
    if (!card?.id || card.type !== 'BOSS_COMBAT' || run?.status !== 'active'
      || !run.sessionId || run.dungeonId !== state.dungeon || run.realm !== state.realm
      || card._dungeonNodeId !== state.dungeonNodeId) return false;
    const contract = this.cardSystem?.validateDungeonEntry?.(run.dungeonId, run.realm);
    const node = contract?.dungeon?.graph?.[state.dungeonNodeId];
    return contract?.valid === true && String(node?.type).toUpperCase() === 'BOSS'
      && node.card === card.id;
  }

  _rejectDirectRealmGateDecision(gate, data) {
    // commitTopLevelDecision may already have rolled back. Repeating rollback
    // is harmless; restoreActiveCombat reads the authenticated saved owner.
    this.gameState.rollbackCausalTransaction?.();
    data.sourceSettlement = { accepted: false, authority: gate.authority };
    if (this.callbacks.setCurrentCard) this.callbacks.setCurrentCard(gate.cardBefore);
    this._restoreRejectedCombatOutcome(null);
    return false;
  }

  _finishDirectRealmGateDecision(gate, data) {
    const accepted = gate.callback(gate.sourceCardId, gate.encounterInstanceId);
    if (accepted !== true) return this._rejectDirectRealmGateDecision(gate, data);
    data.sourceSettlement = { accepted: true, authority: gate.authority,
      encounterInstanceId: gate.encounterInstanceId };
    this._triggerUpdate();
    return true;
  }

  _commitOutcomeCheckpoint(pendingResolution, fallbackSourceCard = null) {
    const sourceCardId = pendingResolution?.sourceCard?.id
      || fallbackSourceCard?.id
      || null;
    if (typeof this.callbacks.onDecisionCheckpoint === 'function') {
      return this.callbacks.onDecisionCheckpoint(sourceCardId);
    }
    if (!this.gameState) return false;
    const currentCard = this._getCurrentCard();
    this.gameState.decisionCheckpoint = {
      version: 1,
      cardId: currentCard?.id || null,
      turn: Math.max(0, Number(this.gameState.turn) || 0),
      sourceCardId
    };
    return typeof this.gameState.persistCausalSession === 'function'
      ? this.gameState.persistCausalSession()
      : true;
  }

  _createEncounterContext(card) {
    const rawKind = card?.encounterKind || card?.enemy?.encounterKind || 'ordinary';
    const encounterKind = ['ordinary', 'elite', 'boss', 'realm_boss'].includes(rawKind)
      ? rawKind
      : 'ordinary';
    const lifeCount = Number(this.gameState?.getLifeCount?.() || this.gameState?.unlocks?.lifeCount || 0);
    const turn = Math.max(0, Number(this.gameState?.turn) || 0);
    return {
      // A live combat is the sole encounter owner for one life/turn/card tuple.  The
      // deterministic suffix prevents a restored payload from minting a second
      // reward/terminal owner simply by changing a resealed in-memory counter.
      encounterInstanceId: `enc:${lifeCount}:${turn}:${card?.id || 'unknown'}:1`,
      encounterKind,
      cardId: card?.id || null,
      realm: card?.realm || this.gameState?.realm || 'qi',
      path: this.gameState?.path || null
    };
  }

  _isTerminalFinale(card) {
    return Boolean(
      card
      && card.isFinale === true
      && typeof card.terminalGateId === 'string'
      && card.terminalGateId
      && card.encounterKind === 'realm_boss'
    );
  }

  _beginTerminalVictory(data) {
    const card = data?.originalCard;
    const encounterContext = data?.encounterContext || card?.encounterContext;
    const eligibilitySnapshot = this.endingEligibilityService?.captureEligibilitySnapshot?.(this.gameState);
    if (!this._isTerminalFinale(card)
      || !encounterContext?.encounterInstanceId
      || !eligibilitySnapshot
      || typeof this.gameState?.beginTerminalVictory !== 'function') {
      return false;
    }
    return this.gameState.beginTerminalVictory({
      gateId: card.terminalGateId,
      encounterId: card.id,
      encounterInstanceId: encounterContext.encounterInstanceId,
      victoryToken: `victory:${encounterContext.encounterInstanceId}`,
      outcome: 'victory',
      eligibilitySnapshot
    });
  }

  _isRealmGateCard(card) {
    return !!(card &&
      Number(card.threshold) === 100 &&
      card.combatRewards &&
      card.combatRewards.breakSuccess);
  }

  _clearRealmGatePillCounter(card) {
    if (!this._isRealmGateCard(card) || typeof this.gameState?.setFlag !== 'function') {
      return false;
    }
    const rules = card.combatRules || {};
    const counters = [rules.counter, ...Object.values(rules.counters || {})];
    let flag = counters
      .map(counter => counter?.flag)
      .find(value => typeof value === 'string' && /^used_.+_pill$/.test(value));
    if (!flag) {
      const requiredPill = this.gameState.config?.realms?.realms?.[card.realm]?.pillRequired;
      flag = requiredPill ? `used_${requiredPill}_pill` : null;
    }
    if (!flag || !this.gameState.hasFlag?.(flag)) return false;
    this.gameState.setFlag(flag, false);
    return true;
  }

  _notifyRealmGateOutcome(outcome, card) {
    if (!this._isRealmGateCard(card)) return true;
    if (this.callbacks.onRealmGateOutcome) {
      return this.callbacks.onRealmGateOutcome(outcome, card);
    }
    return false;
  }

  _rollbackBaseCombatRewards(baseRewards) {
    if (!baseRewards || !this.gameState) return false;
    for (const [attribute, value] of Object.entries(baseRewards.attributes || {})) {
      const amount = Number(value) || 0;
      if (!amount) continue;
      if (typeof this.gameState.addAttribute === 'function') {
        this.gameState.addAttribute(attribute, -amount);
      } else if (typeof this.gameState.setAttribute === 'function') {
        const current = typeof this.gameState.getAttribute === 'function'
          ? this.gameState.getAttribute(attribute)
          : this.gameState.attributes?.[attribute];
        this.gameState.setAttribute(attribute, Math.max(0, (Number(current) || 0) - amount));
      }
    }
    for (const [resource, value] of Object.entries(baseRewards.resources || {})) {
      const amount = Number(value) || 0;
      if (amount && typeof this.gameState.addResource === 'function') {
        this.gameState.addResource(resource, null, -amount);
      }
    }
    return true;
  }

  _getDefeatHealthLoss(combatCard, resolutionContext = null) {
    const choice = resolutionContext?.choice;
    if (choice && typeof choice === 'object' && !Array.isArray(choice)) {
      // Source-choice settlement gives legacy effects and choice/rule fields
      // priority over the Deck event. Preserve that protocol for the warning;
      // this is a requested ceiling, not another current-health projection.
      const sourceCombatCard = resolutionContext.combatCard || combatCard;
      const legacyLoss = Number(choice.defeatEffects?.health) < 0
        ? Math.abs(Number(choice.defeatEffects.health)) : 0;
      const requested = Number(legacyLoss || (choice.defeatHealthLoss
        ?? sourceCombatCard?.combatRules?.defeatHealthLoss
        ?? sourceCombatCard?.enemy?.defeatHealthLoss
        // Deck rounds its top-level configuration before publishing the event.
        // A rounded zero then takes the source settlement's tier fallback.
        ?? this._getDefeatHealthLoss(combatCard)));
      if (Number.isFinite(requested) && requested > 0) return Math.round(requested);
      const tier = Number(sourceCombatCard?.enemy?.tier || 1);
      return tier >= 3 ? 3 : tier === 2 ? 2 : 1;
    }
    const explicit = Number(combatCard?.defeatHealthLoss
      ?? combatCard?.combatRules?.defeatHealthLoss
      ?? combatCard?.enemy?.defeatHealthLoss);
    if (Number.isFinite(explicit) && explicit > 0) return Math.round(explicit);
    const tier = Number(combatCard?.enemy?.tier || 1);
    return tier >= 3 ? 3 : tier === 2 ? 2 : 1;
  }

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
    let desc = warningTexts[battlefield] || warningTexts.default;

    // 【筑基雷关·炼气->筑基 石傀定制预警】
    if (combatCard.id === 'ch_qi_100') {
      const rules = combatCard.combatRules || {};
      const counter = rules.counter || {};
      const source = combatCard.bossJourney?.stages?.['60']?.counterSource || {};
      const surviveTurns = Math.max(1, Number(rules.surviveTurns) || 3);
      const damageMultiplier = Number(counter.incomingDamageMultiplier);
      const blockedPercent = Number.isFinite(damageMultiplier)
        ? Math.round((1 - damageMultiplier) * 100)
        : 50;
      const resourceKey = source.resourceKey || 'foundation';
      const counterFlag = counter.flag || 'used_foundation_pill';
      desc = `古石台上的惊雷石傀以铜柱引雷，三息雷律正校验你的道基。若无灵药护持，导入经络的雷火会造成重创；稳住 ${surviveTurns} 回合即可通过雷关。`;
      const hasPill = this.gameState.hasResource('pill', resourceKey);
      if (hasPill) {
        return {
          id: '_warning_' + combatCard.id,
          title: '筑基雷关将启',
          description: desc + `\n\n【机缘提示】：检测到你拥有【筑基丹】。可在此服用，药力将削弱导雷 ${blockedPercent}% 的伤害！`,
          type: 'COMBAT_WARNING',
          _targetCombatCard: combatCard,
          choices: {
            left: {
              text: '吞服筑基丹入关',
              desc: `消耗筑基丹以温养经脉，导雷伤害降低 ${blockedPercent}%。`,
              effects: { _consumePill: resourceKey, _setFlag: counterFlag },
              _confirmCombat: true
            },
            right: {
              text: '以肉身应雷',
              desc: '硬接石傀导雷，不消耗任何丹药。',
              effects: {},
              _confirmCombat: true
            }
          }
        };
      } else {
        return {
          id: '_warning_' + combatCard.id,
          title: '筑基雷关将启',
          description: desc + '\n\n【机缘提示】：你身上没有任何【筑基丹】，此番导雷避无可避，只能凭借护盾和本领稳住道基！',
          type: 'COMBAT_WARNING',
          _targetCombatCard: combatCard,
          choices: {
            left: {
              text: '直面雷关',
              desc: '正面稳住石傀雷击！',
              effects: {},
              _confirmCombat: true
            },
            right: {
              text: '吞吐灵气调整',
              desc: '消耗 10 灵石，恢复 1 点气血后再迎战。',
              effects: { health: 1 },
              costCheck: { spiritStone: 10 },
              _confirmCombat: true
            }
          }
        };
      }
    }

    // 【天劫突破·筑基->金丹 心魔劫定制预警】
    if (combatCard.id === 'ch_foundation_100') {
      const rules = combatCard.combatRules || {};
      const counter = rules.counter || {};
      const source = combatCard.bossJourney?.stages?.['60']?.counterSource || {};
      const daoHeart = this.gameState.attributes.daoHeart || 0;
      const baseHp = Math.max(1, Number(rules.baseHp) || 30);
      const minimumHp = Math.max(1, Number(rules.minimumHp) || 10);
      const daoHeartReduction = Math.max(0, Number(rules.daoHeartHpReductionPerPoint) || 0);
      const openingBlock = Math.max(0, Number(counter.openingBlock) || 0);
      const enemyHpReduction = Math.max(0, Number(counter.enemyHpReduction) || 0);
      const resourceKey = source.resourceKey || 'golden';
      const counterFlag = counter.flag || 'used_golden_pill';
      desc = `心气浮躁间，虚空中涌出滚滚心魔，将你笼罩在无尽幻象中！这是你的金丹心魔大劫。心魔固定根基为 ${baseHp}，你当前道心为 ${daoHeart}；每点道心削去 ${daoHeartReduction} 点，最低压至 ${minimumHp} 点。`;
      const hasPill = this.gameState.hasResource('pill', resourceKey);
      if (hasPill) {
        return {
          id: '_warning_' + combatCard.id,
          title: '金丹心魔劫',
          description: desc + `\n\n【机缘提示】：检测到你拥有【结金丹】。服用后开场获得 ${openingBlock} 点护盾，并削去心魔 ${enemyHpReduction} 点根基！`,
          type: 'COMBAT_WARNING',
          _targetCombatCard: combatCard,
          choices: {
            left: {
              text: '服用结金丹迎战',
              desc: `消耗结金丹，开场获得 ${openingBlock} 点护盾并削去心魔 ${enemyHpReduction} 点根基。`,
              effects: { _consumePill: resourceKey, _setFlag: counterFlag },
              _confirmCombat: true
            },
            right: {
              text: '以道心正面斩魔',
              desc: '正面迎战，不使用结金丹。',
              effects: {},
              _confirmCombat: true
            },
            up: {
              text: '静心沉思',
              desc: '消耗 5 灵石，平复一下颤动的道心。',
              effects: {},
              costCheck: { spiritStone: 5 },
              _confirmCombat: true
            }
          }
        };
      } else {
        return {
          id: '_warning_' + combatCard.id,
          title: '金丹心魔劫',
          description: desc + '\n\n【机缘提示】：你身上没有【结金丹】，此战无法依靠丹药，只能全凭自身道心御魔！',
          type: 'COMBAT_WARNING',
          _targetCombatCard: combatCard,
          choices: {
            left: {
              text: '直面心神拷问',
              desc: '正面迎击！',
              effects: {},
              _confirmCombat: true
            },
            right: {
              text: '静心沉思',
              desc: '消耗 5 灵石，平复一下颤动的道心。',
              effects: {},
              costCheck: { spiritStone: 5 },
              _confirmCombat: true
            }
          }
        };
      }
    }

    // 【天劫突破·金丹->元婴 阴阳雷劫定制预警】
    if (combatCard.id === 'ch_golden_100') {
      const rules = combatCard.combatRules || {};
      const pillCounter = rules.counters?.nascentPill || {};
      const arrayCounter = rules.counters?.lightningArray || {};
      const source = combatCard.bossJourney?.stages?.['60']?.counterSource || {};
      const alternateSource = combatCard.bossJourney?.stages?.['60']?.alternateSource || {};
      const yangMultiplier = Math.max(1, Number(rules.turnCycle?.yang?.damageMultiplier) || 2);
      const yinPiercing = rules.turnCycle?.yin?.piercing === true;
      const resourceKey = source.resourceKey || pillCounter.resourceKey || 'nascent';
      const pillFlag = pillCounter.flag || 'used_nascent_pill';
      const arrayFlag = arrayCounter.flag || alternateSource.flag || 'used_lightning_array';
      const arrayCost = Math.max(0, Number(arrayCounter.cost?.spiritStone ?? alternateSource.cost) || 0);
      const openingBlock = Math.max(0, Number(arrayCounter.openingBlock) || 0);
      desc = `金丹圆满，碎丹化婴！劫雷奇数回合降下“阳雷”（${yangMultiplier} 倍伤害，可被盾挡），偶数回合降下“阴雷”（${yinPiercing ? '穿透护盾直击本源' : '普通雷击'}）。避雷阵可提供 ${openingBlock} 点开局护盾。`;
      const hasPill = this.gameState.hasResource('pill', resourceKey);
      if (hasPill) {
        return {
          id: '_warning_' + combatCard.id,
          title: '元婴天劫将至',
          description: desc + '\n\n【机缘提示】：检测到你拥有【凝婴丹】。服用后可在战斗中保护元神，使阴雷无法穿透护甲！',
          type: 'COMBAT_WARNING',
          _targetCombatCard: combatCard,
          choices: {
            left: {
              text: '吞服凝婴丹迎战',
              desc: '消耗凝婴丹，药力护住泥丸宫，免疫阴雷穿甲效果。',
              effects: { _consumePill: resourceKey, _setFlag: pillFlag },
              _confirmCombat: true
            },
            right: {
              text: '布避雷阵迎击',
              desc: `花费 ${arrayCost} 灵石布下御雷大阵，战斗开始获得 ${openingBlock} 点护盾。`,
              effects: { _setFlag: arrayFlag },
              costCheck: { spiritStone: arrayCost },
              _confirmCombat: true
            },
            up: {
              text: '凭肉身硬接雷劫',
              desc: '不做准备，直接出战。',
              effects: {},
              _confirmCombat: true
            }
          }
        };
      } else {
        return {
          id: '_warning_' + combatCard.id,
          title: '元婴天劫将至',
          description: desc + '\n\n【机缘提示】：你没有【凝婴丹】，偶数回合需特别警惕阴雷对气血的无视盾牌伤害！',
          type: 'COMBAT_WARNING',
          _targetCombatCard: combatCard,
          choices: {
            left: {
              text: '布避雷法阵',
              desc: `花费 ${arrayCost} 灵石布下避雷大阵，获得 ${openingBlock} 点开局护盾。`,
              effects: { _setFlag: arrayFlag },
              costCheck: { spiritStone: arrayCost },
              _confirmCombat: true
            },
            right: {
              text: '肉身硬顶天威',
              desc: '直接迎战！',
              effects: {},
              _confirmCombat: true
            }
          }
        };
      }
    }

    // 【天劫突破·元婴->化神 虚空雷罚定制预警】
    if (combatCard.id === 'ch_nascent_100') {
      const rules = combatCard.combatRules || {};
      const backlash = rules.attackBacklash || {};
      const counter = backlash.counter || {};
      const source = combatCard.bossJourney?.stages?.['60']?.counterSource || {};
      const backlashDamage = Math.max(0, Number(backlash.damage) || 0);
      const triggerCardType = backlash.triggerCardType || 'attack';
      const resourceKey = source.resourceKey || counter.resourceKey || 'deity';
      const counterFlag = counter.flag || 'used_deity_pill';
      const enemyHpReduction = Math.max(0, Number(counter.enemyHpReduction) || 0);
      desc = `九天玄雷狂暴积蓄，虚空撕裂！虚空雷罚拥有“天机反噬”：每打出一张【${triggerCardType === 'attack' ? '攻击卡' : triggerCardType}】，反噬天雷便直接扣减 ${backlashDamage} 点气血，不受护体值抵挡。`;
      const hasPill = this.gameState.hasResource('pill', resourceKey);
      if (hasPill) {
        return {
          id: '_warning_' + combatCard.id,
          title: '化神虚空雷罚',
          description: desc + `\n\n【机缘提示】：检测到你拥有【化神丹】。服用后可洗练因果天机，完全免除攻击反噬伤害，且削弱雷罚 ${enemyHpReduction} 点根基！`,
          type: 'COMBAT_WARNING',
          _targetCombatCard: combatCard,
          choices: {
            left: {
              text: '服用化神丹出战',
              desc: '消耗化神丹，洗练周身尘缘，完全免疫天机反噬，弱化雷罚。',
              effects: { _consumePill: resourceKey, _setFlag: counterFlag },
              _confirmCombat: true
            },
            right: {
              text: '逆天硬闯雷劫',
              desc: '保留自身锋芒，不做额外防护硬战！',
              effects: {},
              _confirmCombat: true
            }
          }
        };
      } else {
        return {
          id: '_warning_' + combatCard.id,
          title: '化神虚空雷罚',
          description: desc + '\n\n【机缘提示】：你没有【化神丹】，在战斗中需尽量减少使用普通攻击牌以防反噬！',
          type: 'COMBAT_WARNING',
          _targetCombatCard: combatCard,
          choices: {
            left: {
              text: '硬闯天罚',
              desc: '直接迎战！',
              effects: {},
              _confirmCombat: true
            },
            right: {
              text: '吐纳平复气血',
              desc: '消耗 15 灵石，调息恢复 1 气血后再战。',
              effects: { health: 1 },
              costCheck: { spiritStone: 15 },
              _confirmCombat: true
            }
          }
        };
      }
    }

    // 【天劫突破·化神->渡劫 九重天劫定制预警】
    if (combatCard.id === 'ch_deity_100') {
      const rules = combatCard.combatRules || {};
      const karmaDamage = rules.karmaDamage || {};
      const counter = rules.counter || {};
      const karmaAttribute = karmaDamage.attribute || 'karmaBad';
      const badKarma = Number(this.gameState.attributes?.[karmaAttribute]) || 0;
      const perPoints = Math.max(1, Number(karmaDamage.perPoints) || 1);
      const damagePerStep = Math.max(0, Number(karmaDamage.damagePerStep) || 0);
      const openingBlock = Math.max(0, Number(counter.openingBlock) || 0);
      const enemyAttackReduction = Math.max(0, Number(counter.enemyAttackReduction) || 0);
      const counterFlag = counter.flag || 'used_relic_shield';
      const consumeEffectKey = counter.consumeEffectKey || '_consumeTreasure';
      desc = `九霄云涌，九重雷龙狂啸！天雷与因果紧密相连：当前恶业 ${badKarma}，每 ${perPoints} 点恶业使雷击伤害额外 +${damagePerStep}。`;
      const hasTreasure = typeof treasureSystem !== 'undefined' && treasureSystem
        && (treasureSystem.getEquippedInstanceIds?.().length || 0) > 0;
      if (hasTreasure) {
        return {
          id: '_warning_' + combatCard.id,
          title: '九重雷劫降临',
          description: desc + `\n\n【机缘提示】：检测到你已穿戴法宝。可碎裂一件穿戴中的法宝，获得 ${openingBlock} 护盾且天劫攻击 -${enemyAttackReduction}！`,
          type: 'COMBAT_WARNING',
          _targetCombatCard: combatCard,
          choices: {
            left: {
              text: '以法宝分担天雷',
              desc: `消耗一件穿戴中的法宝代劫，获得 ${openingBlock} 护盾且天劫攻击 -${enemyAttackReduction}。`,
              effects: { [consumeEffectKey]: true, _setFlag: counterFlag },
              _confirmCombat: true
            },
            right: {
              text: '以肉身硬抗九天',
              desc: '硬抗天雷！若能成功获胜，将磨砺道心，胜后额外获得 2 点道心！',
              effects: {},
              _confirmCombat: true
            }
          }
        };
      } else {
        return {
          id: '_warning_' + combatCard.id,
          title: '九重雷劫降临',
          description: desc + '\n\n【机缘提示】：你身上别无法宝，只能以血肉躯体硬撼雷霆！若胜，额外获得 2 点道心！',
          type: 'COMBAT_WARNING',
          _targetCombatCard: combatCard,
          choices: {
            left: {
              text: '以肉身迎战',
              desc: '正面硬撑！',
              effects: {},
              _confirmCombat: true
            },
            right: {
              text: '吞吐灵石调息',
              desc: '消耗 20 灵石，恢复 1 点气血后再迎战。',
              effects: { health: 1 },
              costCheck: { spiritStone: 20 },
              _confirmCombat: true
            }
          }
        };
      }
    }

    // 【天劫突破·渡劫->飞升 飞升大劫定制预警】
    if (combatCard.id === 'ch_tribulation_100') {
      const judgment = combatCard.combatRules?.karmaJudgment || {};
      const goodDraw = Math.max(0, Number(judgment.goodDraw) || 0);
      const badDiscard = Math.max(0, Number(judgment.badDiscard) || 0);
      const reincarnationSource = combatCard.bossJourney?.stages?.['80']?.alternateSource || {};
      desc = `这是最后的飞升神雷大劫，你将面对天道意志本身！每回合抽牌后发起“天道审判”：善业高则额外抽 ${goodDraw} 张，恶业高则随机弃 ${badDiscard} 张。接住此劫即可飞升。`;
      return {
        id: '_warning_' + combatCard.id,
        title: '九九飞升大劫',
        description: desc + '\n\n【天命抉择】：选择兵解重修将直接终止战斗进入下世轮回，但能带走 2 点道心和部分前世遗赠；选择迎战胜则登仙，败则重伤甚至可能陨落！',
        type: 'COMBAT_WARNING',
        _targetCombatCard: combatCard,
        choices: {
          left: {
            text: '拼死搏击天门',
            desc: '迎战天道意志！胜则白日飞升！',
            effects: {},
            _confirmCombat: true
          },
          right: {
            text: '兵解遁入轮回',
            desc: '散去修为，带走 2 点道心主动转世。',
            effects: {
              reincarnation_bonus: 'daoHeart +2',
              [reincarnationSource.effectKey || 'reincarnate']: true
            }
          }
        }
      };
    }

    return {
      id: '_warning_' + combatCard.id,
      title: combatCard.combatPresentation?.warningTitle || '危险预感',
      description: desc + (combatCard.combatPresentation?.mechanic
        ? `\n\n【战局情报】${combatCard.combatPresentation.mechanic}`
        : ''),
      type: 'COMBAT_WARNING',
      sceneImage: combatCard.combatPresentation?.sceneImage || combatCard.sceneImage,
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

  _captureSettlementState() {
    const attributes = {};
    const resources = {};
    for (const [key, value] of Object.entries(this.gameState?.attributes || {})) {
      if (Number.isFinite(Number(value))) attributes[key] = Number(value);
    }
    for (const [key, value] of Object.entries(this.gameState?.resources || {})) {
      if (Number.isFinite(Number(value))) resources[key] = Number(value);
    }
    return {
      attributes,
      resources,
      deck: Array.isArray(this.gameState?.deck) ? [...this.gameState.deck] : []
    };
  }

  _diffSettlementState(before, after) {
    const diff = { attributes: {}, resources: {}, cards: [] };
    for (const group of ['attributes', 'resources']) {
      const keys = new Set([
        ...Object.keys(before?.[group] || {}),
        ...Object.keys(after?.[group] || {})
      ]);
      for (const key of keys) {
        const delta = Number(after?.[group]?.[key] || 0) - Number(before?.[group]?.[key] || 0);
        if (delta) diff[group][key] = delta;
      }
    }
    diff.cards = (after?.deck || []).filter(cardId => !(before?.deck || []).includes(cardId));
    return diff;
  }

  _mergeSettlementSummary(baseRewards, sourceDelta) {
    const summary = { attributes: {}, resources: {}, cards: [] };
    for (const group of ['attributes', 'resources']) {
      const keys = new Set([
        ...Object.keys(baseRewards?.[group] || {}),
        ...Object.keys(sourceDelta?.[group] || {})
      ]);
      for (const key of keys) {
        const total = Number(baseRewards?.[group]?.[key] || 0) + Number(sourceDelta?.[group]?.[key] || 0);
        if (total) summary[group][key] = total;
      }
    }
    summary.cards = [
      ...(Array.isArray(baseRewards?.cards) ? baseRewards.cards : []),
      ...(Array.isArray(sourceDelta?.cards) ? sourceDelta.cards : [])
    ].filter((cardId, index, all) => all.indexOf(cardId) === index);
    return summary;
  }

  _formatSettlementSummary(summary) {
    const labels = {
      cultivation: '修为',
      health: '气血',
      daoHeart: '道心',
      karmaGood: '善缘',
      karmaBad: '恶业',
      fortune: '气运',
      aura: '灵气',
      spiritStone: '灵石',
      lifespan: '寿元'
    };
    const order = [
      ['attributes', 'cultivation'],
      ['resources', 'spiritStone'],
      ['attributes', 'health'],
      ['attributes', 'daoHeart'],
      ['attributes', 'karmaGood'],
      ['attributes', 'karmaBad'],
      ['attributes', 'fortune'],
      ['attributes', 'aura'],
      ['resources', 'lifespan']
    ];
    const numericRewards = order
      .map(([group, key]) => {
        const value = Number(summary?.[group]?.[key] || 0);
        return value ? `${labels[key]} ${value > 0 ? '+' : ''}${value}` : null;
      })
      .filter(Boolean);
    const cardRewards = (summary?.cards || []).map(cardId => {
      const name = this.deckCombatSystem?.cardDB?.[cardId]?.name || cardId;
      return `新技能【${name}】`;
    });
    return [...numericRewards, ...cardRewards];
  }

  _buildDeckRewardChoices({ channel, sourceId, includeSkip, continuationCardId = null }) {
    // A route continuation is authored by the victorious source's outcome
    // presentation. It is a post-reward transition only: reward ownership,
    // card acquisition and every combat number stay in their existing systems.
    const continuation = typeof continuationCardId === 'string'
      && continuationCardId.trim()
      && this.cardSystem?.getCard?.(continuationCardId)
      ? continuationCardId
      : null;
    const playerPath = this.gameState.path || 'sword';
    const offers = this.skillCardAcquisitionSystem?.getRewardOffers({
      path: playerPath,
      channel,
      count: 3
    }) || [];
    const directions = includeSkip ? ['left', 'right', 'up'] : ['left', 'right', 'down'];
    const choices = {};
    offers.forEach((offer, index) => {
      const direction = directions[index];
      if (!direction) return;
      choices[direction] = {
        text: `参悟【${offer.cardName}】`,
        desc: `${offer.description || '将本流派功法纳入识海。'}\n\n【来源】${channel === 'breakthrough' ? '境界突破' : '战斗缴获'}`,
        effects: {
          deckCard: {
            cardId: offer.cardId,
            path: playerPath,
            sourceType: offer.sourceType,
            sourceId
          }
        },
        ...(continuation ? { nextCard: continuation } : {})
      };
    });
    if (includeSkip || !choices.down) {
      choices.down = {
        text: includeSkip ? '不纳新法，整理战利品离去' : '稳固识海离去',
        desc: '保留当前牌组，不取得新功法。',
        effects: {},
        // This is a zero-value declination. Its authored continuation is the
        // next readable scene, so retain the settlement in the log rather
        // than pinning a generic value receipt over that scene.
        settlementFeedbackMode: 'log_only',
        ...(continuation ? { nextCard: continuation } : {})
      };
    }
    return choices;
  }

  /**
   * Rebuild the unresolved reward for a non-terminal realm gate.  The reward is
   * deliberately derived from the authored gate and the durable realm
   * transaction instead of trusting a serialized choice/effect payload: the
   * victory has already been settled, while the player's inheritance choice has
   * not.
   */
  restorePendingRealmTransitionReward(transition) {
    if (!transition
      || transition.status !== 'inheritance_pending'
      || typeof transition.sourceCardId !== 'string'
      || transition.to !== this.gameState?.realm
      || transition.pathAtPromotion !== this.gameState?.path) {
      return null;
    }
    // Realm gates are owned by RealmChapterSystem rather than CardSystem's
    // ordinary-draw cache.  Resolve through both explicit owners so a reload
    // does not silently downgrade a completed gate to a normal card draw.
    const sourceCard = this.cardSystem?.getCard?.(transition.sourceCardId)
      || this.chapterSystem?.getMilestoneCard?.(transition.from, 100, transition.pathAtPromotion)
      || (typeof chapterSystem !== 'undefined'
        ? chapterSystem?.getMilestoneCard?.(transition.from, 100, transition.pathAtPromotion)
        : null);
    if (!sourceCard
      || sourceCard.realm !== transition.from
      || Number(sourceCard.threshold) !== 100
      || sourceCard.combatRewards?.breakSuccess !== true) {
      return null;
    }
    return this._buildBreakthroughRewardCard(sourceCard);
  }

  _buildBreakthroughRewardCard(originalCard, rewardText = '', victoryPresentation = null) {
    const authoredPresentation = originalCard?.combatPresentation || {};
    const visualWorldId = victoryPresentation?.visualWorldId
      || authoredPresentation.visualWorldId || originalCard?.visualWorldId || null;
    const uiMaterialId = victoryPresentation?.visualWorld?.uiMaterial?.id
      || authoredPresentation.uiMaterialId || originalCard?.uiMaterialId || null;
    const hasWorldContract = typeof visualWorldId === 'string' && visualWorldId
      && typeof uiMaterialId === 'string' && uiMaterialId;
    return {
      id: 'breakthrough_reward',
      type: 'NORMAL',
      sceneImage: victoryPresentation?.sceneImage || authoredPresentation.sceneImage || originalCard?.sceneImage
        || 'assets/cards/events/scene_pool_breakthrough.png',
      combatPresentationId: victoryPresentation?.presentationId || authoredPresentation.presentationId || null,
      visualWorldId: hasWorldContract ? visualWorldId : null,
      uiMaterialId: hasWorldContract ? uiMaterialId : null,
      visualSurface: hasWorldContract ? 'combat_settlement_ledger' : null,
      title: '神意蜕变 · 本命传承',
      description: `九天惊雷渐渐散去，你历经雷劫心魔的千锤百炼，肉身神魂皆脱胎换骨。${rewardText}\n\n在灵台清明的一瞬间，你感受到了功法法则的召唤，请在传承的法诀中选择其一参悟！`,
      choices: this._buildDeckRewardChoices({
        channel: 'breakthrough',
        sourceId: originalCard?.id || 'breakthrough',
        includeSkip: false
      })
    };
  }

  _buildCombatRewardCard(data, settlementSummary = null, pendingResolution = null) {
    const originalCard = data && data.originalCard;
    const presentation = data?.presentation || null;
    const presentationWorld = presentation?.visualWorld || null;
    const presentationUiMaterial = presentationWorld?.uiMaterial || null;
    const rewardWorldContract = presentation?.visualWorldCompatible === true
      && typeof presentation?.visualWorldId === 'string'
      && presentation.visualWorldId
      && presentationWorld?.id === presentation.visualWorldId
      && presentationUiMaterial?.visualWorldId === presentation.visualWorldId
      && typeof presentationUiMaterial?.id === 'string'
      && presentationUiMaterial.id
      ? {
          visualWorldId: presentation.visualWorldId,
          uiMaterialId: presentationUiMaterial.id,
          mediaDensity: presentationUiMaterial.mediaDensity || null,
          logicalPixelGrid: Number(presentationUiMaterial.logicalPixelGrid) || null
        }
      : null;
    const outcomePresentation = pendingResolution?.choice?.combatOutcomePresentation?.victory || null;
    const continuationCardId = typeof outcomePresentation?.nextCard === 'string'
      && outcomePresentation.nextCard.trim()
      && this.cardSystem?.getCard?.(outcomePresentation.nextCard)
      ? outcomePresentation.nextCard
      : null;
    let rewardText = '';
    let isBreakthrough = false;

    // 应用原卡的 combatRewards
    if (originalCard && originalCard.combatRewards) {
      const rw = originalCard.combatRewards;
      const RouterClass = typeof ChoiceOutcomeRouter !== 'undefined' ? ChoiceOutcomeRouter : null;
      const split = this.choiceOutcomeRouter?.splitCombatRewardFields?.(rw)
        || RouterClass?.splitCombatRewardFields?.(rw)
        || this._splitLegacyCombatRewardFields(rw);
      if (!split.valid) {
        this._log(`【战斗奖励拒绝】${originalCard.id || 'unknown'} 包含未登记字段：${split.unknownFields.join(', ')}`);
      } else {
        const effectKeys = Object.keys(split.effects);
        const application = effectKeys.length > 0
          ? this.effectService.apply(split.effects, this._effectContext())
          : { applied: true };
        if (!application || application.applied !== true) {
          this._log(`【战斗奖励拒绝】${originalCard.id || 'unknown'} 的数值奖励未返回显式成功，控制字段未消费。`);
        } else {
          const rwStrs = [];
          if (split.effects.spiritStone) rwStrs.push(`灵石 +${split.effects.spiritStone}`);
          if (split.effects.cultivation) rwStrs.push(`修为 +${split.effects.cultivation}`);
          if (split.effects.karmaGood) rwStrs.push(`善缘 +${split.effects.karmaGood}`);
          if (split.effects.karmaBad) rwStrs.push(`恶业 +${split.effects.karmaBad}`);
          if (rwStrs.length > 0) {
            rewardText = `\n\n除了战利品，你还获得了：${rwStrs.join('，')}。`;
          }
          if (split.controls.breakSuccess) {
            isBreakthrough = true;
            rewardText += '\n\n【境界突破】：劫数已过，你感觉体内的力量正在蜕变！';
            if (!this._isTerminalFinale(originalCard) && this.callbacks.onResolveBreakthrough) {
              this.callbacks.onResolveBreakthrough(1, originalCard, true);
            }
          }
        }
      }
    }

    const exactRewards = this._formatSettlementSummary(settlementSummary);
    if (exactRewards.length) {
      rewardText = `\n\n【本次结算】${exactRewards.join('，')}。` + rewardText;
    }

    if (isBreakthrough) {
      return this._buildBreakthroughRewardCard(originalCard, rewardText, presentation);
    }

    // 普通胜利提供本流派三选一，并保留不扩充牌组的离开入口。
    return {
      id: 'combat_reward',
      type: 'NORMAL',
      sceneImage: outcomePresentation?.sceneImage || pendingResolution?.sourceCard?.sceneImage
        || data?.presentation?.sceneImage || originalCard?.combatPresentation?.sceneImage || 'assets/cards/events/scene_pool_market.png',
      combatPresentationId: data?.presentation?.presentationId || originalCard?.combatPresentation?.presentationId || null,
      visualWorldId: rewardWorldContract?.visualWorldId || null,
      uiMaterialId: rewardWorldContract?.uiMaterialId || null,
      visualWorldMediaDensity: rewardWorldContract?.mediaDensity || null,
      visualWorldLogicalPixelGrid: rewardWorldContract?.logicalPixelGrid || null,
      visualSurface: rewardWorldContract ? 'combat_settlement_ledger' : null,
      title: outcomePresentation?.title || '大胜 · 择法',
      description: `${outcomePresentation?.description ? `${outcomePresentation.description}\n\n` : ''}战斗结束。你从对手散落的行功痕迹里辨出三条本脉法门；可取其一，也可保持精简。${rewardText}`,
      choices: this._buildDeckRewardChoices({
        channel: 'battle',
        sourceId: originalCard?.id || data?.cardId || 'combat_reward',
        includeSkip: true,
        continuationCardId
      })
    };
  }

  _splitLegacyCombatRewardFields(rewards) {
    if (!rewards || typeof rewards !== 'object' || Array.isArray(rewards)) {
      return { valid: false, unknownFields: ['$invalid_combat_reward_map'], effects: {}, controls: {} };
    }
    const effects = { ...rewards };
    const controls = {};
    if (Object.prototype.hasOwnProperty.call(effects, 'breakSuccess')) {
      controls.breakSuccess = effects.breakSuccess;
      delete effects.breakSuccess;
    }
    return { valid: true, unknownFields: [], effects, controls };
  }

  restorePendingTerminalReward() {
    const context = this.gameState?.getTerminalContext?.();
    if (!context
      || context.stage !== 'REWARD_PENDING'
      || context.consumed !== false
      || this.gameState?.pendingCardId !== 'breakthrough_reward') {
      return null;
    }
    const originalCard = this.cardSystem?.getCard?.(context.encounterId) || {
      id: context.encounterId,
      isFinale: true,
      terminalGateId: context.gateId
    };
    return {
      id: 'breakthrough_reward',
      type: 'NORMAL',
      sceneImage: originalCard?.combatPresentation?.sceneImage || 'assets/cards/events/scene_pool_breakthrough.png',
      title: '神意蜕变 · 本命传承',
      description: '最终天劫已经伏下，胜利事实已封入命盘。选择一门本脉法诀后，天道将据你的证据与旧愿裁定此世结局。',
      terminalVictoryToken: context.victoryToken,
      choices: this._buildDeckRewardChoices({
        channel: 'breakthrough',
        sourceId: originalCard?.id || context.encounterId,
        includeSkip: false
      })
    };
  }

  _buildCombatOutcomeCard(outcome, data, pendingResolution) {
    const sourceCard = pendingResolution?.sourceCard || data?.originalCard || {};
    const enemyName = data?.originalCard?.enemy?.name || sourceCard?.enemy?.name || '敌手';
    const outcomePresentation = pendingResolution?.choice?.combatOutcomePresentation?.[outcome] || null;
    const sceneImage = outcomePresentation?.sceneImage || sourceCard?.sceneImage
      || sourceCard?.combatPresentation?.sceneImage || 'assets/cards/events/scene_pool_dungeon_cave.png';
    if (outcome === 'flee') {
      return {
        id: 'combat_fled_' + (sourceCard.id || 'unknown'),
        type: 'NORMAL',
        sceneImage,
        combatPresentationId: data?.presentation?.presentationId || sourceCard?.combatPresentation?.presentationId || null,
        title: outcomePresentation?.title || '脱离战场',
        description: outcomePresentation?.description || `你抓住${enemyName}攻势转换的间隙退出战局。道路暂时保住了，但这场未完的冲突会留下后果。`,
        choices: {
          down: { text: '收敛气息，继续前行', effects: {} }
        }
      };
    }
    // Legacy successful callbacks may not provide an exact amount. Never
    // substitute a configured loss (or zero) for a missing applied receipt.
    const appliedInjury = data?.appliedDefeatHealthLoss;
    const injuryText = typeof appliedInjury === 'number' && Number.isFinite(appliedInjury) && appliedInjury >= 0
      ? `离场伤势使真实气血减少 ${appliedInjury} 点`
      : '本次伤势数值未记录，请以当前气血为准';
    return {
      id: 'combat_defeat_' + (sourceCard.id || 'unknown'),
      type: 'NORMAL',
      sceneImage,
      combatPresentationId: data?.presentation?.presentationId || sourceCard?.combatPresentation?.presentationId || null,
      title: outcomePresentation?.title || '重伤退却',
      description: outcomePresentation?.description || `${enemyName}压过了你的最后一轮攻势。局内护体值已经耗尽，${injuryText}；任务没有完成，胜利奖励也不会发放。`,
      choices: {
        down: { text: '稳住伤势，记下此败', effects: {} }
      }
    };
  }

  _handleDeath() {
    if (this.gameState.lifePhase === 'EPILOGUE' || (typeof this.gameState.isInEnding === 'function' && this.gameState.isInEnding())) {
      this._log(`[死亡处理] 处于 EPILOGUE 结局阶段，拒绝触发普通死亡逻辑`);
      this._inCombat = false;
      this._triggerUpdate();
      return;
    }
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
    this._pendingResolution = null;
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

  /** Explicit encounter outcome links are the authority for authored faction
   * trials. The old generic reputation heuristic remains only for unlinked
   * legacy combat, so it cannot negate or double an authored result. */
  _hasExplicitFactionOutcomeLink(pendingResolution, outcome) {
    const effects = pendingResolution?.choice?.combatOutcomeLinks?.[outcome]?.factionEffects;
    return Boolean(effects && typeof effects.factionId === 'string' && effects.factionId);
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

if (typeof module !== 'undefined' && module.exports) {
  module.exports = CombatCoordinator;
}
