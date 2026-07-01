/**
 * GameUI - 主游戏界面渲染器
 *
 * 负责所有DOM操作和交互处理。
 * 通过 GameLogic 编排，通过 gameState 全局单例读取数据。
 */
class GameUI {
  constructor(gameLogic) {
    this.game = gameLogic;
    this.screens = {};
    this.swipeStartX = 0;
    this.swipeStartY = 0;
    this.swipeThreshold = 80;
    this.logMessages = [];
    this.maxLogMessages = 6;
    this.choiceButtons = [];
    this.touching = false;
    this.cardEl = null;
    this.cardStartX = 0;
    this.cardStartY = 0;
    this.cardCurrentX = 0;
    this.cardCurrentY = 0;
    this.currentCard = null; // 当前显示的卡牌（用于滑动阻力计算）

    this.init();
  }

  init() {
    this.cacheElements();
    this.bindEvents();
    this.bindNpcPanels();
    this._bindShopPanel();
    this._bindThreadPanel();
    // L3: 格挡时机事件监听
    eventBus.on('combat:blockOpportunity', (data) => this._showBlockBar(data));
    // 【故事线程】线程完成 → 日志提示
    eventBus.on('thread:resolved', (data) => this._onThreadResolved(data));
    // FlowDirector 阶段变更
    eventBus.on('flow:phaseChanged', (data) => this._onPhaseChanged(data));
    this.renderStartScreen();
  }

  cacheElements() {
    this.screens.start = document.getElementById('start-screen');
    this.screens.game = document.getElementById('game-screen');
    this.screens.death = document.getElementById('death-screen');

    // 名字创建界面元素
    this.nameInput = document.getElementById('name-input');
    this.nameCharCount = document.getElementById('name-char-count');
    this.nameConfirmBtn = document.getElementById('name-confirm-btn');
    this.nameCreation = document.getElementById('name-creation');
    this.pathSelection = document.getElementById('path-selection');

    this.cardEl = document.getElementById('card');
    this.cardTitle = document.getElementById('card-title');
    this.cardDesc = document.getElementById('card-description');
    this.cardType = document.getElementById('card-type');
    this.cardSource = document.getElementById('card-source');
    this.cardPortrait = document.getElementById('card-portrait');
    this.cardPortraitCanvas = document.getElementById('card-portrait-canvas');

    this.choiceLeft = document.getElementById('choice-left');
    this.choiceRight = document.getElementById('choice-right');
    this.choiceUp = document.getElementById('choice-up');
    this.choiceDown = document.getElementById('choice-down');
    this.choiceButtons = [this.choiceLeft, this.choiceRight, this.choiceUp, this.choiceDown];

    // 故事线程指示器
    this.threadIndicator = document.getElementById('thread-indicator');
    this.threadBar = document.getElementById('thread-bar');
    this.threadName = document.getElementById('thread-name');
    this.threadPhase = document.getElementById('thread-phase');

    // 故事线程侧边面板
    this.threadPanel = document.getElementById('thread-panel');
    this.threadPanelBtn = document.getElementById('thread-panel-btn');
    this.threadPanelClose = document.getElementById('thread-panel-close');
    this.activeThreads = document.getElementById('active-threads');
    this.completedThreads = document.getElementById('completed-threads');
    this.pendingSeeds = document.getElementById('pending-seeds');

    this.bars = {
      cultivation: document.getElementById('bar-cultivation'),
      daoHeart: document.getElementById('bar-daoHeart'),
      karmaGood: document.getElementById('bar-karmaGood'),
      karmaBad: document.getElementById('bar-karmaBad'),
      fortune: document.getElementById('bar-fortune'),
      health: document.getElementById('bar-health')
    };

    this.labels = {
      cultivation: document.getElementById('label-cultivation'),
      daoHeart: document.getElementById('label-daoHeart'),
      karmaGood: document.getElementById('label-karmaGood'),
      karmaBad: document.getElementById('label-karmaBad'),
      fortune: document.getElementById('label-fortune'),
      health: document.getElementById('label-health')
    };

    // Passive bonus display elements
    this.passiveEls = {
      hpRegen: document.getElementById('passive-hpRegen'),
      fortune: document.getElementById('passive-fortune'),
      atk: document.getElementById('passive-atk'),
      def: document.getElementById('passive-def'),
      crit: document.getElementById('passive-crit')
    };

    this.topRealm = document.getElementById('top-realm');
    this.topPath = document.getElementById('top-path');
    this.topSpiritStone = document.getElementById('top-spiritStone');
    this.topLifespan = document.getElementById('top-lifespan');
    this.topTurn = document.getElementById('top-turn');
    this.topQuest = document.getElementById('top-quest');
    this.topChapter = document.getElementById('top-chapter');
    this.topPhase = document.getElementById('top-phase');
    // 突破倒计时
    this.btBar = document.getElementById('breakthrough-bar');
    this.btLabel = document.getElementById('bt-label');
    this.btFill = document.getElementById('bt-fill');
    this.btPct = document.getElementById('bt-pct');
    this.logContainer = document.getElementById('log-container');
    this.logCountEl = document.getElementById('log-count');

    // 位置栏
    this.locIcon = document.getElementById('loc-icon');
    this.locName = document.getElementById('loc-name');
    this.locMood = document.getElementById('loc-mood');

    this.deathTitle = document.getElementById('death-title');
    this.deathReason = document.getElementById('death-reason');
    this.deathStats = document.getElementById('death-stats');
    this.reincarnateBtn = document.getElementById('reincarnate-btn');
  }

