/**
 * PC98CardSystem — PC98像素卡面集成模块
 *
 * 用途：为游戏中的道侣/NPC角色提供PC98像素风格卡面
 *      替代原有AI生成立绘，提供统一的16-bit像素美术体验
 *
 * 资产约定：assets/cards/characters/card_{id}_pc98.png
 * 分辨率：768×942 (已裁切底部水印)
 *
 * 用法：
 *   const pc98 = new PC98CardSystem();
 *   pc98.init(gameUI);  // 注入到GameUI的NPC立绘系统
 */

class PC98CardSystem {
  constructor() {
    /** 角色ID → PC98卡面路径 映射表 */
    this.cardMap = {
      // ===== 全部8位核心NPC (按GDD人物设定对应) =====
      // 正道/中立角色
      'bai_luoxuan':    'assets/cards/characters/card_bailuoshuang_pc98.png',
      'bai_ren_zhenren': 'assets/cards/characters/card_bairen_zhenren_pc98.png',
      'jian_linger':    'assets/cards/characters/card_jianlinger_pc98.png',
      'mu_qinglan':     'assets/cards/characters/card_mu_qinglan_pc98.png',
      'tianji_laoren':  'assets/cards/characters/card_tianji_laoren_pc98.png',
      // 妖族角色
      'jiuwei_suyue':   'assets/cards/characters/card_jiuwei_suyue_pc98.png',
      // 魔道角色
      'yin_xue':        'assets/cards/characters/card_yinxue_pc98.png',
      'xuesha_laozu':   'assets/cards/characters/card_xuesha_laozu_pc98.png',
      'mortal':         'assets/cards/characters/card_sunian_mortal_pc98.png',
      // ===== 5个随机NPC =====
      'wandering_swordsman': 'assets/cards/characters/card_swordsman_wanderer_pc98.png',
      'liu_qingluan':    'assets/cards/characters/card_liu_qingluan_pc98.png',
      'shi_potian':      'assets/cards/characters/card_shi_potian_pc98.png',
      'dieyi_xianzi':    'assets/cards/characters/card_dieyi_xianzi_pc98.png',
      'youming_shusheng':'assets/cards/characters/card_youming_shusheng_pc98.png',
      // ===== 青楼角色 =====
      'liu_ruyan':       'assets/cards/characters/card_liu_ruyan_pc98.png',
      'hua_xiangrong':   'assets/cards/characters/card_hua_xiangrong_pc98.png',

      // ===== 别名兼容 =====
      'bailuoshuang':   'assets/cards/characters/card_bailuoshuang_pc98.png',
      'bairen':         'assets/cards/characters/card_bairen_zhenren_pc98.png',
      'bai_ren':        'assets/cards/characters/card_bairen_zhenren_pc98.png',
      'jianlinger':     'assets/cards/characters/card_jianlinger_pc98.png',
      'yinxue':         'assets/cards/characters/card_yinxue_pc98.png',
      'muqinglan':      'assets/cards/characters/card_mu_qinglan_pc98.png',
      'tianjilaoren':   'assets/cards/characters/card_tianji_laoren_pc98.png',
      'jiuweisuyue':    'assets/cards/characters/card_jiuwei_suyue_pc98.png',
      'xueshalaozu':    'assets/cards/characters/card_xuesha_laozu_pc98.png',
      'sunian':         'assets/cards/characters/card_sunian_mortal_pc98.png',
      'wanderer':       'assets/cards/characters/card_swordsman_wanderer_pc98.png',
    };

    /** 引用到GameUI的NPC立绘映射表 */
    this._gameUI = null;
    this._originalMap = null;
  }

