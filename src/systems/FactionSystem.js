/**
 * FactionSystem - 势力暗流引擎
 *
 * 管理修仙界各宗门派系斗争、权力更迭、暗流事件。
 * 事件通过 CardSystem 优先级40注入卡牌流。
 * 数据来源：data/world/factions.json
 */
class FactionSystem {
  constructor() {
    /** @type {Map<string, Object>} factionId → 势力定义 */
    this.factions = new Map();
    /** @type {Object<string, Object>} 势力事件库 */
    this.events = {};
    /** @type {Object<string, number>} 玩家在各势力的声望 */
    this.reputations = {};
    /** @type {Object<string, Object>} 暗流进度 */
    this.undercurrents = {};
    /** @type {Object} 已触发的全局事件标记 */
    this.globalFlags = {};
    /** @type {number} 距离上次势力事件的轮数 */
    this._ticksSinceEvent = 0;
    this._baselineReputations = {};
    this._baselineUndercurrentStages = {};
  }

  /**
   * 初始化
   */
  init() {
    eventBus.on('faction:checkEvent', () => this._onCheckEvent());
    eventBus.on('faction:getStatus', (data) => this._onGetStatus(data));
    eventBus.on('state:reset', () => this._onReset());
  }

  /**
   * 加载势力数据
   * @param {Object} data - { factions: [...], events: {...}, undercurrents: {...} }
   */
  loadData(data) {
    if (!data) return;

    if (data.factions) {
      for (const faction of data.factions) {
        this.factions.set(faction.id, faction);
        this._baselineReputations[faction.id] = Number(faction.startReputation) || 0;
        if (faction.subfactions) {
          for (const sub of faction.subfactions) {
            this._baselineReputations[sub.id] = Number(sub.startReputation) || 0;
          }
        }
      }
    }

    if (data.events) {
      this.events = data.events;
    }

    if (data.undercurrents) {
      this.undercurrents = JSON.parse(JSON.stringify(data.undercurrents));
      this._baselineUndercurrentStages = Object.fromEntries(
        Object.entries(this.undercurrents).map(([id, value]) => [
          id,
          Math.max(0, Math.floor(Number(value?.stage) || 0))
        ])
      );
    }

    const restored = gameState.factionProgress && typeof gameState.factionProgress === 'object'
      ? gameState.factionProgress
      : null;
    const hasRestoredProgress = restored
      && Object.keys(restored.reputations || {}).length > 0;
    if (hasRestoredProgress) this._hydrateProgress(restored);
    else this._resetForNewLife({ useLegacy: !this._hasSameLifeSnapshot() });
    gameState.factionProgress = this.exportProgress();
  }

  _hasSameLifeSnapshot() {
    const snapshot = gameState.unlocks?.causalSessionState;
    return Boolean(snapshot
      && Number(snapshot.lifeCount) === Number(gameState.getLifeCount?.() || 0));
  }

  _resetForNewLife({ useLegacy = true } = {}) {
    const inherited = useLegacy ? (gameState.unlocks?.legacy?.factionReputations || {}) : {};
    this.reputations = {};
    for (const [factionId, baseline] of Object.entries(this._baselineReputations)) {
      const legacyValue = Number(inherited[factionId]);
      this.reputations[factionId] = Number.isFinite(legacyValue) && legacyValue !== 0
        ? Math.max(-100, Math.min(100, Math.round(legacyValue)))
        : baseline;
    }
    for (const [id, undercurrent] of Object.entries(this.undercurrents || {})) {
      undercurrent.stage = this._baselineUndercurrentStages[id] || 0;
    }
    this.globalFlags = {};
    this._ticksSinceEvent = 0;
  }

