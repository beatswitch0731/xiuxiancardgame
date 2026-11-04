/**
 * test_p0_phase2_fixes.js - P0 四项修复的单元测试
 *
 * 覆盖：
 *   #1 CombatCoordinator._handleDeath 战斗状态解锁
 *   #2 EffectService.ending + game.makeChoice 飞升结局保护
 *   #3 CombatCoordinator.onDefeat 战败扣血微数值对齐
 *   #4 game.makeChoice costCheck 双重扣费 + UI 返回值捕获
 *
 * 用法：node tools/test_p0_phase2_fixes.js
 */
const fs = require('fs');
const path = require('path');
const vm = require('vm');
const assert = require('assert');

const DIR = path.join(__dirname, '..');

// ========== 1. 直接从 data/ 目录加载 JSON 文件 ==========
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
  'cards:foundesation': loadJson('data/cards/foundation.json'),
  'cards:battle_cards': loadJson('data/cards/battle_cards.json'),
  'cards:karma': loadJson('data/cards/karma.json'),
  'cards:chapter_milestones': loadJson('data/cards/chapter_milestones.json'),
  'world:truth_atlas': loadJson('data/world/truth_atlas.json'),
  'shops:treasures': loadJson('data/shops/treasures.json'),
  'shops:shop_items': loadJson('data/shops/shop_items.json'),
};

// ========== 2. 创建共享上下文 ==========
// 注意：const 声明的变量在 vm 上下文中不会挂载到 context 对象
// 需要在加载脚本后用 runInContext 显式获取
const sandbox = {
  console, setTimeout, setInterval, clearTimeout, clearInterval,
  Math, Date, Array, Object, String, Number, Boolean, JSON,
  parseInt, parseFloat, isNaN, isFinite, NaN, Infinity, undefined,
  Error, TypeError, RangeError,
  Map, Set, WeakMap, WeakSet, Symbol, Promise, Reflect,
  DATA_MODULES,
  // DOM mock（game.js 可能引用 document/window）
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
  'src/services/EndingEligibilityService.js',
  'src/services/EffectService.js',
  'src/coordinators/CombatCoordinator.js',
  'src/game.js',
];

let loadErrors = [];
for (const rel of loadOrder) {
  const fp = path.join(DIR, rel);
  if (!fs.existsSync(fp)) {
    console.log(`⚠️  文件不存在: ${rel}`);
    loadErrors.push(rel);
    continue;
  }
  const code = fs.readFileSync(fp, 'utf8');
  try {
    const script = new vm.Script(code, { filename: rel });
    script.runInContext(context, { timeout: 5000 });
  } catch (e) {
    console.log(`❌ 加载失败 ${rel}: ${e.message}`);
    loadErrors.push(rel);
  }
}

// ========== 4. 从上下文获取 const 变量并初始化系统 ==========
let initError = null;
try {
  // const 变量需要通过 runInContext 获取
  const getVar = (name) => vm.runInContext(name, context);
  const _eventBus = getVar('eventBus');
  const _dataLoader = getVar('dataLoader');
  const _gameState = getVar('gameState');
  const _cardSystem = getVar('cardSystem');
  const _karmaSystem = getVar('karmaSystem');
  const _deckCombatSystem = getVar('deckCombatSystem');

  // DataLoader 没有 setData，通过预填充 cache 来模拟数据加载
  if (_dataLoader) {
    for (const [key, val] of Object.entries(DATA_MODULES)) {
      if (val) _dataLoader.cache.set(key, val);
    }
  }
  const realmsConfig = DATA_MODULES['config:realms'] || null;
  const pathsConfig = DATA_MODULES['config:paths'] || null;
  if (_gameState) _gameState.init({ realms: realmsConfig, paths: pathsConfig });
  if (_gameState) _gameState.path = 'sword';
  if (_cardSystem) _cardSystem.init(DATA_MODULES);
  if (_karmaSystem) _karmaSystem.init(DATA_MODULES['cards:karma'] || {});
  if (_deckCombatSystem) _deckCombatSystem.init({ battleCards: DATA_MODULES['cards:battle_cards'] || {} });

  // 挂载到 sandbox 供后续测试使用
  sandbox.eventBus = _eventBus;
  sandbox.dataLoader = _dataLoader;
  sandbox.gameState = _gameState;
  sandbox.cardSystem = _cardSystem;
  sandbox.karmaSystem = _karmaSystem;
  sandbox.deckCombatSystem = _deckCombatSystem;
} catch (e) {
  initError = e;
  console.log('初始化错误详情:', e.stack);
}

