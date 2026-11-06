/**
 * CardSystem - 卡牌系统（抽卡引擎）
 *
 * 20级优先级抽卡：
 *   100 - 死亡卡 (玩家死亡)
 *   90  - 瓶颈卡 (修为满)
 *   80  - 支线当前卡 (支线进行中)
 *   70  - 支线入口卡 (新支线触发)
 *   60  - 因果卡 (因果种子发芽)
 *   55  - 转世回响卡 (前世记忆)
 *   53  - 道侣弧线高潮卡 (StoryNetwork注入)
 *   52  - 师尊弧线高潮卡 (StoryNetwork注入)
 *   51  - 道侣弧线推进卡 (StoryNetwork注入)
 *   50  - 道侣事件卡 (CompanionSystem)
 *   49  - 盟友弧线高潮卡 (StoryNetwork注入)
 *   48  - 师尊弧线推进卡 (StoryNetwork注入)
 *   45  - 涌现叙事卡 (StoryNetwork注入)
 *   44  - 先知弧线高潮卡 (StoryNetwork注入)
 *   42  - 盟友弧线推进卡 (StoryNetwork注入)
 *   40  - 势力暗流事件卡 (FactionSystem)
 *   39  - 先知弧线推进卡 (StoryNetwork注入)
 *   36  - 选择回响卡 (ChoiceEchoEngine注入)
 *   35  - 叙事浮现卡 (StoryNetwork注入)
 *   31  - NPC交叉互动卡 (NpcSystem注入)
 *   30  - NPC遭遇卡
 *   28  - 场景/位置卡 (SceneLayerSystem注入)
 *   25  - 商店遭遇卡 (ShopSystem注入)
 *   20  - 集市偶遇卡 (MarketSystem注入)
 *   10  - 普通卡 (按权重随机)
 *
 * 数据来源：DataLoader (从 DATA_MODULES 加载)
 */
class CardSystem {
  constructor() {
    this.cardCache = new Map();      // cardId → card 对象
    this.dungeonCache = new Map();   // realm → dungeons
    this.dungeonCardCache = new Map(); // realm → dungeonCards
    this.karmaCardMap = new Map();   // karmaId → cardId
    this.deathCardMap = new Map();   // deadReason → deathCardId

    this._loadedRealms = new Set();
    this._lastDrawnPriority = 0;

    // 叙事节奏控制：预算系统，防止叙事事件堆叠
    this._narrativeBudget = 3;        // 当前预算点数
    this._narrativeBudgetMax = 5;     // 上限
    this._lastNarrativeRound = -1;    // 上次消耗预算的回合号
    this._shopCooldown = 0;           // 商店触发保护冷却计数器
    this._dungeonSessionSequence = 0;
    this._pendingDungeonSettlements = new Map();
  }

  /**
   * 初始化：加载炼气期和下一境界的卡牌
   */
  init() {
    // 预加载炼气期卡牌
    this._loadRealmCards('qi');
    // 预加载筑基期卡牌（因果种子可能需要）
    this._loadRealmCards('foundation');
    // 加载统一的因果卡映射
    this._loadKarmaCards();
    // 加载集中式因果回报扩展；weight=0，只由成熟 seed 解析。
    this._loadExtraModule('cards:karma_expansion');
    // 加载死亡卡
    this._loadDeathCards();
    // 加载额外卡牌模块（魔道女修事件等）
    this._loadExtraModule('cards:demonic_seductress');
    // 加载正魔抉择线卡牌（P0-4）
    this._loadExtraModule('cards:demon_path');
    // 加载跨线交织卡牌（P1-4）
    this._loadExtraModule('cards:interweave');
    // 加载飞升后卡牌（P0-5）
    this._loadExtraModule('cards:post_ascension');
    // 加载转世宿命卡（P0-6）
    this._loadExtraModule('cards:rebirth');
    // 加载核心叙事对话卡（叙事设计师注入）
    this._loadExtraModule('cards:story_dialogue');
    // 加载世界氛围卡（让世界「呼吸」）
    this._loadExtraModule('cards:world_atmosphere');
    // 把 34 条战斗目录记录实体化为可抽取、可回避、可结算的来源卡。
    this._loadCombatEncounterCards();
    // 迁移卡、线程卡与目录卡共用同一套战斗呈现消费契约。
    this._hydrateCachedCombatCards();

    eventBus.on('quest:cardRequest', (data) => this._handleQuestCardRequest(data));
  }

  // ============ 核心抽卡 ============

  /**
   * 叙事预算检查：控制叙事事件密度，防止"一轮太多事"
   *
   * 规则：
   *   - 重大叙事（优先级 ≥ 50）：消耗 3 点
   *   - 次要叙事（优先级 30-49）：消耗 1 点
   *   - 系统卡（死亡/瓶颈/支线 70-100）：不消耗
   *   - 普通卡（< 30）：不消耗
   *   - 预算每轮恢复 1 点，上限 5
   *
   * @param {number} priority
   * @returns {boolean} 是否有足够预算触发该优先级叙事
   */
  _canAffordNarrative(priority) {
    // 系统关键卡不过滤：死亡/瓶颈/支线/因果种子发芽
    if (priority >= 60) return true;

    const turn = gameState.turn || 0;

    // 每进入新的一轮，预算恢复 1 点
    if (turn !== this._lastNarrativeRound) {
      this._narrativeBudget = Math.min(this._narrativeBudgetMax, this._narrativeBudget + 1);
      this._lastNarrativeRound = turn;
    }

    const isMajor = priority >= 50;
    const isMinor = priority >= 30 && priority < 50;

    if (isMajor) return this._narrativeBudget >= 3;
    if (isMinor) return this._narrativeBudget >= 1;
    return true; // 普通卡不消耗
  }

  /** 实际消费叙事预算（仅在确认返回叙事卡后调用） */
  _spendNarrativeBudget(priority) {
    if (priority >= 60) return; // 系统卡不消耗
    if (priority >= 50) { this._narrativeBudget -= 3; return; }
    if (priority >= 30) { this._narrativeBudget -= 1; return; }
  }


  /**
   * 抽一张卡（按优先级）
   * @returns {Object} 卡牌对象
   */
  draw() {
    try {
    // 优先级 100: 死亡 — 根据死因匹配叙事卡
    // 终局/EPILOGUE 阶段：最高优先级，展示对应结局卡，绝不进入普通死亡卡
    if (gameState.lifePhase === 'EPILOGUE' || (typeof gameState.isInEnding === 'function' && gameState.isInEnding())) {
      this._lastDrawnPriority = 100;
      const expectedCardId = gameState.endingId ? `ending_${gameState.endingId}` : null;
      if (!expectedCardId || gameState.pendingCardId !== expectedCardId) return null;
      return this.getCard(expectedCardId);
    }

    if (gameState.dead) {
      this._lastDrawnPriority = 100;
      return this._drawDeathCard();
    }

    // 飞升续章是独立世界层：刷新后不得再次进入下界突破、任务、商店或营地队列。
    if (this._isUpperRealmActive(gameState)) {
      return this._drawUpperRealmCard();
    }

    // 秘境模式下走秘境流程
    if (gameState.dungeon) {
      return this._drawDungeonCard();
    }

    // 优先级 90: 瓶颈
    const breakthroughCardId = gameState.checkBreakthrough();
    if (breakthroughCardId) {
      this._lastDrawnPriority = 90;
      return this.getCard(breakthroughCardId);
    }

    // 优先级 80: 支线当前卡（由 QuestSystem 通过 quest:cardRequest 事件提供）
    const questCurrentCard = this._getQuestCurrentCard();
    if (questCurrentCard) {
      this._lastDrawnPriority = 80;
      return questCurrentCard;
    }

    // 优先级 70: 支线入口卡
    eventBus.emit('quest:checkTrigger', { gameState });
    // QuestSystem 会设置一个 pending trigger card
    const questEntryCard = this._getQuestEntryCard();
    if (questEntryCard) {
      this._lastDrawnPriority = 70;
      return questEntryCard;
    }

    // 优先级 60: 因果种子发芽
    const karmaCard = this._drawKarmaCard();
    if (karmaCard) {
      this._lastDrawnPriority = 60;
      return karmaCard;
    }

    // ── 叙事预算门控：重大叙事区（优先级 55–36） ──
    // 预算不足时跳过整段，等预算恢复后再检查（事件队列保持不丢失）
    if (this._canAffordNarrative(50)) {

    // 优先级 55: 转世回响卡（前世记忆影响今生）
    const reincCard = this._drawReincarnationCard();
    if (reincCard) {
      this._spendNarrativeBudget(55);
      this._lastDrawnPriority = 55;
      return reincCard;
    }

    // 优先级 53: 道侣弧线高潮事件（StoryNetwork注入）
    const arcClimaxCard = this._getStoryNetworkCard(53);
    if (arcClimaxCard) {
      this._spendNarrativeBudget(53);
      this._lastDrawnPriority = 53;
      return arcClimaxCard;
    }

    // 优先级 52: 师尊弧线高潮事件（StoryNetwork注入 — 传承/真相揭示）
    const mentorClimaxCard = this._getStoryNetworkCard(52);
    if (mentorClimaxCard) {
      this._spendNarrativeBudget(52);
      this._lastDrawnPriority = 52;
      return mentorClimaxCard;
    }

    // 优先级 51: 道侣弧线推进事件（StoryNetwork注入）
    const arcProgCard = this._getStoryNetworkCard(51);
    if (arcProgCard) {
      this._spendNarrativeBudget(51);
      this._lastDrawnPriority = 51;
      return arcProgCard;
    }

    // 优先级 50: 道侣事件卡
    const companionCard = this._getCompanionEventCard();
    if (companionCard) {
      this._spendNarrativeBudget(50);
      this._lastDrawnPriority = 50;
      return companionCard;
    }

    // 优先级 49: 盟友弧线高潮事件（StoryNetwork注入 — 天道决战）
    const allyClimaxCard = this._getStoryNetworkCard(49);
    if (allyClimaxCard) {
      this._spendNarrativeBudget(49);
      this._lastDrawnPriority = 49;
      return allyClimaxCard;
    }

    // 优先级 48: 师尊弧线推进事件（StoryNetwork注入）
    const mentorProgCard = this._getStoryNetworkCard(48);
    if (mentorProgCard) {
      this._spendNarrativeBudget(48);
      this._lastDrawnPriority = 48;
      return mentorProgCard;
    }

    // 优先级 45: 涌现叙事事件（StoryNetwork注入 — 双脉齐震/孤峰之上/因果之网等）
    const emergentCard = this._getStoryNetworkCard(45);
    if (emergentCard) {
      this._spendNarrativeBudget(45);
      this._lastDrawnPriority = 45;
      return emergentCard;
    }

    // 优先级 44: 先知弧线高潮事件（StoryNetwork注入 — 终极预言）
    const seerClimaxCard = this._getStoryNetworkCard(44);
    if (seerClimaxCard) {
      this._spendNarrativeBudget(44);
      this._lastDrawnPriority = 44;
      return seerClimaxCard;
    }

    // 优先级 42: 盟友弧线推进事件（StoryNetwork注入）
    const allyProgCard = this._getStoryNetworkCard(42);
    if (allyProgCard) {
      this._spendNarrativeBudget(42);
      this._lastDrawnPriority = 42;
      return allyProgCard;
    }

    } // ── 重大叙事预算门控结束（优先级 55–42） ──

    // ── 叙事预算门控：次要叙事区（优先级 40–28） ──
    if (this._canAffordNarrative(30)) {

    // 优先级 40: 势力暗流事件卡
    const factionCard = this._getFactionEventCard();
    if (factionCard) {
      this._spendNarrativeBudget(40);
      this._lastDrawnPriority = 40;
      return factionCard;
    }

    // 优先级 39: 先知弧线推进事件（StoryNetwork注入）
    const seerProgCard = this._getStoryNetworkCard(39);
    if (seerProgCard) {
      this._spendNarrativeBudget(39);
      this._lastDrawnPriority = 39;
      return seerProgCard;
    }

    // 优先级 36: 选择延迟回响卡（ChoiceEchoEngine注入 — "世界记住了你"）
    const echoCard = this._getStoryNetworkCard(36);
    if (echoCard) {
      this._spendNarrativeBudget(36);
      this._lastDrawnPriority = 36;
      return echoCard;
    }

    // 优先级 35: 叙事浮现层（StoryNetwork注入 — 世界状态变化被NPC感知）
    const surfacingCard = this._getStoryNetworkCard(35);
    if (surfacingCard) {
      this._spendNarrativeBudget(35);
      this._lastDrawnPriority = 35;
      return surfacingCard;
    }

    // 优先级 31: NPC交叉互动卡（NpcSystem注入 — 两个NPC在同一位置触发）
    if (typeof npcSystem !== 'undefined' && npcSystem) {
      const npcCrossCard = npcSystem.getPendingCrossCard();
      if (npcCrossCard) {
        this._spendNarrativeBudget(31);
        this._lastDrawnPriority = 31;
        return npcCrossCard;
      }
    }

    // 优先级 30: NPC 遭遇卡
    const npcCard = this._getNpcEncounterCard();
    if (npcCard) {
      this._spendNarrativeBudget(30);
      this._lastDrawnPriority = 30;
      return npcCard;
    }

    // 优先级 28: 场景/位置卡（SceneLayerSystem注入 — 环境叙事）
    const locationCard = this._getStoryNetworkCard(28);
    if (locationCard) {
      this._spendNarrativeBudget(28);
      this._lastDrawnPriority = 28;
      return locationCard;
    }

    } // ── 次要叙事预算门控结束（优先级 40–28） ──

    // 优先级 25: 商店遭遇卡（ShopSystem注入 — 坊市/炼丹/炼器等）
    const shopCard = this._checkShopEncounter();
    if (shopCard) {
      this._lastDrawnPriority = 25;
      return shopCard;
    }

    // 优先级 24: 洞府冥想遭遇卡
    const campCard = this._checkCampEncounter();
    if (campCard) {
      this._lastDrawnPriority = 24;
      return campCard;
    }

    // 优先级 20: 集市偶遇卡（v2.0 — 由 MarketSystem.tick() 在 game.js 中注入，此处作为后备）
    if (typeof marketSystem !== 'undefined' && marketSystem && gameState._pendingMarket) {
      const marketCard = gameState._pendingMarket;
      gameState._pendingMarket = null;
      // 确保已刷商品
      if (!marketSystem.getCurrentMarketItems().length) {
        marketSystem._currentItems = marketSystem._generateItems(gameState.attributes.fortune);
      }
      this._lastDrawnPriority = 20;
      return marketCard;
    }

    // 优先级 10: 普通卡
    this._lastDrawnPriority = 10;
    return this._drawNormal();
    } catch (e) {
      console.error('[CardSystem.draw()]', e);
      // 兜底：返回通用事件卡，防止 UI 崩溃
      return this._buildFallbackEventCard();
    }
  }

