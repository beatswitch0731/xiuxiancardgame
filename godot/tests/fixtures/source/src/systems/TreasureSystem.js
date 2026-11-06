/**
 * TreasureSystem - 法宝系统
 *
 * 管理所有法宝的被动加成和主动效果。
 * 法宝数据从 data/shops/treasures.json 加载（也内联在 DATA_MODULES 中）。
 *
 * 功能：
 *   - 被动加成：始终生效的属性修正
 *   - 主动效果：在特定卡牌出现时提供额外选项
 *   - 法宝收集和统计
 */
class TreasureSystem {
  constructor() {
    this.treasureDB = {};  // id → { name, type, passive, active, desc, revive? }
    this.owned = new Set(); // definitionId compatibility projection
    this.ownedInstanceIds = new Set();
    this.equipped = {       // 装备槽 (P0 新增)
      weapon: null,
      armor: null,
      accessory: null,
      artifact: null
    };
    this.cooldowns = {};   // { 法宝id: 剩余冷却回合 }
    this.lastMigrationReport = null;
    this.lastReceipt = null;
    this._initialized = false;
  }

  /**
   * 初始化：加载法宝数据
   */
  init() {
    if (this._initialized) return;
    const treasureData = dataLoader.loadSync('shops:treasures');
    if (treasureData) {
      this.loadData(treasureData);
    }
    this.syncFromState();
    this._initialized = true;

    const bus = typeof eventBus !== 'undefined' ? eventBus : null;
    if (bus && typeof bus.on === 'function') {
      bus.on('state:reset', () => this.syncFromState());
    }
  }

  _slots() {
    return ['weapon', 'armor', 'accessory', 'artifact'];
  }

  _clone(value) {
    return JSON.parse(JSON.stringify(value));
  }

  _report(code, detail = {}) {
    return { code, ...detail, migrationVersion: 8 };
  }

  _captureState(state) {
    return this._clone({
      treasureInstances: state.treasureInstances || {},
      equipment: state.equipment || {},
      treasureCooldowns: state.treasureCooldowns || {},
      hasTreasureCommandReceipts: Object.prototype.hasOwnProperty.call(state, 'treasureCommandReceipts'),
      treasureCommandReceipts: state.treasureCommandReceipts || {},
      hasAttributes: Object.prototype.hasOwnProperty.call(state, 'attributes'),
      attributes: state.attributes || {},
      resources: state.resources || {},
      hasDead: Object.prototype.hasOwnProperty.call(state, 'dead'),
      dead: state.dead === true,
      hasDeadReason: Object.prototype.hasOwnProperty.call(state, 'deadReason'),
      deadReason: state.deadReason || '',
      resourcesTreasures: state.resources?.treasures || [],
      treasureInventory: state.treasureInventory || [],
      migrationRequired: state._treasureOwnershipMigrationRequired === true,
      hasLegacyResourceFieldMissing: Object.prototype.hasOwnProperty.call(
        state, '_treasureLegacyResourceFieldMissing'
      ),
      legacyResourceFieldMissing: state._treasureLegacyResourceFieldMissing === true
    });
  }

  _restoreState(state, snapshot) {
    state.resources = snapshot.resources;
    if (snapshot.hasAttributes) state.attributes = snapshot.attributes;
    else delete state.attributes;
    state.treasureInstances = snapshot.treasureInstances;
    state.equipment = snapshot.equipment;
    state.treasureCooldowns = snapshot.treasureCooldowns;
    if (snapshot.hasTreasureCommandReceipts) {
      state.treasureCommandReceipts = snapshot.treasureCommandReceipts;
    } else {
      delete state.treasureCommandReceipts;
    }
    state.resources.treasures = snapshot.resourcesTreasures;
    state.treasureInventory = snapshot.treasureInventory;
    state._treasureOwnershipMigrationRequired = snapshot.migrationRequired;
    if (snapshot.hasLegacyResourceFieldMissing) {
      state._treasureLegacyResourceFieldMissing = snapshot.legacyResourceFieldMissing;
    } else {
      delete state._treasureLegacyResourceFieldMissing;
    }
    if (snapshot.hasDead) state.dead = snapshot.dead;
    else delete state.dead;
    if (snapshot.hasDeadReason) state.deadReason = snapshot.deadReason;
    else delete state.deadReason;
    this._refreshRuntime(state);
  }

