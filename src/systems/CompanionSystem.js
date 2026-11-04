/**
 * CompanionSystem - 道侣养成引擎
 *
 * 管理道侣关系、事件调度、互动效果。
 * 事件通过 CardSystem 优先级50注入卡牌流。
 * 数据来源：data/companions/events.json (通过 DataLoader 加载)
 */
class CompanionSystem {
  constructor() {
    /** @type {Map<string, Object>} companionId → 道侣基础数据 */
    this.companions = new Map();
    /** @type {Map<string, Object[]>} companionId → 事件列表 */
    this.events = new Map();
    /** @type {Object<string, Object>} 道侣状态（羁绊/信任/冷却；好感唯一归 NpcSystem） */
    this.states = {};
    /** @type {Object} 待触发的危机事件 */
    this._pendingCrisis = null;
    /** @type {Object} 事件冷却计时器 */
    this._cooldowns = {};
    /** @type {Array} 【P1 #9 修复】里程碑缓存队列——解决 emit 时序对撞丢失 */
    this._pendingMilestones = [];
    /** 好感立绘定义。选择状态仍由 GameStateManager.unlocks 持久化。 */
    this.portraitStages = new Map();
  }

  /**
   * 初始化：注册事件监听
   */
  init() {
    eventBus.on('companion:checkEvent', () => this._onCheckEvent());
    eventBus.on('companion:getPanelData', (data) => this._onGetPanelData(data));
    eventBus.on('companion:gift', (data) => this._onGift(data));
    eventBus.on('companion:heartEvent', (data) => this._onHeartEvent(data));
    eventBus.on('npc:lifecycleChanged', (data) => this._onNpcLifecycleChanged(data));
  }

  _canPhysicallyAppear(compId) {
    return typeof worldContinuityStore === 'undefined' || !worldContinuityStore
      || worldContinuityStore.canPhysicallyAppear(compId);
  }

  _isNarrativeEligible(card) {
    return Boolean(card) && (
      typeof narrativeLedger === 'undefined' || !narrativeLedger
      || typeof narrativeLedger.canPresent !== 'function'
      || narrativeLedger.canPresent(card, { state: gameState })
    );
  }

  _onNpcLifecycleChanged(data) {
    const npcId = data?.npcId;
    if (!npcId || data?.current?.manifestation === 'PHYSICAL') return;
    this._pendingMilestones = this._pendingMilestones.filter(item => {
      const card = item?.card;
      return card?.compId !== npcId && card?.npcId !== npcId
        && !(Array.isArray(card?.npcIds) && card.npcIds.includes(npcId));
    });
    if (this._pendingCrisis?.compId === npcId) this._pendingCrisis = null;
  }

  /**
   * 加载道侣数据
   * @param {Object} data - { companions: [...] }
   */
  loadData(data) {
    if (!data || !data.companions) return;

    const restoredProgress = typeof gameState !== 'undefined'
      && gameState.companionProgress
      && typeof gameState.companionProgress === 'object'
      ? gameState.companionProgress
      : { states: {}, cooldowns: {} };

    for (const comp of data.companions) {
      this.companions.set(comp.id, comp);
      this.events.set(comp.id, comp.events || []);
      const inheritedAffection = typeof gameState !== 'undefined'
        ? Number(gameState.unlocks?.legacy?.npcAffections?.[comp.id]) || 0
        : 0;
      const npcAffection = typeof npcSystem !== 'undefined'
        ? Number(npcSystem.affections?.[comp.id]) || 0
        : 0;
      const hasRestoredAffection = Object.prototype.hasOwnProperty.call(
        gameState.unlocks?.causalSessionState?.npcAffections || {},
        comp.id
      );
      if (typeof npcSystem !== 'undefined' && npcSystem.affections && !hasRestoredAffection) {
        npcSystem.affections[comp.id] = Math.max(
          Number(comp.startAffection) || 0,
          inheritedAffection,
          npcAffection
        );
      }
      const restoredState = restoredProgress.states?.[comp.id];
      // 初始化道侣自有状态；不得复制 NPC 好感。已恢复字段覆盖配置初值。
      this.states[comp.id] = {
        bond: Math.max(0, Math.min(5, Number.isFinite(Number(restoredState?.bond))
          ? Math.floor(Number(restoredState.bond))
          : (Number(comp.startBond) || 0))),
        trust: Math.max(0, Math.min(100, Number.isFinite(Number(restoredState?.trust))
          ? Math.floor(Number(restoredState.trust))
          : (Number(comp.startTrust) || 0))),
        lastEventTurn: Math.max(0, Math.floor(Number(restoredState?.lastEventTurn) || 0)),
        lastCooldownTurn: Math.max(0, Math.floor(Number.isFinite(Number(restoredState?.lastCooldownTurn))
          ? Number(restoredState.lastCooldownTurn)
          : (Number(gameState.turn) || 0))),
        totalEvents: Math.max(0, Math.floor(Number(restoredState?.totalEvents) || 0)),
        personality: comp.personality || null
      };
      this._cooldowns[comp.id] = Math.max(
        0,
        Math.floor(Number(restoredProgress.cooldowns?.[comp.id]) || 0)
      );
    }
  }

