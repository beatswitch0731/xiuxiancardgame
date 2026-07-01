/**
 * SceneLayerSystem - 环境叙事/场景系统
 *
 * 卡牌游戏无法展示3D空间，环境叙事通过以下方式实现：
 *   1. 场景卡 —— 进入位置时弹出，展示文字+背景描述
 *   2. 叙事层叠加 —— 同一位置多次访问揭示不同深度的信息
 *   3. 位置状态变迁 —— 关键事件后同一位置"看起来不同"
 *
 * 三层位置体系：
 *   Tier 1 — 主场景（宗门/坊市/秘境/洞府/魔域/天道虚空）
 *   Tier 2 — 细粒度位置（宗门大殿/藏经阁/炼丹房/剑崖...）
 *   Tier 3 — 隐藏位置（白落霜的狐丘/血煞地宫/天道裂缝...）
 *
 * 场景卡注入优先级：28（低于商店25，高于普通卡10）
 */
class SceneLayerSystem {
  constructor() {
    /** @type {Object<string, Object>} 位置数据映射 */
    this.locations = {};
    /** @type {Object<string, Array>} 场景卡牌池（按 location + layer 索引） */
    this.locationCards = {};
    /** @type {Array} 已触发的场景卡ID（防止重复） */
    this.triggeredCards = [];
    /** @type {number} 同位置重复访问触发深度卡的轮数间隔 */
    this.DEEP_LAYER_INTERVAL = 8;
  }

  /**
   * 加载位置数据
   * @param {Object} data - { locations: {...}, cards: [...] }
   */
  loadData(data) {
    if (!data) return;

    // 加载位置体系
    if (data.locations) {
      for (const [locId, locData] of Object.entries(data.locations)) {
        this.locations[locId] = locData;
      }
    }

    // 索引场景卡牌（按 location + layer）
    if (data.cards) {
      for (const card of data.cards) {
        const key = `${card.location}_layer_${card.layer}`;
        if (!this.locationCards[key]) this.locationCards[key] = [];
        this.locationCards[key].push(card);
      }
    }
  }

  /**
   * 获取当前位置的场景卡
   * @param {string} location - 位置ID
   * @param {boolean} isFirstVisit - 是否首次访问
   * @returns {Object|null} 场景卡或 null
   */
  getLocationCard(location, isFirstVisit) {
    if (!location) return null;

    // 记录访问
    if (gameState) {
      if (!gameState.visitedLocations) gameState.visitedLocations = [];
      if (!gameState.locationStates) gameState.locationStates = {};

      if (!gameState.locationStates[location]) {
        gameState.locationStates[location] = { visits: 0, layer: 1, eventFlags: [] };
      }

      const locState = gameState.locationStates[location];
      locState.visits++;

      // 首次访问 → Layer 1
      if (isFirstVisit) {
        return this._getCardForLayer(location, 1);
      }

      // 多次访问 → 深度层（每 DEEP_LAYER_INTERVAL 轮一次）
      if (locState.visits >= 3 && locState.layer < 3 && locState.visits % this.DEEP_LAYER_INTERVAL === 0) {
        locState.layer++;
        return this._getCardForLayer(location, locState.layer);
      }
    }

    return null;
  }

  /**
   * 位置切换处理
   * @param {string} newLocation - 目标位置
   * @param {string} reason - 切换原因（'manual', 'realm_breakthrough', 'quest_trigger', 'story_event'）
   */
  transition(newLocation, reason) {
    if (!gameState || !newLocation) return;

    const oldLocation = gameState.currentLocation;
    gameState.currentLocation = newLocation;

    if (!gameState.visitedLocations) gameState.visitedLocations = [];
    const isFirstVisit = !gameState.visitedLocations.includes(newLocation);

    if (isFirstVisit) {
      gameState.visitedLocations.push(newLocation);
    }

    // 发射位置切换事件
    if (typeof eventBus !== 'undefined' && oldLocation !== newLocation) {
      eventBus.emit('state:locationChanged', {
        from: oldLocation,
        to: newLocation,
        reason: reason || 'manual',
        isFirstVisit
      });
    }
  }

