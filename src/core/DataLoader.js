/**
 * DataLoader - JSON数据统一加载器
 *
 * 消除双重维护问题：
 *   - 开发/维护时只需修改 data/ 目录下的 JSON 文件
 *   - 运行时优先从外部 JSON 加载（fetch），失败时回退到 DATA_MODULES 内联数据
 *   - 在 file:// 协议下（双击打开HTML），fetch 跨域失败，自动回退内联数据
 *
 * 加载优先级：
 *   1. 缓存（Cache）—— 已加载过的数据优先复用
 *   2. 外部 JSON（fetch / 同步 XHR）—— 数据唯一维护来源
 *   3. DATA_MODULES 内联数据 —— file:// 协议 fallback
 */
class DataLoader {
  constructor() {
    this.cache = new Map();
    this.pendingLoads = new Map();
  }

  /**
   * 加载指定数据模块（异步，优先从外部JSON fetch，失败回退内联）
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
      eventBus.emit('data:loaded', { module: moduleName, count: this._countItems(data), source: 'external' });
      return data;
    } catch (e) {
      this.pendingLoads.delete(moduleName);
      console.error(`[DataLoader] Failed to load ${moduleName}:`, e);
      return null;
    }
  }

  /**
   * 同步加载（优先从外部JSON加载，失败回退内联数据）
   * @param {string} moduleName
   * @returns {Object|null}
   */
  loadSync(moduleName) {
    if (this.cache.has(moduleName)) return this.cache.get(moduleName);

    // 优先尝试从外部JSON同步加载（HTTP环境下可用）
    try {
      const externalData = this._fetchSync(moduleName);
      if (externalData !== null) {
        this.cache.set(moduleName, externalData);
        return externalData;
      }
    } catch (e) {
      // 同步加载不可用（如浏览器主线程已禁用同步XHR），静默回退
    }

    // Fallback: 内联数据
    const inline = this._readFromModules(moduleName);
    if (inline !== null) {
      this.cache.set(moduleName, inline);
      return inline;
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
    // 从 DATA_MODULES 全局变量读取内联数据
    if (typeof DATA_MODULES !== 'undefined' && DATA_MODULES[moduleName]) {
      return DATA_MODULES[moduleName];
    }
    return null;
  }

  /**
   * 同步加载外部JSON（best-effort）
   * 在浏览器主线程中同步XHR已被弃用，但在以下环境可用：
   *   - Node.js 测试环境
   *   - Electron / WebView
   *   - 某些旧版浏览器
   * 当同步XHR不可用时，会自动回退到内联数据
   */
  _fetchSync(moduleName) {
    if (typeof XMLHttpRequest === 'undefined') return null;
    const path = `data/${moduleName.replace(/:/g, '/')}.json`;
    const xhr = new XMLHttpRequest();
    xhr.open('GET', path, false); // false = 同步请求
    xhr.send(null);
    if (xhr.status === 200 || xhr.status === 0) {
      return JSON.parse(xhr.responseText);
    }
    return null;
  }

  async _fetchAndParse(moduleName) {
    // 1. 优先从外部JSON加载（数据唯一维护来源）
    const path = `data/${moduleName.replace(/:/g, '/')}.json`;
    try {
      const response = await fetch(path);
      if (response.ok) {
        return await response.json();
      }
    } catch (e) {
      // fetch 失败（常见原因：file:// 协议跨域、网络断开、文件不存在）
    }

    // 2. Fallback: 内联数据（双击打开HTML时的兜底方案）
    const inline = this._readFromModules(moduleName);
    if (inline !== null) return inline;

    // 3. 两者都失败，抛出明确错误
    throw new Error(`Failed to load ${moduleName}: neither external JSON (${path}) nor inline DATA_MODULES available`);
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
