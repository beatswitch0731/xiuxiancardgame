/**
 * LegacyFragmentSystem — 传承残卷掉落系统 (GDD 上瘾引擎 §2)
 *
 * 核心机制：
 *   - 每张普通卡牌后有概率掉落传承残卷
 *   - 境界越高，掉落概率越大
 *   - 6 套传承套装，各 8 片碎片
 *   - 集齐 8 片 → 合成传承，获得永久被动加成
 *   - Boss 战斗胜利保证掉落
 */
const LEGACY_PACING_CONTRACT = Object.freeze({
  pityMissLimit: 7,
  focusedWeight: 0.60,
  ordinaryDropRates: Object.freeze({
    qi: 0.08,
    foundation: 0.085,
    golden: 0.09,
    nascent: 0.095,
    deity: 0.10,
    tribulation: 0.10
  })
});

class LegacyFragmentSystem {
  constructor({ deckAuthority = null, gameState: state = null } = {}) {
    this.gameState = state || (typeof gameState !== 'undefined' ? gameState : null);
    this.onLog = null;
    this.deckAuthority = null;
    this._resetListenerBound = false;
    this.setDeckAuthority(deckAuthority);
  }

  setGameState(state) {
    this.gameState = state || null;
    return this.gameState;
  }

  setDeckAuthority(deckAuthority) {
    this.deckAuthority = deckAuthority && typeof deckAuthority.acquireLegacyCard === 'function'
      ? deckAuthority
      : null;
    return this.deckAuthority;
  }

  init() {
    this._ensureState();
    if (!this._resetListenerBound && typeof eventBus !== 'undefined' && eventBus) {
      eventBus.on('state:reset', () => this.reset());
      this._resetListenerBound = true;
    }
  }

  reset() {
    this._ensureState();
  }

  _resolveGameState() {
    if (this.gameState) return this.gameState;
    if (typeof gameState !== 'undefined' && gameState) {
      this.gameState = gameState;
      return this.gameState;
    }
    return null;
  }

  _setIds() {
    return Object.keys(this._sets());
  }

  _rebirthEffect(key) {
    return typeof lineageSystem !== 'undefined' && lineageSystem
      ? Number(lineageSystem.getEffectValue?.(key)) || 0
      : 0;
  }

  getPacingContract() {
    const pityMissLimit = Math.max(
      5,
      LEGACY_PACING_CONTRACT.pityMissLimit - Math.floor(Math.max(0, this._rebirthEffect('pityReduction')))
    );
    const focusedWeight = Math.min(
      0.75,
      LEGACY_PACING_CONTRACT.focusedWeight + Math.max(0, this._rebirthEffect('focusedWeightBonus'))
    );
    return {
      pityMissLimit,
      focusedWeight,
      ordinaryDropRates: Object.fromEntries(Object.entries(LEGACY_PACING_CONTRACT.ordinaryDropRates)
        .map(([realm, rate]) => [realm, Math.min(0.12, rate + Math.max(0, this._rebirthEffect('ordinaryDropBonus')))]))
    };
  }

  _createFallbackArchive() {
    const fragmentsBySet = {};
    for (const setId of this._setIds()) fragmentsBySet[setId] = 0;
    return {
      schemaVersion: 1,
      migrationVersion: 1,
      fragmentsBySet,
      completedSetIds: [],
      discoveredVariantCardIds: [],
      migrationDiagnostics: { unknownSetIds: [] }
    };
  }

  _createFallbackRunState() {
    const state = this._resolveGameState();
    return {
      lifeCount: Number(state?.getLifeCount?.() || state?.unlocks?.lifeCount || 0),
      focusedSetId: null,
      activeSetIds: [],
      inheritedSetId: null,
      pendingInheritanceChoice: null,
      ordinaryMissStreak: 0,
      pendingBossFragmentReward: null,
      claimedEncounterInstanceIds: []
    };
  }

