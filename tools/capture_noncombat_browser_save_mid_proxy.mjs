// Capture an isolated local browser run through the shared web-access CDP proxy.
import { createHash } from 'node:crypto';
import { readFile, mkdir, writeFile } from 'node:fs/promises';
import { resolve, dirname } from 'node:path';

const targetId = process.argv[2];
const output = resolve(process.argv[3] ||
  'godot/output/captures/godot-migration/noncombat-browser-import/mid-source-save-sword-long.json');
const maxDecisions = Number(process.argv[4] || 10);
const isolatedPort = Number(process.argv[5] || 1987);
if (!targetId || !/^[0-9A-F]+$/i.test(targetId)) {
  throw new Error('Pass a web-access target ID created for an isolated local origin.');
}
if (!Number.isInteger(maxDecisions) || maxDecisions < 1 || maxDecisions > 40) {
  throw new Error('Maximum decisions must be an integer from 1 to 40.');
}
if (!Number.isInteger(isolatedPort) || isolatedPort < 1024 || isolatedPort > 65535) {
  throw new Error('Isolated development port must be valid.');
}
const proxy = `http://localhost:3456/eval?target=${targetId}`;
async function evaluate(expression) {
  const response = await fetch(proxy, { method: 'POST', body: expression });
  const result = await response.json();
  if (!response.ok || result.error) throw new Error(JSON.stringify(result));
  return result.value;
}
async function ready() {
  for (let attempt = 0; attempt < 40; attempt++) {
    if (await evaluate('Boolean(window.__combatE2E?.game && window.__combatE2E?.ui)')) return;
    await new Promise(resolveWait => setTimeout(resolveWait, 250));
  }
  throw new Error('Local browser game did not become ready.');
}
const isolated = await evaluate(`(() => {
  const raw = localStorage.getItem('xiuxian_unlocks');
  const save = raw ? JSON.parse(raw) : null;
  return location.hostname === '127.0.0.1' && location.port === '${isolatedPort}'
    && (!save || save.causalSessionState?.runClock?.decisionIndex === 0);
})()`);
if (!isolated) throw new Error(`Capture requires isolated port ${isolatedPort} at decision 0.`);
await evaluate('localStorage.clear(); location.reload(); true');
await new Promise(resolveWait => setTimeout(resolveWait, 750));
await ready();
await evaluate('window.__combatE2E.ui.startGame("sword")');
const snapshots = [];
const directions = [];
const capture = () => evaluate(`(() => ({storage: {
  xiuxian_unlocks: localStorage.getItem('xiuxian_unlocks'),
  xiuxian_active_save_slot: localStorage.getItem('xiuxian_active_save_slot')
}, visibleCardId: window.__combatE2E.game.getCurrentCard()?.id || null}))()`);
snapshots.push(await capture());
const prefix = ['right', 'left', 'left', 'right', 'left'];
for (let index = 0; index < maxDecisions; index++) {
  const choice = index < prefix.length ? prefix[index] : await evaluate(`(() => {
    const game = window.__combatE2E.game;
    const card = game.getCurrentCard();
    const ordered = card?.id?.startsWith('encounter_card_') ?
      ['right', 'left', 'down', 'up'] : ['left', 'right', 'down', 'up'];
    return ordered.find(direction => card?.choices?.[direction]) || null;
  })()`);
  if (!choice) break;
  const committed = await evaluate(`(() => {
    const game = window.__combatE2E.game;
    return game.makeChoice(${JSON.stringify(choice)}, game.issueChoiceToken());
  })()`);
  if (!committed) throw new Error(`Browser rejected choice ${index + 1}: ${choice}`);
  directions.push(choice);
  snapshots.push(await capture());
}
const sources = [
  'src/core/GameStateManager.js', 'src/game.js',
  'src/systems/FlowDirector.js', 'src/systems/FactionSystem.js',
  'src/systems/MarketSystem.js', 'src/systems/HeavensHintSystem.js',
  'src/systems/LegacyFragmentSystem.js', 'src/systems/NarrativeLedger.js',
  'src/systems/PathSkillSystem.js', 'src/services/EffectService.js',
];
const sourceHashes = {};
for (const name of sources) {
  const bytes = await readFile(resolve(name));
  sourceHashes[name] = createHash('sha256').update(bytes).digest('hex');
}
await mkdir(dirname(output), { recursive: true });
await writeFile(output, JSON.stringify({ source: 'live browser', path: 'sword',
  browserOrigin: 'isolated local development port', directions, sourceHashes,
  snapshots }, null, 2) + '\n');
const cards = snapshots.map(row => row.visibleCardId);
process.stdout.write(`NONCOMBAT_BROWSER_SAVE_MID_PROXY_PASS decisions=${directions.length} cards=${cards.join('>')}\n`);
