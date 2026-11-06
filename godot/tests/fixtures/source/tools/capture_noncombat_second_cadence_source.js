'use strict';
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const { openCadence, captureAvoid, snapshot, enterBattle, resolveBattle,
  sourcePins } = require('./capture_noncombat_cadence_source');
const { flush } = require('./capture_noncombat_mountain_source');

const ROOT = path.resolve(__dirname, '..');
const OUT = path.join(ROOT, 'godot/tests/fixtures/second_cadence_source.json');
const SOURCE_ID = 'encounter_card_enc_quota_qi_missing_disciple';
const ROUTE = [
  ['q_whiteFox_quest', 'right'], ['q_whiteFox_2', 'right'],
  ['q_whiteFox_3', 'down'], ['kx_path_sword_legacy', 'right'],
  ['k_chapter_sword_left', 'right'], ['DESTINY_WHEEL', 'left'],
  ['kx_ch_hoarded_manual', 'right'], ['kx_ch_sword_sect_path', 'right']
];
const clone = value => value == null ? value : JSON.parse(JSON.stringify(value));

async function openSecond() {
  const { runtime, context } = await openCadence();
  const first = await captureAvoid(runtime, context);
  assert.equal(first.outcome, 'avoided');
  const inputs = [];
  for (const [id, direction] of ROUTE) {
    const card = runtime.game.getCurrentCard();
    assert.equal(card?.id || card?.type, id);
    assert.equal(runtime.game.makeChoice(direction), true, `${id}.${direction}`);
    await flush(runtime);
    inputs.push({ cardId: id, direction, turn: runtime.state.turn - 1,
      wheelFirst: id === 'DESTINY_WHEEL' ?
        { name: card.wheelState?.deck?.[0]?.name,
          rarity: card.wheelState?.deck?.[0]?.rarity } : undefined,
      health: runtime.state.attributes.health,
      lifespan: runtime.state.resources.lifespan });
  }
  const sourceCard = clone(runtime.game.getCurrentCard());
  assert.equal(sourceCard?.id, SOURCE_ID);
  assert.equal(sourceCard?._flowSource, 'encounter:cadence');
  const offered = snapshot(runtime);
  assert.equal(offered.director.pending?.encounterId,
    'enc_quota_qi_missing_disciple');
  return { runtime, first: { caseId: first.caseId, after: first.after,
    directorAfter: first.directorAfter }, inputs, sourceCard, offered };
}

async function capture(outcome) {
  const opened = await openSecond();
  const { runtime, sourceCard, offered, inputs, first } = opened;
  if (outcome === 'avoided') {
    assert.equal(runtime.game.makeChoice('right'), true);
    await flush(runtime);
    const after = snapshot(runtime);
    assert.equal(after.director.pending, null);
    assert.equal(after.choiceHistory.at(-1).cardId, SOURCE_ID);
    assert.equal(after.director.realmProgress.qi.avoidedIds.at(-1),
      sourceCard.encounterId);
    return { outcome, first, inputs, sourceCard, offered, after,
      nextCard: clone(runtime.game.getCurrentCard()) };
  }
  const entered = await enterBattle(runtime);
  assert.equal(entered.sourceCard.id, SOURCE_ID);
  const result = await resolveBattle(runtime, entered, outcome);
  return { outcome, first, inputs, sourceCard, offered,
    ...result };
}

async function main() {
  const rows = [];
  for (const outcome of ['avoided', 'victory', 'defeat', 'flee']) {
    rows.push(await capture(outcome));
  }
  const pins = sourcePins();
  pins['tools/capture_noncombat_second_cadence_source.js'] = crypto.createHash(
    'sha256').update(fs.readFileSync(__filename)).digest('hex');
  fs.writeFileSync(OUT, JSON.stringify({ seed: 123, path: 'sword',
    publicInput: true, sourceCardId: SOURCE_ID, route: ROUTE, pins, rows }, null, 2) + '\n');
  console.log(`SECOND_CADENCE_SOURCE_PASS rows=${rows.length} bytes=${fs.statSync(OUT).size}`);
}

main().catch(error => { console.error(error.stack || error); process.exitCode = 1; });
