/**
 * SkillCardAcquisitionSystem
 *
 * 本世技能牌取得的唯一写入口：
 * - 计算数据驱动的机遇概率；
 * - 记录一次性尝试与取得来源；
 * - 对 gameState.deck 与运行时 masterDeck 做幂等同步。
 */
class SkillCardAcquisitionSystem {
  constructor({
    gameState,
    contract = null,
    deckContract = null,
    cardCatalog = null,
    deckCombatSystem = null,
    eventBus = null,
    debug = true
  } = {}) {
    this.gameState = gameState;
    this.contract = contract || { realmOrder: [], offers: {} };
    this.deckContract = deckContract || { paths: {}, economy: {}, upgradeRules: {} };
    const cards = Array.isArray(cardCatalog?.battle_cards) ? cardCatalog.battle_cards : [];
    this.cardDB = Object.fromEntries(cards.map(card => [card.id, card]));
    this.deckCombatSystem = deckCombatSystem;
    this.eventBus = eventBus;
    this.debug = debug;
  }

  _dbg(...args) {
    if (this.debug) console.log('[SkillCardAcquisitionSystem]', ...args);
  }

  _ensureState(state = this.gameState) {
    if (!state.deck) state.deck = [];
    if (!state.deckOperations) state.deckOperations = [];
    if (!state.skillAcquisitions) state.skillAcquisitions = {};
    if (!state.skillOpportunityAttempts) state.skillOpportunityAttempts = {};
    if (!state.resources) state.resources = {};
    if (!Number.isFinite(Number(state.resources.spiritStone))) state.resources.spiritStone = 0;
    return state;
  }

  _getOffer(offerId) {
    return this.contract?.offers?.[offerId] || null;
  }

  _realmIndex(realm) {
    const realmOrder = this.deckContract?.realmOrder?.length
      ? this.deckContract.realmOrder
      : (this.contract?.realmOrder || []);
    return realmOrder.indexOf(realm);
  }

  _getPathContract(pathId) {
    return this.deckContract?.paths?.[pathId] || null;
  }

  _getRealmPool(pathContract, poolName, realm, { cumulative = false } = {}) {
    const poolsByRealm = pathContract?.[`${poolName}ByRealm`];
    if (!poolsByRealm || typeof poolsByRealm !== 'object') {
      return Array.isArray(pathContract?.[poolName]) ? pathContract[poolName].slice() : [];
    }
    const realmOrder = this.deckContract?.realmOrder || [];
    const realmIndex = realmOrder.indexOf(realm);
    if (realmIndex < 0) return [];
    const realms = cumulative ? realmOrder.slice(0, realmIndex + 1) : [realm];
    return [...new Set(realms.flatMap(realmId => poolsByRealm[realmId] || []))];
  }

  _sameDeck(left, right) {
    return Array.isArray(left)
      && Array.isArray(right)
      && left.length === right.length
      && left.every((cardId, index) => cardId === right[index]);
  }

  _canonicalCardId(cardId) {
    return typeof cardId === 'string' ? cardId.replace(/\++$/, '') : cardId;
  }

  _isCardOwned(cardId, stateOverride = null) {
    const state = stateOverride || this.gameState || {};
    const canonicalId = this._canonicalCardId(cardId);
    const deckOwns = (Array.isArray(state.deck) ? state.deck : [])
      .some(ownedId => this._canonicalCardId(ownedId) === canonicalId);
    const acquisitionOwns = Object.keys(state.skillAcquisitions || {})
      .some(ownedId => this._canonicalCardId(ownedId) === canonicalId);
    return deckOwns || acquisitionOwns;
  }

  _recordDeckOperation(operation, details = {}) {
    const state = this._ensureState();
    const entry = {
      operation,
      sourceType: details.sourceType || operation,
      sourceId: details.sourceId || null,
      path: details.path || state.path || null,
      realm: state.realm || null,
      turn: Number(state.turn) || 0,
      ...details
    };
    state.deckOperations.push(entry);
    if (state.deckOperations.length > 100) {
      state.deckOperations = state.deckOperations.slice(-100);
    }
    return entry;
  }

  _persistDeck() {
    const state = this.gameState;
    if (state && typeof state.persistCausalSession === 'function') {
      state.persistCausalSession();
      return true;
    }
    if (state && typeof state.persistUnlocks === 'function') {
      state.persistUnlocks();
      return true;
    }
    if (state && typeof state._saveUnlocks === 'function') {
      state._saveUnlocks();
      return true;
    }
    return false;
  }

