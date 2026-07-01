/**
 * FIX-4: 秘境分叉地图重构 — 端到端测试
 * 验证图结构秘境的分叉选择、路径追踪、EXIT出口
 */
var vm = require('vm');
var fs = require('fs');
var path = require('path');

var baseDir = path.resolve(__dirname, '..');

// ════════════════════════════════════════
// 模拟环境
// ════════════════════════════════════════
var sandbox = {
  console: console,
  Date: Date,
  Math: Math,
  Set: Set,
  Map: Map,
  JSON: JSON,
  Object: Object,
  Array: Array,
  String: String,
  Number: Number,
  Boolean: Boolean,
  eventBus: {
    _listeners: {},
    emit: function(event, data) {
      if (this._listeners[event]) {
        this._listeners[event].forEach(function(fn) { fn(data); });
      }
    },
    on: function(event, fn) {
      if (!this._listeners[event]) this._listeners[event] = [];
      this._listeners[event].push(fn);
    },
    once: function(event, fn) {
      var self = this;
      var wrapper = function(data) { fn(data); self.off(event, wrapper); };
      this.on(event, wrapper);
    },
    off: function(event, fn) {
      if (this._listeners[event]) {
        this._listeners[event] = this._listeners[event].filter(function(f) { return f !== fn; });
      }
    }
  },
  gameState: {
    realm: 'qi',
    path: 'sword',
    dead: false,
    deadReason: '',
    dungeon: null,
    dungeonNodeIndex: 0,
    dungeonNodeId: null,
    dungeonPath: [],
    attributes: { health: 100, daoHeart: 50, fortune: 50, cultivation: 10, karmaBad: 0 },
    resources: { spiritStone: 100, pill: 3, karmaGood: 0, karmaBad: 0, lifespan: 9999 },
    cardsPlayed: [],
    flags: {},
    checkFlags: function() { return true; },
    hasFlag: function(k) { return !!this.flags[k]; },
    getFlag: function(k) { return this.flags[k] || null; },
    checkBreakthrough: function() { return null; },
    addResource: function(k, s, v) {
      if (!this.resources[k]) this.resources[k] = 0;
      this.resources[k] += v;
    },
    addAttribute: function(k, v) {
      if (!this.attributes[k]) this.attributes[k] = 0;
      this.attributes[k] += v;
    }
  },
  dataLoader: {
    loadSync: function(key) {
      if (key === 'cards:qi') {
        return {
          realm: 'qi',
          cards: [],
          dungeons: {
            ancientCave: {
              name: '古洞探险',
              startNode: 'entrance',
              graph: {
                entrance: {
                  type: 'EVENT',
                  card: 'cave_spirit',
                  next: 'fork1'
                },
                fork1: {
                  type: 'FORK',
                  title: '岔路口',
                  description: '前方出现两条路：左侧散发着灵药香气，右侧传来低沉咆哮。',
                  paths: {
                    leftPath: {
                      text: '灵药小径',
                      desc: '左侧通道灵气浓郁，似乎有灵药生长。',
                      effects: { fortune: 5 },
                      next: 'herbGarden'
                    },
                    rightPath: {
                      text: '妖兽巢穴',
                      desc: '右侧通道危机四伏，但宝物可能更多。',
                      effects: { daoHeart: -3 },
                      next: 'beastDen'
                    }
                  }
                },
                herbGarden: {
                  type: 'EVENT',
                  card: 'cave_herb',
                  next: 'reward'
                },
                beastDen: {
                  type: 'BATTLE',
                  card: 'cave_beast_hard',
                  next: 'bossRoom'
                },
                bossRoom: {
                  type: 'BOSS',
                  card: 'cave_boss',
                  next: 'reward'
                },
                reward: {
                  type: 'REWARD',
                  card: 'cave_reward',
                  next: 'exit'
                },
                exit: {
                  type: 'EXIT'
                }
              }
            }
          },
          dungeonCards: {
            cave_spirit: { id: 'cave_spirit', title: '洞中生灵', type: 'NORMAL',
              choices: { left: { text: '询问', effects: { cultivation: 15 } }, right: { text: '吞噬', effects: { cultivation: 25, karmaBad: 15 } } } },
            cave_herb: { id: 'cave_herb', title: '灵药园', type: 'NORMAL',
              choices: { left: { text: '采集', effects: { pill: 1 } }, right: { text: '炼化', effects: { cultivation: 20 } } } },
            cave_beast_hard: { id: 'cave_beast_hard', title: '凶兽拦路', type: 'COMBAT', tags: ['combat'],
              enemy: { name: '岩甲兽王', hp: 50, atk: 12 },
              choices: { left: { text: '战斗', effects: {} }, right: { text: '逃跑', effects: { daoHeart: -5 } } } },
            cave_boss: { id: 'cave_boss', title: '洞府主宰', type: 'COMBAT', tags: ['combat'],
              enemy: { name: '古洞蛟蛇', hp: 80, atk: 15 },
              choices: { left: { text: '决战', effects: {} }, right: { text: '谈判', effects: { spiritStone: -50 } } } },
            cave_reward: { id: 'cave_reward', title: '洞府宝藏', type: 'NORMAL',
              choices: { left: { text: '灵石', effects: { spiritStone: 80 } }, right: { text: '功法', effects: { cultivation: 40 } } } }
          }
        };
      }
      return null;
    }
  },
  window: {}
};