  _isKnownDefinition(definitionId) {
    return typeof definitionId === 'string' && Boolean(this.treasureDB[definitionId]);
  }

  _buildInstanceCandidate(state) {
    const instances = state.treasureInstances;
    if (!instances || typeof instances !== 'object' || Array.isArray(instances)) {
      return { ok: false, report: this._report('INSTANCE_LEDGER_MISSING') };
    }
    const candidateInstances = {};
    for (const [instanceId, entry] of Object.entries(instances)) {
      if (!entry || typeof entry !== 'object' || Array.isArray(entry)
        || entry.instanceId !== instanceId || !this._isKnownDefinition(entry.definitionId)) {
        return { ok: false, report: this._report('INVALID_INSTANCE', { instanceId }) };
      }
      candidateInstances[instanceId] = this._clone(entry);
    }
    const equipment = {};
    const used = new Set();
    for (const slot of this._slots()) {
      const instanceId = state.equipment?.[slot] || null;
      if (!instanceId) {
        equipment[slot] = null;
        continue;
      }
      const instance = candidateInstances[instanceId];
      if (!instance || instance.definitionId === undefined || this.treasureDB[instance.definitionId]?.type !== slot || used.has(instanceId)) {
        return { ok: false, report: this._report('INVALID_EQUIPPED_INSTANCE', { slot, instanceId }) };
      }
      used.add(instanceId);
      equipment[slot] = instanceId;
    }
    const cooldowns = {};
    for (const [instanceId, turns] of Object.entries(state.treasureCooldowns || {})) {
      if (!candidateInstances[instanceId] || !Number.isFinite(Number(turns))) {
        return { ok: false, report: this._report('INVALID_INSTANCE_COOLDOWN', { instanceId }) };
      }
      cooldowns[instanceId] = Math.max(0, Math.floor(Number(turns)));
    }
    return { ok: true, instances: candidateInstances, equipment, cooldowns, migrated: false };
  }

  _buildLegacyCandidate(state) {
    const resourcesPresent = Array.isArray(state.resources?.treasures)
      && state._treasureLegacyResourceFieldMissing !== true;
    const resourceIds = resourcesPresent ? state.resources.treasures : [];
    const inventoryIds = Array.isArray(state.treasureInventory) ? state.treasureInventory : [];
    const rawEquipment = state.equipment && typeof state.equipment === 'object' ? state.equipment : {};
    const equipmentIds = this._slots().map(slot => rawEquipment[slot]).filter(Boolean);
    const allCandidates = resourcesPresent ? [...resourceIds, ...inventoryIds, ...equipmentIds] : [...inventoryIds, ...equipmentIds];
    const unknownId = allCandidates.find(id => !this._isKnownDefinition(id));
    if (unknownId) return { ok: false, report: this._report('UNKNOWN_LEGACY_DEFINITION', { definitionId: unknownId }) };

    const count = values => values.reduce((result, id) => {
      result[id] = (result[id] || 0) + 1;
      return result;
    }, {});
    if (resourcesPresent) {
      const resourceCount = count(resourceIds);
      const positionedCount = count([...inventoryIds, ...equipmentIds]);
      const conflictId = Object.keys(positionedCount)
        .find(id => (positionedCount[id] || 0) > (resourceCount[id] || 0));
      if (conflictId) {
        return { ok: false, report: this._report('LEGACY_OWNERSHIP_CONFLICT', { definitionId: conflictId }) };
      }
    }

    const ownership = resourcesPresent ? resourceIds : [...inventoryIds, ...equipmentIds];
    const instances = {};
    const byDefinition = {};
    for (const definitionId of ownership) {
      const index = (byDefinition[definitionId]?.length || 0) + 1;
      const instanceId = `legacy:${definitionId}:${index}`;
      const instance = {
        instanceId,
        definitionId,
        provenance: { source: 'legacy_save', migrationVersion: 8 },
        acquiredDecision: Math.max(0, Number(state.turn) || 0),
        lifecycle: 'owned'
      };
      instances[instanceId] = instance;
      if (!byDefinition[definitionId]) byDefinition[definitionId] = [];
      byDefinition[definitionId].push(instanceId);
    }
    const assigned = new Set();
    const equipment = {};
    for (const slot of this._slots()) {
      const definitionId = rawEquipment[slot] || null;
      if (!definitionId) {
        equipment[slot] = null;
        continue;
      }
      if (this.treasureDB[definitionId].type !== slot) {
        return { ok: false, report: this._report('LEGACY_SLOT_TYPE_MISMATCH', { slot, definitionId }) };
      }
      const instanceId = (byDefinition[definitionId] || []).find(id => !assigned.has(id));
      if (!instanceId) {
        return { ok: false, report: this._report('LEGACY_EQUIPMENT_NOT_OWNED', { slot, definitionId }) };
      }
      assigned.add(instanceId);
      equipment[slot] = instanceId;
    }
    const cooldowns = {};
    for (const [definitionId, turns] of Object.entries(state.treasureCooldowns || {})) {
      if (!this._isKnownDefinition(definitionId) || !Number.isFinite(Number(turns))) {
        return { ok: false, report: this._report('INVALID_LEGACY_COOLDOWN', { definitionId }) };
      }
      const instanceId = Object.values(equipment).find(candidateId => (
        instances[candidateId]?.definitionId === definitionId
      )) || (byDefinition[definitionId] || [])[0];
      if (!instanceId) return { ok: false, report: this._report('COOLDOWN_OWNER_MISSING', { definitionId }) };
      cooldowns[instanceId] = Math.max(0, Math.floor(Number(turns)));
    }
    return { ok: true, instances, equipment, cooldowns, migrated: true };
  }

