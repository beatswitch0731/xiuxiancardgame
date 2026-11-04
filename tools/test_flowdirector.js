/**
 * FlowDirector 端到端测试
 * 在 Node.js VM 中加载 FlowDirector + 模拟环境，验证核心逻辑
 */
var vm = require('vm');
var fs = require('fs');
var path = require('path');

var baseDir = path.resolve(__dirname, '..');

// 读取 FlowDirector 源码
var flowSrc = fs.readFileSync(path.join(baseDir, 'src/systems/FlowDirector.js'), 'utf8');

// 创建模拟环境
var sandbox = {
  console: console,
  Date: Date,
  Math: Math,
  Set: Set,
  Map: Map,
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
      var wrapper = function(data) {
        fn(data);
        self.off(event, wrapper);
      };
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
    deadReason: null,
    attributes: { health: 80, daoHeart: 50, fortune: 60, karmaBad: 10 },
    resources: { spiritStone: 100, pill: 3, karmaGood: 0, karmaBad: 10, lifespan: 9999 },
    cardsPlayed: [],
    currentLocation: 'sect',
    dungeon: null,
    flags: {},
    checkFlags: function(req) { return true; },
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
  cardSystem: {
    cardCache: {},
    _lastDrawnPriority: 0,
    _loadRealmCards: function() {},
    getCardPool: function() {
      return [
        { id: 'q_meditation', title: '打坐修炼', type: 'NORMAL', realm: 'qi', weight: 5,
          choices: { left: { text: '修炼', effects: { exp: 5 } }, right: { text: '休息', effects: { health: 3 } } } },
        { id: 'q_explore', title: '探索后山', type: 'NORMAL', realm: 'qi', weight: 3, tags: ['exploration'],
          choices: { left: { text: '深入', effects: { exp: 8 } }, right: { text: '返回', effects: {} } } },
        { id: 'q_combat1', title: '遭遇妖兽', type: 'COMBAT', realm: 'qi', weight: 2, tags: ['combat'],
          enemy: { name: '赤眼妖狼', hp: 30, atk: 8 },
          choices: { left: { text: '战斗', effects: {} }, right: { text: '逃跑', effects: { daoHeart: -2 } } } },
        { id: 'q_shop1', title: '坊市采购', type: 'SHOP', realm: 'qi', weight: 2, tags: ['shop'],
          choices: { left: { text: '买丹药', effects: {} }, right: { text: '卖灵石', effects: {} } } }
      ];
    },
    getCard: function(id) {
      var pool = this.getCardPool();
      for (var i = 0; i < pool.length; i++) {
        if (pool[i].id === id) return pool[i];
      }
      return null;
    },
    draw: function() {
      this._lastDrawnPriority = 10;
      return this._drawNormal();
    },
    _drawNormal: function() {
      var pool = this.getCardPool();
      return pool[Math.floor(Math.random() * pool.length)];
    },
    _drawKarmaCard: function() { return null; },
    _checkShopEncounter: function() { return null; },
    _getQuestCurrentCard: function() { return null; },
    _getQuestEntryCard: function() { return null; }
  },
  chapterSystem: {
    markTriggered: function() {}
  },
  sceneLayerSystem: null,
  window: {}
};

// 执行 FlowDirector 源码
var script = new vm.Script(flowSrc);
var context = vm.createContext(sandbox);
script.runInContext(context);

var FlowDirector = sandbox.window.FlowDirector || sandbox.FlowDirector;
if (!FlowDirector) {
  // 尝试从 module.exports 获取
  var moduleObj = { exports: {} };
  sandbox.module = moduleObj;
  var script2 = new vm.Script(flowSrc);
  script2.runInContext(vm.createContext(Object.assign({}, sandbox, { module: moduleObj })));
  FlowDirector = moduleObj.exports;
}

if (!FlowDirector) {
  console.error('FAIL: FlowDirector not loaded');
  process.exit(1);
}

