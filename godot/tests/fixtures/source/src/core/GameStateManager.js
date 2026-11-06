/**
 * GameStateManager - 全局游戏状态管理器
 *
 * 单一数据源，所有系统通过 EventBus 或直接读取来访问状态。
 * 每个字段只有一个 Owner 系统（可写），其他系统只读。
 *
 * 数据主权：
 *   attributes (cultivation等) → GameStateManager (读写)
 *   flags                    → GameStateManager (读写), QuestSystem (写)
 *   resources (lifespan等)   → GameStateManager (读写)
 *   realm, path, turn        → GameStateManager (读写)
 *   unlocks                  → GameStateManager (读写), localStorage
 */
class GameStateManager {
  static SAVE_SCHEMA_VERSION = 10;
  static CAUSAL_SESSION_SCHEMA_VERSION = 18;
  static TREASURE_OWNERSHIP_CAUSAL_VERSION = 8;
  static QUEST_STATE_SCHEMA_VERSION = 3;
  static LIFE_ARCHIVE_SCHEMA_VERSION = 1;
  static SAVE_SLOT_SCHEMA_VERSION = 1;
  static SAVE_SLOT_IDS = Object.freeze(['slot_1', 'slot_2', 'slot_3']);
  static ACTIVE_SAVE_SLOT_STORAGE_KEY = 'xiuxian_active_save_slot';
  static LEGACY_QUEST_STORAGE_KEY = 'xiuxian_active_quests';
  static SAVE_SLOT_STORAGE_KEYS = Object.freeze({
    slot_1: 'xiuxian_unlocks',
    slot_2: 'xiuxian_unlocks_slot_2',
    slot_3: 'xiuxian_unlocks_slot_3'
  });
  static LEGACY_ARCHIVE_SCHEMA_VERSION = 1;
  static LEGACY_ARCHIVE_MIGRATION_VERSION = 1;
  static LEGACY_SET_IDS = Object.freeze([
    'sword_heart', 'pill_way', 'array_way',
    'heaven_book', 'demon_blood', 'immortal_will'
  ]);
  static REALM_ORDER = ['qi', 'foundation', 'golden', 'nascent', 'deity', 'tribulation'];
  static LIFE_PHASES = Object.freeze({
    ALIVE: 'ALIVE',
    DYING_NARRATIVE: 'DYING_NARRATIVE',
    EPILOGUE: 'EPILOGUE',
    LEGACY_CHOICE: 'LEGACY_CHOICE',
    REINCARNATING: 'REINCARNATING'
  });
  constructor() {
    this.config = {
      realms: null,
      paths: null
    };
    this.playerName = '\u53f6\u51cc\u4e91'; // 默认道号，可被玩家修改
    this.activeSaveSlotId = this._loadActiveSaveSlotId();
    this._activeSaveSlotCorrupt = false;
    this.unlocks = this._loadUnlocks();
    this.reset(true);
    this._restoredCausalSession = this._restoreCausalSession();
  }

  /**
   * 从配置初始化（境界/功法数据）
   */
  init(config) {
    if (config) {
      if (config.realms) this.config.realms = config.realms;
      if (config.paths) this.config.paths = config.paths;
    }
  }

  /**
   * 重置状态
   * @param {boolean} keepUnlocks - 是否保留解锁记录（转世时为 true）
   */
  reset(keepUnlocks = true) {
    const savedUnlocks = keepUnlocks ? (this.unlocks || this._loadUnlocks()) : this._createDefaultUnlocks();
    const hasRuntimeSeedState = Array.isArray(this.karmaSeeds);

    // 【P1 #10 修复】跨世因果种子保留——bloodline/fate 类型不清空
    const preservedSeeds = !hasRuntimeSeedState && keepUnlocks
      ? (savedUnlocks.pendingKarmaSeeds || []).map(seed => Object.assign({}, seed))
      : [];
    if (keepUnlocks && hasRuntimeSeedState) {
      for (const seed of this.karmaSeeds) {
        if (seed && (seed.seedType === 'bloodline' || seed.seedType === 'fate')) {
          // 施加延迟倍率，前世种子在新一世延迟更久才发芽
          const adjustedSeed = Object.assign({}, seed);
          adjustedSeed.delay = Math.round((seed.delay || 5) * 1.5) + 5;
          preservedSeeds.push(adjustedSeed);
        }
      }
    }

    // 核心属性 (微数值模型)
    // 牌组战斗采用 1～5 的微伤害；基础 6 点气血为玩家保留至少
    // 两次判断与防御机会，避免一次普通攻击直接触发燃血死亡链。
    this.maxHealth = 6 + (savedUnlocks.bonuses.maxHp || 0);
    this.maxDaoHeart = 3 + (savedUnlocks.bonuses.daoHeart || 0);

    this.attributes = {
      cultivation: 0 + (savedUnlocks.bonuses.startCultivation || 0),
      // 新手开局保留一格可见成长空间，确保序章的微量道心奖励不会
      // 因为初始满值而结算为 0；旧存档仍按快照中的实际值恢复。
      daoHeart: Math.max(0, this.maxDaoHeart - 1),
      karmaGood: 0 + (savedUnlocks.bonuses.karmaGood || 0),
      karmaBad: 0 + (savedUnlocks.bonuses.karmaBad || 0),
      fortune: 50 + (savedUnlocks.bonuses.fortune || 0),
      // 与道心一样留出一格新手反馈空间，避免教学卡的气血奖励在满值
      // 时显示为“实际 +0”。旧存档仍以持久化快照为准。
      health: Math.max(1, this.maxHealth - 1),
      aura: 0,
      tianji: 0 // 天机暴露值
    };

    // 资源
    this.resources = {
      spiritStone: 10 + (savedUnlocks.bonuses.startSpiritStone || 0), // 压缩灵石数值
      lifespan: 80 + (savedUnlocks.bonuses.maxLifespan || 0),
      pills: {},
      treasures: [],
      companions: []
    };
    this._treasureOwnershipMigrationRequired = false;
    this._treasureLegacyResourceFieldMissing = false;
    // 当世可消费物品。礼物由商店/事件生产，由 NPC 交互唯一消费。
    this.itemInventory = {};
    // 每个 NPC 每回合至多一次关系行动；持久化以防刷新绕过额度。
    this.interactionBudget = {};
    // 道侣自有的当世进度。好感仍唯一归 NpcSystem；这里只保存羁绊、信任与事件冷却。
    this.companionProgress = { states: {}, cooldowns: {} };
    // 势力当世进度由 FactionSystem 写入；遗产声望只在新一世初始化时消费。
    this.factionProgress = {
      reputations: {}, undercurrentStages: {}, globalFlags: {}, ticksSinceEvent: 0
    };
    this.tradeRouteState = null;
    this.worldPulseState = null;
    this.lineageRunStats = null;

    // ... (rest remains the same)
    this.equipment = {
      weapon: null,
      armor: null,
      accessory: null,
      artifact: null
    };
    // 唯一持久化的法宝拥有账本。resources.treasures 与 treasureInventory
    // 仅是 TreasureSystem 从此账本生成的兼容读投影，绝不能独立写入。
    this.treasureInstances = {};
    this.treasureCommandReceipts = {};
    this.treasureInventory = [];
    this.treasureCooldowns = {};

    this.realm = 'qi';
    this.path = null;
    this.pathArchetypes = Object.assign({}, savedUnlocks.legacy?.pathArchetypes || {});
    this.turn = 0;
    // `turn` remains a compatibility/lifespan counter.  New causal domains
    // must use this single, persistent clock instead of private counters or
    // truncated history lengths.
    this.runClock = this._createRunClock();
    this.marketState = this._createDefaultMarketState();
    this.cardsPlayed = [];
    this.dead = false;
    this.deadReason = '';
    this.deathCauseId = '';
    this._lifeArchived = false;
    this.archiveVersion = 0;
    this.lifePhase = GameStateManager.LIFE_PHASES.ALIVE;
    this.endingCandidate = null;
    this.endingId = null;
    this.pendingCardId = null;
    this.decisionCheckpoint = null;
    // 已扣过成本、仍须玩家处理的本局后果。只存来源，不复制卡片或 effects。
    this.pendingConsequence = null;
    // 境界仍以 realm 为唯一事实。该短事务只记录已破境、但传承/入境决策尚未
    // 完成的恢复边界，绝不保存第二份 visual stage 或可任意篡改的下一境界。
    this.realmTransition = null;
    this.combatSession = null;
    this.chapterProgress = null;
    this.flowState = null;
    this.terminalContext = null;
    this.lastEndingReport = null;
    // 修改器仅允许显式 debug 构建注入；正式页面不创建、持久化或继承该状态。
    const debugBuild = typeof globalThis !== 'undefined' && globalThis.__XIUXIAN_DEBUG__ === true;
    this.godMode = debugBuild
      ? Object.assign({ infiniteGifting: false, invincible: false }, this.godMode || {})
      : null;
    // 统一承接卡牌、同伴和探索产生的长期修正，避免 Effect 被静默丢弃。
    this.modifiers = {};
    // 认知与线索允许跨世保留；力量修正每世清空。
    this.knowledge = Object.assign({}, savedUnlocks.legacy?.knowledge || {});
    this.clues = (savedUnlocks.legacy?.clues || []).map(id => ({
      id,
      source: 'legacy',
      turn: 0,
      life: savedUnlocks.lifeCount || 0
    }));
    this.karmaSeeds = preservedSeeds;  // 【P1 #10 修复】替代原 this.karmaSeeds = []
    this.causalHistory = [];
    this.dungeon = null;
    this.dungeonNodeIndex = 0;
    this.dungeonNodeId = null;
    this.dungeonPath = [];
    this.dungeonRun = null;
    this.dungeonOutcomeReceipts = [];
    this.pendingVendorSession = null;
    // A purchase receipt may be durable before the player decides whether the
    // concrete instance enters a slot or stays in the 纳戒.  This is one
    // recoverable decision, never an inventory projection or a second owner.
    this.pendingLoadoutDecision = null;
    this.worldContinuityState = null;
    this.storyNetworkState = null;
    this.narrativeLedgerState = null;
    this.karmaRippleState = null;
    this.heavensHintState = null;

    this.currentLocation = '宗门';
    this.visitedLocations = ['宗门'];
    this.locationStates = {};

    this.choiceEchoes = [];
    this.choiceHistory = [];
    this.recentCardTags = [];
    this.deck = [];
    this.starterDeckPath = null;
    this.deckOperations = [];
    this.skillAcquisitions = {};
    this.skillOpportunityAttempts = {};
    this.opportunityAcquisitions = {};
    this.opportunityAttempts = {};

    // 运行时使用副本，避免临时状态直接污染持久化对象。
    this.flags = Object.assign({}, savedUnlocks.flags || {});
    delete this.flags.game_ended;
    this.unlocks = savedUnlocks;
    if (this.flags.post_ascension_active) {
      this.realm = 'tribulation';
      this.currentLocation = '云中城';
      this.visitedLocations = ['云中城'];
    }
    this.unlocks.pendingKarmaSeeds = this.karmaSeeds.map(seed => Object.assign({}, seed));
    if (hasRuntimeSeedState) this._saveUnlocks();

    eventBus.emit('state:reset', {});
  }

  _lifeIdFor(lifeCount = this.getLifeCount()) {
    const slotId = this._isValidSaveSlotId(this.activeSaveSlotId)
      ? this.activeSaveSlotId
      : 'slot_1';
    return `${slotId}:life:${Math.max(0, Math.floor(Number(lifeCount) || 0))}`;
  }

  recordDungeonOutcome(settlement) {
    if (!settlement || !['success', 'abandon', 'failure'].includes(settlement.outcome)
      || typeof settlement.sessionId !== 'string' || !settlement.sessionId
      || typeof settlement.dungeonId !== 'string' || !settlement.dungeonId
      || typeof settlement.sourceCardId !== 'string' || !settlement.sourceCardId
      || !Number.isSafeInteger(settlement.sourceDecisionIndex)
      || settlement.sourceDecisionIndex < 0) return false;
    const receipt = {
      lifeId: this._lifeIdFor(),
      sessionId: settlement.sessionId,
      dungeonId: settlement.dungeonId,
      sourceCardId: settlement.sourceCardId,
      sourceDecisionIndex: settlement.sourceDecisionIndex,
      outcome: settlement.outcome,
      settledDecisionIndex: this.getCausalDecisionIndex()
    };
    if (!Array.isArray(this.dungeonOutcomeReceipts)) this.dungeonOutcomeReceipts = [];
    if (this.dungeonOutcomeReceipts.some(entry => entry.sessionId === receipt.sessionId)) return false;
    this.dungeonOutcomeReceipts.push(receipt);
    this.dungeonOutcomeReceipts = this.dungeonOutcomeReceipts.slice(-32);
    return true;
  }

  getDungeonOutcomeForChoice({ sourceCardId, sourceDecisionIndex, dungeonId, outcome }) {
    return (this.dungeonOutcomeReceipts || []).find(entry =>
      entry.lifeId === this._lifeIdFor()
      && entry.sourceCardId === sourceCardId
      && entry.sourceDecisionIndex === sourceDecisionIndex
      && entry.dungeonId === dungeonId
      && entry.outcome === outcome
    ) || null;
  }

  _createRunClock() {
    return {
      version: 1,
      lifeId: this._lifeIdFor(),
      decisionIndex: 0,
      decisionClockMigrationSource: null,
      receipts: {}
    };
  }

  _normalizePendingConsequence(raw) {
    if (!raw || typeof raw !== 'object' || Array.isArray(raw)
      || raw.version !== 1 || raw.type !== 'inner_demon'
      || raw.lifeId !== this._lifeIdFor() || raw.lifeId !== this.runClock?.lifeId
      || raw.realm !== this.realm
      || typeof raw.sourceCardId !== 'string' || !raw.sourceCardId) return null;
    return {
      version: 1,
      type: 'inner_demon',
      lifeId: raw.lifeId,
      realm: raw.realm,
      sourceCardId: raw.sourceCardId
    };
  }

  getPendingConsequence() {
    return this._normalizePendingConsequence(this.pendingConsequence);
  }

  _normalizeRunClock(raw, options = {}) {
    const source = raw && typeof raw === 'object' && !Array.isArray(raw) ? raw : {};
    const expectedLifeId = this._lifeIdFor();
    const validLifeId = typeof source.lifeId === 'string' && source.lifeId === expectedLifeId;
    const fallbackDecisionIndex = Math.max(0, Math.floor(Number(options.fallbackDecisionIndex) || 0));
    const receipts = {};
    if (source.receipts && typeof source.receipts === 'object' && !Array.isArray(source.receipts)) {
      for (const [token, receipt] of Object.entries(source.receipts)) {
        if (typeof token !== 'string' || !token || !receipt || typeof receipt !== 'object') continue;
        const index = Math.max(0, Math.floor(Number(receipt.decisionIndex) || 0));
        if (index <= 0) continue;
        receipts[token] = {
          token,
          decisionIndex: index,
          sourceCardId: typeof receipt.sourceCardId === 'string' ? receipt.sourceCardId : null,
          kind: typeof receipt.kind === 'string' ? receipt.kind : 'top_level'
        };
      }
    }
    const receiptMax = Math.max(0, ...Object.values(receipts).map(receipt => receipt.decisionIndex));
    return {
      version: 1,
      lifeId: expectedLifeId,
      decisionIndex: validLifeId
        ? Math.max(receiptMax, Math.max(0, Math.floor(Number(source.decisionIndex) || 0)))
        : Math.max(receiptMax, fallbackDecisionIndex),
      decisionClockMigrationSource: validLifeId
        ? null
        : (typeof options.migrationSource === 'string' ? options.migrationSource : 'legacy_turn'),
      receipts
    };
  }

  _createDefaultMarketState() {
    return {
      version: 3,
      lastBazaarDecisionIndex: -99,
      lastGhostDecisionIndex: -99,
      nextGhostDecisionIndex: null,
      nextBazaarDecisionIndex: null,
      totalVisits: 0,
      currentItems: [],
      priceMultiplier: 1,
      slotCount: 5,
      routeModifiers: null,
      activeSession: null,
      vendorRelations: {},
      visitHistory: [],
      debts: [],
      rustedSwordOrders: [],
      ghostMarketAccess: 'open',
      migrationSource: null
    };
  }

  _normalizeMarketActiveSession(raw) {
    if (!raw || typeof raw !== 'object' || Array.isArray(raw) || !['open', 'result'].includes(raw.status)) return null;
    const vendorId = raw.vendorId === 'standard_shop' ? 'regulated_market' : raw.vendorId;
    if (raw.status === 'result') {
      return raw.resultCard && typeof raw.resultCard === 'object'
        ? { version: 2, status: 'result', resultCard: JSON.parse(JSON.stringify(raw.resultCard)) }
        : null;
    }
    if (typeof vendorId !== 'string' || !vendorId) return null;
    const sessionId = typeof raw.sessionId === 'string' && raw.sessionId
      ? raw.sessionId
      : (typeof raw.sessionKey === 'string' && raw.sessionKey ? raw.sessionKey : null);
    if (!sessionId) return null;
    const marketType = typeof raw.marketType === 'string' && raw.marketType
      ? raw.marketType
      : (vendorId === 'ghost_market' ? 'ghost' : (vendorId === 'public_bazaar' ? 'public_bazaar' : 'regulated'));
    const clone = value => JSON.parse(JSON.stringify(value));
    const offers = Array.isArray(raw.immutableOffers) ? raw.immutableOffers : raw.items;
    const budget = raw.interactionBudget && typeof raw.interactionBudget === 'object' ? raw.interactionBudget : {};
    return {
      ...clone(raw),
      version: 2,
      status: 'open',
      sessionId,
      sessionKey: sessionId,
      vendorId,
      marketType,
      offerRevision: Math.max(1, Math.floor(Number(raw.offerRevision) || 1)),
      immutableOffers: Array.isArray(offers) ? clone(offers) : [],
      actionReceipts: raw.actionReceipts && typeof raw.actionReceipts === 'object' && !Array.isArray(raw.actionReceipts)
        ? clone(raw.actionReceipts) : {},
      interactionBudget: {
        limit: Math.max(0, Math.floor(Number(budget.limit) || 0)),
        remaining: Math.max(0, Math.floor(Number(budget.remaining ?? budget.limit) || 0))
      },
      stalls: Array.isArray(raw.stalls) ? clone(raw.stalls) : [],
      services: Array.isArray(raw.services) ? clone(raw.services) : [],
      summary: raw.summary && typeof raw.summary === 'object' && !Array.isArray(raw.summary) ? clone(raw.summary) : {},
      items: undefined
    };
  }

