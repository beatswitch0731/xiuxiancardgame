#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const vm = require('vm');
const crypto = require('crypto');
const { POLICY_IDS, selectDecision } = require('./gdd_b3_decision_policies');
const { createAuthorityRecorder, summarizeAuthorityTrace } = require('./gdd_b3_authority_metrics');
const { createPolicyInputLedger } = require('./gdd_b3_policy_input_ledger');

const ROOT = path.resolve(__dirname, '..');
const PATHS = Object.freeze(['sword', 'spell', 'body', 'pill']);
const THREAD_MODULES = Object.freeze([
  'threads:qi_threads',
  'threads:foundation_threads',
  'threads:golden_threads',
  'threads:nascent_threads',
  'threads:deity_threads',
  'threads:tribulation_threads',
  'threads:last_lesson_threads'
]);

const RUNTIME_SCRIPTS = Object.freeze([
  'src/core/EventBus.js',
  'src/core/TextPresentation.js',
  'src/core/GameStateManager.js',
  'src/systems/WorldContinuityStore.js',
  'src/systems/NarrativeLedger.js',
  'src/systems/KarmaSystem.js',
  'src/systems/CardSystem.js',
  'src/systems/QuestSystem.js',
  'src/systems/NpcSystem.js',
  'src/systems/CompanionSystem.js',
  'src/systems/FactionSystem.js',
  'src/systems/EquipmentSystem.js',
  'src/systems/TreasureSystem.js',
  'src/systems/PathSkillSystem.js',
  'src/systems/PathArchetypeSystem.js',
  'src/systems/ShopSystem.js',
  'src/systems/DeckCombatSystem.js',
  'src/systems/SkillCardAcquisitionSystem.js',
  'src/systems/OpportunityAcquisitionSystem.js',
  'src/systems/StoryNetworkSystem.js',
  'src/systems/ChoiceEchoEngine.js',
  'src/systems/SceneLayerSystem.js',
  'src/systems/DestinyWheelSystem.js',
  'src/systems/LegacyFragmentSystem.js',
  'src/systems/KarmaRippleSystem.js',
  'src/systems/HeavensHintSystem.js',
  'src/systems/MarketSystem.js',
  'src/systems/StoryThreadEngine.js',
  'src/systems/NarrativeCoherenceLayer.js',
  'src/systems/RealmChapterSystem.js',
  'src/systems/NarrativeDirector.js',
  'src/systems/EncounterDirector.js',
  'src/systems/FlowDirector.js',
  'src/systems/ChoiceOutcomeRouter.js',
  'src/systems/EvidenceAtlasSystem.js',
  'src/systems/TradeRouteSystem.js',
  'src/systems/LineageSystem.js',
  'src/systems/WorldPulseSystem.js',
  'src/services/EndingEligibilityService.js',
  'src/services/EffectService.js',
  'src/coordinators/CombatCoordinator.js',
  'src/game.js',
  'src/core/Container.js'
]);

const read = relative => fs.readFileSync(path.join(ROOT, relative), 'utf8').replace(/^\uFEFF/, '');
const clone = value => value == null ? value : JSON.parse(JSON.stringify(value));

function collectProductionModules() {
  const modules = {};
  const dataRoot = path.join(ROOT, 'data');
  const visit = directory => {
    for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
      const full = path.join(directory, entry.name);
      if (entry.isDirectory()) visit(full);
      else if (entry.isFile() && entry.name.endsWith('.json')) {
        const relative = path.relative(dataRoot, full).replace(/\\/g, '/').replace(/\.json$/, '');
        const moduleName = relative === 'npcs/core_npcs' ? 'npcs:core' : relative.replace(/\//g, ':');
        modules[moduleName] = JSON.parse(fs.readFileSync(full, 'utf8').replace(/^\uFEFF/, ''));
      }
    }
  };
  visit(dataRoot);
  return modules;
}

const PRODUCTION_MODULES = collectProductionModules();

function createPrng(seed) {
  let value = (Math.abs(Math.floor(Number(seed) || 1)) >>> 0) || 1;
  return function random() {
    value += 0x6D2B79F5;
    let mixed = value;
    mixed = Math.imul(mixed ^ mixed >>> 15, mixed | 1);
    mixed ^= mixed + Math.imul(mixed ^ mixed >>> 7, mixed | 61);
    return ((mixed ^ mixed >>> 14) >>> 0) / 4294967296;
  };
}

function createMemoryStorage() {
  const values = new Map();
  return {
    getItem(key) { return values.has(String(key)) ? values.get(String(key)) : null; },
    setItem(key, value) { values.set(String(key), String(value)); },
    removeItem(key) { values.delete(String(key)); },
    clear() { values.clear(); },
    key(index) { return [...values.keys()][index] || null; },
    get length() { return values.size; }
  };
}

function makeConsole(verbose) {
  if (verbose) return console;
  return { log() {}, info() {}, debug() {}, warn() {}, error() {} };
}

function execute(context, source, filename = 'b12-runtime.js') {
  return vm.runInContext(source, context, { filename });
}

