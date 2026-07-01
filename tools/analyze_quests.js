const fs = require('fs');
const path = require('path');
const base = path.join(__dirname, '..', 'data');

const questFiles = ['white_fox','tianshu_codex','body_tribulation','sword_legacy','spell_codex','pill_master'];
const allSeeds = [];
const allQuestNextIds = [];

for(const f of questFiles){
  const data = JSON.parse(fs.readFileSync(path.join(base,'quests',f+'.json'),'utf8'));
  const q = data.quest;
  const cards = data.cards;
  console.log('\n=== 支线: '+q.name+' ('+q.id+') ===');
  console.log('触发条件: startRealm='+q.startRealm+' | pathRestriction='+q.pathRestriction+' | minTurn='+q.trigger.minTurn);
  console.log('requiredFlags='+JSON.stringify(q.trigger.requiredFlags));
  console.log('forbiddenFlags='+JSON.stringify(q.trigger.forbiddenFlags));
  console.log('chainLength声明='+q.chainLength+' | 实际卡数='+cards.length);

  for(const card of cards){
    const step = card.questStep;
    const choices = card.choices;
    let hasEndOnCard = !!card.questEnd;
    let details = [];
    for(const [dir,ch] of Object.entries(choices)){
      if(ch.questEnd) hasEndOnCard = true;
      if(ch.questNext){
        details.push(dir+':questNext->'+ch.questNext);
        allQuestNextIds.push({file:f, cardId:card.id, dir, refId:ch.questNext});
      }
      if(ch.karmaSeed){
        details.push(dir+':karmaSeed->'+ch.karmaSeed.id+'(delay='+ch.karmaSeed.delay+',realm='+ch.karmaSeed.realm+')');
        allSeeds.push({file:f, card:card.id, dir, seedId:ch.karmaSeed.id, delay:ch.karmaSeed.delay, realm:ch.karmaSeed.realm});
      }
    }
    const isLastStep = step === cards.length;
    const hasQN = details.some(d=>d.includes('questNext'));
    const hasKS = details.some(d=>d.includes('karmaSeed'));
    const issues = [];
    if(!isLastStep && !hasEndOnCard && !hasQN && !hasKS){
      issues.push('⚠️断链风险：靠隐式step++无明确连接');
    }
    if(isLastStep && !hasEndOnCard){
      issues.push('⚠️末尾卡无questEnd标记');
    }
    console.log('  Step'+step+' ['+card.id+'] realm='+card.realm+' questEnd='+hasEndOnCard);
    if(details.length) console.log('    连接: '+details.join(' | '));
    if(issues.length) console.log('    '+issues.join('\n    '));
  }

  if(q.rewardOnComplete && q.rewardOnComplete.karmaSeeds){
    for(const s of q.rewardOnComplete.karmaSeeds){
      allSeeds.push({file:f, card:'rewardOnComplete', dir:'reward', seedId:s.id, delay:s.delay, realm:s.realm});
      console.log('  RewardSeed: id='+s.id+' delay='+s.delay+' realm='+s.realm);
    }
  }
}

// 加载因果卡映射
const karmaData = JSON.parse(fs.readFileSync(path.join(base,'cards','karma.json'),'utf8'));
const karmaMap = karmaData.karmaCards;
const karmaCardIds = new Set(karmaData.cards.map(c=>c.id));

console.log('\n\n=== 因果种子映射完整性检查 ===');
for(const s of allSeeds){
  const mapped = karmaMap[s.seedId];
  const hasCard = mapped && karmaCardIds.has(mapped);
  const status = hasCard ? '✅' : (mapped ? '⚠️ 映射存在但对应卡牌缺失' : '❌ karmaCards中无此映射');
  console.log(status+' ['+s.seedId+'] → '+mapped+'  来源:['+s.file+'/'+s.card+'/'+s.dir+'] realm='+s.realm);
}

// 检查未在任何seed中引用但在karmaCards中存在的孤立映射
console.log('\n=== karmaCards中孤立映射（无任何seed引用）===');
const usedSeedIds = new Set(allSeeds.map(s=>s.seedId));
for(const [seedId, cardId] of Object.entries(karmaMap)){
  if(!usedSeedIds.has(seedId)){
    console.log('⚠️ 孤立映射: '+seedId+' → '+cardId+' (无支线种下此seed)');
  }
}

// 检查questNext引用
const allQuestFiles = questFiles.map(f=>JSON.parse(fs.readFileSync(path.join(base,'quests',f+'.json'),'utf8')));
const allCardIdSet = new Set();
for(const qf of allQuestFiles) for(const c of qf.cards) allCardIdSet.add(c.id);

console.log('\n=== questNext引用目标卡牌检查 ===');
for(const ref of allQuestNextIds){
  const exists = allCardIdSet.has(ref.refId);
  console.log((exists?'✅':'❌ 目标卡不存在')+' '+ref.cardId+'/'+ref.dir+' -> '+ref.refId);
}

// 检查requiredFlags来源
console.log('\n=== requiredFlags来源检查（需人工确认）===');
for(const f of questFiles){
  const data = JSON.parse(fs.readFileSync(path.join(base,'quests',f+'.json'),'utf8'));
  const q = data.quest;
  if(q.trigger.requiredFlags && q.trigger.requiredFlags.length > 0){
    console.log('❓ '+q.name+' 需要 flags='+JSON.stringify(q.trigger.requiredFlags));
    // 搜索这些flag在哪里被设置
    for(const flag of q.trigger.requiredFlags){
      let setBy = [];
      for(const qf2 of allQuestFiles){
        for(const c of qf2.cards){
          for(const [dir,ch] of Object.entries(c.choices)){
            if(ch.flags && ch.flags.includes(flag)) setBy.push(qf2.quest.id+'/'+c.id+'/'+dir);
          }
        }
        if(qf2.quest.rewardOnComplete && qf2.quest.rewardOnComplete.flags){
          if(qf2.quest.rewardOnComplete.flags.includes(flag)) setBy.push(qf2.quest.id+'/rewardOnComplete');
        }
      }
      console.log('  flag['+flag+'] 设置来源: '+(setBy.length ? setBy.join(', ') : '❌ 未找到任何设置来源！'));
    }
  }
}

// 检查同境界多支线互斥问题
console.log('\n=== 同境界+同功法支线冲突检查 ===');
const triggerGroups = {};
for(const f of questFiles){
  const data = JSON.parse(fs.readFileSync(path.join(base,'quests',f+'.json'),'utf8'));
  const q = data.quest;
  const key = (q.startRealm||'any')+'|'+(q.pathRestriction||'any');
  if(!triggerGroups[key]) triggerGroups[key]=[];
  triggerGroups[key].push(q.name+'(priority='+q.trigger.priority+')');
}
for(const [key, names] of Object.entries(triggerGroups)){
  if(names.length > 1){
    console.log('⚠️ 冲突组 ['+key+']: '+names.join(', ')+' — 同时满足条件时会互相阻塞');
  } else {
    console.log('✅ '+key+': '+names[0]);
  }
}