  _normalizeMarketState(raw, options = {}) {
    const defaults = this._createDefaultMarketState();
    const source = raw && typeof raw === 'object' && !Array.isArray(raw) ? raw : {};
    const normalizeIndex = value => Math.max(0, Math.floor(Number(value) || 0));
    const hasStoredIndex = value => value !== null && value !== '' && Number.isFinite(Number(value));
    const hasGhostCadence = hasStoredIndex(source.nextGhostDecisionIndex);
    const hasBazaarCadence = hasStoredIndex(source.nextBazaarDecisionIndex);
    const seenRustedSwordOrderIds = new Set();
    const seenRustedSwordOrderFacts = new Set();
    const rustedSwordOrders = Array.isArray(source.rustedSwordOrders)
      ? source.rustedSwordOrders.flatMap(entry => {
        if (!entry || typeof entry !== 'object' || Array.isArray(entry)) return [];
        const orderId = typeof entry.orderId === 'string' ? entry.orderId : '';
        const factInstanceId = typeof entry.factInstanceId === 'string' ? entry.factInstanceId : '';
        const consumerId = typeof entry.consumerId === 'string' ? entry.consumerId : '';
        const validStatus = ['REGISTERED', 'READY', 'CLAIMED'].includes(entry.status) ? entry.status : null;
        const factConsumerKey = `${factInstanceId}:${consumerId}`;
        const canonicalOrderId = `licensed_rusted_sword:${factInstanceId}:${consumerId}`;
        if (!orderId || orderId !== canonicalOrderId || !factInstanceId || !consumerId || !validStatus
          || seenRustedSwordOrderIds.has(orderId) || seenRustedSwordOrderFacts.has(factConsumerKey)
          || entry.definitionId !== 'licensed_rusted_sword') return [];
        const registeredCoreDecisionIndex = normalizeIndex(
          entry.registeredCoreDecisionIndex ?? entry.registeredDecisionIndex
        );
        const coreDecisionDelay = Math.max(1, Math.floor(Number(entry.coreDecisionDelay) || 0));
        const dueCoreDecisionIndex = normalizeIndex(entry.dueCoreDecisionIndex ?? entry.dueDecisionIndex);
        if (coreDecisionDelay !== 3 || dueCoreDecisionIndex !== registeredCoreDecisionIndex + coreDecisionDelay) return [];
        seenRustedSwordOrderIds.add(orderId);
        seenRustedSwordOrderFacts.add(factConsumerKey);
        const clone = JSON.parse(JSON.stringify(entry));
        return [{
          ...clone,
          orderId,
          factInstanceId,
          consumerId,
          definitionId: 'licensed_rusted_sword',
          provenanceFactTypeId: 'sword_origin_licensed',
          registeredCoreDecisionIndex,
          coreDecisionDelay,
          dueCoreDecisionIndex,
          status: validStatus,
          deliveryQueued: entry.deliveryQueued === true,
          instanceId: typeof entry.instanceId === 'string' && entry.instanceId ? entry.instanceId : null,
          provenanceFactInstanceId: typeof entry.provenanceFactInstanceId === 'string' && entry.provenanceFactInstanceId
            ? entry.provenanceFactInstanceId : null
        }];
      })
      : [];
    return {
      ...defaults,
      version: 3,
      lastBazaarDecisionIndex: Number.isFinite(Number(source.lastBazaarDecisionIndex))
        ? Math.floor(Number(source.lastBazaarDecisionIndex))
        : defaults.lastBazaarDecisionIndex,
      lastGhostDecisionIndex: Number.isFinite(Number(source.lastGhostDecisionIndex))
        ? Math.floor(Number(source.lastGhostDecisionIndex))
        : defaults.lastGhostDecisionIndex,
      nextGhostDecisionIndex: hasGhostCadence ? normalizeIndex(source.nextGhostDecisionIndex) : null,
      nextBazaarDecisionIndex: hasBazaarCadence ? normalizeIndex(source.nextBazaarDecisionIndex) : null,
      totalVisits: normalizeIndex(source.totalVisits),
      currentItems: Array.isArray(source.currentItems)
        ? JSON.parse(JSON.stringify(source.currentItems))
        : [],
      priceMultiplier: Math.max(0.01, Number(source.priceMultiplier) || 1),
      slotCount: Math.max(1, Math.floor(Number(source.slotCount) || defaults.slotCount)),
      routeModifiers: source.routeModifiers && typeof source.routeModifiers === 'object'
        ? JSON.parse(JSON.stringify(source.routeModifiers))
        : null,
      activeSession: this._normalizeMarketActiveSession(source.activeSession),
      vendorRelations: source.vendorRelations && typeof source.vendorRelations === 'object' && !Array.isArray(source.vendorRelations)
        ? JSON.parse(JSON.stringify(source.vendorRelations)) : {},
      visitHistory: Array.isArray(source.visitHistory) ? JSON.parse(JSON.stringify(source.visitHistory)) : [],
      debts: Array.isArray(source.debts) ? source.debts.filter(entry => entry && typeof entry === 'object').map(entry => {
        const debt = JSON.parse(JSON.stringify(entry));
        // B2 debt terms are part of the signed market fact. Legacy debts did
        // not contain a term; migrate them to a visible minimum instead of
        // presenting a free safe settlement after a refresh.
        if (!Array.isArray(debt.settlementCostSpec) || debt.settlementCostSpec.length === 0) {
          debt.settlementCostSpec = [{ kind: 'resource', key: 'spiritStone', amount: 1 }];
        }
        return debt;
      }) : [],
      rustedSwordOrders,
      ghostMarketAccess: source.ghostMarketAccess === 'revoked' ? 'revoked' : 'open',
      // This is provenance, not a migration switch. Preserve a persisted
      // `fresh_run` marker across reloads while still marking truly unclocked
      // legacy snapshots with their recovery source.
      migrationSource: typeof source.migrationSource === 'string' && source.migrationSource
        ? source.migrationSource
        : (hasGhostCadence || hasBazaarCadence ? null : (options.migrationSource || null))
    };
  }

  _normalizePendingLoadoutDecision(raw) {
    if (!raw || typeof raw !== 'object' || Array.isArray(raw) || raw.status !== 'pending') return null;
    const id = typeof raw.id === 'string' ? raw.id : '';
    const instanceId = typeof raw.instanceId === 'string' ? raw.instanceId : '';
    const sourceVendorSessionKey = typeof raw.sourceVendorSessionKey === 'string'
      ? raw.sourceVendorSessionKey
      : '';
    const purchaseReceiptToken = typeof raw.purchaseReceiptToken === 'string'
      ? raw.purchaseReceiptToken
      : '';
    const targetSlot = typeof raw.targetSlot === 'string' ? raw.targetSlot : '';
    if (!id || !instanceId || !sourceVendorSessionKey || !purchaseReceiptToken
      || !['weapon', 'armor', 'accessory', 'artifact'].includes(targetSlot)) return null;
    const actions = raw.allowedActions && typeof raw.allowedActions === 'object'
      && !Array.isArray(raw.allowedActions) ? raw.allowedActions : {};
    const ghostDebtId = typeof raw.ghostDebtId === 'string' && raw.ghostDebtId
      ? raw.ghostDebtId
      : null;
    // This is a frozen B1 receipt preview, not a second debt authority: the
    // actual mutable debt remains in marketState.debts. Preserve it only when
    // it names the same signed debt so a refresh cannot hide the price, due
    // beat, odds, or pity term before the player makes the equip/stash choice.
    const ghostDebt = ghostDebtId && raw.ghostDebt && typeof raw.ghostDebt === 'object'
      && !Array.isArray(raw.ghostDebt) && raw.ghostDebt.debtId === ghostDebtId
      ? JSON.parse(JSON.stringify(raw.ghostDebt))
      : null;
    // The B1 contract has exactly these safe choices.  A malformed/legacy
    // snapshot must not expose an accidental refund operation.
    return {
      id,
      instanceId,
      sourceVendorSessionKey,
      purchaseReceiptToken,
      targetSlot,
      status: 'pending',
      allowedActions: {
        equip: actions.equip === true,
        stash: actions.stash === true,
        viewProvenance: actions.viewProvenance === true,
        return: actions.return === true
      },
      refundPolicy: raw.refundPolicy && typeof raw.refundPolicy === 'object'
        && !Array.isArray(raw.refundPolicy)
        ? JSON.parse(JSON.stringify(raw.refundPolicy))
        : null,
      ...(ghostDebtId ? { ghostDebtId } : {}),
      ...(ghostDebt ? { ghostDebt } : {})
    };
  }

  getRunClock() {
    return JSON.parse(JSON.stringify(this.runClock || this._createRunClock()));
  }

  getDecisionIndex() {
    return Math.max(0, Math.floor(Number(this.runClock?.decisionIndex) || 0));
  }

  getNextDecisionIndex() {
    return this.getDecisionIndex() + 1;
  }

  _cloneCausalValue(value) {
    return value === undefined ? undefined : JSON.parse(JSON.stringify(value));
  }

  // Reincarnation changes both the current-life snapshot and cross-life
  // unlocks. Defer every intermediate save and publish one complete new-life
  // value only after the handoff card and all producers have reset.
  beginLifeTransition() {
    if (this._lifeTransition || this._causalTransaction) return false;
    if (this.persistCausalSession({ force: true }) !== true) return false;
    this._lifeTransition = {
      unlocks: this._cloneCausalValue(this.unlocks),
      flags: this._cloneCausalValue(this.flags),
      npcAffections: typeof npcSystem !== 'undefined' && npcSystem?.affections
        ? this._cloneCausalValue(npcSystem.affections) : null,
      npcRuntime: typeof npcSystem !== 'undefined' && npcSystem
        && typeof npcSystem.captureRollbackState === 'function'
        ? npcSystem.captureRollbackState() : null,
      storyThreadRuntime: typeof threadEngine !== 'undefined'
        && typeof threadEngine?.captureRollbackState === 'function'
        ? threadEngine.captureRollbackState() : null
    };
    return true;
  }

  rollbackLifeTransition() {
    const before = this._lifeTransition;
    if (!before) return false;
    this.unlocks = this._cloneCausalValue(before.unlocks);
    // Reset reads savedUnlocks and broadcasts a clean owner reset. Restore the
    // old-life snapshot and live projections immediately afterwards. Keep the
    // write deferral active during every reset listener: QuestSystem and other
    // owners may otherwise publish an empty new-life state over the old save.
    this.karmaSeeds = undefined;
    this.reset(true);
    this.unlocks = this._cloneCausalValue(before.unlocks);
    this.flags = this._cloneCausalValue(before.flags);
    this._restoreCausalSession();
    if (before.npcAffections && typeof npcSystem !== 'undefined' && npcSystem) {
      npcSystem.affections = this._cloneCausalValue(before.npcAffections);
    }
    this._hydrateCausalRuntimeAfterRollback(before.storyThreadRuntime);
    if (typeof questSystem !== 'undefined' && questSystem
      && typeof questSystem._loadActiveQuests === 'function') {
      questSystem._loadActiveQuests();
    }
    if (typeof companionSystem !== 'undefined' && companionSystem
      && typeof companionSystem.loadData === 'function'
      && typeof dataLoader !== 'undefined') {
      companionSystem.loadData(dataLoader.loadSync('companions:events'));
    }
    if (before.npcRuntime && typeof npcSystem !== 'undefined' && npcSystem
      && typeof npcSystem.restoreRollbackState === 'function') {
      npcSystem.restoreRollbackState(before.npcRuntime);
    }
    this._lifeTransition = null;
    return true;
  }

  commitLifeTransition() {
    if (!this._lifeTransition) return false;
    if (this.persistCausalSession({ force: true }) !== true) {
      this.rollbackLifeTransition();
      return false;
    }
    const before = this._lifeTransition;
    this._lifeTransition = null;
    if (this._saveUnlocks() === true) return true;
    this._lifeTransition = before;
    this.rollbackLifeTransition();
    return false;
  }

  /**
   * Child systems (ledger, treasure commands, Flow) may update their runtime
   * projections while a card is resolving.  They must not independently write
   * a durable snapshot: the source decision has not committed yet.  The
   * transaction records the last authenticated snapshot and lets the single
   * top-level decision port perform the only physical save.
   */
  beginCausalTransaction({ decisionPending = false } = {}) {
    if (this._causalTransaction) {
      this._causalTransaction.depth += 1;
      if (decisionPending && !this._causalTransaction.pendingDecisionIndex) {
        this._causalTransaction.pendingDecisionIndex = this.getNextDecisionIndex();
      }
      return true;
    }
    // A freshly started life has no durable causal snapshot yet.  Establish
    // one before any effect can run so a failed first decision can restore the
    // *entire* authoritative state (attributes/resources/flags included), not
    // merely the clock fields. This is a one-time durability boundary, not a
    // second decision or a player-visible checkpoint.
    if (!this.unlocks?.causalSessionState) {
      let bootstrapped = false;
      try {
        bootstrapped = this.persistCausalSession({ force: true });
      } catch (error) {
        bootstrapped = false;
      }
      if (bootstrapped !== true || !this.unlocks?.causalSessionState) return false;
    }
    this._causalTransaction = {
      depth: 1,
      pendingDecisionIndex: decisionPending ? this.getNextDecisionIndex() : null,
      beforeSnapshot: this._cloneCausalValue(this.unlocks?.causalSessionState ?? null),
      beforeStoryThreadState: this._cloneCausalValue(this.unlocks?.storyThreadState ?? null),
      beforeQuestState: this._cloneCausalValue(this.unlocks?.questState ?? null),
      beforeQuestRuntime: typeof questSystem !== 'undefined' && questSystem
        && typeof questSystem.captureRollbackState === 'function'
        ? questSystem.captureRollbackState()
        : null,
      beforeStoryThreadRuntime: typeof threadEngine !== 'undefined'
        && typeof threadEngine?.captureRollbackState === 'function'
        ? threadEngine.captureRollbackState()
        : null,
      beforeRunClock: this._cloneCausalValue(this.runClock),
      beforeTurn: this.turn,
      beforeMarketState: this._cloneCausalValue(this.marketState),
      beforeNarrativeLedgerState: this._cloneCausalValue(this.narrativeLedgerState),
      beforeFlowState: this._cloneCausalValue(this.flowState),
      beforeKarmaRippleState: this._cloneCausalValue(this.karmaRippleState),
      beforeHeavensHintState: this._cloneCausalValue(this.heavensHintState),
      beforeCheckpoint: this._cloneCausalValue(this.decisionCheckpoint),
      // Flags are a sibling of causalSessionState, not part of its restore
      // payload. A rejected breakthrough/seal must restore both projections.
      beforeFlags: this._cloneCausalValue(this.flags),
      beforeUnlockFlags: this._cloneCausalValue(this.unlocks?.flags || {}),
      beforeKarmaSeeds: this._cloneCausalValue(this.karmaSeeds || []),
      beforePendingKarmaSeeds: this._cloneCausalValue(this.unlocks?.pendingKarmaSeeds || []),
      beforeNpcAffections: typeof npcSystem !== 'undefined' && npcSystem?.affections
        ? this._cloneCausalValue(npcSystem.affections)
        : null,
      deferredWrites: 0
    };
    return true;
  }

  getCausalDecisionIndex() {
    return this._causalTransaction?.pendingDecisionIndex || this.getDecisionIndex();
  }

  _hydrateCausalRuntimeAfterRollback(storyThreadRuntime = null) {
    // Thread state is a sibling of causalSessionState, with a live owner.
    // Restore both before a resumed combat action can persist again.
    if (storyThreadRuntime && typeof threadEngine !== 'undefined' && threadEngine
      && typeof threadEngine.restoreRollbackState === 'function') {
      threadEngine.restoreRollbackState(storyThreadRuntime);
    }
    if (typeof narrativeLedger !== 'undefined' && narrativeLedger
      && typeof narrativeLedger.hydrateState === 'function') {
      narrativeLedger.hydrateState(this.narrativeLedgerState || null);
    }
    if (typeof flowDirector !== 'undefined' && flowDirector
      && typeof flowDirector.hydrateState === 'function') {
      flowDirector.hydrateState(this.flowState || null);
    }
    if (typeof karmaRippleSystem !== 'undefined' && karmaRippleSystem) {
      if (this.karmaRippleState) karmaRippleSystem.hydrateState?.(this.karmaRippleState);
      else karmaRippleSystem.reset?.();
    }
    if (typeof heavensHintSystem !== 'undefined' && heavensHintSystem) {
      if (this.heavensHintState) heavensHintSystem.hydrateState?.(this.heavensHintState);
      else heavensHintSystem.reset?.();
    }
    // These producers are exported again by persistCausalSession. Restoring
    // only the state fields would let rejected outcome deltas leak back from
    // their live caches on the next accepted action or checkpoint.
    if (typeof worldContinuityStore !== 'undefined'
      && typeof worldContinuityStore?.hydrateState === 'function') {
      worldContinuityStore.hydrateState(this.worldContinuityState || {
        version: 1, lifeId: this.getLifeCount(), revision: 0, npcs: {}
      });
    }
    if (typeof factionSystem !== 'undefined'
      && typeof factionSystem?.restoreRollbackState === 'function') {
      factionSystem.restoreRollbackState(this.factionProgress);
    }
    if (typeof storyNetworkSystem !== 'undefined'
      && typeof storyNetworkSystem?.restoreRollbackState === 'function') {
      storyNetworkSystem.restoreRollbackState(this.storyNetworkState);
    }
    if (typeof tradeRouteSystem !== 'undefined' && tradeRouteSystem) {
      tradeRouteSystem.loadData(dataLoader.loadSync('world:trade_routes'));
      if (this.tradeRouteState) tradeRouteSystem.hydrateState(this.tradeRouteState);
    }
    if (typeof worldPulseSystem !== 'undefined' && worldPulseSystem) {
      worldPulseSystem.reset();
      if (this.worldPulseState) worldPulseSystem.hydrateState(this.worldPulseState);
    }
    if (typeof lineageSystem !== 'undefined' && lineageSystem
      && typeof lineageSystem.hydrateState === 'function') {
      lineageSystem.hydrateState(this.lineageRunStats);
    }
    // B5 order delivery can acquire an instance inside a top-level narrative
    // transaction. If its final checkpoint fails, projections must be rebuilt
    // from the restored ledger before a retry is allowed.
    if (typeof treasureSystem !== 'undefined' && treasureSystem
      && typeof treasureSystem.syncFromState === 'function') {
      treasureSystem.syncFromState(this);
    } else if (typeof equipmentSystem !== 'undefined' && equipmentSystem
      && typeof equipmentSystem.syncFromState === 'function') {
      equipmentSystem.syncFromState();
    }
  }

