'use strict';

// Production source oracle: public narrative choices and real combat inputs.
// The same fresh-player prefix reaches all four cadence branches; neither a
// result nor a card/turn/health/deck value is injected into the production run.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { createProductionRuntime, settleCombat } = require('./run_gdd_b12_long_runs');
const { flush } = require('./capture_noncombat_mountain_source');
const { snapshot: priorSnapshot, sourcePins: priorSourcePins } = require('./capture_noncombat_whitefox_battle_source');
const root = path.resolve(__dirname, '..');
const SEED = 123;
const PATH_ID = 'sword';
const ENCOUNTER_ID = 'enc_patrol_qi_mountain_shadow';
const SOURCE_ID = 'encounter_card_' + ENCOUNTER_ID;
const clone = value => value == null ? value : JSON.parse(JSON.stringify(value));
const pick = (value, keys) => Object.fromEntries(keys.filter(key => value?.[key] !== undefined)
  .map(key => [key, clone(value[key])]));

function snapshot(runtime) {
  return { ...priorSnapshot(runtime), director: clone(runtime.encounter.exportState()) };
}

function battleSnapshot(runtime) {
  return pick(runtime.deck.exportState(), ['originalCard', 'resolutionContext', 'encounterContext',
    'phase', 'turn', 'player', 'enemy', 'qi', 'maxQi', 'masterDeck', 'hand', 'drawPile',
    'discardPile', 'exhaustPile', 'playerStatus', 'enemyStatus', 'enemyIntent',
    'pendingReaction', 'preCombatHealth']);
}

async function choose(runtime, direction, trace) {
  const card = runtime.game.getCurrentCard();
  trace.push({ cardId: card.id, cardType: card.type, direction, turn: runtime.state.turn });
  assert.equal(runtime.game.makeChoice(direction), true, `${card.id}.${direction}`);
  await flush(runtime);
}

function recordEvents(runtime) {
  const events = [];
  const listeners = [];
  for (const name of ['encounter:scheduled', 'encounter:presented', 'encounter:accepted',
    'encounter:avoided', 'encounter:resolved', 'combat:sourceResolved', 'combat:victorySettled',
    'combat:defeatSettled', 'combat:pathSynergyResolved', 'state:burnBlood',
    'state:decisionCommitted', 'karma:seedPlanted']) {
    const listener = payload => events.push({ name, turn: runtime.state.turn, payload: pick(payload,
      ['encounterId', 'cardId', 'encounterKind', 'role', 'direction', 'reason', 'scheduledDecision',
        'narrativeSource', 'outcome', 'nextInterval', 'defeatHealthLoss', 'baseRewards',
        'encounterContext', 'token', 'decisionIndex', 'sourceCardId', 'kind', 'lifeId',
        'maxHealth', 'maxDaoHeart', 'health', 'daoHeart', 'pathId', 'activations', 'seed']) });
    runtime.eventBus.on(name, listener);
    listeners.push([name, listener]);
  }
  return { events, close() {
    for (const [name, listener] of listeners) runtime.eventBus.off(name, listener);
  } };
}

async function enterBattle(runtime, sourceDirection = 'left') {
  const sourceCard = clone(runtime.game.getCurrentCard());
  const beforeWarning = snapshot(runtime);
  const choicePreviews = clone(runtime.game.previewCardChoices(sourceCard));
  const recorder = recordEvents(runtime);
  const entryInputs = [];
  await choose(runtime, sourceDirection, entryInputs);
  const warning = clone(runtime.game.getCurrentCard());
  const pendingResolution = clone(runtime.container.combatCoordinator.getPendingResolution());
  const afterChoice = snapshot(runtime);
  const warningChoicePreviews = clone(runtime.game.previewCardChoices(warning));
  assert.equal(warning.id, '_warning_' + sourceCard.id);
  assert.equal(runtime.state.turn, beforeWarning.turn, 'offer acceptance defers its decision');
  assert.equal(pendingResolution.sourceCard.id, sourceCard.id);
  assert.equal(pendingResolution.direction, sourceDirection);
  await choose(runtime, 'left', entryInputs);
  assert.equal(runtime.deck.active, true);
  assert.equal(runtime.state.turn, beforeWarning.turn, 'warning confirmation has no decision tick');
  const battle = battleSnapshot(runtime);
  assert.deepEqual(battle.masterDeck, clone(runtime.state.deck));
  const afterWarning = snapshot(runtime);
  recorder.close();
  return { path: PATH_ID, sourceCard, sourceDirection, choicePreviews, beforeWarning,
    afterChoice, warning, warningChoicePreviews, pendingResolution, afterWarning,
    battle, entryInputs, entryEvents: recorder.events };
}

