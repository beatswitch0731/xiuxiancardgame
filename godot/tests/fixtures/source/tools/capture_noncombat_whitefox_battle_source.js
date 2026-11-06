'use strict';

// Source oracle from the original production runtime. Only public narrative
// and combat inputs settle outcomes; no card, turn, health or result injection.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { createProductionRuntime, settleCombat } = require('./run_gdd_b12_long_runs');
const { flush, snapshot: baseSnapshot } = require('./capture_noncombat_mountain_source');
const root = path.resolve(__dirname, '..');
const clone = value => value == null ? value : JSON.parse(JSON.stringify(value));
const SOURCE_ID = 'q_whiteFox_3';
const QUEST_ID = 'white_fox_line';
const SEED = 123;

function snapshot(runtime) {
  const s = runtime.state;
  return { ...baseSnapshot(runtime), ...clone({
    currentCard: runtime.game.currentCard, runClock: s.runClock,
    questState: s.getQuestState(), factionProgress: s.factionProgress,
    npc: runtime.continuity.getNpcState('bai_luoxuan'),
    worldContinuityState: runtime.continuity.exportState(),
    tradeRouteState: s.tradeRouteState, storyNetworkState: s.storyNetworkState
  }) };
}

function battleSnapshot(runtime) {
  const state = runtime.deck.exportState();
  const keys = ['originalCard', 'resolutionContext', 'encounterContext', 'phase', 'turn',
    'player', 'enemy', 'qi', 'maxQi', 'masterDeck', 'hand', 'drawPile', 'discardPile',
    'exhaustPile', 'playerStatus', 'enemyStatus', 'enemyIntent', 'pendingReaction', 'preCombatHealth'];
  return Object.fromEntries(keys.filter(key => state[key] !== undefined)
    .map(key => [key, clone(state[key])]));
}

async function choose(runtime, direction, trace) {
  const card = runtime.game.getCurrentCard();
  trace.push({ cardId: card.id, cardType: card.type, direction, turn: runtime.state.turn });
  assert.equal(runtime.game.makeChoice(direction), true, `${card.id}.${direction}`);
  await flush(runtime);
}

async function openWhiteFox(pathId) {
  const runtime = createProductionRuntime({ pathId, seed: SEED });
  // Match the fresh-player tutorial input, as in the existing mountain oracle.
  runtime.state.unlocks.tutorialCompleted = false;
  runtime.game.start(pathId);
  const route = [];
  for (const id of ['tutorial_1', 'tutorial_2', 'tutorial_3', 'tutorial_4', 'q_start_' + pathId]) {
    assert.equal(runtime.game.getCurrentCard().id, id);
    await choose(runtime, 'left', route);
  }
  assert.equal(runtime.game.getCurrentCard().type, 'COMBAT');
  await choose(runtime, 'right', route);
  assert.match(runtime.game.getCurrentCard().id, /^promise_result_/);
  await choose(runtime, 'left', route);
  for (const [id, direction] of [['ch_qi_20', 'left'], ['ch_qi_40', 'right'],
    ['q_whiteFox_quest', 'right'], ['q_whiteFox_2', 'left']]) {
    assert.equal(runtime.game.getCurrentCard().id, id);
    await choose(runtime, direction, route);
  }
  return { runtime, context: await enterWhiteFox(runtime, { path: pathId, route }) };
}

async function enterWhiteFox(runtime, provenance) {
  const sourceCard = clone(runtime.game.getCurrentCard());
  assert.equal(sourceCard.id, SOURCE_ID);
  assert.equal(sourceCard.type, 'QUEST');
  assert.equal(sourceCard.choices.left.triggerCombat, true);
  assert.equal(Object.hasOwn(sourceCard.choices.left, 'combatEncounterId'), false);
  assert.equal(sourceCard.choices.left.enemy.id, 'hound_pack_qi');
  assert.equal(runtime.state.getQuestState().activeQuests[0].step, 2);
  const beforeWarning = snapshot(runtime);
  const directorBefore = clone(runtime.encounter.exportState());
  const entryInputs = [];
  await choose(runtime, 'left', entryInputs);
  const warning = clone(runtime.game.getCurrentCard());
  const pendingResolution = clone(runtime.container.combatCoordinator.getPendingResolution());
  assert.equal(warning.id, '_warning_' + SOURCE_ID);
  assert.equal(pendingResolution.combatCard.encounterId, null);
  assert.deepEqual(pendingResolution.choice, sourceCard.choices.left);
  assert.deepEqual(snapshot(runtime).questState, beforeWarning.questState);
  const afterWarning = snapshot(runtime);
  await choose(runtime, 'left', entryInputs);
  assert.equal(runtime.deck.active, true);
  assert.equal(runtime.state.turn, beforeWarning.turn, 'warning is not another decision');
  assert.deepEqual(clone(runtime.state.karmaSeeds), beforeWarning.karmaSeeds);
  const battle = battleSnapshot(runtime);
  assert.deepEqual(battle.masterDeck, clone(runtime.state.deck));
  assert.deepEqual([battle.enemy.hp, battle.enemy.atkPower, battle.enemy.defPower], [6, 1, 0]);
  return { ...clone(provenance), sourceCard, beforeWarning, afterWarning, warning,
    pendingResolution, battle, directorBefore, entryInputs };
}

