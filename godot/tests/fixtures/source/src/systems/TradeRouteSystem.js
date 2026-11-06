/** 势力、战斗与秘境共同驱动的动态商路。 */
class TradeRouteSystem {
  constructor() {
    this.routes = new Map();
    this._initialized = false;
  }

  init() {
    if (this._initialized) return false;
    const data = dataLoader.loadSync('world:trade_routes');
    this.loadData(data);
    if (typeof gameState !== 'undefined' && gameState.tradeRouteState) {
      this.hydrateState(gameState.tradeRouteState);
    }
    this._initialized = true;
    eventBus.on('faction:reputationChanged', data => this._onReputation(data));
    eventBus.on('faction:undercurrentChanged', data => this._onUndercurrent(data));
    eventBus.on('combat:victorySettled', data => this._onVictory(data));
    eventBus.on('dungeon:settled', data => this._onDungeon(data));
    eventBus.on('shop:purchasePrepared', data => this._onPurchase(data));
    eventBus.on('state:reset', () => this.loadData(data));
    return true;
  }

  loadData(data) {
    this.routes.clear();
    for (const route of data?.routes || []) {
      this.routes.set(route.id, {
        ...route,
        openness: route.initial?.openness ?? 50,
        danger: route.initial?.danger ?? 30,
        prosperity: route.initial?.prosperity ?? 50,
        shipments: 0,
        history: []
      });
    }
  }

  _change(route, delta, cause) {
    if (!route) return;
    for (const key of ['openness', 'danger', 'prosperity']) {
      if (!Number.isFinite(Number(delta[key]))) continue;
      route[key] = Math.max(0, Math.min(100, route[key] + Number(delta[key])));
    }
    route.history.push({ turn: gameState.turn, cause, delta });
    route.history = route.history.slice(-8);
    eventBus.emit('trade:routeChanged', { route: this.snapshot(route.id), cause });
  }

  _onReputation(data) {
    for (const route of this.routes.values()) {
      if (!route.factions.includes(data.factionId)) continue;
      const delta = data.newValue - data.oldValue;
      this._change(route, { openness: Math.sign(delta) * 2, prosperity: Math.sign(delta) }, '势力声望变化');
    }
  }

  _onUndercurrent(data) {
    for (const route of this.routes.values()) {
      if (!(route.undercurrents || []).includes(data.id)) continue;
      this._change(route, { danger: 2, openness: -1 }, `${data.name || '势力暗流'}推进`);
    }
  }

  _onVictory(data) {
    const factionId = data?.originalCard?.enemy?.factionId;
    const current = gameState.currentLocation;
    for (const route of this.routes.values()) {
      const relevant = factionId ? route.factions.includes(factionId) : [route.from, route.to].includes(current);
      if (relevant) this._change(route, { danger: -4, openness: 2, prosperity: 1 }, '清剿商路威胁');
    }
  }

  _onDungeon(data) {
    if (!data?.success || typeof data.settlementId !== 'string') return;
    for (const route of this.routes.values()) {
      if (route.from === '秘境' || route.to === '秘境' || route.id === 'ruin_star_path') {
        this._change(route, { openness: 5, danger: -2, prosperity: 3 }, '秘境捷径被打通');
      }
    }
  }

  _onPurchase(data) {
    if (data?.source !== 'market' || !data?.item?.id || !data.result
      || data.result.success === false || data.result.replayed === true) return;
    const route = this.getActiveRoute();
    if (!route) return;
    route.shipments++;
    this._change(route, { prosperity: 1 }, '玩家完成交易');
  }

  getActiveRoute(location = gameState.currentLocation) {
    const candidates = Array.from(this.routes.values()).filter(route =>
      route.from === location || route.to === location || location === '坊市'
    );
    const pool = candidates.length ? candidates : Array.from(this.routes.values());
    return pool.sort((a, b) => (b.openness + b.prosperity - b.danger) - (a.openness + a.prosperity - a.danger))[0] || null;
  }

  getMarketModifiers() {
    const route = this.getActiveRoute();
    if (!route) return { priceMultiplier: 1, extraSlots: 0, rarityBias: 0, route: null };
    return {
      priceMultiplier: Math.max(0.8, Math.min(1.25, 1 + (route.danger - route.prosperity) / 250)),
      extraSlots: route.openness >= 70 ? 1 : route.openness <= 25 ? -1 : 0,
      rarityBias: route.prosperity >= 70 ? 1 : route.danger >= 70 ? -1 : 0,
      supply: route.supply,
      route: this.snapshot(route.id)
    };
  }

  snapshot(id) {
    const route = this.routes.get(id);
    return route ? {
      id: route.id, name: route.name, from: route.from, to: route.to,
      openness: route.openness, danger: route.danger, prosperity: route.prosperity,
      shipments: route.shipments, flavor: route.flavor, supply: route.supply,
      undercurrents: route.undercurrents || [],
      lastChange: route.history[route.history.length - 1] || null
    } : null;
  }

  exportState() {
    return {
      version: 1,
      routes: Object.fromEntries(Array.from(this.routes, ([id, route]) => [id, {
        openness: route.openness,
        danger: route.danger,
        prosperity: route.prosperity,
        shipments: route.shipments,
        history: JSON.parse(JSON.stringify(route.history))
      }]))
    };
  }

  hydrateState(snapshot) {
    if (!snapshot || typeof snapshot !== 'object' || Array.isArray(snapshot)
      || !snapshot.routes || typeof snapshot.routes !== 'object') return false;
    for (const [id, route] of this.routes) {
      const saved = snapshot.routes[id];
      if (!saved || typeof saved !== 'object' || Array.isArray(saved)) continue;
      for (const key of ['openness', 'danger', 'prosperity']) {
        if (Number.isFinite(Number(saved[key]))) {
          route[key] = Math.max(0, Math.min(100, Number(saved[key])));
        }
      }
      if (Number.isFinite(Number(saved.shipments))) {
        route.shipments = Math.max(0, Math.floor(Number(saved.shipments)));
      }
      route.history = Array.isArray(saved.history)
        ? saved.history.filter(entry => entry && typeof entry === 'object' && !Array.isArray(entry))
          .slice(-8).map(entry => JSON.parse(JSON.stringify(entry)))
        : [];
    }
    return true;
  }

  getAll() { return Array.from(this.routes.keys()).map(id => this.snapshot(id)); }
}

const tradeRouteSystem = new TradeRouteSystem();

if (typeof module !== 'undefined' && module.exports) {
  module.exports = TradeRouteSystem;
} else {
  window.TradeRouteSystem = TradeRouteSystem;
  window.tradeRouteSystem = tradeRouteSystem;
}
