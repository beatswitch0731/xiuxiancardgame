/**
 * DATA_MODULES 补全脚本
 * 读取 index.html，解析 DATA_MODULES，添加新数据，写回。
 */
const fs = require('fs');
const vm = require('vm');

const html = fs.readFileSync('index.html', 'utf8');

// Step 1: Extract DATA_MODULES
const dmRegex = /const DATA_MODULES = (\{[\s\S]*?\});\s*<\/script>/;
const dmMatch = html.match(dmRegex);
if (!dmMatch) { console.error('Cannot find DATA_MODULES'); process.exit(1); }

let dm;
try {
  const ctx = {};
  vm.runInNewContext('dm = ' + dmMatch[1], ctx);
  dm = ctx.dm;
} catch(e) {
  console.error('Parse error:', e.message);
  process.exit(1);
}

// ============================================================
// PATCH 1: NPC Secrets (白落霜, 剑灵儿, 慕青岚, 殷血)
// ============================================================
const npcSecrets = {
  bai_luoxuan: [
    {level:1,text:"她每个月圆之夜都在问九尾一个问题——而九尾从未回答过。"},
    {level:2,text:"白狐部的族人在她小时候被正道猎杀了大半。她不说，但她记得每一张脸。"},
    {level:3,text:"她的本命狐牙里封着一缕混沌之力——九尾亲自封的，说是她的嫁妆。"}
  ],
  jian_linger: [
    {level:1,text:"剑灵儿每天多练两个时辰的剑——白刃不知道。"},
    {level:2,text:"她偷看过白刃藏在剑冢密室里的手札。上面写的不是剑法——是遗书。"}
  ],
  mu_qinglan: [
    {level:1,text:"慕青岚睡在万卷楼——不是值班，是真的睡在那里。她的道号是'书呆子'。"},
    {level:2,text:"她私下在研究一本被天枢道院列为禁书的古籍——《逆灵论》。"}
  ],
  yin_xue: [
    {level:1,text:"殷血的剑是仇人的剑。他把仇人的名字刻在剑身上——已经刻了十七个。"},
    {level:2,text:"血煞老祖不是他师父。是他父亲。这件事整个血煞宗只有三个人知道。"}
  ],
  xuesha_laozu: [
    {level:1,text:"血煞老祖每个月给青云剑宗送一次灵石——走的是私下渠道，上面没有人知道。"}
  ]
};

for (const npc of dm['npcs:core'].npcs) {
  if (npcSecrets[npc.id] && (!npc.secrets || npc.secrets.length === 0)) {
    npc.secrets = npcSecrets[npc.id];
    console.log('Added secrets to', npc.id, ':', npc.secrets.length, 'secrets');
  }
}

