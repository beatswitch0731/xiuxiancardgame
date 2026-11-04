/**
 * ShopSystem - 商店系统
 *
 * 管理商品数据、过滤器、购买逻辑。
 * 触发方式：CardSystem 在特定时机注入 shop_encounter 卡。
 * 购买结果通过 eventBus 通知 UI 更新。
 */
class ShopSystem {
  constructor() {
    this.items = [];           // 所有商品
    this._activeOffers = [];   // 当前打开界面的不可变报价快照
    this._activeSession = false;
    this._sessionSource = 'shop';
    this._sessionId = 0;
    this._sessionSummary = null;
    this._lastClosedSummary = null;
    this._initialized = false;
    this.deckAuthority = null;
  }

  init() {
    if (this._initialized) return;
    const data = dataLoader.loadSync('shops:shop_items');
    if (data && data.items) {
      this.items = data.items;
    }
    this._initialized = true;
  }

  /**
   * 获取当前境界可购买的商品列表
   * @param {string} realm - 当前境界
   * @returns {Array}
   */
  getAvailableItems(realm) {
    const realmOrder = (gameState.config && gameState.config.realms && gameState.config.realms.order)
      || ['qi', 'foundation', 'golden', 'nascent', 'deity', 'tribulation'];
    const maxIdx = realmOrder.indexOf(realm);
    if (maxIdx < 0) return [];

    // 所有可用商品池
    let allPills = this.items.filter(item => item.type === 'pill' && realmOrder.indexOf(item.realm) <= maxIdx);
    // Materials share the small inventory stack used by gifts, but remain a
    // distinct trade kind so the regulated buyback can accept actual material
    // stock without accidentally accepting equipped treasures.
    const allGifts = this.items.filter(item => ['gift', 'material'].includes(item.type) && realmOrder.indexOf(item.realm) <= maxIdx);

    // 动态拉取全量法宝库
    let allTreasures = [];
    if (typeof treasureSystem !== 'undefined' && treasureSystem && treasureSystem.treasureDB) {
      allTreasures = Object.values(treasureSystem.treasureDB).filter(t => t?.storyOnly !== true).map(t => {
        return {
          id: `shop_treasure_dyn_${t.id}`,
          name: t.name,
          type: 'treasure',
          price: t.price || 15,
          realm: t.realm || 'qi',
          desc: t.desc || '',
          effect: { treasureId: t.id }
        };
      }).filter(t => realmOrder.indexOf(t.realm) <= maxIdx);
    } else {
      allTreasures = this.items.filter(item => item.type === 'treasure' && item.storyOnly !== true
        && realmOrder.indexOf(item.realm) <= maxIdx);
    }

    const fortune = gameState.getAttribute('fortune') || 0;
    const daoHeart = gameState.getAttribute('daoHeart') || 0;

    let selectedItems = [];

    // 卡槽 1：突破丹药保底。使用稳定实体 ID，避免改名/本地化后保底来源断链。
    const breakthroughPillMap = {
      qi: 'shop_pill_foundation',
      foundation: 'shop_pill_golden',
      golden: 'shop_pill_nascent_pill',
      nascent: 'shop_pill_deity'
    };
    const neededPillId = breakthroughPillMap[realm];
    if (neededPillId) {
      const neededPill = allPills.find(p => p.id === neededPillId);
      if (neededPill) {
        selectedItems.push(neededPill);
      }
    }

    // 卡槽 2：基础恢复丹药 (回春丹/清心丹)
    const restorePills = allPills.filter(p => p.name === '回春丹' || p.name === '清心丹');
    if (restorePills.length > 0) {
      selectedItems.push(restorePills[Math.floor(Math.random() * restorePills.length)]);
    }

    // 卡槽 3：法宝类商品 (根据气运与道心加权刷出品阶)
    if (allTreasures.length > 0) {
      const baseWeights = {
        qi: 60,
        foundation: 30,
        golden: 10,
        nascent: 5,
        deity: 2,
        tribulation: 1
      };

      const weights = {};
      for (let i = 0; i <= maxIdx; i++) {
        const rName = realmOrder[i];
        let w = baseWeights[rName] || 5;

        if (i === maxIdx && i > 0) {
          w += fortune * 2.0 + daoHeart * 1.5;
        } else if (i === maxIdx - 1 && i >= 0) {
          w += fortune * 1.0 + daoHeart * 0.8;
        } else {
          w = Math.max(2, w - (fortune * 0.5 + daoHeart * 0.3));
        }
        weights[rName] = w;
      }

      const totalWeight = Object.values(weights).reduce((a, b) => a + b, 0);
      let roll = Math.random() * totalWeight;
      let chosenRarity = 'qi';
      for (const [rName, w] of Object.entries(weights)) {
        if (roll < w) {
          chosenRarity = rName;
          break;
        }
        roll -= w;
      }

      let candidates = allTreasures.filter(t => t.realm === chosenRarity);
      if (candidates.length === 0) {
        for (let j = maxIdx; j >= 0; j--) {
          candidates = allTreasures.filter(t => t.realm === realmOrder[j]);
          if (candidates.length > 0) break;
        }
      }

      if (candidates.length > 0) {
        selectedItems.push(candidates[Math.floor(Math.random() * candidates.length)]);
      }
    }

    // 卡槽 4：当前本脉稳定功法。只从统一牌组契约生产，过滤已拥有和错误流派。
    const pathOffer = this.deckAuthority?.getShopOffer({
      path: gameState.path,
      realm
    });
    if (pathOffer) selectedItems.push(pathOffer);

    // 卡槽 5：关系资源。购买后进入真实礼物库存，再由 NPC 交互消费。
    if (allGifts.length > 0) {
      const gift = allGifts[Math.floor(Math.random() * allGifts.length)];
      selectedItems.push({ ...gift, effect: { ...(gift.effect || {}) } });
    }

    // 卡槽 6：神秘古玩 / 天机宝匣（35%基础概率 + 气运加成）。
    const runForAntique = Math.random() < 0.35 + (fortune * 0.03);
    if (runForAntique) {
      const isBox = Math.random() < 0.5;
      if (isBox) {
        selectedItems.push({
          id: 'shop_treasure_box',
          name: '天机宝匣',
          type: 'treasure',
          price: 25,
          realm: realm,
          desc: '由天机锁封印的神秘古匣，隐约透出太古灵气。价格不高不低。开启需消耗道心与福缘破解天机！',
          effect: { _identifyTreasure: 'box' }
        });
      } else {
        selectedItems.push({
          id: 'shop_treasure_mysterious',
          name: '神秘古玩',
          type: 'treasure',
          price: 15,
          realm: realm,
          desc: '地摊上淘来的蒙尘古物，价格不高不低。买下鉴宝，全看主角机缘（Fortune）气运！',
          effect: { _identifyTreasure: 'antique' }
        });
      }
    }

    // =========================================
    // 【修复 P2 & P1】计算最终价格
    // 1. 商路物价系数 (TradeRoute)
    // 2. 丹修被动 (stoneToPill)
    // =========================================
    let tradeMult = 1.0;
    if (typeof tradeRouteSystem !== 'undefined' && tradeRouteSystem) {
      tradeMult = tradeRouteSystem.getMarketModifiers().priceMultiplier || 1.0;
    }

    const passives = typeof gameState !== 'undefined' && gameState._getAggregatedPassives ? gameState._getAggregatedPassives() : {};
    const pillDiscount = passives.stoneToPill ? 0.8 : 1.0; // 造化丹鼎：丹药8折

    selectedItems.forEach(item => {
      let finalMult = tradeMult;
      if (item.type === 'pill') {
        finalMult *= pillDiscount;
      }
      // 避免重复乘
      const basePrice = item.price || 15;
      item.price = Math.max(1, Math.floor(basePrice * finalMult));
    });

    return selectedItems;
  }

  getAuthoredOffers(offerIds, realm) {
    if (!Array.isArray(offerIds) || offerIds.length === 0) return [];
    const realmOrder = gameState?.config?.realms?.order
      || ['qi', 'foundation', 'golden', 'nascent', 'deity', 'tribulation'];
    const realmIndex = realmOrder.indexOf(realm);
    if (realmIndex < 0) return [];
    const seen = new Set();
    return offerIds.flatMap(id => {
      if (typeof id !== 'string' || seen.has(id)) return [];
      seen.add(id);
      const item = this.items.find(candidate => candidate.id === id);
      if (!item || realmOrder.indexOf(item.realm || 'qi') > realmIndex) return [];
      return [{ ...item, effect: { ...(item.effect || {}) } }];
    });
  }