async function resolveBattle(runtime, context, outcome, policy = 'defense') {
  const before = snapshot(runtime);
  const recorder = recordEvents(runtime);
  const combatInputs = [];
  const originals = {};
  // Transparent recording of actual browser combat inputs, including the
  // strategy chosen by the existing production-runtime settlement helper.
  for (const method of ['playCard', 'endTurn', 'chooseReaction', 'flee']) {
    originals[method] = runtime.deck[method];
    runtime.deck[method] = function (...args) {
      const input = { method, args: clone(args), turn: this.turn, phase: this.phase };
      if (method === 'playCard') input.cardId = this.hand[args[0]];
      combatInputs.push(input);
      const result = originals[method].apply(this, args);
      input.result = clone(result) ?? null;
      return result;
    };
  }
  try {
    if (outcome === 'victory') await settleCombat(runtime, PATH_ID, () => 0.5,
      policy === 'baseline' ? null : { policyId: policy, decisions: [] });
    else if (outcome === 'flee') runtime.deck.flee();
    else {
      assert.equal(outcome, 'defeat');
      // Passing with no cards makes this plan enter RECOVER. Wait for the
      // actually acquired eighth card, play it once, then take the PROBE hit.
      const acquired = context.battle.masterDeck.at(-1);
      assert.equal(acquired, 'draw_sword');
      let acquiredPlayed = false;
      for (let i = 0; runtime.deck.active && i < 60; i++) {
        if (runtime.deck.pendingReaction) {
          assert.equal(runtime.deck.chooseReaction('TAKE_HIT', runtime.deck.pendingReaction.windowId)?.resolved, true);
        } else {
          const index = runtime.deck.hand.indexOf(acquired);
          if (!acquiredPlayed && index >= 0) {
            assert.equal(runtime.deck.playCard(index), true);
            acquiredPlayed = true;
            await flush(runtime);
          }
          assert.equal(runtime.deck.endTurn()?.opened, true);
        }
        await flush(runtime);
      }
      assert.equal(acquiredPlayed, true, 'the acquired eighth card was played through the public API');
    }
    await flush(runtime);
  } finally {
    for (const method of Object.keys(originals)) runtime.deck[method] = originals[method];
  }
  assert.equal(runtime.deck.active, false);
  const sourceEvent = recorder.events.find(event => event.name === 'combat:sourceResolved');
  assert.equal(sourceEvent?.payload.outcome, outcome, 'the requested outcome occurred in real combat');
  const resultCard = clone(runtime.game.getCurrentCard());
  const after = snapshot(runtime);
  assert.equal(after.turn, before.turn + 1);
  assert.equal(after.choiceHistory.at(-1).cardId, context.sourceCard.id);
  assert.equal(after.choiceHistory.at(-1).cardType, context.sourceCard.type);
  assert.equal(after.choiceHistory.at(-1).turn, before.turn);
  assert.equal(after.choiceHistory.at(-1).decisionIndex, after.turn);
  assert.equal(recorder.events.filter(event => event.name === 'state:decisionCommitted').length, 1);
  const terminalEvents = clone(recorder.events);
  const acknowledgementDirection = outcome === 'victory' ? 'left' : 'down';
  const acknowledgementInputs = [];
  await choose(runtime, acknowledgementDirection, acknowledgementInputs);
  const nextCard = clone(runtime.game.getCurrentCard());
  const afterAcknowledgement = snapshot(runtime);
  assert.equal(afterAcknowledgement.turn, after.turn + 1);
  recorder.close();
  return { ...clone(context), outcome, policy: outcome === 'defeat' ? 'wait_for_eighth_card_then_take_hit'
    : outcome === 'flee' ? 'public_flee' : policy, realCombat: true, publicInput: true,
    encounterInstanceId: context.battle.encounterContext.encounterInstanceId,
    before, after, resultCard, combatInputs, events: terminalEvents,
    acknowledgementDirection, acknowledgementInputs,
    acknowledgementEvents: recorder.events.slice(terminalEvents.length),
    afterAcknowledgement, nextCard };
}

