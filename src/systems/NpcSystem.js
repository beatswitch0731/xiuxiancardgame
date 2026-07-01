/**
 * NpcSystem - NPC生命引擎
 *
 * 三层灵魂模型(情绪/心境/秘密) + 日程 + 台词匹配 + NPC记忆 + 赠礼公式 + 情报网络
 *
 * 通信：所有 NPC 交互通过 EventBus 与 CardSystem/GameLogic/UI 桥接。
 * 数据来源：data/npcs/core_npcs.json (通过 DataLoader 从 DATA_MODULES 加载)
 */
class NpcSystem {
  constructor() {
    /** @type {Map<string, Object>} NPC 完整数据 */
    this.npcs = new Map();
    /** @type {Object<string, string>} NPC 当前情绪 */
    this.emotions = {};
    /** @type {Object<string, string>} NPC 当前心境 */
    this.mindsets = {};
    /** @type {Object<string, string>} NPC 当前位置 */
    this.locations = {};
    /** @type {Object<string, Object>} NPC 记忆 (玩家交互历史) */
    this.memories = {};
    /** @type {Object<string, number[]>} 已解锁的秘密等级 */
    this.unlockedSecrets = {};
    /** @type {Object<string, Object>} 情绪计时器 */
    this._emotionTimers = {};
    /** @type {Object<string, number>} NPC好感度 (affection) */
    this.affections = {};
    /** @type {Object<string, number>} NPC羁绊等级 (0-5) */
    this.bonds = {};
    /** @type {Object<string, number>} NPC信任度 */
    this.trusts = {};
    /** @type {string[]} 已解锁情报 */
    this.unlockedGossip = [];

    // === NPC 交叉互动（CrossInteraction） ===
    /** @type {Map<string, Object>} npcIdA_npcIdB → relationData */
    this.npcRelations = new Map();
    /** @type {Object<string, number>} 上次交互轮数缓存（冷却） */
    this._lastCrossTurn = {};
    /** @type {Object[]} 待处理的交叉互动卡牌队列 */
    this._pendingCrossCards = [];
  }

  /**
   * 初始化：注册事件监听
   */
  init() {
    eventBus.on('npc:getPanelData', (data) => this._onGetPanelData(data));
    eventBus.on('npc:interact', (data) => this._onInteract(data));
    eventBus.on('npc:tick', () => this._tick());
    eventBus.on('npc:getEncounterCard', (data) => this._onGetEncounterCard(data));
  }

  /**
   * 加载 NPC 数据
   * @param {Object} npcData - { npcs: [...], relationships: [...], gossip: [...] }
   */
  loadData(npcData) {
    if (!npcData || !npcData.npcs) return;

    for (const npc of npcData.npcs) {
      this.npcs.set(npc.id, npc);
      // 初始化情绪/心境
      this.emotions[npc.id] = npc.defaultEmotion || '平静';
      this.mindsets[npc.id] = npc.defaultMindset || '通明';
      this.locations[npc.id] = npc.defaultLocation || '宗门';
      this.affections[npc.id] = npc.startAffection || 0;
      this.bonds[npc.id] = 0;
      this.trusts[npc.id] = npc.startTrust || 0;
      this.unlockedSecrets[npc.id] = [];
      this.memories[npc.id] = [];
      this._emotionTimers[npc.id] = 0;
    }
  }

  // ==========================================
  // 三层灵魂模型
  // ==========================================

  /**
   * 获取NPC当前情绪
   * @param {string} npcId
   * @returns {string}
   */
  getEmotion(npcId) {
    return this.emotions[npcId] || '平静';
  }

  /**
   * 设置NPC情绪（由事件驱动）
   * @param {string} npcId
   * @param {string} emotion - 平静/欣喜/忧心/愤怒/哀伤/焦虑/兴奋
   * @param {string} reason - 触发原因（记录用）
   */
  setEmotion(npcId, emotion, reason) {
    const old = this.emotions[npcId];
    this.emotions[npcId] = emotion;
    this._emotionTimers[npcId] = 5; // 情绪持续5轮

    if (old !== emotion) {
      eventBus.emit('npc:emotionChanged', {
        npcId,
        oldEmotion: old,
        newEmotion: emotion,
        reason: reason || ''
      });
    }
  }

  /**
   * 获取NPC心境
   * @param {string} npcId
   * @returns {string}
   */
  getMindset(npcId) {
    return this.mindsets[npcId] || '通明';
  }

