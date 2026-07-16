/**
 * DeckCombatSystem - 杀戮尖塔式微数值打牌战斗引擎
 */
class DeckCombatSystem {
  constructor() {
    this.active = false;
    this.turn = 0;
    
    // 战斗实体
    this.player = null;
    this.enemy = null;
    
    // 微数值资源
    this.qi = 0;
    this.maxQi = 3; // 初始 3 点真元
    
    // 卡组状态
    this.masterDeck = []; // 玩家实际拥有的永久卡组
    this.drawPile = [];
    this.hand = [];
    this.discardPile = [];
    this.exhaustPile = [];
    
    // 状态层数 (如：剑意、罡气、冰寒)
    this.playerStatus = {};
    this.enemyStatus = {};
    
    this.enemyIntent = null;
    
    // 日志
    this.log = [];
  }

  init() {
    // 绑定事件
    eventBus.on('combat:start', (data) => this._start(data));
    eventBus.on('state:reset', () => this.reset());
  }

  reset() {
    this.active = false;
    this.player = null;
    this.enemy = null;
    this.turn = 0;
    this.masterDeck = [];
    this.drawPile = [];
    this.hand = [];
    this.discardPile = [];
    this.exhaustPile = [];
    this.playerStatus = {};
    this.enemyStatus = {};
    this.log = [];
  }
  
  _addLog(msg) {
    this.log.unshift(msg);
    if (this.log.length > 10) this.log.pop();
  }