  /**
   * 固化一次商店/鬼市访问的报价。UI 重绘不得重新抽货或重新定价。
   */
  open(items, options = {}) {
    this._sessionId++;
    this._activeSession = true;
    this._sessionSource = options.source || 'shop';
    this._activeOffers = (items || []).map(item => {
      const offer = Object.assign({}, item);
      offer.effect = Object.assign({}, item.effect || {});
      offer.price = Number(item.displayPrice ?? item.price ?? 0);
      offer._offerSessionId = this._sessionId;
      return offer;
    });
    const restoredSummary = options.summary && typeof options.summary === 'object'
      ? options.summary
      : {};
    this._sessionSummary = {
      sessionId: this._sessionId,
      source: this._sessionSource,
      vendorId: options.vendorId || (this._sessionSource === 'market' ? 'ghost_market' : 'regulated_market'),
      marketType: typeof options.marketType === 'string' ? options.marketType : null,
      offerRevision: Math.max(1, Number(options.session?.offerRevision) || 1),
      entryCardId: options.entryCardId || null,
      sessionKey: typeof options.sessionKey === 'string' ? options.sessionKey : null,
      openingOfferCount: Math.max(0, Number(restoredSummary.openingOfferCount) || this._activeOffers.length),
      purchaseCount: Math.max(0, Number(restoredSummary.purchaseCount) || 0),
      spiritStoneSpent: Math.max(0, Number(restoredSummary.spiritStoneSpent) || 0),
      exchangeCount: Math.max(0, Number(restoredSummary.exchangeCount) || 0),
      interactionCount: Math.max(0, Number(restoredSummary.interactionCount) || 0),
      resolution: typeof restoredSummary.resolution === 'string' ? restoredSummary.resolution : null,
      playerLocation: typeof restoredSummary.playerLocation === 'string' && restoredSummary.playerLocation.trim()
        ? restoredSummary.playerLocation.trim()
        : null,
      purchasedItems: Array.isArray(restoredSummary.purchasedItems)
        ? restoredSummary.purchasedItems.map(item => Object.assign({}, item))
        : [],
      exchangedItems: Array.isArray(restoredSummary.exchangedItems)
        ? restoredSummary.exchangedItems.map(item => Object.assign({}, item))
        : [],
      ghostDebtTerms: Array.isArray(restoredSummary.ghostDebtTerms)
        ? restoredSummary.ghostDebtTerms.map(item => Object.assign({}, item))
        : []
    };
    return this.getActiveOffers();
  }

  close() {
    if (!this._activeSession) {
      return Object.assign({
        sessionId: this._sessionId,
        source: this._sessionSource,
        vendorId: null,
        entryCardId: null,
        openingOfferCount: 0,
        purchaseCount: 0,
        spiritStoneSpent: 0,
        exchangeCount: 0,
        resolution: null,
        purchasedItems: [],
        exchangedItems: []
      }, this._lastClosedSummary || {}, { alreadyClosed: true });
    }
    if (this._sessionSummary && !this._sessionSummary.resolution
      && this._activeOffers.some(offer => offer.type === 'story_item' && Array.isArray(offer.storyAlternatives))) {
      this._sessionSummary.resolution = 'left_empty';
    }
    const summary = Object.assign({}, this._sessionSummary || {}, {
      remainingOfferCount: this._activeOffers.length,
      // A market exit is a fact even when no purchase happened. Keep a small
      // player-facing projection so GameLogic can persist exactly which lead
      // or forbidden offer was declined, without retaining mutable offers.
      remainingOffers: this._activeOffers.map(offer => ({
        id: offer.id,
        name: offer.name || offer.id,
        stallId: offer.stallId || null,
        hiddenTrait: offer.hiddenTrait?.status || null
      })),
      alreadyClosed: false,
      purchasedItems: [...((this._sessionSummary && this._sessionSummary.purchasedItems) || [])],
      exchangedItems: [...((this._sessionSummary && this._sessionSummary.exchangedItems) || [])],
      ghostDebtTerms: [...((this._sessionSummary && this._sessionSummary.ghostDebtTerms) || [])]
    });
    this._activeSession = false;
    this._activeOffers = [];
    this._sessionSource = 'shop';
    this._sessionSummary = null;
    this._lastClosedSummary = summary;
    return Object.assign({}, summary, {
      purchasedItems: [...summary.purchasedItems],
      exchangedItems: [...summary.exchangedItems],
      ghostDebtTerms: [...summary.ghostDebtTerms]
    });
  }

  getActiveSessionSummary() {
    if (!this._activeSession || !this._sessionSummary) return null;
    return Object.assign({}, this._sessionSummary, {
      purchasedItems: [...this._sessionSummary.purchasedItems],
      exchangedItems: [...(this._sessionSummary.exchangedItems || [])]
    });
  }

  getActiveOffers() {
    return this._activeOffers.map(item => Object.assign({}, item, {
      effect: Object.assign({}, item.effect || {})
    }));
  }

  getActiveMarketType() {
    return this._activeSession ? this._sessionSummary?.marketType || null : null;
  }

  formatCostSpec(itemOrCostSpec) {
    const costSpec = Array.isArray(itemOrCostSpec)
      ? itemOrCostSpec
      : this._getCostSpec(itemOrCostSpec, Number(itemOrCostSpec?.price ?? itemOrCostSpec?.displayPrice) || 0);
    return costSpec.map(cost => {
      const amount = Math.max(0, Number(cost?.amount) || 0);
      if (cost?.kind === 'resource') return `${amount} ${cost.key === 'spiritStone' ? '灵石' : cost.key === 'lifespan' ? '寿元' : cost.key}`;
      if (cost?.kind === 'item') return `${amount} 份${cost.key}`;
      return `${amount} ${cost?.key || '未知代价'}`;
    }).join(' + ');
  }

  _resolveCostMode(item, costModeId = null) {
    const modes = Array.isArray(item?.costModes) ? item.costModes : [];
    if (modes.length === 0) return {
      valid: true,
      id: null,
      label: null,
      costSpec: this._getCostSpec(item, Number(item?.price ?? item?.displayPrice) || 0),
      provenanceLabel: null
    };
    const requested = typeof costModeId === 'string' && costModeId
      ? modes.find(mode => mode?.id === costModeId)
      : null;
    if (!requested) return { valid: false, reason: '必须选择一项明确的易手条件。' };
    const relationRule = requested.requiresVendorRelation;
    if (relationRule && typeof relationRule === 'object') {
      const stallId = typeof relationRule.stallId === 'string' ? relationRule.stallId : '';
      const required = Math.max(1, Math.floor(Number(relationRule.minimum) || 1));
      const relation = Math.max(0, Number(gameState.marketState?.vendorRelations?.[stallId]) || 0);
      if (!stallId || relation < required) {
        return { valid: false, reason: `需要先取得${required}点该摊熟客人情。` };
      }
    }
    const costSpec = Array.isArray(requested.costSpec)
      ? this._getCostSpec({ costSpec: requested.costSpec }, 0)
      : [];
    return {
      valid: costSpec.length > 0,
      id: requested.id,
      label: requested.label || requested.id,
      costSpec,
      provenanceLabel: requested.provenanceLabel || requested.label || requested.id
    };
  }

  getOfferCostModes(itemId) {
    const item = this._activeOffers.find(offer => offer.id === itemId);
    if (!item || !Array.isArray(item.costModes)) return [];
    return item.costModes.map(mode => {
      const resolved = this._resolveCostMode(item, mode?.id);
      const canPay = resolved.valid && this._canPayCostSpec(resolved.costSpec || []);
      return {
        id: mode?.id || '',
        label: mode?.label || '易手',
        costSpec: this._clone(resolved.costSpec || []),
        available: resolved.valid && canPay,
        disabledReason: !resolved.valid ? resolved.reason : (canPay ? '' : `需要 ${this.formatCostSpec(resolved.costSpec)}`)
      };
    });
  }

  canAffordOffer(itemId, costModeId = null) {
    const item = this._activeOffers.find(offer => offer.id === itemId);
    const mode = item ? this._resolveCostMode(item, costModeId) : null;
    return Boolean(item && mode?.valid) && this._canPayCostSpec(mode.costSpec);
  }