  _syncRuntimeDeckFull() {
    const state = this._ensureState();
    const runtime = this.deckCombatSystem;
    if (!runtime) return;
    runtime.masterDeck = state.deck.slice();
  }

  grantStarterDeck(pathId, options = {}) {
    const state = this._ensureState();
    const pathContract = this._getPathContract(pathId);
    if (!pathContract || !Array.isArray(pathContract.starterDeck) || pathContract.starterDeck.length !== 6) {
      return { acquired: false, reason: 'unknown_path', path: pathId };
    }
    if (state.path && state.path !== pathId) {
      return { acquired: false, reason: 'path_mismatch', path: pathId, currentPath: state.path };
    }
    if (state.deck.length > 0) {
      return { acquired: false, reason: 'deck_already_initialized', path: pathId };
    }

    state.deck = pathContract.starterDeck.slice();
    state.starterDeckPath = pathId;
    const record = this._recordDeckOperation('starter_grant', {
      sourceType: options.sourceType || 'starter_path',
      sourceId: options.sourceId || `path_select:${pathId}`,
      path: pathId,
      cardIds: state.deck.slice()
    });
    this._syncRuntimeDeckFull();
    this._persistDeck();
    this._emit('deck:starterGranted', record);
    return { acquired: true, reason: 'starter_granted', path: pathId, cardIds: state.deck.slice(), record };
  }

  ensureStarterDeck(pathId, options = {}) {
    const state = this._ensureState();
    if (state.path && state.path !== pathId) {
      return {
        acquired: false,
        migrated: false,
        reason: 'path_mismatch',
        path: pathId,
        currentPath: state.path,
        cardIds: state.deck.slice()
      };
    }
    if (state.deck.length === 0) {
      return this.grantStarterDeck(pathId, options);
    }

    const legacyDeck = this.deckContract?.legacyGenericStarter || [];
    const pathContract = this._getPathContract(pathId);
    if (pathContract && this._sameDeck(state.deck, legacyDeck)) {
      const previousCardIds = state.deck.slice();
      state.deck = pathContract.starterDeck.slice();
      state.starterDeckPath = pathId;
      const record = this._recordDeckOperation('starter_migration', {
        sourceType: options.sourceType || 'legacy_starter_migration',
        sourceId: options.sourceId || 'legacy_generic_six',
        path: pathId,
        previousCardIds,
        cardIds: state.deck.slice()
      });
      this._syncRuntimeDeckFull();
      this._persistDeck();
      this._emit('deck:starterMigrated', record);
      return {
        acquired: true,
        migrated: true,
        reason: 'legacy_starter_migrated',
        path: pathId,
        cardIds: state.deck.slice(),
        record
      };
    }

    return {
      acquired: false,
      migrated: false,
      reason: 'deck_already_initialized',
      path: pathId,
      cardIds: state.deck.slice()
    };
  }

  getCardDefinition(cardId) {
    if (!cardId || typeof cardId !== 'string') return null;
    if (this.cardDB[cardId]) return this.cardDB[cardId];
    if (cardId.endsWith('+')) {
      const baseCard = this.cardDB[cardId.slice(0, -1)];
      return baseCard ? this.buildUpgradedCard(baseCard, cardId) : null;
    }
    const runtimeCard = this.deckCombatSystem?.cardDB?.[cardId];
    return runtimeCard || null;
  }

  /**
   * 传承绝学的组合由 battle_cards.json 声明；这里是唯一的内容查询入口。
   * LegacyFragmentSystem 只请求“某套传承在当前流派的卡”，不复制 24 卡 ID 映射。
   */
  getLegacyVariantCardId(setId, pathId) {
    if (typeof setId !== 'string' || typeof pathId !== 'string') return null;
    const card = Object.values(this.cardDB).find(candidate => (
      candidate?.legacySetId === setId
      && candidate?.legacyPath === pathId
      && (candidate.tags || []).includes('legacy')
      && (candidate.tags || []).includes(pathId)
    ));
    return card?.id || null;
  }