function copyStorage(storage) {
  const values = new Map();
  for (let i = 0; i < storage.length; i++) {
    const key = storage.key(i);
    values.set(key, storage.getItem(key));
  }
  return { getItem: key => values.get(String(key)) ?? null,
    setItem: (key, value) => values.set(String(key), String(value)),
    removeItem: key => values.delete(String(key)), clear: () => values.clear(),
    key: index => [...values.keys()][index] ?? null, get length() { return values.size; } };
}

function canonicalResolution(value) {
  const result = clone(value);
  // FlowDirector adds these presentation annotations on quest reentry. The
  // source restore intentionally rehydrates authored cards without them.
  for (const key of ['sourceCard', 'combatCard']) {
    delete result[key]._flowPhase;
    delete result[key]._flowSource;
  }
  return result;
}

function resumeActive(runtime) {
  const before = battleSnapshot(runtime);
  assert.equal(runtime.state.persistCausalSession({ force: true }), true);
  const fresh = createProductionRuntime({ pathId: runtime.state.path, seed: SEED,
    restoreStorage: copyStorage(runtime.storage) });
  assert.equal(fresh.game.resumeSession(), true);
  assert.equal(fresh.deck.active, true);
  const after = battleSnapshot(fresh);
  assert.deepEqual(after.encounterContext, before.encounterContext);
  assert.deepEqual(canonicalResolution(after.resolutionContext), canonicalResolution(before.resolutionContext));
  for (const key of ['masterDeck', 'player', 'enemy', 'phase', 'turn', 'hand', 'drawPile',
    'discardPile', 'exhaustPile', 'pendingReaction']) assert.deepEqual(after[key], before[key], key);
  assert.deepEqual(clone(fresh.state.getQuestState()), clone(runtime.state.getQuestState()));
  return { runtime: fresh, restoration: { before, after, ownerPreserved: true,
    ignoredPresentationFields: ['_flowPhase', '_flowSource'] } };
}