  /**
   * Vendor actions are data-derived and session-bound. The UI gets rendered
   * descriptors only; the authoritative service/stall and its receipt live in
   * marketState.activeSession so a refresh cannot turn a button into a second
   * transaction.
   */
  getVendorActions() {
    const session = gameState.marketState?.activeSession;
    if (!this._activeSession || !session || session.status !== 'open') return [];
    const receipts = session.actionReceipts && typeof session.actionReceipts === 'object' ? session.actionReceipts : {};
    if (session.marketType === 'regulated') {
      const service = (session.services || []).find(candidate => candidate?.id === 'regulated_buyback' && candidate.kind === 'buyback');
      const buybackActions = !service ? [] : (() => {
        const allowedKinds = new Set(Array.isArray(service.acceptedKinds) ? service.acceptedKinds : []);
        return this.items
          .filter(item => allowedKinds.has(item?.type))
          .map(item => ({ item, itemId: item.effect?.giftItemId || item.id, kind: item.type }))
          .filter(entry => typeof entry.itemId === 'string' && (gameState.getItemCount?.(entry.itemId) || 0) > 0)
          .map(entry => {
            const actionId = `${service.id}:${entry.itemId}`;
            const receipt = receipts[actionId] || null;
            return {
              actionId,
              kind: 'buyback',
              label: `回购 ${entry.item.name}`,
              description: `${service.description || '合规回购。'} 可得 ${Math.max(0, Number(service.payout) || 0)} 灵石。`,
              available: !receipt,
              disabledReason: receipt ? '本次回购已入账' : '',
              itemId: entry.itemId,
              payout: Math.max(0, Number(service.payout) || 0)
            };
          });
      })();
      const causalActions = (session.services || [])
        .filter(candidate => candidate?.kind === 'causal_fact_consumer' || candidate?.kind === 'causal_fact_closed')
        .map(serviceEntry => {
          const costSpec = Array.isArray(serviceEntry.costSpec) ? serviceEntry.costSpec : [];
          const receipt = receipts[serviceEntry.actionId] || null;
          const canPay = this._canPayCostSpec(costSpec);
          const closed = serviceEntry.kind === 'causal_fact_closed';
          return {
            actionId: serviceEntry.actionId,
            kind: serviceEntry.kind,
            factInstanceId: serviceEntry.factInstanceId,
            consumerId: serviceEntry.consumerId,
            label: serviceEntry.label || '登记凭据',
            description: serviceEntry.description || '',
            costSpec: this._clone(costSpec),
            available: !closed && !receipt && canPay,
            disabledReason: closed ? `流转号已逾期：${serviceEntry.terminalClosure || serviceEntry.description || '凭据已失效'}`
              : receipt ? `${serviceEntry.label || '凭据登记服务'}（本次服务已记入账册）`
                : `需要 ${this.formatCostSpec(costSpec)}`
          };
        });
      return [...causalActions, ...buybackActions];
    }
    if (session.marketType === 'public_bazaar') {
      const remaining = Math.max(0, Number(session.interactionBudget?.remaining) || 0);
      return (session.stalls || []).flatMap(stall => {
        const authored = Array.isArray(stall?.actions)
          ? stall.actions
          : (stall?.action ? [stall.action] : []);
        return authored.filter(action => action?.id).map(action => {
          const receipt = receipts[action.id] || null;
          const costSpec = Array.isArray(action.costSpec) ? action.costSpec : [];
          const alreadyKnown = action.causalFact?.factTypeId
            && typeof narrativeLedger !== 'undefined'
            && narrativeLedger?.hasFactTypeForLife?.(action.causalFact.factTypeId);
          const canPay = this._canPayCostSpec(costSpec);
          return {
            actionId: action.id,
            kind: 'stall_interaction',
            stallId: stall.id,
            stallName: stall.name || '无名摊位',
            label: action.label || '与摊主交谈',
            description: action.receiptText || '这次来往会被摊主记下。',
            costSpec: this._clone(costSpec),
            available: remaining > 0 && !receipt && !alreadyKnown && canPay,
            disabledReason: receipt ? '这位摊主已作答'
              : alreadyKnown ? '这条流转号已记入本世账册'
                : remaining <= 0 ? '本次集市交谈已用尽'
                  : canPay ? '' : `需要 ${this.formatCostSpec(costSpec)}`
          };
        });
      });
    }
    if (session.marketType === 'ghost') {
      const service = (session.services || []).find(candidate => candidate?.id === 'ghost_inspect_seal' && candidate.kind === 'inspect_hidden_trait');
      if (!service) return [];
      const costSpec = Array.isArray(service.costSpec) ? service.costSpec : [];
      const canInspect = this._canPayCostSpec(costSpec);
      return (session.immutableOffers || []).flatMap(offer => {
        if (offer?.hiddenTrait?.status !== 'sealed') return [];
        const actionId = `${service.id}:${offer.id}`;
        const receipt = receipts[actionId] || null;
        return [{
          actionId,
          kind: 'inspect_hidden_trait',
          itemId: offer.id,
          label: `验看 ${offer.name || '封签禁物'}`,
          description: service.description || '用情报验看一件封签禁物。',
          available: !receipt && canInspect,
          disabledReason: receipt ? '此物封签已验' : (canInspect ? '' : `需要 ${this.formatCostSpec(costSpec)}`),
          costSpec: this._clone(costSpec)
        }];
      });
    }
    return [];
  }

  executeVendorAction(actionId) {
    const session = gameState.marketState?.activeSession;
    if (!this._activeSession || !this._sessionSummary || !session || session.status !== 'open' || typeof actionId !== 'string') {
      return { success: false, message: '本次交易会话已经结束。' };
    }
    session.actionReceipts = session.actionReceipts && typeof session.actionReceipts === 'object' ? session.actionReceipts : {};
    if (session.actionReceipts[actionId]) {
      return { success: true, replayed: true, message: session.actionReceipts[actionId].message || '已恢复本次会话回执。', receipt: this._clone(session.actionReceipts[actionId]) };
    }
    if (typeof gameState.beginCausalTransaction !== 'function' || gameState.beginCausalTransaction() !== true) {
      return { success: false, message: '存档尚未就绪，操作未执行。' };
    }
    const before = { offers: this._clone(this._activeOffers), summary: this._clone(this._sessionSummary) };
    let receipt = null;
    if (session.marketType === 'regulated' && actionId.startsWith('regulated_buyback:')) {
      const itemId = actionId.slice('regulated_buyback:'.length);
      const service = (session.services || []).find(candidate => candidate?.id === 'regulated_buyback' && candidate.kind === 'buyback');
      const entry = this.items.find(item => (item.effect?.giftItemId || item.id) === itemId);
      const allowed = service && Array.isArray(service.acceptedKinds) && service.acceptedKinds.includes(entry?.type);
      const payout = Math.max(0, Number(service?.payout) || 0);
      if (!allowed || !gameState.consumeItem?.(itemId, 1)) {
        this._rollbackShopTransaction(before);
        return { success: false, message: '该物不在合规回购范围，或库存不足。' };
      }
      gameState.addResource('spiritStone', null, payout);
      receipt = { actionId, kind: 'buyback', itemId, payout, message: `回购 ${entry.name}，入账 ${payout} 灵石。` };
      this._sessionSummary.exchangeCount++;
      this._sessionSummary.exchangedItems.push({ itemId, direction: 'buyback', payout });
    } else if (session.marketType === 'regulated' && actionId.startsWith('causal_fact:')) {
      const service = (session.services || []).find(candidate => candidate?.kind === 'causal_fact_consumer'
        && candidate.actionId === actionId);
      const costSpec = Array.isArray(service?.costSpec) ? service.costSpec : [];
      const settleIndex = Number.isFinite(Number(session.openedAtDecisionIndex))
        ? Number(session.openedAtDecisionIndex)
        : (gameState.getNextDecisionIndex?.() ?? gameState.getDecisionIndex?.() ?? gameState.turn);
      if (!service || !this._canPayCostSpec(costSpec) || !this._applyCostSpec(costSpec)
        || typeof narrativeLedger === 'undefined' || !narrativeLedger?.consumeFact) {
        this._rollbackShopTransaction(before);
        return { success: false, message: '流转号无法核验，订购未成立。' };
      }
      const consumed = narrativeLedger.consumeFact({
        factInstanceId: service.factInstanceId,
        consumerId: service.consumerId,
        decisionIndex: settleIndex,
        receipt: { actionId, orderStatus: 'registered', vendorId: session.vendorId },
        persist: false
      });
      if (!consumed.consumed) {
        this._rollbackShopTransaction(before);
        return { success: false, message: '流转号已失效或已经结算，订购未重复记账。' };
      }
      const order = service.delivery
        ? (typeof marketSystem !== 'undefined' && marketSystem?.registerLicensedRustedSwordOrder
          ? marketSystem.registerLicensedRustedSwordOrder({
            factInstanceId: service.factInstanceId,
            consumerId: service.consumerId,
            delivery: service.delivery,
            paidCostSpec: costSpec,
            registeredDecisionIndex: settleIndex
          })
          : null)
        : null;
      if (service.delivery && !order) {
        this._rollbackShopTransaction(before);
        return { success: false, message: '官坊回执未能登记，订购未成立。' };
      }
      receipt = {
        actionId,
        kind: 'causal_fact_consumer',
        factInstanceId: service.factInstanceId,
        consumerId: service.consumerId,
        costSpec: this._clone(costSpec),
        orderStatus: 'registered',
        orderId: order?.orderId || null,
        dueCoreDecisionIndex: order?.dueCoreDecisionIndex || null,
        message: service.receiptText || '凭据核验通过，订购已记入账册。'
      };
      this._sessionSummary.exchangeCount++;
      this._sessionSummary.exchangedItems.push({
        factInstanceId: service.factInstanceId,
        direction: 'causal_order',
        costSpec: this._clone(costSpec),
        orderId: order?.orderId || null,
        dueCoreDecisionIndex: order?.dueCoreDecisionIndex || null
      });
    } else if (session.marketType === 'public_bazaar') {
      const stall = (session.stalls || []).find(candidate => (
        (Array.isArray(candidate?.actions) ? candidate.actions : [candidate?.action])
          .some(action => action?.id === actionId)
      ));
      const action = (Array.isArray(stall?.actions) ? stall.actions : [stall?.action])
        .find(candidate => candidate?.id === actionId);
      const costSpec = Array.isArray(action?.costSpec) ? action.costSpec : [];
      const alreadyKnown = action?.causalFact?.factTypeId
        && typeof narrativeLedger !== 'undefined'
        && narrativeLedger?.hasFactTypeForLife?.(action.causalFact.factTypeId);
      if (!action || alreadyKnown || Math.max(0, Number(session.interactionBudget?.remaining) || 0) <= 0
        || !this._canPayCostSpec(costSpec) || !this._applyCostSpec(costSpec)) {
        this._rollbackShopTransaction(before);
        return { success: false, message: '本次集市交谈已用尽、代价不足，或流转号已记账。' };
      }
      session.interactionBudget.remaining--;
      gameState.marketState.vendorRelations = gameState.marketState.vendorRelations && typeof gameState.marketState.vendorRelations === 'object'
        ? gameState.marketState.vendorRelations : {};
      const relationDelta = Number(action.relationDelta) || 0;
      gameState.marketState.vendorRelations[stall.id] = (Number(gameState.marketState.vendorRelations[stall.id]) || 0) + relationDelta;
      let fact = null;
      if (action.causalFact?.factTypeId) {
        if (typeof narrativeLedger === 'undefined' || !narrativeLedger?.recordFact) {
          this._rollbackShopTransaction(before);
          return { success: false, message: '流转账册未就绪，询问未成立。' };
        }
        const produced = narrativeLedger.recordFact({
          factTypeId: action.causalFact.factTypeId,
          producerId: action.causalFact.producerId || actionId,
          payload: action.causalFact.payload,
          decisionIndex: gameState.getNextDecisionIndex?.() ?? gameState.getDecisionIndex?.() ?? gameState.turn,
          persist: false
        });
        if (!produced.created) {
          this._rollbackShopTransaction(before);
          return { success: false, message: '这条流转号已经记入本世账册。' };
        }
        fact = produced.fact;
      }
      receipt = { actionId, kind: 'stall_interaction', stallId: stall.id, relationDelta, costSpec: this._clone(costSpec), factInstanceId: fact?.factInstanceId || null, message: action.receiptText || '摊主记下了这次来往。' };
      this._sessionSummary.interactionCount++;
      this._sessionSummary.exchangedItems.push({ stallId: stall.id, direction: 'interaction', relationDelta, costSpec: this._clone(costSpec), factInstanceId: fact?.factInstanceId || null });
    } else if (session.marketType === 'ghost' && actionId.startsWith('ghost_inspect_seal:')) {
      const itemId = actionId.slice('ghost_inspect_seal:'.length);
      const service = (session.services || []).find(candidate => candidate?.id === 'ghost_inspect_seal' && candidate.kind === 'inspect_hidden_trait');
      const sessionOffer = (session.immutableOffers || []).find(offer => offer?.id === itemId);
      const activeOffer = this._activeOffers.find(offer => offer?.id === itemId);
      const costSpec = Array.isArray(service?.costSpec) ? service.costSpec : [];
      if (!service || !sessionOffer || sessionOffer.hiddenTrait?.status !== 'sealed' || !this._canPayCostSpec(costSpec) || !this._applyCostSpec(costSpec)) {
        this._rollbackShopTransaction(before);
        return { success: false, message: '封签无法验看：需要一份有效的商路线索。' };
      }
      sessionOffer.hiddenTrait.status = 'revealed';
      if (activeOffer?.hiddenTrait) activeOffer.hiddenTrait.status = 'revealed';
      const revealed = sessionOffer.hiddenTrait.revealedText || '封签下的来路仍晦暗不明。';
      receipt = { actionId, kind: 'inspect_hidden_trait', itemId, costSpec: this._clone(costSpec), message: `封签验明：${revealed}` };
      this._sessionSummary.exchangeCount++;
      this._sessionSummary.exchangedItems.push({ itemId, direction: 'inspect_hidden_trait', costSpec: this._clone(costSpec) });
    } else {
      this._rollbackShopTransaction(before);
      return { success: false, message: '此处没有可执行的市集服务。' };
    }
    session.actionReceipts[actionId] = receipt;
    this._syncPendingVendorSession({ persist: false });
    if (!this._commitLoadoutTransaction(before)) return { success: false, message: '存档写入失败，操作未执行。' };
    eventBus.emit('market:vendorAction', { actionId, receipt: this._clone(receipt), sessionId: this._sessionSummary.sessionKey, vendorId: session.vendorId });
    return { success: true, message: receipt.message, receipt: this._clone(receipt) };
  }

