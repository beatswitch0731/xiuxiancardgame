/** 数据驱动的功法流派战斗协同。 */
class PathArchetypeSystem {
  constructor() {
    this.data = { paths: {} };
    this.combat = null;
  }

  init() {
    const data = dataLoader.loadSync('config:path_archetypes');
    if (data) this.data = data;
    eventBus.on('state:reset', () => { this.combat = null; });
  }

  getAvailable(path = gameState.path, realm = gameState.realm) {
    const order = gameState.config.realms?.order || ['qi', 'foundation', 'golden', 'nascent', 'deity', 'tribulation'];
    const current = order.indexOf(realm);
    return (this.data.paths?.[path]?.archetypes || []).filter(item => order.indexOf(item.realm) <= current);
  }

  getSelected(path = gameState.path) {
    const available = this.getAvailable(path);
    if (!available.length) return null;
    const selectedId = gameState.pathArchetypes?.[path];
    return available.find(item => item.id === selectedId) || available[0];
  }

  select(path, archetypeId) {
    const target = this.getAvailable(path).find(item => item.id === archetypeId);
    if (!target) return false;
    if (!gameState.pathArchetypes) gameState.pathArchetypes = {};
    gameState.pathArchetypes[path] = archetypeId;
    eventBus.emit('path:archetypeSelected', { path, archetype: target });
    return true;
  }

  onBattleStart() {
    const archetype = this.getSelected();
    this.combat = this._createCombatRuntime(archetype);
    return archetype;
  }

  _createCombatRuntime(archetype = this.getSelected()) {
    return {
      archetype,
      lastType: null,
      sequence: [],
      cardSequence: [],
      cardsThisTurn: [],
      triggeredThisTurn: new Set(),
      turnOpen: false
    };
  }

  onTurnStart() {
    if (!this.combat) return false;
    this.combat.cardsThisTurn = [];
    this.combat.triggeredThisTurn = new Set();
    this.combat.turnOpen = true;
    return true;
  }

  onTurnEnd() {
    if (!this.combat || !this.combat.turnOpen) return false;
    this.combat.turnOpen = false;
    this.combat.cardsThisTurn = [];
    this.combat.triggeredThisTurn = new Set();
    return true;
  }

  onBattleEnd() {
    if (!this.combat) return false;
    this.combat = null;
    return true;
  }

  beforeCard(card, battle) {
    if (!this.combat || !this.combat.archetype || !card) return null;
    const transition = this.previewCardTransition(this.exportCombatState(), card, battle);
    if (!transition) return null;
    this.combat = this._runtimeFromSnapshot(transition.combatState, this.combat.archetype);
    return transition.synergy;
  }

  static projectCardTransition({ archetype, pathId, history, card, battle }) {
    if (!archetype || typeof pathId !== 'string') return null;
    // Reuse the actual rule matcher without a singleton, selected-state lookup,
    // runtime mutation, or an implicit dependency on the global gameState.
    return Object.create(PathArchetypeSystem.prototype)
      .previewCardTransition(history, card, battle, { archetype, pathId });
  }

  previewCardTransition(snapshot, card, battle, context = null) {
    const validation = this.validateCombatState(snapshot, context ? context.archetype : this.getSelected());
    if (!validation.valid || !card) return null;
    const state = this._runtimeFromSnapshot(snapshot, validation.archetype);
    const result = {
      damageBonus: 0, blockBonus: 0, gainQi: 0, enemyStatuses: [], playerStatuses: [], texts: [],
      pathId: context ? context.pathId : gameState.path,
      archetypeId: state.archetype.id,
      feedback: state.archetype.feedback ? JSON.parse(JSON.stringify(state.archetype.feedback)) : null,
      activations: []
    };
    for (const rule of state.archetype.rules || []) {
      if (rule.oncePerTurn && state.triggeredThisTurn.has(rule.id)) continue;
      if (!this._matches(rule, card, battle, state)) continue;
      const triggerCount = rule.condition === 'distinct_cards' ? (rule.count || 3)
        : rule.condition === 'previous_type' ? 2 : 1;
      result.activations.push({
        ruleId: rule.id,
        text: rule.text || '',
        ...(rule.conditionText ? { conditionText: rule.conditionText } : {}),
        ...(rule.condition === 'repeat_type' ? { conditionEvidence: {
          scope: 'turn', cardType: card.type,
          cardsOfTypeThisTurn: [...state.cardsThisTurn, card.type].filter(type => type === card.type).length
        } } : {}),
        triggerCardIds: [...state.cardSequence, card.id].slice(-triggerCount),
        requestedDelta: {
          damageBonus: Number(rule.damageBonus) || 0,
          blockBonus: Number(rule.blockBonus) || 0,
          gainQi: Number(rule.gainQi) || 0
        },
        statuses: {
          enemy: rule.enemyStatus ? [JSON.parse(JSON.stringify(rule.enemyStatus))] : [],
          player: rule.playerStatus ? [JSON.parse(JSON.stringify(rule.playerStatus))] : []
        }
      });
      result.damageBonus += Number(rule.damageBonus) || 0;
      result.blockBonus += Number(rule.blockBonus) || 0;
      result.gainQi += Number(rule.gainQi) || 0;
      if (rule.enemyStatus) result.enemyStatuses.push(rule.enemyStatus);
      if (rule.playerStatus) result.playerStatuses.push(rule.playerStatus);
      if (rule.text) result.texts.push(rule.text);
      if (rule.oncePerTurn) state.triggeredThisTurn.add(rule.id);
    }
    state.lastType = card.type;
    state.sequence.push(card.type);
    state.sequence = state.sequence.slice(-4);
    state.cardSequence.push(card.id);
    state.cardSequence = state.cardSequence.slice(-4);
    state.cardsThisTurn.push(card.type);
    return { synergy: result, combatState: this._snapshotFromRuntime(state) };
  }

