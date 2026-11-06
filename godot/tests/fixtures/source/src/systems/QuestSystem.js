/**
 * QuestSystem - 支线任务引擎
 *
 * 管理支线链的触发、推进、结算。
 * 每条支线由一系列卡牌组成，按链式顺序推进。
 *
 * 工作流程：
 *   1. 每轮 CardSystem.draw() 时，触发 quest:checkTrigger 事件
 *   2. QuestSystem 检查是否有满足条件的支线可触发
 *   3. 如有，将入口卡返回给 CardSystem
 *   4. 玩家选择后，QuestSystem 记录推进状态
 *   5. 完成链中所有卡牌后，结算奖励
 */
class QuestSystem {
  static SAVE_SCHEMA_VERSION = 3;
  constructor() {
    this.quests = new Map();        // questId → quest定义
    this.questCards = new Map();    // questId → [cards]
    this.activeQuests = [];        // [{ questId, step, startedAt }]
    // `completedQuests` is a success-only causal fact.  Terminal failures use
    // the separate closed set so trigger prevention never masquerades as a
    // completed task to a narrative consumer.
    this.completedQuests = new Set();
    this.closedQuests = new Set();
    this.questOutcomes = new Map(); // questId -> completed | failed | abandoned

    this._pendingEntryCard = null;
    this._pendingTriggerEvents = [];
  }

  /**
   * 加载支线数据
   */
  init() {
    // 从 localStorage 恢复进行中的支线（持久化方案A）
    this._loadActiveQuests();
    // 如果没有任何进行中的支线，清理可能残留的 quest_*_active flag（孤立flag清理方案B）
    if (this.activeQuests.length === 0) {
      this._cleanupOrphanFlags();
    }

    // 监听 CardSystem 的抽卡流程事件
    eventBus.on('quest:checkTrigger', () => this._onCheckTrigger());
    eventBus.on('quest:requestCurrentCard', () => this._onRequestCurrentCard());
    eventBus.on('quest:requestEntryCard', () => this._onRequestEntryCard());
    eventBus.on('state:reset', () => this._onReset());
  }

  /**
   * 加载一条支线的数据
   * @param {Object} questPackage - { quest, cards }
   */
  loadQuest(questPackage) {
    if (!questPackage || !questPackage.quest) return;

    const quest = questPackage.quest;
    this.quests.set(quest.id, quest);
    this.questCards.set(quest.id, questPackage.cards || []);

    // 将所有卡牌注册到 CardSystem（通过 DataLoader）
    if (questPackage.cards) {
      for (const card of questPackage.cards) {
        cardSystem.cardCache.set(card.id, card);
      }
    }
  }

  projectCard(card) {
    if (!card || !Array.isArray(card.stateVariants)) return card;
    if (card.questId) {
      const active = this.activeQuests.find(item => item.questId === card.questId);
      const authored = active && this.questCards.get(card.questId)?.[active.step];
      if (authored?.id !== card.id) return card;
    } else if (card.type !== 'KARMA') {
      return card;
    }
    const variant = card.stateVariants.find(item =>
      typeof item?.whenFlag === 'string' && gameState.hasFlag(item.whenFlag)
    );
    if (!variant) return card;
    return {
      ...card,
      ...(typeof variant.title === 'string' ? { title: variant.title } : {}),
      ...(typeof variant.description === 'string' ? { description: variant.description } : {}),
      ...(typeof variant.sceneImage === 'string' ? { sceneImage: variant.sceneImage } : {}),
      ...(variant.artDirection && typeof variant.artDirection === 'object'
        ? { artDirection: variant.artDirection }
        : {}),
      ...(variant.choices && typeof variant.choices === 'object'
        ? { choices: variant.choices }
        : {})
    };
  }

