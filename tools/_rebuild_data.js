// Rebuild DATA_MODULES in index.html from JSON data files
const fs = require('fs');
const path = require('path');

const indexFile = 'index.html';
const dataDir = 'data';

// Map of module name → JSON file path
const moduleMap = {
  'config:realms': 'data/config/realms.json',
  'config:paths': 'data/config/paths.json',
  'config:path_skills': 'data/config/path_skills.json',
  'cards:qi': 'data/cards/qi_condensation.json',
  'cards:foundation': 'data/cards/foundation.json',
  'cards:golden': 'data/cards/golden.json',
  'cards:nascent': 'data/cards/nascent.json',
  'cards:deity': 'data/cards/deity.json',
  'cards:tribulation': 'data/cards/tribulation.json',
  'cards:death': 'data/cards/death.json',
  'cards:karma': 'data/cards/karma.json',
  'cards:demonic_seductress': 'data/cards/demonic_seductress.json',
  'npcs:core': 'data/npcs/core_npcs.json',
  'companions:events': 'data/companions/events.json',
  'companions:portrait_stages': 'data/companions/portrait_stages.json',
  'world:factions': 'data/world/factions.json',
  'quests:white_fox': 'data/quests/white_fox.json',
  'quests:tianshu_codex': 'data/quests/tianshu_codex.json',
  'quests:body_tribulation': 'data/quests/body_tribulation.json',
  'quests:sword_legacy': 'data/quests/sword_legacy.json',
  'quests:spell_codex': 'data/quests/spell_codex.json',
  'quests:pill_master': 'data/quests/pill_master.json',
  'shops:treasures': 'data/shops/treasures.json',
  'shops:shop_items': 'data/shops/shop_items.json',
};

// Read all modules
const DATA_MODULES = {};
for (const [name, file] of Object.entries(moduleMap)) {
  try {
    DATA_MODULES[name] = JSON.parse(fs.readFileSync(file, 'utf-8'));
    console.log('  OK: ' + name + ' ← ' + file);
  } catch (e) {
    console.log('  ERROR: ' + name + ' ← ' + file + ' — ' + e.message);
    process.exit(1);
  }
}

// Read index.html
let html = fs.readFileSync(indexFile, 'utf-8');

// Replace DATA_MODULES block
const re = /const DATA_MODULES\s*=\s*\{.+?\};/s;
const replacement = 'const DATA_MODULES = ' + JSON.stringify(DATA_MODULES) + ';';

if (!re.test(html)) {
  console.log('ERROR: Could not find DATA_MODULES in index.html');
  process.exit(1);
}

html = html.replace(re, replacement);

// Write back
fs.writeFileSync(indexFile, html, 'utf-8');
console.log('\nDone! DATA_MODULES rebuilt with ' + Object.keys(DATA_MODULES).length + ' modules.');
const size = (Buffer.byteLength(JSON.stringify(DATA_MODULES)) / 1024).toFixed(1);
console.log('Data size: ~' + size + ' KB');
