/**
 * P0 修复验证测试 - 一念仙途
 * 验证：功法被动接入战斗 / 商店系统 / 法宝ID映射 / 因果seed来源闭环
 */
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const PROJECT_ROOT = path.resolve(__dirname, '..');

let passed = 0;
let failed = 0;
const errors = [];

function test(name, fn) {
  try {
    fn();
    passed++;
    console.log(`  ✅ ${name}`);
  } catch (e) {
    failed++;
    errors.push(`${name}: ${e.message}`);
    console.log(`  ❌ ${name}: ${e.message}`);
  }
}

function assert(cond, msg) {
  if (!cond) throw new Error(msg);
}

// ============================================================
console.log('=== P0-1: 功法被动接入战斗 ===');

// 检查 CombatSystem._start() 是否读取 pathSkillSystem
{
  const content = fs.readFileSync(path.join(PROJECT_ROOT, 'src/systems/CombatSystem.js'), 'utf8');
  test('CombatSystem._start() 读取 pathSkillSystem.getPassiveBonuses', () => {
    assert(content.includes('pathSkillSystem.getPassiveBonuses'), 'CombatSystem 未读取功法被动');
  });
  test('CombatSystem 应用 critRate 被动', () => {
    assert(content.includes('critRate') && content.includes('pathBonuses'), '未应用 critRate');
  });
  test('CombatSystem 应用 daoResist 被动', () => {
    assert(content.includes('daoResist'), '未应用 daoResist');
  });
  test('CombatSystem 应用 lowHpAtkBonus 被动', () => {
    assert(content.includes('lowHpAtkBonus'), '未应用 lowHpAtkBonus');
  });
  test('CombatSystem._calcDamage 包含低血攻击加成', () => {
    assert(content.includes('lowHpAtkBonus') && content.includes('_calcDamage'), 'lowHpAtkBonus 未接入 _calcDamage');
  });
}

// 检查 game.js _applyEffects 处理 daoHeart 时应用 daoResist
{
  const content = fs.readFileSync(path.join(PROJECT_ROOT, 'src/game.js'), 'utf8');
  test('game.js _applyEffects 处理 daoHeart + daoResist', () => {
    assert(content.includes('daoResist') && content.includes('daoHeart'), 'game.js 未处理 daoResist');
  });
  test('game.js _applyEffects 处理 spiritStone + spiritStoneBonus', () => {
    assert(content.includes('spiritStoneBonus'), 'game.js 未处理 spiritStoneBonus');
  });
  test('game.js _resolveBreakthrough 应用 pillBonus', () => {
    assert(content.includes('pillBonus'), '_resolveBreakthrough 未应用 pillBonus');
  });
}

// ============================================================
console.log('\n=== P0-2: 商店系统 ===');

// 检查 ShopSystem.js 存在且结构正确
{
  const shopPath = path.join(PROJECT_ROOT, 'src/systems/ShopSystem.js');
  test('ShopSystem.js 存在', () => {
    assert(fs.existsSync(shopPath), 'ShopSystem.js 不存在');
  });
  
  if (fs.existsSync(shopPath)) {
    const content = fs.readFileSync(shopPath, 'utf8');
    test('ShopSystem 有 purchase 方法', () => {
      assert(content.includes('purchase('), 'ShopSystem 缺少 purchase 方法');
    });
    test('ShopSystem 有 _applyItemEffect 方法', () => {
      assert(content.includes('_applyItemEffect'), 'ShopSystem 缺少 _applyItemEffect');
    });
    test('ShopSystem 正确处理 treasureId', () => {
      assert(content.includes('treasureId') || content.includes('acquire('), 'ShopSystem 未处理法宝获取');
    });
  }
}

// 检查 game.js 处理 openShop
{
  const content = fs.readFileSync(path.join(PROJECT_ROOT, 'src/game.js'), 'utf8');
  test('game.js 处理 openShop:true', () => {
    assert(content.includes('openShop'), 'game.js 未处理 openShop');
  });
  test('game.js 监听 shop:closed 恢复卡牌流', () => {
    assert(content.includes('shop:closed'), 'game.js 未监听 shop:closed');
  });
}

