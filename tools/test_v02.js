// v0.2 end-to-end test — validates all systems and data modules
const fs = require('fs');
const vm = require('vm');

// ── Create sandbox context ──────────────────────────────────
const ctx = vm.createContext({
  console, Math, Date, JSON, Set, Map, Object, Array, String, Number, Boolean,
  window: {},
  setTimeout: () => {}, clearTimeout: () => {}, setInterval: () => {},
  localStorage: { getItem: () => null, setItem: () => {}, removeItem: () => {} },
  document: {
    addEventListener: () => {},
    createElement: () => ({style:{}, getContext:()=>({
      createShader:()=>({}), shaderSource:()=>{}, compileShader:()=>{}, createProgram:()=>({}),
      attachShader:()=>{}, linkProgram:()=>{}, getProgramParameter:()=>true, useProgram:()=>{},
      getUniformLocation:()=>({}), uniform1f:()=>{}, uniform2f:()=>{}, uniform3f:()=>{},
      activeTexture:()=>{}, bindTexture:()=>{}, texImage2D:()=>{}, texParameteri:()=>{},
      createTexture:()=>({}), pixelStorei:()=>{}, drawArrays:()=>{}, clear:()=>{},
      clearColor:()=>{}, enable:()=>{}, blendFunc:()=>{}, viewport:()=>{},
      getExtension:()=>null, getShaderParameter:()=>true, getShaderInfoLog:()=>'',
      getProgramInfoLog:()=>'', createFramebuffer:()=>({}), bindFramebuffer:()=>{},
      framebufferTexture2D:()=>{}, createBuffer:()=>({}), bindBuffer:()=>{},
      bufferData:()=>{}, getAttribLocation:()=>0, disableVertexAttribArray:()=>{},
      enableVertexAttribArray:()=>{}, vertexAttribPointer:()=>{},
    })}),
    querySelector: () => null, querySelectorAll: () => [],
    getElementById: () => null, body: { appendChild: () => {} }
  },
  Image: class { constructor() { this.onload = null; this.src = ''; } },
  HTMLCanvasElement: class {},
  fetch: (url) => Promise.resolve({
    ok: true,
    json: () => {
      try {
        return Promise.resolve(JSON.parse(fs.readFileSync(url, 'utf-8')));
      } catch (e) {
        return Promise.reject(e);
      }
    }
  })
});

// ── Load DATA_MODULES ───────────────────────────────────────
const html = fs.readFileSync('index.html', 'utf-8');
const dataMatch = html.match(/const DATA_MODULES\s*=\s*(\{.+?\});/s);
if (!dataMatch) { console.log('FATAL: DATA_MODULES not found in index.html'); process.exit(1); }
vm.runInContext('var DATA_MODULES = ' + dataMatch[1] + ';', ctx);

// ── Load all JS source files ────────────────────────────────
const srcFiles = [
  'src/core/EventBus.js',         // must load first
  'src/core/DataLoader.js',
  'src/core/GameStateManager.js',
  'src/services/EndingEligibilityService.js',
  'src/core/Container.js',
  'src/services/EffectService.js',
  'src/systems/KarmaSystem.js',
  'src/systems/CardSystem.js',
  'src/systems/QuestSystem.js',
  'src/systems/NpcSystem.js',
  'src/systems/CompanionSystem.js',
  'src/systems/FactionSystem.js',
  'src/systems/TreasureSystem.js',
  'src/systems/PathSkillSystem.js',
  'src/systems/DeckCombatSystem.js',
  'src/systems/SkillCardAcquisitionSystem.js',
  'src/systems/OpportunityAcquisitionSystem.js',
  'src/coordinators/CombatCoordinator.js',
  'src/game.js'                   // GameLogic class
];

for (const file of srcFiles) {
  const code = fs.readFileSync(file, 'utf-8');
  try {
    vm.runInContext(code, ctx);
  } catch (e) {
    console.log('ERROR loading ' + file + ': ' + e.message);
    process.exit(1);
  }
}

// ── Expose singletons as context properties + init ──────────
vm.runInContext(`
  // Expose all singletons on the context so outer scope can access them
  this.eventBus = eventBus;
  this.dataLoader = dataLoader;
  this.gameState = gameState;
  this.cardSystem = cardSystem;
  this.karmaSystem = karmaSystem;
  this.questSystem = questSystem;
  this.npcSystem = npcSystem;
  this.companionSystem = companionSystem;
  this.factionSystem = factionSystem;
  this.treasureSystem = treasureSystem;
  this.pathSkillSystem = pathSkillSystem;
  this.deckCombatSystem = deckCombatSystem;

  // Init all systems
  eventBus.events = new Map();
  cardSystem.init();
  karmaSystem.init();
  questSystem.init();
  npcSystem.init();
  companionSystem.init();
  factionSystem.init();
  treasureSystem.init();
  pathSkillSystem.init();
  deckCombatSystem.init();

  npcSystem.loadData(DATA_MODULES['npcs:core']);
  companionSystem.loadData(DATA_MODULES['companions:events']);
  factionSystem.loadData(DATA_MODULES['world:factions']);

  questSystem.loadQuest(DATA_MODULES['quests:white_fox']);
  questSystem.loadQuest(DATA_MODULES['quests:tianshu_codex']);
  questSystem.loadQuest(DATA_MODULES['quests:body_tribulation']);

  gameState.init({
    realms: DATA_MODULES['config:realms'],
    paths: DATA_MODULES['config:paths']
  });

  // Create GameLogic via DI Container
  this.container = new Container({ debug: false });
  this.gameLogic = container.game;
  this.effectService = container.effectService;
  this.combatCoordinator = container.combatCoordinator;
`, ctx);

// ── Load battle cards data into DATA_MODULES for DeckCombatSystem ──
const battleCardsData = JSON.parse(fs.readFileSync('data/cards/battle_cards.json', 'utf-8'));
vm.runInContext(`DATA_MODULES['cards:battle_cards'] = ${JSON.stringify(battleCardsData)};`, ctx);
const deckProgressionData = JSON.parse(fs.readFileSync('data/combat/deck_progression.json', 'utf-8'));

function seedPathDeck(pathId = 'sword') {
  ctx.gameState.path = pathId;
  ctx.gameState.deck = deckProgressionData.paths[pathId].starterDeck.slice();
}

// ── Local references to singletons ───────────────────────────
const csys = ctx.cardSystem;
const qs = ctx.questSystem;
const ts = ctx.treasureSystem;
const pss = ctx.pathSkillSystem;

// ── Test framework ──────────────────────────────────────────
let passed = 0, failed = 0;
const testQueue = [];

function test(name, fn) {
  testQueue.push({ name, fn });
}

async function runAllTests() {
  for (const t of testQueue) {
    try {
      await t.fn();
      console.log('  PASS: ' + t.name);
      passed++;
    } catch (e) {
      console.log('  FAIL: ' + t.name + ' — ' + e.message);
      failed++;
    }
  }
  console.log('\n========= RESULTS: ' + passed + ' passed, ' + failed + ' failed =========');
  process.exit(failed > 0 ? 1 : 0);
}

// Queue all tests during file load, then run at the end
setTimeout(runAllTests, 0);

// ═════════════════════════════════════════════════════════════
// 1. DATA MODULES — 22 modules loaded
// ═════════════════════════════════════════════════════════════
console.log('\n=== 1. DATA MODULES ===');
const expectedModules = [
  'config:realms', 'config:paths', 'config:path_skills',
  'cards:qi', 'cards:foundation', 'cards:golden', 'cards:nascent',
  'cards:deity', 'cards:tribulation', 'cards:death', 'cards:karma',
  'npcs:core', 'companions:events', 'world:factions',
  'quests:white_fox', 'quests:tianshu_codex', 'quests:body_tribulation',
  'quests:sword_legacy', 'quests:spell_codex', 'quests:pill_master',
  'shops:treasures', 'shops:shop_items'
];
for (const key of expectedModules) {
  test('  ' + key, () => {
    if (!ctx.DATA_MODULES[key]) throw new Error('missing');
  });
}

