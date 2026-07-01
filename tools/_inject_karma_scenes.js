// Inject sceneImage into karma.json cards + rename auto-generated images
const fs = require('fs');
const path = require('path');

const eventsDir = 'assets/cards/events';
const karmaFile = 'data/cards/karma.json';

// Mapping: auto-generated filename (partial match) → karma card ID
const MAP = [
  // fox / tianshu quest echoes
  { match: 'white_fox_spirit_returning_to_',  id: 'k_fox_returns' },
  { match: 'fox_spirit_bowing_deeply_to_cu',   id: 'k_fox_gratitude' },
  { match: 'ancient_heavenly_book_opening__',   id: 'k_tianshu_echo' },
  { match: 'heavenly_book_pages_turning_re',    id: 'k_tianshu_revelation' },

  // body tribulation echoes
  { match: 'body_cultivation_karmic_echo___',   id: 'k_body_echo' },
  { match: 'body_cultivator_ascending_on_p',    id: 'k_body_ascension' },

  // sword echoes
  { match: 'sword_cultivator_betrayed_by_t',    id: 'k_sword_betrayal' },
  { match: 'sword_cultivator_receiving_hon',    id: 'k_sword_honor' },
  { match: 'ancient_sword_legacy_chamber_o',    id: 'k_sword_legacy_start' },
  { match: 'sword_trial_arena__cultivator__',   id: 'k_sword_legacy_trial' },

  // spell echoes
  { match: 'hidden_spell_tome_sealed_in_da',    id: 'k_spell_hidden' },
  { match: 'spell_tome_revealed_in_brillia',    id: 'k_spell_revealed' },

  // pill echoes
  { match: 'dark_pill_emitting_toxic_green',    id: 'k_pill_poison' },
  { match: 'healing_pill_radiating_pure_wh',    id: 'k_pill_cure' },

  // combat echoes
  { match: 'cultivator_standing_victorious',    id: 'k_combat_glory' },

  // companion echoes
  { match: 'companion_sacrificing_themselv',    id: 'k_comp_sacrifice' },
  { match: 'two_cultivators_clasping_hands',    id: 'k_comp_trust' },

  // faction echoes
  { match: 'faction_uprising_in_sect__cult',    id: 'k_faction_uprising' },
  { match: 'two_faction_leaders_shaking_ha',    id: 'k_faction_peace' },

  // lifespan / fortune echoes
  { match: 'hourglass_running_out__lifespa',    id: 'k_lifespan_waste' },
  { match: 'fortune_wheel_spinning_in_cosm',    id: 'k_fortune_wheel' },

  // past life / mastery echoes
  { match: 'past_life_echo_appearing_in_mi',    id: 'k_echo_past_life' },
  { match: 'cultivator_mastering_ancient_p',    id: 'k_echo_path_mastery' },
  { match: 'endless_karma_chain_linking_co',    id: 'k_echo_karma_chain' },

  // NPC betrayal
  { match: 'NPC_ally_secretly_plotting_bet',    id: 'k_betrayed_npc' },
];

// Step 1: Rename images
console.log('=== Step 1: Rename images ===');
const files = fs.readdirSync(eventsDir);
let renamed = 0, skipped = 0;
const sceneImageMap = {}; // karmaId → sceneImage path

for (const entry of MAP) {
  const found = files.find(f => f.startsWith(entry.match));
  if (!found) {
    console.log('  SKIP: ' + entry.id + ' — no matching file');
    skipped++;
    continue;
  }
  const target = 'scene_karma_' + entry.id + '.png';
  const oldPath = path.join(eventsDir, found);
  const newPath = path.join(eventsDir, target);
  
  if (fs.existsSync(newPath)) {
    console.log('  EXISTS: ' + target);
    sceneImageMap[entry.id] = 'assets/cards/events/' + target;
    continue;
  }
  
  fs.renameSync(oldPath, newPath);
  sceneImageMap[entry.id] = 'assets/cards/events/' + target;
  console.log('  RENAMED: ' + found + ' → ' + target);
  renamed++;
}
console.log('Renamed: ' + renamed + ', Skipped: ' + skipped);

// Step 2: Inject sceneImage into karma.json
console.log('\n=== Step 2: Inject sceneImage into karma.json ===');
const karma = JSON.parse(fs.readFileSync(karmaFile, 'utf-8'));
let injected = 0;

for (const card of karma.cards) {
  if (sceneImageMap[card.id]) {
    card.sceneImage = sceneImageMap[card.id];
    injected++;
    console.log('  SET: ' + card.id + ' → ' + card.sceneImage);
  } else if (!card.sceneImage) {
    console.log('  STILL MISSING: ' + card.id);
  }
}

fs.writeFileSync(karmaFile, JSON.stringify(karma, null, 2) + '\n', 'utf-8');
console.log('Injected: ' + injected + ' / ' + karma.cards.length + ' cards');
console.log('Still missing sceneImage: ' + karma.cards.filter(c => !c.sceneImage).map(c => c.id).join(', '));