  _snapshotFromRuntime(runtime) {
    if (!runtime?.archetype) return null;
    return {
      version: 1,
      archetypeId: runtime.archetype.id,
      lastType: runtime.lastType || null,
      sequence: [...(runtime.sequence || [])],
      cardSequence: [...(runtime.cardSequence || [])],
      cardsThisTurn: [...(runtime.cardsThisTurn || [])],
      triggeredThisTurn: Array.from(runtime.triggeredThisTurn || []),
      turnOpen: runtime.turnOpen === true
    };
  }

  _runtimeFromSnapshot(snapshot, archetype = this.getSelected()) {
    return {
      archetype,
      lastType: snapshot?.lastType || null,
      sequence: [...(snapshot?.sequence || [])],
      cardSequence: [...(snapshot?.cardSequence || [])],
      cardsThisTurn: [...(snapshot?.cardsThisTurn || [])],
      triggeredThisTurn: new Set(snapshot?.triggeredThisTurn || []),
      turnOpen: snapshot?.turnOpen === true
    };
  }

  exportCombatState() {
    return this._snapshotFromRuntime(this.combat);
  }

  buildOpeningCombatState() {
    const archetype = this.getSelected();
    if (!archetype) return null;
    const runtime = this._createCombatRuntime(archetype);
    runtime.turnOpen = true;
    return this._snapshotFromRuntime(runtime);
  }

  validateCombatState(snapshot, archetype = this.getSelected()) {
    if (!snapshot || snapshot.version !== 1 || !archetype || snapshot.archetypeId !== archetype.id) {
      return { valid: false, archetype: null };
    }
    const allowedTypes = new Set(['attack', 'skill', 'power']);
    const stringArray = (value, max) => Array.isArray(value)
      && value.length <= max
      && value.every(item => typeof item === 'string' && item.length > 0);
    const onceRuleIds = new Set((archetype.rules || []).filter(rule => rule.oncePerTurn).map(rule => rule.id));
    const triggered = snapshot.triggeredThisTurn;
    const valid = (snapshot.lastType === null || allowedTypes.has(snapshot.lastType))
      && stringArray(snapshot.sequence, 4)
      && snapshot.sequence.every(type => allowedTypes.has(type))
      && stringArray(snapshot.cardSequence, 4)
      && stringArray(snapshot.cardsThisTurn, 100)
      && snapshot.cardsThisTurn.every(type => allowedTypes.has(type))
      && Array.isArray(triggered)
      && triggered.length <= onceRuleIds.size
      && new Set(triggered).size === triggered.length
      && triggered.every(id => onceRuleIds.has(id))
      && typeof snapshot.turnOpen === 'boolean'
      && snapshot.sequence.length === snapshot.cardSequence.length
      && (snapshot.sequence.length === 0
        ? snapshot.lastType === null
        : snapshot.lastType === snapshot.sequence[snapshot.sequence.length - 1]);
    return { valid, archetype: valid ? archetype : null };
  }

  hydrateCombatState(snapshot) {
    const validation = this.validateCombatState(snapshot);
    if (!validation.valid) return false;
    this.combat = this._runtimeFromSnapshot(snapshot, validation.archetype);
    return true;
  }

  _matches(rule, card, battle, state) {
    if (rule.cardType && rule.cardType !== card.type) return false;
    if (rule.sameTurn === true && state.cardsThisTurn.length === 0) return false;
    if (Number.isFinite(Number(rule.requiredBlock))
      && Number(battle?.player?.block || 0) < Number(rule.requiredBlock)) return false;
    switch (rule.condition) {
      case 'alternate_types': return !!state.lastType && state.lastType !== card.type;
      case 'previous_type': return state.lastType === rule.previousType;
      case 'distinct_sequence': {
        const sequence = [...state.sequence, card.type].slice(-(rule.count || 3));
        return sequence.length >= (rule.count || 3) && new Set(sequence).size >= (rule.count || 3);
      }
      case 'distinct_cards': {
        const sequence = [...state.cardSequence, card.id].slice(-(rule.count || 3));
        return sequence.length >= (rule.count || 3) && new Set(sequence).size >= (rule.count || 3);
      }
      case 'first_type_turn': return !state.cardsThisTurn.includes(card.type);
      case 'repeat_type': return [...state.cardsThisTurn, card.type].filter(type => type === card.type).length >= (rule.count || 2);
      case 'low_hp': return battle.player.hp / Math.max(1, battle.player.maxHp) <= (rule.ratio || 0.5);
      case 'status_min': return (battle.playerStatus?.[rule.status] || 0) >= (rule.value || 1);
      case 'block_min': return battle.player.block >= (rule.value || 1);
      case 'zero_cost': return card.cost === 0;
      case 'full_qi': return battle.qi >= battle.maxQi;
      case 'card_type': return !rule.cardType || rule.cardType === card.type;
      default: return false;
    }
  }
}

const pathArchetypeSystem = new PathArchetypeSystem();

if (typeof module !== 'undefined' && module.exports) {
  module.exports = PathArchetypeSystem;
}
