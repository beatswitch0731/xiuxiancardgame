/**
 * CombatSystem — 回合制战斗系统 v1
 *
 * 战斗流程：
 *   1. 抽到 combat 标签的卡 → 触发战斗
 *   2. 初始化战斗：玩家属性 + 敌人属性
 *   3. 每回合：玩家选择动作 → 结算伤害 → 敌人行动 → 结算伤害
 *   4. 一方 HP ≤ 0 → 战斗结束
 *   5. 胜利：获得奖励（灵石/修为/丹药）
 *   6. 失败：扣除血量，可能触发死亡
 *
 * 玩家属性派生：
 *   - HP: gameState.attributes.health × 3 + 体质加成
 *   - ATK: 5 + cultivation/10 + 剑修加成 + 法宝 atk
 *   - DEF: 3 + 体质加成 + 法宝 def
 *
 * 敌人属性：定义在卡牌的 enemy 字段中
 */
class CombatSystem {
  constructor() {
    this.active = false;
    this.player = null;
    this.enemy = null;
    this.turn = 0;
    this.log = [];
    this.cardId = null;       // 当前触发的战斗卡 ID
    this.rewards = null;      // 战斗奖励
    // ── v2.0 新字段 ──
    this.qi = 0;              // L1: 当前灵力
    this.maxQi = 0;           // L1: 灵力上限
    this.stance = 'attack';   // L2: 架势 attack|defend|break
    this.momentum = 0;        // L4: 连击势层
    this.finisherUnlocked = false;
    this._divineStrike = false; // L5: 天助一击
    // ── L6: 法宝特性追踪 ──
    this._traits = new Set();       // 已装备法宝的特性标签
    this._hasFirstStruck = false;   // 先手是否已触发
    this._voidDodgeReady = true;    // 空蝉是否可用
    this._combatTurnCount = 0;      // 战斗内回合计数（用于续命珠）
  }

  init() {
    this.active = false;
    this.log = [];
    this.turn = 0;
    eventBus.on('combat:start', (data) => this._start(data));
    eventBus.on('combat:action', (data) => this._executeAction(data));
    eventBus.on('combat:blockAction', (data) => this._resolveBlock(data));
    eventBus.on('state:reset', () => this.reset());
  }

  reset() {
    this.active = false;
    this.player = null;
    this.enemy = null;
    this.turn = 0;
    this.log = [];
    this.cardId = null;
    this.rewards = null;
    this.qi = 0;
    this.maxQi = 0;
    this.stance = 'attack';
    this.momentum = 0;
    this.finisherUnlocked = false;
    this._isDefending = false;
    this._divineStrike = false;
    this._traits = new Set();
    this._hasFirstStruck = false;
    this._voidDodgeReady = true;
    this._combatTurnCount = 0;
  }

  // ============ 战斗开始 ============

