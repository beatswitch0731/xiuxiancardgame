/**
 * ChoiceOutcomeRouter - one settlement contract for narrative causality.
 *
 * Numeric effects still belong to EffectService. This router owns the part a
 * player reads as cause and consequence: explicit transitions/resolutions,
 * world mutations and short-lived promises whose result is queued through the
 * authoritative FlowDirector and persisted by NarrativeLedger.
 */
class ChoiceOutcomeRouter {
  /**
   * Authoritative top-level choice schema.
   *
   * `metadata` is display/content annotation and must never be mistaken for a
   * gameplay reward. `behavior` must name the production boundary that owns
   * it. Runtime-generated fields are listed too because generated cards pass
   * through the same fail-closed audit as authored JSON.
   */
  static CHOICE_FIELD_CONTRACT = Object.freeze({
    // Presentation / authoring metadata.
    text: { kind: 'metadata', consumer: 'GameUI' },
    title: { kind: 'metadata', consumer: 'GameUI' },
    subtitle: { kind: 'metadata', consumer: 'GameUI' },
    desc: { kind: 'metadata', consumer: 'ChoiceOutcomeRouter' },
    description: { kind: 'metadata', consumer: 'GameUI' },
    image: { kind: 'metadata', consumer: 'GameUI' },
    sceneImage: { kind: 'metadata', consumer: 'CardSystem/CombatCoordinator/GameUI' },
    effectText: { kind: 'metadata', consumer: 'GameUI' },
    settlementFeedbackMode: { kind: 'metadata', consumer: 'GameLogic/GameUI', values: ['nearfield', 'log_only'] },
    narrativeBlock: { kind: 'metadata', consumer: 'ChoiceOutcomeRouter' },
    _adultThemes: { kind: 'metadata', consumer: 'content-policy' },
    // Fact-consumer narratives are authored in causal_graph.json and are
    // projected into ordinary card choices by GameLogic before settlement.
    // These fields choose the authoritative receipt; they never grant effects.
    id: { kind: 'metadata', consumer: 'GameLogic._buildNarrativeFactCard' },
    receiptDisposition: { kind: 'metadata', consumer: 'GameLogic._settleNarrativeFlowFactChoice' },
    treasureId: { kind: 'metadata', consumer: 'TreasureSystem/GameUI' },
    _treasureOption: { kind: 'runtime', consumer: 'GameLogic/GameUI' },

    // Numeric/resource settlement.
    effects: { kind: 'behavior', consumer: 'EffectService' },
    // A vendor session is a deferred player decision. Its rewards are only
    // authoritative after the matching vendor session closes; `effects` must
    // remain empty on ENTER_VENDOR choices so producers cannot pay early.
    vendorCloseEffects: { kind: 'behavior', consumer: 'GameLogic._finalizeTurnAfterVendor' },
    costCheck: { kind: 'behavior', consumer: 'EffectService/GameLogic' },
    costText: { kind: 'metadata', consumer: 'GameUI' },
    requiredPill: { kind: 'behavior', consumer: 'EffectService/GameLogic._resolveBreakthrough' },
    breakSuccess: { kind: 'behavior', consumer: 'GameLogic._resolveBreakthrough' },
    enterUpperRealm: { kind: 'behavior', consumer: 'GameLogic._enterUpperRealm' },
    innerDemonAction: { kind: 'behavior', consumer: 'GameLogic._resolveInnerDemon' },

    // Combat and encounter expansion.
    combatChance: { kind: 'behavior', consumer: 'GameLogic._resolveProbabilisticCombatChoice' },
    combatEncounterId: { kind: 'behavior', consumer: 'CardSystem.resolveCombatEncounterChoice' },
    triggerCombat: { kind: 'behavior', consumer: 'CombatCoordinator' },
    encounterId: { kind: 'behavior', consumer: 'CompanionSystem/CardSystem' },
    encounterKind: { kind: 'behavior', consumer: 'EncounterDirector/CombatCoordinator' },
    enemy: { kind: 'behavior', consumer: 'CombatCoordinator' },
    battlefield: { kind: 'behavior', consumer: 'CombatCoordinator/DeckCombatUI' },
    combatPresentation: { kind: 'behavior', consumer: 'CombatCoordinator/DeckCombatUI' },
    victoryEffects: { kind: 'behavior', consumer: 'GameLogic._resolveCombatOutcome' },
    defeatEffects: { kind: 'behavior', consumer: 'GameLogic._resolveCombatOutcome' },
    fleeEffects: { kind: 'behavior', consumer: 'GameLogic._resolveCombatOutcome' },
    defeatHealthLoss: { kind: 'behavior', consumer: 'GameLogic._resolveCombatOutcome' },
    defeatHealthFloor: { kind: 'behavior', consumer: 'GameLogic._resolveCombatOutcome' },
    combatOutcomeLinks: { kind: 'behavior', consumer: 'GameLogic._resolveCombatOutcome' },
    combatOutcomePresentation: { kind: 'behavior', consumer: 'CombatCoordinator outcome card builder' },
    combatRewards: { kind: 'behavior', consumer: 'CombatCoordinator' },
    entryEffects: { kind: 'behavior', consumer: 'GameLogic/CombatCoordinator' },
    _confirmCombat: { kind: 'runtime', consumer: 'GameLogic/CombatCoordinator' },
    _cancelCombat: { kind: 'runtime', consumer: 'GameLogic/CombatCoordinator' },

    // Flow, quest and narrative causality.
    action: { kind: 'behavior', consumer: 'GameLogic action router' },
    dungeon: { kind: 'behavior', consumer: 'CardSystem dungeon authority' },
    _dungeonForkNext: { kind: 'runtime', consumer: 'CardSystem dungeon authority' },
    nextCard: { kind: 'behavior', consumer: 'GameLogic/CardSystem' },
    continuityClass: { kind: 'behavior', consumer: 'GameLogic authored-continuation arbitration' },
    questNext: { kind: 'behavior', consumer: 'QuestSystem' },
    questEnd: { kind: 'behavior', consumer: 'QuestSystem' },
    questEndOn: { kind: 'behavior', consumer: 'GameLogic._resolveCombatOutcome' },
    questOutcome: { kind: 'behavior', consumer: 'QuestSystem/ChoiceOutcomeRouter' },
    karmaSeed: { kind: 'behavior', consumer: 'KarmaSystem' },
    karmaSeedOn: { kind: 'behavior', consumer: 'GameLogic._resolveCombatOutcome' },
    reqDeckTag: { kind: 'behavior', consumer: 'GameLogic deck gate' },
    threadDirection: { kind: 'behavior', consumer: 'StoryThreadEngine' },
    _threadDirection: { kind: 'runtime', consumer: 'StoryThreadEngine' },
    transition: { kind: 'runtime', consumer: 'ChoiceOutcomeRouter' },
    resolution: { kind: 'runtime', consumer: 'ChoiceOutcomeRouter' },
    promise: { kind: 'runtime', consumer: 'ChoiceOutcomeRouter/NarrativeLedger' },
    worldMutations: { kind: 'runtime', consumer: 'ChoiceOutcomeRouter' },
    feedbackCue: { kind: 'runtime', consumer: 'GameUI' },
    _choiceDirection: { kind: 'runtime', consumer: 'ChoiceOutcomeRouter' },

    // Relationship/faction systems.
    affection: { kind: 'behavior', consumer: 'CompanionSystem formatter' },
    bondDelta: { kind: 'behavior', consumer: 'CompanionSystem formatter' },
    trustDelta: { kind: 'behavior', consumer: 'CompanionSystem formatter' },
    companionEffects: { kind: 'behavior', consumer: 'CompanionSystem' },
    factionEffects: { kind: 'behavior', consumer: 'FactionSystem' },
    npcAffection: { kind: 'behavior', consumer: 'NpcSystem/GameLogic' },
    reputationDelta: { kind: 'behavior', consumer: 'FactionSystem' },
    subfactionId: { kind: 'behavior', consumer: 'FactionSystem' },
    subReputationDelta: { kind: 'behavior', consumer: 'FactionSystem' },
    undercurrentId: { kind: 'behavior', consumer: 'FactionSystem' },
    undercurrentStageChange: { kind: 'behavior', consumer: 'FactionSystem' },
    globalFlag: { kind: 'behavior', consumer: 'FactionSystem/StoryThreadEngine' },

    // Generated relationship-card annotations consumed by their builders.
    conflict: { kind: 'runtime', consumer: 'StoryNetworkSystem' },
    milestones: { kind: 'runtime', consumer: 'StoryNetworkSystem' },
    num: { kind: 'runtime', consumer: 'StoryNetworkSystem' }
  });