// ============================================================
// PATCH 2: Golden Realm Cards (金丹期 — 8 cards)
// ============================================================
dm['cards:golden'] = {
  realm: 'golden',
  realmName: '金丹期',
  cards: [
    {
      id: 'g_core', title: '金丹初成',
      description: '丹田中金丹初成，光芒万丈。你的灵力凝实了十倍，天地间的灵气主动向你涌来。',
      type: 'NORMAL', realm: 'golden', weight: 0, once: true,
      choices: {
        left: {text:'潜心温养金丹', effects:{cultivation:10, daoHeart:10, fortune:5}},
        right: {text:'借势冲刺', effects:{cultivation:25, health:-10, karmaBad:5}}
      },
      tags: ['breakthrough']
    },
    {
      id: 'g_demon_war', title: '正魔暗涌',
      description: '正道各派密信往来愈加频繁。你偶然截获一封密函——三年内，正魔大战必将爆发。',
      type: 'NORMAL', realm: 'golden', weight: 8,
      choices: {
        left: {text:'将密函上交宗门', effects:{daoHeart:5, karmaGood:8}},
        right: {text:'私藏密函以待时机', effects:{fortune:8, karmaBad:5}}
      },
      tags: ['war', 'foreshadowing']
    },
    {
      id: 'g_thunder_trial', title: '金丹雷劫',
      description: '天雷滚滚，金丹修士必经的小雷劫降临。你的金丹在雷光中剧烈震动。',
      type: 'NORMAL', realm: 'golden', weight: 10,
      choices: {
        left: {text:'以丹硬抗', effects:{cultivation:20, health:-25, fortune:5}},
        right: {text:'用丹药护体', effects:{cultivation:10, health:-5}}
      },
      tags: ['tribulation', 'risk']
    },
    {
      id: 'g_ancient_ruin', title: '上古遗迹',
      description: '金丹期才勉强能破开的禁制——一座被遗忘的上古修士洞府在你面前缓缓开启。',
      type: 'NORMAL', realm: 'golden', weight: 7,
      choices: {
        left: {text:'谨慎探索外围', effects:{cultivation:15, treasure:'ancientJade', fortune:5}},
        right: {text:'直入核心禁地', effects:{cultivation:30, health:-30, treasure:'ancientCore', karmaBad:10}}
      },
      tags: ['exploration', 'risk', 'treasure']
    },
    {
      id: 'g_disciple', title: '收徒之议',
      description: '宗门长老希望你在金丹期收一名弟子——这是金丹修士的传统。',
      type: 'NORMAL', realm: 'golden', weight: 6,
      choices: {
        left: {text:'收一名孤儿为徒', effects:{daoHeart:10, karmaGood:10, spiritStone:-20}},
        right: {text:'婉拒，专注己道', effects:{cultivation:15, daoHeart:-3}}
      },
      tags: ['social']
    },
    {
      id: 'g_herb_king', title: '药王谷邀请',
      description: '药王谷谷主亲自送来请柬——邀请你参加百年一度的百草大典。各家丹修都会展示最得意的丹药。',
      type: 'NORMAL', realm: 'golden', weight: 8,
      choices: {
        left: {text:'前往交流', effects:{cultivation:10, pill:'spiritPill', daoHeart:5}},
        right: {text:'婉拒，不凑热闹', effects:{cultivation:8, daoHeart:3}}
      },
      tags: ['social', 'trade']
    },
    {
      id: 'g_body_refine', title: '炼体秘境',
      description: '一座只允许金丹期体修进入的秘境——据说里面的重力是外界的百倍。',
      type: 'NORMAL', realm: 'golden', weight: 5, path: 'body',
      choices: {
        left: {text:'在百倍重力下淬炼', effects:{cultivation:25, health:-20, daoHeart:10}},
        right: {text:'量力而行', effects:{cultivation:12, health:-5}}
      },
      tags: ['body', 'risk']
    },
    {
      id: 'g_sect_meeting', title: '宗门大会',
      description: '各大宗门在灵虚山召开金丹级修士大会，商议对抗血煞宗扩张的策略。',
      type: 'NORMAL', realm: 'golden', weight: 7,
      choices: {
        left: {text:'主战——先发制人', effects:{cultivation:5, daoHeart:-5, karmaBad:10}},
        right: {text:'主和——寻求共存', effects:{daoHeart:10, karmaGood:10}},
        up: {text:'主防——加固宗门大阵', effects:{cultivation:8, daoHeart:8, fortune:3}}
      },
      tags: ['social', 'faction', 'war']
    }
  ]
};

// ============================================================
// PATCH 3: foxGratitude Karma Card + Mapping
// ============================================================
const karmaFoxGratitude = {
  id: 'k_fox_gratitude', title: '狐族的回报',
  description: '白狐部通过秘法传讯——一位白狐族战士在危难之际突然现身。她的命是你救的，现在她来救你了。',
  type: 'KARMA', realm: 'foundation', weight: 0,
  choices: {
    left: {text:'接受庇护', effects:{health:30, fortune:15, daoHeart:5}},
    right: {text:'让她回去', effects:{daoHeart:15, karmaGood:10, fortune:5}}
  },
  tags: ['karma', 'white_fox']
};

// Add card to cards:qi
dm['cards:qi'].cards.push(karmaFoxGratitude);

// Add karma mapping: foxGratitude → k_fox_gratitude
if (!dm['cards:qi'].karmaCards) dm['cards:qi'].karmaCards = {};
dm['cards:qi'].karmaCards['foxGratitude'] = 'k_fox_gratitude';

console.log('Added foxGratitude karma card + mapping');

