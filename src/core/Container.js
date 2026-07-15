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
    this.gameState = gameState;
    this.eventBus = eventBus;
    this.dataLoader = dataLoader;
    this._log('[Container] core wired: gameState, eventBus, dataLoader');
  }

  _initServices() {
    this.effectService = new EffectService({
      gameState: this.gameState,
      eventBus: this.eventBus,
      debug: this.debug
    });
    this._log('[Container] EffectService created');
  }

  _initCoordinators() {
    this.combatCoordinator = new CombatCoordinator({
      gameState: this.gameState,
      deckCombatSystem: deckCombatSystem,
      effectService: this.effectService,
      cardSystem: cardSystem,
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
      onResolveBreakthrough: (rate, card) => {
        if (this.game && typeof this.game._resolveBreakthrough === 'function') {
          this.game._resolveBreakthrough(rate, card);
        }
      },
      getCurrentCard: () => this.game ? this.game.currentCard : null,
      setCurrentCard: (card) => {
        if (this.game) this.game.currentCard = card;
      }
    };
  }

  _initGameLogic() {
    this.game = new GameLogic({
      gameState: this.gameState,
      eventBus: this.eventBus,
      effectService: this.effectService,
      combatCoordinator: this.combatCoordinator,
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