  validateCardForPath(cardId, pathId = null, stateOverride = null) {
    const state = stateOverride || this.gameState || {};
    const resolvedPath = pathId || state.path || null;
    const card = this.getCardDefinition(cardId);
    if (!card) {
      return { allowed: false, reason: 'unknown_card', cardId, path: resolvedPath };
    }
    const allowedPaths = ['sword', 'spell', 'body', 'pill']
      .filter(candidate => (card.tags || []).includes(candidate));
    if (allowedPaths.length === 0) {
      return { allowed: false, reason: 'missing_path_tag', cardId, path: resolvedPath, allowedPaths };
    }
    if (!resolvedPath || !allowedPaths.includes(resolvedPath)) {
      return { allowed: false, reason: 'path_mismatch', cardId, path: resolvedPath, allowedPaths };
    }
    return { allowed: true, reason: 'allowed', cardId, path: resolvedPath, allowedPaths, card };
  }

  getRewardOffers({ path = null, realm = null, channel = 'battle', count = 3 } = {}) {
    const state = this._ensureState();
    if (path && state.path && path !== state.path) return [];
    if (realm && state.realm && realm !== state.realm) return [];
    const resolvedPath = path || state.path;
    const resolvedRealm = realm || state.realm || 'qi';
    const pathContract = this._getPathContract(resolvedPath);
    if (!pathContract) return [];
    const sourceTypes = {
      battle: 'battle_reward',
      breakthrough: 'breakthrough_reward'
    };
    const sourceType = sourceTypes[channel] || `${channel}_reward`;
    return this._getRealmPool(pathContract, 'rewardPool', resolvedRealm, { cumulative: true })
      .filter(cardId => (
        !this._isCardOwned(cardId, state)
        && this.validateCardForPath(cardId, resolvedPath).allowed
      ))
      .slice(0, Math.max(0, Number(count) || 0))
      .map(cardId => {
        const card = this.getCardDefinition(cardId);
        return {
          cardId,
          cardName: card?.name || cardId,
          description: card?.description || card?.desc || '',
          path: resolvedPath,
          realm: resolvedRealm,
          sourceType
        };
      });
  }

  getShopOffer({ path = null, realm = null } = {}) {
    const state = this._ensureState();
    if (path && state.path && path !== state.path) return null;
    if (realm && state.realm && realm !== state.realm) return null;
    const resolvedPath = path || state.path;
    const resolvedRealm = realm || state.realm || 'qi';
    const pathContract = this._getPathContract(resolvedPath);
    if (!pathContract) return null;
    const cardId = this._getRealmPool(pathContract, 'shopPool', resolvedRealm)
      .find(candidateId => (
        !this._isCardOwned(candidateId, state)
        && this.validateCardForPath(candidateId, resolvedPath).allowed
      ));
    if (!cardId) return null;

    const card = this.getCardDefinition(cardId);
    const economy = this.deckContract?.economy || {};
    const realmIndex = Math.max(0, this._realmIndex(resolvedRealm));
    const price = Math.max(
      1,
      (Number(economy.shopBasePrice) || 0)
        + (Number(card.cost) || 0) * (Number(economy.shopCostMultiplier) || 0)
        + realmIndex * (Number(economy.shopRealmStep) || 0)
    );
    return {
      id: `card_${resolvedPath}_${cardId}`,
      name: `本脉功法：${card.name || cardId}`,
      type: 'card',
      desc: card.description || card.desc || '',
      price,
      realm: resolvedRealm,
      cardId,
      path: resolvedPath,
      sourceType: 'shop_path_slot',
      effect: {
        deckCard: {
          cardId,
          path: resolvedPath,
          sourceType: 'shop_path_slot',
          sourceId: `shop:${resolvedRealm}:${resolvedPath}`
        }
      }
    };
  }

