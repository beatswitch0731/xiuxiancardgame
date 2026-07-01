/**
 * PathSkillSystem - 功法技能系统
 *
 * 管理 4 功法各 3 个被动技能。
 * 技能在境界突破时自动解锁。
 * 被动效果在相关结算时由其他系统读取。
 */
class PathSkillSystem {
  constructor() {
    this.skills = {};        // path → { [skillId]: skill }
    this.unlocked = {};      // path → Set of skillIds
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

    // 转世重置时清空已解锁技能
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

  /**
   * 获取当前功法的聚合被动加成
   * @param {string} path
   * @returns {Object} 键值对
   */
  getPassiveBonuses(path) {
    const bonuses = {};
    if (!this.skills[path]) return bonuses;
    for (const skillId of this.unlocked[path] || []) {
      const skill = this.skills[path][skillId];
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
    if (!this.unlocked[path]) return [];
    return [...this.unlocked[path]].map(id => this.skills[path][id]).filter(Boolean);
  }
}

// 全局单例
const pathSkillSystem = new PathSkillSystem();
