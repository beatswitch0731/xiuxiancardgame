/**
 * TreasureSystem - 法宝系统
 *
 * 管理所有法宝的被动加成和主动效果。
 * 法宝数据从 data/shops/treasures.json 加载（也内联在 DATA_MODULES 中）。
 *
 * 功能：
 *   - 被动加成：始终生效的属性修正
 *   - 主动效果：在特定卡牌出现时提供额外选项
 *   - 法宝收集和统计
 */
class TreasureSystem {
  constructor() {
    this.treasureDB = {};  // id → { name, type, passive, active, desc, revive? }
    this.owned = new Set(); // 当前拥有的法宝 ID 集合
    this.equipped = {       // 装备槽 (P0 新增)
      weapon: null,
      armor: null,
      accessory: null,
      artifact: null
    };
    this.cooldowns = {};   // { 法宝id: 剩余冷却回合 }
    this._initialized = false;
  }

  /**
   * 初始化：加载法宝数据
   */
  init() {
    if (this._initialized) return;
    const treasureData = dataLoader.loadSync('shops:treasures');
    if (treasureData) {
      this.loadData(treasureData);
    }
    this._initialized = true;

    // 监听恢复：转世重置时清空法宝
    eventBus.on('state:reset', () => {
      this.owned = new Set();
    });
  }

  /**
   * 从数据加载法宝定义
   */
  loadData(data) {
    if (!data || !data.treasures) return;
    for (const t of data.treasures) {
      this.treasureDB[t.id] = t;
    }
  }

  /**
   * 记录法宝获取
   */
  acquire(treasureId) {
    if (this.treasureDB[treasureId]) {
      this.owned.add(treasureId);
      // P0: 新增到inventory（未装备）
      if (gameState && gameState.treasureInventory) {
        if (!gameState.treasureInventory.includes(treasureId)) {
          gameState.treasureInventory.push(treasureId);
        }
      }
      eventBus.emit('treasure:acquired', { treasureId, treasure: this.treasureDB[treasureId] });
    }
  }

  /**
   * 是否拥有某法宝
   */
  has(treasureId) {
    return this.owned.has(treasureId);
  }

  /**
   * 获取聚合的被动加成
   * @returns {Object} { atk, def, hpRegen, fortuneBonus, daoResist, ... }
   */
  getPassiveBonuses() {
    const bonuses = {};
    for (const id of this.owned) {
      const t = this.treasureDB[id];
      if (!t || !t.passive) continue;
      for (const [key, val] of Object.entries(t.passive)) {
        bonuses[key] = (bonuses[key] || 0) + val;
      }
    }
    return bonuses;
  }

  /**
   * 获取当前卡牌可用的主动法宝选项
   * @param {Object} card - 当前卡牌
   * @returns {Array} 可用选项 [{ text, effects, treasureId }]
   */
  getActiveOptions(card) {
    const options = [];
    for (const id of this.owned) {
      const t = this.treasureDB[id];
      if (!t || !t.active || !t.active.trigger) continue;

      let match = false;
      const trigger = t.active.trigger;

      if (trigger.cardType && card.type === trigger.cardType) match = true;
      if (trigger.tags && card.tags) {
        match = trigger.tags.some(tag => card.tags.includes(tag));
      }
      if (trigger.cardId && card.id === trigger.cardId) match = true;

      if (match) {
        options.push({
          direction: 'up',
          text: `【${t.name}】${t.active.text}`,
          effects: t.active.effects,
          treasureId: id,
          treasureLabel: t.name
        });
      }
    }
    return options;
  }

  /**
   * 获取拥有的法宝列表
   */
  getOwnedList() {
    return [...this.owned].map(id => this.treasureDB[id]).filter(Boolean);
  }

  // === P0 新增：装备系统 ===

  /**
   * 装备法宝到指定槽位
   * @param {string} treasureId - 法宝ID
   * @param {string} slot - 槽位 (weapon/armor/accessory/artifact)
   * @returns {Object} { success, oldEquipped, message }
   */
  equip(treasureId, slot) {
    // 验证
    if (!this.owned.has(treasureId)) {
      return { success: false, message: '未拥有此法宝' };
    }
    if (!['weapon', 'armor', 'accessory', 'artifact'].includes(slot)) {
      return { success: false, message: '无效槽位' };
    }

    const treasure = this.treasureDB[treasureId];
    if (!treasure) {
      return { success: false, message: '法宝数据不存在' };
    }

    // 检查槽位类型匹配（可选，宽松处理）
    const typeMap = {
      'weapon': ['weapon', 'accessory'], // 剑心佩等
      'armor': ['armor'],
      'accessory': ['accessory', 'tool', 'regen', 'material'],
      'artifact': ['artifact', 'consumable']
    };
    // 暂时不强制类型匹配，让玩家自由搭配

    // 卸下旧装备
    const oldId = this.equipped[slot];
    if (oldId) {
      // 旧装备效果失效（自动处理，因为getPassiveBonuses只算equipped）
    }

    // 装备新法宝
    this.equipped[slot] = treasureId;

    // 同步到gameState
    if (gameState) {
      gameState.equipment[slot] = treasureId;
      // 从inventory移除，加入equipment
      const invIndex = gameState.treasureInventory.indexOf(treasureId);
      if (invIndex > -1) {
        gameState.treasureInventory.splice(invIndex, 1);
      }
    }

    eventBus.emit('treasure:equipped', { treasureId, slot, oldId });
    return { success: true, oldEquipped: oldId, message: `已装备【${treasure.name}】到${this._slotName(slot)}` };
  }

