/**
 * EffectService - 统一效果解释器
 *
 * 将原本散落在 GameLogic._applyEffects 中的硬编码 if-else 效果分支
 * 抽取为可注册 handler 的服务，新增效果类型无需修改 GameLogic。
 *
 * 当前仍通过全局单例访问外部系统（pathSkillSystem / treasureSystem / ...），
 * 在第三阶段引入依赖注入时再进行替换。
 */
class EffectService {
  constructor({ gameState, eventBus, debug = true }) {
    this.gameState = gameState;
    this.eventBus = eventBus;
    this.debug = debug;
    this.handlers = new Map();
    this._registerHandlers();
  }

  _dbg(...args) {
    if (this.debug) console.log('[EffectService]', ...args);
  }

  /**
   * 批量应用 effects
   * @param {Object} effects - 卡牌/选择的 effects 对象
   * @param {Object} context - 上下文回调：log, onNpcRelation, onCompanionActivated
   */
  apply(effects, context) {
    if (!effects || typeof effects !== 'object') {
      this._dbg('apply skipped: empty effects');
      return;
    }

    this._dbg('apply start', effects);
    for (const [key, value] of Object.entries(effects)) {
      this._applySingle(key, value, context);
    }
    this._dbg('apply end');
  }

  _applySingle(key, value, context) {
    if (key.startsWith('_')) {
      // 内部标记键，不处理
      this._dbg('skip internal key', key);
      return;
    }
    if (this.handlers.has(key)) {
      this._dbg('handle', key, value);
      this.handlers.get(key)(value, context);
    } else if (key.startsWith('npc_relation:')) {
      this._dbg('handle npc_relation', key, value);
      this._applyNpcRelation(key, value, context);
    } else {
      this._dbg('no handler for key', key);
    }
  }

  _log(msg, context) {
    if (context && typeof context.log === 'function') {
      context.log(msg);
    }
  }

