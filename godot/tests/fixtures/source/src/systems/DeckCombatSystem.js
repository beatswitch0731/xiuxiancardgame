/**
 * DeckCombatSystem - 杀戮尖塔式微数值打牌战斗引擎
 */
class DeckCombatSystem {
  constructor(deps = {}) {
    this._now = typeof deps.now === 'function' ? deps.now : () => Date.now();
    this._schedule = typeof deps.schedule === 'function' ? deps.schedule : (handler, delay) => setTimeout(handler, delay);
    this._cancelSchedule = typeof deps.cancelSchedule === 'function' ? deps.cancelSchedule : handle => clearTimeout(handle);
    this.active = false;
    this.phase = 'IDLE';
    this.turn = 0;

    // 战斗实体
    this.player = null;
    this.enemy = null;
    this.preCombatHealth = 0;

    // 微数值资源
    this.qi = 0;
    this.maxQi = 3; // 初始 3 点真元

    // 卡组状态
    this.masterDeck = []; // 玩家实际拥有的永久卡组
    this.drawPile = [];
    this.hand = [];
    this.discardPile = [];
    this.exhaustPile = [];

    // 状态层数 (如：剑意、罡气、冰寒)
    this.playerStatus = {};
    this.enemyStatus = {};
    this._playerStatusesAppliedByEnemy = new Set();

    this.enemyIntent = null;
    this.pendingReaction = null;
    this._reactionSequence = 0;
    this._reactionTimer = null;
    this._settledReactionWindows = new Set();
    this._nextTurnDrawPenalty = 0;
    this.bossPhases = [];
    this.bossPhaseIndex = 0;
    this.encounterContext = null;
    this.resolutionContext = null;
    this._cardSynergy = null;
    this._pendingPathSynergyReceipt = null;
    this._pathPresentationData = { paths: {} };
    this._visualWorldData = { worlds: {} };
    this._carrierScaleProvenance = { contractId: null, records: {} };
    this._actionScaleProvenance = { contractId: null, records: {} };
    this._protagonistVisualIdentity = null;
    this._actionPresentationData = { paths: {}, encounters: {}, timelines: {}, sfxCues: {}, bossPhaseTransitions: {} };
    this._activeSemanticAction = null;
    this._semanticActionSequence = 0;
    // Sidecar presentation actions (reaction / hurt) must never replace the
    // authoritative actor action that is currently resolving. Keep their
    // timers separately so a reset or reload cannot leave a late UI event.
    this._presentationActionSequence = 0;
    this._presentationActionTimers = new Set();
    this._victorySettlementTimer = null;
    this._victorySettlementToken = 0;
    this._terminalHideTimer = null;
    this._terminalHideToken = 0;
    // Battle effects settle synchronously, while their authored presentation
    // remains visible. Guard the real input boundary during that window so a
    // double-click cannot hit the card that reflows under the first click.
    this._playerInputLockUntil = 0;
    this._playerInputUnlockTimer = null;
    this._visiblePlayerActionIds = new Set();
    this._companionCombatContracts = [];
    this.deckAuthority = null;
    this.equipmentState = {};
    this._authorityLedger = [];
    this._authorityChain = 'dc2-root';

    // 日志
    this.log = [];
  }

  init() {
    // 绑定事件
    eventBus.on('combat:start', (data) => this._start(data));
    eventBus.on('state:reset', () => this.reset());
    eventBus.on('combat:visualActionMounted', ({ actionId } = {}) => {
      if (actionId && this.active) this._visiblePlayerActionIds.add(String(actionId));
    });
    eventBus.on('combat:visualActionUnmounted', ({ actionId } = {}) => {
      if (!this._visiblePlayerActionIds.delete(String(actionId || ''))) return;
      if (this.active && this.phase === 'PLAYER_TURN' && !this.isPlayerInputLocked()) {
        this._triggerUpdate();
        eventBus.emit('combat:inputUnlocked', { actionId, source: 'player', visualLifecycleCompleted: true });
      }
    });
  }

  reset() {
    this._clearReactionTimer();
    this._clearPlayerInputLockTimer();
    this.active = false;
    this.phase = 'IDLE';
    this._endPathArchetypeBattle();
    this.player = null;
    this.enemy = null;
    this.preCombatHealth = 0;
    this.turn = 0;
    this.masterDeck = [];
    this.drawPile = [];
    this.hand = [];
    this.discardPile = [];
    this.exhaustPile = [];
    this.playerStatus = {};
    this.enemyStatus = {};
    this._playerStatusesAppliedByEnemy = new Set();
    this.enemyIntent = null;
    this.pendingReaction = null;
    this._reactionSequence = 0;
    this._settledReactionWindows = new Set();
    this._nextTurnDrawPenalty = 0;
    this.bossPhases = [];
    this.bossPhaseIndex = 0;
    this.encounterContext = null;
    this.resolutionContext = null;
    this._cardSynergy = null;
    this._pendingPathSynergyReceipt = null;
    this._activeSemanticAction = null;
    this._semanticActionSequence = 0;
    this._clearPresentationActionTimers();
    this._presentationActionSequence = 0;
    this._clearVictorySettlement();
    this._clearTerminalCombatHide();
    this._playerInputLockUntil = 0;
    this._visiblePlayerActionIds.clear();
    this._companionCombatContracts = [];
    this._authorityLedger = [];
    this._authorityChain = 'dc2-root';
    this.log = [];
    this.equipmentState = {}; // Record state for equipment passives
  }

  _addLog(msg) {
    this.log.unshift(msg);
    if (this.log.length > 10) this.log.pop();
  }

  _maxQiForRealm(realm) {
    const realmOrder = ['mortal', 'qi', 'foundation', 'golden', 'nascent', 'deity', 'tribulation', 'ascension'];
    let realmIndex = realmOrder.indexOf(realm);
    if (realmIndex < 0) realmIndex = 1;
    return Math.min(8, 2 + realmIndex);
  }

  _combatVitalityBudget(realm = null, pathId = null) {
    const state = typeof gameState !== 'undefined' ? gameState : null;
    const resolvedRealm = realm || state?.realm || 'qi';
    const resolvedPath = pathId || state?.path || 'sword';
    const pathDefinition = state?.config?.paths?.paths?.[resolvedPath];
    // Isolated compatibility fixtures and legacy embedders without the
    // production path contract retain their authored max health. The browser
    // runtime always loads config:paths before combat starts.
    if (!pathDefinition) return null;
    const realmOrder = ['qi', 'foundation', 'golden', 'nascent', 'deity', 'tribulation', 'ascension'];
    const realmIndex = Math.max(0, realmOrder.indexOf(resolvedRealm));
    // Deck combat uses a separate micro-number vitality track. Persistent
    // max-health growth still governs world injuries and provides the ceiling,
    // while only a bounded part of the path's starting health identity enters
    // combat. This prevents legacy world-scale bonuses from turning 7–20 HP
    // enemies into harmless props.
    // Persistent body-cultivator health still raises the world-health ceiling,
    // but granting the same bonus again inside the separate six-point combat
    // vitality track double-counted that identity and split otherwise equal
    // encounters by several whole HP. Deck combat therefore owns one shared
    // micro-vitality curve; path identity comes from cards, archetypes,
    // reactions and block retention instead of duplicating world attributes.
    // Sword remains the tempo-forward path through its card rules, but one
    // less local vitality than every other starting path made the first
    // authored teaching encounter depend on opening-hand luck rather than the
    // guard→recovery rhythm it is meant to teach.
    const pathOffset = resolvedPath === 'sword' ? -1 : (
      ['spell', 'pill', 'body'].includes(resolvedPath) ? -1 : 0
    );
    return Math.max(3, Math.min(12, 5 + realmIndex + pathOffset));
  }

  _retainedBlockCap(player = this.player) {
    // Retention is a tempo identity, not permanent armour. Keeping this cap in
    // the micro-number domain prevents aura/body builds from accumulating an
    // unreachable shield over long combats while still preserving a setup.
    const maxHp = Math.max(1, Math.floor(Number(player?.maxHp) || 1));
    return Math.min(1, maxHp);
  }

  _buildPlayerAuthority() {
    let atkMod = 0;
    let defMod = 0;
    let critRate = 0;
    if (typeof treasureSystem !== 'undefined' && treasureSystem) {
      const modifiers = treasureSystem.getCombatModifiers();
      atkMod = modifiers.atk || 0;
      defMod = modifiers.def || 0;
      critRate = modifiers.critRate || 0;
    }
    if (typeof pathSkillSystem !== 'undefined' && pathSkillSystem && gameState.path) {
      const skillBonuses = pathSkillSystem.getPassiveBonuses(gameState.path);
      atkMod += skillBonuses.atk || 0;
      defMod += skillBonuses.def || 0;
      critRate += skillBonuses.critRate || 0;
    }
    if (typeof companionSystem !== 'undefined' && companionSystem) {
      const companionBonuses = companionSystem.getAllBonuses();
      if (companionBonuses) {
        atkMod += companionBonuses.atk || 0;
        defMod += companionBonuses.def || 0;
        critRate += companionBonuses.critRate || 0;
      }
    }
    const storyMods = gameState.modifiers || {};
    const storyAtk = (storyMods.swordAtk || 0) + (storyMods.spellPower || 0)
      + (storyMods.iceAtk || 0) + (storyMods.rawPower || 0) + (storyMods.heavenEnemyDamage || 0);
    atkMod += Math.min(5, Math.floor(storyAtk / 20));
    defMod += Math.min(3, Math.floor((storyMods.damageReduction || 0) / 20));
    critRate += Math.min(20, (storyMods.combat_skill || 0) * 5);
    const aggregated = gameState._getAggregatedPassives ? gameState._getAggregatedPassives() : {};
    const legacyPassives = typeof legacyFragmentSystem !== 'undefined' && legacyFragmentSystem
      ? legacyFragmentSystem.getPassiveBonuses()
      : {};
    critRate += legacyPassives.critRate || 0;
    const persistentHealth = Number(gameState.attributes.health) || 1;
    const persistentMaxHealth = (typeof gameState.getActualMaxHealth === 'function'
      ? gameState.getActualMaxHealth()
      : gameState.maxHealth) || persistentHealth || 1;
    const combatVitalityBudget = this._combatVitalityBudget(gameState.realm, gameState.path);
    const combatVitality = Math.max(1, Number.isFinite(combatVitalityBudget)
      ? combatVitalityBudget
      : persistentMaxHealth);
    const healthRatio = Math.max(0, Math.min(1, persistentHealth / Math.max(1, persistentMaxHealth)));
    // World injuries influence the next fight without collapsing the separate
    // combat-vitality resource into a one-to-one copy. A 35% local baseline
    // prevents one bad world event from predetermining the next elite/Boss
    // outcome; the remaining 65% still carries persistent attrition forward.
    const mappedHealthRatio = 0.35 + (healthRatio * 0.65);
    const combatStartVitality = Math.max(1, Math.min(
      combatVitality,
      Math.ceil(combatVitality * mappedHealthRatio)
    ));
    const pathDefinition = gameState.config?.paths?.paths?.[gameState.path] || {};
    const pathOpeningBlock = Math.max(0, Math.floor(Number(pathDefinition.bonuses?.combatOpeningBlock) || 0));
    return {
      preCombatHealth: persistentHealth,
      combatStartBlock: Math.max(0, Math.floor(Number(legacyPassives.combatStartBlock) || 0) + pathOpeningBlock),
      player: {
        hp: combatStartVitality,
        maxHp: combatVitality,
        block: 0,
        aura: Math.max(0, Number(gameState.getAttribute?.('aura')) || 0),
        atkMod,
        defMod,
        critRate,
        daoHeart: gameState.attributes.daoHeart || 0,
        realm: gameState.realm,
        lowHpAtkBonus: aggregated.lowHpAtkBonus || 0,
        lowHpDamageBonus: legacyPassives.lowHpDamageBonus || 0,
        pillBonus: legacyPassives.pillBonus || 0
      }
    };
  }

  /**
   * 开始战斗
   */
  async _start(data) {
    const card = data.card;
    if (!card || !card.enemy) return;
    this._clearPlayerInputLockTimer();
    this._playerInputLockUntil = 0;
    this._visiblePlayerActionIds.clear();
    this.originalCard = card;
    this.encounterContext = data.encounterContext || card.encounterContext || null;
    this.resolutionContext = data.resolutionContext
      ? JSON.parse(JSON.stringify(data.resolutionContext))
      : null;


    // 战斗卡与玩家流派展示契约共享同一次开战加载时序。
    // 遭遇负责敌人/战场/FX，流派契约负责玩家角色卡、UI 与本流派功法画面。
    const [cardData, pathPresentationData, actionPresentationData, protagonistVisualIdentity,
      visualWorldData, carrierScaleProvenance, actionScaleProvenance] = await Promise.all([
      dataLoader.load('cards:battle_cards'),
      dataLoader.load('combat:path_presentations'),
      dataLoader.load('combat:action_presentations'),
      dataLoader.load('combat:protagonist_visual_identity'),
      dataLoader.load('combat:visual_worlds'),
      dataLoader.load('combat:carrier_scale_provenance'),
      dataLoader.load('combat:action_scale_provenance')
    ]);
    if (!cardData || !cardData.battle_cards) {
       console.error("战斗卡牌数据未加载");
       return;
    }
    this._pathPresentationData = pathPresentationData && pathPresentationData.paths
      ? pathPresentationData
      : { paths: {} };
    this._protagonistVisualIdentity = protagonistVisualIdentity?.contractId === 'protagonist_yelingyun_visual_identity_v1'
      ? protagonistVisualIdentity
      : null;
    this._actionPresentationData = actionPresentationData?.contractId === 'combat_action_presentation_registry_v1'
      ? actionPresentationData
      : { paths: {}, encounters: {}, timelines: {}, sfxCues: {}, bossPhaseTransitions: {} };
    this._visualWorldData = visualWorldData?.contractId === 'combat_visual_world_registry_v1'
      ? visualWorldData
      : { worlds: {} };
    this._carrierScaleProvenance = carrierScaleProvenance?.contractId === 'combat_carrier_scale_provenance_v1'
      ? carrierScaleProvenance
      : { contractId: null, records: {} };
    this._actionScaleProvenance = actionScaleProvenance?.contractId === 'combat_action_scale_provenance_v1'
      ? actionScaleProvenance
      : { contractId: null, records: {} };
    this.cardDB = {};
    cardData.battle_cards.forEach(c => this.cardDB[c.id] = c);

    this.enemyDB = {};
    if (cardData.enemies) {
        cardData.enemies.forEach(e => this.enemyDB[e.id] = e);
    }

    // 玩家基础战斗身份由正式持久状态与已加载系统共同重建；恢复时复用同一权威函数。
    const playerAuthority = this._buildPlayerAuthority();
    this.preCombatHealth = playerAuthority.preCombatHealth;
    this.player = playerAuthority.player;

    const combatStartBlock = playerAuthority.combatStartBlock;
    if (combatStartBlock > 0) {
      this.player.block += combatStartBlock;
      this._addLog(`阵法玄机展开，开战获得 ${combatStartBlock} 点护盾。`);
    }

    // Boss 的每个阶段都是独立战斗实体，但共享玩家牌堆与气血。
    const enemyData = card.enemy;
    this.bossPhases = Array.isArray(enemyData.phases) ? enemyData.phases : [];
    this.bossPhaseIndex = 0;
    this.enemy = this._createEnemy(this.bossPhases[0] || enemyData, enemyData);

    // 境界 Boss 的固定强度与对策只从卡牌契约读取，不再在消费者里复制魔数。
    const combatRules = card.combatRules || {};
    if (combatRules.strengthModel === 'fixed_with_counters'
      && Number.isFinite(Number(combatRules.baseHp))) {
      const daoHeart = gameState.attributes.daoHeart || 0;
      const baseHp = Number(combatRules.baseHp);
      const minimumHp = Math.max(1, Number(combatRules.minimumHp) || 1);
      const reductionPerPoint = Math.max(0, Number(combatRules.daoHeartHpReductionPerPoint) || 0);
      const finalHp = Math.max(minimumHp, baseHp - daoHeart * reductionPerPoint);
      this.enemy.hp = finalHp;
      this.enemy.maxHp = finalHp;
      this._addLog(`心魔显化！你当前的道心为 ${daoHeart}。因道心坚韧，心魔遭受到极大压制，其最大血量降为 ${finalHp} 点！`);
    }

    // 境界突破状态加成与天劫弱化。所有数值来自当前终局卡，
    // 兼容单 counter、命名 counters 与攻击反噬内嵌 counter 三种内容契约。
    if (typeof gameState !== 'undefined') {
      const configuredCounters = [];
      if (combatRules.counter) configuredCounters.push(combatRules.counter);
      if (combatRules.counters && typeof combatRules.counters === 'object') {
        configuredCounters.push(...Object.values(combatRules.counters));
      }
      if (combatRules.attackBacklash?.counter) {
        configuredCounters.push(combatRules.attackBacklash.counter);
      }
      for (const counter of configuredCounters) {
        if (!counter?.flag || !gameState.hasFlag(counter.flag)) continue;
        const openingBlock = Math.max(0, Number(counter.openingBlock) || 0);
        const enemyHpReduction = Math.max(0, Number(counter.enemyHpReduction) || 0);
        const enemyAttackReduction = Math.max(0, Number(counter.enemyAttackReduction) || 0);
        this.player.block += openingBlock;
        this.enemy.hp = Math.max(2, this.enemy.hp - enemyHpReduction);
        this.enemy.maxHp = this.enemy.hp;
        this.enemy.atkPower = Math.max(1, this.enemy.atkPower - enemyAttackReduction);
        if (openingBlock > 0 || enemyHpReduction > 0 || enemyAttackReduction > 0) {
          this._addLog(
            `突破对策生效：获得 ${openingBlock} 点护盾，Boss 根基削减 ${enemyHpReduction} 点，攻击降低 ${enemyAttackReduction} 点。`
          );
        }
      }
      const narrativeStance = combatRules.narrativeStance || {};
      if (narrativeStance.id === 'guarded') {
        const openingBlock = Math.max(0, Number(narrativeStance.openingBlock) || 0);
        this.player.block += openingBlock;
        if (openingBlock > 0) this._addLog(`【问剑守势】雷劫开场，获得 ${openingBlock} 点护盾。`);
      }
    }

    // 初始化装备被动状态
    this.equipmentState = {};
    if (typeof equipmentSystem !== 'undefined' && equipmentSystem) {
      const passives = equipmentSystem.getActivePassives();
      passives.forEach((p, idx) => {
        if (p.triggerCount || p.oncePerCombat === true) {
          this.equipmentState[this._equipmentPassiveStateKey(p, idx)] = 0;
        }
        if (Number(p?.distinctTagsThreshold) > 0) {
          this.equipmentState[this._equipmentDistinctTagStateKey(p, idx)] = [];
        }
      });
    }

    // 永久牌组只由牌组权威初始化；这里负责旧通用六牌迁移与运行时同步。
    const deckAuthority = this.deckAuthority
      || (typeof skillCardAcquisitionSystem !== 'undefined' ? skillCardAcquisitionSystem : null);
    if (deckAuthority && typeof deckAuthority.ensureStarterDeck === 'function') {
      deckAuthority.ensureStarterDeck(gameState.path, {
        sourceType: 'combat_entry_migration',
        sourceId: card.id || 'combat:start'
      });
    }
    if (!Array.isArray(gameState.deck) || gameState.deck.length === 0) {
      this._addLog('本命牌组尚未建立，战斗无法开始。请返回择道界面重新立誓。');
      eventBus.emit('combat:error', { reason: 'starter_deck_unavailable', path: gameState.path || null });
      return false;
    }
    this.masterDeck = [...gameState.deck];

    // 【ISSUE-06 闭环】注入穿戴装备与法宝的动态战术卡
    this._injectEquipmentAndTreasureTacticalCards();
    // 道侣只注入当前好感度已解锁的最高阶并肩技能。
    this._injectCompanionTacticalCards();
    // 剧情战可显式提供一张本场专属援护牌；它仍必须由玩家亲手打出，
    // 不是把“同伴协助”写成开场数值或旁白。
    this._injectStoryTacticalCard();

    // A later encounter must never inherit a queued hide from a finished
    // encounter's terminal presentation.
    this._clearTerminalCombatHide();
    this._clearPresentationActionTimers();
    this.active = true;
    this.phase = 'PLAYER_TURN';
    this.pendingReaction = null;
    this._reactionSequence = 0;
    this._settledReactionWindows = new Set();
    this._nextTurnDrawPenalty = 0;
    this._clearReactionTimer();
    this._authorityLedger = [];
    this._authorityChain = 'dc2-root';
    this.turn = 0;
    this.playerStatus = {};
    this.enemyStatus = {};
    this._playerStatusesAppliedByEnemy = new Set();
    if (combatRules.narrativeStance?.id === 'advance'
      && Number(combatRules.narrativeStance.firstDamagingLightningReduction) > 0) {
      this._addStatus('player', 'qi_main_advance_ready', 1);
      this._addLog('【问剑进势】第一道有效雷击将被剑势卸去 1 点。');
    }
    this.drawPile = [...this.masterDeck];

    this.hand = [];
    this.discardPile = [];
    this.exhaustPile = [];

    // 洗牌
    this._shuffle(this.drawPile);
    this._prioritizeOpeningStoryTacticalCard();

    this._addLog(`你遭遇了 ${this.enemy.name}！`);

    // 【体修专属被动 · 金刚气血防壁】
    if (typeof gameState !== 'undefined' && gameState && gameState.path === 'body') {
      // The shield belongs to the combat vitality scale, not the unbounded
      // persistent-world health total. A quarter-budget opening guard gives
      // Body a visible identity without erasing the first enemy action.
      const innateShield = Math.min(1, Math.floor(Math.max(1, Number(this.player.maxHp) || 1) * 0.25));
      this.player.block += innateShield;
      this._addLog(`体修【金刚气血防壁】轰然爆发，凭肉身强悍气血获得 ${innateShield} 点初始防壁！`);
    }

    // Check combat_start equipment passives
    this._triggerEquipmentPassives('onCombatStart');

    if (typeof pathArchetypeSystem !== 'undefined' && pathArchetypeSystem) {
      const archetype = pathArchetypeSystem.onBattleStart();
      if (archetype) this._addLog(`功法流派【${archetype.name}】开始运转。`);
    }

    if (typeof npcSystem !== 'undefined' && npcSystem && npcSystem.getCombatAssist) {
      const assist = npcSystem.getCombatAssist();
      if (assist) {
        this.player.atkMod += assist.atk || 0;
        this.player.block += assist.block || 0;
        if (assist.status) this._addStatus('player', assist.status.id, assist.status.value || 1);
        this._addLog(`${assist.npcName}以跨境神念助阵：${assist.text || '气机相连'}。`);
      }
    }

    // 计算基于境界的 maxQi
    this.maxQi = this._maxQiForRealm(gameState.realm);
    this.qi = this.maxQi;

    // 【P3 修复】装备开局效果已统一由 _triggerEquipmentPassives('onCombatStart') 在第 216 行处理，
    // 此处原有的硬编码已移除，避免与 equipment.json 数据配置产生数值冲突。

    // 法宝遗物：开局效果 (在此触发)
    this._triggerRelic('combat_start');

    // 先切换界面再广播首回合状态，避免首帧动画在 display:none 时被消耗。
    eventBus.emit('ui:showCombatScreen');
    eventBus.emit('combat:started', this._getPresentationContext());
    this._startTurn();
  }

  _startTurn(authorityDetail = {}) {
    if (!this.active) return;
    this.phase = 'PLAYER_TURN';
    this.pendingReaction = null;
    this.damageDealtThisTurn = false;
    this.turn++;
    this.qi = this.maxQi;
    this._beginPlanPlayerTurn();
    if (typeof pathArchetypeSystem !== 'undefined' && pathArchetypeSystem) {
      pathArchetypeSystem.onTurnStart();
    }

    this._triggerEquipmentPassives('onTurnStart');

    // 第 1 回合保留战前丹药/装备/道侣授予的开场护盾；后续回合再按常规清除。
    if (this.turn > 1 && !this._hasStatus('player', 'aura')) {
        this.player.block = 0;
    } else if (this.turn > 1) {
        this.player.block = Math.min(this.player.block, this._retainedBlockCap(this.player));
        this._addLog(`【罡气】生效，保留了护盾。`);
    }

    // 剑意回合结束减半保留 (通过回合开始时结算)
    let swordIntent = this._getStatus('player', 'sword_intent');
    if (swordIntent > 0) {
        this._setStatus('player', 'sword_intent', Math.floor(swordIntent / 2));
    }

    // 状态自然衰减 (回合开始时，玩家自身及敌人的状态衰减 1 层)
    ['weak', 'vulnerable', 'poison', 'fortify', 'opening'].forEach(status => {
        const pVal = this._getStatus('player', status);
        if (this._playerStatusesAppliedByEnemy.has(status)) {
            // 敌人在刚结束的行动中施加的 1 层状态必须覆盖即将开始的玩家回合，
            // 不能在同一条 endTurn -> enemyTurn -> startTurn 链里立刻归零。
            this._playerStatusesAppliedByEnemy.delete(status);
        } else if (pVal > 0) {
            this._setStatus('player', status, pVal - 1);
        }

        // Enemy poison owns its lifetime in _enemyTurn: one stack is consumed
        // only after it has dealt that stack's tick. Generic turn decay here
        // used to erase a second stack without ever producing damage.
        if (status !== 'poison') {
            const eVal = this._getStatus('enemy', status);
            if (eVal > 0) this._setStatus('enemy', status, eVal - 1);
        }
    });

    // 敌人意图生成
    this._generateEnemyIntent();

    // 闪避会以损失下一回合手牌作为代价；惩罚只消费一次。
    const drawPenalty = Math.max(0, Math.floor(Number(this._nextTurnDrawPenalty) || 0));
    this._nextTurnDrawPenalty = 0;
    this._drawCards(Math.max(0, 5 - drawPenalty));
    this._applyKarmaJudgment();

    this._addLog(`--- 第 ${this.turn} 回合 ---`);
    this._recordAuthorityCheckpoint('TURN_START', authorityDetail);
    this._triggerUpdate();
    this._persistCombatSession();
  }

  _applyKarmaJudgment() {
    const judgment = this.originalCard?.combatRules?.karmaJudgment;
    if (!judgment || judgment.timing !== 'after_draw' || typeof gameState === 'undefined') return;

    const goodKey = judgment.goodAttribute || 'karmaGood';
    const badKey = judgment.badAttribute || 'karmaBad';
    const karmaGood = Number(gameState.attributes?.[goodKey]) || 0;
    const karmaBad = Number(gameState.attributes?.[badKey]) || 0;
    if (karmaGood > karmaBad) {
      const drawCount = Math.max(0, Math.floor(Number(judgment.goodDraw) || 0));
      for (let index = 0; index < drawCount; index++) this._drawCard(true);
      if (drawCount > 0) {
        this._addLog(`【天道审判·赏善】善业 ${karmaGood} 高于恶业 ${karmaBad}，额外抽取 ${drawCount} 张手牌！`);
      }
    } else if (karmaBad > karmaGood) {
      const discardCount = Math.min(
        this.hand.length,
        Math.max(0, Math.floor(Number(judgment.badDiscard) || 0))
      );
      for (let index = 0; index < discardCount; index++) {
        const discarded = this.hand.splice(Math.floor(Math.random() * this.hand.length), 1)[0];
        this.discardPile.push(discarded);
      }
      if (discardCount > 0) {
        this._addLog(`【天道审判·罚恶】恶业 ${karmaBad} 高于善业 ${karmaGood}，随机弃置 ${discardCount} 张手牌！`);
      }
    }
  }

  endTurn() {
    if (!this.active) return { opened: false, reason: 'combat_inactive' };
    if (this.phase !== 'PLAYER_TURN') {
      return { opened: false, reason: 'combat_phase_locked', phase: this.phase };
    }
    if (this.isPlayerInputLocked()) {
      return { opened: false, reason: 'combat_input_locked' };
    }

    // 功法流派：回合结束触发
    if (typeof pathArchetypeSystem !== 'undefined'
      && pathArchetypeSystem
      && typeof pathArchetypeSystem.onTurnEnd === 'function') {
      pathArchetypeSystem.onTurnEnd();
    }

    // 【BUG-1 修复】装备被动：回合结束触发（onTurnEnd）
    this._triggerEquipmentPassives('onTurnEnd');

    // Read the committed end-of-turn resource state before the reaction
    // window is authored; the plan may announce a different action.
    this._transitionEnemyPlan('player_reserved_resource');

    // Enemy guard normally lasts for one player action window. A small number
    // of authored mechanisms (for example the broken mountain array) declare
    // an explicit state-owned retention window so the player can truly break
    // the ward before its charged action. This remains plan data, never a
    // tier/HP/name special case, and natural expiry must not masquerade as a
    // combat:enemyBlockBroken edge.
    const enemyPlan = this._getEnemyPlanGraph();
    const retainedStates = enemyPlan?.blockContract?.retainInStates;
    const retainsBlock = Array.isArray(retainedStates)
      && retainedStates.includes(this.enemy?.planRuntime?.currentState);
    if (!retainsBlock) this.enemy.block = 0;

    // 弃掉手牌
    while (this.hand.length > 0) {
      this.discardPile.push(this.hand.pop());
    }

    return this._openReactionWindow();
  }

  _clearReactionTimer() {
    if (this._reactionTimer !== null && this._reactionTimer !== undefined) {
      this._cancelSchedule(this._reactionTimer);
    }
    this._reactionTimer = null;
  }

  _getReactionMode() {
    const configured = typeof experienceSettings !== 'undefined'
      && experienceSettings
      && typeof experienceSettings.get === 'function'
      ? experienceSettings.get('reactionMode')
      : null;
    return configured === 'timed' ? 'timed' : 'paused';
  }

  _enemyDefenseValue(intent) {
    const value = Number(intent?.value);
    return Number.isFinite(value) ? Math.max(0, Math.floor(value)) : 2;
  }

  _previewEnemyAction(intent = this.enemyIntent, enemy = this.enemy) {
    const type = intent?.type || 'attack';
    let expectedDamage = 0;
    if (type === 'attack') {
      expectedDamage = Math.max(Number(intent?.value) || 1, Number(enemy?.atkPower) || 1);
      if (Number(enemy?.tier) === 2) expectedDamage += 2;
      if (Number(intent?.multiplier) > 1) expectedDamage = Math.ceil(expectedDamage * Number(intent.multiplier));
    }
    const actionFamilies = {
      attack: intent?.piercing === true ? 'PIERCING_ATTACK' : 'ATTACK',
      debuff: 'DEBUFF',
      defend: 'DEFEND',
      buff: 'BUFF'
    };
    return {
      type,
      actionFamily: actionFamilies[type] || 'SPECIAL',
      actionName: intent?.actionName || intent?.desc || '敌方行动',
      description: intent?.desc || intent?.actionName || '敌方正在凝聚气机',
      expectedDamage,
      piercing: intent?.piercing === true,
      statusId: intent?.statusId || null,
      value: type === 'defend' ? this._enemyDefenseValue(intent) : Number(intent?.value) || 0
    };
  }

  _reactionOption(id, label, description, costQi, available, disabledReason = '') {
    return {
      id,
      label,
      description,
      cost: { qi: Math.max(0, Number(costQi) || 0) },
      available: Boolean(available),
      disabledReason: available ? '' : disabledReason
    };
  }

  _buildReactionOptions(action, context = {}) {
    const qiSource = Object.prototype.hasOwnProperty.call(context, 'qi') ? context.qi : this.qi;
    const qi = Math.max(0, Number(qiSource) || 0);
    const isAttack = action.type === 'attack';
    const isCounterable = action.piercing !== true;
    const options = [
      this._reactionOption('TAKE_HIT', '承受', '不消耗真元，保留余力并接受敌方行动的完整后果。', 0, true),
      this._reactionOption(
        'GUARD',
        '格挡',
        '消耗 1 点真元，稳住架势并减轻本次攻击。',
        1,
        isAttack && qi >= 1,
        !isAttack ? '此行动不造成直接攻击，无法格挡。' : '至少需要保留 1 点真元。'
      ),
      this._reactionOption(
        'EVADE',
        '闪避',
        '消耗 2 点真元避开直接攻击；下一回合少抽 1 张牌。',
        2,
        isAttack && qi >= 2,
        !isAttack ? '此行动不是可闪避的直接攻击。' : '至少需要保留 2 点真元。'
      )
    ];
    const pathId = context.pathId
      || (typeof gameState !== 'undefined' && gameState?.path ? gameState.path : 'sword');
    if (pathId === 'sword') {
      options.splice(1, 0, this._reactionOption(
        'DEFLECT', '偏斩', '保留两点真元，以剑锋偏开来势；小招只被导开，强攻会被卸力并令敌人暴露破绽。', 2,
        isAttack && isCounterable && qi >= 2,
        action.piercing ? '穿透攻势无法偏斩。' : (!isAttack ? '只能偏斩直接攻击。' : '至少需要保留 2 点真元。')
      ));
    } else if (pathId === 'spell') {
      options.splice(1, 0, this._reactionOption(
        'INTERRUPT', '截术', '保留两点真元，以法印扰乱敌方气机；术式会被取消，攻击则完整落下但后续攻势被削弱。', 2,
        qi >= 2,
        '至少需要保留 2 点真元。'
      ));
    } else if (pathId === 'body') {
      options.splice(1, 0, this._reactionOption(
        'ABSORB', '硬承', '保留两点真元，以肉身承势，减轻伤害并把余威炼成反击劲。', 2,
        isAttack && qi >= 2,
        !isAttack ? '只能硬承直接攻击。' : '至少需要保留 2 点真元。'
      ));
    } else if (pathId === 'pill' || pathId === 'alchemy') {
      options.splice(1, 0, this._reactionOption(
        'TRANSMUTE', '逆炼', '保留两点真元临阵改方：化去负面术式；面对攻击时承受全部伤害，并把来势反炼为丹毒。', 2,
        (isAttack || action.type === 'debuff') && qi >= 2,
        action.type !== 'attack' && action.type !== 'debuff'
          ? '只能逆炼攻击或负面术式。'
          : '至少需要保留 2 点真元。'
      ));
    }
    return options;
  }

  _openReactionWindow() {
    if (!this.active || this.phase !== 'PLAYER_TURN' || !this.enemyIntent) {
      return { opened: false, reason: 'reaction_not_available' };
    }
    const action = this._previewEnemyAction(this.enemyIntent);
    const mode = this._getReactionMode();
    const openedAt = this._now();
    const durationMs = mode === 'timed' ? 8000 : null;
    const sourceCardId = this.originalCard?.id || 'combat';
    const windowId = `${sourceCardId}:turn:${this.turn}:reaction:${++this._reactionSequence}`;
    this.phase = 'REACTION_OPEN';
    this.pendingReaction = {
      version: 1,
      windowId,
      turn: this.turn,
      sourceCardId,
      source: this.enemy?.name || 'enemy',
      target: 'player',
      mode,
      openedAt,
      durationMs,
      deadlineAt: durationMs ? openedAt + durationMs : null,
      action,
      options: this._buildReactionOptions(action)
    };
    this._recordAuthorityCheckpoint('REACTION_OPEN', { windowId });
    eventBus.emit('combat:reactionOpened', this._cloneReaction(this.pendingReaction));
    this._triggerUpdate();
    if (mode === 'timed') this._scheduleReactionExpiry(this.pendingReaction);
    if (typeof gameState !== 'undefined' && typeof gameState?.persistCausalSession === 'function') {
      gameState.persistCausalSession();
    }
    return { opened: true, windowId, mode };
  }

  _cloneReaction(reaction) {
    return reaction ? JSON.parse(JSON.stringify(reaction)) : null;
  }

  _resolveReactionPresentationSourceId(reactionId, action) {
    const registry = this._actionPresentationData || {};
    const encounterId = this._encounterActionId?.();
    const family = String(action?.actionFamily || '').toLowerCase();
    const encounterAction = registry.encounters?.[encounterId]?.[family];
    const variantIds = [
      action?.presentationVariantId,
      action?.sourceId,
      action?.planState,
      this.enemy?.planRuntime?.currentState,
      action?.actionName,
      action?.type
    ].filter(value => value !== null && value !== undefined).map(String);
    const encounterVariant = variantIds
      .map(sourceId => encounterAction?.variantsBySourceId?.[sourceId])
      .find(candidate => candidate && typeof candidate === 'object' && !Array.isArray(candidate));
    const mapped = encounterVariant?.reactionPresentationSourceIds?.[reactionId]
      || encounterAction?.reactionPresentationSourceIds?.[reactionId]
      || reactionId;
    const pathId = ((typeof gameState !== 'undefined' && gameState?.path) || 'sword');
    const reactionVariants = registry.paths?.[pathId]?.reaction?.variantsBySourceId;
    return mapped === reactionId || (reactionVariants && Object.prototype.hasOwnProperty.call(reactionVariants, mapped))
      ? mapped
      : reactionId;
  }

  _scheduleReactionExpiry(reaction) {
    this._clearReactionTimer();
    if (!reaction || reaction.mode !== 'timed' || !Number.isFinite(Number(reaction.deadlineAt))) return;
    const delay = Math.max(0, Number(reaction.deadlineAt) - this._now());
    const windowId = reaction.windowId;
    this._reactionTimer = this._schedule(() => this.expireReaction(windowId), delay);
  }

  expireReaction(windowId) {
    if (!this.pendingReaction || this.pendingReaction.windowId !== windowId || this.phase !== 'REACTION_OPEN') {
      return { resolved: false, reason: 'stale_reaction_window' };
    }
    if (this.pendingReaction.mode !== 'timed') {
      return { resolved: false, reason: 'paused_reaction_window' };
    }
    eventBus.emit('combat:reactionMissed', {
      windowId,
      actionFamily: this.pendingReaction.action?.actionFamily || 'SPECIAL',
      source: this.pendingReaction.source,
      target: this.pendingReaction.target,
      mode: this.pendingReaction.mode,
      result: 'timeout_take_hit'
    });
    return this.chooseReaction('TAKE_HIT', windowId, { missed: true });
  }

  chooseReaction(reactionId, windowId = null, meta = {}) {
    const pending = this.pendingReaction;
    if (!pending || this.phase !== 'REACTION_OPEN' || pending.windowId !== windowId) {
      return { resolved: false, reason: 'stale_reaction_window' };
    }
    const authoritativeAction = this._previewEnemyAction(this.enemyIntent);
    const actionMatches = JSON.stringify(pending.action) === JSON.stringify(authoritativeAction);
    const identityMatches = pending.turn === this.turn
      && pending.sourceCardId === this.originalCard?.id
      && pending.source === this.enemy?.name
      && pending.target === 'player';
    if (!actionMatches || !identityMatches) {
      return { resolved: false, reason: 'invalid_reaction_window' };
    }
    // Rebuild from current authoritative path/action/qi. Snapshot/UI fields are
    // presentation data and can never author an ID, availability, or price.
    const authoritativeOptions = this._buildReactionOptions(authoritativeAction);
    const option = authoritativeOptions.find(candidate => candidate.id === reactionId);
    if (!option) return { resolved: false, reason: 'unknown_reaction' };
    if (!option.available) {
      return { resolved: false, reason: 'reaction_unavailable', disabledReason: option.disabledReason };
    }
    if (this._settledReactionWindows.has(windowId)) {
      return { resolved: false, reason: 'stale_reaction_window' };
    }

    const qiCost = Math.max(0, Number(option.cost?.qi) || 0);
    if (this.qi < qiCost) return { resolved: false, reason: 'reaction_unavailable' };
    const reactionPresentationSourceId = this._resolveReactionPresentationSourceId(reactionId, pending.action);
    this.qi -= qiCost;
    this._clearReactionTimer();
    this._settledReactionWindows.add(windowId);
    this.phase = 'ENEMY_RESOLVE';
    this.pendingReaction = null;

    const resolution = {
      windowId,
      reactionId,
      actionFamily: pending.action?.actionFamily || 'SPECIAL',
      source: pending.source,
      target: pending.target,
      mode: pending.mode,
      missed: meta.missed === true,
      damageMultiplier: 1,
      cancelAction: false,
      result: 'accepted'
    };
    Object.assign(resolution, DeckCombatSystem.projectReactionEffect(reactionId, pending.action, meta));

    eventBus.emit('combat:reactionChosen', {
      ...resolution,
      cost: { qi: qiCost }
    });
    // A reaction is an authored player action, not only a result label. It is
    // deliberately presentation-only: it cannot interrupt or re-author the
    // enemy action that is about to resolve.
    this._emitPlayerPresentationAction('reaction', {
      target: 'enemy',
      sourceId: reactionPresentationSourceId
    });
    const reactionPlanCause = resolution.result === 'deflected'
      ? 'deflected'
      : (reactionId === 'TRANSMUTE' ? 'transmuted' : null);
    if (reactionPlanCause && this.enemy?.planRuntime) {
      // Path reactions change the following plan state, not the already-open
      // action contract that this reaction is resolving.
      this.enemy.planRuntime.lastReaction = reactionId;
      this._transitionEnemyPlan(reactionPlanCause, { refreshIntent: false });
    } else if (this.enemy?.planRuntime) {
      this.enemy.planRuntime.lastReaction = reactionId;
    }
    const terminalOutcome = this._enemyTurn(resolution);
    // Defeat can synchronously restore the authenticated reaction window when
    // its source settlement cannot commit. That makes this.active true again,
    // but this old input must not advance or persist the restored battle.
    if (terminalOutcome === 'defeat') {
      return { resolved: true, reactionId, windowId, result: resolution.result };
    }
    this._applyReactionAftermath(resolution);
    if (this.active) {
      this._recordAuthorityCheckpoint('REACTION_RESOLVED', { windowId, reactionId });
    }
    if (typeof gameState !== 'undefined' && typeof gameState?.persistCausalSession === 'function') {
      gameState.persistCausalSession();
    }
    return { resolved: true, reactionId, windowId, result: resolution.result };
  }

  _applyReactionAftermath(reactionResolution) {
    if (!this.active || this.phase !== 'PLAYER_TURN' || !reactionResolution) return false;
    if (reactionResolution.applyEnemyStatus) {
      this._addStatus(
        'enemy',
        reactionResolution.applyEnemyStatus.id,
        reactionResolution.applyEnemyStatus.value || 1
      );
    }
    if (reactionResolution.applyPlayerStatus) {
      this._addStatus(
        'player',
        reactionResolution.applyPlayerStatus.id,
        reactionResolution.applyPlayerStatus.value || 1
      );
    }
    if (reactionResolution.applyEnemyStatus || reactionResolution.applyPlayerStatus) {
      this._triggerUpdate();
      return true;
    }
    return false;
  }

  _endPathArchetypeBattle() {
    if (typeof pathArchetypeSystem === 'undefined'
      || !pathArchetypeSystem
      || typeof pathArchetypeSystem.onBattleEnd !== 'function') return false;
    return pathArchetypeSystem.onBattleEnd();
  }

  _resolveEnemyDef(enemyData, tier, enemyDB = this.enemyDB) {
    if (enemyData.id && enemyDB[enemyData.id]) return enemyDB[enemyData.id];
    if (enemyData.templateId && enemyDB[enemyData.templateId]) return enemyDB[enemyData.templateId];
    if (enemyData.name && enemyData.name.includes('筑基雷劫')) return enemyDB.enemy_qi_tribulation;
    if (enemyData.name && enemyData.name.includes('金丹心魔')) return enemyDB.enemy_foundation_demon;
    if (enemyData.name && enemyData.name.includes('元婴天劫')) return enemyDB.enemy_golden_tribulation;
    if (enemyData.name && enemyData.name.includes('化神雷罚')) return enemyDB.enemy_nascent_tribulation;
    if (enemyData.name && enemyData.name.includes('九重天劫')) return enemyDB.enemy_deity_tribulation;
    if (enemyData.name && enemyData.name.includes('飞升天劫')) return enemyDB.enemy_tribulation_finale;
    if (enemyData.name && (enemyData.name.includes('妖女') || enemyData.name.includes('合欢'))) return enemyDB.seductress;
    if (enemyData.name && (enemyData.name.includes('剑') || enemyData.name.includes('长老'))) return enemyDB.sword_elder;
    if (enemyData.name && (enemyData.name.includes('妖') || enemyData.name.includes('兽'))) return enemyDB.demon_beast;
    return enemyDB[tier === 1 ? 'enemy_normal' : tier === 2 ? 'enemy_charging' : 'enemy_sword'];
  }

  _normalizePlanGraph(rawGraph) {
    if (!rawGraph || typeof rawGraph !== 'object' || Array.isArray(rawGraph)) return null;
    const graphKeys = new Set([
      'planId', 'initialState', 'states', 'transitions', 'memoryContract', 'blockContract'
    ]);
    if (Object.keys(rawGraph).some(key => !graphKeys.has(key))) return null;
    const planId = typeof rawGraph.planId === 'string' ? rawGraph.planId.trim() : '';
    const initialState = typeof rawGraph.initialState === 'string' ? rawGraph.initialState.trim() : '';
    const states = rawGraph.states;
    if (!planId || !initialState || !states || typeof states !== 'object' || Array.isArray(states)) return null;
    if (!states[initialState]) return null;
    if (!Array.isArray(rawGraph.transitions) || rawGraph.transitions.length === 0) return null;
    const allowedIntentTypes = new Set(['attack', 'defend', 'buff', 'debuff']);
    const allowedIntentKeys = new Set([
      'type', 'value', 'desc', 'actionName', 'statusId', 'multiplier', 'piercing', 'actionFamily'
    ]);
    const allowedPresentationFamilies = new Set(['attack', 'guard', 'skill', 'hurt']);
    const allowedStateKeys = new Set(['label', 'cue', 'intent']);
    const normalizedStates = {};
    for (const [stateId, state] of Object.entries(states)) {
      if (!stateId || !state || typeof state !== 'object' || Array.isArray(state)) return null;
      if (Object.keys(state).some(key => !allowedStateKeys.has(key))) return null;
      if (!state.intent || !allowedIntentTypes.has(state.intent.type)) return null;
      if (Object.keys(state.intent).some(key => !allowedIntentKeys.has(key))) return null;
      if (state.intent.actionFamily !== undefined
        && !allowedPresentationFamilies.has(state.intent.actionFamily)) return null;
      if (typeof state.label !== 'string' || !state.label.trim()
        || typeof state.cue !== 'string' || !state.cue.trim()
        || typeof state.intent.desc !== 'string' || !state.intent.desc.trim()
        || typeof state.intent.actionName !== 'string' || !state.intent.actionName.trim()) return null;
      if (['attack', 'defend'].includes(state.intent.type)
        && (!Number.isFinite(Number(state.intent.value)) || Number(state.intent.value) < 0)) return null;
      normalizedStates[stateId] = {
        label: String(state.label || stateId),
        cue: String(state.cue || ''),
        intent: JSON.parse(JSON.stringify(state.intent))
      };
    }
    const memoryContract = rawGraph.memoryContract === undefined
      ? null : JSON.parse(JSON.stringify(rawGraph.memoryContract));
    if (memoryContract) {
      const isLegacyFamilyContract = memoryContract.kind === 'first_action_family_v1';
      const isSemanticSequenceContract = memoryContract.kind === 'first_action_family_and_semantic_action_v2';
      const allowedMemoryKeys = new Set([
        'kind', 'allowedFamilies', ...(isSemanticSequenceContract ? ['allowedSemanticActionFamilies'] : [])
      ]);
      const families = memoryContract.allowedFamilies;
      if (Object.keys(memoryContract).some(key => !allowedMemoryKeys.has(key))
        || (!isLegacyFamilyContract && !isSemanticSequenceContract)
        || !Array.isArray(families)
        || families.length !== 4
        || new Set(families).size !== families.length
        || families.some(family => !['sword', 'spell', 'body', 'pill'].includes(family))) return null;
      if (isSemanticSequenceContract) {
        const families = memoryContract.allowedSemanticActionFamilies;
        if (!Array.isArray(families)
          || families.length !== 3
          || new Set(families).size !== families.length
          || families.some(family => !['attack', 'guard', 'skill'].includes(family))) return null;
      }
    }
    const blockContract = rawGraph.blockContract === undefined
      ? null : JSON.parse(JSON.stringify(rawGraph.blockContract));
    if (blockContract) {
      const allowedBlockKeys = new Set(['retainInStates', 'releaseOnExit']);
      if (Object.keys(blockContract).some(key => !allowedBlockKeys.has(key))
        || !Array.isArray(blockContract.retainInStates)
        || blockContract.retainInStates.length === 0
        || new Set(blockContract.retainInStates).size !== blockContract.retainInStates.length
        || blockContract.retainInStates.some(stateId => !normalizedStates[stateId])
        || blockContract.releaseOnExit !== true) return null;
    }
    const allowedCauses = new Set([
      'player_overcommitted',
      'repeated_card_type',
      'player_reserved_resource',
      'deflected',
      'transmuted',
      'action_resolved',
      'enemy_block_broken',
      'first_card_recorded',
      'sequence_broken'
    ]);
    const transitions = [];
    for (const transition of Array.isArray(rawGraph.transitions) ? rawGraph.transitions : []) {
      const allowedTransitionKeys = new Set(['from', 'when', 'to']);
      if (transition?.when === 'player_overcommitted') {
        allowedTransitionKeys.add('minCards');
        allowedTransitionKeys.add('maxReservedQi');
      } else if (transition?.when === 'repeated_card_type') {
        allowedTransitionKeys.add('minConsecutive');
      } else if (transition?.when === 'player_reserved_resource') {
        allowedTransitionKeys.add('maxCards');
        allowedTransitionKeys.add('minReservedQi');
      }
      if (!transition || Object.keys(transition).some(key => !allowedTransitionKeys.has(key))) return null;
      const from = Array.isArray(transition?.from) ? transition.from : [transition?.from];
      if (!from.length || new Set(from).size !== from.length || from.some(stateId => !normalizedStates[stateId])) return null;
      if (!normalizedStates[transition?.to] || !allowedCauses.has(transition?.when)) return null;
      if (transition.when === 'player_overcommitted'
        && (!Number.isInteger(Number(transition.minCards)) || Number(transition.minCards) < 1
          || !Number.isInteger(Number(transition.maxReservedQi)) || Number(transition.maxReservedQi) < 0)) return null;
      if (transition.when === 'repeated_card_type'
        && (!Number.isInteger(Number(transition.minConsecutive)) || Number(transition.minConsecutive) < 2)) return null;
      if (transition.when === 'player_reserved_resource'
        && (!Number.isInteger(Number(transition.maxCards)) || Number(transition.maxCards) < 0
          || !Number.isInteger(Number(transition.minReservedQi)) || Number(transition.minReservedQi) < 1)) return null;
      transitions.push({
        ...JSON.parse(JSON.stringify(transition)),
        from: [...from]
      });
    }
    return {
      planId,
      initialState,
      states: normalizedStates,
      transitions,
      ...(memoryContract ? { memoryContract } : {}),
      ...(blockContract ? { blockContract } : {})
    };
  }

  _createPlanRuntime(planGraph, turn = this.turn, qi = this.qi) {
    if (!planGraph) return null;
    const runtime = {
      version: 1,
      planId: planGraph.planId,
      currentState: planGraph.initialState,
      intentState: planGraph.initialState,
      transitionSequence: 0,
      lastTransition: null,
      lastReaction: null,
      turnMemory: {
        turn: Math.max(0, Math.floor(Number(turn) || 0)),
        cardsPlayed: 0,
        qiSpent: 0,
        qiGained: 0,
        qiRemaining: Math.max(0, Number(qi) || 0),
        cardTypes: [],
        playedCards: [],
        consecutiveType: null,
        consecutiveCount: 0,
        consumedSignals: []
      }
    };
    if (['first_action_family_v1', 'first_action_family_and_semantic_action_v2']
      .includes(planGraph.memoryContract?.kind)) {
      const rawPath = typeof gameState !== 'undefined' && gameState?.path
        ? String(gameState.path) : 'sword';
      const fallbackActionFamily = rawPath === 'alchemy' ? 'pill' : rawPath;
      runtime.encounterMemory = {
        kind: planGraph.memoryContract.kind,
        fallbackActionFamily: planGraph.memoryContract.allowedFamilies.includes(fallbackActionFamily)
          ? fallbackActionFamily : 'sword',
        capturedFirstActionFamily: null,
        capturedFirstActionCardId: null,
        ...(planGraph.memoryContract.kind === 'first_action_family_and_semantic_action_v2'
          ? { capturedFirstSemanticActionFamily: null } : {}),
        captureSequence: 0,
        sequenceBroken: false
      };
    }
    return runtime;
  }

  _getEnemyPlanGraph() {
    return this.enemy?.def?.planGraph || null;
  }

  // Some realm gates author a fixed public cadence (for example, the golden
  // yin-yang lightning).  That cadence owns action mechanics.  A plan graph
  // cannot silently replace it with a guard, a different damage value, or a
  // different piercing rule based on hidden player-behaviour signals.
  _getAuthoritativeTurnCycle(card = this.originalCard) {
    const turnCycle = card?.combatRules?.turnCycle;
    const order = Array.isArray(turnCycle?.order) ? turnCycle.order : [];
    if (!turnCycle || order.length === 0 || order.some(phaseId => !turnCycle?.[phaseId])) return null;
    return { turnCycle, order };
  }

  _generateTurnCycleIntent() {
    if (!this.enemy) return null;
    const intent = this._resolveTurnCycleIntent(
      this.originalCard, this.turn, this.enemy.def?.intents, this.enemy
    );
    if (intent) this.enemy.intentIndex += 1;
    return intent;
  }

  // Pure canonical rule shared by live generation and authenticated replay.
  // Presentation variant markers are part of that rule, not optional metadata.
  _resolveTurnCycleIntent(card, turn, authoredIntents, enemyAuthority) {
    const cycle = this._getAuthoritativeTurnCycle(card);
    if (!cycle || !enemyAuthority) return null;
    const phaseId = cycle.order[(Math.max(1, Number(turn) || 1) - 1) % cycle.order.length];
    const phase = cycle.turnCycle[phaseId] || {};
    const type = phase.intentType || 'attack';
    const targetMultiplier = Math.max(1, Number(phase.damageMultiplier) || 1);
    const intents = Array.isArray(authoredIntents) ? authoredIntents : [];
    const authoredIntent = intents.find(intent => {
      if (!intent || intent.condition || intent.type !== type) return false;
      if (Boolean(intent.piercing) !== Boolean(phase.piercing)) return false;
      return Number(intent.multiplier || 1) === targetMultiplier;
    });
    if (authoredIntent) {
      // Clone the authored public action verbatim so the intent banner,
      // reaction window and persistence validator all read one rule.
      return {
        ...JSON.parse(JSON.stringify(authoredIntent)),
        turnCyclePhaseId: phaseId,
        presentationVariantId: String(phase.presentationVariantId || phaseId)
      };
    }
    const intent = {
      type,
      value: Number.isFinite(Number(phase.value)) ? Number(phase.value) : enemyAuthority.atkPower,
      desc: phase.description || `意图：${phaseId}`
    };
    if (targetMultiplier > 1) intent.multiplier = targetMultiplier;
    if (phase.piercing === true) intent.piercing = true;
    intent.turnCyclePhaseId = phaseId;
    intent.presentationVariantId = String(phase.presentationVariantId || phaseId);
    return intent;
  }

  _getPlanStateView() {
    const runtime = this.enemy?.planRuntime;
    const graph = this._getEnemyPlanGraph();
    if (!runtime || !graph || !graph.states?.[runtime.currentState]) return null;
    const state = graph.states[runtime.currentState];
    return {
      ...JSON.parse(JSON.stringify(runtime)),
      stateLabel: state.label || runtime.currentState,
      cue: state.cue || '',
      recentCause: runtime.lastTransition?.cause || null
    };
  }

  _beginPlanPlayerTurn() {
    const runtime = this.enemy?.planRuntime;
    if (!runtime) return false;
    runtime.migration = null;
    runtime.turnMemory = {
      turn: this.turn,
      cardsPlayed: 0,
      qiSpent: 0,
      qiGained: 0,
      qiRemaining: this.qi,
      cardTypes: [],
      playedCards: [],
      consecutiveType: null,
      consecutiveCount: 0,
      consumedSignals: []
    };
    return true;
  }

  _recordPlanCardPlayed(card, cost) {
    const memory = this.enemy?.planRuntime?.turnMemory;
    if (!memory || memory.turn !== this.turn) return false;
    const type = String(card?.type || 'unknown');
    memory.cardsPlayed += 1;
    memory.qiSpent += Math.max(0, Number(cost) || 0);
    memory.qiRemaining = this.qi;
    memory.cardTypes.push(type);
    memory.playedCards.push({
      id: String(card?.id || ''),
      type,
      cost: Math.max(0, Number(cost) || 0)
    });
    if (memory.consecutiveType === type) memory.consecutiveCount += 1;
    else {
      memory.consecutiveType = type;
      memory.consecutiveCount = 1;
    }
    return true;
  }

  _planTransitionMatches(transition, cause, memory) {
    if (!transition || transition.when !== cause || !transition.from.includes(this.enemy.planRuntime.currentState)) return false;
    if (cause === 'player_overcommitted') {
      if (memory.cardsPlayed < Math.max(1, Number(transition.minCards) || 2)) return false;
      if (memory.qiRemaining > Math.max(0, Number(transition.maxReservedQi) || 0)) return false;
    } else if (cause === 'repeated_card_type') {
      if (memory.consecutiveCount < Math.max(2, Number(transition.minConsecutive) || 2)) return false;
    } else if (cause === 'player_reserved_resource') {
      if (memory.cardsPlayed > Math.max(0, Number(transition.maxCards) || 0)) return false;
      if (memory.qiRemaining < Math.max(1, Number(transition.minReservedQi) || 1)) return false;
    }
    return true;
  }

  _transitionEnemyPlan(cause, options = {}) {
    const runtime = this.enemy?.planRuntime;
    const graph = this._getEnemyPlanGraph();
    const memory = runtime?.turnMemory;
    if (!runtime || !graph || !memory) return false;
    const signalKey = `${this.turn}:${runtime.currentState}:${cause}`;
    if (memory.consumedSignals.includes(signalKey)) return false;
    const transition = graph.transitions.find(candidate => this._planTransitionMatches(candidate, cause, memory));
    if (!transition || transition.to === runtime.currentState) return false;
    const from = runtime.currentState;
    runtime.currentState = transition.to;
    const retainedStates = graph.blockContract?.retainInStates;
    if (graph.blockContract?.releaseOnExit === true
      && Array.isArray(retainedStates)
      && retainedStates.includes(from)
      && !retainedStates.includes(transition.to)) {
      // This is an authored lifecycle release, not a player-produced break.
      // It therefore clears block without emitting enemy_block_broken.
      this.enemy.block = 0;
    }
    runtime.transitionSequence += 1;
    const payload = {
      planId: runtime.planId,
      from,
      to: transition.to,
      cause,
      turn: this.turn,
      sourceCardId: this.originalCard?.id || null
    };
    runtime.lastTransition = { ...payload, sequence: runtime.transitionSequence };
    memory.consumedSignals.push(signalKey);
    // State IDs are authority keys, not player copy.  Publish authored labels
    // on the ephemeral presentation event while keeping the saved transition
    // receipt identifier-only for deterministic replay.
    const fromLabel = graph.states[from]?.label || '';
    const nextLabel = graph.states[transition.to]?.label || transition.to;
    eventBus.emit('combat:planTransition', { ...payload, fromLabel, toLabel: nextLabel });
    this._addLog(`敌策转势：${nextLabel}`);
    if (options.refreshIntent !== false) this._generateEnemyIntent();
    return true;
  }

  _resolveEncounterActionFamily(card, fallbackPath = null) {
    const allowed = new Set(['sword', 'spell', 'body', 'pill']);
    const tags = Array.isArray(card?.tags) ? card.tags : [];
    const tagged = [...new Set(tags.map(tag => String(tag).trim()).filter(tag => allowed.has(tag)))];
    if (tagged.length === 1) return tagged[0];
    if (tagged.length > 1) return null;
    const declared = String(card?.legacyPath || card?.path || '').trim();
    if (allowed.has(declared)) return declared;
    const memoryFallback = this.enemy?.planRuntime?.encounterMemory?.fallbackActionFamily;
    const requestedFallback = String(fallbackPath || memoryFallback
      || ((typeof gameState !== 'undefined' && gameState?.path) ? gameState.path : '')).trim();
    const normalizedFallback = requestedFallback === 'alchemy' ? 'pill' : requestedFallback;
    return allowed.has(normalizedFallback) ? normalizedFallback : null;
  }

  _resolveEncounterSemanticActionFamily(card) {
    if (String(card?.type || '') === 'attack') return 'attack';
    const effects = Array.isArray(card?.effects) ? card.effects : [];
    if (effects.some(effect => effect?.type === 'block' && Number(effect?.value) > 0)) return 'guard';
    return 'skill';
  }

  _resolveEncounterPlanCard(card) {
    const runtime = this.enemy?.planRuntime;
    const memory = runtime?.encounterMemory;
    const graph = this._getEnemyPlanGraph();
    const supportedKinds = new Set(['first_action_family_v1', 'first_action_family_and_semantic_action_v2']);
    if (!runtime || !memory || !supportedKinds.has(memory.kind)
      || graph?.memoryContract?.kind !== memory.kind) return false;
    const family = this._resolveEncounterActionFamily(card, memory.fallbackActionFamily);
    if (!graph.memoryContract.allowedFamilies.includes(family)) return false;
    const semanticActionFamily = this._resolveEncounterSemanticActionFamily(card);
    if (memory.kind === 'first_action_family_and_semantic_action_v2'
      && !graph.memoryContract.allowedSemanticActionFamilies.includes(semanticActionFamily)) return false;
    if (memory.capturedFirstActionFamily === null) {
      memory.capturedFirstActionFamily = family;
      memory.capturedFirstActionCardId = String(card?.id || '');
      if (memory.kind === 'first_action_family_and_semantic_action_v2') {
        memory.capturedFirstSemanticActionFamily = semanticActionFamily;
      }
      memory.captureSequence += 1;
      memory.sequenceBroken = false;
      const transitioned = this._transitionEnemyPlan('first_card_recorded', {
        refreshIntent: Number(this.enemy?.hp) > 0
      });
      eventBus.emit('combat:firstCardRecorded', {
        planId: runtime.planId,
        family,
        semanticActionFamily,
        cardId: memory.capturedFirstActionCardId,
        turn: this.turn,
        transitioned
      });
      return true;
    }
    const breakSequence = memory.kind === 'first_action_family_and_semantic_action_v2'
      ? memory.capturedFirstSemanticActionFamily !== semanticActionFamily
      : memory.capturedFirstActionFamily !== family;
    if (breakSequence && memory.sequenceBroken !== true) {
      const transitioned = this._transitionEnemyPlan('sequence_broken', {
        refreshIntent: Number(this.enemy?.hp) > 0
      });
      if (!transitioned) return false;
      memory.sequenceBroken = true;
      eventBus.emit('combat:mirrorSequenceBroken', {
        planId: runtime.planId,
        capturedFamily: memory.capturedFirstActionFamily,
        playedFamily: family,
        capturedSemanticActionFamily: memory.capturedFirstSemanticActionFamily || null,
        playedSemanticActionFamily: semanticActionFamily,
        cardId: String(card?.id || ''),
        turn: this.turn,
        transitioned
      });
      return true;
    }
    return false;
  }

  _signalEnemyBlockBroken(before, after, sourceCard = null) {
    const blockBefore = Number(before);
    const blockAfter = Number(after);
    if (!(blockBefore > 0) || blockAfter !== 0) return false;
    const transitioned = this._transitionEnemyPlan('enemy_block_broken', {
      refreshIntent: Number(this.enemy?.hp) > 0
    });
    if (!transitioned) return false;
    eventBus.emit('combat:enemyBlockBroken', {
      planId: this.enemy?.planRuntime?.planId || null,
      sourceCardId: sourceCard?.id || sourceCard || null,
      before: blockBefore,
      after: blockAfter,
      turn: this.turn
    });
    return true;
  }

  _evaluatePlanCardSignals() {
    const runtime = this.enemy?.planRuntime;
    const graph = this._getEnemyPlanGraph();
    const memory = runtime?.turnMemory;
    if (!runtime || !graph || !memory) return false;
    const candidate = graph.transitions.find(transition =>
      ['player_overcommitted', 'repeated_card_type'].includes(transition.when)
      && this._planTransitionMatches(transition, transition.when, memory)
    );
    return candidate ? this._transitionEnemyPlan(candidate.when) : false;
  }

  _settleEnemyPlanAction(resolvedIntent) {
    const runtime = this.enemy?.planRuntime;
    if (!runtime || !resolvedIntent?.planState || runtime.currentState !== resolvedIntent.planState) return false;
    return this._transitionEnemyPlan('action_resolved', { refreshIntent: false });
  }

  _validatePlanRuntimeSnapshot(runtime, graph, snapshot, authoritativeCardDB = {}) {
    if (!runtime || runtime.version !== 1 || runtime.planId !== graph.planId) return false;
    if (!graph.states[runtime.currentState] || !graph.states[runtime.intentState]) return false;
    const sequence = Number(runtime.transitionSequence);
    if (!Number.isInteger(sequence) || sequence < 0 || sequence > 10000) return false;
    const memory = runtime.turnMemory;
    if (!memory || typeof memory !== 'object' || Array.isArray(memory)) return false;
    const encounterMemory = runtime.encounterMemory;
    if (['first_action_family_v1', 'first_action_family_and_semantic_action_v2']
      .includes(graph.memoryContract?.kind)) {
      const allowedFamilies = graph.memoryContract.allowedFamilies;
      const captured = encounterMemory?.capturedFirstActionFamily;
      const isSemanticSequence = graph.memoryContract.kind === 'first_action_family_and_semantic_action_v2';
      const capturedSemanticFamily = encounterMemory?.capturedFirstSemanticActionFamily;
      if (!encounterMemory || encounterMemory.kind !== graph.memoryContract.kind
        || !allowedFamilies.includes(encounterMemory.fallbackActionFamily)
        || !(captured === null || allowedFamilies.includes(captured))
        || (isSemanticSequence
          && !(capturedSemanticFamily === null
            || graph.memoryContract.allowedSemanticActionFamilies.includes(capturedSemanticFamily)))
        || !(encounterMemory.capturedFirstActionCardId === null
          || (typeof encounterMemory.capturedFirstActionCardId === 'string'
            && encounterMemory.capturedFirstActionCardId.trim()))
        || !Number.isInteger(Number(encounterMemory.captureSequence))
        || Number(encounterMemory.captureSequence) < 0
        || Number(encounterMemory.captureSequence) > 1
        || typeof encounterMemory.sequenceBroken !== 'boolean'
        || (captured === null && (encounterMemory.capturedFirstActionCardId !== null
          || (isSemanticSequence && capturedSemanticFamily !== null)
          || Number(encounterMemory.captureSequence) !== 0
          || encounterMemory.sequenceBroken !== false))
        || (captured !== null && (Number(encounterMemory.captureSequence) !== 1
          || encounterMemory.capturedFirstActionCardId === null
          || (isSemanticSequence
            && !graph.memoryContract.allowedSemanticActionFamilies.includes(capturedSemanticFamily))))) return false;
    } else if (encounterMemory !== undefined && encounterMemory !== null) {
      return false;
    }
    const cardsPlayed = Number(memory.cardsPlayed);
    const qiSpent = Number(memory.qiSpent);
    const qiGained = Number(memory.qiGained);
    const qiRemaining = Number(memory.qiRemaining);
    if (Number(memory.turn) !== Number(snapshot.turn)
      || !Number.isInteger(cardsPlayed) || cardsPlayed < 0
      || !Number.isFinite(qiSpent) || qiSpent < 0
      || !Number.isFinite(qiGained) || qiGained < 0 || qiGained > 50
      || !Number.isFinite(qiRemaining) || qiRemaining < 0
      || qiRemaining !== Number(snapshot.qi)
      || qiRemaining > Number(snapshot.maxQi) + 5
      || !Array.isArray(memory.cardTypes)
      || memory.cardTypes.length !== cardsPlayed
      || memory.cardTypes.some(type => typeof type !== 'string' || !type)) return false;
    if (!Array.isArray(memory.playedCards) || memory.playedCards.length !== cardsPlayed) return false;
    const legacyQiSpent = Number(memory.legacyQiSpent || 0);
    if (!Number.isFinite(legacyQiSpent) || legacyQiSpent < 0 || legacyQiSpent > Number(snapshot.maxQi)) return false;
    if (runtime.migration && runtime.migration !== 'legacy_planless_v1') return false;
    if (!runtime.migration && legacyQiSpent !== 0) return false;
    let authoredSpent = 0;
    for (const [index, played] of memory.playedCards.entries()) {
      if (!played || typeof played.id !== 'string' || !played.id || played.type !== memory.cardTypes[index]) return false;
      const baseId = played.id.replace(/\++$/, '');
      const authored = authoritativeCardDB[played.id] || authoritativeCardDB[baseId];
      if (!authored || authored.type !== played.type || Number(authored.cost) !== Number(played.cost)) return false;
      authoredSpent += Math.max(0, Number(played.cost) || 0);
    }
    if (authoredSpent + legacyQiSpent !== qiSpent
      || Number(snapshot.maxQi) + qiGained - qiSpent !== qiRemaining) return false;
    const expectedType = cardsPlayed > 0 ? memory.cardTypes[cardsPlayed - 1] : null;
    let expectedConsecutive = 0;
    for (let index = memory.cardTypes.length - 1; index >= 0 && memory.cardTypes[index] === expectedType; index--) {
      expectedConsecutive += 1;
    }
    if (memory.consecutiveType !== expectedType
      || Number(memory.consecutiveCount) !== expectedConsecutive) return false;
    if (!Array.isArray(memory.consumedSignals)
      || memory.consumedSignals.length > 64
      || new Set(memory.consumedSignals).size !== memory.consumedSignals.length
      || memory.consumedSignals.some(signal => typeof signal !== 'string' || !signal.startsWith(`${snapshot.turn}:`))) {
      return false;
    }
    const allowedReactions = new Set([null, 'GUARD', 'DEFLECT', 'INTERRUPT', 'ABSORB', 'TRANSMUTE', 'EVADE', 'TAKE_HIT']);
    if (!allowedReactions.has(runtime.lastReaction ?? null)) return false;
    if (sequence === 0) return runtime.lastTransition === null;
    const last = runtime.lastTransition;
    if (!last || Number(last.sequence) !== sequence
      || last.planId !== graph.planId
      || last.to !== runtime.currentState
      || Number(last.turn) > Number(snapshot.turn)
      || last.sourceCardId !== snapshot.originalCard.id) return false;
    const authored = graph.transitions.some(transition =>
      transition.from.includes(last.from)
      && transition.to === last.to
      && transition.when === last.cause
    );
    return authored;
  }

  _migratePlanlessSnapshot(graph, snapshot) {
    const fields = ['type', 'value', 'statusId', 'actionName', 'desc'];
    const matched = Object.entries(graph.states).find(([, state]) =>
      fields.every(field => state.intent?.[field] === snapshot.enemyIntent?.[field])
    );
    const stateId = matched?.[0] || graph.initialState;
    const runtime = this._createPlanRuntime(graph, snapshot.turn, snapshot.qi);
    runtime.migration = 'legacy_planless_v1';
    runtime.currentState = stateId;
    runtime.intentState = stateId;
    const legacyQiSpent = Math.max(0, Number(snapshot.maxQi) - Number(snapshot.qi));
    runtime.turnMemory.qiSpent = legacyQiSpent;
    runtime.turnMemory.legacyQiSpent = legacyQiSpent;
    runtime.turnMemory.qiRemaining = Number(snapshot.qi);
    const state = graph.states[stateId];
    return {
      runtime,
      intent: {
        ...JSON.parse(JSON.stringify(state.intent)),
        planId: graph.planId,
        planState: stateId,
        planStateLabel: state.label,
        planCue: state.cue,
        transitionCause: 'legacy_planless_migration'
      }
    };
  }

  _createEnemy(phaseData, rootData = phaseData) {
    const tier = phaseData.tier || rootData.tier || 1;
    const rawHp = phaseData.hp || (tier === 2 ? 8 : tier === 3 ? 15 : 3);
    const rawAtk = phaseData.atk || rootData.atk || tier;
    const rawDef = phaseData.def || rootData.def || 0;
    const hp = rawHp;
    const atk = rawAtk;
    const defense = rawDef;
    const templateDef = this._resolveEnemyDef(phaseData, tier);
    // 遭遇可以覆写模板意图。这样共享行为骨架的敌人不必继续使用错误的
    // 动作台词，也能把内容文案宣称的机制真正落到执行层。
    const inlineIntents = Array.isArray(phaseData.intents)
      ? phaseData.intents
      : (Array.isArray(rootData.intents) ? rootData.intents : null);
    const enemyDef = inlineIntents
      ? {
          ...(templateDef || {}),
          id: `${phaseData.templateId || phaseData.id || rootData.templateId || 'encounter'}:inline`,
          name: phaseData.name || rootData.name || templateDef?.name,
          intents: inlineIntents,
          randomIntents: phaseData.randomIntents ?? rootData.randomIntents ?? false
        }
      : templateDef;
    // A fixed turnCycle is an explicit player-facing mechanic.  Keep any
    // authored plan graph in data for non-cycle encounters, but never install
    // it into this combat runtime where it could overwrite that cadence.
    const planGraph = this._getAuthoritativeTurnCycle()
      ? null
      : this._normalizePlanGraph(phaseData.planGraph || rootData.planGraph || templateDef?.planGraph);
    const resolvedEnemyDef = enemyDef
      ? { ...enemyDef, planGraph }
      : (planGraph ? { intents: [], planGraph } : null);
    return {
      name: phaseData.name || (enemyDef && enemyDef.name) || rootData.name || '修仙者',
      hp,
      maxHp: hp,
      block: phaseData.block || 0,
      tier,
      atkPower: atk,
      defPower: defense,
      def: resolvedEnemyDef,
      planRuntime: this._createPlanRuntime(planGraph),
      intentIndex: 0,
      factionId: phaseData.factionId || rootData.factionId || null,
      // tier 表示普通/精英/Boss，不是修仙境界。境界压制必须使用真实 realm 比较。
      realm: phaseData.realm || rootData.realm || this.originalCard?.realm || gameState.realm
    };
  }

  _advanceBossPhase() {
    if (!this.bossPhases.length || this.bossPhaseIndex >= this.bossPhases.length - 1) return false;
    const previous = this.bossPhaseIndex + 1;
    this.bossPhaseIndex++;
    const phase = this.bossPhases[this.bossPhaseIndex];
    this.enemy = this._createEnemy(phase, this.originalCard.enemy);
    this.enemyStatus = {};
    if (phase.entryEffect?.block) this.enemy.block += phase.entryEffect.block;
    if (phase.entryEffect?.playerDamage) this._dealDamage(this.player, phase.entryEffect.playerDamage);
    this._addLog(`—— Boss 转入第 ${this.bossPhaseIndex + 1} 阶段：【${this.enemy.name}】——`);
    eventBus.emit('combat:bossPhaseChanged', {
      sourceCardId: this.originalCard?.id || null,
      previous,
      current: this.bossPhaseIndex + 1,
      total: this.bossPhases.length,
      phase,
      enemy: this.enemy,
      // State was already committed above. This carries visual data only so
      // the UI never guesses a phase transition from a name or HP reset.
      phaseTransition: this._resolveBossPhaseTransitionContract({
        current: this.bossPhaseIndex + 1,
        total: this.bossPhases.length
      })
    });
    this._generateEnemyIntent();
    this._triggerUpdate();
    return true;
  }

  _handleEnemyDefeated() {
    // Outcome settlement is terminal. A passive can reach this method before
    // the source card pipeline reaches its own death check, so ignore any
    // later checks once victory/defeat/flee has closed the combat.
    if (!this.active) return false;
    if (this.enemy.hp > 0) return false;
    this.enemy.hp = 0;
    if (!this._advanceBossPhase()) {
      // Enemy collapse is a presentation-only consumer of the already-final
      // HP fact.  It starts before victory so an ordinary enemy reads as a
      // body that was defeated, not as a number that silently disappears.
      // The existing victory pipeline remains the single settlement owner.
      const collapsePresentation = this._emitEnemyPresentationAction('defeat', {
        target: 'enemy',
        sourceId: 'enemy_defeated',
        originActionId: this._activeSemanticAction?.actionId || null
      });
      // A mounted defeat body is not allowed to be immediately covered by the
      // reward card. Only its authored presentation duration delays settlement;
      // HP=0, rewards and every numerical outcome retain their existing owner.
      const collapseDelay = collapsePresentation?.animation?.kind === 'frame_sequence'
        && collapsePresentation?.animation?.motionApproved === true
        ? Math.max(0, Number(collapsePresentation.duration) || 0)
        : 0;
      this._victory({ settlementDelayMs: collapseDelay });
    }
    return true;
  }

  _generateEnemyIntent() {
    const turnCycleIntent = this._generateTurnCycleIntent();
    if (turnCycleIntent) {
        this.enemyIntent = turnCycleIntent;
        return;
    }
    const planGraph = this._getEnemyPlanGraph();
    const planRuntime = this.enemy?.planRuntime;
    if (planGraph && planRuntime && planGraph.states?.[planRuntime.currentState]) {
        const state = planGraph.states[planRuntime.currentState];
        planRuntime.intentState = planRuntime.currentState;
        const capturedFamily = planRuntime.encounterMemory?.capturedFirstActionFamily;
        const presentationVariantId = planRuntime.currentState === 'ECHO'
          && ['first_action_family_v1', 'first_action_family_and_semantic_action_v2']
            .includes(planGraph.memoryContract?.kind)
          && planGraph.memoryContract.allowedFamilies.includes(capturedFamily)
          ? `ECHO_${capturedFamily}`
          : planRuntime.currentState;
        this.enemyIntent = {
            ...JSON.parse(JSON.stringify(state.intent)),
            planId: planRuntime.planId,
            planState: planRuntime.currentState,
            planStateLabel: state.label,
            planCue: state.cue,
            transitionCause: planRuntime.lastTransition?.cause || null,
            presentationVariantId
        };
        return;
    }
    if (this.enemy.def && this.enemy.def.intents) {
        const intents = this.enemy.def.intents;

        // 1. 检查条件意图 (如血量低于 50% 触发)
        let conditionalIntent = null;
        for (const intent of intents) {
            if (intent.condition && intent.condition.type === 'hp_below') {
                const threshold = intent.condition.value;
                if ((this.enemy.hp / this.enemy.maxHp) <= threshold) {
                    if (!this.enemy.usedConditions) this.enemy.usedConditions = new Set();
                    if (!this.enemy.usedConditions.has(intent.desc) || intent.condition.repeatable) {
                        conditionalIntent = intent;
                        this.enemy.usedConditions.add(intent.desc);
                        break; // 优先触发第一个满足条件的
                    }
                }
            }
        }

        if (conditionalIntent) {
            this.enemyIntent = conditionalIntent;
        } else {
            const normalIntents = intents.filter(i => !i.condition);
            if (normalIntents.length > 0) {
                if (this.enemy.def.randomIntents) {
                    // 2. 随机意图抽取
                    this.enemyIntent = normalIntents[Math.floor(Math.random() * normalIntents.length)];
                } else {
                    // 3. 按照配置的意图列表循环执行
                    this.enemyIntent = normalIntents[this.enemy.intentIndex % normalIntents.length];
                    this.enemy.intentIndex++;
                }
            } else {
                this.enemyIntent = { type: 'attack', value: this.enemy.atkPower, desc: `意图：攻击 (${this.enemy.atkPower}点伤害)` };
            }
        }
    } else {
        // Fallback 极简意图逻辑
        const intents = [];
        const atkVal = this.enemy.atkPower || this.enemy.tier || 1;
        if (this.enemy.tier === 1) {
           intents.push({ type: 'attack', value: atkVal, desc: `意图：攻击 (${atkVal}点伤害)` });
        } else if (this.enemy.tier === 2) {
           if (this.turn % 3 === 0) {
               intents.push({ type: 'debuff', value: 1, desc: '意图：施加负面状态' });
           } else {
               intents.push({ type: 'attack', value: atkVal, desc: `意图：攻击 (${atkVal}点伤害)` });
           }
        } else {
           intents.push({ type: 'attack', value: atkVal, desc: `意图：攻击 (${atkVal}点伤害)` });
        }
        this.enemyIntent = intents[0];
    }
  }

  _drawCards(count) {
    for (let i = 0; i < count; i++) {
        this._drawCard();
    }
  }

  _drawCard(ignoreHandLimit = false) {
    if (!ignoreHandLimit && this.hand.length >= 5) return;

    if (this.drawPile.length > 0) {
        this.hand.push(this.drawPile.pop());
    } else {
      if (this.discardPile.length > 0) {
        this.drawPile = [...this.discardPile];
        this.discardPile = [];
        this._shuffle(this.drawPile);
        this.hand.push(this.drawPile.pop());
      }
    }
  }

  _shuffle(array) {
    for (let i = array.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [array[i], array[j]] = [array[j], array[i]];
    }
  }

  // === 玩家行动 ===

  playCard(handIndex, target = 'enemy') {
    if (!this.active) return false;
    if (this.phase !== 'PLAYER_TURN') return false;
    if (this.isPlayerInputLocked()) return false;
    if (handIndex < 0 || handIndex >= this.hand.length) return false;

    const cardId = this.hand[handIndex];
    const card = this.getCardDef(cardId);
    if (!card) return false;

    if (this.qi < card.cost) {
        this._addLog(`真元不足！需要 ${card.cost}，当前 ${this.qi}`);
        return false;
    }

    this._pendingPathSynergyReceipt = null;
    this._cardSynergy = null;
    if (typeof pathArchetypeSystem !== 'undefined' && pathArchetypeSystem) {
      this._cardSynergy = pathArchetypeSystem.beforeCard(card, {
        player: this.player,
        enemy: this.enemy,
        playerStatus: this.playerStatus,
        enemyStatus: this.enemyStatus,
        qi: this.qi,
        maxQi: this.maxQi
      });
      if (this._cardSynergy) {
        this._cardSynergy.damageConsumed = false;
        this._cardSynergy.blockConsumed = false;
        for (const activation of this._cardSynergy.activations || []) {
          activation.consumption = { damageBonus: 0, blockBonus: 0 };
          activation.appliedDelta = { gainQi: 0 };
          activation.damageOutcomes = [];
        }
      }
    }

    // 扣费并出牌
    this.qi -= card.cost;
    const playedCard = this.hand.splice(handIndex, 1)[0];
    this._recordPlanCardPlayed(card, card.cost);
    this._evaluatePlanCardSignals();
    const presentation = this._getPresentationContext();
    const artKey = String(card.id || cardId || '').replace(/\+$/, '');
    const art = presentation.cardArt?.[card.id] || presentation.cardArt?.[cardId] || presentation.cardArt?.[artKey] || null;
    const cardPresentation = presentation.cardProvenance?.[card.id] || presentation.cardProvenance?.[cardId] || null;
    eventBus.emit('combat:cardCommitted', {
      cardId: card.id || cardId,
      cardName: cardPresentation?.displayName || card.name,
      cardType: card.type,
      target,
      presentationId: presentation.presentationId || null,
      artId: art?.id || null,
      artImage: art?.image || null
    });
    const storyAssist = this._storyAssistContract();
    if (storyAssist?.cardId === (card.id || cardId)) {
      eventBus.emit('combat:storyAssistCommitted', {
        assistId: storyAssist.id,
        companionId: storyAssist.compId,
        companionName: storyAssist.companionName,
        cardId: storyAssist.cardId,
        cardName: card.name || storyAssist.unlockText,
        mechanism: storyAssist.mechanism,
        turn: this.turn,
        encounterId: this.originalCard?.id || null
      });
      this._addLog(`【${storyAssist.companionName}·援护】${storyAssist.unlockText}！`);
    }
    this._emitEquippedTreasureTrigger(card, presentation);

    if (card.flavor) {
        this._addLog(`你打出【${card.name}】：“${card.flavor}”`);
    } else {
        this._addLog(`打出：【${card.name}】`);
    }

    // Equipment Passives for onCardPlay
    this._triggerEquipmentPassives('onCardPlay', card);
    // Equipment damage resolves before the authored card effects. If it ends
    // combat, the remainder of this card pipeline must not touch the closed
    // encounter or settle its rewards a second time.
    if (!this.active) {
        this._cardSynergy = null;
        return true;
    }

    // 数据驱动的攻击反噬：攻击类型、伤害与免疫标记均由当前 Boss 卡定义。
    const attackBacklash = this.originalCard?.combatRules?.attackBacklash;
    if (attackBacklash && card.type === (attackBacklash.triggerCardType || 'attack')) {
        const counterFlag = attackBacklash.counter?.flag;
        const counterActive = counterFlag
          && typeof gameState !== 'undefined'
          && gameState.hasFlag(counterFlag);
        const backlashDamage = Math.max(0, Math.floor(Number(attackBacklash.damage) || 0));
        if (!counterActive && backlashDamage > 0) {
            this._addLog(`【天机反噬】雷劫锁定你的攻击气机，天雷反震 ${backlashDamage} 点！`);
            this.player.hp = Math.max(0, this.player.hp - backlashDamage);
            this._emitCombatFeedback('player', 'damage', backlashDamage, { caption: '天机反噬' });
            this._checkPlayerDeath();
            if (!this.active) return true;
        }
    }

    // 解析效果
    const effects = Array.isArray(card.effects) ? card.effects : [];
    // Authored battle cards express a defensive resolution as `block`.
    // `gain_block` was a stale vocabulary from an earlier schema, so every
    // real guard card silently presented as a generic skill and its mounted
    // defensive action sequence could never be reached.
    const semanticPresentation = this._deriveCardSemanticPresentation(card);
    const actionFamily = semanticPresentation.actionFamily;
    this._beginSemanticAction({
      actionFamily,
      source: 'player',
      target: semanticPresentation.target,
      sourceId: card.id || cardId
    });
    this._lockPlayerInputForSemanticAction();
    const authoredCueEmitted = this._emitActionPresentationCues();
    if (!authoredCueEmitted) {
      if (actionFamily === 'attack') this._emitPresentationVfx('slash', 'enemy');
      else this._emitPresentationVfx('aura', 'player');
    }
    effects.forEach((effect, effectIndex) => {
       this._resolveEffect(effect, target, card, effectIndex);
    });

    if (this._cardSynergy) {
      for (const status of this._cardSynergy.enemyStatuses || []) this._addStatus('enemy', status.id, status.value || 1);
      for (const status of this._cardSynergy.playerStatuses || []) this._addStatus('player', status.id, status.value || 1);
      if (this._cardSynergy.gainQi) {
        const qiBeforeSynergy = this.qi;
        this.qi = Math.min(this.maxQi + 5, this.qi + this._cardSynergy.gainQi);
        let remainingGain = this.qi - qiBeforeSynergy;
        for (const activation of this._cardSynergy.activations || []) {
          const applied = Math.min(Math.max(0, activation.requestedDelta.gainQi), Math.max(0, remainingGain));
          activation.appliedDelta.gainQi = applied;
          remainingGain -= applied;
        }
      }
      for (const text of this._cardSynergy.texts || []) this._addLog(`流派联动：${text}！`);
    }

    // 触发打牌主视效
    // 遗物联动 (例如：每回合第一张攻击牌)
    if (card.type === 'attack') {
       this._triggerRelic('play_attack');
    }

    // 弃牌或消耗
    if (card.exhaust) {
       this.exhaustPile.push(playedCard);
    } else {
       this.discardPile.push(playedCard);
    }
    if (this.enemy?.planRuntime?.turnMemory) {
       const memory = this.enemy.planRuntime.turnMemory;
       memory.qiRemaining = this.qi;
       memory.qiGained = Math.max(0, this.qi + memory.qiSpent - this.maxQi);
    }

    // Encounter memory is written only after the card's authored effects,
    // synergies, relics and destination pile have all resolved. Rejected or
    // unaffordable plays never reach this point, so TRACE cannot record a UI
    // click or an attempted card as the mirrored first action.
    this._resolveEncounterPlanCard(card);

    // This is an observation of completed effects, not another rule engine or
    // state clock. Ordinary cards publish only after their existing checkpoint
    // persisted; a terminal card waits for the source-outcome acknowledgement.
    const pathReceipt = this._buildPathSynergyReceipt(card);
    this._pendingPathSynergyReceipt = pathReceipt;

    // 检查敌人死亡
    if (this.enemy?.hp <= 0) this._emitSemanticActionPhase('combat:actorDefeated', { actor: 'enemy' });
    this._completeSemanticAction();
    // `_handleEnemyDefeated()` settles victory synchronously and makes
    // `getState()` intentionally unavailable. Emit one last authoritative
    // active-combat snapshot first so the visible HP readout reaches 0 before
    // the enemy's terminal body sequence is allowed to hold the screen.
    // Without this, the collapse can visibly coexist with the stale pre-hit
    // value until the terminal presentation closes.
    if (this.enemy?.hp <= 0) this._triggerUpdate();
    const phaseBeforeEnemyResolution = this.bossPhaseIndex;
    if (this._handleEnemyDefeated()) {
        // A genuine phase advance remains an accepted play. A terminal
        // rejection, however, restores an earlier hand/ledger and must not
        // append this discarded lethal input against the restored owner.
        if (this.active && this.bossPhaseIndex === phaseBeforeEnemyResolution + 1) {
          this._recordAuthorityCheckpoint('CARD_PLAY', {
            cardId: playedCard,
            definitionId: card.id || cardId,
            handIndex
          });
          if (this._persistCombatSession()) this._publishPathSynergyReceipt(pathReceipt);
          else this._pendingPathSynergyReceipt = null;
        }
        this._cardSynergy = null;
        return true;
    }

    this._cardSynergy = null;
    this._recordAuthorityCheckpoint('CARD_PLAY', {
      cardId: playedCard,
      definitionId: card.id || cardId,
      handIndex
    });
    this._triggerUpdate();
    if (this._persistCombatSession()) this._publishPathSynergyReceipt(pathReceipt);
    else this._pendingPathSynergyReceipt = null;
    return true;
  }

  _buildPathSynergyReceipt(card) {
    const synergy = this._cardSynergy;
    const owner = this.encounterContext?.encounterInstanceId;
    if (!synergy?.feedback?.cueId || !synergy.activations?.length || !owner) return null;
    const settlementSequence = this._authorityLedger.length + 1;
    const lifeId = gameState.runClock?.lifeId;
    const saveSlotId = gameState.getActiveSaveSlotId?.();
    return JSON.parse(JSON.stringify({
      encounterInstanceId: owner,
      lifeId, saveSlotId,
      turn: this.turn,
      settlementSequence,
      settlementId: `path-synergy:${saveSlotId}:${lifeId}:${owner}:${settlementSequence}`,
      pathId: synergy.pathId,
      archetypeId: synergy.archetypeId,
      sourceCardId: card.id,
      triggerCardIds: [...new Set(synergy.activations.flatMap(item => item.triggerCardIds))],
      activations: synergy.activations,
      feedbackCueId: synergy.feedback.cueId,
      feedback: synergy.feedback,
      actionId: this._activeSemanticAction?.actionId || null
    }));
  }

  _publishPathSynergyReceipt(receipt, { terminalAccepted = false } = {}) {
    if (!receipt || this._pendingPathSynergyReceipt !== receipt
      || receipt.encounterInstanceId !== this.encounterContext?.encounterInstanceId
      || receipt.lifeId !== gameState.runClock?.lifeId
      || receipt.saveSlotId !== gameState.getActiveSaveSlotId?.()) return false;
    const entry = this._authorityLedger[this._authorityLedger.length - 1];
    if (!terminalAccepted && (entry?.kind !== 'CARD_PLAY' || entry.sequence !== receipt.settlementSequence)) return false;
    this._pendingPathSynergyReceipt = null;
    eventBus.emit('combat:pathSynergyResolved', JSON.parse(JSON.stringify(receipt)));
    return true;
  }

  _getBossPhaseTransitionDefinition() {
    const registry = this._actionPresentationData || {};
    const sourceCardId = String(this.originalCard?.id || '');
    const definition = registry.bossPhaseTransitions?.[sourceCardId];
    const animation = definition?.animation;
    const frames = Array.isArray(animation?.frames)
      ? animation.frames.filter(frame => typeof frame === 'string' && frame.trim())
      : [];
    const frameDurations = Array.isArray(animation?.frameDurations)
      ? animation.frameDurations.map(duration => Math.max(16, Number(duration) || 0))
      : [];
    if (!sourceCardId
      || definition?.sourceCardId !== sourceCardId
      || !definition.presentationId
      || !definition.frameSetId
      || animation?.kind !== 'frame_sequence'
      || animation?.motionApproved !== true
      || animation?.frameSetId !== definition.frameSetId
      || frames.length < 2
      || frameDurations.length !== frames.length
      || frameDurations.some(duration => !Number.isFinite(duration) || duration < 16)) return null;
    return {
      presentationId: String(definition.presentationId),
      frameSetId: String(definition.frameSetId),
      sourceCardId,
      duration: Math.max(1, Number(definition.duration) || frameDurations.reduce((sum, duration) => sum + duration, 0)),
      label: String(definition.label || '首领转相'),
      phaseCues: JSON.parse(JSON.stringify(definition.phaseCues || {})),
      animation: {
        kind: 'frame_sequence',
        frameSetId: String(definition.frameSetId),
        anchor: animation.anchor || 'center',
        frames: [...frames],
        frameDurations: [...frameDurations],
        motionApproved: true,
        artApproval: animation.artApproval || null
      },
      reducedMotionFallback: definition.reducedMotionFallback || 'phase_label_with_updated_enemy_intent'
    };
  }

  _resolveBossPhaseTransitionContract({ current, total } = {}) {
    const definition = this._getBossPhaseTransitionDefinition();
    const phaseNumber = Math.floor(Number(current) || 0);
    const phaseTotal = Math.floor(Number(total) || 0);
    if (!definition || phaseNumber < 2 || phaseNumber > phaseTotal) return null;
    const owner = String(this.encounterContext?.encounterInstanceId || definition.sourceCardId)
      .replace(/[^a-zA-Z0-9:_-]/g, '_');
    return {
      ...definition,
      current: phaseNumber,
      total: phaseTotal,
      eventId: `boss-phase:${owner}:${phaseNumber}`,
      phaseCue: JSON.parse(JSON.stringify(definition.phaseCues?.[String(phaseNumber)] || {}))
    };
  }

  _persistCombatSession() {
    if (!this.active || typeof gameState === 'undefined'
      || typeof gameState?.persistCausalSession !== 'function') return false;
    return gameState.persistCausalSession();
  }

  // === 装备被动处理 ===
  _equipmentPassiveStateKey(passive, index) {
    if (passive?.oncePerCombat === true) {
      const sourceId = String(passive.sourceItemId || `slot_${index}`);
      const passiveId = String(passive.passiveId || `passive_${index}`);
      return `eq_once:${sourceId}:${passiveId}`;
    }
    return `eq_${index}`;
  }

  _equipmentDistinctTagStateKey(passive, index) {
    const sourceId = String(passive?.sourceItemId || `slot_${index}`);
    const passiveId = String(passive?.passiveId || `passive_${index}`);
    return `eq_tags:${sourceId}:${passiveId}`;
  }

  _equipmentDistinctTag(passive, card) {
    if (!passive || !card || !Array.isArray(card.tags)) return null;
    // A played card can carry several descriptive tags. The first authored
    // combat tag is its declared lineage; generic starter/temporary labels do
    // not let one card satisfy a three-route contract by itself.
    const tag = card.tags.find(candidate => typeof candidate === 'string'
      && candidate.trim()
      && !['starter', 'temporary', 'reward', 'qi'].includes(candidate.trim()));
    return tag ? tag.trim() : null;
  }

  _equipmentProgressView() {
    if (typeof equipmentSystem === 'undefined' || !equipmentSystem) return [];
    return equipmentSystem.getActivePassives().flatMap((passive, index) => {
      const threshold = Math.max(0, Math.floor(Number(passive?.distinctTagsThreshold) || 0));
      if (!threshold || !passive?.temporaryTacticalCardId) return [];
      const tags = Array.isArray(this.equipmentState?.[this._equipmentDistinctTagStateKey(passive, index)])
        ? [...this.equipmentState[this._equipmentDistinctTagStateKey(passive, index)]] : [];
      const unlocked = Number(this.equipmentState?.[this._equipmentPassiveStateKey(passive, index)]) > 0;
      const ready = unlocked && this.hand.includes(passive.temporaryTacticalCardId);
      const used = unlocked && !ready && this.exhaustPile.includes(passive.temporaryTacticalCardId);
      return [{
        sourceItemId: passive.sourceItemId || null,
        sourceItemName: passive.sourceItemName || '装备',
        threshold,
        tags,
        unlocked,
        ready,
        used,
        temporaryTacticalCardId: passive.temporaryTacticalCardId
      }];
    });
  }

  _triggerEquipmentPassives(hook, card = null) {
    if (typeof equipmentSystem === 'undefined' || !equipmentSystem) return;

    const passives = equipmentSystem.getActivePassives();
    passives.forEach((p, idx) => {
      if (p.hook !== hook) return;

      let shouldTrigger = true;
      // 【BUG-2 修复】支持按卡牌类型过滤（attack/skill/power）
      if (hook === 'onCardPlay' && p.cardType && card && card.type !== p.cardType) {
        shouldTrigger = false;
      }
      // 【新增】支持按卡牌标签过滤（如 sword 剑诀类）
      if (hook === 'onCardPlay' && p.cardTag && card) {
        const cardTags = card.tags || [];
        if (!cardTags.includes(p.cardTag)) {
          shouldTrigger = false;
        }
      }

      // 支持本回合未造成伤害判定
      if (hook === 'onTurnEnd' && p.condition === 'noDamageDealt') {
        if (this.damageDealtThisTurn) {
          shouldTrigger = false;
        }
      }

      if (shouldTrigger) {
        const stateKey = this._equipmentPassiveStateKey(p, idx);
        // Once the three-tag sword route has created its one temporary card,
        // that card is not a fourth route ingredient. Freeze its tag receipt
        // before examining later plays so the persisted contract stays at 3.
        if (p.oncePerCombat === true && Number(this.equipmentState[stateKey]) > 0) return;
        const threshold = Math.max(0, Math.floor(Number(p.distinctTagsThreshold) || 0));
        if (threshold > 0) {
          const tag = this._equipmentDistinctTag(p, card);
          if (!tag) return;
          const tagsKey = this._equipmentDistinctTagStateKey(p, idx);
          const seen = Array.isArray(this.equipmentState[tagsKey]) ? this.equipmentState[tagsKey] : [];
          if (!seen.includes(tag)) {
            seen.push(tag);
            this.equipmentState[tagsKey] = seen;
            if (seen.length < threshold) {
              this._addLog(`【${p.sourceItemName || '旧式残剑'}】异路相合 ${seen.length}/${threshold}：${seen.join(' · ')}。`);
            }
          }
          if (seen.length < threshold) return;
        }
        if (p.oncePerCombat === true) {
          this.equipmentState[stateKey] = 1;
          this._applyEquipmentPassiveEffect(p);
        } else if (p.triggerCount) {
          this.equipmentState[stateKey] = (this.equipmentState[stateKey] || 0) + 1;
          if (this.equipmentState[stateKey] >= p.triggerCount) {
            this.equipmentState[stateKey] = 0; // 计数归零，等待下次触发
            this._applyEquipmentPassiveEffect(p);
          }
        } else {
          this._applyEquipmentPassiveEffect(p);
        }
      }
    });
  }

  _applyEquipmentPassiveEffect(p) {
    this._addLog(`✨ 法宝共鸣：【${p.sourceItemName}】发动！`);
    if (p.effect === 'grantTemporaryCard') {
      const cardId = typeof p.temporaryTacticalCardId === 'string' ? p.temporaryTacticalCardId : '';
      if (!cardId || !this.getCardDef(cardId) || this.hand.includes(cardId)
        || this.exhaustPile.includes(cardId) || this.discardPile.includes(cardId)) return;
      this.hand.push(cardId);
      this._addLog(p.logText || `【${p.sourceItemName || '装备'}】悟得一式临时剑路。`);
      this._emitCombatFeedback('player', 'shield', 0, { caption: '旧式剑路已悟' });
    } else if (p.effect === 'dealDamage') {
      // 法宝飞剑/神通直击，绕过护盾直接扣血
      const dmg = p.value || 0;
      this._addLog(`对【${this.enemy.name}】造成 ${dmg} 点法宝贯穿伤害！`);
      this._dealDamage(this.enemy, dmg); // 【BUG-3 修复】原为 _resolveDamage，统一使用 _dealDamage
    } else if (p.effect === 'heal') {
      const heal = p.value || 0;
      const oldHp = this.player.hp;
      this.player.hp = Math.min(this.player.maxHp, this.player.hp + heal);
      const actualHeal = this.player.hp - oldHp;
      this._addLog(`灵气回溯，恢复 ${actualHeal} 点护体值。`);
      this._emitCombatFeedback('player', 'heal', actualHeal, { caption: '法器回护' });
    } else if (p.effect === 'block') {
      const block = p.value || 0;
      this._addLog(`法器庇佑，获得 ${block} 点护盾。`);
      this.player.block += block;
      this._emitCombatFeedback('player', 'shield', block, { caption: '法器庇佑' });
    } else if (p.effect === 'drawCard') {
      const drawCount = p.value || 1;
      this._addLog(`灵光一现，抽取 ${drawCount} 张牌。`);
      this._drawCards(drawCount); // 【BUG-3 修复】原为 _draw(不存在)，修正为 _drawCards
    } else if (p.effect === 'status' && p.statusId) {
      const value = Math.max(0, Math.floor(Number(p.value) || 0));
      if (value > 0) this._addStatus('player', p.statusId, value);
      this._addLog(p.logText || `法器留下一层【${p.statusId}】。`);
      this._emitCombatFeedback('player', p.statusId, value, { caption: p.sourceItemName || '法器共鸣' });
    }

    eventBus.emit('combat:anim', { type: 'buff', target: 'player', text: p.sourceItemName, color: '#f1c40f' });
    // 【BUG-3 修复】原为 _checkEnemyDeath(不存在)，修正为 _handleEnemyDefeated
    this._handleEnemyDefeated();
    this._checkPlayerDeath();
  }

  _resolveEffect(effect, target, sourceCard, effectIndex = null) {
      if (effect.type === 'damage') {
          const prepared = DeckCombatSystem.prepareCardDamage({
            effect, statusValue: this._getStatus('player', effect.conditional_status),
            synergyBonus: this._cardSynergy && !this._cardSynergy.damageConsumed ? this._cardSynergy.damageBonus || 0 : 0,
            hp: this.player.hp, maxHp: this.player.maxHp,
            lowHpAtkBonus: this.player.lowHpAtkBonus, lowHpDamageBonus: this.player.lowHpDamageBonus
          });
          let dmg = prepared.damage;
          // These writes/logs have no event dispatch. Preserve their ordering
          // before the original RNG boundary; never move them after a hit.
          if (prepared.conditionalTriggered) {
              if (effect.consume_status) this._setStatus('player', effect.conditional_status, prepared.statusRemaining);
              this._addLog(`【法术极效】引爆 ${effect.conditional_status}，威力暴涨！`);
          }

          if (this._cardSynergy && !this._cardSynergy.damageConsumed) {
            this._cardSynergy.damageConsumed = true;
            for (const activation of this._cardSynergy.activations || []) {
              activation.consumption.damageBonus = activation.requestedDelta.damageBonus;
              activation.damageEffectIndex = effectIndex;
            }
          }
          // 既有剑修被动：低血量倍率。
          if (prepared.lowHpMultiplierApplied) {
            this._addLog(`血剑共鸣，逆境爆发！伤害翻倍！`);
          }
          if (prepared.lowHpFlatApplied) {
            this._addLog(`魔血传承沸腾，伤害 +${this.player.lowHpDamageBonus}！`);
          }
          // 【P1 #5 修复】法宝暴击
          const critRoll = this.player.critRate > 0 ? Math.random() : undefined;
          const finished = DeckCombatSystem.finishCardDamage({ damage: dmg,
            critRate: this.player.critRate, roll: critRoll,
            swordIntent: this._getStatus('player', 'sword_intent'), conditionalStatus: Boolean(effect.conditional_status) });
          dmg = finished.damage;
          if (finished.critical) {
            this._addLog(`暴击！伤害提升至 ${finished.criticalDamage}！`);
          }
          // 剑意加成
          const swordIntent = finished.swordConsumed;
          if (swordIntent > 0) { // 极效法术不吃普通剑意
             this._setStatus('player', 'sword_intent', 0); // 清空
             this._addLog(`剑意爆发，附加 ${swordIntent} 伤害！`);
          }

          const hpBefore = Math.max(0, Number(this.enemy?.hp) || 0);
          const blockBefore = Math.max(0, Number(this.enemy?.block) || 0);
          if (effect.aoe) {
              // 模拟群体攻击，目前只有一个敌人，直接命中
              this._dealDamage(this.enemy, dmg, {
                consumeOpening: sourceCard?.type === 'attack',
                sourceCardId: sourceCard?.id || null
              });
          } else {
              this._dealDamage(this.enemy, dmg, {
                consumeOpening: sourceCard?.type === 'attack',
                sourceCardId: sourceCard?.id || null
              });
          }
          for (const activation of this._cardSynergy?.activations || []) {
            if (activation.consumption.damageBonus && activation.damageEffectIndex === effectIndex) {
              activation.damageOutcomes.push({
                scope: 'whole_effect', effectIndex,
                hpLoss: Math.max(0, hpBefore - Math.max(0, Number(this.enemy?.hp) || 0)),
                blockSpent: Math.max(0, blockBefore - Math.max(0, Number(this.enemy?.block) || 0))
              });
            }
          }
          this._emitResolvedPresentationEffect({
            sourceCard,
            effectIndex,
            resolvedTarget: 'enemy',
            outcome: {
              type: 'damage',
              amount: Math.max(0, hpBefore - Math.max(0, Number(this.enemy?.hp) || 0)),
              blockSpent: Math.max(0, blockBefore - Math.max(0, Number(this.enemy?.block) || 0))
            }
          });
      }
      else if (effect.type === 'block') {
          const grant = DeckCombatSystem.calculateCardEffectGrant({ type: 'block', value: effect.value,
            current: this.player.block, bonus: this._cardSynergy && !this._cardSynergy.blockConsumed ? this._cardSynergy.blockBonus || 0 : 0 });
          const block = grant.amount;
          if (this._cardSynergy && !this._cardSynergy.blockConsumed) {
            this._cardSynergy.blockConsumed = true;
            for (const activation of this._cardSynergy.activations || []) {
              activation.consumption.blockBonus = activation.requestedDelta.blockBonus;
            }
          }
          this.player.block = grant.next;
          this._addLog(`灵气交织，你获得了 ${block} 层护体罡气。`);
          this._emitPresentationVfx('shield_gain', 'player', 'shield');
          this._emitCombatFeedback('player', 'shield', block);
          if (block > 0) this._emitSemanticActionPhase('combat:stateResolved', {
            target: 'player', effectType: 'block', amount: block, stateMutation: true
          });
      }
      else if (effect.type === 'status') {
          let targetObj = (effect.target === 'enemy') ? 'enemy' : 'player';
          const currentStacks = this._getStatus(targetObj, effect.statusId);
          const appliedStacks = DeckCombatSystem.calculateCardEffectGrant({ type: 'status', value: effect.value,
            current: currentStacks, max: effect.maxStacks }).applied;
          if (appliedStacks > 0) this._addStatus(targetObj, effect.statusId, appliedStacks);
          if (effect.statusId === 'weak') this._emitPresentationVfx('aura', targetObj, 'weak');
          if (effect.statusId === 'opening') this._emitPresentationVfx('aura', targetObj, 'opening');
          this._emitCombatFeedback(targetObj, effect.statusId, effect.value);
          if (appliedStacks > 0) {
            this._emitResolvedPresentationEffect({
              sourceCard,
              effectIndex,
              resolvedTarget: targetObj,
              outcome: { type: 'status', statusId: effect.statusId, amount: appliedStacks }
            });
          }
      }
      else if (effect.type === 'gain_qi') {
          this.qi = DeckCombatSystem.calculateCardEffectGrant({ type: 'gain_qi', value: effect.value,
            current: this.qi, max: this.maxQi }).next; // 软上限
      }
      else if (effect.type === 'heal') {
          const isPillEffect = Array.isArray(sourceCard?.tags) && sourceCard.tags.includes('pill');
          const grant = DeckCombatSystem.calculateCardEffectGrant({ type: 'heal', value: effect.value,
            current: this.player.hp, max: this.player.maxHp, isPill: isPillEffect, pillBonus: this.player.pillBonus });
          this.player.hp = grant.next;
          const actualHeal = grant.applied;
          if (actualHeal > 0) {
              this._addLog(`护体值恢复了 ${actualHeal} 点！`);
              this._emitCombatFeedback('player', 'heal', actualHeal);
              this._emitSemanticActionPhase('combat:stateResolved', {
                target: 'player', effectType: 'heal', amount: actualHeal, stateMutation: true
              });
          }
      }
      else if (effect.type === 'backlash') {
          this._addLog(`受到反噬伤害！`);
          this.player.hp = DeckCombatSystem.calculateCardEffectGrant({ type: 'backlash', value: effect.value, current: this.player.hp }).next;
          this._checkPlayerDeath();
      }
      else if (effect.type === 'draw_per_status') {
          const statusVal = this._getStatus('player', effect.statusId);
          if (statusVal > 0) {
              for (let i = 0; i < statusVal; i++) {
                  this._drawCard();
              }
              this._addLog(`潮汐共鸣：抽取了 ${statusVal} 张牌。`);
          }
      }
      else if (effect.type === 'draw') {
          const drawCount = Math.max(0, Math.floor(Number(effect.value) || 0));
          for (let i = 0; i < drawCount; i++) this._drawCard();
          if (drawCount > 0) this._addLog(`法诀轮转：抽取了 ${drawCount} 张牌。`);
      }
  }

  static projectReactionEffect(reactionId, action, meta = {}) {
    const resolution = { damageMultiplier: 1, cancelAction: false, result: 'accepted' };
    if (reactionId === 'GUARD') {
      resolution.damageMultiplier = 0.5;
      resolution.result = 'guarded';
    } else if (reactionId === 'DEFLECT') {
      resolution.damageMultiplier = 0.8;
      if (Number(action?.expectedDamage) >= 3) resolution.applyEnemyStatus = { id: 'vulnerable', value: 1 };
      resolution.result = 'deflected';
    } else if (reactionId === 'INTERRUPT') {
      resolution.cancelAction = ['buff', 'debuff'].includes(action?.type);
      resolution.damageMultiplier = resolution.cancelAction ? 0 : 1;
      resolution.applyEnemyStatus = { id: 'weak', value: 1 };
      resolution.result = resolution.cancelAction ? 'interrupted' : 'disrupted';
    } else if (reactionId === 'ABSORB') {
      resolution.damageMultiplier = 0.75;
      resolution.applyPlayerStatus = { id: 'counter_force', value: 1 };
      resolution.result = 'absorbed';
    } else if (reactionId === 'TRANSMUTE') {
      resolution.cancelAction = action?.type === 'debuff';
      resolution.damageMultiplier = resolution.cancelAction ? 0 : 1;
      resolution.applyEnemyStatus = { id: 'poison', value: 1 };
      resolution.result = resolution.cancelAction ? 'transmuted_status' : 'transmuted_damage';
    } else if (reactionId === 'EVADE') {
      resolution.damageMultiplier = 0;
      resolution.applyDrawPenalty = 1;
      resolution.result = 'evaded';
    } else resolution.result = meta.missed ? 'missed' : 'taken';
    return resolution;
  }

  static prepareIncomingAttack({ base, multiplier = 1, reduction = 0 }) {
    const afterCounter = multiplier > 0 && multiplier < 1 ? Math.ceil(base * multiplier) : base;
    return { afterCounter, damage: afterCounter > 0 ? Math.max(0, afterCounter - reduction) : afterCounter };
  }

  static finishIncomingAttack({ damage, karmaBonus = 0, weak = 0, fortify = 0, swordIntent = 0, reactionMultiplier = 1 }) {
    if (karmaBonus > 0) damage += karmaBonus;
    if (weak > 0) damage = Math.max(0, damage - 1);
    if (fortify > 0) damage = Math.max(0, damage - 1);
    if (swordIntent > 0) damage += swordIntent;
    const multiplier = Number.isFinite(Number(reactionMultiplier)) ? Math.max(0, Number(reactionMultiplier)) : 1;
    return { beforeReaction: damage, damage: Math.max(0, Math.ceil(damage * multiplier)) };
  }

  static prepareCardDamage({ effect, statusValue = 0, synergyBonus = 0, hp, maxHp, lowHpAtkBonus, lowHpDamageBonus }) {
    let damage = effect.value, statusRemaining = statusValue;
    const conditionalTriggered = Boolean(effect.conditional_status && statusValue >= (effect.conditional_value || 1));
    if (conditionalTriggered) {
      if (effect.conditional_multiply) damage *= effect.conditional_multiply;
      if (effect.conditional_add) damage += effect.conditional_add;
      if (effect.consume_status) statusRemaining = typeof effect.consume_status === 'number'
        ? Math.max(0, statusValue - effect.consume_status) : 0;
    }
    damage += synergyBonus;
    const lowHpMultiplierApplied = Boolean(lowHpAtkBonus && hp / maxHp <= 0.3);
    if (lowHpMultiplierApplied) damage = Math.floor(damage * lowHpAtkBonus);
    const lowHpFlatApplied = Boolean(lowHpDamageBonus && hp / maxHp <= 0.5);
    if (lowHpFlatApplied) damage += lowHpDamageBonus;
    return { damage, statusRemaining, conditionalTriggered, lowHpMultiplierApplied, lowHpFlatApplied };
  }

  static finishCardDamage({ damage, critRate = 0, roll, swordIntent = 0, conditionalStatus = false }) {
    if (critRate > 0 && (!Number.isFinite(roll) || roll < 0 || roll >= 1)) throw new TypeError('Card critical requires an explicit random roll in [0, 1)');
    const critical = critRate > 0 && roll * 100 < critRate;
    if (critical) damage = Math.floor(damage * 1.5);
    const criticalDamage = damage;
    const swordConsumed = swordIntent > 0 && !conditionalStatus ? swordIntent : 0;
    return { damage: damage + swordConsumed, critical, criticalDamage, swordConsumed };
  }

  static calculateCardEffectGrant({ type, value, current, max, bonus = 0, pillBonus = 0, isPill = false }) {
    let amount = value, next;
    if (type === 'block') { amount += bonus; next = current + amount; }
    else if (type === 'gain_qi') next = Math.min(max + 5, current + amount);
    else if (type === 'backlash') next = Math.max(0, current - amount);
    else if (type === 'heal') {
      amount = Math.floor((Number(value) || 0) * (isPill ? 1 + Math.max(0, Number(pillBonus) || 0) / 100 : 1));
      next = Math.min(max, current + amount);
    } else if (type === 'status') {
      amount = Number(value) || 0;
      if (max !== null && max !== undefined && Number.isFinite(Number(max))) amount = Math.max(0, Math.min(amount, Number(max) - current));
      return { next: amount > 0 ? current + amount : current, applied: amount, amount };
    } else throw new TypeError('Unsupported card grant: ' + type);
    return { next, applied: next - current, amount };
  }

  // Pure numerical stages shared by execution and read-only projections.
  // Callers own status writes, RNG, events and persistence. Never combine
  // stages across a synchronous callback using an old whole-combat snapshot.
  static applyStatusDamageModifiers({ damage, weak, vulnerable, opening = 0, consumeOpening = false }) {
    if (weak > 0) damage = Math.floor(damage * 0.75);
    if (vulnerable > 0) damage = Math.ceil(damage * 1.5);
    const available = Math.max(0, Number(opening) || 0);
    const openingConsumed = consumeOpening === true ? Math.min(1, available) : 0;
    damage += openingConsumed;
    return { damage, openingConsumed, openingRemaining: Math.max(0, available - openingConsumed) };
  }

  static applyAttackBonuses({ damage, atkMod = 0, defPower = 0, counterForce = 0 }) {
    const attackBonus = atkMod > 0 ? atkMod : 0;
    damage += attackBonus;
    // Preserve the existing minimum chip rule, including a zero base hit.
    if (defPower > 0) damage = Math.max(1, damage - defPower);
    const counterConsumed = Math.max(0, Math.floor(Number(counterForce) || 0));
    damage += counterConsumed;
    return { damage, attackBonus, counterConsumed };
  }

  static absorbDamageBlock({ damage, block, defMod = 0, ignoreDefense = false, ignoreBlock = false }) {
    if (!ignoreDefense && defMod > 0) damage = Math.max(0, damage - defMod);
    if (!ignoreBlock && block > 0) {
      if (block >= damage) { block -= damage; damage = 0; }
      else { damage -= block; block = 0; }
    }
    return { damage, block };
  }

  static damageResistanceChance({ damage, daoHeart }) {
    return damage > 0 && daoHeart >= 4 ? Math.min(0.5, 0.3 + (daoHeart - 4) * 0.1) : 0;
  }

  static applyDamageResistance({ damage, daoHeart, roll }) {
    const chance = DeckCombatSystem.damageResistanceChance({ damage, daoHeart });
    if (chance > 0 && (!Number.isFinite(roll) || roll < 0 || roll >= 1)) {
      throw new TypeError('Damage resistance requires an explicit random roll in [0, 1)');
    }
    const resisted = chance > 0 && roll < chance;
    return { damage: resisted ? Math.max(0, damage - 1) : damage, resisted };
  }

  static applyRealmDamageSuppression({ damage, playerRealm, enemyRealm, cardRealm }) {
    const realmOrder = ['mortal', 'qi', 'foundation', 'golden', 'nascent', 'deity', 'tribulation', 'ascension'];
    const playerTier = Math.max(1, realmOrder.indexOf(playerRealm));
    const enemyTier = Math.max(1, realmOrder.indexOf(enemyRealm || cardRealm || playerRealm));
    const suppressed = damage > 0 && playerTier >= enemyTier + 2;
    return { damage: suppressed ? 0 : damage, suppressed };
  }

  static applyVitalityDamage({ target, damage, hp, aura = 0, ignoreAura = false }) {
    let auraAbsorbed = 0, hpLost = 0;
    if (damage > 0) {
      if (target === 'player') {
        auraAbsorbed = ignoreAura ? 0 : Math.min(aura || 0, damage);
        aura = Math.max(0, (aura || 0) - auraAbsorbed);
        hpLost = Math.max(0, damage - auraAbsorbed);
        hp = Math.max(0, hp - hpLost);
      } else {
        hpLost = damage;
        hp -= damage;
      }
    }
    return { hp, aura, hpLost, auraAbsorbed };
  }

  _dealDamage(targetObj, dmg, options = {}) {
      let originalDmg = dmg;
      let shieldBroken = false;
      const hpBeforeSemanticImpact = Math.max(0, Number(targetObj?.hp) || 0);
      const blockBeforeSemanticImpact = Math.max(0, Number(targetObj?.block) || 0);

      // 2. 状态干涉 (易伤/虚弱)
      // - 虚弱 (weak)：造成伤害减少 25% (向下取整)
      // - 易伤 (vulnerable)：受到伤害增加 50% (向上取整)
      if (targetObj === this.enemy) {
          // Player hitting Enemy
          const statusDamage = DeckCombatSystem.applyStatusDamageModifiers({
              damage: dmg, weak: this._getStatus('player', 'weak'),
              vulnerable: this._getStatus('enemy', 'vulnerable'),
              opening: this._getStatus('enemy', 'opening'), consumeOpening: options.consumeOpening
          });
          dmg = statusDamage.damage;
          if (statusDamage.openingConsumed > 0) {
              const openingBonus = statusDamage.openingConsumed;
              this._setStatus('enemy', 'opening', statusDamage.openingRemaining);
              this._addLog(`【破绽】乘隙追击，追加 ${openingBonus} 点伤害！`);
              this._emitPresentationVfx('aura', 'enemy', 'opening_consumed');
              this._emitCombatFeedback('enemy', 'opening_consumed', openingBonus);
          }

          // Read attack/defense only after the opening feedback callbacks.
          const attackDamage = DeckCombatSystem.applyAttackBonuses({
              damage: dmg, atkMod: this.player.atkMod, defPower: this.enemy.defPower,
              counterForce: this._getStatus('player', 'counter_force')
          });
          dmg = attackDamage.damage;
          if (attackDamage.attackBonus > 0) {
              this._addLog(`法宝共鸣，伤害 +${this.player.atkMod}！`);
          }
          const counterForce = attackDamage.counterConsumed;
          if (counterForce > 0) {
              this._setStatus('player', 'counter_force', 0);
              this._addLog(`【反击劲】顺势爆发，追加 ${counterForce} 点伤害！`);
              this._emitCombatFeedback('enemy', 'damage', counterForce, { caption: '反击劲' });
          }
      } else {
          // Enemy hitting Player
          dmg = DeckCombatSystem.applyStatusDamageModifiers({
              damage: dmg, weak: this._getStatus('enemy', 'weak'),
              vulnerable: this._getStatus('player', 'vulnerable')
          }).damage;
      }

      // 【新增】用于神农鼎等“本回合未造成伤害”判定的标记
      if (dmg > 0 && targetObj === this.enemy) {
          this.damageDealtThisTurn = true;
      }

      // Read the shield after counter feedback; commit only this stage's
      // block result, before the synchronous plan-transition boundary.
      const contact = DeckCombatSystem.absorbDamageBlock({
          damage: dmg, block: targetObj.block,
          defMod: targetObj === this.player ? this.player.defMod : 0,
          ignoreDefense: options.ignoreDefense, ignoreBlock: options.ignoreBlock
      });
      dmg = contact.damage;
      targetObj.block = contact.block;
      shieldBroken = options.ignoreBlock !== true
        && blockBeforeSemanticImpact > 0
        && Number(targetObj.block) === 0;
      if (targetObj === this.enemy && shieldBroken) {
        this._signalEnemyBlockBroken(
          blockBeforeSemanticImpact,
          Number(targetObj.block),
          options.sourceCardId || null
        );
      }

      const targetName = targetObj === this.player ? 'player' : 'enemy';
      const actorName = targetObj === this.player ? this.enemy.name : '你';
      const receiverName = targetObj === this.player ? '你' : this.enemy.name;

      if (shieldBroken) {
          this._addLog(`狂暴的灵力撕裂了${receiverName}的护体罡气！`);
          // Shield break is still a contact result of the active attack. Route
          // it through the presentation authority so an authored contact cue
          // can suppress the legacy CSS square at the same target anchor.
          this._emitPresentationVfx('shield_break', targetName, 'shield_break');
      } else if (originalDmg > 0 && dmg === 0) {
          this._addLog(`攻击轰在${receiverName}的护体灵光上，荡起阵阵涟漪，却未能破防。`);
          this._emitVfxRequest('shield_hit', targetName, 'shield');
      }

      if (dmg > 0 && targetObj === this.player && this.player.daoHeart >= 4) {
          // The executor still owns exactly one roll at the original boundary.
          const resistance = DeckCombatSystem.applyDamageResistance({
              damage: dmg, daoHeart: this.player.daoHeart, roll: Math.random()
          });
          dmg = resistance.damage;
          if (resistance.resisted) {
              this._addLog(`道心澄澈，真气流转间自动护主，化解了 1 点危机！`);
          }
      }

      // 【特权机制】境界压制 (Realm Suppression)
      if (dmg > 0 && targetObj === this.player) {
          const suppression = DeckCombatSystem.applyRealmDamageSuppression({
              damage: dmg, playerRealm: this.player.realm,
              enemyRealm: this.enemy.realm, cardRealm: this.originalCard?.realm
          });
          dmg = suppression.damage;
          if (suppression.suppressed) {
              this._addLog(`【境界压制】高阶修士的护体威压直接震碎了攻势，免疫伤害！`);
              this._emitVfxRequest('shield_hit', 'player', 'shield');
          }
      }

      if (dmg > 0) {
          if (targetObj === this.player) {
              // Read HP/aura after shield/realm feedback, never from a contact
              // snapshot that could predate a synchronous authority change.
              const vitality = DeckCombatSystem.applyVitalityDamage({
                  target: 'player', damage: dmg, hp: this.player.hp,
                  aura: this.player.aura, ignoreAura: options.ignoreAura
              });
              const { auraAbsorbed, hpLost } = vitality;
              this.player.aura = vitality.aura;
              this.player.hp = vitality.hp;

              if (auraAbsorbed > 0) {
                  this._addLog(`全局护体罡气生效，替你抵挡了 ${auraAbsorbed} 点伤害！`);
                  this._emitVfxRequest('shield_hit', 'player', 'shield');
              }

              if (hpLost > 0) {
                  if (shieldBroken) {
                      this._addLog(`余威不减，真气透体而过，令你损失 ${hpLost} 点气血！`);
                  } else {
                      this._addLog(`招式狠狠命中，令你损失 ${hpLost} 点气血！`);
                  }
                   this._emitPresentationVfx('impact', 'player', 'damage');
                  eventBus.emit('combat:anim', { type: 'shake', target: 'player' });
                  this._emitCombatFeedback('player', 'damage', hpLost);
              } else {
                  this._addLog(`所有穿透伤害已被全局罡气吸收，你未受真伤！`);
              }
          } else {
              targetObj.hp = DeckCombatSystem.applyVitalityDamage({
                  target: 'enemy', damage: dmg, hp: targetObj.hp
              }).hp;
              if (shieldBroken) {
                  this._addLog(`余威不减，真气透体而过，令其损失 ${dmg} 点气血！`);
              } else {
                  this._addLog(`招式狠狠命中，${receiverName}损失 ${dmg} 点气血！`);
              }
               this._emitPresentationVfx('impact', targetName, 'damage');
              eventBus.emit('combat:anim', { type: 'shake', target: targetName });
              this._emitCombatFeedback(targetName, 'damage', dmg);
          }
      } else if (originalDmg > 0) {
          this._emitCombatFeedback(targetName, 'blocked', 0, { valueText: '化解' });
      }
       this._emitSemanticActionPhase('combat:impact', {
           target: targetObj === this.player ? 'player' : 'enemy',
           amount: Math.max(0, hpBeforeSemanticImpact - Math.max(0, Number(targetObj?.hp) || 0)),
           blockSpent: Math.max(0, blockBeforeSemanticImpact - Math.max(0, Number(targetObj?.block) || 0)),
           shieldBroken
       });
       // Hurt sequences are sidecar visuals tied to the same authoritative
       // impact.  They do not write combat state.  A lethal enemy hit uses
       // the terminal collapse instead of immediately replacing a short hurt
       // pose on the same actor.
       if (targetObj === this.player
         && hpBeforeSemanticImpact > Math.max(0, Number(targetObj?.hp) || 0)) {
           this._emitPlayerPresentationAction('hurt', {
             target: 'player',
             sourceId: 'enemy_hit',
             originActionId: this._activeSemanticAction?.actionId || null
           });
       }
       if (targetObj === this.enemy
         && hpBeforeSemanticImpact > Math.max(0, Number(targetObj?.hp) || 0)
         && Number(targetObj?.hp) > 0) {
           this._emitEnemyPresentationAction('hurt', {
             target: 'enemy',
             sourceId: 'player_hit',
             originActionId: this._activeSemanticAction?.actionId || null
           });
       }
   }

  // 【BUG-1 修复】已删除此处重复定义的 endTurn()。
  // JavaScript 后定义的方法会覆盖前者，导致第 304 行的装备被动版本失效。
  // 唯一有效的 endTurn() 定义现在位于第 304 行。

  _enemyTurn(reactionResolution = null) {
      if (!this.active) return;

      const playerHpBefore = Number(this.player?.hp) || 0;
      const enemyHpBefore = Number(this.enemy?.hp) || 0;
      const resolvedIntent = this.enemyIntent ? { ...this.enemyIntent } : null;

      const poison = this._getStatus('enemy', 'poison');
      if (poison > 0) {
          const poisonDamage = Math.min(3, poison);
          const finalDamage = Math.max(0, poisonDamage);
          if (finalDamage > 0) {
            this.damageDealtThisTurn = true;
          }
          this.enemy.hp -= finalDamage;
          this._setStatus('enemy', 'poison', Math.max(0, poison - 1));
          this._addLog(`丹毒侵蚀【${this.enemy.name}】，造成 ${poisonDamage} 点伤害。`);
          if (this.enemy.hp <= 0 && reactionResolution) {
              this._emitReactionResolved(
                reactionResolution,
                playerHpBefore,
                enemyHpBefore,
                resolvedIntent,
                { result: `${reactionResolution.result}_poison_defeat` }
              );
          }
          if (this._handleEnemyDefeated()) {
              if (this.active) this._startTurn(reactionResolution ? {
                reactionWindowId: reactionResolution.windowId,
                reactionId: reactionResolution.reactionId
              } : {});
              return;
          }
      }

      // 执行意图。反应选择由权威状态机先结算，再把单次修正传入本动作。
      let actionText = this.enemyIntent.actionName || '发动攻击';
      const authoredEnemyActionFamily = this.enemyIntent.actionFamily;
      const encounterActionRegistry = this._actionPresentationData?.encounters?.[this._encounterActionId()] || {};
      const enemyActionFamily = ['attack', 'guard', 'skill', 'hurt'].includes(authoredEnemyActionFamily)
        && encounterActionRegistry[authoredEnemyActionFamily]
        ? authoredEnemyActionFamily
        : (this.enemyIntent.type === 'attack'
          ? 'attack'
          : (this.enemyIntent.type === 'defend' ? 'guard' : 'skill'));
      this._beginSemanticAction({
          actionFamily: enemyActionFamily,
          source: 'enemy',
          target: this.enemyIntent.type === 'attack' || this.enemyIntent.type === 'debuff' ? 'player' : 'enemy',
          sourceId: this.enemyIntent.presentationVariantId
            || this.enemyIntent.planState || this.enemyIntent.actionName || this.enemyIntent.type
      });

      if (reactionResolution?.cancelAction) {
          this._addLog(`你的【${reactionResolution.reactionId}】截断了【${this.enemy.name}】的${actionText}！`);
          this._emitCombatFeedback('enemy', 'blocked', 0, { valueText: '截断', caption: '反应成功' });
      } else if (this.enemyIntent.type === 'attack') {
          // Enemy attack carriers own the same authored cue channel as player
          // attacks.  This is presentation-only and runs after a successful
          // interrupt check, so a fully cancelled action cannot leak a travel
          // or contact effect.  It also lets a visually evaded remote strike
          // retain its readable trajectory without manufacturing damage.
          this._emitActionPresentationCues();
          this._emitReactionContactPresentationCue(reactionResolution);
          // 遭遇配置 atk 是本场强度下限，模板 value 是动作差异；二者必须同时生效。
          // 精英/Boss 再获得 1 点难度压力，避免高境敌人套低阶模板后仍只打 1 点。
          let dmg = Math.max(this.enemyIntent.value || 1, this.enemy.atkPower || 1);
          if (this.enemy.tier === 2) dmg += 2;
          if (Number(this.enemyIntent.multiplier) > 1) {
              dmg = Math.ceil(dmg * Number(this.enemyIntent.multiplier));
          }

          const bossCounter = this.originalCard?.combatRules?.counter || {};
          if (bossCounter.flag
            && typeof gameState !== 'undefined'
            && gameState.hasFlag(bossCounter.flag)
            && Number(bossCounter.incomingDamageMultiplier) > 0
            && Number(bossCounter.incomingDamageMultiplier) < 1) {
              dmg = DeckCombatSystem.prepareIncomingAttack({ base: dmg, multiplier: Number(bossCounter.incomingDamageMultiplier) }).damage;
              const blockedPercent = Math.round((1 - Number(bossCounter.incomingDamageMultiplier)) * 100);
              this._addLog(`【突破对策】护持之力抵挡了 ${blockedPercent}% 的天威伤害！`);
          }

          const narrativeStance = this.originalCard?.combatRules?.narrativeStance || {};
          if (narrativeStance.id === 'advance'
            && this.originalCard?.id === 'ch_qi_100'
            && this._getStatus('player', 'qi_main_advance_ready') > 0
            && dmg > 0) {
              const reduction = Math.max(0, Number(narrativeStance.firstDamagingLightningReduction) || 0);
              const before = dmg;
              dmg = DeckCombatSystem.prepareIncomingAttack({ base: dmg, reduction }).damage;
              this._setStatus('player', 'qi_main_advance_ready', 0);
              this._addLog(`【问剑进势】卸去首道雷击 ${Math.max(0, before - dmg)} 点伤害。`);
          }

          let piercing = this.enemyIntent.piercing === true;
          const piercingCounter = this.originalCard?.combatRules?.counters?.nascentPill;
          if (piercing
            && piercingCounter?.cancelPiercing === true
            && piercingCounter.flag
            && typeof gameState !== 'undefined'
            && gameState.hasFlag(piercingCounter.flag)) {
              piercing = false;
              this._addLog(`【凝婴丹效力】药力护住泥丸宫，阴雷改为轰击护盾！`);
          } else if (piercing) {
              this._addLog(`【穿透】这道攻势无视护盾与局内罡气，直击护体本源！`);
          }

          // 数据驱动的业力伤害增幅。
          const karmaDamage = this.originalCard?.combatRules?.karmaDamage;
          let incomingKarmaBonus = 0;
          if (karmaDamage && typeof gameState !== 'undefined') {
              const attribute = karmaDamage.attribute || 'karmaBad';
              const badKarma = Number(gameState.attributes?.[attribute]) || 0;
              const perPoints = Math.max(1, Number(karmaDamage.perPoints) || 1);
              const damagePerStep = Math.max(0, Number(karmaDamage.damagePerStep) || 0);
              const karmaBonus = Math.floor(badKarma / perPoints) * damagePerStep;
              if (karmaBonus > 0) {
                  incomingKarmaBonus = karmaBonus;
                  this._addLog(`【业力缠身】你身上积聚了 ${badKarma} 点恶业，天道感应，天劫伤害额外 +${karmaBonus}！`);
              }
          }

          // 【BUG-4 修复】虚弱/金刚劲的层数衰减统一由 _startTurn 自然处理（每回合 -1 层），
          // 此处只读取状态并应用伤害减益，不再重复调用 _setStatus 造成双重衰减。
          const weak = this._getStatus('enemy', 'weak');
          if (weak > 0) {
              this._addLog(`【虚弱】削弱了【${this.enemy.name}】的攻势，伤害 -1。`);
          }
          const fortify = this._getStatus('player', 'fortify');
          if (fortify > 0) {
              this._addLog(`【金刚罡劲】卸去 1 点伤害。`);
          }
          let swordIntent = this._getStatus('enemy', 'sword_intent');
          if (swordIntent > 0) {
              this._setStatus('enemy', 'sword_intent', 0);
              this._addLog(`【${this.enemy.name}】剑意勃发，杀机毕露！`);
          }
          const reactionMultiplier = Number.isFinite(Number(reactionResolution?.damageMultiplier))
            ? Math.max(0, Number(reactionResolution.damageMultiplier))
            : 1;
          // Logs/status writes above do not dispatch callbacks. Keep the
          // numerical stages together, before the original slash-event boundary.
          const incoming = DeckCombatSystem.finishIncomingAttack({ damage: dmg,
            karmaBonus: incomingKarmaBonus, weak, fortify, swordIntent, reactionMultiplier });
          const damageBeforeReaction = incoming.beforeReaction;
          dmg = incoming.damage;
          if (reactionResolution && reactionMultiplier < 1) {
              this._addLog(`【${reactionResolution.reactionId}】化去 ${Math.max(0, damageBeforeReaction - dmg)} 点攻势。`);
          }
           this._addLog(`【${this.enemy.name}】${actionText}！`);
           this._emitPresentationVfx('slash', 'player');
          this._dealDamage(this.player, dmg, piercing
            ? { ignoreDefense: true, ignoreBlock: true, ignoreAura: true }
            : {});
      } else if (this.enemyIntent.type === 'debuff') {
        this._addLog(`【${this.enemy.name}】${actionText}！`);
        if (this.enemyIntent.statusId) {
            this._addStatus('player', this.enemyIntent.statusId, this.enemyIntent.value);
            this._playerStatusesAppliedByEnemy.add(this.enemyIntent.statusId);
            if (this.enemyIntent.statusId === 'weak') this._emitPresentationVfx('aura', 'player', 'weak');
            this._emitCombatFeedback('player', this.enemyIntent.statusId, this.enemyIntent.value, { caption: '敌方术式' });
        }
      } else if (this.enemyIntent.type === 'defend') {
          // Defend actions own the same authored cue channel as attacks and
          // buffs.  Consume it before applying the numeric guard; otherwise a
          // plan-authored state (for example N11's golden-body barrier) is
          // silently replaced by the shared semantic shield ward.
          const authoredDefenseCueEmitted = this._emitActionPresentationCues();
          const defenseGain = this._enemyDefenseValue(this.enemyIntent);
          this.enemy.block += defenseGain;
          if (defenseGain > 0) {
              this._addLog(`【${this.enemy.name}】${actionText}，获得了 ${defenseGain} 点护盾。`);
              if (!authoredDefenseCueEmitted) {
                  this._emitPresentationVfx('shield_gain', 'enemy', 'shield');
              }
              this._emitCombatFeedback('enemy', 'shield', defenseGain, { caption: '敌方护势' });
          } else {
              this._addLog(`【${this.enemy.name}】${actionText}，未能重新建立护势。`);
          }
      } else if (this.enemyIntent.type === 'buff') {
          this._emitActionPresentationCues();
          this._addLog(`【${this.enemy.name}】${actionText}。`);
          if (this.enemyIntent.statusId) {
              this._addStatus('enemy', this.enemyIntent.statusId, this.enemyIntent.value);
              this._emitCombatFeedback('enemy', this.enemyIntent.statusId, this.enemyIntent.value, { caption: '敌方蓄势' });
          } else if (this._actionPresentationData?.timelines?.[this._activeSemanticAction?.timelineId]
              ?.phases?.includes('statusApplied')) {
              // A readable charge beat may own the statusApplied choreography
              // phase without manufacturing a combat status. Consumers get
              // timing/audio evidence plus an explicit no-state-mutation flag.
              this._emitSemanticActionPhase('combat:statusApplied', {
                  target: 'enemy', statusId: null, amount: 0,
                  semantic: 'charge_hold', stateMutation: false
              });
          }
      }

      if (reactionResolution?.applyDrawPenalty) {
          this._nextTurnDrawPenalty = Math.max(
            this._nextTurnDrawPenalty,
            Math.max(0, Math.floor(Number(reactionResolution.applyDrawPenalty) || 0))
          );
      }

      if (reactionResolution) {
          this._emitReactionResolved(reactionResolution, playerHpBefore, enemyHpBefore, resolvedIntent);
      }
      if (this.player?.hp <= 0) this._emitSemanticActionPhase('combat:actorDefeated', { actor: 'player' });
      this._completeSemanticAction({ cancelled: Boolean(reactionResolution?.cancelAction) });
      if (this._checkPlayerDeath()) return 'defeat';

      // 数据驱动的生存型境界门槛：达到契约回合数即胜利。
      const bossRules = this.originalCard?.combatRules || {};
      if (this.active && bossRules.victoryCondition === 'survive_turns') {
          const surviveTurns = Math.max(1, Number(bossRules.surviveTurns) || 1);
          if (this.turn >= surviveTurns) {
              this._addLog(`雷霆轰鸣渐渐散去，漫天劫云豁然开朗，你终于熬过了这天降雷劫！`);
              this._victory();
              return;
          }
      }

      if (this.active) {
          this._settleEnemyPlanAction(resolvedIntent);
          this._startTurn(reactionResolution ? {
            reactionWindowId: reactionResolution.windowId,
            reactionId: reactionResolution.reactionId
          } : {});
      }
  }

  _emitReactionResolved(reactionResolution, playerHpBefore, enemyHpBefore, intent, overrides = {}) {
      if (!reactionResolution) return false;
      eventBus.emit('combat:reactionResolved', {
        windowId: reactionResolution.windowId,
        reactionId: reactionResolution.reactionId,
        actionFamily: reactionResolution.actionFamily,
        source: reactionResolution.source,
        target: reactionResolution.target,
        mode: reactionResolution.mode,
        result: overrides.result || reactionResolution.result,
        intent,
        damageTaken: Math.max(0, Number(playerHpBefore || 0) - (Number(this.player?.hp) || 0)),
        enemyHpDelta: (Number(this.enemy?.hp) || 0) - Number(enemyHpBefore || 0),
        playerHp: Number(this.player?.hp) || 0,
        enemyHp: Number(this.enemy?.hp) || 0
      });
      return true;
  }

  // 获取卡牌定义（支持实时生成强化牌）
  getCardDef(cardId) {
    if (typeof cardId === 'object' && cardId !== null) return cardId;
    if (typeof cardId !== 'string') return null;
    if (this.cardDB[cardId]) return this.cardDB[cardId];
    if (cardId.endsWith('+')) {
      const baseId = cardId.slice(0, -1);
      const baseCard = this.cardDB[baseId];
      if (baseCard) {
        const deckAuthority = this.deckAuthority
          || (typeof skillCardAcquisitionSystem !== 'undefined' ? skillCardAcquisitionSystem : null);
        const upgradedCard = deckAuthority?.buildUpgradedCard(baseCard, cardId);
        if (!upgradedCard) return null;
        this.cardDB[cardId] = upgradedCard;
        return upgradedCard;
      }
    }
    return null;
  }

  // === 状态与初始化 ===

  _hasStatus(who, statusId) {
      const stats = who === 'player' ? this.playerStatus : this.enemyStatus;
      return (stats[statusId] || 0) > 0;
  }

  _getStatus(who, statusId) {
      const stats = who === 'player' ? this.playerStatus : this.enemyStatus;
      return stats[statusId] || 0;
  }

  _setStatus(who, statusId, value) {
      const stats = who === 'player' ? this.playerStatus : this.enemyStatus;
      stats[statusId] = value;
  }

  _addStatus(who, statusId, amount) {
      // 【ISSUE-3 修复】建立状态ID到中文名的映射表，避免英文状态ID暴露给玩家
      const STATUS_NAME_MAP = {
          'weak': '虚弱',
          'vulnerable': '易伤',
          'opening': '破绽',
          'poison': '丹毒',
          'fortify': '金刚罡劲',
          'sword_intent': '剑意',
          'spell_seal': '法印',
          'aura': '护体罡气',
          'qi_main_advance_ready': '问剑进势',
      };
      const displayName = STATUS_NAME_MAP[statusId] || statusId;
      const target = who === 'player' ? '你' : (this.enemy ? `【${this.enemy.name}】` : '敌人');
      const current = this._getStatus(who, statusId);
      this._setStatus(who, statusId, current + amount);
      this._addLog(`${target}获得 ${amount} 层【${displayName}】`);
      this._emitSemanticActionPhase('combat:statusApplied', {
          target: who === 'player' ? 'player' : 'enemy',
          statusId,
          amount: Math.max(0, Number(amount) || 0)
      });
  }

  // === 法宝/遗物系统联动 ===

  _triggerRelic(triggerType) {
      if (typeof treasureSystem === 'undefined' || !treasureSystem) return;
      for (const treasureId of treasureSystem.getEquippedDefinitionIds?.() || []) {
         const t = treasureSystem.treasureDB[treasureId];
         if (!t || !t.relic) continue;

         const rEffect = t.relic[triggerType];
         if (!rEffect) continue;

         // 执行遗物效果
         this._addLog(`✨【${t.name}】发光了！`);
         if (rEffect.type === 'gain_qi') {
             this.qi = Math.min(this.maxQi + 5, this.qi + rEffect.value);
         } else if (rEffect.type === 'gain_block') {
             this.player.block += rEffect.value;
         } else if (rEffect.type === 'status') {
             this._addStatus('player', rEffect.statusId, rEffect.value);
         }

         if (t.tianjiCost) {
             gameState.addAttribute('tianji', t.tianjiCost);
             this._addLog(`⚡ 天机暴露，天道关注了你！`);
         }
      }
  }

  _emitEquippedTreasureTrigger(card, presentation = null) {
      if (!card || typeof treasureSystem === 'undefined' || !treasureSystem
        || typeof treasureSystem.getEquippedCombatPresentations !== 'function') return;
      const equipped = treasureSystem.getEquippedCombatPresentations();
      for (const item of equipped) {
          const matchesCard = item.tacticalCardId && item.tacticalCardId === card.id;
          const matchesType = item.trigger === 'onCardPlay'
            && item.triggerCardType
            && item.triggerCardType === card.type;
          if (!matchesCard && !matchesType) continue;
          const fx = item.triggerFx || {};
          this._addLog(`法宝【${item.name}】与【${card.name}】共鸣。`);
          const treasurePresentation = {
              treasureId: item.treasureId,
              treasureName: item.name,
              slot: item.slot,
              tacticalCardId: item.tacticalCardId || null,
              cardId: card.id,
              cardName: card.name,
              presentationId: presentation?.presentationId || null,
              assetId: fx.id || null,
              cardArt: item.cardArt || null,
              frames: Array.isArray(fx.frames) ? fx.frames : null,
              durationMs: Number(fx.durationMs) || 480
          };
          eventBus.emit('combat:treasureTriggered', treasurePresentation);
          this._emitVfxRequest('aura', 'player', 'treasure', {
              assetId: treasurePresentation.assetId,
              frames: treasurePresentation.frames,
              durationMs: treasurePresentation.durationMs,
              vfxSlot: 'source_state',
              eventQualifier: item.treasureId || item.slot || 'treasure'
          });
      }
  }

  // === 战斗结算 ===

  _checkPlayerDeath() {
      if (!this.active) return false;
      if (this.player.hp <= 0) {
          this.player.hp = 0;
          this.active = false;
          this.phase = 'IDLE';
          this.pendingReaction = null;
          this._clearReactionTimer();
          this._endPathArchetypeBattle();
          const defeatHealthLoss = this._getDefeatHealthLoss();
          this._addLog(`护体值耗尽，战斗失败。败战伤势基准 ${defeatHealthLoss} 点，实际损失将在离场时结算。`);
          this._emitPresentationVfx('impact', 'player', 'damage');
          const terminalPresentation = this._emitPlayerPresentationAction('defeat', {
            target: 'player',
            sourceId: 'combat_defeat',
            terminal: true
          });
          const outcome = {
            originalCard: this.originalCard,
            cardId: this.originalCard?.id,
            encounterContext: this.encounterContext,
            presentation: this._getPresentationContext(),
            remainingHp: 0,
            combatVitalityLost: this.player.maxHp,
            defeatHealthLoss,
            persistentHealthBefore: this.preCombatHealth,
            log: this.log
          };
          eventBus.emit('combat:defeat', outcome);
          // A rejected durable settlement can synchronously restore this battle.
          // Never enqueue terminal work against that fresh playable scene.
          if (outcome.sourceSettlement?.accepted === false || this.active) return true;
          // A mounted terminal body can be queued behind an earlier authored
          // exchange. Its logical duration therefore cannot own screen hide:
          // DeckCombatUI closes the battlefield only after that body actually
          // reaches the end of its visible lifecycle. Missing presentation
          // contracts retain the immediate fail-safe below.
          if (!terminalPresentation) this._scheduleTerminalCombatHide(0);
          return true;
      }
      return false;
  }

  _getDefeatHealthLoss() {
      const explicit = Number(this.originalCard?.defeatHealthLoss
        ?? this.originalCard?.combatRules?.defeatHealthLoss
        ?? this.originalCard?.enemy?.defeatHealthLoss);
      if (Number.isFinite(explicit) && explicit > 0) return Math.round(explicit);
      const tier = Number(this.originalCard?.enemy?.tier || this.enemy?.tier || 1);
      return tier >= 3 ? 3 : tier === 2 ? 2 : 1;
  }

  _victory({ settlementDelayMs = 0 } = {}) {
      if (!this.active) return false;
      const pathReceipt = this._pendingPathSynergyReceipt;
      this.active = false;
      this.phase = 'IDLE';
      this.pendingReaction = null;
      this._clearReactionTimer();
      this._endPathArchetypeBattle();
      this._addLog(`战斗胜利！`);

      // 基础战斗奖励（修为 + 灵石）
      const defaultCult = 5 + Math.floor((gameState.attributes.cultivation || 0) / 20);
      const defaultStone = Math.floor((this.enemy.atkPower || this.enemy.tier || 1) * 1.5);

      if (gameState.addAttribute) {
        gameState.addAttribute('cultivation', defaultCult);
      }
      if (gameState.addResource) {
        gameState.addResource('spiritStone', null, defaultStone);
      }
      this._addLog(`获得修为 +${defaultCult}，灵石 +${defaultStone}`);

       const settleVictory = () => {
         const outcome = {
           originalCard: this.originalCard,
           cardId: this.originalCard?.id,
           encounterContext: this.encounterContext,
           presentation: this._getPresentationContext(),
           baseRewards: {
             attributes: { cultivation: defaultCult },
             resources: { spiritStone: defaultStone }
           },
           remainingCombatVitality: this.player.hp,
           persistentHealthBefore: this.preCombatHealth,
           log: this.log
         };
         eventBus.emit('combat:victory', outcome);
         if (outcome.outcomeAccepted === true) this._publishPathSynergyReceipt(pathReceipt, { terminalAccepted: true });
         else if (this._pendingPathSynergyReceipt === pathReceipt) this._pendingPathSynergyReceipt = null;
         if (outcome.outcomeAccepted === false || outcome.sourceSettlement?.accepted === false || this.active) return;

         // The reward flow remains the only numerical settlement owner. A
         // player victory pose owns only the final combat-screen hide, and the
         // UI acknowledges that after the queued body has actually played.
         const terminalPresentation = this._emitPlayerPresentationAction('victory', {
           target: 'player',
           sourceId: 'combat_victory',
           terminal: true
         });
         if (!terminalPresentation) this._scheduleTerminalCombatHide(0);
       };
       this._scheduleVictorySettlement(settleVictory, settlementDelayMs);
       return true;
  }

  /**
   * 逃跑（由 UI/CombatCoordinator 调用）
   */
  flee() {
      if (!this.active) return;
      const abandonedReaction = this.pendingReaction ? this._cloneReaction(this.pendingReaction) : null;
      this.active = false;
      this.phase = 'IDLE';
      this.pendingReaction = null;
      this._clearReactionTimer();
      this._endPathArchetypeBattle();
      this._addLog('你抓住机会逃离了战场。');
      if (abandonedReaction) {
        eventBus.emit('combat:reactionResolved', {
          windowId: abandonedReaction.windowId,
          reactionId: 'FLEE',
          actionFamily: abandonedReaction.action?.actionFamily || 'SPECIAL',
          source: abandonedReaction.source,
          target: abandonedReaction.target,
          mode: abandonedReaction.mode,
          result: 'fled',
          intent: abandonedReaction.action,
          damageTaken: 0,
          enemyHpDelta: 0,
          playerHp: Number(this.player?.hp) || 0,
          enemyHp: Number(this.enemy?.hp) || 0
        });
      }
      eventBus.emit('ui:hideCombatScreen');
      eventBus.emit('combat:fled', {
        originalCard: this.originalCard,
        encounterContext: this.encounterContext,
        presentation: this._getPresentationContext()
      });
  }

  /**
   * 获取当前战斗状态快照（供 CombatCoordinator / UI 读取）
   */
  getPublicCombatDecisionView() {
      if (!this.active || !this.player || !this.enemy) return null;
      const copy = value => JSON.parse(JSON.stringify(value));
      const archetypes = typeof pathArchetypeSystem !== 'undefined' ? pathArchetypeSystem : null;
      const treasures = typeof treasureSystem !== 'undefined' ? treasureSystem : null;
      const pathId = typeof gameState !== 'undefined' ? gameState.path : null;
      const pending = this.pendingReaction;
      // Deliberate whitelist: no getState/serialized checkpoint, hidden pile
      // identities, future plan graph, RNG state or private combat flags.
      return copy({ version: 1, phase: this.phase, turn: this.turn, pathId,
        inputLocked: this.isPlayerInputLocked(), qi: this.qi, maxQi: this.maxQi,
        drawCount: this.drawPile.length, discardCount: this.discardPile.length,
        facts: this.getPublicCombatFacts(), playerStatus: this.playerStatus, enemyStatus: this.enemyStatus,
        archetype: archetypes?.getSelected?.() || null,
        history: archetypes?.exportCombatState?.() || null,
        planLabel: this._getPlanStateView()?.stateLabel || null,
        equipmentIds: treasures?.getEquippedDefinitionIds?.() || [],
        equipmentSlots: typeof gameState !== 'undefined' ? Object.keys(gameState.equipment || {})
          .filter(slot => Boolean(gameState.equipment[slot])) : [],
        action: this._previewEnemyAction(),
        reaction: pending ? { windowId: pending.windowId, action: pending.action,
          options: pending.options, mode: pending.mode, deadlineAt: pending.deadlineAt } : null,
        hand: this.hand.map(id => {
          const card = this.getCardDef(id);
          return card ? { id: card.id, name: card.name, type: card.type, cost: card.cost,
            tags: card.tags || [], effects: card.effects || [], exhaust: card.exhaust === true } : null;
        })
      });
  }

  getPublicCombatFacts() {
      if (!this.active || !this.player || !this.enemy) return null;
      const p = this.player, e = this.enemy, rules = this.originalCard?.combatRules || {};
      const number = value => Number(value) || 0;
      const hasFlag = flag => Boolean(flag && typeof gameState !== 'undefined' && gameState.hasFlag(flag));
      const action = this._previewEnemyAction();
      const counter = rules.counter || {};
      const incomingMultiplier = hasFlag(counter.flag)
        && Number(counter.incomingDamageMultiplier) > 0 && Number(counter.incomingDamageMultiplier) < 1
        ? Number(counter.incomingDamageMultiplier) : 1;
      const piercingCounter = rules.counters?.nascentPill;
      const piercing = action.piercing && !(piercingCounter?.cancelPiercing === true && hasFlag(piercingCounter.flag));
      const backlash = rules.attackBacklash;
      const backlashValue = {
        cardType: backlash?.triggerCardType || 'attack',
        damage: backlash && !hasFlag(backlash.counter?.flag) ? Math.max(0, Math.floor(number(backlash.damage))) : 0
      };
      const karma = rules.karmaDamage;
      const karmaValue = karma && typeof gameState !== 'undefined'
        ? Math.max(0, Math.floor(number(gameState.attributes?.[karma.attribute || 'karmaBad'])
          / Math.max(1, number(karma.perPoints))) * Math.max(0, number(karma.damagePerStep))) : 0;
      const stance = rules.narrativeStance;
      const firstHitReduction = stance?.id === 'advance' && this.originalCard?.id === 'ch_qi_100'
        && this._getStatus('player', 'qi_main_advance_ready') > 0
        ? Math.max(0, number(stance.firstDamagingLightningReduction)) : 0;
      const suppression = DeckCombatSystem.applyRealmDamageSuppression({ damage: 1,
        playerRealm: p.realm, enemyRealm: e.realm, cardRealm: this.originalCard?.realm }).suppressed;
      const resistChance = DeckCombatSystem.damageResistanceChance({ damage: 1, daoHeart: p.daoHeart });
      const surviveTurns = rules.victoryCondition === 'survive_turns' ? Math.max(1, number(rules.surviveTurns)) : null;
      const phase = { current: this.bossPhases.length ? this.bossPhaseIndex + 1 : 1, total: Math.max(1, this.bossPhases.length) };
      const rows = [];
      const row = (id, label, value, text = String(value)) => rows.push({ id, label, value, text });
      row('player_hp', '我方气血', { current: p.hp, max: p.maxHp }, `${p.hp} / ${p.maxHp}`);
      row('player_block', '我方护盾', number(p.block));
      row('player_aura', '我方全局罡气', number(p.aura));
      row('player_atk_mod', '攻击加值', number(p.atkMod));
      row('player_def_mod', '常驻减伤', number(p.defMod));
      row('player_crit_rate', '暴击率', number(p.critRate), `${number(p.critRate)}%（先暴击，再加剑意）`);
      row('player_dao_heart', '战斗道心', number(p.daoHeart));
      row('player_resist_chance', '有余伤时抵抗率', resistChance, `${Math.round(resistChance * 100)}%：化解 1 点；没有余伤不判定`);
      row('player_low_hp_multiplier', '气血不高于 30%', number(p.lowHpAtkBonus) || 1, `伤害 ×${number(p.lowHpAtkBonus) || 1}`);
      row('player_low_hp_bonus', '气血不高于 50%', number(p.lowHpDamageBonus), `伤害 +${number(p.lowHpDamageBonus)}`);
      row('player_pill_bonus', '丹药恢复加成', Math.max(0, number(p.pillBonus)), `+${Math.max(0, number(p.pillBonus))}%（仅丹药牌）`);
      row('enemy_hp', '敌方气血', { current: e.hp, max: e.maxHp }, `${e.hp} / ${e.maxHp}`);
      row('enemy_block', '敌方护盾', number(e.block));
      row('enemy_defense', '敌方常驻防御', number(e.defPower), number(e.defPower) > 0
        ? `${number(e.defPower)}（扣防后最低 1 点，再结算护盾）`
        : `${number(e.defPower)}（无常驻防御，无最低伤害保底）`);
      row('attack_base', '当前意图标称伤害', action.expectedDamage, `${action.expectedDamage}（尚未结算状态、反应与防护，不等于最终实伤）`);
      row('attack_piercing', '当前攻击穿透', piercing, piercing ? '无视常驻减伤、护盾与罡气' : '不穿透');
      row('incoming_multiplier', '当前对策护持倍率', incomingMultiplier, `来伤 ×${incomingMultiplier}`);
      row('karma_bonus', '当前业力追加伤害', karmaValue);
      row('first_hit_reduction', '当前首雷减伤', firstHitReduction);
      row('realm_suppression', '当前境界压制免伤', suppression, suppression ? '生效：抵抗后仍有余伤则免疫' : '未生效');
      row('attack_backlash', '牌效果前反噬', backlashValue, `${{ attack: '攻击', skill: '技能', power: '能力' }[backlashValue.cardType] || backlashValue.cardType}牌：${backlashValue.damage} 点气血（不走护盾）`);
      row('survive_turns', '生存胜利目标', surviveTurns, surviveTurns === null ? '无回合生存目标，按敌方击破结算' : `存活到第 ${surviveTurns} 回合敌方行动结算后也可获胜`);
      row('boss_phase', '当前相数', phase, `${phase.current} / ${phase.total}（${phase.current < phase.total
        ? '还有后续相，当前相击破不能结束整战' : '最终相，仍以正式胜利结算为准'}）`);
      return { version: 1, rows, limitations: [
        '仅说明当前生效的结算事实，不揭示未来行动、后续相位数值或未抽到的牌。',
        '出牌、反应和状态变化可能改变局势；这不是整回合必胜或生存保证。',
        '限时反应仍继续计时；阅读说明不会暂停或延长反应窗口。'
      ] };
  }

  getState() {
      if (!this.active) return null;
      return {
          player: this.player,
          enemy: this.enemy,
          qi: this.qi,
          maxQi: this.maxQi,
          hand: this.hand.map(id => this.getCardDef(id)),
          drawCount: this.drawPile.length,
          discardCount: this.discardPile.length,
          exhaustCount: this.exhaustPile.length,
          playerStatus: this.playerStatus,
          enemyStatus: this.enemyStatus,
          intent: this.enemyIntent,
          plan: this._getPlanStateView(),
          phase: this.phase,
          reaction: this._cloneReaction(this.pendingReaction),
          log: this.log,
          equipmentProgress: this._equipmentProgressView(),
          publicCombatFacts: this.getPublicCombatFacts(),
          turn: this.turn,
          archetype: (typeof pathArchetypeSystem !== 'undefined' && pathArchetypeSystem) ? pathArchetypeSystem.getSelected() : null,
          bossPhase: this.bossPhases.length ? {
            current: this.bossPhaseIndex + 1,
            total: this.bossPhases.length,
            name: this.enemy.name
          } : null,
          context: this._getPresentationContext()
      };
  }

  /**
   * Export the authoritative in-combat transaction. This snapshot is JSON-safe
   * and deliberately excludes timers/DOM; a reaction deadline is restored from
   * its absolute timestamp so refresh cannot grant a second window.
   */
  _authorityProjectionFromSnapshot(snapshot) {
      const clone = value => JSON.parse(JSON.stringify(value));
      return {
          phase: snapshot.phase,
          turn: Number(snapshot.turn),
          qi: Number(snapshot.qi),
          player: {
              hp: Number(snapshot.player?.hp),
              maxHp: Number(snapshot.player?.maxHp),
              block: Number(snapshot.player?.block),
              aura: Number(snapshot.player?.aura),
              atkMod: Number(snapshot.player?.atkMod),
              defMod: Number(snapshot.player?.defMod),
              critRate: Number(snapshot.player?.critRate)
          },
          enemy: {
              name: snapshot.enemy?.name || '',
              hp: Number(snapshot.enemy?.hp),
              maxHp: Number(snapshot.enemy?.maxHp),
              block: Number(snapshot.enemy?.block),
              tier: Number(snapshot.enemy?.tier),
              atkPower: Number(snapshot.enemy?.atkPower),
              defPower: Number(snapshot.enemy?.defPower),
              planRuntime: snapshot.enemy?.planRuntime ? clone(snapshot.enemy.planRuntime) : null
          },
          bossPhaseIndex: Number(snapshot.bossPhaseIndex) || 0,
          masterDeck: clone(snapshot.masterDeck || []),
          drawPile: clone(snapshot.drawPile || []),
          hand: clone(snapshot.hand || []),
          discardPile: clone(snapshot.discardPile || []),
          exhaustPile: clone(snapshot.exhaustPile || []),
          playerStatus: clone(snapshot.playerStatus || {}),
          enemyStatus: clone(snapshot.enemyStatus || {}),
          playerStatusesAppliedByEnemy: clone(snapshot.playerStatusesAppliedByEnemy || []),
          pendingReaction: snapshot.pendingReaction ? clone(snapshot.pendingReaction) : null,
          settledReactionWindows: clone(snapshot.settledReactionWindows || []),
          nextTurnDrawPenalty: Number(snapshot.nextTurnDrawPenalty),
          equipmentState: clone(snapshot.equipmentState || {}),
          damageDealtThisTurn: Boolean(snapshot.damageDealtThisTurn),
          pathCombatState: snapshot.pathCombatState ? clone(snapshot.pathCombatState) : null
      };
  }

  _legacyV2AuthorityProjectionFromSnapshot(snapshot) {
      const clone = value => JSON.parse(JSON.stringify(value));
      return {
          phase: snapshot.phase,
          turn: Number(snapshot.turn),
          qi: Number(snapshot.qi),
          player: {
              hp: Number(snapshot.player?.hp),
              block: Number(snapshot.player?.block),
              aura: Number(snapshot.player?.aura)
          },
          enemy: {
              hp: Number(snapshot.enemy?.hp),
              block: Number(snapshot.enemy?.block),
              planRuntime: snapshot.enemy?.planRuntime ? clone(snapshot.enemy.planRuntime) : null
          },
          masterDeck: clone(snapshot.masterDeck || []),
          drawPile: clone(snapshot.drawPile || []),
          hand: clone(snapshot.hand || []),
          discardPile: clone(snapshot.discardPile || []),
          exhaustPile: clone(snapshot.exhaustPile || []),
          playerStatus: clone(snapshot.playerStatus || {}),
          enemyStatus: clone(snapshot.enemyStatus || {}),
          playerStatusesAppliedByEnemy: clone(snapshot.playerStatusesAppliedByEnemy || []),
          pendingReaction: snapshot.pendingReaction ? clone(snapshot.pendingReaction) : null,
          settledReactionWindows: clone(snapshot.settledReactionWindows || []),
          nextTurnDrawPenalty: Number(snapshot.nextTurnDrawPenalty),
          equipmentState: clone(snapshot.equipmentState || {}),
          damageDealtThisTurn: Boolean(snapshot.damageDealtThisTurn)
      };
  }

  _currentAuthorityProjection() {
      return this._authorityProjectionFromSnapshot({
          phase: this.phase,
          turn: this.turn,
          qi: this.qi,
          player: this.player,
          enemy: this.enemy,
          bossPhaseIndex: this.bossPhaseIndex,
          masterDeck: this.masterDeck,
          drawPile: this.drawPile,
          hand: this.hand,
          discardPile: this.discardPile,
          exhaustPile: this.exhaustPile,
          playerStatus: this.playerStatus,
          enemyStatus: this.enemyStatus,
          playerStatusesAppliedByEnemy: Array.from(this._playerStatusesAppliedByEnemy || []),
          pendingReaction: this.pendingReaction,
          settledReactionWindows: Array.from(this._settledReactionWindows || []).slice(-40),
          nextTurnDrawPenalty: this._nextTurnDrawPenalty,
          equipmentState: this.equipmentState,
          damageDealtThisTurn: this.damageDealtThisTurn,
          pathCombatState: typeof pathArchetypeSystem !== 'undefined'
            && pathArchetypeSystem
            && typeof pathArchetypeSystem.exportCombatState === 'function'
            ? pathArchetypeSystem.exportCombatState()
            : null
      });
  }

  _recordAuthorityCheckpoint(kind, detail = {}) {
      if (!this.active) return false;
      const unsigned = {
          sequence: this._authorityLedger.length + 1,
          previous: this._authorityChain,
          kind,
          sourceCardId: this.originalCard?.id || null,
          turn: Math.max(1, Math.floor(Number(this.turn) || 1)),
          detail: JSON.parse(JSON.stringify(detail || {})),
          state: this._currentAuthorityProjection()
      };
      const hash = this._computeCombatAuthoritySeal({ ledgerEntry: unsigned });
      this._authorityLedger.push({ ...unsigned, hash });
      this._authorityChain = hash;
      return true;
  }

  _validateAuthorityLedger(snapshot) {
      const ledger = snapshot.authorityLedger;
      if (!Array.isArray(ledger) || ledger.length < 1 || ledger.length > 1024) return false;
      const allowedKinds = new Set(['TURN_START', 'CARD_PLAY', 'REACTION_OPEN', 'REACTION_RESOLVED', 'LEGACY_MIGRATED']);
      const reactionIds = new Set(['TAKE_HIT', 'GUARD', 'EVADE', 'DEFLECT', 'INTERRUPT', 'ABSORB', 'TRANSMUTE']);
      let previous = 'dc2-root';
      let previousTurn = 0;
      for (let index = 0; index < ledger.length; index++) {
          const entry = ledger[index];
          if (!entry || entry.sequence !== index + 1 || entry.previous !== previous
            || !allowedKinds.has(entry.kind)
            || entry.sourceCardId !== snapshot.originalCard?.id
            || !Number.isInteger(Number(entry.turn))
            || Number(entry.turn) < previousTurn
            || !entry.state || typeof entry.state !== 'object') return false;
          if (entry.kind === 'CARD_PLAY'
            && (typeof entry.detail?.cardId !== 'string' || !entry.detail.cardId
              || (Number(snapshot.version) >= 3
                && (!Number.isInteger(Number(entry.detail.handIndex))
                  || Number(entry.detail.handIndex) < 0)))) return false;
          if (entry.kind === 'REACTION_OPEN'
            && (typeof entry.detail?.windowId !== 'string' || !entry.detail.windowId)) return false;
          if (entry.kind === 'REACTION_RESOLVED'
            && (typeof entry.detail?.windowId !== 'string'
              || !reactionIds.has(entry.detail?.reactionId))) return false;
          const unsigned = { ...entry };
          delete unsigned.hash;
          const expectedHash = this._computeCombatAuthoritySeal({ ledgerEntry: unsigned });
          if (entry.hash !== expectedHash) return false;
          previous = entry.hash;
          previousTurn = Number(entry.turn);
      }
      if (snapshot.authorityChain !== previous) return false;
      const projectedSnapshot = Number(snapshot.version) >= 3
        ? this._authorityProjectionFromSnapshot(snapshot)
        : this._legacyV2AuthorityProjectionFromSnapshot(snapshot);
      return this._stableAuthoritySerialize(ledger[ledger.length - 1].state)
        === this._stableAuthoritySerialize(projectedSnapshot);
  }

  _buildOpeningDynamicAuthority(combatRules = {}) {
      const playerAuthority = this._buildPlayerAuthority();
      let playerBlock = playerAuthority.combatStartBlock;
      let qi = this._maxQiForRealm(gameState?.realm);
      const playerStatus = {};
      const equipmentState = {};
      const addStatus = (statusId, value) => {
          if (!statusId) return;
          playerStatus[statusId] = (Number(playerStatus[statusId]) || 0) + Math.max(0, Number(value) || 0);
      };
      const configuredCounters = [];
      if (combatRules?.counter) configuredCounters.push(combatRules.counter);
      if (combatRules?.counters && typeof combatRules.counters === 'object') {
          configuredCounters.push(...Object.values(combatRules.counters));
      }
      if (combatRules?.attackBacklash?.counter) configuredCounters.push(combatRules.attackBacklash.counter);
      for (const counter of configuredCounters) {
          if (counter?.flag && gameState?.hasFlag?.(counter.flag)) {
              playerBlock += Math.max(0, Number(counter.openingBlock) || 0);
          }
      }
      const narrativeStance = combatRules?.narrativeStance || {};
      if (narrativeStance.id === 'guarded') {
        playerBlock += Math.max(0, Number(narrativeStance.openingBlock) || 0);
      }
      if (narrativeStance.id === 'advance'
        && Number(narrativeStance.firstDamagingLightningReduction) > 0) {
        addStatus('qi_main_advance_ready', 1);
      }
      const equipmentPassives = typeof equipmentSystem !== 'undefined' && equipmentSystem
        && typeof equipmentSystem.getActivePassives === 'function'
        ? equipmentSystem.getActivePassives()
        : [];
       equipmentPassives.forEach((passive, index) => {
        const triggerCount = Math.max(0, Math.floor(Number(passive?.triggerCount) || 0));
        if (triggerCount > 0 || passive?.oncePerCombat === true) {
          equipmentState[this._equipmentPassiveStateKey(passive, index)] = 0;
        }
        const distinctTagsThreshold = Math.max(0, Math.floor(Number(passive?.distinctTagsThreshold) || 0));
        if (distinctTagsThreshold > 0) {
          equipmentState[this._equipmentDistinctTagStateKey(passive, index)] = [];
        }
          if (passive?.hook !== 'onCombatStart') return;
          const triggersNow = triggerCount <= 1;
          if (triggerCount > 1) equipmentState[`eq_${index}`] = 1;
           if (triggersNow && passive.effect === 'block') {
               playerBlock += Math.max(0, Number(passive.value) || 0);
           }
       });
       // The first authoritative checkpoint is captured after `_startTurn()`.
       // A once-per-combat opening card therefore needs its state receipt here,
       // otherwise a valid saved night-oath combat would look forged on reload.
       equipmentPassives.forEach((passive, index) => {
           if (passive?.hook !== 'onTurnStart' || passive?.oncePerCombat !== true) return;
           equipmentState[this._equipmentPassiveStateKey(passive, index)] = 1;
       });
      if (gameState?.path === 'body') {
          playerBlock += Math.min(1, Math.floor(Math.max(1, Number(playerAuthority.player.maxHp) || 1) * 0.25));
      }
      const combatAssist = typeof npcSystem !== 'undefined' && npcSystem
        && typeof npcSystem.getCombatAssist === 'function'
        ? npcSystem.getCombatAssist()
        : null;
      playerBlock += Math.max(0, Number(combatAssist?.block) || 0);
      if (combatAssist?.status) addStatus(combatAssist.status.id, combatAssist.status.value || 1);
      if (typeof treasureSystem !== 'undefined' && treasureSystem
        && typeof treasureSystem.getEquippedDefinitionIds === 'function') {
          for (const treasureId of treasureSystem.getEquippedDefinitionIds()) {
              const relic = treasureSystem.treasureDB?.[treasureId]?.relic?.combat_start;
              if (!relic) continue;
              if (relic.type === 'gain_block') playerBlock += Math.max(0, Number(relic.value) || 0);
              if (relic.type === 'gain_qi') qi = Math.min(qi + 5, qi + Math.max(0, Number(relic.value) || 0));
              if (relic.type === 'status') addStatus(relic.statusId, relic.value);
          }
      }
      return { playerBlock, playerStatus, enemyStatus: {}, qi, equipmentState };
  }

  _authorityValuesEqual(left, right) {
      return this._stableAuthoritySerialize(left) === this._stableAuthoritySerialize(right);
  }

  _validateAuthorityPartition(state) {
      const piles = ['masterDeck', 'drawPile', 'hand', 'discardPile', 'exhaustPile'];
      if (piles.some(field => !Array.isArray(state?.[field])
        || state[field].some(cardId => typeof cardId !== 'string'))) return false;
      const partition = [state.drawPile, state.hand, state.discardPile, state.exhaustPile].flat();
      // A fired equipment passive may inject one declared, non-master tactical
      // card. Keep that exception tied to its fired state key; all permanent
      // cards still have to partition exactly against the master deck.
      const permittedTemporary = new Set(this._authorityEquipmentPassives().flatMap((passive, index) => (
        passive?.temporaryTacticalCardId
          && Number(state.equipmentState?.[this._equipmentPassiveStateKey(passive, index)]) > 0
          ? [passive.temporaryTacticalCardId]
          : []
      )));
      const temporary = partition.filter(cardId => permittedTemporary.has(cardId));
      if ([...new Set(temporary)].some(cardId => temporary.filter(id => id === cardId).length > 1)) return false;
      return this._sameCardMultiset(
        partition.filter(cardId => !permittedTemporary.has(cardId)),
        state.masterDeck
      );
  }

  _authorityCardDef(cardId, cardDB = {}) {
      if (typeof cardId !== 'string' || !cardId) return null;
      if (cardDB[cardId]) return cardDB[cardId];
      const baseId = cardId.replace(/\++$/, '');
      const base = cardDB[baseId];
      if (!base || baseId === cardId) return base || null;
      const authority = this.deckAuthority
        || (typeof skillCardAcquisitionSystem !== 'undefined' ? skillCardAcquisitionSystem : null);
      return authority?.buildUpgradedCard?.(base, cardId) || null;
  }

  _pathTurnBoundary(state, turnOpen) {
      if (!state) return null;
      return {
        ...JSON.parse(JSON.stringify(state)),
        cardsThisTurn: [],
        triggeredThisTurn: [],
        turnOpen: Boolean(turnOpen)
      };
  }

  _previewAuthorityPathCard(previous, card, snapshot) {
      if (!previous.pathCombatState) {
        return { valid: typeof pathArchetypeSystem === 'undefined' || !pathArchetypeSystem, synergy: null, state: null };
      }
      if (typeof pathArchetypeSystem === 'undefined' || !pathArchetypeSystem
        || typeof pathArchetypeSystem.previewCardTransition !== 'function') {
        return { valid: false, synergy: null, state: null };
      }
      const transition = pathArchetypeSystem.previewCardTransition(previous.pathCombatState, card, {
        player: { ...snapshot.player, hp: previous.player.hp, block: previous.player.block },
        enemy: { ...snapshot.enemy, hp: previous.enemy.hp, block: previous.enemy.block },
        playerStatus: previous.playerStatus,
        enemyStatus: previous.enemyStatus,
        qi: previous.qi,
        maxQi: snapshot.maxQi
      });
      return transition
        ? { valid: true, synergy: transition.synergy, state: transition.combatState }
        : { valid: false, synergy: null, state: null };
  }

  _authorityEquipmentPassives() {
      return typeof equipmentSystem !== 'undefined' && equipmentSystem
        && typeof equipmentSystem.getActivePassives === 'function'
        ? equipmentSystem.getActivePassives()
        : [];
  }

  _validateAuthorityReactionWindow(pending, expectedAction, state, snapshot) {
      if (!pending || !expectedAction || !state?.enemy) return false;
      const expectedOptions = this._buildReactionOptions(expectedAction, {
        qi: state.qi,
        pathId: typeof gameState !== 'undefined' && gameState?.path ? gameState.path : 'sword'
      });
      const pausedTiming = pending.mode === 'paused'
        && pending.durationMs === null
        && pending.deadlineAt === null;
      const timedTiming = pending.mode === 'timed'
        && Number(pending.durationMs) === 8000
        && Number.isFinite(Number(pending.openedAt))
        && Number(pending.deadlineAt) === Number(pending.openedAt) + 8000;
      return Number(pending.version) === 1
        && typeof pending.windowId === 'string'
        && pending.windowId.startsWith(`${snapshot.originalCard?.id}:turn:${state.turn}:reaction:`)
        && Number(pending.turn) === Number(state.turn)
        && pending.sourceCardId === snapshot.originalCard?.id
        && pending.source === state.enemy.name
        && pending.target === 'player'
        && (pausedTiming || timedTiming)
        && this._authorityValuesEqual(pending.action, expectedAction)
        && this._authorityValuesEqual(pending.options, expectedOptions);
  }

  _validateAuthorityTurnPiles(
    previous,
    current,
    reactionId,
    snapshot,
    activePassives = [],
    combatRules = {}
  ) {
      if (!this._authorityValuesEqual(current.masterDeck, previous.masterDeck)
        || !this._authorityValuesEqual(current.exhaustPile, previous.exhaustPile)) return false;
      const equipmentDraw = activePassives
        .filter(passive => passive.effect === 'drawCard')
        .reduce((sum, passive) => sum + Math.max(0, Math.floor(Number(passive.value) || 1)), 0);
      const drawPenalty = reactionId === 'EVADE' ? 1 : 0;
      const regularDraw = Math.max(0, 5 - drawPenalty);
      const normalDraw = Math.min(5, equipmentDraw + regularDraw);
      const judgment = combatRules?.karmaJudgment;
      const goodKey = judgment?.goodAttribute || 'karmaGood';
      const badKey = judgment?.badAttribute || 'karmaBad';
      const karmaGood = Number(gameState?.attributes?.[goodKey]) || 0;
      const karmaBad = Number(gameState?.attributes?.[badKey]) || 0;
      const goodDraw = judgment?.timing === 'after_draw' && karmaGood > karmaBad
        ? Math.max(0, Math.floor(Number(judgment.goodDraw) || 0))
        : 0;
      const requestedDraw = normalDraw + goodDraw;
      const available = previous.drawPile.length + previous.discardPile.length;
      const actualDraw = Math.min(requestedDraw, available);
      const badDiscard = judgment?.timing === 'after_draw' && karmaBad > karmaGood
        ? Math.min(actualDraw, Math.max(0, Math.floor(Number(judgment.badDiscard) || 0)))
        : 0;
      if (current.hand.length !== actualDraw - badDiscard) return false;

      const directCount = Math.min(actualDraw, previous.drawPile.length);
      const directDrawn = previous.drawPile.slice(previous.drawPile.length - directCount).reverse();
      const expectedDirectRemainder = previous.drawPile.slice(0, previous.drawPile.length - directCount);
      const reshuffled = actualDraw > previous.drawPile.length;
      const discardDrawCount = Math.max(0, actualDraw - directCount);
      if (!reshuffled) {
        if (!this._authorityValuesEqual(current.drawPile, expectedDirectRemainder)) return false;
        const discardPrefix = previous.discardPile;
        if (current.discardPile.length !== discardPrefix.length + badDiscard
          || !this._authorityValuesEqual(current.discardPile.slice(0, discardPrefix.length), discardPrefix)) return false;
        const removed = current.discardPile.slice(discardPrefix.length);
        if (!this._sameCardMultiset([...current.hand, ...removed], directDrawn)) return false;
        // Random karma discards may remove arbitrary positions, but the cards
        // left in hand retain the order in which they were drawn.
        let handCursor = 0;
        for (const cardId of directDrawn) {
          if (current.hand[handCursor] === cardId) handCursor += 1;
        }
        return handCursor === current.hand.length;
      }

      if (expectedDirectRemainder.length !== 0) return false;
      const removed = current.discardPile;
      if (removed.length !== badDiscard) return false;
      const selectedFromDiscard = [...current.hand, ...removed].slice(directDrawn.length);
      // The reshuffle makes order nondeterministic, but not identity or count.
      // Direct pre-shuffle cards may also be removed by bad karma, so validate
      // the complete drawn/removed multiset and the exact remaining deck.
      const allObservedDrawn = [...current.hand, ...removed];
      const expectedSelectedCount = discardDrawCount;
      if (allObservedDrawn.length !== actualDraw
        || selectedFromDiscard.length !== expectedSelectedCount) {
        // When a direct card was discarded, slicing cannot locate the boundary;
        // fall through to the stronger whole-partition equations below.
      }
      if (!this._sameCardMultiset(
        [...current.drawPile, ...allObservedDrawn],
        [...previous.discardPile, ...directDrawn]
      )) return false;
      if (current.drawPile.length !== previous.discardPile.length - discardDrawCount) return false;
      return directDrawn.every(cardId =>
        allObservedDrawn.filter(observed => observed === cardId).length
          >= directDrawn.filter(expected => expected === cardId).length
      );
  }

  _validateNonPlanIntentAuthority(snapshot, authoredIntents, randomIntents = false, canonicalCard = null) {
      const fixedCycle = this._getAuthoritativeTurnCycle(canonicalCard);
      if (!Array.isArray(authoredIntents) || (!fixedCycle && authoredIntents.length === 0)
        || snapshot.enemy?.planRuntime) return false;
      const ledger = snapshot.authorityLedger || [];
      const finalPhase = Number(snapshot.bossPhaseIndex) || 0;
      let phaseStart = 0;
      for (let index = 1; index < ledger.length; index++) {
        if (Number(ledger[index].state?.bossPhaseIndex) === finalPhase
          && Number(ledger[index - 1].state?.bossPhaseIndex) !== finalPhase) phaseStart = index;
      }
      const phaseEntries = ledger.slice(phaseStart);
      const generationStates = [];
      if (phaseEntries[0]?.state) generationStates.push(phaseEntries[0].state);
      for (let index = 1; index < phaseEntries.length; index++) {
        if (phaseEntries[index].kind === 'TURN_START') generationStates.push(phaseEntries[index].state);
      }
      const openEntries = phaseEntries.filter(entry => entry.kind === 'REACTION_OPEN');
      const observed = openEntries.map(entry => ({
        action: entry.state.pendingReaction?.action,
        pending: entry.state.pendingReaction,
        state: entry.state
      }));
      if (snapshot.phase === 'PLAYER_TURN') {
        observed.push({
          action: this._previewEnemyAction(snapshot.enemyIntent, snapshot.enemy),
          pending: null,
          state: snapshot
        });
      }
      if (generationStates.length !== observed.length || generationStates.length === 0) return false;

      const normalIntents = authoredIntents.filter(intent => !intent?.condition);
      if (!fixedCycle && normalIntents.length === 0) return false;
      const usedConditions = new Set();
      let intentIndex = 0;
      let lastIntent = null;
      for (let index = 0; index < generationStates.length; index++) {
        const generation = generationStates[index];
        const conditional = !fixedCycle && authoredIntents.find(intent => {
          if (intent?.condition?.type !== 'hp_below') return false;
          const ratio = Number(generation.enemy?.hp) / Math.max(1, Number(generation.enemy?.maxHp));
          return ratio <= Number(intent.condition.value)
            && (!usedConditions.has(intent.desc) || intent.condition.repeatable === true);
        }) || null;
        let expectedIntent = conditional;
        if (fixedCycle) {
          expectedIntent = this._resolveTurnCycleIntent(
            canonicalCard, generation.turn, authoredIntents, generation.enemy
          );
          intentIndex += 1;
        } else if (conditional) usedConditions.add(conditional.desc);
        else if (randomIntents) {
          expectedIntent = normalIntents.find(intent =>
            this._authorityValuesEqual(
              this._previewEnemyAction(intent, generation.enemy),
              observed[index].action
            )
          ) || null;
        } else {
          expectedIntent = normalIntents[intentIndex % normalIntents.length];
          intentIndex += 1;
        }
        if (!expectedIntent) return false;
        const expectedAction = this._previewEnemyAction(expectedIntent, generation.enemy);
        if (!this._authorityValuesEqual(observed[index].action, expectedAction)) return false;
        if (observed[index].pending
          && !this._validateAuthorityReactionWindow(
            observed[index].pending,
            expectedAction,
            observed[index].state,
            snapshot
          )) return false;
        lastIntent = expectedIntent;
      }
      if (!lastIntent || !this._authorityValuesEqual(snapshot.enemyIntent, lastIntent)
        || Number(snapshot.enemy.intentIndex) !== (!fixedCycle && randomIntents ? 0 : intentIndex)
        || !this._authorityValuesEqual(snapshot.enemy.usedConditions || [], Array.from(usedConditions))) return false;
      return true;
  }

  _validateAuthorityPlanCard(
    previousRuntime,
    currentRuntime,
    card,
    currentQi,
    graph,
    snapshot,
    previousEnemy = null,
    currentEnemy = null
  ) {
      if (!previousRuntime && !currentRuntime) return true;
      if (!previousRuntime || !currentRuntime || !graph) return false;
      const expected = JSON.parse(JSON.stringify(previousRuntime));
      const memory = expected.turnMemory;
      if (!memory || Number(memory.turn) <= 0) return false;
      const type = String(card.type || 'unknown');
      const cost = Math.max(0, Number(card.cost) || 0);
      memory.cardsPlayed += 1;
      memory.qiSpent += cost;
      memory.cardTypes.push(type);
      memory.playedCards.push({ id: String(card.id || ''), type, cost });
      if (memory.consecutiveType === type) memory.consecutiveCount += 1;
      else {
        memory.consecutiveType = type;
        memory.consecutiveCount = 1;
      }
      memory.qiRemaining = Number(currentQi);
      memory.qiGained = Math.max(0, Number(currentQi) + Number(memory.qiSpent) - Number(snapshot?.maxQi));
      const matches = (transition, cause) => {
        if (!transition || transition.when !== cause || !transition.from.includes(expected.currentState)) return false;
        if (cause === 'player_overcommitted') {
          return memory.cardsPlayed >= Math.max(1, Number(transition.minCards) || 2)
            && memory.qiRemaining <= Math.max(0, Number(transition.maxReservedQi) || 0);
        }
        return cause === 'repeated_card_type'
          && memory.consecutiveCount >= Math.max(2, Number(transition.minConsecutive) || 2);
      };
      const applyTransition = (cause, refreshIntent = true) => {
        const transition = (graph.transitions || []).find(candidate =>
          candidate.when === cause && candidate.from.includes(expected.currentState)
        );
        if (!transition || transition.to === expected.currentState) return false;
        const from = expected.currentState;
        expected.currentState = transition.to;
        if (refreshIntent) expected.intentState = transition.to;
        expected.transitionSequence += 1;
        expected.lastTransition = {
          planId: expected.planId,
          from,
          to: transition.to,
          cause,
          turn: memory.turn,
          sourceCardId: null,
          sequence: expected.transitionSequence
        };
        memory.consumedSignals.push(`${memory.turn}:${from}:${cause}`);
        return true;
      };
      const transition = (graph.transitions || []).find(candidate =>
        ['player_overcommitted', 'repeated_card_type'].includes(candidate.when)
        && matches(candidate, candidate.when)
      );
      if (transition && transition.to !== expected.currentState) {
        applyTransition(transition.when);
      }
      if (Number(previousEnemy?.block) > 0 && Number(currentEnemy?.block) === 0) {
        applyTransition('enemy_block_broken');
      }
      const encounterMemory = expected.encounterMemory;
      if (['first_action_family_v1', 'first_action_family_and_semantic_action_v2']
        .includes(graph.memoryContract?.kind) && encounterMemory) {
        const family = this._resolveEncounterActionFamily(card, encounterMemory.fallbackActionFamily);
        if (!graph.memoryContract.allowedFamilies.includes(family)) return false;
        const semanticActionFamily = this._resolveEncounterSemanticActionFamily(card);
        const isSemanticSequence = graph.memoryContract.kind === 'first_action_family_and_semantic_action_v2';
        if (isSemanticSequence
          && !graph.memoryContract.allowedSemanticActionFamilies.includes(semanticActionFamily)) return false;
        if (encounterMemory.capturedFirstActionFamily === null) {
          encounterMemory.capturedFirstActionFamily = family;
          encounterMemory.capturedFirstActionCardId = String(card?.id || '');
          if (isSemanticSequence) {
            encounterMemory.capturedFirstSemanticActionFamily = semanticActionFamily;
          }
          encounterMemory.captureSequence += 1;
          encounterMemory.sequenceBroken = false;
          applyTransition('first_card_recorded', Number(currentEnemy?.hp) > 0);
        } else if ((isSemanticSequence
          ? encounterMemory.capturedFirstSemanticActionFamily !== semanticActionFamily
          : encounterMemory.capturedFirstActionFamily !== family)
          && encounterMemory.sequenceBroken !== true) {
          if (applyTransition('sequence_broken', Number(currentEnemy?.hp) > 0)) {
            encounterMemory.sequenceBroken = true;
          }
        }
      }
      // sourceCardId is filled from the encounter at runtime and is checked by
      // the enclosing snapshot contract; normalize it for this pure replay.
      if (expected.lastTransition && currentRuntime.lastTransition) {
        expected.lastTransition.sourceCardId = currentRuntime.lastTransition.sourceCardId;
      }
      return this._authorityValuesEqual(expected, currentRuntime);
  }

  _validateAuthorityCardPlay(previous, current, entry, snapshot, cardDB, combatRules = {}, enemyDB = this.enemyDB) {
      if (previous.phase !== 'PLAYER_TURN' || current.phase !== 'PLAYER_TURN'
        || current.turn !== previous.turn
        || previous.pendingReaction !== null || current.pendingReaction !== null
        || !this._authorityValuesEqual(previous.settledReactionWindows, current.settledReactionWindows)
        || !this._authorityValuesEqual(previous.masterDeck, current.masterDeck)) return false;
      const handIndex = Number(entry.detail?.handIndex);
      const playedId = entry.detail?.cardId;
      if (!Number.isInteger(handIndex) || handIndex < 0 || previous.hand[handIndex] !== playedId) return false;
      const card = this._authorityCardDef(playedId, cardDB);
      if (!card) return false;
      const pathTransition = this._previewAuthorityPathCard(previous, card, snapshot);
      if (!pathTransition.valid || !this._authorityValuesEqual(current.pathCombatState, pathTransition.state)) return false;
      const synergy = pathTransition.synergy || { damageBonus: 0, blockBonus: 0, gainQi: 0, enemyStatuses: [], playerStatuses: [] };
      const passives = this._authorityEquipmentPassives();
      const passiveMatches = passive => passive?.hook === 'onCardPlay'
        && (!passive.cardType || passive.cardType === card.type)
        && (!passive.cardTag || (card.tags || []).includes(passive.cardTag));
      const expectedEquipmentState = JSON.parse(JSON.stringify(previous.equipmentState || {}));
      const effectivePassives = [];
      passives.forEach((passive, index) => {
        if (!passiveMatches(passive)) return;
        const stateKey = this._equipmentPassiveStateKey(passive, index);
        // Mirror runtime: a once-per-combat temporary route is frozen after
        // firing, so playing its granted card cannot forge a fourth lineage.
        if (passive.oncePerCombat === true && Number(expectedEquipmentState[stateKey]) > 0) return;
        const threshold = Math.max(0, Math.floor(Number(passive?.distinctTagsThreshold) || 0));
        if (threshold > 0) {
          const tag = this._equipmentDistinctTag(passive, card);
          if (!tag) return;
          const tagsKey = this._equipmentDistinctTagStateKey(passive, index);
          const seen = Array.isArray(expectedEquipmentState[tagsKey]) ? expectedEquipmentState[tagsKey] : [];
          if (!seen.includes(tag)) seen.push(tag);
          expectedEquipmentState[tagsKey] = seen;
          if (seen.length < threshold) return;
        }
        if (passive.oncePerCombat === true) {
          expectedEquipmentState[stateKey] = 1;
          effectivePassives.push(passive);
          return;
        }
        if (Number(passive.triggerCount) > 0) {
          const nextCount = (Number(expectedEquipmentState[stateKey]) || 0) + 1;
          if (nextCount >= Number(passive.triggerCount)) {
            expectedEquipmentState[stateKey] = 0;
            effectivePassives.push(passive);
          } else {
            expectedEquipmentState[stateKey] = nextCount;
          }
        } else {
          effectivePassives.push(passive);
        }
      });
      const effects = Array.isArray(card.effects) ? card.effects : [];
      const guardResolved = card.type !== 'attack' && effects.some(effect => effect?.type === 'block');
      if (guardResolved) {
        passives.forEach((passive, index) => {
          if (passive?.hook !== 'onGuardResolved') return;
          const stateKey = this._equipmentPassiveStateKey(passive, index);
          if (passive.oncePerCombat === true) {
            if (Number(expectedEquipmentState[stateKey]) > 0) return;
            expectedEquipmentState[stateKey] = 1;
            effectivePassives.push(passive);
            return;
          }
          if (Number(passive.triggerCount) > 0) {
            const nextCount = (Number(expectedEquipmentState[stateKey]) || 0) + 1;
            if (nextCount >= Number(passive.triggerCount)) {
              expectedEquipmentState[stateKey] = 0;
              effectivePassives.push(passive);
            } else {
              expectedEquipmentState[stateKey] = nextCount;
            }
            return;
          }
          effectivePassives.push(passive);
        });
      }
      if (!this._authorityValuesEqual(current.equipmentState, expectedEquipmentState)
        || !this._authorityValuesEqual(current.playerStatusesAppliedByEnemy, previous.playerStatusesAppliedByEnemy)
        || Number(current.nextTurnDrawPenalty) !== Number(previous.nextTurnDrawPenalty)) return false;
      const maxDraw = effects.reduce((sum, effect) => {
        if (effect.type === 'draw') return sum + Math.max(0, Math.floor(Number(effect.value) || 0));
        if (effect.type === 'draw_per_status') {
          return sum + Math.max(0, Math.floor(Number(previous.playerStatus?.[effect.statusId]) || 0));
        }
        return sum;
      }, 0) + effectivePassives.filter(passive => passive.effect === 'drawCard')
        .reduce((sum, passive) => sum + Math.max(0, Math.floor(Number(passive.value) || 1)), 0);
      const grantedTemporaryCards = effectivePassives
        .filter(passive => passive.effect === 'grantTemporaryCard'
          && typeof passive.temporaryTacticalCardId === 'string'
          && !previous.hand.includes(passive.temporaryTacticalCardId)
          && !previous.exhaustPile.includes(passive.temporaryTacticalCardId)
          && !previous.discardPile.includes(passive.temporaryTacticalCardId))
        .map(passive => passive.temporaryTacticalCardId);
      const expectedHandBase = [
        ...previous.hand.filter((_, index) => index !== handIndex),
        ...grantedTemporaryCards
      ];
      if (current.hand.length < expectedHandBase.length
        || current.hand.length > expectedHandBase.length + maxDraw
        || !this._authorityValuesEqual(current.hand.slice(0, expectedHandBase.length), expectedHandBase)) return false;
      const drawnIds = current.hand.slice(expectedHandBase.length);
      let simulatedDraw = [...previous.drawPile];
      let simulatedDiscard = [...previous.discardPile];
      let reshuffled = false;
      for (const drawnId of drawnIds) {
        if (simulatedDraw.length > 0 && !reshuffled) {
          if (simulatedDraw.pop() !== drawnId) return false;
          continue;
        }
        if (simulatedDraw.length === 0) {
          if (simulatedDiscard.length === 0) return false;
          simulatedDraw = [...simulatedDiscard];
          simulatedDiscard = [];
          reshuffled = true;
        }
        const drawnIndex = simulatedDraw.indexOf(drawnId);
        if (drawnIndex < 0) return false;
        simulatedDraw.splice(drawnIndex, 1);
      }
      if (drawnIds.length < maxDraw
        && current.hand.length < 5
        && (simulatedDraw.length > 0 || simulatedDiscard.length > 0)) return false;
      const expectedDiscard = card.exhaust
        ? simulatedDiscard
        : [...simulatedDiscard, playedId];
      const expectedExhaust = card.exhaust
        ? [...previous.exhaustPile, playedId]
        : previous.exhaustPile;
      if (!this._authorityValuesEqual(current.discardPile, expectedDiscard)
        || !this._authorityValuesEqual(current.exhaustPile, expectedExhaust)
        || (reshuffled
          ? !this._sameCardMultiset(current.drawPile, simulatedDraw)
          : !this._authorityValuesEqual(current.drawPile, simulatedDraw))) return false;
      let expectedQi = Number(previous.qi) - Math.max(0, Number(card.cost) || 0);
      if (expectedQi < 0) return false;
      for (const effect of effects) {
        if (effect.type === 'gain_qi') expectedQi = Math.min(Number(snapshot.maxQi) + 5, expectedQi + Math.max(0, Number(effect.value) || 0));
      }
      expectedQi = Math.min(Number(snapshot.maxQi) + 5, expectedQi + Math.max(0, Number(synergy.gainQi) || 0));
      if (card.type === 'attack' && typeof treasureSystem !== 'undefined' && treasureSystem
        && typeof treasureSystem.getEquippedDefinitionIds === 'function') {
        for (const treasureId of treasureSystem.getEquippedDefinitionIds()) {
          const relic = treasureSystem.treasureDB?.[treasureId]?.relic?.play_attack;
          if (relic?.type === 'gain_qi') expectedQi = Math.min(Number(snapshot.maxQi) + 5, expectedQi + Math.max(0, Number(relic.value) || 0));
        }
      }
      if (Number(current.qi) !== expectedQi) return false;

      let expectedPlayerHp = Number(previous.player.hp);
      for (const passive of effectivePassives) {
        if (passive.effect === 'heal') {
          expectedPlayerHp = Math.min(
            Number(previous.player.maxHp),
            expectedPlayerHp + Math.max(0, Number(passive.value) || 0)
          );
        }
      }
      const attackBacklash = combatRules?.attackBacklash;
      if (attackBacklash && card.type === (attackBacklash.triggerCardType || 'attack')) {
        const counterFlag = attackBacklash.counter?.flag;
        const counterActive = counterFlag && gameState?.hasFlag?.(counterFlag);
        if (!counterActive) {
          expectedPlayerHp = Math.max(
            0,
            expectedPlayerHp - Math.max(0, Math.floor(Number(attackBacklash.damage) || 0))
          );
        }
      }
      for (const effect of effects) {
        if (effect.type === 'heal') {
          const pillMultiplier = (card.tags || []).includes('pill')
            ? 1 + Math.max(0, Number(snapshot.player?.pillBonus) || 0) / 100
            : 1;
          expectedPlayerHp = Math.min(
            Number(previous.player.maxHp),
            expectedPlayerHp + Math.floor(Math.max(0, Number(effect.value) || 0) * pillMultiplier)
          );
        } else if (effect.type === 'backlash') {
          expectedPlayerHp = Math.max(0, expectedPlayerHp - Math.max(0, Number(effect.value) || 0));
        }
      }

      const blockEffects = effects.filter(effect => effect.type === 'block');
      let exactPlayerBlockIncrease = blockEffects
        .reduce((sum, effect) => sum + Math.max(0, Number(effect.value) || 0), 0);
      if (blockEffects.length > 0) exactPlayerBlockIncrease += Math.max(0, Number(synergy.blockBonus) || 0);
      exactPlayerBlockIncrease += effectivePassives.filter(passive => passive.effect === 'block')
        .reduce((sum, passive) => sum + Math.max(0, Number(passive.value) || 0), 0);
      if (card.type === 'attack' && typeof treasureSystem !== 'undefined' && treasureSystem
        && typeof treasureSystem.getEquippedDefinitionIds === 'function') {
        for (const treasureId of treasureSystem.getEquippedDefinitionIds()) {
          const relic = treasureSystem.treasureDB?.[treasureId]?.relic?.play_attack;
          if (relic?.type === 'gain_block') exactPlayerBlockIncrease += Math.max(0, Number(relic.value) || 0);
        }
      }
      // Reproduce every reachable direct-damage total. A min/max envelope is
      // insufficient here: a self-consistent save could otherwise claim that
      // a deterministic attack dealt zero damage while still consuming the
      // card, qi, statuses and plan memory. Critical hits are the only random
      // branch in the authored player damage pipeline, so retain both legal
      // totals when the rate is strictly between 0 and 100.
      let damageStates = [{
        total: 0,
        playerStatus: JSON.parse(JSON.stringify(previous.playerStatus || {})),
        enemyStatus: JSON.parse(JSON.stringify(previous.enemyStatus || {})),
        synergyDamageAvailable: Math.max(0, Number(synergy.damageBonus) || 0)
      }];
      const applyDamageSource = (states, baseDamage, { cardDamage = false, conditional = null } = {}) => {
        const next = [];
        for (const sourceState of states) {
          const state = JSON.parse(JSON.stringify(sourceState));
          let damage = Math.max(0, Number(baseDamage) || 0);
          if (cardDamage && conditional) {
            const statusValue = Math.max(0, Number(state.playerStatus[conditional.statusId]) || 0);
            if (statusValue >= conditional.threshold) {
              if (conditional.multiply) damage *= conditional.multiply;
              if (conditional.add) damage += conditional.add;
              if (conditional.consume) {
                state.playerStatus[conditional.statusId] = typeof conditional.consume === 'number'
                  ? Math.max(0, statusValue - conditional.consume)
                  : 0;
              }
            }
          }
          if (cardDamage && state.synergyDamageAvailable > 0) {
            damage += state.synergyDamageAvailable;
            state.synergyDamageAvailable = 0;
          }
          if (cardDamage && Number(snapshot.player?.lowHpAtkBonus) > 1
            && Number(previous.player.hp) / Math.max(1, Number(previous.player.maxHp)) <= 0.3) {
            damage = Math.floor(damage * Number(snapshot.player.lowHpAtkBonus));
          }
          if (cardDamage && Number(snapshot.player?.lowHpDamageBonus) > 0
            && Number(previous.player.hp) / Math.max(1, Number(previous.player.maxHp)) <= 0.5) {
            damage += Number(snapshot.player.lowHpDamageBonus);
          }
          if (cardDamage && !conditional?.statusId && Number(state.playerStatus.sword_intent) > 0) {
            damage += Number(state.playerStatus.sword_intent);
            state.playerStatus.sword_intent = 0;
          }
          const critRate = cardDamage ? Math.max(0, Number(snapshot.player?.critRate) || 0) : 0;
          const criticalVariants = critRate <= 0
            ? [damage]
            : (critRate >= 100 ? [Math.floor(damage * 1.5)] : [damage, Math.floor(damage * 1.5)]);
          for (let resolvedDamage of new Set(criticalVariants)) {
            const variant = JSON.parse(JSON.stringify(state));
            if (Number(variant.playerStatus.weak) > 0) resolvedDamage = Math.floor(resolvedDamage * 0.75);
            if (Number(variant.enemyStatus.vulnerable) > 0) resolvedDamage = Math.ceil(resolvedDamage * 1.5);
            if (cardDamage && card.type === 'attack' && Number(variant.enemyStatus.opening) > 0) {
              const openingBonus = Math.min(1, Number(variant.enemyStatus.opening));
              resolvedDamage += openingBonus;
              variant.enemyStatus.opening = Math.max(0, Number(variant.enemyStatus.opening) - openingBonus);
            }
            resolvedDamage += Math.max(0, Number(snapshot.player?.atkMod) || 0);
            if (Number(snapshot.enemy?.defPower) > 0) {
              resolvedDamage = Math.max(1, resolvedDamage - Number(snapshot.enemy.defPower));
            }
            if (Number(variant.playerStatus.counter_force) > 0) {
              resolvedDamage += Number(variant.playerStatus.counter_force);
              variant.playerStatus.counter_force = 0;
            }
            variant.total += Math.max(0, Math.floor(resolvedDamage));
            next.push(variant);
          }
        }
        return next;
      };
      for (const passive of effectivePassives) {
        if (passive.effect === 'dealDamage') {
          damageStates = applyDamageSource(damageStates, passive.value);
        }
      }
      for (const effect of effects) {
        if (effect.type === 'damage') {
          damageStates = applyDamageSource(damageStates, effect.value, {
            cardDamage: true,
            conditional: effect.conditional_status ? {
              statusId: effect.conditional_status,
              threshold: Math.max(1, Number(effect.conditional_value) || 1),
              multiply: effect.conditional_multiply ? Math.max(1, Number(effect.conditional_multiply) || 1) : 0,
              add: Math.max(0, Number(effect.conditional_add) || 0),
              consume: effect.consume_status || null
            } : null
          });
        } else if (effect.type === 'status' && effect.statusId) {
          for (const state of damageStates) {
            const table = effect.target === 'enemy' ? state.enemyStatus : state.playerStatus;
            const currentValue = Math.max(0, Number(table[effect.statusId]) || 0);
            const requested = Math.max(0, Number(effect.value) || 0);
            const hasCap = effect.maxStacks !== null && effect.maxStacks !== undefined
              && Number.isFinite(Number(effect.maxStacks));
            const applied = hasCap
              ? Math.max(0, Math.min(requested, Number(effect.maxStacks) - currentValue))
              : requested;
            table[effect.statusId] = currentValue + applied;
          }
        }
      }
      const reachableDamageTotals = new Set(damageStates.map(state => state.total));
      const maxDamage = Math.max(0, ...reachableDamageTotals);
      const phaseAdvanced = Number(current.bossPhaseIndex) === Number(previous.bossPhaseIndex) + 1;
      const enemyHpLoss = Number(previous.enemy.hp) - Number(current.enemy.hp);
      if (![Number(previous.bossPhaseIndex), Number(previous.bossPhaseIndex) + 1].includes(Number(current.bossPhaseIndex))
        || Number(current.player.maxHp) !== Number(previous.player.maxHp)
        || Number(current.player.aura) !== Number(previous.player.aura)
        || Number(current.player.atkMod) !== Number(previous.player.atkMod)
        || Number(current.player.defMod) !== Number(previous.player.defMod)
        || Number(current.player.critRate) !== Number(previous.player.critRate)) return false;
      if (!phaseAdvanced && (Number(current.enemy.hp) > Number(previous.enemy.hp)
        || enemyHpLoss > maxDamage
        || Number(current.enemy.block) > Number(previous.enemy.block)
        || current.enemy.name !== previous.enemy.name
        || Number(current.enemy.maxHp) !== Number(previous.enemy.maxHp)
        || Number(current.enemy.tier) !== Number(previous.enemy.tier)
        || Number(current.enemy.atkPower) !== Number(previous.enemy.atkPower)
        || Number(current.enemy.defPower) !== Number(previous.enemy.defPower))) return false;
      if (!phaseAdvanced) {
        const previousBlock = Math.max(0, Number(previous.enemy.block) || 0);
        const reachableEnemyState = [...reachableDamageTotals].some(total => {
          const expectedBlock = Math.max(0, previousBlock - total);
          const expectedHpLoss = Math.max(0, total - previousBlock);
          return Number(current.enemy.block) === expectedBlock && enemyHpLoss === expectedHpLoss;
        });
        if (!reachableEnemyState) return false;
      } else {
        if (![...reachableDamageTotals].some(total => total >= Number(previous.enemy.hp) + Number(previous.enemy.block))) {
          return false;
        }
        const nextPhase = snapshot.bossPhases?.[Number(current.bossPhaseIndex)];
        const rootEnemy = snapshot.originalCard?.enemy || {};
        if (!nextPhase) return false;
        const nextTier = Number(nextPhase.tier || rootEnemy.tier || 1);
        const nextTemplate = this._resolveEnemyDef(nextPhase, nextTier, enemyDB);
        const nextMaxHp = Number(nextPhase.hp || (nextTier === 2 ? 8 : nextTier === 3 ? 15 : 3));
        const nextBlock = Math.max(0, Number(nextPhase.block) || 0)
          + Math.max(0, Number(nextPhase.entryEffect?.block) || 0);
        const nextAtk = Number(nextPhase.atk || rootEnemy.atk || nextTier);
        const nextDef = Number(nextPhase.def || rootEnemy.def || 0);
        const nextName = nextPhase.name || nextTemplate?.name || rootEnemy.name || '修仙者';
        if (current.enemy.name !== nextName
          || Number(current.enemy.hp) !== nextMaxHp
          || Number(current.enemy.maxHp) !== nextMaxHp
          || Number(current.enemy.block) !== nextBlock
          || Number(current.enemy.tier) !== nextTier
          || Number(current.enemy.atkPower) !== nextAtk
          || Number(current.enemy.defPower) !== nextDef) return false;
      }
      if (Number(current.player.block) !== Number(previous.player.block) + exactPlayerBlockIncrease) return false;
      const expectedPlayerStatus = JSON.parse(JSON.stringify(previous.playerStatus || {}));
      const expectedEnemyStatus = JSON.parse(JSON.stringify(previous.enemyStatus || {}));
      const addStatus = (target, statusId, amount, maxStacks = null) => {
        if (!statusId) return;
        const table = target === 'enemy' ? expectedEnemyStatus : expectedPlayerStatus;
        const currentValue = Number(table[statusId]) || 0;
        const requested = Math.max(0, Number(amount) || 0);
        const hasFiniteStackCap = maxStacks !== null
          && maxStacks !== undefined
          && Number.isFinite(Number(maxStacks));
        const applied = hasFiniteStackCap
          ? Math.max(0, Math.min(requested, Number(maxStacks) - currentValue))
          : requested;
        if (applied > 0) table[statusId] = currentValue + applied;
      };
      let consumedDamageStatuses = false;
      for (const effect of effects) {
        if (effect.type === 'status') addStatus(effect.target, effect.statusId, effect.value, effect.maxStacks);
        if (effect.type === 'damage' && !consumedDamageStatuses) {
          if (effect.consume_status && effect.conditional_status
            && Number(expectedPlayerStatus[effect.conditional_status]) >= Number(effect.conditional_value || 1)) {
            expectedPlayerStatus[effect.conditional_status] = typeof effect.consume_status === 'number'
              ? Math.max(0, Number(expectedPlayerStatus[effect.conditional_status]) - Number(effect.consume_status))
              : 0;
          } else if (!effect.conditional_status && Number(expectedPlayerStatus.sword_intent) > 0) {
            expectedPlayerStatus.sword_intent = 0;
          }
          if (card.type === 'attack' && Number(expectedEnemyStatus.opening) > 0) {
            expectedEnemyStatus.opening = Math.max(0, Number(expectedEnemyStatus.opening) - 1);
          }
          if (Number(expectedPlayerStatus.counter_force) > 0) expectedPlayerStatus.counter_force = 0;
          consumedDamageStatuses = true;
        }
      }
      for (const status of synergy.enemyStatuses || []) addStatus('enemy', status.id, status.value);
      for (const status of synergy.playerStatuses || []) addStatus('player', status.id, status.value);
      for (const passive of effectivePassives) {
        if (passive.effect === 'status' && passive.statusId) {
          addStatus('player', passive.statusId, passive.value);
        }
      }
      if (card.type === 'attack' && typeof treasureSystem !== 'undefined' && treasureSystem
        && typeof treasureSystem.getEquippedDefinitionIds === 'function') {
        for (const treasureId of treasureSystem.getEquippedDefinitionIds()) {
          const relic = treasureSystem.treasureDB?.[treasureId]?.relic?.play_attack;
          if (relic?.type === 'status') addStatus('player', relic.statusId, relic.value);
        }
      }
      const stripZero = statuses => Object.fromEntries(
        Object.entries(statuses || {}).filter(([, value]) => Number(value) !== 0)
      );
      if (!this._authorityValuesEqual(stripZero(current.playerStatus), stripZero(expectedPlayerStatus))
        || !this._authorityValuesEqual(stripZero(current.enemyStatus), stripZero(expectedEnemyStatus))) return false;
      if (Number(current.player.hp) !== expectedPlayerHp) return false;
      if (current.damageDealtThisTurn !== (previous.damageDealtThisTurn || maxDamage > 0)) return false;
      const graph = snapshot.enemy?.def?.planGraph || snapshot.originalCard?.enemy?.planGraph || null;
      return this._validateAuthorityPlanCard(
        previous.enemy.planRuntime,
        current.enemy.planRuntime,
        card,
        current.qi,
        graph,
        snapshot,
        previous.enemy,
        current.enemy
      );
  }

  _validateAuthorityTurnStart(previous, current, entry, snapshot, combatRules = {}) {
      const reactionId = entry.detail?.reactionId;
      const pending = previous.pendingReaction;
      const option = pending?.options?.find(candidate => candidate.id === reactionId);
      if (!pending || !option?.available) return false;
      const action = pending.action || {};
      const clone = value => JSON.parse(JSON.stringify(value || {}));
      const playerStatus = clone(previous.playerStatus);
      const enemyStatus = clone(previous.enemyStatus);
      const appliedByEnemy = new Set(previous.playerStatusesAppliedByEnemy || []);
      let minEnemyHpLoss = 0;
      let maxEnemyHpLoss = 0;
      const poison = Math.max(0, Number(enemyStatus.poison) || 0);
      if (poison > 0) {
        const poisonDamage = Math.min(3, poison);
        minEnemyHpLoss += poisonDamage;
        maxEnemyHpLoss += poisonDamage;
        enemyStatus.poison = Math.max(0, poison - 1);
      }
      const cancelAction = (reactionId === 'INTERRUPT' && ['buff', 'debuff'].includes(action.type))
        || (reactionId === 'TRANSMUTE' && action.type === 'debuff');
      let enemyBlockBeforePassives = Number(previous.enemy.block) || 0;
      if (!cancelAction && action.type === 'debuff' && action.statusId) {
        playerStatus[action.statusId] = (Number(playerStatus[action.statusId]) || 0) + Math.max(0, Number(action.value) || 0);
        appliedByEnemy.add(action.statusId);
      } else if (!cancelAction && action.type === 'buff' && action.statusId) {
        enemyStatus[action.statusId] = (Number(enemyStatus[action.statusId]) || 0) + Math.max(0, Number(action.value) || 0);
      } else if (!cancelAction && action.type === 'defend') {
        enemyBlockBeforePassives += this._enemyDefenseValue(action);
      } else if (!cancelAction && action.type === 'attack' && Number(enemyStatus.sword_intent) > 0) {
        enemyStatus.sword_intent = 0;
      }

      const expectedEquipmentState = clone(previous.equipmentState);
      const activePassives = [];
      this._authorityEquipmentPassives().forEach((passive, index) => {
        if (passive?.hook !== 'onTurnStart') return;
        if (Number(passive.triggerCount) > 0) {
          const key = `eq_${index}`;
          const next = (Number(expectedEquipmentState[key]) || 0) + 1;
          if (next >= Number(passive.triggerCount)) {
            expectedEquipmentState[key] = 0;
            activePassives.push(passive);
          } else expectedEquipmentState[key] = next;
        } else activePassives.push(passive);
      });
      const maxTurnHeal = activePassives.filter(passive => passive.effect === 'heal')
        .reduce((sum, passive) => sum + Math.max(0, Number(passive.value) || 0), 0);
      const maxTurnDamage = activePassives.filter(passive => passive.effect === 'dealDamage')
        .reduce((sum, passive) => sum + Math.max(0, Number(passive.value) || 0), 0);
      maxEnemyHpLoss += maxTurnDamage;
      if (!this._validateAuthorityTurnPiles(
        previous,
        current,
        reactionId,
        snapshot,
        activePassives,
        combatRules
      )) return false;

      if (Number(playerStatus.sword_intent) > 0) {
        playerStatus.sword_intent = Math.floor(Number(playerStatus.sword_intent) / 2);
      }
      for (const statusId of ['weak', 'vulnerable', 'poison', 'fortify', 'opening']) {
        const playerValue = Math.max(0, Number(playerStatus[statusId]) || 0);
        if (appliedByEnemy.has(statusId)) appliedByEnemy.delete(statusId);
        else if (playerValue > 0) playerStatus[statusId] = playerValue - 1;
        if (statusId !== 'poison') {
          const enemyValue = Math.max(0, Number(enemyStatus[statusId]) || 0);
          if (enemyValue > 0) enemyStatus[statusId] = enemyValue - 1;
        }
      }
      const stripZero = statuses => Object.fromEntries(
        Object.entries(statuses || {}).filter(([, value]) => Number(value) !== 0)
      );
      if (!this._authorityValuesEqual(stripZero(current.playerStatus), stripZero(playerStatus))
        || !this._authorityValuesEqual(stripZero(current.enemyStatus), stripZero(enemyStatus))
        || !this._authorityValuesEqual(current.playerStatusesAppliedByEnemy, Array.from(appliedByEnemy))
        || !this._authorityValuesEqual(current.equipmentState, expectedEquipmentState)) return false;

      const phaseAdvanced = Number(current.bossPhaseIndex) === Number(previous.bossPhaseIndex) + 1;
      const enemyHpLoss = Number(previous.enemy.hp) - Number(current.enemy.hp);
      const turnPlan = this._normalizePlanGraph(
        snapshot.originalCard?.enemy?.planGraph || snapshot.enemy?.def?.planGraph
      );
      const actionTransition = turnPlan?.transitions?.find(transition =>
        transition.when === 'action_resolved'
        && transition.from.includes(previous.enemy?.planRuntime?.currentState)
      );
      const retainedStates = turnPlan?.blockContract?.retainInStates;
      const releasesBlockOnPlanExit = turnPlan?.blockContract?.releaseOnExit === true
        && actionTransition
        && Array.isArray(retainedStates)
        && retainedStates.includes(previous.enemy?.planRuntime?.currentState)
        && !retainedStates.includes(actionTransition.to);
      const minimumExpectedEnemyBlock = releasesBlockOnPlanExit
        ? 0 : Math.max(0, enemyBlockBeforePassives - maxTurnDamage);
      const maximumExpectedEnemyBlock = releasesBlockOnPlanExit ? 0 : enemyBlockBeforePassives;
      if (!phaseAdvanced && (enemyHpLoss < minEnemyHpLoss || enemyHpLoss > maxEnemyHpLoss
        || Number(current.enemy.block) < minimumExpectedEnemyBlock
        || Number(current.enemy.block) > maximumExpectedEnemyBlock
        || current.enemy.name !== previous.enemy.name
        || Number(current.enemy.maxHp) !== Number(previous.enemy.maxHp)
        || Number(current.enemy.atkPower) !== Number(previous.enemy.atkPower)
        || Number(current.enemy.defPower) !== Number(previous.enemy.defPower)
        || Number(current.enemy.tier) !== Number(previous.enemy.tier))) return false;
      const auraPersists = Number(playerStatus?.aura) > 0;
      const maxTurnBlock = activePassives.filter(passive => passive.effect === 'block')
        .reduce((sum, passive) => sum + Math.max(0, Number(passive.value) || 0), 0);
      const reachablePlayerStates = [];
      let incomingDamage = 0;
      let incomingPiercing = false;
      if (!cancelAction && action.type === 'attack') {
        incomingDamage = Math.max(0, Number(action.expectedDamage) || 0);
        const bossCounter = combatRules.counter || {};
        if (bossCounter.flag && gameState?.hasFlag?.(bossCounter.flag)
          && Number(bossCounter.incomingDamageMultiplier) > 0
          && Number(bossCounter.incomingDamageMultiplier) < 1) {
          incomingDamage = Math.ceil(incomingDamage * Number(bossCounter.incomingDamageMultiplier));
        }
        const narrativeStance = combatRules?.narrativeStance || {};
        if (narrativeStance.id === 'advance'
          && snapshot.originalCard?.id === 'ch_qi_100'
          && Number(playerStatus.qi_main_advance_ready) > 0
          && incomingDamage > 0) {
          incomingDamage = Math.max(0, incomingDamage - Math.max(0,
            Number(narrativeStance.firstDamagingLightningReduction) || 0));
          playerStatus.qi_main_advance_ready = 0;
        }
        const karmaDamage = combatRules.karmaDamage;
        if (karmaDamage) {
          const badKarma = Number(gameState?.attributes?.[karmaDamage.attribute || 'karmaBad']) || 0;
          incomingDamage += Math.floor(badKarma / Math.max(1, Number(karmaDamage.perPoints) || 1))
            * Math.max(0, Number(karmaDamage.damagePerStep) || 0);
        }
        if (Number(previous.enemyStatus?.weak) > 0) incomingDamage = Math.max(0, incomingDamage - 1);
        if (Number(previous.playerStatus?.fortify) > 0) incomingDamage = Math.max(0, incomingDamage - 1);
        incomingDamage += Math.max(0, Number(previous.enemyStatus?.sword_intent) || 0);
        incomingDamage = Math.max(0, Math.ceil(incomingDamage
          * ({ GUARD: 0.5, DEFLECT: 0.8, INTERRUPT: 1, ABSORB: 0.75, TRANSMUTE: 1, EVADE: 0 }[reactionId] ?? 1)));
        if (Number(previous.enemyStatus?.weak) > 0) incomingDamage = Math.floor(incomingDamage * 0.75);
        if (Number(previous.playerStatus?.vulnerable) > 0) incomingDamage = Math.ceil(incomingDamage * 1.5);
        incomingPiercing = action.piercing === true;
        const piercingCounter = combatRules.counters?.nascentPill;
        if (incomingPiercing && piercingCounter?.cancelPiercing === true
          && piercingCounter.flag && gameState?.hasFlag?.(piercingCounter.flag)) incomingPiercing = false;
        if (!incomingPiercing) incomingDamage = Math.max(0, incomingDamage - Math.max(0, Number(previous.player.defMod) || 0));
      }

      const initialBlock = Number(previous.player.block) || 0;
      let blockAfterDamage = initialBlock;
      let damageAfterBlock = incomingDamage;
      if (!incomingPiercing) {
        const absorbed = Math.min(blockAfterDamage, damageAfterBlock);
        blockAfterDamage -= absorbed;
        damageAfterBlock -= absorbed;
      }
      const realmOrder = ['mortal', 'qi', 'foundation', 'golden', 'nascent', 'deity', 'tribulation', 'ascension'];
      const playerTier = Math.max(1, realmOrder.indexOf(snapshot.player?.realm));
      const enemyTier = Math.max(1, realmOrder.indexOf(
        snapshot.enemy?.realm || snapshot.originalCard?.realm || snapshot.player?.realm
      ));
      const suppressed = damageAfterBlock > 0 && playerTier >= enemyTier + 2;
      const resistVariants = damageAfterBlock > 0 && Number(snapshot.player?.daoHeart) >= 4
        ? [damageAfterBlock, Math.max(0, damageAfterBlock - 1)]
        : [damageAfterBlock];
      for (let finalDamage of new Set(resistVariants)) {
        if (suppressed) finalDamage = 0;
        const auraAbsorbed = incomingPiercing ? 0 : Math.min(Number(previous.player.aura) || 0, finalDamage);
        const hpLoss = Math.max(0, finalDamage - auraAbsorbed);
        const healedHp = Math.min(
          Number(previous.player.maxHp),
          Math.max(0, Number(previous.player.hp) - hpLoss) + maxTurnHeal
        );
        const nextAura = Math.max(0, Number(previous.player.aura) - auraAbsorbed);
        const nextBlock = auraPersists
          ? Math.min(
            this._retainedBlockCap(previous.player),
            blockAfterDamage + maxTurnBlock
          )
          : 0;
        reachablePlayerStates.push({ hp: healedHp, aura: nextAura, block: nextBlock });
      }
      if (!reachablePlayerStates.some(state =>
        Number(current.player.hp) === state.hp
        && Number(current.player.aura) === state.aura
        && Number(current.player.block) === state.block
      )) return false;
      if (Number(current.player.maxHp) !== Number(previous.player.maxHp)
        || Number(current.player.atkMod) !== Number(previous.player.atkMod)
        || Number(current.player.defMod) !== Number(previous.player.defMod)
        || Number(current.player.critRate) !== Number(previous.player.critRate)
      ) return false;

      const graph = this._normalizePlanGraph(snapshot.originalCard?.enemy?.planGraph || snapshot.enemy?.def?.planGraph);
      if (previous.enemy.planRuntime || current.enemy.planRuntime) {
        if (!graph || !previous.enemy.planRuntime || !current.enemy.planRuntime) return false;
        const expected = clone(previous.enemy.planRuntime);
        const applyTransition = cause => {
          const transition = graph.transitions.find(candidate =>
            candidate.when === cause && candidate.from.includes(expected.currentState)
          );
          if (!transition || transition.to === expected.currentState) return false;
          const from = expected.currentState;
          expected.currentState = transition.to;
          expected.transitionSequence += 1;
          expected.lastTransition = {
            planId: expected.planId,
            from,
            to: transition.to,
            cause,
            turn: previous.turn,
            sourceCardId: snapshot.originalCard?.id || null,
            sequence: expected.transitionSequence
          };
          return true;
        };
        expected.lastReaction = reactionId;
        if (reactionId === 'DEFLECT') applyTransition('deflected');
        if (reactionId === 'TRANSMUTE') applyTransition('transmuted');
        if (expected.currentState === previous.enemy.planRuntime.intentState) applyTransition('action_resolved');
        expected.migration = null;
        expected.intentState = expected.currentState;
        expected.turnMemory = {
          turn: current.turn,
          cardsPlayed: 0,
          qiSpent: 0,
          qiGained: 0,
          qiRemaining: current.qi,
          cardTypes: [],
          playedCards: [],
          consecutiveType: null,
          consecutiveCount: 0,
          consumedSignals: []
        };
        if (!this._authorityValuesEqual(current.enemy.planRuntime, expected)) return false;
      }
      return true;
  }

  _validateAuthorityLedgerSemantics(snapshot, combatRules = {}, cardDB = {}, options = {}) {
      const ledger = snapshot.authorityLedger;
      const first = ledger?.[0];
      if (!first) return false;
      if (first.kind === 'LEGACY_MIGRATED') {
          if (first.detail?.sourceVersion !== 1) return false;
          if (!this._legacyDynamicSnapshotIsSafe({
            ...snapshot,
            ...first.state,
            player: { ...snapshot.player, ...first.state.player },
            enemy: { ...snapshot.enemy, ...first.state.enemy }
          })) return false;
      } else {
        if (first.kind !== 'TURN_START' || first.turn !== 1) return false;
        const opening = this._buildOpeningDynamicAuthority(combatRules);
        const firstState = first.state;
        const openingEnemyData = Array.isArray(snapshot.originalCard?.enemy?.phases)
          && snapshot.originalCard.enemy.phases.length > 0
          ? snapshot.originalCard.enemy.phases[0]
          : snapshot.originalCard?.enemy;
        const openingEnemyBlock = Math.max(0, Number(openingEnemyData?.block) || 0);
        const normalizeStatuses = statuses => Object.fromEntries(
          Object.entries(statuses || {}).filter(([, value]) => Number(value) !== 0)
        );
        if (firstState.phase !== 'PLAYER_TURN'
          || firstState.pendingReaction !== null
          || firstState.settledReactionWindows.length !== 0
          || Number(firstState.nextTurnDrawPenalty) !== 0
          || firstState.damageDealtThisTurn !== false
          || Number(firstState.player?.block) !== opening.playerBlock
          || Number(firstState.enemy?.block) !== openingEnemyBlock
          || Number(firstState.qi) !== opening.qi
          || this._stableAuthoritySerialize(normalizeStatuses(firstState.playerStatus))
            !== this._stableAuthoritySerialize(normalizeStatuses(opening.playerStatus))
          || this._stableAuthoritySerialize(normalizeStatuses(firstState.enemyStatus)) !== '{}'
          || this._stableAuthoritySerialize(firstState.equipmentState || {})
            !== this._stableAuthoritySerialize(opening.equipmentState)) return false;
      }
      if (!this._validateAuthorityPartition(first.state)) return false;
      if (options.requirePath === true) {
        const openingPath = typeof pathArchetypeSystem !== 'undefined' && pathArchetypeSystem
          && typeof pathArchetypeSystem.buildOpeningCombatState === 'function'
          ? pathArchetypeSystem.buildOpeningCombatState()
          : null;
        if (!this._authorityValuesEqual(first.state.pathCombatState, openingPath)) return false;
      }
      let openWindow = first.state.phase === 'REACTION_OPEN'
        ? first.state.pendingReaction?.windowId || null
        : null;
      let awaitingResolved = null;
      for (let index = 1; index < ledger.length; index++) {
          const previous = ledger[index - 1].state;
          const entry = ledger[index];
          const current = entry.state;
          if (!this._validateAuthorityPartition(current)) return false;
          if (entry.kind === 'CARD_PLAY') {
              if (openWindow || awaitingResolved
                || !this._validateAuthorityCardPlay(
                  previous,
                  current,
                  entry,
                  snapshot,
                  cardDB,
                  combatRules,
                  options.enemyDB || this.enemyDB
                )) return false;
          } else if (entry.kind === 'REACTION_OPEN') {
              const pending = current.pendingReaction;
              const expectedPath = this._pathTurnBoundary(previous.pathCombatState, false);
              const reactionGraph = this._normalizePlanGraph(
                snapshot.enemy?.def?.planGraph || snapshot.originalCard?.enemy?.planGraph
              );
              const reactionStateId = current.enemy?.planRuntime?.intentState;
              const expectedPlanIntent = reactionGraph && reactionStateId
                ? reactionGraph.states?.[reactionStateId]?.intent
                : null;
              const expectedPlanAction = expectedPlanIntent
                ? this._previewEnemyAction(expectedPlanIntent, current.enemy)
                : null;
              const retainedStates = reactionGraph?.blockContract?.retainInStates;
              const retainsEnemyBlock = Array.isArray(retainedStates)
                && retainedStates.includes(current.enemy?.planRuntime?.currentState);
              const expectedEnemyBlock = retainsEnemyBlock ? Number(previous.enemy?.block) : 0;
              if (openWindow || awaitingResolved || previous.phase !== 'PLAYER_TURN'
                || current.phase !== 'REACTION_OPEN' || current.turn !== previous.turn
                || !pending || pending.windowId !== entry.detail.windowId
                || Number(current.qi) !== Number(previous.qi)
                || current.hand.length !== 0
                || !this._authorityValuesEqual(current.drawPile, previous.drawPile)
                || !this._authorityValuesEqual(current.exhaustPile, previous.exhaustPile)
                || !this._authorityValuesEqual(current.discardPile, [
                  ...previous.discardPile,
                  ...[...previous.hand].reverse()
                ])
                 || !this._authorityValuesEqual(current.pathCombatState, expectedPath)
                 || !this._authorityValuesEqual(current.player, previous.player)
                 || Number(current.enemy?.block) !== expectedEnemyBlock
                 || current.enemy?.name !== previous.enemy?.name
                 || Number(current.enemy?.hp) !== Number(previous.enemy?.hp)
                 || Number(current.enemy?.maxHp) !== Number(previous.enemy?.maxHp)
                 || Number(current.enemy?.tier) !== Number(previous.enemy?.tier)
                 || Number(current.enemy?.atkPower) !== Number(previous.enemy?.atkPower)
                 || Number(current.enemy?.defPower) !== Number(previous.enemy?.defPower)
                 || !this._authorityValuesEqual(current.enemyStatus, previous.enemyStatus)
                || !this._authorityValuesEqual(current.playerStatus, previous.playerStatus)
                || !this._authorityValuesEqual(current.settledReactionWindows, previous.settledReactionWindows)) return false;
              if (expectedPlanAction
                && !this._validateAuthorityReactionWindow(pending, expectedPlanAction, current, snapshot)) return false;
              openWindow = pending.windowId;
          } else if (entry.kind === 'TURN_START') {
              const reactionId = entry.detail?.reactionId;
              const windowId = entry.detail?.reactionWindowId;
              const option = previous.pendingReaction?.options?.find(candidate => candidate.id === reactionId);
              const expectedSettled = [...previous.settledReactionWindows, openWindow];
              const expectedPath = this._pathTurnBoundary(previous.pathCombatState, true);
              if (!openWindow || awaitingResolved || windowId !== openWindow || !option?.available
                || previous.phase !== 'REACTION_OPEN' || current.phase !== 'PLAYER_TURN'
                || current.turn !== previous.turn + 1 || current.pendingReaction !== null
                || Number(current.qi) !== Number(snapshot.maxQi)
                || current.damageDealtThisTurn !== false
                || Number(current.nextTurnDrawPenalty) !== 0
                || !this._authorityValuesEqual(current.settledReactionWindows, expectedSettled)
                || !this._authorityValuesEqual(current.pathCombatState, expectedPath)
                || !this._validateAuthorityTurnStart(previous, current, entry, snapshot, combatRules)) return false;
              const memory = current.enemy.planRuntime?.turnMemory;
              if (memory && (memory.turn !== current.turn || memory.cardsPlayed !== 0
                || memory.qiSpent !== 0 || memory.qiGained !== 0
                || memory.qiRemaining !== current.qi
                || memory.cardTypes.length !== 0 || memory.playedCards.length !== 0)) return false;
              awaitingResolved = {
                windowId: openWindow,
                reactionId,
                action: JSON.parse(JSON.stringify(previous.pendingReaction?.action || null))
              };
              openWindow = null;
          } else if (entry.kind === 'REACTION_RESOLVED') {
              const reactionEffects = {
                  DEFLECT: Number(awaitingResolved?.action?.expectedDamage) >= 3
                    ? ['enemy', 'vulnerable', 1]
                    : null,
                  INTERRUPT: ['enemy', 'weak', 1],
                  ABSORB: ['player', 'counter_force', 1],
                  TRANSMUTE: ['enemy', 'poison', 1]
              };
              if (!awaitingResolved
                || entry.detail?.windowId !== awaitingResolved.windowId
                || entry.detail?.reactionId !== awaitingResolved.reactionId
                || current.phase !== 'PLAYER_TURN' || current.turn !== previous.turn
                || current.pendingReaction !== null
                || !this._authorityValuesEqual(current.settledReactionWindows, previous.settledReactionWindows)
                || !this._authorityValuesEqual(current.player, previous.player)
                || !this._authorityValuesEqual(current.enemy, previous.enemy)
                || !this._authorityValuesEqual(current.masterDeck, previous.masterDeck)
                || !this._authorityValuesEqual(current.drawPile, previous.drawPile)
                || !this._authorityValuesEqual(current.hand, previous.hand)
                || !this._authorityValuesEqual(current.discardPile, previous.discardPile)
                || !this._authorityValuesEqual(current.exhaustPile, previous.exhaustPile)
                || !this._authorityValuesEqual(current.pathCombatState, previous.pathCombatState)
                || Number(current.qi) !== Number(previous.qi)) return false;
              const expectedPlayer = JSON.parse(JSON.stringify(previous.playerStatus || {}));
              const expectedEnemy = JSON.parse(JSON.stringify(previous.enemyStatus || {}));
              const authored = reactionEffects[entry.detail.reactionId];
              if (authored) {
                const table = authored[0] === 'enemy' ? expectedEnemy : expectedPlayer;
                table[authored[1]] = (Number(table[authored[1]]) || 0) + authored[2];
              }
              if (!this._authorityValuesEqual(current.playerStatus, expectedPlayer)
                || !this._authorityValuesEqual(current.enemyStatus, expectedEnemy)) return false;
              awaitingResolved = null;
          } else {
              return false;
          }
      }
      if (awaitingResolved) return false;
      return openWindow
        ? snapshot.phase === 'REACTION_OPEN' && snapshot.pendingReaction?.windowId === openWindow
        : snapshot.phase === 'PLAYER_TURN';
  }

  _stableAuthoritySerialize(value) {
      if (value === null || typeof value !== 'object') return JSON.stringify(value);
      if (Array.isArray(value)) {
          return `[${value.map(item => this._stableAuthoritySerialize(item)).join(',')}]`;
      }
      return `{${Object.keys(value).sort().map(key =>
        `${JSON.stringify(key)}:${this._stableAuthoritySerialize(value[key])}`
      ).join(',')}}`;
  }

  _computeCombatAuthoritySeal(snapshot) {
      const payload = { ...snapshot };
      delete payload.authoritySeal;
      const text = `xiuxian-deck-combat-v2|${this._stableAuthoritySerialize(payload)}`;
      let primary = 0x811c9dc5;
      let secondary = 0x9e3779b9;
      for (let index = 0; index < text.length; index++) {
          const code = text.charCodeAt(index);
          primary = Math.imul(primary ^ code, 0x01000193) >>> 0;
          secondary = Math.imul(secondary ^ (code + index), 0x85ebca6b) >>> 0;
      }
      return `dc2-${primary.toString(16).padStart(8, '0')}${secondary.toString(16).padStart(8, '0')}`;
  }

  exportState() {
      if (!this.active) return null;
      const clone = value => JSON.parse(JSON.stringify(value));
      const enemy = this.enemy ? clone(this.enemy) : null;
      if (enemy) {
          enemy.usedConditions = this.enemy?.usedConditions instanceof Set
            ? Array.from(this.enemy.usedConditions)
            : (Array.isArray(enemy.usedConditions) ? enemy.usedConditions : []);
      }
      const snapshot = {
          version: 3,
          active: true,
          phase: this.phase,
          turn: Math.max(1, Math.floor(Number(this.turn) || 1)),
          preCombatHealth: Number(this.preCombatHealth) || 0,
          originalCard: this.originalCard ? clone(this.originalCard) : null,
          encounterContext: this.encounterContext ? clone(this.encounterContext) : null,
          resolutionContext: this.resolutionContext ? clone(this.resolutionContext) : null,
          player: this.player ? clone(this.player) : null,
          enemy,
          qi: Math.max(0, Number(this.qi) || 0),
          maxQi: Math.max(0, Number(this.maxQi) || 0),
          masterDeck: clone(this.masterDeck || []),
          drawPile: clone(this.drawPile || []),
          hand: clone(this.hand || []),
          discardPile: clone(this.discardPile || []),
          exhaustPile: clone(this.exhaustPile || []),
          playerStatus: clone(this.playerStatus || {}),
          enemyStatus: clone(this.enemyStatus || {}),
          playerStatusesAppliedByEnemy: Array.from(this._playerStatusesAppliedByEnemy || []),
          enemyIntent: this.enemyIntent ? clone(this.enemyIntent) : null,
          bossPhases: clone(this.bossPhases || []),
          bossPhaseIndex: Math.max(0, Math.floor(Number(this.bossPhaseIndex) || 0)),
          pendingReaction: this._cloneReaction(this.pendingReaction),
          reactionSequence: Math.max(0, Math.floor(Number(this._reactionSequence) || 0)),
          settledReactionWindows: Array.from(this._settledReactionWindows || []).slice(-40),
          nextTurnDrawPenalty: Math.max(0, Math.floor(Number(this._nextTurnDrawPenalty) || 0)),
          equipmentState: clone(this.equipmentState || {}),
          damageDealtThisTurn: Boolean(this.damageDealtThisTurn),
          pathCombatState: typeof pathArchetypeSystem !== 'undefined'
            && pathArchetypeSystem
            && typeof pathArchetypeSystem.exportCombatState === 'function'
            ? clone(pathArchetypeSystem.exportCombatState())
            : null,
          authorityLedger: clone(this._authorityLedger || []),
          authorityChain: this._authorityChain || 'dc2-root',
          log: clone(this.log || []),
          pathPresentationData: clone(this._pathPresentationData || { paths: {} }),
          companionCombatContracts: clone(this._companionCombatContracts || [])
      };
      snapshot.authoritySeal = this._computeCombatAuthoritySeal(snapshot);
      return snapshot;
  }

  _findAuthoredCombatCard(cardId, realmHint = null) {
      if (!cardId || typeof dataLoader === 'undefined' || !dataLoader
        || typeof dataLoader.loadSync !== 'function') return null;
      const milestoneData = dataLoader.loadSync('cards:chapter_milestones');
      const milestoneCard = milestoneData && !Array.isArray(milestoneData)
        ? milestoneData[cardId]
        : null;
      if (milestoneCard?.id === cardId && milestoneCard?.enemy) return milestoneCard;
      const configuredRealms = typeof gameState !== 'undefined' && gameState?.config?.realms?.order;
      const realms = [
          realmHint,
          ...(Array.isArray(configuredRealms) ? configuredRealms : []),
          'qi', 'foundation', 'golden', 'nascent', 'deity', 'tribulation'
      ].filter((realm, index, all) => typeof realm === 'string' && realm && all.indexOf(realm) === index);
      for (const realm of realms) {
          const moduleData = dataLoader.loadSync(`cards:${realm}`);
          const ordinary = Array.isArray(moduleData?.cards)
            ? moduleData.cards.find(card => card?.id === cardId)
            : null;
          if (ordinary) return ordinary;
          const dungeonCard = moduleData?.dungeonCards?.[cardId];
          if (dungeonCard) return dungeonCard;
      }
      return null;
  }

  _resolveAuthoredRuntimeCard(cardId, realmHint = null, thresholdHint = null) {
      if (!cardId) return null;
      // A realm gate can carry a deterministic, same-life chapter projection
      // (for example the qi question's selected stance).  Rebuild that before
      // consulting CardSystem's raw data cache, otherwise a valid saved combat
      // loses the authored dynamic rule during hydrate.
      const chapterRegistry = typeof chapterSystem !== 'undefined' && chapterSystem
        ? chapterSystem
        : (typeof globalThis !== 'undefined' ? globalThis.chapterSystem : null);
      const registries = [];
      if (typeof cardSystem !== 'undefined' && cardSystem) registries.push(cardSystem);
      if (typeof globalThis !== 'undefined' && globalThis.cardSystem
        && !registries.includes(globalThis.cardSystem)) registries.push(globalThis.cardSystem);
      for (const registry of registries) {
          if (typeof registry.resolveCombatSourceCard !== 'function') continue;
          const card = registry.resolveCombatSourceCard(cardId, {
            chapterSystem: chapterRegistry, realmHint, thresholdHint, pathId: gameState?.path
          });
          if (card?.id === cardId) return card;
          // The graph producer rejected its own source. Never downgrade that
          // rejection to the raw module fallback below (including old saves
          // with no serialized node selectors).
          if (registry.isGraphDungeonCombatSource?.(cardId, realmHint || gameState?.realm)) return null;
      }
      // Chapter identity (including a 45 -> 40 alias) belongs to the formal
      // producer above. Never replace a rejected hint with a raw cached gate.
      if (/^ch_[a-z]+_\d+$/.test(cardId)) return null;

      // Faction cards are deliberate runtime projections of authored world
      // data, not CardSystem catalog records. A cold resume must reconstruct
      // the original invitation before validating its canonical encounter
      // handoff; accepting the serialized source here would create a second
      // combat authority instead.
      const factionRegistries = [];
      if (typeof factionSystem !== 'undefined' && factionSystem) factionRegistries.push(factionSystem);
      if (typeof globalThis !== 'undefined' && globalThis.factionSystem
        && !factionRegistries.includes(globalThis.factionSystem)) factionRegistries.push(globalThis.factionSystem);
      for (const registry of factionRegistries) {
          if (typeof registry.getAuthoritativeEventCard !== 'function') continue;
          const card = registry.getAuthoritativeEventCard(cardId);
          if (card?.id === cardId) return card;
      }

      const threadRegistries = [];
      if (typeof threadEngine !== 'undefined' && threadEngine) threadRegistries.push(threadEngine);
      if (typeof globalThis !== 'undefined' && globalThis.threadEngine
        && !threadRegistries.includes(globalThis.threadEngine)) threadRegistries.push(globalThis.threadEngine);
      for (const registry of threadRegistries) {
          if (typeof registry.getAuthoritativePendingCard !== 'function') continue;
          const card = registry.getAuthoritativePendingCard(cardId, gameState);
          if (card?.id === cardId) {
              // Normal thread presentation hydrates migrated combat media in
              // GameLogic. Restore must rebuild that same authored projection
              // before comparing the saved source/choice/combat authority.
              return typeof cardSystem !== 'undefined'
                && typeof cardSystem?.hydrateCombatCardPresentation === 'function'
                  ? cardSystem.hydrateCombatCardPresentation(card)
                  : card;
          }
      }

      return this._findAuthoredCombatCard(cardId, realmHint);
  }

  _combatCardFromAuthoredChoice(sourceCard, direction = null, enemyHint = null) {
      if (!sourceCard?.id) return null;
      const directions = direction
        ? [direction]
        : ['left', 'right', 'up', 'down'];
      let selectedDirection = null;
      let choice = null;
      let combatEnemy = null;
      for (const candidate of directions) {
          const authoredChoice = sourceCard.choices?.[candidate];
          if (!authoredChoice) continue;
          const contract = typeof cardSystem !== 'undefined'
            ? cardSystem?.resolveChoiceCombatContract?.(sourceCard, candidate, authoredChoice, gameState?.path)
            : null;
          const resolvedChoice = contract?.valid ? contract.combatChoice : null;
          // CombatCoordinator accepts a choice-owned enemy when present, or
          // the authored card's encounter enemy for ordinary cards such as
          // q_fellow. Restore must reproduce that exact public handoff: a
          // valid choice combat cannot become an unresumable direct combat
          // merely because its stable enemy lives on the card rather than the
          // choice payload.
          const resolvedEnemy = resolvedChoice?.enemy || sourceCard.enemy || null;
          if (!(resolvedChoice?.triggerCombat || resolvedChoice?.effects?.triggerCombat) || !resolvedEnemy) continue;
          // Keep the resolution receipt byte-for-byte equal to the selected
          // authored choice. Only the combat card receives a derived enemy;
          // otherwise a normal choice that inherits its card-level enemy would
          // reject its own persisted resolution context after refresh.
          if (enemyHint && JSON.stringify(resolvedEnemy) !== JSON.stringify(enemyHint)) continue;
          selectedDirection = candidate;
          choice = resolvedChoice;
          combatEnemy = resolvedEnemy;
          break;
      }
      if (!choice) {
          if (!sourceCard.enemy) return null;
          return {
              direction: null,
              choice: null,
              combatCard: JSON.parse(JSON.stringify(sourceCard))
          };
      }
      const clone = value => JSON.parse(JSON.stringify(value));
      return {
          direction: selectedDirection,
           choice: clone(choice),
           combatCard: {
               ...clone(sourceCard),
               // Keep the same top-level identity projection created by
               // CombatCoordinator.buildChoiceCombatWarning(). The source
               // retains its faction/story identity, while this pair records
               // which canonical encounter it entered for restore and
               // exactly-once ownership.
               encounterId: choice.encounterId || sourceCard.encounterId || null,
               encounterKind: choice.encounterKind || sourceCard.encounterKind || null,
                enemy: clone(combatEnemy),
               battlefield: choice.battlefield || combatEnemy?.battlefield || sourceCard.battlefield,
              combatPresentation: {
                  ...clone(sourceCard.combatPresentation || {}),
                  ...clone(choice.combatPresentation || {})
              },
              combatRules: {
                  ...clone(sourceCard.combatRules || {}),
                  ...clone(choice.combatRules || {})
              },
              defeatHealthLoss: choice.defeatHealthLoss ?? sourceCard.defeatHealthLoss,
              defeatHealthFloor: choice.defeatHealthFloor ?? sourceCard.defeatHealthFloor
          }
      };
  }

  _combatSettlementProjection(card) {
      if (!card || typeof card !== 'object') return null;
      const fields = [
          'id', 'encounterId', 'encounterKind', 'encounterRole', 'teachingEncounter',
          'narrativeSource', 'originThreadId', 'originNodeId', 'type', 'realm', 'path',
          'threshold', 'category', 'tags', 'sceneImage', 'battlefield', 'combatPresentation',
          'combatRewards', 'combatOutcomeLinks', 'victoryEffects', 'defeatEffects',
          'fleeEffects', 'defeatHealthLoss', 'defeatHealthFloor', 'karmaSeed', 'karmaSeedOn', 'isFinale',
          'terminalGateId'
      ];
      const projection = {};
      for (const field of fields) {
          projection[field] = Object.prototype.hasOwnProperty.call(card, field)
            ? (card[field] === undefined ? null : card[field])
            : null;
      }
      return projection;
  }

  _canonicalResolutionAuthority(savedContext, realmHint = null) {
      if (savedContext === null || savedContext === undefined) {
          return { valid: true, value: null, combatCard: null };
      }
      if (!savedContext || typeof savedContext !== 'object'
        || typeof savedContext.sourceCard?.id !== 'string'
        || !['left', 'right', 'up', 'down'].includes(savedContext.direction)) {
          return { valid: false, value: null, combatCard: null };
      }
      const sourceCard = this._resolveAuthoredRuntimeCard(
        savedContext.sourceCard.id,
        savedContext.sourceCard.realm || realmHint,
        savedContext.sourceCard.threshold
      );
      const authored = this._combatCardFromAuthoredChoice(sourceCard, savedContext.direction);
      if (!authored?.choice || authored.direction !== savedContext.direction) {
          return { valid: false, value: null, combatCard: null };
      }
      if (this._stableAuthoritySerialize(savedContext.choice)
          !== this._stableAuthoritySerialize(authored.choice)
        || this._stableAuthoritySerialize(this._combatSettlementProjection(savedContext.sourceCard))
          !== this._stableAuthoritySerialize(this._combatSettlementProjection(sourceCard))
        || this._stableAuthoritySerialize(this._combatSettlementProjection(savedContext.combatCard))
          !== this._stableAuthoritySerialize(this._combatSettlementProjection(authored.combatCard))) {
          return { valid: false, value: null, combatCard: null };
      }
      const clone = value => JSON.parse(JSON.stringify(value));
      return {
          valid: true,
          value: {
              sourceCard: clone(sourceCard),
              direction: authored.direction,
              choice: clone(authored.choice),
              combatCard: clone(authored.combatCard)
          },
          combatCard: clone(authored.combatCard)
      };
  }

  _canonicalEncounterAuthority(savedContext, combatCard) {
      if (savedContext === null || savedContext === undefined) return { valid: true, value: null };
      if (!savedContext || typeof savedContext !== 'object' || !combatCard?.id) {
          return { valid: false, value: null };
      }
      const lifeCount = Number(gameState?.getLifeCount?.() || gameState?.unlocks?.lifeCount || 0);
      const stateTurn = Math.max(0, Number(gameState?.turn) || 0);
      const rawKind = combatCard.encounterKind || combatCard.enemy?.encounterKind || 'ordinary';
      const encounterKind = ['ordinary', 'elite', 'boss', 'realm_boss'].includes(rawKind)
        ? rawKind
        : 'ordinary';
      const realm = combatCard.realm || gameState?.realm || 'qi';
      const path = gameState?.path || null;
      const expectedInstanceId = `enc:${lifeCount}:${stateTurn}:${combatCard.id}:1`;
      if (savedContext.encounterInstanceId !== expectedInstanceId
        || savedContext.encounterKind !== encounterKind
        || savedContext.cardId !== combatCard.id
        || savedContext.realm !== realm
        || savedContext.path !== path) {
          return { valid: false, value: null };
      }
      return {
          valid: true,
          value: {
              encounterInstanceId: expectedInstanceId,
              encounterKind,
              cardId: combatCard.id,
              realm,
              path
          }
      };
  }

  _buildMasterDeckAuthority(cardDB = this.cardDB || {}, combatCard = this.originalCard) {
      const masterDeck = Array.isArray(gameState?.deck) ? [...gameState.deck] : [];
      const injected = new Set(masterDeck);
      const push = cardId => {
          if (!cardId || !cardDB[cardId] || injected.has(cardId)) return;
          masterDeck.push(cardId);
          injected.add(cardId);
      };
      const equipmentFallback = {
          weapon: 'eq_weapon_strike',
          armor: 'eq_armor_shield',
          accessory: 'eq_weapon_strike'
      };
      for (const [slot, itemId] of Object.entries(gameState?.equipment || {})) {
          if (!itemId) continue;
          const treasure = typeof treasureSystem !== 'undefined' && treasureSystem
            && typeof treasureSystem.getTreasureData === 'function'
            ? treasureSystem.getTreasureData(itemId)
            : null;
          push(treasure?.combatPresentation?.tacticalCardId || equipmentFallback[slot] || null);
      }
      const treasureCards = {
          soul_banner: 'treasure_soul_banner',
          thunder_bead: 'treasure_thunder_bead',
          nine_cauldron: 'treasure_nine_cauldron'
      };
      const equippedTreasureIds = typeof treasureSystem !== 'undefined' && treasureSystem
        && typeof treasureSystem.getEquippedDefinitionIds === 'function'
        ? treasureSystem.getEquippedDefinitionIds()
        : [];
      for (const treasureId of equippedTreasureIds) push(treasureCards[treasureId]);
      const companionContracts = typeof companionSystem !== 'undefined' && companionSystem
        && typeof companionSystem.getUnlockedCombatContracts === 'function'
        ? companionSystem.getUnlockedCombatContracts().filter(contract => contract?.cardId && cardDB[contract.cardId])
        : [];
      for (const contract of companionContracts) push(contract.cardId);
      const storyAssist = this._storyAssistContract(combatCard, cardDB);
      if (storyAssist) {
          push(storyAssist.cardId);
          companionContracts.push(storyAssist);
      }
      return {
          masterDeck,
          companionContracts: companionContracts.map(contract => ({ ...contract }))
      };
  }

  _canonicalEnemyAuthority(phaseData, rootData, combatRules, phaseIndex = 0, combatCard = this.originalCard) {
      const tier = phaseData.tier || rootData.tier || 1;
      let maxHp = Number(phaseData.hp || (tier === 2 ? 8 : tier === 3 ? 15 : 3));
      let atkPower = Number(phaseData.atk || rootData.atk || tier);
      const defPower = Number(phaseData.def || rootData.def || 0);
      if (phaseIndex === 0 && combatRules?.strengthModel === 'fixed_with_counters'
        && Number.isFinite(Number(combatRules.baseHp))) {
          const daoHeart = Number(gameState?.attributes?.daoHeart) || 0;
          const minimumHp = Math.max(1, Number(combatRules.minimumHp) || 1);
          const reductionPerPoint = Math.max(0, Number(combatRules.daoHeartHpReductionPerPoint) || 0);
          maxHp = Math.max(minimumHp, Number(combatRules.baseHp) - daoHeart * reductionPerPoint);
      }
      if (phaseIndex === 0) {
          const configuredCounters = [];
          if (combatRules?.counter) configuredCounters.push(combatRules.counter);
          if (combatRules?.counters && typeof combatRules.counters === 'object') {
              configuredCounters.push(...Object.values(combatRules.counters));
          }
          if (combatRules?.attackBacklash?.counter) configuredCounters.push(combatRules.attackBacklash.counter);
          for (const counter of configuredCounters) {
              if (!counter?.flag || !gameState?.hasFlag?.(counter.flag)) continue;
              maxHp = Math.max(2, maxHp - Math.max(0, Number(counter.enemyHpReduction) || 0));
              atkPower = Math.max(1, atkPower - Math.max(0, Number(counter.enemyAttackReduction) || 0));
          }
      }
      return {
          name: phaseData.name || rootData.name,
          tier,
          maxHp,
          atkPower,
          defPower,
          factionId: phaseData.factionId || rootData.factionId || null,
          // Match _createEnemy(): encounter data may omit an enemy realm while
          // the produced combat card deliberately owns one. On a cold resume
          // `this.originalCard` is not installed until validation succeeds, so
          // hydrate passes the canonical authored card explicitly instead of
          // incorrectly substituting the player's current realm.
          realm: phaseData.realm || rootData.realm || combatCard?.realm || gameState?.realm || null
      };
  }

  _validateStatusSnapshot(statuses) {
      if (!statuses || typeof statuses !== 'object' || Array.isArray(statuses)) return false;
      const entries = Object.entries(statuses);
      if (entries.length > 32) return false;
      return entries.every(([statusId, value]) =>
        /^[a-z][a-z0-9_]{0,47}$/.test(statusId)
        && Number.isInteger(Number(value))
        && Number(value) >= 0
        && Number(value) <= 100
      );
  }

  _validateEquipmentStateSnapshot(equipmentState) {
      if (!equipmentState || typeof equipmentState !== 'object' || Array.isArray(equipmentState)) return false;
      const passives = typeof equipmentSystem !== 'undefined' && equipmentSystem
        && typeof equipmentSystem.getActivePassives === 'function'
        ? equipmentSystem.getActivePassives()
        : [];
      const expected = new Map();
      passives.forEach((passive, index) => {
        const triggerCount = Math.max(0, Math.floor(Number(passive?.triggerCount) || 0));
        const key = this._equipmentPassiveStateKey(passive, index);
        if (passive?.oncePerCombat === true) expected.set(key, 2);
        else if (triggerCount > 0) expected.set(key, triggerCount);
        const threshold = Math.max(0, Math.floor(Number(passive?.distinctTagsThreshold) || 0));
        if (threshold > 0) expected.set(this._equipmentDistinctTagStateKey(passive, index), {
          kind: 'tags', threshold
        });
      });
      const entries = Object.entries(equipmentState);
      if (entries.length !== expected.size) return false;
      return entries.every(([key, value]) => {
        const contract = expected.get(key);
        if (!contract) return false;
        if (contract?.kind === 'tags') {
          return Array.isArray(value)
            && value.length <= contract.threshold
            && new Set(value).size === value.length
            && value.every(tag => typeof tag === 'string' && /^[a-z][a-z0-9_]{0,47}$/.test(tag));
        }
        return Number.isInteger(Number(value))
          && Number(value) >= 0
          && Number(value) < contract;
      });
  }

  _legacyDynamicSnapshotIsSafe(snapshot) {
      const noLiveStatuses = [snapshot.playerStatus, snapshot.enemyStatus].every(statuses =>
        Object.values(statuses || {}).every(value => Number(value) === 0)
      );
      const noRuntimeEquipmentProgress = Object.values(snapshot.equipmentState || {})
        .every(value => Array.isArray(value) ? value.length === 0 : Number(value) === 0);
      return noLiveStatuses
        && noRuntimeEquipmentProgress
        && Number(snapshot.player?.block) === 0
        && Number(snapshot.enemy?.block) === 0
        && Number(snapshot.nextTurnDrawPenalty) === 0;
  }

  _sameCardMultiset(left, right) {
      if (!Array.isArray(left) || !Array.isArray(right) || left.length !== right.length) return false;
      const counts = cards => {
          const result = new Map();
          for (const cardId of cards) result.set(cardId, (result.get(cardId) || 0) + 1);
          return result;
      };
      const a = counts(left);
      const b = counts(right);
      return a.size === b.size && [...a].every(([cardId, count]) => b.get(cardId) === count);
  }

  _validateDeckSnapshot(snapshot, expectedMasterDeck, cardDB) {
      const piles = ['masterDeck', 'drawPile', 'hand', 'discardPile', 'exhaustPile'];
      if (piles.some(field => !Array.isArray(snapshot[field]) || snapshot[field].some(cardId => typeof cardId !== 'string'))) {
          return false;
      }
      if (JSON.stringify(snapshot.masterDeck) !== JSON.stringify(expectedMasterDeck)) return false;
      const partition = [snapshot.drawPile, snapshot.hand, snapshot.discardPile, snapshot.exhaustPile].flat();
      const equipmentPassives = this._authorityEquipmentPassives();
      const temporaryAllowed = new Set(equipmentPassives.flatMap((passive, index) => (
        passive?.temporaryTacticalCardId
          && Number(snapshot.equipmentState?.[this._equipmentPassiveStateKey(passive, index)]) > 0
          ? [passive.temporaryTacticalCardId] : []
      )));
      const temporary = partition.filter(cardId => temporaryAllowed.has(cardId));
      if (temporary.some(cardId => !cardDB[cardId]?.temporaryOnly)
        || [...new Set(temporary)].some(cardId => temporary.filter(id => id === cardId).length > 1)) return false;
      const permanentPartition = partition.filter(cardId => !temporaryAllowed.has(cardId));
      if (!this._sameCardMultiset(permanentPartition, expectedMasterDeck)) return false;
      return partition.every(cardId => {
          const baseId = cardId.replace(/\++$/, '');
          return Boolean(cardDB[cardId] || cardDB[baseId]);
      });
  }

  _upgradeV2AuthoritySnapshot(snapshot, cardDB) {
      if (Number(snapshot?.version) !== 2 || !Array.isArray(snapshot.authorityLedger)) return null;
      const clone = value => JSON.parse(JSON.stringify(value));
      const upgraded = clone(snapshot);
      upgraded.version = 3;
      let pathState = typeof pathArchetypeSystem !== 'undefined' && pathArchetypeSystem
        && typeof pathArchetypeSystem.buildOpeningCombatState === 'function'
        ? pathArchetypeSystem.buildOpeningCombatState()
        : null;
      const enriched = [];
      let previousHash = 'dc2-root';
      for (let index = 0; index < snapshot.authorityLedger.length; index++) {
        const sourceEntry = snapshot.authorityLedger[index];
        const detail = clone(sourceEntry.detail || {});
        const previousState = enriched[index - 1]?.state || null;
        if (index > 0 && sourceEntry.kind === 'CARD_PLAY') {
          const playedId = detail.cardId;
          if (!Number.isInteger(Number(detail.handIndex))) {
            detail.handIndex = previousState?.hand?.indexOf(playedId) ?? -1;
          }
          const card = this._authorityCardDef(playedId, cardDB);
          if (!card || detail.handIndex < 0) return null;
          detail.definitionId = card.id || playedId;
          if (pathState) {
            const transition = pathArchetypeSystem.previewCardTransition(pathState, card, {
              player: { ...snapshot.player, hp: previousState.player.hp, block: previousState.player.block },
              enemy: { ...snapshot.enemy, hp: previousState.enemy.hp, block: previousState.enemy.block },
              playerStatus: previousState.playerStatus,
              enemyStatus: previousState.enemyStatus,
              qi: previousState.qi,
              maxQi: snapshot.maxQi
            });
            if (!transition) return null;
            pathState = transition.combatState;
          }
        } else if (index > 0 && sourceEntry.kind === 'REACTION_OPEN') {
          pathState = this._pathTurnBoundary(pathState, false);
        } else if (index > 0 && sourceEntry.kind === 'TURN_START') {
          pathState = this._pathTurnBoundary(pathState, true);
          if (!detail.reactionWindowId || !detail.reactionId) {
            const nextEntry = snapshot.authorityLedger[index + 1];
            detail.reactionWindowId = previousState?.pendingReaction?.windowId || null;
            detail.reactionId = nextEntry?.kind === 'REACTION_RESOLVED'
              ? nextEntry.detail?.reactionId || null
              : null;
          }
        }
        const state = clone(sourceEntry.state);
        state.player = {
          hp: Number(state.player?.hp),
          maxHp: Number(snapshot.player?.maxHp),
          block: Number(state.player?.block),
          aura: Number(state.player?.aura),
          atkMod: Number(snapshot.player?.atkMod),
          defMod: Number(snapshot.player?.defMod),
          critRate: Number(snapshot.player?.critRate)
        };
        state.enemy = {
          name: snapshot.enemy?.name || '',
          hp: Number(state.enemy?.hp),
          maxHp: Number(snapshot.enemy?.maxHp),
          block: Number(state.enemy?.block),
          tier: Number(snapshot.enemy?.tier),
          atkPower: Number(snapshot.enemy?.atkPower),
          defPower: Number(snapshot.enemy?.defPower),
          planRuntime: clone(state.enemy?.planRuntime || null)
        };
        state.bossPhaseIndex = Number.isInteger(Number(state.bossPhaseIndex))
          ? Number(state.bossPhaseIndex)
          : Number(snapshot.bossPhaseIndex) || 0;
        state.pathCombatState = clone(pathState);
        const unsigned = {
          sequence: index + 1,
          previous: previousHash,
          kind: sourceEntry.kind,
          sourceCardId: sourceEntry.sourceCardId,
          turn: sourceEntry.turn,
          detail,
          state
        };
        const hash = this._computeCombatAuthoritySeal({ ledgerEntry: unsigned });
        enriched.push({ ...unsigned, hash });
        previousHash = hash;
      }
      upgraded.authorityLedger = enriched;
      upgraded.authorityChain = previousHash;
      upgraded.pathCombatState = clone(pathState);
      upgraded.authoritySeal = this._computeCombatAuthoritySeal(upgraded);
      return upgraded;
  }

  hydrateState(snapshot, options = {}) {
      const clone = value => JSON.parse(JSON.stringify(value));
      let snapshotVersion = Number(snapshot?.version);
      if (!snapshot || snapshotVersion !== 3 || snapshot.active !== true) return false;
      if (typeof snapshot.authoritySeal !== 'string'
        || snapshot.authoritySeal !== this._computeCombatAuthoritySeal(snapshot)
        || !this._validateAuthorityLedger(snapshot)) return false;
      if (!['PLAYER_TURN', 'REACTION_OPEN'].includes(snapshot.phase)) return false;
      if (!snapshot.originalCard?.id || !snapshot.originalCard?.enemy || !snapshot.player || !snapshot.enemy) return false;
      const settledReactionWindows = snapshot.settledReactionWindows;
      if (!Array.isArray(settledReactionWindows)
        || settledReactionWindows.length > 40
        || new Set(settledReactionWindows).size !== settledReactionWindows.length
        || settledReactionWindows.some(windowId => typeof windowId !== 'string'
          || !windowId.startsWith(`${snapshot.originalCard.id}:turn:`))) return false;
      if (snapshot.phase === 'PLAYER_TURN' && snapshot.pendingReaction !== null) return false;
      if (snapshot.pendingReaction?.windowId
        && settledReactionWindows.includes(snapshot.pendingReaction.windowId)) return false;
      if (!Number.isInteger(Number(snapshot.nextTurnDrawPenalty))
        || Number(snapshot.nextTurnDrawPenalty) !== 0
        || typeof snapshot.damageDealtThisTurn !== 'boolean') return false;
      const snapshotQi = Number(snapshot.qi);
      const snapshotMaxQi = Number(snapshot.maxQi);
      const authoritativeMaxQi = this._maxQiForRealm(gameState?.realm);
      if (!Number.isFinite(snapshotQi) || snapshotQi < 0
        || !Number.isFinite(snapshotMaxQi) || snapshotMaxQi !== authoritativeMaxQi
        || snapshotQi > snapshotMaxQi + 5) return false;
      if (!Number.isInteger(Number(snapshot.turn)) || Number(snapshot.turn) < 1 || Number(snapshot.turn) > 100000) return false;
      if (snapshot.phase === 'REACTION_OPEN') {
          const pending = snapshot.pendingReaction;
          if (!pending?.windowId || pending.turn !== snapshot.turn || !Array.isArray(pending.options)) return false;
          const reactionSequence = Math.max(0, Math.floor(Number(snapshot.reactionSequence) || 0));
          const expectedWindowId = `${snapshot.originalCard.id}:turn:${snapshot.turn}:reaction:${reactionSequence}`;
          const canonicalAction = this._previewEnemyAction(snapshot.enemyIntent, snapshot.enemy);
          const canonicalOptions = this._buildReactionOptions(canonicalAction, {
            qi: snapshot.qi,
            pathId: typeof gameState !== 'undefined' && gameState?.path ? gameState.path : 'sword'
          });
          const identityMatches = reactionSequence > 0
            && pending.windowId === expectedWindowId
            && pending.sourceCardId === snapshot.originalCard.id
            && pending.source === snapshot.enemy.name
            && pending.target === 'player'
            && ['paused', 'timed'].includes(pending.mode);
          if (!identityMatches) return false;
          if (JSON.stringify(pending.action) !== JSON.stringify(canonicalAction)) return false;
          if (JSON.stringify(pending.options) !== JSON.stringify(canonicalOptions)) return false;
      }

      const cardData = typeof dataLoader !== 'undefined' && dataLoader
        && typeof dataLoader.loadSync === 'function'
        ? dataLoader.loadSync('cards:battle_cards')
        : null;
      let nextCardDB = this.cardDB || {};
      let nextEnemyDB = this.enemyDB || {};
      if (cardData?.battle_cards) {
          nextCardDB = {};
          cardData.battle_cards.forEach(card => { nextCardDB[card.id] = card; });
          nextEnemyDB = {};
          (cardData.enemies || []).forEach(enemyDef => { nextEnemyDB[enemyDef.id] = enemyDef; });
      }
      const encounterCatalog = typeof dataLoader !== 'undefined' && dataLoader
        && typeof dataLoader.loadSync === 'function'
        ? dataLoader.loadSync('combat:encounters')
        : null;
      const authoredEncounter = (encounterCatalog?.encounters || []).find(encounter =>
        encounter.id === snapshot.originalCard.encounterId
      );
      const authoredCard = nextCardDB[snapshot.originalCard.id] || null;
       const authoredModuleCard = this._findAuthoredCombatCard(
         snapshot.originalCard.id,
         snapshot.originalCard.realm || snapshot.player.realm
       );
       // Catalog encounters are materialized as choice-owned combat cards by
       // CardSystem. On a cold reload that cache can still contain only the
       // source narrative record when combat hydrate runs. Rebuild it through
       // the public CardSystem producer before checking the saved choice
       // contract; otherwise a valid ordinary encounter cannot reconstruct its
       // enemy/resolution authority and the player loses the paused battle.
       if (snapshot.originalCard.encounterId
         && typeof cardSystem !== 'undefined'
         && typeof cardSystem?.refreshCombatEncounterCards === 'function') {
           cardSystem.refreshCombatEncounterCards(gameState?.path || null);
       }
       const authoredRuntimeCard = this._resolveAuthoredRuntimeCard(
         snapshot.originalCard.id,
        snapshot.originalCard.realm || snapshot.player.realm,
        snapshot.originalCard.threshold
      );
       // Encounter data can be the canonical combat payload for a different
       // authored source (faction invitation, thread choice, chapter branch).
       // It owns the enemy/rules, but only a catalog card whose own ID is
       // encounter_card_<id> may claim catalog-card identity on restore.
       const expectedEncounterCardId = authoredEncounter
         ? `encounter_card_${authoredEncounter.id}`
         : null;
       const catalogEncounterOwnsCard = Boolean(
         authoredEncounter && snapshot.originalCard.id === expectedEncounterCardId
       );
       const authoredSource = catalogEncounterOwnsCard
         ? authoredEncounter
         : (authoredModuleCard || authoredCard || authoredRuntimeCard);
       if (!authoredSource) return false;
       if (catalogEncounterOwnsCard) {
           if (snapshot.originalCard.id !== expectedEncounterCardId
             || snapshot.originalCard.encounterId !== authoredEncounter.id) return false;
      } else if (snapshot.originalCard.id !== authoredSource.id) {
          return false;
      }
      if (!authoredRuntimeCard || authoredRuntimeCard.id !== snapshot.originalCard.id) return false;
      const canonicalResolution = this._canonicalResolutionAuthority(
        snapshot.resolutionContext,
        snapshot.originalCard.realm || snapshot.player.realm
      );
      if (!canonicalResolution.valid) return false;
      const authoredChoiceCombat = this._combatCardFromAuthoredChoice(
        authoredRuntimeCard,
        null,
        snapshot.originalCard.enemy
      );
      if (Boolean(authoredChoiceCombat?.choice) !== Boolean(snapshot.resolutionContext)) return false;
      const authoredCombat = canonicalResolution.combatCard
        ? { combatCard: canonicalResolution.combatCard }
        : authoredChoiceCombat;
      const canonicalOriginalCard = authoredCombat?.combatCard;
      // A present selector must agree with the authored active graph. Missing
      // selectors in legacy snapshots can be rebuilt, never copied as authority.
      for (const field of ['_dungeonNodeId', '_dungeonNodeType']) {
          if (Object.prototype.hasOwnProperty.call(snapshot.originalCard, field)
            && snapshot.originalCard[field] !== canonicalOriginalCard?.[field]) return false;
      }
      if (!canonicalOriginalCard
        || this._stableAuthoritySerialize(this._combatSettlementProjection(snapshot.originalCard))
          !== this._stableAuthoritySerialize(this._combatSettlementProjection(canonicalOriginalCard))) {
          return false;
      }
      const canonicalEncounter = this._canonicalEncounterAuthority(
        snapshot.encounterContext,
        canonicalOriginalCard
      );
      if (!canonicalEncounter.valid || !canonicalEncounter.value) return false;
      // CardSystem is the runtime producer for catalog encounters. It may
      // attach deterministic role-plan contracts that are not duplicated in
      // the raw JSON record, so hydrate must validate against that canonical
      // produced card before falling back to storage modules.
      const authoredRootEnemy = canonicalOriginalCard?.enemy
        || authoredEncounter?.enemy
        || authoredModuleCard?.enemy
        || authoredCard?.enemy
        || null;
      if (!authoredRootEnemy) return false;
      if (JSON.stringify(snapshot.originalCard.enemy?.planGraph || null)
          !== JSON.stringify(authoredRootEnemy.planGraph || null)) return false;
      const authoredRootTemplate = authoredRootEnemy.templateId
        ? nextEnemyDB[authoredRootEnemy.templateId]
        : null;
      const canonicalBossPhases = Array.isArray(authoredRootEnemy.phases)
        ? authoredRootEnemy.phases
        : (Array.isArray(authoredRootTemplate?.phases) ? authoredRootTemplate.phases : []);
      const snapshotBossPhases = Array.isArray(snapshot.bossPhases) ? snapshot.bossPhases : [];
      const bossPhaseIndex = Number(snapshot.bossPhaseIndex);
      if (!Number.isInteger(bossPhaseIndex) || bossPhaseIndex < 0
        || (canonicalBossPhases.length === 0 && bossPhaseIndex !== 0)
        || (canonicalBossPhases.length > 0 && bossPhaseIndex >= canonicalBossPhases.length)
        || JSON.stringify(snapshotBossPhases) !== JSON.stringify(canonicalBossPhases)
        || JSON.stringify(snapshot.originalCard.enemy?.phases || []) !== JSON.stringify(canonicalBossPhases)) {
        return false;
      }
      const canonicalPhaseData = canonicalBossPhases.length > 0
        ? canonicalBossPhases[bossPhaseIndex]
        : authoredRootEnemy;
      const canonicalTemplateId = canonicalPhaseData.templateId
        || canonicalPhaseData.id
        || authoredRootEnemy.templateId
        || authoredRootEnemy.id;
      const canonicalTemplate = canonicalTemplateId ? nextEnemyDB[canonicalTemplateId] : null;
      const authoredCombatRules = authoredEncounter?.combatRules
        || canonicalOriginalCard?.combatRules
        || authoredRuntimeCard?.combatRules
        || authoredModuleCard?.combatRules
        || authoredCard?.combatRules
        || {};
      if (snapshotVersion >= 2
        && !this._validateAuthorityLedgerSemantics(snapshot, authoredCombatRules, nextCardDB, {
          requirePath: snapshotVersion >= 3, enemyDB: nextEnemyDB
        })) return false;
      const enemyAuthority = this._canonicalEnemyAuthority(
        canonicalPhaseData,
        authoredRootEnemy,
        authoredCombatRules,
        bossPhaseIndex,
        canonicalOriginalCard
      );
      const enemyHp = Number(snapshot.enemy.hp);
      const enemyBlock = Number(snapshot.enemy.block);
      const enemyIntentIndex = Number(snapshot.enemy.intentIndex);
      if (snapshot.enemy.name !== (enemyAuthority.name || canonicalTemplate?.name)
        || Number(snapshot.enemy.tier) !== enemyAuthority.tier
        || Number(snapshot.enemy.maxHp) !== enemyAuthority.maxHp
        || !Number.isFinite(enemyHp) || enemyHp <= 0 || enemyHp > enemyAuthority.maxHp
        || Number(snapshot.enemy.atkPower) !== enemyAuthority.atkPower
        || Number(snapshot.enemy.defPower) !== enemyAuthority.defPower
        || !Number.isInteger(enemyBlock) || enemyBlock < 0 || enemyBlock > 100
        || !Number.isInteger(enemyIntentIndex) || enemyIntentIndex < 0
        || enemyIntentIndex > Number(snapshot.turn) + 1
        || (snapshot.enemy.factionId || null) !== enemyAuthority.factionId
        || snapshot.enemy.realm !== enemyAuthority.realm) return false;
      const usedConditions = Array.isArray(snapshot.enemy.usedConditions) ? snapshot.enemy.usedConditions : [];
      const authoritativeIntents = Array.isArray(canonicalPhaseData.intents)
        ? canonicalPhaseData.intents
        : (Array.isArray(authoredRootEnemy.intents)
          ? authoredRootEnemy.intents
          : (Array.isArray(canonicalTemplate?.intents) ? canonicalTemplate.intents : []));
      const allowedConditionIds = new Set(authoritativeIntents.filter(intent => intent?.condition).map(intent => intent.desc));
      if (usedConditions.length > allowedConditionIds.size
        || new Set(usedConditions).size !== usedConditions.length
        || usedConditions.some(conditionId => !allowedConditionIds.has(conditionId))) return false;

      const playerAuthority = this._buildPlayerAuthority();
      const combatAssist = typeof npcSystem !== 'undefined' && npcSystem && typeof npcSystem.getCombatAssist === 'function'
        ? npcSystem.getCombatAssist()
        : null;
      const expectedPlayer = {
        ...playerAuthority.player,
        atkMod: playerAuthority.player.atkMod + (Number(combatAssist?.atk) || 0)
      };
      const playerHp = Number(snapshot.player.hp);
      const playerBlock = Number(snapshot.player.block);
      const playerAura = Number(snapshot.player.aura);
      const immutablePlayerFields = [
        'maxHp', 'atkMod', 'defMod', 'critRate', 'daoHeart', 'realm',
        'lowHpAtkBonus', 'lowHpDamageBonus', 'pillBonus'
      ];
      if (Number(snapshot.preCombatHealth) !== playerAuthority.preCombatHealth
        || !Number.isFinite(playerHp) || playerHp <= 0 || playerHp > expectedPlayer.maxHp
        || !Number.isInteger(playerBlock) || playerBlock < 0 || playerBlock > 100
        || !Number.isFinite(playerAura) || playerAura < 0 || playerAura > expectedPlayer.aura
        || immutablePlayerFields.some(field => snapshot.player[field] !== expectedPlayer[field])) return false;

      const deckAuthority = this._buildMasterDeckAuthority(nextCardDB, canonicalOriginalCard);
      if (!this._validateDeckSnapshot(snapshot, deckAuthority.masterDeck, nextCardDB)) return false;
      if (!this._validateStatusSnapshot(snapshot.playerStatus)
        || !this._validateStatusSnapshot(snapshot.enemyStatus)
        || !this._validateEquipmentStateSnapshot(snapshot.equipmentState)) return false;
      const appliedByEnemy = snapshot.playerStatusesAppliedByEnemy;
      if (!Array.isArray(appliedByEnemy)
        || new Set(appliedByEnemy).size !== appliedByEnemy.length
        || appliedByEnemy.some(statusId => typeof statusId !== 'string'
          || Number(snapshot.playerStatus[statusId]) <= 0)) return false;
      const canonicalPlanGraph = this._getAuthoritativeTurnCycle(canonicalOriginalCard)
        ? null
        : this._normalizePlanGraph(
          canonicalPhaseData.planGraph || authoredRootEnemy.planGraph || canonicalTemplate?.planGraph
        );
      const snapshotPlan = snapshot.enemy.planRuntime;
      let restoredPlan = snapshotPlan || null;
      let restoredIntent = snapshot.enemyIntent ? clone(snapshot.enemyIntent) : null;
      if (canonicalPlanGraph) {
          if (!snapshotPlan) {
              const migrated = this._migratePlanlessSnapshot(canonicalPlanGraph, snapshot);
              restoredPlan = migrated.runtime;
              restoredIntent = migrated.intent;
          } else {
              if (!this._validatePlanRuntimeSnapshot(snapshotPlan, canonicalPlanGraph, snapshot, nextCardDB)) return false;
              const canonicalIntent = canonicalPlanGraph.states[snapshotPlan.intentState].intent;
              const intentFieldsMatch = ['type', 'value', 'statusId', 'actionName', 'desc', 'actionFamily'].every(field =>
                snapshot.enemyIntent?.[field] === canonicalIntent?.[field]
              );
              if (!intentFieldsMatch
                || snapshot.enemyIntent?.planId !== canonicalPlanGraph.planId
                || snapshot.enemyIntent?.planState !== snapshotPlan.intentState) return false;
          }
      } else if (snapshotPlan) {
          return false;
      } else {
          const randomIntents = canonicalPhaseData.randomIntents
            ?? authoredRootEnemy.randomIntents
            ?? canonicalTemplate?.randomIntents
            ?? false;
          if (!this._validateNonPlanIntentAuthority(
            snapshot,
            authoritativeIntents,
            randomIntents === true,
            canonicalOriginalCard
          )) return false;
      }

      this._clearReactionTimer();
      // Presentation locks are not authoritative combat state. A snapshot
      // restore must never inherit a future click window from the discarded
      // runtime, especially when it restores an earlier hand/turn.
      this._clearPlayerInputLockTimer();
      this._playerInputLockUntil = 0;
      this._visiblePlayerActionIds.clear();
      this._clearPresentationActionTimers();
      this.cardDB = nextCardDB;
      this.enemyDB = nextEnemyDB;
      this.active = true;
      this.phase = snapshot.phase;
      this.turn = Math.max(1, Math.floor(Number(snapshot.turn) || 1));
      this.preCombatHealth = Number(snapshot.preCombatHealth) || 0;
      this.originalCard = clone(canonicalOriginalCard);
      this.originalCard.enemy = clone(authoredRootEnemy);
      if (Object.prototype.hasOwnProperty.call(canonicalOriginalCard, 'combatRules')
        || Object.keys(authoredCombatRules).length > 0) {
          this.originalCard.combatRules = clone(authoredCombatRules);
      }
      this.encounterContext = canonicalEncounter.value ? clone(canonicalEncounter.value) : null;
      if (this.encounterContext) this.originalCard.encounterContext = clone(this.encounterContext);
      this.resolutionContext = canonicalResolution.value ? clone(canonicalResolution.value) : null;
      this.player = clone(snapshot.player);
      this.enemy = clone(snapshot.enemy);
      if (canonicalPlanGraph) {
          this.enemy.def = { ...(this.enemy.def || {}), planGraph: canonicalPlanGraph };
          this.enemy.planRuntime = restoredPlan;
      }
      this.enemy.usedConditions = new Set(Array.isArray(snapshot.enemy.usedConditions)
        ? snapshot.enemy.usedConditions
        : []);
      this.qi = Math.max(0, Number(snapshot.qi) || 0);
      this.maxQi = authoritativeMaxQi;
      this.masterDeck = clone(deckAuthority.masterDeck);
      this.drawPile = clone(snapshot.drawPile || []);
      this.hand = clone(snapshot.hand || []);
      this.discardPile = clone(snapshot.discardPile || []);
      this.exhaustPile = clone(snapshot.exhaustPile || []);
      this.playerStatus = clone(snapshot.playerStatus || {});
      this.enemyStatus = clone(snapshot.enemyStatus || {});
      this._playerStatusesAppliedByEnemy = new Set(snapshot.playerStatusesAppliedByEnemy || []);
      this.enemyIntent = restoredIntent;
      this.bossPhases = clone(canonicalBossPhases);
      this.bossPhaseIndex = bossPhaseIndex;
      this.pendingReaction = snapshot.pendingReaction ? clone(snapshot.pendingReaction) : null;
      this._reactionSequence = Math.max(0, Math.floor(Number(snapshot.reactionSequence) || 0));
      this._settledReactionWindows = new Set(settledReactionWindows);
      this._nextTurnDrawPenalty = 0;
      this.equipmentState = clone(snapshot.equipmentState || {});
      this.damageDealtThisTurn = Boolean(snapshot.damageDealtThisTurn);
      this.log = clone(snapshot.log || []).slice(0, 10);
      const authoritativePathPresentations = typeof dataLoader !== 'undefined' && dataLoader
        && typeof dataLoader.loadSync === 'function'
        ? dataLoader.loadSync('combat:path_presentations')
        : null;
      this._pathPresentationData = clone(authoritativePathPresentations?.paths
        ? authoritativePathPresentations
        : { paths: {} });
      const authoritativeProtagonistIdentity = typeof dataLoader !== 'undefined' && dataLoader
        && typeof dataLoader.loadSync === 'function'
        ? dataLoader.loadSync('combat:protagonist_visual_identity')
        : null;
      this._protagonistVisualIdentity = clone(
        authoritativeProtagonistIdentity?.contractId === 'protagonist_yelingyun_visual_identity_v1'
          ? authoritativeProtagonistIdentity
          : null
      );
      const authoritativeActionPresentations = typeof dataLoader !== 'undefined' && dataLoader
        && typeof dataLoader.loadSync === 'function'
        ? dataLoader.loadSync('combat:action_presentations')
        : null;
      this._actionPresentationData = clone(
        authoritativeActionPresentations?.contractId === 'combat_action_presentation_registry_v1'
          ? authoritativeActionPresentations
          : { paths: {}, encounters: {}, timelines: {}, sfxCues: {}, bossPhaseTransitions: {} }
      );
      const authoritativeVisualWorlds = typeof dataLoader !== 'undefined' && dataLoader
        && typeof dataLoader.loadSync === 'function'
        ? dataLoader.loadSync('combat:visual_worlds')
        : null;
      this._visualWorldData = clone(
        authoritativeVisualWorlds?.contractId === 'combat_visual_world_registry_v1'
          ? authoritativeVisualWorlds
          : { worlds: {} }
      );
      const authoritativeScaleProvenance = typeof dataLoader !== 'undefined' && dataLoader
        && typeof dataLoader.loadSync === 'function'
        ? dataLoader.loadSync('combat:carrier_scale_provenance')
        : null;
      this._carrierScaleProvenance = clone(
        authoritativeScaleProvenance?.contractId === 'combat_carrier_scale_provenance_v1'
          ? authoritativeScaleProvenance
          : { contractId: null, records: {} }
      );
      const authoritativeActionScaleProvenance = typeof dataLoader !== 'undefined' && dataLoader
        && typeof dataLoader.loadSync === 'function'
        ? dataLoader.loadSync('combat:action_scale_provenance')
        : null;
      this._actionScaleProvenance = clone(
        authoritativeActionScaleProvenance?.contractId === 'combat_action_scale_provenance_v1'
          ? authoritativeActionScaleProvenance
          : { contractId: null, records: {} }
      );
      this._activeSemanticAction = null;
      this._semanticActionSequence = 0;
      this._pendingPathSynergyReceipt = null;
      this._companionCombatContracts = clone(deckAuthority.companionContracts);
      if (typeof pathArchetypeSystem !== 'undefined' && pathArchetypeSystem
        && typeof pathArchetypeSystem.hydrateCombatState === 'function') {
          const restoredPathState = snapshotVersion >= 3
            ? snapshot.pathCombatState
            : pathArchetypeSystem.buildOpeningCombatState?.();
          if (restoredPathState && !pathArchetypeSystem.hydrateCombatState(restoredPathState)) {
            return false;
          }
      }
      if (snapshotVersion >= 2) {
          this._authorityLedger = clone(snapshot.authorityLedger);
          this._authorityChain = snapshot.authorityChain;
      } else {
          this._authorityLedger = [];
          this._authorityChain = 'dc2-root';
          this._recordAuthorityCheckpoint('LEGACY_MIGRATED', { sourceVersion: 1 });
      }

      if (this.pendingReaction?.mode === 'timed') this._scheduleReactionExpiry(this.pendingReaction);
      if (options.present !== false) {
          eventBus.emit('ui:showCombatScreen');
          eventBus.emit('combat:started', this._getPresentationContext());
          this._triggerUpdate();
      }
      return true;
  }

  _resolvePlacementBodyProfileId(side, placement = {}, playerPath = '', actorCard = null) {
      if (side !== 'player') return placement?.bodyProfileId || null;
      if (placement?.profileBinding === 'runtime_player_actor_card') {
          const runtimeProfileId = typeof actorCard?.scaleProfileId === 'string'
              ? actorCard.scaleProfileId.trim()
              : '';
          return runtimeProfileId || null;
      }
      const byPath = placement?.bodyProfileIdsByPath;
      if (!byPath || typeof byPath !== 'object' || Array.isArray(byPath)) {
          return placement?.bodyProfileId || null;
      }
      const pathId = String(playerPath || '');
      return typeof byPath[pathId] === 'string' && byPath[pathId]
          ? byPath[pathId]
          : null;
  }

  _collectEncounterActionAnimations(actionSet = {}) {
      if (!actionSet || typeof actionSet !== 'object' || Array.isArray(actionSet)) return [];
      const animations = [];
      for (const action of Object.values(actionSet)) {
          if (!action || typeof action !== 'object' || Array.isArray(action)) continue;
          if (action.animation) animations.push(action.animation);
          const variants = action.variantsBySourceId;
          if (!variants || typeof variants !== 'object' || Array.isArray(variants)) continue;
          for (const variant of Object.values(variants)) {
              if (variant && typeof variant === 'object' && !Array.isArray(variant) && variant.animation) {
                  animations.push(variant.animation);
              }
          }
      }
      return animations;
  }

  _collectPlayerStagePreloadAnimations(pathId = 'sword', displayedVisualStageId = null) {
      const registry = this._actionPresentationData || {};
      const roots = [
          ...Object.values(registry.paths?.[pathId] || {}),
          ...Object.values(registry.terminalPlayerActions?.[pathId] || {})
      ];
      const seen = new Set();
      const animations = [];
      for (const action of roots) {
          const candidates = [
              (displayedVisualStageId ? action?.stageAnimations?.[displayedVisualStageId] : null)
                || action?.animation || null,
              ...Object.values(action?.variantsBySourceId || {}).map(variant =>
                  (displayedVisualStageId ? variant?.stageAnimations?.[displayedVisualStageId] : null)
                    || (displayedVisualStageId && action?.stageAnimations?.[displayedVisualStageId])
                    || variant?.animation || action?.animation || null)
          ];
          for (const animation of candidates) {
              if (!this._isPlayerActionAnimationCompatible(animation, displayedVisualStageId)
                  || animation?.kind !== 'frame_sequence'
                  || animation.motionApproved !== true
                  || !Array.isArray(animation.frames)
                  || !animation.frameSetId
                  || seen.has(animation.frameSetId)) continue;
              seen.add(animation.frameSetId);
              animations.push(animation);
          }
      }
      // Per-card action carriers are played instead of the path default, so
      // they have to be fetched with it. Left out, a card-specific strike
      // loaded its frames at play time: the first frame blocked the main
      // thread while it decoded, every later frame then resolved against an
      // already-elapsed clock, and the whole sequence landed in one paint.
      for (const action of Object.values(registry.cardActions || {})) {
          const stageVariant = displayedVisualStageId
              ? action?.stageAnimations?.[displayedVisualStageId]
              : null;
          for (const animation of [stageVariant, action?.animation]) {
              if (!this._isPlayerActionAnimationCompatible(animation, displayedVisualStageId)
                  || animation?.kind !== 'frame_sequence'
                  || animation?.motionApproved !== true
                  || !Array.isArray(animation.frames)
                  || !animation.frameSetId
                  || seen.has(animation.frameSetId)) continue;
              seen.add(animation.frameSetId);
              animations.push(animation);
          }
      }
      return animations;
  }

  _getPresentationContext() {
      const card = this.originalCard || {};
      const enemy = card.enemy || {};
      const presentation = card.combatPresentation || {};
      const playerPath = (typeof gameState !== 'undefined' && gameState && gameState.path)
        ? gameState.path
        : 'sword';
      const pathContract = this.getPathContract(playerPath);
      const encounterActors = presentation.actorCards || {};
      const equippedTreasures = (typeof treasureSystem !== 'undefined' && treasureSystem
        && typeof treasureSystem.getEquippedCombatPresentations === 'function')
        ? treasureSystem.getEquippedCombatPresentations()
        : [];
      const actorCards = {
          ...encounterActors,
          player: pathContract?.actorCard || encounterActors.player || null
      };
      // A scene is allowed to claim one visual world only when both the
      // encounter and the selected cultivation path opt into the same authored
      // contract.  Legacy content remains playable but is explicitly marked
      // incompatible; the renderer must never silently style-mix it into an
      // approved world merely because one side supplied an ID.
      const encounterVisualWorldId = typeof presentation.visualWorldId === 'string'
        ? presentation.visualWorldId.trim()
        : '';
      const pathVisualWorldId = typeof pathContract?.visualWorldId === 'string'
        ? pathContract.visualWorldId.trim()
        : '';
      const candidateVisualWorld = encounterVisualWorldId
        ? this._visualWorldData?.worlds?.[encounterVisualWorldId]
        : null;
      const encounterCompositionId = this._encounterActionId();
      const battlefieldProfileId = typeof presentation.battlefieldId === 'string'
        ? presentation.battlefieldId.trim()
        : '';
      const candidateBattlefieldProfile = battlefieldProfileId
        ? candidateVisualWorld?.battlefieldProfiles?.[battlefieldProfileId]
        : null;
      const candidateEncounterComposition = encounterCompositionId
        ? candidateVisualWorld?.encounterCompositions?.[encounterCompositionId]
        : null;
      const isUnitNumber = value => typeof value === 'number' && Number.isFinite(value)
        && value >= 0 && value <= 1;
      const isPositiveUnitNumber = value => isUnitNumber(value) && value > 0;
      const isUnitPoint = point => point && isUnitNumber(point.x) && isUnitNumber(point.y);
      const isUnitRect = rect => rect
        && isUnitNumber(rect.x) && isUnitNumber(rect.y)
        && isPositiveUnitNumber(rect.width) && isPositiveUnitNumber(rect.height)
        && rect.x + rect.width <= 1.000001
        && rect.y + rect.height <= 1.000001;
      const near = (left, right, tolerance = 0.000001) => Number.isFinite(Number(left))
        && Number.isFinite(Number(right)) && Math.abs(Number(left) - Number(right)) <= tolerance;
      const normaliseVisualPath = value => String(value || '').trim().replace(/\\/g, '/').replace(/^\.\//, '');
      const scaleProvenanceCompatible = Boolean(
        candidateVisualWorld?.carrierScaleProvenance?.contractId === 'combat_carrier_scale_provenance_v1'
        && this._carrierScaleProvenance?.contractId === 'combat_carrier_scale_provenance_v1'
        && this._carrierScaleProvenance?.policy
          === 'one_asset_sha_one_entity_authored_profile_binding_species_morphology_stage_role_change_requires_rebind'
        && this._carrierScaleProvenance?.entityAuthoredPolicy
          === 'species_morphology_progression_stage_combat_role_own_scale_tier_rarity_hp_forbidden'
        && this._carrierScaleProvenance?.records
      );
      const isCarrierScaleBindingCompatible = (carrierMetric, bodyProfile, profileId, carrierMetricId) => {
        const authoredScale = carrierMetric?.authoredScale;
        const record = this._carrierScaleProvenance?.records?.[carrierMetric?.assetSha256];
        const bodyAspect = Number(carrierMetric?.bodyBounds?.width)
          / Number(carrierMetric?.bodyBounds?.height);
        const profileAspect = Number(bodyProfile?.canonicalWidthU)
          / Number(bodyProfile?.canonicalHeightU);
        const strictProfileBindingCompatible = bodyProfile?.spatialContractId !== 'actor_spatial_v1'
          || (record?.bodyProfileContractSha256 === bodyProfile?.bodyProfileContractSha256
            && ['speciesId', 'morphologyId', 'progressionStageId', 'combatRoleId'].every(field => (
              record?.authoredScaleBasis?.[field] === bodyProfile?.authoredScaleBasis?.[field]
            )));
        return Boolean(scaleProvenanceCompatible
          && authoredScale?.source === 'external_carrier_scale_provenance_v1'
          && authoredScale.assetSha256 === carrierMetric?.assetSha256
          && record?.recordId === authoredScale.recordId
          && record.assetSha256 === carrierMetric?.assetSha256
          && record.assetPath === carrierMetric?.assetPath
          && record.carrierMetricId === carrierMetricId
          && record.bodyProfileId === profileId
          && bodyProfile?.id === profileId
          && near(record.canonicalHeightU, bodyProfile?.canonicalHeightU)
          && near(record.canonicalWidthU, bodyProfile?.canonicalWidthU)
          && record.bodyClass === bodyProfile?.bodyClass
          && record.visualThreatRank === bodyProfile?.visualThreatRank
          && near(record.naturalWidth, carrierMetric?.naturalWidth)
          && near(record.naturalHeight, carrierMetric?.naturalHeight)
          && ['x', 'y', 'width', 'height'].every(key => near(
            record.bodyBounds?.[key], carrierMetric?.bodyBounds?.[key]
          ))
          && ['x', 'y', 'width', 'height', 'feetY'].every(key => near(
            record.renderBounds?.[key], carrierMetric?.renderBounds?.[key]
          ))
          && record.groundAnchor?.mode === carrierMetric?.groundAnchor?.mode
          && ['x', 'y'].every(key => near(
            record.groundAnchor?.[key], carrierMetric?.groundAnchor?.[key]
          ))
          && near(record.bodyBoundsAspect, bodyAspect)
          && near(bodyAspect, profileAspect)
          && strictProfileBindingCompatible);
      };
      const isAuthoredScaleOverrideCompatible = (bodyProfile, requiredDimensions = []) => {
        const override = bodyProfile?.authoredOverride;
        const contract = candidateVisualWorld?.authoringScalePolicy?.authoredOverrideContract;
        const changedDimensions = override?.changedDimensions;
        const allowedDimensions = new Set(Array.isArray(contract?.allowedDimensions)
          ? contract.allowedDimensions : []);
        const forbiddenStrategies = new Set(Array.isArray(contract?.forbiddenStrategies)
          ? contract.forbiddenStrategies : []);
        return Boolean(contract
          && override
          && typeof override.reason === 'string' && override.reason.trim()
          && typeof override.silhouetteStrategy === 'string' && override.silhouetteStrategy.trim()
          && !forbiddenStrategies.has(override.silhouetteStrategy)
          && Array.isArray(changedDimensions) && changedDimensions.length > 0
          && changedDimensions.every(dimension => allowedDimensions.has(dimension))
          && requiredDimensions.every(dimension => changedDimensions.includes(dimension)));
      };
      const isBodyProfileCompatible = bodyProfile => {
        const isFiniteNumber = value => typeof value === 'number' && Number.isFinite(value);
        const heightBand = candidateVisualWorld?.authoringScalePolicy?.threatRankHeightU?.[bodyProfile?.visualThreatRank];
        const centerOfMassBand = candidateVisualWorld?.authoringScalePolicy
          ?.centerOfMassHeightFromGround?.[bodyProfile?.bodyClass];
        const canonicalHeightU = Number(bodyProfile?.canonicalHeightU);
        const canonicalWidthU = Number(bodyProfile?.canonicalWidthU);
        const hasStrictSpatialContract = bodyProfile?.spatialContractId === 'actor_spatial_v1';
        const centerOfMassHeight = hasStrictSpatialContract
          ? Number(bodyProfile?.centerMassHeightFromGround)
          : 1 - Number(bodyProfile?.contactAnchors?.centerMass?.y);
        const outsideBaseline = [];
        if (!(heightBand && canonicalHeightU >= Number(heightBand.min)
          && canonicalHeightU <= Number(heightBand.max))) outsideBaseline.push('canonicalHeightU');
        if (!(centerOfMassBand && centerOfMassHeight >= Number(centerOfMassBand.min)
          && centerOfMassHeight <= Number(centerOfMassBand.max))) outsideBaseline.push('centerMass');
        const authoredOverrideCompatible = outsideBaseline.length > 0
          ? isAuthoredScaleOverrideCompatible(bodyProfile, outsideBaseline)
          : !bodyProfile?.authoredOverride || isAuthoredScaleOverrideCompatible(bodyProfile);
        const depth = bodyProfile?.depthEnvelope;
        const viewportClamp = bodyProfile?.viewportClamp;
        const fitPolicy = bodyProfile?.exchangeFitPolicy;
        const basis = bodyProfile?.authoredScaleBasis;
        const authoredBasisCompatible = ['speciesId', 'morphologyId', 'progressionStageId', 'combatRoleId']
          .every(field => typeof basis?.[field] === 'string' && basis[field].trim());
        const compound = bodyProfile?.compoundActor;
        const compoundCompatible = !compound || Boolean(
          compound.contractId === 'compound_actor_formation_v1'
          && compound.mode === 'single_combat_entity'
          && Number.isInteger(compound.memberCount) && compound.memberCount > 1
          && typeof compound.formationRootMode === 'string' && compound.formationRootMode.trim()
          && Number(compound?.formationBoundsU?.width) > 0
          && Number(compound?.formationBoundsU?.height) > 0
          && typeof compound.strikeOriginPolicy === 'string' && compound.strikeOriginPolicy.trim()
        );
        const strictSpatialCompatible = !hasStrictSpatialContract || Boolean(
          authoredBasisCompatible
          && /^[a-f0-9]{64}$/.test(String(bodyProfile?.bodyProfileContractSha256 || ''))
          && compoundCompatible
          && centerOfMassHeight > 0 && centerOfMassHeight < 1
          && near(centerOfMassHeight, 1 - Number(bodyProfile?.contactAnchors?.centerMass?.y))
          && near(bodyProfile?.authoredHeightRatio, canonicalHeightU)
          && near(bodyProfile?.authoredWidthRatio, canonicalWidthU)
          && typeof bodyProfile?.rootMode === 'string' && bodyProfile.rootMode.trim()
          && isFiniteNumber(depth?.min) && isFiniteNumber(depth?.default) && isFiniteNumber(depth?.max)
          && depth.min >= -1 && depth.max <= 1 && depth.min <= depth.default && depth.default <= depth.max
          && ['narrow', 'desktop'].every(mode => {
            const clamp = viewportClamp?.[mode];
            return isFiniteNumber(clamp?.minReadableHeightPx) && clamp.minReadableHeightPx > 0
              && isFiniteNumber(clamp?.maxRenderedHeightVh) && clamp.maxRenderedHeightVh > 0 && clamp.maxRenderedHeightVh <= 1
              && isFiniteNumber(clamp?.maxRenderedWidthVw) && clamp.maxRenderedWidthVw > 0 && clamp.maxRenderedWidthVw <= 1;
          })
          && typeof viewportClamp?.preserveThreatAxis === 'string' && viewportClamp.preserveThreatAxis.trim()
          && isFiniteNumber(fitPolicy?.maximumUniformShrinkRatio)
          && fitPolicy.maximumUniformShrinkRatio >= 0 && fitPolicy.maximumUniformShrinkRatio < 1
          && fitPolicy.preserveAuthoredAspect === true
          && typeof fitPolicy.scalePriority === 'string' && fitPolicy.scalePriority.trim()
          && Array.isArray(bodyProfile?.threatSources) && bodyProfile.threatSources.length >= 2
          && bodyProfile.threatSources.every((source, index) => typeof source?.source === 'string'
            && source.source.trim() && Number.isInteger(source.priority) && source.priority === index + 1)
          && (bodyProfile.groundingMode !== 'shadow_projection'
            || (Number(bodyProfile?.hoverContract?.coreClearanceU) > 0
              && Number(bodyProfile?.hoverContract?.lowestFragmentClearanceU) >= 0
              && Number(bodyProfile.hoverContract.lowestFragmentClearanceU)
                <= Number(bodyProfile.hoverContract.coreClearanceU)
              && bodyProfile?.hoverContract?.shadowRoot === 'centroid'))
        );
        // Strict profiles are authored per entity. Rank/body-class bands are
        // non-blocking lint references only; they cannot dictate runtime size.
        const authoredEntityDimensionsCompatible = hasStrictSpatialContract
          || Boolean(heightBand && centerOfMassBand && authoredOverrideCompatible);
        return Boolean(authoredEntityDimensionsCompatible
          && Number.isFinite(canonicalHeightU) && canonicalHeightU > 0
          && Number.isFinite(canonicalWidthU) && canonicalWidthU > 0
          && ['feet', 'rooted', 'shadow_projection'].includes(bodyProfile?.groundingMode)
          && Array.isArray(bodyProfile?.silhouetteTraits) && bodyProfile.silhouetteTraits.length >= 2
          && bodyProfile.silhouetteTraits.every(trait => typeof trait === 'string' && trait.trim())
          && typeof bodyProfile?.threatIntent === 'string' && bodyProfile.threatIntent.trim()
          && Math.abs(Number(bodyProfile?.contactAnchors?.ground?.y) - 1) <= 0.000001
          && strictSpatialCompatible
          && ['ground', 'centerMass', 'meleeLeft', 'meleeRight', 'castLeft', 'castRight']
            .every(anchor => isUnitPoint(bodyProfile?.contactAnchors?.[anchor])));
      };
      const mediaDensityContract = candidateVisualWorld?.mediaDensityContract;
      const battlefieldMediaCompatible = Boolean(
        mediaDensityContract
        && candidateBattlefieldProfile?.mediaDensity === mediaDensityContract.mediaDensity
        && Number(candidateBattlefieldProfile?.logicalPixelGrid) === Number(mediaDensityContract.logicalPixelGrid)
        && Array.isArray(candidateBattlefieldProfile?.compatibleWorldIds)
        && candidateBattlefieldProfile.compatibleWorldIds.includes(candidateVisualWorld?.id)
        && Array.isArray(mediaDensityContract?.runtimeEligibleReviewStatuses)
        && mediaDensityContract.runtimeEligibleReviewStatuses.includes(candidateBattlefieldProfile?.mediaReviewStatus)
        && !mediaDensityContract?.forbiddenMediaDensity?.includes(candidateBattlefieldProfile?.mediaDensity)
      );
      const battlefieldProfileCompatible = Boolean(
        candidateBattlefieldProfile
        && battlefieldMediaCompatible
        && candidateBattlefieldProfile.id === battlefieldProfileId
        && candidateBattlefieldProfile.sceneImage === presentation.sceneImage
        && ['narrow', 'desktop'].every(mode => {
          const horizonY = candidateBattlefieldProfile.horizonY?.[mode];
          const groundY = candidateBattlefieldProfile.groundY?.[mode];
          const crop = candidateBattlefieldProfile.crop?.[mode];
          return isPositiveUnitNumber(horizonY) && isPositiveUnitNumber(groundY)
            && horizonY < 1
            && groundY > horizonY && groundY < 1
            && crop?.fit === 'cover'
            && isUnitNumber(crop.focusX) && isUnitNumber(crop.focusY)
            && isUnitRect(candidateBattlefieldProfile.uiSafeRect?.[mode]);
        })
      );
      const requiredLayerTokens = ['background', 'grade', 'exchange', 'actors', 'labels', 'ui', 'action', 'overlay'];
      const layerTokensCompatible = requiredLayerTokens.every((layer, index) => {
        const value = candidateVisualWorld?.layerTokens?.[layer];
        const previous = index > 0 ? candidateVisualWorld?.layerTokens?.[requiredLayerTokens[index - 1]] : -Infinity;
        return Number.isInteger(value) && value > previous;
      });
      const depthProjectionCompatible = Number(candidateVisualWorld?.layout?.depthProjection?.groundShiftPerBodyHeight) > 0
        && Number(candidateVisualWorld?.layout?.depthProjection?.scalePerDepth) > 0
        && Number(candidateVisualWorld?.layout?.depthProjection?.zDepthThresholds?.farMax) < 0
        && Number(candidateVisualWorld?.layout?.depthProjection?.zDepthThresholds?.nearMin) > 0
        && ['far', 'mid', 'near'].every((band, index, bands) => {
          const offset = candidateVisualWorld?.layout?.depthProjection?.zIndexOffsets?.[band];
          const previous = index > 0
            ? candidateVisualWorld?.layout?.depthProjection?.zIndexOffsets?.[bands[index - 1]] : -1;
          return Number.isInteger(offset) && offset >= 0 && offset > previous;
        })
        && Number(candidateVisualWorld?.layerTokens?.actors)
          + Number(candidateVisualWorld?.layout?.depthProjection?.zIndexOffsets?.near)
          < Number(candidateVisualWorld?.layerTokens?.labels);
      const requiredScaleProfileIds = [actorCards.player?.scaleProfileId, actorCards.enemy?.scaleProfileId]
        .filter(value => typeof value === 'string' && value.trim())
        .map(value => value.trim());
      const actorScaleProfilesCompatible = requiredScaleProfileIds.length === 2
        && ['player', 'enemy'].every(side => {
           const profileId = actorCards[side]?.scaleProfileId;
           const bodyProfile = candidateVisualWorld?.actorBodyProfiles?.[profileId];
           const requestedCarrierPath = normaliseVisualPath(actorCards[side]?.image);
           // A reviewed world is a binding for the exact actor image selected
           // by the production path/encounter contract.  An absent image may
           // not borrow the profile's default carrier (a pattern that existed
           // only in isolated tests), because that can make a different path
           // or pose appear measured when no runtime asset was requested.
           const requestedCarrierPresent = requestedCarrierPath.length > 0;
           const carrierEntry = Object.entries(candidateVisualWorld?.carrierMetrics || {}).find(([, metric]) =>
             metric?.bodyProfileId === profileId
               && normaliseVisualPath(metric?.assetPath) === requestedCarrierPath);
          const carrierMetricId = carrierEntry?.[0];
          const carrierMetric = carrierEntry?.[1];
          const bodyBounds = carrierMetric?.bodyBounds;
          const renderBounds = carrierMetric?.renderBounds;
          const groundingMode = carrierMetric?.groundAnchor?.mode;
          const groundingCompatible = (groundingMode === 'feet'
            && bodyProfile?.groundingMode === 'feet'
            && Math.abs(Number(carrierMetric?.groundAnchor?.y) - Number(renderBounds?.feetY)) <= 0.000001)
            || (groundingMode === 'rooted'
              && bodyProfile?.groundingMode === 'rooted'
              && Math.abs(Number(carrierMetric?.groundAnchor?.y) - Number(renderBounds?.feetY)) <= 0.000001)
            || (groundingMode === 'shadow_projection'
              && bodyProfile?.groundingMode === 'shadow_projection'
              && Number(carrierMetric?.groundAnchor?.y) >= Number(renderBounds?.feetY));
           return Boolean(requestedCarrierPresent
             && isBodyProfileCompatible(bodyProfile)
             && carrierMetric
            && carrierMetric.bodyProfileId === profileId
            && isUnitRect(bodyBounds)
            && isUnitRect(renderBounds)
            && isUnitNumber(renderBounds.feetY)
            && isUnitPoint(carrierMetric.groundAnchor)
            && carrierMetric.bodyBoundsPolicy === 'authored_anatomy_excludes_weapon_vfx'
            && carrierMetric.renderBoundsPolicy === 'measured_alpha_content'
            && Number(carrierMetric.naturalWidth) > 0
            && Number(carrierMetric.naturalHeight) > 0
            && bodyBounds.x >= renderBounds.x - 0.000001
            && bodyBounds.y >= renderBounds.y - 0.000001
            && bodyBounds.x + bodyBounds.width <= renderBounds.x + renderBounds.width + 0.000001
            && bodyBounds.y + bodyBounds.height <= renderBounds.y + renderBounds.height + 0.000001
            && groundingCompatible
            && isCarrierScaleBindingCompatible(carrierMetric, bodyProfile, profileId, carrierMetricId));
        });
      const encounterCompositionCompatible = Boolean(
        candidateEncounterComposition
        && candidateEncounterComposition.id === encounterCompositionId
        && candidateEncounterComposition.battlefieldProfileId === battlefieldProfileId
        && (!candidateEncounterComposition.requiresActorSpatialContract
          || ['player', 'enemy'].every(side => candidateVisualWorld?.actorBodyProfiles?.[
            actorCards?.[side]?.scaleProfileId
          ]?.spatialContractId === 'actor_spatial_v1'))
        && ['player', 'enemy'].every(side => {
          const placement = candidateEncounterComposition.actors?.[side];
          const expectedProfileId = actorCards[side]?.scaleProfileId;
          const depth = placement?.depth;
          return this._resolvePlacementBodyProfileId(
            side,
            placement,
            playerPath,
            actorCards?.[side] || null
          ) === expectedProfileId
            && typeof depth === 'number' && Number.isFinite(depth) && depth >= -1 && depth <= 1
            && ['narrow', 'desktop'].every(mode => {
              const laneX = placement?.laneX?.[mode];
              return typeof laneX === 'number' && laneX > 0 && laneX < 1;
            });
        })
      );
      const compoundRequirement = candidateEncounterComposition?.requiresCompoundActor;
      const compoundActorCompatible = !compoundRequirement || Boolean(
        ['player', 'enemy'].includes(compoundRequirement.side)
        && compoundRequirement.contractId === 'compound_actor_formation_v1'
        && candidateVisualWorld?.actorBodyProfiles?.[
          actorCards?.[compoundRequirement.side]?.scaleProfileId
        ]?.compoundActor?.contractId === compoundRequirement.contractId
        && candidateVisualWorld.actorBodyProfiles[
          actorCards[compoundRequirement.side].scaleProfileId
        ].compoundActor.mode === 'single_combat_entity'
      );
      const runtimeEligibleReviewStatuses = Array.isArray(mediaDensityContract?.runtimeEligibleReviewStatuses)
        ? mediaDensityContract.runtimeEligibleReviewStatuses
        : [];
      const finalArtEligibleReviewStatuses = Array.isArray(mediaDensityContract?.finalArtEligibleReviewStatuses)
        ? mediaDensityContract.finalArtEligibleReviewStatuses
        : [];
      const isWorldCandidateMediaCompatible = media => Boolean(
        media
        && media.visualWorldId === candidateVisualWorld?.id
        && media.mediaDensity === mediaDensityContract?.mediaDensity
        && Number(media.logicalPixelGrid) === Number(mediaDensityContract?.logicalPixelGrid)
        && runtimeEligibleReviewStatuses.includes(media.reviewStatus)
        // Candidate media remains eligible for in-place review, while an
        // independently approved asset must remain eligible after promotion.
        // A bare finalArtApproved flag is insufficient: it has to be paired
        // with a review status reserved for final visual approval. Rejected or
        // unknown statuses therefore continue to fail closed.
        && (media.finalArtApproved === false
          || (media.finalArtApproved === true
            && finalArtEligibleReviewStatuses.includes(media.reviewStatus)))
      );
      const requiredUiSurfaceIds = [
        'action_button_frame',
        'divider_joinery',
        'hand_card_frame',
        'hand_tray_frame',
        'health_slot_frame',
        'intent_tag_body_9slice',
        'intent_tag_notch',
        'qi_slot_frame',
        'resource_socket_frame',
        'status_ledger_panel'
      ];
      const uiMaterial = candidateVisualWorld?.uiMaterial;
      const uiMaterialCompatible = Boolean(
        isWorldCandidateMediaCompatible(uiMaterial)
        && typeof uiMaterial?.id === 'string' && uiMaterial.id.trim()
        && typeof uiMaterial?.provenanceManifest === 'string'
        && uiMaterial.provenanceManifest.endsWith('/manifest.json')
        && requiredUiSurfaceIds.every(surfaceId => {
          const surface = uiMaterial?.surfaces?.[surfaceId];
          return isWorldCandidateMediaCompatible(surface)
            && surface.id === surfaceId
            && typeof surface.path === 'string' && surface.path.endsWith('.png')
            && /^[a-f0-9]{64}$/.test(String(surface.sha256 || ''))
            && Number(surface.width) > 0 && Number(surface.height) > 0
            && typeof surface.cssVariable === 'string'
            && surface.cssVariable.startsWith('--world-ui-')
            && Array.isArray(surface.consumerSelectors)
            && surface.consumerSelectors.length > 0;
        })
      );
      const contactShadowCompatible = Boolean(
        isWorldCandidateMediaCompatible(candidateVisualWorld?.contactShadow)
        && candidateVisualWorld.contactShadow.renderMode === 'hard_cluster_polygon'
        && candidateVisualWorld.contactShadow.forbiddenRenderer === 'radial_gradient_or_blur'
        && typeof candidateVisualWorld.contactShadow.color === 'string'
        && candidateVisualWorld.contactShadow.color.trim()
      );
      const runtimeLighting = candidateVisualWorld?.lighting?.runtimeComposite;
      const lightingCompatible = Boolean(
        runtimeLighting?.id
        && typeof runtimeLighting.actorFilter === 'string'
        && runtimeLighting.actorFilter.trim()
        && !runtimeLighting.actorFilter.includes('drop-shadow')
        && runtimeLighting.sideSpecificFiltersForbidden === true
        && ['player_static', 'player_action', 'enemy_static', 'enemy_action']
          .every(consumer => runtimeLighting.actorConsumers?.includes(consumer))
      );
      const requiredWorldVfx = {
        fx_damage_contact_agc_u1: 'damage',
        fx_shield_ward_agc_u1: 'shield',
        fx_weak_sag_agc_u1: 'weak',
        fx_pill_projectile_agc_u1: 'pill_projectile',
        fx_pill_impact_agc_u1: 'pill_impact'
      };
      const vfxRegistryCompatible = Boolean(
        candidateVisualWorld?.vfxPolicy?.rendererAuthority === 'deck_combat_ui_vfx_router_v1'
        && candidateVisualWorld?.vfxPolicy?.primaryCarrierRule
          === 'one_authored_sprite_or_one_world_fallback_per_vfx_event'
        && Object.entries(requiredWorldVfx).every(([assetId, semantic]) => {
          const asset = candidateVisualWorld?.vfxAssets?.[assetId];
          return isWorldCandidateMediaCompatible(asset)
            && asset.id === assetId
            && asset.semantic === semantic
            && asset.paletteSource === candidateVisualWorld?.vfxPolicy?.source
            && typeof asset.provenanceManifest === 'string'
            && asset.provenanceManifest.endsWith('/manifest.json')
            && Array.isArray(asset.frames) && asset.frames.length === 4
            && asset.frames.every((frame, index) => frame?.frameIndex === index
              && typeof frame.path === 'string' && frame.path.endsWith('.png')
              && /^[a-f0-9]{64}$/.test(String(frame.sha256 || ''))
              && Number(frame.width) > 0 && Number(frame.height) > 0);
        })
      );
      const visualWorldCompatible = Boolean(
        encounterVisualWorldId
        && pathVisualWorldId
        && encounterVisualWorldId === pathVisualWorldId
        && candidateVisualWorld
        && layerTokensCompatible
        && depthProjectionCompatible
        && scaleProvenanceCompatible
        && actorScaleProfilesCompatible
        && battlefieldProfileCompatible
        && encounterCompositionCompatible
        && compoundActorCompatible
        && uiMaterialCompatible
        && contactShadowCompatible
        && lightingCompatible
        && vfxRegistryCompatible
      );
      const visualWorldId = visualWorldCompatible ? encounterVisualWorldId : null;
      const visualWorld = visualWorldId
        ? JSON.parse(JSON.stringify(this._visualWorldData.worlds[visualWorldId]))
        : null;
      if (visualWorld) {
        visualWorld.carrierScaleBindings = JSON.parse(JSON.stringify(this._carrierScaleProvenance.records));
        visualWorld.actionScaleBindings = JSON.parse(JSON.stringify(this._actionScaleProvenance.records));
      }
      const intrinsicCardArt = {};
      for (const [cardId, cardDef] of Object.entries(this.cardDB || {})) {
          if (cardDef?.cardArt?.image) intrinsicCardArt[cardId] = cardDef.cardArt;
      }
      const equipmentCardArt = {};
      const cardProvenance = {};
      for (const item of equippedTreasures) {
          if (!item?.tacticalCardId) continue;
          if (item.cardArt?.image) equipmentCardArt[item.tacticalCardId] = item.cardArt;
          cardProvenance[item.tacticalCardId] = {
              source: item.name,
              rarity: '器契',
              role: item.slot === 'weapon' ? '器攻' : '器护',
              treasureId: item.treasureId,
              displayName: item.displayName || item.name,
              description: item.cardDescription || '',
              effectBonuses: {
                  damage: Math.max(0, Number(item.combatBonuses?.atk) || 0),
                  block: Math.max(0, Number(item.combatBonuses?.def) || 0)
              }
          };
      }
      const companionContracts = Array.isArray(this._companionCombatContracts)
        ? this._companionCombatContracts
        : [];
      const companionRoles = {
          bai_luoxuan: '月愈',
          jian_linger: '合璧',
          yin_xue: '血剑',
          bai_ren: '点锋',
          mu_qinglan: '天书',
          jiuwei_suyue: '幻域',
          tianji_laoren: '命星',
          xuesha_laozu: '煞域'
      };
      const companionCardArt = {};
      for (const contract of companionContracts) {
          if (!contract?.cardId) continue;
          if (contract.cardArt?.image) companionCardArt[contract.cardId] = contract.cardArt;
          cardProvenance[contract.cardId] = {
              source: contract.companionName || contract.compId,
              rarity: contract.tierId === 'bond_100' ? '天命羁绊' : '道侣羁绊',
              role: companionRoles[contract.compId] || '羁绊',
              companionId: contract.compId,
              affection: contract.affection,
              displayName: contract.unlockText || contract.companionName || contract.compId,
              description: contract.mechanism || ''
          };
      }
      const cardArt = {
          ...intrinsicCardArt,
          ...(presentation.cardArt || {}),
          ...(pathContract?.cardArt || {}),
          ...equipmentCardArt,
          ...companionCardArt
      };
      const tier = enemy.tier || 1;
      const tierLabels = { 1: '普通', 2: '精英', 3: '首领' };
      const difficultyLabel = presentation.difficultyLabel
        || (this.bossPhases.length ? '首领' : tierLabels[tier] || '普通');
      const actionPresentationId = String(
        card.actionPresentationId || presentation.actionPresentationId || ''
      );
      const presentationId = String(presentation.presentationId || '');
      const isBoss = Boolean(
        this.bossPhases.length
        || Number(tier) >= 3
        || /首领/.test(String(difficultyLabel))
        || /^enc_boss(?:_|$)/.test(actionPresentationId)
        || /^combat_enc_boss(?:_|$)/.test(presentationId)
      );
      const displayedVisualStageId = pathContract?.displayedVisualStageId || null;
      const encounterActionSet = this._actionPresentationData?.encounters?.[this._encounterActionId()] || {};
      const bossPhaseTransition = this._getBossPhaseTransitionDefinition();
      const actionAnimations = [
        ...this._collectPlayerStagePreloadAnimations(playerPath, displayedVisualStageId),
        ...this._collectEncounterActionAnimations(encounterActionSet),
        ...(bossPhaseTransition?.animation ? [bossPhaseTransition.animation] : [])
      ]
        .filter(animation => animation?.kind === 'frame_sequence'
          && animation.motionApproved === true
          && Array.isArray(animation.frames));
      const enemyDef = this.enemy && this.enemy.def;
      const firstIntent = enemyDef && Array.isArray(enemyDef.intents)
        ? enemyDef.intents.find(intent => !intent.condition)
        : null;
      return {
          encounterInstanceId: this.encounterContext?.encounterInstanceId || null,
          cardId: card.id || null,
          presentationId: presentation.presentationId || null,
          battlefieldId: presentation.battlefieldId || null,
          title: card.title || enemy.name || '战局展开',
          sceneImage: presentation.sceneImage || card.sceneImage || null,
          enemyImage: presentation.actorCards?.enemy?.image || presentation.enemyImage || enemy.image || null,
          playerPath,
          pathContractId: this._pathPresentationData?.contractId || null,
          visualWorldContractId: this._visualWorldData?.contractId || null,
          // Only the encounter can opt its scene into a reviewed world. A
          // player's path may also be used in legacy encounters (white-fox
          // hounds, quest battles); its world ID must not reject their art.
          // Explicit encounter requests remain intact when validation fails.
          requestedVisualWorldId: encounterVisualWorldId || null,
          visualWorldId,
          visualWorldCompatible,
          battlefieldMediaCompatible,
          battlefieldProfileId: visualWorldCompatible ? battlefieldProfileId : null,
          encounterCompositionId: visualWorldCompatible ? encounterCompositionId : null,
          visualWorldIncompatibility: visualWorldCompatible
            ? null
            : {
                encounterVisualWorldId: encounterVisualWorldId || null,
                pathVisualWorldId: pathVisualWorldId || null,
                actorScaleProfileIds: requiredScaleProfileIds,
                actorScaleProfilesCompatible,
                layerTokensCompatible,
                depthProjectionCompatible,
                battlefieldProfileId: battlefieldProfileId || null,
                battlefieldMediaCompatible,
                battlefieldProfileCompatible,
                encounterCompositionId: encounterCompositionId || null,
                encounterCompositionCompatible,
                compoundActorCompatible,
                uiMaterialCompatible,
                contactShadowCompatible,
                lightingCompatible,
                vfxRegistryCompatible
              },
          visualWorld,
          protagonistIdentityId: pathContract?.identityAnchorId || null,
          requestedVisualStageId: pathContract?.requestedVisualStageId || null,
          displayedVisualStageId: pathContract?.displayedVisualStageId || null,
          visualStageFallback: Boolean(pathContract?.visualStageFallback),
          visualStageAssetStatus: pathContract?.visualStageAssetStatus || null,
          uiTheme: pathContract?.uiTheme || null,
          signatureCardIds: pathContract?.signatureCardIds || [],
          actorCards,
          cardArt,
          cardProvenance,
          equippedTreasures,
          companionContracts,
          actionAnimations: JSON.parse(JSON.stringify(actionAnimations)),
          bossPhaseTransition: bossPhaseTransition ? JSON.parse(JSON.stringify(bossPhaseTransition)) : null,
          vfx: presentation.vfx || null,
          battlefield: presentation.battlefield || card.battlefield || enemy.battlefield || 'default',
          enemyType: presentation.enemyType || enemy.type || '敌手',
          difficultyLabel,
          isBoss,
          mechanic: presentation.mechanic || enemy.mechanic || (firstIntent && firstIntent.desc) || '观察敌人的行动规律'
      };
  }

  /**
   * 四流派战斗展示与功法池的唯一读取入口。
   * @param {string} pathId
   * @returns {Object|null}
   */
  /**
   * Resolves the only presentation authority for a protagonist identity.
   *
   * Combat callers omit visualStageId and resolve from the canonical realm.
   * Narrative callers may explicitly request an authored non-combat stage
   * (currently the reincarnation-only S0 memory), without inventing a realm
   * that does not exist in the GameState realm machine.
   */
  _ensurePathPresentationAuthority() {
      if (!this._pathPresentationData?.paths || Object.keys(this._pathPresentationData.paths).length === 0) {
        const authoritativePathPresentations = typeof dataLoader !== 'undefined'
          && dataLoader && typeof dataLoader.loadSync === 'function'
          ? dataLoader.loadSync('combat:path_presentations')
          : null;
        this._pathPresentationData = authoritativePathPresentations?.paths
          ? JSON.parse(JSON.stringify(authoritativePathPresentations))
          : { paths: {} };
      }
      if (!this._protagonistVisualIdentity) {
        const authoritativeIdentity = typeof dataLoader !== 'undefined'
          && dataLoader && typeof dataLoader.loadSync === 'function'
          ? dataLoader.loadSync('combat:protagonist_visual_identity')
          : null;
        this._protagonistVisualIdentity = authoritativeIdentity?.contractId === 'protagonist_yelingyun_visual_identity_v1'
          ? JSON.parse(JSON.stringify(authoritativeIdentity))
          : null;
      }
      return Boolean(this._pathPresentationData?.paths && Object.keys(this._pathPresentationData.paths).length > 0);
  }

  getProtagonistIdentityContract({ pathId = null, visualStageId = null } = {}) {
      this._ensurePathPresentationAuthority();
      const resolvedPath = pathId || ((typeof gameState !== 'undefined' && gameState) ? gameState.path : null) || 'sword';
      const pathContract = this._pathPresentationData?.paths?.[resolvedPath];
      if (!pathContract) return null;
      const realm = ((typeof gameState !== 'undefined' && gameState?.realm) || 'qi');
      const requestedStageId = visualStageId
        || this._pathPresentationData?.realmStageMap?.[realm]
        || this._pathPresentationData?.fallbackStageId
        || 'S1_outer_novice';
      const requestedStage = this._pathPresentationData?.growthStages?.[requestedStageId] || null;
      const fallbackStageId = this._pathPresentationData?.fallbackStageId || 'S1_outer_novice';
      const fallbackStage = this._pathPresentationData?.growthStages?.[fallbackStageId] || null;
      // Batch C owns a concrete actor for every (stage, path) pair. The
      // stage-level actor remains only a compatibility fallback, never the
      // preferred label-only substitute for a path identity variant.
      const requestedActor = requestedStage?.pathVariants?.[resolvedPath]?.actorCard
        || requestedStage?.actorCard
        || null;
      const fallbackActor = fallbackStage?.pathVariants?.[resolvedPath]?.actorCard
        || fallbackStage?.actorCard
        || null;
      const displayedActor = requestedActor?.image ? requestedActor : fallbackActor;
      const displayedStageId = requestedActor?.image ? requestedStageId : fallbackStageId;
      if (!displayedActor) return null;
      return {
        actorCard: {
          // Stage metadata owns age and silhouette; a path variant only
          // replaces the transparent carrier and its method cue.
          ...(requestedStage?.actorCard || fallbackStage?.actorCard || {}),
          ...displayedActor,
          ageBand: displayedActor.ageBand || requestedStage?.actorCard?.ageBand || fallbackStage?.actorCard?.ageBand || null,
          name: this._protagonistVisualIdentity?.identity?.name || displayedActor.name || '叶凌云',
          kicker: `${requestedStage?.label || fallbackStage?.label || '炼气·外门'} · ${pathContract.pathLabel || resolvedPath}`,
          requestedVisualStageId: requestedStageId,
          displayedVisualStageId: displayedStageId,
          pathVariantId: displayedActor.pathVariantId || pathContract.pathVariantId || null,
          // Body scale belongs to the visual-world composition, not to a CSS
          // default. Stage/path variants may override it as the protagonist
          // grows; the S1 path actor supplies the measured baseline today.
          scaleProfileId: displayedActor.scaleProfileId || pathContract.actorCard?.scaleProfileId || null
        },
        identityAnchorId: this._pathPresentationData?.identityContractId || pathContract.identityAnchorId || null,
        requestedVisualStageId: requestedStageId,
        displayedVisualStageId: displayedStageId,
        visualStageFallback: requestedStageId !== displayedStageId,
        visualStageAssetStatus: requestedStage?.assetStatus || fallbackStage?.assetStatus || null
      };
  }

  getPathContract(pathId = null) {
      this._ensurePathPresentationAuthority();
      const resolvedPath = pathId || ((typeof gameState !== 'undefined' && gameState) ? gameState.path : null) || 'sword';
      const pathContract = this._pathPresentationData?.paths?.[resolvedPath];
      if (!pathContract) return null;
      const identity = this.getProtagonistIdentityContract({ pathId: resolvedPath });
      return {
          ...pathContract,
          actorCard: identity?.actorCard || pathContract.actorCard || null,
          identityAnchorId: identity?.identityAnchorId || this._pathPresentationData?.identityContractId || pathContract.identityAnchorId || null,
          requestedVisualStageId: identity?.requestedVisualStageId || null,
          displayedVisualStageId: identity?.displayedVisualStageId || null,
          visualStageFallback: Boolean(identity?.visualStageFallback),
          visualStageAssetStatus: identity?.visualStageAssetStatus || null
      };
  }

  _encounterActionId() {
      // Chapter milestones deliberately use stable progression card ids (ch_*),
      // while encounter actions use their own visual/action registry ids.  A
      // Boss must name that mapping explicitly; guessing from a scene or a
      // display label makes its attack presentation silently disappear.
      const cardId = String(
        this.originalCard?.actionPresentationId
        || this.originalCard?.combatPresentation?.actionPresentationId
        || this.originalCard?.id
        || this.originalCard?.encounterId
        || 'unknown'
      );
      return cardId.replace(/^encounter_card_/, '');
  }

  _isPlayerActionAnimationCompatible(animation, displayedVisualStageId) {
      if (animation?.kind !== 'frame_sequence' || animation.motionApproved !== true) return false;
      if (!displayedVisualStageId || !Array.isArray(animation.compatibleStageIds)) return false;
      return animation.compatibleStageIds.includes(displayedVisualStageId);
  }

  _buildCurrentStageStaticAnimation(pathContract, rejectedAnimation, fallbackReason) {
      const visualStageId = pathContract?.displayedVisualStageId || null;
      return {
          kind: 'static_actor_frame',
          source: 'current_stage_actor_card',
          identityId: pathContract?.identityAnchorId || rejectedAnimation?.identityId || null,
          visualStageId,
          compatibleStageIds: visualStageId ? [visualStageId] : [],
          motionApproved: false,
          fallbackReason,
          rejectedFrameSetId: rejectedAnimation?.frameSetId || null
      };
  }

  _resolveSemanticActionContract({ actionFamily, source, sourceId = null, terminal = false }) {
      const registry = this._actionPresentationData || {};
      const pathId = ((typeof gameState !== 'undefined' && gameState?.path) || 'sword');
      const resolvedSourceId = sourceId ? String(sourceId) : null;
      // A battle-card choice may author one execution carrier without
      // splitting combat authority.  The card still resolves through the
      // normal action family, cost, effect and target pipeline below; this
      // registry only changes the presentation contract selected for that
      // already-accepted source card.
      const cardAction = source !== 'enemy' && !terminal && resolvedSourceId
        ? registry.cardActions?.[resolvedSourceId]
        : null;
      const cardActionMatches = cardAction?.sourceCardId === resolvedSourceId
        && cardAction?.actionFamily === actionFamily;
      const baseAction = cardActionMatches
        ? cardAction
        : (source === 'enemy'
          ? registry.encounters?.[this._encounterActionId()]?.[actionFamily]
          : (terminal
            ? registry.terminalPlayerActions?.[pathId]?.[actionFamily]
            : registry.paths?.[pathId]?.[actionFamily]));
      const variantMap = baseAction?.variantsBySourceId;
      const authoredVariant = resolvedSourceId
        && variantMap
        && typeof variantMap === 'object'
        && !Array.isArray(variantMap)
        && Object.prototype.hasOwnProperty.call(variantMap, resolvedSourceId)
        && variantMap[resolvedSourceId]
        && typeof variantMap[resolvedSourceId] === 'object'
        && !Array.isArray(variantMap[resolvedSourceId])
        ? variantMap[resolvedSourceId]
        : null;
      const action = authoredVariant
        ? {
            ...baseAction,
            ...authoredVariant,
            ...(baseAction?.stage || authoredVariant.stage
              ? { stage: { ...(baseAction?.stage || {}), ...(authoredVariant.stage || {}) } }
              : {}),
            ...(baseAction?.presentation || authoredVariant.presentation
              ? { presentation: { ...(baseAction?.presentation || {}), ...(authoredVariant.presentation || {}) } }
              : {})
          }
        : baseAction;
      if (!action?.timelineId || !action?.sfxCueId) return null;
      const timeline = registry.timelines?.[action.timelineId];
      const sfxCue = registry.sfxCues?.[action.sfxCueId];
      if (!timeline || !sfxCue) return null;
      const pathContract = source === 'enemy' ? null : this.getPathContract(pathId);
      const displayedVisualStageId = pathContract?.displayedVisualStageId || null;
      const stageAnimation = source !== 'enemy' && displayedVisualStageId
        ? action.stageAnimations?.[displayedVisualStageId]
        : null;
      const selectedAnimation = stageAnimation || action.animation || null;
      const rejectedAnimation = selectedAnimation ? JSON.parse(JSON.stringify(selectedAnimation)) : null;
      let animation = rejectedAnimation;
      if (source !== 'enemy' && rejectedAnimation?.kind === 'frame_sequence'
        && rejectedAnimation.motionApproved === true) {
          const hasCompatibilityContract = Array.isArray(rejectedAnimation.compatibleStageIds)
            && rejectedAnimation.compatibleStageIds.length > 0;
          const fallbackReason = !hasCompatibilityContract
            ? 'missing_compatible_stage_contract'
            : (!displayedVisualStageId
              ? 'missing_displayed_visual_stage'
              : (!this._isPlayerActionAnimationCompatible(rejectedAnimation, displayedVisualStageId)
                ? 'incompatible_visual_stage'
                : null));
          if (fallbackReason) {
              // Previously a stage mismatch downgraded the player's action to a
              // static actor frame — which removed every frame and left only the
              // is-semantic-action-active flash (the reported "角色只闪一下").
              // Instead fall back to the baseline approved frame_sequence so the
              // character always performs its motion; stage-specific variants are
              // a refinement, never a hard gate on whether the body animates.
              animation = {
                  ...rejectedAnimation,
                  displayedVisualStageId: null,
                  stageFallback: true,
                  fallbackReason
              };
          } else {
              animation = {
                  ...rejectedAnimation,
                  displayedVisualStageId
              };
          }
      } else if (source !== 'enemy' && animation) {
          animation = {
              ...animation,
              visualStageId: animation.visualStageId || displayedVisualStageId,
              displayedVisualStageId
          };
      }
       const duration = Math.max(1, Number(timeline.duration) || 1);
       const rawStage = action.stage || registry.stageContracts?.[actionFamily] || registry.stageContracts?.default || null;
       const stage = rawStage ? {
           contact: ['melee', 'projectile', 'self'].includes(rawStage.contact) ? rawStage.contact : 'self',
           impactAtMs: Math.min(duration, Math.max(0, Number(rawStage.impactAtMs) || 0))
       } : null;
       if (stage && ['hold', 'advance'].includes(rawStage.approach)) {
           stage.approach = rawStage.approach;
       }
       if (stage && Number(rawStage.contactSettleU) > 0 && Number(rawStage.contactSettleU) <= 0.4) {
           stage.contactSettleU = Number(rawStage.contactSettleU);
       }
       if (stage && rawStage.releaseAtMs !== undefined && rawStage.releaseAtMs !== null) {
           stage.releaseAtMs = Math.min(
             stage.impactAtMs,
             Math.max(0, Number(rawStage.releaseAtMs) || 0)
           );
       }
       const stagePresentation = source !== 'enemy' && displayedVisualStageId
         ? action.stagePresentations?.[displayedVisualStageId]
         : null;
       const selectedPresentation = stagePresentation || action.presentation || null;
       const presentation = selectedPresentation && typeof selectedPresentation === 'object'
         ? JSON.parse(JSON.stringify(selectedPresentation))
         : null;
       return {
           presentationId: action.timelineId,
           duration,
          reducedMotionFallback: action.reducedMotionFallback || 'static_actor_frame_with_semantic_impact',
          timelineId: action.timelineId,
          sfxCueId: action.sfxCueId,
          sfxCue: { ...sfxCue },
          displayedVisualStageId,
            animation,
            stage,
            presentation
       };
  }

  // A battle card may carry several effects at once, so the presentation
  // family follows a fixed semantic priority rather than the single test
  // "does it mention block".  Ordering matters: a card that both mends and
  // guards must present the mend, otherwise healing cards used to mount the
  // defensive action sequence and read as a block to the player.
  _deriveCardSemanticPresentation(card) {
      const effects = Array.isArray(card?.effects) ? card.effects : [];
      const has = (type) => effects.some(effect => effect?.type === type);
      // Backlash resolves against the player who cast it, so it presents as
      // an offensive channel that recoils rather than as a self-buff.
      const offensive = has('damage') || has('backlash');
      if (has('damage') && card?.type === 'attack') {
          return { actionFamily: 'attack', target: 'enemy' };
      }
      if (offensive) {
          return { actionFamily: 'skill', target: 'enemy' };
      }
      if (has('heal')) {
          return { actionFamily: 'skill', target: 'player' };
      }
      if (has('block')) {
          return { actionFamily: 'guard', target: 'player' };
      }
      return { actionFamily: 'skill', target: 'player' };
  }

  _beginSemanticAction({ actionFamily, source, target, sourceId = null }) {
      if (this._activeSemanticAction) this._completeSemanticAction({ interrupted: true });
      const contract = this._resolveSemanticActionContract({ actionFamily, source, sourceId });
      if (!contract) return null;
      const owner = String(this.encounterContext?.encounterInstanceId || this._encounterActionId()).replace(/[^a-zA-Z0-9:_-]/g, '_');
      this._semanticActionSequence += 1;
      this._activeSemanticAction = {
          actionId: `combat-action:${owner}:${Math.max(1, Number(this.turn) || 1)}:${this._semanticActionSequence}`,
          actionFamily,
          source,
          target,
          sourceId: sourceId ? String(sourceId) : null,
          ...contract,
          emittedPhases: new Set()
      };
      this._emitSemanticActionPhase('combat:actionStarted');
      this._reserveSerializedPresentationWindow(this._activeSemanticAction);
      return this._activeSemanticAction.actionId;
  }

  _emitPlayerPresentationAction(actionFamily, {
      target = 'player',
      sourceId = null,
      terminal = false,
      originActionId = null
  } = {}) {
      const contract = this._resolveSemanticActionContract({ actionFamily, source: 'player', sourceId, terminal });
      // Static fallbacks still have a useful semantic event for the UI, but
      // only an approved frame sequence receives a timed visual lifecycle.
      if (!contract) return null;
      const owner = String(this.encounterContext?.encounterInstanceId || this._encounterActionId())
        .replace(/[^a-zA-Z0-9:_-]/g, '_');
      this._presentationActionSequence += 1;
      const payload = {
        actionId: `combat-presentation:${owner}:${Math.max(1, Number(this.turn) || 1)}:${this._presentationActionSequence}`,
        actionFamily,
          source: 'player',
          target,
          sourceId: sourceId ? String(sourceId) : null,
          originActionId: originActionId ? String(originActionId) : null,
          presentationOnly: true,
          // The renderer must distinguish a terminal pose from an ordinary
          // presentation-only reaction.  Combat is already closed here, so a
          // stale reaction chooser must never cover the authored outcome.
          terminal: terminal === true,
          ...contract
      };
      eventBus.emit('combat:actionStarted', payload);
      this._emitActionPresentationCues(payload);
      this._reserveSerializedPresentationWindow(payload);
      let timer = null;
      timer = this._schedule(() => {
        if (timer !== null) this._presentationActionTimers.delete(timer);
        eventBus.emit('combat:actionCompleted', { ...payload, presentationOnly: true });
      }, Math.max(1, Number(contract.duration) || 1));
      if (timer !== null) this._presentationActionTimers.add(timer);
      return payload;
  }

  _emitEnemyPresentationAction(actionFamily, {
      target = 'enemy',
      sourceId = null,
      originActionId = null
  } = {}) {
      const contract = this._resolveSemanticActionContract({ actionFamily, source: 'enemy' });
      // A missing optional enemy sequence must not block combat.  The same
      // semantic impact, numeric feedback and victory state remain visible.
      if (!contract) return null;
      const owner = String(this.encounterContext?.encounterInstanceId || this._encounterActionId())
        .replace(/[^a-zA-Z0-9:_-]/g, '_');
      this._presentationActionSequence += 1;
      const payload = {
        actionId: `combat-presentation:${owner}:${Math.max(1, Number(this.turn) || 1)}:${this._presentationActionSequence}`,
        actionFamily,
        source: 'enemy',
        target,
        sourceId: sourceId ? String(sourceId) : null,
        originActionId: originActionId ? String(originActionId) : null,
        presentationOnly: true,
        terminal: false,
        // Defeat closes this actor's body state without closing the whole
        // combat presentation.  The UI keeps the authored final frame on the
        // actor's measured ground root while the opposing victory action runs.
        terminalActorState: actionFamily === 'defeat',
        ...contract
      };
      eventBus.emit('combat:actionStarted', payload);
      this._emitActionPresentationCues(payload);
      this._reserveSerializedPresentationWindow(payload);
      let timer = null;
      timer = this._schedule(() => {
        if (timer !== null) this._presentationActionTimers.delete(timer);
        eventBus.emit('combat:actionCompleted', { ...payload, presentationOnly: true });
      }, Math.max(1, Number(contract.duration) || 1));
      if (timer !== null) this._presentationActionTimers.add(timer);
      return payload;
  }

  _clearPresentationActionTimers() {
      for (const timer of this._presentationActionTimers || []) this._cancelSchedule(timer);
      this._presentationActionTimers?.clear();
  }

  _scheduleVictorySettlement(handler, duration = 0) {
      this._clearVictorySettlement();
      const delay = Math.max(0, Number(duration) || 0);
      if (delay <= 0) {
          handler();
          return false;
      }
      const token = this._victorySettlementToken;
      this._victorySettlementTimer = this._schedule(() => {
          if (this._victorySettlementToken !== token) return;
          this._victorySettlementTimer = null;
          handler();
      }, delay);
      return true;
  }

  _clearVictorySettlement() {
      if (this._victorySettlementTimer !== null && this._victorySettlementTimer !== undefined) {
          this._cancelSchedule(this._victorySettlementTimer);
      }
      this._victorySettlementTimer = null;
      this._victorySettlementToken = (Number(this._victorySettlementToken) || 0) + 1;
  }

  _scheduleTerminalCombatHide(duration) {
      this._clearTerminalCombatHide();
      const token = this._terminalHideToken;
      const delay = Math.max(1, Number(duration) || 1);
      this._terminalHideTimer = this._schedule(() => {
          if (this._terminalHideToken !== token) return;
          this._terminalHideTimer = null;
          eventBus.emit('ui:hideCombatScreen', { terminalPresentation: true, token });
      }, delay);
      return token;
  }

  _clearTerminalCombatHide() {
      if (this._terminalHideTimer !== null && this._terminalHideTimer !== undefined) {
          this._cancelSchedule(this._terminalHideTimer);
      }
      this._terminalHideTimer = null;
      this._terminalHideToken = (Number(this._terminalHideToken) || 0) + 1;
  }

  isPlayerInputLocked() {
      const locked = this.active
          && this.phase === 'PLAYER_TURN'
          && (Number(this._playerInputLockUntil) > this._now()
            || this._visiblePlayerActionIds.size > 0);
      // Querying input availability must not mutate the lock.  The scheduled
      // unlock is the single owner that clears the deadline and emits the
      // matching combat update.  Otherwise an eager UI/test read can clear
      // the deadline just before the timer runs, leaving rendered techniques
      // visually disabled although the state now claims they are playable.
      return locked;
  }

  _lockPlayerInputForSemanticAction() {
      const action = this._activeSemanticAction;
      if (!action || action.source !== 'player') return false;
      const duration = Math.max(0, Number(action.duration) || 0);
      if (duration <= 0) return false;
      return this._commitPlayerInputLock(
        Math.max(Number(this._playerInputLockUntil) || 0, this._now() + duration),
        { actionId: action.actionId, source: action.source, duration }
      );
  }

  _reserveSerializedPresentationWindow(action = null) {
      const animation = action?.animation;
      if (!this.active
        || this._getPresentationContext()?.visualWorldCompatible !== true
        || animation?.kind !== 'frame_sequence'
        || animation.motionApproved !== true
        || !Array.isArray(animation.frames)
        || animation.frames.length < 2) return false;
      const authoredFrames = Array.isArray(animation.frameDurations)
        && animation.frameDurations.length === animation.frames.length
        ? animation.frameDurations.map(value => Math.max(16, Number(value) || 0))
        : null;
      const visualDuration = (authoredFrames
        ? authoredFrames.reduce((sum, value) => sum + value, 0)
        : Math.max(1, Number(action.duration) || 1)) + 32;
      const now = this._now();
      const tail = Math.max(now, Number(this._playerInputLockUntil) || 0);
      return this._commitPlayerInputLock(tail + visualDuration, {
        actionId: action.actionId,
        source: action.source,
        duration: visualDuration,
        serializedPresentation: true
      });
  }

  _commitPlayerInputLock(lockedUntil, detail = {}) {
      const resolvedUntil = Math.max(this._now() + 1, Number(lockedUntil) || 0);
      this._playerInputLockUntil = resolvedUntil;
      this._clearPlayerInputLockTimer();
      const unlockDelay = Math.max(1, resolvedUntil - this._now());
      this._playerInputUnlockTimer = this._schedule(() => {
          if (this._playerInputLockUntil !== resolvedUntil || this._now() < resolvedUntil) return;
          this._playerInputLockUntil = 0;
          this._playerInputUnlockTimer = null;
          if (this._visiblePlayerActionIds.size > 0) return;
          if (this.active && this.phase === 'PLAYER_TURN') this._triggerUpdate();
          eventBus.emit('combat:inputUnlocked', {
            actionId: detail.actionId || null,
            source: detail.source || null,
            serializedPresentation: detail.serializedPresentation === true
          });
      }, unlockDelay);
      eventBus.emit('combat:inputLocked', {
          actionId: detail.actionId || null,
          source: detail.source || null,
          lockedUntil: this._playerInputLockUntil,
          duration: Math.max(1, Number(detail.duration) || unlockDelay),
          serializedPresentation: detail.serializedPresentation === true
      });
      return true;
  }

  _clearPlayerInputLockTimer() {
      if (this._playerInputUnlockTimer !== null && this._playerInputUnlockTimer !== undefined) {
          this._cancelSchedule(this._playerInputUnlockTimer);
      }
      this._playerInputUnlockTimer = null;
  }

  _emitSemanticActionPhase(eventName, extra = {}) {
      const action = this._activeSemanticAction;
      if (!action || action.emittedPhases.has(eventName)) return false;
      action.emittedPhases.add(eventName);
      const phase = String(eventName).replace(/^combat:/, '');
      eventBus.emit(eventName, {
          actionId: action.actionId,
          actionFamily: action.actionFamily,
          source: action.source,
          target: action.target,
          sourceId: action.sourceId,
          presentationId: action.presentationId,
          timelineId: action.timelineId,
          duration: action.duration,
          reducedMotionFallback: action.reducedMotionFallback,
           displayedVisualStageId: action.displayedVisualStageId,
           animation: action.animation,
           stage: action.stage ? { ...action.stage } : null,
           sfxCueId: action.sfxCueId,
          sfxCue: action.sfxCue,
          phase,
          ...extra
      });
      return true;
  }

  _completeSemanticAction(extra = {}) {
      if (!this._activeSemanticAction) return false;
      const completedAction = this._activeSemanticAction;
      if (completedAction.actionFamily === 'attack'
        && !completedAction.emittedPhases.has('combat:impact')) {
          this._emitSemanticActionPhase('combat:impact', { amount: 0, blocked: true });
      }
      this._emitSemanticActionPhase('combat:actionCompleted', extra);
      if (completedAction.source === 'player' && completedAction.actionFamily === 'guard'
        && extra.interrupted !== true && extra.cancelled !== true) {
        this._triggerEquipmentPassives('onGuardResolved');
      }
      this._activeSemanticAction = null;
      return true;
  }

  _emitCombatFeedback(target, feedbackId, value, meta = {}) {
       const action = this._activeSemanticAction;
       eventBus.emit('combat:anim', {
          type: 'floating_text',
          target,
          feedbackId: String(feedbackId || 'change'),
          value: Number.isFinite(Number(value)) ? Number(value) : 0,
          caption: meta.caption || '',
           valueText: meta.valueText || '',
           actionId: action?.actionId || null,
           source: action?.source || null,
           stage: action?.stage ? { ...action.stage } : null
      });
  }

  _emitActionPresentationCues(action = this._activeSemanticAction) {
       const cues = Array.isArray(action?.presentation?.cues)
         ? action.presentation.cues
         : [];
       let emitted = 0;
       for (const cue of cues) {
          const cueId = typeof cue?.cueId === 'string' ? cue.cueId.trim() : '';
          if (!cueId) continue;
          const placement = ['travel', 'contact', 'source'].includes(cue.placement)
            ? cue.placement
            : 'contact';
          const releaseAtMs = Math.max(0, Number(cue.releaseAtMs ?? action.stage?.releaseAtMs) || 0);
          const impactAtMs = Math.max(
            releaseAtMs,
            Number(cue.impactAtMs ?? action.stage?.impactAtMs) || releaseAtMs
          );
          // 源局部特效（source placement）必须挂在动作发出方身上，不得被 cue.target 抢走：
          // 一旦有人给 source 特效写了 target:'enemy'，特效会挂到错误角色上。
          // 数据侧 198 条 cue 里显式写 target 的只有 15 条，且全是 'resolved_target'
          // （不在 ['player','enemy'] 内），故 authoredTarget 恒为 null —— 这行 || 是死分支，去掉。
          const cueTarget = placement === 'source' ? action.source : action.target;
          const requestedActorOffset = cue?.actorAnchorOffsetU;
          const actorAnchorOffsetU = requestedActorOffset
            && Number.isFinite(Number(requestedActorOffset.x))
            && Number.isFinite(Number(requestedActorOffset.y))
            && Math.abs(Number(requestedActorOffset.x)) <= 0.5
            && Math.abs(Number(requestedActorOffset.y)) <= 0.5
            ? { x: Number(requestedActorOffset.x), y: Number(requestedActorOffset.y) }
            : null;
          if (this._emitPresentationVfx(cueId, cueTarget, cueId, {
            authoredCue: true,
            placement,
            origin: typeof cue.origin === 'string' ? cue.origin : null,
            destination: typeof cue.destination === 'string' ? cue.destination : null,
            actorAnchorId: ['ground', 'centerMass', 'meleeLeft', 'meleeRight', 'castLeft', 'castRight']
              .includes(cue.actorAnchorId) ? cue.actorAnchorId : null,
            actorAnchorOffsetU,
            releaseAtMs,
            impactAtMs,
            // Hurt/defeat are presentation-only sidecars. Their VFX still
            // belongs to that visible action instead of borrowing the active
            // attack's ID, source or timing.
            actionOverride: action
          })) emitted += 1;
       }
       return emitted > 0;
  }

  _emitReactionContactPresentationCue(reactionResolution, action = this._activeSemanticAction) {
       const reactionId = String(reactionResolution?.reactionId || '');
       const cue = action?.presentation?.reactionContactCues?.[reactionId];
       if (!cue || typeof cue !== 'object' || Array.isArray(cue)) return false;
       return this._emitActionPresentationCues({
         ...action,
         presentation: { ...(action.presentation || {}), cues: [{ ...cue }] }
       });
  }

  _emitResolvedPresentationEffect({ sourceCard, effectIndex, resolvedTarget, outcome } = {}) {
       const action = this._activeSemanticAction;
       const sourceCardId = String(sourceCard?.id || action?.sourceId || '');
       const stableEffectIndex = Number(effectIndex);
       if (!action?.actionId || !sourceCardId || !Number.isInteger(stableEffectIndex)) return false;
       const sidecars = this._actionPresentationData?.cardEffectPresentations?.[sourceCardId];
       const channel = Array.isArray(sidecars)
         ? sidecars.find(item => Number(item?.effectIndex) === stableEffectIndex)
         : null;
       if (!channel || channel.target !== 'resolved_target') return false;
       if (!['player', 'enemy'].includes(resolvedTarget)) return false;
       const cueId = typeof channel.cueId === 'string' ? channel.cueId.trim() : '';
       const requestedAsset = cueId ? this._actionPresentationData?.semanticVfx?.[cueId] : null;
       const presentation = this.originalCard?.combatPresentation || {};
       const playerPath = (typeof gameState !== 'undefined' && gameState?.path) ? gameState.path : 'sword';
       const pathWorldId = this.getPathContract(playerPath)?.visualWorldId || null;
       const reviewedWorld = presentation.visualWorldId && presentation.visualWorldId === pathWorldId
         ? this._visualWorldData?.worlds?.[presentation.visualWorldId] : null;
       const registeredAsset = requestedAsset?.id && reviewedWorld
         ? reviewedWorld.vfxAssets?.[requestedAsset.id] : null;
       const requestedPlacement = ['travel', 'contact', 'source'].includes(channel.placement)
         ? channel.placement : 'contact';
       const asset = reviewedWorld
         ? (this._isRuntimeEligibleWorldVfxAsset(reviewedWorld, registeredAsset, {
           placement: requestedPlacement,
           frames: Array.isArray(requestedAsset?.frames) ? requestedAsset.frames : null
         }) ? registeredAsset : null)
         : requestedAsset;
       if (!cueId || !asset?.id || !Array.isArray(asset.frames) || asset.frames.length === 0) return false;
       const releaseAtMs = Math.max(0, Number(channel.releaseAtMs ?? action.stage?.releaseAtMs) || 0);
       const impactAtMs = Math.max(
         releaseAtMs,
         Number(channel.impactAtMs ?? action.stage?.impactAtMs) || releaseAtMs
       );
        return this._emitVfxRequest(cueId, resolvedTarget, cueId, {
          presentationOnly: true,
          effectIndex: stableEffectIndex,
          eventQualifier: `${sourceCardId}:${stableEffectIndex}`,
          sourceCardId,
          outcome: outcome && typeof outcome === 'object' ? { ...outcome } : null,
          placement: requestedPlacement,
          origin: typeof channel.origin === 'string' ? channel.origin : null,
          destination: typeof channel.destination === 'string' ? channel.destination : null,
          releaseAtMs,
          impactAtMs,
          assetId: asset.id,
          frames: asset.frames.map(frame => typeof frame === 'string' ? frame : frame.path).filter(Boolean),
          durationMs: Math.max(1, Number(asset.durationMs) || 1),
          assetVisualWorldId: asset.visualWorldId || null,
          assetPaletteSource: asset.paletteSource || null,
          assetAuthoredFacing: asset.authoredFacing || null,
          assetAuthoredTravelScale: asset.authoredTravelScale ? { ...asset.authoredTravelScale } : null,
          runtimeFacingPolicy: asset.runtimeFacingPolicy || null,
          vfxSlot: channel.placement === 'travel' ? 'travel_primary' : 'target_state'
        });
   }

  _emitVfxRequest(type, target, semantic = null, extra = {}) {
       const { actionOverride = null, ...requestExtra } = extra || {};
       const action = actionOverride || this._activeSemanticAction;
       const presentation = this.originalCard?.combatPresentation || {};
       const playerPath = (typeof gameState !== 'undefined' && gameState?.path) ? gameState.path : 'sword';
       const pathWorldId = this.getPathContract(playerPath)?.visualWorldId || null;
       const encounterWorldId = presentation.visualWorldId || null;
       const visualWorldId = encounterWorldId && encounterWorldId === pathWorldId
         && this._visualWorldData?.worlds?.[encounterWorldId]
         ? encounterWorldId
         : null;
       const placement = ['travel', 'contact', 'source'].includes(requestExtra.placement)
         ? requestExtra.placement
         : 'contact';
       const stateSemantics = new Set(['shield', 'shield_break', 'weak', 'opening', 'opening_consumed', 'treasure']);
       const vfxSlot = requestExtra.vfxSlot
         || (placement === 'travel'
           ? 'travel_primary'
           : (placement === 'source'
             ? 'source_method'
             : (stateSemantics.has(semantic) ? 'target_state' : 'contact_primary')));
       const owner = action?.actionId
         || `combat-vfx:${String(this.encounterContext?.encounterInstanceId || this._encounterActionId() || 'encounter')}:${Math.max(1, Number(this.turn) || 1)}`;
       const qualifier = requestExtra.eventQualifier ?? requestExtra.effectIndex ?? 'primary';
       const vfxEventId = String(requestExtra.vfxEventId
         || `${owner}:${vfxSlot}:${semantic || type || 'effect'}:${target || 'none'}:${qualifier}`);
       eventBus.emit('combat:vfx', {
          type,
          target,
          semantic,
          presentationId: presentation.presentationId || null,
          actionId: action?.actionId || null,
          source: action?.source || null,
          stage: action?.stage ? { ...action.stage } : null,
          visualWorldId,
          vfxEventId,
          vfxSlot,
          placement,
          ...requestExtra
       });
       return true;
  }

  _isRuntimeEligibleWorldVfxAsset(world, asset, { placement = null, frames = null } = {}) {
       const contract = world?.mediaDensityContract;
       const eligibleStatuses = Array.isArray(contract?.runtimeEligibleReviewStatuses)
         ? contract.runtimeEligibleReviewStatuses : [];
       const finalStatuses = Array.isArray(contract?.finalArtEligibleReviewStatuses)
         ? contract.finalArtEligibleReviewStatuses : [];
       const registeredFrames = Array.isArray(asset?.frames) ? asset.frames : [];
       const requestedFrames = Array.isArray(frames) ? frames : null;
       const scale = asset?.authoredTravelScale;
       const scaleRequired = asset?.requiresVisibleAlphaTravelScale === true;
       const facingCompatible = !scaleRequired
         || (asset?.placement === 'travel' && ['left', 'right'].includes(asset?.authoredFacing));
        const scaleCompatible = !scaleRequired || Boolean(
         asset?.placement === 'travel'
         && scale?.contractId === 'authored_travel_visible_alpha_scale_v2'
         && scale?.basis === 'world_unit_visible_alpha_width_from_verified_frame_bounds'
         && Number(scale.authoredVisibleWidthU) > 0
         && Number(scale.referenceAlphaWidthFraction) > 0
         && Number(scale.referenceAlphaWidthFraction) <= 1
         && Number(scale.minVisiblePx) > 0
         && Number(scale.maxVisiblePx) >= Number(scale.minVisiblePx)
           && registeredFrames.every(frame => frame?.visibleAlphaBounds
             && Number(frame.visibleAlphaBounds.width) > 0
             && Number(frame.visibleAlphaBounds.width) <= 1)
        );
        const groundScale = asset?.authoredGroundSpanScale;
        const groundScaleRequired = asset?.requiresGroundSpanScale === true;
        const groundScaleCompatible = !groundScaleRequired || Boolean(
          asset?.placement === 'contact'
          && groundScale?.contractId === 'authored_ground_conduit_footprint_v2'
          && groundScale?.basis === 'resolved_actor_ground_span_and_verified_luminous_contact_baseline'
          && Number(groundScale.referenceAlphaStartFraction) >= 0
          && Number(groundScale.referenceAlphaStartFraction) < 0.25
          && Number(groundScale.referenceAlphaSpanFraction) > 0.5
          && Number(groundScale.referenceAlphaSpanFraction) <= 1
          && Number(groundScale.referenceGroundContactYFraction) > 0.75
          && Number(groundScale.referenceGroundContactYFraction) < 0.98
          && Number(groundScale.minCarrierPx) > 0
          && Number(groundScale.maxCarrierPx) >= Number(groundScale.minCarrierPx)
          && registeredFrames.every(frame => frame?.visibleAlphaBounds
            && Number(frame.visibleAlphaBounds.width) > 0.4
            && Number(frame.visibleAlphaBounds.height) > 0
            && Number(frame.visibleAlphaBounds.height) < 0.26)
        );
       return Boolean(
         world?.id && asset?.id
         && asset.visualWorldId === world.id
         && asset.paletteSource === world?.vfxPolicy?.source
         && asset.mediaDensity === contract?.mediaDensity
         && Number(asset.logicalPixelGrid) === Number(contract?.logicalPixelGrid)
         && eligibleStatuses.includes(asset.reviewStatus)
         && (asset.finalArtApproved === false
           || (asset.finalArtApproved === true && finalStatuses.includes(asset.reviewStatus)))
         && (!placement || asset.placement === placement)
         && typeof asset.provenanceManifest === 'string'
         && asset.provenanceManifest.endsWith('/manifest.json')
         && registeredFrames.length === 4
         && registeredFrames.every((frame, index) => frame?.frameIndex === index
           && typeof frame.path === 'string' && frame.path.endsWith('.png')
           && /^[a-f0-9]{64}$/.test(String(frame.sha256 || ''))
           && Number(frame.width) > 0 && Number(frame.height) > 0)
         && (!requestedFrames || (requestedFrames.length === registeredFrames.length
           && registeredFrames.every((frame, index) => frame.path === requestedFrames[index])))
          && facingCompatible
          && scaleCompatible
          && groundScaleCompatible
        );
  }

  _emitPresentationVfx(type, target, semantic = null, extra = {}) {
       const action = extra?.actionOverride || this._activeSemanticAction;
       const genericContact = ['damage', 'shield_break'].includes(semantic)
         || (semantic === null && ['slash', 'impact'].includes(type));
       if (genericContact && extra?.authoredCue !== true
         && action?.presentation?.suppressGenericDamageVfx === true) {
          return false;
       }
       const presentation = this.originalCard?.combatPresentation || {};
      // Encounter-owned VFX remain authoritative when provided. Semantic
      // effects such as Opening are card/encounter agnostic and live in the
      // presentation registry, so the same status never degrades into an
      // empty generic impact on a different battle surface.
      // Damage/status callers name an explicit semantic (for example
      // `damage`), while authored attack contact calls use their visual type
      // (`slash`).  Both are presentation keys.  Requiring callers to repeat
      // the same word as a second argument left Boss attack contact VFX with
      // an emitted event but no asset carrier at all.
      const assetKey = semantic || type || null;
       const presentationAsset = assetKey
         ? (presentation.vfx?.[assetKey] || this._actionPresentationData?.semanticVfx?.[assetKey] || null)
         : null;
       const playerPath = (typeof gameState !== 'undefined' && gameState?.path) ? gameState.path : 'sword';
       const pathWorldId = this.getPathContract(playerPath)?.visualWorldId || null;
       const requestedWorldId = presentation.visualWorldId || null;
       const reviewedWorld = requestedWorldId && requestedWorldId === pathWorldId
         ? this._visualWorldData?.worlds?.[requestedWorldId]
         : null;
       const registeredAsset = presentationAsset?.id && reviewedWorld
         ? reviewedWorld.vfxAssets?.[presentationAsset.id]
         : null;
       // A reviewed visual world owns the exact asset registry. Presentation
       // data may request a semantic ID, but it cannot self-attest arbitrary
       // frame paths or palette labels into that world.
       const requestedPlacement = ['travel', 'contact', 'source'].includes(extra?.placement)
         ? extra.placement : (presentationAsset?.placement || null);
       const registeredAssetEligible = reviewedWorld && registeredAsset
         ? this._isRuntimeEligibleWorldVfxAsset(reviewedWorld, registeredAsset, {
           placement: requestedPlacement,
           frames: Array.isArray(presentationAsset?.frames) ? presentationAsset.frames : null
         }) : false;
       if (reviewedWorld && presentationAsset?.id && !registeredAssetEligible) return false;
       const asset = reviewedWorld ? (registeredAssetEligible ? registeredAsset : null) : presentationAsset;
       // Generic action labels without an authored carrier do not get a
       // synthetic flash. A later resolved damage/state request can still use
       // its encounter-owned art or the reviewed world fallback.
       if (!asset && semantic === null && ['slash', 'impact', 'aura'].includes(type)) return false;
       return this._emitVfxRequest(type, target, semantic, {
          assetId: asset?.id || null,
          frames: Array.isArray(asset?.frames)
            ? asset.frames.map(frame => typeof frame === 'string' ? frame : frame.path).filter(Boolean)
            : null,
          durationMs: Number(asset?.durationMs) || null,
          assetVisualWorldId: asset?.visualWorldId || null,
          assetPaletteSource: asset?.paletteSource || null,
          assetAuthoredFacing: asset?.authoredFacing || null,
           assetAuthoredTravelScale: asset?.authoredTravelScale
             ? { ...asset.authoredTravelScale }
             : null,
           assetAuthoredGroundSpanScale: asset?.authoredGroundSpanScale
             ? { ...asset.authoredGroundSpanScale }
             : null,
          runtimeFacingPolicy: asset?.runtimeFacingPolicy || null,
          ...extra
       });
  }

  _triggerUpdate() {
      eventBus.emit('combat:updated', {
      player: this.player,
      enemy: this.enemy,
      qi: this.qi,
      maxQi: this.maxQi,
      hand: this.hand.map(id => this.getCardDef(id)),
      drawCount: this.drawPile.length,
      discardCount: this.discardPile.length,
      exhaustCount: this.exhaustPile.length,
      playerStatus: this.playerStatus,
      enemyStatus: this.enemyStatus,
      intent: this.enemyIntent,
      // Ephemeral read model only: the renderer must display the same
      // tier/multiplier result that the authoritative reaction window uses.
      intentPreview: this._previewEnemyAction(),
      plan: this._getPlanStateView(),
      phase: this.phase,
      reaction: this._cloneReaction(this.pendingReaction),
      log: this.log,
      equipmentProgress: this._equipmentProgressView(),
      publicCombatFacts: this.getPublicCombatFacts(),
      turn: this.turn,
      archetype: (typeof pathArchetypeSystem !== 'undefined' && pathArchetypeSystem) ? pathArchetypeSystem.getSelected() : null,
      bossPhase: this.bossPhases.length ? {
        current: this.bossPhaseIndex + 1,
        total: this.bossPhases.length,
        name: this.enemy.name
      } : null,
      context: this._getPresentationContext()
    });
  }

  /**
   * 【ISSUE-06 闭环】检索玩家装备与持有法宝，转化为战术卡注入战斗构筑
   */
  _injectEquipmentAndTreasureTacticalCards() {
    if (typeof gameState === 'undefined' || !gameState) return;
    const injected = new Set(this.masterDeck);
    const pushExistingCard = (cardId, logText) => {
      if (!cardId || !this.cardDB?.[cardId] || injected.has(cardId)) return false;
      this.masterDeck.push(cardId);
      injected.add(cardId);
      this._addLog(logText);
      return true;
    };

    // 1. 穿戴装备转化战术卡
    const eqMap = {
      weapon: 'eq_weapon_strike',
      armor: 'eq_armor_shield',
      accessory: 'eq_weapon_strike'
    };
    if (gameState.equipment) {
      for (const [slot, itemId] of Object.entries(gameState.equipment)) {
        if (itemId) {
          const treasure = (typeof treasureSystem !== 'undefined' && treasureSystem
            && typeof treasureSystem.getTreasureData === 'function')
            ? treasureSystem.getTreasureData(itemId)
            : null;
          const cardId = treasure?.combatPresentation?.tacticalCardId || eqMap[slot] || null;
          pushExistingCard(cardId, `装备【${itemId}】以真实器契牌【${this.cardDB?.[cardId]?.name || cardId}】进入构筑。`);
        }
      }
    }

    // 2. 仅已穿戴法宝可把威能转化为战术卡；纳戒不是战斗效果区。
    const treasureMap = {
      soul_banner: 'treasure_soul_banner',
      thunder_bead: 'treasure_thunder_bead',
      nine_cauldron: 'treasure_nine_cauldron'
    };

    const treasures = (typeof treasureSystem !== 'undefined' && treasureSystem
      && typeof treasureSystem.getEquippedDefinitionIds === 'function')
      ? treasureSystem.getEquippedDefinitionIds()
      : [];
    treasures.forEach(tId => {
      const cardId = treasureMap[tId];
      pushExistingCard(cardId, `上古法宝【${tId}】威能化为战术大招卡注入构筑！`);
    });
  }

  /**
   * 每名已拥有道侣只注入当前已解锁的最高阶技能，避免 60/100 阶同时膨胀牌库。
   */
  _injectCompanionTacticalCards() {
    const contracts = (typeof companionSystem !== 'undefined' && companionSystem
      && typeof companionSystem.getUnlockedCombatContracts === 'function')
      ? companionSystem.getUnlockedCombatContracts()
      : [];
    const injected = new Set(this.masterDeck);
    this._companionCombatContracts = [];
    for (const contract of contracts) {
      if (!contract?.cardId || !this.cardDB?.[contract.cardId]) continue;
      this._companionCombatContracts.push({ ...contract });
      if (injected.has(contract.cardId)) continue;
      this.masterDeck.push(contract.cardId);
      injected.add(contract.cardId);
      this._addLog(`道侣【${contract.companionName || contract.compId}】以羁绊技能【${this.cardDB[contract.cardId].name}】并肩入局。`);
    }
  }

  _storyAssistContract(card = this.originalCard, cardDB = this.cardDB) {
    const raw = card?.combatPresentation?.storyAssist;
    if (!raw || typeof raw !== 'object' || !raw.id || !raw.cardId || !cardDB?.[raw.cardId]) return null;
    return {
      id: String(raw.id),
      compId: String(raw.compId || 'story_ally'),
      companionName: String(raw.companionName || '同行者'),
      cardId: String(raw.cardId),
      openingHand: raw.openingHand === true,
      unlockText: String(raw.unlockText || cardDB[raw.cardId].name || raw.cardId),
      mechanism: String(raw.mechanism || '')
    };
  }

  _injectStoryTacticalCard() {
    const contract = this._storyAssistContract();
    if (!contract) return false;
    if (!this._companionCombatContracts.some(entry => entry?.id === contract.id)) {
      this._companionCombatContracts.push(contract);
    }
    if (!this.masterDeck.includes(contract.cardId)) this.masterDeck.push(contract.cardId);
    this._addLog(`剧情同伴【${contract.companionName}】将援护牌【${contract.unlockText}】交到你手中。`);
    return true;
  }

  _prioritizeOpeningStoryTacticalCard() {
    const contract = this._storyAssistContract();
    if (!contract?.openingHand) return false;
    const index = this.drawPile.indexOf(contract.cardId);
    if (index < 0) return false;
    const [cardId] = this.drawPile.splice(index, 1);
    this.drawPile.push(cardId);
    return true;
  }
}

// 全局单例
const deckCombatSystem = new DeckCombatSystem();

if (typeof module !== 'undefined' && module.exports) {
  module.exports = DeckCombatSystem;
} else {
  window.DeckCombatSystem = DeckCombatSystem;
  window.deckCombatSystem = deckCombatSystem;
}
// 为了兼容旧代码的事件监听绑定，我们可以先将其暴露为 deckCombatSystem