  /** 所有任务包加载后，清理旧存档中的失效 ID、重复记录和越界步骤。 */
  finalizeLoadedState() {
    const normalized = [];
    const seen = new Set();
    for (const saved of this.activeQuests) {
      const questId = saved?.questId;
      if (!questId || seen.has(questId) || this.closedQuests.has(questId)) continue;
      const cards = this.questCards.get(questId);
      if (!this.quests.has(questId) || !Array.isArray(cards) || cards.length === 0) continue;
      const step = Math.max(0, Math.floor(Number(saved.step) || 0));
      if (step >= cards.length) {
        // An old malformed progress record has no authored terminal choice.
        // Do not invent a success fact or grant success rewards on load.
        this._markQuestClosed(questId, 'abandoned');
        continue;
      }
      seen.add(questId);
      normalized.push({ questId, step, startedAt: Math.max(0, Number(saved.startedAt) || 0) });
    }
    // 当前引擎一次只调度一条支线；旧存档若并行记录多条，只保留最早的一条。
    normalized.sort((a, b) => a.startedAt - b.startedAt);
    this.activeQuests = normalized.slice(0, 1);
    this.closedQuests = new Set([...this.closedQuests].filter(id => this.quests.has(id)));
    this.completedQuests = new Set(
      [...this.completedQuests].filter(id => this.closedQuests.has(id) && this.quests.has(id))
    );
    this.questOutcomes = new Map(
      [...this.questOutcomes].filter(([id]) => this.closedQuests.has(id) && this.quests.has(id))
    );
    this._saveActiveQuests();
  }

  // ============ 触发检测 ============

  _onCheckTrigger() {
    // 如果已有进行中的支线，检查当前卡是否该出
    if (this.activeQuests.length > 0) return;

    // 确保不重复检查
    if (this._pendingEntryCard) return;

    // 遍历所有已加载的支线
    for (const [questId, quest] of this.quests) {
      if (this.closedQuests.has(questId)) continue;
      if (!this._canTrigger(quest)) continue;

      // 激活支线
      this._activateQuest(quest);
      return;
    }
  }

  _canTrigger(quest) {
    const trigger = quest.trigger;
    if (!trigger) return false;

    // 检查起始境界 (支持 quest.startRealm 或 trigger.startRealm)
    const startRealm = quest.startRealm || (trigger.startRealm || null);
    if (startRealm && startRealm !== gameState.realm) return false;

    // 检查功法限制 (支持 quest.pathRestriction 或 trigger.pathRestriction)
    const pathRestriction = quest.pathRestriction || (trigger.pathRestriction || null);
    if (pathRestriction && pathRestriction !== gameState.path) return false;

    // 检查最小轮数
    if (trigger.minTurn && gameState.turn < trigger.minTurn) return false;

    // 检查 requiredFlags
    if (trigger.requiredFlags && !gameState.checkFlags(trigger.requiredFlags)) return false;

    // 检查 forbiddenFlags（已完成标记）
    if (trigger.forbiddenFlags) {
      for (const flag of trigger.forbiddenFlags) {
        if (gameState.hasFlag(flag)) return false;
      }
    }
    if (Array.isArray(trigger.forbiddenCardIds) && trigger.forbiddenCardIds.length > 0) {
      const visited = new Set([
        ...(Array.isArray(gameState.cardsPlayed) ? gameState.cardsPlayed : []),
        ...(Array.isArray(gameState.choiceHistory)
          ? gameState.choiceHistory.map(entry => entry?.cardId)
          : [])
      ]);
      if (trigger.forbiddenCardIds.some(cardId => visited.has(cardId))) return false;
    }

    // 检查属性条件
    if (trigger.requiredAttributes) {
      for (const [attr, minValue] of Object.entries(trigger.requiredAttributes)) {
        if (gameState.getAttribute(attr) < minValue) return false;
      }
    }

    return true;
  }

