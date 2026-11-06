/**
 * Container - 依赖注入容器
 *
 * 负责创建 EffectService、CombatCoordinator、GameLogic 等核心对象，
 * 并将依赖显式注入构造函数，逐步替代脚本级的全局单例。
 *
 * 当前阶段：
 * - 核心状态/事件/加载器仍使用全局单例（gameState / eventBus / dataLoader）
 * - 新增服务与协调器由容器创建并注入
 * - 其余系统（CardSystem、DeckCombatSystem、KarmaSystem 等）仍保持全局单例，
 *   由容器在初始化时传入需要它们的对象
 *
 * 后续可继续把其他系统纳入容器管理。
 */
class Container {
  constructor(options = {}) {
    this.debug = options.debug !== false; // 默认开启日志
    this._log('[Container] start initialization');
    this._initCore();
    this._initServices();
    this._initCoordinators();
    this._initGameLogic();
    this._initEventWiring();
    this._log('[Container] initialization complete');
  }

  _log(...args) {
    if (this.debug) console.log('[Container]', ...args);
  }

  _initCore() {
    // 复用已有的全局核心实例（下一阶段可将它们也纳入容器）
    this.gameState = typeof gameState !== 'undefined' ? gameState : (typeof window !== 'undefined' ? window.gameState : null);
    this.eventBus = typeof eventBus !== 'undefined' ? eventBus : (typeof window !== 'undefined' ? window.eventBus : null);
    this.dataLoader = typeof dataLoader !== 'undefined' ? dataLoader : (typeof window !== 'undefined' ? window.dataLoader : null);
    if (!this.gameState && this.debug) {
      console.warn('[Container] Warning: gameState is not globally defined at initialization.');
    }
    this._log('[Container] core wired: gameState, eventBus, dataLoader');
  }

  _initServices() {
    const readStartupData = (moduleName) => this.dataLoader && typeof this.dataLoader.getCached === 'function'
      ? this.dataLoader.getCached(moduleName)
      : null;
    this.choiceOutcomeRouter = typeof choiceOutcomeRouter !== 'undefined'
      ? choiceOutcomeRouter
      : (typeof window !== 'undefined' ? window.choiceOutcomeRouter : null);
    const endingAtlas = readStartupData('world:truth_atlas');
    this.endingEligibilityService = typeof endingEligibilityService !== 'undefined' && endingEligibilityService
      ? endingEligibilityService
      : new EndingEligibilityService();
    const endingServiceReady = this.endingEligibilityService.init(endingAtlas);
    if (typeof window !== 'undefined') {
      window.endingEligibilityService = this.endingEligibilityService;
    }
    if (!endingServiceReady) {
      console.error('[Container] EndingEligibilityService failed closed: truth atlas unavailable.');
    }
    this._log('[Container] EndingEligibilityService created');

    const skillContract = readStartupData('combat:skill_acquisitions');
    const deckContract = readStartupData('combat:deck_progression');
    const cardCatalog = readStartupData('cards:battle_cards');
    this.skillCardAcquisitionSystem = new SkillCardAcquisitionSystem({
      gameState: this.gameState,
      contract: skillContract,
      deckContract,
      cardCatalog,
      deckCombatSystem: typeof deckCombatSystem !== 'undefined' ? deckCombatSystem : null,
      eventBus: this.eventBus,
      debug: this.debug
    });
    if (typeof window !== 'undefined') {
      window.skillCardAcquisitionSystem = this.skillCardAcquisitionSystem;
    }
    if (typeof deckCombatSystem !== 'undefined' && deckCombatSystem) {
      deckCombatSystem.deckAuthority = this.skillCardAcquisitionSystem;
    }
    if (typeof shopSystem !== 'undefined' && shopSystem) {
      shopSystem.deckAuthority = this.skillCardAcquisitionSystem;
    }
    this._log('[Container] SkillCardAcquisitionSystem created');

    const opportunityContract = readStartupData('progression:acquisition_opportunities');
    this.opportunityAcquisitionSystem = new OpportunityAcquisitionSystem({
      gameState: this.gameState,
      contract: opportunityContract,
      skillCardAcquisitionSystem: this.skillCardAcquisitionSystem,
      treasureSystem: typeof treasureSystem !== 'undefined' ? treasureSystem : null,
      npcSystem: typeof npcSystem !== 'undefined' ? npcSystem : (typeof window !== 'undefined' ? window.npcSystem : null),
      factionSystem: typeof factionSystem !== 'undefined' ? factionSystem : (typeof window !== 'undefined' ? window.factionSystem : null),
      eventBus: this.eventBus,
      debug: this.debug
    });
    if (typeof window !== 'undefined') {
      window.opportunityAcquisitionSystem = this.opportunityAcquisitionSystem;
    }
    this._log('[Container] OpportunityAcquisitionSystem created');

    this.effectService = new EffectService({
      gameState: this.gameState,
      eventBus: this.eventBus,
      skillCardAcquisitionSystem: this.skillCardAcquisitionSystem,
      opportunityAcquisitionSystem: this.opportunityAcquisitionSystem,
      endingEligibilityService: this.endingEligibilityService,
      choiceOutcomeRouter: this.choiceOutcomeRouter,
      encounterDirector: typeof encounterDirector !== 'undefined' ? encounterDirector : null,
      debug: this.debug
    });
    this._log('[Container] EffectService created');

    if (typeof EquipmentSystem !== 'undefined') {
      this.equipmentSystem = new EquipmentSystem({
        gameState: this.gameState,
        eventBus: this.eventBus,
        dataLoader: this.dataLoader,
        debug: this.debug
      });
      window.equipmentSystem = this.equipmentSystem; // Expose globally for now
      this._log('[Container] EquipmentSystem created');
    }
  }

