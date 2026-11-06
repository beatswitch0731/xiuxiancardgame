/**
 * KarmaSystem - 因果系统
 *
 * 管理因果种子的播种、计时、发芽、合并、抵消。
 * 因果种子是延迟触发的卡牌事件——你在第5轮做的好事/坏事，
 * 可能在第20轮才"结果"。
 *
 * 种子类型体系（v2.0）：
 *   karma    = 善因 (善行→善果，可合并为"大善人"事件)
 *   grudge   = 恶因 (恶行→恶果，可合并为"众矢之的"事件)
 *   bloodline = 血脉因果 (与NPC/势力的深度羁绊，不可合并)
 *   fate     = 命运因果 (天劫/转世/天道相关，优先级最高)
 *
 * 合并规则：同类型种子达到阈值(3个)时，合并为一个高阶事件
 * 抵消规则：karma种子与grudge种子相遇时，双方优先级低者被抵消
 *
 * 因果流程：
 *   玩家选择 → 种下种子(karmaSeed) → 每轮delay-1 → delay=0时发芽
 *   → CardSystem 按优先级60抽出因果卡 → 玩家再次选择 → 因果闭环
 */
class KarmaSystem {
  constructor() {
    this._eventBusListeners = [];
  }

  /**
   * 初始化：监听事件
   */
  init() {
    eventBus.on('state:reset', () => this._onReset());
  }

  /**
   * 种植因果种子
   * @param {Object} seed - {
   *   id,              // 种子唯一标识
   *   seedType,        // 'karma'|'grudge'|'bloodline'|'fate' (默认 'karma')
   *   delay,           // 发芽延迟轮数
   *   realm,           // 限定发芽境界 (null=任意)
   *   priority,        // 优先级 (越高越先发芽)
   *   originCard,      // 来源卡牌ID
   *   originChoice,    // 来源选项
   *   mergeGroup,      // 合并组ID (同组种子可合并)
   *   cancelGroup      // 抵消组ID (碰面时低优先级者取消)
   * }
   */
  plantSeed(seed) {
    if (!seed || !seed.id) return;

    // 检查是否已存在同ID种子（避免重复）
    const existing = gameState.karmaSeeds.find(s => s.id === seed.id);
    if (existing) {
      if (seed.delay < existing.delay) {
        existing.delay = seed.delay;
        existing.priority = Math.max(existing.priority, seed.priority || 0);
      }
      // 动态因果（例如道侣里程碑）必须携带产生时的角色上下文。
      // 旧存档里同 ID 的种子可能没有 context，重复种植时允许补全而不覆盖已有快照。
      if (!existing.context && seed.context && typeof seed.context === 'object') {
        existing.context = { ...seed.context };
      }
      if (!existing.payoffEvent && seed.payoffEvent) {
        existing.payoffEvent = seed.payoffEvent;
      }
      if (!existing.path && seed.path) {
        existing.path = seed.path;
      }
      if (!existing.originThread && seed.originThread) {
        existing.originThread = seed.originThread;
      }
      if (!existing.originQuest && seed.originQuest) {
        existing.originQuest = seed.originQuest;
      }
      if (!existing.originOutcome && seed.originOutcome) {
        existing.originOutcome = seed.originOutcome;
      }
      this._recordPromise(existing.id);
      this._persistSeeds();
      return;
    }

    // 应用境界感知的延迟调整
    let adjustedDelay = seed.delay != null ? seed.delay : 5;
    adjustedDelay = this._adjustDelayByRealm(adjustedDelay);

    const karmaSeed = {
      id: seed.id,
      seedType: seed.seedType || 'karma',
      delay: adjustedDelay,
      realm: seed.realm || null,
      path: seed.path || null,
      priority: seed.priority || 0,
      originTurn: gameState.getCausalDecisionIndex?.() ?? gameState.turn,
      originLife: gameState.getLifeCount ? gameState.getLifeCount() : 0,
      originCard: seed.originCard || null,
      originChoice: seed.originChoice || null,
      originThread: seed.originThread || null,
      originQuest: seed.originQuest || null,
      originOutcome: seed.originOutcome || null,
      description: seed.description || null,
      tags: Array.isArray(seed.tags) ? [...seed.tags] : [],
      payoffEvent: seed.payoffEvent || null,
      context: seed.context && typeof seed.context === 'object'
        ? { ...seed.context }
        : null,
      consumed: false,
      mergeGroup: seed.mergeGroup || null,
      cancelGroup: seed.cancelGroup || null
    };

    // 种子抵消检查：同cancelGroup中低优先级种子被取消
    if (!this._checkCancel(karmaSeed)) return;

    gameState.karmaSeeds.push(karmaSeed);

    // seed ID 同时是现有剧情数据的选择承诺键。只有真正被接受的种子才登记，
    // 让 requiresFlags 消费同一个权威选择结果；旧的 false 占位也必须提升为 true。
    this._recordPromise(karmaSeed.id);
    this._persistSeeds();

    eventBus.emit('karma:seedPlanted', { seed: karmaSeed });

    // 合并检查：同mergeGroup + 同seedType 达到阈值时合并
    this._checkMerge(karmaSeed.seedType, karmaSeed.mergeGroup);
  }