function createProductionRuntime({ pathId = 'sword', seed = 1, verbose = false, restoreStorage = null } = {}) {
  if (!PATHS.includes(pathId)) throw new Error(`Unknown path: ${pathId}`);
  const random = createPrng(seed);
  const seededMath = Object.create(Math);
  seededMath.random = random;
  let logicalNow = 1_000_000 + Math.abs(Number(seed) || 0) * 1000;
  let timerSequence = 0;
  const scheduledTimers = new Map();
  const scheduleTimer = (callback, delay = 0, ...args) => {
    const timerId = ++timerSequence;
    scheduledTimers.set(timerId, {
      at: logicalNow + Math.max(0, Number(delay) || 0),
      callback,
      args
    });
    return timerId;
  };
  const cancelTimer = timerId => scheduledTimers.delete(timerId);
  const flushTimers = (limit = 256) => {
    // Advance only the callbacks that already belong to the current public
    // action. A callback may schedule the next visual/settlement boundary;
    // that new boundary is consumed by the next simulation step. Draining
    // until global idle would chase unrelated self-rescheduling services.
    const currentBatch = [...scheduledTimers.entries()]
      .sort((left, right) => left[1].at - right[1].at || left[0] - right[0]);
    if (currentBatch.length > limit) throw new Error('deterministic_timer_batch_overflow');
    let executed = 0;
    for (const [timerId, timer] of currentBatch) {
      if (!scheduledTimers.has(timerId)) continue;
      scheduledTimers.delete(timerId);
      logicalNow = Math.max(logicalNow, timer.at);
      if (typeof timer.callback === 'function') timer.callback(...timer.args);
      executed += 1;
    }
    return executed;
  };
  class DeterministicDate extends Date {
    static now() { logicalNow += 1; return logicalNow; }
  }
  const context = vm.createContext({
    console: makeConsole(verbose),
    Math: seededMath,
    Date: DeterministicDate,
    JSON,
    Object,
    Array,
    Number,
    String,
    Boolean,
    RegExp,
    Map,
    Set,
    WeakMap,
    WeakSet,
    Promise,
    Symbol,
    BigInt,
    Error,
    TypeError,
    RangeError,
    parseInt,
    parseFloat,
    isFinite,
    structuredClone: value => clone(value),
    localStorage: restoreStorage || createMemoryStorage(),
    __restoreProductionSession: Boolean(restoreStorage),
    performance: { now: () => ++logicalNow },
    setTimeout: scheduleTimer,
    clearTimeout: cancelTimer,
    setInterval: () => ++timerSequence,
    clearInterval: cancelTimer,
    requestAnimationFrame: () => 1,
    cancelAnimationFrame() {},
    __XIUXIAN_DEBUG__: false,
    DATA_MODULES: clone(PRODUCTION_MODULES),
    dataLoader: {
      cache: new Map(),
      loadSync(name) { return context.DATA_MODULES[name] || null; },
      getCached(name) { return context.DATA_MODULES[name] || null; },
      async load(name) { return context.DATA_MODULES[name] || null; },
      async preload(names) { return names.map(name => context.DATA_MODULES[name] || null); }
    },
    experienceSettings: { init() {}, get(key) { return key === 'reactionMode' ? 'paused' : null; } },
    immersionDirector: null,
    audioManager: null,
    worldArtDirector: null,
    worldMapSystem: null,
    renderLoopCoordinator: null
  });
  context.window = context;
  context.global = context;
  context.globalThis = context;

  for (const relative of RUNTIME_SCRIPTS) execute(context, read(relative), relative);

  execute(context, `
    worldContinuityStore.init();
    npcSystem.init();
    const __npcData = dataLoader.loadSync('npcs:core');
    if (__npcData) npcSystem.loadData(__npcData);
    const __npcRelations = dataLoader.loadSync('npcs:npc_relations');
    if (__npcRelations) npcSystem.loadNpcRelations(__npcRelations);
    const __npcCross = dataLoader.loadSync('npcs:npc_cross_cards');
    if (__npcCross) npcSystem.loadCrossCards(__npcCross);

    companionSystem.init();
    const __companionData = dataLoader.loadSync('companions:events');
    if (__companionData) companionSystem.loadData(__companionData);
    const __portraitData = dataLoader.loadSync('companions:portrait_stages');
    if (__portraitData) companionSystem.loadPortraitData(__portraitData);

    factionSystem.init();
    const __factionData = dataLoader.loadSync('world:factions');
    if (__factionData) factionSystem.loadData(__factionData);

    const __arcData = dataLoader.loadSync('companions:arcs');
    if (__arcData) {
      storyNetworkSystem.loadArcs(__arcData);
      storyNetworkSystem.registerLoadedRoleArcs();
      storyNetworkSystem.registerOwnedCompanionArcs(gameState.resources?.companions || []);
      // Match index.html's cold startup; do not overwrite the restored owner
      // with freshly registered default arcs when the first battle is saved.
      if (gameState.storyNetworkState) storyNetworkSystem.hydrateState(gameState.storyNetworkState);
    }
    const __locationData = dataLoader.loadSync('locations:locations');
    if (__locationData) sceneLayerSystem.loadData(__locationData);

    window.coherenceLayer = new NarrativeCoherenceLayer();
    window.chapterSystem = new RealmChapterSystem();
    window._chapterMilestoneData = null;
    window.flowDirector = FlowDirector.create({ encounterDirectorRef: window.encounterDirector });

    const __metrics = {
      events: [],
      authorityBypasses: 0,
      choiceRejects: 0,
      currentDecision: 0
    };
    const __compactMetricPayload = (name, payload) => {
      if (!payload || typeof payload !== 'object') return null;
      const base = {};
      const copy = keys => keys.forEach(key => {
        if (payload[key] !== undefined) base[key] = payload[key];
      });
      if (name.startsWith('encounter:')) {
        copy(['encounterId', 'cardId', 'encounterKind', 'role', 'reason', 'scheduledDecision',
          'decision', 'realm', 'path', 'direction', 'outcome', 'nextInterval', 'narrativeSource']);
      } else if (name === 'combat:started') {
        const activeCard = deckCombatSystem.originalCard || {};
        base.cardId = activeCard.id || payload.sourceCardId || null;
        base.realm = activeCard.realm || gameState.realm || null;
        base.encounterRole = activeCard.encounterRole || null;
        base.encounterKind = activeCard.encounterKind || null;
        base.player = {
          hp: Number(deckCombatSystem.player?.hp) || 0,
          maxHp: Number(deckCombatSystem.player?.maxHp) || 0,
          persistentHealth: Number(deckCombatSystem.preCombatHealth) || 0,
          atkMod: Number(deckCombatSystem.player?.atkMod) || 0,
          defMod: Number(deckCombatSystem.player?.defMod) || 0
        };
        base.enemy = {
          hp: Number(deckCombatSystem.enemy?.hp) || 0,
          maxHp: Number(deckCombatSystem.enemy?.maxHp) || 0,
          tier: Number(deckCombatSystem.enemy?.tier) || 0,
          atkPower: Number(deckCombatSystem.enemy?.atkPower) || 0,
          defPower: Number(deckCombatSystem.enemy?.defPower) || 0
        };
      } else if (name.startsWith('combat:reaction')) {
        copy(['reactionId', 'windowId', 'result', 'pathId', 'turn', 'sourceCardId']);
        const action = payload.action || deckCombatSystem.pendingReaction?.action || null;
        if (action) {
          base.action = {
            actionFamily: action.actionFamily || null,
            expectedDamage: Number(action.expectedDamage) || 0,
            piercing: action.piercing === true
          };
        }
      } else if (name === 'combat:victory' || name === 'combat:defeat' || name === 'combat:fled') {
        copy(['cardId', 'outcome']);
        const original = payload.originalCard || {};
        base.originalCard = {
          id: original.id || null,
          realm: original.realm || null,
          encounterRole: original.encounterRole || null,
          encounterKind: original.encounterKind || null
        };
        const encounter = payload.encounterContext || {};
        base.encounterContext = {
          encounterInstanceId: encounter.encounterInstanceId || null,
          cardId: encounter.cardId || null,
          realm: encounter.realm || null,
          encounterRole: encounter.encounterRole || null,
          encounterKind: encounter.encounterKind || null
        };
      } else if (name.startsWith('narrative:promise')) {
        copy(['reason', 'terminalCardId']);
        const record = payload.promise || payload;
        base.promise = {
          id: record.id || record.promiseId || null,
          createdChoiceCount: record.createdChoiceCount,
          resolvedAtChoiceCount: record.resolvedAtChoiceCount,
          resolutionCardId: record.resolutionCardId || null,
          expiresAtChoiceCount: record.expiresAtChoiceCount,
          expirationReason: record.expirationReason || null,
          status: record.status || null
        };
      } else if (name.startsWith('narrative:')) {
        copy(['threadId', 'nodeId', 'semanticKey', 'threadKey', 'reason', 'worldRevision']);
      } else if (name.startsWith('shop:') || name.startsWith('vendor:')) {
        copy(['vendorId', 'entryCardId', 'sessionId', 'sessionKey', 'purchaseCount', 'totalSpent', 'reason']);
      } else if (name === 'state:realmChanged') {
        copy(['from', 'to']);
      } else if (name === 'state:death') {
        copy(['cause', 'reason', 'turn']);
      } else if (name === 'npc:interaction') {
        copy(['npcId', 'cardId', 'manifestation']);
      } else {
        return JSON.parse(JSON.stringify(payload));
      }
      return JSON.parse(JSON.stringify(base));
    };
    [
      'narrative:nodePresented', 'narrative:nodeInvalidated',
      'narrative:promiseCreated', 'narrative:promiseResolved', 'narrative:promiseExpired',
      'narrative:promiseTerminalResolved',
      'narrative:semanticRepeatPrevented',
      'encounter:scheduled', 'encounter:presented', 'encounter:accepted',
      'encounter:avoided', 'encounter:resolved', 'encounter:invalidated',
      'combat:started', 'combat:victory', 'combat:defeat', 'combat:fled',
      'combat:reactionOpened', 'combat:reactionChosen', 'combat:reactionResolved',
      'shop:open', 'shop:closed', 'vendor:entered', 'vendor:purchased', 'vendor:closed',
      'npc:interaction', 'state:death', 'state:realmChanged'
    ].forEach(name => eventBus.on(name, payload => {
      __metrics.events.push({
        name,
        turn: Number(gameState.turn) || 0,
        life: Number(gameState.getLifeCount?.() || 0),
        decision: Number(__metrics.currentDecision) || 0,
        payload: __compactMetricPayload(name, payload)
      });
    }));

    eventBus.on('shop:open', payload => {
      shopSystem.open(payload.items, {
        source: payload.vendorId === 'ghost_market' ? 'market' : 'shop',
        vendorId: payload.vendorId,
        entryCardId: payload.entryCardId,
        sessionKey: payload.sessionKey,
        summary: payload.summary
      });
    });

    const __container = new Container({ debug: false });
    // The browser UI consumes this event by showing the path selector. The
    // deterministic runner is that input consumer and reselects the path under
    // test through GameLogic's public start boundary.
    eventBus.on('reincarnation:pathSelectionRequired', () => {
      __container.game.start(${JSON.stringify(pathId)});
    });
    // Restore tests supply copied persisted strings to a genuinely new VM.
    // Keep the production constructor/init graph, but do not overwrite the
    // loaded life with the normal new-run simulation setup.
    if (!window.__restoreProductionSession) {
      gameState.unlocks.tutorialCompleted = true;
      gameState._saveUnlocks();
      __container.game.start(${JSON.stringify(pathId)});
    }
    window.__b12 = {
      container: __container,
      game: __container.game,
      state: gameState,
      flow: window.flowDirector,
      cardSystem,
      shop: shopSystem,
      deck: deckCombatSystem,
      continuity: worldContinuityStore,
      ledger: narrativeLedger,
      threadEngine,
      narrative: window.narrativeDirector,
      encounter: window.encounterDirector,
      eventBus,
      metrics: __metrics
    };
  `, 'b12-bootstrap.js');

  context.__b12.flushTimers = flushTimers;
  context.__b12.storage = context.localStorage;
  return context.__b12;
}

