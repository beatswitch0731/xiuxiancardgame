// P0补全验证测试 — 使用单一 VM 上下文模拟完整游戏运行
const fs = require('fs');
const vm = require('vm');

// Build shared context
const context = {
    console, Math, Date, JSON, Set, Map, Object, Array, String, Number, Boolean,
    setTimeout: () => {}, clearTimeout: () => {}, setInterval: () => {},
    document: {
        addEventListener: () => {},
        createElement: () => ({ style: {} }),
        querySelector: () => null,
        querySelectorAll: () => [],
        getElementById: () => null,
        body: { appendChild: () => {} }
    },
    Image: class { constructor() { this.onload = null; this.src = ''; } },
    HTMLCanvasElement: class {},
    WebGLRenderingContext: class {},
    window: { location: { href: '' }, localStorage: { getItem:()=>null, setItem:()=>{}, removeItem:()=>{} } },
    global: {},
};
context.global = context;
vm.createContext(context);

// Run in shared context
function runInContext(codeStr, label) {
    try {
        const script = new vm.Script(codeStr);
        script.runInContext(context);
    } catch (e) {
        console.error('ERROR in', label, ':', e.message);
        process.exit(1);
    }
}

// Load DATA_MODULES
const html = fs.readFileSync('index.html', 'utf-8');
const dataMatch = html.match(/const DATA_MODULES = ({.+?});/s);
if (!dataMatch) { console.error('ERROR: DATA_MODULES not found'); process.exit(1); }
runInContext('const DATA_MODULES = ' + dataMatch[1] + ';', 'DATA_MODULES');

// Load all source files
const srcFiles = [
    'src/core/EventBus.js',
    'src/core/DataLoader.js',
    'src/core/GameStateManager.js',
    'src/systems/KarmaSystem.js',
    'src/systems/CardSystem.js',
    'src/systems/QuestSystem.js',
    'src/systems/NpcSystem.js',
    'src/systems/CompanionSystem.js',
    'src/systems/FactionSystem.js',
    'src/game.js'
];
for (const file of srcFiles) {
    const code = fs.readFileSync(file, 'utf-8');
    runInContext(code, file);
}

// Initialize all systems (replicating index.html init sequence)
runInContext('cardSystem.init();', 'init_cardSystem');
runInContext('karmaSystem.init();', 'init_karmaSystem');
runInContext('questSystem.init();', 'init_questSystem');
runInContext('npcSystem.init();', 'init_npcSystem');
runInContext('companionSystem.init();', 'init_companionSystem');
runInContext('factionSystem.init();', 'init_factionSystem');

// Load NPC/companion/faction/quest data
runInContext('npcSystem.loadData(DATA_MODULES["npcs:core"]);', 'load_npcs');
runInContext('companionSystem.loadData(DATA_MODULES["companions:events"]);', 'load_companions');
runInContext('factionSystem.loadData(DATA_MODULES["world:factions"]);', 'load_factions');
runInContext('questSystem.loadQuest(DATA_MODULES["quests:white_fox"]);', 'load_quests');

// Init game state
runInContext('gameState.init({ realms: DATA_MODULES["config:realms"], paths: DATA_MODULES["config:paths"] });', 'init_gameState');