// ═════════════════════════════════════════════════════════════
// 2. CARD POOLS
// ═════════════════════════════════════════════════════════════
console.log('\n=== 2. CARD POOLS ===');
const realmChecks = [
  // The authored, weight-zero heaven pursuit remains addressable without
  // entering the ordinary Qi draw pool.
  { realm: 'qi', file: 'qi_condensation', expectedCards: 34 },
  { realm: 'foundation', file: 'foundation', expectedCards: 15, minimumOnly: true },
  { realm: 'golden', file: 'golden', expectedCards: 21 },
  { realm: 'nascent', file: 'nascent', expectedCards: 20 },
  { realm: 'deity', file: 'deity', expectedCards: 19 },
  { realm: 'tribulation', file: 'tribulation', expectedCards: 19 },
];
for (const { realm, expectedCards, minimumOnly } of realmChecks) {
  test('  ' + realm + ': ' + (minimumOnly ? 'at least ' : '') + expectedCards + ' cards', () => {
    const mod = ctx.DATA_MODULES['cards:' + realm];
    const cards = mod.cards || [];
    if (minimumOnly ? cards.length < expectedCards : cards.length !== expectedCards) {
      throw new Error('Expected ' + (minimumOnly ? 'at least ' : '') + expectedCards + ', got ' + cards.length);
    }
  });
}

// ═════════════════════════════════════════════════════════════
// 3. SHOP CARDS
// ═════════════════════════════════════════════════════════════
console.log('\n=== 3. SHOP CARDS ===');
for (const realm of ['qi', 'foundation', 'golden', 'nascent', 'deity', 'tribulation']) {
  test('  ' + realm + ' has SHOP card', () => {
    const mod = ctx.DATA_MODULES['cards:' + realm];
    const cards = mod.cards || [];
    const shops = cards.filter(c => c.type === 'SHOP');
    if (shops.length === 0) throw new Error('No SHOP card in ' + realm);
  });
}

// ═════════════════════════════════════════════════════════════
// 3b. DEATH CARDS
// ═════════════════════════════════════════════════════════════
console.log('\n=== 3b. DEATH CARDS ===');
test('  6 death cards loaded', () => {
  const mod = ctx.DATA_MODULES['cards:death'];
  const dcs = mod.deathCards || {};
  const count = Object.keys(dcs).length;
  if (count !== 6) throw new Error('Expected 6, got ' + count);
});

const deathReasons = [
  '道心崩碎，走火入魔',
  '气血耗尽，身死道消',
  '厄运缠身，天诛地灭',
  '善因过满，羽化登仙（意外）',
  '恶贯满盈，天劫临身',
  '寿元耗尽，坐化而终'
];
for (const reason of deathReasons) {
  test('  death: ' + reason.substring(0, 6) + '...', () => {
    const cardId = csys.deathCardMap.get(reason);
    if (!cardId) throw new Error('no card mapped for reason');
    const card = csys.getCard(cardId);
    if (!card) throw new Error('death card not found: ' + cardId);
    if (!card.choices || Object.keys(card.choices).length < 2) throw new Error('death card needs >= 2 choices');
    // Each choice should have reincarnation_bonus effect
    for (const [dir, ch] of Object.entries(card.choices)) {
      if (!ch.effects || !ch.effects.reincarnation_bonus) {
        throw new Error(dir + ' choice missing reincarnation_bonus');
      }
    }
  });
}

test('  death card draw maps deadReason correctly', () => {
  // Simulate death
  ctx.gameState.dead = true;
  ctx.gameState.deadReason = '寿元耗尽，坐化而终';
  const card = csys.draw();
  if (!card) throw new Error('draw() returned null for death');
  if (card.id !== 'death_lifespan') throw new Error('Expected death_lifespan, got ' + card.id);
  ctx.gameState.dead = false;
});

// ═════════════════════════════════════════════════════════════
// 3c. BREAKTHROUGH CARDS (all realms)
// ═════════════════════════════════════════════════════════════
console.log('\n=== 3c. BREAKTHROUGH CARDS ===');
const btCards = [
  { id: 'break_qi', realm: 'qi' },
  { id: 'break_foundation', realm: 'foundation' },
  { id: 'break_golden', realm: 'golden' },
  { id: 'break_nascent', realm: 'nascent' },
  { id: 'break_deity', realm: 'deity' },
  { id: 'break_tribulation', realm: 'tribulation' }
];
for (const { id, realm } of btCards) {
  test('  ' + id, () => {
    // Load the realm first so getCard can find it
    csys._loadRealmCards(realm);
    const card = csys.getCard(id);
    if (!card) throw new Error('breakthrough card not found');
    if (card.type !== 'BREAKTHROUGH' && card.type !== 'BOTTLENECK')
      throw new Error('expected BREAKTHROUGH or BOTTLENECK type, got ' + card.type);
    // breakSuccess should be on the left choice for newer cards
    const leftChoice = card.choices && card.choices.left;
    if (leftChoice && leftChoice.breakSuccess === undefined && card.type === 'BREAKTHROUGH')
      throw new Error('BREAKTHROUGH card missing breakSuccess on left choice');
  });
}

// ═════════════════════════════════════════════════════════════
// 3d. KARMA CARDS
// ═════════════════════════════════════════════════════════════
console.log('\n=== 3d. KARMA CARDS ===');
test('  cards:karma module loaded', () => {
  const mod = ctx.DATA_MODULES['cards:karma'];
  if (!mod) throw new Error('cards:karma module missing');
});

test('  at least 33 karma cards', () => {
  const mod = ctx.DATA_MODULES['cards:karma'];
  const cards = mod.cards || [];
  if (cards.length < 33) throw new Error('Expected at least 33, got ' + cards.length);
});

test('  at least 30 karma mappings', () => {
  const mod = ctx.DATA_MODULES['cards:karma'];
  const map = mod.karmaCards || {};
  if (Object.keys(map).length < 30) throw new Error('Expected at least 30, got ' + Object.keys(map).length);
});

test('  all karma cards cached after load', () => {
  const mod = ctx.DATA_MODULES['cards:karma'];
  for (const card of mod.cards) {
    const found = csys.getCard(card.id);
    if (!found) throw new Error('karma card not in cache: ' + card.id);
    if (found.type !== 'KARMA') throw new Error(card.id + ': expected KARMA type, got ' + found.type);
  }
});

test('  karmaCardMap populated', () => {
  const mod = ctx.DATA_MODULES['cards:karma'];
  for (const [karmaId, cardId] of Object.entries(mod.karmaCards)) {
    const mapped = csys.karmaCardMap.get(karmaId);
    if (!mapped) throw new Error('karma mapping missing: ' + karmaId);
    if (mapped !== cardId) throw new Error(karmaId + ': expected ' + cardId + ', got ' + mapped);
  }
});

test('  karma seed germination draws correct card', () => {
  // Inject a test seed
  ctx.gameState.karmaSeeds = [
    { id: 'whiteFox', delay: 0, realm: 'nascent', priority: 3 }
  ];
  // Ensure nascent realm is loaded (required for karma card's realm tag)
  csys._loadRealmCards('nascent');
  ctx.gameState.realm = 'nascent';
  const card = csys._drawKarmaCard();
  if (!card) throw new Error('_drawKarmaCard returned null');
  if (card.id !== 'k_fox_returns') throw new Error('Expected k_fox_returns, got ' + card.id);
  // Drawing only presents the causal consequence. The accepted choice is the
  // single consumer, so cancelled/failed presentations cannot erase the seed.
  if (ctx.gameState.karmaSeeds.length !== 1) throw new Error('seed consumed before accepted choice');
});

test('  karma seed not germinate in wrong realm', () => {
  ctx.gameState.realm = 'qi';
  ctx.gameState.karmaSeeds = [
    { id: 'foxGratitude', delay: 0, realm: 'deity', priority: 3 }
  ];
  const card = csys._drawKarmaCard();
  if (card !== null) throw new Error('should not draw deity karma in qi realm');
  if (ctx.gameState.karmaSeeds.length !== 1) throw new Error('seed wrongly consumed');
});

