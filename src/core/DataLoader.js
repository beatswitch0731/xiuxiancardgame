/**
 * DataLoader - JSON数据加载器
 *
 * 在纯HTML环境下，所有JSON数据内联到 DATA_MODULES 全局变量中
 * （因为双击打开HTML文件时 fetch 无法跨 file:// 协议加载JSON）
 *
 * DataLoader 优先从 DATA_MODULES 读取，fallback 到 fetch（需本地服务器）
 */
class DataLoader {
  constructor() {
    this.cache = new Map();
    this.pendingLoads = new Map();
  }

  /**
   * 加载指定数据模块（懒加载，带缓存）
   * @param {string} moduleName - 模块名，如 'cards:qi_condensation'
   * @returns {Promise<Object>}
   */
  async load(moduleName) {
    if (this.cache.has(moduleName)) return this.cache.get(moduleName);
    if (this.pendingLoads.has(moduleName)) return this.pendingLoads.get(moduleName);

    const loadPromise = this._fetchAndParse(moduleName);
    this.pendingLoads.set(moduleName, loadPromise);

    try {
      const data = await loadPromise;
      this.cache.set(moduleName, data);
      this.pendingLoads.delete(moduleName);
      eventBus.emit('data:loaded', { module: moduleName, count: this._countItems(data) });
      return data;
    } catch (e) {
      this.pendingLoads.delete(moduleName);
      console.error(`[DataLoader] Failed to load ${moduleName}:`, e);
      return null;
    }
  }

  /**
   * 同步加载（如果数据已在 DATA_MODULES 中，直接返回）
   * @param {string} moduleName
   * @returns {Object|null}
   */
  loadSync(moduleName) {
    if (this.cache.has(moduleName)) return this.cache.get(moduleName);

    const data = this._readFromModules(moduleName);
    if (data !== null) {
      this.cache.set(moduleName, data);
      return data;
    }
    return null;
  }

  /**
   * 预加载一系列模块
   * @param {string[]} moduleNames
   * @returns {Promise<Object[]>}
   */
  async preload(moduleNames) {
    return Promise.all(moduleNames.map(name => this.load(name)));
  }

  /**
   * 同步预加载一系列模块
   * @param {string[]} moduleNames
   * @returns {Object[]}
   */
  preloadSync(moduleNames) {
    return moduleNames.map(name => this.loadSync(name)).filter(Boolean);
  }

  /**
   * 清除缓存
   * @param {string} [moduleName] - 不传则清除全部
   */
  clearCache(moduleName) {
    if (moduleName) {
      this.cache.delete(moduleName);
    } else {
      this.cache.clear();
    }
  }

  // --- 内部方法 ---

  _readFromModules(moduleName) {
    // 优先从 DATA_MODULES 全局变量读取
    if (typeof DATA_MODULES !== 'undefined' && DATA_MODULES[moduleName]) {
      return DATA_MODULES[moduleName];
    }
    return null;
  }

  async _fetchAndParse(moduleName) {
    // 优先内联数据
    const inline = this._readFromModules(moduleName);
    if (inline !== null) return inline;

    // Fallback: fetch（需要本地服务器）
    const path = `data/${moduleName.replace(/:/g, '/')}.json`;
    const response = await fetch(path);
    if (!response.ok) throw new Error(`HTTP ${response.status}: ${path}`);
    return response.json();
  }

  _countItems(data) {
    if (!data) return 0;
    // 尝试常见的数据结构
    if (data.cards) return data.cards.length;
    if (data.npcs) return data.npcs.length;
    if (data.quests) return data.quests.length;
    if (data.dialogues) return data.dialogues.length;
    if (data.events) return data.events.length;
    if (Array.isArray(data)) return data.length;
    return Object.keys(data).length;
  }
}

// 全局单例
const dataLoader = new DataLoader();