  _refreshDerivedState(state) {
    if (!state.resources || typeof state.resources !== 'object') state.resources = {};
    const instances = state.treasureInstances || {};
    const equipped = new Set(Object.values(state.equipment || {}).filter(Boolean));
    // Compatibility reads only: these are deterministically rebuilt and are not
    // written into new snapshots by GameStateManager.
    state.resources.treasures = [...new Set(Object.values(instances).map(entry => entry.definitionId))];
    state.treasureInventory = Object.keys(instances).filter(instanceId => !equipped.has(instanceId));
  }

  _refreshRuntime(state) {
    const instances = state?.treasureInstances || {};
    this.ownedInstanceIds = new Set(Object.keys(instances));
    this.owned = new Set(Object.values(instances).map(entry => entry.definitionId));
    this.equipped = { ...Object.fromEntries(this._slots().map(slot => [slot, state?.equipment?.[slot] || null])) };
    this.cooldowns = { ...(state?.treasureCooldowns || {}) };
    if (typeof equipmentSystem !== 'undefined' && typeof equipmentSystem?.syncFromState === 'function') {
      equipmentSystem.syncFromState();
    }
  }

  _commitCandidate(state, candidate) {
    state.treasureInstances = candidate.instances;
    state.equipment = candidate.equipment;
    state.treasureCooldowns = candidate.cooldowns;
    state._treasureOwnershipMigrationRequired = false;
    delete state._treasureLegacyResourceFieldMissing;
    this._refreshDerivedState(state);
    this._refreshRuntime(state);
  }

  /**
   * Catalog-dependent migration. It never writes a partial candidate: unknown
   * definitions, conflicting old projections and wrong slots retain the old
   * save untouched and leave a structured diagnostic for recovery UI.
   */
  syncFromState(state = (typeof gameState !== 'undefined' ? gameState : null)) {
    if (!state || Object.keys(this.treasureDB).length === 0) return false;
    const hasInstanceLedger = state.treasureInstances && typeof state.treasureInstances === 'object'
      && !Array.isArray(state.treasureInstances);
    const candidate = !state._treasureOwnershipMigrationRequired && hasInstanceLedger
      ? this._buildInstanceCandidate(state)
      : this._buildLegacyCandidate(state);
    if (!candidate.ok) {
      this.lastMigrationReport = candidate.report;
      state._treasureMigrationReport = candidate.report;
      return false;
    }
    const before = this._captureState(state);
    this._commitCandidate(state, candidate);
    if (candidate.migrated && !this._persistState(state, 'migrate_legacy_loadout')) {
      this._restoreState(state, before);
      return false;
    }
    this.lastMigrationReport = null;
    delete state._treasureMigrationReport;
    return true;
  }