  /**
   * 每轮推进因果计时器
   */
  tick({ emitEvents = true, persist = true } = {}) {
    const ripened = [];
    for (const seed of gameState.karmaSeeds) {
      seed.delay--;

      if (seed.delay === 0) {
        const notice = {
          seedId: seed.id,
          realm: seed.realm,
          originTurn: seed.originTurn
        };
        ripened.push(notice);
        if (emitEvents) eventBus.emit('karma:seedRipening', notice);
      }
    }
    if (persist) this._persistSeeds();
    return ripened;
  }

  /**
   * 获取所有已成熟（delay <= 0）的因果种子
   * @returns {Object[]}
   */
  getReadySeeds() {
    const realmOrder = gameState.config?.realms?.order || ['qi', 'foundation', 'golden', 'nascent', 'deity', 'tribulation'];
    const currentRealmIndex = realmOrder.indexOf(gameState.realm);
    const ready = gameState.karmaSeeds.filter(s => {
      if (s.delay > 0) return false;
      const pathReady = !s.path || s.path === gameState.path;
      if (!pathReady) return false;
      if (!s.realm) return true;
      const seedRealmIndex = realmOrder.indexOf(s.realm);
      const realmReady = seedRealmIndex < 0 || currentRealmIndex >= seedRealmIndex;
      return realmReady;
    });
    const effectivePriority = (seed) => {
      const basePriority = Number.isFinite(Number(seed.priority)) ? Number(seed.priority) : 0;
      const seedRealmIndex = seed.realm ? realmOrder.indexOf(seed.realm) : -1;
      const crossRealmBonus = seedRealmIndex >= 0 && currentRealmIndex > seedRealmIndex ? 3 : 0;
      return basePriority + crossRealmBonus;
    };
    ready.sort((a, b) => effectivePriority(b) - effectivePriority(a));
    return ready;
  }

  /**
   * 移除种子
   * @param {Object} seed
   */
  removeSeed(seed) {
    gameState.karmaSeeds = gameState.karmaSeeds.filter(s => s !== seed);
    this._persistSeeds();
  }

  /**
   * 检查是否存在指定ID的种子
   * @param {string} id
   * @returns {boolean}
   */
  hasSeed(id) {
    return gameState.karmaSeeds.some(s => s.id === id);
  }

  /**
   * 检查是否存在指定ID的活跃种子（delay > 0，尚未发芽）
   * @param {string} id
   * @returns {Array}
   */
  getActiveSeeds(id) {
    if (!id) return [];
    return gameState.karmaSeeds.filter(s => s.id === id && s.delay > 0);
  }

  /**
   * 获取所有种子（用于调试/日志）
   * @returns {Object[]}
   */
  getAllSeeds() {
    return [...gameState.karmaSeeds];
  }

  /**
   * 获取格式化的所有活动因果种子（供因果簿 UI / 日志展现）
   * @returns {Object[]}
   */
  getPlantedSeeds() {
    const typeNames = {
      karma: '善因',
      grudge: '恶因',
      bloodline: '血脉因果',
      fate: '宿命因果'
    };
    return gameState.karmaSeeds.map(seed => {
      return {
        id: seed.id,
        seedType: seed.seedType || 'karma',
        seedTypeName: typeNames[seed.seedType] || '善因',
        delay: Math.max(0, seed.delay),
        realm: seed.realm || '任意境界',
        path: seed.path || null,
        priority: seed.priority || 0,
        originTurn: seed.originTurn || 0,
        originCard: seed.originCard || '未知来源',
        description: seed.description || `${seed.originTurn > 0 ? `在第 ${seed.originTurn} 次决断` : '在入世之初'}种下的${typeNames[seed.seedType] || '因果'}`
      };
    });
  }

  // ============ 种子类型系统（v2.0） ============

  /**
   * 按境界调整种子延迟
   * 低境界事件发酵慢，高境界因果加速
   */
  _adjustDelayByRealm(delay) {
    const realmDelayMod = {
      'qi': 1.5,          // 炼气期因果发酵慢
      'foundation': 1.2,
      'golden': 1.0,      // 金丹期基准
      'nascent': 0.8,
      'deity': 0.6,       // 化神期因果加速
      'tribulation': 0.5  // 渡劫期因果瞬息万变
    };
    const mod = realmDelayMod[gameState.realm] || 1.0;
    return Math.max(1, Math.round(delay * mod));
  }

