/**
 * test_p1_fixes.js - P1 修复的单元测试
 *
 * 覆盖：
 *   #5 DeckCombatSystem 法宝战斗被动挂载（atk/def/critRate）
 *   #8 game._advanceRealm 突破后寿元增长（lifespanBonus 读取）
 *
 * 注意：本测试需在 P1 #5 和 #8 修复前运行一次（应失败），
 *      修复后再运行（应通过），以验证测试有效性。
 *
 * 用法：node tools/test_p1_fixes.js
 */
const fs = require('fs');
const path = require('path');
const vm = require('vm');
const assert = require('assert');

const DIR = path.join(__dirname, '..');

// ========== 1. 加载 JSON ==========
function loadJson(relPath) {
  const fp = path.join(DIR, relPath);
  if (!fs.existsSync(fp)) return null;
  try { return JSON.parse(fs.readFileSync(fp, 'utf8')); }
  catch (e) { console.log(`⚠️  JSON 解析失败 ${relPath}:`, e.message); return null; }
}

const DATA_MODULES = {
  'config:realms': loadJson('data/config/realms.json'),
  'config:paths': loadJson('data/config/paths.json'),
  'config:path_skills': loadJson('data/config/path_skills.json'),
  'cards:qi': loadJson('data/cards/qi.json'),
  'cards:battle_cards': loadJson('data/cards/battle_cards.json'),
  'cards:karma': loadJson('data/cards/karma.json'),
  'shops:treasures': loadJson('data/shops/treasures.json'),
  'shops:shop_items': loadJson('data/shops/shop_items.json'),
};

// ========== 2. 沙箱上下文 ==========
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
  'src/systems/TreasureSystem.js',
  'src/systems/PathSkillSystem.js',
  'src/systems/DeckCombatSystem.js',
  'src/services/EffectService.js',
  'src/coordinators/CombatCoordinator.js',
  'src/game.js',
];

for (const rel of loadOrder) {
  const fp = path.join(DIR, rel);
  if (!fs.existsSync(fp)) { console.log(`⚠️  文件不存在: ${rel}`); continue; }
  const code = fs.readFileSync(fp, 'utf8');
  try { new vm.Script(code, { filename: rel }).runInContext(context, { timeout: 5000 }); }
  catch (e) { console.log(`❌ 加载失败 ${rel}: ${e.message}`); }
}

// ========== 4. 初始化系统 ==========
try {
  const getVar = (name) => vm.runInContext(name, context);
  const _dataLoader = getVar('dataLoader');
  const _gameState = getVar('gameState');
  const _cardSystem = getVar('cardSystem');
  const _karmaSystem = getVar('karmaSystem');
  const _deckCombatSystem = getVar('deckCombatSystem');
  const _treasureSystem = getVar('treasureSystem');

  for (const [key, val] of Object.entries(DATA_MODULES)) {
    if (val) _dataLoader.cache.set(key, val);
  }
  _gameState.init({ realms: DATA_MODULES['config:realms'], paths: DATA_MODULES['config:paths'] });
  _gameState.path = 'sword';
  _cardSystem.init(DATA_MODULES);
  _karmaSystem.init(DATA_MODULES['cards:karma'] || {});
  _deckCombatSystem.init({ battleCards: DATA_MODULES['cards:battle_cards'] });
  _treasureSystem.init(DATA_MODULES['shops:treasures']);

  sandbox.eventBus = getVar('eventBus');
  sandbox.dataLoader = _dataLoader;
  sandbox.gameState = _gameState;
  sandbox.cardSystem = _cardSystem;
  sandbox.karmaSystem = _karmaSystem;
  sandbox.deckCombatSystem = _deckCombatSystem;
  sandbox.treasureSystem = _treasureSystem;
  sandbox.pathSkillSystem = getVar('pathSkillSystem');
} catch (e) {
  console.log('⚠️  系统初始化错误:', e.message, e.stack);
}

// ========== 5. 测试框架 ==========
let passed = 0, failed = 0;

async function test(name, fn) {
  try {
    await fn();
    passed++;
    console.log(`  ✅ ${name}`);
  } catch (e) {
    failed++;
    console.log(`  ❌ ${name}: ${e.message}`);
  }
}

function section(t) { console.log(`\n--- ${t} ---\n`); }

// ========== 6. 辅助函数 ==========
function resetGameState(overrides = {}) {
  sandbox.gameState.reset(true);
  sandbox.gameState.path = 'sword';
  if (overrides.health !== undefined) sandbox.gameState.attributes.health = overrides.health;
  if (overrides.maxHealth !== undefined) sandbox.gameState.maxHealth = overrides.maxHealth;
  if (overrides.daoHeart !== undefined) sandbox.gameState.attributes.daoHeart = overrides.daoHeart;
  if (overrides.cultivation !== undefined) sandbox.gameState.attributes.cultivation = overrides.cultivation;
  if (overrides.lifespan !== undefined) sandbox.gameState.resources.lifespan = overrides.lifespan;
  if (overrides.spiritStone !== undefined) sandbox.gameState.resources.spiritStone = overrides.spiritStone;
}

