/**
 * WorldContinuityStore — 当世世界人物权威状态。
 *
 * NPC 的剧情弧、日程与好感可以读取这里，但不得各自决定人物是否还能
 * 以实体出现。所有物理遭遇、面板交互、援助与动态卡统一走 manifestation。
 */
class WorldContinuityStore {
  static LIFECYCLES = Object.freeze([
    'UNMET', 'ACTIVE', 'DISTANT', 'ASCENDED', 'RETIRED', 'DEAD'
  ]);

  static MANIFESTATIONS = Object.freeze(['NONE', 'PHYSICAL', 'ECHO_ONLY']);

  constructor({ gameStateRef = null, eventBusRef = null } = {}) {
    this.gameState = gameStateRef || (typeof gameState !== 'undefined' ? gameState : null);
    this.eventBus = eventBusRef || (typeof eventBus !== 'undefined' ? eventBus : null);
    this.lifeId = this._currentLifeId();
    this.revision = 0;
    this.npcs = {};
    this._bound = false;

    const snapshot = this.gameState?.worldContinuityState
      || this.gameState?.unlocks?.causalSessionState?.worldContinuity
      || null;
    if (snapshot) this.hydrateState(snapshot);
  }

  _currentLifeId() {
    if (typeof this.gameState?.getLifeCount === 'function') {
      return Math.max(0, Number(this.gameState.getLifeCount()) || 0);
    }
    return Math.max(0, Number(this.gameState?.unlocks?.lifeCount) || 0);
  }

  init() {
    if (this._bound || !this.eventBus?.on) return false;
    this._bound = true;
    this._onResetBound = () => this._onStateReset();
    this._onDiedBound = data => this._transitionFromEvent(data, 'DEAD', 'npc:died');
    this._onAscendedBound = data => this._transitionFromEvent(data, 'ASCENDED', 'npc:ascended');
    this._onRetiredBound = data => this._transitionFromEvent(data, 'RETIRED', 'npc:retired');
    this._onLeftSectBound = data => this._transitionFromEvent(data, 'DISTANT', 'npc:leftSect');
    this.eventBus.on('state:reset', this._onResetBound);
    this.eventBus.on('npc:died', this._onDiedBound);
    this.eventBus.on('npc:ascended', this._onAscendedBound);
    this.eventBus.on('npc:retired', this._onRetiredBound);
    this.eventBus.on('npc:leftSect', this._onLeftSectBound);
    return true;
  }

  _onStateReset() {
    this.lifeId = this._currentLifeId();
    this.revision = 0;
    this.npcs = {};
    const snapshot = this.gameState?.worldContinuityState || null;
    if (snapshot) this.hydrateState(snapshot);
    this._syncGameState();
  }

  _transitionFromEvent(data, lifecycle, source) {
    if (!data?.npcId) return;
    this.transitionNpc(data.npcId, lifecycle, {
      manifestation: data.manifestation,
      locationId: data.locationId,
      changedByNode: data.changedByNode || data.nodeId || source,
      reason: data.reason || source
    });
  }

  _defaultManifestation(lifecycle) {
    if (lifecycle === 'ACTIVE') return 'PHYSICAL';
    if (lifecycle === 'UNMET') return 'NONE';
    return 'ECHO_ONLY';
  }

  _normalizeManifestation(lifecycle, manifestation) {
    const expected = this._defaultManifestation(lifecycle);
    if (!WorldContinuityStore.MANIFESTATIONS.includes(manifestation)) return expected;
    if (lifecycle !== 'ACTIVE' && manifestation === 'PHYSICAL') return expected;
    return manifestation;
  }

  registerNpc(npcOrId, options = {}) {
    const npcId = typeof npcOrId === 'string' ? npcOrId : npcOrId?.id;
    if (!npcId) return null;
    if (this.npcs[npcId]) return this.getNpcState(npcId);
    const lifecycle = WorldContinuityStore.LIFECYCLES.includes(options.lifecycle)
      ? options.lifecycle
      : 'ACTIVE';
    const locationId = options.locationId
      || (typeof npcOrId === 'object' ? npcOrId.defaultLocation : null)
      || null;
    this.npcs[npcId] = {
      npcId,
      lifeId: this.lifeId,
      lifecycle,
      manifestation: this._normalizeManifestation(lifecycle, options.manifestation),
      locationId,
      factionId: options.factionId || (typeof npcOrId === 'object' ? npcOrId.factionId : null) || null,
      changedByNode: options.changedByNode || 'npc_registered',
      changedAtTurn: Math.max(0, Number(this.gameState?.turn) || 0),
      reason: options.reason || 'initial_presence',
      revision: ++this.revision
    };
    this._syncGameState();
    return this.getNpcState(npcId);
  }

  getNpcState(npcId) {
    const state = this.npcs[npcId];
    return state ? JSON.parse(JSON.stringify(state)) : null;
  }