  /**
   * 导出道侣自有的最小当世进度；配置派生字段与 NPC 好感不进入第二账本。
   */
  exportProgress() {
    const states = {};
    const cooldowns = {};
    for (const [compId, state] of Object.entries(this.states || {})) {
      if (!state || typeof state !== 'object') continue;
      states[compId] = {
        bond: Math.max(0, Math.min(5, Math.floor(Number(state.bond) || 0))),
        trust: Math.max(0, Math.min(100, Math.floor(Number(state.trust) || 0))),
        lastEventTurn: Math.max(0, Math.floor(Number(state.lastEventTurn) || 0)),
        lastCooldownTurn: Math.max(0, Math.floor(Number(state.lastCooldownTurn) || 0)),
        totalEvents: Math.max(0, Math.floor(Number(state.totalEvents) || 0))
      };
    }
    for (const [compId, cooldown] of Object.entries(this._cooldowns || {})) {
      cooldowns[compId] = Math.max(0, Math.floor(Number(cooldown) || 0));
    }
    return { states, cooldowns };
  }

  _persistProgress() {
    if (typeof gameState === 'undefined' || !gameState) return false;
    gameState.companionProgress = this.exportProgress();
    return typeof gameState.persistCausalSession === 'function'
      ? gameState.persistCausalSession()
      : false;
  }

  loadPortraitData(data) {
    this.portraitStages.clear();
    for (const [compId, definition] of Object.entries(data?.portraitStages || {})) {
      if (!definition || !Array.isArray(definition.stages)) continue;
      this.portraitStages.set(compId, {
        ...definition,
        stages: definition.stages
          .filter(stage => stage && typeof stage.id === 'string' && typeof stage.asset === 'string')
          .slice()
          .sort((left, right) => (Number(left.affection) || 0) - (Number(right.affection) || 0))
      });
    }
  }

  _resolvePortraitCompanionId(compId) {
    const aliases = { tian_ji: 'tianji_laoren', xue_sha: 'xuesha_laozu', jiuwei: 'jiuwei_suyue' };
    return aliases[compId] || compId;
  }

  _ensureCosmeticStore() {
    if (!gameState.unlocks) gameState.unlocks = {};
    if (!gameState.unlocks.legacy || typeof gameState.unlocks.legacy !== 'object') {
      gameState.unlocks.legacy = {};
    }
    const legacy = gameState.unlocks.legacy;
    if (!legacy.companionCosmetics || typeof legacy.companionCosmetics !== 'object') {
      legacy.companionCosmetics = {};
    }
    if (!legacy.companionCosmetics.selectedPortraitByNpc
      || typeof legacy.companionCosmetics.selectedPortraitByNpc !== 'object') {
      legacy.companionCosmetics.selectedPortraitByNpc = {};
    }
    return legacy.companionCosmetics.selectedPortraitByNpc;
  }

  _resolvePortraitAffection(compId, explicitAffection = null) {
    const resolvedId = this._resolvePortraitCompanionId(compId);
    if (typeof npcSystem !== 'undefined' && typeof npcSystem.getAffection === 'function') {
      return npcSystem.getAffection(resolvedId);
    }
    const fallback = Number(explicitAffection ?? gameState.unlocks?.legacy?.npcAffections?.[resolvedId]);
    return Number.isFinite(fallback) ? fallback : 0;
  }

  getUnlockedPortraitStages(compId, explicitAffection = null) {
    const resolvedId = this._resolvePortraitCompanionId(compId);
    const definition = this.portraitStages.get(resolvedId);
    if (!definition) return [];
    const affection = this._resolvePortraitAffection(resolvedId, explicitAffection);
    return definition.stages.filter(stage => (Number(stage.affection) || 0) <= affection);
  }

  resolveSelectedPortrait(compId, { affection = null, allowIntimate = false } = {}) {
    const resolvedId = this._resolvePortraitCompanionId(compId);
    const unlocked = this.getUnlockedPortraitStages(resolvedId, affection);
    if (!unlocked.length) return null;
    // A skin explicitly equipped by the player is distinct from an automatic
    // story-stage choice. Only unlocked, successfully persisted selections win.
    const selectedId = this._ensureCosmeticStore()[resolvedId];
    const selected = unlocked.find(stage => stage.id === selectedId);
    if (selected) return selected;
    const eligible = allowIntimate
      ? unlocked
      : unlocked.filter(stage => stage.sceneGate !== 'intimate_only');
    const pool = eligible.length ? eligible : unlocked;
    return pool[pool.length - 1] || null;
  }