  /**
   * 开始战斗
   */
  async _start(data) {
    const card = data.card;
    if (!card || !card.enemy) return;
    this.originalCard = card;

    
    // 确保数据已加载
    const cardData = await dataLoader.load('cards:battle_cards');
    if (!cardData || !cardData.battle_cards) {
       console.error("战斗卡牌数据未加载");
       return;
    }
    this.cardDB = {};
    cardData.battle_cards.forEach(c => this.cardDB[c.id] = c);
    
    this.enemyDB = {};
    if (cardData.enemies) {
        cardData.enemies.forEach(e => this.enemyDB[e.id] = e);
    }

    // 初始化玩家微数值
    // 【P1 #5 修复】读取法宝战斗加成（atk/def/critRate）
    let playerAtkMod = 0;
    let playerDefMod = 0;
    let playerCritRate = 0;
    if (typeof treasureSystem !== 'undefined' && treasureSystem) {
      const mods = treasureSystem.getCombatModifiers();
      playerAtkMod = mods.atk || 0;
      playerDefMod = mods.def || 0;
      playerCritRate = mods.critRate || 0;
    }
    this.player = {
      hp: gameState.attributes.health,
      maxHp: gameState.maxHealth || gameState.attributes.health || 10,
      daoHeart: gameState.attributes.daoHeart,
      block: 0,
      atkMod: playerAtkMod,      // 法宝攻击加成
      defMod: playerDefMod,      // 法宝防御加成
      critRate: playerCritRate   // 法宝暴击率
    };
    
    // 初始化敌人微数值 (根据类型生成极小数值)
    const enemyData = card.enemy;
    const tier = enemyData.tier || 1; // 默认 T1 小怪
    let enemyHp = enemyData.hp || (tier === 2 ? 8 : tier === 3 ? 15 : 3);
    
    // 尝试匹配特定的敌人 AI 模板
    let enemyDef = null;
    if (enemyData.id && this.enemyDB[enemyData.id]) {
        enemyDef = this.enemyDB[enemyData.id];
    } else if (enemyData.templateId && this.enemyDB[enemyData.templateId]) {
        enemyDef = this.enemyDB[enemyData.templateId];
    } else {
        if (enemyData.name && (enemyData.name.includes("妖女") || enemyData.name.includes("合欢"))) enemyDef = this.enemyDB['seductress'];
        else if (enemyData.name && (enemyData.name.includes("剑") || enemyData.name.includes("长老"))) enemyDef = this.enemyDB['sword_elder'];
        else if (enemyData.name && (enemyData.name.includes("妖") || enemyData.name.includes("兽"))) enemyDef = this.enemyDB['demon_beast'];
        else if (tier === 1) enemyDef = this.enemyDB['enemy_normal'];
        else if (tier === 2) enemyDef = this.enemyDB['enemy_charging'];
        else if (tier === 3) enemyDef = this.enemyDB['enemy_sword'];
    }
    
    this.enemy = {
      name: (enemyDef && enemyDef.name) || enemyData.name || '修仙者',
      hp: enemyHp,
      maxHp: enemyHp,
      block: 0,
      tier: tier,
      atkPower: enemyData.atk || tier,
      defPower: enemyData.def || 0,
      def: enemyDef,
      intentIndex: 0,
      factionId: enemyData.factionId || null
    };

    // 初始永久卡组：如果为空，则给基础卡组
    if (this.masterDeck.length === 0) {
      this.masterDeck = [
        'strike', 'strike', 'strike',
        'defend', 'defend', 'defend',
        'sword_intent'
      ];
    }
    
    this.active = true;
    this.turn = 0;
    this.playerStatus = {};
    this.enemyStatus = {};
    this.drawPile = [...this.masterDeck];
    this.hand = [];
    this.discardPile = [];
    this.exhaustPile = [];
    
    // 洗牌
    this._shuffle(this.drawPile);
    
    this._addLog(`你遭遇了 ${this.enemy.name}！`);
    
    // 计算基于境界的 maxQi
    const realmOrder = ['mortal', 'qi', 'foundation', 'golden', 'nascent', 'deity', 'tribulation', 'ascension'];
    let realmIdx = realmOrder.indexOf(gameState.realm);
    if (realmIdx < 0) realmIdx = 1; // 默认练气期
    
    this.maxQi = 2 + realmIdx;
    if (this.maxQi > 8) this.maxQi = 8;
    this.qi = this.maxQi;
    
    // 初始化装备被动 (武器给剑意, 防具给护盾)
    if (gameState.equipment) {
        if (gameState.equipment.weapon) {
            this._setStatus('player', 'sword_intent', 2);
            this._addLog(`装备共鸣：剑气流转，获得 2 层剑意！`);
        }
        if (gameState.equipment.armor) {
            this.player.block += 3;
            this._addLog(`装备共鸣：法袍庇佑，获得 3 点护甲！`);
        }
    }
    
    // 法宝遗物：开局效果 (在此触发)
    this._triggerRelic('combat_start');
    
    this._startTurn();
    
    // 隐藏主探索界面，显示打牌界面
    eventBus.emit('ui:showCombatScreen');
  }

  _startTurn() {
    this.turn++;
    this.qi = this.maxQi;
    
    // 清除上回合护盾 (除非有罡气)
    if (!this._hasStatus('player', 'aura')) {
        this.player.block = 0;
    } else {
        this._addLog(`【罡气】生效，保留了护盾。`);
    }
    
    // 敌人意图生成
    this._generateEnemyIntent();
    
    // 抽 5 张牌
    this._drawCards(5);
    
    this._addLog(`--- 第 ${this.turn} 回合 ---`);
    this._triggerUpdate();
  }
  
  _generateEnemyIntent() {
    if (this.enemy.def && this.enemy.def.intents) {
        // 按照配置的意图列表循环执行
        const intents = this.enemy.def.intents;
        this.enemyIntent = intents[this.enemy.intentIndex % intents.length];
        this.enemy.intentIndex++;
    } else {
        // Fallback 极简意图逻辑
        const intents = [];
        const atkVal = this.enemy.atkPower || this.enemy.tier || 1;
        if (this.enemy.tier === 1) {
           intents.push({ type: 'attack', value: atkVal, desc: `意图：攻击 (${atkVal}点伤害)` });
        } else if (this.enemy.tier === 2) {
           if (this.turn % 3 === 0) {
               intents.push({ type: 'debuff', value: 1, desc: '意图：施加负面状态' });
           } else {
               intents.push({ type: 'attack', value: atkVal, desc: `意图：攻击 (${atkVal}点伤害)` });
           }
        } else {
           intents.push({ type: 'attack', value: atkVal, desc: `意图：攻击 (${atkVal}点伤害)` });
        }
        this.enemyIntent = intents[0];
    }
  }