  /**
   * 卸下指定槽位的法宝
   * @param {string} slot
   * @returns {Object} { success, unequipped }
   */
  unequip(slot) {
    const treasureId = this.equipped[slot];
    if (!treasureId) {
      return { success: false, message: '该槽位没有装备' };
    }

    this.equipped[slot] = null;

    // 同步到gameState
    if (gameState) {
      gameState.equipment[slot] = null;
      // 放回inventory
      if (!gameState.treasureInventory.includes(treasureId)) {
        gameState.treasureInventory.push(treasureId);
      }
    }

    eventBus.emit('treasure:unequipped', { treasureId, slot });
    const treasure = this.treasureDB[treasureId];
    return { success: true, unequipped: treasureId, message: `已卸下【${treasure?.name || treasureId}】` };
  }

  /**
   * 获取指定槽位装备的法宝ID
   */
  getEquipped(slot) {
    return this.equipped[slot];
  }

  /**
   * 获取所有已装备法宝的被动加成（只算装备的）
   * @override
   */
  getPassiveBonuses() {
    const bonuses = {};
    for (const slot of ['weapon', 'armor', 'accessory', 'artifact']) {
      const id = this.equipped[slot];
      if (!id) continue;
      const t = this.treasureDB[id];
      if (!t || !t.passive) continue;
      for (const [key, val] of Object.entries(t.passive)) {
        bonuses[key] = (bonuses[key] || 0) + val;
      }
    }
    return bonuses;
  }

  /**
   * 获取法宝数据
   * @param {string} treasureId
   * @returns {Object|null}
   */
  getTreasureData(treasureId) {
    return this.treasureDB[treasureId] || null;
  }

  /**
   * 执行复活逻辑
   * @param {string} treasureId
   * @param {Object} state - gameState引用
   * @param {string} deathReason
   * @returns {Object} { success, effect }
   */
  executeRevive(treasureId, state, deathReason) {
    const treasure = this.treasureDB[treasureId];
    if (!treasure || !treasure.revive) {
      return { success: false };
    }

    const reviveConfig = treasure.revive;
    let effect = '';

    switch (reviveConfig.type) {
      case 'nirvana':
        // 涅槃羽：HP回50%，道心-5
        state.attributes.health = Math.max(state.attributes.health, Math.floor(state.attributes.health * 0.5 + 30));
        state.attributes.daoHeart = Math.max(0, state.attributes.daoHeart - 5);
        effect = '涅槃之火燃起，你从灰烬中重生！HP恢复至50%，但道心-5';
        break;

      case 'substitute':
        // 替身符：HP回30%，灵石-50%
        state.attributes.health = Math.max(state.attributes.health, Math.floor(state.attributes.health * 0.3 + 20));
        state.resources.spiritStone = Math.floor(state.resources.spiritStone * 0.5);
        effect = '替身符化作灰烬，替你承受了死亡。HP恢复至30%，灵石减半';
        break;

      case 'samsara':
        // 轮回镜：回到10回合前（需要记录历史状态）
        // 简化版：HP回50%，道心-20， cultivation-10
        state.attributes.health = Math.floor(state.attributes.health * 0.5 + 25);
        state.attributes.daoHeart = Math.max(0, state.attributes.daoHeart - 20);
        state.attributes.cultivation = Math.max(0, state.attributes.cultivation - 10);
        effect = '轮回镜照出前世之路。你回到10回合前的自己，但道心-20，修为-10';
        break;

      case 'chaos':
        // 混沌茧：HP全满，所有属性初始化为50
        state.attributes.health = 100;
        state.attributes.cultivation = 50;
        state.attributes.daoHeart = 50;
        state.attributes.fortune = 50;
        state.attributes.karmaGood = 50;
        state.attributes.karmaBad = 50;
        effect = '混沌茧破碎，你以混沌体重生。全属性重置为50，但获得了第二次机会';
        break;

      default:
        return { success: false };
    }

    // 消耗复活法宝（一次性）
    this.unequip('artifact'); // 卸下
    this.owned.delete(treasureId); // 从拥有列表移除
    if (state) {
      const invIdx = state.treasureInventory.indexOf(treasureId);
      if (invIdx > -1) state.treasureInventory.splice(invIdx, 1);
    }

    state.dead = false;
    state.deadReason = '';

    return { success: true, effect };
  }

  /**
   * 槽位中文名
   */
  _slotName(slot) {
    const names = { weapon: '武器', armor: '防具', accessory: '饰品', artifact: '秘宝' };
    return names[slot] || slot;
  }

  /**
   * 获取法宝的战斗修正（属性层）
   * 用于战斗系统
   */
  getCombatModifiers() {
    const bonuses = this.getPassiveBonuses();
    return {
      atk: bonuses.atk || 0,
      def: bonuses.def || 0,
      critRate: bonuses.critRate || 0,
      critDmg: bonuses.critDmg || 0,
      soulDmg: bonuses.soulDmg || 0,
      blockWindow: bonuses.blockWindow || 0,
      qiRegen: bonuses.qiRegen || 0,
      mindResist: bonuses.mindResist || 0,
      dodgeQiGain: bonuses.dodgeQiGain || 0
    };
  }

  /**
   * 获取所有已装备法宝的特性标签集合（特性层）
   * @returns {Set<string>} 如 Set{'先手','破甲','妖噬'}
   */
  getEquippedTraits() {
    const traits = new Set();
    for (const slot of ['weapon', 'armor', 'accessory', 'artifact']) {
      const id = this.equipped[slot];
      if (!id) continue;
      const t = this.treasureDB[id];
      if (t && t.trait) traits.add(t.trait);
    }
    return traits;
  }

  /**
   * 检查是否装备了某个特性的法宝
   */
  hasTrait(traitName) {
    return this.getEquippedTraits().has(traitName);
  }
}

// 全局单例
const treasureSystem = new TreasureSystem();