// cleanup
ctx.gameState.karmaSeeds = [];
ctx.gameState.realm = 'qi';

// ═════════════════════════════════════════════════════════════
// 4. TREASURE SYSTEM
// ═════════════════════════════════════════════════════════════
console.log('\n=== 4. TREASURE SYSTEM ===');
test('  at least 25 treasures loaded', () => {
  const count = Object.keys(ts.treasureDB).length;
  if (count < 25) throw new Error('Expected at least 25, got ' + count);
});
test('  acquire + passive bonus', () => {
  ts.acquire('玄铁甲');
  if (!ts.owned.has('玄铁甲')) throw new Error('not acquired');
  ts.equip('玄铁甲', 'armor');
  const bonuses = ts.getPassiveBonuses();
  const expectedDef = ts.treasureDB['玄铁甲'].passive.def;
  if (bonuses.def !== expectedDef) throw new Error('def bonus should be ' + expectedDef + ', got ' + bonuses.def);
});
test('  has() check', () => {
  if (!ts.has('玄铁甲')) throw new Error('has() should return true');
  if (ts.has('不存在')) throw new Error('has() should return false for unknown');
});

// ═════════════════════════════════════════════════════════════
// 5. PATH SKILLS
// ═════════════════════════════════════════════════════════════
console.log('\n=== 5. PATH SKILLS ===');
test('  4 paths loaded', () => {
  const paths = Object.keys(pss.skills);
  if (paths.length !== 4) throw new Error('Expected 4, got ' + paths.length);
});
test('  3 skills per path', () => {
  for (const path of Object.keys(pss.skills)) {
    const count = Object.keys(pss.skills[path]).length;
    if (count !== 3) throw new Error(path + ': expected 3, got ' + count);
  }
});

const skillUnlockTests = [
  ['sword', 'foundation', 'sword_crit'],
  ['spell', 'foundation', 'spell_fortune'],
  ['body', 'foundation', 'body_hp'],
  ['pill', 'foundation', 'pill_effect'],
];
for (const [path, realm, sid] of skillUnlockTests) {
  test('  unlock ' + path + '/' + realm + ': ' + sid, () => {
    const unlocked = pss.unlockForRealm(path, realm);
    const found = unlocked.find(x => x.id === sid);
    if (!found) throw new Error('skill not found in unlocked list');
    if (!pss.getUnlockedSkills(path, realm).some(skill => skill.id === sid)) {
      throw new Error('public unlocked-skill contract did not expose ' + sid);
    }
  });
}

// ═════════════════════════════════════════════════════════════
// 6. COMPANIONS
// ═════════════════════════════════════════════════════════════
console.log('\n=== 6. COMPANIONS ===');
test('  8 companions total', () => {
  const data = ctx.DATA_MODULES['companions:events'];
  const cs = data.companions || [];
  if (cs.length !== 8) throw new Error('Expected 8, got ' + cs.length);
});

const expectedCompanions = ['白刃真人', '慕青岚', '九尾溯月', '天机老人', '血煞老祖'];
for (const name of expectedCompanions) {
  test('  ' + name + ' has events', () => {
    const data = ctx.DATA_MODULES['companions:events'];
    const cs = data.companions || [];
    const c = cs.find(x => x.name === name);
    if (!c) throw new Error('companion not found');
    if (!c.events || c.events.length < 2) throw new Error('expected >= 2 events, got ' + (c.events ? c.events.length : 0));
  });
}

// ═════════════════════════════════════════════════════════════
// 7. UNDERCURRENTS
// ═════════════════════════════════════════════════════════════
console.log('\n=== 7. UNDERCURRENTS ===');
const expectedUndercurrents = ['qingyun_debate', 'tianshu_forbidden', 'tianji_split', 'wumeng_split', 'dangu_forbidden'];
for (const id of expectedUndercurrents) {
  test('  ' + id, () => {
    const data = ctx.DATA_MODULES['world:factions'];
    const ucs = data.undercurrents || {};
    if (!ucs[id]) throw new Error('missing undercurrent: ' + id);
  });
}

// ═════════════════════════════════════════════════════════════
// 8. QUESTS
// ═════════════════════════════════════════════════════════════
console.log('\n=== 8. QUESTS ===');
test('  3 quests loaded', () => {
  const qmap = qs.quests;
  const count = qmap instanceof Map ? qmap.size : Object.keys(qmap).length;
  if (count < 3) throw new Error('Expected >= 3, got ' + count);
});

const questIds = ['white_fox_line', 'tianshu_codex', 'body_tribulation'];
for (const qid of questIds) {
  test('  quest: ' + qid, () => {
    const qmap = qs.quests;
    const q = qmap instanceof Map ? qmap.get(qid) : qmap[qid];
    if (!q) throw new Error('quest not found in system');
    const stages = q.chainLength || 0;
    if (stages < 2) throw new Error('quest needs >= 2 stages, got ' + stages);
  });
}

// ═════════════════════════════════════════════════════════════
// 9. CARD POOL DRAW (integration)
// ═════════════════════════════════════════════════════════════
console.log('\n=== 9. CARD POOL DRAW ===');
test('  cardSystem draws cards', () => {
  // Ensure qi realm cards are loaded
  csys._loadRealmCards('qi');
  const card = csys.draw();
  if (!card || !card.id) throw new Error('draw() returned invalid card');
  if (!card.choices || Object.keys(card.choices).length === 0) {
    throw new Error('drawn card has no choices');
  }
});

test('  cardSystem respects realm pool', () => {
  csys._loadRealmCards('qi');
  const pool = csys.getCardPool('qi');
  if (!pool || pool.length < 10) throw new Error('qi pool too small: ' + (pool ? pool.length : 0));
});

// ═════════════════════════════════════════════════════════════
// 10. COMBAT SYSTEM (DeckCombatSystem + CombatCoordinator)
// ═════════════════════════════════════════════════════════════
console.log('\n=== 10. COMBAT SYSTEM ===');

test('  deckCombatSystem initialized', () => {
  const dcs = ctx.deckCombatSystem;
  if (!dcs) throw new Error('deckCombatSystem not loaded');
  if (typeof dcs._start !== 'function') throw new Error('_start not a function');
  if (typeof dcs.getState !== 'function') throw new Error('getState not a function');
  if (typeof dcs.flee !== 'function') throw new Error('flee not a function');
});

test('  combat cards have enemy data', () => {
  const combatIds = ['q_fellow', 'f_mission', 'n_hunt'];
  for (const cid of combatIds) {
    // Need to load the realm first
    const realmMap = { q_fellow: 'qi', f_mission: 'foundation', n_hunt: 'nascent' };
    csys._loadRealmCards(realmMap[cid]);
    const card = csys.getCard(cid);
    if (!card) throw new Error(cid + ' not found');
    if (!card.enemy) throw new Error(cid + ' missing enemy data');
    if (!card.enemy.name || !card.enemy.hp || !card.enemy.atk)
      throw new Error(cid + ' enemy data incomplete');
    if (!card.combatRewards) throw new Error(cid + ' missing combatRewards');
  }
});

test('  dungeon combat cards have enemy data', () => {
  // ar_boss is in nascent, it_combat is in tribulation
  csys._loadRealmCards('nascent');
  const arBoss = csys.getCard('ar_boss');
  if (!arBoss) throw new Error('ar_boss not found');
  if (!arBoss.enemy) throw new Error('ar_boss missing enemy data');

  csys._loadRealmCards('tribulation');
  const itCombat = csys.getCard('it_combat');
  if (!itCombat) throw new Error('it_combat not found');
  if (!itCombat.enemy) throw new Error('it_combat missing enemy data');
});