  selectPortrait(compId, stageId) {
    const resolvedId = this._resolvePortraitCompanionId(compId);
    const stage = this.getUnlockedPortraitStages(resolvedId).find(item => item.id === stageId);
    if (!stage) return { selected: false, reason: 'locked_or_unknown_stage' };
    const store = this._ensureCosmeticStore();
    const hadPrevious = Object.prototype.hasOwnProperty.call(store, resolvedId);
    const previousStageId = store[resolvedId];
    store[resolvedId] = stage.id;
    const persisted = typeof gameState._saveUnlocks === 'function' ? gameState._saveUnlocks() : false;
    if (!persisted) {
      if (hadPrevious) store[resolvedId] = previousStageId;
      else delete store[resolvedId];
      return { selected: false, reason: 'persist_failed' };
    }
    if (typeof eventBus !== 'undefined') {
      eventBus.emit('companion:portraitSelected', {
        compId: resolvedId,
        stageId: stage.id,
        asset: stage.asset
      });
    }
    return { selected: true, persisted, compId: resolvedId, stage };
  }

  /**
   * 注册道侣（玩家获得道侣时调用）
   * @param {string} compId
   */
  register(compId) {
    if (!this.companions.has(compId)) {
      // 如果没加载数据，从 npcSystem 获取基础信息
      const npc = npcSystem.getNpc(compId);
      if (!npc) return false;

      this.companions.set(compId, {
        id: compId,
        name: npc.name,
        title: npc.title || '',
        personality: npc.personality || {},
        startAffection: npcSystem.affections[compId] || 30,
        events: []
      });
      this.events.set(compId, []);
    }

    if (!this.states[compId]) {
      this.states[compId] = {
        bond: 1,
        trust: 20,
        lastEventTurn: gameState.turn,
        lastCooldownTurn: gameState.turn,
        totalEvents: 0
      };
    }

    this._cooldowns[compId] = 8; // 刚结成道侣有8轮好感冷却
    this.states[compId].lastCooldownTurn = Math.max(0, Math.floor(Number(gameState.turn) || 0));

    // 【道侣加成】从 StoryNetworkSystem 获取并应用个性化加成
    this._applyBonuses(compId);

    // 【道侣弧线】注册到 StoryNetworkSystem 的 CompanionArcEngine
    if (typeof storyNetworkSystem !== 'undefined' && storyNetworkSystem.companionArcs
      && !storyNetworkSystem.companionArcs.arcStates.has(compId)) {
      storyNetworkSystem.companionArcs.registerCompanion(compId);
    }

    eventBus.emit('companion:registered', { compId, name: this._getName(compId) });
    this._persistProgress();
    return true;
  }

  /**
   * 【道侣加成】应用道侣个性化加成
   * 加成效果存储到 states[compId].bonuses，同时通过 eventBus 广播供其他系统使用
   */
  _applyBonuses(compId) {
    const bonuses = storyNetworkSystem.companionArcs.getCompanionBonuses(compId);
    if (!bonuses) return;

    // 存储加成到 state
    if (this.states[compId]) {
      this.states[compId].bonuses = bonuses;
    }

    // 广播加成应用事件
    eventBus.emit('companion:bonusesApplied', {
      compId,
      name: this._getName(compId),
      bonuses
    });
  }

  /**
   * 获取道侣加成
   * @param {string} compId
   * @returns {Object|null}
   */
  getBonuses(compId) {
    const state = this.states[compId];
    return state ? state.bonuses || null : null;
  }

  /**
   * 获取所有已绑定道侣的合并加成
   * @returns {Object}
   */
  getAllBonuses() {
    const merged = {};
    for (const compId of (gameState.resources.companions || [])) {
      if (!this._canPhysicallyAppear(compId)) continue;
      const bonuses = this.getBonuses(compId);
      if (!bonuses || !bonuses.effects) continue;
      for (const [key, val] of Object.entries(bonuses.effects)) {
        merged[key] = (merged[key] || 0) + val;
      }
    }
    return merged;
  }

  /**
   * 返回玩家当前已拥有道侣的最高阶战斗契约。
   * 好感度只读取 NpcSystem；配置只声明阈值和卡牌，不保存第二份解锁状态。
   */
  getUnlockedCombatContracts() {
    const owned = (typeof gameState !== 'undefined' && gameState?.resources?.companions) || [];
    const unlocked = [];
    for (const compId of owned) {
      if (!this._canPhysicallyAppear(compId)) continue;
      const companion = this.companions.get(compId);
      const state = this.states[compId];
      const affection = this._resolvePortraitAffection(compId);
      const contract = companion?.combatContract;
      if (!state || !contract || !Array.isArray(contract.tiers)) continue;
      const tier = contract.tiers
        .filter(item => affection >= (Number(item.minAffection) || 0))
        .sort((a, b) => (Number(b.minAffection) || 0) - (Number(a.minAffection) || 0))[0];
      if (!tier?.cardId) continue;
      const selectedPortrait = this.resolveSelectedPortrait(compId, {
        affection,
        allowIntimate: false
      });
      unlocked.push({
        compId,
        companionName: companion.name || compId,
        affection,
        mechanismId: contract.mechanismId || null,
        mechanism: contract.mechanism || '',
        tierId: tier.id || null,
        minAffection: Number(tier.minAffection) || 0,
        unlockText: tier.unlockText || '',
        cardId: tier.cardId,
        cardArt: selectedPortrait?.asset
          ? {
              id: `companion_portrait_${compId}_${selectedPortrait.id}`,
              image: selectedPortrait.asset,
              portraitStageId: selectedPortrait.id
            }
          : tier.cardArt || null
      });
    }
    return unlocked;
  }