  /**
   * 从卡牌数据初始化战斗
   * @param {Object} card — 带 enemy 字段的卡牌
   */
  _start(data) {
    const card = data.card;
    if (!card || !card.enemy) return;

    this.cardId = card.id;
    this.originalCard = card;
    this.rewards = card.combatRewards || null;

    // 构建玩家属性
    const gs = gameState;
    const path = gs.path || 'sword';
    const treasMod = treasureSystem ? treasureSystem.getCombatModifiers() : {};

    // 基础属性
    let hp = Math.max(10, Math.floor(gs.attributes.health * 3));
    let atk = 5 + Math.floor(gs.attributes.cultivation / 10) + (treasMod.atk || 0);
    let def = 3 + (treasMod.def || 0);
    let critRate = 10 + (treasMod.critRate || 0);
    let daoResist = 0;

    // 功法被动加成（从 PathSkillSystem 读取）
    let pathBonuses = {};
    if (pathSkillSystem && pathSkillSystem.getPassiveBonuses) {
      pathBonuses = pathSkillSystem.getPassiveBonuses(path) || {};
    }
    if (pathBonuses.atk) atk += pathBonuses.atk;
    if (pathBonuses.def) def += pathBonuses.def;
    if (pathBonuses.critRate) critRate += pathBonuses.critRate;
    if (pathBonuses.daoResist) daoResist += pathBonuses.daoResist;
    if (pathBonuses.maxHp) {
      hp += pathBonuses.maxHp;
    }
    // lowHpAtkBonus 和 pillBonus 在对应时机读取，此处不叠加

    // 功法主动加成（原有 switch 逻辑保留，与被动叠加）
    switch (path) {
      case 'sword':
        atk += 5;
        critRate += 10;
        hp -= 5;
        break;
      case 'spell':
        atk += 3;
        daoResist += 5;
        break;
      case 'body':
        hp += 20;
        def += 5;
        atk -= 2;
        break;
      case 'pill':
        hp += 10;
        hp += Math.floor(gs.attributes.cultivation / 20);
        break;
    }

    // 道侣加成
    if (gs.resources && gs.resources.companions && gs.resources.companions.length > 0) {
      // 基础：每有一位道侣，生命+3 / 攻击+1
      hp += gs.resources.companions.length * 3;
      atk += Math.floor(gs.resources.companions.length / 2);
      // 道侣个性化加成（弧线系统）
      if (typeof companionSystem !== 'undefined' && companionSystem) {
        const allBonuses = companionSystem.getAllBonuses();
        if (allBonuses) {
          for (const [key, val] of Object.entries(allBonuses)) {
            if (key === 'hpRegen') hp += val;          // 生命回复=生命上限
            if (key === 'iceAtk') atk += val;           // 冰系伤害
            if (key === 'spellPower') atk += val;       // 法术伤害
            if (key === 'dodge') critRate += Math.floor(val / 2);  // 闪避→暴击
          }
        }
      }
    }

    // 道心影响伤害
    atk += Math.floor(gs.attributes.daoHeart / 20);

    this.player = {
      hp: hp,
      maxHp: hp,
      atk: Math.max(1, atk),
      def: Math.max(0, def),
      critRate: Math.min(50, Math.max(0, critRate)),
      daoResist: Math.min(30, Math.max(0, daoResist)),
      path: path
    };

    // 构建敌人属性
    const enemyData = card.enemy;
    this.enemy = {
      name: enemyData.name || '未知敌人',
      hp: enemyData.hp || 30,
      maxHp: enemyData.hp || 30,
      atk: enemyData.atk || 8,
      def: enemyData.def || 2,
      critRate: enemyData.critRate || 5,
      special: enemyData.special || null,   // 特殊技能描述
      specialChance: enemyData.specialChance || 0.2,
      specialDmg: enemyData.specialDmg || 0,
      factionId: enemyData.factionId || null  // 关联势力（Combat→Faction 环）
    };

    // 【难度曲线】根据转世次数缩放敌人属性
    this._applyDifficultyScaling();

    // ── v2.0 灵力/架势/连击初始化 ──
    this.maxQi = Math.floor(gameState.attributes.cultivation / 10) + 3;
    this.qi = this.maxQi;
    this.stance = 'attack';
    this.momentum = 0;
    this.finisherUnlocked = false;
    this._divineStrike = false;

    // ── L6: 读取已装备法宝特性 ──
    this._traits = treasureSystem ? treasureSystem.getEquippedTraits() : new Set();
    this._hasFirstStruck = false;
    this._voidDodgeReady = true;
    this._combatTurnCount = 0;

    this.active = true;
    this.turn = 1;
    this.log = [];

    this._addLog(`⚔️ ${this.enemy.name} 出现了！`);
    this._addLog(`【第 ${this.turn} 回合】`);
    eventBus.emit('combat:started', {
      player: this.player,
      enemy: this.enemy,
      cardId: this.cardId
    });
  }

  // ============ 玩家行动 ============

  /**
   * 获取当前可用的动作列表
   */
  getActions() {
    const actions = [];
    // ── L1: 灵力枯竭时只能调息 ──
    if (this.qi <= 0) {
      actions.push({ id: 'meditate', text: '调息', desc: '运转周天，+2灵力（本回合 DEF-50%）' });
      return actions;
    }
    // ── L2: 架势切换 ──
    const stanceNames = { attack: '攻·破军', defend: '守·磐石', break: '破·碎虚' };
    const stanceDescs = {
      attack: 'ATK+30% DEF-20% 暴击+10%',
      defend: 'ATK-30% DEF+50% 灵+1/回合',
      break: 'ATK+10% 无视敌方架势增益'
    };
    const otherStances = Object.keys(stanceNames).filter(s => s !== this.stance);
    for (const s of otherStances) {
      actions.push({ id: 'stance_'+s, text: '⇄ '+stanceNames[s], desc: stanceDescs[s] });
    }
    // ── 普通动作 ──
    actions.push({ id: 'attack', text: '⚔ 攻击', desc: `ATK伤害 (-1灵) [势:${this.momentum}]` });
    actions.push({ id: 'defend', text: '🛡 防御', desc: '减伤50% + 回复10%HP (+1灵)' });
    // ── L4: 连击终结技 ──
    if (this.momentum >= 3) {
      const finisher = this._getFinisher();
      actions.push({ id: 'finisher', text: '💥 '+finisher.name, desc: finisher.desc+' (-'+finisher.qiCost+'灵)' });
    } else {
      actions.push({ id: 'skill', text: '✦ '+this._getSkillName(), desc: this._getSkillDesc()+' (-3灵)' });
    }
    actions.push({ id: 'flee', text: '🏃 逃跑', desc: '50%成功' });
    return actions;
  }