  _registerHandlers() {
    // 功法选择
    this.handlers.set('path', (value) => {
      this.gameState.path = value;
    });

    // 转世标记（由 ReincarnationCoordinator 在 makeChoice 中处理）
    this.handlers.set('reincarnate', () => {});

    // 转世加成（暂存到 gameState，待转世时消费）
    this.handlers.set('reincarnation_bonus', (value, context) => {
      this.gameState._pendingReincBonus = value;
      this._log(`转世加成已记录：${value}`, context);
    });

    // 丹药
    this.handlers.set('pill', (value, context) => {
      this.gameState.addResource('pills', value, 1);
      this._log(`获得丹药：${value}`, context);
    });

    // 法宝
    this.handlers.set('treasure', (value, context) => {
      this.gameState.addResource('treasures', value, 1);
      if (typeof treasureSystem !== 'undefined' && treasureSystem) {
        treasureSystem.acquire(value);
      }
      this._log(`获得法宝：${value}`, context);
    });

    // 道侣
    this.handlers.set('companion', (value, context) => {
      this.gameState.addResource('companions', value, 1);
      this._log(`获得道侣：${value}`, context);
      if (typeof companionSystem !== 'undefined' && companionSystem) {
        companionSystem.register(value);
      }
      if (context && typeof context.onCompanionActivated === 'function') {
        context.onCompanionActivated();
      }
    });

    // 战斗牌组卡牌
    this.handlers.set('deckCard', (value, context) => {
      if (typeof deckCombatSystem !== 'undefined' && deckCombatSystem) {
        deckCombatSystem.masterDeck.push(value);
        this._log(`获得战斗卡牌：【${value}】`, context);
      }
    });

    // 移除卡牌界面（UI 回调）
    this.handlers.set('removeCard', () => {
      if (typeof ui !== 'undefined' && ui && ui.showRemoveCardScreen) {
        ui.showRemoveCardScreen();
      }
    });

    // 升级卡牌界面（UI 回调）
    this.handlers.set('upgradeCard', () => {
      if (typeof ui !== 'undefined' && ui && ui.showUpgradeCardScreen) {
        ui.showUpgradeCardScreen();
      }
    });

    // 基础属性：修为、福缘、气血、善恶因
    this.handlers.set('cultivation', (value) => this.gameState.addAttribute('cultivation', value));
    this.handlers.set('fortune', (value) => this.gameState.addAttribute('fortune', value));
    this.handlers.set('health', (value) => this.gameState.addAttribute('health', value));
    this.handlers.set('karmaGood', (value) => this.gameState.addAttribute('karmaGood', value));
    this.handlers.set('karmaBad', (value) => this.gameState.addAttribute('karmaBad', value));

    // 道心（带功法被动 daoResist 减免）
    this.handlers.set('daoHeart', (value, context) => {
      let modifiedValue = value;
      if (value < 0) {
        let daoResist = 0;
        if (typeof pathSkillSystem !== 'undefined' && pathSkillSystem && this.gameState.path) {
          const skillBonuses = pathSkillSystem.getPassiveBonuses(this.gameState.path);
          daoResist = skillBonuses.daoResist || 0;
        }
        if (daoResist > 0) {
          const reduction = Math.floor(Math.abs(value) * daoResist);
          modifiedValue = value + reduction;
          if (reduction > 0) {
            this._log(`道心通透，减轻了 ${reduction} 点道心损伤！`, context);
          }
        }
      }
      this.gameState.addAttribute('daoHeart', modifiedValue);
    });

    // 灵石（带功法被动 spiritStoneBonus 加成）
    this.handlers.set('spiritStone', (value, context) => {
      let modifiedValue = value;
      if (value > 0) {
        let spiritStoneBonus = 0;
        if (typeof pathSkillSystem !== 'undefined' && pathSkillSystem && this.gameState.path) {
          const skillBonuses = pathSkillSystem.getPassiveBonuses(this.gameState.path);
          spiritStoneBonus = skillBonuses.spiritStoneBonus || 0;
        }
        if (spiritStoneBonus > 0) {
          const bonus = Math.floor(value * spiritStoneBonus);
          modifiedValue = value + bonus;
          if (bonus > 0) {
            this._log(`道法自然，额外获得 ${bonus} 灵石！`, context);
          }
        }
      }
      this.gameState.addResource('spiritStone', null, modifiedValue);
    });

    // exp 是 cultivation 的别名
    this.handlers.set('exp', (value) => this.gameState.addAttribute('cultivation', value));

    // 寿元
    this.handlers.set('lifespan', (value) => this.gameState.addResource('lifespan', null, value));

    // 【P1 #7 修复】天机值（卡牌 effects.tianji 不再被静默忽略）
    this.handlers.set('tianji', (value, context) => {
      this.gameState.addAttribute('tianji', value);
      this._log(`天机值变化 ${value > 0 ? '+' : ''}${value}`, context);
    });

    // 拒绝天命 / 重新开局
    this.handlers.set('restart', (value, context) => {
      this._log('拒绝天命，重新开局', context);
      this.gameState.reset(true);
      eventBus.emit('game:restart', {});
    });

    // 触发终极结局（由剧情抉择卡的 effects.ending 驱动）
    this.handlers.set('ending', (value, context) => {
      const endingDescriptions = {
        ascension: '九重天劫过后，天门大开。你踏入仙庭——飞升成仙。',
        red_dust: '你放弃了飞升，选择与道侣共度余生——红尘兵解。',
        chaos: '你以碎玉为钥匙，撕开天道，自成一道——混沌真解。'
      };
      this.gameState.dead = true;
      this.gameState.deadReason = endingDescriptions[value] || '仙途圆满';
      this.gameState.unlock('ending', value);
      // 【P0 修复 #2】标记结局已触发，阻止 makeChoice 的转世逻辑吞噬结局卡
      this.gameState.setFlag('game_ended', true);
      this._log(`【终局】${this.gameState.deadReason}`, context);
      // 通知 game.js 切换到对应的结局卡
      this.eventBus.emit('game:ending', { endingType: value });
    });
  }

  _applyNpcRelation(key, value, context) {
    if (context && typeof context.onNpcRelation === 'function') {
      context.onNpcRelation(key, value);
    }
  }
}