  /**
   * 设置NPC心境
   * @param {string} npcId
   * @param {string} mindset - 通明/执念/迷茫/释然/阴沉
   */
  setMindset(npcId, mindset) {
    const old = this.mindsets[npcId];
    this.mindsets[npcId] = mindset;
    if (old !== mindset) {
      eventBus.emit('npc:mindsetChanged', { npcId, oldMindset: old, newMindset: mindset });
    }
  }

  /**
   * 解锁NPC秘密
   * @param {string} npcId
   * @param {number} level - 1/2/3
   */
  unlockSecret(npcId, level) {
    if (!this.unlockedSecrets[npcId]) this.unlockedSecrets[npcId] = [];
    if (!this.unlockedSecrets[npcId].includes(level)) {
      this.unlockedSecrets[npcId].push(level);
      eventBus.emit('npc:secretUnlocked', { npcId, level });
    }
  }

  /**
   * 检查秘密是否已解锁
   */
  isSecretUnlocked(npcId, level) {
    return (this.unlockedSecrets[npcId] || []).includes(level);
  }

  // ==========================================
  // NPC 日常情绪衰减（每轮调用）
  // ==========================================
  _tick() {
    for (const npcId of Object.keys(this._emotionTimers)) {
      if (this._emotionTimers[npcId] > 0) {
        this._emotionTimers[npcId]--;
        if (this._emotionTimers[npcId] === 0) {
          // 回归平静
          if (this.emotions[npcId] !== '平静') {
            this.setEmotion(npcId, '平静', '时间流逝');
          }
        }
      }
    }

    // === NPC 交叉互动检测（每轮 tick 调用） ===
    this._checkCrossInteractions();
  }

  // ==========================================
  // NPC 位置与日程
  // ==========================================

  /**
   * 获取NPC当前位置
   */
  getLocation(npcId) {
    return this.locations[npcId] || '未知';
  }

  /**
   * 根据游戏轮数获取NPC当前所在
   * @param {string} npcId
   * @returns {string}
   */
  getCurrentSchedule(npcId) {
    const npc = this.npcs.get(npcId);
    if (!npc || !npc.schedule) return this.getLocation(npcId);

    // 简单轮次映射：每6轮为1个"时辰"
    const period = Math.floor(gameState.turn / 6) % 6;
    const periods = ['子时', '寅时', '辰时', '午时', '申时', '戌时'];
    const loc = npc.schedule[periods[period]] || npc.defaultLocation;
    this.locations[npcId] = loc;
    return loc;
  }

  // ==========================================
  // 台词匹配引擎
  // ==========================================

  /**
   * 获取匹配的台词
   * @param {string} npcId
   * @param {string} scene - 闲聊/修炼/请教/赠礼/危机/表白
   * @param {number} affection - 好感度（可选，默认取当前值）
   * @returns {string|null}
   */
  getDialogue(npcId, scene, affection) {
    const npc = this.npcs.get(npcId);
    if (!npc || !npc.dialogues) return null;

    const aff = affection !== undefined ? affection : (this.affections[npcId] || 0);
    const mood = this.getMindset(npcId);
    const emotion = this.getEmotion(npcId);

    // 过滤：场景匹配 + 好感度匹配
    const candidates = npc.dialogues.filter(d => {
      if (d.scene !== scene && d.scene !== '通用') return false;
      if (d.minAffection !== undefined && aff < d.minAffection) return false;
      if (d.maxAffection !== undefined && aff > d.maxAffection) return false;
      if (d.mindset && d.mindset !== mood) return false;
      if (d.emotion && d.emotion !== emotion) return false;
      return true;
    });

    if (candidates.length === 0) {
      // 没有精确匹配时返回通用台词
      const fallback = npc.dialogues.find(d => d.scene === '通用');
      return fallback ? fallback.text : null;
    }

    return candidates[Math.floor(Math.random() * candidates.length)].text;
  }

  // ==========================================
  // NPC 记忆系统
  // ==========================================

  /**
   * 记录一次玩家-NPC交互
   * @param {string} npcId
   * @param {string} action - 闲聊/请教/赠礼/论道
   * @param {string} reaction - NPC反应摘要
   * @param {number} affectionDelta - 好感变化
   */
  recordInteraction(npcId, action, reaction, affectionDelta) {
    if (!this.memories[npcId]) this.memories[npcId] = [];
    this.memories[npcId].push({
      turn: gameState.turn,
      action,
      reaction,
      affectionDelta,
      timestamp: Date.now()
    });

    // 只保留最近20条
    if (this.memories[npcId].length > 20) {
      this.memories[npcId] = this.memories[npcId].slice(-20);
    }
  }