  /**
   * Authoritative EffectService field schema. Effect maps are behavior, not an
   * open metadata bag: a typo must reject the whole choice before settlement.
   */
  static EFFECT_FIELD_CONTRACT = Object.freeze(Object.fromEntries([
    'path', 'mp', 'reincarnate', 'reincarnation_bonus', 'pill', 'treasure',
    'companion', 'deckCard', 'skillOpportunity', 'opportunityReward',
    'skillAcquire', 'removeCard', 'upgradeCard', 'cultivation', 'fortune',
    'health', 'aura', 'maxHealth', 'maxDaoHeart', '_consumePill',
    '_consumeTreasure', 'breakthroughBoost', '_setFlag', 'npcLifecycle',
    '_identifyTreasure', 'playerLocation', 'karmaGood', 'karmaBad', 'daoHeart', 'spiritStone',
    'exp', 'lifespan', 'tianji', 'restart', 'ending', 'endingCandidate',
    'knowledge', 'wisdom', 'ancientKnowledge', 'cultivationKnowledge',
    'sword_insight', 'spell_insight', 'body_insight', 'pill_insight',
    'find_clue', 'alchemyYield', 'charmResist', 'combat_skill', 'critDamage',
    'cultivationRate', 'curseResist', 'damageReduction', 'daoHeartRecovery',
    'divinationAccuracy', 'dodge', 'fateEventsFavorability', 'fearResist',
    'heavenEnemyDamage', 'heroism', 'hpRegen', 'iceAtk', 'illusionPen',
    'intimidate', 'karmaSeedEffects', 'lowHpAtk', 'painConversion',
    'poisonResist', 'probabilityEvents', 'rageGeneration', 'rawPower',
    'researchSpeed', 'spellPower', 'swordAtk', 'pills', 'triggerCombat',
    'innerDemonCancel'
  ].map(field => [field, Object.freeze({ kind: 'behavior', consumer: 'EffectService' })])));