  /**
   * 从数据加载法宝定义
   */
  loadData(data) {
    if (!data || !data.treasures) return;
    for (const t of data.treasures) {
      this.treasureDB[t.id] = t;
    }
    // 同步给装备系统
    if (typeof equipmentSystem !== 'undefined') {
      equipmentSystem.loadData({ items: this.treasureDB });
    }
  }

  _persistState(state = (typeof gameState !== 'undefined' ? gameState : null), operation = 'update') {
    if (!state || typeof state.persistCausalSession !== 'function') return true;
    try {
      const persisted = state.persistCausalSession();
      if (persisted !== false) return true;
    } catch (error) {
      this._emit('treasure:persistenceFailed', {
        operation,
        reason: error?.message || 'persistence_exception'
      });
      return false;
    }
    {
      this._emit('treasure:persistenceFailed', { operation });
      return false;
    }
  }

  _emit(event, payload) {
    const bus = typeof eventBus !== 'undefined' ? eventBus : null;
    if (bus && typeof bus.emit === 'function') bus.emit(event, payload);
  }

  _state() {
    return typeof gameState !== 'undefined' ? gameState : null;
  }

  _ensureCommandState(state) {
    if (!state) return false;
    const hasLedger = state.treasureInstances && typeof state.treasureInstances === 'object'
      && !Array.isArray(state.treasureInstances);
    return hasLedger && !state._treasureOwnershipMigrationRequired
      ? this.syncFromState(state)
      : this.syncFromState(state);
  }

  _nextInstanceId(definitionId, state) {
    let index = 1;
    let instanceId = `tr:${definitionId}:${index}`;
    while (state.treasureInstances?.[instanceId]) {
      index += 1;
      instanceId = `tr:${definitionId}:${index}`;
    }
    return instanceId;
  }

  _runCommand(state, operation, mutate, options = {}) {
    const before = this._captureState(state);
    const result = mutate();
    if (result === false) {
      this._restoreState(state, before);
      return false;
    }
    this._refreshDerivedState(state);
    this._refreshRuntime(state);
    if (options.persist !== false && !this._persistState(state, operation)) {
      this._restoreState(state, before);
      return false;
    }
    return result;
  }

  /**
   * Acquire is the only production write path from a definition to a concrete
   * owned instance. The returned boolean is preserved for existing callers.
   */
  acquire(treasureId, options = {}) {
    if (!this.treasureDB[treasureId]) return false;
    const state = this._state();
    if (!this._ensureCommandState(state)) return false;
    const transactionId = typeof options.transactionId === 'string' && options.transactionId
      ? options.transactionId
      : null;
    const replay = transactionId ? state.treasureCommandReceipts?.[transactionId] : null;
    if (replay) {
      if (replay.operation !== 'acquire' || replay.definitionId !== treasureId
        || !state.treasureInstances?.[replay.instanceId]) {
        return false;
      }
      this.lastReceipt = { ...replay, replayed: true };
      return true;
    }
    const acquiredDecision = Math.max(0, Number(
      options.decisionIndex
      ?? state.getNextDecisionIndex?.()
      ?? state.getDecisionIndex?.()
      ?? state.turn
    ) || 0);
    const instanceId = this._nextInstanceId(treasureId, state);
    const committed = this._runCommand(state, 'acquire', () => {
      state.treasureInstances[instanceId] = {
        instanceId,
        definitionId: treasureId,
        provenance: {
          // Narrative producers may add JSON-safe details, but this authority
          // writes the source/channel fields last so callers cannot forge the
          // ownership boundary of a concrete instance.
          ...(options.provenance && typeof options.provenance === 'object'
            && !Array.isArray(options.provenance)
            ? this._clone(options.provenance)
            : {}),
          source: options.source || 'runtime_acquire',
          sourceId: typeof options.sourceId === 'string' ? options.sourceId : null,
          channel: typeof options.channel === 'string' ? options.channel : null
        },
        acquiredDecision,
        transactionId,
        lifecycle: 'owned'
      };
      if (transactionId) {
        if (!state.treasureCommandReceipts || typeof state.treasureCommandReceipts !== 'object'
          || Array.isArray(state.treasureCommandReceipts)) {
          state.treasureCommandReceipts = {};
        }
        state.treasureCommandReceipts[transactionId] = {
          operation: 'acquire', transactionId, instanceId, definitionId: treasureId,
          decisionIndex: acquiredDecision
        };
      }
      return true;
    }, options);
    if (!committed) return false;
    if (options.emit !== false) {
      this._emit('treasure:acquired', {
        treasureId,
        instanceId,
        treasure: this.treasureDB[treasureId]
      });
    }
    this.lastReceipt = transactionId ? { ...state.treasureCommandReceipts[transactionId], replayed: false } : null;
    return true;
  }

