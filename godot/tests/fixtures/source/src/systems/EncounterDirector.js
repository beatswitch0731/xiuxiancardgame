/**
 * EncounterDirector - authoritative encounter cadence and lifecycle owner.
 *
 * CardSystem owns encounter eligibility and materialization. FlowDirector owns
 * global card priority. This director owns only when an eligible non-Gate
 * encounter becomes due, its persisted pending identity, and the resolved /
 * avoided cadence that follows.
 */
class EncounterDirector {
  constructor(options = {}) {
    this.gameStateRef = options.gameStateRef || null;
    this.cardSystemRef = options.cardSystemRef || null;
    this.eventBusRef = options.eventBusRef || null;
    this.configRef = options.configRef || null;
    this.version = 2;
    this._onCardChosenBound = data => this._onCardChosen(data);
    this._onRealmChangedBound = data => this._onRealmChanged(data);
    this.reset();
  }

  init(options = {}) {
    if (options.gameStateRef) this.gameStateRef = options.gameStateRef;
    if (options.cardSystemRef) this.cardSystemRef = options.cardSystemRef;
    if (options.eventBusRef) this.eventBusRef = options.eventBusRef;
    if (options.configRef) this.configRef = options.configRef;
    this.reset();
    const bus = this._bus();
    if (bus?.off) {
      bus.off('card:chosen', this._onCardChosenBound);
      bus.off('state:realmChanged', this._onRealmChangedBound);
    }
    if (bus?.on) {
      bus.on('card:chosen', this._onCardChosenBound);
      bus.on('state:realmChanged', this._onRealmChangedBound);
    }
    return true;
  }

  _state() {
    return this.gameStateRef
      || (typeof gameState !== 'undefined' ? gameState : null)
      || {};
  }

  _cards() {
    return this.cardSystemRef
      || (typeof cardSystem !== 'undefined' ? cardSystem : null);
  }

  _bus() {
    return this.eventBusRef
      || (typeof eventBus !== 'undefined' ? eventBus : null);
  }

  _config() {
    const loaded = this.configRef
      || (typeof dataLoader !== 'undefined' && dataLoader?.loadSync
        ? dataLoader.loadSync('combat:encounter_director')
        : null)
      || {};
    return {
      firstMin: Math.max(1, Math.floor(Number(loaded.firstEncounterDecisionMin) || 4)),
      firstMax: Math.max(1, Math.floor(Number(loaded.firstEncounterDecisionMax) || 6)),
      intervalMin: Math.max(1, Math.floor(Number(loaded.cadenceDecisionMin) || 7)),
      intervalMax: Math.max(1, Math.floor(Number(loaded.cadenceDecisionMax) || 12)),
      visibleCadenceMax: Math.max(
        Math.max(1, Math.floor(Number(loaded.cadenceDecisionMax) || 12)),
        Math.floor(Number(loaded.visibleCadenceDecisionMax) || 12)
      ),
      prioritySettlementReserve: Math.max(
        0,
        Math.floor(Number(loaded.prioritySettlementDecisionReserve) || 0)
      ),
      cooldown: Math.max(0, Math.floor(Number(loaded.postEncounterCooldown) || 3)),
      realmMinimums: {
        ordinary: Math.max(0, Math.floor(Number(loaded.realmMinimums?.ordinary) || 2)),
        relationshipOrQuest: Math.max(0, Math.floor(Number(loaded.realmMinimums?.relationshipOrQuest) || 1)),
        elite: Math.max(0, Math.floor(Number(loaded.realmMinimums?.elite) || 1)),
        realmBoss: Math.max(0, Math.floor(Number(loaded.realmMinimums?.realmBoss) || 1))
      }
    };
  }

  _lifeId() {
    const state = this._state();
    if (typeof state.getLifeCount === 'function') {
      return Math.max(0, Math.floor(Number(state.getLifeCount()) || 0));
    }
    return Math.max(0, Math.floor(Number(state.unlocks?.lifeCount) || 0));
  }

  _decision() {
    return Math.max(0, Math.floor(Number(this._state().turn) || 0));
  }