  static EFFECT_FIELD_PREFIX_CONTRACT = Object.freeze({
    'npc_relation:': { kind: 'behavior', consumer: 'EffectService._applyNpcRelation' },
    'bond_': { kind: 'behavior', consumer: 'EffectService/NpcSystem' }
  });

  static EFFECT_MAP_FIELDS = Object.freeze([
    'effects', 'entryEffects', 'victoryEffects', 'defeatEffects', 'fleeEffects',
    'vendorCloseEffects'
  ]);

  static COMBAT_REWARD_CONTROL_FIELD_CONTRACT = Object.freeze({
    breakSuccess: Object.freeze({
      kind: 'behavior',
      consumer: 'CombatCoordinator/GameLogic._resolveBreakthrough'
    })
  });

  static getEffectFieldContract(field) {
    if (ChoiceOutcomeRouter.EFFECT_FIELD_CONTRACT[field]) {
      return ChoiceOutcomeRouter.EFFECT_FIELD_CONTRACT[field];
    }
    const prefix = Object.keys(ChoiceOutcomeRouter.EFFECT_FIELD_PREFIX_CONTRACT)
      .find(candidate => String(field).startsWith(candidate) && String(field).length > candidate.length);
    return prefix ? ChoiceOutcomeRouter.EFFECT_FIELD_PREFIX_CONTRACT[prefix] : null;
  }

  static auditEffectFields(effects) {
    if (!effects || typeof effects !== 'object' || Array.isArray(effects)) {
      return { valid: false, unknownFields: ['$invalid_effect_map'], fields: [] };
    }
    const unknownFields = Object.keys(effects)
      .filter(field => !ChoiceOutcomeRouter.getEffectFieldContract(field))
      .sort();
    return {
      valid: unknownFields.length === 0,
      unknownFields,
      fields: Object.keys(effects).map(field => ({
        field,
        contract: ChoiceOutcomeRouter.getEffectFieldContract(field)
      }))
    };
  }

  static getCombatRewardFieldContract(field) {
    return ChoiceOutcomeRouter.getEffectFieldContract(field)
      || ChoiceOutcomeRouter.COMBAT_REWARD_CONTROL_FIELD_CONTRACT[field]
      || null;
  }

  static auditCombatRewardFields(rewards) {
    if (!rewards || typeof rewards !== 'object' || Array.isArray(rewards)) {
      return { valid: false, unknownFields: ['$invalid_combat_reward_map'], fields: [] };
    }
    const unknownFields = Object.keys(rewards)
      .filter(field => !ChoiceOutcomeRouter.getCombatRewardFieldContract(field))
      .sort();
    return {
      valid: unknownFields.length === 0,
      unknownFields,
      fields: Object.keys(rewards).map(field => ({
        field,
        contract: ChoiceOutcomeRouter.getCombatRewardFieldContract(field)
      }))
    };
  }

