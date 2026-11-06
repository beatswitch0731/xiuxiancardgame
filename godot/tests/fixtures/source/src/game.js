/**
 * GameLogic - 游戏主逻辑（系统编排器）
 *
 * 负责协调所有子系统，处理核心游戏流程。
 * 不直接操作数据——所有状态变更通过 GameStateManager，
 * 抽卡通过 CardSystem，因果通过 KarmaSystem。
 */
class GameLogic {
  constructor(deps = {}) {
    // 依赖注入（核心状态/事件仍保留全局回退，服务与协调器必须注入）
    this.gameState = deps.gameState || gameState;
    this.eventBus = deps.eventBus || eventBus;
    this.cardSystem = deps.cardSystem || cardSystem;
    this.effectService = deps.effectService || null;
    this.combatCoordinator = deps.combatCoordinator || null;
    this.skillCardAcquisitionSystem = deps.skillCardAcquisitionSystem || null;
    this.factionSystem = deps.factionSystem || null;
    this.npcSystem = deps.npcSystem || null;
    this.endingEligibilityService = deps.endingEligibilityService || null;
    this.storyThreadEngine = deps.storyThreadEngine || null;
    this.choiceOutcomeRouter = deps.choiceOutcomeRouter
      || (typeof choiceOutcomeRouter !== 'undefined' ? choiceOutcomeRouter : null);
    this.encounterDirector = deps.encounterDirector
      || (typeof encounterDirector !== 'undefined' ? encounterDirector : null);
    this.flowDirector = deps.flowDirector
      || (typeof flowDirector !== 'undefined' ? flowDirector : null);
    this.marketSystem = deps.marketSystem
      || (typeof marketSystem !== 'undefined' ? marketSystem : null);
    this.chapterSystem = deps.chapterSystem
      || (typeof chapterSystem !== 'undefined' ? chapterSystem : null);
    this.random = typeof deps.random === 'function' ? deps.random : Math.random;
    this.ui = deps.ui || null;
    this.debug = deps.debug !== false;

    this.onLog = null;
    this.onUpdate = null;
    this.currentCard = null;
    this._lastChoiceRejection = null;
    this._pendingChoiceSettlement = null;
    this._lastChoiceSettlement = null;
    this._choiceTokenCounter = 0;
    this._activeChoiceToken = null;
    // 突破成功后的专属承接卡。不能直接写 currentCard：普通选项结算尾部会将其覆盖为 null。
    this._pendingRealmTransitionCard = null;
    // 暂存支线推进后的下一张卡ID（由 QuestSystem 通过 quest:advanced 事件注入）
    this._questNextCardId = null;
    // ── v2.0 上瘾引擎暂存 ──
    this._pendingRipple = null;
    this._pendingHint = null;
    this._pendingMarket = null;
    this._pendingVendorChoiceContext = null;
    this._pendingPromiseResultCard = null;
    // ── 沉浸 v2.0 心念系统 ──
    this._innerVoiceCooldown = 0;
    this._prevAttrSnap = null; // 上一轮属性快照，用于检测变化
    // ── 沉浸 v2.0 P2：世界事件 ──
    this._lastWorldEventTurn = 0;
    // ── 境界章节主线里程碑 ──
    this._chapterMilestoneCard = null;
    // ── 新手引导教程队列 ──
    this._tutorialCardIds = ['tutorial_1', 'tutorial_2', 'tutorial_3', 'tutorial_4'];

    if (this.gameState) {
      this.gameState._getAggregatedPassives = this._getAggregatedPassives.bind(this);
    }
    if (this.debug) console.log('[GameLogic] constructed with deps:', Object.keys(deps));
  }

  /**
   * Attach the presentation port after GameUI has finished constructing.
   * GameLogic starts before the DOM UI, so it must never depend on a lexical/global `ui`.
   * @param {Object|null} ui
   * @returns {boolean}
   */
  attachUI(ui) {
    this.ui = ui || null;
    if (!this.ui) return false;
    this._activateCompanionToHUD();
    return true;
  }

  /**
   * Player-facing choice projection. GameLogic composes the existing numeric
   * authority with the owners of top-level behavior fields; UI must never
   * infer these outcomes from authored prose.
   */
  previewChoice(choice, context = {}) {
    const source = choice && typeof choice === 'object' ? choice : {};
    const card = context.card || this.currentCard || null;
    const numericContext = {
      cardId: context.cardId || card?.id || null,
      cardTags: context.cardTags || card?.tags || []
    };
    const ordinaryBase = context.basePreview
      || this.effectService?.previewChoice?.(source, {
        ...numericContext
      })
      || { executable: true, reason: 'allowed', reasons: [], costs: [], changes: [], skillCards: [] };
    // Source effects move into the selected combat result. The warning is a
    // separate immediate decision and must retain its own preparation costs.
    const combatContract = card?.type === 'COMBAT_WARNING' || context.resolvedCombatMiss === true
      ? { kind: 'none', valid: true }
      : this._getChoiceCombatContract(card, context.direction, source);
    const deferredCombat = combatContract.kind === 'direct'
      || (combatContract.kind === 'chance' && combatContract.chance !== 0);
    const dungeonPreview = Object.prototype.hasOwnProperty.call(source, 'dungeon')
      ? this._projectDungeonEntry(source.dungeon) : null;
    // Invalid admission retires the choice before costs/effects can settle.
    // A missing authority is not a confirmed rejection and remains fail-closed.
    const rejectedDungeon = dungeonPreview?.contractValid === true && dungeonPreview.valid === false;
    const base = deferredCombat || rejectedDungeon
      ? (this.effectService?.previewChoice?.({ effects: {} }, numericContext)
        || { executable: true, reason: 'allowed', reasons: [], costs: [], changes: [], skillCards: [] })
      : ordinaryBase;
    const behaviors = [];
    const behaviorFields = [];
    const has = field => Object.prototype.hasOwnProperty.call(source, field);

    if (has('breakSuccess')) {
      behaviorFields.push('breakSuccess');
      behaviors.push(this._projectBreakthroughAttempt(source.breakSuccess, card, {
        isCombatResolve: context.isCombatResolve === true
      }));
    }

    const combatFields = ['victoryEffects', 'defeatEffects', 'fleeEffects'].filter(has);
    const projectCombat = resolvedChoice => {
      const projection = this._projectCombatOutcomeBranches(resolvedChoice, card, context);
      if (resolvedChoice.entryEffects) {
        projection.entryTiming = 'after_confirmation';
        projection.entryPreview = this.effectService?.previewEffects?.(resolvedChoice.entryEffects, numericContext) || null;
      }
      return projection;
    };
    if (deferredCombat) {
      behaviorFields.push(...combatFields,
        ...['triggerCombat', 'combatEncounterId', 'combatChance'].filter(has));
      const combatPreview = combatContract.combatChoice
        ? projectCombat(combatContract.combatChoice)
        : { type: 'combat_outcomes', contractValid: false, reason: combatContract.reason, branches: [] };
      if (combatContract.kind === 'chance') {
        const ordinaryAvailable = combatContract.chance < 1 && ordinaryBase.executable !== false;
        const blocksChoice = !combatContract.combatChoice && !ordinaryAvailable;
        behaviors.push({
          type: 'combat_chance',
          contractValid: combatContract.valid,
          blocksChoice,
          reason: blocksChoice && combatContract.chance < 1
            ? ordinaryBase.reason
            : (combatContract.reason || null),
          chance: combatContract.chance,
          ordinaryPreview: combatContract.chance < 1 ? ordinaryBase : null,
          combatPreview
        });
      } else {
        behaviors.push(combatPreview);
      }
    } else if (combatFields.length) {
      behaviorFields.push(...combatFields);
      behaviors.push(projectCombat(source));
    }

    if (has('dungeon')) {
      behaviorFields.push('dungeon');
      behaviors.push(dungeonPreview);
    }

    if (has('action')) {
      behaviorFields.push('action');
      behaviors.push(this._projectChoiceAction(source.action, context));
    }

    const invalidBehavior = behaviors.find(behavior => behavior?.contractValid === false);
    const behaviorBlocked = behaviors.find(behavior => behavior?.blocksChoice === true);
    const reasons = [...(base.reasons || [])];
    const combatRejection = combatContract.valid === false ? combatContract.reason : null;
    if (invalidBehavior) reasons.push({ code: combatRejection || 'behavior_preview_unavailable', key: invalidBehavior.type });
    if (behaviorBlocked) reasons.push({ code: behaviorBlocked.reason || 'behavior_unavailable', key: behaviorBlocked.type });
    return {
      ...base,
      executable: base.executable !== false && !invalidBehavior && !behaviorBlocked,
      reason: base.executable === false
        ? base.reason
        : (invalidBehavior ? (combatRejection || 'behavior_preview_unavailable') : (behaviorBlocked?.reason || base.reason || 'allowed')),
      reasons,
      behaviors,
      behaviorFields
    };
  }

  previewCardChoices(card, context = {}) {
    const choices = card?.choices && typeof card.choices === 'object' ? card.choices : {};
    const numeric = this.effectService?.previewCardChoices?.(card, {
      ...context,
      cardId: context.cardId || card?.id || null,
      cardTags: context.cardTags || card?.tags || []
    }) || {};
    return Object.fromEntries(Object.entries(choices).map(([direction, choice]) => [
      direction,
      this.previewChoice(choice, {
        ...context,
        card,
        direction,
        cardId: context.cardId || card?.id || null,
        cardTags: context.cardTags || card?.tags || [],
        basePreview: numeric[direction]
      })
    ]));
  }

  _projectBreakthroughAttempt(successRate, card, { isCombatResolve = false } = {}) {
    const state = this.gameState || gameState;
    const realm = state.realm;
    const realmConfig = state.config?.realms?.realms?.[realm] || null;
    const requiredPill = realmConfig?.pillRequired || null;
    const combatCounters = card?.combatRules?.counters || {};
    const configuredCombatPillFlag = card?.combatRules?.counter?.flag
      || Object.values(combatCounters).find(counter => (
        typeof counter?.flag === 'string' && /^used_.+_pill$/.test(counter.flag)
      ))?.flag;
    const combatPillFlag = configuredCombatPillFlag
      || (requiredPill ? `used_${requiredPill}_pill` : null);
    const pillPrepared = isCombatResolve
      && Number(successRate) > 0
      && Boolean(combatPillFlag)
      && state.hasFlag?.(combatPillFlag) === true;
    const pillAvailable = Boolean(requiredPill) && (
      isCombatResolve ? pillPrepared : state.hasResource?.('pill', requiredPill) === true
    );
    const boost = Math.max(0, Number(state.getFlag?.(`breakthrough_boost:${realm}`, 0)) || 0);
    const baseRate = Math.max(0, Math.min(1, Number(successRate) || 0));
    const beforeTianji = Math.min(1, baseRate + boost);
    const tianji = Math.max(0, Number(state.getAttribute?.('tianji') ?? state.attributes?.tianji) || 0);
    const tianjiPenalty = tianji > 30 ? Math.min(0.3, (tianji - 30) / 200) : 0;
    const finalRate = pillAvailable ? 1 : Math.max(tianjiPenalty > 0 ? 0.1 : 0, beforeTianji - tianjiPenalty);
    const order = state.config?.realms?.order || [];
    const nextRealm = order[order.indexOf(realm) + 1] || null;
    const failurePreview = this.effectService?.previewChoice?.({
      effects: { daoHeart: -1, cultivation: -30 }
    }, { cardId: card?.id || null, cardTags: card?.tags || [] }) || null;
    return {
      type: 'breakthrough',
      contractValid: Number.isFinite(Number(successRate)),
      baseRate,
      boost,
      tianji,
      tianjiPenalty,
      finalRate,
      guaranteed: finalRate >= 1,
      guaranteeSource: pillAvailable ? 'realm_pill' : (baseRate >= 1 ? 'authored_rate' : null),
      realm,
      realmName: realmConfig?.name || realm,
      nextRealm,
      nextRealmName: nextRealm ? (state.config?.realms?.realms?.[nextRealm]?.name || nextRealm) : null,
      pill: requiredPill ? {
        id: requiredPill,
        name: realmConfig?.pillName || requiredPill,
        available: pillAvailable,
        preparedForCombat: pillPrepared,
        willConsume: pillAvailable && !isCombatResolve
      } : null,
      failurePreview
    };
  }

  _projectCombatOutcomeBranches(choice, card, context = {}) {
    const project = effects => this.effectService?.previewEffects?.(effects, {
      cardId: card?.id || context.cardId || null,
      cardTags: card?.tags || context.cardTags || []
    }) || { executable: true, reason: 'allowed', reasons: [], costs: [], changes: [], skillCards: [] };
    const cleanEffects = raw => {
      const effects = raw && typeof raw === 'object' ? { ...raw } : {};
      delete effects.triggerCombat;
      return effects;
    };
    const victoryEffects = cleanEffects(choice.victoryEffects || choice.effects || {});
    const defeatEffects = cleanEffects(choice.defeatEffects || {});
    const fleeEffects = cleanEffects(choice.fleeEffects || { lifespan: -1 });
    const combatCard = context.combatCard || card || {};
    const tier = Math.max(1, Number(combatCard?.enemy?.tier) || 1);
    const legacyEffectLoss = Number(defeatEffects.health) < 0 ? Math.abs(Number(defeatEffects.health)) : 0;
    const configuredLoss = Number(legacyEffectLoss || (
      choice.defeatHealthLoss
      ?? combatCard?.combatRules?.defeatHealthLoss
      ?? combatCard?.enemy?.defeatHealthLoss
      ?? context.defeatHealthLoss
    ));
    let requestedInjury = Number.isFinite(configuredLoss) && configuredLoss > 0
      ? Math.round(configuredLoss)
      : (tier >= 3 ? 3 : (tier === 2 ? 2 : 1));
    const configuredFloor = Number(choice.defeatHealthFloor
      ?? combatCard?.defeatHealthFloor
      ?? combatCard?.combatRules?.defeatHealthFloor);
    const currentHealth = Math.max(0, Number((this.gameState || gameState).getAttribute?.('health')) || 0);
    if (Number.isFinite(configuredFloor) && configuredFloor >= 1) {
      requestedInjury = Math.min(requestedInjury, Math.max(0, currentHealth - Math.floor(configuredFloor)));
    }
    delete defeatEffects.health;
    const appliedInjury = Math.min(currentHealth, Math.max(0, requestedInjury));
    return {
      type: 'combat_outcomes',
      contractValid: true,
      mutuallyExclusive: true,
      branches: [
        { id: 'victory', label: '胜利', preview: project(victoryEffects) },
        {
          id: 'defeat',
          label: '战败',
          preview: project(defeatEffects),
          injury: { requested: requestedInjury, applied: appliedInjury, floor: Number.isFinite(configuredFloor) ? configuredFloor : null }
        },
        { id: 'flee', label: '撤离', preview: project(fleeEffects) }
      ]
    };
  }

  _projectDungeonEntry(dungeonId) {
    const contract = this.cardSystem?.validateDungeonEntry?.(dungeonId, (this.gameState || gameState).realm) || null;
    const dungeon = contract?.dungeon || null;
    const nodes = dungeon?.graph ? Object.values(dungeon.graph) : (Array.isArray(dungeon?.nodes) ? dungeon.nodes : []);
    const firstNodeId = dungeon?.graph
      ? (dungeon.startNode || Object.keys(dungeon.graph)[0] || null)
      : (nodes[0]?.id || null);
    const firstNode = dungeon?.graph?.[firstNodeId] || nodes[0] || null;
    return {
      type: 'dungeon',
      contractValid: Boolean(contract),
      blocksChoice: false,
      dungeonId: contract?.dungeonId || dungeonId || null,
      name: dungeon?.name || dungeon?.title || dungeonId || '未知秘境',
      valid: contract?.valid === true,
      reason: contract?.reason || null,
      nodeCount: nodes.length,
      firstNodeId,
      firstCardId: firstNode?.card || null
    };
  }

  _projectChoiceAction(action, context = {}) {
    const source = action && typeof action === 'object' ? action : {};
    const project = (eligibility, details = {}) => ({
      type: 'action', actionType: source.type, contractValid: true,
      blocksChoice: eligibility.valid !== true,
      eligible: eligibility.valid === true, reason: eligibility.reason || null,
      ...details
    });
    if (source.type === 'SETTLE_GHOST_DEBT') {
      const contract = this._getGhostDebtActionContract(source);
      return project(contract, {
        debtId: source.debtId || null,
        outcome: source.outcome || null,
        spiritStoneCost: contract.outcome === 'SETTLED' ? contract.stoneDue || 0 : 0,
        revokesGhostMarket: contract.outcome === 'DEFAULTED'
          && contract.debt?.defaultConsequence === 'ghost_market_access_revoked'
      });
    }
    if (source.type === 'CLAIM_LICENSED_RUSTED_SWORD') {
      const shop = typeof shopSystem !== 'undefined' ? shopSystem : null;
      const contract = shop?.previewLicensedRustedSwordOrder?.(source.orderId)
        || { valid: false, reason: 'regulated_delivery_unavailable' };
      // Shop keeps receipt replay idempotent for callers restoring an order;
      // a played card must not turn that replay into another core decision.
      const eligibility = contract.replayed
        ? { valid: false, reason: 'regulated_delivery_already_claimed' } : contract;
      return project(eligibility, {
        orderId: source.orderId || null,
        definitionId: contract.order?.definitionId || null,
        orderLabel: contract.order?.orderLabel || null,
        opensLoadoutDecision: eligibility.valid === true
      });
    }
    if (source.type === 'RESOLVE_NARRATIVE_FACT_CONSUMER') {
      const contract = this._getNarrativeFactConsumerActionContract(source);
      return project(contract, {
        factInstanceId: source.factInstanceId || null,
        consumerId: source.consumerId || null,
        outcomeId: contract.authoredChoice?.id || null,
        receiptDisposition: contract.authoredChoice?.receiptDisposition || contract.authoredChoice?.id || null,
        outcomeText: contract.authoredChoice?.text || null
      });
    }
    if (source.type === 'DISMISS_VENDOR_RESULT') {
      const card = context.card || this.currentCard;
      const session = (this.gameState || gameState).marketState?.activeSession;
      const valid = card?.type === 'VENDOR_RESULT' && Boolean(card.id)
        && session?.status === 'result' && session.resultCard?.id === card.id;
      return project({ valid, reason: valid ? null : 'vendor_result_unavailable' }, {
        settlementTiming: 'already_settled', consumesDecision: false
      });
    }
    if (source.type !== 'ENTER_VENDOR') {
      return {
        type: 'action',
        actionType: source.type || null,
        contractValid: false,
        blocksChoice: true,
        reason: 'unsupported_action_preview'
      };
    }
    const market = this.marketSystem;
    const requestedVendorId = source.vendorId || 'regulated_market';
    const vendorId = market?.normalizeVendorId?.(requestedVendorId) || null;
    const profile = vendorId ? market?.getVendorProfile?.(vendorId) : null;
    const decisionIndex = typeof (this.gameState || gameState).getNextDecisionIndex === 'function'
      ? (this.gameState || gameState).getNextDecisionIndex()
      : Math.max(0, Number((this.gameState || gameState).turn) || 0) + 1;
    const eligibility = vendorId && market?.canEnterVendor
      ? market.canEnterVendor(vendorId, {
        marketEncounter: source.marketEncounter === true,
        decisionIndex
      })
      : { valid: Boolean(vendorId && profile), reason: vendorId ? null : 'missing_profile' };
    return {
      type: 'action',
      actionType: 'ENTER_VENDOR',
      contractValid: Boolean(vendorId && profile),
      blocksChoice: eligibility.valid !== true,
      reason: eligibility.reason || null,
      requestedVendorId,
      vendorId,
      marketType: profile?.marketType || null,
      presentationProfileId: profile?.presentationProfile?.id || null,
      eligible: eligibility.valid === true,
      resumePolicy: source.resumePolicy || null,
      settlePolicy: source.settlePolicy || null,
      settlementTiming: source.settlePolicy === 'AFTER_CLOSE_EXACTLY_ONCE'
        ? 'after_close_exactly_once'
        : 'after_close'
    };
  }

  _getGhostDebtActionContract(action = {}) {
    const state = this.gameState || gameState;
    const debt = state.marketState?.debts?.find(entry => entry?.debtId === action.debtId) || null;
    const outcome = action.outcome === 'defaulted' ? 'DEFAULTED' : 'SETTLED';
    const settlementCost = Array.isArray(debt?.settlementCostSpec) && debt.settlementCostSpec.length > 0
      ? debt.settlementCostSpec
      : [{ kind: 'resource', key: 'spiritStone', amount: 1 }];
    const stoneDue = settlementCost
      .filter(cost => cost?.kind === 'resource' && cost.key === 'spiritStone')
      .reduce((total, cost) => total + Math.max(0, Number(cost?.amount) || 0), 0);
    const result = { debt, outcome, settlementCost, stoneDue };
    if (!['settled', 'defaulted'].includes(action.outcome)) {
      return { ...result, valid: false, reason: 'ghost_debt_invalid_outcome' };
    }
    if (!debt || debt.status !== 'DUE') {
      return { ...result, valid: false, reason: 'ghost_debt_not_due' };
    }
    if (outcome === 'SETTLED' && Math.max(0, Number(state.resources?.spiritStone) || 0) < stoneDue) {
      return { ...result, valid: false, reason: 'ghost_debt_settlement_unaffordable' };
    }
    if (debt.kind === 'ghost_oath_sword') {
      const ledger = typeof narrativeLedger !== 'undefined' ? narrativeLedger : null;
      if (!ledger?.consumeFact || !ledger?.getEligibleConsumerFacts || !debt.sourceFactInstanceId) {
        return { ...result, valid: false, reason: 'ghost_oath_fact_unavailable' };
      }
      const eligible = ledger.getEligibleConsumerFacts({
        consumerId: 'ghost_oath_debt_settlement',
        decisionIndex: state.getNextDecisionIndex?.() ?? state.getDecisionIndex?.() ?? state.turn
      }).some(entry => entry.factInstanceId === debt.sourceFactInstanceId);
      if (!eligible) return { ...result, valid: false, reason: 'ghost_oath_fact_settlement_rejected' };
    }
    return { ...result, valid: true, reason: null };
  }

  _getNarrativeFactConsumerActionContract(action = {}) {
    const ledger = typeof narrativeLedger !== 'undefined' ? narrativeLedger : null;
    if (!ledger?.consumeFact || !ledger?.getEligibleConsumerFacts) {
      return { valid: false, reason: 'narrative_fact_ledger_unavailable' };
    }
    const fact = ledger.getFact?.(action.factInstanceId);
    const definition = ledger.getCausalFactDefinition?.(fact?.factTypeId);
    const consumer = definition?.consumers?.find(candidate => candidate.consumerId === action.consumerId);
    const authoredChoice = consumer?.narrative?.choices?.find(choice => choice.id === action.outcomeId);
    const result = { fact, consumer, authoredChoice };
    if (!fact || !consumer || !authoredChoice) {
      return { ...result, valid: false, reason: 'narrative_fact_invalid_choice' };
    }
    const eligible = ledger.getEligibleConsumerFacts({
      consumerId: action.consumerId, decisionIndex: this._narrativeSpineDecisionIndex()
    }).some(entry => entry.factInstanceId === action.factInstanceId);
    return { ...result, valid: eligible, reason: eligible ? null : 'narrative_fact_already_resolved' };
  }

  /** 世界事件触发间隔（回合） */
  static WORLD_EVENT_INTERVAL = 12;

  /** 六境 StoryThread 数据的唯一生产注册表。 */
  static STORY_THREAD_MODULE_NAMES = Object.freeze([
    'threads:qi_threads',
    'threads:foundation_threads',
    'threads:golden_threads',
    'threads:nascent_threads',
    'threads:deity_threads',
    'threads:tribulation_threads',
    'threads:last_lesson_threads'
  ]);

  /**
   * 世界事件池 —— 让玩家感受到"天下不止我一个人在修仙"
   * 
   * 格式: { text, realmGate, tags }
   *   realmGate: null=任意境界, 境界名=需达到该境界才触发
   *   tags: 用于未来因果种子挂钩（death/treasure/war/secret/monster 等）
   */
  static WORLD_EVENTS = [
    // === 通用事件（任意境界） ===
    { text: '\u4e1c\u6d77\u8fdc\u6d77\u4f20\u6765\u6d88\u606f\uff1a\u9f99\u5bab\u5f00\u542f\u4e07\u5e74\u4e00\u5ea6\u7684\u9f99\u95e8\u5927\u4f1a\uff0c\u5404\u8def\u5929\u624d\u6b63\u5728\u8d76\u5f80\u3002', tags: ['event'] },
    { text: '\u5bd2\u5c71\u5251\u5b97\u7684\u4e00\u4f4d\u957f\u8001\u5750\u5316\uff0c\u4e34\u7ec8\u7559\u4e0b\u4e86\u4e00\u9053\u5251\u610f\u2026\u2026\u4f46\u6ca1\u4eba\u80fd\u53c2\u900f\u3002', tags: ['legacy'] },
    { text: '\u897f\u57df\u6c99\u6d77\u4e2d\u53d1\u73b0\u4e86\u4e00\u5ea7\u4e0a\u53e4\u4fee\u58eb\u7684\u6d1e\u5e9c\u9057\u5740\uff0c\u6563\u4fee\u4eec\u8702\u62e5\u800c\u81f3\u3002', tags: ['treasure'] },
    { text: '\u4e91\u96fe\u5c71\u8109\u6df1\u5904\u4f20\u6765\u5f02\u52a8\uff0c\u636e\u8bf4\u662f\u4e00\u5934\u6c89\u7761\u5343\u5e74\u7684\u5996\u517d\u82cf\u9192\u4e86\u3002', tags: ['monster'] },
    { text: '\u4e39\u5b97\u516c\u5e03\u4e86\u65b0\u7684\u7ec3\u4e39\u6cd5\u95e8\uff0c\u636e\u8bf4\u80fd\u5c06\u6210\u4e39\u7387\u63d0\u5347\u4e09\u6210\u3002\u5382\u5e02\u4e0a\u7075\u8349\u4ef7\u683c\u987f\u65f6\u98d9\u5347\u3002', tags: ['economy'] },
    { text: '\u5317\u57df\u7687\u671d\u5185\u4e71\uff0c\u4e09\u4f4d\u7687\u5b50\u4e89\u4f4d\uff0c\u8fde\u5e26\u7740\u51e0\u4e2a\u4fee\u4ed9\u5b97\u95e8\u4e5f\u5377\u4e86\u8fdb\u53bb\u3002', tags: ['politics'] },
    { text: '\u5929\u666f\u57ce\u4eca\u65e5\u6765\u4e86\u4e00\u4f4d\u795e\u79d8\u5546\u4eba\uff0c\u8bf4\u662f\u624b\u91cc\u6709\u4e00\u5f20\u4e0a\u53e4\u6d1e\u5e9c\u7684\u5730\u56fe\u2026\u2026\u4f46\u8981\u4ef7\u5341\u4e07\u7075\u77f3\u3002', tags: ['secret'] },
    { text: '\u84ec\u83b1\u4ed9\u5c9b\u7684\u4f7f\u8005\u62b5\u8fbe\u5927\u9646\uff0c\u5e26\u6765\u4e86\u6d77\u5916\u4fee\u58eb\u7684\u6cd5\u95e8\u4e0e\u602a\u5f02\u6d77\u517d\u7684\u6d88\u606f\u3002', tags: ['exploration'] },
    { text: '\u5357\u7586\u51fa\u73b0\u5929\u8c61\u5f02\u53d8\uff0c\u4e00\u9897\u6d41\u661f\u753b\u8fc7\u5929\u9645\u2014\u2014\u5929\u673a\u8001\u4eba\u95ed\u5173\u4e0d\u51fa\uff0c\u65e0\u4eba\u80fd\u89e3\u8bfb\u8fd9\u662f\u5409\u662f\u51f6\u3002', tags: ['omen'] },
    { text: '\u6668\u96fe\u5c71\u5e02\u7684\u4fe1\u4f7f\u5e26\u6765\u4e86\u4e00\u5219\u60ca\u4eba\u6d88\u606f\uff1a\u6709\u4eba\u5728\u6df1\u6e0a\u4e2d\u53d1\u73b0\u4e86\u6d3b\u7740\u7684\u9b54\u4fee\u2026\u2026\u800c\u90a3\u4e2a\u9b54\u4fee\u5df2\u7ecf\u6d3b\u4e86\u4e94\u767e\u5e74\u3002', tags: ['ancient'] },
    // === 筑基后解锁 ===
    { text: '\u5929\u5251\u5b97\u5e7f\u53d1\u82f1\u96c4\u5e16\uff0c\u9080\u8bf7\u5404\u5730\u5251\u4fee\u524d\u5f80\u53c2\u52a0\u201c\u5929\u5251\u5927\u6bd4\u201d\uff0c\u5934\u7b79\u636e\u8bf4\u662f\u4e00\u67c4\u4ed9\u5251\u3002', realmGate: '\u7b51\u57fa\u671f', tags: ['tournament'] },
    { text: '\u7ec3\u4e39\u5e08\u8054\u76df\u5ba3\u5e03\u53d1\u73b0\u4e86\u65b0\u7684\u4e39\u65b9\u53e4\u7c4d\uff0c\u5176\u4e2d\u8bb0\u8f7d\u4e86\u201c\u592a\u53e4\u56de\u5929\u4e39\u201d\u7684\u70bc\u5236\u65b9\u6cd5\u2014\u2014\u4f46\u6240\u9700\u6750\u6599\u95fb\u6240\u672a\u95fb\u3002', realmGate: '\u7b51\u57fa\u671f', tags: ['pill'] },
    // === 金丹后解锁 ===
    { text: '\u4e94\u884c\u5b97\u516c\u5e03\u4e86\u4e00\u9879\u53d1\u73b0\uff1a\u4e16\u754c\u7684\u7075\u6c14\u6d53\u5ea6\u6b63\u5728\u7f13\u6162\u4e0b\u964d\u3002\u6709\u4eba\u8bf4\u8fd9\u662f\u5929\u5730\u5927\u52ab\u7684\u524d\u5146\u3002', realmGate: '\u91d1\u4e39\u671f', tags: ['crisis'] },
    { text: '\u4f20\u95fb\u4e2d\u7684\u201c\u665a\u5c9a\u5723\u5730\u201d\u51fa\u73b0\u5728\u4e86\u4e1c\u65b9\u7684\u6d77\u5c7f\u4e0a\u2014\u2014\u636e\u8bf4\u8fdb\u5165\u5176\u4e2d\u7684\u4eba\uff0c\u51fa\u6765\u540e\u4fee\u4e3a\u5927\u6da8\uff0c\u4f46\u4e5f\u4f1a\u5931\u53bb\u67d0\u4e9b\u4e1c\u897f\u3002', realmGate: '\u91d1\u4e39\u671f', tags: ['mystery'] },
    // === 元婴后解锁 ===
    { text: '\u4e2d\u5dde\u7684\u4e03\u5927\u5b97\u95e8\u8054\u5408\u53d1\u5e03\u201c\u8baf\u6740\u4ee4\u201d\uff1a\u6709\u4eba\u5728\u6697\u4e2d\u63a8\u52a8\u6b63\u9b54\u5927\u6218\uff0c\u60ac\u8d4f\u63d0\u4f9b\u7ebf\u7d22\u8005\u3002', realmGate: '\u5143\u5a74\u671f', tags: ['conspiracy'] },
    { text: '\u592a\u53e4\u9057\u6c11\u2014\u2014\u4e00\u4e2a\u81ea\u79f0\u201c\u592a\u53e4\u5996\u65cf\u201d\u7684\u4eba\u51fa\u73b0\u5728\u4e16\u4eba\u9762\u524d\uff0c\u8bf4\u8981\u8ba8\u56de\u7956\u5148\u7684\u5730\u76d8\u3002', realmGate: '\u5143\u5a74\u671f', tags: ['ancient'] },
    // === 化神后解锁 ===
    { text: '\u5317\u51a5\u6d77\u6df1\u5904\u4f20\u6765\u949f\u58f0\u2014\u2014\u636e\u8bf4\u90a3\u662f\u4e00\u4ef6\u5148\u5929\u7075\u5b9d\u201c\u6d6e\u6ca7\u949f\u201d\u7684\u58f0\u97f3\uff0c\u53ea\u6709\u5929\u5730\u5927\u52ab\u524d\u624d\u4f1a\u54cd\u8d77\u3002', realmGate: '\u5316\u795e\u671f', tags: ['artifact'] },
    { text: '\u4e00\u4f4d\u98de\u5347\u5931\u8d25\u7684\u4fee\u58eb\u5728\u4e34\u6b7b\u524d\u590d\u523b\u4e86\u5929\u9053\u7684\u79d8\u5bc6\u2014\u2014\u4f46\u523b\u5230\u4e00\u534a\u5c31\u8eab\u6b7b\u9053\u6d88\u3002\u523b\u6587\u88ab\u5404\u5927\u5b97\u95e8\u62a2\u593a\u3002', realmGate: '\u5316\u795e\u671f', tags: ['secret','fate'] },
    // === 渡劫后解锁 ===
    { text: '\u5929\u5730\u8272\u53d8\u3002\u4e09\u5341\u5e74\u524d\u98de\u5347\u7684\u90a3\u4f4d\u4ed9\u4eba\u2026\u2026\u56de\u6765\u4e86\u3002\u4f46\u4ed6\u770b\u8d77\u6765\u4e0d\u50cf\u4ed9\u4eba\u3002\u50cf\u662f\u2026\u2026\u9003\u56de\u6765\u7684\u3002', realmGate: '\u6e21\u52ab\u671f', tags: ['terrifying','fate'] },
    { text: '\u6709\u4eba\u5728\u5929\u9645\u770b\u5230\u4e86\u4e00\u5ea7\u6d6e\u7a7a\u57ce\u3002\u57ce\u5899\u4e0a\u523b\u7740\u4e00\u53e5\u8bdd\uff1a\u201c\u5929\u9053\u5df2\u6b7b\uff0c\u4ed9\u4eba\u5f53\u7acb\u201d\u3002\u6ca1\u4eba\u77e5\u9053\u662f\u8c01\u523b\u7684\u3002', realmGate: '\u6e21\u52ab\u671f', tags: ['revelation'] },
  ];