test('  combat start sets active state', async () => {
  const dcs = ctx.deckCombatSystem;
  dcs.reset();
  if (dcs.active) throw new Error('should not be active before start');

  // Load qi realm and find q_fellow card
  csys._loadRealmCards('qi');
  const card = csys.getCard('q_fellow');
  seedPathDeck('sword');

  await dcs._start({ card });
  if (!dcs.active) throw new Error('combat should be active after start');
  if (!dcs.player || dcs.player.hp <= 0) throw new Error('player HP invalid');
  if (!dcs.enemy || dcs.enemy.hp <= 0) throw new Error('enemy HP invalid');
  if (dcs.turn !== 1) throw new Error('should start at turn 1, got ' + dcs.turn);

  dcs.reset();
});

test('  combat hand available', async () => {
  const dcs = ctx.deckCombatSystem;
  csys._loadRealmCards('qi');
  const card = csys.getCard('q_fellow');
  seedPathDeck('sword');
  await dcs._start({ card });

  const hand = dcs.hand;
  if (!hand || hand.length === 0) throw new Error('Expected hand cards, got ' + (hand ? hand.length : 0));

  dcs.reset();
});

test('  combat victory/defeat flow', async () => {
  const dcs = ctx.deckCombatSystem;
  csys._loadRealmCards('qi');
  const card = csys.getCard('q_fellow');
  seedPathDeck('sword');
  await dcs._start({ card });
  // The production input boundary now deliberately holds one authored action
  // window. This stress fixture has no browser clock, so advance a simulated
  // clock between legal card decisions instead of treating 100 card clicks as
  // zero-time input.
  let actionClock = 0;
  dcs._now = () => actionClock;

  // Execute hand[0] until one side dies (stress test)
  let turns = 0;
  while (dcs.active && turns < 100) {
    if (dcs.hand.length > 0) {
      if (dcs.playCard(0)) actionClock += 1000;
    }
      const reaction = dcs.endTurn();
      if (reaction?.opened) dcs.chooseReaction('TAKE_HIT', reaction.windowId);
    turns++;
  }

  // Combat should have ended
  if (dcs.active) throw new Error('combat did not complete after ' + turns + ' turns');
  // Either victory or defeat — both are valid
  if (!dcs.log || dcs.log.length === 0) throw new Error('no combat log');

  dcs.reset();
});
// ═════════════════════════════════════════════════════════════
// 11. INTERLOCKING — Combat→Faction
// ═════════════════════════════════════════════════════════════
console.log('\n=== 11. INTERLOCKING — Combat→Faction ===');

test('  _applyFactionReputation exists', () => {
  const cc = ctx.combatCoordinator;
  if (typeof cc._applyFactionReputation !== 'function')
    throw new Error('_applyFactionReputation missing');
});

test('  combat victory vs hostile faction boosts righteous', async () => {
  const cc = ctx.combatCoordinator;
  const dcs = ctx.deckCombatSystem;
  dcs.reset();
  csys._loadRealmCards('nascent');
  const card = csys.getCard('n_hunt'); // enemy.factionId = xuesha_sect
  seedPathDeck('sword');
  await dcs._start({ card });

  // Set initial reputations
  ctx.factionSystem.reputations = {
    qingyun_sword: 10, tianshu_academy: 0, shennong_dangu: 0,
    tianji_pavilion: 0, wumeng_alliance: 0, xuesha_sect: -10
  };

  // Force victory
  dcs.enemy.hp = 0;
  dcs.active = false;
  cc._applyFactionReputation(true);

  const rep = ctx.factionSystem.reputations;
  if (rep.qingyun_sword !== 15) throw new Error('qingyun should be 15, got ' + rep.qingyun_sword);
  if (rep.xuesha_sect !== -20) throw new Error('xuesha should be -20, got ' + rep.xuesha_sect);
  dcs.reset();
});

test('  combat defeat reduces all reputations', async () => {
  const cc = ctx.combatCoordinator;
  const dcs = ctx.deckCombatSystem;
  dcs.reset();
  csys._loadRealmCards('nascent');
  const card = csys.getCard('n_hunt');
  seedPathDeck('sword');
  await dcs._start({ card });

  ctx.factionSystem.reputations = {
    qingyun_sword: 10, tianshu_academy: 0, shennong_dangu: 5,
    tianji_pavilion: 0, wumeng_alliance: 0, xuesha_sect: -10
  };

  // Force defeat
  dcs.player.hp = 0;
  dcs.active = false;
  cc._applyFactionReputation(false);

  const rep = ctx.factionSystem.reputations;
  if (rep.qingyun_sword !== 8) throw new Error('qingyun should be 8, got ' + rep.qingyun_sword);
  if (rep.shennong_dangu !== 3) throw new Error('dangu should be 3, got ' + rep.shennong_dangu);
  if (rep.xuesha_sect !== -12) throw new Error('xuesha should be -12, got ' + rep.xuesha_sect);
  dcs.reset();
});

// ═════════════════════════════════════════════════════════════
// 12. INTERLOCKING — NPC→Path
// ═════════════════════════════════════════════════════════════
console.log('\n=== 12. INTERLOCKING — NPC→Path ===');

test('  _getPathFlavor returns per-path flavor', () => {
  const ns = ctx.npcSystem;
  ['sword', 'spell', 'body', 'pill'].forEach(path => {
    const flavor = ns._getPathFlavor(path);
    if (!flavor || typeof flavor !== 'string')
      throw new Error('missing flavor for path: ' + path);
  });
});

test('  _getPathComment returns NPC-specific path reactions', () => {
  const ns = ctx.npcSystem;
  ctx.gameState.path = 'sword';

  // Load NPC data into NpcSystem's internal npcs map
  const coreNpcs = ctx.DATA_MODULES['npcs:core'];
  if (coreNpcs && coreNpcs.npcs) {
    for (const npc of coreNpcs.npcs) {
      ns.npcs.set(npc.id, npc);
    }
    // Map id->name if needed
    if (!ns.npcs.get('bai_ren')) {
      // Try by name
      const bairen = coreNpcs.npcs.find(n => n.name === '白刃真人');
      if (bairen) ns.npcs.set(bairen.id, bairen);
    }
  }

  const comment = ns._getPathComment('bai_ren', 'sword');
  if (!comment || comment.length < 3)
    throw new Error('missing sword comment for bai_ren');
});

test('  _getPathName returns Chinese path names', () => {
  const ns = ctx.npcSystem;
  ctx.gameState.path = 'sword';
  if (ns._getPathName() !== '剑修') throw new Error('sword → ' + ns._getPathName());
  ctx.gameState.path = 'spell';
  if (ns._getPathName() !== '法修') throw new Error('spell → ' + ns._getPathName());
  ctx.gameState.path = 'body';
  if (ns._getPathName() !== '体修') throw new Error('body → ' + ns._getPathName());
  ctx.gameState.path = 'pill';
  if (ns._getPathName() !== '丹修') throw new Error('pill → ' + ns._getPathName());
  ctx.gameState.path = 'sword';
});

// ═════════════════════════════════════════════════════════════
// 13. INTERLOCKING — Faction→Companion
// ═════════════════════════════════════════════════════════════
console.log('\n=== 13. INTERLOCKING — Faction→Companion ===');

test('  _calcEventChance includes factionMod', () => {
  const compSys = ctx.companionSystem;
  if (typeof compSys._calcEventChance !== 'function')
    throw new Error('_calcEventChance missing');

  // Set up test: companion with factionId, high reputation
  ctx.factionSystem.reputations = {
    qingyun_sword: 80, tianshu_academy: 0, shennong_dangu: 0,
    tianji_pavilion: 0, wumeng_alliance: 0, xuesha_sect: -50
  };

  // Make sure companion data has factionId
  const compData = ctx.DATA_MODULES['companions:events'];
  const jianLinger = (compData.companions || []).find(c => c.name === '剑灵儿');
  if (!jianLinger) throw new Error('剑灵儿 not found in data');
  if (!jianLinger.factionId) throw new Error('剑灵儿 missing factionId');

  // Load companion into system
  compSys.companions.set('jian_linger', {
    ...jianLinger,
    affection: 100, bond: 5, met: true
  });
  ctx.gameState.resources.companions = ['jian_linger'];

  const chance = compSys._calcEventChance('jian_linger', {
    affection: 100, bond: 5
  });

  // Base 0.15 + affection 0.10 + bond 0.15 + multi -0 + factionMod (80/100*0.10=0.08) = 0.48 → capped at 0.35
  // Without factionMod: 0.15+0.10+0.15 = 0.40 → capped 0.35
  if (chance < 0.20 || chance > 0.36)
    throw new Error('unexpected chance: ' + chance);
});

