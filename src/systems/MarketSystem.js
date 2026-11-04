/**
 * MarketSystem — 集市刷新系统
 *
 * 福源影响集市商品品质和数量。
 * 集市是偶遇机制，每12-18回合触发一次"鬼市偶遇"卡。
 * 核心公式: 金质法宝概率 = max(3%, 5% + (fortune - 40) × 0.3%)
 *
 * 与 ShopSystem 协作：
 *  - MarketSystem 负责"集市何时开、刷出什么货"
 *  - ShopSystem 负责"购买/替换/消费灵石"
 */
class MarketSystem {
  constructor() {
    this._initialized = false;
    this.onLog = null;
    this._vendorProfiles = new Map();
    this._legacyVendorAliases = {};
    // Kept as a replaceable seam for fixed-seed simulations; production keeps
    // the browser RNG. Cadence must be reproducible in evidence runs without
    // becoming a second clock or a test-only implementation.
    this._random = () => Math.random();

    // 稀有度权重表（按福源区间）
    this._fortuneTiers = [
      { min: 0,  max: 20, slots: 3, weights: [0.70, 0.17, 0.10, 0.03, 0.00], priceMult: 1.5 },
      { min: 21, max: 40, slots: 4, weights: [0.50, 0.30, 0.15, 0.05, 0.00], priceMult: 1.2 },
      { min: 41, max: 60, slots: 5, weights: [0.35, 0.35, 0.20, 0.10, 0.00], priceMult: 1.0 },
      { min: 61, max: 80, slots: 6, weights: [0.25, 0.30, 0.25, 0.20, 0.00], priceMult: 0.9 },
      { min: 81, max: 100,slots: 7, weights: [0.15, 0.30, 0.30, 0.25, 0.00], priceMult: 0.8 },
    ];

    // 价格范围（按稀有度 1-6）
    this._priceRanges = {
      1: { min: 4, max: 7 },    // ☆ 灰
      2: { min: 7, max: 11 },   // ★★ 白
      3: { min: 11, max: 17 },  // ★★★ 蓝
      4: { min: 17, max: 25 },  // ★★★★ 紫
      5: { min: 25, max: 37 },  // ★★★★★ 金
      6: { min: 37, max: 51 },  // ★★★★★★ 传说
    };
  }

  _state() {
    return typeof gameState !== 'undefined' ? gameState : null;
  }

  _decisionIndex() {
    const state = this._state();
    return Math.max(0, Number(state?.getDecisionIndex?.() ?? state?.runClock?.decisionIndex ?? state?.turn) || 0);
  }

  _marketState() {
    const state = this._state();
    if (!state) return {
      version: 3, lastBazaarDecisionIndex: -99, nextBazaarDecisionIndex: null,
      lastGhostDecisionIndex: -99, nextGhostDecisionIndex: null,
      totalVisits: 0, currentItems: [], priceMultiplier: 1, slotCount: 5,
      routeModifiers: null, activeSession: null, vendorRelations: {}, visitHistory: [],
      debts: [], rustedSwordOrders: [], ghostMarketAccess: 'open', migrationSource: 'missing_game_state'
    };
    if (!state.marketState || typeof state.marketState !== 'object' || Array.isArray(state.marketState)) {
      state.marketState = {
        version: 3, lastBazaarDecisionIndex: -99, nextBazaarDecisionIndex: null,
        lastGhostDecisionIndex: -99, nextGhostDecisionIndex: null,
        totalVisits: 0, currentItems: [], priceMultiplier: 1, slotCount: 5,
        routeModifiers: null, activeSession: null, vendorRelations: {}, visitHistory: [],
        debts: [], rustedSwordOrders: [], ghostMarketAccess: 'open', migrationSource: 'legacy_clock'
      };
    }
    return state.marketState;
  }

  _clone(value) {
    return JSON.parse(JSON.stringify(value));
  }

  _hasStoredDecisionIndex(value) {
    return value !== null && value !== '' && Number.isFinite(Number(value));
  }

  // Legacy names remain thin aliases for old diagnostics/tests.  They no
  // longer own state: every read/write goes through GameStateManager.marketState.
  get _lastMarketTurn() { return this._marketState().lastGhostDecisionIndex; }
  set _lastMarketTurn(value) { this._marketState().lastGhostDecisionIndex = Math.floor(Number(value) || 0); }
  get _nextMarketTurn() { return this._marketState().nextGhostDecisionIndex; }
  set _nextMarketTurn(value) { this._marketState().nextGhostDecisionIndex = Math.max(0, Math.floor(Number(value) || 0)); }
  get _totalVisits() { return this._marketState().totalVisits; }
  set _totalVisits(value) { this._marketState().totalVisits = Math.max(0, Math.floor(Number(value) || 0)); }
  get _currentItems() { return this._marketState().currentItems; }
  set _currentItems(value) { this._marketState().currentItems = Array.isArray(value) ? this._clone(value) : []; }
  get _priceMultiplier() { return this._marketState().priceMultiplier; }
  set _priceMultiplier(value) { this._marketState().priceMultiplier = Math.max(0.01, Number(value) || 1); }
  get _slotCount() { return this._marketState().slotCount; }
  set _slotCount(value) { this._marketState().slotCount = Math.max(1, Math.floor(Number(value) || 1)); }
  get _routeModifiers() { return this._marketState().routeModifiers; }
  set _routeModifiers(value) { this._marketState().routeModifiers = value && typeof value === 'object' ? this._clone(value) : null; }

  get _lastBazaarTurn() { return this._marketState().lastBazaarDecisionIndex; }
  set _lastBazaarTurn(value) { this._marketState().lastBazaarDecisionIndex = Math.floor(Number(value) || 0); }
  get _nextBazaarTurn() { return this._marketState().nextBazaarDecisionIndex; }
  set _nextBazaarTurn(value) { this._marketState().nextBazaarDecisionIndex = Math.max(0, Math.floor(Number(value) || 0)); }

