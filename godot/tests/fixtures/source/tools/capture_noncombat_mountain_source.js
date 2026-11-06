'use strict';

// Original production systems and public combat inputs only. The fixture is a
// source oracle, not an injected-result test of the Godot gateway.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { createProductionRuntime, settleCombat } = require('./run_gdd_b12_long_runs');
const root = path.resolve(__dirname, '..');
const clone = value => value == null ? value : JSON.parse(JSON.stringify(value));
const pick = (value, keys) => Object.fromEntries(keys.filter(key => value?.[key] !== undefined)
  .map(key => [key, clone(value[key])]));

async function flush(runtime) {
  for (let i = 0; i < 5; i++) { runtime.flushTimers(); await Promise.resolve(); }
}

function snapshot(runtime) {
  const s = runtime.state;
  return clone({ turn: s.turn, attributes: s.attributes, resources: s.resources,
    maxHealth: s.maxHealth, maxDaoHeart: s.maxDaoHeart, dead: s.dead, lifePhase: s.lifePhase,
    flags: s.flags, knowledge: s.knowledge, modifiers: s.modifiers, deck: s.deck,
    skillAcquisitions: s.skillAcquisitions, deckOperations: s.deckOperations,
    location: s.currentLocation, visitedLocations: s.visitedLocations, karmaSeeds: s.karmaSeeds,
    cardsPlayed: s.cardsPlayed, choiceHistory: s.choiceHistory,
    worldPulse: s.worldPulse, lineageRunStats: s.lineageRunStats,
    chapterProgress: s.chapterProgress, continuation: runtime.game._questNextCardId || null });
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

async function openMountain(pathId) {
  const runtime = createProductionRuntime({ pathId, seed: 123 });
  runtime.state.unlocks.tutorialCompleted = false;
  runtime.game.start(pathId);
  for (const direction of ['right', 'right', 'left', 'left', 'left']) {
    runtime.game.getCurrentCard();
    assert.equal(runtime.game.makeChoice(direction), true);
    await flush(runtime);
  }
  await settleCombat(runtime, pathId, () => 0.5);
  await flush(runtime);
  const teachingReward = clone(runtime.game.getCurrentCard());
  assert.equal(teachingReward.id, 'combat_reward');
  const seventhCardId = teachingReward.choices.left.effects.deckCard.cardId;
  assert.equal(runtime.game.makeChoice('left'), true);
  const interruptions = [];
  let card = runtime.game.getCurrentCard();
  for (let i = 0; card.id !== 'q_mountain_shadow_approach' && i < 8; i++) {
    interruptions.push({ cardId: card.id, direction: 'left' });
    assert.equal(runtime.game.makeChoice('left'), true);
    card = runtime.game.getCurrentCard();
  }
  assert.equal(card.id, 'q_mountain_shadow_approach');
  const sourceCard = clone(card);
  const beforeWarning = snapshot(runtime);
  const directorBefore = clone(runtime.encounter.exportState());
  assert.equal(runtime.game.makeChoice('left'), true);
  const warning = clone(runtime.game.getCurrentCard());
  assert.equal(warning.id, '_warning_q_mountain_shadow_approach');
  const pendingResolution = clone(runtime.container.combatCoordinator.getPendingResolution());
  assert.equal(runtime.state.turn, beforeWarning.turn, 'source choice is deferred until combat outcome');
  assert.equal(runtime.game.makeChoice('left'), true);
  await flush(runtime);
  assert.equal(runtime.deck.active, true);
  assert.equal(runtime.state.turn, beforeWarning.turn, 'warning confirmation is not a new decision');
  const battle = pick(runtime.deck.exportState(), ['originalCard', 'resolutionContext', 'encounterContext',
    'phase', 'turn', 'player', 'enemy', 'qi', 'maxQi', 'masterDeck', 'hand', 'drawPile',
    'discardPile', 'exhaustPile', 'playerStatus', 'enemyStatus', 'enemyIntent']);
  assert.deepEqual(battle.masterDeck, runtime.state.deck);
  assert.equal(battle.masterDeck.length, 7);
  assert.equal(battle.masterDeck.at(-1), seventhCardId);
  return { runtime, context: { path: pathId, seventhCardId, interruptions, sourceCard,
    beforeWarning, warning, pendingResolution, battle, directorBefore } };
}

function resumeActive(runtime) {
  assert.equal(runtime.state.persistCausalSession({ force: true }), true);
  const fresh = createProductionRuntime({ pathId: runtime.state.path, seed: 123,
    restoreStorage: copyStorage(runtime.storage) });
  assert.equal(fresh.game.resumeSession(), true);
  assert.equal(fresh.deck.active, true);
  assert.deepEqual(clone(fresh.deck.masterDeck), clone(runtime.deck.masterDeck));
  assert.deepEqual(clone(fresh.deck.resolutionContext), clone(runtime.deck.resolutionContext));
  return fresh;
}

async function captureOutcome(runtime, context, requestedOutcome, { restored = false } = {}) {
  const before = snapshot(runtime);
  const events = [];
  let resolved = null;
  for (const name of ['combat:sourceResolved', 'combat:victorySettled', 'combat:defeatSettled',
    'combat:pathSynergyResolved', 'state:burnBlood', 'state:decisionCommitted']) {
    runtime.eventBus.on(name, payload => {
      if (name === 'combat:sourceResolved') resolved = clone(payload);
      events.push({ name, turn: runtime.state.turn, payload: pick(payload,
        ['outcome', 'cardId', 'direction', 'defeatHealthLoss', 'baseRewards', 'encounterContext',
          'token', 'decisionIndex', 'sourceCardId', 'kind', 'lifeId', 'maxHealth', 'maxDaoHeart',
          'health', 'daoHeart', 'pathId', 'activations']) });
    });
  }
  const policy = requestedOutcome === 'flee' ? 'public_flee'
    : requestedOutcome === 'defeat' ? 'seventh_card_then_take_hit'
    : requestedOutcome === 'victory' && context.path === 'sword' ? 'defense' : 'baseline';
  if (requestedOutcome === 'flee') runtime.deck.flee();
  else if (requestedOutcome === 'defeat') {
    const index = runtime.deck.hand.indexOf(context.seventhCardId);
    assert.ok(index >= 0, 'the acquired seventh card is actually playable');
    assert.equal(runtime.deck.playCard(index), true);
    await flush(runtime);
    assert.equal(runtime.deck.endTurn()?.opened, true);
    assert.equal(runtime.deck.chooseReaction('TAKE_HIT', runtime.deck.pendingReaction.windowId)?.resolved, true);
  }
  else await settleCombat(runtime, context.path, () => 0.5,
    policy === 'defense' ? { policyId: 'defense', decisions: [] } : null);
  await flush(runtime);
  assert.equal(runtime.deck.active, false);
  assert.equal(resolved?.outcome, requestedOutcome, `${context.path} ${policy} actual outcome`);
  const resultCard = clone(runtime.game.getCurrentCard());
  const after = snapshot(runtime);
  const directorAfter = clone(runtime.encounter.exportState());
  assert.deepEqual(directorAfter, context.directorBefore,
    'STORY source without EncounterDirector pending must not settle scheduled cadence');
  assert.equal(after.turn, before.turn + 1);
  const history = after.choiceHistory.at(-1);
  assert.equal(history.cardId, context.sourceCard.id);
  assert.equal(history.cardType, 'STORY');
  assert.equal(history.turn, before.turn);
  assert.equal(history.decisionIndex, after.turn);
  assert.deepEqual(history.tags, context.sourceCard.tags);
  assert.equal(Object.values(resultCard.choices).some(choice => choice.nextCard), false);
  assert.equal(runtime.game.makeChoice('down'), true);
  const nextCard = clone(runtime.game.getCurrentCard());
  return { ...clone(context), outcome: requestedOutcome, policy, restored, before, after,
    resultCard, events, directorAfter, directorUnchanged: true,
    acknowledgementDirection: 'down', afterAcknowledgement: snapshot(runtime), nextCard };
}

async function main() {
  const rows = [];
  for (const pathId of ['sword', 'spell', 'body', 'pill']) {
    const { runtime, context } = await openMountain(pathId);
    // Branch from the actual persisted active battle, using the production
    // resume boundary. No attributes, deck entries or outcomes are injected.
    const alternate = ['sword', 'body'].includes(pathId) ? resumeActive(runtime) : null;
    rows.push(await captureOutcome(runtime, context, 'victory'));
    if (alternate) rows.push(await captureOutcome(alternate, context,
      pathId === 'sword' ? 'defeat' : 'flee', { restored: true }));
  }
  const pins = {};
  for (const source of ['src/game.js', 'src/coordinators/CombatCoordinator.js',
    'src/systems/CardSystem.js', 'src/systems/DeckCombatSystem.js',
    'src/systems/SkillCardAcquisitionSystem.js', 'src/systems/EncounterDirector.js',
    'src/systems/WorldPulseSystem.js', 'src/systems/LineageSystem.js',
    'data/cards/battle_cards.json', 'data/combat/deck_progression.json',
    'data/combat/encounters.json', 'data/combat/encounter_director.json',
    'data/combat/encounter_presentations.json', 'data/progression/first_session_cohesion.json']) {
    pins[source] = crypto.createHash('sha256').update(fs.readFileSync(path.join(root, source))).digest('hex');
  }
  fs.writeFileSync(path.join(root, 'godot/tests/fixtures/mountain_battle_source.json'),
    JSON.stringify({ pins, rows }, null, 2) + '\n');
  console.log('MOUNTAIN_BATTLE_SOURCE_PASS paths=4 victory=4 defeat=1 flee=1 real_combat=true seventh_card=true director_unchanged=true rows=' + rows.length);
}

module.exports = { flush, snapshot, openMountain, resumeActive, captureOutcome };
if (require.main === module) main().catch(error => { console.error(error); process.exitCode = 1; });
