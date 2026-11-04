/**
 * 叙事连贯性层 (Narrative Coherence Layer)
 *
 * 解决"选了卡但没有因果故事感"的核心设计问题。
 * 整合三个子系统：
 *   A. ChoiceNarrator  — 效果→叙事日志（让每次选择有叙事重量）
 *   B. TransitionBridge — 卡牌间过渡文字（世界状态在文本中可见）
 *   C. CrossReferenceWeaver — 支线×线程交叉引用（动态描述增强）
 */

class NarrativeCoherenceLayer {

  constructor() {
    // ── A: Choice Narrator 效果→叙事模板 ──
    this.effectNarratives = {
      cultivation: [
        '你运转周天，{value}缕灵气凝入丹田。',
        '一番历练，你对大道的感悟又深了几分。修为+{value}。',
        '你屏息凝神，汲取天地灵气，修为增长{value}。',
        '此间经历化作修行资粮，修为+{value}。',
      ],
      health: [
        '你服下丹药，药力化开，伤势好转{value}分。',
        '调息片刻，内伤已无大碍。生命+{value}。',
        '经脉中的瘀滞被冲开，身体恢复了几分。生命+{value}。',
      ],
      daoHeart: [
        '此番抉择之后，你的道心愈发坚定。道心+{value}。',
        '你审视自己的本心——这条路，你没有走错。道心+{value}。',
        '因果循环，善恶有报。你对天道的敬畏又多了一分。道心+{value}。',
      ],
      spiritStone: [
        '你清点行囊，灵石多了{value}枚。',
        '一笔意外之财落入手中。灵石+{value}。',
        '你掂了掂钱袋，份量沉了几分。灵石+{value}。',
      ],
      karmaBad: [
        '你的手上沾了不该沾的血——恶业+{value}。天网恢恢，不知何时会收网。',
        '你选择了最利的刀——但它划开的不只是敌人。恶业+{value}。',
        '杀意入心。道心蒙尘。恶业+{value}。',
      ],
      karmaGood: [
        '善念一动，如春风拂面。功德+{value}。',
        '你在黑暗中点了一盏灯——虽然微弱，但终究是光。功德+{value}。',
      ],
      fortune: [
        '冥冥中，你感到一丝气运加身。气运+{value}。',
        '命运的丝线在你指尖轻轻一颤。气运+{value}。',
        '你抬头看了看天——今日运势似乎不错。气运+{value}。',
      ],
      knowledge: [
        '这番经历为你打开了一扇新的门。见识+{value}。',
        '你细细品味方才所见——其中有大学问。见识+{value}。',
        '一卷残篇也好，一句点拨也罢——皆是修行路上的阶梯。见识+{value}。',
      ],
      exp: [
        '你隐隐触摸到了下一个境界的门槛。经验+{value}。',
        '周天运转间，你感到瓶颈松动了一丝。经验+{value}。',
      ],
      pill: [
        '你将丹药收入袖中。这颗丹或许会在关键时刻救你一命。',
        '丹药入手——药香扑鼻，品相不凡。',
      ],
      treasure: [
        '这件法宝入手温热——上面还残留着前主人的灵力印记。',
        '你将宝物小心收好。这等机缘，可遇不可求。',
      ],
      companion: [
        '你感到一道目光落在背上——那人对你的态度，悄然发生了变化。',
        '缘起缘灭，皆在人心一念之间。',
      ],
      lifespan: [
        '你感觉到——自己的寿元又短了一分。修仙之路，从来都是与时间赛跑。',
        '烛火摇曳。每一息都在燃烧寿命。',
      ],
      // fallback for unknown effects
      _default: [
        '你做出了选择——前路因此改变了细微的角度。',
        '这一步踏出，便再无回头之路。',
      ],
    };

    // ── B: Transition Bridge 卡牌间过渡模板 ──
    this.transitionTemplates = {
      thread_continuation: [
        '「{threadTitle}」——上次的线索还悬在心里，那件事还没完。',
        '关于{threadTitle}的事，你总觉得背后还有更大的隐情。',
        '{threadTitle}的余波未平。你停下脚步，察觉到了一丝异样。',
      ],
      karma_reminder: [
        '你能感觉到——某种因果正在暗中编织，丝丝缕缕，牵着你往前走。',
        '天地之间，因果如网。你已身处网中而不自知。',
        '一颗因果的种子正在发芽。你隐隐有种预感——有什么事就要发生了。',
      ],
      npc_memory: [
        '你想起{npcName}说过的话。当时不觉得什么，此刻却品出了另一层意味。',
        '{npcName}的身影在脑中一闪而过——不知他如今怎样了。',
        '你依稀记得{npcName}的眼神——那是藏了话的眼神。',
      ],
      world_state: [
        '自{event}以来，这片区域的氛围似乎都变了。',
        '你能感觉到——{event}之后，某种平衡被打破了。',
        '{event}的事传遍了方圆百里。散修们议论纷纷。',
      ],
      quest_active: [
        '你惦记着{questTitle}的事——这条线索不能断。',
        '{questTitle}还没有了结。你在心中默念了一遍已知的信息。',
      ],
      realm_feel: [
        '炼气期的修行人，如地上蝼蚁，仰望苍穹。每一步都走得战战兢兢。',
        '修真界暗流涌动。你这一路走来，遇见过善人，也撞见过恶鬼。',
        '夜色深沉。修仙界的每一寸土地下，都埋着不为人知的秘密。',
        '你踏在修真界的边缘——往前一步是机缘，往后一步是深渊。',
        // v2.1 中后期境界感悟
        '筑基已成，你已不再是凡人之躯。但道途漫漫，这不过是第一道坎。',
        '金丹在丹田中缓缓旋转——你感到天地灵气从未如此清晰。',
        '元婴初成，魂魄已然可以短暂离体。你对"生"与"死"的界限，有了新的理解。',
        '化神之后，你隐隐感应到了天道规则的轮廓——那是一种比灵力更古老的力量。',
        '渡劫在即。天雷的威压已经能从云层中嗅到。',
      ],
      general: [
        '你深吸一口气，继续前行。',
        '前路漫漫。道心为灯。',
        '风从远处吹来，带着不知名的花香——这里离城镇已经有些远了。',
        '你环顾四周。修真界的风景，从来都是暗藏杀机。',
      ],
    };

    // ── C: Cross-Reference Weaver 支线×线程交叉引用 ──
    // key: "threadId×questId" 或 "questId×threadId"
    this.threadQuestRefs = {
      // 荒村妖道 × 白狐报恩
      'abandoned_village×white_fox':
        '你想起了白狐——它曾经也受过类似的伤。这药引的来历，怕是与妖族有关。',
      'white_fox×abandoned_village':
        '荒村妖道的事让你多了一分警惕——妖与人之间，未必是谁害谁。',
      // 灵石矿脉 × 天书残卷
      'spirit_mine×tianshu_codex':
        '你想起天书残卷上的记载——矿脉深处，似乎藏着某种阵法遗迹。',
      'tianshu_codex×spirit_mine':
        '矿脉之争让你意识到——天书上记载的那些上古遗迹，恐怕都有人在找。',
      // 剑冢奇遇 × 剑道传承
      'sword_tomb×sword_legacy':
        '剑冢的经历还历历在目——古剑认主之时的剑气，与剑道传承中的描述如出一辙。',
      'sword_legacy×sword_tomb':
        '剑冢中古剑的剑鸣，与剑道传承记载的上古剑诀遥相呼应。',
      // 药王谷叛逃 × 丹道大师
      'herb_valley×pill_master':
        '药王谷叛徒兜售的丹药——你拿给丹道大师看了。他只说："禁药。但配方值得研究。"',
      'pill_master×herb_valley':
        '丹道大师提过，药王谷的水很深——如今看来，他所言非虚。',
      // 雾隐山谷 × 炼体劫
      'mist_valley×body_tribulation':
        '前人洞府中遗留的炼体法门——与你正在经历的炼体劫，有着某种微妙的呼应。',
      'body_tribulation×mist_valley':
        '炼体劫的痛苦让你想起雾隐山谷中那间洞府——前人留下的笔记里，记载了相似的苦楚。',
      // 雾隐山谷 × 法术法典
      'mist_valley×spell_codex':
        '洞府石壁上的禁术刻痕——与法术法典中提到的失传秘术，似乎是同一种文字。',
      'spell_codex×mist_valley':
        '你在整理法术法典时，发现一个字符与雾隐山谷洞府石壁上的完全一致。',
      // 荒村妖道 × 炼体劫
      'abandoned_village×body_tribulation':
        '妖道体内那股诡异药力——让你体内的炼体劫又躁动了几分。这两者之间，怕是有联系。',
      // 灵石矿脉 × 白狐报恩
      'spirit_mine×white_fox':
        '白狐似乎对那片矿脉格外敏感——它在你脚边低鸣，像是在警告什么。',
      // 剑冢奇遇 × 天书残卷
      'sword_tomb×tianshu_codex':
        '剑冢的壁画上——有一角残文，与天书残卷上的某个符号完全吻合。',
      // 药王谷叛逃 × 白狐报恩
      'herb_valley×white_fox':
        '药王谷叛徒看你的时候——眼睛里有恐惧。白狐曾经也有过一模一样的眼神。',
      // 荒村妖道 × 剑道传承
      'abandoned_village×sword_legacy':
        '妖道用的剑法——虽然走了邪路，但根基分明是青云剑宗的正统剑术。',
      // ── v2.1 扩展交叉引用（覆盖更多线程×支线组合）──
      // 白狐报恩 × 丹道大师
      'white_fox×pill_master':
        '白狐曾经叼来一株奇草——丹道大师看过之后沉默了许久，只说了一句："狐族认得这味药，不简单。"',
      'pill_master×white_fox':
        '丹道大师提到，狐族的丹道天赋不下于人族——白狐报恩时送来的那株药，就是证据。',
      // 白狐报恩 × 炼体劫
      'white_fox×body_tribulation':
        '炼体劫发作时，白狐在你身边低鸣——它的灵气似乎在帮你压制体内的躁动。',
      'body_tribulation×white_fox':
        '炼体劫的痛楚中，你想起白狐曾经用同样的方式安抚过你——妖族的疗伤之术，与人族大不相同。',
      // 天书残卷 × 炼体劫
      'tianshu_codex×body_tribulation':
        '天书残卷上有一页记载了上古炼体士的秘法——与你正在经历的炼体劫，路子惊人地相似。',
      'body_tribulation×tianshu_codex':
        '炼体劫的痛苦让你下意识地想起天书上的那段文字——"破而后立，死而后生"。',
      // 天书残卷 × 法术法典
      'tianshu_codex×spell_codex':
        '天书残卷与法术法典——同是上古之物，却走了完全不同的路。一个求道，一个求术。',
      'spell_codex×tianshu_codex':
        '法术法典的编纂者，似乎在刻意回避天书上记载的那些"禁术"。这两本书的作者——怕是认识。',
      // 剑道传承 × 灵石矿脉
      'sword_legacy×spirit_mine':
        '剑道传承中提到一把上古名剑——据记载，它就沉在某条灵脉的深处。',
      'spirit_mine×sword_legacy':
        '矿脉深处涌出的灵压——与剑道传承中描述的"剑意共鸣"如出一辙。下面不只有灵石。',
      // 丹道大师 × 药王谷叛逃
      'pill_master×herb_valley':
        '丹道大师看了看你从药王谷带回来的丹方残页——"这不是废方。这是有人故意撕掉的。"',
      'herb_valley×pill_master':
        '药王谷的叛徒逃走时，带走了不止一种禁药配方。丹道大师说——其中至少三种，他还认得。',
      // 正魔线交织 × 白狐报恩
      'demon_first_contact×white_fox':
        '白狐在魔道中人靠近时炸了毛——妖族对魔气的敏感，远超你的想象。',
      // 正魔线交织 × 剑道传承
      'demon_first_contact×sword_legacy':
        '剑道传承的祖师爷曾与魔道第一高手决战——那一战的剑痕，至今还留在青云剑宗的古壁上。',
      // 正魔线交织 × 天书残卷
      'demon_first_contact×tianshu_codex':
        '天书残卷中有一段被抹去的记载——字迹依稀可辨："魔道非魔，正道非正"。',
    };

    // ── 运行时状态 ──
    this._lastTransitionTurn = -1;
    this._transitionCooldown = 1;   // 过渡文字最小间隔（回合）— 从2降到1，避免叙事断气太久
    this._transitionProbability = 0.50; // 普通过渡出现概率 — 从0.35提升，确保约一半的卡牌间有桥梁文字
    this._lastNarratedTurn = -1;
    this._lastEffects = null;
    this._pendingTransition = null;
  }

