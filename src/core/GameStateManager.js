/**
 * GameStateManager - 全局游戏状态管理器
 *
 * 单一数据源，所有系统通过 EventBus 或直接读取来访问状态。
 * 每个字段只有一个 Owner 系统（可写），其他系统只读。
 *
 * 数据主权：
 *   attributes (cultivation等) → GameStateManager (读写)
 *   flags                    → GameStateManager (读写), QuestSystem (写)
 *   resources (lifespan等)   → GameStateManager (读写)
 *   realm, path, turn        → GameStateManager (读写)
 *   unlocks                  → GameStateManager (读写), localStorage
 */
class GameStateManager {
  static REALM_ORDER = ['qi', 'foundation', 'golden', 'nascent', 'deity', 'tribulation'];
  constructor() {
    this.config = {
      realms: null,
      paths: null
    };
    this.playerName = '\u53f6\u51cc\u4e91'; // 默认道号，可被玩家修改
    this.reset(false);
    this.unlocks = this._loadUnlocks();
  }

  /**
   * 从配置初始化（境界/功法数据）
   */
  init(config) {
    if (config.realms) this.config.realms = config.realms;
    if (config.paths) this.config.paths = config.paths;
  }

  /**
   * 重置状态
   * @param {boolean} keepUnlocks - 是否保留解锁记录（转世时为 true）
   */
  reset(keepUnlocks = true) {
    const savedUnlocks = keepUnlocks ? (this.unlocks || this._loadUnlocks()) : {
      paths: ['sword', 'spell', 'body', 'pill'],
      realms: ['qi'],
      cards: [],
      endings: [],
      flags: {},
      bonuses: { startCultivation: 0, startSpiritStone: 0, maxLifespan: 0 }
    };

    // 【P1 #10 修复】跨世因果种子保留——bloodline/fate 类型不清空
    const preservedSeeds = [];
    if (keepUnlocks && this.karmaSeeds) {
      for (const seed of this.karmaSeeds) {
        if (seed && (seed.seedType === 'bloodline' || seed.seedType === 'fate')) {
          // 施加延迟倍率，前世种子在新一世延迟更久才发芽
          const adjustedSeed = Object.assign({}, seed);
          adjustedSeed.delay = Math.round((seed.delay || 5) * 1.5) + 5;
          preservedSeeds.push(adjustedSeed);
        }
      }
    }

    // 核心属性 (微数值模型)
    this.maxHealth = 3 + (savedUnlocks.bonuses.maxHp || 0);
    this.maxDaoHeart = 3 + (savedUnlocks.bonuses.daoHeart || 0);

    this.attributes = {
      cultivation: 0 + (savedUnlocks.bonuses.startCultivation || 0),
      daoHeart: this.maxDaoHeart,
      karmaGood: 0 + (savedUnlocks.bonuses.karmaGood || 0),
      karmaBad: 0 + (savedUnlocks.bonuses.karmaBad || 0),
      fortune: 50 + (savedUnlocks.bonuses.fortune || 0),
      health: this.maxHealth,
      tianji: 0 // 天机暴露值
    };

    // 资源
    this.resources = {
      spiritStone: 10 + (savedUnlocks.bonuses.startSpiritStone || 0), // 压缩灵石数值
      lifespan: 80 + (savedUnlocks.bonuses.maxLifespan || 0),
      pills: {},
      treasures: [],
      companions: []
    };

    // ... (rest remains the same)
    this.equipment = {
      weapon: null,
      armor: null,
      accessory: null,
      artifact: null
    };
    this.treasureInventory = [];
    this.treasureCooldowns = {};

    this.realm = 'qi';
    this.path = null;
    this.turn = 0;
    this.cardsPlayed = [];
    this.dead = false;
    this.deadReason = '';
    this.karmaSeeds = preservedSeeds;  // 【P1 #10 修复】替代原 this.karmaSeeds = []
    this.dungeon = null;
    this.dungeonNodeIndex = 0;
    this.dungeonNodeId = null;
    this.dungeonPath = [];

    this.currentLocation = '宗门';
    this.visitedLocations = ['宗门'];
    this.locationStates = {};

    this.choiceEchoes = [];
    this.choiceHistory = [];
    this.recentCardTags = [];
    this.flags = savedUnlocks.flags || {};
    this.unlocks = savedUnlocks;

    eventBus.emit('state:reset', {});
  }

  // === 属性操作 ===