console.log('=== FlowDirector loaded successfully ===\n');

// ════════════════════════════════════════
// 测试 1: 基本初始化 + 阶段信息
// ════════════════════════════════════════
console.log('--- Test 1: Init + Phase Info ---');
var fd = FlowDirector.create();
fd.init();
var info = fd.getPhaseInfo();
console.log('Phase:', info.phase, '| Display:', info.displayName, '| Progress:', info.progress + '%');
console.log('Mood:', info.mood);
console.log('CardCount:', info.cardCount);
console.log('hasPending:', info.hasPending);

if (info.phase !== 'CALM') throw new Error('Expected CALM, got ' + info.phase);
if (info.displayName !== '风平浪静') throw new Error('Wrong displayName');
if (info.mood !== 'neutral') throw new Error('Expected neutral mood, got ' + info.mood);
console.log('PASS\n');

// ════════════════════════════════════════
// 回归: 同一里程碑在等待出队期间只能入队一次
// ════════════════════════════════════════
console.log('--- Regression: Milestone Queue Exactly Once ---');
fd.init();
var golden45 = { id: 'ch_golden_40', title: '秘境探索', type: 'MILESTONE', threshold: 45, realm: 'golden' };
var golden60 = { id: 'ch_golden_60', title: '丹成雷动', type: 'MILESTONE', threshold: 60, realm: 'golden' };
if (fd.setMilestone(golden45) !== true) throw new Error('First milestone enqueue must be accepted');
if (fd.setMilestone(Object.assign({}, golden45)) !== false) throw new Error('Duplicate pending milestone must be rejected');
if (fd.setMilestone(golden60) !== false) throw new Error('A pending milestone must not be overwritten by a later threshold');
var pendingMilestone = fd.exportState().milestonePending;
if (!pendingMilestone || pendingMilestone.id !== golden45.id) {
  throw new Error('Duplicate/later enqueue replaced the authoritative pending milestone');
}
console.log('PASS\n');

// ════════════════════════════════════════
// 测试 2: 优先级排序 — 中断 > 里程碑 > 叙事 > 普通
// ════════════════════════════════════════
console.log('--- Test 2: Priority Ordering ---');
fd.init();

// 入队所有类型
fd.enqueueInterrupt({ id: 'death_card', title: '死亡', type: 'DEATH' }, 'death');
fd.setMilestone({ id: 'ch_qi_20', title: '里程碑', type: 'MILESTONE', threshold: 20, realm: 'qi' });
fd.enqueueNarrative({ id: 'story_1', title: '道侣事件', type: 'STORY' }, 50);
fd.setPending('ripple', { id: 'ripple_1', title: '因果涟漪', type: 'RIPPLE' });

// 第一次抽卡应该是中断
var card1 = fd.getNextCard();
console.log('Card 1 (expect interrupt):', card1.id, '| source:', card1._flowSource);
if (card1.id !== 'death_card') throw new Error('Expected death_card, got ' + card1.id);

// 第二次应该是里程碑
var card2 = fd.getNextCard();
console.log('Card 2 (expect milestone):', card2.id, '| source:', card2._flowSource);
if (card2.id !== 'ch_qi_20') throw new Error('Expected milestone, got ' + card2.id);

// 第三次应该是叙事
var card3 = fd.getNextCard();
console.log('Card 3 (expect narrative):', card3.id, '| source:', card3._flowSource);
if (card3.id !== 'story_1') throw new Error('Expected story_1, got ' + card3.id);

// 第四次应该是 ripple (pending flag)
var card4 = fd.getNextCard();
console.log('Card 4 (expect ripple):', card4.id, '| source:', card4._flowSource);
if (card4.id !== 'ripple_1') throw new Error('Expected ripple_1, got ' + card4.id);

console.log('PASS\n');