  /**
   * 执行玩家动作 — v2.0 灵力/架势/连击整合
   */
  _executeAction(data) {
    if (!this.active) return;
    const action = data.action;
    if (!action) return;

    let playerDmg = 0, playerHeal = 0, enemyDmg = 0;

    // ── L2: 架势切换（不耗灵）──
    if (action.startsWith('stance_')) {
      const newStance = action.replace('stance_', '');
      this.stance = newStance;
      this._addLog(`架势切换：「${this._stanceName(newStance)}」`);
      // 架势切换后直接进入敌人回合（不浪费）
      this._enemyTurn();
      return;
    }

    // ── L1: 调息（灵力=0时唯一选项）──
    if (action === 'meditate') {
      this.qi = Math.min(this.maxQi, this.qi + 2);
      this.momentum = 0;
      this._addLog('你盘膝调息，灵力 +2。');
      this._enemyTurn(0.5); // DEF-50%
      return;
    }

    // ── 普通动作：先检查灵力 ──
    const qiCost = { attack: 1, defend: -1, skill: 3, finisher: this._getFinisher().qiCost }[action] || 0;
    if (qiCost > this.qi) {
      this._addLog('灵力不足！请调息或切换防御架势回复灵力。');
      this._triggerUpdate();
      return;
    }

    switch (action) {
      case 'attack':
        this.qi -= 1;
        playerDmg = this._calcDamage(this.player, this.enemy);
        this.enemy.hp -= playerDmg;
        this.momentum = Math.min(4, this.momentum + 1);
        this._addLog(`你发动攻击，造成 ${playerDmg} 点伤害。[势:${this.momentum}/4]`);
        this._applyLifesteal(playerDmg);
        break;

      case 'defend':
        this.qi = Math.min(this.maxQi, this.qi + 1);
        playerHeal = Math.floor(this.player.maxHp * 0.1);
        this.player.hp = Math.min(this.player.maxHp, this.player.hp + playerHeal);
        this.player._isDefending = true;
        this.momentum = 0;
        this._addLog(`你进入防御姿态，恢复 ${playerHeal} 气血，(+1灵)。`);
        break;

      case 'skill':
        this.qi -= 3;
        const skillResult = this._useSkill();
        if (skillResult.damage > 0) {
          this.enemy.hp -= skillResult.damage;
          this.momentum = Math.min(4, this.momentum + 1);
          this._addLog(`你施展 ${this._getSkillName()}，造成 ${skillResult.damage} 点伤害！[势:${this.momentum}/4]`);
          this._applyLifesteal(skillResult.damage);
        }
        if (skillResult.heal > 0) {
          this.player.hp = Math.min(this.player.maxHp, this.player.hp + skillResult.heal);
          this._addLog(`恢复了 ${skillResult.heal} 点气血。`);
        }
        break;

      case 'finisher':
        const finisher = this._getFinisher();
        this.qi -= finisher.qiCost;
        const finDmg = this._useFinisher();
        this.enemy.hp -= finDmg;
        this.momentum = 0;
        this._addLog(`💥 终结技·${finisher.name}！造成 ${finDmg} 点伤害！`);
        this._applyLifesteal(finDmg);
        break;

      case 'flee':
        if (Math.random() < 0.5) {
          this._addLog('你成功逃脱了！');
          this.active = false;
          eventBus.emit('combat:fled', { cardId: this.cardId });
          return;
        } else {
          this._addLog('逃跑失败——你被敌人缠住了！');
        }
        break;
    }

    // 检查敌人是否死亡
    if (this.enemy.hp <= 0) {
      this.enemy.hp = 0;
      this._addLog(`💀 ${this.enemy.name} 被你击败！`);
      this._victory();
      return;
    }

    // ── 敌人回合 ──
    this._enemyTurn();
  }

