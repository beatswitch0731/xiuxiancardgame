/**
 * NarrativeLedger — one-life narrative identity and repeat-policy authority.
 *
 * Card IDs identify runtime payloads. semanticKey identifies the story beat.
 * Producers and schedulers ask this ledger before surfacing narrative content;
 * successful `card:chosen` events record the beat exactly once at the shared
 * settlement boundary.
 */
class NarrativeLedger {
  constructor(options = {}) {
    this.gameStateRef = options.gameStateRef || null;
    this.eventBusRef = options.eventBusRef || null;
    this.entries = new Map();
    this.promises = new Map();
    // Facts are not a second story queue. They are durable, authored evidence
    // that a named downstream consumer may settle exactly once.
    this.facts = new Map();
    this.consumptionsByKey = new Map();
    this.causalGraph = new Map();
    this.version = 6;
    this._initialized = false;
    this._cardResolver = null;
  }

  _state() {
    if (this.gameStateRef) return this.gameStateRef;
    return typeof gameState !== 'undefined' ? gameState : null;
  }

  _bus() {
    if (this.eventBusRef) return this.eventBusRef;
    return typeof eventBus !== 'undefined' ? eventBus : null;
  }

  _decisionIndex(options = {}) {
    const state = options.state || this._state() || {};
    // `turn` is accepted only as a legacy caller alias; persisted records use
    // decisionIndex exclusively.
    const explicit = options.decisionIndex ?? options.turn;
    if (Number.isFinite(Number(explicit))) return Math.max(0, Math.floor(Number(explicit)));
    if (options.next === true && typeof state.getNextDecisionIndex === 'function') {
      return Math.max(0, Math.floor(Number(state.getNextDecisionIndex()) || 0));
    }
    if (typeof state.getDecisionIndex === 'function') {
      return Math.max(0, Math.floor(Number(state.getDecisionIndex()) || 0));
    }
    return Math.max(0, Math.floor(Number(state.runClock?.decisionIndex ?? state.turn) || 0));
  }

  init(options = {}) {
    if (typeof options.cardResolver === 'function') this._cardResolver = options.cardResolver;
    if (options.causalGraph) this.loadCausalGraph(options.causalGraph);
    const state = this._state();
    if (!this._initialized) {
      const snapshot = state?.narrativeLedgerState;
      if (snapshot && typeof snapshot === 'object') {
        this.hydrateState(snapshot);
        this.reconcilePlayedSemanticKeys(state?.cardsPlayed || []);
      } else {
        this.migrateCardsPlayed(state?.cardsPlayed || [], { persist: false });
      }

      const bus = this._bus();
      if (bus?.on) {
        bus.on('card:chosen', data => {
          if (data?.card) this.recordResolved(data.card);
        });
        bus.on('state:reset', () => this.resetForNewLife());
      }
      this._initialized = true;
    }
    return true;
  }

  loadCausalGraph(data) {
    this.causalGraph.clear();
    const source = data && typeof data === 'object' && !Array.isArray(data) ? data : {};
    for (const raw of Array.isArray(source.factTypes) ? source.factTypes : []) {
      const factTypeId = typeof raw?.factTypeId === 'string' ? raw.factTypeId.trim() : '';
      if (!factTypeId || this.causalGraph.has(factTypeId)) continue;
      const consumers = [];
      for (const candidate of Array.isArray(raw.consumers) ? raw.consumers : []) {
        const consumerId = typeof candidate?.consumerId === 'string' ? candidate.consumerId.trim() : '';
        const vendorId = typeof candidate?.vendorId === 'string' ? candidate.vendorId.trim() : '';
        if (!consumerId || !vendorId || consumers.some(entry => entry.consumerId === consumerId)) continue;
        const mode = candidate?.mode === 'observe' ? 'observe' : 'settle_once';
        const isObserver = mode === 'observe';
        const earliestDecisionOffset = Math.max(0, Math.floor(Number(candidate.earliestDecisionOffset) || 0));
        const latestDecisionOffset = Math.max(earliestDecisionOffset,
          Math.floor(Number(candidate.latestDecisionOffset) || earliestDecisionOffset));
        consumers.push({
          consumerId,
          vendorId,
          mode,
          earliestDecisionOffset,
          latestDecisionOffset,
          label: typeof candidate.label === 'string' ? candidate.label : '登记凭据',
          description: typeof candidate.description === 'string' ? candidate.description : '',
          receiptText: isObserver ? '' : (typeof candidate.receiptText === 'string' ? candidate.receiptText : '凭据已登记。'),
          terminalClosure: isObserver ? '' : (typeof candidate.terminalClosure === 'string' && candidate.terminalClosure.trim()
            ? candidate.terminalClosure.trim()
            : '这份凭据已过期。'),
          costSpec: !isObserver && Array.isArray(candidate.costSpec) ? this._clone(candidate.costSpec) : [],
          delivery: !isObserver && candidate.delivery && typeof candidate.delivery === 'object' && !Array.isArray(candidate.delivery)
            ? this._clone(candidate.delivery) : null,
          presentationByPayload: !isObserver && candidate.presentationByPayload
            && typeof candidate.presentationByPayload === 'object' && !Array.isArray(candidate.presentationByPayload)
            ? this._clone(candidate.presentationByPayload) : null,
          narrative: !isObserver && candidate.narrative && typeof candidate.narrative === 'object' && !Array.isArray(candidate.narrative)
            ? this._clone(candidate.narrative) : null
        });
      }
      // A fact may be a terminal provenance receipt with no further consumer.
      // It is still authored state and must remain recordable and reloadable.
      this.causalGraph.set(factTypeId, { factTypeId, consumers });
    }
    return this.causalGraph.size;
  }

