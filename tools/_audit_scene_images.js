const fs = require('fs');
const html = fs.readFileSync('index.html', 'utf8');
const path = require('path');

// 1. 找所有 sceneImage
const scenes = [];
const re = /"sceneImage"\s*:\s*"([^"]+)"/g;
let m;
while ((m = re.exec(html)) !== null) scenes.push(m[1]);
console.log('=== 已有 sceneImage (' + scenes.length + '个) ===');
scenes.forEach(s => console.log('  ' + s));

// 检查文件是否存在
console.log('\n=== 文件存在性检查 ===');
let missingFiles = 0;
scenes.forEach(s => {
  const fullPath = path.join('assets', s);
  const exists = fs.existsSync(fullPath);
  if (!exists) {
    console.log('[MISSING] ' + s);
    missingFiles++;
  }
});
if (missingFiles === 0) console.log('全部存在!');

// 2. 按类型统计卡牌数
const types = ['LOCATION','KARMA','STORY','COMBAT','DUNGEON','BOTTLENECK','DESTINY','QUEST','SHOP','BREAKTHROUGH','NORMAL'];
console.log('\n=== 各类型卡牌总数 ===');
types.forEach(t => {
  const tRe = new RegExp('"type"\\s*:\\s*"' + t + '"', 'g');
  const matches = html.match(tRe);
  if (matches) console.log(t + ': ' + matches.length + ' 张');
});

// 3. 找出每种类型中缺少 sceneImage 的卡牌
console.log('\n========================================');
console.log('=== 缺少 sceneImage 的关键卡牌 ===');
console.log('========================================');

// 更精确的解析：找到每个 { ... } 块中的 type 和 title
const results = [];
const cardRe = /{\s*"id"\s*:\s*"([^"]+)"[\s\S]*?"type"\s*:\s*"(\w+)"[\s\S]*?"title"\s*:\s*"([^"]+)"/g;
while ((m = cardRe.exec(html)) !== null) {
  const id = m[1], type = m[2], title = m[3];
  // 回到这个 id 的位置，找整个卡片块
  const start = html.indexOf('"id":"' + id + '"');
  if (start === -1) continue;
  // 找这个块的结束 - 下一个顶级 "id": 或 DATA_MODULES 结束
  let blockEnd = start;
  let depth = 0, inStr2 = false;
  for (let i = start; i < html.length && i < start + 2000; i++) {
    if (html[i] === '"' && (i === 0 || html[i-1] !== '\\')) inStr2 = !inStr2;
    if (inStr2) continue;
    if (html[i] === '{') depth++;
    if (html[i] === '}') { depth--; if (depth === 0) { blockEnd = i + 1; break; } }
  }
  const block = html.substring(start, Math.min(blockEnd, start + 2000));
  const hasScene = block.includes('sceneImage');
  
  // 只报告需要视觉的类型
  if (!['LOCATION','KARMA','STORY','DUNGEON','BOTTLENECK','DESTINY','QUEST'].includes(type)) continue;
  
  if (!hasScene) {
    results.push({type, title, id});
    console.log('[' + type.padEnd(10) + '] ' + title);
  }
}

console.log('\n总计: ' + results.length + ' 张卡牌缺少 sceneImage');

// 4. 统计覆盖率
const typeStats = {};
results.forEach(r => {
  typeStats[r.type] = (typeStats[r.type] || 0) + 1;
});
console.log('\n=== 按类型缺失统计 ===');
Object.entries(typeStats).sort((a,b) => b[1] - a[1]).forEach(([t, c]) => {
  console.log(t + ': 缺少 ' + c + ' 张');
});