  // ==========================================
  // 事件调度（优先级50，由 CardSystem 调用）
  // ==========================================

  _onCheckEvent() {
    // 【P1 #9 修复】最高优先：先消费里程碑队列（避免与 CardSystem 抽卡时序对撞丢失）
    if (this._pendingMilestones && this._pendingMilestones.length > 0) {
      while (this._pendingMilestones.length > 0) {
        const milestone = this._pendingMilestones.shift();
        const ownerId = milestone?.card?.compId || milestone?.card?.npcId;
        if (ownerId && !this._canPhysicallyAppear(ownerId)) continue;
        eventBus.emit('companion:eventCard', { card: milestone.card, priority: milestone.priority });
        return;
      }
    }

    // 优先：危机事件（flag 驱动）
    if (this._pendingCrisis) {
      const crisis = this._pendingCrisis;
      this._pendingCrisis = null;
      if (!this._canPhysicallyAppear(crisis.compId)) {
        eventBus.emit('companion:eventCard', { card: null, priority: 55 });
        return;
      }
      const card = this._buildEventCard(crisis.compId, crisis.event);
      if (this._isNarrativeEligible(card)) {
        eventBus.emit('companion:eventCard', { card, priority: 55 });
        return;
      }
    }

    let progressChanged = false;

    // 检查所有道侣
    for (const compId of gameState.resources.companions) {
      if (!this.companions.has(compId)) continue;
      if (!this._canPhysicallyAppear(compId)) continue;
      if (this._cooldowns[compId] > 0) {
        const state = this.states[compId];
        const currentTurn = Math.max(0, Math.floor(Number(gameState.turn) || 0));
        if (state && Number(state.lastCooldownTurn) !== currentTurn) {
          this._cooldowns[compId]--;
          state.lastCooldownTurn = currentTurn;
          progressChanged = true;
        }
        continue;
      }

      const state = this.states[compId];
      if (!state) continue;

      // 计算触发概率
      const chance = this._calcEventChance(compId, state);
      if (Math.random() > chance) continue;

      // 候选池先做语义准入，再进行一次选择；耗尽必须返回 null。
      const event = this._pickEvent(compId, state);
      const card = event ? this._buildEventCard(compId, event) : null;
      if (!this._isNarrativeEligible(card)) continue;

      // 发送给 CardSystem
      this._cooldowns[compId] = 10;
      state.lastEventTurn = gameState.turn;
      state.lastCooldownTurn = Math.max(0, Math.floor(Number(gameState.turn) || 0));
      state.totalEvents++;
      progressChanged = true;

      this._persistProgress();
      eventBus.emit('companion:eventCard', { card, priority: 50 });
      return;
    }

    if (progressChanged) this._persistProgress();
    eventBus.emit('companion:eventCard', { card: null, priority: 50 });
  }

  /**
   * 事件触发概率计算
   * 【环环相扣：Faction→Companion】势力声望影响道侣事件概率
   */
  _calcEventChance(compId, state) {
    const baseChance = 0.15;
    const affMod = (this._resolvePortraitAffection(compId) / 100) * 0.10;  // 好感修正
    const bondMod = state.bond * 0.03;                // 羁绊修正
    const multiPenalty = (gameState.resources.companions.length - 1) * (-0.05); // 多道侣惩罚

    // 【Faction→Companion】道侣所在势力的声望影响事件概率
    let factionMod = 0;
    const comp = this.companions.get(compId);
    if (comp && comp.factionId && typeof factionSystem !== 'undefined') {
      const rep = factionSystem.reputations[comp.factionId] || 0;
      // 声望+100时提升10%，声望-100时降低10%
      factionMod = (rep / 100) * 0.10;
    }

    return Math.min(baseChance + affMod + bondMod + multiPenalty + factionMod, 0.35);
  }