  bindEvents() {
    // 名字输入事件
    if (this.nameInput) {
      this.nameInput.addEventListener('input', () => {
        const len = this.nameInput.value.length;
        if (this.nameCharCount) this.nameCharCount.textContent = `${len}/4`;
      });
      this.nameInput.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') this._confirmName();
      });
    }
    if (this.nameConfirmBtn) {
      this.nameConfirmBtn.addEventListener('click', () => this._confirmName());
    }

    // Path selection
    document.querySelectorAll('.path-btn').forEach(btn => {
      btn.addEventListener('click', (e) => {
        const path = e.currentTarget.dataset.path;
        this.startGame(path);
      });
    });

    // Reincarnate
    this.reincarnateBtn.addEventListener('click', () => {
      this.game._reincarnate();
      this.showScreen('game');
      this.renderGame();
    });

    // Swipe on card
    this.cardEl.addEventListener('touchstart', (e) => this.onTouchStart(e), { passive: true });
    this.cardEl.addEventListener('touchmove', (e) => this.onTouchMove(e), { passive: true });
    this.cardEl.addEventListener('touchend', (e) => this.onTouchEnd(e), { passive: true });

    this.cardEl.addEventListener('mousedown', (e) => this.onMouseDown(e));
    document.addEventListener('mousemove', (e) => this.onMouseMove(e));
    document.addEventListener('mouseup', (e) => this.onMouseUp(e));

    // Keyboard
    document.addEventListener('keydown', (e) => {
      if (this.screens.game.classList.contains('active')) {
        if (e.key === 'ArrowLeft') this.makeChoice('left');
        if (e.key === 'ArrowRight') this.makeChoice('right');
        if (e.key === 'ArrowUp') this.makeChoice('up');
        if (e.key === 'ArrowDown') this.makeChoice('down');
      }
    });

    // Choice buttons
    this.choiceButtons.forEach(btn => {
      btn.addEventListener('click', (e) => {
        const dir = e.currentTarget.dataset.dir;
        this.makeChoice(dir);
      });
    });

    // Game callbacks
    this.game.onLog = (msg, cssClass) => this.addLog(msg, cssClass);
    this.game.onUpdate = () => this.renderGame();
  }

  renderStartScreen() {
    this.showScreen('start');
    // 重置为名字输入阶段
    if (this.nameCreation) this.nameCreation.style.display = 'block';
    if (this.pathSelection) this.pathSelection.style.display = 'none';
    if (this.nameInput) {
      this.nameInput.value = '';
      if (this.nameCharCount) this.nameCharCount.textContent = '0/4';
    }
  }

  /** 确认名字 → 显示功法选择 */
  _confirmName() {
    const rawName = this.nameInput ? this.nameInput.value.trim() : '';
    const playerName = rawName || '叶凌云';
    // 存储到 gameState
    if (typeof gameState !== 'undefined') {
      gameState.playerName = playerName;
    }
    // 隐藏名字输入，显示功法选择
    if (this.nameCreation) this.nameCreation.style.display = 'none';
    if (this.pathSelection) this.pathSelection.style.display = 'block';
    // 滚动到功法选择区域
    if (this.pathSelection) this.pathSelection.scrollIntoView({ behavior: 'smooth' });
  }

  startGame(path) {
    this.game.start(path);
    this.showScreen('game');
    this.logMessages = [];
    this.renderGame();
  }

  showScreen(name) {
    Object.values(this.screens).forEach(s => s.classList.remove('active'));
    this.screens[name].classList.add('active');
  }

  renderGame() {
    this.renderTopBar();
    this.renderAttributes();
    this.renderPassives();
    this.renderCard();
    this.renderLog();

    if (gameState.dead) {
      this.renderDeathScreen();
      this.showScreen('death');
    }
  }

  renderTopBar() {
    const playerName = gameState.playerName || '叶凌云';
    this.topRealm.textContent = `${playerName} · ${gameState.getRealmName()}`;

    // ── 境界章节显示 ──
    if (this.topChapter && typeof chapterSystem !== 'undefined' && chapterSystem && chapterSystem._initialized) {
      const chapterTitle = chapterSystem.getChapterTitle(gameState.realm);
      const progress = chapterSystem.getProgress(gameState.realm);
      this.topChapter.textContent = chapterTitle + ' · ' + progress.triggered + '/' + progress.total;
      this.topChapter.style.display = 'inline-block';
    } else if (this.topChapter) {
      this.topChapter.style.display = 'none';
    }

    // ── FlowDirector 阶段显示 ──
    if (this.topPhase && typeof flowDirector !== 'undefined' && flowDirector) {
      const p = flowDirector.PHASES[flowDirector._currentPhase];
      if (p) {
        this.topPhase.textContent = p.name;
        this.topPhase.style.display = 'inline-block';
        this.topPhase.className = `badge phase phase-${p.id}`;
      }
    } else if (this.topPhase) {
      this.topPhase.style.display = 'none';
    }

    this.topPath.textContent = gameState.getPathName(gameState.path);
    this.topSpiritStone.textContent = gameState.resources.spiritStone;
    this.topLifespan.textContent = gameState.resources.lifespan;
    this.topTurn.textContent = gameState.turn;

    // 时辰系统：每 6 轮切换一次
    this._updateTimeOfDay();

    // 位置栏更新
    this._updateLocationBar();

    // 突破倒计时
    this._renderBreakthroughBar();

    // 支线状态
    const activeQuest = questSystem.getActiveQuest();
    if (activeQuest && this.topQuest) {
      const quest = questSystem.getQuest(activeQuest.questId);
      this.topQuest.textContent = quest ? `支线: ${quest.name}` : '';
      this.topQuest.style.display = 'inline-block';
    } else if (this.topQuest) {
      this.topQuest.style.display = 'none';
    }
  }

  /** FlowDirector 阶段变更事件响应 */
  _onPhaseChanged(data) {
    if (this.topPhase) {
      this.topPhase.textContent = data.phaseName;
      this.topPhase.style.display = 'inline-block';
      this.topPhase.className = `badge phase phase-${data.phaseId}`;
    }
  }

  /** 时辰系统 — 每 6 轮切换 */
  _updateTimeOfDay() {
    const turn = gameState.turn || 0;
    const phase = Math.floor(turn / 6) % 4;
    const times = ['子时', '卯时', '午时', '酉时'];
    const timeStr = times[phase];
    document.documentElement.dataset.time = timeStr;
  }

  /** 位置栏 — 从 SceneLayerSystem 获取当前位置 */
  _updateLocationBar() {
    if (!this.locName) return;
    try {
      const loc = (typeof sceneLayerSystem !== 'undefined' && sceneLayerSystem)
        ? sceneLayerSystem.getCurrentLocation()
        : null;
      if (loc) {
        const icons = { '宗门': '🏯', '坊市': '🏪', '秘境': '🏔', '洞府': '🏠', '魔域': '💀' };
        this.locIcon.textContent = icons[loc.id] || '📍';
        this.locName.textContent = `${loc.name} · ${loc.sublocation || ''}`;
        this.locMood.textContent = loc.atmosphere || '风轻云淡，万物静默。';
      } else {
        this.locIcon.textContent = '🏯';
        this.locName.textContent = '青云宗';
        this.locMood.textContent = '晨雾未散，青石阶上露水沾衣。';
      }
    } catch (e) {
      // 静默失败
    }
  }

  /**
   * 突破倒计时进度条 — 始终可见的突破进度
   * 根据当前境界的 cultivationThreshold 计算百分比
   */
  _renderBreakthroughBar() {
    if (!this.btBar) return;
    const realmConfig = gameState.config.realms
      ? (gameState.config.realms.realms || {})[gameState.realm]
      : null;
    if (!realmConfig || !realmConfig.cultivationThreshold) {
      this.btBar.style.display = 'none';
      return;
    }
    const threshold = realmConfig.cultivationThreshold;
    const current = gameState.attributes.cultivation;
    const pct = Math.min(100, Math.floor((current / threshold) * 100));
    const nextRealm = gameState.getRealmName(
      (gameState.config.realms.order || [])[
        (gameState.config.realms.order || []).indexOf(gameState.realm) + 1
      ] || ''
    );

    this.btBar.style.display = 'flex';
    this.btLabel.textContent = `🔥 ${nextRealm || '突破'}进度`;
    this.btFill.style.width = `${pct}%`;
    this.btPct.textContent = `${pct}%`;

    // 阶梯色类名
    this.btFill.className = 'bt-fill';
    if (pct >= 90) {
      this.btFill.classList.add('crit');
      this.btLabel.style.color = '#fbbf24';
      this.btPct.style.color = '#fbbf24';
    } else if (pct >= 75) {
      this.btFill.classList.add('high');
      this.btLabel.style.color = '#a78bfa';
      this.btPct.style.color = '#a78bfa';
    } else if (pct >= 50) {
      this.btFill.classList.add('mid');
      this.btLabel.style.color = '#5ba0f5';
      this.btPct.style.color = '#5ba0f5';
    } else {
      this.btFill.classList.add('low');
      this.btLabel.style.color = '';
      this.btPct.style.color = '';
    }
  }

  renderAttributes() {
    const attrs = gameState.attributes;
    const labels = {
      cultivation: '修为', daoHeart: '道心',
      karmaGood: '善因', karmaBad: '恶因',
      fortune: '福缘', health: '气血'
    };
    for (const [key, bar] of Object.entries(this.bars)) {
      const value = attrs[key] || 0;
      bar.style.width = `${Math.min(value, 100)}%`;
      bar.textContent = `${value}`;
      this.labels[key].textContent = `${labels[key]} ${value}`;
    }
  }

  renderPassives() {
    // Get aggregated passive bonuses from game logic
    const passives = this.game._getAggregatedPassives ? this.game._getAggregatedPassives() : {};
    const mappings = [
      { key: 'hpRegen', id: 'hpRegen', fmt: v => `+${v}` },
      { key: 'fortuneBonus', id: 'fortune', fmt: v => `+${v}` },
      { key: 'atk', id: 'atk', fmt: v => `+${v}` },
      { key: 'def', id: 'def', fmt: v => `+${v}` },
      { key: 'critRate', id: 'crit', fmt: v => `+${v}%` }
    ];

    for (const m of mappings) {
      const el = this.passiveEls[m.id];
      if (!el) continue;
      const val = passives[m.key] || 0;
      const valEl = el.querySelector('.passive-val');
      if (valEl) {
        valEl.textContent = m.fmt(val);
      }
      if (val > 0) {
        el.classList.add('has-bonus');
      } else {
        el.classList.remove('has-bonus');
      }
    }
  }

  renderCard() {
    const card = this.game.getCurrentCard();
    if (!card) return;
    this.currentCard = card; // 保存引用，用于滑动阻力计算

    // ==================== 安全重置：确保卡牌容器可见（防止动画残留 opacity:0）====================
    this.cardEl.style.opacity = '1';
    this.cardEl.style.transform = 'translate(0, 0) rotate(0)';
    this.cardEl.style.display = '';
    this.cardEl.style.visibility = 'visible';
    this.cardEl.classList.remove('card-location', 'card-combat', 'card-karma', 'card-bottleneck', 'card-breakthrough', 'card-shop', 'card-destiny', 'card-story');

    // ==================== 清除上一张卡的立绘残留（解决异步竞态） ====================
    this._portraitGen = (this._portraitGen || 0) + 1;
    const portraitDiv = document.getElementById('card-portrait');
    if (portraitDiv) {
      portraitDiv.style.display = 'none';
      portraitDiv.style.backgroundImage = '';
      portraitDiv.innerHTML = '';
    }
    this.cardEl.style.backgroundImage = '';

    // ==================== v2.0 特殊卡牌分支 ====================
    if (card.type === 'COMBAT_UI') {
      this._renderCombatCard(card);
      return;
    }
    if (card.type === 'INNER_DEMON') {
      this._renderInnerDemonCard(card);
      return;
    }
    if (card.type === 'DESTINY_WHEEL') {
      this._renderDestinyWheelCard(card);
      return;
    }
    if (card.type === 'KARMA_RIPPLE') {
      this._renderKarmaRippleCard(card);
      return;
    }
    if (card.type === 'HEAVENS_HINT') {
      this._renderHeavensHintCard(card);
      return;
    }
    if (card.type === 'NPC_CROSS') {
      this._renderNpcCrossCard(card);
      return;
    }
    if (card.type === 'SPECIAL') {
      this._renderSpecialCard(card);
      return;
    }
    if (card.type === 'LOCATION') {
      this._renderLocationCard(card);
      return;
    }

    this.cardTitle.textContent = card.title;
    // ── 叙事连贯性层：动态增强描述（支线×线程交叉引用）──
    let descText = card.description;
    if (typeof coherenceLayer !== 'undefined' && coherenceLayer) {
      const enhanced = coherenceLayer.enhanceDescription(
        card, this._getGameState(), this._getThreadEngine(), this._getQuestSystem()
      );
      if (enhanced && enhanced !== card.description) {
        descText = enhanced;
      }
    }
    this.cardDesc.textContent = descText;

    // ======== 故事线程指示器 ========
    this._renderThreadIndicator(card);

    // ======== NPC角色立绘 —异步加载，不阻塞 choices 渲染 ========
    const npcId = card.npcId || card.compId || (card.npcIds && card.npcIds[0]);
    if (npcId && portraitDiv) {
      portraitDiv.style.display = 'flex';
      portraitDiv.style.position = 'relative';
      portraitDiv.style.overflow = 'hidden';
      // ★ 场景图作为独立底层（z-index:0），NPC角色渲染在上层，不会被遮挡
      if (card.sceneImage) {
        const sceneBackdrop = document.createElement('div');
        sceneBackdrop.className = 'card-scene-backdrop';
        sceneBackdrop.style.cssText =
          'position:absolute;inset:0;z-index:0;pointer-events:none;background-image:url(\'' + card.sceneImage + '\');' +
          'background-size:cover;background-position:center;';
        portraitDiv.appendChild(sceneBackdrop);
        // 同时设 cardEl 背景以防肖像区高度不够时露出
        this.cardEl.style.backgroundImage = `url('${card.sceneImage}')`;
        this.cardEl.style.backgroundSize = 'cover';
        this.cardEl.style.backgroundPosition = 'center';
      }
      this._renderCardPortrait(npcId, portraitDiv).catch(err => {
        console.warn('[UI] Card portrait render failed:', err);
      });
    } else if (portraitDiv) {
      // 无 NPC 立绘 → 渲染类型主题图标
      this._renderThemedPortrait(card, portraitDiv);
    }

    // 卡牌类型标签
    const typeName = this.getCardTypeName(card.type);
    const priority = cardSystem.getLastDrawnPriority();
    if (card.type === 'QUEST') {
      this.cardType.textContent = `支线任务`;
    } else if (priority === 60) {
      this.cardType.textContent = `因果 · ${typeName}`;
    } else if (priority === 90) {
      this.cardType.textContent = `突破 · ${typeName}`;
    } else {
      this.cardType.textContent = typeName;
    }

    // ── 来源标签显示 ──
    if (card._flowSource && this.cardSource) {
      const sourceMap = {
        'karma': '⚡ 因果',
        'quest:current': '📜 主线',
        'quest:entry': '📜 支线',
        'milestone': '🎯 突破',
        'shop': '🏪 坊市',
        'market': '🎪 集市',
        'combat_warning': '⚠️ 敌袭',
        'fallback': '🔄 兜底'
      };
      
      let sourceText = '';
      if (card._flowSource.startsWith('normal:')) sourceText = '✨ 日常';
      else if (card._flowSource.startsWith('narrative:')) sourceText = '📖 故事';
      else if (card._flowSource.startsWith('pending:')) sourceText = '⏳ 挂起';
      else if (card._flowSource.startsWith('interrupt:')) sourceText = '⚡ 突发';
      else sourceText = sourceMap[card._flowSource] || card._flowSource;

      this.cardSource.textContent = sourceText;
      this.cardSource.style.display = 'inline-block';
    } else if (this.cardSource) {
      this.cardSource.style.display = 'none';
    }

    // Reset card
    this.cardEl.style.transform = 'translate(0, 0) rotate(0)';
    this.cardEl.className = `card card-${card.type.toLowerCase()}`;

    // ======== 场景图动态背景 ========
    if (card.sceneImage) {
      this.cardEl.style.backgroundImage = `url('${card.sceneImage}')`;
    } else {
      this.cardEl.style.backgroundImage = 'none';
    }

    // Reset choice buttons
    this.choiceButtons.forEach(btn => {
      btn.classList.remove('visible');
      btn.querySelector('.choice-text').textContent = '';
    });

    // Show available choices
    const dirs = this.game.getAvailableDirections(card);
    const dirLabels = { left: '←', right: '→', up: '↑', down: '↓' };

    dirs.forEach(dir => {
      const btn = this.getChoiceButton(dir);
      const choice = card.choices[dir];
      if (btn && choice) {
        btn.classList.add('visible');
        btn.querySelector('.choice-text').textContent = `${dirLabels[dir]} ${choice.text}`;
        // ── 叙事连贯性层：选择后果描述 ──
        const descEl = btn.querySelector('.choice-desc');
        if (descEl) {
          descEl.textContent = choice.desc || '';
        }
        // 【沉浸 v2.0】选择预兆 — 按钮按后果类型变色
        const mood = this._choiceMood(choice.effects);
        btn.dataset.mood = mood;
      }
    });
  }

  /**
   * COMBAT_UI卡牌渲染 v2.0 — 含灵力条/架势/势层
   */
  _renderCombatCard(card) {
    const st = card.combatState;
    if (!st) {
      this.cardTitle.textContent = '战斗';
      this.cardDesc.textContent = '战斗状态异常...';
      this.cardType.textContent = 'COMBAT_UI';
      return;
    }

    const p = st.player;
    const e = st.enemy;
    const pHpPct = Math.max(0, Math.min(100, Math.round(p.hp / p.maxHp * 100)));
    const eHpPct = Math.max(0, Math.min(100, Math.round(e.hp / e.maxHp * 100)));
    const qiPct = st.maxQi ? Math.max(0, Math.min(100, Math.round(st.qi / st.maxQi * 100))) : 0;
    const stanceIcons = { attack: '⚔', defend: '🛡', break: '💢' };
    const stanceIcon = stanceIcons[st.stance] || '⚔';

    this.cardTitle.textContent = `${stanceIcon} 回合 ${st.turn} — ${e.name}`;
    this.cardDesc.innerHTML = `
      <div class="combat-hud">
        <div class="combat-hp-row">
          <span class="combat-label">我方</span>
          <div class="combat-bar-bg"><div class="combat-bar-fill player-hp" style="width:${pHpPct}%"></div></div>
          <span class="combat-hp-text">${p.hp}/${p.maxHp}</span>
        </div>
        <div class="combat-qi-row">
          <span class="combat-label">灵力</span>
          <div class="combat-bar-bg qi-bg"><div class="combat-bar-fill qi-fill" style="width:${qiPct}%"></div></div>
          <span class="combat-hp-text" style="color:#5ba0f5">${st.qi}/${st.maxQi}</span>
        </div>
        <div class="combat-hp-row">
          <span class="combat-label">${e.name}</span>
          <div class="combat-bar-bg"><div class="combat-bar-fill enemy-hp" style="width:${eHpPct}%"></div></div>
          <span class="combat-hp-text">${e.hp}/${e.maxHp}</span>
        </div>
        ${st.momentum > 0 ? `<div class="combat-momentum">🔥 连击势: ${'▮'.repeat(st.momentum)}${'▯'.repeat(4-st.momentum)}  [${st.momentum}/4]</div>` : ''}
      </div>
    `;
    this.cardType.textContent = '战斗';

    // Reset card
    this.cardEl.style.transform = 'translate(0, 0) rotate(0)';
    this.cardEl.className = 'card card-combat_ui';
    this.cardEl.style.backgroundImage = '';

    // 渲染战斗动作按钮 — v2: 动态映射
    const actions = combatSystem.getActions();
    const dirSlots = ['left', 'right', 'up', 'down'];
    this.choiceButtons.forEach(btn => {
      btn.classList.remove('visible');
      btn.querySelector('.choice-text').textContent = '';
    });

    // 如果动作 ≤ 4 个,用4方向; 如果 > 4个,前两个用左右,多余的堆叠在下方
    actions.forEach((action, i) => {
      const btn = this.choiceButtons[i];
      if (btn) {
        btn.classList.add('visible');
        btn.querySelector('.choice-text').textContent = action.text;
        btn.dataset.combatAction = action.id;
      }
    });
    this._currentCardIsCombat = actions;
  }

  /**
   * L3: 激活格挡时机UI
   * 监听 combat:blockOpportunity 事件，展示格挡条+光标动画
   */
  _showBlockBar(blockData) {
    if (!blockData) return;

    this.choiceButtons.forEach(btn => btn.classList.remove('visible'));

    const existingBlock = document.getElementById('block-minigame');
    if (existingBlock) existingBlock.remove();

    const blockHtml = `
      <div id="block-minigame" class="block-minigame">
        <div class="block-label">⚡ ${blockData.enemyName} 蓄力攻击！按空格键 / 点击卡牌格挡！${treasureSystem && treasureSystem.hasTrait('坚盾') ? ' 🛡坚盾' : ''}</div>
        <div class="block-bar-container">
          <div class="block-zone block-zone-early">过早</div>
          <div class="block-zone block-zone-perfect">完美</div>
          <div class="block-zone block-zone-late">过晚</div>
          <div class="block-zone block-zone-miss">失误</div>
          <div class="block-cursor" id="block-cursor">▼</div>
        </div>
        <div class="block-dmg-preview">预计伤害：<strong>${blockData.damage}</strong></div>
      </div>
    `;

    this.cardDesc.innerHTML += blockHtml;
    this._blockData = blockData;
    this._blockActive = true;
    this._blockCursorPos = 0;
    this._blockDirection = 1;
    this._blockSpeed = 0.02;

    this._animateBlockCursor();

    // 空格键 / 点击 触发格挡
    this._onBlockInput = (e) => {
      if (!this._blockActive) return;
      if (e.type === 'keydown' && e.code === 'Space') {
        e.preventDefault();
        this._resolveBlock();
        return;
      }
      if (e.type === 'click') {
        // 避免战斗动作按钮的click也触发
        if (e.target.closest('#block-minigame') || e.target.closest('.card')) {
          this._resolveBlock();
        }
      }
    };
    document.addEventListener('keydown', this._onBlockInput);
    this.cardEl.addEventListener('click', this._onBlockInput);
  }

  _animateBlockCursor() {
    if (!this._blockActive) return;
    const cursor = document.getElementById('block-cursor');
    if (!cursor) return;

    this._blockCursorPos += this._blockSpeed * this._blockDirection;
    if (this._blockCursorPos >= 100) { this._blockCursorPos = 100; this._blockDirection = -1; }
    else if (this._blockCursorPos <= 0) { this._blockCursorPos = 0; this._blockDirection = 1; }

    cursor.style.left = this._blockCursorPos + '%';
    this._blockAnimFrame = requestAnimationFrame(() => this._animateBlockCursor());
  }

  _resolveBlock() {
    if (!this._blockActive) return;
    if (this._blockAnimFrame) cancelAnimationFrame(this._blockAnimFrame);
    this._blockActive = false;
    document.removeEventListener('keydown', this._onBlockInput);
    this.cardEl.removeEventListener('click', this._onBlockInput);

    const pos = this._blockCursorPos;
    // ── L6: 坚盾 — 扩大完美/良好判定窗口 ──
    const hasFortress = treasureSystem && treasureSystem.hasTrait('坚盾');
    const pStart = hasFortress ? 45 : 55;
    const gLow = hasFortress ? 30 : 40;
    const gHigh = hasFortress ? 88 : 85;

    let quality = 'miss';
    if (pos >= pStart && pos <= 75) quality = 'perfect';
    else if ((pos >= gLow && pos < pStart) || (pos > 75 && pos <= gHigh)) quality = 'good';
    else if (pos >= 20 && pos < gLow) quality = 'early';
    else if (pos > gHigh && pos <= 95) quality = 'late';

    const blockDiv = document.getElementById('block-minigame');
    if (blockDiv) {
      const texts = { perfect: '✨ 完美格挡！', good: '🛡 格挡成功！', early: '⚡ 稍早了些', late: '💨 稍晚了些', miss: '💥 失误了！' };
      blockDiv.innerHTML = `<div class="block-result ${quality}">${texts[quality]}</div>`;
      setTimeout(() => blockDiv.remove(), 800);
    }

    eventBus.emit('combat:blockAction', { quality });
  }

  /**
   * v2.0 心魔反噬卡渲染
   */
  _renderInnerDemonCard(card) {
    this.cardTitle.textContent = '🖤 心魔反噬';
    this.cardDesc.textContent = card.description;
    this.cardType.textContent = '心魔';
    this.cardEl.style.transform = 'translate(0, 0) rotate(0)';
    this.cardEl.className = 'card card-inner-demon';
    this.cardEl.style.backgroundImage = '';
    this.cardPortrait.style.display = 'none';

    const choiceKeys = Object.keys(card.choices);
    const dirs = ['left', 'right', 'up', 'down'];
    const dirLabels = { left: '←', right: '→', up: '↑', down: '↓' };

    this.choiceButtons.forEach(btn => btn.classList.remove('visible'));
    choiceKeys.forEach((key, i) => {
      const btn = this.choiceButtons[i];
      const choice = card.choices[key];
      if (btn && choice && i < dirs.length) {
        btn.classList.add('visible');
        btn.querySelector('.choice-text').textContent = `${dirLabels[dirs[i]]} ${choice.text}`;
        btn.dataset.combatAction = dirs[i];
      }
    });
    this._currentCardIsCombat = null; // 非战斗卡
  }

  /**
   * v2.0 命盘轮转卡渲染
   */
  _renderDestinyWheelCard(card) {
    const ws = card.wheelState;
    this.cardTitle.textContent = '🔮 天机涌动 · 命盘轮转';
    this.cardType.textContent = '命盘';
    this.cardEl.style.transform = 'translate(0, 0) rotate(0)';
    this.cardEl.className = 'card card-destiny-wheel';
    this.cardEl.style.backgroundImage = '';

    // 构建5张覆面牌展示
    let html = '<div class="wheel-grid">';
    const icons = { legendary: '🐉', epic: '💎', rare: '🔮', common: '💰', empty: '🌫' };
    for (let i = 0; i < ws.deck.length; i++) {
      const c = ws.deck[i];
      const icon = c.revealed ? icons[c.rarity] || '🔮' : '🔮';
      const name = c.revealed ? c.name : '???';
      const desc = c.revealed ? c.desc : '天机未显';
      const rarityClass = c.revealed ? 'revealed-'+c.rarity : '';
      html += `<div class="wheel-card ${rarityClass}">${icon}<br><b>${name}</b><br><small>${desc}</small></div>`;
    }
    html += '</div>';
    html += '<p style="text-align:center;color:var(--text-secondary);font-size:0.75rem;margin-top:6px;">选择一张天机牌翻看（左右上下对应位置）</p>';
    this.cardDesc.innerHTML = html;

    // 4方向对应前4张牌
    const dirs = ['left', 'right', 'up', 'down'];
    this.choiceButtons.forEach(btn => btn.classList.remove('visible'));
    for (let i = 0; i < 4; i++) {
      const btn = this.choiceButtons[i];
      if (btn) {
        btn.classList.add('visible');
        btn.querySelector('.choice-text').textContent = `翻看第${i+1}张`;
        btn.dataset.combatAction = dirs[i];
      }
    }
    this._currentCardIsCombat = null;
  }

  /**
   * v2.0 因果涟漪卡渲染
   */
  _renderKarmaRippleCard(card) {
    const typeIcons = { karma: '🌟', grudge: '💀', bloodline: '🩸', fate: '🌀' };
    const icon = typeIcons[card.seedType] || '🌊';
    const npcTag = card.npcName ? ` · ${card.npcName}` : '';
    this.cardTitle.textContent = `${icon} 因果涟漪 · ${card.title}`;
    this.cardDesc.textContent = card.description;
    this.cardType.textContent = `涟漪 · ${card.seedType}${npcTag}`;
    this.cardEl.style.transform = 'translate(0, 0) rotate(0)';
    this.cardEl.className = 'card card-karma-ripple';
    this.cardEl.style.backgroundImage = '';

    // 显示场景立绘（替代隐藏）
    if (card.imagePath) {
      this.cardPortrait.style.display = 'block';
      this.cardPortrait.style.backgroundImage = `url('${card.imagePath}')`;
      this.cardPortrait.style.backgroundSize = 'contain';
      this.cardPortrait.style.backgroundPosition = 'center';
      this.cardPortrait.style.backgroundRepeat = 'no-repeat';
      // 清除可能残留的 canvas 内容
      this.cardPortrait.innerHTML = '';
    } else {
      this.cardPortrait.style.display = 'none';
    }

    this.choiceButtons.forEach(btn => btn.classList.remove('visible'));
    const dirs = ['left', 'right'];
    const dirLabels = { left: '←', right: '→' };
    const choiceKeys = Object.keys(card.choices);
    for (let i = 0; i < Math.min(2, choiceKeys.length); i++) {
      const btn = this.choiceButtons[i];
      const key = choiceKeys[i];
      if (btn && card.choices[key]) {
        btn.classList.add('visible');
        btn.querySelector('.choice-text').textContent = `${dirLabels[dirs[i]]} ${card.choices[key].text}`;
        btn.dataset.combatAction = dirs[i];
      }
    }
    this._currentCardIsCombat = null;
  }

  /**
   * v2.0 天机一闪卡渲染
   */
  _renderHeavensHintCard(card) {
    const catIcons = { '吉兆': '✨', '凶兆': '⚠', '天机': '🌀' };
    const icon = catIcons[card.hintCategory] || '✨';
    this.cardTitle.textContent = `${icon} ${card.title}`;
    this.cardDesc.textContent = card.description;
    this.cardType.textContent = `天机 · ${card.hintCategory || '预言'}`;
    this.cardEl.style.transform = 'translate(0, 0) rotate(0)';
    this.cardEl.className = 'card card-heavens-hint';
    this.cardEl.style.backgroundImage = '';
    this.cardPortrait.style.display = 'none';

    this.choiceButtons.forEach(btn => btn.classList.remove('visible'));
    const dirs = ['left', 'right'];
    const dirLabels = { left: '←', right: '→' };
    const choiceKeys = Object.keys(card.choices);
    for (let i = 0; i < Math.min(2, choiceKeys.length); i++) {
      const btn = this.choiceButtons[i];
      const key = choiceKeys[i];
      if (btn && card.choices[key]) {
        btn.classList.add('visible');
        btn.querySelector('.choice-text').textContent = `${dirLabels[dirs[i]]} ${card.choices[key].text}`;
        btn.dataset.combatAction = dirs[i];
      }
    }
    this._currentCardIsCombat = null;
  }

  /**
   * NPC_CROSS 交叉互动卡 — 双人立绘 + 关系标识
   * 当两个NPC在同一场景触发互动时渲染
   */
  _renderNpcCrossCard(card) {
    this.cardTitle.textContent = card.title;
    this.cardDesc.innerHTML = (card.description || '').replace(/\n/g, '<br>');
    this.cardType.textContent = `交叉事件 · ${card.location || '偶遇'}`;
    this.cardEl.style.transform = 'translate(0, 0) rotate(0)';
    this.cardEl.className = 'card card-npc_cross';
    this.cardEl.style.backgroundImage = '';

    // ── 双人立绘容器 ──
    const portraitDiv = document.getElementById('card-portrait');
    if (portraitDiv && card.npcIds && card.npcIds.length >= 2) {
      portraitDiv.style.display = 'flex';
      portraitDiv.style.flexDirection = 'row';
      portraitDiv.innerHTML = '';

      // 左侧 NPC A
      const leftSlot = document.createElement('div');
      leftSlot.className = 'npc-cross-slot npc-cross-left';
      leftSlot.style.cssText = 'flex:1;display:flex;align-items:center;justify-content:center;position:relative;';
      portraitDiv.appendChild(leftSlot);

      // 中间关系标识
      const relGauge = document.createElement('div');
      relGauge.className = 'npc-cross-gauge';
      relGauge.style.cssText = 'width:40px;display:flex;align-items:center;justify-content:center;flex-direction:column;font-size:20px;';
      relGauge.innerHTML = '<span style="font-size:12px;color:#ffd700;">vs</span>';
      portraitDiv.appendChild(relGauge);

      // 右侧 NPC B
      const rightSlot = document.createElement('div');
      rightSlot.className = 'npc-cross-slot npc-cross-right';
      rightSlot.style.cssText = 'flex:1;display:flex;align-items:center;justify-content:center;position:relative;';
      portraitDiv.appendChild(rightSlot);

      // 异步加载两个角色的立绘
      this._renderCardPortrait(card.npcIds[0], leftSlot).catch(err =>
        console.warn('[UI] NPC_CROSS left portrait failed:', err)
      );
      this._renderCardPortrait(card.npcIds[1], rightSlot).catch(err =>
        console.warn('[UI] NPC_CROSS right portrait failed:', err)
      );
    } else if (portraitDiv) {
      portraitDiv.style.display = 'none';
    }

    // ── 选择按钮 ──
    this.choiceButtons.forEach(btn => btn.classList.remove('visible'));
    const choiceMap = card.choices;
    if (choiceMap) {
      const labels = { left: '←', right: '→' };
      for (const dir of ['left', 'right']) {
        if (choiceMap[dir]) {
          const btn = this.getChoiceButton(dir);
          if (btn) {
            btn.classList.add('visible');
            btn.querySelector('.choice-text').textContent = `${labels[dir]} ${choiceMap[dir].text}`;
            btn.dataset.combatAction = dir;
          }
        }
      }
    }
    this._currentCardIsCombat = null;
  }

  /**
   * 渲染 SPECIAL 卡牌（正魔抉择、因果交织等无 NPC 的叙事事件卡）
   * 标签驱动的主题背景 + 氛围图标，弥补无立绘的空洞感
   * @param {object} card
   */
  _renderSpecialCard(card) {
    // ── 标签 → 主题映射 ──
    const THEME_MAP = {
      demon_path:    { name: '邪气',    bg: 'demon',    icon: '☯', color: '#c0392b' },
      orthodox:      { name: '道心',    bg: 'orthodox', icon: '☀', color: '#f1c40f' },
      mystery:       { name: '迷雾',    bg: 'mystery',  icon: '◈', color: '#6c5ce7' },
      first_contact: { name: '洞见',    bg: 'mystery',  icon: '◆', color: '#a29bfe' },
      moral:         { name: '抉择',    bg: 'orthodox', icon: '⚖', color: '#e17055' },
      interweave:    { name: '因果',    bg: 'interweave', icon: '✧', color: '#3b3b98' },
      sect_demonic:  { name: '宗门',    bg: 'demon',    icon: '◆', color: '#d63031' },
      offer:         { name: '诱惑',    bg: 'temptation', icon: '☽', color: '#e74c3c' },
      temptation:    { name: '考验',    bg: 'temptation', icon: '☽', color: '#e74c3c' },
      cultivation:   { name: '修炼',    bg: 'orthodox', icon: '☰', color: '#00b894' },
      dao_heart:     { name: '道心',    bg: 'orthodox', icon: '☀', color: '#fdcb6e' },
      karma:         { name: '业果',    bg: 'interweave', icon: '✧', color: '#8e44ad' },
      betrayal:      { name: '背叛',    bg: 'demon',    icon: '⚡', color: '#c0392b' },
      sacrifice:     { name: '牺牲',    bg: 'demon',    icon: '❖', color: '#e17055' },
      awakening:     { name: '觉醒',    bg: 'mystery',  icon: '✦', color: '#74b9ff' },
    };

    // 从 tags 中匹配第一个有效主题
    let theme = { name: '命运', bg: 'default', icon: '※', color: '#636e72' };
    if (card.tags && Array.isArray(card.tags)) {
      for (const tag of card.tags) {
        if (THEME_MAP[tag]) { theme = THEME_MAP[tag]; break; }
      }
    }

    // ── 卡牌元数据 ──
    this.cardTitle.textContent = card.title;
    this.cardDesc.innerHTML = (card.description || '').replace(/\n/g, '<br>');
    this.cardType.textContent = `${theme.name} · 天道`;
    this.cardEl.style.transform = 'translate(0, 0) rotate(0)';
    this.cardEl.className = `card card-special card-special--${theme.bg}`;

    // ── 氛围立绘区：优先使用场景图，无图时用气氛主题占位 ──
    const portraitDiv = document.getElementById('card-portrait');
    if (portraitDiv) {
      portraitDiv.style.display = 'flex';
      portraitDiv.innerHTML = '';

      // ★ 有场景图时 → 全屏背景图 + 底部渐变遮罩 + 主题标签（与 LocationCard 同风格）
      if (card.sceneImage) {
        portraitDiv.style.backgroundImage = `url('${card.sceneImage}')`;
        portraitDiv.style.backgroundSize = 'cover';
        portraitDiv.style.backgroundPosition = 'center';
        portraitDiv.innerHTML =
          `<div style="width:100%;height:100%;display:flex;flex-direction:column;justify-content:flex-end;align-items:center;padding-bottom:16px;
            background:linear-gradient(to top, rgba(6,8,16,0.55) 0%, rgba(6,8,16,0.25) 35%, transparent 60%);">
            <div style="display:flex;align-items:center;gap:8px;margin-bottom:2px;">
              <span style="font-size:26px;filter:drop-shadow(0 0 8px ${theme.color}88);">${theme.icon}</span>
              <span style="font-size:12px;color:${theme.color};opacity:0.75;font-weight:600;letter-spacing:3px;text-shadow:0 0 12px ${theme.color}44;">${theme.name} · 天道</span>
            </div>
          </div>`;
        this.cardEl.style.backgroundImage = `url('${card.sceneImage}')`;
      } else {
        // 无场景图 → 原有主题图标占位
        this.cardEl.style.backgroundImage = '';
        portraitDiv.style.flexDirection = 'column';
        portraitDiv.style.alignItems = 'center';
        portraitDiv.style.justifyContent = 'center';

        // 主题图标
        const iconEl = document.createElement('div');
        iconEl.className = `special-atmo-icon special-atmo--${theme.bg}`;
        iconEl.textContent = theme.icon;
        iconEl.style.cssText = `font-size:64px;color:${theme.color};opacity:0.8;text-shadow:0 0 40px ${theme.color}44;animation:specialPulse 3s ease-in-out infinite;`;
        portraitDiv.appendChild(iconEl);

        // 主题名
        const labelEl = document.createElement('div');
        labelEl.className = 'special-atmo-label';
        labelEl.textContent = theme.name;
        labelEl.style.cssText = `font-size:11px;color:${theme.color};opacity:0.5;margin-top:8px;letter-spacing:4px;`;
        portraitDiv.appendChild(labelEl);
      }
    } else {
      this.cardEl.style.backgroundImage = card.sceneImage ? `url('${card.sceneImage}')` : '';
    }

    // ── 选择按钮 ──
    this.choiceButtons.forEach(btn => btn.classList.remove('visible'));
    const choiceMap = card.choices;
    if (choiceMap) {
      const labels = { left: '←', right: '→' };
      for (const dir of ['left', 'right']) {
        if (choiceMap[dir]) {
          const btn = this.getChoiceButton(dir);
          if (btn) {
            btn.classList.add('visible');
            btn.querySelector('.choice-text').textContent = `${labels[dir]} ${choiceMap[dir].text}`;
            btn.dataset.combatAction = dir;
          }
        }
      }
    }
    this._currentCardIsCombat = null;
  }

  /**
   * LOCATION 卡渲染 — 使用 SceneLayerSystem 的氛围数据生成视觉主题
   */
  _renderLocationCard(card) {
    this.cardTitle.textContent = card.title;
    this.cardDesc.textContent = card.description;
    this.cardType.textContent = `位置 · ${card.location || '未知'}`;

    // 获取位置氛围数据
    let atmosphere = null;
    if (typeof sceneLayerSystem !== 'undefined' && card.location) {
      atmosphere = sceneLayerSystem.getLocationAtmosphere(card.location);
    }

    // 立绘区：位置主题 —— 有 sceneImage 时用场景图填充，无图时用氛围渐变+大图标
    const portraitDiv = document.getElementById('card-portrait');
    if (portraitDiv) {
      portraitDiv.style.display = 'flex';
      portraitDiv.innerHTML = '';
      const icon = this._locationIcon(card.location);
      const color = atmosphere ? atmosphere.borderColor : '#c9a96e';
      const desc = atmosphere ? atmosphere.description : '';

      try {
        if (card.sceneImage) {
          // 有场景图 → 全屏背景图 + 底部渐变遮罩 + 氛围标签
          portraitDiv.style.backgroundImage = `url('${card.sceneImage}')`;
          portraitDiv.style.backgroundSize = 'cover';
          portraitDiv.style.backgroundPosition = 'center';
          portraitDiv.innerHTML =
            `<div style="width:100%;height:100%;display:flex;flex-direction:column;justify-content:flex-end;align-items:center;padding-bottom:20px;
              background:linear-gradient(to top, rgba(6,8,16,0.55) 0%, rgba(6,8,16,0.25) 35%, transparent 60%);">
              <div style="display:flex;align-items:center;gap:8px;margin-bottom:4px;">
                <span style="font-size:28px;filter:drop-shadow(0 0 8px ${color}88);">${icon}</span>
                <span style="font-size:13px;color:${color};opacity:0.8;font-weight:600;letter-spacing:2px;text-shadow:0 0 12px ${color}44;">${card.location || ''}</span>
              </div>
              <div style="font-size:11px;color:rgba(255,255,255,0.5);letter-spacing:1px;">${desc}</div>
            </div>`;
        } else {
          // 无场景图 → 氛围渐变 + 大图标（原有逻辑增强版）
          portraitDiv.style.backgroundImage = '';
          portraitDiv.innerHTML =
            `<div style="width:100%;height:100%;display:flex;flex-direction:column;align-items:center;justify-content:center;
              background:radial-gradient(ellipse at center, ${color}22 0%, transparent 70%);">
              <div class="card-theme-icon" style="font-size:56px;color:${color};opacity:0.7;text-shadow:0 0 30px ${color}44;animation:themeGlow 3s ease-in-out infinite;">
                ${icon}
              </div>
              <div style="font-size:11px;color:${color};opacity:0.4;margin-top:10px;letter-spacing:3px;">${desc}</div>
            </div>`;
        }
      } catch (e) {
        console.warn('[UI] Location portrait render failed, fallback:', e);
        portraitDiv.style.backgroundImage = '';
        portraitDiv.innerHTML = `<div style="width:100%;height:100%;display:flex;flex-direction:column;align-items:center;justify-content:center;
          background:radial-gradient(ellipse at center, ${color}22 0%, transparent 70%);">
          <div class="card-theme-icon" style="font-size:48px;color:${color};opacity:0.6;">${icon}</div>
          <div style="font-size:11px;color:${color};opacity:0.3;margin-top:8px;">${desc || card.location || ''}</div>
        </div>`;
      }
    }

    this.cardEl.className = 'card card-location';

    // 场景图作为卡牌整体背景（有图时使用，无图时保持底色）
    // 安全兜底：即使 sceneImage 有问题，卡牌也有 background-color 作为底色
    try {
      if (card.sceneImage) {
        this.cardEl.style.backgroundImage = `url('${card.sceneImage}')`;
      } else {
        this.cardEl.style.backgroundImage = 'none';
      }
    } catch (e) {
      console.warn('[UI] Location card bg image failed:', e);
      this.cardEl.style.backgroundImage = 'none';
    }

    // 选择按钮（复用通用选择渲染，带 desc 和 mood）
    this.choiceButtons.forEach(btn => btn.classList.remove('visible'));
    const dirLabels = { left: '\u2190', right: '\u2192', up: '\u2191', down: '\u2193' };
    const dirs = this.game.getAvailableDirections(card);
    dirs.forEach(dir => {
      const btn = this.getChoiceButton(dir);
      const choice = card.choices ? card.choices[dir] : null;
      if (btn && choice) {
        btn.classList.add('visible');
        btn.querySelector('.choice-text').textContent = `${dirLabels[dir]} ${choice.text}`;
        const descEl = btn.querySelector('.choice-desc');
        if (descEl) descEl.textContent = choice.desc || '';
        const mood = this._choiceMood(choice.effects);
        btn.dataset.mood = mood;
      }
    });
  }

  /**
   * 位置图标映射
   */
  _locationIcon(location) {
    const icons = {
      '\u5b97\u95e8': '\u2694',   // 宗门→剑
      '\u574a\u5e02': '\u25c6',   // 坊市→菱形
      '\u79d8\u5883': '\u2606',   // 秘境→星
      '\u6d1e\u5e9c': '\u2302',   // 洞府→屋
      '\u9b54\u57df': '\u2620',   // 魔域→骷髅
      '\u5929\u9053\u865a\u7a7a': '\u2726', // 天道虚空→星花
      '\u5251\u5d16': '\u2020',   // 剑崖→十字剑
      '\u85cf\u7ecf\u9601': '\u2316', // 藏经阁→定位
      '\u4e39\u623f': '\u25b3',   // 丹房→三角
      '\u4e07\u5b9d\u697c': '\u25a3', // 万宝楼→方块
    };
    return icons[location] || '\u2316'; // 默认定位图标
  }

  /**
   * 无 NPC 立绘时的通用主题肖像渲染
   * 为所有卡牌类型提供视觉身份——不再有黑洞般的空白立绘区
   */
  _renderThemedPortrait(card, portraitDiv) {
    portraitDiv.style.display = 'flex';
    portraitDiv.innerHTML = '';

    // 类型主题色与图标
    const themes = {
      BOTTLENECK:    { icon: '\u26a1', name: '\u74f6\u9888', color: '#e8a840', glow: '#e8a84044' },
      BREAKTHROUGH:  { icon: '\u2727', name: '\u7a81\u7834', color: '#ffd700', glow: '#ffd70044' },
      KARMA:         { icon: '\u262f', name: '\u56e0\u679c', color: '#d4a574', glow: '#d4a57444' },
      DUNGEON:       { icon: '\u25c6', name: '\u79d8\u5883', color: '#5b7fff', glow: '#5b7fff44' },
      DUNGEON_FORK:  { icon: '\u25c6', name: '\u5c94\u8def', color: '#5b7fff', glow: '#5b7fff44' },
      DESTINY:       { icon: '\u2726', name: '\u5bbf\u547d', color: '#7b68ee', glow: '#7b68ee44' },
      SHOP:          { icon: '\u25c8', name: '\u574a\u5e02', color: '#d4443b', glow: '#d4443b44' },
      COMBAT:        { icon: '\u2694', name: '\u6218\u6597', color: '#c93838', glow: '#c9383844' },
      COMBAT_WARNING:{ icon: '\u26a0', name: '\u9884\u8b66', color: '#e67e22', glow: '#e67e2244' },
      STORY:         { icon: '\u2756', name: '\u6545\u4e8b', color: '#8eb8d0', glow: '#8eb8d044' },
      QUEST:         { icon: '\u25c9', name: '\u652f\u7ebf', color: '#4a7c59', glow: '#4a7c5944' },
      NORMAL:        { icon: '\u2736', name: '\u4e8b\u4ef6', color: '#8899aa', glow: '#8899aa44' },
    };

    const t = themes[card.type] || themes.NORMAL;

    // ★ 有场景图时 → 渲染为背景图 + 底部类型标签（类似 LocationCard）
    if (card.sceneImage) {
      portraitDiv.style.backgroundImage = `url('${card.sceneImage}')`;
      portraitDiv.style.backgroundSize = 'cover';
      portraitDiv.style.backgroundPosition = 'center';
      portraitDiv.innerHTML =
        `<div style="width:100%;height:100%;display:flex;flex-direction:column;justify-content:flex-end;align-items:center;padding-bottom:16px;
          background:linear-gradient(to top, rgba(6,8,16,0.50) 0%, rgba(6,8,16,0.20) 35%, transparent 55%);">
          <div style="display:flex;align-items:center;gap:6px;margin-bottom:2px;">
            <span style="font-size:22px;filter:drop-shadow(0 0 6px ${t.glow});">${t.icon}</span>
            <span style="font-size:11px;color:${t.color};opacity:0.7;font-weight:600;letter-spacing:2px;text-shadow:0 0 10px ${t.glow};">${t.name}</span>
          </div>
        </div>`;
      this.cardEl.style.backgroundImage = `url('${card.sceneImage}')`;
      return;
    }

    // 无场景图 → 原有氛围渐变 + 大图标
    portraitDiv.style.backgroundImage = '';
    portraitDiv.innerHTML =
      `<div style="width:100%;height:100%;display:flex;flex-direction:column;align-items:center;justify-content:center;
        background:radial-gradient(ellipse at center, ${t.glow} 0%, transparent 65%);">
        <div class="card-theme-icon" style="font-size:52px;color:${t.color};opacity:0.65;text-shadow:0 0 28px ${t.glow};animation:themeGlow 3s ease-in-out infinite;">
          ${t.icon}
        </div>
        <div style="font-size:11px;color:${t.color};opacity:0.35;margin-top:10px;letter-spacing:4px;">${t.name}</div>
      </div>`;

    // 透传给 sceneImage 做整体背景（如果存在）
    if (card.sceneImage) {
      this.cardEl.style.backgroundImage = `url('${card.sceneImage}')`;
    } else {
      this.cardEl.style.backgroundImage = 'none';
    }
  }

  getCardTypeName(type) {
    const names = {
      NORMAL: '事件', BOTTLENECK: '瓶颈', KARMA: '因果',
      DUNGEON: '秘境', DUNGEON_FORK: '岔路', DESTINY: '宿命', QUEST: '支线',
      SHOP: '坊市', MARKET: '鬼市', COMBAT: '战斗', COMBAT_WARNING: '预警', COMBAT_UI: '战斗',
      INNER_DEMON: '心魔', DESTINY_WHEEL: '命盘',
      KARMA_RIPPLE: '涟漪', HEAVENS_HINT: '天机', NPC_CROSS: '交叉事件',
      SPECIAL: '天道', LOCATION: '位置', STORY: '故事'
    };
    return names[type] || type;
  }

  getChoiceButton(dir) {
    return {
      left: this.choiceLeft, right: this.choiceRight,
      up: this.choiceUp, down: this.choiceDown
    }[dir];
  }

  makeChoice(dir) {
    if (gameState.dead) { return; }
    const card = this.game.getCurrentCard();

    // ======== COMBAT_UI 战斗选择拦截 ========
    if (card.type === 'COMBAT_UI') {
      const btn = this.getChoiceButton(dir);
      const actionId = btn ? btn.dataset.combatAction : null;
      if (!actionId) return;

      // Animate card away
      const transformMap = {
        left: 'translate(-120%, 0) rotate(-15deg)',
        right: 'translate(120%, 0) rotate(15deg)',
        up: 'translate(0, -120%) rotate(0)',
        down: 'translate(0, 120%) rotate(0)'
      };
      this.cardEl.style.transition = 'transform 0.3s ease, opacity 0.3s ease';
      this.cardEl.style.transform = transformMap[dir] || 'scale(0.8)';
      this.cardEl.style.opacity = '0';

      setTimeout(() => {
        this.game.combatAction(actionId);
        this.cardEl.style.transition = 'none';
        this.cardEl.style.opacity = '1';
        this.cardEl.style.transform = 'translate(0, 0) rotate(0)';
        setTimeout(() => {
          this.cardEl.style.transition = 'transform 0.1s ease';
        }, 50);
      }, 300);
      return;
    }

    // ======== v2.0 心魔反噬/命盘轮转/因果涟漪/天机一闪/集市偶遇 拦截 ========
    if (card.type === 'INNER_DEMON' || card.type === 'DESTINY_WHEEL' ||
        card.type === 'KARMA_RIPPLE' || card.type === 'HEAVENS_HINT' ||
        card.type === 'MARKET') {
      this._animateCardAway(dir, () => {
        try { this.game.makeChoice(dir); } catch (e) { console.error('[UI] special makeChoice failed:', e); }
        this.cardEl.style.transition = 'none';
        this.cardEl.style.opacity = '1';
        this.cardEl.style.transform = 'translate(0, 0) rotate(0)';
        this.cardEl.style.visibility = 'visible';
        setTimeout(() => {
          this.cardEl.style.transition = 'transform 0.1s ease';
          this.cardEl.style.opacity = '1';
        }, 50);
      });
      return;
    }

    if (!card.choices[dir]) { return; }

    // 【沉浸 v2.0】获取选择后果用于涟漪反馈（在 applyEffects 之前捕获）
    const choiceForEcho = card.choices[dir];
    const effectsForEcho = choiceForEcho ? choiceForEcho.effects : null;

    // Animate card away
    this._animateCardAway(dir, () => {
      try {
        this.game.makeChoice(dir);
      } catch (e) {
        console.error('[UI] makeChoice failed:', e);
      }
      this.cardEl.style.transition = 'none';
      this.cardEl.style.opacity = '1';
      this.cardEl.style.transform = 'translate(0, 0) rotate(0)';
      this.cardEl.style.display = '';
      this.cardEl.style.visibility = 'visible';

      // 【沉浸 v2.0】卡面涟漪反馈 — 在效果应用后展示
      if (effectsForEcho) {
        this._showChoiceEcho(effectsForEcho);
      }

      setTimeout(() => {
        this.cardEl.style.transition = 'transform 0.1s ease';
        // 二次安全网：确保 100ms 后卡牌仍然可见（防止被后续动画覆盖）
        this.cardEl.style.opacity = '1';
      }, 50);

      // 三次延迟安全：200ms 后再确认可见（防微任务/异步渲染竞态）
      setTimeout(() => {
        if (this.cardEl.style.opacity === '0') {
          this.cardEl.style.opacity = '1';
          this.cardEl.style.transform = 'translate(0, 0) rotate(0)';
        }
      }, 200);
    });
  }

  // ============ 卡牌滑动动画 ============

  /**
   * 卡牌飞离动画
   * @param {string} dir - 方向
   * @param {Function} callback - 动画完成后的回调
   */
  _animateCardAway(dir, callback) {
    const transformMap = {
      left: 'translate(-120%, 0) rotate(-15deg)',
      right: 'translate(120%, 0) rotate(15deg)',
      up: 'translate(0, -120%) rotate(0)',
      down: 'translate(0, 120%) rotate(0)'
    };
    this.cardEl.style.transition = 'transform 0.3s ease, opacity 0.3s ease';
    this.cardEl.style.transform = transformMap[dir] || 'scale(0.8)';
    this.cardEl.style.opacity = '0';

    setTimeout(() => {
      if (callback) callback();
    }, 300);
  }

  // ============ 沉浸 v2.0：卡面涟漪反馈 ============

  /**
   * 选择生效后，在卡牌上炸出浮动数值
   * 金色上飘=正向，红色下坠=负向
   * @param {Object} effects - 选择的 effects 对象
   */
  _showChoiceEcho(effects) {
    if (!effects || !this.cardEl) return;
    const colors = {
      cultivation: { color: '#f0b232', dir: 'up', icon: '⚔' },
      daoHeart:    { color: '#a371f7', dir: 'up', icon: '\u25c8' },
      karmaGood:   { color: '#3fb950', dir: 'up', icon: '\u25ce' },
      karmaBad:    { color: '#f85149', dir: 'down', icon: '\u25c6' },
      fortune:     { color: '#39d0d8', dir: 'up', icon: '\u2724' },
      health:      { color: '#f85149', dir: 'down', icon: '\u2764' },
      spiritStone: { color: '#f0b232', dir: 'up', icon: '\uD83D\uDC8E' },
      lifespan:    { color: '#fb8500', dir: 'down', icon: '\u23F3' },
    };

    const skipKeys = ['path','reincarnate','pill','treasure','companion','reincarnation_bonus','_innerDemon'];

    for (const [key, value] of Object.entries(effects)) {
      const cfg = colors[key];
      if (!cfg || value === 0 || typeof value !== 'number') continue;
      if (skipKeys.includes(key)) continue;

      const sign = value > 0 ? '+' : '';
      const el = document.createElement('div');
      el.className = 'choice-echo';
      el.textContent = `${cfg.icon} ${sign}${value}`;
      el.style.cssText = `
        left: ${40 + Math.random() * 20}%;
        top: ${30 + Math.random() * 20}%;
        color: ${cfg.color};
        font-size: 1.2rem;
        animation-name: echo-${cfg.dir};
      `;
      this.cardEl.appendChild(el);
      setTimeout(() => el.remove(), 1300);
    }
  }

  /**
   * 选择预兆 — 根据后果主导倾向返回 mood
   * @param {Object} effects
   * @returns {string} 'blessing' | 'danger' | 'tradeoff' | 'neutral'
   */
  _choiceMood(effects) {
    if (!effects) return 'neutral';
    let positive = 0, negative = 0;
    for (const [k, v] of Object.entries(effects)) {
      if (['cultivation','fortune','health','daoHeart','karmaGood','spiritStone','lifespan'].includes(k)) {
        if (v > 0) positive += Math.abs(v);
        if (v < 0) negative += Math.abs(v);
      }
      if (k === 'karmaBad' && v > 0) negative += v;
    }
    if (negative > positive * 1.5) return 'danger';
    if (positive > negative * 1.5) return 'blessing';
    if (negative > 0 && positive > 0) return 'tradeoff';
    return 'neutral';
  }

  // ============ 日志 ============

  addLog(message, cssClass) {
    this.logMessages.unshift({ text: message, cssClass: cssClass || '' });
    if (this.logMessages.length > this.maxLogMessages) {
      this.logMessages.pop();
    }
    this.renderLog();
  }

  renderLog() {
    this.logContainer.innerHTML = this.logMessages
      .map(msg => {
        // 从 cssClass 推断日志类型，用于右侧面板着色
        const dataType = this._logDataType(msg.cssClass);
        if (msg.cssClass === 'thread-complete') {
          // 线程完成消息 → 特殊格式
          const lines = (msg.text || '').split('\n');
          const title = lines[0] || '';
          const note = lines[1] || '';
          const karma = lines[2] || '';
          return `<div class="log-item log-thread-complete" data-type="${dataType}">
            <div class="thread-log-title">${title}</div>
            ${note ? `<div class="thread-log-note">${note}</div>` : ''}
            ${karma ? `<div class="thread-log-karma">${karma}</div>` : ''}
          </div>`;
        }
        return `<div class="log-item ${msg.cssClass || ''}" data-type="${dataType}">${msg.text}</div>`;
      })
      .join('');

    // 更新计数角标
    if (this.logCountEl) {
      this.logCountEl.textContent = this.logMessages.length;
    }
  }

  /** 从 cssClass 推断日志 data-type */
  _logDataType(cssClass) {
    if (!cssClass) return 'choice';
    if (/combat|damage|hp|death/i.test(cssClass)) return 'combat';
    if (/karma|ripple|因果|恶因|善因/i.test(cssClass)) return 'karma';
    if (/quest|支线|mission/i.test(cssClass)) return 'quest';
    if (/realm|breakthrough|突破|境界|chapter/i.test(cssClass)) return 'realm';
    if (/thread|线程|story/i.test(cssClass)) return 'choice';
    return 'choice';
  }

  // ============ 死亡界面 ============

  renderDeathScreen() {
    const state = gameState;
    const playerName = state.playerName || '叶凌云';
    this.deathTitle.textContent = state.deadReason.includes('飞升') ? '功成圆满' : `${playerName} · 道消身陨`;
    this.deathReason.textContent = state.deadReason;
    this.deathStats.innerHTML = `
      <div>${playerName} · ${state.getRealmName(state.realm)}</div>
      <div>存活轮数：${state.turn}</div>
      <div>转世次数：${state.unlocks.endings.length}</div>
      <div>解锁加成：修为+${state.unlocks.bonuses.startCultivation} / 灵石+${state.unlocks.bonuses.startSpiritStone} / 寿元+${state.unlocks.bonuses.maxLifespan}</div>
    `;
    this.reincarnateBtn.textContent = state.deadReason.includes('飞升') ? '飞升后再入轮回' : '转世重修';
  }

  // ============ Touch / Mouse 滑动 ============

  onTouchStart(e) {
    // 不拦截选项按钮的触摸 — 让 click 事件正常触发
    if (e.target.closest('.choice-btn')) return;
    this.startSwipe(e.touches[0].clientX, e.touches[0].clientY);
  }
  onTouchMove(e) { this.moveSwipe(e.touches[0].clientX, e.touches[0].clientY); }
  onTouchEnd(e) { this.endSwipe(); }
  onMouseDown(e) {
    // 不拦截选项按钮的点击 — 让 click 事件正常触发
    if (e.target.closest('.choice-btn')) return;
    this.startSwipe(e.clientX, e.clientY);
    e.preventDefault();
  }
  onMouseMove(e) { if (!this.touching) return; this.moveSwipe(e.clientX, e.clientY); }
  onMouseUp(e) { this.endSwipe(); }

  startSwipe(x, y) {
    this.touching = true;
    this.swipeStartX = x;
    this.swipeStartY = y;
    this.cardStartX = x;
    this.cardStartY = y;
    this.cardCurrentX = 0;
    this.cardCurrentY = 0;
  }

  moveSwipe(x, y) {
    if (!this.touching) return;
    const dx = x - this.cardStartX;
    const dy = y - this.cardStartY;
    // 滑动阻力：重大选择（突破/死亡/战斗）卡牌移动迟缓，感觉"沉重"
    const w = this._getCardWeight();
    const moveX = dx * w;
    const moveY = dy * w;
    this.cardCurrentX = dx;
    this.cardCurrentY = dy;
    // 轻卡旋转更灵巧（dx*0.05），重卡旋转更迟钝（dx*0.03）
    const rotate = dx * (0.03 + w * 0.03);
    this.cardEl.style.transform = `translate(${moveX}px, ${moveY}px) rotate(${rotate}deg)`;
    this.highlightDirection(dx, dy);
  }

  endSwipe() {
    if (!this.touching) return;
    this.touching = false;
    const dx = this.cardCurrentX;
    const dy = this.cardCurrentY;
    // 滑动阻力：重大选择需要更长的滑动距离才能确认
    const w = this._getCardWeight();
    const threshold = this.swipeThreshold * (2 - w);
    let chosenDir = null;

    if (Math.abs(dx) > Math.abs(dy)) {
      if (dx > threshold) chosenDir = 'right';
      if (dx < -threshold) chosenDir = 'left';
    } else {
      if (dy < -threshold) chosenDir = 'up';
      if (dy > threshold) chosenDir = 'down';
    }

    if (chosenDir) {
      this.makeChoice(chosenDir);
    } else {
      this.cardEl.style.transition = 'transform 0.2s ease';
      this.cardEl.style.transform = 'translate(0, 0) rotate(0)';
      setTimeout(() => { this.cardEl.style.transition = 'transform 0.1s ease'; }, 200);
    }

    this.choiceButtons.forEach(btn => btn.classList.remove('highlight'));
  }

  highlightDirection(dx, dy) {
    this.choiceButtons.forEach(btn => btn.classList.remove('highlight'));
    let dir = null;
    if (Math.abs(dx) > Math.abs(dy)) {
      if (dx > this.swipeThreshold) dir = 'right';
      if (dx < -this.swipeThreshold) dir = 'left';
    } else {
      if (dy < -this.swipeThreshold) dir = 'up';
      if (dy > this.swipeThreshold) dir = 'down';
    }
    if (dir) {
      const btn = this.getChoiceButton(dir);
      if (btn) btn.classList.add('highlight');
    }
  }

  /**
   * 滑动阻力 —— 根据卡牌类型返回重量系数
   * 重卡（突破/死亡/战斗）：滑动迟滞，阈值更高 → 感觉"重大决定"
   * 轻卡（探索/坊市）：滑动流畅，阈值正常 → 感觉"日常行动"
   * @returns {number} 0.4~1.0，越小越重
   */
  _getCardWeight() {
    const card = this.currentCard;
    if (!card) return 1.0;
    const type = card.type;
    if (type === 'BOTTLENECK') return 0.40;  // 突破抉择 — 最沉重
    if (type === 'COMBAT_UI')  return 0.45;  // 生死搏杀
    if (type === 'COMBAT')     return 0.50;  // 战斗相关
    if (type === 'INNER_DEMON')return 0.55;  // 心魔对抗
    if (type === 'DESTINY_WHEEL') return 0.60; // 命运轮转
    if (type === 'KARMA')      return 0.65;  // 因果抉择
    if (type === 'QUEST')      return 0.75;  // 支线任务
    if (type === 'FACTION')    return 0.80;  // 势力抉择
    if (type === 'SHOP')       return 0.90;  // 坊市闲逛
    return 1.0; // NORMAL / EXPLORE — 日常轻快
  }

  // ==========================================
  // NPC 人物面板
  // ==========================================

  bindNpcPanels() {
    // 人物列表按钮
    document.getElementById('npc-list-btn').addEventListener('click', () => this.openNpcList());
    // NPC 面板关闭
    document.getElementById('npc-panel-close').addEventListener('click', () => {
      window.litPixelRenderer?.stopLightAnimation();
      document.getElementById('npc-panel').style.display = 'none';
    });
    // 道侣面板关闭
    document.getElementById('comp-panel-close').addEventListener('click', () => {
      window.litPixelRenderer?.stopLightAnimation();
      document.getElementById('companion-panel').style.display = 'none';
    });
    // NPC 列表关闭
    document.getElementById('npc-list-close').addEventListener('click', () => {
      document.getElementById('npc-list-panel').style.display = 'none';
    });
    // 面板背景点击关闭
    document.getElementById('npc-panel').addEventListener('click', (e) => {
      if (e.target === e.currentTarget) {
        window.litPixelRenderer?.stopLightAnimation();
        e.currentTarget.style.display = 'none';
      }
    });
    document.getElementById('companion-panel').addEventListener('click', (e) => {
      if (e.target === e.currentTarget) {
        window.litPixelRenderer?.stopLightAnimation();
        e.currentTarget.style.display = 'none';
      }
    });

    // NPC 交互按钮
    document.querySelectorAll('#npc-panel .npc-action-btn').forEach(btn => {
      btn.addEventListener('click', (e) => {
        const action = e.currentTarget.dataset.action;
        this.handleNpcAction(action);
      });
    });
    // 道侣面板交互按钮
    document.querySelectorAll('#companion-panel .npc-action-btn').forEach(btn => {
      btn.addEventListener('click', (e) => {
        const action = e.currentTarget.dataset.action;
        this.handleCompAction(action);
      });
    });

    // 万物志面板
    this._bindBestiary();

    // 商店面板
    this._bindShopPanel();

    // 卡牌立绘切换按钮
    const switchBtn = document.getElementById('portrait-switch-btn');
    if (switchBtn) {
      switchBtn.addEventListener('click', () => this._cycleCardPortrait());
    }

    // 监听 NPC 交互结果
    eventBus.on('npc:interactionResult', (data) => this._onNpcResult(data));
    eventBus.on('companion:giftResult', (data) => this._onCompResult(data));
    // 监听商店打开
    eventBus.on('shop:open', (data) => this._openShop(data.items || []));
  }

  // ==========================================
  // 商店面板
  // ==========================================

  _bindShopPanel() {
    const shopPanel = document.getElementById('shop-panel');
    const shopClose = document.getElementById('shop-close');
    const shopLeaveBtn = document.getElementById('shop-leave-btn');

    if (shopClose) {
      shopClose.addEventListener('click', () => this._closeShop());
    }
    if (shopLeaveBtn) {
      shopLeaveBtn.addEventListener('click', () => this._closeShop());
    }
    // 背景点击关闭
    if (shopPanel) {
      shopPanel.addEventListener('click', (e) => {
        if (e.target === e.currentTarget) this._closeShop();
      });
    }
  }

  _openShop(data) {
    const panel = document.getElementById('shop-panel');
    const spiritEl = document.getElementById('shop-spirit-stone-val');
    if (spiritEl) spiritEl.textContent = gameState.resources.spiritStone;
    // 标记集市模式
    if (panel) panel.dataset.market = (data && data.market) ? 'true' : 'false';
    this._renderShopItems(data.items || [], data);
    if (panel) panel.style.display = 'flex';
  }

  _closeShop() {
    const panel = document.getElementById('shop-panel');
    if (panel) panel.style.display = 'none';
    eventBus.emit('shop:closed');
  }

  _renderShopItems(items, marketData) {
    const container = document.getElementById('shop-items-container');
    if (!container) return;
    container.innerHTML = '';

    // 集市模式：显示福源档位
    if (marketData && marketData.market) {
      const header = document.createElement('div');
      header.className = 'shop-market-header';
      const marketTitle = document.getElementById('shop-panel-title');
      if (marketTitle) marketTitle.textContent = '🏪 鬼市';
      const pct = marketData.priceMult ? Math.round((marketData.priceMult - 1) * 100) : 0;
      const pctStr = pct >= 0 ? `+${pct}%` : `${pct}%`;
      header.innerHTML = `
        <span class="market-fortune-tag">🕯️ ${marketData.fortuneTier || '未知运道'} · 福源${marketData.fortune || 0}</span>
        <span class="market-price-tag">💰 物价${pctStr}</span>
      `;
      container.appendChild(header);
    } else {
      const marketTitle = document.getElementById('shop-panel-title');
      if (marketTitle) marketTitle.textContent = '🏪 坊市';
    }

    if (!items || items.length === 0) {
      container.innerHTML += '<div style="text-align:center;color:var(--text-secondary);padding:20px;">今日无货。</div>';
      return;
    }

    const currentStone = gameState.resources.spiritStone;

    for (const item of items) {
      const price = item.displayPrice || item.price;
      const canAfford = currentStone >= price;
      const el = document.createElement('div');

      // 稀有度样式
      const rarityClass = item.rarityName ? ' shop-item-rarity-' + item.rarity : '';
      el.className = 'shop-item' + (canAfford ? '' : ' disabled') + rarityClass + (item._marketItem ? ' market-item' : '');

      // 类型标签
      const typeLabel = item.typeLabel || (item.type === 'pill' ? '💊 丹药' :
        item.type === 'treasure' ? '🗡 法宝' : item.type === 'npc_favor' ? '🎁 人情' : '📦 杂物');
      const rarityName = item.rarityName || '';

      el.innerHTML = `
        <div class="shop-item-header">
          <span class="shop-item-name">${rarityName ? '<span class="rarity-badge">' + rarityName + '</span> ' : ''}${item.name}</span>
          <span class="shop-item-price">${price} 🪙</span>
        </div>
        <div class="shop-item-desc">${item.desc || ''}</div>
        <div class="shop-item-type">${typeLabel}</div>
        <button class="shop-buy-btn" data-item-id="${item.id}" ${canAfford ? '' : 'disabled'}>
          ${canAfford ? '购买' : '灵石不足'}
        </button>
      `;

      const buyBtn = el.querySelector('.shop-buy-btn');
      if (buyBtn && canAfford) {
        buyBtn.addEventListener('click', (e) => {
          e.stopPropagation();
          this._handleShopBuy(item.id);
        });
      }

      container.appendChild(el);
    }
  }

  _handleShopBuy(itemId) {
    if (typeof shopSystem === 'undefined' || !shopSystem) return;

    const result = shopSystem.purchase(itemId);
    if (!result.success) {
      this._showShopToast(result.message || '购买失败');
      return;
    }

    // 更新灵石显示
    const spiritEl = document.getElementById('shop-spirit-stone-val');
    if (spiritEl) spiritEl.textContent = gameState.resources.spiritStone;

    // 重新渲染商品列表（刷新购买状态）
    const panel = document.getElementById('shop-panel');
    if (panel && panel.style.display !== 'none') {
      // 检查是否在集市模式
      const isMarket = panel.dataset.market === 'true';
      let items, marketData;
      if (isMarket && typeof marketSystem !== 'undefined' && marketSystem) {
        items = marketSystem.getCurrentMarketItems();
        marketData = {
          market: true,
          fortuneTier: marketSystem.getFortuneTierText(),
          priceMult: marketSystem.getPriceMultiplier(),
          fortune: gameState.attributes.fortune
        };
      } else {
        items = shopSystem.getAvailableItems(gameState.realm);
        marketData = null;
      }
      this._renderShopItems(items, marketData);
    }

    // 显示结果
    let msg = `购买了 ${itemId}`;
    if (result.result) {
      if (result.result.type === 'pill') msg = `获得丹药：${result.result.pillId}`;
      else if (result.result.type === 'treasure') msg = `获得法宝：${result.result.treasureId}`;
      else if (result.result.type === 'heal') msg = `恢复气血 ${result.result.amount}`;
    }
    this._showShopToast(msg);

    // 重新渲染游戏界面（灵石等可能变化）
    this.renderGame();
  }

  _showShopToast(msg) {
    const panel = document.getElementById('shop-panel');
    if (!panel) return;
    let toast = panel.querySelector('.shop-result-toast');
    if (!toast) {
      toast = document.createElement('div');
      toast.className = 'shop-result-toast';
      panel.querySelector('.shop-content').appendChild(toast);
    }
    toast.textContent = msg;
    toast.style.opacity = '1';
    setTimeout(() => { if (toast) toast.style.opacity = '0'; }, 1800);
  }

  /**
   * 打开人物列表
   */
  /**
   * NPC 角色头像映射
   */
  _npcPortraitMap = {
    bai_ren: 'assets/characters/concept_bai_ren_zhenren.webp',
    bai_luoxuan: 'assets/characters/concept_bai_luoxuan.webp',
    jian_linger: 'assets/characters/concept_jian_linger.webp',
    mu_qinglan: 'assets/characters/concept_mu_qinglan.webp',
    yin_xue: 'assets/characters/concept_yin_xue.webp',
    jiuwei_suyue: 'assets/characters/concept_jiuwei_suyue.webp',
    jiuwei:        'assets/characters/concept_jiuwei_suyue.webp',
    // 天机老人/血煞老祖 —— 兼容 arcs.json 旧ID 和 portrait_stages.json 新ID
    tianji_laoren: 'assets/characters/concept_tianji_laoren.webp',
    tian_ji:        'assets/characters/concept_tianji_laoren.webp',
    xuesha_laozu:   'assets/characters/concept_xuesha_laozu.webp',
    xue_sha:        'assets/characters/concept_xuesha_laozu.webp',
    mortal:       'assets/cards/characters/card_sunian_mortal_pc98.png',
    wandering_mortal: 'assets/cards/characters/card_sunian_mortal_pc98.png',
    // ===== 5个随机NPC =====
    wandering_swordsman: 'assets/cards/characters/card_swordsman_wanderer_pc98.png',
    liu_qingluan:    'assets/cards/characters/card_liu_qingluan_pc98.png',
    shi_potian:      'assets/cards/characters/card_shi_potian_pc98.png',
    dieyi_xianzi:    'assets/cards/characters/card_dieyi_xianzi_pc98.png',
    youming_shusheng:'assets/cards/characters/card_youming_shusheng_pc98.png',
    // ===== 青楼角色 =====
    liu_ruyan:       'assets/cards/characters/card_liu_ruyan_pc98.png',
    hua_xiangrong:   'assets/cards/characters/card_hua_xiangrong_pc98.png',
    // ===== demonic_seductress.json NPC → 专属/匹配的女性角色立绘 =====
    ds_bloodrose:    'assets/cards/characters/card_dieyi_xianzi_pc98.png',
    ds_moonmist:     'assets/cards/characters/card_liu_ruyan_pc98.png',
    ds_spiritvine:   'assets/cards/characters/card_hua_xiangrong_pc98.png',
    ds_demoness:     'assets/cards/characters/card_demoness_pc98.png',
    ds_traveler:     'assets/cards/characters/card_liu_qingluan_pc98.png',
    ds_alchemist:    'assets/cards/characters/card_liu_qingluan_pc98.png',
    ds_bandit_queen: 'assets/cards/characters/card_bandit_queen_pc98.png',
  };

  _getNpcPortrait(npcId) {
    return this._npcPortraitMap[npcId] || 'assets/characters/concept_bai_luoxuan.webp';
  }

  /**
   * 回退方案：当 LitPixelRenderer 不可用时，用 Canvas2D 画静态贴图。
   */
  _fallbackAvatar(canvas, npcId) {
    const img = new Image();
    img.onload = () => {
      canvas.width  = img.width;
      canvas.height = img.height;
      const ctx = canvas.getContext('2d');
      ctx.imageSmoothingEnabled = false;
      ctx.drawImage(img, 0, 0);
    };
    img.onerror = () => {
      // 图像加载失败——画占位符
      canvas.width = 256;
      canvas.height = 256;
      const ctx = canvas.getContext('2d');
      ctx.fillStyle = '#1a1a2e';
      ctx.fillRect(0, 0, canvas.width, canvas.height);
      ctx.fillStyle = '#888';
      ctx.font = 'bold 20px sans-serif';
      ctx.textAlign = 'center';
      ctx.fillText('?', canvas.width / 2, canvas.height / 2 + 8);
      ctx.fillText(npcId || '???', canvas.width / 2, canvas.height / 2 - 20);
    };
    img.src = this._getNpcPortrait(npcId);
  }

  /**
   * 在卡牌上渲染NPC角色立绘（Lit Pixel优先）
   * @param {string} npcId
   * @param {HTMLElement} container
   */
  async _renderCardPortrait(npcId, container) {
    const gen = this._portraitGen; // 捕获当前渲染代际，防止异步竞态覆盖
    try {
      if (this._portraitGen !== gen) return;
      // 清除非 sceneBackdrop 的子元素（保留场景底图层）
      Array.from(container.children).forEach(el => {
        if (!el.classList.contains('card-scene-backdrop')) el.remove();
      });

      // 检查是否有已解锁的立绘阶段
      const unlocked = this._getUnlockedPortraitStages(npcId);
      if (unlocked.length > 0) {
        // 默认显示最高已解锁阶段
        this._cardPortraitIndex = unlocked.length - 1;
        const stage = unlocked[this._cardPortraitIndex];
        await this._renderCardPortraitForStage(npcId, container, stage).catch(err => {
          if (this._portraitGen !== gen) return;
          console.warn('[UI] Stage portrait render failed, falling back:', err);
          this._fallbackCardPortrait(container, npcId);
        });
        if (this._portraitGen !== gen) return;
        this._renderStageIndicator(container, npcId, unlocked, this._cardPortraitIndex);
        this._initPortraitSwipe(npcId, container);
      } else {
        if (this._portraitGen !== gen) return;
        // 非道侣或无阶段数据 — 使用 LitPixel 基础角色
        const lpr = window.litPixelRenderer;
        const charId = this._toLitPixelCharId(npcId);

        if (lpr && lpr.ready) {
          const canvas = document.createElement('canvas');
          canvas.width = 512;
          canvas.height = 768;
          canvas.style.width = '100%';
          canvas.style.height = '100%';
          container.appendChild(canvas);

          try {
            await lpr.renderToCanvas(canvas, charId);
            if (this._portraitGen !== gen) return;
          } catch (e) {
            if (this._portraitGen !== gen) return;
            console.warn('[LitPixel] Card portrait render failed:', e);
            this._fallbackCardPortrait(container, npcId);
          }
        } else {
          if (this._portraitGen !== gen) return;
          this._fallbackCardPortrait(container, npcId);
        }
      }

      if (this._portraitGen !== gen) return;

      // 特定角色的氛围粒子（白狐/狐狸系角色）
      if (npcId === 'bai_luoxuan' || npcId === 'jiuwei_suyue' || npcId === 'jiuwei') {
        container.querySelectorAll('.foxfire-particles').forEach(el => el.remove());
        this._addFoxfireParticles(container);
      }

      // ========== 融合渲染：把生硬贴图变成沉浸式卡牌构图 ==========
      this._addCardFusionOverlays(container, npcId);

      // 更新立绘切换按钮状态
      this._updatePortraitSwitchBtn(npcId);
    } catch (err) {
      if (this._portraitGen !== gen) return;
      console.error('[UI] _renderCardPortrait failed:', err);
      this._fallbackCardPortrait(container, npcId);
    }
  }

  /**
   * 添加狐火粒子效果
   * @param {HTMLElement} container
   */
  _addFoxfireParticles(container) {
    const layer = document.createElement('div');
    layer.className = 'foxfire-particles';
    for (let i = 0; i < 12; i++) {
      const mote = document.createElement('div');
      mote.className = 'foxfire-mote';
      mote.style.left = `${10 + Math.random() * 80}%`;
      mote.style.top = `${20 + Math.random() * 60}%`;
      mote.style.setProperty('--dur', `${3 + Math.random() * 5}s`);
      mote.style.setProperty('--delay', `${Math.random() * 6}s`);
      mote.style.setProperty('--rise', `${-30 - Math.random() * 50}px`);
      mote.style.setProperty('--drift', `${(Math.random() - 0.5) * 40}px`);
      layer.appendChild(mote);
    }
    container.appendChild(layer);
  }

  /**
   * ============================================================
   *  多层融合渲染系统 — 把硬切边的立绘贴图变成沉浸式卡牌构图
   * ============================================================
   *
   *  问题：立绘图片自带场景背景（庙宇/山峰），卡牌背景是另一幅图。
   *       直接叠加 → 两张不同的图，像抠图贴纸，没有"融入"感。
   *
   *  方案：注入 4 层融合 overlay，从上到下形成统一的视觉空间：
   *
   *  ① atmo-haze  — 氛围色雾层（统一色温，按卡牌类型变色）
   *     例：因果卡=紫雾，秘境卡=青雾，瓶颈卡=金雾
   *
   *  ② inner-vignette — 内暗角（从立绘边缘向内渐暗，软化矩形边界）
   *
   *  ③ bottom-fade — 底部融入面（立绘底部渐暗融入卡牌底色）
   *
   *  ④ depth-shadow — 深度投影（角色"浮"在卡牌场景中的光影）
   */
  _addCardFusionOverlays(container, npcId) {
    // 清除旧的融合层
    container.querySelectorAll('.portrait-fusion-overlay').forEach(el => el.remove());

    // 获取当前卡牌类型，确定色温方案
    const card = this.game.getCurrentCard();
    const cardType = (card && card.type) ? card.type : 'NORMAL';
    const typeKey = cardType.toLowerCase();

    // 角色类型识别（用于角色专属色调）
    const isFox = npcId === 'bai_luoxuan' || npcId === 'jiuwei_suyue' || npcId === 'jiuwei';
    const isSword = npcId === 'jian_linger' || npcId === 'bai_ren';
    const isDark = npcId === 'yin_xue' || npcId === 'xuesha_laozu';

    // 容器设置 data 属性，CSS 可据此调整
    container.setAttribute('data-card-type', typeKey);
    container.setAttribute('data-npc', npcId);

    // —— ① 氛围色雾 (atmosphere haze) ——
    const haze = document.createElement('div');
    haze.className = 'portrait-fusion-overlay portrait-atmo-haze';
    container.appendChild(haze);

    // —— ② 内暗角 (inner vignette) ——
    const vignette = document.createElement('div');
    vignette.className = 'portrait-fusion-overlay portrait-inner-vignette';
    container.appendChild(vignette);

    // —— ③ 底部融入面 (bottom fade to card surface) ——
    const bottomFade = document.createElement('div');
    bottomFade.className = 'portrait-fusion-overlay portrait-bottom-fade';
    container.appendChild(bottomFade);

    // —— ④ 深度投影 (depth shadow behind portrait, gives 3D lift) ——
    const depthShadow = document.createElement('div');
    depthShadow.className = 'portrait-fusion-overlay portrait-depth-shadow';
    container.appendChild(depthShadow);
  }

  /**
   * 将 NPC/道侣 ID 映射到 LitPixel 角色贴图 ID
   */
  _toLitPixelCharId(npcId) {
    const map = {
      bai_ren: 'bai_ren_zhenren',
      bai_luoxuan: 'bai_luoxuan',
      jian_linger: 'jian_linger',
      mu_qinglan: 'mu_qinglan',
      yin_xue: 'yin_xue',
      jiuwei_suyue: 'jiuwei_suyue',
      jiuwei:        'jiuwei_suyue',
      tianji_laoren: 'tianji_laoren',
      tian_ji:       'tianji_laoren',
      xuesha_laozu: 'xuesha_laozu',
      xue_sha:      'xuesha_laozu',
      // demonic_seductress NPCs → 映射到风格匹配的已有角色（LitPixel 无专属定义，回退到静态图）
      ds_bloodrose: 'yin_xue',
      ds_moonmist: 'jiuwei_suyue',
      ds_spiritvine: 'mu_qinglan',
      ds_demoness: 'yin_xue',
      ds_traveler: 'bai_luoxuan',
      ds_alchemist: 'bai_luoxuan',
      ds_bandit_queen: 'yin_xue',
    };
    return map[npcId] || npcId;
  }

  _fallbackCardPortrait(container, npcId, assetPath) {
    const img = document.createElement('img');
    img.src = assetPath || this._getNpcPortrait(npcId);
    img.alt = npcId;
    img.style.width = '100%';
    img.style.height = '100%';
    img.style.objectFit = 'contain';
    img.style.background = 'rgba(0, 0, 0, 0.3)';
    img.onerror = () => {
      // 立绘加载失败 → 显示像素风格占位角色
      img.style.display = 'none';
      const placeholder = document.createElement('div');
      placeholder.className = 'portrait-placeholder';
      placeholder.innerHTML = `<div style="
        width:100%;height:100%;display:flex;flex-direction:column;align-items:center;justify-content:center;
        background:linear-gradient(135deg,#1a1a2e,#16213e);color:#8899b0;font-size:0.8rem;
      "><span style="font-size:2rem;">⚔</span><span>${npcId || '???'}</span></div>`;
      container.appendChild(placeholder);
    };
    container.appendChild(img);
  }

  async openNpcList() {
    const visible = npcSystem.getVisibleNpcs();
    const container = document.getElementById('npc-list-container');
    const companions = gameState.resources.companions || [];

    const lpr = window.litPixelRenderer;
    // 批量预渲染缩略图（36×36，并行）
    const thumbnailCache = {};
    if (lpr && lpr.ready) {
      await Promise.all(visible.map(async (npc) => {
        try {
          const url = await lpr.renderToDataURL(npc.id, 72, 108); // 2x for retina
          thumbnailCache[npc.id] = url;
        } catch (e) {
          thumbnailCache[npc.id] = this._getNpcPortrait(npc.id);
        }
      }));
    }

    container.innerHTML = visible.map(npc => {
      const isComp = companions.includes(npc.id);
      const src = thumbnailCache[npc.id] || this._getNpcPortrait(npc.id);
      return `<div class="npc-list-card" data-npc="${npc.id}">
        <img class="npc-list-avatar-img" src="${src}" alt="${npc.name}">
        <span class="npc-list-name">${npc.name}</span>
        <span class="npc-list-title">${npc.title}</span>
        ${isComp ? '<span class="npc-list-comp-badge">道侣</span>' : ''}
      </div>`;
    }).join('');

    // 点击NPC卡片打开人物面板
    container.querySelectorAll('.npc-list-card').forEach(card => {
      card.addEventListener('click', () => {
        const npcId = card.dataset.npc;
        document.getElementById('npc-list-panel').style.display = 'none';
        this.openNpcPanel(npcId);
      });
    });

    document.getElementById('npc-list-panel').style.display = 'flex';
  }

  /**
   * 打开 NPC 人物面板
   */
  async openNpcPanel(npcId) {
    const panel = document.getElementById('npc-panel');
    // 请求面板数据（once 自动清理，无需 manual off）
    let panelData = null;
    const handler = (data) => { panelData = data; };
    eventBus.once('npc:panelData', handler);
    eventBus.emit('npc:getPanelData', { npcId });

    if (!panelData || panelData.error) return;

    const d = panelData;
    const isComp = npcSystem.isCompanion(npcId);
    const bondNames = ['陌路','相识','挚友','知己','生死','天命'];

    // Header — 使用 Lit Pixel 渲染器
    const lpr = window.litPixelRenderer;
    const npcCanvas = document.getElementById('npc-avatar-canvas');
    if (lpr && lpr.ready && lpr.textureCache.has(npcId)) {
      try {
        await lpr.renderToCanvas(npcCanvas, npcId);
        // 开启光照旋转动画展示法线贴图效果
        lpr.startLightAnimation(npcCanvas, npcId);
      } catch (e) {
        console.warn('[LitPixel] render failed, fallback to static:', e);
        this._fallbackAvatar(npcCanvas, npcId);
      }
    } else {
      this._fallbackAvatar(npcCanvas, npcId);
    }
    document.getElementById('npc-name').textContent = d.npc.name + (isComp ? ' ♥' : '');
    document.getElementById('npc-subtitle').textContent = d.npc.title || '';
    document.getElementById('npc-relationship').textContent =
      `${d.impression.overall} | 好感:${d.affection} | 羁绊:${bondNames[d.bond]}`;

    // Mood
    document.getElementById('npc-emotion').textContent = d.emotion;
    document.getElementById('npc-mindset').textContent = d.mindset;
    document.getElementById('npc-location').textContent = d.location;

    // Dialogue
    const dialogue = npcSystem.getDialogue(npcId, '闲聊');
    document.getElementById('npc-dialogue').textContent = dialogue ? `"${dialogue}"` : '...';

    // 交互按钮可见性
    document.querySelectorAll('#npc-panel .npc-action-btn').forEach(btn => {
      const action = btn.dataset.action;
      if (action === '告辞') { btn.style.display = 'inline-block'; return; }
      if (action === '赠礼' && d.affection < 0) { btn.style.display = 'none'; return; }
      btn.style.display = d.availableActions.includes(action) ? 'inline-block' : 'none';
    });

    // 交互记录
    const interDiv = document.getElementById('npc-interactions');
    if (d.recentInteractions.length === 0) {
      interDiv.innerHTML = '<div class="npc-detail-item dim">暂无互动记录</div>';
    } else {
      interDiv.innerHTML = d.recentInteractions.map(m =>
        `<div class="npc-detail-item">第${m.turn}轮 · ${m.action}: ${m.reaction}</div>`
      ).join('');
    }

    // 已知信息
    const infoDiv = document.getElementById('npc-known-info');
    if (!d.knownInfo || d.knownInfo.length === 0) {
      infoDiv.innerHTML = '<div class="npc-detail-item dim">尚不了解此人</div>';
    } else {
      infoDiv.innerHTML = d.knownInfo.map(i =>
        `<div class="npc-detail-item ${i.unlocked ? '' : 'locked'}">${i.unlocked ? i.text : '🔒 尚未知晓'}</div>`
      ).join('');
    }

    // 隐藏上次结果
    document.getElementById('npc-result').style.display = 'none';

    // 记录当前打开的NPC ID
    panel.dataset.npcId = npcId;
    panel.style.display = 'flex';
  }

  /**
   * NPC 交互按钮处理
   */
  handleNpcAction(action) {
    const panel = document.getElementById('npc-panel');
    const npcId = panel.dataset.npcId;
    if (!npcId) return;

    if (action === '告辞') {
      window.litPixelRenderer?.stopLightAnimation();
      panel.style.display = 'none';
      return;
    }

    eventBus.emit('npc:interact', { npcId, action, itemId: 'generic_gift' });
  }

  _onNpcResult(data) {
    const resultDiv = document.getElementById('npc-result');
    const affStr = data.affDelta > 0 ? `好感 +${data.affDelta}` :
                   data.affDelta < 0 ? `好感 ${data.affDelta}` : '';
    resultDiv.innerHTML = `<p>${data.reaction.replace(/\n/g, '<br>')}</p><p class="aff-delta">${affStr}</p>`;
    resultDiv.style.display = 'block';

    // 更新道侣面板数据（如果已激活）
    this.addLog(`${npcSystem.getNpcName(data.npcId)}: ${data.reaction.split('\n')[0]}`);

    // 刷新面板
    setTimeout(() => this.openNpcPanel(data.npcId), 500);
  }

  // ==========================================
  // 道侣面板
  // ==========================================

  /**
   * 打开道侣面板
   */
  async openCompanionPanel(compId) {
    const panel = document.getElementById('companion-panel');
    let panelData = null;
    const handler = (data) => { panelData = data; };
    eventBus.once('companion:panelData', handler);
    eventBus.emit('companion:getPanelData', { compId });

    if (!panelData || panelData.error) return;

    const d = panelData;
    const emotionIcon = { '平静':'😐','欣喜':'😊','忧心':'😔','愤怒':'😠','哀伤':'😢' };
    const bondNames = ['陌路','相识','挚友','知己','生死','天命'];

    // Avatar — 使用 Lit Pixel 渲染器
    const lpr = window.litPixelRenderer;
    const compCanvas = document.getElementById('comp-avatar-canvas');
    if (lpr && lpr.ready && lpr.textureCache.has(compId)) {
      try {
        await lpr.renderToCanvas(compCanvas, compId);
        lpr.startLightAnimation(compCanvas, compId);
      } catch (e) {
        this._fallbackAvatar(compCanvas, compId);
      }
    } else {
      this._fallbackAvatar(compCanvas, compId);
    }
    document.getElementById('comp-name').textContent = d.name;
    document.getElementById('comp-subtitle').textContent = d.title;
    document.getElementById('comp-emotion').textContent = d.emotion;
    document.getElementById('comp-location').textContent = d.location;

    // 好感/羁绊/信任条
    document.getElementById('comp-aff-bar').style.width = d.affection + '%';
    document.getElementById('comp-aff-val').textContent = d.affection;
    document.getElementById('comp-bond-bar').style.width = (d.bond / 5 * 100) + '%';
    document.getElementById('comp-bond-val').textContent = 'Lv' + d.bond + ' ' + bondNames[d.bond];
    document.getElementById('comp-trust-bar').style.width = d.trust + '%';
    document.getElementById('comp-trust-val').textContent = d.trust;

    // 道侣台词
    const dialogue = npcSystem.getDialogue(compId, '修炼');
    document.getElementById('comp-dialogue').textContent = dialogue ? `"${dialogue}"` : '...';

    // 事件历史
    const eventsDiv = document.getElementById('comp-events');
    if (!d.recentEvents || d.recentEvents.length === 0) {
      eventsDiv.innerHTML = '<div class="npc-detail-item dim">暂无道侣事件</div>';
    } else {
      eventsDiv.innerHTML = d.recentEvents.map(m =>
        `<div class="npc-detail-item">第${m.turn}轮 · ${m.action || '互动'}: ${m.reaction || ''}</div>`
      ).join('');
    }

    document.getElementById('comp-result').style.display = 'none';
    panel.dataset.compId = compId;
    panel.style.display = 'flex';
  }

  handleCompAction(action) {
    const panel = document.getElementById('companion-panel');
    const compId = panel.dataset.compId;
    if (!compId) return;

    if (action === '告辞') {
      window.litPixelRenderer?.stopLightAnimation();
      panel.style.display = 'none';
      return;
    }

    if (action === '赠礼') {
      eventBus.emit('companion:gift', { compId, itemId: 'generic_gift' });
    } else {
      eventBus.emit('npc:interact', { npcId: compId, action, itemId: null });
    }
  }

  _onCompResult(data) {
    const resultDiv = document.getElementById('comp-result');
    const affStr = data.delta > 0 ? `好感 +${data.delta}` : data.delta < 0 ? `好感 ${data.delta}` : '';
    resultDiv.innerHTML = `<p>${data.reaction}</p><p class="aff-delta">${affStr}</p>`;
    resultDiv.style.display = 'block';
    this.addLog(`道侣: ${data.reaction}`);
  }

  // ==========================================
  // 万物志面板
  // ==========================================

  /** 缓存：加载 portrait_stages.json（延迟加载） */
  _portraitStagesData = null;
  /** 当前查看的道侣ID */
  _bestiaryCurrentComp = null;
  /** 卡牌上当前选择展示的立绘阶段索引 */
  _cardPortraitIndex = 0;

  _bindBestiary() {
    // 打开万物志按钮
    document.getElementById('bestiary-btn').addEventListener('click', () => this.openBestiary());
    // 关闭
    document.getElementById('bestiary-close').addEventListener('click', () => {
      document.getElementById('bestiary-panel').style.display = 'none';
    });
    // 背景点击关闭
    document.getElementById('bestiary-panel').addEventListener('click', (e) => {
      if (e.target === e.currentTarget) {
        e.currentTarget.style.display = 'none';
      }
    });
    // 返回按钮（从立绘查看器回到列表）
    document.getElementById('bestiary-portrait-back').addEventListener('click', () => {
      this._hidePortraitViewer();
    });
    // 标签切换
    document.querySelectorAll('.bestiary-tab').forEach(tab => {
      tab.addEventListener('click', () => {
        const tabName = tab.dataset.tab;
        this._switchBestiaryTab(tabName);
      });
    });
  }

  /**
   * 加载 portrait_stages.json（若尚未加载）
   */
  _loadPortraitStages() {
    if (this._portraitStagesData) return this._portraitStagesData;
    // 从 DataLoader 尝试加载，失败则从 DATA_MODULES 读取
    try {
      const raw = dataLoader ? dataLoader.loadSync('companions:portrait_stages') : null;
      if (raw && raw.portraitStages) {
        this._portraitStagesData = raw;
        return raw;
      }
    } catch (e) {}
    // 备用：内联数据
    if (typeof DATA_MODULES !== 'undefined' && DATA_MODULES['companions:portrait_stages']) {
      this._portraitStagesData = DATA_MODULES['companions:portrait_stages'];
      return this._portraitStagesData;
    }
    return { portraitStages: {} };
  }

  /**
   * 打开万物志面板
   */
  openBestiary() {
    const panel = document.getElementById('bestiary-panel');
    panel.style.display = 'flex';
    this._hidePortraitViewer();
    this._switchBestiaryTab('companions');
  }

  /**
   * 切换万物志标签页
   */
  _switchBestiaryTab(tabName) {
    // 更新标签按钮状态
    document.querySelectorAll('.bestiary-tab').forEach(t => t.classList.remove('active'));
    document.querySelector(`.bestiary-tab[data-tab="${tabName}"]`)?.classList.add('active');
    // 显示对应内容
    document.querySelectorAll('.bestiary-tab-content').forEach(c => c.style.display = 'none');
    const contentEl = document.getElementById(`bestiary-${tabName}`);
    if (contentEl) contentEl.style.display = 'block';

    // 渲染对应内容
    if (tabName === 'companions') this._renderBestiaryCompanions();
    else if (tabName === 'items') this._renderBestiaryItems();
    else if (tabName === 'techniques') this._renderBestiaryTechniques();
    else if (tabName === 'fragments') this._renderBestiaryFragments();
  }

  /**
   * 渲染道侣列表（万物志-道侣标签页）
   */
  _renderBestiaryCompanions() {
    const stagesData = this._loadPortraitStages();
    const container = document.getElementById('bestiary-companion-list');
    const companionIds = gameState.resources.companions || [];
    const allStageIds = Object.keys(stagesData.portraitStages || {});

    if (allStageIds.length === 0) {
      container.innerHTML = '<div class="bestiary-locked-hint">万物志尚未收录道侣信息。随着仙途推进，这里将记录你的每一位道侣。</div>';
      return;
    }

    container.innerHTML = allStageIds.map(compId => {
      const compStages = stagesData.portraitStages[compId];
      // 判断是否已结交（查两处：资源列表 + 道侣系统状态）
      const metInResources = companionIds.includes(compId);
      const metInSystem = typeof companionSystem !== 'undefined' && companionSystem.states[compId];
      const isCompanion = metInResources || metInSystem;
      const affection = isCompanion && typeof companionSystem !== 'undefined'
        ? (companionSystem.getState(compId)?.affection || 0) : 0;

      // 统计已解锁阶段数
      const unlockedCount = compStages.stages.filter(s => s.affection <= affection).length;
      const totalStages = compStages.stages.length;
      // 阶段小圆点
      const dots = compStages.stages.map(s => {
        const unlocked = s.affection <= affection;
        const adultClass = s.adultContent ? 'adult-content' : '';
        return `<span class="bestiary-stage-dot ${unlocked ? 'unlocked' : ''} ${adultClass}"></span>`;
      }).join('');

      // 缩略图：使用第一个已解锁的立绘
      const firstUnlocked = compStages.stages.filter(s => s.affection <= affection).pop();
      const thumbSrc = firstUnlocked
        ? this._getNpcPortrait(compId)
        : this._getNpcPortrait(compId);

      const lockClass = isCompanion ? '' : 'locked';

      return `
        <div class="bestiary-companion-card ${lockClass}" data-comp="${compId}">
          <div class="bestiary-comp-thumb">
            <img src="${thumbSrc}" alt="${compStages.name}">
          </div>
          <div class="bestiary-comp-info">
            <div class="bestiary-comp-name">${compStages.name} ${isCompanion ? '♥' : ''}</div>
            <div class="bestiary-comp-title">立绘 ${unlockedCount}/${totalStages}</div>
            <div class="bestiary-comp-stages">${dots}</div>
          </div>
          <div class="bestiary-comp-arrow">${isCompanion ? '→' : '🔒'}</div>
        </div>`;
    }).join('');

    // 绑定点击事件 — 允许查看所有收录道侣的立绘阶段（含未结交者）
    container.querySelectorAll('.bestiary-companion-card').forEach(card => {
      card.addEventListener('click', () => {
        const compId = card.dataset.comp;
        this._showCompanionPortraits(compId);
      });
    });
  }

  /**
   * 渲染万物标签页 — 物品
   */
  _renderBestiaryItems() {
    // 灵石资源
    const resourcesDiv = document.getElementById('bestiary-resources');
    resourcesDiv.innerHTML = `
      <div class="bestiary-item-card">
        <div class="bestiary-item-icon">💎</div>
        <div class="bestiary-item-name">灵石</div>
        <div class="bestiary-item-desc">修仙界的通用货币。可用于购买丹药、法宝、贿赂、拍卖。当前持有：${gameState.resources.spiritStone || 0}</div>
      </div>
      <div class="bestiary-item-card">
        <div class="bestiary-item-icon">⏳</div>
        <div class="bestiary-item-name">寿元</div>
        <div class="bestiary-item-desc">修士的寿命。每突破一大境界可大幅延长。寿尽则道消。剩余：${gameState.resources.lifespan || 0}轮</div>
      </div>
    `;

    // 法宝
    const treasuresDiv = document.getElementById('bestiary-treasures');
    const treasures = gameState.resources.treasures || [];
    if (treasures.length === 0) {
      treasuresDiv.innerHTML = '<div class="bestiary-locked-hint">尚未获得任何法宝。探索秘境、完成支线可获得法宝。</div>';
    } else {
      treasuresDiv.innerHTML = treasures.map(t => `
        <div class="bestiary-item-card">
          <div class="bestiary-item-icon">🗡</div>
          <div class="bestiary-item-name">${t}</div>
          <div class="bestiary-item-desc">${treasureSystem ? treasureSystem.getDescription?.(t) || '' : ''}</div>
        </div>
      `).join('');
    }

    // 丹药
    const pillsDiv = document.getElementById('bestiary-pills');
    const pills = gameState.resources.pills || [];
    const pillNames = { foundation: '筑基丹', golden: '结金丹', nascent: '凝婴丹', deity: '化神丹', tribulation: '渡劫丹' };
    if (pills.length === 0) {
      pillsDiv.innerHTML = '<div class="bestiary-locked-hint">尚未获得任何丹药。可在商店购买或通过支线任务获得。</div>';
    } else {
      pillsDiv.innerHTML = pills.map(p => `
        <div class="bestiary-item-card">
          <div class="bestiary-item-icon">💊</div>
          <div class="bestiary-item-name">${pillNames[p] || p}</div>
          <div class="bestiary-item-desc">突破境界的必需之物。服用可100%成功突破。</div>
        </div>
      `).join('');
    }
  }

  /**
   * 渲染功法标签页
   */
  _renderBestiaryTechniques() {
    const pathNameEl = document.getElementById('bestiary-path-name');
    const skillsList = document.getElementById('bestiary-skills-list');
    const path = gameState.path;
    const pathName = gameState.getPathName(path);

    pathNameEl.textContent = `当前功法：${pathName}`;

    // 从 pathSkillSystem 获取技能列表
    const skills = typeof pathSkillSystem !== 'undefined' && pathSkillSystem
      ? (pathSkillSystem._skills?.[path] || []) : [];

    if (skills.length === 0) {
      skillsList.innerHTML = '<div class="bestiary-locked-hint">尚未解锁功法技能。突破境界后可解锁对应技能。</div>';
      return;
    }

    const currentRealmIdx = gameState.getRealmIndex ? gameState.getRealmIndex() : 0;

    skillsList.innerHTML = skills.map(skill => {
      const unlocked = skill.unlockRealm
        ? (gameState.config?.realms?.realms?.[skill.unlockRealm]?.index ?? 99) <= currentRealmIdx
        : false;

      return `
        <div class="bestiary-skill-card ${unlocked ? 'unlocked' : 'locked'}">
          <div class="bestiary-skill-name">${skill.name}</div>
          <div class="bestiary-skill-desc">${skill.desc}</div>
          ${skill.flavor ? `<div class="bestiary-skill-flavor">"${skill.flavor}"</div>` : ''}
          <span class="bestiary-skill-badge ${unlocked ? 'owned' : 'locked-badge'}">
            ${unlocked ? '已解锁' : `需要 ${skill.unlockRealm || '更高境界'}`}
          </span>
        </div>
      `;
    }).join('');
  }

  /**
   * 渲染传承残卷收集面板（万物志-残卷标签页）
   */
  _renderBestiaryFragments() {
    const listEl = document.getElementById('bestiary-fragment-list');
    const bonusesSection = document.getElementById('bestiary-bonuses-section');
    const bonusesList = document.getElementById('bestiary-bonuses-list');

    if (!listEl) return;

    const progress = typeof legacyFragmentSystem !== 'undefined'
      ? legacyFragmentSystem.getProgress()
      : {};
    const bonuses = typeof legacyFragmentSystem !== 'undefined'
      ? legacyFragmentSystem.getPassiveBonuses()
      : {};

    const setIds = Object.keys(progress);
    if (setIds.length === 0) {
      listEl.innerHTML = '<div class="bestiary-locked-hint">传承残卷尚未激活。随着仙途推进，你将有机会收集散落各界的上古传承碎片。</div>';
      bonusesSection.style.display = 'none';
      return;
    }

    // 渲染 6 套传承卡片
    listEl.innerHTML = setIds.map(setId => {
      const set = progress[setId];
      const pct = Math.round((set.count / set.total) * 100);
      const filledArr = Array.from({ length: set.total }, (_, i) => i < set.count);

      return `
        <div class="fragment-set-card ${set.completed ? 'completed' : ''}">
          <div class="fragment-set-header">
            <span class="fragment-set-icon">${set.icon}</span>
            <span class="fragment-set-name">${set.name}</span>
            <span class="fragment-set-count">${set.count}/${set.total}</span>
            ${set.completed ? '<span class="fragment-set-badge">✓ 已合成</span>' : ''}
          </div>
          <div class="fragment-progress-bar">
            <div class="fragment-progress-fill" style="width:${pct}%"></div>
          </div>
          <div class="fragment-pieces-grid">
            ${filledArr.map((filled, i) => `
              <div class="fragment-piece ${filled ? 'collected' : 'missing'}" title="碎片 ${i + 1}">
                ${filled ? '◆' : '◇'}
              </div>
            `).join('')}
          </div>
          ${set.completed
            ? `<div class="fragment-set-effect">${this._getFragmentSetEffect(setId)}</div>`
            : `<div class="fragment-set-effect locked-effect">${this._getFragmentSetEffect(setId)}</div>`
          }
        </div>
      `;
    }).join('');

    // 渲染已激活的加成
    const bonusEntries = Object.entries(bonuses);
    if (bonusEntries.length > 0) {
      bonusesSection.style.display = 'block';
      const bonusLabels = {
        atk: '攻击力', def: '防御力', critRate: '暴击率',
        hpRegen: '气血回复/轮', pillBonus: '丹药效果',
        daoResist: '道心抵抗', fortuneBonus: '福缘',
        maxHp: '最大气血', maxLifespan: '寿元上限',
        cultivationBonus: '修为获得', daoHeartPenalty: '道心'
      };
      bonusesList.innerHTML = bonusEntries.map(([key, val]) => {
        const label = bonusLabels[key] || key;
        const isPenalty = val < 0;
        const cls = isPenalty ? 'bonus-penalty' : 'bonus-positive';
        const sign = val > 0 ? '+' : '';
        return `<span class="fragment-bonus-tag ${cls}">${label} ${sign}${val}</span>`;
      }).join('');
    } else {
      bonusesSection.style.display = 'none';
    }
  }

  /**
   * 获取传承套装效果描述
   */
  _getFragmentSetEffect(setId) {
    const effects = {
      sword_heart: '攻击力+10 / 暴击率+8%',
      pill_way: '丹药效果+30% / 气血回复+2/轮',
      array_way: '防御+8 / 道心伤害减免+15%',
      heaven_book: '福缘+10 / 修为获得+20%',
      demon_blood: '攻击+15 / 道心-5（邪恶之道）',
      immortal_will: '最大气血+20 / 寿元上限+10'
    };
    return effects[setId] || '';
  }

  /**
   * 显示道侣立绘查看器
   */
  _showCompanionPortraits(compId) {
    this._bestiaryCurrentComp = compId;
    const stagesData = this._loadPortraitStages();
    const compStages = stagesData.portraitStages[compId];
    if (!compStages) return;

    const affection = typeof companionSystem !== 'undefined'
      ? (companionSystem.getState(compId)?.affection || 0) : 0;

    // 隐藏列表，显示立绘查看器
    document.querySelectorAll('.bestiary-tab-content').forEach(c => c.style.display = 'none');
    document.querySelectorAll('.bestiary-tab').forEach(t => t.classList.remove('active'));
    document.getElementById('bestiary-portrait-viewer').style.display = 'block';

    // 找到当前可用的最高阶段
    const unlockedStages = compStages.stages.filter(s => s.affection <= affection);
    const currentStage = unlockedStages.length > 0 ? unlockedStages[unlockedStages.length - 1] : compStages.stages[0];

    // 渲染立绘
    this._renderPortraitStage(currentStage, compId, compStages);

    // 渲染阶段选择器
    const selector = document.getElementById('bestiary-stage-selector');
    selector.innerHTML = compStages.stages.map((stage, idx) => {
      const unlocked = stage.affection <= affection;
      const isActive = stage.id === currentStage.id;
      const adultClass = stage.adultContent ? 'adult-stage' : '';
      const lockHint = unlocked ? '' : `(需好感${stage.affection})`;
      return `
        <button class="bestiary-stage-btn ${isActive ? 'active' : ''} ${unlocked ? 'unlocked' : 'locked'} ${adultClass}"
                data-stage="${idx}" title="${stage.name} — 好感度${stage.affection}${unlocked ? ' [已解锁]' : ' [未解锁]'}">
          ${unlocked ? stage.name : '🔒 ' + stage.name + ' ' + lockHint}
        </button>`;
    }).join('');

    // 绑定阶段按钮点击
    selector.querySelectorAll('.bestiary-stage-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        const stageIdx = parseInt(btn.dataset.stage);
        const stage = compStages.stages[stageIdx];
        const stageUnlocked = stage.affection <= affection;
        if (!stageUnlocked) return; // 未解锁不可查看

        // 更新选中状态
        selector.querySelectorAll('.bestiary-stage-btn').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');

        // 渲染该阶段立绘
        this._renderPortraitStage(stage, compId, compStages);
      });
    });
  }

  /**
   * 渲染一个具体的立绘阶段
   */
  _renderPortraitStage(stage, compId, compStages) {
    // 阶段信息
    const infoDiv = document.getElementById('bestiary-stage-info');
    infoDiv.innerHTML = `
      <div class="bestiary-stage-name">${stage.name} — ${compStages.name}</div>
      <div class="bestiary-stage-narrative">${stage.narrative}</div>
      <div>
        <span class="bestiary-stage-pose">${stage.pose || ''}</span>
        <span class="bestiary-stage-clothing">${stage.clothing || ''}</span>
        <span class="bestiary-stage-atmo">${stage.atmosphere || ''}</span>
      </div>
    `;

    // 渲染立绘 — 阶段立绘直接加载 stage.asset 静态图
    const canvas = document.getElementById('bestiary-portrait-canvas');
    const ctx = canvas.getContext('2d');
    const lpr = window.litPixelRenderer;
    const charId = this._toLitPixelCharId(compId);

    // 基础阶段用 LitPixel（有法线光照），其余阶段用静态立绘
    if (stage.affection === 0 && lpr && lpr.ready) {
      lpr.renderToCanvas(canvas, charId).catch(() => {
        this._fallbackPortraitStage(canvas, charId, stage.asset);
      });
    } else {
      // 直接加载阶段立绘静态图，并用 crossfade 过渡
      const img = new Image();
      img.onload = () => {
        // crossfade: 先画旧内容半透明，再渐变到新图
        canvas.width = img.width;
        canvas.height = img.height;
        canvas.style.opacity = '0';
        canvas.style.transition = 'opacity 0.4s ease';
        ctx.drawImage(img, 0, 0);
        requestAnimationFrame(() => { canvas.style.opacity = '1'; });
      };
      img.onerror = () => {
        this._fallbackPortraitStage(canvas, compId, stage.asset);
      };
      img.src = stage.asset || this._getNpcPortrait(compId);
    }

    // 如果是成人内容，添加提示
    if (stage.adultContent) {
      infoDiv.querySelector('.bestiary-stage-name').style.color = '#ff6b6b';
    }
  }

  _fallbackPortraitStage(canvas, npcId, assetPath) {
    const img = new Image();
    img.onload = () => {
      canvas.width = img.width;
      canvas.height = img.height;
      const ctx = canvas.getContext('2d');
      ctx.drawImage(img, 0, 0);
    };
    img.onerror = () => {
      canvas.width = 256;
      canvas.height = 256;
      const ctx = canvas.getContext('2d');
      ctx.fillStyle = '#1a1a2e';
      ctx.fillRect(0, 0, canvas.width, canvas.height);
      ctx.fillStyle = '#aaa';
      ctx.font = 'bold 16px sans-serif';
      ctx.textAlign = 'center';
      ctx.fillText('✦', canvas.width / 2, canvas.height / 2);
      ctx.fillText('立绘未就绪', canvas.width / 2, canvas.height / 2 + 30);
    };
    img.src = assetPath || this._getNpcPortrait(npcId);
  }

  /**
   * 隐藏立绘查看器，返回列表视图
   */
  _hidePortraitViewer() {
    document.getElementById('bestiary-portrait-viewer').style.display = 'none';
    this._bestiaryCurrentComp = null;
    // 恢复道侣列表标签
    document.querySelectorAll('.bestiary-tab').forEach(t => t.classList.remove('active'));
    const companionsTab = document.querySelector('.bestiary-tab[data-tab="companions"]');
    if (companionsTab) companionsTab.classList.add('active');
    document.querySelectorAll('.bestiary-tab-content').forEach(c => c.style.display = 'none');
    const compContent = document.getElementById('bestiary-companions');
    if (compContent) compContent.style.display = 'block';
  }

  // ==========================================
  // 卡牌立绘切换
  // ==========================================

  /**
   * 获取当前 NPC 的所有已解锁立绘阶段
   */
  _getUnlockedPortraitStages(npcId) {
    const stagesData = this._loadPortraitStages();
    // 兼容 arcs.json 旧ID → portrait_stages.json 新ID
    const idAlias = { tian_ji: 'tianji_laoren', xue_sha: 'xuesha_laozu', jiuwei: 'jiuwei_suyue' };
    const resolvedId = idAlias[npcId] || npcId;
    const compStages = stagesData.portraitStages[resolvedId];
    if (!compStages) return [];

    // 判断是否已结交（查两处：资源列表 + 道侣系统状态）
    const companionIds = gameState.resources.companions || [];
    const metInResources = companionIds.includes(npcId) || companionIds.includes(resolvedId);
    const metInSystem = typeof companionSystem !== 'undefined' && companionSystem.states &&
      (companionSystem.states[npcId] || companionSystem.states[resolvedId]);
    const isCompanion = metInResources || metInSystem;

    const affection = isCompanion && typeof companionSystem !== 'undefined'
      ? (companionSystem.getState(npcId)?.affection || companionSystem.getState(resolvedId)?.affection || 0) : 0;

    return compStages.stages.filter(s => s.affection <= affection);
  }

  /**
   * 更新卡牌右上角的立绘切换按钮状态
   */
  _updatePortraitSwitchBtn(npcId) {
    const btn = document.getElementById('portrait-switch-btn');
    if (!btn) return;

    const unlocked = this._getUnlockedPortraitStages(npcId);
    if (unlocked.length > 1) {
      btn.style.display = 'flex';
      btn.classList.add('has-multiple');
      btn.title = `${unlocked.length} 个立绘可切换`;
    } else {
      btn.style.display = 'none';
      btn.classList.remove('has-multiple');
    }
    this._cardPortraitIndex = unlocked.length - 1; // 默认显示最高阶段
  }

  /**
   * 循环切换卡牌立绘
   */
  _cycleCardPortrait() {
    const card = this.game.getCurrentCard();
    const npcId = card?.npcId || card?.compId;
    if (!npcId) return;

    const unlocked = this._getUnlockedPortraitStages(npcId);
    if (unlocked.length <= 1) return;

    const next = (this._cardPortraitIndex + 1) % unlocked.length;
    const portraitDiv = document.getElementById('card-portrait');
    if (!portraitDiv) return;

    this._switchToStage(npcId, portraitDiv, next);
  }

  /**
   * 为特定阶段渲染卡牌立绘
   * 基础阶段(affection=0) 用 LitPixel 动态光照；其余阶段直接加载 stage.asset 静态立绘
   */
  async _renderCardPortraitForStage(npcId, container, stage) {
    const isBaseStage = !stage || stage.affection === 0;
    const lpr = window.litPixelRenderer;
    const charId = this._toLitPixelCharId(npcId);

    // 创建新图层（用于 crossfade）
    const newLayer = document.createElement('div');
    newLayer.className = 'portrait-stage-layer';
    newLayer.style.cssText = 'position:absolute;inset:0;z-index:1;opacity:0;transition:opacity 0.4s ease;';

    if (isBaseStage) {
      // 基础阶段 — LitPixel 动态光照渲染
      if (lpr && lpr.ready) {
        const canvas = document.createElement('canvas');
        canvas.width = 512;
        canvas.height = 768;
        canvas.style.cssText = 'width:100%;height:100%;object-fit:contain;image-rendering:pixelated;border-radius:16px;';
        newLayer.appendChild(canvas);

        try {
          await lpr.renderToCanvas(canvas, charId);
        } catch (e) {
          console.warn('[LitPixel] base stage render failed:', e);
          this._fillLayerWithImage(newLayer, stage?.asset || this._getNpcPortrait(npcId));
        }
      } else {
        this._fillLayerWithImage(newLayer, stage?.asset || this._getNpcPortrait(npcId));
      }
    } else {
      // 非基础阶段 — 直接加载 stage.asset 静态立绘
      this._fillLayerWithImage(newLayer, stage.asset);
    }

    container.appendChild(newLayer);

    // Crossfade: 新图层淡入，旧图层淡出后移除
    requestAnimationFrame(() => {
      newLayer.style.opacity = '1';
      const oldLayers = container.querySelectorAll('.portrait-stage-layer:not(:last-child)');
      oldLayers.forEach(old => {
        old.style.opacity = '0';
        setTimeout(() => old.remove(), 450);
      });
    });

    // 狐狸粒子（所有阶段都加）
    if (npcId === 'bai_luoxuan' || npcId === 'jiuwei_suyue' || npcId === 'jiuwei') {
      // 移除旧粒子再重新添加
      container.querySelectorAll('.foxfire-particles').forEach(el => el.remove());
      this._addFoxfireParticles(container);
    }

    // 显示阶段名称浮层
    this._showStageNameOverlay(container, stage);
  }

  /**
   * 用 <img> 填充一个图层
   */
  _fillLayerWithImage(layer, assetPath) {
    const img = document.createElement('img');
    img.src = assetPath;
    img.style.cssText = 'width:100%;height:100%;object-fit:contain;border-radius:16px;';
    img.alt = 'portrait';
    layer.appendChild(img);
  }

  /**
   * 阶段名称浮层 — 切换时短暂显示
   */
  _showStageNameOverlay(container, stage) {
    container.querySelectorAll('.stage-name-overlay').forEach(el => el.remove());
    if (!stage) return;

    const overlay = document.createElement('div');
    overlay.className = 'stage-name-overlay';
    overlay.innerHTML = `
      <span class="stage-name-text">${stage.name}</span>
      ${stage.adultContent ? '<span class="stage-adult-tag">成人</span>' : ''}
    `;
    container.appendChild(overlay);

    // 淡入
    requestAnimationFrame(() => overlay.classList.add('visible'));
    // 2秒后淡出
    setTimeout(() => {
      overlay.classList.remove('visible');
      setTimeout(() => overlay.remove(), 400);
    }, 2000);
  }

  /**
   * 渲染阶段指示器条（异环式底部圆点）
   */
  _renderStageIndicator(container, npcId, unlockedStages, currentIndex) {
    container.querySelectorAll('.stage-indicator, .swipe-hint').forEach(el => el.remove());
    if (unlockedStages.length <= 1) return;

    const indicator = document.createElement('div');
    indicator.className = 'stage-indicator';
    indicator.innerHTML = unlockedStages.map((s, i) => `
      <div class="stage-dot ${i === currentIndex ? 'active' : ''} ${s.adultContent ? 'adult' : ''}"
           data-index="${i}" title="${s.name}"></div>
    `).join('');

    container.appendChild(indicator);

    // 首次显示滑动提示
    if (!container._swipeHintShown) {
      container._swipeHintShown = true;
      const hint = document.createElement('div');
      hint.className = 'swipe-hint';
      hint.textContent = '← 滑动切换皮肤 →';
      container.appendChild(hint);
      setTimeout(() => hint.remove(), 3000);
    }

    // 点击圆点切换
    indicator.querySelectorAll('.stage-dot').forEach(dot => {
      dot.addEventListener('click', (e) => {
        e.stopPropagation();
        const idx = parseInt(dot.dataset.index);
        this._switchToStage(npcId, container, idx);
      });
    });
  }

  /**
   * 切换到指定索引的阶段
   */
  _switchToStage(npcId, container, newIndex) {
    const unlocked = this._getUnlockedPortraitStages(npcId);
    if (newIndex < 0 || newIndex >= unlocked.length) return;

    this._cardPortraitIndex = newIndex;
    const stage = unlocked[newIndex];
    this._renderCardPortraitForStage(npcId, container, stage);
    this._renderStageIndicator(container, npcId, unlocked, newIndex);
  }

  /**
   * 初始化触摸/鼠标滑动切换（异环式皮肤浏览）
   */
  _initPortraitSwipe(npcId, container) {
    if (container._swipeBound) return; // 避免重复绑定
    container._swipeBound = true;

    let startX = 0, startY = 0, isSwiping = false;

    const onStart = (e) => {
      const touch = e.touches ? e.touches[0] : e;
      startX = touch.clientX;
      startY = touch.clientY;
      isSwiping = true;
    };

    const onEnd = (e) => {
      if (!isSwiping) return;
      isSwiping = false;
      const touch = e.changedTouches ? e.changedTouches[0] : e;
      const dx = touch.clientX - startX;
      const dy = touch.clientY - startY;

      // 水平滑动优先（|dx| > |dy| 且 |dx| > 30px）
      if (Math.abs(dx) > Math.abs(dy) && Math.abs(dx) > 30) {
        const unlocked = this._getUnlockedPortraitStages(npcId);
        if (unlocked.length <= 1) return;

        if (dx < 0) {
          // 左滑 → 下一个阶段
          const next = (this._cardPortraitIndex + 1) % unlocked.length;
          this._switchToStage(npcId, container, next);
        } else {
          // 右滑 → 上一个阶段
          const prev = (this._cardPortraitIndex - 1 + unlocked.length) % unlocked.length;
          this._switchToStage(npcId, container, prev);
        }
      }
    };

    container.addEventListener('touchstart', onStart, { passive: true });
    container.addEventListener('touchend', onEnd, { passive: true });
    container.addEventListener('mousedown', onStart);
    container.addEventListener('mouseup', onEnd);
  }

  // ============ 道侣沉浸 — CompanionHUD ============

  /**
   * 初始化随身道侣 HUD
   * 在 game.init() 中由 DOMContentLoaded 调用
   */
  initCompanionHUD() {
    this.companionHUD = new CompanionHUD(this);
    this.companionHUD.init();
  }

  /**
   * 显示道侣气泡评论（羁绊耳语触发）
   * @param {string} text
   * @param {number} duration - 显示时长 (ms)
   */
  showCompanionBubble(text, duration = 3500) {
    if (this.companionHUD) {
      this.companionHUD._showBubble(text, duration);
    }
  }

  /**
   * 设置当前陪伴的道侣
   * @param {string} compId
   * @param {Object} compData - { affection, bond, trust, stage, name }
   */
  setActiveCompanion(compId, compData) {
    if (this.companionHUD) {
      this.companionHUD.setCompanion(compId, compData);
    }
  }

  // ==========================================
  //  故事线程 UI
  // ==========================================

  /**
   * 绑定线程侧边面板的开关事件
   */
  _bindThreadPanel() {
    if (!this.threadPanelBtn || !this.threadPanel) return;

    this.threadPanelBtn.addEventListener('click', () => {
      const isOpen = this.threadPanel.style.display === 'flex';
      if (isOpen) {
        this._closeThreadPanel();
      } else {
        this._openThreadPanel();
      }
    });

    if (this.threadPanelClose) {
      this.threadPanelClose.addEventListener('click', () => this._closeThreadPanel());
    }

    // 点面板外区域关闭（点蒙层）
    document.addEventListener('click', (e) => {
      if (this.threadPanel.style.display === 'flex' &&
          !this.threadPanel.contains(e.target) &&
          e.target !== this.threadPanelBtn) {
        this._closeThreadPanel();
      }
    });
  }

  _openThreadPanel() {
    this.threadPanel.style.display = 'flex';
    this._updateThreadPanel();
  }

  _closeThreadPanel() {
    this.threadPanel.style.display = 'none';
  }

  /**
   * 渲染卡牌上的线程指示器
   */
  _renderThreadIndicator(card) {
    if (!this.threadIndicator) return;

    if (!card._isThreadCard || !card._threadId) {
      this.threadIndicator.style.display = 'none';
      return;
    }

    // 线程定义（从全局 threadEngine 获取）
    let threadTitle = card._threadId;
    let threadCategory = 'mystery';
    if (typeof threadEngine !== 'undefined' && threadEngine) {
      const def = threadEngine.threadDefs.get(card._threadId);
      if (def) {
        threadTitle = def.title || card._threadId;
        // 从线程 tags 推断类别
        const tags = (card.threadTags || def.nodes?.[0]?.card?.threadTags || []);
        if (tags.some(t => ['danger','combat','boss','challenge','confrontation','conflict'].includes(t)))
          threadCategory = 'danger';
        else if (tags.some(t => ['discovery','revelation','treasure'].includes(t)))
          threadCategory = 'discovery';
        else if (tags.some(t => ['destiny','fate','prophecy'].includes(t)))
          threadCategory = 'destiny';
        else if (tags.some(t => ['caution','stealth','diplomacy'].includes(t)))
          threadCategory = 'caution';
        else
          threadCategory = 'mystery';
      }
    }

    // 阶段中文映射
    const phaseLabels = {
      'beginning':  '起',
      'middle':     '承',
      'climax':     '转',
      'resolution': '合',
    };
    const phase = card._threadPhase || '';
    const phaseLabel = phaseLabels[phase] || '';

    // 设置线程栏样式
    this.threadIndicator.className = `thread-indicator ${threadCategory}`;
    this.threadBar.className = `thread-bar ${threadCategory}`;
    this.threadName.textContent = threadTitle;
    this.threadPhase.textContent = phaseLabel;
    this.threadIndicator.style.display = 'flex';

    // 更新面板按钮状态（有活跃线程时脉冲）
    if (this.threadPanelBtn && typeof threadEngine !== 'undefined') {
      const hasActive = threadEngine.activeThreads.size > 0;
      if (hasActive) {
        this.threadPanelBtn.classList.add('has-active');
      } else {
        this.threadPanelBtn.classList.remove('has-active');
      }
    }
  }

  /**
   * 更新线程侧边面板内容
   */
  _updateThreadPanel() {
    if (typeof threadEngine === 'undefined' || !threadEngine) return;

    // ── 进行中的线程 ──
    const activeSummaries = threadEngine.getActiveThreadSummaries();
    if (this.activeThreads) {
      if (activeSummaries.length === 0) {
        this.activeThreads.innerHTML = '<p class="thread-empty">暂无活跃故事线</p>';
      } else {
        this.activeThreads.innerHTML = activeSummaries.map(s => {
          const category = s.dominantDirection === 'brave' ? 'danger' :
                          s.dominantDirection === 'cautious' ? 'caution' :
                          s.dominantDirection === 'kind' ? 'discovery' : 'mystery';
          return `
            <div class="thread-item">
              <span class="thread-item-bar ${category}"></span>
              <div class="thread-item-info">
                <div class="thread-item-title">${s.title}</div>
                <div class="thread-item-meta">第 ${s.startedTurn} 回合 · ${this._phaseLabelFor(s.phase, s.progress)}</div>
              </div>
              <span class="thread-item-progress">${s.progress}</span>
            </div>
          `;
        }).join('');
      }
    }

    // ── 最近完成的线程 ──
    const recentJournal = threadEngine.getRecentJournal(5).filter(e => e.status === 'completed');
    if (this.completedThreads) {
      if (recentJournal.length === 0) {
        this.completedThreads.innerHTML = '<p class="thread-empty">尚无完成的故事线</p>';
      } else {
        this.completedThreads.innerHTML = recentJournal.map(e => `
          <div class="thread-item">
            <span class="thread-item-bar discovery"></span>
            <div class="thread-item-info">
              <div class="thread-item-title">${e.title}</div>
              <div class="thread-item-note">${e.note || '故事线完成'}</div>
              <div class="thread-item-meta">第 ${e.turn} 回合</div>
            </div>
          </div>
        `).join('');
      }
    }

    // ── 因果线索（尚未触发） ──
    if (this.pendingSeeds) {
      let seedsHtml = '';
      if (typeof karmaSystem !== 'undefined' && karmaSystem) {
        const allSeeds = karmaSystem.getAllSeeds ? karmaSystem.getAllSeeds() : [];
        const pending = allSeeds.filter(s => !s.sprouted && (s.originThread || s.sourceThread));
        if (pending.length === 0) {
          seedsHtml = '<p class="thread-empty">暂无线索等待发芽</p>';
        } else {
          seedsHtml = pending.slice(0, 5).map(s => `
            <div class="thread-item">
              <span class="thread-item-bar destiny"></span>
              <div class="thread-item-info">
                <div class="thread-item-title">${s.desc || s.id}</div>
                <div class="thread-item-meta">来源：${s.originThread || '未知'}</div>
              </div>
            </div>
          `).join('');
        }
      } else {
        seedsHtml = '<p class="thread-empty">暂无线索等待发芽</p>';
      }
      this.pendingSeeds.innerHTML = seedsHtml;
    }

    // 更新面板按钮状态
    if (this.threadPanelBtn) {
      const hasActive = threadEngine.activeThreads.size > 0;
      if (hasActive) {
        this.threadPanelBtn.classList.add('has-active');
      } else {
        this.threadPanelBtn.classList.remove('has-active');
      }
    }
  }

  /**
   * 线程完成 → 日志区显示特殊格式消息
   */
  _onThreadResolved(data) {
    if (!data) return;

    // 构造结构化文本
    let karmaText = '';
    if (data.karmaSeed) {
      karmaText = `\n——因果种子已种下：「${data.karmaSeed.desc || data.karmaSeed.id}」将在未来开花。`;
    }
    const text = `🔗 故事线完成：${data.title}\n${data.note || ''}${karmaText}`;

    // 使用现有日志系统，传 HTML 类名来触发特殊样式
    this.addLog(text, 'thread-complete');

    // 同时更新侧边面板（如果打开中）
    if (this.threadPanel && this.threadPanel.style.display === 'flex') {
      this._updateThreadPanel();
    }
  }

  /**
   * 阶段中文短标签
   */
  _phaseLabelFor(phase, progress) {
    const labels = { beginning: '开端', middle: '发展', climax: '高潮', resolution: '结局', active: '进行中' };
    return labels[phase] || '进行中';
  }

  // ═══════════════════════════════════════════════
  //  叙事连贯性层 — 依赖注入辅助方法
  // ═══════════════════════════════════════════════

  /** @returns {Object|null} gameState */
  _getGameState() {
    if (typeof gameState !== 'undefined') return gameState;
    return this.game && this.game.gameState ? this.game.gameState : null;
  }

  /** @returns {Object|null} threadEngine */
  _getThreadEngine() {
    if (typeof threadEngine !== 'undefined') return threadEngine;
    return null;
  }

  /** @returns {Object|null} questSystem */
  _getQuestSystem() {
    if (typeof questSystem !== 'undefined') return questSystem;
    return null;
  }

}