  _realm() {
    return this._state().realm || 'qi';
  }

  _path() {
    return this._state().path || null;
  }

  _clone(value, fallback = null) {
    if (value === undefined || value === null) return fallback;
    try {
      return JSON.parse(JSON.stringify(value));
    } catch (error) {
      return fallback;
    }
  }

  _hash(value) {
    let hash = 2166136261;
    for (const char of String(value || '')) {
      hash ^= char.charCodeAt(0);
      hash = Math.imul(hash, 16777619);
    }
    return hash >>> 0;
  }

  _nextInterval() {
    const config = this._config();
    const min = Math.min(config.intervalMin, config.intervalMax);
    const max = Math.max(config.intervalMin, config.intervalMax);
    const span = max - min + 1;
    const resolvedCount = Object.values(this.realmProgress || {}).reduce((sum, progress) => (
      sum + (Array.isArray(progress?.resolvedIds) ? progress.resolvedIds.length : 0)
    ), 0);
    return min + (this._hash(`${this.lifeId}|${this._realm()}|${this._path()}|${resolvedCount}`) % span);
  }

  _emptyRealmProgress() {
    return {
      presentedIds: [],
      resolvedIds: [],
      avoidedIds: [],
      counts: { ordinary: 0, elite: 0, relationship: 0, quest: 0, boss: 0 },
      seenCounts: { ordinary: 0, elite: 0, relationship: 0, quest: 0, boss: 0 }
    };
  }

  _progress(realm = this._realm()) {
    if (!this.realmProgress[realm]) this.realmProgress[realm] = this._emptyRealmProgress();
    return this.realmProgress[realm];
  }

  reset() {
    const config = this._config ? this._config() : {
      firstMin: 4,
      firstMax: 6,
      intervalMin: 7,
      intervalMax: 12,
      cooldown: 3
    };
    this.lifeId = this._lifeId ? this._lifeId() : 0;
    this.firstTeachingStatus = 'pending';
    this.lastResolvedDecision = null;
    this.lastPresentedDecision = null;
    this.nextDueDecision = config.firstMin;
    this.cooldownUntilDecision = 0;
    this.pending = null;
    this.realmProgress = {};
    this.history = [];
    return true;
  }

  _record(event, payload = {}) {
    const entry = {
      event,
      decision: this._decision(),
      realm: this._realm(),
      path: this._path(),
      ...this._clone(payload, {})
    };
    this.history.push(entry);
    if (this.history.length > 80) this.history.splice(0, this.history.length - 80);
    return entry;
  }

  _emit(name, payload = {}) {
    const eventPayload = {
      decision: this._decision(),
      realm: this._realm(),
      path: this._path(),
      ...this._clone(payload, {})
    };
    this._bus()?.emit?.(name, eventPayload);
    return eventPayload;
  }

  _candidateRole(card) {
    return card?.encounterRole || (
      card?.category === 'factionElite' ? 'elite'
        : card?.category === 'companionQuest' ? 'relationship'
          : card?.category === 'heavenChaos' ? 'quest'
            : card?.category === 'realmBoss' ? 'boss'
              : 'ordinary'
    );
  }

  _isTeachingDue() {
    return this.firstTeachingStatus !== 'resolved'
      && this._decision() + 1 >= this._config().firstMin;
  }

  _isCadenceDue() {
    if (this.firstTeachingStatus !== 'resolved') return false;
    const nextDecision = this._decision() + 1;
    return nextDecision >= Math.max(
      Number(this.nextDueDecision) || Number.POSITIVE_INFINITY,
      Number(this.cooldownUntilDecision) + 1 || 0
    );
  }

  isCadenceHardDue() {
    if (this.firstTeachingStatus !== 'resolved' || this.pending || this.isCoolingDown()) return false;
    if (!Number.isFinite(Number(this.lastPresentedDecision))) return false;
    const nextDecision = this._decision() + 1;
    const config = this._config();
    const latestSafeStart = Math.max(
      config.intervalMin,
      config.visibleCadenceMax - config.prioritySettlementReserve
    );
    return nextDecision - Number(this.lastPresentedDecision) >= latestSafeStart;
  }

