/**
 * GameUI - 主游戏界面渲染器
 *
 * 负责所有DOM操作和交互处理。
 * 通过 GameLogic 编排，通过 gameState 全局单例读取数据。
 */
class GameUI {
  constructor(gameLogic) {
    this.game = gameLogic;
    this.renderLoop = (typeof window !== 'undefined' && window.renderLoopCoordinator) || null;
    this._blockRenderLoopUnsubscribe = null;
    this._swipeRenderLoopUnsubscribe = null;
    this.screens = {};
    this.swipeStartX = 0;
    this.swipeStartY = 0;
    this.swipeThreshold = 80;
    this.logMessages = [];
    this.maxLogMessages = 18;
    this.choiceButtons = [];
    this.touching = false;
    this.cardEl = null;
    this.cardStartX = 0;
    this.cardStartY = 0;
    this.cardCurrentX = 0;
    this.cardCurrentY = 0;
    this.currentCard = null; // 当前显示的卡牌（用于滑动阻力计算）
    this.choicePending = false; // 防止同一张卡的动画窗口重复注册结算
    this.companionHUD = null;

    // 物理引擎变量
    this.phys = {
      currentX: 0,
      currentY: 0,
      targetX: 0,
      targetY: 0,
      vx: 0,
      vy: 0,
      lastX: 0,
      lastY: 0,
      rAF: null
    };

    this.init();
  }

  init() {
    this.cacheElements();
    this.bindEvents();
    this.bindNpcPanels();
    this._bindShopPanel();
    this._bindThreadPanel();
    this._bindKarmaLogPanel();
    this._bindKarmaRipenReceipt();
    this._bindEvidenceAtlas();
    this._bindTopbarPanelFocus();
    this._bindLineage();
    if (typeof window.HeavenlyGallery === 'function') this._heavenlyGallery = new window.HeavenlyGallery(this);
    let heavenlyMode = this._isHeavenlyMode();
    eventBus.on('experience:settingsChanged', () => {
      const enabled = this._isHeavenlyMode();
      if (enabled === heavenlyMode) return;
      heavenlyMode = enabled;
      this._narrativeExhibit?.close();
      if (this.currentCard) this._syncNarrativeExhibit(this.currentCard);
    });
    // 战斗反应由 DeckCombatSystem → DeckCombatUI 的权威 reaction state 消费。
    // 不再把旧 CombatSystem 的 QTE 注入普通剧情卡 DOM，避免双权威输入链。
    // 【故事线程】线程完成 → 日志提示
    eventBus.on('thread:resolved', (data) => this._onThreadResolved(data));
    // FlowDirector 阶段变更
    eventBus.on('flow:phaseChanged', (data) => this._onPhaseChanged(data));
    eventBus.on('world:pulse', (data) => this._onWorldPulse(data));
    eventBus.on('evidence:updated', (data) => this._onEvidenceUpdated(data));
    eventBus.on('npc:affectionChange', (data) => this._onCompanionAffectionChange(data));
    eventBus.on('companion:portraitSelected', (data) => this._onPortraitSelected(data));

    // UI 层级的打牌战斗界面切换
    eventBus.on('ui:showCombatScreen', () => {
       this.showScreen('combat');
    });
    eventBus.on('ui:hideCombatScreen', () => {
       this.showScreen('game');
    });

    // 装备系统事件监听
    eventBus.on('treasure:equipped', () => {
      this._renderEquipmentPanel();
      this.renderPassives();
    });
    eventBus.on('treasure:unequipped', () => {
      this._renderEquipmentPanel();
      this.renderPassives();
    });
    eventBus.on('treasure:acquired', () => {
      this._renderEquipmentPanel();
      this.renderInventoryEquipment();
    });
    eventBus.on('treasure:removed', () => {
      this._renderEquipmentPanel();
      this.renderPassives();
    });
    eventBus.on('loadout:decisionPending', () => {
      this._loadoutDecisionDismissedId = null;
      this.openLoadoutDecision({ force: true });
    });
    eventBus.on('loadout:decisionResolved', () => {
      this._loadoutDecisionDismissedId = null;
      this.closeLoadoutDecision();
      this._renderEquipmentPanel();
      this.renderPassives();
    });
    eventBus.on('opportunity:resolved', (data) => this._showOpportunityResolution(data));

    // 绑定卡组查看按钮
    const viewDeckBtn = document.getElementById('view-deck-btn');
    const closeDeckBtn = document.getElementById('close-deck-btn');
    const deckModal = document.getElementById('deck-view-modal');
    if (viewDeckBtn && deckModal && closeDeckBtn) {
      const closeDeck = () => {
        deckModal.classList.remove('is-open');
        deckModal.setAttribute('aria-hidden', 'true');
        viewDeckBtn.focus();
      };
      viewDeckBtn.addEventListener('click', async () => {
        await this._renderDeckView();
        deckModal.classList.add('is-open');
        deckModal.setAttribute('aria-hidden', 'false');
        closeDeckBtn.focus();
      });
      closeDeckBtn.addEventListener('click', closeDeck);
      deckModal.addEventListener('click', event => {
        if (event.target === deckModal) closeDeck();
      });
      deckModal.addEventListener('keydown', event => {
        if (event.key === 'Escape') closeDeck();
      });
    }
    const viewTreasureBtn = document.getElementById('view-treasure-btn');
    if (viewTreasureBtn) {
      viewTreasureBtn.addEventListener('click', () => this.openEquipmentModal('all'));
    }

    this.renderStartScreen();
    this.initCompanionHUD();
  }

  async _renderDeckView() {
      const container = document.getElementById('deck-view-container');
      if (!container) return;
      container.innerHTML = '';

      const deckAuthority = this.game?.skillCardAcquisitionSystem
        || (typeof skillCardAcquisitionSystem !== 'undefined' ? skillCardAcquisitionSystem : null);
      if (!Array.isArray(gameState.deck)) {
          container.innerHTML = '<div style="color: #fff;">尚未解锁卡组功能。</div>';
          return;
      }

      const deck = gameState.deck;

      if (typeof pathArchetypeSystem !== 'undefined' && pathArchetypeSystem && gameState.path) {
          const selector = document.createElement('section');
          selector.className = 'archetype-selector';
          const current = pathArchetypeSystem.getSelected();
          const options = pathArchetypeSystem.getAvailable();
          selector.innerHTML = `
            <div class="archetype-selector-title">功法流派 · ${current ? current.name : '尚未定型'}</div>
            <div class="archetype-selector-desc">${current ? current.style : '随境界提升解锁新的战斗循环。'}</div>
            <div class="archetype-options"></div>
          `;
          const optionsEl = selector.querySelector('.archetype-options');
          options.forEach(item => {
            const button = document.createElement('button');
            button.className = 'archetype-option' + (current && current.id === item.id ? ' active' : '');
            button.innerHTML = `<strong>${item.name}</strong><small>${item.style}</small>`;
            button.addEventListener('click', async () => {
              if (pathArchetypeSystem.select(gameState.path, item.id)) await this._renderDeckView();
            });
            optionsEl.appendChild(button);
          });
          container.appendChild(selector);
      }

      if (deck.length === 0) {
          container.innerHTML += '<div style="color: #fff;">你的卡组空空如也。</div>';
          return;
      }

      let cardDB = deckCombatSystem.cardDB;
      if (!cardDB || Object.keys(cardDB).length === 0) {
          const cardData = await dataLoader.load('cards:battle_cards');
          cardDB = {};
          if (cardData && cardData.battle_cards) {
              cardData.battle_cards.forEach(c => cardDB[c.id] = c);
          }
      }

      deck.forEach(cardId => {
          const def = deckAuthority?.getCardDefinition(cardId) || (cardDB ? cardDB[cardId] : null);
          if (!def) {
              // 如果 cardDB 没加载出来，我们可以发个默认 fallback
              console.warn("卡牌数据未加载", cardId);
              return;
          }

          const cardEl = document.createElement('div');
          cardEl.className = 'battle-card';
          cardEl.dataset.type = def.type;
          cardEl.dataset.cardId = cardId;
          // Reuse styles from deck-combat.css
          cardEl.style.position = 'relative';
          cardEl.style.marginLeft = '0'; // reset overlap
          cardEl.style.transform = 'none'; // reset hover transform scaling issues in modal

          cardEl.innerHTML = `
             <div class="card-cost">${def.cost}</div>
             <div class="card-name">${def.name}</div>
             ${def.cardArt?.image
               ? `<img class="deck-view-card-art" src="${def.cardArt.image}" alt="${def.name}技能卡图">`
               : ''}
             <div class="card-type">${def.type === 'attack' ? '攻击' : (def.type === 'skill' ? '技能' : '能力')}</div>
             <div class="card-desc">${this._narrativeHtml(def.description)}</div>
          `;

          container.appendChild(cardEl);
      });
  }

  cacheElements() {
    this.screens.start = document.getElementById('start-screen');
    this.screens.game = document.getElementById('game-screen');
    this.screens.death = document.getElementById('death-screen');
    this.screens.combat = document.getElementById('deck-combat-screen');

    // 名字创建界面元素
    this.nameInput = document.getElementById('name-input');
    this.nameCharCount = document.getElementById('name-char-count');
    this.nameConfirmBtn = document.getElementById('name-confirm-btn');
    this.nameCreation = document.getElementById('name-creation');
    this.pathSelection = document.getElementById('path-selection');
    this.saveSlotList = document.getElementById('save-slot-list');
    this.saveSlotStatus = document.getElementById('save-slot-status');
    this.resumeSessionShell = document.getElementById('resume-session-shell');
    this.resumeSessionBtn = document.getElementById('resume-session-btn');
    this.resumeSessionCopy = document.getElementById('resume-session-copy');
    this.legacyBossRewardModal = document.getElementById('legacy-boss-reward-modal');
    this.legacyBossRewardCopy = document.getElementById('legacy-boss-reward-copy');
    this.legacyBossRewardOptions = document.getElementById('legacy-boss-reward-options');
    this.legacyInheritanceModal = document.getElementById('legacy-inheritance-modal');
    this.legacyInheritanceCopy = document.getElementById('legacy-inheritance-copy');
    this.legacyInheritanceOptions = document.getElementById('legacy-inheritance-options');

    this.cardEl = document.getElementById('card');
    this.cardTitle = document.getElementById('card-title');
    this.cardDesc = document.getElementById('card-description');
    this.narrativeSpineSummary = document.getElementById('narrative-spine-summary');
    this.cardType = document.getElementById('card-type');
    this.cardSource = document.getElementById('card-source');
    this.cardPortrait = document.getElementById('card-portrait');
    this.cardPortraitCanvas = document.getElementById('card-portrait-canvas');
    this.cardAssociationDock = document.getElementById('card-association-dock');

    this.choiceLeft = document.getElementById('choice-left');
    this.choiceRight = document.getElementById('choice-right');
    this.choiceUp = document.getElementById('choice-up');
    this.choiceDown = document.getElementById('choice-down');
    this.choiceButtons = [this.choiceLeft, this.choiceRight, this.choiceUp, this.choiceDown];
    this.choiceRail = document.querySelector('#game-screen .choice-buttons');
    this.dungeonExitBtn = document.getElementById('dungeon-exit-btn');

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
      health: document.getElementById('bar-health'),
      tianji: document.getElementById('bar-tianji')
    };

    this.labels = {
      cultivation: document.getElementById('label-cultivation'),
      daoHeart: document.getElementById('label-daoHeart'),
      karmaGood: document.getElementById('label-karmaGood'),
      karmaBad: document.getElementById('label-karmaBad'),
      fortune: document.getElementById('label-fortune'),
      health: document.getElementById('label-health'),
      tianji: document.getElementById('label-tianji')
    };

    // Passive bonus display elements
    this.passiveEls = {
      hpRegen: document.getElementById('passive-hpRegen'),
      fortune: document.getElementById('passive-fortune'),
      atk: document.getElementById('passive-atk'),
      def: document.getElementById('passive-def'),
      crit: document.getElementById('passive-crit')
    };

    // Equipment UI elements. 槽位本体由 _renderEquipmentPanel 动态创建，不能在此缓存空节点。
    this.equipmentModal = document.getElementById('equipment-modal');
    this.equipmentModalTitle = document.getElementById('equipment-modal-title');
    this.equipmentModalList = document.getElementById('equipment-modal-list');
    this.equipmentModalClose = document.getElementById('equipment-modal-close');
    this.equipmentModalUnequip = document.getElementById('equipment-modal-unequip');
    this.currentEquipmentSlot = null;
    this.loadoutDecisionModal = document.getElementById('loadout-decision-modal');
    this.loadoutDecisionTitle = document.getElementById('loadout-decision-title');
    this.loadoutDecisionSummary = document.getElementById('loadout-decision-summary');
    this.loadoutDecisionComparison = document.getElementById('loadout-decision-comparison');
    this.loadoutDecisionProvenance = document.getElementById('loadout-decision-provenance');
    this.loadoutDecisionEquip = document.getElementById('loadout-decision-equip');
    this.loadoutDecisionStash = document.getElementById('loadout-decision-stash');
    this.loadoutDecisionView = document.getElementById('loadout-decision-view');
    this.loadoutDecisionClose = document.getElementById('loadout-decision-close');
    this._loadoutDecisionDismissedId = null;

    this.topRealm = document.getElementById('top-realm');
    this.topPath = document.getElementById('top-path');
    this.topSpiritStone = document.getElementById('top-spiritStone');
    this.topLifespan = document.getElementById('top-lifespan');
    this.topTurn = document.getElementById('top-turn');
    this.resLifespan = document.getElementById('res-lifespan');
    this.topQuest = document.getElementById('top-quest');
    this.topChapter = document.getElementById('top-chapter');
    this.topPhase = document.getElementById('top-phase');
    this.topObjective = document.getElementById('top-objective');
    // 突破倒计时
    this.btBar = document.getElementById('breakthrough-bar');
    this.btLabel = document.getElementById('bt-label');
    this.btFill = document.getElementById('bt-fill');
    this.btPct = document.getElementById('bt-pct');
    this.logContainer = document.getElementById('log-container');
    this.logCountEl = document.getElementById('log-count');
    this.logSidebar = document.getElementById('log-sidebar');
    this.panelSubtitle = document.getElementById('panel-subtitle');
    this.swipeStage = document.getElementById('swipe-choice-stage');
    this.swipePreviews = {};
    document.querySelectorAll('.swipe-choice-preview').forEach(preview => {
      this.swipePreviews[preview.dataset.dir] = preview;
    });

    // 位置栏
    this.locIcon = document.getElementById('loc-icon');
    this.locName = document.getElementById('loc-name');
    this.locMood = document.getElementById('loc-mood');