/**
 * CompanionHUD — 随身道侣视觉系统
 *
 * 屏幕右下角常驻半身像 + 情绪光效 + 气泡对话 + 好感度
 * 不依赖弹窗——始终在玩家视野中。
 */
class CompanionHUD {
  constructor(ui) {
    this.ui = ui;
    this.container = null;
    this.portraitImg = null;
    this.emotionEl = null;
    this.bubbleEl = null;
    this.heartValEl = null;
    this.activeCompId = null;
    this._idleTimer = null;
    this._reactTimer = null;
    this._emotion = 'calm';
    this._lastAffection = 0;
  }

  /** 创建 DOM 结构 */
  init() {
    this.container = document.createElement('div');
    this.container.id = 'companion-hud';
    this.container.innerHTML = `
      <div class="comp-hud-portrait">
        <img class="comp-hud-img" id="comp-hud-img" src="" alt="" />
        <div class="comp-hud-emotion" id="comp-hud-emotion"></div>
      </div>
      <div class="comp-hud-bubble" id="comp-hud-bubble"></div>
      <div class="comp-hud-heart">
        <span class="comp-hud-heart-icon">&hearts;</span>
        <span class="comp-hud-heart-val" id="comp-hud-heart-val">0</span>
      </div>
    `;
    document.body.appendChild(this.container);

    this.portraitImg = document.getElementById('comp-hud-img');
    this.emotionEl = document.getElementById('comp-hud-emotion');
    this.bubbleEl = document.getElementById('comp-hud-bubble');
    this.heartValEl = document.getElementById('comp-hud-heart-val');

    // 点击 HUD 打开道侣详情面板
    this.container.style.pointerEvents = 'auto';
    this.container.addEventListener('click', () => {
      if (this.activeCompId && typeof npcSystem !== 'undefined') {
        this.ui._openNpcCompPanel(this.activeCompId);
      }
    });

    this.container.style.display = 'none';
  }

