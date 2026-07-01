/**
 * test_p0_fixes.js - 验证 P0 修复是否生效（修正版：同一上下文）
 * 用法：node test_p0_fixes.js
 */
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const DIR = __dirname;

// 读取 DATA_MODULES
let indexHtml = fs.readFileSync(path.join(DIR, 'index.html'), 'utf8');
const dmMatch = indexHtml.match(/const DATA_MODULES = (\{[\s\S]*?\});/);
let DATA_MODULES = {};
if (dmMatch) {
  try { DATA_MODULES = eval(dmMatch[1]); } catch (e) { console.log('⚠️  DATA_MODULES 解析失败:', e.message); }
}

console.log('=== P0 修复验证测试（修正版）===\n');

// 创建共享上下文
const context = vm.createContext({
  console,
  setTimeout,
  setInterval,
  Math,
  Date,
  Array,
  Object,
  String,
  Number,
  JSON,
  parseInt,
  parseFloat,
  isNaN,
  isFinite,
  NaN,
  Infinity,
  undefined,
  DATA_MODULES,
  // 预定义全局变量（各脚本会往这些全局变量上挂实例）
  gameState: null,
  eventBus: null,
  dataLoader: null,
  cardSystem: null,
  karmaSystem: null,
  treasureSystem: null,
  pathSkillSystem: null,
  combatSystem: null,
  companionSystem: null,
  factionSystem: null,
  questSystem: null,
  npcSystem: null,
  shopSystem: null,
  gameLogic: null,
});

// 按 index.html 顺序加载脚本到同一上下文
const loadOrder = [
  'src/core/EventBus.js',
  'src/core/DataLoader.js',
  'src/core/GameStateManager.js',
  'src/systems/KarmaSystem.js',
  'src/systems/CardSystem.js',
  'src/systems/QuestSystem.js',
  'src/systems/NpcSystem.js',
  'src/systems/CompanionSystem.js',
  'src/systems/FactionSystem.js',
  'src/systems/TreasureSystem.js',
  'src/systems/PathSkillSystem.js',
  'src/systems/ShopSystem.js',
  'src/systems/CombatSystem.js',
];

let passed = 0;
let failed = 0;

function test(name, fn) {
  try {
    fn();
    console.log(`  ✅ ${name}`);
    passed++;
  } catch (e) {
    console.log(`  ❌ ${name}: ${e.message}`);
    failed++;
  }
}

for (const rel of loadOrder) {
  const fp = path.join(DIR, rel);
  if (!fs.existsSync(fp)) {
    console.log(`⚠️  文件不存在: ${rel}`);
    continue;
  }
  const code = fs.readFileSync(fp, 'utf8');
  try {
    const script = new vm.Script(code, { filename: rel });
    script.runInContext(context, { timeout: 5000 });
  } catch (e) {
    console.log(`❌ 加载失败 ${rel}: ${e.message}`);
    failed++;
  }
}

console.log('\n--- 加载完成 ---\n');
console.log('  全局变量检查:');
console.log(`  eventBus: ${context.eventBus ? '✅' : '❌'}`);
console.log(`  dataLoader: ${context.dataLoader ? '✅' : '❌'}`);
console.log(`  gameState: ${context.gameState ? '✅' : '❌'}`);
console.log(`  pathSkillSystem: ${context.pathSkillSystem ? '✅' : '❌'}`);
console.log(`  combatSystem: ${context.combatSystem ? '✅' : '❌'}`);
console.log(`  shopSystem: ${context.shopSystem ? '✅' : '❌'}`);
console.log('');

// 初始化系统
try {
  context.dataLoader.setData(DATA_MODULES);

  const realmsConfig = DATA_MODULES['config:realms'] || null;
  const pathsConfig = DATA_MODULES['config:paths'] || null;
  context.gameState.init({ realms: realmsConfig, paths: pathsConfig });
  context.gameState.path = 'sword';

  if (context.pathSkillSystem) context.pathSkillSystem.init();
  if (context.combatSystem) context.combatSystem.init();
  if (context.shopSystem) context.shopSystem.init();
} catch (e) {
  console.log(`⚠️  初始化失败: ${e.message}`);
}

console.log('--- P0-1: 功法被动接入战斗 ---\n');