  _drawCards(count) {
    for (let i = 0; i < count; i++) {
        this._drawCard();
    }
  }

  _drawCard() {
    if (this.hand.length >= 5) return;
    
    if (this.drawPile.length > 0) {
        this.hand.push(this.drawPile.pop());
    } else {
      if (this.discardPile.length > 0) {
        this.drawPile = [...this.discardPile];
        this.discardPile = [];
        this._shuffle(this.drawPile);
        this.hand.push(this.drawPile.pop());
      }
    }
  }

  _shuffle(array) {
    for (let i = array.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [array[i], array[j]] = [array[j], array[i]];
    }
  }

  // === 玩家行动 ===

  playCard(handIndex, target = 'enemy') {
    if (!this.active) return false;
    if (handIndex < 0 || handIndex >= this.hand.length) return false;
    
    const cardId = this.hand[handIndex];
    const card = this.getCardDef(cardId);
    if (!card) return false;
    
    if (this.qi < card.cost) {
        this._addLog(`真元不足！需要 ${card.cost}，当前 ${this.qi}`);
        return false;
    }
    
    // 扣费并出牌
    this.qi -= card.cost;
    const playedCard = this.hand.splice(handIndex, 1)[0];
    
    if (card.flavor) {
        this._addLog(`你打出【${card.name}】：“${card.flavor}”`);
    } else {
        this._addLog(`打出：【${card.name}】`);
    }
    
    // 解析效果
    for (const effect of card.effects) {
       this._resolveEffect(effect, target, card);
    }
    
    // 触发打牌主视效
    if (card.type === 'attack') {
       eventBus.emit('combat:vfx', { type: 'slash', target: 'enemy' });
    } else if (card.type === 'skill') {
       eventBus.emit('combat:vfx', { type: 'aura', target: 'player' });
    }
    
    // 遗物联动 (例如：每回合第一张攻击牌)
    if (card.type === 'attack') {
       this._triggerRelic('play_attack');
    }
    
    // 弃牌或消耗
    if (card.exhaust) {
       this.exhaustPile.push(playedCard);
    } else {
       this.discardPile.push(playedCard);
    }
    
    // 检查敌人死亡
    if (this.enemy.hp <= 0) {
        this._victory();
        return true;
    }
    
    this._triggerUpdate();
    return true;
  }
  
  _resolveEffect(effect, target, sourceCard) {
      if (effect.type === 'damage') {
          let dmg = effect.value;
          // 【P1 #5 修复】法宝暴击
          if (this.player.critRate > 0 && Math.random() * 100 < this.player.critRate) {
            dmg = Math.floor(dmg * 1.5);
            this._addLog(`暴击！伤害提升至 ${dmg}！`);
          }
          // 剑意加成
          let swordIntent = this._getStatus('player', 'sword_intent');
          if (swordIntent > 0) {
             dmg += swordIntent;
             this._setStatus('player', 'sword_intent', 0); // 清空
             this._addLog(`剑意爆发，附加 ${swordIntent} 伤害！`);
          }
          
          this._dealDamage(this.enemy, dmg);
      }
      else if (effect.type === 'block') {
          this.player.block += effect.value;
          this._addLog(`灵气交织，你获得了 ${effect.value} 层护体罡气。`);
          eventBus.emit('combat:vfx', { type: 'shield_gain', target: 'player' });
          eventBus.emit('combat:anim', { type: 'floating_text', target: 'player', text: `+${effect.value} 🛡️`, color: '#4caf50' });
      }
      else if (effect.type === 'status') {
          let targetObj = (effect.target === 'enemy') ? 'enemy' : 'player';
          this._addStatus(targetObj, effect.statusId, effect.value);
          eventBus.emit('combat:anim', { type: 'floating_text', target: targetObj, text: `+${effect.value} ${effect.statusId}`, color: '#f1c40f' });
      }
      else if (effect.type === 'gain_qi') {
          this.qi = Math.min(this.maxQi + 5, this.qi + effect.value); // 软上限
      }
      else if (effect.type === 'backlash') {
          this._addLog(`受到反噬伤害！`);
          // 反噬造成直接伤害，无视护盾
          this.player.hp -= effect.value;
          this._checkPlayerDeath();
      }
  }

