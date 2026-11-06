/**
 * EffectService - 统一效果解释器
 *
 * 将原本散落在 GameLogic._applyEffects 中的硬编码 if-else 效果分支
 * 抽取为可注册 handler 的服务，新增效果类型无需修改 GameLogic。
 *
 * 当前仍通过全局单例访问外部系统（pathSkillSystem / treasureSystem / ...），
 * 在第三阶段引入依赖注入时再进行替换。
 */
class EffectService {
  constructor({
    gameState,
    eventBus,
    skillCardAcquisitionSystem = null,
    opportunityAcquisitionSystem = null,
    endingEligibilityService = null,
    debug = true
  }) {
    this.gameState = gameState;
    this.eventBus = eventBus;
    this.skillCardAcquisitionSystem = skillCardAcquisitionSystem;
    this.opportunityAcquisitionSystem = opportunityAcquisitionSystem;
    this.endingEligibilityService = endingEligibilityService;
    this.debug = debug;
    this.handlers = new Map();
    this._registerHandlers();
  }

  _dbg(...args) {
    if (this.debug) console.log('[EffectService]', ...args);
  }

  _getEffectMeta(key) {
    const metadata = {
      health: { label: '气血', unit: '点' },
      daoHeart: { label: '道心', unit: '点' },
      cultivation: { label: '修为', unit: '点' },
      fortune: { label: '福缘', unit: '点' },
      karmaGood: { label: '善因', unit: '点' },
      karmaBad: { label: '恶因', unit: '点' },
      aura: { label: '灵息', unit: '点' },
      tianji: { label: '天机', unit: '点' },
      spiritStone: { label: '灵石', unit: '枚' },
      lifespan: { label: '寿元', unit: '年' },
      knowledge: { label: '见闻', unit: '点' },
      wisdom: { label: '悟性', unit: '点' },
      rawPower: { label: '体魄', unit: '点' },
      sword_insight: { label: '剑道领悟', unit: '点' },
      spell_insight: { label: '术法领悟', unit: '点' },
      body_insight: { label: '炼体领悟', unit: '点' },
      pill_insight: { label: '丹道领悟', unit: '点' }
    };
    return metadata[key] || { label: key, unit: '' };
  }

  _buildEffectFact(key, value, context = {}) {
    if (key === 'skillOpportunity') {
      const offerId = typeof value === 'string' ? value : value?.offerId;
      const qualification = this.skillCardAcquisitionSystem?.previewOpportunity?.(offerId, {
        sourceCardId: context?.cardId || null
      }) || { eligible: false, reason: 'acquisition_unavailable', cardId: null,
        cardName: null, chance: null, oncePerLife: false };
      const name = qualification.cardName || '特殊功法';
      const rejectionText = {
        already_acquired: `已悟得【${name}】，不重复取得`,
        already_attempted: `本世已尝试参悟【${name}】，不再掷骰`,
        path_mismatch: `当前流派不能参悟【${name}】`,
        realm_locked: `境界未达要求，本次无法参悟【${name}】`,
        source_mismatch: `此机缘来源不符，本次不能参悟【${name}】`,
        missing_provenance: `取得凭据缺失，本次不能参悟【${name}】`,
        unknown_offer: '机缘奖励定义缺失，本次不能取得功法',
        unknown_card: '功法定义缺失，本次不能取得功法',
        missing_path_tag: '功法流派归属缺失，本次不能取得功法',
        acquisition_unavailable: '授卡服务不可用，本次不能取得功法'
      };
      return {
        key, label: '随机参悟', value: offerId || null,
        text: qualification.eligible
          ? `参悟【${name}】，成功率${qualification.chance}%${qualification.oncePerLife ? '（本世仅可尝试一次）' : ''}`
          : (rejectionText[qualification.reason] || '当前不具备参悟功法的资格'),
        eligible: qualification.eligible, reason: qualification.reason,
        cardId: qualification.cardId || null,
        chance: qualification.chance, oncePerLife: qualification.oncePerLife
      };
    }
    if (key === 'skillAcquire') {
      const offerId = typeof value === 'string' ? value : value?.offerId;
      const qualification = this.skillCardAcquisitionSystem?.previewGuaranteed?.(offerId, {
        sourceCardId: context?.cardId || null
      }) || { eligible: false, reason: 'acquisition_unavailable', cardId: null, cardName: null };
      const name = qualification.cardName || '特殊功法';
      const rejectionText = {
        already_acquired: `已悟得【${name}】，不重复取得`,
        path_mismatch: `当前流派不能取得【${name}】`,
        realm_locked: `境界未达要求，本次无法悟得【${name}】`,
        source_mismatch: `此机缘来源不符，本次不能取得【${name}】`,
        missing_provenance: `取得凭据缺失，本次不能取得【${name}】`,
        unknown_offer: '机缘奖励定义缺失，本次不能取得功法',
        unknown_card: '功法定义缺失，本次不能取得功法',
        missing_path_tag: '功法流派归属缺失，本次不能取得功法',
        acquisition_unavailable: '授卡服务不可用，本次不能取得功法'
      };
      return {
        key,
        label: '特殊功法',
        text: qualification.eligible ? `必定悟得【${name}】`
          : (rejectionText[qualification.reason] || '当前不具备取得功法的资格'),
        value: offerId || null,
        eligible: qualification.eligible,
        reason: qualification.reason,
        cardId: qualification.cardId || null
      };
    }
    if (key === 'playerLocation') {
      return { key, label: '去向', text: `前往【${String(value)}】`, value };
    }
    if (key.startsWith('npc_relation:')) {
      const npcId = key.slice('npc_relation:'.length);
      const delta = Number(value) || 0;
      return { key, label: '人物关系', text: `与${npcId}关系${delta >= 0 ? '+' : ''}${delta}`, value: delta };
    }
    const named = {
      treasure: '获得法宝',
      pill: '获得丹药',
      companion: '结识同伴',
      path: '道路改变',
      find_clue: '取得线索',
      endingCandidate: '终局倾向被记录'
    };
    if (named[key]) {
      const suffix = typeof value === 'string' ? `【${value}】` : '';
      return { key, label: named[key], text: `${named[key]}${suffix}`, value };
    }
    if (Number.isFinite(Number(value))) {
      const numeric = Number(value);
      const meta = this._getEffectMeta(key);
      return {
        key,
        label: meta.label,
        text: `${meta.label}${numeric >= 0 ? '+' : ''}${numeric}${meta.unit || ''}`,
        value: numeric
      };
    }
    return {
      key,
      label: this._getEffectMeta(key).label,
      text: `${this._getEffectMeta(key).label}将发生变化`,
      value: value === undefined ? null : JSON.parse(JSON.stringify(value))
    };
  }