async function captureOutcome(runtime, context, requestedOutcome, options = {}) {
  const before = snapshot(runtime);
  const owner = runtime.deck.encounterContext.encounterInstanceId;
  const events = [];
  const listeners = [];
  let resolved = null;
  for (const name of ['quest:completed', 'quest:failed', 'karma:seedPlanted',
    'combat:sourceResolved', 'combat:victorySettled', 'combat:defeatSettled',
    'combat:pathSynergyResolved', 'state:burnBlood', 'state:decisionCommitted']) {
    const listener = payload => {
      if (name === 'combat:sourceResolved') resolved = clone(payload);
      const keys = ['questId', 'questName', 'seed', 'outcome', 'cardId', 'direction',
        'defeatHealthLoss', 'baseRewards', 'encounterContext', 'token', 'decisionIndex',
        'sourceCardId', 'kind', 'lifeId', 'maxHealth', 'maxDaoHeart', 'health', 'daoHeart', 'pathId', 'activations'];
      events.push({ name, turn: runtime.state.turn, payload: Object.fromEntries(keys
        .filter(key => payload?.[key] !== undefined).map(key => [key, clone(payload[key])])) });
    };
    runtime.eventBus.on(name, listener);
    listeners.push([name, listener]);
  }
  // Transparent recording around the same public methods used by the browser.
  const combatInputs = [];
  const originals = {};
  for (const method of ['playCard', 'endTurn', 'chooseReaction', 'flee']) {
    originals[method] = runtime.deck[method];
    runtime.deck[method] = function (...args) {
      const input = { method, args: clone(args), turn: this.turn, phase: this.phase };
      combatInputs.push(input);
      const result = originals[method].apply(this, args);
      input.result = clone(result) ?? null;
      return result;
    };
  }
  try {
    if (requestedOutcome === 'victory') await settleCombat(runtime, context.path, () => 0.5);
    else if (requestedOutcome === 'flee') runtime.deck.flee();
    else {
      assert.equal(requestedOutcome, 'defeat');
      for (let i = 0; runtime.deck.active && i < 60; i++) {
        if (runtime.deck.pendingReaction) {
          assert.equal(runtime.deck.chooseReaction('TAKE_HIT', runtime.deck.pendingReaction.windowId)?.resolved, true);
        } else assert.equal(runtime.deck.endTurn()?.opened, true);
        await flush(runtime);
      }
    }
    await flush(runtime);
  } finally {
    for (const method of Object.keys(originals)) runtime.deck[method] = originals[method];
  }
  assert.equal(runtime.deck.active, false);
  assert.equal(resolved?.outcome, requestedOutcome, 'the requested result must occur in real combat');
  const resultCard = clone(runtime.game.getCurrentCard());
  const after = snapshot(runtime);
  const directorAfter = clone(runtime.encounter.exportState());
  assert.deepEqual(directorAfter, context.directorBefore, 'inline quest combat does not settle director cadence');
  assert.equal(after.turn, before.turn + 1);
  assert.deepEqual(after.choiceHistory.at(-1), { cardId: SOURCE_ID, cardType: 'QUEST',
    direction: 'left', turn: before.turn, decisionIndex: after.turn, tags: [] });
  assert.equal(events.filter(event => event.name === 'combat:sourceResolved').length, 1);
  assert.equal(events.filter(event => event.name === 'state:decisionCommitted').length, 1);
  assert.equal(Object.values(resultCard.choices).some(choice => choice.nextCard), false);
  const newSeeds = after.karmaSeeds.filter(seed => ['foxGratitude', 'whiteFox'].includes(seed.id));
  if (requestedOutcome === 'victory') {
    assert.equal(resultCard.id, 'combat_reward');
    assert.deepEqual(after.questState.activeQuests, []);
    assert.equal(after.questState.questOutcomes[QUEST_ID], 'completed');
    assert.equal(after.flags.whiteFoxCompleted, true);
    assert.deepEqual(newSeeds.map(seed => seed.id), ['foxGratitude', 'whiteFox']);
    for (const seed of newSeeds) {
      assert.equal(seed.originCard, SOURCE_ID);
      assert.equal(seed.originChoice, 'left');
      assert.equal(seed.originOutcome, 'victory');
      assert.equal(seed.originTurn, after.turn);
    }
  } else {
    assert.deepEqual(after.questState, before.questState);
    assert.deepEqual(newSeeds, []);
    assert.deepEqual(after.factionProgress, before.factionProgress);
    assert.equal(after.resources.lifespan, before.resources.lifespan - (requestedOutcome === 'flee' ? 1 : 0));
  }
  const acknowledgementDirection = requestedOutcome === 'victory' ? 'left' : 'down';
  const acknowledgementInputs = [];
  await choose(runtime, acknowledgementDirection, acknowledgementInputs);
  const nextCard = clone(runtime.game.getCurrentCard());
  const afterAcknowledgement = snapshot(runtime);
  for (const [name, listener] of listeners) runtime.eventBus.off(name, listener);
  assert.equal(afterAcknowledgement.turn, after.turn + 1);
  return { ...clone(context), ...clone(options), outcome: requestedOutcome,
    encounterInstanceId: owner, policy: requestedOutcome === 'victory' ? 'baseline' : requestedOutcome === 'defeat'
      ? 'end_turn_take_hit' : 'public_flee', realCombat: true, publicInput: true,
    before, after, resultCard, combatInputs, events, directorAfter, directorUnchanged: true,
    acknowledgementDirection, acknowledgementInputs, afterAcknowledgement, nextCard };
}