  rollbackCausalTransaction() {
    const transaction = this._causalTransaction;
    if (!transaction) return false;
    this._causalTransaction = null;
    if (this.unlocks) {
      this.unlocks.storyThreadState = this._cloneCausalValue(transaction.beforeStoryThreadState ?? null);
      this.unlocks.questState = this._cloneCausalValue(transaction.beforeQuestState ?? null);
    }
    if (transaction.beforeSnapshot && this.unlocks) {
      this.unlocks.causalSessionState = this._cloneCausalValue(transaction.beforeSnapshot);
      this._restoreCausalSession();
    } else {
      this.runClock = this._cloneCausalValue(transaction.beforeRunClock);
      this.turn = transaction.beforeTurn;
      this.marketState = this._cloneCausalValue(transaction.beforeMarketState);
      this.narrativeLedgerState = this._cloneCausalValue(transaction.beforeNarrativeLedgerState);
      this.flowState = this._cloneCausalValue(transaction.beforeFlowState);
      this.karmaRippleState = this._cloneCausalValue(transaction.beforeKarmaRippleState);
      this.heavensHintState = this._cloneCausalValue(transaction.beforeHeavensHintState);
      this.decisionCheckpoint = this._cloneCausalValue(transaction.beforeCheckpoint);
      if (this.unlocks) this.unlocks.causalSessionState = null;
    }
    this.flags = this._cloneCausalValue(transaction.beforeFlags);
    this.karmaSeeds = this._cloneCausalValue(transaction.beforeKarmaSeeds);
    if (this.unlocks) {
      this.unlocks.flags = this._cloneCausalValue(transaction.beforeUnlockFlags);
      this.unlocks.pendingKarmaSeeds = this._cloneCausalValue(transaction.beforePendingKarmaSeeds);
    }
    if (transaction.beforeNpcAffections && typeof npcSystem !== 'undefined' && npcSystem) {
      npcSystem.affections = this._cloneCausalValue(transaction.beforeNpcAffections);
    }
    this._hydrateCausalRuntimeAfterRollback(transaction.beforeStoryThreadRuntime);
    if (transaction.beforeQuestRuntime && typeof questSystem !== 'undefined' && questSystem
      && typeof questSystem.restoreRollbackState === 'function') {
      questSystem.restoreRollbackState(transaction.beforeQuestRuntime);
    }
    return true;
  }

  finishCausalTransaction() {
    if (!this._causalTransaction) return false;
    this._causalTransaction = null;
    if (typeof threadEngine !== 'undefined' && threadEngine
      && typeof threadEngine.publishCommittedResolutions === 'function') {
      threadEngine.publishCommittedResolutions();
    }
    return true;
  }

  /**
   * The only write port for a completed player-facing decision.  Callers must
   * supply a stable token for delayed flows (notably vendor close); duplicate
   * delivery returns the prior receipt without advancing time.
   */
  commitTopLevelDecision({ token, sourceCardId = null, kind = 'top_level' } = {}) {
    if (typeof token !== 'string' || !token) {
      return { committed: false, replayed: false, reason: 'missing_token', receipt: null };
    }
    this.runClock = this._normalizeRunClock(this.runClock, {
      fallbackDecisionIndex: this.turn,
      migrationSource: null
    });
    const existing = this.runClock.receipts[token];
    if (existing) {
      return { committed: false, replayed: true, reason: null, receipt: JSON.parse(JSON.stringify(existing)) };
    }
    const beforeClock = JSON.parse(JSON.stringify(this.runClock));
    const beforeTurn = this.turn;
    const beforeCausalSession = this.unlocks?.causalSessionState
      ? JSON.parse(JSON.stringify(this.unlocks.causalSessionState))
      : null;
    const beforeNarrativeLedgerState = this.narrativeLedgerState
      ? JSON.parse(JSON.stringify(this.narrativeLedgerState))
      : null;
    // Market cadence is part of the same durable causal snapshot.  GameLogic
    // may have tentatively evaluated the projected decision before it calls
    // this port, so a failed write must not leave a ghost-market schedule or
    // offer list that claims the decision happened.
    const beforeMarketState = this.marketState
      ? JSON.parse(JSON.stringify(this.marketState))
      : null;
    const beforeCheckpoint = this.decisionCheckpoint
      ? JSON.parse(JSON.stringify(this.decisionCheckpoint))
      : null;
    const beforeKarmaSeeds = this._cloneCausalValue(this.karmaSeeds || []);
    const beforePendingKarmaSeeds = this._cloneCausalValue(this.unlocks?.pendingKarmaSeeds || []);
    const index = this.getNextDecisionIndex();
    const receipt = {
      token,
      decisionIndex: index,
      sourceCardId: typeof sourceCardId === 'string' ? sourceCardId : null,
      kind: typeof kind === 'string' ? kind : 'top_level'
    };
    this.runClock.decisionIndex = index;
    // `turn` is a compatibility mirror for systems that have not yet migrated
    // their display/cooldown wording. It is deliberately derived here, never
    // a second decision authority.
    this.turn = index;
    this.runClock.receipts[token] = receipt;
    // A bounded receipt window is enough for UI retries/reload replay while
    // retaining the greatest index as an explicit migration fallback.
    const receiptEntries = Object.entries(this.runClock.receipts)
      .sort(([, left], [, right]) => right.decisionIndex - left.decisionIndex)
      .slice(0, 128);
    this.runClock.receipts = Object.fromEntries(receiptEntries);
    if (this.decisionCheckpoint && typeof this.decisionCheckpoint === 'object') {
      this.decisionCheckpoint.turn = index;
      this.decisionCheckpoint.decisionIndex = index;
    }
    let persisted = false;
    let ripenedSeeds = [];
    try {
      // A fact window is defined against the one authoritative player-decision
      // clock, never against a later market visit.  Keep this tentative until
      // the same causal snapshot below has been durably written.
      if (typeof narrativeLedger !== 'undefined' && narrativeLedger
        && typeof narrativeLedger.closeExpiredFacts === 'function') {
        narrativeLedger.closeExpiredFacts({ decisionIndex: index, persist: false });
      }
      if (typeof karmaSystem !== 'undefined' && karmaSystem
        && typeof karmaSystem.tick === 'function') {
        ripenedSeeds = karmaSystem.tick({ emitEvents: false, persist: false }) || [];
      }
      persisted = this.persistCausalSession({ force: true });
    } catch (error) {
      persisted = false;
    }
    if (persisted === false) {
      if (this._causalTransaction) {
        this.rollbackCausalTransaction();
        return { committed: false, replayed: false, reason: 'persistence_failed', receipt: null };
      }
      this.runClock = beforeClock;
      this.turn = beforeTurn;
      this.marketState = beforeMarketState;
      this.narrativeLedgerState = beforeNarrativeLedgerState;
      this.decisionCheckpoint = beforeCheckpoint;
      this.karmaSeeds = beforeKarmaSeeds;
      if (this.unlocks) {
        this.unlocks.causalSessionState = beforeCausalSession;
        this.unlocks.pendingKarmaSeeds = beforePendingKarmaSeeds;
      }
      this._hydrateCausalRuntimeAfterRollback();
      return { committed: false, replayed: false, reason: 'persistence_failed', receipt: null };
    }
    this.finishCausalTransaction();
    for (const notice of ripenedSeeds) eventBus.emit('karma:seedRipening', notice);
    eventBus.emit('state:decisionCommitted', { ...receipt, lifeId: this.runClock.lifeId });
    return { committed: true, replayed: false, reason: null, receipt: JSON.parse(JSON.stringify(receipt)) };
  }

  /**
   * Persist the minimum authoritative runtime required to resume a causal
   * thread after a real browser refresh. The narrative queue/current DOM card
   * are deliberately rebuilt by their producers instead of being serialized.
   */
  persistCausalSession(options = {}) {
    if (!this.unlocks) return false;
    if (this._causalTransaction && options.force !== true) {
      this._causalTransaction.deferredWrites += 1;
      return true;
    }
    const clone = value => JSON.parse(JSON.stringify(value));
    const persistedResources = clone(this.resources || {});
    // `treasures` was an old independent write model. Keep it in runtime for
    // legacy consumers, but omit it from new snapshots so it can never win a
    // conflict with instance authority on reload.
    delete persistedResources.treasures;
    const legacyRunState = this.getLegacyRunState();
    const currentCompanionProgress = typeof companionSystem !== 'undefined'
      && typeof companionSystem?.exportProgress === 'function'
      ? companionSystem.exportProgress()
      : (this.companionProgress || { states: {}, cooldowns: {} });
    this.companionProgress = clone(currentCompanionProgress);
    const currentFactionProgress = typeof factionSystem !== 'undefined'
      && typeof factionSystem?.exportProgress === 'function'
      ? factionSystem.exportProgress()
      : (this.factionProgress || {
          reputations: {}, undercurrentStages: {}, globalFlags: {}, ticksSinceEvent: 0
        });
    this.factionProgress = clone(currentFactionProgress);
    const currentTradeRoute = typeof tradeRouteSystem !== 'undefined'
      && tradeRouteSystem?._initialized === true
      && typeof tradeRouteSystem?.exportState === 'function'
      ? tradeRouteSystem.exportState()
      : this.tradeRouteState;
    this.tradeRouteState = currentTradeRoute ? clone(currentTradeRoute) : null;
    const currentWorldPulse = typeof worldPulseSystem !== 'undefined'
      && worldPulseSystem?._initialized === true
      && typeof worldPulseSystem?.exportState === 'function'
      ? worldPulseSystem.exportState()
      : this.worldPulseState;
    this.worldPulseState = currentWorldPulse ? clone(currentWorldPulse) : null;
    const currentLineageStats = typeof lineageSystem !== 'undefined'
      && lineageSystem?._listenersBound === true
      && typeof lineageSystem?.exportState === 'function'
      ? lineageSystem.exportState()
      : this.lineageRunStats;
    this.lineageRunStats = currentLineageStats ? clone(currentLineageStats) : null;
    const currentChapterProgress = typeof chapterSystem !== 'undefined'
      && typeof chapterSystem?.exportProgress === 'function'
      ? chapterSystem.exportProgress()
      : (this.chapterProgress || null);
    this.chapterProgress = currentChapterProgress ? clone(currentChapterProgress) : null;
    const currentFlowState = typeof flowDirector !== 'undefined'
      && typeof flowDirector?.exportState === 'function'
      ? flowDirector.exportState()
      : (this.flowState || null);
    this.flowState = currentFlowState ? clone(currentFlowState) : null;
    const currentWorldContinuity = typeof worldContinuityStore !== 'undefined'
      && typeof worldContinuityStore?.exportState === 'function'
      ? worldContinuityStore.exportState()
      : (this.worldContinuityState || null);
    this.worldContinuityState = currentWorldContinuity ? clone(currentWorldContinuity) : null;
    const currentStoryNetwork = typeof storyNetworkSystem !== 'undefined'
      && typeof storyNetworkSystem?.exportState === 'function'
      ? storyNetworkSystem.exportState()
      : (this.storyNetworkState || null);
    this.storyNetworkState = currentStoryNetwork ? clone(currentStoryNetwork) : null;
    const currentNarrativeLedger = typeof narrativeLedger !== 'undefined'
      && typeof narrativeLedger?.exportState === 'function'
      ? narrativeLedger.exportState()
      : (this.narrativeLedgerState || null);
    this.narrativeLedgerState = currentNarrativeLedger ? clone(currentNarrativeLedger) : null;
    const currentKarmaRipple = typeof karmaRippleSystem !== 'undefined'
      && typeof karmaRippleSystem?.exportState === 'function'
      ? karmaRippleSystem.exportState()
      : (this.karmaRippleState || null);
    this.karmaRippleState = currentKarmaRipple ? clone(currentKarmaRipple) : null;
    const currentHeavensHint = typeof heavensHintSystem !== 'undefined'
      && typeof heavensHintSystem?.exportState === 'function'
      ? heavensHintSystem.exportState()
      : (this.heavensHintState || null);
    this.heavensHintState = currentHeavensHint ? clone(currentHeavensHint) : null;
    const currentCombatSession = typeof deckCombatSystem !== 'undefined'
      && deckCombatSystem
      && typeof deckCombatSystem.exportState === 'function'
      ? deckCombatSystem.exportState()
      : null;
    // On a browser reload the GameStateManager restores the authenticated
    // combat snapshot before DeckCombatSystem has hydrated it. Startup systems
    // can legitimately persist unrelated state in that small interval. Do not
    // let an inactive, brand-new DeckCombatSystem erase the pending battle;
    // preserve it only until resumeSession consumes this restore boundary.
    const pendingRestoredCombat = !currentCombatSession
      && this._restoredCausalSession === true
      && this.combatSession?.active === true
      ? clone(this.combatSession)
      : null;
    this.combatSession = currentCombatSession
      ? clone(currentCombatSession)
      : pendingRestoredCombat;
    this.unlocks.causalSessionState = {
      version: GameStateManager.CAUSAL_SESSION_SCHEMA_VERSION,
      lifeCount: this.getLifeCount ? this.getLifeCount() : (this.unlocks.lifeCount || 0),
      runClock: clone(this.runClock || this._createRunClock()),
      playerName: this.playerName || '',
      path: this.path || null,
      realm: this.realm || 'qi',
      turn: Math.max(0, Number(this.turn) || 0),
      maxHealth: Math.max(1, Number(this.maxHealth) || 1),
      maxDaoHeart: Math.max(1, Number(this.maxDaoHeart) || 1),
      attributes: clone(this.attributes || {}),
      resources: persistedResources,
      itemInventory: clone(this.itemInventory || {}),
      interactionBudget: clone(this.interactionBudget || {}),
      knowledge: clone(this.knowledge || {}),
      clues: clone(this.clues || []),
      npcAffections: clone(
        typeof npcSystem !== 'undefined' && npcSystem?.affections
          ? npcSystem.affections
          : (this.unlocks.causalSessionState?.npcAffections || {})
      ),
      companionProgress: clone(this.companionProgress),
      factionProgress: clone(this.factionProgress),
      tradeRoute: this.tradeRouteState ? clone(this.tradeRouteState) : null,
      worldPulse: this.worldPulseState ? clone(this.worldPulseState) : null,
      lineageRunStats: this.lineageRunStats ? clone(this.lineageRunStats) : null,
      treasureInstances: clone(this.treasureInstances || {}),
      treasureCommandReceipts: clone(this.treasureCommandReceipts || {}),
      equipment: clone(this.equipment || {}),
      treasureCooldowns: clone(this.treasureCooldowns || {}),
      deck: clone(this.deck || []),
      starterDeckPath: this.starterDeckPath || null,
      deckOperations: clone(this.deckOperations || []),
      skillAcquisitions: clone(this.skillAcquisitions || {}),
      skillOpportunityAttempts: clone(this.skillOpportunityAttempts || {}),
      opportunityAcquisitions: clone(this.opportunityAcquisitions || {}),
      opportunityAttempts: clone(this.opportunityAttempts || {}),
      modifiers: clone(this.modifiers || {}),
      currentLocation: this.currentLocation || '宗门',
      visitedLocations: clone(this.visitedLocations || []),
      locationStates: clone(this.locationStates || {}),
      cardsPlayed: clone(this.cardsPlayed || []),
      choiceHistory: clone(this.choiceHistory || []),
      recentCardTags: clone(this.recentCardTags || []),
      dungeon: this.dungeon || null,
      dungeonNodeIndex: Math.max(0, Math.floor(Number(this.dungeonNodeIndex) || 0)),
      dungeonNodeId: typeof this.dungeonNodeId === 'string' ? this.dungeonNodeId : null,
      dungeonPath: clone(this.dungeonPath || []),
      dungeonRun: this.dungeonRun ? clone(this.dungeonRun) : null,
      dungeonOutcomeReceipts: clone(this.dungeonOutcomeReceipts || []),
      pendingLoadoutDecision: (() => {
        const pending = this._normalizePendingLoadoutDecision(this.pendingLoadoutDecision);
        return pending && this.treasureInstances?.[pending.instanceId] ? pending : null;
      })(),
      marketState: this.marketState ? clone(this.marketState) : this._createDefaultMarketState(),
      lifePhase: this.lifePhase || GameStateManager.LIFE_PHASES.ALIVE,
      dead: Boolean(this.dead),
      endingCandidate: this.endingCandidate || null,
      endingId: this.endingId || null,
      pendingCardId: this.pendingCardId || null,
      ...(this.getPendingConsequence()
        ? { pendingConsequence: this.getPendingConsequence() }
        : {}),
      decisionCheckpoint: this.decisionCheckpoint
        && typeof this.decisionCheckpoint === 'object'
        ? clone(this.decisionCheckpoint)
        : null,
      realmTransition: this.realmTransition
        && typeof this.realmTransition === 'object'
        ? clone(this.realmTransition)
        : null,
      combatSession: this.combatSession ? clone(this.combatSession) : null,
      chapterProgress: this.chapterProgress ? clone(this.chapterProgress) : null,
      flowState: this.flowState ? clone(this.flowState) : null,
      worldContinuity: this.worldContinuityState ? clone(this.worldContinuityState) : null,
      storyNetwork: this.storyNetworkState ? clone(this.storyNetworkState) : null,
      narrativeLedger: this.narrativeLedgerState ? clone(this.narrativeLedgerState) : null,
      karmaRipple: this.karmaRippleState ? clone(this.karmaRippleState) : null,
      heavensHint: this.heavensHintState ? clone(this.heavensHintState) : null,
      terminalContext: this.terminalContext ? clone(this.terminalContext) : null,
      lastEndingReport: this.lastEndingReport ? clone(this.lastEndingReport) : null,
      deadReason: this.deadReason || '',
      deathCauseId: this.deathCauseId || '',
      lifeArchived: Boolean(this._lifeArchived),
      archiveVersion: Math.max(0, Math.floor(Number(this.archiveVersion) || 0)),
      legacyRunState: clone(legacyRunState)
    };
    this.unlocks.pendingKarmaSeeds = (this.karmaSeeds || []).map(seed => clone(seed));
    return this._saveUnlocks();
  }