// ========== 5. 测试框架 ==========
let passed = 0, failed = 0, skipped = 0;
const results = [];

function test(name, fn) {
  try {
    fn();
    passed++;
    results.push(`  ✅ ${name}`);
  } catch (e) {
    failed++;
    results.push(`  ❌ ${name}: ${e.message}`);
  }
}

function skip(name, reason) {
  skipped++;
  results.push(`  ⏭️  ${name} (跳过: ${reason})`);
}

function section(title) {
  results.push(`\n--- ${title} ---\n`);
}

// ========== 6. 辅助函数 ==========
/**
 * 创建一个带 mock 依赖的 CombatCoordinator 实例
 */
function createCombatCoordinator(overrides = {}) {
  const gs = overrides.gameState || sandbox.gameState;
  const mockDeck = overrides.deckCombatSystem || {
    active: false,
    _start: () => {},
    reset: () => {},
    enemy: null,
    player: null
  };
  const mockCard = overrides.cardSystem || {
    draw: () => ({ id: 'test_card', type: 'NORMAL', title: '测试', description: '', choices: { left: { text: 'L', effects: {} }, right: { text: 'R', effects: {} } } }),
    getCard: (id) => ({ id, type: 'NORMAL', title: '测试', description: '', choices: { left: { text: 'L', effects: {} }, right: { text: 'R', effects: {} } } })
  };
  return new (vm.runInContext('CombatCoordinator', context))({
    gameState: gs,
    deckCombatSystem: mockDeck,
    effectService: overrides.effectService || null,
    cardSystem: mockCard,
    karmaSystem: overrides.karmaSystem || null,
    callbacks: overrides.callbacks || {
      setCurrentCard: () => {},
      log: () => {},
      onUpdate: () => {},
      onInnerVoice: () => {},
      onResolveBreakthrough: () => {}
    },
    debug: false
  });
}

/**
 * 重置 gameState 到干净状态
 */
function resetGameState(overrides = {}) {
  sandbox.gameState.reset(true);
  sandbox.gameState.path = 'sword';
  if (overrides.health !== undefined) sandbox.gameState.attributes.health = overrides.health;
  if (overrides.daoHeart !== undefined) sandbox.gameState.attributes.daoHeart = overrides.daoHeart;
  if (overrides.spiritStone !== undefined) sandbox.gameState.resources.spiritStone = overrides.spiritStone;
  if (overrides.maxHealth !== undefined) sandbox.gameState.maxHealth = overrides.maxHealth;
}

function settleDefeat(cc, data) {
  // 每次调用代表一次新的真实战斗；协调器只允许 active 战斗首次结算。
  cc._inCombat = true;
  return cc.onDefeat(data);
}

let terminalSequence = 0;
function createTerminalEndingRuntime({ beginVictory = true } = {}) {
  resetGameState();
  const state = sandbox.gameState;
  state.realm = 'tribulation';
  state.turn = 88;
  state.attributes.cultivation = 100;
  const EndingEligibilityService = vm.runInContext('EndingEligibilityService', context);
  const endingEligibilityService = new EndingEligibilityService();
  endingEligibilityService.init(DATA_MODULES['world:truth_atlas']);
  const effectService = new (vm.runInContext('EffectService', context))({
    gameState: state,
    eventBus: sandbox.eventBus,
    endingEligibilityService,
    debug: false
  });
  if (beginVictory) {
    terminalSequence += 1;
    const encounterInstanceId = `enc:p0:${terminalSequence}`;
    state.beginTerminalVictory({
      gateId: 'tribulation_finale',
      encounterId: 'ch_tribulation_100',
      encounterInstanceId,
      victoryToken: `victory:${encounterInstanceId}`,
      outcome: 'victory'
    });
  }
  return { state, effectService, endingEligibilityService };
}