  canStartAuthoredSequence(decisionCost = 0) {
    if (this.firstTeachingStatus !== 'resolved' || this.pending) return true;
    if (!Number.isFinite(Number(this.lastPresentedDecision))) return true;
    const cost = Math.max(0, Math.floor(Number(decisionCost) || 0));
    const gapAtEntry = (this._decision() + 1) - Number(this.lastPresentedDecision);
    return gapAtEntry + cost <= this._config().visibleCadenceMax;
  }

  isCoolingDown() {
    return this._decision() < Number(this.cooldownUntilDecision || 0);
  }

  canPresent(card, { state = this._state() } = {}) {
    if (!card?.encounterId) return true;
    if (card.encounterKind === 'realm_boss' || card.encounterRole === 'boss') return false;
    if (this.lifeId !== this._lifeId()) return false;
    if (this.isCoolingDown()) return false;
    if (this.pending && this.pending.cardId !== card.id) return false;
    const progress = this._progress(state.realm || this._realm());
    if (card.once !== false && progress.resolvedIds.includes(card.encounterId)) return false;
    return true;
  }

  _eligibleCandidates({ teaching = false } = {}) {
    const cards = this._cards();
    if (!cards?.getEligibleCombatEncounterCards) return [];
    const candidates = cards.getEligibleCombatEncounterCards({
      state: this._state(),
      currentRealmOnly: true,
      teachingOnly: teaching,
      roles: teaching ? ['ordinary'] : null,
      includeDirectorCooldown: true
    });
    return candidates.filter(card => (
      card?.encounterKind !== 'realm_boss'
      && this.canPresent(card, { state: this._state() })
    ));
  }

  _selectCandidate(candidates, teaching) {
    if (!Array.isArray(candidates) || candidates.length === 0) return null;
    const progress = this._progress();
    const resolved = new Set(progress.resolvedIds);
    const presented = new Set(progress.presentedIds);
    const roleOrder = ['ordinary', 'elite', 'relationship', 'quest'];
    const minimums = this._config().realmMinimums;
    const seenCounts = progress.seenCounts || this._emptyRealmProgress().seenCounts;
    const relationshipOrQuest = (Number(seenCounts.relationship) || 0)
      + (Number(seenCounts.quest) || 0);
    const quotaRole = Number(seenCounts.ordinary || 0) < minimums.ordinary
      ? 'ordinary'
      : relationshipOrQuest < minimums.relationshipOrQuest
        ? 'relationshipOrQuest'
        : Number(seenCounts.elite || 0) < minimums.elite
          ? 'elite'
          : null;
    const quotaCandidates = quotaRole
      ? candidates.filter(card => {
          const role = this._candidateRole(card);
          return quotaRole === 'relationshipOrQuest'
            ? role === 'relationship' || role === 'quest'
            : role === quotaRole;
        })
      : candidates;
    const selectionPool = quotaCandidates.length > 0 ? quotaCandidates : candidates;
    const ordered = selectionPool.slice().sort((left, right) => {
      const leftResolved = resolved.has(left.encounterId) ? 1 : 0;
      const rightResolved = resolved.has(right.encounterId) ? 1 : 0;
      if (leftResolved !== rightResolved) return leftResolved - rightResolved;
      const leftPresented = presented.has(left.encounterId) ? 1 : 0;
      const rightPresented = presented.has(right.encounterId) ? 1 : 0;
      if (leftPresented !== rightPresented) return leftPresented - rightPresented;
      if (!teaching) {
        const leftRole = this._candidateRole(left);
        const rightRole = this._candidateRole(right);
        const leftCount = Number(seenCounts[leftRole]) || 0;
        const rightCount = Number(seenCounts[rightRole]) || 0;
        if (leftCount !== rightCount) return leftCount - rightCount;
        const roleDelta = roleOrder.indexOf(leftRole) - roleOrder.indexOf(rightRole);
        if (roleDelta !== 0) return roleDelta;
      }
      return String(left.id).localeCompare(String(right.id));
    });
    return ordered[0] || null;
  }

