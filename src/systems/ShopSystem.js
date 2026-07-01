/**
 * ShopSystem - 商店系统
 *
 * 管理商品数据、过滤器、购买逻辑。
 * 触发方式：CardSystem 在特定时机注入 shop_encounter 卡。
 * 购买结果通过 eventBus 通知 UI 更新。
 */
class ShopSystem {
  constructor() {
    this.items = [];           // 所有商品
    this._initialized = false;
  }

  init() {
    if (this._initialized) return;
    const data = dataLoader.loadSync('shops:shop_items');
    if (data && data.items) {
      this.items = data.items;
    }
    this._initialized = true;
  }

  /**
   * 获取当前境界可购买的商品列表
   * @param {string} realm - 当前境界
   * @returns {Array}
   */
  getAvailableItems(realm) {
    const realmOrder = ['qi', 'foundation', 'golden', 'nascent', 'formation', 'void', 'tribulation'];
    const maxIdx = realmOrder.indexOf(realm);
    if (maxIdx < 0) return [];

    return this.items.filter(item => {
      const itemIdx = realmOrder.indexOf(item.realm);
      return itemIdx <= maxIdx;
    });
  }

  /**
   * 尝试购买商品
   * @param {string} itemId - 商品 ID
   * @returns {Object} { success, message, item }
   */
  purchase(itemId) {
    const item = this.items.find(i => i.id === itemId);
    if (!item) return { success: false, message: '商品不存在。' };

    // 检查灵石
    if (gameState.resources.spiritStone < item.price) {
      return { success: false, message: '灵石不足。' };
    }

    // 扣灵石
    gameState.addResource('spiritStone', null, -item.price);

    // 应用效果
    const result = this._applyItemEffect(item);

    eventBus.emit('shop:purchased', { item, result });
    return { success: true, message: `购买了 ${item.name}。`, item, result };
  }

  /**
   * 应用商品效果
   */
  _applyItemEffect(item) {
    const effect = item.effect || {};

    // 丹药类
    if (item.type === 'pill') {
      if (effect.pillId) {
        gameState.addResource('pills', effect.pillId, 1);
        return { type: 'pill', pillId: effect.pillId };
      }
      if (effect.healHp) {
        gameState.addAttribute('health', effect.healHp);
        return { type: 'heal', amount: effect.healHp };
      }
      if (effect.healDaoHeart) {
        gameState.addAttribute('daoHeart', effect.healDaoHeart);
        return { type: 'healDaoHeart', amount: effect.healDaoHeart };
      }
      if (effect.tempCultivation) {
        gameState.addAttribute('cultivation', effect.tempCultivation);
        return { type: 'tempCult', amount: effect.tempCultivation };
      }
    }

    // 法宝类
    if (item.type === 'treasure') {
      const treasureId = effect.treasureId;
      if (treasureId) {
        // 检查法宝栏是否已满（最多2件）
        if (gameState.resources.treasures.length >= 2) {
          // 需要替换，先返回提示
          return { type: 'treasure_need_replace', treasureId, requiresReplace: true };
        }
        treasureSystem.acquire(treasureId);
        gameState.addResource('treasures', treasureId, 1);
        return { type: 'treasure', treasureId };
      }
    }

    // NPC好感类
    if (item.type === 'npc_favor') {
      return { type: 'npc_favor', amount: effect.npcFavor || 15 };
    }

    return { type: 'unknown' };
  }

  /**
   * 替换法宝（当法宝栏已满时）
   * @param {string} newTreasureId - 新法宝 ID
   * @param {string} oldTreasureId - 要替换的法宝 ID
   */
  replaceTreasure(newTreasureId, oldTreasureId) {
    // 移除旧法宝
    const idx = gameState.resources.treasures.indexOf(oldTreasureId);
    if (idx >= 0) {
      gameState.resources.treasures.splice(idx, 1);
      treasureSystem.remove(oldTreasureId);
    }
    // 装备新法宝
    treasureSystem.acquire(newTreasureId);
    gameState.addResource('treasures', newTreasureId, 1);
    eventBus.emit('shop:treasureReplaced', { newId: newTreasureId, oldId: oldTreasureId });
  }
}

// 全局单例
const shopSystem = new ShopSystem();