  _archive() {
    const state = this._resolveGameState();
    if (!state) return null;
    if (typeof state.getLegacyArchive === 'function') return state.getLegacyArchive();
    if (!state.unlocks) state.unlocks = {};
    if (!state.unlocks.legacyArchive || typeof state.unlocks.legacyArchive !== 'object') {
      state.unlocks.legacyArchive = this._createFallbackArchive();
    }
    const archive = state.unlocks.legacyArchive;
    if (!archive.fragmentsBySet || typeof archive.fragmentsBySet !== 'object') {
      archive.fragmentsBySet = this._createFallbackArchive().fragmentsBySet;
    }
    if (!Array.isArray(archive.completedSetIds)) archive.completedSetIds = [];
    if (!Array.isArray(archive.discoveredVariantCardIds)) archive.discoveredVariantCardIds = [];
    return archive;
  }

  _runState() {
    const state = this._resolveGameState();
    if (!state) return null;
    if (typeof state.getLegacyRunState === 'function') return state.getLegacyRunState();
    if (!state.unlocks) state.unlocks = {};
    if (!state.unlocks.causalSessionState || typeof state.unlocks.causalSessionState !== 'object') {
      state.unlocks.causalSessionState = { lifeCount: state.getLifeCount?.() || 0 };
    }
    if (!state.unlocks.causalSessionState.legacyRunState
      || typeof state.unlocks.causalSessionState.legacyRunState !== 'object') {
      state.unlocks.causalSessionState.legacyRunState = this._createFallbackRunState();
    }
    return state.unlocks.causalSessionState.legacyRunState;
  }

  _ensureState() {
    return Boolean(this._archive() && this._runState());
  }

  _fragmentCount(setId) {
    const archive = this._archive();
    const pieces = this._sets()[setId]?.pieces || 8;
    return Math.max(0, Math.min(pieces, Math.floor(Number(archive?.fragmentsBySet?.[setId]) || 0)));
  }

  _setFragmentCount(setId, value) {
    const archive = this._archive();
    const pieces = this._sets()[setId]?.pieces || 8;
    if (!archive || !Object.prototype.hasOwnProperty.call(this._sets(), setId)) return false;
    archive.fragmentsBySet[setId] = Math.max(0, Math.min(pieces, Math.floor(Number(value) || 0)));
    return true;
  }

  _persist() {
    const state = this._resolveGameState();
    if (!state) return false;
    if (typeof state.persistLegacyState === 'function') return state.persistLegacyState();
    if (typeof state.persistCausalSession === 'function') return state.persistCausalSession();
    if (typeof state.persistUnlocks === 'function') {
      state.persistUnlocks();
      return true;
    }
    if (typeof state._saveUnlocks === 'function') {
      state._saveUnlocks();
      return true;
    }
    return false;
  }

  get fragments() {
    const system = this;
    return new Proxy({}, {
      get(_target, setId) {
        if (typeof setId !== 'string' || !system._sets()[setId]) return undefined;
        const count = system._fragmentCount(setId);
        const pieces = system._sets()[setId].pieces;
        return Array.from({ length: pieces }, (_value, index) => index < count);
      },
      set(_target, setId, value) {
        if (typeof setId !== 'string' || !system._sets()[setId]) return false;
        const count = Array.isArray(value) ? value.filter(Boolean).length : value;
        system._setFragmentCount(setId, count);
        system._persist();
        return true;
      }
    });
  }

  get completed() {
    return this._archive()?.completedSetIds || [];
  }

  set completed(value) {
    const archive = this._archive();
    if (!archive) return;
    archive.completedSetIds = Array.from(new Set((Array.isArray(value) ? value : [])
      .filter(setId => typeof setId === 'string' && this._sets()[setId])));
    for (const setId of archive.completedSetIds) {
      this._setFragmentCount(setId, this._sets()[setId].pieces);
    }
    this._persist();
  }