  _invalidatePending(reason, card = null) {
    const pending = this.pending;
    if (!pending) return false;
    const payload = {
      encounterId: pending.encounterId,
      cardId: pending.cardId,
      encounterKind: card?.encounterKind || pending.encounterKind || null,
      reason
    };
    this.pending = null;
    this._record('invalidated', payload);
    this._emit('encounter:invalidated', payload);
    return true;
  }

  _restorePendingCard() {
    if (!this.pending) return null;
    const cards = this._cards();
    const card = cards?.getCard?.(this.pending.cardId) || null;
    if (!card) {
      this._invalidatePending('missing_card');
      return null;
    }
    if (this.pending.realm !== this._realm()) {
      this._invalidatePending('realm_mismatch', card);
      return null;
    }
    if (card.path && card.path !== this._path()) {
      this._invalidatePending('path_mismatch', card);
      return null;
    }
    const eligible = cards?.isCardEligibleForNormalDraw?.(
      card,
      this._state(),
      new Set(),
      { allowDirectorEncounter: true, skipEncounterDirector: true }
    );
    if (!eligible) {
      this._invalidatePending('eligibility_changed', card);
      return null;
    }
    return card;
  }

  takeDueEncounter() {
    if (this.lifeId !== this._lifeId()) this.reset();
    if (this.pending) {
      const restored = this._restorePendingCard();
      return restored ? { card: restored, reason: this.pending.reason, pending: true } : null;
    }

    const teaching = this._isTeachingDue();
    if (!teaching && !this._isCadenceDue()) return null;
    if (this.isCoolingDown()) return null;
    const card = this._selectCandidate(this._eligibleCandidates({ teaching }), teaching);
    if (!card) return null;
    const reason = teaching ? 'teaching' : 'cadence';
    this.pending = {
      cardId: card.id,
      encounterId: card.encounterId,
      encounterKind: card.encounterKind || null,
      role: this._candidateRole(card),
      realm: this._realm(),
      path: this._path(),
      reason,
      scheduledDecision: this._decision() + 1,
      presented: false,
      accepted: false
    };
    const payload = {
      encounterId: card.encounterId,
      cardId: card.id,
      encounterKind: card.encounterKind || null,
      role: this.pending.role,
      reason,
      scheduledDecision: this.pending.scheduledDecision,
      narrativeSource: card.narrativeSource || null
    };
    this._record('scheduled', payload);
    this._emit('encounter:scheduled', payload);
    return { card, reason, pending: false };
  }

  markPresented(card) {
    if (!card?.encounterId || !this.pending || this.pending.cardId !== card.id) return false;
    if (this.pending.presented) return true;
    this.pending.presented = true;
    this.lastPresentedDecision = Math.max(
      1,
      Math.floor(Number(this.pending.scheduledDecision) || (this._decision() + 1))
    );
    const progress = this._progress();
    if (!progress.presentedIds.includes(card.encounterId)) {
      progress.presentedIds.push(card.encounterId);
      const role = this._candidateRole(card);
      if (!progress.seenCounts) progress.seenCounts = { ...this._emptyRealmProgress().seenCounts };
      progress.seenCounts[role] = (Number(progress.seenCounts[role]) || 0) + 1;
    }
    if (this.pending.reason === 'teaching' && this.firstTeachingStatus === 'pending') {
      this.firstTeachingStatus = 'presented';
    }
    const payload = {
      encounterId: card.encounterId,
      cardId: card.id,
      encounterKind: card.encounterKind || null,
      role: this.pending.role,
      reason: this.pending.reason,
      scheduledDecision: this.lastPresentedDecision,
      narrativeSource: card.narrativeSource || null
    };
    this._record('presented', payload);
    this._emit('encounter:presented', payload);
    return true;
  }

