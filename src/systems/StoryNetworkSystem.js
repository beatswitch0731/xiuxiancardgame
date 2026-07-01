/**
 * StoryNetworkSystem - 剧情网系统（v1.0）
 *
 * 叙事元系统：悬在所有子系统之上的编排层。
 * 不产生新内容，而是确保已有内容在正确的时间、正确的条件、正确的情感状态下出现。
 *
 * 四大职责：
 *   1. 叙事状态追踪（WorldNarrativeState） — 记录发生过什么、谁活着、什么改变了
 *   2. 世界观一致性引擎（CoherenceEngine） — 阻止矛盾事件（死人出现/不合理的因果对撞）
 *   3. 涌现叙事生成（EmergentNarrative） — 系统阈值跨越 × 全局状态查询 → 触发叙事
 *   4. 叙事浮现层（NarrativeSurfacing） — 让玩家"看到"因果，"感到"世界在变
 *
 * 道侣沉浸体系（CompanionArcEngine）：
 *   每个道侣拥有一条完整的故事弧（起承转合），弧线阶段由好感/羁绊/玩家抉择驱动。
 *   弧线节点与世界主线交织——正魔抉择、天劫、飞升都会成为弧线的转折点。
 *   道侣的秘密在弧线关键节点揭示，而非数据面板中的静态文字。
 *
 * 架构原则：
 *   - 读取所有系统，写入 CardSystem（通过事件卡注入）
 *   - 不做内容生产——内容在卡牌JSON中，本系统只做"什么时候出哪张卡"的决策
 *   - 所有决策基于系统化规则，而非硬编码if-else
 */
class StoryNetworkSystem {
  constructor() {
    /** @type {WorldNarrativeState} 全局叙事状态 */
    this.worldState = new WorldNarrativeState();

    /** @type {CoherenceEngine} 一致性引擎 */
    this.coherence = new CoherenceEngine(this.worldState);

    /** @type {EmergentNarrativeEngine} 涌现叙事引擎 */
    this.emergent = new EmergentNarrativeEngine(this.worldState, this.coherence);

    /** @type {CompanionArcEngine} 道侣弧线引擎（仅女性道侣） */
    this.companionArcs = new CompanionArcEngine(this.worldState);

    /** @type {MentorArcEngine} 师尊弧线引擎 */
    this.mentorArcs = new MentorArcEngine(this.worldState);

    /** @type {SeerArcEngine} 先知弧线引擎 */
    this.seerArcs = new SeerArcEngine(this.worldState);

    /** @type {AllyArcEngine} 盟友弧线引擎 */
    this.allyArcs = new AllyArcEngine(this.worldState);

    /** @type {NarrativeSurfacing} 叙事浮现层 */
    this.surfacing = new NarrativeSurfacing(this.worldState);

    /** @type {Object} 配置 */
    this.config = {
      companionEventProbBase: 0.12,    // 道侣弧线事件基础概率
      mentorEventProbBase: 0.10,       // 师尊弧线事件基础概率
      seerEventProbBase: 0.08,         // 先知弧线事件基础概率
      allyEventProbBase: 0.10,         // 盟友弧线事件基础概率
      emergentEventProbBase: 0.08,     // 涌现事件基础概率
      surfacingFrequency: 5,           // 每N轮做一次叙事浮现检查
      maxPendingNarrativeEvents: 3     // 最多排队叙事事件
    };
  }

  /**
   * 加载所有关系弧线数据（从 arcs.json）
   */
  loadArcs(data) {
    if (!data) return;
    if (data.companionArcs) this.companionArcs.loadArcs(data.companionArcs);
    if (data.mentorArc) this.mentorArcs.loadArcs(data.mentorArc);
    if (data.seerArc) this.seerArcs.loadArcs(data.seerArc);
    if (data.allyArc) this.allyArcs.loadArcs(data.allyArc);
  }

  /**
   * 获取所有关系加成（道侣+师尊+先知+盟友）
   */
  getAllActiveBonuses() {
    return {
      ...this.companionArcs.getAllActiveBonuses(),
      ...this.mentorArcs.getAllActiveBonuses(),
      ...this.seerArcs.getAllActiveBonuses(),
      ...this.allyArcs.getAllActiveBonuses()
    };
  }

  /**
   * 获取指定NPC的关系加成
   */
  getBonusesForNpc(npcId) {
    return this.companionArcs.getCompanionBonuses(npcId)
      || this.mentorArcs.getMentorBonuses(npcId)
      || this.seerArcs.getSeerBonuses(npcId)
      || this.allyArcs.getAllyBonuses(npcId);
  }

  /**
   * 初始化：挂载所有事件监听
   */
  init() {
    // 卡牌选择 → 记录叙事状态
    eventBus.on('card:chosen', (data) => this._onCardChosen(data));

    // 属性变化 → 检查涌现阈值
    eventBus.on('state:attributeChanged', (data) => this._onAttributeChanged(data));

    // NPC好感变化 → 分流到道侣/师尊/先知/盟友各自的弧线引擎
    eventBus.on('npc:affectionChange', (data) => this._onAffectionChanged(data));
    eventBus.on('companion:stateChanged', (data) => this._onCompanionStateChanged(data));

    // 师尊关系变化（师徒传承值变化）
    eventBus.on('mentor:progressionChange', (data) => this._onMentorProgressionChanged(data));

    // 先知揭示度变化
    eventBus.on('seer:revelationChange', (data) => this._onSeerRevelationChanged(data));

    // 盟友同盟度变化
    eventBus.on('ally:alignmentChange', (data) => this._onAllyAlignmentChanged(data));

    // 境界突破 → 弧线转折点
    eventBus.on('state:realmChanged', (data) => this._onRealmChanged(data));

    // 死亡 → 世界观一致性更新
    eventBus.on('state:death', (data) => this._onDeath(data));

    // NPC死亡 → 清除相关叙事
    eventBus.on('npc:died', (data) => this._onNpcDied(data));

    // 势力声望变化
    eventBus.on('faction:repChanged', (data) => this._onFactionRepChanged(data));

    // CardSystem调度时调用 → 检查是否有该出的叙事卡
    eventBus.on('storynetwork:checkNarrative', () => this._onCheckNarrative());

    // 道侣弧线事件 → 注入卡牌
    eventBus.on('companion:arc:eventCard', (data) => this._onArcEventCard(data));

    // 师尊/先知/盟友弧线事件
    eventBus.on('mentor:arc:eventCard', (data) => this._onArcEventCard(data));
    eventBus.on('seer:arc:eventCard', (data) => this._onArcEventCard(data));
    eventBus.on('ally:arc:eventCard', (data) => this._onArcEventCard(data));

    // ==========================================
    // 游戏行为 → 关系值推进（挂接）
    // 将已有的游戏机制映射到四类关系系统的数值推进上
    // ==========================================

    // --- 修炼提升 → 师尊传承值（白刃真人） ---
    eventBus.on('state:attributeChanged', (data) => {
      if (data.attribute === 'cultivation' && data.newValue > data.oldValue) {
        const delta = Math.max(1, Math.ceil((data.newValue - data.oldValue) * 0.3));
        this.mentorArcs.addProgression('bai_ren', delta);
      }
    });

    // --- 道心提升 → 天机揭示度（天机老人） ---
    eventBus.on('state:attributeChanged', (data) => {
      if (data.attribute === 'daoHeart' && data.newValue > data.oldValue) {
        const delta = Math.max(1, Math.ceil((data.newValue - data.oldValue) * 0.2));
        this.seerArcs.addRevelation('tian_ji', delta);
      }
    });

    // --- 恶业增加 → 血煞同盟度 ---
    eventBus.on('state:attributeChanged', (data) => {
      if (data.attribute === 'karmaBad' && data.newValue > data.oldValue) {
        const delta = Math.max(1, Math.ceil((data.newValue - data.oldValue) * 0.5));
        this.allyArcs.addAlignment('xue_sha', delta);
      }
    });

    // --- 卡牌标签驱动关系推进 ---
    eventBus.on('card:chosen', (data) => {
      const card = data.card;
      if (!card || !card.tags) return;

      const tags = Array.isArray(card.tags) ? card.tags : [card.tags];

      // 剑道/师徒/试炼类卡牌 → 师尊传承值
      if (tags.some(t => ['mentor', 'sword_way', 'disciple', 'trial', 'legacy'].includes(t))) {
        this.mentorArcs.addProgression('bai_ren', 3);
      }

      // 秘密/预言/古史类卡牌 → 天机揭示度
      if (tags.some(t => ['secret', 'prophecy', 'lore', 'hidden', 'truth'].includes(t))) {
        this.seerArcs.addRevelation('tian_ji', 3);
      }

      // 魔道/血煞/战斗类卡牌 → 血煞同盟度
      if (tags.some(t => ['demonic', 'blood', 'war', 'battle', 'slaughter'].includes(t))) {
        this.allyArcs.addAlignment('xue_sha', 3);
      }
    });

    // --- 境界突破 → 所有关系值大幅推进 ---
    eventBus.on('state:realmChanged', (data) => {
      const realmBonus = { foundation: 8, golden: 12, nascent: 15, deity: 20, tribulation: 25 };
      const bonus = realmBonus[data.to] || 5;

      this.mentorArcs.addProgression('bai_ren', bonus);
      this.seerArcs.addRevelation('tian_ji', Math.ceil(bonus * 0.8));
      // 血煞老祖更关注后期境界 —— 前期给得少，后期给得多
      if (['nascent', 'deity', 'tribulation'].includes(data.to)) {
        this.allyArcs.addAlignment('xue_sha', Math.ceil(bonus * 1.2));
      }
    });

    // --- 战斗胜利 → 血煞同盟度（魔道老祖认可实力） ---
    eventBus.on('combat:victory', () => {
      this.allyArcs.addAlignment('xue_sha', 4);
    });
  }

  // ==========================================
  // 事件处理
  // ==========================================

  _onCardChosen(data) {
    const { card, choice, effects } = data;

    // 记录叙事事件
    this.worldState.recordEvent({
      type: 'card_choice',
      cardId: card.id,
      choice,
      turn: gameState.turn,
      realm: gameState.realm,
      path: gameState.path
    });

    // 检查是否触发隐含叙事阈值
    this.emergent.checkThresholds();
  }