async function openCadence() {
  const runtime = createProductionRuntime({ pathId: PATH_ID, seed: SEED });
  // The same fresh-player setting used by the teaching/mountain source oracles.
  runtime.state.unlocks.tutorialCompleted = false;
  runtime.game.start(PATH_ID);
  const route = [];
  for (const [id, direction] of [['tutorial_1', 'right'], ['tutorial_4', 'right'],
    ['q_start_sword', 'left']]) {
    assert.equal(runtime.game.getCurrentCard().id, id);
    await choose(runtime, direction, route);
  }
  const teachingContext = await enterBattle(runtime);
  assert.equal(teachingContext.sourceCard.id, 'encounter_card_enc_trial_sword_swift');
  assert.equal(teachingContext.battle.masterDeck.length, 6);
  const teaching = await resolveBattle(runtime, teachingContext, 'victory', 'baseline');
  teaching.caseId = 'sword_teaching_victory';
  assert.equal(teaching.afterAcknowledgement.deck.length, 7);
  for (let i = 0; runtime.game.getCurrentCard().id !== 'q_mountain_shadow_approach' && i < 8; i++) {
    await choose(runtime, 'left', route);
  }
  assert.equal(runtime.game.getCurrentCard().id, 'q_mountain_shadow_approach');
  const mountainContext = await enterBattle(runtime);
  assert.equal(mountainContext.battle.masterDeck.length, 7);
  const mountain = await resolveBattle(runtime, mountainContext, 'victory');
  mountain.caseId = 'sword_story_mountain_victory';
  assert.deepEqual(mountain.after.director, mountain.beforeWarning.director,
    'STORY mountain does not consume the catalog cadence');
  assert.equal(mountain.afterAcknowledgement.deck.length, 8);
  for (const id of ['ch_qi_40', 'ch_qi_60', 'ch_qi_80']) {
    assert.equal(runtime.game.getCurrentCard().id, id);
    await choose(runtime, 'left', route);
  }
  const beforeOffer = snapshot(runtime);
  const recorder = recordEvents(runtime);
  const sourceCard = clone(runtime.game.getCurrentCard());
  recorder.close();
  assert.equal(sourceCard.id, SOURCE_ID);
  assert.equal(sourceCard._flowSource, 'encounter:cadence');
  assert.equal(runtime.state.turn, 11);
  assert.equal(sourceCard.type, 'COMBAT');
  const offered = snapshot(runtime);
  assert.equal(offered.director.pending.scheduledDecision, 12);
  assert.deepEqual(offered.director.realmProgress.qi.resolvedIds, ['enc_trial_sword_swift']);
  assert.equal(offered.director.realmProgress.qi.seenCounts.ordinary, 2);
  const setup = { path: PATH_ID, route, battles: [teaching, mountain] };
  const context = { path: PATH_ID, seed: SEED, beforeOffer, offered, sourceCard,
    choicePreviews: clone(runtime.game.previewCardChoices(sourceCard)), offerEvents: recorder.events,
    directorBefore: clone(offered.director), priorBattleCaseIds: setup.battles.map(row => row.caseId),
    rawDeckHistory: setup.battles.map(row => ({ sourceCardId: row.sourceCard.id,
      encounterInstanceId: row.encounterInstanceId, deck: row.battle.masterDeck }))
      .concat([{ sourceCardId: SOURCE_ID, deck: clone(runtime.state.deck) }]) };
  return { runtime, setup, context };
}

function assertCadenceSettlement(before, after, avoided) {
  const prior = before.director;
  const next = after.director;
  const priorProgress = prior.realmProgress.qi;
  const progress = next.realmProgress.qi;
  assert.equal(next.pending, null);
  assert.equal(next.firstTeachingStatus, 'resolved');
  assert.deepEqual(progress.presentedIds, priorProgress.presentedIds);
  assert.deepEqual(progress.seenCounts, priorProgress.seenCounts);
  assert.deepEqual(progress.resolvedIds, avoided ? priorProgress.resolvedIds
    : [...priorProgress.resolvedIds, ENCOUNTER_ID]);
  assert.deepEqual(progress.avoidedIds, avoided ? [...priorProgress.avoidedIds, ENCOUNTER_ID]
    : priorProgress.avoidedIds);
  assert.equal(progress.counts.ordinary, priorProgress.counts.ordinary + (avoided ? 0 : 1));
  assert.equal(next.lastResolvedDecision, avoided ? prior.lastResolvedDecision : before.turn);
  const config = JSON.parse(fs.readFileSync(path.join(root, 'data/combat/encounter_director.json'), 'utf8'));
  assert.equal(next.cooldownUntilDecision, before.turn + config.postEncounterCooldown);
  const terminal = next.history.at(-1);
  assert.equal(terminal.event, avoided ? 'avoided' : 'resolved');
  assert.equal(next.nextDueDecision, prior.pending.scheduledDecision + terminal.nextInterval);
  assert.deepEqual(next.history.slice(0, prior.history.length), prior.history);
}