  getCausalFactDefinition(factTypeId) {
    const definition = this.causalGraph.get(factTypeId);
    return definition ? this._clone(definition) : null;
  }

  _factInstanceId(factTypeId, lifeCount) {
    return `fact:${Math.max(0, Math.floor(Number(lifeCount) || 0))}:${factTypeId}`;
  }

  getFact(factInstanceId) {
    const fact = this.facts.get(factInstanceId);
    return fact ? this._clone(fact) : null;
  }

  getFactByType(factTypeId) {
    const lifeCount = Math.max(0, Number(this._state()?.getLifeCount?.() || this._state()?.unlocks?.lifeCount || 0));
    return this.getFact(this._factInstanceId(factTypeId, lifeCount));
  }

  hasFactTypeForLife(factTypeId) {
    return Boolean(this.getFactByType(factTypeId));
  }

  recordFact(definition = {}) {
    const factTypeId = typeof definition.factTypeId === 'string' ? definition.factTypeId.trim() : '';
    const catalog = this.causalGraph.get(factTypeId);
    if (!factTypeId || !catalog) return { created: false, reason: 'unknown_fact_type', fact: null };
    const state = definition.state || this._state() || {};
    const lifeCount = Math.max(0, Number(state.getLifeCount?.() || state.unlocks?.lifeCount || 0));
    const factInstanceId = this._factInstanceId(factTypeId, lifeCount);
    const existing = this.facts.get(factInstanceId);
    if (existing) return { created: false, reason: 'duplicate_fact', fact: this._clone(existing) };
    const fact = {
      factInstanceId,
      factTypeId,
      lifeCount,
      status: 'active',
      producerId: typeof definition.producerId === 'string' ? definition.producerId : null,
      payload: definition.payload && typeof definition.payload === 'object' ? this._clone(definition.payload) : {},
      createdDecisionIndex: this._decisionIndex({ state, decisionIndex: definition.decisionIndex }),
      terminalClosure: null,
      closedDecisionIndex: null
    };
    this.facts.set(factInstanceId, fact);
    if (definition.persist !== false) this._persist();
    this._bus()?.emit?.('narrative:factCreated', { fact: this._clone(fact) });
    return { created: true, reason: null, fact: this._clone(fact) };
  }

  _consumerFor(fact, consumerId) {
    const definition = fact ? this.causalGraph.get(fact.factTypeId) : null;
    return definition?.consumers?.find(candidate => candidate.consumerId === consumerId) || null;
  }

  _consumptionKey(factInstanceId, consumerId) {
    return `${factInstanceId}:${consumerId}`;
  }

  getEligibleConsumerFacts({ consumerId, vendorId, decisionIndex } = {}) {
    const index = this._decisionIndex({ decisionIndex });
    return [...this.facts.values()].flatMap(fact => {
      if (fact.status !== 'active') return [];
      const definition = this.causalGraph.get(fact.factTypeId);
      const candidates = consumerId
        ? [this._consumerFor(fact, consumerId)].filter(Boolean)
        : (definition?.consumers || []);
      return candidates.flatMap(consumer => {
        if (consumer.mode === 'observe') return [];
        if (vendorId && consumer.vendorId !== vendorId) return [];
        const key = this._consumptionKey(fact.factInstanceId, consumer.consumerId);
        if (this.consumptionsByKey.has(key)) return [];
        const earliest = fact.createdDecisionIndex + consumer.earliestDecisionOffset;
        const latest = fact.createdDecisionIndex + consumer.latestDecisionOffset;
        if (index < earliest || index > latest) return [];
        return [{
          factInstanceId: fact.factInstanceId,
          factTypeId: fact.factTypeId,
          payload: this._clone(fact.payload),
          createdDecisionIndex: fact.createdDecisionIndex,
          consumer: this._clone(consumer),
          earliestDecisionIndex: earliest,
          latestDecisionIndex: latest
        }];
      });
    });
  }

  getClosedConsumerFacts({ consumerId, vendorId } = {}) {
    return [...this.facts.values()].flatMap(fact => {
      if (fact.status !== 'closed') return [];
      const definition = this.causalGraph.get(fact.factTypeId);
      const candidates = consumerId
        ? [this._consumerFor(fact, consumerId)].filter(Boolean)
        : (definition?.consumers || []);
      return candidates.flatMap(consumer => {
        if (consumer.mode === 'observe') return [];
        if (vendorId && consumer.vendorId !== vendorId) return [];
        return [{
          factInstanceId: fact.factInstanceId,
          factTypeId: fact.factTypeId,
          terminalClosure: fact.terminalClosure || consumer.terminalClosure,
          consumer: this._clone(consumer)
        }];
      });
    });
  }