  /**
   * 设置当前陪伴道侣
   * @param {string} compId
   * @param {Object} compData
   */
  setCompanion(compId, compData) {
    if (!compId) {
      this.container.style.display = 'none';
      return;
    }

    this.activeCompId = compId;
    this._lastAffection = compData.affection || 0;
    this.container.style.display = 'flex';

    // 加载立绘
    this._loadPortrait(compId);

    // 设置情绪光效
    this._setEmotion(this._lastAffection);

    // 更新好感度
    this.heartValEl.textContent = this._lastAffection;

    // 播放入场动画
    this.container.classList.add('comp-hud-enter');
    setTimeout(() => this.container.classList.remove('comp-hud-enter'), 600);

    // 显示初始气泡
    this._showBubble(this._getGreeting(compId, this._lastAffection), 2500);

    // 启动空闲气泡循环
    this._startIdleBubbles(compId);
  }

  /**
   * 切换陪伴道侣 — 带过渡动画
   */
  switchCompanion(newCompId, newCompData) {
    this.container.classList.add('comp-hud-exit');
    setTimeout(() => {
      this.setCompanion(newCompId, newCompData);
    }, 400);
  }

  /** 加载道侣立绘到 HUD */
  _loadPortrait(compId) {
    // 使用与 card-portrait 相同的映射逻辑
    const staticMap = {
      bai_luoxuan:  'assets/characters/concept_bai_luoxuan.webp',
      jian_linger:  'assets/characters/concept_jian_linger.webp',
      mu_qinglan:   'assets/characters/concept_mu_qinglan.webp',
      yin_xue:      'assets/characters/concept_yin_xue.webp',
      jiuwei_suyue: 'assets/characters/concept_jiuwei_suyue.webp',
      tianji_laoren:'assets/characters/concept_tianji_laoren.webp',
      xuesha_laozu: 'assets/characters/concept_xuesha_laozu.webp',
      jiuwei:       'assets/characters/concept_jiuwei_suyue.webp',
    };
    const fallback = 'assets/cards/characters/card_sunian_mortal_pc98.png';
    const src = staticMap[compId] || fallback;

    this.portraitImg.src = src;
    this.portraitImg.onerror = () => {
      this.portraitImg.src = fallback;
    };
  }