  /**
   * 6 传承套装定义
   */
  _sets() {
    return {
      sword_heart: {
        name: '剑心通明',
        effect: '本世暴击率 +5%',
        pieces: 8,
        icon: '⚔',
        sigil: '剑',
        passive: { critRate: 5 }
      },
      pill_way: {
        name: '丹道真解',
        effect: '本世丹药治疗与丹毒效果 +15%',
        pieces: 8,
        icon: '💊',
        sigil: '丹',
        passive: { pillBonus: 15 }
      },
      array_way: {
        name: '阵法玄机',
        effect: '开战护盾 +3；道心伤害减免 10%',
        pieces: 8,
        icon: '🔮',
        sigil: '阵',
        passive: { combatStartBlock: 3, daoResist: 10 }
      },
      heaven_book: {
        name: '天书残卷',
        effect: '激活时福缘 +3；修为正收益 +10%',
        pieces: 8,
        icon: '📜',
        sigil: '书',
        passive: { cultivationBonus: 10 },
        activation: { fortune: 3 }
      },
      demon_blood: {
        name: '魔血传承',
        effect: '气血≤50%时伤害 +2；道心上限 -2',
        pieces: 8,
        icon: '🩸',
        sigil: '煞',
        passive: { lowHpDamageBonus: 2, daoHeartPenalty: -2 }
      },
      immortal_will: {
        name: '仙人之志',
        effect: '最大气血 +6；本世寿元 +5',
        pieces: 8,
        icon: '✨',
        sigil: '志',
        passive: { maxHp: 6, maxLifespan: 5 }
      }
    };
  }

  _getLegacyArtCardId(setId, pathId = this._resolveGameState()?.path || null) {
    if (!this._sets()[setId]) return null;
    if (this.deckAuthority && typeof this.deckAuthority.getLegacyVariantCardId === 'function') {
      return this.deckAuthority.getLegacyVariantCardId(setId, pathId);
    }
    // 仅为没有内容查询接口的旧调用方保留兼容回退。生产路径必须由牌组权威查询数据。
    return `legacy_${setId}_art`;
  }

  _canOfferSetForPath(setId, pathId) {
    const artCardId = this._getLegacyArtCardId(setId, pathId);
    if (!this.deckAuthority || typeof this.deckAuthority.validateCardForPath !== 'function') return true;
    return Boolean(this.deckAuthority.validateCardForPath(artCardId, pathId)?.allowed);
  }

  /**
   * 当前流派真正可以继续推进的套装。L2 扩充流派变体后，此处自动读取
   * SkillCardAcquisitionSystem 的同一张卡牌契约，不维护第二份流派表。
   */
  getEligibleSetIds({ path = this._resolveGameState()?.path || null } = {}) {
    const sets = this._sets();
    const archive = this._archive();
    if (!archive) return [];
    return Object.keys(sets).filter(setId => (
      !archive.completedSetIds.includes(setId)
      && this._fragmentCount(setId) < sets[setId].pieces
      && this._canOfferSetForPath(setId, path)
    ));
  }

  getFocusedSetId() {
    return this._runState()?.focusedSetId || null;
  }

  /**
   * 传承追踪是本世掉落定向的唯一写入口。只允许追踪当前流派确实能获得的未完成套装，
   * 以免 UI 将不可掉落项伪装成 60% 权重目标。
   */
  setFocusedSet(setId, { path = this._resolveGameState()?.path || null } = {}) {
    const runState = this._runState();
    if (!runState) return { changed: false, reason: 'missing_run_state', focusedSetId: null };
    if (setId === null || setId === undefined || setId === '') {
      const changed = runState.focusedSetId !== null;
      runState.focusedSetId = null;
      if (changed) this._persist();
      return { changed, reason: changed ? 'focus_cleared' : 'already_clear', focusedSetId: null };
    }
    if (!this.getEligibleSetIds({ path }).includes(setId)) {
      return { changed: false, reason: 'ineligible_set', focusedSetId: runState.focusedSetId || null };
    }
    const changed = runState.focusedSetId !== setId;
    runState.focusedSetId = setId;
    if (changed) this._persist();
    return { changed, reason: changed ? 'focus_set' : 'already_focused', focusedSetId: setId };
  }

  _selectWeightedSet(setIds, focusedSetId = null) {
    if (!Array.isArray(setIds) || setIds.length === 0) return null;
    const focused = setIds.includes(focusedSetId) ? focusedSetId : null;
    const focusedWeight = this.getPacingContract().focusedWeight;
    if (focused && (
      setIds.length === 1
      || Math.random() < focusedWeight
    )) return focused;
    const remaining = focused ? setIds.filter(setId => setId !== focused) : setIds;
    return remaining[Math.floor(Math.random() * remaining.length)] || null;
  }

