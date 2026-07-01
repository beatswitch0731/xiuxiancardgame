// Inject sceneImage into ALL card JSONs by mapping existing scene images on disk
const fs = require('fs');
const path = require('path');

const eventsDir = 'assets/cards/events';
const dataDir = 'data/cards';

// Realm → data file mapping
const REALM_MAP = {
  qi_condensation: 'qi_condensation.json',
  foundation: 'foundation.json',
  golden: 'golden.json',
  nascent: 'nascent.json',
  deity: 'deity.json',
  tribulation: 'tribulation.json',
  death: 'death.json',
  demon_path: 'demon_path.json',
  demonic_seductress: 'demonic_seductress.json',
  post_ascension: 'post_ascension.json',
  interweave: 'interweave.json',
  rebirth: 'rebirth.json',
};

// --- File → Card ID logic ---
// On disk: scene_{realmCode}_{cardIdWithPrefix}.png
// For qi_condensation, two conventions: scene_qi_{id} and scene_event_qi_{name}

// Special name overrides for files that don't exactly match card IDs
const OVERRIDES = {
  'event_qi_herb_gather': 'q_gathering',
  'event_qi_spirit_mine': 'q_spiritStone',
  'event_qi_swordtomb': 'q_swordTomb',
  'event_qi_whitefox': 'q_whiteFox',
};

function extractCardId(filename, realm) {
  const base = filename.replace(/\.png$/, '');
  
  // Qi realm special: scene_event_qi_{name}
  if (realm === 'qi_condensation') {
    const em = base.match(/^scene_event_qi_(.+)$/);
    if (em) {
      const name = em[1];
      const overrideKey = 'event_qi_' + name;
      return OVERRIDES[overrideKey] || ('q_' + name);
    }
    // scene_qi_{cardId}
    const sm = base.match(/^scene_qi_(.+)$/);
    if (sm) return sm[1];
  }
  
  // Foundation: scene_fd_{cardId}
  if (realm === 'foundation') {
    const sm = base.match(/^scene_fd_(.+)$/);
    if (sm) return sm[1];
  }
  
  // Golden: scene_gd_{cardId}
  if (realm === 'golden') {
    const sm = base.match(/^scene_gd_(.+)$/);
    if (sm) return sm[1];
  }
  
  // Nascent: scene_ns_{cardId}
  if (realm === 'nascent') {
    const sm = base.match(/^scene_ns_(.+)$/);
    if (sm) return sm[1];
  }
  
  // Deity: scene_dt_{cardId}
  if (realm === 'deity') {
    const sm = base.match(/^scene_dt_(.+)$/);
    if (sm) return sm[1];
  }
  
  // Tribulation: scene_tb_{cardId}
  if (realm === 'tribulation') {
    const sm = base.match(/^scene_tb_(.+)$/);
    if (sm) return sm[1];
  }
  
  // Demon path: scene_dp_{cardId}
  if (realm === 'demon_path') {
    const sm = base.match(/^scene_dp_(.+)$/);
    if (sm) return sm[1];
  }
  
  // Demonic seductress: scene_ds_{cardId}
  if (realm === 'demonic_seductress') {
    const sm = base.match(/^scene_ds_(.+)$/);
    if (sm) return sm[1];
  }
  
  // Interweave: scene_iw_{cardId}
  if (realm === 'interweave') {
    const sm = base.match(/^scene_iw_(.+)$/);
    if (sm) return sm[1];
  }
  
  // Rebirth: scene_rb_{cardId}
  if (realm === 'rebirth') {
    const sm = base.match(/^scene_rb_(.+)$/);
    if (sm) return sm[1];
  }
  
  // Post ascension: scene_pa_{cardId}
  if (realm === 'post_ascension') {
    const sm = base.match(/^scene_pa_(.+)$/);
    if (sm) return sm[1];
  }
  
  return null;
}