  _activateQuest(quest) {
    const entryCard = cardSystem.getCard(quest.entryCardId);
    if (!entryCard) {
      console.warn(`[QuestSystem] 支线 ${quest.id} 缺少入口卡 ${quest.entryCardId}，已拒绝激活以避免流程卡死。`);
      return false;
    }

    const beforeRuntime = this.captureRollbackState();
    const beforeQuestState = gameState.unlocks?.questState == null
      ? gameState.unlocks?.questState ?? null
      : JSON.parse(JSON.stringify(gameState.unlocks.questState));
    const beforeUnlockFlags = gameState.unlocks?.flags
      ? { ...gameState.unlocks.flags }
      : null;
    const activeFlag = 'quest_' + quest.id + '_active';
    const stepFlag = 'quest_' + quest.id + '_step';
    const beforeFlags = [activeFlag, stepFlag].map(key => ({
      key,
      hasRuntime: Object.prototype.hasOwnProperty.call(gameState.flags || {}, key),
      runtimeValue: gameState.flags?.[key]
    }));

    this.activeQuests.push({
      questId: quest.id,
      step: 0,
      startedAt: gameState.turn
    });
    gameState.setFlag(activeFlag, true);
    gameState.setFlag(stepFlag, 0);

    if (!this._saveActiveQuests()) {
      this.restoreRollbackState(beforeRuntime);
      if (gameState.unlocks) {
        gameState.unlocks.questState = beforeQuestState;
        gameState.unlocks.flags = beforeUnlockFlags;
      }
      for (const flag of beforeFlags) {
        if (flag.hasRuntime) gameState.flags[flag.key] = flag.runtimeValue;
        else delete gameState.flags[flag.key];
      }
      return false;
    }

    // Only a durable (or transaction-deferred) activation may enter CardSystem.
    this._pendingEntryCard = entryCard;

    const triggerEvent = {
      questId: quest.id,
      questName: quest.name,
      entryCardId: quest.entryCardId
    };
    if (gameState._causalTransaction) {
      // The quest record is only an in-memory projection until the owning
      // decision writes its checkpoint. A rejected write must not announce it.
      this._pendingTriggerEvents.push(triggerEvent);
    } else {
      eventBus.emit('quest:triggered', triggerEvent);
    }
    return true;
  }

  publishCommittedTriggers() {
    if (gameState._causalTransaction) return false;
    const committed = this._pendingTriggerEvents.splice(0);
    for (const event of committed) eventBus.emit('quest:triggered', event);
    return true;
  }

  // ============ CardSystem 桥接 ============

  _onRequestCurrentCard() {
    // 新任务已激活但入口卡尚未被 CardSystem 消费时，优先让入口卡只出现一次。
    // 否则优先级80会先返回 step=0，同一轮优先级70中的 pending 仍会留到下轮，
    // 造成“白狐受困”等入口剧情连续重复。
    if (this._pendingEntryCard) {
      eventBus.emit('quest:currentCard', { card: null });
      return;
    }

    if (this.activeQuests.length === 0) {
      eventBus.emit('quest:currentCard', { card: null });
      return;
    }

    const active = this.activeQuests[0];
    const quest = this.quests.get(active.questId);
    if (!quest) {
      eventBus.emit('quest:currentCard', { card: null });
      return;
    }

    const cards = this.questCards.get(active.questId);
    if (!cards || active.step >= cards.length) {
      // A task may only complete through an authored `questOutcome: completed`.
      // Corrupt/migrated progress is closed safely instead of paid as success.
      this._failQuest(active.questId, 'abandoned', { reason: 'missing_terminal_outcome' });
      eventBus.emit('quest:currentCard', { card: null });
      return;
    }

    const currentCard = this.projectCard(cards[active.step]);
    eventBus.emit('quest:currentCard', { card: currentCard });
  }

  _onRequestEntryCard() {
    if (this._pendingEntryCard) {
      eventBus.emit('quest:entryCard', { card: this.projectCard(this._pendingEntryCard) });
      this._pendingEntryCard = null;
    } else {
      eventBus.emit('quest:entryCard', { card: null });
    }
  }

  // ============ 推进支线 ============