  /** 情绪光效系统 — 5档常驻情绪 */
  _setEmotion(affection) {
    let animClass;
    if (affection < 20)      { animClass = 'comp-calm'; }
    else if (affection < 40) { animClass = 'comp-calm'; }
    else if (affection < 60) { animClass = 'comp-glow'; }
    else if (affection < 80) { animClass = 'comp-sparkle'; }
    else                     { animClass = 'comp-aura'; }

    this._emotion = animClass;
    this.emotionEl.className = 'comp-hud-emotion ' + animClass;
  }

  /**
   * 触发情绪反应 — 由游戏事件调用
   * @param {string} eventType - player_hurt|breakthrough|dao_heart_gain|karma_bad|death_near|combat_victory
   * @param {Object} data - { affection }
   */
  react(eventType, data) {
    const reactions = {
      player_hurt:     { className: 'comp-worried',  duration: 3000 },
      breakthrough:    { className: 'comp-proud',    duration: 5000 },
      dao_heart_gain:  { className: 'comp-moved',    duration: 4000 },
      karma_bad:       { className: 'comp-concerned',duration: 4000 },
      death_near:      { className: 'comp-desperate',duration: 0 },
      combat_victory:  { className: 'comp-relieved', duration: 3000 },
    };

    const reaction = reactions[eventType];
    if (!reaction) return;

    // 更新情绪动画
    this.emotionEl.className = 'comp-hud-emotion ' + reaction.className;

    // 显示反应气泡
    const affection = data && data.affection ? data.affection : this._lastAffection;
    if (typeof companionWhisper !== 'undefined' && companionWhisper) {
      const line = companionWhisper.getReactionByType(this.activeCompId, eventType, affection);
      if (line) this._showBubble(line, reaction.duration || 3000);
    }

    // 定时恢复默认情绪
    if (reaction.duration > 0) {
      clearTimeout(this._reactTimer);
      this._reactTimer = setTimeout(() => {
        this._setEmotion(this._lastAffection);
      }, reaction.duration);
    }
  }