  _resolveEffectValue(key, value, context = {}, { log = false } = {}) {
    if (!Number.isFinite(Number(value))) return value;
    let resolved = Number(value);
    const isMeditation = context.cardId
      && (context.cardId.includes('meditation')
        || (Array.isArray(context.cardTags) && context.cardTags.includes('cultivation')));
    if (isMeditation && resolved > 0
      && ['cultivation', 'daoHeart', 'aura'].includes(key)
      && typeof this.gameState?._getAggregatedPassives === 'function') {
      const multiplier = Number(this.gameState._getAggregatedPassives()?.meditationBonus) || 0;
      if (multiplier > 0) {
        resolved = Math.floor(resolved * multiplier);
        if (log) this._log(`静心明道：冥想收益提升至 ${resolved}`, context);
      }
    }

    if (key === 'daoHeart' && resolved < 0
      && typeof pathSkillSystem !== 'undefined' && pathSkillSystem && this.gameState.path) {
      const ratio = Number(pathSkillSystem.getPassiveBonuses(this.gameState.path)?.daoResist) || 0;
      const reduction = ratio > 0 ? Math.floor(Math.abs(resolved) * ratio) : 0;
      if (reduction > 0) {
        resolved += reduction;
        if (log) this._log(`道心通透，减轻了 ${reduction} 点道心损伤！`, context);
      }
    }

    if (key === 'spiritStone' && resolved > 0
      && typeof pathSkillSystem !== 'undefined' && pathSkillSystem && this.gameState.path) {
      const ratio = Number(pathSkillSystem.getPassiveBonuses(this.gameState.path)?.spiritStoneBonus) || 0;
      const bonus = ratio > 0 ? Math.floor(resolved * ratio) : 0;
      if (bonus > 0) {
        resolved += bonus;
        if (log) this._log(`道法自然，额外获得 ${bonus} 灵石！`, context);
      }
    }
    return resolved;
  }

  /** Public non-mutating projection consumed by GameLogic and UI. */
  previewChoice(choice, context = {}) {
    return this._projectChoiceEffects(choice, context, false);
  }

  /**
   * Project an outcome that will settle, not an optional cost that must be
   * affordable before choosing. Uses the same value modifiers and State
   * projections as apply(); losses clamp even when they exhaust a resource.
   */
  previewEffects(effects, context = {}) {
    return this._projectChoiceEffects({ effects }, context, true);
  }