  _hashEncounterValue(value) {
    let hash = 2166136261;
    for (const char of String(value || '')) {
      hash ^= char.charCodeAt(0);
      hash = Math.imul(hash, 16777619);
    }
    return hash >>> 0;
  }

  _selectBossCandidateSetIds(setIds, focusedSetId, encounterInstanceId) {
    const pool = Array.from(new Set(setIds)).sort();
    if (pool.length === 0) return [];
    const candidates = [];
    if (pool.includes(focusedSetId)) candidates.push(focusedSetId);
    const remaining = pool.filter(setId => setId !== focusedSetId)
      .sort((left, right) => (
        this._hashEncounterValue(`${encounterInstanceId}:${left}`)
        - this._hashEncounterValue(`${encounterInstanceId}:${right}`)
      ));
    const choiceCount = Math.min(
      pool.length,
      3 + Math.max(0, Math.floor(this._rebirthEffect('bossChoiceBonus')))
    );
    return [...candidates, ...remaining].slice(0, choiceCount);
  }

  /**
   * 普通成功选择后的掉落。连续七次合法未掉落后，第八次强制掉落；
   * 空合法池既不掉落也不累积怜悯。
   */
  tryDrop(realm, { path = this._resolveGameState()?.path || null } = {}) {
    const runState = this._runState();
    const eligibleSetIds = this.getEligibleSetIds({ path });
    if (!runState || eligibleSetIds.length === 0) return null;

    const pityMissLimit = this.getPacingContract().pityMissLimit;
    const isPityDrop = Number(runState.ordinaryMissStreak) >= pityMissLimit;
    if (!isPityDrop && Math.random() > this._dropRate(realm)) {
      runState.ordinaryMissStreak = Math.min(
        pityMissLimit,
        Math.max(0, Number(runState.ordinaryMissStreak) || 0) + 1
      );
      this._persist();
      return null;
    }

    const setId = this._selectWeightedSet(eligibleSetIds, runState.focusedSetId);
    const fragment = this._addFragment(setId, { persist: false });
    if (!fragment) return null;
    runState.ordinaryMissStreak = 0;
    this._persist();
    return fragment;
  }

  /**
   * 兼容既有公共 API。真实 Boss 流程应使用 beginBossReward/claimBossReward，
   * 以便玩家选择、记录 instance 并在刷新后恢复。
   */
  dropFromBoss(realm, { path = this._resolveGameState()?.path || null } = {}) {
    const runState = this._runState();
    const eligibleSetIds = this.getEligibleSetIds({ path });
    if (eligibleSetIds.length === 0) return null;
    return this._addFragment(this._selectWeightedSet(eligibleSetIds, runState?.focusedSetId));
  }

  _normalizeBossEncounter(context) {
    const raw = context && typeof context === 'object' ? context : {};
    const encounterKind = raw.encounterKind;
    const encounterInstanceId = typeof raw.encounterInstanceId === 'string'
      ? raw.encounterInstanceId.trim()
      : '';
    if (!['boss', 'realm_boss'].includes(encounterKind) || !encounterInstanceId) return null;
    const rewardPresentation = raw.rewardPresentation
      && raw.rewardPresentation.visualWorldId === 'cangmang_sect_pc98_v1'
      && raw.rewardPresentation.uiMaterialId === 'sect_field_ledger_v1'
      && raw.rewardPresentation.visualSurface === 'boss_fragment_choice'
      ? {
          visualWorldId: 'cangmang_sect_pc98_v1',
          uiMaterialId: 'sect_field_ledger_v1',
          visualSurface: 'boss_fragment_choice'
        }
      : null;
    return {
      encounterInstanceId,
      encounterKind,
      cardId: typeof raw.cardId === 'string' ? raw.cardId : null,
      realm: typeof raw.realm === 'string' ? raw.realm : (this._resolveGameState()?.realm || 'qi'),
      path: typeof raw.path === 'string' ? raw.path : (this._resolveGameState()?.path || null),
      ...(rewardPresentation ? { rewardPresentation } : {})
    };
  }

  _clone(value) {
    return value ? JSON.parse(JSON.stringify(value)) : null;
  }