  // ============ 商店触发 ============

  /**
   * 检查是否触发商店遭遇
   * 炼气期：每 8~12 轮，10% 概率
   * 筑基期及以上：每 6~10 轮，15% 概率
   * @returns {Object|null} 商店卡或 null
   */
  _checkShopEncounter() {
    if (this._isUpperRealmActive(gameState)) return null;
    if (typeof shopSystem === 'undefined' || !shopSystem) return null;
    if (this._shopCooldown > 0) {
      this._shopCooldown--;
      return null;
    }

    const turn = gameState.turn;
    const realm = gameState.realm;
    const realmOrder = gameState.config.realms?.order || ['qi', 'foundation', 'golden', 'nascent', 'deity', 'tribulation'];
    const realmIdx = realmOrder.indexOf(realm);

    // 计算触发间隔和概率
    let minInterval, probability;
    if (realmIdx <= 1) { // 炼气/筑基
      minInterval = 8;
      probability = 0.10;
    } else {
      minInterval = 6;
      probability = 0.15;
    }

    // 每 minInterval 轮有概率触发
    if (turn % minInterval !== 0) return null;
    if (Math.random() >= probability) return null;

    // 触发商店遭遇，设 6 回合保护
    this._shopCooldown = 6;

    // 返回商店遭遇卡
    return this._buildShopCard();
  }

  /**
   * 构建商店遭遇卡
   */
  _buildShopCard() {
    const realm = gameState.realm;
    const items = shopSystem.getAvailableItems(realm);
    const itemCount = Math.min(items.length, 5);

    return {
      id: 'shop_encounter',
      title: '官坊 · 万宝楼明码',
      description: '朱砂官印压住价签，万宝楼的执事在柜后核验来历。这里可以买到明码货，也能把合规旧物交回回购台。',
      type: 'SHOP',
      realm: realm,
      weight: 0,
      once: false,
      choices: {
        left: {
          text: '不入楼，继续赶路',
          effects: {},
          desc: '专心修行，不被俗物分心。'
        },
        right: {
          text: '入楼核价',
          effects: {},
          action: {
            type: 'ENTER_VENDOR',
            vendorId: 'regulated_market',
            resumePolicy: 'ON_VENDOR_CLOSED',
            settlePolicy: 'AFTER_CLOSE_EXACTLY_ONCE'
          },
          desc: `进入万宝楼，核对明码与回购范围。（你有 ${gameState.resources.spiritStone} 灵石）`
        }
      }
    };
  }

  // ============ 洞府触发 ============

  /**
   * 检查是否触发洞府冥想遭遇
   * 每 15 轮左右 30% 概率触发
   */
  _checkCampEncounter() {
    if (this._isUpperRealmActive(gameState)) return null;
    const turn = gameState.turn;
    if (turn % 15 !== 0) return null;
    if (Math.random() >= 0.3) return null;
    
    // 获取缓存中的 camp_meditation
    const campData = dataLoader.loadSync('cards:camp');
    if (Array.isArray(campData)) {
      return campData.find(card => card && card.id === 'camp_meditation') || null;
    }
    if (campData && Array.isArray(campData.cards)) {
      return campData.cards.find(card => card && card.id === 'camp_meditation') || null;
    }
    if (campData && campData.camp_meditation) return campData.camp_meditation;
    return null;
  }

  // ============ 卡牌查找 ============

  /**
   * Rebuild a saved combat source through its authored producer. This lookup
   * may hydrate CardSystem's cache; it is deliberately separate from the pure
   * choice contract used by preview. A hint can select an alias, never another
   * source ID or serialized reward payload.
   */
  resolveCombatSourceCard(cardId, {
    chapterSystem = null, factionSystem = null, realmHint = null, thresholdHint = null, pathId = null
  } = {}) {
    if (typeof cardId !== 'string' || !cardId) return null;
    const chapterMatch = /^ch_([a-z]+)_(\d+)$/.exec(cardId);
    if (chapterMatch) {
      if (typeof chapterSystem?.getMilestoneCard !== 'function') return null;
      if (realmHint !== null && realmHint !== undefined && realmHint !== chapterMatch[1]) return null;
      const hasThreshold = thresholdHint !== null && thresholdHint !== undefined;
      if (hasThreshold && (!Number.isSafeInteger(thresholdHint) || thresholdHint <= 0)) return null;
      const threshold = hasThreshold ? thresholdHint : Number(chapterMatch[2]);
      const card = chapterSystem.getMilestoneCard(chapterMatch[1], threshold, pathId);
      return card?.id === cardId && card.threshold === threshold ? card : null;
    }
    // Non-chapter sources have no threshold alias to authenticate.
    if (thresholdHint !== null && thresholdHint !== undefined) return null;
    // A faction invitation is a runtime projection, not a cached catalogue
    // card. Rebuild the accepted source without drawing another event; missing
    // authority or an unknown identity must never fall back to a cached copy.
    if (cardId.startsWith('faction_')) {
      if (typeof factionSystem?.getAuthoritativeEventCard !== 'function') return null;
      const card = factionSystem.getAuthoritativeEventCard(cardId);
      return card?.id === cardId ? card : null;
    }
    const card = this.getCard(cardId);
    if (card?.id !== cardId) return null;
    // Graph identity belongs to the current authored dungeon, not a cache
    // annotation left by a previous draw or the serialized combat payload.
    const projected = { ...card };
    delete projected._dungeonNodeId;
    delete projected._dungeonNodeType;
    const run = gameState?.dungeonRun;
    if (run?.status === 'active' && run.sessionId && run.realm === gameState.realm
      && run.dungeonId === gameState.dungeon) {
      const contract = this.validateDungeonEntry(run.dungeonId, run.realm);
      const node = contract?.dungeon?.graph?.[gameState.dungeonNodeId];
      if (contract.valid && node?.card === cardId) {
        projected._dungeonNodeId = gameState.dungeonNodeId;
        projected._dungeonNodeType = node.type;
      }
    }
    // Legacy missing selectors are only migratable through their actual
    // graph owner. A standalone authored payload is not enough to resume a
    // graph-owned fight as an unreceipted forced battle.
    if (this.isGraphDungeonCombatSource(cardId, realmHint || card.realm || gameState.realm)
      && !projected._dungeonNodeId) return null;
    return projected;
  }

  isGraphDungeonCombatSource(cardId, realm = gameState.realm) {
    const realmData = dataLoader.loadSync('cards:' + realm);
    return Boolean(realmData?.dungeonCards?.[cardId])
      && Object.values(realmData?.dungeons || {}).some(dungeon =>
        Object.values(dungeon.graph || {}).some(node => node?.card === cardId));
  }

  /**
   * 通过ID获取卡牌
   * @param {string} id
   * @returns {Object|null}
   */
  getCard(id) {
    if (!id) return null;
    if (this.cardCache.has(id)) {
      const card = this.hydrateCombatCardPresentation(this.cardCache.get(id));
      this.cardCache.set(id, card);
      const presented = this._applyFirstSessionRouteLens(card);
      return typeof questSystem !== 'undefined' && questSystem?.projectCard
        ? questSystem.projectCard(presented)
        : presented;
    }

    // 先尝试已加载的境界
    for (const card of this.cardCache.values()) {
      if (card.id === id) return this._applyFirstSessionRouteLens(card);
    }

    // 没找到，尝试加载所有境界
    const allRealms = ['qi', 'foundation', 'golden', 'nascent', 'deity', 'tribulation'];
    for (const realm of allRealms) {
      const data = dataLoader.loadSync('cards:' + realm);
      if (!data) continue;

      // 检查普通卡
      if (data.cards) {
        for (const card of data.cards) {
          if (card.id === id) {
            const hydratedCard = this.hydrateCombatCardPresentation(card);
            this.cardCache.set(id, hydratedCard);
            return this._applyFirstSessionRouteLens(hydratedCard);
          }
        }
      }
      // 检查秘境卡
      if (data.dungeonCards && data.dungeonCards[id]) {
        this.cardCache.set(id, data.dungeonCards[id]);
        return this._applyFirstSessionRouteLens(data.dungeonCards[id]);
      }
    }

    // 检查死亡卡
    const deathData = dataLoader.loadSync('cards:death');
    if (deathData && deathData.deathCards && deathData.deathCards[id]) {
      this.cardCache.set(id, deathData.deathCards[id]);
      return this._applyFirstSessionRouteLens(deathData.deathCards[id]);
    }

    // 检查因果卡
    const karmaData = dataLoader.loadSync('cards:karma');
    if (karmaData && karmaData.cards) {
      for (const card of karmaData.cards) {
        if (card.id === id) {
          this.cardCache.set(id, card);
          return this._applyFirstSessionRouteLens(card);
        }
      }
    }

    // Location cards are authored in their own canonical module because
    // SceneLayerSystem owns visit/layer state. They are still legitimate named
    // `nextCard` targets, so resolve the exact authored card here rather than
    // letting a temporary null currentCard cause GameUI to draw an unrelated
    // Flow card. Caching is only an ID lookup optimization; it does not own
    // location progression or create a parallel location state.
    const locationData = dataLoader.loadSync('locations:locations');
    const locationCard = Array.isArray(locationData?.cards)
      ? locationData.cards.find(card => card?.id === id)
      : null;
    if (locationCard) {
      this.cardCache.set(id, locationCard);
      return this._applyFirstSessionRouteLens(locationCard);
    }

    return null;
  }

  /**
   * One canonical route can carry a different readable lens for each starting
   * path. This method only projects authored presentation and an existing
   * continuation onto the returned card instance; encounter, rewards, world
   * location, and vendor session authority stay in their owning systems.
   */
  _applyFirstSessionRouteLens(card, state = gameState) {
    if (!card || card.id !== 'q_mountain_shadow_approach' || state?.realm !== 'qi') return card;
    const pathId = typeof state?.path === 'string' ? state.path : null;
    if (!pathId || typeof dataLoader === 'undefined' || !dataLoader?.loadSync) return card;
    const manifest = dataLoader.loadSync('progression:first_session_cohesion');
    const entry = manifest?.paths?.[pathId];
    const lensKey = entry?.routeLensRef?.cardId === card.id ? entry.routeLensRef.variantKey : null;
    const lens = lensKey ? manifest?.routeLenses?.[lensKey] : null;
    if (!lens || typeof lens !== 'object') return card;

    const clone = JSON.parse(JSON.stringify(card));
    if (typeof lens.description === 'string' && lens.description.trim()) clone.description = lens.description;
    clone.choices = clone.choices && typeof clone.choices === 'object' ? clone.choices : {};
    for (const direction of ['left', 'right']) {
      if (lens.choices?.[direction] && clone.choices[direction]) {
        clone.choices[direction] = { ...clone.choices[direction], ...lens.choices[direction] };
        // A cached base card may already have been prepared before this lens
        // was applied. A serial continuation has its own named successor, so
        // it must not retain that earlier generic promise-result producer.
        if (clone.choices[direction].continuityClass === 'first_session_serial') {
          delete clone.choices[direction].promise;
        }
      }
    }
    if (lens.outcomes && clone.choices.left?.combatOutcomePresentation) {
      const current = clone.choices.left.combatOutcomePresentation;
      const sceneImage = clone.sceneImage || current.victory?.sceneImage || null;
      for (const outcome of ['victory', 'defeat', 'flee']) {
        if (!lens.outcomes[outcome]) continue;
        current[outcome] = { ...current[outcome], ...lens.outcomes[outcome] };
        if (sceneImage && !current[outcome].sceneImage) current[outcome].sceneImage = sceneImage;
      }
    }
    clone._firstSessionCohesion = { id: manifest.id, path: pathId, lensKey };
    return clone;
  }