  // ═══════════════════════════════════════════════
  //  A. Choice Narrator — 效果→叙事日志
  // ═══════════════════════════════════════════════

  /**
   * 为玩家选择生成叙事日志文本
   * @returns {string|null} 叙事文本，null 表示无叙事
   */
  narrateChoice(card, direction, choice, gameState, settlement = null) {
    const effects = choice.effects || {};
    const changes = Array.isArray(settlement?.changes) ? settlement.changes : null;
    const actualByKey = changes
      ? new Map(changes.map(change => [
        change && change.key,
        Number(change?.actualDelta ?? change?.delta)
      ]))
      : null;
    const lines = [];
    let hasNarrative = false;

    for (const [key, requestedValue] of Object.entries(effects)) {
      // The choice definition is a preview. Once a settlement receipt exists,
      // narration must consume the committed delta so capped/blocked effects
      // cannot claim a reward the player did not actually receive.
      const value = actualByKey ? actualByKey.get(key) : requestedValue;
      if (!Number.isFinite(Number(value)) || Number(value) === 0) continue;
      const templates = this.effectNarratives[key] || this.effectNarratives._default;
      if (!templates) continue;

      const absVal = Math.abs(Number(value));
      let template = templates[Math.floor(Math.random() * templates.length)];
      template = template.replace('{value}', absVal);
      lines.push(template);
      hasNarrative = true;
    }

    if (!hasNarrative) return null;

    // 限制最多2条，避免刷屏
    const chosen = lines.slice(0, 2);
    this._lastNarratedTurn = gameState.turn;
    this._lastEffects = effects;
    return '> ' + chosen.join(' ');
  }