  /**
   * L3: 结算格挡时机
   * @param {Object} data - { quality: 'perfect'|'good'|'miss' }
   */
  _resolveBlock(data) {
    if (!this.active || this._pendingBlockDamage === undefined) return;

    const quality = data.quality || 'miss';
    let blockMult = 1.0;
    let blockMsg = '';

    switch (quality) {
      case 'perfect':
        blockMult = 0; // 完全格挡
        blockMsg = '✨ 完美格挡！毫发无伤！';
        break;
      case 'good':
        blockMult = 0.4; // 减免60%
        blockMsg = '🛡 及时格挡，减轻伤害。';
        break;
      case 'early':
        blockMult = 0.7; // 减免30%（过早）
        blockMsg = '⚡ 时机稍早，部分格挡。';
        break;
      case 'late':
        blockMult = 0.8; // 减免20%（过晚）
        blockMsg = '💨 出手稍晚，格挡不全。';
        break;
      default:
        blockMult = 1.0; // 完全失误
        blockMsg = '💥 格挡失误！受到全额伤害。';
        break;
    }

    const finalDmg = Math.floor(this._pendingBlockDamage * blockMult);
    this.player.hp -= finalDmg;
    this._addLog(blockMsg);

    if (finalDmg > 0 && this._pendingBlockSpecial) {
      this._addLog(`${this.enemy.name} 的${this.enemy.special}造成 ${finalDmg} 点伤害。`);
    } else if (finalDmg > 0) {
      this._addLog(`${this.enemy.name} 的攻击造成 ${finalDmg} 点伤害。`);
    }

    // 完美格挡 → 额外奖励
    if (quality === 'perfect') {
      this.momentum = Math.min(4, this.momentum + 2);
      this.qi = Math.min(this.maxQi, this.qi + 1);
      this._addLog(`完美格挡反击！连击势+2，灵力+1。[势:${this.momentum}/4]`);

      // ── L6: 镜返（完美格挡时反射50%伤害）──
      if (this._traits.has('镜返')) {
        const reflectDmg = Math.floor(this._pendingBlockDamage * 0.5);
        this.enemy.hp -= reflectDmg;
        this._addLog(`冰魄镜甲——镜返！反射 ${reflectDmg} 伤害给 ${this.enemy.name}。`);
        if (this.enemy.hp <= 0) {
          this.enemy.hp = 0;
          this._addLog(`💀 ${this.enemy.name} 被反射的伤害击溃！`);
          this._pendingBlockDamage = undefined;
          this._pendingBlockSpecial = undefined;
          this._victory();
          return;
        }
      }
    }

    this._pendingBlockDamage = undefined;
    this._pendingBlockSpecial = undefined;

    // 检查玩家是否死亡
    if (this.player.hp <= 0) {
      this.player.hp = 0;
      this._addLog(`💔 你被 ${this.enemy.name} 击败……`);
      this._defeat();
      return;
    }

    this._triggerUpdate();
  }

  /**
   * 敌人回合 — 含 L1 灵回 + L5 天助/魔化检测 + L3 格挡窗口
   */
  _enemyTurn(defMultOverride = null) {
    let defMult = this.player._isDefending ? 0.5 : 1.0;
    if (defMultOverride !== null) defMult = defMultOverride;
    this.player._isDefending = false;

    // ── L5: 天助一击检测（气运）──
    this._divineStrike = false;
    if (Math.random() * 100 < gameState.attributes.fortune / 100) {
      this._divineStrike = true;
    }

    // 敌人行动
    let enemyDmg = 0;

    // ── L3: 格挡时机检测 ──
    // 25%概率敌人蓄力攻击（给予格挡窗口）
    const blockChance = this.enemy.special ? 0.35 : 0.25;
    if (Math.random() < blockChance) {
      // 预计算伤害
      if (this.enemy.special && Math.random() < this.enemy.specialChance) {
        enemyDmg = Math.floor(this.enemy.atk * 1.5 * defMult) + (this.enemy.specialDmg || 0);
        enemyDmg = Math.max(1, enemyDmg - Math.floor(this.player.def * defMult));
        this._addLog(`${this.enemy.name} 蓄力——【${this.enemy.special}】！格挡窗口开启！`);
      } else {
        enemyDmg = this._calcDamage(this.enemy, this.player, defMult);
        this._addLog(`${this.enemy.name} 蓄力一击！格挡窗口开启！`);
      }
      this._pendingBlockDamage = enemyDmg;
      this._pendingBlockSpecial = this.enemy.special && Math.random() < this.enemy.specialChance;
      eventBus.emit('combat:blockOpportunity', {
        damage: enemyDmg,
        enemyName: this.enemy.name,
        special: this._pendingBlockSpecial
      });
      return; // 等待玩家格挡操作
    }

    if (this.enemy.special && Math.random() < this.enemy.specialChance) {
      enemyDmg = Math.floor(this.enemy.atk * 1.5 * defMult) + (this.enemy.specialDmg || 0);
      enemyDmg = Math.max(1, enemyDmg - Math.floor(this.player.def * defMult));
      // ── L6: 空蝉（HP<20%时自动闪避）──
      if (this._traits.has('空蝉') && this._voidDodgeReady && this.player.hp < this.player.maxHp * 0.2) {
        enemyDmg = 0;
        this._voidDodgeReady = false;
        this._addLog('虚空袈裟——空蝉！身形隐入虚空，闪避了致命攻击。');
      }
      this.player.hp -= enemyDmg;
      if (enemyDmg > 0) {
        this._addLog(`${this.enemy.name} 使用【${this.enemy.special}】，造成 ${enemyDmg} 点伤害！`);
      }
    } else {
      enemyDmg = this._calcDamage(this.enemy, this.player, defMult);
      // ── L6: 空蝉 ──
      if (this._traits.has('空蝉') && this._voidDodgeReady && this.player.hp < this.player.maxHp * 0.2) {
        enemyDmg = 0;
        this._voidDodgeReady = false;
        this._addLog('虚空袈裟——空蝉！身形隐入虚空，闪避了致命攻击。');
      }
      this.player.hp -= enemyDmg;
      if (enemyDmg > 0) {
        this._addLog(`${this.enemy.name} 攻击你，造成 ${enemyDmg} 点伤害。`);
      }
    }

    // ── L5: 魔化检测（恶业）──
    if (gameState.attributes.karmaBad > 50 && this.player.hp > 0 && this.player.hp < this.player.maxHp * 0.3) {
      if (Math.random() < 0.25) {
        this._addLog('⚠️ 恶念涌动——魔化！本回合伤害×2但道心-3');
        gameState.addAttribute('daoHeart', -3);
        this.player._demonized = true;
      }
    }

    // 检查玩家死亡
    if (this.player.hp <= 0) {
      this.player.hp = 0;
      // ── L5: 善业天谴豁免 ──
      if (gameState.attributes.karmaGood > 100 && Math.random() < 0.5) {
        this.player.hp = 1;
        this._addLog('✨ 善因庇护——天命未绝！你以1点气血存活。');
        this._endTurn();
        return;
      }
      this._addLog('你被击败了...');
      this._defeat();
      return;
    }

    this._endTurn();
  }