// ========== 7. 开始测试 ==========

console.log('=== P0 Phase 2 修复验证测试 ===\n');

if (loadErrors.length > 0) {
  console.log('⚠️  加载失败的文件:', loadErrors.join(', '));
}
if (initError) {
  console.log('⚠️  系统初始化错误:', initError.message);
}

// 检查核心依赖
test('核心依赖已加载 (CombatCoordinator/EffectService/GameLogic)', () => {
  const CombatCoordinator = vm.runInContext('CombatCoordinator', context);
  const EffectService = vm.runInContext('EffectService', context);
  const GameLogic = vm.runInContext('GameLogic', context);
  if (!CombatCoordinator) throw new Error('CombatCoordinator class 未加载');
  if (!EffectService) throw new Error('EffectService class 未加载');
  if (!GameLogic) throw new Error('GameLogic class 未加载');
  if (!sandbox.gameState) throw new Error('gameState 未初始化');
});

// ==================================================================
// 修复 #1: CombatCoordinator._handleDeath 战斗状态解锁
// ==================================================================
section('修复 #1: _handleDeath 战斗状态解锁');

test('#1a _handleDeath 后 _inCombat 应为 false', () => {
  resetGameState({ health: 0 });
  const cc = createCombatCoordinator();
  // 模拟战斗中状态
  cc._inCombat = true;
  cc._combatWarningShown = true;
  cc._pendingCombatCard = { id: 'fake_combat' };
  // 触发死亡
  cc.gameState.dead = true;
  cc.gameState.deadReason = '测试死亡';
  cc._handleDeath();
  // 验证战斗锁已解开
  assert.strictEqual(cc._inCombat, false, '_inCombat 应为 false');
});

test('#1b _handleDeath 后 _combatWarningShown 应为 false', () => {
  resetGameState({ health: 0 });
  const cc = createCombatCoordinator();
  cc._inCombat = true;
  cc._combatWarningShown = true;
  cc.gameState.dead = true;
  cc._handleDeath();
  assert.strictEqual(cc._combatWarningShown, false, '_combatWarningShown 应为 false');
});

test('#1c _handleDeath 后 _pendingCombatCard 应为 null', () => {
  resetGameState({ health: 0 });
  const cc = createCombatCoordinator();
  cc._inCombat = true;
  cc._pendingCombatCard = { id: 'fake_combat' };
  cc.gameState.dead = true;
  cc._handleDeath();
  assert.strictEqual(cc._pendingCombatCard, null, '_pendingCombatCard 应为 null');
});

test('#1d _handleDeath 后 isInCombat() 返回 false', () => {
  resetGameState({ health: 0 });
  const cc = createCombatCoordinator();
  cc._inCombat = true;
  cc.gameState.dead = true;
  cc._handleDeath();
  assert.strictEqual(cc.isInCombat(), false, 'isInCombat() 应返回 false');
});

test('#1e _handleDeath 调用 callbacks.setCurrentCard', () => {
  resetGameState({ health: 0 });
  let setCardCalled = false;
  const cc = createCombatCoordinator({
    callbacks: {
      setCurrentCard: (card) => { setCardCalled = true; },
      log: () => {}, onUpdate: () => {}, onInnerVoice: () => {}, onResolveBreakthrough: () => {}
    }
  });
  cc._inCombat = true;
  cc.gameState.dead = true;
  cc._handleDeath();
  assert.strictEqual(setCardCalled, true, 'setCurrentCard 应被调用');
});

// ==================================================================
// 修复 #2: EffectService.ending + game.makeChoice 终局门禁
// ==================================================================
section('修复 #2: 最终 Boss 凭证与 EPILOGUE 终局协议');