  _onAttributeChanged(data) {
    this.emergent.checkAttributeThresholds(data);
  }

  _onAffectionChanged(data) {
    const { npcId, delta, newValue } = data;

    this.worldState.recordEvent({
      type: 'affection_change',
      npcId,
      delta,
      newValue,
      turn: gameState.turn
    });

    // 好感阈值对道侣弧线的影响
    this.companionArcs.onAffectionChanged(npcId, newValue, delta);
  }

  _onCompanionStateChanged(data) {
    const { compId, affection, bond, trust } = data;

    // 检查弧线阶段推进
    this.companionArcs.checkArcProgression(compId, { affection, bond, trust });
  }

  _onMentorProgressionChanged(data) {
    const { npcId, newValue } = data;
    this.mentorArcs.onProgressionChanged(npcId, newValue);
  }

  _onSeerRevelationChanged(data) {
    const { npcId, newValue } = data;
    this.seerArcs.onRevelationChanged(npcId, newValue);
  }

  _onAllyAlignmentChanged(data) {
    const { npcId, newValue } = data;
    this.allyArcs.onAlignmentChanged(npcId, newValue);
  }

  _onRealmChanged(data) {
    const { from, to } = data;

    this.worldState.recordEvent({
      type: 'realm_change',
      from, to,
      turn: gameState.turn
    });

    // 境界突破是所有关系弧线的关键转折点
    this.companionArcs.onRealmChanged(to);
    this.mentorArcs.onRealmChanged(to);
    this.seerArcs.onRealmChanged(to);
    this.allyArcs.onRealmChanged(to);

    // 检查涌现叙事
    this.emergent.checkRealmThreshold(to);
  }

  _onDeath(data) {
    this.worldState.recordEvent({
      type: 'player_death',
      reason: data.reason,
      turn: gameState.turn,
      lifeCount: gameState.getLifeCount ? gameState.getLifeCount() : 0
    });

    // 死亡时保存未完成的道侣弧线状态到转世记忆
    this.companionArcs.preserveForReincarnation();
  }

  _onNpcDied(data) {
    // 标记NPC已死亡 → 一致性引擎将过滤相关事件
    this.worldState.markNpcDead(data.npcId, gameState.turn);
  }

  _onFactionRepChanged(data) {
    this.worldState.recordEvent({
      type: 'faction_rep_change',
      factionId: data.factionId,
      delta: data.delta,
      newValue: data.newValue,
      turn: gameState.turn
    });
  }

  // ==========================================
  // 叙事事件调度（由CardSystem在每轮触发）
  // ==========================================

  _onCheckNarrative() {
    // 优先级0：道侣弧线高潮事件（优先级最高——情感最密集）
    const arcClimax = this.companionArcs.getPendingClimax();
    if (arcClimax) {
      eventBus.emit('storynetwork:narrativeCard', {
        card: arcClimax,
        priority: 53,
        source: 'companion_arc_climax'
      });
      return;
    }

    // 优先级1：师尊弧线高潮事件（传承/真相揭示）
    const mentorClimax = this.mentorArcs.getPendingClimax();
    if (mentorClimax) {
      eventBus.emit('storynetwork:narrativeCard', {
        card: mentorClimax,
        priority: 52,
        source: 'mentor_arc_climax'
      });
      return;
    }

    // 优先级2：道侣弧线推进事件
    const arcEvent = this.companionArcs.getPendingArcEvent();
    if (arcEvent) {
      eventBus.emit('storynetwork:narrativeCard', {
        card: arcEvent,
        priority: 51,
        source: 'companion_arc_progression'
      });
      return;
    }

    // 优先级3：盟友弧线高潮事件（对天道/仙庭的决战）
    const allyClimax = this.allyArcs.getPendingClimax();
    if (allyClimax) {
      eventBus.emit('storynetwork:narrativeCard', {
        card: allyClimax,
        priority: 49,
        source: 'ally_arc_climax'
      });
      return;
    }

    // 优先级4：师尊弧线推进事件
    const mentorEvent = this.mentorArcs.getPendingArcEvent();
    if (mentorEvent) {
      eventBus.emit('storynetwork:narrativeCard', {
        card: mentorEvent,
        priority: 48,
        source: 'mentor_arc_progression'
      });
      return;
    }

    // 优先级5：涌现叙事事件
    const emergent = this.emergent.getPendingEmergentEvent();
    if (emergent) {
      eventBus.emit('storynetwork:narrativeCard', {
        card: emergent,
        priority: 45,
        source: 'emergent_narrative'
      });
      return;
    }

    // 优先级6：先知弧线高潮事件（终极预言）
    const seerClimax = this.seerArcs.getPendingClimax();
    if (seerClimax) {
      eventBus.emit('storynetwork:narrativeCard', {
        card: seerClimax,
        priority: 44,
        source: 'seer_arc_climax'
      });
      return;
    }

    // 优先级7：盟友弧线推进事件
    const allyEvent = this.allyArcs.getPendingArcEvent();
    if (allyEvent) {
      eventBus.emit('storynetwork:narrativeCard', {
        card: allyEvent,
        priority: 42,
        source: 'ally_arc_progression'
      });
      return;
    }

    // 优先级8：先知弧线推进事件
    const seerEvent = this.seerArcs.getPendingArcEvent();
    if (seerEvent) {
      eventBus.emit('storynetwork:narrativeCard', {
        card: seerEvent,
        priority: 39,
        source: 'seer_arc_progression'
      });
      return;
    }

    // 优先级9：选择延迟回响事件（"世界记住了你"）
    if (typeof choiceEchoEngine !== 'undefined' && choiceEchoEngine) {
      const echoCard = choiceEchoEngine.checkAndGenerate();
      if (echoCard) {
        eventBus.emit('storynetwork:narrativeCard', {
          card: echoCard,
          priority: 36,
          source: 'choice_echo'
        });
        return;
      }
    }

    // 每N轮做一次叙事浮现检查
    if (gameState.turn % this.config.surfacingFrequency === 0) {
      const surfacing = this.surfacing.check();
      if (surfacing) {
        eventBus.emit('storynetwork:narrativeCard', {
          card: surfacing,
          priority: 35,
          source: 'narrative_surfacing'
        });
        return;
      }
    }

    // 优先级10：场景/位置卡（慢节奏叙事，不抢戏剧冲突）
    if (typeof sceneLayerSystem !== 'undefined' && sceneLayerSystem && gameState.currentLocation) {
      const sceneCard = sceneLayerSystem.getLocationCard(gameState.currentLocation, false);
      if (sceneCard) {
        eventBus.emit('storynetwork:narrativeCard', {
          card: sceneCard,
          priority: 28,
          source: 'location_scene'
        });
        return;
      }
    }

    eventBus.emit('storynetwork:narrativeCard', { card: null, priority: 0 });
  }

  _onArcEventCard(data) {
    eventBus.emit('storynetwork:narrativeCard', {
      card: data.card,
      priority: data.priority || 51,
      source: 'companion_arc'
    });
  }
}

// ==========================================
// WorldNarrativeState — 全局叙事状态
// ==========================================

class WorldNarrativeState {
  constructor() {
    /** @type {Object[]} 叙事事件日志 */
    this.eventLog = [];

    /** @type {Set<string>} 已死亡的NPC */
    this.deadNpcs = new Set();

    /** @type {Map<string, number>} NPC死亡轮 */
    this.deathTurn = new Map();

    /** @type {Map<string, Object>} NPC当前弧线状态 */
    this.companionArcStates = new Map();

    /** @type {Map<string, number>} 势力声望快照 */
    this.factionRepSnapshots = new Map();

    /** @type {Object} 世界级叙事标签 */
    this.worldTags = {
      demonPathChosen: false,         // 是否选择了魔道
      orthodoxPathChosen: false,     // 是否坚持正道
      heavenEngineDiscovered: false, // 是否发现了天道引擎真相
      firstTribulationPassed: false, // 是否渡过第一次天劫
      yinxueAlive: false,            // 殷血是否活着
      bairenAlive: true,             // 白刃真人是否活着
      soulmateFound: false           // 是否找到了天命道侣
    };

    /** @type {number} 叙事深度分数（0-100），越高越复杂 */
    this.narrativeDepth = 0;
  }

  recordEvent(event) {
    this.eventLog.push({ ...event, timestamp: Date.now() });
    // 保持日志在合理大小
    if (this.eventLog.length > 200) {
      this.eventLog = this.eventLog.slice(-100);
    }

    // 自动计算叙事深度
    this._recalculateDepth();
  }

  markNpcDead(npcId, turn) {
    this.deadNpcs.add(npcId);
    this.deathTurn.set(npcId, turn);
  }

  isNpcAlive(npcId) {
    return !this.deadNpcs.has(npcId);
  }

  setWorldTag(tag, value) {
    this.worldTags[tag] = value;
  }

  getWorldTag(tag) {
    return this.worldTags[tag] || false;
  }

  /**
   * 查询：世界状态是否满足某条件组合
   * @param {Object} conditions - { tags: [], npcsAlive: [], minDepth: N, ... }
   * @returns {boolean}
   */
  checkConditions(conditions) {
    if (!conditions) return true;

    if (conditions.tags) {
      for (const tag of conditions.tags) {
        if (!this.worldTags[tag]) return false;
      }
    }

    if (conditions.npcsAlive) {
      for (const npcId of conditions.npcsAlive) {
        if (!this.isNpcAlive(npcId)) return false;
      }
    }

    if (conditions.npcsDead) {
      for (const npcId of conditions.npcsDead) {
        if (this.isNpcAlive(npcId)) return false;
      }
    }

    if (conditions.minDepth && this.narrativeDepth < conditions.minDepth) return false;
    if (conditions.maxDepth && this.narrativeDepth > conditions.maxDepth) return false;

    if (conditions.minLifeCount) {
      const lifeCount = gameState.getLifeCount ? gameState.getLifeCount() : 0;
      if (lifeCount < conditions.minLifeCount) return false;
    }

    return true;
  }