  /**
   * 获取NPC对玩家的整体印象
   * @param {string} npcId
   * @returns {Object}
   */
  getImpression(npcId) {
    const aff = this.affections[npcId] || 0;
    const bond = this.bonds[npcId] || 0;
    const trust = this.trusts[npcId] || 0;
    const memories = this.memories[npcId] || [];

    let overall = '陌路';
    if (aff >= 90 && bond >= 4) overall = '至交';
    else if (aff >= 70) overall = '亲近';
    else if (aff >= 40) overall = '友善';
    else if (aff >= 15) overall = '认识';
    else if (aff < -20) overall = '厌恶';

    return {
      overall,
      affection: aff,
      bond,
      trust,
      interactionCount: memories.length,
      lastInteraction: memories.length > 0 ? memories[memories.length - 1].turn : 0
    };
  }

  // ==========================================
  // 好感度操作
  // ==========================================

  /**
   * 调整好感度
   * @returns {number} 实际变化值
   */
  addAffection(npcId, delta) {
    const old = this.affections[npcId] || 0;
    this.affections[npcId] = Math.max(-50, Math.min(100, old + delta));

    // 好感度阈值 => 羁绊升级
    const newAff = this.affections[npcId];
    const bondThresholds = [0, 30, 55, 75, 90, 100];
    for (let i = bondThresholds.length - 1; i >= 0; i--) {
      if (newAff >= bondThresholds[i] && (this.bonds[npcId] || 0) < i) {
        this.bonds[npcId] = i;
        eventBus.emit('npc:bondUpgraded', { npcId, level: i, npcName: this.getNpcName(npcId) });
        break;
      }
    }

    eventBus.emit('npc:affectionChange', { npcId, oldValue: old, newValue: newAff });
    return newAff - old;
  }

  addTrust(npcId, delta) {
    this.trusts[npcId] = Math.max(0, Math.min(100, (this.trusts[npcId] || 0) + delta));
  }

  // ==========================================
  // 赠礼系统
  // ==========================================

  /**
   * 计算赠礼效果
   * @param {string} npcId
   * @param {string} itemId - 物品ID
   * @returns {{ delta: number, reaction: string }}
   */
  calculateGift(npcId, itemId) {
    const npc = this.npcs.get(npcId);
    if (!npc || !npc.giftPrefs) return { delta: 3, reaction: '收下了，但似乎不太在意。' };

    const baseValue = 5;
    let prefMultiplier = 1.0;
    let reaction = '收下了。';

    // 偏好匹配
    if (npc.giftPrefs.love && npc.giftPrefs.love.includes(itemId)) {
      prefMultiplier = 2.0;
      reaction = '眼中闪过一丝惊喜——这正是ta最喜欢的。';
    } else if (npc.giftPrefs.like && npc.giftPrefs.like.includes(itemId)) {
      prefMultiplier = 1.5;
      reaction = '微微点头，看起来还算满意。';
    } else if (npc.giftPrefs.hate && npc.giftPrefs.hate.includes(itemId)) {
      prefMultiplier = 0.1;
      reaction = '皱眉，似乎很不喜欢这个礼物。';
    }

    // 好感修正：关系越好收什么都香
    const affMod = 1.0 + (this.affections[npcId] || 0) / 200;

    // 性格修正
    const charMod = this._getCharacterMod(npcId);

    // 时机修正
    const timingMod = this._getTimingMod(npcId);

    const delta = Math.round(baseValue * prefMultiplier * affMod * charMod * timingMod);

    // 实际调整好感度
    this.addAffection(npcId, delta);
    this.recordInteraction(npcId, '赠礼', reaction, delta);

    return { delta, reaction };
  }

  _getCharacterMod(npcId) {
    const npc = this.npcs.get(npcId);
    if (!npc || !npc.personality) return 1.0;

    const { proud } = npc.personality; // 傲/傲娇
    if (proud >= 80) return 0.7;
    if (proud <= 30) return 1.2;
    return 1.0;
  }

  _getTimingMod(npcId) {
    const emotion = this.getEmotion(npcId);
    const mods = {
      '欣喜': 1.3,
      '愤怒': 0.5,
      '哀伤': 1.2,
      '兴奋': 1.5
    };
    return mods[emotion] || 1.0;
  }

  // ==========================================
  // NPC 遭遇卡（优先级30）
  // ==========================================

