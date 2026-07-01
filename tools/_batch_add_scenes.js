/**
 * 批量补全 sceneImage — 将 14 张场景池图片映射到 331 张缺图卡牌
 * 策略：按卡牌类型 + 境界前缀 智能匹配最合适的场景图
 */
const fs = require('fs');
const path = require('path');

const htmlPath = 'index.html';
let html = fs.readFileSync(htmlPath, 'utf8');

const missing = JSON.parse(fs.readFileSync('_missing_scene_images.json', 'utf8'));

// 场景池图片映射表 — 按 类型 + id前缀(境界) 匹配
const POOL_IMAGES = {
  // === 通用场景池（14张） ===
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

  // === 已有专属图（之前生成的3张） ===
  'ruins':            'assets/cards/events/scene_dt_d_ruins.png',
  'bloodfeast':       'assets/cards/events/scene_comp_xuesha_laozu_bloodfeast.png',
  'sworddebate':      'assets/cards/events/scene_comp_bai_ren_sworddebate.png',
};

// 映射规则：返回 POOL_IMAGES 的 key
function mapCardToScene(card) {
  const { id, type, title } = card;

  // --- 按类型直接映射 ---
  
  // COMBAT → 战斗场景
  if (type === 'COMBAT') return 'combat';
  
  // DUNGEON → 洞穴场景
  if (type === 'DUNGEON') return 'dungeon_cave';

  // BOTTLENECK / BREAKTHROUGH → 突破场景
  if (type === 'BOTTLENECK' || type === 'BREAKTHROUGH') return 'breakthrough';

  // KARMA → 因果回响场景
  if (type === 'KARMA') return 'karma_echo';

  // SHOP → 拍卖/市集
  if (type === 'SHOP') return 'auction';

  // DESTINY → 命运/飞升
  if (type === 'DESTINY') {
    if (/death|ending|rebirth|path_select/i.test(id)) return 'ascension';
    return 'destiny_fate';
  }

  // SPECIAL (路径选择) → 正邪分岔
  if (type === 'SPECIAL') {
    if (/demon|orthodox|dp_/i.test(id)) return 'path_choice';
    if (/iw_past_life/i.test(id)) return 'karma_echo';
    return 'story_moment';
  }

  // STORY → 角色时刻
  if (type === 'STORY') {
    if (/atm_/i.test(id)) return 'sect_training'; // 氛围故事
    return 'story_moment';
  }

  // QUEST → 任务板
  if (type === 'QUEST') return 'quest_board';

  // NORMAL — 按id前缀（境界）细分 ---
  
  // 炼气期 qi/q_ 开头
  if (/^q_/.test(id) || /^qi_/.test(id)) {
    if (/gathering|herb/i.test(id)) return 'herb_gathering';
    if (/meditation/i.test(id)) return 'meditation';
    if (/market|shop/i.test(id)) return 'market';
    if (/fellow|combat/i.test(id)) return 'combat';
    if (/whitefox|fox/i.test(id)) return 'story_moment'; // 白狐线用角色场景
    return 'sect_training'; // 其他炼气事件用宗门训练场
  }

  // 洞府 cave
  if (/^cave_/.test(id)) return 'dungeon_cave';

  // 筑基期 fd/f_
  if (/^f_/.test(id)) {
    if (/trial|mission|demon2/i.test(id)) return 'dungeon_cave';
    if (/market|shop|bribe/i.test(id)) return 'auction';
    if (/love|fox/i.test(id)) return 'story_moment';
    if (/karma/i.test(id)) return 'karma_echo';
    return 'sect_training';
  }

  // 金丹期 gd/g_
  if (/^g_/.test(id)) {
    if (/ruins|vein/i.test(id)) return 'dungeon_cave';
    if (/tribulation/i.test(id)) return 'breakthrough';
    if (/forbidden|secret/i.test(id)) return 'path_choice';
    if (/oldfriend|library/i.test(id)) return 'story_moment';
    return 'meditation'; // 金丹期偏内修
  }

  // 元婴期 ns/n_
  if (/^n_/.test(id)) {
    if (/hunt|combat/i.test(id)) return 'combat';
    if (/ancient|ruins/i.test(id)) return 'dungeon_cave';
    if (/body_tribulation|heart/i.test(id)) return 'breakthrough';
    if (/bridge|awakening/i.test(id)) return 'ascension';
    return 'karma_echo'; // 元婴期多因果回响
  }

  // 化神期 d/d_
  if (/^d_/.test(id) && !/^ds_/.test(id) && !/^dt_/.test(id)) {
    if (/domain|soul|heaven/i.test(id)) return 'destiny_fate';
    if (/heart_demon/i.test(id)) return 'path_choice';
    if (/enemy|combat/i.test(id)) return 'combat';
    if (/disciples|master/i.test(id)) return 'story_moment';
    return 'breakthrough';
  }

  // 渡劫期 t/t_
  if (/^t_/.test(id)) {
    if (/heaven|ascend/i.test(id)) return 'ascension';
    if (/world|dust|mortal/i.test(id)) return 'story_moment';
    return 'breakthrough';
  }

  // 飞升后 pa_ (飞升篇)
  if (/^pa_/.test(id)) {
    if (/ascend|new_world/i.test(id)) return 'ascension';
    return 'destiny_fate';
  }

  // 转世 rb_
  if (/^rb_/.test(id)) return 'karma_echo';

  // ds_ (正魔线) / iw_ (交织线)
  if (/^ds_/.test(id) || /^iw_/.test(id)) return 'path_choice';

  // atm_ (氛围故事)
  if (/^atm_/.test(id)) return 'sect_training';

  // 默认 fallback
  return 'meditation';
}