  _projectChoiceEffects(choice, context, settlement) {
    const source = choice && typeof choice === 'object' ? choice : {};
    const effects = source.effects && typeof source.effects === 'object' ? source.effects : {};
    const snapshot = {
      attributes: { ...(this.gameState?.attributes || {}) },
      resources: {
        ...(this.gameState?.resources || {}),
        pills: { ...(this.gameState?.resources?.pills || {}) }
      }
    };
    const costs = [];
    const changes = [];
    const skillCards = [];
    const effectFacts = [];
    const reasons = [];
    const costCheck = source.costCheck && typeof source.costCheck === 'object'
      ? source.costCheck
      : {};

    const addReason = (code, key) => {
      if (!reasons.some(reason => reason.code === code && reason.key === key)) {
        reasons.push({ code, key });
      }
    };
    const addCost = ({ key, label, source: costSource, required, current, survives = false }) => {
      const numericRequired = Math.max(0, Number(required) || 0);
      const numericCurrent = Math.max(0, Number(current) || 0);
      const affordable = survives ? numericCurrent > numericRequired : numericCurrent >= numericRequired;
      const meta = this._getEffectMeta(key);
      const item = {
        key,
        label: label || meta.label,
        unit: meta.unit || '个',
        source: costSource,
        required: numericRequired,
        current: numericCurrent,
        after: affordable ? numericCurrent - numericRequired : numericCurrent,
        shortfall: affordable ? 0 : Math.max(1, numericRequired - numericCurrent + (survives ? 1 : 0)),
        affordable
      };
      costs.push(item);
      if (!affordable) {
        addReason(key.startsWith('pill:') ? 'missing_required_resource' : 'insufficient_resource', key);
      }
      return item;
    };

    if (source.requiredPill) {
      const pillId = String(source.requiredPill);
      const pillName = Object.values(this.gameState?.config?.realms?.realms || {})
        .find(realm => realm?.pillRequired === pillId)?.pillName || pillId;
      addCost({
        key: `pill:${pillId}`,
        label: `丹药·${pillName}`,
        source: 'requiredPill',
        required: 1,
        current: Number(snapshot.resources.pills?.[pillId]) || 0
      });
    }

    const costSources = {
      spiritStone: { bucket: 'resources', survives: false },
      lifespan: { bucket: 'resources', survives: true },
      health: { bucket: 'attributes', survives: true },
      karmaGood: { bucket: 'attributes', survives: false }
    };
    const pillCosts = costCheck.pills && typeof costCheck.pills === 'object'
      && !Array.isArray(costCheck.pills)
      ? costCheck.pills
      : {};
    for (const [pillId, required] of Object.entries(pillCosts)) {
      if (!(Number(required) > 0)) continue;
      const current = Number(snapshot.resources.pills?.[pillId]) || 0;
      const cost = addCost({
        key: `pill:${pillId}`,
        label: `丹药·${pillId}`,
        source: 'costCheck.pills',
        required,
        current
      });
      if (cost.affordable) snapshot.resources.pills[pillId] = cost.after;
    }
    for (const [key, required] of Object.entries(costCheck)) {
      if (!costSources[key] || !(Number(required) > 0)) continue;
      const rule = costSources[key];
      const current = Number(snapshot[rule.bucket]?.[key]) || 0;
      const cost = addCost({ key, source: 'costCheck', required, current, survives: rule.survives });
      if (cost.affordable && rule.bucket === 'attributes') {
        const projected = this.gameState.projectAttributeChange(key, -Number(required), snapshot);
        for (const change of projected.changes) snapshot.attributes[change.key] = change.newValue;
        cost.after = projected.newValue;
        cost.actualDelta = projected.actualDelta;
      } else if (cost.affordable) {
        const projected = this.gameState.projectResourceChange(key, -Number(required), snapshot);
        snapshot.resources[key] = projected.newValue;
        cost.after = projected.newValue;
        cost.actualDelta = projected.actualDelta;
      } else {
        cost.actualDelta = 0;
      }
    }

    const attributeKeys = new Set([
      'health', 'daoHeart', 'cultivation', 'fortune', 'karmaGood', 'karmaBad', 'aura', 'tianji'
    ]);
    const resourceKeys = new Set(['spiritStone', 'lifespan']);
    let hasPositiveNumeric = false;
    let hasNegativeNumeric = false;
    const presentationKeys = new Set([
      'text', 'desc', 'description', 'image', 'effects', 'costCheck', 'requiredPill', 'costText'
    ]);
    let hasMeaningfulNonNumeric = Object.entries(source).some(([key, value]) => (
      !presentationKeys.has(key) && value !== undefined && value !== null && value !== false
    ));
    const positiveChanges = [];

    for (const [key, rawValue] of Object.entries(effects)) {
      if (costCheck[key] && Number(rawValue) < 0) continue;
      if (key === 'deckCard') {
        const payload = rawValue && typeof rawValue === 'object' ? rawValue : { cardId: rawValue };
        const card = this.skillCardAcquisitionSystem?.getCardDefinition?.(payload.cardId) || null;
        skillCards.push({
          cardId: payload.cardId || null,
          name: card?.name || card?.title || payload.cardId || '未知功法',
          type: card?.type || 'unknown',
          cost: Number.isFinite(Number(card?.cost)) ? Number(card.cost) : null,
          description: card?.description || card?.desc || '',
          rules: card?.effects ? JSON.parse(JSON.stringify(card.effects)) : [],
          tags: Array.isArray(card?.tags) ? card.tags.slice() : [],
          found: Boolean(card)
        });
        hasMeaningfulNonNumeric = true;
        continue;
      }

      if (!Number.isFinite(Number(rawValue))) {
        if (rawValue !== undefined && rawValue !== null && rawValue !== false) {
          hasMeaningfulNonNumeric = true;
          effectFacts.push(this._buildEffectFact(key, rawValue, context));
        }
        continue;
      }
      const resolvedValue = this._resolveEffectValue(key, Number(rawValue), context, { log: false });
      if (resolvedValue > 0) hasPositiveNumeric = true;
      if (resolvedValue < 0) hasNegativeNumeric = true;

      if (resourceKeys.has(key)) {
        if (resolvedValue < 0 && !settlement) {
          const current = Number(snapshot.resources[key]) || 0;
          const cost = addCost({
            key,
            source: 'effect',
            required: Math.abs(resolvedValue),
            current,
            survives: key === 'lifespan'
          });
          const meta = this._getEffectMeta(key);
          const actualDelta = cost.affordable ? -cost.required : 0;
          changes.push({
            key, label: meta.label, unit: meta.unit,
            oldValue: current,
            newValue: cost.affordable ? cost.after : current,
            requestedDelta: Number(rawValue),
            resolvedDelta: resolvedValue,
            actualDelta,
            delta: actualDelta,
            maxValue: null,
            capped: !cost.affordable
          });
          if (cost.affordable) snapshot.resources[key] = cost.after;
        } else {
          const projected = this.gameState.projectResourceChange(key, resolvedValue, snapshot);
          const meta = this._getEffectMeta(key);
          const change = { ...projected, label: meta.label, unit: meta.unit, delta: projected.actualDelta };
          changes.push(change);
          if (resolvedValue > 0) positiveChanges.push(change);
          snapshot.resources[key] = projected.newValue;
        }
        continue;
      }

      if (attributeKeys.has(key)) {
        const projected = this.gameState.projectAttributeChange(key, resolvedValue, snapshot);
        for (const projectedChange of projected.changes) {
          const meta = this._getEffectMeta(projectedChange.key);
          const change = { ...projectedChange, label: meta.label, unit: meta.unit, delta: projectedChange.actualDelta };
          changes.push(change);
          snapshot.attributes[projectedChange.key] = projectedChange.newValue;
          if (resolvedValue > 0 && projectedChange.key === key) positiveChanges.push(change);
        }
        continue;
      }
      hasMeaningfulNonNumeric = true;
      effectFacts.push(this._buildEffectFact(key, resolvedValue, context));
    }

    const pureIneffectivePositive = hasPositiveNumeric
      && !hasNegativeNumeric
      && !hasMeaningfulNonNumeric
      && positiveChanges.length > 0
      && positiveChanges.every(change => change.actualDelta === 0);
    if (pureIneffectivePositive && !settlement) addReason('all_positive_rewards_capped', 'effects');

    return {
      executable: reasons.length === 0,
      reason: reasons[0]?.code || 'allowed',
      reasons,
      costs,
      changes,
      skillCards,
      effectFacts,
      pureIneffectivePositive
    };
  }

  /**
   * Card-level projection prevents a hard lock when every other route is
   * unaffordable and the remaining harmless route is capped.
   */
  previewCardChoices(card, context = {}) {
    const choices = card?.choices && typeof card.choices === 'object' ? card.choices : {};
    const previews = Object.fromEntries(Object.entries(choices).map(([direction, choice]) => [
      direction,
      this.previewChoice(choice, {
        ...context,
        cardId: context.cardId || card?.id || null,
        cardTags: context.cardTags || card?.tags || []
      })
    ]));
    if (Object.values(previews).some(preview => preview.executable)) return previews;

    const fallbackDirection = Object.keys(choices).find(direction => (
      previews[direction]?.reason === 'all_positive_rewards_capped'
      && !(previews[direction]?.costs || []).some(cost => !cost.affordable)
    ));
    if (!fallbackDirection) return previews;
    const fallback = previews[fallbackDirection];
    previews[fallbackDirection] = {
      ...fallback,
      executable: true,
      reason: 'capped_fallback',
      reasons: (fallback.reasons || []).filter(reason => reason.code !== 'all_positive_rewards_capped'),
      fallback: true
    };
    return previews;
  }