  _endTurn() {
    // ── L1: 灵力自动回复 ──
    let qiRegen = 1;
    if (this.stance === 'defend') qiRegen = 2;
    // ── L6: 灵涌（额外+1灵/回合）──
    if (this._traits.has('灵涌')) qiRegen += 1;
    this.qi = Math.min(this.maxQi, this.qi + qiRegen);

    // ── L6: 续命（每N回合自动回血）──
    this._combatTurnCount++;
    if (this._traits.has('续命')) {
      const treasMod = treasureSystem ? treasureSystem.getCombatModifiers() : {};
      const interval = treasMod.hpRegenInterval || 10;
      const healAmt = treasMod.hpAutoRegen || 5;
      if (this._combatTurnCount % interval === 0 && this.player.hp < this.player.maxHp) {
        this.player.hp = Math.min(this.player.maxHp, this.player.hp + healAmt);
        this._addLog(`续命珠——灵血流转，恢复 ${healAmt} 气血。`);
      }
    }

    this.turn++;
    this._addLog(`【第 ${this.turn} 回合】 灵:${this.qi}/${this.maxQi} 势:${this.momentum}/4 ${this._stanceIcon()}`);
    this._triggerUpdate();
  }

  _triggerUpdate() {
    eventBus.emit('combat:updated', {
      player: this.player,
      enemy: this.enemy,
      log: this.log,
      turn: this.turn
    });
  }

  // ── L6: 妖噬（30%吸血）──
  _applyLifesteal(damage) {
    if (!this._traits.has('妖噬')) return;
    const heal = Math.floor(damage * 0.3);
    if (heal <= 0) return;
    this.player.hp = Math.min(this.player.maxHp, this.player.hp + heal);
    this._addLog(`炼妖壶——妖噬！反哺 ${heal} 气血。`);
  }

  // ============ v2.0 架势/终结技/参数辅助方法 ============

  _stanceName(s) { return { attack:'攻·破军', defend:'守·磐石', break:'破·碎虚' }[s] || s; }
  _stanceIcon() { return { attack:'⚔', defend:'🛡', break:'💢' }[this.stance] || ''; }

  _getStanceAtkMod() {
    return { attack: 1.3, defend: 0.7, break: 1.1 }[this.stance] || 1.0;
  }
  _getStanceDefMod() {
    return { attack: 0.8, defend: 1.5, break: 1.0 }[this.stance] || 1.0;
  }
  _getStanceCritMod() {
    return this.stance === 'attack' ? 10 : 0;
  }

  /** L4: 终结技定义 */
  _getFinisher() {
    const finishers = {
      sword: { name: '万剑归宗', desc: 'ATK×3.0 无视防御', qiCost: 3, mult: 3.0, ignoreDef: true },
      spell: { name: '天雷破', desc: 'ATK×2.5 + 麻痹', qiCost: 4, mult: 2.5, paralyze: true },
      body:  { name: '金刚不坏', desc: 'ATK×2.0 + 2回合无敌', qiCost: 2, mult: 2.0, invincible: true },
      pill:  { name: '万毒噬心', desc: 'ATK×2.0 + 中毒3回合', qiCost: 3, mult: 2.0, poison: true }
    };
    return finishers[this.player.path] || finishers.sword;
  }