function normalizeChoices(card) {
  if (!card?.choices || typeof card.choices !== 'object') return [];
  if (Array.isArray(card.choices)) return card.choices.map((choice, index) => ({ direction: String(index), choice }));
  return Object.entries(card.choices).map(([direction, choice]) => ({ direction, choice }));
}

function choiceScore(state, card, choice, random) {
  const effects = choice?.effects || {};
  const missingHealth = Math.max(0, Number(state.maxHealth) - Number(state.attributes?.health));
  const missingDao = Math.max(0, Number(state.maxDaoHeart) - Number(state.attributes?.daoHeart));
  let score = random() * 2;
  score += Math.min(missingHealth, Math.max(0, Number(effects.health) || 0)) * 7;
  score += Math.min(missingDao, Math.max(0, Number(effects.daoHeart) || 0)) * 5;
  score += Math.max(0, Number(effects.cultivation) || 0) * 0.4;
  score += Math.max(0, Number(effects.spiritStone) || 0) * 0.2;
  score += Math.max(0, Number(effects.karmaGood) || 0) * 0.1;
  if (choice.triggerCombat || effects.triggerCombat) {
    score += card?.teachingEncounter === true ? 30 : 2;
  }
  if (choice.action?.type === 'ENTER_VENDOR') score += 0.25;
  return score;
}

function pickNarrativeChoice(runtime, random) {
  const card = runtime.game.getCurrentCard();
  // Use the same full action/eligibility projection as the player's UI and
  // makeChoice. Numeric effects alone cannot authorize a vendor or dungeon.
  const previews = runtime.game.previewCardChoices(card, {
    source: 'gdd_b12_long_run',
    cardId: card?.id || null,
    cardTags: card?.tags || []
  });
  const options = normalizeChoices(card).filter(item => (
    item.choice?.available !== false && previews?.[item.direction]?.executable === true
  ));
  const pool = options.length ? options : [];
  pool.forEach(item => { item.score = choiceScore(runtime.state, card, item.choice, random); });
  pool.sort((left, right) => right.score - left.score || left.direction.localeCompare(right.direction));
  return { card, selected: pool[0] || null };
}

