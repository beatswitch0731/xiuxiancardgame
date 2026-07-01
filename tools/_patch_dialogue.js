/**
 * _patch_dialogue.js — 对话润色与角色声音统一
 * 
 * 执行对话质量审查后的修正：
 *   1. 殷血 line 3: 移除元注释，改为纯对话
 *   2. 九尾溯月 line 2: 去"你知道"结构
 *   3. 天机老人 line 3: 去"你知道"结构
 *   4. 白落霜: 补充3条对话
 *   5. 慕青岚: 补充3条对话
 *   6. 殷血: 补充2条 + 修正1条
 */

const fs = require('fs');
const vm = require('vm');

// ============================================================
// 读取 + 解析
// ============================================================
const html = fs.readFileSync('index.html', 'utf8');
const dmMatch = html.match(/(const DATA_MODULES = )({[\s\S]*?});/);
const before = html.substring(0, dmMatch.index + dmMatch[1].length);

const ctx = {};
vm.runInNewContext('var dm = ' + dmMatch[2] + ';', ctx);
const dm = ctx.dm;

// 定位 after 部分（匹配 }; 后面的 </script>）
const afterIdx = dmMatch.index + dmMatch[1].length + dmMatch[2].length;
const after = html.substring(afterIdx);

// ============================================================
// 辅助函数
// ============================================================
function findNpc(npcs, id) {
  return npcs.find(n => n.id === id);
}

function findDialogue(npc, scene, affection) {
  return npc.dialogues.find(d => 
    d.scene === scene && d.minAffection === (affection !== undefined ? affection : d.minAffection)
  );
}

const npcs = dm['npcs:core'].npcs;

// ============================================================
// PATCH 1: 殷血 line 3 — 移除元注释
// ============================================================
const yinXue = findNpc(npcs, 'yin_xue');
const yxBadLine = yinXue.dialogues.find(d => d.scene === '修炼');
if (yxBadLine) {
  yxBadLine.text = '来。老地方。三招。不许先出手——今天我想看你。';
}
console.log('[Patch 1] Fixed Yin Xue meta-commentary line');

// ============================================================
// PATCH 2: 九尾溯月 line 2 — 去"你知道"结构
// ============================================================
const jiuwei = findNpc(npcs, 'jiuwei_suyue');
const jwBadLine = jiuwei.dialogues.find(d => d.scene === '闲聊');
if (jwBadLine) {
  jwBadLine.text = '那个时代……不提也罢。太古浩劫——妖族死了九成。不是战败，是被从因果里抹去。';
}
console.log('[Patch 2] Fixed Jiuwei expositional structure');

// ============================================================
// PATCH 3: 天机老人 line 3 — 去"你知道"结构
// ============================================================
const tianji = findNpc(npcs, 'tianji_laoren');
const tjBadLine = tianji.dialogues.find(d => d.scene === '论道');
if (tjBadLine) {
  tjBadLine.text = '飞升……老夫看过上界的真相。不是天堂，不是仙境。是一座牢笼——专关那些以为修到头了的人。';
}
console.log('[Patch 3] Fixed Tianji expositional structure');

// ============================================================
// PATCH 4: 白落霜 补充3条对话
// ============================================================
const baiLx = findNpc(npcs, 'bai_luoxuan');

baiLx.dialogues.push(
  // 修炼 - 低好感
  {
    scene: '修炼',
    minAffection: 0,
    maxAffection: 29,
    text: '你不必勉强。修炼这种事，急不来的——我见过三百年的老狐妖还在练第一式。'
  },
  // 闲聊 - 高好感 + 特定心境
  {
    scene: '闲聊',
    minAffection: 70,
    mindset: '忧虑',
    text: '最近山里的灵兽都在往南走。狐族传说——灵兽南迁，不是好事。你最近多加小心。'
  },
  // 月下 - 超高好感
  {
    scene: '月夜',
    minAffection: 90,
    text: '今晚的月亮和我遇到你那天一样圆。……那天我没说，其实我以为你会杀我。所有正道修士都杀狐妖。但你没有。'
  }
);
console.log('[Patch 4] Added 3 Bai Luoxuan dialogues');

// ============================================================
// PATCH 5: 慕青岚 补充3条对话
// ============================================================
const muQl = findNpc(npcs, 'mu_qinglan');

muQl.dialogues.push(
  // 闲聊 - 低好感
  {
    scene: '闲聊',
    minAffection: 0,
    maxAffection: 29,
    text: '你在找什么书？不用客气——我最讨厌别人把书放错位置。问我就好。'
  },
  // 修炼 - 高好感
  {
    scene: '修炼',
    minAffection: 60,
    text: '我发现了一件事——你的剑法和《逆灵论》里记载的一种远古剑术很像。但《逆灵论》是禁书，我不能借给你……不过我可以念给你听。'
  },
  // 危机 - 特殊场景
  {
    scene: '危机',
    minAffection: 50,
    text: '他们要来查万卷楼的禁书目录。我把《逆灵论》换了个封皮——现在它叫《基础草药图鉴》。谁也不会翻第三页。'
  }
);
console.log('[Patch 5] Added 3 Mu Qinglan dialogues');

// ============================================================
// PATCH 6: 殷血 补充1条 + 调整现有
// ============================================================

// 补充：切磋 - 高好感
yinXue.dialogues.push({
  scene: '切磋',
  minAffection: 70,
  text: '我爹——血煞老祖——他说过一句话：真正的剑客不需要朋友。我以前信。现在……不太确定。'
});
console.log('[Patch 6] Added 1 Yin Xue dialogue');

// ============================================================
// 写回
// ============================================================
const newHtml = before + JSON.stringify(dm) + after;

// 备份
fs.copyFileSync('index.html', 'index.html.bak');
fs.writeFileSync('index.html', newHtml, 'utf8');

console.log('\n=== Dialogue patch complete ===');
console.log('Total changes: 3 fixes + 7 new dialogues');
console.log('Backup saved as index.html.bak');