  _recalculateDepth() {
    let depth = 0;
    const recentEvents = this.eventLog.slice(-50);

    // 独特卡牌选择次数
    const uniqueCards = new Set(recentEvents.filter(e => e.type === 'card_choice').map(e => e.cardId));
    depth += uniqueCards.size;

    // 重要事件加权
    const majorEvents = recentEvents.filter(e =>
      e.type === 'realm_change' || e.type === 'player_death' ||
      e.type === 'faction_rep_change'
    );
    depth += majorEvents.length * 3;

    // 世界标签加权
    const activeTags = Object.values(this.worldTags).filter(v => v === true).length;
    depth += activeTags * 5;

    this.narrativeDepth = Math.min(100, depth);
  }
}

// ==========================================
// CoherenceEngine — 世界观一致性引擎
// ==========================================

class CoherenceEngine {
  constructor(worldState) {
    this.worldState = worldState;
  }

  /**
   * 检查事件是否可以触发
   * @param {Object} event - 要触发的叙事事件
   * @returns {{ valid: boolean, reason?: string }}
   */
  validate(event) {
    // 1. NPC存活检查
    if (event.npcIds) {
      for (const npcId of event.npcIds) {
        if (!this.worldState.isNpcAlive(npcId)) {
          return { valid: false, reason: `NPC ${npcId}已死亡` };
        }
      }
    }

    // 2. 世界条件检查
    if (event.conditions) {
      if (!this.worldState.checkConditions(event.conditions)) {
        return { valid: false, reason: '世界条件不满足' };
      }
    }

    // 3. 时序合理性检查
    if (event.minTurn && gameState.turn < event.minTurn) {
      return { valid: false, reason: `需在第${event.minTurn}轮后触发` };
    }

    // 4. 情感合理性检查
    // 刚发生重大负面事件后的N轮内，不触发过于欢快的事件
    if (event.tone === 'warm' || event.tone === 'joyful') {
      const recentDeaths = this.worldState.eventLog.slice(-5).filter(
        e => e.type === 'player_death' || e.type === 'npc_died'
      );
      if (recentDeaths.length > 0) {
        return { valid: false, reason: '近期有死亡事件，不适合触发欢快事件' };
      }
    }

    return { valid: true };
  }

  /**
   * 筛选：从候选事件中移除不合理的
   */
  filter(events) {
    return events.filter(e => this.validate(e).valid);
  }
}

// ==========================================
// EmergentNarrativeEngine — 涌现叙事引擎
// ==========================================

class EmergentNarrativeEngine {
  constructor(worldState, coherence) {
    this.worldState = worldState;
    this.coherence = coherence;
    this._pendingEmergent = null;
  }

  /**
   * 涌现叙事阈值集
   * 系统状态 × 阈值 → 叙事事件
   */
  static THRESHOLDS = [
    // 道魔双修涌现
    {
      id: 'dual_path_emergence',
      check: () => {
        const karmaGood = gameState.attributes.karmaGood || 0;
        const karmaBad = gameState.attributes.karmaBad || 0;
        return karmaGood > 40 && karmaBad > 40;
      },
      cardId: 'em_dual_path',
      desc: '善因恶因同时达到高位 → 道魔双修之兆'
    },
    // 孤家寡人涌现
    {
      id: 'loner_emergence',
      check: () => {
        const companions = gameState.resources.companions || [];
        return companions.length === 0 && gameState.turn > 30;
      },
      cardId: 'em_loner',
      desc: '长时间无道侣 → 孤独修行者的内心独白'
    },
    // 因果交织涌现
    {
      id: 'karma_density_emergence',
      check: () => {
        const seeds = gameState.karmaSeeds || [];
        return seeds.length >= 5;
      },
      cardId: 'em_karma_density',
      desc: '因果池中种子≥5 → 因果交织的预感'
    },
    // 宿敌涌现
    {
      id: 'nemesis_emergence',
      check: () => {
        const lifeCount = gameState.getLifeCount ? gameState.getLifeCount() : 0;
        return lifeCount >= 2 && gameState.turn > 20;
      },
      cardId: 'em_nemesis',
      desc: '转世≥2且游戏深入 → 宿敌察觉你的存在'
    },
    // 道心危机涌现
    {
      id: 'dao_heart_crisis',
      check: () => {
        const dh = gameState.attributes.daoHeart || 100;
        return dh < 30 && gameState.realm !== 'qi';
      },
      cardId: 'em_dao_crisis',
      desc: '道心低于30 → 道心碎裂的危机'
    },
    // 天道注视涌现
    {
      id: 'heaven_gaze',
      check: () => {
        const fortune = gameState.attributes.fortune || 50;
        const cultivation = gameState.attributes.cultivation || 0;
        return fortune > 80 && cultivation > 80;
      },
      cardId: 'em_heaven_gaze',
      desc: '福缘和修为同时高位 → 天道注意到了你'
    }
  ];

  checkThresholds() {
    for (const threshold of EmergentNarrativeEngine.THRESHOLDS) {
      if (threshold.check()) {
        const cardId = threshold.cardId;
        // 构建涌现事件卡
        const eventCard = this._buildEmergentCard(threshold);
        if (eventCard && this.coherence.validate({ npcIds: [], conditions: null, tone: 'neutral' }).valid) {
          this._pendingEmergent = eventCard;
          return;
        }
      }
    }
  }

  checkAttributeThresholds(data) {
    // 属性变化时不立即触发，只标记检查
    this.checkThresholds();
  }

  checkRealmThreshold(to) {
    // 境界突破是重要的涌现点
    this.checkThresholds();
  }

  getPendingEmergentEvent() {
    const event = this._pendingEmergent;
    this._pendingEmergent = null;
    return event;
  }

  _buildEmergentCard(threshold) {
    const cardTemplates = {
      em_dual_path: {
        id: 'em_dual_path',
        title: '双脉齐震',
        description: '你感到丹田中两股力量在同时震动——善因化作暖流，恶因化作寒潮。它们在经脉中对撞，但你没有死——它们在融合。你的左眼映着金光，右眼浮着血影。道与魔，在你的体内达成了某种脆弱的平衡。',
        type: 'EMERGENT',
        realm: gameState.realm,
        tags: ['emergent', 'dual_path', 'mystical'],
        choices: {
          left: { text: '主动调和——寻找平衡之道', effects: { daoHeart: 15, cultivation: 10, karmaGood: 5, karmaBad: 5 } },
          right: { text: '压制其中一种——选一条路', effects: { daoHeart: 10, karmaGood: 15 } }
        }
      },
      em_loner: {
        id: 'em_loner',
        title: '孤峰之上',
        description: '你站在峰顶，看着山下坊市的灯火。别人的热闹是别人的——你的道，只有你自己走。但今晚的风特别冷——不是天气，是你心里的温度。你忽然想起一个人——也许不是道侣，只是一个能听懂剑气低吟的人。',
        type: 'EMERGENT',
        realm: gameState.realm,
        tags: ['emergent', 'loner', 'reflective'],
        choices: {
          left: { text: '下山走走——去坊市看看', effects: { fortune: 10, daoHeart: 5, cultivation: -3 },
            karmaSeed: { id: 'lonerGoesDown', seedType: 'karma', delay: 5, priority: 2 } },
          right: { text: '继续修炼——孤独是修行的代价', effects: { cultivation: 15, daoHeart: 5 } }
        }
      },
      em_karma_density: {
        id: 'em_karma_density',
        title: '因果之网',
        description: '你忽然感到胸口一阵闷——不是受伤，是因果。你种下的种子太多了——善的、恶的、不解的、未了的——它们在你四周织成了一张看不见的网。你每走一步都在牵动网线，每一条线的尽头都是一张你没有兑现的脸。',
        type: 'EMERGENT',
        realm: gameState.realm,
        tags: ['emergent', 'karma', 'mystical'],
        choices: {
          left: { text: '梳理因果——明确每一份欠与还', effects: { daoHeart: 20, karmaGood: 10, fortune: 5 } },
          right: { text: '无视——因果自会清算', effects: { daoHeart: -5, karmaBad: 10, fortune: -5 } }
        }
      },
      em_nemesis: {
        id: 'em_nemesis',
        title: '宿敌的觉醒',
        description: '远方——很远很远的某个洞府里——一个人忽然睁开了眼睛。你不知道ta是谁，但你知道ta醒了。一种跨越轮回的敌意穿过云层、穿过因果、穿过你的护体灵气——刺进了你的识海。你的宿敌，这一世，也开始了修行。',
        type: 'EMERGENT',
        realm: gameState.realm,
        tags: ['emergent', 'nemesis', 'tension'],
        requirements: { minLifeCount: 2 },
        choices: {
          left: { text: '准备——这一世我不会输', effects: { cultivation: 15, daoHeart: 15, health: 5 } },
          right: { text: '不理会——前世的账不该今生算', effects: { daoHeart: 10, karmaGood: 10 } }
        }
      },
      em_dao_crisis: {
        id: 'em_dao_crisis',
        title: '道心裂隙',
        description: '你坐在蒲团上——但你感觉不到蒲团。你的灵识在飘散，道心像一块被敲碎的玉石——裂缝在蔓延。一切你曾经坚信的东西都变得不确定。什么是道？什么是魔？你是谁？\\n\\n你想起了某个人的脸——不是师父，不是道侣——是你自己。第一世的你。他在裂缝的另一端看着你，什么都没说。',
        type: 'EMERGENT',
        realm: gameState.realm,
        tags: ['emergent', 'crisis', 'dao_heart', 'introspective'],
        choices: {
          left: { text: '接受裂隙——破碎之后才是真正的道', effects: { daoHeart: 30, cultivation: 10, health: -15 } },
          right: { text: '修补裂隙——回到从前', effects: { daoHeart: 10, cultivation: 5, health: 5 } }
        }
      },
      em_heaven_gaze: {
        id: 'em_heaven_gaze',
        title: '天道注视',
        description: '你感到有人在看你——不是任何人，是天道本身。这种感觉非常明确：你不再是芸芸众生中的一粒沙——你变成了天道算法里的一个异常值。它注意到了你的修为增速、你的福缘厚度、你的转世次数。它在权衡：留着你还是收割你。',
        type: 'EMERGENT',
        realm: gameState.realm,
        tags: ['emergent', 'heaven', 'tension', 'mystical'],
        choices: {
          left: { text: '收敛——暂时蛰伏', effects: { cultivation: -5, fortune: 15, daoHeart: 5 } },
          right: { text: '挑衅——让天道来找我', effects: { cultivation: 15, daoHeart: 10, fortune: -20, karmaBad: 10 } }
        }
      }
    };

    return cardTemplates[threshold.cardId] || null;
  }
}