  /**
   * Read the named first-session arrival promise from its progression
   * manifest. GameLogic owns dispatch and the existing generic continuation
   * slot; this resolver only verifies that the currently rendered route lens
   * still matches the one authored serial handoff. Keeping this lookup here
   * prevents a second, hard-coded serial contract from drifting in GameLogic.
   */
  getFirstSessionSerialContract(card, choice, state = gameState) {
    if (!card || !choice || state?.realm !== 'qi'
      || typeof dataLoader === 'undefined' || !dataLoader?.loadSync) return null;
    const manifest = dataLoader.loadSync('progression:first_session_cohesion');
    const serial = manifest?.serialDelivery;
    const pathId = typeof state?.path === 'string' ? state.path : null;
    const routeRef = pathId ? manifest?.paths?.[pathId]?.routeLensRef : null;
    const expectedFrom = serial?.from;
    const expectedTo = serial?.to;
    if (!routeRef || !expectedFrom || !expectedTo) return null;
    const authoredChoice = card.choices?.[expectedFrom.choice];
    if (routeRef.cardId !== expectedFrom.cardId
      || card.id !== expectedFrom.cardId
      || !authoredChoice
      || choice.continuityClass !== serial.continuityClass
      || choice.nextCard !== expectedTo.cardId
      || authoredChoice.continuityClass !== choice.continuityClass
      || authoredChoice.nextCard !== choice.nextCard) return null;
    const recovery = serial.preemptionRecovery;
    if (recovery?.resumeCardId !== expectedTo.cardId
      || Number(recovery?.maxAdditionalTopLevelDecisions) !== 1) return null;
    return {
      id: manifest.id,
      pathId,
      continuityClass: serial.continuityClass,
      from: { cardId: expectedFrom.cardId, choice: expectedFrom.choice },
      to: { cardId: expectedTo.cardId },
      preemptionRecovery: {
        maxAdditionalTopLevelDecisions: 1,
        resumeCardId: recovery.resumeCardId
      },
      ambientDeferrals: [...(serial.ambientDeferrals || [])],
      permittedPreemption: [...(serial.permittedPreemption || [])]
    };
  }

  /**
   * 获取境界的卡池（数组形式）
   * @param {string} realm
   * @returns {Object[]}
   */
  getCardPool(realm) {
    const data = dataLoader.loadSync('cards:' + realm);
    if (!data || !data.cards) return [];
    return data.cards;
  }

  /**
   * 将卡牌的流派限制归一化为稳定数组。
   * 新字段 paths 是权威字段；缺失时兼容旧 pathRestriction / path。
   */
  normalizeCardPaths(card) {
    if (!card || typeof card !== 'object') return [];
    let declared;
    if (card.paths !== undefined) {
      declared = card.paths;
    } else if (card.pathRestriction !== undefined) {
      declared = card.pathRestriction;
    } else {
      declared = card.path;
    }

    const values = Array.isArray(declared) ? declared : [declared];
    return [...new Set(values
      .filter(value => typeof value === 'string' && value.trim())
      .map(value => value.trim()))];
  }

  _getRealmOrder(state = gameState) {
    const configured = state?.config?.realms?.order;
    if (Array.isArray(configured) && configured.length > 0) {
      return configured.slice();
    }
    return ['qi', 'foundation', 'golden', 'nascent', 'deity', 'tribulation'];
  }

  _getCardRealms(card) {
    return String(card?.realm || 'qi')
      .split(',')
      .map(realm => realm.trim())
      .filter(Boolean);
  }

  /**
   * 普通池分档：
   * current 72 / previous 18 / evergreen 10。
   * 当前境界优先；旧 evergreen 独立分档；其余仅保留上一境界。
   */
  getNormalDrawBucket(card, state = gameState) {
    if (!card || !state) return null;
    const realmOrder = this._getRealmOrder(state);
    const currentRealm = state.realm || 'qi';
    const currentIdx = realmOrder.indexOf(currentRealm);
    if (currentIdx < 0) return null;

    const cardRealms = this._getCardRealms(card);
    const tags = Array.isArray(card.tags) ? card.tags : [];
    if (currentIdx >= 1 &&
        tags.includes('basic') &&
        (cardRealms.includes('qi') || tags.includes('qi'))) {
      return null;
    }
    if (cardRealms.includes(currentRealm)) return 'current';
    if (card.evergreen === true) {
      const hasReachedRealm = cardRealms.some(realm => {
        const index = realmOrder.indexOf(realm);
        return index >= 0 && index < currentIdx;
      });
      if (hasReachedRealm) return 'evergreen';
    }
    if (currentIdx > 0 && cardRealms.includes(realmOrder[currentIdx - 1])) {
      return 'previous';
    }
    return null;
  }

  _prepareNormalDrawRealms(state = gameState) {
    const realmOrder = this._getRealmOrder(state);
    const currentIdx = realmOrder.indexOf(state?.realm || 'qi');
    if (currentIdx < 0) return;
    for (let index = 0; index <= currentIdx; index++) {
      this._loadRealmCards(realmOrder[index]);
    }
  }

  _getNormalDrawCards(state = gameState) {
    this._prepareNormalDrawRealms(state);
    const currentPool = this.getCardPool(state?.realm || 'qi');
    const byId = new Map();
    for (const card of currentPool) {
      if (card?.id) byId.set(card.id, card);
    }
    for (const [id, card] of this.cardCache) {
      if (card?.realm && !byId.has(id)) byId.set(id, card);
    }
    return [...byId.values()];
  }

  _getNormalCardBaseWeight(card, state = gameState) {
    let weight = card?.weight !== undefined ? Number(card.weight) : 5;
    if (!Number.isFinite(weight) || weight <= 0) return 0;

    const declaredPaths = this.normalizeCardPaths(card);
    if (declaredPaths.includes(state?.path)) weight *= 1.5;

    if (state?.attributes?.fortune > 70 && card.tags && !card.tags.includes('risk')) {
      weight += 2;
    }
    if (state?.attributes?.karmaBad > 50 && card.tags && card.tags.includes('demon')) {
      weight *= 1.3;
    }
    return weight;
  }

  _selectWeighted(items, getWeight, random = Math.random) {
    const weighted = [];
    let total = 0;
    for (const item of items) {
      const weight = Number(getWeight(item));
      if (!Number.isFinite(weight) || weight <= 0) continue;
      total += weight;
      weighted.push({ item, weight });
    }
    if (weighted.length === 0 || total <= 0) return null;

    let roll = random() * total;
    for (const entry of weighted) {
      roll -= entry.weight;
      if (roll < 0) return entry.item;
    }
    return weighted[weighted.length - 1].item;
  }

  /**
   * 返回普通抽卡公开分档；测试与其他消费者不得自行复制准入算法。
   */
  getNormalDrawBuckets({
    state = gameState,
    recentPlayed = null
  } = {}) {
    const buckets = {
      current: [],
      previous: [],
      evergreen: []
    };

    for (const card of this._getNormalDrawCards(state)) {
      if (!this.isCardEligibleForNormalDraw(card, state, recentPlayed)) continue;
      const bucket = this.getNormalDrawBucket(card, state);
      if (bucket && buckets[bucket]) buckets[bucket].push(card);
    }
    return buckets;
  }

  /**
   * 普通抽卡的唯一选择入口。
   * weightModifier 只允许追加情绪/场景权重，不负责准入与境界分档。
   */
  drawNormalCard({
    state = gameState,
    recentPlayed = null,
    weightModifier = null,
    random = Math.random
  } = {}) {
    const buckets = this.getNormalDrawBuckets({ state, recentPlayed });
    const bucketWeights = { current: 72, previous: 18, evergreen: 10 };
    const availableBuckets = Object.keys(buckets).filter(name => buckets[name].length > 0);
    const selectedBucket = this._selectWeighted(
      availableBuckets,
      name => bucketWeights[name],
      random
    );
    if (!selectedBucket) return null;

    return this._selectWeighted(
      buckets[selectedBucket],
      card => {
        const baseWeight = this._getNormalCardBaseWeight(card, state);
        if (typeof weightModifier !== 'function') return baseWeight;
        return weightModifier(card, baseWeight, state);
      },
      random
    );
  }

  /**
   * EncounterDirector 的唯一公开候选入口。导演只决定时机，不能复制
   * CardSystem 的境界、流派、道侣、flag、once 或世界层准入算法。
   */
  getEligibleCombatEncounterCards({
    state = gameState,
    currentRealmOnly = true,
    roles = null,
    teachingOnly = false,
    includeDirectorCooldown = false
  } = {}) {
    const acceptedRoles = Array.isArray(roles) && roles.length > 0 ? new Set(roles) : null;
    const cards = [];
    for (const card of this.cardCache.values()) {
      if (!card?.encounterId) continue;
      if (currentRealmOnly && card.realm !== state?.realm) continue;
      if (teachingOnly && card.teachingEncounter !== true) continue;
      if (acceptedRoles && !acceptedRoles.has(card.encounterRole || 'ordinary')) continue;
      if (!this.isCardEligibleForNormalDraw(
        card,
        state,
        new Set(),
        {
          allowDirectorEncounter: true,
          skipEncounterDirector: includeDirectorCooldown
        }
      )) continue;
      cards.push(card);
    }
    return cards;
  }

  /**
   * 返回已实体化的完整遭遇目录，不执行任何玩家状态准入。
   *
   * 这是给内容审计、UI 图鉴和作者工具使用的公开只读入口。运行时调度必须
   * 使用 getEligibleCombatEncounterCards，不能把本方法当作资格绕过器。
   */
  getCombatEncounterCatalogCards({ roles = null, teachingOnly = false } = {}) {
    const acceptedRoles = Array.isArray(roles) && roles.length > 0 ? new Set(roles) : null;
    const cards = [];
    for (const card of this.cardCache.values()) {
      if (!card?.encounterId) continue;
      if (teachingOnly && card.teachingEncounter !== true) continue;
      if (acceptedRoles && !acceptedRoles.has(card.encounterRole || 'ordinary')) continue;
      cards.push(card);
    }
    return cards;
  }

  // ============ 内部方法 ============

  /**
   * 兼容两种既有 karmaCards 数据形态：
   * 1. karmaId -> cardId
   * 2. karmaId -> 内联卡牌定义
   *
   * 内联定义必须同时进入 cardCache，否则成熟因果种子只能拿到一个对象，
   * 后续 getCard(cardId) 永远无法解析到真正的事件卡。
   */
  _cacheKarmaMappings(karmaCards) {
    if (!karmaCards || typeof karmaCards !== 'object') return;

    for (const [karmaId, cardReference] of Object.entries(karmaCards)) {
      if (typeof cardReference === 'string' && cardReference) {
        this.karmaCardMap.set(karmaId, cardReference);
        continue;
      }

      if (cardReference && typeof cardReference === 'object' && cardReference.id) {
        this.cardCache.set(cardReference.id, cardReference);
        this.karmaCardMap.set(karmaId, cardReference.id);
      }
    }
  }

  _loadRealmCards(realm) {
    if (this._loadedRealms.has(realm)) return;

    const data = dataLoader.loadSync('cards:' + realm);
    if (!data) return;

    // 缓存所有卡牌
    if (data.cards) {
      for (const card of data.cards) {
        this.cardCache.set(card.id, card);
      }
    }

    // 缓存秘境数据
    if (data.dungeons) {
      this.dungeonCache.set(realm, data.dungeons);
    }
    if (data.dungeonCards) {
      const realmDC = this.dungeonCardCache.get(realm) || {};
      Object.assign(realmDC, data.dungeonCards);
      this.dungeonCardCache.set(realm, realmDC);
      for (const [id, card] of Object.entries(data.dungeonCards)) {
        this.cardCache.set(id, card);
      }
    }

    // 缓存因果卡映射
    this._cacheKarmaMappings(data.karmaCards);

    this._loadedRealms.add(realm);
    this._hydrateCachedCombatCards();
    eventBus.emit('cards:realmLoaded', { realm });
  }