async function captureRetry(runtime, previousRow) {
  const retryRoute = [];
  for (let i = 0; runtime.game.getCurrentCard().id !== SOURCE_ID && i < 12; i++) {
    await choose(runtime, 'left', retryRoute);
  }
  assert.equal(runtime.game.getCurrentCard().id, SOURCE_ID);
  const context = await enterWhiteFox(runtime, { path: previousRow.path,
    route: previousRow.route, retryRoute, retryOf: previousRow.caseId,
    priorEncounterInstanceId: previousRow.encounterInstanceId });
  assert.notEqual(context.battle.encounterContext.encounterInstanceId, previousRow.encounterInstanceId);
  const restored = resumeActive(runtime);
  return captureOutcome(restored.runtime, context, 'victory', {
    caseId: previousRow.path + '_retry_after_' + previousRow.outcome,
    restored: true, restoration: restored.restoration });
}

function sourcePins() {
  const files = [
    'src/game.js', 'src/core/Container.js', 'src/core/EventBus.js', 'src/core/GameStateManager.js',
    'src/services/EffectService.js', 'src/coordinators/CombatCoordinator.js',
    ...['QuestSystem', 'KarmaSystem', 'CardSystem', 'DeckCombatSystem', 'SkillCardAcquisitionSystem',
      'EncounterDirector', 'FlowDirector', 'RealmChapterSystem', 'WorldContinuityStore', 'NpcSystem',
      'FactionSystem', 'TradeRouteSystem', 'WorldPulseSystem', 'LineageSystem', 'StoryNetworkSystem',
      'StoryThreadEngine', 'NarrativeLedger', 'ChoiceEchoEngine', 'KarmaRippleSystem',
      'PathArchetypeSystem', 'ChoiceOutcomeRouter'].map(name => `src/systems/${name}.js`),
    'data/quests/white_fox.json', 'data/cards/qi.json', 'data/cards/chapter_milestones.json',
    'data/cards/battle_cards.json', 'data/config/paths.json', 'data/config/realms.json',
    'data/config/path_archetypes.json', 'data/combat/deck_progression.json',
    'data/combat/encounters.json', 'data/combat/encounter_director.json',
    'data/combat/encounter_presentations.json', 'data/combat/path_presentations.json',
    'data/combat/action_presentations.json', 'data/combat/protagonist_visual_identity.json',
    'data/combat/visual_worlds.json', 'data/combat/carrier_scale_provenance.json',
    'data/combat/action_scale_provenance.json', 'data/npcs/core_npcs.json',
    'data/world/factions.json', 'data/world/trade_routes.json', 'data/narrative/causal_graph.json',
    'data/progression/first_session_cohesion.json', 'data/cards/karma.json',
    'tools/run_gdd_b12_long_runs.js', 'tools/capture_noncombat_mountain_source.js',
    'tools/capture_noncombat_whitefox_battle_source.js'
  ];
  return Object.fromEntries(files.map(file => [file,
    crypto.createHash('sha256').update(fs.readFileSync(path.join(root, file))).digest('hex')]));
}

async function main() {
  const pins = sourcePins();
  const rows = [];
  for (const pathId of ['sword', 'spell', 'body', 'pill']) {
    const { runtime, context } = await openWhiteFox(pathId);
    const alternate = ['sword', 'body'].includes(pathId) ? resumeActive(runtime) : null;
    rows.push(await captureOutcome(runtime, context, 'victory', { caseId: pathId + '_victory', restored: false }));
    if (alternate) {
      const outcome = pathId === 'sword' ? 'defeat' : 'flee';
      const row = await captureOutcome(alternate.runtime, context, outcome, {
        caseId: pathId + '_' + outcome, restored: true, restoration: alternate.restoration });
      rows.push(row, await captureRetry(alternate.runtime, row));
    }
  }
  assert.deepEqual(sourcePins(), pins, 'source authorities changed during capture');
  fs.writeFileSync(path.join(root, 'godot/tests/fixtures/whitefox_battle_source.json'),
    JSON.stringify({ schemaVersion: 1, seed: SEED, realCombat: true, publicInput: true,
      entrypoint: 'index.html -> src/game.js', pins, rows }, null, 2) + '\n');
  console.log('WHITEFOX_BATTLE_SOURCE_PASS paths=4 first_victory=4 defeat=1 flee=1 retry_cold_victory=2 real_combat=true public_input=true director_unchanged=true rows=' + rows.length);
}

module.exports = { snapshot, openWhiteFox, enterWhiteFox, resumeActive, captureOutcome, captureRetry, sourcePins };
if (require.main === module) main().catch(error => { console.error(error); process.exitCode = 1; });