function observeDecision(runtime, card, decision) {
  const focusBefore = runtime.narrative?.primaryFocus?.threadKey || null;
  const lane = card?._narrativeLane || card?.lane || (card?._isThreadCard ? 'primary' : null);
  const threadKey = card?._narrativeThreadKey
    || (card?._threadId ? `thread:${card._threadId}` : null);
  const npcIds = [...new Set([
    card?.npcId,
    card?.compId,
    ...(Array.isArray(card?.npcIds) ? card.npcIds : [])
  ].filter(Boolean))];
  const physical = (card?.manifestation || 'PHYSICAL') === 'PHYSICAL';
  const illegalNpcIds = physical
    ? npcIds.filter(id => !runtime.continuity?.canManifest?.(id, 'PHYSICAL'))
    : [];
  const repeatPolicy = runtime.ledger?.getRepeatPolicy?.(card)
    || { mode: 'unrestricted', cooldownTurns: 0 };
  return {
    decision,
    turn: Number(runtime.state.turn) || 0,
    health: Number(runtime.state.attributes?.health) || 0,
    maxHealth: Number(runtime.state.getActualMaxHealth?.() || runtime.state.maxHealth) || 0,
    deckSize: Array.isArray(runtime.state.deck) ? runtime.state.deck.length : 0,
    cardId: card?.id || null,
    realm: runtime.state.realm || null,
    life: Number(runtime.state.getLifeCount?.() || 0),
    semanticKey: card?.semanticKey || null,
    repeatPolicy: {
      mode: repeatPolicy.mode || 'unrestricted',
      cooldownTurns: Math.max(0, Number(repeatPolicy.cooldownTurns) || 0)
    },
    lane,
    threadKey,
    focusBefore,
    illegalNpcIds
  };
}

function cardValue(deck, cardId, index) {
  const card = deck.getCardDef(cardId);
  if (!card || Number(card.cost) > Number(deck.qi)) return null;
  let damage = 0;
  let block = 0;
  let heal = 0;
  let qi = 0;
  let status = 0;
  for (const effect of card.effects || []) {
    if (effect.type === 'damage') damage += Number(effect.value) || 0;
    if (effect.type === 'block') block += Number(effect.value) || 0;
    if (effect.type === 'heal') heal += Number(effect.value) || 0;
    if (effect.type === 'gain_qi') qi += Number(effect.value) || 0;
    if (effect.type === 'status') status += Math.max(0, Number(effect.value) || 0);
  }
  const incoming = deck.enemyIntent?.type === 'attack' ? Number(deck.enemyIntent.value) || 0 : 0;
  const blockNeed = Math.max(0, incoming - Number(deck.player?.block || 0));
  const missing = Math.max(0, Number(deck.player?.maxHp || 0) - Number(deck.player?.hp || 0));
  const lethal = damage >= Number(deck.enemy?.hp || Infinity) ? 1000 : 0;
  return {
    index,
    score: lethal + damage * 6 + Math.min(blockNeed, block) * 7 + block + Math.min(missing, heal) * 5 + qi * 2 + status
  };
}

function chooseReaction(deck, pathId, random = Math.random) {
  const pending = deck.pendingReaction;
  if (!pending || !Array.isArray(pending.options)) return null;
  const preference = {
    sword: ['DEFLECT', 'GUARD', 'TAKE_HIT'],
    spell: ['INTERRUPT', 'GUARD', 'TAKE_HIT'],
    body: ['ABSORB', 'GUARD', 'TAKE_HIT'],
    pill: ['TRANSMUTE', 'GUARD', 'TAKE_HIT']
  }[pathId] || ['GUARD', 'TAKE_HIT'];
  // Match the established balance harness' average-player policy: one quarter
  // of windows are conservatively/mistakenly taken instead of always solving
  // the authored path reaction perfectly.
  if (random() < 0.5) {
    const takeHit = pending.options.find(candidate => (
      candidate.id === 'TAKE_HIT' && candidate.available !== false
    ));
    if (takeHit) return takeHit;
  }
  for (const id of preference) {
    const option = pending.options.find(candidate => candidate.id === id && candidate.available !== false);
    if (option) return option;
  }
  return pending.options.find(option => option.available !== false) || null;
}