  acquirePathCard(cardId, options = {}) {
    const state = this._ensureState();
    if (options.path && state.path && options.path !== state.path) {
      return {
        acquired: false,
        reason: 'path_mismatch',
        cardId,
        path: options.path,
        currentPath: state.path
      };
    }
    const resolvedPath = state.path || options.path;
    const pathContract = this._getPathContract(resolvedPath);
    if (!cardId || !pathContract) {
      return { acquired: false, reason: 'invalid_card', cardId, path: resolvedPath };
    }
    const validation = this.validateCardForPath(cardId, resolvedPath);
    if (!validation.allowed) return { acquired: false, ...validation };
    const resolvedRealm = state.realm || 'qi';
    const sourceType = options.sourceType || 'path_reward';
    const isShopChannel = sourceType === 'shop_path_slot';
    const allowedCards = new Set(this._getRealmPool(
      pathContract,
      isShopChannel ? 'shopPool' : 'rewardPool',
      resolvedRealm,
      { cumulative: !isShopChannel }
    ));
    if (!allowedCards.has(cardId)) {
      const allPathCards = new Set([
        ...(pathContract.rewardPool || []),
        ...(pathContract.shopPool || [])
      ]);
      if (!allPathCards.has(cardId)) {
        return { acquired: false, reason: 'path_mismatch', cardId, path: resolvedPath };
      }
      const cardRealm = (this.deckContract?.realmOrder || [])
        .find(realmId => (validation.card?.tags || []).includes(realmId));
      const reason = this._realmIndex(cardRealm) > this._realmIndex(resolvedRealm)
        ? 'realm_locked'
        : 'channel_mismatch';
      return {
        acquired: false,
        reason,
        cardId,
        path: resolvedPath,
        realm: resolvedRealm,
        cardRealm: cardRealm || null,
        sourceType
      };
    }
    if (this._isCardOwned(cardId, state)) {
      return { acquired: false, reason: 'already_acquired', cardId, path: resolvedPath };
    }
    const card = this.getCardDefinition(cardId);
    return this._acquire({
      cardId,
      cardName: card?.name || cardId,
      sourceType: options.sourceType || 'path_reward',
      sourceCardId: options.sourceId || options.sourceCardId || null,
      locationId: options.locationId || null
    }, {
      ...options,
      path: resolvedPath,
      mode: options.mode || 'path_reward'
    });
  }

  buildUpgradedCard(baseCard, upgradedId = null) {
    if (!baseCard) return null;
    const upgraded = JSON.parse(JSON.stringify(baseCard));
    upgraded.id = upgradedId || `${baseCard.id}+`;
    upgraded.name = `${baseCard.name}+`;
    upgraded.cost = Number(baseCard.cost) || 0;
    const priority = this.deckContract?.upgradeRules?.effectPriority || [];
    const deltas = this.deckContract?.upgradeRules?.effectDelta || {};
    const targetType = priority.find(type => upgraded.effects?.some(effect => effect.type === type));
    if (targetType) {
      const targetEffect = upgraded.effects.find(effect => effect.type === targetType);
      const beforeValue = Number(targetEffect.value) || 0;
      const afterValue = beforeValue + (Number(deltas[targetType]) || 0);
      targetEffect.value = afterValue;
      const effectLabels = {
        damage: '伤害',
        block: '护盾',
        heal: '恢复',
        status: {
          sword_intent: '剑意',
          spell_seal: '法印',
          fortify: '金刚罡劲',
          weak: '虚弱',
          vulnerable: '易伤',
          poison: '丹毒'
        }[targetEffect.statusId] || '状态层数',
        gain_qi: '真元'
      };
      const label = effectLabels[targetType] || targetType;
      upgraded.description = `${baseCard.description || baseCard.desc || ''}`
        + `\n【强化后主效果：${label} ${afterValue}（原 ${beforeValue}）】`;
    } else {
      upgraded.description = `${baseCard.description || baseCard.desc || ''}\n【强化后：效果不变】`;
    }
    return upgraded;
  }

  getUpgradePreview(index) {
    const state = this._ensureState();
    const cardId = state.deck[index];
    const cost = Number(this.deckContract?.economy?.upgradeCost) || 0;
    if (!cardId) return { allowed: false, reason: 'invalid_index', index, cost };
    if (typeof cardId === 'string' && cardId.endsWith('+')) {
      return { allowed: false, reason: 'already_upgraded', index, cardId, cost };
    }
    const before = this.getCardDefinition(cardId);
    if (!before) return { allowed: false, reason: 'unknown_card', index, cardId, cost };
    if (state.resources.spiritStone < cost) {
      return { allowed: false, reason: 'insufficient_spirit_stone', index, cardId, cost, before };
    }
    const after = this.buildUpgradedCard(before, `${cardId}+`);
    return { allowed: true, reason: 'allowed', index, cardId, cost, before, after };
  }

  upgradeCardAt(index) {
    const state = this._ensureState();
    const preview = this.getUpgradePreview(index);
    if (!preview.allowed) return { success: false, ...preview };

    state.resources.spiritStone -= preview.cost;
    state.deck[index] = preview.after.id;
    const record = this._recordDeckOperation('upgrade', {
      sourceType: 'deck_upgrade',
      sourceId: preview.cardId,
      index,
      fromCardId: preview.cardId,
      toCardId: preview.after.id,
      cost: preview.cost
    });
    this._syncRuntimeDeckFull();
    this._persistDeck();
    this._emit('deck:upgraded', record);
    return { success: true, reason: 'upgraded', preview, record };
  }