  static splitCombatRewardFields(rewards) {
    const audit = ChoiceOutcomeRouter.auditCombatRewardFields(rewards);
    if (!audit.valid) return { ...audit, effects: {}, controls: {} };
    const effects = {};
    const controls = {};
    for (const [field, value] of Object.entries(rewards)) {
      if (ChoiceOutcomeRouter.getEffectFieldContract(field)) effects[field] = value;
      else controls[field] = value;
    }
    return { ...audit, effects, controls };
  }

  constructor(options = {}) {
    this.gameStateRef = options.gameStateRef || null;
    this.eventBusRef = options.eventBusRef || null;
    this.ledgerRef = options.ledgerRef || null;
    this.flowDirectorRef = options.flowDirectorRef || null;
    this.cardResolver = typeof options.cardResolver === 'function' ? options.cardResolver : null;
    this.version = 1;
    this._initialized = false;
  }

  _state() {
    return this.gameStateRef || (typeof gameState !== 'undefined' ? gameState : null) || {};
  }

  _bus() {
    return this.eventBusRef || (typeof eventBus !== 'undefined' ? eventBus : null);
  }

  _ledger() {
    return this.ledgerRef || (typeof narrativeLedger !== 'undefined' ? narrativeLedger : null);
  }

  _decisionIndex(options = {}) {
    const state = this._state() || {};
    const explicit = options.decisionIndex ?? options.turn;
    if (Number.isFinite(Number(explicit))) {
      return Math.max(0, Math.floor(Number(explicit)));
    }
    if (options.next === true && typeof state.getNextDecisionIndex === 'function') {
      return Math.max(0, Math.floor(Number(state.getNextDecisionIndex()) || 0));
    }
    if (typeof state.getDecisionIndex === 'function') {
      return Math.max(0, Math.floor(Number(state.getDecisionIndex()) || 0));
    }
    return Math.max(0, Math.floor(Number(state.runClock?.decisionIndex ?? state.turn) || 0));
  }

  _flow() {
    return this.flowDirectorRef || (typeof flowDirector !== 'undefined' ? flowDirector : null);
  }

  init(options = {}) {
    if (options.gameStateRef) this.gameStateRef = options.gameStateRef;
    if (options.eventBusRef) this.eventBusRef = options.eventBusRef;
    if (options.ledgerRef) this.ledgerRef = options.ledgerRef;
    if (options.flowDirectorRef) this.flowDirectorRef = options.flowDirectorRef;
    if (typeof options.cardResolver === 'function') this.cardResolver = options.cardResolver;
    this._initialized = true;
    this.resumePendingPromises();
    return true;
  }

  _clone(value) {
    if (value === undefined) return undefined;
    return JSON.parse(JSON.stringify(value));
  }

  getChoiceFieldContract(field) {
    return ChoiceOutcomeRouter.CHOICE_FIELD_CONTRACT[field] || null;
  }

  getEffectFieldContract(field) {
    return ChoiceOutcomeRouter.getEffectFieldContract(field);
  }

  auditEffectFields(effects) {
    return ChoiceOutcomeRouter.auditEffectFields(effects);
  }

  getCombatRewardFieldContract(field) {
    return ChoiceOutcomeRouter.getCombatRewardFieldContract(field);
  }

  auditCombatRewardFields(rewards) {
    return ChoiceOutcomeRouter.auditCombatRewardFields(rewards);
  }

  splitCombatRewardFields(rewards) {
    return ChoiceOutcomeRouter.splitCombatRewardFields(rewards);
  }

  auditChoiceFields(choice) {
    const source = choice && typeof choice === 'object' ? choice : {};
    const unknownFields = Object.keys(source)
      .filter(field => !this.getChoiceFieldContract(field))
      .sort();
    for (const field of ChoiceOutcomeRouter.EFFECT_MAP_FIELDS) {
      if (!Object.prototype.hasOwnProperty.call(source, field)) continue;
      const effectAudit = this.auditEffectFields(source[field]);
      for (const nestedField of effectAudit.unknownFields) {
        unknownFields.push(`${field}.${nestedField}`);
      }
    }
    if (source.action?.type === 'ENTER_VENDOR'
      && source.effects
      && typeof source.effects === 'object'
      && !Array.isArray(source.effects)
      && Object.keys(source.effects).length > 0) {
      unknownFields.push('effects.$vendor_entry_effects_forbidden_use_vendorCloseEffects');
    }
    if (Object.prototype.hasOwnProperty.call(source, 'combatRewards')) {
      const rewardAudit = this.auditCombatRewardFields(source.combatRewards);
      for (const nestedField of rewardAudit.unknownFields) {
        unknownFields.push(`combatRewards.${nestedField}`);
      }
    }
    unknownFields.sort();
    return {
      valid: unknownFields.length === 0,
      unknownFields,
      fields: Object.keys(source).map(field => ({
        field,
        contract: this.getChoiceFieldContract(field)
      }))
    };
  }

