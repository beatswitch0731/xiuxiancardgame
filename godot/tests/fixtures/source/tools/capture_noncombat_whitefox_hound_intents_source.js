'use strict';

// Capture the authored hound's normal intent cycle through production inputs.
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const { openWhiteFox } = require('./capture_noncombat_whitefox_battle_source');
const { flush } = require('./capture_noncombat_mountain_source');

const root = path.resolve(__dirname, '..');
const output = path.join(root, 'godot/tests/fixtures/whitefox_hound_intents_source.json');
const sources = [
  'src/systems/DeckCombatSystem.js',
  'src/systems/PathArchetypeSystem.js',
  'data/cards/battle_cards.json',
  'data/quests/white_fox.json',
  'tools/capture_noncombat_whitefox_battle_source.js',
  'tools/capture_noncombat_whitefox_hound_intents_source.js'
];

function snapshot(deck) {
  return {
    turn: deck.turn,
    phase: deck.phase,
    active: deck.active,
    playerHp: deck.player.hp,
    playerBlock: deck.player.block,
    qi: deck.qi,
    playerWeak: deck.playerStatus?.weak || 0,
    enemyHp: deck.enemy.hp,
    intentIndex: deck.enemy.intentIndex,
    intent: JSON.parse(JSON.stringify(deck.enemyIntent)),
    planRuntime: deck.enemy.planRuntime || null
  };
}

async function main() {
  const rows = [];
  for (const pathId of ['sword', 'spell', 'body', 'pill']) {
    const { runtime } = await openWhiteFox(pathId);
    const deck = runtime.deck;
    const vmMath = deck.constructor.constructor('return Math')();
    assert.equal(deck.active, true);
    assert.equal(deck.enemy.def?.id, 'hound_pack_qi');
    assert.equal(deck.enemy.planRuntime, null);
    const states = [snapshot(deck)];
    const inputs = [];
    for (let turn = 0; turn < 3; turn++) {
      const opened = deck.endTurn();
      assert.equal(opened?.opened, true);
      const windowId = deck.pendingReaction?.windowId;
      assert.ok(windowId);
      const intentType = deck.enemyIntent.type;
      const randomCalls = [];
      const originalRandom = vmMath.random;
      vmMath.random = () => {
        const value = originalRandom();
        randomCalls.push(value);
        return value;
      };
      let resolved;
      try {
        resolved = deck.chooseReaction('TAKE_HIT', windowId);
      } finally {
        vmMath.random = originalRandom;
      }
      assert.equal(resolved?.resolved, true);
      inputs.push({ method: 'endTurn', result: 'opened', turn: turn + 1 },
        { method: 'chooseReaction', id: 'TAKE_HIT', turn: turn + 1,
          windowId, result: 'resolved',
          randomCalls,
          resistanceRoll: intentType === 'attack' && deck.player.daoHeart >= 4
            ? randomCalls[0] : null });
      await flush(runtime);
      assert.equal(deck.active, true, `${pathId} survived source turn ${turn + 1}`);
      states.push(snapshot(deck));
    }
    rows.push({ path: pathId, masterDeck: [...deck.masterDeck], inputs, states });
  }
  const pins = Object.fromEntries(sources.map(relative => [relative,
    crypto.createHash('sha256').update(fs.readFileSync(path.join(root, relative))).digest('hex')]));
  const artifact = {
    schemaVersion: 1,
    sourceEntrypoint: 'createProductionRuntime -> openWhiteFox -> DeckCombatSystem public endTurn/chooseReaction',
    publicInput: true,
    injectedState: false,
    pins,
    rows
  };
  fs.mkdirSync(path.dirname(output), { recursive: true });
  fs.writeFileSync(output, JSON.stringify(artifact, null, 2) + '\n');
  console.log(`WHITEFOX_HOUND_INTENTS_SOURCE_PASS paths=${rows.length} steps=${rows.reduce((n, row) => n + row.states.length, 0)}`);
}

main().catch(error => { console.error(error); process.exitCode = 1; });