  getRemovalPreview(index) {
    const state = this._ensureState();
    const cardId = state.deck[index];
    const cost = Number(this.deckContract?.economy?.removeCost) || 0;
    const minimumDeckSize = Number(this.deckContract?.economy?.minimumDeckSize) || 1;
    if (!cardId) return { allowed: false, reason: 'invalid_index', index, cost, minimumDeckSize };
    if (state.deck.length <= minimumDeckSize) {
      return { allowed: false, reason: 'minimum_deck_size', index, cardId, cost, minimumDeckSize };
    }
    if (state.resources.spiritStone < cost) {
      return { allowed: false, reason: 'insufficient_spirit_stone', index, cardId, cost, minimumDeckSize };
    }
    return {
      allowed: true,
      reason: 'allowed',
      index,
      cardId,
      card: this.getCardDefinition(cardId),
      cost,
      minimumDeckSize
    };
  }

  removeCardAt(index) {
    const state = this._ensureState();
    const preview = this.getRemovalPreview(index);
    if (!preview.allowed) return { success: false, ...preview };

    state.resources.spiritStone -= preview.cost;
    state.deck.splice(index, 1);
    const record = this._recordDeckOperation('remove', {
      sourceType: 'deck_remove',
      sourceId: preview.cardId,
      index,
      cardId: preview.cardId,
      cost: preview.cost
    });
    this._syncRuntimeDeckFull();
    this._persistDeck();
    this._emit('deck:removed', record);
    return { success: true, reason: 'removed', preview, record };
  }

  evaluateChance(offerId, stateOverride = null) {
    const state = stateOverride || this.gameState;
    const offer = this._getOffer(offerId);
    if (!offer) return { eligible: false, reason: 'unknown_offer', chance: 0 };
    const pathValidation = this.validateCardForPath(offer.cardId, state?.path, state);
    if (!pathValidation.allowed) {
      return {
        eligible: false,
        reason: pathValidation.reason,
        chance: 0,
        cardId: offer.cardId,
        path: state?.path || null,
        allowedPaths: pathValidation.allowedPaths || []
      };
    }

    const realmIndex = this._realmIndex(state?.realm);
    const minimumIndex = this._realmIndex(offer.minRealm);
    if (realmIndex < 0 || minimumIndex < 0 || realmIndex < minimumIndex) {
      return {
        eligible: false,
        reason: 'realm_locked',
        chance: 0,
        realm: state?.realm,
        minRealm: offer.minRealm
      };
    }

    const formula = offer.formula || {};
    const getAttribute = key => {
      if (state && typeof state.getAttribute === 'function') return Number(state.getAttribute(key)) || 0;
      return Number(state?.attributes?.[key]) || 0;
    };
    const fortune = getAttribute('fortune');
    const daoHeart = getAttribute('daoHeart');
    const cultivation = getAttribute('cultivation');
    const karmaBad = getAttribute('karmaBad');
    const karmaGood = getAttribute('karmaGood');
    const pathBonus = Number(formula.pathBonuses?.[state?.path]) || 0;

    const rawChance =
      (Number(formula.baseChance) || 0) +
      (realmIndex - minimumIndex) * (Number(formula.realmStep) || 0) +
      (fortune - (Number(formula.fortuneCenter) || 0)) * (Number(formula.fortuneScale) || 0) +
      (daoHeart - (Number(formula.daoHeartCenter) || 0)) * (Number(formula.daoHeartScale) || 0) +
      cultivation * (Number(formula.cultivationScale) || 0) +
      karmaBad * (Number(formula.karmaBadScale) || 0) +
      karmaGood * (Number(formula.karmaGoodScale) || 0) +
      pathBonus;
    const minChance = Number.isFinite(Number(formula.minChance)) ? Number(formula.minChance) : 0;
    const maxChance = Number.isFinite(Number(formula.maxChance)) ? Number(formula.maxChance) : 100;
    const chance = Math.max(minChance, Math.min(maxChance, Math.round(rawChance)));

    return {
      eligible: true,
      reason: 'eligible',
      chance,
      rawChance,
      realmIndex,
      minimumIndex,
      inputs: {
        realm: state.realm,
        path: state.path || null,
        fortune,
        daoHeart,
        cultivation,
        karmaBad,
        karmaGood,
        pathBonus
      }
    };
  }