  _dealDamage(targetObj, dmg) {
      let originalDmg = dmg;
      let shieldBroken = false;

      // 【P1 #5 修复】玩家攻击时应用法宝 atk 加成
      if (targetObj === this.enemy && this.player.atkMod > 0) {
        dmg += this.player.atkMod;
        this._addLog(`法宝共鸣，伤害 +${this.player.atkMod}！`);
      }

      // 【P1 #5 修复】玩家受击时应用法宝 def 减伤
      if (targetObj === this.player && this.player.defMod > 0) {
        dmg = Math.max(0, dmg - this.player.defMod);
      }
      
      // 护盾抵消
      if (targetObj.block > 0) {
          if (targetObj.block >= dmg) {
             targetObj.block -= dmg;
             dmg = 0;
          } else {
             dmg -= targetObj.block;
             targetObj.block = 0;
             shieldBroken = true;
          }
      }
      
      const targetName = targetObj === this.player ? 'player' : 'enemy';
      const actorName = targetObj === this.player ? this.enemy.name : '你';
      const receiverName = targetObj === this.player ? '你' : this.enemy.name;
      
      if (shieldBroken) {
          this._addLog(`狂暴的灵力撕裂了${receiverName}的护体罡气！`);
          eventBus.emit('combat:vfx', { type: 'shield_break', target: targetName });
      } else if (originalDmg > 0 && dmg === 0) {
          this._addLog(`攻击轰在${receiverName}的护体灵光上，荡起阵阵涟漪，却未能破防。`);
          eventBus.emit('combat:vfx', { type: 'shield_hit', target: targetName });
      }
      
      if (dmg > 0 && targetObj === this.player && this.player.daoHeart >= 4) {
          // 道心越高，抵御伤害的概率越高 (基础 30%)
          const resistChance = 0.3 + (this.player.daoHeart - 4) * 0.1;
          if (Math.random() < resistChance) {
              dmg = Math.max(0, dmg - 1);
              this._addLog(`道心澄澈，真气流转间自动护主，化解了 1 点危机！`);
          }
      }
      
      if (dmg > 0) {
          targetObj.hp -= dmg;
          if (shieldBroken) {
              this._addLog(`余威不减，真气透体而过，令其损失 ${dmg} 点气血！`);
          } else {
              this._addLog(`招式狠狠命中，${receiverName}损失 ${dmg} 点气血！`);
          }
          eventBus.emit('combat:vfx', { type: 'impact', target: targetName });
          eventBus.emit('combat:anim', { type: 'shake', target: targetName });
          eventBus.emit('combat:anim', { type: 'floating_text', target: targetName, text: `-${dmg}`, color: '#ff4a4a' });
      } else if (originalDmg > 0) {
          eventBus.emit('combat:anim', { type: 'floating_text', target: targetName, text: `🛡️ 抵挡`, color: '#aaaaaa' });
      }
  }

  endTurn() {
      if (!this.active) return;
      
      // 弃掉手牌
      while(this.hand.length > 0) {
          this.discardPile.push(this.hand.pop());
      }
      
      // 敌人行动
      this._enemyTurn();
  }

