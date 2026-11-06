/**
 * EventBus - 全局事件总线
 * 所有模块通信的唯一通道，命名规范：领域:动作
 *
 * 事件类型：
 *   'card:drawn'           → 卡牌被抽出
 *   'card:chosen'          → 玩家做出选择
 *   'state:attributeChanged' → 属性变化
 *   'state:death'          → 玩家死亡
 *   'npc:met'              → 首次遇到NPC
 *   'npc:affectionChange'  → 好感度变化
 *   'quest:triggered'      → 支线触发
 *   'quest:completed'      → 支线完成
 *   'companion:event'      → 道侣事件触发
 *   'world:rumor'          → 新情报产生
 */
class EventBus {
  constructor() {
    this._listeners = {};
    this._onceListeners = {};
  }

  /**
   * 注册事件监听
   * @param {string} event - 事件名
   * @param {function} callback - 回调函数
   */
  on(event, callback) {
    if (!this._listeners[event]) {
      this._listeners[event] = [];
    }
    this._listeners[event].push(callback);
  }

  /**
   * 注册一次性事件监听
   * @param {string} event
   * @param {function} callback
   */
  once(event, callback) {
    if (!this._onceListeners[event]) {
      this._onceListeners[event] = [];
    }
    this._onceListeners[event].push(callback);
  }

  /**
   * 移除事件监听
   * @param {string} event
   * @param {function} callback
   */
  off(event, callback) {
    if (this._listeners[event]) {
      this._listeners[event] = this._listeners[event].filter(fn => fn !== callback);
    }
    if (this._onceListeners[event]) {
      this._onceListeners[event] = this._onceListeners[event].filter(fn => fn !== callback);
    }
  }

  /**
   * 触发事件
   * @param {string} event - 事件名
   * @param {*} data - 事件数据
   */
  emit(event, data) {
    // 调用常规监听器
    if (this._listeners[event]) {
      for (const fn of this._listeners[event]) {
        try { fn(data); } catch (e) { console.error(`[EventBus] Error in ${event}:`, e); }
      }
    }
    // 调用一次性监听器
    if (this._onceListeners[event]) {
      const onceList = this._onceListeners[event];
      this._onceListeners[event] = [];
      for (const fn of onceList) {
        try { fn(data); } catch (e) { console.error(`[EventBus] Error in once:${event}:`, e); }
      }
    }
  }

  /**
   * 收集事件请求（用于 CardSystem.draw() 优先级仲裁）
   * 各系统通过 emit('card:request', { source, priority, cardId }) 插入卡牌
   * CardSystem 随后通过 collect 收集所有请求并按优先级排序
   */
  collect(event, context) {
    const requests = [];
    // 临时劫持 emit，收集请求
    const originalEmit = this.emit.bind(this);
    let collected = [];
    const collector = (data) => { collected.push(data); };
    // 利用现有监听器 + 临时收集器
    if (this._listeners[event]) {
      for (const fn of this._listeners[event]) {
        const savedEmit = this.emit;
        this.emit = function(evt, d) {
          if (evt === event + ':response') collected.push(d);
        };
        try { fn(context); } catch (e) {}
        this.emit = savedEmit;
      }
    }
    return collected;
  }

  /**
   * 清除所有监听器（用于重置）
   */
  clear() {
    this._listeners = {};
    this._onceListeners = {};
  }
}

// 全局单例
const eventBus = new EventBus();

if (typeof module !== 'undefined' && module.exports) {
  module.exports = eventBus;
} else if (typeof window !== 'undefined') {
  window.EventBus = EventBus;
  window.eventBus = eventBus;
}