  /**
   * 初始化 — 从 treasureSystem 加载法宝池
   */
  init() {
    if (this._initialized) return;
    if (typeof treasureSystem === 'undefined' || !treasureSystem) {
      this._log('[MarketSystem] treasureSystem 未就绪，集市暂不可用');
      this._initialized = true;
      return;
    }
    const profileData = typeof dataLoader !== 'undefined' && dataLoader?.loadSync
      ? dataLoader.loadSync('markets:vendor_profiles')
      : null;
    this.loadVendorProfiles(profileData);
    this._initialized = true;
    this.ensureCadence();
  }

  // Service initialization survives a restart; the GSM-owned current-life
  // plan does not. Fill only missing dates, never reroll a restored plan.
  ensureCadence() {
    if (!this._initialized || typeof treasureSystem === 'undefined' || !treasureSystem) return false;
    const state = this._marketState();
    const currentDecision = this._decisionIndex();
    let initializedCadence = false;
    if (!this._hasStoredDecisionIndex(state.nextBazaarDecisionIndex)) {
      state.nextBazaarDecisionIndex = this._scheduleFromProfile('public_bazaar', currentDecision, 6, 10);
      initializedCadence = true;
    }
    if (!this._hasStoredDecisionIndex(state.nextGhostDecisionIndex)) {
      state.nextGhostDecisionIndex = this._scheduleGhostFromProfile(currentDecision);
      initializedCadence = true;
      state.migrationSource = state.migrationSource || 'fresh_run';
    }
    // The first cadence must survive a refresh before either encounter card.
    if (initializedCadence) this._state()?.persistCausalSession?.();
    this._log('[MarketSystem] 集市约在第' + state.nextBazaarDecisionIndex + '次决断后到访；鬼市的夜门约在第' + state.nextGhostDecisionIndex + '次决断后显现。');
    return initializedCadence;
  }

  /**
   * Profiles are authored data; the system only normalizes and instantiates
   * one session from them.  Keeping aliases here prevents old cards/saves
   * from becoming a second market type.
   */
  loadVendorProfiles(data) {
    this._vendorProfiles.clear();
    this._legacyVendorAliases = {};
    const source = data && typeof data === 'object' && !Array.isArray(data) ? data : {};
    if (source.legacyAliases && typeof source.legacyAliases === 'object' && !Array.isArray(source.legacyAliases)) {
      for (const [legacy, target] of Object.entries(source.legacyAliases)) {
        if (typeof legacy === 'string' && legacy && typeof target === 'string' && target) {
          this._legacyVendorAliases[legacy] = target;
        }
      }
    }
    for (const profile of Array.isArray(source.vendors) ? source.vendors : []) {
      if (!profile || typeof profile !== 'object' || typeof profile.id !== 'string' || !profile.id
        || typeof profile.marketType !== 'string' || !profile.marketType) continue;
      this._vendorProfiles.set(profile.id, this._clone(profile));
    }
    return this._vendorProfiles.size;
  }

  normalizeVendorId(vendorId) {
    const raw = typeof vendorId === 'string' && vendorId ? vendorId : 'regulated_market';
    const normalized = this._legacyVendorAliases[raw] || raw;
    return this._vendorProfiles.has(normalized) ? normalized : null;
  }

  getVendorProfile(vendorId) {
    const normalized = this.normalizeVendorId(vendorId);
    const profile = normalized ? this._vendorProfiles.get(normalized) : null;
    return profile ? this._clone(profile) : null;
  }

  _resolveCausalServicePresentation(consumer, fact) {
    const base = {
      label: consumer?.label,
      description: consumer?.description,
      receiptText: consumer?.receiptText
    };
    const rule = consumer?.presentationByPayload;
    const payloadKey = typeof rule?.payloadKey === 'string' ? rule.payloadKey : null;
    const payloadValue = payloadKey && fact?.payload && typeof fact.payload === 'object'
      ? fact.payload[payloadKey]
      : null;
    const variant = typeof payloadValue === 'string' && rule?.variants && typeof rule.variants === 'object'
      ? rule.variants[payloadValue]
      : null;
    if (!variant || typeof variant !== 'object') return base;
    return {
      label: typeof variant.label === 'string' && variant.label ? variant.label : base.label,
      description: typeof variant.description === 'string' && variant.description ? variant.description : base.description,
      receiptText: typeof variant.receiptText === 'string' && variant.receiptText ? variant.receiptText : base.receiptText
    };
  }

  _materializeCausalServices(profile, decisionIndex) {
    if (profile?.id !== 'regulated_market' || typeof narrativeLedger === 'undefined' || !narrativeLedger) return [];
    narrativeLedger.closeExpiredFacts?.({ decisionIndex });
    const active = narrativeLedger.getEligibleConsumerFacts?.({ vendorId: profile.id, decisionIndex }) || [];
    const closed = narrativeLedger.getClosedConsumerFacts?.({ vendorId: profile.id }) || [];
    return [
      ...active.map(entry => {
        const presentation = this._resolveCausalServicePresentation(entry.consumer, entry);
        return {
          id: entry.consumer.consumerId,
          kind: 'causal_fact_consumer',
          actionId: `causal_fact:${entry.consumer.consumerId}:${entry.factInstanceId}`,
          factInstanceId: entry.factInstanceId,
          factTypeId: entry.factTypeId,
          consumerId: entry.consumer.consumerId,
          label: presentation.label,
          description: presentation.description,
          receiptText: presentation.receiptText,
          costSpec: this._clone(entry.consumer.costSpec || []),
          delivery: entry.consumer.delivery && typeof entry.consumer.delivery === 'object'
            ? this._clone(entry.consumer.delivery)
            : null,
          available: true
        };
      }),
      ...closed.map(entry => ({
        id: `${entry.consumer.consumerId}:closed:${entry.factInstanceId}`,
        kind: 'causal_fact_closed',
        actionId: `causal_fact_closed:${entry.consumer.consumerId}:${entry.factInstanceId}`,
        factInstanceId: entry.factInstanceId,
        consumerId: entry.consumer.consumerId,
        label: '流转号已逾期',
        description: entry.terminalClosure,
        terminalClosure: entry.terminalClosure,
        available: false
      }))
    ];
  }