// 加载 CardSystem 源码 — 追加导出代码使类在 sandbox 中可访问
var csSrc = fs.readFileSync(path.join(baseDir, 'src/systems/CardSystem.js'), 'utf8');
csSrc += '\nthis.CardSystem = CardSystem;\nthis.cardSystem = cardSystem;\n';
var script = new vm.Script(csSrc);
var context = vm.createContext(sandbox);
script.runInContext(context);

// CardSystem 类和 cardSystem 单例都被挂到了 sandbox (即 context 的 this)
var CardSystem = sandbox.CardSystem;
var cs = sandbox.cardSystem;

// ════════════════════════════════════════
// 测试 1: 进入秘境 — 首张卡是 entrance 事件
// ════════════════════════════════════════
console.log('--- Test 1: Enter dungeon, get entrance card ---');
sandbox.gameState.dungeon = 'ancientCave';
sandbox.gameState.dungeonNodeId = null;
sandbox.gameState.dungeonPath = [];

var card1 = cs._drawDungeonCard();
console.log('Card 1:', card1.id, '| type:', card1.type, '| nodeId:', card1._dungeonNodeId);
if (card1.id !== 'cave_spirit') throw new Error('Expected cave_spirit, got ' + card1.id);
if (sandbox.gameState.dungeonNodeId !== 'entrance') throw new Error('Expected nodeId=entrance, got ' + sandbox.gameState.dungeonNodeId);
if (sandbox.gameState.dungeonPath.length !== 1 || sandbox.gameState.dungeonPath[0] !== 'entrance') {
  throw new Error('Path should be [entrance], got ' + JSON.stringify(sandbox.gameState.dungeonPath));
}
console.log('Path:', JSON.stringify(sandbox.gameState.dungeonPath));
console.log('PASS\n');

// ════════════════════════════════════════
// 测试 2: 推进到 FORK 节点 — 应返回分叉选择卡
// ════════════════════════════════════════
console.log('--- Test 2: Advance to FORK node, get fork card ---');
cs.advanceDungeon(); // entrance → fork1
console.log('After advance, nodeId:', sandbox.gameState.dungeonNodeId);
console.log('Path:', JSON.stringify(sandbox.gameState.dungeonPath));

if (sandbox.gameState.dungeonNodeId !== 'fork1') throw new Error('Expected fork1, got ' + sandbox.gameState.dungeonNodeId);

var card2 = cs._drawDungeonCard();
console.log('Card 2:', card2.id, '| type:', card2.type);
if (card2.type !== 'DUNGEON_FORK') throw new Error('Expected DUNGEON_FORK, got ' + card2.type);
console.log('Fork choices:', Object.keys(card2.choices).join(', '));
if (!card2.choices.left || !card2.choices.right) throw new Error('Fork should have left+right choices');
console.log('Left:', card2.choices.left.text, '→', card2.choices.left._dungeonForkNext);
console.log('Right:', card2.choices.right.text, '→', card2.choices.right._dungeonForkNext);
console.log('PASS\n');

// ════════════════════════════════════════
// 测试 3A: 选择左路 (灵药小径) → herbGarden → reward → exit
// ════════════════════════════════════════
console.log('--- Test 3A: Choose left path (herbGarden) ---');
cs.advanceDungeonToFork('fork1', 'herbGarden');
console.log('After fork choice, nodeId:', sandbox.gameState.dungeonNodeId);
console.log('Path:', JSON.stringify(sandbox.gameState.dungeonPath));

if (sandbox.gameState.dungeonNodeId !== 'herbGarden') throw new Error('Expected herbGarden');

var card3 = cs._drawDungeonCard();
console.log('Card 3:', card3.id, '| type:', card3.type);
if (card3.id !== 'cave_herb') throw new Error('Expected cave_herb, got ' + card3.id);