  /**
   * 从事件池中选取匹配事件
   */
  _pickEvent(compId, state) {
    const pool = this.events.get(compId) || [];
    if (pool.length === 0) {
      // 没有定义的事件，使用通用事件
      return this._getGenericEvent(compId, state);
    }

    const affection = this._resolvePortraitAffection(compId);
    const candidates = pool.filter(ev => {
      if (ev.minAffection && affection < ev.minAffection) return false;
      if (ev.minBond && state.bond < ev.minBond) return false;
      if (ev.realm && gameState.realm !== ev.realm) return false;
      if (ev.requiredFlag && !gameState.hasFlag(ev.requiredFlag)) return false;
      if (ev.forbiddenFlag && gameState.hasFlag(ev.forbiddenFlag)) return false;
      if (ev.once && state.totalEvents > 0) {
        // 一次性事件跳过（检查是否已触发）
        const triggered = gameState.getFlag('comp_' + compId + '_event_' + ev.id, false);
        if (triggered) return false;
      }
      if (!this._isNarrativeEligible(this._buildEventCard(compId, ev))) return false;
      return true;
    });

    // A defined authored pool is authoritative. If every authored beat is
    // resolved or condition-blocked, fail closed instead of masking exhaustion
    // with an unrelated generic opener.
    if (candidates.length === 0) return null;

    // 按类型权重排序
    const daily = candidates.filter(e => e.type === 'daily');
    const emotional = candidates.filter(e => e.type === 'emotional');
    const crisis = candidates.filter(e => e.type === 'crisis');

    // 优先日常(70%) > 情感(25%) > 危机(5%)
    const roll = Math.random();
    if (roll < 0.05 && crisis.length > 0) return crisis[Math.floor(Math.random() * crisis.length)];
    if (roll < 0.30 && emotional.length > 0) return emotional[Math.floor(Math.random() * emotional.length)];
    if (daily.length > 0) return daily[Math.floor(Math.random() * daily.length)];

    return candidates[Math.floor(Math.random() * candidates.length)];
  }

  /**
   * 通用道侣事件（没有定义事件池时）
   */
  _getGenericEvent(compId, state) {
    const pool = [{
      type: 'daily', id: 'generic_daily',
      once: false, repeatPolicy: { mode: 'cooldown', cooldownTurns: 12 },
      title: '日常陪伴', desc: '道侣为你端来一杯热茶，轻声问起今日修行如何。',
      choices: {
        left: { text: '分享修行心得', affection: 5, effects: { cultivation: 3, daoHeart: 2 } },
        right: { text: '静静品茶', affection: 3, effects: { daoHeart: 5 } }
      }
    }, {
      type: 'emotional', id: 'generic_emo',
      once: false, repeatPolicy: { mode: 'cooldown', cooldownTurns: 12 },
      title: '月下谈心', desc: '月华如练，道侣与你并肩而坐。星河之下，人间万事都显得渺小。',
      choices: {
        left: { text: '倾诉心声', affection: 8, effects: { daoHeart: 5, fortune: 3 } },
        right: { text: '静默相伴', affection: 5, effects: { daoHeart: 8 } }
      }
    }, {
      type: 'daily', id: 'generic_help',
      once: false, repeatPolicy: { mode: 'cooldown', cooldownTurns: 12 },
      title: '修行相助', desc: '道侣递来一枚丹药："这是我闭关三日炼成的，你试试。"',
      choices: {
        left: { text: '感激收下', affection: 6, effects: { cultivation: 10, health: 5 } },
        right: { text: '婉拒', affection: -2, effects: { daoHeart: 3 } }
      }
    }];
    const eligible = pool.filter(event => this._isNarrativeEligible(this._buildEventCard(compId, event)));
    if (eligible.length === 0) return null;
    return eligible[Math.floor(Math.random() * eligible.length)];
  }

  // ==========================================
  // 事件卡牌构建
  // ==========================================

  _buildEventCard(compId, event) {
    const name = this._getName(compId);
    const state = this.states[compId];

    return {
      id: `comp_${compId}_${event.id || 'generic'}`,
      semanticKey: event.semanticKey || `companion:${compId}:event:${event.id || 'generic'}`,
      title: event.title || '道侣',
      description: (event.desc || '').replace('{name}', name),
      type: 'COMPANION_EVENT',
      realm: gameState.realm,
      compId: compId,
      compEvent: event,
      ...(event.sceneImage ? { sceneImage: event.sceneImage } : {}),
      ...(event.artDirection ? { artDirection: { ...event.artDirection } } : {}),
      weight: 0,
      once: event.once !== false,
      repeatPolicy: event.repeatPolicy || null,
      choices: this._fmtChoices(event.choices, compId)
    };
  }

  _fmtChoices(choices, compId) {
    const result = {};
    for (const [dir, ch] of Object.entries(choices)) {
      const encounterChoice = ch.encounterId
        ? this.resolveEncounterChoice(ch.encounterId)
        : null;
      result[dir] = {
        text: ch.text || '...',
        effects: ch.effects || {},
        companionEffects: {
          compId,
          affectionDelta: ch.affection || 0,
          bondDelta: ch.bondDelta || 0,
          trustDelta: ch.trustDelta || 0
        },
        ...(encounterChoice || {})
      };
    }
    return result;
  }