  /**
   * Keep the entry card as evidence, not authority. A forged
   * `marketEncounter` flag must still fail the same night/location/signal
   * predicates the scheduler used to produce a market card.
   */
  canEnterVendor(vendorId, { marketEncounter = false, decisionIndex = this._decisionIndex() } = {}) {
    const profile = this.getVendorProfile(vendorId);
    if (!profile) return { valid: false, reason: 'missing_profile' };
    const rules = profile.entryRules || {};
    if (rules.requiresEncounterCard && marketEncounter !== true) return { valid: false, reason: 'missing_encounter' };
    if (rules.requiresPopulationLocation && !this._hasPopulationLocation(profile)) return { valid: false, reason: 'invalid_location' };
    if (profile.id === 'ghost_market') {
      if (this._marketState().ghostMarketAccess === 'revoked') return { valid: false, reason: 'access_revoked' };
      if (rules.requiresNightWindow && !this._isNightWindow(decisionIndex)) return { valid: false, reason: 'not_night' };
      if (!this._hasGhostSignal(profile)) return { valid: false, reason: 'missing_signal' };
    }
    return { valid: true, reason: null };
  }

  /**
   * Relationship is a consumer, not a cosmetic counter. The next bazaar
   * session materializes the remembered favor into a bounded price adjustment,
   * a provenance hint, and (where authored) one special offer.
   */
  getBazaarStalls() {
    const profile = this.getVendorProfile('public_bazaar');
    if (!profile) return [];
    const relations = this._marketState().vendorRelations || {};
    return (profile.stalls || []).map(raw => {
      const stall = this._clone(raw);
      const relation = Math.max(0, Number(relations[stall.id]) || 0);
      const rule = stall.relationship && typeof stall.relationship === 'object' ? stall.relationship : null;
      const unlocked = Boolean(rule && relation >= Math.max(1, Number(rule.threshold) || 1));
      const priceMultiplier = unlocked ? Math.max(0.1, Number(rule.priceMultiplier) || 1) : 1;
      stall.relation = relation;
      stall.relationshipUnlocked = unlocked;
      stall.relationHint = unlocked && typeof rule.hint === 'string' ? rule.hint : null;
      stall.offers = (stall.offers || []).map(offer => {
        const next = this._clone(offer);
        if (unlocked && !Array.isArray(next.costSpec) && Number.isFinite(Number(next.price))) {
          // Familiarity must be visible even on the low-priced qi-stage
          // catalogue; round the discount in the player's favour.
          next.price = Math.max(1, Math.floor(Number(next.price) * priceMultiplier));
          next.relationHint = stall.relationHint;
        }
        return next;
      });
      if (unlocked && rule?.specialOffer && typeof rule.specialOffer === 'object') {
        stall.offers.push({ ...this._clone(rule.specialOffer), relationHint: stall.relationHint, relationUnlocked: true });
      }
      return stall;
    });
  }