  getAttribute(name) {
    return this.attributes[name] || 0;
  }

  setAttribute(name, value) {
    const oldValue = this.attributes[name] || 0;
    let maxVal = 100;
    if (name === 'health') maxVal = this.maxHealth;
    if (name === 'daoHeart') maxVal = this.maxDaoHeart;
    if (name === 'cultivation') {
      const realmConfig = this.config.realms?.realms?.[this.realm];
      maxVal = realmConfig?.cultivationThreshold || 100;
    }
    
    this.attributes[name] = Math.max(0, Math.min(maxVal, value));
    if (oldValue !== this.attributes[name]) {
      eventBus.emit('state:attributeChanged', {
        attribute: name,
        oldValue,
        newValue: this.attributes[name]
      });
    }
  }

  addAttribute(name, delta) {
    this.setAttribute(name, this.getAttribute(name) + delta);
  }

  getKarma() {
    return this.attributes.karmaGood - this.attributes.karmaBad;
  }

  // === 资源操作 ===

  addResource(type, key, delta) {
    if (type === 'pills') {
      this.resources.pills[key] = (this.resources.pills[key] || 0) + delta;
    } else if (type === 'treasures') {
      if (!this.resources.treasures.includes(key)) {
        this.resources.treasures.push(key);
        eventBus.emit('state:treasureGained', { treasure: key });
      }
    } else if (type === 'companions') {
      if (!this.resources.companions.includes(key)) {
        this.resources.companions.push(key);
        eventBus.emit('state:companionGained', { companion: key });
      }
    } else if (type === 'spiritStone') {
      this.resources.spiritStone = Math.max(0, this.resources.spiritStone + delta);
    } else if (type === 'lifespan') {
      this.resources.lifespan = Math.max(0, this.resources.lifespan + delta);
    }
  }

  hasResource(type, key) {
    if (type === 'pill') return (this.resources.pills[key] || 0) > 0;
    if (type === 'treasure') return this.resources.treasures.includes(key);
    if (type === 'companion') return this.resources.companions.includes(key);
    return false;
  }

  consumeResource(type, key) {
    if (type === 'pill' && this.resources.pills[key]) {
      this.resources.pills[key]--;
      if (this.resources.pills[key] <= 0) delete this.resources.pills[key];
      return true;
    }
    return false;
  }

  // === Flags 系统（跨轮次持久化的游戏标记） ===

  /**
   * 设置 flag
   * @param {string} key
   * @param {*} value
   */
  setFlag(key, value) {
    const oldValue = this.flags[key];
    this.flags[key] = value;
    if (oldValue !== value) {
      eventBus.emit('state:flagChanged', { key, oldValue, newValue: value });
    }
  }

  /**
   * 获取 flag
   * @param {string} key
   * @param {*} defaultValue
   * @returns {*}
   */
  getFlag(key, defaultValue) {
    return this.flags.hasOwnProperty(key) ? this.flags[key] : defaultValue;
  }

  /**
   * 检查 flag 是否存在且为真
   * @param {string} key
   * @returns {boolean}
   */
  hasFlag(key) {
    return this.flags.hasOwnProperty(key);
  }

  /**
   * 批量检查多个 flag
   * @param {Object} required - { key: expectedValue }，值为 null 表示只检查存在
   * @returns {boolean}
   */
  checkFlags(required) {
    if (!required) return true;
    for (const [key, value] of Object.entries(required)) {
      if (value === null) {
        if (!this.hasFlag(key)) return false;
      } else {
        if (this.getFlag(key) !== value) return false;
      }
    }
    return true;
  }

  // === 死亡检测（升级：增加复活法宝拦截） ===

  checkDeath() {
    if (this.dead) return true;

    const checks = [
      { name: 'daoHeart', min: 0, reason: '道心崩碎，走火入魔' },
      { name: 'health', min: 0, reason: '气血耗尽，身死道消' }
    ];

    let deathReason = null;
    for (const c of checks) {
      if (this.attributes[c.name] <= 0) {
        deathReason = c.reason;
        break;
      }
    }

    if (!deathReason && this.resources.lifespan <= 0) {
      deathReason = '寿元耗尽，坐化而终';
    }

    if (deathReason) {
      // 【诊断日志】触发死亡判定
      console.log(`[checkDeath] 触发死亡 reason=${deathReason} hp=${this.attributes.health} daoHeart=${this.attributes.daoHeart} lifespan=${this.resources.lifespan}`);

      // === 复活法宝拦截 (P0) ===
      const revived = this._tryReviveByArtifact(deathReason);
      if (revived) {
        console.log(`[checkDeath] 复活成功，deathReason=${deathReason} 已拦截`);
        return false; // 复活成功，不死亡
      }

      this.dead = true;
      this.deadReason = deathReason;
      console.log(`[checkDeath] 死亡确认 dead=true reason=${deathReason}，emit state:death`);
      eventBus.emit('state:death', { reason: deathReason });
      return true;
    }

    return false;
  }

