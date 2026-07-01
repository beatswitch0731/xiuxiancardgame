/**
 * MarketSystem — 集市刷新系统
 *
 * 福源影响集市商品品质和数量。
 * 集市是偶遇机制，每12-18回合触发一次"鬼市偶遇"卡。
 * 核心公式: 金质法宝概率 = max(3%, 5% + (fortune - 40) × 0.3%)
 *
 * 与 ShopSystem 协作：
 *  - MarketSystem 负责"集市何时开、刷出什么货"
 *  - ShopSystem 负责"购买/替换/消费灵石"
 */
class MarketSystem {
  constructor() {
    this._initialized = false;
    this._lastMarketTurn = -99;
    this._nextMarketTurn = 12 + Math.floor(Math.random() * 7); // 12-18
    this._totalVisits = 0;
    this._currentItems = [];   // 当前集市刷出的商品快照
    this._priceMultiplier = 1.0;
    this._slotCount = 5;
    this.onLog = null;

    // 稀有度权重表（按福源区间）
    this._fortuneTiers = [
      { min: 0,  max: 20, slots: 3, weights: [0.70, 0.17, 0.10, 0.03, 0.00], priceMult: 1.5 },
      { min: 21, max: 40, slots: 4, weights: [0.50, 0.30, 0.15, 0.05, 0.00], priceMult: 1.2 },
      { min: 41, max: 60, slots: 5, weights: [0.35, 0.35, 0.20, 0.10, 0.00], priceMult: 1.0 },
      { min: 61, max: 80, slots: 6, weights: [0.25, 0.30, 0.25, 0.20, 0.00], priceMult: 0.9 },
      { min: 81, max: 100,slots: 7, weights: [0.15, 0.30, 0.30, 0.25, 0.00], priceMult: 0.8 },
    ];

    // 价格范围（按稀有度 1-6）
    this._priceRanges = {
      1: { min: 10, max: 15 },   // ☆ 灰
      2: { min: 20, max: 30 },   // ★★ 白
      3: { min: 40, max: 70 },   // ★★★ 蓝
      4: { min: 80, max: 150 },  // ★★★★ 紫
      5: { min: 150, max: 300 }, // ★★★★★ 金
      6: { min: 300, max: 500 }, // ★★★★★★ 传说
    };
  }

  /**
   * 初始化 — 从 treasureSystem 加载法宝池
   */
  init() {
    if (this._initialized) return;
    if (typeof treasureSystem === 'undefined' || !treasureSystem) {
      this._log('[MarketSystem] treasureSystem 未就绪，集市暂不可用');
      this._initialized = true;
      return;
    }
    this._log('[MarketSystem] 集市已开张。下一轮鬼市约在' + this._nextMarketTurn + '回合后出现。');
    this._initialized = true;
  }

  // ============ 触发检测 ============

  /**
   * 每回合调用，检测是否触发集市偶遇
   * @param {number} turn - 当前回合
   * @returns {Object|null} 集市卡 或 null（不触发）
   */
  tick(turn) {
    if (!this._initialized) return null;

    // 战斗/命盘中不触发
    if (typeof gameState !== 'undefined' && gameState._inCombat) return null;

    if (turn < this._nextMarketTurn) return null;

    // 更新下次触发时间
    this._lastMarketTurn = turn;
    const interval = 12 + Math.floor(Math.random() * 7); // 12-18 回合
    this._nextMarketTurn = turn + interval;

    // 预刷商品
    const fortune = gameState.attributes.fortune;
    this._currentItems = this._generateItems(fortune);

    return this._buildMarketCard();
  }

  /**
   * 获取当前刷出的商品（供 ShopSystem/UI 使用）
   */
  getCurrentMarketItems() {
    return this._currentItems;
  }

  getPriceMultiplier() {
    return this._priceMultiplier;
  }

  getSlotCount() {
    return this._slotCount;
  }

  getFortuneTierText() {
    const f = gameState.attributes.fortune;
    if (f <= 20) return '厄运缠身';
    if (f <= 40) return '时运平平';
    if (f <= 60) return '福运小成';
    if (f <= 80) return '天运亨通';
    return '天命所归';
  }

  // ============ 商品生成 ============

  /**
   * 根据福源生成集市商品列表
   * @param {number} fortune - 当前福源值
   * @returns {Array} 商品列表
   */
  _generateItems(fortune) {
    // 查找福源区间
    let tier = this._fortuneTiers[2]; // 默认 41-60
    for (const t of this._fortuneTiers) {
      if (fortune >= t.min && fortune <= t.max) { tier = t; break; }
    }
    if (fortune > 100) tier = this._fortuneTiers[4];

    this._slotCount = tier.slots;
    this._priceMultiplier = tier.priceMult;

    // 从法宝池筛选可用法宝
    const pool = this._buildTreasurePool();
    if (pool.length === 0) return [];

    const items = [];
    const usedIds = new Set();
    let goldCount = 0;
    const maxGold = 2; // 金质最多2件

    for (let i = 0; i < this._slotCount && pool.length > 0; i++) {
      // 按权重决定稀有度
      let rarity = this._rollRarity(tier.weights);
      if (rarity >= 5 && goldCount >= maxGold) rarity = 4; // 金质已达上限，降级

      // 从池中筛选匹配稀有度的法宝
      const candidates = pool.filter(t => t.rarity === rarity && !usedIds.has(t.id));
      if (candidates.length === 0) {
        // 降级查找
        for (let r = rarity - 1; r >= 1; r--) {
          const fallbacks = pool.filter(t => t.rarity === r && !usedIds.has(t.id));
          if (fallbacks.length > 0) {
            const pick = fallbacks[Math.floor(Math.random() * fallbacks.length)];
            items.push(this._buildMarketItem(pick));
            usedIds.add(pick.id);
            break;
          }
        }
      } else {
        const pick = candidates[Math.floor(Math.random() * candidates.length)];
        items.push(this._buildMarketItem(pick));
        usedIds.add(pick.id);
        if (rarity >= 5) goldCount++;
      }
    }

    // 按稀有度降序排列
    items.sort((a, b) => b.rarity - a.rarity);
    return items;
  }