  _hydrateProgress(progress) {
    this.reputations = { ...this._baselineReputations };
    for (const [factionId, reputation] of Object.entries(progress.reputations || {})) {
      if (!Object.prototype.hasOwnProperty.call(this._baselineReputations, factionId)) continue;
      if (!Number.isFinite(Number(reputation))) continue;
      this.reputations[factionId] = Math.max(-100, Math.min(100, Number(reputation)));
    }
    for (const [id, undercurrent] of Object.entries(this.undercurrents || {})) {
      const savedStage = Number(progress.undercurrentStages?.[id]);
      const baseline = this._baselineUndercurrentStages[id] || 0;
      undercurrent.stage = Number.isFinite(savedStage)
        ? Math.max(0, Math.min(Number(undercurrent.maxStage) || 5, Math.floor(savedStage)))
        : baseline;
    }
    this.globalFlags = Object.fromEntries(
      Object.entries(progress.globalFlags || {}).filter(([id, enabled]) => id && enabled === true)
    );
    this._ticksSinceEvent = Math.max(0, Math.floor(Number(progress.ticksSinceEvent) || 0));
  }

  // Only for an already trusted, same-transaction snapshot. Unlike cold data
  // migration, rollback must preserve legal dynamic reputations and must not
  // retain IDs introduced by the rejected candidate.
  restoreRollbackState(progress) {
    const before = progress ? JSON.parse(JSON.stringify(progress)) : {};
    this.reputations = before.reputations || {};
    for (const [id, undercurrent] of Object.entries(this.undercurrents || {})) {
      undercurrent.stage = before.undercurrentStages?.[id] ?? 0;
    }
    this.globalFlags = before.globalFlags || {};
    this._ticksSinceEvent = before.ticksSinceEvent ?? 0;
    return true;
  }

  exportProgress() {
    return {
      reputations: Object.fromEntries(Object.entries(this.reputations || {})
        .filter(([id, value]) => id && Number.isFinite(Number(value)))
        .map(([id, value]) => [id, Math.max(-100, Math.min(100, Number(value)))])),
      undercurrentStages: Object.fromEntries(Object.entries(this.undercurrents || {})
        .map(([id, value]) => [id, Math.max(0, Math.floor(Number(value?.stage) || 0))])),
      globalFlags: Object.fromEntries(Object.entries(this.globalFlags || {})
        .filter(([id, enabled]) => id && enabled === true)),
      ticksSinceEvent: Math.max(0, Math.floor(Number(this._ticksSinceEvent) || 0))
    };
  }

  _persistProgress() {
    gameState.factionProgress = this.exportProgress();
    return typeof gameState.persistCausalSession === 'function'
      ? gameState.persistCausalSession()
      : false;
  }

  _isNarrativeEligible(card) {
    return Boolean(card) && (
      typeof narrativeLedger === 'undefined' || !narrativeLedger
      || typeof narrativeLedger.canPresent !== 'function'
      || narrativeLedger.canPresent(card, { state: gameState })
    );
  }

  // ==========================================
  // 势力事件检查（优先级40）
  // ==========================================

  _onCheckEvent() {
    this._ticksSinceEvent++;
    this._persistProgress();

    // 至少要过了15轮才可能触发
    if (this._ticksSinceEvent < 15) {
      eventBus.emit('faction:eventCard', { card: null });
      return;
    }

    // 候选池先做语义准入；耗尽时不允许把已完成卡重新发出。
    const event = this._pickFactionEvent();
    const card = event ? this._buildFactionCard(event) : null;
    if (!event || !this._isNarrativeEligible(card)) {
      eventBus.emit('faction:eventCard', { card: null });
      return;
    }

    this._ticksSinceEvent = 0;
    this._persistProgress();

    eventBus.emit('faction:eventCard', { card, priority: 40 });
  }