  getLastReceipt() {
    return this.lastReceipt ? this._clone(this.lastReceipt) : null;
  }

  // Provenance belongs to the concrete owned instance. Consumers may attach
  // only contractual links created after acquisition; they cannot rewrite the
  // source/channel ownership fields established by `acquire`.
  annotateInstanceProvenance(instanceId, patch = {}, options = {}) {
    const state = this._state();
    if (!this._ensureCommandState(state) || typeof instanceId !== 'string' || !state.treasureInstances?.[instanceId]) return false;
    if (!patch || typeof patch !== 'object' || Array.isArray(patch)) return false;
    const allowedKeys = new Set(['ghostDebtId', 'sourceFactInstanceId', 'contractKind', 'contractLabel']);
    const safePatch = Object.fromEntries(Object.entries(patch)
      .filter(([key, value]) => allowedKeys.has(key) && (value === null || typeof value === 'string')));
    if (Object.keys(safePatch).length === 0) return false;
    return this._runCommand(state, 'annotate_instance_provenance', () => {
      const instance = state.treasureInstances[instanceId];
      instance.provenance = { ...(instance.provenance || {}), ...this._clone(safePatch) };
      return true;
    }, options);
  }

  has(treasureId) {
    const state = this._state();
    if (state?.treasureInstances?.[treasureId]) return true;
    return Object.values(state?.treasureInstances || {}).some(entry => entry.definitionId === treasureId)
      || this.owned.has(treasureId);
  }

  getInstance(instanceId) {
    const instance = this._state()?.treasureInstances?.[instanceId];
    return instance ? this._clone(instance) : null;
  }

  getDefinitionId(instanceOrDefinitionId) {
    return this._state()?.treasureInstances?.[instanceOrDefinitionId]?.definitionId || instanceOrDefinitionId;
  }

  getOwnedInstanceIds() {
    const state = this._state();
    return state?.treasureInstances ? Object.keys(state.treasureInstances) : [...this.ownedInstanceIds];
  }

  getUnequippedInstanceIds() {
    const equipped = new Set(Object.values(this._state()?.equipment || this.equipped).filter(Boolean));
    return this.getOwnedInstanceIds().filter(instanceId => !equipped.has(instanceId));
  }

  /**
   * Read-only selectors for effects.  Owned means the instance is safely in
   * the 纳戒; only equipped instances are allowed to change gameplay.
   */
  getEquippedInstanceIds() {
    const state = this._state();
    const instances = state?.treasureInstances || {};
    const equipment = state?.equipment || this.equipped || {};
    return this._slots()
      .map(slot => equipment[slot])
      .filter(instanceId => typeof instanceId === 'string' && Boolean(instances[instanceId]));
  }

  getEquippedDefinitionIds() {
    return [...new Set(this.getEquippedInstanceIds().map(instanceId => this.getDefinitionId(instanceId)))];
  }