  previewLicensedRustedSwordOrder(orderId) {
    if (typeof orderId !== 'string' || !orderId
      || typeof marketSystem === 'undefined' || !marketSystem?.getLicensedRustedSwordOrder) {
      return { valid: false, reason: 'regulated_delivery_unavailable', message: '官坊回执无效。' };
    }
    // Reading a missing market must not invoke its lazy initialization path.
    const stored = gameState.marketState?.rustedSwordOrders?.find(entry => entry?.orderId === orderId);
    const order = stored ? this._clone(stored) : null;
    if (!order) return { valid: false, reason: 'regulated_delivery_missing_order', message: '官坊账册中没有这份订购。' };
    if (order.status === 'CLAIMED') {
      return { valid: true, reason: null, replayed: true, order, message: '这件正货已经凭同一回执交付。' };
    }
    if (order.status !== 'READY') return { valid: false, reason: 'regulated_delivery_not_ready', order, message: '正货尚在官坊净炼，回执未到领取时点。' };
    if (gameState.pendingLoadoutDecision?.status === 'pending') {
      return { valid: false, reason: 'regulated_delivery_pending_loadout', order, message: '请先决定已有法宝是否穿戴或收入纳戒。' };
    }
    const treasure = typeof treasureSystem !== 'undefined' ? treasureSystem : null;
    if (!treasure?.acquire || !treasure?.getTreasureData?.(order.definitionId)) {
      return { valid: false, reason: 'regulated_delivery_item_unavailable', order, message: '官坊交付的法宝资料尚未就绪。' };
    }
    const ledger = typeof narrativeLedger !== 'undefined' ? narrativeLedger : null;
    const provenanceType = order.provenanceFactTypeId || 'sword_origin_licensed';
    if (!ledger?.recordFact || !ledger?.getCausalFactDefinition?.(provenanceType)
      || ledger.getFactByType?.(provenanceType)) {
      return { valid: false, reason: 'regulated_delivery_provenance_unavailable', order, message: '官坊交付的来历凭据尚不可登记。' };
    }
    return { valid: true, reason: null, replayed: false, order };
  }

  fulfillLicensedRustedSwordOrder(orderId, { transactionManaged = false } = {}) {
    const contract = this.previewLicensedRustedSwordOrder(orderId);
    if (!contract.valid) return { success: false, message: contract.message };
    const { order } = contract;
    if (contract.replayed) {
      return { success: true, replayed: true, instanceId: order.instanceId || null,
        provenanceFactInstanceId: order.provenanceFactInstanceId || null, message: contract.message };
    }
    const ownsTransaction = transactionManaged !== true;
    if (ownsTransaction && (typeof gameState.beginCausalTransaction !== 'function'
      || gameState.beginCausalTransaction() !== true)) {
      return { success: false, message: '存档尚未就绪，正货未交付。' };
    }
    const rollback = () => {
      if (ownsTransaction) gameState.rollbackCausalTransaction?.();
    };
    const treasurePort = typeof treasureSystem !== 'undefined' ? treasureSystem : null;
    const definitionId = order.definitionId;
    const acquisitionToken = `licensed_rusted_sword_delivery:${order.orderId}`;
    const acquired = treasurePort?.acquire
      ? treasurePort.acquire(definitionId, {
        source: 'regulated_rusted_sword_order',
        sourceId: order.orderId,
        channel: 'regulated_market',
        transactionId: acquisitionToken,
        decisionIndex: gameState.getNextDecisionIndex?.() ?? gameState.getDecisionIndex?.() ?? gameState.turn,
        persist: false,
        emit: false
      })
      : false;
    const instanceId = treasurePort?.getLastReceipt?.()?.instanceId || null;
    if (acquired === false || typeof instanceId !== 'string' || !instanceId) {
      rollback();
      return { success: false, message: '官坊交付未能落入法宝账册。' };
    }
    const provenance = typeof narrativeLedger !== 'undefined' && narrativeLedger?.recordFact
      ? narrativeLedger.recordFact({
        factTypeId: order.provenanceFactTypeId || 'sword_origin_licensed',
        producerId: 'licensed_rusted_sword_delivery',
        payload: {
          orderId: order.orderId,
          itemInstanceId: instanceId,
          rootFactInstanceId: order.factInstanceId,
          acquisitionPath: 'regulated_order'
        },
        decisionIndex: gameState.getNextDecisionIndex?.() ?? gameState.getDecisionIndex?.() ?? gameState.turn,
        persist: false
      })
      : null;
    if (!provenance?.created || !provenance.fact?.factInstanceId) {
      rollback();
      return { success: false, message: '官坊交付来历未能写入因果账册。' };
    }
    const claimed = marketSystem.claimLicensedRustedSwordDelivery?.(order.orderId, {
      instanceId,
      provenanceFactInstanceId: provenance.fact.factInstanceId,
      claimedDecisionIndex: gameState.getNextDecisionIndex?.() ?? gameState.getDecisionIndex?.() ?? gameState.turn
    });
    if (!claimed) {
      rollback();
      return { success: false, message: '官坊交付回执未能结清。' };
    }
    const pending = this._buildPendingLoadoutDecision(
      { id: definitionId, effect: { treasureId: definitionId } },
      { returnAllowed: false },
      {
        sessionKey: `regulated_order:${order.orderId}`,
        purchaseReceiptToken: acquisitionToken,
        decisionId: `loadout:regulated-order:${order.orderId}`
      }
    );
    if (!pending) {
      rollback();
      return { success: false, message: '法宝装配槽位无法确认，交付已撤回。' };
    }
    gameState.pendingLoadoutDecision = pending;
    if (ownsTransaction) {
      let persisted = false;
      try {
        persisted = gameState.persistCausalSession?.({ force: true }) !== false;
      } catch (error) {
        persisted = false;
      }
      if (!persisted) {
        rollback();
        return { success: false, message: '存档写入失败，正货未交付。' };
      }
      gameState.finishCausalTransaction?.();
    }
    // The delivery is normally resolved inside GameLogic's top-level decision
    // transaction.  Do not let UI observers see the new instance or loadout
    // prompt until that outer transaction has actually committed: a failed
    // final persistence must leave the delivery card retryable, with no modal
    // pointing at the rolled-back instance.
    if (!transactionManaged) {
      eventBus.emit('treasure:acquired', { treasureId: definitionId, instanceId, treasure: treasurePort?.getTreasureData?.(instanceId) });
      eventBus.emit('loadout:decisionPending', { pending: this._clone(pending), source: 'regulated_rusted_sword_order' });
    }
    return {
      success: true,
      replayed: false,
      instanceId,
      provenanceFactInstanceId: provenance.fact.factInstanceId,
      pendingLoadoutDecision: this._clone(pending),
      message: '官坊正货已交付：请决定是否立即穿戴。'
    };
  }