  _loadDeathCards() {
    const data = dataLoader.loadSync('cards:death');
    if (!data || !data.deathCards) return;

    for (const [cardId, card] of Object.entries(data.deathCards)) {
      this.cardCache.set(cardId, card);
      // 用 reason 映射 cardId
      if (card.reason) {
        this.deathCardMap.set(card.reason, cardId);
      }
    }
  }

  _loadKarmaCards() {
    const data = dataLoader.loadSync('cards:karma');
    if (!data) return;

    // 缓存所有因果卡
    if (data.cards) {
      for (const card of data.cards) {
        this.cardCache.set(card.id, card);
      }
    }

    // 缓存 karmaCards 映射 (karmaId → cardId)
    this._cacheKarmaMappings(data.karmaCards);

    eventBus.emit('cards:realmLoaded', { realm: 'karma' });
  }

  /**
   * 加载额外的卡牌模块（不属于某个境界的独立模块）
   * @param {string} moduleName - 如 'cards:demonic_seductress'
   */
  _loadExtraModule(moduleName) {
    const data = dataLoader.loadSync(moduleName);
    if (!data) return;

    // 缓存所有卡牌
    if (data.cards) {
      for (const card of data.cards) {
        this.cardCache.set(card.id, card);
      }
    }

    // 缓存 karmaCards 映射（如果有）
    this._cacheKarmaMappings(data.karmaCards);
  }

  _drawNormal() {
    // 最近 N 张玩过的卡会进入"冷却"，避免连续抽到同一张
    const recentPlayed = new Set(gameState.cardsPlayed.slice(-8));
    const selected = this.drawNormalCard({ state: gameState, recentPlayed });
    if (!selected) {
      const fallback = this.getCard('q_meditation');
      if (fallback) return fallback;
      // 连冥想卡都找不到 — 生成通用事件卡作为最后兜底
      return this._buildFallbackEventCard();
    }
    return selected;
  }

  _drawDeathCard() {
    // 1. 优先使用确切死因契约 deathCauseId
    if (gameState.deathCauseId) {
      const card = this.getCard(gameState.deathCauseId);
      if (card) return card;
    }

    // 2. 精确 deadReason 查找
    if (gameState.deadReason) {
      const deathCardId = this.deathCardMap.get(gameState.deadReason);
      if (deathCardId) {
        const card = this.getCard(deathCardId);
        if (card) return card;
      }

      // 3. 死因文本智能关键词模糊匹配，防止盲目降级回退第一张卡
      const reasonText = String(gameState.deadReason);
      if (reasonText.includes('道心') || reasonText.includes('走火入魔')) {
        const card = this.getCard('death_dao_collapse');
        if (card) return card;
      }
      if (reasonText.includes('气血') || reasonText.includes('身死')) {
        const card = this.getCard('death_blood_loss');
        if (card) return card;
      }
      if (reasonText.includes('寿元') || reasonText.includes('坐化')) {
        const card = this.getCard('death_lifespan');
        if (card) return card;
      }
      if (reasonText.includes('善') || reasonText.includes('仁慈')) {
        const card = this.getCard('death_karma_good');
        if (card) return card;
      }
      if (reasonText.includes('恶') || reasonText.includes('天劫')) {
        const card = this.getCard('death_karma_bad');
        if (card) return card;
      }
      if (reasonText.includes('厄运') || reasonText.includes('天诛')) {
        const card = this.getCard('death_fortune_zero');
        if (card) return card;
      }
    }

    // 4. 兜底：返回第一张死亡卡
    for (const [, cardId] of this.deathCardMap) {
      const card = this.getCard(cardId);
      if (card) return card;
    }
    // 5. 终极兜底：deathCardMap 为空或所有卡加载失败
    return this._buildFallbackDeathCard();
  }

  /**
   * 战斗遭遇目录是敌人、战场、奖励与结果联动的唯一来源。
   * 这里将目录实体化为普通抽卡池里的双选项叙事卡，避免“有数据但无入口”。
   */
  _loadCombatEncounterCards(pathId = null) {
    const catalog = dataLoader.loadSync('combat:encounters');
    const presentationCatalog = dataLoader.loadSync('combat:encounter_presentations');
    if (!catalog || !Array.isArray(catalog.encounters)) return;
    for (const encounter of catalog.encounters) {
      const presentation = presentationCatalog?.presentations?.[encounter.id] || null;
      const hydratedEncounter = presentation
        ? {
            ...encounter,
            combatPresentation: {
              ...(encounter.combatPresentation || {}),
              ...this._cloneCombatValue(presentation)
            }
          }
        : encounter;
      const card = this._buildCombatEncounterCard(hydratedEncounter, catalog, pathId);
      if (card) this.cardCache.set(card.id, card);
    }
  }

  refreshCombatEncounterCards(pathId) {
    const normalizedPath = typeof pathId === 'string' && pathId ? pathId : null;
    this._loadCombatEncounterCards(normalizedPath);
    this._hydrateCachedCombatCards();
    return normalizedPath !== null;
  }

  /**
   * 把旧境界卡与叙事线程卡的选择方向解析为稳定的战场呈现。
   * 返回克隆对象，避免修改 DATA_MODULES 或外部 JSON 的权威数据。
   */
  hydrateCombatCardPresentation(card) {
    if (!card || !card.id || !card.choices) return card;
    const catalog = dataLoader.loadSync('combat:migrated_presentations');
    const presentations = catalog?.presentations;
    if (!presentations) return card;

    let hydratedCard = null;
    for (const direction of ['left', 'right', 'up', 'down']) {
      const presentation = presentations[`${card.id}:${direction}`];
      const sourceChoice = card.choices[direction];
      if (!presentation || !sourceChoice) continue;
      if (!hydratedCard) {
        hydratedCard = {
          ...card,
          choices: { ...card.choices }
        };
      }
      const frozenPresentation = this._cloneCombatValue(presentation);
      // Migrated media owns colliding visual fields, while the authored
      // choice still owns non-visual combat promises such as storyAssist.
      const combatPresentation = {
        ...(sourceChoice.combatPresentation
          && typeof sourceChoice.combatPresentation === 'object'
          ? this._cloneCombatValue(sourceChoice.combatPresentation) : {}),
        ...frozenPresentation
      };
      hydratedCard.choices[direction] = {
        ...sourceChoice,
        battlefield: frozenPresentation.battlefield,
        sceneImage: frozenPresentation.sceneImage,
        combatPresentation
      };
      if (!hydratedCard.sceneImage) hydratedCard.sceneImage = frozenPresentation.sceneImage;
      if (!hydratedCard.combatPresentation) {
        hydratedCard.combatPresentation = this._cloneCombatValue(combatPresentation);
      }
    }
    return hydratedCard || card;
  }

  _hydrateCachedCombatCards() {
    for (const [cardId, card] of this.cardCache) {
      this.cardCache.set(cardId, this.hydrateCombatCardPresentation(card));
    }
  }

  _withEncounterPlanGraph(encounter, pathId = null) {
    if (!encounter?.enemy) return null;
    const enemy = this._cloneCombatValue(encounter.enemy);
    // Realm Boss ownership belongs to the chapter Gate cards. Keep catalog
    // Boss projections byte-for-byte compatible and never let the ordinary
    // encounter upgrader invent a second Boss authority.
    const roleByCategory = {
      archetypeTrial: 'ordinary',
      realmPatrol: 'ordinary',
      factionElite: 'elite',
      companionQuest: 'relationship',
      heavenChaos: 'quest',
      realmQuotaOrdinary: 'ordinary',
      realmQuest: 'quest',
      realmElite: 'elite',
      realmBoss: 'boss'
    };
    const role = encounter.encounterRole
      || roleByCategory[encounter.category]
      || (Number(enemy.tier) >= 2 ? 'elite' : 'ordinary');
    const isBoss = role === 'boss' || encounter.encounterKind === 'realm_boss';
    const isElite = isBoss || role === 'elite';
    if (isBoss || encounter.category === 'realmBoss') return enemy;

    const directorConfig = dataLoader.loadSync('combat:encounter_director') || {};
    const microBalance = directorConfig.roleMicroBalance || {};
    let attackDelta = 0;
    if (!(microBalance.excludeTeaching === true && encounter.teachingEncounter === true)) {
      const roleKey = isElite ? 'elite' : (role === 'ordinary' ? 'ordinary' : 'defaultNonBoss');
      const pathBalance = microBalance.pathOverrides?.[pathId];
      const pathRule = pathBalance?.realmOverrides?.[encounter.realm]?.[roleKey]
        || pathBalance?.[roleKey];
      const balanceRule = pathRule || (isElite
        ? microBalance.elite
        : (role === 'ordinary' ? microBalance.ordinary : microBalance.defaultNonBoss));
      const hpDelta = Math.floor(Number(balanceRule?.enemyHpDelta) || 0);
      if (hpDelta !== 0) {
        enemy.hp = Math.max(1, Math.floor(Number(enemy.hp) || 1) + hpDelta);
        if (Number.isFinite(Number(enemy.maxHp))) {
          enemy.maxHp = Math.max(enemy.hp, Math.floor(Number(enemy.maxHp)) + hpDelta);
        }
      }
      attackDelta = Math.floor(Number(balanceRule?.enemyAtkDelta) || 0);
      if (attackDelta !== 0) {
        enemy.atk = Math.max(1, Math.floor(Number(enemy.atk) || Number(enemy.tier) || 1) + attackDelta);
      }
    }

    const adjustAttackIntent = sourceIntent => {
      const intent = this._cloneCombatValue(sourceIntent);
      if (!intent || attackDelta === 0 || !['attack', 'piercing_attack'].includes(intent.type)) return intent;
      const oldValue = Math.max(1, Math.floor(Number(intent.value) || 1));
      const nextValue = Math.max(1, oldValue + attackDelta);
      intent.value = nextValue;
      if (typeof intent.desc === 'string') {
        intent.desc = intent.desc.replace(/造成\d+点伤害/, `造成${nextValue}点伤害`);
      }
      return intent;
    };
    const adjustPlanGraph = sourceGraph => {
      const graph = this._cloneCombatValue(sourceGraph);
      if (!graph || attackDelta === 0) return graph;
      for (const state of Object.values(graph.states || {})) {
        if (state?.intent) state.intent = adjustAttackIntent(state.intent);
      }
      return graph;
    };
    if (Array.isArray(enemy.intents) && attackDelta !== 0) {
      enemy.intents = enemy.intents.map(adjustAttackIntent);
    }
    if (enemy.planGraph) {
      enemy.planGraph = adjustPlanGraph(enemy.planGraph);
      return enemy;
    }
    const battleCatalog = dataLoader.loadSync('cards:battle_cards');
    const template = Array.isArray(battleCatalog?.enemies)
      ? battleCatalog.enemies.find(candidate => candidate?.id === enemy.templateId)
      : null;
    if (template?.planGraph) {
      if (attackDelta !== 0) enemy.planGraph = adjustPlanGraph(template.planGraph);
      return enemy;
    }

    const attack = Math.max(1, Math.floor(Number(enemy.atk) || Number(enemy.tier) || 1));
    const defense = Math.max(0, Math.floor(Number(enemy.def) || 0));
    // Generic encounters share a readable one-point pressure step. Elite
    // identity comes from the extra repeated-type counter branch rather than
    // stacking hidden block and damage on every state.
    const pressureDamage = attack + (isBoss ? 3 : 1);
    const label = String(enemy.name || encounter.title || '敌手');
    const states = {
      OBSERVE: {
        label: '观势',
        cue: `${label}正在辨认你的出牌节奏。`,
        intent: {
          type: 'defend',
          value: Math.max(1, defense),
          desc: `观势：获得${Math.max(1, defense)}点护盾`,
          actionName: `${label}收住攻势，护住中线并观察你的真元去向`
        }
      },
      PRESSURE: {
        label: '追击空档',
        cue: `${label}抓住你耗尽真元后的空档。`,
        intent: {
          type: 'attack',
          value: pressureDamage,
          desc: `追击：造成${pressureDamage}点伤害`,
          actionName: `${label}在真元枯竭的一刻抢入空门，发动重击`
        }
      },
      EXPOSED: {
        label: '失衡破绽',
        cue: `你改变节奏，${label}的预判落空。`,
        intent: {
          type: 'defend',
          value: 0,
          desc: '失衡：本轮不造成伤害',
          actionName: `${label}失去攻击落点，被迫重新调整架势`
        }
      }
    };
    const transitions = [
      { from: 'OBSERVE', when: 'player_overcommitted', to: 'PRESSURE', minCards: 2, maxReservedQi: 1 },
      { from: 'OBSERVE', when: 'player_reserved_resource', to: 'EXPOSED', maxCards: 1, minReservedQi: 2 },
      { from: ['OBSERVE', 'PRESSURE'], when: 'deflected', to: 'EXPOSED' },
      { from: ['PRESSURE', 'EXPOSED'], when: 'action_resolved', to: 'OBSERVE' }
    ];
    if (isElite) {
      const counterDamage = attack;
      states.COUNTER = {
        label: '同式反制',
        cue: `${label}已经看穿你连续重复的牌型。`,
        intent: {
          type: 'attack',
          value: counterDamage,
          piercing: true,
          desc: `反制：穿透造成${counterDamage}点伤害`,
          actionName: `${label}沿重复招路切入，以反制手段越过外层护势`
        }
      };
      transitions.unshift({
        from: 'OBSERVE', when: 'repeated_card_type', to: 'COUNTER', minConsecutive: 2
      });
      transitions.splice(transitions.length - 1, 0, {
        from: 'COUNTER', when: 'deflected', to: 'EXPOSED'
      });
      transitions[transitions.length - 1].from.push('COUNTER');
    }
    enemy.planGraph = {
      planId: `catalog_${encounter.id}_reactive_v1`,
      initialState: 'OBSERVE',
      states,
      transitions
    };
    return enemy;
  }