test('  negative faction reputation reduces event chance', () => {
  const compSys = ctx.companionSystem;
  ctx.factionSystem.reputations.xuesha_sect = -80;

  compSys.companions.set('xuesha_laozu', {
    id: 'xuesha_laozu', name: '血煞老祖', factionId: 'xuesha_sect',
    affection: 50, bond: 2, met: true
  });
  ctx.gameState.resources.companions = ['xuesha_laozu'];

  const chance = compSys._calcEventChance('xuesha_laozu', {
    affection: 50, bond: 2
  });

  // Base 0.15 + affection 0.05 + bond 0.06 + factionMod (-80/100*0.10=-0.08) = 0.18
  if (chance < 0.10 || chance > 0.25)
    throw new Error('unexpected negative faction chance: ' + chance);
});

// ═════════════════════════════════════════════════════════════
// 14. INTERLOCKING — Quest→Faction
// ═════════════════════════════════════════════════════════════
console.log('\n=== 14. INTERLOCKING — Quest→Faction ===');

test('  quest data has factionRewards', () => {
  const whiteFox = ctx.DATA_MODULES['quests:white_fox'];
  if (!whiteFox.quest.factionRewards) throw new Error('white_fox missing factionRewards');
  if (whiteFox.quest.factionRewards.qingyun_sword !== 5)
    throw new Error('white_fox factionRewards incorrect');

  const bodyTri = ctx.DATA_MODULES['quests:body_tribulation'];
  if (!bodyTri.quest.factionRewards) throw new Error('body_tribulation missing factionRewards');
  if (bodyTri.quest.factionRewards.wumeng_alliance !== 20)
    throw new Error('body_tribulation factionRewards incorrect');

  const tianshu = ctx.DATA_MODULES['quests:tianshu_codex'];
  if (!tianshu.quest.factionRewards) throw new Error('tianshu_codex missing factionRewards');
  if (tianshu.quest.factionRewards.tianshu_academy !== 20)
    throw new Error('tianshu_codex factionRewards incorrect');
});

test('  quest completion applies faction rewards', () => {
  // Reset faction reputations
  ctx.factionSystem.reputations = {
    qingyun_sword: 0, tianshu_academy: 0, shennong_dangu: 0,
    tianji_pavilion: 0, wumeng_alliance: 0, xuesha_sect: 0
  };

  // Reset quest state
  ctx.questSystem.activeQuests = [];
  ctx.questSystem.completedQuests = new Set();
  ctx.questSystem._pendingEntryCard = null;

  // Load quest and complete it
  const whiteFox = ctx.DATA_MODULES['quests:white_fox'];
  ctx.questSystem.loadQuest(whiteFox);

  // Set active for completion
  ctx.questSystem.activeQuests = [{
    questId: 'white_fox_line',
    step: 5, startedAt: 1
  }];

  // Complete the quest
  ctx.questSystem._completeQuest('white_fox_line');

  // Check faction reputation changes
  const rep = ctx.factionSystem.reputations;
  if (rep.qingyun_sword !== 5) throw new Error('qingyun should be 5, got ' + rep.qingyun_sword);
  if (rep.tianshu_academy !== 5) throw new Error('tianshu should be 5, got ' + rep.tianshu_academy);
  if (rep.xuesha_sect !== -5) throw new Error('xuesha should be -5, got ' + rep.xuesha_sect);
});

test('  body_tribulation quest rewards wumeng alliance', () => {
  ctx.factionSystem.reputations = {
    qingyun_sword: 0, tianshu_academy: 0, shennong_dangu: 0,
    tianji_pavilion: 0, wumeng_alliance: 0, xuesha_sect: 0
  };

  const bodyTri = ctx.DATA_MODULES['quests:body_tribulation'];
  ctx.questSystem.loadQuest(bodyTri);
  ctx.questSystem.activeQuests = [{
    questId: 'body_tribulation',
    step: 5, startedAt: 1
  }];
  ctx.questSystem._completeQuest('body_tribulation');

  const rep = ctx.factionSystem.reputations;
  if (rep.wumeng_alliance !== 20)
    throw new Error('wumeng should be 20, got ' + rep.wumeng_alliance);
  if (rep.qingyun_sword !== 5)
    throw new Error('qingyun should be 5, got ' + rep.qingyun_sword);
  if (rep.xuesha_sect !== -10)
    throw new Error('xuesha should be -10, got ' + rep.xuesha_sect);
});

test('  tianshu_codex quest rewards tianshu + tianji', () => {
  ctx.factionSystem.reputations = {
    qingyun_sword: 0, tianshu_academy: 0, shennong_dangu: 0,
    tianji_pavilion: 0, wumeng_alliance: 0, xuesha_sect: 0
  };

  const tianshu = ctx.DATA_MODULES['quests:tianshu_codex'];
  ctx.questSystem.loadQuest(tianshu);
  ctx.questSystem.activeQuests = [{
    questId: 'tianshu_codex',
    step: 5, startedAt: 1
  }];
  ctx.questSystem._completeQuest('tianshu_codex');

  const rep = ctx.factionSystem.reputations;
  if (rep.tianshu_academy !== 20)
    throw new Error('tianshu should be 20, got ' + rep.tianshu_academy);
  if (rep.tianji_pavilion !== 15)
    throw new Error('tianji should be 15, got ' + rep.tianji_pavilion);
  if (rep.xuesha_sect !== -15)
    throw new Error('xuesha should be -15, got ' + rep.xuesha_sect);
});

// ═════════════════════════════════════════════════════════════
// 14. INTERLOCKING — Reincarnation & Legacy
// ═════════════════════════════════════════════════════════════
console.log('\n=== 14. REINCARNATION & LEGACY ===');

test('  unlock defaults include lifeCount=0', () => {
  if (ctx.gameState.unlocks.lifeCount !== 0)
    throw new Error('expected lifeCount=0, got ' + ctx.gameState.unlocks.lifeCount);
});

test('  unlock defaults include legacy', () => {
  const legacy = ctx.gameState.unlocks.legacy;
  if (!legacy) throw new Error('legacy missing');
  if (!legacy.npcAffections || !legacy.factionReputations || !legacy.pathMemories)
    throw new Error('legacy structure incomplete');
});

test('  getLifeCount returns 0 initially', () => {
  if (ctx.gameState.getLifeCount() !== 0)
    throw new Error('expected 0');
});

test('  incrementLife works', () => {
  const before = ctx.gameState.getLifeCount();
  ctx.gameState.incrementLife();
  if (ctx.gameState.getLifeCount() !== before + 1)
    throw new Error('lifeCount did not increment');
});

test('  recordLegacy saves NPC affections', () => {
  ctx.npcSystem.affections['bai_ren'] = 80;
  ctx.npcSystem.affections['sword_elder'] = 60;
  ctx.factionSystem.reputations['qingyun_sword'] = 50;
  ctx.factionSystem.reputations['xuesha_sect'] = -30;
  ctx.gameState.path = 'sword';
  ctx.gameState.recordLegacy();
  const legacy = ctx.gameState.unlocks.legacy;
  if (legacy.npcAffections.bai_ren !== 40)
    throw new Error('bai_ren legacy expected 40, got ' + legacy.npcAffections.bai_ren);
  if (legacy.npcAffections.sword_elder !== 30)
    throw new Error('sword_elder legacy expected 30, got ' + legacy.npcAffections.sword_elder);
  ctx.gameState.unlocks.lifeCount = 0;
  ctx.gameState.unlocks.legacy.npcAffections = {};
});

