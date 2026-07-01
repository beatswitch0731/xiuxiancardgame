/**
 * StoryThreadEngine — 故事线程引擎 v1.0
 *
 * 解决"选了卡但没有因果故事感"的核心问题。
 *
 * 四层职责：
 *   1. ThreadManager      — 线程生命周期（触发/推进/分支/完成）
 *   2. ThreadInjector     — 将线程卡注入主卡牌流（优先级52）
 *   3. ThreadJournal      — 玩家故事日志（可查看的叙事历史）
 *   4. ThreadKarmaBridge  — 线程结局 → 因果种子 → 新线程触发
 *
 * 设计原则：
 *   - 线程卡是对普通卡池的"叙事骨架"，不替代随机抽卡
 *   - 同时最多 2 条活跃线程，线程卡占比约 25%
 *   - 线程节点之间最少间隔 2 回合，给普通事件留空间
 *   - 触发条件宽松——让大多数线程在自然游戏中自然触发
 */
class StoryThreadEngine {
  constructor() {
    /** @type {Map<string, ThreadState>} 当前活跃线程 */
    this.activeThreads = new Map();

    /** @type {Set<string>} 已完成线程ID（防重复触发） */
    this.completedThreads = new Set();

    /** @type {Map<string, Object>} 已加载的线程定义 (threadId → threadDef) */
    this.threadDefs = new Map();

    /** @type {Array<Object>} 玩家故事日志 */
    this.threadJournal = [];

    /** @type {Set<string>} 本回合已触发的线程ID（防重复触发） */
    this._triggeredThisTurn = new Set();

    /** @type {Object} 配置 */
    this.config = {
      maxActiveThreads: 2,          // 同时最多活跃线程
      minTurnsBetweenNodes: 2,      // 线程节点之间最少间隔回合数
      injectionPriority: 52,        // 注入优先级（低于弧线高潮53，高于弧线推进51）
      threadTimeout: 25,            // 线程超时回合数（超时自动失败）
      maxThreadsPerRealm: 5,        // 每个境界最多线程数
      triggerCooldown: 4,           // 新线程触发冷却回合数
    };

    this._lastThreadTriggerTurn = 0;
    this._threadCardCount = 0;
    this._totalCardCount = 0;
  }

  // ============ 数据加载 ============

  /**
   * 加载一个境界的线程定义
   * @param {string} realm - 境界名
   * @param {Array<Object>} threads - 线程定义数组
   */
  loadThreads(realm, threads) {
    if (!threads || !Array.isArray(threads)) return;
    for (const thread of threads) {
      thread.realm = thread.realm || realm;
      this.threadDefs.set(thread.threadId, thread);
    }
  }

  /**
   * 从 JSON 数据加载线程
   * @param {Object} data - { threads: [...] }
   */
  loadThreadData(data) {
    if (!data || !data.threads) return;
    const realm = data.realm || 'qi';
    this.loadThreads(realm, data.threads);
  }

  // ============ 每回合检查 ============

  /**
   * 游戏回合推进时调用
   * 1. 检查新线程触发条件
   * 2. 清理超时线程
   * 3. 推进活跃线程
   */
  tick(gameState) {
    this._totalCardCount++;
    this._resetTurnFlags();

    // 清理超时线程
    this._cleanupTimeout(gameState.turn);

    // 检查新触发
    this._checkAllTriggers(gameState);
  }

  _resetTurnFlags() {
    this._triggeredThisTurn.clear();
  }

  _cleanupTimeout(turn) {
    for (const [threadId, state] of this.activeThreads) {
      if (turn - state.startedAtTurn > this.config.threadTimeout) {
        this._log(`[线程] "${this._threadTitle(threadId)}" 超时 —— 时机已过。`);
        this.activeThreads.delete(threadId);
        this.completedThreads.add(threadId);
        // 记录到日志但不给奖励
        this._addJournalEntry(threadId, 'timeout', '时机已过，此线不再推进。');
      }
    }
  }