  /**
   * 获取最近一次选择的效果摘要（供过渡文字参考）
   */
  getLastEffectsSummary() {
    if (!this._lastEffects) return null;
    const keys = Object.keys(this._lastEffects);
    if (keys.length === 0) return null;
    return keys.slice(0, 3).join('/');
  }

  // ═══════════════════════════════════════════════
  //  B. Transition Bridge — 卡牌间过渡文字
  // ═══════════════════════════════════════════════

  /**
   * 在进入下一张卡之前生成过渡文字
   * @returns {string|null} 过渡文字，null 表示跳过
   */
  buildTransition(nextCard, gameState, threadEngine, questSystem, npcSystem) {
    // 冷却检查
    if (gameState.turn - this._lastTransitionTurn < this._transitionCooldown) {
      return null;
    }

    const candidates = [];
    let isStrongTrigger = false; // 强叙事触发时不检查概率

    // 1. 线程续接 — 最高优先级
    if (threadEngine && nextCard._threadId) {
      const threadInfo = this._getThreadInfo(threadEngine, nextCard._threadId);
      if (threadInfo && threadInfo.currentNodeIndex > 0) {
        candidates.push({
          text: this._pickTemplate('thread_continuation', { threadTitle: threadInfo.title }),
          weight: 4,
        });
        isStrongTrigger = true;
      }
    }

    // 2. 因果种子提醒 — 有活种子时触发，接近发芽时权重翻倍
    const activeSeeds = gameState.karmaSeeds ? gameState.karmaSeeds.filter(s => s.delay <= 3) : [];
    if (activeSeeds.length > 0) {
      candidates.push({
        text: this._pickTemplate('karma_reminder'),
        weight: activeSeeds.some(s => s.delay <= 0) ? 5 : 3, // 已成熟种子：强提醒
      });
    }

    // 3. 活跃支线提醒
    if (questSystem && questSystem.activeQuests && questSystem.activeQuests.length > 0) {
      const active = questSystem.activeQuests[0];
      if (active && active.questId) {
        const questTitle = this._getQuestTitle(questSystem, active.questId);
        candidates.push({
          text: this._pickTemplate('quest_active', { questTitle }),
          weight: 2,
        });
      }
    }

    // 4. NPC 记忆 — 最近有互动的 NPC
    if (npcSystem && gameState.choiceHistory && gameState.choiceHistory.length > 0) {
      const recent = gameState.choiceHistory.slice(-3).find(h => h.npcName);
      if (recent && recent.npcName) {
        candidates.push({
          text: this._pickTemplate('npc_memory', { npcName: recent.npcName }),
          weight: 2,
        });
      }
    }

    // 5. 世界状态变化
    const recentFlags = this._getRecentFlags(gameState);
    if (recentFlags.length > 0) {
      const flagName = this._flagToNarrative(recentFlags[0]);
      if (flagName) {
        candidates.push({
          text: this._pickTemplate('world_state', { event: flagName }),
          weight: 2,
        });
      }
    }

    // 6. 境界感悟
    candidates.push({
      text: this._pickTemplate('realm_feel'),
      weight: 1,
    });

    // 7. 通用过渡
    candidates.push({
      text: this._pickTemplate('general'),
      weight: 1,
    });

    // 加权随机选取
    const totalWeight = candidates.reduce((s, c) => s + c.weight, 0);
    let roll = Math.random() * totalWeight;

    // 非强触发时检查概率
    if (!isStrongTrigger && Math.random() > this._transitionProbability) {
      return null;
    }

    for (const c of candidates) {
      roll -= c.weight;
      if (roll <= 0) {
        this._lastTransitionTurn = gameState.turn;
        return c.text;
      }
    }

    return null;
  }

