// Inject all 6 realm scene images into DATA_MODULES
const fs = require('fs');
const html = fs.readFileSync('index.html', 'utf8');
const lines = html.split('\n');
const dmIdx = lines.findIndex(l => l.includes('const DATA_MODULES'));
const dmLine = lines[dmIdx];
const start = dmLine.indexOf('{');
const end = dmLine.lastIndexOf('};');
const jsonStr = dmLine.slice(start, end + 1);
let data; eval('data = ' + jsonStr);

const sceneMaps = {
  'cards:qi': {
    'q_start_sword': 'assets/cards/events/scene_qi_q_start_sword.png',
    'q_start_spell': 'assets/cards/events/scene_qi_q_start_spell.png',
    'q_start_body': 'assets/cards/events/scene_qi_q_start_body.png',
    'q_start_pill': 'assets/cards/events/scene_qi_q_start_pill.png',
    'q_fellow': 'assets/cards/events/scene_qi_q_fellow.png',
    'q_market': 'assets/cards/events/scene_qi_q_market.png',
    'q_demon': 'assets/cards/events/scene_qi_q_demon.png',
    'q_elder': 'assets/cards/events/scene_qi_q_elder.png',
    'q_cave': 'assets/cards/events/scene_qi_q_cave.png',
    'q_pillRecipe': 'assets/cards/events/scene_qi_q_pillRecipe.png',
    'q_spellTome': 'assets/cards/events/scene_qi_q_spellTome.png',
    'q_bodyTrial': 'assets/cards/events/scene_qi_q_bodyTrial.png',
    'q_fortune': 'assets/cards/events/scene_qi_q_fortune.png',
    'break_qi': 'assets/cards/events/scene_qi_break_qi.png',
    'death': 'assets/cards/events/scene_qi_death.png',
    'ending_ascension': 'assets/cards/events/scene_qi_ending_ascension.png',
    'path_select': 'assets/cards/events/scene_qi_path_select.png',
    'q_shop': 'assets/cards/events/scene_qi_q_shop.png'
  },
  'cards:foundation': {
    'q_foundation': 'assets/cards/events/scene_fd_q_foundation.png',
    'f_mission': 'assets/cards/events/scene_fd_f_mission.png',
    'f_sect': 'assets/cards/events/scene_fd_f_sect.png',
    'f_demon2': 'assets/cards/events/scene_fd_f_demon2.png',
    'f_artifact': 'assets/cards/events/scene_fd_f_artifact.png',
    'f_master': 'assets/cards/events/scene_fd_f_master.png',
    'f_love': 'assets/cards/events/scene_fd_f_love.png',
    'f_trial': 'assets/cards/events/scene_fd_f_trial.png',
    'f_karma': 'assets/cards/events/scene_fd_f_karma.png',
    'f_tribulation': 'assets/cards/events/scene_fd_f_tribulation.png',
    'f_market': 'assets/cards/events/scene_fd_f_market.png',
    'f_foxGratitude': 'assets/cards/events/scene_fd_f_foxGratitude.png',
    'break_foundation': 'assets/cards/events/scene_fd_break_foundation.png',
    'f_shop': 'assets/cards/events/scene_fd_f_shop.png',
    'f_bribe': 'assets/cards/events/scene_fd_f_bribe.png'
  },
  'cards:golden': {
    'g_coreFormed': 'assets/cards/events/scene_gd_g_coreFormed.png',
    'g_swordIntent': 'assets/cards/events/scene_gd_g_swordIntent.png',
    'g_spellGreat': 'assets/cards/events/scene_gd_g_spellGreat.png',
    'g_bodyGold': 'assets/cards/events/scene_gd_g_bodyGold.png',
    'g_pillSecret': 'assets/cards/events/scene_gd_g_pillSecret.png',
    'g_ruins': 'assets/cards/events/scene_gd_g_ruins.png',
    'g_veinFight': 'assets/cards/events/scene_gd_g_veinFight.png',
    'g_tribulationOmen': 'assets/cards/events/scene_gd_g_tribulationOmen.png',
    'g_demonSeed': 'assets/cards/events/scene_gd_g_demonSeed.png',
    'g_elderMystery': 'assets/cards/events/scene_gd_g_elderMystery.png',
    'g_daoConference': 'assets/cards/events/scene_gd_g_daoConference.png',
    'g_oldFriend': 'assets/cards/events/scene_gd_g_oldFriend.png',
    'g_forbiddenTome': 'assets/cards/events/scene_gd_g_forbiddenTome.png',
    'g_fateChoice': 'assets/cards/events/scene_gd_g_fateChoice.png',
    'break_golden': 'assets/cards/events/scene_gd_break_golden.png',
    'g_shop': 'assets/cards/events/scene_gd_g_shop.png',
    'g_bribe': 'assets/cards/events/scene_gd_g_bribe.png',
    'g_secret_sword': 'assets/cards/events/scene_gd_g_secret_sword.png',
    'g_secret_spell': 'assets/cards/events/scene_gd_g_secret_spell.png',
    'g_secret_body': 'assets/cards/events/scene_gd_g_secret_body.png',
    'g_secret_pill': 'assets/cards/events/scene_gd_g_secret_pill.png'
  },
  'cards:nascent': {
    'n_awakening': 'assets/cards/events/scene_ns_n_awakening.png',
    'n_ego': 'assets/cards/events/scene_ns_n_ego.png',
    'n_hunt': 'assets/cards/events/scene_ns_n_hunt.png',
    'n_cave': 'assets/cards/events/scene_ns_n_cave.png',
    'n_old_rival': 'assets/cards/events/scene_ns_n_old_rival.png',
    'n_sect_burden': 'assets/cards/events/scene_ns_n_sect_burden.png',
    'n_out_of_body': 'assets/cards/events/scene_ns_n_out_of_body.png',
    'n_meditation': 'assets/cards/events/scene_ns_n_meditation.png',
    'n_sword_spirit': 'assets/cards/events/scene_ns_n_sword_spirit.png',
    'n_spell_library': 'assets/cards/events/scene_ns_n_spell_library.png',
    'n_body_tribulation': 'assets/cards/events/scene_ns_n_body_tribulation.png',
    'n_pill_miracle': 'assets/cards/events/scene_ns_n_pill_miracle.png',
    'n_heaven_eye': 'assets/cards/events/scene_ns_n_heaven_eye.png',
    'n_trade_city': 'assets/cards/events/scene_ns_n_trade_city.png',
    'n_ancient_ruins': 'assets/cards/events/scene_ns_n_ancient_ruins.png',
    'n_auction': 'assets/cards/events/scene_ns_n_auction.png',
    'n_blood_debt': 'assets/cards/events/scene_ns_n_blood_debt.png',
    'n_spirit_vein': 'assets/cards/events/scene_ns_n_spirit_vein.png',
    'n_bridge': 'assets/cards/events/scene_ns_n_bridge.png',
    'break_nascent': 'assets/cards/events/scene_ns_break_nascent.png'
  },
  'cards:deity': {
    'd_awakening': 'assets/cards/events/scene_dt_d_awakening.png',
    'd_domain': 'assets/cards/events/scene_dt_d_domain.png',
    'd_soul_wander': 'assets/cards/events/scene_dt_d_soul_wander.png',
    'd_heart_demon': 'assets/cards/events/scene_dt_d_heart_demon.png',
    'd_sect_master': 'assets/cards/events/scene_dt_d_sect_master.png',
    'd_old_monster': 'assets/cards/events/scene_dt_d_old_monster.png',
    'd_heaven_dao': 'assets/cards/events/scene_dt_d_heaven_dao.png',
    'd_enemy_territory': 'assets/cards/events/scene_dt_d_enemy_territory.png',
    'd_disciples': 'assets/cards/events/scene_dt_d_disciples.png',
    'd_sword_domain': 'assets/cards/events/scene_dt_d_sword_domain.png',
    'd_spell_origin': 'assets/cards/events/scene_dt_d_spell_origin.png',
    'd_body_saint': 'assets/cards/events/scene_dt_d_body_saint.png',
    'd_pill_tao': 'assets/cards/events/scene_dt_d_pill_tao.png',
    'd_lifespan': 'assets/cards/events/scene_dt_d_lifespan.png',
    'd_karma_count': 'assets/cards/events/scene_dt_d_karma_count.png',
    'd_immortal_trace': 'assets/cards/events/scene_dt_d_immortal_trace.png',
    'd_auction': 'assets/cards/events/scene_dt_d_auction.png',
    'd_star_gazing': 'assets/cards/events/scene_dt_d_star_gazing.png',
    'break_deity': 'assets/cards/events/scene_dt_break_deity.png'
  },
  'cards:tribulation': {
    't_first_strike': 'assets/cards/events/scene_tb_t_first_strike.png',
    't_nine_nine': 'assets/cards/events/scene_tb_t_nine_nine.png',
    't_heart_demon_final': 'assets/cards/events/scene_tb_t_heart_demon_final.png',
    't_dust_sever': 'assets/cards/events/scene_tb_t_dust_sever.png',
    't_teacher': 'assets/cards/events/scene_tb_t_teacher.png',
    't_rival_farewell': 'assets/cards/events/scene_tb_t_rival_farewell.png',
    't_mortal_world': 'assets/cards/events/scene_tb_t_mortal_world.png',
    't_lone_peak': 'assets/cards/events/scene_tb_t_lone_peak.png',
    't_heaven_gate': 'assets/cards/events/scene_tb_t_heaven_gate.png',
    't_sword_heart': 'assets/cards/events/scene_tb_t_sword_heart.png',
    't_spell_truth': 'assets/cards/events/scene_tb_t_spell_truth.png',
    't_body_immortal': 'assets/cards/events/scene_tb_t_body_immortal.png',
    't_pill_immortal': 'assets/cards/events/scene_tb_t_pill_immortal.png',
    't_dao_debate': 'assets/cards/events/scene_tb_t_dao_debate.png',
    't_world_end': 'assets/cards/events/scene_tb_t_world_end.png',
    't_ascend_choice': 'assets/cards/events/scene_tb_t_ascend_choice.png',
    't_last_auction': 'assets/cards/events/scene_tb_t_last_auction.png',
    't_immortal_test': 'assets/cards/events/scene_tb_t_immortal_test.png',
    'break_tribulation': 'assets/cards/events/scene_tb_break_tribulation.png'
  }
};

let injected = 0;
for (const [moduleKey, cardMap] of Object.entries(sceneMaps)) {
  if (!data[moduleKey] || !data[moduleKey].cards) { console.log('MISSING: ' + moduleKey); continue; }
  data[moduleKey].cards.forEach(card => {
    if (cardMap[card.id]) {
      card.sceneImage = cardMap[card.id];
      injected++;
    }
  });
}

const newJson = JSON.stringify(data);
const newDmLine = '  const DATA_MODULES = ' + newJson + ';';
lines[dmIdx] = newDmLine;
fs.writeFileSync('index.html', lines.join('\n'), 'utf8');
console.log('Injected ' + injected + ' sceneImage paths into DATA_MODULES');