  // ============ 触发检测 ============

  /**
   * 检查所有未完成/未激活的线程触发条件
   */
  _checkAllTriggers(gameState) {
    // 已达最大活跃线程数
    if (this.activeThreads.size >= this.config.maxActiveThreads) return;

    // 触发冷却
    if (gameState.turn - this._lastThreadTriggerTurn < this.config.triggerCooldown) return;

    for (const [threadId, def] of this.threadDefs) {
      if (this.activeThreads.has(threadId)) continue;
      if (this.completedThreads.has(threadId)) continue;
      if (this._triggeredThisTurn.has(threadId)) continue;

      // 境界检查
      if (def.realm && def.realm !== gameState.realm) continue;

      // 触发条件检查
      if (this._evaluateTrigger(def.trigger, gameState)) {
        this._startThread(threadId, def, gameState);
        this._triggeredThisTurn.add(threadId);
        this._lastThreadTriggerTurn = gameState.turn;

        if (this.activeThreads.size >= this.config.maxActiveThreads) break;
      }
    }
  }

  /**
   * 评估触发条件
   * @param {Object} trigger
   * @param {Object} gameState
   * @returns {boolean}
   */
  _evaluateTrigger(trigger, gameState) {
    if (!trigger) return false;

    switch (trigger.type) {
      case 'choice_match':
        return this._checkChoiceMatch(trigger, gameState);
      case 'karma_sprout':
        return this._checkKarmaSprout(trigger, gameState);
      case 'state_threshold':
        return this._checkStateThreshold(trigger, gameState);
      case 'npc_affection':
        return this._checkNpcAffection(trigger, gameState);
      case 'realm_enter':
        return gameState.realm === trigger.realm && gameState.turn > (trigger.minTurn || 0);
      case 'tag_chain':
        return this._checkTagChain(trigger, gameState);
      case 'random_chance':
        return Math.random() < (trigger.chance || 0.1);
      case 'turn_count':
        return gameState.turn >= (trigger.minTurn || 0) &&
               (trigger.maxTurn === undefined || gameState.turn <= trigger.maxTurn);
      default:
        return false;
    }
  }

  _checkChoiceMatch(trigger, gameState) {
    // 玩家在特定卡上做了特定选择
    const hist = gameState.choiceHistory || [];
    for (let i = hist.length - 1; i >= 0; i--) {
      const entry = hist[i];
      if (entry.cardId === trigger.cardId) {
        if (trigger.direction && entry.direction !== trigger.direction) continue;
        // 延迟检查
        if (trigger.delay && gameState.turn - entry.turn < trigger.delay) continue;
        // 冷却检查
        if (trigger.cooldown && this.completedThreads.has(trigger.threadId)) continue;
        return true;
      }
    }
    return false;
  }

  _checkKarmaSprout(trigger, gameState) {
    const seeds = gameState.karmaSeeds || [];
    return seeds.some(s => s.id === trigger.karmaId && s.sprouted);
  }

  _checkStateThreshold(trigger, gameState) {
    for (const [attr, threshold] of Object.entries(trigger.thresholds || {})) {
      const value = gameState.attributes ? gameState.attributes[attr] : 0;
      if (value < threshold) return false;
    }
    return true;
  }

  _checkNpcAffection(trigger, gameState) {
    if (typeof npcSystem === 'undefined' || !npcSystem) return false;
    const aff = npcSystem.getAffection ? npcSystem.getAffection(trigger.npcId) : 0;
    return aff >= (trigger.minAffection || 10);
  }

  _checkTagChain(trigger, gameState) {
    const recentCards = (gameState.recentCardTags || []);
    const count = recentCards.filter(t => trigger.tags.includes(t)).length;
    return count >= (trigger.minCount || 2);
  }

  // ============ 线程生命周期 ============