// ==========================================
// CompanionArcEngine — 道侣故事弧线引擎
// ==========================================

class CompanionArcEngine {
  constructor(worldState) {
    this.worldState = worldState;

    /**
     * 个性化弧线数据（从 arcs.json 加载）
     * { compId: { arcStages, secretReveal, tribulationClimax, destinyClimax, bonuses, ... } }
     */
    this.arcData = {};

    /**
     * 道侣弧线阶段定义
     * 每个阶段有进入条件、持续事件池、退出条件
     */
    this.ARC_STAGES = {
      // 阶段0：未结缘
      NOT_BOUND: { index: 0, name: '陌路', threshold: { affection: 0 } },
      // 阶段1：初识——刚刚成为道侣
      ACQUAINTANCE: { index: 1, name: '初识', threshold: { affection: 20 },
        events: ['arc_first_night', 'arc_shy_gift', 'arc_awkward_silence'] },
      // 阶段2：相知——了解彼此的故事
      KNOWING: { index: 2, name: '相知', threshold: { affection: 40 },
        events: ['arc_share_past', 'arc_trust_test', 'arc_night_talk'] },
      // 阶段3：深交——进入彼此的内心世界
      DEEP_BOND: { index: 3, name: '深交', threshold: { affection: 60, bond: 2 },
        events: ['arc_secret_reveal', 'arc_life_death', 'arc_jealousy'] },
      // 阶段4：至交——可以为对方赴死
      SOUL_BOND: { index: 4, name: '至交', threshold: { affection: 80, bond: 3 },
        events: ['arc_tribulation_together', 'arc_master_approval', 'arc_ultimate_choice'] },
      // 阶段5：天命——刻入轮回的羁绊
      DESTINY: { index: 5, name: '天命', threshold: { affection: 95, bond: 4 },
        events: ['arc_destiny_vow', 'arc_reincarnation_promise', 'arc_heaven_witness'] }
    };

    /** @type {Map<string, Object>} compId → arcState */
    this.arcStates = new Map();

    /** @type {Object|null} 待触发的高潮事件 */
    this._pendingClimax = null;

    /** @type {Object|null} 待触发的弧线事件 */
    this._pendingArcEvent = null;
  }

  /**
   * 加载个性化弧线数据（从 arcs.json companionArcs 部分）
   */
  loadArcs(data) {
    if (!data) return;
    this.arcData = data;
  }

  /**
   * 获取道侣加成
   * @param {string} compId
   * @returns {Object|null} { id, name, icon, effects, desc, passiveDesc }
   */
  getCompanionBonuses(compId) {
    const arc = this.arcData[compId];
    if (!arc || !arc.bonuses) return null;
    return arc.bonuses;
  }

  /**
   * 获取所有已绑定道侣的加成汇总
   * @returns {Object} 合并后的效果
   */
  getAllActiveBonuses() {
    const merged = {};
    for (const [compId, state] of this.arcStates) {
      if (state.stageIndex < 1) continue; // 未结缘跳过
      const bonuses = this.getCompanionBonuses(compId);
      if (!bonuses) continue;
      for (const [key, val] of Object.entries(bonuses.effects)) {
        merged[key] = (merged[key] || 0) + val;
      }
    }
    return merged;
  }

  /**
   * 注册道侣弧线
   */
  registerCompanion(compId, arcConfig = {}) {
    this.arcStates.set(compId, {
      compId,
      stage: 'NOT_BOUND',
      stageIndex: 0,
      enteredAtTurn: gameState.turn,
      eventsTriggered: new Set(),
      climaxTriggered: false,
      secretsRevealed: [],
      arcConfig
    });
  }

  /**
   * 好感变化 → 检查阶段推进
   */
  onAffectionChanged(compId, newAffection, delta) {
    const state = this.arcStates.get(compId);
    if (!state) return;

    // 确定新阶段
    let newStage = 'NOT_BOUND';
    let newStageIndex = 0;

    // 获取bond和trust
    const compBond = companionSystem.states[compId]?.bond || 0;

    for (const [stageName, stageDef] of Object.entries(this.ARC_STAGES)) {
      const t = stageDef.threshold;
      const meetsAffection = newAffection >= t.affection;
      const meetsBond = !t.bond || compBond >= t.bond;
      if (meetsAffection && meetsBond && stageDef.index > newStageIndex) {
        newStage = stageName;
        newStageIndex = stageDef.index;
      }
    }

    // 阶段提升 → 触发阶段进入事件
    if (newStageIndex > state.stageIndex) {
      const oldStage = state.stage;
      state.stage = newStage;
      state.stageIndex = newStageIndex;
      state.enteredAtTurn = gameState.turn;

      this.worldState.recordEvent({
        type: 'arc_stage_change',
        compId,
        from: oldStage,
        to: newStage,
        turn: gameState.turn
      });

      // 生成阶段进入事件卡
      this._pendingArcEvent = this._buildStageEvent(compId, newStage);

      // 深交阶段以上 → 可能有秘密揭示
      if (newStageIndex >= 3 && state.secretsRevealed.length === 0) {
        this._pendingClimax = this._buildSecretReveal(compId);
      }
    }

    // 好感大幅下降 → 弧线倒退
    if (delta < -20 && state.stageIndex > 1) {
      state.stageIndex = Math.max(1, state.stageIndex - 1);
      const stages = Object.entries(this.ARC_STAGES).filter(([_, s]) => s.index === state.stageIndex);
      state.stage = stages.length > 0 ? stages[0][0] : 'ACQUAINTANCE';
    }
  }

  /**
   * 弧线阶段推进检查
   */
  checkArcProgression(compId, { affection, bond, trust }) {
    this.onAffectionChanged(compId, affection, 0);
  }

  /**
   * 境界突破 → 弧线转折
   */
  onRealmChanged(to) {
    // 对每个道侣检查是否有境界相关的弧线转折
    for (const [compId, state] of this.arcStates) {
      if (state.stageIndex < 2) continue;

      // 金丹期 + 深交(≥3) → 情劫转折
      if (to === 'golden' && state.stageIndex >= 3 && !state.climaxTriggered) {
        this._pendingClimax = this._buildTribulationClimax(compId);
        return;
      }

      // 化神期 + 至交(≥4) → 天命抉择
      if ((to === 'deity' || to === 'tribulation') && state.stageIndex >= 4) {
        this._pendingClimax = this._buildDestinyClimax(compId);
        return;
      }
    }
  }

  /**
   * 死亡 → 保存道侣弧线到转世记忆
   */
  preserveForReincarnation() {
    const arcMemories = [];
    for (const [compId, state] of this.arcStates) {
      if (state.stageIndex >= 3) {
        arcMemories.push({
          compId,
          name: companionSystem._getName(compId),
          stageIndex: state.stageIndex,
          stage: state.stage,
          secretsRevealed: state.secretsRevealed
        });
      }
    }
    // 存入gameState供转世继承
    if (gameState.setFlag) {
      gameState.setFlag('reincarnation_arc_memories', arcMemories);
    }
  }

  // ==========================================
  // 事件生成
  // ==========================================

  getPendingClimax() {
    const c = this._pendingClimax;
    this._pendingClimax = null;
    return c;
  }

  getPendingArcEvent() {
    const e = this._pendingArcEvent;
    this._pendingArcEvent = null;
    return e;
  }