  _buildCombatEncounterCard(encounter, catalog = null, pathId = null) {
    if (!encounter || !encounter.id || !encounter.enemy || !encounter.realm) return null;
    const categoryWeights = {
      realmBoss: 1,
      archetypeTrial: 2,
      factionElite: 1,
      companionQuest: 2,
      heavenChaos: 1,
      realmQuotaOrdinary: 1,
      realmQuest: 1,
      realmElite: 1
    };
    const challenge = this.resolveCombatEncounterChoice(encounter.id, encounter, catalog, pathId);
    if (!challenge) return null;
    const avoid = encounter.avoid || {};
    const presentation = encounter.combatPresentation || {};
    const encounterKind = encounter.encounterKind
      || (encounter.category === 'realmBoss' ? 'realm_boss' : 'ordinary');
    const roleByCategory = {
      archetypeTrial: 'ordinary',
      realmPatrol: 'ordinary',
      factionElite: 'elite',
      companionQuest: 'relationship',
      heavenChaos: 'quest',
      realmQuotaOrdinary: 'ordinary',
      realmQuest: 'quest',
      realmElite: 'elite',
      realmBoss: 'boss'
    };
    const encounterRole = encounter.encounterRole || roleByCategory[encounter.category] || 'ordinary';
    const avoidHasCost = Object.values(avoid.effects || {}).some(value => (
      typeof value === 'number' && value < 0
    )) || Object.values(avoid.costCheck || {}).some(value => Number(value) > 0);
    const avoidanceNarrative = avoid.narrativeBlock || (!avoidHasCost
      ? `${avoid.desc || `你没有立刻迎战${encounter.enemy.name}。`} ${encounter.worldStory || encounter.mechanic || '你记下敌手的路数，准备在下一次相逢时给出答案。'}`
      : null);
    return {
      id: `encounter_card_${encounter.id}`,
      encounterId: encounter.id,
      encounterKind,
      encounterRole,
      teachingEncounter: encounter.teachingEncounter === true,
      narrativeSource: encounter.narrativeSource || `encounter_catalog:${encounter.category}:${encounter.id}`,
      originThreadId: encounter.originThreadId || null,
      originNodeId: encounter.originNodeId || null,
      title: encounter.title,
      description: encounter.description,
      type: 'COMBAT',
      realm: encounter.realm,
      path: encounter.path || null,
      weight: encounter.weight ?? categoryWeights[encounter.category] ?? 1,
      once: encounter.once !== false,
      category: encounter.category,
      requiredCompanion: encounter.requiredCompanion || null,
      requiresFlags: encounter.requiresFlags || null,
      requiresAnyFlags: Array.isArray(encounter.requiresAnyFlags)
        ? [...encounter.requiresAnyFlags]
        : null,
      forbiddenFlags: encounter.forbiddenFlags || null,
      mechanic: encounter.mechanic || '',
      worldStory: encounter.worldStory || '',
      tags: ['combat', 'encounter', encounter.category].filter(Boolean),
      sceneImage: presentation.sceneImage || encounter.sceneImage || null,
      combatPresentation: this._cloneCombatValue(presentation) || {},
      choices: {
        left: {
          text: encounter.challengeText || `迎战·${encounter.enemy.name}`,
          desc: encounter.mechanic || '进入战斗；胜败与撤离会分别结算。',
          ...challenge
        },
        right: {
          text: avoid.text || '避开此战',
          desc: avoid.desc || '保留当前状态，不触发本场战斗的结果联动。',
          effects: this._cloneCombatValue(avoid.effects || {}) || {},
          costCheck: this._cloneCombatValue(avoid.costCheck),
          narrativeBlock: avoidanceNarrative
        }
      }
    };
  }

  /**
   * Pure normalization shared by choice preview, initial handoff and restore.
   * Already-warm modules only: no source lookup, hydration, state write or RNG.
   * A caller restoring a selected hit consumes combatChoice without rerolling.
   */
  resolveChoiceCombatContract(card, direction, rawChoice, pathId = null) {
    const choice = rawChoice && typeof rawChoice === 'object'
      ? JSON.parse(JSON.stringify(rawChoice))
      : null;
    if (!choice) return { kind: 'none', valid: false, reason: 'missing_choice', message: '选择不存在。' };
    const probabilistic = Object.prototype.hasOwnProperty.call(choice, 'combatChance');
    const hasEncounter = Object.prototype.hasOwnProperty.call(choice, 'combatEncounterId');
    const hasTrigger = Boolean(choice.triggerCombat || choice.effects?.triggerCombat);
    const kind = probabilistic ? 'chance' : (hasEncounter || hasTrigger ? 'direct' : 'none');
    const contract = { kind, valid: true, reason: null, ordinaryChoice: choice, combatChoice: null };
    if (kind === 'none') return contract;
    if (probabilistic) {
      const chance = Number(choice.combatChance);
      contract.chance = chance;
      if (!Number.isFinite(chance) || chance < 0 || chance > 1) {
        return { ...contract, valid: false, reason: 'invalid_combat_chance', message: `combatChance=${choice.combatChance}` };
      }
      // A zero chance never needed an encounter, even if its reference is stale.
      if (chance === 0) return contract;
    } else if (!hasTrigger) {
      return {
        ...contract, valid: false, reason: 'combat_encounter_without_trigger',
        message: `${card?.id || 'unknown'}.${direction} 声明了遭遇但没有标准战斗入口。`
      };
    } else if (!hasEncounter) {
      // Existing inline combat choices already own their battle contract.
      return { ...contract, combatChoice: choice };
    }

    // This is a read-only normalization of already-warm production modules:
    // no card hydration, pending encounter, state write, event or RNG. Preserve
    // the existing path distinction instead of changing combat balance here.
    const encounterId = choice.combatEncounterId;
    const encounterChoice = encounterId && (probabilistic
      ? this.resolveCombatEncounterChoice?.(encounterId)
      : this.resolveCombatEncounterChoice?.(encounterId, null, null, pathId));
    if (!encounterChoice?.triggerCombat || !encounterChoice?.enemy) {
      return {
        ...contract,
        // A missing hit contract cannot turn a valid ordinary miss into a
        // guaranteed refusal. Execution still rejects when that hit is rolled.
        valid: probabilistic && contract.chance < 1,
        reason: 'unresolved_combat_encounter',
        message: `${card?.id || 'unknown'}.${direction} 无法解析遭遇 ${encounterId || '(missing)'}`
      };
    }
    if (!probabilistic) {
      return {
        ...contract,
        combatChoice: {
          ...choice,
          ...encounterChoice,
          combatEncounterId: encounterId,
          ...(choice.entryEffects ? { entryEffects: choice.entryEffects } : {}),
          ...(choice.combatOutcomePresentation ? { combatOutcomePresentation: choice.combatOutcomePresentation } : {})
        }
      };
    }
    const sourceEffects = choice.effects && typeof choice.effects === 'object' ? choice.effects : {};
    const encounterVictory = encounterChoice.victoryEffects && typeof encounterChoice.victoryEffects === 'object'
      ? encounterChoice.victoryEffects
      : {};
    const victoryEffects = { ...sourceEffects };
    for (const [key, value] of Object.entries(encounterVictory)) {
      if (Number.isFinite(Number(value)) && Number.isFinite(Number(victoryEffects[key]))) {
        victoryEffects[key] = Number(victoryEffects[key]) + Number(value);
      } else {
        victoryEffects[key] = value;
      }
    }
    return {
      ...contract,
      combatChoice: {
        ...choice,
        ...encounterChoice,
        // Source causality and encounter loot settle together, and only after
        // victory. Defeat/flee remain owned by the encounter contract.
        victoryEffects,
        combatChance: contract.chance,
        combatEncounterId: encounterId
      }
    };
  }

  /**
   * 将单条遭遇解析为 CombatCoordinator 可消费的冻结选择契约。
   * 可传入已加载记录以避免重复读取；外部系统也可只传 encounterId。
   */
  resolveCombatEncounterChoice(encounterId, resolvedEncounter = null, resolvedCatalog = null, pathId = null) {
    if (!encounterId) return null;
    const catalog = resolvedCatalog || dataLoader.loadSync('combat:encounters');
    const encounterSource = resolvedEncounter ||
      (catalog && Array.isArray(catalog.encounters)
        ? catalog.encounters.find(item => item.id === encounterId)
        : null);
    if (!encounterSource) return null;
    const presentationCatalog = dataLoader.loadSync('combat:encounter_presentations');
    const presentation = presentationCatalog?.presentations?.[encounterId] || null;
    const encounter = presentation
      ? {
          ...encounterSource,
          combatPresentation: {
            ...(encounterSource.combatPresentation || {}),
            ...this._cloneCombatValue(presentation)
          }
        }
      : encounterSource;
    const tier = String(Number(encounter.enemy?.tier || 1));
    const tierLoss = Number(catalog?.defeatHealthLossByTier?.[tier] || tier || 1);
    return {
      encounterId: encounter.id,
      encounterKind: encounter.encounterKind
        || (encounter.category === 'realmBoss' ? 'realm_boss' : 'ordinary'),
      triggerCombat: true,
      enemy: this._withEncounterPlanGraph(encounter, pathId),
      battlefield: encounter.combatPresentation?.battlefield || encounter.battlefield || null,
      combatPresentation: this._cloneCombatValue(encounter.combatPresentation || {}) || {},
      victoryEffects: this._cloneCombatValue(encounter.victoryEffects || {}) || {},
      // 未声明撤离代价时必须保留 undefined，让 GameLogic 使用权威默认 lifespan -1。
      ...(encounter.defeatEffects !== undefined
        ? { defeatEffects: this._cloneCombatValue(encounter.defeatEffects) }
        : {}),
      ...(encounter.fleeEffects !== undefined
        ? { fleeEffects: this._cloneCombatValue(encounter.fleeEffects) }
        : {}),
      defeatHealthLoss: Number(encounter.defeatHealthLoss || tierLoss),
      combatRewards: this._cloneCombatValue(encounter.victoryEffects || {}) || {},
      combatOutcomeLinks: this._cloneCombatValue(encounter.outcomeLinks || {}) || {},
      ...(encounter.combatOutcomePresentation
        ? { combatOutcomePresentation: this._cloneCombatValue(encounter.combatOutcomePresentation) }
        : {}),
      karmaSeed: this._cloneCombatValue(encounter.karmaSeed),
      karmaSeedOn: this._cloneCombatValue(encounter.karmaSeedOn)
    };
  }

  _cloneCombatValue(value) {
    return value === undefined ? undefined : JSON.parse(JSON.stringify(value));
  }