  // ============ 沉浸 v2.0：心念系统（内心独白） ============

  /** @type {Object<string, string[]>} */
  static INNER_VOICES = {
    breakthrough_success: [
      "\u4e39\u7530\u5185\u7075\u6c14\u5982\u6f6e\u6c50\u3002\u6211\u611f\u5230\u81ea\u5df1\u2026\u2026\u53d8\u4e86\u3002",
      "\u8f70\u2014\u2014\u50cf\u662f\u4e00\u6247\u95e8\u88ab\u649e\u5f00\u3002\u95e8\u540e\uff0c\u662f\u5168\u65b0\u7684\u5929\u5730\u3002",
      "\u539f\u6765\u7a81\u7834\u7684\u611f\u89c9\u662f\u8fd9\u6837\u7684\u3002\u4e0d\u662f\u53d8\u5f3a\uff0c\u662f\u53d8\u5f97\u2026\u2026\u5b8c\u6574\u4e86\u3002"
    ],
    breakthrough_fail: [
      "\u4e39\u7530\u50cf\u788e\u88c2\u7684\u74f7\u5668\u3002\u4f46\u88c2\u75d5\u91cc\uff0c\u6709\u91d1\u8272\u7684\u5149\u900f\u51fa\u6765\u3002",
      "\u53c8\u5931\u8d25\u4e86\u3002\u7b2c\u4e09\u6b21\u4e86\u3002\u6211\u54ac\u7740\u7259\u5bf9\u81ea\u5df1\u8bf4\uff1a\u7b2c\u56db\u6b21\uff0c\u4e00\u5b9a\u6210\u3002",
      "\u75bc\u3002\u4f46\u75bc\u8bf4\u660e\u6211\u8fd8\u6d3b\u7740\u3002\u6d3b\u7740\u7684\u4fee\u58eb\uff0c\u6ca1\u6709\u653e\u5f03\u7684\u8d44\u683c\u3002"
    ],
    near_death: [
      "\u8840\u4ece\u5634\u89d2\u6d41\u4e0b\u6765\u3002\u539f\u6765\u4fee\u58eb\u7684\u8840\uff0c\u4e5f\u662f\u54b8\u7684\u3002",
      "\u773c\u524d\u53d1\u9ed1\u3002\u4f46\u6211\u8fd8\u80fd\u770b\u89c1\u90a3\u6761\u8def\u2014\u2014\u90a3\u6761\u5411\u4e0a\u7684\u8def\u3002",
      "\u547d\u60ac\u4e00\u7ebf\u3002\u5947\u602a\u7684\u662f\uff0c\u6211\u53cd\u800c\u4e0d\u6015\u4e86\u3002"
    ],
    meet_companion: [
      "\u5979\u770b\u6211\u7684\u773c\u795e\u91cc\u6709\u4e00\u79cd\u8bf4\u4e0d\u6e05\u7684\u4e1c\u897f\u3002\u50cf\u662f\u2026\u2026\u597d\u5947\u3002",
      "\u539f\u6765\u4fee\u4ed9\u8def\u4e0a\uff0c\u4e5f\u4f1a\u9047\u89c1\u8fd9\u6837\u7684\u4eba\u3002\u4f1a\u5728\u4f60\u8f6c\u8eab\u7684\u65f6\u5019\uff0c\u8ddf\u7740\u4f60\u8d70\u3002"
    ],
    karma_good_surge: [
      "\u6211\u505a\u4e86\u4e00\u4ef6\u597d\u4e8b\u3002\u4e0d\u77e5\u9053\u4e3a\u4ec0\u4e48\uff0c\u5fc3\u91cc\u6696\u6696\u7684\u3002\u8fd9\u5c31\u662f\u2026\u2026\u5584\u56e0\u5417\uff1f",
      "\u638c\u5fc3\u53d1\u71c3\u3002\u4ed9\u9014\u4e0d\u53ea\u662f\u4e89\u3002\u6709\u65f6\u5019\uff0c\u4e5f\u662f\u5b88\u62a4\u3002"
    ],
    karma_bad_surge: [
      "\u6211\u7684\u624b\u5728\u6296\u3002\u4e0d\u662f\u6015\u2014\u2014\u662f\u5174\u594b\u3002\u539f\u6765\u8d70\u8fd9\u6761\u8def\uff0c\u4f1a\u8ba9\u4eba\u2026\u2026\u6d3b\u8fc7\u6765\u3002",
      "\u6709\u4eba\u8bf4\u4fee\u4ed9\u8981\u65ad\u60c5\u7edd\u6b32\u3002\u6211\u89c9\u5f97\u4e0d\u5bf9\u3002\u60c5\u611f\u672c\u8eab\uff0c\u5c31\u662f\u529b\u91cf\u3002",
      "\u6076\u56e0\u50cf\u4e00\u6761\u86c7\uff0c\u7f20\u4e0a\u4e86\u6211\u7684\u810a\u690e\u3002\u4f46\u5b83\u662f\u6e29\u70ed\u7684\u3002"
    ],
    combat_victory: [
      "\u4ed6\u5012\u4e0b\u4e86\u3002\u6211\u7684\u5251\u8fd8\u5728\u9e23\u53eb\u3002\u8fd9\u5c31\u662f\u2026\u2026\u751f\u5b58\u7684\u6ecb\u5473\u3002",
      "\u80dc\u5229\u4e86\u3002\u4f46\u6211\u77e5\u9053\uff0c\u4e0b\u4e00\u4e2a\u654c\u4eba\u4f1a\u66f4\u5f3a\u3002\u8fd9\u5c31\u662f\u4fee\u4ed9\u3002"
    ],
    dao_heart_crack: [
      "\u9053\u5fc3\u52a8\u6447\u4e86\u3002\u6211\u7591\u60d1\u4e86\u4e00\u77ac\u2014\u2014\u6211\u5230\u5e95\u5728\u8d70\u4ec0\u4e48\u8def\uff1f",
      "\u4fe1\u5ff5\u50cf\u6c99\u5821\u4e00\u6837\u5d29\u584c\u4e86\u4e00\u89d2\u3002\u4f46\u6211\u8fd8\u7ad9\u7740\u3002\u53ea\u8981\u8fd8\u7ad9\u7740\uff0c\u5c31\u80fd\u91cd\u5efa\u3002"
    ]
  };

  /**
   * 触发内心独白
   * @param {string} category - 心念类别
   * @param {number} [forceChance] - 强制概率 (0-1)
   */
  _triggerInnerVoice(category, forceChance) {
    if (this._innerVoiceCooldown > 0) return;
    const voices = GameLogic.INNER_VOICES[category];
    if (!voices || voices.length === 0) return;
    const chance = forceChance !== undefined ? forceChance : 0.7;
    if (Math.random() > chance) return;
    const voice = voices[Math.floor(Math.random() * voices.length)];
    this._log(`\u300c${voice}\u300d`, 'inner-voice');
    this._innerVoiceCooldown = 3;
  }

  /**
   * 拍摄属性快照（用于检测大幅变化）
   */
  _snapshotAttrs() {
    this._prevAttrSnap = {
      cultivation: gameState.attributes.cultivation,
      daoHeart: gameState.attributes.daoHeart,
      karmaGood: gameState.attributes.karmaGood,
      karmaBad: gameState.attributes.karmaBad,
      health: gameState.attributes.health
    };
  }

  /**
   * 检测属性大幅变化并触发心念
   */
  _checkAttrSurges() {
    if (!this._prevAttrSnap) return;
    const curr = {
      cultivation: gameState.attributes.cultivation,
      daoHeart: gameState.attributes.daoHeart,
      karmaGood: gameState.attributes.karmaGood,
      karmaBad: gameState.attributes.karmaBad,
      health: gameState.attributes.health
    };

    // 修为暴涨
    if (curr.cultivation - this._prevAttrSnap.cultivation >= 15) {
      this._triggerInnerVoice('breakthrough_success', 0.7);
    }
    // 道心重创
    if (this._prevAttrSnap.daoHeart - curr.daoHeart >= 10) {
      this._triggerInnerVoice('dao_heart_crack', 0.8);
    }
    // 善因激增
    if (curr.karmaGood - this._prevAttrSnap.karmaGood >= 10) {
      this._triggerInnerVoice('karma_good_surge', 0.6);
    }
    // 恶因激增
    if (curr.karmaBad - this._prevAttrSnap.karmaBad >= 10) {
      this._triggerInnerVoice('karma_bad_surge', 0.6);
    }
  }

  /**
   * Load chapter definitions and restore consumed milestones before any other
   * runtime system can persist. On a browser reload GameStateManager already
   * owns the authenticated chapter snapshot; exporting an unhydrated chapter
   * registry even once would replace it with an empty milestone list.
   *
   * @returns {boolean}
   */
  _initializeRealmChapters() {
    const chapters = this.chapterSystem;
    if (!chapters) return false;

    try {
      const milestoneData = dataLoader.loadSync('cards:chapter_milestones');
      if (!milestoneData) {
        this._log('[系统] 里程碑卡牌数据加载失败，章节系统降级。');
        return false;
      }

      chapters.init(milestoneData);
      if (this.gameState?.chapterProgress
        && typeof chapters.hydrateProgress === 'function') {
        chapters.hydrateProgress(this.gameState.chapterProgress);
      }
      this._log('【章节】六章主线已就绪。');
      return true;
    } catch (error) {
      this._log('[系统] 章节系统初始化异常：' + error.message);
      return false;
    }
  }

  init() {
    if (this.gameState) {
      this.gameState._getAggregatedPassives = this._getAggregatedPassives.bind(this);
    }
    // Restore consumed milestones before card/shop/market/system initialization.
    // Several of those systems may legitimately persist during init.
    this._initializeRealmChapters();
    // 初始化卡牌系统（预加载炼气+筑基）
    this.cardSystem.init();
    if (typeof narrativeLedger !== 'undefined' && narrativeLedger) {
      const causalGraph = dataLoader.loadSync('narrative:causal_graph');
      narrativeLedger.init({
        cardResolver: id => this.cardSystem.getCard(id),
        causalGraph
      });
    }

    // 初始化因果系统
    karmaSystem.init();

    // 初始化法宝系统
    treasureSystem.init();

    // 初始化天机图谱系统
    if (typeof evidenceAtlasSystem !== 'undefined' && evidenceAtlasSystem) {
      evidenceAtlasSystem.init();
      const atlasData = dataLoader.loadSync('world:truth_atlas');
      if (atlasData) {
        evidenceAtlasSystem.loadData(atlasData);
      }
    }

    // 初始化功法技能系统
    pathSkillSystem.init();
    if (typeof pathArchetypeSystem !== 'undefined' && pathArchetypeSystem) {
      pathArchetypeSystem.init();
    }
    if (typeof tradeRouteSystem !== 'undefined' && tradeRouteSystem) {
      tradeRouteSystem.init();
    }
    if (typeof lineageSystem !== 'undefined' && lineageSystem) {
      lineageSystem.init();
    }
    if (typeof worldPulseSystem !== 'undefined' && worldPulseSystem) {
      worldPulseSystem.init();
    }

    // 初始化战斗系统
    if (typeof deckCombatSystem !== 'undefined') {
        deckCombatSystem.init();
    }

    // 初始化商店系统
    if (typeof shopSystem !== 'undefined' && shopSystem) {
      shopSystem.init();
    }

    // 初始化支线系统并加载支线数据
    questSystem.init();

    // 尝试加载支线数据
    const whiteFoxData = dataLoader.loadSync('quests:white_fox');
    if (whiteFoxData) {
      questSystem.loadQuest(whiteFoxData);
    }
    const tianshuData = dataLoader.loadSync('quests:tianshu_codex');
    if (tianshuData) {
      questSystem.loadQuest(tianshuData);
    }
    const bodyTrialData = dataLoader.loadSync('quests:body_tribulation');
    if (bodyTrialData) {
      questSystem.loadQuest(bodyTrialData);
    }
    const swordLegacyData = dataLoader.loadSync('quests:sword_legacy');
    if (swordLegacyData) {
      questSystem.loadQuest(swordLegacyData);
    }
    const spellCodexData = dataLoader.loadSync('quests:spell_codex');
    if (spellCodexData) {
      questSystem.loadQuest(spellCodexData);
    }
    const pillMasterData2 = dataLoader.loadSync('quests:pill_master');
    if (pillMasterData2) {
      questSystem.loadQuest(pillMasterData2);
    }
    if (typeof questSystem.finalizeLoadedState === 'function') {
      questSystem.finalizeLoadedState();
    }

    // 初始化剧情网系统（叙事元系统）
    if (typeof storyNetworkSystem !== 'undefined' && storyNetworkSystem) {
      storyNetworkSystem.init();
    }

    // ── 故事线程引擎初始化 (StoryThreadEngine) ──
    const activeThreadEngine = this.storyThreadEngine ||
      (typeof storyThreadEngine !== 'undefined' && storyThreadEngine
        ? storyThreadEngine
        : (typeof threadEngine !== 'undefined' ? threadEngine : null));
    if (activeThreadEngine) {
      this._loadStoryThreadDefinitions(activeThreadEngine);
      this._log('【剧情】六境故事线程引擎已加载。');
    }

    // ── v2.0 上瘾引擎初始化 ──
    if (typeof destinyWheelSystem !== 'undefined' && destinyWheelSystem) {
      destinyWheelSystem.init();
      destinyWheelSystem.onLog = (msg) => this._log(msg);
    }
    if (typeof legacyFragmentSystem !== 'undefined' && legacyFragmentSystem) {
      legacyFragmentSystem.init();
      legacyFragmentSystem.setDeckAuthority(this.skillCardAcquisitionSystem);
      legacyFragmentSystem.onLog = (msg) => this._log(msg);
    }
    if (typeof karmaRippleSystem !== 'undefined' && karmaRippleSystem) {
      karmaRippleSystem.init();
      karmaRippleSystem.onLog = (msg) => this._log(msg);
    }
    if (typeof heavensHintSystem !== 'undefined' && heavensHintSystem) {
      heavensHintSystem.init();
      heavensHintSystem.onLog = (msg) => this._log(msg);
    }
    if (typeof marketSystem !== 'undefined' && marketSystem) {
      marketSystem.init();
      marketSystem.onLog = (msg) => this._log(msg);
    }

    // 初始化配置
    const realmsConfig = dataLoader.loadSync('config:realms');
    const pathsConfig = dataLoader.loadSync('config:paths');
    gameState.init({
      realms: realmsConfig,
      paths: pathsConfig
    });

    // 初始化 FlowDirector 核心调度
    if (typeof flowDirector !== 'undefined' && flowDirector) {
      flowDirector.init();
    }
    if (this.choiceOutcomeRouter && typeof this.choiceOutcomeRouter.init === 'function') {
      this.choiceOutcomeRouter.init({
        gameStateRef: this.gameState,
        eventBusRef: this.eventBus,
        ledgerRef: typeof narrativeLedger !== 'undefined' ? narrativeLedger : null,
        flowDirectorRef: typeof flowDirector !== 'undefined' ? flowDirector : null,
        cardResolver: id => this.cardSystem.getCard(id)
      });
    }

    // FIX-1: 接通位置/场景系统 — 加载位置数据并设置初始位置
    if (typeof sceneLayerSystem !== 'undefined' && sceneLayerSystem) {
      const locData = dataLoader.loadSync('locations:locations');
      if (locData) {
        sceneLayerSystem.loadData(locData);
      }
      // 恢复档必须留在持久化地点；新档的 GameState 默认值仍是宗门。
      sceneLayerSystem.transition(gameState.currentLocation || '宗门',
        gameState._restoredCausalSession ? 'game_restore' : 'game_start');
    }

    // 监听事件
    this.eventBus.on('state:death', (data) => this._onDeath(data));
    this.eventBus.on('game:restart', () => {
      this.start(gameState.path || 'sword');
    });
    // 终极结局事件：EffectService 触发后，切换到对应结局卡
    this.eventBus.on('game:ending', (data) => {
      const endingId = gameState.endingId;
      const endingCardId = gameState.pendingCardId;
      if (!endingId || endingCardId !== `ending_${endingId}` || data.endingType !== endingId) {
        console.error('[GameLogic] 终局事件与权威状态不一致，拒绝猜测结局卡。');
        return;
      }
      const endingCard = cardSystem.getCard(endingCardId);
      if (endingCard) {
        this.currentCard = endingCard;
        this._log(`【仙途终局】进入结局：${endingCard.title}`);
      } else {
        console.error(`[GameLogic] 权威结局卡不存在：${endingCardId}`);
        this.currentCard = null;
      }
      this._triggerUpdate();
    });
    this.eventBus.on('quest:triggered', (data) => this._onQuestTriggered(data));
    this.eventBus.on('quest:completed', (data) => this._onQuestCompleted(data));
    // 支线推进事件：暂存下一张卡ID，避免依赖 choice.nextCard 的数据污染
    this.eventBus.on('quest:advanced', (data) => {
      this._questNextCardId = data.nextCardId || null;
    });
    this.eventBus.on('karma:seedPlanted', (data) => this._onKarmaSeedPlanted(data));
    this.eventBus.on('combat:victory', (data) => {
      const settled = this.combatCoordinator.onVictory(data);
      data.outcomeAccepted = settled === true;
      if (!settled || typeof marketSystem === 'undefined' || !marketSystem?.applyGhostOathDebtPressure) return settled;
      const receipt = marketSystem.applyGhostOathDebtPressure({
        encounterInstanceId: data?.encounterContext?.encounterInstanceId,
        decisionIndex: gameState.getDecisionIndex?.() ?? gameState.runClock?.decisionIndex ?? gameState.turn
      });
      if (receipt?.processed) {
        const advanced = receipt.receipts.filter(entry => entry.advanced).length;
        this._log(`【夜契】剑鸣之后，${advanced > 0 ? '债期被催近了一步' : '债主暂未收紧回执'}（${receipt.receipts.length} 笔契约已记账）。`);
      }
      return settled;
    });
    this.eventBus.on('combat:defeat', (data) => this.combatCoordinator.onDefeat(data));
    this.eventBus.on('combat:fled', (data) => this.combatCoordinator.onFled(data));
    // 【故事线程】引擎日志 → 游戏日志区
    this.eventBus.on('game:log', (msg) => this._log(msg));

    // 【EX-05 / P1-01 规范】秘境完成与三分结算机制（成功通关 / 中途正常退出 / 失败及异常离场）
    this.eventBus.on('dungeon:completed', (data) => {
      if (!this.cardSystem.consumeDungeonSettlement(data)) {
        if (this.debug) console.warn('[DungeonSettlement] ignored unauthenticated or duplicate settlement');
        return;
      }
      const success = Boolean(data && data.success);
      const outcome = data && data.outcome;
      const reason = data && data.reason;

      if (success) {
        // 1. 成功通关：发放通关奖励（依据 §6.2 预算：3-5 修为, 2-4 灵石）
        let cultReward = 3 + Math.floor(Math.random() * 3);
        let stoneReward = 2 + Math.floor(Math.random() * 3);
        const passives = gameState._getAggregatedPassives ? gameState._getAggregatedPassives() : {};
        if (passives.dungeonBonus) {
          cultReward += passives.dungeonBonus;
          stoneReward += passives.dungeonBonus;
        }
        gameState.addAttribute('cultivation', cultReward);
        gameState.addResource('spiritStone', null, stoneReward);
        this._log(`【秘境通关】探险圆满：修为 +${cultReward}，灵石 +${stoneReward}${passives.dungeonBonus ? '（含五行精通加成）' : ''}`);
      } else if (outcome === 'abandon' || reason === 'user_exit' || reason === 'abandon') {
        // 2. 中途正常退出：保留已探索所得，不重复发通关大奖
        this._log(`【秘境离场】你见好即收，安全离开了秘境。`);
      } else {
        // 3. 失败/未知异常（如 missing_dungeon / combat_loss）：零通关奖励，记载失败日志
        this._log(`【秘境失败】未能走完秘境探险 (${reason || '未能完成'})，无通关奖励。`);
      }
      // The active CardSystem run authenticated this settlement before any
      // story trigger can observe it. Keep the per-life receipt in the same
      // causal snapshot as rewards, lineage, and the cleared dungeon run.
      if (data.sourceCardId) gameState.recordDungeonOutcome?.(data);
      this.eventBus.emit('dungeon:settled', data);
      if (data.settlementOwnsTransaction) {
        let persisted = false;
        try { persisted = gameState.persistCausalSession?.({ force: true }) === true; } catch (error) { persisted = false; }
        if (!persisted) {
          gameState.rollbackCausalTransaction?.();
          data.settlementAccepted = false;
          return;
        }
        gameState.finishCausalTransaction?.();
      } else {
        // A source decision owns the surrounding transaction and its final save.
        gameState.persistCausalSession?.();
      }
      data.settlementAccepted = true;
    });
    this.eventBus.on('dungeon:entryRejected', (data) => {
      const id = data?.dungeonId || '未知入口';
      this._log(`【秘境封闭】${id} 的入口已经失效，你仍可继续当前行程。`);
    });

    // 【商店系统】商店关闭后继续卡牌流
    this.eventBus.on('shop:closed', (summary) => {
      this._handleVendorClosed(summary);
    });

    // ── 叙事连贯性层（效果叙事 + 卡牌过渡 + 交叉引用）──
    if (typeof coherenceLayer !== 'undefined' && coherenceLayer) {
      coherenceLayer.init();
    }

  }

  /**
   * 开始游戏
   * @param {string} path - 功法路径
   */
  start(path) {
    this.discardChoiceSettlement();
    const isReincarnationStart = Boolean(
      gameState.getLifeCount?.() > 0
      && !gameState.path
      && Array.isArray(gameState.deck)
      && gameState.deck.length === 0
    );
    if (typeof gameState.beginFreshSession === 'function') gameState.beginFreshSession();
    else {
      gameState.reset(true);
      if (gameState.unlocks) gameState.unlocks.storyThreadState = null;
    }
    this._resetStoryThreadsForNewSession();
    gameState.path = path;
    if (this.cardSystem && typeof this.cardSystem.refreshCombatEncounterCards === 'function') {
      this.cardSystem.refreshCombatEncounterCards(path);
    }
    if (this.skillCardAcquisitionSystem) {
      const starterResult = this.skillCardAcquisitionSystem.grantStarterDeck(path, {
        sourceType: 'starter_path',
        sourceId: `path_select:${path}`
      });
      if (!starterResult?.acquired) {
        this._log(`【牌组】起始牌组未能初始化：${starterResult?.reason || 'unknown'}`);
      }
    }
    if (isReincarnationStart
      && typeof legacyFragmentSystem !== 'undefined'
      && legacyFragmentSystem
      && typeof legacyFragmentSystem.beginInheritanceChoice === 'function') {
      legacyFragmentSystem.beginInheritanceChoice({ path });
    }
    this._pendingRealmTransitionCard = null;
    this._innerVoiceCooldown = 0;
    this._chapterMilestoneCard = null;

    // 【P0 修复 #2】清除结局标志，新一周目可正常转世
    if (gameState.hasFlag('game_ended')) {
      delete gameState.flags.game_ended;
    }

    // 转世先承接轮回之选；首局教程仍先于功法序章。
    if (isReincarnationStart) {
      this.currentCard = cardSystem.getCard('rebirth_boon');
      this._log(`【轮回新生】你选择以${gameState.getPathName(path)}重踏仙途。`);
    } else if (this.isFirstPlay()) {
      const tutorialCard = cardSystem.getCard('tutorial_1');
      if (tutorialCard) {
        this.currentCard = tutorialCard;
        this._log('【引导】初入仙途，请跟随指引了解修仙法则。');
      } else {
        this.currentCard = null;
      }
    } else {
      // ── 4大修仙流派专属开场序章卡 ──
      const prologueCardId = 'q_start_' + (path || 'sword');
      const prologueCard = cardSystem.getCard(prologueCardId);
      if (prologueCard) {
        this.currentCard = prologueCard;
        this._log(`【仙途开端】你选择踏入 ${gameState.getPathName(path)} 之道。`);
      } else {
        this.currentCard = null;
      }
    }

    // ── 重置章节系统 ──
    if (typeof chapterSystem !== 'undefined' && chapterSystem) {
      chapterSystem.reset();
    }

    const playerName = gameState.playerName || '\u53f6\u51cc\u4e91';
    this._log(`${playerName}\uff0c\u4ed9\u9014\u4e4b\u8def\uff0c\u81ea\u6b64\u5f00\u59cb\u3002`);
    this._log(`\u4f60\u9009\u62e9\u4e86 ${gameState.getPathName(path)} \u4e4b\u9053\u3002`);
    this._snapshotAttrs();

    // ── 道侣沉浸 v2.5：激活已有道侣到 HUD ──
    this._activateCompanionToHUD();

    // 应用功法加成
    if (gameState.config.paths && gameState.config.paths.paths[path]) {
      const bonuses = gameState.config.paths.paths[path].bonuses;
      if (bonuses) {
        for (const [key, value] of Object.entries(bonuses)) {
          if (key === 'spiritStone') {
            gameState.addResource('spiritStone', null, value);
          } else if (key === 'health') {
            // 微数值模型：如果功法增减血量，同时对应调整上限 maxHealth，防止溢出或降为0
            gameState.maxHealth = Math.max(1, gameState.maxHealth + value);
            gameState.setAttribute('health', gameState.attributes.health + value);
          } else if (key === 'daoHeart') {
            // 微数值模型：如果功法增减道心，同时对应调整上限 maxDaoHeart
            gameState.maxDaoHeart = Math.max(1, gameState.maxDaoHeart + value);
            gameState.setAttribute('daoHeart', gameState.attributes.daoHeart + value);
          } else if (['cultivation', 'fortune'].includes(key)) {
            gameState.addAttribute(key, value);
          }
        }
      }
    }

    // beginFreshSession clears the GSM-owned market plan without rebuilding
    // its service instance. Initialize this life's missing dates after the
    // final reset and path bonuses, before any first-card checkpoint is saved.
    this.marketSystem?.ensureCadence?.();

    // The first card of a reincarnated life is an actual unresolved decision.
    // Persist its authored card ID after path bonuses are applied so refresh
    // restores the same rebirth-memory identity instead of silently drawing
    // a normal qi card.
    if (isReincarnationStart && this.currentCard?.id === 'rebirth_boon') {
      this._commitDecisionCheckpoint('reincarnation:path_selected');
    }
    this._triggerUpdate();
    this.eventBus.emit('path:selected', {
      path,
      newSession: true,
      reincarnation: isReincarnationStart,
      playerIdentityId: 'protagonist_yelingyun'
    });
  }

  hasRecoverableSession() {
    return Boolean(
      gameState &&
      gameState._restoredCausalSession &&
      typeof gameState.hasRecoverableCausalSession === 'function' &&
      gameState.hasRecoverableCausalSession()
    );
  }

