/**
 * CompanionWhisper — 羁绊耳语系统
 *
 * 每次玩家滑动选择后，当前陪伴的道侣对选择做出实时评论。
 * 同一事件类型，不同好感度阶段有不同语气/内容。
 *
 * 集成方式:
 *   game.js _applyChoice 末尾 → companionWhisper.getReaction()
 *   → ui.showCompanionBubble() 显示气泡
 *   → ui.companionHUD.react() 情绪动画
 */
class CompanionWhisper {
  constructor() {
    /** @type {Object<string, Object<string, string[]>>} 反应库: 道侣ID → 事件类型 → [低/中/高好感] */
    this._reactionDB = {
      bai_luoxuan: {
        heal: [
          '\u4f60\u53d7\u4f24\u4e86\uff1f\u6211\u56de\u53bb\u71ac\u836f\u3002',
          '\u53c2\u6c64\u4e00\u76f4\u5728\u7076\u4e0a\u6e29\u7740\u3002',
          '\u4ee5\u540e\u53d7\u4f24\u2014\u2014\u5148\u544a\u8bc9\u6211\u3002',
        ],
        cultivate: [
          '\u4fee\u70bc\u65f6\u6ce8\u610f\u7ecf\u8109\u3002',
          '\u4f60\u7684\u7075\u6c14\u8d8a\u6765\u8d8a\u7a33\u4e86\u3002',
          '\u9053\u4fa3\u4fee\u70bc\u7684\u6837\u5b50\u2014\u2014\u5f88\u597d\u770b\u3002',
        ],
        kill: [
          '\u2026\u2026\u90a3\u4e2a\u4eba\u5fc5\u987b\u6b7b\u5417\uff1f',
          '\u4f60\u662f\u5bf9\u7684\u3002\u4f46\u4e0b\u6b21\u8ba9\u6211\u5e2e\u5fd9\u3002',
          '\u6740\u4fbf\u6740\u4e86\u3002\u5929\u9053\u4e0d\u8bb0\u8fd9\u4e00\u7b14\u2014\u2014\u6211\u66ff\u4f60\u8bb0\u3002',
        ],
        save: [
          '\u4f60\u6551\u4e86\u4eba\u3002',
          '\u4f60\u662f\u597d\u4eba\u2014\u2014\u6211\u4e00\u76f4\u77e5\u9053\u3002',
          '\u4e09\u767e\u5e74\u540e\u2014\u2014\u4e16\u4eba\u4f1a\u8bb0\u5f97\u4f60\u505a\u8fc7\u4ec0\u4e48\u3002',
        ],
        breakthrough: [
          '\u606d\u559c\u3002',
          '\u4f60\u7684\u4fee\u4e3a\u53c8\u8fdb\u4e00\u6b65\u4e86\u3002',
          '\u9053\u4fa3\u2014\u2014\u6211\u4e3a\u4f60\u9ad8\u5174\u3002\u771f\u7684\u3002',
        ],
        dao_heart_gain: [
          '\u9053\u5fc3\u575a\u5b9a\u662f\u597d\u4e8b\u3002',
          '\u4f60\u7684\u9053\u2014\u2014\u8d8a\u6765\u8d8a\u6e05\u6670\u4e86\u3002',
          '\u4f60\u9009\u7684\u6bcf\u6761\u8def\u2014\u2014\u6211\u90fd\u8ddf\u968f\u3002',
        ],
        karma_bad: [
          '\u4f60\u2026\u2026\u505a\u4e86\u4ec0\u4e48\uff1f',
          '\u5929\u9053\u5728\u770b\u7740\u3002',
          '\u4e0d\u7ba1\u600e\u6837\u2014\u2014\u6211\u7ad9\u5728\u4f60\u8fd9\u8fb9\u3002',
        ],
        death_near: [
          '\u4e0d\u884c\uff01',
          '\u4f60\u4e0d\u80fd\u6b7b\u2014\u2014\u53c2\u6c64\u8fd8\u6ca1\u559d\u5b8c\u3002',
          '\u4f60\u7b54\u5e94\u8fc7\u6211\u7684\u2014\u2014\u4e09\u767e\u5e74\u4e0d\u591f\uff01',
        ],
        neutral: [
          '\u2026\u2026\u3002',
          '\u4eca\u5929\u7684\u98ce\u6709\u70b9\u51c9\u3002',
          '\u6211\u5728\u3002',
        ],
      },

      jian_linger: {
        heal: [
          '\u8fd9\u70b9\u4f24\u5c31\u558a\u75bc\uff1f',
          '\u4e0b\u6b21\u8eb2\u5feb\u70b9\u3002',
          '\u2026\u2026\u75bc\u7684\u8bdd\u5c31\u8bf4\u3002',
        ],
        cultivate: [
          '\u4eca\u5929\u7684\u5251\u8def\u8fd8\u884c\u3002',
          '\u4fee\u70bc\u8ba4\u771f\u70b9\u2014\u2014\u522b\u5077\u61d2\u3002',
          '\u4f60\u8fdb\u6b65\u4e86\u2014\u2014\u522b\u5f97\u610f\u3002',
        ],
        kill: [
          '\u5e72\u51c0\u5229\u843d\u2014\u2014\u4e0d\u9519\u3002',
          '\u8fd9\u79cd\u4eba\u4e0d\u503c\u5f97\u4f60\u810f\u5251\u3002',
          '\u6740\u5c31\u6740\u4e86\u3002\u5251\u4e0d\u4f1a\u72b9\u8c6b\u2014\u2014\u4f60\u4e5f\u4e0d\u8bb8\u3002',
        ],
        save: [
          '\u2026\u2026\u591a\u7ba1\u95f2\u4e8b\u3002',
          '\u6551\u4eba\u503c\u5f97\u3002\u4f46\u522b\u901e\u5f3a\u3002',
          '\u4f60\u5fc3\u8f6f\u7684\u6837\u5b50\u2014\u2014\u4e5f\u4e0d\u7b97\u96be\u770b\u3002',
        ],
        breakthrough: [
          '\u54fc\u2014\u2014\u8fd8\u884c\u3002',
          '\u7a81\u7834\u5c31\u597d\u3002\u522b\u9a84\u50b2\u3002',
          '\uff08\u5634\u89d2\u538b\u4e0d\u4f4f\u5730\u4e0a\u626c\uff09\u606d\u559c\u3002',
        ],
        dao_heart_gain: [
          '\u9053\u5fc3\u8fd9\u79cd\u4e1c\u897f\u2014\u2014\u81ea\u5df1\u609f\u3002',
          '\u4f60\u7684\u9053\u2014\u2014\u6bd4\u6211\u7684\u950b\u5229\u3002',
          '\u5251\u9053\u540c\u5f52\u3002\u6211\u4e0d\u4f1a\u8d70\u2014\u2014\u4f60\u4e5f\u4e0d\u8bb8\u3002',
        ],
        karma_bad: [
          '\u4f60\u60f3\u6e05\u695a\u4e86\uff1f',
          '\u5929\u9053\u5728\u7b97\u8d26\u2014\u2014\u4f60\u7b97\u5f97\u8fc7\u5b83\uff1f',
          '\u505a\u90fd\u505a\u4e86\u2014\u2014\u522b\u540e\u6094\u3002\u540e\u6094\u6ca1\u7528\u3002',
        ],
        death_near: [
          '\u4f60\u6562\uff01',
          '\u6211\u8fd8\u6ca1\u8d62\u591f\u2014\u2014\u4f60\u4e0d\u51c6\u6b7b\u3002',
          '\uff08\u62d4\u5251\uff09\u5929\u9053\u2014\u2014\u4f60\u6562\u52a8\u4ed6\u8bd5\u8bd5\u3002',
        ],
        neutral: [
          '\u2026\u2026\u3002',
          '\u6ca1\u4ec0\u4e48\u3002',
          '\u5251\u5728\u8eab\u8fb9\u3002',
        ],
      },

      mu_qinglan: {
        neutral: ['\u2026\u2026\u3002', '\u5929\u9053\u5faa\u73af\u3002', '\u7075\u6c14\u6ce2\u52a8\u2026\u2026\u5f88\u5fae\u5f31\u3002'],
        heal: ['\u8fd9\u662f\u2026\u2026\u751f\u547d\u7684\u6c14\u606f\u3002', '\u6062\u590d\u5f97\u5f88\u5feb\u3002', '\u4f60\u7684\u7075\u9b42\u2026\u2026\u6b63\u5728\u6108\u5408\u3002'],
        cultivate: ['\u7075\u6c14\u2026\u2026\u5728\u6d41\u8f6c\u3002', '\u4f60\u8ddf\u81ea\u7136\u7684\u5171\u632f\u52a0\u5f3a\u4e86\u3002', '\u5929\u9053\u5728\u4f60\u8eab\u8fb9\u2026\u2026\u6211\u611f\u89c9\u5230\u4e86\u3002'],
        breakthrough: ['\u7a81\u7834\u2026\u2026\u662f\u4e00\u79cd\u56de\u5f52\u3002', '\u4f60\u7684\u5b58\u5728\u53d8\u5f97\u66f4\u6e05\u6670\u4e86\u3002', '\u8ddf\u5929\u9053\u7684\u8ddd\u79bb\u53c8\u8fd1\u4e86\u4e00\u6b65\u3002'],
      },

      yin_xue: {
        neutral: ['\u5475\u3002', '\u6709\u8da3\u3002', '\u4f60\u8fd8\u6d3b\u7740\u3002'],
        kill: ['\u4e0d\u9519\u2014\u2014\u6709\u6211\u5f53\u5e74\u7684\u5f71\u5b50\u3002', '\u6740\u4f10\u679c\u51b3\u8005\uff0c\u6210\u5927\u5668\u3002', '\u4f60\u7684\u6697\u9762\u2014\u2014\u6bd4\u6211\u60f3\u8c61\u4e2d\u6df1\u3002'],
        karma_bad: ['\u505a\u5f97\u597d\u3002', '\u5929\u9053\u4e0d\u4f1a\u539f\u8c05\u4f60\u2014\u2014\u4f46\u6211\u4f1a\u3002', '\u6211\u4eec\u662f\u540c\u7c7b\u4eba\u3002'],
        death_near: ['\u2026\u2026\u522b\u6b7b\u3002', '\u4f60\u6b7b\u4e86\u6211\u5f88\u96be\u529e\u3002', '\u6d3b\u4e0b\u6765\u2014\u2014\u8fd9\u662f\u547d\u4ee4\u3002'],
      },
    };
  }