  getStoryAlternatives(itemId) {
    if (!this._activeSession) return [];
    const item = this._activeOffers.find(offer => offer.id === itemId);
    if (!item || !Array.isArray(item.storyAlternatives)) return [];
    const spiritStone = Math.max(0, Number(gameState.resources?.spiritStone) || 0);
    const price = Math.max(0, Number(item.price ?? item.displayPrice) || 0);
    return item.storyAlternatives.map(raw => {
      const option = Object.assign({}, raw);
      let available = false;
      let disabledReason = '';
      if (option.type === 'barter_item') {
        const required = Math.max(1, Math.floor(Number(option.quantity) || 1));
        const owned = typeof gameState.getItemCount === 'function'
          ? gameState.getItemCount(option.itemId)
          : Math.max(0, Number(gameState.itemInventory?.[option.itemId]) || 0);
        available = typeof option.itemId === 'string' && owned >= required;
        if (!available) disabledReason = `需要 ${required} 件【${option.itemId || '交换物'}】`;
      } else if (option.type === 'insufficient_fallback') {
        available = spiritStone < price;
        if (!available) disabledReason = '仅在灵石不足时启用';
      }
      return { ...option, available, disabledReason };
    });
  }

  resolveStoryAlternative(itemId, alternativeId) {
    if (!this._activeSession || !this._sessionSummary) {
      return { success: false, message: '本次坊市已经结束。' };
    }
    const item = this._activeOffers.find(offer => offer.id === itemId);
    const option = this.getStoryAlternatives(itemId).find(candidate => candidate.id === alternativeId);
    if (!item || !option) return { success: false, message: '这项交换已经失效。' };
    if (!option.available) return { success: false, message: option.disabledReason || '当前不能选择这项交换。' };

    if (option.type === 'barter_item') {
      const quantity = Math.max(1, Math.floor(Number(option.quantity) || 1));
      const consumed = typeof gameState.consumeItem === 'function'
        ? gameState.consumeItem(option.itemId, quantity)
        : false;
      if (!consumed) return { success: false, message: '交换物数量不足。' };
      const grant = option.grantOfferedItem === false
        ? { success: true, type: 'story_resolution' }
        : this._applyItemEffect(item);
      if (!grant || grant.success === false || grant.type === 'unknown') {
        gameState.addItem?.(option.itemId, quantity);
        return { success: false, message: '交换未完成，交换物已归还。' };
      }
      this._sessionSummary.exchangeCount += 1;
      this._sessionSummary.resolution = option.resolution || 'bartered';
      this._sessionSummary.exchangedItems.push({
        offeredItemId: item.id,
        paymentItemId: option.itemId,
        quantity
      });
    } else if (option.type === 'insufficient_fallback') {
      this._sessionSummary.resolution = option.resolution || 'fallback';
      const nextLocation = typeof option.playerLocation === 'string' ? option.playerLocation.trim() : '';
      if (nextLocation) {
        this._sessionSummary.playerLocation = nextLocation;
        const scene = typeof sceneLayerSystem !== 'undefined' ? sceneLayerSystem : null;
        if (scene && typeof scene.transition === 'function') scene.transition(nextLocation, 'story_event');
        else gameState.currentLocation = nextLocation;
      }
    } else {
      return { success: false, message: '未知交换方式。' };
    }

    this._activeOffers = this._activeOffers.filter(offer => offer.id !== itemId);
    this._syncPendingVendorSession();
    eventBus.emit('shop:storyAlternativeResolved', {
      itemId,
      alternativeId,
      resolution: this._sessionSummary.resolution,
      playerLocation: this._sessionSummary.playerLocation,
      sessionId: this._sessionId,
      sessionKey: this._sessionSummary.sessionKey
    });
    return {
      success: true,
      message: option.type === 'barter_item'
        ? `以【${option.itemId}】换得了【${item.name}】。`
        : '剑灵儿已带你回宗门借剑。',
      item,
      option,
      resolution: this._sessionSummary.resolution
    };
  }

  _syncPendingVendorSession(options = {}) {
    const activeSession = gameState.marketState?.activeSession;
    if (activeSession && activeSession.status === 'open') {
      activeSession.immutableOffers = this.getActiveOffers();
      // `items` existed only on the legacy pendingVendorSession shape.  Do not
      // write it back here: immutableOffers is the one persisted offer source.
      delete activeSession.items;
      activeSession.summary = this.getActiveSessionSummary();
      if (options.persist !== false && typeof gameState.persistCausalSession === 'function') {
        gameState.persistCausalSession();
      }
    }
  }

  _clone(value) {
    return JSON.parse(JSON.stringify(value));
  }

  _isTreasureOffer(item) {
    return Boolean((item?.type === 'treasure' || item?._marketItem) && item?.effect?.treasureId);
  }

  _buildPendingLoadoutDecision(item, result, overrides = {}) {
    const receipt = treasureSystem.getLastReceipt?.();
    const instanceId = receipt?.instanceId;
    const treasure = instanceId ? treasureSystem.getTreasureData?.(instanceId) : null;
    const targetSlot = typeof treasure?.type === 'string' ? treasure.type : null;
    if (!instanceId || !targetSlot || !['weapon', 'armor', 'accessory', 'artifact'].includes(targetSlot)) {
      return null;
    }
    const sessionKey = typeof overrides.sessionKey === 'string' && overrides.sessionKey
      ? overrides.sessionKey : this._vendorSessionKey();
    const token = typeof overrides.purchaseReceiptToken === 'string' && overrides.purchaseReceiptToken
      ? overrides.purchaseReceiptToken : this._treasurePurchaseToken(item);
    return {
      id: typeof overrides.decisionId === 'string' && overrides.decisionId
        ? overrides.decisionId : `loadout:${sessionKey}:${item.id}`,
      instanceId,
      sourceVendorSessionKey: sessionKey,
      purchaseReceiptToken: token,
      targetSlot,
      status: 'pending',
      allowedActions: {
        equip: true,
        stash: true,
        viewProvenance: true,
        // B2 owns pricing and return policies.  An absent policy must never
        // accidentally become a free refund channel.
        return: Boolean(result?.returnAllowed === true)
      },
      // Reserved data contract only. B2 will author price, recipient and
      // eligibility; B1 intentionally exposes neither a sale nor a refund.
      refundPolicy: result?.refundPolicy && typeof result.refundPolicy === 'object'
        ? this._clone(result.refundPolicy)
        : null
    };
  }

  _restoreShopTransaction(before) {
    this._activeOffers = before.offers;
    this._sessionSummary = before.summary;
  }

  _rollbackShopTransaction(before) {
    try {
      gameState.rollbackCausalTransaction?.();
    } finally {
      this._restoreShopTransaction(before);
    }
  }

  _commitLoadoutTransaction(before) {
    let persisted = false;
    try {
      persisted = gameState.persistCausalSession?.({ force: true }) !== false;
    } catch (error) {
      persisted = false;
    }
    if (!persisted) {
      this._rollbackShopTransaction(before);
      return false;
    }
    gameState.finishCausalTransaction?.();
    return true;
  }

  _getCostSpec(item, price) {
    if (Array.isArray(item?.costSpec) && item.costSpec.length > 0) {
      return item.costSpec.map(cost => ({
        kind: cost?.kind,
        key: cost?.key,
        amount: Math.max(0, Number(cost?.amount) || 0)
      })).filter(cost => cost.amount > 0 && typeof cost.kind === 'string' && typeof cost.key === 'string');
    }
    return [{ kind: 'resource', key: 'spiritStone', amount: Math.max(0, Number(price) || 0) }];
  }

  _canPayCostSpec(costSpec) {
    return costSpec.every(cost => {
      if (cost.kind === 'resource') return Math.max(0, Number(gameState.resources?.[cost.key]) || 0) >= cost.amount;
      if (cost.kind === 'item') return typeof gameState.getItemCount === 'function' && gameState.getItemCount(cost.key) >= cost.amount;
      return false;
    });
  }

  _applyCostSpec(costSpec) {
    for (const cost of costSpec) {
      if (cost.kind === 'resource') gameState.addResource(cost.key, null, -cost.amount);
      else if (cost.kind === 'item' && !gameState.consumeItem?.(cost.key, cost.amount)) return false;
    }
    return true;
  }

  _spiritStoneCost(costSpec) {
    return costSpec.filter(cost => cost.kind === 'resource' && cost.key === 'spiritStone')
      .reduce((total, cost) => total + cost.amount, 0);
  }