  resumeSession() {
    if (!this.hasRecoverableSession()) return false;
    // A shown dynamic NPC decision outranks a new Flow/Thread arbitration.
    // Validate before consuming the resume flag or mutating any world state;
    // a malformed save must not silently downgrade to a fresh random card.
    const npcCheckpoint = typeof gameState.decisionCheckpoint?.cardId === 'string'
      && gameState.decisionCheckpoint.cardId.startsWith('npc_encounter_')
      ? gameState.decisionCheckpoint : null;
    let restoredNpcCard = null;
    if (npcCheckpoint) {
      if (gameState.combatSession || gameState.marketState?.activeSession
        || typeof this.npcSystem?.restoreEncounterCheckpoint !== 'function') return false;
      restoredNpcCard = this.npcSystem.restoreEncounterCheckpoint(npcCheckpoint);
      if (!restoredNpcCard) return false;
    }
    const generatedCheckpoint = gameState.decisionCheckpoint;
    const generatedCardId = generatedCheckpoint?.cardId || '';
    const generatedKind = generatedCardId.startsWith('karma_ripple:') ? 'ripple'
      : generatedCardId.startsWith('heavens_hint:') ? 'hint' : null;
    let restoredGeneratedCard = null;
    if (generatedKind) {
      if (gameState.combatSession || gameState.marketState?.activeSession) return false;
      const producer = generatedKind === 'ripple'
        ? (typeof karmaRippleSystem !== 'undefined' ? karmaRippleSystem : null)
        : (typeof heavensHintSystem !== 'undefined' ? heavensHintSystem : null);
      restoredGeneratedCard = producer?.restorePendingCard?.(generatedCheckpoint.cardSnapshot) || null;
      if (!restoredGeneratedCard || restoredGeneratedCard.id !== generatedCardId) return false;
    }
    // The consequence owns presentation, while the ordinary checkpoint still
    // owns any authored continuation underneath it. Never ask Flow for a new
    // card merely to reconstruct an unresolved breakthrough failure.
    const pendingInnerDemon = this._innerDemonActive && !gameState.dead;
    let interruptedCard = null;
    if (pendingInnerDemon) {
      if (gameState.combatSession || gameState.marketState?.activeSession) return false;
      const checkpoint = gameState.decisionCheckpoint;
      interruptedCard = restoredNpcCard || (checkpoint?.cardId
        ? this.cardSystem?.getCard?.(checkpoint.cardId) : null) || null;
      if (!interruptedCard && checkpoint?.cardSnapshot
        && checkpoint.cardSnapshot.id === checkpoint.cardId
        && this._isRecoverableCombatOutcomeCard(checkpoint.cardSnapshot)
        && this._canRestoreDecisionSnapshot(checkpoint.cardSnapshot, gameState.realmTransition)) {
        interruptedCard = JSON.parse(JSON.stringify(checkpoint.cardSnapshot));
      }
      if (checkpoint?.cardId && !interruptedCard) return false;
    }
    if (!gameState.consumeRestoredCausalSession()) return false;
    this.discardChoiceSettlement();

    if (this.chapterSystem
      && typeof this.chapterSystem.hydrateProgress === 'function'
      && gameState.chapterProgress) {
      this.chapterSystem.hydrateProgress(gameState.chapterProgress);
    }
    if (typeof flowDirector !== 'undefined' && flowDirector
      && typeof flowDirector.hydrateState === 'function'
      && gameState.flowState) {
      flowDirector.hydrateState(gameState.flowState);
    }
    if (pendingInnerDemon) {
      this.currentCard = interruptedCard;
      this._snapshotAttrs();
      this._log('【续写前缘】突破失败后的心魔仍待你抉择。');
      this._triggerUpdate();
      return true;
    }
    if (restoredNpcCard) {
      this.currentCard = restoredNpcCard;
      this._snapshotAttrs();
      this._log(`【续写前缘】${restoredNpcCard.title}`);
      this._triggerUpdate();
      return true;
    }
    const activeDeckCombat = this.combatCoordinator?.deckCombatSystem
      || (typeof deckCombatSystem !== 'undefined' ? deckCombatSystem : null);
    if (gameState.combatSession && activeDeckCombat
      && typeof activeDeckCombat.hydrateState === 'function') {
      const restoredCombat = activeDeckCombat.hydrateState(gameState.combatSession, {
        present: false
      });
      if (restoredCombat) {
        const upgradedCombatSession = typeof activeDeckCombat.exportState === 'function'
          ? activeDeckCombat.exportState()
          : null;
        if (upgradedCombatSession) gameState.combatSession = upgradedCombatSession;
        const coordinatorRestored = typeof this.combatCoordinator?.restoreActiveCombat !== 'function'
          || this.combatCoordinator.restoreActiveCombat(gameState.combatSession);
        if (coordinatorRestored) {
          this.currentCard = JSON.parse(JSON.stringify(gameState.combatSession.originalCard));
          this._snapshotAttrs();
          if (typeof gameState.persistCausalSession === 'function') {
            gameState.persistCausalSession();
          }
          this._log(`【续写战局】第 ${activeDeckCombat.turn} 回合的${activeDeckCombat.phase === 'REACTION_OPEN' ? '反应窗口' : '出牌阶段'}已恢复。`);
          return true;
        }
        activeDeckCombat.reset();
      }
      gameState.combatSession = null;
    }
    const resumedPromise = this.choiceOutcomeRouter
      && typeof this.choiceOutcomeRouter.resumePendingPromises === 'function'
      ? this.choiceOutcomeRouter.resumePendingPromises()
      : null;
    const pendingPromiseCard = resumedPromise?.immediateCard || null;

    const persistedVendor = gameState.marketState?.activeSession || null;
    if (persistedVendor && persistedVendor.status === 'result' && persistedVendor.resultCard) {
      this._pendingVendorChoiceContext = null;
      this.currentCard = JSON.parse(JSON.stringify(persistedVendor.resultCard));
      this._snapshotAttrs();
      this._log('【续写前缘】坊市交易结果已恢复。');
      this._triggerUpdate();
      return true;
    }
    if (persistedVendor && persistedVendor.status === 'open') {
      const sessionKey = persistedVendor.sessionKey || this._buildVendorSessionKey(
        persistedVendor.card,
        persistedVendor.vendorId,
        persistedVendor.openedAtTurn
      );
      this._pendingVendorChoiceContext = {
        card: persistedVendor.card,
        direction: persistedVendor.direction,
        choice: persistedVendor.choice,
        vendorId: persistedVendor.vendorId,
        entryCardId: persistedVendor.entryCardId || persistedVendor.card?.id || null,
        sessionKey,
        settled: false
      };
      persistedVendor.sessionKey = sessionKey;
      this.currentCard = this._buildVendorPendingCard(persistedVendor.card);
      this.eventBus.emit('shop:open', {
        items: Array.isArray(persistedVendor.immutableOffers) ? persistedVendor.immutableOffers : [],
        vendorId: persistedVendor.vendorId,
        marketType: persistedVendor.marketType,
        entryCardId: persistedVendor.entryCardId || persistedVendor.card?.id || null,
        sessionKey,
        resumePolicy: persistedVendor.choice?.action?.resumePolicy,
        settlePolicy: persistedVendor.choice?.action?.settlePolicy,
        summary: persistedVendor.summary || null,
        session: persistedVendor,
        ...(persistedVendor.vendorMeta || {})
      });
      this._snapshotAttrs();
      this._log('【续写前缘】坊市报价与未结算行程已恢复。');
      this._triggerUpdate();
      return true;
    }

    const activeThreadEngine = this.storyThreadEngine ||
      (typeof storyThreadEngine !== 'undefined' && storyThreadEngine
        ? storyThreadEngine
        : (typeof threadEngine !== 'undefined' ? threadEngine : null));
    const pendingThreadCard = !restoredGeneratedCard && activeThreadEngine &&
      typeof activeThreadEngine.getNextThreadCard === 'function'
      ? activeThreadEngine.getNextThreadCard(gameState)
      : null;
    let persistedCard = restoredGeneratedCard;
    const checkpointCardId = gameState.decisionCheckpoint
      && typeof gameState.decisionCheckpoint.cardId === 'string'
      ? gameState.decisionCheckpoint.cardId
      : null;
    const cardApi = this.cardSystem
      || (typeof cardSystem !== 'undefined' ? cardSystem : null);
    if (!persistedCard && checkpointCardId && cardApi && typeof cardApi.getCard === 'function') {
      persistedCard = cardApi.getCard(checkpointCardId);
    }
    const checkpointSnapshot = gameState.decisionCheckpoint?.cardSnapshot;
    const restoredWarningCard = !persistedCard
      ? this._restoreCombatWarningCheckpoint(
        gameState.decisionCheckpoint,
        pendingThreadCard,
        cardApi
      )
      : null;
    if (restoredWarningCard) persistedCard = restoredWarningCard;
    if (!persistedCard
      && checkpointSnapshot?.id === checkpointCardId
      && this._isRecoverableCombatOutcomeCard(checkpointSnapshot)
      && this._canRestoreDecisionSnapshot(checkpointSnapshot, gameState.realmTransition)) {
      persistedCard = JSON.parse(JSON.stringify(checkpointSnapshot));
    }
    if (!persistedCard) {
      persistedCard = this._restoreRealmTransitionCard(gameState.realmTransition);
    }
    // A non-terminal realm gate has already settled its combat rewards before
    // this choice appears.  Its inheritance offers are intentionally rebuilt
    // from the authenticated realm transaction + authored gate, never restored
    // from a mutable serialized reward-card snapshot.
    if (!persistedCard
      && checkpointCardId === 'breakthrough_reward'
      && gameState.realmTransition?.status === 'inheritance_pending'
      && gameState.realmTransition.sourceCardId === gameState.decisionCheckpoint?.sourceCardId
      && this.combatCoordinator
      && typeof this.combatCoordinator.restorePendingRealmTransitionReward === 'function') {
      persistedCard = this.combatCoordinator.restorePendingRealmTransitionReward(gameState.realmTransition);
    }
    if (!persistedCard && gameState.pendingCardId === 'breakthrough_reward'
      && this.combatCoordinator
      && typeof this.combatCoordinator.restorePendingTerminalReward === 'function') {
      persistedCard = this.combatCoordinator.restorePendingTerminalReward();
    } else if (!persistedCard && gameState.pendingCardId && cardApi) {
      persistedCard = cardApi.getCard(gameState.pendingCardId);
    }
    const pendingFlowCard = !pendingPromiseCard && !persistedCard && !pendingThreadCard && !gameState.pendingCardId
      && typeof flowDirector !== 'undefined'
      && flowDirector
      && typeof flowDirector.getNextCard === 'function'
      ? flowDirector.getNextCard()
      : null;
    // A presented StoryThread node is an unaccepted decision, not a mere queue
    // suggestion. Dynamic thread cards are not in CardSystem, so checkpoint
    // lookup cannot restore them; replay the engine's exact pending node before
    // Flow is allowed to draw an unrelated ordinary/ambient card.
    if (pendingPromiseCard && persistedCard?.id && !this._questNextCardId
      && cardApi?.getCard?.(persistedCard.id)) {
      this._questNextCardId = persistedCard.id;
    }
    this.currentCard = pendingPromiseCard || persistedCard || pendingThreadCard || pendingFlowCard || null;
    this._pendingRealmTransitionCard = null;
    this._innerVoiceCooldown = 0;
    this._chapterMilestoneCard = null;
    this._snapshotAttrs();
    this._log(
      this.currentCard
        ? `【续写前缘】${this.currentCard.title || this.currentCard.id}`
        : '【续写前缘】因果与修行状态已从上次离开处恢复。'
    );
    this._triggerUpdate();
    return true;
  }

  claimLegacyBossReward(setId) {
    if (typeof legacyFragmentSystem === 'undefined' || !legacyFragmentSystem) {
      return { claimed: false, reason: 'legacy_system_unavailable' };
    }
    const result = legacyFragmentSystem.claimBossReward(setId);
    if (result.claimed) {
      // 完整合成反馈由 LegacyFragmentSystem 使用同一权威完成结果记录，
      // 此处只为未触发合成的普通残卷补充领取提示，避免重复播报。
      if (!Array.isArray(result.completions) || result.completions.length === 0) {
        this._log('【传承】Boss 残卷已记入传承档案。');
      }
    } else if (result.reason === 'completion_pending') {
      this._log('【传承】绝学发放暂未完成，残卷选择仍保留，可稍后重试。');
    }
    this._triggerUpdate();
    return result;
  }

  claimLegacyInheritance(setId) {
    if (typeof legacyFragmentSystem === 'undefined'
      || !legacyFragmentSystem
      || typeof legacyFragmentSystem.claimInheritance !== 'function') {
      return { claimed: false, reason: 'legacy_system_unavailable' };
    }
    const result = legacyFragmentSystem.claimInheritance(setId);
    this._triggerUpdate();
    return result;
  }

  setFocusedLegacySet(setId) {
    if (typeof legacyFragmentSystem === 'undefined' || !legacyFragmentSystem) {
      return { changed: false, reason: 'legacy_system_unavailable', focusedSetId: null };
    }
    const result = legacyFragmentSystem.setFocusedSet(setId, { path: gameState.path });
    if (result.changed) {
      const focusedName = result.focusedSetId
        ? legacyFragmentSystem.getProgress()?.[result.focusedSetId]?.name || result.focusedSetId
        : null;
      this._log(result.focusedSetId
        ? `【传承】已追踪${focusedName}，普通选择掉落权重为 60%。`
        : '【传承】已停止追踪，普通选择掉落将均分至合法传承。');
      this._triggerUpdate();
    }
    return result;
  }

  _resetStoryThreadsForNewSession() {
    const activeThreadEngine = this.storyThreadEngine ||
      (typeof storyThreadEngine !== 'undefined' && storyThreadEngine
        ? storyThreadEngine
        : (typeof threadEngine !== 'undefined' ? threadEngine : null));
    if (!activeThreadEngine) return;
    this._loadStoryThreadDefinitions(activeThreadEngine);
  }

  _loadStoryThreadDefinitions(activeThreadEngine) {
    if (!activeThreadEngine) return 0;
    activeThreadEngine.init();
    let loaded = 0;
    for (const moduleName of GameLogic.STORY_THREAD_MODULE_NAMES) {
      const data = dataLoader.loadSync(moduleName);
      if (!data) continue;
      activeThreadEngine.loadThreadData(data);
      loaded++;
    }
    if (typeof activeThreadEngine.reconcileRealm === 'function') {
      activeThreadEngine.reconcileRealm(gameState);
    }
    return loaded;
  }

  /**
   * 检测是否为首次游玩（新手引导判断）
   * 兼容旧存档：已转世或有解锁记录的玩家视为已完成引导
   */
  isFirstPlay() {
    if (gameState.unlocks.tutorialCompleted === true) return false;
    if (gameState.unlocks.tutorialCompleted === false) return true;
    // 旧存档兼容：有转世记录或已解锁卡牌 → 已完成引导
    if ((gameState.unlocks.lifeCount || 0) > 0 || (gameState.unlocks.cards || []).length > 0) {
      gameState.unlocks.tutorialCompleted = true;
      gameState._saveUnlocks();
      return false;
    }
    return true;
  }

  // ============ 抽卡与选择 ============

  _getNextCardFromAuthoritativeFlow() {
    const nextCard = typeof flowDirector !== 'undefined' && flowDirector
      ? flowDirector.getNextCard()
      : cardSystem.draw();

    // A choice may create an immediate promise result and kill the player in
    // the same transaction. Once Flow replaces that result with a death card,
    // the death card is the only visible/authoritative terminal response. Close
    // the promise here, before any later getCurrentCard/reincarnation reset can
    // erase the one-life ownership context.
    if (gameState.dead && this._pendingPromiseResultCard && nextCard?.id) {
      this.choiceOutcomeRouter?.resolvePromiseAtTerminal?.(
        this._pendingPromiseResultCard,
        nextCard,
        nextCard.id.startsWith('ending_') ? 'ending_closed_life' : 'source_choice_caused_death'
      );
      this._pendingPromiseResultCard = null;
    }

    return nextCard;
  }

  /**
   * A location card may arrive through ordinary flow or through an authored
   * post-choice continuation (for example, a combat reward). Both are real
   * player-facing arrivals. Keep the location authority in SceneLayerSystem
   * instead of allowing a direct `nextCard` assignment to leave the world
   * state and the visible card describing different places.
   */
  _syncCardDrivenLocation(card, reason = 'card_driven') {
    if (!card?.location || card.requiresPlayerPresence === true
        || typeof sceneLayerSystem === 'undefined' || !sceneLayerSystem) {
      return false;
    }
    const state = this.gameState || (typeof gameState !== 'undefined' ? gameState : null);
    if (!state || state.currentLocation === card.location) return false;
    sceneLayerSystem.transition(card.location, reason);
    return true;
  }

  /**
   * 只有纯强制战斗才可被全局入口接管。
   * 带 triggerCombat 选项的 COMBAT 卡本质是“交涉后可能开战”的叙事卡，
   * 必须先展示选择，不能因为 type 被提前吞掉。
   */
  _isImmediateCombatCard(card) {
    if (!card) return false;
    if (card.type === 'FORCED_COMBAT' || card.type === 'BOSS_COMBAT') return true;
    const taggedCombat = Array.isArray(card.tags) && card.tags.includes('combat');
    if (card.type !== 'COMBAT' && !taggedCombat) return false;
    const choices = card.choices ? Object.values(card.choices) : [];
    const hasChoiceDrivenCombat = choices.some(choice =>
      choice && (choice.triggerCombat || (choice.effects && choice.effects.triggerCombat))
    );
    return !hasChoiceDrivenCombat;
  }

  /**
   * 获取当前卡牌
   * @returns {Object}
   */
  getCurrentCard() {
    if (this._choiceAttemptActive && this._nestedCheckpointRejected) return null;
    const checkpointOwnedByChoice = this._choiceAttemptActive === true
      && Boolean((this.gameState || gameState)?._causalTransaction);
    if (this.combatCoordinator && this.combatCoordinator.isInCombat()) {
      return this.combatCoordinator.getCombatCard();
    }

    // ── v2.0 心魔反噬卡 ──
    if (this._innerDemonActive && !gameState.dead) {
      return this._buildInnerDemonCard();
    }

    // ── v2.0 命盘轮转卡 ──
    if (typeof destinyWheelSystem !== 'undefined' && destinyWheelSystem && destinyWheelSystem.active) {
      return { type: 'DESTINY_WHEEL', wheelState: destinyWheelSystem.getState() };
    }

    // 首局教学战后的山径是由战斗结算直接持有的 currentCard，不一定会
    // 再经过 FlowDirector → CardSystem.getCard()。在这里统一投影其路径
    // lens，避免缓存中的基础剑修文案/通用 promise 被序列化续卡重新带回。
    // 这只改展示和已署名的 nextCard；遭遇、战利品、地点与坊市会话仍由
    // 原有系统拥有，不能在首局另建一套状态机。
    if (this.currentCard && this.cardSystem
      && typeof this.cardSystem._applyFirstSessionRouteLens === 'function') {
      this.currentCard = this.cardSystem._applyFirstSessionRouteLens(
        this.currentCard,
        this.gameState || gameState
      );
    }

    // 秘境战斗会临时把“预警/战果”放进 currentCard。它们属于当前秘境
    // 事务，必须先于节点重绘；否则预警会被原 Boss 节点覆盖，战果也会
    // 被吞掉，造成无法开战或零战斗领取后续奖励。
    const dungeonCombatTransient = this.currentCard && (
      this.currentCard.type === 'COMBAT_WARNING'
      || this.currentCard.id === 'combat_reward'
      || this.currentCard.id === 'breakthrough_reward'
    );
    if (gameState.dungeon && dungeonCombatTransient) {
      return this.currentCard;
    }

    // ── FIX-4 秘境图模式下委托 ──
    if (gameState.dungeon) {
      this.currentCard = cardSystem._drawDungeonCard();
      if (this.currentCard && typeof cardSystem.hydrateCombatCardPresentation === 'function') {
        this.currentCard = cardSystem.hydrateCombatCardPresentation(this.currentCard);
      }
      // 秘境的强制战斗同样必须经过生产预警链，不能因秘境优先级而绕过。
      if (this._isImmediateCombatCard(this.currentCard)) {
        const warningCard = this.combatCoordinator.buildCombatWarning(this.currentCard);
        this.currentCard = warningCard;
      }
      return this.currentCard;
    }

    if (!this.currentCard) {
      // ── 天机追踪 (Tianji Pursuit) ──
      if (gameState.getAttribute('tianji') >= 100) {
        const pursuit = cardSystem.getCard('heaven_pursuit');
        if (!pursuit || (!checkpointOwnedByChoice
          && gameState.beginCausalTransaction?.() === false)) return null;
        gameState.setAttribute('tianji', 0);
        this.currentCard = pursuit;
        if (!checkpointOwnedByChoice && !this._commitDecisionCheckpoint('heaven_pursuit')) {
          this.currentCard = null;
          return null;
        }
        if (checkpointOwnedByChoice) this._pendingHeavenPursuitWarning = true;
        else this._log('【警告】天机泄露，跨界大能锁定了你的气息！');
        return this.currentCard;
      }
      
      // ===== FlowDirector 核心调度 =====
      this.currentCard = this._getNextCardFromAuthoritativeFlow();
      if (this.currentCard && typeof cardSystem !== 'undefined' && cardSystem &&
          typeof cardSystem.hydrateCombatCardPresentation === 'function') {
        this.currentCard = cardSystem.hydrateCombatCardPresentation(this.currentCard);
      }
      // ── 安全兜底：极少情况下 draw() 可能返回 null（deathCardMap 空 + 兜底卡也未生成）
      if (!this.currentCard) {
        this._log('[系统] 抽卡池为空，已生成默认事件。');
        this.currentCard = {
          id: 'game_fallback',
          title: '潜心修炼',
          description: '你盘膝而坐，运转周天，吐纳灵气。修行之道，贵在坚持。',
          type: 'NORMAL',
          realm: gameState.realm,
          choices: {
            left: { text: '专注修炼', effects: { exp: 5 }, desc: '稳扎稳打提升修为。' },
            right: { text: '游历散心', effects: { fortune: 1 }, desc: '放松心情，或许会有意外收获。' }
          }
        };
      }

      // Flow schedules and marks a card as presented inside getNextCard(). A
      // card-driven location transition must precede the checkpoint so reload
      // cannot restore the new card under the old world location.
      this._syncCardDrivenLocation(this.currentCard);
      // Rendering can re-enter getCurrentCard() before makeChoice() finishes.
      // In that case the drawn card is only a preview inside the owning choice
      // transaction; the outer choice must write its single final checkpoint.
      if (!checkpointOwnedByChoice && !this._commitDecisionCheckpoint(
        gameState.decisionCheckpoint?.sourceCardId || null
      )) {
        // The draw may have activated a quest inside the owning transaction.
        // Rollback restores QuestSystem, but this UI-held card is a separate
        // projection and must not expose an entry that never reached disk.
        this.currentCard = null;
        return null;
      }

      // 战斗卡检测：抽到 combat 标签的卡 → 先展示预警卡，再进入战斗
      if (this._isImmediateCombatCard(this.currentCard)) {
        this.currentCard = this._prepareNarrativeSpineCombat(this.currentCard);
        // FIX-3: 战斗预警机制 — 先展示预警卡，给玩家准备时间
        if (!this.combatCoordinator.hasWarningShown()) {
          const warningCard = this.combatCoordinator.buildCombatWarning(this.currentCard);
          this.currentCard = warningCard;
          return warningCard;
        }
        // 预警卡已展示过，正式进入战斗
        if (!this.currentCard.enemy) {
          this._log('[系统] 战斗状态异常，已自动恢复。');
          return this.currentCard;
        }
        this.combatCoordinator.enterCombat(this.currentCard);
        return this.combatCoordinator.getCombatCard();
      }
    }

    // 【环环相扣：法宝主动效果】为当前卡牌附加法宝主动选项
    if (this.currentCard && typeof treasureSystem !== 'undefined' && treasureSystem) {
      const activeOptions = treasureSystem.getActiveOptions(this.currentCard);
      if (activeOptions.length > 0) {
        // 浅拷贝卡牌对象，附加法宝选项
        const enhancedCard = Object.assign({}, this.currentCard);
        enhancedCard.choices = Object.assign({}, this.currentCard.choices);
        for (const opt of activeOptions) {
          enhancedCard.choices[opt.direction] = {
            text: opt.text,
            effects: opt.effects,
            treasureId: opt.treasureId,
            _treasureOption: true
          };
        }
        enhancedCard._hasTreasureOptions = true;
        return this._projectEndingCandidateResult(enhancedCard);
      }
    }

    return this._projectEndingCandidateResult(this.currentCard);
  }

  _projectEndingCandidateResult(card) {
    if (!card?.id?.startsWith('ending_')) return card;
    const testimony = this.endingEligibilityService?.projectTribulationTestimony?.(
      gameState.endingId || card.id.slice('ending_'.length), gameState.getTerminalContext?.()
    );
    const testimonyDescription = testimony
      ? `${card.description}\n\n【天门证词】${testimony.text}`
      : card.description;
    const rejected = gameState.terminalContext?.candidateRejection;
    if (!rejected || !Array.isArray(rejected.missing)) {
      return { ...card, description: testimonyDescription };
    }
    const explanation = `【未竟的意向】你曾选择${rejected.name}，但终战时仍缺少：${rejected.missing.join('；')}。天门已开，你按当前可达之路继续。`;
    return { ...card, description: `${testimonyDescription}\n\n${explanation}` };
  }

  /**
   * 为一次即将发生的 UI 选择签发单次令牌。
   * 令牌属于“这次玩家意图”，不依赖动态卡是否有 ID 或是否每次重建对象。
   */
  issueChoiceToken() {
    this._choiceTokenCounter += 1;
    this._activeChoiceToken = this._choiceTokenCounter;
    return this._activeChoiceToken;
  }

  /**
   * Commit the post-choice decision boundary as one causal checkpoint.
   * The snapshot contains the card the player should see next, not merely the
   * effects that happened before the browser was refreshed.
   */
  _buildDecisionCheckpoint(sourceCardId = null) {
    const state = this.gameState || (typeof gameState !== 'undefined' ? gameState : null);
    if (!state) return null;
    const nextCard = this.currentCard;
    const warningResolution = nextCard?.type === 'COMBAT_WARNING'
      ? this.combatCoordinator?.getPendingResolution?.()
      : null;
    const directWarningSource = nextCard?.type === 'COMBAT_WARNING' && !warningResolution
      ? this.combatCoordinator?.getPendingCombatCard?.()
      : null;
    const effectiveSourceCardId = typeof warningResolution?.sourceCard?.id === 'string'
      ? warningResolution.sourceCard.id
      : sourceCardId;
    const cardSnapshot = (this._isRecoverableCombatOutcomeCard(nextCard)
      || (nextCard?.type === 'KARMA_RIPPLE' && nextCard?.id?.startsWith('karma_ripple:'))
      || (nextCard?.type === 'HEAVENS_HINT' && nextCard?.id?.startsWith('heavens_hint:')))
      ? JSON.parse(JSON.stringify(nextCard))
      : null;
    return {
      version: 1,
      cardId: nextCard && typeof nextCard.id === 'string' ? nextCard.id : null,
      turn: Math.max(0, Number(state.turn) || 0),
      decisionIndex: state.runClock?.decisionIndex ?? state.turn,
      sourceCardId: typeof effectiveSourceCardId === 'string' ? effectiveSourceCardId : null,
      ...(typeof nextCard?.id === 'string' && nextCard.id.startsWith('npc_encounter_') ? {
        // The existing commit port updates the top-level decisionIndex/turn
        // atomically. Do not duplicate a pre-commit clock inside the selector.
        lifeId: state.runClock?.lifeId || null,
        npcEncounter: nextCard.npcEncounter && typeof nextCard.npcEncounter === 'object'
          && !Array.isArray(nextCard.npcEncounter) ? {
            version: nextCard.npcEncounter.version,
            npcId: nextCard.npcEncounter.npcId,
            scene: nextCard.npcEncounter.scene,
            location: nextCard.npcEncounter.location,
            emotion: nextCard.npcEncounter.emotion
          } : null
      } : {}),
      ...(nextCard?.type === 'COMBAT_WARNING' && typeof warningResolution?.direction === 'string'
        ? { warningDirection: warningResolution.direction }
        : {}),
      ...(directWarningSource?.id
        && nextCard?.id === `_warning_${directWarningSource.id}`
        && this._isImmediateCombatCard(directWarningSource)
        ? { directWarningSourceId: directWarningSource.id }
        : {}),
      ...(nextCard?.type === 'COMBAT_WARNING'
        && /^ch_[a-z]+_\d+$/.test(effectiveSourceCardId || '')
        && Number.isSafeInteger(warningResolution?.sourceCard?.threshold)
        && warningResolution.sourceCard.threshold > 0
        ? { sourceThreshold: warningResolution.sourceCard.threshold }
        : {}),
      ...(cardSnapshot ? { cardSnapshot } : {})
    };
  }

  _commitDecisionCheckpoint(sourceCardId = null) {
    const state = this.gameState || (typeof gameState !== 'undefined' ? gameState : null);
    if (!state) return true;
    state.decisionCheckpoint = this._buildDecisionCheckpoint(sourceCardId);
    if (typeof state.persistCausalSession !== 'function') return true;
    let persisted = false;
    try {
      persisted = state.persistCausalSession({ force: true });
    } catch (error) {
      persisted = false;
    }
    if (persisted === false && typeof state.rollbackCausalTransaction === 'function') {
      if (this._choiceAttemptActive) this._nestedCheckpointRejected = true;
      state.rollbackCausalTransaction();
    } else if (persisted !== false && typeof state.finishCausalTransaction === 'function') {
      state.finishCausalTransaction();
      if (typeof questSystem !== 'undefined' && questSystem
        && typeof questSystem.publishCommittedTriggers === 'function') {
        questSystem.publishCommittedTriggers();
      }
    }
    if (persisted === false && this.debug) {
      this._log('【存档】本次选择已结算，但检查点写盘失败；请勿关闭页面。');
    }
    return persisted !== false;
  }

  _captureUncommittedDecisionUi() {
    const clone = value => (value === undefined ? undefined : JSON.parse(JSON.stringify(value)));
    return {
      currentCard: clone(this.currentCard),
      questNextCardId: this._questNextCardId || null,
      pendingMarket: clone(this._pendingMarket),
      pendingRipple: clone(this._pendingRipple),
      pendingHint: clone(this._pendingHint),
      pendingPromiseResultCard: clone(this._pendingPromiseResultCard),
      pendingRealmTransitionCard: clone(this._pendingRealmTransitionCard),
      pendingVendorChoiceContext: clone(this._pendingVendorChoiceContext),
      combatWarning: this.combatCoordinator?.capturePendingWarningState?.() || null,
      logMessages: Array.isArray(this.ui?.logMessages) ? clone(this.ui.logMessages) : null,
      logSequence: Number(this.ui?._logSequence) || 0
    };
  }

  _restoreUncommittedDecisionUi(snapshot) {
    if (!snapshot || typeof snapshot !== 'object') return false;
    const clone = value => (value === undefined ? undefined : JSON.parse(JSON.stringify(value)));
    this.currentCard = clone(snapshot.currentCard);
    this._questNextCardId = snapshot.questNextCardId || null;
    this._pendingMarket = clone(snapshot.pendingMarket);
    this._pendingRipple = clone(snapshot.pendingRipple);
    this._pendingHint = clone(snapshot.pendingHint);
    this._pendingPromiseResultCard = clone(snapshot.pendingPromiseResultCard);
    this._pendingRealmTransitionCard = clone(snapshot.pendingRealmTransitionCard);
    this._pendingVendorChoiceContext = clone(snapshot.pendingVendorChoiceContext);
    if (snapshot.combatWarning) {
      this.combatCoordinator?.restorePendingWarningState?.(snapshot.combatWarning);
    }
    if (Array.isArray(snapshot.logMessages) && this.ui) {
      this.ui.logMessages = clone(snapshot.logMessages);
      this.ui._logSequence = snapshot.logSequence;
      this.ui.renderLog?.();
    }
    return true;
  }

  /**
   * The single player-facing decision write port. Checkpoint and clock are
   * written together; duplicate delayed callbacks receive the old receipt.
   */
  _commitTopLevelDecision(sourceCardId = null, { kind = 'top_level', stableKey = null } = {}) {
    const state = this.gameState || (typeof gameState !== 'undefined' ? gameState : null);
    if (!state || typeof state.commitTopLevelDecision !== 'function') {
      return this._commitDecisionCheckpoint(sourceCardId);
    }
    const nextIndex = typeof state.getNextDecisionIndex === 'function'
      ? state.getNextDecisionIndex()
      : Math.max(0, Number(state.turn) || 0) + 1;
    const lifeId = typeof state.getRunClock === 'function'
      ? (state.getRunClock()?.lifeId || 'legacy_life')
      : `legacy:${typeof state.getLifeCount === 'function' ? state.getLifeCount() : 0}`;
    const token = stableKey
      ? `decision:${lifeId}:${kind}:${stableKey}`
      : `decision:${lifeId}:${kind}:${sourceCardId || 'unknown'}:${nextIndex}`;
    const previousCheckpoint = state.decisionCheckpoint
      ? JSON.parse(JSON.stringify(state.decisionCheckpoint))
      : null;
    state.decisionCheckpoint = this._buildDecisionCheckpoint(sourceCardId);
    const result = state.commitTopLevelDecision({ token, sourceCardId, kind });
    if (result?.committed === true && typeof questSystem !== 'undefined' && questSystem
      && typeof questSystem.publishCommittedTriggers === 'function') {
      questSystem.publishCommittedTriggers();
    }
    if (result?.committed !== true) state.decisionCheckpoint = previousCheckpoint;
    const germinations = this._pendingKarmaGerminations || [];
    this._pendingKarmaGerminations = [];
    if (result?.committed === true) {
      for (const notice of germinations) eventBus.emit('karma:seedGerminated', notice);
    }
    if (result?.reason === 'persistence_failed' && this.debug) {
      this._log('【存档】本次决断未能写盘，已回滚；请重试。');
    }
    return result?.committed !== false || result?.replayed === true;
  }

  _isRecoverableCombatOutcomeCard(card) {
    const id = card && typeof card.id === 'string' ? card.id : '';
    return id === 'combat_reward'
      || id === 'breakthrough_reward'
      || id.startsWith('combat_defeat_')
      || id.startsWith('combat_fled_');
  }

  _canRestoreDecisionSnapshot(card, realmTransition = null) {
    if (card?.id !== 'breakthrough_reward') return true;
    return Boolean(
      realmTransition
      && realmTransition.status === 'inheritance_pending'
      && realmTransition.sourceCardId === gameState.decisionCheckpoint?.sourceCardId
    );
  }

  _buildRealmTransitionArrivalCard(transition) {
    if (!transition || transition.status !== 'arrival_pending') return null;
    if (transition.to !== gameState.realm || transition.pathAtPromotion !== gameState.path) return null;
    const sourceCard = this.cardSystem?.getCard?.(transition.sourceCardId)
      || this.chapterSystem?.getMilestoneCard?.(transition.from, 100, transition.pathAtPromotion)
      || (typeof chapterSystem !== 'undefined'
        ? chapterSystem?.getMilestoneCard?.(transition.from, 100, transition.pathAtPromotion)
        : null);
    const card = transition.to === 'foundation'
      ? this._buildEpiphanyCard()
      : this._buildRealmArrivalCard(transition.from, transition.to, [], sourceCard);
    return card?.id === transition.arrivalCardId ? card : null;
  }

  _restoreRealmTransitionCard(transition) {
    return this._buildRealmTransitionArrivalCard(transition);
  }

  _activateRealmTransitionArrival(card) {
    const transition = gameState.realmTransition;
    if (!transition || transition.status !== 'inheritance_pending' || card?.id !== 'breakthrough_reward') {
      return false;
    }
    const arrivalCard = this._buildRealmTransitionArrivalCard({
      ...transition,
      status: 'arrival_pending'
    });
    if (!arrivalCard) return false;
    gameState.realmTransition = { ...transition, status: 'arrival_pending' };
    this._pendingRealmTransitionCard = arrivalCard;
    gameState.persistCausalSession?.();
    return true;
  }

  _completeRealmTransitionArrival(card) {
    const transition = gameState.realmTransition;
    if (!transition || transition.status !== 'arrival_pending' || card?.id !== transition.arrivalCardId) {
      return false;
    }
    gameState.realmTransition = null;
    return true;
  }