  /**
   * 启动一个线程
   */
  _startThread(threadId, def, gameState) {
    const state = new ThreadState(threadId, gameState.turn);
    this.activeThreads.set(threadId, state);
    this._log(`[线程] 故事线开启：「${def.title}」—— ${def.description}`);
  }

  /**
   * 获取下一个需要推进的线程卡
   * 在 makeChoice 后调用，向 narrativeQueue 注入
   * @returns {Object|null} 线程卡牌对象，或 null
   */
  getNextThreadCard(gameState) {
    if (this.activeThreads.size === 0) return null;

    // 找到最早启动的活跃线程
    let oldestThread = null;
    let oldestState = null;
    for (const [threadId, state] of this.activeThreads) {
      if (!oldestThread || state.startedAtTurn < oldestState.startedAtTurn) {
        oldestThread = threadId;
        oldestState = state;
      }
    }

    if (!oldestThread) return null;

    const def = this.threadDefs.get(oldestThread);
    if (!def || !def.nodes || def.nodes.length === 0) return null;

    // 检查是否到了推进下一节点的时机
    if (oldestState.currentNodeIndex >= def.nodes.length) return null;

    const turnsSinceLastNode = gameState.turn - oldestState.lastNodeTurn;
    if (turnsSinceLastNode < this.config.minTurnsBetweenNodes) return null;

    // 获取当前节点
    const node = def.nodes[oldestState.currentNodeIndex];
    if (!node || !node.card) return null;

    // 构建线程卡
    const threadCard = this._buildThreadCard(node, def, oldestState);
    threadCard._isThreadCard = true;
    threadCard._threadId = oldestThread;
    threadCard._threadPhase = node.phase;
    threadCard._threadNodeIndex = oldestState.currentNodeIndex;

    // 推进状态
    oldestState.currentNodeIndex++;
    oldestState.lastNodeTurn = gameState.turn;
    this._threadCardCount++;

    return threadCard;
  }

  /**
   * 构建线程卡（合并线程元数据到卡内容）
   */
  _buildThreadCard(node, threadDef, state) {
    const card = JSON.parse(JSON.stringify(node.card));

    // 注入线程上下文到描述中
    if (state.currentNodeIndex > 0 && threadDef.title) {
      card.description = `【${threadDef.title}】${card.description}`;
    }

    // 确保卡有 realm 字段
    card.realm = card.realm || threadDef.realm || 'qi';

    // 为每个选择注入线程方向标记
    if (card.choices) {
      for (const [dir, choice] of Object.entries(card.choices)) {
        if (node.card.choices && node.card.choices[dir]) {
          choice._threadDirection = node.card.choices[dir].threadDirection || dir;
        }
      }
    }

    return card;
  }

  /**
   * 玩家做出选择后调用 —— 处理线程分支/结局
   * @param {Object} card - 当前卡牌
   * @param {string} direction - 玩家选择的方向
   * @param {Object} choice - 选择的choice对象
   * @param {Object} gameState
   */
  onChoiceMade(card, direction, choice, gameState) {
    if (!card._isThreadCard || !card._threadId) return;

    const threadId = card._threadId;
    const state = this.activeThreads.get(threadId);
    const def = this.threadDefs.get(threadId);
    if (!state || !def) return;

    // 记录玩家选择
    state.choices.push({
      nodeIndex: card._threadNodeIndex,
      direction: direction,
      threadDirection: choice._threadDirection || direction,
      turn: gameState.turn
    });

    state.direction = this._computeDominantDirection(state.choices);

    // 检查是否到达结局
    const nodeIndex = card._threadNodeIndex;
    const node = def.nodes[nodeIndex];
    if (node && node.phase === 'resolution') {
      this._resolveThread(threadId, def, state, node, gameState);
    }
  }

  /**
   * 计算主导方向（最多选择的方向）
   */
  _computeDominantDirection(choices) {
    const counts = {};
    for (const c of choices) {
      counts[c.threadDirection] = (counts[c.threadDirection] || 0) + 1;
    }
    let max = 0, maxDir = '';
    for (const [dir, count] of Object.entries(counts)) {
      if (count > max) { max = count; maxDir = dir; }
    }
    return maxDir;
  }