  /**
   * 设置待显示的过渡文字（由 game.js 在 getCurrentCard 前调用）
   */
  setPendingTransition(text) {
    this._pendingTransition = text;
  }

  /** 取出并清除待显示的过渡文字 */
  consumePendingTransition() {
    const t = this._pendingTransition;
    this._pendingTransition = null;
    return t;
  }

  // ═══════════════════════════════════════════════
  //  C. Cross-Reference Weaver — 动态描述增强
  // ═══════════════════════════════════════════════

  /**
   * 根据世界状态动态增强卡牌描述
   * @returns {string} 增强后的描述
   */
  enhanceDescription(card, gameState, threadEngine, questSystem) {
    let desc = card.description || card.desc || '';

    // 只增强有叙事标识的卡（线程卡/支线卡/NPC卡/因果卡/战斗卡/世界卡）
    const hasThreadContext = card._threadId || (card.threadTags && card.threadTags.length > 0);
    const isQuestCard = card.type === 'QUEST' || card.questId;
    const isNpcCard = card.npcId || card.compId;
    const isKarmaCard = card.type === 'KARMA' || (card.tags && card.tags.includes('karma'));
    const isCombatCard = card.type === 'COMBAT' || (card.tags && card.tags.includes('combat'));
    const isWorldCard = card.type === 'SPECIAL' && card.realm === 'interweave';

    if (!hasThreadContext && !isQuestCard && !isNpcCard && !isKarmaCard && !isCombatCard && !isWorldCard) return desc;

    const bonuses = [];

    // 线程卡 × 已完成支线
    if (card._threadId && questSystem) {
      const completed = questSystem.getAllCompletedQuests
        ? questSystem.getAllCompletedQuests() : [];
      for (const qid of completed) {
        const key = `${card._threadId}×${qid}`;
        if (this.threadQuestRefs[key]) {
          bonuses.push({ text: this.threadQuestRefs[key], weight: 5 });
        }
      }
      // 活跃支线交叉引用（权重较低）
      if (questSystem.activeQuests) {
        for (const aq of questSystem.activeQuests) {
          const key = `${card._threadId}×${aq.questId}`;
          if (this.threadQuestRefs[key]) {
            bonuses.push({ text: this.threadQuestRefs[key], weight: 3 });
          }
        }
      }
    }

    // 支线卡 × 已完成线程
    if (isQuestCard && threadEngine) {
      const qid = card.questId || card.id || '';
      const completed = threadEngine.completedThreads instanceof Set
        ? threadEngine.completedThreads : new Set();
      for (const tid of completed) {
        const key = `${qid}×${tid}`;
        if (this.threadQuestRefs[key]) {
          bonuses.push({ text: this.threadQuestRefs[key], weight: 5 });
        }
      }
    }

    // NPC卡 × 线程/支线（如果有相关交叉引用）
    if (isNpcCard && threadEngine) {
      const npcId = card.npcId || card.compId;
      if (questSystem) {
        const completed = questSystem.getAllCompletedQuests
          ? questSystem.getAllCompletedQuests() : [];
        for (const qid of completed) {
          const key = `${npcId}×${qid}`;
          if (this.threadQuestRefs[key]) {
            bonuses.push({ text: this.threadQuestRefs[key], weight: 4 });
          }
        }
      }
    }

    if (bonuses.length === 0) return desc;

    // 最多添加1条增强文字
    const totalWeight = bonuses.reduce((s, b) => s + b.weight, 0);
    let roll = Math.random() * totalWeight;
    for (const b of bonuses) {
      roll -= b.weight;
      if (roll <= 0) {
        return desc + ' ' + b.text;
      }
    }

    return desc;
  }