  _authoredChoiceText(choice) {
    if (typeof choice?.narrativeBlock === 'string' && choice.narrativeBlock.trim()) {
      return choice.narrativeBlock.trim();
    }
    if (typeof choice?.desc === 'string' && choice.desc.trim()) return choice.desc.trim();
    return null;
  }

  _hash(text) {
    const source = String(text || '');
    let hash = 0x811c9dc5;
    for (let index = 0; index < source.length; index++) {
      hash ^= source.charCodeAt(index);
      hash = Math.imul(hash, 0x01000193);
    }
    return (hash >>> 0).toString(16).padStart(8, '0');
  }

  classifyCard(card) {
    if (!card || typeof card !== 'object') return 'UTILITY';
    if (card.type === 'NARRATIVE_RESULT' || card.promiseId) return 'UTILITY';
    if (card._isThreadCard === true) return 'PRIMARY';
    if (card.type === 'QUEST') return 'QUEST';
    if (card.type === 'MILESTONE') return 'WORLD_EVENT';
    if (new Set([
      'COMPANION_ARC', 'COMPANION_EVENT', 'MENTOR_ARC',
      'SEER_ARC', 'ALLY_ARC', 'NPC_CROSS'
    ]).has(card.type)) return 'RELATIONSHIP';
    if (card.type === 'STORY') {
      const tags = Array.isArray(card.tags) ? card.tags : [];
      if (String(card.id || '').startsWith('atm_')
        || tags.includes('atmosphere') || tags.includes('world_atmosphere')
        || card._narrativeLane === 'ambient') return 'AMBIENT';
      return 'PRIMARY';
    }
    return 'UTILITY';
  }

  _feedbackCue(card, choice, classification) {
    const authored = this._authoredChoiceText(choice);
    const substantial = Boolean(typeof choice?.narrativeBlock === 'string' && choice.narrativeBlock.trim())
      || Boolean(authored && ['PRIMARY', 'QUEST', 'WORLD_EVENT', 'RELATIONSHIP'].includes(classification))
      || Boolean(authored && ['SPECIAL', 'DESTINY'].includes(card?.type))
      || Boolean(authored && authored.length >= 40);
    return {
      kind: authored ? 'authored_result' : 'choice_acknowledged',
      text: authored || `你选择了「${choice.text || '继续'}」。`,
      lane: classification === 'AMBIENT' ? 'ambient' : 'narrative',
      display: substantial ? 'narrative' : 'brief'
    };
  }

  _resolution(card, choice, classification) {
    const authored = this._authoredChoiceText(choice);
    return {
      kind: classification === 'WORLD_EVENT' ? 'world_echo' : 'authored_choice_result',
      outcomeId: `outcome:${card.id}:${choice._choiceDirection || 'choice'}`,
      text: authored || `「${choice.text || '这项选择'}」已经发生。`
    };
  }

  _transition(card, direction, choice) {
    if (choice.transition && typeof choice.transition === 'object') {
      return this._clone(choice.transition);
    }
    if (choice.questNext || choice.nextCard) {
      return {
        kind: choice.questNext ? 'quest_next' : 'next_card',
        targetCardId: choice.questNext || choice.nextCard
      };
    }
    if (choice.threadDirection || choice._threadDirection || card._isThreadCard) {
      return {
        kind: 'story_thread_direction',
        threadId: card._threadId || null,
        direction: choice.threadDirection || choice._threadDirection || direction
      };
    }
    return null;
  }

  _promiseIdentity(card, direction) {
    const ledger = this._ledger();
    const semanticKey = ledger?.getSemanticKey?.(card)
      || card.semanticKey || `card:${card.id}`;
    const state = this._state() || {};
    const lifeCount = Math.max(0, Number(
      state.getLifeCount?.() ?? state.unlocks?.lifeCount ?? 0
    ) || 0);
    // semanticKey groups repeated beats for cooldown/once policy; card.id is
    // the concrete occurrence. Keeping both prevents a later legitimate
    // encounter from colliding with an already-resolved promise. Life scope
    // prevents a new incarnation from reusing a prior-life promise/result ID.
    return `promise:${this._hash(`life:${lifeCount}|${semanticKey}|${card.id}|${direction}`)}`;
  }