  getPendingBossReward() {
    return this._clone(this._runState()?.pendingBossFragmentReward || null);
  }

  getBossRewardOptions() {
    const pending = this.getPendingBossReward();
    if (!pending) return [];
    const sets = this._sets();
    return (pending.candidateSetIds || []).map(setId => {
      const set = sets[setId];
      if (!set) return null;
      return {
        setId,
        name: set.name,
        icon: set.icon,
        sigil: set.sigil,
        count: this._fragmentCount(setId),
        total: set.pieces,
        focused: pending.focusedSetId === setId,
        effect: set.effect,
        variantCardId: this._getLegacyArtCardId(setId, pending.path)
      };
    }).filter(Boolean);
  }

  beginBossReward(context) {
    const encounter = this._normalizeBossEncounter(context);
    if (!encounter) return { created: false, reason: 'not_eligible_boss', pending: null };
    const runState = this._runState();
    if (!runState) return { created: false, reason: 'missing_run_state', pending: null };
    if (runState.claimedEncounterInstanceIds.includes(encounter.encounterInstanceId)) {
      return { created: false, reason: 'already_claimed', pending: null };
    }
    if (runState.pendingBossFragmentReward) {
      const pending = runState.pendingBossFragmentReward;
      return {
        created: false,
        reason: pending.encounterInstanceId === encounter.encounterInstanceId
          ? 'pending_exists'
          : 'pending_reward_exists',
        pending: this._clone(pending)
      };
    }

    const candidateSetIds = this._selectBossCandidateSetIds(
      this.getEligibleSetIds({ path: encounter.path }),
      runState.focusedSetId,
      encounter.encounterInstanceId
    );
    if (candidateSetIds.length === 0) return { created: false, reason: 'no_eligible_set', pending: null };

    const pending = {
      schemaVersion: 1,
      ...encounter,
      focusedSetId: candidateSetIds.includes(runState.focusedSetId) ? runState.focusedSetId : null,
      candidateSetIds,
      createdAtTurn: Math.max(0, Number(this._resolveGameState()?.turn) || 0)
    };
    runState.pendingBossFragmentReward = pending;
    this._persist();
    if (this.onLog) this.onLog(`⚔ Boss 战利：可从 ${candidateSetIds.length} 套传承中择取一片。`);
    return { created: true, reason: 'pending_created', pending: this._clone(pending) };
  }

  claimBossReward(setId) {
    let runState = this._runState();
    const pending = runState?.pendingBossFragmentReward;
    if (!pending) return { claimed: false, reason: 'no_pending_reward' };
    if (!pending.candidateSetIds?.includes(setId)) return { claimed: false, reason: 'invalid_candidate' };
    if (runState.claimedEncounterInstanceIds.includes(pending.encounterInstanceId)) {
      return { claimed: false, reason: 'already_claimed' };
    }

    const fragment = this._addFragment(setId, { persist: false });
    const completions = this.checkCompletions({ source: pending, persist: false });
    const archive = this._archive();
    const set = this._sets()[setId];
    const waitingForCompletion = Boolean(
      set
      && this._fragmentCount(setId) >= set.pieces
      && !archive?.completedSetIds.includes(setId)
    );
    if (waitingForCompletion) {
      this._persist();
      return { claimed: false, reason: 'completion_pending', fragment, completions };
    }

    // acquireLegacyCard() can persist a fresh causal snapshot. Re-read before
    // recording the claim so the instance marker cannot be written to a stale object.
    runState = this._runState();
    if (!runState.claimedEncounterInstanceIds.includes(pending.encounterInstanceId)) {
      runState.claimedEncounterInstanceIds.push(pending.encounterInstanceId);
    }
    runState.pendingBossFragmentReward = null;
    this._persist();
    if (this.onLog) this.onLog(`🎁 Boss 战利已领取：${this._sets()[setId]?.name || setId}。`);
    return {
      claimed: true,
      reason: 'claimed',
      fragment,
      completions,
      encounterInstanceId: pending.encounterInstanceId
    };
  }

  getPendingInheritanceChoice() {
    return this._clone(this._runState()?.pendingInheritanceChoice || null);
  }