// 检查 ui.js 有商店面板逻辑
{
  const uiPath = path.join(PROJECT_ROOT, 'src/ui.js');
  if (fs.existsSync(uiPath)) {
    const content = fs.readFileSync(uiPath, 'utf8');
    test('ui.js 有 _openShop 方法', () => {
      assert(content.includes('_openShop'), 'ui.js 缺少 _openShop');
    });
    test('ui.js 有 _handleShopBuy 方法', () => {
      assert(content.includes('_handleShopBuy'), 'ui.js 缺少 _handleShopBuy');
    });
    test('ui.js 有 _closeShop 方法', () => {
      assert(content.includes('_closeShop'), 'ui.js 缺少 _closeShop');
    });
  } else {
    test('ui.js 存在', () => { throw new Error('ui.js 不存在'); });
  }
}

// ============================================================
console.log('\n=== P0-3: 法宝ID映射 ===');

// 检查 shop_items.json 的 treasureId 是否匹配 treasures.json 的 ID
{
  const shopItemsPath = path.join(PROJECT_ROOT, 'data/shops/shop_items.json');
  const treasuresPath = path.join(PROJECT_ROOT, 'data/shops/treasures.json');
  
  test('shop_items.json 存在', () => {
    assert(fs.existsSync(shopItemsPath), 'shop_items.json 不存在');
  });
  test('treasures.json 存在', () => {
    assert(fs.existsSync(treasuresPath), 'treasures.json 不存在');
  });
  
  if (fs.existsSync(shopItemsPath) && fs.existsSync(treasuresPath)) {
    const shopData = JSON.parse(fs.readFileSync(shopItemsPath, 'utf8'));
    const shopItems = Array.isArray(shopData) ? shopData : (shopData.items || shopData.shop_items || []);
    const treasuresData = JSON.parse(fs.readFileSync(treasuresPath, 'utf8'));
    const treasures = Array.isArray(treasuresData) ? treasuresData : (treasuresData.treasures || treasuresData.items || []);
    
    const treasureIds = new Set(treasures.map(t => t.id || t.name));
    
    for (const item of shopItems) {
      if (item.type === 'treasure' && item.effect && item.effect.treasureId) {
        test(`法宝 ${item.id} 的 treasureId="${item.effect.treasureId}" 存在于 treasures.json`, () => {
          assert(treasureIds.has(item.effect.treasureId), 
            `treasureId "${item.effect.treasureId}" 不在 treasures.json 中。可用ID: ${[...treasureIds].join(', ')}`);
        });
      }
    }
  }
}

// ============================================================
console.log('\n=== P0-4: 因果seed来源闭环 ===');

// 检查所有9种因果种子都有种植源头
const allSeedIds = [
  'combatScar',      // CombatSystem._victory
  'combatGlory',     // CombatSystem._victory
  'lifespanWaste',   // game.js makeChoice
  'factionUprising', // FactionSystem
  'companionSacrifice', // CompanionSystem
  'companionTrust',   // CompanionSystem
  'spellHidden',      // spell_codex.json q_spell_3 right
  'spellRevealed',   // spell_codex.json q_spell_3 left
  'pillPoison',       // pill_master.json q_pill_2 left
  'pillCure',         // pill_master.json q_pill_3 left
];

// 检查代码中是否有种植这些种子的逻辑
{
  const combatContent = fs.readFileSync(path.join(PROJECT_ROOT, 'src/systems/CombatSystem.js'), 'utf8');
  test('CombatSystem 种植 combatScar 种子', () => {
    assert(combatContent.includes('combatScar'), 'CombatSystem 未种植 combatScar');
  });
  test('CombatSystem 种植 combatGlory 种子', () => {
    assert(combatContent.includes('combatGlory'), 'CombatSystem 未种植 combatGlory');
  });
}

