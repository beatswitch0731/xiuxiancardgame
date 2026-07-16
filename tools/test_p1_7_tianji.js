/**
 * test_p1_7_tianji.js - P1 #7 天机值 handler + 雷劫接入验证
 *
 * 验证：
 *   - EffectService 已注册 tianji handler
 *   - apply({tianji: 5}) 能正确修改 gameState.tianji
 *   - _resolveBreakthrough 在 tianji > 30 时降低成功率
 *
 * 用法：node tools/test_p1_7_tianji.js
 */
const fs = require('fs');
const path = require('path');
const vm = require('vm');
const assert = require('assert');

const DIR = path.join(__dirname, '..');

function loadJson(relPath) {
  const fp = path.join(DIR, relPath);
  if (!fs.existsSync(fp)) return null;
  try { return JSON.parse(fs.readFileSync(fp, 'utf8')); } catch (e) { return null; }
}

const DATA_MODULES = {
  'config:realms': loadJson('data/config/realms.json'),
  'config:paths': loadJson('data/config/paths.json'),
  'cards:qi': loadJson('data/cards/qi.json'),
  'cards:foundesation': loadJson('data/cards/foundation.json'),
  'cards:battle_cards': loadJson('data/cards/battle_cards.json'),
  'cards:karma': loadJson('data/cards/karma.json'),
  'cards:chapter_milestones': loadJson('data/cards/chapter_milestones.json'),
  'shops:treasures': loadJson('data/shops/treasures.json'),
};

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
  // stub: game.js _resolveBreakthrough/_advanceRealm 会引用 pathSkillSystem
  pathSkillSystem: { getPassiveBonuses: () => ({}), unlockForRealm: () => [] },
};
const context = vm.createContext(sandbox);

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
  try { new vm.Script(code, { filename: rel }).runInContext(context, { timeout: 5000 }); }
  catch (e) { console.log(`❌ 加载失败 ${rel}: ${e.message}`); }
}

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

let passed = 0, failed = 0;
const results = [];
function test(name, fn) {
  try { fn(); passed++; results.push(`  ✅ ${name}`); }
  catch (e) { failed++; results.push(`  ❌ ${name}: ${e.message}`); }
}

function resetGameState() {
  sandbox.gameState.reset(true);
  sandbox.gameState.path = 'sword';
}

console.log('=== P1 #7 天机值 handler + 雷劫接入验证 ===\n');

test('#7a EffectService 应注册 tianji handler', () => {
  const es = new (vm.runInContext('EffectService', context))({
    gameState: sandbox.gameState,
    eventBus: vm.runInContext('eventBus', context),
    debug: false
  });
  assert.ok(es.handlers.has('tianji'), 'EffectService 应注册 tianji handler');
});

test('#7b apply({tianji: 5}) 应增加 gameState.tianji 5 点', () => {
  resetGameState();
  const es = new (vm.runInContext('EffectService', context))({
    gameState: sandbox.gameState,
    eventBus: vm.runInContext('eventBus', context),
    debug: false
  });
  const before = sandbox.gameState.getAttribute('tianji') || 0;
  es.apply({ tianji: 5 });
  const after = sandbox.gameState.getAttribute('tianji') || 0;
  assert.strictEqual(after - before, 5, `tianji 应增加 5，实际增加 ${after - before}`);
});

test('#7c apply({tianji: -10}) 应减少 gameState.tianji 10 点', () => {
  resetGameState();
  const es = new (vm.runInContext('EffectService', context))({
    gameState: sandbox.gameState,
    eventBus: vm.runInContext('eventBus', context),
    debug: false
  });
  sandbox.gameState.setAttribute('tianji', 50);
  es.apply({ tianji: -10 });
  const after = sandbox.gameState.getAttribute('tianji');
  assert.strictEqual(after, 40, `tianji 应为 40，实际 ${after}`);
});

test('#7d tianji handler 不再被静默忽略（_applySingle 走 handler 分支）', () => {
  resetGameState();
  const es = new (vm.runInContext('EffectService', context))({
    gameState: sandbox.gameState,
    eventBus: vm.runInContext('eventBus', context),
    debug: false
  });
  // 触发 apply，若 handler 未注册，tianji 不会变
  es.apply({ tianji: 15 });
  assert.strictEqual(sandbox.gameState.getAttribute('tianji'), 15, `tianji 应为 15，实际 ${sandbox.gameState.getAttribute('tianji')}`);
});

test('#7e _resolveBreakthrough 在 tianji=0 时不影响成功率', () => {
  resetGameState();
  sandbox.gameState.setAttribute('tianji', 0);
  const es = new (vm.runInContext('EffectService', context))({
    gameState: sandbox.gameState,
    eventBus: vm.runInContext('eventBus', context),
    debug: false
  });
  const cc = new (vm.runInContext('CombatCoordinator', context))({
    gameState: sandbox.gameState,
    deckCombatSystem: { active: false, _start: () => {}, reset: () => {}, enemy: null, player: null },
    effectService: es,
    cardSystem: { draw: () => ({ id: 'test', type: 'NORMAL', choices: { left: { text: 'L', effects: {} }, right: { text: 'R', effects: {} } } }), getCard: (id) => ({ id, type: 'NORMAL', choices: { left: { text: 'L', effects: {} }, right: { text: 'R', effects: {} } } }) },
    karmaSystem: null,
    callbacks: { setCurrentCard: () => {}, log: () => {}, onUpdate: () => {}, onInnerVoice: () => {}, onResolveBreakthrough: () => {} },
    debug: false
  });
  const game = new (vm.runInContext('GameLogic', context))({
    gameState: sandbox.gameState,
    eventBus: vm.runInContext('eventBus', context),
    effectService: es,
    combatCoordinator: cc,
    debug: false
  });

  // 设置境界为炼气（_advanceRealm 可推进到筑基）
  sandbox.gameState.realm = 'qi';
  sandbox.gameState.attributes.cultivation = 100;

  // 用 successRate=1.0 强制成功，验证 tianji=0 时不被惩罚
  game._resolveBreakthrough(1.0, { id: 'break_qi' });
  assert.strictEqual(sandbox.gameState.realm, 'foundation', `tianji=0 时成功率应不变，应突破到筑基，实际 ${sandbox.gameState.realm}`);
});