  _onGetEncounterCard(data) {
    // NPC遭遇总次数限制：每局最多6次NPC遭遇（防止泛滥）
    const totalEncounters = Object.values(this.memories)
      .reduce((sum, mems) => sum + mems.length, 0);
    if (totalEncounters >= 6) {
      eventBus.emit('npc:encounterCard', { card: null });
      return;
    }
    // 检查是否触发 NPC 遭遇，并避免重复已玩过的事件
    let attempts = 0;
    let enc = null;
    while (attempts < 5) {
      enc = this._checkEncounter();
      if (!enc) break;
      // 如果该遭遇已玩过，则尝试重新生成
      if (gameState.cardsPlayed.includes(enc.id)) {
        enc = null;
        attempts++;
        continue;
      }
      break;
    }
    if (enc) {
      eventBus.emit('npc:encounterCard', { card: enc });
    } else {
      eventBus.emit('npc:encounterCard', { card: null });
    }
  }

  /**
   * 检测是否触发NPC遭遇（概率引擎）
   */
  _checkEncounter() {
    const realm = gameState.realm;
    const availableNpcs = [];

    for (const [npcId, npc] of this.npcs) {
      // 境界要求：NPC 在此境界或更低境界可出现
      if (!npc.appearRealms || !npc.appearRealms.includes(realm)) continue;

      // 功法限制
      if (npc.pathRestriction && npc.pathRestriction !== gameState.path) continue;

      // 冷却检查：每两次遭遇至少间隔 15 轮（原8轮太短，导致重复感）
      const mem = this.memories[npcId] || [];
      if (mem.length > 0 && gameState.turn - mem[mem.length - 1].turn < 15) continue;

      availableNpcs.push(npcId);
    }

    if (availableNpcs.length === 0) return null;

    // 概率：15% 基础 × 福缘修正
    const baseChance = 0.15;
    const fortuneMod = gameState.attributes.fortune / 100;
    const chance = baseChance + fortuneMod * 0.1;

    if (Math.random() > chance) return null;

    // 随机选一个NPC
    const npcId = availableNpcs[Math.floor(Math.random() * availableNpcs.length)];
    const npc = this.npcs.get(npcId);

    return this._generateEncounterCard(npcId, npc);
  }

  /**
   * 生成 NPC 遭遇卡牌
   */
  _generateEncounterCard(npcId, npc) {
    const emotion = this.getEmotion(npcId);
    const location = this.getCurrentSchedule(npcId);
    const impression = this.getImpression(npcId);

    // 根据好感度不同，生成不同场景的遭遇卡
    const aff = this.affections[npcId] || 0;
    let scene = '偶遇';

    if (aff >= 60) scene = '重逢';
    else if (aff < 0) scene = '对峙';
    else if (impression.interactionCount === 0) scene = '初见';

    // 【环环相扣：NPC→Path】获取功法感知描述
    const pathFlavor = this._getPathFlavor(gameState.path);
    const pathComment = this._getPathComment(npcId, gameState.path);

    const encounterCards = {
      '初见': {
        title: `初见${npc.name}`,
        description: `你在${location}遇到了一位修士——${npc.title || ''}${npc.name}。${npc.firstMeeting || ''}${pathComment ? '\n\n' + pathComment : ''}`,
        choices: {
          left: { text: '恭敬行礼', effects: { daoHeart: 5 }, npcAffection: 5 },
          right: { text: '傲然以对', effects: { cultivation: 3, karmaBad: 3 }, npcAffection: -3 }
        }
      },
      '偶遇': {
        title: `偶遇${npc.name}`,
        description: `在${location}，你又一次遇到了${npc.name}。${emotion === '忧心' ? 'ta看起来心事重重。' : emotion === '欣喜' ? 'ta看起来心情不错。' : 'ta对你微微点头。'}${pathFlavor ? ' ' + pathFlavor : ''}`,
        choices: {
          left: { text: '上前问候', effects: { daoHeart: 3 }, npcAffection: 3 },
          right: { text: '匆匆离去', effects: {}, npcAffection: -1 }
        }
      },
      '重逢': {
        title: `故人${npc.name}`,
        description: `${npc.name}在${location}远远看到你，露出了一丝笑意。"最近修行如何？你的${this._getPathName()}气息更浓了。"`,
        choices: {
          left: { text: '汇报修炼所得', effects: { cultivation: 5, daoHeart: 3 }, npcAffection: 5 },
          right: { text: '请教困惑', effects: { cultivation: 8, daoHeart: -2 }, npcAffection: 8 }
        }
      },
      '对峙': {
        title: `冷遇${npc.name}`,
        description: `${npc.name}看到你，面色微沉。空气似乎也冷了几分。${pathFlavor || ''}`,
        choices: {
          left: { text: '低头避开', effects: { daoHeart: -3 }, npcAffection: 0 },
          right: { text: '直视对方', effects: { daoHeart: 5, karmaBad: 3 }, npcAffection: -5 }
        }
      }
    };

    const template = encounterCards[scene] || encounterCards['偶遇'];

    return {
      id: `npc_encounter_${npcId}_${scene}`,
      title: template.title,
      description: template.description,
      type: 'NPC_ENCOUNTER',
      realm: gameState.realm,
      npcId: npcId,
      weight: 0,
      once: true,
      choices: template.choices
    };
  }