  /** 获取入场问候 */
  _getGreeting(compId, affection) {
    const hellos = {
      bai_luoxuan: {
        low:  '\u4f60\u6765\u4e86\u3002',
        mid:  '\u4eca\u5929\u4e5f\u4e00\u8d77\u4fee\u884c\u5427\u3002',
        high: '\u9053\u4fa3\u2014\u2014\u7b49\u4f60\u5f88\u4e45\u4e86\u3002',
      },
      jian_linger: {
        low:  '\u2026\u2026\u4f60\u6765\u4e86\u3002',
        mid:  '\u5251\u78e8\u597d\u4e86\u5417\uff1f',
        high: '\u7b49\u4f60\u5f88\u4e45\u4e86\u2014\u2014\u522b\u8bef\u4f1a\uff0c\u662f\u8981\u7ec3\u5251\u3002',
      },
      mu_qinglan: {
        low:  '\u2026\u2026\u3002',
        mid:  '\u4f60\u7684\u7075\u9b42\u4eca\u5929\u5f88\u5b89\u9759\u3002',
        high: '\u5929\u9053\u8ba9\u6211\u7559\u5728\u4f60\u8eab\u8fb9\u3002',
      },
      yin_xue: {
        low:  '\u54e6\u3002',
        mid:  '\u7ec8\u4e8e\u6765\u4e86\u3002',
        high: '\u7b49\u4f60\u5f88\u4e45\u2014\u2014\u522b\u8ba9\u6211\u8bf4\u7b2c\u4e8c\u904d\u3002',
      },
    };

    const charHellos = hellos[compId];
    if (!charHellos) return '\u2026\u2026';
    if (affection < 40) return charHellos.low;
    if (affection < 70) return charHellos.mid;
    return charHellos.high;
  }