  _buildPromise(card, direction, choice) {
    const id = this._promiseIdentity(card, direction);
    const resultId = `promise_result_${this._hash(id)}`;
    const resultText = this._authoredChoiceText(choice)
      || `你在「${card.title || card.id}」中选择了「${choice.text || direction}」。这段因缘已给出明确回应。`;
    const resultCard = {
      id: resultId,
      semanticKey: `promise-result:${id}`,
      type: 'NARRATIVE_RESULT',
      title: `${card.title || '这段因缘'}·回应`,
      description: resultText,
      promiseId: id,
      originCardId: card.id,
      originChoice: direction,
      _narrativeLane: 'primary',
      _narrativeThreadKey: `promise:${id}`,
      _narrativeSticky: true,
      narrativeTtlTurns: 4,
      once: true,
      tags: ['narrative_result', 'promise_resolution'],
      choices: {
        left: {
          text: '记下这段回应',
          effects: {},
          resolution: { kind: 'promise_resolved', promiseId: id },
          feedbackCue: { kind: 'promise_resolved', text: resultText, lane: 'narrative' }
        }
      }
    };
    return {
      id,
      dueWithinDecisions: 2,
      followUpCard: resultCard
    };
  }

  _worldMutations(card, direction, choice) {
    if (choice.worldMutations && typeof choice.worldMutations === 'object') {
      return this._clone(choice.worldMutations);
    }
    return {
      flags: {
        [`choice:${card.id}:${direction}`]: true
      }
    };
  }

  prepareCard(card) {
    if (!card || typeof card !== 'object') return null;
    const prepared = this._clone(card);
    prepared.choices = prepared.choices && typeof prepared.choices === 'object'
      ? prepared.choices
      : {};
    const classification = this.classifyCard(prepared);
    prepared.choiceContractVersion = this.version;
    prepared.choiceClassification = classification;

    for (const [direction, rawChoice] of Object.entries(prepared.choices)) {
      if (!rawChoice || typeof rawChoice !== 'object') continue;
      const choice = rawChoice;
      choice._choiceDirection = direction;
      if (!choice.feedbackCue) choice.feedbackCue = this._feedbackCue(prepared, choice, classification);

      // narrativeBlock is authored as an actual post-choice scene, not hover
      // copy. Give it both an immediate receipt and the same persisted,
      // exactly-once follow-up used by core narrative choices, regardless of
      // the legacy card type that happens to carry it.
      if (typeof choice.narrativeBlock === 'string' && choice.narrativeBlock.trim()) {
        if (!choice.resolution) choice.resolution = this._resolution(prepared, choice, classification);
        if (!choice.transition && !choice.promise) {
          choice.promise = this._buildPromise(prepared, direction, choice);
        }
      }

      if (prepared.type === 'NARRATIVE_RESULT' || prepared.promiseId) {
        if (!choice.resolution) {
          choice.resolution = {
            kind: prepared.isPromiseClosure ? 'promise_closed' : 'promise_resolved',
            promiseId: prepared.promiseId || null
          };
        }
        continue;
      }

      const transition = this._transition(prepared, direction, choice);
      if (transition && !choice.transition) choice.transition = transition;

      if (classification === 'QUEST') {
        if (choice.questEnd === true && !choice.resolution) {
          choice.resolution = {
            kind: 'quest_closed',
            outcome: choice.questOutcome || 'completed'
          };
        }
        continue;
      }

      if (classification === 'AMBIENT') {
        if (!choice.resolution) choice.resolution = this._resolution(prepared, choice, classification);
        continue;
      }

      if (classification === 'WORLD_EVENT') {
        if (!choice.resolution) choice.resolution = this._resolution(prepared, choice, classification);
        if (!choice.worldMutations) {
          choice.worldMutations = this._worldMutations(prepared, direction, choice);
        }
        continue;
      }

      if (classification === 'PRIMARY' && prepared._isThreadCard === true) {
        continue;
      }

      if (classification === 'PRIMARY' || classification === 'RELATIONSHIP') {
        if (!choice.resolution) choice.resolution = this._resolution(prepared, choice, classification);
        // `first_session_serial` already names the next visible player beat.
        // Manufacturing a generic promise-result card between those two beats
        // turns a deliberate route -> vendor choice into an interruptible
        // pseudo-result and lets unrelated Flow work steal the screen.
        if (!choice.transition && !choice.promise && choice.continuityClass !== 'first_session_serial') {
          choice.promise = this._buildPromise(prepared, direction, choice);
        }
      }
    }
    return prepared;
  }

