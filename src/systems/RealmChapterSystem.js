/**
 * RealmChapterSystem — 境界章节引擎
 * 
 * 将六个修仙境界转化为六个叙事章节，每章5个主线里程碑卡。
 * 里程碑在修为达到阈值(20/40/60/80)时强制注入，突破卡在修为100时注入。
 * 
 * 数据流：
 *   milestoneCards (加载自 chapter_milestones.json)
 *   → shouldTriggerMilestone(realm, cultivation) 检测阈值
 *   → getMilestoneCard(realm, threshold) 获取对应卡牌
 *   → game.js getCurrentCard() 优先注入
 *   → markTriggered() 标记已触发
 */

const RealmChapterSystem = (function() {
  'use strict';

  // ========== 章节定义 ==========
  const CHAPTER_DEFINITIONS = {
    qi: {
      num: 1,
      title: '凡尘初醒',
      subtitle: '灵根残缺的少年，在尘世边缘触碰仙途之门。',
      conflict: '灵根残缺 vs 求道之志',
      // FIX-5: 新手期密集反馈，每15~20修为一个里程碑
      milestones: [15, 30, 50, 70, 100]
    },
    foundation: {
      num: 2,
      title: '宗门风云',
      subtitle: '拜入仙门，在规矩与自由之间寻找自己的道。',
      conflict: '宗门规矩 vs 自由意志',
      milestones: [20, 40, 60, 80, 100]
    },
    golden: {
      num: 3,
      title: '丹心问道',
      subtitle: '金丹初成，正魔之辨、秘境之谜纷至沓来。',
      conflict: '正道路线 vs 魔道诱惑',
      // 中期：开始拉长间距，制造"修炼如行山路"感
      milestones: [20, 45, 65, 85, 100]
    },
    nascent: {
      num: 4,
      title: '碎丹成婴',
      subtitle: '元婴化形，天劫将至，宿命的齿轮开始转动。',
      conflict: '逆天而行 vs 顺天应命',
      // 元婴期：苦修感，前期慢、后期突变
      milestones: [25, 50, 70, 90, 100]
    },
    deity: {
      num: 5,
      title: '神游太虚',
      subtitle: '化神之后，上古秘辛与众生因果尽收眼底。',
      conflict: '守护苍生 vs 独善其身',
      // 化神期：大间距，强调"漫长修行后的顿悟"
      milestones: [30, 55, 75, 95, 100]
    },
    tribulation: {
      num: 6,
      title: '天劫飞升',
      subtitle: '九九雷劫降世，一念成仙、一念成灰。',
      conflict: '飞升成仙 vs 兵解重修',
      // 渡劫期：回归较短间距，最后72→100是最长一段，制造"最后一劫"的煎熬感
      milestones: [20, 38, 55, 72, 100]
    }
  };

  /**
   * FIX-5: 阈值别名映射 — 新阈值 → 旧卡牌数据中的阈值
   * 避免重命名所有 chapter_milestones.json 中的卡牌ID
   */
  const THRESHOLD_ALIASES = {
    qi:          { 15: 20, 30: 40, 50: 60, 70: 80 },
    golden:      { 45: 40, 65: 60, 85: 80 },
    nascent:     { 25: 20, 50: 40, 70: 60, 90: 80 },
    deity:       { 30: 20, 55: 40, 75: 60, 95: 80 },
    tribulation: { 38: 40, 55: 60, 72: 80 },
  };

  /**
   * 场景图 fallback 映射
   * 优先使用 chapter_milestones.json 中的 sceneImage 路径
   * 如果文件不存在，回退到映射中指定的现有图片
   */
  const SCENE_FALLBACK_MAP = {
    // 第一章：炼气期 → 用炼气期匹配卡面
    'ch_qi_20':   'assets/cards/events/scene_qi_q_start_sword.png',   // 灵根觉醒→剑种入心
    'ch_qi_40':   'assets/cards/events/scene_qi_q_cave.png',           // 初遇机缘→古洞
    'ch_qi_60':   'assets/cards/events/scene_qi_q_elder.png',          // 师承抉择→长老传道
    'ch_qi_80':   'assets/cards/events/scene_qi_q_bodyTrial.png',      // 入道试炼→淬体
    'ch_qi_100':  'assets/cards/events/scene_qi_break_qi.png',         // 突破筑基→突破场景

    // 第二章：筑基期 → 用相应氛围卡面
    'ch_foundation_20':  'assets/cards/events/scene_qi_q_elder.png',       // 拜入宗门
    'ch_foundation_40':  'assets/cards/events/scene_qi_q_demon.png',       // 师门历练→妖魔
    'ch_foundation_60':  'assets/cards/events/scene_qi_q_fellow.png',      // 门派纷争→同门
    'ch_foundation_80':  'assets/cards/events/scene_qi_q_fortune.png',     // 红尘试炼→算命
    'ch_foundation_100': 'assets/cards/events/scene_qi_break_qi.png',      // 突破金丹

    // 第三章：金丹期
    'ch_golden_20':  'assets/cards/events/scene_qi_q_cave.png',           // 金丹初成
    'ch_golden_40':  'assets/cards/events/scene_ch_golden_40_agc_g2.png', // 秘境探索→剑阵遗台
    'ch_golden_60':  'assets/cards/events/scene_qi_q_demon.png',          // 正魔抉择→妖魔
    'ch_golden_80':  'assets/cards/events/scene_qi_q_fortune.png',        // 道侣机缘→机缘
    'ch_golden_100': 'assets/cards/events/scene_qi_break_qi.png',         // 突破元婴

    // 第四章：元婴期
    'ch_nascent_20':  'assets/cards/events/scene_qi_q_spellTome.png',    // 元婴化形→功典
    'ch_nascent_40':  'assets/cards/events/scene_qi_q_demon.png',        // 天劫预兆→暗雷
    'ch_nascent_60':  'assets/cards/events/scene_qi_q_fortune.png',      // 因果清算→命运
    'ch_nascent_80':  'assets/cards/events/scene_qi_q_fellow.png',       // 宿命抉择→对峙
    'ch_nascent_100': 'assets/cards/events/scene_qi_break_qi.png',       // 突破化神

    // 第五章：化神期
    'ch_deity_20':  'assets/cards/events/scene_qi_q_cave.png',           // 化神之变
    'ch_deity_40':  'assets/cards/events/scene_qi_q_cave.png',           // 上古秘辛
    'ch_deity_60':  'assets/cards/events/scene_qi_q_demon.png',          // 世界崩塌→暗云
    'ch_deity_80':  'assets/cards/events/scene_qi_q_fellow.png',         // 众生因果
    'ch_deity_100': 'assets/cards/events/scene_qi_break_qi.png',         // 突破渡劫

    // 第六章：渡劫期
    'ch_tribulation_20':  'assets/cards/events/scene_qi_q_demon.png',        // 天劫降临→暗雷
    'ch_tribulation_40':  'assets/cards/events/scene_qi_q_demon.png',        // 九九雷劫
    'ch_tribulation_60':  'assets/cards/events/scene_qi_q_fellow.png',       // 心魔大劫→心魔
    'ch_tribulation_80':  'assets/cards/events/scene_qi_q_fortune.png',      // 最后抉择→命运岔路
    'ch_tribulation_100': 'assets/cards/events/scene_qi_ending_ascension.png' // 飞升陨落→飞升场景
  };

  /**
   * RealmChapterSystem 构造函数
   */
  function RealmChapterSystem() {
    /** @type {Object<string, Object>} 里程碑卡牌索引，按 cardId 存储 */
    this.milestoneCards = {};

    /** @type {Object<string, number[]>} 已触发的里程碑阈值，按境界索引 */
    this.triggeredMilestones = {};

    /** @type {string|null} 当前活跃章节的 realm */
    this.activeChapterRealm = null;

    /** @type {boolean} 是否已初始化 */
    this._initialized = false;
  }

  /**
   * 初始化章节系统，加载里程碑卡牌数据
   * @param {Object} milestoneData — 从 chapter_milestones.json 加载的卡牌数据 { cardId: cardObj }
   */
  RealmChapterSystem.prototype.init = function(milestoneData) {
    if (!milestoneData || typeof milestoneData !== 'object') {
      console.warn('[RealmChapterSystem] 里程碑数据为空或格式错误，章节系统将降级。');
      this._initialized = false;
      return;
    }

    this.milestoneCards = milestoneData;

    // 按境界组织索引（方便批量查询）
    this._cardsByRealm = {};
    for (const [cardId, card] of Object.entries(milestoneData)) {
      if (cardId === '_meta') continue;
      const realm = card.realm;
      if (!this._cardsByRealm[realm]) this._cardsByRealm[realm] = {};
      this._cardsByRealm[realm][card.threshold] = card;
    }

    this._initialized = true;
    console.log('[RealmChapterSystem] 已加载', Object.keys(this._cardsByRealm || {}).length, '个境界，共计',
      Object.keys(milestoneData).filter(function(k) { return k !== '_meta'; }).length, '张里程碑卡牌');
  };

  // ========== 章节信息 ==========

  /**
   * 获取境界对应的章节标题
   * @param {string} realm
   * @returns {string}
   */
  RealmChapterSystem.prototype.getChapterTitle = function(realm) {
    const ch = CHAPTER_DEFINITIONS[realm];
    if (!ch) return '未知';
    return '第' + ch.num + '章：' + ch.title;
  };

  /**
   * 获取章节编号
   * @param {string} realm
   * @returns {number}
   */
  RealmChapterSystem.prototype.getChapterNum = function(realm) {
    const ch = CHAPTER_DEFINITIONS[realm];
    return ch ? ch.num : 0;
  };

  /**
   * 获取章节完整信息
   * @param {string} realm
   * @returns {Object|null}
   */
  RealmChapterSystem.prototype.getChapterInfo = function(realm) {
    const ch = CHAPTER_DEFINITIONS[realm];
    if (!ch) return null;
    const progress = this.getProgress(realm);
    return {
      num: ch.num,
      title: ch.title,
      subtitle: ch.subtitle,
      conflict: ch.conflict,
      triggered: progress.triggered,
      total: progress.total
    };
  };

  // ========== 里程碑检测 ==========

  /**
   * 检测当前修为是否达到下一个里程碑阈值
   * @param {string} realm
   * @param {number} cultivation
   * @returns {number|null} 返回应触发的阈值，或 null 表示无需触发
   */
  RealmChapterSystem.prototype.shouldTriggerMilestone = function(realm, cultivation) {
    const ch = CHAPTER_DEFINITIONS[realm];
    if (!ch) return null;

    if (!this.triggeredMilestones[realm]) {
      this.triggeredMilestones[realm] = [];
    }

    const triggered = this.triggeredMilestones[realm];
    for (var i = 0; i < ch.milestones.length; i++) {
      var threshold = ch.milestones[i];
      if (cultivation >= threshold && triggered.indexOf(threshold) === -1) {
        return threshold;
      }
    }
    return null;
  };

  /**
   * 获取里程碑卡牌（含场景图 fallback）
   * @param {string} realm
   * @param {number} threshold
   * @returns {Object|null}
   */
  RealmChapterSystem.prototype.getMilestoneCard = function(realm, threshold, overridePath) {
    var card = null;
    // FIX-5: 先用原始阈值查，查不到再用别名映射查旧数据
    // 优先从按境界索引查询
    if (this._cardsByRealm && this._cardsByRealm[realm]) {
      card = this._cardsByRealm[realm][threshold] || null;
    }
    // 回退：按 cardId 查询
    if (!card) {
      const cardId = 'ch_' + realm + '_' + threshold;
      card = this.milestoneCards[cardId] || null;
    }
    // FIX-5: 别名回退 — 新阈值映射到旧卡牌数据
    if (!card && THRESHOLD_ALIASES[realm] && THRESHOLD_ALIASES[realm][threshold]) {
      var oldThreshold = THRESHOLD_ALIASES[realm][threshold];
      if (this._cardsByRealm && this._cardsByRealm[realm]) {
        card = this._cardsByRealm[realm][oldThreshold] || null;
      }
      if (!card) {
        var oldCardId = 'ch_' + realm + '_' + oldThreshold;
        card = this.milestoneCards[oldCardId] || null;
      }
      if (card) {
        // 克隆卡牌并更新阈值字段，使UI显示正确
        card = Object.assign({}, card, { threshold: threshold, _aliasedFrom: oldThreshold });
      }
    }

    if (!card) return null;

    // 动态流派文本与选项适配（体修/剑修/法修/丹修）
    var gs = (typeof gameState !== 'undefined' && gameState) ? gameState : (typeof window !== 'undefined' && window.gameState ? window.gameState : (typeof globalThis !== 'undefined' && globalThis.gameState ? globalThis.gameState : null));
    var playerPath = overridePath || (gs && gs.path ? gs.path : 'sword');
    card = _adaptCardForPath(card, playerPath);
    if (!card) return null;
    card = _attachBossJourneyStage(this, card, realm, threshold);
    card = _attachNarrativeSpineContext(card);

    // sceneImage fallback: 如果文件不存在，用映射中的图片
    if (card.sceneImage) {
      // 浏览器端检查（Node.js 环境用 fs.existsSync 不可用）
      var cardId = 'ch_' + realm + '_' + threshold;
      if (SCENE_FALLBACK_MAP[cardId]) {
        card._sceneImageFallback = SCENE_FALLBACK_MAP[cardId];
        card._sceneImageOriginal = card.sceneImage;
      } else if (card._aliasedFrom) {
        // FIX-5: 别名卡牌用旧阈值查fallback
        var oldCardId = 'ch_' + realm + '_' + card._aliasedFrom;
        if (SCENE_FALLBACK_MAP[oldCardId]) {
          card._sceneImageFallback = SCENE_FALLBACK_MAP[oldCardId];
          card._sceneImageOriginal = card.sceneImage;
        }
      }
    }

    return card;
  };

  /**
   * 将终局 Boss 的劫兆旅程投射到本境界各里程碑。
   * 终局卡是权威生产者；前期卡只消费对应阶段，避免复制后出现文案/机制漂移。
   */
  function _attachBossJourneyStage(system, card, realm, requestedThreshold) {
    if (!system || !card || !realm) return card;
    var bossCard = system._cardsByRealm
      && system._cardsByRealm[realm]
      && system._cardsByRealm[realm][100];
    var journey = bossCard && bossCard.bossJourney;
    if (!journey || !journey.stages) return card;

    var canonicalThreshold = card._aliasedFrom || card.threshold || requestedThreshold;
    var stage = journey.stages[String(canonicalThreshold)];
    if (!stage) return card;

    var projected = JSON.parse(JSON.stringify(card));
    projected.bossJourneyStage = Object.assign({
      journeyId: journey.id,
      bossName: journey.bossName,
      strengthModel: journey.strengthModel,
      scalesWithPlayerRealm: journey.scalesWithPlayerRealm,
      canonicalThreshold: Number(canonicalThreshold),
      triggerThreshold: Number(requestedThreshold)
    }, JSON.parse(JSON.stringify(stage)));
    if (stage.cue && projected.description && projected.description.indexOf(stage.cue) === -1) {
      projected.description += '\n\n' + stage.cue;
    }
    return projected;
  }

  /**
   * A chapter spine is authored on the card, but provenance remains owned by
   * NarrativeLedger.  Project a read-only echo at presentation time so an old
   * market receipt can inform a later chapter without becoming a new reward or
   * a second settlement opportunity.
   */
  function _attachNarrativeSpineContext(card) {
    if (!card || !card.narrativeSpine) return card;
    var projected = JSON.parse(JSON.stringify(card));
    var ledger = typeof narrativeLedger !== 'undefined' ? narrativeLedger
      : (typeof globalThis !== 'undefined' ? globalThis.narrativeLedger : null);
    var spine = projected.narrativeSpine;
    if (!ledger) return projected;
    if (spine.threadId === 'qi_ask_sword') {
    var originTypes = ['sword_origin_licensed', 'sword_origin_traded', 'sword_origin_ghost_oath'];
    var observations = typeof ledger.getObservedFacts === 'function'
      ? ledger.getObservedFacts({
        consumerId: 'qi_main_origin_observation',
        vendorId: 'chapter_qi',
        factTypeIds: originTypes
      })
      : [];
    spine.observedOrigins = observations.map(function(entry) {
      return { factTypeId: entry.factTypeId, status: entry.status };
    });
    if (Number(spine.step) === 3) {
      var echoMap = {
        sword_origin_licensed: '官坊印记与流转号仍在：这把剑曾被明码交付。',
        sword_origin_traded: '集市札记的折痕仍在：这把剑曾在旧主与摊主之间易手。',
        sword_origin_ghost_oath: '雾中夜契的余温仍在：这把剑曾以寿契记名。'
      };
      var echo = observations.map(function(entry) { return echoMap[entry.factTypeId]; }).filter(Boolean)[0]
        || '这一世未曾留下残剑来历；问剑只能照见你自己立下的气机。';
      projected.description = (projected.description || '') + '\n\n【来历回声】' + echo;
    }
    if (Number(spine.step) === 5) {
      var stance = typeof ledger.getFactByType === 'function' ? ledger.getFactByType('qi_sword_master_stance') : null;
      var stanceId = stance?.status === 'active' ? stance.payload?.stance : null;
      var settlementOriginMap = {
        sword_origin_licensed: '曾在坊市凭官印收下这把残剑',
        sword_origin_traded: '曾在集市承下这把残剑与旧主札记',
        sword_origin_ghost_oath: '曾在鬼市以夜契为这把残剑记名'
      };
      var settlementOrigin = observations.map(function(entry) {
        return settlementOriginMap[entry.factTypeId];
      }).filter(Boolean)[0] || '未以残剑来历替自己回答这一问';
      if (stanceId === 'guarded' || stanceId === 'advance') {
        projected.combatRules = Object.assign({}, projected.combatRules || {}, {
          narrativeStance: stanceId === 'guarded'
            ? { id: 'guarded', openingBlock: 1 }
            : { id: 'advance', firstDamagingLightningReduction: 1 }
        });
        spine.stance = stanceId;
        projected.description = (projected.description || '') + (stanceId === 'guarded'
          ? '\n\n【问剑清算】因你' + settlementOrigin + '，且在剑主前立下守势；雷劫开场获得 1 点护盾。'
          : '\n\n【问剑清算】因你' + settlementOrigin + '，且在剑主前选择进势；第一道有效雷击伤害 -1。');
      }
    }
    }
    var presentation = spine.presentation && typeof spine.presentation === 'object'
      ? spine.presentation
      : null;
    var specification = presentation?.echo || presentation?.settlement || null;
    var summary = _buildNarrativeSpinePresentation(ledger, specification);
    if (summary && projected.description && projected.description.indexOf(summary) === -1) {
      projected.description += '\n\n' + summary;
    }
    return projected;
  }

  /**
   * Keep player-facing chapter echoes authored in card data.  The projection
   * reads this-life Ledger records (including already-settled predecessors)
   * without creating an observer receipt, reopening a fact, or touching Flow.
   */
  function _buildNarrativeSpinePresentation(ledger, specification) {
    if (!ledger || !specification || typeof specification !== 'object') return '';
    var marker = typeof specification.marker === 'string' ? specification.marker.trim() : '';
    var segments = Array.isArray(specification.segments) ? specification.segments : [];
    if (!marker || !segments.length) return '';
    var phrases = segments.map(function(segment) {
      if (!segment || typeof segment !== 'object' || typeof segment.factTypeId !== 'string') return '';
      var fact = typeof ledger.getFactByType === 'function'
        ? ledger.getFactByType(segment.factTypeId)
        : null;
      var payloadKey = typeof segment.payloadKey === 'string' ? segment.payloadKey : '';
      var value = payloadKey && fact?.payload ? fact.payload[payloadKey] : null;
      var variants = segment.variants && typeof segment.variants === 'object' ? segment.variants : {};
      return typeof variants[value] === 'string' ? variants[value].trim() : '';
    }).filter(Boolean);
    if (!phrases.length) return '';
    var prefix = typeof specification.prefix === 'string' ? specification.prefix : '';
    var separator = typeof specification.separator === 'string' ? specification.separator : '；';
    var suffix = typeof specification.suffix === 'string' ? specification.suffix : '';
    return marker + prefix + phrases.join(separator) + suffix;
  }

  /**
   * 动态按玩家流派适配里程碑卡文案与选项
   */
  function _adaptCardForPath(card, path) {
    if (!card || !path) return card;
    var adapted = JSON.parse(JSON.stringify(card));
    var variants = adapted.pathVariants;
    if (!variants) return adapted;
    var variant = variants[path];
    var directions = ['left', 'right'];
    var valid = variant
      && variant.realm === adapted.realm
      && variant.path === path
      && variant.text && variant.text.title && variant.text.description && variant.text.choices
      && variant.rules && variant.rules.identityTag === 'path:' + path
      && variant.rewards && variant.causal
      && variant.scene && variant.scene.image && variant.scene.location
      && Array.isArray(variant.consumers)
      && directions.every(function(direction) {
        return variant.text.choices[direction]
          && variant.text.choices[direction].text
          && variant.rewards[direction]
          && variant.rewards[direction].effects
          && variant.causal[direction]
          && variant.causal[direction].realm === adapted.realm
          && variant.causal[direction].path === path;
      });
    if (!valid) {
      console.error('[RealmChapterSystem] 非法流派变体，拒绝发放基础卡:', adapted.id, path);
      return null;
    }

    adapted.title = variant.text.title;
    adapted.description = variant.text.description;
    adapted.path = path;
    adapted.location = variant.scene.location;
    adapted.sceneImage = variant.scene.image;
    adapted.tags = Array.from(new Set((adapted.tags || []).concat([
      'milestone', 'realm:' + adapted.realm, variant.rules.identityTag
    ])));
    adapted.choices = adapted.choices || {};
    directions.forEach(function(direction) {
      var text = variant.text.choices[direction];
      adapted.choices[direction] = Object.assign({}, adapted.choices[direction] || {}, {
        text: text.text,
        desc: text.desc || '',
        effects: JSON.parse(JSON.stringify(variant.rewards[direction].effects)),
        karmaSeed: JSON.parse(JSON.stringify(variant.causal[direction]))
      });
    });
    adapted._pathVariant = {
      sourceCardId: adapted.id,
      realm: variant.realm,
      path: variant.path,
      identityTag: variant.rules.identityTag,
      consumers: variant.consumers.slice()
    };
    delete adapted.pathVariants;
    return adapted;
  }

  /**
   * 标记里程碑已触发
   * @param {string} realm
   * @param {number} threshold
   */
  RealmChapterSystem.prototype.markTriggered = function(realm, threshold) {
    if (!this.triggeredMilestones[realm]) {
      this.triggeredMilestones[realm] = [];
    }
    if (this.triggeredMilestones[realm].indexOf(threshold) === -1) {
      this.triggeredMilestones[realm].push(threshold);
    }
  };

  /**
   * Export only durable chapter facts. Card definitions remain owned by the
   * data loader; the snapshot carries the consumed milestone thresholds.
   */
  RealmChapterSystem.prototype.exportProgress = function() {
    var triggeredMilestones = {};
    Object.keys(CHAPTER_DEFINITIONS).forEach(function(realm) {
      var allowed = CHAPTER_DEFINITIONS[realm].milestones || [];
      var current = Array.isArray(this.triggeredMilestones[realm])
        ? this.triggeredMilestones[realm]
        : [];
      triggeredMilestones[realm] = current
        .map(function(value) { return Number(value); })
        .filter(function(value, index, values) {
          return Number.isFinite(value)
            && allowed.indexOf(value) !== -1
            && values.indexOf(value) === index;
        });
    }, this);
    return {
      version: 1,
      activeChapterRealm: typeof this.activeChapterRealm === 'string'
        ? this.activeChapterRealm
        : null,
      triggeredMilestones: triggeredMilestones
    };
  };

  /**
   * Hydrate durable chapter facts after card definitions have been loaded.
   * Unknown realms/thresholds are discarded instead of creating ghost
   * progress that the chapter data cannot explain.
   */
  RealmChapterSystem.prototype.hydrateProgress = function(snapshot) {
    if (!snapshot || typeof snapshot !== 'object') return false;
    var incoming = snapshot.triggeredMilestones;
    if (!incoming || typeof incoming !== 'object' || Array.isArray(incoming)) return false;
    var restored = {};
    Object.keys(CHAPTER_DEFINITIONS).forEach(function(realm) {
      var allowed = CHAPTER_DEFINITIONS[realm].milestones || [];
      var values = Array.isArray(incoming[realm]) ? incoming[realm] : [];
      restored[realm] = values
        .map(function(value) { return Number(value); })
        .filter(function(value, index, all) {
          return Number.isFinite(value)
            && allowed.indexOf(value) !== -1
            && all.indexOf(value) === index;
        });
    });
    this.triggeredMilestones = restored;
    this.activeChapterRealm = typeof snapshot.activeChapterRealm === 'string'
      && CHAPTER_DEFINITIONS[snapshot.activeChapterRealm]
      ? snapshot.activeChapterRealm
      : null;
    return true;
  };

  /**
   * 获取章节进度
   * @param {string} realm
   * @returns {{ triggered: number, total: number }}
   */
  RealmChapterSystem.prototype.getProgress = function(realm) {
    const total = CHAPTER_DEFINITIONS[realm] ? CHAPTER_DEFINITIONS[realm].milestones.length : 5;
    const triggered = this.triggeredMilestones[realm]
      ? this.triggeredMilestones[realm].length
      : 0;
    return { triggered: triggered, total: total };
  };

  /**
   * 获取进度百分比
   * @param {string} realm
   * @returns {number} 0-1
   */
  RealmChapterSystem.prototype.getProgressRatio = function(realm) {
    const p = this.getProgress(realm);
    return p.total > 0 ? p.triggered / p.total : 0;
  };

  // ========== 遍历 ==========

  /**
   * 获取所有章节定义（用于 UI 等需要全区遍历的场景）
   * @returns {Object[]}
   */
  RealmChapterSystem.prototype.getAllChapters = function() {
    var self = this;
    return Object.keys(CHAPTER_DEFINITIONS).map(function(realm) {
      var ch = CHAPTER_DEFINITIONS[realm];
      var progress = self.getProgress(realm);
      return {
        realm: realm,
        num: ch.num,
        title: ch.title,
        subtitle: ch.subtitle,
        triggered: progress.triggered,
        total: progress.total
      };
    });
  };

  /**
   * 重置指定章节的触发记录（用于转世重来）
   * @param {string} [realm] — 不传则重置全部
   */
  RealmChapterSystem.prototype.reset = function(realm) {
    if (realm) {
      this.triggeredMilestones[realm] = [];
    } else {
      this.triggeredMilestones = {};
    }
  };

  return RealmChapterSystem;
})();

// 挂载到全局
if (typeof window !== 'undefined') {
  window.RealmChapterSystem = RealmChapterSystem;
}
if (typeof module !== 'undefined') {
  module.exports = RealmChapterSystem;
}