  _buildStageEvent(compId, stage) {
    const name = companionSystem._getName(compId);

    // 【个性化弧线】优先读取 arcs.json 中的个性化数据
    const arcData = this.arcData[compId];
    if (arcData && arcData.arcStages && arcData.arcStages[stage]) {
      const pd = arcData.arcStages[stage];
      return {
        id: `arc_${compId}_stage_${stage}`,
        title: pd.title,
        description: pd.desc,
        type: 'COMPANION_ARC',
        realm: gameState.realm,
        compId,
        arcStage: stage,
        once: true,
        weight: 0,
        tags: ['companion_arc', 'milestone', 'personalized'],
        choices: {
          left: {
            text: pd.leftText,
            effects: pd.leftEffects,
            companionEffects: { compId, affectionDelta: pd.leftAffection || 10, bondDelta: stage === 'DESTINY' ? 1 : 0 }
          },
          right: {
            text: pd.rightText,
            effects: pd.rightEffects,
            companionEffects: { compId, affectionDelta: pd.rightAffection || 5 }
          }
        }
      };
    }

    // 回退：通用模板（无个性化数据时）
    const stageEvents = {
      ACQUAINTANCE: {
        title: `${name}·缘起`,
        desc: `${name}成为了你的道侣——不是轰轰烈烈的告白，也许只是某个傍晚的灵茶，某次战斗中的默契。但有什么东西变了——你看ta的眼神不再像看同门，ta在你身边时你感到的不仅是安心，还有一丝之前从未留意过的暖意。`,
        leftText: `"以后——请多指教"`,
        leftEffects: { daoHeart: 10, fortune: 5 },
        rightText: `沉默——把这份感觉记在心里`,
        rightEffects: { daoHeart: 8, cultivation: 5 }
      },
      KNOWING: {
        title: `${name}·知心`,
        desc: `和${name}相处久了——你开始注意到一些细节。ta喝茶时左手习惯放在杯沿上，t说重要事情前会微微皱眉。你意识到——你在乎这些细节。不是因为ta有用，不是因为修行需要——只是因为这个人是这个人。`,
        leftText: `主动了解ta的过去`,
        leftEffects: { daoHeart: 12, fortune: 5, cultivation: 3 },
        rightText: `让时间慢慢揭示一切`,
        rightEffects: { daoHeart: 8, fortune: 8 }
      },
      DEEP_BOND: {
        title: `${name}·入心`,
        desc: `${name}受伤了——不重，但够让你害怕。你看着ta苍白的脸，想起没有ta的日子——你能活下去，修行也不会停。但那不是"活着"——那是"运转"。你第一次意识到——你不想回到没有ta的日子。这不是软弱，这是你找到的比大道更重要的东西。`,
        leftText: `守在ta身边——直到ta醒来`,
        leftEffects: { daoHeart: 20, fortune: 10, cultivation: -5, karmaGood: 10 },
        rightText: `去寻最好的灵药——最快的速度`,
        rightEffects: { cultivation: 5, fortune: 5, daoHeart: 10, health: -5 }
      },
      SOUL_BOND: {
        title: `${name}·至交`,
        desc: `${name}把一件东西放在你手心——不是法器，不是丹药。是一个小小的、磨得光滑的木雕。ta说："这是我七岁时刻的——刻的是我娘。我娘走后，这是我最珍贵的东西。"\\n\\nta把最珍贵的东西给了你，什么都没要求。`,
        leftText: `紧紧握住——"我会比你娘活得更久"`,
        leftEffects: { daoHeart: 25, karmaGood: 15, fortune: 10 },
        rightText: `还给ta——"你应该留着它"`,
        rightEffects: { daoHeart: 15, karmaGood: 10 }
      },
      DESTINY: {
        title: `${name}·天命`,
        desc: `天命——修道之人最怕的词，因为你控制不了。但${name}站在天劫的边缘，回望你——不是害怕，是笃定。ta说："如果飞升之后不能在一起——我不飞升。"\\n\\n这是对抗天道的宣言。以血肉之躯，以凡人之心。`,
        leftText: `"我们一起——不走天道安排的路"`,
        leftEffects: { daoHeart: 30, karmaGood: 20, fortune: 15, cultivation: 10 },
        rightText: `"你先走——我会追上"`,
        rightEffects: { daoHeart: 20, cultivation: 20, fortune: 5 }
      }
    };

    const data = stageEvents[stage];
    if (!data) return null;

    return {
      id: `arc_${compId}_stage_${stage}`,
      title: data.title,
      description: data.desc,
      type: 'COMPANION_ARC',
      realm: gameState.realm,
      compId,
      arcStage: stage,
      once: true,
      weight: 0,
      tags: ['companion_arc', 'milestone', 'generic'],
      choices: {
        left: {
          text: data.leftText,
          effects: data.leftEffects,
          companionEffects: { compId, affectionDelta: 10, bondDelta: stage === 'DESTINY' ? 1 : 0 }
        },
        right: {
          text: data.rightText,
          effects: data.rightEffects,
          companionEffects: { compId, affectionDelta: 5 }
        }
      }
    };
  }

  _buildSecretReveal(compId) {
    const name = companionSystem._getName(compId);

    // 【个性化秘密揭示】优先读取 arcs.json
    const arcData = this.arcData[compId];
    if (arcData && arcData.secretReveal) {
      const pd = arcData.secretReveal;
      return {
        id: `arc_${compId}_secret_reveal`,
        title: pd.title,
        description: pd.desc,
        type: 'COMPANION_ARC',
        realm: gameState.realm,
        compId,
        arcStage: 'SECRET',
        once: true,
        weight: 0,
        tags: ['companion_arc', 'secret', 'personalized'],
        choices: {
          left: {
            text: pd.leftText,
            effects: pd.leftEffects,
            companionEffects: { compId, affectionDelta: pd.leftAffection || 15, trustDelta: 25 }
          },
          right: {
            text: pd.rightText,
            effects: pd.rightEffects,
            companionEffects: { compId, affectionDelta: pd.rightAffection || 10, trustDelta: 15 }
          }
        }
      };
    }

    // 回退：通用模板
    const npc = npcSystem.getNpc ? npcSystem.getNpc(compId) : null;
    let secretText = `${name}看着你很久，终于说了一件从未对任何人说过的事。`;
    if (npc && npc.secrets && npc.secrets.length > 0) {
      const secret = npc.secrets[0];
      secretText = `${name}深吸一口气："有一件事——我从来没对任何人说过。${secret}。"`;
    }

    return {
      id: `arc_${compId}_secret_reveal`,
      title: `${name}的秘密`,
      description: secretText + `\\n\\nta说完后沉默了很久——你从没见过ta这么脆弱的样子。你把选择权交给ta的沉默——不催、不问、不评判。`,
      type: 'COMPANION_ARC',
      realm: gameState.realm,
      compId,
      arcStage: 'SECRET',
      once: true,
      weight: 0,
      tags: ['companion_arc', 'secret', 'generic'],
      choices: {
        left: {
          text: `"我听到了——但不会因为这件事改变对你的看法"`,
          effects: { daoHeart: 20, karmaGood: 15, fortune: 5 },
          companionEffects: { compId, affectionDelta: 15, trustDelta: 25 }
        },
        right: {
          text: `也分享一个自己的秘密`,
          effects: { daoHeart: 15, karmaGood: 10 },
          companionEffects: { compId, affectionDelta: 20, trustDelta: 20 }
        }
      }
    };
  }

  _buildTribulationClimax(compId) {
    const name = companionSystem._getName(compId);

    // 【个性化情劫】优先读取 arcs.json
    const arcData = this.arcData[compId];
    if (arcData && arcData.tribulationClimax) {
      const pd = arcData.tribulationClimax;
      return {
        id: `arc_${compId}_tribulation`,
        title: pd.title,
        description: pd.desc,
        type: 'COMPANION_ARC',
        realm: gameState.realm,
        compId,
        arcStage: 'CLIMAX',
        once: true,
        weight: 0,
        tags: ['companion_arc', 'tribulation', 'climax', 'personalized'],
        choices: {
          left: {
            text: pd.leftText,
            effects: pd.leftEffects,
            companionEffects: { compId, affectionDelta: pd.leftAffection || 20, bondDelta: 1 }
          },
          right: {
            text: pd.rightText,
            effects: pd.rightEffects,
            companionEffects: { compId, affectionDelta: pd.rightAffection || 10 }
          }
        }
      };
    }

    // 回退：通用模板
    return {
      id: `arc_${compId}_tribulation`,
      title: `${name}·情劫`,
      description: `天劫不总是雷——有时它以一个你最爱的人的面目出现。${name}的天劫降临了——而天道给你的考验是：看着ta承受一切，不能出手。因为一旦你出手，天劫加倍，你们俩都活不了。\\n\\nta在雷光中回头看了你一眼——不是求救，是告别。`,
      type: 'COMPANION_ARC',
      realm: gameState.realm,
      compId,
      arcStage: 'CLIMAX',
      once: true,
      weight: 0,
      tags: ['companion_arc', 'tribulation', 'climax', 'generic'],
      choices: {
        left: {
          text: "遵守天道规则——'我相信你'",
          effects: { daoHeart: 15, karmaGood: 10, fortune: 10 },
          companionEffects: { compId, affectionDelta: 10, bondDelta: 1, trustDelta: 5 }
        },
        right: {
          text: "冲进去——'去他妈的天道'",
          effects: { daoHeart: 25, health: -40, karmaGood: 20, fortune: -15 },
          companionEffects: { compId, affectionDelta: 30, bondDelta: 1 }
        }
      }
    };
  }

  _buildDestinyClimax(compId) {
    const name = companionSystem._getName(compId);

    // 【个性化天命抉择】优先读取 arcs.json
    const arcData = this.arcData[compId];
    if (arcData && arcData.destinyClimax) {
      const pd = arcData.destinyClimax;
      return {
        id: `arc_${compId}_destiny`,
        title: pd.title,
        description: pd.desc,
        type: 'COMPANION_ARC',
        realm: gameState.realm,
        compId,
        arcStage: 'DESTINY_CLIMAX',
        once: true,
        weight: 0,
        tags: ['companion_arc', 'destiny', 'finale', 'personalized'],
        choices: {
          left: {
            text: pd.leftText,
            effects: pd.leftEffects,
            companionEffects: { compId, affectionDelta: pd.leftAffection || 30, bondDelta: 2 }
          },
          right: {
            text: pd.rightText,
            effects: pd.rightEffects,
            companionEffects: { compId, affectionDelta: pd.rightAffection || 15, bondDelta: 0 }
          }
        }
      };
    }

    // 回退：通用模板
    return {
      id: `arc_${compId}_destiny`,
      title: `${name}·天命抉择`,
      description: `飞升在即——天道问了你一个问题，不是用语言，是用因果。它向你展示了两条路：飞升，但忘掉一切——包括${name}；或者留下，和${name}一起在苍茫界渡过余生，永远放弃触摸天道的机会。\\n\\n这不是一个选项——这是一道烙印，刻进你的道心里的烙印，会影响你未来的每一次转世。`,
      type: 'COMPANION_ARC',
      realm: gameState.realm,
      compId,
      arcStage: 'DESTINY_CLIMAX',
      once: true,
      weight: 0,
      tags: ['companion_arc', 'destiny', 'finale', 'generic'],
      choices: {
        left: {
          text: "留下——'大道若不共——不是我要的道'",
          effects: { daoHeart: 40, karmaGood: 30, fortune: 20, cultivation: -20 },
          companionEffects: { compId, affectionDelta: 50, bondDelta: 2 }
        },
        right: {
          text: "飞升——但发誓找到让ta也飞升的方法",
          effects: { cultivation: 30, daoHeart: 15, karmaGood: 10, fortune: 5 },
          companionEffects: { compId, affectionDelta: -10, bondDelta: 0, trustDelta: -5 },
          karmaSeed: { id: 'destinyPromise', seedType: 'fate', delay: 20, priority: 10 }
        }
      }
    };
  }
}

// ==========================================
// NarrativeSurfacing — 叙事浮现层
// ==========================================

class NarrativeSurfacing {
  constructor(worldState) {
    this.worldState = worldState;
    this._lastSurfacingTurn = 0;
  }