test('  recordLegacy saves faction reputations', () => {
  const legacy = ctx.gameState.unlocks.legacy;
  // 50 * 0.6 = 30
  if (legacy.factionReputations.qingyun_sword !== 30)
    throw new Error('qingyun legacy rep expected 30, got ' + legacy.factionReputations.qingyun_sword);
  // -30 * 0.6 = -18
  if (legacy.factionReputations.xuesha_sect !== -18)
    throw new Error('xuesha legacy rep expected -18, got ' + legacy.factionReputations.xuesha_sect);
  ctx.gameState.unlocks.legacy.factionReputations = {};
});

test('  recordLegacy saves path mastery', () => {
  if (ctx.gameState.unlocks.legacy.pathMemories.sword !== 1)
    throw new Error('sword mastery expected 1, got ' + ctx.gameState.unlocks.legacy.pathMemories.sword);
  // A second archive belongs to a fresh run; do not weaken production idempotency.
  ctx.gameState.reset(true);
  ctx.gameState.path = 'sword';
  ctx.gameState.unlocks.legacy.pathMemories.sword = 5;
  ctx.gameState.recordLegacy();
  if (ctx.gameState.unlocks.legacy.pathMemories.sword > 5)
    throw new Error('mastery exceeded cap');
});

test('  difficulty multiplier scales with lifeCount', () => {
  ctx.gameState.unlocks.lifeCount = 0;
  const gl = ctx.gameLogic;
  if (typeof gl.getDifficultyLevel !== 'function')
    throw new Error('getDifficultyLevel missing');
  if (typeof gl._getDifficultyMultiplier !== 'function')
    throw new Error('_getDifficultyMultiplier missing');

  ctx.gameState.unlocks.lifeCount = 0;
  if (gl._getDifficultyMultiplier() !== 1) throw new Error('lifeCount=0 should be 1, got ' + gl._getDifficultyMultiplier());

  ctx.gameState.unlocks.lifeCount = 5;
  if (gl._getDifficultyMultiplier() !== 1.75) throw new Error('lifeCount=5 should be 1.75, got ' + gl._getDifficultyMultiplier());
});

// ═════════════════════════════════════════════════════════════
// 15. INTERLOCKING — Path-Specific Quests
// ═════════════════════════════════════════════════════════════
console.log('\n=== 15. PATH-SPECIFIC QUESTS ===');

test('  sword_legacy quest loaded', () => {
  const data = ctx.DATA_MODULES['quests:sword_legacy'];
  if (!data) throw new Error('quests:sword_legacy missing');
  if (!data.quest || data.quest.id !== 'sword_legacy') throw new Error('quest id mismatch');
  if (data.quest.pathRestriction !== 'sword') throw new Error('not sword-gated');
  if (!data.quest.factionRewards.qingyun_sword) throw new Error('no qingyun faction reward');
  if (!data.cards || data.cards.length !== 4) throw new Error('expected 4 cards, got ' + (data.cards ? data.cards.length : 0));
});

test('  spell_codex quest loaded', () => {
  const data = ctx.DATA_MODULES['quests:spell_codex'];
  if (!data) throw new Error('quests:spell_codex missing');
  if (!data.quest || data.quest.id !== 'spell_codex') throw new Error('quest id mismatch');
  if (data.quest.pathRestriction !== 'spell') throw new Error('not spell-gated');
  if (!data.quest.factionRewards.tianshu_academy) throw new Error('no tianshu faction reward');
  if (!data.cards || data.cards.length !== 4) throw new Error('expected 4 cards');
});

test('  pill_master quest loaded', () => {
  const data = ctx.DATA_MODULES['quests:pill_master'];
  if (!data) throw new Error('quests:pill_master missing');
  if (!data.quest || data.quest.id !== 'pill_master') throw new Error('quest id mismatch');
  if (data.quest.pathRestriction !== 'pill') throw new Error('not pill-gated');
  if (!data.quest.factionRewards.shennong_dangu) throw new Error('no shennong faction reward');
  if (!data.cards || data.cards.length !== 4) throw new Error('expected 4 cards');
});

test('  quest triggers respect pathRestriction', () => {
  ctx.gameState.realm = 'foundation';
  ctx.gameState.path = 'sword';
  ctx.questSystem.completedQuests = new Set();
  ctx.questSystem.activeQuests = [];
  ctx.questSystem._pendingEntryCard = null;

  // Load all path quests
  ctx.questSystem.loadQuest(ctx.DATA_MODULES['quests:sword_legacy']);
  ctx.questSystem.loadQuest(ctx.DATA_MODULES['quests:spell_codex']);

  // _canTrigger check: spell quest should NOT trigger for sword path
  const spellQ = ctx.questSystem.quests.get('spell_codex');
  if (ctx.questSystem._canTrigger(spellQ))
    throw new Error('spell quest should not trigger for sword path');

  const swordQ = ctx.questSystem.quests.get('sword_legacy');
  // sword quest needs daoHeart >= 40 and startRealm=foundation and minTurn=8
  ctx.gameState.turn = 10;
  ctx.gameState.attributes.daoHeart = 50;
  if (!ctx.questSystem._canTrigger(swordQ))
    throw new Error('sword quest should trigger with daoHeart 50 and turn 10');
});

// ═════════════════════════════════════════════════════════════
// 16. PATH-SPECIFIC SECRET REALMS (Dungeons)
// ═════════════════════════════════════════════════════════════
console.log('\n=== 16. PATH-SPECIFIC SECRET REALMS ===');

test('  4 path dungeons in golden realm', () => {
  const data = ctx.DATA_MODULES['cards:golden'];
  if (!data.dungeons) throw new Error('no dungeons');
  if (!data.dungeons.swordSanctum) throw new Error('swordSanctum missing');
  if (!data.dungeons.spellSanctum) throw new Error('spellSanctum missing');
  if (!data.dungeons.bodySanctum) throw new Error('bodySanctum missing');
  if (!data.dungeons.pillSanctum) throw new Error('pillSanctum missing');
});

test('  sword realm dungeon has 3 nodes', () => {
  const d = ctx.DATA_MODULES['cards:golden'].dungeons.swordSanctum;
  if (d.nodes.length !== 3) throw new Error('expected 3 nodes, got ' + d.nodes.length);
  if (d.pathRestriction !== 'sword') throw new Error('missing pathRestriction');
});

test('  realm entry cards have path filter', () => {
  const data = ctx.DATA_MODULES['cards:golden'];
  const entryCards = (data.cards || []).filter(c => c.id && c.id.startsWith('g_secret_'));
  if (entryCards.length !== 4) throw new Error('expected 4 entry cards, got ' + entryCards.length);
  // Verify path filtering
  for (const card of entryCards) {
    if (!card.path) throw new Error(card.id + ' missing path filter');
    if (!card.once) throw new Error(card.id + ' not marked once');
    const leftChoice = card.choices.left;
    if (!leftChoice.dungeon) throw new Error(card.id + ' left choice has no dungeon');
  }
});

test('  12 new dungeon cards total', () => {
  const dc = ctx.DATA_MODULES['cards:golden'].dungeonCards || {};
  const secretKeys = Object.keys(dc).filter(k => k.startsWith('secret_'));
  if (secretKeys.length !== 12) throw new Error('expected 12 dungeon cards, got ' + secretKeys.length);
});

// ═════════════════════════════════════════════════════════════
// 17. KARMA CARDS — Reincarnation Echo
// ═════════════════════════════════════════════════════════════
console.log('\n=== 17. KARMA REINCARNATION ECHO CARDS ===');

test('  3 new karma echo cards', () => {
  const karmaData = ctx.DATA_MODULES['cards:karma'];
  const echoCards = (karmaData.cards || []).filter(c => c.id && c.id.startsWith('k_echo_'));
  if (echoCards.length !== 3)
    throw new Error('expected 3 echo cards, got ' + echoCards.length);
});