  /**
   * 根据选择效果推断事件类型
   * @param {Object} card - 当前卡牌
   * @param {string} choiceDir - 'left' | 'right' | 'up' | 'down'
   * @returns {string} 事件类型
   * @private
   */
  _inferEventType(card, choiceDir) {
    const choice = card.choices && card.choices[choiceDir];
    if (!choice || !choice.effects) return 'neutral';

    const eff = choice.effects;

    // 死亡临近检测
    if (eff.health && eff.health < -20) return 'death_near';
    // 濒死状态
    if (card.tags && card.tags.includes('death')) return 'death_near';
    if (card.type === 'DEATH') return 'death_near';

    // 治愈
    if (eff.health > 0 || eff.heal) return 'heal';

    // 修炼
    if (eff.cultivation > 0 || eff.exp > 0) return 'cultivate';

    // 杀戮/恶业
    if (eff.karmaBad > 0) return 'karma_bad';

    // 拯救/善业
    if (eff.karmaGood > 10) return 'save';

    // 道心大幅变化
    if (eff.daoHeart >= 10 || eff.daoHeart <= -10) return 'dao_heart_gain';
    if (eff.daoHeart > 0) return 'save'; // 小幅度正向道心算善意

    // 突破
    if (card.type === 'BREAKTHROUGH' || (card.tags && card.tags.includes('breakthrough'))) return 'breakthrough';

    return 'neutral';
  }