test('#7f _resolveBreakthrough 在 tianji=100 时显著降低成功率（强制失败）', () => {
  resetGameState();
  sandbox.gameState.setAttribute('tianji', 100);
  const es = new (vm.runInContext('EffectService', context))({
    gameState: sandbox.gameState,
    eventBus: vm.runInContext('eventBus', context),
    debug: false
  });
  const cc = new (vm.runInContext('CombatCoordinator', context))({
    gameState: sandbox.gameState,
    deckCombatSystem: { active: false, _start: () => {}, reset: () => {}, enemy: null, player: null },
    effectService: es,
    cardSystem: { draw: () => ({ id: 'test', type: 'NORMAL', choices: { left: { text: 'L', effects: {} }, right: { text: 'R', effects: {} } } }), getCard: (id) => ({ id, type: 'NORMAL', choices: { left: { text: 'L', effects: {} }, right: { text: 'R', effects: {} } } }) },
    karmaSystem: null,
    callbacks: { setCurrentCard: () => {}, log: () => {}, onUpdate: () => {}, onInnerVoice: () => {}, onResolveBreakthrough: () => {} },
    debug: false
  });
  const game = new (vm.runInContext('GameLogic', context))({
    gameState: sandbox.gameState,
    eventBus: vm.runInContext('eventBus', context),
    effectService: es,
    combatCoordinator: cc,
    debug: false
  });

  sandbox.gameState.realm = 'qi';
  sandbox.gameState.attributes.cultivation = 100;

  // 用 successRate=0.35, tianji=100: penalty=min(0.3, 70/200)=0.3, adjusted=max(0.1, 0.05)=0.1
  // 通过 stub Math.random 控制 roll=0.5 > 0.1，必然失败
  const origRandom = Math.random;
  vm.runInContext('var __origRandom = Math.random; Math.random = function() { return 0.5; };', context);

  game._resolveBreakthrough(0.35, { id: 'break_qi' });

  // 还原 Math.random
  vm.runInContext('Math.random = __origRandom;', context);

  assert.strictEqual(sandbox.gameState.realm, 'qi', `tianji=100 时 roll=0.5 应突破失败，境界应仍为 qi，实际 ${sandbox.gameState.realm}`);
});

test('#7g tianji=50 时 penalty 计算正确（(50-30)/200 = 0.1）', () => {
  resetGameState();
  sandbox.gameState.setAttribute('tianji', 50);
  const es = new (vm.runInContext('EffectService', context))({
    gameState: sandbox.gameState,
    eventBus: vm.runInContext('eventBus', context),
    debug: false
  });
  const cc = new (vm.runInContext('CombatCoordinator', context))({
    gameState: sandbox.gameState,
    deckCombatSystem: { active: false, _start: () => {}, reset: () => {}, enemy: null, player: null },
    effectService: es,
    cardSystem: { draw: () => ({ id: 'test', type: 'NORMAL', choices: { left: { text: 'L', effects: {} }, right: { text: 'R', effects: {} } } }), getCard: (id) => ({ id, type: 'NORMAL', choices: { left: { text: 'L', effects: {} }, right: { text: 'R', effects: {} } } }) },
    karmaSystem: null,
    callbacks: { setCurrentCard: () => {}, log: () => {}, onUpdate: () => {}, onInnerVoice: () => {}, onResolveBreakthrough: () => {} },
    debug: false
  });
  const game = new (vm.runInContext('GameLogic', context))({
    gameState: sandbox.gameState,
    eventBus: vm.runInContext('eventBus', context),
    effectService: es,
    combatCoordinator: cc,
    debug: false
  });

  sandbox.gameState.realm = 'qi';
  sandbox.gameState.attributes.cultivation = 100;

  // successRate=0.15, tianji=50: penalty=0.1, adjusted=max(0.1, 0.05)=0.1
  // roll=0.05 < 0.1 应成功
  vm.runInContext('var __origRandom2 = Math.random; Math.random = function() { return 0.05; };', context);
  game._resolveBreakthrough(0.15, { id: 'break_qi' });
  vm.runInContext('Math.random = __origRandom2;', context);

  assert.strictEqual(sandbox.gameState.realm, 'foundation', `tianji=50 penalty=0.1, successRate=0.15→adjusted=0.1, roll=0.05 应突破成功，实际 ${sandbox.gameState.realm}`);
});

console.log(results.join('\n'));
console.log(`\n=== 测试结果 ===`);
console.log(`  通过: ${passed}`);
console.log(`  失败: ${failed}`);
console.log(`  总计: ${passed + failed}`);
if (failed > 0) {
  console.log('\n❌ 有测试失败，请检查 #7 修复');
  process.exit(1);
} else {
  console.log('\n✅ 所有测试通过，#7 天机值修复验证成功');
}