function getGameInstance() {
  const EffectService = vm.runInContext('EffectService', context);
  const GameLogic = vm.runInContext('GameLogic', context);
  const CombatCoordinator = vm.runInContext('CombatCoordinator', context);
  const es = new EffectService({ gameState: sandbox.gameState, eventBus: sandbox.eventBus, debug: false });
  const cc = new CombatCoordinator({
    gameState: sandbox.gameState,
    deckCombatSystem: sandbox.deckCombatSystem,
    effectService: es,
    cardSystem: sandbox.cardSystem,
    karmaSystem: sandbox.karmaSystem,
    callbacks: { setCurrentCard: () => {}, log: () => {}, onUpdate: () => {}, onInnerVoice: () => {}, onResolveBreakthrough: () => {} },
    debug: false
  });
  return new GameLogic({ gameState: sandbox.gameState, eventBus: sandbox.eventBus, effectService: es, combatCoordinator: cc, debug: false });
}

async function startCombatWithTreasure(treasureId, slot) {
  resetGameState({ health: 3, maxHealth: 3 });
  sandbox.treasureSystem.equipped = { weapon: null, armor: null, accessory: null, artifact: null };
  if (treasureId) {
    sandbox.treasureSystem.owned.add(treasureId);
    sandbox.gameState.treasureInventory = [treasureId];
    sandbox.treasureSystem.equip(treasureId, slot);
  }
  sandbox.deckCombatSystem.reset();
  const card = { id: 'test_combat', type: 'COMBAT', enemy: { id: 'enemy_normal', name: '测试妖兽', tier: 1 } };
  await sandbox.deckCombatSystem._start({ card });
}