  _useFinisher() {
    const f = this._getFinisher();
    let dmg = f.mult * this.player.atk;
    if (f.ignoreDef) dmg = Math.max(1, dmg); // 无视防御
    else dmg = Math.max(1, dmg - this.enemy.def);
    if (this.momentum >= 4) dmg = Math.floor(dmg * 1.2);
    // L5: 天助一击
    if (this._divineStrike) { dmg = Math.floor(dmg * 1.5); this._addLog('✨ 天助一击！'); }
    // L5: 魔化
    if (this.player._demonized) { dmg = Math.floor(dmg * 2); this.player._demonized = false; }
    return dmg;
  }

  // ============ 伤害计算 v2.0 ============

  _calcDamage(attacker, defender, defMultiplier = 1.0) {
    // ── L6: 破甲（无视50%防御）──
    let effectiveDef = Math.floor(defender.def * defMultiplier);
    if (attacker === this.player && this._traits.has('破甲')) {
      effectiveDef = Math.floor(effectiveDef * 0.5);
    }
    let dmg = Math.max(1, attacker.atk - effectiveDef);

    // ── L2: 架势加成（玩家专属）──
    if (attacker === this.player) {
      dmg = Math.floor(dmg * this._getStanceAtkMod());
    }
    // ── L4: 连击势加成 ──
    if (attacker === this.player && this.momentum >= 1) {
      dmg = Math.floor(dmg * (1 + this.momentum * 0.1));
    }
    // ── L2: 防御架势减伤（玩家专属）──
    if (defender === this.player) {
      const stanceDef = this._getStanceDefMod();
      dmg = Math.floor(dmg / stanceDef); // 简化处理
    }

    // 暴击（L5: 道心加成）
    let effectiveCrit = attacker.critRate;
    if (attacker === this.player) {
      effectiveCrit += Math.floor(gameState.attributes.daoHeart / 10); // L5
      effectiveCrit += this._getStanceCritMod(); // L2: 攻架势暴击+10%
    }
    if (Math.random() * 100 < effectiveCrit) {
      dmg = Math.floor(dmg * 1.5);
      this._addLog('暴击！');
    }

    // ── L5: 天助一击（玩家攻击时）──
    if (attacker === this.player && this._divineStrike) {
      dmg = Math.floor(dmg * 1.5);
      this._addLog('✨ 天助一击——气运加身！');
    }
    // ── L5: 魔化（玩家攻击时）──
    if (attacker === this.player && attacker._demonized) {
      dmg = Math.floor(dmg * 2);
      this._addLog('🩸 恶念爆发——魔化一击！');
      attacker._demonized = false;
    }

    // 【功法被动】低气血爆发（玩家专属）
    if (attacker === this.player && attacker.hp < attacker.maxHp * 0.3) {
      let pathBonuses = {};
      if (pathSkillSystem && pathSkillSystem.getPassiveBonuses) {
        pathBonuses = pathSkillSystem.getPassiveBonuses(gameState.path) || {};
      }
      if (pathBonuses.lowHpAtkBonus) {
        dmg = Math.floor(dmg * pathBonuses.lowHpAtkBonus);
        this._addLog('气血低迷，战意爆发！');
      }
    }

    // ── L6: 先手（首击+50%）──
    if (attacker === this.player && this._traits.has('先手') && !this._hasFirstStruck) {
      dmg = Math.floor(dmg * 1.5);
      this._hasFirstStruck = true;
      this._addLog('剑心佩——先手必胜！首击+50%。');
    }
    // ── L6: 血战（HP<50%时攻击×1.5）──
    if (attacker === this.player && this._traits.has('血战') && attacker.hp < attacker.maxHp * 0.5) {
      dmg = Math.floor(dmg * 1.5);
      this._addLog('血玉扳指——血战！濒死时攻击×1.5。');
    }

    // 浮动 ±20%
    const variance = Math.floor(dmg * 0.2);
    dmg += Math.floor(Math.random() * variance * 2) - variance;

    return Math.max(1, dmg);
  }

  // ============ 功法技能 ============

  _getSkillName() {
    switch (this.player.path) {
      case 'sword': return '剑意斩';
      case 'spell': return '五行咒';
      case 'body': return '肉身冲撞';
      case 'pill': return '毒丹投掷';
      default: return '攻击';
    }
  }

  _getSkillDesc() {
    switch (this.player.path) {
      case 'sword': return '高暴击率强力一击';
      case 'spell': return '远程攻击，无视部分防御';
      case 'body': return '造成伤害同时恢复气血';
      case 'pill': return '中毒伤害 + 自身小幅恢复';
      default: return '普通技能';
    }
  }