  createVendorSession({ vendorId, sessionKey, entryCardId = null, openedAtDecisionIndex, offers = [], stalls = null } = {}) {
    const profile = this.getVendorProfile(vendorId);
    if (!profile || typeof sessionKey !== 'string' || !sessionKey) return null;
    const decisionIndex = Number.isFinite(Number(openedAtDecisionIndex))
      ? Math.max(0, Math.floor(Number(openedAtDecisionIndex)))
      : this._decisionIndex();
    // A ghost contract offer is authored by the profile and placed ahead of the
    // ambient pool. It is intentionally not part of `_generateGhostItems()`:
    // the player must recognize a fixed pact rather than infer a special route
    // from a lucky random roll.
    const profileContracts = profile.marketType === 'ghost' && Array.isArray(profile.contractOffers)
      ? profile.contractOffers : [];
    const suppliedOffers = Array.isArray(offers) ? offers : [];
    const sessionOffers = [
      ...profileContracts,
      ...suppliedOffers.filter(offer => !profileContracts.some(contract => contract?.id === offer?.id))
    ].filter(offer => offer && typeof offer === 'object');
    const immutableOffers = sessionOffers.map((raw, index) => {
      const offer = this._clone(raw);
      if (profile.marketType === 'ghost') {
        offer.provenance = 'ghost_market';
        // A ghost-market price is always a contract. Charging lifespan/debt on
        // only the first visual card would recreate a hidden ordinary-shop
        // escape hatch as soon as the player buys a later offer.
        const authoredCosts = Array.isArray(offer.costSpec) ? offer.costSpec : [];
        const authoredStone = authoredCosts
          .filter(cost => cost?.kind === 'resource' && cost.key === 'spiritStone')
          .reduce((total, cost) => total + Math.max(0, Number(cost?.amount) || 0), 0);
        const authoredLifespan = authoredCosts
          .filter(cost => cost?.kind === 'resource' && cost.key === 'lifespan')
          .reduce((total, cost) => total + Math.max(0, Number(cost?.amount) || 0), 0);
        const nonContractCosts = authoredCosts.filter(cost => !(cost?.kind === 'resource'
          && (cost.key === 'spiritStone' || cost.key === 'lifespan')));
        const stone = authoredStone || Math.max(0, Number(offer.displayPrice ?? offer.price) || 0);
        const lifespan = Math.max(
          Math.max(1, Number(profile.riskRules?.lifespanCost) || 3),
          authoredLifespan
        );
        offer.costSpec = [
          ...this._clone(nonContractCosts),
          { kind: 'resource', key: 'spiritStone', amount: stone },
          { kind: 'resource', key: 'lifespan', amount: lifespan }
        ];
      }
      return offer;
    });
    return {
      version: 2,
      status: 'open',
      sessionId: sessionKey,
      sessionKey,
      vendorId: profile.id,
      marketType: profile.marketType,
      entryCardId,
      openedAtDecisionIndex: decisionIndex,
      offerRevision: 1,
      immutableOffers,
      actionReceipts: {},
      interactionBudget: {
        limit: Math.max(0, Math.floor(Number(profile.interactionBudget) || 0)),
        remaining: Math.max(0, Math.floor(Number(profile.interactionBudget) || 0))
      },
      stalls: Array.isArray(stalls) ? this._clone(stalls) : (Array.isArray(profile.stalls) ? this._clone(profile.stalls) : []),
      services: [
        ...(Array.isArray(profile.services) ? this._clone(profile.services) : []),
        ...this._materializeCausalServices(profile, decisionIndex)
      ],
      riskRules: profile.riskRules && typeof profile.riskRules === 'object' ? this._clone(profile.riskRules) : {},
      debt: profile.debt && typeof profile.debt === 'object' ? this._clone(profile.debt) : null,
      // Presentation is selected by the vendor profile at entry, then frozen
      // with the economic session. Rendering and ambience may consume this
      // snapshot but never use it as a source of prices, effects, or debt.
      presentationProfile: profile.presentationProfile && typeof profile.presentationProfile === 'object'
        ? this._clone(profile.presentationProfile)
        : null,
      exitContract: typeof profile.exitContract === 'string' ? profile.exitContract : '',
      summary: { openingOfferCount: immutableOffers.length, purchaseCount: 0, spiritStoneSpent: 0, purchasedItems: [], exchangedItems: [] }
    };
  }

  collectDueDebtEvents(decisionIndex = this._decisionIndex()) {
    const state = this._marketState();
    const index = Math.max(0, Math.floor(Number(decisionIndex) || 0));
    const events = [];
    for (const debt of Array.isArray(state.debts) ? state.debts : []) {
      if (!debt || !['PENDING', 'DUE'].includes(debt.status)) continue;
      if (debt.status === 'PENDING' && Number(debt.dueDecisionIndex) > index) continue;
      if (debt.status === 'PENDING') {
        debt.status = 'DUE';
        debt.dueReceiptId = `debt_due:${debt.debtId}`;
      }
      // A DUE debt is re-offered only when the prior queue was not durably
      // accepted. This is what makes the pursuit survive a refresh without
      // duplicating a card that FlowDirector already owns.
      if (debt.pursuitQueued !== true) {
        events.push({ debtId: debt.debtId, creditorId: debt.creditorId, consequence: debt.defaultConsequence || null });
      }
    }
    return events;
  }

  markDebtPursuitQueued(debtId) {
    const debt = this._marketState().debts?.find(entry => entry?.debtId === debtId && entry.status === 'DUE');
    if (!debt) return false;
    debt.pursuitQueued = true;
    return true;
  }

  _isGhostOathInstanceEquipped(debt) {
    const state = this._state();
    const instanceId = typeof debt?.acquiredInstanceId === 'string' ? debt.acquiredInstanceId : null;
    if (!instanceId || !state?.treasureInstances?.[instanceId]) return false;
    return Object.values(state.equipment || {}).includes(instanceId);
  }

  /**
   * A settled combat can pressure an active night-oath, but it may never create
   * a second roll for the same encounter. The receipt lives with its debt so it
   * survives reload and remains valid even if the sword is later stashed.
   */
  applyGhostOathDebtPressure({ encounterInstanceId, decisionIndex = this._decisionIndex() } = {}) {
    const state = this._state();
    const encounterId = typeof encounterInstanceId === 'string' ? encounterInstanceId.trim() : '';
    if (!state || !encounterId || !Array.isArray(state.marketState?.debts)) return { processed: false, receipts: [] };
    const index = Math.max(0, Math.floor(Number(decisionIndex) || 0));
    const ownsTransaction = !state._causalTransaction;
    if (ownsTransaction && (typeof state.beginCausalTransaction !== 'function' || state.beginCausalTransaction() !== true)) {
      return { processed: false, receipts: [] };
    }
    const receipts = [];
    try {
      for (const debt of state.marketState.debts) {
        if (!debt || debt.kind !== 'ghost_oath_sword' || debt.status !== 'PENDING'
          || !this._isGhostOathInstanceEquipped(debt)) continue;
        const pressure = debt.pressure && typeof debt.pressure === 'object' ? debt.pressure : {};
        const processedIds = Array.isArray(pressure.processedEncounterIds) ? pressure.processedEncounterIds : [];
        if (processedIds.includes(encounterId)) continue;
        const chance = Math.max(0, Math.min(1, Number(pressure.chance) || (1 / 3)));
        const pityLimit = Math.max(1, Math.floor(Number(pressure.pityLimit) || 3));
        const misses = Math.max(0, Math.floor(Number(pressure.misses) || 0));
        const forced = misses + 1 >= pityLimit;
        const roll = this._random();
        const advanced = forced || roll < chance;
        const beforeDue = Math.max(index + 1, Math.floor(Number(debt.dueDecisionIndex) || index + 1));
        const afterDue = advanced ? Math.max(index + 1, beforeDue - 1) : beforeDue;
        const receipt = {
          receiptId: `ghost_oath_pressure:${debt.debtId}:${encounterId}`,
          encounterInstanceId: encounterId,
          decisionIndex: index,
          chance,
          pityLimit,
          missesBefore: misses,
          forced,
          roll: Number.isFinite(Number(roll)) ? Number(roll) : null,
          advanced,
          dueDecisionIndexBefore: beforeDue,
          dueDecisionIndexAfter: afterDue
        };
        debt.dueDecisionIndex = afterDue;
        debt.pressure = {
          chance,
          pityLimit,
          misses: advanced ? 0 : misses + 1,
          processedEncounterIds: [...processedIds, encounterId].slice(-24),
          receipts: [...(Array.isArray(pressure.receipts) ? pressure.receipts : []), receipt].slice(-24),
          lastReceipt: receipt
        };
        receipts.push(this._clone(receipt));
      }
      if (ownsTransaction && receipts.length > 0) {
        let persisted = false;
        try { persisted = state.persistCausalSession?.({ force: true }) !== false; } catch (error) { persisted = false; }
        if (!persisted) {
          state.rollbackCausalTransaction?.();
          return { processed: false, receipts: [] };
        }
        state.finishCausalTransaction?.();
      } else if (ownsTransaction) {
        state.finishCausalTransaction?.();
      }
    } catch (error) {
      if (ownsTransaction) state.rollbackCausalTransaction?.();
      return { processed: false, receipts: [] };
    }
    return { processed: receipts.length > 0, receipts };
  }

