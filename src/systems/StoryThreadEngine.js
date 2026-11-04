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

    /** @type {Map<string, Object>} 本世已终止线程的权威选择回执 */
    this.threadReceipts = new Map();

    /** @type {Map<string, Object>} 已加载的线程定义 (threadId → threadDef) */
    this.threadDefs = new Map();

    /** @type {Array<Object>} 玩家故事日志 */
    this.threadJournal = [];

    /** @type {Array<Object>} Only publish completion notices after the decision is durable. */
    this._pendingResolutionEvents = [];

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

  /**
   * 初始化 / 重置故事线程引擎
   */
  init() {
    this.activeThreads.clear();
    this.completedThreads.clear();
    this.threadReceipts.clear();
    this.threadDefs.clear();
    this.threadJournal = [];
    this._pendingResolutionEvents = [];
    this._triggeredThisTurn.clear();
    this._lastThreadTriggerTurn = 0;
    this._threadCardCount = 0;
    this._totalCardCount = 0;
    this._restoreState();
  }

  /** Transient transaction state, not a save-file or cold-load projection. */
  captureRollbackState() {
    return JSON.parse(JSON.stringify({
      activeThreads: Array.from(this.activeThreads.entries()),
      completedThreads: Array.from(this.completedThreads),
      threadReceipts: Array.from(this.threadReceipts.entries()),
      threadJournal: this.threadJournal,
      pendingResolutionEvents: this._pendingResolutionEvents,
      triggeredThisTurn: Array.from(this._triggeredThisTurn),
      lastThreadTriggerTurn: this._lastThreadTriggerTurn,
      threadCardCount: this._threadCardCount,
      totalCardCount: this._totalCardCount
    }));
  }

  /** Restore the same owner's live state without rebasing time or saving. */
  restoreRollbackState(snapshot) {
    if (!snapshot) return false;
    const restored = JSON.parse(JSON.stringify(snapshot));
    this.activeThreads.clear();
    for (const [threadId, raw] of restored.activeThreads) {
      this.activeThreads.set(threadId, Object.assign(new ThreadState(threadId, raw.startedAtTurn), raw));
    }
    this.completedThreads.clear();
    for (const threadId of restored.completedThreads) this.completedThreads.add(threadId);
    this.threadReceipts.clear();
    for (const [threadId, receipt] of restored.threadReceipts || []) {
      this.threadReceipts.set(threadId, receipt);
    }
    this.threadJournal = restored.threadJournal;
    this._pendingResolutionEvents = restored.pendingResolutionEvents || [];
    this._triggeredThisTurn.clear();
    for (const threadId of restored.triggeredThisTurn) this._triggeredThisTurn.add(threadId);
    this._lastThreadTriggerTurn = restored.lastThreadTriggerTurn;
    this._threadCardCount = restored.threadCardCount;
    this._totalCardCount = restored.totalCardCount;
    return true;
  }

  /** Publish only notices belonging to a successfully persisted decision. */
  publishCommittedResolutions() {
    const notices = this._pendingResolutionEvents.splice(0);
    for (const notice of notices) eventBus.emit('thread:resolved', notice);
    return notices.length;
  }

  /**
   * Story threads are current-life runtime state, but a browser refresh must
   * not rewind them. Store a plain-data snapshot in unlocks and bind it to the
   * current life number so reincarnation cannot replay an old narrative.
   */
  _persistState(gameStateRef) {
    const state = gameStateRef || (typeof gameState !== 'undefined' ? gameState : null);
    if (!state || !state.unlocks) return;

    const lifeCount = typeof state.getLifeCount === 'function'
      ? state.getLifeCount()
      : (state.unlocks.lifeCount || 0);
    state.unlocks.storyThreadState = {
      version: 4,
      lifeCount,
      capturedTurn: Math.max(0, Number(state.turn) || 0),
      activeThreads: Array.from(this.activeThreads.entries()).map(([threadId, threadState]) => ({
        threadId,
        state: {
          threadId,
          currentNodeIndex: Math.max(0, Number(threadState.currentNodeIndex) || 0),
          pendingNodeIndex: Number.isInteger(threadState.pendingNodeIndex)
            ? threadState.pendingNodeIndex
            : null,
          direction: threadState.direction || '',
          startedAtTurn: Number(threadState.startedAtTurn) || 0,
          lastNodeTurn: Number(threadState.lastNodeTurn) || 0,
          choices: Array.isArray(threadState.choices)
            ? threadState.choices.map(choice => JSON.parse(JSON.stringify(choice)))
            : [],
          completed: !!threadState.completed
        }
      })),
      completedThreads: Array.from(this.completedThreads),
      completionReceipts: Object.fromEntries(this.threadReceipts),
      threadJournal: this.threadJournal.map(entry => ({ ...entry })),
      lastThreadTriggerTurn: this._lastThreadTriggerTurn,
      threadCardCount: this._threadCardCount,
      totalCardCount: this._totalCardCount,
      choiceHistory: Array.isArray(state.choiceHistory)
        ? state.choiceHistory.slice(-100).map(entry => ({ ...entry }))
        : [],
      recentCardTags: Array.isArray(state.recentCardTags)
        ? state.recentCardTags.slice(-50)
        : []
    };

    if (typeof state.persistCausalSession === 'function') state.persistCausalSession();
    else if (typeof state.persistUnlocks === 'function') state.persistUnlocks();
    else if (typeof state._saveUnlocks === 'function') state._saveUnlocks();
  }

  _restoreState(gameStateRef) {
    const state = gameStateRef || (typeof gameState !== 'undefined' ? gameState : null);
    if (!state || !state.unlocks) return false;

    const snapshot = state.unlocks.storyThreadState;
    if (!snapshot || typeof snapshot !== 'object') return false;
    const lifeCount = typeof state.getLifeCount === 'function'
      ? state.getLifeCount()
      : (state.unlocks.lifeCount || 0);

    // A different life is a hard causal boundary. Replace the stale snapshot
    // immediately so another refresh cannot resurrect it.
    if (Number(snapshot.lifeCount) !== Number(lifeCount)) {
      state.choiceHistory = [];
      state.recentCardTags = [];
      this._persistState(state);
      return false;
    }

    const capturedTurn = Number(snapshot.capturedTurn);
    const currentTurn = Math.max(0, Number(state.turn) || 0);
    const rebaseTurn = value => {
      const numeric = Math.max(0, Number(value) || 0);
      if (!Number.isFinite(capturedTurn)) return numeric;
      const ageAtCapture = Math.max(0, capturedTurn - numeric);
      return Math.max(0, currentTurn - ageAtCapture);
    };

    for (const entry of Array.isArray(snapshot.activeThreads) ? snapshot.activeThreads : []) {
      if (!entry || typeof entry.threadId !== 'string') continue;
      const raw = entry.state && typeof entry.state === 'object' ? entry.state : {};
      const restored = new ThreadState(entry.threadId, rebaseTurn(raw.startedAtTurn));
      restored.currentNodeIndex = Math.max(0, Math.floor(Number(raw.currentNodeIndex) || 0));
      restored.pendingNodeIndex = Number.isInteger(raw.pendingNodeIndex)
        && raw.pendingNodeIndex >= restored.currentNodeIndex
        ? raw.pendingNodeIndex
        : null;
      restored.direction = typeof raw.direction === 'string' ? raw.direction : '';
      restored.lastNodeTurn = rebaseTurn(raw.lastNodeTurn);
      const restoredChoices = this._sanitizeRestoredChoices(raw.choices);
      if (restoredChoices === null) continue;
      restored.choices = restoredChoices;
      restored.completed = !!raw.completed;
      restored._restoredSnapshotVersion = Math.max(1, Math.floor(Number(snapshot.version) || 1));
      this.activeThreads.set(entry.threadId, restored);
    }

    this.completedThreads = new Set(
      (Array.isArray(snapshot.completedThreads) ? snapshot.completedThreads : [])
        .filter(threadId => typeof threadId === 'string')
    );
    this.threadReceipts.clear();
    const rawReceipts = snapshot.completionReceipts;
    if (rawReceipts && typeof rawReceipts === 'object' && !Array.isArray(rawReceipts)) {
      for (const [threadId, receipt] of Object.entries(rawReceipts)) {
        if (this.completedThreads.has(threadId) && receipt && typeof receipt === 'object') {
          this.threadReceipts.set(threadId, JSON.parse(JSON.stringify(receipt)));
        }
      }
    }
    this.threadJournal = (Array.isArray(snapshot.threadJournal) ? snapshot.threadJournal : [])
      .filter(entry => entry && typeof entry === 'object')
      .slice(-50)
      .map(entry => ({ ...entry }));
    this._lastThreadTriggerTurn = rebaseTurn(snapshot.lastThreadTriggerTurn);
    this._threadCardCount = Math.max(0, Number(snapshot.threadCardCount) || 0);
    this._totalCardCount = Math.max(0, Number(snapshot.totalCardCount) || 0);
    // The causal owner may have committed a non-thread decision after this
    // sibling thread snapshot. Do not rewind its history on cold startup.
    // Keep legacy fallback and the different-life reset above unchanged.
    const causal = state.unlocks.causalSessionState;
    const sameLifeCausal = causal && typeof causal === 'object'
      && Number(causal.lifeCount) === Number(lifeCount);
    state.choiceHistory = (sameLifeCausal && Array.isArray(causal.choiceHistory)
      ? causal.choiceHistory : (Array.isArray(snapshot.choiceHistory) ? snapshot.choiceHistory : []))
      .slice(-100)
      .map(entry => ({ ...entry }));
    state.recentCardTags = (sameLifeCausal && Array.isArray(causal.recentCardTags)
      ? causal.recentCardTags : (Array.isArray(snapshot.recentCardTags) ? snapshot.recentCardTags : []))
      .slice(-50);
    return true;
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
      this._reconcileRestoredThreadDefinition(thread.threadId, thread);
      this._reconcileRestoredReceipt(thread.threadId, thread);
    }
  }

  _reconcileRestoredThreadDefinition(threadId, def) {
    const state = this.activeThreads.get(threadId);
    if (!state) return true;
    if (state.completed === true || state.currentNodeIndex === def?.nodes?.length) {
      this.activeThreads.delete(threadId);
      this.completedThreads.add(threadId);
      return false;
    }
    if (!Array.isArray(def?.nodes)
      || state.currentNodeIndex >= def.nodes.length
      || state.choices.length !== state.currentNodeIndex
      || (state.pendingNodeIndex !== null
        && (state.pendingNodeIndex !== state.currentNodeIndex
          || state.pendingNodeIndex >= def.nodes.length))) {
      this.activeThreads.delete(threadId);
      return false;
    }
    for (let expectedIndex = 0; expectedIndex < state.choices.length; expectedIndex++) {
      const entry = state.choices[expectedIndex];
      const node = def.nodes[expectedIndex];
      const choice = node?.card?.choices?.[entry.direction];
      if (!node || !choice || entry.nodeIndex !== expectedIndex) {
        this.activeThreads.delete(threadId);
        return false;
      }
      if (entry.nodeId === undefined || entry.nodeId === null) entry.nodeId = node.id;
      if (entry.nodeId !== node.id) {
        this.activeThreads.delete(threadId);
        return false;
      }
      const authoredThreadDirection = choice.threadDirection || entry.direction;
      if (entry.threadDirection === undefined || entry.threadDirection === null) {
        entry.threadDirection = authoredThreadDirection;
      }
      if (entry.threadDirection !== authoredThreadDirection) {
        this.activeThreads.delete(threadId);
        return false;
      }
      const expectedMode = choice.action?.type === 'ENTER_VENDOR'
        ? 'vendor'
        : (choice.triggerCombat ? 'combat' : null);
      const actualMode = entry.outcomeContext?.mode || null;
      if (expectedMode && actualMode === null && state._restoredSnapshotVersion < 3) {
        // Pre-B11 snapshots accepted combat nodes without recording the result.
        // Re-present that unresolved cross-mode node instead of guessing an
        // outcome or silently deleting the whole in-flight story.
        state.choices = state.choices.slice(0, expectedIndex);
        state.currentNodeIndex = expectedIndex;
        state.pendingNodeIndex = null;
        state.lastNodeTurn = expectedIndex > 0
          ? Math.max(0, Number(state.choices[expectedIndex - 1]?.turn) || state.startedAtTurn)
          : state.startedAtTurn;
        state.direction = this._computeDominantDirection(state.choices);
        return true;
      }
      if (expectedMode !== actualMode) {
        this.activeThreads.delete(threadId);
        return false;
      }
    }
    state.direction = this._computeDominantDirection(state.choices);
    return true;
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

    // A realm transition is a hard eligibility boundary for authored threads.
    // Lower-realm pending nodes must not survive into a new chapter or occupy
    // one of the two active-thread slots after refresh.
    this.reconcileRealm(gameState);

    // 清理超时线程
    this._cleanupTimeout(gameState.turn,
      gameState.getCausalDecisionIndex?.() ?? gameState.turn);

    // 检查新触发
    this._checkAllTriggers(gameState);
    this._persistState(gameState);
  }

  _resetTurnFlags() {
    this._triggeredThisTurn.clear();
  }

  _cleanupTimeout(turn, closedTurn = turn) {
    for (const [threadId, state] of this.activeThreads) {
      // A card already shown to the player is an owned pending interaction,
      // not an ambient opportunity that may disappear behind their back.
      if (Number.isInteger(state.pendingNodeIndex)) continue;
      const def = this.threadDefs.get(threadId);
      const timeoutTurns = Math.max(
        1,
        Math.floor(Number(def?.timeoutTurns) || this.config.threadTimeout)
      );
      if (turn - state.startedAtTurn > timeoutTurns) {
        this._log(`[线程] "${this._threadTitle(threadId)}" 超时 —— 时机已过。`);
        this._recordTerminalReceipt(threadId, state, 'timeout', closedTurn);
        this.activeThreads.delete(threadId);
        this.completedThreads.add(threadId);
        // 记录到日志但不给奖励
        this._addJournalEntry(threadId, 'timeout', '时机已过，此线不再推进。');
      }
    }
  }

  reconcileRealm(gameStateRef) {
    const stateRef = gameStateRef || (typeof gameState !== 'undefined' ? gameState : null);
    if (!stateRef?.realm) return 0;
    let removed = 0;
    for (const [threadId] of this.activeThreads) {
      const def = this.threadDefs.get(threadId);
      const eligibleRealms = Array.isArray(def?.eligibleRealms) && def.eligibleRealms.length > 0
        ? def.eligibleRealms
        : [def?.realm].filter(Boolean);
      if (!def || eligibleRealms.length === 0 || eligibleRealms.includes(stateRef.realm)) continue;
      this._recordTerminalReceipt(
        threadId, this.activeThreads.get(threadId), 'realm_expired',
        stateRef.getCausalDecisionIndex?.() ?? stateRef.turn
      );
      this.activeThreads.delete(threadId);
      this.completedThreads.add(threadId);
      this._addJournalEntry(
        threadId,
        'realm_expired',
        `境界已进入 ${stateRef.realm}，旧章节线程不再具备展示资格。`
      );
      removed++;
    }
    if (removed > 0) this._persistState(stateRef);
    return removed;
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
      const eligibleRealms = Array.isArray(def.eligibleRealms) && def.eligibleRealms.length > 0
        ? def.eligibleRealms
        : [def.realm].filter(Boolean);
      if (eligibleRealms.length > 0 && !eligibleRealms.includes(gameState.realm)) continue;
      if (!this._meetsThreadRequirements(def.requirements, gameState)) continue;

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
  _meetsThreadRequirements(requirements, gameStateRef) {
    if (!requirements || typeof requirements !== 'object') return true;
    const completedQuestIds = Array.isArray(requirements.completedQuestIds)
      ? requirements.completedQuestIds
      : [];
    if (completedQuestIds.length > 0) {
      const flags = gameStateRef?.flags || {};
      // QuestSystem writes this success-only fact.  Do not consult its terminal
      // replay set here: failed and abandoned tasks must never unlock a thread.
      if (!completedQuestIds.every(questId => flags[questId + 'Completed'] === true)) return false;
    }
    const contracts = Array.isArray(requirements.npcManifestations)
      ? requirements.npcManifestations
      : [];
    if (contracts.length === 0) return true;
    const continuity = typeof worldContinuityStore !== 'undefined'
      ? worldContinuityStore
      : null;
    if (!continuity || typeof continuity.canManifest !== 'function') return false;
    return contracts.every(contract => contract?.npcId
      && ['PHYSICAL', 'ECHO_ONLY'].includes(contract.manifestation)
      && continuity.canManifest(contract.npcId, contract.manifestation));
  }

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
        if (trigger.requiredDungeonOutcome) {
          const required = trigger.requiredDungeonOutcome;
          if (!required.dungeonId || required.outcome !== 'success'
            || !gameState.getDungeonOutcomeForChoice?.({
              sourceCardId: entry.cardId,
              sourceDecisionIndex: entry.decisionIndex,
              dungeonId: required.dungeonId,
              outcome: required.outcome
            })) continue;
        }
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
    this.reconcileRealm(gameState);
    if (this.activeThreads.size === 0) return null;

    // A presented-but-unaccepted node is authoritative. Refresh and queue
    // rebuilds must replay it before any other thread can inject a new node.
    let oldestThread = null;
    let oldestState = null;
    const pendingCandidates = [];
    const eligibleCandidates = [];
    for (const [threadId, state] of this.activeThreads) {
      if (Number.isInteger(state.pendingNodeIndex)) {
        pendingCandidates.push([threadId, state]);
        continue;
      }
      const def = this.threadDefs.get(threadId);
      const node = def?.nodes?.[state.currentNodeIndex];
      if (!node) continue;
      if (!this._isNodeEligibleForState(node, state, gameState)) continue;
      const turnsSinceLastNode = gameState.turn - state.lastNodeTurn;
      const requiredGap = this._requiredNodeGap(def, node);
      if (turnsSinceLastNode >= requiredGap) eligibleCandidates.push([threadId, state]);
    }
    const priorityOf = ([threadId]) => Math.floor(Number(this.threadDefs.get(threadId)?.priority) || 0);
    const highestPendingPriority = pendingCandidates.reduce(
      (highest, candidate) => Math.max(highest, priorityOf(candidate)),
      -Infinity
    );
    const highestEligiblePriority = eligibleCandidates.reduce(
      (highest, candidate) => Math.max(highest, priorityOf(candidate)),
      -Infinity
    );
    // pendingNodeIndex is assigned when a card is handed to Flow's queue, not
    // only after the UI actually presents it. A low-priority queued node can
    // therefore remain pseudo-pending behind quests/karma and otherwise block
    // a newly eligible authored scene forever. Priority-90+ continuity may
    // preempt only strictly lower pending work; an equal/higher pending beat
    // remains the authoritative replay target.
    const continuityPreemptsPending = highestEligiblePriority >= 90
      && highestEligiblePriority > highestPendingPriority;
    const selectingPending = pendingCandidates.length > 0 && !continuityPreemptsPending;
    const candidates = selectingPending ? pendingCandidates : eligibleCandidates;
    for (const [threadId, state] of candidates) {
      const priority = Math.floor(Number(this.threadDefs.get(threadId)?.priority) || 0);
      const selectedPriority = !oldestThread
        ? 0
        : Math.floor(Number(this.threadDefs.get(oldestThread)?.priority) || 0);
      if (
        !oldestThread
        || priority > selectedPriority
        || (priority === selectedPriority && state.startedAtTurn < oldestState.startedAtTurn)
      ) {
        oldestThread = threadId;
        oldestState = state;
      }
    }

    if (!oldestThread) return null;

    const def = this.threadDefs.get(oldestThread);
    if (!def || !def.nodes || def.nodes.length === 0) return null;

    const nodeIndex = Number.isInteger(oldestState.pendingNodeIndex)
      ? oldestState.pendingNodeIndex
      : oldestState.currentNodeIndex;
    if (nodeIndex >= def.nodes.length) return null;

    const isReplay = Number.isInteger(oldestState.pendingNodeIndex);
    if (!isReplay) {
      const turnsSinceLastNode = gameState.turn - oldestState.lastNodeTurn;
      const requiredGap = this._requiredNodeGap(def, def.nodes[nodeIndex]);
      if (turnsSinceLastNode < requiredGap) return null;
    }

    // 获取当前节点
    const node = def.nodes[nodeIndex];
    if (!node || !node.card) return null;

    // 构建线程卡
    const threadCard = this._buildThreadCard(node, def, oldestState);
    this._decorateThreadCard(threadCard, oldestThread, def, node, nodeIndex, gameState);

    // Presentation is not acceptance. Persist the exact pending node so a
    // refresh can replay it; accepted progress advances only in onChoiceMade.
    if (!isReplay) {
      oldestState.pendingNodeIndex = nodeIndex;
      this._threadCardCount++;
      this._persistState(gameState);
    }

    return threadCard;
  }

  /**
   * Rebuild the exact authored card for an already-presented thread node.
   *
   * This is intentionally read-only: combat reload validation needs an
   * authority source for dynamic thread cards, but must never trust the card
   * serialized inside the combat snapshot or advance/present a new node while
   * resolving that authority.
   */
  getAuthoritativePendingCard(cardId, gameState) {
    if (typeof cardId !== 'string' || !cardId) return null;
    for (const [threadId, state] of this.activeThreads) {
      const nodeIndex = state?.pendingNodeIndex;
      if (!Number.isInteger(nodeIndex)) continue;
      const def = this.threadDefs.get(threadId);
      const node = def?.nodes?.[nodeIndex];
      if (!node?.card) continue;
      const threadCard = this._buildThreadCard(node, def, state);
      this._decorateThreadCard(threadCard, threadId, def, node, nodeIndex, gameState);
      if (threadCard.id === cardId) return threadCard;
    }
    return null;
  }

  _decorateThreadCard(threadCard, threadId, def, node, nodeIndex, gameState) {
    threadCard._isThreadCard = true;
    threadCard._threadId = threadId;
    threadCard._threadPhase = node.phase;
    threadCard._threadNodeIndex = nodeIndex;
    threadCard._narrativeLane = 'primary';
    threadCard._narrativeThreadKey = `thread:${threadId}`;
    threadCard._narrativeSticky = true;
    threadCard._narrativePriority = Math.max(
      0,
      Math.floor(Number(def.priority) || Number(this.config.injectionPriority) || 52)
    );
    threadCard.semanticKey = threadCard.semanticKey || `thread:${threadId}:${node.id}`;
    if (threadCard.once === undefined && threadCard.repeatPolicy === undefined) {
      threadCard.once = true;
    }
    if (!Array.isArray(threadCard.eligibleRealms) || threadCard.eligibleRealms.length === 0) {
      threadCard.eligibleRealms = [threadCard.realm || def.realm || gameState?.realm];
    }
  }

  _requiredNodeGap(threadDef, node) {
    const authoredGap = Math.max(0, Math.floor(Number(node?.minTurnsAfterPrevious) || 0));
    // Priority-90+ threads are authored scene sequences. Injecting the global
    // ambient gap between their contiguous nodes lets an unrelated location
    // card move the player away before a presence-gated follow-up can appear,
    // permanently deadlocking the scene. Such threads use only their explicit
    // authored pauses (for example the eight-turn epilogue echo).
    const priority = Math.floor(Number(threadDef?.priority) || 0);
    return priority >= 90
      ? authoredGap
      : Math.max(this.config.minTurnsBetweenNodes, authoredGap);
  }

  _isNodeEligibleForState(node, state, gameState) {
    const eligibility = node?.eligibility && typeof node.eligibility === 'object'
      ? node.eligibility
      : {};
    const settledNodeIds = new Set((state?.choices || []).map(choice => choice?.nodeId).filter(Boolean));
    if (Array.isArray(eligibility.requiredNodes)
      && eligibility.requiredNodes.some(nodeId => !settledNodeIds.has(nodeId))) return false;
    if (Array.isArray(eligibility.forbiddenNodes)
      && eligibility.forbiddenNodes.some(nodeId => settledNodeIds.has(nodeId))) return false;

    const variant = this._selectNodeVariant(node, state);
    const card = this._mergeThreadCard(node?.card || {}, variant?.card || null);
    if (card.requiresPlayerPresence === true) {
      const authoredLocations = Array.isArray(card.location) ? card.location : [card.location];
      if (!authoredLocations.filter(Boolean).includes(gameState?.currentLocation)) return false;
    }
    return true;
  }

  /**
   * 构建线程卡（合并线程元数据到卡内容）
   */
  _buildThreadCard(node, threadDef, state) {
    const variant = this._selectNodeVariant(node, state);
    const card = this._mergeThreadCard(node.card, variant?.card || null);

    // 注入线程上下文到描述中
    if (state.currentNodeIndex > 0 && threadDef.title) {
      card.description = `【${threadDef.title}】${card.description}`;
    }

    // A node may append a second, independent prior choice after its primary
    // variant. This keeps an existing outcome matrix intact (for example the
    // lesson × combat result) without multiplying or shadowing its variants.
    for (const echo of Array.isArray(node.historyEchoes) ? node.historyEchoes : []) {
      if (!echo?.when || !Object.keys(echo.when).length
        || typeof echo.text !== 'string' || !echo.text.trim()
        || !this._matchesHistoryVariant(echo.when, state?.choices || [])) continue;
      card.description = `${card.description || ''}\n\n${echo.text.trim()}`;
    }

    // Cross-realm callbacks must read completed, author-validated receipts.
    // A legacy completion ID carries no direction and therefore gets the
    // authored neutral text instead of inventing a past choice.
    for (const echo of Array.isArray(node.receiptEchoes) ? node.receiptEchoes : []) {
      const receipt = this.getCompletionReceipt(echo.threadId);
      const decision = receipt?.nodes?.find(entry => entry.nodeId === echo.nodeId);
      const text = decision && typeof echo.directions?.[decision.threadDirection] === 'string'
        ? echo.directions[decision.threadDirection]
        : echo.missing;
      if (typeof text === 'string' && text.trim()) {
        card.description = `${card.description || ''}\n\n${text.trim()}`;
      }
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

    if (variant?.id) card._threadVariantId = variant.id;

    return card;
  }

  _selectNodeVariant(node, state) {
    const variants = Array.isArray(node?.variants) ? node.variants : [];
    return variants.find(variant => this._matchesHistoryVariant(variant?.when, state?.choices || [])) || null;
  }

  _matchesHistoryVariant(when, choices) {
    if (!when || typeof when !== 'object') return false;
    if (Array.isArray(when.anyOf)
      && !when.anyOf.some(candidate => this._matchesHistoryVariant(candidate, choices))) return false;
    const byNode = new Map(choices.map(entry => [entry.nodeId, entry]));
    for (const [nodeId, direction] of Object.entries(when.choiceDirections || {})) {
      if (byNode.get(nodeId)?.direction !== direction) return false;
    }
    for (const [nodeId, outcome] of Object.entries(when.combatOutcomes || {})) {
      const context = byNode.get(nodeId)?.outcomeContext;
      if (context?.mode !== 'combat' || context.combatOutcome !== outcome) return false;
    }
    for (const [nodeId, itemId] of Object.entries(when.vendorPurchasedItems || {})) {
      const context = byNode.get(nodeId)?.outcomeContext;
      if (context?.mode !== 'vendor'
        || !context.vendorSummary?.purchasedItemIds?.includes(itemId)) return false;
    }
    for (const [nodeId, resolution] of Object.entries(when.vendorResolutions || {})) {
      const context = byNode.get(nodeId)?.outcomeContext;
      if (context?.mode !== 'vendor' || context.vendorSummary?.resolution !== resolution) return false;
    }
    return true;
  }

  _mergeThreadCard(base, override) {
    const card = JSON.parse(JSON.stringify(base));
    if (!override || typeof override !== 'object') return card;
    for (const [key, value] of Object.entries(override)) {
      if (key === 'id' || key === 'semanticKey' || key === 'realm') continue;
      if (key === 'choices' && value && typeof value === 'object') {
        for (const [direction, choiceOverride] of Object.entries(value)) {
          if (!card.choices?.[direction]) continue;
          card.choices[direction] = {
            ...card.choices[direction],
            ...JSON.parse(JSON.stringify(choiceOverride)),
            effects: {
              ...(card.choices[direction].effects || {}),
              ...(choiceOverride.effects || {})
            }
          };
        }
        continue;
      }
      card[key] = JSON.parse(JSON.stringify(value));
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
  onChoiceMade(card, direction, choice, gameState, outcomeContext = null) {
    if (!card._isThreadCard || !card._threadId) return;

    const threadId = card._threadId;
    const state = this.activeThreads.get(threadId);
    const def = this.threadDefs.get(threadId);
    if (!state || !def) return false;

    const nodeIndex = Number(card._threadNodeIndex);
    if (!Number.isInteger(nodeIndex)) return false;
    if (!Number.isInteger(state.pendingNodeIndex)
      || nodeIndex !== state.pendingNodeIndex) return false;
    if (state.choices.some(entry => entry.nodeIndex === nodeIndex)) return false;

    // A caller-supplied card or choice cannot become the source of a durable
    // completion receipt. Match the pending node to its loaded authored card,
    // then use the authored choice for direction and cross-mode validation.
    const authoredCard = this.getAuthoritativePendingCard(card.id, gameState);
    const authoredChoice = authoredCard?.choices?.[direction];
    if (!authoredCard || authoredCard._threadId !== threadId
      || card.id !== authoredCard.id
      || card.semanticKey !== authoredCard.semanticKey
      || !card.choices?.[direction] || !authoredChoice
      || choice?._threadDirection !== authoredChoice._threadDirection) return false;

    // 记录玩家选择
    // Cross-mode settlement must validate before any mutation. A malformed
    // result cannot advance the node and leave a contextless causal record.
    const outcomeValidation = this._validateOutcomeContextForChoice(authoredChoice, outcomeContext);
    if (!outcomeValidation.valid) return false;
    const normalizedOutcomeContext = outcomeValidation.normalized;
    state.choices.push({
      nodeIndex,
      nodeId: def.nodes[nodeIndex]?.id || null,
      direction: direction,
      threadDirection: authoredChoice._threadDirection || direction,
      turn: gameState.getCausalDecisionIndex?.() ?? gameState.turn,
      ...(normalizedOutcomeContext ? { outcomeContext: normalizedOutcomeContext } : {})
    });

    state.direction = this._computeDominantDirection(state.choices);
    state.currentNodeIndex = nodeIndex + 1;
    state.pendingNodeIndex = null;
    state.lastNodeTurn = Math.max(0, Number(gameState.getCausalDecisionIndex?.() ?? gameState.turn) || 0);

    const node = def.nodes[nodeIndex];
    const exit = node?.exits?.[direction];
    if (exit && typeof exit === 'object') {
      const status = typeof exit.status === 'string' && exit.status ? exit.status : 'declined';
      const note = typeof exit.note === 'string' && exit.note
        ? exit.note
        : `「${def.title}」至此告一段落。`;
      this._recordTerminalReceipt(threadId, state, status,
        gameState.getCausalDecisionIndex?.() ?? gameState.turn);
      this.activeThreads.delete(threadId);
      this.completedThreads.add(threadId);
      this._addJournalEntry(threadId, status, note);
      this._log(`[线程] ${note}`);
      this._persistState(gameState);
    } else if (node && node.phase === 'resolution') {
      this._resolveThread(threadId, def, state, node, gameState);
    } else {
      this._persistState(gameState);
    }
    return true;
  }

  /**
   * Cross-mode systems may report only the small authored facts needed by a
   * later node.  Never persist a UI payload or combat object wholesale.
   */
  _normalizeOutcomeContext(context) {
    if (!context || typeof context !== 'object') return null;
    if (context.mode === 'combat') {
      const combatOutcome = ['victory', 'defeat', 'flee'].includes(context.combatOutcome)
        ? context.combatOutcome
        : null;
      return combatOutcome ? { mode: 'combat', combatOutcome } : null;
    }
    if (context.mode === 'vendor') {
      const summary = context.vendorSummary && typeof context.vendorSummary === 'object'
        ? context.vendorSummary
        : {};
      const purchasedItemIds = Array.isArray(summary.purchasedItemIds)
        ? summary.purchasedItemIds
        : (Array.isArray(summary.purchasedItems)
          ? summary.purchasedItems.map(item => item?.id)
          : []);
      const resolution = summary.resolution == null
        ? null
        : (['purchased', 'bartered', 'sect_loan', 'left_empty'].includes(summary.resolution)
          ? summary.resolution
          : undefined);
      if (resolution === undefined) return null;
      return {
        mode: 'vendor',
        vendorSummary: {
          purchaseCount: Math.max(0, Math.floor(Number(summary.purchaseCount) || 0)),
          spiritStoneSpent: Math.max(0, Math.floor(Number(summary.spiritStoneSpent) || 0)),
          resolution,
          purchasedItemIds: purchasedItemIds
            .filter(id => typeof id === 'string' && id.length > 0)
            .slice(0, 20)
        }
      };
    }
    return null;
  }

  _validateOutcomeContextForChoice(choice, context) {
    const expectedMode = choice?.action?.type === 'ENTER_VENDOR'
      ? 'vendor'
      : (choice?.triggerCombat ? 'combat' : null);
    const contextSupplied = context !== null && context !== undefined;
    if (!expectedMode && !contextSupplied) return { valid: true, normalized: null };
    const normalized = this._normalizeOutcomeContext(context);
    if (!normalized || normalized.mode !== expectedMode) {
      return { valid: false, normalized: null };
    }
    return { valid: true, normalized };
  }

  _sanitizeRestoredChoices(rawChoices) {
    if (!Array.isArray(rawChoices)) return [];
    const sanitized = [];
    for (const raw of rawChoices) {
      if (!raw || typeof raw !== 'object') return null;
      const copy = JSON.parse(JSON.stringify(raw));
      if (Object.prototype.hasOwnProperty.call(copy, 'outcomeContext')) {
        const normalized = this._normalizeOutcomeContext(copy.outcomeContext);
        if (!normalized) return null;
        copy.outcomeContext = normalized;
      }
      sanitized.push(copy);
    }
    return sanitized;
  }

  /** Return a detached, validated current-life receipt. */
  getThreadReceipt(threadId) {
    const receipt = this.threadReceipts.get(threadId);
    const def = this.threadDefs.get(threadId);
    if (!receipt || !def || !this.completedThreads.has(threadId)
      || !this._isReceiptConsistentWithDefinition(receipt, def)) return null;
    return JSON.parse(JSON.stringify(receipt));
  }

  getCompletionReceipt(threadId) {
    const receipt = this.getThreadReceipt(threadId);
    return receipt?.status === 'completed' ? receipt : null;
  }

  _recordTerminalReceipt(threadId, state, status, closedTurn) {
    if (!state || this.threadReceipts.has(threadId)) return false;
    const turn = Math.max(0, Math.floor(Number(closedTurn) || 0));
    const nodes = (state.choices || []).map(entry => ({
      nodeId: entry.nodeId,
      direction: entry.direction,
      threadDirection: entry.threadDirection,
      turn: Math.max(0, Math.floor(Number(entry.turn) || 0)),
      ...(entry.outcomeContext
        ? { outcomeContext: this._normalizeOutcomeContext(entry.outcomeContext) }
        : {})
    }));
    const receipt = {
      threadId, status, closedTurn: turn,
      completedTurn: status === 'completed' ? turn : null,
      nodes
    };
    const def = this.threadDefs.get(threadId);
    if (!this._isReceiptConsistentWithDefinition(receipt, def)) return false;
    this.threadReceipts.set(threadId, receipt);
    return true;
  }

  _reconcileRestoredReceipt(threadId, def) {
    const receipt = this.threadReceipts.get(threadId);
    if (receipt && !this._isReceiptConsistentWithDefinition(receipt, def)) {
      this.threadReceipts.delete(threadId);
    }
  }

  _isReceiptConsistentWithDefinition(receipt, def) {
    if (!receipt || !def || receipt.threadId !== def.threadId
      || !['completed', 'declined', 'timeout', 'realm_expired'].includes(receipt.status)
      || !Number.isSafeInteger(receipt.closedTurn) || receipt.closedTurn < 0
      || Object.keys(receipt).some(key => !['threadId', 'status', 'closedTurn', 'completedTurn', 'nodes'].includes(key))
      || !Array.isArray(receipt.nodes) || receipt.nodes.length > def.nodes?.length) return false;
    if (receipt.status === 'completed') {
      if (receipt.nodes.length !== def.nodes.length
        || def.nodes.at(-1)?.phase !== 'resolution'
        || receipt.completedTurn !== receipt.closedTurn
        || receipt.nodes.at(-1)?.turn !== receipt.closedTurn) return false;
    } else if (receipt.completedTurn !== null
      || (['timeout', 'realm_expired'].includes(receipt.status)
        && receipt.nodes.length >= def.nodes.length)) return false;
    for (let index = 0; index < receipt.nodes.length; index++) {
      const entry = receipt.nodes[index];
      const node = def.nodes[index];
      const choice = node?.card?.choices?.[entry?.direction];
      if (!choice || entry.nodeId !== node.id
        || Object.keys(entry).some(key => !['nodeId', 'direction', 'threadDirection', 'turn', 'outcomeContext'].includes(key))
        || entry.threadDirection !== (choice.threadDirection || entry.direction)
        || !Number.isSafeInteger(entry.turn) || entry.turn < 0
        || entry.turn > receipt.closedTurn
        || (index > 0 && entry.turn < receipt.nodes[index - 1].turn)) return false;
      const exit = node.exits?.[entry.direction];
      if (exit && (receipt.status !== (exit.status || 'declined')
        || index !== receipt.nodes.length - 1)) return false;
      const expectedMode = choice.action?.type === 'ENTER_VENDOR'
        ? 'vendor' : (choice.triggerCombat ? 'combat' : null);
      const normalized = entry.outcomeContext
        ? this._normalizeOutcomeContext(entry.outcomeContext) : null;
      if ((normalized?.mode || null) !== expectedMode
        || (entry.outcomeContext && JSON.stringify(entry.outcomeContext) !== JSON.stringify(normalized))) return false;
    }
    if (receipt.status === 'declined') {
      const lastIndex = receipt.nodes.length - 1;
      const last = receipt.nodes[lastIndex];
      if (!last || def.nodes[lastIndex]?.exits?.[last.direction]?.status !== 'declined') return false;
    }
    return true;
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

      // Only publish a seed when this resolution really added it. An authored
      // condition may leave the thread completed without a victory payoff.
      let plantedKarmaSeed = null;
      if (complete.karmaSeed
        && (!complete.karmaSeedWhen
          || this._matchesHistoryVariant(complete.karmaSeedWhen, state.choices))
        && typeof karmaSystem !== 'undefined') {
        const priorSeed = gameState.karmaSeeds?.find(seed => seed.id === complete.karmaSeed.id) || null;
        karmaSystem.plantSeed({
          ...complete.karmaSeed,
          originThread: threadId,
          originTurn: gameState.getCausalDecisionIndex?.() ?? gameState.turn
        });
        const currentSeed = gameState.karmaSeeds?.find(seed => seed.id === complete.karmaSeed.id) || null;
        if (currentSeed && currentSeed !== priorSeed) plantedKarmaSeed = complete.karmaSeed;
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
      const resolutionNotice = {
        threadId,
        title: def.title,
        note: complete.note,
        karmaSeed: plantedKarmaSeed,
        direction: state.direction,
        turn: gameState.getCausalDecisionIndex?.() ?? gameState.turn
      };
      if (gameState._causalTransaction) this._pendingResolutionEvents.push(resolutionNotice);
      else eventBus.emit('thread:resolved', resolutionNotice);
    }

    // 从活跃线程中移除
    this._recordTerminalReceipt(threadId, state, 'completed',
      gameState.getCausalDecisionIndex?.() ?? gameState.turn);
    this.activeThreads.delete(threadId);
    this.completedThreads.add(threadId);
    this._persistState(gameState);
  }

  // ============ 线程日志 ============

  _addJournalEntry(threadId, status, note) {
    const def = this.threadDefs.get(threadId);
    this.threadJournal.push({
      threadId,
      title: def ? def.title : threadId,
      status,
      note,
      turn: typeof gameState !== 'undefined'
        ? gameState.getCausalDecisionIndex?.() ?? gameState.turn : 0,
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
    this.pendingNodeIndex = null;
    this.direction = '';              // 主导方向
    this.startedAtTurn = turn;
    this.lastNodeTurn = turn;
    this.choices = [];                // [{nodeIndex, direction, threadDirection, turn}]
    this.completed = false;
  }
}

// 全局单例
const threadEngine = new StoryThreadEngine();

if (typeof module !== 'undefined' && module.exports) {
  module.exports = StoryThreadEngine;
} else if (typeof window !== 'undefined') {
  window.StoryThreadEngine = StoryThreadEngine;
  window.threadEngine = threadEngine;
}