  /**
   * 批量应用 effects
   * @param {Object} effects - 卡牌/选择的 effects 对象
   * @param {Object} context - 上下文回调：log, onNpcRelation, onCompanionActivated
   */
  apply(effects, context) {
    const baseline = this.captureObservableState();
    if (!effects || typeof effects !== 'object') {
      this._dbg('apply skipped: empty effects');
      return { applied: false, effectKeys: [], changes: [] };
    }

    const RouterClass = typeof ChoiceOutcomeRouter !== 'undefined'
      ? ChoiceOutcomeRouter
      : (typeof require === 'function' ? require('../systems/ChoiceOutcomeRouter.js') : null);
    // Legacy isolated VMs may load this service without the router script. In
    // that environment, the concrete registered consumer map is the exact
    // fallback authority; it still rejects every unhandled field and typo.
    const fallbackUnknownFields = Object.keys(effects).filter(key =>
      !this.handlers.has(key)
      && !(key.startsWith('npc_relation:') && key.length > 'npc_relation:'.length)
      && !(key.startsWith('bond_') && key.length > 'bond_'.length)
    );
    const audit = RouterClass?.auditEffectFields?.(effects) || {
      valid: fallbackUnknownFields.length === 0,
      unknownFields: fallbackUnknownFields.sort()
    };
    if (!audit.valid) {
      this._dbg('apply rejected: unknown effect field', audit.unknownFields);
      return {
        applied: false,
        reason: 'unknown_effect_field',
        unknownFields: audit.unknownFields.slice(),
        effectKeys: [],
        changes: []
      };
    }

    this._dbg('apply start', effects);
    // 随机技能机遇必须读取“做出选择前”的属性快照，不能因 JSON 键顺序
    // 先吃到同一选项里的修为/因果增量而改变成功率。
    const entries = Object.entries(effects);
    const opportunityKeys = new Set(['skillOpportunity', 'opportunityReward']);
    const opportunityEntries = entries.filter(([key]) => opportunityKeys.has(key));
    if (opportunityEntries.length) {
      entries.splice(0, entries.length,
        ...opportunityEntries,
        ...entries.filter(([key]) => !opportunityKeys.has(key))
      );
    }
    const handlerResults = {};
    for (const [key, value] of entries) {
      const handlerResult = this._applySingle(
        key,
        this._resolveEffectValue(key, value, context || {}, { log: true }),
        context
      );
      if (handlerResult !== undefined) handlerResults[key] = handlerResult;
    }
    this._dbg('apply end');
    return {
      applied: true,
      effectKeys: entries.map(([key]) => key),
      changes: this.createSettlement(baseline).changes,
      handlerResults
    };
  }

  captureObservableState() {
    const attributes = this.gameState?.attributes || {};
    const resources = this.gameState?.resources || {};
    return {
      health: Number(attributes.health) || 0,
      daoHeart: Number(attributes.daoHeart) || 0,
      cultivation: Number(attributes.cultivation) || 0,
      fortune: Number(attributes.fortune) || 0,
      karmaGood: Number(attributes.karmaGood) || 0,
      karmaBad: Number(attributes.karmaBad) || 0,
      aura: Number(attributes.aura) || 0,
      tianji: Number(attributes.tianji) || 0,
      spiritStone: Number(resources.spiritStone) || 0,
      lifespan: Number(resources.lifespan) || 0
    };
  }

  createSettlement(baseline = {}) {
    const after = this.captureObservableState();
    const keys = [
      'health', 'daoHeart', 'cultivation', 'fortune', 'karmaGood',
      'karmaBad', 'aura', 'tianji', 'spiritStone', 'lifespan'
    ];
    const changes = [];
    for (const key of keys) {
      const meta = this._getEffectMeta(key);
      const oldValue = Number(baseline[key]) || 0;
      const newValue = Number(after[key]) || 0;
      if (oldValue === newValue) continue;
      const maxValue = this.gameState?.getAttributeMaximum && key in (this.gameState.attributes || {})
        ? this.gameState.getAttributeMaximum(key)
        : null;
      changes.push({
        key,
        label: meta.label,
        unit: meta.unit,
        oldValue,
        newValue,
        actualDelta: newValue - oldValue,
        delta: newValue - oldValue,
        maxValue,
        capped: maxValue !== null && newValue === maxValue
      });
    }
    return { before: { ...baseline }, after, changes };
  }

  _applySingle(key, value, context) {
    if (this.handlers.has(key)) {
      this._dbg('handle', key, value);
      return this.handlers.get(key)(value, context);
    } else if (key.startsWith('npc_relation:')) {
      this._dbg('handle npc_relation', key, value);
      this._applyNpcRelation(key, value, context);
    } else if (key.startsWith('bond_')) {
      const npcId = key.slice(5);
      if (typeof npcSystem !== 'undefined' && npcSystem && npcSystem.addAffection) {
        npcSystem.addAffection(npcId, value);
        this._log(`与${npcId}的羁绊 ${value >= 0 ? '+' : ''}${value}`, context);
      }
    } else {
      this._dbg('no handler for key', key);
    }
  }

  _log(msg, context) {
    if (context && typeof context.log === 'function') {
      context.log(msg);
    }
  }

  _acquireTreasure(treasureId, options = {}) {
    if (typeof treasureSystem !== 'undefined' && treasureSystem
      && typeof treasureSystem.acquire === 'function') {
      return treasureSystem.acquire(treasureId, options);
    }
    return false;
  }

  _treasureTransactionId(channel, sourceId, treasureId, context = {}) {
    const runClock = this.gameState?.getRunClock?.() || null;
    const life = runClock?.lifeId
      || `legacy:${Number(this.gameState?.getLifeCount?.() ?? this.gameState?.unlocks?.lifeCount ?? 0) || 0}`;
    // Effects settle before the top-level decision commits. Bind them to the
    // projected persistent decision, rather than the legacy `turn` mirror.
    const decision = Math.max(0, Number(
      context.decisionIndex
      ?? this.gameState?.getNextDecisionIndex?.()
      ?? this.gameState?.getDecisionIndex?.()
      ?? this.gameState?.turn
    ) || 0);
    const source = String(sourceId || context.cardId || context.sourceCardId || 'anonymous');
    return `treasure:${channel}:life:${life}:decision:${decision}:source:${source}:item:${treasureId}`;
  }