  _drawKarmaCard() {
    if (typeof karmaSystem === 'undefined' || !karmaSystem ||
        typeof karmaSystem.getReadySeeds !== 'function') return null;
    const ready = karmaSystem.getReadySeeds();
    if (ready.length === 0) return null;
    const closeSeed = (seed, cardId, reason) => {
      karmaSystem.removeSeed(seed);
      eventBus.emit('karma:seedClosed', { seedId: seed.id, cardId, reason });
    };

    // 成熟性、境界可达性与有效优先级均由 KarmaSystem 统一解释。
    // 内容解析成功之前不能消费种子；坏引用也不能阻塞队列中其他有效因果。
    for (const seed of ready) {
      const cardId = seed.payoffEvent || this.karmaCardMap.get(seed.id);
      if (!cardId) {
        eventBus.emit('karma:seedUnresolved', {
          seedId: seed.id,
          reason: 'missing_payoff_mapping'
        });
        continue;
      }

      const card = this.getCard(cardId);
      if (!card) {
        eventBus.emit('karma:seedUnresolved', {
          seedId: seed.id,
          cardId,
          reason: 'missing_payoff_card'
        });
        continue;
      }
      const continuity = typeof worldContinuityStore !== 'undefined'
        ? worldContinuityStore
        : null;
      if (card.npcId && continuity?.getNpcState && continuity?.canManifest) {
        const npcState = continuity.getNpcState(card.npcId);
        if (npcState?.lifecycle === 'DEAD' && (card.manifestation || 'PHYSICAL') === 'PHYSICAL') {
          closeSeed(seed, cardId, 'payoff_npc_dead');
          continue;
        }
        if (!continuity.canManifest(card.npcId, card.manifestation || 'PHYSICAL')) {
          eventBus.emit('karma:seedDeferred', {
            seedId: seed.id, cardId, reason: 'payoff_npc_unavailable'
          });
          continue;
        }
      }
      if (card.once && gameState.cardsPlayed?.includes(cardId)) {
        closeSeed(seed, cardId, 'already_settled_once');
        continue;
      }
      if (Array.isArray(card.payoffRequiresPlayed)) {
        const missingPrequels = card.payoffRequiresPlayed.filter(requiredId =>
          !gameState.cardsPlayed?.includes(requiredId));
        if (missingPrequels.length > 0) {
          const pendingPrequels = missingPrequels.every(requiredId =>
            gameState.karmaSeeds?.some(other => other !== seed
              && (other.payoffEvent || this.karmaCardMap.get(other.id)) === requiredId));
          if (!pendingPrequels) {
            closeSeed(seed, cardId, 'payoff_prequel_unreachable');
          } else {
            eventBus.emit('karma:seedDeferred', {
              seedId: seed.id, cardId, reason: 'payoff_prequel_pending'
            });
          }
          continue;
        }
      }
      if (seed.path && !(
        Array.isArray(card.tags)
        && (card.tags.includes(seed.path) || card.tags.includes('path:' + seed.path))
      )) {
        eventBus.emit('karma:seedUnresolved', {
          seedId: seed.id,
          cardId,
          reason: 'payoff_path_mismatch',
          expectedPath: seed.path
        });
        continue;
      }
      const realmOrder = this._getRealmOrder(gameState);
      const currentRealmIndex = realmOrder.indexOf(gameState.realm || 'qi');
      const payoffRealmIndices = this._getCardRealms(card).map(realm => realmOrder.indexOf(realm));
      if (currentRealmIndex < 0 || payoffRealmIndices.some(index => index < 0)) {
        eventBus.emit('karma:seedUnresolved', {
          seedId: seed.id, cardId, reason: 'invalid_payoff_realm'
        });
        continue;
      }
      if (currentRealmIndex < Math.min(...payoffRealmIndices)) {
        eventBus.emit('karma:seedDeferred', {
          seedId: seed.id, cardId, reason: 'payoff_realm_pending'
        });
        continue;
      }
      if (!this.isCardAllowedForWorldLayer(card, gameState)) {
        eventBus.emit('karma:seedDeferred', {
          seedId: seed.id,
          cardId,
          reason: 'world_layer_mismatch'
        });
        continue;
      }
      if (typeof narrativeLedger !== 'undefined' && narrativeLedger?.evaluate) {
        const admission = narrativeLedger.evaluate(card, { state: gameState });
        if (!admission.allowed) {
          if (admission.reason === 'semantic_once_resolved') {
            closeSeed(seed, cardId, admission.reason);
          } else {
            eventBus.emit('karma:seedDeferred', {
              seedId: seed.id, cardId, reason: admission.reason
            });
          }
          continue;
        }
      }

      const materializedCard = this._materializeKarmaCard(card, seed);
      const presentedCard = materializedCard === card
        ? this._cloneCombatValue(card)
        : materializedCard;
      presentedCard._karmaSeedId = seed.id;
      presentedCard._karmaCardId = cardId;
      eventBus.emit('karma:seedPresented', { seedId: seed.id, cardId });
      return presentedCard;
    }

    return null;
  }

  _isUpperRealmActive(state = gameState) {
    return typeof state.hasFlag === 'function'
      ? state.hasFlag('post_ascension_active')
      : Boolean(state.flags?.post_ascension_active);
  }

  _drawUpperRealmCard() {
    const continuationId = typeof gameState.getFlag === 'function'
      ? gameState.getFlag('post_ascension_next_card')
      : gameState.flags?.post_ascension_next_card;
    if (continuationId) {
      const continuation = this.getCard(continuationId);
      if (continuation && this.isCardAllowedForWorldLayer(continuation, gameState)) {
        this._lastDrawnPriority = 95;
        return continuation;
      }
    }

    const karmaCard = this._drawKarmaCard();
    if (karmaCard) {
      this._lastDrawnPriority = 60;
      return karmaCard;
    }

    this._lastDrawnPriority = 10;
    const card = this._drawNormal();
    if (card && this.isCardAllowedForWorldLayer(card, gameState)) return card;
    return {
      id: 'upper_realm_meditation_fallback',
      title: '云中城·调息',
      description: '上界灵压如潮，你在云台边缘重新校准经脉，没有让下界旧事越层闯入。',
      type: 'NORMAL',
      realm: 'tribulation',
      worldLayer: 'upper_realm',
      weight: 0,
      choices: {
        left: { text: '顺应上界灵压', effects: { cultivation: 2 } },
        right: { text: '观察云城法则', effects: { tianji: 1 } }
      }
    };
  }

  /**
   * 将共享的动态因果卡模板实例化为某一位道侣的独立卡面。
   * 只处理明确标记 companion_dynamic 的卡，避免普通剧情文本被意外替换；
   * 深拷贝保证不会污染 CardSystem 的全局缓存。
   */
  _materializeKarmaCard(card, seed) {
    if (!card || !Array.isArray(card.tags)) {
      return card;
    }
    const isCompanionDynamic = card.tags.includes('companion_dynamic');
    const isChapterVariantDynamic = card.tags.includes('chapter_variant_dynamic');
    const isThreadReceiptDynamic = card.tags.includes('thread_receipt_dynamic');
    if (!isCompanionDynamic && !isChapterVariantDynamic && !isThreadReceiptDynamic) return card;

    if (isThreadReceiptDynamic) {
      const copy = this._cloneCombatValue(card);
      const threadId = card.threadReceiptSource;
      const receipt = seed?.originThread === threadId
        && typeof threadEngine !== 'undefined'
        ? threadEngine.getCompletionReceipt?.(threadId)
        : null;
      const selected = receipt?.nodes?.find(node => node.nodeId === card.threadReceiptNodeId);
      const variant = selected && card.threadReceiptVariants?.[selected.direction];
      if (variant && typeof variant === 'object') {
        if (typeof variant.description === 'string') copy.description = variant.description;
        if (variant.choices && typeof variant.choices === 'object') {
          for (const [direction, override] of Object.entries(variant.choices)) {
            if (copy.choices?.[direction] && override && typeof override === 'object') {
              copy.choices[direction] = { ...copy.choices[direction], ...override };
            }
          }
        }
      }
      return copy;
    }

    const context = seed && seed.context && typeof seed.context === 'object'
      ? seed.context
      : {};
    const companionId = context.companionId || 'unknown_companion';
    const replacements = {
      '{{companion}}': context.companionName || companionId,
      '{{companionId}}': companionId,
      '{{milestoneId}}': context.milestoneId || '',
      '{{seedId}}': seed && seed.id ? seed.id : '',
      '{{sourceTitle}}': context.sourceTitle || seed?.originCard || '旧日选择',
      '{{choiceText}}': context.choiceText || seed?.originChoice || '当时的取舍',
      '{{realm}}': context.realm || seed?.realm || '',
      '{{path}}': context.path || seed?.path || ''
    };

    const materialize = (value) => {
      if (typeof value === 'string') {
        return Object.entries(replacements).reduce(
          (result, [token, replacement]) => result.split(token).join(String(replacement)),
          value
        );
      }
      if (Array.isArray(value)) return value.map(materialize);
      if (value && typeof value === 'object') {
        return Object.fromEntries(
          Object.entries(value).map(([key, child]) => [key, materialize(child)])
        );
      }
      return value;
    };

    return materialize(card);
  }

  // ============ 转世回响卡（优先级55） ============

  /**
   * 抽取转世回响卡：当玩家转世次数满足要求时，
   * 从 karma + rebirth 卡池中筛选出带有 requirements.minLifeCount 的卡
   */
  _drawReincarnationCard() {
    const lifeCount = gameState.getLifeCount ? gameState.getLifeCount() : 0;
    if (lifeCount < 1) return null;

    // 防止频繁出现：每 10-15 回合才可能触发一次
    if (gameState.turn % 12 !== 0 && gameState.turn > 0) return null;
    // 20% 概率
    if (Math.random() > 0.2) return null;

    // 合并 karma + rebirth 两个卡池
    const allCards = [];
    const karmaData = dataLoader.loadSync('cards:karma');
    if (karmaData && karmaData.cards) allCards.push(...karmaData.cards);
    const rebirthData = dataLoader.loadSync('cards:rebirth');
    if (rebirthData && rebirthData.cards) allCards.push(...rebirthData.cards);

    if (allCards.length === 0) return null;

    const realm = gameState.realm;
    const candidates = [];

    for (const card of allCards) {
      if (!card.requirements) continue;
      if (!card.requirements.minLifeCount) continue;
      if (!this._checkRequirements(card, gameState)) continue;

      // 境界过滤
      if (card.realm) {
        const realms = card.realm.split(',').map(item => item.trim()).filter(Boolean);
        if (!realms.includes(realm)) continue;
      }

      // 冷却
      if (card.once && gameState.cardsPlayed.includes(card.id)) continue;
      if (!this.isNarrativeCardEligible(card, gameState)) continue;

      candidates.push(card);
    }

    if (candidates.length === 0) return null;
    return candidates[Math.floor(Math.random() * candidates.length)];
  }

  /**
   * 通用卡牌 requirements 检查
   * @param {Object} card
   * @returns {boolean}
   */
  _checkRequirements(card, state = gameState) {
    if (!card.requirements) return true;
    const req = card.requirements;

    if (req.minLifeCount !== undefined) {
      const lifeCount = state.getLifeCount ? state.getLifeCount() : 0;
      if (lifeCount < req.minLifeCount) return false;
    }

    if (req.minTurn !== undefined) {
      const currentTurn = Math.max(0, Math.floor(Number(state.turn) || 0));
      if (currentTurn < Math.max(0, Math.floor(Number(req.minTurn) || 0))) return false;
    }

    if (req.differentPaths) {
      const path = state.path;
      const legacy = state.unlocks?.legacy?.pathMemories || {};
      const otherPaths = Object.keys(legacy).filter(p => p !== path && legacy[p] > 0);
      if (otherPaths.length === 0) return false;
    }

    if (req.pastPath) {
      const legacy = state.unlocks?.legacy?.pathMemories || {};
      if (!(Number(legacy[req.pastPath]) > 0)) return false;
    }

    return true;
  }