  /**
   * 获取功法名称（中文）
   */
  _getPathName() {
    const names = { sword: '剑修', spell: '法修', body: '体修', pill: '丹修' };
    return names[gameState.path] || '修行';
  }

  /**
   * 获取功法特色描述（NPC感知到的）
   */
  _getPathFlavor(path) {
    const flavors = {
      sword: 'ta的目光在你身上停留——剑修的气息掩饰不住。',
      spell: 'ta似乎感受到了你身上流转的法力，那是法修的标记。',
      body: 'ta的视线掠过你坚实的体魄——典型的体修。',
      pill: 'ta闻到了你身上淡淡的药香，丹修的印记。'
    };
    return flavors[path] || '';
  }

  /**
   * 根据NPC性格和玩家功法生成特殊评论
   */
  _getPathComment(npcId, path) {
    const npc = this.npcs.get(npcId);
    if (!npc) return null;

    // 功法共鸣/冲突
    const pathReactions = {
      '白刃真人': { sword: '"剑修……好。青云剑宗又多了一把好剑。"', spell: '"不走剑道？可惜了。"', body: '"以肉身为剑，或许也是一条路。"', pill: '"丹修来我剑宗，可是走错门了？"' },
      '玄机真人': { sword: '"剑修……天枢道院的阵法未必适合你。"', spell: '"法修同道！天枢道院的大门为你敞开。"', body: '"体修倒是少见……不过道法自然，万法皆通。"', pill: '"丹修来天枢道院？有意思，丹道和阵道本有相通之处。"' },
      '药圣': { sword: '"剑修受伤多，丹药倒是用得上。哈哈。"', spell: '"法修不用丹药？错！法修最需要固本培元的丹药。"', body: '"体修好——体修知道肉身才是根本。"', pill: '"丹修同道！来，我这里有一炉新丹，陪我品鉴品鉴。"' },
      '天机老人': { sword: '天机老人看了你的剑一眼，若有所思。', spell: '天机老人掐指一算，微微颔首。', body: '"体修到这一步不容易啊……"天机老人罕见地露出了欣赏的神色。', pill: '"丹修逆天……比剑修还要逆天几分。"天机老人意味深长地说。' },
      '血煞老祖': { sword: '"剑修？杀伐倒是不错……"血煞老祖舔了舔嘴唇。', spell: '"法修……精于算计，跟你合作得多个心眼。"', body: '"体修！好！打起来最痛快！"血煞老祖大笑道。', pill: '"丹修……毒丹、爆丹、隐丹——嘿嘿，老夫喜欢。"' }
    };

    return (pathReactions[npc.name] && pathReactions[npc.name][path]) || null;
  }

  // ==========================================
  // 面板数据组装
  // ==========================================

  _onGetPanelData(data) {
    const npcId = data.npcId;
    const npc = this.npcs.get(npcId);
    if (!npc) {
      eventBus.emit('npc:panelData', { error: 'NPC not found' });
      return;
    }

    const emotion = this.getEmotion(npcId);
    const mindset = this.getMindset(npcId);
    const impression = this.getImpression(npcId);
    const location = this.getCurrentSchedule(npcId);

    // 解锁的秘密
    const secrets = [];
    if (npc.secrets) {
      for (const secret of npc.secrets) {
        if (this.isSecretUnlocked(npcId, secret.level)) {
          secrets.push(secret);
        }
      }
    }

    // 交互记录（最近5条）
    const recentInteractions = (this.memories[npcId] || []).slice(-5);

    // 知道的情报（如果好感度够）
    const knownInfo = [];
    if (npc.knownInfo) {
      for (const info of npc.knownInfo) {
        if (info.requiredAffection === undefined ||
            this.affections[npcId] >= info.requiredAffection) {
          knownInfo.push({ text: info.text, unlocked: true });
        } else {
          knownInfo.push({ text: '尚未知晓', unlocked: false });
        }
      }
    }

    eventBus.emit('npc:panelData', {
      npc,
      emotion,
      mindset,
      impression,
      location,
      secrets,
      recentInteractions,
      knownInfo,
      affection: this.affections[npcId] || 0,
      bond: this.bonds[npcId] || 0,
      trust: this.trusts[npcId] || 0,
      giftPrefs: npc.giftPrefs || null,
      availableActions: this._getAvailableActions(npcId, npc)
    });
  }