  validateCard(card) {
    const errors = [];
    if (!card || typeof card !== 'object' || !card.id) errors.push('invalid_card');
    const choices = card?.choices && typeof card.choices === 'object' ? card.choices : {};
    if (Object.keys(choices).length === 0) errors.push('missing_choices');
    const classification = card?.choiceClassification || this.classifyCard(card);
    for (const [direction, choice] of Object.entries(choices)) {
      if (!choice || typeof choice !== 'object') {
        errors.push(`${direction}:invalid_choice`);
        continue;
      }
      if (typeof choice.text !== 'string' || !choice.text.trim()) errors.push(`${direction}:missing_label`);
      const fieldAudit = this.auditChoiceFields(choice);
      for (const field of fieldAudit.unknownFields) {
        errors.push(`${direction}:unknown_choice_field:${field}`);
      }
      if (!choice.feedbackCue || typeof choice.feedbackCue !== 'object') {
        errors.push(`${direction}:missing_feedback`);
      }
      if (new Set(['PRIMARY', 'RELATIONSHIP', 'QUEST', 'WORLD_EVENT']).has(classification)
        && !choice.transition && !choice.resolution && !choice.promise && !choice.worldMutations) {
        errors.push(`${direction}:missing_outcome`);
      }
      if (classification === 'QUEST' && !choice.transition && !choice.resolution) {
        errors.push(`${direction}:quest_has_no_terminal_or_transition`);
      }
      if (choice.transition?.targetCardId && this.cardResolver
        && !this.cardResolver(choice.transition.targetCardId)) {
        // Quest cards may be loaded outside CardSystem during startup; an
        // explicit authored questNext remains valid and is resolved by QuestSystem.
        if (choice.transition.kind !== 'quest_next') {
          errors.push(`${direction}:missing_transition_target`);
        }
      }
      if (choice.promise) {
        if (!choice.promise.id) errors.push(`${direction}:promise_missing_id`);
        if (Number(choice.promise.dueWithinDecisions) > 2) errors.push(`${direction}:promise_overdue_contract`);
        const followUp = choice.promise.followUpCard;
        if (!followUp?.id || !followUp?.title || !followUp?.description
          || !followUp?.choices || Object.keys(followUp.choices).length === 0) {
          errors.push(`${direction}:invalid_promise_follow_up`);
        }
      }
    }
    return { valid: errors.length === 0, classification, errors };
  }

  _applyWorldMutations(mutations) {
    if (!mutations || typeof mutations !== 'object') return 0;
    const state = this._state();
    let count = 0;
    for (const [key, value] of Object.entries(mutations.flags || {})) {
      if (typeof state.setFlag === 'function') state.setFlag(key, value);
      else {
        if (!state.flags || typeof state.flags !== 'object') state.flags = {};
        state.flags[key] = value;
      }
      count++;
    }
    return count;
  }

  _enqueuePromiseCard(card, source = 'choice_promise') {
    if (!card || !card.id) return false;
    const flow = this._flow();
    return !!flow?.enqueueNarrative?.(this.prepareCard(card), 58, source);
  }

  commitChoice(card, direction, selectedChoice = null) {
    const prepared = this.prepareCard(card);
    if (!prepared) return { committed: false, reason: 'invalid_card' };
    const validation = this.validateCard(prepared);
    if (!validation.valid) {
      return { committed: false, reason: 'invalid_choice_contract', errors: validation.errors };
    }
    const choice = prepared.choices?.[direction] || selectedChoice;
    if (!choice) return { committed: false, reason: 'missing_choice' };
    const ledger = this._ledger();
    const decisionIndex = this._decisionIndex({ next: true });

    let resolvedPromiseId = null;
    if (prepared.promiseId) {
      const resolved = ledger?.resolvePromise?.(prepared.promiseId, {
        resolutionCardId: prepared.id,
        decisionIndex
      });
      if (resolved?.resolved) resolvedPromiseId = prepared.promiseId;
    }

    const mutationCount = this._applyWorldMutations(choice.worldMutations);
    let promiseId = null;
    let promiseQueued = false;
    let immediateCard = null;
    if (choice.promise && !prepared.promiseId) {
      const definition = {
        ...this._clone(choice.promise),
        sourceCardId: prepared.id,
        sourceSemanticKey: this._ledger()?.getSemanticKey?.(prepared)
          || prepared.semanticKey || `card:${prepared.id}`,
        sourceTitle: prepared.title || prepared.id,
        choiceDirection: direction,
        createdDecisionIndex: decisionIndex
      };
      const created = ledger?.createPromise?.(definition);
      if (created?.created) {
        promiseId = created.promise.id;
        immediateCard = this.prepareCard(created.promise.followUpCard);
        promiseQueued = this._enqueuePromiseCard(created.promise.followUpCard);
      }
    }

    this.reconcilePromises({ decisionIndex });
    const payload = {
      cardId: prepared.id,
      direction,
      classification: validation.classification,
      promiseId,
      promiseQueued,
      resolvedPromiseId,
      mutationCount
    };
    this._bus()?.emit?.('narrative:choiceCommitted', payload);
    return { committed: true, immediateCard, ...payload };
  }