  registerLicensedRustedSwordOrder({
    factInstanceId,
    consumerId,
    delivery,
    paidCostSpec = [],
    registeredDecisionIndex = this._decisionIndex()
  } = {}) {
    if (typeof factInstanceId !== 'string' || !factInstanceId
      || typeof consumerId !== 'string' || !consumerId
      || delivery?.definitionId !== 'licensed_rusted_sword'
      || Math.floor(Number(delivery?.coreDecisionDelay) || 0) !== 3) return null;
    const state = this._marketState();
    if (!Array.isArray(state.rustedSwordOrders)) state.rustedSwordOrders = [];
    const orderId = `licensed_rusted_sword:${factInstanceId}:${consumerId}`;
    const existing = state.rustedSwordOrders.find(entry => entry?.orderId === orderId);
    if (existing) {
      return existing.factInstanceId === factInstanceId
        && existing.consumerId === consumerId
        && existing.definitionId === delivery.definitionId
        ? { ...this._clone(existing), replayed: true }
        : null;
    }
    const registered = Math.max(0, Math.floor(Number(registeredDecisionIndex) || 0));
    const order = {
      orderId,
      factInstanceId,
      consumerId,
      definitionId: 'licensed_rusted_sword',
      provenanceFactTypeId: 'sword_origin_licensed',
      orderLabel: typeof delivery.orderLabel === 'string' && delivery.orderLabel
        ? delivery.orderLabel : '坊市净炼残剑',
      paidCostSpec: this._clone(Array.isArray(paidCostSpec) ? paidCostSpec : []),
      registeredCoreDecisionIndex: registered,
      coreDecisionDelay: 3,
      dueCoreDecisionIndex: registered + 3,
      status: 'REGISTERED',
      deliveryQueued: false,
      instanceId: null,
      provenanceFactInstanceId: null
    };
    state.rustedSwordOrders.push(order);
    return this._clone(order);
  }

  collectDueLicensedSwordDeliveries(decisionIndex = this._decisionIndex()) {
    const state = this._marketState();
    const index = Math.max(0, Math.floor(Number(decisionIndex) || 0));
    const due = [];
    for (const order of Array.isArray(state.rustedSwordOrders) ? state.rustedSwordOrders : []) {
      if (!order || !['REGISTERED', 'READY'].includes(order.status)) continue;
      if (order.status === 'REGISTERED' && Number(order.dueCoreDecisionIndex) > index) continue;
      if (order.status === 'REGISTERED') {
        order.status = 'READY';
        order.deliveryReceiptId = `licensed_rusted_sword_due:${order.orderId}`;
      }
      if (order.deliveryQueued !== true) due.push(this._clone(order));
    }
    return due;
  }

  markLicensedSwordDeliveryQueued(orderId) {
    const order = this._marketState().rustedSwordOrders?.find(entry => entry?.orderId === orderId
      && entry.status === 'READY');
    if (!order) return false;
    order.deliveryQueued = true;
    return true;
  }

  getLicensedRustedSwordOrder(orderId) {
    const order = this._marketState().rustedSwordOrders?.find(entry => entry?.orderId === orderId);
    return order ? this._clone(order) : null;
  }

  claimLicensedRustedSwordDelivery(orderId, { instanceId, provenanceFactInstanceId, claimedDecisionIndex = this._decisionIndex() } = {}) {
    const order = this._marketState().rustedSwordOrders?.find(entry => entry?.orderId === orderId);
    if (!order) return null;
    if (order.status === 'CLAIMED') return { ...this._clone(order), replayed: true };
    if (order.status !== 'READY' || typeof instanceId !== 'string' || !instanceId
      || typeof provenanceFactInstanceId !== 'string' || !provenanceFactInstanceId) return null;
    order.status = 'CLAIMED';
    order.deliveryQueued = false;
    order.instanceId = instanceId;
    order.provenanceFactInstanceId = provenanceFactInstanceId;
    order.claimedDecisionIndex = Math.max(0, Math.floor(Number(claimedDecisionIndex) || 0));
    order.claimReceiptId = `licensed_rusted_sword_claim:${orderId}`;
    return this._clone(order);
  }