  /**
   * 尝试使用装备中的复活法宝
   * @param {string} reason - 死亡原因
   * @returns {boolean} 是否复活成功
   */
  _tryReviveByArtifact(deathReason) {
    const artifactId = this.equipment.artifact;
    if (!artifactId) {
      console.log(`[revive] 无装备法宝，跳过复活判定`);
      return false;
    }

    console.log(`[revive] 检查法宝 artifactId=${artifactId} 是否可复活 reason=${deathReason}`);

    // 检查秘宝槽中的法宝是否有复活效果
    if (typeof treasureSystem !== 'undefined' && treasureSystem) {
      const treasure = treasureSystem.getTreasureData(artifactId);
      if (treasure && treasure.revive) {
        console.log(`[revive] 法宝 ${treasure.name} 有复活效果 type=${treasure.revive.type}，执行复活`);
        // 执行复活逻辑
        const result = treasureSystem.executeRevive(artifactId, this, deathReason);
        if (result.success) {
          console.log(`[revive] 复活成功 effect=${result.effect} hpAfter=${this.attributes.health}`);
          eventBus.emit('treasure:revive', {
            treasureId: artifactId,
            treasureName: treasure.name,
            effect: result.effect
          });
          return true;
        } else {
          console.log(`[revive] ⚠️ 复活失败 result.success=false`);
        }
      } else {
        console.log(`[revive] 法宝 ${artifactId} 无 revive 字段或数据不存在`);
      }
    } else {
      console.log(`[revive] treasureSystem 未加载，跳过复活判定`);
    }
    return false;
  }

  // === 境界突破检测 ===

  checkBreakthrough() {
    const realmOrder = this.config.realms ? this.config.realms.order : ['qi', 'foundation', 'golden', 'nascent', 'deity', 'tribulation'];
    const realmConfig = this.config.realms ? this.config.realms.realms[this.realm] : null;

    if (!realmConfig) return null;

    if (this.attributes.cultivation >= realmConfig.cultivationThreshold) {
      return realmConfig.breakthroughCard;
    }
    return null;
  }

  // === 解锁系统 ===

  unlock(key, value) {
    if (key === 'card' && !this.unlocks.cards.includes(value)) {
      this.unlocks.cards.push(value);
    }
    if (key === 'ending' && !this.unlocks.endings.includes(value)) {
      this.unlocks.endings.push(value);
    }
    if (key === 'realm' && !this.unlocks.realms.includes(value)) {
      this.unlocks.realms.push(value);
    }
    this._saveUnlocks();
  }

  // === 获取名字 ===

  getPathName(path) {
    if (!path) return '未选';
    if (this.config.paths && this.config.paths.paths[path]) {
      return this.config.paths.paths[path].name;
    }
    const names = {
      sword: '剑修', spell: '法修', body: '体修', pill: '丹修',
      array: '阵修', talisman: '符修'
    };
    return names[path] || path;
  }

  getRealmName(realm) {
    const r = realm || this.realm;
    if (this.config.realms && this.config.realms.realms[r]) {
      return this.config.realms.realms[r].name;
    }
    const names = {
      qi: '炼气期', foundation: '筑基期', golden: '金丹期',
      nascent: '元婴期', deity: '化神期', tribulation: '渡劫期'
    };
    return names[r] || r;
  }

  // === 转世系统 ===

  /**
   * 获取当前转世次数（第几世）
   */
  getLifeCount() {
    return this.unlocks.lifeCount || 0;
  }

  /**
   * 转世次数+1
   */
  incrementLife() {
    this.unlocks.lifeCount = (this.unlocks.lifeCount || 0) + 1;
  }

