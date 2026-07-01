/**
 * 批量补全 sceneImage v2 — 稳健版
 * 策略：对每张卡牌，精确定位到其 id 字段后的完整对象，
 *       在第一个顶层字段前插入 sceneImage
 */
const fs = require('fs');

const htmlPath = 'index.html';
let html = fs.readFileSync(htmlPath, 'utf8');
const missing = JSON.parse(fs.readFileSync('_missing_scene_images.json', 'utf8'));

const POOL_IMAGES = {
  'herb_gathering':   'assets/cards/events/scene_pool_herb_gathering.png',
  'meditation':       'assets/cards/events/scene_pool_meditation.png',
  'market':           'assets/cards/events/scene_pool_market.png',
  'combat':           'assets/cards/events/scene_pool_combat.png',
  'karma_echo':       'assets/cards/events/scene_pool_karma_echo.png',
  'dungeon_cave':     'assets/cards/events/scene_pool_dungeon_cave.png',
  'breakthrough':     'assets/cards/events/scene_pool_breakthrough.png',
  'destiny_fate':     'assets/cards/events/scene_pool_destiny_fate.png',
  'path_choice':       'assets/cards/events/scene_pool_path_choice.png',
  'story_moment':     'assets/cards/events/scene_pool_story_moment.png',
  'auction':          'assets/cards/events/scene_pool_auction.png',
  'quest_board':      'assets/cards/events/scene_pool_quest_board.png',
  'sect_training':    'assets/cards/events/scene_pool_sect_training.png',
  'ascension':        'assets/cards/events/scene_pool_ascension.png',
};

function mapCardToScene(card) {
  const { id, type } = card;
  if (type === 'COMBAT') return 'combat';
  if (type === 'DUNGEON') return 'dungeon_cave';
  if (type === 'BOTTLENECK' || type === 'BREAKTHROUGH') return 'breakthrough';
  if (type === 'KARMA') return 'karma_echo';
  if (type === 'SHOP') return 'auction';
  if (type === 'DESTINY') {
    if (/death|ending|rebirth|path_select/i.test(id)) return 'ascension';
    return 'destiny_fate';
  }
  if (type === 'SPECIAL') {
    if (/demon|orthodox|dp_/i.test(id)) return 'path_choice';
    if (/iw_past_life/i.test(id)) return 'karma_echo';
    return 'story_moment';
  }
  if (type === 'STORY') {
    if (/atm_/i.test(id)) return 'sect_training';
    return 'story_moment';
  }
  if (type === 'QUEST') return 'quest_board';
  // NORMAL — 按id前缀(境界)细分
  if (/^q_/.test(id) || /^qi_/.test(id)) {
    if (/gathering|herb/i.test(id)) return 'herb_gathering';
    if (/meditation/i.test(id)) return 'meditation';
    if (/market|shop/i.test(id)) return 'market';
    if (/fellow|combat/i.test(id)) return 'combat';
    if (/whitefox|fox/i.test(id)) return 'story_moment';
    return 'sect_training';
  }
  if (/^cave_/.test(id)) return 'dungeon_cave';
  if (/^f_/.test(id)) {
    if (/trial|mission|demon2/i.test(id)) return 'dungeon_cave';
    if (/market|shop|bribe/i.test(id)) return 'auction';
    if (/love|fox/i.test(id)) return 'story_moment';
    if (/karma/i.test(id)) return 'karma_echo';
    return 'sect_training';
  }
  if (/^g_/.test(id)) {
    if (/ruins|vein/i.test(id)) return 'dungeon_cave';
    if (/tribulation/i.test(id)) return 'breakthrough';
    if (/forbidden|secret/i.test(id)) return 'path_choice';
    if (/oldfriend|library/i.test(id)) return 'story_moment';
    return 'meditation';
  }
  if (/^n_/.test(id)) {
    if (/hunt|combat/i.test(id)) return 'combat';
    if (/ancient|ruins/i.test(id)) return 'dungeon_cave';
    if (/body_tribulation|heart/i.test(id)) return 'breakthrough';
    if (/bridge|awakening/i.test(id)) return 'ascension';
    return 'karma_echo';
  }
  if (/^d_[aeg]/.test(id) && !/^ds_/.test(id) && !/^dt_/.test(id)) {
    if (/domain|soul|heaven/i.test(id)) return 'destiny_fate';
    if (/heart_demon/i.test(id)) return 'path_choice';
    if (/enemy|combat/i.test(id)) return 'combat';
    if (/disciples|master/i.test(id)) return 'story_moment';
    return 'breakthrough';
  }
  if (/^t_/.test(id)) {
    if (/heaven|ascend/i.test(id)) return 'ascension';
    if (/world|dust|mortal/i.test(id)) return 'story_moment';
    return 'breakthrough';
  }
  if (/^pa_/.test(id)) return /^pa_ascend/.test(id) ? 'ascension' : 'destiny_fate';
  if (/^rb_/.test(id)) return 'karma_echo';
  if (/^ds_/.test(id) || /^iw_/.test(id)) return 'path_choice';
  if (/^atm_/.test(id)) return 'sect_training';
  return 'meditation';
}