  _restoreCausalSession() {
    const snapshot = this.unlocks && this.unlocks.causalSessionState;
    if (!snapshot || typeof snapshot !== 'object') return false;
    const lifeCount = this.getLifeCount ? this.getLifeCount() : (this.unlocks.lifeCount || 0);
    if (Number(snapshot.lifeCount) !== Number(lifeCount)) {
      this.unlocks.causalSessionState = null;
      this._saveUnlocks();
      return false;
    }
    const clone = value => JSON.parse(JSON.stringify(value));
    const objectOr = (value, fallback) => (
      value && typeof value === 'object' && !Array.isArray(value) ? clone(value) : fallback
    );
    const arrayOr = (value, fallback = []) => Array.isArray(value) ? clone(value) : fallback;

    this.playerName = typeof snapshot.playerName === 'string' && snapshot.playerName
      ? snapshot.playerName
      : this.playerName;
    this.path = typeof snapshot.path === 'string' ? snapshot.path : this.path;
    this.realm = typeof snapshot.realm === 'string' ? snapshot.realm : this.realm;
    this.turn = Math.max(0, Number(snapshot.turn) || 0);
    this.runClock = this._normalizeRunClock(snapshot.runClock, {
      fallbackDecisionIndex: this.turn,
      migrationSource: snapshot.runClock ? null : 'legacy_turn'
    });
    this.maxHealth = Math.max(1, Number(snapshot.maxHealth) || this.maxHealth);
    this.maxDaoHeart = Math.max(1, Number(snapshot.maxDaoHeart) || this.maxDaoHeart);
    this.attributes = objectOr(snapshot.attributes, this.attributes);
    const restoredResources = objectOr(snapshot.resources, {});
    const causalVersion = Number.isFinite(Number(snapshot.version)) ? Number(snapshot.version) : 0;
    const restoredTreasureInstances = objectOr(snapshot.treasureInstances, null);
    this._treasureLegacyResourceFieldMissing = !Array.isArray(restoredResources.treasures);
    this._treasureOwnershipMigrationRequired = causalVersion < GameStateManager.TREASURE_OWNERSHIP_CAUSAL_VERSION
      || !restoredTreasureInstances;
    this.resources = Object.assign({}, this.resources, restoredResources, {
      spiritStone: Math.max(0, Number(
        restoredResources.spiritStone ?? this.resources.spiritStone
      ) || 0),
      lifespan: Math.max(0, Number(
        restoredResources.lifespan ?? this.resources.lifespan
      ) || 0),
      pills: objectOr(restoredResources.pills, {}),
      treasures: arrayOr(restoredResources.treasures),
      companions: arrayOr(restoredResources.companions)
    });
    this.itemInventory = objectOr(snapshot.itemInventory, {});
    this.interactionBudget = objectOr(snapshot.interactionBudget, {});
    const rawCompanionProgress = objectOr(snapshot.companionProgress, {});
    const rawCompanionStates = objectOr(rawCompanionProgress.states, {});
    const rawCompanionCooldowns = objectOr(rawCompanionProgress.cooldowns, {});
    const companionStates = {};
    const companionCooldowns = {};
    for (const [compId, rawState] of Object.entries(rawCompanionStates)) {
      if (typeof compId !== 'string' || !compId || !rawState || typeof rawState !== 'object' || Array.isArray(rawState)) {
        continue;
      }
      companionStates[compId] = {
        bond: Math.max(0, Math.min(5, Math.floor(Number(rawState.bond) || 0))),
        trust: Math.max(0, Math.min(100, Math.floor(Number(rawState.trust) || 0))),
        lastEventTurn: Math.max(0, Math.floor(Number(rawState.lastEventTurn) || 0)),
        lastCooldownTurn: Math.max(0, Math.floor(
          Number.isFinite(Number(rawState.lastCooldownTurn))
            ? Number(rawState.lastCooldownTurn)
            : (Number(snapshot.turn) || 0)
        )),
        totalEvents: Math.max(0, Math.floor(Number(rawState.totalEvents) || 0))
      };
    }
    for (const [compId, cooldown] of Object.entries(rawCompanionCooldowns)) {
      if (typeof compId !== 'string' || !compId) continue;
      companionCooldowns[compId] = Math.max(0, Math.floor(Number(cooldown) || 0));
    }
    this.companionProgress = { states: companionStates, cooldowns: companionCooldowns };
    const rawFactionProgress = objectOr(snapshot.factionProgress, {});
    const rawReputations = objectOr(rawFactionProgress.reputations, {});
    const rawUndercurrentStages = objectOr(rawFactionProgress.undercurrentStages, {});
    const rawFactionFlags = objectOr(rawFactionProgress.globalFlags, {});
    const factionReputations = {};
    const undercurrentStages = {};
    const factionFlags = {};
    for (const [factionId, reputation] of Object.entries(rawReputations)) {
      if (typeof factionId !== 'string' || !factionId || !Number.isFinite(Number(reputation))) continue;
      factionReputations[factionId] = Math.max(-100, Math.min(100, Number(reputation)));
    }
    for (const [undercurrentId, stage] of Object.entries(rawUndercurrentStages)) {
      if (typeof undercurrentId !== 'string' || !undercurrentId || !Number.isFinite(Number(stage))) continue;
      undercurrentStages[undercurrentId] = Math.max(0, Math.floor(Number(stage)));
    }
    for (const [flagId, enabled] of Object.entries(rawFactionFlags)) {
      if (typeof flagId === 'string' && flagId && enabled === true) factionFlags[flagId] = true;
    }
    this.factionProgress = {
      reputations: factionReputations,
      undercurrentStages,
      globalFlags: factionFlags,
      ticksSinceEvent: Math.max(0, Math.floor(Number(rawFactionProgress.ticksSinceEvent) || 0))
    };
    this.tradeRouteState = objectOr(snapshot.tradeRoute, null);
    this.worldPulseState = objectOr(snapshot.worldPulse, null);
    this.lineageRunStats = objectOr(snapshot.lineageRunStats, null);
    this.knowledge = objectOr(snapshot.knowledge, this.knowledge);
    if (Array.isArray(snapshot.clues)) {
      const restoredClueIds = new Set();
      this.clues = snapshot.clues
        .filter(entry => {
          if (!entry || typeof entry !== 'object' || typeof entry.id !== 'string' || !entry.id) {
            return false;
          }
          if (restoredClueIds.has(entry.id)) return false;
          restoredClueIds.add(entry.id);
          return true;
        })
        .map(entry => ({
          id: entry.id,
          source: typeof entry.source === 'string' ? entry.source : null,
          turn: Math.max(0, Number(entry.turn) || 0),
          life: Math.max(0, Number(entry.life) || 0)
        }));
    }
    this.equipment = objectOr(snapshot.equipment, this.equipment);
    this.treasureInstances = restoredTreasureInstances || {};
    this.treasureCommandReceipts = objectOr(snapshot.treasureCommandReceipts, {});
    // Old snapshots retain this field only long enough for TreasureSystem to
    // validate and migrate them after its catalog has loaded.
    this.treasureInventory = arrayOr(snapshot.treasureInventory);
    this.treasureCooldowns = objectOr(snapshot.treasureCooldowns, {});
    this.deck = arrayOr(snapshot.deck);
    this.starterDeckPath = typeof snapshot.starterDeckPath === 'string'
      ? snapshot.starterDeckPath
      : null;
    this.deckOperations = arrayOr(snapshot.deckOperations);
    this.skillAcquisitions = objectOr(snapshot.skillAcquisitions, {});
    this.skillOpportunityAttempts = objectOr(snapshot.skillOpportunityAttempts, {});
    this.opportunityAcquisitions = objectOr(snapshot.opportunityAcquisitions, {});
    this.opportunityAttempts = objectOr(snapshot.opportunityAttempts, {});
    this.modifiers = objectOr(snapshot.modifiers, {});
    this.currentLocation = typeof snapshot.currentLocation === 'string'
      ? snapshot.currentLocation
      : this.currentLocation;
    this.visitedLocations = arrayOr(snapshot.visitedLocations, [this.currentLocation]);
    this.locationStates = objectOr(snapshot.locationStates, {});
    this.worldContinuityState = snapshot.worldContinuity
      && typeof snapshot.worldContinuity === 'object'
      ? objectOr(snapshot.worldContinuity, null)
      : null;
    this.storyNetworkState = snapshot.storyNetwork
      && typeof snapshot.storyNetwork === 'object'
      ? objectOr(snapshot.storyNetwork, null)
      : null;
    this.narrativeLedgerState = snapshot.narrativeLedger
      && typeof snapshot.narrativeLedger === 'object'
      ? objectOr(snapshot.narrativeLedger, null)
      : null;
    this.karmaRippleState = snapshot.karmaRipple
      && typeof snapshot.karmaRipple === 'object'
      ? objectOr(snapshot.karmaRipple, null)
      : null;
    this.heavensHintState = snapshot.heavensHint
      && typeof snapshot.heavensHint === 'object'
      ? objectOr(snapshot.heavensHint, null)
      : null;
    this.cardsPlayed = arrayOr(snapshot.cardsPlayed);
    this.choiceHistory = arrayOr(snapshot.choiceHistory);
    this.recentCardTags = arrayOr(snapshot.recentCardTags);
    this.dungeon = typeof snapshot.dungeon === 'string' && snapshot.dungeon ? snapshot.dungeon : null;
    this.dungeonNodeIndex = Math.max(0, Math.floor(Number(snapshot.dungeonNodeIndex) || 0));
    this.dungeonNodeId = typeof snapshot.dungeonNodeId === 'string' ? snapshot.dungeonNodeId : null;
    this.dungeonPath = arrayOr(snapshot.dungeonPath);
    this.dungeonRun = snapshot.dungeonRun
      && typeof snapshot.dungeonRun === 'object'
      && !Array.isArray(snapshot.dungeonRun)
      && snapshot.dungeonRun.status === 'active'
      ? clone(snapshot.dungeonRun)
      : null;
    this.dungeonOutcomeReceipts = Array.isArray(snapshot.dungeonOutcomeReceipts)
      ? snapshot.dungeonOutcomeReceipts.filter(receipt => receipt
        && receipt.lifeId === this._lifeIdFor()
        && typeof receipt.sessionId === 'string' && receipt.sessionId
        && typeof receipt.dungeonId === 'string' && receipt.dungeonId
        && typeof receipt.sourceCardId === 'string' && receipt.sourceCardId
        && Number.isSafeInteger(receipt.sourceDecisionIndex)
        && receipt.sourceDecisionIndex >= 0
        && Number.isSafeInteger(receipt.settledDecisionIndex)
        && receipt.settledDecisionIndex >= receipt.sourceDecisionIndex
        && ['success', 'abandon', 'failure'].includes(receipt.outcome)).slice(-32).map(clone)
      : [];
    const restoredLoadoutDecision = this._normalizePendingLoadoutDecision(snapshot.pendingLoadoutDecision);
    this.pendingLoadoutDecision = restoredLoadoutDecision
      && this.treasureInstances?.[restoredLoadoutDecision.instanceId]
      ? restoredLoadoutDecision
      : null;
    this.marketState = this._normalizeMarketState(snapshot.marketState, {
      fallbackDecisionIndex: this.runClock.decisionIndex,
      migrationSource: snapshot.marketState ? null : 'legacy_clock'
    });
    // v15 and earlier owned an independent pendingVendorSession field.  Read
    // it exactly once into the v16 market domain; later snapshots never write
    // that field again, avoiding split session authority.
    if (!this.marketState.activeSession) {
      this.marketState.activeSession = this._normalizeMarketActiveSession(snapshot.pendingVendorSession);
    }
    this.pendingVendorSession = null;
    if (typeof snapshot.lifePhase === 'string' && Object.values(GameStateManager.LIFE_PHASES).includes(snapshot.lifePhase)) {
      this.lifePhase = snapshot.lifePhase;
    }
    this.endingCandidate = typeof snapshot.endingCandidate === 'string' ? snapshot.endingCandidate : null;
    this.endingId = typeof snapshot.endingId === 'string' ? snapshot.endingId : null;
    this.pendingCardId = typeof snapshot.pendingCardId === 'string' ? snapshot.pendingCardId : null;
    this.pendingConsequence = this._normalizePendingConsequence(snapshot.pendingConsequence);
    const restoredCheckpoint = snapshot.decisionCheckpoint;
    const restoredCheckpointCardId = typeof restoredCheckpoint?.cardId === 'string'
      && restoredCheckpoint.cardId
      ? restoredCheckpoint.cardId
      : null;
    const restoredCardSnapshot = restoredCheckpoint?.cardSnapshot;
    const hasNpcSelector = restoredCheckpoint
      && Object.prototype.hasOwnProperty.call(restoredCheckpoint, 'npcEncounter');
    const rawNpcSelector = restoredCheckpoint?.npcEncounter;
    const normalizedNpcSelector = hasNpcSelector
      && rawNpcSelector && typeof rawNpcSelector === 'object' && !Array.isArray(rawNpcSelector)
      && rawNpcSelector.version === 1
      && ['npcId', 'scene', 'location', 'emotion'].every(key => (
        typeof rawNpcSelector[key] === 'string' && rawNpcSelector[key].length > 0
      ))
      && typeof restoredCheckpoint.lifeId === 'string'
      && Number.isSafeInteger(restoredCheckpoint.turn) && restoredCheckpoint.turn >= 0
      && Number.isSafeInteger(restoredCheckpoint.decisionIndex) && restoredCheckpoint.decisionIndex >= 0
      ? {
          version: 1,
          npcId: rawNpcSelector.npcId, scene: rawNpcSelector.scene,
          location: rawNpcSelector.location, emotion: rawNpcSelector.emotion
        }
      : null;
    const hasWarningThreshold = restoredCheckpoint
      && Object.prototype.hasOwnProperty.call(restoredCheckpoint, 'sourceThreshold');
    const validWarningThreshold = !hasWarningThreshold
      || (/^ch_[a-z]+_\d+$/.test(restoredCheckpoint.sourceCardId || '')
        && Number.isSafeInteger(restoredCheckpoint.sourceThreshold)
        && restoredCheckpoint.sourceThreshold > 0);
    const restoredWarningDirection = restoredCheckpointCardId?.startsWith('_warning_')
      && typeof restoredCheckpoint?.sourceCardId === 'string'
      && restoredCheckpoint.sourceCardId
      && validWarningThreshold
      && ['left', 'right', 'up', 'down'].includes(restoredCheckpoint?.warningDirection)
      ? restoredCheckpoint.warningDirection
      : null;
    const restoredDirectWarningSourceId = restoredCheckpointCardId?.startsWith('_warning_')
      && !Object.prototype.hasOwnProperty.call(restoredCheckpoint, 'warningDirection')
      && typeof restoredCheckpoint?.directWarningSourceId === 'string'
      && restoredCheckpointCardId === `_warning_${restoredCheckpoint.directWarningSourceId}`
      ? restoredCheckpoint.directWarningSourceId
      : null;
    const recoverableCombatOutcomeSnapshot = restoredCardSnapshot
      && typeof restoredCardSnapshot === 'object'
      && !Array.isArray(restoredCardSnapshot)
      && restoredCardSnapshot.id === restoredCheckpointCardId
      && (
        restoredCheckpointCardId === 'combat_reward'
        || restoredCheckpointCardId?.startsWith('combat_defeat_')
        || restoredCheckpointCardId?.startsWith('combat_fled_')
      )
      && restoredCardSnapshot.type === 'NORMAL'
      && restoredCardSnapshot.choices
      && typeof restoredCardSnapshot.choices === 'object'
      && !Array.isArray(restoredCardSnapshot.choices)
      ? clone(restoredCardSnapshot)
      : null;
    const recoverableGeneratedSnapshot = restoredCardSnapshot
      && typeof restoredCardSnapshot === 'object'
      && !Array.isArray(restoredCardSnapshot)
      && restoredCardSnapshot.id === restoredCheckpointCardId
      && ((restoredCardSnapshot.type === 'KARMA_RIPPLE'
          && restoredCheckpointCardId?.startsWith('karma_ripple:'))
        || (restoredCardSnapshot.type === 'HEAVENS_HINT'
          && restoredCheckpointCardId?.startsWith('heavens_hint:')))
      && restoredCardSnapshot.choices
      && typeof restoredCardSnapshot.choices === 'object'
      && !Array.isArray(restoredCardSnapshot.choices)
      ? clone(restoredCardSnapshot)
      : null;
    this.decisionCheckpoint = restoredCheckpoint
      && typeof restoredCheckpoint === 'object'
      && !Array.isArray(restoredCheckpoint)
      ? {
          version: Math.max(1, Math.floor(Number(restoredCheckpoint.version) || 1)),
          cardId: restoredCheckpointCardId,
           turn: Math.max(0, Math.floor(Number(restoredCheckpoint.turn) || 0)),
            decisionIndex: Math.max(0, Math.floor(Number(
              restoredCheckpoint.decisionIndex ?? restoredCheckpoint.turn
            ) || 0)),
            sourceCardId: typeof restoredCheckpoint.sourceCardId === 'string'
            ? restoredCheckpoint.sourceCardId
            : null,
          ...(restoredWarningDirection
            ? { warningDirection: restoredWarningDirection }
            : {}),
          ...(restoredDirectWarningSourceId
            ? { directWarningSourceId: restoredDirectWarningSourceId }
            : {}),
          ...(restoredWarningDirection && hasWarningThreshold
            ? { sourceThreshold: restoredCheckpoint.sourceThreshold }
            : {}),
          ...(recoverableCombatOutcomeSnapshot || recoverableGeneratedSnapshot
            ? { cardSnapshot: recoverableCombatOutcomeSnapshot || recoverableGeneratedSnapshot }
            : {}),
          ...(hasNpcSelector ? { npcEncounter: normalizedNpcSelector } : {}),
          ...(hasNpcSelector || Object.prototype.hasOwnProperty.call(restoredCheckpoint, 'lifeId')
            ? { lifeId: typeof restoredCheckpoint.lifeId === 'string' ? restoredCheckpoint.lifeId : null }
            : {})
        }
      : null;
    const rawRealmTransition = objectOr(snapshot.realmTransition, null);
    const realmOrder = GameStateManager.REALM_ORDER;
    const transitionFromIndex = realmOrder.indexOf(rawRealmTransition?.from);
    const transitionToIndex = realmOrder.indexOf(rawRealmTransition?.to);
    const expectedArrivalCardId = rawRealmTransition?.to === 'foundation'
      ? 'epiphany_foundation'
      : `realm_arrival_${rawRealmTransition?.to || ''}`;
    const transitionValid = rawRealmTransition
      && Number(rawRealmTransition.version) === 1
      && typeof rawRealmTransition.id === 'string'
      && rawRealmTransition.id.length > 0
      && typeof rawRealmTransition.sourceCardId === 'string'
      && rawRealmTransition.sourceCardId.length > 0
      && Number(rawRealmTransition.lifeCount) === Number(lifeCount)
      && typeof rawRealmTransition.pathAtPromotion === 'string'
      && rawRealmTransition.pathAtPromotion === this.path
      && transitionFromIndex >= 0
      && transitionToIndex === transitionFromIndex + 1
      && rawRealmTransition.to === this.realm
      && ['inheritance_pending', 'arrival_pending'].includes(rawRealmTransition.status)
      && rawRealmTransition.arrivalCardId === expectedArrivalCardId;
    this.realmTransition = transitionValid
      ? {
          version: 1,
          id: rawRealmTransition.id,
          sourceCardId: rawRealmTransition.sourceCardId,
          lifeCount: Number(lifeCount),
          from: rawRealmTransition.from,
          to: rawRealmTransition.to,
          pathAtPromotion: rawRealmTransition.pathAtPromotion,
          status: rawRealmTransition.status,
          arrivalCardId: rawRealmTransition.arrivalCardId
        }
      : null;
    const restoredCombatSession = snapshot.combatSession;
    const combatPhase = restoredCombatSession?.phase;
    const combatOriginalCardId = restoredCombatSession?.originalCard?.id;
    const restoredReaction = restoredCombatSession?.pendingReaction;
    const reactionValid = combatPhase !== 'REACTION_OPEN' || (
      restoredReaction
      && typeof restoredReaction.windowId === 'string'
      && restoredReaction.windowId
      && Number(restoredReaction.turn) === Number(restoredCombatSession.turn)
      && restoredReaction.sourceCardId === combatOriginalCardId
      && Array.isArray(restoredReaction.options)
      && restoredReaction.options.some(option => option?.id === 'TAKE_HIT' && option.available === true)
    );
    this.combatSession = restoredCombatSession
      && typeof restoredCombatSession === 'object'
      && !Array.isArray(restoredCombatSession)
      && Number(restoredCombatSession.version) === 3
      && restoredCombatSession.active === true
      && ['PLAYER_TURN', 'REACTION_OPEN'].includes(combatPhase)
      && typeof combatOriginalCardId === 'string'
      && combatOriginalCardId
      && restoredCombatSession.originalCard?.enemy
      && restoredCombatSession.player
      && restoredCombatSession.enemy
      && reactionValid
      ? clone(restoredCombatSession)
      : null;
    this.chapterProgress = snapshot.chapterProgress
      && typeof snapshot.chapterProgress === 'object'
      && !Array.isArray(snapshot.chapterProgress)
      ? clone(snapshot.chapterProgress)
      : null;
    this.flowState = snapshot.flowState
      && typeof snapshot.flowState === 'object'
      && !Array.isArray(snapshot.flowState)
      ? clone(snapshot.flowState)
      : null;
    this.terminalContext = snapshot.terminalContext
      && typeof snapshot.terminalContext === 'object'
      && !Array.isArray(snapshot.terminalContext)
      ? clone(snapshot.terminalContext)
      : null;
    this.lastEndingReport = snapshot.lastEndingReport
      && typeof snapshot.lastEndingReport === 'object'
      && !Array.isArray(snapshot.lastEndingReport)
      ? clone(snapshot.lastEndingReport)
      : null;
    this.deadReason = typeof snapshot.deadReason === 'string' ? snapshot.deadReason : this.deadReason;
    this.deathCauseId = typeof snapshot.deathCauseId === 'string' ? snapshot.deathCauseId : this.deathCauseId;
    this.archiveVersion = Math.max(0, Math.floor(Number(snapshot.archiveVersion) || 0));
    this._lifeArchived = Boolean(snapshot.lifeArchived)
      || this.archiveVersion >= GameStateManager.LIFE_ARCHIVE_SCHEMA_VERSION;

    // v1 causal snapshots did not persist `dead`. Reconstruct the ordinary
    // death invariant from the durable phase/cause pair, while explicitly
    // preventing old mixed saves from treating an epilogue as a death.
    if (this.lifePhase === GameStateManager.LIFE_PHASES.EPILOGUE) {
      this.dead = false;
      this.deadReason = '';
      this.deathCauseId = '';
    } else if (
      this.lifePhase === GameStateManager.LIFE_PHASES.DYING_NARRATIVE
      || snapshot.dead === true
    ) {
      this.dead = true;
      this.lifePhase = GameStateManager.LIFE_PHASES.DYING_NARRATIVE;
    } else {
      this.dead = false;
    }
    return this.hasRecoverableCausalSession();
  }