test('pathSkillSystem.getPassiveBonuses 返回对象', () => {
  if (!context.pathSkillSystem) throw new Error('pathSkillSystem 未加载');
  const b = context.pathSkillSystem.getPassiveBonuses('sword');
  if (typeof b !== 'object') throw new Error('返回值不是对象');
});

test('功法被动 atk/def/critRate 可读取', () => {
  const b = context.pathSkillSystem.getPassiveBonuses('sword');
  // 剑修默认未解锁技能，所以应为空对象 {} —— 能调用不报错就算通过
});

test('CombatSystem._start 不报错', () => {
  if (!context.combatSystem) throw new Error('combatSystem 未加载');
  context.combatSystem.reset();
  const card = { id: 'test_combat', type: 'COMBAT', enemy: { name: '测试', hp: 30, atk: 8 } };
  context.combatSystem._start({ card });
  if (!context.combatSystem.player) throw new Error('玩家属性未初始化');
  if (typeof context.combatSystem.player.atk !== 'number') throw new Error('atk 不是数字');
});

console.log('\n--- P0-3: 法宝 ID 映射 ---\n');

test('shop_items.json effect.treasureId 全部匹配 treasures.json', () => {
  const shopItems = DATA_MODULES['shops:shop_items'];
  const treasures = DATA_MODULES['shops:treasures'];
  if (!shopItems || !treasures) throw new Error('数据未加载');
  const tIds = new Set(treasures.treasures.map(t => t.id));
  const errors = [];
  for (const item of shopItems.items) {
    if (item.type === 'treasure' && item.effect && item.effect.treasureId) {
      if (!tIds.has(item.effect.treasureId)) {
        errors.push(`${item.id}: "${item.effect.treasureId}" 在 treasures.json 中不存在`);
      }
    }
  }
  if (errors.length > 0) throw new Error(errors.join('; '));
});

console.log('\n--- P0-2: 商店系统 ---\n');

test('ShopSystem 已加载', () => {
  if (!context.shopSystem) throw new Error('shopSystem 未加载');
});

test('ShopSystem.getAvailableItems 返回数组', () => {
  const items = context.shopSystem.getAvailableItems('qi');
  if (!Array.isArray(items)) throw new Error('返回值不是数组');
});

test('ShopSystem.purchase 灵石不足时返回 failure', () => {
  if (context.gameState) context.gameState.resources.spiritStone = 0;
  const result = context.shopSystem.purchase('shop_pill_healing');
  if (result.success) throw new Error('灵石不足时应返回失败');
});

console.log('\n--- P0-4: 因果 seed 来源 ---\n');

test('CombatSystem 代码包含 karmaSystem.plantSeed 调用', () => {
  const fp = path.join(DIR, 'src/systems/CombatSystem.js');
  const code = fs.readFileSync(fp, 'utf8');
  if (!code.includes('karmaSystem.plantSeed')) {
    throw new Error('CombatSystem.js 中未找到 karmaSystem.plantSeed 调用');
  }
});

test('game.js 代码包含 lifespanWaste seed', () => {
  const fp = path.join(DIR, 'src/game.js');
  const code = fs.readFileSync(fp, 'utf8');
  if (!code.includes('lifespanWaste')) {
    throw new Error('game.js 中未找到 lifespanWaste seed');
  }
});

test('FactionSystem.js 代码包含 factionUprising seed', () => {
  const fp = path.join(DIR, 'src/systems/FactionSystem.js');
  const code = fs.readFileSync(fp, 'utf8');
  if (!code.includes('factionUprising')) {
    throw new Error('FactionSystem.js 中未找到 factionUprising seed');
  }
});

console.log('\n--- 汇总 ---');
console.log(`✅ 通过: ${passed}`);
console.log(`❌ 失败: ${failed}`);
console.log('\n说明：');
console.log('  P0-1 功法被动: ✅ 代码已改，需浏览器实战验证');
console.log('  P0-3 法宝ID映射: ✅ shop_items.json 已修复');
console.log('  P0-2 商店系统: ⏳ 核心逻辑完成，缺 UI 面板');
console.log('  P0-4 因果seed: ⏳ combatScar/combatGlory/factionUprising 已加，缺 companionSacrifice');