  /**
   * Read same-life provenance without making it eligible for Flow or changing
   * its settlement status.  This is deliberately narrower than getFact(): an
   * authored observer may read only the fact types that explicitly name it.
   */
  getObservedFacts({ consumerId, vendorId, factTypeIds } = {}) {
    const requestedTypes = Array.isArray(factTypeIds)
      ? new Set(factTypeIds.filter(value => typeof value === 'string' && value))
      : null;
    const currentLife = Math.max(0, Number(
      this._state()?.getLifeCount?.() || this._state()?.unlocks?.lifeCount || 0
    ));
    if (typeof consumerId !== 'string' || !consumerId) return [];
    return [...this.facts.values()].flatMap(fact => {
      if (fact.lifeCount !== currentLife) return [];
      if (requestedTypes && !requestedTypes.has(fact.factTypeId)) return [];
      if (!['active', 'consumed', 'closed'].includes(fact.status)) return [];
      const consumer = this._consumerFor(fact, consumerId);
      if (!consumer || consumer.mode !== 'observe') return [];
      if (vendorId && consumer.vendorId !== vendorId) return [];
      return [{
        factInstanceId: fact.factInstanceId,
        factTypeId: fact.factTypeId,
        status: fact.status,
        producerId: fact.producerId,
        payload: this._clone(fact.payload),
        createdDecisionIndex: fact.createdDecisionIndex,
        observer: this._clone(consumer)
      }];
    });
  }

  consumeFact({ factInstanceId, consumerId, decisionIndex, receipt, persist = true } = {}) {
    const fact = this.facts.get(factInstanceId);
    if (!fact) return { consumed: false, reason: 'missing_fact', fact: null };
    const consumer = this._consumerFor(fact, consumerId);
    if (!consumer) return { consumed: false, reason: 'unknown_consumer', fact: this._clone(fact) };
    if (consumer.mode === 'observe') {
      return { consumed: false, reason: 'read_only_consumer', fact: this._clone(fact) };
    }
    if (fact.status !== 'active') {
      return { consumed: false, reason: 'fact_not_active', fact: this._clone(fact) };
    }
    const index = this._decisionIndex({ decisionIndex });
    const earliest = fact.createdDecisionIndex + consumer.earliestDecisionOffset;
    const latest = fact.createdDecisionIndex + consumer.latestDecisionOffset;
    if (index < earliest || index > latest) return { consumed: false, reason: 'consumer_outside_window', fact: this._clone(fact) };
    const key = this._consumptionKey(factInstanceId, consumerId);
    if (this.consumptionsByKey.has(key)) return { consumed: false, reason: 'already_consumed', fact: this._clone(fact) };
    const consumption = {
      factInstanceId,
      factTypeId: fact.factTypeId,
      consumerId,
      consumedDecisionIndex: index,
      receipt: receipt && typeof receipt === 'object' ? this._clone(receipt) : {}
    };
    this.consumptionsByKey.set(key, consumption);
    fact.status = 'consumed';
    fact.consumedDecisionIndex = index;
    fact.consumedBy = consumerId;
    if (persist) this._persist();
    this._bus()?.emit?.('narrative:factConsumed', { fact: this._clone(fact), consumption: this._clone(consumption) });
    return { consumed: true, reason: null, fact: this._clone(fact), consumption: this._clone(consumption) };
  }

  closeExpiredFacts({ decisionIndex, persist = true } = {}) {
    const index = this._decisionIndex({ decisionIndex });
    const closed = [];
    for (const fact of this.facts.values()) {
      if (fact.status !== 'active') continue;
      const definition = this.causalGraph.get(fact.factTypeId);
      const settleConsumers = (definition?.consumers || []).filter(consumer => consumer.mode !== 'observe');
      if (!settleConsumers.length) continue;
      const stillOpen = settleConsumers.some(consumer => (
        !this.consumptionsByKey.has(this._consumptionKey(fact.factInstanceId, consumer.consumerId))
        && index <= fact.createdDecisionIndex + consumer.latestDecisionOffset
      ));
      if (stillOpen) continue;
      const terminal = settleConsumers.find(consumer => (
        !this.consumptionsByKey.has(this._consumptionKey(fact.factInstanceId, consumer.consumerId))
      ));
      fact.status = 'closed';
      fact.closedDecisionIndex = index;
      fact.terminalClosure = terminal?.terminalClosure || '这条线索已无从追查。';
      closed.push(this._clone(fact));
    }
    if (closed.length && persist) this._persist();
    for (const fact of closed) this._bus()?.emit?.('narrative:factClosed', { fact });
    return { closed: closed.length, facts: closed };
  }