  _restoreCombatWarningCheckpoint(checkpoint, pendingThreadCard = null, cardApi = null) {
    if (!checkpoint || typeof checkpoint !== 'object') return null;
    if (typeof checkpoint.cardId !== 'string' || !checkpoint.cardId.startsWith('_warning_')) return null;
    if (typeof checkpoint.directWarningSourceId === 'string'
      && typeof checkpoint.warningDirection !== 'string') {
      const sourceId = checkpoint.directWarningSourceId;
      if (checkpoint.cardId !== `_warning_${sourceId}`
        || !this.combatCoordinator?.buildCombatWarning) return null;
      // The source ID may belong to a graph in a different realm from the
      // restored player. Resolve against its authored graph realm so a forged
      // checkpoint cannot turn a dungeon Boss into a free forced encounter.
      const graphRealm = (gameState.constructor?.REALM_ORDER || []).find(realm =>
        cardApi?.isGraphDungeonCombatSource?.(sourceId, realm)
      );
      if (graphRealm && (gameState.dungeonRun?.status !== 'active'
        || gameState.dungeonRun.realm !== graphRealm)) return null;
      const sourceCard = cardApi?.resolveCombatSourceCard?.(sourceId, {
        chapterSystem: this.chapterSystem,
        factionSystem: this.factionSystem,
        realmHint: graphRealm || null,
        pathId: this.gameState?.path
      });
      if (sourceCard?.id !== sourceId || !sourceCard.enemy
        || !this._isImmediateCombatCard(sourceCard)) return null;
      const warningCard = this.combatCoordinator.buildCombatWarning(sourceCard);
      if (warningCard?.id !== checkpoint.cardId) {
        this.combatCoordinator.cancelPendingCombat?.();
        return null;
      }
      return warningCard;
    }
    if (typeof checkpoint.sourceCardId !== 'string' || typeof checkpoint.warningDirection !== 'string') return null;
    if (!this.combatCoordinator || typeof this.combatCoordinator.buildChoiceCombatWarning !== 'function') return null;

    const hasThreshold = Object.prototype.hasOwnProperty.call(checkpoint, 'sourceThreshold');
    if (hasThreshold && (!/^ch_[a-z]+_\d+$/.test(checkpoint.sourceCardId)
      || !Number.isSafeInteger(checkpoint.sourceThreshold) || checkpoint.sourceThreshold <= 0)) return null;
    const pendingThreadSource = pendingThreadCard?.id === checkpoint.sourceCardId;
    const rawSourceCard = pendingThreadSource
      ? pendingThreadCard
      : cardApi?.resolveCombatSourceCard?.(checkpoint.sourceCardId, {
        chapterSystem: this.chapterSystem,
        factionSystem: this.factionSystem,
        thresholdHint: hasThreshold ? checkpoint.sourceThreshold : null,
        pathId: this.gameState?.path
      });
    // ThreadEngine rebuilds the authored pending node without CardSystem's
    // migrated combat media. Normal presentation hydrates it before choice;
    // resume must build the warning from that same canonical projection so
    // DeckCombatSystem can authenticate the later active-combat snapshot.
    const sourceCard = pendingThreadSource && rawSourceCard
      && typeof cardApi?.hydrateCombatCardPresentation === 'function'
      ? cardApi.hydrateCombatCardPresentation(rawSourceCard)
      : rawSourceCard;
    const contract = sourceCard && this._getChoiceCombatContract(
      sourceCard, checkpoint.warningDirection, sourceCard.choices?.[checkpoint.warningDirection]
    );
    // A persisted warning identifies an already selected hit. Rebuild that
    // branch from authorship; neither raw effects nor saved rewards own it.
    const choice = contract?.valid ? contract.combatChoice : null;
    if (!sourceCard || !choice
      || !(choice.triggerCombat || choice.effects?.triggerCombat)
      || !(choice.enemy || sourceCard.enemy)) return null;

    const warningCard = this.combatCoordinator.buildChoiceCombatWarning(
      sourceCard,
      checkpoint.warningDirection,
      choice
    );
    if (!warningCard || warningCard.id !== checkpoint.cardId) {
      this.combatCoordinator.cancelPendingCombat?.();
      return null;
    }
    return warningCard;
  }

  /**
   * 玩家做出选择
   * @param {string} direction - 'left' | 'right' | 'up' | 'down'
   * @param {number|null} expectedChoiceToken - UI 开始动画前签发的一次性令牌
   * @returns {boolean} 选择是否有效
   */
  makeChoice(direction, expectedChoiceToken = null) {
    // 每次玩家意图都是独立事务。入口先清掉任何未消费旧回执，成功出口再统一
    // 完成当前回执；失败或异常绝不能把半成品带到下一张卡或下一世。
    this.discardChoiceSettlement();
    this._pendingKarmaGerminations = [];
    this._pendingReincarnationPathSelection = null;
    // Most cards settle one top-level player decision. Flows that defer their
    // real outcome (vendor/combat) mark themselves below and only checkpoint
    // this intermediate UI transition.
    this._topLevelDecisionDisposition = 'commit';
    // A delivery may create an instance inside this transaction. Its next-card
    // render must wait for the outer persistence result: otherwise UI asks
    // getCurrentCard() while currentCard is temporarily null, consumes an
    // unrelated Flow card, and makes a failed delivery impossible to retry.
    this._deferChoiceUiUpdate = false;
    const sourceCard = this.currentCard;
    const sourceChoice = sourceCard?.choices?.[direction] || null;
    const preparedSourceCard = sourceCard && this.choiceOutcomeRouter
      && typeof this.choiceOutcomeRouter.prepareCard === 'function'
      ? this.choiceOutcomeRouter.prepareCard(sourceCard)
      : sourceCard;
    const structuredSourceChoice = preparedSourceCard?.choices?.[direction] || sourceChoice;
    // 死亡卡的正式数据只携带 reincarnation_bonus，真正的转世门禁来自选择前
    // gameState.dead；必须在内部重置状态之前冻结该事实。
    const suppressSettlement = Boolean(
      (typeof gameState !== 'undefined' && gameState.dead)
      || sourceChoice?.effects?.reincarnate
    );
    const transactionState = this.gameState || (typeof gameState !== 'undefined' ? gameState : null);
    const uncommittedUi = this._captureUncommittedDecisionUi();
    if (suppressSettlement && typeof transactionState?.beginLifeTransition === 'function') {
      if (transactionState.beginLifeTransition() !== true) {
        this._lastChoiceRejection = 'persistence_unavailable';
        return false;
      }
    }
    if (!suppressSettlement && typeof transactionState?.beginCausalTransaction === 'function') {
      if (transactionState.beginCausalTransaction({ decisionPending: true }) === false) {
        this._lastChoiceRejection = 'persistence_unavailable';
        if (this.debug) this._log('【存档】无法建立本次决断的恢复基线，选择未执行。');
        return false;
      }
    }
    const fallbackBaseline = this.effectService?.captureObservableState?.() || null;
    this._choiceAttemptActive = true;
    this._nestedCheckpointRejected = false;
    try {
      const result = this._makeChoiceInternal(direction, expectedChoiceToken);
      const nestedCheckpointRejected = this._nestedCheckpointRejected === true;
      if (result === false || nestedCheckpointRejected) {
        this._pendingReincarnationPathSelection = null;
        transactionState?.rollbackLifeTransition?.();
        transactionState?.rollbackCausalTransaction?.();
        this._restoreUncommittedDecisionUi(uncommittedUi);
        this.discardChoiceSettlement();
        if (nestedCheckpointRejected) {
          this._nestedCheckpointRejected = false;
          this._lastChoiceRejection = 'persistence_failed';
          this._triggerUpdate();
        }
        return false;
      }
      if (suppressSettlement) {
        if (transactionState?.commitLifeTransition?.() === false) {
          this._pendingReincarnationPathSelection = null;
          this._restoreUncommittedDecisionUi(uncommittedUi);
          this.discardChoiceSettlement();
          this._lastChoiceRejection = 'persistence_failed';
          this._triggerUpdate();
          return false;
        }
        this.discardChoiceSettlement();
        if (this._pendingReincarnationPathSelection) {
          this.eventBus.emit('reincarnation:pathSelectionRequired', this._pendingReincarnationPathSelection);
          this._pendingReincarnationPathSelection = null;
        }
        this._triggerUpdate();
        return result;
      }

      this._finalizePendingChoiceSettlement();
      if (this._lastChoiceSettlement) {
        this._lastChoiceSettlement.choiceToken = expectedChoiceToken;
        this._lastChoiceSettlement.feedbackCue = structuredSourceChoice?.feedbackCue || null;
        this._lastChoiceSettlement.outcomeText = structuredSourceChoice?.feedbackCue?.text
          || structuredSourceChoice?.resolution?.text
          || null;
      }
      if (!this._lastChoiceSettlement && fallbackBaseline && sourceChoice) {
        const actual = this.effectService?.createSettlement?.(fallbackBaseline);
        if (actual?.changes?.length) {
          this._lastChoiceSettlement = {
            sourceName: sourceChoice.text || sourceCard?.title || '选择回执',
            sourceCardId: sourceCard?.id || null,
            visualWorldId: sourceCard?.visualWorldId || null,
            uiMaterialId: sourceCard?.uiMaterialId || null,
            visualSurface: sourceCard?.visualSurface || null,
            choiceToken: expectedChoiceToken,
            costText: sourceChoice.costText || this._formatChoiceCost(sourceChoice.costCheck),
            effectKeys: Object.keys(sourceChoice.effects || {}),
            feedbackMode: sourceChoice.settlementFeedbackMode || 'nearfield',
            feedbackCue: structuredSourceChoice?.feedbackCue || null,
            outcomeText: structuredSourceChoice?.feedbackCue?.text
              || structuredSourceChoice?.resolution?.text
              || null,
            changes: actual.changes
          };
        }
      }
      // 叙事日志读取已提交的 SettlementReceipt，而不是直接读取卡牌预览。
      // 这样属性封顶、资源不足或系统拒绝时，不会向玩家宣称虚假的收益。
      if (typeof coherenceLayer !== 'undefined' && coherenceLayer
        && this._lastChoiceSettlement && sourceChoice) {
        const narration = coherenceLayer.narrateChoice(
          sourceCard,
          direction,
          sourceChoice,
          gameState,
          this._lastChoiceSettlement
        );
        if (narration) this._log(narration);
      }
      const disposition = this._topLevelDecisionDisposition;
      this._topLevelDecisionDisposition = null;
      const deferredUiUpdate = this._deferChoiceUiUpdate === true;
      this._deferChoiceUiUpdate = false;
      const committed = disposition === 'inner_demon'
        ? this._commitTopLevelDecision('inner_demon', { kind: 'inner_demon' })
        : disposition === 'commit'
          ? this._commitTopLevelDecision(sourceCard?.id || null, { kind: 'choice' })
          : this._commitDecisionCheckpoint(sourceCard?.id || null);
      if (!committed) {
        transactionState?.rollbackCausalTransaction?.();
        this._restoreUncommittedDecisionUi(uncommittedUi);
        this.discardChoiceSettlement();
        this._lastChoiceRejection = 'persistence_failed';
        this._triggerUpdate();
        return false;
      }
      if (this._pendingHeavenPursuitWarning) {
        this._pendingHeavenPursuitWarning = false;
        this._log('【警告】天机泄露，跨界大能锁定了你的气息！');
      }
      if (deferredUiUpdate) this._triggerUpdate();
      return result;
    } catch (error) {
      this._deferChoiceUiUpdate = false;
      this._pendingReincarnationPathSelection = null;
      transactionState?.rollbackLifeTransition?.();
      transactionState?.rollbackCausalTransaction?.();
      this._restoreUncommittedDecisionUi(uncommittedUi);
      this.discardChoiceSettlement();
      throw error;
    } finally {
      this._choiceAttemptActive = false;
      this._nestedCheckpointRejected = false;
      this._pendingHeavenPursuitWarning = false;
    }
  }

  _makeChoiceInternal(direction, expectedChoiceToken = null) {
    this._lastChoiceRejection = null;
    if (expectedChoiceToken !== null && expectedChoiceToken !== undefined) {
      if (expectedChoiceToken !== this._activeChoiceToken) {
        this._lastChoiceRejection = 'stale_card';
        if (this.debug) {
          this._log(
            `[makeChoice] 忽略已消费或过期的选择令牌 token=${expectedChoiceToken}`
          );
        }
        return false;
      }
      // 先消费令牌：即使后续校验失败，同一次动画回调也不能再次提交。
      this._activeChoiceToken = null;
    }

    // 【诊断日志】makeChoice 入口：记录决策上下文
    const entryCardId = this.currentCard ? this.currentCard.id : 'null';
    if (this.debug) this._log(`[makeChoice] 入口 dir=${direction} card=${entryCardId} dead=${gameState.dead} inCombat=${this.combatCoordinator ? this.combatCoordinator.isInCombat() : 'N/A'} turn=${gameState.turn}`);

    if (gameState.dead && this.currentCard && !this.currentCard.id.startsWith('death_') && !this.currentCard.id.startsWith('ending_')) {
      if (this.debug) this._log(`[makeChoice] ⚠️ 死亡状态但卡牌非 death_*/ending_*，拒绝操作`);
      return false;
    }

    const card = this.getCurrentCard();
    if (!card) {
      this._lastChoiceRejection = 'persistence_failed';
      return false;
    }
    // 若本次选择开始前已经有支线续卡挂起，说明当前卡是插入在两段支线之间的
    // 一次性中断。该中断结算后必须恢复原支线，不能被新一轮命盘/涟漪/集市
    // 再次抢占，否则真实任务会在随机卡流中长期饥饿。
    const hadPendingQuestContinuation = Boolean(this._questNextCardId);
    const selectedChoice = card?.choices?.[direction] || null;
    if (selectedChoice) {
      const fieldAudit = this._auditChoiceBehavior(selectedChoice);
      if (!fieldAudit.valid) {
        this._lastChoiceRejection = 'unknown_choice_field';
        this._log(`【选择合同拒绝】${card.id}.${direction} 包含未登记字段：${fieldAudit.unknownFields.join(', ')}`);
        this._triggerUpdate();
        return false;
      }
    }

    // ── v2.0 心魔反噬选择处理 ──
    if (card.type === 'INNER_DEMON') {
      // Effects, pending clear and receipt belong to the same outer transaction.
      // Present the next card only after that one commit succeeds; an additional
      // tail checkpoint must not turn an already committed choice into false.
      this._topLevelDecisionDisposition = 'inner_demon';
      this._deferChoiceUiUpdate = true;
      if (!this._resolveInnerDemon(direction)) return false;
      if (gameState.checkDeath()) {
        const pn = gameState.playerName || '\u59da\u51cc\u4e91';
        this._log(`${pn}，道消身陨。${gameState.deadReason}`);
        this.currentCard = this._getNextCardFromAuthoritativeFlow();
      }
      return true;
    }

    // ── v2.0 命盘轮转选择处理 ──
    if (card.type === 'DESTINY_WHEEL') {
      // A wheel flip is an interaction inside the interrupt; it does not settle
      // the source card's top-level decision a second time.
      this._topLevelDecisionDisposition = 'internal';
      const idx = { left: 0, right: 1, up: 2, down: 3 }[direction];
      if (idx !== undefined && typeof destinyWheelSystem !== 'undefined') {
        destinyWheelSystem.flipCard(idx);
      }
      this._triggerUpdate();
      return true;
    }




    // ── FIX-3: 战斗预警卡选择处理 ──
    if (card.type === 'COMBAT_WARNING') {
      const warningChoice = card.choices[direction];
      if (!warningChoice) return false;
      // 预警中的撤退、兵解、交涉等非战斗选项必须走普通选择管线，
      // 不能因为存在待战斗卡而被强制送入战斗。
      if (!warningChoice._confirmCombat) {
        this.combatCoordinator.cancelPendingCombat();
      } else {
        const warningPreview = this.previewCardChoices?.(card, {
          cardId: card.id || null,
          cardTags: card.tags || []
        })?.[direction] || this.previewChoice?.(warningChoice, {
          card,
          direction,
          cardId: card.id || null, cardTags: card.tags || []
        }) || { executable: true };
        if (!warningPreview.executable) {
          this._lastChoiceRejection = warningPreview.reason;
          this._log('资源不足，无法完成这项备战。');
          this._triggerUpdate();
          return false;
        }
        if (warningChoice.costCheck?.spiritStone) {
          gameState.addResource('spiritStone', null, -warningChoice.costCheck.spiritStone);
        }
        if (warningChoice.costCheck?.lifespan) {
          gameState.addResource('lifespan', null, -warningChoice.costCheck.lifespan);
        }
        if (warningChoice.costCheck?.health) {
          gameState.addAttribute('health', -warningChoice.costCheck.health);
        }
        if (warningChoice.costCheck?.karmaGood) {
          gameState.addAttribute('karmaGood', -warningChoice.costCheck.karmaGood);
        }
        // Apply the same no-double-charge filtering used by ordinary choices.
        let warningEffects = warningChoice.effects;
        if (warningEffects && warningChoice.costCheck) {
          warningEffects = { ...warningEffects };
          for (const key of ['spiritStone', 'lifespan', 'health', 'karmaGood']) {
            if (warningChoice.costCheck[key] && warningEffects[key] < 0) delete warningEffects[key];
          }
        }
        if (warningEffects) this._applyEffects(warningEffects);
        const pendingResolution = this.combatCoordinator.getPendingResolution();
        if (pendingResolution?.choice?.entryEffects) {
          this._applyEffects(pendingResolution.choice.entryEffects);
        }
        // 恢复待战斗的卡牌并进入战斗
        const pendingCombatCard = this.combatCoordinator.getPendingCombatCard();
        if (pendingCombatCard) {
          this.currentCard = pendingCombatCard;
          this._topLevelDecisionDisposition = 'deferred_combat';
          // 正式进入战斗（fire-and-forget，战斗系统会通过事件通知 UI）
          this.combatCoordinator.enterCombatFromWarning();
          this._triggerUpdate();
          return true;
        }
        this._triggerUpdate();
        return false;
      }
    }

    // ── FIX-4: 秘境分叉选择处理 ──
    if (card.type === 'DUNGEON_FORK') {
      const forkChoice = card.choices[direction];
      if (!forkChoice) return false;
      // 应用路径上的效果 (如有)
      if (forkChoice.effects) this._applyEffects(forkChoice.effects);
      // 推进秘境到玩家选择的目标节点
      if (forkChoice._dungeonForkNext && typeof cardSystem !== 'undefined' && cardSystem) {
        const advanced = cardSystem.advanceDungeonToFork(card._dungeonNodeId, forkChoice._dungeonForkNext);
        if (!advanced) return false;
        this._log('你选择了：' + forkChoice.text);
      }
      this.currentCard = null;
      gameState.cardsPlayed.push(card.id);
      this._recordChoiceHistory(card, direction, forkChoice);
      this.eventBus.emit('card:chosen', { card, direction, choice: forkChoice });
      if (gameState.checkDeath()) {
        const playerName = gameState.playerName || '叶凌云';
        this._log(`${playerName}，道消身陨。${gameState.deadReason}`);
        this.currentCard = this._getNextCardFromAuthoritativeFlow();
        this._triggerUpdate();
        return true;
      }
      this._triggerUpdate();
      return true;
    }

    let choice = selectedChoice;
    if (!choice) return false;
    const combatRoll = this._resolveProbabilisticCombatChoice(card, direction, choice);
    if (!combatRoll.valid) {
      this._lastChoiceRejection = combatRoll.reason || 'invalid_probabilistic_combat';
      this._log(`【概率战斗拒绝】${combatRoll.message || '遭遇合同不完整。'}`);
      this._triggerUpdate();
      return false;
    }
    choice = combatRoll.choice;
    const authoredEncounter = this._resolveAuthoredCombatEncounterChoice(card, direction, choice);
    if (!authoredEncounter.valid) {
      this._lastChoiceRejection = authoredEncounter.reason || 'invalid_authored_combat_encounter';
      this._log(`【遭遇战斗拒绝】${authoredEncounter.message || '遭遇合同不完整。'}`);
      this._triggerUpdate();
      return false;
    }
    choice = authoredEncounter.choice;
    if (card.type === 'VENDOR_RESULT' && choice.action?.type === 'DISMISS_VENDOR_RESULT') {
      const dismissal = this._projectChoiceAction(choice.action, { card });
      if (dismissal.blocksChoice) {
        this._lastChoiceRejection = dismissal.reason;
        return false;
      }
      // This branch is deliberately an internal UI transition, but it still
      // runs inside makeChoice's causal transaction. The forced checkpoint at
      // that wrapper's internal-disposition exit is what durably removes the
      // result session before the player can refresh.
      this._topLevelDecisionDisposition = 'internal';
      this.currentCard = null;
      if (gameState.marketState) gameState.marketState.activeSession = null;
      if (card.id) gameState.cardsPlayed.push(card.id);
      this._recordChoiceHistory(card, direction, choice);
      this.eventBus.emit('card:chosen', { card, direction, choice });
      this._triggerUpdate();
      return true;
    }
    const dungeonEntryContract = Object.prototype.hasOwnProperty.call(choice, 'dungeon')
      ? this.cardSystem.validateDungeonEntry(choice.dungeon)
      : null;
    if (dungeonEntryContract && !dungeonEntryContract.valid) {
      this.cardSystem.enterDungeon(choice.dungeon, { sourceCardId: card.id, direction });
      this.currentCard = null;
      gameState.cardsPlayed.push(card.id);
      this._recordChoiceHistory(card, direction, choice);
      this.eventBus.emit('card:chosen', { card, direction, choice, dungeonEntryRejected: true });
      this._triggerUpdate();
      return true;
    }
    const resolvingTerminalReward = card.id === 'breakthrough_reward'
      && typeof gameState.isTerminalRewardPending === 'function'
      && gameState.isTerminalRewardPending();
    let pauseCardFlow = false;

    // 【沉浸 v2.0】拍快照（在应用效果前）
    this._snapshotAttrs();

    // 选项驱动战斗：把原选项冻结为待结算上下文。旧 effects 在迁移期
    // 视作 victoryEffects，绝不在战斗开始前执行。
    if (choice.triggerCombat || (choice.effects && choice.effects.triggerCombat)) {
      if (card.encounterId && this.encounterDirector
          && typeof this.encounterDirector.markAccepted === 'function') {
        this.encounterDirector.markAccepted(card, direction);
      }
      const warningCard = this.combatCoordinator.buildChoiceCombatWarning(card, direction, choice);
      this.currentCard = warningCard;
      this._topLevelDecisionDisposition = 'deferred_combat';
      this._triggerUpdate();
      return true;
    }

    // A rolled miss keeps both the ordinary numeric authority and every
    // non-combat behavior gate. Only skip the unresolved probability union;
    // routing directly to EffectService would bypass action eligibility.
    const resolvedCombatMiss = combatRoll.roll?.triggered === false;
    const choicePreview = this.previewCardChoices?.(card, {
      resolvedCombatMiss,
      cardId: card.id || null,
      cardTags: card.tags || []
    })?.[direction] || this.previewChoice?.(choice, {
      resolvedCombatMiss,
      card,
      direction,
      cardId: card.id || null, cardTags: card.tags || []
    }) || { executable: true, reason: 'preview_unavailable', costs: [] };
    if (!choicePreview.executable) {
      this._lastChoiceRejection = choicePreview.reason;
      const reasonText = choicePreview.reason === 'all_positive_rewards_capped'
        ? '此选择的正向收益均已达到上限。'
        : (choicePreview.reason === 'missing_required_resource'
          ? '缺少所需物品，无法执行此选择。'
          : (choicePreview.reason === 'behavior_preview_unavailable'
            ? '此选择的行为预览合同缺失，当前已安全禁用。'
            : (choicePreview.reason && choicePreview.reason !== 'insufficient_resource'
              ? '此选择当前不满足进入条件。'
              : '资源不足，无法执行此选择。')));
      this._log(reasonText);
      this._triggerUpdate();
      return false;
    }

    // 真实结算基线由 EffectService 统一定义；UI 不再复制状态差值算法。
    const settlementBaseline = this.effectService?.captureObservableState?.() || null;

    // Cost validation above and settlement use the same EffectService projection.
    if (choice.costCheck) {
      if (!this._settleChoiceCosts(choice)) {
        this._lastChoiceRejection = 'choice_cost_changed';
        this._log('成本状态已变化，本次选择未结算。');
        this._triggerUpdate();
        return false;
      }
      // 【P0 修复 #4】从 effects 中剥离与 costCheck 同名的负值字段，防止双重扣费
      if (choice.effects) {
        const filteredEffects = Object.assign({}, choice.effects);
        if (choice.costCheck.spiritStone && filteredEffects.spiritStone < 0) {
          delete filteredEffects.spiritStone;
        }
        if (choice.costCheck.health && filteredEffects.health < 0) {
          delete filteredEffects.health;
        }
        if (choice.costCheck.karmaGood && filteredEffects.karmaGood < 0) {
          delete filteredEffects.karmaGood;
        }
        if (choice.costCheck.lifespan && filteredEffects.lifespan < 0) {
          delete filteredEffects.lifespan;
        }
        choice = Object.assign({}, choice, { effects: filteredEffects });
      }
    }

    // 首局“去坊市整备”是玩家刚刚作出的有限、署名续卡承诺。它并不
    // 创造调度模式或独立状态；只在这个动作的同一结算帧内，把可延后的
    // 环境/章节插入留到真实坊市入口之后，不能抢走已明确的到达结果。
    const firstSessionSerialContract = this.cardSystem
      && typeof this.cardSystem.getFirstSessionSerialContract === 'function'
      ? this.cardSystem.getFirstSessionSerialContract(card, choice, this.gameState || gameState)
      : null;
    const firstSessionSerialContinuation = Boolean(firstSessionSerialContract);
    // Later generic choice normalization may create a fresh transient object.
    // Once CardSystem has authenticated the named first-session handoff, the
    // destination must come from that contract for the rest of this
    // transaction—not from a mutable presentation copy of `choice`.
    const protectedContinuationCardId = firstSessionSerialContract?.to?.cardId
      || choice.nextCard
      || null;

    // 选择一旦通过全部校验，就先退役当前卡牌。后续事件可以决定“下一张”
    // 是普通卡还是中断卡，但不能让已经结算的来源卡继续保持可操作。
    // sourceCard 显式传给 EffectService，避免清空 currentCard 后丢失效果来源。
    this.currentCard = null;
    // `card:chosen` 的观察者会同步请求 UI 重绘。若此时仍是 null，UI 会
    // 合法地向 Flow 要一张新卡，进而把已经排队的里程碑消费在“去坊市”
    // 与其目的地之间。首局署名续卡在通过选择校验后立刻占位为可见到达卡；
    // 仍允许后面明确的死亡/到期合约分支覆盖它，不会修改 Flow 队列本身。
    if (firstSessionSerialContinuation) {
      this.currentCard = this.cardSystem.getCard(protectedContinuationCardId);
      this._syncCardDrivenLocation(this.currentCard, 'choice_continuation');
    }
    // Vendor entries are a deferred decision: an author must use
    // `vendorCloseEffects`, never immediate `effects`. Keep the generic path
    // from accidentally paying the player before an authenticated vendor
    // session exists or before it has been closed.
    const immediateEffects = choice.action?.type === 'ENTER_VENDOR' ? {} : choice.effects;
    const effectSettlement = this._applyEffects(immediateEffects, card);
    if (settlementBaseline && !(immediateEffects && immediateEffects.reincarnate)) {
      this._pendingChoiceSettlement = {
        baseline: settlementBaseline,
        sourceName: choice.text || card.title || '选择回执',
        sourceCardId: card.id || null,
        visualWorldId: card.visualWorldId || null,
        uiMaterialId: card.uiMaterialId || null,
        visualSurface: card.visualSurface || null,
        costText: choice.costText || this._formatChoiceCost(choice.costCheck),
        effectKeys: effectSettlement?.effectKeys || Object.keys(immediateEffects || {}),
        feedbackMode: choice.settlementFeedbackMode || 'nearfield',
        preview: choicePreview
      };
    }
    if (resolvingTerminalReward && !this._finalizeTerminalVictory(card)) {
      this._log('【终局交接】战利已结算，但结局门禁未能裁定；请刷新后重试。');
      this.currentCard = this.combatCoordinator?.restorePendingTerminalReward?.() || card;
      this._triggerUpdate();
      return false;
    }
    if (choice.enterUpperRealm) {
      this._enterUpperRealm();
    }
    this._syncUpperRealmContinuation(card, choice);

    // ════════════════════════════════════════
    //  境界章节里程碑检测
    //  修为达到阈值(20/40/60/80/100)时注入对应里程碑卡
    // ════════════════════════════════════════
    if (!firstSessionSerialContinuation && !gameState.hasFlag('post_ascension_active') &&
        typeof chapterSystem !== 'undefined' && chapterSystem && chapterSystem._initialized) {
      const cultivation = gameState.getAttribute('cultivation');
      const threshold = chapterSystem.shouldTriggerMilestone(gameState.realm, cultivation);
      if (threshold !== null) {
        const milestoneCard = chapterSystem.getMilestoneCard(gameState.realm, threshold);
        if (milestoneCard) {
          let milestoneQueued = false;
          if (typeof flowDirector !== 'undefined' && flowDirector) {
            milestoneQueued = flowDirector.setMilestone(milestoneCard) === true;
          } else if (!this._chapterMilestoneCard) {
            this._chapterMilestoneCard = milestoneCard;
            milestoneQueued = true;
          }
          if (milestoneQueued) {
            this._log(
              '【' + chapterSystem.getChapterTitle(gameState.realm) + '】里程碑 ' +
              threshold + ' —— ' + milestoneCard.title
            );
            eventBus.emit('story:milestone', {
              realm: gameState.realm,
              threshold,
              card: milestoneCard
            });
          }
        }
      }
    }

    // Every vendor entry uses one action contract and settles only after the
    // consumer closes that exact session. There is no second market UI path.
    if (choice.action?.type === 'ENTER_VENDOR') {
      const requestedVendorId = choice.action.vendorId || 'regulated_market';
      const vendorId = typeof marketSystem !== 'undefined' && marketSystem?.normalizeVendorId
        ? marketSystem.normalizeVendorId(requestedVendorId)
        : (requestedVendorId === 'standard_shop' ? 'regulated_market' : requestedVendorId);
      if (!vendorId) {
        this._log('【市集】交易地点档案缺失，本次未进入。');
        return false;
      }
      const entryCardId = card.id || null;
      const openedAtTurn = Math.max(0, Number(gameState.turn) || 0);
      const openedAtDecisionIndex = typeof gameState.getNextDecisionIndex === 'function'
        ? gameState.getNextDecisionIndex()
        : openedAtTurn + 1;
      const sessionKey = this._buildVendorSessionKey(card, vendorId, openedAtDecisionIndex);
      const profile = typeof marketSystem !== 'undefined' && marketSystem?.getVendorProfile
        ? marketSystem.getVendorProfile(vendorId)
        : null;
      const entryEligibility = typeof marketSystem !== 'undefined' && marketSystem?.canEnterVendor
        ? marketSystem.canEnterVendor(vendorId, {
            marketEncounter: choice.action.marketEncounter === true,
            decisionIndex: openedAtDecisionIndex
          })
        : { valid: !(profile?.entryRules?.requiresEncounterCard === true && choice.action.marketEncounter !== true) };
      if (entryEligibility.valid !== true) {
        const reason = entryEligibility.reason === 'access_revoked'
          ? '无面人已记下你的失约；此门不再为你开启。'
          : entryEligibility.reason === 'not_night'
            ? '夜门尚未开启。'
            : entryEligibility.reason === 'invalid_location'
              ? '此处没有足以遮掩来路的人烟。'
              : entryEligibility.reason === 'missing_signal'
                ? '你尚未得到能引来无面人的征兆。'
                : '商队或夜门尚未到访，不能从普通商店入口绕过市场节拍。';
        this._log(`【市集】${reason}`);
        return false;
      }
      const isMarket = vendorId === 'ghost_market';
      let items = [];
      let vendorMeta = {};
      if (isMarket && typeof marketSystem !== 'undefined' && marketSystem) {
        marketSystem._totalVisits++;
        items = marketSystem.getCurrentMarketItems();
        vendorMeta = {
          market: true,
          fortuneTier: marketSystem.getFortuneTierText(),
          priceMult: marketSystem.getPriceMultiplier(),
          ghostMarkupRange: (() => {
            const values = items.map(item => Number(item?.ghostMarkup)).filter(value => Number.isFinite(value));
            return values.length ? { min: Math.min(...values), max: Math.max(...values) } : null;
          })(),
          fortune: gameState.attributes.fortune,
          tradeRoute: typeof tradeRouteSystem !== 'undefined' && tradeRouteSystem
            ? tradeRouteSystem.getMarketModifiers().route
            : null
        };
      } else if (vendorId === 'public_bazaar' && profile) {
        const stalls = typeof marketSystem.getBazaarStalls === 'function'
          ? marketSystem.getBazaarStalls()
          : (profile.stalls || []);
        items = stalls.flatMap(stall => (stall.offers || []).map(offer => ({
          ...offer,
          stallId: stall.id,
          stallName: stall.name,
          relationHint: offer.relationHint || stall.relationHint || null
        })));
        vendorMeta = { market: true, marketType: 'public_bazaar', stalls };
      } else if (typeof shopSystem !== 'undefined' && shopSystem) {
        items = shopSystem.getAvailableItems(gameState.realm);
        const authoredOffers = shopSystem.getAuthoredOffers(choice.action.storyOfferIds, gameState.realm);
        if (authoredOffers.length > 0) {
          const authoredIds = new Set(authoredOffers.map(item => item.id));
          items = [...authoredOffers, ...items.filter(item => !authoredIds.has(item.id))];
        }
      }
      const vendorSession = typeof marketSystem !== 'undefined' && marketSystem?.createVendorSession
        ? marketSystem.createVendorSession({
            vendorId,
            sessionKey,
            entryCardId,
            openedAtDecisionIndex,
            offers: items,
            stalls: vendorMeta.stalls || null
          })
        : null;
      if (!vendorSession) {
        this._log('【市集】无法建立交易会话，本次未进入。');
        return false;
      }
      items = vendorSession.immutableOffers;
      this._pendingVendorChoiceContext = {
        card,
        direction,
        choice,
        vendorId,
        entryCardId,
        sessionKey,
        settled: false
      };
      const vendorPayload = {
        items,
        vendorId,
        marketType: vendorSession.marketType,
        entryCardId,
        sessionKey,
        resumePolicy: choice.action.resumePolicy,
        settlePolicy: choice.action.settlePolicy,
        ...vendorMeta,
        session: vendorSession
      };
      gameState.marketState.activeSession = {
        ...vendorSession,
        openedAtTurn,
        direction,
        card: JSON.parse(JSON.stringify(card)),
        choice: JSON.parse(JSON.stringify(choice)),
        vendorMeta: JSON.parse(JSON.stringify(vendorMeta)),
      };
      this.currentCard = this._buildVendorPendingCard(card);
      this._topLevelDecisionDisposition = 'deferred_vendor';
      if (typeof gameState.persistCausalSession === 'function') gameState.persistCausalSession();
      this.eventBus.emit('shop:open', vendorPayload);
      return true;
    }

    // A KARMA payoff choice settles its source promise before it may plant a
    // successor. This ordering is required when the successor intentionally
    // reuses the same stable seed ID.
    if (choice.action?.type === 'SETTLE_GHOST_DEBT' && !this._resolveGhostDebtAction(choice.action)) {
      return false;
    }
    if (choice.action?.type === 'CLAIM_LICENSED_RUSTED_SWORD'
      && !this._resolveLicensedRustedSwordDeliveryAction(choice.action)) {
      return false;
    }
    if (choice.action?.type === 'RESOLVE_NARRATIVE_FACT_CONSUMER'
      && !this._resolveNarrativeFactConsumerAction(choice.action)) {
      return false;
    }
    if (!this._settleNarrativeSpineChoice(card, direction)) return false;

    this._settleKarmaCard(card);

    // 种因果种子（支持单个对象、数组、或字符串快捷格式）
    if (choice.karmaSeed) {
      const seeds = Array.isArray(choice.karmaSeed) ? choice.karmaSeed : [choice.karmaSeed];
      for (let seed of seeds) {
        // 兼容字符串快捷格式 "causal:xxx" → 展开为标准对象
        if (typeof seed === 'string') {
          seed = {
            id: seed,
            seedType: 'karma',
            delay: 5,
            priority: 1
          };
        }
        karmaSystem.plantSeed({
          ...seed,
          originCard: card.id,
          originChoice: direction,
          context: {
            ...(seed.context && typeof seed.context === 'object' ? seed.context : {}),
            sourceTitle: card.title || card.id,
            choiceText: choice.text || direction,
            realm: seed.realm || card.realm || gameState.realm,
            path: seed.path || card.path || gameState.path
          }
        });
      }
    }

    // 支线推进
    if (card.type === 'QUEST') {
      questSystem.advanceQuest(direction, card);
    }

    // NPC 遭遇卡：记录好感变化
    if (card.type === 'NPC_ENCOUNTER' && choice.npcAffection !== undefined && card.npcId) {
      npcSystem.addAffection(card.npcId, choice.npcAffection);
      npcSystem.recordInteraction(card.npcId, '\u906d\u9047', choice.text, choice.npcAffection);
      // 【沉浸 v2.0】初次遇到道侣 → 心念
      if (choice.npcAffection > 0 && !gameState.resources.companions.includes(card.npcId)) {
        this._triggerInnerVoice('meet_companion', 0.8);
      }
    }

    // NPC交叉互动卡：处理好感变化（可能影响多个NPC）+ NPC间关系变化
    if (card.type === 'NPC_CROSS' && choice.npcAffection) {
      if (typeof choice.npcAffection === 'object') {
        for (const [npcId, delta] of Object.entries(choice.npcAffection)) {
          npcSystem.addAffection(npcId, delta);
        }
      }
      // npc_relation 效果由 _applyEffects 中的 _applyNpcRelationEffect 处理
    }

    // 弧线卡 & 道侣事件卡：应用伴侣效果（好感/信任/羁绊变化）
    const isDynamicCompanionKarma = card.type === 'KARMA' &&
      Array.isArray(card.tags) &&
      card.tags.includes('companion_dynamic');
    if ((card.type === 'COMPANION_EVENT' || card.type === 'COMPANION_ARC' || isDynamicCompanionKarma) &&
        choice.companionEffects) {
      companionSystem.applyChoice(choice);
    }

    // 师尊弧线卡 & 先知弧线卡 & 盟友弧线卡：关系推进已在引擎侧通过事件体系处理
    // （mentor:progressionChange / seer:revelationChange / ally:alignmentChange 由修炼/道心/恶业变化自动触发）

    // 势力事件卡：应用势力效果
    if (card.type === 'FACTION_EVENT' && choice.factionEffects) {
      factionSystem.applyChoice(choice);
    }

    // 秘境进入
    if (choice.dungeon) {
      const entry = this.cardSystem.enterDungeon(dungeonEntryContract.dungeonId, {
        sourceCardId: card.id,
        direction
      });
      if (entry.entered) this._log('【秘境启程】你踏入异境，退路仍在身后。');
    }

    // 境界突破
    if (choice.breakSuccess !== undefined) {
      this._resolveBreakthrough(choice.breakSuccess, card);
    }

    // 转世重修（死亡卡选择 或 手动转世效果）
    // 结局触发当回合先展示尾声；尾声卡明确选择 reincarnate 后必须能进入下一世。
    if (gameState.dead || (choice.effects && choice.effects.reincarnate)) {
      // 【诊断日志】转世判断入口
      const endingFlag = gameState.hasFlag('game_ended');
      const hasReincarnateEffect = !!(choice.effects && choice.effects.reincarnate);
      this._log(`[转世判断] dead=${gameState.dead} hasReincarnateEffect=${hasReincarnateEffect} game_ended=${endingFlag} cardId=${card.id}`);
      if (endingFlag && !hasReincarnateEffect) {
        // 终局效果刚触发：保留系统切换出的结局卡，等待玩家确认传承。
        this._log(`[转世判断] game_ended=true，阻止转世，保留结局卡展示`);
        return true;
      }
      if (endingFlag && hasReincarnateEffect) {
        if (gameState.clearFlag) gameState.clearFlag('game_ended');
        else delete gameState.flags.game_ended;
      }
      const fromEnding = card.id.startsWith('ending_');
      this._log(`[转世判断] 进入 _reincarnate()`);
      this._reincarnate({
        fromEnding,
        archiveMeta: {
          cause: fromEnding ? card.title : (gameState.deadReason || card.title),
          deathCauseId: gameState.deathCauseId || null,
          endingId: fromEnding ? gameState.endingId : null,
          ending: fromEnding ? card.title : null
        }
      });
      this._topLevelDecisionDisposition = 'internal';
      return true;
    }

    // 秘境推进
    if (gameState.dungeon && !choice.dungeon) {
      this.cardSystem.advanceDungeon();
    }

    // 回避目录遭遇代表“尚未解决”，由 EncounterDirector 冷却后重排；
    // 不能沿用普通 once 卡语义把整场内容永久注销。选择本身仍进入
    // choiceHistory、turn 与 encounter:avoided 遥测。
    const avoidedEncounter = Boolean(
      card.encounterId
      && !(choice.triggerCombat || choice.effects?.triggerCombat)
    );
    if (!avoidedEncounter) gameState.cardsPlayed.push(card.id);
    const projectedDecisionIndex = typeof gameState.getNextDecisionIndex === 'function'
      ? gameState.getNextDecisionIndex()
      : Math.max(0, Number(gameState.turn) || 0) + 1;

    // ── v2.0 上瘾引擎钩子 ──
    // 传承残卷掉落检测
    if (typeof legacyFragmentSystem !== 'undefined' && legacyFragmentSystem && card.type !== 'COMBAT') {
      const frag = legacyFragmentSystem.tryDrop(gameState.realm, { path: gameState.path });
      if (frag) {
        // 检查是否集齐
        const completions = legacyFragmentSystem.checkCompletions();
        for (const set of completions) {
          this._log(`🎉 传承合成：${set.name}！${set.effect}`);
        }
      }
    }
    // 后置中断保持既有优先级，每次选择最多排入一个；但不能提前 return，
    // 否则回合、历史、叙事线程与寿元等结算会被截断。
    let postChoiceInterruptQueued = false;
    // The first-session serial flag was captured before effects and chapter
    // checks, so the same authored continuation governs every ambient insert
    // point in this transaction. Death and already-due contractual work below
    // remain able to preempt it.
    // A realm transaction is an authored, unresolved player decision. Random
    // interruptions may be evaluated after it is settled, but never allowed to
    // replace the immediate inheritance → arrival handoff.
    const mandatoryRealmContinuation = card?.id === 'breakthrough_reward'
      && gameState.realmTransition?.status === 'inheritance_pending';

    // A due ghost debt is a contractual deadline, not ambient market cadence.
    // Queue it before destiny/karma/hint checks; otherwise any one of those
    // signals could suppress collection until another core decision has passed.
    const dueGhostDebt = !mandatoryRealmContinuation
      && typeof marketSystem !== 'undefined' && marketSystem
      && !this.combatCoordinator.isInCombat()
      ? this._queueDueGhostDebt(projectedDecisionIndex)
      : null;
    if (dueGhostDebt) postChoiceInterruptQueued = true;

    // 命盘轮转触发检测
    if (!mandatoryRealmContinuation && !firstSessionSerialContinuation && !postChoiceInterruptQueued
      && typeof destinyWheelSystem !== 'undefined' && destinyWheelSystem && !this.combatCoordinator.isInCombat()) {
      if (destinyWheelSystem.tick(projectedDecisionIndex)) {
        eventBus.emit('destiny:triggered', destinyWheelSystem.getState());
        postChoiceInterruptQueued = true;
      }
    }
    // 因果涟漪触发检测
    if (!mandatoryRealmContinuation && !firstSessionSerialContinuation && !postChoiceInterruptQueued && typeof karmaRippleSystem !== 'undefined' && karmaRippleSystem && !this.combatCoordinator.isInCombat()) {
      const ripple = karmaRippleSystem.tick(projectedDecisionIndex);
      if (ripple) {
        if (typeof flowDirector !== 'undefined' && flowDirector) flowDirector.setPending('ripple', ripple);
        else this._pendingRipple = ripple;
        postChoiceInterruptQueued = true;
      }
    }
    // 天机一闪触发检测
    if (!mandatoryRealmContinuation && !firstSessionSerialContinuation && !postChoiceInterruptQueued && typeof heavensHintSystem !== 'undefined' && heavensHintSystem && !this.combatCoordinator.isInCombat()) {
      const hint = heavensHintSystem.tick(projectedDecisionIndex);
      if (hint) {
        if (typeof flowDirector !== 'undefined' && flowDirector) flowDirector.setPending('hint', hint);
        else this._pendingHint = hint;
        postChoiceInterruptQueued = true;
      }
    }
    // 官坊正货的到期交付不是随机市场节拍。即便同一决断先产生了命盘、业报或
    // 天机提示，也必须在准确的 due index 写入 Flow；否则“第三次决断到货”会
    // 被无关的中断延后到第四次。死亡/战斗等终局边界仍由上层流程优先处理。
    const licensedDelivery = !mandatoryRealmContinuation
      && typeof marketSystem !== 'undefined' && marketSystem
      && !this.combatCoordinator.isInCombat()
      ? this._queueDueLicensedSwordDelivery(projectedDecisionIndex)
      : null;
    if (licensedDelivery) postChoiceInterruptQueued = true;
    // A provenance fact can promise a later scene without turning that scene
    // into another shop button. The Flow queue is durable and de-duplicates by
    // the fact/consumer card id; the fact itself remains active until the
    // player resolves one of the authored choices.
    const narrativeFact = !mandatoryRealmContinuation
      && typeof narrativeLedger !== 'undefined' && narrativeLedger
      && !this.combatCoordinator.isInCombat()
      ? this._queueNarrativeFactConsumer(projectedDecisionIndex)
      : null;
    if (narrativeFact) postChoiceInterruptQueued = true;
    // 集市偶遇触发检测
    if (!mandatoryRealmContinuation && !firstSessionSerialContinuation && !postChoiceInterruptQueued && typeof marketSystem !== 'undefined' && marketSystem && !this.combatCoordinator.isInCombat()) {
      const mkt = this._queueMarketForProjectedDecision(projectedDecisionIndex, { skipLicensedDelivery: true });
      if (mkt) {
        postChoiceInterruptQueued = true;
      }
    }
    // 世界事件公告（沉浸 v2.0 P2）
    if (!this.combatCoordinator.isInCombat()) {
      this._tickWorldEvents();
    }

    // 寿元消耗
    if (this._shouldConsumeLifespan(card, choice)) {
      gameState.addResource('lifespan', null, -1);
    }

    // 【因果种子】lifespanWaste：寿元 <= 20 时种下危机种子
    if (gameState.resources.lifespan <= 20 && gameState.resources.lifespan > 0) {
      if (typeof karmaSystem !== 'undefined' && karmaSystem) {
        // 避免重复种下
        const existing = karmaSystem.getActiveSeeds && karmaSystem.getActiveSeeds('lifespanWaste');
        if (!existing || existing.length === 0) {
          karmaSystem.plantSeed({
            id: 'lifespanWaste',
            description: `寿元仅剩 ${gameState.resources.lifespan} 年，身体开始衰竭。`,
            originCard: card.id,
            magnitude: Math.max(1, 30 - gameState.resources.lifespan)
          });
        }
      }
    }

    // NPC情绪衰减 + 同位置交叉互动检测（修复：此前从未被调用）
    if (typeof npcSystem !== 'undefined' && npcSystem && typeof npcSystem._tick === 'function') {
      npcSystem._tick();
    }

    // 【环环相扣：法宝/功法被动】每轮回血/福缘加成
    this._applyPassiveRegen();

    // 【环环相扣：道侣危机】善恶剧烈变化时触发情劫/危机
    this._checkCompanionCrisis(card, direction, choice);

    // === 选择回响：在弧线/道侣/师尊/盟友卡上种回响种子 ===
    this._plantChoiceEcho(card, direction, choice);

    // === 故事线程：记录选择历史 + 线程推进 ===
    this._recordChoiceHistory(card, direction, choice);
    this._advanceStoryThreadsAfterChoice(card, direction, choice);

    if (this.choiceOutcomeRouter && typeof this.choiceOutcomeRouter.commitChoice === 'function') {
      const outcomeCommit = this.choiceOutcomeRouter.commitChoice(card, direction, choice);
      if (outcomeCommit?.immediateCard) {
        this._pendingPromiseResultCard = outcomeCommit.immediateCard;
      }
    }

    // Event: 卡牌被选择
    eventBus.emit('card:chosen', { card, direction, choice });

    // 【沉浸 v2.5】道侣耳语 — 每次选择后触发
    this._triggerCompanionWhisper(card, direction);

    // 【沉浸 v2.0】检测属性剧变 → 触发心念
    this._checkAttrSurges();
    // 心念冷却递减
    if (this._innerVoiceCooldown > 0) this._innerVoiceCooldown--;

    // 终局卡只读取 GameStateManager 的持久权威 ID，不能从候选或私有指针猜测。
    if (gameState.lifePhase === 'EPILOGUE' && gameState.pendingCardId) {
      this.currentCard = cardSystem.getCard(gameState.pendingCardId);
      this._triggerUpdate();
      return true;
    }

    // 检查死亡
    if (gameState.checkDeath()) {
      const pn = gameState.playerName || '\u59da\u51cc\u4e91';
      this._log(`${pn}\uff0c\u9053\u6d88\u8eab\u9699\u3002${gameState.deadReason}`);
      this.currentCard = this._getNextCardFromAuthoritativeFlow();
      this._triggerUpdate();
      return true;
    }

    // 传承选择完成后才把破境事务推进到入境承接卡。它必须发生在普通卡流之前，
    // 否则刷新后会把已赢的境界门槛和未完成的成长选择割裂开。
    this._activateRealmTransitionArrival(card);
    // 入境选择已实际通过 effects/成本结算，才允许关闭事务；若选择被前置校验
    // 拒绝，则该卡仍是唯一恢复点，刷新不会静默跳过成长决定。
    this._completeRealmTransitionArrival(card);

    // 下一张卡：优先使用支线推进事件注入的 nextCardId
    if (this._pendingRealmTransitionCard) {
      this.currentCard = this._pendingRealmTransitionCard;
      this._pendingRealmTransitionCard = null;
    } else if (this._questNextCardId && hadPendingQuestContinuation) {
      this.currentCard = this.cardSystem.getCard(this._questNextCardId);
      this._questNextCardId = null;
    } else if (postChoiceInterruptQueued) {
      // 显式 nextCard 需要跨中断保留；QuestSystem 注入的 continuation
      // 已经使用同一个槽位，因此不覆盖更高优先级的任务推进。
      if (!this._questNextCardId && protectedContinuationCardId) {
        this._questNextCardId = protectedContinuationCardId;
      }
      this.currentCard = null;
    } else if (firstSessionSerialContinuation && protectedContinuationCardId) {
      // Do not let the generic tail re-derive this protected promise from a
      // transient choice clone. A newly queued quest remains in its existing
      // slot for the subsequent decision; it cannot erase this arrival.
      this.currentCard = this.cardSystem.getCard(protectedContinuationCardId);
    } else if (this._questNextCardId) {
      this.currentCard = this.cardSystem.getCard(this._questNextCardId);
      this._questNextCardId = null;
    } else if (choice.nextCard) {
      // 兜底：兼容旧数据中直接在 choice 上设置的 nextCard
      this.currentCard = this.cardSystem.getCard(choice.nextCard);
    } else {
      this.currentCard = null;
    }

    // ── 新手引导：教程完成处理 ──
    if (card.id && card.id.startsWith('tutorial_') && !choice.nextCard && !this._questNextCardId) {
      gameState.unlocks.tutorialCompleted = true;
      gameState._saveUnlocks();
      const pathStarterMap = {
        sword: 'q_start_sword',
        spell: 'q_start_spell',
        body: 'q_start_body',
        pill: 'q_start_pill'
      };
      const starterId = pathStarterMap[gameState.path] || 'q_meditation';
      this.currentCard = cardSystem.getCard(starterId);
      this._log('【引导】教程完成，仙途正式开启。');
    }

    // An authored promise is the direct consequence of the decision that just
    // settled. A quest/next-card branch may wait behind it, but must not erase
    // it or be erased by it. The exact result also remains in Flow so refresh
    // can recover this dynamic card even though CardSystem has no static ID.
    if (this._pendingPromiseResultCard) {
      const deferredCard = this.currentCard;
      if (deferredCard?.id && deferredCard.id !== this._pendingPromiseResultCard.id
        && !this._questNextCardId && this.cardSystem?.getCard?.(deferredCard.id)) {
        this._questNextCardId = deferredCard.id;
      }
      this.currentCard = this._pendingPromiseResultCard;
      this._pendingPromiseResultCard = null;
    }

    // `choice.nextCard` does not call getCurrentCard(), so it must use the
    // same arrival port as a normally drawn location card. This is deliberately
    // after promise substitution: only the card actually shown may move the
    // player and be persisted as the next decision.
    this._syncCardDrivenLocation(this.currentCard, 'choice_continuation');

    // ── 叙事连贯性层：构建卡牌间过渡文字（方案B）──
    const nextCard = this.currentCard;
    if (typeof coherenceLayer !== 'undefined' && coherenceLayer && nextCard) {
      const transition = coherenceLayer.buildTransition(
        nextCard, gameState,
        typeof threadEngine !== 'undefined' ? threadEngine : null,
        typeof questSystem !== 'undefined' ? questSystem : null,
        typeof npcSystem !== 'undefined' ? npcSystem : null
      );
      coherenceLayer.setPendingTransition(transition);
    }

    // Flow may draw during onUpdate. A settled choice must ripen karma and
    // persist its decision before that draw arbitrates the next visible card.
    if (this._topLevelDecisionDisposition === 'commit') {
      this._deferChoiceUiUpdate = true;
    } else if (!this._deferChoiceUiUpdate) {
      this._triggerUpdate();
    }
    if (pauseCardFlow) return true;
    return true;
  }

