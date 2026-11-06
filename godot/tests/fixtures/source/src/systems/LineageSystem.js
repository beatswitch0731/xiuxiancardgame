/** 将每一世的玩法事实压缩为谱系，并把首次归档结算成轮回树悟点。 */
class LineageSystem {
  static ARCHIVE_VERSION = 1;

  constructor() {
    this.stats = this._emptyStats();
    this.treeData = null;
    this._listenersBound = false;
  }

  _emptyStats() {
    return { combatsWon: 0, bossesDefeated: [], dungeonsCompleted: 0, routesChanged: [], purchases: 0 };
  }

  init() {
    this.treeData = (typeof dataLoader !== 'undefined' && dataLoader)
      ? dataLoader.loadSync('progression:rebirth_tree')
      : null;
    this._ensureStore();
    if (typeof gameState !== 'undefined' && gameState.lineageRunStats) {
      this.hydrateState(gameState.lineageRunStats);
    }
    if (this._listenersBound || typeof eventBus === 'undefined') return;
    this._listenersBound = true;
    eventBus.on('combat:victorySettled', data => {
      this.stats.combatsWon++;
      const enemy = data?.originalCard?.enemy;
      if (Array.isArray(enemy?.phases)) {
        this.stats.bossesDefeated.push(data.originalCard.title || enemy.name || '未知 Boss');
      }
    });
    eventBus.on('dungeon:settled', data => {
      if (data?.success && typeof data.settlementId === 'string') this.stats.dungeonsCompleted++;
    });
    eventBus.on('trade:routeChanged', data => {
      if (data?.route?.name && !this.stats.routesChanged.includes(data.route.name)) {
        this.stats.routesChanged.push(data.route.name);
      }
    });
    eventBus.on('shop:purchasePrepared', data => {
      if (data?.item?.id && data.result && data.result.success !== false && data.result.replayed !== true) {
        this.stats.purchases++;
      }
    });
    eventBus.on('state:reset', () => { this.stats = this._emptyStats(); });
  }

  exportState() {
    return { version: 1, stats: JSON.parse(JSON.stringify(this.stats)) };
  }

  hydrateState(snapshot) {
    this.stats = this._emptyStats();
    if (!snapshot || typeof snapshot !== 'object' || Array.isArray(snapshot)
      || !snapshot.stats || typeof snapshot.stats !== 'object' || Array.isArray(snapshot.stats)) {
      return false;
    }
    const stats = snapshot.stats;
    for (const key of ['combatsWon', 'dungeonsCompleted', 'purchases']) {
      if (Number.isFinite(Number(stats[key]))) {
        this.stats[key] = Math.max(0, Math.floor(Number(stats[key])));
      }
    }
    this.stats.bossesDefeated = Array.isArray(stats.bossesDefeated)
      ? stats.bossesDefeated.filter(name => typeof name === 'string' && name).slice(-200)
      : [];
    this.stats.routesChanged = Array.isArray(stats.routesChanged)
      ? Array.from(new Set(stats.routesChanged.filter(name => typeof name === 'string' && name))).slice(-100)
      : [];
    return true;
  }

  _ensureStore() {
    if (!gameState.unlocks.legacy || typeof gameState.unlocks.legacy !== 'object') {
      gameState.unlocks.legacy = {};
    }
    const legacy = gameState.unlocks.legacy;
    if (!Array.isArray(legacy.lineage)) legacy.lineage = [];
    const rawTree = legacy.rebirthTree && typeof legacy.rebirthTree === 'object'
      ? legacy.rebirthTree
      : {};
    legacy.rebirthTree = {
      version: Math.max(1, Math.floor(Number(rawTree.version) || Number(this.treeData?.version) || 1)),
      insight: Math.max(0, Math.floor(Number(rawTree.insight) || 0)),
      spentInsight: Math.max(0, Math.floor(Number(rawTree.spentInsight) || 0)),
      unlockedNodeIds: Array.from(new Set((Array.isArray(rawTree.unlockedNodeIds)
        ? rawTree.unlockedNodeIds
        : []).filter(id => typeof id === 'string')))
    };
    return legacy.lineage;
  }

  _tree() {
    this._ensureStore();
    return gameState.unlocks.legacy.rebirthTree;
  }

  _nodes() {
    return (this.treeData?.branches || []).flatMap(branch => branch.nodes || []);
  }

  _node(nodeId) {
    return this._nodes().find(node => node.id === nodeId) || null;
  }

  _persist() {
    return typeof gameState._saveUnlocks === 'function' ? gameState._saveUnlocks() : false;
  }