  /**
   * 初始化：注入到GameUI的NPC立绘系统
   * @param {GameUI} gameUI - 游戏UI实例
   * @param {object} [options]
   * @param {boolean} [options.overrideLitPixel=false] - 是否覆盖LitPixel渲染
   */
  init(gameUI, options = {}) {
    if (!gameUI || !gameUI._npcPortraitMap) {
      console.warn('[PC98Card] GameUI或_npcPortraitMap不可用，跳过注入');
      return false;
    }

    this._gameUI = gameUI;
    this._originalMap = { ...gameUI._npcPortraitMap };

    // 将PC98卡面路径注入到NPC立绘映射表
    for (const [npcId, pc98Path] of Object.entries(this.cardMap)) {
      gameUI._npcPortraitMap[npcId] = pc98Path;
    }

    // 设置PC98渲染钩子：劫持 _renderCardPortrait 让非道侣角色使用PC98卡片
    if (!gameUI._pc98Patched) {
      this._patchCardPortrait(gameUI);
      gameUI._pc98Patched = true;
    }

    console.log(`[PC98Card] 已注入 ${Object.keys(this.cardMap).length} 张PC98卡面`);
    return true;
  }

  /**
   * 劫持 _renderCardPortrait：所有PC98角色统一走融合渲染管线
   *
   * 渲染结构（从下到上）：
   *   container (#card-portrait)
   *     ├── .pc98-card-wrapper          ← 像素卡面容器
   *     │     ├── <img>                 ← PC98卡面原图
   *     │     ├── .pc98-pixel-frame     ← 像素画框边框
   *     │     └── .pc98-scanlines       ← CRT扫描线（极淡）
   *     ├── .portrait-fusion-overlay ×4 ← 氛围雾/暗角/底部融入/深度投影
   *     └── .foxfire-particles         ← 狐火特效（仅白狐系）
   *
   * 卡牌容器自带的 ::before 边缘融合遮罩继续生效。
   */
  _patchCardPortrait(gameUI) {
    const originalRender = gameUI._renderCardPortrait.bind(gameUI);

    gameUI._renderCardPortrait = async function(npcId, container) {
      const pc98Path = this._npcPortraitMap[npcId];

      // —— PC98卡面可用 → 走完整PC98渲染管线 ——
      if (pc98Path && pc98Path.includes('_pc98.png')) {
        container.innerHTML = '';

        // ① 构建像素卡面画框（wrapper 封装 img + 像素框 + 扫描线）
        const wrapper = document.createElement('div');
        wrapper.className = 'pc98-card-wrapper';

        const img = document.createElement('img');
        img.src = pc98Path;
        img.alt = npcId;
        img.className = 'pc98-card-img';
        wrapper.appendChild(img);

        // 像素画框边框（4方向各一根像素线，用box-shadow模拟NES卡带框）
        const frame = document.createElement('div');
        frame.className = 'pc98-pixel-frame';
        wrapper.appendChild(frame);

        // CRT扫描线（极淡，透出像素纹理）
        const scanlines = document.createElement('div');
        scanlines.className = 'pc98-scanlines';
        wrapper.appendChild(scanlines);

        container.appendChild(wrapper);

        // ② 应用融合叠层（复用原生渲染的4层融合系统）
        this._addCardFusionOverlays(container, npcId);

        // ③ 角色专属特效
        if (npcId === 'bai_luoxuan' || npcId === 'jiuwei_suyue') {
          container.querySelectorAll('.foxfire-particles').forEach(el => el.remove());
          this._addFoxfireParticles(container);
        }

        // ④ 更新立绘切换按钮（有多个阶段解锁时显示）
        this._updatePortraitSwitchBtn(npcId);

        return;
      }

      // —— 非PC98角色 → 回退原有渲染 ——
      return originalRender(npcId, container);
    };

    console.log('[PC98Card] _renderCardPortrait 已打补丁：全部PC98角色统一融合渲染');
  }

  /**
   * 检查某角色是否有PC98卡面
   */
  hasPC98Card(npcId) {
    return !!this.cardMap[npcId];
  }

  /**
   * 获取PC98卡面路径
   */
  getCardPath(npcId) {
    return this.cardMap[npcId] || null;
  }
}

// 挂到全局
if (typeof window !== 'undefined') {
  window.PC98CardSystem = PC98CardSystem;
}