test('#2a 没有最终 Boss 胜利凭证时 ending 必须失败关闭', () => {
  const runtime = createTerminalEndingRuntime({ beginVictory: false });
  runtime.effectService.apply({ ending: 'ascension' });
  assert.strictEqual(runtime.state.endingId, null, '无凭证不得写入 endingId');
  assert.strictEqual(runtime.state.lifePhase, 'ALIVE', '无凭证不得进入 EPILOGUE');
  assert.strictEqual(runtime.state.hasFlag('game_ended'), false, '无凭证不得设置 game_ended');
});

test('#2b 合法 ending 进入 EPILOGUE 且不伪装成普通死亡', () => {
  const runtime = createTerminalEndingRuntime();
  runtime.effectService.apply({ ending: 'ascension' }, { terminalContext: runtime.state.getTerminalContext() });
  assert.strictEqual(runtime.state.lifePhase, 'EPILOGUE', '合法结局应进入 EPILOGUE');
  assert.strictEqual(runtime.state.dead, false, '结局不是普通死亡，dead 应保持 false');
});

test('#2c 合法 ending 持久化 endingId 与对应尾声卡', () => {
  const runtime = createTerminalEndingRuntime();
  runtime.effectService.apply({ ending: 'ascension' }, { terminalContext: runtime.state.getTerminalContext() });
  assert.strictEqual(runtime.state.endingId, 'ascension', 'endingId 应为 ascension');
  assert.strictEqual(runtime.state.pendingCardId, 'ending_ascension', '应挂起对应结局卡');
  assert.strictEqual(runtime.state.getTerminalContext().stage, 'EPILOGUE', '终局阶段应推进到 EPILOGUE');
});

test('#2d 合法 ending 应且只应在提交后 emit game:ending', () => {
  const runtime = createTerminalEndingRuntime();
  let emitReceived = null;
  sandbox.eventBus.on('game:ending', (data) => { emitReceived = data; });
  runtime.effectService.apply({ ending: 'ascension' }, { terminalContext: runtime.state.getTerminalContext() });
  assert.ok(emitReceived, 'game:ending 事件应被 emit');
  assert.strictEqual(emitReceived.endingType, 'ascension', 'endingType 应为 ascension');
});

test('#2e 结局卡明确选择 reincarnate 后应进入下一世', () => {
  const runtime = createTerminalEndingRuntime();
  runtime.effectService.apply({ ending: 'ascension' }, { terminalContext: runtime.state.getTerminalContext() });
  const cc = createCombatCoordinator({ effectService: runtime.effectService });
  const game = new (vm.runInContext('GameLogic', context))({
    gameState: runtime.state,
    eventBus: sandbox.eventBus,
    effectService: runtime.effectService,
    endingEligibilityService: runtime.endingEligibilityService,
    combatCoordinator: cc,
    debug: false
  });
  assert.strictEqual(runtime.state.lifePhase, 'EPILOGUE', '前置: 应处于 EPILOGUE');

  // 设置当前卡为结局卡
  game.currentCard = {
    id: 'ending_ascension',
    type: 'ENDING',
    title: '飞升',
    description: '你飞升了',
    choices: {
      left: { text: '继续', effects: { reincarnate: true } }
    }
  };

  const lifeBefore = runtime.state.getLifeCount();

  // 尝试 makeChoice
  const result = game.makeChoice('left');

  assert.strictEqual(result, true, '结局轮回选择应成功');
  assert.strictEqual(runtime.state.getLifeCount(), lifeBefore + 1, '转世次数应增加 1');
  assert.strictEqual(runtime.state.realm, 'qi', '下一世应回到炼气期');
  assert.strictEqual(runtime.state.dead, false, '下一世不应保持死亡状态');
  assert.strictEqual(runtime.state.lifePhase, 'LEGACY_CHOICE', '应停在跨世遗产选择前');
  assert.strictEqual(runtime.state.pendingCardId, 'rebirth_boon', '应挂起轮回恩赐卡');
  assert.strictEqual(runtime.state.getTerminalContext(), null, '旧终局凭证必须清除');
});