  /**
   * 结算线程结局
   */
  _resolveThread(threadId, def, state, resolutionNode, gameState) {
    const consequences = resolutionNode.consequences || {};

    // 应用结局效果
    if (consequences.onComplete) {
      const complete = consequences.onComplete;

      // 世界标记
      if (complete.worldFlags) {
        for (const flag of complete.worldFlags) {
          gameState.setFlag(flag, true);
        }
      }

      // 因果种子
      if (complete.karmaSeed && typeof karmaSystem !== 'undefined') {
        karmaSystem.plantSeed({
          ...complete.karmaSeed,
          originThread: threadId,
          originTurn: gameState.turn
        });
      }

      // 解锁后续线程
      if (complete.unlockThread) {
        const nextDef = this.threadDefs.get(complete.unlockThread);
        if (nextDef) {
          this._log(`[线程] 解锁后续故事线：「${nextDef.title}」`);
        }
      }

      // 记录日志
      this._addJournalEntry(threadId, 'completed', complete.note || `「${def.title}」故事线完成。`);
      this._log(`[线程] 故事线完成：「${def.title}」—— ${complete.note || ''}`);
      eventBus.emit('thread:resolved', {
        threadId,
        title: def.title,
        note: complete.note,
        karmaSeed: complete.karmaSeed,
        direction: state.direction,
        turn: gameState.turn
      });
    }

    // 从活跃线程中移除
    this.activeThreads.delete(threadId);
    this.completedThreads.add(threadId);
  }

  // ============ 线程日志 ============

  _addJournalEntry(threadId, status, note) {
    const def = this.threadDefs.get(threadId);
    this.threadJournal.push({
      threadId,
      title: def ? def.title : threadId,
      status,
      note,
      turn: typeof gameState !== 'undefined' ? gameState.turn : 0,
      timestamp: Date.now()
    });

    // 只保留最近 50 条
    if (this.threadJournal.length > 50) {
      this.threadJournal = this.threadJournal.slice(-50);
    }
  }

  /**
   * 获取活跃线程摘要（供UI使用）
   */
  getActiveThreadSummaries() {
    const summaries = [];
    for (const [threadId, state] of this.activeThreads) {
      const def = this.threadDefs.get(threadId);
      if (!def) continue;
      summaries.push({
        threadId,
        title: def.title,
        phase: def.nodes[Math.min(state.currentNodeIndex, def.nodes.length - 1)]?.phase || 'active',
        progress: `${state.currentNodeIndex}/${def.nodes.length}`,
        dominantDirection: state.direction,
        startedTurn: state.startedAtTurn
      });
    }
    return summaries;
  }

  /**
   * 获取最近的日志条目
   */
  getRecentJournal(count = 5) {
    return this.threadJournal.slice(-count).reverse();
  }

  // ============ 统计 & 调试 ============

  /**
   * 线程卡占比
   */
  getThreadCardRatio() {
    if (this._totalCardCount === 0) return 0;
    return this._threadCardCount / this._totalCardCount;
  }

  _threadTitle(threadId) {
    const def = this.threadDefs.get(threadId);
    return def ? def.title : threadId;
  }

  _log(msg) {
    if (typeof eventBus !== 'undefined' && eventBus) {
      eventBus.emit('game:log', msg);
    }
  }
}

// ==========================================
// ThreadState — 线程运行时状态
// ==========================================
class ThreadState {
  constructor(threadId, turn) {
    this.threadId = threadId;
    this.currentNodeIndex = 0;
    this.direction = '';              // 主导方向
    this.startedAtTurn = turn;
    this.lastNodeTurn = turn;
    this.choices = [];                // [{nodeIndex, direction, threadDirection, turn}]
    this.completed = false;
  }
}

// 全局单例
const threadEngine = new StoryThreadEngine();