  isInEnding() {
    return this.lifePhase === GameStateManager.LIFE_PHASES.EPILOGUE;
  }

  hasRecoverableCausalSession() {
    const story = this.unlocks && this.unlocks.storyThreadState;
    const sameLife = !story || Number(story.lifeCount) === Number(this.getLifeCount());
    const activeStory = sameLife && Array.isArray(story?.activeThreads)
      && story.activeThreads.length > 0;
    const pendingKarma = Array.isArray(this.karmaSeeds) && this.karmaSeeds.length > 0;
    const snapshot = this.unlocks?.causalSessionState;
    const persistedDeck = snapshot
      && Number(snapshot.lifeCount) === Number(this.getLifeCount())
      && typeof snapshot.path === 'string'
      && snapshot.path.length > 0
      && Array.isArray(snapshot.deck)
      && snapshot.deck.length > 0;
    const persistedCriticalCard = snapshot
      && Number(snapshot.lifeCount) === Number(this.getLifeCount())
      && typeof snapshot.pendingCardId === 'string'
      && snapshot.pendingCardId.length > 0;
    const persistedDecisionCard = snapshot
      && Number(snapshot.lifeCount) === Number(this.getLifeCount())
      && snapshot.decisionCheckpoint
      && typeof snapshot.decisionCheckpoint.cardId === 'string'
      && snapshot.decisionCheckpoint.cardId.length > 0;
    const marketSession = snapshot?.marketState?.activeSession || snapshot?.pendingVendorSession;
    const persistedVendorSession = snapshot
      && Number(snapshot.lifeCount) === Number(this.getLifeCount())
      && marketSession
      && (
        (marketSession.status === 'open'
          && typeof marketSession.vendorId === 'string'
          && marketSession.vendorId.length > 0)
        || (marketSession.status === 'result'
          && marketSession.resultCard
          && marketSession.resultCard.type === 'VENDOR_RESULT')
      );
    const persistedLoadoutDecision = snapshot
      && Number(snapshot.lifeCount) === Number(this.getLifeCount())
      && (() => {
        const pending = this._normalizePendingLoadoutDecision(snapshot.pendingLoadoutDecision);
        return Boolean(pending && snapshot.treasureInstances?.[pending.instanceId]);
      })();
    const persistedCombatSession = snapshot
      && Number(snapshot.lifeCount) === Number(this.getLifeCount())
      && snapshot.combatSession
      && [1, 2, 3].includes(Number(snapshot.combatSession.version))
      && snapshot.combatSession.active === true
      && ['PLAYER_TURN', 'REACTION_OPEN'].includes(snapshot.combatSession.phase)
      && typeof snapshot.combatSession.originalCard?.id === 'string';
    return Boolean(
      activeStory
      || pendingKarma
      || persistedDeck
      || persistedCriticalCard
      || (snapshot && Number(snapshot.lifeCount) === Number(this.getLifeCount())
        && this._normalizePendingConsequence(snapshot.pendingConsequence))
      || persistedDecisionCard
      || persistedVendorSession
      || persistedLoadoutDecision
      || persistedCombatSession
    );
  }

  consumeRestoredCausalSession() {
    if (!this._restoredCausalSession || !this.hasRecoverableCausalSession()) return false;
    this._restoredCausalSession = false;
    return true;
  }

  beginFreshSession() {
    this.reset(true);
    if (typeof npcSystem !== 'undefined' && typeof npcSystem.resetForNewLife === 'function') {
      npcSystem.resetForNewLife();
    }
    this.unlocks.storyThreadState = null;
    this.unlocks.causalSessionState = null;
    this._restoredCausalSession = false;
    this.unlocks.pendingKarmaSeeds = this.karmaSeeds.map(seed => Object.assign({}, seed));
    if (this.karmaSeeds.length > 0) this.persistCausalSession();
    else this._saveUnlocks();
  }

  _createDefaultLegacyArchive() {
    const fragmentsBySet = {};
    for (const setId of GameStateManager.LEGACY_SET_IDS) fragmentsBySet[setId] = 0;
    return {
      schemaVersion: GameStateManager.LEGACY_ARCHIVE_SCHEMA_VERSION,
      migrationVersion: GameStateManager.LEGACY_ARCHIVE_MIGRATION_VERSION,
      fragmentsBySet,
      completedSetIds: [],
      discoveredVariantCardIds: [],
      migrationDiagnostics: { unknownSetIds: [] }
    };
  }

  _createDefaultLegacyRunState(lifeCount = this.getLifeCount()) {
    return {
      lifeCount: Math.max(0, Math.floor(Number(lifeCount) || 0)),
      focusedSetId: null,
      activeSetIds: [],
      inheritedSetId: null,
      pendingInheritanceChoice: null,
      ordinaryMissStreak: 0,
      pendingBossFragmentReward: null,
      claimedEncounterInstanceIds: []
    };
  }

  _normalizeLegacyFragmentCount(value) {
    const rawCount = Array.isArray(value)
      ? value.filter(Boolean).length
      : Number(value);
    return Math.max(0, Math.min(8, Math.floor(Number(rawCount) || 0)));
  }

  _normalizeLegacyArchive(value) {
    const defaults = this._createDefaultLegacyArchive();
    const raw = value && typeof value === 'object' && !Array.isArray(value) ? value : {};
    const fragments = raw.fragmentsBySet && typeof raw.fragmentsBySet === 'object' && !Array.isArray(raw.fragmentsBySet)
      ? raw.fragmentsBySet
      : (raw.fragments && typeof raw.fragments === 'object' && !Array.isArray(raw.fragments) ? raw.fragments : {});
    const completed = Array.isArray(raw.completedSetIds) ? raw.completedSetIds : raw.completed;
    const knownSetIds = new Set(GameStateManager.LEGACY_SET_IDS);
    const uniqueStrings = valueToNormalize => Array.from(new Set((Array.isArray(valueToNormalize) ? valueToNormalize : [])
      .filter(item => typeof item === 'string' && item.trim())));

    for (const setId of GameStateManager.LEGACY_SET_IDS) {
      defaults.fragmentsBySet[setId] = this._normalizeLegacyFragmentCount(fragments[setId]);
    }
    defaults.completedSetIds = uniqueStrings(completed).filter(setId => knownSetIds.has(setId));
    for (const setId of defaults.completedSetIds) defaults.fragmentsBySet[setId] = 8;
    defaults.discoveredVariantCardIds = uniqueStrings(raw.discoveredVariantCardIds);
    const unknownSetIds = [
      ...Object.keys(fragments),
      ...uniqueStrings(completed),
      ...(Array.isArray(raw.migrationDiagnostics?.unknownSetIds) ? raw.migrationDiagnostics.unknownSetIds : [])
    ].filter(setId => typeof setId === 'string' && setId && !knownSetIds.has(setId));
    defaults.migrationDiagnostics.unknownSetIds = Array.from(new Set(unknownSetIds));
    return defaults;
  }

  _normalizeLegacyRunState(value, lifeCount = this.getLifeCount()) {
    const defaults = this._createDefaultLegacyRunState(lifeCount);
    const raw = value && typeof value === 'object' && !Array.isArray(value) ? value : {};
    const knownSetIds = new Set(GameStateManager.LEGACY_SET_IDS);
    const uniqueKnownSetIds = valueToNormalize => Array.from(new Set((Array.isArray(valueToNormalize) ? valueToNormalize : [])
      .filter(setId => typeof setId === 'string' && knownSetIds.has(setId))));
    const isKnownSetId = setId => typeof setId === 'string' && knownSetIds.has(setId);

    defaults.focusedSetId = isKnownSetId(raw.focusedSetId) ? raw.focusedSetId : null;
    defaults.activeSetIds = uniqueKnownSetIds(raw.activeSetIds);
    defaults.inheritedSetId = isKnownSetId(raw.inheritedSetId) ? raw.inheritedSetId : null;
    const rawPendingInheritance = raw.pendingInheritanceChoice;
    if (rawPendingInheritance
      && typeof rawPendingInheritance === 'object'
      && !Array.isArray(rawPendingInheritance)
      && Number(rawPendingInheritance.lifeCount) === Number(lifeCount)
      && ['sword', 'spell', 'body', 'pill'].includes(rawPendingInheritance.path)) {
      const candidateSetIds = uniqueKnownSetIds(rawPendingInheritance.candidateSetIds);
      if (candidateSetIds.length > 0 && !defaults.inheritedSetId) {
        defaults.pendingInheritanceChoice = {
          schemaVersion: 1,
          lifeCount: Math.max(0, Math.floor(Number(lifeCount) || 0)),
          path: rawPendingInheritance.path,
          candidateSetIds,
          createdAtTurn: Math.max(0, Math.floor(Number(rawPendingInheritance.createdAtTurn) || 0))
        };
      }
    }
    defaults.ordinaryMissStreak = Math.max(0, Math.min(7, Math.floor(Number(raw.ordinaryMissStreak) || 0)));
    const rawPendingBossReward = raw.pendingBossFragmentReward;
    if (rawPendingBossReward
      && typeof rawPendingBossReward === 'object'
      && !Array.isArray(rawPendingBossReward)
      && ['boss', 'realm_boss'].includes(rawPendingBossReward.encounterKind)
      && typeof rawPendingBossReward.encounterInstanceId === 'string'
      && rawPendingBossReward.encounterInstanceId.trim()) {
      const candidateSetIds = uniqueKnownSetIds(rawPendingBossReward.candidateSetIds).slice(0, 3);
      if (candidateSetIds.length > 0) {
        const focusedSetId = candidateSetIds.includes(rawPendingBossReward.focusedSetId)
          ? rawPendingBossReward.focusedSetId
          : null;
        const rewardPresentation = rawPendingBossReward.rewardPresentation
          && rawPendingBossReward.rewardPresentation.visualWorldId === 'cangmang_sect_pc98_v1'
          && rawPendingBossReward.rewardPresentation.uiMaterialId === 'sect_field_ledger_v1'
          && rawPendingBossReward.rewardPresentation.visualSurface === 'boss_fragment_choice'
          ? {
              visualWorldId: 'cangmang_sect_pc98_v1',
              uiMaterialId: 'sect_field_ledger_v1',
              visualSurface: 'boss_fragment_choice'
            }
          : null;
        defaults.pendingBossFragmentReward = {
          schemaVersion: 1,
          encounterInstanceId: rawPendingBossReward.encounterInstanceId.trim(),
          encounterKind: rawPendingBossReward.encounterKind,
          cardId: typeof rawPendingBossReward.cardId === 'string' ? rawPendingBossReward.cardId : null,
          realm: typeof rawPendingBossReward.realm === 'string' ? rawPendingBossReward.realm : 'qi',
          path: typeof rawPendingBossReward.path === 'string' ? rawPendingBossReward.path : null,
          focusedSetId,
          candidateSetIds,
          createdAtTurn: Math.max(0, Math.floor(Number(rawPendingBossReward.createdAtTurn) || 0)),
          ...(rewardPresentation ? { rewardPresentation } : {})
        };
      }
    }
    defaults.claimedEncounterInstanceIds = Array.from(new Set((Array.isArray(raw.claimedEncounterInstanceIds)
      ? raw.claimedEncounterInstanceIds
      : []).filter(id => typeof id === 'string' && id.trim())));
    return defaults;
  }

  getLegacyArchive() {
    const current = this.unlocks?.legacyArchive;
    const normalized = this._normalizeLegacyArchive(current);
    if (current && typeof current === 'object' && !Array.isArray(current)) {
      Object.assign(current, normalized);
      return current;
    }
    this.unlocks.legacyArchive = normalized;
    return normalized;
  }

  getLegacyRunState() {
    const lifeCount = this.getLifeCount();
    const snapshot = this.unlocks?.causalSessionState;
    if (!snapshot || typeof snapshot !== 'object' || Array.isArray(snapshot)
      || Number(snapshot.lifeCount) !== Number(lifeCount)) {
      this.unlocks.causalSessionState = {
        version: 1,
        lifeCount,
        legacyRunState: this._createDefaultLegacyRunState(lifeCount)
      };
    } else {
      const currentRunState = snapshot.legacyRunState;
      const normalizedRunState = this._normalizeLegacyRunState(currentRunState, lifeCount);
      if (currentRunState && typeof currentRunState === 'object' && !Array.isArray(currentRunState)) {
        Object.assign(currentRunState, normalizedRunState);
      } else {
        snapshot.legacyRunState = normalizedRunState;
      }
    }
    return this.unlocks.causalSessionState.legacyRunState;
  }