  /**
   * 选取势力事件
   */
  _pickFactionEvent() {
    const candidates = [];

    for (const [factionId, faction] of this.factions) {
      if (!faction.events) continue;

      for (const ev of faction.events) {
        // A physical faction beat belongs to its authored place.  The map is
        // observational, so this gate is enforced by the same card-flow state
        // that other narrative producers use; an invitation cannot materialize
        // in a disconnected cave merely because its cadence happened to tick.
        if (!this._isEventLocationEligible(ev)) continue;

        // 境界检查
        if (ev.minRealm) {
          const realmOrder = ['qi', 'foundation', 'golden', 'nascent', 'deity', 'tribulation'];
          const currentIdx = realmOrder.indexOf(gameState.realm);
          const minIdx = realmOrder.indexOf(ev.minRealm);
          if (currentIdx < minIdx) continue;
        }

        // 功法限制
        if (ev.pathRestriction && ev.pathRestriction !== gameState.path) continue;

        // 势力声望限制
        if (ev.minReputation !== undefined &&
            (this.reputations[factionId] || 0) < ev.minReputation) continue;

        // 一次性事件
        if (ev.once && this.globalFlags['faction_' + ev.id]) continue;

        // 前置条件
        if (ev.requiresFlag && !gameState.hasFlag(ev.requiresFlag)) continue;

        // 暗流阶段
        if (ev.undercurrentId) {
          const uc = this.undercurrents[ev.undercurrentId];
          if (!uc || uc.stage < (ev.undercurrentStage || 1)) continue;
        }

        // 概率修正
        let weight = ev.weight || 10;
        if (gameState.attributes.fortune > 60) weight += 3;
        if (ev.pathRestriction === gameState.path) weight *= 1.5;

        const candidate = { factionId, event: ev, weight };
        if (!this._isNarrativeEligible(this._buildFactionCard(candidate))) continue;
        candidates.push(candidate);
      }
    }

    if (candidates.length === 0) return null;

    // 权重抽选
    const totalWeight = candidates.reduce((s, c) => s + c.weight, 0);
    let roll = Math.random() * totalWeight;
    for (const c of candidates) {
      roll -= c.weight;
      if (roll <= 0) return c;
    }

    return candidates[candidates.length - 1];
  }

  /**
   * 构建势力事件卡
   */
  _buildFactionCard(selected) {
    const { factionId, event: ev } = selected;
    const faction = this.factions.get(factionId);

    return {
      id: `faction_${ev.id}`,
      semanticKey: ev.semanticKey || `faction:${factionId}:event:${ev.id}`,
      title: ev.title || '势力事件',
      description: ev.desc || '宗门中暗流涌动...',
      type: 'FACTION_EVENT',
      realm: gameState.realm,
      factionId,
      factionEventId: ev.id,
      location: ev.location || null,
      requiresPlayerPresence: ev.requiresPlayerPresence === true,
      // A location-combat invitation is a commitment made at this place, not
      // an ambient beat that may expire invisibly behind unrelated cards.
      // FlowDirector owns its safe-gap delivery policy; keep the authored
      // classification on the runtime card so that policy survives the
      // FactionSystem producer boundary and cold-resume source rebuild.
      deliveryClass: typeof ev.deliveryClass === 'string' ? ev.deliveryClass : null,
      // The invitation scene belongs to the faction event itself. It is not a
      // cropped combat battlefield: the choice below owns the later move into
      // that battlefield through a confirmed combat entry effect.
      sceneImage: ev.sceneImage || null,
      narrativeSource: ev.narrativeSource || `faction:${factionId}:${ev.id}`,
      weight: 0,
      once: ev.once !== false,
      choices: this._fmtFactionChoices(ev, factionId)
    };
  }

  /**
   * Recreate a faction source card from the authored world data.
   *
   * This intentionally does not run cadence, location, once, or reputation
   * eligibility.  Those rules decide whether a new invitation may appear;
   * a paused combat already has an authorized source card and must be rebuilt
   * from the same static definition before DeckCombatSystem accepts its saved
   * authority projection on a cold resume.
   */
  getAuthoritativeEventCard(cardId) {
    if (typeof cardId !== 'string' || !cardId.startsWith('faction_')) return null;
    for (const [factionId, faction] of this.factions) {
      for (const event of faction?.events || []) {
        if (`faction_${event?.id || ''}` !== cardId) continue;
        const card = this._buildFactionCard({ factionId, event });
        return card?.id === cardId ? card : null;
      }
    }
    return null;
  }