  // ═══════════════════════════════════════════════
  //  内部辅助方法
  // ═══════════════════════════════════════════════

  _pickTemplate(key, vars = {}) {
    const templates = this.transitionTemplates[key];
    if (!templates || templates.length === 0) return '';
    let text = templates[Math.floor(Math.random() * templates.length)];
    for (const [k, v] of Object.entries(vars)) {
      text = text.replace(`{${k}}`, v || '');
    }
    return text;
  }

  _getThreadInfo(threadEngine, threadId) {
    if (!threadEngine) return null;
    // activeThreads 是 Map<threadId, ThreadState>
    const at = threadEngine.activeThreads;
    if (at instanceof Map && at.has(threadId)) return at.get(threadId);
    if (at && typeof at === 'object' && at[threadId]) return at[threadId];
    return null;
  }

  _getQuestTitle(questSystem, questId) {
    if (!questSystem || !questSystem.quests) return questId;
    const quest = questSystem.quests instanceof Map
      ? questSystem.quests.get(questId) : questSystem.quests[questId];
    return (quest && (quest.name || quest.title || quest.questTitle)) || questId;
  }

  _getRecentFlags(gameState) {
    if (!gameState.flags) return [];
    return Object.entries(gameState.flags)
      .filter(([, v]) => v === true)
      .slice(0, 3)
      .map(([k]) => k);
  }