// 关键修复：从后往前替换，避免位置偏移问题！
missing.reverse().forEach(card => {
  const sceneKey = mapCardToScene(card);
  const imageUrl = POOL_IMAGES[sceneKey];
  if (!imageUrl) return;
  
  // 查找 "id": "xxx" 的精确位置（从后往前找避免重复）
  const idPattern = new RegExp('"id"\\s*:\\s*"' + card.id.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + '"', 'g');
  let lastIdx = -1;
  let match;
  while ((match = idPattern.exec(html)) !== null) {
    lastIdx = match.index;
  }
  if (lastIdx === -1) return;
  
  // 从 id 位置往后找到这个卡片的结构范围（匹配括号层级）
  let depth = 0;
  let inStr = false;
  let firstFieldPos = -1; // 第一个字段的位置
  
  for (let i = lastIdx + `"id":"${card.id}"`.length; i < Math.min(lastIdx + 2000, html.length); i++) {
    const c = html[i];
    if (c === '"' && html[i-1] !== '\\') inStr = !inStr;
    if (inStr) continue;
    
    if (c === '{') {
      depth++;
      // 跳过 id 值后面的第一个 { 后，找下一个字段作为插入点
      if (depth === 1 && firstFieldPos === -1) continue;
    }
    if (c === '}') {
      depth--;
      if (depth === 0) break; // 卡片结束
    }
    
    // 在 depth===1 时，找到第一个字段定义的起始位置
    if (depth === 1 && c === '"' && firstFieldPos === -1) {
      // 回退到字段名开头
      let j = i - 1;
      while (j > lastIdx && html[j] !== '"') j--;
      firstFieldPos = j;
    }
  }
  
  if (firstFieldPos !== -1) {
    const insertText = `\n        "sceneImage": "${imageUrl}",`;
    html = html.substring(0, firstFieldPos) + insertText + '\n        ' + html.substring(firstFieldPos);
  }
});

fs.writeFileSync(htmlPath, html, 'utf8');

const finalCount = (html.match(/"sceneImage"/g) || []).length;
console.log(`补全完成! sceneImage 引用总数: ${finalCount} (原 185 → 新增 ${finalCount - 185})`);

// 验证：检查是否有缺图的卡片还剩下
const remaining = [];
const reCheck = /"id"\s*:\s*"([^"]+)"/g;
let m2;
while ((m2 = reCheck.exec(html)) !== null) {
  const start = m2.index;
  let d=0, end=start+2000;
  for(let i=start;i<Math.min(end,html.length);i++) {
    if(html[i]==='{') d++;
    if(html[i]=='}') { d--; if(d==0) { end=i+1; break; } }
  }
  const block = html.substring(start, end);
  if (!block.includes('"sceneImage"')) {
    const tMatch = block.match(/"type"\s*:\s*"(\w+)"/);
    const tiMatch = block.match(/"title"\s*:\s*"([^"]{1,40})"/);
    remaining.push({id: m2[1], type: tMatch?tMatch[1]:'?', title: tiMatch?tiMatch[1]:'?'});
  }
}

if (remaining.length > 0) {
  console.log(`\n⚠️ 仍有 ${remaining.length} 张无 sceneImage:`);
  remaining.slice(0, 20).forEach(r => console.log(`  [${r.type}] ${r.id}: ${r.title}`));
} else {
  console.log('\n✅ 所有主要卡牌均已覆盖 sceneImage!');
}