// ============================================================
// PATCH 4: New Faction — 药王谷 (Yaowang Valley, pill/body path)
// ============================================================
dm['world:factions'].factions.push({
  id: 'yaowang_valley',
  name: '药王谷',
  icon: '🌿',
  type: 'neutral',
  startReputation: 0,
  subfactions: [
    {id:'yaowang_classic', name:'古丹派（药老）', startReputation:10},
    {id:'yaowang_radical', name:'革新派（百草真人）', startReputation:0},
    {id:'yaowang_poison', name:'毒宗暗流', startReputation:-10}
  ],
  undercurrentId: 'yaowang_secret',
  events: [
    {
      id: 'pill_1', title: '百草大典试丹',
      minRealm: 'foundation', pathRestriction: 'pill',
      minReputation: 0,
      desc: '药王谷十年一度的百草大典——谷主药老亲自坐镇。新丹药的成败，关乎药王谷未来十年的丹药配给。',
      weight: 12,
      choices: {
        left: {text:'展示丹药，争取名额', reputationDelta:15, effects:{cultivation:10, fortune:5}},
        right: {text:'观摩为主，低调学习', reputationDelta:5, effects:{cultivation:8, daoHeart:8}}
      }
    },
    {
      id: 'pill_2', title: '毒宗密信',
      minRealm: 'golden', pathRestriction: 'pill',
      minReputation: 20,
      desc: '一封未署名的密信出现在你的丹房里——毒宗暗流邀请你合作，研究一种能突破境界瓶颈的禁药。',
      weight: 8,
      choices: {
        left: {text:'上报药老', reputationDelta:10, effects:{daoHeart:10, karmaGood:5}},
        right: {text:'私下接触', reputationDelta:-15, subfactionId:'yaowang_poison', subReputationDelta:20, effects:{cultivation:20, karmaBad:15}}
      }
    }
  ]
});

// Add undercurrent for 药王谷
dm['world:factions'].undercurrents['yaowang_secret'] = {
  id: 'yaowang_secret',
  name: '药王谷禁药之争',
  stage: 0,
  maxStage: 4,
  stages: {
    '0': '药王谷看似平静——两种炼丹路线暗中较劲。',
    '1': '毒宗暗流开始接触谷内弟子。百草真人公开批评药老保守。',
    '2': '革新派在百草大典上提出了禁药方案——药老当众驳斥。',
    '3': '毒宗暗流策划分裂药王谷。一封信送到了你的手上——你必须站队。',
    '4': '禁药之争平息。药王谷统一了新的炼丹准则——但代价是你失去了一些朋友。'
  }
};

console.log('Added Yaowang Valley faction with events + undercurrent');

// ============================================================
// PATCH 5: New Quest — "药王传承" (Pill path)
// ============================================================
dm['quests:pill_master'] = {
  quest: {
    id: 'pill_master_line',
    name: '药王传承',
    type: 'PATH',
    startRealm: 'foundation',
    pathRestriction: 'pill',
    trigger: {
      minTurn: 12,
      requiredFlags: null,
      forbiddenFlags: ['pillMasterCompleted', 'quest_pill_master_line_active'],
      requiredAttributes: null,
      priority: 7
    },
    entryCardId: 'q_pillMaster_quest',
    chainLength: 3,
    rewardOnComplete: {
      attributes: {cultivation:15, daoHeart:10, fortune:10},
      resources: {spiritStone:30, treasures:['pillMasterStone']},
      flags: ['pillMasterCompleted'],
      karmaSeeds: [{id:'pillLegacy', delay:15, realm:'golden', priority:3}]
    }
  },
  cards: [
    {
      id: 'q_pillMaster_quest', title: '药老托梦',
      description: '你在丹房打盹时梦到一位白发老翁——药王谷的创始人药老。他说你的丹火里有一缕他的旧火，问你是否愿意继承真传。',
      type: 'QUEST', questId: 'pill_master_line', questStep: 1, realm: 'foundation', weight: 0,
      choices: {
        left: {text:'婉拒——道不同', effects:{daoHeart:10, cultivation:5}, questEnd:true},
        right: {text:'接受试炼', effects:{daoHeart:3, fortune:-5}, karmaSeed:{id:'pillTrial', delay:3, realm:'foundation', priority:2}}
      }
    },
    {
      id: 'q_pillMaster_2', title: '三味真火',
      description: '药老的试炼：三日之内炼出三味不同属性的丹药——一味补元、一味解毒、一味破障。丹房里的药童都在看你。',
      type: 'QUEST', questId: 'pill_master_line', questStep: 2, realm: 'foundation', weight: 0,
      choices: {
        left: {text:'通宵达旦，一气呵成', effects:{cultivation:20, health:-15, fortune:5}},
        right: {text:'分步精炼，稳扎稳打', effects:{cultivation:12, daoHeart:8, pill:'regen'}}
      }
    },
    {
      id: 'q_pillMaster_3', title: '薪火相传',
      description: '丹药大成。药老在梦中接过你炼的三枚丹，端详良久。他说这三枚丹药里有年轻人的狂妄、耐心、和恐惧——都是好火。丹火就是这样传下去的。',
      type: 'QUEST', questId: 'pill_master_line', questStep: 3, realm: 'foundation', weight: 0,
      choices: {
        left: {text:'叩谢药老', effects:{cultivation:10, daoHeart:15, fortune:10, pill:'spiritPill'}, questEnd:true},
        right: {text:'问药老还有何教诲', effects:{cultivation:5, daoHeart:20, fortune:5}, questEnd:true}
      }
    }
  ]
};