  getInheritanceOptions() {
    const pending = this.getPendingInheritanceChoice();
    const archive = this._archive();
    if (!pending || !archive) return [];
    const sets = this._sets();
    return pending.candidateSetIds.map(setId => {
      const set = sets[setId];
      if (!set || !archive.completedSetIds.includes(setId)) return null;
      const variantCardId = this._getLegacyArtCardId(setId, pending.path);
      const validation = this.deckAuthority?.validateCardForPath?.(variantCardId, pending.path);
      if (!variantCardId || (validation && !validation.allowed)) return null;
      const card = this.deckAuthority?.getCardDefinition?.(variantCardId);
      return {
        setId,
        name: set.name,
        icon: set.icon,
        effect: set.effect,
        passive: set.passive,
        path: pending.path,
        variantCardId,
        cardName: card?.name || variantCardId,
        cardCost: Number.isFinite(Number(card?.cost)) ? Number(card.cost) : null,
        cardDescription: card?.description || card?.desc || ''
      };
    }).filter(Boolean);
  }

  beginInheritanceChoice({ path = this._resolveGameState()?.path || null } = {}) {
    const state = this._resolveGameState();
    const runState = this._runState();
    const archive = this._archive();
    const lifeCount = Math.max(0, Math.floor(Number(state?.getLifeCount?.() || 0)));
    if (!state || !runState || !archive) {
      return { created: false, reason: 'missing_state', pending: null };
    }
    if (lifeCount <= 0) return { created: false, reason: 'first_life', pending: null };
    if (!['sword', 'spell', 'body', 'pill'].includes(path) || state.path !== path) {
      return { created: false, reason: 'path_mismatch', pending: null };
    }
    if (runState.inheritedSetId) {
      return { created: false, reason: 'already_inherited', pending: null };
    }
    if (runState.pendingInheritanceChoice) {
      const pending = runState.pendingInheritanceChoice;
      return {
        created: false,
        reason: pending.path === path ? 'pending_exists' : 'pending_path_mismatch',
        pending: this._clone(pending)
      };
    }

    const candidateSetIds = archive.completedSetIds.filter(setId => (
      this._sets()[setId] && this._canOfferSetForPath(setId, path)
    ));
    if (candidateSetIds.length === 0) {
      return { created: false, reason: 'no_completed_set', pending: null };
    }

    const pending = {
      schemaVersion: 1,
      lifeCount,
      path,
      candidateSetIds,
      createdAtTurn: Math.max(0, Math.floor(Number(state.turn) || 0))
    };
    runState.pendingInheritanceChoice = pending;
    this._persist();
    if (this.onLog) {
      this.onLog(`【轮回传承】前世已有 ${candidateSetIds.length} 套传承可选，本世只能继承一套。`);
    }
    return { created: true, reason: 'pending_created', pending: this._clone(pending) };
  }