test('#2f start() 新开游戏应清除旧终局上下文', () => {
  const runtime = createTerminalEndingRuntime();
  runtime.effectService.apply({ ending: 'ascension' }, { terminalContext: runtime.state.getTerminalContext() });
  assert.strictEqual(runtime.state.lifePhase, 'EPILOGUE', '前置: 应处于 EPILOGUE');
  const cc = createCombatCoordinator({ effectService: runtime.effectService });
  const game = new (vm.runInContext('GameLogic', context))({
    gameState: runtime.state,
    eventBus: sandbox.eventBus,
    effectService: runtime.effectService,
    endingEligibilityService: runtime.endingEligibilityService,
    combatCoordinator: cc,
    debug: false
  });
  game.start('sword');
  assert.strictEqual(runtime.state.hasFlag('game_ended'), false, 'start() 后 game_ended 应被清除');
  assert.strictEqual(runtime.state.lifePhase, 'ALIVE', 'start() 后应回到 ALIVE');
  assert.strictEqual(runtime.state.endingId, null, 'start() 后不得残留 endingId');
  assert.strictEqual(runtime.state.getTerminalContext(), null, 'start() 后不得残留 terminalContext');
});

// ==================================================================
// 修复 #3: CombatCoordinator.onDefeat 按等级结算固定伤势
// ==================================================================
section('修复 #3: onDefeat 固定伤势与局内护体值解耦');

test('#3a onDefeat 普通战固定扣 1 点真实气血', () => {
  resetGameState({ health: 3, maxHealth: 3 });
  const cc = createCombatCoordinator();
  const healthBefore = sandbox.gameState.attributes.health;
  settleDefeat(cc, { originalCard: { id: 'test_combat' } });
  const healthAfter = sandbox.gameState.attributes.health;
  const delta = healthBefore - healthAfter;
  assert.strictEqual(delta, 1, `普通战败应固定扣 1 点真实气血，实际扣了 ${delta}`);
});

test('#3b onDefeat 不使用局内剩余护体值覆盖真实气血', () => {
  resetGameState({ health: 3, maxHealth: 3 });
  const cc = createCombatCoordinator();
  settleDefeat(cc, { originalCard: { id: 'test_combat' } });
  assert.strictEqual(sandbox.gameState.attributes.health, 2, `真实气血应从 3 固定降到 2，实际: ${sandbox.gameState.attributes.health}`);
});

test('#3c onDefeat 不应扣 20 点血（旧宏数值）', () => {
  resetGameState({ health: 3, maxHealth: 3 });
  const cc = createCombatCoordinator();
  settleDefeat(cc, { originalCard: { id: 'test_combat' } });
  assert.ok(sandbox.gameState.attributes.health > 0, `health 不应为负数，实际: ${sandbox.gameState.attributes.health}`);
  assert.ok(sandbox.gameState.attributes.health >= 1, `health 不应被旧宏数值二次扣除，实际: ${sandbox.gameState.attributes.health}`);
});

test('#3d 突破战失败同样结算固定伤势', () => {
  resetGameState({ health: 3, maxHealth: 3 });
  const cc = createCombatCoordinator({
    callbacks: {
      setCurrentCard: () => {}, log: () => {}, onUpdate: () => {},
      onInnerVoice: () => {},
      onResolveBreakthrough: (rate, card) => { /* 模拟突破结算 */ }
    }
  });
  settleDefeat(cc, { originalCard: { id: 'break_qi', combatRewards: { breakSuccess: true } } });
  assert.strictEqual(sandbox.gameState.attributes.health, 2, '突破战失败应固定扣 1 点真实气血');
});