console.log('Added Pill Master quest (3 cards)');

// ============================================================
// PATCH 6: Fix Bai Ren dialogue #3 and #6
// ============================================================
const baiRen = dm['npcs:core'].npcs.find(n => n.id === 'bai_ren');
if (baiRen) {
  // Fix dialogue #3 (修炼 50-79): too precise
  const d3 = baiRen.dialogues.find(d => d.minAffection === 50 && d.maxAffection === 79);
  if (d3) d3.text = '嗯。快了。不是剑快了——是你慢了。想太多，剑就重。';

  // Fix dialogue #5 (闲聊 80+): rephrase as self-talk
  const d5 = baiRen.dialogues.find(d => d.scene === '闲聊' && d.minAffection === 80);
  if (d5) d5.text = '……陆沉舟。他发现了。所以他走了。我不认同——但我不拦。各人各命。';

  // Fix dialogue #6 (请教): remove 3rd person narration
  const d6 = baiRen.dialogues.find(d => d.scene === '请教');
  if (d6) d6.text = '看清楚了。这一剑——不在快，在准。你试试。';

  console.log('Fixed Bai Ren dialogues');
}

// ============================================================
// Step 2: Serialize and write back
// ============================================================
const newDM = 'const DATA_MODULES = ' + JSON.stringify(dm) + ';';

const before = html.substring(0, dmMatch.index);
const after = html.substring(dmMatch.index + dmMatch[0].length);
const newHtml = before + newDM + '\n</script>\n' + after;

// Verify syntax
try {
  const dmRegex2 = /const DATA_MODULES = (\{[\s\S]*?\});\s*$/m;
  const m2 = newHtml.match(dmRegex2);
  if (m2) {
    const ctx2 = {};
    vm.runInNewContext('dm2 = ' + m2[1], ctx2);
    console.log('\nFinal DATA_MODULES verification:');
    console.log('  NPCs:', ctx2.dm2['npcs:core'].npcs.length);
    console.log('  Card realms:', Object.keys(ctx2.dm2).filter(k=>k.startsWith('cards:')).join(', '));
    console.log('  Quests:', Object.keys(ctx2.dm2).filter(k=>k.startsWith('quests:')).map(k=>k.split(':')[1]).join(', '));
    console.log('  Factions:', ctx2.dm2['world:factions'].factions.length);
    console.log('  karmaCards in qi:', Object.keys(ctx2.dm2['cards:qi'].karmaCards||{}).join(', '));
  }
} catch(e) {
  console.error('Output verification failed:', e.message);
  process.exit(1);
}

fs.writeFileSync('index.html', newHtml);
console.log('\n✅ index.html updated successfully');
console.log('Backup at: index.html.bak');
fs.writeFileSync('index.html.bak', html);