  resolveOwnedInstanceId(instanceOrDefinitionId) {
    const state = this._state();
    if (state?.treasureInstances?.[instanceOrDefinitionId]) return instanceOrDefinitionId;
    return this.getOwnedInstanceIds().find(instanceId => (
      state?.treasureInstances?.[instanceId]?.definitionId === instanceOrDefinitionId
    )) || null;
  }

  getOwnedIds() {
    return [...new Set(this.getOwnedInstanceIds().map(instanceId => this.getDefinitionId(instanceId)))];
  }

  // (Redundant getPassiveBonuses removed, defined at bottom of file)

  /**
   * 获取当前卡牌可用的主动法宝选项
   * @param {Object} card - 当前卡牌
   * @returns {Array} 可用选项 [{ text, effects, treasureId }]
   */
  getActiveOptions(card) {
    const options = [];
    for (const instanceId of this.getEquippedInstanceIds()) {
      const definitionId = this.getDefinitionId(instanceId);
      const t = this.treasureDB[definitionId];
      if (!t || !t.active || !t.active.trigger) continue;

      let match = false;
      const trigger = t.active.trigger;

      if (trigger.cardType && card.type === trigger.cardType) match = true;
      if (trigger.tags && card.tags) {
        match = trigger.tags.some(tag => card.tags.includes(tag));
      }
      if (trigger.cardId && card.id === trigger.cardId) match = true;

      if (match) {
        options.push({
          direction: 'up',
          text: `【${t.name}】${t.active.text}`,
          effects: t.active.effects,
          // Carry the concrete equipped instance forward.  An effect may not
          // silently target a same-definition object sitting in the inventory.
          treasureId: instanceId,
          treasureLabel: t.name
        });
      }
    }
    return options;
  }

  /**
   * 获取拥有的法宝列表
   */
  getOwnedList() {
    return this.getOwnedIds().map(id => this.treasureDB[id]).filter(Boolean);
  }

  /**
   * 从唯一拥有账本移除法宝，并同步背包、装备、冷却与运行时投影。
   */
  remove(
    treasureId,
    state = this._state(),
    options = {}
  ) {
    if (!this._ensureCommandState(state)) return false;
    const instanceId = this.resolveOwnedInstanceId(treasureId);
    if (!instanceId) return false;
    const definitionId = state.treasureInstances[instanceId].definitionId;
    const committed = this._runCommand(state, 'remove', () => {
      for (const slot of this._slots()) {
        if (state.equipment?.[slot] === instanceId) state.equipment[slot] = null;
      }
      delete state.treasureInstances[instanceId];
      delete state.treasureCooldowns[instanceId];
      return true;
    }, options);
    if (!committed) return false;
    if (options.emit !== false) {
      this._emit('treasure:removed', { treasureId: definitionId, instanceId, treasure: this.treasureDB[definitionId] || null });
    }
    return true;
  }

  // === P0 新增：装备系统 ===

  /**
   * 装备法宝到指定槽位
   * @param {string} treasureId - 法宝ID
   * @param {string} slot - 槽位 (weapon/armor/accessory/artifact)
   * @returns {Object} { success, oldEquipped, message }
   */
  equip(treasureId, slot, options = {}) {
    const state = this._state();
    if (!this._ensureCommandState(state)) return { success: false, message: '法宝账本不可用' };
    if (!this._slots().includes(slot)) {
      return { success: false, message: '无效槽位' };
    }
    const instanceId = this.resolveOwnedInstanceId(treasureId);
    if (!instanceId) return { success: false, message: '未拥有此法宝' };
    const definitionId = state.treasureInstances[instanceId].definitionId;
    const treasure = this.treasureDB[definitionId];
    if (!treasure) {
      return { success: false, message: '法宝数据不存在' };
    }
    if (treasure.type !== slot) {
      return { success: false, message: `【${treasure.name}】不能装入${this._slotName(slot)}` };
    }

    const occupiedSlot = this._slots()
      .find(candidate => candidate !== slot
        && state.equipment?.[candidate] === instanceId);
    if (occupiedSlot) {
      return { success: false, message: `【${treasure.name}】已装备在${this._slotName(occupiedSlot)}` };
    }

    const oldId = state.equipment[slot] || null;
    const committed = this._runCommand(state, 'equip', () => {
      state.equipment[slot] = instanceId;
      return true;
    }, options);
    if (!committed) return { success: false, message: '存档写入失败，装备未改变' };
    if (options.emit !== false) this._emit('treasure:equipped', { treasureId: definitionId, instanceId, slot, oldId });
    return { success: true, instanceId, oldEquipped: oldId, message: `已装备【${treasure.name}】到${this._slotName(slot)}` };
  }