  /**
   * 检查是否需要叙事浮现
   * 浮现：把系统层的状态变化"翻译"成玩家能感知的叙事
   */
  check() {
    if (gameState.turn - this._lastSurfacingTurn < 5) return null;
    this._lastSurfacingTurn = gameState.turn;

    // 检查1：世界观变化浮现
    const worldChange = this._checkWorldChange();
    if (worldChange) return worldChange;

    // 检查2：因果浮现
    const karmaSurface = this._checkKarmaSurface();
    if (karmaSurface) return karmaSurface;

    // 检查3：道侣情感浮现
    const affectionSurface = this._checkAffectionSurface();
    if (affectionSurface) return affectionSurface;

    return null;
  }

  _checkWorldChange() {
    // 如果白刃真人去世了且距今5轮内
    const bairenDeathTurn = this.worldState.deathTurn.get('bairen_zhenren');
    if (bairenDeathTurn && gameState.turn - bairenDeathTurn === 3) {
      return {
        id: 'surface_bairen_memory',
        title: '白刃的遗产',
        description: '今天路过剑冢时——一把剑自己出鞘了。不是你的剑。是白刃真人的。它悬在空中，剑尖指向你，没有敌意——像是一个遗愿。剑身上映出了白刃真人最后一次舞剑的残影——那是他教你的第一式。也是最后一批学员的第一式。\\n\\n他没有弟子了——只有你。',
        type: 'SURFACING',
        realm: gameState.realm,
        choices: {
          left: { text: '接过剑——继承剑道传承', effects: { cultivation: 15, daoHeart: 20, treasure: '白刃遗剑' } },
          right: { text: '让剑回剑冢——和师父一起安息', effects: { daoHeart: 25, karmaGood: 15 } }
        }
      };
    }

    return null;
  }

  _checkKarmaSurface() {
    const seeds = gameState.karmaSeeds || [];
    if (seeds.length >= 4) {
      return {
        id: 'surface_karma_burden',
        title: '肩上的重量',
        description: `你感到双肩沉重——不是肉体上的，是因果上的。${seeds.length}颗因果种子在你识海中沉睡——每一颗都是一件未了的事、一笔未清的账。它们不吵不闹，但它们在那里——你知道它们在那里。`,
        type: 'SURFACING',
        realm: gameState.realm,
        tags: ['surfacing', 'karma'],
        choices: {
          left: { text: '坦然面对——「该来的总会来」', effects: { daoHeart: 10, fortune: 5 } },
          right: { text: '暂时放下——专注当下', effects: { cultivation: 10, daoHeart: -3 } }
        }
      };
    }
    return null;
  }

  _checkAffectionSurface() {
    // 如果某个道侣好感接近但未达到阈值 → 浮现一个推动事件
    for (const [compId, state] of Object.entries(companionSystem.states || {})) {
      const aff = state.affection || 0;
      if (aff >= 18 && aff < 20 && !gameState.hasFlag(`surface_pushed_${compId}_20`)) {
        gameState.setFlag(`surface_pushed_${compId}_20`, true);
        const name = companionSystem._getName(compId);
        return {
          id: `surface_${compId}_near_20`,
          title: `${name}的眼神`,
          description: `你注意到${name}最近看你的方式有些不一样——不是奇怪，是更专注了。ta在你说话时不会走神了——这在以前很常见。ta记得你前天说过的一句无关紧要的话——这种记忆对于一个修士来说很不寻常。\\n\\n也许ta自己都没意识到。但你意识到了。`,
          type: 'SURFACING',
          realm: gameState.realm,
          compId,
          choices: {
            left: { text: '回应这份关注——多陪陪ta', effects: { daoHeart: 8, fortune: 5 },
              companionEffects: { compId, affectionDelta: 5 } },
            right: { text: '装作没注意到', effects: { daoHeart: 5 } }
          }
        };
      }
    }
    return null;
  }
}

// ==========================================
// MentorArcEngine — 师尊弧线引擎
// ==========================================
// 基于"传承值"而非好感度驱动的师徒关系。
// 白刃真人→叶凌云：被收留的弟子→接过剑的传人
// 阶段：DISCIPLE → INNER_DISCIPLE → TRUSTED → HEIR → LEGACY

class MentorArcEngine {
  constructor(worldState) {
    this.worldState = worldState;
    this.arcData = {};

    this.ARC_STAGES = {
      DISCIPLE:        { index: 0, name: '弟子',      threshold: 0  },
      INNER_DISCIPLE:  { index: 1, name: '入室弟子',  threshold: 20 },
      TRUSTED:         { index: 2, name: '心腹弟子',  threshold: 40 },
      HEIR:            { index: 3, name: '衣钵传人',  threshold: 60 },
      LEGACY:          { index: 4, name: '薪火相传',  threshold: 80 }
    };

    this.arcStates = new Map();
    this._pendingClimax = null;
    this._pendingArcEvent = null;
  }

  loadArcs(data) {
    this.arcData = data || {};
  }

  registerMentor(npcId) {
    this.arcStates.set(npcId, {
      npcId,
      stage: 'DISCIPLE',
      stageIndex: 0,
      progression: 0,
      enteredAtTurn: gameState.turn,
      eventsTriggered: new Set(),
      climaxTriggered: false
    });
  }

  getMentorBonuses(npcId) {
    const arc = this.arcData[npcId];
    if (!arc || !arc.bonuses) return null;
    return arc.bonuses;
  }

  getAllActiveBonuses() {
    const merged = {};
    for (const [npcId, state] of this.arcStates) {
      if (state.stageIndex < 1) continue;
      const bonuses = this.getMentorBonuses(npcId);
      if (!bonuses) continue;
      for (const [key, val] of Object.entries(bonuses.effects)) {
        merged[key] = (merged[key] || 0) + val;
      }
    }
    return merged;
  }

  onProgressionChanged(npcId, newValue) {
    const state = this.arcStates.get(npcId);
    if (!state) return;

    let newStage = 'DISCIPLE';
    let newStageIndex = 0;
    for (const [stageName, stageDef] of Object.entries(this.ARC_STAGES)) {
      if (newValue >= stageDef.threshold && stageDef.index > newStageIndex) {
        newStage = stageName;
        newStageIndex = stageDef.index;
      }
    }

    if (newStageIndex > state.stageIndex) {
      state.stage = newStage;
      state.stageIndex = newStageIndex;
      state.enteredAtTurn = gameState.turn;
      this.worldState.recordEvent({ type: 'mentor_stage_change', npcId, to: newStage, turn: gameState.turn });
      this._pendingArcEvent = this._buildStageEvent(npcId, newStage);
      if (newStageIndex >= 3 && !state.climaxTriggered) {
        this._pendingClimax = this._buildRevelation(npcId);
      }
    }
  }

  /**
   * 累加传承值（由外部游戏行为——修炼突破/论道/试炼——触发）
   */
  addProgression(npcId, delta) {
    const state = this.arcStates.get(npcId);
    if (!state) return;
    state.progression = Math.min(100, Math.max(0, state.progression + delta));
    this.onProgressionChanged(npcId, state.progression);
  }

  onRealmChanged(to) {
    for (const [npcId, state] of this.arcStates) {
      if (state.stageIndex >= 3 && to === 'golden' && !state.climaxTriggered) {
        this._pendingClimax = this._buildTribulationClimax(npcId);
        return;
      }
      if ((to === 'deity' || to === 'tribulation') && state.stageIndex >= 4) {
        this._pendingClimax = this._buildDestinyClimax(npcId);
        return;
      }
    }
  }

  getPendingClimax() { const c = this._pendingClimax; this._pendingClimax = null; return c; }
  getPendingArcEvent() { const e = this._pendingArcEvent; this._pendingArcEvent = null; return e; }

  _getName(npcId) {
    const arc = this.arcData[npcId];
    return arc ? arc.name : npcId;
  }

  _buildStageEvent(npcId, stage) {
    const name = this._getName(npcId);
    const arc = this.arcData[npcId];
    if (arc && arc.arcStages && arc.arcStages[stage]) {
      const pd = arc.arcStages[stage];
      return {
        id: `mentor_${npcId}_stage_${stage}`,
        title: pd.title, description: pd.desc,
        type: 'MENTOR_ARC', realm: gameState.realm, npcId, arcStage: stage,
        once: true, weight: 0, tags: ['mentor_arc', 'milestone'],
        choices: {
          left: { text: pd.leftText, effects: pd.leftEffects },
          right: { text: pd.rightText, effects: pd.rightEffects }
        }
      };
    }
    // 回退：通用模板
    const mentorStages = {
      RECRUITMENT: { title: `${name}·收徒`, desc: `${name}看着你很久——不是看你的修为，是看你的骨。半晌，他点了点头。`, leftText: '跪下——行拜师礼', leftEffects: { daoHeart: 15, cultivation: 10 }, rightText: '拱手——以礼相待但不必跪', rightEffects: { daoHeart: 10, cultivation: 5 } },
      TRAINING: { title: `${name}·传道`, desc: `${name}把一本书放在你面前——封面已经快碎了，是他年轻时手抄的。`, leftText: '日夜研读——书中的每一个字都刻进心里', leftEffects: { cultivation: 20, daoHeart: 10 }, rightText: '通读一遍——抓住精髓就够了', rightEffects: { cultivation: 10, daoHeart: 5 } },
      REVELATION: { title: `${name}·真相`, desc: `${name}终于说了一件从来没说过的事——一件关于他自己、关于青云、关于你修炼速度的秘密。`, leftText: '追问——我想知道全部', leftEffects: { daoHeart: 20, cultivation: 5 }, rightText: '沉默——让师父说多少算多少', rightEffects: { daoHeart: 15 } },
      TRANSMISSION: { title: `${name}·衣钵`, desc: `${name}脱下了他的剑——不是比喻，是真的剑。递给你。`, leftText: '双手接剑——"弟子不负此剑"', leftEffects: { daoHeart: 25, cultivation: 15 }, rightText: '推辞——"师父还需要它"', rightEffects: { daoHeart: 15, cultivation: 5 } },
      ASCENSION: { title: `${name}·飞升`, desc: `${name}即将飞升。他最后看了你一眼——不需要说话。你明白。`, leftText: '叩首——"弟子送师父"', leftEffects: { daoHeart: 30, cultivation: 10 }, rightText: '站立——"弟子会追上"', rightEffects: { daoHeart: 20, cultivation: 20 } }
    };
    const data = mentorStages[stage];
    if (!data) return null;
    return { id: `mentor_${npcId}_stage_${stage}`, title: data.title, description: data.desc,
      type: 'MENTOR_ARC', realm: gameState.realm, npcId, arcStage: stage,
      once: true, weight: 0, tags: ['mentor_arc', 'milestone'],
      choices: { left: { text: data.leftText, effects: data.leftEffects }, right: { text: data.rightText, effects: data.rightEffects } } };
  }