// Now run tests
const testCode = `
let failed = 0;
let passed = 0;

function check(name, condition, detail) {
    if (condition) {
        console.log('  PASS:', name, detail || '');
        passed++;
    } else {
        console.log('  FAIL:', name, detail || '');
        failed++;
    }
}

// ===== TEST 1: foxGratitude karma flow =====
console.log('=== TEST 1: foxGratitude karma flow ===');
gameState.realm = 'foundation';
gameState.path = 'sword';
gameState.karmaSeeds = [{
    id: 'foxGratitude', delay: 0, realm: 'foundation',
    priority: 2, originTurn: 10, originCard: 'test', originChoice: 'right'
}];

  const karmaCard = cardSystem._drawKarmaCard();
  check('Karma seed germinates', karmaCard !== null, karmaCard ? karmaCard.id + ': ' + karmaCard.title : '');
  check(
    'Seed remains pending until an accepted choice consumes it',
    gameState.karmaSeeds.length === 1,
    'remaining: ' + gameState.karmaSeeds.length
  );

// ===== TEST 2: Golden realm card pool =====
console.log('\\n=== TEST 2: Golden realm card pool ===');
gameState.realm = 'golden';
gameState.cardsPlayed = [];
gameState.karmaSeeds = [];
gameState.dungeon = null;

cardSystem._loadRealmCards('golden');
const goldenPool = cardSystem.getCardPool('golden');
check('Golden pool has at least 15 cards', goldenPool.length >= 15, 'got ' + goldenPool.length);

// Verify structure
let structOK = true;
for (const card of goldenPool) {
    if (!card.id || !card.title || !card.choices || Object.keys(card.choices).length === 0) {
        console.log('    STRUCT ISSUE:', card.id || card.title || 'unknown');
        structOK = false;
    }
}
check('All cards have valid structure', structOK);

// Normal draw
let drawCard = null;
for (let i = 0; i < 10; i++) {
    drawCard = cardSystem._drawNormal();
    if (drawCard && drawCard.id !== 'q_meditation') break;
}
check('Normal draw from golden', drawCard && drawCard.id !== 'q_meditation', drawCard ? drawCard.title : 'null');

// Breakthrough card
const breakCard = cardSystem.getCard('break_golden');
check('Breakthrough card exists', breakCard !== null, breakCard ? breakCard.title : '');

// Dungeon card
const dunCard = cardSystem.getCard('ruins_ancient');
check('Dungeon card exists', dunCard !== null);

// Path-specific cards
check('Sword card exists', goldenPool.some(c => c.path === 'sword'));
check('Spell card exists', goldenPool.some(c => c.path === 'spell'));
check('Body card exists', goldenPool.some(c => c.path === 'body'));
check('Pill card exists', goldenPool.some(c => c.path === 'pill'));

// ===== TEST 3: Faction events =====
console.log('\\n=== TEST 3: Faction events ===');
const factions = DATA_MODULES['world:factions'];
const shennong = factions.factions.find(f => f.id === 'shennong_dangu');
check('药王谷 has >= 2 events', shennong && shennong.events.length >= 2, shennong ? 'events: ' + shennong.events.length : '');

const wumeng = factions.factions.find(f => f.id === 'wumeng_alliance');
check('武盟 exists', wumeng !== undefined);
check('武盟 has >= 3 events', wumeng && wumeng.events.length >= 3, wumeng ? 'events: ' + wumeng.events.length : '');
check('武盟 has 3 subfactions', wumeng && wumeng.subfactions && wumeng.subfactions.length === 3);
check('武盟 undercurrent exists', factions.undercurrents['wumeng_split'] !== undefined);

const wuUC = factions.undercurrents['wumeng_split'];
check('武盟 undercurrent 4 stages', wuUC && wuUC.maxStage === 4);

// Pill foundation event
const pillEarly = shennong.events.find(e => e.id === 'pill_0' && e.minRealm === 'foundation');
check('药王谷 has foundation-level event', pillEarly !== undefined);

// Faction event picking
gameState.realm = 'foundation';
gameState.path = 'pill';
factionSystem._ticksSinceEvent = 20;
const pillEv = factionSystem._pickFactionEvent();
check('Pill faction event fires', pillEv !== null, pillEv ? pillEv.event.title : '');

gameState.path = 'body';
const bodyEv = factionSystem._pickFactionEvent();
check('Body faction event fires', bodyEv !== null, bodyEv ? bodyEv.event.title : '');

// ===== TEST 4: NPC secrets =====
console.log('\\n=== TEST 4: NPC secrets ===');
const npcs = DATA_MODULES['npcs:core'].npcs;
check('All 8 NPCs have 3-level secrets', npcs.every(n => n.secrets && n.secrets.length >= 3),
    npcs.filter(n => !n.secrets || n.secrets.length < 3).map(n => n.id).join(', ') || 'all OK');

// Updated NPCs
const updated = ['bai_luoxuan', 'jian_linger', 'yin_xue', 'mu_qinglan'];
for (const id of updated) {
    const npc = npcs.find(n => n.id === id);
    const ok = npc && npc.secrets && npc.secrets.length === 3 && npc.knownInfo && npc.knownInfo.length >= 4;
    check(id + ' complete', ok, npc ? npc.name : 'missing');
}

// ===== RESULT =====
console.log('\\n========================================');
console.log('Passed:', passed, '| Failed:', failed);
if (failed > 0) throw new Error(failed + ' tests failed');
`;

runInContext(testCode, 'TEST_RUNNER');