  /** worldFlags → 叙事化中文名 */
  _flagToNarrative(flagKey) {
    const map = {
      // v2.0 基础世界标识
      bandit_defeated_village: '荒村妖道被诛杀',
      mine_distributed: '矿脉重新分配',
      sword_claimed: '古剑认主',
      herb_valley_resolved: '药王谷叛逃事件',
      cave_discovered: '前人洞府被发掘',
      white_fox_completed: '白狐报恩',
      tianshu_completed: '天书残卷集齐',
      body_trial_completed: '炼体劫渡过',
      sword_legacy_completed: '剑道传承获得',
      spell_codex_completed: '法术法典修习',
      pill_master_completed: '丹道大师认可',
      // v2.1 扩展标识映射 — 正魔线/交织/势力/转世
      demon_contacted: '第一次接触魔道',
      demon_accepted: '接受了魔道之力',
      demon_rejected: '拒绝了魔道诱惑',
      sect_hunt_order: '师门下达了追杀令',
      companion_bonded: '与道侣缔结了羁绊',
      companion_sacrificed: '道侣为你做出了牺牲',
      master_passed_torch: '师尊传承了衣钵',
      ally_sworn: '与盟友立下了誓约',
      faction_uprising: '势力暗流涌动',
      rebirth_memory: '前世记忆开始浮现',
      tribulation_survived: '天劫余波未平',
    };
    return map[flagKey] || flagKey;
  }

  // ═══════════════════════════════════════════════
  //  初始化 / 重置
  // ═══════════════════════════════════════════════

  init() {
    this._lastTransitionTurn = -1;
    this._lastNarratedTurn = -1;
    this._lastEffects = null;
    this._pendingTransition = null;
  }

  reset() {
    this.init();
  }
}

// 全局可用
if (typeof module !== 'undefined' && module.exports) {
  module.exports = NarrativeCoherenceLayer;
}