// 推进到 reward
cs.advanceDungeon();
console.log('After advance, nodeId:', sandbox.gameState.dungeonNodeId);
if (sandbox.gameState.dungeonNodeId !== 'reward') throw new Error('Expected reward, got ' + sandbox.gameState.dungeonNodeId);

var card4 = cs._drawDungeonCard();
console.log('Card 4:', card4.id, '| type:', card4.type);
if (card4.id !== 'cave_reward') throw new Error('Expected cave_reward, got ' + card4.id);

// 推进到 exit
cs.advanceDungeon();
console.log('After advance, nodeId:', sandbox.gameState.dungeonNodeId);
if (sandbox.gameState.dungeonNodeId !== 'exit') throw new Error('Expected exit, got ' + sandbox.gameState.dungeonNodeId);

// EXIT 节点 → 秘境结束
var card5 = cs._drawDungeonCard();
console.log('Card 5 (EXIT): dungeon should be null, got:', sandbox.gameState.dungeon);
if (sandbox.gameState.dungeon !== null) throw new Error('Expected dungeon=null after EXIT');
if (sandbox.gameState.dungeonNodeId !== null) throw new Error('Expected dungeonNodeId=null after EXIT');
console.log('PASS\n');

// ════════════════════════════════════════
// 测试 3B: 重新进入，选择右路 (妖兽巢穴) → beastDen → bossRoom → reward → exit
// ════════════════════════════════════════
console.log('--- Test 3B: Choose right path (beastDen → bossRoom) ---');
sandbox.gameState.dungeon = 'ancientCave';
sandbox.gameState.dungeonNodeId = null;
sandbox.gameState.dungeonPath = [];

// 快进到 fork
cs._drawDungeonCard(); // entrance
cs.advanceDungeon();   // → fork1
var forkCard = cs._drawDungeonCard(); // fork
if (forkCard.type !== 'DUNGEON_FORK') throw new Error('Expected fork card');

// 选择右路
cs.advanceDungeonToFork('fork1', 'beastDen');
console.log('After right fork, nodeId:', sandbox.gameState.dungeonNodeId);

var beastCard = cs._drawDungeonCard();
console.log('Beast card:', beastCard.id, '| type:', beastCard.type);
if (beastCard.id !== 'cave_beast_hard') throw new Error('Expected cave_beast_hard');
if (beastCard.type !== 'COMBAT') throw new Error('Expected COMBAT type');

// 推进到 boss
cs.advanceDungeon();
console.log('After advance, nodeId:', sandbox.gameState.dungeonNodeId);
if (sandbox.gameState.dungeonNodeId !== 'bossRoom') throw new Error('Expected bossRoom');

var bossCard = cs._drawDungeonCard();
console.log('Boss card:', bossCard.id, '| type:', bossCard.type);
if (bossCard.id !== 'cave_boss') throw new Error('Expected cave_boss');

// 推进到 reward
cs.advanceDungeon();
if (sandbox.gameState.dungeonNodeId !== 'reward') throw new Error('Expected reward');

var rewardCard = cs._drawDungeonCard();
if (rewardCard.id !== 'cave_reward') throw new Error('Expected cave_reward');

// 推进到 exit
cs.advanceDungeon();
var exitCard = cs._drawDungeonCard();
if (sandbox.gameState.dungeon !== null) throw new Error('Expected dungeon=null after EXIT');

console.log('Full path (right):', JSON.stringify(sandbox.gameState.dungeonPath));
// dungeonPath 在 EXIT 时被清空，但我们在退出前可以验证
// 实际上 dungeonPath 在 _drawDungeonGraphCard 的 EXIT 分支中被清空
console.log('PASS\n');

// ════════════════════════════════════════
// 测试 4: 路径追踪验证
// ════════════════════════════════════════
console.log('--- Test 4: Path tracking ---');
sandbox.gameState.dungeon = 'ancientCave';
sandbox.gameState.dungeonNodeId = null;
sandbox.gameState.dungeonPath = [];

// entrance
cs._drawDungeonCard();
// → fork1
cs.advanceDungeon();
// fork card
cs._drawDungeonCard();
// choose left
cs.advanceDungeonToFork('fork1', 'herbGarden');

console.log('Path after left fork:', JSON.stringify(sandbox.gameState.dungeonPath));
// Should be ['entrance', 'fork1', 'herbGarden']
if (sandbox.gameState.dungeonPath.length !== 3) throw new Error('Expected 3 nodes in path');
if (sandbox.gameState.dungeonPath[0] !== 'entrance') throw new Error('Expected entrance at index 0');
if (sandbox.gameState.dungeonPath[1] !== 'fork1') throw new Error('Expected fork1 at index 1');
if (sandbox.gameState.dungeonPath[2] !== 'herbGarden') throw new Error('Expected herbGarden at index 2');