// 统计映射分布
const stats = {};
missing.forEach(c => {
  const sceneKey = mapCardToScene(c);
  stats[sceneKey] = (stats[sceneKey] || 0) + 1;
});
console.log('=== 场景池映射统计 ===');
Object.entries(stats).sort((a,b) => b[1]-a[1]).forEach(([k,v]) => {
  console.log(`  ${k}: ${v} 张`);
});

// 执行替换：为每张缺失的卡牌添加 sceneImage 字段
let patchedCount = 0;
let errorCount = 0;

missing.forEach(card => {
  const sceneKey = mapCardToScene(card);
  const imageUrl = POOL_IMAGES[sceneKey];
  
  if (!imageUrl) {
    console.error(`[ERROR] No image for key: ${sceneKey} (card ${card.id})`);
    errorCount++;
    return;
  }
  
  // 在卡牌的 choices 字段之前（或最后一个字段之后）插入 sceneImage
  // 策略：找到 "choices": 或 "weight" 或 "once" 或 "tags" 的位置，在前面插入
  
  // 构建插入文本
  const insertText = `\n        "sceneImage": "${imageUrl}",`;
  
  // 查找该卡片块中合适的插入点（优先在 choices/tags/weight 之前）
  // 卡片从 "id": "xxx" 开始
  const cardStart = html.indexOf(`"id":"${card.id}"`);
  if (cardStart === -1) {
    // 尝试其他引号格式
    const altStart = html.indexOf('"id": "' + card.id + '"');
    if (altStart === -1) {
      console.error(`[WARN] Cannot find card: ${card.id}`);
      errorCount++;
      return;
    }
  }
  
  // 在卡片块内找第一个可用的插入锚点
  const cardBlockEnd = Math.min(cardStart + 3000, html.length);
  const cardBlock = html.substring(cardStart, cardBlockEnd);
  
  // 插入点优先级：choices > weight > once > tags > type > description > title
  const anchors = [
    { pattern: '"choices"', before: true },
    { pattern: '"weight"', before: true },
    { pattern: '"once"', before: true },
    { pattern: '"tags"', before: true },
    { pattern: '"realm"', before: true },
    { pattern: '"description"', before: true },
  ];
  
  let inserted = false;
  for (const anchor of anchors) {
    const anchorIdx = cardBlock.indexOf(anchor.pattern);
    if (anchorIdx !== -1) {
      const absPos = cardStart + anchorIdx;
      if (anchor.before) {
        html = html.substring(0, absPos) + insertText + '\n        ' + html.substring(absPos);
      } else {
        // after: 找到这行的末尾
        const lineEnd = html.indexOf('\n', absPos);
        if (lineEnd !== -1 && lineEnd < cardStart + 2000) {
          html = html.substring(0, lineEnd) + ',' + insertText.substring(1) + html.substring(lineEnd);
        }
      }
      inserted = true;
      break;
    }
  }
  
  if (!inserted) {
    // 兜底：在卡片块的第一个 { 后面插入
    const braceIdx = cardBlock.indexOf('{');
    if (braceIdx !== -1) {
      const absPos = cardStart + braceIdx + 1;
      html = html.substring(0, absPos) + insertText + html.substring(absPos);
      inserted = true;
    }
  }
  
  if (inserted) patchedCount++;
});

// 写回文件
fs.writeFileSync(htmlPath, html, 'utf8');

console.log(`\n=== 补全结果 ===`);
console.log(`成功补入: ${patchedCount} 张`);
console.log(`失败: ${errorCount} 张`);

// 验证
const verifyHtml = fs.readFileSync(htmlPath, 'utf8');
const newSceneCount = (verifyHtml.match(/"sceneImage"/g) || []).length;
console.log(`\ndataModules 中现有 sceneImage 引用总数: ${newSceneCount}`);