  getRealmQuotaStatus(realm = this._realm()) {
    const progress = this._progress(realm);
    const seen = { ...this._emptyRealmProgress().seenCounts, ...(progress.seenCounts || {}) };
    const minimums = this._config().realmMinimums;
    const relationshipOrQuest = (Number(seen.relationship) || 0) + (Number(seen.quest) || 0);
    const missing = {
      ordinary: Math.max(0, minimums.ordinary - (Number(seen.ordinary) || 0)),
      relationshipOrQuest: Math.max(0, minimums.relationshipOrQuest - relationshipOrQuest),
      elite: Math.max(0, minimums.elite - (Number(seen.elite) || 0))
    };
    return {
      realm,
      seen,
      minimums: { ...minimums },
      missing,
      ready: Object.values(missing).every(value => value === 0)
    };
  }

  isRealmGateReady(realm = this._realm()) {
    return this.getRealmQuotaStatus(realm).ready;
  }

  markAccepted(card, direction = 'left') {
    if (!card?.encounterId) return false;
    if (!this.pending || this.pending.cardId !== card.id) return false;
    if (this.pending.accepted) return true;
    this.pending.accepted = true;
    const payload = {
      encounterId: card.encounterId,
      cardId: card.id,
      encounterKind: card.encounterKind || null,
      role: this._candidateRole(card),
      direction,
      narrativeSource: card.narrativeSource || null
    };
    this._record('accepted', payload);
    this._emit('encounter:accepted', payload);
    return true;
  }

  _settleCadence(card, outcome, avoided = false) {
    const decision = this._decision();
    const presentationDecision = Number(this.pending?.scheduledDecision) || decision;
    const progress = this._progress(card.realm || this._realm());
    if (avoided) {
      progress.avoidedIds.push(card.encounterId);
      if (this.firstTeachingStatus !== 'resolved') this.firstTeachingStatus = 'avoided';
    } else {
      if (!progress.resolvedIds.includes(card.encounterId)) progress.resolvedIds.push(card.encounterId);
      const role = this._candidateRole(card);
      progress.counts[role] = (Number(progress.counts[role]) || 0) + 1;
      if (card.teachingEncounter === true || this.pending?.reason === 'teaching') {
        this.firstTeachingStatus = 'resolved';
      }
      this.lastResolvedDecision = decision;
    }
    const interval = this._nextInterval();
    this.cooldownUntilDecision = decision + this._config().cooldown;
    // Cadence is a player-visible presentation-to-presentation contract. The
    // combat warning/reward settlement choices must not silently extend the
    // advertised 7–12 decision gap. Post-combat safety still comes from the
    // independent cooldown lower bound in _isCadenceDue().
    this.nextDueDecision = presentationDecision + interval;
    this.pending = null;
    return interval;
  }

  _onCardChosen(data) {
    const card = data?.card;
    if (!card?.encounterId) return;
    if (!this.pending || this.pending.cardId !== card.id) return;
    const choice = data.choice || card.choices?.[data.direction] || null;
    const outcome = data.combatOutcome || null;
    const accepted = Boolean(outcome || choice?.triggerCombat || choice?.effects?.triggerCombat);
    if (accepted && outcome) {
      if (!this.pending?.accepted) this.markAccepted(card, data.direction || 'left');
      const interval = this._settleCadence(card, outcome, false);
      const payload = {
        encounterId: card.encounterId,
        cardId: card.id,
        encounterKind: card.encounterKind || null,
        role: this._candidateRole(card),
        outcome,
        nextInterval: interval,
        narrativeSource: card.narrativeSource || null
      };
      this._record('resolved', payload);
      this._emit('encounter:resolved', payload);
      return;
    }
    if (!accepted) {
      const interval = this._settleCadence(card, 'avoided', true);
      const payload = {
        encounterId: card.encounterId,
        cardId: card.id,
        encounterKind: card.encounterKind || null,
        role: this._candidateRole(card),
        direction: data.direction || 'right',
        nextInterval: interval,
        narrativeSource: card.narrativeSource || null
      };
      this._record('avoided', payload);
      this._emit('encounter:avoided', payload);
    }
  }