  /**
   * 玩家做出选择后，推进支线
   * @param {string} direction - 'left' | 'right' | 'up' | 'down'
   * @param {Object} card - 当前的支线卡牌
   */
  advanceQuest(direction, card, outcome = null) {
    if (this.activeQuests.length === 0) return;

    const active = this.activeQuests[0];
    const choice = card.choices[direction];
    if (!choice) return;

    // 更新步骤
    if (choice.questNext) {
      // 分支跳转到指定卡
      const cards = this.questCards.get(active.questId);
      const nextIndex = cards.findIndex(c => c.id === choice.questNext);
      if (nextIndex >= 0) {
        active.step = nextIndex;
        gameState.setFlag('quest_' + active.questId + '_step', nextIndex);
      } else {
        active.step++;
      }
    } else if (choice.questEnd) {
      const terminalOutcome = choice.questOutcome;
      const provenance = {
        originCard: card.id,
        originChoice: direction,
        originOutcome: outcome || terminalOutcome || 'invalid_terminal_outcome'
      };
      if (terminalOutcome === 'completed') {
        this._completeQuest(active.questId, provenance);
      } else if (terminalOutcome === 'failed' || terminalOutcome === 'abandoned') {
        this._failQuest(active.questId, terminalOutcome, provenance);
      } else {
        // Content must author a terminal meaning.  Fail closed so an omitted
        // field cannot silently turn a refusal into a rewarded completion.
        console.warn(`[QuestSystem] 支线 ${active.questId} 的终止分支缺少有效 questOutcome，按 abandoned 关闭。`);
        this._failQuest(active.questId, 'abandoned', provenance);
      }
      return;
    } else {
      // 默认推进
      active.step++;
      gameState.setFlag('quest_' + active.questId + '_step', active.step);
    }

    // 检查是否已完成所有卡牌
    const cards = this.questCards.get(active.questId);
    if (active.step >= cards.length) {
      this._failQuest(active.questId, 'abandoned', {
        originCard: card.id,
        originChoice: direction,
        originOutcome: outcome || 'missing_terminal_outcome'
      });
      return;
    }

    // 将下一张卡的ID暂存到 active 对象，供 _onRequestCurrentCard 直接使用
    const nextCard = cards[active.step];
    if (nextCard) {
      active._pendingNextCardId = nextCard.id;
    }

    eventBus.emit('quest:advanced', {
      questId: active.questId,
      step: active.step,
      nextCardId: nextCard ? nextCard.id : null,
      totalSteps: cards.length
    });

    this._saveActiveQuests();
  }

  // ============ 结算 ============

  _markQuestClosed(questId, outcome) {
    const terminalOutcome = ['completed', 'failed', 'abandoned'].includes(outcome)
      ? outcome
      : 'abandoned';
    this.closedQuests.add(questId);
    this.questOutcomes.set(questId, terminalOutcome);
    if (terminalOutcome === 'completed') {
      this.completedQuests.add(questId);
      gameState.setFlag(questId + 'Completed', true);
    } else {
      this.completedQuests.delete(questId);
      gameState.setFlag(questId + 'Completed', false);
      gameState.setFlag('quest_' + questId + '_' + terminalOutcome, true);
    }
    gameState.setFlag('quest_' + questId + '_active', false);
  }

  _completeQuest(questId, provenance = {}) {
    const quest = this.quests.get(questId);
    if (!quest || this.closedQuests.has(questId)) return false;

    this.activeQuests = this.activeQuests.filter(q => q.questId !== questId);
    this._markQuestClosed(questId, 'completed');

    // 发放奖励
    if (quest.rewardOnComplete) {
      this._grantReward(quest.rewardOnComplete, {
        originQuest: questId,
        ...provenance
      });
    }

    // 【环环相扣：Quest→Faction】支线完成影响势力声望
    if (quest.factionRewards) {
      for (const [factionId, delta] of Object.entries(quest.factionRewards)) {
        if (typeof factionSystem !== 'undefined' && factionSystem) {
          factionSystem.addReputation(factionId, delta);
        }
      }
    }

    this._saveActiveQuests();

    eventBus.emit('quest:completed', {
      questId,
      questName: quest.name
    });
    return true;
  }

  _failQuest(questId, outcome = 'failed', provenance = {}) {
    const quest = this.quests.get(questId);
    if (!quest || this.closedQuests.has(questId)) return false;

    this.activeQuests = this.activeQuests.filter(q => q.questId !== questId);
    this._markQuestClosed(questId, outcome);

    if (quest.rewardOnFail) {
      this._grantReward(quest.rewardOnFail, {
        originQuest: questId,
        originOutcome: outcome,
        ...provenance
      });
    }

    this._saveActiveQuests();
    eventBus.emit('quest:failed', {
      questId,
      questName: quest.name,
      outcome
    });
    return true;
  }