  claimInheritance(setId) {
    const state = this._resolveGameState();
    let runState = this._runState();
    const archive = this._archive();
    if (!state || !runState || !archive) return { claimed: false, reason: 'missing_state' };
    if (runState.inheritedSetId) {
      return {
        claimed: false,
        reason: 'already_inherited',
        inheritedSetId: runState.inheritedSetId
      };
    }
    const pending = runState.pendingInheritanceChoice;
    if (!pending) return { claimed: false, reason: 'no_pending_inheritance' };
    if (pending.lifeCount !== state.getLifeCount?.() || pending.path !== state.path) {
      return { claimed: false, reason: 'stale_inheritance_choice' };
    }
    if (!pending.candidateSetIds.includes(setId) || !archive.completedSetIds.includes(setId)) {
      return { claimed: false, reason: 'invalid_candidate' };
    }

    const cardId = this._getLegacyArtCardId(setId, pending.path);
    if (!cardId || !this.deckAuthority) {
      return { claimed: false, reason: 'missing_deck_authority', cardId };
    }
    const sourceId = `legacy-inheritance:${pending.lifeCount}:${setId}`;
    const artResult = this.deckAuthority.acquireLegacyCard(cardId, {
      sourceType: 'legacy_reincarnation',
      sourceCardId: sourceId,
      sourceId,
      mode: 'legacy_inheritance'
    });
    if (!artResult?.acquired && artResult?.reason !== 'already_acquired') {
      this._persist();
      return {
        claimed: false,
        reason: artResult?.reason || 'inheritance_card_failed',
        cardId
      };
    }

    // 发卡会先持久化牌组；重新取得同一世 run state，再提交继承标记。
    runState = this._runState();
    if (runState.inheritedSetId && runState.inheritedSetId !== setId) {
      return {
        claimed: false,
        reason: 'already_inherited',
        inheritedSetId: runState.inheritedSetId
      };
    }
    runState.inheritedSetId = setId;
    if (!runState.activeSetIds.includes(setId)) runState.activeSetIds.push(setId);
    runState.pendingInheritanceChoice = null;
    if (!archive.discoveredVariantCardIds.includes(cardId)) {
      archive.discoveredVariantCardIds.push(cardId);
    }
    this._persist();

    const card = this.deckAuthority.getCardDefinition?.(cardId);
    const result = {
      claimed: true,
      reason: artResult?.acquired ? 'inherited' : 'inheritance_recovered',
      setId,
      setName: this._sets()[setId]?.name || setId,
      path: pending.path,
      cardId,
      cardName: artResult?.record?.cardName || card?.name || cardId,
      sourceId
    };
    if (this.onLog) {
      this.onLog(
        `【轮回传承】本世继承「${result.setName}」，获得${state.getPathName?.(pending.path) || pending.path}`
        + `绝学【${result.cardName}】；本世被动已激活。`
      );
    }
    return result;
  }

  /**
   * 境界 → 掉落概率
   */
  _dropRate(realm) {
    // 七次未掉必出的怜悯与每 20 次选择的 Boss 定向片已经提供主要进度。
    // 境界只做温和加速，避免高境界在 20/50 次选择时提前灌满聚焦套装。
    const base = LEGACY_PACING_CONTRACT.ordinaryDropRates[realm]
      || LEGACY_PACING_CONTRACT.ordinaryDropRates.qi;
    return Math.min(0.12, base + Math.max(0, this._rebirthEffect('ordinaryDropBonus')));
  }

  _getIncompleteSets(options = {}) {
    return this.getEligibleSetIds(options);
  }

  /**
   * 向指定套装添加一片碎片
   * @param {string} setId
   * @returns {Object|null} { setId, name, icon, count, total }
   */
  _addFragment(setId, { persist = true } = {}) {
    const set = this._sets()[setId];
    if (!set || this._fragmentCount(setId) >= set.pieces) return null;
    const count = this._fragmentCount(setId) + 1;
    const pieceIndex = count - 1;
    this._setFragmentCount(setId, count);
    if (persist) this._persist();
    const msg = `${set.icon} 获得传承残卷：「${set.name}」(${count}/${set.pieces})`;
    if (this.onLog) this.onLog(msg);

    return { setId, name: set.name, icon: set.icon, count, total: set.pieces, pieceIndex };
  }

  /**
   * 检查所有套装的完成状态，合成已完成套装
   * @returns {Array} 新合成的套装列表 [{ name, effect, passive }]
   */
  _acquireLegacyArt(setId, source = null) {
    const pathId = this._resolveGameState()?.path || source?.path || null;
    const artCardId = this._getLegacyArtCardId(setId, pathId);
    if (!artCardId) return { acquired: false, reason: 'missing_path_variant', cardId: null };
    if (!this.deckAuthority) {
      return { acquired: false, reason: 'deck_authority_unavailable', cardId: artCardId };
    }
    return this.deckAuthority.acquireLegacyCard(artCardId, {
      sourceType: 'legacy_fragment_set',
      sourceCardId: source?.encounterInstanceId || setId,
      legacySetId: setId,
      legacyPath: pathId
    });
  }