  _profileCadence(vendorId, fallbackMin, fallbackMax) {
    const cadence = this.getVendorProfile(vendorId)?.cadence || {};
    const min = Math.max(1, Math.floor(Number(cadence.minDecisions) || fallbackMin));
    const max = Math.max(min, Math.floor(Number(cadence.maxDecisions) || fallbackMax));
    return { min, max };
  }

  _scheduleFromProfile(vendorId, fromDecisionIndex, fallbackMin, fallbackMax) {
    const { min, max } = this._profileCadence(vendorId, fallbackMin, fallbackMax);
    return Math.max(0, Math.floor(Number(fromDecisionIndex) || 0))
      + min + Math.floor(this._random() * (max - min + 1));
  }

  _isNightWindow(decisionIndex) {
    // Four decision beats make one visible journey cycle: day, dusk, night,
    // late night. The rule is derived from decisionIndex, never from wall
    // time, and therefore survives refreshes and fixed-seed simulation.
    const phase = Math.max(0, Math.floor(Number(decisionIndex) || 0)) % 4;
    return phase === 2 || phase === 3;
  }

  _scheduleGhostFromProfile(fromDecisionIndex) {
    const base = Math.max(0, Math.floor(Number(fromDecisionIndex) || 0));
    const { min, max } = this._profileCadence('ghost_market', 14, 20);
    const candidates = [];
    for (let offset = min; offset <= max; offset++) {
      if (this._isNightWindow(base + offset)) candidates.push(base + offset);
    }
    // There is always at least one night in a 7-decision GDD window. Preserve
    // a safe fallback in case a future profile authors a narrower interval.
    if (candidates.length === 0) return this._scheduleFromProfile('ghost_market', base, min, max);
    return candidates[Math.floor(this._random() * candidates.length)];
  }

  _hasPopulationLocation(profile) {
    if (profile?.entryRules?.requiresPopulationLocation !== true) return true;
    const state = this._state();
    // Older saves and isolated runtime tests predate currentLocation. They are
    // compatible rather than silently locked out; live runs always persist it.
    if (!state || !Object.prototype.hasOwnProperty.call(state, 'currentLocation')) return true;
    return Boolean(String(state.currentLocation || '').trim());
  }

  _hasGhostSignal(profile) {
    const rules = profile?.entryRules || {};
    const requested = Array.isArray(rules.signalAny) ? rules.signalAny : [];
    if (requested.length === 0) return true;
    const state = this._state();
    const fortune = Number(state?.attributes?.fortune) || 0;
    const karmaBad = Number(state?.attributes?.karmaBad) || 0;
    const lead = state?.marketState?.ghostMarketLead === true
      || (typeof state?.getItemCount === 'function' && state.getItemCount('鬼市路引') > 0);
    return (requested.includes('fortune>=40') && fortune >= 40)
      || (requested.includes('karmaBad>=10') && karmaBad >= 10)
      || (requested.includes('ghost_market_lead') && lead);
  }

  _canTriggerGhost(decisionIndex) {
    const profile = this.getVendorProfile('ghost_market');
    if (!profile) return true; // legacy test/runtime fallback before profile data loads
    if (this._marketState().ghostMarketAccess === 'revoked') return false;
    return (!profile.entryRules?.requiresNightWindow || this._isNightWindow(decisionIndex))
      && this._hasPopulationLocation(profile)
      && this._hasGhostSignal(profile);
  }

  // ============ 触发检测 ============

  /**
   * Single market scheduler. It may emit at most one card for one projected
   * decision: a due debt is queued by GameLogic first, then ghost (night +
   * signal) takes precedence over a routine bazaar arrival.
   */
  tick(decisionIndex = this._decisionIndex()) {
    if (!this._initialized) return null;

    // 战斗/命盘中不触发
    if (typeof gameState !== 'undefined' && gameState._inCombat) return null;

    const index = Math.max(0, Math.floor(Number(decisionIndex) || 0));
    const state = this._marketState();
    const ghostDue = this._hasStoredDecisionIndex(state.nextGhostDecisionIndex)
      && index >= Number(state.nextGhostDecisionIndex);
    if (ghostDue && this._canTriggerGhost(index)) {
      this._lastMarketTurn = index;
      this._nextMarketTurn = this._scheduleGhostFromProfile(index);
      const fortune = gameState.attributes.fortune;
      this._currentItems = this._generateGhostItems(fortune);
      return this._buildMarketCard();
    }

    const bazaarDue = this._hasStoredDecisionIndex(state.nextBazaarDecisionIndex)
      && index >= Number(state.nextBazaarDecisionIndex);
    const bazaarProfile = this.getVendorProfile('public_bazaar');
    if (bazaarDue && this._hasPopulationLocation(bazaarProfile)) {
      this._lastBazaarTurn = index;
      this._nextBazaarTurn = this._scheduleFromProfile('public_bazaar', index, 6, 10);
      return this._buildBazaarCard();
    }
    return null;
  }

  /**
   * 获取当前刷出的商品（供 ShopSystem/UI 使用）
   */
  getCurrentMarketItems() {
    return this._currentItems;
  }

  getPriceMultiplier() {
    return this._priceMultiplier;
  }

  getSlotCount() {
    return this._slotCount;
  }

  getFortuneTierText() {
    const f = gameState.attributes.fortune;
    if (f <= 20) return '厄运缠身';
    if (f <= 40) return '时运平平';
    if (f <= 60) return '福运小成';
    if (f <= 80) return '天运亨通';
    return '天命所归';
  }

  // ============ 商品生成 ============