  getSemanticKey(card) {
    if (!card || typeof card !== 'object') return null;
    if (typeof card.semanticKey === 'string' && card.semanticKey.trim()) {
      return card.semanticKey.trim();
    }

    const id = typeof card.id === 'string' ? card.id.trim() : '';
    if (!id) return null;

    const companionStage = id.match(/^arc_(.+)_stage_([A-Z_]+)$/);
    if (companionStage) return `arc:${companionStage[1]}:${companionStage[2]}`;
    const roleStage = id.match(/^(mentor|seer|ally)_(.+)_stage_([A-Z_]+)$/);
    if (roleStage) return `arc:${roleStage[2]}:${roleStage[3]}`;

    if (card.type === 'NPC_CROSS' && Array.isArray(card.npcIds) && card.npcIds.length >= 2) {
      const pair = [...new Set(card.npcIds.filter(Boolean))].sort();
      const status = card.relationStatus || card.status || 'neutral';
      if (pair.length >= 2) return `npc-cross:${pair.join(':')}:${status}`;
    }
    return `card:${id}`;
  }

  getRepeatPolicy(card) {
    if (!card || typeof card !== 'object') return { mode: 'unrestricted', cooldownTurns: 0 };
    if (card.once === true) return { mode: 'once', cooldownTurns: 0 };

    const declared = card.repeatPolicy;
    const mode = typeof declared === 'string'
      ? declared
      : (declared && typeof declared === 'object' ? declared.mode : null);
    if (mode === 'once') return { mode: 'once', cooldownTurns: 0 };
    if (mode === 'cooldown') {
      const raw = Number(declared?.cooldownTurns ?? card.cooldownTurns ?? 12);
      return {
        mode: 'cooldown',
        cooldownTurns: Math.max(1, Math.floor(Number.isFinite(raw) ? raw : 12))
      };
    }

    const narrativeTypes = new Set([
      'STORY', 'NPC_ENCOUNTER', 'NPC_CROSS', 'COMPANION_EVENT',
      'COMPANION_ARC', 'MENTOR_ARC', 'SEER_ARC', 'ALLY_ARC',
      'FACTION_EVENT', 'LOCATION', 'EMERGENT', 'SURFACING', 'CHOICE_ECHO'
    ]);
    if (narrativeTypes.has(card.type)) return { mode: 'cooldown', cooldownTurns: 12 };
    return { mode: 'unrestricted', cooldownTurns: 0 };
  }

  evaluate(card, options = {}) {
    if (!card || typeof card !== 'object' || !card.id) {
      return { allowed: false, reason: 'invalid_card', semanticKey: null };
    }
    const state = options.state || this._state() || {};
    const semanticKey = this.getSemanticKey(card);
    if (card.requiresResolvedSemanticKeys !== undefined) {
      const required = card.requiresResolvedSemanticKeys;
      if (!Array.isArray(required) || required.length === 0
        || required.some(key => typeof key !== 'string' || !key.trim())) {
        return { allowed: false, reason: 'invalid_semantic_prerequisite', semanticKey };
      }
      if (required.some(key => Number(this.entries.get(key)?.resolvedCount) <= 0
        || !this.entries.has(key))) {
        return { allowed: false, reason: 'semantic_prerequisite_missing', semanticKey };
      }
    }
    const physical = (card.manifestation || 'PHYSICAL') === 'PHYSICAL';
    const npcIds = [...new Set([
      card.npcId,
      card.compId,
      ...(Array.isArray(card.npcIds) ? card.npcIds : [])
    ].filter(Boolean))];
    const continuity = typeof worldContinuityStore !== 'undefined' ? worldContinuityStore : null;
    if (physical && continuity && npcIds.some(id => (
      typeof continuity.canManifest === 'function'
        ? !continuity.canManifest(id, 'PHYSICAL')
        : (typeof continuity.canPhysicallyAppear === 'function' && !continuity.canPhysicallyAppear(id))
    ))) {
      return { allowed: false, reason: 'npc_not_physical', semanticKey };
    }

    if (physical && card.requiresPlayerPresence === true && card.location
      && !this.areLocationsCompatible(state.currentLocation, card.location)) {
      return { allowed: false, reason: 'player_location_mismatch', semanticKey };
    }

    if (Array.isArray(card.eligibleRealms) && card.eligibleRealms.length > 0
      && !card.eligibleRealms.includes(state.realm)) {
      return { allowed: false, reason: 'realm_mismatch', semanticKey };
    }

    const policy = this.getRepeatPolicy(card);
    const entry = semanticKey ? this.entries.get(semanticKey) : null;
    if (policy.mode === 'once' && entry?.resolvedCount > 0) {
      return { allowed: false, reason: 'semantic_once_resolved', semanticKey, policy, entry: { ...entry } };
    }
    if (policy.mode === 'cooldown' && entry && (entry.lastResolvedDecisionIndex !== undefined || entry.lastResolvedTurn !== undefined)) {
      const decisionIndex = this._decisionIndex({
        state,
        decisionIndex: options.decisionIndex ?? options.turn
      });
      const resolvedAt = Math.max(0, Math.floor(Number(
        entry.lastResolvedDecisionIndex ?? entry.lastResolvedTurn
      ) || 0));
      if (decisionIndex - resolvedAt < policy.cooldownTurns) {
        return { allowed: false, reason: 'semantic_cooldown', semanticKey, policy, entry: { ...entry } };
      }
    }
    return { allowed: true, reason: null, semanticKey, policy, entry: entry ? { ...entry } : null };
  }

