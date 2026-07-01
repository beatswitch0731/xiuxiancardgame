/**
 * FlowDirector — 单一卡牌调度器
 * 
 * 替换 game.js 的 7 个 pending 标志 + CardSystem 的 9 级优先级链
 * 统一为一条优先级管道 + 5 阶段场景节奏控制
 *
 * 架构:
 *   ┌──────────────────────────────────────────────┐
 *   │              FlowDirector.getNextCard()        │
 *   ├──────────────────────────────────────────────┤
 *   │  P100  系统中断 (死亡/强制事件)                 │
 *   │  P95  战斗预警 (待处理的战斗)                   │
 *   │  P90  瓶颈突破                                 │
 *   │  P85  章节里程碑                               │
 *   │  P80  支线当前卡                               │
 *   │  P70  支线入口卡                               │
 *   │  P60  因果种子                                 │
 *   │  P55-42  重大叙事 (StoryNetwork + 预算门控)     │
 *   │  P40-28  次要叙事 (StoryNetwork + 预算门控)     │
 *   │  P25  商店遭遇                                 │
 *   │  P20  集市偶遇                                 │
 *   │  P15  挂起标志 (涟漪/天机/心魔/命盘)            │
 *   │  P10  阶段权重普通抽卡 (含情绪调节)             │
 *   └──────────────────────────────────────────────┘
 *
 * 场景阶段:
 *   CALM → BUILDUP → TENSION → CLIMAX → RESOLUTION → (循环)
 *
 * 集成 FIX-6 (叙事饥饿算法) + FIX-7 (情绪调节权重)
 */