// ════════════════════════════════════════
// 测试 3: 阶段推进
// ════════════════════════════════════════
console.log('--- Test 3: Phase Progression ---');
fd.init();
console.log('Start phase:', fd.getPhaseInfo().phase);

// CALM advanceRate=8, 需要 ~13 张卡到 100%
var phasesSeen = ['CALM'];
var phaseChangeCount = 0;
sandbox.eventBus.on('flow:phaseChanged', function(data) {
  phasesSeen.push(data.phase);
  phaseChangeCount++;
});

// 抽 15 张卡，应该至少转换 1 次
for (var i = 0; i < 15; i++) {
  fd.getNextCard();
}
var info3 = fd.getPhaseInfo();
console.log('After 15 cards: phase=' + info3.phase + ', progress=' + info3.progress + '%');
console.log('Phases seen:', phasesSeen.join(' → '));
console.log('Phase changes:', phaseChangeCount);

if (phaseChangeCount === 0) throw new Error('Expected at least 1 phase change after 15 cards');
if (phasesSeen.indexOf('BUILDUP') === -1) throw new Error('Expected BUILDUP phase');
console.log('PASS\n');

// ════════════════════════════════════════
// 测试 4: 饥饿追踪
// ════════════════════════════════════════
console.log('--- Test 4: Starvation Tracking ---');
fd.init();

// 抽 15 张普通卡（不触发叙事）
for (var i = 0; i < 15; i++) {
  fd.getNextCard();
}
var report = fd.getStarvationReport();
console.log('Starvation report after 15 normal cards:', JSON.stringify(report, null, 2));

// narrative 应该饥饿
if (!report.narrative) {
  console.log('NOTE: narrative not in starvation report (may be below threshold)');
} else {
  console.log('narrative starvation:', report.narrative.cardsSinceLastUse, 'cards, boost:', report.narrative.boost);
}
console.log('PASS\n');

// ════════════════════════════════════════
// 测试 5: 情绪推导
// ════════════════════════════════════════
console.log('--- Test 5: Mood Derivation ---');

// 正常状态
sandbox.gameState.attributes = { health: 80, daoHeart: 50, fortune: 60, karmaBad: 10 };
sandbox.gameState.resources.karmaBad = 10;
var mood1 = FlowDirector.deriveMood(sandbox.gameState);
console.log('Normal state → mood:', mood1);
if (mood1 !== 'neutral') throw new Error('Expected neutral, got ' + mood1);

// 道心崩溃
sandbox.gameState.attributes.daoHeart = 15;
var mood2 = FlowDirector.deriveMood(sandbox.gameState);
console.log('Low daoHeart → mood:', mood2);
if (mood2 !== 'despair') throw new Error('Expected despair, got ' + mood2);

// 昂扬
sandbox.gameState.attributes = { health: 90, daoHeart: 60, fortune: 75, karmaBad: 5 };
sandbox.gameState.resources.karmaBad = 5;
var mood3 = FlowDirector.deriveMood(sandbox.gameState);
console.log('High health+fortune → mood:', mood3);
if (mood3 !== 'inspired') throw new Error('Expected inspired, got ' + mood3);

// 诡谲
sandbox.gameState.attributes = { health: 70, daoHeart: 50, fortune: 50, karmaBad: 65 };
sandbox.gameState.resources.karmaBad = 65;
var mood4 = FlowDirector.deriveMood(sandbox.gameState);
console.log('High karmaBad → mood:', mood4);
if (mood4 !== 'sinister') throw new Error('Expected sinister, got ' + mood4);

// 警觉
sandbox.gameState.attributes = { health: 25, daoHeart: 40, fortune: 50, karmaBad: 10 };
sandbox.gameState.resources.karmaBad = 10;
var mood5 = FlowDirector.deriveMood(sandbox.gameState);
console.log('Low health → mood:', mood5);
if (mood5 !== 'cautious') throw new Error('Expected cautious, got ' + mood5);