  /**
   * 商店关闭后统一触发的回合推进与结算
   */
  _queueDueLicensedSwordDelivery(decisionIndex = null) {
    if (typeof marketSystem === 'undefined' || !marketSystem) return null;
    const projected = Math.max(0, Number(
      decisionIndex
      ?? gameState.getNextDecisionIndex?.()
      ?? gameState.turn
    ) || 0);
    const dueDeliveries = typeof marketSystem.collectDueLicensedSwordDeliveries === 'function'
      ? marketSystem.collectDueLicensedSwordDeliveries(projected)
      : [];
    if (dueDeliveries.length === 0) return null;
    const delivery = dueDeliveries[0];
    const deliveryCard = this._buildLicensedRustedSwordDeliveryCard(delivery);
    let queued = false;
    if (typeof flowDirector !== 'undefined' && flowDirector?.enqueueInterrupt) {
      flowDirector.enqueueInterrupt(deliveryCard, 'regulated_delivery');
      queued = true;
    } else if (typeof flowDirector !== 'undefined' && flowDirector?.enqueueNarrative) {
      queued = flowDirector.enqueueNarrative(deliveryCard, 60, 'regulated_delivery') === true;
    }
    if (queued) {
      marketSystem.markLicensedSwordDeliveryQueued?.(delivery.orderId);
      return deliveryCard;
    }
    if (typeof flowDirector === 'undefined' || !flowDirector) {
      this._pendingMarket = deliveryCard;
      marketSystem.markLicensedSwordDeliveryQueued?.(delivery.orderId);
      return deliveryCard;
    }
    return null;
  }

  _queueMarketForProjectedDecision(decisionIndex = null, { skipLicensedDelivery = false } = {}) {
    if (typeof marketSystem === 'undefined' || !marketSystem) return null;
    const projected = Math.max(0, Number(
      decisionIndex
      ?? gameState.getNextDecisionIndex?.()
      ?? gameState.turn
    ) || 0);
    const queuedDebtCard = this._queueDueGhostDebt(projected);
    if (queuedDebtCard) return queuedDebtCard;
    let queuedLicensedDeliveryCard = null;
    if (!skipLicensedDelivery) {
      queuedLicensedDeliveryCard = this._queueDueLicensedSwordDelivery(projected);
      if (queuedLicensedDeliveryCard && typeof flowDirector === 'undefined') return queuedLicensedDeliveryCard;
    }
    const market = marketSystem.tick(projected);
    if (market) {
      if (typeof flowDirector !== 'undefined' && flowDirector) flowDirector.setPending('market', market);
      else this._pendingMarket = market;
    }
    return queuedLicensedDeliveryCard || market;
  }

  _queueDueGhostDebt(decisionIndex = null) {
    if (typeof marketSystem === 'undefined' || !marketSystem) return null;
    const projected = Math.max(0, Number(
      decisionIndex
      ?? gameState.getNextDecisionIndex?.()
      ?? gameState.turn
    ) || 0);
    const dueDebts = typeof marketSystem.collectDueDebtEvents === 'function'
      ? marketSystem.collectDueDebtEvents(projected)
      : [];
    if (dueDebts.length === 0) return null;
    const debtEvent = dueDebts[0];
    const debtCard = this._buildGhostDebtDueCard(debtEvent);
    let queued = false;
    if (typeof flowDirector !== 'undefined' && flowDirector?.enqueueInterrupt) {
      flowDirector.enqueueInterrupt(debtCard, 'ghost_debt');
      queued = true;
    } else if (typeof flowDirector !== 'undefined' && flowDirector?.enqueueNarrative) {
      queued = flowDirector.enqueueNarrative(debtCard, 64, 'ghost_debt') === true;
    }
    if (queued) {
      marketSystem.markDebtPursuitQueued?.(debtEvent.debtId);
      return debtCard;
    }
    if (typeof flowDirector === 'undefined' || !flowDirector) {
      this._pendingMarket = debtCard;
      marketSystem.markDebtPursuitQueued?.(debtEvent.debtId);
      return debtCard;
    }
    return null;
  }

  _buildNarrativeFactConsumerCard(entry) {
    const factInstanceId = typeof entry?.factInstanceId === 'string' ? entry.factInstanceId : '';
    const consumerId = typeof entry?.consumer?.consumerId === 'string' ? entry.consumer.consumerId : '';
    const narrative = entry?.consumer?.narrative && typeof entry.consumer.narrative === 'object'
      ? entry.consumer.narrative : null;
    if (!factInstanceId || !consumerId || !narrative || !Array.isArray(narrative.choices)) return null;
    const choices = {};
    const directions = ['left', 'right', 'up', 'down'];
    narrative.choices.slice(0, directions.length).forEach((choice, index) => {
      if (!choice || typeof choice.id !== 'string' || !choice.id) return;
      choices[directions[index]] = {
        text: choice.text || '作出回应',
        desc: choice.desc || '',
        effects: {},
        action: {
          type: 'RESOLVE_NARRATIVE_FACT_CONSUMER',
          factInstanceId,
          consumerId,
          outcomeId: choice.id,
          receiptDisposition: choice.receiptDisposition || choice.id
        }
      };
    });
    if (Object.keys(choices).length === 0) return null;
    return {
      id: `narrative_fact:${factInstanceId}:${consumerId}`,
      semanticKey: `narrative_fact:${factInstanceId}:${consumerId}`,
      // Flow has to validate this durable interrupt against the fact itself,
      // not merely against the card's once-policy. A fact can be consumed
      // while an earlier system interrupt is being shown.
      causalFactInstanceId: factInstanceId,
      causalConsumerId: consumerId,
      title: narrative.title || entry.consumer.label || '旧事追索',
      description: narrative.description || entry.consumer.description || '',
      type: 'NARRATIVE_FACT_CONSUMER',
      realm: gameState.realm,
      weight: 0,
      once: true,
      choices
    };
  }

  _queueNarrativeFactConsumer(decisionIndex = null) {
    if (typeof narrativeLedger === 'undefined' || !narrativeLedger?.getEligibleConsumerFacts) return null;
    const index = Math.max(0, Number(
      decisionIndex ?? gameState.getNextDecisionIndex?.() ?? gameState.getDecisionIndex?.() ?? gameState.turn
    ) || 0);
    narrativeLedger.closeExpiredFacts?.({ decisionIndex: index, persist: false });
    const eligible = narrativeLedger.getEligibleConsumerFacts({ vendorId: 'narrative_flow', decisionIndex: index }) || [];
    const entry = eligible.find(candidate => candidate?.consumer?.narrative);
    const card = this._buildNarrativeFactConsumerCard(entry);
    if (!card) return null;
    const priority = Math.max(1, Number(entry.consumer.narrative?.priority) || 58);
    // This is a time-bounded causality contract, not ambient flavor. It must
    // interrupt the next card handoff when it becomes due; a normal narrative
    // queue may defer it behind budget and let the authored window expire.
    if (typeof flowDirector !== 'undefined' && flowDirector?.enqueueInterrupt) {
      flowDirector.enqueueInterrupt(card, 'causal_fact');
      return card;
    }
    if (typeof flowDirector !== 'undefined' && flowDirector?.enqueueNarrative) {
      return flowDirector.enqueueNarrative(card, priority, 'causal_fact') === true ? card : null;
    }
    // Isolated harnesses without Flow still retain the exact card as a
    // pending consequence. Production always uses the durable Flow queue.
    if (!this._pendingNarrativeFactCard || this._pendingNarrativeFactCard.id !== card.id) {
      this._pendingNarrativeFactCard = card;
      return card;
    }
    return null;
  }

  _resolveNarrativeFactConsumerAction(action) {
    const contract = this._getNarrativeFactConsumerActionContract(action);
    if (!contract.valid) {
      this._lastChoiceRejection = contract.reason;
      return false;
    }
    const { fact, authoredChoice } = contract;
    const consumed = narrativeLedger.consumeFact({
      factInstanceId: action.factInstanceId,
      consumerId: action.consumerId,
      decisionIndex: gameState.getNextDecisionIndex?.() ?? gameState.getDecisionIndex?.() ?? gameState.turn,
      receipt: {
        outcomeId: authoredChoice.id,
        disposition: authoredChoice.receiptDisposition || authoredChoice.id,
        sellerLeadId: fact.payload?.sellerLeadId || null,
        itemInstanceId: fact.payload?.itemInstanceId || null
      },
      persist: false
    });
    if (!consumed?.consumed) {
      this._lastChoiceRejection = 'narrative_fact_already_resolved';
      return false;
    }
    this._log(`【旧主追索】${authoredChoice.receiptDisposition === 'named_luo_route'
      ? '你交出了许爷的去向。' : '你压下了许爷的去向。'}`);
    return true;
  }

  _narrativeSpineDecisionIndex() {
    return gameState.getNextDecisionIndex?.() ?? gameState.getDecisionIndex?.() ?? gameState.turn;
  }

  /**
   * Settle an authored chapter beat inside the caller's existing top-level
   * transaction.  A spine has no independent scheduler: every beat consumes
   * exactly the previous beat before it produces its successor.
   */
  _settleNarrativeSpineChoice(card, direction) {
    const spine = card?.narrativeSpine;
    if (!spine?.threadId || typeof narrativeLedger === 'undefined' || !narrativeLedger) return true;
    const decisionIndex = this._narrativeSpineDecisionIndex();
    const choicePayload = spine.choicePayload?.[direction] && typeof spine.choicePayload[direction] === 'object'
      ? spine.choicePayload[direction]
      : {};
    const consumes = Array.isArray(spine.consumes) ? spine.consumes : [];
    for (const factTypeId of consumes) {
      const fact = narrativeLedger.getFactByType?.(factTypeId);
      const consumerId = spine.consumerIds?.[factTypeId];
      const settled = fact && consumerId ? narrativeLedger.consumeFact({
        factInstanceId: fact.factInstanceId,
        consumerId,
        decisionIndex,
        receipt: {
          threadId: spine.threadId,
          step: spine.step,
          sourceCardId: card.id,
          direction
        },
        persist: false
      }) : { consumed: false, reason: 'missing_spine_predecessor' };
      if (!settled?.consumed) {
        this._lastChoiceRejection = `narrative_spine_${settled?.reason || 'settlement_rejected'}`;
        this._log(`【${spine.label || '主线'}】前一拍未能结算，本次选择未成立。`);
        return false;
      }
    }
    const produces = Array.isArray(spine.produces) ? spine.produces : [];
    for (const factTypeId of produces) {
      const produced = narrativeLedger.recordFact?.({
        factTypeId,
        producerId: `${card.id}:${direction}`,
        decisionIndex,
        payload: {
          threadId: spine.threadId,
          step: spine.step,
          sourceCardId: card.id,
          direction,
          ...choicePayload,
          observedOrigins: Array.isArray(spine.observedOrigins) ? spine.observedOrigins.map(entry => ({
            factTypeId: entry.factTypeId,
            status: entry.status
          })) : []
        },
        persist: false
      });
      if (!produced?.created) {
        this._lastChoiceRejection = `narrative_spine_${produced?.reason || 'production_rejected'}`;
        this._log(`【${spine.label || '主线'}】这一拍的回执未能写入，本次选择未成立。`);
        return false;
      }
    }
    return true;
  }

