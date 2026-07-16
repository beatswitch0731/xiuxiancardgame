/**
 * test_p1_6_revive.js - P1 #6 复活法宝微数值修复验证
 *
 * 验证四种复活法宝触发后玩家 HP 处于微数值范围（≤ maxHealth=3），
 * 不再出现 health=100 的爆表情况。
 *
 * 用法：node tools/test_p1_6_revive.js
 */
const fs = require('fs');
const path = require('path');
const vm = require('vm');
const assert = require('assert');

const DIR = path.join(__dirname, '..');

// ========== 1. 数据加载 ==========
function loadJson(relPath) {
  const fp = path.join(DIR, relPath);
  if (!fs.existsSync(fp)) return null;
  try { return JSON.parse(fs.readFileSync(fp, 'utf8')); }
  catch (e) { return null; }
}

const DATA_MODULES = {
  'config:realms': loadJson('data/config/realms.json'),
  'config:paths': loadJson('data/config/paths.json'),
  'config:path_skills': loadJson('data/config/path_skills.json'),
  'cards:qi': loadJson('data/cards/qi.json'),
  'cards:foundesation': loadJson('data/cards/foundation.json'),
  'cards:battle_cards': loadJson('data/cards/battle_cards.json'),
  'cards:karma': loadJson('data/cards/karma.json'),
  'cards:chapter_milestones': loadJson('data/cards/chapter_milestones.json'),
  'shops:treasures': loadJson('data/shops/treasures.json'),
  'shops:shop_items': loadJson('data/shops/shop_items.json'),
};

// ========== 2. 创建上下文 ==========
const sandbox = {
  console, setTimeout, setInterval, clearTimeout, clearInterval,
  Math, Date, Array, Object, String, Number, Boolean, JSON,
  parseInt, parseFloat, isNaN, isFinite, NaN, Infinity, undefined,
  Error, TypeError, RangeError,
  Map, Set, WeakMap, WeakSet, Symbol, Promise, Reflect,
  DATA_MODULES,
  document: { addEventListener: () => {}, querySelector: () => null, querySelectorAll: () => [], getElementById: () => null, createElement: () => ({ style: {}, classList: { add: () => {}, remove: () => {}, contains: () => false }, appendChild: () => {}, addEventListener: () => {}, setAttribute: () => {}, getContext: () => null }) },
  window: { addEventListener: () => {} },
  localStorage: { getItem: () => null, setItem: () => {}, removeItem: () => {} },
  requestAnimationFrame: (fn) => setTimeout(fn, 0),
  performance: { now: () => Date.now() },
};
const context = vm.createContext(sandbox);

// ========== 3. 加载脚本 ==========
const loadOrder = [
  'src/core/EventBus.js',
  'src/core/DataLoader.js',
  'src/core/GameStateManager.js',
  'src/systems/KarmaSystem.js',
  'src/systems/CardSystem.js',
  'src/systems/DeckCombatSystem.js',
  'src/systems/TreasureSystem.js',
  'src/services/EffectService.js',
  'src/coordinators/CombatCoordinator.js',
  'src/game.js',
];

for (const rel of loadOrder) {
  const fp = path.join(DIR, rel);
  if (!fs.existsSync(fp)) continue;
  const code = fs.readFileSync(fp, 'utf8');
  try {
    new vm.Script(code, { filename: rel }).runInContext(context, { timeout: 5000 });
  } catch (e) {
    console.log(`❌ 加载失败 ${rel}: ${e.message}`);
  }
}

// ========== 4. 初始化 ==========
try {
  const getVar = (name) => vm.runInContext(name, context);
  const _dataLoader = getVar('dataLoader');
  const _gameState = getVar('gameState');
  const _cardSystem = getVar('cardSystem');
  const _karmaSystem = getVar('karmaSystem');
  const _deckCombatSystem = getVar('deckCombatSystem');
  const _treasureSystem = getVar('treasureSystem');

  if (_dataLoader) {
    for (const [key, val] of Object.entries(DATA_MODULES)) {
      if (val) _dataLoader.cache.set(key, val);
    }
  }
  if (_gameState) _gameState.init({ realms: DATA_MODULES['config:realms'], paths: DATA_MODULES['config:paths'] });
  if (_gameState) _gameState.path = 'sword';
  if (_cardSystem) _cardSystem.init(DATA_MODULES);
  if (_karmaSystem) _karmaSystem.init(DATA_MODULES['cards:karma'] || {});
  if (_deckCombatSystem) _deckCombatSystem.init({ battleCards: DATA_MODULES['cards:battle_cards'] || {} });
  if (_treasureSystem) _treasureSystem.init();

  sandbox.gameState = _gameState;
  sandbox.treasureSystem = _treasureSystem;
  sandbox.deckCombatSystem = _deckCombatSystem;
} catch (e) {
  console.log('初始化错误:', e.message);
}