  /**
   * 卸下指定槽位的法宝
   * @param {string} slot
   * @returns {Object} { success, unequipped }
   */
  unequip(slot, options = {}) {
    const state = this._state();
    if (!this._ensureCommandState(state)) return { success: false, message: '法宝账本不可用' };
    const treasureId = state.equipment?.[slot];
    if (!treasureId) {
      return { success: false, message: '该槽位没有装备' };
    }
    const definitionId = state.treasureInstances?.[treasureId]?.definitionId || treasureId;
    const committed = this._runCommand(state, 'unequip', () => {
      state.equipment[slot] = null;
      return true;
    }, options);
    if (!committed) return { success: false, message: '存档写入失败，装备未改变' };
    if (options.emit !== false) this._emit('treasure:unequipped', { treasureId: definitionId, instanceId: treasureId, slot });
    const treasure = this.treasureDB[definitionId];
    return { success: true, unequipped: treasureId, message: `已卸下【${treasure?.name || definitionId}】` };
  }

  /**
   * 获取指定槽位装备的法宝ID
   */
  getEquipped(slot) {
    if (typeof gameState !== 'undefined' && gameState && gameState.equipment) {
      return gameState.equipment[slot];
    }
    return this.equipped[slot];
  }

  /**
   * 获取所有已装备法宝的被动加成（只算装备的）
   * @override
   */
  getPassiveBonuses() {
    const bonuses = {};
    const equipment = (typeof gameState !== 'undefined' && gameState && gameState.equipment) ? gameState.equipment : this.equipped;
    for (const slot of ['weapon', 'armor', 'accessory', 'artifact']) {
      const id = equipment[slot];
      if (!id) continue;
      const t = this.getTreasureData(id);
      if (!t || !t.passive) continue;
      for (const [key, val] of Object.entries(t.passive)) {
        bonuses[key] = (bonuses[key] || 0) + val;
      }
    }
    return bonuses;
  }

  /**
   * 获取法宝数据
   * @param {string} treasureId
   * @returns {Object|null}
   */
  getTreasureData(treasureId) {
    return this.treasureDB[this.getDefinitionId(treasureId)] || null;
  }

  /**
   * 返回已装备法宝的战斗展示契约。
   * gameState.equipment 是唯一装备状态；数据定义只提供名称、卡面与触发 FX。
   */
  getEquippedCombatPresentations() {
    const equipment = (typeof gameState !== 'undefined' && gameState && gameState.equipment)
      ? gameState.equipment
      : this.equipped;
    const presentations = [];
    for (const slot of ['weapon', 'armor', 'accessory', 'artifact']) {
      const treasureId = equipment?.[slot];
      if (!treasureId) continue;
      const treasure = this.getTreasureData(treasureId);
      const presentation = treasure?.combatPresentation;
      if (!treasure || !presentation) continue;
      presentations.push({
        treasureId,
        slot,
        name: treasure.name || treasureId,
        rarity: treasure.rarity || 1,
        summary: presentation.summary || treasure.desc || '',
        ...presentation,
        combatBonuses: { ...(treasure.passive || {}) }
      });
    }
    return presentations;
  }