  resolvePromiseAtTerminal(promiseCard, terminalCard, reason = 'terminal_state') {
    const promiseId = typeof promiseCard?.promiseId === 'string' ? promiseCard.promiseId : null;
    const terminalCardId = typeof terminalCard?.id === 'string' ? terminalCard.id : null;
    if (!promiseId || !terminalCardId) {
      return { resolved: false, reason: 'invalid_terminal_promise' };
    }
    const resolved = this._ledger()?.resolvePromise?.(promiseId, {
      resolutionCardId: terminalCardId,
      decisionIndex: this._decisionIndex({ next: true })
    });
    if (resolved?.resolved) {
      this._bus()?.emit?.('narrative:promiseTerminalResolved', {
        promise: resolved.promise,
        reason,
        terminalCardId
      });
    }
    return resolved || { resolved: false, reason: 'missing_ledger' };
  }

  _buildClosureCard(promise) {
    const id = `promise_closure_${this._hash(promise.id)}`;
    const description = `「${promise.sourceTitle || promise.sourceCardId || '这段因缘'}」的后续因行程或世界变化被打断。这段承诺已明确收束，不会无声消失。`;
    return {
      id,
      semanticKey: `promise-closure:${promise.id}`,
      type: 'NARRATIVE_RESULT',
      title: `${promise.sourceTitle || '这段因缘'}·未竟`,
      description,
      promiseId: promise.id,
      isPromiseClosure: true,
      originCardId: promise.sourceCardId,
      originChoice: promise.choiceDirection,
      _narrativeLane: 'primary',
      _narrativeThreadKey: `promise:${promise.id}`,
      _narrativeSticky: true,
      narrativeTtlTurns: 4,
      once: true,
      tags: ['narrative_result', 'promise_closure'],
      choices: {
        left: {
          text: '接受这段因缘的收束',
          effects: {},
          resolution: { kind: 'promise_closed', promiseId: promise.id },
          feedbackCue: { kind: 'promise_closed', text: description, lane: 'narrative' }
        }
      }
    };
  }

  reconcilePromises(options = {}) {
    const ledger = this._ledger();
    const pending = ledger?.getPendingPromises?.() || [];
    const decisionIndex = this._decisionIndex(options);
    let resumed = 0;
    let closed = 0;
    for (const promise of pending) {
      if (promise.status === 'closing') {
        const closure = promise.closureCard || this._buildClosureCard(promise);
        if (this._enqueuePromiseCard(closure, 'choice_promise_closure')) resumed++;
        continue;
      }
      if (decisionIndex > Number(promise.dueDecisionIndex ?? promise.createdDecisionIndex ?? 0)) {
        const closure = this._buildClosureCard(promise);
        const marked = ledger.markPromiseClosing(promise.id, {
          reason: 'due_window_elapsed',
          closureCard: closure
        });
        if (marked?.closing) {
          if (this._enqueuePromiseCard(closure, 'choice_promise_closure')) resumed++;
          closed++;
        }
        continue;
      }
      if (this._enqueuePromiseCard(promise.followUpCard)) resumed++;
    }
    return { pending: pending.length, resumed, closed };
  }

  getImmediatePendingCard() {
    const pending = this._ledger()?.getPendingPromises?.() || [];
    pending.sort((left, right) => (
      Number(left.createdDecisionIndex || 0) - Number(right.createdDecisionIndex || 0)
      || String(left.id || '').localeCompare(String(right.id || ''))
    ));
    const promise = pending[0];
    if (!promise) return null;
    const card = promise.status === 'closing'
      ? (promise.closureCard || this._buildClosureCard(promise))
      : promise.followUpCard;
    return card ? this.prepareCard(card) : null;
  }

  resumePendingPromises() {
    const result = this.reconcilePromises();
    return { ...result, immediateCard: this.getImmediatePendingCard() };
  }
}

const choiceOutcomeRouter = new ChoiceOutcomeRouter();

if (typeof window !== 'undefined') {
  window.ChoiceOutcomeRouter = ChoiceOutcomeRouter;
  window.choiceOutcomeRouter = choiceOutcomeRouter;
}

if (typeof module !== 'undefined' && module.exports) {
  module.exports = ChoiceOutcomeRouter;
}
