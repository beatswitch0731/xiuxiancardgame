'use strict';
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const { openCadence, captureAvoid, snapshot, enterBattle, resolveBattle,
  sourcePins } = require('./capture_noncombat_cadence_source');
const { flush } = require('./capture_noncombat_mountain_source');

const ROOT = path.resolve(__dirname, '..');
const OUT = path.join(ROOT, 'godot/tests/fixtures/third_cadence_source.json');
const SOURCE_ID = 'encounter_card_enc_quota_qi_outer_guard';
const PRE_ROUTE = [
  ['q_whiteFox_quest', 'right'], ['q_whiteFox_2', 'right'],
  ['q_whiteFox_3', 'down'], ['kx_path_sword_legacy', 'right'],
  ['k_chapter_sword_left', 'right'], ['DESTINY_WHEEL', 'left'],
  ['kx_ch_hoarded_manual', 'right'], ['kx_ch_sword_sect_path', 'right']
];
const POST_ROUTE = [
  ['promise_result_eee72bc7', 'left'],
  ['mentor_bai_ren_stage_INNER_DISCIPLE', 'right'],
  ['promise_result_dc8715d0', 'left'],
  ['em_heaven_gaze', 'right'],
  ['npc_encounter_bai_ren_初见', 'right'],
  ['mentor_bai_ren_stage_TRUSTED', 'left'],
  ['promise_result_c500a306', 'left']
];
const clone = value => value == null ? value : JSON.parse(JSON.stringify(value));

async function chooseRoute(runtime, route, inputs, evidence = null) {
  for (const [id, direction] of route) {
    const card = runtime.game.getCurrentCard();
    assert.equal(card?.id || card?.type, id);
    const npcBefore = id.startsWith('npc_encounter_') ? {
      card: clone(card), snapshot: snapshot(runtime),
      system: clone(runtime.game.npcSystem.captureRollbackState()) } : null;
    assert.equal(runtime.game.makeChoice(direction), true, `${id}.${direction}`);
    await flush(runtime);
    inputs.push({ cardId: id, direction, turn: runtime.state.turn - 1 });
    if (npcBefore && evidence) evidence.npcEncounter = { before: npcBefore,
      after: { snapshot: snapshot(runtime),
        system: clone(runtime.game.npcSystem.captureRollbackState()) } };
  }
}

async function openThird() {
  const { runtime, context } = await openCadence();
  const first = await captureAvoid(runtime, context);
  const inputs = [];
  await chooseRoute(runtime, PRE_ROUTE, inputs);
  assert.equal(runtime.game.getCurrentCard()?.id,
    'encounter_card_enc_quota_qi_missing_disciple');
  assert.equal(runtime.game.makeChoice('right'), true);
  await flush(runtime);
  inputs.push({ cardId: 'encounter_card_enc_quota_qi_missing_disciple',
    direction: 'right', turn: runtime.state.turn - 1 });
  const second = snapshot(runtime);
  const evidence = {};
  await chooseRoute(runtime, POST_ROUTE, inputs, evidence);
  const sourceCard = clone(runtime.game.getCurrentCard());
  assert.equal(sourceCard?.id, SOURCE_ID);
  assert.equal(sourceCard?._flowSource, 'encounter:cadence');
  const offered = snapshot(runtime);
  assert.equal(offered.director.pending?.encounterId, 'enc_quota_qi_outer_guard');
  assert.equal(offered.director.pending?.role, 'elite');
  return { runtime, first: { outcome: first.outcome, after: first.after },
    second, inputs, npcEncounter: evidence.npcEncounter, sourceCard, offered };
}

async function capture(outcome) {
  const { runtime, first, second, inputs, npcEncounter, sourceCard, offered } = await openThird();
  if (outcome === 'avoided') {
    assert.equal(runtime.game.makeChoice('right'), true);
    await flush(runtime);
    const after = snapshot(runtime);
    assert.equal(after.director.pending, null);
    assert.equal(after.choiceHistory.at(-1).cardId, SOURCE_ID);
    return { outcome, first, second, inputs, npcEncounter, sourceCard, offered,
      after, nextCard: clone(runtime.game.getCurrentCard()) };
  }
  const entered = await enterBattle(runtime);
  assert.equal(entered.sourceCard.id, SOURCE_ID);
  return { outcome, first, second, inputs, npcEncounter, sourceCard, offered,
    ...await resolveBattle(runtime, entered, outcome) };
}

async function main() {
  const rows = [];
  for (const outcome of ['avoided', 'victory', 'defeat', 'flee'])
    rows.push(await capture(outcome));
  const pins = sourcePins();
  pins['tools/capture_noncombat_third_cadence_source.js'] = crypto.createHash(
    'sha256').update(fs.readFileSync(__filename)).digest('hex');
  fs.writeFileSync(OUT, JSON.stringify({ seed: 123, path: 'sword',
    publicInput: true, sourceCardId: SOURCE_ID, preRoute: PRE_ROUTE,
    postRoute: POST_ROUTE, pins, rows }, null, 2) + '\n');
  console.log(`THIRD_CADENCE_SOURCE_PASS rows=${rows.length} bytes=${fs.statSync(OUT).size}`);
}

module.exports = { openThird, capture };
if (require.main === module)
  main().catch(error => { console.error(error.stack || error); process.exitCode = 1; });