  _createGhostDebt(item, result, purchaseCostSpec = []) {
    const session = gameState.marketState?.activeSession;
    if (session?.marketType !== 'ghost' || !session.debt || !Array.isArray(gameState.marketState?.debts)) return null;
    const oath = item?.ghostOathContract && typeof item.ghostOathContract === 'object'
      ? item.ghostOathContract : null;
    const minOffset = Math.max(3, Math.floor(Number(session.debt.minDueOffset) || 3));
    const maxOffset = Math.max(minOffset, Math.floor(Number(session.debt.maxDueOffset) || minOffset));
    const dueOffset = minOffset; // deterministic at B2; B5 may author bounded variants.
    const decisionIndex = Math.max(0, Number(gameState.getDecisionIndex?.() ?? gameState.runClock?.decisionIndex) || 0);
    const contractStoneCost = this._spiritStoneCost(Array.isArray(purchaseCostSpec) ? purchaseCostSpec : []);
    // Debt is a future claim, not a decorative status. The eventual settlement
    // fee is deliberately derived from the signed quote and saved on the debt
    // so a refresh or later price-table change can never make it free.
    const genericSettlementCostSpec = [{
      kind: 'resource',
      key: 'spiritStone',
      amount: Math.max(1, Math.ceil(contractStoneCost * 0.5))
    }];
    const settlementCostSpec = oath && Array.isArray(oath.settlementCostSpec) && oath.settlementCostSpec.length > 0
      ? this._clone(oath.settlementCostSpec)
      : genericSettlementCostSpec;
    const dueDecisionIndex = oath
      ? decisionIndex + Math.max(1, Math.floor(Number(oath.dueDecisionOffset) || 3))
      : decisionIndex + Math.min(maxOffset, dueOffset);
    const debt = {
      debtId: `ghost_debt:${session.sessionId}:${item.id}:r${session.offerRevision || 1}`,
      originSessionId: session.sessionId,
      acquiredInstanceId: result?.instanceId || treasureSystem.getLastReceipt?.()?.instanceId || null,
      creditorId: session.debt.creditorId || 'faceless_broker',
      dueDecisionIndex,
      status: 'PENDING',
      defaultConsequence: session.debt.defaultConsequence || 'ghost_market_access_revoked',
      settlementCostSpec,
      settlementReceiptId: null
    };
    if (oath) {
      const pressure = oath.pressure && typeof oath.pressure === 'object' ? oath.pressure : {};
      debt.kind = oath.kind || 'ghost_oath_sword';
      debt.contractLabel = oath.label || item.name || '夜契';
      debt.sourceFactInstanceId = typeof result?.sourceFactInstanceId === 'string' ? result.sourceFactInstanceId : null;
      debt.pressure = {
        chance: Math.max(0, Math.min(1, Number(pressure.chance) || (1 / 3))),
        pityLimit: Math.max(1, Math.floor(Number(pressure.pityLimit) || 3)),
        misses: 0,
        processedEncounterIds: [],
        receipts: [],
        lastReceipt: null
      };
    }
    if (gameState.marketState.debts.some(existing => existing?.debtId === debt.debtId)) return null;
    gameState.marketState.debts.push(debt);
    return debt;
  }

  _describeGhostDebtTerm(debt) {
    if (!debt) return '';
    const current = Math.max(0, Number(gameState.getDecisionIndex?.() ?? gameState.runClock?.decisionIndex) || 0);
    const due = Math.max(current, Math.floor(Number(debt.dueDecisionIndex) || current));
    const remaining = Math.max(0, due - current);
    const settlement = this.formatCostSpec(Array.isArray(debt.settlementCostSpec) ? debt.settlementCostSpec : []);
    return `第 ${due} 次决断到期（还剩 ${remaining} 次）；届时须补 ${settlement || '一笔代价'}清偿。`;
  }

  _purchaseWithCostSpec(item, price) {
    const costSpec = this._getCostSpec(item, price);
    if (!this._canPayCostSpec(costSpec)) return { success: false, message: '契约代价不足，交易未执行。', item };
    if (typeof gameState.beginCausalTransaction !== 'function' || gameState.beginCausalTransaction() !== true) {
      return { success: false, message: '存档尚未就绪，交易未执行。', item };
    }
    const before = { offers: this._clone(this._activeOffers), summary: this._clone(this._sessionSummary) };
    if (!this._applyCostSpec(costSpec)) {
      this._rollbackShopTransaction(before);
      return { success: false, message: '契约代价不足，交易未执行。', item };
    }
    const result = this._applyItemEffect(item, { persist: false, emit: false });
    if (!result || result.type === 'unknown' || result.success === false) {
      this._rollbackShopTransaction(before);
      return { success: false, message: '交易未能完成，代价未扣除。', item, result };
    }
    this._activeOffers = this._activeOffers.filter(offer => offer.id !== item.id);
    if (this._sessionSummary) {
      this._sessionSummary.purchaseCount++;
      this._sessionSummary.spiritStoneSpent += this._spiritStoneCost(costSpec);
      this._sessionSummary.purchasedItems.push({ id: item.id, name: item.name, costSpec: this._clone(costSpec) });
    }
    const debt = this._createGhostDebt(item, result, costSpec);
    if (debt && this._sessionSummary) this._sessionSummary.ghostDebtTerms.push(this._clone(debt));
    this._syncPendingVendorSession({ persist: false });
    eventBus.emit('shop:purchasePrepared', {
      item, result, costSpec, source: this._sessionSource, sessionId: this._sessionId
    });
    if (!this._commitLoadoutTransaction(before)) {
      return { success: false, message: '存档写入失败，交易未执行。', item, result };
    }
    eventBus.emit('shop:purchased', { item, result, costSpec, source: this._sessionSource, sessionId: this._sessionId, vendorId: this._sessionSummary?.vendorId || null });
    if (debt) eventBus.emit('market:debtCreated', { debt: this._clone(debt), item });
    return { success: true, message: `契约已成：${item.name}。${this._describeGhostDebtTerm(debt)}`, item, result, costSpec, debt };
  }

  /**
   * Treasure purchases are deliberately a single state transaction.  The
   * instance writer remains TreasureSystem; ShopSystem only composes payment,
   * offer consumption and the one persistent post-purchase player decision.
   */
  _purchaseTreasure(item, price, costMode = null) {
    const existing = gameState.pendingLoadoutDecision;
    const wantedId = `loadout:${this._vendorSessionKey()}:${item.id}`;
    if (existing?.status === 'pending' && existing.id !== wantedId) {
      return { success: false, message: '请先决定刚购得的法宝是穿戴还是收入纳戒。', item };
    }
    const resolvedMode = this._resolveCostMode(item, costMode);
    if (!resolvedMode.valid) return { success: false, message: resolvedMode.reason || '易手条件无效。', item };
    const costSpec = resolvedMode.costSpec;
    const ghostOath = this._sessionSummary?.vendorId === 'ghost_market'
      && item.ghostOathContract && typeof item.ghostOathContract === 'object'
      ? item.ghostOathContract : null;
    const provenanceExchangeMode = resolvedMode.id || (ghostOath ? 'ghost_oath' : null);
    const provenanceExchangeLabel = resolvedMode.provenanceLabel
      || (ghostOath?.provenanceLabel || null);
    if (!this._canPayCostSpec(costSpec)) {
      return { success: false, message: costSpec.some(cost => cost.key !== 'spiritStone') ? '契约代价不足。' : '灵石不足。', item };
    }
    if (typeof gameState.beginCausalTransaction !== 'function' || gameState.beginCausalTransaction() !== true) {
      return { success: false, message: '存档尚未就绪，交易未执行。', item };
    }
    const before = {
      offers: this._clone(this._activeOffers),
      summary: this._clone(this._sessionSummary)
    };
    const result = this._applyItemEffect(item, {
      persist: false,
      emit: false,
      costMode: resolvedMode.id,
      provenanceLabel: resolvedMode.provenanceLabel
    });
    if (!result || result.type !== 'treasure' || result.success === false) {
      this._rollbackShopTransaction(before);
      return { success: false, message: '交易未能完成，灵石未扣除。', item, result };
    }

    const pending = existing?.id === wantedId ? existing : this._buildPendingLoadoutDecision(item, result);
    if (!pending) {
      this._rollbackShopTransaction(before);
      return { success: false, message: '法宝来历不完整，交易未提交。', item, result };
    }

    const provenanceDefinition = item.narrativeProvenance;
    let provenanceFact = null;
    if (provenanceDefinition?.factTypeId) {
      if (typeof narrativeLedger === 'undefined' || !narrativeLedger?.recordFact) {
        this._rollbackShopTransaction(before);
        return { success: false, message: '易手来历账册未就绪，交易未执行。', item, result };
      }
      const produced = narrativeLedger.recordFact({
        factTypeId: provenanceDefinition.factTypeId,
        producerId: provenanceDefinition.producerId || item.id,
        payload: {
          ...(provenanceDefinition.payload && typeof provenanceDefinition.payload === 'object'
            ? this._clone(provenanceDefinition.payload) : {}),
          itemInstanceId: pending.instanceId,
          exchangeMode: provenanceExchangeMode,
          exchangeLabel: provenanceExchangeLabel,
          source: this._sessionSummary?.vendorId === 'ghost_market' ? 'ghost_market_purchase' : 'public_bazaar_trade',
          sessionKey: this._vendorSessionKey(),
          offerId: item.id
        },
        decisionIndex: gameState.getNextDecisionIndex?.() ?? gameState.getDecisionIndex?.() ?? gameState.turn,
        persist: false
      });
      if (!produced.created) {
        const existingFact = narrativeLedger.getFactByType?.(provenanceDefinition.factTypeId);
        if (result.replayed !== true || existingFact?.payload?.itemInstanceId !== pending.instanceId) {
          this._rollbackShopTransaction(before);
          return { success: false, message: '同世易手来历已经结清，不能重复取得。', item, result };
        }
        provenanceFact = existingFact;
      } else {
        provenanceFact = produced.fact;
      }
    }

    if (result.replayed !== true && !this._applyCostSpec(costSpec)) {
      this._rollbackShopTransaction(before);
      return { success: false, message: '契约代价不足，交易未执行。', item, result };
    }
    if (this._activeSession) {
      this._activeOffers = this._activeOffers.filter(offer => offer.id !== item.id);
      if (result.replayed !== true && this._sessionSummary) {
        this._sessionSummary.purchaseCount++;
        this._sessionSummary.spiritStoneSpent += this._spiritStoneCost(costSpec);
        this._sessionSummary.purchasedItems.push({ id: item.id, name: item.name, costSpec: this._clone(costSpec), costMode: resolvedMode.id });
      }
      const debt = result.replayed !== true ? this._createGhostDebt(item, {
        ...result,
        instanceId: pending.instanceId,
        sourceFactInstanceId: provenanceFact?.factInstanceId || null
      }, costSpec) : null;
      this._syncPendingVendorSession({ persist: false });
      if (debt) {
        // Only the authored oath claims a concrete-instance provenance closure.
        // Ordinary ghost contracts predate that instance link and must remain a
        // valid shared ShopSystem / MarketSystem transaction when no such port
        // is available (for example their B2 contract harness).
        const requiresOathProvenance = debt.kind === 'ghost_oath_sword';
        const annotated = !requiresOathProvenance || treasureSystem.annotateInstanceProvenance?.(pending.instanceId, {
          ghostDebtId: debt.debtId,
          sourceFactInstanceId: debt.sourceFactInstanceId,
          contractKind: debt.kind || null,
          contractLabel: debt.contractLabel || null
        }, { persist: false, emit: false });
        if (!annotated) {
          this._rollbackShopTransaction(before);
          return { success: false, message: '夜契来历未能归档，交易未执行。', item, result };
        }
        pending.ghostDebtId = debt.debtId;
        pending.ghostDebt = {
          debtId: debt.debtId,
          dueDecisionIndex: debt.dueDecisionIndex,
          settlementCostSpec: this._clone(debt.settlementCostSpec),
          pressure: this._clone(debt.pressure || null),
          contractLabel: debt.contractLabel || null
        };
        this._sessionSummary?.ghostDebtTerms?.push(this._clone(debt));
      }
    }
    // Debt provenance is computed inside the same purchase transaction. Store
    // the loadout decision only after that link exists; otherwise the modal
    // can survive a refresh with an orphaned-looking ghost acquisition.
    gameState.pendingLoadoutDecision = this._clone(pending);
    if (result.replayed !== true) {
      eventBus.emit('shop:purchasePrepared', {
        item, result, price, costSpec, source: this._sessionSource, sessionId: this._sessionId
      });
    }
    if (!this._commitLoadoutTransaction(before)) {
      return { success: false, message: '存档写入失败，交易未执行。', item, result };
    }

    if (result.replayed !== true) {
      eventBus.emit('treasure:acquired', {
        treasureId: result.treasureId,
        instanceId: pending.instanceId,
        treasure: treasureSystem.getTreasureData?.(pending.instanceId) || null
      });
    }
    if (result.replayed !== true) {
      eventBus.emit('shop:purchased', {
        item, result, price, costSpec, costMode: resolvedMode.id, source: this._sessionSource, sessionId: this._sessionId,
        vendorId: this._sessionSummary?.vendorId || null,
        entryCardId: this._sessionSummary?.entryCardId || null
      });
    }
    const debt = result.replayed !== true
      ? gameState.marketState?.debts?.find(entry => entry?.debtId === pending.ghostDebtId) || null
      : null;
    if (debt) eventBus.emit('market:debtCreated', { debt: this._clone(debt), item });
    eventBus.emit('loadout:decisionPending', { decision: this._clone(pending), item });
    return {
      success: true,
      replayed: result.replayed === true,
      message: result.replayed === true
        ? `已恢复 ${item.name} 的既有交易。`
        : (debt ? `契约已成：${item.name}。${this._describeGhostDebtTerm(debt)}` : `购买了 ${item.name}。`),
      item,
      result,
      costSpec,
      costMode: resolvedMode.id,
      provenanceFact: provenanceFact ? this._clone(provenanceFact) : null,
      debt: debt ? this._clone(debt) : null,
      pendingLoadoutDecision: this._clone(pending)
    };
  }