  /**
   * 普通抽卡的唯一准入策略。
   * FlowDirector 的情绪加权和 CardSystem 的基础抽卡必须共同调用此方法。
   */
  isCardEligibleForNormalDraw(card, state = gameState, recentPlayed = null, options = {}) {
    if (!card || !card.id) return false;
    if (['DESTINY', 'BOTTLENECK', 'KARMA', 'QUEST', 'TUTORIAL', 'PROLOGUE', 'DEATH', 'ENDING'].includes(card.type)) {
      return false;
    }
    if (card.weight !== undefined && (!Number.isFinite(Number(card.weight)) || Number(card.weight) <= 0)) {
      return false;
    }
    if (!this.isCardAllowedForWorldLayer(card, state)) return false;
    if (!this.isCardAllowedForRealm(card, state.realm, state)) return false;
    // Combat encounter catalog cards have an authoritative owner. Non-Boss
    // encounters may only enter through EncounterDirector; realm Bosses may
    // only enter through Realm Gate. A normal weighted draw is never allowed
    // to bypass either cadence contract.
    if (card.encounterId) {
      if (card.encounterKind === 'realm_boss') {
        if (options.allowRealmBoss !== true) return false;
      } else if (options.allowDirectorEncounter !== true) {
        return false;
      }
    }

    const declaredPaths = this.normalizeCardPaths(card);
    if (declaredPaths.length > 0 && !declaredPaths.includes(state.path)) return false;
    if (card.requiredCompanion) {
      const companions = Array.isArray(state.resources?.companions)
        ? state.resources.companions
        : [];
      if (!companions.includes(card.requiredCompanion)) return false;
    }

    const played = Array.isArray(state.cardsPlayed) ? state.cardsPlayed : [];
    if (card.once && played.includes(card.id)) return false;
    if (recentPlayed && recentPlayed.has(card.id)) return false;
    if (!this.isNarrativeCardEligible(card, state)) return false;

    if (card.requiresFlags) {
      if (typeof state.checkFlags !== 'function' || !state.checkFlags(card.requiresFlags)) return false;
    }
    if (Array.isArray(card.requiresAnyFlags) && card.requiresAnyFlags.length > 0) {
      const hasAny = card.requiresAnyFlags.some(key => (
        typeof state.hasFlag === 'function'
          ? state.hasFlag(key)
          : Boolean(state.flags?.[key])
      ));
      if (!hasAny) return false;
    }
    if (card.forbiddenFlags) {
      for (const [key, value] of Object.entries(card.forbiddenFlags)) {
        const hasFlag = typeof state.hasFlag === 'function' ? state.hasFlag(key) : false;
        const flagValue = typeof state.getFlag === 'function' ? state.getFlag(key) : undefined;
        if (value === null ? hasFlag : flagValue === value) return false;
      }
    }

    const director = typeof encounterDirector !== 'undefined' && encounterDirector
      ? encounterDirector
      : (typeof window !== 'undefined' ? window.encounterDirector : null);
    if (card.type === 'DUNGEON' && director
      && typeof director.canStartAuthoredSequence === 'function') {
      const dungeonIds = Object.values(card.choices || {})
        .map(choice => choice?.dungeon)
        .filter(value => typeof value === 'string' && value);
      const catalog = this._getDungeonCatalog(state.realm);
      const projectedCosts = dungeonIds.map(dungeonId => {
        const dungeon = catalog?.[dungeonId];
        const nodes = Array.isArray(dungeon?.nodes)
          ? dungeon.nodes
          : Object.values(dungeon?.graph || {});
        const combatNodes = nodes.filter(node => {
          const nodeCardId = node?.card;
          const nodeCard = nodeCardId ? this.getCard(nodeCardId) : node;
          return nodeCard?.type === 'COMBAT' || nodeCard?.choices?.left?.triggerCombat === true;
        }).length;
        // The entry choice itself consumes one decision; each combat node
        // adds a warning/result boundary beyond its authored dungeon node.
        return 1 + nodes.length + combatNodes;
      });
      const longestProjection = Math.max(0, ...projectedCosts);
      if (longestProjection > 0 && !director.canStartAuthoredSequence(longestProjection)) {
        return false;
      }
    }
    if (card.encounterId && !options.skipEncounterDirector
      && director && typeof director.canPresent === 'function'
      && !director.canPresent(card, { state })) {
      return false;
    }

    return this._checkRequirements(card, state);
  }

  isCardAllowedForWorldLayer(card, state = gameState) {
    if (!card) return false;
    const inUpperRealm = this._isUpperRealmActive(state);
    if (card.worldLayer === 'upper_realm') return inUpperRealm;
    return !inUpperRealm;
  }

  isNarrativeCardEligible(card, state = gameState) {
    return typeof narrativeLedger === 'undefined' || !narrativeLedger
      || typeof narrativeLedger.canPresent !== 'function'
      || narrativeLedger.canPresent(card, { state });
  }

  // ============ CompanionSystem 桥接（优先级50） ============

  _getCompanionEventCard() {
    let card = null;
    const handler = (data) => {
      if (data.card && this.isNarrativeCardEligible(data.card, gameState)) card = data.card;
    };
    eventBus.once('companion:eventCard', handler);
    eventBus.emit('companion:checkEvent', { gameState });
    eventBus.off('companion:eventCard', handler);
    return card;
  }

  // ============ FactionSystem 桥接（优先级40） ============

  _getFactionEventCard() {
    let card = null;
    const handler = (data) => {
      if (data.card && this.isNarrativeCardEligible(data.card, gameState)) card = data.card;
    };
    eventBus.once('faction:eventCard', handler);
    eventBus.emit('faction:checkEvent', { gameState });
    eventBus.off('faction:eventCard', handler);
    return card;
  }

  // ============ StoryNetwork 桥接（优先级53/51/45/35） ============

  /**
   * 从StoryNetwork获取指定优先级的叙事卡
   */
  _getStoryNetworkCard(expectedPriority) {
    let card = null;
    const handler = (data) => {
      if (data.priority === expectedPriority && data.card
        && this.isNarrativeCardEligible(data.card, gameState)) {
        card = data.card;
      }
    };
    eventBus.once('storynetwork:narrativeCard', handler);
    eventBus.emit('storynetwork:checkNarrative', { gameState });
    eventBus.off('storynetwork:narrativeCard', handler);
    return card;
  }

  // ============ NpcSystem 桥接（优先级30） ============

  _getNpcEncounterCard() {
    let card = null;
    const handler = (data) => {
      if (data.card && this.isNarrativeCardEligible(data.card, gameState)) card = data.card;
    };
    eventBus.once('npc:encounterCard', handler);
    eventBus.emit('npc:getEncounterCard', { gameState });
    eventBus.off('npc:encounterCard', handler);
    return card;
  }

  _getDungeonCatalog(realm = gameState.realm) {
    const realmData = dataLoader.loadSync('cards:' + realm);
    return realmData?.dungeons || this.dungeonCache.get(realm) || {};
  }

  _persistDungeonState() {
    if (typeof gameState.persistCausalSession === 'function') {
      gameState.persistCausalSession();
    }
  }

  getActiveDungeonRun() {
    const run = gameState.dungeonRun;
    if (run && run.status === 'active' && typeof run.sessionId === 'string' && run.sessionId) {
      return { ...run };
    }
    // 旧存档只有 dungeon 四元组。恢复时补出会话，而不是丢掉正在进行的探索。
    if (typeof gameState.dungeon === 'string' && gameState.dungeon) {
      const life = Number(gameState.getLifeCount?.() || gameState.unlocks?.lifeCount || 0);
      const migrated = {
        sessionId: `dungeon:migrated:${life}:${gameState.realm}:${gameState.dungeon}`,
        dungeonId: gameState.dungeon,
        realm: gameState.realm,
        sourceCardId: null,
        enteredAtTurn: Math.max(0, Number(gameState.turn) || 0),
        status: 'active'
      };
      gameState.dungeonRun = migrated;
      this._persistDungeonState();
      return { ...migrated };
    }
    return null;
  }

  validateDungeonEntry(dungeonId, realm = gameState.realm) {
    const normalizedId = typeof dungeonId === 'string' ? dungeonId.trim() : '';
    const dungeon = normalizedId ? this._getDungeonCatalog(realm)[normalizedId] : null;
    const firstNodeId = dungeon?.graph
      ? (dungeon.startNode || Object.keys(dungeon.graph)[0])
      : null;
    const firstCardId = dungeon?.graph
      ? dungeon.graph?.[firstNodeId]?.card
      : dungeon?.nodes?.[0]?.card;
    const hasPlayableStart = Boolean(
      dungeon
      && (dungeon.graph ? dungeon.graph?.[firstNodeId] : Array.isArray(dungeon.nodes))
      && (firstCardId ? this.getCard(firstCardId) : dungeon.graph?.[firstNodeId])
    );
    return {
      valid: Boolean(normalizedId && hasPlayableStart),
      reason: typeof dungeonId !== 'string'
        ? 'invalid_dungeon_id'
        : (dungeon ? 'invalid_dungeon_start' : 'missing_dungeon'),
      dungeonId: normalizedId || null,
      realm,
      dungeon: dungeon || null
    };
  }

  enterDungeon(dungeonId, context = {}) {
    const contract = this.validateDungeonEntry(dungeonId);
    const normalizedId = contract.dungeonId;
    const realm = contract.realm;

    if (!contract.valid) {
      const rejection = {
        entered: false,
        reason: contract.reason,
        dungeonId: normalizedId,
        realm,
        sourceCardId: context.sourceCardId || null
      };
      eventBus.emit('dungeon:entryRejected', rejection);
      return rejection;
    }

    if (this.getActiveDungeonRun()) {
      return { entered: false, reason: 'dungeon_already_active', dungeonId: normalizedId, realm };
    }

    const life = Number(gameState.getLifeCount?.() || gameState.unlocks?.lifeCount || 0);
    this._dungeonSessionSequence += 1;
    const sessionId = [
      'dungeon', life, Math.max(0, Number(gameState.turn) || 0), realm,
      normalizedId, Date.now().toString(36), this._dungeonSessionSequence
    ].join(':');
    gameState.dungeon = normalizedId;
    gameState.dungeonNodeIndex = 0;
    gameState.dungeonNodeId = null;
    gameState.dungeonPath = [];
    gameState.dungeonRun = {
      sessionId,
      dungeonId: normalizedId,
      realm,
      sourceCardId: context.sourceCardId || null,
      sourceDecisionIndex: gameState.getCausalDecisionIndex?.() ?? gameState.getNextDecisionIndex?.() ?? 0,
      enteredAtTurn: Math.max(0, Number(gameState.turn) || 0),
      status: 'active'
    };
    this._persistDungeonState();
    const payload = { entered: true, ...gameState.dungeonRun };
    eventBus.emit('dungeon:entered', payload);
    return payload;
  }

  completeDungeon(outcome, reason, extra = {}) {
    const run = this.getActiveDungeonRun();
    if (!run) return null;
    // Keep the active run as the rollback owner until the completion reward
    // and its lineage/world facts have been saved in one causal snapshot.
    const ownsTransaction = !gameState._causalTransaction;
    if (ownsTransaction && gameState.beginCausalTransaction?.() !== true) return null;
    const normalizedOutcome = ['success', 'abandon', 'failure'].includes(outcome)
      ? outcome
      : 'failure';
    const dungeonId = run.dungeonId || gameState.dungeon || null;
    const path = Array.isArray(gameState.dungeonPath) ? gameState.dungeonPath.slice() : [];
    gameState.dungeon = null;
    gameState.dungeonNodeIndex = 0;
    gameState.dungeonNodeId = null;
    gameState.dungeonPath = [];
    gameState.dungeonRun = null;
    const payload = {
      settlementId: `dungeon-settlement:${run.sessionId}`,
      sessionId: run.sessionId,
      dungeonId,
      realm: run.realm || gameState.realm,
      sourceCardId: run.sourceCardId || null,
      sourceDecisionIndex: run.sourceDecisionIndex,
      outcome: normalizedOutcome,
      success: normalizedOutcome === 'success',
      reason: reason || (normalizedOutcome === 'success' ? 'complete' : normalizedOutcome),
      path,
      ...extra,
      settlementOwnsTransaction: ownsTransaction,
      settlementAccepted: false
    };
    this._pendingDungeonSettlements.set(payload.settlementId, payload);
    eventBus.emit('dungeon:completed', payload);
    this._pendingDungeonSettlements.delete(payload.settlementId);
    if (!payload.settlementAccepted && ownsTransaction) gameState.rollbackCausalTransaction?.();
    return payload.settlementAccepted ? payload : null;
  }

  abandonDungeon(reason = 'user_exit', extra = {}) {
    return this.completeDungeon('abandon', reason, extra);
  }

  consumeDungeonSettlement(payload) {
    if (!payload || typeof payload.settlementId !== 'string') return false;
    const authoritative = this._pendingDungeonSettlements.get(payload.settlementId);
    if (!authoritative
      || authoritative.sessionId !== payload.sessionId
      || authoritative.outcome !== payload.outcome
      || authoritative.dungeonId !== payload.dungeonId) {
      return false;
    }
    this._pendingDungeonSettlements.delete(payload.settlementId);
    return true;
  }

  _completeDungeon(success, reason, extra = {}) {
    return this.completeDungeon(success ? 'success' : 'failure', reason, extra);
  }

  _drawDungeonCard() {
    const realmData = dataLoader.loadSync('cards:' + gameState.realm);
    const dungeons = realmData ? realmData.dungeons : this.dungeonCache.get(gameState.realm);
    const dungeon = dungeons ? dungeons[gameState.dungeon] : null;

    if (!dungeon) {
      this.completeDungeon('failure', 'missing_dungeon');
      return this.draw();
    }

    // FIX-4: 图结构模式 — 通过节点 ID 查找
    if (dungeon.graph) {
      return this._drawDungeonGraphCard(dungeon);
    }

    // 兼容旧版线性数组模式
    const node = dungeon.nodes[gameState.dungeonNodeIndex];
    if (!node) {
      this._completeDungeon(false, 'linear_node_exhausted');
      return this.draw();
    }

    return this.getCard(node.card);
  }