// fork event fired?
var forkEventFired = false;
sandbox.eventBus.on('dungeon:forkChosen', function() { forkEventFired = true; });
cs.advanceDungeonToFork('herbGarden', 'reward'); // not a real fork, but test the event
// Wait, herbGarden is not a FORK node. Let's test with a real fork.

// Reset and test event
forkEventFired = false;
sandbox.gameState.dungeon = 'ancientCave';
sandbox.gameState.dungeonNodeId = null;
sandbox.gameState.dungeonPath = [];
cs._drawDungeonCard(); // entrance
cs.advanceDungeon(); // → fork1
cs._drawDungeonCard(); // fork
cs.advanceDungeonToFork('fork1', 'herbGarden');

if (!forkEventFired) throw new Error('Expected dungeon:forkChosen event to fire');
console.log('Fork event fired correctly');
console.log('PASS\n');

// ════════════════════════════════════════
// 测试 5: 向后兼容 — 旧版线性数组格式仍可用
// ════════════════════════════════════════
console.log('--- Test 5: Backward compatibility with linear array format ---');

// 临时替换 dataLoader 返回旧格式
var originalLoadSync = sandbox.dataLoader.loadSync;
sandbox.dataLoader.loadSync = function(key) {
  if (key === 'cards:qi') {
    return {
      realm: 'qi',
      cards: [],
      dungeons: {
        linearCave: {
          name: '线性洞穴',
          nodes: [
            { type: 'event', card: 'cave_spirit' },
            { type: 'battle', card: 'cave_beast_hard' },
            { type: 'reward', card: 'cave_reward' }
          ]
        }
      },
      dungeonCards: {
        cave_spirit: { id: 'cave_spirit', title: '洞中生灵', type: 'NORMAL', choices: {} },
        cave_beast_hard: { id: 'cave_beast_hard', title: '凶兽', type: 'COMBAT', choices: {} },
        cave_reward: { id: 'cave_reward', title: '宝藏', type: 'NORMAL', choices: {} }
      }
    };
  }
  return null;
};

sandbox.gameState.dungeon = 'linearCave';
sandbox.gameState.dungeonNodeIndex = 0;
sandbox.gameState.dungeonNodeId = null;
sandbox.gameState.dungeonPath = [];

var lc1 = cs._drawDungeonCard();
console.log('Linear card 1:', lc1.id, '(expect cave_spirit)');
if (lc1.id !== 'cave_spirit') throw new Error('Expected cave_spirit in linear mode');

cs.advanceDungeon();
var lc2 = cs._drawDungeonCard();
console.log('Linear card 2:', lc2.id, '(expect cave_beast_hard)');
if (lc2.id !== 'cave_beast_hard') throw new Error('Expected cave_beast_hard in linear mode');

cs.advanceDungeon();
var lc3 = cs._drawDungeonCard();
console.log('Linear card 3:', lc3.id, '(expect cave_reward)');
if (lc3.id !== 'cave_reward') throw new Error('Expected cave_reward in linear mode');

cs.advanceDungeon();
// After 3 nodes, dungeon should be null
console.log('After 3 advances, dungeon:', sandbox.gameState.dungeon);
if (sandbox.gameState.dungeon !== null) throw new Error('Expected dungeon=null after linear completion');

// 恢复
sandbox.dataLoader.loadSync = originalLoadSync;
console.log('PASS\n');

// ════════════════════════════════════════
// 测试 6: FORK 节点不自动推进
// ════════════════════════════════════════
console.log('--- Test 6: FORK node does not auto-advance ---');
sandbox.gameState.dungeon = 'ancientCave';
sandbox.gameState.dungeonNodeId = null;
sandbox.gameState.dungeonPath = [];

cs._drawDungeonCard(); // entrance
cs.advanceDungeon();   // → fork1
var nodeIdBeforeAdvance = sandbox.gameState.dungeonNodeId;
console.log('Node before advance at FORK:', nodeIdBeforeAdvance);

// advanceDungeon at FORK should NOT move
cs.advanceDungeon();
var nodeIdAfterAdvance = sandbox.gameState.dungeonNodeId;
console.log('Node after advance at FORK:', nodeIdAfterAdvance);

if (nodeIdBeforeAdvance !== nodeIdAfterAdvance) {
  throw new Error('FORK node should not auto-advance! Before: ' + nodeIdBeforeAdvance + ', After: ' + nodeIdAfterAdvance);
}
console.log('FORK node correctly stays in place until player chooses');
console.log('PASS\n');

console.log('═════════════════════════════════════════');
console.log('  All FIX-4 dungeon graph tests passed! ✓');
console.log('═════════════════════════════════════════');