  /**
   * 尝试购买商品
   * @param {string} itemId - 商品 ID
   * @returns {Object} { success, message, item }
   */
  purchase(itemId, costModeId = null) {
    const item = this._activeSession
      ? this._activeOffers.find(i => i.id === itemId)
      : this.items.find(i => i.id === itemId);
    if (!item) return { success: false, message: this._activeSession ? '此物已易主或报价已失效。' : '商品不存在。' };

    const price = Number(item.price ?? item.displayPrice ?? 0);
    if (!Number.isFinite(price) || price < 0) {
      return { success: false, message: '商品价格异常。' };
    }

    const resolvedMode = this._resolveCostMode(item, costModeId);
    if (!resolvedMode.valid) return { success: false, message: resolvedMode.reason || '易手条件无效。' };
    const costSpec = resolvedMode.costSpec;
    if (!this._canPayCostSpec(costSpec)) {
      return { success: false, message: costSpec.some(cost => cost.key !== 'spiritStone') ? '契约代价不足。' : '灵石不足。' };
    }

    if (this._isTreasureOffer(item)) return this._purchaseTreasure(item, price, resolvedMode.id);
    // Bazaar offers are a real session transaction even when their authored
    // price happens to be stone-only. Otherwise one of its three stalls could
    // commit payment/effect before the session receipt becomes durable.
    if ((this._sessionSummary?.marketType === 'public_bazaar')
      || (Array.isArray(item.costSpec) && item.costSpec.length > 0)) {
      return this._purchaseWithCostSpec(item, price);
    }

    if (typeof gameState.beginCausalTransaction !== 'function' || gameState.beginCausalTransaction() !== true) {
      return { success: false, message: '存档尚未就绪，交易未执行。', item };
    }
    const before = { offers: this._clone(this._activeOffers), summary: this._clone(this._sessionSummary) };
    // 扣款、发货与本世功绩在同一同步事务中完成。
    gameState.addResource('spiritStone', null, -price);
    const result = this._applyItemEffect(item, { persist: false, emit: false });
    if (!result || result.type === 'unknown' || result.success === false) {
      this._rollbackShopTransaction(before);
      return { success: false, message: '交易未能完成，灵石已退回。', item, result };
    }

    // A receipt replay means the previous process committed the acquisition
    // before its offer snapshot was persisted. Undo this invocation's
    // provisional debit, consume the stale offer, and never emit a second
    // purchase event or spend record.
    if (result.replayed === true) {
      this._rollbackShopTransaction(before);
      if (this._activeSession) {
        this._activeOffers = this._activeOffers.filter(offer => offer.id !== itemId);
        this._syncPendingVendorSession();
      }
      return { success: true, replayed: true, message: `已恢复 ${item.name} 的既有交易。`, item, result };
    }

    if (this._activeSession) {
      this._activeOffers = this._activeOffers.filter(offer => offer.id !== itemId);
      if (this._sessionSummary) {
        this._sessionSummary.purchaseCount++;
        this._sessionSummary.spiritStoneSpent += price;
        this._sessionSummary.purchasedItems.push({ id: item.id, name: item.name, price });
        if (item.type === 'story_item') this._sessionSummary.resolution = 'purchased';
      }
      this._syncPendingVendorSession({ persist: false });
    }

    eventBus.emit('shop:purchasePrepared', {
      item, result, price, source: this._sessionSource, sessionId: this._sessionId
    });
    if (!this._commitLoadoutTransaction(before)) {
      return { success: false, message: '存档写入失败，交易未执行。', item, result };
    }

    eventBus.emit('shop:purchased', {
      item,
      result,
      price,
      source: this._sessionSource,
      sessionId: this._sessionId,
      vendorId: this._sessionSummary?.vendorId || null,
      entryCardId: this._sessionSummary?.entryCardId || null
    });
    return { success: true, message: `购买了 ${item.name}。`, item, result };
  }

  /**
   * Finalize the player-visible post-purchase loadout choice.  This is not a
   * shop purchase and never advances the decision clock; it is only the
   * second half of the already committed acquisition receipt.
   */
  resolveLoadoutDecision(action) {
    const pending = gameState.pendingLoadoutDecision;
    if (!pending || pending.status !== 'pending') {
      return { success: false, message: '没有待处理的法宝装配决定。' };
    }
    if (!['equip', 'stash'].includes(action) || pending.allowedActions?.[action] !== true) {
      return { success: false, message: '此法宝不能执行该操作。' };
    }
    if (!treasureSystem.getInstance?.(pending.instanceId)) {
      return { success: false, message: '待装配法宝不存在，存档未作修改。' };
    }
    if (typeof gameState.beginCausalTransaction !== 'function' || gameState.beginCausalTransaction() !== true) {
      return { success: false, message: '存档尚未就绪，装配未改变。' };
    }
    const before = {
      offers: this._clone(this._activeOffers),
      summary: this._clone(this._sessionSummary)
    };
    let equipmentResult = null;
    if (action === 'equip') {
      equipmentResult = treasureSystem.equip(pending.instanceId, pending.targetSlot, {
        persist: false,
        emit: false
      });
      if (!equipmentResult?.success) {
        this._rollbackShopTransaction(before);
        return { success: false, message: equipmentResult?.message || '法宝无法装入该槽位。' };
      }
    }
    gameState.pendingLoadoutDecision = null;
    if (!this._commitLoadoutTransaction(before)) {
      return { success: false, message: '存档写入失败，装配未改变。' };
    }
    if (equipmentResult) {
      eventBus.emit('treasure:equipped', {
        treasureId: treasureSystem.getDefinitionId?.(pending.instanceId) || pending.instanceId,
        instanceId: pending.instanceId,
        slot: pending.targetSlot,
        oldId: equipmentResult.oldEquipped || null
      });
    }
    eventBus.emit('loadout:decisionResolved', {
      decision: this._clone(pending), action, equipmentResult
    });
    return {
      success: true,
      action,
      equipmentResult,
      message: action === 'equip'
        ? equipmentResult.message
        : '已收入纳戒；未穿戴的法宝不会提供任何效果。'
    };
  }

