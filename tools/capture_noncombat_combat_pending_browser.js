#!/usr/bin/env node
'use strict';

// Reproduce with: node tools/capture_noncombat_combat_pending_browser.js
// Read-only drift check: node tools/capture_noncombat_combat_pending_browser.js --check
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { chromium } = require('playwright');

const root = path.resolve(__dirname, '..');
const output = path.join(root, 'godot/output/captures/godot-migration/noncombat-browser-import/combat-pending-source-sword.json');
const files = ['index.html', 'src/core/GameStateManager.js', 'src/coordinators/CombatCoordinator.js',
  'src/systems/DeckCombatSystem.js', 'src/game.js', 'src/ui.js', 'data/cards/qi.json',
  'data/npcs/core_npcs.json'];
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const hashes = () => Object.fromEntries(files.map(file => [file, sha(fs.readFileSync(path.join(root, file)))]));
const slotKeys = ['xiuxian_unlocks', 'xiuxian_unlocks_slot_2', 'xiuxian_unlocks_slot_3', 'xiuxian_active_save_slot'];

function verify(fixture) {
  assert.deepEqual(fixture.sourceHashes, hashes(), 'source drift');
  assert.equal(fixture.source, 'live browser public UI');
  for (const stage of ['pending', 'afterReload', 'result', 'next']) {
    assert.equal(Object.values(fixture[stage].storage).includes(null), false,
      `${stage}: absent localStorage key exported as null`);
  }
  assert.equal(fixture.pending.originalCardId, 'encounter_card_enc_trial_sword_swift');
  const key = { slot_1: 'xiuxian_unlocks', slot_2: 'xiuxian_unlocks_slot_2', slot_3: 'xiuxian_unlocks_slot_3' }[fixture.pending.slotId];
  assert.ok(key);
  const raw = fixture.pending.storage[key];
  assert.equal(typeof raw, 'string');
  assert.equal(sha(raw), fixture.pending.slotSha256);
  const saved = JSON.parse(raw);
  assert.equal(saved.saveVersion, 10);
  assert.equal(saved.causalSessionState.version, 18);
  assert.equal(saved.questState.saveVersion, 3);
  const combat = saved.causalSessionState.combatSession;
  assert.equal(combat.active, true);
  assert.equal(combat.version, 3);
  assert.equal(typeof combat.authoritySeal, 'string');
  assert.equal(combat.authoritySeal, fixture.pending.authoritySeal);
  assert.equal(combat.originalCard.id, fixture.pending.originalCardId);
  assert.equal(combat.authorityLedger.at(-1)?.detail?.cardId, 'sword_sheath_guard');
  assert.ok(fixture.pending.hand.includes('sword_edge')
    && fixture.pending.hand.includes('sword_followthrough'),
  'pending hand cannot exercise the captured two-card continuation');
  assert.equal(fixture.afterReload.active, true);
  assert.equal(fixture.afterReload.authoritySeal,
    JSON.parse(fixture.afterReload.storage[key]).causalSessionState.combatSession.authoritySeal);
  assert.match(fixture.result.visibleCardId, /^combat_fled_/);
  assert.ok(fixture.next.visibleCardId);
  assert.equal(fixture.next.decisionIndex, fixture.result.decisionIndex + 1);
}

async function snapshot(page) {
  return page.evaluate(keys => {
    const game = window.__combatE2E?.game;
    const state = game?.gameState;
    const combat = state?.combatSession;
    const storage = Object.fromEntries(keys.map(key => [key, localStorage.getItem(key)])
      .filter(([, value]) => value !== null));
    return { storage, slotId: state?.activeSaveSlotId || null,
      visibleCardId: game?.getCurrentCard?.()?.id || null,
      decisionIndex: state?.getDecisionIndex?.() ?? state?.runClock?.decisionIndex ?? null,
      turn: state?.turn ?? null, health: state?.attributes?.health ?? null,
      active: combat?.active === true, authoritySeal: combat?.authoritySeal || null,
      originalCardId: combat?.originalCard?.id || null,
      phase: combat?.phase || null,
      encounterId: combat?.encounterContext?.encounterId || null,
      hand: combat?.hand || null, enemy: combat?.enemy || null };
  }, slotKeys);
}

async function choose(page, direction) {
  const button = page.locator(`#choice-${direction}`);
  await button.waitFor({ state: 'visible', timeout: 15000 });
  assert.equal(await button.getAttribute('aria-disabled'), 'false', direction);
  await button.click();
  await page.waitForTimeout(550);
}

