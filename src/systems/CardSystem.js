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
    if (gameState.dead) {
      this._lastDrawnPriority = 100;
      const deathCardId = this.deathCardMap.get(gameState.deadReason);
      if (deathCardId) {
        const card = this.getCard(deathCardId);
        if (card) return card;
      }
      // 兜底：返回第一张死亡卡
      for (const [reason, cardId] of this.deathCardMap) {
        const card = this.getCard(cardId);
        if (card) return card;
      }
      // 终极兜底：deathCardMap 为空或所有卡加载失败 → 生成通用死亡卡，防止 UI 崩溃
      return this._buildFallbackDeathCard();
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
    if (typeof shopSystem === 'undefined' || !shopSystem) return null;

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
      title: '坊市偶遇',
      description: '前方出现一处修士集市，散修摆摊叫卖。空气中弥漫着丹药和灵草的气味。',
      type: 'SHOP',
      realm: realm,
      weight: 0,
      once: false,
      choices: {
        left: {
          text: '不买，继续赶路',
          effects: {},
          desc: '专心修行，不被俗物分心。'
        },
        right: {
          text: '看看有什么好货',
          effects: {},
          openShop: true,
          desc: `进入集市，看看商品。（你有 ${gameState.resources.spiritStone} 灵石）`
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
    const turn = gameState.turn;
    if (turn % 15 !== 0) return null;
    if (Math.random() >= 0.3) return null;
    
    // 获取缓存中的 camp_meditation
    const campData = dataLoader.loadSync('cards:camp');
    if (campData && campData.camp_meditation) {
      return campData.camp_meditation;
    }
    return null;
  }

  // ============ 卡牌查找 ============

  /**
   * 通过ID获取卡牌
   * @param {string} id
   * @returns {Object|null}
   */
  getCard(id) {
    if (!id) return null;
    if (this.cardCache.has(id)) return this.cardCache.get(id);

    // 先尝试已加载的境界
    for (const card of this.cardCache.values()) {
      if (card.id === id) return card;
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
            this.cardCache.set(id, card);
            return card;
          }
        }
      }
      // 检查秘境卡
      if (data.dungeonCards && data.dungeonCards[id]) {
        this.cardCache.set(id, data.dungeonCards[id]);
        return data.dungeonCards[id];
      }
    }

    // 检查死亡卡
    const deathData = dataLoader.loadSync('cards:death');
    if (deathData && deathData.deathCards && deathData.deathCards[id]) {
      this.cardCache.set(id, deathData.deathCards[id]);
      return deathData.deathCards[id];
    }

    // 检查因果卡
    const karmaData = dataLoader.loadSync('cards:karma');
    if (karmaData && karmaData.cards) {
      for (const card of karmaData.cards) {
        if (card.id === id) {
          this.cardCache.set(id, card);
          return card;
        }
      }
    }

    return null;
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

  // ============ 内部方法 ============

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
    if (data.karmaCards) {
      for (const [karmaId, cardId] of Object.entries(data.karmaCards)) {
        this.karmaCardMap.set(karmaId, cardId);
      }
    }

    this._loadedRealms.add(realm);
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
    if (data.karmaCards) {
      for (const [karmaId, cardId] of Object.entries(data.karmaCards)) {
        this.karmaCardMap.set(karmaId, cardId);
      }
    }

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
    if (data.karmaCards) {
      for (const [karmaId, cardId] of Object.entries(data.karmaCards)) {
        this.karmaCardMap.set(karmaId, cardId);
      }
    }
  }

  _drawNormal() {
    // 确保当前境界卡池已加载
    this._loadRealmCards(gameState.realm);

    const candidates = [];
    const pool = this.getCardPool(gameState.realm);
    // 最近 N 张玩过的卡会进入"冷却"，避免连续抽到同一张
    const recentPlayed = new Set(gameState.cardsPlayed.slice(-8));

    // 合并境界卡池中的卡 + 额外模块中的卡（如魔道女修事件）
    const poolIds = new Set(pool.map(c => c.id));
    const extraCards = [];
    for (const [id, card] of this.cardCache) {
      if (!poolIds.has(id) && card.realm && card.type !== 'DESTINY' && card.type !== 'BOTTLENECK') {
        extraCards.push(card);
      }
    }

    const allPool = [...pool, ...extraCards];

    for (const card of allPool) {
      // 跳过特殊类型
      if (['DESTINY', 'BOTTLENECK', 'KARMA', 'QUEST'].includes(card.type)) continue;
      // 境界过滤
      if (card.realm && card.realm !== gameState.realm) continue;
      // 功法过滤
      if (card.path && card.path !== gameState.path) continue;
      // 一次性过滤
      if (card.once && gameState.cardsPlayed.includes(card.id)) continue;
      // 最近 8 张冷却（对非 once 卡生效，防止连续重复）
      if (recentPlayed.has(card.id)) continue;
      // Flags 条件过滤
      if (card.requiresFlags && !gameState.checkFlags(card.requiresFlags)) continue;
      if (card.forbiddenFlags) {
        let blocked = false;
        for (const [key, val] of Object.entries(card.forbiddenFlags)) {
          if (val === null ? gameState.hasFlag(key) : gameState.getFlag(key) === val) {
            blocked = true;
            break;
          }
        }
        if (blocked) continue;
      }

      let weight = card.weight !== undefined ? card.weight : 5;

      // 功法亲和加成
      if (card.path === gameState.path) weight *= 1.5;

      // 福缘影响好事件
      if (gameState.attributes.fortune > 70 && card.tags && !card.tags.includes('risk')) {
        weight += 2;
      }

      // 恶因影响魔道事件
      if (gameState.attributes.karmaBad > 50 && card.tags && card.tags.includes('demon')) {
        weight *= 1.3;
      }

      for (let i = 0; i < Math.max(1, Math.round(weight)); i++) {
        candidates.push(card);
      }
    }

    if (candidates.length === 0) {
      const fallback = this.getCard('q_meditation');
      if (fallback) return fallback;
      // 连冥想卡都找不到 — 生成通用事件卡作为最后兜底
      return this._buildFallbackEventCard();
    }
    return candidates[Math.floor(Math.random() * candidates.length)];
  }

  _drawKarmaCard() {
    const seeds = gameState.karmaSeeds;
    if (seeds.length === 0) return null;

    const ready = seeds.filter(s =>
      (s.delay === undefined || s.delay <= 0) && (!s.realm || s.realm === gameState.realm)
    );

    if (ready.length === 0) return null;

    // 按优先级取最高
    ready.sort((a, b) => b.priority - a.priority);
    const seed = ready[0];

    // 移除种子
    gameState.karmaSeeds = seeds.filter(s => s !== seed);

    // 查找因果卡
    const cardId = this.karmaCardMap.get(seed.id);
    if (cardId) {
      eventBus.emit('karma:seedGerminated', { seedId: seed.id, cardId });
      return this.getCard(cardId);
    }

    return null;
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
    const path = gameState.path;
    const candidates = [];

    for (const card of allCards) {
      if (!card.requirements) continue;
      if (!card.requirements.minLifeCount) continue;
      if (lifeCount < card.requirements.minLifeCount) continue;

      // differentPaths: 需要换了功法
      if (card.requirements.differentPaths) {
        const legacy = gameState.unlocks?.legacy?.pathMemories || {};
        const otherPaths = Object.keys(legacy).filter(p => p !== path && legacy[p] > 0);
        if (otherPaths.length === 0) continue;
      }

      // 境界过滤
      if (card.realm) {
        const realms = card.realm.split(',');
        if (!realms.includes(realm)) continue;
      }

      // 冷却
      if (card.once && gameState.cardsPlayed.includes(card.id)) continue;

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
  _checkRequirements(card) {
    if (!card.requirements) return true;
    const req = card.requirements;

    if (req.minLifeCount !== undefined) {
      const lifeCount = gameState.getLifeCount ? gameState.getLifeCount() : 0;
      if (lifeCount < req.minLifeCount) return false;
    }

    if (req.differentPaths) {
      const path = gameState.path;
      const legacy = gameState.unlocks?.legacy?.pathMemories || {};
      const otherPaths = Object.keys(legacy).filter(p => p !== path && legacy[p] > 0);
      if (otherPaths.length === 0) return false;
    }

    return true;
  }

  // ============ CompanionSystem 桥接（优先级50） ============

  _getCompanionEventCard() {
    let card = null;
    const handler = (data) => { card = data.card; };
    eventBus.once('companion:eventCard', handler);
    eventBus.emit('companion:checkEvent', { gameState });
    eventBus.off('companion:eventCard', handler);
    return card;
  }

  // ============ FactionSystem 桥接（优先级40） ============

  _getFactionEventCard() {
    let card = null;
    const handler = (data) => { card = data.card; };
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
      if (data.priority === expectedPriority && data.card) {
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
    const handler = (data) => { card = data.card; };
    eventBus.once('npc:encounterCard', handler);
    eventBus.emit('npc:getEncounterCard', { gameState });
    eventBus.off('npc:encounterCard', handler);
    return card;
  }

  _drawDungeonCard() {
    const realmData = dataLoader.loadSync('cards:' + gameState.realm);
    const dungeons = realmData ? realmData.dungeons : this.dungeonCache.get(gameState.realm);
    const dungeon = dungeons ? dungeons[gameState.dungeon] : null;

    if (!dungeon) {
      gameState.dungeon = null;
      gameState.dungeonNodeIndex = 0;
      gameState.dungeonNodeId = null;
      gameState.dungeonPath = [];
      return this.draw();
    }

    // FIX-4: 图结构模式 — 通过节点 ID 查找
    if (dungeon.graph) {
      return this._drawDungeonGraphCard(dungeon);
    }

    // 兼容旧版线性数组模式
    const node = dungeon.nodes[gameState.dungeonNodeIndex];
    if (!node) {
      gameState.dungeon = null;
      gameState.dungeonNodeIndex = 0;
      eventBus.emit('dungeon:completed', {});
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
    }

    var node = graph[nodeId];
    if (!node) {
      // 节点不存在 → 秘境异常，退出
      console.warn('[DungeonGraph] Node not found:', nodeId);
      gameState.dungeon = null;
      gameState.dungeonNodeId = null;
      gameState.dungeonPath = [];
      eventBus.emit('dungeon:completed', {});
      return this.draw();
    }

    // EXIT 节点 → 秘境结束
    if (node.type === 'EXIT' || node.type === 'exit') {
      gameState.dungeon = null;
      gameState.dungeonNodeId = null;
      gameState.dungeonPath = [];
      eventBus.emit('dungeon:completed', {});
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
        return this._drawDungeonGraphCard(dungeon);
      }
    }

    // 兜底
    console.warn('[DungeonGraph] Empty node:', nodeId);
    if (node.next) {
      gameState.dungeonNodeId = node.next;
      gameState.dungeonPath.push(node.next);
      return this._drawDungeonGraphCard(dungeon);
    }

    // 没有出口 → 结束秘境
    gameState.dungeon = null;
    gameState.dungeonNodeId = null;
    gameState.dungeonPath = [];
    eventBus.emit('dungeon:completed', {});
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
      gameState.dungeon = null;
      gameState.dungeonNodeIndex = 0;
      gameState.dungeonNodeId = null;
      gameState.dungeonPath = [];
      return;
    }

    // FIX-4: 图结构模式 — 跟随 next 指针
    if (dungeon.graph) {
      var currentNodeId = gameState.dungeonNodeId;
      if (!currentNodeId) return;

      var currentNode = dungeon.graph[currentNodeId];
      if (!currentNode) {
        gameState.dungeon = null;
        gameState.dungeonNodeId = null;
        gameState.dungeonPath = [];
        return;
      }

      // EXIT 节点 → 结束
      if (currentNode.type === 'EXIT' || currentNode.type === 'exit') {
        gameState.dungeon = null;
        gameState.dungeonNodeId = null;
        gameState.dungeonPath = [];
        eventBus.emit('dungeon:completed', {});
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
      } else {
        // 没有 next → 秘境结束
        gameState.dungeon = null;
        gameState.dungeonNodeId = null;
        gameState.dungeonPath = [];
        eventBus.emit('dungeon:completed', {});
      }
      return;
    }

    // 兼容旧版线性数组模式
    gameState.dungeonNodeIndex++;
    if (!dungeon || gameState.dungeonNodeIndex >= dungeon.nodes.length) {
      gameState.dungeon = null;
      gameState.dungeonNodeIndex = 0;
    }
  }

  /**
   * FIX-4: 处理秘境分叉选择
   * 由 game.js makeChoice 在遇到 DUNGEON_FORK 卡时调用
   * @param {string} forkNodeId - FORK 节点 ID
   * @param {string} nextNodeId - 玩家选择的目标节点 ID
   */
  advanceDungeonToFork(forkNodeId, nextNodeId) {
    if (!gameState.dungeon) return;

    const realmData = dataLoader.loadSync('cards:' + gameState.realm);
    const dungeons = realmData ? realmData.dungeons : this.dungeonCache.get(gameState.realm);
    const dungeon = dungeons ? dungeons[gameState.dungeon] : null;

    if (!dungeon || !dungeon.graph) return;

    var targetNode = dungeon.graph[nextNodeId];
    if (!targetNode) {
      console.warn('[DungeonGraph] Fork target not found:', nextNodeId);
      return;
    }

    gameState.dungeonNodeId = nextNodeId;
    gameState.dungeonPath.push(nextNodeId);

    // 发射分叉选择事件 (供 UI 显示路径)
    eventBus.emit('dungeon:forkChosen', {
      from: forkNodeId,
      to: nextNodeId,
      path: gameState.dungeonPath.slice()
    });
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
}

// 全局单例
const cardSystem = new CardSystem();
