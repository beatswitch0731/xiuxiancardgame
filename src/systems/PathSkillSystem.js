/**
 * PathSkillSystem - 功法技能系统
 *
 * 管理 4 功法各 3 个被动技能。
 *
 * 技能是否生效由当前世的 `path + realm` 唯一派生；不会把可推导结果
 * 另存成第二份存档权威。`unlocked` 只保留本次运行的“新解锁提示”去重，
 * 不能决定被动是否存在。
 */
class PathSkillSystem {
  constructor() {
    this.skills = {};        // path → { [skillId]: skill }
    this.unlocked = {};      // path → Set of本次运行已提示 skillId（非权威）
    this._initialized = false;
  }

  /**
   * 初始化：加载技能数据
   */
  init() {
    if (this._initialized) return;
    const skillData = dataLoader.loadSync('config:path_skills');
    if (skillData && skillData.skills) {
      for (const [path, data] of Object.entries(skillData.skills)) {
        this.skills[path] = {};
        for (const skill of data.skills) {
          this.skills[path][skill.id] = skill;
        }
        this.unlocked[path] = new Set();
      }
    }
    this._initialized = true;

    // 转世重置时清空“本世已提示”缓存；实际技能会由新世 path + realm 派生。
    eventBus.on('state:reset', () => {
      for (const path of Object.keys(this.unlocked)) {
        this.unlocked[path] = new Set();
      }
    });
  }

  /**
   * 在境界突破时解锁技能
   * @param {string} path - 功法
   * @param {string} realm - 当前境界（突破后）
   */
  unlockForRealm(path, realm) {
    if (!this.skills[path]) return [];
    const unlocked = [];
    for (const skill of Object.values(this.skills[path])) {
      if (skill.unlockRealm === realm && !this.unlocked[path].has(skill.id)) {
        this.unlocked[path].add(skill.id);
        unlocked.push(skill);
      }
    }
    return unlocked;
  }

  _getRealmOrder() {
    const configured = typeof gameState !== 'undefined'
      ? gameState?.config?.realms?.order
      : null;
    return Array.isArray(configured) && configured.length > 0
      ? configured
      : ['qi', 'foundation', 'golden', 'nascent', 'deity', 'tribulation'];
  }

  _resolveRealm(realm) {
    if (typeof realm === 'string' && realm) return realm;
    return typeof gameState !== 'undefined' && gameState?.realm
      ? gameState.realm
      : 'qi';
  }

  /** 返回某流派的全部数据定义，供 UI 与调试读取。 */
  getAllSkills(path) {
    if (!this.skills[path]) return [];
    return Object.values(this.skills[path]);
  }

  /**
   * 判断技能是否在给定境界已生效。
   * 只接受数据定义和当前世境界；通知缓存不授予技能权限。
   */
  isSkillUnlocked(path, skillOrId, realm = null) {
    const skill = typeof skillOrId === 'string'
      ? this.skills[path]?.[skillOrId]
      : skillOrId;
    if (!skill || !this.skills[path]) return false;
    const order = this._getRealmOrder();
    const currentIndex = order.indexOf(this._resolveRealm(realm));
    const unlockIndex = order.indexOf(skill.unlockRealm);
    return currentIndex >= 0 && unlockIndex >= 0 && currentIndex >= unlockIndex;
  }

  /**
   * 获取当前功法的聚合被动加成
   * @param {string} path
   * @returns {Object} 键值对
   */
  getPassiveBonuses(path, realm = null) {
    const bonuses = {};
    if (!this.skills[path]) return bonuses;
    for (const skill of this.getUnlockedSkills(path, realm)) {
      if (skill && skill.passive) {
        for (const [key, val] of Object.entries(skill.passive)) {
          if (typeof val === 'number') {
            bonuses[key] = (bonuses[key] || 0) + val;
          }
        }
      }
    }
    return bonuses;
  }

  /**
   * 获取当前已解锁的功法技能列表
   * @param {string} path
   * @returns {Array}
   */
  getUnlockedSkills(path) {
    const realm = arguments.length > 1 ? arguments[1] : null;
    return this.getAllSkills(path).filter(skill => this.isSkillUnlocked(path, skill, realm));
  }

  /** 从权威的当前世状态读取正在生效的所有被动。 */
  getActiveBonuses(state = null) {
    const currentState = state || (typeof gameState !== 'undefined' ? gameState : null);
    return this.getPassiveBonuses(currentState?.path, currentState?.realm);
  }

  /** 返回下一项可期待的功法技能；最高阶段时为 null。 */
  getNextUnlock(path, realm = null) {
    const order = this._getRealmOrder();
    const currentIndex = order.indexOf(this._resolveRealm(realm));
    return this.getAllSkills(path)
      .filter(skill => !this.isSkillUnlocked(path, skill, realm))
      .sort((left, right) => order.indexOf(left.unlockRealm) - order.indexOf(right.unlockRealm))
      .find(skill => order.indexOf(skill.unlockRealm) > currentIndex) || null;
  }
}

// 全局单例
const pathSkillSystem = new PathSkillSystem();