  _fmtFactionChoices(event, factionId) {
    const result = {};
    for (const [dir, ch] of Object.entries(event.choices || {})) {
      result[dir] = {
        text: ch.text || '...',
        effects: ch.effects || {},
        factionEffects: {
          factionId,
          reputationDelta: ch.reputationDelta || 0,
          subfactionId: ch.subfactionId || null,
          subReputationDelta: ch.subReputationDelta || 0,
          undercurrentId: ch.undercurrentId || null,
          undercurrentStageChange: ch.undercurrentStageChange || 0,
          globalFlag: ch.globalFlag || null
        },
        // Faction data may name an existing encounter, but never owns its
        // enemy, rewards or outcome links. GameLogic resolves this ID through
        // CardSystem before it can create a warning card.
        ...(ch.triggerCombat === true ? {
          triggerCombat: true,
          combatEncounterId: ch.combatEncounterId || null,
          ...(ch.entryEffects ? { entryEffects: JSON.parse(JSON.stringify(ch.entryEffects)) } : {}),
          ...(ch.combatOutcomePresentation
            ? { combatOutcomePresentation: JSON.parse(JSON.stringify(ch.combatOutcomePresentation)) }
            : {})
        } : {})
      };
    }
    return result;
  }

  // ==========================================
  // 选择结果应用
  // ==========================================

  /**
   * 玩家做出势力事件选择后调用
   */
  applyChoice(choice) {
    if (!choice || !choice.factionEffects) return;

    const fe = choice.factionEffects;

    // 势力声望
    if (fe.reputationDelta && fe.factionId) {
      this.addReputation(fe.factionId, fe.reputationDelta, { persist: false });
    }

    // 子派系声望
    if (fe.subReputationDelta && fe.subfactionId) {
      this.addReputation(fe.subfactionId, fe.subReputationDelta, { persist: false });
    }

    // 暗流推进
    if (fe.undercurrentId && fe.undercurrentStageChange && this.undercurrents[fe.undercurrentId]) {
      const uc = this.undercurrents[fe.undercurrentId];
      const oldStage = uc.stage;
      uc.stage = Math.max(0, Math.min(uc.maxStage || 5, uc.stage + fe.undercurrentStageChange));

      // 【因果种子】factionUprising：暗流 stage >= 2 时种下势力冲突种子
      if (uc.stage >= 2 && oldStage < 2) {
        if (typeof karmaSystem !== 'undefined' && karmaSystem) {
          karmaSystem.plantSeed({
            id: 'factionUprising',
            description: `${uc.name}——势力矛盾已经爆发，你被卷入其中。`,
            originCard: 'faction_event',
            magnitude: uc.stage,
            factionId: fe.undercurrentId
          });
        }
      }

      eventBus.emit('faction:undercurrentChanged', {
        id: fe.undercurrentId,
        name: uc.name,
        stage: uc.stage
      });
    }

    // 全局标记
    if (fe.globalFlag) {
      this.globalFlags[fe.globalFlag] = true;
    }
    this._persistProgress();
  }

  // ==========================================
  // 声望操作
  // ==========================================

  /**
   * 增加势力声望
   */
  addReputation(factionId, delta, { persist = true } = {}) {
    const old = this.reputations[factionId] || 0;
    this.reputations[factionId] = Math.max(-100, Math.min(100, old + delta));

    if (this.reputations[factionId] !== old) {
      eventBus.emit('faction:reputationChanged', {
        factionId,
        oldValue: old,
        newValue: this.reputations[factionId],
        delta: this.reputations[factionId] - old,
        factionName: this._getFactionName(factionId)
      });
    }
    if (persist) this._persistProgress();
  }