  /**
   * 构建可用的法宝池：
   * - 已拥有的法宝不出现在集市
   * - 高于当前境界的法宝不出
   */
  _buildTreasurePool() {
    const allTreasures = Object.values(treasureSystem.treasureDB);
    if (!allTreasures.length) return [];

    const ownedIds = new Set(treasureSystem.owned || []);
    const realm = gameState.realm;
    const realmOrder = ['qi', 'foundation', 'golden', 'nascent', 'formation', 'void', 'tribulation'];
    const maxRealmIdx = realmOrder.indexOf(realm);

    return allTreasures.filter(t => {
      if (ownedIds.has(t.id)) return false;
      const itemIdx = realmOrder.indexOf(t.realm);
      if (itemIdx < 0) return false;
      return itemIdx <= maxRealmIdx;
    });
  }

  /**
   * 按权重掷骰决定稀有度
   * @param {number[]} weights - [白, 蓝, 紫, 金, 传说] 权重
   * @returns {number} 稀有度 2-6
   */
  _rollRarity(weights) {
    const roll = Math.random();
    let cum = 0;
    // 下标0=白(2),1=蓝(3),2=紫(4),3=金(5),4=传说(6)
    for (let i = 0; i < weights.length; i++) {
      cum += weights[i];
      if (roll < cum) return i + 2;
    }
    return 2; // fallback 白
  }

  /**
   * 将treasure DB条目转为集市商品
   * 应用价格倍率
   */
  _buildMarketItem(treasure) {
    const baseRange = this._priceRanges[treasure.rarity] || this._priceRanges[2];
    const base = baseRange.min + Math.floor(Math.random() * (baseRange.max - baseRange.min));
    const finalPrice = Math.floor(base * this._priceMultiplier);

    // 稀有度名称
    const rarityNames = { 1:'☆ 灰', 2:'★★ 白', 3:'★★★ 蓝', 4:'★★★★ 紫', 5:'★★★★★ 金', 6:'★★★★★★ 传说' };

    // 槽位类型标签
    const typeLabels = {
      weapon: '🗡️ 武器', armor: '🛡️ 防具',
      accessory: '📿 饰品', artifact: '🔮 秘宝',
      consumable: '📜 消耗', tool: '🔧 法器',
      material: '💎 材料', regen: '💧 回复'
    };

    return {
      ...treasure,
      displayPrice: finalPrice,
      rarityName: rarityNames[treasure.rarity] || '★★ 白',
      typeLabel: typeLabels[treasure.type] || '📦 杂物',
      _marketItem: true
    };
  }

  // ============ 集市偶遇卡 ============

  _buildMarketCard() {
    const tierText = this.getFortuneTierText();
    const fortune = gameState.attributes.fortune;
    const stone = gameState.resources.spiritStone;

    const flavorTexts = [
      '你路过一座废弃坊市时，感到一阵空间波动——这不是普通的坊市，是鬼市。',
      '雾气中浮现一扇古铜门。门楣上写着"有缘者入"——你的福源微微发热。',
      '一阵阴风吹过，路边突然出现了几个摊铺。摊主不露脸，只露手——这是鬼市的规矩。',
      '你听到铃铛声。三声为号——鬼市开了。你正好走在那个时辰、那个地点。',
    ];
    const flavor = flavorTexts[Math.floor(Math.random() * flavorTexts.length)];

    return {
      id: 'market_encounter',
      title: `🏪 鬼市偶遇 — ${tierText}`,
      description: flavor + `\n\n🕯️ 当前福源: ${fortune} | 灵石: ${stone}`,
      type: 'MARKET',
      realm: gameState.realm,
      weight: 0,
      once: false,
      choices: {
        left: {
          text: '进去逛逛',
          effects: {},
          openMarket: true,
          desc: `踏入鬼市大门。以你${tierText}的运道，可刷出 ${this._slotCount} 件商品。`
        },
        right: {
          text: '绕道而行',
          effects: {},
          desc: '鬼市虽有好货，但也可能沾上不干净的东西。还是赶路要紧。'
        }
      }
    };
  }

  // ============ 辅助 ============

  getState() {
    return {
      lastMarketTurn: this._lastMarketTurn,
      nextMarketTurn: this._nextMarketTurn,
      totalVisits: this._totalVisits,
      slotCount: this._slotCount,
      priceMultiplier: this._priceMultiplier,
      currentItemCount: this._currentItems.length,
      fortuneTier: this.getFortuneTierText()
    };
  }

  _log(msg) {
    if (this.onLog) this.onLog(msg);
  }
}

// 全局单例
const marketSystem = new MarketSystem();