  /**
   * 种子抵消检查
   * 同cancelGroup中，低优先级种子被高优先级种子抵消
   */
  _checkCancel(newSeed) {
    if (!newSeed.cancelGroup) return true;

    const conflicting = gameState.karmaSeeds.filter(s =>
      s.cancelGroup === newSeed.cancelGroup &&
      s.id !== newSeed.id &&
      s.delay > 0
    );

    for (const seed of conflicting) {
      if (seed.priority < newSeed.priority) {
        // 旧种子被抵消
        eventBus.emit('karma:seedCancelled', {
          cancelled: seed,
          cancelledBy: newSeed,
          reason: 'priority_override'
        });
        this.removeSeed(seed);
      } else if (seed.priority > newSeed.priority) {
        // 新种子被抵消（不加入）
        eventBus.emit('karma:seedCancelled', {
          cancelled: newSeed,
          cancelledBy: seed,
          reason: 'priority_override'
        });
        return false; // 新种子不加入
      } else {
        // 同优先级——两者都保留（势均力敌的因果）
        eventBus.emit('karma:seedConflict', {
          seedA: seed,
          seedB: newSeed,
          resolution: 'both_kept'
        });
      }
    }
    return true;
  }

  /**
   * 种子合并检查
   * 同seedType + 同mergeGroup 达到3个时，合并为一个高阶种子
   */
  _checkMerge(seedType, mergeGroup) {
    if (!mergeGroup) return;

    const sameGroup = gameState.karmaSeeds.filter(s =>
      s.seedType === seedType &&
      s.mergeGroup === mergeGroup &&
      s.delay > 0
    );

    const MERGE_THRESHOLD = 3;

    if (sameGroup.length >= MERGE_THRESHOLD) {
      // 按优先级排序，取最高的3个
      sameGroup.sort((a, b) => b.priority - a.priority);
      const merged = sameGroup.slice(0, MERGE_THRESHOLD);

      // 确定合并后的种子类型
      const mergeResultMap = {
        'karma': { id: 'merged:great_karma', seedType: 'fate', priority: 8, delay: 5 },
        'grudge': { id: 'merged:great_grudge', seedType: 'fate', priority: 8, delay: 5 },
        'bloodline': { id: 'merged:blood_debt', seedType: 'fate', priority: 9, delay: 3 },
        'fate': { id: 'merged:fate_convergence', seedType: 'fate', priority: 10, delay: 2 }
      };

      const result = mergeResultMap[seedType];
      if (result) {
        // 移除被合并的种子
        for (const seed of merged) {
          this.removeSeed(seed);
        }

        // 种下合并后的高阶种子
        const mergedSeed = {
          id: result.id,
          seedType: result.seedType,
          delay: result.delay,
          priority: result.priority,
          originTurn: gameState.getCausalDecisionIndex?.() ?? gameState.turn,
          originCard: 'merged',
          originChoice: 'merged',
          mergeGroup: null,
          cancelGroup: null
        };
        gameState.karmaSeeds.push(mergedSeed);
        this._recordPromise(mergedSeed.id);
        this._persistSeeds();

        eventBus.emit('karma:seedsMerged', {
          mergedFrom: merged.map(s => s.id),
          mergedTo: mergedSeed,
          mergeGroup
        });
      }
    }
  }

  /**
   * 获取种子统计（用于调试/UI展示）
   * @returns {Object} { karma: N, grudge: N, bloodline: N, fate: N, total: N }
   */
  getSeedStats() {
    const stats = { karma: 0, grudge: 0, bloodline: 0, fate: 0, total: 0 };
    for (const seed of gameState.karmaSeeds) {
      const type = seed.seedType || 'karma';
      stats[type] = (stats[type] || 0) + 1;
      stats.total++;
    }
    return stats;
  }

  /**
   * 将已被接受的 seed 登记成后续剧情可消费的承诺。
   * 取消发生在调用本方法之前，因此被拒绝的 seed 不会伪造 flag。
   */
  _recordPromise(seedId) {
    if (!seedId || typeof gameState.setFlag !== 'function') return;
    gameState.setFlag(seedId, true);
  }

  /**
   * pendingKarmaSeeds 是刷新恢复用的当前局快照；转世继承规则仍由
   * GameStateManager.reset(true) 单独裁定。
   */
  _persistSeeds() {
    if (!gameState.unlocks || !Array.isArray(gameState.karmaSeeds)) return;
    gameState.unlocks.pendingKarmaSeeds = gameState.karmaSeeds
      .map(seed => Object.assign({}, seed));
    if (typeof gameState.persistCausalSession === 'function') {
      gameState.persistCausalSession();
    } else if (typeof gameState.persistUnlocks === 'function') {
      gameState.persistUnlocks();
    }
  }

  // ============ 内部事件处理 ============

  _onReset() {
    // 状态重置时不需要特殊处理
  }
}

// 全局单例
const karmaSystem = new KarmaSystem();

if (typeof module !== 'undefined' && module.exports) {
  module.exports = KarmaSystem;
} else if (typeof window !== 'undefined') {
  window.KarmaSystem = KarmaSystem;
  window.karmaSystem = karmaSystem;
}