  /**
   * Old saves may have already reached the legacy qi gate before the five-beat
   * spine existed.  Create only the missing terminal receipts, with an explicit
   * migration provenance, so they can finish one real combat without minting
   * rewards or replaying earlier chapters.
   */
  _prepareNarrativeSpineCombat(card) {
    const settlement = card?.narrativeSpine?.combatSettlement;
    if (!settlement || typeof narrativeLedger === 'undefined' || !narrativeLedger) return card;
    const decisionIndex = this._narrativeSpineDecisionIndex();
    const migration = settlement.legacyMigration && typeof settlement.legacyMigration === 'object'
      ? settlement.legacyMigration
      : {};
    const required = Array.isArray(settlement.consumes) ? settlement.consumes : [];
    const missing = required.filter(factTypeId => !narrativeLedger.getFactByType?.(factTypeId));
    if (!missing.length) return card;
    for (const factTypeId of missing) {
      const defaultPayload = migration.defaultPayloadByFactType?.[factTypeId]
        && typeof migration.defaultPayloadByFactType[factTypeId] === 'object'
        ? migration.defaultPayloadByFactType[factTypeId]
        : {};
      const produced = narrativeLedger.recordFact?.({
        factTypeId,
        producerId: migration.producerId || `${card.narrativeSpine.threadId}:legacy_gate_migration`,
        decisionIndex,
        payload: {
          threadId: card.narrativeSpine.threadId,
          step: card.narrativeSpine.step,
          legacyMigration: true,
          ...defaultPayload
        },
        persist: false
      });
      if (!produced?.created) return card;
    }
    this._log(migration.log || `【${card.narrativeSpine.label || '主线'}】旧世记录抵达终局，已补写无额外收益的迁移回执。`);
    return card;
  }

  /**
   * Direct realm-gate combat has no choice source to settle.  Its authoritative
   * combat outcome is therefore the sole terminal consumer for the trial and
   * stance receipts.  The coordinator's ordinary outcome checkpoint persists
   * this staged ledger state together with the reward card.
   */
  _settleNarrativeSpineCombatOutcome(outcome, card) {
    const spine = card?.narrativeSpine;
    const settlement = spine?.combatSettlement;
    this._lastNarrativeSpineCombatSettlement = { accepted: true, stateRolledBack: false };
    if (!settlement || typeof narrativeLedger === 'undefined' || !narrativeLedger) return true;
    // Defeat and retreat keep the realm gate retryable. They may update Flow's
    // gate cadence, but they are not the terminal verdict and therefore must
    // never consume the player's last active spine fact or mint an outcome.
    if (outcome === 'defeat' || outcome === 'flee') {
      const authoredRetryText = settlement.resultTextByOutcome
        && typeof settlement.resultTextByOutcome === 'object'
        ? settlement.resultTextByOutcome[outcome]
        : null;
      const retryText = typeof authoredRetryText === 'string' && authoredRetryText
        ? authoredRetryText
        : outcome === 'flee'
          ? '你暂退终局，未竟的选择仍留待下一次整备兑现。'
          : '终局击碎了这次试炼，但没有抹去你已经立下的选择。';
      this._log(`【${spine.label || '主线'} ${spine.step}/${spine.totalSteps}】${retryText}`);
      return true;
    }
    if (outcome !== 'victory') {
      this._lastNarrativeSpineCombatSettlement = { accepted: false, stateRolledBack: false };
      this._log(`【${spine.label || '主线'}】未知终局结果未被接受。`);
      return false;
    }
    const outcomeFactTypeId = Array.isArray(spine.produces)
      ? spine.produces.find(factTypeId => typeof factTypeId === 'string' && factTypeId)
      : null;
    if (!outcomeFactTypeId) {
      this._lastNarrativeSpineCombatSettlement = { accepted: false, stateRolledBack: false };
      this._log(`【${spine.label || '主线'}】终局缺少作者化结果事实，本次裁定未写入。`);
      return false;
    }
    // A realm-gate outcome is one causal receipt, not two loosely related
    // writes.  In particular, never consume the player's last active fact
    // until the terminal verdict is known to exist.  The direct gate has no
    // makeChoice wrapper, so it owns the causal transaction itself and leaves
    // a successful transaction open for CombatCoordinator's single durable
    // outcome checkpoint.
    const ledgerBefore = typeof narrativeLedger.exportState === 'function'
      ? narrativeLedger.exportState()
      : null;
    const state = typeof gameState !== 'undefined' && gameState ? gameState : null;
    const ownsTransaction = Boolean(
      state
      && !state._causalTransaction
      && typeof state.beginCausalTransaction === 'function'
      && typeof state.rollbackCausalTransaction === 'function'
    );
    if (ownsTransaction && state.beginCausalTransaction() !== true) {
      this._lastNarrativeSpineCombatSettlement = { accepted: false, stateRolledBack: false };
      this._log(`【${spine.label || '主线'}】无法建立终局回执事务，本次裁定未写入。`);
      return false;
    }
    const rollbackSettlement = () => {
      const stateRolledBack = ownsTransaction && state.rollbackCausalTransaction() === true;
      // Unit runtimes and a nested outer decision may not own a GameState
      // transaction.  These operations mutate only NarrativeLedger, so its
      // exact pre-settlement snapshot is the safe local fallback.
      if (ledgerBefore && typeof narrativeLedger.hydrateState === 'function') {
        narrativeLedger.hydrateState(ledgerBefore);
      }
      if (!ownsTransaction && state) {
        state.narrativeLedgerState = ledgerBefore ? JSON.parse(JSON.stringify(ledgerBefore)) : null;
      }
      this._lastNarrativeSpineCombatSettlement = { accepted: false, stateRolledBack };
    };
    const decisionIndex = this._narrativeSpineDecisionIndex();
    const consumedPayloads = {};
    for (const factTypeId of settlement.consumes || []) {
      const fact = narrativeLedger.getFactByType?.(factTypeId);
      const consumerId = settlement.consumerIds?.[factTypeId];
      const settled = fact && consumerId ? narrativeLedger.consumeFact({
        factInstanceId: fact.factInstanceId,
        consumerId,
        decisionIndex,
        receipt: { threadId: spine.threadId, outcome, combatCardId: card.id },
        persist: false
      }) : { consumed: false, reason: 'missing_spine_combat_receipt' };
      if (!settled?.consumed) {
        rollbackSettlement();
        this._log(`【${spine.label || '主线'}】雷劫已结束，但主线回执未能重复结算。`);
        return false;
      }
      consumedPayloads[factTypeId] = settled.fact?.payload || {};
    }
    const outcomePayload = {
      threadId: spine.threadId,
      step: spine.step,
      outcome,
      sourceCardId: card.id
    };
    const outcomeFields = Array.isArray(settlement.outcomePayloadFields)
      ? settlement.outcomePayloadFields
      : [];
    for (const field of outcomeFields) {
      if (!field || typeof field !== 'object') continue;
      const factTypeId = typeof field.factTypeId === 'string' ? field.factTypeId : '';
      const sourceKey = typeof field.sourceKey === 'string' ? field.sourceKey : '';
      const targetKey = typeof field.targetKey === 'string' && field.targetKey ? field.targetKey : sourceKey;
      if (!factTypeId || !sourceKey || !targetKey) continue;
      const value = consumedPayloads[factTypeId]?.[sourceKey];
      outcomePayload[targetKey] = value === undefined ? field.fallback : value;
    }
    const produced = narrativeLedger.recordFact?.({
      factTypeId: outcomeFactTypeId,
      producerId: `${card.id}:combat:${outcome}`,
      decisionIndex,
      payload: outcomePayload,
      persist: false
    });
    if (!produced?.created) {
      rollbackSettlement();
      this._log(`【${spine.label || '主线'}】雷劫结果未能写入主线回执。`);
      return false;
    }
    const authoredResult = settlement.resultTextByOutcome && typeof settlement.resultTextByOutcome === 'object'
      ? settlement.resultTextByOutcome[outcome]
      : null;
    const resultText = typeof authoredResult === 'string' && authoredResult
      ? authoredResult
      : outcome === 'victory' ? '终局认可了你这一世的选择。'
        : outcome === 'flee' ? '你暂退终局，未竟的选择仍留下一道裂隙。'
          : '终局击碎了这次试炼，但你的选择已被如实记下。';
    this._log(`【${spine.label || '主线'} ${spine.step}/${spine.totalSteps}】${resultText}`);
    this._lastNarrativeSpineCombatSettlement = { accepted: true, stateRolledBack: false };
    return true;
  }

  _buildGhostDebtDueCard(event) {
    const debtId = event?.debtId || 'unknown_debt';
    const debt = gameState.marketState?.debts?.find(entry => entry?.debtId === debtId) || null;
    const settlementCost = Array.isArray(debt?.settlementCostSpec) ? debt.settlementCostSpec : [];
    const settlementStone = settlementCost
      .filter(cost => cost?.kind === 'resource' && cost.key === 'spiritStone')
      .reduce((total, cost) => total + Math.max(0, Number(cost?.amount) || 0), 0);
    const settlementLabel = settlementStone > 0 ? `${settlementStone} 灵石` : '一笔未明代价';
    const oath = debt?.kind === 'ghost_oath_sword';
    const oathLabel = oath ? (debt.contractLabel || '夜契残剑') : '鬼市契约';
    const pressure = debt?.pressure || null;
    const pressureText = oath && pressure
      ? ` 你仍可从已穿戴此剑的胜利中催近债期：每场 ${Math.round((Number(pressure.chance) || 0) * 100)}%，连续 ${pressure.pityLimit || 3} 场保底。`
      : '';
    return {
      id: `ghost_debt_due:${debtId}`,
      title: '鬼市 · 无面人索债',
      description: `雾里有人扣响门环。${oathLabel}以寿元签下的契约已经到期；留名还须补上 ${settlementLabel}，拒约则永失鬼市门路。${pressureText}`,
      type: 'GHOST_DEBT_DUE',
      causalFactInstanceId: oath ? debt.sourceFactInstanceId : null,
      causalConsumerId: oath ? 'ghost_oath_debt_settlement' : null,
      realm: gameState.realm,
      weight: 0,
      once: true,
      choices: {
        left: {
          text: `按约留名（${settlementLabel}）`, effects: {},
          action: { type: 'SETTLE_GHOST_DEBT', debtId, outcome: 'settled' },
          desc: `补足 ${settlementLabel}；无面人收下回执，鬼市仍认得你的名字。`
        },
        right: {
          text: '拒不应约', effects: {},
          action: { type: 'SETTLE_GHOST_DEBT', debtId, outcome: 'defaulted' },
          desc: '此后鬼市之门将不再为你开启。'
        }
      }
    };
  }

  _buildLicensedRustedSwordDeliveryCard(order) {
    const orderId = typeof order?.orderId === 'string' ? order.orderId : 'unknown_order';
    const name = typeof order?.orderLabel === 'string' && order.orderLabel ? order.orderLabel : '坊市净炼残剑';
    return {
      id: `regulated_rusted_sword_delivery:${orderId}`,
      title: '坊市 · 官坊正货已到',
      description: `三次决断已过，坊市差役送来一只覆着官印的窄匣。你曾用流转号登记的【${name}】已经净炼完毕；回执、灵石定金与器物来路在同一册上，可以当面验收。`,
      type: 'REGULATED_RUSTED_SWORD_DELIVERY',
      realm: gameState.realm,
      weight: 0,
      once: true,
      choices: {
        left: {
          text: '验印收讫',
          effects: {},
          action: { type: 'CLAIM_LICENSED_RUSTED_SWORD', orderId },
          desc: '领取净炼残剑，并立刻决定是否穿戴。'
        }
      }
    };
  }

  _resolveGhostDebtAction(action) {
    const contract = this._getGhostDebtActionContract(action);
    if (!contract.valid) {
      this._lastChoiceRejection = contract.reason;
      this._log(contract.reason === 'ghost_debt_settlement_unaffordable'
        ? `【鬼市】留名还需 ${contract.stoneDue} 灵石；契约未被结清。`
        : '【鬼市】这笔债已无可结算的状态。');
      return false;
    }
    const { debt, outcome, settlementCost, stoneDue } = contract;
    if (debt.kind === 'ghost_oath_sword') {
      const consumed = narrativeLedger.consumeFact({
        factInstanceId: debt.sourceFactInstanceId,
        consumerId: 'ghost_oath_debt_settlement',
        decisionIndex: gameState.getNextDecisionIndex?.() ?? gameState.getDecisionIndex?.() ?? gameState.turn,
        receipt: { debtId: debt.debtId, outcome: outcome.toLowerCase(), acquiredInstanceId: debt.acquiredInstanceId || null },
        persist: false
      });
      if (!consumed?.consumed) {
        this._lastChoiceRejection = 'ghost_oath_fact_settlement_rejected';
        return false;
      }
    }
    if (outcome === 'SETTLED') {
      if (stoneDue > 0 && gameState.addResource?.('spiritStone', null, -stoneDue) === false) {
        this._lastChoiceRejection = 'ghost_debt_settlement_failed';
        return false;
      }
      debt.settlementCostSpec = JSON.parse(JSON.stringify(settlementCost));
      debt.settlementPaid = JSON.parse(JSON.stringify(settlementCost));
    }
    debt.status = outcome;
    debt.settlementReceiptId = `debt_settlement:${debt.debtId}:${outcome.toLowerCase()}`;
    debt.pursuitQueued = false;
    if (outcome === 'DEFAULTED' && debt.defaultConsequence === 'ghost_market_access_revoked') {
      gameState.marketState.ghostMarketAccess = 'revoked';
    }
    eventBus.emit('market:debtSettled', { debtId: debt.debtId, outcome, settlementCost: outcome === 'SETTLED' ? settlementCost : [] });
    return true;
  }

  _resolveLicensedRustedSwordDeliveryAction(action) {
    if (typeof shopSystem === 'undefined' || !shopSystem?.fulfillLicensedRustedSwordOrder) {
      this._lastChoiceRejection = 'regulated_delivery_unavailable';
      this._log('【坊市】官坊账册暂未就绪，尚不能领取正货。');
      return false;
    }
    const result = shopSystem.fulfillLicensedRustedSwordOrder(action?.orderId, { transactionManaged: true });
    if (!result?.success) {
      this._lastChoiceRejection = 'regulated_delivery_failed';
      this._log(`【坊市】${result?.message || '正货交付未能成立。'}`);
      return false;
    }
    this._log(result.replayed
      ? '【坊市】同一回执已完成交付，未重复入册。'
      : '【坊市】官印、来历与器物一并核验；净炼残剑已入纳戒。');
    // See makeChoice: wait until the outer top-level checkpoint has either
    // committed or restored this delivery card before asking UI to render a
    // successor. The delivery action's data/state writes remain in ShopSystem.
    this._deferChoiceUiUpdate = true;
    return true;
  }

  _recordMarketVisit(summary = {}) {
    const market = gameState.marketState;
    const sessionKey = typeof summary.sessionKey === 'string' && summary.sessionKey
      ? summary.sessionKey
      : (typeof summary.sessionId === 'string' ? summary.sessionId : null);
    if (!market || !sessionKey) return null;
    if (!Array.isArray(market.visitHistory)) market.visitHistory = [];
    const existing = market.visitHistory.find(entry => entry?.sessionKey === sessionKey);
    if (existing) return existing;
    const purchased = Math.max(0, Number(summary.purchaseCount) || 0);
    const interacted = Math.max(0, Number(summary.interactionCount) || 0);
    const missedOffers = (Array.isArray(summary.remainingOffers) ? summary.remainingOffers : [])
      .filter(offer => offer && typeof offer.id === 'string')
      .map(offer => ({ id: offer.id, name: offer.name || offer.id, stallId: offer.stallId || null }));
    const projectedIndex = typeof gameState.getNextDecisionIndex === 'function'
      ? gameState.getNextDecisionIndex()
      : Math.max(0, Number(gameState.turn) || 0) + 1;
    const visit = {
      visitId: `market_visit:${sessionKey}`,
      sessionKey,
      vendorId: summary.vendorId || null,
      marketType: summary.marketType || 'regulated',
      decisionIndex: projectedIndex,
      seen: true,
      refused: purchased === 0,
      outcome: purchased > 0 ? 'traded' : interacted > 0 ? 'interacted' : 'declined',
      missedOffers
    };
    market.visitHistory.push(visit);
    // Visit history is player memory, not a full transcript. Bound it so one
    // long life cannot grow a persistence payload without limit.
    market.visitHistory = market.visitHistory.slice(-48);
    return visit;
  }

  _finalizeTurnAfterVendor(card, direction, choice, summary = {}) {
    // The delayed vendor close is still one source decision.  All of its
    // receipts, market cadence and result card therefore share one save.
    const uncommittedUi = this._captureUncommittedDecisionUi();
    if (gameState.beginCausalTransaction?.({ decisionPending: true }) === false) {
      if (this.debug) this._log('【存档】无法建立坊市结算的恢复基线，本次离开未执行。');
      return false;
    }
    // The vendor close event is authenticated by _handleVendorClosed before
    // this method runs. Apply authored rewards only inside this close
    // transaction so failure to create/close a session cannot grant them.
    const vendorCloseEffects = { ...(choice?.vendorCloseEffects || {}) };
    const summaryLocation = typeof summary?.playerLocation === 'string'
      ? summary.playerLocation.trim()
      : '';
    const persistedSummaryLocation = typeof gameState.marketState?.activeSession?.summary?.playerLocation === 'string'
      ? gameState.marketState.activeSession.summary.playerLocation.trim()
      : '';
    // A story alternative may already have moved the player before the shop
    // closes. Preserve that authored, persisted destination only when the
    // emitted close receipt, session snapshot and current world state agree;
    // an arbitrary close payload must not become a teleport authority.
    if (summaryLocation
      && summaryLocation === persistedSummaryLocation
      && summaryLocation === gameState.currentLocation) {
      vendorCloseEffects.playerLocation = summaryLocation;
    }
    this._applyEffects(vendorCloseEffects, card);
    if (card && card.id) {
      gameState.cardsPlayed.push(card.id);
    }
    if (this._shouldConsumeLifespan(card, choice)) {
      gameState.addResource('lifespan', null, -1);
    }
    if (typeof npcSystem !== 'undefined' && npcSystem && typeof npcSystem._tick === 'function') {
      npcSystem._tick();
    }
    this._applyPassiveRegen();
    this._recordChoiceHistory(card, direction, choice);
    this._recordMarketVisit(summary);
    this._advanceStoryThreadsAfterChoice(card, direction, choice, {
      mode: 'vendor',
      vendorSummary: summary
    });
    this.eventBus.emit('card:chosen', { card, direction, choice, vendorSummary: summary });
    this.currentCard = this._buildVendorResultCard(card, summary);
    if (gameState.marketState) {
      gameState.marketState.activeSession = {
        version: 2,
        status: 'result',
        resultCard: JSON.parse(JSON.stringify(this.currentCard))
      };
    }
    this._queueMarketForProjectedDecision();
    const committed = this._commitTopLevelDecision(card?.id || null, {
      kind: 'vendor',
      stableKey: summary.sessionKey || null
    });
    if (!committed) {
      this._restoreUncommittedDecisionUi(uncommittedUi);
      this._triggerUpdate();
      return false;
    }
    this._triggerUpdate();
    return true;
  }

  _buildVendorSessionKey(card, vendorId, openedAtDecisionIndex = null) {
    const lifeId = typeof gameState.getRunClock === 'function'
      ? (gameState.getRunClock()?.lifeId || 'legacy_life')
      : `legacy:${typeof gameState.getLifeCount === 'function'
        ? gameState.getLifeCount()
        : (gameState.unlocks?.lifeCount || 0)}`;
    const decisionIndex = Math.max(0, Number(
      openedAtDecisionIndex
      ?? gameState.getNextDecisionIndex?.()
      ?? gameState.turn
    ) || 0);
    return `vendor:${lifeId}:${decisionIndex}:${card?.id || 'unknown'}:${vendorId || 'regulated_market'}`;
  }

  _handleVendorClosed(summary = {}) {
    const ctx = this._pendingVendorChoiceContext;
    if (!ctx || ctx.settled || summary?.alreadyClosed) return false;
    const expectedEntryCardId = ctx.entryCardId || ctx.card?.id || null;
    if (!ctx.sessionKey
      || summary.sessionKey !== ctx.sessionKey
      || summary.vendorId !== ctx.vendorId
      || summary.entryCardId !== expectedEntryCardId) {
      if (this.debug) console.warn('[VendorSettlement] ignored foreign or stale shop close event');
      return false;
    }
    const settled = this._finalizeTurnAfterVendor(ctx.card, ctx.direction, ctx.choice, summary);
    if (!settled) return false;
    ctx.settled = true;
    this._pendingVendorChoiceContext = null;
    return true;
  }

  _buildVendorResultCard(entryCard, summary = {}) {
    const bought = Math.max(0, Number(summary.purchaseCount) || 0);
    const spent = Math.max(0, Number(summary.spiritStoneSpent) || 0);
    const offered = Math.max(0, Number(summary.openingOfferCount) || 0);
    const marketType = summary.marketType || 'regulated';
    const interacted = Math.max(0, Number(summary.interactionCount) || 0);
    const missedNames = (Array.isArray(summary.remainingOffers) ? summary.remainingOffers : [])
      .map(offer => offer?.name || offer?.id)
      .filter(Boolean)
      .slice(0, 3);
    const missedText = missedNames.length ? `错过了 ${missedNames.join('、')}${(summary.remainingOfferCount || 0) > missedNames.length ? ' 等线索' : ''}` : '没有新的货讯可记';
    const debtTerms = (Array.isArray(summary.ghostDebtTerms) ? summary.ghostDebtTerms : []).map(debt => {
      const due = Math.max(0, Math.floor(Number(debt?.dueDecisionIndex) || 0));
      const settlement = (Array.isArray(debt?.settlementCostSpec) ? debt.settlementCostSpec : [])
        .filter(cost => cost?.kind === 'resource' && cost.key === 'spiritStone')
        .reduce((total, cost) => total + Math.max(0, Number(cost?.amount) || 0), 0);
      return due > 0 ? `第 ${due} 次决断索取 ${settlement || 1} 灵石` : null;
    }).filter(Boolean);
    const labels = {
      regulated: { base: '官坊', settled: '官坊 · 交易落定', empty: '官坊 · 此行收尾' },
      public_bazaar: { base: '集市', settled: '集市 · 摊主记名', empty: '集市 · 此行收尾' },
      ghost: { base: '鬼市', settled: '鬼市 · 契约已成', empty: '鬼市 · 雾门合拢' }
    };
    const label = labels[marketType] || labels.regulated;
    const description = marketType === 'ghost'
      ? bought > 0
        ? `你签下 ${bought} 份鬼市契约，付出 ${spent} 灵石；${debtTerms.length ? `无面人记下${debtTerms.join('；')}。` : '寿元与债期已被无面人记下。'}`
        : `雾中摊主没有挽留。你拒绝了这次寿契，${missedText}；鬼市在身后合门。`
      : marketType === 'public_bazaar'
        ? bought > 0 || interacted > 0
          ? `你完成 ${bought} 笔交易，并与 ${interacted} 位摊主留下来往。花费 ${spent} 灵石；${bought === 0 ? `${missedText}，` : ''}摊主会记得。`
          : `三处摊位各有来路。你没有出手，也未留下新的口信；${missedText}。`
        : offered === 0
          ? '官坊货架暂空；盖印的回购收据仍在你手中。'
          : bought > 0
            ? `官坊记录了 ${bought} 笔明码交易，共花费 ${spent} 灵石。`
            : '你核对了官坊的明码报价，最终没有出手。';
    return {
      id: `vendor_result:${summary.sessionId || gameState.turn}:${entryCard?.id || 'unknown'}`,
      title: bought > 0 || interacted > 0 ? label.settled : label.empty,
      description,
      type: 'VENDOR_RESULT',
      realm: gameState.realm,
      weight: 0,
      once: true,
      choices: {
        right: {
          text: '继续行程',
          effects: {},
          action: { type: 'DISMISS_VENDOR_RESULT' }
        }
      }
    };
  }

  _buildVendorPendingCard(entryCard) {
    const marketType = gameState.marketState?.activeSession?.marketType || 'regulated';
    const copy = marketType === 'ghost'
      ? { title: '鬼市契约进行中', description: '禁物报价与寿契已锁定。请签约或离开；债期将在结算后开始计算。' }
      : marketType === 'public_bazaar'
        ? { title: '集市来往进行中', description: '三处摊位与本次可交谈次数已锁定。交易或记名后，再继续行程。' }
        : { title: '官坊交易进行中', description: '明码报价与回购服务已锁定。请完成交易或离开，结算后再继续行程。' };
    return {
      id: `vendor_pending:${entryCard?.id || 'unknown'}`,
        title: copy.title,
        description: copy.description,
      type: 'VENDOR_PENDING',
      realm: gameState.realm,
      weight: 0,
      once: true,
      choices: {}
    };
  }

  /**
   * 恢复由叙事选项发起的战斗。战斗结果确定前，原选项的结果效果、
   * 任务推进与因果种子都不会执行。
   */
  _resolveCombatOutcome(outcome, context, data) {
    const sourceCard = context && context.sourceCard;
    const direction = context && context.direction;
    const choice = context && context.choice;
    if (!sourceCard || !choice || !direction) return;
    this._pendingKarmaGerminations = [];
    // Coordinator has authenticated this live encounter before forwarding its
    // outcome. The source card can occur again in the same life; it is not the
    // identity of a settlement. Retries of this owner retain the same key.
    const encounterId = data?.encounterContext?.encounterInstanceId
      || data?.originalCard?.encounterContext?.encounterInstanceId;
    if (typeof encounterId !== 'string' || !encounterId.trim()) {
      if (data && typeof data === 'object') {
        data.sourceSettlement = { accepted: false, stateRolledBack: false };
      }
      return false;
    }
    // Combat actions are internal; only this outcome settles their source
    // decision, so it opens the same transaction boundary as a normal card.
    const uncommittedUi = this._captureUncommittedDecisionUi();
    if (gameState.beginCausalTransaction?.({ decisionPending: true }) === false) {
      if (data && typeof data === 'object') {
        data.sourceSettlement = { accepted: false, stateRolledBack: false };
      }
      if (this.debug) this._log('【存档】无法建立战局结算的恢复基线，结果未执行。');
      return false;
    }

    // A combat-backed chapter choice is still one authored spine decision.
    // Normal choices settle this receipt in _makeChoiceInternal; the combat
    // branch returns at the warning boundary, so its receipt must be delayed
    // until the authenticated combat outcome reaches this transaction.
    if (!this._settleNarrativeSpineChoice(sourceCard, direction)) {
      const stateRolledBack = gameState.rollbackCausalTransaction?.() === true;
      if (data && typeof data === 'object') {
        data.sourceSettlement = { accepted: false, stateRolledBack };
      }
      this._restoreUncommittedDecisionUi(uncommittedUi);
      this.discardChoiceSettlement();
      this._triggerUpdate();
      return false;
    }

    let effects = null;
    if (outcome === 'victory') {
      effects = choice.victoryEffects || choice.effects || null;
    } else if (outcome === 'defeat') {
      effects = choice.defeatEffects || null;
    } else if (outcome === 'flee') {
      effects = choice.fleeEffects || { lifespan: -1 };
    }
    let appliedDefeatHealthLoss = 0;
    if (effects || outcome === 'defeat') {
      const resolvedEffects = Object.assign({}, effects || {});
      if (outcome === 'defeat') {
        const combatCard = context.combatCard || data?.originalCard || sourceCard;
        const tier = Number(combatCard?.enemy?.tier || 1);
        const legacyEffectLoss = Number(resolvedEffects.health) < 0
          ? Math.abs(Number(resolvedEffects.health))
          : 0;
        const configuredLoss = Number(legacyEffectLoss || (
          choice.defeatHealthLoss
          ?? combatCard?.combatRules?.defeatHealthLoss
          ?? combatCard?.enemy?.defeatHealthLoss
          ?? data?.defeatHealthLoss
        ));
        let injury = Number.isFinite(configuredLoss) && configuredLoss > 0
          ? Math.round(configuredLoss)
          : tier >= 3 ? 3 : tier === 2 ? 2 : 1;
        const configuredFloor = Number(choice.defeatHealthFloor
          ?? combatCard?.defeatHealthFloor
          ?? combatCard?.combatRules?.defeatHealthFloor);
        if (Number.isFinite(configuredFloor) && configuredFloor >= 1) {
          const currentHealth = Math.max(0, Number(gameState.getAttribute('health')) || 0);
          injury = Math.min(injury, Math.max(0, currentHealth - Math.floor(configuredFloor)));
        }
        delete resolvedEffects.health;
        if (typeof gameState.applyInjury === 'function') {
          appliedDefeatHealthLoss = gameState.applyInjury(injury, {
            source: sourceCard.id,
            reason: 'combat_defeat'
          });
        } else {
          const healthBefore = gameState.getAttribute('health');
          gameState.setAttribute('health', healthBefore - injury);
          appliedDefeatHealthLoss = healthBefore - gameState.getAttribute('health');
        }
        this._log(`【战败伤势】局内护体值耗尽，真实气血 -${appliedDefeatHealthLoss}。`);
      }
      delete resolvedEffects.triggerCombat;
      if (Object.keys(resolvedEffects).length > 0) this._applyEffects(resolvedEffects, sourceCard);
    }

    const questEndOn = Array.isArray(choice.questEndOn) ? choice.questEndOn : ['victory'];
    const shouldAdvanceQuest = sourceCard.type === 'QUEST' && questEndOn.includes(outcome);
    if (shouldAdvanceQuest && typeof questSystem !== 'undefined' && questSystem) {
      questSystem.advanceQuest(direction, sourceCard, outcome);
    }

    // Combat-delayed KARMA choices use the same transaction boundary as normal
    // choices: consume the presented payoff first, then plant any successor.
    this._settleKarmaCard(sourceCard);

    // 因果种子只在被声明的结果上种下，旧数据默认胜利后种下。
    const karmaSeedOn = Array.isArray(choice.karmaSeedOn) ? choice.karmaSeedOn : ['victory'];
    if (choice.karmaSeed && karmaSeedOn.includes(outcome) && typeof karmaSystem !== 'undefined' && karmaSystem) {
      const seeds = Array.isArray(choice.karmaSeed) ? choice.karmaSeed : [choice.karmaSeed];
      for (let seed of seeds) {
        if (typeof seed === 'string') {
          seed = { id: seed, seedType: 'karma', delay: 5, priority: 1 };
        }
        karmaSystem.plantSeed(Object.assign({}, seed, {
          originCard: sourceCard.id,
          originChoice: direction,
          originOutcome: outcome
        }));
      }
    }

    if (outcome === 'victory') {
      if (sourceCard.type === 'NPC_ENCOUNTER' && choice.npcAffection !== undefined && sourceCard.npcId) {
        npcSystem.addAffection(sourceCard.npcId, choice.npcAffection);
        npcSystem.recordInteraction(sourceCard.npcId, '战斗', choice.text, choice.npcAffection);
      }
      if ((sourceCard.type === 'COMPANION_EVENT' || sourceCard.type === 'COMPANION_ARC') && choice.companionEffects) {
        companionSystem.applyChoice(choice);
      }
      if (sourceCard.type === 'FACTION_EVENT' && choice.factionEffects) {
        factionSystem.applyChoice(choice);
      }
    }

    // P2 战斗内容可按胜利/战败/逃跑分别联动伙伴、势力和因果，
    // 不再要求来源卡本身必须伪装成 COMPANION_EVENT / FACTION_EVENT。
    const outcomeLinks = choice.combatOutcomeLinks?.[outcome];
    if (outcomeLinks) {
      if (outcomeLinks.companionEffects && typeof companionSystem !== 'undefined' && companionSystem) {
        companionSystem.applyChoice({ companionEffects: outcomeLinks.companionEffects });
      }
      if (outcomeLinks.factionEffects && typeof factionSystem !== 'undefined' && factionSystem) {
        factionSystem.applyChoice({ factionEffects: outcomeLinks.factionEffects });
      }
      if (outcomeLinks.karmaSeed && typeof karmaSystem !== 'undefined' && karmaSystem) {
        const linkedSeeds = Array.isArray(outcomeLinks.karmaSeed)
          ? outcomeLinks.karmaSeed
          : [outcomeLinks.karmaSeed];
        linkedSeeds.forEach(seed => karmaSystem.plantSeed(Object.assign({}, seed, {
          originCard: sourceCard.id,
          originChoice: direction,
          originOutcome: outcome
        })));
      }
    }

    if (outcome === 'victory') {
      const combatCard = context.combatCard || data?.originalCard || sourceCard;
      const enemy = combatCard?.enemy || data?.originalCard?.enemy || sourceCard.enemy || null;
      if (enemy?.factionId && typeof karmaSystem !== 'undefined' && karmaSystem) {
        karmaSystem.plantSeed({
          id: 'combatGlory',
          seedType: 'karma',
          delay: 6,
          priority: Math.max(2, Number(enemy.tier) || 1),
          originCard: sourceCard.id,
          originChoice: direction,
          originOutcome: 'victory',
          context: {
            enemyId: enemy.id || null,
            enemyName: enemy.name || null,
            factionId: enemy.factionId,
            tier: Number(enemy.tier) || 1
          }
        });
      }
    }

    if (!Array.isArray(gameState.cardsPlayed)) gameState.cardsPlayed = [];
    gameState.cardsPlayed.push(sourceCard.id);
    this._recordChoiceHistory(sourceCard, direction, choice);
    this._advanceStoryThreadsAfterChoice(sourceCard, direction, choice, {
      mode: 'combat',
      combatOutcome: outcome
    });
    eventBus.emit('card:chosen', { card: sourceCard, direction, choice, combatOutcome: outcome });
    eventBus.emit('combat:sourceResolved', {
      outcome,
      cardId: sourceCard.id,
      direction,
      defeatHealthLoss: outcome === 'defeat' ? appliedDefeatHealthLoss : 0,
      enemy: data?.originalCard?.enemy || sourceCard.enemy || choice.enemy || null
    });
    this._log(`【战局结果】${sourceCard.title || sourceCard.id}：${outcome === 'victory' ? '胜利' : outcome === 'flee' ? '撤离' : '战败'}。`);
    this._queueMarketForProjectedDecision();
    // Source effects (including defeat injury and flee lifespan) are already
    // applied inside this transaction. A fatal result must be part of its
    // single durable decision receipt, not a second best-effort save after
    // CombatCoordinator has finished the outcome. The coordinator will still
    // present/checkpoint the death card once the source commit is accepted.
    if (gameState.lifePhase !== 'EPILOGUE'
      && !(typeof gameState.isInEnding === 'function' && gameState.isInEnding())
      && gameState.checkDeath()) {
      const deathCard = this.cardSystem?.draw?.();
      if (!deathCard?.id?.startsWith('death_')) {
        const stateRolledBack = gameState.rollbackCausalTransaction?.() === true;
        if (data && typeof data === 'object') {
          data.sourceSettlement = { accepted: false, stateRolledBack };
        }
        this._restoreUncommittedDecisionUi(uncommittedUi);
        this._triggerUpdate();
        return false;
      }
      this.currentCard = deathCard;
    }
    // The source decision is the durable combat boundary. Publish accepted
    // world/deed effects inside its transaction, before the first write.
    if (outcome === 'victory') eventBus.emit('combat:victorySettled', data);
    if (outcome === 'defeat') eventBus.emit('combat:defeatSettled', data);
    const transactionOpenBeforeCommit = Boolean(gameState._causalTransaction);
    const committed = this._commitTopLevelDecision(sourceCard.id, {
      kind: 'combat',
      stableKey: encounterId
    });
    if (!committed) {
      if (data && typeof data === 'object') {
        data.sourceSettlement = {
          accepted: false,
          stateRolledBack: transactionOpenBeforeCommit && !gameState._causalTransaction
        };
      }
      this._restoreUncommittedDecisionUi(uncommittedUi);
      this._triggerUpdate();
      return false;
    }
    if (data && typeof data === 'object') {
      data.sourceSettlement = { accepted: true, stateRolledBack: false };
      // The requested injury is not a receipt: floors, health clamping and
      // subsequent recovery can all make it differ from the applied amount.
      // Publish this value only after the source decision has committed.
      if (outcome === 'defeat') data.sourceSettlement.defeatHealthLoss = appliedDefeatHealthLoss;
    }
    return true;
  }