  /**
   * 把遭遇目录记录解析为 CardSystem 可消费的选项战斗契约。
   * 遭遇目录是敌人、画面、奖励和结果联动的唯一来源。
   */
  resolveEncounterChoice(encounterId) {
    if (typeof cardSystem !== 'undefined' && cardSystem &&
        typeof cardSystem.resolveCombatEncounterChoice === 'function') {
      return cardSystem.resolveCombatEncounterChoice(encounterId);
    }
    if (!encounterId || typeof dataLoader === 'undefined' || !dataLoader) return null;
    const catalog = dataLoader.loadSync('combat:encounters');
    const encounter = catalog?.encounters?.find(item => item.id === encounterId);
    if (!encounter) return null;
    const clone = value => value === undefined ? undefined : JSON.parse(JSON.stringify(value));
    return {
      encounterId: encounter.id,
      triggerCombat: true,
      enemy: clone(encounter.enemy),
      battlefield: encounter.combatPresentation?.battlefield || encounter.battlefield || null,
      combatPresentation: clone(encounter.combatPresentation || {}),
      victoryEffects: clone(encounter.victoryEffects || {}),
      combatRewards: clone(encounter.victoryEffects || {}),
      combatOutcomeLinks: clone(encounter.outcomeLinks || {}),
      karmaSeed: clone(encounter.karmaSeed),
      karmaSeedOn: clone(encounter.karmaSeedOn)
    };
  }

  // ==========================================
  // 道侣选择结果应用
  // ==========================================

  /**
   * 玩家做出道侣事件选择后调用
   * @param {Object} choice - 包含 companionEffects
   */
  applyChoice(choice) {
    if (!choice || !choice.companionEffects) return;

    const ce = choice.companionEffects;
    if (!ce.compId) return;

    const state = this.states[ce.compId];
    if (!state) return;

    // 保存旧值用于阈值检测
    const oldAffection = npcSystem.getAffection(ce.compId);

    // 羁绊变化
    if (ce.bondDelta) {
      state.bond = Math.max(0, Math.min(5, state.bond + ce.bondDelta));
    }

    // 信任变化
    if (ce.trustDelta) {
      state.trust = Math.max(0, Math.min(100, state.trust + ce.trustDelta));
    }

    // 同步到 NPC 系统
    if (ce.affectionDelta) {
      npcSystem.addAffection(ce.compId, ce.affectionDelta);
    }
    const newAffection = npcSystem.getAffection(ce.compId);

    // 【因果种子】companionSacrifice：道侣好感大幅下降（背叛/牺牲）→ 种下因果
    if (ce.affectionDelta && ce.affectionDelta <= -20) {
      if (typeof karmaSystem !== 'undefined' && karmaSystem) {
        const comp = this.companions.get(ce.compId);
        karmaSystem.plantSeed({
          id: 'companionSacrifice',
          description: `${comp ? comp.name : ce.compId}与你之间的关系发生了剧烈变化。`,
          originCard: `comp_${ce.compId}`,
          magnitude: Math.abs(ce.affectionDelta)
        });
      }
    }

    // 【因果种子】companionTrust：道侣信任大幅提升 → 种下善因
    if (ce.trustDelta && ce.trustDelta >= 20) {
      if (typeof karmaSystem !== 'undefined' && karmaSystem) {
        const comp = this.companions.get(ce.compId);
        karmaSystem.plantSeed({
          id: 'companionTrust',
          description: `${comp ? comp.name : ce.compId}深深信任了你——这份信任会在关键时刻成为你的倚仗。`,
          originCard: `comp_${ce.compId}`,
          magnitude: ce.trustDelta
        });
      }
    }

    // 【P1-3】好感阈值跨越 → 触发里程碑事件卡
    this._checkAffectionMilestones(ce.compId, state, oldAffection, newAffection);

    eventBus.emit('companion:stateChanged', {
      compId: ce.compId,
      affection: newAffection,
      bond: state.bond,
      trust: state.trust
    });
    this._persistProgress();
  }

  // ==========================================
  // 道侣面板数据
  // ==========================================

  _onGetPanelData(data) {
    const compId = data.compId;
    const comp = this.companions.get(compId);
    const state = this.states[compId];

    if (!comp || !state) {
      eventBus.emit('companion:panelData', { error: '道侣不存在' });
      return;
    }

    // 从 npcSystem 获取当前情绪
    const emotion = npcSystem.getEmotion(compId);
    const lifecycleState = typeof worldContinuityStore !== 'undefined'
      ? worldContinuityStore.getNpcState(compId)
      : null;
    const canInteract = this._canPhysicallyAppear(compId);
    const location = canInteract
      ? npcSystem.getCurrentSchedule(compId)
      : (lifecycleState?.locationId || '因果之外');

    // 事件历史（最近5条）
    const npcMem = npcSystem.memories[compId] || [];
    const recentEvents = npcMem.slice(-5);

    eventBus.emit('companion:panelData', {
      id: compId,
      name: comp.name,
      title: comp.title || '',
      personality: comp.personality || {},
      emotion,
      location,
      affection: npcSystem.getAffection(compId),
      bond: state.bond,
      trust: state.trust,
      totalEvents: state.totalEvents,
      recentEvents,
      isCompanion: true,
      lifecycle: lifecycleState?.lifecycle || 'ACTIVE',
      manifestation: lifecycleState?.manifestation || 'PHYSICAL',
      canInteract
    });
  }