  /**
   * 根据好感度和境界确定可用交互
   */
  _getAvailableActions(npcId, npc) {
    const aff = this.affections[npcId] || 0;
    const realm = gameState.realm;
    const actions = ['闲聊', '告辞'];

    if (aff >= 0) actions.splice(1, 0, '赠礼');
    if (npc.teachable && aff >= 15) actions.splice(1, 0, '请教');
    if (realm !== 'qi' && aff >= 30) actions.splice(2, 0, '论道');

    return actions;
  }

  // ==========================================
  // 交互处理
  // ==========================================

  _onInteract(data) {
    const { npcId, action, itemId } = data;
    const npc = this.npcs.get(npcId);
    if (!npc) return;

    let reaction = '';
    let affDelta = 0;

    switch (action) {
      case '闲聊':
        affDelta = Math.floor(Math.random() * 6) - 1; // -1 ~ +5
        reaction = this.getDialogue(npcId, '闲聊') ||
          `${npc.name}与你闲聊了几句。`;
        this.addAffection(npcId, affDelta);
        this.recordInteraction(npcId, '闲聊', reaction, affDelta);

        // 闲聊可能解锁 Lv1 秘密
        if (this.memories[npcId].filter(m => m.action === '闲聊').length >= 3) {
          this.unlockSecret(npcId, 1);
        }

        // 好感够高可能解锁情报
        if (this.affections[npcId] >= 40 && npc.gossipTopics && Math.random() < 0.3) {
          const gossip = npc.gossipTopics[Math.floor(Math.random() * npc.gossipTopics.length)];
          if (!this.unlockedGossip.includes(gossip)) {
            this.unlockedGossip.push(gossip);
            reaction += `\n\nta不经意间透露了一些消息："${gossip}"`;
          }
        }
        break;

      case '请教':
        if (!npc.teachable) {
          reaction = `${npc.name}摆了摆手："我没什么可教你的。"`;
          break;
        }
        affDelta = 5;
        reaction = this.getDialogue(npcId, '请教') ||
          `${npc.name}悉心指点你的修行，你获益匪浅。`;
        this.addAffection(npcId, affDelta);
        this.recordInteraction(npcId, '请教', reaction, affDelta);
        // 请教给修为加成
        eventBus.emit('npc:taught', { npcId, cultivationBonus: 8 });
        break;

      case '赠礼':
        if (!itemId) {
          reaction = '你没有可赠之物。';
          break;
        }
        const giftResult = this.calculateGift(npcId, itemId);
        affDelta = giftResult.delta;
        reaction = giftResult.reaction;

        // 送对挚爱物品可能解锁 Lv2 秘密
        const npcGift = this.npcs.get(npcId);
        if (npcGift && npcGift.giftPrefs && npcGift.giftPrefs.love &&
            npcGift.giftPrefs.love.includes(itemId)) {
          if (this.bonds[npcId] >= 2) {
            this.unlockSecret(npcId, 2);
            reaction += '\n\nta看着礼物，沉默了许久，似乎在想什么往事...';
          }
        }
        break;

      case '论道':
        if (gameState.realm === 'qi') {
          reaction = '炼气期论道，尚早了些。';
          break;
        }
        affDelta = Math.floor(Math.random() * 11); // 0 ~ 10
        reaction = this.getDialogue(npcId, '论道') ||
          `与${npc.name}论道一番，豁然开朗。`;
        this.addAffection(npcId, affDelta);
        this.recordInteraction(npcId, '论道', reaction, affDelta);
        eventBus.emit('npc:discussedDao', { npcId, daoHeartBonus: 5, cultivationBonus: 5 });
        break;

      default:
        reaction = '告辞。';
    }

    eventBus.emit('npc:interactionResult', {
      npcId,
      action,
      reaction,
      affDelta,
      newAffection: this.affections[npcId] || 0
    });
  }

  // ==========================================
  // 工具方法
  // ==========================================

  getNpcName(npcId) {
    const npc = this.npcs.get(npcId);
    return npc ? npc.name : npcId;
  }

  getNpc(npcId) {
    return this.npcs.get(npcId) || null;
  }