  resetLegacyRunState() {
    const lifeCount = this.getLifeCount();
    this.unlocks.causalSessionState = null;
    this._restoredCausalSession = false;
    return this._createDefaultLegacyRunState(lifeCount);
  }

  persistLegacyState() {
    this.getLegacyArchive();
    this.getLegacyRunState();
    // Legacy completion mutates both the durable archive and the per-life
    // causal state.  Saving unlocks alone leaves an older embedded
    // legacyRunState snapshot behind after a card-acquisition persistence.
    return this.persistCausalSession();
  }

  // === 属性操作 ===

  getAttribute(name) {
    return this.attributes[name] || 0;
  }

  getActualMaxHealth() {
    let max = this.maxHealth;
    if (typeof this._getAggregatedPassives === 'function') {
      const passives = this._getAggregatedPassives();
      if (passives.maxHp) max += passives.maxHp;
    }
    return max;
  }

  getActualMaxDaoHeart() {
    let max = this.maxDaoHeart || 10;
    if (typeof this._getAggregatedPassives === 'function') {
      const passives = this._getAggregatedPassives();
      if (passives.daoHeartPenalty) max += passives.daoHeartPenalty; // e.g. -5
    }
    return Math.max(1, max);
  }

  getAttributeMaximum(name) {
    let maxVal = 100;
    if (name === 'health') maxVal = this.getActualMaxHealth();
    if (name === 'daoHeart') maxVal = this.getActualMaxDaoHeart();
    if (name === 'aura') maxVal = this.maxAura || 10;
    if (name === 'cultivation') {
      const realmConfig = this.config.realms?.realms?.[this.realm];
      maxVal = realmConfig?.cultivationThreshold || 100;
    }
    return maxVal;
  }

  setAttribute(name, value) {
    const oldValue = this.attributes[name] || 0;
    const maxVal = this.getAttributeMaximum(name);

    const clampedValue = Math.max(0, Math.min(maxVal, value));
    const actualDelta = clampedValue - oldValue;
    this.attributes[name] = clampedValue;
    const isCapped = (clampedValue === maxVal && value >= maxVal);

    if (oldValue !== this.attributes[name]) {
      eventBus.emit('state:attributeChanged', {
        attribute: name,
        oldValue,
        newValue: this.attributes[name],
        actualDelta,
        isCapped
      });
    }
    return actualDelta;
  }

  /**
   * Non-mutating projection used by both choice preview and settlement.
   * It is the single authority for aura absorption, passive modifiers and caps.
   */
  projectAttributeChange(name, delta, snapshot = null) {
    const requestedDelta = Number(delta) || 0;
    let resolvedDelta = requestedDelta;
    const changes = [];
    let absorbedByAura = 0;
    const projectedAttributes = snapshot?.attributes || this.attributes;

    if (name === 'health' && resolvedDelta < 0) {
      const aura = Number(projectedAttributes.aura) || 0;
      if (aura > 0) {
        absorbedByAura = Math.min(aura, Math.abs(resolvedDelta));
        changes.push({
          key: 'aura',
          oldValue: aura,
          newValue: aura - absorbedByAura,
          requestedDelta: -absorbedByAura,
          resolvedDelta: -absorbedByAura,
          actualDelta: -absorbedByAura,
          maxValue: this.getAttributeMaximum('aura'),
          capped: false
        });
        resolvedDelta += absorbedByAura;
      }
    }

    // 传承与功法被动加成。道心减免只处理负向道心变化，且不改变正向恢复。
    if (typeof this._getAggregatedPassives === 'function') {
      const passives = this._getAggregatedPassives();
      if (resolvedDelta > 0 && name === 'cultivation' && passives.cultivationBonus) {
        resolvedDelta = Math.floor(resolvedDelta * (1 + passives.cultivationBonus / 100));
      }
      if (resolvedDelta < 0 && name === 'daoHeart' && passives.daoResist) {
        const resist = Math.min(80, Math.max(0, Number(passives.daoResist) || 0));
        resolvedDelta = -Math.ceil(Math.abs(resolvedDelta) * (1 - resist / 100));
      }
    }

    const oldValue = Number(projectedAttributes[name]) || 0;
    const maxValue = this.getAttributeMaximum(name);
    const unclampedValue = oldValue + resolvedDelta;
    const newValue = Math.max(0, Math.min(maxValue, unclampedValue));
    const actualDelta = newValue - oldValue;
    const primary = {
      key: name,
      oldValue,
      newValue,
      requestedDelta,
      resolvedDelta,
      actualDelta,
      maxValue,
      capped: actualDelta !== resolvedDelta,
      absorbedByAura
    };
    changes.push(primary);
    return { ...primary, changes };
  }

  addAttribute(name, delta) {
    const projection = this.projectAttributeChange(name, delta);
    for (const change of projection.changes) {
      if (change.actualDelta !== 0 || change.key === 'health') {
        this.setAttribute(change.key, change.newValue);
      }
    }
    if (projection.absorbedByAura > 0) {
      console.log(`[Aura] 罡气抵消了 ${projection.absorbedByAura} 点气血伤害，剩余真实伤害 ${Math.abs(projection.actualDelta)}`);
    }
    return projection.actualDelta;
  }

  /**
   * 结算会穿透罡气的真实伤势。
   * 战斗中的护体值/格挡属于局内资源；离场伤势必须直接落到真实气血，
   * 不能再次被常驻 aura 吸收，否则“战败固定扣血”的规则仍会失真。
   */
  applyInjury(amount, context = {}) {
    const requested = Math.max(0, Math.round(Number(amount) || 0));
    const oldValue = this.getAttribute('health');
    this.setAttribute('health', oldValue - requested);
    const applied = oldValue - this.getAttribute('health');
    if (applied > 0) {
      eventBus.emit('state:injuryApplied', {
        amount: applied,
        requested,
        source: context.source || 'unknown',
        reason: context.reason || 'injury'
      });
    }
    return applied;
  }

  getKarma() {
    return this.attributes.karmaGood - this.attributes.karmaBad;
  }

  // === 资源操作 ===

  projectResourceChange(type, delta, snapshot = null) {
    if (type !== 'spiritStone' && type !== 'lifespan') return null;
    const oldValue = Number(snapshot?.resources?.[type] ?? this.resources[type]) || 0;
    const requestedDelta = Number(delta) || 0;
    const newValue = Math.max(0, oldValue + requestedDelta);
    return {
      key: type,
      oldValue,
      newValue,
      requestedDelta,
      resolvedDelta: requestedDelta,
      actualDelta: newValue - oldValue,
      maxValue: null,
      capped: newValue !== oldValue + requestedDelta,
      changes: []
    };
  }

  addResource(type, key, delta) {
    if (type === 'pills') {
      if (!this.resources.pills || typeof this.resources.pills !== 'object'
        || Array.isArray(this.resources.pills)) {
        this.resources.pills = {};
      }
      this.resources.pills[key] = (this.resources.pills[key] || 0) + delta;
    } else if (type === 'treasures') {
      // Compatibility command only. TreasureSystem owns instance creation and
      // all loadout mutations; GameStateManager must not recreate the old
      // resources/inventory/equipment three-write path.
      if (typeof treasureSystem !== 'undefined' && typeof treasureSystem?.acquire === 'function') {
        return treasureSystem.acquire(key, { source: 'legacy_state_add_resource' }) ? 1 : 0;
      }
      return 0;
    } else if (type === 'companions') {
      if (!Array.isArray(this.resources.companions)) this.resources.companions = [];
      if (!this.resources.companions.includes(key)) {
        this.resources.companions.push(key);
        eventBus.emit('state:companionGained', { companion: key });
      }
    } else if (type === 'spiritStone') {
      const projection = this.projectResourceChange(type, delta);
      this.resources.spiritStone = projection.newValue;
      return projection.actualDelta;
    } else if (type === 'lifespan') {
      const projection = this.projectResourceChange(type, delta);
      this.resources.lifespan = projection.newValue;
      return projection.actualDelta;
    }
    return 0;
  }

  hasResource(type, key) {
    if (type === 'pill') return (this.resources.pills[key] || 0) > 0;
    if (type === 'treasure') return this.resources.treasures.includes(key);
    if (type === 'companion') return this.resources.companions.includes(key);
    return false;
  }

  consumeResource(type, key) {
    if (type === 'pill' && this.resources.pills[key]) {
      this.resources.pills[key]--;
      if (this.resources.pills[key] <= 0) delete this.resources.pills[key];
      return true;
    }
    if (type === 'treasure') {
      if (typeof treasureSystem !== 'undefined' && typeof treasureSystem?.remove === 'function') {
        return treasureSystem.remove(key, this, { source: 'legacy_state_consume_resource' });
      }
      return false;
    }
    return false;
  }

  getItemCount(itemId) {
    if (typeof itemId !== 'string' || !itemId) return 0;
    return Math.max(0, Math.floor(Number(this.itemInventory?.[itemId]) || 0));
  }

  addItem(itemId, quantity = 1) {
    const amount = Math.floor(Number(quantity) || 0);
    if (typeof itemId !== 'string' || !itemId || amount <= 0) return false;
    if (!this.itemInventory || typeof this.itemInventory !== 'object') this.itemInventory = {};
    this.itemInventory[itemId] = this.getItemCount(itemId) + amount;
    eventBus.emit('state:itemInventoryChanged', {
      itemId,
      quantity: this.itemInventory[itemId],
      delta: amount
    });
    return true;
  }

  consumeItem(itemId, quantity = 1) {
    const amount = Math.floor(Number(quantity) || 0);
    const current = this.getItemCount(itemId);
    if (amount <= 0 || current < amount) return false;
    const next = current - amount;
    if (next > 0) this.itemInventory[itemId] = next;
    else delete this.itemInventory[itemId];
    eventBus.emit('state:itemInventoryChanged', { itemId, quantity: next, delta: -amount });
    return true;
  }

  hasInteractionBudget(npcId, turn = this.turn) {
    const turnKey = String(Math.max(0, Math.floor(Number(turn) || 0)));
    return Boolean(this.interactionBudget?.[npcId]?.[turnKey]);
  }

  consumeInteractionBudget(npcId, action, turn = this.turn) {
    if (typeof npcId !== 'string' || !npcId || this.hasInteractionBudget(npcId, turn)) return false;
    const turnKey = String(Math.max(0, Math.floor(Number(turn) || 0)));
    if (!this.interactionBudget || typeof this.interactionBudget !== 'object') this.interactionBudget = {};
    const current = this.interactionBudget[npcId] && typeof this.interactionBudget[npcId] === 'object'
      ? this.interactionBudget[npcId]
      : {};
    // 仅保留当前回合，防止长局无限增长；历史行为已由 NPC memory 保存。
    this.interactionBudget[npcId] = {
      [turnKey]: { action: String(action || ''), consumedAtTurn: Number(turnKey) }
    };
    eventBus.emit('state:interactionBudgetChanged', {
      npcId,
      turn: Number(turnKey),
      action: String(action || ''),
      previous: current
    });
    return true;
  }

  // === Flags 系统（跨轮次持久化的游戏标记） ===

  /**
   * 设置 flag
   * @param {string} key
   * @param {*} value
   */
  setFlag(key, value) {
    const oldValue = this.flags[key];
    this.flags[key] = value;
    if (oldValue !== value) {
      eventBus.emit('state:flagChanged', { key, oldValue, newValue: value });
    }
    // game_ended 是单局生命周期状态，绝不能写入跨世存档。
    if (key !== 'game_ended' && this.unlocks) {
      this.unlocks.flags = Object.assign({}, this.flags);
    }
  }

  clearFlag(key) {
    if (!Object.prototype.hasOwnProperty.call(this.flags, key)) return;
    const oldValue = this.flags[key];
    delete this.flags[key];
    if (key !== 'game_ended' && this.unlocks) {
      this.unlocks.flags = Object.assign({}, this.flags);
    }
    eventBus.emit('state:flagChanged', { key, oldValue, newValue: undefined });
  }

  transitionLifePhase(nextPhase, meta = {}) {
    if (!Object.values(GameStateManager.LIFE_PHASES).includes(nextPhase)) {
      console.warn('[GameState] ignored unknown life phase:', nextPhase);
      return false;
    }
    const previous = this.lifePhase;
    if (previous === nextPhase) return true;
    this.lifePhase = nextPhase;
    eventBus.emit('state:lifePhaseChanged', { previous, current: nextPhase, ...meta });
    return true;
  }

  setEndingCandidate(endingId) {
    const normalized = typeof endingId === 'string' && endingId.trim()
      ? endingId.trim()
      : null;
    if (!normalized) return false;
    this.endingCandidate = normalized;
    this.persistCausalSession();
    eventBus.emit('state:endingCandidateChanged', { endingId: normalized });
    return true;
  }

  getTerminalContext() {
    return this.terminalContext;
  }

  beginTerminalVictory(context = {}) {
    const gateId = typeof context.gateId === 'string' ? context.gateId : '';
    const encounterId = typeof context.encounterId === 'string' ? context.encounterId : '';
    const encounterInstanceId = typeof context.encounterInstanceId === 'string'
      ? context.encounterInstanceId
      : '';
    const victoryToken = typeof context.victoryToken === 'string' ? context.victoryToken : '';
    const eligibilitySnapshot = context.eligibilitySnapshot
      && typeof context.eligibilitySnapshot === 'object'
      && !Array.isArray(context.eligibilitySnapshot)
      ? JSON.parse(JSON.stringify(context.eligibilitySnapshot))
      : null;
    if (!gateId || !encounterId || !encounterInstanceId || !victoryToken || context.outcome !== 'victory') {
      return false;
    }
    if (this.terminalContext) return false;
    // Freeze only the current-life receipt accepted by StoryThreadEngine. The
    // caller cannot supply a narrative claim alongside the victory token.
    const testimonyId = 'tribulation_gate_testimony';
    const currentLifeThreadState = this.unlocks?.storyThreadState;
    const verifiedTestimony = typeof gameState !== 'undefined' && gameState === this
      && typeof threadEngine !== 'undefined'
      && typeof threadEngine?.getCompletionReceipt === 'function'
      && Number(currentLifeThreadState?.lifeCount) === Number(this.getLifeCount())
      ? threadEngine.getCompletionReceipt(testimonyId)
      : null;
    const persistedTestimony = currentLifeThreadState?.completionReceipts?.[testimonyId];
    const tribulationTestimonyReceipt = verifiedTestimony && persistedTestimony
      && JSON.stringify(verifiedTestimony) === JSON.stringify(persistedTestimony)
      && verifiedTestimony.completedTurn <= this.getCausalDecisionIndex()
      ? JSON.parse(JSON.stringify(verifiedTestimony))
      : null;
    const previousPendingCardId = this.pendingCardId;
    this.terminalContext = {
      gateId,
      encounterId,
      encounterInstanceId,
      victoryToken,
      outcome: 'victory',
      stage: 'REWARD_PENDING',
      consumed: false,
      eligibilitySnapshot,
      tribulationTestimonyReceipt
    };
    this.pendingCardId = 'breakthrough_reward';
    if (this.persistCausalSession() !== true) {
      this.terminalContext = null;
      this.pendingCardId = previousPendingCardId;
      return false;
    }
    eventBus.emit('state:terminalVictoryPending', { ...this.terminalContext });
    return true;
  }

  isTerminalRewardPending() {
    return Boolean(
      this.terminalContext
      && this.terminalContext.stage === 'REWARD_PENDING'
      && this.terminalContext.consumed === false
      && this.pendingCardId === 'breakthrough_reward'
    );
  }

  commitTerminalEnding({ endingId, pendingCardId, victoryToken, report = null } = {}) {
    const context = this.terminalContext;
    if (!context
      || context.stage !== 'REWARD_PENDING'
      || context.consumed !== false
      || context.victoryToken !== victoryToken
      || typeof endingId !== 'string'
      || typeof pendingCardId !== 'string') {
      return false;
    }
    this.endingId = endingId;
    this.pendingCardId = pendingCardId;
    this.lastEndingReport = report;
    this.dead = false;
    this.deathCauseId = '';
    this.terminalContext = {
      ...context,
      stage: 'EPILOGUE',
      consumed: true,
      endingId
    };
    this.transitionLifePhase(GameStateManager.LIFE_PHASES.EPILOGUE, { ending: endingId });
    this.setFlag('game_ended', true);
    this.unlock('ending', endingId);
    this.persistCausalSession();
    eventBus.emit('state:terminalEndingCommitted', {
      endingId,
      pendingCardId,
      victoryToken
    });
    return true;
  }

  continueAfterEnding({ pendingCardId = null } = {}) {
    if (this.lifePhase !== GameStateManager.LIFE_PHASES.EPILOGUE || !this.endingId) return false;
    if (this.terminalContext) {
      this.terminalContext = {
        ...this.terminalContext,
        stage: 'UPPER_REALM',
        consumed: true
      };
    }
    this.pendingCardId = typeof pendingCardId === 'string' ? pendingCardId : null;
    this.clearFlag('game_ended');
    this.transitionLifePhase(GameStateManager.LIFE_PHASES.ALIVE, { reason: 'continue_post_ascension' });
    return true;
  }

  prepareReincarnationHandoff(cardId = 'rebirth_boon', reason = 'reincarnation') {
    this.endingCandidate = null;
    this.endingId = null;
    this.terminalContext = null;
    this.lastEndingReport = null;
    this.pendingCardId = cardId;
    this.transitionLifePhase(GameStateManager.LIFE_PHASES.LEGACY_CHOICE, {
      reason
    });
    this.persistCausalSession();
    return true;
  }

  prepareEndingReincarnationHandoff(cardId = 'rebirth_boon') {
    return this.prepareReincarnationHandoff(cardId, 'ending_reincarnation');
  }

  addModifier(name, delta) {
    const amount = Number(delta);
    if (!Number.isFinite(amount)) return false;
    const oldValue = Number(this.modifiers[name]) || 0;
    this.modifiers[name] = oldValue + amount;
    eventBus.emit('state:modifierChanged', {
      modifier: name,
      oldValue,
      newValue: this.modifiers[name]
    });
    return true;
  }