  canPresent(card, options = {}) {
    return this.evaluate(card, options).allowed;
  }

  recordResolved(card, options = {}) {
    if (!card || typeof card !== 'object' || !card.id) return false;
    const policy = this.getRepeatPolicy(card);
    const semanticKey = this.getSemanticKey(card);
    if (!semanticKey || (policy.mode === 'unrestricted' && !card.semanticKey)) return false;

    const state = options.state || this._state() || {};
    const decisionIndex = this._decisionIndex({
      state,
      decisionIndex: options.decisionIndex,
      next: options.decisionIndex === undefined && options.turn === undefined
    });
    const previous = this.entries.get(semanticKey) || {
      semanticKey,
      resolvedCount: 0,
      firstResolvedDecisionIndex: decisionIndex,
      lastResolvedDecisionIndex: decisionIndex,
      lastCardId: card.id,
      policy: policy.mode,
      cooldownTurns: policy.cooldownTurns || 0,
      cardIds: []
    };
    const previousFirstDecision = Number(previous.firstResolvedDecisionIndex ?? previous.firstResolvedTurn);
    const cardIds = [...new Set([...(previous.cardIds || []), card.id])].slice(-12);
    this.entries.set(semanticKey, {
      ...previous,
      resolvedCount: Math.max(0, Number(previous.resolvedCount) || 0) + 1,
      firstResolvedDecisionIndex: Math.min(
        decisionIndex,
        Number.isFinite(previousFirstDecision) ? previousFirstDecision : decisionIndex
      ),
      lastResolvedDecisionIndex: decisionIndex,
      lastCardId: card.id,
      policy: policy.mode,
      cooldownTurns: policy.cooldownTurns || 0,
      cardIds
    });
    if (options.persist !== false) this._persist();
    return true;
  }

  _choiceCount() {
    const history = this._state()?.choiceHistory;
    return Array.isArray(history) ? history.length : 0;
  }

  _clone(value) {
    if (value === undefined) return undefined;
    return JSON.parse(JSON.stringify(value));
  }

  _isValidPromiseCard(card) {
    if (!card || typeof card !== 'object') return false;
    if (typeof card.id !== 'string' || !card.id.trim()) return false;
    if (typeof card.title !== 'string' || !card.title.trim()) return false;
    if (typeof card.description !== 'string' || !card.description.trim()) return false;
    if (!card.choices || typeof card.choices !== 'object') return false;
    return Object.values(card.choices).some(choice => (
      choice && typeof choice === 'object'
      && typeof choice.text === 'string' && choice.text.trim()
    ));
  }

  createPromise(definition, context = {}) {
    const def = definition && typeof definition === 'object' ? definition : {};
    const id = typeof def.id === 'string' ? def.id.trim() : '';
    if (!id) return { created: false, reason: 'invalid_promise_id', promise: null };
    if (!this._isValidPromiseCard(def.followUpCard)) {
      return { created: false, reason: 'invalid_follow_up', promise: null };
    }
    const existing = this.promises.get(id);
    if (existing) {
      return { created: false, reason: 'duplicate_promise', promise: this._clone(existing) };
    }

    const state = context.state || this._state() || {};
    const dueWithinDecisions = Math.max(0, Math.min(2,
      Math.floor(Number(def.dueWithinDecisions) || 0)));
    const record = {
      id,
      status: 'pending',
      kind: typeof def.kind === 'string' && def.kind ? def.kind : 'PROMISE',
      closureEligible: def.closureEligible !== false,
      lifeCount: Math.max(0, Number(state.getLifeCount?.() || state.unlocks?.lifeCount || 0)),
      sourceCardId: typeof def.sourceCardId === 'string' ? def.sourceCardId : null,
      sourceSemanticKey: typeof def.sourceSemanticKey === 'string' ? def.sourceSemanticKey : null,
      sourceTitle: typeof def.sourceTitle === 'string' ? def.sourceTitle : null,
      choiceDirection: typeof def.choiceDirection === 'string' ? def.choiceDirection : null,
      createdDecisionIndex: this._decisionIndex({
        state,
        decisionIndex: def.createdDecisionIndex,
        next: def.createdDecisionIndex === undefined
      }),
      dueWithinDecisions,
      dueDecisionIndex: 0,
      followUpCardId: def.followUpCard.id,
      followUpCard: this._clone(def.followUpCard),
      closureCard: this._isValidPromiseCard(def.closureCard) ? this._clone(def.closureCard) : null,
      resolvedDecisionIndex: null,
      resolutionCardId: null,
      expirationReason: null
    };
    record.dueDecisionIndex = record.createdDecisionIndex + dueWithinDecisions;
    this.promises.set(id, record);
    if (context.persist !== false) this._persist();
    this._bus()?.emit?.('narrative:promiseCreated', { promise: this._clone(record) });
    return { created: true, reason: null, promise: this._clone(record) };
  }

  getPromise(id) {
    const record = this.promises.get(id);
    return record ? this._clone(record) : null;
  }

  getPendingPromises() {
    return [...this.promises.values()]
      .filter(record => record.status === 'pending' || record.status === 'closing')
      .map(record => this._clone(record));
  }