var FlowDirector = (function() {

  // ════════════════════════════════════════
  //  场景阶段定义
  // ════════════════════════════════════════

  var PHASES = {
    CALM: {
      name: 'CALM',
      displayName: '风平浪静',
      weights: { normal: 70, lightStory: 15, shop: 10, exploration: 5 },
      advanceRate: 8,
      tensionTarget: 'low',
      desc: '日常修炼、小事件为主，让玩家放松'
    },
    BUILDUP: {
      name: 'BUILDUP',
      displayName: '暗流涌动',
      weights: { normal: 45, story: 20, shop: 10, exploration: 10, combatLight: 15 },
      advanceRate: 6,
      tensionTarget: 'medium',
      desc: '引入支线、轻战斗，节奏逐渐加快'
    },
    TENSION: {
      name: 'TENSION',
      displayName: '危机四伏',
      weights: { normal: 25, story: 15, combat: 35, challenge: 25 },
      advanceRate: 5,
      tensionTarget: 'high',
      desc: '高强度战斗+抉择，玩家压力达到高峰'
    },
    CLIMAX: {
      name: 'CLIMAX',
      displayName: '决战时刻',
      weights: { combat: 50, story: 20, challenge: 30 },
      advanceRate: 4,
      tensionTarget: 'critical',
      desc: 'Boss战/重大抉择，不可回头'
    },
    RESOLUTION: {
      name: 'RESOLUTION',
      displayName: '尘埃落定',
      weights: { normal: 35, story: 35, reward: 20, shop: 10 },
      advanceRate: 10,
      tensionTarget: 'low',
      desc: '战后收尾、奖励发放、故事交代'
    }
  };

  var PHASE_ORDER = ['CALM', 'BUILDUP', 'TENSION', 'CLIMAX', 'RESOLUTION'];

  // ════════════════════════════════════════
  //  饥饿追踪器 (FIX-6)
  // ════════════════════════════════════════

  var STARVATION_THRESHOLD = 12; // 连续 12 张卡未出某源 → 开始加权重
  var STARVATION_BOOST_MAX = 3.0; // 最大加权重倍数

  // ════════════════════════════════════════
  //  情绪状态映射 (FIX-7)
  // ════════════════════════════════════════

  function deriveMood(state) {
    if (!state) return 'neutral';
    var health = state.attributes ? (state.attributes.health || 100) : 100;
    var daoHeart = state.attributes ? (state.attributes.daoHeart || 50) : 50;
    var karmaBad = state.resources ? (state.resources.karmaBad || 0) : 0;
    var fortune = state.attributes ? (state.attributes.fortune || 50) : 50;

    // 道心崩溃 → 绝望
    if (daoHeart < 20) return 'despair';
    // 气血充盈 + 福缘高 → 昂扬
    if (health > 80 && fortune > 70) return 'inspired';
    // 恶因重 → 诡谲
    if (karmaBad > 60) return 'sinister';
    // 气血低 → 警觉
    if (health < 30) return 'cautious';
    return 'neutral';
  }

  // 情绪 → tag 权重调整
  var MOOD_TAG_WEIGHTS = {
    despair: { risk: 1.5, demon: 1.3, combat: 0.7, story: 1.4, lightStory: 1.5 },
    inspired: { combat: 1.3, exploration: 1.4, reward: 1.3, risk: 1.2 },
    sinister: { demon: 1.5, risk: 1.3, combat: 1.2, story: 1.1 },
    cautious: { shop: 1.4, exploration: 1.3, combat: 0.6, story: 1.2, lightStory: 1.3 },
    neutral: {}
  };

  // ════════════════════════════════════════
  //  FlowDirector 主体
  // ════════════════════════════════════════

  var instance = null;

  function create() {
    var _currentPhase = 'CALM';
    var _phaseProgress = 0;
    var _cardCount = 0;
    var _phaseHistory = [];
    var _interruptQueue = [];      // P100: 系统中断
    var _combatWarningPending = null; // P95: 战斗预警
    var _milestonePending = null;   // P85: 章节里程碑
    var _narrativeQueue = [];       // P55-28: 叙事队列
    var _pendingFlags = {};         // P15: 涟漪/天机/心魔/命盘/集市
    var _starvationTracker = {};    // { source: cardsSinceLastUse }
    var _lastDrawSource = null;
    var _phaseLog = [];             // 调试用

    // ── 初始化 ──
    function init() {
      _currentPhase = 'CALM';
      _phaseProgress = 0;
      _cardCount = 0;
      _phaseHistory = [];
      _interruptQueue = [];
      _combatWarningPending = null;
      _milestonePending = null;
      _narrativeQueue = [];
      _pendingFlags = {};
      _starvationTracker = {};
      _lastDrawSource = null;
      _phaseLog = [];
      _logPhase('init', 'FlowDirector initialized');
    }

    // ── 主入口：获取下一张卡 ──
    function getNextCard() {
      _cardCount++;
      _advancePhaseProgress();
      _tickStarvation();

      var card = null;
      var source = null;

      // P100: 系统中断
      if (_interruptQueue.length > 0) {
        var interrupt = _interruptQueue.shift();
        card = interrupt.card;
        source = 'interrupt:' + (interrupt.type || 'unknown');
      }

      // P95: 战斗预警
      if (!card && _combatWarningPending) {
        card = _combatWarningPending;
        _combatWarningPending = null;
        source = 'combat_warning';
      }

      // P90: 瓶颈突破 — 委托给 gameState
      if (!card && typeof gameState !== 'undefined' && gameState) {
        var breakthroughId = gameState.checkBreakthrough();
        if (breakthroughId && typeof cardSystem !== 'undefined' && cardSystem) {
          card = cardSystem.getCard(breakthroughId);
          source = 'breakthrough';
        }
      }

      // P85: 章节里程碑
      if (!card && _milestonePending) {
        card = _milestonePending;
        _milestonePending = null;
        // 标记已触发
        if (typeof chapterSystem !== 'undefined' && chapterSystem && card.threshold) {
          chapterSystem.markTriggered(card.realm, card.threshold);
        }
        source = 'milestone';
      }

      // P80-70: 支线 — 委托给 CardSystem 的事件桥接
      if (!card && typeof cardSystem !== 'undefined' && cardSystem) {
        var questCard = cardSystem._getQuestCurrentCard();
        if (questCard) {
          card = questCard;
          source = 'quest:current';
        }
      }

      if (!card && typeof cardSystem !== 'undefined' && cardSystem) {
        if (typeof eventBus !== 'undefined') {
          eventBus.emit('quest:checkTrigger', { gameState: gameState });
        }
        var questEntry = cardSystem._getQuestEntryCard();
        if (questEntry) {
          card = questEntry;
          source = 'quest:entry';
        }
      }

      // P60: 因果种子
      if (!card && typeof cardSystem !== 'undefined' && cardSystem) {
        var karmaCard = cardSystem._drawKarmaCard();
        if (karmaCard) {
          card = karmaCard;
          source = 'karma';
        }
      }

      // P55-28: 叙事队列 (含饥饿算法 FIX-6)
      if (!card && _narrativeQueue.length > 0) {
        var wrapper = _popNarrativeWithStarvation();
        if (wrapper) {
          card = wrapper.card || wrapper;
          source = 'narrative:' + (wrapper.priority || 'unknown');
        }
      }

      // P25: 商店遭遇 — 委托给 CardSystem
      if (!card && typeof cardSystem !== 'undefined' && cardSystem) {
        var shopCard = cardSystem._checkShopEncounter();
        if (shopCard) {
          card = shopCard;
          source = 'shop';
        }
      }

      // P20: 集市偶遇 (从 pendingFlags)
      if (!card && _pendingFlags.market) {
        card = _pendingFlags.market;
        _pendingFlags.market = null;
        source = 'market';
      }

      // P15: 挂起标志 (涟漪/天机/心魔/命盘)
      if (!card) {
        var flagOrder = ['innerDemon', 'destinyWheel', 'ripple', 'hint'];
        for (var i = 0; i < flagOrder.length; i++) {
          var key = flagOrder[i];
          if (_pendingFlags[key]) {
            card = _pendingFlags[key];
            _pendingFlags[key] = null;
            source = 'pending:' + key;
            break;
          }
        }
      }

      // P10: 阶段权重普通抽卡 (含情绪调节 FIX-7)
      if (!card && typeof cardSystem !== 'undefined' && cardSystem) {
        card = _drawPhaseWeighted();
        source = 'normal:' + _currentPhase;
      }

      // 最终兜底
      if (!card) {
        card = {
          id: 'flow_fallback',
          title: '潜心修炼',
          description: '你盘膝而坐，运转周天，吐纳灵气。修行之道，贵在坚持。',
          type: 'NORMAL',
          choices: {
            left: { text: '专注修炼', effects: { exp: 5 }, desc: '稳扎稳打提升修为。' },
            right: { text: '游历散心', effects: { fortune: 1 }, desc: '放松心情，或许会有意外收获。' }
          }
        };
        source = 'fallback';
      }

      _markSourceUsed(source);
      _lastDrawSource = source;

      // 附加 FlowDirector 元信息 (供 UI 使用)
      if (card && typeof card === 'object') {
        card._flowSource = source;
        card._flowPhase = _currentPhase;
      }

      return card;
    }

    // ════════════════════════════════════════
    //  阶段权重抽卡 (FIX-7: 情绪调节)
    // ════════════════════════════════════════

    function _drawPhaseWeighted() {
      var phase = PHASES[_currentPhase];
      if (!phase) return cardSystem.draw(); // 兜底走原始 draw

      var weights = phase.weights;
      var mood = deriveMood(gameState);
      var moodWeights = MOOD_TAG_WEIGHTS[mood] || {};

      // 根据情绪调整阶段权重
      var adjustedWeights = {};
      var totalWeight = 0;
      for (var key in weights) {
        var w = weights[key];
        // 情绪影响：如果该 source 的 tag 在情绪表中有调整
        if (moodWeights[key]) {
          w *= moodWeights[key];
        }
        // 饥饿加成
        var starvationBoost = _getStarvationBoost(key);
        if (starvationBoost > 1) {
          w *= starvationBoost;
        }
        adjustedWeights[key] = w;
        totalWeight += w;
      }

      if (totalWeight <= 0) return cardSystem._drawNormal();

      // 加权随机选择 source
      var rand = Math.random() * totalWeight;
      var cumulative = 0;
      var selectedSource = null;
      for (var src in adjustedWeights) {
        cumulative += adjustedWeights[src];
        if (rand <= cumulative) {
          selectedSource = src;
          break;
        }
      }

      // 根据 source 类型抽卡
      return _drawFromSource(selectedSource, mood, moodWeights);
    }

    function _drawFromSource(source, mood, moodWeights) {
      if (!source) return cardSystem._drawNormal();

      switch (source) {
        case 'normal':
          return _drawNormalWithMood(mood, moodWeights);

        case 'lightStory':
          // 轻叙事：从叙事队列中取低优先级的，或者生成环境叙事卡
          if (_narrativeQueue.length > 0) {
            // 找一个低优先级的叙事卡
            for (var i = _narrativeQueue.length - 1; i >= 0; i--) {
              if ((_narrativeQueue[i].priority || 50) < 40) {
                var wrapper = _narrativeQueue.splice(i, 1)[0];
                return wrapper.card || wrapper;
              }
            }
          }
          // 没有可用叙事卡 → 走普通卡
          return _drawNormalWithMood(mood, moodWeights);

        case 'story':
          // 重大叙事：从叙事队列中取高优先级的
          if (_narrativeQueue.length > 0) {
            var wrapper2 = _narrativeQueue.shift();
            return wrapper2.card || wrapper2;
          }
          return _drawNormalWithMood(mood, moodWeights);

        case 'shop':
          if (typeof cardSystem !== 'undefined' && cardSystem) {
            var shopCard = cardSystem._checkShopEncounter();
            if (shopCard) return shopCard;
          }
          return _drawNormalWithMood(mood, moodWeights);

        case 'exploration':
          // 探索：偏好有 exploration tag 的卡
          return _drawNormalWithMood(mood, moodWeights, ['exploration', 'discovery']);

        case 'combatLight':
        case 'combat':
          // 战斗：偏好有 combat tag 的卡
          return _drawNormalWithMood(mood, moodWeights, ['combat', 'enemy', 'danger']);

        case 'challenge':
          // 挑战：偏好有 challenge/risk tag 的卡
          return _drawNormalWithMood(mood, moodWeights, ['challenge', 'risk', 'trial']);

        case 'reward':
          // 奖励：偏好有 reward/fortune tag 的卡
          return _drawNormalWithMood(mood, moodWeights, ['reward', 'fortune', 'treasure']);

        default:
          return _drawNormalWithMood(mood, moodWeights);
      }
    }

    /**
     * 带情绪偏好的普通抽卡
     * @param {string} mood - 当前情绪
     * @param {Object} moodWeights - 情绪 tag 权重
     * @param {Array} preferredTags - 优先 tag 列表 (可选)
     */
    function _drawNormalWithMood(mood, moodWeights, preferredTags) {
      if (typeof cardSystem === 'undefined' || !cardSystem) return null;

      // 确保卡池已加载
      cardSystem._loadRealmCards(gameState.realm);

      var pool = cardSystem.getCardPool(gameState.realm);
      if (!pool || pool.length === 0) return cardSystem._drawNormal();

      var recentPlayed = new Set(gameState.cardsPlayed.slice(-8));
      var candidates = [];

      // 合并额外卡池
      var poolIds = new Set(pool.map(function(c) { return c.id; }));
      var extraCards = [];
      if (cardSystem.cardCache) {
        for (var id in cardSystem.cardCache) {
          var card = cardSystem.cardCache[id];
          if (!poolIds.has(id) && card && card.realm && 
              card.type !== 'DESTINY' && card.type !== 'BOTTLENECK') {
            extraCards.push(card);
          }
        }
      }
      var allPool = pool.concat(extraCards);

      for (var i = 0; i < allPool.length; i++) {
        var c = allPool[i];
        // 跳过特殊类型
        if (['DESTINY', 'BOTTLENECK', 'KARMA', 'QUEST'].indexOf(c.type) !== -1) continue;
        // 境界过滤
        if (c.realm && c.realm !== gameState.realm) continue;
        // 功法过滤
        if (c.path && c.path !== gameState.path) continue;
        // 一次性过滤
        if (c.once && gameState.cardsPlayed.indexOf(c.id) !== -1) continue;
        // 冷却
        if (recentPlayed.has(c.id)) continue;
        // Flags 条件
        if (c.requiresFlags && !gameState.checkFlags(c.requiresFlags)) continue;
        if (c.forbiddenFlags) {
          var blocked = false;
          for (var fk in c.forbiddenFlags) {
            var fv = c.forbiddenFlags[fk];
            if (fv === null ? gameState.hasFlag(fk) : gameState.getFlag(fk) === fv) {
              blocked = true;
              break;
            }
          }
          if (blocked) continue;
        }

        var weight = c.weight !== undefined ? c.weight : 5;

        // 功法亲和
        if (c.path === gameState.path) weight *= 1.5;

        // 福缘影响
        if (gameState.attributes && gameState.attributes.fortune > 70 && 
            c.tags && !c.tags.includes('risk')) {
          weight += 2;
        }

        // 恶因影响
        if (gameState.attributes && gameState.attributes.karmaBad > 50 && 
            c.tags && c.tags.includes('demon')) {
          weight *= 1.3;
        }

        // FIX-7: 情绪 tag 权重调整
        if (c.tags && moodWeights) {
          for (var tag in moodWeights) {
            if (c.tags.indexOf(tag) !== -1) {
              weight *= moodWeights[tag];
            }
          }
        }

        // 优先 tag 加成
        if (preferredTags && c.tags) {
          for (var pi = 0; pi < preferredTags.length; pi++) {
            if (c.tags.indexOf(preferredTags[pi]) !== -1) {
              weight *= 2.0;
              break;
            }
          }
        }

        for (var j = 0; j < Math.max(1, Math.round(weight)); j++) {
          candidates.push(c);
        }
      }

      if (candidates.length === 0) {
        var fallback = cardSystem.getCard('q_meditation');
        return fallback || cardSystem._drawNormal();
      }

      return candidates[Math.floor(Math.random() * candidates.length)];
    }

    // ════════════════════════════════════════
    //  饥饿算法 (FIX-6)
    // ════════════════════════════════════════

    function _tickStarvation() {
      var sources = ['normal', 'lightStory', 'story', 'shop', 'exploration', 
                     'combat', 'combatLight', 'challenge', 'reward',
                     'narrative', 'karma', 'quest', 'milestone'];
      for (var i = 0; i < sources.length; i++) {
        var s = sources[i];
        if (!_starvationTracker[s]) _starvationTracker[s] = 0;
        _starvationTracker[s]++;
      }
    }

    function _markSourceUsed(source) {
      // 从 source 字符串提取类别
      var category = source;
      if (source.indexOf(':') !== -1) {
        category = source.split(':')[0];
      }
      // 映射到阶段 source 类别
      var sourceMap = {
        'interrupt': 'interrupt',
        'combat_warning': 'combat',
        'breakthrough': 'normal',
        'milestone': 'milestone',
        'quest': 'quest',
        'karma': 'karma',
        'narrative': 'narrative',
        'shop': 'shop',
        'market': 'shop',
        'pending': 'normal',
        'normal': 'normal',
        'fallback': 'normal'
      };
      var mapped = sourceMap[category] || category;
      _starvationTracker[mapped] = 0;
      
      // 也重置相关的阶段 source
      if (mapped === 'normal') {
        _starvationTracker['lightStory'] = 0;
      }
    }

    function _getStarvationBoost(source) {
      var count = _starvationTracker[source];
      if (!count || count < STARVATION_THRESHOLD) return 1.0;
      // 线性增长，上限 STARVATION_BOOST_MAX
      var excess = count - STARVATION_THRESHOLD;
      var boost = 1.0 + (excess / 20) * (STARVATION_BOOST_MAX - 1.0);
      return Math.min(boost, STARVATION_BOOST_MAX);
    }

    /**
     * FIX-6: 从叙事队列弹出时考虑饥饿
     * 高优先级叙事卡如果等待太久，会被加权提前弹出
     */
    function _popNarrativeWithStarvation() {
      if (_narrativeQueue.length === 0) return null;

      // 按优先级排序（降序）
      _narrativeQueue.sort(function(a, b) {
        return (b.priority || 50) - (a.priority || 50);
      });

      // 检查最高优先级是否有饥饿加成
      var top = _narrativeQueue[0];
      var topPriority = top.priority || 50;
      var starvationCount = _starvationTracker['narrative'] || 0;

      // 如果叙事源饥饿超过阈值，降低弹出门槛
      if (starvationCount > STARVATION_THRESHOLD + 5) {
        // 饥饿模式：弹出第一个，不管优先级多低
        return _narrativeQueue.shift();
      }

      // 正常模式：弹出最高优先级
      return _narrativeQueue.shift();
    }

    // ════════════════════════════════════════
    //  阶段推进
    // ════════════════════════════════════════

    function _advancePhaseProgress() {
      var phase = PHASES[_currentPhase];
      if (!phase) return;
      _phaseProgress += phase.advanceRate;

      if (_phaseProgress >= 100) {
        _transitionPhase();
      }
    }

    function _transitionPhase() {
      var currentIdx = PHASE_ORDER.indexOf(_currentPhase);
      var nextIdx = (currentIdx + 1) % PHASE_ORDER.length;
      var nextPhaseName = PHASE_ORDER[nextIdx]; // 字符串，如 'BUILDUP'
      var nextPhase = PHASES[nextPhaseName];    // 取阶段对象

      _phaseHistory.push({
        from: _currentPhase,
        to: nextPhaseName,
        cardCount: _cardCount,
        timestamp: Date.now()
      });

      // 限制历史长度
      if (_phaseHistory.length > 20) {
        _phaseHistory = _phaseHistory.slice(-20);
      }

      _currentPhase = nextPhaseName;
      _phaseProgress = 0;
      _logPhase('transition', _currentPhase + ' (' + (nextPhase ? nextPhase.displayName : '') + ')');

      // 发射阶段转换事件（供 UI 监听）
      if (typeof eventBus !== 'undefined') {
        eventBus.emit('flow:phaseChanged', {
          phase: _currentPhase,
          displayName: nextPhase ? nextPhase.displayName : nextPhaseName,
          desc: nextPhase ? nextPhase.desc : '',
          cardCount: _cardCount
        });
      }
    }

    function _logPhase(type, msg) {
      _phaseLog.push({ type: type, msg: msg, time: Date.now(), cardCount: _cardCount });
      if (_phaseLog.length > 50) _phaseLog = _phaseLog.slice(-50);
    }

    // ════════════════════════════════════════
    //  公共 API: 入队方法
    // ════════════════════════════════════════

    /**
     * 入队系统中断 (P100)
     * @param {Object} card - 卡牌
     * @param {string} type - 中断类型 (death/forced/etc)
     */
    function enqueueInterrupt(card, type) {
      _interruptQueue.push({ card: card, type: type || 'forced' });
    }

    /**
     * 设置战斗预警 (P95)
     */
    function setCombatWarning(card) {
      _combatWarningPending = card;
    }

    /**
     * 设置章节里程碑 (P85)
     */
    function setMilestone(card) {
      _milestonePending = card;
    }

    /**
     * 入队叙事卡 (P55-28)
     * @param {Object} card - 卡牌
     * @param {number} priority - 优先级 (55=最高叙事, 28=最低)
     */
    function enqueueNarrative(card, priority) {
      _narrativeQueue.push({ card: card, priority: priority || 50 });
    }

    /**
     * 设置挂起标志 (P15)
     * @param {string} type - innerDemon/destinyWheel/ripple/hint/market
     * @param {Object} card - 卡牌
     */
    function setPending(type, card) {
      _pendingFlags[type] = card;
    }

    /**
     * 手动设置阶段
     */
    function setPhase(phaseName) {
      if (PHASES[phaseName]) {
        _currentPhase = phaseName;
        _phaseProgress = 0;
        _logPhase('manual_set', phaseName);
      }
    }

    /**
     * 强制推进到下一阶段
     */
    function forceAdvancePhase() {
      _transitionPhase();
    }

    // ════════════════════════════════════════
    //  公共 API: 查询方法
    // ════════════════════════════════════════

    function getPhaseInfo() {
      var phase = PHASES[_currentPhase];
      return {
        phase: _currentPhase,
        displayName: phase ? phase.displayName : '未知',
        desc: phase ? phase.desc : '',
        progress: Math.round(_phaseProgress),
        cardCount: _cardCount,
        weights: phase ? phase.weights : {},
        mood: deriveMood(gameState),
        lastSource: _lastDrawSource,
        narrativeQueueLength: _narrativeQueue.length,
        hasInterrupt: _interruptQueue.length > 0,
        hasCombatWarning: !!_combatWarningPending,
        hasMilestone: !!_milestonePending,
        hasPending: hasPending()
      };
    }

    function getStarvationReport() {
      var report = {};
      for (var s in _starvationTracker) {
        if (_starvationTracker[s] > STARVATION_THRESHOLD) {
          report[s] = {
            cardsSinceLastUse: _starvationTracker[s],
            boost: _getStarvationBoost(s)
          };
        }
      }
      return report;
    }

    function getPhaseHistory() {
      return _phaseHistory.slice();
    }

    function getNarrativeQueueLength() {
      return _narrativeQueue.length;
    }

    function hasPending() {
      return _interruptQueue.length > 0 ||
             !!_combatWarningPending ||
             !!_milestonePending ||
             _narrativeQueue.length > 0 ||
             _hasPendingFlags();
    }

    function _hasPendingFlags() {
      for (var k in _pendingFlags) {
        if (_pendingFlags[k]) return true;
      }
      return false;
    }

    function reset() {
      init();
    }

    // ════════════════════════════════════════
    //  导出
    // ════════════════════════════════════════

    return {
      init: init,
      reset: reset,
      getNextCard: getNextCard,

      // 入队
      enqueueInterrupt: enqueueInterrupt,
      setCombatWarning: setCombatWarning,
      setMilestone: setMilestone,
      enqueueNarrative: enqueueNarrative,
      setPending: setPending,

      // 阶段控制
      setPhase: setPhase,
      forceAdvancePhase: forceAdvancePhase,

      // 查询
      getPhaseInfo: getPhaseInfo,
      getStarvationReport: getStarvationReport,
      getPhaseHistory: getPhaseHistory,
      getNarrativeQueueLength: getNarrativeQueueLength,
      hasPending: hasPending,

      // 静态
      PHASES: PHASES,
      PHASE_ORDER: PHASE_ORDER
    };
  }

  return {
    create: create,
    get PHASES() { return PHASES; },
    get PHASE_ORDER() { return PHASE_ORDER; },
    deriveMood: deriveMood,
    MOOD_TAG_WEIGHTS: MOOD_TAG_WEIGHTS
  };
})();

// 导出
if (typeof module !== 'undefined' && module.exports) {
  module.exports = FlowDirector;
}
if (typeof window !== 'undefined') {
  window.FlowDirector = FlowDirector;
}