  checkCompletions({ source = null, persist = true } = {}) {
    const newCompletions = [];
    const sets = this._sets();
    let archive = this._archive();
    let runState = this._runState();
    if (!archive || !runState) return newCompletions;

    for (const [setId, set] of Object.entries(sets)) {
      if (archive.completedSetIds.includes(setId)) continue;
      if (this._fragmentCount(setId) >= set.pieces) {
        const artResult = this._acquireLegacyArt(setId, source);
        if (!artResult?.acquired && artResult?.reason !== 'already_acquired') {
          if (this.onLog) this.onLog(`Legacy art grant failed: ${artResult?.reason || 'unknown'}. Fragments retained for retry.`);
          continue;
        }
        // Card acquisition persists the causal snapshot. Re-read the authoritative
        // objects so this completion does not write to a pre-persistence reference.
        archive = this._archive();
        runState = this._runState();
        archive.completedSetIds.push(setId);
        this._setFragmentCount(setId, set.pieces);
        if (!runState.activeSetIds.includes(setId)) runState.activeSetIds.push(setId);
        const artCardId = artResult.cardId || this._getLegacyArtCardId(setId);
        if (!archive.discoveredVariantCardIds.includes(artCardId)) {
          archive.discoveredVariantCardIds.push(artCardId);
        }
        const state = this._resolveGameState();
        const artCard = this.deckAuthority?.getCardDefinition?.(artCardId);
        const completion = {
          setId,
          name: set.name,
          effect: set.effect,
          passive: set.passive,
          cardId: artCardId,
          cardName: artResult.record?.cardName || artCard?.name || artCardId,
          path: artResult.record?.path || state?.path || source?.path || null,
          sourceId: artResult.record?.sourceId || source?.encounterInstanceId || setId
        };
        newCompletions.push(completion);
        if (this.onLog) {
          this.onLog(
            `🎉 传承合成：「${set.name}」！获得绝学【${completion.cardName}】；`
            + `${set.effect}（本世被动已激活）`
          );
        }

        // 激活奖励只在完成事务内结算一次；常驻被动由 getPassiveBonuses() 消费。
        if (state) {
          if (set.passive.maxLifespan) {
            state.addResource('lifespan', null, set.passive.maxLifespan);
          }
          if (set.activation?.fortune) {
            state.addAttribute('fortune', set.activation.fortune);
          }
          if (set.passive.daoHeartPenalty) {
            state.setAttribute('daoHeart', state.getAttribute('daoHeart'));
          }
          if (set.passive.maxHp) {
            state.setAttribute('health', state.getAttribute('health') + set.passive.maxHp);
          }
        }
      }
    }
    if (persist && newCompletions.length > 0) this._persist();
    return newCompletions;
  }

  /**
   * 获取所有已合成传承的聚合被动加成
   * @returns {Object} { atk, def, critRate, hpRegen, pillBonus, daoResist, fortuneBonus, maxHp, maxLifespan, cultivationBonus, daoHeartPenalty }
   */
  getPassiveBonuses() {
    const bonuses = {};
    const sets = this._sets();
    const archive = this._archive();
    const activeSetIds = this._runState()?.activeSetIds || [];
    for (const setId of activeSetIds) {
      if (!archive?.completedSetIds.includes(setId)) continue;
      const set = sets[setId];
      if (!set || !set.passive) continue;
      for (const [key, val] of Object.entries(set.passive)) {
        bonuses[key] = (bonuses[key] || 0) + val;
      }
    }
    return bonuses;
  }

  /**
   * 获取碎片收集进度（供 UI 显示）
   */
  getCollectionDefinitions() {
    // Definition-only view; never initializes a player archive.
    return this._sets();
  }

  getProgress() {
    const progress = {};
    const sets = this._sets();
    const archive = this._archive();
    for (const setId of Object.keys(sets)) {
      const count = this._fragmentCount(setId);
      progress[setId] = {
        name: sets[setId].name,
        icon: sets[setId].icon,
        count,
        total: sets[setId].pieces,
        effect: sets[setId].effect,
        completed: Boolean(archive?.completedSetIds.includes(setId)),
        active: Boolean(this._runState()?.activeSetIds.includes(setId)),
        variantCardId: this._getLegacyArtCardId(setId)
      };
    }
    return progress;
  }
}

// 全局单例
const legacyFragmentSystem = new LegacyFragmentSystem();

if (typeof module !== 'undefined' && module.exports) {
  module.exports = LegacyFragmentSystem;
} else {
  window.LegacyFragmentSystem = LegacyFragmentSystem;
  window.legacyFragmentSystem = legacyFragmentSystem;
}
