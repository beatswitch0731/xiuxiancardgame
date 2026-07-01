/**
 * ChoiceEchoEngine - 选择延迟回响引擎
 *
 * 核心概念：玩家做出的选择被"记住"，若干轮后在合适时机回响。
 * 与 KarmaSystem 的区别：
 *   - KarmaSystem 是"因果报应"（做善得善，做恶得恶）
 *   - ChoiceEcho 是"叙事共鸣"（选择被世界记住，以情感连续性呈现）
 *
 * 回响设计原则：
 *   - 不解释：回响文本不重复当初发生了什么，只展示"现在"
 *   - 情感递进：第一次选择的信任建立 → 回响时承诺确认
 *   - 对比张力：第一次选择的天真 → 回响时的成熟视角
 *
 * 通信：通过 EventBus 发射 storynetwork:narrativeCard(priority:36) 注入卡牌流
 */
class ChoiceEchoEngine {
  constructor() {
    /** @type {Object<string, Object>} NPC → 回响模板库 */
    this.echoTemplates = {};
    /** @type {number} 最少轮次间隔才能触发回响 */
    this.MIN_TURN_GAP = 15;
  }

  /**
   * 加载回响模板数据
   * @param {Object} templates - { npcId: { echoTemplates: [...] } }
   */
  loadTemplates(templates) {
    if (!templates) return;
    for (const [npcId, data] of Object.entries(templates)) {
      this.echoTemplates[npcId] = data.echoTemplates || [];
    }
  }

  /**
   * 种下回响种子 — 每次玩家做出有意义的选择时调用
   * @param {Object} context
   * @param {number} context.turn - 当前轮数
   * @param {string} context.realm - 当时的境界
   * @param {string} context.cardId - 触发选择的卡牌ID
   * @param {string} context.choice - 'left' | 'right'
   * @param {string} context.choiceLabel - 选项文本摘要
   * @param {string} context.npcId - 关联NPC（可选）
   * @param {number} context.affection - 当时好感度（可选）
   * @param {string} context.location - 当前位置
   * @param {string} context.cardType - 卡牌类型（用于过滤回响模板）
   */
  plantEcho(context) {
    if (!context || !context.cardId) return;

    const npcId = context.npcId;
    const templates = npcId ? (this.echoTemplates[npcId] || []) : [];
    
    // 匹配模板（如果有NPC模板且条件匹配）
    let matchedTemplate = null;
    if (templates.length > 0) {
      matchedTemplate = templates.find(t => {
        if (t.triggerCardId && t.triggerCardId !== context.cardId) return false;
        if (t.triggerChoice && t.triggerChoice !== context.choice) return false;
        if (t.minAffection && (context.affection || 0) < t.minAffection) return false;
        if (t.minTurnGap && !context.turn) return false;
        return true;
      });
    }

    const echo = {
      id: `echo_${Date.now()}_${Math.floor(Math.random() * 10000)}`,
      turn: context.turn || 0,
      realm: context.realm || 'qi',
      cardId: context.cardId,
      choice: context.choice || 'left',
      choiceLabel: context.choiceLabel || '',
      context: {
        npcId: npcId || null,
        affection: context.affection || 0,
        location: context.location || '未知',
        cardType: context.cardType || 'UNKNOWN'
      },
      echoConditions: matchedTemplate ? {
        minTurnGap: matchedTemplate.minTurnGap || this.MIN_TURN_GAP,
        minAffection: matchedTemplate.minAffection || 0,
        npcAlive: matchedTemplate.npcAlive !== false,
        location: matchedTemplate.location || null,
        minRealm: matchedTemplate.minRealm || null
      } : {
        minTurnGap: this.MIN_TURN_GAP,
        minAffection: 0,
        npcAlive: !!npcId,
        location: context.location || null,
        minRealm: null
      },
      echoText: matchedTemplate ? matchedTemplate.echoText : null,
      echoChoices: matchedTemplate ? matchedTemplate.echoChoices : null,
      triggered: false
    };

    if (typeof gameState !== 'undefined' && gameState) {
      if (!gameState.choiceEchoes) gameState.choiceEchoes = [];
      gameState.choiceEchoes.push(echo);
    }
  }

  /**
   * 扫描未触发的回响 — 每轮结束调用
   * @returns {Object|null} 满足条件的回响卡，或 null
   */
  checkAndGenerate() {
    if (!gameState || !gameState.choiceEchoes) return null;

    for (const echo of gameState.choiceEchoes) {
      if (echo.triggered) continue;
      if (!this._checkConditions(echo)) continue;

      // 条件满足，生成回响卡
      const card = this._buildEchoCard(echo);
      echo.triggered = true;
      return card;
    }

    return null;
  }