  /**
   * 获取所有在当前境界可见的NPC列表
   * @returns {Object[]}
   */
  getVisibleNpcs() {
    const result = [];
    for (const [npcId, npc] of this.npcs) {
      if (npc.appearRealms && npc.appearRealms.includes(gameState.realm)) {
        result.push({
          id: npcId,
          name: npc.name,
          title: npc.title || '',
          emotion: this.getEmotion(npcId),
          affection: this.affections[npcId] || 0
        });
      }
    }
    return result;
  }

  /**
   * 检查道侣关系是否存在
   */
  isCompanion(npcId) {
    return gameState.hasResource('companion', npcId);
  }

  // ==========================================
  // NPC 关系矩阵（CrossInteraction）
  // ==========================================

  /**
   * 加载 NPC 关系数据
   * @param {Object} data - { relations: [...] } from npc_relations.json
   */
  loadNpcRelations(data) {
    if (!data || !data.relations) return;
    for (const rel of data.relations) {
      const key = this._relationKey(rel.npcA, rel.npcB);
      this.npcRelations.set(key, {
        affinity: rel.affinity || 0,
        history: [{ turn: 0, event: '初始关系', delta: rel.affinity || 0 }],
        status: rel.status || 'neutral',
        lastInteractionTurn: 0,
        sharedSecrets: rel.sharedSecrets || []
      });
    }
  }

  /**
   * 调整两个NPC之间的关系值
   * @param {string} npcA
   * @param {string} npcB
   * @param {number} delta
   */
  adjustNpcRelation(npcA, npcB, delta) {
    const key = this._relationKey(npcA, npcB);
    let relation = this.npcRelations.get(key);
    if (!relation) {
      relation = { affinity: 0, history: [], status: 'neutral', lastInteractionTurn: 0, sharedSecrets: [] };
      this.npcRelations.set(key, relation);
    }

    const old = relation.affinity;
    relation.affinity = Math.max(-100, Math.min(100, relation.affinity + delta));
    relation.lastInteractionTurn = gameState.turn;
    relation.history.push({ turn: gameState.turn, event: '玩家影响', delta });

    // 更新状态
    if (relation.affinity >= 50) relation.status = 'ally';
    else if (relation.affinity <= -50) relation.status = 'rival';
    else if (relation.affinity >= 20 && relation.affinity < 50) relation.status = 'ally';
    else if (relation.affinity <= -20 && relation.affinity > -50) relation.status = 'rival';
    else relation.status = 'neutral';

    if (old !== relation.affinity && typeof eventBus !== 'undefined') {
      eventBus.emit('npc:relationChanged', {
        npcA, npcB,
        oldAffinity: old,
        newAffinity: relation.affinity,
        delta
      });
    }
  }

  /**
   * 获取两个NPC之间的关系数据
   * @returns {Object} { affinity, status, history, sharedSecrets }
   */
  getNpcRelation(npcA, npcB) {
    const key = this._relationKey(npcA, npcB);
    return this.npcRelations.get(key) || { affinity: 0, status: 'neutral', history: [], lastInteractionTurn: 0, sharedSecrets: [] };
  }

  /**
   * 生成关系Map的key（按字母序确保一致性）
   * @private
   */
  _relationKey(npcA, npcB) {
    return npcA < npcB ? `${npcA}_${npcB}` : `${npcB}_${npcA}`;
  }

  // ==========================================
  // NPC 交叉互动检测
  // ==========================================

  /**
   * 每轮检测所有位置重合的NPC对，触发交叉互动
   * @private
   */
  _checkCrossInteractions() {
    // 更新所有NPC的当前位置
    const locationMap = {};
    for (const [npcId] of this.npcs) {
      const loc = this.getCurrentSchedule(npcId);
      if (!locationMap[loc]) locationMap[loc] = [];
      locationMap[loc].push(npcId);
    }

    // 检测所有pair
    for (const [loc, npcIds] of Object.entries(locationMap)) {
      if (npcIds.length < 2) continue;
      for (let i = 0; i < npcIds.length; i++) {
        for (let j = i + 1; j < npcIds.length; j++) {
          this._tryTriggerNpcInteraction(npcIds[i], npcIds[j], loc);
        }
      }
    }
  }

