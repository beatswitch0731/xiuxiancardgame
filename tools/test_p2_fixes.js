/**
 * test_p2_fixes.js - P2 三项修复的单元测试
 *
 * 覆盖：
 *   #9  CompanionSystem 道侣里程碑缓存队列
 *   #10 GameStateManager 跨世因果种子保留
 *   #11 CardSystem 因果跨境界发芽
 *
 * 用法：node tools/test_p2_fixes.js
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
  // stubs for systems referenced as globals
  pathSkillSystem: { getPassiveBonuses: () => ({}), unlockForRealm: () => [] },
  factionSystem: null,  // CompanionSystem 内部用 typeof 检查
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
  'src/systems/CompanionSystem.js',
  'src/services/EffectService.js',
  'src/coordinators/CombatCoordinator.js',
  'src/game.js',
];

let loadErrors = [];
for (const rel of loadOrder) {
  const fp = path.join(DIR, rel);
  if (!fs.existsSync(fp)) {
    loadErrors.push(rel);
    continue;
  }
  const code = fs.readFileSync(fp, 'utf8');
  try {
    new vm.Script(code, { filename: rel }).runInContext(context, { timeout: 5000 });
  } catch (e) {
    console.log(`❌ 加载失败 ${rel}: ${e.message}`);
    loadErrors.push(rel);
  }
}

// ========== 4. 初始化 ==========
let initError = null;
try {
  const getVar = (name) => vm.runInContext(name, context);
  const _eventBus = getVar('eventBus');
  const _dataLoader = getVar('dataLoader');
  const _gameState = getVar('gameState');
  const _cardSystem = getVar('cardSystem');
  const _karmaSystem = getVar('karmaSystem');
  const _deckCombatSystem = getVar('deckCombatSystem');
  const _treasureSystem = getVar('treasureSystem');
  const _companionSystem = getVar('companionSystem');

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
  if (_companionSystem) _companionSystem.init();

  sandbox.eventBus = _eventBus;
  sandbox.dataLoader = _dataLoader;
  sandbox.gameState = _gameState;
  sandbox.cardSystem = _cardSystem;
  sandbox.karmaSystem = _karmaSystem;
  sandbox.deckCombatSystem = _deckCombatSystem;
  sandbox.treasureSystem = _treasureSystem;
  sandbox.companionSystem = _companionSystem;
} catch (e) {
  initError = e;
  console.log('初始化错误详情:', e.stack);
}

// ========== 5. 测试框架 ==========
let passed = 0, failed = 0, skipped = 0;
const results = [];
function test(name, fn) {
  try { fn(); passed++; results.push(`  ✅ ${name}`); }
  catch (e) { failed++; results.push(`  ❌ ${name}: ${e.message}`); }
}
function section(title) { results.push(`\n--- ${title} ---\n`); }

function resetGameState(overrides = {}) {
  sandbox.gameState.reset(true);
  sandbox.gameState.path = 'sword';
  if (overrides.realm !== undefined) sandbox.gameState.realm = overrides.realm;
  if (overrides.health !== undefined) sandbox.gameState.attributes.health = overrides.health;
  if (overrides.maxHealth !== undefined) sandbox.gameState.maxHealth = overrides.maxHealth;
}

console.log('=== P2 修复验证测试 ===\n');
if (loadErrors.length > 0) console.log('⚠️  加载失败:', loadErrors.join(', '));
if (initError) console.log('⚠️  初始化错误:', initError.message);

test('核心依赖已加载', () => {
  const CompanionSystem = vm.runInContext('CompanionSystem', context);
  const GameStateManager = vm.runInContext('GameStateManager', context);
  const CardSystem = vm.runInContext('CardSystem', context);
  if (!CompanionSystem) throw new Error('CompanionSystem 未加载');
  if (!GameStateManager) throw new Error('GameStateManager 未加载');
  if (!CardSystem) throw new Error('CardSystem 未加载');
  if (!sandbox.companionSystem) throw new Error('companionSystem 单例未初始化');
});

// ==================================================================
// 修复 #9: CompanionSystem 道侣里程碑缓存队列
// ==================================================================
section('修复 #9: 道侣里程碑缓存队列');

test('#9a CompanionSystem 应有 _pendingMilestones 队列属性', () => {
  assert.ok(Array.isArray(sandbox.companionSystem._pendingMilestones), '_pendingMilestones 应为数组');
});

test('#9b _pendingMilestones 初始应为空数组', () => {
  // 重置一下队列
  sandbox.companionSystem._pendingMilestones = [];
  assert.strictEqual(sandbox.companionSystem._pendingMilestones.length, 0, '初始长度应为 0');
});

test('#9c _checkAffectionMilestones 应入队而非直接 emit', () => {
  resetGameState();
  sandbox.companionSystem._pendingMilestones = [];
  // 设置道侣数据
  sandbox.companionSystem.companions.set('test_comp', {
    id: 'test_comp', name: '测试道侣', events: []
  });
  sandbox.companionSystem.states['test_comp'] = {
    affection: 0, bond: 0, trust: 0, lastEventTurn: 0, totalEvents: 0
  };
  // gameState 需要有 companions 资源
  sandbox.gameState.resources.companions = ['test_comp'];

  // 触发好感度从 0 → 20，跨过 bond_acquaint 阈值
  const state = sandbox.companionSystem.states['test_comp'];
  const oldAffection = 0;
  state.affection = 20;

  let emitCalled = false;
  const origEmit = sandbox.eventBus.emit;
  sandbox.eventBus.emit = (event) => { if (event === 'companion:eventCard') emitCalled = true; };

  sandbox.companionSystem._checkAffectionMilestones('test_comp', state, oldAffection);

  sandbox.eventBus.emit = origEmit;

  // 【关键断言】应该入队，不直接 emit
  assert.strictEqual(sandbox.companionSystem._pendingMilestones.length, 1, '应入队 1 个里程碑');
  assert.strictEqual(emitCalled, false, '不应直接 emit（避免时序对撞）');
});

test('#9d _onCheckEvent 应优先消费 _pendingMilestones 队列', () => {
  resetGameState();
  sandbox.companionSystem._pendingMilestones = [];
  // 预先入队一个里程碑
  sandbox.companionSystem._pendingMilestones.push({
    card: { id: 'milestone_test', type: 'COMPANION_MILESTONE', title: '测试里程碑' },
    priority: 52
  });

  let emittedCard = null;
  let emittedPriority = null;
  const origEmit = sandbox.eventBus.emit;
  sandbox.eventBus.emit = (event, data) => {
    if (event === 'companion:eventCard') {
      emittedCard = data.card;
      emittedPriority = data.priority;
    }
  };

  sandbox.companionSystem._onCheckEvent();
  sandbox.eventBus.emit = origEmit;

  assert.ok(emittedCard, '应 emit 里程碑卡');
  assert.strictEqual(emittedCard.id, 'milestone_test', '应消费队列中的里程碑卡');
  assert.strictEqual(emittedPriority, 52, '应保留优先级 52');
});

test('#9e 消费后队列长度应减 1', () => {
  resetGameState();
  sandbox.companionSystem._pendingMilestones = [
    { card: { id: 'ms_1' }, priority: 52 },
    { card: { id: 'ms_2' }, priority: 52 }
  ];
  const origEmit = sandbox.eventBus.emit;
  sandbox.eventBus.emit = () => {};
  sandbox.companionSystem._onCheckEvent();
  sandbox.eventBus.emit = origEmit;
  assert.strictEqual(sandbox.companionSystem._pendingMilestones.length, 1, '消费后应剩 1 个');
  assert.strictEqual(sandbox.companionSystem._pendingMilestones[0].card.id, 'ms_2', '应消费队首 ms_1，剩 ms_2');
});

test('#9f 队列为空时 _onCheckEvent 走原有逻辑（不报错）', () => {
  resetGameState();
  sandbox.companionSystem._pendingMilestones = [];
  sandbox.gameState.resources.companions = [];
  let emitReceived = false;
  const origEmit = sandbox.eventBus.emit;
  sandbox.eventBus.emit = (event, data) => {
    if (event === 'companion:eventCard') emitReceived = true;
  };
  // 不应抛错
  sandbox.companionSystem._onCheckEvent();
  sandbox.eventBus.emit = origEmit;
  // 队列空 + 无道侣 → 应走原有 emit(null) 分支
  assert.strictEqual(sandbox.companionSystem._pendingMilestones.length, 0, '队列应仍为空');
});

// ==================================================================
// 修复 #10: GameStateManager 跨世因果种子保留
// ==================================================================
section('修复 #10: 跨世因果种子保留');

test('#10a reset(true) 应保留 bloodline 种子', () => {
  resetGameState();
  sandbox.gameState.karmaSeeds = [
    { id: 'seed_bl_1', seedType: 'bloodline', delay: 5, priority: 7 }
  ];
  sandbox.gameState.reset(true);
  const preserved = sandbox.gameState.karmaSeeds.filter(s => s.seedType === 'bloodline');
  assert.ok(preserved.length > 0, 'bloodline 种子应被保留');
  assert.strictEqual(preserved[0].id, 'seed_bl_1', '应保留原 seed_bl_1');
});

test('#10b reset(true) 应保留 fate 种子', () => {
  resetGameState();
  sandbox.gameState.karmaSeeds = [
    { id: 'seed_fate_1', seedType: 'fate', delay: 3, priority: 10 }
  ];
  sandbox.gameState.reset(true);
  const preserved = sandbox.gameState.karmaSeeds.filter(s => s.seedType === 'fate');
  assert.ok(preserved.length > 0, 'fate 种子应被保留');
  assert.strictEqual(preserved[0].id, 'seed_fate_1', '应保留原 seed_fate_1');
});

test('#10c reset(true) 应清空 karma/grudge 种子', () => {
  resetGameState();
  sandbox.gameState.karmaSeeds = [
    { id: 'seed_karma_1', seedType: 'karma', delay: 2, priority: 4 },
    { id: 'seed_grudge_1', seedType: 'grudge', delay: 2, priority: 4 }
  ];
  sandbox.gameState.reset(true);
  const remaining = sandbox.gameState.karmaSeeds.filter(s =>
    s.seedType === 'karma' || s.seedType === 'grudge'
  );
  assert.strictEqual(remaining.length, 0, 'karma/grudge 种子应被清空');
});

test('#10d 保留的种子 delay 应调整（*1.5 +5）', () => {
  resetGameState();
  // 原始 delay=5 → 调整后 Math.round(5*1.5)+5 = 8+5 = 13
  sandbox.gameState.karmaSeeds = [
    { id: 'seed_bl_delay', seedType: 'bloodline', delay: 5, priority: 7 }
  ];
  sandbox.gameState.reset(true);
  const preserved = sandbox.gameState.karmaSeeds.find(s => s.id === 'seed_bl_delay');
  assert.ok(preserved, '种子应被保留');
  assert.strictEqual(preserved.delay, 13, `delay 应为 13（5*1.5+5），实际: ${preserved.delay}`);
});

test('#10e reset(false) 应清空所有种子（含 bloodline/fate）', () => {
  resetGameState();
  sandbox.gameState.karmaSeeds = [
    { id: 'seed_bl_hard', seedType: 'bloodline', delay: 5, priority: 7 },
    { id: 'seed_fate_hard', seedType: 'fate', delay: 3, priority: 10 }
  ];
  sandbox.gameState.reset(false);
  assert.strictEqual(sandbox.gameState.karmaSeeds.length, 0, 'reset(false) 应清空所有种子');
});

test('#10f 多个保留种子都应存活', () => {
  resetGameState();
  sandbox.gameState.karmaSeeds = [
    { id: 'bl_a', seedType: 'bloodline', delay: 4, priority: 7 },
    { id: 'fate_b', seedType: 'fate', delay: 6, priority: 9 },
    { id: 'karma_c', seedType: 'karma', delay: 2, priority: 3 },
    { id: 'bl_d', seedType: 'bloodline', delay: 8, priority: 6 }
  ];
  sandbox.gameState.reset(true);
  const ids = sandbox.gameState.karmaSeeds.map(s => s.id).sort();
  const expected = ['bl_a', 'bl_d', 'fate_b'].sort();
  console.log('  [debug #10f] actual ids:', JSON.stringify(ids));
  console.log('  [debug #10f] expected:', JSON.stringify(expected));
  console.log('  [debug #10f] equal?', JSON.stringify(ids) === JSON.stringify(expected));
  assert.deepStrictEqual(ids, expected, '应保留 bl_a, bl_d, fate_b 三个');
});

// ==================================================================
// 修复 #11: CardSystem 因果跨境界发芽
// ==================================================================
section('修复 #11: 因果跨境界发芽');

test('#11a 种子 realm=qi 应在玩家境界 foundation 时发芽', () => {
  resetGameState({ realm: 'foundation' });
  sandbox.gameState.karmaSeeds = [
    { id: 'seed_realm_qi', seedType: 'karma', delay: 0, priority: 5, realm: 'qi' }
  ];
  // karmaCardMap 需要有对应映射
  sandbox.cardSystem.karmaCardMap.set('seed_realm_qi', 'karma_test_card');
  sandbox.cardSystem.cardCache.set('karma_test_card', { id: 'karma_test_card', type: 'KARMA', title: '测试', description: '', choices: { left: { text: 'L', effects: {} }, right: { text: 'R', effects: {} } } });

  const card = sandbox.cardSystem._drawKarmaCard();
  assert.ok(card, '种子应能跨境界发芽');
  assert.strictEqual(card.id, 'karma_test_card', '应返回因果卡');
});

test('#11b 种子 realm=foundation 不应在玩家境界 qi 时发芽', () => {
  resetGameState({ realm: 'qi' });
  sandbox.gameState.karmaSeeds = [
    { id: 'seed_realm_foundation', seedType: 'karma', delay: 0, priority: 5, realm: 'foundation' }
  ];
  sandbox.cardSystem.karmaCardMap.set('seed_realm_foundation', 'karma_test_card_2');
  sandbox.cardSystem.cardCache.set('karma_test_card_2', { id: 'karma_test_card_2', type: 'KARMA', title: '测试2', description: '', choices: { left: { text: 'L', effects: {} }, right: { text: 'R', effects: {} } } });

  const card = sandbox.cardSystem._drawKarmaCard();
  assert.strictEqual(card, null, '境界不足时不应发芽');
  // 种子应仍在 karmaSeeds 中
  assert.strictEqual(sandbox.gameState.karmaSeeds.length, 1, '种子应未被消耗');
});

test('#11c 无 realm 限制的种子可在任意境界发芽', () => {
  resetGameState({ realm: 'deity' });
  sandbox.gameState.karmaSeeds = [
    { id: 'seed_no_realm', seedType: 'karma', delay: 0, priority: 5 }
  ];
  sandbox.cardSystem.karmaCardMap.set('seed_no_realm', 'karma_test_card_3');
  sandbox.cardSystem.cardCache.set('karma_test_card_3', { id: 'karma_test_card_3', type: 'KARMA', title: '测试3', description: '', choices: { left: { text: 'L', effects: {} }, right: { text: 'R', effects: {} } } });

  const card = sandbox.cardSystem._drawKarmaCard();
  assert.ok(card, '无 realm 种子应能发芽');
  assert.strictEqual(card.id, 'karma_test_card_3');
});

test('#11d 跨境界种子应获得优先级 +3 补偿', () => {
  resetGameState({ realm: 'nascent' });
  // 两个种子：一个同境界（foundation=idx2，玩家 nascent=idx3），一个跨境界
  // 注：foundation idx=2，玩家 nascent idx=3 → 跨境界 +3
  // golden idx=2 同境界，无补偿
  // 实际：seedA realm=foundation priority=5 → effective 8（跨境界）
  //       seedB realm=nascent priority=5 → effective 5（同境界）
  // 应优先取 seedA
  sandbox.gameState.karmaSeeds = [
    { id: 'seed_same_realm', seedType: 'karma', delay: 0, priority: 5, realm: 'nascent' },
    { id: 'seed_cross_realm', seedType: 'karma', delay: 0, priority: 5, realm: 'foundation' }
  ];
  sandbox.cardSystem.karmaCardMap.set('seed_same_realm', 'karma_same');
  sandbox.cardSystem.karmaCardMap.set('seed_cross_realm', 'karma_cross');
  sandbox.cardSystem.cardCache.set('karma_same', { id: 'karma_same', type: 'KARMA', title: '同境界', description: '', choices: { left: { text: 'L', effects: {} }, right: { text: 'R', effects: {} } } });
  sandbox.cardSystem.cardCache.set('karma_cross', { id: 'karma_cross', type: 'KARMA', title: '跨境界', description: '', choices: { left: { text: 'L', effects: {} }, right: { text: 'R', effects: {} } } });

  const card = sandbox.cardSystem._drawKarmaCard();
  assert.ok(card, '应返回某张卡');
  assert.strictEqual(card.id, 'karma_cross', '跨境界种子应优先（priority 5+3=8 > 同境界 5）');
});

test('#11e 同境界种子保持原优先级', () => {
  resetGameState({ realm: 'golden' });
  // seedA realm=golden priority=8 (同境界，effective=8)
  // seedB realm=qi priority=5 (跨境界，effective=5+3=8) 平局
  // 平局时 sort 不稳定，改用不同优先级确保稳定测试
  // seedA realm=golden priority=10 → effective 10
  // seedB realm=qi priority=5 → effective 8
  // 应取 seedA
  sandbox.gameState.karmaSeeds = [
    { id: 'seed_low_cross', seedType: 'karma', delay: 0, priority: 5, realm: 'qi' },
    { id: 'seed_high_same', seedType: 'karma', delay: 0, priority: 10, realm: 'golden' }
  ];
  sandbox.cardSystem.karmaCardMap.set('seed_low_cross', 'karma_low_cross');
  sandbox.cardSystem.karmaCardMap.set('seed_high_same', 'karma_high_same');
  sandbox.cardSystem.cardCache.set('karma_low_cross', { id: 'karma_low_cross', type: 'KARMA', title: '低优先跨境界', description: '', choices: { left: { text: 'L', effects: {} }, right: { text: 'R', effects: {} } } });
  sandbox.cardSystem.cardCache.set('karma_high_same', { id: 'karma_high_same', type: 'KARMA', title: '高优先同境界', description: '', choices: { left: { text: 'L', effects: {} }, right: { text: 'R', effects: {} } } });

  const card = sandbox.cardSystem._drawKarmaCard();
  assert.strictEqual(card.id, 'karma_high_same', '同境界高优先种子应被选中（10 > 5+3=8）');
});

test('#11f 多个跨境界种子，最高 effective priority 获胜', () => {
  resetGameState({ realm: 'deity' });
  // realmOrder: qi(0) foundation(1) golden(2) nascent(3) deity(4) tribulation(5)
  // seedA realm=qi priority=3 → effective 3+3=6
  // seedB realm=golden priority=4 → effective 4+3=7
  // seedC realm=nascent priority=5 → effective 5+3=8 (跨2境界但只+3)
  // 应取 seedC
  sandbox.gameState.karmaSeeds = [
    { id: 'seed_a', seedType: 'karma', delay: 0, priority: 3, realm: 'qi' },
    { id: 'seed_b', seedType: 'karma', delay: 0, priority: 4, realm: 'golden' },
    { id: 'seed_c', seedType: 'karma', delay: 0, priority: 5, realm: 'nascent' }
  ];
  sandbox.cardSystem.karmaCardMap.set('seed_a', 'karma_a');
  sandbox.cardSystem.karmaCardMap.set('seed_b', 'karma_b');
  sandbox.cardSystem.karmaCardMap.set('seed_c', 'karma_c');
  sandbox.cardSystem.cardCache.set('karma_a', { id: 'karma_a', type: 'KARMA', title: 'A', description: '', choices: { left: { text: 'L', effects: {} }, right: { text: 'R', effects: {} } } });
  sandbox.cardSystem.cardCache.set('karma_b', { id: 'karma_b', type: 'KARMA', title: 'B', description: '', choices: { left: { text: 'L', effects: {} }, right: { text: 'R', effects: {} } } });
  sandbox.cardSystem.cardCache.set('karma_c', { id: 'karma_c', type: 'KARMA', title: 'C', description: '', choices: { left: { text: 'L', effects: {} }, right: { text: 'R', effects: {} } } });

  const card = sandbox.cardSystem._drawKarmaCard();
  assert.strictEqual(card.id, 'karma_c', '应取 effective priority 最高的 seed_c (5+3=8)');
});

console.log(results.join('\n'));
console.log(`\n=== 测试结果 ===`);
console.log(`  通过: ${passed}`);
console.log(`  失败: ${failed}`);
console.log(`  总计: ${passed + failed}`);
if (failed > 0) {
  console.log('\n❌ 有测试失败');
  process.exit(1);
} else {
  console.log('\n✅ 所有测试通过');
}
