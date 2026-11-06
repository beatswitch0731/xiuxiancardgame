#!/usr/bin/env node
'use strict';

// Public UI continuation of the authenticated first-sword pending fixture.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { chromium } = require('playwright');

const root = path.resolve(__dirname, '..');
const sourcePath = path.join(root, 'godot/tests/fixtures/artifacts/godot-migration/noncombat-browser-import/combat-pending-source-sword.json');
const outputPath = path.join(root, 'godot/output/captures/godot-migration/noncombat-browser-import/combat-turn-source-sword.json');
const sha = text => crypto.createHash('sha256').update(text).digest('hex');
const keys = ['xiuxian_unlocks', 'xiuxian_unlocks_slot_2', 'xiuxian_unlocks_slot_3', 'xiuxian_active_save_slot'];

function verifyEvidence(evidence, fixture) {
  assert.equal(evidence.source, 'live browser public UI');
  assert.equal(evidence.sourceFixtureSha256, sha(fs.readFileSync(sourcePath)));
  for (const [file, expected] of Object.entries(fixture.sourceHashes)) {
    assert.equal(sha(fs.readFileSync(path.join(root, file))), expected, `source drift: ${file}`);
  }
  assert.equal(evidence.slotId, fixture.pending.slotId);
  assert.equal(evidence.states.initial.combat.authoritySeal, fixture.afterReload.authoritySeal);
  for (const [stage, phase] of Object.entries({ initial: 'PLAYER_TURN', secondCard: 'PLAYER_TURN',
    thirdCard: 'PLAYER_TURN', reactionOpen: 'REACTION_OPEN', enemyResolved: 'PLAYER_TURN' })) {
    const state = evidence.states[stage];
    assert.equal(state.screenActive, true, stage);
    assert.equal(state.combat.phase, phase, stage);
    assert.equal(JSON.parse(state.storage[evidence.slotKey]).causalSessionState.combatSession.authoritySeal,
      state.combat.authoritySeal, `${stage}: localStorage seal`);
  }
  const edgeIndex = evidence.states.initial.combat.hand.indexOf('sword_edge');
  const followIndex = evidence.states.secondCard.combat.hand.indexOf('sword_followthrough');
  assert.ok(edgeIndex >= 0 && followIndex >= 0, 'authored cards were absent from the visible hand');
  assert.deepEqual(evidence.states.secondCard.combat.authorityLedger.at(-1).detail,
    { cardId: 'sword_edge', definitionId: 'sword_edge', handIndex: edgeIndex });
  assert.deepEqual(evidence.states.thirdCard.combat.authorityLedger.at(-1).detail,
    { cardId: 'sword_followthrough', definitionId: 'sword_followthrough', handIndex: followIndex });
  assert.equal(evidence.states.reactionOpen.combat.authorityLedger.at(-1).kind, 'REACTION_OPEN');
  assert.equal(evidence.states.enemyResolved.combat.authorityLedger.at(-1).kind, 'REACTION_RESOLVED');
  assert.equal(evidence.randomObservations.length, 5);
  assert.match(evidence.randomObservations[0].origin, /DeckCombatSystem\._dealDamage/);
  for (const call of evidence.randomObservations.slice(1)) {
    assert.match(call.origin, /DeckCombatSystem\._shuffle/);
    assert.ok(Number.isFinite(call.value) && call.value >= 0 && call.value < 1);
  }
}

async function snapshot(page, slotKey) {
  return page.evaluate(({ keys, slotKey }) => {
    const storage = Object.fromEntries(keys.map(key => [key, localStorage.getItem(key)])
      .filter(([, value]) => value !== null));
    const combat = JSON.parse(storage[slotKey])?.causalSessionState?.combatSession || null;
    return { storage, combat, screenActive: document.querySelector('#deck-combat-screen')?.classList.contains('active') || false,
      reactionOptions: Array.from(document.querySelectorAll('#combat-reaction-options .combat-reaction-option'))
        .map(button => ({ text: button.textContent.trim(), disabled: button.disabled })) };
  }, { keys, slotKey });
}