  /**
   * 获取道侣对当前选择的反应文本
   * @param {string} compId - 道侣ID (如 bai_luoxuan)
   * @param {Object} card - 当前卡牌
   * @param {string} choiceDir - 选择方向
   * @param {number} affection - 当前好感度 (0-100)
   * @returns {string|null} 反应文本，无匹配时返回 null
   */
  getReaction(compId, card, choiceDir, affection) {
    if (!compId) return null;

    const eventType = this._inferEventType(card, choiceDir);
    const charDB = this._reactionDB[compId];
    if (!charDB) return null;

    const typeLines = charDB[eventType];
    if (!typeLines || typeLines.length === 0) return null;

    const tier = affection < 40 ? 0 : affection < 70 ? 1 : 2;
    return typeLines[Math.min(tier, typeLines.length - 1)] || null;
  }

  /**
   * 获取道侣对特定事件类型的反应（用于 CompanionHUD.react）
   * @param {string} compId - 道侣ID
   * @param {string} eventType - 事件类型
   * @param {number} affection - 好感度
   * @returns {string|null}
   */
  getReactionByType(compId, eventType, affection) {
    const charDB = this._reactionDB[compId];
    if (!charDB) return null;

    const typeLines = charDB[eventType] || charDB['neutral'];
    if (!typeLines || typeLines.length === 0) return null;

    const tier = affection < 40 ? 0 : affection < 70 ? 1 : 2;
    return typeLines[Math.min(tier, typeLines.length - 1)] || null;
  }