  addKnowledge(topic, amount = 1) {
    const key = String(topic || 'general');
    const delta = Number(amount);
    if (!Number.isFinite(delta)) return false;
    this.knowledge[key] = (Number(this.knowledge[key]) || 0) + delta;
    eventBus.emit('state:knowledgeChanged', { topic: key, value: this.knowledge[key] });
    return true;
  }

  addClue(clueId, source = null) {
    if (!clueId) return false;
    if (this.clues.some(entry => entry.id === clueId)) return false;
    const clue = { id: clueId, source, turn: this.turn, life: this.getLifeCount() };
    this.clues.push(clue);
    eventBus.emit('state:clueGained', clue);
    return true;
  }

  /**
   * 获取 flag
   * @param {string} key
   * @param {*} defaultValue
   * @returns {*}
   */
  getFlag(key, defaultValue) {
    return Object.prototype.hasOwnProperty.call(this.flags, key)
      ? this.flags[key]
      : defaultValue;
  }

  /**
   * 检查 flag 是否存在且为真
   * @param {string} key
   * @returns {boolean}
   */
  hasFlag(key) {
    return Object.prototype.hasOwnProperty.call(this.flags, key)
      && Boolean(this.flags[key]);
  }

  /**
   * 检查 flag 键是否存在（允许值为 false / 0）。
   * 仅供“只检查是否曾写入”这类条件使用。
   * @param {string} key
   * @returns {boolean}
   */
  hasFlagEntry(key) {
    return Object.prototype.hasOwnProperty.call(this.flags, key);
  }

  /**
   * 批量检查多个 flag
   * @param {Object} required - { key: expectedValue }，值为 null 表示只检查存在
   * @returns {boolean}
   */
  checkFlags(required) {
    if (!required) return true;
    for (const [key, value] of Object.entries(required)) {
      if (value === null) {
        if (!this.hasFlagEntry(key)) return false;
      } else {
        if (this.getFlag(key) !== value) return false;
      }
    }
    return true;
  }

  setDeath(reason, causeId = null) {
    this.dead = true;
    this.deadReason = reason || '仙途未竟';
    if (causeId) {
      this.deathCauseId = causeId;
    }
    this.dungeon = null;
    this.dungeonNodeIndex = 0;
    this.dungeonNodeId = null;
    this.transitionLifePhase(GameStateManager.LIFE_PHASES.DYING_NARRATIVE, {
      reason: this.deadReason,
      causeId: this.deathCauseId
    });
    console.log(`[setDeath] 确认死亡 dead=true causeId=${this.deathCauseId} reason=${this.deadReason}`);
    eventBus.emit('state:death', { reason: this.deadReason, causeId: this.deathCauseId });
  }

  // === 死亡检测（升级：增加复活法宝拦截） ===

  checkDeath() {
    if (this.godMode && this.godMode.invincible) {
      console.log('[checkDeath] 🛡️ 天命无敌模式开启，判定免死');
      return false;
    }
    if (this.dead) return true;

    const checks = [
      { name: 'daoHeart', min: 0, reason: '道心崩碎，走火入魔', causeId: 'death_dao_collapse' },
      { name: 'health', min: 0, reason: '气血耗尽，身死道消', causeId: 'death_blood_loss' }
    ];

    let deathItem = null;
    for (const c of checks) {
      if (this.attributes[c.name] <= 0) {
        deathItem = c;
        break;
      }
    }

    if (!deathItem && this.resources.lifespan <= 0) {
      deathItem = { reason: '寿元耗尽，坐化而终', causeId: 'death_lifespan' };
    }

    if (deathItem) {
      const deathReason = deathItem.reason;
      const causeId = deathItem.causeId;
      // 【诊断日志】触发死亡判定
      console.log(`[checkDeath] 触发死亡 causeId=${causeId} reason=${deathReason} hp=${this.attributes.health} daoHeart=${this.attributes.daoHeart} lifespan=${this.resources.lifespan}`);

      // === 燃血续命 (Burn Blood) ===
      if (deathReason === '气血耗尽，身死道消') {
        if (this.maxHealth > 1 && this.maxDaoHeart > 1) {
          this.maxHealth -= 1;
          this.maxDaoHeart -= 1;
          this.attributes.health = 1;
          this.attributes.daoHeart = Math.min(this.maxDaoHeart, this.attributes.daoHeart);
          console.log(`[checkDeath] 触发燃血续命成功 HP上限减至 ${this.maxHealth}, 道心上限减至 ${this.maxDaoHeart}`);

          eventBus.emit('state:burnBlood', {
            maxHealth: this.maxHealth,
            maxDaoHeart: this.maxDaoHeart,
            health: this.attributes.health,
            daoHeart: this.attributes.daoHeart
          });

          // 广播属性变动事件以更新UI
          eventBus.emit('state:attributeChanged', { attribute: 'health', oldValue: 0, newValue: 1 });
          eventBus.emit('state:attributeChanged', { attribute: 'daoHeart', oldValue: this.attributes.daoHeart, newValue: this.attributes.daoHeart });
          return false; // 成功苟活，不判定死亡
        }
      }

      // === 复活法宝拦截 (P0) ===
      const revived = this._tryReviveByArtifact(deathReason);
      if (revived) {
        console.log(`[checkDeath] 复活成功，deathReason=${deathReason} 已拦截`);
        return false; // 复活成功，不死亡
      }

      this.dead = true;
      this.deadReason = deathReason;
      this.deathCauseId = causeId;
      this.dungeon = null;
      this.dungeonNodeIndex = 0;
      this.dungeonNodeId = null;
      this.transitionLifePhase(GameStateManager.LIFE_PHASES.DYING_NARRATIVE, { reason: deathReason, causeId });
      console.log(`[checkDeath] 死亡确认 dead=true causeId=${causeId} reason=${deathReason}，emit state:death`);
      eventBus.emit('state:death', { reason: deathReason, causeId });
      return true;
    }

    return false;
  }

  /**
   * 尝试使用装备中的复活法宝
   * @param {string} reason - 死亡原因
   * @returns {boolean} 是否复活成功
   */
  _tryReviveByArtifact(deathReason) {
    const artifactId = this.equipment.artifact;
    if (!artifactId) {
      console.log(`[revive] 无装备法宝，跳过复活判定`);
      return false;
    }

    console.log(`[revive] 检查法宝 artifactId=${artifactId} 是否可复活 reason=${deathReason}`);

    // 检查秘宝槽中的法宝是否有复活效果
    if (typeof treasureSystem !== 'undefined' && treasureSystem) {
      const treasure = treasureSystem.getTreasureData(artifactId);
      if (treasure && treasure.revive) {
        console.log(`[revive] 法宝 ${treasure.name} 有复活效果 type=${treasure.revive.type}，执行复活`);
        // 执行复活逻辑
        const result = treasureSystem.executeRevive(artifactId, this, deathReason);
        if (result.success) {
          console.log(`[revive] 复活成功 effect=${result.effect} hpAfter=${this.attributes.health}`);
          eventBus.emit('treasure:revive', {
            treasureId: artifactId,
            treasureName: treasure.name,
            effect: result.effect
          });
          return true;
        } else {
          console.log(`[revive] ⚠️ 复活失败 result.success=false`);
        }
      } else {
        console.log(`[revive] 法宝 ${artifactId} 无 revive 字段或数据不存在`);
      }
    } else {
      console.log(`[revive] treasureSystem 未加载，跳过复活判定`);
    }
    return false;
  }

  // === 境界突破检测 ===

  checkBreakthrough() {
    const realmOrder = this.config.realms ? (this.config.realms.order || ['qi', 'foundation', 'golden', 'nascent', 'deity', 'tribulation']) : ['qi', 'foundation', 'golden', 'nascent', 'deity', 'tribulation'];
    const realmsMap = this.config.realms ? (this.config.realms.realms || this.config.realms) : null;
    const realmConfig = (realmsMap && realmsMap[this.realm]) ? realmsMap[this.realm] : null;

    if (!realmConfig) return null;

    if (this.attributes.cultivation >= realmConfig.cultivationThreshold) {
      return realmConfig.breakthroughCard;
    }
    return null;
  }

  // === 解锁系统 ===

  unlock(key, value) {
    if (key === 'card' && !this.unlocks.cards.includes(value)) {
      this.unlocks.cards.push(value);
    }
    if (key === 'ending' && !this.unlocks.endings.includes(value)) {
      this.unlocks.endings.push(value);
    }
    if (key === 'realm' && !this.unlocks.realms.includes(value)) {
      this.unlocks.realms.push(value);
    }
    this._saveUnlocks();
  }

  // === 获取名字 ===

  getPathName(path) {
    if (!path) return '未选';
    if (this.config.paths && this.config.paths.paths[path]) {
      return this.config.paths.paths[path].name;
    }
    const names = {
      sword: '剑修', spell: '法修', body: '体修', pill: '丹修',
      array: '阵修', talisman: '符修'
    };
    return names[path] || path;
  }

  getRealmName(realm) {
    const r = realm || this.realm;
    if (this.config.realms && this.config.realms.realms[r]) {
      return this.config.realms.realms[r].name;
    }
    const names = {
      qi: '炼气期', foundation: '筑基期', golden: '金丹期',
      nascent: '元婴期', deity: '化神期', tribulation: '渡劫期'
    };
    return names[r] || r;
  }

  // === 转世系统 ===

  /**
   * 获取当前转世次数（第几世）
   */
  getLifeCount() {
    return this.unlocks.lifeCount || 0;
  }

  /**
   * 转世次数+1
   */
  incrementLife() {
    this.unlocks.lifeCount = (this.unlocks.lifeCount || 0) + 1;
    this.resetLegacyRunState();
  }

  /**
   * 在转世前记录跨世遗产，保存到 unlocks.legacy 中
   * 在 reset() 之前调用，将当前世的记忆存入持久化。
   */
  recordLegacy() {
    if (this._lifeArchived) {
      console.log('[recordLegacy] 当世遗产已完成归档，跳过重复结算');
      return false;
    }
    this._lifeArchived = true;
    this.archiveVersion = GameStateManager.LIFE_ARCHIVE_SCHEMA_VERSION;
    const legacy = this.unlocks.legacy;

    // 记录 NPC 好感
    if (typeof npcSystem !== 'undefined' && npcSystem && npcSystem.affections) {
      const affections = npcSystem.affections;
      for (const [npcId, affection] of Object.entries(affections)) {
        const prev = legacy.npcAffections[npcId] || 0;
        // 轮回树只改善既有衰减公式；最高保留 70%，不产生额外好感。
        const retentionBonus = typeof lineageSystem !== 'undefined' && lineageSystem
          ? Number(lineageSystem.getEffectValue?.('affectionRetention')) || 0
          : 0;
        const retentionRate = Math.min(0.7, 0.5 + Math.max(0, retentionBonus));
        const decayed = affection * retentionRate;
        legacy.npcAffections[npcId] = Math.max(prev, decayed);
      }
    }

    // 记录势力声望
    if (typeof factionSystem !== 'undefined' && factionSystem) {
      for (const [factionId, rep] of Object.entries(factionSystem.reputations || {})) {
        const prev = legacy.factionReputations[factionId] || 0;
        // 声望跨世衰减 40%，保留大局印象
        const decayed = Math.round(rep * 0.6);
        // 正向声望取 max（保留好印象的峰值），负向声望取 min（保留坏印象的谷值）
        if (decayed >= 0) {
          legacy.factionReputations[factionId] = Math.max(prev, decayed);
        } else {
          legacy.factionReputations[factionId] = Math.min(prev, decayed);
        }
      }
    }

    // 记录完成的支线（不衰减，永久标记）
    if (this.flags) {
      for (const [key, value] of Object.entries(this.flags)) {
        if (key.endsWith('Completed') && value && !legacy.completedQuests.includes(key)) {
          legacy.completedQuests.push(key);
        }
      }
    }

    // 记录当前功法的熟练度
    if (this.path) {
      const prev = legacy.pathMemories[this.path] || 0;
      const memoryBonus = typeof lineageSystem !== 'undefined' && lineageSystem
        ? Math.max(0, Math.floor(Number(lineageSystem.getEffectValue?.('pathMemoryGain')) || 0))
        : 0;
      const newMastery = prev + 1 + memoryBonus;
      legacy.pathMemories[this.path] = Math.min(newMastery, 5); // 最高5级熟练度
    }

    legacy.knowledge = Object.assign({}, legacy.knowledge || {}, this.knowledge || {});
    legacy.pathArchetypes = Object.assign({}, legacy.pathArchetypes || {}, this.pathArchetypes || {});
    const clueIds = new Set([...(legacy.clues || []), ...(this.clues || []).map(clue => clue.id)]);
    legacy.clues = Array.from(clueIds);
    return true;
  }

  /**
   * 获取跨世 NPC 好感遗产
   * @param {string} npcId
   * @returns {number} 前世累积的衰减后好感
   */
  getLegacyAffection(npcId) {
    return this.unlocks.legacy?.npcAffections?.[npcId] || 0;
  }

  /**
   * 获取跨世势力声望遗产
   * @param {string} factionId
   * @returns {number}
   */
  getLegacyReputation(factionId) {
    return this.unlocks.legacy?.factionReputations?.[factionId] || 0;
  }

  /**
   * 获取跨世功法熟练度
   * @returns {number} 0-5
   */
  getPathMastery() {
    if (!this.path) return 0;
    const memories = this.unlocks.legacy?.pathMemories || {};
    const own = Number(memories[this.path]) || 0;
    const translationRate = typeof lineageSystem !== 'undefined' && lineageSystem
      ? Math.min(0.5, Math.max(0, Number(lineageSystem.getEffectValue?.('crossPathMemoryRate')) || 0))
      : 0;
    if (translationRate <= 0) return own;
    const strongestOtherPath = Math.max(
      0,
      ...Object.entries(memories)
        .filter(([pathId]) => pathId !== this.path)
        .map(([, value]) => Number(value) || 0)
    );
    return Math.min(5, own + Math.floor(strongestOtherPath * translationRate));
  }

  // === 持久化 ===

  _normalizeQuestState(raw) {
    const source = raw && typeof raw === 'object' && !Array.isArray(raw) ? raw : {};
    const activeQuests = (Array.isArray(source.activeQuests)
      ? source.activeQuests
      : (source.activeQuest ? [source.activeQuest] : []))
      .filter(item => item && typeof (item.questId || item.id) === 'string')
      .map(item => ({
        questId: item.questId || item.id,
        step: Math.max(0, Math.floor(Number(item.step) || 0)),
        startedAt: Math.max(0, Number(item.startedAt) || 0)
      }));
    const completedQuests = Array.from(new Set(
      (Array.isArray(source.completedQuests) ? source.completedQuests : [])
        .filter(id => typeof id === 'string' && id)
    ));
    const closedQuests = Array.from(new Set(
      (Array.isArray(source.closedQuests) ? source.closedQuests : [])
        .filter(id => typeof id === 'string' && id)
    ));
    const questOutcomes = {};
    if (source.questOutcomes && typeof source.questOutcomes === 'object' && !Array.isArray(source.questOutcomes)) {
      for (const [questId, outcome] of Object.entries(source.questOutcomes)) {
        if (typeof questId !== 'string' || !questId) continue;
        if (!['completed', 'failed', 'abandoned'].includes(outcome)) continue;
        questOutcomes[questId] = outcome;
      }
    }
    return {
      saveVersion: GameStateManager.QUEST_STATE_SCHEMA_VERSION,
      activeQuests,
      completedQuests,
      closedQuests,
      questOutcomes
    };
  }

  getQuestState() {
    if (!this.unlocks || this.unlocks.questState === null) return null;
    return JSON.parse(JSON.stringify(this._normalizeQuestState(this.unlocks.questState)));
  }

  persistQuestState(questState) {
    if (!this.unlocks) return false;
    this.unlocks.questState = this._normalizeQuestState(questState);
    if (this._causalTransaction) {
      this._causalTransaction.deferredWrites += 1;
      return true;
    }
    return this._saveUnlocks();
  }

  _isValidSaveSlotId(slotId) {
    return GameStateManager.SAVE_SLOT_IDS.includes(slotId);
  }

  _getSaveSlotStorageKey(slotId = this.activeSaveSlotId) {
    const normalized = this._isValidSaveSlotId(slotId) ? slotId : 'slot_1';
    return GameStateManager.SAVE_SLOT_STORAGE_KEYS[normalized];
  }

  _getSaveSlotCorruptBackupKey(slotId = this.activeSaveSlotId) {
    return `${this._getSaveSlotStorageKey(slotId)}_corrupt_backup`;
  }

  _getDefaultSaveSlotLabel(slotId) {
    const labels = {
      slot_1: '一号玉简',
      slot_2: '二号玉简',
      slot_3: '三号玉简'
    };
    return labels[slotId] || labels.slot_1;
  }

  _loadActiveSaveSlotId() {
    try {
      const stored = localStorage.getItem(GameStateManager.ACTIVE_SAVE_SLOT_STORAGE_KEY);
      if (this._isValidSaveSlotId(stored)) return stored;
    } catch (_) {}
    return 'slot_1';
  }

  getActiveSaveSlotId() {
    return this.activeSaveSlotId;
  }

  _normalizeSaveSlotMeta(raw, slotId) {
    const source = raw && typeof raw === 'object' && !Array.isArray(raw) ? raw : {};
    const label = typeof source.label === 'string' && source.label.trim()
      ? source.label.trim().slice(0, 12)
      : this._getDefaultSaveSlotLabel(slotId);
    return {
      version: GameStateManager.SAVE_SLOT_SCHEMA_VERSION,
      id: slotId,
      label
    };
  }