async function main() {
  const fixture = JSON.parse(fs.readFileSync(sourcePath, 'utf8'));
  assert.equal(fixture.source, 'live browser public UI');
  if (process.argv.includes('--check')) {
    verifyEvidence(JSON.parse(fs.readFileSync(outputPath, 'utf8')), fixture);
    console.log('NONCOMBAT_COMBAT_TURN_SOURCE_CHECK_PASS source=true storage=true rng=5');
    return;
  }
  const slotKey = { slot_1: 'xiuxian_unlocks', slot_2: 'xiuxian_unlocks_slot_2', slot_3: 'xiuxian_unlocks_slot_3' }[fixture.pending.slotId];
  assert.ok(slotKey);
  const url = process.env.NONCOMBAT_SOURCE_URL || 'http://127.0.0.1:1978/';
  const browser = await chromium.launch({ executablePath: process.env.NONCOMBAT_CHROME || 'C:/Program Files/Google/Chrome/Application/chrome.exe', headless: true });
  const page = await browser.newPage({ viewport: { width: 1280, height: 800 } });
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  try {
    await page.goto(url, { waitUntil: 'networkidle' });
    await page.evaluate(storage => {
      localStorage.clear();
      sessionStorage.clear();
      for (const [key, value] of Object.entries(storage)) localStorage.setItem(key, value);
      localStorage.setItem('xiuxian_muted', '1');
    }, fixture.afterReload.storage);
    await page.goto(new URL('?e2e=combat&batch=n10-combat-turn', url).toString(), { waitUntil: 'networkidle' });
    await page.locator('#resume-session-btn').click();
    await page.locator('#deck-combat-screen.active').waitFor({ state: 'visible' });
    await page.evaluate(() => {
      const originalRandom = Math.random;
      window.__n10RandomObservations = [];
      Math.random = function observedRandom() {
        const value = originalRandom();
        const stack = new Error().stack || '';
        window.__n10RandomObservations.push({ value, origin: stack.split('\n').slice(2, 5).join(' | ') });
        return value;
      };
    });
    const states = {};
    states.initial = await snapshot(page, slotKey);
    assert.deepEqual(states.initial.combat.hand, fixture.pending.hand);
    assert.equal(states.initial.combat.authoritySeal, fixture.afterReload.authoritySeal);
    for (const [label, cardId] of [['secondCard', 'sword_edge'], ['thirdCard', 'sword_followthrough']]) {
      await page.waitForFunction(() => typeof deckCombatSystem !== 'undefined'
        && deckCombatSystem.active && !deckCombatSystem.isPlayerInputLocked());
      const card = page.locator(`#combat-player-hand .battle-card[data-card-id="${cardId}"]`).first();
      assert.equal(await card.count(), 1, `${label}: authored card is absent from the visible hand`);
      await card.click();
      await page.waitForFunction(({ slotKey, cardId }) => {
        const raw = localStorage.getItem(slotKey);
        const combat = raw && JSON.parse(raw).causalSessionState?.combatSession;
        return combat?.authorityLedger?.some(entry => entry.kind === 'CARD_PLAY' && entry.detail?.cardId === cardId);
      }, { slotKey, cardId });
      states[label] = await snapshot(page, slotKey);
    }
    await page.locator('#combat-end-turn-btn').click();
    await page.waitForFunction(slotKey => JSON.parse(localStorage.getItem(slotKey)).causalSessionState?.combatSession?.phase === 'REACTION_OPEN', slotKey);
    states.reactionOpen = await snapshot(page, slotKey);
    const takeHit = page.locator('#combat-reaction-options .combat-reaction-option').filter({ hasText: '承受' });
    await takeHit.click();
    await page.waitForFunction(slotKey => {
      const combat = JSON.parse(localStorage.getItem(slotKey)).causalSessionState?.combatSession;
      return combat && combat.phase !== 'REACTION_OPEN' && combat.authorityLedger?.some(entry => entry.kind === 'REACTION_RESOLVED');
    }, slotKey);
    states.enemyResolved = await snapshot(page, slotKey);
    assert.deepEqual(errors, []);
    const randomObservations = await page.evaluate(() => window.__n10RandomObservations || []);
    const evidence = { source: 'live browser public UI', sourceFixtureSha256: sha(fs.readFileSync(sourcePath)),
      slotId: fixture.pending.slotId, slotKey, states, randomObservations };
    verifyEvidence(evidence, fixture);
    fs.writeFileSync(outputPath, JSON.stringify(evidence, null, 2) + '\n');
    console.log(`NONCOMBAT_COMBAT_TURN_SOURCE_PASS second=${states.secondCard.combat.hand.length} third=${states.thirdCard.combat.hand.length} reaction=${states.reactionOpen.combat.phase} after=${states.enemyResolved.combat.phase}`);
  } finally { await browser.close(); }
}

main().catch(error => { console.error(error); process.exitCode = 1; });
