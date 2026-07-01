/**
 * LegacyFragmentSystem — 传承残卷掉落系统 (GDD 上瘾引擎 §2)
 *
 * 核心机制：
 *   - 每张普通卡牌后有概率掉落传承残卷
 *   - 境界越高，掉落概率越大
 *   - 6 套传承套装，各 8 片碎片
 *   - 集齐 8 片 → 合成传承，获得永久被动加成
 *   - Boss 战斗胜利保证掉落
 */
class LegacyFragmentSystem {
  constructor() {
    this.fragments = {};  // { setId: [bool×8] }
    this.completed = [];  // 已合成的套装ID列表
    this.onLog = null;
  }

  init() {
    this.fragments = {};
    this.completed = [];
    eventBus.on('state:reset', () => this.reset());
  }

  reset() {
    this.fragments = {};
    this.completed = [];
  }

  /**
   * 6 传承套装定义
   */
  _sets() {
    return {
      sword_heart: {
        name: '剑心通明',
        effect: '攻击力+10 暴击率+8%',
        pieces: 8,
        icon: '⚔',
        passive: { atk: 10, critRate: 8 }
      },
      pill_way: {
        name: '丹道真解',
        effect: '丹药效果+30% 回血+2/轮',
        pieces: 8,
        icon: '💊',
        passive: { pillBonus: 30, hpRegen: 2 }
      },
      array_way: {
        name: '阵法玄机',
        effect: '防御+8 道心伤害减免+15%',
        pieces: 8,
        icon: '🔮',
        passive: { def: 8, daoResist: 15 }
      },
      heaven_book: {
        name: '天书残卷',
        effect: '福缘+10 修为获得+20%',
        pieces: 8,
        icon: '📜',
        passive: { fortuneBonus: 10, cultivationBonus: 20 }
      },
      demon_blood: {
        name: '魔血传承',
        effect: '攻击+15 道心-5 (邪恶之道)',
        pieces: 8,
        icon: '🩸',
        passive: { atk: 15, daoHeartPenalty: -5 }
      },
      immortal_will: {
        name: '仙人之志',
        effect: '最大气血+20 寿元上限+10',
        pieces: 8,
        icon: '✨',
        passive: { maxHp: 20, maxLifespan: 10 }
      }
    };
  }

  /**
   * 尝试掉落传承残卷
   * @param {string} realm 当前境界
   * @returns {Object|null} 掉落的碎片信息, 或 null
   */
  tryDrop(realm) {
    const dropRate = this._dropRate(realm);
    if (Math.random() > dropRate) return null;

    // 选择一套未完成的传承
    const incomplete = this._getIncompleteSets();
    if (incomplete.length === 0) return null;

    const setId = incomplete[Math.floor(Math.random() * incomplete.length)];
    return this._addFragment(setId);
  }

  /**
   * Boss 击败保证掉落
   * @param {string} realm 当前境界
   * @returns {Object} 掉落的碎片信息
   */
  dropFromBoss(realm) {
    const incomplete = this._getIncompleteSets();
    if (incomplete.length === 0) return null;
    const setId = incomplete[Math.floor(Math.random() * incomplete.length)];
    return this._addFragment(setId);
  }

  /**
   * 境界 → 掉落概率
   */
  _dropRate(realm) {
    const map = { qi: 0.08, foundation: 0.10, golden: 0.12, nascent: 0.15, deity: 0.18, tribulation: 0.22 };
    return map[realm] || 0.08;
  }

  /**
   * 获取未完成的套装ID列表
   */
  _getIncompleteSets() {
    const sets = this._sets();
    return Object.keys(sets).filter(setId => !this.completed.includes(setId));
  }

  /**
   * 向指定套装添加一片碎片
   * @param {string} setId
   * @returns {Object|null} { setId, name, icon, count, total }
   */
  _addFragment(setId) {
    if (!this.fragments[setId]) {
      this.fragments[setId] = new Array(8).fill(false);
    }
    const arr = this.fragments[setId];
    const empty = [];
    for (let i = 0; i < arr.length; i++) {
      if (!arr[i]) empty.push(i);
    }
    if (empty.length === 0) return null;
    const idx = empty[Math.floor(Math.random() * empty.length)];
    arr[idx] = true;

    const set = this._sets()[setId];
    const count = arr.filter(Boolean).length;
    const msg = `${set.icon} 获得传承残卷：「${set.name}」(${count}/${set.pieces})`;
    if (this.onLog) this.onLog(msg);

    return { setId, name: set.name, icon: set.icon, count, total: set.pieces, pieceIndex: idx };
  }

  /**
   * 检查所有套装的完成状态，合成已完成套装
   * @returns {Array} 新合成的套装列表 [{ name, effect, passive }]
   */
  checkCompletions() {
    const newCompletions = [];
    const sets = this._sets();

    for (const [setId, set] of Object.entries(sets)) {
      if (this.completed.includes(setId)) continue;
      const arr = this.fragments[setId];
      if (!arr) continue;
      if (arr.every(Boolean)) {
        this.completed.push(setId);
        newCompletions.push({ setId, name: set.name, effect: set.effect, passive: set.passive });
        if (this.onLog) this.onLog(`🎉 传承合成：「${set.name}」！${set.effect}`);
      }
    }
    return newCompletions;
  }

  /**
   * 获取所有已合成传承的聚合被动加成
   * @returns {Object} { atk, def, critRate, hpRegen, pillBonus, daoResist, fortuneBonus, maxHp, maxLifespan, cultivationBonus, daoHeartPenalty }
   */
  getPassiveBonuses() {
    const bonuses = {};
    const sets = this._sets();
    for (const setId of this.completed) {
      const set = sets[setId];
      if (!set || !set.passive) continue;
      for (const [key, val] of Object.entries(set.passive)) {
        bonuses[key] = (bonuses[key] || 0) + val;
      }
    }
    return bonuses;
  }

  /**
   * 获取碎片收集进度（供 UI 显示）
   */
  getProgress() {
    const progress = {};
    const sets = this._sets();
    for (const setId of Object.keys(sets)) {
      const arr = this.fragments[setId];
      const count = arr ? arr.filter(Boolean).length : 0;
      progress[setId] = {
        name: sets[setId].name,
        icon: sets[setId].icon,
        count,
        total: sets[setId].pieces,
        completed: this.completed.includes(setId)
      };
    }
    return progress;
  }
}

// 全局单例
const legacyFragmentSystem = new LegacyFragmentSystem();
