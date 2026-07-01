const fs = require('fs');
const html = fs.readFileSync('index.html', 'utf8');

// 全量解析：找到每个顶级卡片对象的 id, type, title, 是否有 sceneImage
const results = [];
// 匹配 "id": "xxx" 开头的卡片块
const idPattern = /"id"\s*:\s*"([^"]+)"/g;
let match;
let lastPos = 0;

while ((match = idPattern.exec(html)) !== null) {
  const cardId = match[1];
  const startPos = match.index;
  
  // 找到这个卡片块的结束（匹配的 } 数）
  let depth = 0;
  let inStr = false;
  let endPos = startPos;
  
  for (let i = startPos; i < Math.min(startPos + 3000, html.length); i++) {
    const c = html[i];
    if (c === '"' && html[i-1] !== '\\') { inStr = !inStr; continue; }
    if (inStr) continue;
    if (c === '{') depth++;
    if (c === '}') {
      depth--;
      if (depth === 0) { endPos = i + 1; break; }
    }
  }
  
  const block = html.substring(startPos, endPos);
  
  const typeMatch = block.match(/"type"\s*:\s*"(\w+)"/);
  const titleMatch = block.match(/"title"\s*:\s*"([^"]{1,50})"/);
  const hasSceneImage = block.includes('"sceneImage"');
  const type = typeMatch ? typeMatch[1] : 'UNKNOWN';
  const title = titleMatch ? titleMatch[1] : cardId;
  
  results.push({ id: cardId, type, title, hasSceneImage });
}

// 分类统计
console.log('===========================================');
console.log('   全量场景图覆盖审计 — 一念仙途');
console.log('===========================================');
console.log('总卡牌数: ' + results.length);

// 按类型分组
const byType = {};
results.forEach(r => {
  if (!byType[r.type]) byType[r.type] = { total: 0, withScene: 0, withoutScene: [] };
  byType[r.type].total++;
  if (r.hasSceneImage) {
    byType[r.type].withScene++;
  } else {
    byType[r.type].withoutScene.push(r);
  }
});

console.log('\n--- 各类型覆盖率 ---');
Object.keys(byType).sort().forEach(type => {
  const t = byType[type];
  const pct = t.total > 0 ? ((t.withScene / t.total) * 100).toFixed(0) : 0;
  console.log(`\n[${type}] ${t.total}张 — 有图${t.withScene} (${pct}%) | 缺图${t.withoutScene.length}`);
});

// 汇总缺图的（排除不需要视觉的类型）
const needVisualTypes = ['NORMAL','STORY','KARMA','QUEST','DUNGEON','DESTINY','COMBAT','BOTTLENECK','BREAKTHROUGH','SHOP','SPECIAL','LOCATION'];
const missingAll = [];

console.log('\n===========================================');
console.log('   缺少 sceneImage 的卡牌详情');
console.log('===========================================');

needVisualTypes.forEach(type => {
  if (!byType[type]) return;
  const missing = byType[type].withoutScene;
  if (missing.length === 0) return;
  console.log(`\n【${type}】(${missing.length}张)`);
  missing.forEach(r => {
    console.log(`  [${r.id}] ${r.title}`);
    missingAll.push(r);
  });
});

const noNeedTypes = Object.keys(byType).filter(t => !needVisualTypes.includes(t));
if (noNeedTypes.length) {
  console.log('\n--- 以下类型通常不需要场景图 ---');
  noNeedTypes.forEach(t => {
    if (byType[t].withoutScene.length > 0) {
      console.log(`${t}: ${byType[t].withoutScene.length}张无图 (可忽略)`);
    }
  });
}

console.log(`\n总计需要补图的卡牌: ${missingAll.length} 张`);

// 输出 JSON 供后续使用
if (missingAll.length > 0) {
  fs.writeFileSync('_missing_scene_images.json', JSON.stringify(missingAll, null, 2));
  console.log('\n完整列表已导出 → _missing_scene_images.json');
}