  /**
   * FIX-4: 图结构秘境抽卡
   * 支持节点类型: EVENT / BATTLE / REWARD / FORK / BOSS / EXIT
   * FORK 节点返回一张路径选择卡，玩家选择后由 makeChoice 处理
   */
  _drawDungeonGraphCard(dungeon) {
    var graph = dungeon.graph;
    var nodeId = gameState.dungeonNodeId;

    // 首次进入：从 startNode 开始
    if (!nodeId) {
      nodeId = dungeon.startNode || Object.keys(graph)[0];
      gameState.dungeonNodeId = nodeId;
      gameState.dungeonPath = [nodeId];
      this._persistDungeonState();
    }

    var node = graph[nodeId];
    if (!node) {
      // 节点不存在 → 秘境异常，退出
      console.warn('[DungeonGraph] Node not found:', nodeId);
      this._completeDungeon(false, 'missing_graph_node', { nodeId });
      return this.draw();
    }

    // EXIT 节点 → 秘境结束
    if (node.type === 'EXIT' || node.type === 'exit') {
      this._completeDungeon(true, 'exit_node', { nodeId });
      return this.draw();
    }

    // FORK 节点 → 返回路径选择卡
    if (node.type === 'FORK' || node.type === 'fork') {
      return this._buildDungeonForkCard(dungeon, nodeId, node);
    }

    // 普通节点 (EVENT / BATTLE / REWARD / BOSS) → 返回对应卡牌
    if (node.card) {
      var card = this.getCard(node.card);
      if (card) {
        // 附加秘境图元信息
        card._dungeonNodeId = nodeId;
        card._dungeonNodeType = node.type;
        return card;
      }
      // 卡牌缺失 → 跳到 next
      if (node.next) {
        gameState.dungeonNodeId = node.next;
        gameState.dungeonPath.push(node.next);
        this._persistDungeonState();
        return this._drawDungeonGraphCard(dungeon);
      }
    }

    // 兜底
    console.warn('[DungeonGraph] Empty node:', nodeId);
    if (node.next) {
      gameState.dungeonNodeId = node.next;
      gameState.dungeonPath.push(node.next);
      this._persistDungeonState();
      return this._drawDungeonGraphCard(dungeon);
    }

    // 没有出口 → 结束秘境
    this._completeDungeon(false, 'dead_end_node', { nodeId });
    return this.draw();
  }

  /**
   * FIX-4: 构建秘境分叉选择卡
   */
  _buildDungeonForkCard(dungeon, forkNodeId, forkNode) {
    var choices = {};
    var paths = forkNode.paths || forkNode.choices || {};

    var directions = ['left', 'right'];
    var pathKeys = Object.keys(paths);
    var idx = 0;

    for (var i = 0; i < pathKeys.length; i++) {
      var pk = pathKeys[i];
      var path = paths[pk];
      var dir = directions[idx] || ('option' + idx);
      choices[dir] = {
        text: path.text || path.title || ('路径' + (idx + 1)),
        desc: path.desc || path.description || '',
        effects: path.effects || {},
        _dungeonForkNext: path.next || path.nodeId
      };
      if (path.card) {
        choices[dir]._dungeonForkCard = path.card;
      }
      idx++;
    }

    return {
      id: '_dungeon_fork_' + forkNodeId,
      title: forkNode.title || '岔路口',
      description: forkNode.description || '前方出现了多条路径，你需要做出选择。',
      type: 'DUNGEON_FORK',
      _dungeonNodeId: forkNodeId,
      choices: choices
    };
  }

  /**
   * 推进秘境到下一节点
   * FIX-4: 支持图结构 (跟随 next 指针) 和线性数组 (index++)
   */
  advanceDungeon() {
    const realmData = dataLoader.loadSync('cards:' + gameState.realm);
    const dungeons = realmData ? realmData.dungeons : this.dungeonCache.get(gameState.realm);
    const dungeon = dungeons ? dungeons[gameState.dungeon] : null;

    if (!dungeon) {
      this._completeDungeon(false, 'missing_dungeon');
      return;
    }

    // FIX-4: 图结构模式 — 跟随 next 指针
    if (dungeon.graph) {
      var currentNodeId = gameState.dungeonNodeId;
      if (!currentNodeId) return;

      var currentNode = dungeon.graph[currentNodeId];
      if (!currentNode) {
        this._completeDungeon(false, 'missing_graph_node', { nodeId: currentNodeId });
        return;
      }

      // EXIT 节点 → 结束
      if (currentNode.type === 'EXIT' || currentNode.type === 'exit') {
        this._completeDungeon(true, 'exit_node', { nodeId: currentNodeId });
        return;
      }

      // FORK 节点不自动推进 — 由 makeChoice 处理
      if (currentNode.type === 'FORK' || currentNode.type === 'fork') {
        return;
      }

      // 普通节点：跟随 next
      if (currentNode.next) {
        gameState.dungeonNodeId = currentNode.next;
        gameState.dungeonPath.push(currentNode.next);
        this._persistDungeonState();
      } else {
        // 没有 next → 秘境结束
        this._completeDungeon(true, 'graph_natural_end', { nodeId: currentNodeId });
      }
      return;
    }

    // 兼容旧版线性数组模式
    gameState.dungeonNodeIndex++;
    if (!dungeon || gameState.dungeonNodeIndex >= dungeon.nodes.length) {
      this._completeDungeon(true, 'linear_complete');
    } else {
      this._persistDungeonState();
    }
  }

  /**
   * FIX-4: 处理秘境分叉选择
   * 由 game.js makeChoice 在遇到 DUNGEON_FORK 卡时调用
   * @param {string} forkNodeId - FORK 节点 ID
   * @param {string} nextNodeId - 玩家选择的目标节点 ID
   */
  advanceDungeonToFork(forkNodeId, nextNodeId) {
    if (!gameState.dungeon) return false;

    const realmData = dataLoader.loadSync('cards:' + gameState.realm);
    const dungeons = realmData ? realmData.dungeons : this.dungeonCache.get(gameState.realm);
    const dungeon = dungeons ? dungeons[gameState.dungeon] : null;

    if (!dungeon || !dungeon.graph) return false;

    var targetNode = dungeon.graph[nextNodeId];
    if (!targetNode) {
      console.warn('[DungeonGraph] Fork target not found:', nextNodeId);
      this._completeDungeon(false, 'missing_fork_target', {
        fromNodeId: forkNodeId,
        nodeId: nextNodeId
      });
      return false;
    }

    gameState.dungeonNodeId = nextNodeId;
    gameState.dungeonPath.push(nextNodeId);
    this._persistDungeonState();

    // 发射分叉选择事件 (供 UI 显示路径)
    eventBus.emit('dungeon:forkChosen', {
      from: forkNodeId,
      to: nextNodeId,
      path: gameState.dungeonPath.slice()
    });
    return true;
  }

  // ============ QuestSystem 桥接 ============

  /**
   * 由 QuestSystem 调用来获取当前支线的待出卡
   */
  _getQuestCurrentCard() {
    let card = null;
    const handler = (data) => { card = data.card; };
    eventBus.once('quest:currentCard', handler);
    eventBus.emit('quest:requestCurrentCard', { gameState });
    eventBus.off('quest:currentCard', handler);
    return card;
  }

  /**
   * QuestSystem 触发新支线时会调用此方法
   */
  _getQuestEntryCard() {
    let card = null;
    const handler = (data) => { card = data.card; };
    eventBus.once('quest:entryCard', handler);
    eventBus.emit('quest:requestEntryCard', { gameState });
    eventBus.off('quest:entryCard', handler);
    return card;
  }

  _handleQuestCardRequest(data) {
    // QuestSystem 请求插入一张支线卡
    // 暂存，在 draw() 的优先级80/70中处理
    if (data && data.cardId) {
      this._pendingQuestCard = this.getCard(data.cardId);
      this._pendingQuestCardPriority = data.priority || 80;
    }
  }

  // ============ 兜底卡生成（防止 draw() 返回 null 导致 UI 崩溃） ============

  /**
   * 当 deathCardMap 为空或所有死亡卡加载失败时，生成通用死亡卡
   */
  _buildFallbackDeathCard() {
    return {
      id: 'death_fallback',
      title: '道陨',
      description: '你的修仙之路在此终结。世间万物，皆有定数。',
      type: 'DEATH',
      realm: gameState.realm,
      weight: 0,
      once: false,
      tags: ['death'],
      choices: {
        left: {
          text: '接受死亡，转世重修',
          effects: { reincarnate: true },
          desc: '前世因果未消，来生再续仙缘。'
        },
        right: {
          text: '拒绝天命，燃魂一击',
          effects: { restart: true },
          desc: '耗尽最后一缕神魂，以求一线生机。'
        }
      }
    };
  }

  /**
   * 当 _drawNormal() 卡池完全为空时，生成通用事件卡
   */
  _buildFallbackEventCard() {
    return {
      id: 'event_fallback',
      title: '潜心修炼',
      description: '你盘膝坐于山洞之中，运转周天，吐纳灵气。虽无奇遇，修行贵在坚持。',
      type: 'NORMAL',
      realm: gameState.realm,
      weight: 1,
      once: false,
      tags: ['cultivation', 'safe'],
      choices: {
        left: {
          text: '专注修炼',
          effects: { cultivation: 10 },
          desc: '稳定增长修为。'
        },
        right: {
          text: '游历散心',
          effects: { fortune: 1 },
          desc: '放松心情，或许会有意外收获。'
        }
      }
    };
  }

  // ============ 工具方法 ============

  getCardTypeName(type) {
    const names = {
      NORMAL: '事件',
      BOTTLENECK: '瓶颈',
      KARMA: '因果',
      DUNGEON: '秘境',
      DESTINY: '宿命',
      QUEST: '支线'
    };
    return names[type] || type;
  }

  getAvailableDirections(card) {
    if (!card || !card.choices) return [];
    return Object.keys(card.choices);
  }

  getLastDrawnPriority() {
    return this._lastDrawnPriority;
  }

  /**
   * 【ISSUE-05 闭环】境界过滤器：判断某张卡在当前境界下是否允许被抽取
   * 筑基期 (foundation) 及以上自动屏蔽 qi 阶的 basic 基础卡（平刺/基础盾）
   */
  isCardAllowedForRealm(card, currentRealm, sourceState = null) {
    if (!card) return false;
    const state = {
      realm: currentRealm || 'qi',
      config: sourceState?.config || (
        typeof gameState !== 'undefined' ? gameState?.config : undefined
      )
    };
    return this.getNormalDrawBucket(card, state) !== null;
  }

  /**
   * 【P1-03 规范】透明化解析选项的资源成本、全息卡牌与封顶预检
   * @param {Object} choice 选项对象
   * @param {Object} [gs] 运行时 gameState 状态
   * @returns {Object} 包含 formattedText, formattedDesc, costText, isAffordable, cardPreview, isCappedInfo
   */
  formatTransparentChoiceText(choice, preview) {
    if (!choice) return { formattedText: '', formattedDesc: '', isAffordable: true };
    const authoritative = preview && Array.isArray(preview.costs) ? preview : null;
    const costText = authoritative
      ? authoritative.costs.map(cost => (
        cost.affordable
          ? `【消耗 ${cost.required} ${cost.unit}${cost.label}】`
          : `【${cost.label}不足：需 ${cost.required}，现有 ${cost.current}】`
      )).join(' ')
      : '';
    const cardPreview = authoritative
      ? authoritative.skillCards.map(card => (
        `【获得卡牌：${card.name}（${card.type} ${card.cost === null ? '' : `${card.cost}费`} ${card.description}）】`
      )).join('\n')
      : '';
    const cappedTips = authoritative
      ? authoritative.changes
        .filter(change => change.requestedDelta > 0 && change.actualDelta === 0 && change.capped)
        .map(change => `${change.label}已达上限${change.maxValue === null ? '' : `(${change.maxValue})`}`)
      : [];
    const formattedText = `${choice.text || ''}${costText ? ` ${costText}` : ''}`;
    const details = [choice.desc || choice.description || '', cardPreview];
    if (cappedTips.length) details.push(`注：${cappedTips.join('，')}，本次实际收益为 0。`);
    return {
      formattedText,
      formattedDesc: details.filter(Boolean).join('\n'),
      costText,
      isAffordable: authoritative ? authoritative.executable : true,
      cardPreview,
      cappedTips
    };
  }
}

// 全局单例
const cardSystem = new CardSystem();

if (typeof module !== 'undefined' && module.exports) {
  module.exports = CardSystem;
} else if (typeof window !== 'undefined') {
  window.CardSystem = CardSystem;
  window.cardSystem = cardSystem;
}