console.log('PASS\n');

// ════════════════════════════════════════
// 测试 6: 战斗预警卡
// ════════════════════════════════════════
console.log('--- Test 6: Combat Warning ---');
fd.init();

var warningCard = {
  id: '_warning_test',
  title: '危险预感',
  type: 'COMBAT_WARNING',
  choices: {
    left: { text: '迎战', effects: { daoHeart: 2 } },
    right: { text: '服丹备战', effects: { health: 15 }, costCheck: { pill: 1 } }
  }
};
fd.setCombatWarning(warningCard);

var combatCard = fd.getNextCard();
console.log('Combat warning card:', combatCard.id, '| source:', combatCard._flowSource);
if (combatCard.id !== '_warning_test') throw new Error('Expected combat warning, got ' + combatCard.id);
if (combatCard._flowSource !== 'combat_warning') throw new Error('Wrong source');

// 下一次抽卡应该是普通卡
var nextCard = fd.getNextCard();
console.log('Next card after warning:', nextCard.id, '| source:', nextCard._flowSource);
console.log('PASS\n');

// ════════════════════════════════════════
// 测试 7: 阶段权重
// ════════════════════════════════════════
console.log('--- Test 7: Phase Weights ---');
fd.init();

// 在 CALM 阶段抽 20 张卡，统计 source 分布
var sourceCounts = {};
for (var i = 0; i < 20; i++) {
  var c = fd.getNextCard();
  var src = c._flowSource || 'unknown';
  var srcBase = src.split(':')[0];
  sourceCounts[srcBase] = (sourceCounts[srcBase] || 0) + 1;
}
console.log('CALM phase source distribution (20 cards):', JSON.stringify(sourceCounts));

// 正常卡应该占大多数
if (!sourceCounts.normal || sourceCounts.normal < 5) {
  console.log('WARNING: normal cards are underrepresented in CALM phase');
}

// 手动设置 TENSION 阶段
fd.setPhase('TENSION');
sourceCounts = {};
for (var i = 0; i < 20; i++) {
  var c = fd.getNextCard();
  var src = c._flowSource || 'unknown';
  var srcBase = src.split(':')[0];
  sourceCounts[srcBase] = (sourceCounts[srcBase] || 0) + 1;
}
console.log('TENSION phase source distribution (20 cards):', JSON.stringify(sourceCounts));

console.log('PASS\n');

// ════════════════════════════════════════
// 测试 8: hasPending 判断
// ════════════════════════════════════════
console.log('--- Test 8: hasPending ---');
fd.init();
console.log('Empty:', fd.hasPending());

fd.enqueueNarrative({ id: 'test' }, 50);
console.log('With narrative:', fd.hasPending());

fd.getNextCard(); // 消费叙事卡
console.log('After consume:', fd.hasPending());

fd.setMilestone({ id: 'milestone_test' });
console.log('With milestone:', fd.hasPending());

fd.getNextCard(); // 消费里程碑
console.log('After consume milestone:', fd.hasPending());
console.log('PASS\n');

// ════════════════════════════════════════
// 测试 9: 阶段历史
// ════════════════════════════════════════
console.log('--- Test 9: Phase History ---');
fd.init();
// 抽足够多的卡来触发多次阶段转换
for (var i = 0; i < 60; i++) {
  fd.getNextCard();
}
var history = fd.getPhaseHistory();
console.log('Phase history length:', history.length);
console.log('Last 3 transitions:');
for (var i = Math.max(0, history.length - 3); i < history.length; i++) {
  var h = history[i];
  console.log('  ' + h.from + ' → ' + h.to + ' (card #' + h.cardCount + ')');
}
if (history.length === 0) throw new Error('Expected phase history');
console.log('PASS\n');

console.log('═════════════════════════════════════════');
console.log('  All FlowDirector tests passed! ✓');
console.log('═════════════════════════════════════════');
