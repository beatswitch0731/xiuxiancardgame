'use strict';

const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const { openCadence, captureAvoid, snapshot, sourcePins } =
  require('./capture_noncombat_cadence_source');
const { flush } = require('./capture_noncombat_mountain_source');

const ROOT = path.resolve(__dirname, '..');
const OUT = path.join(ROOT, 'godot/tests/fixtures/npc_first_source.json');
const FIRST_ROUTE = [
  ['q_whiteFox_quest', 'right'], ['q_whiteFox_2', 'right'],
  ['q_whiteFox_3', 'down'], ['kx_path_sword_legacy', 'right'],
  ['k_chapter_sword_left', 'right'], ['DESTINY_WHEEL', 'left'],
  ['kx_ch_hoarded_manual', 'right'], ['kx_ch_sword_sect_path', 'right']
];
const SECOND_ROUTE = [
  ['promise_result_eee72bc7', 'left'],
  ['mentor_bai_ren_stage_INNER_DISCIPLE', 'right'],
  ['promise_result_dc8715d0', 'left'],
  ['em_heaven_gaze', 'right']
];
const clone = value => value == null ? value : JSON.parse(JSON.stringify(value));

async function capture(direction) {
  const { runtime, context } = await openCadence();
  await captureAvoid(runtime, context);
  const npc = runtime.game.npcSystem;
  const story = runtime.game.getCurrentCard.constructor('return storyNetworkSystem')();
  const mentorProgression = () => story.exportState().mentorArcs.arcStates.bai_ren?.progression || 0;
  assert.ok(npc && typeof npc._checkEncounter === 'function');
  const realmMath = runtime.game.getCurrentCard.constructor('return Math')();
  const originalRandom = realmMath.random;
  const originalCheck = npc._checkEncounter;
  const rolls = [];
  let checking = false;
  realmMath.random = function () {
    const value = originalRandom();
    if (checking) rolls.push({ turn: runtime.state.turn, value });
    return value;
  };
  npc._checkEncounter = function (...args) {
    checking = true;
    try { return originalCheck.apply(this, args); }
    finally { checking = false; }
  };
  const inputs = [];
  try {
    for (const [id, chosen] of FIRST_ROUTE) {
      const card = runtime.game.getCurrentCard();
      assert.equal(card?.id || card?.type, id);
      assert.equal(runtime.game.makeChoice(chosen), true, `${id}.${chosen}`);
      await flush(runtime);
      inputs.push({ cardId: id, direction: chosen, turn: runtime.state.turn - 1,
        mentorProgression: mentorProgression(),
        cultivation: runtime.state.attributes.cultivation });
    }
    assert.equal(runtime.game.getCurrentCard()?.id,
      'encounter_card_enc_quota_qi_missing_disciple');
    assert.equal(runtime.game.makeChoice('right'), true);
    await flush(runtime);
    inputs.push({ cardId: 'encounter_card_enc_quota_qi_missing_disciple',
      direction: 'right', turn: runtime.state.turn - 1,
      mentorProgression: mentorProgression(),
      cultivation: runtime.state.attributes.cultivation });
    for (const [id, chosen] of SECOND_ROUTE) {
      const card = runtime.game.getCurrentCard();
      assert.equal(card?.id || card?.type, id);
      assert.equal(runtime.game.makeChoice(chosen), true, `${id}.${chosen}`);
      await flush(runtime);
      inputs.push({ cardId: id, direction: chosen, turn: runtime.state.turn - 1,
        mentorProgression: mentorProgression(),
        cultivation: runtime.state.attributes.cultivation });
    }
    const card = clone(runtime.game.getCurrentCard());
    assert.equal(card?.id, 'npc_encounter_bai_ren_初见');
    const before = snapshot(runtime);
    const npcBefore = clone(npc.captureRollbackState());
    const mentorBefore = clone(story.exportState().mentorArcs);
    assert.equal(runtime.game.makeChoice(direction), true);
    await flush(runtime);
    const after = snapshot(runtime);
    const npcAfter = clone(npc.captureRollbackState());
    const mentorAfter = clone(story.exportState().mentorArcs);
    return { direction, publicInput: true, inputs, rolls, card, before, after,
      npcBefore, npcAfter, mentorBefore, mentorAfter,
      nextCard: clone(runtime.game.getCurrentCard()) };
  } finally {
    realmMath.random = originalRandom;
    npc._checkEncounter = originalCheck;
  }
}

async function main() {
  const rows = [await capture('left'), await capture('right')];
  const pins = sourcePins();
  pins['tools/capture_noncombat_npc_first_source.js'] = crypto.createHash('sha256')
    .update(fs.readFileSync(__filename)).digest('hex');
  fs.writeFileSync(OUT, JSON.stringify({ seed: 123, path: 'sword', rows,
    pins }, null, 2) + '\n');
  console.log(`NPC_FIRST_SOURCE_PASS rows=${rows.length} bytes=${fs.statSync(OUT).size}`);
}

main().catch(error => { console.error(error.stack || error); process.exitCode = 1; });