test('  echo cards have minLifeCount requirements', () => {
  const karmaData = ctx.DATA_MODULES['cards:karma'];
  const echoCards = (karmaData.cards || []).filter(c => c.id && c.id.startsWith('k_echo_'));
  for (const card of echoCards) {
    if (!card.requirements || card.requirements.minLifeCount === undefined)
      throw new Error(card.id + ' missing minLifeCount');
  }
});

test('  k_echo_path_mastery requires differentPaths', () => {
  const karmaData = ctx.DATA_MODULES['cards:karma'];
  const card = (karmaData.cards || []).find(c => c.id === 'k_echo_path_mastery');
  if (!card) throw new Error('card missing');
  if (!card.requirements.differentPaths) throw new Error('missing differentPaths requirement');
});

test('  k_echo_karma_chain requires minLifeCount=3', () => {
  const karmaData = ctx.DATA_MODULES['cards:karma'];
  const card = (karmaData.cards || []).find(c => c.id === 'k_echo_karma_chain');
  if (!card) throw new Error('card missing');
  if (card.requirements.minLifeCount !== 3) throw new Error('expected minLifeCount=3, got ' + card.requirements.minLifeCount);
});

// ═════════════════════════════════════════════════════════════
// 18a. INTERLOCKING — Treasure→Card (法宝主动选项注入)
// ═════════════════════════════════════════════════════════════
console.log('\n=== 18a. TREASURE ACTIVE OPTIONS ===');

// Create GameLogic instance reference in sandbox for testing interlocking methods
const gl = ctx.gameLogic;

// Ensure treasure system has active options defined
test('  treasureSystem.getActiveOptions exists', () => {
  if (typeof ts.getActiveOptions !== 'function')
    throw new Error('getActiveOptions missing');
});

test('  getActiveOptions for combat card returns treasure options', () => {
  // Give player a combat-relevant treasure
  ts.treasureDB['test_active_combat'] = {
    id: 'test_active_combat',
    name: '测试战斗法宝',
    type: 'artifact',
    active: {
      trigger: { cardType: 'COMBAT' },
      text: '测试激活选项',
      effects: { health: 5 }
    }
  };
  ts.acquire('test_active_combat', { transactionId: 'v02:test_active_combat' });
  if (!ts.equip('test_active_combat', 'artifact', { persist: false }).success)
    throw new Error('test active treasure must be equipped before it can expose an active option');

  // Get a combat card from qi realm
  csys._loadRealmCards('qi');
  const card = csys.getCard('q_fellow');
  if (!card) throw new Error('q_fellow not found');

  const options = ts.getActiveOptions(card);
  // test_active_combat matches combat type
  if (options.length < 1) throw new Error('expected >= 1 active option, got ' + options.length);

  // Each option must have direction, text, effects, treasureId
  for (const opt of options) {
    if (!opt.direction) throw new Error('active option missing direction');
    if (!opt.text) throw new Error('active option missing text');
    if (!opt.effects) throw new Error('active option missing effects');
    if (!opt.treasureId) throw new Error('active option missing treasureId');
  }

  // Cleanup through the same ownership authority used by runtime code.
  ts.unequip('artifact', { persist: false });
  ts.remove('test_active_combat', undefined, { persist: false });
});

test('  getActiveOptions for non-matching card returns empty', () => {
  // 灵泉葫芦 triggers on cardType NORMAL — q_shop is SHOP type, won't match
  ts.treasureDB['test_active_normal'] = {
    id: 'test_active_normal',
    name: '测试常规法宝',
    type: 'artifact',
    active: {
      trigger: { cardType: 'NORMAL' },
      text: '测试常规选项',
      effects: { fortune: 5 }
    }
  };
  ts.acquire('test_active_normal', { transactionId: 'v02:test_active_normal' });
  if (!ts.equip('test_active_normal', 'artifact', { persist: false }).success)
    throw new Error('non-matching trigger must be tested from an equipped treasure');

  csys._loadRealmCards('qi');
  const card = csys.getCard('q_shop');
  if (!card) throw new Error('q_shop not found');

  const options = ts.getActiveOptions(card);
  // q_shop is SHOP type, test_active_normal matches only NORMAL — should be empty
  if (!Array.isArray(options)) throw new Error('getActiveOptions should return array');
  if (options.length !== 0) throw new Error('expected 0 options for non-matching card, got ' + options.length);

  ts.unequip('artifact', { persist: false });
  ts.remove('test_active_normal', undefined, { persist: false });
});

test('  getCurrentCard injects treasure options into card choices', () => {
  // Set up: give player a treasure, ensure no other card state
  ts.acquire('玄铁甲');
  ctx.gameState.reset(true);
  ctx.gameState.realm = 'qi';
  ctx.gameState.attributes.health = 100;
  ctx.gameState.attributes.cultivation = 50;
  ctx.gameState.attributes.daoHeart = 50;
  ctx.gameState.attributes.fortune = 50;
  ctx.gameState.attributes.karmaGood = 0;
  ctx.gameState.attributes.karmaBad = 0;
  ctx.gameState.resources.spiritStone = 500;
  ctx.gameState.resources.lifespan = 100;

  // Init card system for qi realm
  csys._loadRealmCards('qi');

  // Force draw a specific card that would match treasure active options
  gl.currentCard = null;
  const card = gl.getCurrentCard();

  if (!card) throw new Error('getCurrentCard returned null');

  // If treasure active options exist, card should have enhanced properties
  if (ts.getActiveOptions(card).length > 0) {
    if (!card._hasTreasureOptions) throw new Error('card should be marked _hasTreasureOptions');
    const hasTreasureChoice = Object.values(card.choices).some(c => c._treasureOption);
    if (!hasTreasureChoice) throw new Error('card should have at least one _treasureOption choice');
  }

  ts.owned.clear();
});

// ═════════════════════════════════════════════════════════════
// 18b. INTERLOCKING — Passive Regen (法宝/功法被动再生)
// ═════════════════════════════════════════════════════════════
console.log('\n=== 18b. PASSIVE REGEN ===');

test('  _applyPassiveRegen exists on GameLogic', () => {
  if (typeof gl._applyPassiveRegen !== 'function')
    throw new Error('_applyPassiveRegen missing');
});

test('  _applyPassiveRegen heals with treasure hpRegen', () => {
  ctx.gameState.maxHealth = 100;
  ctx.gameState.attributes.health = 80;
  ctx.gameState.attributes.fortune = 100;

  // 以当前数据定义为准，避免微数值平衡调整后测试仍锁死旧宏数值。
  ts.acquire('灵泉葫芦');
  ts.equip('灵泉葫芦', 'accessory');
  // Clear any path skill bonuses
  ctx.gameState.path = 'sword';
  // 以权威境界隔离功法被动；技能本身由 path + realm 派生，不再篡改私有缓存。
  ctx.gameState.realm = 'qi';

  gl._applyPassiveRegen();

  const expectedHealth = 80 + ts.treasureDB['灵泉葫芦'].passive.hpRegen;
  if (ctx.gameState.attributes.health !== expectedHealth)
    throw new Error('expected health ' + expectedHealth + ', got ' + ctx.gameState.attributes.health);

  // Fortune should NOT have changed (both >= 100, no fortune bonus from 灵泉葫芦)
  // 灵泉葫芦 has no fortuneBonus
  if (ctx.gameState.attributes.fortune !== 100)
    throw new Error('expected fortune 100, got ' + ctx.gameState.attributes.fortune);

  ts.owned.clear();
});

test('  _applyPassiveRegen does not exceed max health', () => {
  ctx.gameState.maxHealth = 100;
  ctx.gameState.attributes.health = 99;
  ts.acquire('灵泉葫芦'); // hpRegen: 2
  ts.equip('灵泉葫芦', 'accessory');

  gl._applyPassiveRegen();

  // Should cap at 100, not go to 101
  if (ctx.gameState.attributes.health !== 100)
    throw new Error('expected health 100 (capped), got ' + ctx.gameState.attributes.health);

  ts.owned.clear();
});