  transitionNpc(npcId, lifecycle, metadata = {}) {
    if (!npcId || !WorldContinuityStore.LIFECYCLES.includes(lifecycle)) {
      return { changed: false, reason: 'invalid_lifecycle', state: this.getNpcState(npcId) };
    }
    if (!this.npcs[npcId]) this.registerNpc(npcId, { lifecycle: 'ACTIVE' });
    const previous = this.npcs[npcId];
    if (previous.lifecycle === lifecycle) {
      return { changed: false, reason: 'already_in_state', state: this.getNpcState(npcId) };
    }

    const terminal = ['ASCENDED', 'RETIRED', 'DEAD'];
    if (terminal.includes(previous.lifecycle)) {
      return { changed: false, reason: 'terminal_lifecycle', state: this.getNpcState(npcId) };
    }
    const allowed = {
      UNMET: ['ACTIVE'],
      ACTIVE: ['DISTANT', 'ASCENDED', 'RETIRED', 'DEAD'],
      DISTANT: ['ACTIVE', 'ASCENDED', 'RETIRED', 'DEAD']
    };
    if (!(allowed[previous.lifecycle] || []).includes(lifecycle)) {
      return { changed: false, reason: 'invalid_transition', state: this.getNpcState(npcId) };
    }

    const next = {
      ...previous,
      lifeId: this.lifeId,
      lifecycle,
      manifestation: this._normalizeManifestation(lifecycle, metadata.manifestation),
      locationId: Object.prototype.hasOwnProperty.call(metadata, 'locationId')
        ? metadata.locationId
        : (lifecycle === 'ACTIVE' ? previous.locationId : null),
      changedByNode: metadata.changedByNode || metadata.nodeId || 'system_transition',
      changedAtTurn: Math.max(0, Number(this.gameState?.turn) || 0),
      reason: metadata.reason || lifecycle.toLowerCase(),
      revision: ++this.revision
    };
    this.npcs[npcId] = next;
    this._syncGameState();
    if (this.eventBus?.emit) {
      this.eventBus.emit('npc:lifecycleChanged', {
        npcId,
        previous: JSON.parse(JSON.stringify(previous)),
        current: this.getNpcState(npcId),
        revision: this.revision
      });
    }
    return { changed: true, reason: null, state: this.getNpcState(npcId) };
  }

  setLocation(npcId, locationId, metadata = {}) {
    const state = this.npcs[npcId];
    if (!state || state.lifecycle !== 'ACTIVE' || !locationId || state.locationId === locationId) {
      return false;
    }
    state.locationId = locationId;
    state.changedAtTurn = Math.max(0, Number(this.gameState?.turn) || 0);
    state.changedByNode = metadata.changedByNode || 'npc_schedule';
    state.revision = ++this.revision;
    this._syncGameState();
    return true;
  }

  canPhysicallyAppear(npcId) {
    const state = this.npcs[npcId];
    return Boolean(state && state.lifeId === this.lifeId
      && state.lifecycle === 'ACTIVE' && state.manifestation === 'PHYSICAL');
  }

  canManifest(npcId, manifestation = 'PHYSICAL') {
    if (manifestation === 'PHYSICAL') return this.canPhysicallyAppear(npcId);
    const state = this.npcs[npcId];
    return Boolean(state && state.lifeId === this.lifeId
      && manifestation === 'ECHO_ONLY' && state.manifestation === 'ECHO_ONLY');
  }

  exportState() {
    return {
      version: 1,
      lifeId: this.lifeId,
      revision: this.revision,
      npcs: JSON.parse(JSON.stringify(this.npcs))
    };
  }

  hydrateState(snapshot) {
    if (!snapshot || typeof snapshot !== 'object') return false;
    const snapshotLifeId = Math.max(0, Number(snapshot.lifeId) || 0);
    if (snapshotLifeId !== this._currentLifeId()) return false;
    const restored = {};
    for (const [npcId, raw] of Object.entries(snapshot.npcs || {})) {
      if (!raw || raw.npcId !== npcId || !WorldContinuityStore.LIFECYCLES.includes(raw.lifecycle)) continue;
      restored[npcId] = {
        npcId,
        lifeId: snapshotLifeId,
        lifecycle: raw.lifecycle,
        manifestation: this._normalizeManifestation(raw.lifecycle, raw.manifestation),
        locationId: typeof raw.locationId === 'string' ? raw.locationId : null,
        factionId: typeof raw.factionId === 'string' ? raw.factionId : null,
        changedByNode: typeof raw.changedByNode === 'string' ? raw.changedByNode : 'restore',
        changedAtTurn: Math.max(0, Number(raw.changedAtTurn) || 0),
        reason: typeof raw.reason === 'string' ? raw.reason : 'restore',
        revision: Math.max(0, Number(raw.revision) || 0)
      };
    }
    this.lifeId = snapshotLifeId;
    this.revision = Math.max(Number(snapshot.revision) || 0,
      ...Object.values(restored).map(state => state.revision));
    this.npcs = restored;
    this._syncGameState();
    return true;
  }

  _syncGameState() {
    if (this.gameState) this.gameState.worldContinuityState = this.exportState();
  }
}

const worldContinuityStore = new WorldContinuityStore();

if (typeof window !== 'undefined') {
  window.WorldContinuityStore = WorldContinuityStore;
  window.worldContinuityStore = worldContinuityStore;
}
if (typeof global !== 'undefined') {
  global.WorldContinuityStore = WorldContinuityStore;
  global.worldContinuityStore = worldContinuityStore;
}
if (typeof module !== 'undefined' && module.exports) {
  module.exports = WorldContinuityStore;
  module.exports.WorldContinuityStore = WorldContinuityStore;
  module.exports.worldContinuityStore = worldContinuityStore;
}