  _createDefaultUnlocks(slotId = this.activeSaveSlotId || 'slot_1') {
    const normalizedSlotId = this._isValidSaveSlotId(slotId) ? slotId : 'slot_1';
    return {
      saveVersion: GameStateManager.SAVE_SCHEMA_VERSION,
      saveSlot: this._normalizeSaveSlotMeta(null, normalizedSlotId),
      paths: ['sword', 'spell', 'body', 'pill'],
      realms: ['qi'],
      cards: [],
      endings: [],
      flags: {},
      pendingKarmaSeeds: [],
      storyThreadState: null,
      causalSessionState: null,
      // null 表示旧存档尚未完成 Quest sidecar 迁移；明确的空对象表示该玉简
      // 已初始化且当前没有任务。QuestSystem 依此区分“需要迁移”和“确实为空”。
      questState: null,
      legacyArchive: this._createDefaultLegacyArchive(),
      bonuses: {
        startCultivation: 0, startSpiritStone: 0, maxLifespan: 0,
        daoHeart: 0, fortune: 0, maxHp: 0, karmaGood: 0, karmaBad: 0
      },
      lifeCount: 0,
      legacy: {
        npcAffections: {}, factionReputations: {}, pathMemories: {}, completedQuests: [],
        knowledge: {}, clues: [], pathArchetypes: {}, lineage: [],
        rebirthTree: { version: 1, insight: 0, spentInsight: 0, unlockedNodeIds: [] },
        companionCosmetics: { selectedPortraitByNpc: {} }
      }
    };
  }

  _stableCombatAuthoritySerialize(value) {
    if (value === null || typeof value !== 'object') return JSON.stringify(value);
    if (Array.isArray(value)) {
      return `[${value.map(item => this._stableCombatAuthoritySerialize(item)).join(',')}]`;
    }
    return `{${Object.keys(value).sort().map(key =>
      `${JSON.stringify(key)}:${this._stableCombatAuthoritySerialize(value[key])}`
    ).join(',')}}`;
  }

  _migrateUnlocks(raw, slotId = this.activeSaveSlotId || 'slot_1') {
    const normalizedSlotId = this._isValidSaveSlotId(slotId) ? slotId : 'slot_1';
    const defaults = this._createDefaultUnlocks(normalizedSlotId);
    const parsed = raw && typeof raw === 'object' && !Array.isArray(raw) ? raw : {};
    const fromVersion = Number.isFinite(Number(parsed.saveVersion)) ? Number(parsed.saveVersion) : 0;
    parsed.saveSlot = this._normalizeSaveSlotMeta(parsed.saveSlot, normalizedSlotId);
    parsed.bonuses = Object.assign({}, defaults.bonuses, parsed.bonuses || {});

    // v0/v1 使用百点制转世气血与道心加成。只缩放明显超出微数值范围的值，
    // 已经由新版本产生的 1～3 点加成保持不变。
    if (fromVersion < 2) {
      const migrateMicroBonus = value => {
        const numeric = Math.max(0, Number(value) || 0);
        return numeric > 3 ? Math.min(3, Math.max(1, Math.ceil(numeric / 10))) : numeric;
      };
      parsed.bonuses.maxHp = migrateMicroBonus(parsed.bonuses.maxHp);
      parsed.bonuses.daoHeart = migrateMicroBonus(parsed.bonuses.daoHeart);
    }

    const uniqueStrings = value => Array.from(new Set((Array.isArray(value) ? value : [])
      .filter(item => typeof item === 'string' && item.trim())));
    parsed.paths = uniqueStrings(parsed.paths);
    if (parsed.paths.length === 0) parsed.paths = [...defaults.paths];
    parsed.realms = uniqueStrings(parsed.realms);
    if (parsed.realms.length === 0) parsed.realms = ['qi'];
    parsed.cards = uniqueStrings(parsed.cards);
    parsed.endings = uniqueStrings(parsed.endings);
    parsed.flags = parsed.flags && typeof parsed.flags === 'object' ? parsed.flags : {};
    parsed.pendingKarmaSeeds = (Array.isArray(parsed.pendingKarmaSeeds) ? parsed.pendingKarmaSeeds : [])
      .filter(seed => seed && typeof seed === 'object' && typeof seed.id === 'string')
      .map(seed => Object.assign({}, seed));
    parsed.storyThreadState = parsed.storyThreadState && typeof parsed.storyThreadState === 'object'
      && !Array.isArray(parsed.storyThreadState)
      ? parsed.storyThreadState
      : null;
    parsed.causalSessionState = parsed.causalSessionState
      && typeof parsed.causalSessionState === 'object'
      && !Array.isArray(parsed.causalSessionState)
      ? parsed.causalSessionState
      : null;
    const storedCombat = parsed.causalSessionState?.combatSession;
    const storedOwner = storedCombat?.encounterContext?.encounterInstanceId;
    const cardId = storedCombat?.originalCard?.id;
    const lifeCount = Math.max(0, Math.floor(Number(parsed.causalSessionState?.lifeCount) || 0));
    const turn = Math.max(0, Math.floor(Number(parsed.causalSessionState?.turn) || 0));
    const canonicalOwner = typeof cardId === 'string' && cardId
      ? `enc:${lifeCount}:${turn}:${cardId}:1`
      : null;
    // Local JSON cannot prove that it genuinely came from an older writer. Never
    // rewrite an exactly-once owner or authorize legacy combat from client-authored
    // version fields: discard only the in-flight battle and preserve the run.
    if (storedCombat && (
      Number(storedCombat.version) !== 3
      || !canonicalOwner
      || storedOwner !== canonicalOwner
    )) {
      parsed.causalSessionState.combatSession = null;
    }
    parsed.questState = Object.prototype.hasOwnProperty.call(parsed, 'questState')
      ? this._normalizeQuestState(parsed.questState)
      : null;
    parsed.lifeCount = Math.max(0, Math.floor(Number(parsed.lifeCount) || 0));

    const legacyArchiveSource = parsed.legacyArchive
      || (parsed.legacy && typeof parsed.legacy === 'object' ? {
        fragments: parsed.legacy.fragments,
        completed: parsed.legacy.completed
      } : null);
    const legacyArchive = this._normalizeLegacyArchive(legacyArchiveSource);
    const legacyCardIds = [
      ...(parsed.cards || []),
      ...(Array.isArray(parsed.causalSessionState?.deck) ? parsed.causalSessionState.deck : []),
      ...Object.keys(parsed.causalSessionState?.skillAcquisitions || {})
    ];
    for (const cardId of legacyCardIds) {
      const match = typeof cardId === 'string'
        ? cardId.match(/^legacy_(sword_heart|pill_way|array_way|heaven_book|demon_blood|immortal_will)_(?:art|sword|spell|body|pill)\+*$/)
        : null;
      if (!match) continue;
      const setId = match[1];
      legacyArchive.fragmentsBySet[setId] = 8;
      if (!legacyArchive.completedSetIds.includes(setId)) legacyArchive.completedSetIds.push(setId);
      const canonicalCardId = cardId.replace(/\++$/, '');
      if (!legacyArchive.discoveredVariantCardIds.includes(canonicalCardId)) {
        legacyArchive.discoveredVariantCardIds.push(canonicalCardId);
      }
    }
    legacyArchive.migrationVersion = GameStateManager.LEGACY_ARCHIVE_MIGRATION_VERSION;
    parsed.legacyArchive = legacyArchive;

    if (parsed.causalSessionState && Number(parsed.causalSessionState.lifeCount) === parsed.lifeCount) {
      parsed.causalSessionState.legacyRunState = this._normalizeLegacyRunState(
        parsed.causalSessionState.legacyRunState,
        parsed.lifeCount
      );
    }

    parsed.legacy = Object.assign({}, defaults.legacy, parsed.legacy || {});
    for (const field of ['npcAffections', 'factionReputations', 'pathMemories', 'knowledge', 'pathArchetypes']) {
      if (!parsed.legacy[field] || typeof parsed.legacy[field] !== 'object' || Array.isArray(parsed.legacy[field])) {
        parsed.legacy[field] = {};
      }
    }
    parsed.legacy.completedQuests = uniqueStrings(parsed.legacy.completedQuests);
    parsed.legacy.clues = uniqueStrings(parsed.legacy.clues);
    parsed.legacy.lineage = Array.isArray(parsed.legacy.lineage) ? parsed.legacy.lineage : [];
    const rawRebirthTree = parsed.legacy.rebirthTree && typeof parsed.legacy.rebirthTree === 'object'
      ? parsed.legacy.rebirthTree
      : {};
    parsed.legacy.rebirthTree = {
      version: Math.max(1, Math.floor(Number(rawRebirthTree.version) || 1)),
      insight: Math.max(0, Math.floor(Number(rawRebirthTree.insight) || 0)),
      spentInsight: Math.max(0, Math.floor(Number(rawRebirthTree.spentInsight) || 0)),
      unlockedNodeIds: uniqueStrings(rawRebirthTree.unlockedNodeIds)
    };
    const rawCosmetics = parsed.legacy.companionCosmetics
      && typeof parsed.legacy.companionCosmetics === 'object'
      ? parsed.legacy.companionCosmetics
      : {};
    parsed.legacy.companionCosmetics = {
      selectedPortraitByNpc: rawCosmetics.selectedPortraitByNpc
        && typeof rawCosmetics.selectedPortraitByNpc === 'object'
        && !Array.isArray(rawCosmetics.selectedPortraitByNpc)
        ? Object.fromEntries(Object.entries(rawCosmetics.selectedPortraitByNpc)
          .filter(([npcId, stageId]) => (
            typeof npcId === 'string' && npcId.trim()
            && typeof stageId === 'string' && stageId.trim()
          )))
        : {}
    };
    parsed.saveVersion = GameStateManager.SAVE_SCHEMA_VERSION;
    return parsed;
  }

  _summarizeSaveSlot(slotId, rawText) {
    const active = slotId === this.activeSaveSlotId;
    if (!rawText) {
      return {
        slotId,
        label: this._getDefaultSaveSlotLabel(slotId),
        active,
        occupied: false,
        corrupted: false,
        canResume: false,
        lifeCount: 0,
        currentLife: 1,
        realm: 'qi',
        path: null,
        turn: 0,
        playerName: '',
        lineageCount: 0
      };
    }
    try {
      const parsed = this._migrateUnlocks(JSON.parse(rawText), slotId);
      const snapshot = parsed.causalSessionState;
      const sameLife = snapshot
        && Number(snapshot.lifeCount) === Number(parsed.lifeCount || 0);
      const story = parsed.storyThreadState;
      const activeStory = story
        && Number(story.lifeCount) === Number(parsed.lifeCount || 0)
        && Array.isArray(story.activeThreads)
        && story.activeThreads.length > 0;
      const pendingKarma = Array.isArray(parsed.pendingKarmaSeeds)
        && parsed.pendingKarmaSeeds.length > 0;
      const persistedCriticalCard = sameLife
        && typeof snapshot.pendingCardId === 'string'
        && snapshot.pendingCardId.length > 0;
      const canResume = Boolean(
        activeStory
        || pendingKarma
        || persistedCriticalCard
        || (sameLife && snapshot.path && Array.isArray(snapshot.deck) && snapshot.deck.length > 0)
      );
      return {
        slotId,
        label: parsed.saveSlot.label,
        active,
        occupied: true,
        corrupted: false,
        canResume,
        lifeCount: parsed.lifeCount,
        currentLife: parsed.lifeCount + 1,
        realm: sameLife ? (snapshot.realm || 'qi') : 'qi',
        path: sameLife ? (snapshot.path || null) : null,
        turn: sameLife ? Math.max(0, Number(snapshot.turn) || 0) : 0,
        playerName: sameLife ? (snapshot.playerName || '') : '',
        lineageCount: Array.isArray(parsed.legacy?.lineage) ? parsed.legacy.lineage.length : 0
      };
    } catch (_) {
      return {
        slotId,
        label: this._getDefaultSaveSlotLabel(slotId),
        active,
        occupied: true,
        corrupted: true,
        canResume: false,
        lifeCount: 0,
        currentLife: 1,
        realm: 'qi',
        path: null,
        turn: 0,
        playerName: '',
        lineageCount: 0
      };
    }
  }

  listSaveSlots() {
    return GameStateManager.SAVE_SLOT_IDS.map(slotId => {
      try {
        return this._summarizeSaveSlot(
          slotId,
          localStorage.getItem(this._getSaveSlotStorageKey(slotId))
        );
      } catch (_) {
        return this._summarizeSaveSlot(slotId, null);
      }
    });
  }

  createSaveSlot(options = {}) {
    const slotId = options.slotId;
    if (!this._isValidSaveSlotId(slotId)) {
      return { created: false, reason: 'invalid-slot' };
    }
    const storageKey = this._getSaveSlotStorageKey(slotId);
    try {
      if (localStorage.getItem(storageKey)) {
        return { created: false, reason: 'slot-occupied', slotId };
      }
      if (slotId !== this.activeSaveSlotId && !this._activeSaveSlotCorrupt) {
        if (!this._saveUnlocks()) {
          return { created: false, reason: 'current-save-failed', slotId };
        }
      }
      const unlocks = this._createDefaultUnlocks(slotId);
      unlocks.questState = this._normalizeQuestState(null);
      unlocks.saveSlot = this._normalizeSaveSlotMeta(
        { label: options.label },
        slotId
      );
      localStorage.setItem(storageKey, JSON.stringify(unlocks));
      const activate = options.activate !== false;
      if (activate) {
        localStorage.setItem(GameStateManager.ACTIVE_SAVE_SLOT_STORAGE_KEY, slotId);
      }
      return {
        created: true,
        slotId,
        activated: activate,
        requiresReload: activate && slotId !== this.activeSaveSlotId
      };
    } catch (_) {
      return { created: false, reason: 'storage-unavailable', slotId };
    }
  }

  activateSaveSlot(slotId) {
    if (!this._isValidSaveSlotId(slotId)) {
      return { activated: false, reason: 'invalid-slot' };
    }
    if (slotId === this.activeSaveSlotId) {
      return { activated: true, slotId, requiresReload: false };
    }
    try {
      if (!localStorage.getItem(this._getSaveSlotStorageKey(slotId))) {
        return { activated: false, reason: 'empty-slot', slotId };
      }
      if (!this._activeSaveSlotCorrupt && !this._saveUnlocks()) {
        return { activated: false, reason: 'current-save-failed', slotId };
      }
      localStorage.setItem(GameStateManager.ACTIVE_SAVE_SLOT_STORAGE_KEY, slotId);
      return { activated: true, slotId, requiresReload: true };
    } catch (_) {
      return { activated: false, reason: 'storage-unavailable', slotId };
    }
  }

  renameSaveSlot(slotId, label) {
    if (!this._isValidSaveSlotId(slotId)) {
      return { renamed: false, reason: 'invalid-slot' };
    }
    const cleanLabel = typeof label === 'string' ? label.trim().slice(0, 12) : '';
    if (!cleanLabel) return { renamed: false, reason: 'invalid-label', slotId };
    try {
      const storageKey = this._getSaveSlotStorageKey(slotId);
      const raw = localStorage.getItem(storageKey);
      if (!raw) return { renamed: false, reason: 'empty-slot', slotId };
      const unlocks = this._migrateUnlocks(JSON.parse(raw), slotId);
      unlocks.saveSlot.label = cleanLabel;
      localStorage.setItem(storageKey, JSON.stringify(unlocks));
      if (slotId === this.activeSaveSlotId) this.unlocks.saveSlot.label = cleanLabel;
      return { renamed: true, slotId, label: cleanLabel };
    } catch (_) {
      return { renamed: false, reason: 'corrupt-or-unavailable', slotId };
    }
  }

  deleteSaveSlot(slotId) {
    if (!this._isValidSaveSlotId(slotId)) {
      return { deleted: false, reason: 'invalid-slot' };
    }
    try {
      if (slotId !== this.activeSaveSlotId && !this._activeSaveSlotCorrupt) {
        if (!this._saveUnlocks()) {
          return { deleted: false, reason: 'current-save-failed', slotId };
        }
      }
      localStorage.removeItem(this._getSaveSlotStorageKey(slotId));
      localStorage.removeItem(this._getSaveSlotCorruptBackupKey(slotId));
      if (slotId === 'slot_1') {
        // 旧 Quest sidecar 只可能属于一号玉简。用户明确清空一号玉简时，
        // 必须一并删除尚未迁移完成的旧记录，避免刷新后任务复活。
        localStorage.removeItem(GameStateManager.LEGACY_QUEST_STORAGE_KEY);
      }
      if (slotId === this.activeSaveSlotId) {
        localStorage.setItem(GameStateManager.ACTIVE_SAVE_SLOT_STORAGE_KEY, slotId);
      }
      return {
        deleted: true,
        slotId,
        requiresReload: slotId === this.activeSaveSlotId
      };
    } catch (_) {
      return { deleted: false, reason: 'storage-unavailable', slotId };
    }
  }

  _saveUnlocks() {
    if (this._lifeTransition) return true;
    try {
      this.unlocks.saveSlot = this._normalizeSaveSlotMeta(
        this.unlocks.saveSlot,
        this.activeSaveSlotId
      );
      localStorage.setItem(
        this._getSaveSlotStorageKey(this.activeSaveSlotId),
        JSON.stringify(this.unlocks)
      );
      this._activeSaveSlotCorrupt = false;
      return true;
    } catch (e) {
      // localStorage 不可用时静默失败
      return false;
    }
  }

  persistUnlocks() {
    return this._saveUnlocks();
  }

  _loadUnlocks() {
    const slotId = this._isValidSaveSlotId(this.activeSaveSlotId)
      ? this.activeSaveSlotId
      : 'slot_1';
    const storageKey = this._getSaveSlotStorageKey(slotId);
    let saved = null;
    try {
      saved = localStorage.getItem(storageKey);
    } catch (_) {
      return this._createDefaultUnlocks(slotId);
    }
    if (!saved) return this._createDefaultUnlocks(slotId);

    try {
      const migrated = this._migrateUnlocks(JSON.parse(saved), slotId);
      // 合法存档已经读取成功。迁移回写失败（例如 quota 满）不能把可恢复状态降级为空档。
      try {
        localStorage.setItem(storageKey, JSON.stringify(migrated));
      } catch (_) {}
      return migrated;
    } catch (e) {
      // 解析失败时保留损坏文本，便于玩家反馈后恢复，而不是静默覆盖证据。
      try {
        if (saved) {
          localStorage.setItem(this._getSaveSlotCorruptBackupKey(slotId), saved);
          this._activeSaveSlotCorrupt = true;
        }
      } catch (_) {}
    }
    return this._createDefaultUnlocks(slotId);
  }
}

// 全局单例
const gameState = new GameStateManager();

if (typeof module !== 'undefined' && module.exports) {
  module.exports = GameStateManager;
}