  /**
   * 根据位置的事件标记获取"变迁后"的场景卡
   * @param {string} location - 位置ID
   * @param {string} eventFlag - 事件标记（如 'bai_ren_departed'）
   * @returns {Object|null}
   */
  getTransitionedCard(location, eventFlag) {
    if (!gameState || !location) return null;

    const locState = gameState.locationStates ? gameState.locationStates[location] : null;
    if (!locState || !locState.eventFlags) return null;
    if (!locState.eventFlags.includes(eventFlag)) return null;

    const key = `${location}_flag_${eventFlag}`;
    if (this.locationCards[key]) {
      const card = this.locationCards[key][0];
      if (card && !this.triggeredCards.includes(card.id)) return card;
    }

    return null;
  }

  /**
   * 标记位置事件（NPC死亡/剧情转折后调用）
   * @param {string} location - 位置ID
   * @param {string} eventFlag - 事件标记
   */
  markLocationEvent(location, eventFlag) {
    if (!gameState) return;
    if (!gameState.locationStates) gameState.locationStates = {};
    if (!gameState.locationStates[location]) {
      gameState.locationStates[location] = { visits: 0, layer: 1, eventFlags: [] };
    }
    if (!gameState.locationStates[location].eventFlags.includes(eventFlag)) {
      gameState.locationStates[location].eventFlags.push(eventFlag);
    }
  }

  /**
   * 获取指定层的场景卡
   * @private
   */
  _getCardForLayer(location, layer) {
    const key = `${location}_layer_${layer}`;
    const cards = this.locationCards[key];
    if (!cards || cards.length === 0) return null;

    // 过滤已触发
    const available = cards.filter(c => !this.triggeredCards.includes(c.id));
    if (available.length === 0) return null;

    const card = available[Math.floor(Math.random() * available.length)];
    this.triggeredCards.push(card.id);
    return card;
  }

  /**
   * 获取位置的美术/氛围配置（供UI渲染用）
   * @param {string} location
   * @returns {Object} { bgClass, borderColor, particleType, description }
   */
  getLocationAtmosphere(location) {
    const locData = this.locations[location];
    if (locData && locData.atmosphere) return locData.atmosphere;

    // 通用回退
    const defaults = {
      '宗门': { bgClass: 'loc-sect', borderColor: '#c9a96e', particleType: 'cloud', description: '仙宗圣地，灵气充沛' },
      '坊市': { bgClass: 'loc-market', borderColor: '#d4443b', particleType: 'spark', description: '修士云集，热闹非凡' },
      '秘境': { bgClass: 'loc-dungeon', borderColor: '#5b7fff', particleType: 'rune', description: '危机四伏，机缘暗藏' },
      '洞府': { bgClass: 'loc-cave', borderColor: '#4a7c59', particleType: 'mist', description: '幽静洞府，修炼之所' },
      '魔域': { bgClass: 'loc-demon', borderColor: '#7b2d3b', particleType: 'ember', description: '魔气弥漫，压抑邪异' },
      '天道虚空': { bgClass: 'loc-void', borderColor: 'transparent', particleType: 'star', description: '超越凡尘，直面天道' }
    };

    return defaults[location] || { bgClass: 'loc-default', borderColor: '#555', particleType: null, description: '' };
  }

  /**
   * 获取所有已发现的位置列表
   * @returns {string[]}
   */
  getVisitedLocations() {
    return gameState && gameState.visitedLocations ? [...gameState.visitedLocations] : ['宗门'];
  }

  /**
   * 重置（转世时调用）
   */
  reset() {
    this.triggeredCards = [];
  }
}

// 全局单例
const sceneLayerSystem = new SceneLayerSystem();