  /**
   * 检查回响条件是否满足
   * @private
   */
  _checkConditions(echo) {
    const c = echo.echoConditions;
    if (!c) return false;

    const turn = gameState.turn || 0;

    // 轮次间隔检查
    if (turn - echo.turn < c.minTurnGap) return false;

    // 好感度门槛检查
    if (c.minAffection > 0 && echo.context.npcId) {
      const aff = (typeof npcSystem !== 'undefined' && npcSystem)
        ? (npcSystem.affections[echo.context.npcId] || 0)
        : 0;
      if (aff < c.minAffection) return false;
    }

    // NPC存活检查
    if (c.npcAlive && echo.context.npcId) {
      if (gameState.deadNpcs && gameState.deadNpcs.includes(echo.context.npcId)) {
        return false;
      }
    }

    // 位置匹配检查
    if (c.location && gameState.currentLocation !== c.location) return false;

    // 境界门槛检查
    if (c.minRealm) {
      const realmOrder = ['qi', 'foundation', 'golden', 'nascent', 'deity', 'tribulation'];
      const currentIdx = realmOrder.indexOf(gameState.realm);
      const minIdx = realmOrder.indexOf(c.minRealm);
      if (currentIdx < minIdx && minIdx >= 0) return false;
    }

    return true;
  }

  /**
   * 生成回响卡牌
   * @private
   */
  _buildEchoCard(echo) {
    const npcName = echo.context.npcId
      ? ((typeof npcSystem !== 'undefined' && npcSystem)
        ? (npcSystem.getNpcName(echo.context.npcId) || echo.context.npcId)
        : echo.context.npcId)
      : '';

    // 如果模板有预设文本，使用模板
    if (echo.echoText) {
      return {
        id: `echo_${echo.id}`,
        type: 'CHOICE_ECHO',
        title: `${echo.turn}轮前，你说:"${echo.choiceLabel}"`,
        description: echo.echoText,
        npcId: echo.context.npcId,
        originTurn: echo.turn,
        originChoice: echo.choiceLabel,
        once: true,
        weight: 0,
        tags: ['echo', 'memory', 'choice_echo'],
        choices: echo.echoChoices || {
          left: { text: '（沉默）', effects: {} },
          right: { text: '（沉默）', effects: {} }
        }
      };
    }

    // 没有模板 → 通用回响（轻量但有效）
    const genericEchoes = [
      `${npcName}看到你，眼神里有一丝不易察觉的温度——仿佛想起了什么。`,
      `风吹过${echo.context.location || '这里'}，${npcName}的目光在你身上停留了片刻。`,
      `你注意到${npcName}的动作比以前从容了些。时间改变了很多事，也包括你们之间的距离。`,
      `${npcName}没有开口，但你从ta的神情里读到了某种确认——就像多年前的那天一样。`
    ];

    const text = genericEchoes[Math.floor(Math.random() * genericEchoes.length)];

    return {
      id: `echo_${echo.id}`,
      type: 'CHOICE_ECHO',
      title: `${echo.turn}轮前，你选择了:"${echo.choiceLabel}"`,
      description: text,
      npcId: echo.context.npcId,
      originTurn: echo.turn,
      originChoice: echo.choiceLabel,
      once: true,
      weight: 0,
      tags: ['echo', 'memory', 'choice_echo'],
      choices: {
        left: { text: '微笑回应', effects: { daoHeart: 2 }, companionEffects: echo.context.npcId ? { id: echo.context.npcId, type: 'affection', value: 3 } : null },
        right: { text: '移开目光', effects: {}, companionEffects: null }
      }
    };
  }

  /**
   * 获取未触发的回响总数（供调试/UI使用）
   * @returns {number}
   */
  getPendingCount() {
    if (!gameState || !gameState.choiceEchoes) return 0;
    return gameState.choiceEchoes.filter(e => !e.triggered).length;
  }

  /**
   * 清理已触发的回响（每10轮调用一次，防止数组无限增长）
   */
  cleanup() {
    if (!gameState || !gameState.choiceEchoes) return;
    gameState.choiceEchoes = gameState.choiceEchoes.filter(e => !e.triggered);
  }
}

// 全局单例
const choiceEchoEngine = new ChoiceEchoEngine();