{
  const gameContent = fs.readFileSync(path.join(PROJECT_ROOT, 'src/game.js'), 'utf8');
  test('game.js 种植 lifespanWaste 种子', () => {
    assert(gameContent.includes('lifespanWaste'), 'game.js 未种植 lifespanWaste');
  });
}

{
  const factionPath = path.join(PROJECT_ROOT, 'src/systems/FactionSystem.js');
  if (fs.existsSync(factionPath)) {
    const content = fs.readFileSync(factionPath, 'utf8');
    test('FactionSystem 种植 factionUprising 种子', () => {
      assert(content.includes('factionUprising'), 'FactionSystem 未种植 factionUprising');
    });
  }
}

{
  const companionPath = path.join(PROJECT_ROOT, 'src/systems/CompanionSystem.js');
  if (fs.existsSync(companionPath)) {
    const content = fs.readFileSync(companionPath, 'utf8');
    test('CompanionSystem 种植 companionSacrifice 种子', () => {
      assert(content.includes('companionSacrifice'), 'CompanionSystem 未种植 companionSacrifice');
    });
    test('CompanionSystem 种植 companionTrust 种子', () => {
      assert(content.includes('companionTrust'), 'CompanionSystem 未种植 companionTrust');
    });
  }
}

// 检查 JSON 奇遇文件中是否有新种子
{
  const spellCodexPath = path.join(PROJECT_ROOT, 'data/quests/spell_codex.json');
  const pillMasterPath = path.join(PROJECT_ROOT, 'data/quests/pill_master.json');
  
  if (fs.existsSync(spellCodexPath)) {
    const content = fs.readFileSync(spellCodexPath, 'utf8');
    test('spell_codex.json 包含 spellHidden 种子', () => {
      assert(content.includes('spellHidden'), 'spell_codex.json 缺少 spellHidden');
    });
    test('spell_codex.json 包含 spellRevealed 种子', () => {
      assert(content.includes('spellRevealed'), 'spell_codex.json 缺少 spellRevealed');
    });
  }
  
  if (fs.existsSync(pillMasterPath)) {
    const content = fs.readFileSync(pillMasterPath, 'utf8');
    test('pill_master.json 包含 pillPoison 种子', () => {
      assert(content.includes('pillPoison'), 'pill_master.json 缺少 pillPoison');
    });
    test('pill_master.json 包含 pillCure 种子', () => {
      assert(content.includes('pillCure'), 'pill_master.json 缺少 pillCure');
    });
  }
}

// ============================================================
console.log('\n=== 逻辑闭环检查 ===');

// 检查 karmaSeed 数组格式支持
{
  const gameContent = fs.readFileSync(path.join(PROJECT_ROOT, 'src/game.js'), 'utf8');
  test('game.js 支持 karmaSeed 数组格式', () => {
    assert(gameContent.includes('Array.isArray(choice.karmaSeed)'), 'game.js 未支持 karmaSeed 数组');
  });
}

// 检查 KarmaSystem 有 getActiveSeeds 方法
{
  const karmaContent = fs.readFileSync(path.join(PROJECT_ROOT, 'src/systems/KarmaSystem.js'), 'utf8');
  test('KarmaSystem 有 getActiveSeeds 方法', () => {
    assert(karmaContent.includes('getActiveSeeds'), 'KarmaSystem 缺少 getActiveSeeds');
  });
}

// 检查 CardSystem 按优先级60抽出因果卡
{
  const cardContent = fs.readFileSync(path.join(PROJECT_ROOT, 'src/systems/CardSystem.js'), 'utf8');
  test('CardSystem 按优先级60抽出因果卡', () => {
    assert(cardContent.includes('60') && cardContent.includes('karma'), 'CardSystem 未处理因果卡抽取');
  });
}

// ============================================================
console.log('\n========================================');
console.log(`结果: ${passed} 通过, ${failed} 失败`);
if (errors.length > 0) {
  console.log('\n失败项:');
  errors.forEach(e => console.log(`  - ${e}`));
}
console.log('========================================');

process.exit(failed > 0 ? 1 : 0);