  _onRealmChanged(data) {
    const to = data?.to || this._realm();
    if (this.pending) this._invalidatePending('realm_changed');
    this._progress(to);
    const decision = this._decision();
    this.lastPresentedDecision = null;
    this.cooldownUntilDecision = decision + this._config().cooldown;
    this.nextDueDecision = decision + this._nextInterval();
    this._record('realm_changed', { from: data?.from || null, to });
  }

  exportState() {
    return {
      version: this.version,
      lifeId: this.lifeId,
      firstTeachingStatus: this.firstTeachingStatus,
      lastResolvedDecision: this.lastResolvedDecision,
      lastPresentedDecision: this.lastPresentedDecision,
      nextDueDecision: this.nextDueDecision,
      cooldownUntilDecision: this.cooldownUntilDecision,
      pending: this._clone(this.pending, null),
      realmProgress: this._clone(this.realmProgress, {}),
      history: this._clone(this.history, [])
    };
  }

  hydrateState(snapshot) {
    if (!snapshot || typeof snapshot !== 'object') return false;
    const snapshotLife = Math.max(0, Math.floor(Number(snapshot.lifeId) || 0));
    if (snapshotLife !== this._lifeId()) {
      this.reset();
      return false;
    }
    this.lifeId = snapshotLife;
    this.firstTeachingStatus = ['pending', 'presented', 'avoided', 'resolved']
      .includes(snapshot.firstTeachingStatus)
      ? snapshot.firstTeachingStatus
      : 'pending';
    this.lastResolvedDecision = snapshot.lastResolvedDecision !== null
      && snapshot.lastResolvedDecision !== undefined
      && Number.isFinite(Number(snapshot.lastResolvedDecision))
      ? Math.max(0, Math.floor(Number(snapshot.lastResolvedDecision)))
      : null;
    this.lastPresentedDecision = snapshot.lastPresentedDecision !== null
      && snapshot.lastPresentedDecision !== undefined
      && Number.isFinite(Number(snapshot.lastPresentedDecision))
      ? Math.max(1, Math.floor(Number(snapshot.lastPresentedDecision)))
      : this.lastResolvedDecision;
    this.nextDueDecision = Math.max(
      this._config().firstMin,
      Math.floor(Number(snapshot.nextDueDecision) || this._config().firstMin)
    );
    this.cooldownUntilDecision = Math.max(0, Math.floor(Number(snapshot.cooldownUntilDecision) || 0));
    this.pending = snapshot.pending && typeof snapshot.pending === 'object'
      ? this._clone(snapshot.pending, null)
      : null;
    this.realmProgress = snapshot.realmProgress && typeof snapshot.realmProgress === 'object'
      ? this._clone(snapshot.realmProgress, {})
      : {};
    for (const realm of Object.keys(this.realmProgress)) {
      const raw = this.realmProgress[realm] || {};
      this.realmProgress[realm] = {
        presentedIds: Array.isArray(raw.presentedIds) ? [...new Set(raw.presentedIds)] : [],
        resolvedIds: Array.isArray(raw.resolvedIds) ? [...new Set(raw.resolvedIds)] : [],
        avoidedIds: Array.isArray(raw.avoidedIds) ? raw.avoidedIds.slice(-40) : [],
        counts: { ...this._emptyRealmProgress().counts, ...(raw.counts || {}) },
        seenCounts: { ...this._emptyRealmProgress().seenCounts, ...(raw.seenCounts || raw.counts || {}) }
      };
    }
    this.history = Array.isArray(snapshot.history) ? this._clone(snapshot.history.slice(-80), []) : [];
    return true;
  }

  getDebugState() {
    return this.exportState();
  }
}

const encounterDirector = new EncounterDirector();

if (typeof window !== 'undefined') {
  window.EncounterDirector = EncounterDirector;
  window.encounterDirector = encounterDirector;
}
if (typeof global !== 'undefined') {
  global.EncounterDirector = EncounterDirector;
  global.encounterDirector = encounterDirector;
}
if (typeof module !== 'undefined' && module.exports) {
  module.exports = EncounterDirector;
  module.exports.EncounterDirector = EncounterDirector;
  module.exports.encounterDirector = encounterDirector;
}