  // ==========================================
  // 赠予（道侣专用）
  // ==========================================

  _onGift(data) {
    const { compId, itemId } = data;
    const state = this.states[compId];
    if (!state) return;
    if (!this._canPhysicallyAppear(compId)) {
      eventBus.emit('companion:giftResult', {
        compId,
        itemId,
        success: false,
        reason: 'physical_presence_unavailable',
        delta: 0,
        reaction: '此人当前不能以实体接受礼物。'
      });
      return;
    }

    const result = npcSystem.interact({ npcId: compId, action: '赠礼', itemId, emitResult: false });

    eventBus.emit('companion:giftResult', {
      compId,
      itemId,
      success: Boolean(result?.success),
      reason: result?.reason || null,
      delta: result?.affDelta || 0,
      reaction: result?.reaction || '本次赠礼没有结算。'
    });
  }

  // ==========================================
  // 情劫与危机事件
  // ==========================================

  _onHeartEvent(data) {
    // 设置待触发的危机事件
    this._pendingCrisis = {
      compId: data.compId,
      event: data.event
    };
  }

  /**
   * 检查是否触发情劫（境界突破时调用）
   */
  checkTribulation(compId) {
    const state = this.states[compId];
    if (!state) return null;

    // 金丹期 + 羁绊≥3 → 可能触发情劫
    if (gameState.realm === 'golden' && state.bond >= 3 && Math.random() < 0.3) {
      const comp = this.companions.get(compId);
      return {
        type: 'tribulation',
        compId,
        name: comp ? comp.name : compId,
        title: '情劫降临',
        desc: `天道降下情劫——你与${comp ? comp.name : compId}的关系，必须接受天道考验。`,
        choices: {
          left: { text: '携手渡劫', effects: { daoHeart: -2, health: -2 }, affection: 20, bondDelta: 1 },
          right: { text: '独自面对', effects: { daoHeart: -1 }, affection: -30, bondDelta: -1 }
        }
      };
    }
    return null;
  }

  /**
   * 【P1-3】好感度阈值里程碑检测
   * 当好感度跨越关键阈值时，触发一次性的里程碑事件卡
   *
   * 阈值体系：
   *   20  — 初识 (首次认真交流)
   *   50  — 信赖 (开始分享秘密)
   *   80  — 深交 (将对方视为重要之人)
   *   100 — 至交/道侣 (终极羁绊)
   *  -20  — 厌恶 (关系破裂警告)
   */
  _checkAffectionMilestones(compId, state, oldAffection, newAffection = this._resolvePortraitAffection(compId)) {
    const milestones = [
      { threshold: 100, milestoneId: 'bond_ultimate', seedType: 'bloodline', direction: 'up', payoffEvent: 'kx_companion_bond_ultimate' },
      { threshold: 80,  milestoneId: 'bond_deep',     seedType: 'bloodline', direction: 'up', payoffEvent: 'kx_companion_bond_deep' },
      { threshold: 50,  milestoneId: 'bond_trust',    seedType: 'karma',     direction: 'up', payoffEvent: 'kx_companion_bond_trust' },
      { threshold: 20,  milestoneId: 'bond_acquaint', seedType: 'karma',     direction: 'up', payoffEvent: 'kx_companion_bond_acquaint' },
      { threshold: -20, milestoneId: 'bond_hostile',  seedType: 'grudge',    direction: 'down', payoffEvent: 'kx_companion_bond_hostile' }
    ];

    for (const ms of milestones) {
      // 正向里程碑向上跨阈值；关系破裂必须向下跨过 -20，不能在和解时误触发。
      const crossed = ms.direction === 'down'
        ? oldAffection > ms.threshold && newAffection <= ms.threshold
        : oldAffection < ms.threshold && newAffection >= ms.threshold;
      if (crossed) {
        const comp = this.companions.get(compId);
        const name = comp ? comp.name : compId;
        const flagKey = `comp_milestone_${compId}_${ms.milestoneId}`;

        // 每个里程碑只触发一次
        if (gameState.hasFlag(flagKey)) continue;

        gameState.setFlag(flagKey, gameState.turn);

        // 【P1 #9 修复】入队而非直接 emit，等 CardSystem 抽卡时再取（避免时序对撞丢失）
        const card = this._buildMilestoneCard(compId, name, ms, { ...state, affection: newAffection });
        if (card) {
          this._pendingMilestones.push({ card, priority: 52 });
        }

        // 种下因果种子
        if (typeof karmaSystem !== 'undefined' && karmaSystem) {
          karmaSystem.plantSeed({
            id: `companion_milestone_${compId}_${ms.milestoneId}`,
            seedType: ms.seedType,
            delay: ms.threshold >= 80 ? 3 : 8,
            priority: ms.threshold >= 80 ? 7 : 4,
            originCard: `comp_${compId}_milestone`,
            payoffEvent: ms.payoffEvent,
            context: {
              companionId: compId,
              companionName: name,
              milestoneId: ms.milestoneId
            }
          });
        }

        // 一个choice只触发一个里程碑
        return;
      }
    }
  }