  /**
   * 尝试触发NPC交叉互动
   * @private
   */
  _tryTriggerNpcInteraction(npcA, npcB, location) {
    // 基础概率
    let chance = 0.15;

    // 有预设关系 → 概率翻倍
    const key = this._relationKey(npcA, npcB);
    const relation = this.npcRelations.get(key);
    if (relation && relation.affinity !== 0) {
      chance *= 1.5;
      // rival 同处一室 → 戏剧性优先
      if (relation.status === 'rival') chance *= 2.0;
    }

    // 冷却：10轮内同一对不重复
    const pairKey = this._relationKey(npcA, npcB);
    if (this._lastCrossTurn[pairKey] && gameState.turn - this._lastCrossTurn[pairKey] < 10) {
      chance *= 0.5;
    }

    // 高密聚地点修正（宗门大殿/坊市中心）
    if (location === '宗门大殿' || location === '坊市中心') {
      chance *= 1.5;
    }

    // 福缘修正
    if (gameState && gameState.attributes) {
      chance *= 1.0 + (gameState.attributes.fortune || 50) / 500;
    }

    if (Math.random() > chance) return;

    // 触发！
    this._lastCrossTurn[pairKey] = gameState.turn;

    if (relation) {
      relation.lastInteractionTurn = gameState.turn;
    }

    this._emitCrossCard(npcA, npcB, location, relation);
  }

  /**
   * 生成并发射NPC交叉卡
   * @private
   */
  _emitCrossCard(npcA, npcB, location, relation) {
    const nameA = this.getNpcName(npcA);
    const nameB = this.getNpcName(npcB);
    const aff = relation ? relation.affinity : 0;
    const status = relation ? relation.status : 'neutral';

    // 根据关系状态选择卡牌模板
    let title, description, choices;

    if (status === 'rival') {
      title = `${nameA}与${nameB}·对峙`;
      description = `${nameA}与${nameB}在${location}不期而遇。空气骤然凝滞——${Math.abs(aff) >= 50 ? '浓烈的杀意' : '无声的较量'}在两人之间涌动。\n\n你被夹在中间。`;
      choices = {
        left: { text: '挡在中间，以身为盾', effects: { heroism: 5, daoHeart: 3, [`npc_relation:${npcA}:${npcB}`]: 10 }, npcAffection: { [npcA]: 2, [npcB]: 2 } },
        right: { text: '退后一步，让他们自己解决', effects: { wisdom: 5, [`npc_relation:${npcA}:${npcB}`]: -20 }, npcAffection: { [npcA]: -1, [npcB]: -1 } }
      };
    } else if (status === 'ally' || status === 'master-disciple') {
      title = `${nameA}与${nameB}·叙旧`;
      description = `${nameA}和${nameB}在${location}相遇。${nameB}说了句什么，${nameA}罕见地笑了——你从未见过${nameA}这样的表情。`;
      choices = {
        left: { text: '上前加入他们的谈话', effects: { daoHeart: 3, wisdom: 3 }, npcAffection: { [npcA]: 3, [npcB]: 3 } },
        right: { text: '不打扰他们，远远观察', effects: { wisdom: 5 }, npcAffection: {} }
      };
    } else {
      // neutral / estranged — 微妙的对峙
      const microTensions = [
        `两人在${location}见面时，相对无言。${nameA}微微侧身，${nameB}的目光从你身上掠过——你感觉到一种说不清的张力。`,
        `${nameA}和${nameB}在${location}擦肩而过。两人都假装没看到对方——但谁都骗不了谁。`,
        `在${location}，${nameB}对${nameA}微微点头。${nameA}还以目光——不冷不热，像是第一次知道对方存在。`
      ];
      title = `问心有愧`;
      description = microTensions[Math.floor(Math.random() * microTensions.length)];
      choices = {
        left: { text: '试着缓和气氛', effects: { daoHeart: 2, [`npc_relation:${npcA}:${npcB}`]: 5 } },
        right: { text: '若无其事地走开', effects: {} }
      };
    }

    const card = {
      id: `npc_cross_${npcA}_${npcB}_${gameState.turn}`,
      type: 'NPC_CROSS',
      title,
      description,
      npcIds: [npcA, npcB],
      location,
      realm: gameState.realm,
      once: true,
      weight: 0,
      tags: ['npc_cross', 'dramatic'],
      choices
    };

    // 推入待处理队列——等待 CardSystem.draw() 在优先级31获取
    this._pendingCrossCards.push(card);
  }

  /**
   * 获取并清除待处理的交叉互动卡
   * 由 CardSystem.draw() 在优先级31调用
   * @returns {Object|null}
   */
  getPendingCrossCard() {
    if (this._pendingCrossCards.length === 0) return null;
    return this._pendingCrossCards.shift();
  }

  /**
   * 获取NPC的五维性格
   */
  getPersonality(npcId) {
    const npc = this.npcs.get(npcId);
    return npc ? npc.personality : null;
  }
}

// 全局单例
const npcSystem = new NpcSystem();