// ========== 7. 主流程 ==========
async function run() {
  console.log('=== P1 修复验证测试 ===\n');
  console.log('（含 #5 法宝战斗被动 + #8 寿元增长）\n');

  // =====================================================================
  // 修复 #5: DeckCombatSystem 法宝战斗被动挂载
  // =====================================================================
  section('修复 #5: 法宝战斗被动挂载');

  await test('#5a 装备剑心佩后 player.atkMod 应为 2', async () => {
    await startCombatWithTreasure('剑心佩', 'weapon');
    assert.strictEqual(sandbox.deckCombatSystem.player.atkMod, 2, `atkMod 应为 2，实际: ${sandbox.deckCombatSystem.player.atkMod}`);
  });

  await test('#5b 装备玄铁甲后 player.defMod 应为 1', async () => {
    await startCombatWithTreasure('玄铁甲', 'armor');
    assert.strictEqual(sandbox.deckCombatSystem.player.defMod, 1, `defMod 应为 1，实际: ${sandbox.deckCombatSystem.player.defMod}`);
  });

  await test('#5c 装备剑心佩后 player.critRate 应为 5', async () => {
    await startCombatWithTreasure('剑心佩', 'weapon');
    assert.strictEqual(sandbox.deckCombatSystem.player.critRate, 5, `critRate 应为 5，实际: ${sandbox.deckCombatSystem.player.critRate}`);
  });

  await test('#5d 未装备法宝时 atkMod/defMod/critRate 应为 0', async () => {
    await startCombatWithTreasure(null);
    assert.strictEqual(sandbox.deckCombatSystem.player.atkMod, 0);
    assert.strictEqual(sandbox.deckCombatSystem.player.defMod, 0);
    assert.strictEqual(sandbox.deckCombatSystem.player.critRate, 0);
  });

  await test('#5e 玩家攻击时 dmg 应包含 atkMod', async () => {
    await startCombatWithTreasure('剑心佩', 'weapon');
    const enemyHpBefore = sandbox.deckCombatSystem.enemy.hp;
    sandbox.deckCombatSystem._dealDamage(sandbox.deckCombatSystem.enemy, 1);
    const actualDmg = enemyHpBefore - sandbox.deckCombatSystem.enemy.hp;
    assert.ok(actualDmg >= 3, `玩家攻击伤害应 >= 3（1+atkMod2），实际: ${actualDmg}`);
  });

  await test('#5f 玩家受击时 dmg 应被 defMod 减伤', async () => {
    await startCombatWithTreasure('玄铁甲', 'armor');
    const playerHpBefore = sandbox.deckCombatSystem.player.hp;
    sandbox.deckCombatSystem._dealDamage(sandbox.deckCombatSystem.player, 3);
    const actualDmg = playerHpBefore - sandbox.deckCombatSystem.player.hp;
    assert.strictEqual(actualDmg, 2, `受击 3 减伤 1 后应扣 2，实际扣: ${actualDmg}`);
  });

  // =====================================================================
  // 修复 #8: _advanceRealm 突破后寿元增长
  // =====================================================================
  section('修复 #8: 突破寿元增长');

  await test('#8a 从炼气突破到筑基后 lifespan 应增加 5', async () => {
    resetGameState({ health: 3, maxHealth: 3, lifespan: 80, cultivation: 100 });
    sandbox.gameState.realm = 'qi';
    const before = sandbox.gameState.resources.lifespan;
    const game = getGameInstance();
    game._advanceRealm();
    const delta = sandbox.gameState.resources.lifespan - before;
    assert.strictEqual(delta, 5, `突破到筑基应增加 5 寿元，实际增加: ${delta}`);
  });

  await test('#8b 从筑基突破到金丹后 lifespan 应增加 8', async () => {
    resetGameState({ health: 3, maxHealth: 3, lifespan: 80, cultivation: 100 });
    sandbox.gameState.realm = 'foundation';
    const before = sandbox.gameState.resources.lifespan;
    const game = getGameInstance();
    game._advanceRealm();
    const delta = sandbox.gameState.resources.lifespan - before;
    assert.strictEqual(delta, 8, `突破到金丹应增加 8 寿元，实际增加: ${delta}`);
  });

  await test('#8c 从金丹突破到元婴后 lifespan 应增加 12', async () => {
    resetGameState({ health: 3, maxHealth: 3, lifespan: 80, cultivation: 100 });
    sandbox.gameState.realm = 'golden';
    const before = sandbox.gameState.resources.lifespan;
    const game = getGameInstance();
    game._advanceRealm();
    const delta = sandbox.gameState.resources.lifespan - before;
    assert.strictEqual(delta, 12, `突破到元婴应增加 12 寿元，实际增加: ${delta}`);
  });

  await test('#8d 从元婴突破到化神后 lifespan 应增加 20', async () => {
    resetGameState({ health: 3, maxHealth: 3, lifespan: 80, cultivation: 100 });
    sandbox.gameState.realm = 'nascent';
    const before = sandbox.gameState.resources.lifespan;
    const game = getGameInstance();
    game._advanceRealm();
    const delta = sandbox.gameState.resources.lifespan - before;
    assert.strictEqual(delta, 20, `突破到化神应增加 20 寿元，实际增加: ${delta}`);
  });

  await test('#8e 从化神突破到渡劫后 lifespan 应增加 30', async () => {
    resetGameState({ health: 3, maxHealth: 3, lifespan: 80, cultivation: 100 });
    sandbox.gameState.realm = 'deity';
    const before = sandbox.gameState.resources.lifespan;
    const game = getGameInstance();
    game._advanceRealm();
    const delta = sandbox.gameState.resources.lifespan - before;
    assert.strictEqual(delta, 30, `突破到渡劫应增加 30 寿元，实际增加: ${delta}`);
  });

  await test('#8f realms.json 的 lifespanBonus 应为微数值', async () => {
    const realms = DATA_MODULES['config:realms'];
    if (!realms || !realms.realms) throw new Error('realms.json 未加载');
    const expected = { qi: 0, foundation: 5, golden: 8, nascent: 12, deity: 20, tribulation: 30 };
    for (const [realm, expectedBonus] of Object.entries(expected)) {
      const actual = realms.realms[realm] && realms.realms[realm].lifespanBonus;
      assert.strictEqual(actual, expectedBonus, `${realm}.lifespanBonus 应为 ${expectedBonus}，实际: ${actual}`);
    }
  });

  await test('#8g 突破后 realm 应正确切换', async () => {
    resetGameState({ health: 3, maxHealth: 3, lifespan: 80, cultivation: 100 });
    sandbox.gameState.realm = 'qi';
    const game = getGameInstance();
    game._advanceRealm();
    assert.strictEqual(sandbox.gameState.realm, 'foundation', `突破后 realm 应为 foundation，实际: ${sandbox.gameState.realm}`);
  });

  await test('#8h 渡劫突破后触发飞升结局（不再增加寿元）', async () => {
    resetGameState({ health: 3, maxHealth: 3, lifespan: 80, cultivation: 100 });
    sandbox.gameState.realm = 'tribulation';
    const before = sandbox.gameState.resources.lifespan;
    const game = getGameInstance();
    game._advanceRealm();
    // 渡劫是最后一境界，应触发飞升结局 dead=true
    assert.strictEqual(sandbox.gameState.dead, true, '渡劫突破后应触发飞升结局 dead=true');
    // 寿元不应减少
    assert.ok(sandbox.gameState.resources.lifespan >= before, `渡劫后寿元不应减少，before=${before}, after=${sandbox.gameState.resources.lifespan}`);
  });

  console.log(`\n=== 测试结果 ===`);
  console.log(`  通过: ${passed}`);
  console.log(`  失败: ${failed}`);
  console.log(`  总计: ${passed + failed}`);

  if (failed > 0) {
    console.log('\n❌ 有测试失败，请检查修复是否正确应用');
    process.exit(1);
  } else {
    console.log('\n✅ 全部测试通过，修复无回归');
    process.exit(0);
  }
}

run().catch(e => {
  console.log('❌ 测试运行错误:', e);
  process.exit(1);
});
