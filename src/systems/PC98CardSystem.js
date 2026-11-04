/**
 * PC98CardSystem
 *
 * 角色立绘的 PC-98 美术解析器。该系统只解析稳定资产与表现元数据，
 * 不拥有 DOM，也不得替换 GameUI 的渲染方法。
 */
class PC98CardSystem {
  constructor() {
    this.cardMap = {
      bai_luoxuan: 'assets/cards/characters/collected/bai_luoxuan_pc98.png',
      bai_ren_zhenren: 'assets/cards/characters/collected/bai_ren_pc98.png',
      jian_linger: 'assets/cards/characters/collected/jian_linger_pc98.png',
      mu_qinglan: 'assets/cards/characters/collected/mu_qinglan_pc98.png',
      tianji_laoren: 'assets/cards/characters/collected/tianji_laoren_pc98.png',
      jiuwei_suyue: 'assets/cards/characters/collected/jiuwei_suyue_pc98.png',
      yin_xue: 'assets/cards/characters/collected/yin_xue_pc98.png',
      xuesha_laozu: 'assets/cards/characters/collected/xuesha_laozu_pc98.png',
      mortal: 'assets/cards/characters/card_sunian_mortal_pc98.png',
      wandering_swordsman: 'assets/cards/characters/card_swordsman_wanderer_pc98.png',
      liu_qingluan: 'assets/cards/characters/card_liu_qingluan_pc98.png',
      shi_potian: 'assets/cards/characters/card_shi_potian_pc98.png',
      dieyi_xianzi: 'assets/cards/characters/card_dieyi_xianzi_pc98.png',
      youming_shusheng: 'assets/cards/characters/card_youming_shusheng_pc98.png',
      liu_ruyan: 'assets/cards/characters/card_liu_ruyan_pc98.png',
      hua_xiangrong: 'assets/cards/characters/card_hua_xiangrong_pc98.png',

      // 旧卡牌与存档中的别名兼容。
      bailuoshuang: 'assets/cards/characters/collected/bai_luoxuan_pc98.png',
      bairen: 'assets/cards/characters/collected/bai_ren_pc98.png',
      bai_ren: 'assets/cards/characters/collected/bai_ren_pc98.png',
      jianlinger: 'assets/cards/characters/collected/jian_linger_pc98.png',
      yinxue: 'assets/cards/characters/collected/yin_xue_pc98.png',
      muqinglan: 'assets/cards/characters/collected/mu_qinglan_pc98.png',
      tianjilaoren: 'assets/cards/characters/collected/tianji_laoren_pc98.png',
      jiuweisuyue: 'assets/cards/characters/collected/jiuwei_suyue_pc98.png',
      xueshalaozu: 'assets/cards/characters/collected/xuesha_laozu_pc98.png',
      sunian: 'assets/cards/characters/card_sunian_mortal_pc98.png',
      wanderer: 'assets/cards/characters/card_swordsman_wanderer_pc98.png'
    };

    // cardMap is the curated primary set. presentationMap also adopts legacy
    // character mappings that already point at a PC-98 asset during init.
    this.presentationMap = { ...this.cardMap };

    this._gameUI = null;
    this._originalMap = null;
  }

  /**
   * 把 PC-98 资产注册到现有 UI 映射，并作为只读表现解析器接入。
   */
  init(gameUI) {
    if (!gameUI || !gameUI._npcPortraitMap) {
      console.warn('[PC98Card] GameUI 或 _npcPortraitMap 不可用，跳过注入');
      return false;
    }

    this._gameUI = gameUI;
    this._originalMap = { ...gameUI._npcPortraitMap };
    for (const [npcId, portraitPath] of Object.entries(this._originalMap)) {
      if (this._isPC98Asset(portraitPath) && !this.presentationMap[npcId]) {
        this.presentationMap[npcId] = portraitPath;
      }
    }
    for (const [npcId, pc98Path] of Object.entries(this.cardMap)) {
      gameUI._npcPortraitMap[npcId] = pc98Path;
    }

    if (typeof gameUI.setPortraitPresentationResolver === 'function') {
      gameUI.setPortraitPresentationResolver(this);
    } else {
      // 旧入口兼容：显式保存解析器，但绝不替换 UI 方法。
      gameUI._portraitPresentationResolver = this;
    }

    console.log(`[PC98Card] 已注册 ${Object.keys(this.cardMap).length} 张 PC-98 卡面`);
    return true;
  }

  _isPC98Asset(assetPath) {
    return typeof assetPath === 'string' && /_pc98\.(?:png|webp|jpe?g)$/i.test(assetPath);
  }

  _resolveNpcId(npcId) {
    const aliases = {
      tian_ji: 'tianji_laoren',
      xue_sha: 'xuesha_laozu',
      jiuwei: 'jiuwei_suyue',
      bailuoshuang: 'bai_luoxuan',
      jianlinger: 'jian_linger',
      yinxue: 'yin_xue',
      muqinglan: 'mu_qinglan',
      tianjilaoren: 'tianji_laoren',
      jiuweisuyue: 'jiuwei_suyue',
      xueshalaozu: 'xuesha_laozu'
    };
    return aliases[npcId] || npcId;
  }

  /**
   * 基础阶段使用正式 PC-98 卡面；解锁阶段保留阶段独立资产。
   * 两者都返回 renderer=pc98，由 GameUI 统一应用画框、扫描线和融合层。
   */
  resolvePortraitPresentation(npcId, { stage = null, surface = 'card' } = {}) {
    const resolvedId = this._resolveNpcId(npcId);
    const baseAsset = this.presentationMap[resolvedId] || this.presentationMap[npcId];
    if (!baseAsset) return null;

    const isBaseStage = !stage || Number(stage.affection || 0) === 0;
    return Object.freeze({
      npcId: resolvedId,
      stageId: stage?.id || null,
      asset: stage?.asset && (!isBaseStage || stage.id === 'bai_luoxuan_trapped') ? stage.asset : baseAsset,
      fallbackAsset: baseAsset,
      renderer: 'pc98',
      pixelated: true,
      surface,
      transitionPreset: 'pc98-portrait-settle'
    });
  }

  hasPC98Card(npcId) {
    const resolvedId = this._resolveNpcId(npcId);
    return !!(this.presentationMap[resolvedId] || this.presentationMap[npcId]);
  }

  getCardPath(npcId) {
    const resolvedId = this._resolveNpcId(npcId);
    return this.presentationMap[resolvedId] || this.presentationMap[npcId] || null;
  }
}

if (typeof window !== 'undefined') {
  window.PC98CardSystem = PC98CardSystem;
}