async function main() {
  if (process.argv.includes('--check')) {
    verify(JSON.parse(fs.readFileSync(output, 'utf8')));
    console.log('NONCOMBAT_COMBAT_PENDING_SOURCE_CHECK_PASS source=true raw=true seal=true result=true');
    return;
  }
  const url = process.env.NONCOMBAT_SOURCE_URL || 'http://127.0.0.1:1978/';
  const executablePath = process.env.NONCOMBAT_CHROME || 'C:/Program Files/Google/Chrome/Application/chrome.exe';
  const browser = await chromium.launch({ executablePath, headless: true });
  const page = await browser.newPage({ viewport: { width: 1280, height: 800 } });
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  try {
    await page.goto(url, { waitUntil: 'networkidle' });
    await page.evaluate(() => { localStorage.clear(); sessionStorage.clear(); localStorage.setItem('xiuxian_muted', '1'); });
    await page.goto(new URL('?e2e=combat&batch=n10-combat-pending', url).toString(), { waitUntil: 'networkidle' });
    const create = page.locator('#save-slot-list button[data-save-slot-action="create"]').first();
    if (await create.isVisible()) await create.click();
    await page.waitForFunction(() => window.__combatE2E?.ui?.startGame);
    await page.locator('#name-confirm-btn').click();
    await page.locator('.path-btn[data-path="sword"]').click();
    await page.locator('#game-screen.screen.active').waitFor({ state: 'visible' });
    const chapter = page.locator('#chapter-scroll-transition');
    if (await chapter.count()) await chapter.waitFor({ state: 'hidden', timeout: 7000 });
    const route = [];
    for (let i = 0; i < 12; i++) {
      const before = await snapshot(page);
      if (before.visibleCardId === 'encounter_card_enc_trial_sword_swift') break;
      assert.ok(before.visibleCardId, 'missing card on route');
      route.push({ cardId: before.visibleCardId, direction: 'left', decisionIndex: before.decisionIndex });
      await choose(page, 'left');
    }
    const encounter = await snapshot(page);
    assert.equal(encounter.visibleCardId, 'encounter_card_enc_trial_sword_swift');
    route.push({ cardId: encounter.visibleCardId, direction: 'left', decisionIndex: encounter.decisionIndex });
    await choose(page, 'left');
    const warning = await snapshot(page);
    assert.match(warning.visibleCardId, /^_warning_/);
    route.push({ cardId: warning.visibleCardId, direction: 'left', decisionIndex: warning.decisionIndex });
    await choose(page, 'left');
    await page.waitForFunction(() => window.__combatE2E?.game?.gameState?.combatSession?.active === true);
    // Select the authored guard through the visible hand; its position varies
    // with the browser's normal opening shuffle.
    const guard = page.locator('#combat-player-hand .battle-card[data-card-id="sword_sheath_guard"]');
    assert.equal(await guard.count(), 1, 'opening hand has no sword_sheath_guard; recapture');
    await guard.waitFor({ state: 'visible' });
    await page.waitForFunction(() => !deckCombatSystem.isPlayerInputLocked());
    assert.equal(await guard.getAttribute('aria-disabled'), 'false', 'guard unavailable');
    await guard.click();
    await page.waitForFunction(() => {
      return ['xiuxian_unlocks', 'xiuxian_unlocks_slot_2', 'xiuxian_unlocks_slot_3']
        .some(key => { const raw = localStorage.getItem(key);
          return raw && JSON.parse(raw).causalSessionState?.combatSession?.active === true; });
    });
    const pending = await snapshot(page);
    assert.ok(pending.hand.includes('sword_edge')
      && pending.hand.includes('sword_followthrough'),
    'opening hand cannot exercise the captured two-card continuation; recapture');
    const slotKey = { slot_1: 'xiuxian_unlocks', slot_2: 'xiuxian_unlocks_slot_2', slot_3: 'xiuxian_unlocks_slot_3' }[pending.slotId];
    pending.slotSha256 = sha(pending.storage[slotKey]);
    assert.equal(pending.originalCardId, encounter.visibleCardId);
    await page.reload({ waitUntil: 'networkidle' });
    await page.waitForFunction(() => window.__combatE2E?.game?.gameState?.combatSession?.active === true);
    await page.locator('#resume-session-btn').click();
    await page.locator('#deck-combat-screen.active').waitFor({ state: 'visible' });
    const afterReload = await snapshot(page);
    assert.equal(afterReload.active, true);
    await page.locator('#combat-flee-btn').click();
    await page.locator('#combat-flee-btn').click();
    await page.waitForFunction(() => /^combat_fled_/.test(window.__combatE2E?.game?.getCurrentCard?.()?.id || ''));
    const result = await snapshot(page);
    await choose(page, 'down');
    const next = await snapshot(page);
    const sourceHashes = hashes();
    for (const file of files) {
      const response = await page.request.get(new URL(file, url).toString(), { headers: { 'Cache-Control': 'no-cache' } });
      assert.equal(response.ok(), true, `served source ${file}`);
      assert.equal(sha(await response.body()), sourceHashes[file], `served source drift ${file}`);
    }
    assert.deepEqual(errors, [], 'browser page errors');
    const fixture = { source: 'live browser public UI', urlPath: '/', path: 'sword', route,
      sourceHashes, pending, afterReload, result, next };
    verify(fixture);
    fs.mkdirSync(path.dirname(output), { recursive: true });
    fs.writeFileSync(output, JSON.stringify(fixture, null, 2) + '\n');
    console.log(`NONCOMBAT_COMBAT_PENDING_SOURCE_PASS slot=${pending.slotId} decision=${pending.decisionIndex} card=${pending.originalCardId} result=${result.visibleCardId} next=${next.visibleCardId}`);
  } finally { await browser.close(); }
}
main().catch(error => { console.error(error); process.exitCode = 1; });