  /**
   * 根据福源生成集市商品列表
   * @param {number} fortune - 当前福源值
   * @returns {Array} 商品列表
   */
  _generateItems(fortune) {
    // 查找福源区间
    let tier = this._fortuneTiers[2]; // 默认 41-60
    for (const t of this._fortuneTiers) {
      if (fortune >= t.min && fortune <= t.max) { tier = t; break; }
    }
    if (fortune > 100) tier = this._fortuneTiers[4];

    this._slotCount = tier.slots;
    this._priceMultiplier = tier.priceMult;
    this._routeModifiers = typeof tradeRouteSystem !== 'undefined'
      ? tradeRouteSystem.getMarketModifiers()
      : null;
    if (this._routeModifiers) {
      this._slotCount = Math.max(2, Math.min(8, this._slotCount + this._routeModifiers.extraSlots));
      this._priceMultiplier *= this._routeModifiers.priceMultiplier;
    }

    // 从法宝池筛选可用法宝
    const pool = this._buildTreasurePool();
    if (pool.length === 0) return [];

    const items = [];
    const usedIds = new Set();
    let goldCount = 0;
    const maxGold = 2; // 金质最多2件

    for (let i = 0; i < this._slotCount && pool.length > 0; i++) {
      // 按权重决定稀有度
      let rarity = this._rollRarity(tier.weights);
      rarity = Math.max(1, Math.min(6, rarity + (this._routeModifiers?.rarityBias || 0)));
      if (rarity >= 5 && goldCount >= maxGold) rarity = 4; // 金质已达上限，降级

      // 从池中筛选匹配稀有度的法宝
      let candidates = pool.filter(t => t.rarity === rarity && !usedIds.has(t.id));
      const supplied = candidates.filter(t => (this._routeModifiers?.supply || []).includes(t.type));
      if (supplied.length > 0 && this._random() < 0.7) candidates = supplied;
      if (candidates.length === 0) {
        // 降级查找
        for (let r = rarity - 1; r >= 1; r--) {
          const fallbacks = pool.filter(t => t.rarity === r && !usedIds.has(t.id));
          if (fallbacks.length > 0) {
            const pick = fallbacks[Math.floor(this._random() * fallbacks.length)];
            items.push(this._buildMarketItem(pick));
            usedIds.add(pick.id);
            break;
          }
        }
      } else {
        const pick = candidates[Math.floor(this._random() * candidates.length)];
        items.push(this._buildMarketItem(pick));
        usedIds.add(pick.id);
        if (rarity >= 5) goldCount++;
      }
    }

    // 按稀有度降序排列
    items.sort((a, b) => b.rarity - a.rarity);
    return items;
  }

  /**
   * 构建可用的法宝池：
   * - 已拥有的法宝不出现在集市
   * - 高于当前境界的法宝不出
   */
  _buildTreasurePool() {
    const allTreasures = Object.values(treasureSystem.treasureDB);
    if (!allTreasures.length) return [];

    const ownedIds = new Set(treasureSystem.getOwnedIds());
    const realm = gameState.realm;
    const realmOrder = (gameState.config && gameState.config.realms && gameState.config.realms.order)
      || ['qi', 'foundation', 'golden', 'nascent', 'deity', 'tribulation'];
    const maxRealmIdx = realmOrder.indexOf(realm);

    return allTreasures.filter(t => {
      if (t?.storyOnly === true) return false;
      if (ownedIds.has(t.id)) return false;
      const itemIdx = realmOrder.indexOf(t.realm);
      if (itemIdx < 0) return false;
      return itemIdx <= maxRealmIdx;
    });
  }

  /**
   * 按权重掷骰决定稀有度
   * @param {number[]} weights - [白, 蓝, 紫, 金, 传说] 权重
   * @returns {number} 稀有度 2-6
   */
  _rollRarity(weights) {
    const roll = this._random();
    let cum = 0;
    // 下标0=白(2),1=蓝(3),2=紫(4),3=金(5),4=传说(6)
    for (let i = 0; i < weights.length; i++) {
      cum += weights[i];
      if (roll < cum) return i + 2;
    }
    return 2; // fallback 白
  }

  /**
   * 将treasure DB条目转为集市商品
   * 应用价格倍率
   */
  _buildMarketItem(treasure) {
    const baseRange = this._priceRanges[treasure.rarity] || this._priceRanges[2];
    const base = baseRange.min + Math.floor(this._random() * (baseRange.max - baseRange.min));
    const finalPrice = Math.floor(base * this._priceMultiplier);

    // 稀有度名称
    const rarityNames = { 1:'☆ 灰', 2:'★★ 白', 3:'★★★ 蓝', 4:'★★★★ 紫', 5:'★★★★★ 金', 6:'★★★★★★ 传说' };

    // 槽位类型标签
    const typeLabels = {
      weapon: '🗡️ 武器', armor: '🛡️ 防具',
      accessory: '📿 饰品', artifact: '🔮 秘宝',
      consumable: '📜 消耗', tool: '🔧 法器',
      material: '💎 材料', regen: '💧 回复'
    };

    return {
      ...treasure,
      type: 'treasure',
      treasureType: treasure.type,
      effect: { treasureId: treasure.id },
      displayPrice: finalPrice,
      rarityName: rarityNames[treasure.rarity] || '★★ 白',
      typeLabel: typeLabels[treasure.type] || '📦 杂物',
      _marketItem: true,
      tradeRouteId: this._routeModifiers?.route?.id || null
    };
  }

  // ============ 集市偶遇卡 ============