  _calculateInsight(entry, priorEntries) {
    const realms = ['qi', 'foundation', 'golden', 'nascent', 'deity', 'tribulation'];
    const realmValue = Math.max(0, realms.indexOf(entry.realm));
    const bossValue = Math.min(3, new Set(entry.deeds?.bossesDefeated || []).size);
    const dungeonValue = Math.min(2, Math.floor(Number(entry.deeds?.dungeonsCompleted) || 0));
    const bondValue = Number(entry.topNpc?.affection) >= 80 ? 1 : 0;
    const clueValue = Number(entry.clues) >= 3 ? 1 : 0;
    const newPathValue = entry.path && !priorEntries.some(item => item.path === entry.path) ? 1 : 0;
    const treeBonus = Math.max(0, Math.floor(this.getEffectValue('lifeInsightBonus')));
    return Math.max(1, 2 + realmValue + bossValue + dungeonValue + bondValue + clueValue + newPathValue + treeBonus);
  }

  recordCurrentLife(meta = {}) {
    const lineage = this._ensureStore();
    const topNpc = typeof npcSystem !== 'undefined'
      ? Object.entries(npcSystem.affections || {}).sort((a, b) => b[1] - a[1])[0]
      : null;
    const topFaction = typeof factionSystem !== 'undefined'
      ? Object.entries(factionSystem.reputations || {}).sort((a, b) => b[1] - a[1])[0]
      : null;
    const archetype = typeof pathArchetypeSystem !== 'undefined' ? pathArchetypeSystem.getSelected() : null;
    const route = typeof tradeRouteSystem !== 'undefined' ? tradeRouteSystem.getActiveRoute() : null;
    const currentLifeNum = gameState.getLifeCount() + 1;
    const existingIndex = lineage.findIndex(item => item.life === currentLifeNum);
    const existing = existingIndex >= 0 ? lineage[existingIndex] : null;
    const entry = {
      id: existing?.id || `life_${currentLifeNum}_${Date.now()}`,
      life: currentLifeNum,
      name: gameState.playerName || '无名修士',
      path: gameState.path,
      pathName: gameState.getPathName ? gameState.getPathName(gameState.path) : gameState.path,
      archetype: archetype ? { id: archetype.id, name: archetype.name } : null,
      realm: gameState.realm,
      turn: gameState.turn,
      cause: meta.cause || existing?.cause || gameState.deadReason || '主动轮回',
      deathCauseId: meta.deathCauseId || existing?.deathCauseId || gameState.deathCauseId || null,
      endingId: meta.endingId || existing?.endingId || gameState.endingId || null,
      ending: meta.ending || existing?.ending || null,
      archiveVersion: Math.max(
        LineageSystem.ARCHIVE_VERSION,
        Math.floor(Number(existing?.archiveVersion) || 0)
      ),
      clues: (gameState.clues || []).length,
      karma: {
        good: gameState.attributes.karmaGood || 0,
        bad: gameState.attributes.karmaBad || 0
      },
      topNpc: topNpc
        ? { id: topNpc[0], name: npcSystem.getNpcName(topNpc[0]), affection: topNpc[1] }
        : null,
      topFaction: topFaction ? { id: topFaction[0], reputation: topFaction[1] } : null,
      activeRoute: route ? route.name : null,
      deeds: {
        combatsWon: this.stats.combatsWon,
        bossesDefeated: this.stats.bossesDefeated.slice(),
        dungeonsCompleted: this.stats.dungeonsCompleted,
        routesChanged: this.stats.routesChanged.slice(),
        purchases: this.stats.purchases
      },
      timestamp: Date.now()
    };

    const alreadySettled = Number.isFinite(Number(existing?.insightAwarded));
    entry.insightAwarded = alreadySettled
      ? Math.max(0, Math.floor(Number(existing.insightAwarded)))
      : this._calculateInsight(entry, lineage.filter(item => item.life !== currentLifeNum));
    if (!alreadySettled) {
      this._tree().insight += entry.insightAwarded;
      if (typeof eventBus !== 'undefined') {
        eventBus.emit('lineage:insightAwarded', {
          life: entry.life,
          amount: entry.insightAwarded,
          total: this._tree().insight
        });
      }
    }

    if (existingIndex >= 0) lineage[existingIndex] = entry;
    else lineage.push(entry);
    if (lineage.length > 24) lineage.splice(0, lineage.length - 24);
    this._persist();
    if (typeof eventBus !== 'undefined') eventBus.emit('lineage:recorded', entry);
    return entry;
  }

  getTreeState() {
    const tree = this._tree();
    return {
      version: tree.version,
      insight: tree.insight,
      spentInsight: tree.spentInsight,
      unlockedNodeIds: tree.unlockedNodeIds.slice()
    };
  }

  getEffectValue(key) {
    const unlocked = new Set(this._tree().unlockedNodeIds);
    return this._nodes().reduce((sum, node) => (
      unlocked.has(node.id) && node.effect?.key === key
        ? sum + (Number(node.effect.value) || 0)
        : sum
    ), 0);
  }