  /**
   * 执行复活逻辑
   * @param {string} treasureId
   * @param {Object} state - gameState引用
   * @param {string} deathReason
   * @returns {Object} { success, effect }
   */
  executeRevive(treasureId, state, deathReason) {
    if (!this._ensureCommandState(state)) return { success: false };
    const instanceId = this.resolveOwnedInstanceId(treasureId);
    const treasure = this.getTreasureData(instanceId || treasureId);
    if (!instanceId || !treasure?.revive) return { success: false };

    const reviveConfig = treasure.revive;
    let effect = '';
    const committed = this._runCommand(state, 'revive', () => {
      const maxHp = state.maxHealth || 3;
      switch (reviveConfig.type) {
        case 'nirvana':
          state.attributes.health = maxHp;
          state.attributes.daoHeart = Math.max(0, state.attributes.daoHeart - 1);
          effect = '涅槃之火燃起，你从灰烬中重生！HP 回满，道心 -1';
          break;
        case 'substitute':
          state.attributes.health = Math.min(maxHp, 2);
          state.resources.spiritStone = Math.floor(state.resources.spiritStone * 0.5);
          effect = '替身符化作灰烬，替你承受了死亡。HP 回 2，灵石减半';
          break;
        case 'samsara':
          state.attributes.health = Math.min(maxHp, 2);
          state.attributes.daoHeart = Math.max(0, state.attributes.daoHeart - 2);
          state.attributes.cultivation = Math.floor(state.attributes.cultivation * 0.8);
          effect = '轮回镜照出前世之路。HP 回 2，道心 -2，修为降 20%';
          break;
        case 'chaos':
          state.attributes.health = maxHp;
          state.attributes.cultivation = Math.floor(state.attributes.cultivation * 0.8);
          effect = '混沌茧破碎，你以混沌体重生。HP 回满，修为降 20%';
          break;
        default:
          return false;
      }
      for (const slot of this._slots()) {
        if (state.equipment?.[slot] === instanceId) state.equipment[slot] = null;
      }
      delete state.treasureInstances[instanceId];
      delete state.treasureCooldowns[instanceId];
      state.dead = false;
      state.deadReason = '';
      return true;
    });
    if (!committed) return { success: false };
    this._emit('treasure:removed', { treasureId: treasure.id, instanceId, treasure });
    return { success: true, effect };
  }

  /**
   * 槽位中文名
   */
  _slotName(slot) {
    const names = { weapon: '武器', armor: '防具', accessory: '饰品', artifact: '秘宝' };
    return names[slot] || slot;
  }

  /**
   * 获取法宝的战斗修正（属性层）
   * 用于战斗系统
   */
  getCombatModifiers() {
    const bonuses = this.getPassiveBonuses();
    return {
      atk: bonuses.atk || 0,
      def: bonuses.def || 0,
      critRate: bonuses.critRate || 0,
      critDmg: bonuses.critDmg || 0,
      soulDmg: bonuses.soulDmg || 0,
      blockWindow: bonuses.blockWindow || 0,
      qiRegen: bonuses.qiRegen || 0,
      mindResist: bonuses.mindResist || 0,
      dodgeQiGain: bonuses.dodgeQiGain || 0
    };
  }

  /**
   * 获取所有已装备法宝的特性标签集合（特性层）
   * @returns {Set<string>} 如 Set{'先手','破甲','妖噬'}
   */
  getEquippedTraits() {
    const traits = new Set();
    const equipment = (typeof gameState !== 'undefined' && gameState && gameState.equipment) ? gameState.equipment : this.equipped;
    for (const slot of ['weapon', 'armor', 'accessory', 'artifact']) {
      const id = equipment[slot];
      if (!id) continue;
      const t = this.getTreasureData(id);
      if (t && t.trait) traits.add(t.trait);
    }
    return traits;
  }

  /**
   * 检查是否装备了某个特性的法宝
   */
  hasTrait(traitName) {
    return this.getEquippedTraits().has(traitName);
  }
}

// 全局单例
const treasureSystem = new TreasureSystem();

if (typeof window !== 'undefined') {
  window.TreasureSystem = TreasureSystem;
  window.treasureSystem = treasureSystem;
}
if (typeof global !== 'undefined') {
  global.TreasureSystem = TreasureSystem;
  global.treasureSystem = treasureSystem;
}
if (typeof module !== 'undefined' && module.exports) {
  module.exports = TreasureSystem;
}
