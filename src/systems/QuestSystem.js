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
  constructor() {
    this.quests = new Map();        // questId → quest定义
    this.questCards = new Map();    // questId → [cards]
    this.activeQuests = [];        // [{ questId, step, startedAt }]
    this.completedQuests = new Set();

    this._pendingEntryCard = null;
  }

  /**
   * 加载支线数据
   */
  init() {
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

  // ============ 触发检测 ============

  _onCheckTrigger() {
    // 如果已有进行中的支线，检查当前卡是否该出
    if (this.activeQuests.length > 0) return;

    // 确保不重复检查
    if (this._pendingEntryCard) return;

    // 遍历所有已加载的支线
    for (const [questId, quest] of this.quests) {
      if (this.completedQuests.has(questId)) continue;
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

    // 检查属性条件
    if (trigger.requiredAttributes) {
      for (const [attr, minValue] of Object.entries(trigger.requiredAttributes)) {
        if (gameState.getAttribute(attr) < minValue) return false;
      }
    }

    return true;
  }

  _activateQuest(quest) {
    this.activeQuests.push({
      questId: quest.id,
      step: 0,
      startedAt: gameState.turn
    });

    // 设置入口卡（由 CardSystem 在优先级70中提取）
    const entryCard = cardSystem.getCard(quest.entryCardId);
    this._pendingEntryCard = entryCard;

    gameState.setFlag('quest_' + quest.id + '_active', true);
    gameState.setFlag('quest_' + quest.id + '_step', 0);

    eventBus.emit('quest:triggered', {
      questId: quest.id,
      questName: quest.name,
      entryCardId: quest.entryCardId
    });
  }

  // ============ CardSystem 桥接 ============

  _onRequestCurrentCard() {
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
      // 支线完成但未结算
      this._completeQuest(active.questId);
      eventBus.emit('quest:currentCard', { card: null });
      return;
    }

    const currentCard = cards[active.step];
    eventBus.emit('quest:currentCard', { card: currentCard });
  }

  _onRequestEntryCard() {
    if (this._pendingEntryCard) {
      eventBus.emit('quest:entryCard', { card: this._pendingEntryCard });
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
  advanceQuest(direction, card) {
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
      // 支线结束
      this._completeQuest(active.questId);
      return;
    } else {
      // 默认推进
      active.step++;
      gameState.setFlag('quest_' + active.questId + '_step', active.step);
    }

    // 检查是否已完成所有卡牌
    const cards = this.questCards.get(active.questId);
    if (active.step >= cards.length) {
      this._completeQuest(active.questId);
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
  }

  // ============ 结算 ============

  _completeQuest(questId) {
    const quest = this.quests.get(questId);
    if (!quest) return;

    this.activeQuests = this.activeQuests.filter(q => q.questId !== questId);
    this.completedQuests.add(questId);

    gameState.setFlag(questId + 'Completed', true);
    gameState.setFlag('quest_' + questId + '_active', false);

    // 发放奖励
    if (quest.rewardOnComplete) {
      this._grantReward(quest.rewardOnComplete);
    }

    // 【环环相扣：Quest→Faction】支线完成影响势力声望
    if (quest.factionRewards) {
      for (const [factionId, delta] of Object.entries(quest.factionRewards)) {
        if (typeof factionSystem !== 'undefined' && factionSystem) {
          factionSystem.addReputation(factionId, delta);
        }
      }
    }

    eventBus.emit('quest:completed', {
      questId,
      questName: quest.name
    });
  }

  _grantReward(reward) {
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
        karmaSystem.plantSeed(seed);
      }
    }
  }

  // ============ 状态重置 ============

  _onReset() {
    this.activeQuests = [];
    this.completedQuests = new Set();
    this._pendingEntryCard = null;
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
    if (this.completedQuests.has(questId)) return 'completed';
    const active = this.activeQuests.find(q => q.questId === questId);
    if (active) return 'active';
    if (this.quests.has(questId)) return 'available';
    return 'unknown';
  }

  getAllCompletedQuests() {
    return Array.from(this.completedQuests);
  }
}

// 全局单例
const questSystem = new QuestSystem();