    this.deathTitle = document.getElementById('death-title');
    this.deathReason = document.getElementById('death-reason');
    this.deathStats = document.getElementById('death-stats');
    this.reincarnateBtn = document.getElementById('reincarnate-btn');
  }

  openEquipmentModal(slotType) {
    if (!this.equipmentModal || !gameState || !treasureSystem) return;
    this._equipmentReturnFocus = {
      element: document.activeElement,
      slot: ['weapon', 'armor', 'accessory', 'artifact'].includes(slotType) ? slotType : null
    };
    this.currentEquipmentSlot = slotType;
    const isLibraryView = slotType === 'all';

    const slotNames = {
      all: '全部法宝与器物',
      weapon: '武器/剑诀',
      armor: '法袍/宝甲',
      accessory: '饰品/法宝',
      artifact: '本命神兵'
    };

    if (this.equipmentModalTitle) {
      this.equipmentModalTitle.textContent = isLibraryView
        ? '法宝库 · 查看并装配'
        : `选择装配的${slotNames[slotType] || '装备'}`;
    }
    const equipmentFeedback = document.getElementById('equipment-modal-feedback');
    if (equipmentFeedback) {
      equipmentFeedback.textContent = '';
      equipmentFeedback.hidden = true;
    }

    const equippedId = isLibraryView ? null : treasureSystem.getEquipped(slotType);
    const equippedBySlot = { ...(gameState.equipment || {}) };

    if (this.equipmentModalUnequip) {
      this.equipmentModalUnequip.style.display = !isLibraryView && equippedId ? 'block' : 'none';
    }

    if (this.equipmentModalList) {
      this.equipmentModalList.innerHTML = '';

      // 合并当前已装备的物品和库存物品
      const availableItems = isLibraryView
        ? treasureSystem.getOwnedInstanceIds()
        : treasureSystem.getUnequippedInstanceIds();
      if (!isLibraryView && equippedId && !availableItems.includes(equippedId)) {
        availableItems.unshift(equippedId);
      }

      if (availableItems.length === 0) {
        this.equipmentModalList.innerHTML = '<div class="empty-state">库存空空如也</div>';
      } else {
        availableItems.forEach(itemId => {
          const item = treasureSystem.getTreasureData(itemId);
          if (!item || (!isLibraryView && item.type !== slotType)) return;

          const equippedSlot = Object.keys(equippedBySlot)
            .find(slot => equippedBySlot[slot] === itemId) || null;
          const isEquipped = Boolean(equippedSlot);
          const el = document.createElement('button');
          el.type = 'button';
          el.className = `equipment-item ${isEquipped ? 'equipped' : ''}`;
          el.dataset.treasureId = itemId;
          el.dataset.treasureType = item.type || 'accessory';
          if (equippedSlot) el.dataset.equippedSlot = equippedSlot;

          let statsHtml = '';
          if (item.passive) {
            const stats = [];
            if (item.passive.atk) stats.push(`攻击+${item.passive.atk}`);
            if (item.passive.def) stats.push(`护甲+${item.passive.def}`);
            if (item.passive.hpRegen) stats.push(`回血+${item.passive.hpRegen}`);
            if (item.passive.fortuneBonus) stats.push(`福缘恢复+${item.passive.fortuneBonus}`);
            if (item.passive.critRate) stats.push(`暴击率+${item.passive.critRate}%`);
            statsHtml = `<span class="equipment-item-stats">${stats.join(' | ')}</span>`;
          }

          const typeLabels = { weapon: '兵刃', armor: '护具', accessory: '佩饰', artifact: '秘宝' };
          const badge = isEquipped
            ? `<span class="equipped-badge">已装备 · ${slotNames[equippedSlot] || equippedSlot}</span>`
            : `<span class="equipment-type-badge">${typeLabels[item.type] || '器物'}</span>`;
          const objectArt = item.combatPresentation?.objectArt?.image
            || item.combatPresentation?.cardArt?.image
            || null;
          const iconHtml = objectArt
            ? `<img class="equipment-item-object-art" src="${objectArt}" alt="${item.name}器物图">`
            : (item.icon || '🔮');

          el.innerHTML = `
            <span class="equipment-item-icon">${iconHtml}</span>
            <span class="equipment-item-info">
              <span class="equipment-item-name">${item.name} ${badge}</span>
              <span class="equipment-item-desc">${item.desc || ''}</span>
              ${statsHtml}
            </span>
          `;

          el.addEventListener('click', () => {
            if (!isEquipped) {
              const targetSlot = isLibraryView
                ? (['weapon', 'armor', 'accessory', 'artifact'].includes(item.type)
                    ? item.type
                    : 'accessory')
                : slotType;
              const pending = gameState.pendingLoadoutDecision;
              if (pending?.status === 'pending' && pending.instanceId === itemId
                && typeof shopSystem !== 'undefined' && shopSystem?.resolveLoadoutDecision) {
                const result = shopSystem.resolveLoadoutDecision('equip');
                if (!result.success) {
                  this._showEquipmentModalError(result.message);
                  return;
                }
              } else {
                const result = treasureSystem.equip(itemId, targetSlot);
                if (!result?.success) {
                  this._showEquipmentModalError(result?.message);
                  return;
                }
              }
            }
            this._closeEquipmentModal();
          });

          this.equipmentModalList.appendChild(el);
        });
      }
    }

    this.equipmentModal.style.display = 'flex';
    this.equipmentModal.setAttribute('aria-hidden', 'false');
    this.equipmentModalClose?.focus();
  }

  _closeEquipmentModal() {
    if (!this.equipmentModal) return;
    this.equipmentModal.style.display = 'none';
    this.equipmentModal.setAttribute('aria-hidden', 'true');
    this.currentEquipmentSlot = null;
    const previous = this._equipmentReturnFocus;
    this._equipmentReturnFocus = null;
    const target = previous?.element?.isConnected
      ? previous.element
      : (previous?.slot ? document.querySelector(`.eq-slot[data-slot="${previous.slot}"]`) : null);
    target?.focus?.();
  }

  _showEquipmentModalError(message) {
    const feedback = document.getElementById('equipment-modal-feedback');
    if (!feedback) return;
    feedback.textContent = message || '装备操作未能保存，请重试';
    feedback.hidden = false;
  }

  renderEquipmentSlots() {
    this._renderEquipmentPanel();
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
    if (this.resumeSessionBtn) {
      this.resumeSessionBtn.addEventListener('click', () => this.resumeGame());
    }
    if (this.saveSlotList) {
      this.saveSlotList.addEventListener('click', (event) => {
        const button = event.target.closest('button[data-save-slot-action][data-save-slot-id]');
        if (!button) return;
        this._handleSaveSlotAction(button.dataset.saveSlotAction, button.dataset.saveSlotId);
      });
    }
    if (this.legacyBossRewardOptions) {
      this.legacyBossRewardOptions.addEventListener('click', (event) => {
        const button = event.target.closest('.legacy-boss-reward-option[data-set-id]');
        if (!button || button.disabled) return;
        button.disabled = true;
        const result = this.game.claimLegacyBossReward(button.dataset.setId);
        if (!result?.claimed) button.disabled = false;
      });
    }
    if (this.legacyInheritanceOptions) {
      this.legacyInheritanceOptions.addEventListener('click', (event) => {
        const button = event.target.closest('.legacy-inheritance-option[data-set-id]');
        if (!button || button.disabled) return;
        button.disabled = true;
        const result = this.game.claimLegacyInheritance(button.dataset.setId);
        if (!result?.claimed) button.disabled = false;
      });
    }

    // 动态装备槽的点击绑定由 _renderEquipmentPanel 在创建节点后完成。
    if (this.equipmentModalClose && this.equipmentModal) {
      this.equipmentModalClose.addEventListener('click', () => this._closeEquipmentModal());
      // Click outside to close
      this.equipmentModal.addEventListener('click', (e) => {
        if (e.target === this.equipmentModal) this._closeEquipmentModal();
      });
      this.equipmentModal.addEventListener('keydown', e => {
        if (e.key === 'Escape') {
          e.preventDefault();
          this._closeEquipmentModal();
          return;
        }
        if (e.key !== 'Tab') return;
        const focusable = [...this.equipmentModal.querySelectorAll('button:not([disabled])')]
          .filter(button => button.getClientRects().length > 0);
        if (!focusable.length) return;
        const first = focusable[0];
        const last = focusable[focusable.length - 1];
        if (e.shiftKey && document.activeElement === first) {
          e.preventDefault();
          last.focus();
        } else if (!e.shiftKey && document.activeElement === last) {
          e.preventDefault();
          first.focus();
        }
      });
    }
    if (this.equipmentModalUnequip) {
      this.equipmentModalUnequip.addEventListener('click', () => {
        if (this.currentEquipmentSlot && typeof treasureSystem !== 'undefined') {
          const result = treasureSystem.unequip(this.currentEquipmentSlot);
          if (!result?.success) {
            this._showEquipmentModalError(result?.message);
            return;
          }
          this._closeEquipmentModal();
        }
      });
    }

    // Path selection (包含键盘 Enter/Space 与 1-4 快捷键支持)
    document.querySelectorAll('.path-btn').forEach(btn => {
      btn.addEventListener('click', (e) => {
        const path = e.currentTarget.dataset.path;
        this.startGame(path);
      });
      btn.addEventListener('keydown', (e) => {
        const buttons = Array.from(document.querySelectorAll('.path-btn'));
        const grid = e.currentTarget.closest('.path-floating-grid');
        const gridStyle = grid ? getComputedStyle(grid) : null;
        const columns = gridStyle?.display === 'grid'
          ? Math.max(1, gridStyle.gridTemplateColumns.split(' ').filter(Boolean).length)
          : 1;
        const movement = {
          ArrowLeft: -1,
          ArrowRight: 1,
          ArrowUp: -columns,
          ArrowDown: columns
        }[e.key];
        if (movement) {
          e.preventDefault();
          const index = buttons.indexOf(e.currentTarget);
          buttons[(index + movement + buttons.length) % buttons.length]?.focus();
        }
      });
    });

    // 移动属性面板显式 Toggle 按钮 (EX-04 / P1-07)
    const mobileAttrBtn = document.getElementById('mobile-attr-toggle-btn');
    if (mobileAttrBtn) {
      mobileAttrBtn.addEventListener('click', () => {
        const panel = document.querySelector('.attribute-panel');
        if (!panel) return;
        const isExpanded = panel.classList.toggle('mobile-expanded');
        mobileAttrBtn.setAttribute('aria-expanded', isExpanded ? 'true' : 'false');
        mobileAttrBtn.textContent = isExpanded ? '收起' : '展开';
      });
    }

    // Reincarnate
    this.reincarnateBtn.addEventListener('click', () => {
      if (!this.game.reincarnateFromDeathScreen()) {
        this._showToast('转世尚未保存，请重试');
      }
    });

    // 关联卡槽只负责查看上下文，不能误触发主卡滑动。
    if (this.cardAssociationDock) {
      ['mousedown', 'touchstart', 'pointerdown', 'click'].forEach(eventName => {
        this.cardAssociationDock.addEventListener(eventName, (event) => event.stopPropagation());
      });
      this.cardAssociationDock.addEventListener('click', (event) => {
        const relation = event.target.closest('.card-association[data-kind="character"]');
        if (relation?.dataset.refId) this.openNpcPanel(relation.dataset.refId);
      });
    }

    // Swipe on card
    this.cardEl.addEventListener('touchstart', (e) => this.onTouchStart(e), { passive: true });
    this.cardEl.addEventListener('touchmove', (e) => this.onTouchMove(e), { passive: true });
    this.cardEl.addEventListener('touchend', (e) => this.onTouchEnd(e), { passive: true });

    this.cardEl.addEventListener('mousedown', (e) => this.onMouseDown(e));
    document.addEventListener('mousemove', (e) => this.onMouseMove(e));
    document.addEventListener('mouseup', (e) => this.onMouseUp(e));

    // Hover Tilt 物理悬停效果
    this.cardEl.addEventListener('mousemove', (e) => this.onCardHover(e));
    this.cardEl.addEventListener('mouseleave', (e) => this.onCardLeave(e));
    this.cardEl.addEventListener('wheel', (e) => this._onKeyframeReadingWheel(e), { passive: false });

    // Keyboard
    document.addEventListener('keydown', (e) => {
      if (this.pathSelection && this.pathSelection.style.display !== 'none' && this.screens.start.classList.contains('active')) {
        const pathKeys = { '1': 'sword', '2': 'spell', '3': 'body', '4': 'pill' };
        if (pathKeys[e.key]) {
          this.startGame(pathKeys[e.key]);
          return;
        }
      }
      if (this.legacyBossRewardModal?.style.display === 'flex') return;
      if (this.screens.game.classList.contains('active')) {
        if (e.target.closest?.('.card-association')) return;
        if (this.cardEl.dataset.keyframeFormat === 'wide' &&
            e.target.closest?.('#card .card-body')) return;
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
    if (this.dungeonExitBtn) {
      this.dungeonExitBtn.addEventListener('click', () => this.game.abandonDungeon());
    }

    // 移动端日志收束为玉简书脊，点标题展开；按钮本身不触发展开。
    if (this.logSidebar) {
      const header = this.logSidebar.querySelector('.log-sidebar-header');
      header?.addEventListener('click', (event) => {
        if (event.target.closest('button')) return;
        this.logSidebar.classList.toggle('expanded');
      });
    }

    // Game callbacks
    this.game.onLog = (msg, cssClass) => this.addLog(msg, cssClass);
    this.game.onUpdate = () => this.renderGame();
    this.game.eventBus?.on('reincarnation:pathSelectionRequired', () => {
      this._showReincarnationPathSelection();
    });
  }

  renderStartScreen() {
    this.showScreen('start');
    this.renderSaveSlots();
    const canResume = typeof this.game.hasRecoverableSession === 'function'
      && this.game.hasRecoverableSession();
    if (this.resumeSessionShell) this.resumeSessionShell.hidden = !canResume;
    if (canResume && this.resumeSessionCopy && typeof gameState !== 'undefined') {
      const storyCount = gameState.unlocks?.storyThreadState?.activeThreads?.length || 0;
      const seedCount = Array.isArray(gameState.karmaSeeds) ? gameState.karmaSeeds.length : 0;
      const realmName = gameState.getRealmName?.(gameState.realm) || gameState.realm || '炼气';
      this.resumeSessionCopy.textContent =
        `第 ${Math.max(1, Number(gameState.unlocks?.lifeCount || 0) + 1)} 世 · ` +
        `${realmName} · 剧情 ${storyCount} · 因果 ${seedCount}`;
    }
    const awaitingReincarnationPath = Boolean(
      !canResume
      && Number(gameState?.getLifeCount?.() || 0) > 0
      && !gameState?.path
      && Array.isArray(gameState?.deck)
      && gameState.deck.length === 0
    );
    if (awaitingReincarnationPath) {
      this._showReincarnationPathSelection();
      return;
    }
    // 重置为名字输入阶段
    if (this.nameCreation) this.nameCreation.style.display = 'block';
    if (this.pathSelection) this.pathSelection.style.display = 'none';
    const heading = this.pathSelection?.querySelector('.path-section-header h2');
    const subtitle = this.pathSelection?.querySelector('.path-subtitle');
    if (heading) heading.textContent = '择道立誓 · 传承功法';
    if (subtitle) subtitle.textContent = '修仙之道，各有所长；一经选择，宿命启程';
    if (this.nameInput) {
      this.nameInput.value = '';
      if (this.nameCharCount) this.nameCharCount.textContent = '0/4';
    }
  }

  _announceSaveSlot(message) {
    if (!this.saveSlotStatus) return;
    this.saveSlotStatus.textContent = '';
    queueMicrotask(() => {
      this.saveSlotStatus.textContent = message;
    });
  }

  _reloadAfterSaveSlotChange(result, message) {
    if (!result || (!result.activated && !result.created && !result.deleted)) return false;
    this._announceSaveSlot(message);
    if (result.requiresReload && typeof window !== 'undefined' && window.location) {
      window.location.reload();
      return true;
    }
    this.renderSaveSlots();
    return true;
  }

  _handleSaveSlotAction(action, slotId) {
    if (typeof gameState === 'undefined' || !gameState) return false;
    if (action === 'current') {
      this._announceSaveSlot('当前已经在使用这枚轮回玉简。');
      return true;
    }
    if (action === 'create' && typeof gameState.createSaveSlot === 'function') {
      const result = gameState.createSaveSlot({ slotId, activate: true });
      if (!result.created) {
        this._announceSaveSlot('未能开辟这枚轮回玉简。');
        return false;
      }
      return this._reloadAfterSaveSlotChange(result, '新玉简已开辟，正在载入。');
    }
    if (action === 'select' && typeof gameState.activateSaveSlot === 'function') {
      const result = gameState.activateSaveSlot(slotId);
      if (!result.activated) {
        this._announceSaveSlot('未能载入这枚轮回玉简。');
        return false;
      }
      return this._reloadAfterSaveSlotChange(result, '轮回玉简已切换，正在恢复其因果。');
    }
    if (action === 'delete' && typeof gameState.deleteSaveSlot === 'function') {
      const slot = gameState.listSaveSlots?.().find(item => item.slotId === slotId);
      const label = slot?.label || '这枚玉简';
      const confirmed = typeof window === 'undefined'
        || typeof window.confirm !== 'function'
        || window.confirm(`确定清空“${label}”吗？其中的当世、传承、好感与历世谱系都将删除。`);
      if (!confirmed) {
        this._announceSaveSlot('已取消清空玉简。');
        return false;
      }
      const result = gameState.deleteSaveSlot(slotId);
      if (!result.deleted) {
        this._announceSaveSlot('未能清空这枚轮回玉简。');
        return false;
      }
      return this._reloadAfterSaveSlotChange(result, '玉简已清空。');
    }
    return false;
  }

  renderSaveSlots() {
    if (!this.saveSlotList || typeof gameState === 'undefined'
      || typeof gameState.listSaveSlots !== 'function') return;
    const realmLabels = {
      qi: '炼气',
      foundation: '筑基',
      golden: '金丹',
      nascent: '元婴',
      deity: '化神',
      tribulation: '渡劫'
    };
    const pathLabels = {
      sword: '剑修',
      spell: '法修',
      body: '体修',
      pill: '丹修'
    };
    const slots = gameState.listSaveSlots();
    this.saveSlotList.textContent = '';

    for (const slot of slots) {
      const item = document.createElement('article');
      item.className = `save-slot-card${slot.active ? ' is-active' : ''}${slot.corrupted ? ' is-corrupted' : ''}`;
      item.setAttribute('role', 'listitem');
      if (slot.active) item.setAttribute('aria-current', 'true');

      const seal = document.createElement('span');
      seal.className = 'save-slot-seal';
      seal.setAttribute('aria-hidden', 'true');
      seal.textContent = slot.slotId.slice(-1);

      const copy = document.createElement('div');
      copy.className = 'save-slot-copy';
      const title = document.createElement('strong');
      title.textContent = slot.label;
      const summary = document.createElement('span');
      if (slot.corrupted) {
        summary.textContent = '存档损坏 · 可清空重建';
      } else if (!slot.occupied) {
        summary.textContent = '空玉简 · 尚无因果';
      } else {
        const identity = slot.playerName ? `${slot.playerName} · ` : '';
        const path = slot.path ? ` · ${pathLabels[slot.path] || slot.path}` : '';
        summary.textContent =
          `${identity}第 ${slot.currentLife} 世 · ${realmLabels[slot.realm] || slot.realm}${path} · ` +
          `${slot.turn} 次决断 · 历世 ${slot.lineageCount}`;
      }
      copy.append(title, summary);

      const actions = document.createElement('div');
      actions.className = 'save-slot-actions';
      const primary = document.createElement('button');
      primary.type = 'button';
      primary.className = 'save-slot-primary';
      primary.dataset.saveSlotId = slot.slotId;
      if (slot.active) {
        primary.dataset.saveSlotAction = 'current';
        primary.textContent = slot.occupied ? '当前玉简' : '当前空玉简';
        primary.setAttribute('aria-pressed', 'true');
      } else if (slot.occupied) {
        primary.dataset.saveSlotAction = 'select';
        primary.textContent = slot.corrupted ? '尝试载入' : '载入';
      } else {
        primary.dataset.saveSlotAction = 'create';
        primary.textContent = '开辟';
      }
      actions.appendChild(primary);

      if (slot.occupied) {
        const remove = document.createElement('button');
        remove.type = 'button';
        remove.className = 'save-slot-delete';
        remove.dataset.saveSlotAction = 'delete';
        remove.dataset.saveSlotId = slot.slotId;
        remove.setAttribute('aria-label', `清空${slot.label}`);
        remove.textContent = '清空';
        actions.appendChild(remove);
      }

      item.append(seal, copy, actions);
      this.saveSlotList.appendChild(item);
    }
  }

  _showReincarnationPathSelection() {
    this.showScreen('start');
    if (this.resumeSessionShell) this.resumeSessionShell.hidden = true;
    if (this.nameCreation) this.nameCreation.style.display = 'none';
    if (this.pathSelection) this.pathSelection.style.display = 'block';
    if (typeof window !== 'undefined' && typeof window.ensurePath3DArtifacts === 'function') {
      window.ensurePath3DArtifacts();
    }
    const heading = this.pathSelection?.querySelector('.path-section-header h2');
    const subtitle = this.pathSelection?.querySelector('.path-subtitle');
    if (heading) heading.textContent = `第 ${Math.max(2, Number(gameState?.getLifeCount?.() || 0) + 1)} 世 · 重新择道`;
    if (subtitle) subtitle.textContent = '前世传承仍在档案中；先定今生流派，再选择一套传承转译为本世绝学';
    queueMicrotask(() => this.pathSelection?.querySelector('.path-btn')?.focus?.());
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
    if (typeof window !== 'undefined' && typeof window.ensurePath3DArtifacts === 'function') {
      window.ensurePath3DArtifacts();
    }
    // 滚动到功法选择区域
    if (this.pathSelection) this.pathSelection.scrollIntoView({ behavior: 'smooth' });
  }

  startGame(path) {
    document.getElementById('choice-outcome-receipts')?.replaceChildren();
    this.game.start(path);
    this.showScreen('game');
    this.logMessages = [];
    this.renderGame();
  }

  resumeGame() {
    if (typeof this.game.resumeSession !== 'function' || !this.game.resumeSession()) return false;
    this.logMessages = [];
    const activeDeckCombat = this.game?.combatCoordinator?.deckCombatSystem
      || (typeof deckCombatSystem !== 'undefined' ? deckCombatSystem : null);
    if (activeDeckCombat?.active) {
      this.showScreen('combat');
      eventBus.emit('combat:started', activeDeckCombat._getPresentationContext());
      activeDeckCombat._triggerUpdate();
    } else {
      this.showScreen('game');
      this.renderGame();
    }
    return true;
  }

  _isScreenFocusCandidate(element, screen) {
    return !!(element &&
      screen &&
      screen.contains(element) &&
      !element.disabled &&
      !element.hidden &&
      element.getAttribute?.('aria-hidden') !== 'true');
  }

  _focusScreenTarget(screen) {
    if (!screen || screen.inert || screen.getAttribute('aria-hidden') === 'true') return false;

    let destination = null;
    if (screen === this.screens.game && Array.isArray(this.choiceButtons)) {
      destination = this.choiceButtons.find(button => (
        this._isScreenFocusCandidate(button, screen)
      )) || null;
    }
    if (!destination && typeof screen.querySelector === 'function') {
      const candidate = screen.querySelector(
        '[data-screen-focus], button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), a[href], [tabindex]:not([tabindex="-1"])'
      );
      if (this._isScreenFocusCandidate(candidate, screen)) destination = candidate;
    }
    if (!destination) {
      if (!screen.hasAttribute('tabindex')) screen.setAttribute('tabindex', '-1');
      destination = screen;
    }

    try {
      destination.focus({ preventScroll: true });
    } catch (error) {
      destination.focus();
    }
    if (document.activeElement !== destination && destination !== screen) {
      if (!screen.hasAttribute('tabindex')) screen.setAttribute('tabindex', '-1');
      screen.focus({ preventScroll: true });
    }
    return screen.contains(document.activeElement);
  }

  showScreen(name) {
    const target = this.screens[name];
    if (!target) return;
    const screenChanged = !target.classList.contains('active');
    const exhibitIsLeaving = name !== 'game' && !!this._narrativeExhibit?.dialog?.open;
    if (name !== 'game') this._narrativeExhibit?.clear();
    if (screenChanged) {
      const litPixel = typeof window !== 'undefined' ? window.litPixelRenderer : null;
      litPixel?.stopLightAnimation?.();
      ['npc-panel', 'companion-panel'].forEach(id => {
        const panel = document.getElementById(id);
        if (panel) panel.style.display = 'none';
      });
    }
    const activeElement = document.activeElement;
    const focusIsLeaving = exhibitIsLeaving || Object.values(this.screens).some(screen => (
      screen &&
      screen !== target &&
      screen.contains(activeElement)
    ));

    // 先激活新屏并交接焦点，再隐藏旧屏，避免焦点短暂停留在 aria-hidden 子树。
    target.classList.add('active');
    target.inert = false;
    target.setAttribute('aria-hidden', 'false');
    if (focusIsLeaving) this._focusScreenTarget(target);

    Object.values(this.screens).forEach(screen => {
      if (!screen || screen === target) return;
      screen.classList.remove('active');
      screen.inert = true;
      screen.setAttribute('aria-hidden', 'true');
      // 清理旧 HTML 中遗留的内联 display，屏幕可见性只由 active 状态控制。
      if (screen.id === 'deck-combat-screen') screen.style.removeProperty('display');
    });

    // 战斗结算监听器会在同一事件栈内重绘结果卡；微任务后再对准最新可用选项。
    if (focusIsLeaving) {
      const refocus = () => {
        if (target.classList.contains('active') &&
            !target.inert &&
            target.getAttribute('aria-hidden') === 'false') {
          this._focusScreenTarget(target);
        }
      };
      if (typeof queueMicrotask === 'function') queueMicrotask(refocus);
      else Promise.resolve().then(refocus);
    }
  }

  renderGame() {
    this.renderTopBar();
    const tianjiBeforeCard = gameState.getAttribute('tianji');
    this.renderAttributes();
    this.renderPassives();
    this.renderCard();
    if (gameState.getAttribute('tianji') !== tianjiBeforeCard) this.renderAttributes();
    this.renderLog();
    this.renderLegacyBossReward();
    this.renderLegacyInheritance();
    this.openLoadoutDecision();
    if (this.dungeonExitBtn) this.dungeonExitBtn.hidden = !gameState.dungeon;

    if (gameState.dead) {
      const card = this.game.getCurrentCard();
      if (card && card.id && (card.id.startsWith('death_') || card.id.startsWith('ending_'))) {
        // 当前正在展示死亡卡或结局卡，允许玩家看到并选择后再进入转世流程
      } else {
        this.renderDeathScreen();
        this.showScreen('death');
      }
    }
  }

  renderLegacyBossReward() {
    if (!this.legacyBossRewardModal || !this.legacyBossRewardOptions) return;
    delete this.legacyBossRewardModal.dataset.visualWorldId;
    delete this.legacyBossRewardModal.dataset.uiMaterialId;
    delete this.legacyBossRewardModal.dataset.visualSurface;
    const pending = typeof legacyFragmentSystem !== 'undefined' && legacyFragmentSystem
      ? legacyFragmentSystem.getPendingBossReward()
      : null;
    if (!pending) {
      this.legacyBossRewardModal.style.display = 'none';
      this.legacyBossRewardModal.setAttribute('aria-hidden', 'true');
      this._applyReviewedWorldShellPresentation(this.game?.getCurrentCard?.() || null);
      return;
    }

    const rewardPresentation = pending.rewardPresentation;
    const reviewedReward = rewardPresentation?.visualWorldId === 'cangmang_sect_pc98_v1'
      && rewardPresentation?.uiMaterialId === 'sect_field_ledger_v1'
      && rewardPresentation?.visualSurface === 'boss_fragment_choice';
    if (reviewedReward) {
      this.legacyBossRewardModal.dataset.visualWorldId = rewardPresentation.visualWorldId;
      this.legacyBossRewardModal.dataset.uiMaterialId = rewardPresentation.uiMaterialId;
      this.legacyBossRewardModal.dataset.visualSurface = rewardPresentation.visualSurface;
    }
    this._applyReviewedWorldShellPresentation(
      this.game?.getCurrentCard?.() || null,
      rewardPresentation
    );

    const options = legacyFragmentSystem.getBossRewardOptions();
    const deckAuthority = this.game?.skillCardAcquisitionSystem
      || (typeof skillCardAcquisitionSystem !== 'undefined' ? skillCardAcquisitionSystem : null);
    this.legacyBossRewardOptions.textContent = '';
    for (const option of options) {
      const variant = deckAuthority?.getCardDefinition(option.variantCardId);
      const variantPreview = variant
        ? (reviewedReward
          ? `本脉绝学：${variant.name}`
          : `本流派绝学：${variant.name}（${variant.description || ''}）`)
        : `本流派绝学：${option.variantCardId || '加载中'}`;
      const optionIcon = reviewedReward ? (option.sigil || option.icon) : option.icon;
      const button = document.createElement('button');
      button.type = 'button';
      button.className = 'legacy-boss-reward-option';
      button.dataset.setId = option.setId;
      button.innerHTML = `
        <span class="legacy-boss-option-icon" aria-hidden="true">${optionIcon}</span>
        <span class="legacy-boss-option-body">
          <strong>${option.name}</strong>
          <small>${option.count}/${option.total} · ${option.focused ? '当前追踪' : '可推进传承'}</small>
          <small>${variantPreview}</small>
          <small>${option.effect}</small>
        </span>
        <span class="legacy-boss-option-claim">择此残卷</span>
      `;
      this.legacyBossRewardOptions.appendChild(button);
    }
    if (this.legacyBossRewardCopy) {
      const bossName = this.game?.cardSystem?.getCard?.(pending.cardId)?.title || '此境首领';
      this.legacyBossRewardCopy.textContent = `${bossName} 已伏。选择一套传承领取一片；本次胜利仅能领取一次。`;
    }
    const wasHidden = this.legacyBossRewardModal.style.display !== 'flex';
    this.legacyBossRewardModal.style.display = 'flex';
    this.legacyBossRewardModal.setAttribute('aria-hidden', 'false');
    if (wasHidden) queueMicrotask(() => this.legacyBossRewardOptions.querySelector('button')?.focus());
  }

  renderLegacyInheritance() {
    if (!this.legacyInheritanceModal || !this.legacyInheritanceOptions) return;
    const pending = typeof legacyFragmentSystem !== 'undefined'
      && legacyFragmentSystem
      && typeof legacyFragmentSystem.getPendingInheritanceChoice === 'function'
      ? legacyFragmentSystem.getPendingInheritanceChoice()
      : null;
    if (!pending) {
      this.legacyInheritanceModal.style.display = 'none';
      this.legacyInheritanceModal.setAttribute('aria-hidden', 'true');
      return;
    }

    const options = legacyFragmentSystem.getInheritanceOptions();
    this.legacyInheritanceOptions.textContent = '';
    for (const option of options) {
      const button = document.createElement('button');
      button.type = 'button';
      button.className = 'legacy-boss-reward-option legacy-inheritance-option';
      button.dataset.setId = option.setId;
      const cost = option.cardCost === null ? '' : ` · ${option.cardCost} 灵力`;
      button.innerHTML = `
        <span class="legacy-boss-option-icon" aria-hidden="true">${option.icon}</span>
        <span class="legacy-boss-option-body">
          <strong>${option.name}</strong>
          <small>本世绝学：${option.cardName}${cost}</small>
          <small>${this._narrativeHtml(option.cardDescription)}</small>
          <small>${option.effect}</small>
        </span>
        <span class="legacy-boss-option-claim">继承此脉</span>
      `;
      this.legacyInheritanceOptions.appendChild(button);
    }
    if (this.legacyInheritanceCopy) {
      this.legacyInheritanceCopy.textContent =
        `第 ${pending.lifeCount + 1} 世已选择${gameState.getPathName(pending.path)}。`
        + `从 ${options.length} 套前世传承中继承一套；其余仍留在档案。`;
    }
    const wasHidden = this.legacyInheritanceModal.style.display !== 'flex';
    this.legacyInheritanceModal.style.display = 'flex';
    this.legacyInheritanceModal.setAttribute('aria-hidden', 'false');
    if (wasHidden) queueMicrotask(() => this.legacyInheritanceOptions.querySelector('button')?.focus());
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

    // ── 当前目标提示 ──
    if (this.topObjective) {
      const realmConfig = gameState.config.realms
        ? (gameState.config.realms.realms || {})[gameState.realm]
        : null;
      const realmOrder = gameState.config.realms ? (gameState.config.realms.order || []) : [];
      const currentRealmIdx = realmOrder.indexOf(gameState.realm);
      const nextRealm = realmOrder[currentRealmIdx + 1];
      const nextRealmName = nextRealm ? gameState.getRealmName(nextRealm) : '';
      const threshold = realmConfig ? realmConfig.cultivationThreshold : 100;
      const currentCult = gameState.attributes.cultivation || 0;

      let objText = '';
      if (gameState.realm === 'tribulation') {
        objText = '目标：渡劫飞升，证道成仙';
      } else if (currentCult >= threshold) {
        objText = `目标：准备突破，觅地闭关`;
      } else {
        objText = `目标：积累${threshold}修为突破${nextRealmName || ''}`;
      }
      this.topObjective.textContent = objText;
      this.topObjective.style.display = 'inline-block';
    }

    // ── 寿命预警 ──
    if (this.resLifespan && this.topLifespan) {
      const lifespan = gameState.resources.lifespan || 0;
      if (lifespan < 20) {
        this.resLifespan.classList.add('lifespan-warning');
        this.topLifespan.textContent = `${lifespan} ⚠️`;
      } else {
        this.resLifespan.classList.remove('lifespan-warning');
        this.topLifespan.textContent = lifespan;
      }
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
    if (typeof worldArtDirector !== 'undefined') worldArtDirector.setTime(timeStr);
  }

  /** 位置栏 — 从 SceneLayerSystem 获取当前位置 */
  _updateLocationBar() {
    if (!this.locName) return;
    try {
      const loc = (typeof sceneLayerSystem !== 'undefined' && sceneLayerSystem)
        ? sceneLayerSystem.getCurrentLocation()
        : null;
      if (loc) {
        const icons = { '宗门': '宗', '坊市': '市', '秘境': '境', '洞府': '府', '魔域': '魔', '天道虚空': '道' };
        this.locIcon.textContent = icons[loc.id] || '位';
        this.locName.textContent = `${loc.name} · ${loc.sublocation || ''}`;
        this.locMood.textContent = loc.atmosphere || '风轻云淡，万物静默。';
      } else {
        this.locIcon.textContent = '宗';
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
    this.btLabel.textContent = `破 · ${nextRealm || '下一境界'}进度`;
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
      fortune: '福缘', health: '气血', tianji: '天机'
    };
    for (const [key, bar] of Object.entries(this.bars)) {
      if (!bar || !this.labels[key]) continue;
      const value = attrs[key] || 0;
      const max = this._attributeMax(key);
      const ratio = Math.max(0, Math.min(1, value / Math.max(1, max)));
      const presentation = this._attributePresentation(key, ratio, value);
      bar.style.width = `${Math.round(ratio * 100)}%`;
      bar.textContent = '';
      const suffix = key === 'cultivation' ? `<span class="attr-denominator">/ ${max}</span>` : '';
      this.labels[key].innerHTML = `<span class="attr-name">${labels[key]}</span><span class="attr-state">${presentation.label}</span><span class="attr-value">${value}${suffix}</span>`;

      const item = bar.closest('.attr-item');
      if (item) {
        item.dataset.state = presentation.tone;
        item.classList.toggle('critical', presentation.tone === 'critical');
      }
    }

    if (this.panelSubtitle) {
      const life = typeof gameState.getLifeCount === 'function' ? gameState.getLifeCount() + 1 : 1;
      this.panelSubtitle.textContent = `命盘流转 · 第 ${life} 世`;
    }

    // 闭环渲染装备与法宝面板
    this._renderEquipmentPanel();
  }

  /**
   * 渲染装备/法宝槽位与交互面板
   */
  _renderEquipmentPanel() {
    let eqContainer = document.querySelector('.equipment-slots-container');
    if (!eqContainer) {
      const parent = document.querySelector('.attribute-panel') || document.querySelector('#sidebar');
      if (!parent) return;
      eqContainer = document.createElement('div');
      eqContainer.className = 'equipment-slots-container';
      parent.appendChild(eqContainer);
    }

    const slots = [
      { id: 'weapon', label: '武器', glyph: '武' },
      { id: 'armor', label: '防具', glyph: '甲' },
      { id: 'accessory', label: '饰品', glyph: '饰' },
      { id: 'artifact', label: '秘宝', glyph: '宝' }
    ];

    eqContainer.innerHTML = slots.map(s => {
      const treasureId = (typeof treasureSystem !== 'undefined' && treasureSystem)
        ? treasureSystem.getEquipped(s.id)
        : gameState.equipment?.[s.id];
      const treasure = (treasureId && typeof treasureSystem !== 'undefined') ? treasureSystem.getTreasureData(treasureId) : null;
      const name = treasure ? treasure.name : s.label;
      const rarity = treasure ? (treasure.rarity || 'common') : 'common';
      const action = treasure ? `查看${s.label}：${name}` : `选择${s.label}，当前未装备`;
      return `
        <button class="eq-slot" type="button" data-slot="${s.id}" data-rarity="${this._escapeHtml(rarity)}" aria-label="${this._escapeHtml(action)}">
          <span class="eq-slot-icon" aria-hidden="true">${s.glyph}</span>
          <span class="eq-slot-text"><span class="eq-slot-type">${s.label}</span><span class="eq-slot-name">${this._escapeHtml(treasure ? name : '未装备')}</span></span>
        </button>
      `;
    }).join('');

    const pending = gameState.pendingLoadoutDecision;
    if (pending?.status === 'pending') {
      const pendingTreasure = typeof treasureSystem !== 'undefined'
        ? treasureSystem.getTreasureData(pending.instanceId)
        : null;
      const resume = document.createElement('button');
      resume.type = 'button';
      resume.className = 'loadout-resume-btn';
      resume.textContent = `待装配 · ${pendingTreasure?.name || '新法宝'}（继续决定）`;
      resume.addEventListener('click', () => this.openLoadoutDecision({ force: true }));
      eqContainer.appendChild(resume);
    }

    eqContainer.querySelectorAll('.eq-slot').forEach(slotEl => {
      slotEl.addEventListener('click', () => {
        const slot = slotEl.dataset.slot;
        this.openEquipmentModal(slot);
      });
    });
  }

  _attributeMax(key) {
    if (key === 'health') return (typeof gameState.getActualMaxHealth === 'function' ? gameState.getActualMaxHealth() : gameState.maxHealth) || 3;
    if (key === 'daoHeart') return (typeof gameState.getActualMaxDaoHeart === 'function' ? gameState.getActualMaxDaoHeart() : gameState.maxDaoHeart) || 3;
    if (key === 'cultivation') {
      return gameState.config?.realms?.realms?.[gameState.realm]?.cultivationThreshold || 100;
    }
    return 100;
  }

  _attributePresentation(key, ratio, value) {
    if (key === 'tianji') {
      if (ratio >= 0.75) return { label: '天罚将至', tone: 'critical' };
      if (ratio >= 0.4) return { label: '天机渐露', tone: 'warning' };
      if (value > 0) return { label: '微有感应', tone: 'steady' };
      return { label: '未被窥见', tone: 'dormant' };
    }
    if (key === 'karmaBad') return ratio >= 0.55 ? { label: '业影缠身', tone: 'warning' } : { label: value ? '业痕初结' : '未染恶业', tone: value ? 'steady' : 'dormant' };
    if (key === 'karmaGood') return ratio >= 0.55 ? { label: '善缘深厚', tone: 'radiant' } : { label: value ? '善缘初结' : '因果未显', tone: value ? 'steady' : 'dormant' };
    if (key === 'health') {
      if (ratio <= 0.34) return { label: '气血危殆', tone: 'critical' };
      if (ratio <= 0.67) return { label: '脉息不稳', tone: 'warning' };
      return { label: '气血充盈', tone: 'radiant' };
    }
    if (key === 'daoHeart') {
      if (ratio <= 0.34) return { label: '道心动摇', tone: 'critical' };
      if (ratio <= 0.67) return { label: '心境微澜', tone: 'warning' };
      return { label: '道心澄明', tone: 'radiant' };
    }
    if (key === 'fortune') return ratio >= 0.7 ? { label: '紫气相随', tone: 'radiant' } : ratio < 0.3 ? { label: '时运低回', tone: 'warning' } : { label: '气运平和', tone: 'steady' };
    if (ratio >= 0.85) return { label: '只待破境', tone: 'radiant' };
    if (ratio >= 0.55) return { label: '渐入佳境', tone: 'steady' };
    if (ratio > 0) return { label: '灵息初聚', tone: 'steady' };
    return { label: '尚未启程', tone: 'dormant' };
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
    if (card?.artDirection?.presentation !== 'scene' || !card?.sceneImage) {
      this._clearKeyframeReading();
    }
    this._renderEndingReport(card);
    this._narrativeExhibit?.clear();
    delete this.cardEl.dataset.narrativeArt;
    this.cardEl.style.removeProperty('--narrative-accent');
    this._applyReviewedWorldShellPresentation(card);
    if (!card) return;
    this.choicePreviewDetails?.querySelectorAll('details').forEach(detail => {
      detail.hidden = true;
      detail.open = false;
    });
    this.currentCard = card; // 保存引用，用于滑动阻力计算
    const visualPriority = typeof cardSystem !== 'undefined' ? cardSystem.getLastDrawnPriority() : 0;
    this._refreshSwipeChoicePreviews(card);

    // ==================== 安全重置：确保卡牌容器可见（防止动画残留 opacity:0）====================
    this.cardEl.style.opacity = '1';
    this.cardEl.style.transform = 'translate(0, 0) rotate(0)';
    this.cardEl.style.display = '';
    this.cardEl.style.visibility = 'visible';
    this.cardEl.classList.remove('card-location', 'card-combat', 'card-karma', 'card-bottleneck', 'card-breakthrough', 'card-shop', 'card-destiny', 'card-story', 'has-narrative-spine-summary');
    if (this.narrativeSpineSummary) {
      this.narrativeSpineSummary.hidden = true;
      this.narrativeSpineSummary.textContent = '';
    }

    // ==================== 清除上一张卡的立绘残留（解决异步竞态） ====================
    this._portraitGen = (this._portraitGen || 0) + 1;
    const portraitDiv = document.getElementById('card-portrait');
    if (portraitDiv) {
      this._beginPortraitRender(portraitDiv);
      portraitDiv._portraitNpcId = null;
      portraitDiv.style.display = 'none';
      portraitDiv.style.backgroundImage = '';
      portraitDiv.innerHTML = '';
    }
    if (this.cardAssociationDock) {
      this.cardAssociationDock.hidden = true;
      this.cardAssociationDock.innerHTML = '';
    }
    this.cardEl.style.backgroundImage = '';

    // ==================== v2.0 特殊卡牌分支 ====================
    if (card.type === 'COMBAT_UI') {
      this._renderCombatCard(card);
      this._presentVisualStory(card, visualPriority);
      return;
    }
    if (card.type === 'INNER_DEMON') {
      this._renderInnerDemonCard(card);
      this._presentVisualStory(card, visualPriority);
      return;
    }
    if (card.type === 'DESTINY_WHEEL') {
      this._renderDestinyWheelCard(card);
      this._presentVisualStory(card, visualPriority);
      return;
    }
    if (card.type === 'KARMA_RIPPLE') {
      this._renderKarmaRippleCard(card);
      this._presentVisualStory(card, visualPriority);
      return;
    }
    if (card.type === 'HEAVENS_HINT') {
      this._renderHeavensHintCard(card);
      this._presentVisualStory(card, visualPriority);
      return;
    }
    if (card.type === 'NPC_CROSS') {
      this._renderNpcCrossCard(card);
      this._presentVisualStory(card, visualPriority);
      return;
    }
    if (card.type === 'SPECIAL') {
      this._renderSpecialCard(card);
      this._presentVisualStory(card, visualPriority);
      return;
    }
    if (card.type === 'LOCATION') {
      this._renderLocationCard(card);
      this._presentVisualStory(card, visualPriority);
      return;
    }

    this.cardTitle.textContent = card.title;
    // ── 叙事连贯性层：动态增强描述（支线×线程交叉引用）──
    let descText = card.description;
    if (typeof coherenceLayer !== 'undefined' && coherenceLayer) {
      try {
        const enhanced = coherenceLayer.enhanceDescription(
          card, this._getGameState(), this._getThreadEngine(), this._getQuestSystem()
        );
        if (enhanced && enhanced !== card.description) {
          descText = enhanced;
        }
      } catch (e) {
        console.warn('coherenceLayer.enhanceDescription error:', e);
      }
    }
    this.cardDesc.textContent = this._normalizeNarrativeText(descText);

    // ======== 故事线程指示器 ========
    this._renderThreadIndicator(card);

    // ======== NPC角色立绘 —异步加载，不阻塞 choices 渲染 ========
    // S0 is an authored reincarnation-memory identity, not a fake "mortal"
    // realm. Resolve it through DeckCombatSystem's public presentation
    // authority so the stage/path carrier cannot diverge across reload.
    const protagonistIdentity = this._resolveNarrativeProtagonistIdentity(card);
    const npcId = card.npcId || card.compId || (card.npcIds && card.npcIds[0]);
    const isNarrativeKeyframe = card.artDirection?.presentation === 'scene' && !!card.sceneImage;
    if (isNarrativeKeyframe && portraitDiv) {
      portraitDiv.style.display = 'flex';
      const scene = document.createElement('img');
      scene.className = 'narrative-keyframe-image';
      scene.src = card.sceneImage;
      scene.alt = card.artDirection?.alt || card.title;
      portraitDiv.appendChild(scene);
      const switchButton = document.getElementById('portrait-switch-btn');
      if (switchButton) switchButton.style.display = 'none';
      this.cardEl.dataset.narrativeArt = 'keyframe';
    } else if (protagonistIdentity && portraitDiv) {
      this._renderNarrativeProtagonistIdentity(card, protagonistIdentity, portraitDiv);
    } else if (npcId && portraitDiv) {
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
    let typeName = this.getCardTypeName(card.type);
    if (card.tags && card.tags.includes('tutorial')) {
      typeName = '入门引导';
    }
    const priority = visualPriority;
    if (card.type === 'QUEST') {
      this.cardType.textContent = `支线任务`;
    } else if (priority === 60) {
      this.cardType.textContent = `因果 · ${typeName}`;
    } else if (priority === 90) {
      this.cardType.textContent = `突破 · ${typeName}`;
    } else {
      this.cardType.textContent = typeName;
    }
    if (card.narrativeSpine?.label && Number.isFinite(Number(card.narrativeSpine.step))) {
      this.cardType.textContent = `${card.narrativeSpine.label} ${card.narrativeSpine.step}/${card.narrativeSpine.totalSteps || 5}`;
    }

    // ── 来源标签显示 ──
    if (card._flowSource && this.cardSource) {
      const sourceMap = {
        'karma': '因果',
        'quest:current': '主线',
        'quest:entry': '支线',
        'milestone': '天关',
        'shop': '坊市',
        'market': '鬼市',
        'combat_warning': '敌袭',
        'fallback': '流转'
      };

      let sourceText = '';
      if (card._flowSource.startsWith('normal:')) sourceText = '浮世';
      else if (card._flowSource.startsWith('narrative:')) sourceText = '故事';
      else if (card._flowSource.startsWith('pending:')) sourceText = '伏笔';
      else if (card._flowSource.startsWith('interrupt:')) sourceText = '变数';
      else sourceText = sourceMap[card._flowSource] || card._flowSource;

      this.cardSource.textContent = sourceText;
      this.cardSource.style.display = 'inline-block';
    } else if (this.cardSource) {
      this.cardSource.style.display = 'none';
    }

    // Reset card
    this.cardEl.style.transform = 'translate(0, 0) rotate(0)';
    let cardClass = `card card-${(card.type || 'normal').toLowerCase()} card-immersive`;
    if (card.tags && card.tags.includes('tutorial')) {
      cardClass += ' card-tutorial';
    }
    if (card.sceneImage) {
      cardClass += ' has-scene-art';
    }
    const isReviewedWorldLedger = card.visualWorldId === 'cangmang_sect_pc98_v1'
      && card.uiMaterialId === 'sect_field_ledger_v1'
      && ['combat_settlement_ledger', 'realm_arrival_ledger'].includes(card.visualSurface);
    if (isReviewedWorldLedger) {
      cardClass += ' card-combat-reward';
      this.cardEl.dataset.visualWorldId = card.visualWorldId;
      this.cardEl.dataset.uiMaterialId = card.uiMaterialId || '';
      this.cardEl.dataset.visualSurface = card.visualSurface;
    } else {
      delete this.cardEl.dataset.visualWorldId;
      delete this.cardEl.dataset.uiMaterialId;
      delete this.cardEl.dataset.visualSurface;
    }
    // Identity carriers are transparent people over authored scenes. Keep
    // their midtones readable; the generic scene card treatment is designed
    // for painted keyframes and otherwise buries a small pixel figure.
    if (protagonistIdentity?.actorCard) {
      cardClass += ' has-protagonist-identity';
    }
    this.cardEl.className = cardClass;
    this._renderNarrativeSpineSummary(card, descText);
    this._presentVisualStory(card, priority);
    this._syncNarrativeExhibit(card);
    this._syncKeyframeReading(card);

    // 角色、任务、物品统一收束为左下角关联卡槽，悬浮/聚焦再展开完整卡片。
    this._renderCardAssociations(card);

    // ======== 场景图动态背景 ========
    if (card.sceneImage) {
      this.cardEl.style.backgroundImage = `url('${card.sceneImage}')`;
    } else {
      this.cardEl.style.backgroundImage = 'none';
    }

    // Reset choice buttons
    this._setChoiceRailPresentation(card);
    this._resetChoiceButtons();

    // Show available choices
    const dirs = this.game.getAvailableDirections(card);
    dirs.forEach(dir => {
      const btn = this.getChoiceButton(dir);
      const choice = card.choices[dir];
      if (btn && choice) {
        this._presentChoiceButton(btn, choice);
      }
    });
  }

  /**
   * Project a reviewed post-combat receipt onto the game shell.  This is a
   * presentation-only consumer: the current card / pending boss reward remain
   * the authorities, while the DOM dataset merely scopes world-owned material.
   * Unknown worlds, materials, surfaces or scene paths clear immediately.
   */
  _applyReviewedWorldShellPresentation(card = null, rewardPresentation = null) {
    const shell = this.screens.game;
    if (!shell) return false;

    const materialTargets = [shell, this.legacyBossRewardModal].filter(Boolean);
    const clear = () => {
      delete shell.dataset.visualWorldId;
      delete shell.dataset.uiMaterialId;
      delete shell.dataset.visualSurface;
      materialTargets.forEach(target => {
        target.style.removeProperty('--world-shell-scene-image');
        target.style.removeProperty('--world-ui-status-ledger-panel');
        target.style.removeProperty('--world-ui-hand-tray-frame');
        target.style.removeProperty('--world-ui-action-button-frame');
        target.style.removeProperty('--world-ui-hand-card-frame');
      });
    };
    clear();

    const reviewedWorld = card?.visualWorldId === 'cangmang_sect_pc98_v1'
      && card?.uiMaterialId === 'sect_field_ledger_v1';
    const reviewedCardSurface = reviewedWorld
      && ['combat_settlement_ledger', 'realm_arrival_ledger'].includes(card?.visualSurface);
    const sceneImage = reviewedCardSurface && typeof card.sceneImage === 'string'
      && /^assets\/combat\/battlefields\/[a-z0-9_./-]+\.(?:png|webp)$/i.test(card.sceneImage)
      ? card.sceneImage
      : null;
    const visualWorldRegistry = typeof dataLoader !== 'undefined' && dataLoader
      && typeof dataLoader.loadSync === 'function'
      ? dataLoader.loadSync('combat:visual_worlds')
      : null;
    const material = visualWorldRegistry?.contractId === 'combat_visual_world_registry_v1'
      ? visualWorldRegistry.worlds?.[card?.visualWorldId]?.uiMaterial
      : null;
    const requiredSurfaces = [
      ['status_ledger_panel', '--world-ui-status-ledger-panel'],
      ['hand_tray_frame', '--world-ui-hand-tray-frame'],
      ['action_button_frame', '--world-ui-action-button-frame'],
      ['hand_card_frame', '--world-ui-hand-card-frame']
    ];
    const resolvedSurfaces = requiredSurfaces.map(([surfaceId, cssVariable]) => {
      const surface = material?.surfaces?.[surfaceId];
      const safe = material?.id === 'sect_field_ledger_v1'
        && material?.visualWorldId === 'cangmang_sect_pc98_v1'
        && surface?.id === surfaceId
        && surface?.visualWorldId === material.visualWorldId
        && surface?.cssVariable === cssVariable
        && typeof surface?.path === 'string'
        && /^assets\/combat\/ui\/[a-z0-9_./-]+\.png$/i.test(surface.path);
      return safe ? surface : null;
    });
    if (!sceneImage || resolvedSurfaces.some(surface => !surface)) return false;

    const reviewedRewardSurface = rewardPresentation?.visualWorldId === 'cangmang_sect_pc98_v1'
      && rewardPresentation?.uiMaterialId === 'sect_field_ledger_v1'
      && rewardPresentation?.visualSurface === 'boss_fragment_choice';
    const visualSurface = reviewedRewardSurface
      ? 'boss_fragment_choice'
      : card.visualSurface;

    this.screens.game.dataset.visualWorldId = card.visualWorldId;
    this.screens.game.dataset.uiMaterialId = card.uiMaterialId;
    this.screens.game.dataset.visualSurface = visualSurface;
    const surfaceTargets = reviewedRewardSurface && this.legacyBossRewardModal
      ? [shell, this.legacyBossRewardModal]
      : [shell];
    resolvedSurfaces.forEach(surface => {
      surfaceTargets.forEach(target => {
        target.style.setProperty(surface.cssVariable, `url("../${surface.path}")`);
      });
    });
    // The variable is consumed inside styles/style.css, so its URL must be
    // relative to that stylesheet rather than to the document root.
    shell.style.setProperty('--world-shell-scene-image', `url("../${sceneImage}")`);
    return true;
  }

  // A route changes only the reading surface around the existing button
  // intents. It deliberately derives from the already-rendered card and
  // cannot write location, card flow, or choice state.
  _setChoiceRailPresentation(card) {
    const rail = this.choiceRail;
    if (!rail) return;
    if (card?.visualSignature === 'route') {
      rail.dataset.presentation = 'route';
      rail.setAttribute('role', 'group');
      rail.setAttribute('aria-label', '山径分岔，选择下一段行程');
      return;
    }

    delete rail.dataset.presentation;
    rail.removeAttribute('role');
    rail.removeAttribute('aria-label');
  }

  /**
   * The causal spine is a player decision, not disposable flavor text.  Its
   * source echo and terminal settlement therefore live in a bounded, visible
   * card overlay instead of the line-clamped body copy.
   */
  _renderNarrativeSpineSummary(card, description) {
    const summary = this.narrativeSpineSummary;
    if (!summary || !this.cardEl) return;
    summary.hidden = true;
    summary.textContent = '';
    this.cardEl.classList.remove('has-narrative-spine-summary');
    const authoredMarkers = card?.narrativeSpine?.presentation?.summaryMarkers;
    const markers = Array.isArray(authoredMarkers) && authoredMarkers.length > 0
      ? authoredMarkers.filter(marker => typeof marker === 'string' && marker)
      : card?.narrativeSpine?.threadId === 'qi_ask_sword'
        ? ['【来历回声】', '【问剑清算】']
        : [];
    if (!markers.length) return;
    const source = typeof description === 'string' ? description : (card.description || '');
    const start = markers.reduce((earliest, marker) => {
      const index = source.indexOf(marker);
      return index >= 0 && (earliest < 0 || index < earliest) ? index : earliest;
    }, -1);
    if (start < 0) return;
    summary.textContent = source.slice(start).trim();
    summary.hidden = false;
    this.cardEl.classList.add('has-narrative-spine-summary');
  }

  /**
   * 将抽取卡牌涉及的角色、任务、物品压缩成左下角关联卡槽。
   * 主卡只保留叙事与全幅画面，完整上下文通过悬浮渐进呈现。
   */
  _renderCardAssociations(card) {
    const dock = this.cardAssociationDock;
    if (!dock) return;

    dock.innerHTML = '';
    const relations = [];
    const seen = new Set();
    const add = (kind, id) => {
      if (id === undefined || id === null || id === '' || typeof id === 'object') return;
      const normalized = String(id).trim();
      if (!normalized || /^\d+(\.\d+)?$/.test(normalized)) return;
      const key = `${kind}:${normalized}`;
      if (seen.has(key)) return;
      seen.add(key);
      relations.push({ kind, id: normalized });
    };

    [card.npcId, card.compId, ...(card.npcIds || []), ...(card.relatedNpcIds || []), ...(card.relatedCharacters || [])]
      .forEach(id => add('character', id));
    [card.questId, card.relatedQuestId, ...(card.relatedQuestIds || [])]
      .forEach(id => add('quest', id));
    this._collectCardItemRefs(card).forEach(id => add('item', id));

    if (!relations.length) {
      dock.hidden = true;
      this.cardEl.classList.remove('has-associations');
      return;
    }

    dock.hidden = false;
    this.cardEl.classList.add('has-associations');
    dock.setAttribute('aria-label', `此牌关联 ${relations.length} 项内容`);
    relations.slice(0, 4).forEach((relation, index) => {
      const meta = this._getCardAssociationMeta(relation, card);
      const item = document.createElement('article');
      item.className = `card-association association-${relation.kind}`;
      item.dataset.kind = relation.kind;
      item.dataset.refId = relation.id;
      item.tabIndex = 0;
      item.style.setProperty('--association-index', index);
      item.setAttribute('aria-label', `关联${meta.kindLabel}：${meta.name}，悬浮或聚焦查看完整卡牌`);

      const imageHtml = meta.image
        ? `<img src="${this._escapeAssociationHtml(meta.image)}" alt="" onerror="this.hidden=true">`
        : `<span class="association-glyph" aria-hidden="true">${meta.glyph}</span>`;
      const previewImage = meta.image
        ? `<div class="association-preview-art"><img src="${this._escapeAssociationHtml(meta.image)}" alt="${this._escapeAssociationHtml(meta.name)}"></div>`
        : `<div class="association-preview-art association-preview-symbol" aria-hidden="true">${meta.glyph}</div>`;

      item.innerHTML = `
        <span class="association-link-mark" aria-hidden="true">连</span>
        <span class="association-thumb">${imageHtml}</span>
        <span class="association-mini-label">${this._escapeAssociationHtml(meta.name)}</span>
        <section class="association-preview" aria-hidden="true">
          ${previewImage}
          <div class="association-preview-copy">
            <span class="association-preview-kicker">关联${meta.kindLabel} · ${this._escapeAssociationHtml(meta.status)}</span>
            <strong>${this._escapeAssociationHtml(meta.name)}</strong>
            <small>${this._escapeAssociationHtml(meta.subtitle)}</small>
            <p>${this._escapeHtml(this._normalizeNarrativeText(meta.description)).replace(/\n/g, '<br>')}</p>
            <span class="association-preview-hint">${relation.kind === 'character' ? '点击可打开人物详情' : '移开光标收起关联卡'}</span>
          </div>
        </section>`;
      item.addEventListener('click', event => {
        if (!window.matchMedia?.('(pointer: coarse)').matches) return;
        if (!item.classList.contains('is-open')) {
          event.preventDefault();
          event.stopPropagation();
          dock.querySelectorAll('.card-association.is-open').forEach(other => other.classList.remove('is-open'));
          item.classList.add('is-open');
        }
      });
      dock.appendChild(item);
    });
  }

  _presentVisualStory(card, priority = 0) {
    if (typeof visualStoryDirector === 'undefined' || !visualStoryDirector || !this.cardEl) return;
    visualStoryDirector.present(card, this.cardEl, {
      priority,
      realm: typeof gameState !== 'undefined' ? gameState.realm : 'qi'
    });
  }

  _collectCardItemRefs(card) {
    const refs = new Set();
    const explicitKeys = new Set(['itemId', 'itemIds', 'treasureId', 'treasureIds', 'artifactId', 'artifactIds', 'pillId', 'rewardItemId']);
    const namedKeys = new Set(['treasure', 'artifact', 'pill', 'item']);
    const visit = (value, depth = 0) => {
      if (!value || depth > 5 || typeof value !== 'object') return;
      Object.entries(value).forEach(([key, child]) => {
        if (explicitKeys.has(key) || namedKeys.has(key)) {
          (Array.isArray(child) ? child : [child]).forEach(candidate => {
            if ((typeof candidate === 'string' || typeof candidate === 'number') && String(candidate).trim()) refs.add(String(candidate).trim());
          });
        }
        if (typeof child === 'object') visit(child, depth + 1);
      });
    };
    visit(card);
    return [...refs];
  }

  _getCardAssociationMeta(relation, card) {
    if (relation.kind === 'character') {
      const npc = typeof npcSystem !== 'undefined' ? npcSystem.getNpc(relation.id) : null;
      const growth = typeof npcSystem !== 'undefined' ? npcSystem.getGrowthStage?.(relation.id) : null;
      const affection = typeof npcSystem !== 'undefined' ? (npcSystem.affections?.[relation.id] || 0) : 0;
      return {
        kindLabel: '角色', glyph: '人', image: this._getNpcPortrait(relation.id),
        name: npc?.name || this._humanizeAssociationId(relation.id),
        subtitle: growth?.title || npc?.title || '此段仙途中的关键人物',
        description: npc?.firstMeeting || npc?.dialogues?.[0]?.text || '此人与你眼前的因果有所牵连。',
        status: typeof npcSystem !== 'undefined' ? `${npcSystem.getEmotion?.(relation.id) || '平静'} · 好感 ${affection}` : '人物因缘'
      };
    }

    if (relation.kind === 'quest') {
      const quest = typeof questSystem !== 'undefined' ? questSystem.getQuest(relation.id) : null;
      const statusMap = { active: '进行中', completed: '已完成', available: '可触发', locked: '未触发' };
      const questStatus = typeof questSystem !== 'undefined' ? questSystem.getQuestStatus?.(relation.id) : '';
      return {
        kindLabel: '任务', glyph: '卷', image: card.sceneImage || '',
        name: quest?.name || this._humanizeAssociationId(relation.id),
        subtitle: quest?.type ? `${quest.type} · ${quest.chainLength || '?'} 段因果` : '仙途支线',
        description: quest?.description || `当前卡牌属于「${quest?.name || this._humanizeAssociationId(relation.id)}」任务链，选择会推动任务走向。`,
        status: statusMap[questStatus] || '任务关联'
      };
    }

    const shopItem = typeof shopSystem !== 'undefined' ? shopSystem.items?.find(item => item.id === relation.id || item.name === relation.id) : null;
    const treasure = typeof treasureSystem !== 'undefined' ? treasureSystem.getTreasureData?.(relation.id) : null;
    const item = shopItem || treasure;
    const iconMap = { pill: '丹', treasure: '宝', artifact: '器', material: '材' };
    return {
      kindLabel: '物品', glyph: iconMap[item?.type] || '物', image: item?.image || item?.imagePath || '',
      name: item?.name || this._humanizeAssociationId(relation.id),
      subtitle: item?.type ? `${item.type}${item.price ? ` · ${item.price} 灵石` : ''}` : '机缘物品',
      description: item?.desc || item?.description || '此物品会被当前卡牌的选择、奖励或代价所牵动。',
      status: '物品关联'
    };
  }

  _humanizeAssociationId(id) {
    return String(id || '未知').replace(/^(shop_|q_|quest_)/, '').replace(/[_-]+/g, ' ');
  }

  _escapeAssociationHtml(value) {
    return String(value ?? '').replace(/[&<>'"]/g, char => ({
      '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;'
    })[char]);
  }

  _resetChoiceButtons() {
    this.choicePreviewDetails?.querySelectorAll('details').forEach(detail => {
      detail.hidden = true;
      detail.open = false;
    });
    this.choiceButtons.forEach(btn => {
      btn.classList.remove('visible', 'has-choice-image');
      btn.style.removeProperty('--choice-image');
      btn.querySelector('.choice-text').textContent = '';
      const desc = btn.querySelector('.choice-desc');
      if (desc) desc.textContent = '';
      btn.title = '';
      btn.removeAttribute('aria-label');
      btn.dataset.mood = 'neutral';
      btn.disabled = false;
      btn.setAttribute('aria-disabled', 'false');
      delete btn.dataset.disabledReason;
      delete btn.dataset.behaviorPreview;
      delete btn.dataset.fullChoicePreview;
    });
  }

  /** Read-only card exhibition; skins keep CompanionSystem's save authority. */
  _clearKeyframeReading() {
    clearTimeout(this._keyframeReadingTimer);
    this._keyframeReadingTimer = null;
    this._keyframeReadingId = null;
    delete this.cardEl.dataset.keyframeReading;
    delete this.cardEl.dataset.keyframeScrollable;
    delete this.cardEl.dataset.keyframeFormat;
    this.cardEl.querySelector('.card-body')?.removeAttribute('tabindex');
    this.cardEl.querySelector('.card-body')?.removeAttribute('aria-label');
  }

  _syncKeyframeReading(card) {
    if (card?.artDirection?.presentation !== 'scene' || !card?.sceneImage) return;
    const readingId = `${card.id || ''}|${card.sceneImage}|${card.title || ''}|${card.description || ''}`;
    const body = this.cardEl.querySelector('.card-body');
    if (this._keyframeReadingId !== readingId) {
      clearTimeout(this._keyframeReadingTimer);
      this._keyframeReadingTimer = null;
      this._keyframeReadingId = readingId;
      this.cardEl.dataset.keyframeReading = 'pending';
      delete this.cardEl.dataset.keyframeFormat;
      delete this.cardEl.dataset.keyframeScrollable;
      body.scrollTop = 0;
      body.removeAttribute('tabindex');
      body.removeAttribute('aria-label');
    }
    const image = this.cardEl.querySelector('.narrative-keyframe-image');
    const revealAfterImage = () => {
      if (this._keyframeReadingId !== readingId || !image?.isConnected) return;
      if (!image.naturalWidth || !image.naturalHeight) {
        delete this.cardEl.dataset.keyframeReading;
        return;
      }
      const isWide = image.naturalWidth / image.naturalHeight >= 1.35;
      this.cardEl.dataset.keyframeFormat = isWide ? 'wide' : 'portrait';
      if (!isWide) {
        delete this.cardEl.dataset.keyframeReading;
        return;
      }
      body.tabIndex = 0;
      body.setAttribute('aria-label', `剧情正文：${card.title || '当前场景'}，可用滚轮或方向键阅读`);
      if (!this.cardEl.querySelector('.keyframe-reading-scrim')) {
        const scrim = document.createElement('span');
        scrim.className = 'keyframe-reading-scrim';
        scrim.setAttribute('aria-hidden', 'true');
        this.cardEl.insertBefore(scrim, this.cardEl.querySelector('.card-header'));
        const hint = document.createElement('span');
        hint.className = 'keyframe-scroll-hint';
        hint.setAttribute('aria-hidden', 'true');
        hint.textContent = '滚轮滑动';
        this.cardEl.appendChild(hint);
      }
      if (this.cardEl.dataset.keyframeReading === 'pending') {
        this.cardEl.dataset.keyframeReading = 'intro';
        this._keyframeReadingTimer = setTimeout(() => {
          this._keyframeReadingTimer = null;
          if (this._keyframeReadingId === readingId) this.cardEl.dataset.keyframeReading = 'rest';
        }, 1000);
      }
      requestAnimationFrame(() => {
        if (this._keyframeReadingId !== readingId || !image.isConnected) return;
        this.cardEl.dataset.keyframeScrollable = String(body.scrollHeight > body.clientHeight + 1);
      });
    };
    // Exhibit keeps the source visible until its display variant is decoded.
    // Begin the one-second cue only after that final image is ready.
    Promise.resolve(this._narrativeExhibit?.displayReady).then(() => {
      if (this._keyframeReadingId !== readingId || !image?.isConnected) return;
      if (image.complete) revealAfterImage();
      else {
        image.addEventListener('load', revealAfterImage, { once: true });
        image.addEventListener('error', revealAfterImage, { once: true });
      }
    });
  }

  _onKeyframeReadingWheel(event) {
    if (this.cardEl.dataset.keyframeFormat !== 'wide' || !matchMedia('(min-width: 901px)').matches) return;
    const body = this.cardEl.querySelector('.card-body');
    const remaining = body.scrollHeight - body.clientHeight - body.scrollTop;
    if ((event.deltaY > 0 && remaining > 1) || (event.deltaY < 0 && body.scrollTop > 1)) {
      event.preventDefault();
      body.scrollTop += event.deltaY;
    }
  }

  _syncNarrativeExhibit(card = this.game.getCurrentCard()) {
    if (!card || typeof window.NarrativeCardExhibit !== 'function') return;
    const isScene = card.artDirection?.presentation === 'scene' && !!card.sceneImage;
    const npcId = this._resolvePortraitCompanionId(card.npcId || card.compId || '');
    const definition = npcId ? this._loadPortraitStages()?.portraitStages?.[npcId] : null;
    if (!isScene && !definition) return;
    const stage = definition ? this._resolvePortraitStage(npcId, { card }) : null;
    const portrait = !isScene && this._resolvePortraitPresentation(npcId, stage, 'card');
    const meta = this._loadPortraitStages()?.cardAssets?.[npcId];
    this.cardEl.dataset.narrativeArt = isScene ? 'keyframe' : 'portrait';
    this.cardEl.style.setProperty('--narrative-accent', meta?.borderColor || '#c9b17e');
    if (!this._narrativeExhibit) {
      this._narrativeExhibit = new window.NarrativeCardExhibit({
        cardElement: this.cardEl, portraitElement: this.cardPortrait
      });
    }
    const unlocked = new Set((this._isHeavenlyMode() ? definition?.stages || [] : this._getUnlockedPortraitStages(npcId)).map(item => item.id));
    this._narrativeExhibit.update({
      card, title: isScene ? card.title : (definition?.name || card.title),
      subtitle: isScene ? '命途留影 · ' + (card.artDirection?.chapter || '抉择之时') : (stage?.name || meta?.theme || ''),
      asset: isScene ? card.sceneImage : portrait.asset,
      accent: meta?.borderColor, kind: isScene ? 'keyframe' : (card.compId ? 'companion' : 'character'),
      skins: isScene ? [] : definition.stages.map(skin => ({
        id: skin.id, name: skin.name,
        asset: unlocked.has(skin.id) ? this._resolvePortraitPresentation(npcId, skin, 'card').asset : '',
        unlocked: unlocked.has(skin.id), selected: skin.id === stage?.id,
        requirement: `好感 ${skin.affection} 解锁`
      })),
      onSelectSkin: isScene ? null : id => {
        if (this._isHeavenlyMode()) {
          this._narrativeExhibit.close();
          return this._heavenlyGallery.openPortrait(npcId, id);
        }
        const result = companionSystem.selectPortrait(npcId, id);
        if (!result?.selected) this.addLog(result?.reason === 'persist_failed' ? '皮肤未保存，请重试。' : '此皮肤尚未解锁。');
        return result?.selected === true;
      }
    });
  }

  _onPortraitSelected(data) {
    if (!data?.compId) return;
    const npcId = this._resolvePortraitCompanionId(data.compId);
    const card = this.game.getCurrentCard();
    const activeId = this._resolvePortraitCompanionId(card?.npcId || card?.compId);
    if (npcId === activeId && card?.artDirection?.presentation !== 'scene') {
      this._portraitGen = (this._portraitGen || 0) + 1;
      this._renderCardPortrait(npcId, this.cardPortrait).catch(error => console.warn('[UI] Skin render failed:', error));
      this._syncNarrativeExhibit(card);
    } else if (card?.type === 'NPC_CROSS') {
      // The same persisted event also serves selections made in the bestiary.
      // Each visible slot owns its image request and index independently.
      this.cardPortrait?.querySelectorAll('.npc-cross-slot').forEach(slot => {
        if (this._resolvePortraitCompanionId(slot._portraitNpcId) === npcId) {
          this._renderCardPortrait(npcId, slot).catch(error => console.warn('[UI] Skin render failed:', error));
        }
      });
    }
    if (this._resolvePortraitCompanionId(this.companionHUD?.activeCompId) === npcId) {
      this.companionHUD._loadPortrait(npcId);
    }
  }

  _presentChoiceButton(btn, choice) {
    if (!btn || !choice) return;
    // Transient cards (destiny, karma, heaven hints) may be rebuilt every time
    // GameLogic is queried.  Their choice objects therefore do not retain
    // reference identity across render and preview.  The button's authored
    // direction is stable, so use it to request the card-level projection that
    // contains the harmless capped-reward fallback.
    const preview = this._getAuthoritativeChoicePreview(choice, btn.dataset?.dir || null);
    // Preserve behavior classification independently of description layout.
    // Reset on every render because the directional buttons are reused.
    if (preview?.behaviors?.length || preview?.effectFacts?.some(fact => ['skillAcquire', 'skillOpportunity'].includes(fact.key))) {
      btn.dataset.behaviorPreview = 'true';
    }
    else delete btn.dataset.behaviorPreview;
    btn.classList.add('visible');
    const skill = preview?.skillCards?.[0] || null;
    const currentCard = this.game?.getCurrentCard?.() || this.currentCard || null;
    const playerFacingReward = ['combat_reward', 'breakthrough_reward'].includes(currentCard?.id);
    const skillSummary = skill && !playerFacingReward
      ? ` · ${skill.name}${skill.cost === null ? '' : ` ${skill.cost}费`}`
      : '';
    btn.querySelector('.choice-text').textContent = `${choice.text || '无名之择'}${skillSummary}`;
    const descEl = btn.querySelector('.choice-desc');
    if (descEl) {
      const fullText = this._formatAuthoritativeChoicePreview(preview, choice);
      descEl.textContent = this._formatChoicePreviewSummary(preview, choice);
      btn.title = fullText;
      btn.setAttribute('aria-label', `${choice.text || '无名之择'}。${descEl.textContent}`);
      this._presentChoicePreviewDetail(btn.dataset?.dir, choice, fullText);
    }
    // Every authoritative decision description matters, including ordinary
    // numeric gains and preparation costs. Do not invent a behavior to show it.
    if (preview && descEl?.textContent?.trim()) btn.dataset.fullChoicePreview = 'true';
    else delete btn.dataset.fullChoicePreview;
    const disabled = preview ? !preview.executable : false;
    btn.disabled = disabled;
    btn.setAttribute('aria-disabled', String(disabled));
    if (disabled) btn.dataset.disabledReason = preview.reason || 'unavailable';
    else delete btn.dataset.disabledReason;
    btn.dataset.mood = this._choiceMood(choice.effects);
    if (choice.image) {
      const choiceImage = /^(?:[a-z]+:|\/)/i.test(choice.image)
        ? choice.image
        : `/${String(choice.image).replace(/^\.?\//, '')}`;
      btn.classList.add('has-choice-image');
      btn.style.setProperty('--choice-image', `url("${choiceImage}")`);
    } else {
      btn.classList.remove('has-choice-image');
      btn.style.removeProperty('--choice-image');
    }
  }

  _presentChoicePreviewDetail(direction, choice, fullText) {
    if (!direction || !fullText?.trim() || !this.choiceRail || typeof document === 'undefined') return;
    if (!this.choicePreviewDetails) {
      const group = document.createElement('div');
      group.className = 'choice-preview-details';
      group.setAttribute('role', 'group');
      group.setAttribute('aria-label', '选项完整预览');
      this.choiceRail.after(group);
      this.choicePreviewDetails = group;
    }
    let detail = this.choicePreviewDetails.querySelector(`details[data-dir="${direction}"]`);
    if (!detail) {
      detail = document.createElement('details');
      detail.className = 'choice-preview-detail';
      detail.dataset.dir = direction;
      const summary = document.createElement('summary');
      const body = document.createElement('div');
      body.className = 'choice-preview-detail-body';
      detail.append(summary, body);
      this.choicePreviewDetails.appendChild(detail);
    }
    const directionLabels = { left: '←', right: '→', up: '↑', down: '↓' };
    detail.querySelector('summary').textContent = `${directionLabels[direction] || ''} 查看「${choice.text || '无名之择'}」完整预览`;
    detail.querySelector('.choice-preview-detail-body').textContent = fullText;
    detail.hidden = false;
  }

  _formatChoicePreviewSummary(preview, choice) {
    if (!preview) return this._formatAuthoritativeChoicePreview(null, choice);
    const delta = change => {
      const actual = Number(change.actualDelta);
      if (!Number.isFinite(actual)) return null;
      if (actual === 0 && Number(change.requestedDelta) > 0) return `${change.label}已达上限`;
      if (actual === 0) return null;
      return `${change.label}${actual > 0 ? '+' : ''}${actual}${change.unit || ''}`;
    };
    const projected = (outcome, injury = null) => {
      const changes = (outcome?.changes || []).map(delta).filter(Boolean);
      const negatives = changes.filter(item => /-\d/.test(item));
      const positives = changes.filter(item => !/-\d/.test(item));
      const result = [];
      if (Number(injury?.applied) > 0) result.push(`气血-${Number(injury.applied)}`);
      result.push(...negatives, ...positives.slice(0, 2));
      if (positives.length > 2 || outcome?.skillCards?.length || outcome?.effectFacts?.length) result.push('其余见详情');
      return result.join('、') || '结果见详情';
    };
    const branchSummary = behavior => {
      if (behavior?.contractValid === false) return '遭遇不可用';
      const branches = behavior?.branches || [];
      const riskFirst = [...branches].sort((left, right) => {
        const risk = branch => branch.id === 'defeat' ? 0 : branch.id === 'flee' ? 1 : 2;
        return risk(left) - risk(right);
      });
      return riskFirst.map(branch => `${branch.label} ${projected(branch.preview, branch.injury)}`).join('；');
    };
    const parts = [];
    for (const cost of preview.costs || []) {
      parts.push(cost.affordable === false
        ? `${cost.label}需 ${cost.required}${cost.unit || ''}，现有 ${cost.current}，缺 ${cost.shortfall}`
        : `${cost.label}-${cost.required}${cost.unit || ''}`);
    }
    for (const change of preview.changes || []) {
      const label = delta(change);
      if (label) parts.push(label);
    }
    for (const card of preview.skillCards || []) parts.push(`功法【${card.name}】`);
    for (const fact of preview.effectFacts || []) {
      if (['skillAcquire', 'skillOpportunity'].includes(fact.key)) parts.push(fact.text || fact.label);
    }
    for (const behavior of preview.behaviors || []) {
      if (behavior.type === 'combat_chance') {
        const chance = Math.round((Number(behavior.chance) || 0) * 100);
        parts.push(`斗法概率 ${chance}%`);
        if (chance > 0 && behavior.combatPreview) parts.push(branchSummary(behavior.combatPreview));
        if (chance < 100 && behavior.ordinaryPreview) parts.push(`未遇战 ${100 - chance}%：${behavior.ordinaryPreview.executable === false ? '不可结算' : projected(behavior.ordinaryPreview)}`);
      } else if (behavior.type === 'combat_outcomes') {
        parts.push(branchSummary(behavior));
      } else if (behavior.type === 'breakthrough') {
        parts.push(`突破成功率 ${Math.round((Number(behavior.finalRate) || 0) * 100)}%`);
        parts.push(`失败 ${projected(behavior.failurePreview)}`);
      } else if (behavior.type === 'dungeon') {
        parts.push(behavior.valid ? `秘境入口 · ${behavior.nodeCount}关` : '秘境入口不可用');
      } else {
        const detail = this._formatBehaviorProjection(behavior);
        parts.push(detail.length > 72 ? `${detail.slice(0, 70)}…` : detail);
      }
    }
    const reasons = {
      all_positive_rewards_capped: '收益已封顶，当前不可用',
      capped_fallback: '收益已封顶，仍可继续',
      missing_required_resource: '缺少物品，当前不可用',
      insufficient_resource: '资源不足，当前不可用'
    };
    if (reasons[preview.reason]) parts.push(reasons[preview.reason]);
    return parts.length ? parts.join(' · ') : this._formatAuthoritativeChoicePreview(preview, choice);
  }

  /**
   * COMBAT_UI 卡牌渲染 —— 新版 DeckCombatUI 已接管实际战斗界面
   * 主卡牌区仅作为占位提示，避免依赖旧 combatSystem
   */
  _renderCombatCard(card) {
    const st = card.combatState;
    if (!st) {
      this.cardTitle.textContent = '战斗';
      this.cardDesc.textContent = '战斗状态异常...';
      this.cardType.textContent = 'COMBAT_UI';
      return;
    }

    this.cardTitle.textContent = '⚔ 战斗中';
    this.cardDesc.innerHTML = `
      <div class="combat-hud">
        <p>已进入打牌战斗界面，请使用战斗界面进行操作。</p>
      </div>
    `;
    this.cardType.textContent = '战斗';

    this.cardEl.style.transform = 'translate(0, 0) rotate(0)';
    this.cardEl.className = 'card card-combat_ui';
    this.cardEl.style.backgroundImage = '';

    // 隐藏四向选择按钮，避免误触旧 combatSystem 动作
    this.choiceButtons.forEach(btn => btn.classList.remove('visible'));
    this._currentCardIsCombat = null;
  }

  /* ==========================================================
     因果成熟回执（EPIC-1.4）
     背景：karma:seedRipening 此前全项目 0 个订阅者。游戏承诺
     「你的选择会种下因果，约 N 轮后显现」，但玩家种下、等到 N 轮，
     兑现那一刻屏幕上什么都不会发生 —— 于是玩家正确地推断出
     「这个游戏的选择没有意义」。
     本方法只做 UI 消费：订阅已有事件，从 getPlantedSeeds() 取回文案，
     不新增后端方法、不改因果计时与数值、不维护第二份因果状态。
     ========================================================== */
  _bindKarmaRipenReceipt() {
    if (this._karmaRipenBound || typeof eventBus === 'undefined' || !eventBus) return;
    this._karmaRipenBound = true;
    eventBus.on('karma:seedRipening', (payload) => this._onKarmaSeedRipening(payload));
  }

  _onKarmaSeedRipening(payload) {
    const seedId = payload?.seedId;
    if (!seedId) return;
    const karma = this.game?.karmaSystem
      || (typeof window !== 'undefined' ? window.karmaSystem : null);
    // 从权威只读快照取文案，不在 UI 维护另一份因果时钟。
    let seed = null;
    if (karma && typeof karma.getPlantedSeeds === 'function') {
      try { seed = karma.getPlantedSeeds().find((s) => s.id === seedId) || null; } catch (e) { seed = null; }
    }
    const typeName = seed?.seedTypeName || '因果';
    const desc = seed?.description || (seed?.originTurn > 0
      ? `你在第 ${seed.originTurn} 次决断的选择，如今应验`
      : '你早先的选择，如今应验');
    const originTurn = Number(seed?.originTurn || 0);

    const floater = document.createElement('div');
    floater.className = 'karma-ripen-floater ' + (seed?.seedType || 'karma');
    const head = document.createElement('span');
    head.className = 'karma-ripen-head';
    head.textContent = typeName + '成熟';
    const body = document.createElement('span');
    body.className = 'karma-ripen-desc';
    body.textContent = desc;
    const from = document.createElement('span');
    from.className = 'karma-ripen-from';
    from.textContent = originTurn > 0 ? `—— 你在第 ${originTurn} 次决断埋下的因` : '—— 你早先埋下的因';
    floater.append(head, body, from);
    floater.setAttribute('aria-live', 'polite');
    document.body.appendChild(floater);
    window.setTimeout(() => floater.remove(), 3100);

    // 面板开着时同步刷新，保证因果簿与刚兑现的内容一致
    const modal = document.getElementById('karma-log-modal');
    if (modal && modal.style.display === 'flex') this._renderKarmaLog();
  }

  _bindKarmaLogPanel() {
    const btn = document.getElementById('karma-log-btn');
    const modal = document.getElementById('karma-log-modal');
    const closeBtn = document.getElementById('karma-log-close');
    if (!btn || !modal) return;

    btn.addEventListener('click', () => {
      this._renderKarmaLog();
      modal.style.display = 'flex';
      this._enterTopbarPanel('karma-log-modal', 'karma-log-close', 'karma-log-btn');
    });

    if (closeBtn) {
      closeBtn.addEventListener('click', () => {
        modal.style.display = 'none';
      });
    }

    modal.addEventListener('click', (e) => {
      if (e.target === modal) {
        modal.style.display = 'none';
      }
    });
  }

  _renderKarmaLog() {
    const container = document.getElementById('karma-log-content');
    if (!container) return;
    container.innerHTML = '';

    const karmaSystem = this.game?.karmaSystem
      || (typeof window !== 'undefined' ? window.karmaSystem : null);

    const seeds = karmaSystem && typeof karmaSystem.getPlantedSeeds === 'function'
      ? karmaSystem.getPlantedSeeds()
      : [];

    if (!seeds || seeds.length === 0) {
      container.innerHTML = `
        <div style="text-align: center; color: #8e9eab; padding: 30px 10px;">
          <div style="font-size: 32px; margin-bottom: 10px;">☯</div>
          <div>天道清明，暂无发芽中的因果种子。</div>
          <small style="color: #5c6b73; display: block; margin-top: 5px;">你在世间的抉择（善行/恶举/羁绊）将种下因果，于若干次决断后显现。</small>
        </div>
      `;
      return;
    }

    const typeBadges = {
      karma: '<span style="color: #2ecc71; border: 1px solid #2ecc71; padding: 2px 6px; border-radius: 4px; font-size: 12px;">善因</span>',
      grudge: '<span style="color: #e74c3c; border: 1px solid #e74c3c; padding: 2px 6px; border-radius: 4px; font-size: 12px;">恶因</span>',
      bloodline: '<span style="color: #9b59b6; border: 1px solid #9b59b6; padding: 2px 6px; border-radius: 4px; font-size: 12px;">血脉</span>',
      fate: '<span style="color: #f1c40f; border: 1px solid #f1c40f; padding: 2px 6px; border-radius: 4px; font-size: 12px;">宿命</span>'
    };

    let html = '<div style="display: flex; flex-direction: column; gap: 12px;">';
    seeds.forEach(seed => {
      const badge = typeBadges[seed.seedType] || typeBadges.karma;
      html += `
        <div style="background: rgba(255,255,255,0.05); border-left: 3px solid #f39c12; padding: 12px; border-radius: 4px;">
          <div class="karma-seed-heading">
            <strong class="karma-seed-name">${seed.id} <span class="karma-seed-type">${badge}</span></strong>
            <span class="karma-seed-delay">🌱 ${seed.delay} 次决断后发芽</span>
          </div>
          <div style="color: #bdc3c7; font-size: 13px; margin-bottom: 4px;">${this._narrativeHtml(seed.description)}</div>
          <div style="display: flex; gap: 15px; font-size: 12px; color: #7f8c8d;">
            <span>境界限制: ${seed.realm}</span>
            <span>${seed.originTurn > 0 ? `播种决断: 第 ${seed.originTurn} 次` : '播种时机: 入世之初'}</span>
            <span>优先级: ${seed.priority}</span>
          </div>
        </div>
      `;
    });
    html += '</div>';
    container.innerHTML = html;
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

    this._startBlockCursorLoop();

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

  _startBlockCursorLoop() {
    if (!this.renderLoop) {
      console.warn('[GameUI] RenderLoopCoordinator unavailable; block cursor animation skipped');
      return;
    }
    this._blockRenderLoopUnsubscribe?.();
    this._blockRenderLoopUnsubscribe = this.renderLoop.register('ui-block-cursor', () => this._animateBlockCursorFrame(), {
      fps: 60,
      isActive: () => this._blockActive === true
    });
  }

  _animateBlockCursorFrame() {
    if (!this._blockActive) return;
    const cursor = document.getElementById('block-cursor');
    if (!cursor) return;

    this._blockCursorPos += this._blockSpeed * this._blockDirection;
    if (this._blockCursorPos >= 100) { this._blockCursorPos = 100; this._blockDirection = -1; }
    else if (this._blockCursorPos <= 0) { this._blockCursorPos = 0; this._blockDirection = 1; }

    cursor.style.left = this._blockCursorPos + '%';
  }

  _resolveBlock() {
    if (!this._blockActive) return;
    this._blockRenderLoopUnsubscribe?.();
    this._blockRenderLoopUnsubscribe = null;
    this._blockAnimFrame = null;
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
    this.cardDesc.textContent = this._normalizeNarrativeText(card.description);
    this.cardType.textContent = '心魔';
    this.cardEl.style.transform = 'translate(0, 0) rotate(0)';
    this.cardEl.className = 'card card-inner-demon';
    this.cardEl.style.backgroundImage = '';
    this.cardPortrait.style.display = 'none';

    const choiceKeys = Object.keys(card.choices);
    const dirs = ['left', 'right', 'up', 'down'];
    this.choiceButtons.forEach(btn => btn.classList.remove('visible'));
    choiceKeys.forEach((key, i) => {
      const btn = this.choiceButtons[i];
      const choice = card.choices[key];
      if (btn && choice && i < dirs.length) {
        this._presentChoiceButton(btn, choice);
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
    // The wheel has its own input contract (no card.choices); it must not
    // inherit a previous card's costs, disabled state, or accessible labels.
    this._resetChoiceButtons();
    for (let i = 0; i < 4; i++) {
      const btn = this.choiceButtons[i];
      if (btn) {
        btn.classList.add('visible');
        const label = `翻看第${i+1}张`;
        btn.querySelector('.choice-text').textContent = label;
        btn.title = label;
        btn.setAttribute('aria-label', label);
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
    this.cardDesc.textContent = this._normalizeNarrativeText(card.description);
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
    const choiceKeys = Object.keys(card.choices);
    for (let i = 0; i < Math.min(2, choiceKeys.length); i++) {
      const btn = this.choiceButtons[i];
      const key = choiceKeys[i];
      if (btn && card.choices[key]) {
        this._presentChoiceButton(btn, card.choices[key]);
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
    this.cardDesc.textContent = this._normalizeNarrativeText(card.description);
    this.cardType.textContent = `天机 · ${card.hintCategory || '预言'}`;
    this.cardEl.style.transform = 'translate(0, 0) rotate(0)';
    this.cardEl.className = 'card card-heavens-hint';
    this.cardEl.style.backgroundImage = '';
    this.cardPortrait.style.display = 'none';

    this.choiceButtons.forEach(btn => btn.classList.remove('visible'));
    const dirs = ['left', 'right'];
    const choiceKeys = Object.keys(card.choices);
    for (let i = 0; i < Math.min(2, choiceKeys.length); i++) {
      const btn = this.choiceButtons[i];
      const key = choiceKeys[i];
      if (btn && card.choices[key]) {
        this._presentChoiceButton(btn, card.choices[key]);
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
    this.cardDesc.innerHTML = this._escapeHtml(this._normalizeNarrativeText(card.description)).replace(/\n/g, '<br>');
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
      for (const dir of ['left', 'right']) {
        if (choiceMap[dir]) {
          const btn = this.getChoiceButton(dir);
          if (btn) {
            this._presentChoiceButton(btn, choiceMap[dir]);
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
    this.cardDesc.innerHTML = this._escapeHtml(this._normalizeNarrativeText(card.description)).replace(/\n/g, '<br>');
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
      for (const dir of ['left', 'right']) {
        if (choiceMap[dir]) {
          const btn = this.getChoiceButton(dir);
          if (btn) {
            this._presentChoiceButton(btn, choiceMap[dir]);
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
    this.cardDesc.textContent = this._normalizeNarrativeText(card.description);
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
    const dirs = this.game.getAvailableDirections(card);
    dirs.forEach(dir => {
      const btn = this.getChoiceButton(dir);
      const choice = card.choices ? card.choices[dir] : null;
      if (btn && choice) {
        this._presentChoiceButton(btn, choice);
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

  /**
   * Returns a non-combat protagonist identity only for cards that explicitly
   * declare one. The UI never maps a made-up realm to an art stage itself.
   */
  _resolveNarrativeProtagonistIdentity(card) {
    const declared = card?.protagonistIdentity;
    if (!declared) return null;
    const deck = this.game?.combatCoordinator?.deckCombatSystem || null;
    if (!deck || typeof deck.getProtagonistIdentityContract !== 'function') return null;
    const state = this._getGameState?.() || null;
    let resolved = null;
    if (declared.consumer === 'reincarnation_memory' && typeof declared.visualStageId === 'string') {
      resolved = deck.getProtagonistIdentityContract({
        visualStageId: declared.visualStageId,
        pathId: declared.pathSource === 'current_life_path' ? state?.path : null
      });
      if (resolved?.displayedVisualStageId !== declared.visualStageId) return null;
    } else if (declared.consumer === 'realm_arrival'
      && declared.stageSource === 'current_realm'
      && declared.pathSource === 'current_life_path'
      && typeof state?.realm === 'string'
      && typeof state?.path === 'string') {
      resolved = deck.getProtagonistIdentityContract({ pathId: state.path });
      if (resolved?.requestedVisualStageId !== resolved?.displayedVisualStageId) return null;
    } else {
      return null;
    }
    if (!resolved?.actorCard?.image) return null;
    return resolved;
  }

  /**
   * Composes a transparent identity carrier over its separately-authored
   * narrative scene. It deliberately does not recycle battle keyframes or
   * animation sprites as a character-card portrait.
   */
  _renderNarrativeProtagonistIdentity(card, identity, portraitDiv) {
    const actor = identity.actorCard;
    portraitDiv.style.display = 'flex';
    portraitDiv.style.position = 'relative';
    portraitDiv.style.overflow = 'hidden';
    portraitDiv.style.backgroundImage = '';
    portraitDiv.innerHTML = '';
    if (card.sceneImage) {
      const sceneBackdrop = document.createElement('div');
      sceneBackdrop.className = 'card-scene-backdrop';
      sceneBackdrop.style.cssText =
        'position:absolute;inset:0;z-index:0;pointer-events:none;background-image:url(\'' + card.sceneImage + '\');' +
        'background-size:cover;background-position:center;';
      portraitDiv.appendChild(sceneBackdrop);
      this.cardEl.style.backgroundImage = `url('${card.sceneImage}')`;
      this.cardEl.style.backgroundSize = 'cover';
      this.cardEl.style.backgroundPosition = 'center';
    }
    const image = document.createElement('img');
    image.id = 'card-protagonist-identity';
    image.className = 'card-protagonist-identity';
    image.src = actor.image;
    image.alt = `${actor.name || '叶凌云'} · ${actor.kicker || ''}`;
    image.dataset.assetId = actor.id || '';
    image.dataset.identityAnchorId = identity.identityAnchorId || '';
    image.dataset.stageId = identity.displayedVisualStageId || '';
    image.dataset.pathVariantId = actor.pathVariantId || '';
    image.dataset.assetStatus = identity.visualStageAssetStatus || '';
    image.style.cssText =
      'position:absolute;z-index:1;inset:2% 10% 0;max-width:80%;width:80%;height:98%;object-fit:contain;' +
      'object-position:center bottom;filter:drop-shadow(0 8px 10px rgba(3,8,18,.56));pointer-events:none;';
    portraitDiv.appendChild(image);
    const label = document.createElement('div');
    label.className = 'card-protagonist-identity-label';
    label.textContent = actor.kicker || '凡尘旧忆';
    label.style.cssText =
      'position:absolute;z-index:2;left:10px;right:10px;bottom:8px;text-align:center;color:#d7e5ee;' +
      'font-size:10px;letter-spacing:1.5px;text-shadow:0 1px 5px #070b14;pointer-events:none;';
    portraitDiv.appendChild(label);
  }

  getCardTypeName(type) {
    const names = {
      NORMAL: '事件', BOTTLENECK: '瓶颈', KARMA: '因果',
      DUNGEON: '秘境', DUNGEON_FORK: '岔路', DESTINY: '宿命', QUEST: '支线',
      SHOP: '坊市', MARKET: '鬼市', COMBAT: '战斗', COMBAT_WARNING: '预警', COMBAT_UI: '战斗',
      INNER_DEMON: '心魔', DESTINY_WHEEL: '命盘',
      KARMA_RIPPLE: '涟漪', HEAVENS_HINT: '天机', NPC_CROSS: '交叉事件',
      SPECIAL: '天道', LOCATION: '位置', STORY: '故事', COMPANION_EVENT: '道侣', REALM_UPGRADE: '破境回执'
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
    if (this.choicePending) return;
    const card = this.game.getCurrentCard();
    if (gameState.dead && card && !card.id.startsWith('death_') && !card.id.startsWith('ending_')) { return; }

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
      this.choicePending = true;

      setTimeout(() => {
        try {
          this.game.combatAction(actionId);
          this.cardEl.style.transition = 'none';
          this.cardEl.style.opacity = '1';
          this.cardEl.style.transform = 'translate(0, 0) rotate(0)';
          setTimeout(() => {
            this.cardEl.style.transition = 'transform 0.1s ease';
          }, 50);
        } finally {
          this.choicePending = false;
        }
      }, 300);
      return;
    }

    // ======== v2.0 心魔反噬/命盘轮转/因果涟漪/天机一闪/集市偶遇 拦截 ========
    if (card.type === 'INNER_DEMON' || card.type === 'DESTINY_WHEEL' ||
        card.type === 'KARMA_RIPPLE' || card.type === 'HEAVENS_HINT' ||
        card.type === 'MARKET') {
      const specialChoice = card.choices?.[dir];
      if (typeof visualStoryDirector !== 'undefined') visualStoryDirector.recordChoice?.(card, specialChoice, dir);
      const choiceToken = this.game.issueChoiceToken();
      this.choicePending = true;
      this._animateCardAway(dir, () => {
        try {
          const result = this.game.makeChoice(dir, choiceToken);
          if (result === false) {
            this._handleChoiceRejection(card);
          } else {
            this._presentChoiceSettlement(choiceToken);
            this._queueChoiceRefocus();
          }
        } catch (e) {
          this.game.discardChoiceSettlement?.();
          console.error('[UI] special makeChoice failed:', e);
        }
        finally { this.choicePending = false; }
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
    if (typeof visualStoryDirector !== 'undefined') visualStoryDirector.recordChoice?.(card, choiceForEcho, dir);

    // Animate card away
    const choiceToken = this.game.issueChoiceToken();
    this.choicePending = true;
    this._animateCardAway(dir, () => {
      try {
        // 【P0 修复 #4】捕获 makeChoice 返回值，资源不足时抖动提示
        const result = this.game.makeChoice(dir, choiceToken);
        if (result === false) {
          this._handleChoiceRejection(card);
          return;
        }

        this._presentChoiceSettlement(choiceToken);
        this._queueChoiceRefocus();
      } catch (e) {
        this.game.discardChoiceSettlement?.();
        console.error('[UI] makeChoice failed:', e);
      }
      finally {
        this.choicePending = false;
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

  _presentChoiceSettlement(choiceToken = null) {
    const settlement = this.game.consumeLastChoiceSettlement?.(choiceToken);
    if (!settlement) return false;
    // A zero-value reward declination can immediately hand the player to an
    // authored scene. Keep its receipt in the durable narrative log without
    // overlaying boilerplate on the scene the player is meant to read next.
    if (settlement.feedbackMode === 'log_only') return true;
    this.showNearfieldFeedback(
      settlement.sourceName,
      settlement.costText,
      settlement.changes,
      settlement.outcomeText,
      {
        visualWorldId: settlement.visualWorldId || null,
        uiMaterialId: settlement.uiMaterialId || null,
        visualSurface: settlement.visualSurface || null,
        feedbackDisplay: settlement.feedbackCue?.display
          || (['promise_resolved', 'promise_closed'].includes(settlement.feedbackCue?.kind) ? 'narrative' : 'brief')
      }
    );
    return true;
  }

  _queueChoiceRefocus() {
    const refocus = () => {
      const shopPanel = typeof document !== 'undefined'
        ? document.getElementById('shop-panel')
        : null;
      if (shopPanel?.style?.display && shopPanel.style.display !== 'none') return;
      this._focusScreenTarget(this.screens.game);
    };
    if (typeof queueMicrotask === 'function') queueMicrotask(refocus);
    else Promise.resolve().then(refocus);
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
    this.cardEl.style.transition = 'transform 0.16s ease, opacity 0.16s ease';
    this.cardEl.style.transform = transformMap[dir] || 'scale(0.8)';
    this.cardEl.style.opacity = '0';

    setTimeout(() => {
      if (callback) callback();
    }, 160);
  }

  /**
   * Translate the authoritative settlement rejection into player-facing
   * feedback. A failed choice is not necessarily a resource failure: schema,
   * encounter resolution and changed-cost failures must remain distinguishable
   * so the UI does not teach the player a false cause.
   */
  _getChoiceRejectionMessage(reason) {
    const messages = {
      missing_required_resource: '缺少所需物品',
      insufficient_resource: '资源不足',
      all_positive_rewards_capped: '当前收益已达上限',
      choice_cost_changed: '消耗已变化，请重新确认',
      unknown_choice_field: '选择合同异常，本次未结算',
      invalid_combat_chance: '遭遇规则异常，本次未结算',
      unresolved_combat_encounter: '遭遇内容缺失，本次未结算'
    };
    return messages[reason] || '当前选择未能结算';
  }

  _handleChoiceRejection(card, directorOverride = null) {
    this.game.discardChoiceSettlement?.();
    const director = directorOverride
      || (typeof visualStoryDirector !== 'undefined' ? visualStoryDirector : null);
    director?.forgetChoice?.(card?.id);
    if (this.game._lastChoiceRejection === 'stale_card') return false;
    this._shakeCard();
    this._showToast(this._getChoiceRejectionMessage(this.game._lastChoiceRejection));
    return true;
  }

  /**
   * 【P0 修复 #4】卡牌抖动反馈（资源不足时触发）
   */
  _shakeCard() {
    if (!this.cardEl) return;
    this.cardEl.style.transition = 'transform 0.05s ease';
    let shakes = 0;
    const maxShakes = 4;
    const doShake = () => {
      if (shakes >= maxShakes) {
        this.cardEl.style.transform = 'translate(0, 0) rotate(0)';
        this.cardEl.style.transition = 'transform 0.1s ease';
        return;
      }
      this.cardEl.style.transform = `translate(${shakes % 2 === 0 ? 8 : -8}px, 0) rotate(${shakes % 2 === 0 ? 2 : -2}deg)`;
      shakes++;
      setTimeout(doShake, 60);
    };
    doShake();
  }

  /**
   * 【P0 修复 #4】Toast 提示（资源不足等场景）
   * @param {string} msg - 提示消息
   */
  _showToast(msg) {
    // 复用已有 toast 元素，避免重复创建
    let toast = document.getElementById('ui-toast');
    if (!toast) {
      toast = document.createElement('div');
      toast.id = 'ui-toast';
      toast.style.cssText = 'position:fixed;top:60%;left:50%;transform:translate(-50%,-50%);background:rgba(0,0,0,0.8);color:#ff6b6b;padding:8px 20px;border-radius:6px;font-size:14px;z-index:9999;pointer-events:none;transition:opacity 0.3s ease;';
      document.body.appendChild(toast);
    }
    toast.textContent = msg;
    toast.style.opacity = '1';
    clearTimeout(this._toastTimer);
    this._toastTimer = setTimeout(() => {
      toast.style.opacity = '0';
    }, 1500);
  }

  /**
   * EX-04: 300ms 近场回执 Toast (展现来源、代价和属性前后变化)
   */
  showNearfieldFeedback(sourceName, costText, deltas, outcomeText = null, presentation = null) {
    if (typeof document === 'undefined' || !document.body) return;
    if (presentation?.feedbackDisplay) {
      document.getElementById('choice-outcome-receipts')?.replaceChildren();
    }
    if (presentation?.feedbackDisplay !== 'brief' && typeof outcomeText === 'string' && outcomeText.trim()) {
      this._showChoiceOutcomeReceipt(sourceName, costText, outcomeText.trim());
    }
    let toast = document.getElementById('nearfield-feedback-toast');
    if (!toast) {
      toast = document.createElement('div');
      toast.id = 'nearfield-feedback-toast';
      toast.setAttribute('role', 'status');
      toast.setAttribute('aria-live', 'polite');
      toast.setAttribute('aria-atomic', 'true');
      const rail = this.choiceRail || document.querySelector('#game-screen .choice-buttons');
      if (rail) rail.before(toast);
      else document.body.appendChild(toast);
    }

    delete toast.dataset.visualWorldId;
    delete toast.dataset.uiMaterialId;
    delete toast.dataset.visualSurface;
    if (presentation?.visualWorldId === 'cangmang_sect_pc98_v1'
      && presentation?.uiMaterialId === 'sect_field_ledger_v1'
      && presentation?.visualSurface === 'combat_settlement_ledger') {
      toast.dataset.visualWorldId = presentation.visualWorldId;
      toast.dataset.uiMaterialId = presentation.uiMaterialId;
      toast.dataset.visualSurface = 'combat_reward_receipt';
    }

    toast.replaceChildren();
    const header = document.createElement('div');
    header.className = 'nearfield-header';
    header.textContent = `【${sourceName || '选择回执'}】${costText ? `（${costText}）` : ''}`;
    toast.appendChild(header);
    const list = document.createElement('div');
    list.className = 'nearfield-deltas';
    if (Array.isArray(deltas) && deltas.length > 0) {
      for (const change of deltas) {
        const delta = Number(change.delta) || 0;
        const item = document.createElement('span');
        item.className = `nearfield-delta-item ${delta >= 0 ? 'pos' : 'neg'}`;
        item.textContent = `${change.label} ${change.oldValue} → ${change.newValue}（${delta > 0 ? '+' : ''}${delta}）`;
        list.appendChild(item);
      }
    } else {
      const item = document.createElement('span');
      item.className = 'nearfield-delta-item neutral';
      item.textContent = '状态已结算，无数值变化';
      list.appendChild(item);
    }
    toast.appendChild(list);

    toast.classList.add('show');
    if (this._nearfieldTimer) clearTimeout(this._nearfieldTimer);
    this._nearfieldTimer = setTimeout(() => {
      toast.classList.remove('show');
    }, 1500);
  }

  _showChoiceOutcomeReceipt(sourceName, costText, outcomeText) {
    const rail = this.choiceRail || document.querySelector('#game-screen .choice-buttons');
    if (!rail) return;
    let group = document.getElementById('choice-outcome-receipts');
    if (!group) {
      group = document.createElement('section');
      group.id = 'choice-outcome-receipts';
      group.setAttribute('aria-label', '已结算的剧情回执');
      rail.before(group);
    }
    const receipt = document.createElement('article');
    receipt.className = 'choice-outcome-receipt';
    receipt.setAttribute('role', 'status');
    const heading = document.createElement('strong');
    heading.className = 'choice-outcome-heading';
    heading.textContent = `【${sourceName || '选择回执'}】${costText ? ` · ${costText}` : ''}`;
    const body = document.createElement('p');
    body.className = 'choice-outcome-body';
    body.textContent = this._normalizeNarrativeText(outcomeText);
    const close = document.createElement('button');
    close.type = 'button';
    close.className = 'choice-outcome-close';
    close.textContent = '收起回执';
    close.setAttribute('aria-label', `收起「${sourceName || '选择'}」回执`);
    close.addEventListener('click', () => {
      const hadFocus = receipt.contains(document.activeElement);
      receipt.remove();
      if (hadFocus) this._focusScreenTarget?.(this.screens?.game);
    });
    receipt.append(heading, body, close);
    group.appendChild(receipt);
  }

  // ============ 沉浸 v2.0：卡面涟漪反馈 ============

  /** 选择生效后，以“命数回响”展示语义影响，不暴露后台数值。 */
  _showChoiceEcho(effects) {
    if (!effects || !this.cardEl) return;
    const seal = document.createElement('div');
    seal.className = `choice-consequence-seal is-${this._choiceMood(effects)}`;
    seal.innerHTML = '<span>定</span><small>一念落印</small>';
    this.cardEl.appendChild(seal);
    setTimeout(() => seal.remove(), 1350);
    this._effectSemantics(effects).slice(0, 3).forEach((effect, index) => {
      const el = document.createElement('div');
      el.className = `choice-echo is-${effect.tone}`;
      el.textContent = `${effect.icon} ${effect.text}`;
      el.style.cssText = `
        left: ${50 + (index - 1) * 7}%;
        top: ${38 + index * 8}%;
        animation-delay: ${index * 90}ms;
        animation-name: echo-${effect.tone === 'negative' ? 'down' : 'up'};
      `;
      this.cardEl.appendChild(el);
      setTimeout(() => el.remove(), 1500);
    });
  }

  _showOpportunityResolution(data) {
    if (!data?.rewardId) return;
    const previous = document.querySelector('.opportunity-resolution-toast');
    if (previous) previous.remove();

    let artImage = null;
    if (data.rewardType === 'card') {
      const battleData = dataLoader?.loadSync?.('cards:battle_cards');
      const cardDef = battleData?.battle_cards?.find(card => card.id === data.rewardId);
      artImage = cardDef?.cardArt?.image || null;
    } else if (data.rewardType === 'treasure') {
      const treasure = typeof treasureSystem !== 'undefined'
        ? treasureSystem?.getTreasureData?.(data.rewardId)
        : null;
      artImage = treasure?.combatPresentation?.objectArt?.image
        || treasure?.combatPresentation?.cardArt?.image
        || null;
    }

    const toast = document.createElement('aside');
    toast.className = `opportunity-resolution-toast is-${data.rewardType}`;
    toast.setAttribute('role', 'status');
    toast.innerHTML = `
      ${artImage ? `<img src="${artImage}" alt="${data.rewardName}">` : '<div class="opportunity-resolution-glyph">缘</div>'}
      <div class="opportunity-resolution-copy">
        <small>${data.mode === 'special' ? '特殊传承' : '机缘落定'} · ${data.locationName || '未知地点'}</small>
        <strong>${data.rewardType === 'treasure' ? '法宝入库' : '技能入组'} · ${data.rewardName}</strong>
        <span>${data.rewardType === 'treasure' ? '已收入右下角法宝册，可查看并装备' : '已收入卡组，可在战斗中抽取并触发'}</span>
      </div>
    `;
    document.body.appendChild(toast);
    requestAnimationFrame(() => toast.classList.add('is-visible'));
    setTimeout(() => {
      toast.classList.remove('is-visible');
      setTimeout(() => toast.remove(), 260);
    }, 5200);
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

  _effectSemantics(effects) {
    if (!effects || typeof effects !== 'object') return [];
    const phrases = {
      cultivation: { positive: ['修行有所精进', 'positive', '剑'], negative: ['修为可能折损', 'negative', '剑'] },
      daoHeart: { positive: ['道心趋于澄明', 'positive', '心'], negative: ['道心可能动摇', 'negative', '心'] },
      karmaGood: { positive: ['将结下一段善缘', 'positive', '缘'], negative: ['旧日善缘渐薄', 'negative', '缘'] },
      karmaBad: { positive: ['可能沾染新的业障', 'negative', '业'], negative: ['一缕恶业得以消解', 'positive', '业'] },
      fortune: { positive: ['气运将有所转盛', 'positive', '运'], negative: ['气运可能转衰', 'negative', '运'] },
      health: { positive: ['气血能够得到调息', 'positive', '息'], negative: ['可能损伤气血', 'negative', '伤'] },
      spiritStone: { positive: ['将获得修行资粮', 'positive', '石'], negative: ['需要耗费修行资粮', 'negative', '石'] },
      lifespan: { positive: ['寿元将有所延续', 'positive', '寿'], negative: ['可能耗损寿元', 'negative', '寿'] },
      tianji: { positive: ['天机将更易暴露', 'negative', '机'], negative: ['天机痕迹逐渐隐去', 'positive', '机'] }
    };
    const results = [];
    if (effects.opportunityReward && typeof opportunityAcquisitionSystem !== 'undefined') {
      const value = effects.opportunityReward;
      const opportunityId = typeof value === 'string' ? value : value?.opportunityId;
      const profile = typeof value === 'object' ? value?.profile : null;
      if (opportunityId && profile) {
        results.push({
          key: 'opportunityReward',
          text: opportunityAcquisitionSystem.formatPreview(opportunityId, {
            profile,
            sourceCardId: this.currentCard?.id || null
          }),
          tone: 'mixed',
          icon: '缘'
        });
      }
    }
    for (const [key, value] of Object.entries(effects)) {
      const pair = phrases[key];
      if (pair && typeof value === 'number' && value !== 0) {
        const [text, tone, icon] = value > 0 ? pair.positive : pair.negative;
        results.push({ key, text, tone, icon });
      }
    }
    const special = [
      [['triggerCombat', 'combat', 'startCombat'], '可能引发一场斗法', 'negative', '战'],
      [['pill', 'pills'], '将牵动丹药机缘', 'positive', '丹'],
      [['treasure', 'artifact'], '将牵动法宝机缘', 'positive', '宝'],
      [['companion', 'npcRelation', 'affection'], '人物关系可能改变', 'mixed', '缘'],
      [['dungeon', 'enterDungeon', 'secretRealm'], '将踏入未知秘境', 'mixed', '境'],
      [['openShop', 'openMarket', 'shop'], '将开启一场交易', 'mixed', '市'],
      [['deckCard', 'card', 'skillOpportunity', 'skillAcquire'], '可能悟得新的招式', 'positive', '诀'],
      [['reincarnate', 'reincarnation_bonus'], '将牵动轮回命数', 'mixed', '轮'],
      [['find_clue', 'clue', 'evidence'], '可能取得关键线索', 'positive', '迹']
    ];
    special.forEach(([keys, text, tone, icon]) => {
      if (keys.some(key => Object.prototype.hasOwnProperty.call(effects, key))) results.push({ key: keys[0], text, tone, icon });
    });
    return results.filter((item, index, all) => all.findIndex(other => other.text === item.text) === index);
  }

  /** 将后台数值翻译成玩家可感知的命运预兆。 */
  _formatEffectsPreview(effects) {
    return this._effectSemantics(effects).slice(0, 3).map(item => item.text).join(' · ');
  }

  _formatChoiceImpact(choice) {
    const semantic = this._formatEffectsPreview(choice?.effects);
    if (semantic) return `影响 · ${semantic}`;
    const desc = String(choice?.desc || '');
    if (/战|敌|袭|斗法/.test(desc)) return '影响 · 可能引发一场斗法';
    if (/线索|调查|探查|真相/.test(desc)) return '影响 · 可能取得新的线索';
    if (/离开|返回|回去|避开/.test(desc)) return '影响 · 将避开眼前因缘';
    if (/探索|进入|深入|前往/.test(desc)) return '影响 · 将开启未知遭遇';
    return '影响 · 后续机缘将被改写';
  }

  _getAuthoritativeChoicePreview(choice, requestedDirection = null) {
    const card = this.game?.getCurrentCard?.() || this.game?.currentCard || null;
    const direction = requestedDirection && card?.choices?.[requestedDirection]
      ? requestedDirection
      : (Object.entries(card?.choices || {})
        .find(([, candidate]) => candidate === choice)?.[0] || null);
    const context = {
      cardId: card?.id || null,
      cardTags: card?.tags || []
    };
    return (direction
      ? this.game?.previewCardChoices?.(card, context)?.[direction]
      : null)
      || this.game?.previewChoice?.(choice, { ...context, card, direction })
      || (direction
        ? this.game?.effectService?.previewCardChoices?.(card, context)?.[direction]
        : null)
      || this.game?.effectService?.previewChoice?.(choice, context)
      || null;
  }

  _formatAuthoritativeChoicePreview(preview, choice) {
    const currentCard = this.game?.getCurrentCard?.() || this.currentCard || null;
    const playerFacingReward = ['combat_reward', 'breakthrough_reward'].includes(currentCard?.id);
    if (!preview) {
      return playerFacingReward && choice?.desc
        ? String(choice.desc).split('\n\n', 1)[0]
        : this._formatChoiceImpact(choice);
    }
    const parts = [];
    for (const cost of preview.costs || []) {
      parts.push(cost.affordable
        ? `消耗${cost.label} ${cost.required}${cost.unit}（现有 ${cost.current}，结算后 ${cost.after}）`
        : `${cost.label}需 ${cost.required}${cost.unit} · 现有 ${cost.current} · 缺 ${cost.shortfall}`);
    }
    for (const change of preview.changes || []) {
      if (change.requestedDelta === undefined) continue;
      const requested = Number(change.requestedDelta);
      const actual = Number(change.actualDelta);
      const requestedText = `${requested >= 0 ? '+' : ''}${requested}${change.unit || ''}`;
      const actualText = `${actual >= 0 ? '+' : ''}${actual}`;
      const capText = change.maxValue !== null && change.maxValue !== undefined
        ? `，上限 ${change.maxValue}`
        : '';
      parts.push(`${change.label} ${requestedText}（实际 ${actualText}${capText}）`);
    }
    for (const card of preview.skillCards || []) {
      if (playerFacingReward) {
        const cost = card.cost === null ? '费用未知' : `${card.cost}费`;
        parts.push(`悟得【${card.name}】· ${cost} · ${card.description || '纳入本脉牌组'}`);
        continue;
      }
      const rules = (card.rules || []).map(rule => {
        const detail = Object.entries(rule)
          .filter(([key]) => key !== 'type')
          .map(([key, value]) => `${key} ${value}`)
          .join(' ');
        return `${rule.type || 'effect'}${detail ? ` ${detail}` : ''}`;
      }).join(' / ');
      const cost = card.cost === null ? '费用未知' : `${card.cost}费`;
      const tags = (card.tags || []).join('、') || '无标签';
      parts.push(`获得功法【${card.name}】· ${card.type} · ${cost} · ${card.description} · 标签：${tags}${rules ? ` · 规则：${rules}` : ''}`);
    }
    // Skill eligibility and random chances also matter outside combat outcomes.
    // Consume the authority's fact; UI must not reconstruct acquisition rules.
    for (const fact of preview.effectFacts || []) {
      if (['skillAcquire', 'skillOpportunity'].includes(fact.key)) parts.push(fact.text || fact.label);
    }
    for (const behavior of preview.behaviors || []) {
      parts.push(this._formatBehaviorProjection(behavior));
    }
    if (preview.reason === 'all_positive_rewards_capped') parts.push('正向收益均已封顶，当前不可用');
    if (preview.reason === 'capped_fallback') parts.push('收益已封顶，仍可继续此段因缘');
    if (preview.reason === 'missing_required_resource') parts.push('缺少所需物品，当前不可用');
    if (preview.reason === 'insufficient_resource') parts.push('资源不足，当前不可用');
    return parts.length
      ? parts.join(' · ')
      : (playerFacingReward && choice?.desc
        ? String(choice.desc).split('\n\n', 1)[0]
        : this._formatChoiceImpact(choice));
  }

  _formatProjectedOutcome(preview, injury = null) {
    const parts = [];
    for (const change of preview?.changes || []) {
      const actual = Number(change.actualDelta);
      if (!Number.isFinite(actual) || actual === 0) continue;
      parts.push(`${change.label}${actual > 0 ? '+' : ''}${actual}${change.unit || ''}`);
    }
    for (const card of preview?.skillCards || []) {
      parts.push(`获得功法【${card.name}】`);
    }
    for (const fact of preview?.effectFacts || []) {
      parts.push(fact.text || fact.label);
    }
    if (injury && Number(injury.applied) > 0) {
      parts.unshift(`真实气血-${Number(injury.applied)}点${injury.floor === null ? '' : `（最低保留 ${injury.floor}）`}`);
    }
    if (!parts.length) {
      const unaffordable = (preview?.costs || []).find(cost => cost.affordable === false);
      if (unaffordable) return `${unaffordable.label}不足，条件结果无法完整兑现`;
      return '无额外数值变化';
    }
    return parts.join('、');
  }

  _formatBehaviorProjection(behavior) {
    if (!behavior || behavior.contractValid === false) return '预览合同缺失，当前不可用';
    if (behavior.type === 'combat_chance') {
      const chance = Number(behavior.chance) || 0;
      const parts = [`斗法概率 ${Math.round(chance * 100)}%`];
      if (behavior.ordinaryPreview) {
        const ordinary = behavior.ordinaryPreview;
        const reasons = {
          all_positive_rewards_capped: '正向收益均已封顶，当前不能结算',
          insufficient_resource: '资源不足，当前不能结算',
          missing_required_resource: '缺少所需物品，当前不能结算'
        };
        parts.push(`未遇战（${Math.round((1 - chance) * 100)}%）：${ordinary.executable === false
          ? (reasons[ordinary.reason] || '当前不符合结算条件')
          : this._formatProjectedOutcome(ordinary)}`);
      }
      if (behavior.combatPreview) {
        parts.push(behavior.combatPreview.contractValid === false
          ? '遇战后：遭遇合同不可用，命中时拒绝且不结算'
          : `遇战后：${this._formatBehaviorProjection(behavior.combatPreview)}`);
      }
      return parts.join(' · ');
    }
    if (behavior.type === 'breakthrough') {
      const percent = value => `${Math.round(Math.max(0, Number(value) || 0) * 100)}%`;
      const modifiers = [];
      if (behavior.pill?.available) modifiers.push(`${behavior.pill.name}保证成功`);
      if (Number(behavior.boost) > 0) modifiers.push(`本境助力 +${percent(behavior.boost)}`);
      if (Number(behavior.tianjiPenalty) > 0) modifiers.push(`天机压制 -${percent(behavior.tianjiPenalty)}`);
      const failure = this._formatProjectedOutcome(behavior.failurePreview);
      return `突破 · 成功率 ${percent(behavior.finalRate)}（基础 ${percent(behavior.baseRate)}${modifiers.length ? `；${modifiers.join('；')}` : ''}）· 失败：${failure}`;
    }
    if (behavior.type === 'combat_outcomes') {
      const parts = behavior.branches.map(branch => (
        `${branch.label}：${this._formatProjectedOutcome(branch.preview, branch.injury || null)}`
      ));
      if (behavior.entryPreview) parts.unshift(`确认开战后：${this._formatProjectedOutcome(behavior.entryPreview)}`);
      return parts.join(' · ');
    }
    if (behavior.type === 'dungeon') {
      const availability = behavior.valid
        ? `可进入，共 ${behavior.nodeCount} 个节点`
        : `入口失效（${behavior.reason || '未知原因'}），选择后继续当前行程`;
      return `秘境入口【${behavior.name}】· ${availability}`;
    }
    if (behavior.type === 'action' && behavior.actionType !== 'ENTER_VENDOR') {
      const unavailable = behavior.eligible === false ? '当前条件不满足，暂不可执行 · ' : '';
      if (behavior.actionType === 'SETTLE_GHOST_DEBT') {
        const result = behavior.outcome === 'defaulted'
          ? `债契记为违约${behavior.revokesGhostMarket ? '，鬼市准入将被撤销' : ''}`
          : `支付 ${Number(behavior.spiritStoneCost) || 0} 灵石，结清此笔债契`;
        return `${unavailable}${result}`;
      }
      if (behavior.actionType === 'CLAIM_LICENSED_RUSTED_SWORD') {
        return `${unavailable}领取【${behavior.orderLabel || '官坊订购正货'}】· 随后选择穿戴或收入纳戒，不会自动替换装备`;
      }
      if (behavior.actionType === 'RESOLVE_NARRATIVE_FACT_CONSUMER') {
        return `${unavailable}因果去向：${behavior.outcomeText || '当前因果选择已不可用'} · 此事实只结算一次`;
      }
      if (behavior.actionType === 'DISMISS_VENDOR_RESULT') {
        return `${unavailable}交易回执已结算 · 关闭后继续行程，不重复结算、不推进决断`;
      }
    }
    if (behavior.type === 'action' && behavior.actionType === 'ENTER_VENDOR') {
      const marketNames = { regulated: '官坊', public_bazaar: '行商集市', ghost: '鬼市', ghost_market: '鬼市' };
      const name = marketNames[behavior.marketType] || '坊市';
      const availability = behavior.eligible ? '可进入' : `当前不可进入（${behavior.reason || '入口条件不足'}）`;
      return `坊市【${name}】· ${availability} · 交易关闭后恰好结算一次`;
    }
    return '预览合同缺失，当前不可用';
  }

  _choiceForDirection(card, dir) {
    if (!card?.choices) return null;
    if (card.choices[dir]) return card.choices[dir];
    const keys = Object.keys(card.choices);
    const index = ['left', 'right', 'up', 'down'].indexOf(dir);
    return index >= 0 ? card.choices[keys[index]] || null : null;
  }

  _refreshSwipeChoicePreviews(card) {
    if (!this.swipeStage) return;
    const isCombat = card?.type === 'COMBAT_UI';
    this.swipeStage.classList.toggle('is-disabled', isCombat);
    for (const dir of ['left', 'right', 'up', 'down']) {
      const preview = this.swipePreviews[dir];
      if (!preview) continue;
      const choice = this._choiceForDirection(card, dir);
      const authoritative = choice ? this._getAuthoritativeChoicePreview(choice, dir) : null;
      preview.classList.toggle('is-available', Boolean(choice) && !isCombat && authoritative?.executable !== false);
      preview.dataset.mood = choice ? this._choiceMood(choice.effects) : 'neutral';
      preview.querySelector('.swipe-choice-title').textContent = choice?.text || '此路未显';
      preview.querySelector('.swipe-choice-impact').textContent = choice
        ? this._formatChoicePreviewSummary(authoritative, choice)
        : '命盘中没有这道选择';
    }
    this._resetSwipeChoicePreview();
  }

  _updateSwipeChoicePreview(dir, progress) {
    if (!this.swipeStage) return;
    const target = this.swipePreviews[dir];
    if (!target?.classList.contains('is-available')) {
      this._resetSwipeChoicePreview();
      return;
    }
    this.swipeStage.classList.add('is-previewing');
    this.swipeStage.setAttribute('aria-hidden', 'false');
    Object.values(this.swipePreviews).forEach(preview => preview.classList.toggle('is-active', preview === target));
    target.style.setProperty('--swipe-progress', Math.max(0.08, Math.min(1, progress)).toFixed(2));
    this.cardEl.closest('.card-area')?.classList.add('is-swiping');
  }

  _resetSwipeChoicePreview() {
    if (!this.swipeStage) return;
    this.swipeStage.classList.remove('is-previewing');
    this.swipeStage.setAttribute('aria-hidden', 'true');
    Object.values(this.swipePreviews).forEach(preview => {
      preview.classList.remove('is-active');
      preview.style.removeProperty('--swipe-progress');
    });
    this.cardEl?.closest('.card-area')?.classList.remove('is-swiping');
  }

  // ============ 日志 ============

  addLog(message, cssClass) {
    const text = String(message || '').trim();
    if (!text) return;
    if (this._isDeveloperLog(text, cssClass)) {
      console.debug('[仙途后台]', text);
      return;
    }
    this.logMessages.unshift({
      text,
      cssClass: cssClass || '',
      turn: gameState.getDecisionIndex?.() ?? gameState.turn ?? 0,
      sequence: (this._logSequence = (this._logSequence || 0) + 1)
    });
    if (this.logMessages.length > this.maxLogMessages) {
      this.logMessages.pop();
    }
    this.renderLog();
  }

  /** 玩家玉简只记录世界内发生的事，诊断信息留在开发者控制台。 */
  _isDeveloperLog(message, cssClass) {
    if (cssClass === 'debug' || cssClass === 'diagnostic') return true;
    return /^(\[(makeChoice|转世判断|转世|系统|debug|diagnostic|flow)\])|^【?\[?战斗结算(?:·[^\]】]+)?[\]】]|数据源[:：]|\b(dungeonId|cardId|count|hpRegen|fortuneBonus|inCombat|hpBefore|hpAfter|hpNow|maxHealth|willCheckDeath)=/i.test(message);
  }

  renderLog() {
    if (!this.logContainer) return;
    const meta = {
      choice: { glyph: '念', label: '一念既出' },
      combat: { glyph: '战', label: '斗法留痕' },
      karma: { glyph: '因', label: '因果回响' },
      quest: { glyph: '缘', label: '尘缘新章' },
      realm: { glyph: '境', label: '境界感悟' }
    };
    this.logContainer.innerHTML = this.logMessages
      .map(msg => {
        const dataType = this._logDataType(msg.cssClass);
        const typeMeta = meta[dataType] || meta.choice;
        const safeClass = String(msg.cssClass || '').replace(/[^a-zA-Z0-9_-]/g, '');
        const turnText = msg.turn > 0 ? `已完成 ${msg.turn} 次决断时` : '入世之初';
        if (msg.cssClass === 'thread-complete') {
          const lines = this._normalizeNarrativeText(msg.text).split('\n');
          return `<article class="log-item log-thread-complete" data-type="${dataType}">
            <div class="log-timeline"><span class="log-glyph">章</span><i></i></div>
            <div class="log-entry-body">
              <div class="log-entry-meta"><span>一卷终章</span><time>${turnText}</time></div>
              <div class="thread-log-title">${this._escapeHtml(lines[0] || '')}</div>
              ${lines[1] ? `<div class="thread-log-note">${this._escapeHtml(lines[1])}</div>` : ''}
              ${lines[2] ? `<div class="thread-log-karma">${this._escapeHtml(lines[2])}</div>` : ''}
            </div>
          </article>`;
        }
        return `<article class="log-item ${safeClass}" data-type="${dataType}">
          <div class="log-timeline"><span class="log-glyph">${typeMeta.glyph}</span><i></i></div>
          <div class="log-entry-body">
            <div class="log-entry-meta"><span>${typeMeta.label}</span><time>${turnText}</time></div>
          <p>${this._escapeHtml(this._normalizeNarrativeText(msg.text)).replace(/\n/g, '<br>')}</p>
          </div>
        </article>`;
      })
      .join('');

    // 更新计数角标
    if (this.logCountEl) {
      this.logCountEl.textContent = this.logMessages.length;
    }
  }

  _normalizeNarrativeText(value) {
    if (typeof normalizeNarrativeText === 'function') return normalizeNarrativeText(value);
    return String(value == null ? '' : value)
      .replace(/\\r\\n/g, '\n')
      .replace(/\\n/g, '\n')
      .replace(/\r\n/g, '\n')
      .replace(/\r/g, '\n')
      .replace(/\n{3,}/g, '\n\n')
      .trim();
  }

  _narrativeHtml(value) {
    return this._escapeHtml(this._normalizeNarrativeText(value)).replace(/\n/g, '<br>');
  }

  _renderEndingReport(card) {
    const existing = this.cardEl?.parentElement?.querySelector('[data-ending-report]');
    const report = card?.id?.startsWith('ending_') ? gameState.lastEndingReport : null;
    if (!report?.tribulationTestimony?.text) {
      existing?.remove();
      return;
    }
    const details = existing || document.createElement('details');
    if (!existing) {
      details.className = 'ending-report ending-report-inline';
      details.dataset.endingReport = '';
      const summary = document.createElement('summary');
      summary.textContent = '查看本世结局报告';
      details.appendChild(summary);
      this.cardEl.insertAdjacentElement('afterend', details);
    }
    details.querySelectorAll('p').forEach(paragraph => paragraph.remove());
    const appendLine = (label, value) => {
      const line = document.createElement('p');
      const heading = document.createElement('strong');
      heading.textContent = `${label}：`;
      line.append(heading, document.createTextNode(value));
      details.appendChild(line);
    };
    appendLine('结局立场', report.stance || gameState.endingId || '待核验');
    appendLine('天门证词', report.tribulationTestimony.text);
    const rejected = gameState.getTerminalContext?.()?.candidateRejection;
    if (rejected?.name && Array.isArray(rejected.missing)) {
      appendLine('未竟的意向', `${rejected.name}尚缺：${rejected.missing.join('；')}`);
    }
    appendLine('已证实', Array.isArray(report.verifiedHypotheses)
      ? report.verifiedHypotheses.join('、') || '尚无完整真相假说' : '尚无完整真相假说');
    appendLine('跨世证据', Array.isArray(report.discoveredClues)
      ? report.discoveredClues.join('、') || '无' : '无');
  }

  _escapeHtml(value) {
    return String(value || '').replace(/[&<>"']/g, char => ({
      '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
    })[char]);
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
    const report = state.lastEndingReport;
    const testimonyHtml = report?.tribulationTestimony?.text
      ? `<div><strong>天门证词：</strong>${this._narrativeHtml(report.tribulationTestimony.text)}</div>`
      : '';
    const reportHtml = report ? `
      <div class="ending-report">
        <strong>结局立场：${report.stance}</strong>
        <div>达成路径：${report.reasons.filter(reason => reason.ok).map(reason => reason.text).join('、') || '以当前选择强行踏入此结局'}</div>
        <div>已证实：${report.verifiedHypotheses.join('、') || '尚无完整真相假说'}</div>
        <div>跨世证据：${report.discoveredClues.join('、') || '无'}</div>
        ${testimonyHtml}
      </div>` : '';
    this.deathStats.innerHTML = `
      <div>${playerName} · ${state.getRealmName(state.realm)}</div>
      <div>本世已完成决断：${state.turn}</div>
      <div>当前轮回：第 ${state.getLifeCount() + 1} 世</div>
      <div>解锁加成：修为+${state.unlocks.bonuses.startCultivation} / 灵石+${state.unlocks.bonuses.startSpiritStone} / 寿元+${state.unlocks.bonuses.maxLifespan}</div>
      ${reportHtml}
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
    if (e.target.closest('.choice-btn')) return;
    this.startSwipe(e.clientX, e.clientY);
    e.preventDefault();
  }
  onMouseMove(e) { if (!this.touching) return; this.moveSwipe(e.clientX, e.clientY); }
  onMouseUp(e) { this.endSwipe(); }

  onCardHover(e) {
    if (this.touching) return;
    const rect = this.cardEl.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;
    const xc = rect.width / 2;
    const yc = rect.height / 2;
    if (window.matchMedia?.('(prefers-reduced-motion: reduce)').matches) return;
    const rotateY = ((x - xc) / xc) * 3.4;
    const rotateX = -((y - yc) / yc) * 3.4;
    this.cardEl.style.transition = 'transform 120ms cubic-bezier(0.2, 0.72, 0.22, 1), box-shadow 160ms ease-out';
    this.cardEl.style.transform = `perspective(1000px) rotateX(${rotateX}deg) rotateY(${rotateY}deg) scale3d(1.012, 1.012, 1.012)`;
    // Dynamic shadow to enhance the 3D feel
    this.cardEl.style.boxShadow = `${-rotateY * 1.5}px ${rotateX * 1.5}px 26px rgba(0,0,0,0.42), 0 0 18px rgba(205,176,112,0.035) inset`;
  }

  onCardLeave(e) {
    if (this.touching) return;
    this.cardEl.style.transition = 'transform 360ms cubic-bezier(0.18, 0.88, 0.28, 1.08), box-shadow 320ms ease';
    this.cardEl.style.transform = 'perspective(1000px) rotateX(0deg) rotateY(0deg) scale3d(1, 1, 1)';
    this.cardEl.style.boxShadow = '';
  }

  startSwipe(x, y) {
    this.touching = true;
    this.swipeStartX = x;
    this.swipeStartY = y;

    this.phys.targetX = 0;
    this.phys.targetY = 0;
    this.phys.currentX = 0;
    this.phys.currentY = 0;
    this.phys.lastX = 0;
    this.phys.lastY = 0;
    this.phys.vx = 0;
    this.phys.vy = 0;

    this.cardEl.style.transition = 'none'; // Use JS physics
    this.cardEl.style.willChange = 'transform';
    this.cardEl.classList.add('is-dragging');
    this._resetSwipeChoicePreview();

    // Start physics loop
    this._startSwipePhysicsLoop();
  }

  moveSwipe(x, y) {
    if (!this.touching) return;
    const dx = x - this.swipeStartX;
    const dy = y - this.swipeStartY;

    const w = this._getCardWeight(); // 1.0 for normal, ~0.45 for heavy
    this.phys.targetX = dx * w;
    this.phys.targetY = dy * w;

    const distance = Math.max(Math.abs(dx), Math.abs(dy));
    const horizontal = Math.abs(dx) >= Math.abs(dy);
    const dir = horizontal ? (dx >= 0 ? 'right' : 'left') : (dy >= 0 ? 'down' : 'up');
    const decisionThreshold = this.swipeThreshold * (2 - w);

    if (distance > 6) this._updateSwipeChoicePreview(dir, distance / decisionThreshold);
    this.highlightDirection(dx, dy);
  }

  _startSwipePhysicsLoop() {
    if (!this.renderLoop) {
      console.warn('[GameUI] RenderLoopCoordinator unavailable; swipe physics animation skipped');
      return;
    }
    this._swipeRenderLoopUnsubscribe?.();
    this._swipeRenderLoopUnsubscribe = this.renderLoop.register('ui-swipe-physics', () => this._tickPhysicsFrame(), {
      fps: 60,
      isActive: () => this.touching === true
    });
  }

  _tickPhysicsFrame() {
    if (!this.touching) return;

    const w = this._getCardWeight();
    // Heavy card: lerp = 0.08, Light card: lerp = 0.20
    const lerp = 0.08 + (w * 0.12);

    // Lerp pursuit
    this.phys.currentX += (this.phys.targetX - this.phys.currentX) * lerp;
    this.phys.currentY += (this.phys.targetY - this.phys.currentY) * lerp;

    // Calculate instantaneous velocity
    this.phys.vx = this.phys.currentX - this.phys.lastX;
    this.phys.vy = this.phys.currentY - this.phys.lastY;
    this.phys.lastX = this.phys.currentX;
    this.phys.lastY = this.phys.currentY;

    // Dynamic physics tilt
    const rotateZ = this.phys.vx * 0.25;
    const tiltY = this.phys.vx * 0.08;
    const tiltX = -this.phys.vy * 0.08;

    this.cardEl.style.transform = `translate3d(${this.phys.currentX}px, ${this.phys.currentY}px, 0) perspective(800px) rotateX(${tiltX}deg) rotateY(${tiltY}deg) rotateZ(${rotateZ}deg) scale3d(1.04, 1.04, 1.04)`;

  }

  endSwipe() {
    if (!this.touching) return;
    this.touching = false;

    this._swipeRenderLoopUnsubscribe?.();
    this._swipeRenderLoopUnsubscribe = null;
    this.phys.rAF = null;

    this.cardEl.classList.remove('is-dragging');
    const dx = this.phys.currentX;
    const dy = this.phys.currentY;
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

    this._resetSwipeChoicePreview();

    if (chosenDir) {
      // Inertia throw out
      this.cardEl.style.transition = 'transform 0.25s cubic-bezier(0.25, 1, 0.5, 1), opacity 0.2s ease';
      const exitX = chosenDir === 'right' ? 800 : (chosenDir === 'left' ? -800 : 0);
      const exitY = chosenDir === 'down' ? 800 : (chosenDir === 'up' ? -800 : 0);
      this.cardEl.style.transform = `translate3d(${exitX}px, ${exitY}px, 0) rotateZ(${exitX * 0.1}deg) scale3d(0.8, 0.8, 0.8)`;
      this.cardEl.style.opacity = '0';

      setTimeout(() => {
        this.cardEl.style.willChange = 'auto';
        this.makeChoice(chosenDir);
      }, 250);
    } else {
      // Spring Bounce back
      this.cardEl.style.transition = 'transform 0.5s cubic-bezier(0.34, 1.56, 0.64, 1), box-shadow 0.4s ease';
      this.cardEl.style.transform = 'translate3d(0px, 0px, 0) perspective(800px) rotateX(0deg) rotateY(0deg) rotateZ(0deg) scale3d(1, 1, 1)';
      this.cardEl.style.boxShadow = '';

      setTimeout(() => {
        this.cardEl.style.willChange = 'auto';
      }, 500);
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
  // 人物与法宝面板 (Character Panel)
  // ==========================================

  bindCharacterPanel() {
    const btn = document.getElementById('character-panel-btn');
    if (btn) {
      btn.addEventListener('click', () => this.openCharacterPanel());
    }

    const closeBtn = document.getElementById('character-close');
    if (closeBtn) {
      closeBtn.addEventListener('click', () => {
        document.getElementById('character-panel').style.display = 'none';
      });
    }

    // Allow hotkey 'C' or 'c' to toggle
    document.addEventListener('keydown', (e) => {
      if ((e.key === 'c' || e.key === 'C') && !e.ctrlKey && !e.altKey && !e.metaKey) {
        const panel = document.getElementById('character-panel');
        if (panel && panel.style.display === 'block') {
          panel.style.display = 'none';
        } else if (panel) {
          this.openCharacterPanel();
        }
      }
    });

    // Close on click outside
    const panel = document.getElementById('character-panel');
    if (panel) {
      panel.addEventListener('click', (e) => {
        if (e.target === e.currentTarget) {
          e.currentTarget.style.display = 'none';
        }
      });
    }
  }

  openCharacterPanel() {
    const panel = document.getElementById('character-panel');
    if (!panel) return;

    this.renderCharacterStats();
    this.renderCharacterEquipmentSlots();
    this.renderInventoryEquipment();

    panel.style.display = 'flex';
  }

  renderCharacterStats() {
    const container = document.getElementById('character-stats-container');
    if (!container) return;
    const g = this.game.gameState;

    container.innerHTML = `
      <div>
        <p><strong>境界:</strong> ${g.realmName || '凡人'}</p>
        <p><strong>流派:</strong> ${g.pathName || '未定'}</p>
        <p><strong>寿元:</strong> ${g.attributes.lifespan}</p>
        <p><strong>气血:</strong> ${g.attributes.health} / ${(typeof g.getActualMaxHealth === 'function' ? g.getActualMaxHealth() : g.maxHealth)}</p>
      </div>
      <div>
        <p><strong>攻击(ATK):</strong> ${g.attributes.atk || 0}</p>
        <p><strong>防御(DEF):</strong> ${g.attributes.def || 0}</p>
        <p><strong>暴击率:</strong> ${(g.attributes.critRate || 0)}%</p>
        <p><strong>暴击伤害:</strong> ${Math.floor((g.attributes.critDmg || 1.5) * 100)}%</p>
      </div>
    `;
  }

  renderCharacterEquipmentSlots() {
    const slots = ['weapon', 'armor', 'accessory', 'artifact'];
    const system = typeof treasureSystem !== 'undefined' ? treasureSystem : null;
    if (!system) return;

    slots.forEach(slot => {
      const el = document.getElementById(`eq-slot-${slot}`);
      if (!el) return;

      const itemId = system.getEquipped(slot);
      if (itemId) {
        const item = system.getTreasureData(itemId);
        if (item) {
          el.innerHTML = `<span style="font-size: 0.8em; text-align: center;">${item.name}</span>`;
          el.title = `${item.name}\n${item.desc}`;
          el.onclick = () => {
            if (confirm(`卸下 ${item.name}？`)) {
              system.unequip(slot);
              this.renderCharacterStats();
              this.renderCharacterEquipmentSlots();
              this.renderInventoryEquipment();
              this.updateTopBar();
            }
          };
        } else {
          el.innerHTML = `<span style="color:#555;">${this._getSlotName(slot)}</span>`;
          el.onclick = null;
          el.title = this._getSlotName(slot);
        }
      } else {
        const defaultColor = slot === 'artifact' ? '#f1c40f' : '#555';
        el.innerHTML = `<span style="color:${defaultColor};">${this._getSlotName(slot)}</span>`;
        el.onclick = null;
        el.title = this._getSlotName(slot);
      }
    });
  }

  _getSlotName(slot) {
    const map = { weapon: '武器', armor: '护甲', accessory: '饰品', artifact: '本命' };
    return map[slot] || slot;
  }

  renderInventoryEquipment() {
    const container = document.getElementById('inventory-equipment-container');
    if (!container) return;

    container.innerHTML = '';
    const g = this.game.gameState;
    const system = typeof treasureSystem !== 'undefined' ? treasureSystem : null;
    if (!system) return;

    // 背包是由 instance 账本派生的只读查询，不读取旧的可写 inventory 投影。
    const eqItems = system.getUnequippedInstanceIds()
      .filter(id => Boolean(system.getTreasureData(id)));

    if (eqItems.length === 0) {
      container.innerHTML = '<span style="color:#aaa; padding: 10px;">背包空空如也…</span>';
      return;
    }

    eqItems.forEach(itemId => {
      const item = system.getTreasureData(itemId);
      if (!item) return;

      const div = document.createElement('div');
      div.style.padding = '8px';
      div.style.border = '1px solid #5d6d7e';
      div.style.borderRadius = '5px';
      div.style.cursor = 'pointer';
      div.style.backgroundColor = 'rgba(255,255,255,0.05)';

      div.innerHTML = `<strong>${item.name}</strong> <span style="font-size:0.8em; color:#aaa;">[${this._getSlotName(item.type)}]</span><br><span style="font-size:0.9em;">${item.desc}</span>`;

      div.onclick = () => {
        const pending = g.pendingLoadoutDecision;
        const result = pending?.status === 'pending' && pending.instanceId === itemId
          && typeof shopSystem !== 'undefined' && shopSystem?.resolveLoadoutDecision
          ? shopSystem.resolveLoadoutDecision('equip')
          : system.equip(itemId, item.type);
        if (result.success) {
          this.renderCharacterStats();
          this.renderCharacterEquipmentSlots();
          this.renderInventoryEquipment();
          this.updateTopBar();
        }
      };

      container.appendChild(div);
    });
  }

  _pendingLoadoutDecision() {
    const pending = gameState?.pendingLoadoutDecision;
    return pending?.status === 'pending' ? pending : null;
  }

  closeLoadoutDecision({ dismiss = false } = {}) {
    const pending = this._pendingLoadoutDecision();
    if (dismiss && pending) this._loadoutDecisionDismissedId = pending.id;
    if (this.loadoutDecisionModal) {
      this.loadoutDecisionModal.style.display = 'none';
      this.loadoutDecisionModal.setAttribute('aria-hidden', 'true');
    }
  }

  openLoadoutDecision({ force = false } = {}) {
    const pending = this._pendingLoadoutDecision();
    // Rendering is driven by authoritative state.  A transaction rollback can
    // invalidate a prompt that was already on screen, so close it rather than
    // leaving an inert modal over the retryable source card.
    if (!pending) {
      this.closeLoadoutDecision();
      return false;
    }
    if (!this.loadoutDecisionModal || typeof treasureSystem === 'undefined') return false;
    if (!force && this._loadoutDecisionDismissedId === pending.id) return false;
    const treasure = treasureSystem.getTreasureData?.(pending.instanceId);
    const instance = treasureSystem.getInstance?.(pending.instanceId);
    if (!treasure || !instance) return false;
    const slotNames = { weapon: '武器', armor: '护甲', accessory: '饰品', artifact: '本命法宝' };
    const oldInstanceId = gameState.equipment?.[pending.targetSlot] || null;
    const oldTreasure = oldInstanceId ? treasureSystem.getTreasureData?.(oldInstanceId) : null;
    const sourceLabels = {
      market_purchase: '集市交易', public_bazaar_trade: '集市易手', shop_purchase: '坊市交易',
      ghost_market_purchase: '鬼市交易', ghost_market: '鬼市交易',
      regulated_rusted_sword_order: '坊市官印订货'
    };
    if (this.loadoutDecisionTitle) this.loadoutDecisionTitle.textContent = `新得法宝 · ${treasure.name}`;
    if (this.loadoutDecisionSummary) {
      const replacement = oldTreasure
        ? `若穿戴，当前【${oldTreasure.name}】会回到纳戒。`
        : `【${slotNames[pending.targetSlot] || pending.targetSlot}】槽尚空。`;
      this.loadoutDecisionSummary.textContent = `${treasure.desc || '此器已记入纳戒。'} ${replacement}`;
    }
    if (this.loadoutDecisionComparison) {
      const describeEffects = item => {
        if (!item) return '无';
        const labels = { atk: '攻击', def: '防御', critRate: '暴击', hpRegen: '气血回复', qiRegen: '灵力回复' };
        const stats = Object.entries(item.passive && !Array.isArray(item.passive) ? item.passive : {})
          .filter(([, value]) => Number(value) !== 0)
          .map(([key, value]) => `${labels[key] || key} ${Number(value) > 0 ? '+' : ''}${value}`);
        const mechanics = (Array.isArray(item.combatPassives) ? item.combatPassives : [])
          .map(passive => passive.hook === 'onGuardResolved' && passive.statusId === 'counter_force'
            ? `首次成功防御后，下一次攻击伤害 +${Math.max(0, Number(passive.value) || 0)}`
             : Number(passive.distinctTagsThreshold) > 0 && passive.temporaryTacticalCardId
               ? `本场打出 ${Math.floor(Number(passive.distinctTagsThreshold))} 种不同战斗标签后，获得一次【旧式剑路】`
              : passive.hook === 'onTurnStart' && passive.oncePerCombat === true && passive.temporaryTacticalCardId
                ? '每场首回合获得一次耗竭式【噬主剑鸣】'
              : null)
          .filter(Boolean);
        const effectDetails = [...stats, ...mechanics];
        return [...effectDetails, ...(effectDetails.length === 0 ? [item.combatPresentation?.summary] : [])]
          .filter((value, index, all) => value && all.indexOf(value) === index)
          .join(' · ') || '无额外战斗效果';
      };
      this.loadoutDecisionComparison.textContent = [
        oldTreasure
          ? `当前${slotNames[pending.targetSlot] || pending.targetSlot}：${oldTreasure.name}｜${describeEffects(oldTreasure)}`
          : `当前${slotNames[pending.targetSlot] || pending.targetSlot}：空槽`,
        `新得${slotNames[pending.targetSlot] || pending.targetSlot}：${treasure.name}｜${describeEffects(treasure)}`
      ].join('\n');
    }
    if (this.loadoutDecisionProvenance) {
      const provenance = instance.provenance || {};
      const source = sourceLabels[provenance.source] || provenance.source || '未知来历';
      const exchange = provenance.exchangeLabel ? ` · ${provenance.exchangeLabel}` : '';
      const clue = provenance.oldOwnerClue ? ` · ${provenance.oldOwnerClue}` : '';
      const debt = pending.ghostDebt;
      const debtCost = (debt?.settlementCostSpec || [])
        .map(cost => `${cost.amount}${cost.key === 'spiritStone' ? '灵石' : cost.key === 'lifespan' ? '寿元' : cost.key}`)
        .join('、');
      const debtTerm = debt?.debtId
        ? ` · ${debt.contractLabel || '夜契'}：第 ${debt.dueDecisionIndex} 次决断到期，补 ${debtCost || '一笔代价'}；战胜时前压 ${Math.round((Number(debt.pressure?.chance) || 0) * 100)}%，连续 ${debt.pressure?.pityLimit || 3} 场保底`
        : '';
      this.loadoutDecisionProvenance.textContent = `来历：${source}${exchange}${clue}${debtTerm}`;
      this.loadoutDecisionProvenance.hidden = true;
    }
    if (this.loadoutDecisionEquip) {
      this.loadoutDecisionEquip.textContent = `立即穿戴到${slotNames[pending.targetSlot] || pending.targetSlot}`;
      this.loadoutDecisionEquip.disabled = pending.allowedActions?.equip !== true;
      this.loadoutDecisionEquip.onclick = () => this._resolveLoadoutDecision('equip');
    }
    if (this.loadoutDecisionStash) {
      this.loadoutDecisionStash.disabled = pending.allowedActions?.stash !== true;
      this.loadoutDecisionStash.onclick = () => this._resolveLoadoutDecision('stash');
    }
    if (this.loadoutDecisionView) {
      this.loadoutDecisionView.onclick = () => {
        if (this.loadoutDecisionProvenance) this.loadoutDecisionProvenance.hidden = !this.loadoutDecisionProvenance.hidden;
      };
    }
    if (this.loadoutDecisionClose) this.loadoutDecisionClose.onclick = () => this.closeLoadoutDecision({ dismiss: true });
    this.loadoutDecisionModal.onclick = event => {
      if (event.target === this.loadoutDecisionModal) this.closeLoadoutDecision({ dismiss: true });
    };
    this.loadoutDecisionModal.style.display = 'flex';
    this.loadoutDecisionModal.setAttribute('aria-hidden', 'false');
    return true;
  }

  _resolveLoadoutDecision(action) {
    if (typeof shopSystem === 'undefined' || !shopSystem?.resolveLoadoutDecision) return;
    const result = shopSystem.resolveLoadoutDecision(action);
    if (!result?.success) {
      this._showShopToast(result?.message || '装配未能保存。');
      return;
    }
    this.closeLoadoutDecision();
    this._showShopToast(result.message);
    this.renderGame();
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
      this._npcPanelReturnFocus?.focus?.();
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
        this._npcPanelReturnFocus?.focus?.();
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

    // 宗门录面板（EPIC-1.1）
    this._bindFactionPanel();

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
    eventBus.on('shop:open', (data) => this._openShop(data || { items: [] }));
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
    // 兼容旧调用 _openShop(items)，正式入口统一使用 { items, market, ... }。
    if (Array.isArray(data)) data = { items: data };
    data = data || { items: [] };
    const panel = document.getElementById('shop-panel');
    const spiritEl = document.getElementById('shop-spirit-stone-val');
    if (spiritEl) spiritEl.textContent = gameState.resources.spiritStone;
    // A result toast belongs to the completed session. Letting a bazaar barter
    // hang over the next ghost-market contract makes the domains feel like one
    // recycled shop and misattributes the last receipt.
    const staleToast = panel?.querySelector('.shop-result-toast');
    if (staleToast) {
      staleToast.textContent = '';
      staleToast.style.opacity = '0';
    }
    const marketType = data.marketType || data.session?.marketType || (data.market ? 'ghost' : 'regulated');
    const presentationProfile = data.session?.presentationProfile || data.presentationProfile || null;
    this._shopRenderData = { ...data, marketType, presentationProfile };
    // market is legacy visual compatibility. marketType owns domain rendering.
    if (panel) {
      panel.dataset.market = marketType === 'ghost' ? 'true' : 'false';
      panel.dataset.marketType = marketType;
      this._applyMarketPresentation(panel, presentationProfile);
    }
    const offers = (typeof shopSystem !== 'undefined' && shopSystem && shopSystem.open)
      ? shopSystem.open(data.items || [], {
          source: marketType === 'ghost' ? 'market' : 'shop',
          vendorId: data.vendorId,
          marketType,
          entryCardId: data.entryCardId,
          sessionKey: data.sessionKey,
          summary: data.summary,
          session: data.session
        })
      : (data.items || []);
    this._renderShopItems(offers, this._shopRenderData);
    if (panel) panel.style.display = 'flex';
  }

  _closeShop() {
    const panel = document.getElementById('shop-panel');
    if (panel) panel.style.display = 'none';
    const summary = (typeof shopSystem !== 'undefined' && shopSystem && shopSystem.close)
      ? shopSystem.close()
      : { alreadyClosed: false, purchaseCount: 0, openingOfferCount: 0 };
    eventBus.emit('shop:closed', summary);
  }

  // Presentation comes from the immutable VendorSession snapshot. Keep the
  // whitelist local to the renderer: even a legacy or manually edited save
  // may alter no more than decorative classes/URLs, never shop authority.
  _applyMarketPresentation(panel, rawPresentation) {
    const leaveButton = document.getElementById('shop-leave-btn');
    const knownProfiles = {
      'regulated-ledger': {
        layout: 'ledger',
        backgroundPath: '../assets/markets/regulated/bg_market_regulated_pc98.webp',
        fallbackClass: 'market-regulated-fallback'
      },
      'public-bazaar-stalls': {
        layout: 'stalls',
        backgroundPath: '../assets/markets/bazaar/bg_market_bazaar_pc98.webp',
        fallbackClass: 'market-bazaar-fallback'
      },
      'ghost-contract-plinth': {
        layout: 'contract',
        backgroundPath: '../assets/markets/ghost/bg_market_ghost_pc98.webp',
        fallbackClass: 'market-ghost-fallback'
      }
    };
    const candidate = rawPresentation && typeof rawPresentation === 'object'
      ? knownProfiles[rawPresentation.id] || null
      : null;
    const profile = candidate
      && rawPresentation.layout === candidate.layout
      && rawPresentation.backgroundPath === candidate.backgroundPath
      && rawPresentation.fallbackClass === candidate.fallbackClass
      ? candidate
      : null;
    const fallbackClasses = Object.values(knownProfiles).map(entry => entry.fallbackClass);
    panel.classList.remove(...fallbackClasses);
    if (profile) {
      panel.dataset.marketPresentation = rawPresentation.id;
      panel.dataset.marketLayout = rawPresentation.layout;
      panel.classList.add(profile.fallbackClass);
      panel.style.setProperty('--market-background-image', `url("${rawPresentation.backgroundPath}")`);
    } else {
      delete panel.dataset.marketPresentation;
      delete panel.dataset.marketLayout;
      panel.style.removeProperty('--market-background-image');
    }
    if (leaveButton) {
      const label = typeof rawPresentation?.exitLabel === 'string' && rawPresentation.exitLabel.trim()
        ? rawPresentation.exitLabel.trim()
        : '离开集市';
      leaveButton.textContent = label;
      leaveButton.setAttribute('aria-label', label);
    }
  }

  _renderShopItems(items, marketData) {
    const container = document.getElementById('shop-items-container');
    if (!container) return;
    container.innerHTML = '';

    const marketType = marketData?.marketType || 'regulated';
    this._renderShopArrivalAnchor(marketData, marketType);
    const marketTitle = document.getElementById('shop-panel-title');
    if (marketType === 'ghost') {
      const header = document.createElement('div');
      header.className = 'shop-market-header shop-ghost-contract';
      if (marketTitle) marketTitle.textContent = '鬼市 · 寿契';
      const markup = marketData.ghostMarkupRange;
      const pct = marketData.priceMult ? Math.round((marketData.priceMult - 1) * 100) : 0;
      const pctStr = markup
        ? `+${Math.round((markup.min - 1) * 100)}%—+${Math.round((markup.max - 1) * 100)}%`
        : (pct >= 0 ? `+${pct}%` : `${pct}%`);
      header.innerHTML = `
        <span class="market-fortune-tag">不问真名 · 债到必偿 · ${marketData.fortuneTier || '未知运道'}</span>
        <span class="market-price-tag">每件禁物另折寿元 · 灵石物价${pctStr}</span>
        ${marketData.tradeRoute ? `<span class="market-route-tag">🧭 ${marketData.tradeRoute.name} · 通畅${marketData.tradeRoute.openness} / 风险${marketData.tradeRoute.danger}</span>` : ''}
      `;
      container.appendChild(header);
      const actions = typeof shopSystem !== 'undefined' ? shopSystem.getVendorActions?.() || [] : [];
      if (actions.length) {
        const services = document.createElement('div');
        services.className = 'shop-ghost-services';
        services.innerHTML = actions.map(action => `<button class="shop-vendor-action" data-action-id="${action.actionId}" ${action.available ? '' : 'disabled'} title="${action.description}">${action.available ? action.label : action.disabledReason}</button>`).join('');
        services.querySelectorAll('.shop-vendor-action').forEach(button => {
          if (!button.disabled) button.addEventListener('click', event => { event.stopPropagation(); this._handleShopVendorAction(button.dataset.actionId); });
        });
        container.appendChild(services);
      }
    } else if (marketType === 'public_bazaar') {
      if (marketTitle) marketTitle.textContent = '集市 · 三摊记名';
      const stalls = document.createElement('div');
      stalls.className = 'shop-bazaar-stalls';
      const actions = typeof shopSystem !== 'undefined' ? shopSystem.getVendorActions?.() || [] : [];
      const sessionStalls = marketData?.session?.stalls || [];
      stalls.innerHTML = sessionStalls.map(stall => {
        const stallActions = actions.filter(candidate => candidate.stallId === stall.id);
        const relation = stall.relationshipUnlocked && stall.relationHint
          ? `<em class="shop-bazaar-relation">熟客 · ${stall.relationHint}</em>`
          : '';
        const actionButtons = stallActions.map(action => `<button class="shop-vendor-action" data-action-id="${action.actionId}" ${action.available ? '' : 'disabled'} title="${action.disabledReason || action.description}">${action.available ? action.label : action.disabledReason}</button>`).join('');
        return `<section class="shop-bazaar-stall" data-stall-id="${stall.id}"><strong>${stall.name}</strong><small>${stall.role || ''}</small>${relation}${actionButtons}</section>`;
      }).join('');
      stalls.querySelectorAll('.shop-vendor-action').forEach(button => {
        if (!button.disabled) button.addEventListener('click', event => { event.stopPropagation(); this._handleShopVendorAction(button.dataset.actionId); });
      });
      container.appendChild(stalls);
    } else {
      if (marketTitle) marketTitle.textContent = '官坊 · 明码回购';
      const actions = typeof shopSystem !== 'undefined' ? shopSystem.getVendorActions?.() || [] : [];
      if (actions.length) {
        const services = document.createElement('div');
        services.className = 'shop-regulated-services';
        services.innerHTML = actions.map(action => `<button class="shop-vendor-action" data-action-id="${action.actionId}" ${action.available ? '' : 'disabled'} title="${action.description}">${action.available ? action.label : action.disabledReason}</button>`).join('');
        services.querySelectorAll('.shop-vendor-action').forEach(button => {
          if (!button.disabled) button.addEventListener('click', event => { event.stopPropagation(); this._handleShopVendorAction(button.dataset.actionId); });
        });
        container.appendChild(services);
      }
    }

    if (!items || items.length === 0) {
      const empty = document.createElement('div');
      empty.className = 'shop-empty-state';
      empty.textContent = '今日无货。';
      container.appendChild(empty);
      return;
    }

    for (const item of items) {
      const price = item.displayPrice || item.price;
      const costModes = typeof shopSystem !== 'undefined' && shopSystem?.getOfferCostModes
        ? shopSystem.getOfferCostModes(item.id)
        : [];
      const canAfford = costModes.length > 0
        ? costModes.some(mode => mode.available)
        : (typeof shopSystem !== 'undefined' && shopSystem?.canAffordOffer
          ? shopSystem.canAffordOffer(item.id)
          : gameState.resources.spiritStone >= price);
      const costText = costModes.length > 0
        ? '两种易手条件'
        : (typeof shopSystem !== 'undefined' && shopSystem?.formatCostSpec
          ? shopSystem.formatCostSpec(item)
          : `${price} 灵石`);
      const alternatives = typeof shopSystem !== 'undefined' && shopSystem?.getStoryAlternatives
        ? shopSystem.getStoryAlternatives(item.id)
        : [];
      const hasAvailableAlternative = alternatives.some(option => option.available);
      const el = document.createElement('div');

      // 稀有度样式
      const rarityClass = item.rarityName ? ' shop-item-rarity-' + item.rarity : '';
      el.className = 'shop-item' + (canAfford || hasAvailableAlternative ? '' : ' disabled') + rarityClass + (item._marketItem ? ' market-item' : '') + (item.stallId ? ' bazaar-offer' : '');
      if (item.stallId) el.dataset.stallId = item.stallId;
      el.dataset.itemKind = item.type || 'misc';

      // 类型标签
      const typeLabel = item.typeLabel || (item.type === 'pill' ? '丹药' :
        item.type === 'treasure' ? '法宝' : item.type === 'card' ? '功法' : item.type === 'npc_favor' ? '人情' : '杂物');
      const rarityName = item.rarityName || '';
      const hiddenTrait = item.hiddenTrait?.status === 'sealed'
        ? `<div class="shop-hidden-trait is-sealed">封签未知：${item.hiddenTrait.inspection || '此物的来路尚未验明。'}</div>`
        : item.hiddenTrait?.status === 'revealed'
          ? `<div class="shop-hidden-trait is-revealed">封签验明：${item.hiddenTrait.revealedText || '来路已记入本次契约。'}</div>`
          : '';
      const visibleDescription = [item.desc, item.relationHint].filter(Boolean).join(' ');

      el.innerHTML = `
        <div class="shop-item-header">
          <span class="shop-item-name">${rarityName ? '<span class="rarity-badge">' + rarityName + '</span> ' : ''}${item.name}</span>
          <span class="shop-item-price">${costText}</span>
        </div>
        <div class="shop-item-desc">${visibleDescription}</div>
        ${hiddenTrait}
        <div class="shop-item-type">${typeLabel}</div>
        ${costModes.length > 0 ? `<div class="shop-story-alternatives shop-cost-modes">
          ${costModes.map(mode => `<button class="shop-buy-btn shop-cost-mode" data-item-id="${item.id}" data-cost-mode-id="${mode.id}" ${mode.available ? '' : 'disabled'} title="${mode.disabledReason || ''}">${mode.available ? mode.label : `${mode.label} · ${mode.disabledReason || '不可用'}`}</button>`).join('')}
        </div>` : `<button class="shop-buy-btn" data-item-id="${item.id}" ${canAfford ? '' : 'disabled'}>
          ${canAfford ? (marketType === 'ghost' && Array.isArray(item.costSpec) ? '签下契约' : marketType === 'public_bazaar' && Array.isArray(item.costSpec) ? '以物易物' : '购买') : '代价不足'}
        </button>`}
        ${alternatives.length > 0 ? `<div class="shop-story-alternatives">
          ${alternatives.map(option => `<button class="shop-story-action" data-item-id="${item.id}" data-alternative-id="${option.id}" ${option.available ? '' : 'disabled'} title="${option.available ? option.description || '' : option.disabledReason || ''}">
            ${option.label}${option.available ? '' : ` · ${option.disabledReason || '不可用'}`}
          </button>`).join('')}
        </div>` : ''}
      `;

      el.querySelectorAll('.shop-buy-btn').forEach(buyBtn => {
        if (buyBtn.disabled) return;
        buyBtn.addEventListener('click', (e) => {
          e.stopPropagation();
          this._handleShopBuy(item.id, buyBtn.dataset.costModeId || null);
        });
      });
      el.querySelectorAll('.shop-story-action').forEach(button => {
        if (button.disabled) return;
        button.addEventListener('click', event => {
          event.stopPropagation();
          this._handleShopStoryAlternative(button.dataset.itemId, button.dataset.alternativeId);
        });
      });

      container.appendChild(el);
    }
  }

  _renderShopArrivalAnchor(marketData, marketType) {
    const anchor = document.getElementById('shop-arrival-anchor');
    if (!anchor) return;
    anchor.hidden = true;
    anchor.textContent = '';
    if (marketType !== 'regulated') return;

    const entryCardId = marketData?.session?.entryCardId || marketData?.entryCardId;
    const cardApi = this.game?.cardSystem || (typeof cardSystem !== 'undefined' ? cardSystem : null);
    const resolveCard = id => (typeof cardApi?.getCard === 'function' && typeof id === 'string')
      ? cardApi.getCard(id)
      : null;
    const entryCard = resolveCard(entryCardId);
    const history = this._getGameState()?.choiceHistory;
    const routeRecord = Array.isArray(history)
      ? [...history].reverse().find(record => Array.isArray(record?.tags) && record.tags.includes('route'))
      : null;
    const routeCard = resolveCard(routeRecord?.cardId);
    if (!routeCard?.title || !entryCard?.title) return;

    const vendorId = marketData?.session?.vendorId || marketData?.vendorId;
    const vendorChoice = Object.values(entryCard.choices || {}).find(choice => (
      choice?.action?.type === 'ENTER_VENDOR' && choice.action.vendorId === vendorId
    ));
    const vendorLabel = typeof vendorChoice?.text === 'string' ? vendorChoice.text.trim() : '';
    anchor.textContent = `${routeCard.title} → ${entryCard.title}${vendorLabel ? ` · ${vendorLabel}` : ''}`;
    anchor.hidden = false;
  }

  _handleShopBuy(itemId, costModeId = null) {
    if (typeof shopSystem === 'undefined' || !shopSystem) return;

    const result = shopSystem.purchase(itemId, costModeId);
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
      this._renderShopItems(shopSystem.getActiveOffers ? shopSystem.getActiveOffers() : [], this._shopRenderData);
    }

    // 显示结果
    // Results carry the resolved offer.  Never expose the internal offer id in
    // the player receipt; it breaks the market's authored voice (most visibly
    // for a bazaar barter) and makes a successful transaction look debug-only.
    let msg = result.message || `购买了 ${result.item?.name || itemId}`;
    if (!result.debt && result.result) {
      if (result.result.type === 'pill') msg = `获得丹药：${result.result.pillId}`;
      else if (result.result.type === 'treasure') msg = `获得法宝：${result.result.treasureId}`;
      else if (result.result.type === 'card') msg = `已将【${result.result.deckCard}】吸纳入识海牌组中`;
      else if (result.result.type === 'heal') msg = `恢复气血 ${result.result.amount}`;
    }
    this._showShopToast(msg);

    // 重新渲染游戏界面（灵石等可能变化）
    this.renderGame();
  }

  _handleShopStoryAlternative(itemId, alternativeId) {
    if (typeof shopSystem === 'undefined' || !shopSystem?.resolveStoryAlternative) return;
    const result = shopSystem.resolveStoryAlternative(itemId, alternativeId);
    this._showShopToast(result.message || (result.success ? '交换完成' : '交换失败'));
    if (!result.success) return;
    if (result.resolution === 'sect_loan') {
      this._closeShop();
      return;
    }
    const spiritEl = document.getElementById('shop-spirit-stone-val');
    if (spiritEl) spiritEl.textContent = gameState.resources.spiritStone;
    const panel = document.getElementById('shop-panel');
    if (panel?.style.display !== 'none') this._renderShopItems(shopSystem.getActiveOffers(), this._shopRenderData);
  }

  _handleShopVendorAction(actionId) {
    if (typeof shopSystem === 'undefined' || !shopSystem?.executeVendorAction) return;
    const result = shopSystem.executeVendorAction(actionId);
    this._showShopToast(result.message || (result.success ? '交易已记账' : '操作失败'));
    if (!result.success) return;
    const spiritEl = document.getElementById('shop-spirit-stone-val');
    if (spiritEl) spiritEl.textContent = gameState.resources.spiritStone;
    const panel = document.getElementById('shop-panel');
    if (panel?.style.display !== 'none') this._renderShopItems(shopSystem.getActiveOffers(), this._shopRenderData);
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

  // ============ 删牌弹窗 ============
  showRemoveCardScreen() {
    const panel = document.getElementById('remove-card-panel');
    const container = document.getElementById('remove-card-container');
    const closeBtn = document.getElementById('remove-card-close');
    const deckAuthority = this.game?.skillCardAcquisitionSystem
      || (typeof skillCardAcquisitionSystem !== 'undefined' ? skillCardAcquisitionSystem : null);
    if (!panel || !container || !deckAuthority) return;

    container.innerHTML = '';
    const deck = gameState.deck || [];

    if (deck.length === 0) {
      container.innerHTML = '<p style="color:#888;">你的识海空无一物，无需斩除。</p>';
    } else {
      deck.forEach((cardId, index) => {
        const preview = deckAuthority.getRemovalPreview(index);
        const cardData = preview.card || deckAuthority.getCardDefinition(cardId) || {
          name: cardId,
          description: '未知卡牌'
        };
        const reasonText = {
          minimum_deck_size: `至少保留 ${preview.minimumDeckSize} 张牌`,
          insufficient_spirit_stone: `灵石不足，需要 ${preview.cost}`,
          invalid_index: '牌组位置已变化'
        }[preview.reason] || '';

        const cardEl = document.createElement('div');
        cardEl.className = 'shop-item';
        cardEl.style.cursor = preview.allowed ? 'pointer' : 'not-allowed';
        cardEl.setAttribute('aria-disabled', preview.allowed ? 'false' : 'true');
        cardEl.innerHTML = `
          <div class="shop-item-name">${cardData.name || cardId}</div>
          <div class="shop-item-desc">${this._narrativeHtml(cardData.description || cardData.desc || '')}</div>
          <div style="margin-top:5px; font-size:12px; color:${preview.allowed ? '#ff7a70' : '#888'};">
            ${preview.allowed
              ? `[斩除：${preview.cost} 灵石 · 牌组 ${deck.length} → ${deck.length - 1}]`
              : `[不可斩除：${reasonText}]`}
          </div>
        `;

        cardEl.onclick = preview.allowed ? () => {
          const result = deckAuthority.removeCardAt(index);
          if (!result.success) {
            this._showShopToast(`斩除失败：${result.reason}`);
            return;
          }
          this._showShopToast(`已斩除【${cardData.name || cardId}】，消耗 ${preview.cost} 灵石`);
          panel.style.display = 'none';
          this.renderGame();
        } : null;
        container.appendChild(cardEl);
      });
    }

    if (closeBtn) closeBtn.onclick = () => {
      panel.style.display = 'none';
      this.renderGame();
    };

    panel.style.display = 'flex';
  }

  // ============ 强化牌弹窗 ============
  showUpgradeCardScreen() {
    const panel = document.getElementById('upgrade-card-panel');
    const container = document.getElementById('upgrade-card-container');
    const closeBtn = document.getElementById('upgrade-card-close');
    const deckAuthority = this.game?.skillCardAcquisitionSystem
      || (typeof skillCardAcquisitionSystem !== 'undefined' ? skillCardAcquisitionSystem : null);
    if (!panel || !container || !deckAuthority) return;

    container.innerHTML = '';
    const deck = gameState.deck || [];

    // 过滤出未升级的牌
    const upgradable = deck.map((cardId, index) => {
       const isUpgraded = typeof cardId === 'string' && cardId.endsWith('+');
       return { cardId, index, isUpgraded };
    }).filter(item => !item.isUpgraded);

    if (upgradable.length === 0) {
      container.innerHTML = '<p style="color:#888;">你的识海中没有可参悟的功法。</p>';
    } else {
      upgradable.forEach(item => {
        const { cardId, index } = item;
        const preview = deckAuthority.getUpgradePreview(index);
        const cardData = preview.before || deckAuthority.getCardDefinition(cardId) || {
          name: cardId,
          description: '未知卡牌'
        };
        const upgradedData = preview.after || null;
        const reasonText = {
          insufficient_spirit_stone: `灵石不足，需要 ${preview.cost}`,
          already_upgraded: '本世已强化',
          unknown_card: '卡牌定义缺失',
          invalid_index: '牌组位置已变化'
        }[preview.reason] || '';

        const cardEl = document.createElement('div');
        cardEl.className = 'shop-item';
        cardEl.style.cursor = preview.allowed ? 'pointer' : 'not-allowed';
        cardEl.setAttribute('aria-disabled', preview.allowed ? 'false' : 'true');
        cardEl.innerHTML = `
          <div class="shop-item-name">${cardData.name || cardId}</div>
          <div class="shop-item-desc">${this._narrativeHtml(cardData.description || cardData.desc || '')}</div>
          ${upgradedData
            ? `<div class="shop-item-desc" style="color:#aee6b2;">→ ${this._narrativeHtml(upgradedData.description || upgradedData.desc || '')}</div>`
            : ''}
          <div style="margin-top:5px; font-size:12px; color:${preview.allowed ? '#73d58b' : '#888'};">
            ${preview.allowed
              ? `[参悟：${preview.cost} 灵石 · 费用保持 ${cardData.cost}]`
              : `[不可参悟：${reasonText}]`}
          </div>
        `;

        cardEl.onclick = preview.allowed ? () => {
          const result = deckAuthority.upgradeCardAt(index);
          if (!result.success) {
            this._showShopToast(`参悟失败：${result.reason}`);
            return;
          }
          this._showShopToast(`已强化【${cardData.name || cardId}】，消耗 ${preview.cost} 灵石`);
          panel.style.display = 'none';
          this.renderGame();
        } : null;
        container.appendChild(cardEl);
      });
    }

    if (closeBtn) closeBtn.onclick = () => {
      panel.style.display = 'none';
      this.renderGame();
    };

    panel.style.display = 'flex';
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
    yin_xue: 'assets/cards/characters/card_yinxue_pc98.png',
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

  setPortraitPresentationResolver(resolver) {
    this._portraitPresentationResolver = resolver || null;
  }

  _resolvePortraitPresentation(npcId, stage = null, surface = 'card') {
    const resolved = this._portraitPresentationResolver?.resolvePortraitPresentation?.(npcId, {
      stage,
      surface
    });
    if (resolved?.asset) return resolved;

    const fallbackAsset = this._getNpcPortrait(npcId);
    return {
      npcId,
      stageId: stage?.id || null,
      asset: stage?.asset || fallbackAsset,
      fallbackAsset,
      renderer: 'static',
      pixelated: false,
      surface,
      transitionPreset: 'portrait-settle'
    };
  }

  _beginPortraitRender(container) {
    if (!container) return 0;
    const requestId = (Number(container._portraitRequestId) || 0) + 1;
    container._portraitRequestId = requestId;
    return requestId;
  }

  _isPortraitRenderCurrent(container, requestId) {
    return !!container && container._portraitRequestId === requestId;
  }

  _retirePortraitLayer(layer) {
    if (!layer || typeof layer.remove !== 'function') return;
    const reducedMotion = window.matchMedia?.('(prefers-reduced-motion: reduce)')?.matches;
    if (reducedMotion || typeof layer.addEventListener !== 'function') {
      requestAnimationFrame(() => layer.remove());
      return;
    }
    let retired = false;
    let safetyTimer = null;
    const retire = event => {
      if (event && event.target !== layer) return;
      if (retired) return;
      retired = true;
      if (safetyTimer !== null) clearTimeout(safetyTimer);
      layer.remove();
    };
    layer.addEventListener('transitionend', retire, { once: true });
    layer.addEventListener('transitioncancel', retire, { once: true });
    // display:none or detached ancestors do not consistently dispatch an end
    // event, so keep a bounded cleanup guard beyond the 220ms motion contract.
    safetyTimer = setTimeout(() => retire(), 360);
    safetyTimer?.unref?.();
  }

  _commitPortraitLayer(container, layer, requestId) {
    if (!this._isPortraitRenderCurrent(container, requestId)) return false;

    const oldLayers = Array.from(container.querySelectorAll('.portrait-stage-layer'));
    container.appendChild(layer);
    container.classList?.add('has-portrait-presentation');
    container.classList?.add('is-portrait-transitioning');

    requestAnimationFrame(() => {
      if (!this._isPortraitRenderCurrent(container, requestId)) {
        layer.remove();
        return;
      }
      layer.classList.add('is-active');
      oldLayers.forEach(oldLayer => {
        oldLayer.classList.remove('is-active');
        oldLayer.classList.add('is-leaving');
        this._retirePortraitLayer(oldLayer);
      });
    });

    if (typeof layer.addEventListener === 'function') {
      let settled = false;
      let settleTimer = null;
      const settle = event => {
        if (event && event.target !== layer) return;
        if (settled) return;
        settled = true;
        if (settleTimer !== null) clearTimeout(settleTimer);
        container.classList?.remove('is-portrait-transitioning');
      };
      layer.addEventListener('transitionend', settle, { once: true });
      layer.addEventListener('transitioncancel', settle, { once: true });
      settleTimer = setTimeout(() => settle(), 360);
      settleTimer?.unref?.();
    }
    return true;
  }

  _loadPortraitImage(assetPath) {
    return new Promise((resolve, reject) => {
      const img = new Image();
      img.onload = () => resolve(img);
      img.onerror = () => reject(new Error(`Portrait asset failed to load: ${assetPath}`));
      img.src = assetPath;
    });
  }

  _createPortraitLayer(presentation, img, altText) {
    const layer = document.createElement('div');
    layer.className = 'portrait-stage-layer';
    layer.dataset.renderer = presentation.renderer || 'static';
    layer.dataset.stageId = presentation.stageId || '';
    layer.dataset.assetWidth = String(img.naturalWidth || img.width || 0);
    layer.dataset.assetHeight = String(img.naturalHeight || img.height || 0);

    img.alt = altText || presentation.npcId || 'portrait';
    img.className = presentation.renderer === 'pc98' ? 'pc98-card-img' : 'portrait-stage-img';

    if (presentation.renderer === 'pc98') {
      const wrapper = document.createElement('div');
      wrapper.className = 'pc98-card-wrapper';
      wrapper.appendChild(img);

      const frame = document.createElement('div');
      frame.className = 'pc98-pixel-frame';
      wrapper.appendChild(frame);

      const scanlines = document.createElement('div');
      scanlines.className = 'pc98-scanlines';
      wrapper.appendChild(scanlines);
      layer.appendChild(wrapper);
    } else {
      layer.appendChild(img);
    }
    return layer;
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
    container._portraitNpcId = npcId;
    const gen = this._portraitGen; // 捕获当前渲染代际，防止异步竞态覆盖
    try {
      if (this._portraitGen !== gen) return;
      // 清除非 sceneBackdrop 的子元素（保留场景底图层）
      Array.from(container.children).forEach(el => {
        if (!el.classList.contains('card-scene-backdrop')) el.remove();
      });

      // 检查是否有已解锁的立绘阶段
      const unlocked = this._getContextualPortraitStages(npcId);
      if (unlocked.length > 0) {
        const selected = this._resolvePortraitStage(npcId);
        const selectedIndex = unlocked.findIndex(stage => stage.id === selected?.id);
        const portraitIndex = selectedIndex >= 0 ? selectedIndex : unlocked.length - 1;
        container._portraitIndex = portraitIndex;
        const stage = unlocked[portraitIndex];
        const committed = await this._renderCardPortraitForStage(npcId, container, stage).catch(err => {
          if (this._portraitGen !== gen) return;
          console.warn('[UI] Stage portrait render failed, falling back:', err);
          this._fallbackCardPortrait(container, npcId);
        });
        if (this._portraitGen !== gen || committed === false) return;
        this._renderStageIndicator(container, npcId, unlocked, portraitIndex);
        this._initPortraitSwipe(npcId, container);
      } else {
        if (this._portraitGen !== gen) return;
        // 非道侣或无阶段数据 — 使用 LitPixel 基础角色
        const directPresentation = this._resolvePortraitPresentation(npcId, null, 'card');
        if (directPresentation.renderer === 'pc98') {
          await this._renderCardPortraitForStage(npcId, container, null);
        } else {
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
      if (container === this.cardPortrait) this._updatePortraitSwitchBtn(npcId);
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
      return `<button type="button" class="npc-list-card" data-npc="${npc.id}" aria-label="查看${npc.name}">
        <img class="npc-list-avatar-img" src="${src}" alt="${npc.name}">
        <span class="npc-list-name">${npc.name}</span>
        <span class="npc-list-title">${npc.title}</span>
        ${isComp ? '<span class="npc-list-comp-badge">道侣</span>' : ''}
      </button>`;
    }).join('');

    // 点击NPC卡片打开人物面板
    container.querySelectorAll('.npc-list-card').forEach(card => {
      card.addEventListener('click', () => {
        const npcId = card.dataset.npc;
        document.getElementById('npc-list-panel').style.display = 'none';
        this._leaveTopbarPanel('npc-list-panel', 'npc-list-btn', false);
        this.openNpcPanel(npcId);
      });
    });

    document.getElementById('npc-list-panel').style.display = 'flex';
    this._enterTopbarPanel('npc-list-panel', 'npc-list-close', 'npc-list-btn');
  }

  /**
   * 打开 NPC 人物面板
   */
  async openNpcPanel(npcId) {
    const panel = document.getElementById('npc-panel');
    this._npcPanelReturnFocus = document.activeElement?.getClientRects?.().length
      ? document.activeElement : document.getElementById('npc-list-btn');
    // 请求面板数据（once 自动清理，无需 manual off）
    let panelData = null;
    const handler = (data) => { panelData = data; };
    eventBus.once('npc:panelData', handler);
    eventBus.emit('npc:getPanelData', { npcId });

    if (!panelData || panelData.error) return;

    const d = panelData;
    const isComp = npcSystem.isCompanion(npcId);
    const bondNames = ['陌路','相识','挚友','知己','生死','天命'];
    const lifecycleLabels = {
      ACTIVE: '在世', DISTANT: '远行', ASCENDED: '已飞升',
      RETIRED: '已退隐', DEAD: '已身死', UNMET: '未相识'
    };

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
    const npcSubtitle = d.growth
      ? `${d.growth.title} · ${d.growth.npcRealm || '境界未知'}`
      : (d.npc.title || '');
    document.getElementById('npc-subtitle').textContent = d.canInteract
      ? npcSubtitle
      : `${npcSubtitle} · ${lifecycleLabels[d.lifecycle] || d.lifecycle} · 仅可回响`;
    document.getElementById('npc-relationship').textContent =
      `${d.impression.overall} | 好感:${d.affection} | 羁绊:${bondNames[d.bond]} | 状态:${lifecycleLabels[d.lifecycle] || d.lifecycle}`;

    // Mood
    document.getElementById('npc-emotion').textContent = d.emotion;
    document.getElementById('npc-mindset').textContent = d.mindset;
    document.getElementById('npc-location').textContent = d.location;

    // Dialogue
    const dialogue = d.canInteract ? npcSystem.getDialogue(npcId, '闲聊') : '';
    document.getElementById('npc-dialogue').textContent = d.canInteract
      ? (dialogue ? `"${dialogue}"` : '...')
      : '此刻无法当面交谈；后续只会通过书信、遗物、残魂或上界投影形成专用回响。';

    // 交互按钮可见性
    document.querySelectorAll('#npc-panel .npc-action-btn').forEach(btn => {
      const action = btn.dataset.action;
      if (action === '告辞') { btn.style.display = 'inline-block'; return; }
      if (!d.canInteract) { btn.style.display = 'none'; return; }
      if (action === '赠礼' && d.affection < 0) { btn.style.display = 'none'; return; }
      btn.style.display = d.availableActions.includes(action) ? 'inline-block' : 'none';
    });

    // 交互记录
    const interDiv = document.getElementById('npc-interactions');
    if (d.recentInteractions.length === 0) {
      interDiv.innerHTML = '<div class="npc-detail-item dim">暂无互动记录</div>';
    } else {
      interDiv.innerHTML = d.recentInteractions.map(m =>
        `<div class="npc-detail-item">第${m.turn}次决断 · ${m.action}: ${m.reaction}</div>`
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
    this._renderGiftInventory('npc-gift-select', 'npc-panel');

    // 记录当前打开的NPC ID
    panel.dataset.npcId = npcId;
    panel.dataset.lifecycle = d.lifecycle || 'ACTIVE';
    panel.style.display = 'flex';
    document.getElementById('npc-panel-close')?.focus();
  }

  /**
   * NPC 交互按钮处理
   */
  _renderGiftInventory(selectId, panelId) {
    const select = document.getElementById(selectId);
    const panel = document.getElementById(panelId);
    if (!select || !panel) return;
    const previous = select.value;
    select.replaceChildren();
    const entries = Object.entries(gameState.itemInventory || {})
      .filter(([, quantity]) => Number(quantity) > 0)
      .sort(([left], [right]) => left.localeCompare(right, 'zh-CN'));
    if (entries.length === 0) {
      const option = document.createElement('option');
      option.value = '';
      option.textContent = '暂无礼物（可在商店购得）';
      select.appendChild(option);
    } else {
      for (const [itemId, quantity] of entries) {
        const option = document.createElement('option');
        option.value = itemId;
        option.textContent = `${itemId} × ${quantity}`;
        select.appendChild(option);
      }
      if (entries.some(([itemId]) => itemId === previous)) select.value = previous;
    }
    const giftButton = panel.querySelector('[data-action="赠礼"]');
    if (giftButton) {
      giftButton.disabled = entries.length === 0;
      giftButton.setAttribute('aria-disabled', String(entries.length === 0));
    }
  }

  handleNpcAction(action) {
    const panel = document.getElementById('npc-panel');
    const npcId = panel.dataset.npcId;
    if (!npcId) return;

    if (action === '告辞') {
      window.litPixelRenderer?.stopLightAnimation();
      panel.style.display = 'none';
      return;
    }

    const itemId = action === '赠礼' ? document.getElementById('npc-gift-select')?.value : null;
    eventBus.emit('npc:interact', { npcId, action, itemId });
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
    const lifecycleLabels = {
      ACTIVE: '在世', DISTANT: '远行', ASCENDED: '已飞升',
      RETIRED: '已退隐', DEAD: '已身死', UNMET: '未相识'
    };

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
    document.getElementById('comp-subtitle').textContent = d.canInteract
      ? d.title
      : `${d.title} · ${lifecycleLabels[d.lifecycle] || d.lifecycle} · 仅可回响`;
    document.getElementById('comp-emotion').textContent = d.emotion;
    document.getElementById('comp-location').textContent = d.location;

    // 好感/羁绊/信任条
    document.getElementById('comp-aff-bar').style.width = Math.max(0, d.affection) + '%';
    document.getElementById('comp-aff-val').textContent = d.affection;
    document.getElementById('comp-bond-bar').style.width = (d.bond / 5 * 100) + '%';
    document.getElementById('comp-bond-val').textContent = 'Lv' + d.bond + ' ' + bondNames[d.bond];
    document.getElementById('comp-trust-bar').style.width = d.trust + '%';
    document.getElementById('comp-trust-val').textContent = d.trust;

    // 道侣台词
    const dialogue = d.canInteract ? npcSystem.getDialogue(compId, '修炼') : '';
    document.getElementById('comp-dialogue').textContent = d.canInteract
      ? (dialogue ? `"${dialogue}"` : '...')
      : '此人已不在现世，不能继续使用实体互动。';

    // 事件历史
    const eventsDiv = document.getElementById('comp-events');
    if (!d.recentEvents || d.recentEvents.length === 0) {
      eventsDiv.innerHTML = '<div class="npc-detail-item dim">暂无道侣事件</div>';
    } else {
      eventsDiv.innerHTML = d.recentEvents.map(m =>
        `<div class="npc-detail-item">第${m.turn}次决断 · ${m.action || '互动'}: ${m.reaction || ''}</div>`
      ).join('');
    }

    document.getElementById('comp-result').style.display = 'none';
    this._renderGiftInventory('comp-gift-select', 'companion-panel');
    panel.dataset.compId = compId;
    panel.dataset.lifecycle = d.lifecycle || 'ACTIVE';
    document.querySelectorAll('#companion-panel .npc-action-btn').forEach(btn => {
      btn.style.display = d.canInteract || btn.dataset.action === '告辞' ? 'inline-block' : 'none';
    });
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
      eventBus.emit('companion:gift', { compId, itemId: document.getElementById('comp-gift-select')?.value || '' });
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
  _isHeavenlyMode() {
    return typeof experienceSettings !== 'undefined' && experienceSettings.get('heavenlyMode') === true;
  }

  _loadPortraitStages() {
    if (this._portraitStagesData) return this._portraitStagesData;
    // 从 DataLoader 尝试加载，失败则从 DATA_MODULES 读取
    try {
      const raw = dataLoader ? dataLoader.loadSync('companions:portrait_stages') : null;
      if (raw && raw.portraitStages) {
        this._portraitStagesData = raw;
        if (typeof companionSystem !== 'undefined') companionSystem.loadPortraitData?.(raw);
        return raw;
      }
    } catch (e) {}
    // 备用：内联数据
    if (typeof DATA_MODULES !== 'undefined' && DATA_MODULES['companions:portrait_stages']) {
      this._portraitStagesData = DATA_MODULES['companions:portrait_stages'];
      if (typeof companionSystem !== 'undefined') companionSystem.loadPortraitData?.(this._portraitStagesData);
      return this._portraitStagesData;
    }
    return { portraitStages: {} };
  }

  /**
   * 打开万物志面板
   */
  openBestiary() {
    if (this._isHeavenlyMode() && this._heavenlyGallery) { this._heavenlyGallery.open(); return; }
    const panel = document.getElementById('bestiary-panel');
    panel.style.display = 'flex';
    this._hidePortraitViewer({ restoreFocus: false });
    this._switchBestiaryTab('companions');
    this._enterTopbarPanel('bestiary-panel', 'bestiary-close', 'bestiary-btn');
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
      // loadData 会为全部定义创建运行时状态；只有资源列表才代表真实结缘。
      const isCompanion = companionIds.includes(compId);
      const affection = isCompanion ? this._resolvePortraitAffection(compId) : 0;

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
      const firstUnlocked = typeof companionSystem !== 'undefined'
        ? companionSystem.resolveSelectedPortrait?.(compId, { affection, allowIntimate: true })
        : compStages.stages.filter(s => s.affection <= affection).pop();
      const thumbSrc = firstUnlocked?.asset || this._getNpcPortrait(compId);

      const lockClass = isCompanion ? '' : 'locked';

      return `
        <button type="button" class="bestiary-companion-card ${lockClass}" data-comp="${compId}" aria-label="查看${compStages.name}立绘">
          <span class="bestiary-comp-thumb">
            <img src="${thumbSrc}" alt="${compStages.name}">
          </span>
          <span class="bestiary-comp-info">
            <span class="bestiary-comp-name">${compStages.name} ${isCompanion ? '♥' : ''}</span>
            <span class="bestiary-comp-title">立绘 ${unlockedCount}/${totalStages}</span>
            <span class="bestiary-comp-stages">${dots}</span>
          </span>
          <span class="bestiary-comp-arrow">${isCompanion ? '→' : '🔒'}</span>
        </button>`;
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
    const treasures = typeof treasureSystem !== 'undefined'
      && typeof treasureSystem?.getOwnedInstanceIds === 'function'
      ? treasureSystem.getOwnedInstanceIds()
      : (typeof treasureSystem !== 'undefined' && typeof treasureSystem?.getOwnedIds === 'function'
        ? treasureSystem.getOwnedIds()
        : (gameState.resources.treasures || []));
    if (treasures.length === 0) {
      treasuresDiv.innerHTML = '<div class="bestiary-locked-hint">尚未获得任何法宝。探索秘境、完成支线可获得法宝。</div>';
    } else {
      const typeIcons = { weapon: '⚔️', armor: '🛡️', accessory: '📿', artifact: '🔮' };
      const slotNames = { weapon: '武器位', armor: '防具位', accessory: '饰品位', artifact: '秘宝位' };
      treasuresDiv.innerHTML = treasures.map(treasureId => {
        const item = typeof treasureSystem !== 'undefined'
          ? treasureSystem?.getTreasureData?.(treasureId)
          : null;
        const equippedSlot = Object.entries(gameState.equipment || {})
          .find(([, id]) => id === treasureId)?.[0] || null;
        return `
          <div class="bestiary-item-card">
            <div class="bestiary-item-icon">${typeIcons[item?.type] || '🔮'}</div>
            <div class="bestiary-item-name">${item?.name || treasureId}</div>
            <div class="bestiary-item-status">${equippedSlot ? `已装备 · ${slotNames[equippedSlot]}` : '背包中'}</div>
            <div class="bestiary-item-desc">${item?.desc || '这件器物的来历仍待考证。'}</div>
          </div>
        `;
      }).join('');
    }

    // 丹药
    const pillsDiv = document.getElementById('bestiary-pills');
    const pillCounts = gameState.resources.pills && typeof gameState.resources.pills === 'object'
      && !Array.isArray(gameState.resources.pills)
      ? gameState.resources.pills
      : {};
    const pillNames = { foundation: '筑基丹', golden: '结金丹', nascent: '凝婴丹', deity: '化神丹', tribulation: '渡劫丹' };
    const pills = Object.entries(pillCounts)
      .map(([id, count]) => [id, Math.floor(Number(count) || 0)])
      .filter(([id, count]) => Boolean(id) && count > 0);
    if (pills.length === 0) {
      pillsDiv.innerHTML = '<div class="bestiary-locked-hint">尚未获得任何丹药。可在商店购买或通过支线任务获得。</div>';
    } else {
      pillsDiv.innerHTML = pills.map(([pillId, count]) => `
        <div class="bestiary-item-card">
          <div class="bestiary-item-icon">💊</div>
          <div class="bestiary-item-name">${pillNames[pillId] || pillId} <span class="bestiary-item-count">× ${count}</span></div>
          <div class="bestiary-item-desc">当前持有 ${count} 枚。突破丹用于应对境界考验，其他丹药按其来源效果使用。</div>
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

    // 只通过公开功法 API 读取定义和解锁状态；UI 不拥有第二份技能状态。
    const skills = typeof pathSkillSystem !== 'undefined' && pathSkillSystem
      ? pathSkillSystem.getAllSkills(path) : [];

    if (skills.length === 0) {
      skillsList.innerHTML = '<div class="bestiary-locked-hint">尚未解锁功法技能。突破境界后可解锁对应技能。</div>';
      return;
    }

    skillsList.innerHTML = skills.map(skill => {
      const unlocked = pathSkillSystem.isSkillUnlocked(path, skill, gameState.realm);

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
    const focusedSetId = typeof legacyFragmentSystem !== 'undefined'
      ? legacyFragmentSystem.getFocusedSetId()
      : null;
    const eligibleSetIds = typeof legacyFragmentSystem !== 'undefined'
      ? legacyFragmentSystem.getEligibleSetIds({ path: gameState.path })
      : [];
    const deckAuthority = this.game?.skillCardAcquisitionSystem
      || (typeof skillCardAcquisitionSystem !== 'undefined' ? skillCardAcquisitionSystem : null);

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
      const variant = deckAuthority?.getCardDefinition(set.variantCardId);
      const variantPreview = variant
        ? `本流派绝学：${variant.name}（${variant.cost} 灵力）· ${variant.description || ''}`
        : `本流派绝学：${set.variantCardId || '暂不可用'}`;

      return `
        <div class="fragment-set-card ${set.completed ? 'completed' : ''} ${focusedSetId === setId ? 'focused' : ''}">
          <div class="fragment-set-header">
            <span class="fragment-set-icon">${set.icon}</span>
            <span class="fragment-set-name">${set.name}</span>
            <span class="fragment-set-count">${set.count}/${set.total}</span>
            ${set.completed
              ? `<span class="fragment-set-badge">${set.active ? '✓ 本世已激活' : '✓ 档案已解锁'}</span>`
              : ''}
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
          <div class="fragment-set-effect ${set.completed ? '' : 'locked-effect'}">${set.effect || ''}</div>
          <div class="fragment-set-effect ${set.completed ? '' : 'locked-effect'}">${variantPreview}</div>
          ${!set.completed && eligibleSetIds.includes(setId)
            ? `<button type="button" class="fragment-focus-button ${focusedSetId === setId ? 'active' : ''}"
                data-set-id="${setId}" aria-pressed="${focusedSetId === setId}">
                ${focusedSetId === setId ? '停止追踪' : '追踪此传承（普通掉落 60%）'}
              </button>`
            : ''
          }
        </div>
      `;
    }).join('');

    listEl.querySelectorAll('.fragment-focus-button[data-set-id]').forEach(button => {
      button.addEventListener('click', () => {
        const nextSetId = button.classList.contains('active') ? null : button.dataset.setId;
        const result = this.game.setFocusedLegacySet(nextSetId);
        if (result?.changed) this._renderBestiaryFragments();
      });
    });

    // 渲染已激活的加成
    const bonusEntries = Object.entries(bonuses);
    if (bonusEntries.length > 0) {
      bonusesSection.style.display = 'block';
      const bonusLabels = {
        critRate: '暴击率', pillBonus: '丹药效果',
        combatStartBlock: '开战护盾', daoResist: '道心伤害减免',
        cultivationBonus: '修为正收益', lowHpDamageBonus: '低血量伤害',
        maxHp: '最大气血', maxLifespan: '本世寿元', daoHeartPenalty: '道心上限'
      };
      const percentKeys = new Set(['critRate', 'pillBonus', 'daoResist', 'cultivationBonus']);
      bonusesList.innerHTML = bonusEntries.map(([key, val]) => {
        const label = bonusLabels[key] || key;
        const isPenalty = val < 0;
        const cls = isPenalty ? 'bonus-penalty' : 'bonus-positive';
        const sign = val > 0 ? '+' : '';
        const unit = percentKeys.has(key) ? '%' : '';
        return `<span class="fragment-bonus-tag ${cls}">${label} ${sign}${val}${unit}</span>`;
      }).join('');
    } else {
      bonusesSection.style.display = 'none';
    }
  }

  /**
   * 显示道侣立绘查看器
   */
  _showCompanionPortraits(compId) {
    if (this._isHeavenlyMode() && this._heavenlyGallery) { this._heavenlyGallery.openPortrait(compId); return; }
    this._bestiaryCurrentComp = compId;
    const stagesData = this._loadPortraitStages();
    const compStages = stagesData.portraitStages[compId];
    if (!compStages) return;
    this._bestiaryPortraitReturnFocus = document.activeElement;

    const affection = this._resolvePortraitAffection(compId);

    // 隐藏列表，显示立绘查看器
    document.querySelectorAll('.bestiary-tab-content').forEach(c => c.style.display = 'none');
    document.querySelectorAll('.bestiary-tab').forEach(t => t.classList.remove('active'));
    document.getElementById('bestiary-portrait-viewer').style.display = 'block';
    document.getElementById('bestiary-portrait-back')?.focus();

    // 旧档没有选择时回落到最高已解锁阶段。
    const unlockedStages = compStages.stages.filter(s => s.affection <= affection);
    const selectedStage = typeof companionSystem !== 'undefined'
      ? companionSystem.resolveSelectedPortrait?.(compId, { affection, allowIntimate: true })
      : null;
    const currentStage = selectedStage
      || (unlockedStages.length > 0 ? unlockedStages[unlockedStages.length - 1] : compStages.stages[0]);

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
        <button type="button" class="bestiary-stage-btn ${isActive ? 'active selected' : ''} ${unlocked ? 'unlocked' : 'locked'} ${adultClass}"
                data-stage="${idx}" aria-pressed="${isActive}" ${unlocked ? '' : 'disabled'}
                title="${stage.name} — 好感度${stage.affection}${unlocked ? ' [悬浮预览；点击选用]' : ' [未解锁]'}">
          ${unlocked ? stage.name : '🔒 ' + stage.name + ' ' + lockHint}
        </button>`;
    }).join('');

    const renderSelected = () => {
      const selected = typeof companionSystem !== 'undefined'
        ? companionSystem.resolveSelectedPortrait?.(compId, { affection, allowIntimate: true })
        : currentStage;
      if (selected) this._renderPortraitStage(selected, compId, compStages);
    };

    // 桌面悬浮/键盘焦点只预览；点击或 Enter 才持久选用。
    selector.querySelectorAll('.bestiary-stage-btn').forEach(btn => {
      const preview = () => {
        const stage = compStages.stages[parseInt(btn.dataset.stage)];
        if (stage && stage.affection <= affection) {
          this._renderPortraitStage(stage, compId, compStages, { preview: true });
        }
      };
      btn.addEventListener('mouseenter', preview);
      btn.addEventListener('focus', preview);
      btn.addEventListener('mouseleave', renderSelected);
      btn.addEventListener('blur', renderSelected);
      btn.addEventListener('click', () => {
        const stageIdx = parseInt(btn.dataset.stage);
        const stage = compStages.stages[stageIdx];
        const stageUnlocked = stage.affection <= affection;
        if (!stageUnlocked) return; // 未解锁不可查看

        const result = typeof companionSystem !== 'undefined'
          ? companionSystem.selectPortrait?.(compId, stage.id)
          : { selected: false };
        if (!result?.selected) return;
        selector.querySelectorAll('.bestiary-stage-btn').forEach(b => {
          b.classList.remove('active', 'selected');
          b.setAttribute('aria-pressed', 'false');
        });
        btn.classList.add('active', 'selected');
        btn.setAttribute('aria-pressed', 'true');
        this._renderPortraitStage(stage, compId, compStages);
        this._renderBestiaryCompanions();
      });
    });
  }

  /**
   * 渲染一个具体的立绘阶段
   */
  _renderPortraitStage(stage, compId, compStages, { preview = false } = {}) {
    if (!this._portraitPresentationResolver) {
      const legacyWrap = document.getElementById('bestiary-portrait-canvas')?.parentElement;
      legacyWrap?.classList?.remove('has-portrait-presentation');
      return this._renderPortraitStageLegacy(stage, compId, compStages, { preview });
    }

    const infoDiv = document.getElementById('bestiary-stage-info');
    infoDiv.innerHTML = `
      <div class="bestiary-stage-name">${this._escapeHtml(stage.name)} · ${this._escapeHtml(compStages.name)}${preview ? ' · 预览' : ' · 已选用'}</div>
      <div class="bestiary-stage-narrative">${this._escapeHtml(this._normalizeNarrativeText(stage.narrative)).replace(/\n/g, '<br>')}</div>
      <div>
        <span class="bestiary-stage-pose">${this._narrativeHtml(stage.pose)}</span>
        <span class="bestiary-stage-clothing">${this._narrativeHtml(stage.clothing)}</span>
        <span class="bestiary-stage-atmo">${this._narrativeHtml(stage.atmosphere)}</span>
      </div>
    `;
    if (stage.adultContent) {
      infoDiv.querySelector('.bestiary-stage-name').style.color = '#ff6b6b';
    }

    const sentinel = document.getElementById('bestiary-portrait-canvas');
    const wrap = sentinel?.parentElement;
    if (!sentinel || !wrap) return;

    const requestId = this._beginPortraitRender(wrap);
    const presentation = this._resolvePortraitPresentation(compId, stage, 'bestiary');
    wrap.dataset.renderer = presentation.renderer;
    wrap.dataset.stageId = stage.id;

    const render = async () => {
      let img;
      try {
        img = await this._loadPortraitImage(presentation.asset);
      } catch (error) {
        if (!presentation.fallbackAsset || presentation.fallbackAsset === presentation.asset) throw error;
        img = await this._loadPortraitImage(presentation.fallbackAsset);
      }
      if (!this._isPortraitRenderCurrent(wrap, requestId)) return false;

      const canvas = document.createElement('canvas');
      canvas.className = 'portrait-stage-layer bestiary-portrait-layer';
      canvas.dataset.renderer = presentation.renderer;
      canvas.dataset.stageId = stage.id;
      canvas.width = img.naturalWidth || img.width || 512;
      canvas.height = img.naturalHeight || img.height || 768;
      canvas.dataset.assetWidth = String(canvas.width);
      canvas.dataset.assetHeight = String(canvas.height);
      const ctx = canvas.getContext('2d');
      ctx.imageSmoothingEnabled = !presentation.pixelated;
      ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
      return this._commitPortraitLayer(wrap, canvas, requestId);
    };

    render().catch(error => {
      if (!this._isPortraitRenderCurrent(wrap, requestId)) return;
      console.warn('[Bestiary] Portrait stage render failed:', error);
      const placeholder = document.createElement('canvas');
      placeholder.className = 'portrait-stage-layer bestiary-portrait-layer portrait-placeholder';
      placeholder.width = 512;
      placeholder.height = 768;
      placeholder.dataset.assetWidth = String(placeholder.width);
      placeholder.dataset.assetHeight = String(placeholder.height);
      const ctx = placeholder.getContext('2d');
      ctx.fillStyle = '#080b0d';
      ctx.fillRect(0, 0, placeholder.width, placeholder.height);
      ctx.fillStyle = '#b5ad98';
      ctx.font = '600 24px serif';
      ctx.textAlign = 'center';
      ctx.fillText('立绘暂不可用', placeholder.width / 2, placeholder.height / 2);
      this._commitPortraitLayer(wrap, placeholder, requestId);
    });
  }

  _renderPortraitStageLegacy(stage, compId, compStages, { preview = false } = {}) {
    // 阶段信息
    const infoDiv = document.getElementById('bestiary-stage-info');
    infoDiv.innerHTML = `
      <div class="bestiary-stage-name">${this._escapeHtml(stage.name)} — ${this._escapeHtml(compStages.name)}${preview ? ' · 预览' : ' · 已选用'}</div>
      <div class="bestiary-stage-narrative">${this._escapeHtml(this._normalizeNarrativeText(stage.narrative)).replace(/\n/g, '<br>')}</div>
      <div>
        <span class="bestiary-stage-pose">${this._narrativeHtml(stage.pose)}</span>
        <span class="bestiary-stage-clothing">${this._narrativeHtml(stage.clothing)}</span>
        <span class="bestiary-stage-atmo">${this._narrativeHtml(stage.atmosphere)}</span>
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
  _hidePortraitViewer({ restoreFocus = true } = {}) {
    const wasVisible = document.getElementById('bestiary-portrait-viewer').style.display === 'block';
    document.getElementById('bestiary-portrait-viewer').style.display = 'none';
    this._bestiaryCurrentComp = null;
    // 恢复道侣列表标签
    document.querySelectorAll('.bestiary-tab').forEach(t => t.classList.remove('active'));
    const companionsTab = document.querySelector('.bestiary-tab[data-tab="companions"]');
    if (companionsTab) companionsTab.classList.add('active');
    document.querySelectorAll('.bestiary-tab-content').forEach(c => c.style.display = 'none');
    const compContent = document.getElementById('bestiary-companions');
    if (compContent) compContent.style.display = 'block';
    if (wasVisible && restoreFocus) this._bestiaryPortraitReturnFocus?.focus?.();
    this._bestiaryPortraitReturnFocus = null;
  }

  // ==========================================
  // 卡牌立绘切换
  // ==========================================

  _resolvePortraitCompanionId(npcId) {
    const idAlias = { tian_ji: 'tianji_laoren', xue_sha: 'xuesha_laozu', jiuwei: 'jiuwei_suyue' };
    return idAlias[npcId] || npcId;
  }

  /** 展示层只读 NpcSystem 好感权威值，不合并旧快照或道侣副本。 */
  _resolvePortraitAffection(npcId, explicitAffection = null) {
    const resolvedId = this._resolvePortraitCompanionId(npcId);
    if (typeof npcSystem !== 'undefined' && typeof npcSystem.getAffection === 'function') {
      return npcSystem.getAffection(resolvedId);
    }
    const fallback = Number(explicitAffection);
    return Number.isFinite(fallback) ? fallback : 0;
  }

  _resolvePortraitStage(npcId, options = {}) {
    const affection = this._resolvePortraitAffection(npcId, options.affection);
    const contextualCard = options.card === undefined ? this.game?.currentCard || null : options.card;
    const stages = options.contextual === false
      ? this._getUnlockedPortraitStages(npcId, affection)
      : this._getContextualPortraitStages(npcId, contextualCard, affection);
    if (!stages.length) return null;
    const selected = typeof companionSystem !== 'undefined'
      ? companionSystem.resolveSelectedPortrait?.(npcId, {
          affection,
          allowIntimate: options.contextual === false || this._isIntimatePortraitScene(contextualCard)
        })
      : null;
    return stages.find(stage => stage.id === selected?.id) || stages[stages.length - 1];
  }

  /**
   * 获取当前 NPC 的所有已解锁立绘阶段
   */
  _getUnlockedPortraitStages(npcId, affectionOverride = null) {
    const stagesData = this._loadPortraitStages();
    const resolvedId = this._resolvePortraitCompanionId(npcId);
    const compStages = stagesData.portraitStages[resolvedId];
    if (!compStages) return [];
    const affection = this._resolvePortraitAffection(npcId, affectionOverride);
    if (typeof companionSystem !== 'undefined' && companionSystem.getUnlockedPortraitStages) {
      const resolved = companionSystem.getUnlockedPortraitStages(resolvedId, affection);
      if (resolved.length) return resolved;
    }
    return compStages.stages.filter(s => s.affection <= affection);
  }

  /**
   * 自动立绘遵循剧情门禁；玩家明确装备的已解锁皮肤保留手选。
   */
  _getContextualPortraitStages(npcId, card = this.game?.currentCard || null, affectionOverride = null) {
    const unlocked = this._getUnlockedPortraitStages(npcId, affectionOverride);
    const intimateScene = this._isIntimatePortraitScene(card);
    const selected = typeof companionSystem !== 'undefined'
      ? companionSystem.resolveSelectedPortrait?.(npcId, { affection: affectionOverride }) : null;
    return unlocked.filter(stage => stage.sceneGate !== 'intimate_only' || intimateScene || stage.id === selected?.id);
  }

  _isIntimatePortraitScene(card) {
    const tags = Array.isArray(card?.tags) ? card.tags.map(tag => String(tag).toLowerCase()) : [];
    return !!(card?.portraitScene === 'intimate' || card?.allowIntimatePortrait === true ||
      tags.some(tag => ['intimate', 'romance', 'adult', 'seduction', 'dual_cultivation'].includes(tag)));
  }

  /**
   * 更新卡牌右上角的立绘切换按钮状态
   */
  _updatePortraitSwitchBtn(npcId) {
    const btn = document.getElementById('portrait-switch-btn');
    if (!btn) return;

    const unlocked = this._getContextualPortraitStages(npcId);
    if (unlocked.length > 1) {
      btn.style.display = 'flex';
      btn.classList.add('has-multiple');
      btn.title = `${unlocked.length} 个立绘可切换`;
    } else {
      btn.style.display = 'none';
      btn.classList.remove('has-multiple');
    }
    const selected = this._resolvePortraitStage(npcId);
    const selectedIndex = unlocked.findIndex(stage => stage.id === selected?.id);
    this._cardPortraitIndex = selectedIndex >= 0 ? selectedIndex : unlocked.length - 1;
  }

  /**
   * 循环切换卡牌立绘
   */
  _cycleCardPortrait() {
    const card = this.game.getCurrentCard();
    const npcId = card?.npcId || card?.compId;
    if (!npcId) return;

    const unlocked = this._getContextualPortraitStages(npcId, card);
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
    if (!this._portraitPresentationResolver) {
      return this._renderCardPortraitForStageLegacy(npcId, container, stage);
    }

    const requestId = this._beginPortraitRender(container);
    const presentation = this._resolvePortraitPresentation(npcId, stage, 'card');
    let img;
    try {
      img = await this._loadPortraitImage(presentation.asset);
    } catch (error) {
      if (!presentation.fallbackAsset || presentation.fallbackAsset === presentation.asset) throw error;
      img = await this._loadPortraitImage(presentation.fallbackAsset);
    }
    if (!this._isPortraitRenderCurrent(container, requestId)) return false;

    const layer = this._createPortraitLayer(presentation, img, stage?.name || npcId);
    const committed = this._commitPortraitLayer(container, layer, requestId);
    if (committed) this._showStageNameOverlay(container, stage);
    return committed;
  }

  async _renderCardPortraitForStageLegacy(npcId, container, stage) {
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
    const unlocked = this._getContextualPortraitStages(npcId);
    if (newIndex < 0 || newIndex >= unlocked.length) return;

    const stage = unlocked[newIndex];
    const result = typeof companionSystem !== 'undefined' ? companionSystem.selectPortrait?.(npcId, stage.id) : null;
    if (!result?.selected) return result;
    // The persisted portraitSelected event updates all surfaces exactly once.
    return result;
  }

  /**
   * 初始化触摸/鼠标滑动切换（异环式皮肤浏览）
   */
  _initPortraitSwipe(npcId, container) {
    container._portraitNpcId = npcId;
    if (container._swipeBound) return; // 避免重复绑定
    container._swipeBound = true;

    let startX = 0, startY = 0, isSwiping = false, startedNpcId = null;

    const onStart = (e) => {
      isSwiping = false;
      if (!container._portraitNpcId || this._getContextualPortraitStages(container._portraitNpcId).length <= 1) return;
      // Portrait gestures equip a skin; they must not also choose a story branch.
      e.stopPropagation();
      if (e.target.closest?.('.stage-dot') || e.button > 0) return;
      if (!e.touches) e.preventDefault(); // Native image drag suppresses mouseup.
      startedNpcId = container._portraitNpcId;
      const touch = e.touches ? e.touches[0] : e;
      startX = touch.clientX;
      startY = touch.clientY;
      isSwiping = true;
    };

    const onEnd = (e) => {
      if (!isSwiping) return;
      e.stopPropagation();
      isSwiping = false;
      const touch = e.changedTouches ? e.changedTouches[0] : e;
      const dx = touch.clientX - startX;
      const dy = touch.clientY - startY;

      // 水平滑动优先（|dx| > |dy| 且 |dx| > 30px）
      if (Math.abs(dx) > Math.abs(dy) && Math.abs(dx) > 30) {
        const npcId = container._portraitNpcId;
        if (!npcId || npcId !== startedNpcId) return;
        const unlocked = this._getContextualPortraitStages(npcId);
        if (unlocked.length <= 1) return;

        if (dx < 0) {
          // 左滑 → 下一个阶段
          const next = (container._portraitIndex + 1) % unlocked.length;
          this._switchToStage(npcId, container, next);
        } else {
          // 右滑 → 上一个阶段
          const prev = (container._portraitIndex - 1 + unlocked.length) % unlocked.length;
          this._switchToStage(npcId, container, prev);
        }
      }
    };

    container.addEventListener('touchstart', onStart, { passive: true });
    container.addEventListener('touchmove', e => { if (isSwiping) e.stopPropagation(); }, { passive: true });
    container.addEventListener('touchend', onEnd, { passive: true });
    container.addEventListener('touchcancel', () => { isSwiping = false; }, { passive: true });
    container.addEventListener('mousedown', onStart);
    container.addEventListener('mouseup', onEnd);
  }

  // ============ 道侣沉浸 — CompanionHUD ============

  /**
   * 初始化随身道侣 HUD
   * 由 GameUI.init() 挂载；GameLogic 在 UI 构造完成后通过 attachUI() 取得端口。
   */
  initCompanionHUD() {
    if (this.companionHUD?.container?.isConnected) return this.companionHUD;
    if (!this.companionHUD) this.companionHUD = new CompanionHUD(this);
    this.companionHUD.init();
    return this.companionHUD;
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

  _onCompanionAffectionChange(data) {
    if (!data?.npcId || !this.companionHUD?.activeCompId) return;
    const resolveId = id => ({ jiuwei: 'jiuwei_suyue' }[id] || id);
    if (resolveId(data.npcId) !== resolveId(this.companionHUD.activeCompId)) return;
    this.companionHUD.updateAffection(data.newValue);
  }

  // ==========================================
  //  故事线程 UI
  // ==========================================

  _bindTopbarPanelFocus() {
    const panels = [
      ['npc-list-panel', 'npc-list-close', 'npc-list-btn'],
      ['bestiary-panel', 'bestiary-close', 'bestiary-btn'],
      ['karma-log-modal', 'karma-log-close', 'karma-log-btn'],
      ['evidence-atlas-panel', 'evidence-atlas-close', 'evidence-atlas-btn'],
      ['thread-panel', 'thread-panel-close', 'thread-panel-btn']
    ];
    for (const [panelId, closeId, openerId] of panels) {
      const panel = document.getElementById(panelId);
      const close = document.getElementById(closeId);
      if (!panel || !close) continue;
      panel.addEventListener('keydown', event => {
        if (event.key === 'Escape') {
          event.preventDefault();
          close.click();
          return;
        }
        if (event.key !== 'Tab' || panelId === 'thread-panel') return;
        const focusable = [...panel.querySelectorAll('button:not([disabled]), [href], input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])')]
          .filter(node => node.getClientRects().length && getComputedStyle(node).visibility !== 'hidden');
        if (!focusable.length) {
          event.preventDefault();
          return;
        }
        const first = focusable[0];
        const last = focusable[focusable.length - 1];
        if (event.shiftKey && document.activeElement === first) {
          event.preventDefault();
          last.focus();
        } else if (!event.shiftKey && document.activeElement === last) {
          event.preventDefault();
          first.focus();
        }
      });
      if (panelId === 'thread-panel') continue;
      close.addEventListener('click', () => this._leaveTopbarPanel(panelId, openerId));
      panel.addEventListener('click', event => {
        if (event.target === panel) {
          panel.style.display = 'none';
          this._leaveTopbarPanel(panelId, openerId);
        }
      });
    }
  }

  _enterTopbarPanel(panelId, closeId, openerId) {
    const panel = document.getElementById(panelId);
    if (!panel) return;
    this._topbarPanelOpeners ||= {};
    this._topbarPanelOpeners[panelId] = document.activeElement;
    panel.setAttribute('aria-hidden', 'false');
    (document.getElementById(closeId) || document.getElementById(openerId))?.focus();
  }

  _leaveTopbarPanel(panelId, openerId, restoreFocus = true) {
    const panel = document.getElementById(panelId);
    panel?.setAttribute('aria-hidden', 'true');
    const previous = this._topbarPanelOpeners?.[panelId];
    if (this._topbarPanelOpeners) delete this._topbarPanelOpeners[panelId];
    if (restoreFocus) {
      const target = previous?.isConnected ? previous : document.getElementById(openerId);
      target?.focus?.();
    }
  }

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
        this._closeThreadPanel(false);
      }
    });
  }

  _openThreadPanel() {
    this.threadPanel.style.display = 'flex';
    this._updateThreadPanel();
    this._enterTopbarPanel('thread-panel', 'thread-panel-close', 'thread-panel-btn');
  }

  _closeThreadPanel(restoreFocus = true) {
    this.threadPanel.style.display = 'none';
    this._leaveTopbarPanel('thread-panel', 'thread-panel-btn', restoreFocus);
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
                <div class="thread-item-meta">第 ${s.startedTurn} 次决断 · ${this._phaseLabelFor(s.phase, s.progress)}</div>
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
              <div class="thread-item-meta">第 ${e.turn} 次决断</div>
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
        const pending = allSeeds.filter(s => !s.sprouted);
        if (pending.length === 0) {
          seedsHtml = '<p class="thread-empty">暂无线索等待发芽</p>';
        } else {
          seedsHtml = pending.slice(0, 5).map(s => `
            <div class="thread-item">
              <span class="thread-item-bar destiny"></span>
              <div class="thread-item-info">
                <div class="thread-item-title">${s.desc || s.id}</div>
                <div class="thread-item-meta">来源：${s.originQuest || s.originThread || s.sourceThread || s.originCard || '未知'}</div>
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

  // ═══════════════════════════════════════════════
  //  P1/P2：天道证据星图 + 活世界多模态反馈
  // ═══════════════════════════════════════════════

  _bindEvidenceAtlas() {
    const openButton = document.getElementById('evidence-atlas-btn');
    const closeButton = document.getElementById('evidence-atlas-close');
    const panel = document.getElementById('evidence-atlas-panel');
    const muteButton = document.getElementById('immersion-mute-btn');
    if (openButton) openButton.addEventListener('click', () => this._openEvidenceAtlas());
    if (closeButton) closeButton.addEventListener('click', () => {
      if (panel) panel.style.display = 'none';
    });
    if (panel) panel.addEventListener('click', event => {
      if (event.target === panel) panel.style.display = 'none';
    });
    if (muteButton && typeof immersionDirector !== 'undefined') {
      muteButton.classList.toggle('muted', immersionDirector.muted);
      muteButton.title = immersionDirector.muted ? '开启全部声音' : '关闭全部声音';
      muteButton.setAttribute('aria-label', muteButton.title);
      muteButton.setAttribute('aria-pressed', String(immersionDirector.muted));
      muteButton.addEventListener('click', () => {
        const muted = immersionDirector.toggleMute();
        // 环境音和战斗/BGM 使用两个音频控制器，但玩家只应面对一个总静音开关。
        if (typeof window.audioManager?.toggleMute === 'function'
          && window.audioManager.muted !== muted) {
          window.audioManager.toggleMute();
        }
        muteButton.classList.toggle('muted', muted);
        muteButton.title = muted ? '开启全部声音' : '关闭全部声音';
        muteButton.setAttribute('aria-label', muteButton.title);
        muteButton.setAttribute('aria-pressed', String(muted));
      });
    }
  }

  _bindLineage() {
    const openButton = document.getElementById('lineage-btn');
    const closeButton = document.getElementById('lineage-close');
    const panel = document.getElementById('lineage-panel');
    if (openButton) openButton.addEventListener('click', () => {
      this._renderLineage();
      if (panel) panel.style.display = 'flex';
    });
    if (closeButton) closeButton.addEventListener('click', () => { if (panel) panel.style.display = 'none'; });
    if (panel) panel.addEventListener('click', event => { if (event.target === panel) panel.style.display = 'none'; });
  }

  _renderLineage() {
    if (typeof lineageSystem === 'undefined') return;
    const entries = lineageSystem.getEntries();
    const tree = lineageSystem.getTreeView?.() || null;
    const list = document.getElementById('lineage-list');
    const summary = document.getElementById('lineage-summary');
    const escape = value => String(value ?? '')
      .replace(/&/g, '&amp;').replace(/</g, '&lt;')
      .replace(/>/g, '&gt;').replace(/"/g, '&quot;');
    if (summary) {
      const insightText = tree ? `；尚有 ${tree.insight} 悟点` : '';
      summary.textContent = `已铭记 ${entries.length} 世；当前正在书写第 ${gameState.getLifeCount() + 1} 世${insightText}。`;
    }
    this._renderRebirthTree(tree, escape);
    if (!list) return;
    if (!entries.length) {
      list.innerHTML = '<p class="lineage-empty">第一世尚未落幕。破境、结交、清剿商路与击败秘境Boss，都会成为谱系中的生平。</p>';
      return;
    }
    list.innerHTML = entries.map(entry => {
      const deeds = entry.deeds || {};
      const bossText = (deeds.bossesDefeated || []).length ? ` · Boss：${deeds.bossesDefeated.join('、')}` : '';
      const relation = entry.topNpc ? `挚交 ${entry.topNpc.name}（${entry.topNpc.affection}）` : '未留挚交';
      return `<article class="lineage-entry">
        <div class="lineage-life">第 ${escape(entry.life)} 世</div>
        <div class="lineage-main">
          <h3>${escape(entry.name)} · ${escape(entry.pathName || '未定道途')}${entry.archetype ? ` / ${escape(entry.archetype.name)}` : ''}</h3>
          <p>止步于 ${escape(entry.realm)} 境，第 ${escape(entry.turn)} 次决断；${entry.ending ? `达成「${escape(entry.ending)}」后` : `因「${escape(entry.cause)}」`}入轮回。</p>
          <small>${escape(relation)} · 战胜 ${escape(deeds.combatsWon || 0)} 场 · 通关秘境 ${escape(deeds.dungeonsCompleted || 0)} 次${escape(bossText)}</small>
          <div class="lineage-tags"><span>线索 ${escape(entry.clues || 0)}</span><span>善/恶 ${escape(entry.karma?.good || 0)}/${escape(entry.karma?.bad || 0)}</span>${entry.activeRoute ? `<span>${escape(entry.activeRoute)}</span>` : ''}</div>
        </div>
      </article>`;
    }).join('');
  }

  _renderRebirthTree(tree, escape) {
    const grid = document.getElementById('rebirth-tree-grid');
    const insight = document.getElementById('rebirth-insight');
    const help = document.getElementById('rebirth-tree-help');
    if (!grid || !tree) return;
    if (insight) insight.textContent = `${tree.insight} 悟点`;
    const unlockedIds = new Set(tree.unlockedNodeIds || []);
    const dependentIds = new Set(
      (tree.branches || []).flatMap(branch => branch.nodes || [])
        .filter(node => node.unlocked)
        .flatMap(node => node.requires || [])
    );

    grid.innerHTML = (tree.branches || []).map(branch => `
      <article class="rebirth-branch" data-branch="${escape(branch.id)}">
        <header>
          <span aria-hidden="true">${escape(branch.icon || '◇')}</span>
          <div><h4>${escape(branch.name)}</h4><p>${escape(this._normalizeNarrativeText(branch.description)).replace(/\n/g, '<br>')}</p></div>
        </header>
        <div class="rebirth-node-list">
          ${(branch.nodes || []).map((node, index) => {
            const lockedByPrerequisite = !node.unlocked && !node.prerequisitesMet;
            const insufficient = !node.unlocked && !node.affordable;
            const refundable = node.unlocked && !dependentIds.has(node.id);
            const stateClass = node.unlocked ? 'unlocked' : lockedByPrerequisite ? 'blocked' : 'available';
            const action = node.unlocked ? 'refund' : 'unlock';
            const actionText = node.unlocked
              ? (refundable ? `退还 ${node.cost}` : '后继已点')
              : (lockedByPrerequisite ? '先悟前置' : insufficient ? `需 ${node.cost} 点` : `参悟 ${node.cost}`);
            return `<div class="rebirth-node ${stateClass}">
              <div class="rebirth-node-line" aria-hidden="true">${index === 0 ? '始' : '↓'}</div>
              <div class="rebirth-node-copy">
                <strong>${escape(node.name)}</strong>
                <small>${escape(node.effectText)}</small>
              </div>
              <button type="button" data-node-id="${escape(node.id)}" data-node-action="${action}"
                ${(!node.unlocked && (lockedByPrerequisite || insufficient)) || (node.unlocked && !refundable) ? 'disabled' : ''}
                aria-label="${escape(`${node.name}：${actionText}`)}">${escape(actionText)}</button>
            </div>`;
          }).join('')}
        </div>
      </article>
    `).join('');

    grid.querySelectorAll('button[data-node-id]').forEach(button => {
      button.addEventListener('click', () => {
        const result = button.dataset.nodeAction === 'refund'
          ? lineageSystem.refundNode(button.dataset.nodeId)
          : lineageSystem.unlockNode(button.dataset.nodeId);
        const changed = result?.unlocked || result?.refunded;
        if (changed) {
          this.addLog(result.unlocked ? '轮回道册亮起一道新悟。' : '轮回悟点已从枝梢退还。');
          this._renderLineage();
        } else if (help) {
          const reasonText = {
            insufficient_insight: '悟点不足。',
            missing_prerequisite: '请先参悟前置节点。',
            dependent_node_unlocked: '请先退还后继节点。',
            persist_failed: '玉简写入失败，轮回树未改变。',
            already_unlocked: '该节点已经参悟。'
          };
          help.textContent = reasonText[result?.reason] || '当前无法变更此节点。';
        }
      });
    });
  }

  /* ==========================================================
     宗门录 · EPIC-1.1
     接的是 FactionSystem 已有的异步请求-响应链路（eventBus.on('faction:getStatus')
     → emit('faction:status', payload)），本层不新增后端方法、不维护第二份状态，
     面板只渲染后端给出的只读快照。
     称号配色由后端返回的 level 字符串直接映射，不在前端重算声望区间 ——
     两处口径必须唯一，否则面板会和 FactionSystem 的判定分叉。
     ========================================================== */
  _bindFactionPanel() {
    const openBtn = document.getElementById('faction-btn');
    const panel = document.getElementById('faction-panel');
    const closeBtn = document.getElementById('faction-close');
    if (openBtn) openBtn.addEventListener('click', () => this._openFactionPanel());
    if (closeBtn) closeBtn.addEventListener('click', () => this._closeFactionPanel());
    if (panel) {
      panel.addEventListener('click', (e) => {
        if (e.target === e.currentTarget) this._closeFactionPanel();
      });
    }
    // 权威数据源：只在 UI 层订阅一次，保持单向数据流（系统层发，UI 层收）
    if (!this._factionStatusBound && typeof eventBus !== 'undefined' && eventBus) {
      this._factionStatusBound = true;
      eventBus.on('faction:status', (payload) => this._onFactionStatus(payload));
      // 声望变化的即时回执（EPIC-1.2）。后端只在数值真正变化时才发，故不会误报。
      eventBus.on('faction:reputationChanged', (payload) => this._onFactionReputationChanged(payload));
    }
  }

  /* 声望变化的浮字回执。
     只报「哪个宗门、变了多少」——不显示称号阶位，因为阶位需要声望区间判定，
     在前端重算会与 FactionSystem.getReputationLevel 形成第二套口径。
     阶位由宗门录面板展示，两者分工不重叠。 */
  _onFactionReputationChanged(data) {
    if (!data) return;
    const delta = Number(data.newValue || 0) - Number(data.oldValue || 0);
    if (!Number.isFinite(delta) || delta === 0) return;
    const name = data.factionName || data.factionId || '某处';
    const floater = document.createElement('div');
    floater.className = 'faction-rep-floater ' + (delta > 0 ? 'up' : 'down');
    floater.textContent = name + ' 声望 ' + (delta > 0 ? '+' : '') + delta;
    floater.setAttribute('aria-live', 'polite');
    document.body.appendChild(floater);
    window.setTimeout(() => floater.remove(), 1900);

    // 面板开着时同步刷新，保证玩家看到的是当前值而不是打开那一刻的快照
    const panel = document.getElementById('faction-panel');
    if (panel && panel.style.display === 'flex' && typeof eventBus !== 'undefined' && eventBus) {
      eventBus.emit('faction:getStatus');
    }
  }

  _openFactionPanel() {
    const panel = document.getElementById('faction-panel');
    if (!panel) return;
    panel.style.display = 'flex';
    const list = document.getElementById('faction-list');
    if (this._lastFactionStatus) {
      this._renderFactionPanel(this._lastFactionStatus);
    } else if (list) {
      list.innerHTML = '<p class="faction-empty">正在探问各宗……</p>';
    }
    if (typeof eventBus !== 'undefined' && eventBus) eventBus.emit('faction:getStatus');
  }

  _closeFactionPanel() {
    const panel = document.getElementById('faction-panel');
    if (panel) panel.style.display = 'none';
  }

  _onFactionStatus(status) {
    if (!status || typeof status !== 'object') return;
    this._lastFactionStatus = status;
    const panel = document.getElementById('faction-panel');
    if (panel && panel.style.display === 'flex') this._renderFactionPanel(status);
  }

  _renderFactionPanel(status) {
    const list = document.getElementById('faction-list');
    if (!list) return;
    const summary = document.getElementById('faction-summary');
    const entries = Object.entries(status || {});
    if (!entries.length) {
      list.innerHTML = '<p class="faction-empty">天下宗门尚未与你结缘。</p>';
      if (summary) summary.textContent = '你在世间留下的每一步，宗门都记着。';
      return;
    }
    // 配色沿用账本 GDD 模块二七阶表；键为后端返回的中文称号，缺失时回退中立
    const RANK_COLORS = {
      '崇敬': '#f59e0b', '尊敬': '#a855f7', '友善': '#3b82f6', '中立': '#9ca3af',
      '冷淡': '#f97316', '敌视': '#ef4444', '仇恨': '#991b1b'
    };
    const esc = (v) => String(v ?? '')
      .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;').replace(/'/g, '&#039;');
    let known = 0;
    const cards = entries.map(([fid, f]) => {
      const rep = Number(f.reputation || 0);
      const rank = f.level || '中立';
      const color = RANK_COLORS[rank] || RANK_COLORS['中立'];
      if (rank !== '中立') known += 1;
      // 声望范围 -100..100；从中线(0)向两侧延伸，宽度按绝对值的一半计
      const pct = Math.min(50, Math.abs(rep) / 2);
      const bar = rep >= 0
        ? '<i class="positive" style="width:' + pct + '%;background:' + color + '"></i>'
        : '<i class="negative" style="width:' + pct + '%;background:' + color + '"></i>';
      const subs = (f.subfactions || []).map((s) => {
        const sColor = RANK_COLORS[s.level || '中立'] || RANK_COLORS['中立'];
        return '<span class="faction-sub" style="border-color:' + sColor + '55;color:' + sColor + '">'
          + esc(s.name) + ' <b class="val">' + Number(s.reputation || 0) + '</b></span>';
      }).join('');
      const uc = f.undercurrent;
      const ucHtml = uc
        ? '<div class="faction-undercurrent">【' + esc(uc.name) + '】'
          + '<span class="stage">第 ' + Number(uc.stage || 0) + '/' + Number(uc.maxStage || 5) + ' 阶段</span>'
          + ' · ' + esc(uc.description || '尚无风声') + '</div>'
        : '';
      return '<article class="faction-card" data-faction="' + esc(fid) + '">'
        + '<div class="faction-card-head">'
        + '<span class="faction-icon">' + esc(f.icon || '◆') + '</span>'
        + '<span class="faction-name">' + esc(f.name || fid) + '</span>'
        + '<span class="faction-rank" style="color:' + color + '">' + esc(rank) + '</span>'
        + '<span class="faction-rep">声望 ' + rep + '</span>'
        + '</div>'
        + '<div class="faction-bar">' + bar + '</div>'
        + (subs ? '<div class="faction-subs">' + subs + '</div>' : '')
        + ucHtml
        + '</article>';
    });
    list.innerHTML = cards.join('');
    if (summary) {
      summary.textContent = known > 0
        ? entries.length + ' 家宗门中，已有 ' + known + ' 家对你另眼相看。'
        : '你在世间留下的每一步，宗门都记着。';
    }
  }

  _openEvidenceAtlas() {
    const panel = document.getElementById('evidence-atlas-panel');
    if (!panel || typeof evidenceAtlasSystem === 'undefined') return;
    this._renderEvidenceAtlas();
    panel.style.display = 'flex';
    this._enterTopbarPanel('evidence-atlas-panel', 'evidence-atlas-close', 'evidence-atlas-btn');
    document.getElementById('evidence-atlas-btn')?.classList.remove('has-new-evidence');
  }

  _renderEvidenceAtlas() {
    if (typeof evidenceAtlasSystem === 'undefined') return;
    const atlas = evidenceAtlasSystem.getAtlas();
    const escape = value => String(value ?? '')
      .replace(/&/g, '&amp;').replace(/</g, '&lt;')
      .replace(/>/g, '&gt;').replace(/"/g, '&quot;');
    const clues = document.getElementById('evidence-clue-list');
    const hypotheses = document.getElementById('evidence-hypothesis-list');
    const endings = document.getElementById('evidence-ending-list');
    const summary = document.getElementById('evidence-atlas-summary');
    if (summary) {
      summary.textContent = `已取得 ${atlas.discoveredClues.length}/${atlas.totalClues} 条核心证据；证据跨轮回保留，但解释仍可能被推翻。`;
    }

    if (clues) {
      clues.innerHTML = atlas.discoveredClues.length
        ? atlas.discoveredClues.map(entry => `
          <article class="evidence-card clue-card">
            <div class="evidence-card-top"><strong>${escape(entry.definition.name)}</strong><span>可信度 ${escape(entry.definition.reliability)}/3</span></div>
            <p>${escape(this._normalizeNarrativeText(entry.definition.description)).replace(/\n/g, '<br>')}</p>
            <small>第 ${escape(entry.life)} 世 · 第 ${escape(entry.turn)} 次决断</small>
          </article>`).join('')
        : '<p class="evidence-empty">星图一片沉寂。探索秘境、追问旧事或回应回响，才能取得可验证的证据。</p>';
    }

    if (hypotheses) {
      hypotheses.innerHTML = atlas.hypotheses.map(item => `
        <article class="evidence-card hypothesis-card ${item.status}">
          <div class="evidence-card-top"><strong>${escape(item.title)}</strong><span>${escape(item.confidence)}%</span></div>
          <div class="evidence-progress"><i style="width:${item.confidence}%"></i></div>
          <p>${escape(item.summary)}</p>
          <small>${item.status === 'verified' ? '已被现有证据证实' : item.status === 'plausible' ? '假说成立，但仍缺关键证据' : '证据不足，暂不可断言'}</small>
        </article>`).join('');
    }

    if (endings) {
      endings.innerHTML = atlas.endings.map(item => `
        <article class="evidence-card ending-orbit ${item.eligible ? 'eligible' : 'locked'}">
          <div class="evidence-card-top"><strong>${escape(item.name)}</strong><span>${item.eligible ? '可达' : `${item.progress}%`}</span></div>
          <p>${escape(item.stance)}</p>
          <ul>${item.reasons.map(reason => `<li class="${reason.ok ? 'met' : 'unmet'}">${reason.ok ? '◆' : '◇'} ${escape(reason.text)}</li>`).join('')}</ul>
        </article>`).join('');
    }
    this._renderWorldPulse(typeof worldPulseSystem !== 'undefined' ? worldPulseSystem.getSnapshot() : null);
  }

  _onEvidenceUpdated(data) {
    const button = document.getElementById('evidence-atlas-btn');
    if (button) button.classList.add('has-new-evidence');
    if (data?.clue) this.addLog(`✦ 星图收录新证据：${data.clue.name}`, 'evidence-log');
    const panel = document.getElementById('evidence-atlas-panel');
    if (panel?.style.display === 'flex') this._renderEvidenceAtlas();
  }

  _onWorldPulse(snapshot) {
    this._lastWorldPulse = snapshot;
    const badge = document.getElementById('world-pulse-badge');
    if (badge && snapshot) {
      badge.textContent = snapshot.headline;
      badge.dataset.mood = snapshot.dominantTag;
    }
    this._renderWorldPulse(snapshot);
  }

  _renderWorldPulse(snapshot) {
    const container = document.getElementById('evidence-world-pulse');
    if (!container || !snapshot) return;
    container.innerHTML = `
      <div class="pulse-headline">${snapshot.headline}</div>
      <div class="pulse-metrics">
        <span>动荡 <b>${snapshot.instability}</b></span>
        <span>民生 <b>${snapshot.hope}</b></span>
        <span>资源 <b>${100 - snapshot.scarcity}</b></span>
        <span>真相 <b>${snapshot.truth}</b></span>
      </div>`;
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
    if (this.container?.isConnected) return this.container;
    const existing = document.getElementById('companion-hud');
    if (existing) {
      this.container = existing;
      this.portraitImg = document.getElementById('comp-hud-img');
      this.emotionEl = document.getElementById('comp-hud-emotion');
      this.bubbleEl = document.getElementById('comp-hud-bubble');
      this.heartValEl = document.getElementById('comp-hud-heart-val');
      return this.container;
    }
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
    return this.container;
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
    this._lastAffection = this.ui._resolvePortraitAffection(compId, compData?.affection);
    this.container.style.display = 'flex';

    // 加载立绘
    this._loadPortrait(compId, this._lastAffection);

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

  updateAffection(affection) {
    if (!this.activeCompId) return;
    this._lastAffection = this.ui._resolvePortraitAffection(this.activeCompId, affection);
    if (this.heartValEl) this.heartValEl.textContent = this._lastAffection;
    this._setEmotion(this._lastAffection);
    this._loadPortrait(this.activeCompId, this._lastAffection);
  }

  /** 加载道侣立绘到 HUD；与剧情卡、万物志共享同一阶段解析器。 */
  _loadPortrait(compId, affection = this._lastAffection) {
    const fallback = 'assets/cards/characters/card_sunian_mortal_pc98.png';
    const stage = this.ui._resolvePortraitStage(compId, {
      affection,
      contextual: true
    });
    const src = stage?.asset || this.ui._getNpcPortrait(compId) || fallback;

    this.portraitImg.dataset.portraitStageId = stage?.id || '';
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

    const steady = typeof experienceSettings !== 'undefined' && experienceSettings.get('steadyCamera');
    const duration = steady ? 700 : 1600;
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

if (typeof module !== 'undefined' && module.exports) {
  module.exports = { GameUI, UI: GameUI };
}