  getTreeView() {
    const state = this.getTreeState();
    const unlocked = new Set(state.unlockedNodeIds);
    return {
      ...state,
      branches: (this.treeData?.branches || []).map(branch => ({
        id: branch.id,
        name: branch.name,
        icon: branch.icon,
        description: branch.description,
        nodes: (branch.nodes || []).map(node => ({
          ...node,
          unlocked: unlocked.has(node.id),
          prerequisitesMet: (node.requires || []).every(id => unlocked.has(id)),
          affordable: state.insight >= (Number(node.cost) || 0)
        }))
      }))
    };
  }

  unlockNode(nodeId) {
    const tree = this._tree();
    const node = this._node(nodeId);
    if (!node) return { unlocked: false, reason: 'unknown_node' };
    if (tree.unlockedNodeIds.includes(nodeId)) return { unlocked: false, reason: 'already_unlocked' };
    if (!(node.requires || []).every(id => tree.unlockedNodeIds.includes(id))) {
      return { unlocked: false, reason: 'missing_prerequisite' };
    }
    const cost = Math.max(0, Math.floor(Number(node.cost) || 0));
    if (tree.insight < cost) return { unlocked: false, reason: 'insufficient_insight' };

    const previousInsight = tree.insight;
    const previousSpent = tree.spentInsight;
    const previousBonus = node.effect?.channel === 'bonuses'
      ? Number(gameState.unlocks.bonuses?.[node.effect.key]) || 0
      : null;
    tree.insight -= cost;
    tree.spentInsight += cost;
    tree.unlockedNodeIds.push(nodeId);
    if (node.effect?.channel === 'bonuses') {
      if (!gameState.unlocks.bonuses || typeof gameState.unlocks.bonuses !== 'object') {
        gameState.unlocks.bonuses = {};
      }
      const key = node.effect.key;
      gameState.unlocks.bonuses[key] = (Number(gameState.unlocks.bonuses[key]) || 0)
        + (Number(node.effect.value) || 0);
    }
    if (!this._persist()) {
      tree.insight = previousInsight;
      tree.spentInsight = previousSpent;
      tree.unlockedNodeIds = tree.unlockedNodeIds.filter(id => id !== nodeId);
      if (node.effect?.channel === 'bonuses') {
        gameState.unlocks.bonuses[node.effect.key] = previousBonus;
      }
      return { unlocked: false, reason: 'persist_failed' };
    }
    if (typeof eventBus !== 'undefined') eventBus.emit('lineage:nodeUnlocked', { nodeId, node });
    return { unlocked: true, nodeId, remainingInsight: tree.insight };
  }

  refundNode(nodeId) {
    const tree = this._tree();
    const node = this._node(nodeId);
    if (!node || !tree.unlockedNodeIds.includes(nodeId)) {
      return { refunded: false, reason: 'not_unlocked' };
    }
    const hasUnlockedDependent = this._nodes().some(candidate => (
      tree.unlockedNodeIds.includes(candidate.id) && (candidate.requires || []).includes(nodeId)
    ));
    if (hasUnlockedDependent) return { refunded: false, reason: 'dependent_node_unlocked' };

    const cost = Math.max(0, Math.floor(Number(node.cost) || 0));
    const previousInsight = tree.insight;
    const previousSpent = tree.spentInsight;
    const previousBonus = node.effect?.channel === 'bonuses'
      ? Number(gameState.unlocks.bonuses?.[node.effect.key]) || 0
      : null;
    tree.unlockedNodeIds = tree.unlockedNodeIds.filter(id => id !== nodeId);
    tree.insight += cost;
    tree.spentInsight = Math.max(0, tree.spentInsight - cost);
    if (node.effect?.channel === 'bonuses') {
      const key = node.effect.key;
      gameState.unlocks.bonuses[key] = Math.max(
        0,
        (Number(gameState.unlocks.bonuses?.[key]) || 0) - (Number(node.effect.value) || 0)
      );
    }
    if (!this._persist()) {
      tree.insight = previousInsight;
      tree.spentInsight = previousSpent;
      tree.unlockedNodeIds.push(nodeId);
      if (node.effect?.channel === 'bonuses') {
        gameState.unlocks.bonuses[node.effect.key] = previousBonus;
      }
      return { refunded: false, reason: 'persist_failed' };
    }
    if (typeof eventBus !== 'undefined') eventBus.emit('lineage:nodeRefunded', { nodeId, node });
    return { refunded: true, nodeId, remainingInsight: tree.insight };
  }

  getEntries() {
    return this._ensureStore().slice().sort((a, b) => b.life - a.life);
  }
}

const lineageSystem = new LineageSystem();

if (typeof module !== 'undefined' && module.exports) {
  module.exports = LineageSystem;
} else {
  window.LineageSystem = LineageSystem;
  window.lineageSystem = lineageSystem;
}