  markPromiseClosing(id, context = {}) {
    const record = this.promises.get(id);
    if (!record || record.status !== 'pending') {
      return { closing: false, reason: record ? 'not_pending' : 'missing_promise', promise: record ? this._clone(record) : null };
    }
    record.status = 'closing';
    record.expirationReason = typeof context.reason === 'string' && context.reason
      ? context.reason
      : 'due_window_elapsed';
    if (context.closureCard && this._isValidPromiseCard(context.closureCard)) {
      record.closureCard = this._clone(context.closureCard);
    }
    if (context.persist !== false) this._persist();
    this._bus()?.emit?.('narrative:promiseExpired', {
      promise: this._clone(record),
      reason: record.expirationReason
    });
    return { closing: true, reason: null, promise: this._clone(record) };
  }

  resolvePromise(id, context = {}) {
    const record = this.promises.get(id);
    if (!record) return { resolved: false, reason: 'missing_promise', promise: null };
    if (record.status === 'resolved') {
      return { resolved: false, reason: 'already_resolved', promise: this._clone(record) };
    }
    if (record.status !== 'pending' && record.status !== 'closing') {
      return { resolved: false, reason: 'not_resolvable', promise: this._clone(record) };
    }
    record.status = 'resolved';
    record.resolvedDecisionIndex = this._decisionIndex({
      state: context.state,
      decisionIndex: context.decisionIndex,
      next: context.decisionIndex === undefined
    });
    record.resolutionCardId = typeof context.resolutionCardId === 'string'
      ? context.resolutionCardId
      : null;
    if (context.persist !== false) this._persist();
    this._bus()?.emit?.('narrative:promiseResolved', { promise: this._clone(record) });
    return { resolved: true, reason: null, promise: this._clone(record) };
  }

  migrateCardsPlayed(cardIds, options = {}) {
    if (!Array.isArray(cardIds) || cardIds.length === 0) return 0;
    let migrated = 0;
    for (const id of [...new Set(cardIds.filter(value => typeof value === 'string' && value))]) {
      const resolved = this._cardResolver ? this._cardResolver(id) : null;
      const card = resolved || { id, once: true };
      if (this.recordResolved(card, { decisionIndex: this._decisionIndex(), persist: false })) migrated++;
    }
    if (migrated > 0 && options.persist !== false) this._persist();
    return migrated;
  }

  reconcilePlayedSemanticKeys(cardIds) {
    if (!Array.isArray(cardIds) || typeof this._cardResolver !== 'function') return 0;
    let migrated = 0;
    for (const id of [...new Set(cardIds.filter(value => typeof value === 'string' && value))]) {
      const card = this._cardResolver(id);
      const key = typeof card?.semanticKey === 'string' ? card.semanticKey.trim() : '';
      if (!key) continue;
      const oldKey = `card:${id}`;
      const oldEntry = this.entries.get(oldKey);
      const currentEntry = this.entries.get(key);
      if (!oldEntry && currentEntry) continue;
      if (!oldEntry) {
        this.recordResolved(card, { decisionIndex: this._decisionIndex(), persist: false });
        migrated++;
        continue;
      }
      const entries = [oldEntry, currentEntry].filter(Boolean);
      const first = Math.min(...entries.map(entry => Number(entry.firstResolvedDecisionIndex) || 0));
      const last = Math.max(...entries.map(entry => Number(entry.lastResolvedDecisionIndex) || 0));
      const policy = this.getRepeatPolicy(card);
      this.entries.set(key, {
        ...oldEntry,
        ...currentEntry,
        semanticKey: key,
        resolvedCount: Math.max(...entries.map(entry => Number(entry.resolvedCount) || 0)),
        firstResolvedDecisionIndex: first,
        lastResolvedDecisionIndex: last,
        lastCardId: currentEntry?.lastCardId || oldEntry.lastCardId || id,
        policy: policy.mode,
        cooldownTurns: policy.cooldownTurns || 0,
        cardIds: [...new Set(entries.flatMap(entry => entry.cardIds || []).concat(id))].slice(-12)
      });
      this.entries.delete(oldKey);
      migrated++;
    }
    if (migrated > 0) this._persist();
    return migrated;
  }

  _locationTags(rawLocation) {
    const text = String(rawLocation || '').trim();
    if (!text) return new Set();
    const tags = new Set([`exact:${text}`]);
    const add = (...values) => values.forEach(value => tags.add(value));
    if (/宗门|青云剑宗|宗门大殿|演武场|闭关室|山门|剑崖|剑冢|裂石山径/.test(text)) add('region:sect');
    if (/剑崖|剑冢/.test(text)) add('place:sword-cliff');
    if (/坊市|万宝楼|灵草街|铁匠铺/.test(text)) add('region:market');
    if (/秘境|遗迹|试炼通道|灵脉矿洞|古修洞府/.test(text)) add('region:ruins');
    if (/魔域|血煞|西域|血砂|白骨荒野/.test(text)) add('region:demon');
    if (/洞府|炼气室|丹房|剑室|灵兽棚/.test(text)) add('region:cave');
    if (/天道虚空|天道裂缝|因果之海|时间回廊|混沌虚空/.test(text)) add('region:void');
    if (/南疆|白狐部|月湖|狐丘/.test(text)) add('region:foxlands');
    if (/天枢道院|万卷楼|天道书/.test(text)) add('region:tianshu');
    if (/天机阁|观星台/.test(text)) add('region:tianji');
    if (/神农丹谷|药王谷|禁药堂|药谷/.test(text)) add('region:dangu');
    if (/武盟|万钧瀑布|天雷峰|地火窟/.test(text)) add('region:wumeng');
    if (/云中城/.test(text)) add('region:upper');
    return tags;
  }