// Detect realm from filename
function detectRealm(filename) {
  const base = filename.replace(/\.png$/, '');
  if (base.startsWith('scene_event_qi_') || base.startsWith('scene_qi_')) return 'qi_condensation';
  if (base.startsWith('scene_fd_')) return 'foundation';
  if (base.startsWith('scene_gd_')) return 'golden';
  if (base.startsWith('scene_ns_')) return 'nascent';
  if (base.startsWith('scene_dt_')) return 'deity';
  if (base.startsWith('scene_tb_')) return 'tribulation';
  if (base.startsWith('scene_dp_')) return 'demon_path';
  if (base.startsWith('scene_ds_')) return 'demonic_seductress';
  if (base.startsWith('scene_iw_')) return 'interweave';
  if (base.startsWith('scene_rb_')) return 'rebirth';
  if (base.startsWith('scene_pa_')) return 'post_ascension';
  return null;
}

// Scan disk
const diskFiles = fs.readdirSync(eventsDir).filter(f =>
  f.endsWith('.png') && !f.startsWith('scene_karma_') && !f.startsWith('scene_comp_')
);
console.log('Scene images on disk (non-karma, non-comp): ' + diskFiles.length);

// Build file→cardId map
const fileToPath = {};
let mapped = 0, unmatched = [];

for (const f of diskFiles) {
  const realm = detectRealm(f);
  if (!realm) { unmatched.push(f); continue; }
  const cardId = extractCardId(f, realm);
  if (!cardId) { unmatched.push(f); continue; }
  fileToPath[realm + ':' + cardId] = 'assets/cards/events/' + f;
  mapped++;
}
console.log('Mapped: ' + mapped + ' of ' + diskFiles.length + ' disk files');
if (unmatched.length) console.log('Unmatched: ' + unmatched.join(', '));

// Inject into JSONs
let totalInjected = 0, totalCards = 0;
const allMissing = [];

for (const [realm, filename] of Object.entries(REALM_MAP)) {
  const filePath = path.join(dataDir, filename);
  if (!fs.existsSync(filePath)) { console.log('  SKIP: ' + filename + ' (not found)'); continue; }

  let data;
  try { data = JSON.parse(fs.readFileSync(filePath, 'utf8')); }
  catch (e) { console.log('  BROKEN: ' + filename); continue; }

  const cards = data.cards || [];
  totalCards += cards.length;
  let injected = 0;
  const missing = [];

  for (const card of cards) {
    const key = realm + ':' + card.id;
    if (fileToPath[key]) {
      card.sceneImage = fileToPath[key];
      injected++;
    } else if (!card.sceneImage || card.sceneImage === 'NONE') {
      missing.push(card.id);
    }
  }

  totalInjected += injected;
  fs.writeFileSync(filePath, JSON.stringify(data, null, 2) + '\n', 'utf-8');
  const status = missing.length === 0 ? 'COMPLETE' : 'MISS ' + missing.length;
  const pad = 28;
  console.log(('  ' + filename).padEnd(pad) + injected + '/' + cards.length + '  ' + status);
  if (missing.length && missing.length <= 10) console.log('    ' + missing.join(', '));
  
  for (const m of missing) allMissing.push({ realm, cardId: m });
}

console.log('\n=== SUMMARY ===');
console.log('TOTAL: ' + totalInjected + '/' + totalCards + ' cards have sceneImage');
console.log('MISSING: ' + (totalCards - totalInjected) + ' cards');
if (allMissing.length > 0) {
  console.log('\nBreakdown by realm:');
  const byRealm = {};
  for (const m of allMissing) {
    if (!byRealm[m.realm]) byRealm[m.realm] = [];
    byRealm[m.realm].push(m.cardId);
  }
  for (const [realm, ids] of Object.entries(byRealm)) {
    console.log('  ' + realm + ': ' + ids.length + ' cards');
    if (ids.length <= 10) ids.forEach(id => console.log('    - ' + id));
  }
}