  /**
   * 获取势力声望等级
   */
  getReputationLevel(factionId) {
    const rep = this.reputations[factionId] || 0;
    if (rep >= 80) return '崇敬';
    if (rep >= 50) return '尊敬';
    if (rep >= 20) return '友善';
    if (rep >= 0) return '中立';
    if (rep >= -20) return '冷淡';
    if (rep >= -50) return '敌视';
    return '仇恨';
  }

  // ==========================================
  // 面板数据
  // ==========================================

  _onGetStatus(data) {
    const result = {};
    for (const [factionId, faction] of this.factions) {
      result[factionId] = {
        name: faction.name,
        icon: faction.icon || '',
        reputation: this.reputations[factionId] || 0,
        level: this.getReputationLevel(factionId),
        subfactions: (faction.subfactions || []).map(sub => ({
          id: sub.id,
          name: sub.name,
          reputation: this.reputations[sub.id] || 0,
          level: this.getReputationLevel(sub.id)
        }))
      };

      // 暗流状态
      if (faction.undercurrentId && this.undercurrents[faction.undercurrentId]) {
        const uc = this.undercurrents[faction.undercurrentId];
        result[factionId].undercurrent = {
          id: uc.id,
          name: uc.name,
          stage: uc.stage,
          maxStage: uc.maxStage || 5,
          description: uc.stages ? (uc.stages[uc.stage] || '') : ''
        };
      }
    }

    eventBus.emit('faction:status', result);
  }

  // ==========================================
  // 境界突破时的势力反应
  // ==========================================

  /**
   * 境界突破时检查势力事件
   */
  onRealmAdvance(newRealm) {
    // 金丹期：可能触发论剑大会请柬
    if (newRealm === 'golden' && gameState.path === 'sword') {
      this.globalFlags['faction_swordDebate_available'] = true;
    }

    // 元婴期：禁药堂秘密泄露
    if (newRealm === 'nascent' && gameState.path === 'pill') {
      this.globalFlags['faction_forbiddenPill_available'] = true;
    }
    this._persistProgress();
  }

  // ==========================================
  // 工具方法
  // ==========================================

  _getFactionName(factionId) {
    const faction = this.factions.get(factionId);
    if (faction) return faction.name;

    // 检查子派系
    for (const [id, f] of this.factions) {
      if (f.subfactions) {
        for (const sub of f.subfactions) {
          if (sub.id === factionId) return sub.name;
        }
      }
    }
    return factionId;
  }

  _onReset() {
    this._resetForNewLife({ useLegacy: true });
    gameState.factionProgress = this.exportProgress();
  }

  _isEventLocationEligible(event) {
    if (event?.requiresPlayerPresence !== true || !event.location) return true;
    const current = gameState?.currentLocation || null;
    if (typeof narrativeLedger !== 'undefined' && narrativeLedger
      && typeof narrativeLedger.areLocationsCompatible === 'function') {
      return narrativeLedger.areLocationsCompatible(current, event.location);
    }
    const authored = Array.isArray(event.location) ? event.location : [event.location];
    return authored.includes(current);
  }

  getFaction(factionId) {
    return this.factions.get(factionId) || null;
  }

  getAllFactions() {
    return Array.from(this.factions.entries()).map(([id, f]) => ({
      id,
      name: f.name,
      reputation: this.reputations[id] || 0,
      level: this.getReputationLevel(id)
    }));
  }
}

// 全局单例
const factionSystem = new FactionSystem();

if (typeof window !== 'undefined') {
  window.FactionSystem = FactionSystem;
  window.factionSystem = factionSystem;
}
if (typeof global !== 'undefined') {
  global.FactionSystem = FactionSystem;
  global.factionSystem = factionSystem;
}
if (typeof module !== 'undefined' && module.exports) {
  module.exports = FactionSystem;
  module.exports.FactionSystem = FactionSystem;
  module.exports.factionSystem = factionSystem;
}