  _enemyTurn() {
      if (!this.active) return;
      
      // 执行意图
      let actionText = this.enemyIntent.actionName || '发动攻击';
      
      if (this.enemyIntent.type === 'attack') {
          let dmg = this.enemyIntent.value || 1;
          let swordIntent = this._getStatus('enemy', 'sword_intent');
          if (swordIntent > 0) {
              dmg += swordIntent;
              this._setStatus('enemy', 'sword_intent', 0);
              this._addLog(`【${this.enemy.name}】剑意勃发，杀机毕露！`);
          }
          this._addLog(`【${this.enemy.name}】${actionText}！`);
          eventBus.emit('combat:vfx', { type: 'slash', target: 'player' });
          this._dealDamage(this.player, dmg);
      } else if (this.enemyIntent.type === 'debuff') {
          this._addLog(`【${this.enemy.name}】施加了负面状态 (未实装)。`);
      } else if (this.enemyIntent.type === 'defend') {
          this.enemy.block += (this.enemyIntent.value || 2);
          this._addLog(`【${this.enemy.name}】${actionText}，获得了 ${this.enemyIntent.value || 2} 点护盾。`);
          eventBus.emit('combat:vfx', { type: 'shield_gain', target: 'enemy' });
          eventBus.emit('combat:anim', { type: 'floating_text', target: 'enemy', text: `+${this.enemyIntent.value || 2} 🛡️`, color: '#4caf50' });
      } else if (this.enemyIntent.type === 'buff') {
          this._addLog(`【${this.enemy.name}】${actionText}。`);
          if (this.enemyIntent.statusId) {
              this._addStatus('enemy', this.enemyIntent.statusId, this.enemyIntent.value);
              eventBus.emit('combat:anim', { type: 'floating_text', target: 'enemy', text: `+${this.enemyIntent.value} ${this.enemyIntent.statusId}`, color: '#f1c40f' });
          }
      }
      
      this._checkPlayerDeath();
      
      if (this.active) {
          this._startTurn();
      }
  }

  // 获取卡牌定义（支持实时生成强化牌）
  getCardDef(cardId) {
    if (this.cardDB[cardId]) return this.cardDB[cardId];
    if (cardId.endsWith('+')) {
      const baseId = cardId.slice(0, -1);
      const baseCard = this.cardDB[baseId];
      if (baseCard) {
        // 深拷贝基础卡牌
        const upgradedCard = JSON.parse(JSON.stringify(baseCard));
        upgradedCard.id = cardId;
        upgradedCard.name = baseCard.name + '+';
        // 粗暴数值强化：伤害+3，护盾+3，消耗降低
        if (upgradedCard.cost > 1) upgradedCard.cost -= 1;
        upgradedCard.effects.forEach(eff => {
          if (eff.type === 'damage') eff.value = Math.floor(eff.value * 1.5) + 2;
          else if (eff.type === 'block') eff.value += 3;
          else if (eff.type === 'status') eff.value += 1;
        });
        this.cardDB[cardId] = upgradedCard; // 缓存生成的强化牌
        return upgradedCard;
      }
    }
    return null;
  }

  // === 状态与初始化 ===
  
  _hasStatus(who, statusId) {
      const stats = who === 'player' ? this.playerStatus : this.enemyStatus;
      return (stats[statusId] || 0) > 0;
  }
  
  _getStatus(who, statusId) {
      const stats = who === 'player' ? this.playerStatus : this.enemyStatus;
      return stats[statusId] || 0;
  }
  
  _setStatus(who, statusId, value) {
      const stats = who === 'player' ? this.playerStatus : this.enemyStatus;
      stats[statusId] = value;
  }
  
  _addStatus(who, statusId, amount) {
      const current = this._getStatus(who, statusId);
      this._setStatus(who, statusId, current + amount);
      this._addLog(`获得 ${amount} 层【${statusId}】`);
  }

  // === 法宝/遗物系统联动 ===
  