  /** 空闲时随机冒泡 */
  _startIdleBubbles(compId) {
    const cycle = () => {
      if (!this.activeCompId || this.activeCompId !== compId) return;
      let lines;
      if (typeof companionWhisper !== 'undefined' && companionWhisper) {
        lines = companionWhisper.getIdleLines(compId, this._lastAffection);
      } else {
        lines = ['\u2026\u2026'];
      }
      const line = lines[Math.floor(Math.random() * lines.length)];
      this._showBubble(line, 3500);
      this._idleTimer = setTimeout(cycle, 15000 + Math.random() * 20000);
    };
    cycle();
  }

  /** 显示气泡文字 */
  _showBubble(text, duration = 3500) {
    if (!this.bubbleEl) return;
    this.bubbleEl.textContent = text;
    this.bubbleEl.classList.add('show');
    clearTimeout(this._bubbleTimer);
    this._bubbleTimer = setTimeout(() => {
      this.bubbleEl.classList.remove('show');
    }, duration);
  }

  /** 销毁清理 */
  destroy() {
    clearTimeout(this._idleTimer);
    clearTimeout(this._reactTimer);
    clearTimeout(this._bubbleTimer);
    if (this.container && this.container.parentNode) {
      this.container.parentNode.removeChild(this.container);
    }
  }

  // ═══════════════════════════════════════════════
  //  叙事连贯性层 — 过渡文字显示
  // ═══════════════════════════════════════════════

  /**
   * 显示卡牌间过渡文字（方案B）
   * @param {string} text - 过渡叙事文字
   * @param {function} [onComplete] - 动画结束回调
   */
  showTransitionOverlay(text, onComplete) {
    if (!text) {
      if (onComplete) onComplete();
      return;
    }
    const overlay = document.getElementById('transition-overlay');
    if (!overlay) {
      if (onComplete) onComplete();
      return;
    }

    overlay.textContent = text;
    overlay.classList.add('transition-visible');

    const duration = 1400; // 显示时长
    clearTimeout(this._transitionTimer);
    this._transitionTimer = setTimeout(() => {
      overlay.classList.remove('transition-visible');
      if (onComplete) onComplete();
    }, duration);
  }

  /** 立即隐藏过渡文字 */
  hideTransitionOverlay() {
    const overlay = document.getElementById('transition-overlay');
    if (overlay) overlay.classList.remove('transition-visible');
    clearTimeout(this._transitionTimer);
  }
}
