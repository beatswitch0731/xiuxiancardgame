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

  var LOW_RESOURCE_RATIO = 1 / 3;
  var HIGH_HEALTH_RATIO = 0.8;

  function _finiteNumber(value, fallback) {
    var number = Number(value);
    return Number.isFinite(number) ? number : fallback;
  }

  function _resolvePositiveMax(state, propertyName, getterName, fallback) {
    var getterValue = NaN;
    if (state && typeof state[getterName] === 'function') {
      getterValue = Number(state[getterName]());
    }
    if (Number.isFinite(getterValue) && getterValue > 0) return getterValue;

    var propertyValue = Number(state && state[propertyName]);
    if (Number.isFinite(propertyValue) && propertyValue > 0) return propertyValue;
    return fallback;
  }

  function _normalizedRatio(value, max) {
    return Math.max(0, Math.min(1, value / max));
  }

  function deriveMood(state) {
    if (!state) return 'neutral';
    var attributes = state.attributes || {};
    var health = _finiteNumber(attributes.health, 100);
    var daoHeart = _finiteNumber(attributes.daoHeart, 50);
    var karmaBad = _finiteNumber(attributes.karmaBad, 0);
    var fortune = _finiteNumber(attributes.fortune, 50);
    var maxHealth = _resolvePositiveMax(state, 'maxHealth', 'getActualMaxHealth', 100);
    var maxDaoHeart = _resolvePositiveMax(state, 'maxDaoHeart', 'getActualMaxDaoHeart', 100);
    var healthRatio = _normalizedRatio(health, maxHealth);
    var daoHeartRatio = _normalizedRatio(daoHeart, maxDaoHeart);

    // 微数值模型按“剩余占比”表达危险，而不是假定属性上限为 100。
    if (daoHeartRatio <= LOW_RESOURCE_RATIO) return 'despair';
    // 气血充盈 + 福缘高 → 昂扬
    if (healthRatio > HIGH_HEALTH_RATIO && fortune > 70) return 'inspired';
    // 恶因重 → 诡谲
    if (karmaBad > 60) return 'sinister';
    // 气血低 → 警觉
    if (healthRatio <= LOW_RESOURCE_RATIO) return 'cautious';
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

  function create(options) {
    options = options || {};
    var _currentPhase = 'CALM';
    var _phaseProgress = 0;
    var _cardCount = 0;
    var _phaseHistory = [];
    var _interruptQueue = [];      // P100: 系统中断
    var _combatWarningPending = null; // P95: 战斗预警
    var _milestonePending = null;   // P85: 章节里程碑
    var _realmGateState = null;     // 唯一破境 Gate: in_progress/deferred/resolved
    var _narrativeQueue = [];       // P55-28: 叙事队列
    var _pendingFlags = {};         // P15: 涟漪/天机/心魔/命盘/集市
    var _starvationTracker = {};    // { source: cardsSinceLastUse }
    var _lastDrawSource = null;
    var _phaseLog = [];             // 调试用
    var _encounterDirectorRef = options.encounterDirectorRef || null;

    function _getNarrativeDirector() {
      return typeof narrativeDirector !== 'undefined' && narrativeDirector
        ? narrativeDirector
        : null;
    }

    function _getEncounterDirector() {
      if (_encounterDirectorRef) return _encounterDirectorRef;
      return typeof encounterDirector !== 'undefined' && encounterDirector
        ? encounterDirector
        : null;
    }

    function _receiveNarrativeEvent(data, defaultPriority, defaultSource) {
      if (!data) return;
      var card = data.card || data;
      if (!card || !card.id) return;
      var rawPriority = data.priority !== undefined ? data.priority : card._narrativePriority;
      var priority = Number(rawPriority);
      enqueueNarrative(
        card,
        Number.isFinite(priority) ? priority : defaultPriority,
        data.source || card._narrativeSource || defaultSource
      );
    }

    function _onStoryNarrative(data) {
      _receiveNarrativeEvent(data, 45, 'storynetwork');
    }

    function _onCompanionNarrative(data) {
      _receiveNarrativeEvent(data, 50, 'companion');
    }

    function _isLocationCombatInvitation(card) {
      return !!(card && card.deliveryClass === 'location_combat_invitation');
    }

    // A physical invitation to a combat place is a promise made in the
    // current scene. It must not enter the ordinary ambient queue, where
    // unrelated tutorial/quest cards can consume its six-turn TTL before the
    // player ever sees it. Keep the raw authored card until Flow reaches a
    // normal narrative gap, then create a fresh, fully revalidated envelope.
    function _holdLocationCombatInvitation(data) {
      var card = data && (data.card || data);
      if (!_isLocationCombatInvitation(card) || !card.id) return false;
      if (!_isNarrativeValid(card)) return false;

      var existing = _pendingFlags.locationInvitation;
      if (existing && existing.card) {
        return _semanticKey(existing.card) === _semanticKey(card);
      }

      var rawPriority = data && data.priority !== undefined
        ? data.priority
        : card._narrativePriority;
      var priority = Number(rawPriority);
      _pendingFlags.locationInvitation = {
        card: _cloneSerializable(card, null),
        priority: Number.isFinite(priority) ? priority : 40,
        source: (data && data.source) || card._narrativeSource || 'faction'
      };
      return !!_pendingFlags.locationInvitation.card;
    }

    function _takeHeldLocationCombatInvitation() {
      var held = _pendingFlags.locationInvitation;
      if (!held) return null;
      var card = held.card;
      if (!_isLocationCombatInvitation(card) || !_isNarrativeValid(card)) {
        _pendingFlags.locationInvitation = null;
        return null;
      }

      var priority = Number(held.priority);
      if (!Number.isFinite(priority)) priority = 40;
      if (!_canServeNarrativePriority(priority)) return null;

      var director = _getNarrativeDirector();
      var envelope = director && typeof director.createEnvelope === 'function'
        ? director.createEnvelope(card, priority, held.source || 'faction')
        : {
            card: card,
            priority: priority,
            source: held.source || 'faction'
          };
      if (!envelope) {
        // createEnvelope has already recorded the concrete invalidation.
        _pendingFlags.locationInvitation = null;
        return null;
      }

      _pendingFlags.locationInvitation = null;
      if (director && typeof director.onPresented === 'function') {
        director.onPresented(envelope);
      }
      _spendNarrativePriority(priority);
      return envelope;
    }

    function _onFactionNarrative(data) {
      var card = data && (data.card || data);
      if (_isLocationCombatInvitation(card)) {
        _holdLocationCombatInvitation(data);
        return;
      }
      _receiveNarrativeEvent(data, 40, 'faction');
    }

    function _onNpcNarrative(data) {
      _receiveNarrativeEvent(data, 30, 'npc');
    }

    function _cardNpcIds(card) {
      var ids = [];
      if (card && typeof card.npcId === 'string') ids.push(card.npcId);
      if (card && typeof card.compId === 'string') ids.push(card.compId);
      if (card && Array.isArray(card.npcIds)) ids = ids.concat(card.npcIds);
      return ids.filter(function(id, index) {
        return typeof id === 'string' && id && ids.indexOf(id) === index;
      });
    }

    function _isLifecycleValid(card) {
      if (typeof worldContinuityStore === 'undefined' || !worldContinuityStore) return true;
      var ids = _cardNpcIds(card);
      if (ids.length === 0) return true;
      var manifestation = card.manifestation || 'PHYSICAL';
      return ids.every(function(npcId) {
        return worldContinuityStore.canManifest(npcId, manifestation);
      });
    }

    function _semanticKey(card) {
      return typeof narrativeLedger !== 'undefined' && narrativeLedger
        && typeof narrativeLedger.getSemanticKey === 'function'
        ? narrativeLedger.getSemanticKey(card)
        : (card && card.id);
    }

    function _causalFactInstanceId(card) {
      if (card && typeof card.causalFactInstanceId === 'string' && card.causalFactInstanceId) {
        return card.causalFactInstanceId;
      }
      // B5-B snapshots created before the explicit field still use the stable
      // fact id in their card id. Read it only as a migration fallback, so an
      // old saved duplicate cannot resurrect an already consumed consequence.
      var legacyId = card && typeof card.id === 'string' ? card.id : '';
      var legacyMatch = legacyId.match(/^narrative_fact:(fact:[^:]+:[^:]+):[^:]+$/);
      return legacyMatch ? legacyMatch[1] : null;
    }

    function _isNarrativeValid(card) {
      if (!_isLifecycleValid(card)) return false;
      // Causal-fact consumers carry their immutable fact id. Unlike an
      // ordinary once card, their availability changes when the player
      // resolves the fact; stale saved interrupts must therefore disappear
      // before they can reach the choice UI.
      var causalFactInstanceId = _causalFactInstanceId(card);
      if (causalFactInstanceId) {
        var fact = typeof narrativeLedger !== 'undefined' && narrativeLedger
          && typeof narrativeLedger.getFact === 'function'
          ? narrativeLedger.getFact(causalFactInstanceId)
          : null;
        if (!fact || fact.status !== 'active') return false;
      }
      return typeof narrativeLedger === 'undefined' || !narrativeLedger
        || typeof narrativeLedger.canPresent !== 'function'
        || narrativeLedger.canPresent(card, { state: gameState });
    }

    function _takeNarrativeEnvelope(filter) {
      var director = _getNarrativeDirector();
      if (director && typeof director.takeNext === 'function') {
        return director.takeNext(_narrativeQueue, {
          filter: typeof filter === 'function' ? filter : function() { return true; },
          canServe: function(envelope) {
            return _canServeNarrativePriority(Number(envelope.priority) || 50);
          }
        });
      }
      return null;
    }

    function _takeNarrativeAtOrAbove(minPriority) {
      var threshold = Number(minPriority);
      if (!Number.isFinite(threshold)) threshold = 90;
      var director = _getNarrativeDirector();
      var selected = director && typeof director.takeNext === 'function'
        ? director.takeNext(_narrativeQueue, {
            filter: function(envelope) {
              return envelope && envelope.card && envelope.card._isThreadCard === true
                && Number(envelope.priority) >= threshold;
            },
            canServe: function(envelope) {
              return _canServeNarrativePriority(Number(envelope.priority) || threshold);
            },
            preemptFocus: true
          })
        : null;
      if (!selected && !director) {
        var bestIndex = -1;
        for (var i = 0; i < _narrativeQueue.length; i++) {
          var candidate = _narrativeQueue[i];
          var priority = Number(candidate && candidate.priority);
          var candidateCard = candidate && (candidate.card || candidate);
          if (!candidateCard || candidateCard._isThreadCard !== true) continue;
          if (!Number.isFinite(priority) || priority < threshold) continue;
          if (!_canServeNarrativePriority(priority)) continue;
          if (!_isNarrativeValid(candidateCard)) continue;
          if (bestIndex < 0 || priority > Number(_narrativeQueue[bestIndex].priority)) {
            bestIndex = i;
          }
        }
        if (bestIndex >= 0) selected = _narrativeQueue.splice(bestIndex, 1)[0];
      }
      if (selected) _spendNarrativePriority(Number(selected.priority) || threshold);
      return selected;
    }

    function invalidateNarrativeByNpc(npcId) {
      if (!npcId) return 0;
      var before = _narrativeQueue.length;
      var director = _getNarrativeDirector();
      if (director && typeof director.prune === 'function') {
        director.prune(_narrativeQueue);
        return before - _narrativeQueue.length;
      }
      _narrativeQueue = _narrativeQueue.filter(function(wrapper) {
        var card = wrapper && wrapper.card ? wrapper.card : wrapper;
        return !_cardNpcIds(card).includes(npcId) || _isLifecycleValid(card);
      });
      return before - _narrativeQueue.length;
    }

    function _onNpcLifecycleChanged(data) {
      invalidateNarrativeByNpc(data && data.npcId);
    }

    function _bindNarrativeEventSources() {
      if (typeof eventBus === 'undefined' || !eventBus || typeof eventBus.on !== 'function') return;
      var bindings = [
        ['storynetwork:narrativeCard', _onStoryNarrative],
        ['companion:eventCard', _onCompanionNarrative],
        ['faction:eventCard', _onFactionNarrative],
        ['npc:encounterCard', _onNpcNarrative],
        ['npc:lifecycleChanged', _onNpcLifecycleChanged]
      ];
      for (var i = 0; i < bindings.length; i++) {
        if (typeof eventBus.off === 'function') {
          eventBus.off(bindings[i][0], bindings[i][1]);
        }
        eventBus.on(bindings[i][0], bindings[i][1]);
      }
    }

    // ── 初始化 ──
    function init() {
      _currentPhase = 'CALM';
      _phaseProgress = 0;
      _cardCount = 0;
      _phaseHistory = [];
      _interruptQueue = [];
      _combatWarningPending = null;
      _milestonePending = null;
      _realmGateState = null;
      _narrativeQueue = [];
      _pendingFlags = {};
      _starvationTracker = {};
      _lastDrawSource = null;
      _phaseLog = [];
      var director = _getNarrativeDirector();
      if (director && typeof director.init === 'function') {
        director.init({
          gameStateRef: typeof gameState !== 'undefined' ? gameState : null,
          ledgerRef: typeof narrativeLedger !== 'undefined' ? narrativeLedger : null,
          continuityRef: typeof worldContinuityStore !== 'undefined' ? worldContinuityStore : null,
          threadEngineRef: typeof storyThreadEngine !== 'undefined' && storyThreadEngine
            ? storyThreadEngine
            : (typeof threadEngine !== 'undefined' ? threadEngine : null)
        });
      }
      var combatDirector = _getEncounterDirector();
      if (combatDirector && typeof combatDirector.init === 'function') {
        combatDirector.init({
          gameStateRef: typeof gameState !== 'undefined' ? gameState : null,
          // window.cardSystem is the authoritative runtime instance. Prefer it
          // over the lexical compatibility singleton so tests, reload recovery
          // and alternate containers cannot be silently rebound to an empty
          // CardSystem created while this script was evaluated.
          cardSystemRef: typeof window !== 'undefined' && window.cardSystem
            ? window.cardSystem
            : (typeof cardSystem !== 'undefined' ? cardSystem : null),
          eventBusRef: typeof eventBus !== 'undefined' ? eventBus : null,
          configRef: typeof dataLoader !== 'undefined' && dataLoader?.loadSync
            ? dataLoader.loadSync('combat:encounter_director')
            : null
        });
      }
      _bindNarrativeEventSources();
      _logPhase('init', 'FlowDirector initialized');
    }

    // ── 主入口：获取下一张卡 ──
    function getNextCard() {
      _cardCount++;
      _advancePhaseProgress();
      _tickStarvation();

      var card = null;
      var source = null;

      // P100: 死亡叙事仍由唯一调度入口仲裁
      // Death precedes every other persisted interrupt: an outstanding
      // contract cannot mask a terminal state. Non-terminal contractual
      // interrupts (such as a due ghost-market debt) still arrive before
      // combat warnings and normal narrative draws below.
      if (typeof gameState !== 'undefined' && gameState && gameState.dead &&
          typeof cardSystem !== 'undefined' && cardSystem &&
          typeof cardSystem._drawDeathCard === 'function') {
        card = cardSystem._drawDeathCard();
        source = 'death';
      }

      // P100: 系统中断
      while (!card && _interruptQueue.length > 0) {
        var interrupt = _interruptQueue.shift();
        // A fact-consumer can be resolved while another older interrupt is
        // ahead of it. Do not surface its stale durable duplicate afterwards.
        if (interrupt.type === 'causal_fact' && !_isNarrativeValid(interrupt.card)) continue;
        card = interrupt.card;
        source = 'interrupt:' + (interrupt.type || 'unknown');
      }

      // P95: 战斗预警
      if (!card && _combatWarningPending) {
        card = _combatWarningPending;
        _combatWarningPending = null;
        source = 'combat_warning';
      }

      // P90+: authored continuity lock. A priority-90+ primary beat already
      // passed its eligibility/location/cooldown checks. It must be arbitrated
      // before both lower-realm cadence and the post-ascension early return;
      // otherwise a queued epilogue becomes permanently pending in the upper
      // realm because every draw exits through CardSystem first.
      if (!card && _narrativeQueue.length > 0) {
        var continuityEnvelope = _takeNarrativeAtOrAbove(90);
        if (continuityEnvelope) {
          card = continuityEnvelope.card || continuityEnvelope;
          source = 'narrative:continuity';
        }
      }

      // 飞升续章是独立世界层。系统中断与已冻结战斗仍可优先结算；
      // 已通过资格检查的高优先级作者化回响也可先兑现；其余下界突破、
      // 任务、低优先级叙事、商店与营地全部绕开，由 CardSystem 的上界
      // 入口恢复显式续卡或抽取 upper_realm 内容。
      var upperRealmActive = typeof gameState !== 'undefined' && gameState && (
        typeof gameState.hasFlag === 'function'
          ? gameState.hasFlag('post_ascension_active')
          : !!(gameState.flags && gameState.flags.post_ascension_active)
      );
      if (!card && upperRealmActive && typeof cardSystem !== 'undefined' && cardSystem) {
        card = cardSystem.draw();
        source = 'upper_realm';
        _markSourceUsed(source);
        _lastDrawSource = source;
        if (card && typeof card === 'object') {
          card._flowSource = source;
          card._flowPhase = _currentPhase;
        }
        return card;
      }

      // P90: 唯一破境 Gate。章节终章是主入口，旧 break_* 仅在章节系统
      // 不可用时兜底。旧 breakthrough_paused_cooldown 不再直接阻断：
      // 暂缓选项已经降低修为，重新修满即代表冷却结束。
      // Regular encounters have a player-visible hard deadline independent
      // from their ordinary due date. A long authored dungeon may consume the
      // reserved deferral window; once that happens, a repeated Realm Gate
      // cannot keep starving the regular combat lane beyond twelve decisions.
      if (!card) {
        var hardDeadlineScheduler = _getEncounterDirector();
        if (hardDeadlineScheduler
          && typeof hardDeadlineScheduler.isCadenceHardDue === 'function'
          && hardDeadlineScheduler.isCadenceHardDue()
          && typeof hardDeadlineScheduler.takeDueEncounter === 'function') {
          var hardDueEncounter = hardDeadlineScheduler.takeDueEncounter();
          if (hardDueEncounter && hardDueEncounter.card) {
            card = hardDueEncounter.card;
            source = 'encounter:hard_deadline';
            if (typeof hardDeadlineScheduler.markPresented === 'function') {
              hardDeadlineScheduler.markPresented(card);
            }
          }
        }
      }

      if (!card) {
        var realmGate = _resolveRealmGateCandidate();
        if (realmGate && realmGate.card) {
          card = realmGate.card;
          source = realmGate.source;
        }
      }

      // P88: EncounterDirector 只在死亡/冻结战斗/唯一 Realm Gate 与作者化
      // 连续节点之后调度普通、精英与关系/任务战。它不能制造或替代 Gate Boss。
      if (!card) {
        var encounterScheduler = _getEncounterDirector();
        if (encounterScheduler && typeof encounterScheduler.takeDueEncounter === 'function') {
          var dueEncounter = encounterScheduler.takeDueEncounter();
          if (dueEncounter && dueEncounter.card) {
            card = dueEncounter.card;
            source = 'encounter:' + (dueEncounter.reason || 'cadence');
            if (typeof encounterScheduler.markPresented === 'function') {
              encounterScheduler.markPresented(card);
            }
          }
        }
      }

      // P85: 章节里程碑
      if (!card && _milestonePending && (
        !_isTerminalRealmGate(_milestonePending) || _isRealmEncounterQuotaReady()
      )) {
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

      // P55: 转世回响
      if (!card && typeof cardSystem !== 'undefined' && cardSystem &&
          typeof cardSystem._drawReincarnationCard === 'function' &&
          _canServeNarrativePriority(55)) {
        var reincarnationCard = cardSystem._drawReincarnationCard();
        if (reincarnationCard) {
          _spendNarrativePriority(55);
          card = reincarnationCard;
          source = 'reincarnation';
        }
      }

      // P55-28: 叙事队列 (含饥饿算法 FIX-6)
      if (!card && _narrativeQueue.length === 0) {
        _collectNarrativeSources();
      }
      if (!card && _narrativeQueue.length > 0) {
        var wrapper = _popNarrativeWithStarvation();
        if (wrapper) {
          card = wrapper.card || wrapper;
          source = 'narrative:' + (wrapper.priority || 'unknown');
        }
      }

      // A held location-combat invitation is deliberately lower than every
      // system/quest/ordinary narrative route above, but higher than shops,
      // pending flavor flags and normal draws. This is the first safe gap:
      // no active authored narrative was deliverable this turn.
      if (!card) {
        var locationInvitation = _takeHeldLocationCombatInvitation();
        if (locationInvitation) {
          card = locationInvitation.card || locationInvitation;
          source = 'narrative:location_invitation';
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

      // P24: 营地遭遇
      if (!card && typeof cardSystem !== 'undefined' && cardSystem &&
          typeof cardSystem._checkCampEncounter === 'function') {
        var campCard = cardSystem._checkCampEncounter();
        if (campCard) {
          card = campCard;
          source = 'camp';
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

    function _isTerminalRealmGate(card) {
      return !!(card &&
        Number(card.threshold) === 100 &&
        card.combatRewards &&
        card.combatRewards.breakSuccess);
    }

    function _isRealmEncounterQuotaReady() {
      var director = _getEncounterDirector();
      if (!director || typeof director.isRealmGateReady !== 'function') return true;
      return director.isRealmGateReady(
        typeof gameState !== 'undefined' && gameState ? gameState.realm : undefined
      );
    }

    function _getBreakthroughCardId() {
      if (typeof gameState === 'undefined' || !gameState ||
          typeof gameState.checkBreakthrough !== 'function') {
        return null;
      }
      return gameState.checkBreakthrough();
    }

    function _isSameRealmGateState() {
      return !!(_realmGateState &&
        typeof gameState !== 'undefined' &&
        gameState &&
        _realmGateState.realm === gameState.realm);
    }

    /**
     * P90 的唯一破境候选仲裁。
     * - 已入队的普通里程碑保留给 P85；
     * - terminal milestone 是首选；
     * - chapterSystem 不可用时才回退旧 break_*。
     */
    function _resolveRealmGateCandidate() {
      var breakthroughId = _getBreakthroughCardId();

      if (!breakthroughId) {
        if (_realmGateState && _realmGateState.status !== 'resolved') {
          _realmGateState = null;
        }
        return null;
      }

      // Reaching the cultivation cap makes the Gate eligible, but must not
      // erase the ordinary/quest/elite material promised for this realm. Keep
      // the authored terminal milestone queued while EncounterDirector serves
      // the remaining visible quota through its public cadence path.
      if (!_isRealmEncounterQuotaReady()) return null;

      if (_realmGateState && !_isSameRealmGateState()) {
        _realmGateState = null;
      }

      if (_isSameRealmGateState()) {
        if (_realmGateState.status === 'in_progress' ||
            _realmGateState.status === 'resolved') {
          return null;
        }
        if (_realmGateState.status === 'deferred') {
          if (_realmGateState.deferDrawsRemaining > 0) {
            _realmGateState.deferDrawsRemaining--;
            if (_realmGateState.deferDrawsRemaining <= 0) {
              _realmGateState.status = 'available';
            }
            return null;
          }
          _realmGateState.status = 'available';
        }
      }

      // 不吞掉已经排队的普通章节里程碑。
      if (_milestonePending && Number(_milestonePending.threshold) !== 100) {
        return null;
      }

      var terminalCard = _isTerminalRealmGate(_milestonePending)
        ? _milestonePending
        : null;

      if (!terminalCard &&
          typeof chapterSystem !== 'undefined' &&
          chapterSystem &&
          chapterSystem._initialized &&
          typeof chapterSystem.getMilestoneCard === 'function') {
        var chapterGate = chapterSystem.getMilestoneCard(gameState.realm, 100);
        if (_isTerminalRealmGate(chapterGate)) {
          terminalCard = chapterGate;
        }
      }

      if (terminalCard) {
        if (_milestonePending === terminalCard ||
            (_milestonePending && _milestonePending.id === terminalCard.id)) {
          _milestonePending = null;
        }
        if (typeof chapterSystem !== 'undefined' &&
            chapterSystem &&
            typeof chapterSystem.markTriggered === 'function') {
          chapterSystem.markTriggered(terminalCard.realm, 100);
        }
        _realmGateState = {
          realm: gameState.realm,
          cardId: terminalCard.id,
          status: 'in_progress',
          deferDrawsRemaining: 0
        };
        return { card: terminalCard, source: 'milestone' };
      }

      if (typeof cardSystem !== 'undefined' && cardSystem &&
          typeof cardSystem.getCard === 'function') {
        var fallbackCard = cardSystem.getCard(breakthroughId);
        if (fallbackCard) {
          return { card: fallbackCard, source: 'breakthrough' };
        }
      }
      return null;
    }

    /**
     * 战斗协调器回传终章战结果。非终章战不会改变 Gate。
     * @returns {boolean} 是否消费了一个终章 Gate 结果
     */
    function settleRealmGate(outcome, card) {
      if (!_isTerminalRealmGate(card)) return false;
      if (!_realmGateState ||
          _realmGateState.realm !== card.realm ||
          _realmGateState.cardId !== card.id) {
        _realmGateState = {
          realm: card.realm,
          cardId: card.id,
          status: 'in_progress',
          deferDrawsRemaining: 0
        };
      }

      if (outcome === 'victory') {
        _realmGateState.status = 'resolved';
        _realmGateState.deferDrawsRemaining = 0;
      } else if (outcome === 'flee' || outcome === 'deferred') {
        _realmGateState.status = 'deferred';
        _realmGateState.deferDrawsRemaining = 1;
      } else if (outcome === 'defeat') {
        _realmGateState.status = 'available';
        _realmGateState.deferDrawsRemaining = 0;
      } else {
        return false;
      }
      return true;
    }

    function getRealmGateState() {
      return _realmGateState ? Object.assign({}, _realmGateState) : null;
    }

    /**
     * 每次仲裁最多向各叙事生产者请求一次结果。
     * 生产者通过 *:eventCard / storynetwork:narrativeCard 回传，
     * 统一监听器负责进入 FlowDirector 的唯一权威队列。
     */
    function _collectNarrativeSources() {
      if (typeof eventBus !== 'undefined' && eventBus && typeof eventBus.emit === 'function') {
        eventBus.emit('storynetwork:checkNarrative', { gameState: gameState });
        eventBus.emit('companion:checkEvent', { gameState: gameState });
        eventBus.emit('faction:checkEvent', { gameState: gameState });
        eventBus.emit('npc:getEncounterCard', { gameState: gameState });
      }

      if (typeof npcSystem !== 'undefined' && npcSystem &&
          typeof npcSystem.getPendingCrossCard === 'function') {
        var crossCard = npcSystem.getPendingCrossCard();
        if (crossCard) enqueueNarrative(crossCard, 31, 'npc_cross');
      }
    }

    function _canServeNarrativePriority(priority) {
      if (typeof cardSystem === 'undefined' || !cardSystem ||
          typeof cardSystem._canAffordNarrative !== 'function') {
        return true;
      }
      return cardSystem._canAffordNarrative(priority);
    }

    function _spendNarrativePriority(priority) {
      if (typeof cardSystem !== 'undefined' && cardSystem &&
          typeof cardSystem._spendNarrativeBudget === 'function') {
        cardSystem._spendNarrativeBudget(priority);
      }
    }

    // ════════════════════════════════════════
    //  阶段权重抽卡 (FIX-7: 情绪调节)
    // ════════════════════════════════════════

    function _drawPhaseWeighted() {
      var phase = PHASES[_currentPhase];
      if (!phase) return cardSystem._drawNormal();

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
          // 轻叙事仍须经过 NarrativeDirector 的焦点与出队重验。
          if (_narrativeQueue.length > 0 && _getNarrativeDirector()) {
            var lightEnvelope = _takeNarrativeEnvelope(function(envelope) {
              return (Number(envelope.priority) || 50) < 40;
            });
            if (lightEnvelope) {
              _spendNarrativePriority(Number(lightEnvelope.priority) || 50);
              return lightEnvelope.card;
            }
          } else if (_narrativeQueue.length > 0) {
            // Legacy fallback for isolated consumers that do not load B4.
            for (var i = _narrativeQueue.length - 1; i >= 0; i--) {
              if ((_narrativeQueue[i].priority || 50) < 40) {
                var wrapper = _narrativeQueue.splice(i, 1)[0];
                var lightCard = wrapper.card || wrapper;
                if (_isNarrativeValid(lightCard)) return lightCard;
              }
            }
          }
          // 没有可用叙事卡 → 走普通卡
          return _drawNormalWithMood(mood, moodWeights);

        case 'story':
          // 重大叙事同样不能绕过 primary stickiness 或 envelope validity。
          if (_narrativeQueue.length > 0 && _getNarrativeDirector()) {
            var storyEnvelope = _takeNarrativeEnvelope();
            if (storyEnvelope) {
              _spendNarrativePriority(Number(storyEnvelope.priority) || 50);
              return storyEnvelope.card;
            }
          } else if (_narrativeQueue.length > 0) {
            while (_narrativeQueue.length > 0) {
              var wrapper2 = _narrativeQueue.shift();
              var storyCard = wrapper2.card || wrapper2;
              if (_isNarrativeValid(storyCard)) return storyCard;
            }
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
      if (typeof cardSystem.drawNormalCard !== 'function') {
        return cardSystem._drawNormal();
      }

      var recentPlayed = new Set(gameState.cardsPlayed.slice(-8));
      var selected = cardSystem.drawNormalCard({
        state: gameState,
        recentPlayed: recentPlayed,
        weightModifier: function(card, baseWeight) {
          var weight = baseWeight;

          // FIX-7: 情绪 tag 权重调整。准入、境界分档与基础权重仍由 CardSystem 权威处理。
          if (card.tags && moodWeights) {
            for (var tag in moodWeights) {
              if (card.tags.indexOf(tag) !== -1) {
                weight *= moodWeights[tag];
              }
            }
          }

          if (preferredTags && card.tags) {
            for (var index = 0; index < preferredTags.length; index++) {
              if (card.tags.indexOf(preferredTags[index]) !== -1) {
                weight *= 2.0;
                break;
              }
            }
          }
          return weight;
        }
      });
      return selected || cardSystem._drawNormal();
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

      var director = _getNarrativeDirector();
      if (director) {
        var selected = _takeNarrativeEnvelope();
        if (selected) {
          _spendNarrativePriority(Number(selected.priority) || 50);
        }
        return selected;
      }

      // 按优先级排序（降序）
      _narrativeQueue.sort(function(a, b) {
        return (b.priority || 50) - (a.priority || 50);
      });

      // 预算不足的重大叙事保留在队列中，允许较轻的叙事先出现。
      for (var i = 0; i < _narrativeQueue.length; i++) {
        var priority = Number(_narrativeQueue[i].priority);
        if (!Number.isFinite(priority)) priority = 50;
        if (_canServeNarrativePriority(priority)) {
          var wrapper = _narrativeQueue.splice(i, 1)[0];
          if (!_isNarrativeValid(wrapper.card || wrapper)) {
            i--;
            continue;
          }
          _spendNarrativePriority(priority);
          return wrapper;
        }
      }
      return null;
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
      if (!card || !card.id) return false;
      var interruptType = type || 'forced';
      // Narrative facts remain active until the player chooses, so repeated
      // due checks must not append the same consumer behind another interrupt.
      if (interruptType === 'causal_fact') {
        if (!_isNarrativeValid(card)) return false;
        var incomingSemanticKey = _semanticKey(card);
        for (var i = 0; i < _interruptQueue.length; i++) {
          var existing = _interruptQueue[i];
          if (existing && existing.type === 'causal_fact'
            && _semanticKey(existing.card) === incomingSemanticKey) return false;
        }
      }
      _interruptQueue.push({ card: card, type: interruptType });
      return true;
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
      if (!card || typeof card !== 'object' || typeof card.id !== 'string' || !card.id) {
        return false;
      }
      // A reached milestone remains authoritative until getNextCard consumes it.
      // Re-detection during combat/interrupt turns must neither re-announce it
      // nor overwrite it with a later threshold.
      if (_milestonePending) {
        return false;
      }
      _milestonePending = card;
      return true;
    }

    /**
     * 入队叙事卡 (P55-28)
     * @param {Object} card - 卡牌
     * @param {number} priority - 优先级 (55=最高叙事, 28=最低)
     */
    function enqueueNarrative(card, priority, source) {
      if (!card || !card.id) return false;
      if (!_isNarrativeValid(card)) return false;
      var incomingSemanticKey = _semanticKey(card);
      for (var i = 0; i < _narrativeQueue.length; i++) {
        if (_narrativeQueue[i].card
          && _semanticKey(_narrativeQueue[i].card) === incomingSemanticKey) return false;
      }
      var numericPriority = Number(priority);
      var director = _getNarrativeDirector();
      var wrapper = director && typeof director.createEnvelope === 'function'
        ? director.createEnvelope(
            card,
            Number.isFinite(numericPriority) ? numericPriority : 50,
            source || 'external'
          )
        : {
            card: card,
            priority: Number.isFinite(numericPriority) ? numericPriority : 50,
            source: source || 'external'
          };
      if (!wrapper) return false;
      _narrativeQueue.push(wrapper);
      return true;
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
      var combatDirector = _getEncounterDirector();
      return _interruptQueue.length > 0 ||
             !!_combatWarningPending ||
             !!_milestonePending ||
             _narrativeQueue.length > 0 ||
             !!(combatDirector && combatDirector.pending) ||
             _hasPendingFlags();
    }

    function _hasPendingFlags() {
      for (var k in _pendingFlags) {
        if (_pendingFlags[k]) return true;
      }
      return false;
    }

    function _cloneSerializable(value, fallback) {
      if (value === undefined || value === null) return fallback;
      try {
        return JSON.parse(JSON.stringify(value));
      } catch (error) {
        return fallback;
      }
    }

    /**
     * Export the scheduler cursor and pending decisions. The cards themselves
     * are immutable data snapshots; no live callbacks or DOM references cross
     * the persistence boundary.
     */
    function exportState() {
      return {
        version: 2,
        phase: _currentPhase,
        phaseProgress: _phaseProgress,
        cardCount: _cardCount,
        phaseHistory: _cloneSerializable(_phaseHistory, []),
        interruptQueue: _cloneSerializable(_interruptQueue, []),
        combatWarningPending: _cloneSerializable(_combatWarningPending, null),
        milestonePending: _cloneSerializable(_milestonePending, null),
        realmGateState: _cloneSerializable(_realmGateState, null),
        narrativeQueue: _cloneSerializable(_narrativeQueue, []),
        narrativeDirectorState: _getNarrativeDirector()
          && typeof _getNarrativeDirector().exportState === 'function'
          ? _cloneSerializable(_getNarrativeDirector().exportState(), null)
          : null,
        encounterDirectorState: _getEncounterDirector()
          && typeof _getEncounterDirector().exportState === 'function'
          ? _cloneSerializable(_getEncounterDirector().exportState(), null)
          : null,
        pendingFlags: _cloneSerializable(_pendingFlags, {}),
        starvationTracker: _cloneSerializable(_starvationTracker, {}),
        lastDrawSource: _lastDrawSource,
        phaseLog: _cloneSerializable(_phaseLog, [])
      };
    }

    /**
     * Restore a scheduler snapshot after init() has rebound event sources.
     * Invalid cards are ignored; an invalid snapshot never blocks ordinary
     * card flow.
     */
    function hydrateState(snapshot) {
      if (!snapshot || typeof snapshot !== 'object') return false;
      var director = _getNarrativeDirector();
      var directorHydrated = false;
      if (director && typeof director.hydrateState === 'function') {
        directorHydrated = director.hydrateState(snapshot.narrativeDirectorState || null);
      }
      var combatDirector = _getEncounterDirector();
      if (combatDirector && typeof combatDirector.hydrateState === 'function'
          && snapshot.encounterDirectorState) {
        combatDirector.hydrateState(snapshot.encounterDirectorState);
      }
      if (snapshot.phase && PHASES[snapshot.phase]) _currentPhase = snapshot.phase;
      _phaseProgress = Math.max(0, Math.min(100, _finiteNumber(snapshot.phaseProgress, 0)));
      _cardCount = Math.max(0, Math.floor(_finiteNumber(snapshot.cardCount, 0)));
      _phaseHistory = Array.isArray(snapshot.phaseHistory)
        ? _cloneSerializable(snapshot.phaseHistory, [])
        : [];
      var seenCausalFacts = {};
      _interruptQueue = Array.isArray(snapshot.interruptQueue)
        ? _cloneSerializable(snapshot.interruptQueue, []).filter(function(item) {
            if (!item || !item.card || typeof item.card.id !== 'string' || !_isLifecycleValid(item.card)) return false;
            if (item.type !== 'causal_fact') return true;
            var semanticKey = _semanticKey(item.card);
            if (!_isNarrativeValid(item.card) || seenCausalFacts[semanticKey]) return false;
            seenCausalFacts[semanticKey] = true;
            return true;
          })
        : [];
      _combatWarningPending = snapshot.combatWarningPending
        && typeof snapshot.combatWarningPending.id === 'string'
        ? _cloneSerializable(snapshot.combatWarningPending, null)
        : null;
      _milestonePending = snapshot.milestonePending
        && typeof snapshot.milestonePending.id === 'string'
        ? _cloneSerializable(snapshot.milestonePending, null)
        : null;
      _realmGateState = snapshot.realmGateState
        && typeof snapshot.realmGateState === 'object'
        ? _cloneSerializable(snapshot.realmGateState, null)
        : null;
      _narrativeQueue = Array.isArray(snapshot.narrativeQueue)
        ? _cloneSerializable(snapshot.narrativeQueue, []).map(function(item) {
            if (director && typeof director.normalizeEnvelope === 'function') {
              return director.normalizeEnvelope(item, {
                acquireFocus: directorHydrated || Number(snapshot.version) >= 2
                  ? false
                  : true
              });
            }
            return item;
          }).filter(function(item) {
            if (!item || !item.card || typeof item.card.id !== 'string') return false;
            if (director && typeof director.validateEnvelope === 'function') {
              var validity = director.validateEnvelope(item);
              if (!validity.valid && typeof director.recordInvalidation === 'function') {
                director.recordInvalidation(item, validity.reason);
              }
              return validity.valid;
            }
            return _isNarrativeValid(item.card);
          })
        : [];
      _pendingFlags = snapshot.pendingFlags
        && typeof snapshot.pendingFlags === 'object'
        && !Array.isArray(snapshot.pendingFlags)
        ? _cloneSerializable(snapshot.pendingFlags, {})
        : {};
      _starvationTracker = snapshot.starvationTracker
        && typeof snapshot.starvationTracker === 'object'
        && !Array.isArray(snapshot.starvationTracker)
        ? _cloneSerializable(snapshot.starvationTracker, {})
        : {};
      _lastDrawSource = typeof snapshot.lastDrawSource === 'string'
        ? snapshot.lastDrawSource
        : null;
      _phaseLog = Array.isArray(snapshot.phaseLog)
        ? _cloneSerializable(snapshot.phaseLog, [])
        : [];
      return true;
    }

    function getNarrativeInvalidations() {
      var director = _getNarrativeDirector();
      return director && typeof director.getInvalidations === 'function'
        ? director.getInvalidations()
        : [];
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
      settleRealmGate: settleRealmGate,
      enqueueNarrative: enqueueNarrative,
      invalidateNarrativeByNpc: invalidateNarrativeByNpc,
      setPending: setPending,

      // 阶段控制
      setPhase: setPhase,
      forceAdvancePhase: forceAdvancePhase,

      // 查询
      getPhaseInfo: getPhaseInfo,
      getStarvationReport: getStarvationReport,
      getPhaseHistory: getPhaseHistory,
      getNarrativeQueueLength: getNarrativeQueueLength,
      getNarrativeInvalidations: getNarrativeInvalidations,
      getRealmGateState: getRealmGateState,
      hasPending: hasPending,
      exportState: exportState,
      hydrateState: hydrateState,

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