  /**
   * 在转世前记录跨世遗产，保存到 unlocks.legacy 中
   * 在 reset() 之前调用，将当前世的记忆存入持久化。
   */
  recordLegacy() {
    const legacy = this.unlocks.legacy;

    // 记录 NPC 好感
    if (typeof npcSystem !== 'undefined' && npcSystem && npcSystem.affections) {
      const affections = npcSystem.affections;
      for (const [npcId, affection] of Object.entries(affections)) {
        const prev = legacy.npcAffections[npcId] || 0;
        // 好感跨世衰减 50%，但不低于 0
        const decayed = affection * 0.5;
        legacy.npcAffections[npcId] = Math.max(prev, decayed);
      }
    }

    // 记录势力声望
    if (typeof factionSystem !== 'undefined' && factionSystem) {
      for (const [factionId, rep] of Object.entries(factionSystem.reputations || {})) {
        const prev = legacy.factionReputations[factionId] || 0;
        // 声望跨世衰减 40%，保留大局印象
        const decayed = Math.round(rep * 0.6);
        // 正向声望取 max（保留好印象的峰值），负向声望取 min（保留坏印象的谷值）
        if (decayed >= 0) {
          legacy.factionReputations[factionId] = Math.max(prev, decayed);
        } else {
          legacy.factionReputations[factionId] = Math.min(prev, decayed);
        }
      }
    }

    // 记录完成的支线（不衰减，永久标记）
    if (this.flags) {
      for (const [key, value] of Object.entries(this.flags)) {
        if (key.endsWith('Completed') && value && !legacy.completedQuests.includes(key)) {
          legacy.completedQuests.push(key);
        }
      }
    }

    // 记录当前功法的熟练度
    if (this.path) {
      const prev = legacy.pathMemories[this.path] || 0;
      const newMastery = prev + 1;
      legacy.pathMemories[this.path] = Math.min(newMastery, 5); // 最高5级熟练度
    }
  }

  /**
   * 获取跨世 NPC 好感遗产
   * @param {string} npcId
   * @returns {number} 前世累积的衰减后好感
   */
  getLegacyAffection(npcId) {
    return this.unlocks.legacy?.npcAffections?.[npcId] || 0;
  }

  /**
   * 获取跨世势力声望遗产
   * @param {string} factionId
   * @returns {number}
   */
  getLegacyReputation(factionId) {
    return this.unlocks.legacy?.factionReputations?.[factionId] || 0;
  }

  /**
   * 获取跨世功法熟练度
   * @returns {number} 0-5
   */
  getPathMastery() {
    if (!this.path) return 0;
    return this.unlocks.legacy?.pathMemories?.[this.path] || 0;
  }

  // === 持久化 ===

  _saveUnlocks() {
    try {
      localStorage.setItem('xiuxian_unlocks', JSON.stringify(this.unlocks));
    } catch (e) {
      // localStorage 不可用时静默失败
    }
  }

  _loadUnlocks() {
    try {
      const saved = localStorage.getItem('xiuxian_unlocks');
      if (saved) {
        const parsed = JSON.parse(saved);
        // 确保新字段存在（向前兼容旧存档）
        if (!parsed.flags) parsed.flags = {};
        if (typeof parsed.lifeCount !== 'number') parsed.lifeCount = 0;
        if (!parsed.bonuses) parsed.bonuses = { startCultivation: 0, startSpiritStone: 0, maxLifespan: 0, daoHeart: 0, fortune: 0, maxHp: 0, karmaGood: 0, karmaBad: 0 };
        if (!parsed.legacy) parsed.legacy = { npcAffections: {}, factionReputations: {}, pathMemories: {}, completedQuests: [] };
        return parsed;
      }
    } catch (e) {
      // 解析失败时使用默认值
    }
    return {
      paths: ['sword', 'spell', 'body', 'pill'],
      realms: ['qi'],
      cards: [],
      endings: [],
      flags: {},
      bonuses: { startCultivation: 0, startSpiritStone: 0, maxLifespan: 0, daoHeart: 0, fortune: 0, maxHp: 0, karmaGood: 0, karmaBad: 0 },
      lifeCount: 0,
      legacy: {
        npcAffections: {},    // { npcId: affectionDelta } 跨世 NPC 印象
        factionReputations: {}, // { factionId: delta } 跨世势力声望
        pathMemories: {},     // { pathId: masteryLevel } 跨世功法熟练度
        completedQuests: []   // 前世完成的支线 ID
      }
    };
  }
}

// 全局单例
const gameState = new GameStateManager();