function applyPolicyInput(runtime, policyId, trace) {
  const deck = runtime.deck;
  const before = clone(deck.getPublicCombatDecisionView());
  const beforeBytes = JSON.stringify(before);
  const choice = selectDecision(before, policyId);
  if (choice.kind === 'wait') throw Error('policy_input_locked_after_timer_flush');
  // Re-observe immediately before dispatch. A policy is not an authority token
  // and cannot re-use an index/window after a synchronous observable change.
  if (JSON.stringify(deck.getPublicCombatDecisionView()) !== beforeBytes) throw Error('policy_observation_changed');
  const owner = deck.encounterContext?.encounterInstanceId;
  if (!owner) throw Error('policy_input_missing_encounter_owner');
  const lifeId = runtime.state.runClock.lifeId, slotId = runtime.state.getActiveSaveSlotId();
  const reactionObservations = [];
  const cardCompletions = [];
  const onReaction = payload => {
    if (payload.windowId === choice.windowId) reactionObservations.push(clone(payload));
  };
  if (choice.kind === 'reaction') runtime.eventBus.on('combat:reactionResolved', onReaction);
  const onCardCompleted = payload => {
    if (payload.source === 'player' && payload.sourceId === choice.cardId) cardCompletions.push({
      hp: deck.player.hp, block: deck.player.block, enemyHp: deck.enemy.hp, enemyBlock: deck.enemy.block, qi: deck.qi
    });
  };
  if (choice.kind === 'playCard') runtime.eventBus.on('combat:actionCompleted', onCardCompleted);
  let outcome;
  try {
    if (choice.kind === 'playCard') {
      if (before.hand[choice.index]?.id !== choice.cardId) throw Error('policy_stale_card');
      outcome = deck.playCard(choice.index);
    } else if (choice.kind === 'reaction') outcome = deck.chooseReaction(choice.reactionId, choice.windowId);
    else if (choice.kind === 'endTurn') outcome = deck.endTurn();
    else throw Error('invalid_policy_input_kind');
  } finally {
    runtime.eventBus.off('combat:reactionResolved', onReaction);
    runtime.eventBus.off('combat:actionCompleted', onCardCompleted);
  }
  const accepted = outcome === true || outcome?.resolved === true || outcome?.opened === true;
  const after = clone(deck.getPublicCombatDecisionView());
  const containmentFailures = [];
  let containmentScope = 'not_applicable_to_input_kind';
  if (choice.kind === 'reaction' && accepted) {
    containmentScope = 'actual_reaction_resolution_hp';
    if (reactionObservations.length !== 1) containmentFailures.push({ key: 'reactionResolutionCount', actual: reactionObservations.length });
    else {
      const hp = reactionObservations[0].playerHp;
      if (choice.hp.min !== null && (hp < choice.hp.min || hp > choice.hp.max)) {
        containmentFailures.push({ key: 'reactionHp', bound: choice.hp, actual: hp });
      }
      if (choice.roundSurvival === true && hp <= 0) containmentFailures.push({ key: 'roundSurvival', actual: false });
    }
  }
  if (choice.kind === 'playCard') {
    containmentScope = !after ? 'terminal_requires_result_receipt' : 'immediate_card_public_deltas';
    // End-of-card numerical evidence precedes _handleEnemyDefeated. Comparing
    // the next phase's new HP against the previous phase would be invalid.
    if (cardCompletions.length === 1) {
      containmentScope = 'card_completed_before_phase_or_terminal_transition';
      const a = cardCompletions[0];
      const b = Object.fromEntries(before.facts.rows.map(r => [r.id, r.value]));
      const actual = { hp: a.hp, block: a.block - b.player_block,
        damage: Math.max(0, b.enemy_hp.current) - Math.max(0, a.enemyHp),
        enemyBlockSpent: b.enemy_block - a.enemyBlock, qi: a.qi };
      for (const [key, value] of Object.entries(actual)) {
        const bound = choice[key];
        if (bound?.min !== null && bound?.max !== null && bound !== undefined
          && (value < bound.min || value > bound.max)) containmentFailures.push({ key, bound, actual: value });
      }
    } else if (choice.damage?.min !== null && choice.hp?.max > 0) {
      containmentFailures.push({ key: 'cardCompletionCount', actual: cardCompletions.length });
    }
  }
  trace.push({ owner, lifeId, slotId, beforeHash: crypto.createHash('sha256').update(beforeBytes).digest('hex'),
    before, choice, accepted, outcome: clone(outcome), after, reactionObservations, cardCompletions, containmentScope, containmentFailures });
  if (!accepted) throw Error('policy_input_rejected:' + choice.kind);
  if (containmentFailures.length) throw Error('policy_projection_containment_failed');
}

function joinPolicyVictories(strategy, authorityMetrics) {
  let valid = true;
  for (const row of strategy.decisions) {
    if (row.choice.battleVictory !== true) continue;
    const joined = authorityMetrics.battles.find(battle => battle.encounterInstanceId === row.owner
      && battle.lifeId === row.lifeId && battle.slotId === row.slotId);
    row.victoryReceiptJoin = joined ? clone(joined) : null;
    if (authorityMetrics.status !== 'TRUSTED' || joined?.outcome !== 'victory') valid = false;
  }
  return valid;
}

async function settleCombat(runtime, pathId, random = Math.random, strategy = null) {
  let safety = 0;
  let observedTurn = Number(runtime.deck.turn) || 0;
  let playsThisTurn = 0;
  while ((runtime.deck.active || runtime.container.combatCoordinator.isInCombat()) && safety++ < 240) {
    runtime.flushTimers();
    if (!runtime.deck.active) {
      await Promise.resolve();
      continue;
    }
    if ((Number(runtime.deck.turn) || 0) !== observedTurn) {
      observedTurn = Number(runtime.deck.turn) || 0;
      playsThisTurn = 0;
    }
    if (strategy) {
      applyPolicyInput(runtime, strategy.policyId, strategy.decisions);
      runtime.flushTimers();
      await Promise.resolve();
      continue;
    }
    if (runtime.deck.phase === 'REACTION_OPEN') {
      const option = chooseReaction(runtime.deck, pathId, random);
      if (!option) throw new Error('reaction_window_has_no_available_option');
      const result = runtime.deck.chooseReaction(option.id, runtime.deck.pendingReaction?.windowId);
      if (!result || result.resolved !== true) throw new Error(`reaction_rejected:${option.id}`);
      runtime.flushTimers();
      await Promise.resolve();
      continue;
    }
    const options = runtime.deck.hand
      .map((cardId, index) => cardValue(runtime.deck, cardId, index))
      .filter(Boolean)
      .sort((left, right) => right.score - left.score || left.index - right.index);
    const shouldHold = playsThisTurn > 0 && random() < 0.12;
    const selected = options.length && random() < 0.25
      ? options[Math.floor(random() * options.length)]
      : options[0];
    if (!shouldHold && selected && runtime.deck.playCard(selected.index)) {
      playsThisTurn += 1;
      runtime.flushTimers();
      await Promise.resolve();
      continue;
    }
    const reaction = runtime.deck.endTurn();
    if (reaction?.opened !== true && runtime.deck.active) throw new Error('end_turn_did_not_open_reaction');
    await Promise.resolve();
  }
  if (safety >= 240) throw new Error('combat_softlock');
}

function settleVendor(runtime) {
  const session = runtime.shop.getActiveSessionSummary();
  if (!session) return false;
  const offers = runtime.shop.getActiveOffers();
  const affordable = offers
    .filter(offer => Number(offer.price || 0) <= Number(runtime.state.resources?.spiritStone || 0))
    .sort((left, right) => Number(left.price || 0) - Number(right.price || 0));
  if (affordable[0]) runtime.shop.purchase(affordable[0].id);
  const summary = runtime.shop.close();
  runtime.eventBus.emit('shop:closed', summary);
  return true;
}