  _buildRevelation(npcId) {
    const arc = this.arcData[npcId];
    if (!arc || !arc.revelation) return null;
    const pd = arc.revelation;
    return {
      id: `mentor_${npcId}_revelation`,
      title: pd.title, description: pd.desc,
      type: 'MENTOR_ARC', realm: gameState.realm, npcId, arcStage: 'REVELATION',
      once: true, weight: 0, tags: ['mentor_arc', 'revelation'],
      choices: {
        left: { text: pd.leftText, effects: pd.leftEffects },
        right: { text: pd.rightText, effects: pd.rightEffects }
      }
    };
  }

  _buildTribulationClimax(npcId) {
    const arc = this.arcData[npcId];
    if (!arc || !arc.tribulationClimax) return null;
    const pd = arc.tribulationClimax;
    return {
      id: `mentor_${npcId}_tribulation`,
      title: pd.title, description: pd.desc,
      type: 'MENTOR_ARC', realm: gameState.realm, npcId, arcStage: 'CLIMAX',
      once: true, weight: 0, tags: ['mentor_arc', 'tribulation'],
      choices: {
        left: { text: pd.leftText, effects: pd.leftEffects },
        right: { text: pd.rightText, effects: pd.rightEffects }
      }
    };
  }

  _buildDestinyClimax(npcId) {
    const arc = this.arcData[npcId];
    if (!arc || !arc.destinyClimax) return null;
    const pd = arc.destinyClimax;
    return {
      id: `mentor_${npcId}_destiny`,
      title: pd.title, description: pd.desc,
      type: 'MENTOR_ARC', realm: gameState.realm, npcId, arcStage: 'DESTINY',
      once: true, weight: 0, tags: ['mentor_arc', 'destiny'],
      choices: {
        left: { text: pd.leftText, effects: pd.leftEffects },
        right: { text: pd.rightText, effects: pd.rightEffects }
      }
    };
  }
}

// ==========================================
// SeerArcEngine — 先知弧线引擎
// ==========================================
// 基于"天机揭示度"而非好感度。天机老人不是朋友——是真相的递送者。
// 阶段：ENCOUNTER → REVELATION → UNVEILING → SACRIFICE → FINAL_PROPHECY

class SeerArcEngine {
  constructor(worldState) {
    this.worldState = worldState;
    this.arcData = {};

    this.ARC_STAGES = {
      ENCOUNTER:       { index: 0, name: '初遇',      threshold: 0  },
      REVELATION:      { index: 1, name: '揭示',      threshold: 20 },
      UNVEILING:       { index: 2, name: '揭开',      threshold: 40 },
      SACRIFICE:       { index: 3, name: '牺牲',      threshold: 60 },
      FINAL_PROPHECY:  { index: 4, name: '终极预言',  threshold: 80 }
    };

    this.arcStates = new Map();
    this._pendingClimax = null;
    this._pendingArcEvent = null;
  }

  loadArcs(data) {
    this.arcData = data || {};
  }

  registerSeer(npcId) {
    this.arcStates.set(npcId, {
      npcId, stage: 'ENCOUNTER', stageIndex: 0,
      revelation: 0, enteredAtTurn: gameState.turn,
      eventsTriggered: new Set(), climaxTriggered: false
    });
  }

  getSeerBonuses(npcId) {
    const arc = this.arcData[npcId];
    return (arc && arc.bonuses) ? arc.bonuses : null;
  }

  getAllActiveBonuses() {
    const merged = {};
    for (const [npcId, state] of this.arcStates) {
      if (state.stageIndex < 1) continue;
      const bonuses = this.getSeerBonuses(npcId);
      if (!bonuses) continue;
      for (const [key, val] of Object.entries(bonuses.effects)) {
        merged[key] = (merged[key] || 0) + val;
      }
    }
    return merged;
  }

  onRevelationChanged(npcId, newValue) {
    const state = this.arcStates.get(npcId);
    if (!state) return;

    let newStage = 'ENCOUNTER';
    let newStageIndex = 0;
    for (const [stageName, stageDef] of Object.entries(this.ARC_STAGES)) {
      if (newValue >= stageDef.threshold && stageDef.index > newStageIndex) {
        newStage = stageName;
        newStageIndex = stageDef.index;
      }
    }

    if (newStageIndex > state.stageIndex) {
      state.stage = newStage;
      state.stageIndex = newStageIndex;
      state.enteredAtTurn = gameState.turn;
      this._pendingArcEvent = this._buildStageEvent(npcId, newStage);
      if (newStageIndex >= 3 && !state.climaxTriggered) {
        this._pendingClimax = this._buildRevelation(npcId);
      }
    }
  }

  /**
   * 累加天机揭示度（由探索/发现秘密/道心突破触发）
   */
  addRevelation(npcId, delta) {
    const state = this.arcStates.get(npcId);
    if (!state) return;
    state.revelation = Math.min(100, Math.max(0, state.revelation + delta));
    this.onRevelationChanged(npcId, state.revelation);
  }

  onRealmChanged(to) {
    for (const [npcId, state] of this.arcStates) {
      if (state.stageIndex >= 3 && to === 'golden' && !state.climaxTriggered) {
        this._pendingClimax = this._buildTribulationClimax(npcId);
        return;
      }
      if ((to === 'deity' || to === 'tribulation') && state.stageIndex >= 4) {
        this._pendingClimax = this._buildDestinyClimax(npcId);
        return;
      }
    }
  }

  getPendingClimax() { const c = this._pendingClimax; this._pendingClimax = null; return c; }
  getPendingArcEvent() { const e = this._pendingArcEvent; this._pendingArcEvent = null; return e; }

  _getName(npcId) { const arc = this.arcData[npcId]; return arc ? arc.name : npcId; }

  _buildStageEvent(npcId, stage) {
    const arc = this.arcData[npcId];
    if (!arc || !arc.arcStages || !arc.arcStages[stage]) {
      // 回退：通用模板
      const name = this._getName(npcId);
      const seerStages = {
        ENCOUNTER: { title: `${name}·窥命`, desc: `${name}抬头看了你一眼——不需要生辰八字，不需要罗盘。他看到了。`, leftText: '追问——"你看到了什么？"', leftEffects: { daoHeart: 15, fortune: 10 }, rightText: '沉默——等他自己说', rightEffects: { daoHeart: 10, fortune: 5 } },
        REVELATION: { title: `${name}·天机`, desc: `${name}终于开口了——他的话不多，但每一个字都像钉子一样钉进你的识海。`, leftText: '深信——按照预言行动', leftEffects: { daoHeart: 15, fortune: 15, cultivation: -5 }, rightText: '存疑——天机未必就是定数', rightEffects: { daoHeart: 10, cultivation: 10 } },
        UNVEILING: { title: `${name}·揭开`, desc: `${name}把一本发黄的古卷推到你面前——上面画着你。或者说是你应该成为的样子。`, leftText: '仔细研读——关于自己的每一句预言', leftEffects: { daoHeart: 20, fortune: 15 }, rightText: '合上——"我只信当下的自己"', rightEffects: { daoHeart: 15, cultivation: 10 } },
        SACRIFICE: { title: `${name}·代价`, desc: `${name}咳了一口血——为你看天机的代价。天机不可泄，泄天机者折寿。`, leftText: '悔悟——"我不该让你看的"', leftEffects: { daoHeart: 25, karmaGood: 20, fortune: 5 }, rightText: '铭记——让你的牺牲不白费', rightEffects: { daoHeart: 20, cultivation: 15, fortune: 10 } },
        FINAL_PROPHECY: { title: `${name}·终章`, desc: `${name}笑了——这个一辈子没笑过几次的人，笑了。他看到了什么，但不肯说了。`, leftText: '恳求——"最后一次——告诉我"', leftEffects: { daoHeart: 20, fortune: 20 }, rightText: '释然——"不说也好"', rightEffects: { daoHeart: 30 } }
      };
      const data = seerStages[stage];
      if (!data) return null;
      return { id: `seer_${npcId}_stage_${stage}`, title: data.title, description: data.desc,
        type: 'SEER_ARC', realm: gameState.realm, npcId, arcStage: stage,
        once: true, weight: 0, tags: ['seer_arc', 'milestone'],
        choices: { left: { text: data.leftText, effects: data.leftEffects }, right: { text: data.rightText, effects: data.rightEffects } } };
    }
    const pd = arc.arcStages[stage];
    return {
      id: `seer_${npcId}_stage_${stage}`,
      title: pd.title, description: pd.desc,
      type: 'SEER_ARC', realm: gameState.realm, npcId, arcStage: stage,
      once: true, weight: 0, tags: ['seer_arc', 'milestone'],
      choices: { left: { text: pd.leftText, effects: pd.leftEffects }, right: { text: pd.rightText, effects: pd.rightEffects } }
    };
  }

  _buildRevelation(npcId) {
    const arc = this.arcData[npcId];
    if (!arc || !arc.revelation) return null;
    const pd = arc.revelation;
    return {
      id: `seer_${npcId}_revelation`,
      title: pd.title, description: pd.desc,
      type: 'SEER_ARC', realm: gameState.realm, npcId, arcStage: 'REVELATION',
      once: true, weight: 0, tags: ['seer_arc', 'revelation'],
      choices: {
        left: { text: pd.leftText, effects: pd.leftEffects },
        right: { text: pd.rightText, effects: pd.rightEffects }
      }
    };
  }