  _vendorSessionKey() {
    const runClock = gameState.getRunClock?.() || null;
    const life = runClock?.lifeId
      || `legacy:${Number(gameState.getLifeCount?.() ?? gameState.unlocks?.lifeCount ?? 0) || 0}`;
    const decision = Math.max(0, Number(
      gameState.getNextDecisionIndex?.()
      ?? gameState.getDecisionIndex?.()
      ?? gameState.turn
    ) || 0);
    // Vendor sessions provide sessionKey on the real market path. The fallback
    // is still derived entirely from persisted state, never `_sessionId`.
    return this._sessionSummary?.sessionKey
      || this._sessionSummary?.entryCardId
      || `${this._sessionSource || 'shop'}:life:${life}:decision:${decision}`;
  }

  _treasurePurchaseToken(item) {
    const runClock = gameState.getRunClock?.() || null;
    const life = runClock?.lifeId
      || `legacy:${Number(gameState.getLifeCount?.() ?? gameState.unlocks?.lifeCount ?? 0) || 0}`;
    const decision = Math.max(0, Number(
      gameState.getNextDecisionIndex?.()
      ?? gameState.getDecisionIndex?.()
      ?? gameState.turn
    ) || 0);
    const sessionKey = this._vendorSessionKey();
    return `treasure:shop:life:${life}:decision:${decision}:session:${sessionKey}:offer:${item.id}`;
  }

  /**
   * 应用商品效果
   */
  _applyItemEffect(item, options = {}) {
    const effect = item.effect || {};

    if (item.type === 'story_item') {
      const itemId = typeof effect.itemId === 'string' ? effect.itemId : '';
      const quantity = Math.max(1, Math.floor(Number(effect.quantity) || 1));
      if (!itemId || typeof gameState.addItem !== 'function'
        || !gameState.addItem(itemId, quantity)) {
        return { type: 'story_item', success: false, reason: 'story_inventory_unavailable' };
      }
      if (options.persist !== false && typeof gameState.persistCausalSession === 'function') gameState.persistCausalSession();
      return { type: 'story_item', success: true, itemId, quantity };
    }

    if (item.type === 'gift') {
      const giftItemId = typeof effect.giftItemId === 'string' ? effect.giftItemId : '';
      const quantity = Math.max(1, Math.floor(Number(effect.quantity) || 1));
      if (!giftItemId || typeof gameState.addItem !== 'function'
        || !gameState.addItem(giftItemId, quantity)) {
        return { type: 'gift', success: false, reason: 'gift_inventory_unavailable' };
      }
      if (options.persist !== false && typeof gameState.persistCausalSession === 'function') gameState.persistCausalSession();
      return { type: 'gift', success: true, giftItemId, quantity };
    }

    // 丹药类
    if (item.type === 'pill') {
      if (effect.pillId) {
        gameState.addResource('pills', effect.pillId, 1);
        return { type: 'pill', pillId: effect.pillId };
      }
      if (effect.healHp) {
        gameState.addAttribute('health', effect.healHp);
        return { type: 'heal', amount: effect.healHp };
      }
      if (effect.healDaoHeart) {
        gameState.addAttribute('daoHeart', effect.healDaoHeart);
        return { type: 'healDaoHeart', amount: effect.healDaoHeart };
      }
      if (effect.tempCultivation) {
        gameState.addAttribute('cultivation', effect.tempCultivation);
        return { type: 'tempCult', amount: effect.tempCultivation };
      }
    }

    // 法宝类
    if (item.type === 'treasure' || item._marketItem) {
      const treasureId = effect.treasureId;
      if (treasureId) {
        const narrative = item.narrativeProvenance && typeof item.narrativeProvenance === 'object'
          ? item.narrativeProvenance : null;
        const traded = this._sessionSummary?.marketType === 'public_bazaar' && narrative?.factTypeId;
        const ghostOath = this._sessionSummary?.vendorId === 'ghost_market'
          && item.ghostOathContract && typeof item.ghostOathContract === 'object'
          ? item.ghostOathContract : null;
        const source = traded
          ? 'public_bazaar_trade'
          : (this._sessionSummary?.vendorId === 'ghost_market'
            ? 'ghost_market_purchase'
            : `${this._sessionSource || 'shop'}_purchase`);
        const acquired = treasureSystem.acquire(treasureId, {
          source,
          sourceId: `${this._vendorSessionKey()}:${item.id}`,
          channel: this._sessionSummary?.vendorId || this._sessionSource || 'shop',
          transactionId: this._treasurePurchaseToken(item),
          provenance: traded ? {
              exchangeMode: options.costMode || null,
              exchangeLabel: options.provenanceLabel || null,
              sellerLeadId: narrative?.payload?.sellerLeadId || null,
              oldOwnerClue: narrative?.payload?.oldOwnerClue || null,
              stallId: narrative?.payload?.stallId || null
            } : (ghostOath ? {
              exchangeMode: 'ghost_oath',
              exchangeLabel: ghostOath.provenanceLabel || '夜契签下',
              contractKind: ghostOath.kind || 'ghost_oath_sword',
              contractLabel: ghostOath.label || item.name || '夜契'
            } : null),
          persist: options.persist,
          emit: options.emit
        });
        return {
          type: 'treasure', treasureId, success: acquired !== false,
          replayed: acquired !== false && Boolean(treasureSystem.getLastReceipt?.()?.replayed)
        };
      }
    }

    // NPC好感类
    if (item.type === 'npc_favor') {
      const amount = effect.npcFavor || 2;
      if (typeof npcSystem !== 'undefined' && npcSystem && npcSystem.npcs) {
        const localNpcs = Array.from(npcSystem.npcs.keys())
          .filter(id => !npcSystem.getCurrentSchedule || npcSystem.getCurrentSchedule(id) === gameState.currentLocation)
          .sort((a, b) => (npcSystem.affections[b] || 0) - (npcSystem.affections[a] || 0));
        if (localNpcs.length > 0) {
          npcSystem.addAffection(localNpcs[0], amount);
          return { type: 'npc_favor', npcId: localNpcs[0], amount };
        }
      }
      // 当前地点无人可打点时，转化为本地人脉标记，仍有后续消费者。
      gameState.addModifier('localInfluence', amount);
      return { type: 'local_influence', amount };
    }

    // 功法卡牌类
    if (item.type === 'card') {
      if (effect.deckCard) {
        const payload = typeof effect.deckCard === 'object'
          ? effect.deckCard
          : { cardId: effect.deckCard };
        if (!this.deckAuthority) {
          return { type: 'card', success: false, reason: 'deck_authority_unavailable' };
        }
        const acquisition = payload.path
          ? this.deckAuthority.acquirePathCard(payload.cardId, {
              path: payload.path,
              sourceType: payload.sourceType || 'shop_path_slot',
              sourceId: payload.sourceId || item.id
            })
          : this.deckAuthority.acquireLegacyCard(payload.cardId, {
              sourceType: 'shop_legacy_offer',
              sourceCardId: item.id
            });
        if (!acquisition?.acquired) {
          return {
            type: 'card',
            success: false,
            reason: acquisition?.reason || 'acquisition_failed',
            deckCard: payload.cardId
          };
        }
        return { type: 'card', success: true, deckCard: payload.cardId, acquisition };
      }
    }

    // 神秘古玩鉴宝类：通过 EffectService 的 _identifyTreasure 处理器触发气运加权抽奖
    if (effect._identifyTreasure) {
      if (typeof effectService === 'undefined' || !effectService
        || typeof effectService.apply !== 'function') {
        return { type: 'treasure_identify', success: false, reason: 'effect_service_unavailable' };
      }
      const settlement = effectService.apply({ _identifyTreasure: effect._identifyTreasure }, {
        sourceType: `${this._sessionSource || 'shop'}_identify`,
        sourceId: `${this._vendorSessionKey()}:${item.id}`,
        log: (msg) => console.log(msg)
      });
      const identify = settlement?.handlerResults?._identifyTreasure;
      if (settlement?.applied !== true || !identify || identify.success !== true) {
        return {
          type: 'treasure_identify',
          success: false,
          reason: identify?.reason || settlement?.reason || 'identify_writer_rejected'
        };
      }
      return {
        type: 'treasure_identify', success: true, treasureId: identify.treasureId || null,
        replayed: identify.replayed === true
      };
    }

    return { type: 'unknown' };
  }

  /**
   * 替换法宝（当法宝栏已满时）
   * @param {string} newTreasureId - 新法宝 ID
   * @param {string} oldTreasureId - 要替换的法宝 ID
   */
  replaceTreasure(newTreasureId, oldTreasureId) {
    const removed = treasureSystem.remove(oldTreasureId, gameState, { persist: false });
    if (!removed) return { success: false, message: '待替换法宝不存在。' };
    const acquired = treasureSystem.acquire(newTreasureId, {
      persist: false,
      source: 'shop_replace',
      sourceId: `${this._sessionId}:${newTreasureId}`,
      channel: this._sessionSource || 'shop'
    });
    if (acquired === false) {
      treasureSystem.acquire(oldTreasureId, { persist: false });
      gameState.persistCausalSession?.();
      return { success: false, message: '新法宝数据异常，原法宝已归还。' };
    }
    gameState.persistCausalSession?.();
    eventBus.emit('shop:treasureReplaced', { newId: newTreasureId, oldId: oldTreasureId });
    return { success: true, newId: newTreasureId, oldId: oldTreasureId };
  }
}

// 全局单例
const shopSystem = new ShopSystem();

if (typeof module !== 'undefined' && module.exports) {
  module.exports = { ShopSystem, shopSystem };
} else if (typeof window !== 'undefined') {
  window.ShopSystem = ShopSystem;
  window.shopSystem = shopSystem;
}