function buildMetrics(runtime, observations, completedDecisions, failure = null) {
  const events = runtime.metrics.events;
  const eventCount = name => events.filter(event => event.name === name).length;
  const combatEvents = events.filter(event => event.name === 'encounter:presented');
  const scheduledCombatEvents = events.filter(event => event.name === 'encounter:scheduled');
  const effectiveCombatDecision = event => {
    const matchingSchedule = scheduledCombatEvents
      .filter(candidate => candidate.life === event.life
        && candidate.payload?.encounterId === event.payload?.encounterId
        && candidate.decision <= event.decision)
      .at(-1);
    const scheduledDecision = Number(matchingSchedule?.payload?.scheduledDecision);
    return Number.isFinite(scheduledDecision)
      ? scheduledDecision
      : Math.max(1, (Number(event.payload?.decision) || Number(event.turn) || Number(event.decision) || 0) + 1);
  };
  const resolvedCombats = events.filter(event => ['combat:victory', 'combat:defeat', 'combat:fled'].includes(event.name));
  const roles = { ordinary: { wins: 0, losses: 0, total: 0 }, elite: { wins: 0, losses: 0, total: 0 }, boss: { wins: 0, losses: 0, total: 0 } };
  for (const event of resolvedCombats) {
    const kind = event.payload?.originalCard?.encounterRole || event.payload?.encounterContext?.encounterRole
      || event.payload?.originalCard?.encounterKind || 'ordinary';
    const role = kind === 'realm_boss' || kind === 'boss' ? 'boss' : (kind === 'elite' ? 'elite' : 'ordinary');
    roles[role].total += 1;
    if (event.name === 'combat:victory') roles[role].wins += 1;
    else roles[role].losses += 1;
  }
  const combatTurns = combatEvents.map(event => event.turn);
  const promises = events.filter(event => event.name === 'narrative:promiseCreated');
  const resolvedPromises = events.filter(event => event.name === 'narrative:promiseResolved');
  const promiseLatency = resolvedPromises.map(resolved => {
    const record = resolved.payload?.promise;
    if (!record) return null;
    const resolvedCount = Number(record.resolvedAtChoiceCount);
    const createdCount = Number(record.createdChoiceCount);
    return Number.isFinite(resolvedCount) && Number.isFinite(createdCount)
      ? Math.max(0, resolvedCount - createdCount)
      : null;
  }).filter(Number.isFinite);
  const semanticHistory = new Map();
  let semanticRepeatViolations = 0;
  let allowedSemanticReprises = 0;
  let primaryInterruptions = 0;
  let illegalNpcAppearances = 0;
  for (const observation of observations) {
    if (observation.semanticKey) {
      const historyKey = `${observation.life}:${observation.semanticKey}`;
      const previous = semanticHistory.get(historyKey);
      if (previous) {
        const policy = observation.repeatPolicy || {};
        const turnGap = Number(observation.turn) - Number(previous.turn);
        if (policy.mode === 'cooldown' && turnGap >= Number(policy.cooldownTurns || 0)) {
          allowedSemanticReprises += 1;
        } else {
          semanticRepeatViolations += 1;
        }
      }
      semanticHistory.set(historyKey, observation);
    }
    if (observation.lane === 'primary' && observation.focusBefore
      && observation.threadKey && observation.threadKey !== observation.focusBefore) {
      // A promised consequence is the response to an earlier primary choice,
      // not an unrelated primary thread stealing focus.
      if (!observation.threadKey.startsWith('promise:')) primaryInterruptions += 1;
    }
    illegalNpcAppearances += observation.illegalNpcIds.length;
  }
  const cadenceByLife = new Map();
  const cadenceByRealmVisit = new Map();
  for (const event of combatEvents) {
    const life = Number(event.life) || 0;
    const realm = event.payload?.realm || 'unknown';
    const effectiveDecision = effectiveCombatDecision(event);
    if (!cadenceByLife.has(life)) cadenceByLife.set(life, []);
    cadenceByLife.get(life).push(effectiveDecision);
    const visitKey = `${life}:${realm}`;
    if (!cadenceByRealmVisit.has(visitKey)) cadenceByRealmVisit.set(visitKey, []);
    cadenceByRealmVisit.get(visitKey).push(effectiveDecision);
  }
  const cadenceGaps = [];
  for (const decisions of cadenceByRealmVisit.values()) {
    for (let index = 1; index < decisions.length; index += 1) {
      cadenceGaps.push(decisions[index] - decisions[index - 1]);
    }
  }
  const pendingPromises = runtime.ledger?.getPendingPromises?.() || [];
  const currentChoiceCount = Array.isArray(runtime.state?.choiceHistory)
    ? runtime.state.choiceHistory.length
    : completedDecisions;
  const overduePromises = pendingPromises.filter(promise => {
    const createdChoiceCount = Number(promise?.createdChoiceCount);
    const dueWithinDecisions = Number(promise?.dueWithinDecisions);
    return Number.isFinite(createdChoiceCount)
      && Number.isFinite(dueWithinDecisions)
      && currentChoiceCount - createdChoiceCount > dueWithinDecisions;
  });
  return {
    semanticRepeats: semanticRepeatViolations,
    semanticRepeatViolations,
    allowedSemanticReprises,
    semanticRepeatsPrevented: eventCount('narrative:semanticRepeatPrevented'),
    promiseLatency,
    primaryInterruptions,
    combatCadence: {
      presentedTurns: combatTurns,
      presentedDecisions: combatEvents.map(effectiveCombatDecision),
      firstByLife: [...cadenceByLife.entries()].map(([life, decisions]) => ({ life, decision: decisions[0] })),
      gaps: cadenceGaps
    },
    illegalNpcAppearances,
    vendorSessions: {
      opened: eventCount('shop:open'),
      closed: eventCount('shop:closed')
    },
    promises: {
      created: promises.length,
      resolved: resolvedPromises.length,
      expired: eventCount('narrative:promiseExpired'),
      pending: pendingPromises.length,
      overdue: overduePromises.length
    },
    softlocks: failure && /softlock|no_card|no_choice/.test(failure) ? 1 : 0,
    deaths: eventCount('state:death'),
    combat: {
      presented: combatEvents.length,
      resolved: resolvedCombats.length,
      reactionsOpened: eventCount('combat:reactionOpened'),
      reactionsResolved: eventCount('combat:reactionResolved'),
      roles
    },
    authorityBypasses: Number(runtime.metrics.authorityBypasses) || 0,
    choiceRejects: Number(runtime.metrics.choiceRejects) || 0,
    completedDecisions,
    witnessCount: observations.length
  };
}