  _buildTribulationClimax(npcId) {
    const arc = this.arcData[npcId];
    if (!arc || !arc.tribulationClimax) return null;
    const pd = arc.tribulationClimax;
    return {
      id: `seer_${npcId}_tribulation`,
      title: pd.title, description: pd.desc,
      type: 'SEER_ARC', realm: gameState.realm, npcId, arcStage: 'CLIMAX',
      once: true, weight: 0, tags: ['seer_arc', 'tribulation'],
      choices: {
        left: { text: pd.leftText, effects: pd.leftEffects },
        right: { text: pd.rightText, effects: pd.rightEffects }
      }
    };
  }

  _buildDestinyClimax(npcId) {
    const arc = this.arcData[npcId];
    if (!arc || !arc.destinyClimax) return null;
    const pd = arc.destinyClimax;
    return {
      id: `seer_${npcId}_destiny`,
      title: pd.title, description: pd.desc,
      type: 'SEER_ARC', realm: gameState.realm, npcId, arcStage: 'DESTINY',
      once: true, weight: 0, tags: ['seer_arc', 'destiny'],
      choices: {
        left: { text: pd.leftText, effects: pd.leftEffects },
        right: { text: pd.rightText, effects: pd.rightEffects }
      }
    };
  }
}

// ==========================================
// AllyArcEngine — 盟友弧线引擎
// ==========================================
// 基于"同盟度"驱动。血煞老祖不是道侣不是师尊——是目标一致的战友。
// 阶段：CONTACT → RECOGNITION → TRUST → COMRADE → LEGACY

class AllyArcEngine {
  constructor(worldState) {
    this.worldState = worldState;
    this.arcData = {};

    this.ARC_STAGES = {
      CONTACT:      { index: 0, name: '接触',      threshold: 0  },
      RECOGNITION:  { index: 1, name: '认可',      threshold: 20 },
      TRUST:        { index: 2, name: '信任',      threshold: 40 },
      COMRADE:      { index: 3, name: '战友',      threshold: 60 },
      LEGACY:       { index: 4, name: '传承',      threshold: 80 }
    };

    this.arcStates = new Map();
    this._pendingClimax = null;
    this._pendingArcEvent = null;
  }

  loadArcs(data) {
    this.arcData = data || {};
  }

  registerAlly(npcId) {
    this.arcStates.set(npcId, {
      npcId, stage: 'CONTACT', stageIndex: 0,
      alignment: 0, enteredAtTurn: gameState.turn,
      eventsTriggered: new Set(), climaxTriggered: false
    });
  }

  getAllyBonuses(npcId) {
    const arc = this.arcData[npcId];
    return (arc && arc.bonuses) ? arc.bonuses : null;
  }

  getAllActiveBonuses() {
    const merged = {};
    for (const [npcId, state] of this.arcStates) {
      if (state.stageIndex < 1) continue;
      const bonuses = this.getAllyBonuses(npcId);
      if (!bonuses) continue;
      for (const [key, val] of Object.entries(bonuses.effects)) {
        merged[key] = (merged[key] || 0) + val;
      }
    }
    return merged;
  }

  onAlignmentChanged(npcId, newValue) {
    const state = this.arcStates.get(npcId);
    if (!state) return;

    let newStage = 'CONTACT';
    let newStageIndex = 0;
    for (const [stageName, stageDef] of Object.entries(this.ARC_STAGES)) {
      if (newValue >= stageDef.threshold && stageDef.index > newStageIndex) {
        newStage = stageName;
        newStageIndex = stageDef.index;
      }
    }

    if (newStageIndex > state.stageIndex) {
      state.stage = newStage;
      state.stageIndex = newStageIndex;
      state.enteredAtTurn = gameState.turn;
      this._pendingArcEvent = this._buildStageEvent(npcId, newStage);
      if (newStageIndex >= 3 && !state.climaxTriggered) {
        this._pendingClimax = this._buildRevelation(npcId);
      }
    }
  }

  /**
   * 累加同盟度（由共同战斗/利益结盟/资源交易触发）
   */
  addAlignment(npcId, delta) {
    const state = this.arcStates.get(npcId);
    if (!state) return;
    state.alignment = Math.min(100, Math.max(0, state.alignment + delta));
    this.onAlignmentChanged(npcId, state.alignment);
  }

  onRealmChanged(to) {
    for (const [npcId, state] of this.arcStates) {
      if (state.stageIndex >= 3 && to === 'golden' && !state.climaxTriggered) {
        this._pendingClimax = this._buildTribulationClimax(npcId);
        return;
      }
      if ((to === 'deity' || to === 'tribulation') && state.stageIndex >= 4) {
        this._pendingClimax = this._buildDestinyClimax(npcId);
        return;
      }
    }
  }

  getPendingClimax() { const c = this._pendingClimax; this._pendingClimax = null; return c; }
  getPendingArcEvent() { const e = this._pendingArcEvent; this._pendingArcEvent = null; return e; }

  _getName(npcId) { const arc = this.arcData[npcId]; return arc ? arc.name : npcId; }

  _buildStageEvent(npcId, stage) {
    const arc = this.arcData[npcId];
    if (!arc || !arc.arcStages || !arc.arcStages[stage]) {
      // 回退：通用模板
      const name = this._getName(npcId);
      const allyStages = {
        CONTACT: { title: `${name}·相逢`, desc: `${name}在黑暗里看着你——不是敌人，但也不是朋友。至少现在不是。`, leftText: '直面——"你想怎样"', leftEffects: { daoHeart: 10, health: -5 }, rightText: '观察——等待对方先开口', rightEffects: { daoHeart: 5, fortune: 5 } },
        RECOGNITION: { title: `${name}·认可`, desc: `${name}点了点头——很轻，轻到你差点错过。这大概是他能给出的最大尊重。`, leftText: '回礼——"彼此彼此"', leftEffects: { daoHeart: 15, cultivation: 10 }, rightText: '无言——一个眼神就够了', rightEffects: { daoHeart: 10, cultivation: 5 } },
        TRUST: { title: `${name}·托付`, desc: `${name}把后背交给了你——不是比喻。他真的背对着你，去处理前面的事。`, leftText: '守住——寸步不离', leftEffects: { daoHeart: 20, karmaGood: 15, health: -10 }, rightText: '警惕——他未必真的信你', rightEffects: { daoHeart: 10, fortune: 5 } },
        COMRADE: { title: `${name}·并肩`, desc: `${name}和你背靠背站着——四周全是敌人。他笑了一声："没想到会是你。"`, leftText: '"我也没想到"——挥剑向前', leftEffects: { daoHeart: 25, cultivation: 15, health: -10 }, rightText: '"少废话——打完再说"', rightEffects: { cultivation: 20, daoHeart: 15 } },
        LEGACY: { title: `${name}·传承`, desc: `${name}把他最珍贵的东西给你了——不是法器，不是功法。是一个承诺。`, leftText: '接受——"你的路，我替你走完"', leftEffects: { daoHeart: 30, karmaGood: 20 }, rightText: '拒绝——"你自己走完"', rightEffects: { daoHeart: 15, cultivation: 15 } }
      };
      const data = allyStages[stage];
      if (!data) return null;
      return { id: `ally_${npcId}_stage_${stage}`, title: data.title, description: data.desc,
        type: 'ALLY_ARC', realm: gameState.realm, npcId, arcStage: stage,
        once: true, weight: 0, tags: ['ally_arc', 'milestone'],
        choices: { left: { text: data.leftText, effects: data.leftEffects }, right: { text: data.rightText, effects: data.rightEffects } } };
    }
    const pd = arc.arcStages[stage];
    return {
      id: `ally_${npcId}_stage_${stage}`,
      title: pd.title, description: pd.desc,
      type: 'ALLY_ARC', realm: gameState.realm, npcId, arcStage: stage,
      once: true, weight: 0, tags: ['ally_arc', 'milestone'],
      choices: { left: { text: pd.leftText, effects: pd.leftEffects }, right: { text: pd.rightText, effects: pd.rightEffects } }
    };
  }

  _buildRevelation(npcId) {
    const arc = this.arcData[npcId];
    if (!arc || !arc.revelation) return null;
    const pd = arc.revelation;
    return {
      id: `ally_${npcId}_revelation`,
      title: pd.title, description: pd.desc,
      type: 'ALLY_ARC', realm: gameState.realm, npcId, arcStage: 'REVELATION',
      once: true, weight: 0, tags: ['ally_arc', 'revelation'],
      choices: {
        left: { text: pd.leftText, effects: pd.leftEffects },
        right: { text: pd.rightText, effects: pd.rightEffects }
      }
    };
  }

  _buildTribulationClimax(npcId) {
    const arc = this.arcData[npcId];
    if (!arc || !arc.tribulationClimax) return null;
    const pd = arc.tribulationClimax;
    return {
      id: `ally_${npcId}_tribulation`,
      title: pd.title, description: pd.desc,
      type: 'ALLY_ARC', realm: gameState.realm, npcId, arcStage: 'CLIMAX',
      once: true, weight: 0, tags: ['ally_arc', 'tribulation'],
      choices: {
        left: { text: pd.leftText, effects: pd.leftEffects },
        right: { text: pd.rightText, effects: pd.rightEffects }
      }
    };
  }

  _buildDestinyClimax(npcId) {
    const arc = this.arcData[npcId];
    if (!arc || !arc.destinyClimax) return null;
    const pd = arc.destinyClimax;
    return {
      id: `ally_${npcId}_destiny`,
      title: pd.title, description: pd.desc,
      type: 'ALLY_ARC', realm: gameState.realm, npcId, arcStage: 'DESTINY',
      once: true, weight: 0, tags: ['ally_arc', 'destiny'],
      choices: {
        left: { text: pd.leftText, effects: pd.leftEffects },
        right: { text: pd.rightText, effects: pd.rightEffects }
      }
    };
  }
}

// 全局单例
const storyNetworkSystem = new StoryNetworkSystem();