test('#3e onDefeat 后 near_death 阈值应为微数值 (<=1)', () => {
  resetGameState({ health: 3, maxHealth: 3 });
  let innerVoiceCalled = false;
  let innerVoiceCategory = null;
  const cc = createCombatCoordinator({
    callbacks: {
      setCurrentCard: () => {}, log: () => {}, onUpdate: () => {},
      onInnerVoice: (cat, prob) => { innerVoiceCalled = true; innerVoiceCategory = cat; },
      onResolveBreakthrough: () => {}
    }
  });
  // health=3 扣除 1 后为 2，不应触发 near_death
  settleDefeat(cc, { originalCard: { id: 'test_combat' } });
  assert.strictEqual(innerVoiceCalled, false, 'health=3 时不应触发 near_voice');

  // health=2 扣除 1 后为 1，应触发 near_death
  sandbox.gameState.attributes.health = 2;
  settleDefeat(cc, { originalCard: { id: 'test_combat' } });
  assert.strictEqual(innerVoiceCalled, true, 'health=1 时应触发 near_death');
  assert.strictEqual(innerVoiceCategory, 'near_death', `category 应为 near_death，实际: ${innerVoiceCategory}`);
});

// ==================================================================
// 修复 #4: game.makeChoice costCheck 双重扣费 + UI 返回值捕获
// ==================================================================
section('修复 #4: costCheck 双重扣费防护 + UI 返回值');

test('#4a costCheck 扣费后 effects 中同名字段应被剥离', () => {
  resetGameState({ spiritStone: 100 });
  const es = new (vm.runInContext('EffectService', context))({
    gameState: sandbox.gameState,
    eventBus: sandbox.eventBus,
    debug: false
  });
  // EffectService 在构造函数中自动注册 handlers，无需 init()
  const cc = createCombatCoordinator({ effectService: es });
  const game = new (vm.runInContext('GameLogic', context))({
    gameState: sandbox.gameState,
    eventBus: sandbox.eventBus,
    effectService: es,
    combatCoordinator: cc,
    debug: false
  });

  const stoneBefore = sandbox.gameState.resources.spiritStone;
  // costCheck: spiritStone -10, effects: spiritStone -10 (双重扣费场景)
  game.currentCard = {
    id: 'test_shop',
    type: 'SHOP',
    title: '测试商店',
    description: '',
    choices: {
      left: {
        text: '购买',
        costCheck: { spiritStone: 10 },
        effects: { spiritStone: -10, cultivation: 5 }
      }
    }
  };

  game.makeChoice('left');
  const stoneAfter = sandbox.gameState.resources.spiritStone;
  const actualDeduction = stoneBefore - stoneAfter;
  // 修复后：costCheck 扣 10，effects 中 spiritStone 被剥离，总扣费 = 10（不是 20）
  assert.strictEqual(actualDeduction, 10, `应只扣 10 灵石（非双扣 20），实际扣了 ${actualDeduction}`);
});

test('#4b costCheck 不足时 makeChoice 应返回 false', () => {
  resetGameState({ spiritStone: 5 });
  const es = new (vm.runInContext('EffectService', context))({
    gameState: sandbox.gameState,
    eventBus: sandbox.eventBus,
    debug: false
  });
  // EffectService 在构造函数中自动注册 handlers，无需 init()
  const cc = createCombatCoordinator({ effectService: es });
  const game = new (vm.runInContext('GameLogic', context))({
    gameState: sandbox.gameState,
    eventBus: sandbox.eventBus,
    effectService: es,
    combatCoordinator: cc,
    debug: false
  });

  game.currentCard = {
    id: 'test_shop',
    type: 'SHOP',
    title: '测试商店',
    description: '',
    choices: {
      left: {
        text: '购买',
        costCheck: { spiritStone: 50 },
        effects: { cultivation: 5 }
      }
    }
  };

  const result = game.makeChoice('left');
  assert.strictEqual(result, false, '资源不足时 makeChoice 应返回 false');
});

