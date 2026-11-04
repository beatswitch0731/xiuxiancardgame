// Executes the current browser equipment/damage rules to produce the Godot
// comparison fixture. Only presentation, persistence, draws and enemy planning
// are stubbed; equip, passive dispatch, card effects and damage stay original.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '../..');
const files = ['data/shops/treasures.json', 'data/cards/battle_cards.json',
  'src/systems/EquipmentSystem.js', 'src/systems/TreasureSystem.js',
  'src/systems/DeckCombatSystem.js'];
const bytes = Object.fromEntries(files.map(f => [f, fs.readFileSync(path.join(root, f))]));
const catalog = JSON.parse(bytes[files[0]]).treasures;
const cards = Object.fromEntries(JSON.parse(bytes[files[1]]).battle_cards.map(c => [c.id, c]));
const ids = ['问道剑', 'brokenSword', '玄铁甲', '灵纹法袍', '灵泉葫芦', '青云剑匣'];
function runtime() {
  const state = { resources: { treasures: ids }, equipment: {}, treasureInstances: {},
    treasureCooldowns: {}, treasureCommandReceipts: {}, attributes: {}, realm: 'qi', path: 'sword' };
  for (const id of ids) {
    const instanceId = 'equipment-demo:' + id;
    state.treasureInstances[instanceId] = { instanceId, definitionId: id,
      lifecycle: 'owned', acquiredDecision: 0, provenance: { source: 'equipment_demo' } };
  }
  const math = Object.create(Math);
  math.random = () => 0.5; // Reproducible non-critical comparison, not a balance change.
  const ctx = vm.createContext({ gameState: state, console: { log() {}, warn() {}, error() {} },
    window: {}, global: {}, module: { exports: {} }, Math: math,
    eventBus: { emit() {}, on() {} }, setTimeout, clearTimeout });
  vm.runInContext(bytes[files[2]].toString(), ctx, { filename: files[2] });
  vm.runInContext('var equipmentSystem = new EquipmentSystem({gameState, debug:false});', ctx);
  vm.runInContext(bytes[files[3]].toString(), ctx, { filename: files[3] });
  vm.runInContext(bytes[files[4]].toString(), ctx, { filename: files[4] });
  const treasure = vm.runInContext('treasureSystem', ctx);
  const deck = vm.runInContext('deckCombatSystem', ctx);
  const equipment = vm.runInContext('equipmentSystem', ctx);
  treasure.loadData({ treasures: catalog });
  if (!treasure.syncFromState()) throw new Error('source ledger failed');
  deck.player = { hp: 8, maxHp: 12, block: 0, aura: 0, atkMod: 0, defMod: 0,
    critRate: 0, daoHeart: 0, realm: 'qi' };
  deck.enemy = { hp: 120, maxHp: 120, block: 0, defPower: 0, name: '木人', realm: 'qi' };
  deck.active = true;
  deck.turn = 1;
  deck.qi = 3;
  deck.maxQi = 3;
  deck.phase = 'PLAYER_TURN';
  deck.getCardDef = id => cards[id];
  for (const method of ['_emitPresentationVfx', '_emitCombatFeedback', '_emitSemanticActionPhase',
    '_emitPlayerPresentationAction', '_emitEnemyPresentationAction', '_emitVfxRequest',
    '_emitResolvedPresentationEffect', '_signalEnemyBlockBroken', '_handleEnemyDefeated',
    '_checkPlayerDeath', '_beginPlanPlayerTurn', '_generateEnemyIntent', '_drawCards',
    '_applyKarmaJudgment', '_recordAuthorityCheckpoint', '_triggerUpdate', '_persistCombatSession']) {
    deck[method] = () => {};
  }
  return { state, deck, treasure, equipment };
}
function snapshot(r) {
  const p = r.equipment.getActivePassives();
  const idx = p.findIndex(x => x.sourceItemName === '青云剑匣' && x.triggerCount);
  return { hp: r.deck.player.hp, qi: r.deck.qi, block: r.deck.player.block,
    enemyHp: r.deck.enemy.hp, enemyBlock: r.deck.enemy.block,
    opening: r.deck.enemyStatus.opening || 0, turn: r.deck.turn,
    artifactCounter: idx < 0 ? 0 : r.deck.equipmentState['eq_' + idx] || 0 };
}
function equip(r, slot, id) {
  const result = id ? r.treasure.equip('equipment-demo:' + id, slot, { persist:false, emit:false })
    : r.treasure.unequip(slot, { persist:false, emit:false });
  if (!result.success) throw new Error(JSON.stringify(result));
  Object.assign(r.deck.player, { atkMod: r.treasure.getCombatModifiers().atk,
    defMod: r.treasure.getCombatModifiers().def, critRate: r.treasure.getCombatModifiers().critRate });
}
function play(r, cardId) {
  const c = cards[cardId];
  if (r.deck.qi < c.cost) throw new Error('reference card unaffordable');
  r.deck.qi -= c.cost;
  r.deck._triggerEquipmentPassives('onCardPlay', c);
  c.effects.forEach((e, i) => r.deck._resolveEffect(e, null, c, i));
}
const traces = [];
for (const weapon of ['brokenSword', '问道剑']) {
  const r = runtime();
  equip(r, 'weapon', weapon); equip(r, 'armor', '玄铁甲'); equip(r, 'artifact', '青云剑匣');
  const steps = [];
  for (const action of ['attack', 'guard', 'end_turn', 'attack', 'attack', 'attack', 'end_turn']) {
    if (action === 'end_turn') {
      r.deck._triggerEquipmentPassives('onTurnEnd');
      r.deck._dealDamage(r.deck.player, 3);
      r.deck._startTurn();
    } else play(r, action === 'attack' ? 'sword_probe' : 'sword_guard');
    steps.push({ action, expected: snapshot(r) });
  }
  traces.push({ weapon, armor:'玄铁甲', artifact:'青云剑匣', steps });
}
// Actual executable behavior wins over the sword-box "piercing 5" description.
const shield = runtime();
equip(shield, 'weapon', '问道剑'); equip(shield, 'artifact', '青云剑匣');
shield.deck.enemy.block = 10;
for (let i = 0; i < 3; i++) shield.deck._triggerEquipmentPassives('onCardPlay', cards.sword_probe);
const regen = runtime();
equip(regen, 'armor', '灵纹法袍'); equip(regen, 'accessory', '灵泉葫芦');
regen.deck.qi = 0;
regen.deck._triggerEquipmentPassives('onTurnEnd');
regen.deck._startTurn();
const armorChecks = [];
for (const armor of ['玄铁甲', '灵纹法袍']) {
  for (const guard of [false, true]) {
    const r = runtime();
    equip(r, 'armor', armor);
    if (guard) play(r, 'sword_guard');
    r.deck._dealDamage(r.deck.player, 3);
    armorChecks.push({ armor, guard, hp: r.deck.player.hp,
      modifiers: r.treasure.getCombatModifiers() });
  }
}
const fixture = { generatedBy:'current executable browser source',
  sourceSha256: Object.fromEntries(files.map(f => [f, crypto.createHash('sha256').update(bytes[f]).digest('hex')])),
  traces, armorChecks, swordBoxShield: snapshot(shield), regenGap: snapshot(regen),
  declarations: Object.fromEntries(catalog.filter(x => ids.includes(x.id)).map(x => [x.id, x.passive || {}])) };
const output = path.join(root, 'godot/tests/fixtures/equipment_demo_source_reference.json');
fs.mkdirSync(path.dirname(output), {recursive:true});
fs.writeFileSync(output, JSON.stringify(fixture, null, 2) + '\n');
console.log('EQUIPMENT_DEMO_BROWSER_REFERENCE_PASS traces=' + traces.length
  + ' shieldRemaining=' + fixture.swordBoxShield.enemyBlock
  + ' sourceRegenHp=' + fixture.regenGap.hp + ' sourceRegenQi=' + fixture.regenGap.qi);