// ========== 5. 测试框架 ==========
let passed = 0, failed = 0;
const results = [];
function test(name, fn) {
  try { fn(); passed++; results.push(`  ✅ ${name}`); }
  catch (e) { failed++; results.push(`  ❌ ${name}: ${e.message}`); }
}

// ========== 6. 辅助 ==========
function setupReviveScenario(treasureId) {
  sandbox.gameState.reset(true);
  sandbox.gameState.path = 'sword';
  sandbox.gameState.maxHealth = 3;
  sandbox.gameState.attributes.health = 0;  // 死亡
  sandbox.gameState.attributes.daoHeart = 3;
  sandbox.gameState.attributes.cultivation = 80;
  sandbox.gameState.resources.spiritStone = 100;
  sandbox.gameState.dead = true;
  sandbox.gameState.deadReason = '测试死亡';
  sandbox.gameState.treasureInventory = [treasureId];
  sandbox.treasureSystem.owned = new Set([treasureId]);
  sandbox.treasureSystem.equipped = { weapon: null, armor: null, accessory: null, artifact: treasureId };
}

// ========== 7. 开始测试 ==========
console.log('=== P1 #6 复活法宝微数值修复验证 ===\n');

test('前置: treasures.json 已加载', () => {
  assert.ok(sandbox.treasureSystem.treasureDB['涅槃羽'], '涅槃羽 应已加载');
  assert.ok(sandbox.treasureSystem.treasureDB['替身符'], '替身符 应已加载');
  assert.ok(sandbox.treasureSystem.treasureDB['轮回镜'], '轮回镜 应已加载');
  assert.ok(sandbox.treasureSystem.treasureDB['混沌茧'], '混沌茧 应已加载');
});

// === 涅槃羽 ===
test('#6a 涅槃羽复活 HP 应为 maxHealth(3)，不再爆表至 100', () => {
  setupReviveScenario('涅槃羽');
  const result = sandbox.treasureSystem.executeRevive('涅槃羽', sandbox.gameState, '测试');
  assert.strictEqual(result.success, true, '应成功复活');
  assert.strictEqual(sandbox.gameState.attributes.health, 3, `HP 应为 3，实际: ${sandbox.gameState.attributes.health}`);
  assert.ok(sandbox.gameState.attributes.health <= 3, 'HP 不应超过 maxHealth');
});

test('#6b 涅槃羽复活后道心 -1（从 3 → 2）', () => {
  setupReviveScenario('涅槃羽');
  sandbox.treasureSystem.executeRevive('涅槃羽', sandbox.gameState, '测试');
  assert.strictEqual(sandbox.gameState.attributes.daoHeart, 2, `道心应为 2，实际: ${sandbox.gameState.attributes.daoHeart}`);
});

test('#6c 涅槃羽复活后 dead 应为 false', () => {
  setupReviveScenario('涅槃羽');
  sandbox.treasureSystem.executeRevive('涅槃羽', sandbox.gameState, '测试');
  assert.strictEqual(sandbox.gameState.dead, false, 'dead 应为 false');
});

// === 替身符 ===
test('#6d 替身符复活 HP 应为 2（微数值）', () => {
  setupReviveScenario('替身符');
  const result = sandbox.treasureSystem.executeRevive('替身符', sandbox.gameState, '测试');
  assert.strictEqual(result.success, true, '应成功复活');
  assert.strictEqual(sandbox.gameState.attributes.health, 2, `HP 应为 2，实际: ${sandbox.gameState.attributes.health}`);
  assert.ok(sandbox.gameState.attributes.health <= 3, 'HP 不应超过 maxHealth');
});

test('#6e 替身符复活后灵石应减半（100 → 50）', () => {
  setupReviveScenario('替身符');
  sandbox.treasureSystem.executeRevive('替身符', sandbox.gameState, '测试');
  assert.strictEqual(sandbox.gameState.resources.spiritStone, 50, `灵石应为 50，实际: ${sandbox.gameState.resources.spiritStone}`);
});

// === 轮回镜 ===
test('#6f 轮回镜复活 HP 应为 2，道心 -2，修为 -20%', () => {
  setupReviveScenario('轮回镜');
  const result = sandbox.treasureSystem.executeRevive('轮回镜', sandbox.gameState, '测试');
  assert.strictEqual(result.success, true);
  assert.strictEqual(sandbox.gameState.attributes.health, 2, `HP 应为 2，实际: ${sandbox.gameState.attributes.health}`);
  assert.strictEqual(sandbox.gameState.attributes.daoHeart, 1, `道心应为 1（3-2），实际: ${sandbox.gameState.attributes.daoHeart}`);
  assert.strictEqual(sandbox.gameState.attributes.cultivation, 64, `修为应为 64（80*0.8），实际: ${sandbox.gameState.attributes.cultivation}`);
  assert.ok(sandbox.gameState.attributes.health <= 3, 'HP 不应超过 maxHealth');
});