test('#4c costCheck 足够时 makeChoice 应返回 true', () => {
  resetGameState({ spiritStone: 100 });
  const es = new (vm.runInContext('EffectService', context))({
    gameState: sandbox.gameState,
    eventBus: sandbox.eventBus,
    debug: false
  });
  // EffectService 在构造函数中自动注册 handlers，无需 init()
  const cc = createCombatCoordinator({ effectService: es });
  const game = new (vm.runInContext('GameLogic', context))({
    gameState: sandbox.gameState,
    eventBus: sandbox.eventBus,
    effectService: es,
    combatCoordinator: cc,
    debug: false
  });

  game.currentCard = {
    id: 'test_shop',
    type: 'SHOP',
    title: '测试商店',
    description: '',
    choices: {
      left: {
        text: '购买',
        costCheck: { spiritStone: 10 },
        effects: { cultivation: 5 }
      }
    }
  };

  const result = game.makeChoice('left');
  assert.strictEqual(result, true, '资源足够时 makeChoice 应返回 true');
});

test('#4d costCheck + effects 同时有 health 字段时只扣一次', () => {
  resetGameState({ health: 3, maxHealth: 3 });
  const es = new (vm.runInContext('EffectService', context))({
    gameState: sandbox.gameState,
    eventBus: sandbox.eventBus,
    debug: false
  });
  // EffectService 在构造函数中自动注册 handlers，无需 init()
  const cc = createCombatCoordinator({ effectService: es });
  const game = new (vm.runInContext('GameLogic', context))({
    gameState: sandbox.gameState,
    eventBus: sandbox.eventBus,
    effectService: es,
    combatCoordinator: cc,
    debug: false
  });

  const healthBefore = sandbox.gameState.attributes.health;
  game.currentCard = {
    id: 'test_blood_sacrifice',
    type: 'NORMAL',
    title: '血祭',
    description: '',
    choices: {
      left: {
        text: '献祭',
        costCheck: { health: 1 },
        effects: { health: -1, cultivation: 3 }
      }
    }
  };

  game.makeChoice('left');
  const healthAfter = sandbox.gameState.attributes.health;
  const actualDeduction = healthBefore - healthAfter;
  // 修复后：costCheck 扣 1，effects 中 health 被剥离，总扣血 = 1（不是 2）
  assert.strictEqual(actualDeduction, 1, `应只扣 1 点血（非双扣 2），实际扣了 ${actualDeduction}`);
});

test('#4e makeChoice 返回 false 时不抛异常（UI 可捕获）', () => {
  resetGameState({ spiritStone: 0 });
  const es = new (vm.runInContext('EffectService', context))({
    gameState: sandbox.gameState,
    eventBus: sandbox.eventBus,
    debug: false
  });
  // EffectService 在构造函数中自动注册 handlers，无需 init()
  const cc = createCombatCoordinator({ effectService: es });
  const game = new (vm.runInContext('GameLogic', context))({
    gameState: sandbox.gameState,
    eventBus: sandbox.eventBus,
    effectService: es,
    combatCoordinator: cc,
    debug: false
  });

  game.currentCard = {
    id: 'test_expensive',
    type: 'SHOP',
    title: '贵重物品',
    description: '',
    choices: {
      left: {
        text: '购买',
        costCheck: { spiritStone: 999 },
        effects: {}
      }
    }
  };

  let caught = null;
  let result = null;
  try {
    result = game.makeChoice('left');
  } catch (e) {
    caught = e;
  }
  assert.strictEqual(caught, null, 'makeChoice 资源不足时不应抛异常');
  assert.strictEqual(result, false, '应返回 false 而非 undefined');
});

// ========== 8. 输出结果 ==========
for (const line of results) {
  console.log(line);
}

console.log(`\n=== 测试结果 ===`);
console.log(`  通过: ${passed}`);
console.log(`  失败: ${failed}`);
console.log(`  跳过: ${skipped}`);
console.log(`  总计: ${passed + failed + skipped}`);

if (failed > 0) {
  console.log('\n❌ 有测试失败，请检查修复是否正确应用');
  process.exit(1);
} else {
  console.log('\n✅ 全部测试通过，修复无回归');
  process.exit(0);
}