  _buildBazaarCard() {
    const location = String(gameState.currentLocation || '沿途驿道').trim() || '沿途驿道';
    return {
      id: 'bazaar_encounter',
      title: '行商到访 · 三摊开张',
      description: `商队在${location}外支起三盏不同的灯：药材、旧货和鉴物各占一席。摊主说得明白——买卖不占人情，但你若肯帮忙或打听，他们会记得。`,
      type: 'BAZAAR',
      realm: gameState.realm,
      weight: 0,
      once: false,
      choices: {
        left: {
          text: '循摊位逐一看看',
          effects: {},
          action: {
            type: 'ENTER_VENDOR',
            vendorId: 'public_bazaar',
            marketEncounter: true,
            resumePolicy: 'ON_VENDOR_CLOSED',
            settlePolicy: 'AFTER_CLOSE_EXACTLY_ONCE'
          },
          desc: '本次可做两次深度来往；购买与换物另行结算。'
        },
        right: {
          text: '记下商队旗号，继续赶路',
          effects: {},
          desc: '错过的摊主和线索会在这次到访结束后离开。'
        }
      }
    };
  }

  _buildMarketCard() {
    const tierText = this.getFortuneTierText();
    const fortune = gameState.attributes.fortune;
    const stone = gameState.resources.spiritStone;
    const route = this._routeModifiers?.route;

    const flavorTexts = [
      '你路过一座废弃坊市时，感到一阵空间波动——这不是普通的坊市，是鬼市。',
      '雾气中浮现一扇古铜门。门楣上写着"有缘者入"——你的福源微微发热。',
      '一阵阴风吹过，路边突然出现了几个摊铺。摊主不露脸，只露手——这是鬼市的规矩。',
      '你听到铃铛声。三声为号——鬼市开了。你正好走在那个时辰、那个地点。',
    ];
    const flavor = flavorTexts[Math.floor(this._random() * flavorTexts.length)];

    return {
      id: 'market_encounter',
      title: `🏪 鬼市偶遇 — ${tierText}`,
      description: flavor + `\n\n${route ? `🧭 本次货源：${route.name}（通畅${route.openness} / 风险${route.danger}）\n${route.flavor}\n\n` : ''}🕯️ 当前福源: ${fortune} | 灵石: ${stone}`,
      type: 'MARKET',
      realm: gameState.realm,
      weight: 0,
      once: false,
      choices: {
        left: {
          text: '进去逛逛',
          effects: {},
          action: {
            type: 'ENTER_VENDOR',
            vendorId: 'ghost_market',
            marketEncounter: true,
            resumePolicy: 'ON_VENDOR_CLOSED',
            settlePolicy: 'AFTER_CLOSE_EXACTLY_ONCE'
          },
          desc: `踏入鬼市大门。以你${tierText}的运道，可刷出 ${this._slotCount} 件商品。`
        },
        right: {
          text: '绕道而行',
          effects: {},
          desc: '鬼市虽有好货，但也可能沾上不干净的东西。还是赶路要紧。'
        }
      }
    };
  }

  // ============ 辅助 ============

  getState() {
    return {
      lastBazaarDecisionIndex: this._lastBazaarTurn,
      nextBazaarDecisionIndex: this._nextBazaarTurn,
      lastMarketTurn: this._lastMarketTurn,
      nextMarketTurn: this._nextMarketTurn,
      lastGhostDecisionIndex: this._lastMarketTurn,
      nextGhostDecisionIndex: this._nextMarketTurn,
      totalVisits: this._totalVisits,
      slotCount: this._slotCount,
      priceMultiplier: this._priceMultiplier,
      currentItemCount: this._currentItems.length,
      fortuneTier: this.getFortuneTierText(),
      tradeRoute: this._routeModifiers?.route || null
    };
  }

  _generateGhostItems(fortune) {
    const profile = this.getVendorProfile('ghost_market');
    const risk = profile?.riskRules || {};
    const hiddenRate = Math.max(0.25, Math.min(0.40, Number(risk.hiddenTraitRate) || 0.30));
    // A ghost visit offers fewer things than the bazaar, and a 3–5 item set
    // always seals 25%–40% of them. This is stronger than an independent
    // probability roll: a particular visit can never accidentally expose no
    // unknown cost, which would turn that visit back into an ordinary shop.
    const source = this._generateItems(fortune).slice(0, 5);
    const sealedCount = source.length > 0
      ? Math.max(1, Math.min(source.length, Math.round(source.length * hiddenRate)))
      : 0;
    const sealedIndexes = new Set();
    while (sealedIndexes.size < sealedCount) sealedIndexes.add(Math.floor(this._random() * source.length));
    const hiddenOrigins = [
      '封签下有一段被抹去的前主名字。',
      '禁纹在夜气里反复指向一条未标商路。',
      '器纹里夹着债主留下的半枚收据。'
    ];
    return source.map((item, index) => {
      const multiplier = 1.10 + this._random() * 0.50;
      const displayPrice = Math.max(1, Math.ceil((Number(item.displayPrice ?? item.price) || 1) * multiplier));
      const hiddenTrait = sealedIndexes.has(index)
        ? {
            status: 'sealed',
            inspection: '需要交出一份商路线索，才能验看此物的来路。',
            revealedText: hiddenOrigins[Math.floor(this._random() * hiddenOrigins.length)]
          }
        : null;
      return { ...item, displayPrice, price: displayPrice, ghostMarkup: multiplier, hiddenTrait };
    });
  }

  exportState() {
    return this._clone(this._marketState());
  }

  hydrateState(snapshot) {
    const state = this._state();
    if (!state || !snapshot || typeof snapshot !== 'object' || Array.isArray(snapshot)) return false;
    const fallback = this._decisionIndex();
    const normalize = typeof state._normalizeMarketState === 'function'
      ? value => state._normalizeMarketState(value, { fallbackDecisionIndex: fallback, migrationSource: 'legacy_clock' })
      : value => ({ ...this._marketState(), ...this._clone(value) });
    state.marketState = normalize(snapshot);
    return true;
  }

  _log(msg) {
    if (this.onLog) this.onLog(msg);
  }
}

// 全局单例
const marketSystem = new MarketSystem();