  _registerHandlers() {
    // 功法选择
    this.handlers.set('path', (value) => {
      this.gameState.path = value;
    });

    // 真元 / MP 兼容映射 -> 转换为修为灵力
    this.handlers.set('mp', (value, context) => {
      this.gameState.addAttribute('cultivation', value);
      this._log(`真元修为 ${value >= 0 ? '+' : ''}${value}`, context);
    });

    // 转世标记（由 ReincarnationCoordinator 在 makeChoice 中处理）
    this.handlers.set('reincarnate', () => {});

    // 转世加成（暂存到 gameState，待转世时消费）
    this.handlers.set('reincarnation_bonus', (value, context) => {
      this.gameState._pendingReincBonus = value;
      this._log(`转世加成已记录：${value}`, context);
    });

    // 丹药
    this.handlers.set('pill', (value, context) => {
      this.gameState.addResource('pills', value, 1);
      this._log(`获得丹药：${value}`, context);
    });

    // 法宝
    this.handlers.set('treasure', (value, context) => {
      const sourceId = String(context?.cardId || context?.sourceCardId || value);
      const acquired = this._acquireTreasure(value, {
        source: 'narrative_effect',
        sourceId,
        transactionId: this._treasureTransactionId('narrative', sourceId, value, context)
      });
      const treasure = typeof treasureSystem !== 'undefined' && treasureSystem
        ? treasureSystem.getTreasureData?.(value)
        : null;
      const label = treasure?.name || value;
      if (acquired === false) {
        this._log(`法宝奖励未能写入：${label}`, context);
        eventBus.emit('treasure:acquisitionRejected', { treasureId: value, source: context?.cardId || null });
        return { success: false, treasureId: value, reason: 'treasure_writer_rejected' };
      }
      this._log(`获得法宝：${label}`, context);
      return {
        success: true,
        treasureId: value,
        replayed: Boolean(treasureSystem?.getLastReceipt?.()?.replayed)
      };
    });

    // 道侣
    this.handlers.set('companion', (value, context) => {
      this.gameState.addResource('companions', value, 1);
      this._log(`获得道侣：${value}`, context);
      if (typeof companionSystem !== 'undefined' && companionSystem) {
        companionSystem.register(value);
      }
      if (context && typeof context.onCompanionActivated === 'function') {
        context.onCompanionActivated();
      }
    });

    // 战斗牌组卡牌只委托唯一牌组权威，由其同步永久状态与战斗运行时。
    this.handlers.set('deckCard', (value, context) => {
      const payload = value && typeof value === 'object' ? value : { cardId: value };
      const cardId = payload.cardId;
      let result = null;
      if (this.skillCardAcquisitionSystem && payload.path && payload.sourceType) {
        result = this.skillCardAcquisitionSystem.acquirePathCard(cardId, {
          path: payload.path,
          sourceId: payload.sourceId || context?.cardId || null,
          sourceType: payload.sourceType,
          locationId: payload.locationId || null
        });
      } else if (this.skillCardAcquisitionSystem) {
        result = this.skillCardAcquisitionSystem.acquireLegacyCard(cardId, {
          sourceCardId: payload.sourceId || context?.cardId || null,
          sourceType: payload.sourceType || 'legacy_deck_effect'
        });
      } else {
        result = { acquired: false, reason: 'deck_authority_unavailable', cardId };
        this._dbg('deckCard rejected: deck authority unavailable', cardId);
      }

      // 解析卡牌真实名字以提高显示品质
      let cardName = cardId;
      if (typeof deckCombatSystem !== 'undefined' && deckCombatSystem && deckCombatSystem.cardDB && deckCombatSystem.cardDB[cardId]) {
        cardName = deckCombatSystem.cardDB[cardId].name;
      } else {
        const nameMap = {
          'strike': '青元斩',
          'defend': '灵气盾',
          'heavy_strike': '重剑无锋',
          'sword_intent': '凝结剑意',
          'mana_potion': '回气丹',
          'backlash_flame': '血魔火',
          'qi_shield': '太乙玄黄罩',
          'spell_gather': '五气朝元',
          'spell_tide': '灵力潮汐',
          'spell_nuke': '九天玄雷诀',
          'draw_sword': '拔剑式',
          'sword_array': '太虚剑阵'
        };
        cardName = nameMap[cardId] || cardId;
      }
      if (result?.acquired) {
        this._log(`领悟功法：获得卡牌【${cardName}】！已编入本世牌组。`, context);
      } else if (result?.reason === 'already_acquired') {
        this._log(`【${cardName}】已经掌握，本次不会重复编入牌组。`, context);
      } else if (result?.reason === 'path_mismatch') {
        this._log(`【${cardName}】与你当前道途不合，未编入牌组。`, context);
      }
    });

    this.handlers.set('skillOpportunity', (value, context) => {
      const offerId = typeof value === 'string' ? value : value?.offerId;
      if (!offerId || !this.skillCardAcquisitionSystem) {
        this._log('技能机遇契约不可用，本次没有获得技能牌。', context);
        return;
      }
      const result = this.skillCardAcquisitionSystem.resolveOpportunity(offerId, {
        sourceCardId: context?.cardId || null,
        random: context?.random
      });
      this._logSkillAcquisitionResult(result, context);
    });

    this.handlers.set('opportunityReward', (value, context) => {
      const opportunityId = typeof value === 'string' ? value : value?.opportunityId;
      const profile = typeof value === 'object' ? value?.profile : null;
      if (!opportunityId || !this.opportunityAcquisitionSystem) {
        this._log('机遇奖池契约不可用，本次没有写入卡组或法宝库。', context);
        return;
      }
      const result = this.opportunityAcquisitionSystem.resolve(opportunityId, {
        profile,
        sourceCardId: context?.cardId || null,
        random: context?.random
      });
      if (result?.acquired) {
        const typeName = result.rewardType === 'treasure' ? '法宝' : '技能牌';
        const modeName = result.mode === 'special' ? '特殊悟道' : '机缘落定';
        this._log(`【${modeName}】获得${typeName}【${result.rewardName}】，已写入${
          result.rewardType === 'treasure' ? '法宝库' : '本世卡组'
        }。`, context);
      } else if (result?.reason === 'already_resolved') {
        this._log('这段机缘本世已经落定，不会重复结算。', context);
      } else {
        this._log(`机缘未能结算（${result?.reason || 'unknown'}）。`, context);
      }
    });

    this.handlers.set('skillAcquire', (value, context) => {
      const offerId = typeof value === 'string' ? value : value?.offerId;
      if (!this.skillCardAcquisitionSystem?.acquireGuaranteed) {
        this._log('技能取得契约不可用，本次奖励未写入牌组。', context);
        return { acquired: false, reason: 'acquisition_unavailable', offerId: offerId || null };
      }
      const result = this.skillCardAcquisitionSystem.acquireGuaranteed(offerId, {
        sourceCardId: context?.cardId || null
      });
      this._logSkillAcquisitionResult(result, context);
      return result;
    });

    // 移除卡牌界面（UI 回调）
    this.handlers.set('removeCard', () => {
      if (typeof ui !== 'undefined' && ui && ui.showRemoveCardScreen) {
        ui.showRemoveCardScreen();
      }
    });

    // 升级卡牌界面（UI 回调）
    this.handlers.set('upgradeCard', () => {
      if (typeof ui !== 'undefined' && ui && ui.showUpgradeCardScreen) {
        ui.showUpgradeCardScreen();
      }
    });

    // 基础属性：修为、福缘、气血、善恶因
    this.handlers.set('cultivation', (value) => this.gameState.addAttribute('cultivation', value));
    this.handlers.set('fortune', (value) => this.gameState.addAttribute('fortune', value));
    this.handlers.set('health', (value) => this.gameState.addAttribute('health', value));
    this.handlers.set('aura', (value) => this.gameState.addAttribute('aura', value));

    // 上限类成长，增加上限的同时等额恢复当前值
    this.handlers.set('maxHealth', (value) => {
      this.gameState.maxHealth += value;
      if (value > 0) this.gameState.addAttribute('health', value);
      eventBus.emit('state:attributeChanged', { attribute: 'health', newValue: this.gameState.attributes.health });
    });
    this.handlers.set('maxDaoHeart', (value) => {
      this.gameState.maxDaoHeart += value;
      if (value > 0) this.gameState.addAttribute('daoHeart', value);
      eventBus.emit('state:attributeChanged', { attribute: 'daoHeart', newValue: this.gameState.attributes.daoHeart });
    });

    // === 天劫与法宝赌石专属效果 ===
    this.handlers.set('_consumePill', (value, context) => {
      if (this.gameState.hasResource('pill', value)) {
        this.gameState.consumeResource('pill', value);
        this._log(`消耗了突破灵药【${value === 'foundation' ? '筑基丹' : value}】。`, context);
      }
    });

    this.handlers.set('_consumeTreasure', (value, context) => {
      if (typeof treasureSystem !== 'undefined' && treasureSystem) {
        const list = treasureSystem.getEquippedInstanceIds?.() || [];
        if (list.length === 0) return;
        const trash = list[Math.floor(Math.random() * list.length)];
        const tName = treasureSystem.getTreasureData?.(trash)?.name || trash;
        treasureSystem.remove(trash, this.gameState);
        this._log(`祭出的法宝【${tName}】在天劫雷霆轰击下粉碎，替你挡去部分劫雷威力！`, context);
      }
    });

    // 按境界记录一次性破境助力。flags 已进入因果快照，
    // 因此刷新不会丢失或重复发放。
    this.handlers.set('breakthroughBoost', (value, context) => {
      const realm = typeof value?.realm === 'string' ? value.realm : null;
      const amount = Number(value?.amount);
      if (!realm || !Number.isFinite(amount) || amount <= 0) {
        this._log('破境助力合同无效，本次未写入。', context);
        return;
      }
      const key = `breakthrough_boost:${realm}`;
      const current = Number(this.gameState.getFlag?.(key, 0)) || 0;
      const next = Math.min(0.5, current + amount);
      this.gameState.setFlag(key, next);
      this._log(`【破境助力】${realm} 境下一次破境成功率 +${Math.round(amount * 100)}%`, context);
    });

    this.handlers.set('_setFlag', (value) => {
      this.gameState.setFlag(value, true);
    });

    this.handlers.set('npcLifecycle', (value, context) => {
      const continuity = typeof worldContinuityStore !== 'undefined'
        ? worldContinuityStore
        : null;
      if (!continuity || !value?.npcId || !value?.lifecycle) {
        this._log('人物生命周期契约不可用，本次世界变化已拒绝结算。', context);
        return;
      }
      const result = continuity.transitionNpc(value.npcId, value.lifecycle, {
        manifestation: value.manifestation,
        locationId: value.locationId,
        changedByNode: value.changedByNode || context?.cardId || null,
        reason: value.reason || context?.cardId || 'choice_effect'
      });
      if (result.changed) {
        const labels = { ASCENDED: '飞升', DEAD: '身死', RETIRED: '退隐', DISTANT: '远行', ACTIVE: '归来' };
        this._log(`【世界变迁】${value.npcId}：${labels[value.lifecycle] || value.lifecycle}`, context);
      }
    });

    this.handlers.set('playerLocation', (value, context) => {
      const nextLocation = typeof value === 'string' ? value.trim() : '';
      if (!nextLocation) {
        this._log('地点迁移合同无效，本次移动已拒绝。', context);
        return;
      }
      const previousLocation = this.gameState.currentLocation || null;
      const scene = typeof sceneLayerSystem !== 'undefined' ? sceneLayerSystem : null;
      if (scene && typeof scene.transition === 'function') {
        scene.transition(nextLocation, 'story_event');
      } else {
        this.gameState.currentLocation = nextLocation;
        if (!Array.isArray(this.gameState.visitedLocations)) this.gameState.visitedLocations = [];
        if (!this.gameState.visitedLocations.includes(nextLocation)) this.gameState.visitedLocations.push(nextLocation);
        if (typeof eventBus !== 'undefined' && previousLocation !== nextLocation) {
          eventBus.emit('state:locationChanged', {
            from: previousLocation,
            to: nextLocation,
            reason: 'story_event',
            isFirstVisit: true
          });
        }
      }
      this._log(`【行程】前往 ${nextLocation}。`, context);
    });

    this.handlers.set('_identifyTreasure', (value, context) => {
      const fortune = this.gameState.getAttribute('fortune') || 0;
      const daoHeart = this.gameState.getAttribute('daoHeart') || 0;

      let identifiedTreasure = '';
      let logMsg = '';
      const isBox = (value === 'box');

      // 所有的法宝库按境界分组
      let treasuresByRealm = { qi: [], foundation: [], golden: [], nascent: [] };
      if (typeof treasureSystem !== 'undefined' && treasureSystem && treasureSystem.treasureDB) {
        for (const [id, t] of Object.entries(treasureSystem.treasureDB)) {
          const r = t.realm || 'qi';
          if (r === 'qi') treasuresByRealm.qi.push(id);
          else if (r === 'foundation') treasuresByRealm.foundation.push(id);
          else if (r === 'golden') treasuresByRealm.golden.push(id);
          else treasuresByRealm.nascent.push(id); // nascent, deity, tribulation
        }
      }
      if (typeof equipmentSystem !== 'undefined' && equipmentSystem && equipmentSystem.equipmentData) {
        for (const [id, eq] of Object.entries(equipmentSystem.equipmentData)) {
          const r = eq.tier === '天阶' || eq.tier === '玄阶' ? 'nascent' :
                   (eq.tier === '地阶' ? 'golden' :
                   (eq.tier === '灵阶' ? 'foundation' : 'qi'));
          treasuresByRealm[r].push(id);
        }
      }

      if (treasuresByRealm.qi.length === 0) {
        treasuresByRealm.qi = ['玄铁甲', '灵泉葫芦'];
        treasuresByRealm.foundation = ['避尘珠', '剑心佩'];
        treasuresByRealm.golden = ['避尘珠', '剑心佩'];
        treasuresByRealm.nascent = ['避尘珠', '剑心佩'];
      }

      if (isBox) {
        // 天机宝匣
        const roll = Math.random() * 120 + fortune * 2.5 + daoHeart * 2.5;
        if (roll < 35) {
          // 反震残卷也必须走当前流派的统一奖励池与来源记录。
          const authority = this.skillCardAcquisitionSystem;
          const rewardOffer = authority?.getRewardOffers({
            path: this.gameState.path,
            channel: 'treasure_box_backlash',
            count: 1
          })?.[0] || null;
          const acquisition = rewardOffer
            ? authority.acquirePathCard(rewardOffer.cardId, {
              path: rewardOffer.path,
              sourceType: rewardOffer.sourceType,
              sourceId: 'treasure_box_backlash',
              mode: 'treasure_box'
            })
            : null;
          if (acquisition?.acquired) {
            logMsg = `【开启宝匣】封印骤然引爆！宝物尽毁，只余一页与你道途相合的残卷【${rewardOffer.cardName}】。`;
          } else {
            logMsg = '【开启宝匣】封印骤然引爆！宝物尽毁，残卷也在天机反震中化为飞灰。';
          }
        } else if (roll < 70) {
          // 获得地阶法宝
          const candidates = treasuresByRealm.foundation.length ? treasuresByRealm.foundation : ['避尘珠'];
          identifiedTreasure = candidates[Math.floor(Math.random() * candidates.length)];
          logMsg = `【开启宝匣】天机消退，宝物发光，你从宝匣中取出一件地阶法宝【${identifiedTreasure}】！`;
        } else if (roll < 105) {
          // 获得天阶法宝
          const candidates = treasuresByRealm.golden.length ? treasuresByRealm.golden : ['避尘珠'];
          identifiedTreasure = candidates[Math.floor(Math.random() * candidates.length)];
          logMsg = `【开启宝匣】霞光万道！天道气息汇聚，你成功开启出天阶至宝【${identifiedTreasure}】！`;
        } else {
          // 获得玄阶（元婴）及以上法宝
          const candidates = treasuresByRealm.nascent.length ? treasuresByRealm.nascent : ['避尘珠'];
          identifiedTreasure = candidates[Math.floor(Math.random() * candidates.length)];
          logMsg = `【开启宝匣】太古机缘！太古法则崩裂，一件传说级本命神兵/法宝【${identifiedTreasure}】自天机洪流中浮现，落入你的手中！`;
        }
      } else {
        // 神秘古玩
        const roll = Math.random() * 100 + fortune * 2.0 + daoHeart * 1.5;
        if (roll < 40) {
          this.gameState.addResource('spiritStone', null, 2);
          logMsg = '【鉴宝结果】你细细摩挲这件古玩，发现只是灵气散尽的顽石，只得随手 2 灵石当废铁卖掉。';
        } else if (roll < 75) {
          const candidates = treasuresByRealm.qi.length ? treasuresByRealm.qi : ['玄铁甲', '灵泉葫芦'];
          identifiedTreasure = candidates[Math.floor(Math.random() * candidates.length)];
          logMsg = `【鉴宝结果】擦去锈斑，宝物微光闪烁，是一件凡阶法宝【${identifiedTreasure}】！`;
        } else if (roll < 95) {
          const candidates = treasuresByRealm.foundation.length ? treasuresByRealm.foundation : ['避尘珠'];
          identifiedTreasure = candidates[Math.floor(Math.random() * candidates.length)];
          logMsg = `【鉴宝结果】古玩寸寸碎裂，露出一枚地阶法宝【${identifiedTreasure}】！`;
        } else {
          // 开出高阶天阶法宝
          const candidates = treasuresByRealm.golden.length ? treasuresByRealm.golden : ['剑心佩'];
          identifiedTreasure = candidates[Math.floor(Math.random() * candidates.length)];
          logMsg = `【鉴宝结果】紫气东来！你慧眼识珠，从蒙尘古玩中鉴识出失传已久的天阶法宝【${identifiedTreasure}】！`;
        }
      }

      let acquisitionSucceeded = true;
      let acquisitionReplayed = false;
      if (identifiedTreasure) {
        acquisitionSucceeded = this._acquireTreasure(identifiedTreasure, {
          source: context?.sourceType || (isBox ? 'shop_treasure_box' : 'shop_antique'),
          sourceId: String(context?.sourceId || value || identifiedTreasure),
          transactionId: this._treasureTransactionId(
            'identify',
            context?.sourceId || value || identifiedTreasure,
            identifiedTreasure,
            context
          )
        }) !== false;
        acquisitionReplayed = acquisitionSucceeded && Boolean(treasureSystem?.getLastReceipt?.()?.replayed);
        if (!acquisitionSucceeded) {
          logMsg = `【鉴宝结果】法宝【${identifiedTreasure}】未能写入法宝账本，原物已保留。`;
        }
      }
      this._log(logMsg, context);
      return {
        success: acquisitionSucceeded,
        treasureId: identifiedTreasure || null,
        replayed: acquisitionReplayed,
        reason: acquisitionSucceeded ? null : 'treasure_writer_rejected'
      };
    });

    this.handlers.set('karmaGood', (value) => this.gameState.addAttribute('karmaGood', value));
    this.handlers.set('karmaBad', (value) => this.gameState.addAttribute('karmaBad', value));

    // Passive modifiers are resolved once by _resolveEffectValue before dispatch.
    this.handlers.set('daoHeart', value => this.gameState.addAttribute('daoHeart', value));
    this.handlers.set('spiritStone', value => this.gameState.addResource('spiritStone', null, value));

    // exp 是 cultivation 的别名
    this.handlers.set('exp', (value) => this.gameState.addAttribute('cultivation', value));

    // 寿元
    this.handlers.set('lifespan', (value) => this.gameState.addResource('lifespan', null, value));

    // 【P1 #7 修复】天机值（卡牌 effects.tianji 不再被静默忽略）
    this.handlers.set('tianji', (value, context) => {
      this.gameState.addAttribute('tianji', value);
      this._log(`天机值变化 ${value > 0 ? '+' : ''}${value}`, context);
    });

    // 拒绝天命 / 重新开局
    this.handlers.set('restart', (value, context) => {
      this._log('拒绝天命，重新开局', context);
      this.gameState.reset(true);
      eventBus.emit('game:restart', {});
    });

    // 触发终极结局（由剧情抉择卡的 effects.ending 驱动）
    this.handlers.set('ending', (value, context) => {
      // 强校验：通过 EndingEligibilityService 校验结局准入资格
      const service = this.endingEligibilityService;
      const terminalContext = context?.terminalContext || this.gameState.getTerminalContext?.() || null;
      const evalResult = service
        ? service.evaluate(value, this.gameState, terminalContext)
        : { eligible: false, missingRequirements: [{ text: '结局准入服务未初始化' }] };
      if (!evalResult.eligible) {
        const missing = (evalResult.missingRequirements || []).map(r => r.text).join('；');
        console.warn(`[EndingEligibilityService] 结局「${value}」强校验未通过: ${missing}`);
        this._log(`【结局准入拒绝】无法达成结局「${value}」，缺乏条件: ${missing}`, context);
        if (typeof this.gameState.setEndingCandidate === 'function') {
          this.gameState.setEndingCandidate(value);
        } else {
          this.gameState.endingCandidate = value;
        }
        return;
      }

      const endingDescriptions = {
        ascension: '九重天劫过后，天门大开。你踏入仙庭——飞升成仙。',
        red_dust: '你放弃飞升，以羁绊护住跨世记忆，兵解入轮回。',
        chaos: '你以碎玉为钥匙，撕开天道，自成一道——混沌真解。'
      };
      // 关键修复：主动结局进入 EPILOGUE 生命阶段，不复用死亡态(dead=true)
      this.gameState.deadReason = endingDescriptions[value] || '仙途圆满';
      const atlasReport = typeof evidenceAtlasSystem !== 'undefined' && evidenceAtlasSystem
        ? evidenceAtlasSystem.explainEnding(value)
        : null;
      const testimony = service?.projectTribulationTestimony?.(value, terminalContext);
      const endingReport = testimony ? {
        ...(atlasReport || {}),
        stance: atlasReport?.stance || evalResult.endingName || value,
        reasons: Array.isArray(atlasReport?.reasons) ? atlasReport.reasons : [],
        verifiedHypotheses: Array.isArray(atlasReport?.verifiedHypotheses)
          ? atlasReport.verifiedHypotheses : [],
        discoveredClues: Array.isArray(atlasReport?.discoveredClues)
          ? atlasReport.discoveredClues : [],
        tribulationTestimony: testimony
      } : atlasReport;
      const committed = typeof this.gameState.commitTerminalEnding === 'function'
        && this.gameState.commitTerminalEnding({
          endingId: value,
          pendingCardId: `ending_${value}`,
          victoryToken: terminalContext?.victoryToken,
          report: endingReport
        });
      if (!committed) {
        this._log(`【结局准入拒绝】终局胜利凭证已消费或状态不一致。`, context);
        return;
      }
      this._log(`【终局】${this.gameState.deadReason}`, context);
      // 通知 game.js 切换到对应的结局卡
      this.eventBus.emit('game:ending', { endingType: value, report: endingReport });
    });

    // 设置结局候选（由早期剧情卡或分支驱动，等待合法终局门兑现）
    this.handlers.set('endingCandidate', (value, context) => {
      if (typeof this.gameState.setEndingCandidate === 'function') {
        this.gameState.setEndingCandidate(value);
      } else {
        this.gameState.endingCandidate = value;
      }
      this._log(`【叙事因果】种下结局倾向「${value}」`, context);
    });

    // 叙事知识与证据：进入统一状态源，供任务、真相和结局条件消费。
    this.handlers.set('knowledge', (value) => this.gameState.addKnowledge('world', value));
    this.handlers.set('wisdom', (value) => this.gameState.addKnowledge('wisdom', value));
    this.handlers.set('ancientKnowledge', (value) => this.gameState.addKnowledge('ancient', value));
    this.handlers.set('cultivationKnowledge', (value) => this.gameState.addKnowledge('cultivation', value));
    this.handlers.set('sword_insight', (value) => this.gameState.addKnowledge('sword', value));
    this.handlers.set('spell_insight', (value) => this.gameState.addKnowledge('spell', value));
    this.handlers.set('body_insight', (value) => this.gameState.addKnowledge('body', value));
    this.handlers.set('pill_insight', (value) => this.gameState.addKnowledge('pill', value));
    this.handlers.set('find_clue', (value, context) => {
      if (this.gameState.addClue(value, context && context.cardId)) {
        this._log(`获得线索：【${value}】`, context);
      }
    });

    // 卡牌/同伴内容中的长期修正统一落入 modifiers；战斗与回合系统按需读取。
    const modifierKeys = [
      'alchemyYield', 'charmResist', 'combat_skill', 'critDamage', 'cultivationRate',
      'curseResist', 'damageReduction', 'daoHeartRecovery', 'divinationAccuracy',
      'dodge', 'fateEventsFavorability', 'fearResist', 'heavenEnemyDamage', 'heroism',
      'hpRegen', 'iceAtk', 'illusionPen', 'intimidate', 'karmaSeedEffects', 'lowHpAtk',
      'painConversion', 'poisonResist', 'probabilityEvents', 'rageGeneration', 'rawPower',
      'researchSpeed', 'spellPower', 'swordAtk'
    ];
    for (const key of modifierKeys) {
      this.handlers.set(key, (value) => this.gameState.addModifier(key, value));
    }

    this.handlers.set('pills', (value, context) => {
      this.gameState.addResource('pills', value, 1);
      this._log(`获得丹药：${value}`, context);
    });
    // 流程指令由 GameLogic 消费，在统一解释器中声明为空操作，避免误报未知字段。
    this.handlers.set('triggerCombat', () => {});
    this.handlers.set('innerDemonCancel', (value) => {
      if (value) this.gameState.setFlag('inner_demon_cancelled', true);
    });
  }

  _applyNpcRelation(key, value, context) {
    if (context && typeof context.onNpcRelation === 'function') {
      context.onNpcRelation(key, value);
    }
  }

  _logSkillAcquisitionResult(result, context) {
    if (!result) return;
    if (result.acquired) {
      const name = result.record?.cardName || result.cardId;
      const detail = result.record?.mode === 'random'
        ? `参悟判定 ${result.record.roll}/${result.record.chance}`
        : '战斗胜利传承';
      this._log(`【技能取得】${name}已编入本世牌组（${detail}）。`, context);
      return;
    }
    const labels = {
      roll_failed: `参悟未成（判定 ${result.roll}/${result.chance}）`,
      already_attempted: '此机遇本世已经判定过',
      already_acquired: '此技能已经掌握',
      realm_locked: '当前境界不足',
      source_mismatch: '技能来源不符',
      unknown_offer: '未知技能机遇'
    };
    this._log(`【技能机遇】${labels[result.reason] || '未能取得技能牌'}。`, context);
  }
}

if (typeof module !== 'undefined' && module.exports) {
  module.exports = EffectService;
}