  _useSkill() {
    let damage = 0;
    let heal = 0;

    switch (this.player.path) {
      case 'sword':
        // 剑修：必定暴击
        damage = Math.max(1, this.player.atk * 2 - this.enemy.def);
        this._addLog('剑意贯穿——暴击！');
        break;
      case 'spell':
        // 法修：无视50%防御
        damage = Math.max(1, this.player.atk * 1.5 - Math.floor(this.enemy.def * 0.5));
        break;
      case 'body':
        // 体修：伤害+回血
        damage = Math.max(1, this.player.atk * 1.3 - this.enemy.def);
        heal = Math.floor(this.player.maxHp * 0.15);
        break;
      case 'pill':
        // 丹修：毒伤 + 回血
        damage = Math.max(1, this.player.atk * 1.2 - this.enemy.def);
        heal = Math.floor(this.player.maxHp * 0.1);
        // 追加毒伤（固定值）
        const poison = Math.floor(this.enemy.maxHp * 0.05);
        damage += poison;
        this._addLog(`毒素蔓延，附加 ${poison} 点伤害。`);
        break;
    }

    return { damage, heal };
  }

  // ============ 战斗结果 ============

  _victory() {
    this.active = false;

    // 收集奖励
    const rewardText = [];
    if (this.rewards) {
      if (this.rewards.cultivation) {
        gameState.addAttribute('cultivation', this.rewards.cultivation);
        rewardText.push(`修为 +${this.rewards.cultivation}`);
      }
      if (this.rewards.spiritStone) {
        gameState.addResource('spiritStone', null, this.rewards.spiritStone);
        rewardText.push(`灵石 +${this.rewards.spiritStone}`);
      }
      if (this.rewards.pill) {
        gameState.addResource('pills', this.rewards.pill, 1);
        rewardText.push(`获得丹药：${this.rewards.pill}`);
      }
      if (this.rewards.treasure) {
        const runClock = gameState.getRunClock?.() || null;
        const life = runClock?.lifeId
          || `legacy:${Number(gameState.getLifeCount?.() ?? gameState.unlocks?.lifeCount ?? 0) || 0}`;
        const decision = Math.max(0, Number(
          gameState.getNextDecisionIndex?.()
          ?? gameState.getDecisionIndex?.()
          ?? gameState.turn
        ) || 0);
        const encounterId = String(this.rewards.encounterId || this.cardId || this.enemy?.id || this.rewards.treasure);
        const acquired = typeof treasureSystem !== 'undefined' && treasureSystem
          && typeof treasureSystem.acquire === 'function'
          ? treasureSystem.acquire(this.rewards.treasure, {
            source: 'combat_reward',
            sourceId: encounterId,
            channel: 'combat',
            // The encounter is settled before the source choice advances turn;
            // this survives a reload/replay without collapsing later combats.
            transactionId: `treasure:combat:life:${life}:decision:${decision}:encounter:${encounterId}:item:${this.rewards.treasure}`
          })
          : false;
        if (acquired) {
          rewardText.push(`获得法宝：${this.rewards.treasure}`);
        } else {
          rewardText.push(`法宝奖励未能写入：${this.rewards.treasure}`);
        }
      }
    }

    // 默认奖励
    const defaultCult = 5 + Math.floor(gameState.attributes.cultivation / 20);
    if (!this.rewards || !this.rewards.cultivation) {
      gameState.addAttribute('cultivation', defaultCult);
      rewardText.push(`修为 +${defaultCult}`);
    }

    const defaultStone = Math.floor(this.enemy.atk * 1.5);
    if (!this.rewards || !this.rewards.spiritStone) {
      gameState.addResource('spiritStone', null, defaultStone);
      rewardText.push(`灵石 +${defaultStone}`);
    }

    // 消耗寿元（战斗有代价）
    gameState.resources.lifespan -= 1;

    // 【因果种子】combatScar：战斗胜利后气血 < 30% → 种下重伤后遗症种子
    if (typeof karmaSystem !== 'undefined' && karmaSystem && this.player.hp < this.player.maxHp * 0.3) {
      karmaSystem.plantSeed({
        id: 'combatScar',
        description: `与${this.enemy.name}大战后气血亏空，落下病根。`,
        originCard: this.cardId,
        magnitude: Math.floor((this.player.maxHp * 0.3 - this.player.hp) / 5)
      });
    }

    // 【因果种子】combatGlory：击败有名敌人（有 factionId）→ 种下威名种子
    if (typeof karmaSystem !== 'undefined' && karmaSystem && this.enemy.factionId) {
      karmaSystem.plantSeed({
        id: 'combatGlory',
        description: `你击败了${this.enemy.name}，战名开始在修真界流传。`,
        originCard: this.cardId,
        magnitude: 10
      });
    }

    // 【环环相扣：Combat→Faction】战斗胜利影响势力声望
    const factionResult = this._applyFactionReputation(true);

    this._addLog(`🎉 战斗胜利！获得 ${rewardText.join('，')}`);
    if (factionResult) this._addLog(factionResult);
    eventBus.emit('combat:victory', {
      cardId: this.cardId,
      rewards: this.rewards,
      log: this.log,
      originalCard: this.originalCard
    });
  }