  /**
   * 构建里程碑事件卡
   */
  _buildMilestoneCard(compId, name, milestone, state) {
    const milestoneData = {
      bond_ultimate: {
        title: `${name}·天命之约`,
        desc: `${name}站在你面前，眼中映着星河。\\n\\n"我活了很久——久到以为不会再有'舍不得'这种情绪。"\\n\\nta握住了你的手——那温度不像修士该有的冰冷，像凡人的、温热的、赤裸的。\\n\\n"直到你来了。"`,
        leftText: `"此生不负"`,
        leftEffects: { daoHeart: 3, fortune: 3, cultivation: 3 },
        leftAffection: 0,
        rightText: `沉默——但紧紧回握`,
        rightEffects: { daoHeart: 2, fortune: 2 },
        rightAffection: 5
      },
      bond_deep: {
        title: `${name}·深交`,
        desc: `${name}忽然问了一个ta从未问过的问题："如果有一天……你修成了大道，还会记得苍茫界的这些人吗？"\\n\\nta说这话时没有看你——而是看着很远的地方。`,
        leftText: `"大道若无人——不是我要的道"`,
        leftEffects: { daoHeart: 2, karmaGood: 2, fortune: 1 },
        leftAffection: 10,
        rightText: `"我会记得你"`,
        rightEffects: { daoHeart: 1, fortune: 1 },
        rightAffection: 15
      },
      bond_trust: {
        title: `${name}·推心置腹`,
        desc: `${name}犹豫了很久，终于对你说了一件事——一件ta从未对任何人说过的事。\\n\\n不是秘密，是伤疤。`,
        leftText: `认真倾听——不打断`,
        leftEffects: { daoHeart: 15, fortune: 5, karmaGood: 5 },
        leftAffection: 12,
        rightText: `也分享一件自己的心事`,
        rightEffects: { daoHeart: 10, cultivation: 5 },
        rightAffection: 8
      },
      bond_acquaint: {
        title: `${name}·初见`,
        desc: `${name}不再是'那个NPC'了——今天的交谈中，ta露出了一个你自己都没注意到的细节。\\n\\n你开始认真看这个人了。`,
        leftText: `主动了解ta的过往`,
        leftEffects: { daoHeart: 5, fortune: 5 },
        leftAffection: 10,
        rightText: `保持距离——慢慢来`,
        rightEffects: { daoHeart: 3 },
        rightAffection: 5
      },
      bond_hostile: {
        title: `${name}·裂痕`,
        desc: `你感到${name}看你的眼神变了——多了一层疏离。\\n\\nta还站在你面前，但你们之间的空气已经不一样了。`,
        leftText: `问ta："怎么了？"`,
        leftEffects: { daoHeart: 5, fortune: -5 },
        leftAffection: 5,
        rightText: `给ta空间`,
        rightEffects: { daoHeart: 3 },
        rightAffection: 3
      }
    };

    const data = milestoneData[milestone.milestoneId];
    if (!data) return null;

    return {
      id: `comp_${compId}_milestone_${milestone.milestoneId}`,
      title: data.title,
      description: data.desc,
      type: 'COMPANION_MILESTONE',
      realm: gameState.realm,
      compId: compId,
      once: true,
      weight: 0,
      tags: ['companion', 'milestone', milestone.milestoneId],
      choices: {
        left: {
          text: data.leftText,
          effects: data.leftEffects,
          companionEffects: {
            compId,
            affectionDelta: data.leftAffection,
            bondDelta: milestone.threshold >= 80 ? 1 : 0,
            trustDelta: milestone.threshold >= 50 ? 10 : 5
          }
        },
        right: {
          text: data.rightText,
          effects: data.rightEffects,
          companionEffects: {
            compId,
            affectionDelta: data.rightAffection,
            bondDelta: 0,
            trustDelta: 5
          }
        }
      }
    };
  }

  // ==========================================
  // 工具方法
  // ==========================================

  _getName(compId) {
    const comp = this.companions.get(compId);
    if (comp) return comp.name;
    return npcSystem.getNpcName(compId);
  }

  getState(compId) {
    const state = this.states[compId];
    return state ? { ...state, affection: this._resolvePortraitAffection(compId) } : null;
  }

  getAllCompanions() {
    return gameState.resources.companions.map(id => ({
      id,
      name: this._getName(id),
      state: this.getState(id),
      data: this.companions.get(id)
    }));
  }

  /**
   * 获得羁绊等级名称
   */
  getBondName(level) {
    const names = ['陌路', '相识', '挚友', '知己', '生死', '天命'];
    return names[level] || '未知';
  }
}

// 全局单例
const companionSystem = new CompanionSystem();

if (typeof module !== 'undefined' && module.exports) {
  module.exports = CompanionSystem;
}