async function runSingle({ pathId = 'sword', seed = 1, decisions = 100, witness = false, verbose = false,
  decisionUnit = 'inputs', policyId = null } = {}) {
  if (!['inputs','committed'].includes(decisionUnit)) throw new Error('Unknown decision unit: '+decisionUnit);
  if (policyId !== null && !POLICY_IDS.includes(policyId)) throw new Error('Unknown policy: ' + policyId);
  const strategy = policyId === null ? null : { policyId, scope: 'combat decisions; shared narrative policy', decisions: [] };
  const runtime = createProductionRuntime({ pathId, seed, verbose });
  const authorityRecorder = createAuthorityRecorder(runtime);
  const policyLedger = strategy ? createPolicyInputLedger(runtime) : null;
  const random = createPrng(seed ^ 0xB12B12);
  const rows = [];
  const observations = [];
  let completedDecisions = 0;
  let failure = null;
  let failureDetails = null;
  let safety = 0;
  let measuredProgress = null;
  const progress = () => {
    if (decisionUnit === 'inputs') return completedDecisions;
    measuredProgress = authorityRecorder.summarize();
    return measuredProgress.completedDecisions;
  };
  while (progress() < decisions && safety++ < decisions * 80 + 500) {
    try {
      if (measuredProgress && measuredProgress.status !== 'TRUSTED') throw new Error('authority_telemetry_unproven');
      if (runtime.shop.getActiveSessionSummary()) {
        settleVendor(runtime);
        await Promise.resolve();
        continue;
      }
      if (runtime.deck.active || runtime.container.combatCoordinator.isInCombat()) {
        await settleCombat(runtime, pathId, random, strategy);
        authorityRecorder.checkpoint();
        continue;
      }
      const specialCard = runtime.game.getCurrentCard();
      if (specialCard?.type === 'DESTINY_WHEEL') {
        const direction = ['left', 'right', 'up', 'down'][Math.floor(random() * 4)];
        runtime.metrics.currentDecision = completedDecisions + 1;
        const observation = observeDecision(runtime, specialCard, completedDecisions + 1);
        observations.push(observation);
        const accepted = runtime.game.makeChoice(direction);
        authorityRecorder.checkpoint();
        if (accepted !== true) {
          runtime.metrics.choiceRejects += 1;
          throw new Error(`choice_rejected:DESTINY_WHEEL:${direction}`);
        }
        completedDecisions += 1;
        if (witness) {
          rows.push({
            ...observation,
            decision: completedDecisions,
            turnBefore: Number(runtime.state.turn) || 0,
            turnAfter: Number(runtime.state.turn) || 0,
            realm: runtime.state.realm,
            path: runtime.state.path,
            cardId: 'DESTINY_WHEEL',
            semanticKey: null,
            direction,
            flowSource: 'system:destiny_wheel',
            location: runtime.state.currentLocation || null
          });
        }
        await Promise.resolve();
        continue;
      }
      const { card, selected } = pickNarrativeChoice(runtime, random);
      if (!card) throw new Error('no_card_softlock');
      if (!selected) throw new Error(`no_choice_softlock:${card.id}`);
      const turnBefore = Number(runtime.state.turn) || 0;
      runtime.metrics.currentDecision = completedDecisions + 1;
      const observation = observeDecision(runtime, card, completedDecisions + 1);
      observations.push(observation);
      const accepted = runtime.game.makeChoice(selected.direction);
      authorityRecorder.checkpoint();
      if (accepted !== true) {
        runtime.metrics.choiceRejects += 1;
        throw new Error(`choice_rejected:${card.id}:${selected.direction}`);
      }
      completedDecisions += 1;
      if (witness) {
        rows.push({
          ...observation,
          decision: completedDecisions,
          turnBefore,
          turnAfter: Number(runtime.state.turn) || 0,
          realm: runtime.state.realm,
          path: runtime.state.path,
          cardId: card.id,
          semanticKey: card.semanticKey || null,
          direction: selected.direction,
          flowSource: card._flowSource || null,
          location: runtime.state.currentLocation || null
        });
      }
      await Promise.resolve();
    } catch (error) {
      failure = error && error.message ? error.message : String(error);
      const current = runtime.game.getCurrentCard();
      failureDetails = {
        currentCard: current ? clone(current) : null,
        lastChoiceRejection: clone(runtime.game._lastChoiceRejection),
        pendingChoiceSettlement: clone(runtime.game._pendingChoiceSettlement)
      };
      break;
    }
  }
  if (!failure && progress() < decisions) failure = 'decision_loop_softlock';
  if (!failure) {
    // A choice can open a modal subsystem on the exact final decision. Drain
    // that same settlement before taking metrics so an arbitrary report
    // boundary cannot manufacture an unclosed vendor/combat session.
    let drainSafety = 0;
    try {
      while (drainSafety++ < 300) {
        if (runtime.shop.getActiveSessionSummary()) {
          settleVendor(runtime);
          await Promise.resolve();
          continue;
        }
        if (runtime.deck.active || runtime.container.combatCoordinator.isInCombat()) {
          await settleCombat(runtime, pathId, random, strategy);
          continue;
        }
        break;
      }
      if (drainSafety >= 300) failure = 'final_settlement_softlock';
    } catch (error) {
      failure = `final_settlement_failed:${error && error.message ? error.message : String(error)}`;
    }
  }
  const authorityTrace = authorityRecorder.exportTrace();
  if (policyLedger) { strategy.inputLedger = policyLedger.export(); policyLedger.dispose(); }
  authorityRecorder.dispose();
  const authorityMetrics = summarizeAuthorityTrace(authorityTrace);
  if (strategy && !joinPolicyVictories(strategy, authorityMetrics)) failure ||= 'policy_victory_receipt_unproven';
  const completedHorizon = decisionUnit === 'committed' ? authorityMetrics.completedDecisions : completedDecisions;
  if (decisionUnit === 'committed') {
    if (authorityMetrics.status !== 'TRUSTED') failure ||= 'authority_telemetry_unproven';
    if (completedHorizon !== decisions) failure ||= 'committed_horizon_mismatch';
  }
  return {
    // Existing B12 counters remain legacy input-loop measurements. B3 must
    // consume this independently recomputable committed-state trace instead.
    authority: { trace: authorityTrace, metrics: authorityMetrics },
    ...(strategy ? { strategy } : {}),
    decisionUnit,
    acceptedInputs: completedDecisions,
    pathId,
    seed,
    requestedDecisions: decisions,
    completedDecisions: completedHorizon,
    failure,
    failureDetails,
    finalState: {
      turn: runtime.state.turn,
      realm: runtime.state.realm,
      dead: Boolean(runtime.state.dead),
      health: runtime.state.attributes?.health,
      maxHealth: runtime.state.getActualMaxHealth?.() || runtime.state.maxHealth,
      daoHeart: runtime.state.attributes?.daoHeart,
      lifespan: runtime.state.resources?.lifespan,
      spiritStone: runtime.state.resources?.spiritStone
    },
    witness: rows,
    events: witness ? clone(runtime.metrics.events) : [],
    metrics: buildMetrics(runtime, observations, completedHorizon, failure)
  };
}