  _triggerRelic(triggerType) {
      if (typeof treasureSystem === 'undefined' || !treasureSystem) return;
      for (const treasureId of treasureSystem.owned) {
         const t = treasureSystem.treasureDB[treasureId];
         if (!t || !t.relic) continue;
         
         const rEffect = t.relic[triggerType];
         if (!rEffect) continue;
         
         // 执行遗物效果
         this._addLog(`✨【${t.name}】发光了！`);
         if (rEffect.type === 'gain_qi') {
             this.qi = Math.min(this.maxQi + 5, this.qi + rEffect.value);
         } else if (rEffect.type === 'gain_block') {
             this.player.block += rEffect.value;
         } else if (rEffect.type === 'status') {
             this._addStatus('player', rEffect.statusId, rEffect.value);
         }
         
         if (t.tianjiCost) {
             gameState.addAttribute('tianji', t.tianjiCost);
             this._addLog(`⚡ 天机暴露，天道关注了你！`);
         }
      }
  }
  
  // === 战斗结算 ===
  
  _checkPlayerDeath() {
      if (this.player.hp <= 0) {
          this.player.hp = 0;
          this.active = false;
          
          // 同步回 gameState 并触发死亡
          gameState.attributes.health = 0;
          this._addLog(`你被击败了...`);
          eventBus.emit('ui:hideCombatScreen');
          eventBus.emit('combat:defeat', { 
            originalCard: this.originalCard,
            cardId: this.originalCard?.id,
            hpLoss: Math.max(0, this.player.maxHp - this.player.hp),
            log: this.log
          });
      }
  }

  _victory() {
      this.active = false;
      this._addLog(`战斗胜利！`);
      
      // 同步剩余HP
      gameState.attributes.health = this.player.hp;
      
      // 基础战斗奖励（修为 + 灵石）
      const defaultCult = 5 + Math.floor((gameState.attributes.cultivation || 0) / 20);
      const defaultStone = Math.floor((this.enemy.atkPower || this.enemy.tier || 1) * 1.5);
      
      if (gameState.addAttribute) {
        gameState.addAttribute('cultivation', defaultCult);
      }
      if (gameState.addResource) {
        gameState.addResource('spiritStone', null, defaultStone);
      }
      this._addLog(`获得修为 +${defaultCult}，灵石 +${defaultStone}`);
      
      eventBus.emit('combat:victory', { 
        originalCard: this.originalCard,
        cardId: this.originalCard?.id,
        log: this.log
      });
      
      // 关闭 UI
      eventBus.emit('ui:hideCombatScreen');
  }

  /**
   * 逃跑（由 UI/CombatCoordinator 调用）
   */
  flee() {
      if (!this.active) return;
      this.active = false;
      this._addLog('你抓住机会逃离了战场。');
      eventBus.emit('ui:hideCombatScreen');
      eventBus.emit('combat:fled', { originalCard: this.originalCard });
  }

  /**
   * 获取当前战斗状态快照（供 CombatCoordinator / UI 读取）
   */
  getState() {
      if (!this.active) return null;
      return {
          player: this.player,
          enemy: this.enemy,
          qi: this.qi,
          maxQi: this.maxQi,
          hand: this.hand.map(id => this.getCardDef(id)),
          drawCount: this.drawPile.length,
          discardCount: this.discardPile.length,
          exhaustCount: this.exhaustPile.length,
          intent: this.enemyIntent,
          log: this.log,
          turn: this.turn
      };
  }
  
  _triggerUpdate() {
    eventBus.emit('combat:updated', {
      player: this.player,
      enemy: this.enemy,
      qi: this.qi,
      maxQi: this.maxQi,
      hand: this.hand.map(id => this.getCardDef(id)),
      drawCount: this.drawPile.length,
      discardCount: this.discardPile.length,
      exhaustCount: this.exhaustPile.length,
      intent: this.enemyIntent,
      log: this.log
    });
  }
}

// 替换全局的 combatSystem
const deckCombatSystem = new DeckCombatSystem();
// 为了兼容旧代码的事件监听绑定，我们可以先将其暴露为 deckCombatSystem