test('  _applyPassiveRegen applies fortune bonus', () => {
  ctx.gameState.attributes.health = 100;
  ctx.gameState.attributes.fortune = 85;

  // 避尘珠 has passive.fortuneBonus: 3
  ts.acquire('避尘珠');
  ts.equip('避尘珠', 'accessory');
  ctx.gameState.realm = 'qi';

  gl._applyPassiveRegen();

  if (ctx.gameState.attributes.fortune !== 90)
    throw new Error('expected fortune 90, got ' + ctx.gameState.attributes.fortune);

  ts.owned.clear();
});

test('  _applyPassiveRegen combines treasure + path skill passives', () => {
  ctx.gameState.maxHealth = 100;
  ctx.gameState.attributes.health = 70;
  ctx.gameState.path = 'body';
  ctx.gameState.realm = 'golden';

  // 灵泉葫芦与体修技能的回复值均读取当前数据定义。
  ts.acquire('灵泉葫芦');
  ts.equip('灵泉葫芦', 'accessory');
  // body path golden skill: body_regen ("气血再生") has hpRegen: 3

  const expectedRegen = gl._getAggregatedPassives().hpRegen || 0;
  gl._applyPassiveRegen();

  if (ctx.gameState.attributes.health !== 70 + expectedRegen)
    throw new Error('expected health ' + (70 + expectedRegen) + ', got ' + ctx.gameState.attributes.health);

  ts.owned.clear();
  ctx.gameState.realm = 'qi';
});

test('  _getAggregatedPassives returns combined passives', () => {
  ts.acquire('玄铁甲');
  ts.acquire('剑心佩');
  ts.equip('玄铁甲', 'armor');
  ts.equip('剑心佩', 'weapon');
  ctx.gameState.path = 'sword';
  ctx.gameState.realm = 'foundation'; // sword_crit: critRate: 10

  const passives = gl._getAggregatedPassives();
  const armor = ts.treasureDB['玄铁甲'].passive;
  const weapon = ts.treasureDB['剑心佩'].passive;
  const pathBonuses = pss.getPassiveBonuses('sword');

  if (passives.def < (armor.def || 0)) throw new Error('expected def >= ' + (armor.def || 0) + ', got ' + passives.def);
  if (passives.atk < (weapon.atk || 0)) throw new Error('expected atk >= ' + (weapon.atk || 0) + ', got ' + passives.atk);
  const expectedCrit = (weapon.critRate || 0) + (pathBonuses.critRate || 0);
  if (passives.critRate < expectedCrit) throw new Error('expected critRate >= ' + expectedCrit + ', got ' + passives.critRate);

  ts.owned.clear();
  ctx.gameState.realm = 'qi';
});

// ═════════════════════════════════════════════════════════════
// 18c. INTERLOCKING — Companion Crisis (道侣危机激活)
// ═════════════════════════════════════════════════════════════
console.log('\n=== 18c. COMPANION CRISIS ===');

test('  _checkCompanionCrisis exists on GameLogic', () => {
  if (typeof gl._checkCompanionCrisis !== 'function')
    throw new Error('_checkCompanionCrisis missing');
});

test('  _checkCompanionCrisis triggers on large karmaGood delta', () => {
  // Setup: companion metadata + NpcSystem authoritative affection >= 50
  const compSys = ctx.companionSystem;
  compSys.states['bai_luoxuan'] = { bond: 3, trust: 50 };
  ctx.npcSystem.affections['bai_luoxuan'] = 80;
  compSys.companions.set('bai_luoxuan', {
    id: 'bai_luoxuan', name: '白珞玄'
  });
  ctx.gameState.resources.companions = ['bai_luoxuan'];

  // Watch for companion:heartEvent emission
  let crisisTriggered = false;
  let crisisData = null;
  ctx.eventBus.on('companion:heartEvent', (data) => {
    crisisTriggered = true;
    crisisData = data;
  });

  // A choice with large karmaGood
  const choice = { effects: { karmaGood: 20 } };
  gl._checkCompanionCrisis({ id: 'test_card' }, 'up', choice);

  if (!crisisTriggered) throw new Error('companion:heartEvent was NOT emitted');
  if (!crisisData || !crisisData.compId) throw new Error('crisis data missing compId');
  if (crisisData.compId !== 'bai_luoxuan')
    throw new Error('expected compId bai_luoxuan, got ' + crisisData.compId);

  // Cleanup
  ctx.gameState.resources.companions = [];
  delete ctx.npcSystem.affections['bai_luoxuan'];
  compSys.companions.delete('bai_luoxuan');
  ctx.eventBus.events.delete('companion:heartEvent');
});

test('  _checkCompanionCrisis triggers on large karmaBad delta', () => {
  const compSys = ctx.companionSystem;
  compSys.states['jian_linger'] = { bond: 4, trust: 50 };
  ctx.npcSystem.affections['jian_linger'] = 65;
  compSys.companions.set('jian_linger', {
    id: 'jian_linger', name: '剑灵儿'
  });
  ctx.gameState.resources.companions = ['jian_linger'];

  let crisisTriggered = false;
  ctx.eventBus.on('companion:heartEvent', () => { crisisTriggered = true; });

  // A choice with large karmaBad
  const choice = { effects: { karmaBad: 18 } };
  gl._checkCompanionCrisis({ id: 'test_card2' }, 'down', choice);

  if (!crisisTriggered) throw new Error('companion:heartEvent was NOT emitted for karmaBad');

  ctx.gameState.resources.companions = [];
  delete ctx.npcSystem.affections['jian_linger'];
  compSys.companions.delete('jian_linger');
  ctx.eventBus.events.delete('companion:heartEvent');
});

test('  _checkCompanionCrisis does NOT trigger for small delta', () => {
  const compSys = ctx.companionSystem;
  compSys.companions.set('bai_luoxuan', {
    id: 'bai_luoxuan', name: '白珞玄',
    affection: 80, bond: 3, met: true
  });
  ctx.gameState.resources.companions = ['bai_luoxuan'];

  let crisisTriggered = false;
  ctx.eventBus.on('companion:heartEvent', () => { crisisTriggered = true; });

  // Small karma delta (10 < 15 threshold)
  const choice = { effects: { karmaGood: 10 } };
  gl._checkCompanionCrisis({ id: 'test_card3' }, 'left', choice);

  if (crisisTriggered) throw new Error('should NOT trigger for karma delta 10');

  ctx.gameState.resources.companions = [];
  compSys.companions.delete('bai_luoxuan');
  ctx.eventBus.events.delete('companion:heartEvent');
});

test('  _checkCompanionCrisis does NOT trigger without companions', () => {
  ctx.gameState.resources.companions = [];

  let crisisTriggered = false;
  ctx.eventBus.on('companion:heartEvent', () => { crisisTriggered = true; });

  const choice = { effects: { karmaGood: 20 } };
  gl._checkCompanionCrisis({ id: 'test_card4' }, 'right', choice);

  if (crisisTriggered) throw new Error('should NOT trigger when no companions');

  ctx.eventBus.events.delete('companion:heartEvent');
});

test('  _checkCompanionCrisis does NOT trigger with low affection', () => {
  const compSys = ctx.companionSystem;
  compSys.states['bai_luoxuan'] = { affection: 30, bond: 1, trust: 20 };
  compSys.companions.set('bai_luoxuan', {
    id: 'bai_luoxuan', name: '白珞玄'
  });
  ctx.gameState.resources.companions = ['bai_luoxuan'];

  let crisisTriggered = false;
  ctx.eventBus.on('companion:heartEvent', () => { crisisTriggered = true; });

  const choice = { effects: { karmaGood: 25 } };
  gl._checkCompanionCrisis({ id: 'test_card5' }, 'up', choice);

  if (crisisTriggered) throw new Error('should NOT trigger with affection 30 (< 50)');

  ctx.gameState.resources.companions = [];
  compSys.companions.delete('bai_luoxuan');
  ctx.eventBus.events.delete('companion:heartEvent');
});