function aggregateRuns(runs) {
  const aggregate = {
    paths: {},
    failedSeeds: [],
    totalRuns: runs.length,
    policy: {
      cardJudgmentErrorRate: 0.25,
      earlyEndTurnRate: 0.12,
      reactionMissRate: 0.5
    }
  };
  for (const result of runs) {
    if (!aggregate.paths[result.pathId]) {
      aggregate.paths[result.pathId] = {
        runs: 0,
        completedDecisions: 0,
        combatPresented: 0,
        combatResolved: 0,
        semanticRepeats: 0,
        allowedSemanticReprises: 0,
        softlocks: 0,
        deaths: 0,
        choiceRejects: 0,
        authorityBypasses: 0,
        primaryInterruptions: 0,
        illegalNpcAppearances: 0,
        vendorOpened: 0,
        vendorClosed: 0,
        promisesCreated: 0,
        promisesResolved: 0,
        promisesExpired: 0,
        promisesPending: 0,
        promisesOverdue: 0,
        promiseLatency: [],
        firstCombatDecisions: [],
        combatCadenceGaps: [],
        reactionsOpened: 0,
        reactionsResolved: 0,
        roles: {
          ordinary: { wins: 0, losses: 0, total: 0 },
          elite: { wins: 0, losses: 0, total: 0 },
          boss: { wins: 0, losses: 0, total: 0 }
        }
      };
    }
    const row = aggregate.paths[result.pathId];
    row.runs += 1;
    row.completedDecisions += result.completedDecisions;
    row.combatPresented += result.metrics.combat.presented;
    row.combatResolved += result.metrics.combat.resolved;
    row.semanticRepeats += result.metrics.semanticRepeats;
    row.allowedSemanticReprises += result.metrics.allowedSemanticReprises;
    row.softlocks += result.metrics.softlocks;
    row.deaths += result.metrics.deaths;
    row.choiceRejects += result.metrics.choiceRejects;
    row.authorityBypasses += result.metrics.authorityBypasses;
    row.primaryInterruptions += result.metrics.primaryInterruptions;
    row.illegalNpcAppearances += result.metrics.illegalNpcAppearances;
    row.vendorOpened += result.metrics.vendorSessions.opened;
    row.vendorClosed += result.metrics.vendorSessions.closed;
    row.promisesCreated += result.metrics.promises.created;
    row.promisesResolved += result.metrics.promises.resolved;
    row.promisesExpired += result.metrics.promises.expired;
    row.promisesPending += result.metrics.promises.pending;
    row.promisesOverdue += result.metrics.promises.overdue;
    row.promiseLatency.push(...result.metrics.promiseLatency);
    // GDD 11.3 specifies the first encounter of a new save, not the first
    // encounter after every reincarnation (which intentionally has epilogue
    // and path-selection work before normal scheduling resumes).
    row.firstCombatDecisions.push(...result.metrics.combatCadence.firstByLife
      .filter(item => item.life === 0)
      .map(item => item.decision));
    row.combatCadenceGaps.push(...result.metrics.combatCadence.gaps);
    row.reactionsOpened += result.metrics.combat.reactionsOpened;
    row.reactionsResolved += result.metrics.combat.reactionsResolved;
    for (const role of ['ordinary', 'elite', 'boss']) {
      row.roles[role].wins += result.metrics.combat.roles[role].wins;
      row.roles[role].losses += result.metrics.combat.roles[role].losses;
      row.roles[role].total += result.metrics.combat.roles[role].total;
    }
    if (result.failure) aggregate.failedSeeds.push({ pathId: result.pathId, seed: result.seed, failure: result.failure });
  }
  for (const row of Object.values(aggregate.paths)) {
    for (const role of ['ordinary', 'elite', 'boss']) {
      row.roles[role].winRate = row.roles[role].total
        ? row.roles[role].wins / row.roles[role].total
        : null;
    }
    const allRoles = Object.values(row.roles);
    const totalBattles = allRoles.reduce((sum, role) => sum + role.total, 0);
    const totalWins = allRoles.reduce((sum, role) => sum + role.wins, 0);
    row.combatWinRate = totalBattles ? totalWins / totalBattles : null;
    row.reactionResolutionRate = row.reactionsOpened
      ? row.reactionsResolved / row.reactionsOpened
      : 1;
  }
  return aggregate;
}

function getProductionThreadModuleNames() {
  return [...THREAD_MODULES];
}

async function runCli() {
  const arg = name => {
    const prefix = `--${name}=`;
    const found = process.argv.slice(2).find(value => value.startsWith(prefix));
    return found ? found.slice(prefix.length) : null;
  };
  const decisions = Math.max(1, Number(arg('decisions')) || 100);
  const seeds = Math.max(1, Number(arg('seeds')) || 1);
  const seedStart = Math.max(1, Number(arg('seed-start')) || 12000);
  const requestedPaths = (arg('paths') || PATHS.join(','))
    .split(',').map(value => value.trim()).filter(value => PATHS.includes(value));
  if (requestedPaths.length === 0) throw new Error('No valid --paths were supplied');
  const output = arg('output');
  const decisionUnit = arg('decision-unit') || 'inputs';
  const runs = [];
  for (const pathId of requestedPaths) {
    for (let index = 0; index < seeds; index += 1) {
      runs.push(await runSingle({ pathId, seed: seedStart + index, decisions, decisionUnit, witness: Boolean(output) }));
    }
  }
  const report = { generatedAt: new Date().toISOString(), decisionUnit, decisions, seedsPerPath: seeds, seedStart, paths: requestedPaths, runs, aggregate: aggregateRuns(runs) };
  if (output) {
    const target = path.resolve(ROOT, output);
    fs.mkdirSync(path.dirname(target), { recursive: true });
    fs.writeFileSync(target, `${JSON.stringify(report, null, 2)}\n`, 'utf8');
  }
  console.log(JSON.stringify(report.aggregate, null, 2));
  if (report.aggregate.failedSeeds.length) process.exitCode = 1;
}

module.exports = {
  PATHS,
  createProductionRuntime,
  settleCombat,
  joinPolicyVictories,
  runSingle,
  aggregateRuns,
  getProductionThreadModuleNames
};

if (require.main === module) {
  runCli().catch(error => {
    console.error(error && error.stack ? error.stack : error);
    process.exitCode = 1;
  });
}