  areLocationsCompatible(playerLocation, eventLocation) {
    const player = this._locationTags(playerLocation);
    const event = this._locationTags(eventLocation);
    if (player.size === 0 || event.size === 0) return false;
    for (const tag of player) {
      if (event.has(tag)) return true;
    }
    return false;
  }

  exportState() {
    return {
      version: this.version,
      lifeCount: Math.max(0, Number(this._state()?.getLifeCount?.() || this._state()?.unlocks?.lifeCount || 0)),
      entries: Object.fromEntries([...this.entries.entries()].map(([key, value]) => [key, {
        ...value,
        cardIds: Array.isArray(value.cardIds) ? [...value.cardIds] : []
      }])),
      promises: Object.fromEntries([...this.promises.entries()].map(([key, value]) => [key, this._clone(value)])),
      facts: Object.fromEntries([...this.facts.entries()].map(([key, value]) => [key, this._clone(value)])),
      consumptionsByKey: Object.fromEntries([...this.consumptionsByKey.entries()].map(([key, value]) => [key, this._clone(value)]))
    };
  }

  hydrateState(snapshot) {
    if (!snapshot || typeof snapshot !== 'object') return false;
    const currentLife = Math.max(0, Number(this._state()?.getLifeCount?.() || this._state()?.unlocks?.lifeCount || 0));
    if (snapshot.lifeCount !== undefined && Number(snapshot.lifeCount) !== currentLife) {
      this.resetForNewLife();
      return false;
    }
    this.entries = new Map();
    this.promises = new Map();
    this.facts = new Map();
    this.consumptionsByKey = new Map();
    for (const [key, raw] of Object.entries(snapshot.entries || {})) {
      if (!key || !raw || typeof raw !== 'object') continue;
      this.entries.set(key, {
        semanticKey: key,
        resolvedCount: Math.max(0, Math.floor(Number(raw.resolvedCount) || 0)),
        firstResolvedDecisionIndex: Math.max(0, Math.floor(Number(
          raw.firstResolvedDecisionIndex ?? raw.firstResolvedTurn
        ) || 0)),
        lastResolvedDecisionIndex: Math.max(0, Math.floor(Number(
          raw.lastResolvedDecisionIndex ?? raw.lastResolvedTurn
        ) || 0)),
        lastCardId: typeof raw.lastCardId === 'string' ? raw.lastCardId : null,
        policy: ['once', 'cooldown', 'unrestricted'].includes(raw.policy) ? raw.policy : 'once',
        cooldownTurns: Math.max(0, Math.floor(Number(raw.cooldownTurns) || 0)),
        cardIds: [...new Set((Array.isArray(raw.cardIds) ? raw.cardIds : []).filter(id => typeof id === 'string'))].slice(-12)
      });
    }
    // v1 snapshots have no promises. They migrate to an intentionally empty
    // promise map rather than inventing causality from old numeric effects.
    if (Number(snapshot.version) >= 2) {
      for (const [key, raw] of Object.entries(snapshot.promises || {})) {
        if (!key || !raw || typeof raw !== 'object') continue;
        if (!['pending', 'closing', 'resolved'].includes(raw.status)) continue;
        if (!this._isValidPromiseCard(raw.followUpCard)) continue;
        const hasDecisionClock = Number(snapshot.version) >= 3
          && Number.isFinite(Number(raw.createdDecisionIndex))
          && Number.isFinite(Number(raw.dueDecisionIndex));
        const legacyUnproven = !hasDecisionClock && (raw.status === 'pending' || raw.status === 'closing');
        const createdDecisionIndex = hasDecisionClock
          ? Math.max(0, Math.floor(Number(raw.createdDecisionIndex) || 0))
          : this._decisionIndex();
        const dueWithinDecisions = Math.max(0, Math.min(2, Math.floor(Number(raw.dueWithinDecisions) || 0)));
        this.promises.set(key, {
          id: key,
          status: legacyUnproven ? 'closing' : raw.status,
          kind: legacyUnproven ? 'LEGACY_RECEIPT' : (raw.kind || 'PROMISE'),
          closureEligible: legacyUnproven ? false : raw.closureEligible !== false,
          lifeCount: currentLife,
          sourceCardId: typeof raw.sourceCardId === 'string' ? raw.sourceCardId : null,
          sourceSemanticKey: typeof raw.sourceSemanticKey === 'string' ? raw.sourceSemanticKey : null,
          sourceTitle: typeof raw.sourceTitle === 'string' ? raw.sourceTitle : null,
          choiceDirection: typeof raw.choiceDirection === 'string' ? raw.choiceDirection : null,
          createdDecisionIndex,
          dueWithinDecisions,
          dueDecisionIndex: hasDecisionClock
            ? Math.max(createdDecisionIndex, Math.floor(Number(raw.dueDecisionIndex) || 0))
            : createdDecisionIndex,
          followUpCardId: raw.followUpCard.id,
          followUpCard: this._clone(raw.followUpCard),
          closureCard: this._isValidPromiseCard(raw.closureCard) ? this._clone(raw.closureCard) : null,
          resolvedDecisionIndex: raw.resolvedDecisionIndex != null && Number.isFinite(Number(raw.resolvedDecisionIndex))
            ? Math.max(0, Math.floor(Number(raw.resolvedDecisionIndex) || 0))
            : null,
          resolutionCardId: typeof raw.resolutionCardId === 'string' ? raw.resolutionCardId : null,
          expirationReason: legacyUnproven
            ? 'UNPROVEN_LEGACY'
            : (typeof raw.expirationReason === 'string' ? raw.expirationReason : null),
          ...(legacyUnproven ? { migrationStatus: 'UNPROVEN_LEGACY' }
            : Object.prototype.hasOwnProperty.call(raw, 'migrationStatus')
              ? { migrationStatus: raw.migrationStatus === 'UNPROVEN_LEGACY' ? 'UNPROVEN_LEGACY' : null }
              : {})
        });
      }
    }
    if (Number(snapshot.version) >= 5) {
      for (const [key, raw] of Object.entries(snapshot.facts || {})) {
        const factTypeId = typeof raw?.factTypeId === 'string' ? raw.factTypeId : '';
        const definition = this.causalGraph.get(factTypeId);
        if (!key || !definition || !raw || typeof raw !== 'object') continue;
        const factInstanceId = typeof raw.factInstanceId === 'string' && raw.factInstanceId ? raw.factInstanceId : key;
        const lifeCount = Math.max(0, Math.floor(Number(raw.lifeCount) || 0));
        if (lifeCount !== currentLife || factInstanceId !== this._factInstanceId(factTypeId, currentLife)) continue;
        if (!['active', 'consumed', 'closed'].includes(raw.status)) continue;
        this.facts.set(factInstanceId, {
          factInstanceId,
          factTypeId,
          lifeCount: currentLife,
          status: raw.status,
          producerId: typeof raw.producerId === 'string' ? raw.producerId : null,
          payload: raw.payload && typeof raw.payload === 'object' ? this._clone(raw.payload) : {},
          createdDecisionIndex: Math.max(0, Math.floor(Number(raw.createdDecisionIndex) || 0)),
          terminalClosure: typeof raw.terminalClosure === 'string' ? raw.terminalClosure : null,
          closedDecisionIndex: raw.closedDecisionIndex !== null && raw.closedDecisionIndex !== undefined
            && Number.isFinite(Number(raw.closedDecisionIndex)) ? Math.max(0, Math.floor(Number(raw.closedDecisionIndex))) : null,
          consumedDecisionIndex: raw.consumedDecisionIndex !== null && raw.consumedDecisionIndex !== undefined
            && Number.isFinite(Number(raw.consumedDecisionIndex)) ? Math.max(0, Math.floor(Number(raw.consumedDecisionIndex))) : null,
          consumedBy: typeof raw.consumedBy === 'string' ? raw.consumedBy : null
        });
      }
      for (const [key, raw] of Object.entries(snapshot.consumptionsByKey || {})) {
        const fact = this.facts.get(raw?.factInstanceId);
          const consumer = fact && this._consumerFor(fact, raw?.consumerId);
          if (!key || !fact || fact.status !== 'consumed' || typeof raw?.consumerId !== 'string'
           || !consumer || consumer.mode === 'observe'
           || key !== this._consumptionKey(fact.factInstanceId, raw.consumerId)) continue;
        this.consumptionsByKey.set(key, {
          factInstanceId: fact.factInstanceId,
          factTypeId: fact.factTypeId,
          consumerId: raw.consumerId,
          consumedDecisionIndex: Math.max(0, Math.floor(Number(raw.consumedDecisionIndex) || 0)),
          receipt: raw.receipt && typeof raw.receipt === 'object' ? this._clone(raw.receipt) : {}
        });
      }
    }
    return true;
  }

  resetForNewLife() {
    this.entries.clear();
    this.promises.clear();
    this.facts.clear();
    this.consumptionsByKey.clear();
    const state = this._state();
    if (state) state.narrativeLedgerState = null;
    return true;
  }

  _persist() {
    const state = this._state();
    if (!state) return false;
    // Narrative facts are staged with their source choice.  GameStateManager's
    // top-level decision transaction is the sole durable write port; saving
    // here used to let a promise survive after the source decision rolled back.
    state.narrativeLedgerState = this.exportState();
    return true;
  }
}

const narrativeLedger = new NarrativeLedger();

if (typeof window !== 'undefined') {
  window.NarrativeLedger = NarrativeLedger;
  window.narrativeLedger = narrativeLedger;
}

if (typeof module !== 'undefined' && module.exports) {
  module.exports = NarrativeLedger;
}