  _defeat() {
    this.active = false;

    // 扣除血量（玩家已在此次战斗中受伤）
    const hpLoss = Math.floor(this.player.maxHp * 0.3);
    gameState.addAttribute('health', -hpLoss);

    // 消耗额外寿元
    gameState.resources.lifespan -= 3;

    // 【环环相扣：Combat→Faction】战斗失败影响势力声望
    const factionResult = this._applyFactionReputation(false);

    this._addLog(`你战败了——损失了 ${hpLoss} 点气血和 3 年寿元。`);
    this._addLog(`你拖着伤残之躯逃离了战场...`);
    if (factionResult) this._addLog(factionResult);

    eventBus.emit('combat:defeat', {
      cardId: this.cardId,
      hpLoss: hpLoss,
      log: this.log,
      originalCard: this.originalCard
    });
  }

  // ============ 势力声望联动 ============

  /**
   * 战斗结果影响势力声望（Combat→Faction 环）
   * @param {boolean} victory — true=胜利, false=失败
   * @returns {string|null} 日志消息
   */
  _applyFactionReputation(victory) {
    if (!this.enemy || !this.enemy.factionId) return null;
    if (typeof factionSystem === 'undefined' || !factionSystem) return null;

    const factionId = this.enemy.factionId;
    const faction = factionSystem.getFaction(factionId);

    // 敌对势力列表（邪道/魔道）
    const hostileFactions = ['xuesha_sect'];

    if (victory) {
      if (hostileFactions.includes(factionId)) {
        // 击败邪道：全正道势力声望+5，血煞宗声望-10
        factionSystem.addReputation(factionId, -10);
        for (const [fid] of factionSystem.factions) {
          if (!hostileFactions.includes(fid)) {
            factionSystem.addReputation(fid, 5);
          }
        }
        return `你的战绩传遍修真界，正道各派声望+5！`;
      } else {
        // 击败正道弟子：该势力声望-3
        factionSystem.addReputation(factionId, -3);
        return `${faction ? faction.name : factionId} 对你的行为感到不满，声望-3。`;
      }
    } else {
      // 战败：各势力声望微降（流言蜚语）
      if (hostileFactions.includes(factionId)) {
        factionSystem.addReputation(factionId, -2);
      }
      // 所有正道声望微降
      for (const [fid] of factionSystem.factions) {
        if (!hostileFactions.includes(fid)) {
          factionSystem.addReputation(fid, -2);
        }
      }
      return `战败的消息传开，你的声望受损。`;
    }
  }

  // ============ 难度曲线 ============

  /**
   * 根据转世次数缩放敌人属性
   */
  _applyDifficultyScaling() {
    let diffMult = 1;
    // 尝试从 gameLogic 获取难度乘数
    if (typeof gameLogic !== 'undefined' && gameLogic && gameLogic._getDifficultyMultiplier) {
      diffMult = gameLogic._getDifficultyMultiplier();
    }

    this.enemy.hp = Math.round(this.enemy.hp * diffMult);
    this.enemy.maxHp = this.enemy.hp;
    this.enemy.atk = Math.round(this.enemy.atk * diffMult);
    this.enemy.def = Math.round(this.enemy.def * (1 + (diffMult - 1) * 0.5)); // 防御增长减半
    this.enemy.critRate = Math.min(30, Math.round(this.enemy.critRate * (1 + (diffMult - 1) * 0.3)));

    if (diffMult > 1.2) {
      this._addLog(`⚠️ 天道助力——第${typeof gameLogic !== 'undefined' && gameLogic ? gameLogic.getDifficultyLevel() : '?'}次轮回，敌人变强了！`);
    }
  }

  // ============ 工具方法 ============

  _addLog(msg) {
    this.log.push(msg);
  }

  getState() {
    if (!this.active) return null;
    return {
      player: { ...this.player },
      enemy: { ...this.enemy },
      turn: this.turn,
      log: [...this.log],
      cardId: this.cardId,
      // v2.0
      qi: this.qi,
      maxQi: this.maxQi,
      stance: this.stance,
      momentum: this.momentum
    };
  }
}

// 全局单例
const combatSystem = new CombatSystem();