// === 混沌茧 ===
test('#6g 混沌茧复活 HP 应为 maxHealth(3)，不再爆表至 100', () => {
  setupReviveScenario('混沌茧');
  const result = sandbox.treasureSystem.executeRevive('混沌茧', sandbox.gameState, '测试');
  assert.strictEqual(result.success, true);
  assert.strictEqual(sandbox.gameState.attributes.health, 3, `HP 应为 3，实际: ${sandbox.gameState.attributes.health}`);
  assert.ok(sandbox.gameState.attributes.health <= 3, 'HP 不应超过 maxHealth');
});

test('#6h 混沌茧不再将所有属性重置为 50（道心应保留或不变）', () => {
  setupReviveScenario('混沌茧');
  // 设置不同的初始值，验证不被重置为 50
  sandbox.gameState.attributes.daoHeart = 3;
  sandbox.gameState.attributes.fortune = 30;
  sandbox.gameState.attributes.karmaGood = 20;
  sandbox.treasureSystem.executeRevive('混沌茧', sandbox.gameState, '测试');
  assert.notStrictEqual(sandbox.gameState.attributes.daoHeart, 50, '道心不应被重置为 50');
  assert.notStrictEqual(sandbox.gameState.attributes.fortune, 50, '福缘不应被重置为 50');
  assert.notStrictEqual(sandbox.gameState.attributes.karmaGood, 50, '善因不应被重置为 50');
});

test('#6i 混沌茧复活后修为 -20%（80 → 64）', () => {
  setupReviveScenario('混沌茧');
  sandbox.treasureSystem.executeRevive('混沌茧', sandbox.gameState, '测试');
  assert.strictEqual(sandbox.gameState.attributes.cultivation, 64, `修为应为 64，实际: ${sandbox.gameState.attributes.cultivation}`);
});

// === 通用 ===
test('#6j 复活后法宝应从 owned 移除（一次性消耗）', () => {
  setupReviveScenario('涅槃羽');
  assert.ok(sandbox.treasureSystem.owned.has('涅槃羽'), '前置: 应拥有涅槃羽');
  sandbox.treasureSystem.executeRevive('涅槃羽', sandbox.gameState, '测试');
  assert.strictEqual(sandbox.treasureSystem.owned.has('涅槃羽'), false, '复活后应从 owned 移除');
});

test('#6k 复活后 artifact 槽位应卸下', () => {
  setupReviveScenario('涅槃羽');
  assert.strictEqual(sandbox.treasureSystem.equipped.artifact, '涅槃羽', '前置: artifact 应为涅槃羽');
  sandbox.treasureSystem.executeRevive('涅槃羽', sandbox.gameState, '测试');
  assert.strictEqual(sandbox.treasureSystem.equipped.artifact, null, '复活后 artifact 槽位应为 null');
});

// === 战斗集成测试 ===
test('#6l 战斗场景下复活数值不爆表（maxHealth=3）', () => {
  sandbox.gameState.reset(true);
  sandbox.gameState.path = 'sword';
  sandbox.gameState.maxHealth = 3;
  sandbox.gameState.attributes.health = 1;  // 残血
  sandbox.gameState.attributes.daoHeart = 3;
  sandbox.gameState.attributes.cultivation = 50;
  sandbox.gameState.treasureInventory = ['涅槃羽'];
  sandbox.treasureSystem.owned = new Set(['涅槃羽']);
  sandbox.treasureSystem.equipped = { weapon: null, armor: null, accessory: null, artifact: '涅槃羽' };

  // 模拟战斗中死亡
  sandbox.gameState.attributes.health = 0;
  sandbox.gameState.dead = true;
  sandbox.gameState.deadReason = '战斗陨落';

  const result = sandbox.treasureSystem.executeRevive('涅槃羽', sandbox.gameState, '战斗陨落');
  assert.strictEqual(result.success, true);
  assert.strictEqual(sandbox.gameState.attributes.health, 3, `战斗复活后 HP 应为 3，实际: ${sandbox.gameState.attributes.health}`);
  assert.strictEqual(sandbox.gameState.dead, false, 'dead 应为 false');
  assert.ok(sandbox.gameState.attributes.health <= sandbox.gameState.maxHealth, 'HP 不应超过 maxHealth');
});

console.log(results.join('\n'));
console.log(`\n=== 测试结果 ===`);
console.log(`  通过: ${passed}`);
console.log(`  失败: ${failed}`);
console.log(`  总计: ${passed + failed}`);
if (failed > 0) {
  console.log('\n❌ 有测试失败，请检查修复是否正确应用');
  process.exit(1);
} else {
  console.log('\n✅ 所有测试通过，#6 复活微数值修复验证成功');
}