  /** Pure eligibility and pre-choice probability; never initializes save fields. */
  previewOpportunity(offerId, options = {}) {
    const state = this.gameState || {};
    const offer = this._getOffer(offerId);
    const identity = {
      offerId: offerId || null,
      cardId: offer?.cardId || null,
      cardName: offer?.cardName || this.getCardDefinition(offer?.cardId)?.name || null,
      oncePerLife: Boolean(offer?.oncePerLife),
      chance: null,
      evaluation: null
    };
    if (!offer) return { ...identity, eligible: false, reason: 'unknown_offer' };
    if (this._isCardOwned(offer.cardId, state)) {
      return { ...identity, eligible: false, reason: 'already_acquired' };
    }
    if (offer.oncePerLife && state.skillOpportunityAttempts?.[offerId]) {
      return { ...identity, eligible: false, reason: 'already_attempted' };
    }
    if (options.sourceCardId && offer.sourceCardId && options.sourceCardId !== offer.sourceCardId) {
      return { ...identity, eligible: false, reason: 'source_mismatch' };
    }

    const evaluation = this.evaluateChance(offerId);
    if (!evaluation.eligible) {
      return { ...identity, eligible: false, reason: evaluation.reason, evaluation };
    }
    // A successful roll must be able to deliver its promised card/provenance.
    const acquisition = this._previewAcquisition(offer, options);
    return { ...identity, ...acquisition, evaluation,
      chance: acquisition.eligible ? evaluation.chance : null };
  }

  resolveOpportunity(offerId, options = {}) {
    const preview = this.previewOpportunity(offerId, options);
    if (!preview.eligible) return { ...preview, acquired: false };
    const state = this._ensureState();
    const offer = this._getOffer(offerId);
    const evaluation = preview.evaluation;
    const random = typeof options.random === 'function' ? options.random : Math.random;
    const roll = Math.max(0, Math.min(0.999999, Number(random()) || 0));
    const rollPercent = Math.floor(roll * 100) + 1;
    const attempt = {
      offerId,
      sourceId: options.sourceCardId || offer.sourceCardId,
      sourceType: offer.sourceType,
      locationId: offer.locationId,
      realm: state.realm,
      turn: Number(state.turn) || 0,
      chance: evaluation.chance,
      roll: rollPercent,
      outcome: rollPercent <= evaluation.chance ? 'acquired' : 'failed'
    };
    state.skillOpportunityAttempts[offerId] = attempt;

    if (attempt.outcome !== 'acquired') {
      this._persistDeck();
      this._emit('skillcard:opportunityResolved', { ...attempt, acquired: false });
      return {
        acquired: false,
        reason: 'roll_failed',
        offerId,
        cardId: offer.cardId,
        chance: evaluation.chance,
        roll: rollPercent,
        evaluation
      };
    }

    return this._acquire(offer, {
      ...options,
      offerId,
      mode: 'random',
      chance: evaluation.chance,
      roll: rollPercent
    });
  }

  /** Read the full guarantee contract without initializing or writing state. */
  previewGuaranteed(offerId, options = {}) {
    const offer = this._getOffer(offerId);
    if (!offer) {
      return { eligible: false, reason: 'unknown_offer', offerId: offerId || null,
        cardId: null, cardName: null, sourceType: null, sourceId: null };
    }
    const acquisition = { ...this._previewAcquisition(offer, options), offerId };
    // Keep guaranteed acquisition's existing rejection order. A prior random
    // attempt is intentionally not a gate for an earned victory reward.
    if (this._isCardOwned(offer.cardId)) {
      return { ...acquisition, eligible: false, reason: 'already_acquired' };
    }
    if (options.sourceCardId && offer.sourceCardId && options.sourceCardId !== offer.sourceCardId) {
      return { ...acquisition, eligible: false, reason: 'source_mismatch' };
    }
    const evaluation = this.evaluateChance(offerId);
    if (!evaluation.eligible) {
      return { ...acquisition, eligible: false, reason: evaluation.reason, evaluation };
    }
    return acquisition;
  }