  _grantReward(reward, provenance = {}) {
    // 属性奖励
    if (reward.attributes) {
      for (const [attr, delta] of Object.entries(reward.attributes)) {
        if (['cultivation', 'daoHeart', 'karmaGood', 'karmaBad', 'fortune', 'health'].includes(attr)) {
          gameState.addAttribute(attr, delta);
        }
      }
    }

    // 资源奖励
    if (reward.resources) {
      for (const [type, keyOrDelta] of Object.entries(reward.resources)) {
        if (Array.isArray(keyOrDelta)) {
          for (const item of keyOrDelta) {
            gameState.addResource(type, item, 1);
          }
        } else {
          gameState.addResource(type, null, keyOrDelta);
        }
      }
    }

    // Flags 设置
    if (reward.flags) {
      for (const flag of reward.flags) {
        gameState.setFlag(flag, true);
      }
    }

    // 因果种子
    if (reward.karmaSeeds) {
      for (const seed of reward.karmaSeeds) {
        karmaSystem.plantSeed({
          ...provenance,
          ...seed
        });
      }
    }
  }

  // ============ 状态重置 ============

  _onReset() {
    this.activeQuests = [];
    this._pendingEntryCard = null;
    this._pendingTriggerEvents = [];
    this._cleanupOrphanFlags();
    this._saveActiveQuests();
  }

  // ============ 持久化与清理 ============

  _saveActiveQuests() {
    try {
      const data = {
        saveVersion: QuestSystem.SAVE_SCHEMA_VERSION,
        activeQuests: this.activeQuests,
        completedQuests: Array.from(this.completedQuests),
        closedQuests: Array.from(this.closedQuests),
        questOutcomes: Object.fromEntries(this.questOutcomes)
      };
      if (typeof gameState.persistQuestState !== 'function') return false;
      return gameState.persistQuestState(data);
    } catch (e) {
      // localStorage 不可用时静默失败
      return false;
    }
  }

  /** Preserve the live projection as well as the persisted quest record.
   * A rejected top-level decision must be retryable without reloading.
   */
  captureRollbackState() {
    return {
      activeQuests: this.activeQuests.map(active => ({ ...active })),
      completedQuests: [...this.completedQuests],
      closedQuests: [...this.closedQuests],
      questOutcomes: [...this.questOutcomes],
      pendingEntryCard: this._pendingEntryCard,
      pendingTriggerEvents: this._pendingTriggerEvents.map(event => ({ ...event }))
    };
  }

  restoreRollbackState(snapshot) {
    if (!snapshot || typeof snapshot !== 'object') return false;
    this.activeQuests = (snapshot.activeQuests || []).map(active => ({ ...active }));
    this.completedQuests = new Set(snapshot.completedQuests || []);
    this.closedQuests = new Set(snapshot.closedQuests || []);
    this.questOutcomes = new Map(snapshot.questOutcomes || []);
    this._pendingEntryCard = snapshot.pendingEntryCard || null;
    this._pendingTriggerEvents = (snapshot.pendingTriggerEvents || []).map(event => ({ ...event }));
    return true;
  }