async function captureAvoid(runtime, context) {
  const before = snapshot(runtime);
  const recorder = recordEvents(runtime);
  const inputs = [];
  await choose(runtime, 'right', inputs);
  const afterChoice = snapshot(runtime);
  assert.equal(runtime.deck.active, false);
  assert.equal(runtime.container.combatCoordinator.getPendingResolution(), null);
  assert.equal(afterChoice.turn, before.turn + 1);
  assert.deepEqual(afterChoice.deck, before.deck);
  assert.equal(afterChoice.resources.lifespan, before.resources.lifespan - 2,
    'authored avoidance and the ordinary COMBAT decision each cost one lifespan');
  assert.equal(afterChoice.cardsPlayed.includes(SOURCE_ID), false,
    'avoiding a once encounter must not mark it played');
  assert.equal(afterChoice.choiceHistory.at(-1).cardId, SOURCE_ID);
  assertCadenceSettlement(before, afterChoice, true);
  const nextCard = clone(runtime.game.getCurrentCard());
  const after = snapshot(runtime);
  recorder.close();
  return { ...clone(context), caseId: 'sword_avoid', outcome: 'avoided', direction: 'right',
    realCombat: false, publicInput: true, before, afterChoice, after,
    warning: null, pendingResolution: null, battle: null, resultCard: null,
    acknowledgementDirection: null, afterAcknowledgement: null,
    inputs, events: recorder.events, nextCard, directorAfter: clone(afterChoice.director) };
}

async function captureOutcome(runtime, context, outcome) {
  const entered = await enterBattle(runtime);
  assert.equal(entered.battle.masterDeck.length, 8);
  assert.deepEqual(entered.battle.masterDeck, context.offered.deck);
  const row = await resolveBattle(runtime, entered, outcome);
  assertCadenceSettlement(context.offered, row.after, false);
  assert.equal(Object.values(row.resultCard.choices).some(choice => choice.nextCard), false);
  return { ...clone(context), ...row, caseId: 'sword_' + outcome,
    directorAfter: clone(row.after.director) };
}

function sourcePins() {
  const pins = priorSourcePins();
  for (const file of ['src/core/DataLoader.js', 'src/systems/DestinyWheelSystem.js',
    'src/systems/HeavensHintSystem.js', 'src/systems/LegacyFragmentSystem.js',
    'src/systems/PathSkillSystem.js', 'src/systems/TreasureSystem.js',
    'data/config/path_skills.json', 'data/shops/treasures.json',
    'tools/capture_noncombat_cadence_source.js']) {
    pins[file] = crypto.createHash('sha256').update(fs.readFileSync(path.join(root, file))).digest('hex');
  }
  return pins;
}

async function main() {
  const pins = sourcePins();
  const rows = [];
  let setup = null;
  let offered = null;
  for (const outcome of ['avoided', 'victory', 'defeat', 'flee']) {
    const opened = await openCadence();
    if (setup) {
      assert.deepEqual(opened.setup, setup, 'all branches share the actual public prefix');
      assert.deepEqual(opened.context, offered, 'the same offered encounter owns all branches');
    } else { setup = opened.setup; offered = clone(opened.context); }
    rows.push(outcome === 'avoided' ? await captureAvoid(opened.runtime, opened.context)
      : await captureOutcome(opened.runtime, opened.context, outcome));
  }
  assert.deepEqual(sourcePins(), pins, 'source authorities changed during capture');
  fs.writeFileSync(path.join(root, 'godot/tests/fixtures/cadence_battle_source.json'),
    JSON.stringify({ schemaVersion: 1, seed: SEED, paths: [PATH_ID], realCombat: true,
      publicInput: true, entrypoint: 'index.html -> src/game.js', pins, setup, rows }, null, 2) + '\n');
  console.log('CADENCE_BATTLE_SOURCE_PASS paths=1 avoided=1 victory=1 defeat=1 flee=1 real_combat=true public_input=true deck_sizes=6,7,8 accumulated_director=true rows=' + rows.length);
}

module.exports = { snapshot, battleSnapshot, openCadence, enterBattle, resolveBattle,
  captureAvoid, captureOutcome, sourcePins };
if (require.main === module) main().catch(error => { console.error(error); process.exitCode = 1; });