  acquireGuaranteed(offerId, options = {}) {
    const preview = this.previewGuaranteed(offerId, options);
    if (!preview.eligible) return { ...preview, acquired: false };
    const offer = this._getOffer(offerId);
    return this._acquire(offer, { ...options, offerId, mode: 'guaranteed', chance: 100, roll: 0 });
  }

  acquireLegacyCard(cardId, options = {}) {
    const state = this._ensureState();
    if (!cardId) return { acquired: false, reason: 'invalid_card', cardId };
    const validation = this.validateCardForPath(cardId, state.path);
    if (!validation.allowed) return { acquired: false, ...validation };
    const card = validation.card;
    if (this._isCardOwned(cardId, state)) {
      return { acquired: false, reason: 'already_acquired', cardId };
    }
    return this._acquire({
      cardId,
      cardName: options.cardName || card.name || cardId,
      sourceType: options.sourceType || 'legacy_deck_effect',
      sourceCardId: options.sourceCardId || null,
      locationId: options.locationId || null
    }, { ...options, mode: options.mode || 'legacy' });
  }

  _previewAcquisition(offer, options = {}) {
    const state = this.gameState || {};
    const sourceType = options.sourceType || offer.sourceType || null;
    const sourceId = options.sourceId || options.sourceCardId || offer.sourceCardId || null;
    const validation = this.validateCardForPath(offer.cardId, state.path);
    const identity = { cardId: offer.cardId, cardName: offer.cardName || validation.card?.name || offer.cardId,
      sourceType, sourceId };
    if (!validation.allowed) {
      return { ...identity, ...validation, eligible: false };
    }
    if (this._isCardOwned(offer.cardId, state)) {
      return { ...identity, eligible: false, reason: 'already_acquired' };
    }
    if (!sourceType || sourceType === 'unknown' || !sourceId) {
      return { ...identity, eligible: false, reason: 'missing_provenance' };
    }
    return { ...identity, eligible: true, reason: 'eligible' };
  }

  _acquire(offer, options = {}) {
    const preview = this._previewAcquisition(offer, options);
    if (!preview.eligible) return { ...preview, acquired: false };
    const { sourceType, sourceId } = preview;
    const state = this._ensureState();
    // A guarantee records success only after the final path, ownership, and
    // provenance checks. Keep this in the same save as the acquired card.
    if (options.mode === 'guaranteed' && options.offerId) {
      state.skillOpportunityAttempts[options.offerId] = {
        offerId: options.offerId,
        sourceId,
        sourceType,
        locationId: offer.locationId,
        realm: state.realm,
        turn: Number(state.turn) || 0,
        chance: 100,
        roll: 0,
        outcome: 'acquired'
      };
    }
    state.deck.push(offer.cardId);
    const record = {
      cardId: offer.cardId,
      cardName: offer.cardName || offer.cardId,
      offerId: options.offerId || null,
      sourceId,
      sourceType,
      locationId: options.locationId || offer.locationId || null,
      realm: state.realm || null,
      path: state.path || null,
      turn: Number(state.turn) || 0,
      mode: options.mode || 'unknown',
      chance: Number.isFinite(options.chance) ? options.chance : null,
      roll: Number.isFinite(options.roll) ? options.roll : null
    };
    state.skillAcquisitions[this._canonicalCardId(offer.cardId)] = record;
    this._syncRuntimeDeck(offer.cardId);
    this._recordDeckOperation('acquire', {
      sourceType: record.sourceType,
      sourceId: record.sourceId,
      path: record.path,
      cardId: offer.cardId,
      mode: record.mode
    });
    this._persistDeck();
    this._emit('skillcard:acquired', record);
    this._dbg('acquired', record);
    return { acquired: true, reason: 'acquired', cardId: offer.cardId, record };
  }

  _syncRuntimeDeck(cardId) {
    const runtime = this.deckCombatSystem;
    if (!runtime) return;
    if (typeof runtime.addCard === 'function') {
      runtime.addCard(cardId);
      return;
    }
    if (Array.isArray(runtime.masterDeck) && !runtime.masterDeck.includes(cardId)) {
      runtime.masterDeck.push(cardId);
    }
  }

  _emit(name, data) {
    if (this.eventBus && typeof this.eventBus.emit === 'function') this.eventBus.emit(name, data);
  }
}

if (typeof window !== 'undefined') window.SkillCardAcquisitionSystem = SkillCardAcquisitionSystem;
if (typeof module !== 'undefined' && module.exports) module.exports = SkillCardAcquisitionSystem;