  _loadActiveQuests() {
    let migratedLegacySidecar = false;
    try {
      let parsed = typeof gameState.getQuestState === 'function'
        ? gameState.getQuestState()
        : null;
      const activeSlotId = typeof gameState.getActiveSaveSlotId === 'function'
        ? gameState.getActiveSaveSlotId()
        : 'slot_1';

      // v2 以前使用无槽位 sidecar。它只可能属于旧的一号玉简；二、三号玉简
      // 绝不能认领该记录。只有核心存档成功接管后才删除旧 key。
      if (!parsed && activeSlotId === 'slot_1') {
        const legacySaved = localStorage.getItem('xiuxian_active_quests');
        if (legacySaved) {
          parsed = JSON.parse(legacySaved);
          migratedLegacySidecar = true;
        }
      }

      if (parsed) {
        const legacyActive = Array.isArray(parsed.activeQuests)
          ? parsed.activeQuests
          : (parsed.activeQuest ? [parsed.activeQuest] : []);
        this.activeQuests = legacyActive.map(item => ({
          questId: item?.questId || item?.id,
          step: Math.max(0, Math.floor(Number(item?.step) || 0)),
          startedAt: Math.max(0, Number(item?.startedAt) || 0)
        }));
        const outcomes = parsed.questOutcomes && typeof parsed.questOutcomes === 'object'
          ? parsed.questOutcomes
          : {};
        for (const [questId, outcome] of Object.entries(outcomes)) {
          if (!['completed', 'failed', 'abandoned'].includes(outcome)) continue;
          this.closedQuests.add(questId);
          this.questOutcomes.set(questId, outcome);
          if (outcome === 'completed') this.completedQuests.add(questId);
        }

        const legacyClosed = Array.isArray(parsed.closedQuests) ? parsed.closedQuests : [];
        for (const questId of legacyClosed) {
          if (typeof questId !== 'string' || this.closedQuests.has(questId)) continue;
          const outcome = gameState.hasFlag(questId + 'Completed')
            ? 'completed'
            : (gameState.hasFlag('quest_' + questId + '_failed') ? 'failed' : 'abandoned');
          this.closedQuests.add(questId);
          this.questOutcomes.set(questId, outcome);
          if (outcome === 'completed') this.completedQuests.add(questId);
        }

        // v2 overloaded `completedQuests` with every terminal state.  Migrate
        // unambiguous successes only; an ambiguous legacy ID remains closed
        // but cannot become a future causal fact by accident.
        const legacyCompleted = Array.isArray(parsed.completedQuests) ? parsed.completedQuests : [];
        for (const questId of legacyCompleted) {
          if (typeof questId !== 'string' || this.closedQuests.has(questId)) continue;
          const outcome = gameState.hasFlag(questId + 'Completed')
            ? 'completed'
            : (gameState.hasFlag('quest_' + questId + '_failed') ? 'failed' : 'abandoned');
          this.closedQuests.add(questId);
          this.questOutcomes.set(questId, outcome);
          if (outcome === 'completed') this.completedQuests.add(questId);
        }

        // `questOutcomes` is the v3 source of truth.  A v2 save can carry a
        // stale `${questId}Completed` flag from the era when every terminal
        // state lived in `completedQuests`.  Reconcile the derived flag before
        // any thread evaluates it, otherwise a recorded failure can unlock a
        // success-only narrative consumer after reload.
        this._reconcileQuestCompletionFacts();
      }

      if (migratedLegacySidecar && this._saveActiveQuests()) {
        localStorage.removeItem('xiuxian_active_quests');
      }
    } catch (e) {
      // 解析失败时保持默认空状态
    }
  }

  _cleanupOrphanFlags() {
    const flags = gameState.flags || {};
    for (const key of Object.keys(flags)) {
      if (key.startsWith('quest_') && key.endsWith('_active') && flags[key]) {
        gameState.setFlag(key, false);
      }
    }
  }

  _reconcileQuestCompletionFacts() {
    for (const [questId, outcome] of this.questOutcomes) {
      const completed = outcome === 'completed';
      if (completed) {
        this.completedQuests.add(questId);
      } else {
        this.completedQuests.delete(questId);
      }
      gameState.setFlag(questId + 'Completed', completed);
    }
  }

  // ============ 查询 ============

  getActiveQuest() {
    return this.activeQuests.length > 0 ? this.activeQuests[0] : null;
  }

  getQuest(questId) {
    return this.quests.get(questId) || null;
  }

  isQuestCompleted(questId) {
    return this.completedQuests.has(questId);
  }

  getQuestStatus(questId) {
    const active = this.activeQuests.find(q => q.questId === questId);
    if (active) return 'active';
    if (this.questOutcomes.has(questId)) return this.questOutcomes.get(questId);
    if (this.completedQuests.has(questId)) return 'completed';
    if (this.quests.has(questId)) return 'available';
    return 'unknown';
  }

  getAllCompletedQuests() {
    return Array.from(this.completedQuests);
  }
}

// 全局单例
const questSystem = new QuestSystem();