  // ============ 效果应用 ============

  _applyEffects(effects, sourceCard = null) {
    if (!effects) return { applied: false, effectKeys: [], changes: [] };
    if (!this.effectService) {
      console.error('[GameLogic] EffectService 未注入');
      return { applied: false, effectKeys: [], changes: [] };
    }
    return this.effectService.apply(effects, this._effectContext(sourceCard));
  }

  _auditChoiceBehavior(choice) {
    if (!this.choiceOutcomeRouter?.auditChoiceFields) {
      return { valid: true, unknownFields: [] };
    }
    return this.choiceOutcomeRouter.auditChoiceFields(choice);
  }

  /**
   * Resolve an authored probability into either an ordinary settlement or a
   * concrete encounter contract. A hit without a resolvable encounter fails
   * closed; it can never become a fake "combat happened" numeric choice.
   */
  _getChoiceCombatContract(card, direction, rawChoice) {
    const resolver = this.cardSystem?.resolveChoiceCombatContract;
    if (typeof resolver === 'function') {
      return resolver.call(this.cardSystem, card, direction, rawChoice, this.gameState?.path);
    }
    // Ordinary choices do not depend on a combat service. Any actual combat
    // metadata, however, requires the shared authority and fails closed.
    const isCombatChoice = rawChoice && typeof rawChoice === 'object' && (
      Object.prototype.hasOwnProperty.call(rawChoice, 'combatChance')
      || Object.prototype.hasOwnProperty.call(rawChoice, 'combatEncounterId')
      || rawChoice.triggerCombat || rawChoice.effects?.triggerCombat
    );
    return {
      kind: isCombatChoice ? 'direct' : 'none',
      valid: !isCombatChoice && Boolean(rawChoice),
      reason: isCombatChoice ? 'combat_authority_unavailable' : (rawChoice ? null : 'missing_choice'),
      ordinaryChoice: rawChoice ? JSON.parse(JSON.stringify(rawChoice)) : null,
      combatChoice: null
    };
  }

  _resolveProbabilisticCombatChoice(card, direction, rawChoice) {
    if (!Object.prototype.hasOwnProperty.call(rawChoice || {}, 'combatChance')) {
      return rawChoice && typeof rawChoice === 'object'
        ? { valid: true, choice: JSON.parse(JSON.stringify(rawChoice)), roll: null }
        : { valid: false, reason: 'missing_choice', message: '选择不存在。' };
    }
    const contract = this._getChoiceCombatContract(card, direction, rawChoice);
    if (contract.reason === 'invalid_combat_chance'
      || contract.reason === 'combat_authority_unavailable') return contract;
    const chance = contract.chance;
    // Keep exactly one execution roll, including chances zero and one.
    const rolled = Math.max(0, Math.min(0.999999999, Number(this.random()) || 0));
    const triggered = rolled < chance;
    const roll = { chance, value: rolled, triggered };
    if (!triggered) return { valid: true, choice: contract.ordinaryChoice, roll };
    if (!contract.combatChoice) return { ...contract, valid: false, roll };
    return {
      valid: true,
      choice: contract.combatChoice,
      roll: { ...roll, encounterId: rawChoice.combatEncounterId }
    };
  }

  /**
   * A deterministic narrative/faction choice may point at an existing combat
   * encounter without rolling combatChance. The source owns why the player is
   * here and its post-battle words; CardSystem remains the sole authority for
   * enemy, battlefield, rewards and outcome links.
   */
  _resolveAuthoredCombatEncounterChoice(card, direction, rawChoice) {
    const choice = rawChoice && typeof rawChoice === 'object'
      ? JSON.parse(JSON.stringify(rawChoice))
      : null;
    if (!choice) return { valid: false, reason: 'missing_choice', message: '选择不存在。' };
    // _resolveProbabilisticCombatChoice is the preceding authority for every
    // combatChance choice. On a hit it has already resolved the canonical
    // encounter and merged colliding source/encounter rewards additively; a
    // second resolution here would overwrite that merged victory receipt.
    if (Object.prototype.hasOwnProperty.call(choice, 'combatChance')) {
      return { valid: true, choice };
    }
    const contract = this._getChoiceCombatContract(card, direction, choice);
    return { ...contract, choice: contract.combatChoice || contract.ordinaryChoice };
  }

  /** Atomically settle every explicit top-level choice cost. */
  _settleChoiceCosts(choice) {
    const costCheck = choice?.costCheck;
    if (!costCheck || typeof costCheck !== 'object') return true;
    const preview = this.effectService?.previewChoice?.({ effects: {}, costCheck });
    if (!preview || preview.costs?.some(cost => !cost.affordable)) return false;

    const state = this.gameState || gameState;
    const pillCosts = costCheck.pills && typeof costCheck.pills === 'object'
      && !Array.isArray(costCheck.pills)
      ? costCheck.pills
      : {};
    // Recheck exact pill quantities before mutating so a partially affordable
    // multi-pill cost cannot leak a partial transaction.
    for (const [pillId, required] of Object.entries(pillCosts)) {
      const current = Number(state.resources?.pills?.[pillId]) || 0;
      if (!(Number(required) > 0) || current < Number(required)) return false;
    }
    if (costCheck.spiritStone) state.addResource('spiritStone', null, -costCheck.spiritStone);
    if (costCheck.lifespan) state.addResource('lifespan', null, -costCheck.lifespan);
    if (costCheck.health) state.addAttribute('health', -costCheck.health);
    if (costCheck.karmaGood) state.addAttribute('karmaGood', -costCheck.karmaGood);
    for (const [pillId, required] of Object.entries(pillCosts)) {
      for (let count = 0; count < Number(required); count++) state.consumeResource('pill', pillId);
    }
    return true;
  }

  _consumeBreakthroughBoost(realm) {
    const state = this.gameState || gameState;
    const key = `breakthrough_boost:${realm}`;
    const amount = Number(state.getFlag?.(key, 0)) || 0;
    if (!(amount > 0)) return 0;
    if (typeof state.clearFlag === 'function') state.clearFlag(key);
    else state.setFlag(key, 0);
    return amount;
  }

  _formatChoiceCost(costCheck) {
    if (!costCheck || typeof costCheck !== 'object') return '';
    const labels = { spiritStone: '灵石', health: '气血', karmaGood: '善因', lifespan: '寿元' };
    const numeric = Object.entries(costCheck)
      .filter(([, value]) => Number(value) > 0)
      .map(([key, value]) => `消耗${labels[key] || key} ${Number(value)}`);
    const pills = costCheck.pills && typeof costCheck.pills === 'object'
      ? Object.entries(costCheck.pills)
        .filter(([, value]) => Number(value) > 0)
        .map(([key, value]) => `消耗丹药·${key} ${Number(value)}`)
      : [];
    return [...numeric, ...pills].join(' · ');
  }

  _finalizePendingChoiceSettlement() {
    const pending = this._pendingChoiceSettlement;
    if (!pending || !this.effectService?.createSettlement) return null;
    const actual = this.effectService.createSettlement(pending.baseline);
    this._lastChoiceSettlement = {
      sourceName: pending.sourceName,
      sourceCardId: pending.sourceCardId,
      visualWorldId: pending.visualWorldId || null,
      uiMaterialId: pending.uiMaterialId || null,
      visualSurface: pending.visualSurface || null,
      costText: pending.costText,
      effectKeys: pending.effectKeys.slice(),
      feedbackMode: pending.feedbackMode || 'nearfield',
      preview: pending.preview || null,
      changes: actual.changes
    };
    this._pendingChoiceSettlement = null;
    return this._lastChoiceSettlement;
  }

  consumeLastChoiceSettlement(expectedChoiceToken = null) {
    this._finalizePendingChoiceSettlement();
    const result = this._lastChoiceSettlement;
    if (result
      && expectedChoiceToken !== null
      && expectedChoiceToken !== undefined
      && result.choiceToken !== null
      && result.choiceToken !== undefined
      && result.choiceToken !== expectedChoiceToken) {
      return null;
    }
    this.discardChoiceSettlement();
    return result;
  }

  discardChoiceSettlement() {
    this._pendingChoiceSettlement = null;
    this._lastChoiceSettlement = null;
  }

  _advanceStoryThreadsAfterChoice(card, direction, choice, outcomeContext = null) {
    const activeThreadEngine = this.storyThreadEngine ||
      (typeof storyThreadEngine !== 'undefined' && storyThreadEngine
        ? storyThreadEngine
        : (typeof threadEngine !== 'undefined' ? threadEngine : null));
    if (!activeThreadEngine) return null;

    if (typeof activeThreadEngine.onChoiceMade === 'function') {
      activeThreadEngine.onChoiceMade(card, direction, choice, gameState, outcomeContext);
    }
    if (typeof activeThreadEngine.tick === 'function') {
      activeThreadEngine.tick(gameState);
    }
    const threadCard = typeof activeThreadEngine.getNextThreadCard === 'function'
      ? activeThreadEngine.getNextThreadCard(gameState)
      : null;
    if (threadCard && typeof flowDirector !== 'undefined' && flowDirector) {
      flowDirector.enqueueNarrative(
        threadCard,
        Number.isFinite(Number(threadCard._narrativePriority))
          ? Number(threadCard._narrativePriority)
          : ((activeThreadEngine.config && activeThreadEngine.config.injectionPriority) || 52),
        'story_thread'
      );
    }
    return threadCard;
  }

  _effectContext(sourceCard = null) {
    return {
      log: this._log.bind(this),
      cardId: sourceCard ? sourceCard.id : (this.currentCard ? this.currentCard.id : null),
      onNpcRelation: this._applyNpcRelationEffect.bind(this),
      onCompanionActivated: this._activateCompanionToHUD.bind(this)
    };
  }

  _settleKarmaCard(card) {
    const seedId = card && card._karmaSeedId;
    if (!seedId || typeof karmaSystem === 'undefined' || !karmaSystem) return false;
    const seeds = Array.isArray(gameState.karmaSeeds) ? gameState.karmaSeeds : [];
    const seed = seeds.find(item => item && item.id === seedId);
    if (!seed) return false;
    karmaSystem.removeSeed(seed);
    if (!Array.isArray(this._pendingKarmaGerminations)) this._pendingKarmaGerminations = [];
    this._pendingKarmaGerminations.push({
      seedId,
      cardId: card._karmaCardId || card.id,
      settledByChoice: true
    });
    return true;
  }

  _shouldConsumeLifespan(card, choice) {
    // FIX-2: 改为 tag/type 检测，自动覆盖所有战斗卡，无需维护硬编码ID列表
    if (card && card.type === 'COMBAT') return true;
    if (card && Array.isArray(card.tags) && card.tags.includes('combat')) return true;
    if (choice && choice.effects && (choice.effects.health < 0 || choice.effects.daoHeart < 0)) return true;
    return false;
  }

  _checkCost(costCheck) {
    if (!costCheck) return true;
    const preview = this.effectService?.previewChoice?.({ effects: {}, costCheck }) || { costs: [] };
    return preview.costs.every(cost => cost.affordable);
  }

  /**
   * 检查 effects 中的资源消耗是否可支付。
   * 防止灵石/寿元/丹药被扣到负数。
   * @param {Object} effects
   * @returns {boolean}
   */
  _checkEffectCost(effects) {
    if (!effects) return true;
    const preview = this.effectService?.previewChoice?.({ effects }) || { costs: [] };
    return preview.costs.every(cost => cost.affordable);
  }

  // ============ 沉浸 v2.0 P2：世界事件 ============

  /**
   * 每隔 WORLD_EVENT_INTERVAL 回合，在日志中插入一条"天下大事"。
   * 让玩家感受到世界在独立运转——不依赖玩家的行动。
   */
  _tickWorldEvents() {
    // 上次事件后还需等待足够回合
    if (gameState.turn - this._lastWorldEventTurn < GameLogic.WORLD_EVENT_INTERVAL) return;
    // 随机小波动，避免完全是固定节奏
    if (Math.random() < 0.6) return; // 60%概率触发，平均每 ~20 回合一次事件

    const candidate = this._pickWorldEvent();
    if (!candidate) return;

    this._lastWorldEventTurn = gameState.turn;
    this._log(candidate.text, 'world-event');
  }

  /**
   * 随机选取一条符合当前境界要求的世界事件
   * @returns {{ text: string }|null}
   */
  _pickWorldEvent() {
    const realmOrder = gameState.config.realms?.order || ['qi', 'foundation', 'golden', 'nascent', 'deity', 'tribulation'];
    const realmIndex = realmOrder.indexOf(gameState.realm);
    // 只筛选境界门禁 ≤ 当前境界的事件
    const pool = GameLogic.WORLD_EVENTS.filter(ev => {
      if (!ev.realmGate) return true;
      const gateIndex = realmOrder.indexOf(
        realmOrder.find(r => gameState.getRealmName(r) === ev.realmGate)
      );
      return gateIndex >= 0 && realmIndex >= gateIndex;
    });
    if (pool.length === 0) return null;
    // 从池中随机选
    return pool[Math.floor(Math.random() * pool.length)];
  }

  // ============ 法宝/功法被动再生 ============

  /**
   * 每轮结束时应用法宝和功法技能的被动再生效果。
   * 包括 hpRegen（回血）、fortuneBonus（福缘恢复）。
   */
  _applyPassiveRegen() {
    // 聚合所有被动加成
    let hpRegen = 0;
    let fortuneBonus = 0;

    // 选择、线索与关系事件产生的长期修正由统一状态源提供。
    if (gameState.modifiers) {
      hpRegen += Math.max(0, Math.min(2, gameState.modifiers.hpRegen || 0));
    }

    // 法宝被动
    if (typeof treasureSystem !== 'undefined' && treasureSystem) {
      const treasBonuses = treasureSystem.getPassiveBonuses();
      hpRegen += treasBonuses.hpRegen || 0;
      fortuneBonus += treasBonuses.fortuneBonus || 0;
    }

    // 功法技能被动
    if (typeof pathSkillSystem !== 'undefined' && pathSkillSystem && gameState.path) {
      const skillBonuses = pathSkillSystem.getPassiveBonuses(gameState.path);
      hpRegen += skillBonuses.hpRegen || 0;
      fortuneBonus += skillBonuses.fortuneBonus || 0;
    }

    // 【P3 #15 新增】道侣被动加成 — 合并所有绑定道侣的 hpRegen/fortuneBonus
    if (typeof companionSystem !== 'undefined' && companionSystem) {
      const compBonuses = companionSystem.getAllBonuses();
      const compHp = compBonuses.hpRegen || 0;
      const compFort = compBonuses.fortuneBonus || 0;
      hpRegen += compHp;
      fortuneBonus += compFort;
      // 详细日志：仅当道侣有实际加成时打印，避免噪声
      if (compHp > 0 || compFort > 0) {
        this._log(`【道侣加成】hpRegen +${compHp}，fortuneBonus +${compFort}（数据源：companionSystem.getAllBonuses）`);
      }
    }

    // 应用回血（不超过 maxHealth）
    if (hpRegen > 0 && gameState.attributes.health < gameState.maxHealth) {
      const healAmount = Math.min(hpRegen, gameState.maxHealth - gameState.attributes.health);
      gameState.addAttribute('health', healAmount);
    }

    // 应用福缘恢复（不超过100）
    if (fortuneBonus > 0 && gameState.attributes.fortune < 100) {
      gameState.addAttribute('fortune', Math.min(fortuneBonus, 100 - gameState.attributes.fortune));
    }
  }

  /**
   * 获取聚合被动加成（供外部查询，如UI面板）
   * @returns {Object}
   */
  _getAggregatedPassives() {
    const passives = { hpRegen: 0, atk: 0, def: 0, critRate: 0, fortuneBonus: 0, daoResist: 0, pillBonus: 0 };

    if (typeof treasureSystem !== 'undefined' && treasureSystem) {
      const tb = treasureSystem.getPassiveBonuses();
      for (const k of Object.keys(tb)) {
        passives[k] = (passives[k] || 0) + tb[k];
      }
    }

    // 【修复 P0】传承套装系统被动加成合并
    if (typeof legacyFragmentSystem !== 'undefined' && legacyFragmentSystem) {
      const lfb = legacyFragmentSystem.getPassiveBonuses();
      // 这里不限制只合并预设的 passives key，因为传承还提供额外的属性
      for (const k of Object.keys(lfb)) {
        passives[k] = (passives[k] || 0) + lfb[k];
      }
    }

    if (typeof pathSkillSystem !== 'undefined' && pathSkillSystem && gameState.path) {
      const sb = pathSkillSystem.getPassiveBonuses(gameState.path);
      for (const k of Object.keys(sb)) {
        passives[k] = (passives[k] || 0) + sb[k];
      }
    }

    // 【P3 #15 新增】道侣加成 — 合并到聚合被动（供战斗系统/HUD 读取）
    if (typeof companionSystem !== 'undefined' && companionSystem) {
      const cb = companionSystem.getAllBonuses();
      if (cb) {
        for (const k of Object.keys(cb)) {
          passives[k] = (passives[k] || 0) + cb[k];
        }
      }
    }

    return passives;
  }

  // ============ 道侣危机检测 ============

  /**
   * 检测善恶值剧烈变化，触发道侣情劫/危机事件。
   * 触发条件：本回合 karmaGood 或 karmaBad 变化 ≥ 15 且存在好感度 ≥ 50 的道侣。
   */
  _checkCompanionCrisis(card, direction, choice) {
    if (typeof companionSystem === 'undefined' || !companionSystem) return;
    // Higher realms use their authored companion-event pool; this karma card is Qi-only.
    if (gameState.realm !== 'qi') return;

    // 计算本回合善恶变化
    let karmaDelta = 0;
    if (choice.effects && choice.effects.karmaGood !== undefined) karmaDelta += choice.effects.karmaGood;
    if (choice.effects && choice.effects.karmaBad !== undefined) karmaDelta -= choice.effects.karmaBad;

    if (Math.abs(karmaDelta) < 15) return;

    // 查找好感度 ≥ 50 的已激活道侣
    const companionIds = gameState.resources.companions || [];
    const candidates = [];
    for (const compId of companionIds) {
      const state = companionSystem.getState(compId);
      if (state && state.affection >= 50) {
        candidates.push({ id: compId, name: companionSystem._getName(compId), state });
      }
    }

    if (candidates.length === 0) return;

    // 随机选一位道侣触发危机
    const comp = candidates[Math.floor(Math.random() * candidates.length)];
    const qiCrisis = dataLoader.loadSync('companions:qi_crisis');
    const authored = qiCrisis?.variants?.[karmaDelta > 0 ? 'good' : 'bad'];
    if (!authored || !authored.choices) return;
    const crisisEvent = { ...authored };

    eventBus.emit('companion:heartEvent', {
      compId: comp.id,
      event: crisisEvent
    });

    this._log(`【道侣危机】${comp.name}对你的行为产生了强烈反应。`);
  }

  // ============ 境界突破 ============

  _finalizeTerminalVictory(sourceCard) {
    const terminalContext = gameState.getTerminalContext?.();
    if (!terminalContext || !this.endingEligibilityService || !this.effectService) return false;
    const preferred = gameState.endingCandidate || 'ascension';
    const preferredResult = this.endingEligibilityService.evaluate(preferred, gameState, terminalContext);
    const endingId = preferredResult.eligible ? preferred
      : this.endingEligibilityService.evaluate('ascension', gameState, terminalContext).eligible
        ? 'ascension' : null;
    if (!endingId) return false;
    if (preferred !== endingId) {
      terminalContext.candidateRejection = {
        id: preferred,
        name: preferredResult.endingName || preferred,
        missing: (preferredResult.missingRequirements || []).map(item => item.text)
      };
      this._log(`【终局意向未竟】${terminalContext.candidateRejection.name}尚缺：${terminalContext.candidateRejection.missing.join('；')}。`);
    }
    this.effectService.apply(
      { ending: endingId },
      { ...this._effectContext(sourceCard), terminalContext }
    );
    return gameState.lifePhase === 'EPILOGUE'
      && gameState.endingId === endingId
      && gameState.pendingCardId === `ending_${endingId}`;
  }

  _enterUpperRealm() {
    const continued = typeof gameState.continueAfterEnding === 'function'
      ? gameState.continueAfterEnding({ pendingCardId: 'pa_ascension_moment' })
      : false;
    if (!continued) {
      this._log('【飞升续章】终局状态不完整，无法进入上界。');
      return false;
    }
    gameState.dead = false;
    gameState.deadReason = '';
    gameState.setFlag('post_ascension_active', true);
    gameState.setFlag('ascension_continued_this_life', true);
    gameState.setFlag('post_ascension_next_card', 'pa_ascension_moment');
    gameState.realm = 'tribulation';
    gameState.currentLocation = '云中城';
    if (Array.isArray(gameState.visitedLocations) && !gameState.visitedLocations.includes('云中城')) {
      gameState.visitedLocations.push('云中城');
    }
    if (typeof gameState.persistCausalSession === 'function') gameState.persistCausalSession();
    eventBus.emit('world:layerChanged', {
      layer: 'upper_realm',
      location: gameState.currentLocation
    });
    this._log('【飞升续章】你没有轮回。云海裂开，上界成为本世的新地图。');
    return true;
  }

  _syncUpperRealmContinuation(card, choice) {
    if (!gameState.hasFlag('post_ascension_active')) return;
    const isUpperChoice = choice?.enterUpperRealm || card?.worldLayer === 'upper_realm';
    if (!isUpperChoice) return;

    const current = gameState.getFlag('post_ascension_next_card');
    const next = choice?.nextCard || null;
    let changed = false;
    if (next && current !== next) {
      gameState.setFlag('post_ascension_next_card', next);
      gameState.pendingCardId = next;
      changed = true;
    } else if (!next && current === card?.id) {
      gameState.clearFlag('post_ascension_next_card');
      gameState.pendingCardId = null;
      changed = true;
    }
    if (changed && typeof gameState.persistCausalSession === 'function') {
      gameState.persistCausalSession();
    }
  }

  _resolveBreakthrough(successRate, card, isCombatResolve = false) {
    const realmConfig = gameState.config.realms
      ? gameState.config.realms.realms[gameState.realm]
      : null;
    const projection = this._projectBreakthroughAttempt(successRate, card, { isCombatResolve });
    const requiredPill = projection.pill?.id || null;
    const shouldUseBreakthroughPill = projection.guaranteeSource === 'realm_pill';
    // Entering this method is the authoritative matching breakthrough attempt.
    // Consume the current-life boost before every early return (pill or 100%).
    const breakthroughBoost = this._consumeBreakthroughBoost(gameState.realm);

    // 普通突破在此刻服丹；门槛 Boss 则已由预警选项在战前服丹，
    // 只能以该场战斗的临时标记确认，避免胜利后重复消耗或漏算丹修被动。
    if (shouldUseBreakthroughPill) {
      if (!isCombatResolve) {
        gameState.consumeResource('pill', requiredPill);
      }
      const pillName = realmConfig ? realmConfig.pillName : '\u4e39\u836f';
      this._log(`\u670d\u7528${pillName}\uff0c\u7a81\u7834\u6210\u529f\uff01`);
      if (breakthroughBoost > 0) {
        this._log('【破境助力】本境助力已在此次服丹破境中消耗。');
      }
      this._triggerInnerVoice('breakthrough_success', 1.0);

      // 【功法被动】破境丹修为比例：明确为 ratio，不再与百分数混用。
      let pillBreakthroughCultivationRatio = 0;
      if (typeof pathSkillSystem !== 'undefined' && pathSkillSystem && gameState.path) {
        const skillBonuses = pathSkillSystem.getPassiveBonuses(gameState.path);
        pillBreakthroughCultivationRatio = skillBonuses.pillBreakthroughCultivationRatio || 0;
      }
      let breakthroughCultivationBonus = 0;
      if (pillBreakthroughCultivationRatio > 0) {
        // ratio × 下个境界阈值；奖励在 _advanceRealm 的基础修为重设后写入。
        const nextRealm = gameState.config.realms
          ? gameState.config.realms.order[gameState.config.realms.order.indexOf(gameState.realm) + 1]
          : null;
        const nextThreshold = nextRealm && gameState.config.realms.realms[nextRealm]
          ? gameState.config.realms.realms[nextRealm].cultivationThreshold : 100;
        const ratio = Math.max(0, Math.min(1, Number(pillBreakthroughCultivationRatio) || 0));
        breakthroughCultivationBonus = Math.floor(nextThreshold * ratio);
      }

      this._advanceRealm({
        breakthroughCultivationBonus,
        sourceCard: card,
        inheritancePending: isCombatResolve
      });
      return;
    }

    const roll = this.random();
    // 【P1 #7 修复】天机值影响雷劫：天机越高，雷劫越猛，突破成功率越低
    const adjustedSuccessRate = projection.finalRate;
    if (breakthroughBoost > 0) {
      this._log(`【破境助力】本次成功率 +${Math.round(breakthroughBoost * 100)}%，助力已消耗。`);
    }
    if (projection.tianjiPenalty > 0.05) {
      this._log(`【天机警告】天机值 ${projection.tianji}，雷劫威力增强，突破成功率 -${Math.round(projection.tianjiPenalty * 100)}%`);
    }
    if (roll < adjustedSuccessRate) {
      this._log('\u7a81\u7834\u6210\u529f\uff01\u5883\u754c\u63d0\u5347\uff01');
      this._triggerInnerVoice('breakthrough_success', 1.0);
      this._advanceRealm({ sourceCard: card, inheritancePending: isCombatResolve });
    } else {
      this._log('\u7a81\u7834\u5931\u8d25\uff0c\u9053\u5fc3\u53d7\u632b\u3002');
      this._triggerInnerVoice('breakthrough_fail', 1.0);
      gameState.addAttribute('daoHeart', -1);
      gameState.addAttribute('cultivation', -30);

      // ── v2.0 心魔反噬 (GDD §3) ──
      gameState.pendingConsequence = {
        version: 1,
        type: 'inner_demon',
        lifeId: gameState.runClock.lifeId,
        realm: gameState.realm,
        sourceCardId: card.id
      };
    }
  }

  // ============ v2.0 心魔反噬 ============

  // Compatibility for diagnostics; GameStateManager is the only authority.
  get _innerDemonActive() {
    return this.gameState?.getPendingConsequence?.()?.type === 'inner_demon';
  }

  _buildInnerDemonCard() {
    // 检查师尊护体 (GDD §3.4)
    const mentorProtection = (typeof npcSystem !== 'undefined' && npcSystem &&
      npcSystem.affections && npcSystem.affections.mentor_sword_elder >= 50);
    const demonPill = gameState.hasResource('pill', '心魔丹');

    const card = {
      id: 'inner_demon',
      type: 'INNER_DEMON',
      title: '心魔反噬',
      description: '突破失败，心魔趁虚而入——黑暗的念头在你识海中翻涌。你感到另一个自己在低语：\n\n"何必苦苦坚持正道？接受我，你将更强。"',
      realm: gameState.realm,
      tags: ['inner_demon', 'breakthrough_failure'],
      choices: {}
    };

    if (mentorProtection) {
      card.description += '\n\n✨ 师尊的传承之力护住了你的心脉——你感到一股暖流驱散了些许寒意。';
      card.choices = {
        left: { text: '接受心魔', effects: { cultivation: 8, daoHeart: -5, karmaBad: 5 } },
        right: { text: '师尊训诫', effects: { daoHeart: 2, cultivation: 2 } },
        up: { text: '暂时封印', effects: {} }
      };
      card._mentorProtected = true;
    } else {
      card.choices = {
        left: { text: '接受心魔', effects: { cultivation: 5, daoHeart: -5, karmaBad: 10 }, innerDemonAction: 'accept' },
        right: { text: '抵抗心魔', effects: { daoHeart: -3, cultivation: 2 }, innerDemonAction: 'resist' },
        up: { text: '暂时封印', effects: {}, innerDemonAction: 'seal' }
      };
    }

    if (demonPill) {
      card.choices.down = { text: '服用心魔丹', effects: { daoHeart: 5, cultivation: 3 }, innerDemonAction: 'pill' };
      card._demonPill = true;
    }

    return card;
  }

  _resolveInnerDemon(direction) {
    const card = this._buildInnerDemonCard();
    const choice = card.choices[direction];
    if (!choice) return false;

    this._applyEffects(choice.effects);

    const innerAction = choice.innerDemonAction;
    if (innerAction === 'accept') {
      this._log('你接受了心魔——它融入了你的修为，但从此它与你共存。恶业+10。');
      // 下次突破概率+10%（设置flag）
      gameState.setFlag('innerDemonBoost', true);
    } else if (innerAction === 'resist') {
      this._log('你以道心强行压制了心魔。道心-3, 修为+2。');
      const resisted = (gameState.getFlag('innerDemonResisted', 0)) + 1;
      gameState.setFlag('innerDemonResisted', resisted);
      if (resisted >= 3) {
        this._log('🏆 成就解锁: 心如铁石！连续三次抵抗心魔，道心+5！');
        gameState.addAttribute('daoHeart', 5);
      }
    } else if (innerAction === 'seal') {
      const sealed = (gameState.getFlag('innerDemonSealed', 0)) + 1;
      gameState.setFlag('innerDemonSealed', sealed);
      this._log(`你将心魔暂时封印。封印层数: ${sealed}/5`);
      if (sealed >= 5) {
        this._log('⚠️ 五重心魔封印集体爆发——魔劫降临！');
        gameState.addAttribute('daoHeart', -20);
        gameState.addAttribute('karmaBad', 20);
        gameState.setFlag('innerDemonSealed', 0);
      }
    } else if (innerAction === 'pill') {
      gameState.consumeResource('pill', '心魔丹');
      this._log('心魔丹入喉——心魔被强行震散，道心反而更加凝实。');
    } else if (card._mentorProtected && direction === 'right') {
      // 师尊训诫: 扣传承值
      if (typeof npcSystem !== 'undefined' && npcSystem) {
        npcSystem.affections.mentor_sword_elder = Math.max(0, (npcSystem.affections.mentor_sword_elder || 0) - 10);
        this._log('师尊训诫了你一番——传承值 -10，但道心更加稳固。');
      }
    }

    gameState.pendingConsequence = null;
    gameState.cardsPlayed.push('inner_demon');
    return true;
  }