  /**
   * 获取空闲对话文本（用于 CompanionHUD 随机冒泡）
   * @param {string} compId
   * @param {number} affection
   * @returns {string[]}
   */
  getIdleLines(compId, affection) {
    const db = {
      bai_luoxuan: {
        low:  ['\u53c2\u6c64\u8981\u8d81\u70ed\u2026\u2026', '\u4eca\u5929\u7684\u836f\u91c7\u597d\u4e86\u3002', '\u6d1e\u5e9c\u7684\u98ce\u6709\u70b9\u51c9\u3002'],
        mid:  ['\u4f60\u4fee\u70bc\u65f6\u6211\u5c31\u5728\u65c1\u8fb9\u3002', '\u4eca\u5929\u7684\u53c2\u6c64\u591a\u653e\u4e86\u67b8\u675e\u3002', '\u4f60\u7684\u7075\u6c14\u6bd4\u6628\u5929\u66f4\u7a33\u4e86\u3002'],
        high: ['\u9053\u4fa3\u2014\u2014\u6708\u4eae\u51fa\u6765\u4e86\u3002', '\u6211\u7684\u5c3e\u5df4\u6709\u70b9\u75d2\u3002', '\u4e09\u767e\u5e74\u2014\u2014\u591f\u957f\u4e86\u3002'],
      },
      jian_linger: {
        low:  ['\u5251\u51a2\u7684\u98ce\u8fd8\u662f\u90a3\u4e48\u51b7\u3002', '\u2026\u2026\u2026\u2026', '\u51fa\u5251\u518d\u5feb\u4e00\u70b9\u3002'],
        mid:  ['\u4eca\u5929\u7684\u5251\u8def\u2014\u2014\u8fd8\u884c\u3002', '\u6211\u4e0d\u662f\u5728\u7b49\u4f60\u3002', '\u4f60\u51fa\u5251\u6162\u4e86\u534a\u62cd\u3002'],
        high: ['\u51b0\u5fc3\u5251\u610f\u2014\u2014\u539f\u6765\u662f\u6696\u7684\u3002', '\u522b\u8d70\u592a\u8fdc\u3002', '\u6211\u5728\u5251\u51a2\u7b49\u4f60\u3002'],
      },
      mu_qinglan: {
        low:  ['\u2026\u2026', '\u5929\u5730\u6709\u7075\u3002', '\u5c71\u6c34\u4e4b\u95f4\u2026\u2026\u5927\u9053\u5728\u6d41\u8f6c\u3002'],
        mid:  ['\u4f60\u7684\u7075\u9b42\u5f88\u5e72\u51c0\u3002', '\u5929\u9053\u2026\u2026\u5728\u4f60\u8fd9\u8fb9\u3002', '\u611f\u8c22\u4f60\u2026\u2026\u8ba9\u6211\u7559\u5728\u8fd9\u91cc\u3002'],
        high: ['\u4f60\u662f\u5929\u9053\u7684\u610f\u5fd7\u3002', '\u6211\u613f\u610f\u2026\u2026\u4e3a\u4f60\u627f\u8f7d\u5929\u5730\u3002', '\u4e0d\u8981\u79bb\u5f00\u3002'],
      },
      yin_xue: {
        low:  ['\u5475\u3002', '\u8fd8\u6ca1\u6b7b\u554a\u3002', '\u65e0\u804a\u3002'],
        mid:  ['\u6709\u70b9\u610f\u601d\u3002', '\u4f60\u6bd4\u90a3\u4e9b\u5e9f\u7269\u5f3a\u3002', '\u7ee7\u7eed\u2014\u2014\u6211\u5728\u770b\u3002'],
        high: ['\u4f60\u5f88\u7279\u522b\u3002', '\u522b\u8ba9\u6211\u5931\u671b\u3002', '\u2026\u2026\u6696\u548c\u7684\u4e1c\u897f\u3002'],
      },
    };

    const charLines = db[compId];
    if (!charLines) return ['\u2026\u2026'];

    if (affection < 40) return charLines.low;
    if (affection < 70) return charLines.mid;
    return charLines.high;
  }
}

// 全局单例
const companionWhisper = new CompanionWhisper();