  _initCoordinators() {
    this.combatCoordinator = new CombatCoordinator({
      gameState: this.gameState,
      deckCombatSystem: deckCombatSystem,
      effectService: this.effectService,
      choiceOutcomeRouter: this.choiceOutcomeRouter,
      endingEligibilityService: this.endingEligibilityService,
      skillCardAcquisitionSystem: this.skillCardAcquisitionSystem,
      cardSystem: cardSystem,
      chapterSystem: typeof chapterSystem !== 'undefined' ? chapterSystem : null,
      karmaSystem: karmaSystem,
      callbacks: this._buildCombatCallbacks(),
      debug: this.debug
    });
    this._log('[Container] CombatCoordinator created');
  }

  _buildCombatCallbacks() {
    // 回调通过闭包访问 this.game，解决初始化时 game 尚未创建的循环依赖
    return {
      log: (msg) => {
        if (this.game && typeof this.game._log === 'function') {
          this.game._log(msg);
        } else if (this.debug) {
          console.log('[CombatCoordinator callback]', msg);
        }
      },
      onUpdate: () => {
        if (this.game && typeof this.game._triggerUpdate === 'function') {
          this.game._triggerUpdate();
        }
      },
      onInnerVoice: (category, probability) => {
        if (this.game && typeof this.game._triggerInnerVoice === 'function') {
          this.game._triggerInnerVoice(category, probability);
        }
      },
      onResolveBreakthrough: (rate, card, isCombat = false) => {
        if (this.game && typeof this.game._resolveBreakthrough === 'function') {
          this.game._resolveBreakthrough(rate, card, isCombat);
        }
      },
      onCombatOutcome: (outcome, context, data) => {
        if (this.game && typeof this.game._resolveCombatOutcome === 'function') {
          return this.game._resolveCombatOutcome(outcome, context, data);
        }
        return false;
      },
      onRealmGateOutcome: (outcome, card) => {
        if (this.game && typeof this.game._settleNarrativeSpineCombatOutcome === 'function') {
          const settled = this.game._settleNarrativeSpineCombatOutcome(outcome, card);
          if (settled === false) {
            return {
              accepted: false,
              stateRolledBack: this.game._lastNarrativeSpineCombatSettlement?.stateRolledBack === true
            };
          }
        }
        if (typeof flowDirector !== 'undefined' &&
            flowDirector &&
            typeof flowDirector.settleRealmGate === 'function') {
          return flowDirector.settleRealmGate(outcome, card) !== false;
        }
        return true;
      },
      getCurrentCard: () => this.game ? this.game.currentCard : null,
      setCurrentCard: (card) => {
        if (this.game) this.game.currentCard = card;
      },
      onDecisionCheckpoint: (sourceCardId = null) => {
        if (this.game && typeof this.game._commitDecisionCheckpoint === 'function') {
          return this.game._commitDecisionCheckpoint(sourceCardId);
        }
        return false;
      },
      onDirectRealmGateDecision: (sourceCardId, encounterInstanceId) => {
        if (!encounterInstanceId || !this.game) return false;
        return this.game._commitTopLevelDecision(sourceCardId, {
          kind: 'combat', stableKey: `direct_gate:${encounterInstanceId}`
        });
      },
      onDirectDungeonBossDecision: (sourceCardId, encounterInstanceId) => {
        if (!encounterInstanceId || !this.game) return false;
        return this.game._commitTopLevelDecision(sourceCardId, {
          kind: 'combat', stableKey: `direct_dungeon:${encounterInstanceId}`
        });
      },
      onDirectCombatDecision: (sourceCardId, encounterInstanceId) => {
        if (!encounterInstanceId || !this.game) return false;
        return this.game._commitTopLevelDecision(sourceCardId, {
          kind: 'combat', stableKey: `direct_combat:${encounterInstanceId}`
        });
      }
    };
  }

  _initGameLogic() {
    this.game = new GameLogic({
      gameState: this.gameState,
      eventBus: this.eventBus,
      cardSystem: cardSystem,
      effectService: this.effectService,
      combatCoordinator: this.combatCoordinator,
      skillCardAcquisitionSystem: this.skillCardAcquisitionSystem,
      factionSystem: typeof factionSystem !== 'undefined' ? factionSystem : (typeof window !== 'undefined' ? window.factionSystem : null),
      npcSystem: typeof npcSystem !== 'undefined' ? npcSystem : (typeof window !== 'undefined' ? window.npcSystem : null),
      endingEligibilityService: this.endingEligibilityService,
      choiceOutcomeRouter: this.choiceOutcomeRouter,
      flowDirector: typeof flowDirector !== 'undefined'
        ? flowDirector
        : null,
      marketSystem: typeof marketSystem !== 'undefined'
        ? marketSystem
        : null,
      encounterDirector: typeof encounterDirector !== 'undefined'
        ? encounterDirector
        : null,
      debug: this.debug
    });
    this._log('[Container] GameLogic created');
  }

  _initEventWiring() {
    this.game.init();
    this._log('[Container] GameLogic.init() called');
  }
}

// 导出到全局，供浏览器启动脚本使用
if (typeof window !== 'undefined') {
  window.Container = Container;
}