  _buildEpiphanyCard() {
    const playerDeck = gameState.deck || [];
    const battleCards = DATA_MODULES['cards:battle_cards'] ? DATA_MODULES['cards:battle_cards'].battle_cards : [];

    let swordCount = 0;
    let spellCount = 0;
    playerDeck.forEach(cardId => {
      const bCard = battleCards.find(c => c.id === cardId);
      if (bCard && bCard.tags) {
        if (bCard.tags.includes('sword') || bCard.tags.includes('sword_intent')) swordCount++;
        if (bCard.tags.includes('spell') || bCard.tags.includes('spell_seal')) spellCount++;
      }
    });

    let choices = {};
    let awakeningLabel = '奇绝术法根基';
    if (gameState.path === 'body') {
      awakeningLabel = '不坏筋骨与沉稳气血';
      choices = {
        left: {
          text: '领悟【金刚架】',
          desc: '以筋骨承势，获得护盾与金刚劲。',
          effects: { deckCard: 'body_guard' },
          nextCard: 'q_foundation'
        },
        right: {
          text: '领悟【重剑无锋】',
          desc: '把肉身力量灌入重击，以势破巧。',
          effects: { deckCard: 'heavy_strike' },
          nextCard: 'q_foundation'
        },
        down: {
          text: '领悟【太乙玄黄罩】',
          desc: '将护体真元炼成可以保留的罡气。',
          effects: { deckCard: 'qi_shield' },
          nextCard: 'q_foundation'
        }
      };
    } else if (gameState.path === 'pill') {
      awakeningLabel = '药理循环与炉火灵机';
      choices = {
        left: {
          text: '炼成【回春丹】',
          desc: '在战斗中恢复局内护体值；不能抹去战败伤势。',
          effects: { deckCard: 'pill_mending' },
          nextCard: 'q_foundation'
        },
        right: {
          text: '炼成【回气丹】',
          desc: '临阵恢复真元，延长一轮操作链。',
          effects: { deckCard: 'mana_potion' },
          nextCard: 'q_foundation'
        },
        down: {
          text: '参悟【太乙玄黄罩】',
          desc: '以丹气护体，建立长线防守。',
          effects: { deckCard: 'qi_shield' },
          nextCard: 'q_foundation'
        }
      };
    } else if (gameState.path === 'sword' || (gameState.path !== 'spell' && swordCount >= spellCount)) {
      awakeningLabel = '纯粹剑骨气劲';
      choices = {
        left: {
          text: '领悟【太虚剑阵】',
          desc: '以真气聚万剑，防御并获取剑意。',
          effects: { deckCard: 'sword_array' },
          nextCard: 'q_foundation'
        },
        right: {
          text: '领悟【养剑诀】',
          desc: '极聚锋芒，以宝剑养神。',
          effects: { deckCard: 'sword_intent' },
          nextCard: 'q_foundation'
        },
        down: {
          text: '领悟【拔剑式】',
          desc: '寒光一闪，极速攻击。',
          effects: { deckCard: 'draw_sword' },
          nextCard: 'q_foundation'
        }
      };
    } else {
      choices = {
        left: {
          text: '领悟【五气朝元】',
          desc: '凝聚五行法印，防御并累积层数。',
          effects: { deckCard: 'spell_gather' },
          nextCard: 'q_foundation'
        },
        right: {
          text: '领悟【九天玄雷诀】',
          desc: '以气血引天雷，雷云洗地！',
          effects: { deckCard: 'spell_nuke' },
          nextCard: 'q_foundation'
        },
        down: {
          text: '领悟【灵力潮汐】',
          desc: '根据法印层数，灵潮爆发大量抽牌。',
          effects: { deckCard: 'spell_tide' },
          nextCard: 'q_foundation'
        }
      };
    }

    return {
      id: 'epiphany_foundation',
      title: '天道灌顶 · 本命觉醒',
      description: `劫散云开，天降七彩祥光，浩瀚的天道灵气洗练周身！你在渡劫中展现出的【${awakeningLabel}】引动了天道的本源共鸣。请挑选你的筑基期本命神通！`,
      type: 'NORMAL',
      protagonistIdentity: {
        consumer: 'realm_arrival',
        stageSource: 'current_realm',
        pathSource: 'current_life_path'
      },
      choices: choices,
      sceneImage: 'assets/cards/events/scene_qi_break_qi.png'
    };
  }

  _buildRealmArrivalCard(oldRealm, newRealm, unlockedSkills = [], sourceCard = null) {
    const realmArrivalScenes = {
      foundation: 'assets/cards/events/scene_fd_break_foundation.png',
      golden: 'assets/cards/events/scene_gd_break_golden.png',
      nascent: 'assets/cards/events/scene_ns_break_nascent.png',
      deity: 'assets/cards/events/scene_dt_break_deity.png',
      tribulation: 'assets/cards/events/scene_tb_break_tribulation.png'
    };
    const realmProfiles = {
      golden: {
        title: '金丹既成 · 本命丹纹',
        description: '灵液凝作金丹，丹纹随你的功法流转。自此真元可以离体久存，新的敌人与机缘也将进入牌池。'
      },
      nascent: {
        title: '元婴出窍 · 神识初成',
        description: '金丹碎而不灭，一点灵光化作元婴。神识越过肉身边界，你终于能看见天地灵机的脉络。'
      },
      deity: {
        title: '化神归一 · 法相显化',
        description: '元婴与神魂合一，法相第一次立于天地之间。你的功法不再只是招式，而开始影响一方规则。'
      },
      tribulation: {
        title: '渡劫之境 · 天门在望',
        description: '九重雷意烙入道躯，天门已能感知你的存在。此后每次战斗都可能成为飞升前的最后一课。'
      }
    };
    const profile = realmProfiles[newRealm] || {
      title: `${gameState.getRealmName(newRealm)} · 境界稳固`,
      description: '新境已成，旧日修行化作更广阔的道路。'
    };
    const pathNames = { sword: '剑修', spell: '法修', body: '体修', pill: '丹修' };
    const skillText = unlockedSkills.length
      ? `\n\n新解锁：${unlockedSkills.map(skill => `【${skill.name}】`).join('、')}。`
      : '';
    const sourcePresentation = sourceCard?.combatPresentation || {};
    const visualWorldId = sourcePresentation.visualWorldId || sourceCard?.visualWorldId || null;
    const uiMaterialId = sourcePresentation.uiMaterialId || sourceCard?.uiMaterialId || null;
    const hasWorldContract = typeof visualWorldId === 'string' && visualWorldId
      && typeof uiMaterialId === 'string' && uiMaterialId;
    return {
      id: `realm_arrival_${newRealm}`,
      title: profile.title,
      description: `${profile.description}\n\n当前道路：${pathNames[gameState.path] || '未定'}。气血与道心上限各提升 1，新境界卡池、Boss 与流派证明战已经开放。${skillText}`,
      type: 'REALM_UPGRADE',
      realm: newRealm,
      tags: ['realm_upgrade', newRealm, gameState.path].filter(Boolean),
      protagonistIdentity: {
        consumer: 'realm_arrival',
        stageSource: 'current_realm',
        pathSource: 'current_life_path'
      },
      sceneImage: sourcePresentation.sceneImage || sourceCard?.sceneImage
        || realmArrivalScenes[newRealm] || 'assets/cards/events/scene_pool_breakthrough.png',
      combatPresentationId: sourcePresentation.presentationId || null,
      visualWorldId: hasWorldContract ? visualWorldId : null,
      uiMaterialId: hasWorldContract ? uiMaterialId : null,
      visualSurface: hasWorldContract ? 'realm_arrival_ledger' : null,
      choices: {
        left: {
          text: '稳固道基',
          desc: '以新境真元温养经脉，修为 +5。',
          effects: { cultivation: 5, _setFlag: `realm_upgrade_${newRealm}_foundation` }
        },
        right: {
          text: '澄明道心',
          desc: '回望破境所得，道心 +2。',
          effects: { daoHeart: 2, _setFlag: `realm_upgrade_${newRealm}_daoheart` }
        },
        down: {
          text: '推演本命法',
          desc: '把新境感悟沉入自身流派，气运 +2。',
          effects: { fortune: 2, _setFlag: `realm_upgrade_${newRealm}_path` }
        }
      }
    };
  }

  _advanceRealm({ breakthroughCultivationBonus = 0, sourceCard = null, inheritancePending = false } = {}) {
    const realmOrder = gameState.config.realms
      ? gameState.config.realms.order
      : ['qi', 'foundation', 'golden', 'nascent', 'deity', 'tribulation'];

    const idx = realmOrder.indexOf(gameState.realm);
    const oldRealm = gameState.realm;
    if (idx < realmOrder.length - 1) {
      gameState.realm = realmOrder[idx + 1];
      gameState.setAttribute('cultivation', 10);
      eventBus.emit('state:realmChanged', { from: oldRealm, to: gameState.realm });

      // 境界突破增益：提升最大生命值 +1，最大道心值 +1，并强行恢复满状态
      const newMaxHp = gameState.maxHealth + 1;
      const newMaxDaoHeart = gameState.maxDaoHeart + 1;
      gameState.maxHealth = newMaxHp;
      gameState.maxDaoHeart = newMaxDaoHeart;
      gameState.setAttribute('health', newMaxHp);
      gameState.setAttribute('daoHeart', newMaxDaoHeart);
      this._log(`突破成功！脱胎换骨，气血上限提升至 ${newMaxHp}，道心上限提升至 ${newMaxDaoHeart}！`);

      // 【P1 #8 修复】突破后增加寿元（读取 realms.json 的 lifespanBonus）
      const newRealmConfig = gameState.config.realms
        && gameState.config.realms.realms
        ? gameState.config.realms.realms[gameState.realm]
        : null;
      if (newRealmConfig && newRealmConfig.lifespanBonus && newRealmConfig.lifespanBonus > 0) {
        gameState.addResource('lifespan', null, newRealmConfig.lifespanBonus);
        this._log(`境界突破，寿元 +${newRealmConfig.lifespanBonus} 年。`);
      }

      // 基础入境修为已在上方重设为 10。丹道真意的 ratio 奖励必须随后写入，
      // 并封顶到本境阈值，避免超过阈值后产生隐式跨境结算。
      const nextThreshold = Number(newRealmConfig?.cultivationThreshold) || 100;
      const baseCultivation = gameState.getAttribute
        ? gameState.getAttribute('cultivation')
        : (gameState.attributes?.cultivation || 0);
      const requestedBonus = Math.max(0, Math.floor(Number(breakthroughCultivationBonus) || 0));
      const appliedBonus = Math.min(requestedBonus, Math.max(0, nextThreshold - baseCultivation));
      if (appliedBonus > 0) {
        gameState.addAttribute('cultivation', appliedBonus);
        this._log(`丹道真意，入境后额外获得 ${appliedBonus} 修为！`);
      }

      // 位置切换：境界突破 → 返回宗门（最安全的默认位置）
      if (typeof sceneLayerSystem !== 'undefined' && sceneLayerSystem) {
        sceneLayerSystem.transition('宗门', 'realm_breakthrough');
      }

      // 加载下一境界卡牌
      cardSystem._loadRealmCards(gameState.realm);

      // 解锁功法技能
      let newSkills = [];
      if (gameState.path) {
        newSkills = pathSkillSystem.unlockForRealm(gameState.path, gameState.realm);
        for (const skill of newSkills) {
          this._log(`功法技能解锁：【${skill.name}】—— ${skill.desc}`);
        }
      }

      gameState.unlock('realm', gameState.realm);

      // ── 境界章节：完成上一章，进入下一章 ──
      if (typeof chapterSystem !== 'undefined' && chapterSystem && chapterSystem._initialized) {
        const oldChapter = chapterSystem.getChapterTitle(oldRealm);
        const newChapter = chapterSystem.getChapterTitle(gameState.realm);
        const oldProgress = chapterSystem.getProgress(oldRealm);
        this._log(
          '【' + oldChapter + '】完成！里程碑 ' + oldProgress.triggered + '/' + oldProgress.total +
          '\n  → ' + newChapter
        );
        // 重置新章里程碑（防转世残留）
        chapterSystem.reset(gameState.realm);
      }

      this._log(`进入${gameState.getRealmName(gameState.realm)}！`);

      const arrivalCard = gameState.realm === 'foundation'
        ? this._buildEpiphanyCard()
        : this._buildRealmArrivalCard(oldRealm, gameState.realm, newSkills, sourceCard);
      const lifeCount = typeof gameState.getLifeCount === 'function'
        ? gameState.getLifeCount()
        : (gameState.unlocks?.lifeCount || 0);
      const sourceCardId = typeof sourceCard?.id === 'string' && sourceCard.id
        ? sourceCard.id
        : `break_${oldRealm}`;
      gameState.realmTransition = {
        version: 1,
        id: `realm:${lifeCount}:${sourceCardId}:${oldRealm}->${gameState.realm}`,
        sourceCardId,
        lifeCount: Number(lifeCount),
        from: oldRealm,
        to: gameState.realm,
        pathAtPromotion: gameState.path,
        status: inheritancePending ? 'inheritance_pending' : 'arrival_pending',
        arrivalCardId: arrivalCard.id
      };
      this._pendingRealmTransitionCard = arrivalCard;
      // CombatCoordinator installs breakthrough_reward after this call; persist the
      // transaction now so either side of that handoff can survive a refresh.
      gameState.persistCausalSession?.();
    } else {
      // 渡劫封顶不等于合法终局；只能由最终 Boss 胜利凭证推进。
      this._log('【终局门禁】修为已至渡劫圆满，须击败最终天门 Boss 才能裁定结局。');
    }
  }

  // ============ 转世 ============

  reincarnateFromDeathScreen() {
    const state = this.gameState || gameState;
    if (!state?.dead || this.currentCard?.id?.startsWith('death_')
      || this.currentCard?.id?.startsWith('ending_')
      || state.beginLifeTransition?.() !== true) return false;
    const beforeUi = this._captureUncommittedDecisionUi();
    this._pendingReincarnationPathSelection = null;
    try {
      this._reincarnate();
      if (state.commitLifeTransition?.() !== true) {
        this._pendingReincarnationPathSelection = null;
        this._restoreUncommittedDecisionUi(beforeUi);
        this._triggerUpdate();
        return false;
      }
      if (this._pendingReincarnationPathSelection) {
        this.eventBus.emit('reincarnation:pathSelectionRequired', this._pendingReincarnationPathSelection);
        this._pendingReincarnationPathSelection = null;
      }
      this._triggerUpdate();
      return true;
    } catch (error) {
      this._pendingReincarnationPathSelection = null;
      state.rollbackLifeTransition?.();
      this._restoreUncommittedDecisionUi(beforeUi);
      this._triggerUpdate();
      throw error;
    }
  }

  _reincarnate({ fromEnding = false, archiveMeta = null } = {}) {
    this.discardChoiceSettlement();
    // A fatal choice may have created its immediate narrative response before
    // death took control of the card stream. The visible death/ending card is
    // the authoritative terminal response; settle against it before the
    // one-life ledger and Flow queues reset, then never carry that card onward.
    if (this._pendingPromiseResultCard) {
      this.choiceOutcomeRouter?.resolvePromiseAtTerminal?.(
        this._pendingPromiseResultCard,
        this.currentCard,
        fromEnding ? 'ending_closed_life' : 'source_choice_caused_death'
      );
      this._pendingPromiseResultCard = null;
    }
    const lastTurn = gameState.turn;
    const lastRealm = gameState.realm;
    const lastPath = gameState.path;

    // 【诊断日志】_reincarnate 入口
    this._log(`[转世] 入口 turn=${lastTurn} realm=${lastRealm} path=${lastPath} dead=${gameState.dead} deadReason=${gameState.deadReason}`);
    if (gameState.transitionLifePhase && typeof GameStateManager !== 'undefined') {
      gameState.transitionLifePhase(GameStateManager.LIFE_PHASES.REINCARNATING, { reason: gameState.deadReason });
    }

    // 【环环相扣：转世连锁】记录跨世遗产
    if (typeof lineageSystem !== 'undefined' && lineageSystem) {
      const currentCardIsEnding = Boolean(this.currentCard?.id?.startsWith('ending_'));
      const endingId = archiveMeta?.endingId
        || (fromEnding || currentCardIsEnding ? gameState.endingId : null);
      const ending = archiveMeta?.ending
        || (currentCardIsEnding ? this.currentCard.title : null);
      lineageSystem.recordCurrentLife({
        cause: archiveMeta?.cause || gameState.deadReason || ending || '主动轮回',
        deathCauseId: archiveMeta?.deathCauseId || gameState.deathCauseId || null,
        endingId,
        ending
      });
    }
    gameState.recordLegacy();
    this._log(`[转世] recordLegacy 已记录跨世遗产`);

    // 转世次数+1
    gameState.incrementLife();
    const lifeCount = gameState.getLifeCount();
    this._log(`—————— 第 ${lifeCount} 世 · 轮回 ——————`);

    // 基础跨世加成（境界越高、寿命越长，转世加成越多）
    if (lastRealm !== 'qi') {
      gameState.unlocks.bonuses.startCultivation += 3 + (lifeCount > 1 ? 2 : 0);
    }
    if (lastTurn > 30) {
      gameState.unlocks.bonuses.startSpiritStone += 5 + Math.min(lifeCount, 5) * 2;
    }
    if (lastRealm === 'foundation' || lastRealm === 'golden') {
      gameState.unlocks.bonuses.maxLifespan += 5 + lifeCount;
    }
    if (lastRealm === 'nascent' || lastRealm === 'deity') {
      gameState.unlocks.bonuses.maxLifespan += 10 + lifeCount * 2;
    }

    // 应用死亡卡选择的转世加成
    const bonus = gameState._pendingReincBonus;
    if (bonus) {
      const parts = bonus.split(',');
      for (const part of parts) {
        const trimmed = part.trim();
        const match = trimmed.match(/^([a-zA-Z]+)\s*([+-]\d+)$/);
        if (!match) continue;
        const [, stat, valueStr] = match;
        const value = parseInt(valueStr, 10);
        switch (stat) {
          case 'cultivation': gameState.unlocks.bonuses.startCultivation += value; break;
          case 'spiritStone': gameState.unlocks.bonuses.startSpiritStone += value; break;
          case 'maxLifespan': gameState.unlocks.bonuses.maxLifespan += value; break;
          case 'daoHeart': gameState.unlocks.bonuses.daoHeart = (gameState.unlocks.bonuses.daoHeart || 0) + value; break;
          case 'fortune': gameState.unlocks.bonuses.fortune = (gameState.unlocks.bonuses.fortune || 0) + value; break;
          case 'maxHp': gameState.unlocks.bonuses.maxHp = (gameState.unlocks.bonuses.maxHp || 0) + value; break;
          case 'karmaGood': gameState.unlocks.bonuses.karmaGood = (gameState.unlocks.bonuses.karmaGood || 0) + value; break;
          case 'karmaBad': gameState.unlocks.bonuses.karmaBad = (gameState.unlocks.bonuses.karmaBad || 0) + value; break;
        }
      }
      this._log(`前世抉择余响：${bonus}`);
      gameState._pendingReincBonus = null;
    }

    if (gameState.clearFlag) {
      gameState.clearFlag('post_ascension_active');
      gameState.clearFlag('ascension_continued_this_life');
      gameState.clearFlag('post_ascension_next_card');
      const currentLifeFlagKeys = new Set([
        ...Object.keys(gameState.flags || {}),
        ...Object.keys(gameState.unlocks?.flags || {})
      ]);
      for (const key of currentLifeFlagKeys) {
        if (key.startsWith('breakthrough_boost:')) gameState.clearFlag(key);
      }
    }
    gameState._saveUnlocks();
    gameState.reset(true);

    // Flow state is scoped to one life. Reset through the authoritative Flow
    // owner so its queues, cadence cursor and injected EncounterDirector all
    // cross the reincarnation boundary together. The direct fallback keeps
    // isolated runtimes fail-safe when no FlowDirector is installed.
    if (this.flowDirector && typeof this.flowDirector.reset === 'function') {
      this.flowDirector.reset();
    } else if (this.encounterDirector && typeof this.encounterDirector.reset === 'function') {
      this.encounterDirector.reset();
    }

    // Current-life thread snapshots survive browser refreshes, but a new life
    // is a hard causal boundary. Reinitialize against the incremented life and
    // reload definitions so no previous-life node can be replayed.
    const activeThreadEngine = this.storyThreadEngine ||
      (typeof storyThreadEngine !== 'undefined' && storyThreadEngine
        ? storyThreadEngine
        : (typeof threadEngine !== 'undefined' ? threadEngine : null));
    if (activeThreadEngine) {
      this._loadStoryThreadDefinitions(activeThreadEngine);
    }

    this._log(`转世重修——前世的道路如雾中残梦。`);
    this._log(`你感觉到体内有 ${gameState.getLegacyAffection ? '一股熟悉的气息' : '新的力量'}在涌动。`);
    this._log(`难度：${this._getDifficultyText()}`);

    // 新一世先重建 NPC 权威状态，再生成可刷新的因果快照；否则快照会带回
    // 前世未衰减的运行时好感，绕过 recordLegacy 的继承公式。
    let npcRestored = 0;
    if (typeof npcSystem !== 'undefined' && npcSystem && typeof npcSystem.resetForNewLife === 'function') {
      npcRestored = npcSystem.resetForNewLife();
    }

    // 【天道恩赐】：抽第一张牌为轮回之选
    this.currentCard = cardSystem.getCard('rebirth_boon');
    if (typeof gameState.prepareReincarnationHandoff === 'function') {
      gameState.prepareReincarnationHandoff(
        'rebirth_boon',
        fromEnding ? 'ending_reincarnation' : 'death_reincarnation'
      );
    } else if (fromEnding && typeof gameState.prepareEndingReincarnationHandoff === 'function') {
      gameState.prepareEndingReincarnationHandoff('rebirth_boon');
    }
    this._log(`[转世] 新一世首张卡 id=${this.currentCard ? this.currentCard.id : 'null'}（应为 rebirth_boon）`);
    const pathSelectionNotice = {
      lifeCount,
      completedLegacySetIds: gameState.getLegacyArchive?.().completedSetIds?.slice() || []
    };
    if (gameState._lifeTransition) this._pendingReincarnationPathSelection = pathSelectionNotice;
    else this.eventBus.emit('reincarnation:pathSelectionRequired', pathSelectionNotice);

    // 【环环相扣：转世→NPC】前世老友残留印象
    if (npcRestored > 0) this._log(`[转世] NPC 跨世好感继承 count=${npcRestored}`);

    // 【环环相扣：转世→Faction】前世势力的暗流依旧
    if (typeof factionSystem !== 'undefined' && factionSystem && gameState.unlocks.legacy) {
      const legacyReps = gameState.unlocks.legacy.factionReputations || {};
      let factionRestored = 0;
      for (const [factionId, rep] of Object.entries(legacyReps)) {
        if (rep !== 0) {
          const currentRep = factionSystem.reputations?.[factionId] || 0;
          factionSystem.reputations[factionId] = currentRep + Math.round(rep * 0.3);
          factionRestored++;
        }
      }
      if (factionRestored > 0) this._log(`[转世] 势力跨世声望继承 count=${factionRestored}`);
    }

    // 【诊断日志】_reincarnate 出口
    this._log(`[转世] 出口 lifeCount=${gameState.getLifeCount()} realm=${gameState.realm} hp=${gameState.attributes.health} turn=${gameState.turn} dead=${gameState.dead}`);

    // The new-life handoff must become durable before the UI presents it.
    if (!gameState._lifeTransition) this._triggerUpdate();
  }

  // ============ 战斗协调器代理 ============

  /**
   * 战斗中选择动作（由 UI 调用）
   * 注：新版 DeckCombatUI 已直接绑定点击事件，此方法保留兼容层
   */
  combatAction(action) {
    if (this.combatCoordinator) {
      this.combatCoordinator.handleAction(action);
    }
  }

  // ============ 难度曲线系统 ============

  /**
   * 根据转世次数获得当前难度等级 (0-10)
   */
  getDifficultyLevel() {
    const lifeCount = gameState.getLifeCount();
    return Math.min(lifeCount, 10);
  }

  /**
   * 获取难度乘数（敌方属性缩放）
   */
  _getDifficultyMultiplier() {
    const level = this.getDifficultyLevel();
    return 1 + level * 0.15; // 每世 +15% 难度
  }

  /**
   * 获取难度文本描述
   */
  _getDifficultyText() {
    const level = this.getDifficultyLevel();
    if (level === 0) return '初世·凡尘';
    if (level <= 2) return '轮回·磨砺';
    if (level <= 4) return '三世·因果';
    if (level <= 7) return '五世·逆命';
    return '九世·天道';
  }

  // ============ 事件处理 ============

  _onDeath(data) {
    if (this.cardSystem?.getActiveDungeonRun?.()) {
      this.cardSystem.completeDungeon('failure', 'player_death', { deathCauseId: data?.causeId || null });
    }
    this._log(`道消身陨：${data.reason}`);
  }

  abandonDungeon() {
    const settlement = this.cardSystem?.abandonDungeon?.('user_exit');
    if (!settlement) return false;
    this.currentCard = null;
    this._triggerUpdate();
    return true;
  }

  _onQuestTriggered(data) {
    this._log(`支线触发：【${data.questName}】`);
  }

  _onQuestCompleted(data) {
    this._log(`支线完成：【${data.questName}】`);
  }

  _onKarmaSeedPlanted(data) {
    this._log('一道因果伏线已经种下，将随之后的决断显现。');
  }

  // ============ 工具方法 ============

  /**
   * 种选择回响种子（在弧线卡/道侣卡/师尊卡/盟友卡做选择后调用）
   * @private
   */
  _plantChoiceEcho(card, direction, choice) {
    if (!card || !choice) return;
    if (typeof choiceEchoEngine === 'undefined' || !choiceEchoEngine) return;

    const echoTypes = ['COMPANION_ARC', 'COMPANION_EVENT', 'MENTOR_ARC', 'ALLY_ARC', 'SEER_ARC'];
    if (echoTypes.includes(card.type)) {
      choiceEchoEngine.plantEcho({
        turn: gameState.turn,
        realm: gameState.realm,
        cardId: card.id,
        choice: direction,
        choiceLabel: choice.text || '',
        npcId: card.npcId || null,
        affection: card.npcId && typeof npcSystem !== 'undefined'
          ? (npcSystem.affections[card.npcId] || 0)
          : 0,
        location: gameState.currentLocation || '未知',
        cardType: card.type
      });
    }
  }

  /**
   * 应用NPC间关系效果
   * 处理 effects 中的 'npc_relation:fromId:toId': delta 格式
   * @private
   */
  _applyNpcRelationEffect(key, value) {
    const parts = key.split(':');
    if (parts.length < 3) return;
    const fromNpc = parts[1];
    const toNpc = parts[2];

    if (typeof npcSystem !== 'undefined' && npcSystem && npcSystem.adjustNpcRelation) {
      npcSystem.adjustNpcRelation(fromNpc, toNpc, value);
      this._log(`${npcSystem.getNpcName(fromNpc)} 与 ${npcSystem.getNpcName(toNpc)} 的关系 ${value > 0 ? '改善' : '恶化'}了。`);
    }
  }

  _log(message, cssClass) {
    if (this.onLog) this.onLog(message, cssClass);
  }

  // ============ 道侣沉浸 v2.5 ============

  /**
   * 获取当前激活的道侣（好感最高且 registered）
   * @returns {{ id: string, affection: number, bond: number, trust: number, stage: string, name: string }|null}
   */
  _getActiveCompanion() {
    if (typeof companionSystem === 'undefined' || !companionSystem) return null;
    const comps = gameState.resources.companions || [];
    if (comps.length === 0) return null;

    let best = null;
    let bestAff = -1;
    for (const compId of comps) {
      const state = companionSystem.getState(compId);
      if (!state) continue;
      if (state.affection > bestAff) {
        bestAff = state.affection;
        best = { id: compId, ...state };
      }
    }
    return best;
  }

  /**
   * 触发道侣耳语 — 每次滑动选择后调用
   * @param {Object} card
   * @param {string} direction
   */
  _triggerCompanionWhisper(card, direction) {
    if (typeof companionWhisper === 'undefined' || !companionWhisper) return;
    if (!this.ui || !this.ui.companionHUD) return;

    const activeComp = this._getActiveCompanion();
    if (!activeComp) return;

    const affection = activeComp.affection || 0;
    const reaction = companionWhisper.getReaction(activeComp.id, card, direction, affection);
    if (reaction) {
      this.ui.showCompanionBubble(reaction, 3500);
    }

    // 好感数字、情绪与立绘阶段必须在同一入口更新。
    this.ui.companionHUD.updateAffection(affection);
  }

  /**
   * 激活道侣到 HUD（获得道侣或游戏开始时调用）
   */
  _activateCompanionToHUD() {
    if (!this.ui || !this.ui.companionHUD) return;
    const activeComp = this._getActiveCompanion();
    if (activeComp) {
      this.ui.setActiveCompanion(activeComp.id, activeComp);
    }
  }

  _triggerUpdate() {
    // ── 叙事连贯性层：在渲染新卡之前显示过渡文字 ──
    if (typeof coherenceLayer !== 'undefined' && coherenceLayer) {
      const transition = coherenceLayer.consumePendingTransition();
      if (transition && this.onShowTransition) {
        this.onShowTransition(transition);
      }
    }
    if (this.onUpdate) this.onUpdate();
  }

  getAvailableDirections(card) {
    if (!card || !card.choices) return [];

    // 【特权机制】卡组流派标签过滤 (reqDeckTag)
    return Object.keys(card.choices).filter(direction => {
      const choice = card.choices[direction];
      if (choice.reqDeckTag) {
        // 检查玩家持久化卡组中是否包含带有该标签的卡牌
        const playerDeck = gameState.deck || [];
        const battleCards = DATA_MODULES['cards:battle_cards'] ? DATA_MODULES['cards:battle_cards'].battle_cards : [];

        const hasTag = playerDeck.some(cardId => {
          const bCard = battleCards.find(c => c.id === cardId);
          return bCard && bCard.tags && bCard.tags.includes(choice.reqDeckTag);
        });

        if (!hasTag) return false;
      }
      const deckCardPayload = choice.effects?.deckCard;
      const deckCardId = deckCardPayload && typeof deckCardPayload === 'object'
        ? deckCardPayload.cardId
        : deckCardPayload;
      if (deckCardId && this.skillCardAcquisitionSystem) {
        const validation = this.skillCardAcquisitionSystem.validateCardForPath(
          deckCardId,
          gameState.path
        );
        if (!validation.allowed) return false;
      }
      return true;
    });
  }

  /**
   * 记录选择历史（供 StoryThreadEngine 触发检测使用）
   */
  _recordChoiceHistory(card, direction, choice) {
    if (!gameState.choiceHistory) gameState.choiceHistory = [];
    gameState.choiceHistory.push({
      cardId: card.id,
      cardType: card.type,
      direction: direction,
      turn: gameState.turn,
      // History is display/debug data only, never a causal clock.  Retaining
      // the projected absolute index makes records intelligible after turn is
      // kept merely as a compatibility mirror.
      decisionIndex: typeof gameState.getNextDecisionIndex === 'function'
        ? gameState.getNextDecisionIndex()
        : Math.max(0, Number(gameState.turn) || 0) + 1,
      tags: card.tags || []
    });

    // 记录最近卡牌标签（供 tag_chain 触发）
    if (!gameState.recentCardTags) gameState.recentCardTags = [];
    if (card.tags) {
      for (const tag of card.tags) {
        gameState.recentCardTags.push(tag);
      }
    }
    // 只保留最近 20 个标签
    if (gameState.recentCardTags.length > 20) {
      gameState.recentCardTags = gameState.recentCardTags.slice(-20);
    }

    // 只保留最近 30 条选择历史
    if (gameState.choiceHistory.length > 30) {
      gameState.choiceHistory = gameState.choiceHistory.slice(-30);
    }
  }
}

if (typeof module !== 'undefined' && module.exports) {
  module.exports = GameLogic;
} else if (typeof window !== 'undefined') {
  window.GameLogic = GameLogic;
}
